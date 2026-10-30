// Official (TBA) result for one match, trimmed to what the analytics screens
// show so it can be cached per event without storing raw TBA JSON.
// Separate from TbaMatch, which the scouting screens cache in their own format.

int _toInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

/// "None" / "Level1".."Level3" from TBA -> 0..3.
int _towerLevel(dynamic v) {
  if (v is num) return v.toInt();
  final m = RegExp(r'(\d)').firstMatch(v?.toString() ?? '');
  return m == null ? 0 : int.parse(m.group(1)!);
}

class AllianceBreakdown {
  final int totalPoints;
  final int autoPoints;
  final int teleopPoints;
  final int hubAuto; // fuel counted in the hub per phase
  final int hubTeleop;
  final int hubEndgame;
  final int hubTotal;
  final int towerPoints;
  final int foulPoints;
  final int minorFouls;
  final int majorFouls;
  final int rp;
  final List<int> autoTower; // per robot slot, 0 = none, 1..3 = level
  final List<int> endTower;
  final bool energized;
  final bool supercharged;
  final bool traversal;

  const AllianceBreakdown({
    this.totalPoints = 0,
    this.autoPoints = 0,
    this.teleopPoints = 0,
    this.hubAuto = 0,
    this.hubTeleop = 0,
    this.hubEndgame = 0,
    this.hubTotal = 0,
    this.towerPoints = 0,
    this.foulPoints = 0,
    this.minorFouls = 0,
    this.majorFouls = 0,
    this.rp = 0,
    this.autoTower = const [0, 0, 0],
    this.endTower = const [0, 0, 0],
    this.energized = false,
    this.supercharged = false,
    this.traversal = false,
  });

