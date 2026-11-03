import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../models/cluster_config.dart';
import '../models/cluster_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'app_state_provider.dart';

/// Cluster settings and the clustering they produce for the selected event.
///
/// Settings: the team default (published to the API, one per season) unless
/// this device has its own custom settings, which are saved locally.
///
/// Result: the event clustered with those settings and no exclusions, which
/// Team Details uses for groups and neighbors. Same policy as the other
/// analytics data: cached copy first, fetched at most once per session per
/// settings, [refresh] to re-fetch.
class ClusterProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String? _year;
  String? _eventKey;
  String _secretKey = '';
  ClusterConfig? _teamDefault;
  ClusterConfig? _custom;
  ClusterResult? _result;
  bool _loading = false;
  String? _error;
  int _seq = 0;
  Timer? _debounce;
  Future<void> _switchLock = Future.value();
  // Only cluster once some screen has shown a clustering; settings loaded at
  // startup alone shouldn't cost an API run.
  bool _resultWanted = false;
  final Set<String> _fetchedDefaults = {};
  final Set<String> _fetchedResults = {};

  /// Published team default for the season, if anyone has published one.
  ClusterConfig? get teamDefault => _teamDefault;

  /// This device's own settings, or null when following the team default.
  ClusterConfig? get custom => _custom;
  bool get isCustom => _custom != null;

  /// The settings in effect.
  ClusterConfig get config => _custom ?? _teamDefault ?? ClusterConfig.builtIn;

  /// Settings with the API's built-in default features filled in, once a
  /// result has said what those are.
  ClusterConfig get resolvedConfig {
    final c = config;
    if (c.features.isNotEmpty || _result == null) return c;
    return c.copyWith(features: _result!.features);
  }

  ClusterResult? get result => _result;
  bool get loading => _loading;
  String? get error => _error;
  bool get configured => _eventKey != null && _secretKey.isNotEmpty;

  String get _tag => '$_secretKey|${config.signature}';

  /// Point at the selected event/season. Loads saved settings and the cached
  /// result; fetches the team default once per session. Pass [withResult] to
  /// also make sure there's a clustering (screens that show one).
  Future<void> ensureLoaded({
    required String? eventKey,
    required String secretKey,
    bool withResult = false,
  }) async {
    // One switch at a time, so a second caller never sees half-loaded
    // settings; the network calls happen outside the lock.
    final switched = _switchLock.then((_) => _switchTo(eventKey, secretKey));
    _switchLock = switched;
    await switched;
    final year = _year;
    final secret = _secretKey;
    if (year != null && secret.isNotEmpty && _fetchedDefaults.add('$secret|$year')) {
      await _fetchTeamDefault(year, secret);
    }
    if (withResult) {
      _resultWanted = true;
      await _ensureResult();
    }
  }

  Future<void> _switchTo(String? eventKey, String secretKey) async {
    final key = (eventKey == null || eventKey.isEmpty) ? null : eventKey;
    final secret = secretKey.trim();
    final year = key != null && key.length >= 4 ? key.substring(0, 4) : null;
    if (year != _year || secret != _secretKey) {
      _year = year;
      _secretKey = secret;
      _teamDefault = null;
      _custom = null;
      _eventKey = null;
      _result = null;
      if (year != null) {
        _teamDefault = await _storage.loadClusterConfig(year, custom: false);
        _custom = await _storage.loadClusterConfig(year, custom: true);
      }
      notifyListeners();
    }
    if (key != _eventKey) {
      _eventKey = key;
      _result = null;
      _error = null;
      await _loadCachedResult();
      notifyListeners();
    }
  }

  Future<void> _loadCachedResult() async {
    final key = _eventKey;
    if (key == null || _secretKey.isEmpty) return;
    final tag = _tag;
    try {
      final cached = await _storage.loadCachedClusters(key, tag);
      if (cached != null && key == _eventKey && tag == _tag) _result = cached;
    } catch (e) {
      debugPrint('ClusterProvider cache read failed: $e');
    }
  }

  Future<void> _fetchTeamDefault(String year, String secret) async {
    try {
      final fetched = await _api.getClusterConfig(secretKey: secret, year: year);
      if (year != _year || secret != _secretKey) return;
      final before = config.signature;
      _teamDefault = fetched;
      await _storage.saveClusterConfig(year, fetched, custom: false);
      if (config.signature != before) await _settingsChanged();
      notifyListeners();
    } catch (e) {
      debugPrint('ClusterProvider team default fetch failed: $e');
      _fetchedDefaults.remove('$secret|$year');
    }
  }

  Future<void> _ensureResult() async {
    if (!configured) return;
    if (_fetchedResults.contains('$_eventKey|$_tag')) return;
    await fetch();
  }

  /// Cluster the event with the current settings. [refresh] skips every cache.
  Future<void> fetch({bool refresh = false}) async {
    final key = _eventKey;
    if (key == null || _secretKey.isEmpty) return;
    final tag = _tag;
    final fetchKey = '$key|$tag';
    _fetchedResults.add(fetchKey);
    final seq = ++_seq;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _api.getClusters(
        secretKey: _secretKey,
        eventKey: key,
        config: config,
        refresh: refresh,
      );
      if (seq != _seq) return;
      _result = r;
      try {
        await _storage.cacheClusters(key, tag, r);
      } catch (e) {
        debugPrint('ClusterProvider cache write failed: $e');
      }
    } catch (e) {
      _fetchedResults.remove(fetchKey);
      if (seq == _seq) _error = e.toString();
    }
    if (seq == _seq) {
      _loading = false;
      notifyListeners();
    }
  }

  /// Settings changed: show a cached clustering for them if there is one,
  /// then fetch (debounced so stepping through options doesn't spam the API).
  /// The previous result stays up until the new one lands, so screens don't
  /// flash empty on every tweak.
  Future<void> _settingsChanged() async {
    await _loadCachedResult();
    notifyListeners();
    _debounce?.cancel();
    if (_resultWanted) {
      _debounce = Timer(const Duration(milliseconds: 400), _ensureResult);
    }
  }

  /// Use [next] on this device only.
  Future<void> setCustom(ClusterConfig next) async {
    final year = _year;
    if (year == null) return;
    // Matching the team default exactly is the same as following it.
    final follow = _teamDefault != null && next.sameAs(_teamDefault!);
    _custom = follow ? null : next;
    await _storage.saveClusterConfig(year, _custom, custom: true);
    await _settingsChanged();
  }

  /// Drop this device's settings and follow the team default again.
  Future<void> resetToTeamDefault() async {
    final year = _year;
    if (year == null || _custom == null) return;
    _custom = null;
    await _storage.saveClusterConfig(year, null, custom: true);
    await _settingsChanged();
  }

  /// Publish the settings in effect as the team default for everyone.
  Future<void> publishAsTeamDefault(String scouterName) async {
    final year = _year;
    if (year == null || _secretKey.isEmpty) return;
    final saved = await _api.setClusterConfig(
      secretKey: _secretKey,
      year: year,
      config: resolvedConfig,
      updatedBy: scouterName,
    );
    final before = config.signature;
    _teamDefault = saved;
    _custom = null;
    await _storage.saveClusterConfig(year, saved, custom: false);
    await _storage.saveClusterConfig(year, null, custom: true);
    if (config.signature != before) {
      await _settingsChanged();
    } else {
      notifyListeners();
    }
  }

  /// Pick up a team default someone else just published.
  Future<void> reloadTeamDefault() async {
    final year = _year;
    if (year == null || _secretKey.isEmpty) return;
    await _fetchTeamDefault(year, _secretKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

extension ClusterContext on BuildContext {
  /// Sync [ClusterProvider] with the selected event and secret key; screens
  /// that show a clustering pass [withResult].
  Future<void> ensureClusters({bool withResult = true}) {
    final settings = read<AppStateProvider>().settings;
    return read<ClusterProvider>().ensureLoaded(
      eventKey: settings.selectedEventKey,
      secretKey: settings.secretTeamKey,
      withResult: withResult,
    );
  }
}
