/// Quality → Cost Estimate linkage.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): **"quality is not
/// done … the quality costs must reach the cost estimate."** and, on the same
/// walkthrough, **"these are the costs that we are incurring because we are not
/// doing quality right."**
///
/// The Cost of Quality capture (prevention, appraisal, internal failure,
/// external failure) and `CostOfQualityService` already existed on the branch
/// but were unreachable: `ProjectDataModel` had never carried the
/// `costOfQualityData` field, so nothing could be stored and no screen could
/// read it. That field is now ported, and this is the pure half of the link —
/// selection rules, no I/O — in the same shape as `ssher_cost_lines.dart` and
/// `risk_cost_lines.dart`.
///
/// Nothing is invented: an entry moves only when someone has priced it.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/models/cost_of_quality.dart';

/// The four Cost of Quality categories, in the order they are reported.
const List<String> qualityCostCategories = [
  'Prevention',
  'Appraisal',
  'Internal Failure',
  'External Failure',
];

/// One Cost of Quality entry selected for the estimate.
typedef QualityCostLine = ({
  String entryId,
  String description,
  String category,
  String scope,
  double total,
});

/// The amount to carry for one CoQ entry.
///
/// **Actual wins when it is recorded.** Once the real spend is known it is the
/// truth, and the estimate should reflect what quality actually cost rather
/// than what it was hoped to cost. Until then the estimate stands.
double qualityEntryAmount(CoQEntry entry) {
  if (entry.actualCost > 0) return entry.actualCost;
  return entry.estimatedCost;
}

/// Collect the CoQ entries that should become `quality` cost lines.
///
/// Rules:
/// - **Priced only.** An entry with neither an estimate nor an actual is
///   skipped rather than counted as zero, so it stays visible as missing work
///   instead of quietly deflating the quality total.
/// - **Named only.** A blank description cannot be estimated, matched or
///   traced later — the same blank-name rule the other pulls use.
/// - **Category is carried through**, because prevention and external failure
///   are opposite ends of the same story: one is money spent to avoid defects,
///   the other is money lost to them. Flattening them into a single "quality"
///   figure would hide exactly what the owner was pointing at.
List<QualityCostLine> collectQualityCostLines({
  required CostOfQualityData? data,
}) {
  if (data == null) return const [];

  final buckets = <String, List<CoQEntry>>{
    'Prevention': data.preventionCosts,
    'Appraisal': data.appraisalCosts,
    'Internal Failure': data.internalFailureCosts,
    'External Failure': data.externalFailureCosts,
  };

  final out = <QualityCostLine>[];
  for (final category in qualityCostCategories) {
    for (final entry in buckets[category] ?? const <CoQEntry>[]) {
      final description = entry.description.trim();
      if (description.isEmpty) continue;

      final total = qualityEntryAmount(entry);
      if (total <= 0) continue;

      out.add((
        entryId: entry.id,
        description: description,
        category: category,
        scope: entry.scope.trim(),
        total: total,
      ));
    }
  }
  return out;
}

/// Every captured Cost of Quality entry, in report order.
///
/// Unpriced entries included — this is what the Cost Estimate card counts to
/// say how many entries are still waiting on a price, so they are not silently
/// dropped on the way to the estimate.
List<CoQEntry> collectQualityEntries({required CostOfQualityData? data}) {
  if (data == null) return const [];

  final buckets = <String, List<CoQEntry>>{
    'Prevention': data.preventionCosts,
    'Appraisal': data.appraisalCosts,
    'Internal Failure': data.internalFailureCosts,
    'External Failure': data.externalFailureCosts,
  };

  final out = <CoQEntry>[];
  for (final category in qualityCostCategories) {
    for (final entry in buckets[category] ?? const <CoQEntry>[]) {
      if (entry.description.trim().isEmpty) continue;
      out.add(entry);
    }
  }
  return out;
}

/// The CostCategory the quality pull writes into.
const CostCategory qualityCostCategory = CostCategory.quality;
