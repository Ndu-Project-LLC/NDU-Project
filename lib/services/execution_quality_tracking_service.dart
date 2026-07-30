/// Execution Quality Tracking Service
/// Handles data seeding from Planning phase, calendar integration, and persistence.
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/models/execution_quality_tracking_model.dart';
import 'package:ndu_project/models/project_data_model.dart' hide AuditResultStatus;

class ExecutionQualityTrackingService {
  static final ExecutionQualityTrackingService _instance = 
      ExecutionQualityTrackingService._();
  static ExecutionQualityTrackingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ExecutionQualityTrackingService._();

  // ============================================================================
  // AUTO-SEED FROM PLANNING PHASE
  // ============================================================================

  /// Seed execution tracking data from Planning Quality Management
  /// Returns the seeded data with all items converted to trackable format
  Future<ExecutionQualityTrackingData> seedFromPlanningPhase({
    required String projectId,
    required QualityManagementData planningData,
    bool forceReseed = false,
  }) async {
    
    // Check if already exists and we're not forcing reseed
    if (!forceReseed) {
      final existing = await loadTrackingData(projectId: projectId);
      if (existing != null && existing.seededFromPlanning) {
        return existing; // Already seeded, return existing
      }
    }

    final now = DateTime.now();
    
    // Convert planning objectives to execution objectives
    final objectives = planningData.objectives.map((obj) {
      // Parse planned date from objective or use default (30 days from now)
      DateTime plannedDate = now.add(const Duration(days: 30));
      
      return ExecutionObjective(
        sourcePlanningId: obj.id,
        title: obj.title,
        description: obj.acceptanceCriteria,
        acceptanceCriteria: obj.acceptanceCriteria,
        status: ExecutionQualityStatus.planned,
        assignedTo: obj.owner,
        plannedDate: plannedDate,
        progressPercent: 0,
      );
    }).toList();

    // Convert QA/QC techniques to inspections
    final inspections = <ExecutionInspection>[];
    
    for (final qa in planningData.qaTechniques) {
      DateTime scheduledDate = now.add(const Duration(days: 14));
      
      inspections.add(ExecutionInspection(
        sourcePlanningId: qa.id,
        title: qa.name,
        type: 'QA',
        description: qa.description,
        scope: qa.frequency,
        inspector: '',
        scheduledDate: scheduledDate,
        isHoldPoint: false,
      ));
    }

    for (final qc in planningData.qcTechniques) {
      DateTime scheduledDate = now.add(const Duration(days: 14));
      
      inspections.add(ExecutionInspection(
        sourcePlanningId: qc.id,
        title: qc.name,
        type: 'QC',
        description: qc.description,
        scope: qc.frequency,
        inspector: '',
        scheduledDate: scheduledDate,
        isHoldPoint: false,
      ));
    }

    // Convert audit plan to execution audits
    final audits = planningData.auditPlan.map((audit) {
      DateTime plannedDate = now.add(const Duration(days: 21));
      if (audit.plannedDate.isNotEmpty) {
        final parsed = DateTime.tryParse(audit.plannedDate);
        if (parsed != null) plannedDate = parsed;
      }
      
      return ExecutionAudit(
        sourcePlanningId: audit.id,
        title: audit.title,
        auditType: _determineAuditType(audit.title),
        scope: audit.scope,
        auditor: audit.owner,
        plannedDate: plannedDate,
        reminderSet: true,
        reminderDaysBefore: 3,
      );
    }).toList();

    // Convert KPIs to execution KPI entries
    final kpiEntries = planningData.customKpis.map((kpi) {
      final target = double.tryParse(kpi.targetValue) ?? 0;
      return ExecutionKpiEntry(
        kpiName: kpi.name,
        kpiUnit: kpi.unit,
        targetValue: target,
        trend: kpi.trendDirection,
      );
    }).toList();

    // Convert corrective actions
    final correctiveActions = planningData.correctiveActions.map((ca) {
      DateTime dueDate = now.add(const Duration(days: 14));
      if (ca.dueDate.isNotEmpty) {
        final parsed = DateTime.tryParse(ca.dueDate);
        if (parsed != null) dueDate = parsed;
      }
      
      return ExecutionCorrectiveAction(
        title: ca.title,
        description: ca.action,
        rootCause: ca.rootCause,
        priority: _mapPriority(ca.status.name),
        status: ExecutionQualityStatus.inProgress,
        assignedTo: ca.owner,
        dueDate: dueDate,
      );
    }).toList();

    // Create calendar events for audits and inspections with dates
    final calendarEvents = <CalendarEvent>[];
    
    for (final audit in audits) {
      calendarEvents.add(CalendarEvent(
        sourceType: 'audit',
        sourceId: audit.id,
        title: '📋 ${audit.title}',
        description: '${audit.auditType} Audit - ${audit.scope}',
        eventDate: audit.plannedDate,
        attendees: [audit.auditor, audit.auditee].where((e) => e.isNotEmpty).toList(),
        reminderMinutesBefore: audit.reminderDaysBefore * 24 * 60, // Convert days to minutes
      ));
    }
    
    for (final inspection in inspections.where((i) => i.isHoldPoint)) {
      calendarEvents.add(CalendarEvent(
        sourceType: 'inspection',
        sourceId: inspection.id,
        title: '🔍 ${inspection.title} (Hold Point)',
        description: '${inspection.type} Inspection - Cannot proceed until passed',
        eventDate: inspection.scheduledDate,
        attendees: [inspection.inspector].where((e) => e.isNotEmpty).toList(),
        reminderMinutesBefore: 1440, // 1 day before
      ));
    }

    // Create dashboard snapshot
    final dashboardSnapshot = ExecutionDashboardSnapshot.compute(
      objectives: objectives,
      audits: audits,
      inspections: inspections,
      correctiveActions: correctiveActions,
    );

    final trackingData = ExecutionQualityTrackingData(
      seededFromPlanning: true,
      seededAt: now,
      qualityPlanLive: planningData.qualityPlan,
      objectives: objectives,
      inspections: inspections,
      audits: audits,
      kpiEntries: kpiEntries,
      correctiveActions: correctiveActions,
      calendarEvents: calendarEvents,
      dashboardSnapshot: dashboardSnapshot,
    );

    // Save to Firestore
    await saveTrackingData(
      projectId: projectId, 
      trackingData: trackingData,
    );

    return trackingData;
  }

