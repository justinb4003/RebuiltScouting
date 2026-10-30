import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/robot_note.dart';
import '../models/pick_list.dart';
import '../models/pick_board.dart';
import '../models/rankings.dart';
import '../models/match_result.dart';
import '../models/scouted_match.dart';

class StorageService {
  static final instance = StorageService();

  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async => _prefs ??= await SharedPreferences.getInstance();

  static const String _settingsKey = 'app_settings';
  static const String _eventListKey = 'event_list';
  static const String _eventTeamsCacheKey = 'event_teams_cache';
  static const String _eventMatchesCacheKey = 'event_matches_cache';
  static const String _heldScoutDataKey = 'held_scout_data';
  static const String _heldPitDataKey = 'held_pit_data';
  static const String _heldRobotNoteKey = 'held_robot_note_data';
  static const String _pitResultsCacheKey = 'pit_results_cache';
  static const String _pickListCacheKey = 'pick_list_cache';
  static const String _pickBoardCacheKey = 'pick_board_cache';
  static const String _rankingsCacheKey = 'rankings_cache';
  static const String _scoutedCacheKey = 'scouted_matches_cache';
  static const String _matchResultsCacheKey = 'match_results_cache';

  // Settings
  Future<AppSettings> loadSettings() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      return AppSettings.fromJson(jsonDecode(json));
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _getPrefs();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // Event list cache
  Future<List<TbaEvent>> loadCachedEvents() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_eventListKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => TbaEvent.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> cacheEvents(List<TbaEvent> events) async {
    final prefs = await _getPrefs();
    await prefs.setString(
        _eventListKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  // Team list cache (per event)
  Future<List<TbaTeam>> loadCachedTeams(String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_eventTeamsCacheKey);
    if (json != null) {
      final Map<String, dynamic> cache = jsonDecode(json);
      if (cache.containsKey(eventKey)) {
        final List<dynamic> data = cache[eventKey];
        return data.map((e) => TbaTeam.fromJson(e)).toList();
      }
    }
    return [];
  }

  Future<void> cacheTeams(String eventKey, List<TbaTeam> teams) async {
    await _cachePerEvent(
        _eventTeamsCacheKey, eventKey, teams.map((t) => t.toJson()).toList());
  }

  // Match list cache (per event)
  Future<List<TbaMatch>> loadCachedMatches(String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_eventMatchesCacheKey);
    if (json != null) {
      final Map<String, dynamic> cache = jsonDecode(json);
      if (cache.containsKey(eventKey)) {
        final List<dynamic> data = cache[eventKey];
        return data.map((e) => TbaMatch.fromJson(e)).toList();
      }
    }
    return [];
  }

  Future<void> cacheMatches(String eventKey, List<TbaMatch> matches) async {
    await _cachePerEvent(_eventMatchesCacheKey, eventKey,
        matches.map((m) => m.toJson()).toList());
  }

