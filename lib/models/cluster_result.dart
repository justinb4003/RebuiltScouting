import 'dart:math' as math;

/// Response from the API's GetClusters endpoint.
class ClusterFeature {
  final String name;
  final String source; // 'scouted' or 'opr'
  final double variance;
  final bool isDefault;

  ClusterFeature({
    required this.name,
    required this.source,
    required this.variance,
    required this.isDefault,
  });

  bool get isOpr => source == 'opr';

  /// teleop_fuel_made -> Teleop Fuel Made, hubScore_teleopCount ->
  /// OPR Hub Score Teleop Count.
  String get label {
    final words = name
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return isOpr && !words.startsWith('Opr') ? 'OPR $words' : words;
  }

  factory ClusterFeature.fromJson(Map<String, dynamic> json) => ClusterFeature(
    name: json['name'] as String,
    source: json['source'] as String,
    variance: (json['variance'] as num?)?.toDouble() ?? 0,
    isDefault: json['default'] == true,
  );
}

class ClusterProfileEntry {
  final String feature;
  final double? mean;
  final double? eventMean;
  final double z;

  ClusterProfileEntry({
    required this.feature,
    this.mean,
    this.eventMean,
    required this.z,
  });

  factory ClusterProfileEntry.fromJson(Map<String, dynamic> json) =>
      ClusterProfileEntry(
        feature: json['feature'] as String,
        mean: (json['mean'] as num?)?.toDouble(),
        eventMean: (json['event_mean'] as num?)?.toDouble(),
        z: (json['z'] as num?)?.toDouble() ?? 0,
      );
}

class ClusterGroup {
  final int group;
  final List<int> teams;
  final double? strength;
  final List<ClusterProfileEntry> profile;

  ClusterGroup({
    required this.group,
    required this.teams,
    this.strength,
    required this.profile,
  });

