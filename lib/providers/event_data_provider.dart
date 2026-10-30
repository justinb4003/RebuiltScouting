import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../analytics/scout_stats.dart';
import '../models/match_result.dart';
import '../models/scouted_match.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'app_state_provider.dart';

/// Shared analytics data for the selected event: our scouted rows and the
/// official match results, plus per-team aggregation built from them.
///
/// Kept apart from [AppStateProvider] (which owns settings, the team/match
/// lists the scouting forms use and pit results) because these datasets have
/// their own fetch policy and are read by several analytics screens:
///  * cached data is loaded immediately,
///  * each dataset is fetched automatically at most once per app session,
///  * [refresh] forces a re-fetch.
/// Pit results and the team list stay in [AppStateProvider]; screens read
/// them from there rather than duplicating them.
class EventDataProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String? _eventKey;
  String _secretKey = '';
  List<ScoutedMatch> _scouted = [];
  List<MatchResult> _matches = [];
  Map<int, TeamStats>? _teamStats;
  Map<int, Map<int, List<ScoutedMatch>>>? _byQual; // qual number -> team -> rows
  int _loadingCount = 0;
  String? _error;
  DateTime? _lastFetched;

  // Datasets already fetched this session, as "dataset|event[|secret]".
  final Set<String> _fetched = {};
  // Bumped on every event change so late responses for an old event are dropped.
  int _generation = 0;

  String? get eventKey => _eventKey;
  List<ScoutedMatch> get scouted => _scouted;
  List<MatchResult> get matches => _matches;
  bool get loading => _loadingCount > 0;
  String? get error => _error;

  /// When data was last fetched from the API this session (null: cache only).
  DateTime? get lastFetched => _lastFetched;

  /// Scouted stats per team number. Recomputed only when the rows change.
  Map<int, TeamStats> get teamStats => _teamStats ??= aggregateByTeam(_scouted);

  TeamStats? statsFor(int team) => teamStats[team];

  List<MatchResult> matchesForTeam(int team) =>
      [for (final m in _matches) if (m.hasTeam(team)) m];

  /// Scouted rows for a qualification match, keyed by team number.
  Map<int, List<ScoutedMatch>> scoutedInMatch(MatchResult match) {
    if (!match.isQual) return const {};
    final index = _byQual ??= () {
      final out = <int, Map<int, List<ScoutedMatch>>>{};
      for (final r in _scouted) {
        out.putIfAbsent(r.matchNumber, () => {}).putIfAbsent(r.teamNumber, () => []).add(r);
      }
      return out;
    }();
    return index[match.matchNumber] ?? const {};
  }

  /// Point the provider at an event and make sure data is available: loads
  /// the cache right away and fetches once per session. Safe to call from
  /// every screen's init; repeat calls are no-ops.
  Future<void> ensureLoaded({required String? eventKey, required String secretKey}) async {
    final key = (eventKey == null || eventKey.isEmpty) ? null : eventKey;
    final secret = secretKey.trim();
    if (key != _eventKey || secret != _secretKey) {
      final gen = ++_generation;
      _eventKey = key;
      _secretKey = secret;
      _scouted = [];
      _matches = [];
      _teamStats = null;
      _byQual = null;
      _error = null;
      notifyListeners();
      if (key == null) return;
      final cachedMatches = await _storage.loadCachedMatchResults(key);
      final cachedScouted =
          secret.isEmpty ? <ScoutedMatch>[] : await _storage.loadCachedScouted(key, secret);
      if (gen != _generation) return;
      // A concurrent caller's fetch may already have landed; don't clobber it.
      if (_matches.isEmpty) _matches = cachedMatches;
      if (_scouted.isEmpty) _scouted = cachedScouted;
      _teamStats = null;
      _byQual = null;
      notifyListeners();
    }
    if (key == null) return;
    await Future.wait([
      if (_fetched.add('matches|$key')) _fetchMatches(key),
      if (secret.isNotEmpty && _fetched.add('scouted|$key|$secret')) _fetchScouted(key, secret),
    ]);
  }

  /// Force a re-fetch of both datasets.
  Future<void> refresh() async {
    final key = _eventKey;
    if (key == null) return;
    await Future.wait([
      _fetchMatches(key),
      if (_secretKey.isNotEmpty) _fetchScouted(key, _secretKey),
    ]);
  }

  Future<void> _fetchScouted(String key, String secret) async {
    final gen = _generation;
    _begin();
    try {
      final rows = await _api.getScoutedMatches(key, secret);
      if (gen == _generation) {
        _scouted = rows;
        _teamStats = null;
        _byQual = null;
        _lastFetched = DateTime.now();
        await _storage.cacheScouted(key, secret, rows);
      }
    } catch (e) {
      debugPrint('EventDataProvider scouted fetch failed: $e');
      // Let a later screen visit try again.
      _fetched.remove('scouted|$key|$secret');
      if (gen == _generation) _error = 'Failed to load scouted results: $e';
    }
    _end();
  }

  Future<void> _fetchMatches(String key) async {
    final gen = _generation;
    _begin();
    try {
      final matches = await _api.getMatchResults(key);
      if (gen == _generation) {
        _matches = matches;
        _lastFetched = DateTime.now();
        await _storage.cacheMatchResults(key, matches);
      }
    } catch (e) {
      debugPrint('EventDataProvider matches fetch failed: $e');
      _fetched.remove('matches|$key');
      if (gen == _generation) _error = 'Failed to load match results: $e';
    }
    _end();
  }

  void _begin() {
    _loadingCount++;
    _error = null;
    notifyListeners();
  }

  void _end() {
    _loadingCount--;
    notifyListeners();
  }
}

extension EventDataContext on BuildContext {
  /// Call from initState / a post-frame callback of any analytics screen.
  /// Syncs [EventDataProvider] with the configured event and secret key and
  /// refreshes pit results once per session.
  void ensureEventData() {
    final app = read<AppStateProvider>();
    read<EventDataProvider>().ensureLoaded(
      eventKey: app.settings.selectedEventKey,
      secretKey: app.settings.secretTeamKey,
    );
    app.ensurePitResultsLoaded();
  }
}
