const defaultTeamNumber = 4003;

/// The season the app defaults to: the calendar year, or next year from
/// October 1 on (teams sign up for next season's events in October).
int currentSeason([DateTime? now]) {
  final d = now ?? DateTime.now();
  return d.month >= 10 ? d.year + 1 : d.year;
}

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
  // currentSeason() unless the user picked a season, which then sticks
  // (eventYearChosen).
  int eventYear;
  bool eventYearChosen;
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
    int? eventYear,
    this.eventYearChosen = false,
    this.selectedEventKey,
    this.selectedEventName,
    this.useOpenDyslexic = false,
    this.themeColor = 0xFF1565C0,
    this.themeMode = 'system',
    this.confettiEnabled = true,
    this.hapticEnabled = true,
    this.scrollableScoutLayout = false,
    this.scheduleTestMode = false,
  }) : eventYear = eventYear ?? currentSeason();

  Map<String, dynamic> toJson() => {
        'scouterName': scouterName,
        'secretTeamKey': secretTeamKey,
        'teamNumber': teamNumber,
        'slackUserId': slackUserId,
        'slackName': slackName,
        'slackTeamId': slackTeamId,
        'slackLinkToken': slackLinkToken,
        'eventYear': eventYear,
        'eventYearChosen': eventYearChosen,
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
        eventYear: json['eventYearChosen'] == true
            ? (json['eventYear'] as num?)?.toInt()
            : null,
        eventYearChosen: json['eventYearChosen'] == true,
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
