import 'dart:math' as math;
import '../models/cluster_result.dart';

/// One team's nearest neighbor in clustering space.
class Neighbor {
  final int teamNumber;
  final int group;
  final double distance;

  /// Share of all team pairs at the event that are farther apart than this
  /// pair, 0–100. 95 = closer than 95% of pairs.
  final double similarity;

  const Neighbor(this.teamNumber, this.group, this.distance, this.similarity);
}

/// What pulls a team away from the average robot on one dimension.
class Distinction {
  final String feature;

  /// Team's value, the event average and the spread, in raw units.
  final double? value;
  final double mean;
  final double std;

  /// Standard deviations from the event average.
  final double z;

  /// Share (0–1) of the team's squared distance from the event average, in
  /// the space the clustering used, that this dimension accounts for.
  final double share;

  /// Neighbors' values and the team's group average, in raw units.
  final List<(int, double)> neighborValues;
  final double? groupMean;

  const Distinction({
    required this.feature,
    required this.value,
    required this.mean,
    required this.std,
    required this.z,
    required this.share,
    required this.neighborValues,
    required this.groupMean,
  });
}

/// The clustering's feature space rebuilt from a [ClusterResult]: the same
/// normalizing and weights the API used, over the same teams. A weight
/// scales squared distance, so columns are multiplied by its square root.
class ClusterSpace {
  final ClusterResult result;
  final List<String> features;
  final List<double> mean;
  final List<double> std;
  final Map<int, List<double>> _raw;
  final Map<int, List<double>> _coords;
  List<double>? _pairDistances;

  ClusterSpace._(this.result, this.features, this.mean, this.std, this._raw,
      this._coords);

  factory ClusterSpace(ClusterResult r) {
    final features = r.features;
    // Missing values count as the event average (the API zero-fills raw
    // values; for averages this is the closer, gentler choice).
    final mean = <double>[];
    final std = <double>[];
    for (final f in features) {
      final vs = [for (final t in r.teams) t.values[f]].whereType<double>().toList();
      final m = vs.isEmpty ? 0.0 : vs.reduce((a, b) => a + b) / vs.length;
      final v = vs.isEmpty
          ? 0.0
          : vs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / vs.length;
      mean.add(m);
      std.add(math.sqrt(v));
    }
    final raw = <int, List<double>>{};
    final coords = <int, List<double>>{};
    for (final t in r.teams) {
      final row = [
        for (var j = 0; j < features.length; j++) t.values[features[j]] ?? mean[j],
      ];
      raw[t.teamNumber] = row;
      coords[t.teamNumber] = [
        for (var j = 0; j < features.length; j++)
          (row[j] - mean[j]) / (std[j] > 0 ? std[j] : 1) *
              math.sqrt(r.weightOf(features[j])),
      ];
    }
    return ClusterSpace._(r, features, mean, std, raw, coords);
  }

  bool contains(int team) => _coords.containsKey(team);

  double _dist(List<double> a, List<double> b) {
    var s = 0.0;
    for (var j = 0; j < a.length; j++) {
      s += (a[j] - b[j]) * (a[j] - b[j]);
    }
    return math.sqrt(s);
  }

  List<double> get _pairs => _pairDistances ??= () {
        final cs = _coords.values.toList();
        return [
          for (var i = 0; i < cs.length; i++)
            for (var j = i + 1; j < cs.length; j++) _dist(cs[i], cs[j]),
        ]..sort();
      }();

  double _similarity(double d) {
    final pairs = _pairs;
    if (pairs.isEmpty) return 100;
    // Pairs strictly farther apart than d.
    var lo = 0, hi = pairs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pairs[mid] <= d) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return 100 * (pairs.length - lo) / pairs.length;
  }

  /// The [count] teams closest to [team], nearest first.
  List<Neighbor> neighbors(int team, {int count = 5}) {
    final me = _coords[team];
    if (me == null) return const [];
    final all = [
      for (final t in result.teams)
        if (t.teamNumber != team) (t, _dist(me, _coords[t.teamNumber]!)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [
      for (final (t, d) in all.take(count))
        Neighbor(t.teamNumber, t.group, d, _similarity(d)),
    ];
  }

  double _z(int j, double v) => std[j] > 0 ? (v - mean[j]) / std[j] : 0;

  /// Every clustering dimension for [team], biggest share of what sets the
  /// team apart first.
  List<Distinction> distinctions(int team, List<int> neighborTeams) {
    final me = _coords[team];
    final raw = _raw[team];
    if (me == null || raw == null) return const [];
    final total = me.fold(0.0, (s, c) => s + c * c);
    final group = result.team(team)?.group;
    final mates = [
      for (final t in result.teams)
        if (t.group == group) _raw[t.teamNumber]!,
    ];
    final out = [
      for (var j = 0; j < features.length; j++)
        Distinction(
          feature: features[j],
          value: result.team(team)!.values[features[j]],
          mean: mean[j],
          std: std[j],
          z: _z(j, raw[j]),
          share: total > 0 ? me[j] * me[j] / total : 0,
          neighborValues: [
            for (final n in neighborTeams)
              if (result.team(n)?.values[features[j]] case final v?) (n, v),
          ],
          groupMean: mates.isEmpty
              ? null
              : mates.map((m) => m[j]).reduce((a, b) => a + b) / mates.length,
        ),
    ]..sort((a, b) => b.share.compareTo(a.share));
    return out;
  }
}
