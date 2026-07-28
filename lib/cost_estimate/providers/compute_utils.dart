library;

/// Cost Estimate — totals & variance computation (Dart equivalent)
///
/// Implements the baseline formula from the guidance doc:
///   Direct + Indirect + Risk + Contingency + Escalation + Taxes = Cost Baseline
///   Cost Baseline + Management Reserve = Total Authorized Budget

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';

class ComputeUtils {
  static EstimateTotals computeTotals(List<CostLine> lines) {
    double effectiveLineTotal(CostLine l) {
      if (l.varianceType == VarianceType.remove) {
        return -(l.varianceBaselineTotal ?? 0);
      }
      if (l.varianceType == VarianceType.change) {
        return l.varianceDelta ?? 0;
      }
      return l.total;
    }

    double sumCats(List<CostCategory> cats) {
      return lines
          .where((l) => cats.contains(l.category))
          .fold(0.0, (acc, l) => acc + effectiveLineTotal(l));
    }

    final direct = sumCats([
      CostCategory.labor,
      CostCategory.materials,
      CostCategory.software,
      CostCategory.procurement,
      CostCategory.travelTraining,
      CostCategory.construction,
    ]);
    final indirect = sumCats([
      CostCategory.projectTeam,
      CostCategory.overheads,
      CostCategory.ga,
      CostCategory.facilities,
      CostCategory.insuranceCompliance,
    ]);
    final sherQuality =
        sumCats([CostCategory.ssher, CostCategory.quality]);
    final riskAllowances = sumCats([CostCategory.riskAllowance]);
    final contingency = sumCats([CostCategory.contingency]);
    final escalation = sumCats([CostCategory.escalation]);
    final taxes = sumCats([CostCategory.taxes]);
    final financing = sumCats([CostCategory.financing]);
    final startup = sumCats([CostCategory.startup]);
    final warranty = sumCats([CostCategory.warranty]);
    final decommissioning = sumCats([CostCategory.decommissioning]);
    final managementReserve = sumCats([CostCategory.mgmtReserve]);

    final costBaseline = direct +
        indirect +
        sherQuality +
        riskAllowances +
        contingency +
        escalation +
        taxes +
        financing +
        startup +
        warranty +
        decommissioning;

    final totalAuthorizedBudget = costBaseline + managementReserve;

    return EstimateTotals(
      direct: direct,
      indirect: indirect,
      sherQuality: sherQuality,
      riskAllowances: riskAllowances,
      contingency: contingency,
      escalation: escalation,
      taxes: taxes,
      financing: financing,
      startup: startup,
      warranty: warranty,
      decommissioning: decommissioning,
      costBaseline: costBaseline,
      managementReserve: managementReserve,
      totalAuthorizedBudget: totalAuthorizedBudget,
    );
  }

  /// Recompute a single line's total from quantity × rate.
  static CostLine recalcLineTotal(CostLine line) {
    if (line.quantity != null && line.rate != null) {
      return line.copyWith(total: line.quantity! * line.rate!);
    }
    return line;
  }

  /// Variance vs baseline snapshot.
  static VarianceSummary computeVariance(
    List<CostLine> baselineLines,
    List<CostLine> currentLines,
  ) {
    final baselineTotals = computeTotals(baselineLines);
    final currentTotals = computeTotals(currentLines);
    final delta = currentTotals.costBaseline - baselineTotals.costBaseline;
    final deltaPct = baselineTotals.costBaseline > 0
        ? (delta / baselineTotals.costBaseline) * 100
        : 0.0;

    final byCategory = CostCategory.values.map((cat) {
      final baseline = baselineLines
          .where((l) => l.category == cat)
          .fold(0.0, (a, l) => a + l.total);
      final current = currentLines
          .where((l) => l.category == cat)
          .fold(0.0, (a, l) {
        if (l.varianceType == VarianceType.remove) {
          return a - (l.varianceBaselineTotal ?? 0);
        }
        if (l.varianceType == VarianceType.change) {
          return a + (l.varianceDelta ?? 0);
        }
        return a + l.total;
      });
      return VarianceByCategory(
        category: cat,
        label: cat.label,
        baseline: baseline,
        current: current,
        delta: current - baseline,
      );
    }).toList();

    return VarianceSummary(
      baselineTotal: baselineTotals.costBaseline,
      currentTotal: currentTotals.costBaseline,
      delta: delta,
      deltaPct: deltaPct,
      byCategory: byCategory,
    );
  }
}

class VarianceSummary {
  final double baselineTotal;
  final double currentTotal;
  final double delta;
  final double deltaPct;
  final List<VarianceByCategory> byCategory;