  factory ClusterGroup.fromJson(Map<String, dynamic> json) => ClusterGroup(
    group: (json['group'] as num).toInt(),
    teams: (json['teams'] as List).map((t) => (t as num).toInt()).toList(),
    strength: (json['strength'] as num?)?.toDouble(),
    profile: (json['profile'] as List)
        .map((p) => ClusterProfileEntry.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

class ClusterTeam {
  final int teamNumber;
  final int group;
  final Map<String, double?> values;

  ClusterTeam({
    required this.teamNumber,
    required this.group,
    required this.values,
  });

  factory ClusterTeam.fromJson(Map<String, dynamic> json) => ClusterTeam(
    teamNumber: (json['team_number'] as num).toInt(),
    group: (json['group'] as num).toInt(),
    values: (json['values'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num?)?.toDouble()),
    ),
  );
}

class ClusterResult {
  final int k;
  final bool hasOpr;
  final List<String> features;

  /// Multiplier per feature the API applied; missing = 1.
  final Map<String, double> weights;
  final List<ClusterFeature> availableFeatures;
  final String? strengthMetric;
  final List<ClusterGroup> groups;
  final List<ClusterTeam> teams;
  final List<int> excluded;
  final List<int> dropped;

  /// The response as decoded, so it can be cached and parsed again.
  final Map<String, dynamic> json;

  ClusterResult({
    required this.k,
    required this.hasOpr,
    required this.features,
    this.weights = const {},
    required this.availableFeatures,
    this.strengthMetric,
    required this.groups,
    required this.teams,
    required this.excluded,
    required this.dropped,
    this.json = const {},
  });

  double weightOf(String feature) => weights[feature] ?? 1.0;

  ClusterTeam? team(int teamNumber) {
    for (final t in teams) {
      if (t.teamNumber == teamNumber) return t;
    }
    return null;
  }

  /// Lowest and highest value any clustered team has for [feature].
  (double, double)? rangeOf(String feature, {int? group}) {
    double? lo, hi;
    for (final t in teams) {
      if (group != null && t.group != group) continue;
      final v = t.values[feature];
      if (v == null) continue;
      if (lo == null || v < lo) lo = v;
      if (hi == null || v > hi) hi = v;
    }
    return lo == null ? null : (lo, hi!);
  }

  /// Default chart axes: X is the dimension that best tells the groups
  /// apart (share of its variance between group averages, R²; unit-free so
  /// points don't win by being big). Y is the next best after discounting
  /// overlap with X (R² × (1 − correlation²)), so the chart isn't a diagonal.
  /// Groups of one are left out: a lone outlier would score R² = 1 on
  /// anything only it does.
  late final (String?, String?) defaultAxes = () {
    final sizes = <int, int>{};
    for (final t in teams) {
      sizes[t.group] = (sizes[t.group] ?? 0) + 1;
    }
    final members = [
      for (final t in teams)
        if (sizes[t.group]! > 1) t,
    ];
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    List<double> column(String f) => [
      for (final t in members) t.values[f] ?? 0,
    ];

    double separation(String f) {
      final all = column(f);
      if (all.length < 2) return 0;
      final m = mean(all);
      final total = all.fold(0.0, (s, v) => s + (v - m) * (v - m));
      if (total <= 0) return 0;
      final byGroup = <int, List<double>>{};
      for (var i = 0; i < members.length; i++) {
        (byGroup[members[i].group] ??= []).add(all[i]);
      }
      var between = 0.0;
      for (final vs in byGroup.values) {
        final gm = mean(vs);
        between += vs.length * (gm - m) * (gm - m);
      }
      return between / total;
    }

    double correlation(String f, String g) {
      final x = column(f), y = column(g);
      if (x.length < 2) return 0;
      final mx = mean(x), my = mean(y);
      var sxy = 0.0, sxx = 0.0, syy = 0.0;
      for (var i = 0; i < x.length; i++) {
        sxy += (x[i] - mx) * (y[i] - my);
        sxx += (x[i] - mx) * (x[i] - mx);
        syy += (y[i] - my) * (y[i] - my);
      }
      return sxx > 0 && syy > 0 ? sxy / math.sqrt(sxx * syy) : 0;
    }

    if (features.isEmpty) return (null, null);
    final scores = {for (final f in features) f: separation(f)};
    String? best(double Function(String f) score, [String? not]) {
      String? top;
      for (final f in features) {
        if (f != not && (top == null || score(f) > score(top))) top = f;
      }
      return top;
    }

    final x = best((f) => scores[f]!);
    final y = best((f) {
      final r = correlation(x!, f);
      return scores[f]! * (1 - r * r);
    }, x);
    return (x, y);
  }();

  ClusterGroup? group(int number) {
    for (final g in groups) {
      if (g.group == number) return g;
    }
    return null;
  }

  ClusterFeature? feature(String name) {
    for (final f in availableFeatures) {
      if (f.name == name) return f;
    }
    return null;
  }

  String labelFor(String name) => feature(name)?.label ?? name;

  /// How groups are ordered, e.g. "OPR avg".
  String? get strengthLabel => switch (strengthMetric) {
    'totalPoints' => 'OPR avg',
    'total_fuel_made' => 'avg fuel made',
    null => null,
    _ => labelFor(strengthMetric!),
  };

  static List<int> _ints(dynamic list) =>
      ((list ?? []) as List).map((t) => (t as num).toInt()).toList();

  factory ClusterResult.fromJson(Map<String, dynamic> json) => ClusterResult(
    k: (json['k'] as num).toInt(),
    hasOpr: json['has_opr'] == true,
    features: (json['features'] as List).cast<String>(),
    weights: ((json['weights'] ?? {}) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    availableFeatures: (json['available_features'] as List)
        .map((f) => ClusterFeature.fromJson(f as Map<String, dynamic>))
        .toList(),
    strengthMetric: json['strength_metric'] as String?,
    groups: (json['groups'] as List)
        .map((g) => ClusterGroup.fromJson(g as Map<String, dynamic>))
        .toList(),
    teams: (json['teams'] as List)
        .map((t) => ClusterTeam.fromJson(t as Map<String, dynamic>))
        .toList(),
    excluded: _ints(json['excluded']),
    dropped: _ints(json['dropped']),
    json: json,
  );
}
