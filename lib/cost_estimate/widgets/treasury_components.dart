library;

/// Treasury Components — shared world-class UI library for the Cost Estimate
/// module.
///
/// Design language:
///   "The Treasury" — a premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient. Generous
///   whitespace, tabular figures everywhere, hairline borders, layered soft
///   shadows, and a bento-style composition that scales gracefully from
///   compact laptop to ultrawide. Every section earns its real estate —
///   empty states are first-class, never silent zeros.
///
/// Exposes:
///   - `TreasuryTokens` — design tokens (colors, surfaces, hairlines)
///   - `treasuryFmt()` — number formatter (K / M suffix)
///   - `TreasuryHeroBand` — gradient hero header with eyebrow / title /
///     subtitle / status / context chips / actions
///   - `TreasuryHeroChip`, `TreasuryHeroAction`
///   - `TreasuryHeroGridPainter` — decorative grid for the hero band
///   - `TreasuryKpiSpec`, `TreasuryKpiTile` — premium KPI cards
///   - `TreasurySectionCard` — chrome for content sections
///   - `TreasuryEmptyState` — empty state with CTA
///   - `TreasuryTableHeader` — tabular column header
///   - `TreasurySpotlightBar`, `TreasurySpotlightColumn` — totals spotlight
///
/// Used by:
///   - Cost Dashboard tab (original Treasury implementation)
///   - Builder tab
///   - BOE tab
///   - Review tab
///   - Baseline tab
///   - Variance tab

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryTokens {
  const TreasuryTokens._();

  // Text
  static const ink = Color(0xFF0B1220);
  static const inkSoft = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const mutedSoft = Color(0xFF94A3B8);

  // Hairlines / surfaces
  static const hairline = Color(0xFFE2E8F0);
  static const hairlineSoft = Color(0xFFEEF1F6);
  static const canvas = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF8FAFC);

  // Brand
  static const brand = Color(0xFFFFC812);
  static const brandDeep = Color(0xFFD97706);
  static const brandSoft = Color(0xFFFFF7E0);

  // Semantic accents (consistent with Cost Dashboard palette)
  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFE7F8F0);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFF3E0);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF6366F1);
  static const infoSoft = Color(0xFFEEF0FF);
}

