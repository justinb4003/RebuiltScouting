import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/analytics/match_stats.dart';
import 'package:rebuilt_scouting/analytics/scout_stats.dart';
import 'package:rebuilt_scouting/models/match_result.dart';
import 'package:rebuilt_scouting/models/pit_result.dart';
import 'package:rebuilt_scouting/models/scouted_match.dart';

Map<String, dynamic> row(int team, int match,
        {List<num> volleys = const [], num acc = 50, Object? winAuto, int tower = 0}) =>
    {
      'team_number': team,
      'match_number': match,
      'scouter_name': 's',
      'teleop_fuel_accuracy': acc,
      'volley_accuracy_list': volleys,
      'endgame_tower_level': tower,
      'win_auto': winAuto,
      'endgame_carried': 1,
      'match_notes': ' hi ',
    };

Map<String, dynamic> tbaMatch(String key, int n, List<String> red, List<String> blue,
        {int? redScore, int? blueScore, String winner = '', int redRp = 0}) =>
    {
      'key': key,
      'comp_level': 'qm',
      'set_number': 1,
      'match_number': n,
      'alliances': {
        'red': {'team_keys': red, 'score': redScore ?? -1},
        'blue': {'team_keys': blue, 'score': blueScore ?? -1},
      },
      'winning_alliance': winner,
      'time': 1774724040,
      'score_breakdown': redScore == null
          ? null
          : {
              'red': {
                'rp': redRp,
                'totalPoints': redScore,
                'endGameTowerRobot2': 'Level2',
                'autoTowerRobot1': 'Level1',
                'hubScore': {'totalCount': 50, 'autoCount': 10, 'teleopCount': 30, 'endgameCount': 10},
              },
              'blue': {'rp': 0, 'totalPoints': blueScore},
            },
    };

