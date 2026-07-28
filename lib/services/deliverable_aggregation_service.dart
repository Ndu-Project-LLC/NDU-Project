import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/models/aggregated_deliverable.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/roadmap_deliverable.dart';
import 'package:flutter/material.dart';

/// Service for aggregating deliverables from across all project phases
class DeliverableAggregationService {
  DeliverableAggregationService._();
  static final DeliverableAggregationService instance =
      DeliverableAggregationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Aggregate all deliverables from initiation and planning phases
  Future<List<AggregatedDeliverable>> aggregateAllDeliverables({
    required String projectId,
    DeliverableFilter? filter,
  }) async {
    final List<AggregatedDeliverable> allDeliverables = [];

    // Load project data
    final projectData = await _loadProjectData(projectId);
    if (projectData == null) return [];

    // Aggregate from Initiation Phase
    allDeliverables.addAll(_aggregateFromInitiation(projectData));

    // Aggregate from Front-End Planning Phase
    allDeliverables.addAll(_aggregateFromFrontEndPlanning(projectData));

    // Aggregate from Planning Phase
    allDeliverables.addAll(_aggregateFromPlanning(projectData));

    // Aggregate from Roadmap Deliverables
    final roadmapDeliverables = await _loadRoadmapDeliverables(projectId);
    for (final rd in roadmapDeliverables) {
      allDeliverables
          .add(AggregatedDeliverable.fromRoadmapDeliverable(rd));
    }

    // Apply filter if provided
    if (filter != null) {
      return allDeliverables.where(filter.matches).toList();
    }

    return allDeliverables;
  }

  /// Get deliverables by category
  Future<Map<DeliverableCategory, List<AggregatedDeliverable>>>
      getDeliverablesByCategory({
    required String projectId,
  }) async {
    final allDeliverables =
        await aggregateAllDeliverables(projectId: projectId);

    final grouped = <DeliverableCategory, List<AggregatedDeliverable>>{};
    for (final category in DeliverableCategory.values) {
      grouped[category] = [];
    }

    for (final deliverable in allDeliverables) {
      grouped[deliverable.category]!.add(deliverable);
    }

    return grouped;
  }

  /// Get deliverables by phase
  Future<Map<DeliverablePhase, List<AggregatedDeliverable>>>
      getDeliverablesByPhase({
    required String projectId,
  }) async {
    final allDeliverables =
        await aggregateAllDeliverables(projectId: projectId);

    final grouped = <DeliverablePhase, List<AggregatedDeliverable>>{};
    for (final phase in DeliverablePhase.values) {
      grouped[phase] = [];
    }

    for (final deliverable in allDeliverables) {
      grouped[deliverable.phase]!.add(deliverable);
    }

    return grouped;
  }

  /// Calculate statistics
  Future<DeliverableStatistics> calculateStatistics({
    required String projectId,
  }) async {
    final allDeliverables =
        await aggregateAllDeliverables(projectId: projectId);
    return DeliverableStatistics.calculate(allDeliverables);
  }

  /// Sync deliverable status back to source
  Future<bool> syncDeliverableToSource({
    required String projectId,
    required AggregatedDeliverable deliverable,
    required BuildContext context,
  }) async {
    try {
      switch (deliverable.sourceType) {
        case DeliverableSourceType.roadmapDeliverable:
          return await _syncRoadmapDeliverable(
            projectId: projectId,
            deliverable: deliverable,
          );
        case DeliverableSourceType.milestone:
          return await _syncMilestone(
            projectId: projectId,
            deliverable: deliverable,
          );
        case DeliverableSourceType.requirement:
          return await _syncRequirement(
            projectId: projectId,
            deliverable: deliverable,
          );
        case DeliverableSourceType.wbsItem:
          return await _syncWBSItem(
            projectId: projectId,
            deliverable: deliverable,
          );
        default:
          debugPrint('Unsupported source type for sync: ${deliverable.sourceType}');
          return false;
      }
    } catch (e) {
      debugPrint('Error syncing deliverable: $e');
      return false;
    }
  }

