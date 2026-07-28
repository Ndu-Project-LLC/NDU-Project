import 'package:ndu_project/models/project_data_model.dart';

class ScheduleCpmService {
  ScheduleCpmService._();

  static CpmResult calculate({
    required List<ScheduleActivity> activities,
    required DateTime projectStart,
  }) {
    final byId = {for (final activity in activities) activity.id: activity};
    final diagnostics = <CpmDiagnostic>[];
    final successors = <String, List<String>>{
      for (final activity in activities) activity.id: <String>[],
    };
    final dependenciesById = <String, List<String>>{};

    for (final activity in activities) {
      final dependencies = _dependenciesFor(activity);
      final validDependencies = <String>[];
      for (final dependencyId in dependencies) {
        if (dependencyId == activity.id) {
          diagnostics.add(
            CpmDiagnostic(
              activityId: activity.id,
              type: CpmDiagnosticType.cycle,
              message: 'Activity cannot depend on itself.',
            ),
          );
          continue;
        }
        if (!byId.containsKey(dependencyId)) {
          diagnostics.add(
            CpmDiagnostic(
              activityId: activity.id,
              type: CpmDiagnosticType.missingDependency,
              message: 'Missing dependency "$dependencyId".',
            ),
          );
          continue;
        }
        validDependencies.add(dependencyId);
        successors.putIfAbsent(dependencyId, () => <String>[]).add(activity.id);
      }
      dependenciesById[activity.id] = validDependencies;
    }

    final order = <String>[];
    final permanent = <String>{};
    final temporary = <String>{};
    final cycleNodes = <String>{};

    void visit(String id, List<String> stack) {
      if (permanent.contains(id)) return;
      if (temporary.contains(id)) {
        cycleNodes.add(id);
        diagnostics.add(
          CpmDiagnostic(
            activityId: id,
            type: CpmDiagnosticType.cycle,
            message:
                'Circular dependency detected: ${[...stack, id].join(' -> ')}.',
          ),
        );
        return;
      }

      temporary.add(id);
      for (final dependencyId in dependenciesById[id] ?? const <String>[]) {
        visit(dependencyId, [...stack, id]);
      }
      temporary.remove(id);
      permanent.add(id);
      order.add(id);
    }

    for (final activity in activities) {
      visit(activity.id, const <String>[]);
    }

    final earlyStart = <String, int>{};
    final earlyFinish = <String, int>{};

    for (final id in order) {
      final activity = byId[id]!;
      final duration = _duration(activity);
      final dependencyFinishes = (dependenciesById[id] ?? const <String>[])
          .where((dependencyId) => !cycleNodes.contains(dependencyId))
          .map((dependencyId) => earlyFinish[dependencyId] ?? 0);
      final es = dependencyFinishes.isEmpty
          ? 0
          : dependencyFinishes.reduce((a, b) => a > b ? a : b);
      earlyStart[id] = es;
      earlyFinish[id] = es + duration;
    }

    final projectDuration = earlyFinish.values.isEmpty
        ? 0
        : earlyFinish.values.reduce((a, b) => a > b ? a : b);
    final lateStart = <String, int>{};
    final lateFinish = <String, int>{};

    for (final id in order.reversed) {
      final activity = byId[id]!;
      final duration = _duration(activity);
      final validSuccessors = (successors[id] ?? const <String>[])
          .where((successorId) => !cycleNodes.contains(successorId))
          .toList();
      final lf = validSuccessors.isEmpty
          ? projectDuration
          : validSuccessors
              .map((successorId) => lateStart[successorId] ?? projectDuration)
              .reduce((a, b) => a < b ? a : b);
      lateFinish[id] = lf;
      lateStart[id] = lf - duration;
    }

    final items = <String, CpmActivityResult>{};
    for (final activity in activities) {
      final es = earlyStart[activity.id] ?? 0;
      final ef = earlyFinish[activity.id] ?? es + _duration(activity);
      final ls = lateStart[activity.id] ?? es;
      final lf = lateFinish[activity.id] ?? ef;
      final totalFloat = ls - es;
      final isCritical = !cycleNodes.contains(activity.id) && totalFloat == 0;
      items[activity.id] = CpmActivityResult(
        activityId: activity.id,
        earlyStartOffsetDays: es,
        earlyFinishOffsetDays: ef,
        lateStartOffsetDays: ls,
        lateFinishOffsetDays: lf,
        totalFloat: totalFloat < 0 ? 0 : totalFloat,
        isCritical: isCritical,
        computedStart: projectStart.add(Duration(days: es)),
        computedEnd: projectStart.add(Duration(days: ef == 0 ? 0 : ef - 1)),
        dependencyIds: dependenciesById[activity.id] ?? const <String>[],
      );
    }

    return CpmResult(
      activitiesById: items,
      orderedActivityIds: order,
      projectDurationDays: projectDuration,
      criticalPathIds: items.values
          .where((item) => item.isCritical)
          .map((item) => item.activityId)
          .toList(),
      diagnostics: diagnostics,
    );
  }

