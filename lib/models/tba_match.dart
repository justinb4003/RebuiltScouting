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

  factory TbaMatch.fromJson(Map<String, dynamic> json) => TbaMatch(
        key: json['key'] ?? json['match_key'] ?? '',
        matchNumber: json['matchNumber'] ?? json['match_number'] ?? 0,
        compLevel: json['compLevel'] ?? json['comp_level'] ?? 'qm',
        setNumber: json['setNumber'] ?? json['set_number'] ?? 1,
        redTeams: List<String>.from(json['redTeams'] ?? json['red_teams'] ?? []),
        blueTeams: List<String>.from(json['blueTeams'] ?? json['blue_teams'] ?? []),
      );

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
