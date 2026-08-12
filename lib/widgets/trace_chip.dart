/// Trace Chip — a small icon+label badge that surfaces a cross-section
/// foreign-key reference inline next to a row / list item.
///
/// Promoted to a public widget from the private `_traceChip` in
/// `lib/widgets/work_package_detail.dart` so it can be reused across the
/// WBS, Schedule, and Project Controls module screens.
///
/// Behaviour:
/// - Renders as a compact pill with a colored icon and short label.
/// - When [onTap] is non-null, the chip becomes clickable and shows a
///   hover affordance (cursor pointer + subtle background tint).
/// - Tap is intended to navigate to the linked section (e.g. push the
///   Schedule route with the activity highlighted).
/// - When [onTap] is null, the chip is purely informational.
///
/// Design tokens match the existing `_traceChip` so visual consistency is
/// preserved across the app.

library;

import 'package:flutter/material.dart';

class TraceChip extends StatelessWidget {
  const TraceChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  /// Icon shown to the left of the label (typically an `Icons.*` value).
  final IconData icon;

  /// Short text — usually an ID prefix + value (e.g. "WBS 1.2.3",
  /// "CA wp_wbs_42", "ACT act_1700_0001").
  final String label;

  /// Pill colour. Suggested palettes:
  /// - Indigo `Color(0xFF4F46E5)` for WBS links
  /// - Teal `Color(0xFF0D9488)` for Schedule links
  /// - Amber `Color(0xFFD97706)` for Project Controls links
  final Color color;

  /// Optional tap handler. When null, the chip is non-interactive.
  final VoidCallback? onTap;

  /// Optional tooltip shown on hover/long-press.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final core = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onTap != null ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (onTap != null) ...[
            const SizedBox(width: 3),
            Icon(Icons.open_in_new, size: 9, color: color.withValues(alpha: 0.7)),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return tooltip == null ? core : Tooltip(message: tooltip!, child: core);
    }

    final clickable = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: color.withValues(alpha: 0.08),
        child: core,
      ),
    );

    return tooltip == null
        ? clickable
        : Tooltip(message: tooltip!, child: clickable);
  }
}

/// Pre-baked colour constants for each section so callers don't reinvent
/// them. Usage:
/// ```dart
/// TraceChip(
///   icon: Icons.account_tree,
///   label: 'WBS 1.2.3',
///   color: TraceChipPalette.wbs,
///   onTap: () => context.push('/work-breakdown-structure'),
/// )
/// ```
class TraceChipPalette {
  TraceChipPalette._();

  static const Color wbs = Color(0xFF4F46E5); // indigo
  static const Color schedule = Color(0xFF0D9488); // teal
  static const Color projectControls = Color(0xFFD97706); // amber
  static const Color costEstimate = Color(0xFF7C3AED); // purple
  static const Color procurement = Color(0xFFDC2626); // red
}
