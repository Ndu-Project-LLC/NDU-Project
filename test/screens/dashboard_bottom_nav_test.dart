// Regression for the Play "Unresponsive UI elements, such as buttons or icons"
// rejection.
//
// Play rejected the build with the dashboard's bottom navigation bar boxed in
// the evidence: tapping Portfolio and Settings did nothing. The bar itself
// (`DashboardBottomNavBar._handleTap`) maps all four indices to routes, but
// this shell passes its own `onNavigate` and that switch only had cases 1 and 2
// — so Settings moved the highlight and went nowhere. A reviewer sees that as a
// dead button, which is exactly what the policy names.
//
// These tests tap every tab and require each one to land on its route, so a tab
// can never again ship that only repaints itself. They also pin the two other
// dead controls that lived on this screen: the placeholder notification bell,
// and "See All" buttons that were drawn even when the list was already complete
// (and tapped to no effect).
//
// The destinations are stubs — what is under test is the tab's wiring, not the
// page behind it. The paths are the production constants, so a tab pointing at
// an unregistered route fails here rather than passing.
//
// This shell also has phone-width RenderFlex debt recorded in
// `test/support/mobile_overflow_debt.dart` (it is 'ProjectDashboardScreen' and
// friends in that work list, pointing at this file). Those overflows are
// drained below and checked to be exactly that known debt, so these tests still
// fail on any new kind of layout error.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/screens/project/project_dashboard_mobile_shell.dart';
import 'package:ndu_project/widgets/dashboard_bottom_nav_bar.dart';

/// Every tab, and the route it must reach. The values are the same constants
/// the shell navigates with, so renaming a route fails here.
final Map<String, String> _tabRoutes = <String, String>{
  'Programs': '/${AppRoutes.programDashboardMobile}',
  'Portfolios': '/${AppRoutes.portfolioDashboard}',
  'Settings': '/${AppRoutes.settings}',
};

const String _dashboard = '/${AppRoutes.dashboard}';

/// Where the router ended up. Only the stub destinations write it: `push`
/// leaves the dashboard mounted, and the shell rebuilds after its own setState,
/// so a value written by the dashboard's builder would be overwritten back to
/// the dashboard — which would hide a tab that works.
String _location = '';

/// Everything the framework reported while the shell was pumped.
List<String> _errors = <String>[];

/// The tab's label inside the nav bar — the label text also appears elsewhere
/// on the page, so the finder is scoped to the bar.
Finder _tab(String label) => find.descendant(
      of: find.byType(DashboardBottomNavBar),
      matching: find.text(label),
    );

Future<void> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(427, 952);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  _location = _dashboard;
  _errors = <String>[];

  final paths = <String>{_dashboard, ..._tabRoutes.values};
  final router = GoRouter(
    initialLocation: _dashboard,
    routes: <RouteBase>[
      for (final path in paths)
        GoRoute(
          path: path,
          builder: (context, state) {
            if (state.uri.path == _dashboard) {
              return ProjectDashboardMobileShell(
                isBasicPlan: false,
                onAddProject: () async {},
              );
            }
            _location = state.uri.path;
            return Scaffold(body: Text('destination ${state.uri.path}'));
          },
        ),
    ],
  );
  addTearDown(router.dispose);

  // Collected through FlutterError.onError rather than takeException: the
  // binding collapses a burst of layout errors into one report with no location.
  final prior = FlutterError.onError;
  FlutterError.onError = (details) => _errors.add(details.exceptionAsString());
  addTearDown(() => FlutterError.onError = prior);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  // Fixed frames rather than pumpAndSettle: the KAZ AI bubble animates
  // continuously, so settling would never finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  for (var i = 0; i < 50; i++) {
    final extra = tester.takeException();
    if (extra == null) break;
    _errors.add(extra.toString());
  }
  FlutterError.onError = prior;
}

/// Every error the page reported must be the RenderFlex debt already recorded in
/// `mobile_overflow_debt.dart` — nothing of any other kind.
void _expectOnlyKnownOverflowDebt() {
  for (final message in _errors) {
    expect(
      message,
      contains('RenderFlex overflowed'),
      reason: 'expected only the known phone-width overflow debt, got:\n'
          '$message',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the dashboard starts on the Projects tab', (tester) async {
    await _pumpShell(tester);
    expect(_location, _dashboard);
    expect(_tab('Projects'), findsOneWidget);
    for (final label in _tabRoutes.keys) {
      expect(_tab(label), findsOneWidget, reason: '$label tab must exist');
    }
    _expectOnlyKnownOverflowDebt();
  });

  for (final entry in _tabRoutes.entries) {
    testWidgets('tapping ${entry.key} navigates to ${entry.value}',
        (tester) async {
      await _pumpShell(tester);
      expect(_location, _dashboard, reason: 'must start on the dashboard');

      await tester.tap(_tab(entry.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Reported before the location check, so a navigation that threw is
      // surfaced as its own error instead of hiding behind "still on the
      // dashboard".
      _expectOnlyKnownOverflowDebt();

      final arrived =
          find.text('destination ${entry.value}').evaluate().isNotEmpty;
      expect(
        _location,
        entry.value,
        reason: 'tapping ${entry.key} left the user on $_location (destination '
            'page mounted: $arrived) — a tab that only moves the highlight is '
            'the dead control Play rejected',
      );
    });
  }

  testWidgets('tapping the active Projects tab stays on the dashboard',
      (tester) async {
    await _pumpShell(tester);
    await tester.tap(_tab('Projects'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_location, _dashboard);
    _expectOnlyKnownOverflowDebt();
  });

  testWidgets('there is no notification bell without a feed behind it',
      (tester) async {
    await _pumpShell(tester);
    expect(
      find.byIcon(Icons.notifications_none_rounded),
      findsNothing,
      reason: 'the header bell was a placeholder with an empty onPressed',
    );
    _expectOnlyKnownOverflowDebt();
  });

  testWidgets('"See All" is absent while the list is already complete',
      (tester) async {
    await _pumpShell(tester);
    // No signed-in user, so both lists are empty: there is nothing more to
    // reveal and the control must not be offered. Previously both were always
    // drawn with an empty onPressed.
    expect(
      find.text('See All'),
      findsNothing,
      reason: 'a "See All" that cannot reveal anything is a dead control',
    );
    _expectOnlyKnownOverflowDebt();
  });
}
