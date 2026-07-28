/// Change Management — Extended models for the CM module
///
/// Per the Change Management Process docs (Waterfall: 313 paragraphs,
/// Agile: 338 paragraphs) + supporting document tables (24 WF docs,
/// 30 Agile docs).

import 'package:flutter/material.dart';

// ─── Change Types (10 Waterfall categories, 7 Agile categories) ──────────

enum CMChangeType {
  // Waterfall
  scope,
  schedule,
  cost,
  resource,
  procurement,
  contract,
  risk,
  quality,
  regulatory,
  // Agile
  product,
  requirements,
  technical,
  defect,
  compliance,
  operational,
}

extension CMChangeTypeMeta on CMChangeType {
  String get label => switch (this) {
        CMChangeType.scope => 'Scope Change',
        CMChangeType.schedule => 'Schedule Change',
        CMChangeType.cost => 'Cost Change',
        CMChangeType.resource => 'Resource Change',
        CMChangeType.procurement => 'Procurement Change',
        CMChangeType.contract => 'Contract Change',
        CMChangeType.risk => 'Risk Change',
        CMChangeType.quality => 'Quality Change',
        CMChangeType.regulatory => 'Regulatory Change',
        CMChangeType.product => 'Product Change',
        CMChangeType.requirements => 'Requirements Change',
        CMChangeType.technical => 'Technical Change',
        CMChangeType.defect => 'Defect Change',
        CMChangeType.compliance => 'Compliance Change',
        CMChangeType.operational => 'Operational Change',
      };

  IconData get icon => switch (this) {
        CMChangeType.scope => Icons.account_tree_outlined,
        CMChangeType.schedule => Icons.schedule_outlined,
        CMChangeType.cost => Icons.attach_money,
        CMChangeType.resource => Icons.group_outlined,
        CMChangeType.procurement => Icons.shopping_bag_outlined,
        CMChangeType.contract => Icons.assignment_outlined,
        CMChangeType.risk => Icons.warning_amber_rounded,
        CMChangeType.quality => Icons.verified_outlined,
        CMChangeType.regulatory => Icons.gavel_outlined,
        CMChangeType.product => Icons.inventory_2_outlined,
        CMChangeType.requirements => Icons.list_alt_outlined,
        CMChangeType.technical => Icons.code,
        CMChangeType.defect => Icons.bug_report_outlined,
        CMChangeType.compliance => Icons.security_outlined,
        CMChangeType.operational => Icons.settings_outlined,
      };

  Color get color => switch (this) {
        CMChangeType.scope => const Color(0xFF6366F1),
        CMChangeType.schedule => const Color(0xFF8B5CF6),
        CMChangeType.cost => const Color(0xFFD97706),
        CMChangeType.resource => const Color(0xFF06B6D4),
        CMChangeType.procurement => const Color(0xFF10B981),
        CMChangeType.contract => const Color(0xFF3B82F6),
        CMChangeType.risk => const Color(0xFFEF4444),
        CMChangeType.quality => const Color(0xFF14B8A6),
        CMChangeType.regulatory => const Color(0xFF6B7280),
        CMChangeType.product => const Color(0xFFF59E0B),
        CMChangeType.requirements => const Color(0xFFEC4899),
        CMChangeType.technical => const Color(0xFF6366F1),
        CMChangeType.defect => const Color(0xFFEF4444),
        CMChangeType.compliance => const Color(0xFF6B7280),
        CMChangeType.operational => const Color(0xFF06B6D4),
      };
}

// ─── Change Status ────────────────────────────────────────────────────────

enum CMStatus {
  draft,
  submitted,
  underReview,
  pendingApproval,
  approved,
  rejected,
  returned,
  implemented,
  closed,
  emergency,
}

