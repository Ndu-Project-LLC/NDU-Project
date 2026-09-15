// End-to-end widget test for the Risk Allowances card on the Cost Dashboard
// (the Risk Register → Cost Estimate pull, Lusaka 22: "whatever the total
// comes out to should show up on the cost estimate as well").
//
// The card is driven exactly as the user meets it — the real
// CostEstimateModuleScreen, real CostEstimateProvider, real pull — with only
// the Firestore read replaced by the card's `registerSource` test seam, so no
// Firebase and no network are involved. Verifies:
//   1. the register renders (stated amount + P×I matrix default, closed and
//      blank-description risks excluded);
//   2. tapping Pull creates the right riskAllowance lines;
//   3. the dashboard's Total Estimated Cost KPI moves by the pulled amount;
//   4. the pull is idempotent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart'
    as cost_dashboard;
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// The fake "risk_assessment_entries" register — same Map shape the card maps
/// Firestore docs into.
final riskRegister = <Map<String, String>>[
  {
    'id': 'R-241',
    'description': 'Budget overrun on steel supply',
    'probability': 'High',
    'impact': 'High',
    'score': '12000', // stated amount — must win over the matrix cell
    'status': 'Open',
  },
  {
    'id': 'R-242',
    'description': 'Vendor delay on CPE devices',
    'probability': 'Medium',
    'impact': 'High',
    'score': '', // no amount — defaults to the Medium×High cell (25,000)
    'status': 'Monitoring',
  },
  {
    'id': 'R-243',
    'description': 'Closed risk',
    'probability': 'High',
    'impact': 'High',
    'score': '9999',
    'status': 'Closed', // closed — must never be pulled
  },
  {
    'id': 'R-244',
    'description': '', // blank description — must never be pulled
    'probability': 'High',
    'impact': 'High',
    'score': '9999',
    'status': 'Open',
  },
];

Future<CostEstimateProvider> pumpDashboard(WidgetTester tester) async {
  final provider = CostEstimateProvider();
  cost_dashboard.riskRegisterSourceOverride = () => riskRegister;
  addTearDown(() => cost_dashboard.riskRegisterSourceOverride = null);

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
  // Frame 2: setup() runs → the dashboard (and the risk card) build; the
  // card's _load() starts against the override.
  await tester.pump(const Duration(milliseconds: 300));
  // Frame 3: the card's setState lands the register data.
  await tester.pump(const Duration(milliseconds: 100));
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('risk register renders with pending count and total',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(tester);

    // Card headline and its register total: 12,000 + 25,000 (Medium×High) =
    // 34,000 → rendered through the card's K formatter as 34K.
    expect(find.text('Risk Allowances (Risk Register)'), findsOneWidget);
    // Closed and blank-description risks are skipped: 2 valid of 4 docs.
    expect(find.textContaining('2 of 4 risks not yet in the estimate'),
        findsOneWidget);
    // 12,000 (stated) + 25,000 (Medium×High matrix cell) = 37,000 to add.
    expect(find.textContaining(r'$15500'), findsNothing);
    expect(find.textContaining('14500'), findsNothing);
    expect(find.textContaining('37000'), findsOneWidget);
    // The pull button offers exactly the pending risks.
    expect(find.text('Pull 2 into Cost Estimate'), findsOneWidget);
  });

  testWidgets('pulling creates the risk allowance lines and moves the KPI',
      (tester) async {
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
      find.textContaining('Added 2 risk allowance lines'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$37000 total'), findsOneWidget);

    // The estimate now carries exactly the two expected lines.
    final lines = provider.estimate!.lines;
    expect(lines, hasLength(2));
    expect(
      lines.every((l) => l.category == CostCategory.riskAllowance),
      isTrue,
    );
    expect(
      lines.every((l) => l.subCategory == 'Risk (register)'),
      isTrue,
    );
    expect(
      lines.every((l) => l.aiGenerated == false),
      isTrue,
    );

    final stated = lines.singleWhere((l) => l.description == 'Budget overrun on steel supply');
    expect(stated.total, 12000);
    // The basis records the register id and the risk's matrix position.
    expect(stated.basisReference, contains('Risk register R-241'));

    final matrix = lines.singleWhere((l) => l.description == 'Vendor delay on CPE devices');
    expect(matrix.total, 25000);
    expect(matrix.basisReference, contains('P: Medium × I: High'));

    // The dashboard's headline KPI reflects the pulled allowance: 12,000 +
    // 25,000 = 37,000 → 37K.
    // KPI labels render upper-cased on the tile (see _KpiTile).
    expect(find.text('TOTAL ESTIMATED COST'), findsOneWidget);
    // The 37K total shows up throughout the dashboard (KPI tile, breakdown,
    // spotlight bar) — the headline figure is present, not unique.
    expect(find.text(r'$37K'), findsWidgets);
    expect(provider.estimate!.totals.riskAllowances, 37000);
  });

  testWidgets('the pull is idempotent — the card reports everything reflected',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Pull 2 into Cost Estimate'));
    await tester.tap(find.text('Pull 2 into Cost Estimate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Data-layer idempotency: re-pulling the same candidates adds nothing.
    final again = provider.pullRiskCostLines(provider.estimate!.lines
        .map((l) => (
              riskId: '',
              description: l.description,
              probability: 'High',
              impact: 'High',
              total: l.total,
            ))
        .toList());
    expect(again.pulled, 0);
    expect(again.alreadyInEstimate, 2);

    // UI idempotency: the card now shows the all-pulled state and the button
    // is gone.
    expect(find.textContaining('risks reflected in the estimate'),
        findsOneWidget);
    expect(find.text('Pull 2 into Cost Estimate'), findsNothing);
    // And the estimate still holds exactly two risk lines.
    expect(provider.estimate!.lines, hasLength(2));
  });
}
