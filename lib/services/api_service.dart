import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/robot_note.dart';
import '../models/pick_list.dart';
import '../models/pick_board.dart';
import '../models/cluster_config.dart';
import '../models/cluster_result.dart';
import '../models/game_score.dart';
import '../models/team_location.dart';
import '../models/state_teams.dart';
import '../models/rankings.dart';
import '../models/match_result.dart';
import '../models/opr.dart';
import '../models/scouted_match.dart';
import '../models/scout_schedule.dart';

/// The API answered with an error status (the request did get through).
class ApiStatusException implements Exception {
  final int statusCode;
  final String body;
  ApiStatusException(this.statusCode, this.body);

  /// Gateway/overload answers that say nothing about the record itself;
  /// treat them like being offline.
  bool get transient => const {408, 429, 502, 503, 504}.contains(statusCode);

  @override
  String toString() => 'HTTP $statusCode';
}

class ApiService {
  static final instance = ApiService();

  // Override for local dev: --dart-define=API_BASE_URL=http://localhost:7071/api
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://trisonics-scouting-api.azurewebsites.net/api');
  static const _timeout = Duration(seconds: 30);
  // Polls repeat every few seconds; don't let one stall pile up behind it.
  static const _pollTimeout = Duration(seconds: 10);

  Future<List<TbaEvent>> getEvents(int year) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetEvents?year=$year'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => TbaEvent.fromJson(e)).toList();
    }
    throw Exception('Failed to load events: ${response.statusCode}');
  }

  Future<List<TbaTeam>> getTeamsForEvent(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetTeamsForEvent?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => TbaTeam.fromJson(e)).toList()
        ..sort((a, b) => a.teamNumber.compareTo(b.teamNumber));
    }
    throw Exception('Failed to load teams: ${response.statusCode}');
  }

  Future<List<TbaMatch>> getMatchesForEvent(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetMatchesForEvent?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => TbaMatch.fromJson(e)).toList()
        ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    }
    throw Exception('Failed to load matches: ${response.statusCode}');
  }

  // Scouting posts are retried from the held queue, so fail fast on bad
  // Wi-Fi rather than hold the scouter up; photos get longer.
  static const _submitTimeout = Duration(seconds: 15);
  static const _photoSubmitTimeout = Duration(seconds: 30);

  /// Completes when the API accepted [body]. Throws [ApiStatusException] when
  /// it answered with an error, or the http/timeout error when it couldn't
  /// be reached.
  Future<void> _postRecord(String name, String endpoint,
      Map<String, dynamic> body, Duration timeout) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(timeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('$name failed: ${response.statusCode} ${response.body}');
      throw ApiStatusException(response.statusCode, response.body);
    }
  }

  // PostResults and PostPitResults upsert on the record's id, so posting
  // the same held record again is safe.
  Future<void> postResults(ScoutResult result) =>
      _postRecord('postResults', 'PostResults', result.toJson(), _submitTimeout);

  Future<void> postPitResults(PitResult result) => _postRecord(
      'postPitResults',
      'PostPitResults',
      result.toJson(),
      result.photoBase64 == null ? _submitTimeout : _photoSubmitTimeout);

  /// Robot notes are notes-only pit records. PostPitResults upserts by id,
  /// so sending the note's own id (and original time) makes retries safe.
  Future<void> postRobotNote(RobotNote note) => _postRecord('postRobotNote',
      'PostPitResults', {...note.toJson(), 'images': <String>[]}, _submitTimeout);

  /// Returns null when no pick list exists yet for this key + event.
  Future<PickList?> getPickList(String secretKey, String eventKey) async {
    final uri = Uri.parse('$baseUrl/GetScoutingResults').replace(
        queryParameters: {'secret_key': secretKey, 'event_key': eventKey});
    final response = await http.get(uri).timeout(_pollTimeout);
    if (response.statusCode != 200) {
      debugPrint('getPickList failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load pick list: ${response.statusCode}');
    }
    final List<dynamic> docs = jsonDecode(response.body);
    return docs.isEmpty ? null : PickList.fromJson(docs.first);
  }

  Future<PickList> updatePickListTeam({
    required String secretKey,
    required String eventKey,
    required String updatedBy,
    required PickListUpdate update,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/UpdatePickListTeam'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'secret_key': secretKey,
        'event_key': eventKey,
        'updated_by': updatedBy,
        ...update.toJson(),
      }),
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'updatePickListTeam failed: ${response.statusCode} ${response.body}');
      throw Exception('Pick list update failed: ${response.statusCode}');
    }
    return PickList.fromJson(jsonDecode(response.body));
  }

  /// Everyone's personal pick lists plus the shared taken list.
  Future<PickBoard> getPickBoard(String secretKey, String eventKey) async {
    final uri = Uri.parse('$baseUrl/GetPickVotes').replace(
        queryParameters: {'secret_key': secretKey, 'event_key': eventKey});
    final response = await http.get(uri).timeout(_pollTimeout);
    if (response.statusCode != 200) {
      debugPrint('getPickBoard failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load pick board: ${response.statusCode}');
    }
    return PickBoard.fromJson(jsonDecode(response.body));
  }

  /// WebSocket URL for live pick board pushes, or null when the API has
  /// live updates turned off (the app then just polls).
  Future<Uri?> negotiatePickBoard(String secretKey, String eventKey) async {
    final uri = Uri.parse('$baseUrl/NegotiatePickBoard').replace(
        queryParameters: {'secret_key': secretKey, 'event_key': eventKey});
    final response = await http.get(uri).timeout(_pollTimeout);
    if (response.statusCode == 503) return null;
    if (response.statusCode != 200) {
      debugPrint(
          'negotiatePickBoard failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to start live updates: ${response.statusCode}');
    }
    return Uri.parse(jsonDecode(response.body)['url'] as String);
  }

  /// Change one team on [voter]'s own list; returns their updated ballot.
  Future<Ballot> updatePickVote({
    required String secretKey,
    required String eventKey,
    required String voter,
    required PickListUpdate update,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/UpdatePickVote'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'secret_key': secretKey,
        'event_key': eventKey,
        'voter': voter,
        ...update.toJson(),
      }),
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'updatePickVote failed: ${response.statusCode} ${response.body}');
      throw Exception('Pick vote failed: ${response.statusCode}');
    }
    return Ballot.fromJson(jsonDecode(response.body));
  }

  /// Mark a team taken (or not) for everyone; returns the new taken list
  /// and its version.
  Future<(Set<int>, int)> setPickTaken({
    required String secretKey,
    required String eventKey,
    required String updatedBy,
    required int teamNumber,
    required bool taken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/SetPickTaken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'secret_key': secretKey,
        'event_key': eventKey,
        'updated_by': updatedBy,
        'team_number': teamNumber,
        'taken': taken,
      }),
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'setPickTaken failed: ${response.statusCode} ${response.body}');
      throw Exception('Taken update failed: ${response.statusCode}');
    }
    final doc = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      {for (final t in (doc['teams'] ?? []) as List) (t as num).toInt()},
      (doc['version'] as num?)?.toInt() ?? 0,
    );
  }

  // Clustering is slow and only changes when new scouting data lands, so keep
  // results (and in-flight requests) for the app session; only an explicit
  // refresh asks again.
  final _clusterCache = <String, Future<ClusterResult>>{};

  Future<ClusterResult> getClusters({
    required String secretKey,
    required String eventKey,
    required ClusterConfig config,
    bool refresh = false,
  }) {
    final weights = [
      for (final f in config.features)
        if (config.weightOf(f) != 1.0) '$f:${config.weightOf(f)}',
    ];
    final uri = Uri.parse('$baseUrl/GetClusters').replace(queryParameters: {
      'secret_team_key': secretKey,
      'event_key': eventKey,
      'k': '${config.k}',
      if (config.features.isNotEmpty) 'features': config.features.join(','),
      if (weights.isNotEmpty) 'weights': weights.join(','),
    });
    // A refresh means the data changed, so every cached combination is stale.
    if (refresh) _clusterCache.clear();
    final key = uri.toString();
    final cached = _clusterCache[key];
    if (cached != null) return cached;
    final request = _fetchClusters(uri);
    _clusterCache[key] = request;
    // Don't keep failures; the next view should try again.
    request.then<void>((_) {}, onError: (Object _) {
      if (identical(_clusterCache[key], request)) _clusterCache.remove(key);
    });
    return request;
  }

  Future<ClusterResult> _fetchClusters(Uri uri) async {
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getClusters failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load clusters: ${response.statusCode}');
    }
    return ClusterResult.fromJson(jsonDecode(response.body));
  }

  /// The team's published cluster settings for [year], or null if none.
  Future<ClusterConfig?> getClusterConfig({
    required String secretKey,
    required String year,
  }) async {
    final uri = Uri.parse('$baseUrl/GetClusterConfig')
        .replace(queryParameters: {'secret_key': secretKey, 'year': year});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'getClusterConfig failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load team default: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    return json == null ? null : ClusterConfig.fromJson(json);
  }

  /// Replace the team's published cluster settings for [year].
  Future<ClusterConfig> setClusterConfig({
    required String secretKey,
    required String year,
    required ClusterConfig config,
    required String updatedBy,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/SetClusterConfig'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...config.toJson(),
            'secret_key': secretKey,
            'year': year,
            'updated_by': updatedBy,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'setClusterConfig failed: ${response.statusCode} ${response.body}');
      throw Exception('Publishing failed: ${response.statusCode}');
    }
    return ClusterConfig.fromJson(jsonDecode(response.body));
  }

  /// Every team in [teamNumber]'s state for the [year] season, with
  /// hometowns if [locations] (slow the first time a state is looked up).
  Future<StateTeams> getStateTeams({
    required int teamNumber,
    required int year,
    bool locations = false,
  }) async {
    final uri = Uri.parse('$baseUrl/GetStateTeams').replace(queryParameters: {
      'team_number': '$teamNumber',
      'year': '$year',
      if (locations) 'locations': '1',
    });
    // The first statewide hometown lookup geocodes a few hundred towns.
    final response = await http
        .get(uri)
        .timeout(locations ? const Duration(seconds: 120) : _timeout);
    if (response.statusCode != 200) {
      debugPrint('getStateTeams failed: ${response.statusCode} ${response.body}');
      throw ApiStatusException(response.statusCode, response.body);
    }
    return StateTeams.fromJson(jsonDecode(response.body));
  }

  /// Where the event is and where its US/Canadian teams are from.
  Future<TeamLocations> getTeamLocations(String eventKey) async {
    final uri = Uri.parse('$baseUrl/GetTeamLocations')
        .replace(queryParameters: {'event_key': eventKey});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getTeamLocations failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load team hometowns: ${response.statusCode}');
    }
    return TeamLocations.fromJson(jsonDecode(response.body));
  }

  /// A game's leaderboard for the team, highest score first.
  Future<List<GameScore>> getGameScores({
    required String secretKey,
    required String game,
  }) async {
    final uri = Uri.parse('$baseUrl/GetGameScores')
        .replace(queryParameters: {'secret_key': secretKey, 'game': game});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getGameScores failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load leaderboard: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List)
        .map((j) => GameScore.fromJson(j))
        .toList();
  }

  /// Publish a finished game's score. [id] makes a retry an upsert.
  Future<GameScore> postGameScore({
    required String id,
    required String secretKey,
    required String game,
    required String player,
    required int score,
    required String eventKey,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/PostGameScore'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'secret_key': secretKey,
            'game': game,
            'player': player,
            'score': score,
            'event_key': eventKey,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('postGameScore failed: ${response.statusCode} ${response.body}');
      throw Exception('Publishing failed: ${response.statusCode}');
    }
    return GameScore.fromJson(jsonDecode(response.body));
  }

  // --- Match-scouting schedule ---

  /// Record that [name] is in use for this key + event. Returns the
  /// scouter's private calendar token.
  Future<String> registerScouter({
    required String secretKey,
    required String eventKey,
    required String name,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/RegisterScouter'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'secret_key': secretKey,
            'event_key': eventKey,
            'scouter_name': name,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'registerScouter failed: ${response.statusCode} ${response.body}');
      throw Exception('Registering scouter failed: ${response.statusCode}');
    }
    return jsonDecode(response.body)['calendar_token'] as String;
  }

  Future<List<ScouterInfo>> getScouters(String secretKey, String eventKey) async {
    final uri = Uri.parse('$baseUrl/GetScouters')
        .replace(queryParameters: {'secret_key': secretKey, 'event_key': eventKey});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getScouters failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load scouters: ${response.statusCode}');
    }
    return [
      for (final j in jsonDecode(response.body) as List)
        ScouterInfo.fromJson(Map<String, dynamic>.from(j)),
    ];
  }

  /// Every published schedule for the key + event, newest first.
  Future<List<ScoutSchedule>> getSchedules(String secretKey, String eventKey) async {
    final uri = Uri.parse('$baseUrl/GetSchedules')
        .replace(queryParameters: {'secret_key': secretKey, 'event_key': eventKey});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getSchedules failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load schedules: ${response.statusCode}');
    }
    return [
      for (final j in jsonDecode(response.body) as List)
        ScoutSchedule.fromJson(Map<String, dynamic>.from(j)),
    ];
  }

  Future<ScoutSchedule> publishSchedule({
    required String secretKey,
    required String eventKey,
    required String publishedBy,
    required List<Shift> shifts,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/PublishSchedule'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'secret_key': secretKey,
            'event_key': eventKey,
            'published_by': publishedBy,
            'shifts': [for (final s in shifts) s.toJson()],
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint(
          'publishSchedule failed: ${response.statusCode} ${response.body}');
      throw Exception('Publishing failed: ${response.statusCode}');
    }
    return ScoutSchedule.fromJson(jsonDecode(response.body));
  }

  /// The iCalendar feed for a scouter's calendar token. [scheme] is 'https'
  /// (or the API's own scheme) to copy, 'webcal' to subscribe.
  static String calendarUrl(String token, {bool webcal = false}) {
    final uri = Uri.parse('$baseUrl/ScheduleCalendar')
        .replace(queryParameters: {'token': token});
    return webcal ? uri.replace(scheme: 'webcal').toString() : uri.toString();
  }

  Future<List<PitResult>> getPitResults(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetPitResults?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => PitResult.fromJson(e)).toList();
    }
    throw Exception('Failed to load pit results: ${response.statusCode}');
  }

  /// Official TBA rankings. Empty [RankingsData.rows] means none posted yet.
  Future<RankingsData> getRankings(String eventKey) async {
    final response = await http
        .get(Uri.parse(
            '$baseUrl/GetRankings?event_key=${Uri.encodeQueryComponent(eventKey)}'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return RankingsData.fromJson(jsonDecode(response.body));
    }
    debugPrint('getRankings failed: ${response.statusCode} ${response.body}');
    throw Exception('Failed to load rankings: ${response.statusCode}');
  }

  /// Scouted rows for [secretKey]'s team, parsed and trimmed for analytics.
  /// GetResults filters server-side by secret_team_key; we filter again in
  /// case an older deployment ignores the parameter.
  Future<List<ScoutedMatch>> getScoutedMatches(String eventKey, String secretKey) async {
    final uri = Uri.parse('$baseUrl/GetResults')
        .replace(queryParameters: {'event_key': eventKey, 'secret_team_key': secretKey});
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getScoutedMatches failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load scouted results: ${response.statusCode}');
    }
    final List<dynamic> data = jsonDecode(response.body);
    final wanted = secretKey.trim().toLowerCase();
    return [
      for (final row in data)
        if (row is Map &&
            (row['secret_team_key'] ?? secretKey).toString().trim().toLowerCase() == wanted)
          ScoutedMatch.fromApi(Map<String, dynamic>.from(row)),
    ];
  }

  /// Official results with score breakdowns, sorted in match order.
  Future<List<MatchResult>> getMatchResults(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetMatchesForEvent?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getMatchResults failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load match results: ${response.statusCode}');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return [for (final m in data) MatchResult.fromTba(Map<String, dynamic>.from(m))]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }

  /// OPR per team for every numeric score-breakdown field (qual matches
  /// only), keyed by team number: field -> contribution.
  Future<OprData> getOprData(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetOPRData?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('getOprData failed: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load OPR: ${response.statusCode}');
    }
    return oprFromJson(jsonDecode(response.body) as List);
  }
}

