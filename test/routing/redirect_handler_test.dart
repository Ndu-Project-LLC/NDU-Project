import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/routing/redirect_handler.dart';

/// Helper to build a [RedirectContext] with sensible defaults.
RedirectContext _ctx({
  String? userId = 'user-1',
  String? userEmail = 'alice@example.com',
  String location = '/dashboard',
  bool isAdminHost = false,
  bool isAllowedAdminUser = false,
  bool isAdminUser = false,
  Future<bool> Function()? hasSub,
}) {
  return RedirectContext(
    userId: userId,
    userEmail: userEmail,
    matchedLocation: location,
    isAdminHost: isAdminHost,
    isAllowedAdminUser: isAllowedAdminUser,
    isAdminUser: isAdminUser,
    hasActiveSubscription: hasSub ?? () async => true,
  );
}

void main() {
  // ────────────────────────────────────────────────────────────────────
  // 1. Admin-host guard
  // ────────────────────────────────────────────────────────────────────
  group('Admin-host guard', () {
    test('redirects unauthenticated user on admin host to sign-in', () async {
      final result = await evaluateRedirect(_ctx(
        userId: null,
        userEmail: null,
        location: '/dashboard',
        isAdminHost: true,
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/${AppRoutes.signIn}');
    });

    test('redirects non-allowed email on admin host to sign-in', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        userEmail: 'bob@gmail.com',
        location: '/dashboard',
        isAdminHost: true,
        isAllowedAdminUser: false,
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/${AppRoutes.signIn}');
    });

    test('allows allowed email on admin host to proceed', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        userEmail: 'alice@nduproject.com',
        location: '/admin-home',
        isAdminHost: true,
        isAllowedAdminUser: true,
        isAdminUser: true,
      ));
      expect(result.didRedirect, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 2. Auth guard
  // ────────────────────────────────────────────────────────────────────
  group('Auth guard', () {
    test('redirects unauthenticated user on protected route to sign-in', () async {
      final result = await evaluateRedirect(_ctx(
        userId: null,
        userEmail: null,
        location: '/dashboard',
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/${AppRoutes.signIn}');
    });

    test('allows unauthenticated user on public routes', () async {
      for (final route in [
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
      ]) {
        final result = await evaluateRedirect(_ctx(
          userId: null,
          userEmail: null,
          location: route,
        ));
        expect(result.didRedirect, isFalse,
            reason: 'Public route $route should not redirect');
      }
    });

    test('redirects unauthenticated user on /front-end-planning to sign-in', () async {
      final result = await evaluateRedirect(_ctx(
        userId: null,
        location: '/front-end-planning',
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/${AppRoutes.signIn}');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 3. Root → dashboard redirect
  // ────────────────────────────────────────────────────────────────────
  group('Authenticated root redirect', () {
    test('redirects authenticated user on "/" to dashboard', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/',
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/${AppRoutes.dashboard}');
    });

    test('does NOT redirect authenticated user on non-root route', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/settings',
      ));
      // May redirect due to subscription guard, but NOT to dashboard
      expect(result.redirectTo, isNot('/${AppRoutes.dashboard}'));
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 4. Subscription guard
  // ────────────────────────────────────────────────────────────────────
  group('Subscription guard', () {
    test('redirects to pricing when user has no active subscription', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/dashboard',
        hasSub: () async => false,
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, contains('/${AppRoutes.pricing}'));
      expect(result.redirectTo, contains('reason=no_subscription'));
    });

    test('allows user with active subscription on protected route', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/dashboard',
        hasSub: () async => true,
      ));
      expect(result.didRedirect, isFalse);
    });

    test('skips subscription check for admin host', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/dashboard',
        isAdminHost: true,
        isAllowedAdminUser: true,
        hasSub: () async => false, // would redirect if checked
      ));
      expect(result.didRedirect, isFalse);
    });

    test('skips subscription check for admin users', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        userEmail: 'chungu424@gmail.com',
        location: '/dashboard',
        isAdminUser: true,
        hasSub: () async => false, // would redirect if checked
      ));
      expect(result.didRedirect, isFalse);
    });

    test('skips subscription check on pricing route', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/${AppRoutes.pricing}',
        hasSub: () async => false,
      ));
      expect(result.didRedirect, isFalse);
    });

    test('skips subscription check on mobile-pricing route', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/${AppRoutes.mobilePricing}',
        hasSub: () async => false,
      ));
      expect(result.didRedirect, isFalse);
    });

    test('redirects to pricing with custom URL builder', () async {
      final result = await evaluateRedirect(RedirectContext(
        userId: 'u1',
        userEmail: 'user@test.com',
        matchedLocation: '/cost-estimate',
        hasActiveSubscription: () async => false,
        pricingUrlBuilder: (reason) => '/custom-pricing?why=$reason',
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, '/custom-pricing?why=no_subscription');
    });

    test('does not call hasActiveSubscription when already on pricing', () async {
      var callCount = 0;
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/${AppRoutes.pricing}',
        hasSub: () async {
          callCount++;
          return false;
        },
      ));
      expect(callCount, 0);
      expect(result.didRedirect, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 5. Edge cases
  // ────────────────────────────────────────────────────────────────────
  group('Edge cases', () {
    test('null user with "/" root is public route — no redirect', () async {
      final result = await evaluateRedirect(_ctx(
        userId: null,
        location: '/',
      ));
      expect(result.didRedirect, isFalse);
    });

    test('protected route on non-admin host with no sub redirects', () async {
      final result = await evaluateRedirect(_ctx(
        userId: 'u1',
        location: '/wbs',
        isAdminHost: false,
        hasSub: () async => false,
      ));
      expect(result.didRedirect, isTrue);
      expect(result.redirectTo, contains('/${AppRoutes.pricing}'));
    });

    test('subscription guard runs on many protected routes', () async {
      final protectedRoutes = [
        '/dashboard', '/settings', '/wbs', '/pbs',
        '/schedule', '/team-management', '/cost-estimate',
        '/front-end-planning', '/risk-assessment',
      ];
      for (final route in protectedRoutes) {
        final result = await evaluateRedirect(_ctx(
          userId: 'u1',
          location: route,
          hasSub: () async => false,
        ));
        expect(result.didRedirect, isTrue,
            reason: 'Protected route $route should redirect when no subscription');
      }
    });

    test('pricing URL builder receives correct reason', () async {
      final result = await evaluateRedirect(RedirectContext(
        userId: 'u1',
        matchedLocation: '/dashboard',
        hasActiveSubscription: () async => false,
      ));
      expect(result.redirectTo, '/${AppRoutes.pricing}?reason=no_subscription');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 6. Public routes completeness
  // ────────────────────────────────────────────────────────────────────
  group('Public routes set', () {
    test('contains all expected public routes', () {
      expect(publicRoutes, containsAll([
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
      ]));
    });

    test('does not contain protected routes', () {
      expect(publicRoutes, isNot(contains('/dashboard')));
      expect(publicRoutes, isNot(contains('/settings')));
      expect(publicRoutes, isNot(contains('/wbs')));
    });
  });
}