/// Treasury number formatter — K / M suffix for compact tabular figures.
String treasuryFmt(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO COMMAND BAND
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryHeroBand extends StatelessWidget {
  const TreasuryHeroBand({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusLive,
    required this.contextChips,
    required this.actions,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool statusLive;
  final List<TreasuryHeroChip> contextChips;
  final List<TreasuryHeroAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC812), Color(0xFFFABD00), Color(0xFFD97706)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative grid
          Positioned.fill(
            child: CustomPaint(painter: TreasuryHeroGridPainter()),
          ),
          // Soft glow orb
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.38),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: eyebrow + status chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D1F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1A1D1F)
                              .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dashboard_rounded,
                              size: 13,
                              color: const Color(0xFF1A1D1F)
                                  .withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Color(0xFF1A1D1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusLive
                            ? const Color(0xFF059669).withValues(alpha: 0.16)
                            : const Color(0xFF1A1D1F)
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusLive
                              ? const Color(0xFF059669)
                                  .withValues(alpha: 0.55)
                              : const Color(0xFF1A1D1F)
                                  .withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusLive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF1A1D1F)
                                      .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              boxShadow: statusLive
                                  ? const [
                                      BoxShadow(
                                        color: Color(0xFF059669),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: statusLive
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1A1D1F)
                                      .withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.05,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1A1D1F).withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                // Context chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: contextChips,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TreasuryHeroChip extends StatelessWidget {
  const TreasuryHeroChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: const Color(0xFF1A1D1F).withValues(alpha: 0.78)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color:
                      const Color(0xFF1A1D1F).withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D1F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TreasuryHeroAction extends StatelessWidget {
  const TreasuryHeroAction({
    super.key,
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return Material(
        color: const Color(0xFF1A1D1F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1D1F)
                      .withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFFFFC812)),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: const Color(0xFF1A1D1F)),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D1F))),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        side: BorderSide(
            color: const Color(0xFF1A1D1F).withValues(alpha: 0.32)),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class TreasuryHeroGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.7;
    const spacing = 32.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM KPI TILE
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryKpiSpec {
  const TreasuryKpiSpec({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.tintSoft,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color tintSoft;
}

class TreasuryKpiTile extends StatelessWidget {
  const TreasuryKpiTile({super.key, required this.spec});
  final TreasuryKpiSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: spec.tint.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile + label
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: spec.tintSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: spec.tint.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(spec.icon, size: 17, color: spec.tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: TreasuryTokens.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Big value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: TreasuryTokens.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.sub,
            style: TextStyle(
              fontSize: 11.5,
              color: TreasuryTokens.mutedSoft,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Treasury KPI strip — responsive grid of KPI tiles.
class TreasuryKpiStrip extends StatelessWidget {
  const TreasuryKpiStrip({
    super.key,
    required this.kpis,
    this.breakpoint = 1100,
    this.gap = 14,
  });
  final List<TreasuryKpiSpec> kpis;
  final double breakpoint;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        final cols = wide ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
        final rows = (kpis.length / cols).ceil();
        final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              Padding(
                padding:
                    EdgeInsets.only(bottom: r < rows - 1 ? gap : 0),
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++)
                      if (r * cols + c < kpis.length)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: c < cols - 1 ? gap : 0),
                            child: SizedBox(
                              width: tileW,
                              child: TreasuryKpiTile(
                                  spec: kpis[r * cols + c]),
                            ),
                          ),
                        )
                      else
                        Expanded(child: const SizedBox()),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION CARD — chrome for content sections
// ═══════════════════════════════════════════════════════════════════════════

class TreasurySectionCard extends StatelessWidget {
  const TreasurySectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: TreasuryTokens.ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: TreasuryTokens.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryEmptyState extends StatelessWidget {
  const TreasuryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: TreasuryTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TreasuryTokens.hairline,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: TreasuryTokens.brand.withValues(alpha: 0.32),
              ),
            ),
            child:
                Icon(icon, size: 28, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TreasuryTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: TreasuryTokens.muted,
              height: 1.55,
            ),
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 16),
            Material(
              color: TreasuryTokens.brand,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onCta,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: TreasuryTokens.brand
                            .withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 15, color: TreasuryTokens.ink),
                      const SizedBox(width: 7),
                      Text(
                        ctaLabel!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: TreasuryTokens.ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLE HEADER
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryTableHeader extends StatelessWidget {
  const TreasuryTableHeader(this.label, {super.key, this.alignRight = false});
  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: TreasuryTokens.mutedSoft,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOTALS SPOTLIGHT BAR
// ═══════════════════════════════════════════════════════════════════════════

class TreasurySpotlightBar extends StatelessWidget {
  const TreasurySpotlightBar({
    super.key,
    required this.columns,
    this.spotlightIndex,
  });
  final List<TreasurySpotlightColumn> columns;
  final int? spotlightIndex;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();
    final spotIdx = spotlightIndex ?? columns.length - 1;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: TreasuryTokens.surface,
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: TreasuryTokens.hairline,
                ),
              Expanded(
                child: i == spotIdx
                    ? _SpotlightDarkWrapper(child: columns[i])
                    : columns[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpotlightDarkWrapper extends StatelessWidget {
  const _SpotlightDarkWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: child,
    );
  }
}

class TreasurySpotlightColumn extends StatelessWidget {
  const TreasurySpotlightColumn({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.tintSoft,
    this.dark = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color tintSoft;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final iconBg = dark
        ? TreasuryTokens.brand.withValues(alpha: 0.22)
        : tintSoft;
    final iconFg = dark ? TreasuryTokens.brand : tint;
    final labelColor =
        dark ? Colors.white70 : TreasuryTokens.muted;
    final valueColor = dark ? TreasuryTokens.brand : TreasuryTokens.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                  border: dark
                      ? null
                      : Border.all(color: tint.withValues(alpha: 0.20)),
                ),
                child: Icon(icon, size: 15, color: iconFg),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: labelColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PILLS & BADGES (used by Builder/Review/Baseline/Variance)
// ═══════════════════════════════════════════════════════════════════════════

enum TreasuryStatusTone {
  brand,
  success,
  warning,
  danger,
  info,
  neutral,
}

class TreasuryStatusPill extends StatelessWidget {
  const TreasuryStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.glow = false,
  });
  final String label;
  final TreasuryStatusTone tone;
  final IconData? icon;
  final bool glow;

  (Color, Color, Color) _colors() {
    switch (tone) {
      case TreasuryStatusTone.success:
        return (TreasuryTokens.success.withValues(alpha: 0.16),
            TreasuryTokens.success.withValues(alpha: 0.55),
            const Color(0xFF047857));
      case TreasuryStatusTone.warning:
        return (TreasuryTokens.warningSoft,
            TreasuryTokens.warning.withValues(alpha: 0.55),
            const Color(0xFFB45309));
      case TreasuryStatusTone.danger:
        return (TreasuryTokens.dangerSoft,
            TreasuryTokens.danger.withValues(alpha: 0.55),
            const Color(0xFFB91C1C));
      case TreasuryStatusTone.info:
        return (TreasuryTokens.infoSoft,
            TreasuryTokens.info.withValues(alpha: 0.55),
            const Color(0xFF4338CA));
      case TreasuryStatusTone.neutral:
        return (TreasuryTokens.surfaceAlt,
            TreasuryTokens.hairline, TreasuryTokens.inkSoft);
      case TreasuryStatusTone.brand:
        return (TreasuryTokens.brandSoft,
            TreasuryTokens.brand.withValues(alpha: 0.55),
            TreasuryTokens.brandDeep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
              boxShadow: glow
                  ? [BoxShadow(color: fg, blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: fg,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 11, color: fg),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON (Treasury brand)
// ═══════════════════════════════════════════════════════════════════════════

class TreasuryPrimaryButton extends StatelessWidget {
  const TreasuryPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.dark = false,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool dark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1D1F) : TreasuryTokens.brand;
    final fg = dark ? TreasuryTokens.brand : TreasuryTokens.ink;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: (dark
                                ? const Color(0xFF1A1D1F)
                                : TreasuryTokens.brand)
                            .withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : TreasuryTokens.ink,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
