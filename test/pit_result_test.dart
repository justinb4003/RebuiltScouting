import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/pit_result.dart';

PitResult _pit({String? photo}) => PitResult(
      scouterName: 'Sam',
      secretTeamKey: 'key',
      eventKey: '2026mitry',
      teamNumber: 4003,
      driveTrain: 'Tank',
      notes: 'fast',
      photoBase64: photo,
    );

void main() {
  test('held record keeps its photo through toJson/fromJson', () {
    final original = _pit(photo: 'aGVsbG8=');
    final json = original.toJson();
    expect(json['images'], ['data:image/jpeg;base64,aGVsbG8=']);
    final back = PitResult.fromJson(json);
    expect(back.photoBase64, 'aGVsbG8=');
    expect(back.id, original.id);
    expect(back.timestamp, original.timestamp);
    expect(back.driveTrain, 'Tank');
    // And again, so a retry posts the same photo.
    expect(back.toJson()['images'], json['images']);
  });

  test('no photo stays no photo', () {
    final back = PitResult.fromJson(_pit().toJson());
    expect(back.photoBase64, isNull);
    expect(back.toJson()['images'], isEmpty);
  });

  test('older stored shapes still load', () {
    final base = _pit().toJson();
    expect(PitResult.fromJson({...base, 'images': 'aGVsbG8='}).photoBase64,
        'aGVsbG8=');
    expect(
        PitResult.fromJson({...base, 'images': null, 'photo_base64': 'aGk='})
            .photoBase64,
        'aGk=');
  });
}
