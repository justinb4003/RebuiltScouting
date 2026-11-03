import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team_location.dart';
import '../models/state_teams.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/robot_note.dart';
import '../models/upload_status.dart';
import 'photo_store.dart';
import '../models/pick_list.dart';
import '../models/pick_board.dart';
import '../models/rankings.dart';
import '../models/match_result.dart';
import '../models/opr.dart';
import '../models/scouted_match.dart';
import '../models/scout_schedule.dart';
import '../models/cluster_config.dart';
import '../models/cluster_result.dart';

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
  static const String _heldUploadStatusKey = 'held_upload_status';
  static const String _pitResultsCacheKey = 'pit_results_cache';
  static const String _pickListCacheKey = 'pick_list_cache';
  static const String _pickBoardCacheKey = 'pick_board_cache';
  static const String _boardFiltersKey = 'pick_board_filters';
  static const String _rankingsCacheKey = 'rankings_cache';
  static const String _scoutedCacheKey = 'scouted_matches_cache';
  static const String _matchResultsCacheKey = 'match_results_cache';
  static const String _oprCacheKey = 'opr_cache';
  static const String _teamLocationsCacheKey = 'team_locations_cache';
  static const String _stateTeamsCacheKey = 'state_teams_cache';
  static const String _collapsedSectionsKey = 'team_details_collapsed';
  static const String _sectionOrderKey = 'team_details_section_order';
  static const String _h2hOrderKey = 'head_to_head_section_order';
  static const String _h2hOpenKey = 'head_to_head_open_sections';
  static const String _h2hTeamsKey = 'head_to_head_teams';
  static const String _clusterTeamConfigKey = 'cluster_config_team';
  static const String _clusterCustomConfigKey = 'cluster_config_custom';
  static const String _clusterResultCacheKey = 'cluster_result_cache';
  static const String _scheduleCacheKey = 'scout_schedule_cache';
  static const String _scheduleSetupKey = 'schedule_builder_setup';
  static const String _scheduleShiftsKey = 'schedule_builder_shifts_per_person';
  static const String _scheduleMaxMatchesKey = 'schedule_builder_max_matches';
  static const String _calendarTokensKey = 'scouter_calendar_tokens';

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
    await _setString(prefs, cacheKey, jsonEncode(cache));
  }

  Future<void> clearAll() => _locked(() async {
        final prefs = await _getPrefs();
        await prefs.clear();
        try {
          await clearPhotos();
        } catch (e) {
          debugPrint('Clearing held photos failed: $e');
        }
      });

  // Held (unsent) data. Every change is a read-modify-write of one list, so
  // they all run one at a time through _locked; otherwise a submit and an
  // upload removing another item could each save a stale copy and drop data.
  Future<void> _heldLock = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _heldLock.then((_) => action());
    _heldLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<T>> _loadHeld<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(key);
    if (json == null) return [];
    final List<dynamic> data = jsonDecode(json);
    return [for (final e in data) fromJson(Map<String, dynamic>.from(e))];
  }

  Future<void> _editHeld(String key, void Function(List<dynamic> items) edit) =>
      _locked(() => _editHeldUnlocked(key, edit));

  Future<void> _editHeldUnlocked(
      String key, void Function(List<dynamic> items) edit) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(key);
    final List<dynamic> items = json == null ? [] : jsonDecode(json);
    edit(items);
    await _setString(prefs, key, jsonEncode(items));
  }

  // SharedPreferences updates its in-memory copy before writing, so when
  // localStorage throws (quota full) reads would keep returning data that was
  // never stored. Re-sync from storage before passing the error on.
  Future<void> _setString(SharedPreferences prefs, String key, String value) async {
    try {
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Saving $key (${value.length} chars) failed: $e');
      await prefs.reload();
      rethrow;
    }
  }

  Future<void> _addHeld(String key, Map<String, dynamic> item) =>
      _editHeld(key, (items) => items.add(item));

  Future<void> _removeHeld(String key, String id) async {
    await _editHeld(key, (items) => items.removeWhere((e) => e['id'] == id));
    await _editUploadStatus((status) => status.remove(id));
  }

  // Upload attempts per held id (see UploadStatus).
  Future<Map<String, UploadStatus>> loadUploadStatus() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_heldUploadStatusKey);
    if (json == null) return {};
    final Map<String, dynamic> data = jsonDecode(json);
    return {
      for (final e in data.entries)
        e.key: UploadStatus.fromJson(Map<String, dynamic>.from(e.value)),
    };
  }

  Future<void> recordUploadFailure(String id, String error) =>
      _editUploadStatus((status) {
        final prev = status[id] == null
            ? null
            : UploadStatus.fromJson(Map<String, dynamic>.from(status[id]));
        status[id] = UploadStatus(
          attempts: (prev?.attempts ?? 0) + 1,
          lastError: error,
          lastAttempt: DateTime.now(),
        ).toJson();
      });

  Future<void> _editUploadStatus(void Function(Map<String, dynamic>) edit) =>
      _locked(() async {
        final prefs = await _getPrefs();
        final json = prefs.getString(_heldUploadStatusKey);
        final Map<String, dynamic> status = json == null ? {} : jsonDecode(json);
        edit(status);
        await _setString(prefs, _heldUploadStatusKey, jsonEncode(status));
      });

  // Held scout data
  Future<List<ScoutResult>> loadHeldScoutData() =>
      _loadHeld(_heldScoutDataKey, ScoutResult.fromJson);

  Future<void> addHeldScoutResult(ScoutResult result) =>
      _addHeld(_heldScoutDataKey, result.toJson());

  Future<void> removeHeldScoutResult(String id) =>
      _removeHeld(_heldScoutDataKey, id);

  // Held pit data. Photos would fill localStorage's ~5 MB within a few dozen
  // records, so on the web they go to the photo store (IndexedDB) under the
  // record's id and the record only keeps heldPhotoKey. If the photo store
  // write fails the photo stays inline: never drop a photo.
  Future<List<PitResult>> loadHeldPitData() =>
      _loadHeld(_heldPitDataKey, PitResult.fromJson);

  /// Fills in [result]'s photo from the photo store before it's posted.
  /// Throws [PhotoStoreException] when the store can't be read.
  Future<void> loadHeldPhoto(PitResult result) async {
    if (!result.photoInStore || result.photoBase64 != null) return;
    result.photoBase64 = await getPhoto(result.id);
    if (result.photoBase64 == null) {
      debugPrint('Held photo for ${result.id} is missing; posting without it');
    }
  }

  Future<void> addHeldPitResult(PitResult result) => _locked(() async {
        final json = await _movePhotoToStore(result.toJson(), result.photoBase64);
        try {
          await _editHeldUnlocked(_heldPitDataKey, (items) => items.add(json));
        } catch (e) {
          if (json[heldPhotoKey] == true) await _deletePhoto(result.id);
          rethrow;
        }
      });

  Future<void> removeHeldPitResult(String id) async {
    await _removeHeld(_heldPitDataKey, id);
    await _deletePhoto(id);
  }

  /// [json] with its photo moved to the photo store, or unchanged if there's
  /// no store or the write failed.
  Future<Map<String, dynamic>> _movePhotoToStore(
      Map<String, dynamic> json, String? photo) async {
    final id = json['id'];
    if (!photoStoreAvailable || photo == null || id is! String) return json;
    try {
      await putPhoto(id, photo);
    } catch (e) {
      debugPrint('Photo store write for $id failed, keeping it inline: $e');
      return json;
    }
    return {...json, 'images': <String>[], heldPhotoKey: true};
  }

  Future<void> _deletePhoto(String id) async {
    try {
      await deletePhoto(id);
    } catch (e) {
      // Swept up by migrateHeldPhotos on the next start.
      debugPrint('Deleting held photo $id failed: $e');
    }
  }

  /// Run once at startup: moves photos still inline in held records (saved
  /// before the photo store, or when it failed) into the store, then drops
  /// stored photos whose record is gone. Never throws.
  Future<void> migrateHeldPhotos() => _locked(() async {
        if (!photoStoreAvailable) return;
        try {
          final prefs = await _getPrefs();
          final json = prefs.getString(_heldPitDataKey);
          final List<dynamic> items = json == null ? [] : jsonDecode(json);
          var moved = false;
          for (var i = 0; i < items.length; i++) {
            final item = Map<String, dynamic>.from(items[i]);
            if (item[heldPhotoKey] == true) continue;
            final updated = await _movePhotoToStore(
                item, PitResult.fromJson(item).photoBase64);
            if (!identical(updated, item)) {
              items[i] = updated;
              moved = true;
            }
          }
          // If this write fails the photos are both inline and stored; the
          // sweep below keeps them since their records still exist.
          if (moved) await _setString(prefs, _heldPitDataKey, jsonEncode(items));

          final heldIds = {for (final item in items) item['id']};
          for (final id in await photoIds()) {
            if (!heldIds.contains(id)) await _deletePhoto(id);
          }
        } catch (e) {
          debugPrint('Moving held photos to the photo store failed: $e');
        }
      });

  // Held robot notes
  Future<List<RobotNote>> loadHeldRobotNotes() =>
      _loadHeld(_heldRobotNoteKey, RobotNote.fromJson);

  Future<void> addHeldRobotNote(RobotNote note) =>
      _addHeld(_heldRobotNoteKey, note.toJson());

  Future<void> removeHeldRobotNote(String id) =>
      _removeHeld(_heldRobotNoteKey, id);

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

  // Board tab filters (per event): minimum votes and excluded voter keys
  Future<({int minVotes, Set<String> excluded})> loadBoardFilters(
      String eventKey) async {
    final data = await _loadPerEvent(_boardFiltersKey, eventKey);
    if (data.isEmpty) return (minVotes: 1, excluded: <String>{});
    final m = Map<String, dynamic>.from(data.first);
    return (
      minVotes: (m['minVotes'] as num?)?.toInt() ?? 1,
      excluded: {for (final k in (m['excluded'] ?? []) as List) k as String},
    );
  }

  Future<void> saveBoardFilters(
      String eventKey, int minVotes, Set<String> excluded) async {
    await _cachePerEvent(_boardFiltersKey, eventKey, [
      {'minVotes': minVotes, 'excluded': excluded.toList()..sort()}
    ]);
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

  Future<TeamLocations?> loadCachedTeamLocations(String eventKey) async {
    final data = await _loadPerEvent(_teamLocationsCacheKey, eventKey);
    return data.isEmpty
        ? null
        : TeamLocations.fromJson(Map<String, dynamic>.from(data.first));
  }

  Future<void> cacheTeamLocations(String eventKey, TeamLocations data) =>
      _cachePerEvent(_teamLocationsCacheKey, eventKey, [data.toJson()]);

  // Statewide team lists, keyed like '4003|2026|loc' (team, season, with
  // hometowns or not) rather than by event.
  Future<StateTeams?> loadCachedStateTeams(String key) async {
    final data = await _loadPerEvent(_stateTeamsCacheKey, key);
    return data.isEmpty
        ? null
        : StateTeams.fromJson(Map<String, dynamic>.from(data.first));
  }

  Future<void> cacheStateTeams(String key, StateTeams data) =>
      _cachePerEvent(_stateTeamsCacheKey, key, [data.toJson()]);

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

  // Schedule Builder setup on this device (per event + secret key): who's
  // scouting, the groups, and the block length.
  Future<Map<String, dynamic>?> loadScheduleSetup(String eventKey, String secretKey) async {
    final data = await _loadPerEvent(_scheduleSetupKey, '$eventKey|$secretKey');
    return data.isEmpty ? null : Map<String, dynamic>.from(data.first);
  }

  Future<void> saveScheduleSetup(String eventKey, String secretKey, Map<String, dynamic> setup) =>
      _cachePerEvent(_scheduleSetupKey, '$eventKey|$secretKey', [setup]);

  // Schedule Builder preferences on this device (every event): shifts per
  // person and the most matches anyone should scout.
  Future<({int? shiftsPerPerson, int? maxMatches})> loadSchedulePrefs() async {
    final prefs = await _getPrefs();
    return (
      shiftsPerPerson: prefs.getInt(_scheduleShiftsKey),
      maxMatches: prefs.getInt(_scheduleMaxMatchesKey),
    );
  }

  Future<void> saveScheduleShiftsPerPerson(int shifts) async =>
      (await _getPrefs()).setInt(_scheduleShiftsKey, shifts);

  Future<void> saveScheduleMaxMatches(int max) async =>
      (await _getPrefs()).setInt(_scheduleMaxMatchesKey, max);

  // Match-scouting schedule (per event + secret key): published schedules and
  // registered scouters, so the schedule is readable offline.
  Future<({List<ScoutSchedule> schedules, List<ScouterInfo> scouters})?> loadCachedSchedule(
      String eventKey, String secretKey) async {
    final data = await _loadPerEvent(_scheduleCacheKey, '$eventKey|$secretKey');
    if (data.isEmpty) return null;
    final m = Map<String, dynamic>.from(data.first);
    return (
      schedules: [
        for (final j in (m['schedules'] as List? ?? const []))
          ScoutSchedule.fromJson(Map<String, dynamic>.from(j)),
      ],
      scouters: [
        for (final j in (m['scouters'] as List? ?? const []))
          ScouterInfo.fromJson(Map<String, dynamic>.from(j)),
      ],
    );
  }

  Future<void> cacheSchedule(String eventKey, String secretKey,
      List<ScoutSchedule> schedules, List<ScouterInfo> scouters) async {
    await _cachePerEvent(_scheduleCacheKey, '$eventKey|$secretKey', [
      {
        'schedules': [for (final s in schedules) s.toJson()],
        'scouters': [for (final s in scouters) s.toJson()],
      }
    ]);
  }

  /// Calendar tokens from RegisterScouter, keyed by "secret|event|namekey".
  /// A token being here also means this device already registered the name.
  Future<Map<String, String>> loadCalendarTokens() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_calendarTokensKey);
    if (json == null) return {};
    return Map<String, String>.from(jsonDecode(json));
  }

  Future<void> setCalendarToken(String key, String token) => _locked(() async {
        final prefs = await _getPrefs();
        final json = prefs.getString(_calendarTokensKey);
        final tokens = json == null ? <String, dynamic>{} : jsonDecode(json) as Map<String, dynamic>;
        tokens[key] = token;
        await _setString(prefs, _calendarTokensKey, jsonEncode(tokens));
      });

  // Team Details layout: collapsed sections per team, one section order.
  Future<Set<String>> loadCollapsedSections(int team) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_collapsedSectionsKey);
    if (json == null) return {};
    final List<dynamic>? ids = (jsonDecode(json) as Map<String, dynamic>)['$team'];
    return {for (final id in ids ?? const []) id as String};
  }

  Future<void> saveCollapsedSections(int team, Set<String> ids) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_collapsedSectionsKey);
    final all = json == null ? <String, dynamic>{} : jsonDecode(json) as Map<String, dynamic>;
    if (ids.isEmpty) {
      all.remove('$team');
    } else {
      all['$team'] = ids.toList()..sort();
    }
    await prefs.setString(_collapsedSectionsKey, jsonEncode(all));
  }

  Future<List<String>> loadSectionOrder() async =>
      (await _getPrefs()).getStringList(_sectionOrderKey) ?? const [];

  Future<void> saveSectionOrder(List<String> order) async =>
      (await _getPrefs()).setStringList(_sectionOrderKey, order);

  // Head to Head layout (section order, open sections) and teams per event.
  Future<(List<String>, Set<String>?)> loadHeadToHeadLayout() async {
    final prefs = await _getPrefs();
    final open = prefs.getStringList(_h2hOpenKey);
    return (prefs.getStringList(_h2hOrderKey) ?? const <String>[], open?.toSet());
  }

  Future<void> saveHeadToHeadLayout(List<String> order, Set<String> open) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(_h2hOrderKey, order);
    await prefs.setStringList(_h2hOpenKey, open.toList()..sort());
  }

  Future<List<int>> loadHeadToHeadTeams(String eventKey) async {
    final json = (await _getPrefs()).getString(_h2hTeamsKey);
    if (json == null) return [];
    final List<dynamic>? teams = (jsonDecode(json) as Map<String, dynamic>)[eventKey];
    return [for (final t in teams ?? const []) t as int];
  }

  Future<void> saveHeadToHeadTeams(String eventKey, List<int> teams) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_h2hTeamsKey);
    final all = json == null ? <String, dynamic>{} : jsonDecode(json) as Map<String, dynamic>;
    all[eventKey] = teams;
    await prefs.setString(_h2hTeamsKey, jsonEncode(all));
  }

  Future<OprData> loadCachedOpr(String eventKey) async =>
      oprFromJson(await _loadPerEvent(_oprCacheKey, eventKey));

  Future<void> cacheOpr(String eventKey, OprData opr) async {
    await _cachePerEvent(_oprCacheKey, eventKey,
        [for (final e in opr.entries) {'teamNumber': e.key, ...e.value}]);
  }

  Future<List<dynamic>> _loadPerEvent(String cacheKey, String eventKey) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(cacheKey);
    if (json == null) return [];
    final Map<String, dynamic> cache = jsonDecode(json);
    return (cache[eventKey] as List<dynamic>?) ?? [];
  }

  // Cluster settings are per season ({year: config}); a null custom config
  // means "follow the team default".
  Future<ClusterConfig?> loadClusterConfig(String year, {required bool custom}) async {
    final json = (await _getPrefs())
        .getString(custom ? _clusterCustomConfigKey : _clusterTeamConfigKey);
    final entry = json == null ? null : (jsonDecode(json) as Map<String, dynamic>)[year];
    return entry == null ? null : ClusterConfig.fromJson(entry);
  }

  Future<void> saveClusterConfig(String year, ClusterConfig? config, {required bool custom}) async {
    final prefs = await _getPrefs();
    final key = custom ? _clusterCustomConfigKey : _clusterTeamConfigKey;
    final json = prefs.getString(key);
    final all = json == null ? <String, dynamic>{} : jsonDecode(json) as Map<String, dynamic>;
    if (config == null) {
      all.remove(year);
    } else {
      all[year] = config.toJson();
    }
    await prefs.setString(key, jsonEncode(all));
  }

  /// Last clustering for an event, tagged with the settings that made it
  /// ([tag]); a different tag means the cache is stale.
  Future<ClusterResult?> loadCachedClusters(String eventKey, String tag) async {
    final json = (await _getPrefs()).getString(_clusterResultCacheKey);
    if (json == null) return null;
    final entry = (jsonDecode(json) as Map<String, dynamic>)[eventKey];
    if (entry == null || entry['tag'] != tag) return null;
    return ClusterResult.fromJson(entry['result'] as Map<String, dynamic>);
  }

  Future<void> cacheClusters(String eventKey, String tag, ClusterResult result) async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_clusterResultCacheKey);
    final all = json == null ? <String, dynamic>{} : jsonDecode(json) as Map<String, dynamic>;
    all[eventKey] = {'tag': tag, 'result': result.json};
    await _setString(prefs, _clusterResultCacheKey, jsonEncode(all));
  }
}
