// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TeamManagementPlan
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Holds the plan that outlines what would occur in the Execution phase
// team activities section. This plan is defined during the Planning phase
// on the Team Management screen and consumed during Execution.
//
// Sections (per user spec):
//   1. Team mobilization process (text plan)
//   2. Mobilization checklist (per-team-member onboarding tasks that
//      trigger the "Mobilize team" aspect of Execution)
//   3. Project onboarding documents (auto-generated project summary
//      from Initiation + Planning scope)
//   4. Role onboarding documents (per-role requirements — PM needs PMO
//      certification, Security needs course completion, etc.)
//   5. Team member recognition process (skippable, not available for
//      basic/regular plan projects)
//   6. Role handover template (must be completed before a team member
//      leaves the project)
//   7. Team activities feed (low-priority, announcement-like posts)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// A single checklist item in a team member's mobilization checklist.
/// When all items are checked, the team member is "mobilized" for the
/// Execution phase.
class MobilizationChecklistItem {
  String id;
  String label;
  bool isChecked;
  String? completedAt;
  String? completedBy;

  MobilizationChecklistItem({
    String? id,
    required this.label,
    this.isChecked = false,
    this.completedAt,
    this.completedBy,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'isChecked': isChecked,
        'completedAt': completedAt,
        'completedBy': completedBy,
      };

  factory MobilizationChecklistItem.fromJson(Map<String, dynamic> json) {
    return MobilizationChecklistItem(
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      isChecked: json['isChecked'] == true,
      completedAt: json['completedAt']?.toString(),
      completedBy: json['completedBy']?.toString(),
    );
  }

  MobilizationChecklistItem copyWith({
    String? label,
    bool? isChecked,
    String? completedAt,
    String? completedBy,
  }) {
    return MobilizationChecklistItem(
      id: id,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
    );
  }
}

/// A per-member mobilization record. Each team member has their own
/// checklist that must be completed before they are considered
/// "mobilized" for the Execution phase.
class MemberMobilization {
  String memberId;
  List<MobilizationChecklistItem> checklist;
  String? mobilizedAt;

  MemberMobilization({
    required this.memberId,
    List<MobilizationChecklistItem>? checklist,
    this.mobilizedAt,
  }) : checklist = checklist ?? [];

  bool get isFullyMobilized =>
      checklist.isNotEmpty && checklist.every((item) => item.isChecked);

  double get progress {
    if (checklist.isEmpty) return 0.0;
    final done = checklist.where((item) => item.isChecked).length;
    return done / checklist.length;
  }

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'mobilizedAt': mobilizedAt,
      };

  factory MemberMobilization.fromJson(Map<String, dynamic> json) {
    return MemberMobilization(
      memberId: json['memberId']?.toString() ?? '',
      checklist: (json['checklist'] as List?)
              ?.map((c) => MobilizationChecklistItem.fromJson(c))
              .toList() ??
          [],
      mobilizedAt: json['mobilizedAt']?.toString(),
    );
  }
}

/// A role-specific onboarding requirement (e.g. "PMO certification copy"
/// for Project Managers, "Security course completion" for Security
/// personnel). The project can identify these or skip them.
class RoleOnboardingRequirement {
  String id;
  String role;
  String requirement;
  String description;
  bool isRequired;
  bool isSkipped;

  RoleOnboardingRequirement({
    String? id,
    required this.role,
    required this.requirement,
    this.description = '',
    this.isRequired = true,
    this.isSkipped = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'requirement': requirement,
        'description': description,
        'isRequired': isRequired,
        'isSkipped': isSkipped,
      };

  factory RoleOnboardingRequirement.fromJson(Map<String, dynamic> json) {
    return RoleOnboardingRequirement(
      id: json['id']?.toString(),
      role: json['role']?.toString() ?? '',
      requirement: json['requirement']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isRequired: json['isRequired'] ?? true,
      isSkipped: json['isSkipped'] ?? false,
    );
  }
}

/// A handover record for when a team member moves on from the project.
/// Must be completed before the member leaves.
class RoleHandoverRecord {
  String id;
  String memberId;
  String memberName;
  String memberRole;
  String outgoingResponsibilities;
  String incomingMemberName;
  String knowledgeTransferNotes;
  String openActionItems;
  String assetHandoverNotes;
  String? completedAt;
  String? completedBy;
  bool isCompleted;

