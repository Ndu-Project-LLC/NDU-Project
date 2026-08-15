/// Shared building blocks for Project Controls tabs.
///
/// Provides a world-class, top-1% polish scaffold that gives every
/// Project Controls tab a consistent identity: gradient page background,
/// fade-in intro, hero band with eyebrow chip + title + subtitle + CTA,
/// KPI strip with accent rails, and section cards with hover micro-
/// interactions.
///
/// The Baseline Management tab is the visual reference for this system.
library;

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE — tightly coordinated, top 1% polish.
// ─────────────────────────────────────────────────────────────────────────────

/// Shared color palette used by every Project Controls tab.
///
/// Exposed as a class (rather than top-level constants) so consumers can
/// reference `PcPalette.gold`, `PcPalette.indigo`, etc., making the visual
/// system explicit and discoverable.
class PcPalette {
  const PcPalette._();

  // Ink ramp
  static const Color inkPrimary = Color(0xFF0B1220);
  static const Color inkSecondary = Color(0xFF475467);
  static const Color inkMuted = Color(0xFF98A2B3);

  // Surfaces
  static const Color surface = Colors.white;
  // Per Task 18: entire Project Controls page should have a white background.
  // surfaceSubtle was previously a light gray (#F9FAFB) which created visible
  // gray panels across the dashboard, summary cards, and content sections.
  // Aliased to white so all surfaces render uniformly white.
  static const Color surfaceSubtle = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE4E7EC);
  static const Color borderSubtle = Color(0xFFEFF1F4);

  // Brand / accent ramp
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDeep = Color(0xFFF59E0B);
  static const Color goldSoft = Color(0xFFFFF4CC);

  // Semantic accents
  static const Color indigo = Color(0xFFB8860B);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color violet = Color(0xFFB8860B);
  static const Color sky = Color(0xFFFFC812);
  static const Color rose = Color(0xFFD97706);
  static const Color teal = Color(0xFFD97706);
  static const Color fuchsia = Color(0xFFD97706);

  // Status
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSurface = Color(0xFFFFF1F1);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
}

// ─────────────────────────────────────────────────────────────────────────────
// HOVER BUILDER — mouse-driven micro-interactions.
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks mouse enter/exit and rebuilds [builder] with the current
/// hovered state.
///
/// Use this for subtle tactile feedback on cards, chips, and CTAs.
class PcHoverBuilder extends StatefulWidget {
  const PcHoverBuilder({super.key, required this.builder});
  final Widget Function(bool hovered) builder;

  @override
  State<PcHoverBuilder> createState() => _PcHoverBuilderState();
}

