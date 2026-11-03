// Small browser-only hooks. The stub keeps tests and non-web builds
// compiling; dart:js_interop only exists on the web.
export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
