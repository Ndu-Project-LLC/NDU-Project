/// NDU Project — WBS type system (Dart equivalent)
///
/// Level convention:
///   Level 0 = Project (root)
///   Level 1 = Major breakdown (Epic / Deliverable / Discipline / etc.)
///   Level 2 = Sub-component (Feature / Sub-Deliverable / Component / etc.)
///   Level 3 = Work Package (or Story in Agile)
///   Level 4 = Activity / Task
///   Level 5 = Sub-activity / Subtask
///   Level 6 = Task (detailed planning level)
///   Level 7 = Subtask
///   Level 8 = Work Item / Hours Block (lowest executable unit)
///
/// Maximum depth: Level 8 (configurable per framework).

library;

import 'package:flutter/material.dart';

/// View mode for the WBS Builder screen.
enum WBSViewMode {
  advanced,
  simple,
  table;

  String get label => switch (this) {
        WBSViewMode.advanced => 'Advanced',
        WBSViewMode.simple => 'Simple',
        WBSViewMode.table => 'Table',
      };
}

/// The overall project delivery methodology.
enum ProjectMethodology {
  waterfall,
  agile,
  hybrid;

  String get label => switch (this) {
        ProjectMethodology.waterfall => 'Waterfall',
        ProjectMethodology.agile => 'Agile',
        ProjectMethodology.hybrid => 'Hybrid',
      };

  String get description => switch (this) {
        ProjectMethodology.waterfall =>
          'Linear, sequential delivery. Best for well-defined requirements, construction, manufacturing, and regulated industries.',
        ProjectMethodology.agile =>
          'Iterative, incremental delivery. Best for software, digital products, R&D, and rapidly evolving requirements.',
        ProjectMethodology.hybrid =>
          'Combines Waterfall and Agile. Best for projects with both well-defined and exploratory components, or organizations transitioning to Agile.',
      };

  IconData get icon => switch (this) {
        ProjectMethodology.waterfall => Icons.timeline,
        ProjectMethodology.agile => Icons.speed,
        ProjectMethodology.hybrid => Icons.account_tree,
      };

  Color get color => switch (this) {
        ProjectMethodology.waterfall => Color(0xFFD97706),
        ProjectMethodology.agile => Color(0xFF7C3AED),
        ProjectMethodology.hybrid => Color(0xFF059669),
      };
}

enum WBSFramework {
  agile,
  waterfallDeliverable,
  waterfallDiscipline,
  waterfallFunctional,
  waterfallGeographic,
  waterfallPhase;

  String get label => switch (this) {
        WBSFramework.agile => 'Agile WBS',
        WBSFramework.waterfallDeliverable => 'Waterfall — Deliverable-Based',
        WBSFramework.waterfallDiscipline => 'Waterfall — Discipline-Based',
        WBSFramework.waterfallFunctional => 'Waterfall — Functional Area',
        WBSFramework.waterfallGeographic => 'Waterfall — Geographic Location',
        WBSFramework.waterfallPhase =>
          'Waterfall — Phase-Based (Least Preferred)',
      };

  String get shortLabel => switch (this) {
        WBSFramework.agile => 'Agile',
        WBSFramework.waterfallDeliverable => 'Deliverable',
        WBSFramework.waterfallDiscipline => 'Discipline',
        WBSFramework.waterfallFunctional => 'Functional',
        WBSFramework.waterfallGeographic => 'Geographic',
        WBSFramework.waterfallPhase => 'Phase',
      };

  String get deliveryModel => switch (this) {
        WBSFramework.agile => 'AGILE',
        _ => 'WATERFALL',
      };

  String get level1Label => switch (this) {
        WBSFramework.agile => 'Epic',
        WBSFramework.waterfallDeliverable => 'Deliverable',
        WBSFramework.waterfallDiscipline => 'Discipline',
        WBSFramework.waterfallFunctional => 'Functional Area',
        WBSFramework.waterfallGeographic => 'Region',
        WBSFramework.waterfallPhase => 'Phase',
      };

  String get level2Label => switch (this) {
        WBSFramework.agile => 'Feature',
        WBSFramework.waterfallDeliverable => 'Sub-Deliverable',
        WBSFramework.waterfallDiscipline => 'Component',
        WBSFramework.waterfallFunctional => 'Sub-Area',
        WBSFramework.waterfallGeographic => 'Site',
        WBSFramework.waterfallPhase => 'Phase Activity',
      };

