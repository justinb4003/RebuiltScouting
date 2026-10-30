import '../analytics/scout_stats.dart';

/// One scouter's observation of one team in one qualification match, trimmed
/// to the numeric stats the analytics screens aggregate plus the text notes.
/// Built from the API's GetResults rows, which carry more than the app's
/// [ScoutResult] (e.g. thumbs-up) and are not worth round-tripping through it.
class ScoutedMatch {
  final int teamNumber;
  final int matchNumber;
  final String scouterName;
  final String matchNotes;
  final String autoNotes;
  final String activeDefense; // quality label, 'N/A' when none
  final String inactiveDefense;

  /// Numeric stats keyed by [ScoutStats.defs] keys. Booleans are 0/1;
  /// a missing key means "not recorded" (e.g. the tri-state win_auto).
  final Map<String, double> stats;

  const ScoutedMatch({
    required this.teamNumber,
    required this.matchNumber,
    this.scouterName = '',
    this.matchNotes = '',
    this.autoNotes = '',
    this.activeDefense = 'N/A',
    this.inactiveDefense = 'N/A',
    required this.stats,
  });

  double? stat(String key) => stats[key];

  bool get hasDefense => activeDefense != 'N/A' || inactiveDefense != 'N/A';

  /// Parse one GetResults row. Handles the legacy column names Streamlit
  /// renames (`scouting_team` -> team_number, `match_key` -> match_number).
  factory ScoutedMatch.fromApi(Map<String, dynamic> j) {
    double? num_(dynamic v) {
      if (v is bool) return v ? 1 : 0;
      if (v is num) return v.toDouble();
      return null;
    }

    int intOf(dynamic v) {
      if (v is num) return v.toInt();
      final m = RegExp(r'(\d+)').allMatches(v?.toString() ?? '');
      return m.isEmpty ? 0 : int.parse(m.last.group(1)!);
    }

    final raw = <String, double>{};
    for (final key in ScoutStats.rawKeys) {
      final v = num_(j[key]);
      if (v != null) raw[key] = v;
    }
    return ScoutedMatch(
      teamNumber: intOf(j['scouting_team'] ?? j['team_number']),
      matchNumber: intOf(j['match_key'] ?? j['match_number']),
      scouterName: (j['scouter_name'] ?? '').toString(),
      matchNotes: (j['match_notes'] ?? '').toString().trim(),
      autoNotes: (j['auto_notes'] ?? '').toString().trim(),
      activeDefense: (j['teleop_active_defense_quality'] ?? 'N/A').toString(),
      inactiveDefense: (j['teleop_inactive_defense_quality'] ?? 'N/A').toString(),
      stats: {...raw, ...ScoutStats.volleyStats(j['volley_accuracy_list'] as List?)},
    );
  }

  Map<String, dynamic> toJson() => {
        't': teamNumber,
        'm': matchNumber,
        's': scouterName,
        'n': matchNotes,
        'an': autoNotes,
        'ad': activeDefense,
        'id': inactiveDefense,
        'v': stats,
      };

  factory ScoutedMatch.fromJson(Map<String, dynamic> j) => ScoutedMatch(
        teamNumber: j['t'] ?? 0,
        matchNumber: j['m'] ?? 0,
        scouterName: j['s'] ?? '',
        matchNotes: j['n'] ?? '',
        autoNotes: j['an'] ?? '',
        activeDefense: j['ad'] ?? 'N/A',
        inactiveDefense: j['id'] ?? 'N/A',
        stats: {
          for (final e in (j['v'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
      );
}
