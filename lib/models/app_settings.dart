class AppSettings {
  String scouterName;
  String secretTeamKey;
  int eventYear;
  String? selectedEventKey;
  String? selectedEventName;

  AppSettings({
    this.scouterName = '',
    this.secretTeamKey = '',
    this.eventYear = 2026,
    this.selectedEventKey,
    this.selectedEventName,
  });

  Map<String, dynamic> toJson() => {
        'scouterName': scouterName,
        'secretTeamKey': secretTeamKey,
        'eventYear': eventYear,
        'selectedEventKey': selectedEventKey,
        'selectedEventName': selectedEventName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        scouterName: json['scouterName'] ?? '',
        secretTeamKey: json['secretTeamKey'] ?? '',
        eventYear: json['eventYear'] ?? 2026,
        selectedEventKey: json['selectedEventKey'],
        selectedEventName: json['selectedEventName'],
      );
}
