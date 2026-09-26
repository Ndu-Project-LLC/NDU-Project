// End-to-end widget test for the Cost of Quality card on the Cost Dashboard —
// the other half of the round trip whose capture side is covered by
// `test/screens/quality_cost_of_quality_tab_test.dart`.
//
// Lusaka 25 (copy): "quality is not done … the quality costs must reach the cost
// estimate."
//
// The card is driven exactly as the user meets it — the real
// CostEstimateModuleScreen, the real CostEstimateProvider, the real pull — with
// only the project read replaced by the card's `dataSource` test seam, so no
// Firebase and no network are involved. Verifies:
//   1. the four categories are selected and totalled (estimated vs actual);
//   2. an unpriced entry is counted as waiting, not carried as a zero;
//   3. tapping Pull creates the right `quality` lines, with the actual winning
//      over the estimate once one is recorded;
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
import 'package:ndu_project/models/cost_of_quality.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

CoQEntry _entry({
  required String id,
  required String description,
  String scope = 'Internal',
  double estimated = 0,
  double actual = 0,
}) =>
    CoQEntry.fromJson({
      'id': id,
      'description': description,
      'scope': scope,
      'estimatedCost': estimated,
      'actualCost': actual,
    });

/// Prevention 4,500 + Appraisal 1,200 estimated; Internal failure 3,750 actual
/// (estimate 2,000 — the actual must win); External failure 900 estimated. The
/// fifth entry is unpriced and must be reported, never carried as a zero.
final qualityData = CostOfQualityData(
  preventionCosts: [
    _entry(id: 'p1', description: 'Code reviews', estimated: 4500),
  ],
  appraisalCosts: [
    _entry(id: 'a1', description: 'Inspection', estimated: 1200),
  ],
  internalFailureCosts: [
    _entry(id: 'i1', description: 'Rework', estimated: 2000, actual: 3750),
  ],
  externalFailureCosts: [
    _entry(id: 'e1', description: 'Warranty claims', estimated: 900),
  ],
);

/// 4,500 + 1,200 + 3,750 + 900 = 10,350.
const double _expectedTotal = 10350;

Future<CostEstimateProvider> pumpDashboard(
  WidgetTester tester, {
  CostOfQualityData? data,
}) async {
  final provider = CostEstimateProvider();
  cost_dashboard.costOfQualitySourceOverride = () => data ?? qualityData;
  addTearDown(() => cost_dashboard.costOfQualitySourceOverride = null);

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

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the card lists the priced entries and the amount to add',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(tester);

    expect(
      find.text('Cost of Quality (Prevention / Appraisal / Failure)'),
      findsOneWidget,
    );
    // All four entries are priced, so four are ready and none is waiting.
    expect(find.textContaining('10350'), findsOneWidget);
    expect(find.text('Pull 4 quality cost lines'), findsOneWidget);
  });

  testWidgets('an unpriced entry is reported, not carried as a zero',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final withUnpriced = CostOfQualityData(
      preventionCosts: [
        ...qualityData.preventionCosts,
        _entry(id: 'p2', description: 'Unpriced idea'),
      ],
      appraisalCosts: qualityData.appraisalCosts,
      internalFailureCosts: qualityData.internalFailureCosts,
      externalFailureCosts: qualityData.externalFailureCosts,
    );
    await pumpDashboard(tester, data: withUnpriced);

    // Five entries, four priced — and the fifth is named as waiting.
    expect(find.textContaining('Awaiting a price'), findsOneWidget);
    expect(
      find.textContaining('still needs an estimated cost'),
      findsOneWidget,
    );
    // The unpriced entry adds nothing to the total.
    expect(find.textContaining('10350'), findsOneWidget);
  });

  testWidgets('pulling creates the quality lines and the actual wins',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Pull 4 quality cost lines'));
    await tester.tap(find.text('Pull 4 quality cost lines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Added 4 quality cost lines'),
      findsOneWidget,
    );

    final lines = provider.estimate!.lines;
    expect(lines, hasLength(4));
    expect(
      lines.every((l) => l.category == CostCategory.quality),
      isTrue,
      reason: 'quality costs must land in the quality category, not SSHER',
    );
    expect(lines.every((l) => l.aiGenerated == false), isTrue);

    // The category is carried into the sub-category, so prevention and external
    // failure stay distinguishable in the estimate rather than collapsing into
    // one "quality" figure.
    expect(
      lines.map((l) => l.subCategory).toSet(),
      {
        'Quality — Prevention',
        'Quality — Appraisal',
        'Quality — Internal Failure',
        'Quality — External Failure',
      },
    );

    // The actual amount wins over the estimate once one is recorded.
    final rework = lines.singleWhere((l) => l.description == 'Rework');
    expect(rework.total, 3750);
    expect(rework.basisReference, contains('Cost of Quality entry i1'));

    // Quality rolls into the estimate's combined SHER + Quality bucket (there
    // are no SSHER lines in this estimate, so the bucket is exactly the CoQ
    // total). The per-category split lives on the lines' sub-category above.
    expect(provider.estimate!.totals.sherQuality, _expectedTotal);
  });

  testWidgets('the pull is idempotent', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Pull 4 quality cost lines'));
    await tester.tap(find.text('Pull 4 quality cost lines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Data layer: re-pulling the same entries adds nothing.
    final again = provider.pullQualityCostLines(
      provider.estimate!.lines
          .map((l) => (
                entryId: '',
                description: l.description,
                category: l.subCategory.replaceFirst('Quality — ', ''),
                scope: '',
                total: l.total,
              ))
          .toList(),
    );
    expect(again.pulled, 0);
    expect(again.alreadyInEstimate, 4);

    // UI: the card now says the costs are already reflected.
    expect(
      find.textContaining('Quality costs are in the estimate'),
      findsOneWidget,
    );
    expect(provider.estimate!.lines, hasLength(4));
  });
}
