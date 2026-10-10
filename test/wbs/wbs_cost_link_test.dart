// End-to-end tests for the Cost ↔ WBS linkage behind the "Cost by WBS" tab.
//
// The tab claims to be a pure consumer of WBSProvider.computeCostRollup and
// deliberately does NOT re-walk the estimate itself. These tests hold it to
// that: they build a real WBS tree and real cost lines through the providers'
// own public APIs, then check three things agree —
//
//   1. the canonical rollup (computeCostRollup / getCostRollupsForL1),
//   2. the link mutators (linkCostLine / unlinkCostLine / autoLinkCostLines),
//   3. the "is this line linked?" rule the tab derives from flattenWBS paths.
//
// (3) matters because the tab matches `wbsRef` against FlattenedWBSNode.path
// while the rollup matches it against `node.code`. If those ever diverge, the
// KPI band and the per-node rows would report different money.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

CostLine costLine(
  String id,
  double total, {
  String? wbsRef,
  String description = 'line',
  CostCategory category = CostCategory.materials,
  VarianceType? varianceType,
  double? varianceDelta,
  double? varianceBaselineTotal,
}) {
  return CostLine(
    id: id,
    category: category,
    subCategory: '',
    description: description,
    wbsRef: wbsRef,
    total: total,
    inSchedule: false,
    basisSource: CostSourceType.expertJudgment,
    aiGenerated: false,
    varianceType: varianceType,
    varianceDelta: varianceDelta,
    varianceBaselineTotal: varianceBaselineTotal,
  );
}

