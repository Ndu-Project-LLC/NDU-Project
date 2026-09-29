// The Schedule module's header stack (Section Navigator, context banner, WBS
// Packages card, Cross-Section Sync card) and its tab content must scroll as
// ONE continuous page.
//
// They used to be two competing scroll surfaces: the header was capped at half
// the viewport and scrolled inside that cap (clipping its own cards behind a
// "Scroll for more" pill) while the tab content scrolled below it. The header
// now renders as ordinary slivers of the page's NestedScrollView and scrolls
// away with the content; a slim pinned bar keeps the module label + active tab
// available and returns the user to the header.
//
// Driven as the user meets it: the real ScheduleModuleScreen with the real
// providers. No Firebase, no network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// A schedule with a populated root, so the module screen's auto-sync on entry
/// (which only fires for an empty tree) stays out of the way.
ScheduleProvider newScheduleProvider() {
  final provider = ScheduleProvider();
  provider.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');
  provider.setActivities([
    ScheduleActivity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'Lusaka',
      type: ActivityType.summary,
      domain: ScheduleDomain.engineering,
      dependencies: const [],
      aiGenerated: false,
      children: [
        ScheduleActivity(
          id: 'a1',
          level: 1,
          code: '1',
          name: 'Mobilise',
          type: ActivityType.task,
          domain: ScheduleDomain.engineering,
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 4, 30),
          dependencies: const [],
          aiGenerated: false,
          children: const [],
        ),
      ],
    ),
  ]);
  return provider;
}

/// The page scroll's outer position — the first scrollable under the keyed
/// [NestedScrollView].
ScrollableState pageScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(const ValueKey('scheduleHeaderScroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

Future<void> pumpModule(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final schedule = newScheduleProvider();
  // The provider's constructor reads storage asynchronously; let that settle
  // outside the fake-async zone the test body runs in.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  schedule.setup(projectName: 'Lusaka', deliveryModel: 'WATERFALL');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: schedule),
        ChangeNotifierProvider<WBSProvider>(create: (_) => WBSProvider()),
        ChangeNotifierProvider<CostEstimateProvider>(
            create: (_) => CostEstimateProvider()),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => ProjectDataProvider()),
        ChangeNotifierProvider<ProjectControlsProvider>(
            create: (_) => ProjectControlsProvider()),
      ],
      child: const MaterialApp(home: ScheduleModuleScreen()),
    ),
  );
  // Bounded pumps rather than `pumpAndSettle`: the module's tab screens host
  // perpetual animations (loading spinners) that `pumpAndSettle` would wait
  // on forever.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the header stack and tab content scroll as one page',
      (tester) async {
    await pumpModule(tester, size: const Size(1400, 800));

    // The whole header stack is laid out — nothing clipped behind a cap.
    expect(find.text('Schedule Navigation'), findsOneWidget);
    expect(find.text('WBS Packages'), findsOneWidget);
    expect(find.text('Search WBS packages by code or name'), findsOneWidget);

    // One vertical scroll experience: no capped inner viewport chrome.
    expect(find.text('Scroll for more'), findsNothing);
    expect(find.text('Show header'), findsNothing);

    // Dragging on the header content scrolls the page…
    await tester.drag(find.text('Schedule Navigation'), const Offset(0, -140));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(pageScrollable(tester).position.pixels, greaterThan(0));

    // …and the tab content still renders below the stack.
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a long drag on the tab body hands off to the page scroll and the pinned bar restores the header',
      (tester) async {
    await pumpModule(tester, size: const Size(1400, 800));

    // A long drag starting on the tab content exhausts the body's extent and
    // hands off to the page scroll, scrolling the header stack away.
    await tester.drag(find.byType(TabBarView), const Offset(0, -4000));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final position = pageScrollable(tester).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('Schedule Navigation'), findsNothing);

    // The pinned bar keeps the module + active tab available however deep the
    // user is (the Builder tab paints its own 'Schedule' heading too, so
    // scope to the pinned bar's SliverAppBar).
    expect(
      find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.text('Schedule'),
      ),
      findsOneWidget,
    );
    expect(find.text('Builder'), findsOneWidget);

    // …and tapping it brings the header stack back.
    await tester.tap(find.byTooltip('Back to top'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(pageScrollable(tester).position.pixels, 0);
    expect(find.text('Schedule Navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole header stack is visible at rest on a tall window',
      (tester) async {
    await pumpModule(tester, size: const Size(1400, 1600));

    // The stack renders uncapped and fully laid out — nothing clipped behind
    // a cap or hidden behind a hint pill. The page still scrolls (the header
    // stack scrolls away with the content by design), but at rest the user
    // sees the whole stack plus the tab content below it.
    expect(find.text('Schedule Navigation'), findsOneWidget);
    expect(find.text('WBS Packages'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
