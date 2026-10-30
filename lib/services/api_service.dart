import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/pick_list.dart';
import '../models/pick_board.dart';
import '../models/cluster_result.dart';
import '../models/rankings.dart';
import '../models/match_result.dart';
import '../models/scouted_match.dart';

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

  Future<bool> postResults(ScoutResult result) async {
    final response = await http.post(
      Uri.parse('$baseUrl/PostResults'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(result.toJson()),
    ).timeout(_timeout);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> postPitResults(PitResult result) async {
    final response = await http.post(
      Uri.parse('$baseUrl/PostPitResults'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(result.toJson()),
    ).timeout(_timeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('postPitResults failed: ${response.statusCode} ${response.body}');
    }
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getResults(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetResults?event_key=$eventKey'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load results: ${response.statusCode}');
  }

  Future<bool> postRobotNote({
    required String scouterName,
    required String secretTeamKey,
    required String eventKey,
    required int teamNumber,
    required String notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/PostPitResults'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scouter_name': scouterName,
        'secret_team_key': secretTeamKey,
        'event_key': eventKey,
        'team_number': teamNumber,
        'notes': notes,
        'images': <String>[],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(_timeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('postRobotNote failed: ${response.statusCode} ${response.body}');
    }
    return response.statusCode == 200 || response.statusCode == 201;
  }

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
    required int k,
    required bool scale,
    List<String>? features,
    List<int> exclude = const [],
    bool refresh = false,
  }) {
    final uri = Uri.parse('$baseUrl/GetClusters').replace(queryParameters: {
      'secret_team_key': secretKey,
      'event_key': eventKey,
      'k': '$k',
      'scale': scale ? '1' : '0',
      if (features != null && features.isNotEmpty)
        'features': features.join(','),
      if (exclude.isNotEmpty) 'exclude': exclude.join(','),
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
}