/// A provider with storage loaded, so `setup()` is no longer gated.
Future<WBSProvider> newWbsProvider() async {
  final provider = WBSProvider();
  for (var i = 0; i < 100 && provider.isLoadingFromStorage; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  provider.setup(
    projectName: 'Test Project',
    framework: WBSFramework.waterfallDeliverable,
  );
  return provider;
}

CostEstimateProvider newCostProvider() {
  final provider = CostEstimateProvider();
  provider.setup(
    projectName: 'Test Project',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
  );
  return provider;
}

/// The tab's own "is this line linked to the WBS?" rule, replicated verbatim:
/// linked when any FlattenedWBSNode.path equals the line's trimmed wbsRef, or
/// when any node lists the line id in costLineIds.
Set<String> tabLinkedIds(WBS wbs, List<CostLine> lines) {
  final ids = <String>{};
  void collect(WBSNode n) {
    for (final id in (n.costLineIds ?? const <String>[])) {
      ids.add(id);
    }
    for (final c in n.children) {
      collect(c);
    }
  }

  collect(wbs.level0);

  final paths = <String>{};
  for (final flat in flattenWBS(wbs)) {
    if (flat.path.isNotEmpty) paths.add(flat.path);
  }
  for (final line in lines) {
    final ref = (line.wbsRef ?? '').trim();
    if (ref.isNotEmpty && paths.contains(ref)) ids.add(line.id);
  }
  return ids;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('computeCostRollup — the canonical matching rule', () {
    test('links a line listed in the node costLineIds', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      wbs.linkCostLine(l1, 'line_a');
      final rollup = wbs.computeCostRollup(
        wbs.findNode(l1)!,
        [costLine('line_a', 500)],
      );

      expect(rollup.directCost, 500);
      expect(rollup.directLineCount, 1);
      expect(rollup.isDirectlyLinked, isTrue);
    });

    test('links a line whose wbsRef equals the node code', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final code = wbs.findNode(l1)!.code;

      final rollup = wbs.computeCostRollup(
        wbs.findNode(l1)!,
        [costLine('line_a', 750, wbsRef: code)],
      );

      expect(rollup.directCost, 750);
      expect(rollup.isDirectlyLinked, isTrue);
    });

    test('trims whitespace around the wbsRef before matching', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final code = wbs.findNode(l1)!.code;

      final rollup = wbs.computeCostRollup(
        wbs.findNode(l1)!,
        [costLine('line_a', 100, wbsRef: '  $code  ')],
      );

      expect(rollup.directCost, 100);
    });

    test('a wbsRef pointing at a sibling node does not leak in', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final l2 = wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

      final rollup = wbs.computeCostRollup(
        wbs.findNode(l1)!,
        [costLine('line_b', 900, wbsRef: wbs.findNode(l2)!.code)],
      );

      expect(rollup.directCost, 0);
      expect(rollup.directLineCount, 0);
    });

    test('a line with no wbsRef and no costLineIds matches nothing', () async {
      final wbs = await newWbsProvider();
      wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      final rollups = wbs.getCostRollupsForL1([costLine('orphan', 400)]);
      expect(rollups.first.directCost, 0);
      expect(rollups.first.rolledUpCost, 0);
    });

    test('descendant costs roll up while directCost stays local', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final l2 = wbs.addChildNode(l1, 'Process Design');
      final l3 = wbs.addChildNode(l2, 'P&ID Package');

      wbs.linkCostLine(l1, 'l1_line');
      wbs.linkCostLine(l3, 'l3_line');

      final rollup = wbs.computeCostRollup(wbs.findNode(l1)!, [
        costLine('l1_line', 1000),
        costLine('l3_line', 250),
      ]);

      expect(rollup.directCost, 1000);
      expect(rollup.directLineCount, 1);
      expect(rollup.rolledUpCost, 1250);
      expect(rollup.rolledUpLineCount, 2);
    });

    test('honours the variance rules the cost side uses', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      wbs.linkCostLine(l1, 'base');
      wbs.linkCostLine(l1, 'removed');
      wbs.linkCostLine(l1, 'changed');

      final rollup = wbs.computeCostRollup(wbs.findNode(l1)!, [
        costLine('base', 1000),
        costLine('removed', 0,
            varianceType: VarianceType.remove, varianceBaselineTotal: 300),
        costLine('changed', 9999,
            varianceType: VarianceType.change, varianceDelta: 250),
      ]);

      // 1000 - 300 + 250
      expect(rollup.directCost, 950);
    });

    test('getCostRollupsForL1 returns one rollup per L1 deliverable', () async {
      final wbs = await newWbsProvider();
      final a = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final b = wbs.addChildNode(wbs.wbs!.level0.id, 'Procurement');

      wbs.linkCostLine(a, 'la');
      wbs.linkCostLine(b, 'lb');

      final rollups = wbs.getCostRollupsForL1([
        costLine('la', 100),
        costLine('lb', 60),
      ]);

      expect(rollups.length, 2);
      expect(rollups.map((r) => r.node.code), ['G1', 'G2']);
      // L1 subtrees are disjoint, so summing them cannot double-count.
      expect(rollups.fold<double>(0, (s, r) => s + r.rolledUpCost), 160);
    });
  });

  group('linkCostLine / unlinkCostLine', () {
    test('unlinkCostLine removes exactly the requested link', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      wbs.linkCostLine(l1, 'keep');
      wbs.linkCostLine(l1, 'drop');
      wbs.unlinkCostLine(l1, 'drop');

      expect(wbs.findNode(l1)!.costLineIds, ['keep']);
    });

    test('linking the same pair twice does not duplicate the link', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      wbs.linkCostLine(l1, 'line_a');
      wbs.linkCostLine(l1, 'line_a');

      expect(wbs.findNode(l1)!.costLineIds, ['line_a']);
    });

    test('a duplicated link cannot double-count the cost either way', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');

      wbs.linkCostLine(l1, 'line_a');
      wbs.linkCostLine(l1, 'line_a');

      final rollup =
          wbs.computeCostRollup(wbs.findNode(l1)!, [costLine('line_a', 100)]);
      // Rollups filter the *lines*, so cost is safe regardless of id dupes.
      expect(rollup.directCost, 100);
      expect(rollup.rolledUpLineCount, 1);
    });
  });

  group('autoLinkCostLines', () {
    test('strong signal — wbsRef matching a node code', () async {
      final wbs = await newWbsProvider();
      final l2 = wbs.addChildNode(
          wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering'), 'Process Design');
      final code = wbs.findNode(l2)!.code;

      final ce = newCostProvider()
        ..addLine(costLine('line_a', 500, wbsRef: code));

      expect(wbs.autoLinkCostLines(ce), 1);
      expect(wbs.findNode(l2)!.costLineIds, contains('line_a'));
    });

    test('weak signal — node name contained in the line description', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Process Design');

      final ce = newCostProvider()
        ..addLine(costLine('line_a', 500,
            description: 'Detailed process design package'));

      expect(wbs.autoLinkCostLines(ce), 1);
      expect(wbs.findNode(l1)!.costLineIds, contains('line_a'));
    });

    test('weak signal is skipped for short names that would false-positive',
        () async {
      final wbs = await newWbsProvider();
      wbs.addChildNode(wbs.wbs!.level0.id, 'Ops');

      final ce = newCostProvider()
        ..addLine(costLine('line_a', 500, description: 'Operations support'));

      expect(wbs.autoLinkCostLines(ce), 0);
    });

    test('an explicit but unmatched wbsRef is not second-guessed by name',
        () async {
      final wbs = await newWbsProvider();
      wbs.addChildNode(wbs.wbs!.level0.id, 'Process Design');

      final ce = newCostProvider()
        ..addLine(costLine('line_a', 500,
            wbsRef: 'G9.9', description: 'Detailed process design package'));

      expect(wbs.autoLinkCostLines(ce), 0);
    });

    test('is idempotent — a second run creates no new links', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Process Design');

      final ce = newCostProvider()
        ..addLine(costLine('line_a', 500,
            description: 'Detailed process design package'));

      expect(wbs.autoLinkCostLines(ce), 1);
      expect(wbs.autoLinkCostLines(ce), 0);
      expect(wbs.findNode(l1)!.costLineIds, ['line_a']);
    });

    test('does nothing when there is no estimate', () async {
      final wbs = await newWbsProvider();
      wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      expect(wbs.autoLinkCostLines(CostEstimateProvider()), 0);
    });
  });

  group('the tab stays consistent with the rollup', () {
    test('flattened paths equal node codes, so both rules pick the same lines',
        () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final l2 = wbs.addChildNode(l1, 'Process Design');
      final l3 = wbs.addChildNode(l2, 'P&ID Package');

      final wbsData = wbs.wbs!;
      final paths = flattenWBS(wbsData)
          .map((f) => f.path)
          .where((p) => p.isNotEmpty)
          .toSet();
      final codes = <String>{};
      void collect(WBSNode n) {
        if (n.code.isNotEmpty) codes.add(n.code);
        for (final c in n.children) {
          collect(c);
        }
      }

      collect(wbsData.level0);
      expect(paths, codes, reason: 'tab matches paths, rollup matches codes');

      final lines = [
        costLine('via_ref_l3', 100, wbsRef: wbs.findNode(l3)!.code),
        costLine('via_ref_l1', 100, wbsRef: wbs.findNode(l1)!.code),
      ];

      final tabIds = tabLinkedIds(wbsData, lines);
      expect(tabIds, {'via_ref_l3', 'via_ref_l1'});

      // Every line the tab calls "linked" is reachable by some node's rollup.
      final reachable = <String>{};
      for (final r in wbs.getCostRollupsForL1(lines)) {
        for (final l in r.directLines) {
          reachable.add(l.id);
        }
        void descend(WBSNode n) {
          for (final l in wbs.computeCostRollup(n, lines).directLines) {
            reachable.add(l.id);
          }
          for (final c in n.children) {
            descend(c);
          }
        }

        descend(r.node);
      }

      expect(reachable.containsAll(tabIds), isTrue);
    });

    test('a line linked to a deep node is counted once up the chain', () async {
      final wbs = await newWbsProvider();
      final l1 = wbs.addChildNode(wbs.wbs!.level0.id, 'Engineering');
      final l2 = wbs.addChildNode(l1, 'Process Design');
      final l3 = wbs.addChildNode(l2, 'P&ID Package');

      wbs.linkCostLine(l3, 'deep');
      final lines = [costLine('deep', 400, category: CostCategory.labor)];

      expect(wbs.computeCostRollup(wbs.findNode(l3)!, lines).rolledUpCost, 400);
      expect(wbs.computeCostRollup(wbs.findNode(l2)!, lines).rolledUpCost, 400);
      expect(wbs.computeCostRollup(wbs.findNode(l1)!, lines).rolledUpCost, 400);

      final l1Sum = wbs
          .getCostRollupsForL1(lines)
          .fold<double>(0, (s, r) => s + r.rolledUpCost);
      expect(l1Sum, 400);
    });
  });
}