  RoleHandoverRecord({
    String? id,
    required this.memberId,
    this.memberName = '',
    this.memberRole = '',
    this.outgoingResponsibilities = '',
    this.incomingMemberName = '',
    this.knowledgeTransferNotes = '',
    this.openActionItems = '',
    this.assetHandoverNotes = '',
    this.completedAt,
    this.completedBy,
    this.isCompleted = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'memberRole': memberRole,
        'outgoingResponsibilities': outgoingResponsibilities,
        'incomingMemberName': incomingMemberName,
        'knowledgeTransferNotes': knowledgeTransferNotes,
        'openActionItems': openActionItems,
        'assetHandoverNotes': assetHandoverNotes,
        'completedAt': completedAt,
        'completedBy': completedBy,
        'isCompleted': isCompleted,
      };

  factory RoleHandoverRecord.fromJson(Map<String, dynamic> json) {
    return RoleHandoverRecord(
      id: json['id']?.toString(),
      memberId: json['memberId']?.toString() ?? '',
      memberName: json['memberName']?.toString() ?? '',
      memberRole: json['memberRole']?.toString() ?? '',
      outgoingResponsibilities: json['outgoingResponsibilities']?.toString() ?? '',
      incomingMemberName: json['incomingMemberName']?.toString() ?? '',
      knowledgeTransferNotes: json['knowledgeTransferNotes']?.toString() ?? '',
      openActionItems: json['openActionItems']?.toString() ?? '',
      assetHandoverNotes: json['assetHandoverNotes']?.toString() ?? '',
      completedAt: json['completedAt']?.toString(),
      completedBy: json['completedBy']?.toString(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

/// A team activity post (low-priority, announcement-like feed for
/// project team activities only).
class TeamActivityPost {
  String id;
  String authorName;
  String authorRole;
  String message;
  DateTime createdAt;
  List<String> attachments;

  TeamActivityPost({
    String? id,
    required this.authorName,
    this.authorRole = '',
    required this.message,
    DateTime? createdAt,
    List<String>? attachments,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        attachments = attachments ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorRole': authorRole,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'attachments': attachments,
      };

  factory TeamActivityPost.fromJson(Map<String, dynamic> json) {
    return TeamActivityPost(
      id: json['id']?.toString(),
      authorName: json['authorName']?.toString() ?? '',
      authorRole: json['authorRole']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      attachments: List<String>.from(json['attachments'] ?? []),
    );
  }
}

/// The full Team Management plan for a project.
class TeamManagementPlan {
  // 1. Team mobilization process (text plan)
  String mobilizationProcess;

  // 2. Per-member mobilization checklists
  List<MemberMobilization> memberMobilizations;

  // 3. Project onboarding summary (auto-generated, stored for caching)
  String projectOnboardingSummary;
  DateTime? summaryGeneratedAt;

  // 4. Role onboarding requirements
  List<RoleOnboardingRequirement> roleOnboardingRequirements;

  // 5. Team member recognition process (skippable)
  String recognitionProcess;
  bool recognitionSkipped;

  // 6. Role handover records
  List<RoleHandoverRecord> handoverRecords;

  // 7. Team activities feed (low priority)
  List<TeamActivityPost> activityPosts;

  TeamManagementPlan({
    this.mobilizationProcess = '',
    List<MemberMobilization>? memberMobilizations,
    this.projectOnboardingSummary = '',
    this.summaryGeneratedAt,
    List<RoleOnboardingRequirement>? roleOnboardingRequirements,
    this.recognitionProcess = '',
    this.recognitionSkipped = false,
    List<RoleHandoverRecord>? handoverRecords,
    List<TeamActivityPost>? activityPosts,
  })  : memberMobilizations = memberMobilizations ?? [],
        roleOnboardingRequirements = roleOnboardingRequirements ?? [],
        handoverRecords = handoverRecords ?? [],
        activityPosts = activityPosts ?? [];

  Map<String, dynamic> toJson() => {
        'mobilizationProcess': mobilizationProcess,
        'memberMobilizations':
            memberMobilizations.map((m) => m.toJson()).toList(),
        'projectOnboardingSummary': projectOnboardingSummary,
        'summaryGeneratedAt': summaryGeneratedAt?.toIso8601String(),
        'roleOnboardingRequirements':
            roleOnboardingRequirements.map((r) => r.toJson()).toList(),
        'recognitionProcess': recognitionProcess,
        'recognitionSkipped': recognitionSkipped,
        'handoverRecords': handoverRecords.map((h) => h.toJson()).toList(),
        'activityPosts': activityPosts.map((a) => a.toJson()).toList(),
      };

  factory TeamManagementPlan.fromJson(Map<String, dynamic> json) {
    return TeamManagementPlan(
      mobilizationProcess: json['mobilizationProcess']?.toString() ?? '',
      memberMobilizations: (json['memberMobilizations'] as List?)
              ?.map((m) => MemberMobilization.fromJson(m))
              .toList() ??
          [],
      projectOnboardingSummary:
          json['projectOnboardingSummary']?.toString() ?? '',
      summaryGeneratedAt:
          DateTime.tryParse(json['summaryGeneratedAt']?.toString() ?? ''),
      roleOnboardingRequirements: (json['roleOnboardingRequirements'] as List?)
              ?.map((r) => RoleOnboardingRequirement.fromJson(r))
              .toList() ??
          [],
      recognitionProcess: json['recognitionProcess']?.toString() ?? '',
      recognitionSkipped: json['recognitionSkipped'] ?? false,
      handoverRecords: (json['handoverRecords'] as List?)
              ?.map((h) => RoleHandoverRecord.fromJson(h))
              .toList() ??
          [],
      activityPosts: (json['activityPosts'] as List?)
              ?.map((a) => TeamActivityPost.fromJson(a))
              .toList() ??
          [],
    );
  }

  factory TeamManagementPlan.empty() => TeamManagementPlan();

  TeamManagementPlan copyWith({
    String? mobilizationProcess,
    List<MemberMobilization>? memberMobilizations,
    String? projectOnboardingSummary,
    DateTime? summaryGeneratedAt,
    List<RoleOnboardingRequirement>? roleOnboardingRequirements,
    String? recognitionProcess,
    bool? recognitionSkipped,
    List<RoleHandoverRecord>? handoverRecords,
    List<TeamActivityPost>? activityPosts,
  }) {
    return TeamManagementPlan(
      mobilizationProcess: mobilizationProcess ?? this.mobilizationProcess,
      memberMobilizations: memberMobilizations ?? this.memberMobilizations,
      projectOnboardingSummary:
          projectOnboardingSummary ?? this.projectOnboardingSummary,
      summaryGeneratedAt: summaryGeneratedAt ?? this.summaryGeneratedAt,
      roleOnboardingRequirements:
          roleOnboardingRequirements ?? this.roleOnboardingRequirements,
      recognitionProcess: recognitionProcess ?? this.recognitionProcess,
      recognitionSkipped: recognitionSkipped ?? this.recognitionSkipped,
      handoverRecords: handoverRecords ?? this.handoverRecords,
      activityPosts: activityPosts ?? this.activityPosts,
    );
  }
}
