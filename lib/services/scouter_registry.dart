import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/scout_schedule.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Tells the API which scouter names are in use (so the schedule builder can
/// offer them) once per secret key + event + name per device, and keeps the
/// calendar token the API hands back.
class ScouterRegistry {
  static final instance = ScouterRegistry();

  final _api = ApiService.instance;
  final _storage = StorageService.instance;
  Timer? _timer;
  bool _busy = false;

  static String _combo(String secretKey, String eventKey, String name) =>
      '$secretKey|$eventKey|${nameKey(name)}';

  /// Settings were saved or changed. Waits a few seconds so a name that is
  /// still being typed isn't registered half-finished.
  void settingsChanged(AppSettings Function() current) {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () => registerIfNeeded(current()));
  }

  /// Register now if there's a name, key and event and this combination
  /// hasn't been sent from this device yet. Never throws; a failure is
  /// retried the next time the app starts or settings change.
  Future<void> registerIfNeeded(AppSettings s) async {
    final name = s.scouterName.trim();
    final key = s.secretTeamKey.trim();
    final event = s.selectedEventKey ?? '';
    if (name.isEmpty || key.isEmpty || event.isEmpty || nameKey(name).isEmpty) return;
    if (_busy) return;
    _busy = true;
    try {
      final tokens = await _storage.loadCalendarTokens();
      final combo = _combo(key, event, name);
      if (tokens.containsKey(combo)) return;
      final token = await _api.registerScouter(secretKey: key, eventKey: event, name: name);
      await _storage.setCalendarToken(combo, token);
    } catch (e) {
      debugPrint('Registering scouter failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// This scouter's calendar token, registering first if needed. Null when
  /// it can't be had (no name/key/event, or offline).
  Future<String?> calendarToken(AppSettings s) async {
    await registerIfNeeded(s);
    final tokens = await _storage.loadCalendarTokens();
    return tokens[_combo(s.secretTeamKey.trim(), s.selectedEventKey ?? '', s.scouterName)];
  }
}
