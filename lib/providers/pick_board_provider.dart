import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pick_board.dart';
import '../models/pick_list.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'pick_list_provider.dart' show PickListSync;

/// Live pick board: everyone's personal pick lists plus the shared taken
/// list. While a screen is watching and the app is visible it holds a
/// WebSocket (Azure Web PubSub) that the API pushes every saved change to,
/// with a slow poll as a safety net. You only edit your own ballot (keyed by
/// your scouter name) and the taken flags; both are applied optimistically
/// and sent one change at a time.
class PickBoardProvider extends ChangeNotifier {
  /// Safety-net poll while pushes are flowing, in case one is missed.
  static const pushPollInterval = Duration(seconds: 60);

  /// Poll while the socket is down or live updates are off.
  static const fallbackPollInterval = Duration(seconds: 10);

  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String _secretKey = '';
  String _eventKey = '';
  String _voter = '';

  /// Last board from the server, with our own ballot and the taken list
  /// replaced by whichever confirmed copy is newer.
  PickBoard _server = const PickBoard();
  bool _loaded = false;

  /// Local changes not yet confirmed, re-applied on top of [_server].
  final List<PickListUpdate> _pendingVotes = [];
  final List<(int, bool)> _pendingTaken = [];
  PickBoard _view = const PickBoard();
  Future<void> _sendChain = Future.value();

  PickListSync _sync = PickListSync.idle;

  int _watchers = 0;
  bool _visible = true;
  bool _holding = false;
  bool _fetching = false;
  Timer? _timer;
  Duration? _timerInterval;
  AppLifecycleListener? _lifecycle;

  WebSocketChannel? _socket;
  StreamSubscription? _socketSub;
  bool _connecting = false;
  bool _pushLive = false;
  bool _liveUnavailable = false; // API has no Web PubSub configured
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  final _random = math.Random();

  PickBoard get board => _view;
  String get voter => _voter;
  String get myKey => voterKey(_voter);
  PickList get myList => _view.ballots[myKey]?.list ?? PickList.empty();
  bool get configured =>
      _secretKey.isNotEmpty && _eventKey.isNotEmpty && myKey.isNotEmpty;
  bool get loaded => _loaded;
  PickListSync get sync => _sync;

  /// True while changes are being pushed to us (not just polled).
  bool get pushLive => _pushLive;
  bool get hasPending => _pendingVotes.isNotEmpty || _pendingTaken.isNotEmpty;

  void configure({
    required String secretKey,
    required String eventKey,
    required String voter,
  }) {
    secretKey = secretKey.trim();
    voter = voter.trim();
    if (secretKey == _secretKey && eventKey == _eventKey && voter == _voter) {
      return;
    }
    final sameEvent = secretKey == _secretKey && eventKey == _eventKey;
    // The socket is joined to one secret key + event's group.
    if (!sameEvent) {
      _disconnect();
      _liveUnavailable = false;
    }
    _secretKey = secretKey;
    _eventKey = eventKey;
    _voter = voter;
    _pendingVotes.clear();
    _pendingTaken.clear();
    if (!sameEvent) {
      _server = const PickBoard();
      _loaded = false;
      _sync = PickListSync.idle;
    }
    _recompute();
    notifyListeners();
    _schedule();
    if (!configured) return;
    if (!sameEvent) {
      _storage.loadCachedPickBoard(eventKey).then((cached) {
        if (cached != null && eventKey == _eventKey && !_loaded) {
          _server = cached;
          _recompute();
          notifyListeners();
        }
      });
    }
    refresh();
  }

  /// Screens call watch()/unwatch() from initState/dispose to drive polling.
  void watch() {
    _watchers++;
    _lifecycle ??= AppLifecycleListener(
      onShow: () {
        _visible = true;
        _schedule();
        refresh();
      },
      onHide: () {
        _visible = false;
        _schedule();
      },
    );
    _schedule();
  }

