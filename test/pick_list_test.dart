import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/pick_list.dart';

// Mirrors trisonics-api test cases for pick_list.apply_update so optimistic
// local changes match what the server stores.
List<(int, int?)> order(PickList l) =>
    [for (final t in l.teams) (t.teamNumber, t.ranking)];

void main() {
  test('append, move, status changes keep a dense pick order', () {
    var l = PickList.empty();
    for (final tn in [100, 200, 300]) {
      l = l.apply(PickListUpdate(tn, position: 99));
    }
    expect(order(l), [(100, 1), (200, 2), (300, 3)]);

    l = l.apply(const PickListUpdate(300, position: 1));
    expect(l.ranked.map((t) => t.teamNumber), [300, 100, 200]);

    l = l.apply(const PickListUpdate(100, status: PickStatus.dnp));
    expect(l.ranked.map((t) => (t.teamNumber, t.ranking)), [(300, 1), (200, 2)]);
    expect(l.statusOf(100), PickStatus.dnp);

    l = l.apply(const PickListUpdate(100, position: 2));
    expect(l.ranked.map((t) => t.teamNumber), [300, 100, 200]);
    expect(l.entryFor(100)!.dnp, isFalse);

    l = l.apply(const PickListUpdate(200, status: PickStatus.unranked));
    expect(l.entryFor(200), isNull, reason: 'empty entries are dropped');
  });

  test('notes and picked are independent of ranking', () {
    var l = PickList.empty()
        .apply(const PickListUpdate(1, position: 1))
        .apply(const PickListUpdate(1, picked: true))
        .apply(const PickListUpdate(2, notes: '  fast  '));
    expect(l.entryFor(1)!.picked, isTrue);
    expect(l.entryFor(1)!.ranking, 1);
    expect(l.entryFor(2)!.notes, 'fast');
    expect(l.statusOf(2), PickStatus.unranked);
    l = l.apply(const PickListUpdate(2, notes: ''));
    expect(l.entryFor(2), isNull);
  });

  test('legacy Streamlit docs with gaps and stale DNP rankings normalise', () {
    final legacy = PickList.fromJson({
      'teams': [
        {'team_number': 1, 'ranking': 1},
        {'team_number': 2, 'ranking': 5},
        {'team_number': 3, 'ranking': 3, 'dnp': true},
      ],
    });
    final l = legacy.apply(const PickListUpdate(9, position: 2));
    expect(l.ranked.map((t) => (t.teamNumber, t.ranking)),
        [(1, 1), (9, 2), (2, 3)]);
    expect(l.entryFor(3)!.ranking, isNull);
  });

  test('apply does not mutate the original list', () {
    final a = PickList.empty().apply(const PickListUpdate(1, position: 1));
    a.apply(const PickListUpdate(1, status: PickStatus.dnp));
    expect(a.entryFor(1)!.isRanked, isTrue);
  });
}
