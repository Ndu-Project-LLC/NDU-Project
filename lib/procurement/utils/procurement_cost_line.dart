/// Procurement item → Cost Estimate line, and the WBS node it belongs to.
///
///
/// Product rule (voice note, 2026-09-10):
///
/// > "[fix] the scope value to move from procurement to scope details"
///
/// A procurement item's budget is scope money. When the item is linked to a WBS
/// package, that value has to become a real Cost Estimate line, referenced by
/// the package, so the WBS module, the Cost Estimate overview and Cost by WBS
/// all read the same number. Writing only the legacy project blob (what the
/// screen used to do) moved the value nowhere those views could see it.
///
/// Pure and dependency-free — the provider does the writing, this decides
/// *what* to write.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// Whether a screen bound to [boundProjectId] should now bind to [projectId].
///
/// This is the rule behind the Planning Procurement page's data binding, and it
/// exists because the page used a one-shot `_didInitialize` flag: opened before
/// the project data arrived, it latched an empty project id and never
/// subscribed to anything, so every tab stayed empty for the session
/// ("nothing is working … just everything else on the page").
///
/// Keying on the *bound project* instead means an empty id is simply "nothing to
/// do yet" — it never latches — and a project arriving later (or a project
/// switch) binds correctly.
bool shouldBindProject({
  required String? boundProjectId,
  required String projectId,
}) {
  final target = projectId.trim();
  if (target.isEmpty) return false;
  return target != (boundProjectId ?? '').trim();
}

/// Stable back-reference for the line a procurement item produces.
///
/// Stamped on the line so re-running the pull refreshes the one line instead of
/// stacking a duplicate every time.
String procurementCostReference(String procurementItemId) =>
    'procurement:${procurementItemId.trim()}';

/// The Cost Estimate line that carries [item]'s budget.
///
/// [wbsRef] is the dotted WBS code the line is filed under, so it also matches
/// the WBS rollup's `wbsRef == node.code` rule. Pass [existingLineId] to update
/// the line already produced for this item rather than creating a new one.
CostLine procurementItemCostLine({
  required ProcurementItemModel item,
  String? wbsRef,
  String? existingLineId,
}) {
  final code = (wbsRef ?? '').trim();
  final category = item.category.trim();

  return CostLine(
    id: (existingLineId ?? '').trim().isEmpty
        ? newId('src_procurement')
        : existingLineId!.trim(),
    category: CostCategory.procurement,
    subCategory: category,
    description: item.name.trim(),
    wbsRef: code.isEmpty ? null : code,
    // The item's own budget is the scope value being moved across.
    total: item.budget,
    // Only claim a schedule slot when the item actually has a delivery date.
    inSchedule: item.estimatedDelivery != null,
    basisSource: CostSourceType.expertJudgment,
    basisReference: procurementCostReference(item.id),
    aiGenerated: false,
  );
}

/// Finds the WBS node carrying [code], or `null` when the tree has none.
///
/// The legacy `wbsTree` work item a procurement item is linked to and the WBS
/// module's node are not guaranteed to share an id, but they do share the
/// dotted code — so the code is what the link is resolved on.
WBSNode? findWbsNodeByCode(WBS? wbs, String code) {
  final target = code.trim();
  if (wbs == null || target.isEmpty) return null;

  WBSNode? search(WBSNode node) {
    if (node.code.trim() == target) return node;
    for (final child in node.children) {
      final hit = search(child);
      if (hit != null) return hit;
    }
    return null;
  }

  return search(wbs.level0);
}
