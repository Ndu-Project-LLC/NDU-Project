import 'package:flutter/material.dart';

import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';

/// Theme-resolved design tokens for the Integration Dashboard.
///
/// The dashboard needs to satisfy two very different jobs at once — a
/// portfolio-level workspace launchpad and a project-level baseline
/// integration review — and both have to read correctly in light *and*
/// dark mode. Rather than scattering `isDarkMode ?` ternaries through the
/// widget tree (or, as the previous implementations did, hard-coding
/// `Colors.white`), every widget resolves one of these snapshots and takes
/// all of its colours from it.
///
/// Brand hues (gold, amber, emerald, red) come from the active
/// [DashboardPalette] so the screen stays inside the app's yellow/gold
/// visual language; neutrals come from [AdaptiveColors] so dark mode is
/// handled by the theme rather than by a parallel set of constants.
@immutable
class IntegrationTokens {
  const IntegrationTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.outline,
    required this.outlineSoft,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.mutedSoft,
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.onBrand,
    required this.good,
    required this.warn,
    required this.bad,
    required this.neutral,
    required this.shadow,
  });

  /// Resolve tokens for the ambient [BuildContext] and [palette].
  factory IntegrationTokens.of(
    BuildContext context,
    DashboardPalette palette,
  ) {
    final isDark = context.isDarkMode;
    return IntegrationTokens(
      canvas: isDark
          ? DarkModeColors.darkSurface
          : const Color(0xFFFFFDF7),
      surface: context.adaptiveCard,
      surfaceAlt: context.adaptiveSubtle,
      // A slightly recessed well used for progress tracks and code chips.
      surfaceSunken:
          isDark ? const Color(0xFF0B0D11) : const Color(0xFFF7F4EC),
      outline: context.adaptiveBorder,
      outlineSoft: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1EDE2),
      ink: context.adaptiveTextPrimary,
      inkSoft: isDark
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF3D4046),
      muted: context.adaptiveTextSecondary,
      mutedSoft: context.adaptiveTextMuted,
      brand: palette.primary,
      brandDeep: palette.primaryDeep,
      brandSoft: palette.primarySoft,
      onBrand: const Color(0xFF1C1C1C),
      good: isDark ? DarkModeColors.successColor : palette.onTrack,
      warn: isDark ? DarkModeColors.warningColor : palette.atRisk,
      bad: isDark ? const Color(0xFFF87171) : palette.offTrack,
      neutral: context.adaptiveTextMuted,
      shadow: isDark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;
  final Color outline;
  final Color outlineSoft;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color mutedSoft;
  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color onBrand;
  final Color good;
  final Color warn;
  final Color bad;
  final Color neutral;
  final Color shadow;

  /// Status colour for a rollup key: `on_track` / `at_risk` / `off_track`.
  Color health(String status) {
    switch (status) {
      case 'on_track':
        return good;
      case 'at_risk':
        return warn;
      case 'off_track':
        return bad;
      default:
        return neutral;
    }
  }
}