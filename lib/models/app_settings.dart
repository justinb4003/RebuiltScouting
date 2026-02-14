class AppSettings {
  String scouterName;
  String secretTeamKey;
  int eventYear;
  String? selectedEventKey;
  String? selectedEventName;
  bool useOpenDyslexic;
  int themeColor;
  String themeMode;
  bool confettiEnabled;
  bool hapticEnabled;

  AppSettings({
    this.scouterName = '',
    this.secretTeamKey = '',
    this.eventYear = 2026,
    this.selectedEventKey,
    this.selectedEventName,
    this.useOpenDyslexic = false,
    this.themeColor = 0xFF1565C0,
    this.themeMode = 'system',
    this.confettiEnabled = true,
    this.hapticEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'scouterName': scouterName,
        'secretTeamKey': secretTeamKey,
        'eventYear': eventYear,
        'selectedEventKey': selectedEventKey,
        'selectedEventName': selectedEventName,
        'useOpenDyslexic': useOpenDyslexic,
        'themeColor': themeColor,
        'themeMode': themeMode,
        'confettiEnabled': confettiEnabled,
        'hapticEnabled': hapticEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        scouterName: json['scouterName'] ?? '',
        secretTeamKey: json['secretTeamKey'] ?? '',
        eventYear: json['eventYear'] ?? 2026,
        selectedEventKey: json['selectedEventKey'],
        selectedEventName: json['selectedEventName'],
        useOpenDyslexic: json['useOpenDyslexic'] ?? false,
        themeColor: json['themeColor'] ?? 0xFF1565C0,
        themeMode: json['themeMode'] ?? 'system',
        confettiEnabled: json['confettiEnabled'] ?? true,
        hapticEnabled: json['hapticEnabled'] ?? true,
      );
}
