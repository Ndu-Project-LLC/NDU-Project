// The Scope Tracking Plan page was removed from the product. A page like this
// lives in four places at once, and a removal that misses one of them leaves a
// dead end behind — which is exactly the "unresponsive UI element" that Play
// rejected the app for. So this pins all four:
//
//   1. the route (a deep link that still resolves),
//   2. the page registry the Planning Next/Back labels are read from,
//   3. the sidebar order those labels are actually read out of, and
//   4. the sidebar entry itself — while the sibling that shared its section,
//      Project Controls, stays reachable.

// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';

import '../app_test.dart' show collectRegisteredPaths;

/// The decoration of the sidebar tile that renders [text].
///
/// The coloured "selected" background lives on the `Container` that wraps the
/// tile's row, so the nearest `Container` ancestor of the label is the one
/// carrying the highlight. Same probe `agile_hub_sidebar_test.dart` uses.
BoxDecoration _tileDecoration(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the Scope Tracking Plan page is gone', () {
    test('its route is no longer registered', () {
      final registered = collectRegisteredPaths(AppRouter.main);

      expect(registered, isNot(contains('/scope-tracking-plan')));
      // The neighbours must survive the removal, or this test would pass on a
      // router that had lost the whole Planning section.
      expect(registered, contains('/${AppRoutes.changeManagementModule}'));
      expect(registered, contains('/${AppRoutes.costEstimateScreen}'));
    });

    test('it is out of the page registry', () {
      expect(PlanningPhaseNavigation.getPageIndex('scope_tracking_plan'), -1);
      expect(
        PlanningPhaseNavigation.pages.map((page) => page.id).toSet(),
        isNot(contains('scope_tracking_plan')),
      );
    });

    test('the flow closes over it, so no button walks into it', () {
      // The order was Cost Estimate → Integration Dashboard → Scope Tracking
      // Plan → Change Management, and the button labels are read out of that
      // order rather than written by hand. Removing the page has to splice the
      // flow back together, otherwise Integration Dashboard's Next button
      // promises a screen that no longer exists.
      expect(PlanningPhaseNavigation.nextLabel('integration_dashboard'),
          'Next: Change Management');
      expect(PlanningPhaseNavigation.backLabel('change_management'),
          'Back: Integration Dashboard');
    });

    test('it is out of the sidebar order the labels come from', () {
      expect(
        SidebarNavigationService.instance
            .findItemByCheckpoint('scope_tracking_plan'),
        isNull,
      );
      expect(
        SidebarNavigationService.allItems
            .map((item) => item.checkpoint)
            .toSet(),
        isNot(contains('scope_tracking_plan')),
      );
    });

    testWidgets('the sidebar offers Project Controls directly, with no group',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Naming Project Controls as the active item selects the rail it lives
      // in — the same entry point the deleted page used to provide.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
              body: InitiationLikeSidebar(activeItemLabel: 'Project Controls')),
        ),
      );
      await tester.pumpAndSettle();

      // It is now a top-level Planning item, so it is on screen with nothing
      // to open first. Checked first so a sidebar that failed to build the
      // entry at all cannot make the removal below look verified.
      expect(find.text('Project Controls'), findsOneWidget);
      expect(find.text('Project Services'), findsNothing);
      expect(find.text('Scope Tracking Plan'), findsNothing);
    });

    testWidgets('the Planning Phase header still lights up for Project Controls',
        (tester) async {
      // A tall window so the whole Phase rail is laid out and the header above
      // Project Controls is built rather than scrolled out of the list.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
              body: InitiationLikeSidebar(activeItemLabel: 'Project Controls')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planning Phase'), findsOneWidget);
      // The parent header highlights whenever one of its children is the open
      // page. Project Controls claimed that through the Project Services label
      // set, which the collapse deleted — so this is the assertion that the
      // collapse did not quietly drop the parent highlight with it.
      expect(
        _tileDecoration(tester, 'Planning Phase').color,
        isNot(Colors.transparent),
        reason: 'the Planning Phase header no longer highlights when its '
            'Project Controls child is the open page',
      );
    });
  });
}
