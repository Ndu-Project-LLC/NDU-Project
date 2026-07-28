import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';

/// Tracks the last visited dashboard context for both client and admin
/// surfaces, so clicking the brand logo can take the user to the most
/// relevant dashboard without hard-coding per-screen logic.
class NavigationContextService {
  NavigationContextService._();
  static final NavigationContextService instance = NavigationContextService._();

  String? _lastClientDashboardRouteName; // project/program/portfolio
  String? _lastAdminDashboardRouteName; // admin-* routes

  void setLastClientDashboard(String routeName) {
    _lastClientDashboardRouteName = routeName;
    if (kDebugMode) {
      debugPrint(
          'NavigationContextService: last client dashboard -> $routeName');
    }
  }

  void setLastAdminDashboard(String routeName) {
    _lastAdminDashboardRouteName = routeName;
    if (kDebugMode) {
      debugPrint(
          'NavigationContextService: last admin dashboard -> $routeName');
    }
  }

  /// Navigates to the dashboard when the logo is tapped.
  /// Provides consistent behavior across all screens.
  void navigateFromLogo(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.maybeOf(context);
    try {
      if (kDebugMode) {
        debugPrint('Logo tap -> navigating to dashboard');
      }
      // Prefer the most recent dashboard context when known; fallback to the
      // default dashboard route.
      final rawTarget =
          (_lastClientDashboardRouteName?.trim().isNotEmpty ?? false)
              ? _lastClientDashboardRouteName!.trim()
              : (_lastAdminDashboardRouteName?.trim().isNotEmpty ?? false)
                  ? _lastAdminDashboardRouteName!.trim()
                  : '/dashboard';
      final target = rawTarget.startsWith('/') ? rawTarget : '/$rawTarget';

      // Some screens are opened with Navigator.push(MaterialPageRoute). In that
      // case, using go() alone can update router state while the pushed route
      // remains visible. Pop to the root route first, then route via go_router.
      if (rootNavigator.canPop()) {
        rootNavigator.popUntil((route) => route.isFirst);
      }

      if (router != null) {
        router.go(target);
        return;
      }
    } catch (e, st) {
      debugPrint('NavigationContextService.navigateFromLogo error: $e\n$st');
    }

    // Fallback when GoRouter is not available in the current context.
    if (rootNavigator.mounted) {
      rootNavigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProjectDashboardScreen()),
        (route) => false,
      );
    }
  }
}
