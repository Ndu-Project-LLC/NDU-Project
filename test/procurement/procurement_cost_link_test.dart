// Tests for the procurement → scope money bridge behind the Planning
// Procurement page (voice note, 2026-09-10):
//
//   "nothing is working, the tags, the scope value to move from procurement to
//    scope details, procurement workflow, and just everything else on the page"
//
// Two things are pinned here:
//
//   1. The scope value actually becomes a Cost Estimate line filed under the
//      WBS package — and re-running the pull refreshes that one line instead of
//      stacking duplicates. Writing only the legacy project blob (what the page
//      used to do) moved the value nowhere the WBS / Cost Estimate / Cost by WBS
//      views could read it.
//   2. The page's project binding is keyed on the bound project, not on a
//      one-shot "did initialise" flag. The old flag meant a page opened before
//      the project loaded latched an empty id and never subscribed to anything,
//      leaving every tab empty for the session.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/procurement/utils/procurement_cost_line.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

ProcurementItemModel item({
  String id = 'itm_1',
  String name = 'CPE Equipment',
  double budget = 125000,
  String category = 'Equipment',
  DateTime? estimatedDelivery,
}) {
  final now = DateTime(2026, 9, 10);
  return ProcurementItemModel(
    id: id,
    projectId: 'proj_1',
    name: name,
    description: 'Core network equipment',
    category: category,
    budget: budget,
    estimatedDelivery: estimatedDelivery,
    createdAt: now,
    updatedAt: now,
  );
}

WBS wbsWith(List<WBSNode> level1) {
  final now = DateTime(2026, 9, 10);
  return WBS(
    id: 'wbs_1',
    projectId: 'proj_1',
    projectName: 'Lusaka',
    framework: WBSFramework.waterfallDeliverable,
    level0: WBSNode(
      id: 'root',
      level: WBSLevel.level0,
      code: '0',
      name: 'Lusaka',
      aiGenerated: false,
      children: level1,
    ),
    aiSuggestions: const [],
    createdAt: now,
    updatedAt: now,
  );
}

WBSNode node(
  String id,
  String code,
  String name, {
  List<WBSNode> children = const [],
}) {
  return WBSNode(
    id: id,
    level: WBSLevel.level1,
    code: code,
    name: name,
    aiGenerated: false,
    children: children,
  );
}

void main() {
  group('procurementItemCostLine', () {
    test('carries the item budget as a procurement line under the WBS code',
        () {
      final line = procurementItemCostLine(
        item: item(),
        wbsRef: '1.2',
      );

      expect(line.total, 125000);
      expect(line.category, CostCategory.procurement);
      expect(line.subCategory, 'Equipment');
      expect(line.description, 'CPE Equipment');
      expect(line.wbsRef, '1.2');
      expect(line.aiGenerated, isFalse);
    });

    test('stamps a stable back-reference so the pull can be repeated', () {
      final first = procurementItemCostLine(item: item(), wbsRef: '1.2');
      final again = procurementItemCostLine(
        item: item(),
        wbsRef: '1.2',
        existingLineId: first.id,
      );

      expect(again.basisReference, 'procurement:itm_1');
      expect(again.basisReference, first.basisReference);
      // Refreshing reuses the line the item already produced.
      expect(again.id, first.id);
    });

    test('re-keying the item to another package keeps the same line id', () {
      final first = procurementItemCostLine(item: item(), wbsRef: '1.2');
      final moved = procurementItemCostLine(
        item: item(),
        wbsRef: '2.4',
        existingLineId: first.id,
      );

      expect(moved.id, first.id);
      expect(moved.wbsRef, '2.4');
    });

    test('only claims a schedule slot when the item has a delivery date', () {
      expect(
        procurementItemCostLine(item: item(), wbsRef: '1.2').inSchedule,
        isFalse,
      );
      expect(
        procurementItemCostLine(
          item: item(estimatedDelivery: DateTime(2026, 11, 1)),
          wbsRef: '1.2',
        ).inSchedule,
        isTrue,
      );
    });

    test('omits the WBS reference when the package has no code', () {
      expect(procurementItemCostLine(item: item(), wbsRef: '  ').wbsRef, isNull);
      expect(procurementItemCostLine(item: item()).wbsRef, isNull);
    });

    test('an item that is not yet priced still produces a zero-total line', () {
      final line = procurementItemCostLine(item: item(budget: 0), wbsRef: '1');
      expect(line.total, 0);
      expect(line.basisReference, 'procurement:itm_1');
    });
  });

  group('procurementCostReference', () {
    test('is derived from the item id and trimmed', () {
      expect(procurementCostReference(' itm_7 '), 'procurement:itm_7');
    });
  });

  group('findWbsNodeByCode', () {
    test('finds an L1 node by its dotted code', () {
      final wbs = wbsWith([node('n1', '1', 'Engineering')]);
      expect(findWbsNodeByCode(wbs, '1')?.id, 'n1');
    });

    test('walks into deeper levels', () {
      final wbs = wbsWith([
        node('n1', '1', 'Engineering', children: [
          node('n2', '1.1', 'Process Design', children: [
            node('n3', '1.1.1', 'P&ID Package'),
          ]),
        ]),
      ]);

      expect(findWbsNodeByCode(wbs, '1.1.1')?.id, 'n3');
    });

    test('trims the code before matching', () {
      final wbs = wbsWith([node('n1', '1', 'Engineering')]);
      expect(findWbsNodeByCode(wbs, '  1  ')?.id, 'n1');
    });

    test('returns null for an unknown code, an empty code or no WBS', () {
      final wbs = wbsWith([node('n1', '1', 'Engineering')]);
      expect(findWbsNodeByCode(wbs, '9.9'), isNull);
      expect(findWbsNodeByCode(wbs, '   '), isNull);
      expect(findWbsNodeByCode(null, '1'), isNull);
    });
  });

  group('shouldBindProject', () {
    test('binds a project that arrives after the first frame', () {
      // The old one-shot flag returned false here for the rest of the session,
      // which is what left every tab empty.
      expect(shouldBindProject(boundProjectId: null, projectId: 'p1'), isTrue);
    });

    test('an empty id does not latch — the next call still binds', () {
      expect(shouldBindProject(boundProjectId: null, projectId: ''), isFalse);
      expect(shouldBindProject(boundProjectId: null, projectId: 'p1'), isTrue);
    });

    test('does not re-bind the project it is already bound to', () {
      expect(shouldBindProject(boundProjectId: 'p1', projectId: 'p1'), isFalse);
      expect(shouldBindProject(boundProjectId: 'p1', projectId: ' p1 '), isFalse);
    });

    test('binds when the active project changes', () {
      expect(shouldBindProject(boundProjectId: 'p1', projectId: 'p2'), isTrue);
    });
  });
}
