import 'dart:math' as math;
import '../models/scouted_match.dart';

/// A scouted column the analytics screens aggregate and display.
class StatDef {
  final String key;
  final String label;
  final String section; // Auto, Teleop, Endgame, General
  final bool binary; // 0/1 per match; averaged as a rate
  const StatDef(this.key, this.label, this.section, {this.binary = false});
}

/// Column catalogue for the scouted data. This season's form records
/// accuracy ratings and volleys rather than fuel counts (the raw
/// `*_fuel_scored` columns are always 0), so those are what we aggregate.
/// Pure functions only; no widgets or I/O.
class ScoutStats {
  static const sections = ['Auto', 'Teleop', 'Endgame', 'General'];

  static const defs = <StatDef>[
    StatDef('auto_fuel_accuracy', 'Shooting accuracy %', 'Auto'),
    StatDef('auto_tower_level', 'Tower level', 'Auto'),
    StatDef('auto_middle_pickup', 'Middle pickups', 'Auto'),
    StatDef('auto_human_station_pickup', 'Human station pickups', 'Auto'),
    StatDef('win_auto', 'Won auto', 'Auto', binary: true),
    StatDef('auto_did_nothing', 'Did nothing', 'Auto', binary: true),
    StatDef('auto_depot_pickup', 'Depot pickup', 'Auto', binary: true),
    StatDef('teleop_volleys', 'Volleys', 'Teleop'),
    StatDef('teleop_volley_accuracy', 'Volley accuracy %', 'Teleop'),
    StatDef('teleop_fuel_accuracy', 'Shooting accuracy %', 'Teleop'),
    StatDef('hopper_size', 'Hopper size', 'Teleop'),
    StatDef('teleop_shoot_on_fly', 'Shoots on the fly', 'Teleop', binary: true),
    StatDef('teleop_inactive_scored_fuel', 'Scores while inactive', 'Teleop', binary: true),
    StatDef('teleop_inactive_collected_fuel', 'Collects while inactive', 'Teleop', binary: true),
    StatDef('teleop_inactive_collected_fuel_push', 'Inactive: push', 'Teleop', binary: true),
    StatDef('teleop_inactive_collected_fuel_lobby', 'Inactive: lobby', 'Teleop', binary: true),
    StatDef('teleop_inactive_collected_fuel_refill', 'Inactive: refill', 'Teleop', binary: true),
    StatDef('teleop_active_defense_penalties', 'Defense penalties (active)', 'Teleop', binary: true),
    StatDef('teleop_inactive_defense_penalties', 'Defense penalties (inactive)', 'Teleop', binary: true),
    StatDef('endgame_tower_level', 'Tower level', 'Endgame'),
    StatDef('endgame_fuel_accuracy', 'Shooting accuracy %', 'Endgame'),
    StatDef('endgame_carried', 'Carried', 'Endgame', binary: true),
    StatDef('endgame_thumbs_up', 'Thumbs up', 'Endgame', binary: true),
    StatDef('fuel_ground_pickup', 'Ground pickup', 'General', binary: true),
    StatDef('fuel_human_pickup', 'Human pickup', 'General', binary: true),
    StatDef('fuel_depot_pickup', 'Depot pickup', 'General', binary: true),
  ];

  static final byKey = {for (final d in defs) d.key: d};

  static List<StatDef> inSection(String section) =>
      [for (final d in defs) if (d.section == section) d];

  /// Stats computed from the volley lists rather than read from a column.
  static const _volleyKeys = {'teleop_volleys', 'teleop_volley_accuracy'};

  /// API columns we read; everything else in a GetResults row is dropped.
  static final rawKeys = <String>{
    for (final d in defs)
      if (!_volleyKeys.contains(d.key)) d.key,
  };

  /// Volley count and mean volley accuracy from the row's volley lists.
  static Map<String, double> volleyStats(List<dynamic>? accuracy) {
    final acc = [for (final a in accuracy ?? const []) if (a is num) a.toDouble()];
    if (acc.isEmpty) return const {'teleop_volleys': 0};
    return {
      'teleop_volleys': acc.length.toDouble(),
      'teleop_volley_accuracy': acc.reduce((a, b) => a + b) / acc.length,
    };
  }
}

/// One team's scouted rows with the usual summary statistics.
class TeamStats {
  final int teamNumber;
  final List<ScoutedMatch> rows; // sorted by match number

  TeamStats(this.teamNumber, Iterable<ScoutedMatch> rows)
      : rows = (rows.toList()..sort((a, b) => a.matchNumber.compareTo(b.matchNumber)));

  /// Distinct matches scouted (several scouters may cover one match).
  int get matchesScouted => rows.map((r) => r.matchNumber).toSet().length;

  List<double> values(String key) =>
      [for (final r in rows) if (r.stats[key] != null) r.stats[key]!];

  double? mean(String key) => _mean(values(key));

  double? stdDev(String key) {
    final v = values(key);
    if (v.length < 2) return null;
    final m = _mean(v)!;
    final ss = v.fold<double>(0, (s, x) => s + (x - m) * (x - m));
    return math.sqrt(ss / (v.length - 1)); // sample std dev, like pandas
  }

  double? max(String key) {
    final v = values(key);
    return v.isEmpty ? null : v.reduce(math.max);
  }

  double? sum(String key) {
    final v = values(key);
    return v.isEmpty ? null : v.fold<double>(0, (s, x) => s + x);
  }

  /// Mean of the later half minus the earlier half (null under 4 rows).
  double? halfDelta(String key) {
    final v = values(key);
    if (v.length < 4) return null;
    final h = v.length ~/ 2;
    return _mean(v.sublist(v.length - h))! - _mean(v.sublist(0, h))!;
  }

  /// Most common value of [key] (e.g. the usual tower level).
  double? mode(String key) {
    final v = values(key);
    if (v.isEmpty) return null;
    final counts = <double, int>{};
    for (final x in v) {
      counts[x] = (counts[x] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Rows scouted for a given qualification match.
  List<ScoutedMatch> inMatch(int matchNumber) =>
      [for (final r in rows) if (r.matchNumber == matchNumber) r];

  static double? _mean(List<double> v) =>
      v.isEmpty ? null : v.fold<double>(0, (s, x) => s + x) / v.length;
}

/// Group rows by team.
Map<int, TeamStats> aggregateByTeam(Iterable<ScoutedMatch> rows) {
  final grouped = <int, List<ScoutedMatch>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.teamNumber, () => []).add(r);
  }
  return {for (final e in grouped.entries) e.key: TeamStats(e.key, e.value)};
}

/// Mean of each team's mean for [key] (every team weighs the same).
double? eventMean(Map<int, TeamStats> stats, String key) {
  final means = [for (final t in stats.values) t.mean(key)].whereType<double>().toList();
  return means.isEmpty ? null : means.reduce((a, b) => a + b) / means.length;
}

/// 1-based rank of [team] for [key] among all teams (higher is better), or
/// null if the team has no value.
int? rankOf(Map<int, TeamStats> stats, int team, String key) {
  final mine = stats[team]?.mean(key);
  if (mine == null) return null;
  var better = 0;
  for (final t in stats.values) {
    final m = t.mean(key);
    if (m != null && m > mine) better++;
  }
  return better + 1;
}
