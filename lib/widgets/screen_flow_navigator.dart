import 'package:flutter/material.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

/// Screen flow navigator — an always-visible strip that shows every screen of
/// a section's flow, in the same order as the sidebar selector, and makes it
/// obvious where the user is and which screens come next.
///
/// Screens like Scrum Configuration and Capacity Planning have no sidebar
/// entry of their own; they were only reachable through the bottom Back/Next
/// buttons, which reveal a single step at a time. This navigator mirrors the
/// selector's screens overall so the whole route is visible at the top of the
/// page — completed steps checked, the current step filled, and the upcoming
/// step badged "NEXT".
///
/// Tapping a step jumps straight to that screen (pending auto-save is flushed
/// first). Tapping the current step is a no-op.
class ScreenFlowNavigator extends StatelessWidget {
  const ScreenFlowNavigator({
    super.key,
    required this.steps,
    required this.currentCheckpoint,
    this.title = 'Screen Navigator',
    this.accentColor = const Color(0xFFD97706),
    this.onStepTap,
  });

  /// The ordered screens of the flow (sidebar-selector order).
  final List<SidebarItem> steps;

  /// Checkpoint of the screen the user is on right now.
  final String currentCheckpoint;

  /// Card title.
  final String title;

  /// Accent used for the current step and the "next" badges.
  final Color accentColor;

  /// Optional tap override (defaults to planning-flow navigation).
  final void Function(SidebarItem step)? onStepTap;

  static const Color _kBorder = Color(0xFFE4E7EC);
  static const Color _kMuted = Color(0xFF6B7280);
  static const Color _kHeadline = Color(0xFF111827);
  static const Color _kDone = Color(0xFF16A34A);
  static const Color _kDoneText = Color(0xFF15803D);
  static const Color _kDoneBg = Color(0xFFF0FDF4);
  static const Color _kDoneBorder = Color(0xFF86EFAC);
  static const Color _kIdleBg = Color(0xFFF8FAFC);
  static const Color _kIdleText = Color(0xFF374151);

  void _handleTap(BuildContext context, SidebarItem step) {
    if (step.checkpoint == currentCheckpoint) return;
    final override = onStepTap;
    if (override != null) {
      override(step);
      return;
    }
    PlanningPhaseNavigation.goToCheckpoint(context, step.checkpoint);
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final currentIndex =
        steps.indexWhere((s) => s.checkpoint == currentCheckpoint);
    final SidebarItem? nextStep = (currentIndex != -1 &&
            currentIndex < steps.length - 1)
        ? steps[currentIndex + 1]
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(currentIndex, nextStep),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < steps.length; i++)
                _buildStepChip(context, i, currentIndex),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Select any screen to jump straight to it.',
            style: TextStyle(fontSize: 11, color: _kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int currentIndex, SidebarItem? nextStep) {
    final String subtitle = currentIndex == -1
        ? '${steps.length} screens in this section'
        : 'Step ${currentIndex + 1} of ${steps.length}'
            ' · You are here: ${steps[currentIndex].label}';

    final Widget titleBlock = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.route_outlined, size: 20, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kHeadline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: _kMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final Widget? upNextPill = nextStep == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_forward_rounded,
                    size: 13, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'Up next: ${nextStep.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kHeadline,
                  ),
                ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (upNextPill != null) ...[
                const SizedBox(height: 10),
                upNextPill,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            if (upNextPill != null) ...[
              const SizedBox(width: 12),
              upNextPill,
            ],
          ],
        );
      },
    );
  }

  Widget _buildStepChip(BuildContext context, int index, int currentIndex) {
    final step = steps[index];
    final bool isCurrent = index == currentIndex;
    final bool isDone = currentIndex != -1 && index < currentIndex;
    final bool isNext = index == currentIndex + 1;

    final Color bg;
    final Color border;
    final Color textColor;
    if (isCurrent) {
      bg = accentColor;
      border = accentColor;
      textColor = Colors.white;
    } else if (isDone) {
      bg = _kDoneBg;
      border = _kDoneBorder;
      textColor = _kDoneText;
    } else if (isNext) {
      bg = Colors.white;
      border = accentColor.withValues(alpha: 0.55);
      textColor = _kHeadline;
    } else {
      bg = _kIdleBg;
      border = _kBorder;
      textColor = _kIdleText;
    }

    final String statusLabel = isCurrent
        ? 'You are here'
        : isNext
            ? 'Up next'
            : isDone
                ? 'Completed'
                : 'Upcoming';

    return Tooltip(
      message: '${step.label} — $statusLabel',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrent ? null : () => _handleTap(context, step),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250, minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: border,
                width: isCurrent || isNext ? 1.4 : 1,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? Colors.white.withValues(alpha: 0.25)
                        : isDone
                            ? _kDone
                            : isNext
                                ? accentColor.withValues(alpha: 0.12)
                                : const Color(0xFFE5E7EB),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? Colors.white
                                  : isNext
                                      ? accentColor
                                      : _kMuted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCurrent || isNext ? FontWeight.w700 : FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
