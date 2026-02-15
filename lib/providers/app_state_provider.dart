import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../models/tba_match.dart';
import '../models/tba_team.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AppStateProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  AppSettings _settings = AppSettings();
  List<TbaEvent> _events = [];
  List<TbaTeam> _teams = [];
  List<TbaMatch> _matches = [];
  bool _loading = false;
  String? _error;
  int _heldDataCount = 0;

  AppSettings get settings => _settings;
  List<TbaEvent> get events => _events;
  List<TbaTeam> get teams => _teams;
  List<TbaMatch> get matches => _matches;
  bool get loading => _loading;
  String? get error => _error;
  int get heldDataCount => _heldDataCount;

  Future<void> init() async {
    _settings = await _storage.loadSettings();
    _events = await _storage.loadCachedEvents();
    if (_settings.selectedEventKey != null) {
      _teams = await _storage.loadCachedTeams(_settings.selectedEventKey!);
      _matches = await _storage.loadCachedMatches(_settings.selectedEventKey!);
    }
    await refreshHeldDataCount();
    notifyListeners();

    // Auto-load events if cache is empty (non-blocking)
    if (_events.isEmpty) {
      loadEvents(_settings.eventYear);
    }
  }

  Future<void> refreshHeldDataCount() async {
    final scout = await _storage.loadHeldScoutData();
    final pit = await _storage.loadHeldPitData();
    _heldDataCount = scout.length + pit.length;
    notifyListeners();
  }

  /// Persist settings to storage without triggering a rebuild.
  Future<void> _persistSettings() async {
    await _storage.saveSettings(_settings);
  }

  /// Persist and notify listeners (triggers rebuild).
  Future<void> saveAndNotify() async {
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  void updateScouterName(String name) {
    _settings.scouterName = name;
  }

  void updateSecretKey(String key) {
    _settings.secretTeamKey = key;
  }

  /// Persist name/key without rebuilding the widget tree.
  Future<void> persistTextFields() async {
    await _persistSettings();
  }

  Future<void> setEventYear(int year) async {
    _settings.eventYear = year;
    await _persistSettings();
    await loadEvents(year);
  }

  Future<void> setEventKey(String key) async {
    _settings.selectedEventKey = key.isEmpty ? null : key;

    // Try to find matching event name
    final match = _events.where((e) => e.key == key);
    _settings.selectedEventName = match.isNotEmpty ? match.first.name : null;

    // Clear old event data immediately so screens don't show stale data
    _teams = [];
    _matches = [];

    await _persistSettings();
    notifyListeners();

    // Auto-load teams and matches when event is set
    if (key.isNotEmpty) {
      await Future.wait([loadTeams(), loadMatches()]);
    }
  }

  Future<void> loadEvents(int year) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _api.getEvents(year);
      await _storage.cacheEvents(_events);
    } catch (e) {
      _error = 'Failed to load events: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadTeams() async {
    if (_settings.selectedEventKey == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _teams = await _api.getTeamsForEvent(_settings.selectedEventKey!);
      await _storage.cacheTeams(_settings.selectedEventKey!, _teams);
    } catch (e) {
      _error = 'Failed to load teams: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMatches() async {
    if (_settings.selectedEventKey == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _matches = await _api.getMatchesForEvent(_settings.selectedEventKey!);
      await _storage.cacheMatches(_settings.selectedEventKey!, _matches);
    } catch (e) {
      _error = 'Failed to load matches: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _storage.clearAll();
    _settings = AppSettings();
    _events = [];
    _teams = [];
    _matches = [];
    _heldDataCount = 0;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
