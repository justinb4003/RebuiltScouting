// No IndexedDB here: held pit records keep their photo inline.
const photoStoreAvailable = false;

Future<void> putPhoto(String id, String base64) =>
    throw UnsupportedError('No photo store on this platform');

Future<String?> getPhoto(String id) async => null;

Future<void> deletePhoto(String id) async {}

Future<List<String>> photoIds() async => [];

Future<void> clearPhotos() async {}
