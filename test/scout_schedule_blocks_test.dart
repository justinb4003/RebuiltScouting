import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/scout_schedule.dart';

void main() {
  final roster = [for (var i = 1; i <= 22; i++) 'S$i'];
  final friends = [
    ['S1', 'S2', 'S3'],
    ['S4', 'S5'],
    ['S6', 'S7', 'S8', 'S9'],
  ];

  test('every block has six, friends always together, loads even', () {
    for (var seed = 0; seed < 100; seed++) {
      final blocks = toBlocks(generateSchedule(roster, friends, blockRanges(80, 8), Random(seed)));
      expect(blocks.map((b) => b.range).first, 'Q1–Q10');
      expect(blocks.length, 8);
      for (final b in blocks) {
        expect(b.names.length, 6, reason: 'seed $seed ${b.range}');
        expect(b.names.values.toSet().length, 6);
        final here = b.names.values.toSet();
        for (final g in friends) {
          final inBlock = g.where(here.contains).length;
          expect(inBlock == 0 || inBlock == g.length, isTrue, reason: 'seed $seed: $g split in ${b.range}');
        }
      }
      // 48 seats over 22 people: everyone 2 or 3 blocks.
      final counts = blocksPerPerson(fromBlocks(blocks)).values;
      expect(counts.reduce(min), greaterThanOrEqualTo(2), reason: 'seed $seed');
      expect(counts.reduce(max), lessThanOrEqualTo(3), reason: 'seed $seed');
    }
  });

  test('different seeds give different schedules', () {
    final a = generateSchedule(roster, friends, blockRanges(80, 11), Random(1));
    final b = generateSchedule(roster, friends, blockRanges(80, 11), Random(2));
    expect(a.map((s) => '${s.station}${s.scouterName}${s.firstMatch}').join(),
        isNot(b.map((s) => '${s.station}${s.scouterName}${s.firstMatch}').join()));
  });

  test('fewer than six people: everyone every block', () {
    final blocks = toBlocks(generateSchedule(['A', 'B', 'C'], [], blockRanges(25, 3), Random(3)));
    expect(blocks.map((b) => b.range), ['Q1–Q9', 'Q10–Q17', 'Q18–Q25']);
    expect(blocks.every((b) => b.names.length == 3), isTrue);
  });

  test('setCell replaces one block cell and trims longer shifts', () {
    var shifts = [
      const Shift(scouterName: 'A', station: 'red1', firstMatch: 1, lastMatch: 30),
    ];
    shifts = setCell(shifts, 'red1', 11, 20, 'B');
    expect(toBlocks(shifts).map((b) => '${b.range} ${b.names['red1']}'),
        ['Q1–Q10 A', 'Q11–Q20 B', 'Q21–Q30 A']);
    shifts = setCell(shifts, 'red1', 11, 20, '');
    expect(toBlocks(shifts).map((b) => b.range), ['Q1–Q10', 'Q21–Q30']);
  });

  test('blocks come from scouts and shifts per person', () {
    expect(blockCountFor(22, 3, 80), 11); // 66 seats / 6
    expect(blockCountFor(24, 2, 80), 8);
    expect(blockCountFor(3, 4, 80), 4); // fewer than six: everyone every block
    expect(blockCountFor(200, 6, 80), 80); // never more blocks than matches
    final ranges = blockRanges(80, 11);
    expect(ranges.first, (1, 8));
    expect(ranges.last, (74, 80));
    expect(ranges.map((r) => r.$2 - r.$1 + 1).toSet(), {7, 8});
  });

  test('22 scouts, 3 shifts each: 11 full blocks, everyone exactly 3', () {
    for (var seed = 0; seed < 50; seed++) {
      final blocks = toBlocks(generateSchedule(
          roster, friends, blockRanges(80, blockCountFor(22, 3, 80)), Random(seed)));
      expect(blocks.length, 11);
      expect(blocks.every((b) => b.names.length == 6), isTrue);
      expect(blocksPerPerson(fromBlocks(blocks)).values.toSet(), {3}, reason: 'seed $seed');
    }
  });

  test('findBreaks spots lunch, the end of the day, and other breaks', () {
    DateTime t(int day, int h, int m) => DateTime(2026, 3, day, h, m);
    final times = <int, MatchTime>{};
    var at = t(27, 10, 50);
    for (var q = 1; q <= 60; q++) {
      if (q == 15) at = t(27, 14, 0); // lunch after Q14
      if (q == 30) at = at.add(const Duration(minutes: 30)); // field fault
      if (q == 59) at = t(28, 9, 24); // next morning
      times[q] = MatchTime(at, actual: q < 40);
      at = at.add(const Duration(minutes: 8));
    }
    final breaks = findBreaks(times);
    expect(breaks.map((b) => '${b.afterMatch} ${b.kind.name}'), ['14 lunch', '29 other', '58 endOfDay']);
  });

  test('blockRanges snaps to lunch and the end of the day', () {
    final ranges = blockRanges(80, 11, cuts: [14, 58]);
    expect(ranges.length, 11);
    for (final (a, b) in ranges) {
      expect(a <= 14 && b > 14, isFalse, reason: 'Q$a–Q$b crosses lunch');
      expect(a <= 58 && b > 58, isFalse, reason: 'Q$a–Q$b crosses the end of the day');
    }
    expect(ranges.first.$1, 1);
    expect(ranges.last.$2, 80);
    for (var i = 0; i + 1 < ranges.length; i++) {
      expect(ranges[i + 1].$1, ranges[i].$2 + 1); // no gaps or overlaps
    }
    expect(ranges.map((r) => r.$2 - r.$1 + 1).every((l) => l >= 7 && l <= 8), isTrue);
    // A short stretch still gets a block of its own.
    final few = blockRanges(80, 2, cuts: [3]);
    expect(few.first, (1, 3));
    expect(few.length, 2);
  });

  test('problems: empty stations are errors; uneven shifts are warnings', () {
    final full = generateSchedule(roster, friends, blockRanges(80, 11), Random(5));
    expect(scheduleProblems(full, 80), isEmpty);
    expect(scheduleWarnings(full, roster), isEmpty);
    // Clear one cell: an error for that station and range.
    final holed = setCell(full, 'blue3', 1, 8, '');
    expect(scheduleProblems(holed, 80), ['Blue 3: nobody scouting, Q1–Q8']);
    // Five people can't fill six seats.
    final five = generateSchedule(['A', 'B', 'C', 'D', 'E'], [], blockRanges(20, 2), Random(1));
    final fiveProblems = scheduleProblems(five, 20);
    expect(fiveProblems, isNotEmpty);
    expect(fiveProblems.every((p) => p.contains('nobody scouting')), isTrue);
    // Someone picked but never scheduled, and uneven loads.
    final uneven = setCell(full, 'red1', 1, 8, 'S1');
    expect(scheduleWarnings(uneven, [...roster, 'Newbie']).join(' | '),
        allOf(contains('No shifts: Newbie'), contains('range from')));
  });

  test('max matches: checked up front, avoided when generating, an error after', () {
    // 80 quals × 6 = 480 matches to scout; 22 people need at least 22 each.
    expect(maxMatchesProblem(22, 80, 10), contains('Pick at least 48 scouts or raise the max to 22'));
    expect(maxMatchesProblem(22, 80, 22), isNull);
    expect(maxMatchesProblem(48, 80, 10), isNull);
    // With a reachable max, generating keeps everyone under it.
    final ranges = blockRanges(80, blockCountFor(roster.length, 3, 80));
    final each = (480 / roster.length).ceil();
    final limit = each + 2;
    for (var seed = 0; seed < 10; seed++) {
      final s = generateSchedule(roster, friends, ranges, Random(seed), maxMatches: limit);
      expect(matchesPerPerson(s).values.every((n) => n <= limit), isTrue, reason: 'seed $seed');
      expect(scheduleProblems(s, 80, maxMatches: limit), isEmpty);
    }
    // Over the max is reported by name.
    final full = generateSchedule(roster, friends, ranges, Random(1));
    final most = matchesPerPerson(full).entries.first;
    expect(scheduleProblems(full, 80, maxMatches: most.value - 1).first,
        allOf(startsWith('More than ${most.value - 1} matches: '), contains('${most.key} (${most.value})')));
  });

  test('first lap random, then the same crews repeat; no second shift before everyone has a first', () {
    final twentyFour = [for (var i = 1; i <= 24; i++) 'T$i'];
    for (var seed = 0; seed < 20; seed++) {
      final blocks = toBlocks(generateSchedule(twentyFour, [], blockRanges(80, 12), Random(seed)));
      final crews = [for (final b in blocks) b.names.values.toSet()];
      // Lap 1 (blocks 1-4) has everyone once; laps 2 and 3 repeat it exactly.
      expect(crews.take(4).expand((c) => c).toSet().length, 24);
      for (var k = 4; k < crews.length; k++) {
        expect(crews[k], crews[k - 4], reason: 'seed $seed block ${k + 1}');
        // ...on the same stations.
        expect(blocks[k].names, blocks[k - 4].names, reason: 'seed $seed block ${k + 1}');
      }
    }
    // 22 people: nobody's (n+1)th shift comes before everyone's nth. With
    // groups that can't always hold (a group of 4 and one of 3 left over
    // for 6 seats), but it's never off by more than one.
    for (var seed = 0; seed < 50; seed++) {
      final withGroups = seed.isOdd;
      final blocks = toBlocks(
          generateSchedule(roster, withGroups ? friends : [], blockRanges(80, 11), Random(seed)));
      final count = {for (final n in roster) n: 0};
      for (final b in blocks) {
        final low = count.values.reduce(min);
        final here = b.names.values.toSet();
        final waiting = [for (final e in count.entries) if (e.value == low && !here.contains(e.key)) e.key];
        for (final n in here) {
          expect(count[n]! <= low + 1, isTrue, reason: 'seed $seed ${b.range}: $n');
          // Someone ahead only when everyone behind is already in.
          if (!withGroups && count[n]! > low) {
            expect(waiting, isEmpty, reason: 'seed $seed ${b.range}: $n went before $waiting');
          }
        }
        for (final n in b.names.values) {
          count[n] = count[n]! + 1;
        }
      }
    }
  });
}
