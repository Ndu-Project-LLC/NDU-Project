enum ProjectActivityStatus {
  pending,
  acknowledged,
  implemented,
  rejected,
  deferred,
}

enum ProjectApprovalStatus {
  draft,
  approved,
  locked,
}

ProjectActivityStatus _parseProjectActivityStatus(dynamic raw) {
  final token = (raw ?? '').toString().trim().toLowerCase();
  switch (token) {
    case 'acknowledged':
      return ProjectActivityStatus.acknowledged;
    case 'implemented':
      return ProjectActivityStatus.implemented;
    case 'rejected':
      return ProjectActivityStatus.rejected;
    case 'deferred':
      return ProjectActivityStatus.deferred;
    default:
      return ProjectActivityStatus.pending;
  }
}

ProjectApprovalStatus _parseProjectApprovalStatus(dynamic raw) {
  final token = (raw ?? '').toString().trim().toLowerCase();
  switch (token) {
    case 'approved':
      return ProjectApprovalStatus.approved;
    case 'locked':
      return ProjectApprovalStatus.locked;
    default:
      return ProjectApprovalStatus.draft;
  }
}

DateTime _parseDate(dynamic raw, DateTime fallback) {
  if (raw is DateTime) return raw;
  return DateTime.tryParse((raw ?? '').toString()) ?? fallback;
}

class ProjectActivity {
  final String id;
  final String title;
  final String description;
  final String sourceSection;
  final String phase;
  final String discipline;
  final String role;
  final String? assignedTo;
  final List<String> applicableSections;
  final String dueDate;
  final ProjectActivityStatus status;
  final ProjectApprovalStatus approvalStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceSection,
    required this.phase,
    required this.discipline,
    required this.role,
    this.assignedTo,
    this.applicableSections = const [],
    this.dueDate = '',
    this.status = ProjectActivityStatus.pending,
    this.approvalStatus = ProjectApprovalStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectActivity copyWith({
    String? title,
    String? description,
    String? sourceSection,
    String? phase,
    String? discipline,
    String? role,
    String? assignedTo,
    bool clearAssignedTo = false,
    List<String>? applicableSections,
    String? dueDate,
    ProjectActivityStatus? status,
    ProjectApprovalStatus? approvalStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectActivity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceSection: sourceSection ?? this.sourceSection,
      phase: phase ?? this.phase,
      discipline: discipline ?? this.discipline,
      role: role ?? this.role,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      applicableSections: applicableSections ?? this.applicableSections,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sourceSection': sourceSection,
        'phase': phase,
        'discipline': discipline,
        'role': role,
        'assignedTo': assignedTo,
        'applicableSections': applicableSections,
        'dueDate': dueDate,
        'status': status.name,
        'approvalStatus': approvalStatus.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProjectActivity.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ProjectActivity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sourceSection: json['sourceSection']?.toString() ?? '',
      phase: json['phase']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      assignedTo: json['assignedTo']?.toString(),
      applicableSections:
          (json['applicableSections'] as List?)?.map((e) => '$e').toList() ??
              const [],
      dueDate: json['dueDate']?.toString() ?? '',
      status: _parseProjectActivityStatus(json['status']),
      approvalStatus: _parseProjectApprovalStatus(json['approvalStatus']),
      createdAt: _parseDate(json['createdAt'], now),
      updatedAt: _parseDate(json['updatedAt'], now),
    );
  }
}
