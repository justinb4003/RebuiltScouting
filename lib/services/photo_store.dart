// Held pit photos, keyed by the held record's id. On the web they live in
// IndexedDB, which has far more room than localStorage's ~5 MB; elsewhere
// photoStoreAvailable is false and photos stay inline in the record.
export 'photo_store_stub.dart' if (dart.library.js_interop) 'photo_store_web.dart';

/// A photo couldn't be read or written (e.g. the browser's storage is full).
class PhotoStoreException implements Exception {
  final String message;
  PhotoStoreException(this.message);
  @override
  String toString() => message;
}
