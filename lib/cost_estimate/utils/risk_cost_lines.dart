/// Risk Register → Cost Estimate linkage.
///
/// Product rule (Lusaka 22 voice note, 2026-09-10): **"the risk also has a
/// risk matrix, it has like the calculations for the risk. So whatever the
/// total comes out to … should show up on the cost estimate as well."**
///
/// Like `schedule_work_packages.dart`, this file is the pure, testable half —
/// it selects which risks carry a cost exposure and maps each to one Risk
/// Allowance line. The provider does the data movement; the dashboard renders
/// the pull card. Deterministic, no AI: probability and impact levels are the
/// assessor's input, the score is whatever the assessor typed, and the
/// exposure amount is the assessor's number — code only selects and sums.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';

/// One risk to be pulled into the estimate, plus the Risk Allowance total it
/// maps to.
typedef RiskCostLine = ({
  String riskId,
  String description,
  String probability,
  String impact,
  double total,
});

/// Parse a risk score/amount that a user may have typed loosely.
///
/// Accepts `12`, `12,000`, `$12,000`, `12 000` — strips everything that is
/// not a digit or a dot, then parses. Returns 0 when nothing numeric remains.
double parseRiskAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}

/// Collect the risks that should become Risk Allowance lines.
///
/// Rules:
/// - **Amount wins.** A risk whose score/amount field carries a number is
///   taken as the assessor's cost exposure for that risk (users who do not
///   think in scores type money there; both are honoured).
/// - **Fallback: the P×I matrix.** When no amount is given, the risk's place
///   on the probability × impact matrix defaults the exposure: High×High is
///   the most expensive cell, Low×Low the cheapest. The matrix counts risks;
///   this turns each count into money.
/// - Open risks only: `Closed` risks are not exposures any more, and
///   `Cancelled`-style rows carry no allowance. Blank status counts as open.
/// - Blank descriptions are skipped — an unnamed risk cannot be estimated or
///   matched later, mirroring the blank-name rule in
///   `schedule_work_packages.dart`.
List<RiskCostLine> collectRiskCostLines({
  required List<Map<String, String>> risks,
  required Map<String, Map<String, double>> matrixCellExposure,
  List<String> closedStatuses = const ['closed', 'cancelled'],
}) {
  final out = <RiskCostLine>[];

  double cellExposure(String probability, String impact) {
    final p = _normalizeLevel(probability);
    final i = _normalizeLevel(impact);
    return matrixCellExposure[p]?[i] ?? 0;
  }

  for (final risk in risks) {
    final description = (risk['description'] ?? '').trim();
    if (description.isEmpty) continue;

    final status = (risk['status'] ?? '').trim().toLowerCase();
    if (closedStatuses.contains(status)) continue;

    final probability = (risk['probability'] ?? '').trim();
    final impact = (risk['impact'] ?? '').trim();

    final stated = parseRiskAmount(risk['score'] ?? '');
    final total = stated > 0 ? stated : cellExposure(probability, impact);
    if (total <= 0) continue;

    out.add((
      riskId: (risk['id'] ?? '').trim(),
      description: description,
      probability: probability,
      impact: impact,
      total: total,
    ));
  }
  return out;
}

/// Default per-cell exposure for the P×I matrix when the assessor did not
/// state an amount. Ordered Low < Medium < High on both axes; each cell is a
/// share of the project's risk budget that the owner can tune later on the
/// line itself (the pull creates *editable* lines, not a locked total).
const Map<String, Map<String, double>> defaultMatrixCellExposure = {
  'Low': {'Low': 1000, 'Medium': 2500, 'High': 5000},
  'Medium': {'Low': 2500, 'Medium': 10000, 'High': 25000},
  'High': {'Low': 5000, 'Medium': 25000, 'High': 50000},
};

String _normalizeLevel(String value) {
  final lower = value.trim().toLowerCase();
  if (lower.startsWith('h')) return 'High';
  if (lower.startsWith('m')) return 'Medium';
  return 'Low';
}

/// The CostCategory the risk pull writes into.
const CostCategory riskCostCategory = CostCategory.riskAllowance;
