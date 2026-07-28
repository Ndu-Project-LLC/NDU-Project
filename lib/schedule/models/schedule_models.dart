library;

/// NDU Project — Schedule type system (Dart equivalent)
///
/// Implements both the Agile Schedule Development guidance and the
/// Schedule Development Update Guidance (Waterfall).
///
/// Level convention (extends WBS):
///   Level 0 = Project (root, from WBS)
///   Level 1 = Major Deliverable (from WBS)
///   Level 2 = Epic / Sub-Deliverable (from WBS — stops here in WBS module)
///   Level 3 = Feature / EWP / Procurement Package / CWP
///   Level 4 = Story / Activity
///   Level 5-8 = Task / sub-task (down to one-person bite-sized packages)

enum ScheduleDomain {
  engineering,
  procurement,
  execution,
  construction,
  commissioning;

  String get label => switch (this) {
        ScheduleDomain.engineering => 'Engineering',
        ScheduleDomain.procurement => 'Procurement',
        ScheduleDomain.execution => 'Execution',
        ScheduleDomain.construction => 'Construction',
        ScheduleDomain.commissioning => 'Commissioning',
      };

  int get color => switch (this) {
        ScheduleDomain.engineering => 0xFF3B82F6, // blue
        ScheduleDomain.procurement => 0xFF22C55E, // green
        ScheduleDomain.execution => 0xFFF8BD2A, // yellow/gold
        ScheduleDomain.construction => 0xFF909096, // gray
        ScheduleDomain.commissioning => 0xFFC084FC, // purple
      };

  String get icon => switch (this) {
        ScheduleDomain.engineering => 'engineering',
        ScheduleDomain.procurement => 'shopping_cart',
        ScheduleDomain.execution => 'construction',
        ScheduleDomain.construction => 'foundation',
        ScheduleDomain.commissioning => 'fact_check',
      };
}

enum ActivityType {
  summary,
  ewp,
  procurementPackage,
  cwp,
  activity,
  task,
  milestone;

  String get label => switch (this) {
        ActivityType.summary => 'Summary',
        ActivityType.ewp => 'Engineering Work Package',
        ActivityType.procurementPackage => 'Procurement Package',
        ActivityType.cwp => 'Construction Work Package',
        ActivityType.activity => 'Activity',
        ActivityType.task => 'Task',
        ActivityType.milestone => 'Milestone',
      };
}

enum DependencyType {
  finishToStart,
  startToStart,
  startToFinish,
  finishToFinish,
  external,
  interface;

  String get label => switch (this) {
        DependencyType.finishToStart => 'Finish-to-Start',
        DependencyType.startToStart => 'Start-to-Start',
        DependencyType.startToFinish => 'Start-to-Finish',
        DependencyType.finishToFinish => 'Finish-to-Finish',
        DependencyType.external => 'External',
        DependencyType.interface => 'Interface',
      };

  String get short => switch (this) {
        DependencyType.finishToStart => 'FS',
        DependencyType.startToStart => 'SS',
        DependencyType.startToFinish => 'SF',
        DependencyType.finishToFinish => 'FF',
        DependencyType.external => 'EXT',
        DependencyType.interface => 'INT',
      };
}

enum EstimationMethod {
  tShirt,
  storyPoints,
  hours,
  days,
  expertJudgment,
  historical,
  parametric,
  threePoint;

  String get label => switch (this) {
        EstimationMethod.tShirt => 'T-shirt Size',
        EstimationMethod.storyPoints => 'Story Points',
        EstimationMethod.hours => 'Hours',
        EstimationMethod.days => 'Days',
        EstimationMethod.expertJudgment => 'Expert Judgment',
        EstimationMethod.historical => 'Historical Data',
        EstimationMethod.parametric => 'Parametric',
        EstimationMethod.threePoint => 'Three-Point',
      };
}

enum ScheduleStatus {
  draft,
  inReview,
  stage1Complete,
  stage2Complete,
  readyForCostEstimate,
  locked;

  String get label => switch (this) {
        ScheduleStatus.draft => 'Draft',
        ScheduleStatus.inReview => 'In Review',
        ScheduleStatus.stage1Complete => 'Stage 1 Complete',
        ScheduleStatus.stage2Complete => 'Stage 2 Complete',
        ScheduleStatus.readyForCostEstimate => 'Ready for Cost Estimate',
        ScheduleStatus.locked => 'Locked',
      };
}

enum TShirtSize { xs, s, m, l, xl }

