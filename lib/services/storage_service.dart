import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';

class StorageService {
  static const String _settingsKey = 'app_settings';
  static const String _eventListKey = 'event_list';
  static const String _eventTeamsCacheKey = 'event_teams_cache';
  static const String _eventMatchesCacheKey = 'event_matches_cache';
  static const String _heldScoutDataKey = 'held_scout_data';
  static const String _heldPitDataKey = 'held_pit_data';

  // Settings
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      return AppSettings.fromJson(jsonDecode(json));
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // Event list cache
  Future<List<TbaEvent>> loadCachedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_eventListKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => TbaEvent.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> cacheEvents(List<TbaEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _eventListKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  // Team list cache (per event)
  Future<List<TbaTeam>> loadCachedTeams(String eventKey) async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_eventTeamsCacheKey);
    Map<String, dynamic> cache = {};
    if (json != null) {
      cache = jsonDecode(json);
    }
    cache[eventKey] = teams.map((t) => t.toJson()).toList();
    await prefs.setString(_eventTeamsCacheKey, jsonEncode(cache));
  }

  // Match list cache (per event)
  Future<List<TbaMatch>> loadCachedMatches(String eventKey) async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_eventMatchesCacheKey);
    Map<String, dynamic> cache = {};
    if (json != null) {
      cache = jsonDecode(json);
    }
    cache[eventKey] = matches.map((m) => m.toJson()).toList();
    await prefs.setString(_eventMatchesCacheKey, jsonEncode(cache));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Held scout data
  Future<List<ScoutResult>> loadHeldScoutData() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_heldScoutDataKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => ScoutResult.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> saveHeldScoutData(List<ScoutResult> results) async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_heldPitDataKey);
    if (json != null) {
      final List<dynamic> data = jsonDecode(json);
      return data.map((e) => PitResult.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> saveHeldPitData(List<PitResult> results) async {
    final prefs = await SharedPreferences.getInstance();
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
}
