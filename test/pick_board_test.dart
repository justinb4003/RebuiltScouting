import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/pick_board.dart';
import 'package:rebuilt_scouting/models/pick_list.dart';

Ballot ballot(String voter, List<int> order, {List<int> dnp = const []}) {
  var list = PickList.empty();
  for (final tn in order) {
    list = list.apply(PickListUpdate(tn, position: 999));
  }
  for (final tn in dnp) {
    list = list.apply(PickListUpdate(tn, status: PickStatus.dnp));
  }
  return Ballot(voter, list);
}

PickBoard board(List<Ballot> ballots, {Set<int> taken = const {}}) =>
    PickBoard(ballots: {for (final b in ballots) b.key: b}, taken: taken);

void main() {
  test('voterKey matches the API normalization', () {
    expect(voterKey(' Justin B '), 'justin-b');
    expect(voterKey('Alex!!'), 'alex');
    expect(voterKey('!!!'), '');
  });

  test('row #k is the team the most people put at #k', () {
    final b = board([
      ballot('Justin', [3539, 6090, 1918]),
      ballot('Alex', [6090, 3539, 1918]),
      ballot('Sam', [3539, 1918], dnp: [6090]),
      ballot('Idle', []), // opened the board, ranked nobody: not counted
    ]);
    final rows = b.rows(40);
    // #1: 3539 (2 votes). #2: 3539 is placed; 6090 and 1918 have one vote
    // each -> a tie, both shown at #2 (1918 first: it's on more lists).
    expect(rows.map((r) => r.teamNumber), [3539, 1918, 6090]);
    expect(rows.map((r) => r.agreedRank), [1, 2, 2]);
    expect(rows.map((r) => r.agreement!.round()), [67, 33, 33]);
    expect(rows[2].dnpBy, ['sam']);
  });

  test('a spot nobody put a remaining team at is skipped', () {
    final b = board([
      ballot('A', [11, 22, 33]),
      ballot('B', [22, 11, 33]),
    ]);
    // #1: 11 and 22 tie. #2: both votes went to them, so no #2. #3: 33.
    final rows = b.rows(40);
    expect(rows.map((r) => r.teamNumber), [11, 22, 33]);
    expect(rows.map((r) => r.agreedRank), [1, 1, 3]);
    expect(rows.map((r) => r.agreement), [50, 50, 100]);
  });

  test('a team shows once, at the first spot it wins', () {
    // 3539 has the most votes at #1 and at #2; #2 goes to the next team.
    final b = board([
      ballot('A', [3539, 254]),
      ballot('B', [3539, 254]),
      ballot('C', [6090, 3539]),
      ballot('D', [1918, 3539]),
    ]);
    final rows = b.rows(40);
    expect(rows.map((r) => r.teamNumber).take(2), [3539, 254]);
    expect(rows.map((r) => r.agreement).take(2), [50, 50]);
    // 6090 and 1918 never win a spot: listed after, without a spot.
    expect(rows.skip(2).map((r) => r.agreedRank), [null, null]);
    expect(rows.skip(2).map((r) => r.agreement), [null, null]);
  });

  test('full bar only when everyone has it in the same spot', () {
    final b = board([
      ballot('Justin', [1, 2]),
      ballot('Alex', [1, 2]),
    ]);
    expect(b.rows(40).map((r) => r.agreement), [100, 100]);
    final close = board([ballot('Justin', [1, 2]), ballot('Alex', [2, 1])]);
    expect(close.rows(40).map((r) => r.agreement), [50, 50]); // close != agree
    final solo = board([ballot('Justin', [7, 3])]).rows(40);
    expect(solo.map((r) => r.teamNumber), [7, 3]); // one voter: their list
    expect(solo.first.agreement, isNull);
    final dnpOnly = board([
      ballot('Justin', [1], dnp: [244]),
      ballot('Alex', [1], dnp: [244]),
    ]).rows(40);
    // Nobody ranked 244 (DNP only): not on the board at all.
    expect(dnpOnly.map((r) => r.teamNumber), [1]);
  });

  test('taken flags pass through and round-trip with the cache', () {
    final b = board([ballot('Justin', [254, 1678])], taken: {254});
    final again = PickBoard.fromJson(
        Map<String, dynamic>.from(b.toJson()));
    expect(again.taken, {254});
    expect(again.rows(40).first.taken, isTrue);
    expect(again.ballots['justin']!.list.ranked.map((e) => e.teamNumber),
        [254, 1678]);
  });
}
