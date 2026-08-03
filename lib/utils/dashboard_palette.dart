// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// dashboard_palette.dart
//
// Shared design tokens for the world-class project dashboards.
//
// The product has two plan tiers, each with its own visual identity:
//
//   Regular Projects (basic plan) → the warm-teal "Runway" language.
//     Used by: RegularProjectDashboardScreen, and the basic-plan mode of
//     ProjectDashboardScreen / ProjectDashboardMobileShell.
//     - Warm off-white canvas, teal primary (#0D9488), sand/clay neutrals,
//       generous 22-28px radii, soft shadows, onboarding-first tone.
//
//   Project (standard plan) → the royal-blue "Command Center" language.
//     Used by: ProjectCommandCenterScreen, and the standard mode of
//     ProjectDashboardScreen / ProjectDashboardMobileShell.
//     - Cool ivory canvas, royal blue primary (#2563EB), slate/charcoal
//       neutrals, tight radii, sharp shadows, executive cockpit tone.
//
// Both palettes share the same structural design language — only the hue
// (and a few radius/shadow tokens) change. Screens read the active palette
// through [DashboardPaletteScope] so every child widget stays in sync.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/widgets.dart';

/// Design tokens for a project dashboard. Picks the warm-teal "Runway"
/// palette for basic-plan (Regular) workspaces and the royal-blue
/// "Command Center" palette for standard (Project) workspaces.
class DashboardPalette {
  DashboardPalette({required this.isBasicPlan});

  /// True → Regular (basic plan) workspace → teal Runway palette.
  /// False → Project (standard plan) workspace → royal-blue Command Center.
  final bool isBasicPlan;

  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// Page canvas.
  Color get canvas =>
      isBasicPlan ? const Color(0xFFFBFAF7) : const Color(0xFFF6F7FB);
  /// Elevated card surface.
  Color get surface =>
      isBasicPlan ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
  /// Warm/muted secondary surface (banners, chips).
  Color get surfaceAlt =>
      isBasicPlan ? const Color(0xFFFFFBF3) : const Color(0xFFEFF2F8);
  /// Soft tint of the primary (icon tiles, pills).
  Color get primarySoft =>
      isBasicPlan ? const Color(0xFFCCFBF1) : const Color(0xFFDBEAFE);
  /// Deep dark surface (attention rail / header band base).
  Color get surfaceDeep =>
      isBasicPlan ? const Color(0xFF115E59) : const Color(0xFF0F172A);

  // ── Borders ───────────────────────────────────────────────────────────────
  Color get outline =>
      isBasicPlan ? const Color(0xFFE7E5E0) : const Color(0xFFE2E8F0);
  Color get outlineSoft =>
      isBasicPlan ? const Color(0xFFF1EFE9) : const Color(0xFFEEF1F6);

  // ── Text ──────────────────────────────────────────────────────────────────
  Color get ink =>
      isBasicPlan ? const Color(0xFF1A1D1F) : const Color(0xFF0B1220);
  Color get inkSoft =>
      isBasicPlan ? const Color(0xFF3D4046) : const Color(0xFF1E293B);
  Color get muted =>
      isBasicPlan ? const Color(0xFF6B7280) : const Color(0xFF64748B);
  Color get mutedSoft =>
      isBasicPlan ? const Color(0xFF9CA3AF) : const Color(0xFF94A3B8);

  // ── Brand ─────────────────────────────────────────────────────────────────
  Color get primary =>
      isBasicPlan ? const Color(0xFF0D9488) : const Color(0xFF2563EB);
  Color get primaryDeep =>
      isBasicPlan ? const Color(0xFF0F766E) : const Color(0xFF1D4ED8);
  Color get accent =>
      isBasicPlan ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

  // ── Status ────────────────────────────────────────────────────────────────
  Color get onTrack =>
      isBasicPlan ? const Color(0xFF10B981) : const Color(0xFF059669);
  Color get atRisk =>
      isBasicPlan ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get offTrack =>
      isBasicPlan ? const Color(0xFFFB7185) : const Color(0xFFDC2626);

  // ── Header band gradient ──────────────────────────────────────────────────
  List<Color> get deepBand => isBasicPlan
      ? const [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF115E59)]
      : const [Color(0xFF0B1220), Color(0xFF1E293B), Color(0xFF0F172A)];

  // ── Shape ─────────────────────────────────────────────────────────────────
  double get cardRadius => isBasicPlan ? 22 : 16;
  double get sectionRadius => isBasicPlan ? 28 : 16;
  double get pillRadius => isBasicPlan ? 999 : 999;

  /// Convenience: build a palette for the current plan tier.
  factory DashboardPalette.forPlan(bool isBasicPlan) =>
      DashboardPalette(isBasicPlan: isBasicPlan);
}

/// Inherited scope that exposes the active [DashboardPalette] to the whole
/// dashboard subtree. Wrap the dashboard body once; children read the palette
/// with [DashboardPaletteScope.of].
class DashboardPaletteScope extends InheritedWidget {
  const DashboardPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final DashboardPalette palette;

  /// Nearest active palette above this widget. Falls back to the standard
  /// (royal-blue) palette when no scope is present.
  static DashboardPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DashboardPaletteScope>();
    return scope?.palette ?? DashboardPalette(isBasicPlan: false);
  }

  @override
  bool updateShouldNotify(DashboardPaletteScope oldWidget) =>
      oldWidget.palette.isBasicPlan != palette.isBasicPlan;
}
