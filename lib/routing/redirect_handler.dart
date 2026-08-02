/// Pure, testable redirect logic extracted from [AppRouter.main].
///
/// This file contains no Flutter/Firebase dependencies — every external
/// dependency is injected via parameters or callbacks so that unit tests
/// can cover every branch without touching real services.
library;

import 'package:ndu_project/routing/app_router.dart';

/// Encapsulates the result of the redirect decision.
class RedirectResult {
  /// The path to redirect to, or `null` if navigation should proceed.
  final String? redirectTo;

  const RedirectResult(this.redirectTo);

  /// Convenience: `true` when [redirectTo] is non-null (i.e. a redirect
  /// was triggered).
  bool get didRedirect => redirectTo != null;

  @override
  String toString() => 'RedirectResult($redirectTo)';
}

/// All injectable dependencies for the redirect guard.
///
/// By making every external call optional / callback-based, the full
/// redirect logic becomes a pure async function that is trivially
/// testable with no Firebase, Firestore, or platform dependencies.
class RedirectContext {
  /// The currently authenticated Firebase user (null when signed out).
  final String? userId;
  final String? userEmail;

  /// The matched location from [GoRouterState.matchedLocation].
  final String matchedLocation;

  /// Whether the current host is the restricted admin domain.
  final bool isAdminHost;

  /// Whether the user's email is allowed on the admin host
  /// (e.g. ends with @nduproject.com, or is a known admin email).
  final bool isAllowedAdminUser;

  /// Whether the user's email belongs to an admin account.
  final bool isAdminUser;

  /// Async check: does the user have an active subscription?
  final Future<bool> Function() hasActiveSubscription;

  /// Callback used to build the pricing redirect URL.
  final String Function(String reason) pricingUrlBuilder;

  RedirectContext({
    this.userId,
    this.userEmail,
    required this.matchedLocation,
    this.isAdminHost = false,
    this.isAllowedAdminUser = false,
    this.isAdminUser = false,
    required this.hasActiveSubscription,
    String Function(String reason)? pricingUrlBuilder,
  }) : pricingUrlBuilder =
            pricingUrlBuilder ?? ((reason) => '/${AppRoutes.pricing}?reason=$reason');
}

/// Public routes that never require authentication or subscription.
const Set<String> publicRoutes = {
  '/',
  '/${AppRoutes.signIn}',
  '/${AppRoutes.createAccount}',
  '/${AppRoutes.splash}',
  '/${AppRoutes.onboarding}',
  '/${AppRoutes.profileOnboarding}',
  '/${AppRoutes.mobilePricing}',
  '/${AppRoutes.pricing}',
  '/${AppRoutes.privacyPolicy}',
  '/${AppRoutes.termsConditions}',
};

/// Pure async redirect logic — fully testable with no static dependencies.
///
/// Returns a [RedirectResult] indicating whether navigation should be
/// redirected, and to where.
Future<RedirectResult> evaluateRedirect(RedirectContext ctx) async {
  // ── 1. Admin-host guard ──────────────────────────────────────────────
  // On the admin host, only allowed emails may proceed.
  // Mirrors AccessPolicy.isRestrictedAdminHost() + isEmailAllowedForAdmin().
  if (ctx.isAdminHost && !ctx.isAllowedAdminUser) {
    return RedirectResult('/${AppRoutes.signIn}');
  }

  // ── 2. Auth guard ───────────────────────────────────────────────────
  final isPublicRoute = publicRoutes.contains(ctx.matchedLocation);
  if (ctx.userId == null && !isPublicRoute) {
    return RedirectResult('/${AppRoutes.signIn}');
  }

  // ── 3. Authenticated root → dashboard ────────────────────────────────
  if (ctx.userId != null && ctx.matchedLocation == '/') {
    return RedirectResult('/${AppRoutes.dashboard}');
  }

  // ── 4. Subscription guard ────────────────────────────────────────────
  // Only for authenticated users on non-public, non-pricing routes,
  // and only on non-admin hosts for non-admin users.
  if (ctx.userId != null &&
      !isPublicRoute &&
      ctx.matchedLocation != '/${AppRoutes.pricing}' &&
      ctx.matchedLocation != '/${AppRoutes.mobilePricing}') {
    if (!ctx.isAdminHost && !ctx.isAdminUser) {
      final hasSub = await ctx.hasActiveSubscription();
      if (!hasSub) {
        return RedirectResult(ctx.pricingUrlBuilder('no_subscription'));
      }
    }
  }

  // ── 5. No redirect ──────────────────────────────────────────────────
  return RedirectResult(null);
}
