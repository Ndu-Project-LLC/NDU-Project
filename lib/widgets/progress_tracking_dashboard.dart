import 'package:flutter/material.dart';
import 'package:ndu_project/models/deliverable_row.dart';
import 'package:ndu_project/models/recurring_deliverable_row.dart';
import 'package:ndu_project/models/status_report_row.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';

class ProgressTrackingDashboard extends StatelessWidget {
  const ProgressTrackingDashboard({
    super.key,
    required this.deliverables,
    required this.recurringDeliverables,
    required this.statusReports,
    required this.onDeliverablesChanged,
    required this.onRecurringChanged,
    required this.onStatusReportsChanged,
  });

  final List<DeliverableRow> deliverables;
  final List<RecurringDeliverableRow> recurringDeliverables;
  final List<StatusReportRow> statusReports;
  final ValueChanged<List<DeliverableRow>> onDeliverablesChanged;
  final ValueChanged<List<RecurringDeliverableRow>> onRecurringChanged;
  final ValueChanged<List<StatusReportRow>> onStatusReportsChanged;

  double get _completionPercentage {
    if (deliverables.isEmpty) return 0.0;
    final int completed =
        deliverables.where((item) => item.status == 'Completed').length;
    return (completed / deliverables.length) * 100;
  }

  int get _atRiskCount {
    return deliverables.where((item) => item.isAtRisk || item.isOverdue).length;
  }

  int get _totalBlockers {
    return deliverables.where((item) => item.blockers.trim().isNotEmpty).length;
  }

  int get _reportDraftCount {
    return statusReports.where((report) => report.status == 'Draft').length;
  }

  @override
  Widget build(BuildContext context) {
    final Color completionColor = _completionPercentage >= 80
        ? const Color(0xFF10B981)
        : _completionPercentage >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExecutionPanelShell(
          title: 'Live progress pulse',
          subtitle:
              'Delivery progress, execution blockers, and reporting load for the current execution window.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Completion health',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_completionPercentage.toStringAsFixed(0)}% complete',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: completionColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _completionPercentage / 100,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(completionColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ExecutionMetricsGrid(
          metrics: [
            ExecutionMetricData(
              label: 'Deliverables complete',
              value: '${_completionPercentage.toStringAsFixed(0)}%',
              helper:
                  '${deliverables.where((item) => item.status == 'Completed').length} of ${deliverables.length} deliverables closed',
              icon: Icons.check_circle_outline,
              emphasisColor: completionColor,
            ),
            ExecutionMetricData(
              label: 'Items at risk',
              value: '$_atRiskCount',
              helper: 'Deliverables flagged as at risk or overdue',
              icon: Icons.warning_amber_outlined,
              emphasisColor: const Color(0xFFEF4444),
            ),
            ExecutionMetricData(
              label: 'Current blockers',
              value: '$_totalBlockers',
              helper: 'Deliverables carrying blocker details right now',
              icon: Icons.block_outlined,
              emphasisColor: const Color(0xFFF59E0B),
            ),
            ExecutionMetricData(
              label: 'Report drafts',
              value: '$_reportDraftCount',
              helper:
                  '${statusReports.length} total reports with ${recurringDeliverables.length} recurring deliverables in flight',
              icon: Icons.description_outlined,
              emphasisColor: const Color(0xFF2563EB),
            ),
          ],
        ),
      ],
    );
  }
}
