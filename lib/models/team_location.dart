/// Where a team is from (US and Canada only), for the Hometown game.
class TeamLocation {
  final int teamNumber;
  final String city;
  // State/province code, e.g. 'MI', 'ON'.
  final String state;
  // 'US' or 'CA'.
  final String country;
  // Null when the city couldn't be found.
  final double? lat;
  final double? lng;

  TeamLocation({
    required this.teamNumber,
    required this.city,
    required this.state,
    required this.country,
    this.lat,
    this.lng,
  });

  bool get placed => lat != null && lng != null;
  String get label => '$city, $state';

  Map<String, dynamic> toJson() => {
        'team_number': teamNumber,
        'city': city,
        'state': state,
        'country': country,
        'lat': lat,
        'lng': lng,
      };

  factory TeamLocation.fromJson(Map<String, dynamic> json) => TeamLocation(
        teamNumber: (json['team_number'] as num).toInt(),
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        country: json['country'] ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}

/// GetTeamLocations: the event's state and its teams' hometowns.
class TeamLocations {
  final String? eventState;
  final String? eventCountry;
  final List<TeamLocation> teams;

  TeamLocations({this.eventState, this.eventCountry, required this.teams});

  Map<String, dynamic> toJson() => {
        'event': {'state': eventState, 'country': eventCountry},
        'teams': [for (final t in teams) t.toJson()],
      };

  factory TeamLocations.fromJson(Map<String, dynamic> json) {
    final event = (json['event'] as Map?) ?? {};
    return TeamLocations(
      eventState: event['state'],
      eventCountry: event['country'],
      teams: [
        for (final t in (json['teams'] as List? ?? []))
          TeamLocation.fromJson(Map<String, dynamic>.from(t)),
      ],
    );
  }
}
