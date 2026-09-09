/// Cost rollup for a single WBS node — the canonical, reusable shape for
/// "how much cost is associated with this node?".
///
/// Lives in its own file so it can be imported by both [WBSProvider] (which
/// produces rollups) and consumers like [CostByWBSTab] (which render them)
/// without dragging the full provider into a circular import.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// Immutable snapshot of cost information for a single [WBSNode].
///
/// - [directCost]   = sum of [CostLine.total] for lines linked *directly*
///                    to this node (via [WBSNode.costLineIds] or
///                    [CostLine.wbsRef] == [WBSNode.code]).
/// - [rolledUpCost] = [directCost] + the rolled-up cost of every descendant
///                    node. This is the number to display next to an L1
///                    deliverable when its L2/L3 children have their own
///                    cost lines.
/// - [directLines]  = the actual [CostLine] objects linked to this node,
///                    so consumers can render a breakdown list without
///                    re-walking the estimate.
class WBSNodeCostRollup {
  final WBSNode node;
  final double directCost;
  final double rolledUpCost;
  final int directLineCount;
  final int rolledUpLineCount;
  final List<CostLine> directLines;

  const WBSNodeCostRollup({
    required this.node,
    required this.directCost,
    required this.rolledUpCost,
    required this.directLineCount,
    required this.rolledUpLineCount,
    required this.directLines,
  });

  /// True if this node (or any descendant) has at least one linked cost
  /// line with a non-zero total.
  bool get hasCost => rolledUpCost > 0 || rolledUpLineCount > 0;

  /// True if THIS node has directly-linked cost lines (excluding
  /// descendants). Useful for showing a "linked" badge only at the level
  /// where the linkage actually exists.
  bool get isDirectlyLinked => directLineCount > 0;

  /// The fraction of [rolledUpCost] that comes from this node's own direct
  /// lines (0.0 – 1.0). 0 when [rolledUpCost] == 0.
  double get directFraction =>
      rolledUpCost > 0 ? (directCost / rolledUpCost).clamp(0.0, 1.0) : 0.0;
}