  String get level3Label => switch (this) {
        WBSFramework.agile => 'User Story',
        WBSFramework.waterfallDeliverable => 'Work Package',
        WBSFramework.waterfallDiscipline => 'Work Package',
        WBSFramework.waterfallFunctional => 'Work Package',
        WBSFramework.waterfallGeographic => 'Deliverable',
        WBSFramework.waterfallPhase => 'Deliverable',
      };

  String get level4Label => switch (this) {
        WBSFramework.agile => 'Task',
        WBSFramework.waterfallDeliverable => 'Activity',
        WBSFramework.waterfallDiscipline => 'Activity',
        WBSFramework.waterfallFunctional => 'Activity',
        WBSFramework.waterfallGeographic => 'Work Package',
        WBSFramework.waterfallPhase => 'Work Package',
      };

  String get level5Label => switch (this) {
        WBSFramework.agile => 'Subtask',
        WBSFramework.waterfallDeliverable => 'Sub-Activity',
        WBSFramework.waterfallDiscipline => 'Sub-Activity',
        WBSFramework.waterfallFunctional => 'Sub-Activity',
        WBSFramework.waterfallGeographic => 'Activity',
        WBSFramework.waterfallPhase => 'Activity',
      };

  String get level6Label => switch (this) {
        WBSFramework.agile => 'Work Item',
        WBSFramework.waterfallDeliverable => 'Task',
        WBSFramework.waterfallDiscipline => 'Task',
        WBSFramework.waterfallFunctional => 'Task',
        WBSFramework.waterfallGeographic => 'Sub-Activity',
        WBSFramework.waterfallPhase => 'Sub-Activity',
      };

  String get level7Label => switch (this) {
        WBSFramework.agile => 'Hours Block',
        WBSFramework.waterfallDeliverable => 'Subtask',
        WBSFramework.waterfallDiscipline => 'Subtask',
        WBSFramework.waterfallFunctional => 'Subtask',
        WBSFramework.waterfallGeographic => 'Task',
        WBSFramework.waterfallPhase => 'Task',
      };

  String get level8Label => switch (this) {
        WBSFramework.agile => 'Hours Block',
        WBSFramework.waterfallDeliverable => 'Work Item',
        WBSFramework.waterfallDiscipline => 'Work Item',
        WBSFramework.waterfallFunctional => 'Work Item',
        WBSFramework.waterfallGeographic => 'Subtask',
        WBSFramework.waterfallPhase => 'Subtask',
      };

  /// Returns the label for a given level number (1-8).
  String levelLabel(int level) => switch (level) {
        1 => level1Label,
        2 => level2Label,
        3 => level3Label,
        4 => level4Label,
        5 => level5Label,
        6 => level6Label,
        7 => level7Label,
        8 => level8Label,
        _ => 'Node',
      };

  IconData get iconData => switch (this) {
        WBSFramework.agile => Icons.speed,
        WBSFramework.waterfallDeliverable => Icons.inventory_2,
        WBSFramework.waterfallDiscipline => Icons.engineering,
        WBSFramework.waterfallFunctional => Icons.group,
        WBSFramework.waterfallGeographic => Icons.public,
        WBSFramework.waterfallPhase => Icons.timeline,
      };

  int get rating => switch (this) {
        WBSFramework.agile => 5,
        WBSFramework.waterfallDeliverable => 5,
        WBSFramework.waterfallDiscipline => 5,
        WBSFramework.waterfallFunctional => 4,
        WBSFramework.waterfallGeographic => 4,
        WBSFramework.waterfallPhase => 2,
      };

  int get maxDepth => switch (this) {
        WBSFramework.agile => 8,
        WBSFramework.waterfallDeliverable => 8,
        WBSFramework.waterfallDiscipline => 8,
        WBSFramework.waterfallFunctional => 4,
        WBSFramework.waterfallGeographic => 8,
        WBSFramework.waterfallPhase => 4,
      };

  String get bestFor => switch (this) {
        WBSFramework.agile => 'Software, digital products, iterative delivery',
        WBSFramework.waterfallDeliverable =>
          'All industries (preferred standard approach)',
        WBSFramework.waterfallDiscipline =>
          'Engineering, Construction, EPC, Industrial facilities',
        WBSFramework.waterfallFunctional =>
          'Organizations with strong departments, resource planning, cost reporting',
        WBSFramework.waterfallGeographic =>
          'Multi-site deployments, infrastructure programs, retail expansions, telecom rollouts',
        WBSFramework.waterfallPhase =>
          'High-level reporting, small projects, educational purposes only',
      };

