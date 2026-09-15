// End-to-end widget test for the Schedule module's "WBS Packages" card.
//
// The owner's note (2026-09-10) was blunt: "this card is supposed to show the
// WBS packages" — and, on the same walkthrough, that everything on the WBS
// should be able to find itself on the schedule, take its start/finish, and
// carry a cost item that then shows up in the Cost Estimate and the WBS cost
// views.
//
// Driven exactly as the user meets it: the real card, the real WBSProvider and
// ScheduleProvider, real data built through the providers' own public APIs. No
// Firebase, no network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/widgets/schedule_wbs_packages_card.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// A WBS provider with storage loaded, so `setup()` is no longer gated.
///
/// The storage read is a real async platform call, so it has to be awaited
/// outside the fake-async zone a `testWidgets` body runs in — otherwise the
/// loop never sees the timer fire and the test hangs.
Future<WBSProvider> newWbsProvider(WidgetTester tester) async {
  final provider = WBSProvider();
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && provider.isLoadingFromStorage; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  provider.setup(
    projectName: 'Lusaka',
    framework: WBSFramework.waterfallDeliverable,
  );
  return provider;
}

ScheduleProvider newScheduleProvider({List<ScheduleActivity>? children}) {
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
      children: children ?? const [],
    ),
  ]);
  return provider;
}

Future<void> pumpCard(
  WidgetTester tester, {
  required WBSProvider wbs,
  required ScheduleProvider schedule,
}) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WBSProvider>.value(value: wbs),
        ChangeNotifierProvider<ScheduleProvider>.value(value: schedule),
        ChangeNotifierProvider<CostEstimateProvider>(
            create: (_) => CostEstimateProvider()),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => ProjectDataProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ScheduleWbsPackagesCard()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists the WBS packages, showing which are scheduled',
      (tester) async {
    final wbs = await newWbsProvider(tester);
    final engineering = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

    final schedule = newScheduleProvider(children: [
      ScheduleActivity(
        id: 'a1',
        level: 1,
        code: '1',
        name: 'Engineering',
        type: ActivityType.task,
        domain: ScheduleDomain.engineering,
        wbsNodeId: engineering,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 30),
        dependencies: const [],
        aiGenerated: false,
        children: const [],
      ),
    ]);

    await pumpCard(tester, wbs: wbs, schedule: schedule);

    // Both packages are on the card, by code and by name.
    expect(find.textContaining('Engineering'), findsWidgets);
    expect(find.textContaining('Procurement'), findsWidgets);
    // One is scheduled, one is not — and the card says so.
    expect(find.text('On schedule'), findsOneWidget);
    expect(find.text('Not scheduled'), findsOneWidget);
    expect(find.text('Add 1 to schedule'), findsOneWidget);
    expect(find.textContaining('not scheduled yet'), findsOneWidget);
  });

  testWidgets('brings a missing WBS package onto the schedule in one tap',
      (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    final schedule = newScheduleProvider();

    await pumpCard(tester, wbs: wbs, schedule: schedule);
    expect(find.text('Add 1 to schedule'), findsOneWidget);

    await tester.ensureVisible(find.text('Add 1 to schedule'));
    await tester.tap(find.text('Add 1 to schedule'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The package is on the schedule, linked back to its WBS node.
    final added = schedule.schedule!.activities.first.children.single;
    expect(added.wbsNodeId, isNotEmpty);
    expect(added.name, contains('Engineering'));

    // And the card now reports full coverage.
    expect(find.text('Fully scheduled'), findsOneWidget);
    expect(
      find.text('Every WBS package is on the schedule'),
      findsOneWidget,
    );
    expect(find.textContaining('are not on the schedule yet'), findsNothing);
  });

  testWidgets('points at the WBS module when there is no breakdown yet',
      (tester) async {
    final wbs = await newWbsProvider(tester);
    final schedule = newScheduleProvider();

    await pumpCard(tester, wbs: wbs, schedule: schedule);

    expect(
      find.textContaining('No WBS work packages yet'),
      findsOneWidget,
    );
  });

  testWidgets('filters the package list by code or name', (tester) async {
    final wbs = await newWbsProvider(tester);
    wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');
    final schedule = newScheduleProvider();

    await pumpCard(tester, wbs: wbs, schedule: schedule);

    await tester.enterText(find.byType(TextField).first, 'procure');
    await tester.pump();

    expect(find.textContaining('Procurement'), findsWidgets);
    expect(find.textContaining('Engineering'), findsNothing);
  });

  testWidgets('offers the WBS → schedule date fill only when it would help',
      (tester) async {
    final wbs = await newWbsProvider(tester);
    final node = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
    // The package carries a planned window, its schedule row does not. Written
    // through the same API the WBS timeline sync uses.
    expect(
      wbs.applyScheduleTimelines({
        node: (start: DateTime(2026, 1, 5), finish: DateTime(2026, 1, 30)),
      }),
      1,
    );

    final schedule = newScheduleProvider(children: [
      ScheduleActivity(
        id: 'a1',
        level: 1,
        code: '1',
        name: 'Engineering',
        type: ActivityType.task,
        domain: ScheduleDomain.engineering,
        wbsNodeId: node,
        dependencies: const [],
        aiGenerated: false,
        children: const [],
      ),
    ]);

    await pumpCard(tester, wbs: wbs, schedule: schedule);

    final button = tester.widget<OutlinedButton>(
      find
          .ancestor(
            of: find.text('Fill schedule dates from WBS'),
            matching: find.byType(OutlinedButton),
          )
          .first,
    );
    expect(button.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Fill schedule dates from WBS'));
    await tester.tap(find.text('Fill schedule dates from WBS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final activity = schedule.schedule!.activities.first.children.single;
    expect(activity.startDate, DateTime(2026, 1, 5));
    expect(activity.endDate, DateTime(2026, 1, 30));
  });
}
