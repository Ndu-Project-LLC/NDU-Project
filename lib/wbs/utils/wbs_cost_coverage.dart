/// Cost coverage of WBS leaf work packages.
///
/// Pure helpers (no ChangeNotifier / provider dependencies) that answer the
/// core Cost Estimate question: for every *smallest-level* WBS node — a node
/// with no children — is there a cost line linked to it?
///
/// Product rule (voice note, 2026-09-03): cost belongs at the smallest level
/// of the WBS. Listing every work package that is not yet priced — and letting
/// the user price it by hand — is CORE functionality and must never depend on
/// AI. These helpers power exactly that flow (see the "Unpriced work packages"
/// section in [CostByWBSTab]).
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// A leaf work package (node with no children) that has no priced cost line.
class UnpricedWorkPackage {
  final String nodeId;
  final String code;
  final String name;
  final String? description;

  const UnpricedWorkPackage({
    required this.nodeId,
    required this.code,
    required this.name,
    this.description,
  });
}

/// Snapshot of how completely the WBS leaves have been priced.
class WbsCostCoverage {
  final int totalWorkPackages;
  final int pricedWorkPackages;
  final List<UnpricedWorkPackage> unpriced;

  const WbsCostCoverage({
    required this.totalWorkPackages,
    required this.pricedWorkPackages,
    required this.unpriced,
  });

  bool get hasUnpriced => unpriced.isNotEmpty;

  double get pricedRatio =>
      totalWorkPackages > 0 ? pricedWorkPackages / totalWorkPackages : 0.0;
}

/// All nodes that have no children — the smallest level of the WBS and the
/// level at which work-package costs are estimated. Walks the tree from [root]
/// (normally `wbs.level0`) down through every descendant.
List<WBSNode> collectLeafWorkPackages(WBSNode root) {
  final leaves = <WBSNode>[];
  void walk(WBSNode node) {
    if (node.children.isEmpty) {
      leaves.add(node);
      return;
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(root);
  return leaves;
}

/// True when a cost [line] is linked to [node] — either through the
/// bidirectional link (`costLineIds` contains `line.id`) or through the
/// path reference stored on the line (`line.wbsRef == node.code`).
bool isCostLineLinkedToNode(WBSNode node, CostLine line) {
  final linkedIds = node.costLineIds;
  if (linkedIds != null && linkedIds.contains(line.id)) return true;
  final ref = (line.wbsRef ?? '').trim();
  return ref.isNotEmpty && ref == node.code;
}

/// Whether [line] carries an actual price. Zero-cost placeholder lines
/// (e.g. a WBS shell row with a $0 total) do NOT count as priced — they would
/// silently satisfy coverage while the work package has no estimate.
bool hasMeaningfulCost(CostLine line) {
  if (line.total > 0) return true;
  final qty = line.quantity ?? 0;
  final rate = line.rate ?? 0;
  return qty > 0 && rate > 0;
}

/// Compute leaf-level cost coverage for the WBS tree rooted at [root]
/// (normally `wbs.level0`) against the current cost [lines].
WbsCostCoverage computeWbsCostCoverage({
  required WBSNode root,
  required List<CostLine> lines,
}) {
  final leaves = collectLeafWorkPackages(root);
  final pricedIds = <String>{};

  // Pre-index lines by the WBS codes they reference (trimmed, non-empty).
  final linesByRefCode = <String, List<CostLine>>{};
  for (final line in lines) {
    if (!hasMeaningfulCost(line)) continue;
    final ref = (line.wbsRef ?? '').trim();
    if (ref.isNotEmpty) {
      linesByRefCode.putIfAbsent(ref, () => []).add(line);
    }
  }

  final unpriced = <UnpricedWorkPackage>[];
  for (final leaf in leaves) {
    var priced = false;
    final linkedIds = leaf.costLineIds;
    if (linkedIds != null) {
      for (final line in lines) {
        if (linkedIds.contains(line.id) && hasMeaningfulCost(line)) {
          priced = true;
          break;
        }
      }
    }
    if (!priced) {
      final refLines = linesByRefCode[leaf.code];
      if (refLines != null && refLines.isNotEmpty) priced = true;
    }
    if (priced) {
      pricedIds.add(leaf.id);
    } else {
      unpriced.add(UnpricedWorkPackage(
        nodeId: leaf.id,
        code: leaf.code,
        name: leaf.name,
        description: leaf.description,
      ));
    }
  }

  return WbsCostCoverage(
    totalWorkPackages: leaves.length,
    pricedWorkPackages: pricedIds.length,
    unpriced: unpriced,
  );
}
