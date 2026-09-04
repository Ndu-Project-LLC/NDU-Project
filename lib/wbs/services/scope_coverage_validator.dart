// ignore_for_file: avoid_print

import 'package:ndu_project/wbs/models/wbs_models.dart';

/// ─── Phase 1: Scope → WBS integration ────────────────────────────────
///
/// Implements the PMI Practice Standard for WBS 100% Rule:
///   > "The WBS includes 100% of the work defined by the scope statement
///   > and captures ALL deliverables — internal, external, and interim —
///   > in terms of the work activities required to complete them."
///
/// Practically, the rule cuts both ways:
///   • Every scope item should trace to at least one WBS node.
///     (Otherwise: scope is "missing" from the WBS → coverage gap.)
///   • Every WBS leaf (work package) should ideally trace to a scope item.
///     (Otherwise: WBS contains "orphan work" not in scope → scope creep.)
///
/// This validator also flags work-package WBS nodes whose WBS Dictionary
/// entry is incomplete (missing deliverableDescription, acceptanceCriteria,
/// or workPackageDefinition) — these are the per-WP scope statements that
/// prove the 100% Rule is satisfied at the leaf level.
///
/// The validator is **pure** — it takes snapshots and returns a report,
/// without modifying any state. Callers (UI, integration dashboard, IBR
/// gate) decide what to do with the report.

/// A single scope-tracking item used as input to the validator.
///
/// We accept a minimal DTO rather than the full `ScopeTrackingItem` so the
/// validator doesn't import the legacy `models/` layer. Callers convert
/// their scope items (legacy `ScopeTrackingItem` or otherwise) into this
/// DTO at the call site.
class ScopeCoverageInput {
  final String id;
  final String description;
  final String? wbsNodeId;
  final String? wbsCode;

  const ScopeCoverageInput({
    required this.id,
    required this.description,
    this.wbsNodeId,
    this.wbsCode,
  });
}

/// Per-item coverage result.
class ScopeItemCoverage {
  final ScopeCoverageInput item;
  final WBSNode? matchedNode;
  final bool isCovered;

  const ScopeItemCoverage({
    required this.item,
    required this.matchedNode,
    required this.isCovered,
  });
}

/// Per-WBS-leaf coverage result.
class WbsLeafCoverage {
  final WBSNode node;
  final bool hasDictionaryEntry;
  final int linkedScopeItemCount;
  final bool isOrphan;

  const WbsLeafCoverage({
    required this.node,
    required this.hasDictionaryEntry,
    required this.linkedScopeItemCount,
    required this.isOrphan,
  });
}

/// The full coverage report.
class ScopeCoverageReport {
  /// One entry per scope item — was it found in the WBS?
  final List<ScopeItemCoverage> scopeItems;

  /// One entry per WBS leaf (work-package node).
  final List<WbsLeafCoverage> wbsLeaves;

  /// Scope items that don't trace to any WBS node.
  final List<ScopeCoverageInput> uncoveredScopeItems;

  /// WBS leaves that don't trace back to any scope item.
  final List<WBSNode> orphanWbsLeaves;

  /// WBS leaves whose dictionary entry is incomplete.
  final List<WBSNode> incompleteDictionaryLeaves;

  const ScopeCoverageReport({
    required this.scopeItems,
    required this.wbsLeaves,
    required this.uncoveredScopeItems,
    required this.orphanWbsLeaves,
    required this.incompleteDictionaryLeaves,
  });

  /// Total scope items considered.
  int get totalScopeItems => scopeItems.length;

  /// Scope items that trace to at least one WBS node.
  int get coveredScopeItemCount =>
      scopeItems.where((c) => c.isCovered).length;

  /// 0–100 scope coverage ratio.
  double get scopeCoverageRatio => totalScopeItems == 0
      ? 0
      : coveredScopeItemCount / totalScopeItems;

  /// Total WBS leaves (work packages).
  int get totalWbsLeaves => wbsLeaves.length;

  /// WBS leaves with at least one scope item linking back to them.
  int get tracedLeafCount =>
      wbsLeaves.where((l) => !l.isOrphan).length;

  /// 0–100 WBS-leaf-trace ratio (how much of the WBS traces to scope).
  double get wbsLeafTraceRatio => totalWbsLeaves == 0
      ? 0
      : tracedLeafCount / totalWbsLeaves;

  /// WBS leaves with a complete dictionary entry.
  int get completeDictionaryCount =>
      wbsLeaves.where((l) => l.hasDictionaryEntry).length;

  /// 0–100 dictionary completeness ratio.
  double get dictionaryCompletenessRatio => totalWbsLeaves == 0
      ? 0
      : completeDictionaryCount / totalWbsLeaves;