  const VarianceSummary({
    required this.baselineTotal,
    required this.currentTotal,
    required this.delta,
    required this.deltaPct,
    required this.byCategory,
  });
}

class VarianceByCategory {
  final CostCategory category;
  final String label;
  final double baseline;
  final double current;
  final double delta;

  const VarianceByCategory({
    required this.category,
    required this.label,
    required this.baseline,
    required this.current,
    required this.delta,
  });
}

/// Format a currency amount.
String formatCurrency(double amount, [String currency = 'USD']) {
  final symbol = switch (currency) {
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '',
  };
  return '$symbol${amount.toInt().toString().replaceAllMapped(RegExp(r'(d{1,3})(?=(d{3})+(?!d))'), (Match m) => '${m[1]},')}';
}

/// Format a variance delta with sign.
String formatVariance(double delta, [String currency = 'USD']) {
  final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
  return '$sign${formatCurrency(delta.abs(), currency)}';
}

/// Format a percentage with sign.
String formatPercent(double value) {
  final sign = value > 0 ? '+' : value < 0 ? '−' : '';
  return '$sign${value.abs().toStringAsFixed(1)}%';
}

/// Generate a unique ID.
String newId([String prefix = 'id']) {
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
}

/// Create an empty BOE for a given estimate class.
BasisOfEstimate emptyBOE(EstimateClass className) => BasisOfEstimate(
      scopeBasis: '',
      assumptions: [],
      constraints: [],
      exclusions: [],
      dataSources: [],
      methodology: [],
      accuracyRange: className.accuracy,
      escalationAssumptions: '',
    );

/// Create an empty estimate scaffold.
CostEstimate createEmptyEstimate({
  required String projectId,
  required String projectName,
  required EstimateClass className,
  required DeliveryModel deliveryModel,
  required String userEmail,
}) {
  final now = DateTime.now();
  return CostEstimate(
    id: newId('ce'),
    projectId: projectId,
    projectName: projectName,
    className: className,
    deliveryModel: deliveryModel,
    status: EstimateStatus.draft,
    currency: 'USD',
    lines: [],
    boe: emptyBOE(className),
    totals: EstimateTotals.empty(),
    access: [
      AccessGrant(
        userEmail: userEmail,
        role: RBACRole.admin,
        grantedBy: userEmail,
        grantedAt: now,
      ),
    ],
    stakeholders: [],
    accountingIntegration: const AccountingIntegration(
      provider: AccountingProvider.none,
      connected: false,
      glMapping: [],
    ),
    aiSuggestions: [],
    createdAt: now,
    updatedAt: now,
  );
}

/// Default GL code suggestions per category.
Map<CostCategory, ({String code, String name})> defaultGLMappings() => {
      CostCategory.labor: (code: '5000', name: 'Direct Labor'),
      CostCategory.materials: (code: '5100', name: 'Materials & Supplies'),
      CostCategory.software: (code: '6100', name: 'Software & Subscriptions'),
      CostCategory.procurement:
          (code: '5200', name: 'Procurement & Vendor Services'),
      CostCategory.travelTraining: (code: '6200', name: 'Travel & Training'),
      CostCategory.construction: (code: '5300', name: 'Construction & Field Costs'),
      CostCategory.projectTeam: (code: '5500', name: 'Project Management'),
      CostCategory.overheads: (code: '6500', name: 'Overheads'),
      CostCategory.ga: (code: '6600', name: 'General & Administrative'),
      CostCategory.facilities: (code: '6700', name: 'Facilities'),
      CostCategory.insuranceCompliance:
          (code: '6800', name: 'Insurance & Compliance'),
      CostCategory.ssher: (code: '6900', name: 'SSHER'),
      CostCategory.quality: (code: '6910', name: 'Quality Management'),
      CostCategory.riskAllowance: (code: '7200', name: 'Risk Allowances'),
      CostCategory.contingency: (code: '7300', name: 'Contingency'),
      CostCategory.mgmtReserve: (code: '7400', name: 'Management Reserve'),
      CostCategory.escalation: (code: '7500', name: 'Escalation'),
      CostCategory.taxes: (code: '2300', name: 'Taxes & Duties Payable'),
      CostCategory.financing: (code: '7600', name: 'Financing Costs'),
      CostCategory.startup: (code: '7700', name: 'Startup & Transition'),
      CostCategory.warranty: (code: '7800', name: 'Warranty & Closeout'),
      CostCategory.decommissioning: (code: '7900', name: 'Decommissioning'),
    };
