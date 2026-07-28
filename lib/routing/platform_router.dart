import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Platform detection service for routing decisions.
///
/// CRITICAL: Use platform detection (kIsWeb, Platform.isIOS, Platform.isAndroid)
/// NOT screen size for routing decisions.
class PlatformRouter {
  /// Returns true if running as a native mobile app (iOS or Android)
  static bool get isNativeApp => !kIsWeb;

  /// Returns true if running on web platform (desktop or mobile browser)
  static bool get isWebPlatform => kIsWeb;

  /// Returns true if running as an installed iOS app
  static bool get isIOSApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns true if running as an installed Android app
  static bool get isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Determines the initial route based on platform
  ///
  /// Behavior Matrix:
  /// - Desktop Browser → Landing Page (/)
  /// - Mobile Browser → Landing Page (/)
  /// - iOS App → Splash Screen (/splash)
  /// - Android App → Splash Screen (/splash)
  static String getInitialRoute() {
    if (isNativeApp) {
      return '/splash';
    }
    return '/'; // Landing page for all web
  }

  /// Returns true if the current platform should show the landing page
  static bool shouldShowLandingPage() {
    return isWebPlatform;
  }

  /// Returns true if the current platform should show splash screen
  static bool shouldShowSplashScreen() {
    return isNativeApp;
  }
}
