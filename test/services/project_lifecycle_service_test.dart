import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart'
    as cost;
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/services/project_lifecycle_service.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

void main() {
  const emptyControls = ProjectControlsState(
    deliveryModel: DeliveryModel.waterfall,
    isBaselined: false,
    isExecutionActive: false,
    workPackages: [],
    changeRequests: [],
    baselineHistory: [],
    auditTrail: [],
  );

  test('blocks downstream stages until scope and WBS exist', () {
    final assessment = ProjectLifecycleService.assess(
      project: ProjectDataModel(),
      wbs: null,
      schedule: null,
      costEstimate: null,
      controls: emptyControls,
    );

    expect(
      assessment.stages.map((stage) => stage.stage),
      ProjectLifecycleStage.values,
    );
    expect(
      assessment.stage(ProjectLifecycleStage.wbs)!.state,
      LifecycleStageState.blocked,
    );
    expect(
      assessment.stage(ProjectLifecycleStage.schedule)!.state,
      LifecycleStageState.blocked,
    );
  });

  test('recognizes a WBS-derived and scheduled activity chain', () {
    final project = ProjectDataModel()
      ..projectName = 'Plant Upgrade'
      ..projectObjective = 'Increase production capacity'
      ..withinScopeItems.add(
        PlanningDashboardItem(description: 'Install upgraded line'),
      );
    final now = DateTime(2026, 8, 12);
    const workPackage = WBSNode(
      id: 'wp-1',
      level: WBSLevel.level1,
      code: '1.1',
      name: 'Install line',
      aiGenerated: false,
      children: const [],
    );
    final wbs = WBS(
      id: 'wbs-1',
      projectId: 'project-1',
      projectName: project.projectName,
      framework: WBSFramework.waterfallDeliverable,
      level0: WBSNode(
        id: 'root',
        level: WBSLevel.level0,
        code: '1',
        name: project.projectName,
        aiGenerated: false,
        children: [workPackage],
      ),
      aiSuggestions: const [],
      createdAt: now,
      updatedAt: now,
    );
    final schedule = Schedule(
      id: 'schedule-1',
      projectId: 'project-1',
      projectName: project.projectName,
      basis: createEmptyBasis('WATERFALL'),
      activities: [
        ScheduleActivity(
          id: 'schedule-root',
          level: 0,
          code: '1',
          name: project.projectName,
          type: ActivityType.summary,
          domain: ScheduleDomain.execution,
          dependencies: const [],
          aiGenerated: false,
          children: [
            ScheduleActivity(
              id: 'activity-1',
              wbsNodeId: workPackage.id,
              wbsCode: workPackage.code,
              level: 1,
              code: '1.1',
              name: workPackage.name,
              type: ActivityType.activity,
              domain: ScheduleDomain.execution,
              duration: 10,
              durationUnit: 'days',
              startDate: now,
              endDate: now.add(const Duration(days: 10)),
              owner: 'Construction Team',
              dependencies: const [],
              aiGenerated: false,
              children: const [],
            ),
          ],
        ),
      ],
      status: ScheduleStatus.draft,
      isLocked: false,
      createdAt: now,
      updatedAt: now,
    );
    const costLine = cost.CostLine(
      id: 'cost-1',
      category: cost.CostCategory.construction,
      subCategory: 'Concrete works',
      description: 'Install upgraded line',
      wbsRef: '1.1',
      total: 50000,
      inSchedule: true,
      basisSource: cost.CostSourceType.vendorQuote,
      aiGenerated: false,
    );
    final estimate = cost.CostEstimate(
      id: 'estimate-1',
      projectId: 'project-1',
      projectName: project.projectName,
      className: cost.EstimateClass.class3,
      deliveryModel: cost.DeliveryModel.waterfall,
      status: cost.EstimateStatus.baselined,
      currency: 'USD',
      lines: const [costLine],
      boe: const cost.BasisOfEstimate(
        scopeBasis: 'Approved WBS',
        assumptions: [],
        constraints: [],
        exclusions: [],
        dataSources: [],
        methodology: [],
        accuracyRange: (low: -20, high: 30),
        escalationAssumptions: '',
      ),
      totals: cost.EstimateTotals.empty(),
      access: const [],
      stakeholders: const [],
      aiSuggestions: const [],
      createdAt: now,
      updatedAt: now,
    );
    const controls = ProjectControlsState(
      deliveryModel: DeliveryModel.waterfall,
      isBaselined: true,
      isExecutionActive: false,
      workPackages: const [
        WorkPackageControl(
          id: 'control-1',
          wbsCode: '1.1',
          wbsNodeId: 'wp-1',
          scheduleActivityId: 'activity-1',
          name: 'Install line',
          scopeDescription: 'Install upgraded line',
          deliverables: [],
          acceptanceCriteria: [],
          priority: 'High',
          status: 'Not Started',
          originalBudget: 50000,
          currentBudget: 50000,
          committedCost: 0,
          actualCost: 0,
          earnedValue: 0,
          plannedValue: 50000,
          progressMethod: ProgressMethod.physicalPercent,
        ),
      ],
      changeRequests: const [],
      baselineHistory: const [],
      auditTrail: const [],
    );

    final assessment = ProjectLifecycleService.assess(
      project: project,
      wbs: wbs,
      schedule: schedule,
      costEstimate: estimate,
      controls: controls,
    );

    expect(assessment.stage(ProjectLifecycleStage.scope)!.state,
        LifecycleStageState.ready);
    expect(assessment.stage(ProjectLifecycleStage.wbs)!.state,
        LifecycleStageState.ready);
    expect(assessment.stage(ProjectLifecycleStage.schedule)!.completion, 1);
    expect(assessment.stage(ProjectLifecycleStage.resources)!.state,
        LifecycleStageState.ready);
    expect(assessment.traceability.single.activityCount, 1);
    expect(assessment.traceability.single.hasDates, isTrue);
    expect(assessment.traceability.single.hasResources, isTrue);
    expect(assessment.traceability.single.estimatedCost, 50000);
    expect(assessment.fullyTracedWorkPackageCount, 1);
    expect(assessment.timePhasedBudget.single.amount, 50000);
    expect(assessment.timePhasedBaselineReady, isTrue);
    expect(assessment.evmReady, isTrue);
    expect(assessment.stage(ProjectLifecycleStage.cost)!.state,
        LifecycleStageState.ready);
    expect(assessment.stage(ProjectLifecycleStage.controls)!.state,
        LifecycleStageState.ready);
  });
}
