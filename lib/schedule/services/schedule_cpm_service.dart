import 'package:ndu_project/schedule/models/schedule_models.dart';

class ScheduleCpmService {
  ScheduleCpmService._();

  /// Flatten a tree of [ScheduleActivity] into a list via DFS.
  static List<ScheduleActivity> flatten(List<ScheduleActivity> roots) {
    final result = <ScheduleActivity>[];
    void walk(ScheduleActivity node) {
      result.add(node);
      for (final child in node.children) {
        walk(child);
      }
    }
    for (final root in roots) {
      walk(root);
    }
    return result;
  }

  /// Compute CPM for a list of flattened schedule activities.
  static CpmResult calculate({
    required List<ScheduleActivity> activities,
  }) {
    final byId = {for (final a in activities) a.id: a};
    final diags = <CpmDiagnostic>[];

    final forwardDeps = <String, List<(String, DependencyType)>>{};
    final successors = <String, List<(String, DependencyType)>>{};
    for (final a in activities) {
      forwardDeps[a.id] = <(String, DependencyType)>[];
      successors[a.id] = <(String, DependencyType)>[];
    }

    for (final a in activities) {
      for (final dep in a.dependencies) {
        if (dep.activityId == a.id) {
          diags.add(CpmDiagnostic(
            activityId: a.id,
            type: CpmDiagnosticType.selfDependency,
            message: 'Activity "${a.id}" depends on itself.',
          ));
          continue;
        }
        if (!byId.containsKey(dep.activityId)) {
          diags.add(CpmDiagnostic(
            activityId: a.id,
            type: CpmDiagnosticType.missingDependency,
            message: 'Missing dependency "${dep.activityId}" for "${a.id}".',
          ));
          continue;
        }
        forwardDeps[a.id]!.add((dep.activityId, dep.type));
        successors[dep.activityId]!.add((a.id, dep.type));
      }
    }

    // Topological sort (DFS)
    final order = <String>[];
    final permanent = <String>{};
    final temporary = <String>{};
    final cycleNodes = <String>{};

    void visit(String id, List<String> stack) {
      if (permanent.contains(id)) return;
      if (temporary.contains(id)) {
        cycleNodes.add(id);
        diags.add(CpmDiagnostic(
          activityId: id,
          type: CpmDiagnosticType.cycle,
          message: 'Circular dependency: ${[...stack, id].join(' -> ')}.',
        ));
        return;
      }
      temporary.add(id);
      for (final entry in forwardDeps[id] ?? <(String, DependencyType)>[]) {
        final depId = entry.$1;
        if (!cycleNodes.contains(depId)) {
          final nextStack = <String>[...stack, id];
          visit(depId, nextStack);
        }
      }
      temporary.remove(id);
      permanent.add(id);
      order.add(id);
    }

    for (final a in activities) {
      visit(a.id, <String>[]);
    }

    // Forward pass
    final es = <String, double>{};
    final ef = <String, double>{};

    for (final id in order) {
      final a = byId[id]!;
      final dur = _duration(a);

      double maxConstraint = 0;
      for (final entry in forwardDeps[id] ?? <(String, DependencyType)>[]) {
        final depId = entry.$1;
        final depType = entry.$2;
        if (cycleNodes.contains(depId)) continue;
        final constraint = _applyDependency(
          depType: depType,
          predecessorEs: es[depId] ?? 0,
          predecessorEf: ef[depId] ?? 0,
          activityDuration: dur,
        );
        if (constraint > maxConstraint) maxConstraint = constraint;
      }
      es[id] = maxConstraint;
      ef[id] = maxConstraint + dur;
    }

    final projectDuration = ef.values.isEmpty
        ? 0.0
        : ef.values.reduce((a, b) => a > b ? a : b);

    // Backward pass
    final ls = <String, double>{};
    final lf = <String, double>{};

    for (final id in order.reversed) {
      final a = byId[id]!;
      final dur = _duration(a);
      final succ = (successors[id] ?? <(String, DependencyType)>[])
          .where((s) => !cycleNodes.contains(s.$1))
          .toList();

      double minConstraint = projectDuration;
      for (final entry in succ) {
        final succId = entry.$1;
        final depType = entry.$2;
        final constraint = _applyReverseDependency(
          depType: depType,
          successorLs: ls[succId] ?? projectDuration,
          successorLf: lf[succId] ?? projectDuration,
          activityDuration: dur,
        );
        if (constraint < minConstraint) minConstraint = constraint;
      }
      lf[id] = minConstraint;
      ls[id] = minConstraint - dur;
    }

    // Build result items
    final items = <String, CpmActivityResult>{};
    for (final a in activities) {
      final activityEs = es[a.id] ?? 0;
      final activityEf = ef[a.id] ?? activityEs + _duration(a);
      final activityLs = ls[a.id] ?? activityEs;
      final activityLf = lf[a.id] ?? activityEf;
      final totalFloat = activityLs - activityEs;
      final isCritical = !cycleNodes.contains(a.id) && totalFloat.abs() < 0.001;

      items[a.id] = CpmActivityResult(
        activityId: a.id,
        earlyStartOffsetDays: activityEs,
        earlyFinishOffsetDays: activityEf,
        lateStartOffsetDays: activityLs,
        lateFinishOffsetDays: activityLf,
        totalFloat: totalFloat < 0 ? 0 : totalFloat,
        isCritical: isCritical,
      );
    }

    return CpmResult(
      activitiesById: items,
      orderedActivityIds: order,
      projectDurationDays: projectDuration,
      criticalPathIds: items.values
          .where((i) => i.isCritical)
          .map((i) => i.activityId)
          .toList(),
      diagnostics: diags,
    );
  }

