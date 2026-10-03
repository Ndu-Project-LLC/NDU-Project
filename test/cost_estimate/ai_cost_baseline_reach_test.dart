// AUDIT: can an AI-generated number reach the Cost Estimate baseline without
// an explicit human action?
//
// Answer: yes, via the Front End Planning allowance register. This test drives
// the real production code path end to end (no fakes) to pin it down:
//
//   1. The allowance AI prompt INSTRUCTS the model to tag items
//      `appliesTo: ["Schedule", "Estimate"]`
//      (lib/services/openai_service_secure.dart:3145).
//   2. Merely opening the FEP Allowance screen auto-runs that AI when the
//      section is empty — initState -> postFrame ->
//      _checkAndGenerateDefaultAllowances -> _generateDefaultAllowances
//      (lib/screens/front_end_planning_allowance.dart:109,174).
//   3. _syncItemsToProvider -> applyTaggedFrontEndPlanningData turns every
//      allowance tagged 'Estimate' into a project cost item.
//   4. The Cost Estimate module auto-imports those items into lines when the
//      estimate is empty (initState + every build).
//   5. computeTotals never inspects aiGenerated, so the number lands in
//      costBaseline.
//
// So the human action was "opened the Allowance screen". Nobody reviewed,
// approved, or tagged the number that ends up in the baseline.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

CostEstimateProvider readyEstimate() {
  final provider = CostEstimateProvider();
  provider.setup(
    projectName: 'Test Project',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
  );
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AI number reaching the cost baseline unattended', () {
    test('an AI-tagged allowance flows to the baseline with no acceptance step',
        () {
      // ── 1. What the allowance AI is instructed to return ────────────────
      // The model picks the 'Estimate' tag itself; nothing validates that a
      // human agreed with it.
      final aiAllowance = AllowanceItem(
        id: 'allow_ai_1',
        name: 'Regional weather contingency',
        type: 'Weather',
        amount: 250000,
        appliesTo: const ['Schedule', 'Estimate'],
        notes: 'AI estimated exposure for hurricane season',
      );

      // ── 2/3. The FEP sync that the Allowance screen triggers ────────────
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        ProjectDataModel(
          projectName: 'Test Project',
          frontEndPlanning: FrontEndPlanningData(
            allowanceItems: [aiAllowance],
          ),
        ),
      );

      expect(data.costEstimateItems, hasLength(1));
      final item = data.costEstimateItems.single;
      expect(item.amount, 250000);
      expect(item.source, 'planning_allowance');
      expect(item.costType, 'indirect');

      // ── 4. The Cost Estimate auto-import ───────────────────────────────
      final ce = readyEstimate();
      expect(
        ce.importFromProjectCostEstimateItems(data.costEstimateItems),
        isTrue,
      );

      final line = ce.estimate!.lines.single;
      expect(line.total, 250000);
      expect(line.category, CostCategory.overheads);
      expect(line.description, contains('Regional weather contingency'));

      // ── 5. It is in the baseline, flagged as NOT AI ────────────────────
      // `source` is 'planning_allowance', and the import only treats
      // 'ai_generated' as AI — a string nothing in the codebase ever writes.
      expect(line.aiGenerated, isFalse,
          reason: 'AI provenance is lost: the line reads as human-entered');

      final totals = ComputeUtils.computeTotals(ce.estimate!.lines);
      expect(totals.indirect, 250000);
      expect(totals.costBaseline, 250000);
      expect(totals.totalAuthorizedBudget, 250000);
    });

    test('an allowance the AI did not tag is correctly excluded', () {
      // Control case: the guard that exists is the appliesTo tag, not any AI
      // check. Untagged AI output is filtered out.
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        ProjectDataModel(
          projectName: 'Test Project',
          frontEndPlanning: FrontEndPlanningData(
            allowanceItems: [
              AllowanceItem(
                id: 'allow_ai_2',
                name: 'Untagged exposure',
                amount: 99999,
                appliesTo: const ['Project Wide'],
              ),
            ],
          ),
        ),
      );

      expect(data.costEstimateItems, isEmpty);
    });

    test('a zero-amount allowance is excluded', () {
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        ProjectDataModel(
          projectName: 'Test Project',
          frontEndPlanning: FrontEndPlanningData(
            allowanceItems: [
              AllowanceItem(
                id: 'allow_ai_3',
                name: 'Placeholder',
                amount: 0,
                appliesTo: const ['Estimate'],
              ),
            ],
          ),
        ),
      );

      expect(data.costEstimateItems, isEmpty);
    });
  });

  group('the aiGenerated flag cannot be trusted', () {
    test('an item accepted from the AI dialog is imported as NOT AI', () {
      // cost_estimate_screen.dart:686 writes source: 'ai' for items the user
      // accepted in the AI suggestions dialog, but the import checks for
      // 'ai_generated'. The two strings never meet.
      final ce = readyEstimate();
      ce.importFromProjectCostEstimateItems([
        CostEstimateItem(
          id: 'ai_item',
          title: 'AI suggested line',
          amount: 5000,
          costType: 'indirect',
          source: 'ai',
        ),
      ]);

      final line = ce.estimate!.lines.single;
      expect(line.total, 5000);
      expect(line.aiGenerated, isFalse,
          reason: "'ai' is never recognised as 'ai_generated'");
    });

    test('the only string that sets aiGenerated is never written', () {
      // Documents the dead comparison at cost_estimate_provider.dart:359.
      final ce = readyEstimate();
      ce.importFromProjectCostEstimateItems([
        CostEstimateItem(
          id: 'legacy',
          title: 'Legacy AI line',
          amount: 100,
          source: 'ai_generated',
        ),
      ]);

      expect(ce.estimate!.lines.single.aiGenerated, isTrue);
    });
  });

  group('computeTotals has no AI guard at all', () {
    test('an explicitly AI-generated line still counts in the baseline', () {
      final aiLine = CostLine(
        id: 'ai',
        category: CostCategory.labor,
        subCategory: '',
        description: 'AI generated labour',
        total: 1000,
        inSchedule: false,
        basisSource: CostSourceType.kazAI,
        aiGenerated: true,
      );

      final totals = ComputeUtils.computeTotals([aiLine]);
      expect(totals.direct, 1000);
      expect(totals.costBaseline, 1000,
          reason: 'no aiGenerated/basisSource filter exists in the totals path');
    });
  });
}
