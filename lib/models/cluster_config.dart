/// Settings that decide how teams are clustered: which dimensions, how much
/// each one counts and how many groups. Dimensions are always normalized
/// for clustering; screens show real units.
///
/// One per season. The team default lives on the API (GetClusterConfig /
/// SetClusterConfig); anyone can override it locally.
class ClusterConfig {
  /// Empty = let the API pick its built-in defaults.
  final List<String> features;

  /// Multiplier per feature after normalizing; missing = 1.
  final Map<String, double> weights;
  final int k;
  final String? updatedBy;
  final DateTime? updatedAt;

  const ClusterConfig({
    this.features = const [],
    this.weights = const {},
    this.k = 4,
    this.updatedBy,
    this.updatedAt,
  });

  /// What the app uses before anyone publishes a team default.
  static const builtIn = ClusterConfig();

  static const minK = 2;
  static const maxK = 8;
  static const weightSteps = [0.5, 1.0, 1.5, 2.0, 3.0];

  double weightOf(String feature) => weights[feature] ?? 1.0;

  ClusterConfig copyWith({
    List<String>? features,
    Map<String, double>? weights,
    int? k,
  }) {
    final f = features ?? this.features;
    final w = weights ?? this.weights;
    return ClusterConfig(
      features: f,
      // Weights only matter for selected features; 1 is the default.
      weights: {
        for (final e in w.entries)
          if (f.contains(e.key) && e.value != 1.0) e.key: e.value,
      },
      k: k ?? this.k,
    );
  }

  /// Same clustering settings, ignoring who saved them and when.
  bool sameAs(ClusterConfig other) => signature == other.signature;

  /// Stable string for cache keys and comparisons; feature order doesn't
  /// change the clustering, so it doesn't change the signature.
  String get signature {
    final f = [...features]..sort();
    final w = [
      for (final e in weights.entries)
        if (e.value != 1.0) '${e.key}:${e.value}',
    ]..sort();
    return 'k=$k|f=${f.join(',')}|w=${w.join(',')}';
  }

  Map<String, dynamic> toJson() => {
        'features': features,
        'weights': weights,
        'k': k,
        if (updatedBy != null) 'updated_by': updatedBy,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  factory ClusterConfig.fromJson(Map<String, dynamic> json) => ClusterConfig(
        features: ((json['features'] ?? []) as List).cast<String>(),
        weights: ((json['weights'] ?? {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        k: (json['k'] as num?)?.toInt() ?? 4,
        updatedBy: json['updated_by'] as String?,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}