  /// Overall 100%-Rule satisfaction gate.
  ///
  /// True when:
  ///   • scopeCoverageRatio == 1.0 (every scope item is in the WBS), AND
  ///   • wbsLeafTraceRatio >= 0.8 (most WBS leaves trace back to scope —
  ///     we allow 20% slack for project-management / interim deliverables
  ///     that legitimately appear in the WBS without an explicit scope
  ///     statement), AND
  ///   • dictionaryCompletenessRatio == 1.0 (every work package has its
  ///     dictionary entry — the literal scope statement per WP).
  bool get hundredPercentRuleSatisfied =>
      scopeCoverageRatio == 1.0 &&
      wbsLeafTraceRatio >= 0.8 &&
      dictionaryCompletenessRatio == 1.0;

  /// Overall IBR-style readiness score (0–100).
  ///
  /// Weighted blend of the three ratios. Used by the Integration
  /// Dashboard and the IBR gate to surface a single number.
  double get readinessScore {
    if (totalScopeItems == 0 && totalWbsLeaves == 0) return 0;
    return (scopeCoverageRatio * 40 +
        wbsLeafTraceRatio * 30 +
        dictionaryCompletenessRatio * 30);
  }
}

class ScopeCoverageValidator {
  /// Run the 100%-Rule analysis against the given WBS tree + scope items.
  ///
  /// [wbs] — the full WBS tree (root + recursive children).
  /// [scopeItems] — list of scope-tracking items, each optionally
  ///   linked to a WBS node by `wbsNodeId` or by `wbsCode`.
  ///
  /// Returns a [ScopeCoverageReport] containing per-item, per-leaf,
  /// and aggregate coverage metrics.
  static ScopeCoverageReport validate({
    required WBS wbs,
    required List<ScopeCoverageInput> scopeItems,
  }) {
    // Build lookup maps from the WBS tree.
    final nodeById = <String, WBSNode>{};
    final nodeByCode = <String, WBSNode>{};
    final leaves = <WBSNode>[];

    void walk(WBSNode node) {
      nodeById[node.id] = node;
      if (node.code.isNotEmpty) {
        nodeByCode[node.code] = node;
      }
      if (node.children.isEmpty && node.level != WBSLevel.level0) {
        leaves.add(node);
      }
      for (final c in node.children) {
        walk(c);
      }
    }

    walk(wbs.level0);

    // Per-scope-item coverage.
    final scopeItemResults = <ScopeItemCoverage>[];
    final uncovered = <ScopeCoverageInput>[];
    for (final item in scopeItems) {
      WBSNode? matched;
      if (item.wbsNodeId != null && item.wbsNodeId!.isNotEmpty) {
        matched = nodeById[item.wbsNodeId];
      }
      matched ??= (item.wbsCode != null && item.wbsCode!.isNotEmpty)
          ? nodeByCode[item.wbsCode]
          : null;
      final covered = matched != null;
      scopeItemResults.add(ScopeItemCoverage(
        item: item,
        matchedNode: matched,
        isCovered: covered,
      ));
      if (!covered) uncovered.add(item);
    }

    // Per-leaf coverage (build reverse-link count).
    final leafLinkCount = <String, int>{};
    for (final item in scopeItems) {
      final matched = item.wbsNodeId != null && item.wbsNodeId!.isNotEmpty
          ? nodeById[item.wbsNodeId]
          : (item.wbsCode != null && item.wbsCode!.isNotEmpty
              ? nodeByCode[item.wbsCode]
              : null);
      if (matched != null) {
        leafLinkCount[matched.id] = (leafLinkCount[matched.id] ?? 0) + 1;
      }
    }

    final leafResults = <WbsLeafCoverage>[];
    final orphans = <WBSNode>[];
    final incompleteDict = <WBSNode>[];
    for (final leaf in leaves) {
      final linked = leafLinkCount[leaf.id] ?? 0;
      final hasDict = leaf.hasWbsDictionaryEntry;
      final isOrphan = linked == 0;
      leafResults.add(WbsLeafCoverage(
        node: leaf,
        hasDictionaryEntry: hasDict,
        linkedScopeItemCount: linked,
        isOrphan: isOrphan,
      ));
      if (isOrphan) orphans.add(leaf);
      if (!hasDict) incompleteDict.add(leaf);
    }

    return ScopeCoverageReport(
      scopeItems: scopeItemResults,
      wbsLeaves: leafResults,
      uncoveredScopeItems: uncovered,
      orphanWbsLeaves: orphans,
      incompleteDictionaryLeaves: incompleteDict,
    );
  }
}
