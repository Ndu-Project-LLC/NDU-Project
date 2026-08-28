import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// The canonical delivery chain used throughout planning and control.
enum ProjectLifecycleStage { scope, wbs, schedule, resources, cost, controls }

enum LifecycleStageState { blocked, attention, ready }

class LifecycleStageAssessment {
  const LifecycleStageAssessment({
    required this.stage,
    required this.state,
    required this.label,
    required this.summary,
    required this.completion,
  });

  final ProjectLifecycleStage stage;
  final LifecycleStageState state;
  final String label;
  final String summary;
  final double completion;
}

class ProjectLifecycleAssessment {
  const ProjectLifecycleAssessment({
    required this.stages,
    required this.workPackageCount,
    required this.scheduleActivityCount,
    required this.costLineCount,
    required this.controlAccountCount,
    required this.openFeedbackCount,
    required this.traceability,
    required this.timePhasedCostLineCount,
    required this.timePhasedBudget,
    required this.timePhasedBaselineReady,
    required this.evmReady,
  });

  final List<LifecycleStageAssessment> stages;
  final int workPackageCount;
  final int scheduleActivityCount;
  final int costLineCount;
  final int controlAccountCount;
  final int openFeedbackCount;
  final List<WorkPackageTraceability> traceability;
  final int timePhasedCostLineCount;
  final List<TimePhasedBudgetPeriod> timePhasedBudget;
  final bool timePhasedBaselineReady;
  final bool evmReady;

  /// Null when the stage has no assessment record (callers must handle).
  LifecycleStageAssessment? stage(ProjectLifecycleStage stage) =>
      stages.where((item) => item.stage == stage).firstOrNull;

  bool get hasIterativeFeedback => openFeedbackCount > 0;

  int get fullyTracedWorkPackageCount =>
      traceability.where((item) => item.isFullyTraced).length;
}

class TimePhasedBudgetPeriod {
  const TimePhasedBudgetPeriod({required this.period, required this.amount});

  final DateTime period;
  final double amount;
}

/// A single row in the scope–schedule–cost control-account structure.
class WorkPackageTraceability {
  const WorkPackageTraceability({
    required this.wbsNodeId,
    required this.wbsCode,
    required this.name,
    required this.activityCount,
    required this.hasDates,
    required this.hasResources,
    required this.estimatedCost,
    required this.hasControlAccount,
  });

  final String wbsNodeId;
  final String wbsCode;
  final String name;
  final int activityCount;
  final bool hasDates;
  final bool hasResources;
  final double estimatedCost;
  final bool hasControlAccount;

  bool get hasActivities => activityCount > 0;
  bool get hasCost => estimatedCost > 0;
  bool get isFullyTraced => hasActivities &&
      hasDates &&
      hasResources &&
      hasCost &&
      hasControlAccount;
}

/// Read-only lifecycle intelligence. It never mutates module data, so every
/// screen can use the same readiness and traceability rules.
class ProjectLifecycleService {
  ProjectLifecycleService._();

