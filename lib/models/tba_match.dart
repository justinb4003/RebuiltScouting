class TbaMatch {
  final String key;
  final int matchNumber;
  final String compLevel; // qm, qf, sf, f
  final int setNumber;
  final List<String> redTeams;
  final List<String> blueTeams;

  TbaMatch({
    required this.key,
    required this.matchNumber,
    required this.compLevel,
    this.setNumber = 1,
    required this.redTeams,
    required this.blueTeams,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'matchNumber': matchNumber,
        'compLevel': compLevel,
        'setNumber': setNumber,
        'redTeams': redTeams,
        'blueTeams': blueTeams,
      };

  factory TbaMatch.fromJson(Map<String, dynamic> json) {
    List<String> redTeams;
    List<String> blueTeams;

    // API format: alliances.red.team_keys / alliances.blue.team_keys
    final alliances = json['alliances'];
    if (alliances != null && alliances is Map) {
      redTeams = _extractTeamNumbers(alliances['red']?['team_keys']);
      blueTeams = _extractTeamNumbers(alliances['blue']?['team_keys']);
    } else {
      // Cached format: redTeams / blueTeams (already plain numbers)
      redTeams = List<String>.from(json['redTeams'] ?? []);
      blueTeams = List<String>.from(json['blueTeams'] ?? []);
    }

    return TbaMatch(
      key: json['key'] ?? json['match_key'] ?? '',
      matchNumber: json['matchNumber'] ?? json['match_number'] ?? 0,
      compLevel: json['compLevel'] ?? json['comp_level'] ?? 'qm',
      setNumber: json['setNumber'] ?? json['set_number'] ?? 1,
      redTeams: redTeams,
      blueTeams: blueTeams,
    );
  }

  /// Strip "frc" prefix from team keys like "frc862" → "862"
  static List<String> _extractTeamNumbers(dynamic teamKeys) {
    if (teamKeys == null || teamKeys is! List) return [];
    return teamKeys
        .map<String>((k) => k.toString().replaceFirst('frc', ''))
        .toList();
  }

  String get displayName {
    switch (compLevel) {
      case 'qm':
        return 'Qual $matchNumber';
      case 'qf':
        return 'QF $setNumber-$matchNumber';
      case 'sf':
        return 'SF $setNumber-$matchNumber';
      case 'f':
        return 'Final $matchNumber';
      default:
        return '$compLevel $matchNumber';
    }
  }
}
