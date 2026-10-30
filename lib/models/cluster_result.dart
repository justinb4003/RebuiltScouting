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
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
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
        values: (json['values'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num?)?.toDouble())),
      );
}

class ClusterResult {
  final int k;
  final bool scaled;
  final bool hasOpr;
  final List<String> features;
  final List<ClusterFeature> availableFeatures;
  final String? strengthMetric;
  final List<ClusterGroup> groups;
  final List<ClusterTeam> teams;
  final List<int> excluded;
  final List<int> dropped;

  ClusterResult({
    required this.k,
    required this.scaled,
    required this.hasOpr,
    required this.features,
    required this.availableFeatures,
    this.strengthMetric,
    required this.groups,
    required this.teams,
    required this.excluded,
    required this.dropped,
  });

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
        scaled: json['scaled'] == true,
        hasOpr: json['has_opr'] == true,
        features: (json['features'] as List).cast<String>(),
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
      );
}