  static ProjectLifecycleAssessment assess({
    required ProjectDataModel project,
    required WBS? wbs,
    required Schedule? schedule,
    required CostEstimate? costEstimate,
    required ProjectControlsState controls,
  }) {
    final scopeItems = project.withinScopeItems
        .where((item) => item.description.trim().isNotEmpty)
        .length;
    final scopeNarrative = project.projectObjective.trim().isNotEmpty ||
        project.solutionDescription.trim().isNotEmpty ||
        project.businessCase.trim().isNotEmpty;
    final scopeReady = project.projectName.trim().isNotEmpty &&
        scopeNarrative &&
        scopeItems > 0;

    final wbsLeaves = <WBSNode>[];
    if (wbs != null) {
      void walk(WBSNode node) {
        if (node.level != WBSLevel.level0 && node.children.isEmpty) {
          wbsLeaves.add(node);
        }
        for (final child in node.children) {
          walk(child);
        }
      }

      walk(wbs.level0);
    }
    final workPackageCount = wbsLeaves.length;

    final activities = <ScheduleActivity>[];
    if (schedule != null) {
      void walkActivities(ScheduleActivity activity, {bool isRoot = false}) {
        if (!isRoot) activities.add(activity);
        for (final child in activity.children) {
          walkActivities(child);
        }
      }

      for (var index = 0; index < schedule.activities.length; index++) {
        walkActivities(schedule.activities[index], isRoot: index == 0);
      }
    }
    final linkedActivities = activities
        .where((activity) =>
            activity.wbsNodeId != null && activity.wbsNodeId!.isNotEmpty)
        .length;
    final scheduledActivities = activities
        .where((activity) =>
            activity.duration != null ||
            activity.startDate != null ||
            activity.endDate != null)
        .length;
    final ownedActivities = activities
        .where((activity) => activity.owner?.trim().isNotEmpty ?? false)
        .length;

    final activitiesByWbs = <String, List<ScheduleActivity>>{};
    for (final activity in activities) {
      for (final key in [activity.wbsNodeId, activity.wbsCode]) {
        if (key == null || key.trim().isEmpty) continue;
        activitiesByWbs.putIfAbsent(key, () => []).add(activity);
      }
    }

    final costLines = costEstimate?.lines ?? const <CostLine>[];
    final wbsIds = wbsLeaves.map((node) => node.id).toSet();
    final wbsCodes = wbsLeaves.map((node) => node.code).toSet();
    final linkedCostLines = costLines.where((line) {
      final ref = line.wbsRef?.trim() ?? '';
      return ref.isNotEmpty && (wbsIds.contains(ref) || wbsCodes.contains(ref));
    }).length;
    final scheduledCostLines =
        costLines.where((line) => line.inSchedule).length;
    final costByWbs = <String, double>{};
    for (final line in costLines) {
      final ref = line.wbsRef?.trim() ?? '';
      if (ref.isEmpty) continue;
      costByWbs[ref] = (costByWbs[ref] ?? 0) + line.total;
    }

    final controlAccounts = controls.workPackages;
    final tracedControls = controlAccounts.where((workPackage) {
      final hasWbs = (workPackage.wbsNodeId?.isNotEmpty ?? false) ||
          wbsCodes.contains(workPackage.wbsCode);
      final hasSchedule = workPackage.scheduleActivityId?.isNotEmpty ?? false;
      return hasWbs && hasSchedule;
    }).length;
    final budgetedControls = controlAccounts
        .where((workPackage) => workPackage.currentBudget > 0)
        .length;
    final controlsByWbs = <String, WorkPackageControl>{};
    for (final account in controlAccounts) {
      if (account.wbsNodeId?.isNotEmpty ?? false) {
        controlsByWbs[account.wbsNodeId!] = account;
      }
      if (account.wbsCode.isNotEmpty) {
        controlsByWbs[account.wbsCode] = account;
      }
    }

    final traceability = wbsLeaves.map((node) {
      final linkedActivitiesForNode = <ScheduleActivity>{
        ...?activitiesByWbs[node.id],
        ...?activitiesByWbs[node.code],
      };
      final hasDates = linkedActivitiesForNode.any((activity) =>
          activity.startDate != null && activity.endDate != null);
      final hasResources = linkedActivitiesForNode
              .any((activity) => activity.owner?.trim().isNotEmpty ?? false) ||
          controls.resourceAllocations.isNotEmpty;
      return WorkPackageTraceability(
        wbsNodeId: node.id,
        wbsCode: node.code,
        name: node.name,
        activityCount: linkedActivitiesForNode.length,
        hasDates: hasDates,
        hasResources: hasResources,
        estimatedCost: (costByWbs[node.id] ?? 0) +
            (node.id == node.code ? 0 : (costByWbs[node.code] ?? 0)),
        hasControlAccount: controlsByWbs.containsKey(node.id) ||
            controlsByWbs.containsKey(node.code),
      );
    }).toList();

    final timePhasedCostLineCount = costLines.where((line) {
      final ref = line.wbsRef?.trim() ?? '';
      if (ref.isEmpty) return false;
      return (activitiesByWbs[ref] ?? const <ScheduleActivity>[]).any(
        (activity) => activity.startDate != null && activity.endDate != null,
      );
    }).length;
    final timePhasedBudget = _buildTimePhasedBudget(
      costLines: costLines,
      activitiesByWbs: activitiesByWbs,
    );
    final timePhasedBaselineReady = costLines.isNotEmpty &&
        timePhasedCostLineCount == costLines.length &&
        (costEstimate?.status == EstimateStatus.baselined ||
            costEstimate?.status == EstimateStatus.rebaselined);
    final evmReady = timePhasedBaselineReady &&
        controls.isBaselined &&
        controlAccounts.isNotEmpty &&
        controlAccounts.every((account) =>
            account.currentBudget > 0 && account.plannedValue > 0);

    final wbsCompletion = workPackageCount == 0 ? 0.0 : 1.0;
    final scheduleLinkCoverage = _ratio(linkedActivities, workPackageCount);
    final scheduleDetailCoverage =
        _ratio(scheduledActivities, activities.length);
    final scheduleCompletion =
        (scheduleLinkCoverage * .65 + scheduleDetailCoverage * .35)
            .clamp(0.0, 1.0);
    final resourceCompletion = controls.resourceAllocations.isNotEmpty
        ? 1.0
        : _ratio(ownedActivities, activities.length);
    final costTraceCoverage = _ratio(linkedCostLines, costLines.length);
    final costScheduleCoverage = _ratio(scheduledCostLines, costLines.length);
    final costCompletion =
        (costTraceCoverage * .7 + costScheduleCoverage * .3).clamp(0.0, 1.0);
    final controlTraceCoverage = _ratio(tracedControls, controlAccounts.length);
    final controlBudgetCoverage =
        _ratio(budgetedControls, controlAccounts.length);
    final controlCompletion =
        (controlTraceCoverage * .7 + controlBudgetCoverage * .3)
            .clamp(0.0, 1.0);

    final openFeedback = controls.openChangeRequests +
        controls.scheduleVariances
            .where((item) => item.varianceDays != 0)
            .length +
        controls.openIssues.length;
    final wbsReady = scopeReady && workPackageCount > 0;
    final scheduleReady = wbsReady && scheduleCompletion >= .8;
    final resourcesReady = scheduleReady && resourceCompletion >= .8;
    final costReady = resourcesReady && costCompletion >= .8;
    final controlsReady = costReady && controlCompletion >= .8;

    return ProjectLifecycleAssessment(
      stages: [
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.scope,
          state: scopeReady
              ? LifecycleStageState.ready
              : LifecycleStageState.attention,
          label: 'Scope',
          summary: scopeReady
              ? '$scopeItems in-scope items defined'
              : 'Define the objective and in-scope deliverables',
          completion: scopeReady ? 1 : (scopeNarrative ? .5 : 0),
        ),
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.wbs,
          state: workPackageCount == 0
              ? (scopeReady
                  ? LifecycleStageState.attention
                  : LifecycleStageState.blocked)
              : wbsReady
                  ? LifecycleStageState.ready
                  : LifecycleStageState.attention,
          label: 'WBS',
          summary: workPackageCount == 0
              ? 'Break approved scope into work packages'
              : '$workPackageCount work packages',
          completion: wbsCompletion,
        ),
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.schedule,
          state: workPackageCount == 0
              ? LifecycleStageState.blocked
              : scheduleReady
                  ? LifecycleStageState.ready
                  : LifecycleStageState.attention,
          label: 'Schedule',
          summary: activities.isEmpty
              ? 'Create activities from the WBS'
              : '$linkedActivities/${activities.length} activities traced to WBS',
          completion: scheduleCompletion,
        ),
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.resources,
          state: activities.isEmpty
              ? LifecycleStageState.blocked
              : resourcesReady
                  ? LifecycleStageState.ready
                  : LifecycleStageState.attention,
          label: 'Resources',
          summary: controls.resourceAllocations.isNotEmpty
              ? '${controls.resourceAllocations.length} resource allocations'
              : '$ownedActivities/${activities.length} activities have owners',
          completion: resourceCompletion,
        ),
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.cost,
          state: activities.isEmpty
              ? LifecycleStageState.blocked
              : costReady
                  ? LifecycleStageState.ready
                  : LifecycleStageState.attention,
          label: 'Cost',
          summary: costLines.isEmpty
              ? 'Estimate resources and activity costs'
              : '$linkedCostLines/${costLines.length} lines traced to WBS',
          completion: costCompletion,
        ),
        LifecycleStageAssessment(
          stage: ProjectLifecycleStage.controls,
          state: costLines.isEmpty
              ? LifecycleStageState.blocked
              : controlsReady
                  ? LifecycleStageState.ready
                  : LifecycleStageState.attention,
          label: 'Controls',
          summary: controlAccounts.isEmpty
              ? 'Create control accounts from linked work'
              : '$tracedControls/${controlAccounts.length} accounts fully traced',
          completion: controlCompletion,
        ),
      ],
      workPackageCount: workPackageCount,
      scheduleActivityCount: activities.length,
      costLineCount: costLines.length,
      controlAccountCount: controlAccounts.length,
      openFeedbackCount: openFeedback,
      traceability: traceability,
      timePhasedCostLineCount: timePhasedCostLineCount,
      timePhasedBudget: timePhasedBudget,
      timePhasedBaselineReady: timePhasedBaselineReady,
      evmReady: evmReady,
    );
  }

  static double _ratio(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  /// Spreads each scheduled cost line evenly across the calendar months
  /// covered by its linked WBS activities. This creates the initial planned
  /// value profile; controls can later replace it with a finer resource-loaded
  /// curve without changing the WBS traceability key.
  static List<TimePhasedBudgetPeriod> _buildTimePhasedBudget({
    required List<CostLine> costLines,
    required Map<String, List<ScheduleActivity>> activitiesByWbs,
  }) {
    final amounts = <DateTime, double>{};
    for (final line in costLines.where((item) => item.inSchedule)) {
      final ref = line.wbsRef?.trim() ?? '';
      if (ref.isEmpty) continue;
      final dated = (activitiesByWbs[ref] ?? const <ScheduleActivity>[])
          .where((activity) =>
              activity.startDate != null && activity.endDate != null)
          .toList();
      if (dated.isEmpty) continue;
      final start = dated
          .map((activity) => activity.startDate!)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final finish = dated
          .map((activity) => activity.endDate!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final months = <DateTime>[];
      var cursor = DateTime(start.year, start.month);
      final finalMonth = DateTime(finish.year, finish.month);
      while (!cursor.isAfter(finalMonth)) {
        months.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
      if (months.isEmpty) continue;
      final amountPerMonth = line.total / months.length;
      for (final month in months) {
        amounts[month] = (amounts[month] ?? 0) + amountPerMonth;
      }
    }
    final periods = amounts.entries
        .map((entry) =>
            TimePhasedBudgetPeriod(period: entry.key, amount: entry.value))
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    return periods;
  }
}
