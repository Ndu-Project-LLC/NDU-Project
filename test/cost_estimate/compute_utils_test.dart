// Tests for ComputeUtils — the totals formula behind every Cost Estimate KPI.
//
// The guidance-doc formula this pins down:
//   Direct + Indirect + SHER/Q + RiskAllowance + Contingency + Escalation
//     + Taxes + Financing + Startup + Warranty + Decommissioning = Cost Baseline
//   Cost Baseline + Management Reserve = Total Authorized Budget
//
// Note the deliberate asymmetry: Management Reserve is EXCLUDED from the cost
// baseline and only enters the total authorized budget, which is what makes it
// a reserve rather than budgeted cost.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

CostLine line(
  CostCategory category,
  double total, {
  String id = 'l',
  VarianceType? varianceType,
  double? varianceDelta,
  double? varianceBaselineTotal,
  double? quantity,
  double? rate,
}) {
  return CostLine(
    id: id,
    category: category,
    subCategory: '',
    description: id,
    total: total,
    inSchedule: false,
    basisSource: CostSourceType.expertJudgment,
    aiGenerated: false,
    varianceType: varianceType,
    varianceDelta: varianceDelta,
    varianceBaselineTotal: varianceBaselineTotal,
    quantity: quantity,
    rate: rate,
  );
}

