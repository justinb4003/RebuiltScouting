import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AppStateProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  AppSettings _settings = AppSettings();
  List<TbaEvent> _events = [];
  List<TbaTeam> _teams = [];
  bool _loading = false;
  String? _error;

  AppSettings get settings => _settings;
  List<TbaEvent> get events => _events;
  List<TbaTeam> get teams => _teams;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> init() async {
    _settings = await _storage.loadSettings();
    _events = await _storage.loadCachedEvents();
    if (_settings.selectedEventKey != null) {
      _teams = await _storage.loadCachedTeams(_settings.selectedEventKey!);
    }
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _storage.saveSettings(newSettings);
    notifyListeners();
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
