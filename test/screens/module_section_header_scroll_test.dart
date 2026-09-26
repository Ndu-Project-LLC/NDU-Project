// The Schedule module's scrollable section-header stack is shared with the
// Cost Estimate, WBS and Project Controls modules. This is the wiring smoke
// test: each of those screens must host its header in
// [ScrollableSectionHeader] (which caps it, scrolls it, hints when there is
// more below, and collapses it to a slim bar), while the tab content keeps
// rendering below.
//
// The behaviour of the host itself is covered by
// test/widgets/scrollable_section_header_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/screens/project_controls_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';

/// A Cost Estimate bound to the (empty project id → `'default'`) scope the
/// screens compute from the project data, so nothing re-scopes mid-test.
///
/// Built synchronously: the provider's bootstrap storage read is empty under
/// `SharedPreferences.setMockInitialValues`, and awaiting a real timer inside a
/// `testWidgets` body would deadlock on the fake clock.
CostEstimateProvider readyCostEstimate() {
  final provider = CostEstimateProvider();
  provider.setup(
    projectId: 'default',
    projectName: 'Lusaka',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
  );
  return provider;
}

/// A WBS provider with storage loaded, so the WBS screen's auto-setup is a
/// no-op. The read is a real async platform call, so it has to be awaited
/// outside the fake-async zone a `testWidgets` body runs in.
Future<WBSProvider> readyWbs(WidgetTester tester) async {
  final provider = WBSProvider();
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && provider.isLoadingFromStorage; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  provider.setup(
    projectName: 'Lusaka',
    framework: WBSFramework.waterfallDeliverable,
    projectId: 'default',
  );
  return provider;
}

Future<ScheduleProvider> readySchedule(WidgetTester tester) async {
  final provider = ScheduleProvider();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  provider.setup(
    projectId: 'default',
    projectName: 'Lusaka',
    deliveryModel: 'WATERFALL',
  );
  return provider;
}

Future<void> pumpModule(
  WidgetTester tester, {
  required Widget screen,
  required CostEstimateProvider costEstimate,
  required WBSProvider wbs,
  required ScheduleProvider schedule,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CostEstimateProvider>.value(value: costEstimate),
        ChangeNotifierProvider<WBSProvider>.value(value: wbs),
        ChangeNotifierProvider<ScheduleProvider>.value(value: schedule),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => ProjectDataProvider()),
        ChangeNotifierProvider<ProjectControlsProvider>(
            create: (_) => ProjectControlsProvider()),
        ChangeNotifierProvider<ChangeManagementProvider>(
            create: (_) => ChangeManagementProvider()),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  // Bounded pumps rather than `pumpAndSettle`: these module screens host
  // perpetual animations (loading spinners, shimmer skeletons) that
  // `pumpAndSettle` would wait on forever.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the WBS module hosts its header in the shared scroll host',
      (tester) async {
    final wbs = await readyWbs(tester);
    final wbsCount = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

    await pumpModule(
      tester,
      screen: const WBSModuleScreen(),
      costEstimate: readyCostEstimate(),
      wbs: wbs,
      schedule: await readySchedule(tester),
    );

    expect(wbsCount, isNotEmpty);
    expect(find.byKey(const ValueKey('wbsHeaderScroll')), findsOneWidget);
    expect(find.text('WBS Navigation'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the Cost Estimate module hosts its header in the shared scroll host',
      (tester) async {
    await pumpModule(
      tester,
      screen: const CostEstimateModuleScreen(),
      costEstimate: readyCostEstimate(),
      wbs: await readyWbs(tester),
      schedule: await readySchedule(tester),
    );

    expect(
        find.byKey(const ValueKey('costEstimateHeaderScroll')), findsOneWidget);
    expect(find.text('Cost Estimate Navigation'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the Project Controls module hosts its header in the shared scroll host',
      (tester) async {
    await pumpModule(
      tester,
      screen: const ProjectControlsScreen(),
      costEstimate: readyCostEstimate(),
      wbs: await readyWbs(tester),
      schedule: await readySchedule(tester),
    );

    expect(find.byKey(const ValueKey('projectControlsHeaderScroll')),
        findsOneWidget);
    expect(find.text('Project Controls Navigation'), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
