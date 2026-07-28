import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

// Web-only sessionStorage accessor. Stubbed for non-web platforms.
import 'platform_router_web_stub.dart'
    if (dart.library.html) 'platform_router_web.dart' as web_storage;

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
  ///
  /// SPA deep-link recovery: when a user navigates directly to a deep
  /// link (e.g. /pricing, /sign-in) on GitHub Pages, the static host
  /// serves 404.html which captures the requested path into
  /// sessionStorage and redirects to /. Here we read that pending
  /// route and restore it so Flutter's GoRouter navigates to the
  /// intended screen instead of dropping the user on the landing page.
  static String getInitialRoute() {
    if (isNativeApp) {
      return '/splash';
    }
    // Web: check for a pending deep-link route captured by 404.html
    final pending = web_storage.readSessionStorage('__ndu_pending_route');
    if (pending != null && pending.isNotEmpty) {
      // Clear the marker so a refresh on the resolved route doesn't
      // loop back to it after the user has navigated elsewhere.
      web_storage.removeSessionStorage('__ndu_pending_route');
      // Parse the pending path — only accept the pathname portion.
      final uri = Uri.parse(pending);
      final path = uri.path;
      if (path.isNotEmpty && path != '/') {
        // Re-attach any query params the original URL had (e.g. for
        // email-confirm flows that use ?token=...).
        if (uri.query.isNotEmpty) {
          return '$path?${uri.query}';
        }
        return path;
      }
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