extension CMStatusMeta on CMStatus {
  String get label => switch (this) {
        CMStatus.draft => 'Draft',
        CMStatus.submitted => 'Submitted',
        CMStatus.underReview => 'Under Review',
        CMStatus.pendingApproval => 'Pending Approval',
        CMStatus.approved => 'Approved',
        CMStatus.rejected => 'Rejected',
        CMStatus.returned => 'Returned for Revision',
        CMStatus.implemented => 'Implemented',
        CMStatus.closed => 'Closed',
        CMStatus.emergency => 'Emergency',
      };

  Color get color => switch (this) {
        CMStatus.draft => const Color(0xFF6B7280),
        CMStatus.submitted => const Color(0xFF3B82F6),
        CMStatus.underReview => const Color(0xFFF59E0B),
        CMStatus.pendingApproval => const Color(0xFF8B5CF6),
        CMStatus.approved => const Color(0xFF10B981),
        CMStatus.rejected => const Color(0xFFEF4444),
        CMStatus.returned => const Color(0xFFEC4899),
        CMStatus.implemented => const Color(0xFF06B6D4),
        CMStatus.closed => const Color(0xFF6B7280),
        CMStatus.emergency => const Color(0xFFDC2626),
      };

  Color get bgColor => color.withValues(alpha: 0.08);
}

// ─── Priority ─────────────────────────────────────────────────────────────

enum CMPriority { low, medium, high, critical, emergency }

extension CMPriorityMeta on CMPriority {
  String get label => switch (this) {
        CMPriority.low => 'Low',
        CMPriority.medium => 'Medium',
        CMPriority.high => 'High',
        CMPriority.critical => 'Critical',
        CMPriority.emergency => 'Emergency',
      };

  Color get color => switch (this) {
        CMPriority.low => const Color(0xFF10B981),
        CMPriority.medium => const Color(0xFF3B82F6),
        CMPriority.high => const Color(0xFFF59E0B),
        CMPriority.critical => const Color(0xFFEF4444),
        CMPriority.emergency => const Color(0xFFDC2626),
      };
}

// ─── Approval Decision ───────────────────────────────────────────────────

enum ApprovalDecision {
  pending,
  approved,
  rejected,
  requestInfo,
  returnRevision,
  delegated,
  escalated,
}

extension ApprovalDecisionMeta on ApprovalDecision {
  String get label => switch (this) {
        ApprovalDecision.pending => 'Pending',
        ApprovalDecision.approved => 'Approved',
        ApprovalDecision.rejected => 'Rejected',
        ApprovalDecision.requestInfo => 'Request Info',
        ApprovalDecision.returnRevision => 'Return for Revision',
        ApprovalDecision.delegated => 'Delegated',
        ApprovalDecision.escalated => 'Escalated',
      };

  IconData get icon => switch (this) {
        ApprovalDecision.pending => Icons.hourglass_top,
        ApprovalDecision.approved => Icons.check_circle,
        ApprovalDecision.rejected => Icons.cancel,
        ApprovalDecision.requestInfo => Icons.help_outline,
        ApprovalDecision.returnRevision => Icons.undo,
        ApprovalDecision.delegated => Icons.forward,
        ApprovalDecision.escalated => Icons.arrow_upward,
      };

  Color get color => switch (this) {
        ApprovalDecision.pending => const Color(0xFFF59E0B),
        ApprovalDecision.approved => const Color(0xFF10B981),
        ApprovalDecision.rejected => const Color(0xFFEF4444),
        ApprovalDecision.requestInfo => const Color(0xFF3B82F6),
        ApprovalDecision.returnRevision => const Color(0xFFEC4899),
        ApprovalDecision.delegated => const Color(0xFF8B5CF6),
        ApprovalDecision.escalated => const Color(0xFFDC2626),
      };
}

// ─── Impact Assessment (15 dimensions) ────────────────────────────────────

class ImpactDimension {
  final String name;
  final String? impact;
  final double? scheduleDays;
  final double? costAmount;
  final bool isCritical;
  // Editable fields for the Impact Assessment Detail tab
  final int impactLevel; // 0-5 slider value
  final String? narrative;
  final String? owner;
  final DateTime? dueDate;

