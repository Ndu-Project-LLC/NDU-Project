/// Model for a deliverable row in Progress Tracking
class DeliverableRow {
  final String id;
  String title;
  String description; // Prose (no bullets)
  String owner;
  DateTime? dueDate;
  DateTime? completionDate;
  String status; // Not Started, In Progress, Completed, At Risk, Blocked
  List<String> dependencies; // IDs of other deliverables this depends on
  String blockers; // "." bullet list
  String nextSteps; // "." bullet list
  String notes; // Manual notes only, no AI generation

  DeliverableRow({
    String? id,
    this.title = '',
    this.description = '',
    this.owner = '',
    this.dueDate,
    this.completionDate,
    this.status = 'Not Started',
    List<String>? dependencies,
    this.blockers = '',
    this.nextSteps = '',
    this.notes = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        dependencies = dependencies ?? [];

  /// Check if deliverable is overdue
  bool get isOverdue {
    if (dueDate == null || status == 'Completed') return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Calculate days until due (negative if overdue)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  /// Check if deliverable is at risk (due within 7 days and not completed)
  bool get isAtRisk {
    if (status == 'Completed' || dueDate == null) return false;
    final days = daysUntilDue ?? 0;
    return days >= 0 && days <= 7 && status != 'Completed';
  }

  DeliverableRow copyWith({
    String? title,
    String? description,
    String? owner,
    DateTime? dueDate,
    DateTime? completionDate,
    String? status,
    List<String>? dependencies,
    String? blockers,
    String? nextSteps,
    String? notes,
  }) {
    return DeliverableRow(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      completionDate: completionDate ?? this.completionDate,
      status: status ?? this.status,
      dependencies: dependencies ?? this.dependencies,
      blockers: blockers ?? this.blockers,
      nextSteps: nextSteps ?? this.nextSteps,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'owner': owner,
        'dueDate': dueDate?.toIso8601String(),
        'completionDate': completionDate?.toIso8601String(),
        'status': status,
        'dependencies': dependencies,
        'blockers': blockers,
        'nextSteps': nextSteps,
        'notes': notes,
      };

  factory DeliverableRow.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return DeliverableRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      dueDate: parseDate(json['dueDate']?.toString()),
      completionDate: parseDate(json['completionDate']?.toString()),
      status: json['status']?.toString() ?? 'Not Started',
      dependencies:
          (json['dependencies'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      blockers: json['blockers']?.toString() ?? '',
      nextSteps: json['nextSteps']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}
