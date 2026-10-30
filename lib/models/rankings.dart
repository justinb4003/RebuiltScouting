/// Official event rankings, proxied from TBA by the API's GetRankings.
/// Column meaning is game specific, so the API describes the sort-order and
/// extra-stat columns in `sort_order_info` / `extra_stats_info`.
class RankingColumnInfo {
  final String name;
  final int precision;

  const RankingColumnInfo(this.name, this.precision);

  factory RankingColumnInfo.fromJson(Map<String, dynamic> json) =>
      RankingColumnInfo(
        (json['name'] ?? '').toString(),
        (json['precision'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'precision': precision};

  String format(num? v) => v == null ? '–' : v.toStringAsFixed(precision);
}

class RankingRow {
  final int rank;
  final int teamNumber;
  final int wins;
  final int losses;
  final int ties;
  final int matchesPlayed;
  final int dq;
  final List<double?> sortOrders;
  final List<double?> extraStats;

  const RankingRow({
    required this.rank,
    required this.teamNumber,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.matchesPlayed = 0,
    this.dq = 0,
    this.sortOrders = const [],
    this.extraStats = const [],
  });

  String get record => '$wins-$losses-$ties';

  /// Win fraction (ties count half) for sorting the W-L-T column.
  double get winFraction {
    final games = wins + losses + ties;
    return games == 0 ? 0 : (wins + ties / 2) / games;
  }

  static List<double?> _nums(dynamic v) =>
      v is List ? [for (final n in v) (n as num?)?.toDouble()] : const [];

  factory RankingRow.fromJson(Map<String, dynamic> json) {
    final record = (json['record'] as Map?) ?? const {};
    // TBA uses "frc1234"; our own cache stores team_number directly.
    final teamKey = (json['team_key'] ?? '').toString();
    return RankingRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamNumber:
          (json['team_number'] as num?)?.toInt() ??
          int.tryParse(teamKey.replaceFirst('frc', '')) ??
          0,
      wins: (record['wins'] as num?)?.toInt() ?? 0,
      losses: (record['losses'] as num?)?.toInt() ?? 0,
      ties: (record['ties'] as num?)?.toInt() ?? 0,
      matchesPlayed: (json['matches_played'] as num?)?.toInt() ?? 0,
      dq: (json['dq'] as num?)?.toInt() ?? 0,
      sortOrders: _nums(json['sort_orders']),
      extraStats: _nums(json['extra_stats']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'team_number': teamNumber,
    'record': {'wins': wins, 'losses': losses, 'ties': ties},
    'matches_played': matchesPlayed,
    'dq': dq,
    'sort_orders': sortOrders,
    'extra_stats': extraStats,
  };
}

class RankingsData {
  final List<RankingRow> rows;
  final List<RankingColumnInfo> sortOrderInfo;
  final List<RankingColumnInfo> extraStatsInfo;
  final DateTime fetchedAt;

  const RankingsData({
    required this.rows,
    required this.sortOrderInfo,
    required this.extraStatsInfo,
    required this.fetchedAt,
  });

  bool get isEmpty => rows.isEmpty;

  /// TBA answers `{"rankings": null}` (or omits it) before an event starts.
  factory RankingsData.fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
  }) {
    List<RankingColumnInfo> info(dynamic v) => v is List
        ? [
            for (final e in v)
              RankingColumnInfo.fromJson(e as Map<String, dynamic>),
          ]
        : const [];
    final raw = json['rankings'];
    return RankingsData(
      rows: raw is List
          ? [
              for (final e in raw)
                RankingRow.fromJson(e as Map<String, dynamic>),
            ]
          : const [],
      sortOrderInfo: info(json['sort_order_info']),
      extraStatsInfo: info(json['extra_stats_info']),
      fetchedAt:
          fetchedAt ??
          DateTime.tryParse((json['fetched_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'rankings': rows.map((r) => r.toJson()).toList(),
    'sort_order_info': sortOrderInfo.map((c) => c.toJson()).toList(),
    'extra_stats_info': extraStatsInfo.map((c) => c.toJson()).toList(),
    'fetched_at': fetchedAt.toIso8601String(),
  };

  /// Table columns in display order.
  List<RankingColumn> get columns => [
    const RankingColumn(RankingColumnKind.rank, 'Rank'),
    const RankingColumn(RankingColumnKind.team, 'Team'),
    const RankingColumn(RankingColumnKind.name, 'Name'),
    const RankingColumn(RankingColumnKind.record, 'W-L-T'),
    const RankingColumn(RankingColumnKind.played, 'Played'),
    const RankingColumn(RankingColumnKind.dq, 'DQ'),
    for (var i = 0; i < sortOrderInfo.length; i++)
      RankingColumn(
        RankingColumnKind.sortOrder,
        sortOrderInfo[i].name,
        index: i,
        precision: sortOrderInfo[i].precision,
      ),
    for (var i = 0; i < extraStatsInfo.length; i++)
      RankingColumn(
        RankingColumnKind.extraStat,
        extraStatsInfo[i].name,
        index: i,
        precision: extraStatsInfo[i].precision,
      ),
  ];
}

enum RankingColumnKind {
  rank,
  team,
  name,
  record,
  played,
  dq,
  sortOrder,
  extraStat,
}

class RankingColumn {
  final RankingColumnKind kind;
  final String label;
  final int index;
  final int precision;

  const RankingColumn(
    this.kind,
    this.label, {
    this.index = 0,
    this.precision = 0,
  });

  bool get isText => kind == RankingColumnKind.name;

  /// Numeric value for this column, or null (text columns / missing data).
  double? valueOf(RankingRow r) => switch (kind) {
    RankingColumnKind.rank => r.rank.toDouble(),
    RankingColumnKind.team => r.teamNumber.toDouble(),
    RankingColumnKind.name => null,
    RankingColumnKind.record => r.winFraction,
    RankingColumnKind.played => r.matchesPlayed.toDouble(),
    RankingColumnKind.dq => r.dq.toDouble(),
    RankingColumnKind.sortOrder =>
      index < r.sortOrders.length ? r.sortOrders[index] : null,
    RankingColumnKind.extraStat =>
      index < r.extraStats.length ? r.extraStats[index] : null,
  };

  /// Rank, team and name read best ascending; stats best-first (descending).
  bool get defaultAscending => switch (kind) {
    RankingColumnKind.rank ||
    RankingColumnKind.team ||
    RankingColumnKind.name => true,
    _ => false,
  };
}

/// Sorted copy of [rows]. Missing values always sort last; ties fall back to
/// official rank so the order is stable and meaningful.
List<RankingRow> sortRankings(
  List<RankingRow> rows,
  RankingColumn column,
  bool ascending, {
  String Function(int teamNumber)? nameOf,
}) {
  final out = [...rows];
  int dir(int c) => ascending ? c : -c;
  out.sort((a, b) {
    int c;
    if (column.isText) {
      final an = nameOf?.call(a.teamNumber).toLowerCase() ?? '';
      final bn = nameOf?.call(b.teamNumber).toLowerCase() ?? '';
      if (an.isEmpty != bn.isEmpty) return an.isEmpty ? 1 : -1;
      c = dir(an.compareTo(bn));
    } else {
      final av = column.valueOf(a);
      final bv = column.valueOf(b);
      if (av == null || bv == null) {
        if (av == bv) return a.rank.compareTo(b.rank);
        return av == null ? 1 : -1;
      }
      c = dir(av.compareTo(bv));
    }
    return c != 0 ? c : a.rank.compareTo(b.rank);
  });
  return out;
}