  String get description => switch (this) {
        WBSFramework.agile =>
          'Product → Epic → Feature → Story → Task → Work Item → Hours Block. Focuses on deliverable increments. Supports up to 8 levels for hours-of-work granularity.',
        WBSFramework.waterfallDeliverable =>
          'Project → Deliverable → Sub-Deliverable → Work Package → Activity → Task → Subtask → Work Item. Focuses on what must be produced, not how. Preferred standard approach. Supports up to 8 levels.',
        WBSFramework.waterfallDiscipline =>
          'Project → Discipline → Component → Work Package → Activity → Task → Subtask → Work Item. Best for technical/engineering systems. Supports up to 8 levels.',
        WBSFramework.waterfallFunctional =>
          'Project → Functional Area → Sub-Area → Work Package → Activity. Focuses on who performs the work.',
        WBSFramework.waterfallGeographic =>
          'Project → Region → Site → Deliverable → Work Package → Activity → Task → Subtask. Focuses on where the work occurs. Supports up to 8 levels.',
        WBSFramework.waterfallPhase =>
          'Project → Phase → Phase Activity → Deliverable → Work Package → Activity. Least preferred — mixes deliverables and activities.',
      };

  /// Returns an appropriate EstimationMethod based on level and framework.
  EstimationMethod? suggestedEstimation(int level) {
    if (this == WBSFramework.agile) {
      return switch (level) {
        1 => EstimationMethod.tShirt,
        2 || 3 => EstimationMethod.storyPoints,
        _ => EstimationMethod.hours,
      };
    }
    return switch (level) {
      1 || 2 => EstimationMethod.tShirt,
      3 => EstimationMethod.days,
      _ => EstimationMethod.hours,
    };
  }
}

enum WBSLevel {
  level0,
  level1,
  level2,
  level3,
  level4,
  level5,
  level6,
  level7,
  level8
}

extension WBSLevelMeta on WBSLevel {
  int get value => switch (this) {
        WBSLevel.level0 => 0,
        WBSLevel.level1 => 1,
        WBSLevel.level2 => 2,
        WBSLevel.level3 => 3,
        WBSLevel.level4 => 4,
        WBSLevel.level5 => 5,
        WBSLevel.level6 => 6,
        WBSLevel.level7 => 7,
        WBSLevel.level8 => 8,
      };

  static WBSLevel fromInt(int v) => switch (v) {
        0 => WBSLevel.level0,
        1 => WBSLevel.level1,
        2 => WBSLevel.level2,
        3 => WBSLevel.level3,
        4 => WBSLevel.level4,
        5 => WBSLevel.level5,
        6 => WBSLevel.level6,
        7 => WBSLevel.level7,
        8 => WBSLevel.level8,
        _ => WBSLevel.level8,
      };
}

enum EstimationMethod {
  tShirt,
  storyPoints,
  hours,
  days;

  String get label => switch (this) {
        EstimationMethod.tShirt => 'T-shirt Size',
        EstimationMethod.storyPoints => 'Story Points',
        EstimationMethod.hours => 'Hours',
        EstimationMethod.days => 'Days',
      };

  String get desc => switch (this) {
        EstimationMethod.tShirt =>
          'XS / S / M / L / XL — quick epic-level sizing',
        EstimationMethod.storyPoints => 'Fibonacci-scale relative estimation',
        EstimationMethod.hours => 'Detailed hour estimates (task-level)',
        EstimationMethod.days => 'Day-level estimates (task-level)',
      };

  IconData get icon => switch (this) {
        EstimationMethod.tShirt => Icons.checkroom,
        EstimationMethod.storyPoints => Icons.looks_3,
        EstimationMethod.hours => Icons.schedule,
        EstimationMethod.days => Icons.calendar_today,
      };
}

enum AISource {
  global,
  regional,
  local,
  siteSpecific,
  kazAI;

  String get label => switch (this) {
        AISource.global => 'Global Projects',
        AISource.regional => 'Regional Projects',
        AISource.local => 'Local Projects',
        AISource.siteSpecific => 'Site-Specific',
        AISource.kazAI => 'KAZ AI',
      };