  /// Create a new deliverable in RoadmapDeliverable format
  Future<RoadmapDeliverable> createNewDeliverable({
    required String projectId,
    required String title,
    required String description,
    required DeliverableCategory category,
    String? assignee,
    DateTime? dueDate,
    RoadmapDeliverablePriority priority = RoadmapDeliverablePriority.medium,
    List<String> dependencies = const [],
  }) async {
    final now = DateTime.now();
    final deliverable = RoadmapDeliverable(
      title: title,
      description: description,
      assignee: assignee ?? '',
      dueDate: dueDate,
      priority: priority,
      status: RoadmapDeliverableStatus.notStarted,
      dependencies: dependencies,
      sprintId: 'unassigned',
      order: 0,
      createdById: '',
      createdByEmail: '',
      createdByName: '',
    );

    // Save to roadmap
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('roadmap_deliverables')
        .doc(deliverable.id)
        .set(deliverable.toJson());

    return deliverable;
  }

  // Private methods

  Future<ProjectDataModel?> _loadProjectData(String projectId) async {
    try {
      final doc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return ProjectDataModel.fromJson(data);
    } catch (e) {
      debugPrint('Error loading project data: $e');
      return null;
    }
  }

  List<AggregatedDeliverable> _aggregateFromInitiation(
      ProjectDataModel data) {
    final List<AggregatedDeliverable> deliverables = [];

    // Business Case deliverable
    if (data.businessCase.isNotEmpty) {
      deliverables.add(AggregatedDeliverable(
        id: 'initiation_business_case',
        title: 'Business Case',
        description: data.businessCase,
        phase: DeliverablePhase.initiation,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'business_case',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'business_case',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.critical,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Project Charter
    if (data.charterAssumptions.isNotEmpty ||
        data.charterConstraints.isNotEmpty) {
      deliverables.add(AggregatedDeliverable(
        id: 'initiation_project_charter',
        title: 'Project Charter',
        description: 'Project authorization and objectives',
        phase: DeliverablePhase.initiation,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'project_charter',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'project_charter',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.critical,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Potential Solutions
    for (var i = 0; i < data.potentialSolutions.length; i++) {
      final solution = data.potentialSolutions[i];
      deliverables.add(AggregatedDeliverable(
        id: 'initiation_solution_$i',
        title: solution.title.isNotEmpty ? solution.title : 'Solution ${i + 1}',
        description: solution.description,
        phase: DeliverablePhase.initiation,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'potential_solutions',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'solution_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.high,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Risk Identification
    for (var i = 0; i < data.solutionRisks.length; i++) {
      final risk = data.solutionRisks[i];
      deliverables.add(AggregatedDeliverable(
        id: 'initiation_risk_$i',
        title: risk.solutionTitle.isNotEmpty ? risk.solutionTitle : 'Risk ${i + 1}',
        description: risk.risks.isNotEmpty ? risk.risks.join(', ') : '',
        phase: DeliverablePhase.initiation,
        category: DeliverableCategory.riskCompliance,
        sourceCheckpoint: 'risk_identification',
        sourceType: DeliverableSourceType.risk,
        sourceItemId: 'risk_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.high,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Cost Analysis
    if (data.costAnalysisData != null) {
      deliverables.add(AggregatedDeliverable(
        id: 'initiation_cost_analysis',
        title: 'Cost Benefit Analysis',
        description: 'Financial analysis and metrics',
        phase: DeliverablePhase.initiation,
        category: DeliverableCategory.scheduleCost,
        sourceCheckpoint: 'cost_analysis',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'cost_analysis',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.critical,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    return deliverables;
  }

  List<AggregatedDeliverable> _aggregateFromFrontEndPlanning(
      ProjectDataModel data) {
    final List<AggregatedDeliverable> deliverables = [];

    // Requirements from Front-End Planning
    if (data.frontEndPlanningData.requirements.isNotEmpty) {
      deliverables.add(AggregatedDeliverable(
        id: 'fep_requirements',
        title: 'Project Requirements',
        description: data.frontEndPlanningData.requirements,
        phase: DeliverablePhase.frontEndPlanning,
        category: DeliverableCategory.requirements,
        sourceCheckpoint: 'fep_requirements',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'fep_requirements',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.high,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Front-End Planning Requirement Items
    for (var i = 0; i < data.frontEndPlanningData.requirementItems.length; i++) {
      final req = data.frontEndPlanningData.requirementItems[i];
      deliverables.add(AggregatedDeliverable(
        id: 'fep_requirement_$i',
        title: req.description.isNotEmpty ? req.description.substring(0, 50) : 'Requirement ${i + 1}',
        description: req.description,
        phase: DeliverablePhase.frontEndPlanning,
        category: DeliverableCategory.requirements,
        sourceCheckpoint: 'fep_requirements',
        sourceType: DeliverableSourceType.requirement,
        sourceItemId: 'requirement_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.medium,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Front-End Planning Opportunities
    for (var i = 0; i < data.frontEndPlanningData.opportunityItems.length; i++) {
      final opp = data.frontEndPlanningData.opportunityItems[i];
      deliverables.add(AggregatedDeliverable(
        id: 'fep_opportunity_$i',
        title: opp.opportunity.isNotEmpty ? opp.opportunity : 'Opportunity ${i + 1}',
        description: opp.potentialCostSavings ?? '',
        phase: DeliverablePhase.frontEndPlanning,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'fep_opportunities',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'opportunity_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.low,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    return deliverables;
  }

  List<AggregatedDeliverable> _aggregateFromPlanning(ProjectDataModel data) {
    final List<AggregatedDeliverable> deliverables = [];

    // Planning Goals
    for (var i = 0; i < data.planningGoals.length; i++) {
      final goal = data.planningGoals[i];
      deliverables.add(AggregatedDeliverable(
        id: 'planning_goal_$i',
        title: goal.title,
        description: goal.description,
        phase: DeliverablePhase.planning,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'project_goals_milestones',
        sourceType: DeliverableSourceType.milestone,
        sourceItemId: 'goal_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: goal.priority.contains('High') || goal.priority.contains('Critical')
            ? RoadmapDeliverablePriority.high
            : RoadmapDeliverablePriority.medium,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));

      // Add milestones within goals
      for (var j = 0; j < goal.milestones.length; j++) {
        final milestone = goal.milestones[j];
        deliverables.add(AggregatedDeliverable(
          id: 'planning_milestone_${i}_$j',
          title: milestone.title.isNotEmpty ? milestone.title : 'Milestone ${j + 1}',
          description: 'Milestone for ${goal.title}',
          phase: DeliverablePhase.planning,
          category: DeliverableCategory.governance,
          sourceCheckpoint: 'project_goals_milestones',
          sourceType: DeliverableSourceType.milestone,
          sourceItemId: 'milestone_${i}_$j',
          status: RoadmapDeliverableStatus.completed,
          priority: RoadmapDeliverablePriority.high,
          completionPercent: 100.0,
          dueDate: _parseDate(milestone.deadline),
          createdDate: DateTime.now(),
          lastUpdated: DateTime.now(),
        ));
      }
    }

    // Key Milestones
    for (var i = 0; i < data.keyMilestones.length; i++) {
      final milestone = data.keyMilestones[i];
      deliverables.add(AggregatedDeliverable(
        id: 'key_milestone_$i',
        title: milestone.name,
        description: milestone.comments,
        phase: DeliverablePhase.planning,
        category: DeliverableCategory.governance,
        sourceCheckpoint: 'project_goals_milestones',
        sourceType: DeliverableSourceType.milestone,
        sourceItemId: 'key_milestone_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.high,
        completionPercent: 100.0,
        dueDate: _parseDate(milestone.dueDate),
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Planning Requirements
    for (var i = 0; i < data.planningRequirementItems.length; i++) {
      final req = data.planningRequirementItems[i];
      deliverables.add(AggregatedDeliverable(
        id: 'planning_requirement_$i',
        title: req.plannedText,
        description: 'Owner: ${req.owner}, Priority: ${req.priority}',
        phase: DeliverablePhase.planning,
        category: DeliverableCategory.requirements,
        sourceCheckpoint: 'requirements',
        sourceType: DeliverableSourceType.requirement,
        sourceItemId: 'requirement_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: _parsePriority(req.priority),
        assigneeId: req.owner.isNotEmpty ? req.owner : null,
        assigneeName: req.owner,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // WBS Items
    void addWBSItems(List<WorkItem> items, String parentId) {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        deliverables.add(AggregatedDeliverable(
          id: item.id,
          title: item.title,
          description: item.description,
          phase: DeliverablePhase.planning,
          category: DeliverableCategory.execution,
          sourceCheckpoint: 'work_breakdown_structure',
          sourceType: DeliverableSourceType.wbsItem,
          sourceItemId: item.id,
          status: _parseWBSStatus(item.status),
          priority: RoadmapDeliverablePriority.medium,
          completionPercent: item.status == 'completed' ? 100.0 : 0.0,
          createdDate: DateTime.now(),
          lastUpdated: DateTime.now(),
        ));

        if (item.children.isNotEmpty) {
          addWBSItems(item.children, item.id);
        }
      }
    }

    if (data.wbsTree.isNotEmpty) {
      addWBSItems(data.wbsTree, '');
    }

    // Scope Items
    for (var item in data.withinScopeItems) {
      deliverables.add(AggregatedDeliverable(
        id: item.id,
        title: item.title,
        description: item.description,
        phase: DeliverablePhase.planning,
        category: DeliverableCategory.requirements,
        sourceCheckpoint: 'scope_tracking_plan',
        sourceType: DeliverableSourceType.requirement,
        sourceItemId: item.id,
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.medium,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    // Interface Entries
    for (var i = 0; i < data.interfaceEntries.length; i++) {
      final interface = data.interfaceEntries[i];
      deliverables.add(AggregatedDeliverable(
        id: 'interface_$i',
        title: interface.boundary.isNotEmpty ? interface.boundary : 'Interface ${i + 1}',
        description: interface.notes,
        phase: DeliverablePhase.planning,
        category: DeliverableCategory.technical,
        sourceCheckpoint: 'interface_management',
        sourceType: DeliverableSourceType.document,
        sourceItemId: 'interface_$i',
        status: RoadmapDeliverableStatus.completed,
        priority: RoadmapDeliverablePriority.medium,
        completionPercent: 100.0,
        createdDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
    }

    return deliverables;
  }

  Future<List<RoadmapDeliverable>> _loadRoadmapDeliverables(
      String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('roadmap_deliverables')
          .get();

      return snapshot.docs
          .map((doc) => RoadmapDeliverable.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error loading roadmap deliverables: $e');
      return [];
    }
  }

  Future<bool> _syncRoadmapDeliverable({
    required String projectId,
    required AggregatedDeliverable deliverable,
  }) async {
    try {
      final roadmapDeliverable = RoadmapDeliverable(
        id: deliverable.id,
        title: deliverable.title,
        description: deliverable.description,
        status: deliverable.status,
        priority: deliverable.priority,
        assignee: deliverable.assigneeId ?? '',
        dueDate: deliverable.dueDate,
        dependencies: deliverable.dependencies,
        sprintId: 'unassigned',
        order: deliverable.order,
        notes: deliverable.notes ?? '',
        createdById: '',
        createdByEmail: '',
        createdByName: '',
      );

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('roadmap_deliverables')
          .doc(deliverable.id)
          .set(roadmapDeliverable.toJson(), SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error syncing roadmap deliverable: $e');
      return false;
    }
  }

  Future<bool> _syncMilestone({
    required String projectId,
    required AggregatedDeliverable deliverable,
  }) async {
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'keyMilestones': FieldValue.arrayUnion([
          {
            'name': deliverable.title,
            'dueDate': deliverable.dueDate?.toIso8601String(),
            'comments': deliverable.description,
          }
        ])
      });
      return true;
    } catch (e) {
      debugPrint('Error syncing milestone: $e');
      return false;
    }
  }

  Future<bool> _syncRequirement({
    required String projectId,
    required AggregatedDeliverable deliverable,
  }) async {
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'planningRequirementItems': FieldValue.arrayUnion([
          {
            'id': deliverable.sourceItemId,
            'plannedText': deliverable.title,
            'priority': deliverable.priorityLabel,
            'owner': deliverable.assigneeName ?? '',
          }
        ])
      });
      return true;
    } catch (e) {
      debugPrint('Error syncing requirement: $e');
      return false;
    }
  }

  Future<bool> _syncWBSItem({
    required String projectId,
    required AggregatedDeliverable deliverable,
  }) async {
    try {
      // WBS items are stored in a nested structure
      // This would require more complex logic to update specific items
      debugPrint('WBS sync not fully implemented');
      return false;
    } catch (e) {
      debugPrint('Error syncing WBS item: $e');
      return false;
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  RoadmapDeliverableStatus _parseWBSStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return RoadmapDeliverableStatus.completed;
      case 'in_progress':
      case 'in-progress':
        return RoadmapDeliverableStatus.inProgress;
      case 'blocked':
        return RoadmapDeliverableStatus.blocked;
      case 'at_risk':
      case 'at-risk':
        return RoadmapDeliverableStatus.atRisk;
      default:
        return RoadmapDeliverableStatus.notStarted;
    }
  }

  RoadmapDeliverablePriority _parsePriority(String priority) {
    final p = priority.toLowerCase();
    if (p.contains('critical') || p.contains('urgent')) {
      return RoadmapDeliverablePriority.critical;
    } else if (p.contains('high')) {
      return RoadmapDeliverablePriority.high;
    } else if (p.contains('low')) {
      return RoadmapDeliverablePriority.low;
    }
    return RoadmapDeliverablePriority.medium;
  }
}
