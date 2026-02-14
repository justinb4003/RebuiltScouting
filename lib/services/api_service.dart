import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tba_event.dart';
import '../models/tba_team.dart';
import '../models/tba_match.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';

class ApiService {
  static const String baseUrl =
      'https://trisonics-scouting-api.azurewebsites.net/api';

  Future<List<TbaEvent>> getEvents(int year) async {
    final response =
        await http.get(Uri.parse('$baseUrl/GetEvents?year=$year'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => TbaEvent.fromJson(e)).toList();
    }
    throw Exception('Failed to load events: ${response.statusCode}');
  }

  Future<List<TbaTeam>> getTeamsForEvent(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetTeamsForEvent?event_key=$eventKey'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => TbaTeam.fromJson(e)).toList()
        ..sort((a, b) => a.teamNumber.compareTo(b.teamNumber));
    }
    throw Exception('Failed to load teams: ${response.statusCode}');
  }

  Future<List<TbaMatch>> getMatchesForEvent(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetMatchesForEvent?event_key=$eventKey'));
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
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> postPitResults(PitResult result) async {
    final response = await http.post(
      Uri.parse('$baseUrl/PostPitResults'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(result.toJson()),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<List<PitResult>> getPitResults(String eventKey) async {
    final response = await http
        .get(Uri.parse('$baseUrl/GetPitResults?event_key=$eventKey'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => PitResult.fromJson(e)).toList();
    }
    throw Exception('Failed to load pit results: ${response.statusCode}');
  }
}
