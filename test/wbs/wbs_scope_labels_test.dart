// Tests for wbsScopeLabels — the bridge that keeps cross-module scope pickers
// (Change Management "Scope Impact") anchored to the real work breakdown
// structure instead of a hard-coded stand-in list.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/utils/wbs_scope_labels.dart';

WBSNode _node(String id, String code, String name, WBSLevel level,
    {List<WBSNode> children = const []}) {
  return WBSNode(
    id: id,
    level: level,
    code: code,
    name: name,
    aiGenerated: false,
    children: children,
  );
}

WBS _wbs(WBSNode root) => WBS(
      id: 'wbs_1',
      projectId: 'proj_1',
      projectName: 'Test Project',
      framework: WBSFramework.waterfallDeliverable,
      level0: root,
      aiSuggestions: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('wbsScopeLabels', () {
    test('returns an empty list when there is no WBS', () {
      expect(wbsScopeLabels(null), isEmpty);
    });

    test('excludes the project root and labels nodes as "code — name"', () {
      final wbs = _wbs(_node('n0', '0', 'Test Project', WBSLevel.level0,
          children: [
            _node('n1', '1', 'Engineering & Design', WBSLevel.level1, children: [
              _node('n2', '1.1', 'Process Design Package', WBSLevel.level2),
              _node('n3', '1.2', 'Detailed Engineering', WBSLevel.level2),
            ]),
            _node('n4', '2', 'Procurement', WBSLevel.level1),
          ]));

      expect(wbsScopeLabels(wbs), [
        '1 — Engineering & Design',
        '1.1 — Process Design Package',
        '1.2 — Detailed Engineering',
        '2 — Procurement',
      ]);
    });

    test('never invents scope — nodes without a name are dropped', () {
      final wbs = _wbs(_node('n0', '0', 'Test Project', WBSLevel.level0,
          children: [
            _node('n1', '', '', WBSLevel.level1),
            _node('n2', '1.1', 'Real Deliverable', WBSLevel.level2),
          ]));

      expect(wbsScopeLabels(wbs), ['1.1 — Real Deliverable']);
    });

    test('falls back to the name alone when a node has no code', () {
      final wbs = _wbs(_node('n0', '0', 'Test Project', WBSLevel.level0,
          children: [
            _node('n1', '', 'Uncoded Package', WBSLevel.level1),
          ]));

      expect(wbsScopeLabels(wbs), ['Uncoded Package']);
    });
  });
}
