/// Scope / work-package labels derived from the real work breakdown structure.
///
/// Cross-module pickers (the Change Management "Scope Impact" multi-select,
/// for one) must offer the same scope the project actually decomposed in the
/// WBS module — never an invented stand-in list. Pure and dependency-free so
/// it can be unit tested.
library;

import 'package:ndu_project/wbs/models/wbs_models.dart';

/// Labels for every WBS node below the project root, in tree order.
///
/// A node renders as `code — name` (e.g. `1.2.3 — Foundation Construction`),
/// or as its name alone when it has no code of its own.
///
/// Deliberately walks the tree rather than reusing [flattenWBS]: that helper
/// inherits a parent's path when a node has no code (so a Level 1 node would
/// be labelled with the project root's code) and can emit a code-only label
/// for a node with no name. Neither makes sense as a scope a user picks.
///
/// Returns an empty list when there is no WBS — callers should show an empty
/// state that points at the WBS module rather than fabricating entries.
List<String> wbsScopeLabels(WBS? wbs) {
  if (wbs == null) return const [];

  final labels = <String>[];
  void walk(WBSNode node, {required bool isRoot}) {
    if (!isRoot) {
      final name = node.name.trim();
      final code = node.code.trim();
      // An unnamed node is not scope anyone can pick — skip the node but keep
      // walking, because its children may still be named.
      if (name.isNotEmpty) {
        labels.add(code.isEmpty ? name : '$code — $name');
      }
    }
    for (final child in node.children) {
      walk(child, isRoot: false);
    }
  }

  walk(wbs.level0, isRoot: true);
  return labels;
}
