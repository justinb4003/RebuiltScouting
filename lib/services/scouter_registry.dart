import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/scout_schedule.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Tells the API which scouter names are in use (so the schedule builder can
/// offer them) once per secret key + event + name per device, with the
/// Slack link token when there is one.
class ScouterRegistry {
  static final instance = ScouterRegistry();

  final _api = ApiService.instance;
  final _storage = StorageService.instance;
  Timer? _timer;
  bool _busy = false;

  /// Called when the API says our Slack link token is no longer valid (the
  /// link was removed elsewhere); the app state clears the local link.
  VoidCallback? onLinkInvalid;

  // A Slack link token appearing makes this a new combination, so the name
  // is registered again with the token.
  static String _combo(AppSettings s, String name) =>
      '${s.secretTeamKey.trim()}|${s.selectedEventKey ?? ''}|${nameKey(name)}'
      '${s.slackLinked ? '|slack' : ''}';

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
      final combo = _combo(s, name);
      if ((await _storage.loadRegisteredScouters()).contains(combo)) return;
      final r = await _api.registerScouter(
          secretKey: key, eventKey: event, name: name, linkToken: s.slackLinkToken);
      await _storage.markScouterRegistered(combo);
      if (r.linkValid == false) onLinkInvalid?.call();
    } catch (e) {
      debugPrint('Registering scouter failed: $e');
    } finally {
      _busy = false;
    }
  }
}
