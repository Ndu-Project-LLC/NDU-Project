import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('BOE, stakeholders, lines and totals survive a save/load round-trip',
      () async {
    // ── Writer session ───────────────────────────────────────────────
    final writer = CostEstimateProvider();
    writer.setup(
      projectName: 'Chipata—Lundazi Road',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );

    writer.updateBOE(writer.estimate!.boe.copyWith(
      scopeBasis: 'Rehabilitation of the existing corridor',
      assumptions: ['Traffic counts are accurate'],
      constraints: ['Budget cap of USD 50M'],
      exclusions: ['Land acquisition'],
      methodology: [EstimationMethod.bottomUp],
    ));
    writer.addStakeholder(const Stakeholder(
      id: 'sh_1',
      name: 'Alinafe Banda',
      email: 'alinafe@ndu.gov.zm',
      role: 'Project Sponsor',
      sme: true,
      includedInDevelopment: true,
    ));
    writer.addLine(const CostLine(
      id: 'line_1',
      category: CostCategory.construction,
      subCategory: 'Road Works',
      description: 'Pavement works — Section A',
      wbsRef: 'G1.1.1',
      quantity: 1,
      unit: 'lump',
      rate: 480000,
      total: 480000,
      inSchedule: true,
      basisSource: CostSourceType.vendorQuote,
      aiGenerated: false,
    ));

    // Let the async SharedPreferences writes flush.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // ── Reader session (fresh provider = cold start) ────────────────
    final reader = CostEstimateProvider();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final estimate = reader.estimate;
    expect(estimate, isNotNull, reason: 'saved estimate should reload');
    expect(estimate!.projectName, 'Chipata—Lundazi Road');
    expect(estimate.totals.costBaseline, 480000,
        reason: 'totals must survive the round-trip');
    expect(estimate.lines.length, 1);
    expect(estimate.lines.first.wbsRef, 'G1.1.1');

    // BOE restored field-for-field.
    expect(estimate.boe.scopeBasis,
        'Rehabilitation of the existing corridor');
    expect(estimate.boe.assumptions, ['Traffic counts are accurate']);
    expect(estimate.boe.constraints, ['Budget cap of USD 50M']);
    expect(estimate.boe.exclusions, ['Land acquisition']);
    expect(estimate.boe.methodology, [EstimationMethod.bottomUp]);
    expect(estimate.boe.accuracyRange.low, isNegative);

    // Stakeholders restored.
    expect(estimate.stakeholders.length, 1);
    expect(estimate.stakeholders.first.name, 'Alinafe Banda');
    expect(estimate.stakeholders.first.email, 'alinafe@ndu.gov.zm');
    expect(estimate.stakeholders.first.sme, isTrue);
  });
}