  void unwatch() {
    if (_watchers > 0) _watchers--;
    _schedule();
  }

  /// Hold off applying polled changes mid-drag so rows don't jump.
  void holdUpdates(bool hold) {
    _holding = hold;
    if (!hold) refresh();
  }

  bool get _active => _watchers > 0 && _visible && configured;

  /// Connect and poll while someone's looking; otherwise let go of the
  /// socket so idle devices don't hold Web PubSub connections.
  void _schedule() {
    if (!_active) {
      _timer?.cancel();
      _timer = null;
      _timerInterval = null;
      _disconnect();
      return;
    }
    final interval = _pushLive ? pushPollInterval : fallbackPollInterval;
    if (_timerInterval != interval) {
      _timer?.cancel();
      _timer = Timer.periodic(interval, (_) => refresh());
      _timerInterval = interval;
    }
    _connect();
  }

  Future<void> _connect() async {
    if (_connecting || _socket != null || _liveUnavailable ||
        _reconnectTimer != null) {
      return;
    }
    _connecting = true;
    final sk = _secretKey;
    final ek = _eventKey;
    bool stale() => !_active || sk != _secretKey || ek != _eventKey;
    try {
      final url = await _api.negotiatePickBoard(sk, ek);
      if (url == null) {
        _liveUnavailable = true;
        return;
      }
      if (stale()) return;
      final channel = WebSocketChannel.connect(url);
      await channel.ready;
      if (stale()) {
        channel.sink.close();
        return;
      }
      _socket = channel;
      _socketSub = channel.stream.listen(
        _onPush,
        onDone: _onSocketClosed,
        onError: (Object e) => _onSocketClosed(),
      );
      _reconnectAttempt = 0;
      _pushLive = true;
      _schedule(); // slow the poll down
      // Catch up on anything saved before we joined the group.
      refresh();
      notifyListeners();
    } catch (e) {
      debugPrint('Pick board live connect failed: $e');
      if (!stale()) _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onSocketClosed() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    if (_pushLive) {
      _pushLive = false;
      notifyListeners();
    }
    if (_active) {
      _schedule(); // speed the poll back up
      _scheduleReconnect();
    }
  }

  /// Back off up to 30s, with jitter so a blip doesn't bring every client
  /// back at the same instant.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final base = math.min(30, 1 << math.min(_reconnectAttempt, 5));
    _reconnectAttempt++;
    final delay = Duration(
        milliseconds: (base * 1000 * (0.5 + _random.nextDouble())).round());
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_active) _connect();
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.sink.close();
    _socket = null;
    _pushLive = false;
  }

  /// A doc the API just saved: {type: 'ballot'|'taken', doc}.
  void _onPush(dynamic data) {
    // Mid-drag, skip it; letting go triggers a full refresh anyway.
    if (_holding || data is! String) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final doc = msg['doc'];
    if (doc is! Map<String, dynamic> || doc['event_key'] != _eventKey) return;
    switch (msg['type']) {
      case 'ballot':
        final b = Ballot.fromJson(doc);
        final current = _server.ballots[b.key]?.list.version ?? -1;
        if (b.list.version <= current) return;
        _server = _server.withBallot(b);
      case 'taken':
        final version = (doc['version'] as num?)?.toInt() ?? 0;
        if (version <= _server.takenVersion) return;
        _server = _server.withTaken({
          for (final t in (doc['teams'] ?? []) as List) (t as num).toInt(),
        }, version);
      default:
        return;
    }
    _loaded = true;
    _sync = PickListSync.live;
    _recompute();
    _storage.cachePickBoard(_eventKey, _server);
    notifyListeners();
  }

  void _recompute() {
    var view = _server;
    if (_pendingVotes.isNotEmpty) {
      final mine = _server.ballots[myKey]?.list ?? PickList.empty();
      view = view.withBallot(
          Ballot(_voter, _pendingVotes.fold(mine, (l, u) => l.apply(u))));
    }
    if (_pendingTaken.isNotEmpty) {
      final taken = {..._server.taken};
      for (final (tn, isTaken) in _pendingTaken) {
        isTaken ? taken.add(tn) : taken.remove(tn);
      }
      view = view.withTaken(taken, _server.takenVersion);
    }
    _view = view;
  }

  /// Take a polled board, but never step a ballot or the taken list back
  /// to an older version than one we already have from a write or a push
  /// (a poll can start before a push and land after it).
  PickBoard _merge(PickBoard polled) {
    var merged = polled;
    for (final b in _server.ballots.values) {
      final p = polled.ballots[b.key];
      if (p == null || p.list.version < b.list.version) {
        merged = merged.withBallot(b);
      }
    }
    if (polled.takenVersion < _server.takenVersion) {
      merged = merged.withTaken(_server.taken, _server.takenVersion);
    }
    return merged;
  }

  Future<void> refresh() async {
    if (!configured || _fetching || _holding) return;
    _fetching = true;
    final sk = _secretKey;
    final ek = _eventKey;
    try {
      final polled = await _api.getPickBoard(sk, ek);
      if (sk != _secretKey || ek != _eventKey || _holding) return;
      _server = _merge(polled);
      _loaded = true;
      _sync = PickListSync.live;
      _recompute();
      _storage.cachePickBoard(ek, _server);
      notifyListeners();
    } catch (e) {
      if (sk == _secretKey && ek == _eventKey &&
          _sync != PickListSync.offline) {
        _sync = PickListSync.offline;
        notifyListeners();
      }
    } finally {
      _fetching = false;
    }
  }

  /// Queue a send after any earlier ones; resolves false if it didn't stick
  /// (the optimistic change is rolled back either way once it settles).
  Future<bool> _send(Future<void> Function() send, VoidCallback settle) {
    final done = Completer<bool>();
    final sk = _secretKey;
    final ek = _eventKey;
    _sendChain = _sendChain.then((_) async {
      var ok = false;
      try {
        await send();
        ok = true;
        if (sk == _secretKey && ek == _eventKey) {
          _sync = PickListSync.live;
          _storage.cachePickBoard(ek, _server);
        }
      } catch (e) {
        if (sk == _secretKey && ek == _eventKey) {
          _sync = PickListSync.offline;
        }
      } finally {
        settle();
        _recompute();
        notifyListeners();
        done.complete(ok);
      }
    });
    return done.future;
  }

  /// Change one team on your own list.
  Future<bool> vote(PickListUpdate u) {
    if (!configured) return Future.value(false);
    _pendingVotes.add(u);
    _recompute();
    notifyListeners();
    final sk = _secretKey;
    final ek = _eventKey;
    final voter = _voter;
    return _send(() async {
      final ballot = await _api.updatePickVote(
          secretKey: sk, eventKey: ek, voter: voter, update: u);
      if (sk != _secretKey || ek != _eventKey || ballot.key != myKey) return;
      final current = _server.ballots[myKey]?.list.version ?? -1;
      if (ballot.list.version >= current) _server = _server.withBallot(ballot);
    }, () => _pendingVotes.remove(u));
  }

  /// Mark a team taken (or available) for everyone.
  Future<bool> setTaken(int teamNumber, bool taken) {
    if (!configured) return Future.value(false);
    final change = (teamNumber, taken);
    _pendingTaken.add(change);
    _recompute();
    notifyListeners();
    final sk = _secretKey;
    final ek = _eventKey;
    return _send(() async {
      final (teams, version) = await _api.setPickTaken(
          secretKey: sk,
          eventKey: ek,
          updatedBy: _voter,
          teamNumber: teamNumber,
          taken: taken);
      if (sk != _secretKey || ek != _eventKey) return;
      if (version >= _server.takenVersion) {
        _server = _server.withTaken(teams, version);
      }
    }, () => _pendingTaken.remove(change));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disconnect();
    _lifecycle?.dispose();
    super.dispose();
  }
}
