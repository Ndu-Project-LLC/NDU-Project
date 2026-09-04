import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/utils/wbs_cost_coverage.dart';

WBSNode _node(
  String id,
  WBSLevel level,
  String code,
  String name, {
  List<WBSNode> children = const [],
  List<String>? costLineIds,
}) {
  return WBSNode(
    id: id,
    level: level,
    code: code,
    name: name,
    aiGenerated: false,
    costLineIds: costLineIds,
    children: children,
  );
}

WBSNode _sampleTree() {
  return _node('r', WBSLevel.level0, 'ROOT', 'House', children: [
    _node('g1', WBSLevel.level1, 'G1', 'Upstairs', children: [
      _node('g11', WBSLevel.level2, 'G1.1', 'Bedroom'),
      _node('g12', WBSLevel.level2, 'G1.2', 'Kitchen'),
    ]),
    _node('g2', WBSLevel.level1, 'G2', 'Downstairs', children: [
      _node('g21', WBSLevel.level2, 'G2.1', 'Garage', costLineIds: ['c']),
    ]),
  ]);
}

CostLine _line(
  String id,
  String? wbsRef,
  double total, {
  double? qty,
  double? rate,
}) {
  return CostLine(
    id: id,
    category: CostCategory.materials,
    subCategory: '',
    description: 'line $id',
    wbsRef: wbsRef,
    quantity: qty,
    rate: rate,
    total: total,
    inSchedule: true,
    basisSource: CostSourceType.historical,
    aiGenerated: false,
  );
}

void main() {
  group('collectLeafWorkPackages', () {
    test('walks every depth and returns only nodes without children', () {
      final leaves = collectLeafWorkPackages(_sampleTree());
      expect(leaves.length, 3);
      expect(leaves.map((n) => n.code).toSet(),
          {'G1.1', 'G1.2', 'G2.1'});
    });
  });

  group('computeWbsCostCoverage', () {
    test('zero priced lines leaves every leaf unpriced', () {
      final coverage = computeWbsCostCoverage(
        root: _sampleTree(),
        lines: [_line('x', null, 5000)],
      );
      expect(coverage.totalWorkPackages, 3);
      expect(coverage.pricedWorkPackages, 0);
      expect(coverage.unpriced.length, 3);
      expect(coverage.pricedRatio, 0);
    });

    test('wbsRef match, costLineIds link and qty×rate count as priced', () {
      final coverage = computeWbsCostCoverage(
        root: _sampleTree(),
        lines: [
          // Strong signal: line.wbsRef == leaf code.
          _line('a', 'G1.1', 15000),
          // Zero total but real quantity × rate still counts as priced.
          _line('b', 'G1.2', 0, qty: 40, rate: 125),
          // Bidirectional link via costLineIds.
          _line('c', null, 8000),
          // Unlinked line with no wbsRef — affects nothing.
          _line('d', null, 999),
        ],
      );
      expect(coverage.totalWorkPackages, 3);
      expect(coverage.pricedWorkPackages, 3);
      expect(coverage.hasUnpriced, isFalse);
      expect(coverage.pricedRatio, 1);
    });

    test('zero-total line without qty/rate does NOT count as priced', () {
      final coverage = computeWbsCostCoverage(
        root: _sampleTree(),
        lines: [_line('z', 'G1.1', 0)],
      );
      expect(coverage.pricedWorkPackages, 0);
      expect(coverage.unpriced.length, 3);
      expect(coverage.unpriced.map((u) => u.code).toSet(),
          {'G1.1', 'G1.2', 'G2.1'});
    });

    test('unpriced entries carry node id, code, name for quick pricing UI', () {
      final coverage = computeWbsCostCoverage(
        root: _sampleTree(),
        lines: [_line('a', 'G1.1', 15000)],
      );
      expect(coverage.unpriced.length, 2);
      final kitchen =
          coverage.unpriced.firstWhere((u) => u.code == 'G1.2');
      expect(kitchen.nodeId, 'g12');
      expect(kitchen.name, 'Kitchen');
    });
  });
}
