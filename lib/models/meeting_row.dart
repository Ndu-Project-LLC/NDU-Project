/// Model for a meeting row in the Team Meetings page.
/// Extended with scheduling fields: date, time, meeting link, location,
/// organizer email, attendee emails, reminder, and agenda items.
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
  String? nextScheduledDate; // ISO date string for next occurrence (YYYY-MM-DD)
  String status;

  // ── Scheduling & Collaboration fields ──
  String meetingTime; // Time of day in HH:mm format (e.g. "14:30")
  String meetingLink; // Video conference URL (Zoom, Teams, Google Meet, etc.)
  String location; // Physical location or room
  String organizerEmail; // Email of the meeting organizer
  List<String> attendeeEmails; // Email addresses of invited collaborators
  int reminderMinutes; // Reminder before meeting (15, 30, 60 minutes, etc.)
  List<String> agendaItems; // Structured agenda items

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
    this.meetingTime = '',
    this.meetingLink = '',
    this.location = '',
    this.organizerEmail = '',
    List<String>? attendeeEmails,
    this.reminderMinutes = 30,
    List<String>? agendaItems,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        keyParticipants = keyParticipants ?? [],
        attendeeEmails = attendeeEmails ?? [],
        agendaItems = agendaItems ?? [];

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

  /// Returns true if this meeting has a valid date AND time set.
  bool get hasScheduledDateTime =>
      (nextScheduledDate ?? '').isNotEmpty && meetingTime.isNotEmpty;

  /// Returns a combined ISO datetime string if both date and time are set,
  /// otherwise returns just the date.
  String get fullDateTimeString {
    final date = (nextScheduledDate ?? '').trim();
    final time = meetingTime.trim();
    if (date.isEmpty) return '';
    if (time.isEmpty) return date;
    return '${date}T$time';
  }

  /// Builds a Google Calendar "add event" URL that pre-fills title, dates,
  /// details, and location. Opens in a new browser tab.
  String get googleCalendarUrl {
    final title = Uri.encodeComponent(meetingType.isNotEmpty
        ? meetingType
        : 'Project Meeting');
    final details = Uri.encodeComponent(
        '${meetingObjective.isNotEmpty ? meetingObjective : ''}\n\n'
        'Agenda:\n${agendaItems.isEmpty ? actionItems : agendaItems.map((a) => '• $a').join('\n')}'
        '${notes.isNotEmpty ? '\n\nNotes: $notes' : ''}'
        '${meetingLink.isNotEmpty ? '\n\nJoin: $meetingLink' : ''}');
    final locationStr = Uri.encodeComponent(
        meetingLink.isNotEmpty ? meetingLink : location);

    // Build start/end datetime
    final date = (nextScheduledDate ?? '').trim();
    final time = meetingTime.trim();
    String startStr = '';
    String endStr = '';
    if (date.isNotEmpty) {
      final hh = time.isNotEmpty ? time.split(':')[0] : '09';
      final mm = time.isNotEmpty ? time.split(':')[1] : '00';
      startStr = '${date.replaceAll('-', '')}T${hh}${mm}00';
      // End time = start + durationHours
      final dur = double.tryParse(durationHours) ?? 1.0;
      final durHours = dur.floor();
      final durMins = ((dur - durHours) * 60).round();
      final startDateTime = DateTime.tryParse('${date}T$time:00') ??
          DateTime.parse('${date}T09:00:00');
      final endDateTime = startDateTime.add(
          Duration(hours: durHours, minutes: durMins));
      endStr = '${endDateTime.year.toString().padLeft(4, '0')}'
          '${endDateTime.month.toString().padLeft(2, '0')}'
          '${endDateTime.day.toString().padLeft(2, '0')}'
          'T${endDateTime.hour.toString().padLeft(2, '0')}'
          '${endDateTime.minute.toString().padLeft(2, '0')}00';
    }

    return 'https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=$title'
        '&details=$details'
        '&location=$locationStr'
        '${startStr.isNotEmpty ? '&dates=$startStr/$endStr' : ''}'
        '${attendeeEmails.isNotEmpty ? '&add=${attendeeEmails.map(Uri.encodeComponent).join(',')}' : ''}'
        '${reminderMinutes > 0 ? '&reminders=EMAIL:${reminderMinutes},POPUP:${reminderMinutes}' : ''}';
  }

  /// Builds a formatted meeting invitation text that can be copied to clipboard
  /// and pasted into an email or messaging app.
  String get inviteText {
    final buffer = StringBuffer();
    buffer.writeln('Meeting Invitation');
    buffer.writeln('${'=' * 40}');
    buffer.writeln('Title: ${meetingType.isNotEmpty ? meetingType : 'Project Meeting'}');
    if (nextScheduledDate != null && nextScheduledDate!.isNotEmpty) {
      buffer.writeln('Date: $nextScheduledDate');
    }
    if (meetingTime.isNotEmpty) {
      buffer.writeln('Time: $meetingTime');
    }
    if (durationHours.isNotEmpty) {
      buffer.writeln('Duration: $durationHours hour(s)');
    }
    if (frequency.isNotEmpty) {
      buffer.writeln('Frequency: $frequency');
    }
    if (location.isNotEmpty) {
      buffer.writeln('Location: $location');
    }
    if (meetingLink.isNotEmpty) {
      buffer.writeln('Join Online: $meetingLink');
    }
    if (organizerEmail.isNotEmpty) {
      buffer.writeln('Organizer: $organizerEmail');
    }
    if (keyParticipants.isNotEmpty) {
      buffer.writeln('Key Participants: ${keyParticipants.join(', ')}');
    }
    if (attendeeEmails.isNotEmpty) {
      buffer.writeln('Attendees: ${attendeeEmails.join(', ')}');
    }
    if (meetingObjective.isNotEmpty) {
      buffer.writeln('\nObjective:');
      buffer.writeln(meetingObjective);
    }
    if (agendaItems.isNotEmpty) {
      buffer.writeln('\nAgenda:');
      for (int i = 0; i < agendaItems.length; i++) {
        buffer.writeln('${i + 1}. ${agendaItems[i]}');
      }
    } else if (actionItems.isNotEmpty) {
      buffer.writeln('\nAction Items:');
      buffer.writeln(actionItems.replaceAll('.', '• '));
    }
    if (notes.isNotEmpty) {
      buffer.writeln('\nNotes:');
      buffer.writeln(notes);
    }
    buffer.writeln('\n${'=' * 40}');
    buffer.writeln('Please confirm your attendance.');
    return buffer.toString();
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
    String? meetingTime,
    String? meetingLink,
    String? location,
    String? organizerEmail,
    List<String>? attendeeEmails,
    int? reminderMinutes,
    List<String>? agendaItems,
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
      meetingTime: meetingTime ?? this.meetingTime,
      meetingLink: meetingLink ?? this.meetingLink,
      location: location ?? this.location,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      attendeeEmails: attendeeEmails ?? this.attendeeEmails,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      agendaItems: agendaItems ?? this.agendaItems,
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
        'meetingTime': meetingTime,
        'meetingLink': meetingLink,
        'location': location,
        'organizerEmail': organizerEmail,
        'attendeeEmails': attendeeEmails,
        'reminderMinutes': reminderMinutes,
        'agendaItems': agendaItems,
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
      meetingTime: json['meetingTime']?.toString() ?? '',
      meetingLink: json['meetingLink']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      organizerEmail: json['organizerEmail']?.toString() ?? '',
      attendeeEmails: (json['attendeeEmails'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reminderMinutes: json['reminderMinutes'] as int? ?? 30,
      agendaItems: (json['agendaItems'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
