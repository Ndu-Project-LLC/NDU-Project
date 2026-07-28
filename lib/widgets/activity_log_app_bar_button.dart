import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';

/// A reusable activity-log button that can be dropped into any AppBar's
/// `actions` list. Opens the full [ProjectActivitiesLogScreen] when tapped.
///
/// Visual style matches the existing `_ActivityLogAction` in
/// `unified_phase_header.dart`: gold-tinted pill with the fact-check icon,
/// so the button looks identical whether it's rendered inside
/// [UnifiedPhaseHeader] or inside a custom AppBar.
///
/// Use it like:
/// ```dart
/// AppBar(
///   title: const Text('My Screen'),
///   actions: const [
///     ActivityLogAppBarButton(),
///   ],
/// )
/// ```
class ActivityLogAppBarButton extends StatelessWidget {
  const ActivityLogAppBarButton({
    super.key,
    this.compact = false,
    this.iconColor = const Color(0xFFB45309),
    this.onTap,
  });

  /// When true, renders a tighter icon-only pill (no label). Used on
  /// mobile viewports or crowded AppBars.
  final bool compact;

  /// Color of the icon. Defaults to the brand amber.
  final Color iconColor;

  /// Optional override for the tap handler. Defaults to opening
  /// [ProjectActivitiesLogScreen].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Project Activity Log',
      child: InkWell(
        onTap: onTap ?? () => ProjectActivitiesLogScreen.open(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD873)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: iconColor,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
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