/// A single schedule activity (tree node).
class ScheduleActivity {
  final String id;
  final String? wbsNodeId;
  final String? agileTaskId;
  final String? costLineId;
  final String? sprintId;
  final String? releaseId;
  final String? agileEpicTitle;
  final String? agileFeatureTitle;
  final String? sprintLabel;
  final String? releaseLabel;
  final String? importSource;
  final int level;
  final String code;
  final String name;
  final String? description;
  final ActivityType type;
  final ScheduleDomain domain;
  final double? duration;
  final String? durationUnit;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ActivityDependency> dependencies;
  final String? owner;
  final String? status;
  final double? progress;
  final EstimationMethod? estimationMethod;
  final double? storyPoints;
  final TShirtSize? tShirtSize;
  final String? definitionOfReady;
  final String? definitionOfDone;
  final List<String>? prerequisites;
  final bool isCriticalPath;
  final bool isLongLead;
  final double? estimatedHours;
  final bool aiGenerated;
  final List<ScheduleActivity> children;

  const ScheduleActivity({
    required this.id,
    this.wbsNodeId,
    this.agileTaskId,
    this.costLineId,
    this.sprintId,
    this.releaseId,
    this.agileEpicTitle,
    this.agileFeatureTitle,
    this.sprintLabel,
    this.releaseLabel,
    this.importSource,
    required this.level,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    required this.domain,
    this.duration,
    this.durationUnit,
    this.startDate,
    this.endDate,
    required this.dependencies,
    this.owner,
    this.status,
    this.progress,
    this.estimationMethod,
    this.storyPoints,
    this.tShirtSize,
    this.definitionOfReady,
    this.definitionOfDone,
    this.prerequisites,
    this.isCriticalPath = false,
    this.isLongLead = false,
    this.estimatedHours,
    required this.aiGenerated,
    required this.children,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (wbsNodeId != null) 'wbsNodeId': wbsNodeId,
        if (agileTaskId != null) 'agileTaskId': agileTaskId,
        if (costLineId != null) 'costLineId': costLineId,
        if (sprintId != null) 'sprintId': sprintId,
        if (releaseId != null) 'releaseId': releaseId,
        if (agileEpicTitle != null) 'agileEpicTitle': agileEpicTitle,
        if (agileFeatureTitle != null) 'agileFeatureTitle': agileFeatureTitle,
        if (sprintLabel != null) 'sprintLabel': sprintLabel,
        if (releaseLabel != null) 'releaseLabel': releaseLabel,
        if (importSource != null) 'importSource': importSource,
        'level': level,
        'code': code,
        'name': name,
        if (description != null) 'description': description,
        'type': type.name,
        'domain': domain.name,
        if (duration != null) 'duration': duration,
        if (durationUnit != null) 'durationUnit': durationUnit,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        if (owner != null) 'owner': owner,
        if (status != null) 'status': status,
        if (progress != null) 'progress': progress,
        if (estimationMethod != null)
          'estimationMethod': estimationMethod!.name,
        if (storyPoints != null) 'storyPoints': storyPoints,
        if (tShirtSize != null) 'tShirtSize': tShirtSize!.name,
        if (definitionOfReady != null) 'definitionOfReady': definitionOfReady,
        if (definitionOfDone != null) 'definitionOfDone': definitionOfDone,
        if (prerequisites != null) 'prerequisites': prerequisites,
        'isCriticalPath': isCriticalPath,
        'isLongLead': isLongLead,
        if (estimatedHours != null) 'estimatedHours': estimatedHours,
        'aiGenerated': aiGenerated,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory ScheduleActivity.fromJson(Map<String, dynamic> json) {
    return ScheduleActivity(
      id: json['id'] as String,
      wbsNodeId: json['wbsNodeId'] as String?,
      agileTaskId: json['agileTaskId'] as String?,
      costLineId: json['costLineId'] as String?,
      sprintId: json['sprintId'] as String?,
      releaseId: json['releaseId'] as String?,
      agileEpicTitle: json['agileEpicTitle'] as String?,
      agileFeatureTitle: json['agileFeatureTitle'] as String?,
      sprintLabel: json['sprintLabel'] as String?,
      releaseLabel: json['releaseLabel'] as String?,
      importSource: json['importSource'] as String?,
      level: json['level'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: ActivityType.values.byName(json['type'] as String),
      domain: ScheduleDomain.values.byName(json['domain'] as String),
      duration: (json['duration'] as num?)?.toDouble(),
      durationUnit: json['durationUnit'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map(
                  (d) => ActivityDependency.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      owner: json['owner'] as String?,
      status: json['status'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      estimationMethod: json['estimationMethod'] != null
          ? EstimationMethod.values.byName(json['estimationMethod'] as String)
          : null,
      storyPoints: (json['storyPoints'] as num?)?.toDouble(),
      tShirtSize: json['tShirtSize'] != null
          ? TShirtSize.values.byName(json['tShirtSize'] as String)
          : null,
      definitionOfReady: json['definitionOfReady'] as String?,
      definitionOfDone: json['definitionOfDone'] as String?,
      prerequisites: (json['prerequisites'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isCriticalPath: json['isCriticalPath'] as bool? ?? false,
      isLongLead: json['isLongLead'] as bool? ?? false,
      estimatedHours: (json['estimatedHours'] as num?)?.toDouble(),
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => ScheduleActivity.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  ScheduleActivity copyWith({
    String? id,
    String? wbsNodeId,
    String? agileTaskId,
    String? costLineId,
    String? sprintId,
    String? releaseId,
    String? agileEpicTitle,
    String? agileFeatureTitle,
    String? sprintLabel,
    String? releaseLabel,
    String? importSource,
    int? level,
    String? code,
    String? name,
    String? description,
    ActivityType? type,
    ScheduleDomain? domain,
    double? duration,
    String? durationUnit,
    DateTime? startDate,
    DateTime? endDate,
    List<ActivityDependency>? dependencies,
    String? owner,
    String? status,
    double? progress,
    EstimationMethod? estimationMethod,
    double? storyPoints,
    TShirtSize? tShirtSize,
    String? definitionOfReady,
    String? definitionOfDone,
    List<String>? prerequisites,
    bool? isCriticalPath,
    bool? isLongLead,
    double? estimatedHours,
    bool? aiGenerated,
    List<ScheduleActivity>? children,
  }) {
    return ScheduleActivity(
      id: id ?? this.id,
      wbsNodeId: wbsNodeId ?? this.wbsNodeId,
      agileTaskId: agileTaskId ?? this.agileTaskId,
      costLineId: costLineId ?? this.costLineId,
      sprintId: sprintId ?? this.sprintId,
      releaseId: releaseId ?? this.releaseId,
      agileEpicTitle: agileEpicTitle ?? this.agileEpicTitle,
      agileFeatureTitle: agileFeatureTitle ?? this.agileFeatureTitle,
      sprintLabel: sprintLabel ?? this.sprintLabel,
      releaseLabel: releaseLabel ?? this.releaseLabel,
      importSource: importSource ?? this.importSource,
      level: level ?? this.level,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      domain: domain ?? this.domain,
      duration: duration ?? this.duration,
      durationUnit: durationUnit ?? this.durationUnit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dependencies: dependencies ?? this.dependencies,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      estimationMethod: estimationMethod ?? this.estimationMethod,
      storyPoints: storyPoints ?? this.storyPoints,
      tShirtSize: tShirtSize ?? this.tShirtSize,
      definitionOfReady: definitionOfReady ?? this.definitionOfReady,
      definitionOfDone: definitionOfDone ?? this.definitionOfDone,
      prerequisites: prerequisites ?? this.prerequisites,
      isCriticalPath: isCriticalPath ?? this.isCriticalPath,
      isLongLead: isLongLead ?? this.isLongLead,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      children: children ?? this.children,
    );
  }
}

class ActivityDependency {
  final String activityId;
  final DependencyType type;

  const ActivityDependency({
    required this.activityId,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'type': type.name,
      };

  factory ActivityDependency.fromJson(Map<String, dynamic> json) {
    return ActivityDependency(
      activityId: json['activityId'] as String,
      type: DependencyType.values.byName(json['type'] as String),
    );
  }
}

/// Schedule basis configuration.
class ScheduleBasis {
  final String deliveryModel; // 'AGILE' | 'WATERFALL' | 'HYBRID'
  final int? sprintDurationWeeks;
  final String? releaseCadence;
  final String? definitionOfReady;
  final String? definitionOfDone;
  final List<String> assumptions;
  final List<String> constraints;
  final List<String> milestones;
  final List<String> interfaces;

  const ScheduleBasis({
    required this.deliveryModel,
    this.sprintDurationWeeks,
    this.releaseCadence,
    this.definitionOfReady,
    this.definitionOfDone,
    required this.assumptions,
    required this.constraints,
    required this.milestones,
    required this.interfaces,
  });

  ScheduleBasis copyWith({
    String? deliveryModel,
    int? sprintDurationWeeks,
    String? releaseCadence,
    String? definitionOfReady,
    String? definitionOfDone,
    List<String>? assumptions,
    List<String>? constraints,
    List<String>? milestones,
    List<String>? interfaces,
  }) {
    return ScheduleBasis(
      deliveryModel: deliveryModel ?? this.deliveryModel,
      sprintDurationWeeks: sprintDurationWeeks ?? this.sprintDurationWeeks,
      releaseCadence: releaseCadence ?? this.releaseCadence,
      definitionOfReady: definitionOfReady ?? this.definitionOfReady,
      definitionOfDone: definitionOfDone ?? this.definitionOfDone,
      assumptions: assumptions ?? this.assumptions,
      constraints: constraints ?? this.constraints,
      milestones: milestones ?? this.milestones,
      interfaces: interfaces ?? this.interfaces,
    );
  }
}

/// SME reviewer for the 2-stage review gate.
class SMEReviewer {
  final String id;
  final String name;
  final String email;
  final String role;
  final int stage; // 1 or 2
  final bool approved;
  final DateTime? approvedAt;

  const SMEReviewer({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.stage,
    required this.approved,
    this.approvedAt,
  });
}

/// Schedule review state (2-stage).
class ScheduleReview {
  final List<SMEReviewer> stage1Reviewers;
  final List<SMEReviewer> stage2Reviewers;
  final bool stage1Complete;
  final bool stage2Complete;
  final DateTime? stage1CompletedAt;
  final DateTime? stage2CompletedAt;
  final String? reviewNotes;

  const ScheduleReview({
    required this.stage1Reviewers,
    required this.stage2Reviewers,
    required this.stage1Complete,
    required this.stage2Complete,
    this.stage1CompletedAt,
    this.stage2CompletedAt,
    this.reviewNotes,
  });

  ScheduleReview copyWith({
    List<SMEReviewer>? stage1Reviewers,
    List<SMEReviewer>? stage2Reviewers,
    bool? stage1Complete,
    bool? stage2Complete,
    DateTime? stage1CompletedAt,
    DateTime? stage2CompletedAt,
    String? reviewNotes,
  }) {
    return ScheduleReview(
      stage1Reviewers: stage1Reviewers ?? this.stage1Reviewers,
      stage2Reviewers: stage2Reviewers ?? this.stage2Reviewers,
      stage1Complete: stage1Complete ?? this.stage1Complete,
      stage2Complete: stage2Complete ?? this.stage2Complete,
      stage1CompletedAt: stage1CompletedAt ?? this.stage1CompletedAt,
      stage2CompletedAt: stage2CompletedAt ?? this.stage2CompletedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }
}

/// Estimate basis for schedule development.
class EstimateBasis {
  final String scopeAlignment;
  final List<EstimationMethod> estimationMethods;
  final Map<String, String> keyAssumptions;
  final Map<String, String> procurementConsiderations;
  final Map<String, String> engineeringConsiderations;
  final List<String> constraintsAndRisks;
  final String validationBenchmarking;
  final String documentation;

  const EstimateBasis({
    required this.scopeAlignment,
    required this.estimationMethods,
    required this.keyAssumptions,
    required this.procurementConsiderations,
    required this.engineeringConsiderations,
    required this.constraintsAndRisks,
    required this.validationBenchmarking,
    required this.documentation,
  });

  EstimateBasis copyWith({
    String? scopeAlignment,
    List<EstimationMethod>? estimationMethods,
    Map<String, String>? keyAssumptions,
    Map<String, String>? procurementConsiderations,
    Map<String, String>? engineeringConsiderations,
    List<String>? constraintsAndRisks,
    String? validationBenchmarking,
    String? documentation,
  }) {
    return EstimateBasis(
      scopeAlignment: scopeAlignment ?? this.scopeAlignment,
      estimationMethods: estimationMethods ?? this.estimationMethods,
      keyAssumptions: keyAssumptions ?? this.keyAssumptions,
      procurementConsiderations:
          procurementConsiderations ?? this.procurementConsiderations,
      engineeringConsiderations:
          engineeringConsiderations ?? this.engineeringConsiderations,
      constraintsAndRisks: constraintsAndRisks ?? this.constraintsAndRisks,
      validationBenchmarking:
          validationBenchmarking ?? this.validationBenchmarking,
      documentation: documentation ?? this.documentation,
    );
  }
}

/// The full schedule.
class Schedule {
  final String id;
  final String projectId;
  final String projectName;
  final ScheduleBasis basis;
  final List<ScheduleActivity> activities;
  final ScheduleReview? review;
  final ScheduleStatus status;
  final bool isLocked;
  final EstimateBasis? estimateBasis;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Schedule({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.basis,
    required this.activities,
    this.review,
    required this.status,
    required this.isLocked,
    this.estimateBasis,
    required this.createdAt,
    required this.updatedAt,
  });

  Schedule copyWith({
    String? id,
    String? projectId,
    String? projectName,
    ScheduleBasis? basis,
    List<ScheduleActivity>? activities,
    ScheduleReview? review,
    ScheduleStatus? status,
    bool? isLocked,
    EstimateBasis? estimateBasis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      basis: basis ?? this.basis,
      activities: activities ?? this.activities,
      review: review ?? this.review,
      status: status ?? this.status,
      isLocked: isLocked ?? this.isLocked,
      estimateBasis: estimateBasis ?? this.estimateBasis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Recursive WBS node for importing into the schedule.
/// Supports arbitrary depth via [children].
class WbsImportNode {
  final String id;
  final String code;
  final String name;
  final String? description;
  final List<WbsImportNode> children;

  const WbsImportNode({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.children,
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String newSchedId([String prefix = 'sched']) {
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
}

ScheduleBasis createEmptyBasis(String deliveryModel) => ScheduleBasis(
      deliveryModel: deliveryModel,
      sprintDurationWeeks: deliveryModel == 'AGILE' ? 2 : null,
      releaseCadence: deliveryModel == 'AGILE' ? 'Monthly' : null,
      definitionOfReady: '',
      definitionOfDone: '',
      assumptions: [],
      constraints: [],
      milestones: [],
      interfaces: [],
    );

EstimateBasis createEmptyEstimateBasis() => const EstimateBasis(
      scopeAlignment: '',
      estimationMethods: [],
      keyAssumptions: {
        'resourceAvailability': '',
        'productivityRates': '',
        'workingCalendars': '',
        'siteConditions': '',
      },
      procurementConsiderations: {
        'vendorLeadTimes': '',
        'fabricationDurations': '',
        'logisticsConstraints': '',
        'contractAwardTimelines': '',
      },
      engineeringConsiderations: {
        'designComplexity': '',
        'reviewApprovalCycles': '',
        'iterationReworkAllowances': '',
      },
      constraintsAndRisks: [],
      validationBenchmarking: '',
      documentation: '',
    );

Schedule createEmptySchedule({
  required String projectName,
  required String deliveryModel,
}) {
  final now = DateTime.now();
  return Schedule(
    id: newSchedId('sched'),
    projectId: 'default',
    projectName: projectName,
    basis: createEmptyBasis(deliveryModel),
    activities: [
      ScheduleActivity(
        id: newSchedId('act'),
        level: 0,
        code: '0',
        name: projectName,
        type: ActivityType.summary,
        domain: ScheduleDomain.engineering,
        dependencies: [],
        aiGenerated: false,
        children: [],
      ),
    ],
    status: ScheduleStatus.draft,
    isLocked: false,
    estimateBasis: createEmptyEstimateBasis(),
    createdAt: now,
    updatedAt: now,
  );
}

/// Recompute activity codes based on tree position.
ScheduleActivity recalcActivityCodes(ScheduleActivity node) {
  if (node.level == 0) {
    return node.copyWith(
      code: '0',
      children: node.children
          .asMap()
          .entries
          .map((e) => _recalcRecursive(e.value, '${e.key + 1}'))
          .toList(),
    );
  }
  return node;
}

ScheduleActivity _recalcRecursive(ScheduleActivity node, String parentCode) {
  final level = parentCode.split('.').length;
  return node.copyWith(
    code: parentCode,
    level: level,
    children: node.children
        .asMap()
        .entries
        .map((e) => _recalcRecursive(e.value, '$parentCode.${e.key + 1}'))
        .toList(),
  );
}

/// Count activities at each level.
Map<int, int> countActivities(Schedule schedule) {
  final counts = <int, int>{};
  void walk(ScheduleActivity node) {
    counts[node.level] = (counts[node.level] ?? 0) + 1;
    for (final c in node.children) {
      walk(c);
    }
  }

  if (schedule.activities.isNotEmpty) {
    walk(schedule.activities[0]);
  }
  return counts;
}

/// Format duration with unit.
String formatDuration(double? duration, String? unit) {
  if (duration == null) return '—';
  return '$duration ${unit ?? 'days'}';
}

/// Format a date.
String formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
}
