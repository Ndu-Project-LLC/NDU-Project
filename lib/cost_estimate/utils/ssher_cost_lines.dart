/// SSHER → Cost Estimate linkage.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): **"what is the cost
/// aspect for these things? … something very basic, like if it says PPE
/// required, just have a question on the cost for that"** and **"in that share
/// costs … you can have them on the table and say cost items and then
/// estimated costs … that is how we can put our share costs into the cost
/// estimate."**
///
/// Like `risk_cost_lines.dart` and `schedule_work_packages.dart`, this is the
/// pure, testable half: it selects which SSHER items carry a spend and maps
/// each to one `ssher` cost line. The provider moves the data; the Cost
/// Estimate screen renders the pull card. Deterministic, no AI — the assessor
/// ticks "requires a purchase" and types the amount, and code only selects and
/// sums. Nothing is invented for an item nobody priced.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// One SSHER item to be pulled into the estimate, plus the amount it maps to.
typedef SsherCostLine = ({
  String entryId,
  String description,
  String category,
  double total,
});

/// Parse an amount a user may have typed loosely.
///
/// Accepts `12000`, `12,000`, `$12,000`, `12 000` — strips everything that is
/// not a digit or a dot, then parses. Returns 0 when nothing numeric remains,
/// so an empty or placeholder value never becomes a silent zero-cost line.
double parseSsherAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}

/// Collect the SSHER items that should become `ssher` cost lines.
///
/// Rules:
/// - **Purchase only.** An item that does not require a purchase is a control the
///   project already covers, so it carries no line. The owner's framing is the
///   question itself: "if it's something that needs to be bought for the
///   project" — if it isn't, there is nothing to estimate.
/// - **A price is required.** An unpriced purchase is skipped rather than
///   assumed. Zero and unparseable amounts both count as unpriced, mirroring
///   the "amount wins" rule in `risk_cost_lines.dart` in reverse: there, a
///   missing amount falls back to the matrix; here there is no fallback, so the
///   item simply waits until someone prices it.
/// - Blank descriptions are skipped — an unnamed item cannot be estimated or
///   matched later, the same blank-name rule the other pulls use.
/// - `category` is carried through so the line can say which SSHER discipline
///   (safety / security / health / environment / regulatory) it came from.
List<SsherCostLine> collectSsherCostLines({
  required Iterable<SsherEntry> entries,
}) {
  final out = <SsherCostLine>[];

  for (final entry in entries) {
    if (!entry.requiresPurchase) continue;

    final description = entry.concern.trim();
    if (description.isEmpty) continue;

    final total = parseSsherAmount(entry.estimatedCost);
    if (total <= 0) continue;

    out.add((
      entryId: entry.id,
      description: description,
      category: entry.category.trim(),
      total: total,
    ));
  }

  return out;
}

/// The CostCategory the SSHER pull writes into.
const CostCategory ssherCostCategory = CostCategory.ssher;
