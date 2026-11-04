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

  // Builder setup (saved on this device per event + key): who's scouting,
  // and the groups.
  Set<String> _roster = {};
  // People who scout together (2–6 each).
  List<ScoutGroup> _groups = [];
  // Preferences on this device, for every event.
  int _shiftsPerPerson = 3;
  int _maxMatches = 10;
  ScheduleOptions _options = const ScheduleOptions();
  bool _prefsLoaded = false;

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

  /// Names ticked as scouting at this event (registered or added by hand).
  Set<String> get roster => _roster;
  List<ScoutGroup> get groups => _groups;
  /// How many blocks each person scouts; sets how many blocks there are.
  int get shiftsPerPerson => _shiftsPerPerson;
  /// The most qualification matches anyone should scout; more is a problem.
  int get maxMatches => _maxMatches;
  /// How Generate works (the Algorithm dialog).
  ScheduleOptions get options => _options;

  void setOptions(ScheduleOptions options) {
    _options = options;
    notifyListeners();
    _storage.saveScheduleOptions(options.toJson());
  }

  void setRoster(Set<String> roster) {
    _roster = Set.of(roster);
    // Drop people no longer scouting from the groups, and groups left with
    // fewer than two.
    _groups = [
      for (final g in _groups) [for (final n in g) if (_roster.contains(n)) n],
    ]..removeWhere((g) => g.length < 2);
    _saveSetup();
  }

  void setGroups(List<ScoutGroup> groups) {
    _groups = [for (final g in groups) List.of(g)];
    _saveSetup();
  }

  void setShiftsPerPerson(int shifts) {
    _shiftsPerPerson = shifts;
    notifyListeners();
    _storage.saveScheduleShiftsPerPerson(shifts);
  }

  void setMaxMatches(int max) {
    _maxMatches = max;
    notifyListeners();
    _storage.saveScheduleMaxMatches(max);
  }

  Future<void> _loadPrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    final p = await _storage.loadSchedulePrefs();
    _shiftsPerPerson = p.shiftsPerPerson ?? _shiftsPerPerson;
    _maxMatches = p.maxMatches ?? _maxMatches;
    if (p.options != null) _options = ScheduleOptions.fromJson(p.options!);
  }

  void _saveSetup() {
    notifyListeners();
    final eventKey = _eventKey, secretKey = _secretKey;
    if (eventKey == null || secretKey == null) return;
    _storage.saveScheduleSetup(eventKey, secretKey, {
      'roster': _roster.toList(),
      'groups': _groups,
    });
  }

  Future<void> _loadSetup(String eventKey, String secretKey) async {
    final setup = await _storage.loadScheduleSetup(eventKey, secretKey);
    if (_eventKey != eventKey || _secretKey != secretKey) return;
    _roster = {for (final n in (setup?['roster'] as List? ?? const [])) n.toString()};
    _groups = [
      for (final g in (setup?['groups'] as List? ?? const []))
        if (g is List) [for (final n in g) n.toString()],
    ];
  }

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
      _roster = {};
      _groups = [];
      await _loadPrefs();
      await _loadSetup(eventKey, secretKey);
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
  /// Publish the draft. A [timeOffset] makes it a practice run (schedule
  /// test mode): every match time moved by that much.
  Future<void> publish(String publishedBy, {Duration timeOffset = Duration.zero}) async {
    final eventKey = _eventKey, secretKey = _secretKey;
    if (eventKey == null || secretKey == null) throw StateError('No event');
    final saved = await _api.publishSchedule(
      secretKey: secretKey,
      eventKey: eventKey,
      publishedBy: publishedBy,
      shifts: draft,
      timeOffset: timeOffset,
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
