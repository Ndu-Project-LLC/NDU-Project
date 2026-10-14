// Visual capture of the Schedule Builder's new surfaces, for design review.
//
// These are not pixel-compare regression goldens in spirit — they exist so the
// action row, the CPM result sheet, the export sheet and the methodology import
// dialog can be looked at without launching the app. Everything rendered here is
// the production widget driven through the production providers: the Run CPM
// sheet, for instance, is reached by tapping the real button, so the screenshot
// cannot drift from what a user actually sees.
//
// Regenerate after an intentional UI change:
//   flutter test test/schedule/schedule_builder_screenshots_test.dart \
//     --update-goldens

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

ScheduleActivity activity(
  String id,
  String name, {
  int level = 2,
  ActivityType type = ActivityType.task,
  double? duration,
  DateTime? start,
  DateTime? end,
  String? owner,
  String? wbsNodeId,
  String? workPackageId,
  List<ActivityDependency> dependencies = const [],
  List<ScheduleActivity> children = const [],
}) {
  return ScheduleActivity(
    id: id,
    level: level,
    code: '',
    name: name,
    type: type,
    domain: ScheduleDomain.engineering,
    duration: duration,
    durationUnit: 'day',
    startDate: start,
    endDate: end,
    owner: owner,
    wbsNodeId: wbsNodeId,
    workPackageId: workPackageId,
    dependencies: dependencies,
    aiGenerated: false,
    children: children,
  );
}

ScheduleProvider scheduleWith(List<ScheduleActivity> children) {
  final provider = ScheduleProvider();
  provider.setup(
      projectName: 'Lusaka 28', deliveryModel: 'HYBRID', projectId: 'p1');
  provider.setActivities([
    provider.schedule!.activities.first.copyWith(
      startDate: DateTime(2026, 1, 6),
      endDate: DateTime(2026, 6, 30),
      children: children,
    ),
  ]);
  return provider;
}

Future<void> pumpBuilder(
  WidgetTester tester,
  ScheduleProvider schedule,
) async {
  tester.view.physicalSize = const Size(1440, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ChangeNotifierProvider<ProjectDataProvider>.value(
    value: ProjectDataProvider(),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: schedule),
        ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
        ChangeNotifierProvider<CostEstimateProvider>.value(
            value: CostEstimateProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: BuilderScreen()),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  // These are the repository's first goldens. Rasterisation and font metrics
  // differ per platform, so a pixel comparison run on CI would fail on the
  // image, not on the code. They are a review tool: run them locally with
  // `flutter test --update-goldens` after an intentional UI change.
  final isCi = Platform.environment['CI'] == 'true' ||
      Platform.environment['GITHUB_ACTIONS'] == 'true';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A plan with real content on every row so the table is not a stub.
  final populated = [
    activity('a1', 'Detailed Design',
        duration: 12,
        start: DateTime(2026, 1, 6),
        end: DateTime(2026, 1, 17),
        owner: 'M. Chanda',
        workPackageId: 'wp1'),
    activity('a2', 'Switchgear Procurement',
        duration: 45,
        start: DateTime(2026, 1, 19),
        end: DateTime(2026, 3, 4),
        owner: 'Procurement',
        workPackageId: 'wp2',
        dependencies: const [
          ActivityDependency(
              activityId: 'a1', type: DependencyType.finishToStart),
        ]),
    activity('a3', 'Substation Civil Works',
        duration: 30,
        start: DateTime(2026, 3, 9),
        end: DateTime(2026, 4, 7),
        owner: 'K. Banda',
        workPackageId: 'wp3',
        dependencies: const [
          ActivityDependency(
              activityId: 'a2', type: DependencyType.finishToStart),
        ]),
    activity('a4', 'Protection Panel Installation',
        duration: 18,
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 27),
        owner: 'K. Banda',
        workPackageId: 'wp4',
        dependencies: const [
          ActivityDependency(
              activityId: 'a3', type: DependencyType.finishToStart),
        ]),
    activity('a5', 'Pre-Commissioning Tests',
        duration: 15,
        start: DateTime(2026, 4, 30),
        end: DateTime(2026, 5, 14),
        owner: 'A. Phiri',
        workPackageId: 'wp5',
        dependencies: const [
          ActivityDependency(
              activityId: 'a4', type: DependencyType.finishToStart),
        ]),
  ];

  testWidgets('01 the action row', (tester) async {
    if (isCi) return;
    await pumpBuilder(tester, scheduleWith(populated));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_builder_action_row.png'),
    );
  });

  testWidgets('02 CPM result sheet with dependency issues', (tester) async {
    if (isCi) return;
    // A cycle, a link to an activity that no longer exists, and a row with no
    // duration — the three things the sheet now surfaces instead of swallowing.
    await pumpBuilder(
      tester,
      scheduleWith([
        activity('a1', 'Detailed Design',
            duration: 12,
            start: DateTime(2026, 1, 6),
            end: DateTime(2026, 1, 17)),
        activity('a2', 'Switchgear Procurement',
            start: DateTime(2026, 1, 19),
            end: DateTime(2026, 3, 4),
            dependencies: const [
              ActivityDependency(
                  activityId: 'a1', type: DependencyType.finishToStart),
            ]),
        activity('a3', 'Substation Civil Works',
            duration: 30,
            start: DateTime(2026, 3, 9),
            end: DateTime(2026, 4, 7),
            dependencies: const [
              ActivityDependency(
                  activityId: 'a2', type: DependencyType.finishToStart),
            ]),
        // Deleting 'a3' left this link dangling.
        activity('a4', 'Protection Panel Installation',
            duration: 18,
            dependencies: const [
              ActivityDependency(
                  activityId: 'a3-deleted', type: DependencyType.finishToStart),
            ]),
        // No duration set — CPM assumes a day, which the sheet flags.
        activity('a5', 'Pre-Commissioning Tests', dependencies: const [
          ActivityDependency(
              activityId: 'a1', type: DependencyType.finishToStart),
        ]),
      ]),
    );

    await tester.tap(find.text('Run CPM'));
    await settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_cpm_results_with_issues.png'),
    );
  });

  testWidgets('03 CPM result sheet on a clean plan', (tester) async {
    if (isCi) return;
    await pumpBuilder(tester, scheduleWith(populated));

    await tester.tap(find.text('Run CPM'));
    await settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_cpm_results_clean.png'),
    );
  });

  testWidgets('04 export sheet', (tester) async {
    if (isCi) return;
    await pumpBuilder(tester, scheduleWith(populated));

    await tester.tap(find.text('Export'));
    await settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_export_sheet.png'),
    );
  });

  testWidgets('05 import by methodology dialog', (tester) async {
    if (isCi) return;
    await pumpBuilder(tester, scheduleWith(populated));

    await tester.tap(find.text('Import by Methodology'));
    await settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05_import_by_methodology.png'),
    );
  });

  testWidgets('06 delete confirmation on a parent row', (tester) async {
    if (isCi) return;
    await pumpBuilder(
      tester,
      scheduleWith([
        activity(
          'a1',
          'Detailed Design',
          level: 1,
          type: ActivityType.summary,
          children: [
            activity('a1a', 'Design Review',
                level: 2,
                duration: 4,
                start: DateTime(2026, 1, 8),
                end: DateTime(2026, 1, 11)),
            activity('a1b', 'Drawing Issue',
                level: 2,
                duration: 3,
                start: DateTime(2026, 1, 14),
                end: DateTime(2026, 1, 16)),
          ],
        ),
      ]),
    );

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06_delete_confirmation.png'),
    );
  });
}