class _PcHoverBuilderState extends State<PcHoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD — page background + intro animation wrapper.
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps tab content in:
///   1. A clean white page background.
///   2. A center-constrained column (maxWidth: 1280).
///   3. A 700ms fade + slide intro animation.
///
/// Pass `intro` (an AnimationController) if you want the scaffold to drive
/// the animation, or omit it to use a built-in controller.
class PcPageScaffold extends StatefulWidget {
  const PcPageScaffold({
    super.key,
    required this.children,
    this.maxWidth = 1280,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 48),
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  State<PcPageScaffold> createState() => _PcPageScaffoldState();
}

class _PcPageScaffoldState extends State<PcPageScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: widget.padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: FadeTransition(
              opacity: _intro,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(_intro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BAND — eyebrow chip + title + subtitle + CTA, ambient gradient.
// ─────────────────────────────────────────────────────────────────────────────

/// Configuration for the hero band's primary CTA.
class PcHeroAction {
  const PcHeroAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Hero band with:
///   - 64×64 gradient badge with icon
///   - eyebrow chip (uppercase, gold accent)
///   - title (26px, w800)
///   - subtitle (13.5px, w500)
///   - optional primary CTA (gradient button)
///
/// Stacks to a single column when width < 720.
class PcHeroBand extends StatelessWidget {
  const PcHeroBand({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = PcPalette.gold,
    this.accentDeep = PcPalette.goldDeep,
    this.accentSoft = PcPalette.goldSoft,
    this.tint = const Color(0xFFFCF8E8),
    this.borderColor = const Color(0xFFF1E8C5),
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color tint;
  final Color borderColor;
  final PcHeroAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, tint],
        ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: PcPalette.inkPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent ribbon
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0),
                    accent,
                    accentDeep,
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 720;
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBadge(),
                          const SizedBox(height: 18),
                          _buildCopy(),
                          if (action != null) ...[
                            const SizedBox(height: 20),
                            _buildAction(),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          _buildBadge(),
                          const SizedBox(width: 22),
                          Expanded(child: _buildCopy()),
                          if (action != null) ...[
                            const SizedBox(width: 22),
                            _buildAction(),
                          ],
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accentSoft,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              color: accentDeep,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFamily: appFontFamily,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: PcPalette.inkPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.15,
            fontFamily: appFontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: PcPalette.inkSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
            fontFamily: appFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildAction() {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedScale(
          scale: hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: action!.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accentDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: hovered ? 0.5 : 0.3),
                      blurRadius: hovered ? 16 : 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        action!.icon,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      action!.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI STRIP — responsive grid of tactile metric cards with accent rails.
// ─────────────────────────────────────────────────────────────────────────────

/// Configuration for a single KPI card.
class PcKpiSpec {
  const PcKpiSpec({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.accent,
    this.live = true,
    this.trend,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color accent;
  final bool live;
  final PcKpiTrend? trend;
}

/// Optional trend chip ("+5.2%" / "-1.8%") rendered inside the KPI card.
class PcKpiTrend {
  const PcKpiTrend({
    required this.delta,
    required this.positive,
  });

  final String delta;
  final bool positive;
}

/// Renders a responsive `Wrap` of KPI cards built from [kpis].
///
/// 4 columns when width > 1100, 2 columns when > 720, else 1 column.
class PcKpiStrip extends StatelessWidget {
  const PcKpiStrip({
    super.key,
    required this.kpis,
    this.spacing = 14.0,
  });

  final List<PcKpiSpec> kpis;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100
            ? 4
            : c.maxWidth > 720
                ? 2
                : 1;
        final cardW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: kpis
              .map((k) => _PcKpiCard(spec: k, cardWidth: cardW))
              .toList(growable: false),
        );
      },
    );
  }
}

class _PcKpiCard extends StatelessWidget {
  const _PcKpiCard({required this.spec, required this.cardWidth});

  final PcKpiSpec spec;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: cardWidth,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovered
                  ? spec.accent.withValues(alpha: 0.4)
                  : PcPalette.border,
            ),
            boxShadow: [
              BoxShadow(
                color: PcPalette.inkPrimary
                    .withValues(alpha: hovered ? 0.08 : 0.04),
                blurRadius: hovered ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Accent left rail
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: spec.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                spec.accent.withValues(alpha: 0.95),
                                spec.accent.withValues(alpha: 0.65),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: spec.accent.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child:
                              Icon(spec.icon, color: Colors.white, size: 20),
                        ),
                        const Spacer(),
                        if (spec.live)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: spec.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      spec.label.toUpperCase(),
                      style: TextStyle(
                        color: PcPalette.inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            spec.value,
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                        if (spec.trend != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (spec.trend!.positive
                                      ? PcPalette.emerald
                                      : PcPalette.danger)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  spec.trend!.positive
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 10,
                                  color: spec.trend!.positive
                                      ? PcPalette.emerald
                                      : PcPalette.danger,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  spec.trend!.delta,
                                  style: TextStyle(
                                    color: spec.trend!.positive
                                        ? PcPalette.emerald
                                        : PcPalette.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: appFontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.sub,
                      style: TextStyle(
                        color: PcPalette.inkSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD — titled card container for content blocks.
// ─────────────────────────────────────────────────────────────────────────────

/// A titled card with an accent rail, used to group content sections.
///
/// Pattern: leading icon chip + uppercase title + optional subtitle +
/// optional trailing widget, then [child] below.
class PcSectionCard extends StatelessWidget {
  const PcSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.accent = PcPalette.indigo,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PcPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PcPalette.border),
        boxShadow: [
          BoxShadow(
            color: PcPalette.inkPrimary.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with accent rail
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: PcPalette.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  // Accent rail
                  Container(width: 3, height: 44, color: accent),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: accent.withValues(alpha: 0.1),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: PcPalette.inkPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  const SizedBox(width: 14),
                ],
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS PILL — colored status badge.
// ─────────────────────────────────────────────────────────────────────────────

/// A compact status pill with optional leading dot.
class PcStatusPill extends StatelessWidget {
  const PcStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.dotted = true,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool dotted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotted) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE — friendly placeholder for empty sections.
// ─────────────────────────────────────────────────────────────────────────────

/// A friendly empty-state placeholder with icon, title, and subtitle.
class PcEmptyState extends StatelessWidget {
  const PcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = PcPalette.indigo,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.1),
              border: Border.all(
                color: accent.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: PcPalette.inkPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PcPalette.inkSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION SPACER — consistent vertical gap between content blocks.
// ─────────────────────────────────────────────────────────────────────────────

/// Consistent vertical spacer between content sections (28px default).
const Widget pcSectionSpacer = SizedBox(height: 28);

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSITE TAB SHELL — convenience wrapper for the most common pattern.
// ─────────────────────────────────────────────────────────────────────────────

/// Composite wrapper that ties together [PcPageScaffold], [PcHeroBand],
/// [PcKpiStrip], and a list of content sections.
///
/// Most Project Controls tabs can use this shell and pass their own
/// content `sections` (typically [PcSectionCard]s or custom widgets).
class PcTabShell extends StatelessWidget {
  const PcTabShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
    this.kpis = const [],
    this.action,
    this.accent = PcPalette.gold,
    this.accentDeep = PcPalette.goldDeep,
    this.accentSoft = PcPalette.goldSoft,
    this.tint = const Color(0xFFFCF8E8),
    this.borderColor = const Color(0xFFF1E8C5),
    this.heroSpacing = 22,
    this.kpiSpacing = 28,
    this.showHero = true,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> sections;
  final List<PcKpiSpec> kpis;
  final PcHeroAction? action;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color tint;
  final Color borderColor;
  final double heroSpacing;
  final double kpiSpacing;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return PcPageScaffold(
      children: [
        if (showHero)
          PcHeroBand(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            icon: icon,
            accent: accent,
            accentDeep: accentDeep,
            accentSoft: accentSoft,
            tint: tint,
            borderColor: borderColor,
            action: action,
          ),
        if (kpis.isNotEmpty) ...[
          if (showHero) SizedBox(height: heroSpacing),
          PcKpiStrip(kpis: kpis),
        ],
        for (final s in sections) ...[
          SizedBox(height: kpiSpacing),
          s,
        ],
      ],
    );
  }
}
