import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/rankings.dart';

final _json = {
  'rankings': [
    {
      'rank': 1,
      'team_key': 'frc6090',
      'record': {'wins': 12, 'losses': 0, 'ties': 0},
      'matches_played': 12,
      'dq': 0,
      'sort_orders': [4.25, 288.5],
      'extra_stats': [51],
    },
    {
      'rank': 2,
      'team_key': 'frc254',
      'record': {'wins': 6, 'losses': 5, 'ties': 1},
      'matches_played': 12,
      'dq': 1,
      'sort_orders': [4.5, null],
      'extra_stats': [40],
    },
    {
      'rank': 3,
      'team_key': 'frc111',
      'record': {'wins': 1, 'losses': 11, 'ties': 0},
      'matches_played': 12,
      'dq': 0,
      'sort_orders': [1, 10],
      'extra_stats': [],
    },
  ],
  'sort_order_info': [
    {'name': 'Ranking Score', 'precision': 2},
    {'name': 'Avg Match', 'precision': 1},
  ],
  'extra_stats_info': [
    {'name': 'Total RP', 'precision': 0},
  ],
};

void main() {
  test('parses TBA shape and builds columns from info arrays', () {
    final d = RankingsData.fromJson(_json);
    expect(d.rows.map((r) => r.teamNumber), [6090, 254, 111]);
    expect(d.rows[1].record, '6-5-1');
    expect(d.rows[1].sortOrders, [4.5, null]);
    expect(d.rows[2].sortOrders, [1.0, 10.0]);
    expect(d.columns.map((c) => c.label), [
      'Rank',
      'Team',
      'Name',
      'W-L-T',
      'Played',
      'DQ',
      'Ranking Score',
      'Avg Match',
      'Total RP',
    ]);
    expect(d.columns[6].precision, 2);
    expect(d.sortOrderInfo[0].format(4.256), '4.26');
  });

  test('null or missing rankings means empty, not an error', () {
    expect(RankingsData.fromJson({'rankings': null}).isEmpty, isTrue);
    expect(RankingsData.fromJson(<String, dynamic>{}).isEmpty, isTrue);
  });

  test('cache round trip preserves rows and fetch time', () {
    final d = RankingsData.fromJson(
      _json,
      fetchedAt: DateTime.utc(2026, 3, 1, 12),
    );
    final back = RankingsData.fromJson(d.toJson());
    expect(back.rows.map((r) => r.teamNumber), [6090, 254, 111]);
    expect(back.rows[1].sortOrders, [4.5, null]);
    expect(back.fetchedAt, DateTime.utc(2026, 3, 1, 12));
    expect(back.extraStatsInfo.single.name, 'Total RP');
  });

  test('sorting: direction, nulls last, tie falls back to rank', () {
    final d = RankingsData.fromJson(_json);
    final cols = d.columns;
    List<int> order(RankingColumn c, bool asc, {String Function(int)? n}) =>
        sortRankings(
          d.rows,
          c,
          asc,
          nameOf: n,
        ).map((r) => r.teamNumber).toList();

    expect(order(cols[1], true), [111, 254, 6090]); // team
    expect(order(cols[6], false), [254, 6090, 111]); // score desc
    expect(order(cols[6], true), [111, 6090, 254]); // score asc
    // Missing Avg Match sorts last in both directions.
    expect(order(cols[7], false), [6090, 111, 254]);
    expect(order(cols[7], true), [111, 6090, 254]);
    expect(order(cols[3], false), [6090, 254, 111]); // win fraction
    expect(order(cols[5], false), [254, 6090, 111]); // DQ desc, rank tiebreak
    final names = {6090: 'Zed', 254: 'alpha', 111: ''};
    expect(order(cols[2], true, n: (t) => names[t]!), [254, 6090, 111]);
  });
}
