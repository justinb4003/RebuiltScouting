const defaultTeamNumber = 4003;

class AppSettings {
  String scouterName;
  String secretTeamKey;
  // The user's own team (optional). Used by the statewide games; 4003 until
  // someone changes it.
  int? teamNumber;
  // Set by Sign in with Slack (Settings > Link Slack account). The link token
  // is the secret that proves the link to the API; never sent anywhere else.
  String? slackUserId;
  String? slackName;
  String? slackTeamId;
  String? slackLinkToken;
  int eventYear;
  String? selectedEventKey;
  String? selectedEventName;
  bool useOpenDyslexic;
  int themeColor;
  String themeMode;
  bool confettiEnabled;
  bool hapticEnabled;
  bool scrollableScoutLayout;
  // Off-season testing: Publish offers to move a schedule's match times to
  // today (a practice run) so Slack shift reminders can be drilled.
  bool scheduleTestMode;

  bool get slackLinked => (slackLinkToken ?? '').isNotEmpty;

  AppSettings({
    this.scouterName = '',
    this.secretTeamKey = '',
    this.teamNumber = defaultTeamNumber,
    this.slackUserId,
    this.slackName,
    this.slackTeamId,
    this.slackLinkToken,
    this.eventYear = 2026,
    this.selectedEventKey,
    this.selectedEventName,
    this.useOpenDyslexic = false,
    this.themeColor = 0xFF1565C0,
    this.themeMode = 'system',
    this.confettiEnabled = true,
    this.hapticEnabled = true,
    this.scrollableScoutLayout = false,
    this.scheduleTestMode = false,
  });

  Map<String, dynamic> toJson() => {
        'scouterName': scouterName,
        'secretTeamKey': secretTeamKey,
        'teamNumber': teamNumber,
        'slackUserId': slackUserId,
        'slackName': slackName,
        'slackTeamId': slackTeamId,
        'slackLinkToken': slackLinkToken,
        'eventYear': eventYear,
        'selectedEventKey': selectedEventKey,
        'selectedEventName': selectedEventName,
        'useOpenDyslexic': useOpenDyslexic,
        'themeColor': themeColor,
        'themeMode': themeMode,
        'confettiEnabled': confettiEnabled,
        'hapticEnabled': hapticEnabled,
        'scrollableScoutLayout': scrollableScoutLayout,
        'scheduleTestMode': scheduleTestMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        scouterName: json['scouterName'] ?? '',
        secretTeamKey: json['secretTeamKey'] ?? '',
        // Missing (settings saved before this field existed) means the
        // default; a saved null means the user cleared it.
        teamNumber: json.containsKey('teamNumber')
            ? (json['teamNumber'] as num?)?.toInt()
            : defaultTeamNumber,
        slackUserId: json['slackUserId'],
        slackName: json['slackName'],
        slackTeamId: json['slackTeamId'],
        slackLinkToken: json['slackLinkToken'],
        eventYear: json['eventYear'] ?? 2026,
        selectedEventKey: json['selectedEventKey'],
        selectedEventName: json['selectedEventName'],
        useOpenDyslexic: json['useOpenDyslexic'] ?? false,
        themeColor: json['themeColor'] ?? 0xFF1565C0,
        themeMode: json['themeMode'] ?? 'system',
        confettiEnabled: json['confettiEnabled'] ?? true,
        hapticEnabled: json['hapticEnabled'] ?? true,
        scrollableScoutLayout: json['scrollableScoutLayout'] ?? false,
        scheduleTestMode: json['scheduleTestMode'] ?? false,
      );
}
