import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'photo_store.dart' show PhotoStoreException;

const photoStoreAvailable = true;

const _dbName = 'rebuilt_scouting';
const _store = 'held_photos';

Future<web.IDBDatabase>? _db;

Future<web.IDBDatabase> _open() {
  return _db ??= () {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_store)) db.createObjectStore(_store);
    }).toJS;
    request.onsuccess =
        ((web.Event _) => done.complete(request.result as web.IDBDatabase)).toJS;
    request.onerror = ((web.Event _) {
      _db = null; // let the next call try again
      done.completeError(_error('open photo storage', request.error));
    }).toJS;
    return done.future;
  }();
}

PhotoStoreException _error(String what, web.DOMException? e) {
  final quota = e?.name == 'QuotaExceededError';
  return PhotoStoreException(quota
      ? "Couldn't $what: this device's browser storage is full"
      : "Couldn't $what: ${e?.name ?? 'unknown error'} ${e?.message ?? ''}"
          .trim());
}

/// Runs [op] in one transaction and completes when it's committed (quota
/// errors show up as the transaction aborting, not on the request).
Future<JSAny?> _run(String what, String mode,
    web.IDBRequest Function(web.IDBObjectStore store) op) async {
  final db = await _open();
  final done = Completer<JSAny?>();
  final web.IDBTransaction tx;
  final web.IDBRequest request;
  try {
    tx = db.transaction(_store.toJS, mode);
    request = op(tx.objectStore(_store));
  } catch (e) {
    throw PhotoStoreException("Couldn't $what: $e");
  }
  tx.oncomplete = ((web.Event _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  void fail(web.Event _) {
    if (!done.isCompleted) done.completeError(_error(what, tx.error ?? request.error));
  }
  tx.onerror = fail.toJS;
  tx.onabort = fail.toJS;
  return done.future;
}

Future<void> putPhoto(String id, String base64) =>
    _run('save the photo', 'readwrite', (s) => s.put(base64.toJS, id.toJS));

Future<String?> getPhoto(String id) async {
  final value = await _run('read the photo', 'readonly', (s) => s.get(id.toJS));
  return value.isA<JSString>() ? (value as JSString).toDart : null;
}

Future<void> deletePhoto(String id) =>
    _run('delete the photo', 'readwrite', (s) => s.delete(id.toJS));

Future<List<String>> photoIds() async {
  final keys = await _run('list photos', 'readonly', (s) => s.getAllKeys());
  if (keys == null) return [];
  return [
    for (final k in (keys as JSArray<JSAny?>).toDart)
      if (k.isA<JSString>()) (k as JSString).toDart,
  ];
}

Future<void> clearPhotos() =>
    _run('clear photos', 'readwrite', (s) => s.clear());