void main() {
  group('computeTotals — the baseline formula', () {
    test('an empty estimate totals zero', () {
      final t = ComputeUtils.computeTotals(const []);
      expect(t.direct, 0);
      expect(t.indirect, 0);
      expect(t.costBaseline, 0);
      expect(t.managementReserve, 0);
      expect(t.totalAuthorizedBudget, 0);
    });

    test('direct gathers exactly labor, materials, software, procurement, '
        'travelTraining and construction', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 100, id: 'labor'),
        line(CostCategory.materials, 10, id: 'materials'),
        line(CostCategory.software, 1, id: 'software'),
        line(CostCategory.procurement, 20, id: 'procurement'),
        line(CostCategory.travelTraining, 2, id: 'travel'),
        line(CostCategory.construction, 200, id: 'construction'),
      ]);
      expect(t.direct, 333);
    });

    test('indirect gathers projectTeam, overheads, ga, facilities and '
        'insuranceCompliance — not labor or construction', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.projectTeam, 500, id: 'team'),
        line(CostCategory.overheads, 50, id: 'oh'),
        line(CostCategory.ga, 5, id: 'ga'),
        line(CostCategory.facilities, 15, id: 'fac'),
        line(CostCategory.insuranceCompliance, 12, id: 'ins'),
        line(CostCategory.labor, 9999, id: 'must-not-count'),
      ]);
      expect(t.indirect, 582);
    });

    test('ssher and quality are their own bucket, excluded from direct and '
        'indirect', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.ssher, 40, id: 'ssher'),
        line(CostCategory.quality, 60, id: 'quality'),
      ]);
      expect(t.sherQuality, 100);
      expect(t.direct, 0);
      expect(t.indirect, 0);
      expect(t.costBaseline, 100);
    });

    test('costBaseline sums all eleven buckets but NOT management reserve', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 1000, id: 'direct'),
        line(CostCategory.projectTeam, 200, id: 'indirect'),
        line(CostCategory.ssher, 30, id: 'sher'),
        line(CostCategory.quality, 20, id: 'q'),
        line(CostCategory.riskAllowance, 50, id: 'risk'),
        line(CostCategory.contingency, 75, id: 'cont'),
        line(CostCategory.escalation, 25, id: 'esc'),
        line(CostCategory.taxes, 15, id: 'tax'),
        line(CostCategory.financing, 10, id: 'fin'),
        line(CostCategory.startup, 5, id: 'start'),
        line(CostCategory.warranty, 3, id: 'warranty'),
        line(CostCategory.decommissioning, 2, id: 'decom'),
        line(CostCategory.mgmtReserve, 900, id: 'reserve'),
      ]);

      // 1000 + 200 + 50 + 50 + 75 + 25 + 15 + 10 + 5 + 3 + 2
      expect(t.costBaseline, 1435);
      expect(t.managementReserve, 900);
      expect(t.totalAuthorizedBudget, 2335);
    });

    test('management reserve alone leaves the baseline at zero but raises the '
        'authorized budget', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.mgmtReserve, 400, id: 'reserve'),
      ]);
      expect(t.costBaseline, 0);
      expect(t.totalAuthorizedBudget, 400);
    });
  });

  group('computeTotals — variance-adjusted lines', () {
    test('a remove line subtracts its baseline total instead of adding its own',
        () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 1000, id: 'base'),
        line(CostCategory.labor, 0,
            id: 'removed',
            varianceType: VarianceType.remove,
            varianceBaselineTotal: 300),
      ]);
      // The removed line's own `total` (0) is ignored; the baseline 300 is
      // subtracted.
      expect(t.direct, 700);
    });

    test('a change line contributes its delta, not its total', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 1000, id: 'base'),
        line(CostCategory.labor, 9999,
            id: 'changed',
            varianceType: VarianceType.change,
            varianceDelta: 250),
      ]);
      expect(t.direct, 1250);
    });

    test('an add line contributes its total', () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 1000, id: 'base'),
        line(CostCategory.labor, 500,
            id: 'added', varianceType: VarianceType.add),
      ]);
      expect(t.direct, 1500);
    });

    test('a remove line with no baseline total subtracts zero, not null-crash',
        () {
      final t = ComputeUtils.computeTotals([
        line(CostCategory.labor, 1000, id: 'base'),
        line(CostCategory.labor, 0,
            id: 'removed', varianceType: VarianceType.remove),
      ]);
      expect(t.direct, 1000);
    });
  });

  group('recalcLineTotal', () {
    test('multiplies quantity by rate', () {
      final l = line(CostCategory.labor, 0, quantity: 12, rate: 250);
      expect(ComputeUtils.recalcLineTotal(l).total, 3000);
    });

    test('leaves the total untouched when quantity or rate is missing', () {
      expect(
        ComputeUtils.recalcLineTotal(line(CostCategory.labor, 42, rate: 7))
            .total,
        42,
      );
      expect(
        ComputeUtils.recalcLineTotal(line(CostCategory.labor, 42, quantity: 7))
            .total,
        42,
      );
    });
  });

  group('computeVariance', () {
    test('reports delta and percentage against the baseline snapshot', () {
      final summary = ComputeUtils.computeVariance(
        [line(CostCategory.labor, 1000, id: 'base')],
        [line(CostCategory.labor, 1150, id: 'base')],
      );
      expect(summary.baselineTotal, 1000);
      expect(summary.currentTotal, 1150);
      expect(summary.delta, 150);
      expect(summary.deltaPct, 15);
    });

    test('avoids dividing by zero when the baseline is empty', () {
      final summary = ComputeUtils.computeVariance(const [],
          [line(CostCategory.labor, 500, id: 'new')]);
      expect(summary.deltaPct, 0);
      expect(summary.delta, 500);
    });

    test('per-category rows carry the same variance rules as the totals', () {
      final summary = ComputeUtils.computeVariance(
        [line(CostCategory.labor, 1000, id: 'base')],
        [
          line(CostCategory.labor, 1000, id: 'base'),
          line(CostCategory.labor, 0,
              id: 'removed',
              varianceType: VarianceType.remove,
              varianceBaselineTotal: 200),
        ],
      );
      final labor =
          summary.byCategory.firstWhere((c) => c.category == CostCategory.labor);
      expect(labor.baseline, 1000);
      expect(labor.current, 800);
      expect(labor.delta, -200);
    });
  });

  group('formatCurrency', () {
    test('inserts thousands separators', () {
      expect(formatCurrency(1000), r'$1,000');
      expect(formatCurrency(1234567), r'$1,234,567');
      expect(formatCurrency(1234567890), r'$1,234,567,890');
    });

    test('leaves sub-thousand amounts alone', () {
      expect(formatCurrency(0), r'$0');
      expect(formatCurrency(999), r'$999');
    });

    test('groups negative amounts after the sign', () {
      expect(formatCurrency(-5000), r'-$5,000');
    });

    test('honours the currency symbol argument', () {
      expect(formatCurrency(1500, 'EUR'), '€1,500');
      expect(formatCurrency(1500, 'GBP'), '£1,500');
    });
  });

  group('formatAmountGrouped — the symbol-free half', () {
    test('groups whole units', () {
      expect(formatAmountGrouped(1000), '1,000');
      expect(formatAmountGrouped(4200000), '4,200,000');
      expect(formatAmountGrouped(999), '999');
    });

    test('never emits a currency symbol, so prefixing one cannot double it', () {
      for (final value in [0.0, 999.0, 1000.0, 1234567.0, -5000.0]) {
        final s = formatAmountGrouped(value);
        expect(s.contains(r'$'), isFalse, reason: 'value=$value s=$s');
        expect(s.contains('€'), isFalse, reason: 'value=$value s=$s');
        expect(s.contains('£'), isFalse, reason: 'value=$value s=$s');
      }
    });

    test('renders one symbol, not two, when the caller supplies it', () {
      // Regression: the Builder used to do
      //   '$currencySymbol${formatCurrency(line.total, 'USD')}'
      // which rendered "$$4,200,000".
      const preferenceSymbol = r'$';
      final rendered =
          '$preferenceSymbol${formatAmountGrouped(4200000)}';
      expect(rendered, r'$4,200,000');
      expect(r'$'.allMatches(rendered).length, 1);
    });

    test('keeps a symbol formatCurrency does not know about', () {
      // formatCurrency only hardcodes USD/EUR/GBP, so on a Zambian project it
      // groups the number but silently drops the symbol — the reason the
      // Builder formats the number itself and lets user preferences supply the
      // symbol.
      expect(formatCurrency(1500, 'ZMW'), '1,500');
      expect(formatCurrency(1500, 'ZMW').contains(r'$'), isFalse);
      expect('ZK${formatAmountGrouped(1500)}', 'ZK1,500');
    });
  });
}
