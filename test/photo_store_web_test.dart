@TestOn('browser')
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/pit_result.dart';
import 'package:rebuilt_scouting/services/photo_store.dart';
import 'package:rebuilt_scouting/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// flutter test --platform chrome test/photo_store_web_test.dart
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearPhotos();
  });

  test('photo store round trip', () async {
    expect(photoStoreAvailable, isTrue);
    await putPhoto('a', 'aGVsbG8=');
    expect(await getPhoto('a'), 'aGVsbG8=');
    expect(await photoIds(), ['a']);
    await deletePhoto('a');
    expect(await getPhoto('a'), isNull);
  });

  test('held pit photo goes to the store and comes back for upload', () async {
    final storage = StorageService();
    final pit = PitResult(
        scouterName: 'Sam',
        secretTeamKey: 'k',
        eventKey: '2026mitry',
        teamNumber: 4003,
        photoBase64: 'aGVsbG8=');
    await storage.addHeldPitResult(pit);

    final held = (await storage.loadHeldPitData()).single;
    expect(held.photoInStore, isTrue);
    expect(held.photoBase64, isNull);
    await storage.loadHeldPhoto(held);
    expect(held.toJson()['images'], ['data:image/jpeg;base64,aGVsbG8=']);
    expect(held.toJson().containsKey(heldPhotoKey), isFalse);

    await storage.removeHeldPitResult(pit.id);
    expect(await photoIds(), isEmpty);
  });

  test('startup migration moves inline photos and sweeps orphans', () async {
    final inline = PitResult(
        scouterName: 'Sam',
        secretTeamKey: 'k',
        eventKey: '2026mitry',
        teamNumber: 4003,
        photoBase64: 'aGk=');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('held_pit_data', jsonEncode([inline.toJson()]));
    await putPhoto('orphan', 'eA==');

    final storage = StorageService();
    await storage.migrateHeldPhotos();

    expect(await photoIds(), [inline.id]);
    final held = (await storage.loadHeldPitData()).single;
    expect(held.photoInStore, isTrue);
    expect(held.photoBase64, isNull);
    await storage.loadHeldPhoto(held);
    expect(held.photoBase64, 'aGk=');
  });
}