  IconData get icon => switch (this) {
        AISource.kazAI => Icons.auto_awesome,
        _ => Icons.public,
      };
}

enum AIConfidence { low, med, high }

/// A WBS node — supports levels 0 through maxDepth (frequently 5).
class WBSNode {
  final String id;
  final WBSLevel level;
  final String code;
  final String name;
  final String? description;
  final EstimationMethod? estimationMethod;
  final bool? isWorkPackage;
  final bool aiGenerated;
  final AISource? aiSource;
  final AIConfidence? aiConfidence;
  final String? aiReference;
  final String? methodology; // 'waterfall', 'agile', or null (inherits parent)
  final List<String>? costLineIds;
  final List<WBSNode> children;

  const WBSNode({
    required this.id,
    required this.level,
    required this.code,
    required this.name,
    this.description,
    this.estimationMethod,
    this.isWorkPackage,
    required this.aiGenerated,
    this.aiSource,
    this.aiConfidence,
    this.aiReference,
    this.methodology,
    this.costLineIds,
    required this.children,
  });

  WBSNode copyWith({
    String? id,
    WBSLevel? level,
    String? code,
    String? name,
    String? description,
    EstimationMethod? estimationMethod,
    bool? isWorkPackage,
    bool? aiGenerated,
    AISource? aiSource,
    AIConfidence? aiConfidence,
    String? aiReference,
    String? methodology,
    List<String>? costLineIds,
    List<WBSNode>? children,
  }) {
    return WBSNode(
      id: id ?? this.id,
      level: level ?? this.level,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      estimationMethod: estimationMethod ?? this.estimationMethod,
      isWorkPackage: isWorkPackage ?? this.isWorkPackage,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      aiSource: aiSource ?? this.aiSource,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiReference: aiReference ?? this.aiReference,
      methodology: methodology ?? this.methodology,
      costLineIds: costLineIds ?? this.costLineIds,
      children: children ?? this.children,
    );
  }
}

/// The full WBS.
class WBS {
  final String id;
  final String projectId;
  final String projectName;
  final WBSFramework framework;
  final ProjectMethodology methodology;
  final WBSNode level0;
  final List<dynamic> aiSuggestions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WBS({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.framework,
    this.methodology = ProjectMethodology.waterfall,
    required this.level0,
    required this.aiSuggestions,
    required this.createdAt,
    required this.updatedAt,
  });

