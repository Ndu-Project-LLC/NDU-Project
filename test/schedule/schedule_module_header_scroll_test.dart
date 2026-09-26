// The Schedule module's section-header stack (Section Navigator, context
// banner, WBS Packages card, Cross-Section Sync card) must be scrollable.
//
// It used to be pinned above the tab content, so on a short window — or once
// the WBS Packages / Cross-Section Sync cards were expanded — it squeezed the
// tab content rather than getting out of the way. It is now capped at half the
// viewport, scrolls inside that cap, hints that there is more to scroll, and
// collapses into a slim bar once the user scrolls it partway.
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

/// The header stack's own scroll view — the outermost vertical scrollable
/// inside the keyed [SingleChildScrollView].
ScrollableState headerScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(const ValueKey('scheduleHeaderScroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

double hintOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('sectionHeaderScrollHint')))
    .opacity;

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
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the header stack scrolls, then collapses out of the way',
      (tester) async {
    await pumpModule(tester, size: const Size(1400, 480));

    // The header is taller than its cap at this height…
    final header = headerScrollable(tester);
    expect(header.position.maxScrollExtent, greaterThan(56),
        reason: 'the header stack should scroll instead of squeezing '
            'the tab content');
    // …so the stack hints that there is more below…
    expect(hintOpacity(tester), 1);

    // …the tab content is still laid out below it…
    expect(find.byType(TabBarView), findsOneWidget);
    expect(find.text('Schedule Navigation'), findsOneWidget);

    // …and scrolling the stack partway collapses it into the slim bar,
    // handing the freed height to the tab content.
    await tester.drag(find.text('Schedule Navigation'), const Offset(0, -140));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Show header'), findsOneWidget);
    expect(find.text('Schedule Navigation'), findsNothing);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The bar brings the module header back.
    await tester.tap(find.text('Show header'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule Navigation'), findsOneWidget);
    expect(headerScrollable(tester).position.pixels, 0);
  });

  testWidgets('the header stack stays at its natural height when it fits',
      (tester) async {
    await pumpModule(tester, size: const Size(1400, 1400));

    // Nothing to scroll: the tall window shows the whole stack and leaves the
    // rest of the page to the tab content.
    expect(headerScrollable(tester).position.maxScrollExtent, 0);
    expect(hintOpacity(tester), 0);
    expect(find.text('Schedule Navigation'), findsOneWidget);
    expect(find.text('WBS Packages'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
