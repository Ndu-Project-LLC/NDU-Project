import 'package:flutter/material.dart';
import 'package:ndu_project/services/quality_intelligence_service.dart';

/// Quality Intelligence Insights Panel
/// 
/// Displays AI-generated quality recommendations in a visually rich card format.
/// Can be used standalone or integrated into the KAZ AI chat interface.
class QualityInsightsPanel extends StatelessWidget {
  const QualityInsightsPanel({
    super.key,
    required this.report,
    this.onRecommendationTap,
    this.maxItemsPerCategory = 3,
    this.compact = false,
  });

  final QualityIntelligenceReport report;
  final void Function(QualityRecommendation)? onRecommendationTap;
  final int maxItemsPerCategory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (report.totalFindings == 0) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        if (report.criticalItems.isNotEmpty) ...[
          _buildSection(
            context,
            title: '🚨 Critical Items',
            icon: Icons.error_outline,
            color: const Color(0xFFDC2626),
            items: report.criticalItems.take(maxItemsPerCategory).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (report.missingRequirements.isNotEmpty) ...[
          _buildSection(
            context,
            title: '⚠️ Missing Requirements',
            icon: Icons.warning_amber_outlined,
            color: const Color(0xFFF59E0B),
            items: report.missingRequirements.take(maxItemsPerCategory).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (report.qualityRisks.isNotEmpty) ...[
          _buildSection(
            context,
            title: '🎯 Quality Risks',
            icon: Icons.risk_check_outlined,
            color: const Color(0xFFEF4444),
            items: report.qualityRisks.take(maxItemsPerCategory).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (report.acceptanceCriteriaGaps.isNotEmpty) ...[
          _buildSection(
            context,
            title: '📊 Gaps Detected',
            icon: Icons.find_in_page_outlined,
            color: const Color(0xFF8B5CF6),
            items: report.acceptanceCriteriaGaps.take(maxItemsPerCategory).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (!compact) ...[
          _buildSummaryCards(context),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.green[700]),
          const SizedBox(height: 12),
          Text(
            'Quality Profile Looks Good!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No critical quality issues detected. Continue monitoring as the project progresses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.psychology_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quality Intelligence',
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                '${report.projectName} • ${report.totalFindings} findings',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildPriorityBadge(context, count: report.findingsByPriority['Critical'] ?? 0, label: 'Critical'),
        const SizedBox(width: 8),
        _buildPriorityBadge(context, count: report.findingsByPriority['High'] ?? 0, label: 'High'),
      ],
    );
  }

  Widget _buildPriorityBadge(BuildContext context, {required int count, required String label}) {
    final isCritical = label == 'Critical';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
        ),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<QualityRecommendation> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            Text(
              '${items.length} item(s)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _RecommendationCard(
          recommendation: item,
          onTap: onRecommendationTap,
          compact: compact,
        )),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childHeight: 90,
      children: [
        _SummaryCard(
          title: 'Activities to Add',
          value: report.recommendedActivities.length.toString(),
          icon: Icons.add_task_outlined,
          color: const Color(0xFF3B82F6),
        ),
        _SummaryCard(
          title: 'Standards to Review',
          value: report.recommendedStandards.length.toString(),
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF10B981),
        ),
        _SummaryCard(
          title: 'KPIs Recommended',
          value: report.recommendedKpis.length.toString(),
          icon: Icons.speed_outlined,
          color: const Color(0xFFF59E0B),
        ),
        _SummaryCard(
          title: 'Rework Sources',
          value: report.reworkSources.length.toString(),
          icon: Icons.autorenew_outlined,
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    this.onTap,
    this.compact = false,
  });

  final QualityRecommendation recommendation;
  final VoidCallback? onTap;
  final bool compact;

  Color get _priorityColor {
    switch (recommendation.priority) {
      case Priority.critical:
        return const Color(0xFFFEE2E2);
      case Priority.high:
        return const Color(0xFFFEF3C7);
      case Priority.medium:
        return const Color(0xFFE0E7FF);
      case Priority.low:
        return const Color(0xFFF0FDF4);
    }
  }

  Color get _priorityTextColor {
    switch (recommendation.priority) {
      case Priority.critical:
        return const Color(0xFFDC2626);
      case Priority.high:
        return const Color(0xFFD97706);
      case Priority.medium:
        return const Color(0xFF6366F1);
      case Priority.low:
        return const Color(0xFF059669);
    }
  }

  IconData get _typeIcon {
    switch (recommendation.type) {
      case RecommendationType.missingRequirement:
        return Icons.warning_amber_rounded;
      case RecommendationType.recommendedActivity:
        return Icons.add_circle_outline;
      case RecommendationType.recommendedStandard:
        return Icons.verified_outlined;
      case RecommendationType.acceptanceGap:
        return Icons.find_in_page_outlined;
      case RecommendationType.qualityRisk:
        return Icons.error_outline;
      case RecommendationType.recommendedKpi:
        return Icons.speed_outlined;
      case RecommendationType.reworkSource:
        return Icons.autorenew_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () => onTap!(recommendation) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _priorityColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _priorityColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon, size: 16, color: _priorityTextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      recommendation.title,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PriorityChip(priority: recommendation.priority),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  recommendation.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '💡 ${recommendation.suggestedAction}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, textColor) = switch (priority) {
      Priority.critical => ('CRITICAL', Color(0xFEF2F2), Color(0xFFDC2626)),
      Priority.high => ('HIGH', Color(0xFFFFFBEB), Color(0xFFD97706)),
      Priority.medium => ('MEDIUM', Color(0xFFEFF6FF), Color(0xFF3B82F6)),
      Priority.low => ('LOW', Color(0xFFF0FDF4), Color(0xFF059669)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen dialog for viewing detailed quality intelligence
class QualityIntelligenceDialog extends StatelessWidget {
  const QualityIntelligenceDialog({super.key, required this.report});

  final QualityIntelligenceReport report;

  static Future<void> show(BuildContext context, QualityIntelligenceReport report) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 700,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogTitleBar(report: report),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: QualityInsightsPanel(report: report),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({super.key, required this.report});

  final QualityIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[50]!, Colors.purple[50]!],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quality Intelligence Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  '${report.projectName} • Generated ${_formatTimeAgo(report.generatedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
