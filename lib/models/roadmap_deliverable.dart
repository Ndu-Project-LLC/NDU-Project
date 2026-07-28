enum RoadmapDeliverableStatus {
  notStarted,
  inProgress,
  completed,
  atRisk,
  blocked,
}

enum RoadmapDeliverablePriority {
  critical,
  high,
  medium,
  low,
}

class RoadmapDeliverable {
  final String id;
  String title;
  String description;
  String sprintId;
  String assignee;
  DateTime? dueDate;
  RoadmapDeliverableStatus status;
  RoadmapDeliverablePriority priority;
  int storyPoints;
  List<String> dependencies;
  String blockers;
  String acceptanceCriteria;
  String notes;
  int order;
  String createdById;
  String createdByEmail;
  String createdByName;

  RoadmapDeliverable({
    String? id,
    this.title = '',
    this.description = '',
    this.sprintId = '',
    this.assignee = '',
    this.dueDate,
    this.status = RoadmapDeliverableStatus.notStarted,
    this.priority = RoadmapDeliverablePriority.medium,
    this.storyPoints = 1,
    List<String>? dependencies,
    this.blockers = '',
    this.acceptanceCriteria = '',
    this.notes = '',
    this.order = 0,
    this.createdById = '',
    this.createdByEmail = '',
    this.createdByName = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        dependencies = dependencies ?? [];

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

  RoadmapDeliverable copyWith({
    String? title,
    String? description,
    String? sprintId,
    String? assignee,
    DateTime? dueDate,
    RoadmapDeliverableStatus? status,
    RoadmapDeliverablePriority? priority,
    int? storyPoints,
    List<String>? dependencies,
    String? blockers,
    String? acceptanceCriteria,
    String? notes,
    int? order,
  }) {
    return RoadmapDeliverable(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      sprintId: sprintId ?? this.sprintId,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      storyPoints: storyPoints ?? this.storyPoints,
      dependencies: dependencies ?? this.dependencies,
      blockers: blockers ?? this.blockers,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      notes: notes ?? this.notes,
      order: order ?? this.order,
      createdById: createdById,
      createdByEmail: createdByEmail,
      createdByName: createdByName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sprintId': sprintId,
        'assignee': assignee,
        'dueDate': dueDate?.toIso8601String(),
        'status': status.index,
        'priority': priority.index,
        'storyPoints': storyPoints,
        'dependencies': dependencies,
        'blockers': blockers,
        'acceptanceCriteria': acceptanceCriteria,
        'notes': notes,
        'order': order,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
      };

  factory RoadmapDeliverable.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    RoadmapDeliverableStatus parseStatus(dynamic v) {
      if (v is int) {
        return RoadmapDeliverableStatus.values.firstWhere(
          (e) => e.index == v,
          orElse: () => RoadmapDeliverableStatus.notStarted,
        );
      }
      return RoadmapDeliverableStatus.notStarted;
    }

    RoadmapDeliverablePriority parsePriority(dynamic v) {
      if (v is int) {
        return RoadmapDeliverablePriority.values.firstWhere(
          (e) => e.index == v,
          orElse: () => RoadmapDeliverablePriority.medium,
        );
      }
      return RoadmapDeliverablePriority.medium;
    }

    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 1;
    }

    return RoadmapDeliverable(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sprintId: json['sprintId']?.toString() ?? '',
      assignee: json['assignee']?.toString() ?? '',
      dueDate: parseDate(json['dueDate']?.toString()),
      status: parseStatus(json['status']),
      priority: parsePriority(json['priority']),
      storyPoints: parseInt(json['storyPoints']),
      dependencies:
          (json['dependencies'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      blockers: json['blockers']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      order: parseInt(json['order']),
      createdById: json['createdById']?.toString() ?? '',
      createdByEmail: json['createdByEmail']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
    );
  }
}
