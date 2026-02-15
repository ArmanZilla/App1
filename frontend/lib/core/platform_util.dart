/// Platform utility — safe platform detection without dart:io.
///
/// Uses `defaultTargetPlatform` from flutter/foundation which works
/// on all platforms including Flutter Web.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Returns true if running on Android (emulator or device).
bool isAndroid() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

/// Returns true if running on iOS.
bool isIOS() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}