void main() {
  group('scouted aggregation', () {
    test('derives volley count and mean accuracy from the volley list', () {
      final m = ScoutedMatch.fromApi(row(1, 1, volleys: [80, 100, 90]));
      expect(m.stat('teleop_volleys'), 3);
      expect(m.stat('teleop_volley_accuracy'), 90);
      expect(m.stat('teleop_fuel_accuracy'), 50);
      final none = ScoutedMatch.fromApi(row(1, 2));
      expect(none.stat('teleop_volleys'), 0);
      expect(none.stat('teleop_volley_accuracy'), isNull);
      expect(m.matchNotes, 'hi');
    });

    test('tri-state win_auto null is left out, bools become 0/1', () {
      final unknown = ScoutedMatch.fromApi(row(1, 1));
      expect(unknown.stat('win_auto'), isNull);
      expect(ScoutedMatch.fromApi(row(1, 1, winAuto: true)).stat('win_auto'), 1);
      expect(ScoutedMatch.fromApi(row(1, 1, winAuto: false)).stat('win_auto'), 0);
      expect(unknown.stat('endgame_carried'), 1);
    });

    test('legacy column names are understood', () {
      final m = ScoutedMatch.fromApi({'scouting_team': 254, 'match_key': 'qm12'});
      expect((m.teamNumber, m.matchNumber), (254, 12));
    });

    test('team means, std dev, rank and event mean', () {
      final rows = [
        for (final (t, mn, acc) in [(1, 1, 10), (1, 2, 20), (1, 3, 30), (1, 4, 40), (2, 1, 5), (2, 2, 15)])
          ScoutedMatch.fromApi(row(t, mn, acc: acc)),
      ];
      const k = 'teleop_fuel_accuracy';
      final stats = aggregateByTeam(rows);
      expect(stats.keys, unorderedEquals([1, 2]));
      expect(stats[1]!.mean(k), 25);
      expect(stats[1]!.stdDev(k), closeTo(12.91, 0.01));
      expect(stats[1]!.max(k), 40);
      expect(stats[1]!.halfDelta(k), 20); // (30+40)/2 - (10+20)/2
      expect(stats[2]!.halfDelta(k), isNull);
      expect(eventMean(stats, k), 17.5); // (25 + 10) / 2
      expect(rankOf(stats, 1, k), 1);
      expect(rankOf(stats, 2, k), 2);
      expect(stats[1]!.mean('win_auto'), isNull);
    });

    test('duplicate scouters count as one match scouted but both feed the mean', () {
      final stats = aggregateByTeam([
        ScoutedMatch.fromApi(row(1, 1, acc: 10)),
        ScoutedMatch.fromApi(row(1, 1, acc: 20)),
      ]);
      expect(stats[1]!.matchesScouted, 1);
      expect(stats[1]!.mean('teleop_fuel_accuracy'), 15);
    });

    test('cache JSON round-trips', () {
      final m = ScoutedMatch.fromApi(row(7, 3, volleys: [50], tower: 2));
      final back = ScoutedMatch.fromJson(m.toJson());
      expect(back.stats, m.stats);
      expect((back.teamNumber, back.matchNumber, back.scouterName), (7, 3, 's'));
    });
  });

  group('official results', () {
    test('parses TBA, treats -1 scores as unplayed, reads per-robot tower levels', () {
      final played = MatchResult.fromTba(tbaMatch('2026x_qm1', 1, ['frc1', 'frc2', 'frc3'],
          ['frc4', 'frc5', 'frc6'], redScore: 100, blueScore: 80, winner: 'red', redRp: 3));
      expect(played.played, isTrue);
      expect(played.red.teams, [1, 2, 3]);
      expect(played.red.rp, 3);
      expect(played.red.breakdown!.autoTower, [1, 0, 0]);
      expect(played.red.breakdown!.endTower, [0, 2, 0]);
      expect(played.won(1), isTrue);
      expect(played.won(5), isFalse);
      expect(played.won(99), isNull);

      final upcoming = MatchResult.fromTba(
          tbaMatch('2026x_qm2', 2, ['frc1', 'frc2', 'frc3'], ['frc4', 'frc5', 'frc6']));
      expect(upcoming.played, isFalse);
      expect(upcoming.red.score, isNull);
      expect(upcoming.won(1), isNull);
    });

    test('cache JSON round-trips', () {
      final m = MatchResult.fromTba(tbaMatch('k', 1, ['frc1', 'frc2', 'frc3'], ['frc4', 'frc5', 'frc6'],
          redScore: 100, blueScore: 80, winner: 'red', redRp: 3));
      final back = MatchResult.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
      expect(back.red.breakdown!.hubTotal, 50);
    });

    test('team record counts wins, ties and RP over played quals', () {
      final ms = [
        MatchResult.fromTba(tbaMatch('a', 1, ['frc1', 'frc2', 'frc3'], ['frc4', 'frc5', 'frc6'],
            redScore: 100, blueScore: 80, winner: 'red', redRp: 3)),
        MatchResult.fromTba(tbaMatch('b', 2, ['frc4', 'frc5', 'frc6'], ['frc1', 'frc2', 'frc3'],
            redScore: 90, blueScore: 90, winner: '', redRp: 1)),
        MatchResult.fromTba(tbaMatch('c', 3, ['frc1', 'frc2', 'frc3'], ['frc4', 'frc5', 'frc6'])),
      ];
      final r = teamRecord(ms, 1);
      expect((r.wins, r.losses, r.ties), (1, 0, 1));
      expect(r.label, '1-0-1');
      expect(r.avgScore, 95);
      expect(r.avgRp, 1.5); // 3 RP as red in match 1; blue has no breakdown rp in match 2 -> 0
      expect(matchesForTeam(ms, 1).length, 3);
      expect(matchesForTeam(ms, 4).length, 3);
    });
  });

  group('pit results', () {
    test('notes-only records and photo URLs survive the cache', () {
      final noteOnly = PitResult.fromJson({'team_number': 5, 'notes': 'fast', 'drive_train': null});
      expect(noteOnly.hasFullData, isFalse);
      final back = PitResult.fromJson(noteOnly.toJson());
      expect(back.hasFullData, isFalse);

      final full = PitResult.fromJson({
        'team_number': 5,
        'drive_train': 'Swerve',
        'fuel_capacity': null,
        'image_names': ['https://x/y.jpeg'],
      });
      expect(full.hasFullData, isTrue);
      expect(PitResult.fromJson(full.toJson()).imageUrls, ['https://x/y.jpeg']);
      // Posted records stay unchanged.
      final posted = PitResult(scouterName: 's', secretTeamKey: 'k', eventKey: 'e', teamNumber: 1);
      expect(posted.toJson().containsKey('image_names'), isFalse);
      expect(posted.toJson().containsKey('has_full_data'), isFalse);
    });
  });
}