  const ImpactDimension({
    required this.name,
    this.impact,
    this.scheduleDays,
    this.costAmount,
    this.isCritical = false,
    this.impactLevel = 0,
    this.narrative,
    this.owner,
    this.dueDate,
  });

  ImpactDimension copyWith({
    String? name,
    String? impact,
    double? scheduleDays,
    double? costAmount,
    bool? isCritical,
    int? impactLevel,
    String? narrative,
    String? owner,
    DateTime? dueDate,
  }) {
    return ImpactDimension(
      name: name ?? this.name,
      impact: impact ?? this.impact,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      costAmount: costAmount ?? this.costAmount,
      isCritical: isCritical ?? this.isCritical,
      impactLevel: impactLevel ?? this.impactLevel,
      narrative: narrative ?? this.narrative,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  bool get hasImpact =>
      (impact?.isNotEmpty ?? false) ||
      (scheduleDays ?? 0) != 0 ||
      (costAmount ?? 0) != 0 ||
      impactLevel > 0;
}

class FullImpactAssessment {
  final ImpactDimension scope;
  final ImpactDimension schedule;
  final ImpactDimension cost;
  final ImpactDimension resources;
  final ImpactDimension procurement;
  final ImpactDimension contracts;
  final ImpactDimension risks;
  final ImpactDimension quality;
  final ImpactDimension safety;
  final ImpactDimension stakeholders;
  final ImpactDimension funding;
  final ImpactDimension benefits;
  final ImpactDimension dependencies;
  final ImpactDimension interfaces;
  final ImpactDimension technical;

  const FullImpactAssessment({
    this.scope = const ImpactDimension(name: 'Scope'),
    this.schedule = const ImpactDimension(name: 'Schedule'),
    this.cost = const ImpactDimension(name: 'Cost'),
    this.resources = const ImpactDimension(name: 'Resources'),
    this.procurement = const ImpactDimension(name: 'Procurement'),
    this.contracts = const ImpactDimension(name: 'Contracts'),
    this.risks = const ImpactDimension(name: 'Risks'),
    this.quality = const ImpactDimension(name: 'Quality'),
    this.safety = const ImpactDimension(name: 'Safety'),
    this.stakeholders = const ImpactDimension(name: 'Stakeholders'),
    this.funding = const ImpactDimension(name: 'Funding'),
    this.benefits = const ImpactDimension(name: 'Benefits'),
    this.dependencies = const ImpactDimension(name: 'Dependencies'),
    this.interfaces = const ImpactDimension(name: 'Interfaces'),
    this.technical = const ImpactDimension(name: 'Technical'),
  });

  List<ImpactDimension> get all => [
        scope, schedule, cost, resources, procurement, contracts,
        risks, quality, safety, stakeholders, funding, benefits,
        dependencies, interfaces, technical,
      ];

  double get totalScheduleImpact =>
      all.fold(0, (sum, d) => sum + (d.scheduleDays ?? 0));

  double get totalCostImpact =>
      all.fold(0, (sum, d) => sum + (d.costAmount ?? 0));

  int get impactedCount => all.where((d) => d.hasImpact).length;

  bool get requiresRebaseline =>
      totalCostImpact > 0 || totalScheduleImpact > 0;

  /// Weighted-average composite impact score across all 15 dimensions.
  /// Scope / Schedule / Cost carry weight 2.0 (primary constraints);
  /// all other dimensions carry weight 1.0. Returns a value in [0, 5].
  double get compositeImpactScore {
    double weightedSum = 0;
    double weightSum = 0;
    for (final d in all) {
      final w = (d.name == 'Scope' ||
              d.name == 'Schedule' ||
              d.name == 'Cost')
          ? 2.0
          : 1.0;
      weightedSum += d.impactLevel * w;
      weightSum += w;
    }
    return weightSum == 0 ? 0 : weightedSum / weightSum;
  }

  /// Returns a new assessment with the dimension at [index] replaced.
  FullImpactAssessment updateDimension(int index, ImpactDimension dim) {
    final dims = all.toList();
    dims[index] = dim;
    return copyWith(
      scope: dims[0],
      schedule: dims[1],
      cost: dims[2],
      resources: dims[3],
      procurement: dims[4],
      contracts: dims[5],
      risks: dims[6],
      quality: dims[7],
      safety: dims[8],
      stakeholders: dims[9],
      funding: dims[10],
      benefits: dims[11],
      dependencies: dims[12],
      interfaces: dims[13],
      technical: dims[14],
    );
  }

  FullImpactAssessment copyWith({
    ImpactDimension? scope,
    ImpactDimension? schedule,
    ImpactDimension? cost,
    ImpactDimension? resources,
    ImpactDimension? procurement,
    ImpactDimension? contracts,
    ImpactDimension? risks,
    ImpactDimension? quality,
    ImpactDimension? safety,
    ImpactDimension? stakeholders,
    ImpactDimension? funding,
    ImpactDimension? benefits,
    ImpactDimension? dependencies,
    ImpactDimension? interfaces,
    ImpactDimension? technical,
  }) {
    return FullImpactAssessment(
      scope: scope ?? this.scope,
      schedule: schedule ?? this.schedule,
      cost: cost ?? this.cost,
      resources: resources ?? this.resources,
      procurement: procurement ?? this.procurement,
      contracts: contracts ?? this.contracts,
      risks: risks ?? this.risks,
      quality: quality ?? this.quality,
      safety: safety ?? this.safety,
      stakeholders: stakeholders ?? this.stakeholders,
      funding: funding ?? this.funding,
      benefits: benefits ?? this.benefits,
      dependencies: dependencies ?? this.dependencies,
      interfaces: interfaces ?? this.interfaces,
      technical: technical ?? this.technical,
    );
  }
}

// ─── Approval Role ───────────────────────────────────────────────────────

enum ApprovalRole {
  projectManager,
  projectControls,
  engineering,
  quality,
  procurement,
  finance,
  sponsor,
  safetyOfficer,
  regulatory,
  changeBoard,
}

extension ApprovalRoleMeta on ApprovalRole {
  String get label => switch (this) {
        ApprovalRole.projectManager => 'Project Manager',
        ApprovalRole.projectControls => 'Project Controls',
        ApprovalRole.engineering => 'Engineering Lead',
        ApprovalRole.quality => 'Quality Manager',
        ApprovalRole.procurement => 'Procurement Lead',
        ApprovalRole.finance => 'Finance',
        ApprovalRole.sponsor => 'Sponsor',
        ApprovalRole.safetyOfficer => 'Safety Officer',
        ApprovalRole.regulatory => 'Regulatory Authority',
        ApprovalRole.changeBoard => 'Change Control Board',
      };

  IconData get icon => switch (this) {
        ApprovalRole.projectManager => Icons.engineering_outlined,
        ApprovalRole.projectControls => Icons.assignment_outlined,
        ApprovalRole.engineering => Icons.build_circle_outlined,
        ApprovalRole.quality => Icons.verified_outlined,
        ApprovalRole.procurement => Icons.shopping_bag_outlined,
        ApprovalRole.finance => Icons.account_balance_outlined,
        ApprovalRole.sponsor => Icons.star_outline,
        ApprovalRole.safetyOfficer => Icons.health_and_safety_outlined,
        ApprovalRole.regulatory => Icons.gavel_outlined,
        ApprovalRole.changeBoard => Icons.groups_2_outlined,
      };
}

// ─── Approval Step (configurable) ─────────────────────────────────────────

class CMApprovalStep {
  final String id;
  final String roleLabel;
  final ApprovalRole? role;
  final String? assigneeName;
  final ApprovalDecision decision;
  final DateTime? decidedAt;
  final String? comments;
  final bool isParallel;
  // Workflow builder fields
  final DateTime? dueDate;
  final String? escalationTarget;
  final String? escalationReason;
  final String? delegatedFrom;

  const CMApprovalStep({
    required this.id,
    required this.roleLabel,
    this.role,
    this.assigneeName,
    this.decision = ApprovalDecision.pending,
    this.decidedAt,
    this.comments,
    this.isParallel = false,
    this.dueDate,
    this.escalationTarget,
    this.escalationReason,
    this.delegatedFrom,
  });

  bool get isTerminal =>
      decision == ApprovalDecision.approved ||
      decision == ApprovalDecision.rejected ||
      decision == ApprovalDecision.delegated ||
      decision == ApprovalDecision.escalated ||
      decision == ApprovalDecision.returnRevision ||
      decision == ApprovalDecision.requestInfo;

  CMApprovalStep copyWith({
    ApprovalDecision? decision,
    DateTime? decidedAt,
    String? comments,
    String? assigneeName,
    DateTime? dueDate,
    String? escalationTarget,
    String? escalationReason,
    String? delegatedFrom,
  }) {
    return CMApprovalStep(
      id: id,
      roleLabel: roleLabel,
      role: role,
      assigneeName: assigneeName ?? this.assigneeName,
      decision: decision ?? this.decision,
      decidedAt: decidedAt ?? this.decidedAt,
      comments: comments ?? this.comments,
      isParallel: isParallel,
      dueDate: dueDate ?? this.dueDate,
      escalationTarget: escalationTarget ?? this.escalationTarget,
      escalationReason: escalationReason ?? this.escalationReason,
      delegatedFrom: delegatedFrom ?? this.delegatedFrom,
    );
  }
}

// ─── Implementation Status ────────────────────────────────────────────────

enum ImplementationStatus { todo, inProgress, done }

extension ImplementationStatusMeta on ImplementationStatus {
  String get label => switch (this) {
        ImplementationStatus.todo => 'To-Do',
        ImplementationStatus.inProgress => 'In Progress',
        ImplementationStatus.done => 'Done',
      };

  Color get color => switch (this) {
        ImplementationStatus.todo => const Color(0xFF6B7280),
        ImplementationStatus.inProgress => const Color(0xFFF59E0B),
        ImplementationStatus.done => const Color(0xFF10B981),
      };

  IconData get icon => switch (this) {
        ImplementationStatus.todo => Icons.radio_button_unchecked,
        ImplementationStatus.inProgress => Icons.pending,
        ImplementationStatus.done => Icons.check_circle,
      };
}

// ─── Implementation Task (per affected work package) ──────────────────────

class ImplementationTask {
  final String id;
  final String workPackageId;
  final String workPackageName;
  final ImplementationStatus status;
  final String? assignee;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? notes;

  const ImplementationTask({
    required this.id,
    required this.workPackageId,
    required this.workPackageName,
    this.status = ImplementationStatus.todo,
    this.assignee,
    this.dueDate,
    this.completedAt,
    this.notes,
  });

  ImplementationTask copyWith({
    ImplementationStatus? status,
    String? assignee,
    DateTime? dueDate,
    DateTime? completedAt,
    String? notes,
  }) {
    return ImplementationTask(
      id: id,
      workPackageId: workPackageId,
      workPackageName: workPackageName,
      status: status ?? this.status,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}

// ─── Full Change Request ─────────────────────────────────────────────────

class CMChangeRequest {
  final String id;
  final String crNumber;
  final String title;
  final String description;
  final CMChangeType changeType;
  final CMPriority priority;
  final CMStatus status;
  final String submittedBy;
  final DateTime dateSubmitted;
  final DateTime? requestedCompletion;
  final String businessJustification;
  final String? rootCause;
  final FullImpactAssessment impact;
  final List<CMApprovalStep> approvalSteps;
  final int currentStepIndex;
  final bool isEmergency;
  final bool isAgileRoutineRefinement;
  final List<String> affectedRegisters;
  final List<String> affectedBaselines;
  final double? contingencyUsed;
  final double? reserveUsed;
  final bool triggersRebaseline;
  final DateTime? approvedAt;
  final DateTime? implementedAt;
  final DateTime? closedAt;
  final String? implementationNotes;
  final String? closureNotes;
  // CR creation form + implementation fields
  final String? alternativesConsidered;
  final List<String> affectedWorkPackages;
  final int deliverablesAdded;
  final int deliverablesModified;
  final int deliverablesRemoved;
  final double? initialCostEstimate;
  final int? scheduleDaysImpact;
  final double? contingencyDrawdownRequested;
  final double? reserveDrawdownRequested;
  final List<ImplementationTask> implementationTasks;

  const CMChangeRequest({
    required this.id,
    required this.crNumber,
    required this.title,
    required this.description,
    required this.changeType,
    required this.priority,
    required this.status,
    required this.submittedBy,
    required this.dateSubmitted,
    this.requestedCompletion,
    required this.businessJustification,
    this.rootCause,
    required this.impact,
    required this.approvalSteps,
    this.currentStepIndex = 0,
    this.isEmergency = false,
    this.isAgileRoutineRefinement = false,
    required this.affectedRegisters,
    required this.affectedBaselines,
    this.contingencyUsed,
    this.reserveUsed,
    this.triggersRebaseline = false,
    this.approvedAt,
    this.implementedAt,
    this.closedAt,
    this.implementationNotes,
    this.closureNotes,
    this.alternativesConsidered,
    this.affectedWorkPackages = const [],
    this.deliverablesAdded = 0,
    this.deliverablesModified = 0,
    this.deliverablesRemoved = 0,
    this.initialCostEstimate,
    this.scheduleDaysImpact,
    this.contingencyDrawdownRequested,
    this.reserveDrawdownRequested,
    this.implementationTasks = const [],
  });

  CMChangeRequest copyWith({
    String? id,
    String? crNumber,
    String? title,
    String? description,
    CMChangeType? changeType,
    CMPriority? priority,
    CMStatus? status,
    String? submittedBy,
    DateTime? dateSubmitted,
    DateTime? requestedCompletion,
    String? businessJustification,
    String? rootCause,
    FullImpactAssessment? impact,
    List<CMApprovalStep>? approvalSteps,
    int? currentStepIndex,
    bool? isEmergency,
    bool? isAgileRoutineRefinement,
    List<String>? affectedRegisters,
    List<String>? affectedBaselines,
    double? contingencyUsed,
    double? reserveUsed,
    bool? triggersRebaseline,
    DateTime? approvedAt,
    DateTime? implementedAt,
    DateTime? closedAt,
    String? implementationNotes,
    String? closureNotes,
    String? alternativesConsidered,
    List<String>? affectedWorkPackages,
    int? deliverablesAdded,
    int? deliverablesModified,
    int? deliverablesRemoved,
    double? initialCostEstimate,
    int? scheduleDaysImpact,
    double? contingencyDrawdownRequested,
    double? reserveDrawdownRequested,
    List<ImplementationTask>? implementationTasks,
  }) {
    return CMChangeRequest(
      id: id ?? this.id,
      crNumber: crNumber ?? this.crNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      changeType: changeType ?? this.changeType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      submittedBy: submittedBy ?? this.submittedBy,
      dateSubmitted: dateSubmitted ?? this.dateSubmitted,
      requestedCompletion: requestedCompletion ?? this.requestedCompletion,
      businessJustification: businessJustification ?? this.businessJustification,
      rootCause: rootCause ?? this.rootCause,
      impact: impact ?? this.impact,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isEmergency: isEmergency ?? this.isEmergency,
      isAgileRoutineRefinement: isAgileRoutineRefinement ?? this.isAgileRoutineRefinement,
      affectedRegisters: affectedRegisters ?? this.affectedRegisters,
      affectedBaselines: affectedBaselines ?? this.affectedBaselines,
      contingencyUsed: contingencyUsed ?? this.contingencyUsed,
      reserveUsed: reserveUsed ?? this.reserveUsed,
      triggersRebaseline: triggersRebaseline ?? this.triggersRebaseline,
      approvedAt: approvedAt ?? this.approvedAt,
      implementedAt: implementedAt ?? this.implementedAt,
      closedAt: closedAt ?? this.closedAt,
      implementationNotes: implementationNotes ?? this.implementationNotes,
      closureNotes: closureNotes ?? this.closureNotes,
      alternativesConsidered: alternativesConsidered ?? this.alternativesConsidered,
      affectedWorkPackages: affectedWorkPackages ?? this.affectedWorkPackages,
      deliverablesAdded: deliverablesAdded ?? this.deliverablesAdded,
      deliverablesModified: deliverablesModified ?? this.deliverablesModified,
      deliverablesRemoved: deliverablesRemoved ?? this.deliverablesRemoved,
      initialCostEstimate: initialCostEstimate ?? this.initialCostEstimate,
      scheduleDaysImpact: scheduleDaysImpact ?? this.scheduleDaysImpact,
      contingencyDrawdownRequested: contingencyDrawdownRequested ?? this.contingencyDrawdownRequested,
      reserveDrawdownRequested: reserveDrawdownRequested ?? this.reserveDrawdownRequested,
      implementationTasks: implementationTasks ?? this.implementationTasks,
    );
  }
}

// ─── Audit Entry ──────────────────────────────────────────────────────────

class CMAuditEntry {
  final String id;
  final String user;
  final DateTime timestamp;
  final String action;
  final String? details;
  final String? linkedCRId;
  final String? baselineVersion;

  const CMAuditEntry({
    required this.id,
    required this.user,
    required this.timestamp,
    required this.action,
    this.details,
    this.linkedCRId,
    this.baselineVersion,
  });
}

// ─── Baseline Revision Record ─────────────────────────────────────────────

class BaselineRevisionRecord {
  final int version;
  final DateTime revisionDate;
  final String revisedBy;
  final String linkedCRId;
  final String reason;
  final List<String> updatedBaselines;
  final double? previousBudget;
  final double? revisedBudget;
  final DateTime? previousFinish;
  final DateTime? revisedFinish;
  // Scope-hash tracking for baseline comparison
  final String? previousScopeHash;
  final String? revisedScopeHash;
  final String? approver;

  const BaselineRevisionRecord({
    required this.version,
    required this.revisionDate,
    required this.revisedBy,
    required this.linkedCRId,
    required this.reason,
    required this.updatedBaselines,
    this.previousBudget,
    this.revisedBudget,
    this.previousFinish,
    this.revisedFinish,
    this.previousScopeHash,
    this.revisedScopeHash,
    this.approver,
  });

  BaselineRevisionRecord copyWith({
    int? version,
    DateTime? revisionDate,
    String? revisedBy,
    String? linkedCRId,
    String? reason,
    List<String>? updatedBaselines,
    double? previousBudget,
    double? revisedBudget,
    DateTime? previousFinish,
    DateTime? revisedFinish,
    String? previousScopeHash,
    String? revisedScopeHash,
    String? approver,
  }) {
    return BaselineRevisionRecord(
      version: version ?? this.version,
      revisionDate: revisionDate ?? this.revisionDate,
      revisedBy: revisedBy ?? this.revisedBy,
      linkedCRId: linkedCRId ?? this.linkedCRId,
      reason: reason ?? this.reason,
      updatedBaselines: updatedBaselines ?? this.updatedBaselines,
      previousBudget: previousBudget ?? this.previousBudget,
      revisedBudget: revisedBudget ?? this.revisedBudget,
      previousFinish: previousFinish ?? this.previousFinish,
      revisedFinish: revisedFinish ?? this.revisedFinish,
      previousScopeHash: previousScopeHash ?? this.previousScopeHash,
      revisedScopeHash: revisedScopeHash ?? this.revisedScopeHash,
      approver: approver ?? this.approver,
    );
  }
}
