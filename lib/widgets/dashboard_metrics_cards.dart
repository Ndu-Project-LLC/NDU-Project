import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';

/// Reusable card showing activities assigned to the current user, filtered
/// by their role + discipline. Each row is tappable to open the unified
/// activity log (which remains constant across the full project site).
///
/// Shown on: project dashboard, program dashboard, portfolio dashboard.
class AssignedActivitiesCard extends StatelessWidget {
  const AssignedActivitiesCard({
    super.key,
    required this.activities,
    this.title = 'Assigned to me',
    this.maxRows = 5,
  });

  final List<AssignedActivity> activities;
  final String title;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind_outlined,
                  color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${activities.length}',
                    style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            _emptyState()
          else
            ...activities.take(maxRows).map((a) => _activityRow(a)),
          if (activities.length > maxRows) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => ProjectActivitiesLogScreen.open(context),
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: Text(
                    'View all ${activities.length} in activity log'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF10B981), size: 32),
            SizedBox(height: 8),
            Text('No activities assigned to you',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(AssignedActivity a) {
    final pastDue = a.isPastDue;
    return InkWell(
      onTap: () {}, // Activity log is opened via the "View all" button above
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pastDue
                    ? Colors.red.shade600
                    : _statusColor(a.status),
              ),
            ),
            const SizedBox(width: 10),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    children: [
                      _metaChip(a.projectName, Icons.folder_outlined),
                      if (a.discipline.isNotEmpty)
                        _metaChip(a.discipline, Icons.engineering_outlined),
                      if (a.role.isNotEmpty)
                        _metaChip(a.role, Icons.badge_outlined),
                    ],
                  ),
                ],
              ),
            ),
            // Due date / past-due badge
            pastDue
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '${a.daysPastDue}d overdue',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                : a.dueDate.isNotEmpty
                    ? Text(_formatDate(a.dueDate),
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11.5))
                    : const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'implemented':
      case 'completed':
        return const Color(0xFF10B981);
      case 'acknowledged':
        return const Color(0xFFFBBF24);
      case 'rejected':
        return Colors.grey;
      case 'deferred':
        return Colors.orange;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Card showing past-due activities across the account, sorted by how
/// overdue they are. Each row shows the activity, project, and days overdue.
class PastDueActivitiesCard extends StatelessWidget {
  const PastDueActivitiesCard({
    super.key,
    required this.activities,
    this.maxRows = 5,
  });

  final List<AssignedActivity> activities;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Past due activities',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${activities.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text('Nothing overdue — on track.',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...activities.take(maxRows).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${a.daysPastDue}d',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('${a.projectName} · ${a.discipline}',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          if (activities.length > maxRows) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => ProjectActivitiesLogScreen.open(context),
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: Text('View all ${activities.length} in activity log'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card showing the 5-dimension status rollup for a single project (or
/// program, or portfolio). Renders the schedule/cost/scope/quality/risk
/// traffic lights plus headline metrics (progress %, budget used %,
/// open risks, open issues).
///
/// This is the "sample portfolio dashboard" metric card. At program level
/// it's a step down (same shape, rolled-up from child projects). At
/// portfolio level it's rolled up from child programs.
class ProjectMetricsCard extends StatelessWidget {
  const ProjectMetricsCard({
    super.key,
    required this.rollup,
    this.level = 'Project',
    this.onTap,
  });

  final ProjectStatusRollup rollup;
  final String level; // 'Project' | 'Program' | 'Portfolio'
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _overallColor(rollup.overallStatus).withOpacity(0.4),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _overallColor(rollup.overallStatus).withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + overall status pill
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rollup.projectName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(level,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                _statusPill(rollup.overallStatus),
              ],
            ),
            const SizedBox(height: 16),
            // 5-dimension traffic lights
            Row(
              children: [
                _metricLight('Schedule', rollup.scheduleStatus),
                _metricLight('Cost', rollup.costStatus),
                _metricLight('Scope', rollup.scopeStatus),
                _metricLight('Quality', rollup.qualityStatus),
                _metricLight('Risk', rollup.riskStatus),
              ],
            ),
            const SizedBox(height: 16),
            // Headline metrics row
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                if (rollup.progressPercent != null)
                  _headlineMetric('Progress',
                      '${rollup.progressPercent!.toStringAsFixed(0)}%',
                      Icons.timeline_outlined),
                if (rollup.budgetUsedPercent != null)
                  _headlineMetric('Budget used',
                      '${rollup.budgetUsedPercent!.toStringAsFixed(0)}%',
                      Icons.savings_outlined),
                if (rollup.openRisks != null)
                  _headlineMetric('Open risks', '${rollup.openRisks}',
                      Icons.warning_amber_outlined),
                if (rollup.openIssues != null)
                  _headlineMetric('Open issues', '${rollup.openIssues}',
                      Icons.bug_report_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final c = _overallColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _metricLight(String label, String status) {
    final c = _overallColor(status);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withOpacity(0.15),
              border: Border.all(color: c, width: 2),
            ),
            child: Icon(Icons.circle, color: c, size: 10),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _headlineMetric(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12.5)),
      ],
    );
  }

  Color _overallColor(String status) {
    switch (status) {
      case 'on_track':
        return const Color(0xFF10B981);
      case 'at_risk':
        return const Color(0xFFF59E0B);
      case 'off_track':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_track':
        return 'On track';
      case 'at_risk':
        return 'At risk';
      case 'off_track':
        return 'Off track';
      default:
        return 'Unknown';
    }
  }
}
