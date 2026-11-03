import 'package:flutter/foundation.dart';
import '../models/scout_schedule.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Match-scouting schedule: the newest published schedule and the registered
/// scouters. The cached copy shows immediately, the API is hit at most once
/// automatically per app session per event, and [refresh] forces a re-fetch.
/// Also holds the Schedule Builder's unpublished draft so it survives leaving
/// the screen.
class ScheduleProvider extends ChangeNotifier {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  String? _eventKey;
  String? _secretKey;
  List<ScoutSchedule> _schedules = [];
  List<ScouterInfo> _scouters = [];
  bool _loading = false;
  String? _error;
  final Set<String> _autoFetched = {};

  // Builder draft, per event + secret key. null = not started yet.
  List<Shift>? _draft;
  ScoutSchedule? _draftSource;

  /// All published schedules for this key + event, newest first.
  List<ScoutSchedule> get schedules => _schedules;
  ScoutSchedule? get newest => _schedules.isEmpty ? null : _schedules.first;
  List<ScouterInfo> get scouters => _scouters;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasDraft => _draft != null;
  List<Shift> get draft => _draft ?? const [];

  /// The published schedule the draft started from, or null when it began
  /// empty.
  ScoutSchedule? get draftSource => _draftSource;

  void setDraft(List<Shift> shifts) {
    _draft = List.of(shifts);
    notifyListeners();
  }

  /// Begin a draft from the newest published schedule (or empty), unless one
  /// is already in progress.
  void startDraftIfNeeded() {
    if (_draft != null) return;
    final s = newest;
    _draft = s == null ? [] : List.of(s.shifts);
    _draftSource = s;
  }

  /// Called when a screen opens (or the event/key changes).
  Future<void> load(String eventKey, String secretKey) async {
    if (eventKey.isEmpty || secretKey.isEmpty) return;
    if (_eventKey != eventKey || _secretKey != secretKey) {
      _eventKey = eventKey;
      _secretKey = secretKey;
      _schedules = [];
      _scouters = [];
      _draft = null;
      _draftSource = null;
      _error = null;
      notifyListeners();
      final cached = await _storage.loadCachedSchedule(eventKey, secretKey);
      if (_eventKey != eventKey || _secretKey != secretKey) return;
      if (cached != null) {
        _schedules = cached.schedules;
        _scouters = cached.scouters;
      }
      notifyListeners();
    }
    if (_autoFetched.add('$eventKey|$secretKey')) await _fetch();
  }

  Future<void> refresh() async {
    if (_eventKey == null) return;
    _autoFetched.add('$_eventKey|$_secretKey');
    await _fetch();
  }

  Future<void> _fetch() async {
    final eventKey = _eventKey, secretKey = _secretKey;
    if (_loading || eventKey == null || secretKey == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getSchedules(secretKey, eventKey),
        _api.getScouters(secretKey, eventKey),
      ]);
      if (_eventKey == eventKey && _secretKey == secretKey) {
        _schedules = results[0] as List<ScoutSchedule>;
        _scouters = results[1] as List<ScouterInfo>;
        await _storage.cacheSchedule(eventKey, secretKey, _schedules, _scouters);
      }
    } catch (e) {
      debugPrint('Schedule fetch failed: $e');
      _error = 'Could not load the schedule. ${_schedules.isNotEmpty ? 'Showing saved data.' : ''}'.trim();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Publish the draft as [publishedBy]. Throws on failure.
  Future<void> publish(String publishedBy) async {
    final eventKey = _eventKey, secretKey = _secretKey;
    if (eventKey == null || secretKey == null) throw StateError('No event');
    final saved = await _api.publishSchedule(
      secretKey: secretKey,
      eventKey: eventKey,
      publishedBy: publishedBy,
      shifts: draft,
    );
    // One schedule per publisher: replace theirs, keep newest first.
    _schedules = [
      saved,
      for (final s in _schedules)
        if (nameKey(s.publishedBy) != nameKey(saved.publishedBy)) s,
    ];
    _draftSource = saved;
    await _storage.cacheSchedule(eventKey, secretKey, _schedules, _scouters);
    notifyListeners();
  }
}
