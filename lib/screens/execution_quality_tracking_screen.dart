import 'package:flutter/material.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/execution_phase_page.dart';

class ExecutionQualityTrackingScreen extends StatelessWidget {
  const ExecutionQualityTrackingScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExecutionQualityTrackingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExecutionPhasePage(
      pageKey: 'execution_quality_tracking',
      title: 'Execution Quality Tracking',
      subtitle:
          'Track audits, inspections, acceptance evidence, corrective actions, and KPI performance during execution.',
      introText:
          'This workspace is seeded from Planning Quality Management and stays editable for live execution tracking.',
      sections: const [
        ExecutionSectionSpec(
          key: 'quality_management_plan',
          title: 'Project Quality Management Plan',
          description:
              'Maintain the live execution version of the approved quality management plan.',
        ),
        ExecutionSectionSpec(
          key: 'quality_objectives',
          title: 'Quality Objectives & Acceptance Criteria',
          description:
              'Track acceptance readiness, evidence, and current status for execution deliverables.',
        ),
        ExecutionSectionSpec(
          key: 'inspection_test_plan',
          title: 'Inspection & Test Plan',
          description:
              'Track inspection points, test activities, hold points, owners, and outcomes.',
        ),
        ExecutionSectionSpec(
          key: 'quality_metrics_dashboard',
          title: 'Quality Metrics Dashboard',
          description:
              'Track live KPI updates, thresholds, trends, and exceptions requiring intervention.',
        ),
        ExecutionSectionSpec(
          key: 'quality_audit_plan',
          title: 'Quality Audit Plan',
          description:
              'Run planned audits, document results, and confirm closeout evidence.',
        ),
        ExecutionSectionSpec(
          key: 'nonconformance_corrective_actions',
          title: 'Nonconformance & Corrective Action Log',
          description:
              'Track nonconformances, root causes, corrective actions, due dates, and verification closure.',
        ),
      ],
      navigation: PhaseNavigationSpec(
        backLabel:
            PlanningPhaseNavigation.backLabel('execution_quality_tracking'),
        nextLabel:
            PlanningPhaseNavigation.nextLabel('execution_quality_tracking'),
        onBack: () => PlanningPhaseNavigation.goToPrevious(
          context,
          'execution_quality_tracking',
        ),
        onNext: () => PlanningPhaseNavigation.goToNext(
          context,
          'execution_quality_tracking',
        ),
      ),
    );
  }
}