  WBS copyWith({
    String? id,
    String? projectId,
    String? projectName,
    WBSFramework? framework,
    ProjectMethodology? methodology,
    WBSNode? level0,
    List<dynamic>? aiSuggestions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WBS(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      framework: framework ?? this.framework,
      methodology: methodology ?? this.methodology,
      level0: level0 ?? this.level0,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Count nodes at each level (up to level8).
({
  int level0,
  int level1,
  int level2,
  int level3,
  int level4,
  int level5,
  int level6,
  int level7,
  int level8
}) countNodes(WBS wbs) {
  final counts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0};
  void walk(WBSNode node) {
    final lvl = node.level.value;
    if (counts.containsKey(lvl)) counts[lvl] = counts[lvl]! + 1;
    for (final c in node.children) {
      walk(c);
    }
  }

  walk(wbs.level0);
  return (
    level0: counts[0]!,
    level1: counts[1]!,
    level2: counts[2]!,
    level3: counts[3]!,
    level4: counts[4]!,
    level5: counts[5]!,
    level6: counts[6]!,
    level7: counts[7]!,
    level8: counts[8]!,
  );
}

/// A flattened WBS node entry used by dropdowns / summaries.
class FlattenedWBSNode {
  final String id;
  final String path;
  final String name;
  final WBSLevel level;

  const FlattenedWBSNode({
    required this.id,
    required this.path,
    required this.name,
    required this.level,
  });

  /// Human-readable label, e.g. `1.2.3 — Foundation Construction`.
  String get label {
    final trimmed = path.trim();
    final nameTrimmed = name.trim();
    if (trimmed.isEmpty) return nameTrimmed;
    if (nameTrimmed.isEmpty) return trimmed;
    return '$trimmed — $nameTrimmed';
  }
}

/// Walk the WBS tree (any depth) and return a flat list of
/// [FlattenedWBSNode] entries. The Level 0 root is included by default but
/// can be excluded via [includeRoot].
List<FlattenedWBSNode> flattenWBS(WBS wbs, {bool includeRoot = true}) {
  final out = <FlattenedWBSNode>[];
  void walk(WBSNode node, String parentPath) {
    final path = node.code.isEmpty ? parentPath : node.code;
    if (node.level != WBSLevel.level0 || includeRoot) {
      out.add(FlattenedWBSNode(
        id: node.id,
        path: path,
        name: node.name,
        level: node.level,
      ));
    }
    for (final child in node.children) {
      walk(child, path);
    }
  }

  walk(wbs.level0, '');
  return out;
}

/// Count the total number of cost-line IDs linked anywhere in the WBS tree.
int countAllLinkedCostLines(WBS wbs) {
  int count(WBSNode n) {
    final own = n.costLineIds?.length ?? 0;
    return own + n.children.fold(0, (s, c) => s + count(c));
  }

  return count(wbs.level0);
}

int _wbsIdCounter = 0;

/// Generate a unique ID.
String newWBSId([String prefix = 'wbs']) {
  _wbsIdCounter++;
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$_wbsIdCounter';
}

/// Determine [WBSLevel] from a dotted-code like "G1.2.3" → level3 (2 dots + 1).
/// G-prefixed nomenclature: G1 = level1, G1.1 = level2, G1.1.1 = level3
WBSLevel _codeDepthToLevel(String code) {
  final depth = code.split('.').length;
  return WBSLevelMeta.fromInt(depth);
}

/// Recompute node codes based on tree position for arbitrary depth.
/// Uses G-prefixed nomenclature that cascades from Goals:
///   Level 1: G1, G2, G3
///   Level 2: G1.1, G1.2, G1.3
///   Level 3: G1.1.1, G1.1.2, G1.1.3
/// The root (Level 0) keeps its project name as the code.
WBSNode recalcCodes(WBSNode node) {
  if (node.level == WBSLevel.level0) {
    return node.copyWith(
      code: '0',
      children: node.children.asMap().entries.map((e) {
        return _recalcCodesRecursive(e.value, 'G${e.key + 1}');
      }).toList(),
    );
  }
  return node;
}

WBSNode _recalcCodesRecursive(WBSNode node, String parentCode) {
  final level = _codeDepthToLevel(parentCode);
  return node.copyWith(
    code: parentCode,
    level: level,
    children: node.children.asMap().entries.map((e) {
      return _recalcCodesRecursive(e.value, '$parentCode.${e.key + 1}');
    }).toList(),
  );
}

/// Get the effective depth of a WBS tree (0 = root only).
int treeDepth(WBSNode node) {
  if (node.children.isEmpty) return 0;
  int maxChildDepth = 0;
  for (final c in node.children) {
    final d = treeDepth(c);
    if (d > maxChildDepth) maxChildDepth = d;
  }
  return 1 + maxChildDepth;
}

/// Count all nodes in the tree.
int countAllNodes(WBSNode node) {
  return 1 + node.children.fold(0, (s, c) => s + countAllNodes(c));
}

/// Create an empty WBS.
WBS createEmptyWBS({
  required String projectId,
  required String projectName,
  required WBSFramework framework,
  ProjectMethodology methodology = ProjectMethodology.waterfall,
}) {
  final now = DateTime.now();
  return WBS(
    id: newWBSId('wbs'),
    projectId: projectId,
    projectName: projectName,
    framework: framework,
    methodology: methodology,
    level0: WBSNode(
      id: newWBSId('node'),
      level: WBSLevel.level0,
      code: '0',
      name: projectName,
      description: 'Project root (Level 0)',
      aiGenerated: false,
      children: [],
    ),
    aiSuggestions: [],
    createdAt: now,
    updatedAt: now,
  );
}

/// Determine the level label for a node given the framework and its depth.
String nodeLevelLabel(WBSNode node, WBSFramework framework) {
  final depth = node.level.value;
  if (depth == 0) return 'Project';
  if (depth > 0 && depth <= 8) return framework.levelLabel(depth);
  return 'Node';
}

/// Determine the color shade for a given level (for visual hierarchy).
Color levelColor(int level, [Color base = const Color(0xFFD97706)]) {
  final opacity = switch (level) {
    0 => 1.0,
    1 => 0.9,
    2 => 0.8,
    3 => 0.65,
    4 => 0.5,
    5 => 0.35,
    _ => 0.3,
  };
  return base.withValues(alpha: opacity);
}
