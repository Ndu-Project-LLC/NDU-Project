import 'package:flutter/material.dart';
import 'package:ndu_project/services/planning_phase_context_service.dart';

/// A visual progress indicator showing the launch phase flow with context
/// badges on each screen. Displays a vertical timeline with connected dots,
/// checkmarks for screens that have published context, and labels.
///
/// This widget is designed to be embedded in the sidebar's Launch Phase
/// section header area to give users a visual overview of their progress.
class LaunchPhaseProgressIndicator extends StatelessWidget {
  /// Optional: label of the currently active screen to highlight.
  final String? activeItemLabel;

  const LaunchPhaseProgressIndicator({
    super.key,
    this.activeItemLabel,
  });

  @override
  Widget build(BuildContext context) {
    final service = PlanningPhaseContextService.instance;
    final flowOrder = PlanningPhaseContextService.launchFlowOrder;
    final screenLabels = PlanningPhaseContextService.launchScreenLabels;

    // Compute progress: count screens that have published context
    final completedCount =
        flowOrder.where((id) => service.hasContext(id)).length;
    final totalCount = flowOrder.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar header
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? const Color(0xFF10B981)
                          : progress > 0
                              ? const Color(0xFFD97706)
                              : const Color(0xFF9CA3AF),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completedCount/$totalCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: progress >= 1.0
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vertical timeline
          ...List.generate(flowOrder.length, (index) {
            final screenId = flowOrder[index];
            final label = screenLabels[screenId] ?? screenId;
            final hasContext = service.hasContext(screenId);
            final isActive = activeItemLabel == label;
            final isLast = index == flowOrder.length - 1;

            return _TimelineItem(
              label: label,
              screenId: screenId,
              hasContext: hasContext,
              isActive: isActive,
              isLast: isLast,
              index: index,
              totalCount: totalCount,
            );
          }),
        ],
      ),
    );
  }
}

/// A single item in the vertical timeline.
class _TimelineItem extends StatelessWidget {
  final String label;
  final String screenId;
  final bool hasContext;
  final bool isActive;
  final bool isLast;
  final int index;
  final int totalCount;

  const _TimelineItem({
    required this.label,
    required this.screenId,
    required this.hasContext,
    required this.isActive,
    required this.isLast,
    required this.index,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFD97706);
    const completedColor = Color(0xFF10B981);
    const pendingColor = Color(0xFF9CA3AF);
    const lineColor = Color(0xFFD1D5DB);

    final dotColor = hasContext ? completedColor : pendingColor;
    final textColor = isActive
        ? activeColor
        : hasContext
            ? const Color(0xFF374151)
            : const Color(0xFF9CA3AF);
    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column (dot + line)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: isActive
                        ? Border.all(color: activeColor, width: 2)
                        : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: hasContext
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: hasContext ? completedColor : lineColor,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: fontWeight,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Context badge
          if (hasContext)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: completedColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: completedColor.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.link,
                  size: 10,
                  color: completedColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
