/// Document review and approval tracking models for the Document Review Matrix
library;

/// Status of a document in the review workflow
enum ReviewStatus {
  notStarted,
  pendingReview,
  underReview,
  changesRequested,
  approved,
  rejected,
}

/// Category of document for organization in the review matrix
enum DocumentCategory {
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

/// Phase where the document originates
enum DocumentPhase {
  initiation,
  frontEndPlanning,
  planning,
  design,
  execution,
  launch,
}

/// History entry for tracking review actions on a document
class ReviewHistoryEntry {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String reviewerRole;
  final ReviewAction action;
  final String? comments;
  final DateTime timestamp;

  const ReviewHistoryEntry({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerRole,
    required this.action,
    this.comments,
    required this.timestamp,
  });

  ReviewHistoryEntry copyWith({
    String? id,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
    ReviewAction? action,
    String? comments,
    DateTime? timestamp,
  }) {
    return ReviewHistoryEntry(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerRole: reviewerRole ?? this.reviewerRole,
      action: action ?? this.action,
      comments: comments ?? this.comments,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'reviewerRole': reviewerRole,
        'action': action.index,
        'comments': comments,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ReviewHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReviewHistoryEntry(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      reviewerId: json['reviewerId'] ?? '',
      reviewerName: json['reviewerName'] ?? '',
      reviewerRole: json['reviewerRole'] ?? '',
      action: json['action'] is int
          ? ReviewAction.values[json['action'] % ReviewAction.values.length]
          : ReviewAction.assigned,
      comments: json['comments'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// Actions that can be taken during review
enum ReviewAction {
  assigned,
  submitted,
  underReview,
  approved,
  rejected,
  changesRequested,
  comment,
}

/// Represents a document in the review matrix
class DocumentReviewItem {
  final String id;
  final String documentId; // Reference to source document
  final String documentName;
  final String description;
  final DocumentPhase phase;
  final DocumentCategory category;
  final String sourceCheckpoint; // Where it originates in navigation
  final ReviewStatus status;
  final String? primaryReviewerId;
  final String? primaryReviewerName;
  final String? secondaryReviewerId;
  final String? secondaryReviewerName;
  final String? finalApproverId;
  final String? finalApproverName;
  final DateTime? reviewDueDate;
  final DateTime? approvedDate;
  final String? reviewComments;
  final List<ReviewHistoryEntry> reviewHistory;
  final int version;
  final DateTime lastUpdated;
  final String? documentLocation; // Path to source screen for preview
  final bool requiresRereview; // Flag for re-review after source changes

  const DocumentReviewItem({
    required this.id,
    required this.documentId,
    required this.documentName,
    this.description = '',
    required this.phase,
    required this.category,
    required this.sourceCheckpoint,
    this.status = ReviewStatus.notStarted,
    this.primaryReviewerId,
    this.primaryReviewerName,
    this.secondaryReviewerId,
    this.secondaryReviewerName,
    this.finalApproverId,
    this.finalApproverName,
    this.reviewDueDate,
    this.approvedDate,
    this.reviewComments,
    this.reviewHistory = const [],
    this.version = 1,
    required this.lastUpdated,
    this.documentLocation,
    this.requiresRereview = false,
  });

  DocumentReviewItem copyWith({
    String? id,
    String? documentId,
    String? documentName,
    String? description,
    DocumentPhase? phase,
    DocumentCategory? category,
    String? sourceCheckpoint,
    ReviewStatus? status,
    String? primaryReviewerId,
    String? primaryReviewerName,
    String? secondaryReviewerId,
    String? secondaryReviewerName,
    String? finalApproverId,
    String? finalApproverName,
    DateTime? reviewDueDate,
    DateTime? approvedDate,
    String? reviewComments,
    List<ReviewHistoryEntry>? reviewHistory,
    int? version,
    DateTime? lastUpdated,
    String? documentLocation,
    bool? requiresRereview,
  }) {
    return DocumentReviewItem(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentName: documentName ?? this.documentName,
      description: description ?? this.description,
      phase: phase ?? this.phase,
      category: category ?? this.category,
      sourceCheckpoint: sourceCheckpoint ?? this.sourceCheckpoint,
      status: status ?? this.status,
      primaryReviewerId: primaryReviewerId ?? this.primaryReviewerId,
      primaryReviewerName: primaryReviewerName ?? this.primaryReviewerName,
      secondaryReviewerId: secondaryReviewerId ?? this.secondaryReviewerId,
      secondaryReviewerName: secondaryReviewerName ?? this.secondaryReviewerName,
      finalApproverId: finalApproverId ?? this.finalApproverId,
      finalApproverName: finalApproverName ?? this.finalApproverName,
      reviewDueDate: reviewDueDate ?? this.reviewDueDate,
      approvedDate: approvedDate ?? this.approvedDate,
      reviewComments: reviewComments ?? this.reviewComments,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      documentLocation: documentLocation ?? this.documentLocation,
      requiresRereview: requiresRereview ?? this.requiresRereview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentId': documentId,
        'documentName': documentName,
        'description': description,
        'phase': phase.name,
        'category': category.name,
        'sourceCheckpoint': sourceCheckpoint,
        'status': status.name,
        'primaryReviewerId': primaryReviewerId,
        'primaryReviewerName': primaryReviewerName,
        'secondaryReviewerId': secondaryReviewerId,
        'secondaryReviewerName': secondaryReviewerName,
        'finalApproverId': finalApproverId,
        'finalApproverName': finalApproverName,
        'reviewDueDate': reviewDueDate?.toIso8601String(),
        'approvedDate': approvedDate?.toIso8601String(),
        'reviewComments': reviewComments,
        'reviewHistory': reviewHistory.map((e) => e.toJson()).toList(),
        'version': version,
        'lastUpdated': lastUpdated.toIso8601String(),
        'documentLocation': documentLocation,
        'requiresRereview': requiresRereview,
      };

  factory DocumentReviewItem.fromJson(Map<String, dynamic> json) {
    return DocumentReviewItem(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      documentId: json['documentId'] ?? '',
      documentName: json['documentName'] ?? '',
      description: json['description'] ?? '',
      phase: DocumentPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => DocumentPhase.initiation,
      ),
      category: DocumentCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DocumentCategory.governance,
      ),
      sourceCheckpoint: json['sourceCheckpoint'] ?? '',
      status: ReviewStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReviewStatus.notStarted,
      ),
      primaryReviewerId: json['primaryReviewerId'],
      primaryReviewerName: json['primaryReviewerName'],
      secondaryReviewerId: json['secondaryReviewerId'],
      secondaryReviewerName: json['secondaryReviewerName'],
      finalApproverId: json['finalApproverId'],
      finalApproverName: json['finalApproverName'],
      reviewDueDate: json['reviewDueDate'] != null
          ? DateTime.parse(json['reviewDueDate'])
          : null,
      approvedDate: json['approvedDate'] != null
          ? DateTime.parse(json['approvedDate'])
          : null,
      reviewComments: json['reviewComments'],
      reviewHistory: json['reviewHistory'] != null
          ? (json['reviewHistory'] as List)
              .map((e) => ReviewHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      version: json['version'] ?? 1,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      documentLocation: json['documentLocation'],
      requiresRereview: json['requiresRereview'] ?? false,
    );
  }

  /// Get display label for status
  String get statusLabel {
    switch (status) {
      case ReviewStatus.notStarted:
        return 'Not Started';
      case ReviewStatus.pendingReview:
        return 'Pending Review';
      case ReviewStatus.underReview:
        return 'Under Review';
      case ReviewStatus.changesRequested:
        return 'Changes Requested';
      case ReviewStatus.approved:
        return 'Approved';
      case ReviewStatus.rejected:
        return 'Rejected';
    }
  }

  /// Get display label for phase
  String get phaseLabel {
    switch (phase) {
      case DocumentPhase.initiation:
        return 'Initiation';
      case DocumentPhase.frontEndPlanning:
        return 'Front-End Planning';
      case DocumentPhase.planning:
        return 'Planning';
      case DocumentPhase.design:
        return 'Design';
      case DocumentPhase.execution:
        return 'Execution';
      case DocumentPhase.launch:
        return 'Launch';
    }
  }

  /// Get display label for category
  String get categoryLabel {
    switch (category) {
      case DocumentCategory.governance:
        return 'Governance';
      case DocumentCategory.requirements:
        return 'Requirements';
      case DocumentCategory.riskCompliance:
        return 'Risk & Compliance';
      case DocumentCategory.execution:
        return 'Execution';
      case DocumentCategory.technical:
        return 'Technical';
      case DocumentCategory.quality:
        return 'Quality';
      case DocumentCategory.contractsProcurement:
        return 'Contracts & Procurement';
      case DocumentCategory.scheduleCost:
        return 'Schedule & Cost';
      case DocumentCategory.teamStakeholders:
        return 'Team & Stakeholders';
    }
  }

  /// Check if review is overdue
  bool get isOverdue {
    if (reviewDueDate == null ||
        status == ReviewStatus.approved ||
        status == ReviewStatus.rejected) {
      return false;
    }
    return DateTime.now().isAfter(reviewDueDate!);
  }

  /// Get days until due (negative if overdue)
  int? get daysUntilDue {
    if (reviewDueDate == null) return null;
    return reviewDueDate!.difference(DateTime.now()).inDays;
  }

  /// Check if document needs re-review
  bool get needsRereview => requiresRereview && status == ReviewStatus.approved;

  /// Create a new version incrementing version number
  DocumentReviewItem newVersion() {
    return copyWith(
      version: version + 1,
      lastUpdated: DateTime.now(),
      status: ReviewStatus.pendingReview,
      requiresRereview: false,
    );
  }

  /// Add a history entry
  DocumentReviewItem addHistoryEntry(ReviewHistoryEntry entry) {
    return copyWith(
      reviewHistory: [...reviewHistory, entry],
      lastUpdated: DateTime.now(),
    );
  }
}

/// Template for creating review items for known document types
class DocumentReviewTemplate {
  final String documentId;
  final String documentName;
  final String description;
  final DocumentPhase phase;
  final DocumentCategory category;
  final String sourceCheckpoint;
  final String? documentLocation;
  final List<String> defaultReviewerRoles;
  final bool requiresFinalApproval;

  const DocumentReviewTemplate({
    required this.documentId,
    required this.documentName,
    this.description = '',
    required this.phase,
    required this.category,
    required this.sourceCheckpoint,
    this.documentLocation,
    this.defaultReviewerRoles = const [],
    this.requiresFinalApproval = true,
  });

  /// Create a DocumentReviewItem from this template
  DocumentReviewItem createReviewItem({
    String? primaryReviewerId,
    String? primaryReviewerName,
    String? secondaryReviewerId,
    String? secondaryReviewerName,
    String? finalApproverId,
    String? finalApproverName,
    DateTime? reviewDueDate,
  }) {
    return DocumentReviewItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      documentId: documentId,
      documentName: documentName,
      description: description,
      phase: phase,
      category: category,
      sourceCheckpoint: sourceCheckpoint,
      documentLocation: documentLocation,
      primaryReviewerId: primaryReviewerId,
      primaryReviewerName: primaryReviewerName,
      secondaryReviewerId: secondaryReviewerId,
      secondaryReviewerName: secondaryReviewerName,
      finalApproverId: finalApproverId,
      finalApproverName: finalApproverName,
      reviewDueDate: reviewDueDate,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Predefined document templates for common project documents
class DocumentTemplates {
  static const List<DocumentReviewTemplate> initiationDocuments = [
    DocumentReviewTemplate(
      documentId: 'business_case',
      documentName: 'Business Case',
      description: 'Project justification, cost-benefit analysis, and strategic alignment',
      phase: DocumentPhase.initiation,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'business_case',
      defaultReviewerRoles: ['Project Sponsor', 'Steering Committee'],
    ),
    DocumentReviewTemplate(
      documentId: 'scope_statement',
      documentName: 'Scope Statement',
      description: 'Defined project scope, boundaries, and deliverables',
      phase: DocumentPhase.initiation,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'business_case',
      defaultReviewerRoles: ['Project Manager', 'Business Sponsor'],
    ),
    DocumentReviewTemplate(
      documentId: 'project_charter',
      documentName: 'Project Charter',
      description: 'Project authorization, objectives, and stakeholder identification',
      phase: DocumentPhase.initiation,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'project_charter',
      defaultReviewerRoles: ['Senior Management', 'Project Sponsor'],
    ),
    DocumentReviewTemplate(
      documentId: 'initiation_risk_assessment',
      documentName: 'Risk Identification',
      description: 'Initial risk register and mitigation strategies',
      phase: DocumentPhase.initiation,
      category: DocumentCategory.riskCompliance,
      sourceCheckpoint: 'risk_identification',
      defaultReviewerRoles: ['Risk Management Office'],
    ),
  ];

  static const List<DocumentReviewTemplate> frontEndPlanningDocuments = [
    DocumentReviewTemplate(
      documentId: 'fep_requirements',
      documentName: 'Project Requirements',
      description: 'Detailed project requirements documentation',
      phase: DocumentPhase.frontEndPlanning,
      category: DocumentCategory.requirements,
      sourceCheckpoint: 'fep_requirements',
      defaultReviewerRoles: ['Requirements Review Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'fep_risks',
      documentName: 'Project Risks',
      description: 'Front-end planning risk register',
      phase: DocumentPhase.frontEndPlanning,
      category: DocumentCategory.riskCompliance,
      sourceCheckpoint: 'fep_risks',
      defaultReviewerRoles: ['Risk Management Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'fep_contracting',
      documentName: 'Contracting Plan',
      description: 'Contract requirements and vendor strategy',
      phase: DocumentPhase.frontEndPlanning,
      category: DocumentCategory.contractsProcurement,
      sourceCheckpoint: 'fep_contract_vendor_quotes',
      defaultReviewerRoles: ['Legal Department', 'Procurement'],
    ),
    DocumentReviewTemplate(
      documentId: 'fep_procurement',
      documentName: 'Procurement Plan',
      description: 'Procurement strategy and vendor selection',
      phase: DocumentPhase.frontEndPlanning,
      category: DocumentCategory.contractsProcurement,
      sourceCheckpoint: 'fep_procurement',
      defaultReviewerRoles: ['Procurement Department'],
    ),
    DocumentReviewTemplate(
      documentId: 'fep_security',
      documentName: 'Security Plan',
      description: 'Security requirements and access controls',
      phase: DocumentPhase.frontEndPlanning,
      category: DocumentCategory.riskCompliance,
      sourceCheckpoint: 'fep_security',
      defaultReviewerRoles: ['Security Review Board'],
    ),
  ];

  static const List<DocumentReviewTemplate> planningDocuments = [
    DocumentReviewTemplate(
      documentId: 'planning_requirements',
      documentName: 'Planning Requirements',
      description: 'Comprehensive planning requirements documentation',
      phase: DocumentPhase.planning,
      category: DocumentCategory.requirements,
      sourceCheckpoint: 'requirements',
      defaultReviewerRoles: ['Requirements Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'wbs',
      documentName: 'Work Breakdown Structure',
      description: 'Detailed work breakdown structure',
      phase: DocumentPhase.planning,
      category: DocumentCategory.execution,
      sourceCheckpoint: 'work_breakdown_structure',
      defaultReviewerRoles: ['Project Manager', 'Planning Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'project_goals_milestones',
      documentName: 'Project Goals & Milestones',
      description: 'Project objectives and milestone definitions',
      phase: DocumentPhase.planning,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'project_goals_milestones',
      defaultReviewerRoles: ['Project Sponsor'],
    ),
    DocumentReviewTemplate(
      documentId: 'roles_responsibilities',
      documentName: 'Roles & Responsibilities',
      description: 'Team role definitions and responsibilities matrix',
      phase: DocumentPhase.planning,
      category: DocumentCategory.teamStakeholders,
      sourceCheckpoint: 'organization_roles_responsibilities',
      defaultReviewerRoles: ['HR Department'],
    ),
    DocumentReviewTemplate(
      documentId: 'staffing_plan',
      documentName: 'Staffing Plan',
      description: 'Resource requirements and staffing strategy',
      phase: DocumentPhase.planning,
      category: DocumentCategory.teamStakeholders,
      sourceCheckpoint: 'organization_staffing_plan',
      defaultReviewerRoles: ['Resource Management Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'stakeholder_management',
      documentName: 'Stakeholder Management Plan',
      description: 'Stakeholder identification and engagement strategy',
      phase: DocumentPhase.planning,
      category: DocumentCategory.teamStakeholders,
      sourceCheckpoint: 'stakeholder_management',
      defaultReviewerRoles: ['Stakeholder Management Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'ssher',
      documentName: 'SSHER Plan',
      description: 'Safety, Security, Health, Environment, and Reliability plan',
      phase: DocumentPhase.planning,
      category: DocumentCategory.riskCompliance,
      sourceCheckpoint: 'ssher',
      defaultReviewerRoles: ['SSHER Review Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'quality_management',
      documentName: 'Quality Management Plan',
      description: 'Quality assurance and control procedures',
      phase: DocumentPhase.planning,
      category: DocumentCategory.quality,
      sourceCheckpoint: 'quality_management',
      defaultReviewerRoles: ['QA Department'],
    ),
    DocumentReviewTemplate(
      documentId: 'construction_plan',
      documentName: 'Construction Plan',
      description: 'Construction execution strategy',
      phase: DocumentPhase.planning,
      category: DocumentCategory.execution,
      sourceCheckpoint: 'execution_plan_construction_plan',
      defaultReviewerRoles: ['Execution Committee'],
    ),
    DocumentReviewTemplate(
      documentId: 'infrastructure_plan',
      documentName: 'Infrastructure Plan',
      description: 'Infrastructure execution strategy',
      phase: DocumentPhase.planning,
      category: DocumentCategory.technical,
      sourceCheckpoint: 'execution_plan_infrastructure_plan',
      defaultReviewerRoles: ['Infrastructure Review Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'agile_delivery_plan',
      documentName: 'Agile Delivery Plan',
      description: 'Agile methodology and sprint planning',
      phase: DocumentPhase.planning,
      category: DocumentCategory.execution,
      sourceCheckpoint: 'execution_plan_agile_delivery_plan',
      defaultReviewerRoles: ['Agile Coach', 'Project Manager'],
    ),
    DocumentReviewTemplate(
      documentId: 'design_planning',
      documentName: 'Design Planning',
      description: 'Design phase preparation and approach',
      phase: DocumentPhase.planning,
      category: DocumentCategory.technical,
      sourceCheckpoint: 'design',
      defaultReviewerRoles: ['Design Review Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'technology_planning',
      documentName: 'Technology Planning',
      description: 'Technology stack and infrastructure planning',
      phase: DocumentPhase.planning,
      category: DocumentCategory.technical,
      sourceCheckpoint: 'technology',
      defaultReviewerRoles: ['Technology Governance Committee'],
    ),
    DocumentReviewTemplate(
      documentId: 'interface_management',
      documentName: 'Interface Management Plan',
      description: 'System and process interface definitions',
      phase: DocumentPhase.planning,
      category: DocumentCategory.technical,
      sourceCheckpoint: 'interface_management',
      defaultReviewerRoles: ['Integration Review Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'planning_risk_assessment',
      documentName: 'Risk Assessment',
      description: 'Comprehensive risk assessment and mitigation',
      phase: DocumentPhase.planning,
      category: DocumentCategory.riskCompliance,
      sourceCheckpoint: 'risk_assessment',
      defaultReviewerRoles: ['Risk Management Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'contract_planning',
      documentName: 'Contract Planning',
      description: 'Contract preparation and management',
      phase: DocumentPhase.planning,
      category: DocumentCategory.contractsProcurement,
      sourceCheckpoint: 'contracts',
      defaultReviewerRoles: ['Legal Department', 'Procurement'],
    ),
    DocumentReviewTemplate(
      documentId: 'procurement_planning',
      documentName: 'Procurement Plan',
      description: 'Procurement planning and execution strategy',
      phase: DocumentPhase.planning,
      category: DocumentCategory.contractsProcurement,
      sourceCheckpoint: 'procurement',
      defaultReviewerRoles: ['Procurement Department'],
    ),
    DocumentReviewTemplate(
      documentId: 'schedule',
      documentName: 'Project Schedule',
      description: 'Project timeline and schedule',
      phase: DocumentPhase.planning,
      category: DocumentCategory.scheduleCost,
      sourceCheckpoint: 'schedule',
      defaultReviewerRoles: ['Project Planning Office'],
    ),
    DocumentReviewTemplate(
      documentId: 'cost_estimate',
      documentName: 'Cost Estimate',
      description: 'Project budget and cost estimation',
      phase: DocumentPhase.planning,
      category: DocumentCategory.scheduleCost,
      sourceCheckpoint: 'cost_estimate',
      defaultReviewerRoles: ['Finance Department'],
    ),
    DocumentReviewTemplate(
      documentId: 'scope_tracking_plan',
      documentName: 'Scope Tracking Plan',
      description: 'Scope management and control procedures',
      phase: DocumentPhase.planning,
      category: DocumentCategory.requirements,
      sourceCheckpoint: 'scope_tracking_plan',
      defaultReviewerRoles: ['Change Control Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'change_management',
      documentName: 'Change Management Plan',
      description: 'Change control procedures',
      phase: DocumentPhase.planning,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'change_management',
      defaultReviewerRoles: ['Change Control Board'],
    ),
    DocumentReviewTemplate(
      documentId: 'issue_management',
      documentName: 'Issue Management Plan',
      description: 'Issue tracking and resolution procedures',
      phase: DocumentPhase.planning,
      category: DocumentCategory.governance,
      sourceCheckpoint: 'issue_management',
      defaultReviewerRoles: ['Project Manager'],
    ),
    DocumentReviewTemplate(
      documentId: 'training_plan',
      documentName: 'Training & Team Building Plan',
      description: 'Training activities and team development',
      phase: DocumentPhase.planning,
      category: DocumentCategory.teamStakeholders,
      sourceCheckpoint: 'team_training',
      defaultReviewerRoles: ['Training Department'],
    ),
  ];

  /// Get all templates
  static List<DocumentReviewTemplate> get allTemplates => [
        ...initiationDocuments,
        ...frontEndPlanningDocuments,
        ...planningDocuments,
      ];

  /// Get templates by phase
  static List<DocumentReviewTemplate> getByPhase(DocumentPhase phase) {
    return allTemplates.where((t) => t.phase == phase).toList();
  }

  /// Get templates by category
  static List<DocumentReviewTemplate> getByCategory(DocumentCategory category) {
    return allTemplates.where((t) => t.category == category).toList();
  }

  /// Find template by document ID
  static DocumentReviewTemplate? findById(String documentId) {
    for (final template in allTemplates) {
      if (template.documentId == documentId) return template;
    }
    return null;
  }
}