  static double _applyDependency({
    required DependencyType depType,
    required double predecessorEs,
    required double predecessorEf,
    required double activityDuration,
  }) {
    switch (depType) {
      case DependencyType.finishToStart:
        return predecessorEf;
      case DependencyType.startToStart:
        return predecessorEs;
      case DependencyType.finishToFinish:
        return predecessorEf - activityDuration;
      case DependencyType.startToFinish:
        return predecessorEs - activityDuration;
      case DependencyType.external:
      case DependencyType.interface:
        return predecessorEf;
    }
  }

  static double _applyReverseDependency({
    required DependencyType depType,
    required double successorLs,
    required double successorLf,
    required double activityDuration,
  }) {
    switch (depType) {
      case DependencyType.finishToStart:
        return successorLs;
      case DependencyType.startToStart:
        return successorLs + activityDuration;
      case DependencyType.finishToFinish:
        return successorLf;
      case DependencyType.startToFinish:
        return successorLf + activityDuration;
      case DependencyType.external:
      case DependencyType.interface:
        return successorLs;
    }
  }

  /// Apply CPM results back onto [ScheduleActivity] tree nodes.
  static List<ScheduleActivity> applyToActivities({
    required List<ScheduleActivity> roots,
    required DateTime projectStart,
    required CpmResult result,
    bool overwriteDates = false,
  }) {
    List<ScheduleActivity> applyNode(ScheduleActivity node) {
      final cpm = result.activitiesById[node.id];
      if (cpm == null) return [node];
      final newStart = overwriteDates || node.startDate == null
          ? projectStart.add(Duration(
              milliseconds: (cpm.earlyStartOffsetDays * 86400000).round()))
          : node.startDate;
      final newEnd = overwriteDates || node.endDate == null
          ? projectStart.add(Duration(
              milliseconds: (cpm.earlyFinishOffsetDays * 86400000).round()))
          : node.endDate;
      return [
        node.copyWith(
          isCriticalPath: cpm.isCritical,
          startDate: newStart,
          endDate: newEnd,
          children: node.children.expand((c) => applyNode(c)).toList(),
        ),
      ];
    }

    return roots.expand((r) => applyNode(r)).toList();
  }

  static double _duration(ScheduleActivity a) {
    if (a.type == ActivityType.milestone) return 0;
    return (a.duration ?? 1).clamp(0, double.infinity);
  }
}

/// Result of a CPM calculation.
class CpmResult {
  final Map<String, CpmActivityResult> activitiesById;
  final List<String> orderedActivityIds;
  final double projectDurationDays;
  final List<String> criticalPathIds;
  final List<CpmDiagnostic> diagnostics;

  const CpmResult({
    required this.activitiesById,
    required this.orderedActivityIds,
    required this.projectDurationDays,
    required this.criticalPathIds,
    required this.diagnostics,
  });
}

/// Per-activity CPM result.
class CpmActivityResult {
  final String activityId;
  final double earlyStartOffsetDays;
  final double earlyFinishOffsetDays;
  final double lateStartOffsetDays;
  final double lateFinishOffsetDays;
  final double totalFloat;
  final bool isCritical;

  const CpmActivityResult({
    required this.activityId,
    required this.earlyStartOffsetDays,
    required this.earlyFinishOffsetDays,
    required this.lateStartOffsetDays,
    required this.lateFinishOffsetDays,
    required this.totalFloat,
    required this.isCritical,
  });
}

/// Diagnostic message from CPM validation.
class CpmDiagnostic {
  final String activityId;
  final CpmDiagnosticType type;
  final String message;

  const CpmDiagnostic({
    required this.activityId,
    required this.type,
    required this.message,
  });
}

enum CpmDiagnosticType {
  missingDependency,
  selfDependency,
  cycle,
}
