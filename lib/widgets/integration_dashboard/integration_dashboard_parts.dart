import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';

/// Shared building blocks for the Integration Dashboard.
///
/// The dashboard has a lot of small repeated shapes — cards, section
/// headings, KPI tiles, status pills, meters, chips. Pulling them into one
/// place is what keeps the two halves of the screen (workspace launchpad and
/// baseline review) looking like one product rather than two screens that
/// happen to live in the same file.

/// The standard raised container used for every section of the dashboard.
class IntegrationCard extends StatelessWidget {
  const IntegrationCard({
    super.key,
    required this.tokens,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.color,
    this.borderColor,
    this.gradient,
  });

  final IntegrationTokens tokens;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient != null ? null : (color ?? tokens.surface),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? tokens.outline),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A section heading: icon tile + title + optional trailing widget.
class IntegrationSectionTitle extends StatelessWidget {
  const IntegrationSectionTitle({
    super.key,
    required this.tokens,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
  });

  final IntegrationTokens tokens;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? tokens.brandDeep;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: tokens.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: tokens.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

/// A large hero KPI tile (On Track / At Risk / Avg. Progress).
class IntegrationStatTile extends StatelessWidget {
  const IntegrationStatTile({
    super.key,
    required this.tokens,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.accent,
  });

  final IntegrationTokens tokens;
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value, $sublabel',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.outline),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(fontSize: 11, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact KPI inside a bento section.
class IntegrationMiniKpi extends StatelessWidget {
  const IntegrationMiniKpi({
    super.key,
    required this.tokens,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.hint,
  });

  final IntegrationTokens tokens;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hint == null ? '$label: $value' : '$label: $value. $hint',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.outlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: tokens.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled progress meter with a value read-out.
class IntegrationMeter extends StatelessWidget {
  const IntegrationMeter({
    super.key,
    required this.tokens,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final IntegrationTokens tokens;

  /// 0–1.
  final double value;
  final String label;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 9,
            backgroundColor: tokens.surfaceSunken,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${pct.toStringAsFixed(0)}% · $detail',
          style: TextStyle(fontSize: 11, color: tokens.muted),
        ),
      ],
    );
  }
}

/// Small status pill with a leading dot.
class IntegrationPill extends StatelessWidget {
  const IntegrationPill({
    super.key,
    required this.tokens,
    required this.label,
    required this.accent,
    this.dot = true,
    this.dense = false,
  });

  final IntegrationTokens tokens;
  final String label;
  final Color accent;
  final bool dot;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10 : 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// A neutral metadata chip (tags, codes, counts).
class IntegrationChip extends StatelessWidget {
  const IntegrationChip({
    super.key,
    required this.tokens,
    required this.label,
    this.icon,
    this.accent,
  });

  final IntegrationTokens tokens;
  final String label;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? tokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tokens.outlineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bulleted list of outstanding gaps, capped so a long backlog never
/// swamps the dashboard.
class IntegrationGapList extends StatelessWidget {
  const IntegrationGapList({
    super.key,
    required this.tokens,
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.cap = 6,
  });

  final IntegrationTokens tokens;
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;
  final int cap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(cap).toList(growable: false);
    final overflow = items.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$title (${items.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ...shown.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.circle, size: 5, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: tokens.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 13),
            child: Text(
              '+ $overflow more not shown',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: tokens.mutedSoft,
              ),
            ),
          ),
      ],
    );
  }
}

/// A centred loading / empty / error state with consistent framing.
class IntegrationStatePanel extends StatelessWidget {
  const IntegrationStatePanel({
    super.key,
    required this.tokens,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.isBusy = false,
    this.action,
  });

  final IntegrationTokens tokens;
  final IconData icon;
  final String title;
  final String message;
  final Color? accent;
  final bool isBusy;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? tokens.brandDeep;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.outline),
      ),
      child: Column(
        children: [
          if (isBusy)
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: tone),
            )
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: tone),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: tokens.muted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Lays [children] out in a responsive grid of [minTileWidth]-wide cells.
///
/// Used everywhere a KPI row needs to collapse gracefully instead of
/// relying on a fixed `GridView` aspect ratio (which overflows as soon as a
/// label wraps).
class IntegrationTileGrid extends StatelessWidget {
  const IntegrationTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 200,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final cols = (maxWidth / minTileWidth).floor().clamp(1, 6);
        final tileWidth = (maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}