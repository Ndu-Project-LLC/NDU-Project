/// Execution Quality Tracking Data Models
/// Used for live tracking during project execution phase.
library;

import 'package:flutter/material.dart';

// ============================================================================
// STATUS WORKFLOW ENUMS
// ============================================================================

/// Status workflow for quality items during execution
enum ExecutionQualityStatus {
  planned('Planned', Icons.schedule, Color(0xFF6B7280)),
  inProgress('In Progress', Icons.pending_actions, Color(0xFF3B82F6)),
  complete('Complete', Icons.check_circle, Color(0xFF10B981)),
  verified('Verified', Icons.verified, Color(0xFF059669)),
  blocked('Blocked', Icons.block, Color(0xFFEF4444)),
  overdue('Overdue', Icons.warning_amber, Color(0xFFF59E0B));

  const ExecutionQualityStatus(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Audit result status
enum AuditResultStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  passed('Passed'),
  passedWithObservations('Passed with Observations'),
  failed('Failed'),
  deferred('Deferred');

  const AuditResultStatus(this.label);
  final String label;
}

/// Corrective action priority
enum CaPriority {
  critical('Critical', Color(0xFFDC2626)),
  high('High', Color(0xFFEF4444)),
  medium('Medium', Color(0xFFF59E0B)),
  low('Low', Color(0xFF10B981));

  const CaPriority(this.label, this.color);
  final String label;
  final Color color;
}

// ============================================================================
// EXECUTION QUALITY TRACKING DATA MODEL
// ============================================================================

class ExecutionQualityTrackingData {
  final String id;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final bool seededFromPlanning;
  final DateTime? seededAt;

  // Seeded from planning - Quality Plan
  final String qualityPlanLive;
  
  // Objectives tracking
  final List<ExecutionObjective> objectives;
  
  // Inspection & Test tracking
  final List<ExecutionInspection> inspections;
  
  // Audit tracking
  final List<ExecutionAudit> audits;
  
  // Metrics & KPIs
  final List<ExecutionKpiEntry> kpiEntries;
  
  // Corrective actions
  final List<ExecutionCorrectiveAction> correctiveActions;
  
  // Cost of Quality tracking
  final ExecutionCoqTracking coqTracking;
  
  // Calendar integration flags
  final List<CalendarEvent> calendarEvents;
  
  // Dashboard snapshot
  final ExecutionDashboardSnapshot dashboardSnapshot;

  ExecutionQualityTrackingData({
    String? id,
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.seededFromPlanning = false,
    this.seededAt,
    this.qualityPlanLive = '',
    List<ExecutionObjective>? objectives,
    List<ExecutionInspection>? inspections,
    List<ExecutionAudit>? audits,
    List<ExecutionKpiEntry>? kpiEntries,
    List<ExecutionCorrectiveAction>? correctiveActions,
    ExecutionCoqTracking? coqTracking,
    List<CalendarEvent>? calendarEvents,
    ExecutionDashboardSnapshot? dashboardSnapshot,
  }) : id = id ?? _generateId(),
       createdAt = createdAt ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now(),
       objectives = objectives ?? [],
       inspections = inspections ?? [],
       audits = audits ?? [],
       kpiEntries = kpiEntries ?? [],
       correctiveActions = correctiveActions ?? [],
       coqTracking = coqTracking ?? ExecutionCoqTracking.empty(),
       calendarEvents = calendarEvents ?? [],
       dashboardSnapshot = dashboardSnapshot ?? ExecutionDashboardSnapshot.empty();

  static String _generateId() => 
      'eqt_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionQualityTrackingData.empty() => 
      ExecutionQualityTrackingData();

