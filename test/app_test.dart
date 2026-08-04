// Router configuration tests for the NDU Project app.
//
// The old test was FlutterFlow starter scaffolding that imported the
// `flutterflow_ai` package (not a dependency of this project), so it could
// never compile. Replaced with tests that guard the go_router deep-link
// migration: every key route must be registered in the live router config,
// and constructing the routers must not throw (e.g. on duplicate paths).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/routing/app_router.dart';

/// Collects every full path registered in a go_router route tree.
///
/// Handles GoRoutes, ShellRoutes and StatefulShellRoutes generically by
/// walking `RouteBase.routes` and normalizing slashes.
Set<String> collectRegisteredPaths(GoRouter router) {
  final paths = <String>{};

  void walk(RouteBase route, String parent) {
    final segment = route is GoRoute ? route.path : null;
    final full = segment == null
        ? parent
        : '$parent/$segment'.replaceAll(RegExp(r'/+'), '/');
    if (segment != null) {
      paths.add(full);
    }
    for (final sub in route.routes) {
      walk(sub, segment == null ? parent : full);
    }
  }

  for (final route in router.configuration.routes) {
    walk(route, '');
  }
  return paths;
}

void main() {
  group('AppRouter', () {
    test('main router constructs without duplicate-path errors', () {
      // GoRouter throws at construction on duplicate sibling paths, so a
      // successful construction guards the route table's integrity.
      expect(AppRouter.main, isNotNull);
      expect(AppRouter.admin, isNotNull);
    });

    test('key deep-link routes are registered in the main router', () {
      final registered = collectRegisteredPaths(AppRouter.main);

      final expected = <String>{
        '/${AppRoutes.dashboard}',
        '/${AppRoutes.programDashboard}',
        '/${AppRoutes.portfolioDashboard}',
        '/${AppRoutes.regularProjectDashboard}',
        '/${AppRoutes.projectCommandCenter}',
        '/${AppRoutes.programDashboardMobile}',
        '/${AppRoutes.signIn}',
        '/${AppRoutes.pricing}',
      };

      final missing = expected.difference(registered);
      expect(missing, isEmpty,
          reason: 'Unregistered deep-link routes: ${missing.toList()..sort()}');
    });

    test('newly added phase routes are registered in the main router', () {
      final registered = collectRegisteredPaths(AppRouter.main);

      final expected = <String>{
        '/${AppRoutes.uiUxDesign}',
        '/${AppRoutes.backendDesign}',
        '/${AppRoutes.specializedDesign}',
        '/${AppRoutes.requirementsImplementation}',
        '/${AppRoutes.technicalDevelopment}',
        '/${AppRoutes.longLeadEquipmentOrdering}',
        '/${AppRoutes.projectBaseline}',
        '/${AppRoutes.scheduleScreen}',
        '/${AppRoutes.agileProjectHub}',
        '/${AppRoutes.adminUsers}',
        '/${AppRoutes.adminContent}',
        '/${AppRoutes.adminHints}',
      };

      final missing = expected.difference(registered);
      expect(missing, isEmpty,
          reason: 'Unregistered routes: ${missing.toList()..sort()}');
    });
  });

  group('runtime route guard', () {
    test('current main + admin configs pass the route-table guard', () {
      expect(routeTableViolation(AppRouter.main.configuration.routes), isNull);
      expect(routeTableViolation(AppRouter.admin.configuration.routes), isNull);
    });

    test('detects duplicate full paths across different parents', () {
      // '/a/shared' is reachable both via the /a tree and as a flat route.
      // go_router only rejects sibling duplicates, so this collision needs
      // the runtime guard to surface it.
      final routes = <RouteBase>[
        GoRoute(
          path: '/a',
          name: 'alpha',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'shared',
              name: 'a-shared',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
        GoRoute(
          path: '/b',
          name: 'beta',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'shared',
              name: 'b-shared',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
        GoRoute(
          path: '/a/shared',
          name: 'flat-a-shared',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ];
      final violation = routeTableViolation(routes);
      expect(violation, isNotNull);
      expect(violation, contains('/a/shared'));
    });

    test('detects duplicate route names', () {
      final routes = <RouteBase>[
        GoRoute(
          path: '/one',
          name: 'dup',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/two',
          name: 'dup',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ];
      final violation = routeTableViolation(routes);
      expect(violation, isNotNull);
      expect(violation, contains('dup'));
    });

    test('accepts a healthy route table', () {
      final routes = <RouteBase>[
        GoRoute(
          path: '/x',
          name: 'x',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'child',
              name: 'x-child',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
        GoRoute(
          path: '/y',
          name: 'y',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ];
      expect(routeTableViolation(routes), isNull);
    });
  });
}
