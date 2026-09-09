import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/staffing_row.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CostEstimateProvider fresh() {
    final provider = CostEstimateProvider();
    provider.setup(
      projectName: 'P',
      className: EstimateClass.class3,
      deliveryModel: DeliveryModel.waterfall,
    );
    return provider;
  }

  List<StaffingRow> rows() => [
        StaffingRow(
          role: 'Project Manager',
          quantity: 1,
          durationMonths: '12',
          monthlyCost: '5000',
        ),
        StaffingRow(
          role: 'Structural Engineer',
          quantity: 2,
          durationMonths: '6',
          monthlyCost: '3,500',
        ),
        StaffingRow(
          role: 'Site Supervisor',
          quantity: 1,
          durationMonths: '0',
          monthlyCost: '',
        ),
      ];

  test('pulls personnel as projectTeam lines with code-level totals', () {
    final provider = fresh();
    final result = provider.pullPersonnelCosts(rows());

    // Project Manager 1×12×5000 = 60000; Structural Engineer 2×6×3500 = 42000.
    // Site Supervisor has no months/rate → subtotal 0, still pulled.
    expect(result.pulled, 3);
    expect(result.alreadyInEstimate, 0);
    expect(result.addedTotal, 60000 + 42000);

    final lines = provider.estimate!.lines;
    expect(lines.length, 3);
    for (final line in lines) {
      expect(line.category, CostCategory.projectTeam);
      expect(line.subCategory, 'Personnel (staffing)');
      expect(line.inSchedule, isFalse);
      expect(line.aiGenerated, isFalse, reason: 'no AI — pure calculation');
    }
    final pm =
        lines.firstWhere((l) => l.description == 'Project Manager');
    expect(pm.total, 60000);
    expect(pm.quantity, 1);
    expect(pm.basisReference, contains('12 mo'));
    final se =
        lines.firstWhere((l) => l.description == 'Structural Engineer');
    expect(se.total, 42000);
    expect(se.basisReference, contains('2 × 6 mo'));
    // Baseline reflects the personnel cost immediately.
    expect(provider.estimate!.totals.costBaseline, 60000 + 42000);
  });

  test('idempotent — second pull adds nothing and reports already', () {
    final provider = fresh();
    final first = provider.pullPersonnelCosts(rows());
    expect(first.pulled, 3);

    final second = provider.pullPersonnelCosts(rows());
    expect(second.pulled, 0);
    expect(second.alreadyInEstimate, 3);
    expect(provider.estimate!.lines.length, 3);
  });

  test('a repriced row (different total) is pulled as a new line', () {
    final provider = fresh();
    provider.pullPersonnelCosts([rows().first]);

    // Same role but the staffing page now prices it higher — the estimate
    // line no longer matches, so it is represented as a new line.
    final updated = [
      StaffingRow(
        role: 'Project Manager',
        quantity: 1,
        durationMonths: '12',
        monthlyCost: '6000',
      ),
    ];
    final result = provider.pullPersonnelCosts(updated);
    expect(result.pulled, 1);
    expect(provider.estimate!.lines.length, 2);
  });

  test('no estimate → empty result (module auto-setup covers this)', () {
    final provider = CostEstimateProvider();
    final result = provider.pullPersonnelCosts(rows());
    expect(result.pulled, 0);
    expect(result.alreadyInEstimate, 0);
    expect(result.addedTotal, 0);
  });
}