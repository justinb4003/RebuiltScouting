import 'tba_team.dart';
import 'team_location.dart';

/// GetStateTeams: every team active in a season in one state/province (the
/// user's team's), for the statewide games.
class StateTeams {
  final String state;
  final String country;
  // The season actually used (the previous one if the requested year had
  // no teams yet).
  final int year;
  final List<TbaTeam> teams;
  // Hometowns, when requested with locations; empty otherwise.
  final List<TeamLocation> locations;

  StateTeams({
    required this.state,
    required this.country,
    required this.year,
    required this.teams,
    required this.locations,
  });

  Map<String, dynamic> toJson() => {
        'state': state,
        'country': country,
        'year': year,
        'teams': [
          for (var i = 0; i < teams.length; i++)
            {
              'team_number': teams[i].teamNumber,
              'nickname': teams[i].nickname,
              if (locations.isNotEmpty) ...locations[i].toJson(),
            },
        ],
      };

  factory StateTeams.fromJson(Map<String, dynamic> json) {
    final rows = [
      for (final t in (json['teams'] as List? ?? []))
        Map<String, dynamic>.from(t),
    ];
    final withLocations = rows.any((r) => r.containsKey('lat'));
    return StateTeams(
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      teams: [
        for (final r in rows)
          TbaTeam(
            teamNumber: (r['team_number'] as num).toInt(),
            nickname: r['nickname'] ?? '',
            city: r['city'],
            stateProv: r['state'],
          ),
      ],
      locations: withLocations ? [for (final r in rows) TeamLocation.fromJson(r)] : [],
    );
  }
}
