import 'dart:js_interop';

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persist();
}

@JS('navigator.storage')
external _StorageManager? get _storageManager;

@JS('window.addEventListener')
external void _addEventListener(String type, JSFunction listener);

/// Ask the browser not to evict our localStorage (held scouting data) under
/// storage pressure. Best effort: some browsers decide on their own, or
/// only grant it to installed PWAs.
Future<bool> requestPersistentStorage() async {
  try {
    final storage = _storageManager;
    if (storage == null) return false;
    return (await storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

/// Calls [callback] whenever the browser says the network came back.
void onBrowserOnline(void Function() callback) {
  _addEventListener('online', ((JSAny _) => callback()).toJS);
}
