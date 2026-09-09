import 'package:flutter/material.dart';

/// Warning item model for design planning specifications
class DesignPlanningWarning {
  final String id;
  final String message;
  final WarningSeverity severity;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<String> affectedItemIds;

  const DesignPlanningWarning({
    required this.id,
    required this.message,
    this.severity = WarningSeverity.warning,
    this.actionLabel,
    this.onAction,
    this.affectedItemIds = const [],
  });
}

/// Severity levels for warnings
enum WarningSeverity { info, warning, error, success }

/// Enhanced warning banner widget for design planning
/// Displays categorized warnings with color-coded severity indicators
class DesignPlanningWarningsWidget extends StatelessWidget {
  final List<DesignPlanningWarning> warnings;
  final VoidCallback? onDismissAll;

  const DesignPlanningWarningsWidget({
    super.key,
    required this.warnings,
    this.onDismissAll,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: warnings
          .map((warning) => _buildWarningCard(context, warning))
          .toList(),
    );
  }

  Widget _buildWarningCard(BuildContext context, DesignPlanningWarning warning) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (warning.severity) {
      case WarningSeverity.error:
        bgColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
      case WarningSeverity.warning:
        bgColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case WarningSeverity.info:
        bgColor = const Color(0xFFFFF8E1);
        iconColor = const Color(0xFFB8860B);
        icon = Icons.info_outline;
        break;
      case WarningSeverity.success:
        bgColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                warning.message,
                style: TextStyle(color: iconColor, fontSize: 13),
              ),
            ),
            if (warning.actionLabel != null && warning.onAction != null) ...[
              TextButton(
                onPressed: warning.onAction,
                child: Text(warning.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Coverage summary card widget for design planning specifications
/// Shows mapping coverage statistics with visual indicators
class CoverageSummaryCard extends StatelessWidget {
  final int totalSpecs;
  final int mappedToRequirements;
  final int mappedToPackages;
  final int totalRequirements;
  final int totalPackages;
  final VoidCallback? onViewDetails;

  const CoverageSummaryCard({
    super.key,
    required this.totalSpecs,
    required this.mappedToRequirements,
    required this.mappedToPackages,
    required this.totalRequirements,
    required this.totalPackages,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final reqCoverage = totalRequirements > 0
        ? (mappedToRequirements / totalRequirements * 100).round()
        : 0;
    final pkgCoverage =
        totalPackages > 0 ? (mappedToPackages / totalPackages * 100).round() : 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF4154F1)),
                const SizedBox(width: 8),
                Text(
                  'Mapping Coverage Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats grid
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                  title: 'Total Specs',
                  value: '$totalSpecs',
                  icon: Icons.description_outlined,
                  color: const Color(0xFFB8860B),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  title: 'Req. Coverage',
                  value: '$reqCoverage%',
                  icon: Icons.link,
                  color: reqCoverage >= 80
                      ? Colors.green
                      : (reqCoverage >= 50 ? Colors.orange : Colors.red),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                  title: 'Scope Coverage',
                  value: '$pkgCoverage%',
                  icon: Icons.folder_outlined,
                  color: pkgCoverage >= 80
                      ? Colors.green
                      : (pkgCoverage >= 50 ? Colors.orange : Colors.red),
                )),
              ],
            ),

            if (onViewDetails != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View Detailed Report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal stat card widget for coverage metrics
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
