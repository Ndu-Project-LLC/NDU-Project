/// Model for a recurring deliverable in Progress Tracking
class RecurringDeliverableRow {
  final String id;
  String title;
  String description; // Prose (no bullets)
  String frequency; // Daily, Weekly, Bi-Weekly, Monthly, Quarterly
  DateTime? nextOccurrence;
  DateTime? lastCompleted;
  int completionCount; // Number of times completed
  String owner;
  String status; // Active, Paused, Completed
  String actionItems; // "." bullet list
  String notes; // Manual notes only, no AI generation

  RecurringDeliverableRow({
    String? id,
    this.title = '',
    this.description = '',
    this.frequency = 'Weekly',
    this.nextOccurrence,
    this.lastCompleted,
    this.completionCount = 0,
    this.owner = '',
    this.status = 'Active',
    this.actionItems = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Calculate next occurrence based on frequency
  DateTime? calculateNextOccurrence() {
    final last = lastCompleted ?? DateTime.now();
    final daysToAdd = switch (frequency.toLowerCase()) {
      'daily' => 1,
      'weekly' => 7,
      'bi-weekly' => 14,
      'monthly' => 30,
      'quarterly' => 90,
      _ => 7,
    };
    return last.add(Duration(days: daysToAdd));
  }

  RecurringDeliverableRow copyWith({
    String? title,
    String? description,
    String? frequency,
    DateTime? nextOccurrence,
    DateTime? lastCompleted,
    int? completionCount,
    String? owner,
    String? status,
    String? actionItems,
    String? notes,
  }) {
    return RecurringDeliverableRow(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      completionCount: completionCount ?? this.completionCount,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      actionItems: actionItems ?? this.actionItems,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'frequency': frequency,
        'nextOccurrence': nextOccurrence?.toIso8601String(),
        'lastCompleted': lastCompleted?.toIso8601String(),
        'completionCount': completionCount,
        'owner': owner,
        'status': status,
        'actionItems': actionItems,
        'notes': notes,
      };

  factory RecurringDeliverableRow.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return RecurringDeliverableRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? 'Weekly',
      nextOccurrence: parseDate(json['nextOccurrence']?.toString()),
      lastCompleted: parseDate(json['lastCompleted']?.toString()),
      completionCount: json['completionCount'] is int
          ? json['completionCount'] as int
          : (json['completionCount'] is num
              ? (json['completionCount'] as num).toInt()
              : 0),
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      actionItems: json['actionItems']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}
