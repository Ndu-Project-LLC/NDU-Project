// End-to-end widget test for the Personnel Costs card on the Cost Dashboard —
// the Staff Team Orchestration → Cost Estimate pull (Lusaka 22).
//
// The card is driven exactly as the user meets it — the real
// CostEstimateModuleScreen, real CostEstimateProvider, real pull — with only
// the Firestore read replaced by the card's `rowsSource` test seam, so no
// Firebase and no network are involved. Verifies:
//   1. the card renders the pending count as 'N of M roles not yet in the
//      estimate' (regression guard: it once interpolated the pending *list*,
//      which minified builds render as "[Instance of 'minified:js', …]");
//   2. the pending total and the pull button offer exactly the pending roles;
//   3. a role already carried by the estimate (same role + same computed
//      total) is excluded from the pending count;
//   4. tapping Pull creates the right `projectTeam` lines;
//   5. the pull is idempotent — the card flips to the all-priced state.
//
// Rows: role × quantity × months × monthly rate.
//   PM   1 × 4 × 3,000  = 12,000
//   Tech 2 × 6 × 2,000  = 24,000
//   Blank role (excluded) and already-priced Field Eng 1 × 3 × 2,000 = 6,000.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart'
    as cost_dashboard;
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

StaffingRow _row({
  required String role,
  int quantity = 1,
  required String months,
  required String monthlyCost,
}) =>
    StaffingRow(
      role: role,
      quantity: quantity,
      durationMonths: months,
      monthlyCost: monthlyCost,
    );

/// The fake "staff_team" sheet — same `List<StaffingRow>` shape
/// ExecutionPhaseService.loadStaffingRows returns.
final staffingRows = <StaffingRow>[
  _row(role: 'Project Manager', months: '4', monthlyCost: '3000'),
  _row(role: 'Field Engineer', months: '3', monthlyCost: '2000'), // 6,000
  _row(role: 'Technician', quantity: 2, months: '6', monthlyCost: '2000'),
  _row(role: '', months: '2', monthlyCost: '5000'), // blank — never pulled
];

/// 12,000 + 24,000 = 36,000 pending (the already-priced Field Eng 6,000 is
/// excluded — see pumpDashboard).
const double _expectedPendingTotal = 36000;

Future<CostEstimateProvider> pumpDashboard(WidgetTester tester) async {
  final provider = CostEstimateProvider();
  cost_dashboard.staffingRowsSourceOverride = () => staffingRows;
  addTearDown(() => cost_dashboard.staffingRowsSourceOverride = null);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CostEstimateProvider>.value(value: provider),
        ChangeNotifierProvider<WBSProvider>(create: (_) => WBSProvider()),
        ChangeNotifierProvider<ProjectDataProvider>(
            create: (_) => ProjectDataProvider()),
      ],
      child: const MaterialApp(home: CostEstimateModuleScreen()),
    ),
  );

  // Frame 1: initState schedules the auto-setup post-frame callback.
  await tester.pump();
  // Frame 2: setup() runs → the dashboard (and the personnel card) build; the
  // card's _load() starts against the override.
  await tester.pump(const Duration(milliseconds: 300));
  // Frame 3: the card's setState lands the staffing rows.
  await tester.pump(const Duration(milliseconds: 100));

  // Seed the estimate with a line that already carries the Field Engineer
  // role at its exact computed subtotal (1 × 3 × 2,000 = 6,000). The card's
  // pending scan must exclude it.
  provider.addLine(const CostLine(
    id: 'seed-field-eng',
    category: CostCategory.projectTeam,
    subCategory: 'Personnel (staffing)',
    description: 'Field Engineer',
    quantity: 1,
    unit: 'people',
    rate: null,
    total: 6000,
    inSchedule: false,
    basisSource: CostSourceType.expertJudgment,
    aiGenerated: false,
  ));
  await tester.pump();

  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'renders "N of M roles not yet in the estimate" with the pending total',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(tester);

    expect(find.text('Personnel Costs (Staff Team)'), findsOneWidget);

    // THE regression: the count must be the pending list's *length*, not the
    // list itself (minified builds render that as
    // "[Instance of 'minified:js', …]"). 3 valid roles, 1 seeded as priced →
    // 2 pending of 4 rows total (blank-role row still counts in M).
    expect(
      find.textContaining('2 of 4 roles not yet in the estimate'),
      findsOneWidget,
    );

    // 12,000 + 24,000 = 36,000 to add.
    expect(find.textContaining(r'$36000'), findsOneWidget);

    // The pull button offers exactly the pending roles.
    expect(find.text('Pull 2 into Cost Estimate'), findsOneWidget);
  });

  testWidgets(
      'pulling creates the personnel lines and the subtotal wins', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Pull 2 into Cost Estimate'));
    await tester.tap(find.text('Pull 2 into Cost Estimate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Snackbar confirms both lines and the combined total.
    expect(
      find.textContaining('Added 2 personnel cost lines'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$36000 total'), findsOneWidget);
    // Same figure, via the shared constant.
    expect(find.textContaining(_expectedPendingTotal.toStringAsFixed(0)),
        findsWidgets);

    // The estimate now carries the seeded line plus exactly the two pulls.
    final lines = provider.estimate!.lines;
    expect(
      lines.where((l) => l.subCategory == 'Personnel (staffing)'),
      hasLength(3),
    );

    final pm = lines.singleWhere((l) => l.description == 'Project Manager');
    expect(pm.category, CostCategory.projectTeam);
    expect(pm.total, 12000);
    // The basis records the exact people × months × rate computation.
    expect(pm.basisReference, contains('1 × 4 mo'));
    expect(pm.basisReference, contains(r'$3000/mo per person'));
    expect(pm.aiGenerated, isFalse);

    final tech = lines.singleWhere((l) => l.description == 'Technician');
    expect(tech.total, 24000);
    expect(tech.quantity, 2);
    expect(tech.unit, 'people');

    // Personnel costs roll into the estimate's indirect bucket.
    expect(provider.estimate!.totals.indirect, 36000 + 6000);
  });

  testWidgets(
      'the pull is idempotent — the card reports every role priced in',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Pull 2 into Cost Estimate'));
    await tester.tap(find.text('Pull 2 into Cost Estimate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Data layer: re-pulling the same rows adds nothing.
    final again = provider.pullPersonnelCosts(staffingRows);
    expect(again.pulled, 0);
    expect(again.alreadyInEstimate, 3);

    // UI idempotency: the card now shows the all-pulled state and the button
    // is gone. M counts every loaded row, including the blank-role row that
    // can never be pending (4 rows, none pending → '4 of 4').
    expect(
      find.text('4 of 4 roles already priced in the estimate ✓'),
      findsOneWidget,
    );
    expect(find.text('Pull 2 into Cost Estimate'), findsNothing);
  });
}
