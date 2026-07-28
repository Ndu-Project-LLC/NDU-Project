/// Model for a meeting row in the Team Meetings page
class MeetingRow {
  final String id;
  String
      meetingType; // Weekly Sync, Stakeholder Update, Technical Deep-Dive, etc.
  String frequency; // Daily, Weekly, Bi-Weekly, Monthly
  List<String> keyParticipants; // List of role titles from Staff Team
  String durationHours; // Duration in hours (as string for flexibility)
  String meetingObjective; // Prose description (no bullets)
  String actionItems; // Bullet list with "." separator
  String notes; // Manual notes only, no AI generation
  String? nextScheduledDate; // ISO date string for next occurrence
  String status;

  MeetingRow({
    String? id,
    this.meetingType = '',
    this.frequency = '',
    List<String>? keyParticipants,
    this.durationHours = '',
    this.meetingObjective = '',
    this.actionItems = '',
    this.notes = '',
    this.nextScheduledDate,
    this.status = 'Scheduled',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        keyParticipants = keyParticipants ?? [];

  /// Calculate total hours for this meeting type (duration × frequency multiplier)
  double get totalHoursPerPeriod {
    final duration = double.tryParse(durationHours.replaceAll(',', '')) ?? 0.0;
    if (duration == 0.0) return 0.0;

    // Frequency multiplier (meetings per month)
    final multiplier = switch (frequency.toLowerCase()) {
      'daily' => 30.0,
      'weekly' => 4.0,
      'bi-weekly' => 2.0,
      'monthly' => 1.0,
      _ => 0.0,
    };

    return duration * multiplier;
  }

  MeetingRow copyWith({
    String? meetingType,
    String? frequency,
    List<String>? keyParticipants,
    String? durationHours,
    String? meetingObjective,
    String? actionItems,
    String? notes,
    String? nextScheduledDate,
    String? status,
  }) {
    return MeetingRow(
      id: id,
      meetingType: meetingType ?? this.meetingType,
      frequency: frequency ?? this.frequency,
      keyParticipants: keyParticipants ?? this.keyParticipants,
      durationHours: durationHours ?? this.durationHours,
      meetingObjective: meetingObjective ?? this.meetingObjective,
      actionItems: actionItems ?? this.actionItems,
      notes: notes ?? this.notes,
      nextScheduledDate: nextScheduledDate ?? this.nextScheduledDate,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'meetingType': meetingType,
        'frequency': frequency,
        'keyParticipants': keyParticipants,
        'durationHours': durationHours,
        'meetingObjective': meetingObjective,
        'actionItems': actionItems,
        'notes': notes,
        'nextScheduledDate': nextScheduledDate,
        'status': status,
      };

  factory MeetingRow.fromJson(Map<String, dynamic> json) {
    return MeetingRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      meetingType: json['meetingType']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      keyParticipants: (json['keyParticipants'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      durationHours: json['durationHours']?.toString() ?? '',
      meetingObjective: json['meetingObjective']?.toString() ?? '',
      actionItems: json['actionItems']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      nextScheduledDate: json['nextScheduledDate']?.toString(),
      status: json['status']?.toString() ?? 'Scheduled',
    );
  }
}
