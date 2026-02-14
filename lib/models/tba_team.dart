class TbaTeam {
  final int teamNumber;
  final String nickname;
  final String? city;
  final String? stateProv;

  TbaTeam({
    required this.teamNumber,
    required this.nickname,
    this.city,
    this.stateProv,
  });

  Map<String, dynamic> toJson() => {
        'teamNumber': teamNumber,
        'nickname': nickname,
        'city': city,
        'stateProv': stateProv,
      };

  factory TbaTeam.fromJson(Map<String, dynamic> json) => TbaTeam(
        teamNumber: json['teamNumber'] ?? json['number'] ?? json['team_number'] ?? 0,
        nickname: json['nickname'] ?? json['name'] ?? json['team_name'] ?? '',
        city: json['city'],
        stateProv: json['stateProv'] ?? json['state_prov'],
      );

  @override
  String toString() => '$teamNumber - $nickname';
}
