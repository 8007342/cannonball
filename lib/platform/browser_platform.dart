/// Browser services stay optional so simulation/widget tests run without a DOM.
library;

export 'browser_platform_stub.dart'
    if (dart.library.js_interop) 'browser_platform_web.dart';
