import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// Guards the removal of Cost from the Schedule Builder. Cost used to surface
/// in three places and is now gone from all of them:
///
///   1. the Activity Tree table had a "Cost" column ("—" / "$X" / "not priced");
///   2. the card view of the same tree showed a "Cost: $X" / "Cost: not priced
///      yet" chip on any activity linked to an estimate line;
///   3. the KPI strip carried a "Cost Budget" tile.
///
/// The Activity Tree assertions deliberately run against an activity that IS
/// linked to a priced cost line — the old column and chip keyed off exactly
/// that link, so a test with an unlinked activity would pass vacuously.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Builds a schedule with one activity whose `costLineId` points at a priced
  /// line in a real estimate — the state that used to render "$1,500" in the
  /// Cost column and the green "Cost: $1,500" chip on the card.
  ({ScheduleProvider schedule, CostEstimateProvider cost}) linkedSchedule() {
    final schedule = ScheduleProvider()
      ..setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');
    final root = schedule.schedule!.activities[0];
    final activityId = schedule.addActivity(
      root.id,
      const ScheduleActivity(
        id: '',
        level: 1,
        code: '1.1',
        name: 'Foundation Engineering Work Package',
        type: ActivityType.activity,
        domain: ScheduleDomain.engineering,
        dependencies: [],
        aiGenerated: false,
        children: [],
      ),
    );

    final cost = CostEstimateProvider()
      ..setup(
        projectName: 'Test Project',
        className: EstimateClass.class3,
        deliveryModel: DeliveryModel.waterfall,
      );
    cost.addLine(
      const CostLine(
        id: 'line_1',
        category: CostCategory.construction,
        subCategory: 'Works',
        description: 'Foundation works',
        quantity: 1,
        unit: 'lump',
        rate: 1500,
        total: 1500,
        inSchedule: true,
        basisSource: CostSourceType.vendorQuote,
        aiGenerated: false,
      ),
    );
    schedule.attachCostLineToActivity(activityId, 'line_1');
    return (schedule: schedule, cost: cost);
  }

  Future<void> pumpBuilder(
    WidgetTester tester, {
    required ScheduleProvider schedule,
    required CostEstimateProvider cost,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectDataProvider>.value(
        value: ProjectDataProvider(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(value: schedule),
            ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
            ChangeNotifierProvider<CostEstimateProvider>.value(value: cost),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BuilderScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The activity created by [linkedSchedule], carrying the cost link.
  ScheduleActivity linkedActivity(ScheduleProvider schedule) => schedule
      .schedule!.activities[0]
      .children
      .firstWhere((c) => c.name == 'Foundation Engineering Work Package');

  /// Scopes a finder to the Activity Tree table only. Needed because the
  /// "Drawing From" banner legitimately shows the estimate total — asserting
  /// on the whole page would conflate the two surfaces.
  Finder inActivityTreeTable(Finder matching) => find.descendant(
        of: find
            .ancestor(
              of: find.text('Domain'),
              matching: find.byType(Column),
            )
            .first,
        matching: matching,
      );

  /// Reveals the KPI strip, which sits above the Activity Tree and outside the
  /// initially-built viewport.
  Future<void> scrollToKpiStrip(WidgetTester tester) async {
    await tester.drag(find.byType(BuilderScreen), const Offset(0, -500));
    await tester.pump();
    await tester.pump();
  }

  /// TreasuryKpiStrip upper-cases its tile labels, so match them that way.

  testWidgets('the Activity Tree table has no Cost column', (tester) async {
    final (schedule: schedule, cost: cost) = linkedSchedule();
    // Sanity: the link the old column keyed off is really there.
    expect(linkedActivity(schedule).costLineId, isNotNull);

    await pumpBuilder(tester, schedule: schedule, cost: cost);

    // No "Cost" header in the Activity Tree table.
    expect(inActivityTreeTable(find.text('Cost')), findsNothing);
    // Header row still renders, so the assertion above is not vacuous.
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    // No per-row cost status values anywhere in the tree.
    expect(inActivityTreeTable(find.text('not priced')), findsNothing);
    expect(inActivityTreeTable(find.textContaining('\$1,500')), findsNothing);
  });

  testWidgets('the card view has no cost status chip', (tester) async {
    final (schedule: schedule, cost: cost) = linkedSchedule();
    await pumpBuilder(tester, schedule: schedule, cost: cost);

    // Switch the Activity Tree from the Table view to the Cards view.
    await tester.tap(find.text('Cards'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Activity Tree'), findsOneWidget);
    expect(find.text('Foundation Engineering Work Package'), findsOneWidget);
    expect(find.textContaining('Cost:'), findsNothing);
    expect(find.byIcon(Icons.attach_money), findsNothing);
  });

  testWidgets('the KPI strip has no Cost Budget tile', (tester) async {
    final (schedule: schedule, cost: cost) = linkedSchedule();
    await pumpBuilder(tester, schedule: schedule, cost: cost);
    await scrollToKpiStrip(tester);

    expect(find.text('COST BUDGET'), findsNothing);
    expect(find.text('From Cost Estimate'), findsNothing);
    expect(find.text('No estimate linked'), findsNothing);
    // The surviving tiles still render, so the assertion above is not vacuous.
    expect(find.text('TOTAL ACTIVITIES'), findsOneWidget);
    expect(find.text('TIMELINE SPAN'), findsOneWidget);
    expect(find.text('TOP DOMAIN'), findsOneWidget);
  });
}