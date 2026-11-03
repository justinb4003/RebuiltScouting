import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/analytics/cluster_similarity.dart';
import 'package:rebuilt_scouting/models/cluster_config.dart';
import 'package:rebuilt_scouting/models/cluster_result.dart';

ClusterResult _result({Map<String, double> weights = const {}}) => ClusterResult.fromJson({
      'k': 2,
      'has_opr': false,
      'features': ['a', 'b'],
      'weights': weights,
      'available_features': [],
      'groups': [],
      'teams': [
        {'team_number': 1, 'group': 1, 'values': {'a': 0.0, 'b': 0.0}},
        {'team_number': 2, 'group': 1, 'values': {'a': 1.0, 'b': 0.0}},
        {'team_number': 3, 'group': 2, 'values': {'a': 0.0, 'b': 1.0}},
        {'team_number': 4, 'group': 2, 'values': {'a': 10.0, 'b': 10.0}},
      ],
    });

void main() {
  test('nearest neighbors come first', () {
    final space = ClusterSpace(_result());
    final n = space.neighbors(1, count: 3);
    expect(n.map((x) => x.teamNumber).toList()..removeLast(), unorderedEquals([2, 3]));
    expect(n.last.teamNumber, 4);
    expect(n.first.similarity, greaterThan(n.last.similarity));
  });

  test('weights break ties between equally close teams', () {
    final space = ClusterSpace(_result(weights: {'b': 3}));
    expect(space.neighbors(1, count: 1).single.teamNumber, 2);
  });

  test('distinction shares sum to 1 and sort biggest first', () {
    final d = ClusterSpace(_result(weights: {'a': 2})).distinctions(4, [3]);
    expect(d.fold(0.0, (s, x) => s + x.share), closeTo(1, 1e-9));
    expect(d.first.feature, 'a');
    expect(d.first.z, greaterThan(0));
    expect(d.first.neighborValues.single, (3, 0.0));
  });

  test('axes default to the dimensions that best separate the groups', () {
    // b's group averages (0 vs 5.5) sit further apart, relative to its
    // spread, than a's (0.5 vs 5).
    expect(_result().defaultAxes, ('b', 'a'));
  });

  test('config signature ignores order and default weights', () {
    const a = ClusterConfig(features: ['x', 'y'], weights: {'x': 1.0, 'y': 2.0});
    const b = ClusterConfig(features: ['y', 'x'], weights: {'y': 2.0});
    expect(a.sameAs(b), isTrue);
    expect(a.sameAs(b.copyWith(k: 5)), isFalse);
  });
}
