/// WBS — validation rules V1-V8 (Dart equivalent)
///
/// Derived from the best practices in both guidance docs.


library;

import 'package:ndu_project/wbs/models/wbs_models.dart';

enum ValidationSeverity { pass, warn, fail }

class ValidationCheck {
  final String id;
  final ValidationSeverity severity;
  final String title;
  final String detail;
  final String? fix;

  const ValidationCheck({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    this.fix,
  });
}

// Activity verbs that should NOT be used as node names
const List<String> _activityVerbs = [
  'design', 'code', 'test', 'build', 'implement', 'develop', 'create',
  'configure', 'install', 'deploy', 'migrate', 'integrate', 'plan',
];

bool _isActivityVerb(String name) {
  final lower = name.trim().toLowerCase();
  for (final v in _activityVerbs) {
    if (lower.startsWith('$v ') || lower == v) return true;
  }
  return false;
}

class WBSValidator {
  static List<ValidationCheck> validate(WBS wbs) {
    final checks = <ValidationCheck>[];
    final level1Nodes = wbs.level0.children;
    final frameworkMeta = wbs.framework;

    // V1: At least 3 Level 1 nodes
    if (level1Nodes.length >= 3) {
      checks.add(ValidationCheck(
        id: 'V1',
        severity: ValidationSeverity.pass,
        title: 'Sufficient Level 1 breakdown',
        detail:
            '${level1Nodes.length} ${frameworkMeta.level1Label} nodes defined (minimum 3).',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V1',
        severity: ValidationSeverity.fail,
        title: 'Insufficient Level 1 breakdown',
        detail:
            'Only ${level1Nodes.length} ${frameworkMeta.level1Label} node(s). At least 3 required.',
        fix: 'Add more Level 1 nodes to cover the full scope.',
      ));
    }

    // V2: Each Level 1 has at least 2 Level 2 children
    final underParented =
        level1Nodes.where((l1) => l1.children.length < 2).toList();
    if (underParented.isEmpty && level1Nodes.isNotEmpty) {
      checks.add(ValidationCheck(
        id: 'V2',
        severity: ValidationSeverity.pass,
        title: 'Level 2 children present',
        detail:
            'Every ${frameworkMeta.level1Label} has at least 2 ${frameworkMeta.level2Label} children.',
      ));
    } else if (level1Nodes.isEmpty) {
      checks.add(ValidationCheck(
        id: 'V2',
        severity: ValidationSeverity.warn,
        title: 'No Level 1 nodes yet',
        detail: 'Add Level 1 nodes before checking Level 2 children.',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V2',
        severity: ValidationSeverity.fail,
        title: 'Level 1 nodes missing Level 2 children',
        detail:
            '${underParented.length} ${frameworkMeta.level1Label}(s) have fewer than 2 ${frameworkMeta.level2Label} children: ${underParented.map((n) => n.name).join(", ")}.',
        fix:
            'Add at least 2 ${frameworkMeta.level2Label} children to each ${frameworkMeta.level1Label}.',
      ));
    }

    // V3 & V4: No activity verbs; deliverable-focused names
    final allNodes = <WBSNode>[
      ...level1Nodes,
      ...level1Nodes.expand((l1) => l1.children),
    ];
    final verbNodes = allNodes.where((n) => _isActivityVerb(n.name)).toList();
    if (verbNodes.isEmpty) {
      checks.add(ValidationCheck(
        id: 'V3',
        severity: ValidationSeverity.pass,
        title: 'Deliverable-focused names',
        detail:
            'All node names use deliverable nouns, not activity verbs.',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V3',
        severity: ValidationSeverity.warn,
        title: 'Activity-verb names detected',
        detail:
            '${verbNodes.length} node(s) start with an activity verb: ${verbNodes.map((n) => '"${n.name}"').join(", ")}.',
        fix:
            'Rename to deliverable nouns (e.g. "Authentication Module" instead of "Design Authentication").',
      ));
    }

    // V5: MECE check at Level 1
    final names = level1Nodes.map((n) => n.name.trim().toLowerCase()).toList();
    final seen = <String>{};
    final overlap = <String>[];
    for (final n in names) {
      if (seen.contains(n)) overlap.add(n);
      seen.add(n);
    }
    if (overlap.isEmpty) {
      checks.add(ValidationCheck(
        id: 'V5',
        severity: ValidationSeverity.pass,
        title: 'Mutually exclusive (Level 1)',
        detail:
            'All ${frameworkMeta.level1Label} names are unique — no overlap.',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V5',
        severity: ValidationSeverity.warn,
        title: 'Duplicate Level 1 names',
        detail: 'Duplicate names detected: ${overlap.join(", ")}.',
        fix:
            'Rename duplicates to ensure Level 1 nodes are mutually exclusive.',
      ));
    }

    // V6: Phase-Based warning
    if (wbs.framework == WBSFramework.waterfallPhase) {
      checks.add(ValidationCheck(
        id: 'V6',
        severity: ValidationSeverity.warn,
        title: 'Phase-Based framework (least preferred)',
        detail:
            'Phase-Based WBS is rated ★★ (least preferred). It tends to mix deliverables and activities and does not naturally support scope control.',
        fix:
            'Consider switching to Deliverable-Based (★★★★★) if the project scope can be decomposed into deliverables.',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V6',
        severity: ValidationSeverity.pass,
        title: 'Framework preference check',
        detail:
            '${frameworkMeta.label} is rated ${"★" * frameworkMeta.rating} — acceptable framework choice.',
      ));
    }

    // V7: Level 2 waterfall nodes flagged as work packages
    if (frameworkMeta.deliveryModel == 'WATERFALL') {
      final level2Nodes =
          level1Nodes.expand((l1) => l1.children).toList();
      final notWorkPackage =
          level2Nodes.where((n) => n.isWorkPackage != true).toList();
      if (level2Nodes.isEmpty) {
        checks.add(ValidationCheck(
          id: 'V7',
          severity: ValidationSeverity.warn,
          title: 'No Level 2 work packages',
          detail: 'Add Level 2 nodes to enable cost traceability.',
        ));
      } else if (notWorkPackage.isEmpty) {
        checks.add(ValidationCheck(
          id: 'V7',
          severity: ValidationSeverity.pass,
          title: 'All Level 2 nodes are work packages',
          detail:
              '${level2Nodes.length} Level 2 nodes are flagged as cost-traceable work packages.',
        ));
      } else {
        checks.add(ValidationCheck(
          id: 'V7',
          severity: ValidationSeverity.warn,
          title: 'Level 2 nodes not flagged as work packages',
          detail:
              '${notWorkPackage.length} of ${level2Nodes.length} Level 2 nodes are not flagged as work packages.',
          fix:
              'Flag Level 2 nodes as work packages to enable cost traceability in the Cost Estimate module.',
        ));
      }
    } else {
      checks.add(ValidationCheck(
        id: 'V7',
        severity: ValidationSeverity.pass,
        title: 'Agile framework — work package flag N/A',
        detail:
            'Agile Level 2 nodes (Features) are estimated via story points, not work packages.',
      ));
    }

    // V8: AI-suggested nodes need validation
    final aiNodes = allNodes.where((n) => n.aiGenerated).toList();
    if (aiNodes.isEmpty) {
      checks.add(ValidationCheck(
        id: 'V8',
        severity: ValidationSeverity.pass,
        title: 'No AI-suggested nodes pending validation',
        detail:
            'All nodes are user-authored or AI suggestions have been validated.',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'V8',
        severity: ValidationSeverity.warn,
        title: '${aiNodes.length} AI-suggested node(s) require validation',
        detail:
            '${aiNodes.length} node(s) were generated by KAZ AI. Validate each with a qualified SME before baseline.',
        fix:
            'Review AI-suggested nodes and confirm they match the project scope. Remove or rename any that don\'t fit.',
      ));
    }

    return checks;
  }

  static ({int pass, int warn, int fail, String overall}) summarize(
      List<ValidationCheck> checks) {
    final pass =
        checks.where((c) => c.severity == ValidationSeverity.pass).length;
    final warn =
        checks.where((c) => c.severity == ValidationSeverity.warn).length;
    final fail =
        checks.where((c) => c.severity == ValidationSeverity.fail).length;
    final overall =
        fail > 0 ? 'FAIL' : warn > 0 ? 'WARN' : 'PASS';
    return (pass: pass, warn: warn, fail: fail, overall: overall);
  }
}
