import 'dart:js_interop';
import 'package:web/web.dart' as web;

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

/// Reload the page: the app starts over from scratch.
void reloadPage() => web.window.location.reload();

/// Open [url] in this tab, or
/// in a new one.
void openUrl(String url, {bool newTab = false}) {
  web.window.open(url, newTab ? '_blank' : '_self');
}