  String _determineAuditType(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('external') || lower.contains('third party') || lower.contains('customer')) {
      return 'External';
    } else if (lower.contains('regulatory') || lower.contains('compliance') || lower.contains('iso')) {
      return 'Regulatory';
    }
    return 'Internal';
  }

  CaPriority _mapPriority(String? priority) {
    if (priority == null) return CaPriority.medium;
    final lower = priority.toLowerCase();
    if (lower.contains('critical')) return CaPriority.critical;
    if (lower.contains('high')) return CaPriority.high;
    if (lower.contains('low')) return CaPriority.low;
    return CaPriority.medium;
  }

  // ============================================================================
  // DATA PERSISTENCE
  // ============================================================================

  Future<void> saveTrackingData({
    required String projectId,
    required ExecutionQualityTrackingData trackingData,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_quality')
          .doc('tracking_data')
          .set(trackingData.toJson());
    } catch (e) {
      debugPrint('Error saving execution quality tracking: $e');
      rethrow;
    }
  }

  Future<ExecutionQualityTrackingData?> loadTrackingData({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_quality')
          .doc('tracking_data')
          .get();

      if (!doc.exists) return null;

      return ExecutionQualityTrackingData.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error loading execution quality tracking: $e');
      return null;
    }
  }

  Future<void> updateTrackingData({
    required String projectId,
    required ExecutionQualityTrackingData Function(ExecutionQualityTrackingData current) updater,
  }) async {
    final current = await loadTrackingData(projectId: projectId) 
        ?? ExecutionQualityTrackingData.empty();
    
    final updated = updater(current);
    await saveTrackingData(projectId: projectId, trackingData: updated);
  }

  // ============================================================================
  // CALENDAR INTEGRATION
  // ============================================================================

  /// Sync a quality event to Team Calendar
  Future<CalendarEvent> syncToTeamCalendar({
    required String projectId,
    required CalendarEvent event,
    required String postedBy,
  }) async {
    try {
      // Create TeamActivity in project's team activities collection
      final activityRef = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('team_activities')
          .add({
            'title': event.title,
            'description': event.description,
            'postedBy': postedBy,
            'date': '${event.eventDate.year}-${event.eventDate.month.toString().padLeft(2, '0')}-${event.eventDate.day.toString().padLeft(2, '0')}',
            'category': _mapToTeamActivityCategory(event.sourceType),
            'createdAt': FieldValue.serverTimestamp(),
            'sourceType': event.sourceType,
            'sourceId': event.sourceId,
            'reminderSet': event.reminderMinutesBefore > 0,
            'reminderMinutesBefore': event.reminderMinutesBefore,
          });

      // Update the calendar event with the team activity ID
      final updatedEvent = CalendarEvent(
        id: event.id,
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        title: event.title,
        description: event.description,
        eventDate: event.eventDate,
        endTime: event.endTime,
        location: event.location,
        attendees: event.attendees,
        allDay: event.allDay,
        reminderMinutesBefore: event.reminderMinutesBefore,
        recurrence: event.recurrence,
        syncedToTeamCalendar: true,
        syncedAt: DateTime.now(),
        teamActivityId: activityRef.id,
      );

      // Update in quality tracking subcollection
      await _updateCalendarEvent(
        projectId: projectId, 
        eventId: event.id, 
        updatedEvent: updatedEvent,
      );

      return updatedEvent;
    } catch (e) {
      debugPrint('Error syncing to team calendar: $e');
      rethrow;
    }
  }

  /// Bulk sync all pending calendar events
  Future<int> syncAllPendingEvents({
    required String projectId,
    required String postedBy,
  }) async {
    final trackingData = await loadTrackingData(projectId: projectId);
    if (trackingData == null) return 0;

    int syncedCount = 0;
    
    for (final event in trackingData.calendarEvents.where((e) => !e.syncedToTeamCalendar)) {
      try {
        await syncToTeamCalendar(
          projectId: projectId, 
          event: event, 
          postedBy: postedBy,
        );
        syncedCount++;
      } catch (e) {
        debugPrint('Failed to sync event ${event.id}: $e');
      }
    }

    return syncedCount;
  }

  Future<void> _updateCalendarEvent({
    required String projectId,
    required String eventId,
    required CalendarEvent updatedEvent,
  }) async {
    final trackingData = await loadTrackingData(projectId: projectId);
    if (trackingData == null) return;

    final updatedEvents = trackingData.calendarEvents.map((e) {
      return e.id == eventId ? updatedEvent : e;
    }).toList();

    await updateTrackingData(
      projectId: projectId,
      updater: (current) => current.copyWith(calendarEvents: updatedEvents),
    );
  }

  String _mapToTeamActivityCategory(String sourceType) {
    switch (sourceType) {
      case 'audit':
        return 'Action Required'; // Audits require action
      case 'inspection':
        return 'Event'; // Inspections are events
      case 'corrective_action':
        return 'Action Required'; // CAs require action
      default:
        return 'Update';
    }
  }

  // ============================================================================
  // STATUS WORKFLOW HELPERS
  // ============================================================================

  /// Advance status through workflow
  ExecutionQualityStatus advanceStatus(ExecutionQualityStatus current) {
    switch (current) {
      case ExecutionQualityStatus.planned:
        return ExecutionQualityStatus.inProgress;
      case ExecutionQualityStatus.inProgress:
        return ExecutionQualityStatus.complete;
      case ExecutionQualityStatus.complete:
        return ExecutionQualityStatus.verified;
      case ExecutionQualityStatus.verified:
        return ExecutionQualityStatus.verified; // Terminal state
      case ExecutionQualityStatus.blocked:
        return ExecutionQualityStatus.inProgress; // Unblock back to progress
      case ExecutionQualityStatus.overdue:
        return ExecutionQualityStatus.inProgress; // Get back on track
    }
  }

  /// Check if status transition is valid
  bool isValidTransition(ExecutionQualityStatus from, ExecutionQualityStatus to) {
    // Define valid transitions
    const validTransitions = <ExecutionQualityStatus, Set<ExecutionQualityStatus>>{
      ExecutionQualityStatus.planned: {
        ExecutionQualityStatus.inProgress,
        ExecutionQualityStatus.blocked,
        ExecutionQualityStatus.overdue,
      },
      ExecutionQualityStatus.inProgress: {
        ExecutionQualityStatus.complete,
        ExecutionQualityStatus.blocked,
        ExecutionQualityStatus.overdue,
      },
      ExecutionQualityStatus.complete: {
        ExecutionQualityStatus.verified,
      },
      ExecutionQualityStatus.verified: {}, // Terminal
      ExecutionQualityStatus.blocked: {
        ExecutionQualityStatus.inProgress,
        ExecutionQualityStatus.overdue,
      },
      ExecutionQualityStatus.overdue: {
        ExecutionQualityStatus.inProgress,
        ExecutionQualityStatus.complete,
      },
    };

    return validTransitions[from]?.contains(to) ?? false;
  }

  // ============================================================================
  // DASHBOARD COMPUTATION
  // ============================================================================

  /// Refresh dashboard snapshot with latest data
  Future<ExecutionDashboardSnapshot> refreshDashboard({
    required String projectId,
  }) async {
    final trackingData = await loadTrackingData(projectId: projectId);
    if (trackingData == null) {
      return ExecutionDashboardSnapshot.empty();
    }

    final snapshot = ExecutionDashboardSnapshot.compute(
      objectives: trackingData.objectives,
      audits: trackingData.audits,
      inspections: trackingData.inspections,
      correctiveActions: trackingData.correctiveActions,
    );

    // Save updated snapshot
    await updateTrackingData(
      projectId: projectId,
      updater: (current) => current.copyWith(dashboardSnapshot: snapshot),
    );

    return snapshot;
  }

  // ============================================================================
  // REMINDER GENERATION
  // ============================================================================

  /// Get upcoming reminders for notifications
  List<CalendarEvent> getUpcomingReminders({
    required ExecutionQualityTrackingData trackingData,
    Duration within = const Duration(days: 7),
  }) {
    final now = DateTime.now();
    final cutoff = now.add(within);

    return trackingData.calendarEvents.where((event) {
      // Only events that haven't happened yet
      if (event.eventDate.isBefore(now)) return false;
      
      // Event is within the window
      if (event.eventDate.isAfter(cutoff)) return false;
      
      // Has a reminder set
      if (event.reminderMinutesBefore <= 0) return false;
      
      // Reminder time has passed or is coming up soon
      final reminderTime = event.eventDate.subtract(
        Duration(minutes: event.reminderMinutesBefore),
      );
      
      return !reminderTime.isAfter(cutoff);
    }).toList();
  }

  /// Get overdue items that need attention
  OverdueReport getOverdueReport({
    required ExecutionQualityTrackingData trackingData,
  }) {
    final now = DateTime.now();
    
    final overdueObjectives = trackingData.objectives
        .where((o) => o.isOverdue)
        .toList()
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));

    final overdueAudits = trackingData.audits
        .where((a) => a.isOverdue)
        .toList()
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));

    final overdueInspections = trackingData.inspections
        .where((i) => i.isOverdue)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final overdueCAs = trackingData.correctiveActions
        .where((ca) => ca.isOverdue)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return OverdueReport(
      totalOverdueItems: 
          overdueObjectives.length + 
          overdueAudits.length + 
          overdueInspections.length + 
          overdueCAs.length,
      overdueObjectives: overdueObjectives,
      overdueAudits: overdueAudits,
      overdueInspections: overdueInspections,
      overdueCorrectiveActions: overdueCAs,
      generatedAt: now,
    );
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

class OverdueReport {
  final int totalOverdueItems;
  final List<ExecutionObjective> overdueObjectives;
  final List<ExecutionAudit> overdueAudits;
  final List<ExecutionInspection> overdueInspections;
  final List<ExecutionCorrectiveAction> overdueCorrectiveActions;
  final DateTime generatedAt;

  OverdueReport({
    required this.totalOverdueItems,
    required this.overdueObjectives,
    required this.overdueAudits,
    required this.overdueInspections,
    required this.overdueCorrectiveActions,
    required this.generatedAt,
  });
}

// Date formatting helper
class _DateFormatHelper {
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