  /// Parse TBA's `score_breakdown.{red,blue}` object.
  factory AllianceBreakdown.fromTba(Map<String, dynamic> j) {
    final hub = j['hubScore'] is Map ? j['hubScore'] as Map : const {};
    return AllianceBreakdown(
      totalPoints: _toInt(j['totalPoints']),
      autoPoints: _toInt(j['totalAutoPoints']),
      teleopPoints: _toInt(j['totalTeleopPoints']),
      hubAuto: _toInt(hub['autoCount']),
      hubTeleop: _toInt(hub['teleopCount']),
      hubEndgame: _toInt(hub['endgameCount']),
      hubTotal: _toInt(hub['totalCount']),
      towerPoints: _toInt(j['totalTowerPoints']),
      foulPoints: _toInt(j['foulPoints']),
      minorFouls: _toInt(j['minorFoulCount']),
      majorFouls: _toInt(j['majorFoulCount']),
      rp: _toInt(j['rp']),
      autoTower: [for (var i = 1; i <= 3; i++) _towerLevel(j['autoTowerRobot$i'])],
      endTower: [for (var i = 1; i <= 3; i++) _towerLevel(j['endGameTowerRobot$i'])],
      energized: j['energizedAchieved'] == true,
      supercharged: j['superchargedAchieved'] == true,
      traversal: j['traversalAchieved'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tp': totalPoints,
        'ap': autoPoints,
        'op': teleopPoints,
        'ha': hubAuto,
        'ho': hubTeleop,
        'he': hubEndgame,
        'ht': hubTotal,
        'tw': towerPoints,
        'fp': foulPoints,
        'mnf': minorFouls,
        'mjf': majorFouls,
        'rp': rp,
        'at': autoTower,
        'et': endTower,
        'en': energized,
        'su': supercharged,
        'tr': traversal,
      };

  factory AllianceBreakdown.fromJson(Map<String, dynamic> j) => AllianceBreakdown(
        totalPoints: _toInt(j['tp']),
        autoPoints: _toInt(j['ap']),
        teleopPoints: _toInt(j['op']),
        hubAuto: _toInt(j['ha']),
        hubTeleop: _toInt(j['ho']),
        hubEndgame: _toInt(j['he']),
        hubTotal: _toInt(j['ht']),
        towerPoints: _toInt(j['tw']),
        foulPoints: _toInt(j['fp']),
        minorFouls: _toInt(j['mnf']),
        majorFouls: _toInt(j['mjf']),
        rp: _toInt(j['rp']),
        autoTower: List<int>.from(j['at'] ?? const [0, 0, 0]),
        endTower: List<int>.from(j['et'] ?? const [0, 0, 0]),
        energized: j['en'] == true,
        supercharged: j['su'] == true,
        traversal: j['tr'] == true,
      );
}

class MatchAlliance {
  final List<int> teams;
  final int? score; // null until the match is played
  final AllianceBreakdown? breakdown;

  const MatchAlliance({required this.teams, this.score, this.breakdown});

  int get rp => breakdown?.rp ?? 0;

  Map<String, dynamic> toJson() => {
        'teams': teams,
        'score': score,
        if (breakdown != null) 'bd': breakdown!.toJson(),
      };

  factory MatchAlliance.fromJson(Map<String, dynamic> j) => MatchAlliance(
        teams: List<int>.from(j['teams'] ?? const []),
        score: j['score'] as int?,
        breakdown: j['bd'] is Map
            ? AllianceBreakdown.fromJson(Map<String, dynamic>.from(j['bd']))
            : null,
      );
}

class MatchResult {
  final String key;
  final String compLevel; // qm, ef, qf, sf, f
  final int setNumber;
  final int matchNumber;
  final MatchAlliance red;
  final MatchAlliance blue;
  final String? winner; // 'red' | 'blue' | null (tie or unplayed)
  final int? time; // scheduled start, epoch seconds

  const MatchResult({
    required this.key,
    required this.compLevel,
    required this.setNumber,
    required this.matchNumber,
    required this.red,
    required this.blue,
    this.winner,
    this.time,
  });

  bool get played => red.score != null && blue.score != null;
  bool get isQual => compLevel == 'qm';

  DateTime? get startTime =>
      time == null ? null : DateTime.fromMillisecondsSinceEpoch(time! * 1000);

  List<int> get allTeams => [...red.teams, ...blue.teams];
  bool hasTeam(int team) => red.teams.contains(team) || blue.teams.contains(team);

  /// 'red' / 'blue' for the alliance [team] is on.
  String? sideOf(int team) =>
      red.teams.contains(team) ? 'red' : (blue.teams.contains(team) ? 'blue' : null);

  MatchAlliance? allianceOf(int team) {
    final s = sideOf(team);
    return s == 'red' ? red : (s == 'blue' ? blue : null);
  }

  /// True/false once played, null if tied, unplayed or the team isn't in it.
  bool? won(int team) {
    final side = sideOf(team);
    if (side == null || !played || winner == null) return null;
    return winner == side;
  }

  /// Orders qualification, then playoffs by round, set and number.
  int get sortKey {
    const order = {'qm': 0, 'ef': 1, 'qf': 2, 'sf': 3, 'f': 4};
    return (order[compLevel] ?? 5) * 10000 + setNumber * 100 + matchNumber;
  }

  String get displayName {
    switch (compLevel) {
      case 'qm':
        return 'Qual $matchNumber';
      case 'ef':
        return 'EF $setNumber-$matchNumber';
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

  Map<String, dynamic> toJson() => {
        'key': key,
        'lvl': compLevel,
        'set': setNumber,
        'num': matchNumber,
        'red': red.toJson(),
        'blue': blue.toJson(),
        'win': winner,
        'time': time,
      };

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        key: j['key'] ?? '',
        compLevel: j['lvl'] ?? 'qm',
        setNumber: _toInt(j['set'], 1),
        matchNumber: _toInt(j['num']),
        red: MatchAlliance.fromJson(Map<String, dynamic>.from(j['red'])),
        blue: MatchAlliance.fromJson(Map<String, dynamic>.from(j['blue'])),
        winner: j['win'] as String?,
        time: j['time'] as int?,
      );

  /// Parse one entry of the API's GetMatchesForEvent (raw TBA match).
  factory MatchResult.fromTba(Map<String, dynamic> j) {
    final alliances = j['alliances'] is Map ? j['alliances'] as Map : const {};
    final breakdown = j['score_breakdown'] is Map ? j['score_breakdown'] as Map : const {};

    MatchAlliance parse(String color) {
      final a = alliances[color] is Map ? alliances[color] as Map : const {};
      final teams = [
        for (final k in (a['team_keys'] as List? ?? const []))
          int.tryParse(k.toString().replaceFirst('frc', '')) ?? 0,
      ];
      // TBA reports -1 for matches that haven't been played.
      final rawScore = a['score'];
      final score = rawScore is num && rawScore >= 0 ? rawScore.toInt() : null;
      final bd = breakdown[color];
      return MatchAlliance(
        teams: teams,
        score: score,
        breakdown: bd is Map ? AllianceBreakdown.fromTba(Map<String, dynamic>.from(bd)) : null,
      );
    }

    final winner = j['winning_alliance'];
    final timeRaw = j['time'] ?? j['predicted_time'];
    return MatchResult(
      key: j['key'] ?? '',
      compLevel: j['comp_level'] ?? 'qm',
      setNumber: _toInt(j['set_number'], 1),
      matchNumber: _toInt(j['match_number']),
      red: parse('red'),
      blue: parse('blue'),
      winner: winner == 'red' || winner == 'blue' ? winner : null,
      time: timeRaw is num ? timeRaw.toInt() : null,
    );
  }
}
