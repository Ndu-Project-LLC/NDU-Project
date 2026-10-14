import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';

QualityTaskEntry _task({
  required String id,
  required String title,
  QualityTaskStatus status = QualityTaskStatus.notStarted,
}) =>
    QualityTaskEntry(
      id: id,
      task: title,
      percentComplete: 0,
      responsible: 'Quality Lead',
      startDate: '2026-09-01',
      endDate: '2026-09-10',
      durationDays: 9,
      status: status,
      priority: QualityTaskPriority.moderate,
      comments: 'Track this work',
      resolvedDate: null,
    );

void main() {
  group('Quality Management activity traceability', () {
    test('publishes assigned open quality work with due dates and stable IDs', () {
      final quality = QualityManagementData.empty().copyWith(
        objectives: [
          QualityObjective(
            id: 'obj-1',
            title: 'Meet acceptance threshold',
            acceptanceCriteria: 'All critical tests pass',
            successMetric: 'Pass rate',
            targetValue: '100%',
            currentValue: '80%',
            owner: 'Quality Lead',
            linkedRequirement: 'REQ-7',
            linkedWbs: 'WBS-2',
            status: 'In Progress',
          ),
        ],
        workflowControls: [
          QualityWorkflowControl(
            id: 'control-1',
            type: QualityWorkflowType.qa,
            name: 'Weekly review',
            method: 'Peer review',
            tools: '',
            checklist: 'Acceptance criteria',
            frequency: 'Weekly',
            owner: 'Quality Lead',
            standardsReference: 'ISO 9001',
          ),
        ],
        qaTaskLog: [_task(id: 'qa-1', title: 'Review test plan')],
        qcTaskLog: [_task(id: 'qc-1', title: 'Inspect sample')],
        auditPlan: [
          QualityAuditEntry(
            id: 'audit-1',
            title: 'Supplier audit',
            scope: 'Critical components',
            plannedDate: '2026-10-01',
            completedDate: '',
            owner: 'Auditor',
            result: AuditResultStatus.pending,
            findings: '',
            notes: '',
          ),
        ],
        correctiveActions: [
          CorrectiveActionEntry(
            id: 'ca-1',
            auditEntryId: 'audit-1',
            title: 'Resolve supplier nonconformance',
            rootCause: 'Process gap',
            action: 'Update inspection process',
            owner: 'Supplier Lead',
            dueDate: '2026-10-15',
            status: CorrectiveActionStatus.open,
            createdAt: '2026-09-01',
            closedAt: '',
            verificationNotes: '',
          ),
        ],
      );

      final result = ProjectIntelligenceService.rebuildActivityLog(
        ProjectDataModel().copyWith(qualityManagementData: quality),
      );
      final byId = {for (final activity in result.projectActivities) activity.id: activity};

      final task = byId['activity_quality_qa_qa_1']!;
      expect(task.title, 'Review test plan');
      expect(task.assignedTo, 'Quality Lead');
      expect(task.dueDate, '2026-09-10');
      expect(task.sourceSection, 'quality_management');
      expect(task.discipline, 'Quality');
      expect(task.status, ProjectActivityStatus.pending);
      expect(byId['activity_quality_qc_qc_1']!.assignedTo, 'Quality Lead');
      expect(byId['activity_quality_audit_audit_1']!.dueDate, '2026-10-01');
      expect(byId['activity_quality_corrective_ca_1']!.assignedTo, 'Supplier Lead');
      expect(byId['activity_quality_objective_obj_1']!.assignedTo, 'Quality Lead');
      expect(byId['activity_quality_control_control_1']!.description,
          contains('Review cadence: Weekly'));
      // A cadence is descriptive until the quality model includes a schedulable
      // next-occurrence date; don't invent a due date from free text.
      expect(byId['activity_quality_control_control_1']!.dueDate, isEmpty);
    });

    test('does not publish completed tasks, passed audits, or closed actions', () {
      final quality = QualityManagementData.empty().copyWith(
        qaTaskLog: [
          _task(
            id: 'qa-done',
            title: 'Completed check',
            status: QualityTaskStatus.complete,
          ),
        ],
        auditPlan: [
          QualityAuditEntry(
            id: 'audit-pass',
            title: 'Passed audit',
            scope: '',
            plannedDate: '',
            completedDate: '2026-09-01',
            owner: 'Auditor',
            result: AuditResultStatus.pass,
            findings: '',
            notes: '',
          ),
        ],
        correctiveActions: [
          CorrectiveActionEntry(
            id: 'ca-closed',
            auditEntryId: '',
            title: 'Closed action',
            rootCause: '',
            action: '',
            owner: 'Quality Lead',
            dueDate: '',
            status: CorrectiveActionStatus.closed,
            createdAt: '',
            closedAt: '2026-09-01',
            verificationNotes: '',
          ),
        ],
      );

      final result = ProjectIntelligenceService.rebuildActivityLog(
        ProjectDataModel().copyWith(qualityManagementData: quality),
      );

      expect(
        result.projectActivities.where((a) => a.id.startsWith('activity_quality_')),
        isEmpty,
      );
    });

    test('preserves user lifecycle state across deterministic rebuilds', () {
      final quality = QualityManagementData.empty().copyWith(
        qaTaskLog: [_task(id: 'qa-1', title: 'Review test plan')],
      );
      final initial = ProjectIntelligenceService.rebuildActivityLog(
        ProjectDataModel().copyWith(qualityManagementData: quality),
      );
      final updated = initial.copyWith(
        projectActivities: [
          for (final activity in initial.projectActivities)
            if (activity.id == 'activity_quality_qa_qa_1')
              activity.copyWith(
                status: ProjectActivityStatus.acknowledged,
                dueDate: '2026-11-01',
              )
            else
              activity,
        ],
      );

      final rebuilt = ProjectIntelligenceService.rebuildActivityLog(updated);
      final activity = rebuilt.projectActivities
          .singleWhere((a) => a.id == 'activity_quality_qa_qa_1');
      expect(activity.status, ProjectActivityStatus.acknowledged);
      // A concrete source date supersedes a user-entered fallback date.
      expect(activity.dueDate, '2026-09-10');
    });

    test('preserves legacy quality change entries in project serialization', () {
      final quality = QualityManagementData.empty().copyWith(
        qualityChangeLog: [
          QualityChangeEntry(
            id: 'legacy-change-1',
            description: 'Update the inspection checklist',
            reason: 'New regulation',
            requestedBy: 'Quality Lead',
            approvedBy: 'Project Manager',
            date: '2026-08-01',
            status: 'Approved',
          ),
        ],
      );

      final restored = ProjectDataModel.fromJson(
        ProjectDataModel()
            .copyWith(qualityManagementData: quality)
            .toJson(),
      );

      expect(restored.qualityManagementData!.qualityChangeLog.single.id,
          'legacy-change-1');
      expect(restored.qualityManagementData!.qualityChangeLog.single.reason,
          'New regulation');
    });
  });
}