  Future<void> _cachePerEvent(
      String cacheKey, String eventKey, List<Map<String, dynamic>> data) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(cacheKey);
    Map<String, dynamic> cache = {};
    if (json != null) {
      cache = jsonDecode(json);
    }
    cache[eventKey] = data;
    await prefs.setString(cacheKey, jsonEncode(cache));
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }

  // Held scout data
  Future<List<ScoutResult>> loadHeldScoutData() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_heldScoutDataKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => ScoutResult.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> saveHeldScoutData(List<ScoutResult> results) async {
    final prefs = await _getPrefs();
    await prefs.setString(
        _heldScoutDataKey, jsonEncode(results.map((r) => r.toJson()).toList()));
  }

  Future<void> addHeldScoutResult(ScoutResult result) async {
    final held = await loadHeldScoutData();
    held.add(result);
    await saveHeldScoutData(held);
  }

  Future<void> removeHeldScoutResult(String id) async {
    final held = await loadHeldScoutData();
    held.removeWhere((r) => r.id == id);
    await saveHeldScoutData(held);
  }

  // Held pit data
  Future<List<PitResult>> loadHeldPitData() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_heldPitDataKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => PitResult.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> saveHeldPitData(List<PitResult> results) async {
    final prefs = await _getPrefs();
    await prefs.setString(
        _heldPitDataKey, jsonEncode(results.map((r) => r.toJson()).toList()));
  }

  Future<void> addHeldPitResult(PitResult result) async {
    final held = await loadHeldPitData();
    held.add(result);
    await saveHeldPitData(held);
  }

  Future<void> removeHeldPitResult(String id) async {
    final held = await loadHeldPitData();
    held.removeWhere((r) => r.id == id);
    await saveHeldPitData(held);
  }

  // Held robot notes
  Future<List<RobotNote>> loadHeldRobotNotes() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_heldRobotNoteKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => RobotNote.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> saveHeldRobotNotes(List<RobotNote> notes) async {
    final prefs = await _getPrefs();
    await prefs.setString(
        _heldRobotNoteKey, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  Future<void> addHeldRobotNote(RobotNote note) async {
    final held = await loadHeldRobotNotes();
    held.add(note);
    await saveHeldRobotNotes(held);
  }

  Future<void> removeHeldRobotNote(String id) async {
    final held = await loadHeldRobotNotes();
    held.removeWhere((n) => n.id == id);
    await saveHeldRobotNotes(held);
  }

  // Pit results cache (per event)
  Future<List<PitResult>> loadCachedPitResults(String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_pitResultsCacheKey);
    if (json != null) {
      final Map<String, dynamic> cache = jsonDecode(json);
      if (cache.containsKey(eventKey)) {
        final List<dynamic> data = cache[eventKey];
        return data.map((e) => PitResult.fromJson(e)).toList();
      }
    }
    return [];
  }

  Future<void> cachePitResults(String eventKey, List<PitResult> results) async {
    await _cachePerEvent(
        _pitResultsCacheKey, eventKey, results.map((r) => r.toJson()).toList());
  }

  // Pick list cache (per event) so the list is readable offline
  Future<PickList?> loadCachedPickList(String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_pickListCacheKey);
    if (json != null) {
      final Map<String, dynamic> cache = jsonDecode(json);
      final List<dynamic>? data = cache[eventKey];
      if (data != null && data.isNotEmpty) return PickList.fromJson(data.first);
    }
    return null;
  }

  Future<void> cachePickList(String eventKey, PickList list) async {
    await _cachePerEvent(_pickListCacheKey, eventKey, [list.toJson()]);
  }

  // Pick board cache (per event) so everyone's lists are readable offline
  Future<PickBoard?> loadCachedPickBoard(String eventKey) async {
    final data = await _loadPerEvent(_pickBoardCacheKey, eventKey);
    return data.isEmpty
        ? null
        : PickBoard.fromJson(Map<String, dynamic>.from(data.first));
  }

  Future<void> cachePickBoard(String eventKey, PickBoard board) async {
    await _cachePerEvent(_pickBoardCacheKey, eventKey, [board.toJson()]);
  }

  // Rankings cache (per event) so the table is readable offline
  Future<RankingsData?> loadCachedRankings(String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_rankingsCacheKey);
    if (json != null) {
      final Map<String, dynamic> cache = jsonDecode(json);
      final List<dynamic>? data = cache[eventKey];
      if (data != null && data.isNotEmpty) return RankingsData.fromJson(data.first);
    }
    return null;
  }

  Future<void> cacheRankings(String eventKey, RankingsData data) async {
    await _cachePerEvent(_rankingsCacheKey, eventKey, [data.toJson()]);
  }

  // Scouted match rows (trimmed) and official match results, per event.
  // Scouted rows are also keyed by secret team key since each team only
  // sees its own.
  Future<List<ScoutedMatch>> loadCachedScouted(String eventKey, String secretKey) async {
    final data = await _loadPerEvent(_scoutedCacheKey, '$eventKey|$secretKey');
    return [for (final e in data) ScoutedMatch.fromJson(Map<String, dynamic>.from(e))];
  }

  Future<void> cacheScouted(String eventKey, String secretKey, List<ScoutedMatch> rows) async {
    await _cachePerEvent(
        _scoutedCacheKey, '$eventKey|$secretKey', rows.map((r) => r.toJson()).toList());
  }

  Future<List<MatchResult>> loadCachedMatchResults(String eventKey) async {
    final data = await _loadPerEvent(_matchResultsCacheKey, eventKey);
    return [for (final e in data) MatchResult.fromJson(Map<String, dynamic>.from(e))];
  }

  Future<void> cacheMatchResults(String eventKey, List<MatchResult> matches) async {
    await _cachePerEvent(
        _matchResultsCacheKey, eventKey, matches.map((m) => m.toJson()).toList());
  }

  Future<List<dynamic>> _loadPerEvent(String cacheKey, String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(cacheKey);
    if (json == null) return [];
    final Map<String, dynamic> cache = jsonDecode(json);
    return (cache[eventKey] as List<dynamic>?) ?? [];
  }
}
