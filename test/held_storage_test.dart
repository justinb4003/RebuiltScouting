import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/models/pit_result.dart';
import 'package:rebuilt_scouting/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Runs on the VM, where there's no photo store, so this covers the inline
// fallback; the IndexedDB path needs a browser.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('held pit photo survives save, migrate and reload without a store',
      () async {
    final storage = StorageService();
    final pit = PitResult(
        scouterName: 'Sam',
        secretTeamKey: 'k',
        eventKey: '2026mitry',
        teamNumber: 4003,
        photoBase64: 'aGVsbG8=');
    await storage.addHeldPitResult(pit);
    await storage.migrateHeldPhotos();

    final held = await storage.loadHeldPitData();
    expect(held.single.photoBase64, 'aGVsbG8=');
    expect(held.single.photoInStore, isFalse);
    await storage.loadHeldPhoto(held.single);
    expect(held.single.toJson()['images'], ['data:image/jpeg;base64,aGVsbG8=']);

    await storage.removeHeldPitResult(pit.id);
    expect(await storage.loadHeldPitData(), isEmpty);
  });

  test('concurrent adds and removes all land', () async {
    final storage = StorageService();
    final pits = [
      for (var i = 0; i < 10; i++)
        PitResult(
            scouterName: 'S', secretTeamKey: 'k', eventKey: 'e', teamNumber: i),
    ];
    await Future.wait([for (final p in pits) storage.addHeldPitResult(p)]);
    await Future.wait(
        [for (final p in pits.take(5)) storage.removeHeldPitResult(p.id)]);
    final left = await storage.loadHeldPitData();
    expect(left.map((p) => p.teamNumber), [5, 6, 7, 8, 9]);
  });
}
