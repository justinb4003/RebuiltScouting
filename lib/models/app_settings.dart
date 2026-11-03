const defaultTeamNumber = 4003;

class AppSettings {
  String scouterName;
  String secretTeamKey;
  // The user's own team (optional). Used by the statewide games; 4003 until
  // someone changes it.
  int? teamNumber;
  int eventYear;
  String? selectedEventKey;
  String? selectedEventName;
  bool useOpenDyslexic;
  int themeColor;
  String themeMode;
  bool confettiEnabled;
  bool hapticEnabled;
  bool scrollableScoutLayout;

  AppSettings({
    this.scouterName = '',
    this.secretTeamKey = '',
    this.teamNumber = defaultTeamNumber,
    this.eventYear = 2026,
    this.selectedEventKey,
    this.selectedEventName,
    this.useOpenDyslexic = false,
    this.themeColor = 0xFF1565C0,
    this.themeMode = 'system',
    this.confettiEnabled = true,
    this.hapticEnabled = true,
    this.scrollableScoutLayout = false,
  });

  Map<String, dynamic> toJson() => {
        'scouterName': scouterName,
        'secretTeamKey': secretTeamKey,
        'teamNumber': teamNumber,
        'eventYear': eventYear,
        'selectedEventKey': selectedEventKey,
        'selectedEventName': selectedEventName,
        'useOpenDyslexic': useOpenDyslexic,
        'themeColor': themeColor,
        'themeMode': themeMode,
        'confettiEnabled': confettiEnabled,
        'hapticEnabled': hapticEnabled,
        'scrollableScoutLayout': scrollableScoutLayout,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        scouterName: json['scouterName'] ?? '',
        secretTeamKey: json['secretTeamKey'] ?? '',
        // Missing (settings saved before this field existed) means the
        // default; a saved null means the user cleared it.
        teamNumber: json.containsKey('teamNumber')
            ? (json['teamNumber'] as num?)?.toInt()
            : defaultTeamNumber,
        eventYear: json['eventYear'] ?? 2026,
        selectedEventKey: json['selectedEventKey'],
        selectedEventName: json['selectedEventName'],
        useOpenDyslexic: json['useOpenDyslexic'] ?? false,
        themeColor: json['themeColor'] ?? 0xFF1565C0,
        themeMode: json['themeMode'] ?? 'system',
        confettiEnabled: json['confettiEnabled'] ?? true,
        hapticEnabled: json['hapticEnabled'] ?? true,
        scrollableScoutLayout: json['scrollableScoutLayout'] ?? false,
      );
}
