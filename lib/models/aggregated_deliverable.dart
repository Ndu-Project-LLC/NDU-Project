import 'roadmap_deliverable.dart';

/// Aggregated deliverable from any phase, unified representation
class AggregatedDeliverable {
  final String id;
  final String title;
  final String description;
  final DeliverablePhase phase;
  final DeliverableCategory category;
  final String sourceCheckpoint; // Source section in navigation
  final DeliverableSourceType sourceType;
  final String sourceItemId; // Reference to original item
  final RoadmapDeliverableStatus status;
  final RoadmapDeliverablePriority priority;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;
  final List<String> dependencies;
  final double completionPercent;
  final int order;
  final String? notes;
  final DateTime createdDate;
  final DateTime lastUpdated;

  const AggregatedDeliverable({
    required this.id,
    required this.title,
    this.description = '',
    required this.phase,
    required this.category,
    required this.sourceCheckpoint,
    required this.sourceType,
    required this.sourceItemId,
    this.status = RoadmapDeliverableStatus.notStarted,
    this.priority = RoadmapDeliverablePriority.medium,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.dependencies = const [],
    this.completionPercent = 0.0,
    this.order = 0,
    this.notes,
    required this.createdDate,
    required this.lastUpdated,
  });

  AggregatedDeliverable copyWith({
    String? id,
    String? title,
    String? description,
    DeliverablePhase? phase,
    DeliverableCategory? category,
    String? sourceCheckpoint,
    DeliverableSourceType? sourceType,
    String? sourceItemId,
    RoadmapDeliverableStatus? status,
    RoadmapDeliverablePriority? priority,
    String? assigneeId,
    String? assigneeName,
    DateTime? dueDate,
    List<String>? dependencies,
    double? completionPercent,
    int? order,
    String? notes,
    DateTime? createdDate,
    DateTime? lastUpdated,
  }) {
    return AggregatedDeliverable(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      phase: phase ?? this.phase,
      category: category ?? this.category,
      sourceCheckpoint: sourceCheckpoint ?? this.sourceCheckpoint,
      sourceType: sourceType ?? this.sourceType,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: dueDate ?? this.dueDate,
      dependencies: dependencies ?? this.dependencies,
      completionPercent: completionPercent ?? this.completionPercent,
      order: order ?? this.order,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'phase': phase.name,
        'category': category.name,
        'sourceCheckpoint': sourceCheckpoint,
        'sourceType': sourceType.name,
        'sourceItemId': sourceItemId,
        'status': status.index,
        'priority': priority.index,
        'assigneeId': assigneeId,
        'assigneeName': assigneeName,
        'dueDate': dueDate?.toIso8601String(),
        'dependencies': dependencies,
        'completionPercent': completionPercent,
        'order': order,
        'notes': notes,
        'createdDate': createdDate.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory AggregatedDeliverable.fromJson(Map<String, dynamic> json) {
    return AggregatedDeliverable(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      phase: DeliverablePhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => DeliverablePhase.planning,
      ),
      category: DeliverableCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DeliverableCategory.governance,
      ),
      sourceCheckpoint: json['sourceCheckpoint'] ?? '',
      sourceType: DeliverableSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => DeliverableSourceType.other,
      ),
      sourceItemId: json['sourceItemId'] ?? '',
      status: RoadmapDeliverableStatus.values.firstWhere(
        (e) => e.index == json['status'],
        orElse: () => RoadmapDeliverableStatus.notStarted,
      ),
      priority: RoadmapDeliverablePriority.values.firstWhere(
        (e) => e.index == json['priority'],
        orElse: () => RoadmapDeliverablePriority.medium,
      ),
      assigneeId: json['assigneeId'],
      assigneeName: json['assigneeName'],
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'])
          : null,
      dependencies: json['dependencies'] != null
          ? List<String>.from(json['dependencies'])
          : [],
      completionPercent: (json['completionPercent'] as num?)?.toDouble() ?? 0.0,
      order: json['order'] ?? 0,
      notes: json['notes'],
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'])
          : DateTime.now(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  /// Convert from RoadmapDeliverable
  factory AggregatedDeliverable.fromRoadmapDeliverable(
    RoadmapDeliverable deliverable, {
    DeliverablePhase phase = DeliverablePhase.planning,
    DeliverableCategory category = DeliverableCategory.execution,
    String sourceCheckpoint = 'deliverables_roadmap',
  }) {
    return AggregatedDeliverable(
      id: deliverable.id,
      title: deliverable.title,
      description: deliverable.description,
      phase: phase,
      category: category,
      sourceCheckpoint: sourceCheckpoint,
      sourceType: DeliverableSourceType.roadmapDeliverable,
      sourceItemId: deliverable.id,
      status: deliverable.status,
      priority: deliverable.priority,
      assigneeId: deliverable.assignee.isNotEmpty ? deliverable.assignee : null,
      assigneeName: deliverable.assignee,
      dueDate: deliverable.dueDate,
      dependencies: deliverable.dependencies,
      completionPercent: deliverable.status == RoadmapDeliverableStatus.completed
          ? 100.0
          : deliverable.status == RoadmapDeliverableStatus.inProgress
              ? 50.0
              : 0.0,
      order: deliverable.order,
      notes: deliverable.notes.isNotEmpty ? deliverable.notes : null,
      createdDate: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from a goal/milestone type item
  factory AggregatedDeliverable.fromMilestone({
    required String id,
    required String title,
    String description = '',
    required DeliverablePhase phase,
    required String sourceCheckpoint,
    DateTime? dueDate,
    String? assigneeId,
    String? assigneeName,
    RoadmapDeliverableStatus? status,
  }) {
    return AggregatedDeliverable(
      id: id,
      title: title,
      description: description,
      phase: phase,
      category: DeliverableCategory.governance,
      sourceCheckpoint: sourceCheckpoint,
      sourceType: DeliverableSourceType.milestone,
      sourceItemId: id,
      status: status ?? RoadmapDeliverableStatus.notStarted,
      priority: RoadmapDeliverablePriority.high,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      dueDate: dueDate,
      completionPercent: status == RoadmapDeliverableStatus.completed ? 100.0 : 0.0,
      createdDate: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from a requirement
  factory AggregatedDeliverable.fromRequirement({
    required String id,
    required String title,
    String description = '',
    required DeliverablePhase phase,
    required String sourceCheckpoint,
    DateTime? dueDate,
    RoadmapDeliverableStatus? status,
  }) {
    return AggregatedDeliverable(
      id: id,
      title: title,
      description: description,
      phase: phase,
      category: DeliverableCategory.requirements,
      sourceCheckpoint: sourceCheckpoint,
      sourceType: DeliverableSourceType.requirement,
      sourceItemId: id,
      status: status ?? RoadmapDeliverableStatus.notStarted,
      priority: RoadmapDeliverablePriority.medium,
      dueDate: dueDate,
      createdDate: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from a WBS item
  factory AggregatedDeliverable.fromWBSItem({
    required String id,
    required String title,
    String description = '',
    required String sourceCheckpoint,
    DateTime? dueDate,
    String? assigneeId,
    String? assigneeName,
    RoadmapDeliverableStatus? status,
  }) {
    return AggregatedDeliverable(
      id: id,
      title: title,
      description: description,
      phase: DeliverablePhase.planning,
      category: DeliverableCategory.execution,
      sourceCheckpoint: sourceCheckpoint,
      sourceType: DeliverableSourceType.wbsItem,
      sourceItemId: id,
      status: status ?? RoadmapDeliverableStatus.notStarted,
      priority: RoadmapDeliverablePriority.medium,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      dueDate: dueDate,
      createdDate: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case RoadmapDeliverableStatus.notStarted:
        return 'Not Started';
      case RoadmapDeliverableStatus.inProgress:
        return 'In Progress';
      case RoadmapDeliverableStatus.completed:
        return 'Completed';
      case RoadmapDeliverableStatus.atRisk:
        return 'At Risk';
      case RoadmapDeliverableStatus.blocked:
        return 'Blocked';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case RoadmapDeliverablePriority.critical:
        return 'Critical';
      case RoadmapDeliverablePriority.high:
        return 'High';
      case RoadmapDeliverablePriority.medium:
        return 'Medium';
      case RoadmapDeliverablePriority.low:
        return 'Low';
    }
  }

  String get phaseLabel {
    switch (phase) {
      case DeliverablePhase.initiation:
        return 'Initiation';
      case DeliverablePhase.frontEndPlanning:
        return 'Front-End Planning';
      case DeliverablePhase.planning:
        return 'Planning';
      case DeliverablePhase.design:
        return 'Design';
      case DeliverablePhase.execution:
        return 'Execution';
      case DeliverablePhase.launch:
        return 'Launch';
    }
  }

  String get categoryLabel {
    switch (category) {
      case DeliverableCategory.governance:
        return 'Governance';
      case DeliverableCategory.requirements:
        return 'Requirements';
      case DeliverableCategory.riskCompliance:
        return 'Risk & Compliance';
      case DeliverableCategory.execution:
        return 'Execution';
      case DeliverableCategory.technical:
        return 'Technical';
      case DeliverableCategory.quality:
        return 'Quality';
      case DeliverableCategory.contractsProcurement:
        return 'Contracts & Procurement';
      case DeliverableCategory.scheduleCost:
        return 'Schedule & Cost';
      case DeliverableCategory.teamStakeholders:
        return 'Team & Stakeholders';
    }
  }

  String get sourceTypeLabel {
    switch (sourceType) {
      case DeliverableSourceType.milestone:
        return 'Milestone';
      case DeliverableSourceType.requirement:
        return 'Requirement';
      case DeliverableSourceType.wbsItem:
        return 'WBS Item';
      case DeliverableSourceType.roadmapDeliverable:
        return 'Roadmap Deliverable';
      case DeliverableSourceType.risk:
        return 'Risk Item';
      case DeliverableSourceType.task:
        return 'Task';
      case DeliverableSourceType.document:
        return 'Document';
      case DeliverableSourceType.other:
        return 'Other';
    }
  }

  bool get isOverdue {
    if (dueDate == null || status == RoadmapDeliverableStatus.completed) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }

  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  bool get isCompleted => status == RoadmapDeliverableStatus.completed;
  bool get isNotStarted => status == RoadmapDeliverableStatus.notStarted;
  bool get isInProgress => status == RoadmapDeliverableStatus.inProgress;
  bool get isAtRisk => status == RoadmapDeliverableStatus.atRisk;
  bool get isBlocked => status == RoadmapDeliverableStatus.blocked;
}

/// Phase where the deliverable originates
enum DeliverablePhase {
  initiation,
  frontEndPlanning,
  planning,
  design,
  execution,
  launch,
}

/// Category of deliverable for organization
enum DeliverableCategory {
  governance,
  requirements,
  riskCompliance,
  execution,
  technical,
  quality,
  contractsProcurement,
  scheduleCost,
  teamStakeholders,
}

/// Type of source item
enum DeliverableSourceType {
  milestone,
  requirement,
  wbsItem,
  roadmapDeliverable,
  risk,
  task,
  document,
  other,
}

/// Filter options for aggregated deliverables
class DeliverableFilter {
  final Set<DeliverablePhase>? phases;
  final Set<DeliverableCategory>? categories;
  final Set<RoadmapDeliverableStatus>? statuses;
  final Set<RoadmapDeliverablePriority>? priorities;
  final String? assigneeId;
  final DateTime? dueBefore;
  final DateTime? dueAfter;
  final bool? includeOverdue;
  final String? searchTerm;

  const DeliverableFilter({
    this.phases,
    this.categories,
    this.statuses,
    this.priorities,
    this.assigneeId,
    this.dueBefore,
    this.dueAfter,
    this.includeOverdue,
    this.searchTerm,
  });

  DeliverableFilter copyWith({
    Set<DeliverablePhase>? phases,
    Set<DeliverableCategory>? categories,
    Set<RoadmapDeliverableStatus>? statuses,
    Set<RoadmapDeliverablePriority>? priorities,
    String? assigneeId,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool? includeOverdue,
    String? searchTerm,
  }) {
    return DeliverableFilter(
      phases: phases ?? this.phases,
      categories: categories ?? this.categories,
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      assigneeId: assigneeId ?? this.assigneeId,
      dueBefore: dueBefore ?? this.dueBefore,
      dueAfter: dueAfter ?? this.dueAfter,
      includeOverdue: includeOverdue ?? this.includeOverdue,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  /// Check if a deliverable matches the filter
  bool matches(AggregatedDeliverable deliverable) {
    if (phases != null && !phases!.contains(deliverable.phase)) {
      return false;
    }
    if (categories != null && !categories!.contains(deliverable.category)) {
      return false;
    }
    if (statuses != null && !statuses!.contains(deliverable.status)) {
      return false;
    }
    if (priorities != null && !priorities!.contains(deliverable.priority)) {
      return false;
    }
    if (assigneeId != null && deliverable.assigneeId != assigneeId) {
      return false;
    }
    if (dueBefore != null &&
        (deliverable.dueDate == null || deliverable.dueDate!.isAfter(dueBefore!))) {
      return false;
    }
    if (dueAfter != null &&
        (deliverable.dueDate == null || deliverable.dueDate!.isBefore(dueAfter!))) {
      return false;
    }
    if (includeOverdue == true && !deliverable.isOverdue) {
      return false;
    }
    if (searchTerm != null && searchTerm!.isNotEmpty) {
      final term = searchTerm!.toLowerCase();
      if (!deliverable.title.toLowerCase().contains(term) &&
          !deliverable.description.toLowerCase().contains(term)) {
        return false;
      }
    }
    return true;
  }

  /// Empty filter (matches all)
  static const empty = DeliverableFilter();
}

/// Statistics for deliverable dashboard
class DeliverableStatistics {
  final int total;
  final int completed;
  final int inProgress;
  final int notStarted;
  final int atRisk;
  final int blocked;
  final int overdue;
  final double completionPercent;
  final Map<DeliverableCategory, int> byCategory;
  final Map<DeliverablePhase, int> byPhase;

  const DeliverableStatistics({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.notStarted,
    required this.atRisk,
    required this.blocked,
    required this.overdue,
    required this.completionPercent,
    this.byCategory = const {},
    this.byPhase = const {},
  });

  /// Calculate statistics from a list of deliverables
  static DeliverableStatistics calculate(List<AggregatedDeliverable> deliverables) {
    final total = deliverables.length;
    final completed = deliverables.where((d) => d.isCompleted).length;
    final inProgress = deliverables.where((d) => d.isInProgress).length;
    final notStarted = deliverables.where((d) => d.isNotStarted).length;
    final atRisk = deliverables.where((d) => d.isAtRisk).length;
    final blocked = deliverables.where((d) => d.isBlocked).length;
    final overdue = deliverables.where((d) => d.isOverdue).length;

    final byCategory = <DeliverableCategory, int>{};
    for (final cat in DeliverableCategory.values) {
      byCategory[cat] = deliverables.where((d) => d.category == cat).length;
    }

    final byPhase = <DeliverablePhase, int>{};
    for (final phase in DeliverablePhase.values) {
      byPhase[phase] = deliverables.where((d) => d.phase == phase).length;
    }

    final completionPercent = total > 0 ? (completed / total) * 100 : 0.0;

    return DeliverableStatistics(
      total: total,
      completed: completed,
      inProgress: inProgress,
      notStarted: notStarted,
      atRisk: atRisk,
      blocked: blocked,
      overdue: overdue,
      completionPercent: completionPercent,
      byCategory: byCategory,
      byPhase: byPhase,
    );
  }
}
