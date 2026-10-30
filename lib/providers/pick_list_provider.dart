import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/pick_list.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum PickListSync { idle, live, offline }

/// Live, shared pick list. Polls the API while any screen is watching and
/// the app is visible. Local changes are applied optimistically and sent
/// one at a time; the server applies each against its latest copy, so
/// concurrent editors never overwrite each other.
class PickListProvider extends ChangeNotifier {
  static const pollInterval = Duration(seconds: 3);

  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String _secretKey = '';
  String _eventKey = '';
  String _scouterName = '';

  /// Last copy confirmed by the server.
  PickList _server = PickList.empty();
  bool _loaded = false;

  /// Local changes not yet confirmed, re-applied on top of [_server].
  final List<PickListUpdate> _pending = [];
  PickList _view = PickList.empty();
  Future<void> _sendChain = Future.value();

  PickListSync _sync = PickListSync.idle;
  String? _error;

  int _watchers = 0;
  bool _visible = true;
  bool _holding = false;
  bool _fetching = false;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  PickList get list => _view;
  bool get configured => _secretKey.isNotEmpty && _eventKey.isNotEmpty;
  bool get loaded => _loaded;
  PickListSync get sync => _sync;
  String? get error => _error;
  bool get hasPending => _pending.isNotEmpty;

  /// Point the provider at a secret key + event. Resets if either changed.
  void configure({
    required String secretKey,
    required String eventKey,
    required String scouterName,
  }) {
    _scouterName = scouterName;
    secretKey = secretKey.trim();
    if (secretKey == _secretKey && eventKey == _eventKey) return;
    _secretKey = secretKey;
    _eventKey = eventKey;
    _server = PickList.empty();
    _loaded = false;
    _pending.clear();
    _sync = PickListSync.idle;
    _error = null;
    _recompute();
    notifyListeners();
    _schedule();
    if (!configured) return;
    _storage.loadCachedPickList(eventKey).then((cached) {
      if (cached != null && eventKey == _eventKey && !_loaded) {
        _server = cached;
        _recompute();
        notifyListeners();
      }
    });
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

  /// Hold off applying polled changes (e.g. mid-drag) so the list doesn't
  /// shift under the user's finger.
  void holdUpdates(bool hold) {
    _holding = hold;
    if (!hold) refresh();
  }

  void _schedule() {
    final shouldPoll = _watchers > 0 && _visible && configured;
    if (shouldPoll && _timer == null) {
      _timer = Timer.periodic(pollInterval, (_) => refresh());
    } else if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _recompute() {
    _view = _pending.fold(_server, (list, u) => list.apply(u));
  }

  Future<void> refresh() async {
    if (!configured || _fetching || _holding) return;
    _fetching = true;
    final sk = _secretKey;
    final ek = _eventKey;
    try {
      final doc = await _api.getPickList(sk, ek);
      if (sk != _secretKey || ek != _eventKey || _holding) return;
      var changed = _sync != PickListSync.live || _error != null;
      _sync = PickListSync.live;
      _error = null;
      if (doc != null && (!_loaded || doc.version > _server.version)) {
        _server = doc;
        _recompute();
        _storage.cachePickList(ek, doc);
        changed = true;
      }
      if (!_loaded) {
        _loaded = true;
        changed = true;
      }
      if (changed) notifyListeners();
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

  /// Apply a change locally right away and send it. Resolves to false if the
  /// server didn't accept it (the local change is rolled back).
  Future<bool> update(PickListUpdate u) {
    if (!configured) return Future.value(false);
    _pending.add(u);
    _recompute();
    notifyListeners();
    final done = Completer<bool>();
    final sk = _secretKey;
    final ek = _eventKey;
    _sendChain = _sendChain.then((_) async {
      try {
        final doc = await _api.updatePickListTeam(
          secretKey: sk,
          eventKey: ek,
          updatedBy: _scouterName,
          update: u,
        );
        if (sk == _secretKey && ek == _eventKey) {
          if (doc.version >= _server.version) _server = doc;
          _loaded = true;
          _sync = PickListSync.live;
          _error = null;
          _storage.cachePickList(ek, doc);
        }
        done.complete(true);
      } catch (e) {
        if (sk == _secretKey && ek == _eventKey) {
          _sync = PickListSync.offline;
          _error = 'Change not saved: $e';
        }
        done.complete(false);
      } finally {
        _pending.remove(u);
        _recompute();
        notifyListeners();
      }
    });
    return done.future;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