  factory ExecutionQualityTrackingData.fromJson(Map<String, dynamic> json) {
    return ExecutionQualityTrackingData(
      id: json['id'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
      seededFromPlanning: json['seededFromPlanning'] as bool? ?? false,
      seededAt: json['seededAt'] != null 
          ? DateTime.parse(json['seededAt'] as String) 
          : null,
      qualityPlanLive: json['qualityPlanLive'] as String? ?? '',
      objectives: (json['objectives'] as List?)
          ?.map((e) => ExecutionObjective.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      inspections: (json['inspections'] as List?)
          ?.map((e) => ExecutionInspection.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      audits: (json['audits'] as List?)
          ?.map((e) => ExecutionAudit.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      kpiEntries: (json['kpiEntries'] as List?)
          ?.map((e) => ExecutionKpiEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      correctiveActions: (json['correctiveActions'] as List?)
          ?.map((e) => ExecutionCorrectiveAction.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      coqTracking: json['coqTracking'] != null 
          ? ExecutionCoqTracking.fromJson(json['coqTracking'] as Map<String, dynamic>)
          : null,
      calendarEvents: (json['calendarEvents'] as List?)
          ?.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      dashboardSnapshot: json['dashboardSnapshot'] != null 
          ? ExecutionDashboardSnapshot.fromJson(json['dashboardSnapshot'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'seededFromPlanning': seededFromPlanning,
    'seededAt': seededAt?.toIso8601String(),
    'qualityPlanLive': qualityPlanLive,
    'objectives': objectives.map((e) => e.toJson()).toList(),
    'inspections': inspections.map((e) => e.toJson()).toList(),
    'audits': audits.map((e) => e.toJson()).toList(),
    'kpiEntries': kpiEntries.map((e) => e.toJson()).toList(),
    'correctiveActions': correctiveActions.map((e) => e.toJson()).toList(),
    'coqTracking': coqTracking.toJson(),
    'calendarEvents': calendarEvents.map((e) => e.toJson()).toList(),
    'dashboardSnapshot': dashboardSnapshot.toJson(),
  };

  ExecutionQualityTrackingData copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastUpdated,
    bool? seededFromPlanning,
    DateTime? seededAt,
    String? qualityPlanLive,
    List<ExecutionObjective>? objectives,
    List<ExecutionInspection>? inspections,
    List<ExecutionAudit>? audits,
    List<ExecutionKpiEntry>? kpiEntries,
    List<ExecutionCorrectiveAction>? correctiveActions,
    ExecutionCoqTracking? coqTracking,
    List<CalendarEvent>? calendarEvents,
    ExecutionDashboardSnapshot? dashboardSnapshot,
  }) {
    return ExecutionQualityTrackingData(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? DateTime.now(),
      seededFromPlanning: seededFromPlanning ?? this.seededFromPlanning,
      seededAt: seededAt ?? this.seededAt,
      qualityPlanLive: qualityPlanLive ?? this.qualityPlanLive,
      objectives: objectives ?? this.objectives,
      inspections: inspections ?? this.inspections,
      audits: audits ?? this.audits,
      kpiEntries: kpiEntries ?? this.kpiEntries,
      correctiveActions: correctiveActions ?? this.correctiveActions,
      coqTracking: coqTracking ?? this.coqTracking,
      calendarEvents: calendarEvents ?? this.calendarEvents,
      dashboardSnapshot: dashboardSnapshot ?? this.dashboardSnapshot,
    );
  }
}

// ============================================================================
// EXECUTION OBJECTIVE (from Planning Objective)
// ============================================================================

class ExecutionObjective {
  final String id;
  final String sourcePlanningId; // Link back to planning phase
  final String title;
  final String description;
  final String acceptanceCriteria;
  ExecutionQualityStatus status;
  final String evidenceNotes;
  final List<String> evidenceUrls; // Uploaded evidence files
  final String assignedTo;
  final DateTime plannedDate;
  final DateTime? actualDate;
  final double progressPercent; // 0-100
  final String varianceReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExecutionObjective({
    String? id,
    required this.title,
    this.sourcePlanningId = '',
    this.description = '',
    this.acceptanceCriteria = '',
    this.status = ExecutionQualityStatus.planned,
    this.evidenceNotes = '',
    List<String>? evidenceUrls,
    this.assignedTo = '',
    required this.plannedDate,
    this.actualDate,
    this.progressPercent = 0,
    this.varianceReason = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _generateId(),
       evidenceUrls = evidenceUrls ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static String _generateId() => 
      'obj_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionObjective.fromJson(Map<String, dynamic> json) {
    return ExecutionObjective(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      sourcePlanningId: json['sourcePlanningId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      acceptanceCriteria: json['acceptanceCriteria'] as String? ?? '',
      status: ExecutionQualityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionQualityStatus.planned,
      ),
      evidenceNotes: json['evidenceNotes'] as String? ?? '',
      evidenceUrls: (json['evidenceUrls'] as List?)?.cast<String>() ?? [],
      assignedTo: json['assignedTo'] as String? ?? '',
      plannedDate: DateTime.parse(json['plannedDate'] as String),
      actualDate: json['actualDate'] != null 
          ? DateTime.parse(json['actualDate'] as String) 
          : null,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      varianceReason: json['varianceReason'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourcePlanningId': sourcePlanningId,
    'title': title,
    'description': description,
    'acceptanceCriteria': acceptanceCriteria,
    'status': status.name,
    'evidenceNotes': evidenceNotes,
    'evidenceUrls': evidenceUrls,
    'assignedTo': assignedTo,
    'plannedDate': plannedDate.toIso8601String(),
    'actualDate': actualDate?.toIso8601String(),
    'progressPercent': progressPercent,
    'varianceReason': varianceReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  bool get isOverdue => 
      status != ExecutionQualityStatus.complete && 
      status != ExecutionQualityStatus.verified &&
      plannedDate.isBefore(DateTime.now());

  int get daysRemaining => 
      plannedDate.difference(DateTime.now()).inDays;
}

// ============================================================================
// EXECUTION INSPECTION (from QC/QA Techniques)
// ============================================================================

class ExecutionInspection {
  final String id;
  final String sourcePlanningId;
  final String title;
  final String type; // 'QA' or 'QC'
  final String description;
  final String scope;
  ExecutionQualityStatus status;
  final String inspector;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final String result;
  final String findings;
  final String nonConformances;
  final bool isHoldPoint; // Cannot proceed until passed
  final String linkedWorkPackage;
  final List<String> evidenceUrls;
  final bool addedToCalendar;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExecutionInspection({
    String? id,
    required this.title,
    this.sourcePlanningId = '',
    this.type = 'QC',
    this.description = '',
    this.scope = '',
    this.status = ExecutionQualityStatus.planned,
    this.inspector = '',
    required this.scheduledDate,
    this.completedDate,
    this.result = '',
    this.findings = '',
    this.nonConformances = '',
    this.isHoldPoint = false,
    this.linkedWorkPackage = '',
    List<String>? evidenceUrls,
    this.addedToCalendar = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _generateId(),
       evidenceUrls = evidenceUrls ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static String _generateId() => 
      'insp_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionInspection.fromJson(Map<String, dynamic> json) {
    return ExecutionInspection(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      sourcePlanningId: json['sourcePlanningId'] as String? ?? '',
      type: json['type'] as String? ?? 'QC',
      description: json['description'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      status: ExecutionQualityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionQualityStatus.planned,
      ),
      inspector: json['inspector'] as String? ?? '',
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      completedDate: json['completedDate'] != null 
          ? DateTime.parse(json['completedDate'] as String) 
          : null,
      result: json['result'] as String? ?? '',
      findings: json['findings'] as String? ?? '',
      nonConformances: json['nonConformances'] as String? ?? '',
      isHoldPoint: json['isHoldPoint'] as bool? ?? false,
      linkedWorkPackage: json['linkedWorkPackage'] as String? ?? '',
      evidenceUrls: (json['evidenceUrls'] as List?)?.cast<String>() ?? [],
      addedToCalendar: json['addedToCalendar'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourcePlanningId': sourcePlanningId,
    'title': title,
    'type': type,
    'description': description,
    'scope': scope,
    'status': status.name,
    'inspector': inspector,
    'scheduledDate': scheduledDate.toIso8601String(),
    'completedDate': completedDate?.toIso8601String(),
    'result': result,
    'findings': findings,
    'nonConformances': nonConformances,
    'isHoldPoint': isHoldPoint,
    'linkedWorkPackage': linkedWorkPackage,
    'evidenceUrls': evidenceUrls,
    'addedToCalendar': addedToCalendar,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

// ============================================================================
// EXECUTION AUDIT (from Planning Audit Plan)
// ============================================================================

class ExecutionAudit {
  final String id;
  final String sourcePlanningId;
  final String title;
  final String auditType; // Internal, External, Regulatory
  final String scope;
  final String auditor;
  final String auditee;
  final DateTime plannedDate;
  final DateTime? actualDate;
  ExecutionQualityStatus status;
  AuditResultStatus resultStatus;
  final String summary;
  final List<AuditFinding> findings;
  final String recommendations;
  final bool requiresFollowUp;
  final DateTime? followUpDate;
  final List<String> evidenceUrls;
  final bool addedToCalendar;
  final bool reminderSet;
  final int reminderDaysBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExecutionAudit({
    String? id,
    required this.title,
    this.sourcePlanningId = '',
    this.auditType = 'Internal',
    this.scope = '',
    this.auditor = '',
    this.auditee = '',
    required this.plannedDate,
    this.actualDate,
    this.status = ExecutionQualityStatus.planned,
    this.resultStatus = AuditResultStatus.notStarted,
    this.summary = '',
    List<AuditFinding>? findings,
    this.recommendations = '',
    this.requiresFollowUp = false,
    this.followUpDate,
    List<String>? evidenceUrls,
    this.addedToCalendar = false,
    this.reminderSet = false,
    this.reminderDaysBefore = 3,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _generateId(),
       findings = findings ?? [],
       evidenceUrls = evidenceUrls ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static String _generateId() => 
      'audit_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionAudit.fromJson(Map<String, dynamic> json) {
    return ExecutionAudit(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      sourcePlanningId: json['sourcePlanningId'] as String? ?? '',
      auditType: json['auditType'] as String? ?? 'Internal',
      scope: json['scope'] as String? ?? '',
      auditor: json['auditor'] as String? ?? '',
      auditee: json['auditee'] as String? ?? '',
      plannedDate: DateTime.parse(json['plannedDate'] as String),
      actualDate: json['actualDate'] != null 
          ? DateTime.parse(json['actualDate'] as String) 
          : null,
      status: ExecutionQualityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionQualityStatus.planned,
      ),
      resultStatus: AuditResultStatus.values.firstWhere(
        (e) => e.name == json['resultStatus'],
        orElse: () => AuditResultStatus.notStarted,
      ),
      summary: json['summary'] as String? ?? '',
      findings: (json['findings'] as List?)
          ?.map((e) => AuditFinding.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recommendations: json['recommendations'] as String? ?? '',
      requiresFollowUp: json['requiresFollowUp'] as bool? ?? false,
      followUpDate: json['followUpDate'] != null 
          ? DateTime.parse(json['followUpDate'] as String) 
          : null,
      evidenceUrls: (json['evidenceUrls'] as List?)?.cast<String>() ?? [],
      addedToCalendar: json['addedToCalendar'] as bool? ?? false,
      reminderSet: json['reminderSet'] as bool? ?? false,
      reminderDaysBefore: json['reminderDaysBefore'] as int? ?? 3,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourcePlanningId': sourcePlanningId,
    'title': title,
    'auditType': auditType,
    'scope': scope,
    'auditor': auditor,
    'auditee': auditee,
    'plannedDate': plannedDate.toIso8601String(),
    'actualDate': actualDate?.toIso8601String(),
    'status': status.name,
    'resultStatus': resultStatus.name,
    'summary': summary,
    'findings': findings.map((e) => e.toJson()).toList(),
    'recommendations': recommendations,
    'requiresFollowUp': requiresFollowUp,
    'followUpDate': followUpDate?.toIso8601String(),
    'evidenceUrls': evidenceUrls,
    'addedToCalendar': addedToCalendar,
    'reminderSet': reminderSet,
    'reminderDaysBefore': reminderDaysBefore,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  bool get isOverdue => 
      status != ExecutionQualityStatus.complete && 
      status != ExecutionQualityStatus.verified &&
      plannedDate.isBefore(DateTime.now());
}

class AuditFinding {
  final String id;
  final String reference;
  final String description;
  final String severity; // Major, Minor, Observation
  final String rootCause;
  final String correctiveAction;
  final bool closed;
  final DateTime? closedDate;

  AuditFinding({
    String? id,
    required this.reference,
    required this.description,
    this.severity = 'Minor',
    this.rootCause = '',
    this.correctiveAction = '',
    this.closed = false,
    this.closedDate,
  }) : id = id ?? _generateId();

  static String _generateId() => 
      'finding_${DateTime.now().millisecondsSinceEpoch}';

  factory AuditFinding.fromJson(Map<String, dynamic> json) {
    return AuditFinding(
      id: json['id'] as String?,
      reference: json['reference'] as String? ?? '',
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'Minor',
      rootCause: json['rootCause'] as String? ?? '',
      correctiveAction: json['correctiveAction'] as String? ?? '',
      closed: json['closed'] as bool? ?? false,
      closedDate: json['closedDate'] != null 
          ? DateTime.parse(json['closedDate'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'description': description,
    'severity': severity,
    'rootCause': rootCause,
    'correctiveAction': correctiveAction,
    'closed': closed,
    'closedDate': closedDate?.toIso8601String(),
  };
}

// ============================================================================
// EXECUTION KPI ENTRY (for metrics tracking)
// ============================================================================

class ExecutionKpiEntry {
  final String id;
  final String kpiName;
  final String kpiUnit;
  final double targetValue;
  final double? currentValue;
  final double thresholdMin; // Alert if below
  final double thresholdMax; // Alert if above
  final List<KpiDataPoint> dataPoints;
  final String trend; // 'improving', 'declining', 'stable'
  final String notes;
  final DateTime recordedAt;
  final DateTime createdAt;

  ExecutionKpiEntry({
    String? id,
    required this.kpiName,
    this.kpiUnit = '%',
    required this.targetValue,
    this.currentValue,
    this.thresholdMin = 0,
    this.thresholdMax = 100,
    List<KpiDataPoint>? dataPoints,
    this.trend = 'stable',
    this.notes = '',
    DateTime? recordedAt,
    DateTime? createdAt,
  }) : id = id ?? _generateId(),
       dataPoints = dataPoints ?? [],
       recordedAt = recordedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  static String _generateId() => 
      'kpi_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionKpiEntry.fromJson(Map<String, dynamic> json) {
    return ExecutionKpiEntry(
      id: json['id'] as String?,
      kpiName: json['kpiName'] as String? ?? '',
      kpiUnit: json['kpiUnit'] as String? ?? '%',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble(),
      thresholdMin: (json['thresholdMin'] as num?)?.toDouble() ?? 0,
      thresholdMax: (json['thresholdMax'] as num?)?.toDouble() ?? 100,
      dataPoints: (json['dataPoints'] as List?)
          ?.map((e) => KpiDataPoint.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      trend: json['trend'] as String? ?? 'stable',
      notes: json['notes'] as String? ?? '',
      recordedAt: json['recordedAt'] != null 
          ? DateTime.parse(json['recordedAt'] as String) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kpiName': kpiName,
    'kpiUnit': kpiUnit,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'thresholdMin': thresholdMin,
    'thresholdMax': thresholdMax,
    'dataPoints': dataPoints.map((e) => e.toJson()).toList(),
    'trend': trend,
    'notes': notes,
    'recordedAt': recordedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  bool get needsAttention {
    if (currentValue == null) return false;
    return currentValue! < thresholdMin || currentValue! > thresholdMax;
  }

  double? get achievementPercent {
    if (currentValue == null || targetValue == 0) return null;
    return (currentValue! / targetValue) * 100;
  }
}

class KpiDataPoint {
  final DateTime date;
  final double value;
  final String notes;

  KpiDataPoint({required this.date, required this.value, this.notes = ''});

  factory KpiDataPoint.fromJson(Map<String, dynamic> json) {
    return KpiDataPoint(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
    'notes': notes,
  };
}

// ============================================================================
// EXECUTION CORRECTIVE ACTION
// ============================================================================

class ExecutionCorrectiveAction {
  final String id;
  final String linkedAuditId;
  final String linkedInspectionId;
  final String title;
  final String description;
  final String rootCause;
  CaPriority priority;
  ExecutionQualityStatus status;
  final String assignedTo;
  final DateTime dueDate;
  final DateTime? completedDate;
  final String resolution;
  final String verificationNotes;
  final bool verified;
  final DateTime? verifiedDate;
  final String verifiedBy;
  final List<String> evidenceUrls;
  final bool addedToCalendar;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExecutionCorrectiveAction({
    String? id,
    this.linkedAuditId = '',
    this.linkedInspectionId = '',
    required this.title,
    this.description = '',
    this.rootCause = '',
    this.priority = CaPriority.medium,
    this.status = ExecutionQualityStatus.inProgress,
    this.assignedTo = '',
    required this.dueDate,
    this.completedDate,
    this.resolution = '',
    this.verificationNotes = '',
    this.verified = false,
    this.verifiedDate,
    this.verifiedBy = '',
    List<String>? evidenceUrls,
    this.addedToCalendar = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _generateId(),
       evidenceUrls = evidenceUrls ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static String _generateId() => 
      'ca_${DateTime.now().millisecondsSinceEpoch}';

  factory ExecutionCorrectiveAction.fromJson(Map<String, dynamic> json) {
    return ExecutionCorrectiveAction(
      id: json['id'] as String?,
      linkedAuditId: json['linkedAuditId'] as String? ?? '',
      linkedInspectionId: json['linkedInspectionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rootCause: json['rootCause'] as String? ?? '',
      priority: CaPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => CaPriority.medium,
      ),
      status: ExecutionQualityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionQualityStatus.inProgress,
      ),
      assignedTo: json['assignedTo'] as String? ?? '',
      dueDate: DateTime.parse(json['dueDate'] as String),
      completedDate: json['completedDate'] != null 
          ? DateTime.parse(json['completedDate'] as String) 
          : null,
      resolution: json['resolution'] as String? ?? '',
      verificationNotes: json['verificationNotes'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      verifiedDate: json['verifiedDate'] != null 
          ? DateTime.parse(json['verifiedDate'] as String) 
          : null,
      verifiedBy: json['verifiedBy'] as String? ?? '',
      evidenceUrls: (json['evidenceUrls'] as List?)?.cast<String>() ?? [],
      addedToCalendar: json['addedToCalendar'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'linkedAuditId': linkedAuditId,
    'linkedInspectionId': linkedInspectionId,
    'title': title,
    'description': description,
    'rootCause': rootCause,
    'priority': priority.name,
    'status': status.name,
    'assignedTo': assignedTo,
    'dueDate': dueDate.toIso8601String(),
    'completedDate': completedDate?.toIso8601String(),
    'resolution': resolution,
    'verificationNotes': verificationNotes,
    'verified': verified,
    'verifiedDate': verifiedDate?.toIso8601String(),
    'verifiedBy': verifiedBy,
    'evidenceUrls': evidenceUrls,
    'addedToCalendar': addedToCalendar,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  bool get isOverdue => 
      status != ExecutionQualityStatus.complete && 
      status != ExecutionQualityStatus.verified &&
      dueDate.isBefore(DateTime.now());

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

// ============================================================================
// COST OF QUALITY TRACKING
// ============================================================================

class ExecutionCoqTracking {
  final double preventionCostActual;
  final double appraisalCostActual;
  final double internalFailureCostActual;
  final double externalFailureCostActual;
  final double totalCoqActual;
  final DateTime lastUpdated;
  final List<CoqEntry> entries;

  ExecutionCoqTracking({
    this.preventionCostActual = 0,
    this.appraisalCostActual = 0,
    this.internalFailureCostActual = 0,
    this.externalFailureCostActual = 0,
    this.totalCoqActual = 0,
    DateTime? lastUpdated,
    List<CoqEntry>? entries,
  }) : lastUpdated = lastUpdated ?? DateTime.now(),
       entries = entries ?? [];

  factory ExecutionCoqTracking.empty() => ExecutionCoqTracking();

  factory ExecutionCoqTracking.fromJson(Map<String, dynamic> json) {
    return ExecutionCoqTracking(
      preventionCostActual: (json['preventionCostActual'] as num?)?.toDouble() ?? 0,
      appraisalCostActual: (json['appraisalCostActual'] as num?)?.toDouble() ?? 0,
      internalFailureCostActual: (json['internalFailureCostActual'] as num?)?.toDouble() ?? 0,
      externalFailureCostActual: (json['externalFailureCostActual'] as num?)?.toDouble() ?? 0,
      totalCoqActual: (json['totalCoqActual'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
      entries: (json['entries'] as List?)
          ?.map((e) => CoqEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'preventionCostActual': preventionCostActual,
    'appraisalCostActual': appraisalCostActual,
    'internalFailureCostActual': internalFailureCostActual,
    'externalFailureCostActual': externalFailureCostActual,
    'totalCoqActual': totalCoqActual,
    'lastUpdated': lastUpdated.toIso8601String(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

class CoqEntry {
  final String id;
  final String category; // Prevention, Appraisal, Internal Failure, External Failure
  final String description;
  final double amount;
  final String performer;
  final DateTime date;
  final String workPackageRef;

  CoqEntry({
    String? id,
    required this.category,
    required this.description,
    required this.amount,
    this.performer = '',
    required this.date,
    this.workPackageRef = '',
  }) : id = id ?? _generateId();

  static String _generateId() => 
      'coq_${DateTime.now().millisecondsSinceEpoch}';

  factory CoqEntry.fromJson(Map<String, dynamic> json) {
    return CoqEntry(
      id: json['id'] as String?,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      performer: json['performer'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      workPackageRef: json['workPackageRef'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'performer': performer,
    'date': date.toIso8601String(),
    'workPackageRef': workPackageRef,
  };
}

// ============================================================================
// CALENDAR EVENT (for Team Calendar Integration)
// ============================================================================

class CalendarEvent {
  final String id;
  final String sourceType; // 'audit', 'inspection', 'corrective_action', 'milestone'
  final String sourceId;
  final String title;
  final String description;
  final DateTime eventDate;
  final DateTime? endTime;
  final String location;
  final List<String> attendees;
  final bool allDay;
  final int reminderMinutesBefore; // 0 = no reminder
  final String recurrence; // None, Daily, Weekly, Monthly
  final bool syncedToTeamCalendar;
  final DateTime? syncedAt;
  final String teamActivityId; // If synced, ID of created TeamActivity
  final DateTime createdAt;

  CalendarEvent({
    String? id,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    this.description = '',
    required this.eventDate,
    this.endTime,
    this.location = '',
    List<String>? attendees,
    this.allDay = true,
    this.reminderMinutesBefore = 1440, // Default 1 day before
    this.recurrence = 'None',
    this.syncedToTeamCalendar = false,
    this.syncedAt,
    this.teamActivityId = '',
    DateTime? createdAt,
  }) : id = id ?? _generateId(),
       attendees = attendees ?? [],
       createdAt = createdAt ?? DateTime.now();

  static String _generateId() => 
      'calevt_${DateTime.now().millisecondsSinceEpoch}';

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String?,
      sourceType: json['sourceType'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventDate: DateTime.parse(json['eventDate'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      location: json['location'] as String? ?? '',
      attendees: (json['attendees'] as List?)?.cast<String>() ?? [],
      allDay: json['allDay'] as bool? ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 1440,
      recurrence: json['recurrence'] as String? ?? 'None',
      syncedToTeamCalendar: json['syncedToTeamCalendar'] as bool? ?? false,
      syncedAt: json['syncedAt'] != null 
          ? DateTime.parse(json['syncedAt'] as String) 
          : null,
      teamActivityId: json['teamActivityId'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'title': title,
    'description': description,
    'eventDate': eventDate.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'location': location,
    'attendees': attendees,
    'allDay': allDay,
    'reminderMinutesBefore': reminderMinutesBefore,
    'recurrence': recurrence,
    'syncedToTeamCalendar': syncedToTeamCalendar,
    'syncedAt': syncedAt?.toIso8601String(),
    'teamActivityId': teamActivityId,
    'createdAt': createdAt.toIso8601String(),
  };
}

// ============================================================================
// DASHBOARD SNAPSHOT
// ============================================================================

class ExecutionDashboardSnapshot {
  final int totalObjectives;
  final int objectivesComplete;
  final int objectivesInProgress;
  final int objectivesOverdue;
  
  final int totalAudits;
  final int auditsComplete;
  final int auditsPassed;
  final int auditsWithFindings;
  final int auditsOverdue;
  
  final int totalInspections;
  final int inspectionsComplete;
  final int inspectionsPassed;
  final int inspectionsOverdue;
  
  final int openCorrectiveActions;
  final int caOverdue;
  final int caCritical;
  
  final double overallQualityScore; // 0-100
  final DateTime computedAt;

  ExecutionDashboardSnapshot({
    this.totalObjectives = 0,
    this.objectivesComplete = 0,
    this.objectivesInProgress = 0,
    this.objectivesOverdue = 0,
    this.totalAudits = 0,
    this.auditsComplete = 0,
    this.auditsPassed = 0,
    this.auditsWithFindings = 0,
    this.auditsOverdue = 0,
    this.totalInspections = 0,
    this.inspectionsComplete = 0,
    this.inspectionsPassed = 0,
    this.inspectionsOverdue = 0,
    this.openCorrectiveActions = 0,
    this.caOverdue = 0,
    this.caCritical = 0,
    this.overallQualityScore = 0,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();

  factory ExecutionDashboardSnapshot.empty() => ExecutionDashboardSnapshot();

  factory ExecutionDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return ExecutionDashboardSnapshot(
      totalObjectives: json['totalObjectives'] as int? ?? 0,
      objectivesComplete: json['objectivesComplete'] as int? ?? 0,
      objectivesInProgress: json['objectivesInProgress'] as int? ?? 0,
      objectivesOverdue: json['objectivesOverdue'] as int? ?? 0,
      totalAudits: json['totalAudits'] as int? ?? 0,
      auditsComplete: json['auditsComplete'] as int? ?? 0,
      auditsPassed: json['auditsPassed'] as int? ?? 0,
      auditsWithFindings: json['auditsWithFindings'] as int? ?? 0,
      auditsOverdue: json['auditsOverdue'] as int? ?? 0,
      totalInspections: json['totalInspections'] as int? ?? 0,
      inspectionsComplete: json['inspectionsComplete'] as int? ?? 0,
      inspectionsPassed: json['inspectionsPassed'] as int? ?? 0,
      inspectionsOverdue: json['inspectionsOverdue'] as int? ?? 0,
      openCorrectiveActions: json['openCorrectiveActions'] as int? ?? 0,
      caOverdue: json['caOverdue'] as int? ?? 0,
      caCritical: json['caCritical'] as int? ?? 0,
      overallQualityScore: (json['overallQualityScore'] as num?)?.toDouble() ?? 0,
      computedAt: json['computedAt'] != null 
          ? DateTime.parse(json['computedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalObjectives': totalObjectives,
    'objectivesComplete': objectivesComplete,
    'objectivesInProgress': objectivesInProgress,
    'objectivesOverdue': objectivesOverdue,
    'totalAudits': totalAudits,
    'auditsComplete': auditsComplete,
    'auditsPassed': auditsPassed,
    'auditsWithFindings': auditsWithFindings,
    'auditsOverdue': auditsOverdue,
    'totalInspections': totalInspections,
    'inspectionsComplete': inspectionsComplete,
    'inspectionsPassed': inspectionsPassed,
    'inspectionsOverdue': inspectionsOverdue,
    'openCorrectiveActions': openCorrectiveActions,
    'caOverdue': caOverdue,
    'caCritical': caCritical,
    'overallQualityScore': overallQualityScore,
    'computedAt': computedAt.toIso8601String(),
  };

  /// Compute from tracking data
  static ExecutionDashboardSnapshot compute({
    required List<ExecutionObjective> objectives,
    required List<ExecutionAudit> audits,
    required List<ExecutionInspection> inspections,
    required List<ExecutionCorrectiveAction> correctiveActions,
  }) {
    final now = DateTime.now();
    
    // Objectives stats
    final totalObj = objectives.length;
    final objComplete = objectives.where((o) => 
      o.status == ExecutionQualityStatus.complete || 
      o.status == ExecutionQualityStatus.verified).length;
    final objInProgress = objectives.where((o) => 
      o.status == ExecutionQualityStatus.inProgress).length;
    final objOverdue = objectives.where((o) => o.isOverdue).length;
    
    // Audits stats
    final totalAud = audits.length;
    final audComplete = audits.where((a) => 
      a.status == ExecutionQualityStatus.complete || 
      a.status == ExecutionQualityStatus.verified).length;
    final audPassed = audits.where((a) => 
      a.resultStatus == AuditResultStatus.passed || 
      a.resultStatus == AuditResultStatus.passedWithObservations).length;
    final audFindings = audits.where((a) => a.findings.isNotEmpty).length;
    final audOverdue = audits.where((a) => a.isOverdue).length;
    
    // Inspections stats
    final totalInsp = inspections.length;
    final inspComplete = inspections.where((i) => 
      i.status == ExecutionQualityStatus.complete || 
      i.status == ExecutionQualityStatus.verified).length;
    final inspPassed = inspections.where((i) => i.result.toLowerCase().contains('pass')).length;
    final inspOverdue = inspections.where((i) => i.isOverdue).length;
    
    // CA stats
    final openCa = correctiveActions.where((ca) => 
      ca.status != ExecutionQualityStatus.complete && 
      ca.status != ExecutionQualityStatus.verified).length;
    final caOverdue = correctiveActions.where((ca) => ca.isOverdue).length;
    final caCrit = correctiveActions.where((ca) => 
      ca.priority == CaPriority.critical && 
      ca.status != ExecutionQualityStatus.complete).length;
    
    // Overall score calculation
    double score = 0;
    int components = 0;
    
    if (totalObj > 0) {
      score += (objComplete / totalObj) * 30; // Objectives worth 30%
      components++;
    }
    if (totalAud > 0) {
      score += (audPassed / totalAud) * 25; // Audits worth 25%
      components++;
    }
    if (totalInsp > 0) {
      score += (inspPassed / totalInsp) * 25; // Inspections worth 25%
      components++;
    }
    if (openCa > 0) {
      score += ((openCa - caOverdue) / openCa.clamp(min: 1)) * 20; // CA closure worth 20%
      components++;
    } else if (components > 0) {
      score += 20; // No open CAs = full marks
    }
    
    return ExecutionDashboardSnapshot(
      totalObjectives: totalObj,
      objectivesComplete: objComplete,
      objectivesInProgress: objInProgress,
      objectivesOverdue: objOverdue,
      totalAudits: totalAud,
      auditsComplete: audComplete,
      auditsPassed: audPassed,
      auditsWithFindings: audFindings,
      auditsOverdue: audOverdue,
      totalInspections: totalInsp,
      inspectionsComplete: inspComplete,
      inspectionsPassed: inspPassed,
      inspectionsOverdue: inspOverdue,
      openCorrectiveActions: openCa,
      caOverdue: caOverdue,
      caCritical: caCrit,
      overallQualityScore: score.clamp(0, 100),
    );
  }
}