  static List<ScheduleActivity> applyToActivities({
    required List<ScheduleActivity> activities,
    required DateTime projectStart,
    bool overwriteDates = false,
  }) {
    final result = calculate(
      activities: activities,
      projectStart: projectStart,
    );
    return activities.map((activity) {
      final cpm = result.activitiesById[activity.id];
      if (cpm == null) return activity;
      return ScheduleActivity(
        id: activity.id,
        wbsId: activity.wbsId,
        title: activity.title,
        durationDays: activity.durationDays,
        predecessorIds: activity.predecessorIds,
        isMilestone: activity.isMilestone,
        status: activity.status,
        priority: activity.priority,
        assignee: activity.assignee,
        discipline: activity.discipline,
        progress: activity.progress,
        startDate: overwriteDates || activity.startDate.isEmpty
            ? _formatDate(cpm.computedStart)
            : activity.startDate,
        dueDate: overwriteDates || activity.dueDate.isEmpty
            ? _formatDate(cpm.computedEnd)
            : activity.dueDate,
        estimatedHours: activity.estimatedHours,
        milestone: activity.milestone,
        workPackageId: activity.workPackageId,
        workPackageTitle: activity.workPackageTitle,
        workPackageType: activity.workPackageType,
        phase: activity.phase,
        wbsLevel2Id: activity.wbsLevel2Id,
        wbsLevel2Title: activity.wbsLevel2Title,
        contractId: activity.contractId,
        vendorId: activity.vendorId,
        procurementStatus: activity.procurementStatus,
        procurementRfqDate: activity.procurementRfqDate,
        procurementAwardDate: activity.procurementAwardDate,
        contractStartDate: activity.contractStartDate,
        contractEndDate: activity.contractEndDate,
        budgetedCost: activity.budgetedCost,
        actualCost: activity.actualCost,
        estimatingBasis: activity.estimatingBasis,
        dependencyIds: cpm.dependencyIds,
        isCriticalPath: cpm.isCritical,
        totalFloat: cpm.totalFloat,
      );
    }).toList();
  }

  static List<String> _dependenciesFor(ScheduleActivity activity) {
    return {
      ...activity.predecessorIds.map((id) => id.trim()),
      ...activity.dependencyIds.map((id) => id.trim()),
    }.where((id) => id.isNotEmpty).toList();
  }

  static int _duration(ScheduleActivity activity) {
    if (activity.isMilestone) return 0;
    return activity.durationDays < 0 ? 0 : activity.durationDays;
  }

  static String _formatDate(DateTime date) =>
      date.toIso8601String().split('T').first;
}

class CpmResult {
  const CpmResult({
    required this.activitiesById,
    required this.orderedActivityIds,
    required this.projectDurationDays,
    required this.criticalPathIds,
    required this.diagnostics,
  });

  final Map<String, CpmActivityResult> activitiesById;
  final List<String> orderedActivityIds;
  final int projectDurationDays;
  final List<String> criticalPathIds;
  final List<CpmDiagnostic> diagnostics;
}

class CpmActivityResult {
  const CpmActivityResult({
    required this.activityId,
    required this.earlyStartOffsetDays,
    required this.earlyFinishOffsetDays,
    required this.lateStartOffsetDays,
    required this.lateFinishOffsetDays,
    required this.totalFloat,
    required this.isCritical,
    required this.computedStart,
    required this.computedEnd,
    required this.dependencyIds,
  });

  final String activityId;
  final int earlyStartOffsetDays;
  final int earlyFinishOffsetDays;
  final int lateStartOffsetDays;
  final int lateFinishOffsetDays;
  final int totalFloat;
  final bool isCritical;
  final DateTime computedStart;
  final DateTime computedEnd;
  final List<String> dependencyIds;
}

class CpmDiagnostic {
  const CpmDiagnostic({
    required this.activityId,
    required this.type,
    required this.message,
  });

  final String activityId;
  final CpmDiagnosticType type;
  final String message;
}

enum CpmDiagnosticType {
  missingDependency,
  cycle,
}
