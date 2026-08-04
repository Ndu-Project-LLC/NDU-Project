// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// dashboard_palette.dart
//
// Shared design tokens for the world-class project dashboards.
//
// The product has two plan tiers, each with its own visual identity — but both
// are built on the application's signature YELLOW / GOLD brand language
// (brand yellow #FFC812 → gold #FABD00 → amber #F59E0B):
//
//   Regular Projects (basic plan) → the bright-yellow "Runway" language.
//     Used by: RegularProjectDashboardScreen, and the basic-plan mode of
//     ProjectDashboardScreen / ProjectDashboardMobileShell.
//     - Warm ivory canvas, BRAND YELLOW primary (#FFC812), sand/amber
//       neutrals, generous 22-28px radii, soft shadows, onboarding-first tone.
//
//   Project (standard plan) → the rich-gold "Command Center" language.
//     Used by: ProjectCommandCenterScreen, and the standard mode of
//     ProjectDashboardScreen / ProjectDashboardMobileShell.
//     - Cool ivory canvas, GOLD primary (#F4B400), amber neutrals, tight
//       radii, sharp shadows, executive cockpit tone.
//
// Both palettes share the same structural design language — only the hue
// (and a few radius/shadow tokens) change. Screens read the active palette
// through [DashboardPaletteScope] so every child widget stays in sync.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/widgets.dart';

/// Design tokens for a project dashboard. Both tiers share the application's
/// yellow/gold brand language: the bright-yellow "Runway" palette for
/// basic-plan (Regular) workspaces and the rich-gold "Command Center" palette
/// for standard (Project) workspaces.
class DashboardPalette {
  DashboardPalette({required this.isBasicPlan});

  /// True → Regular (basic plan) workspace → bright-yellow Runway palette.
  /// False → Project (standard plan) workspace → rich-gold Command Center.
  final bool isBasicPlan;

  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// Page canvas.
  Color get canvas =>
      isBasicPlan ? const Color(0xFFFFFDF5) : const Color(0xFFF8F9FC);
  /// Elevated card surface.
  Color get surface =>
      isBasicPlan ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
  /// Warm/muted secondary surface (banners, chips).
  Color get surfaceAlt =>
      isBasicPlan ? const Color(0xFFFFF9E6) : const Color(0xFFF3F4F8);
  /// Soft tint of the primary (icon tiles, pills, plan badges).
  Color get primarySoft =>
      isBasicPlan ? const Color(0xFFFFF4CC) : const Color(0xFFFEF3C7);
  /// Deep dark surface (attention rail / contrast header base).
  Color get surfaceDeep =>
      isBasicPlan ? const Color(0xFF3D2E00) : const Color(0xFF241A00);

  // ── Borders ───────────────────────────────────────────────────────────────
  Color get outline =>
      isBasicPlan ? const Color(0xFFE9E2D0) : const Color(0xFFE2E8F0);
  Color get outlineSoft =>
      isBasicPlan ? const Color(0xFFF3EEE1) : const Color(0xFFEEF1F6);

  // ── Text ──────────────────────────────────────────────────────────────────
  Color get ink =>
      isBasicPlan ? const Color(0xFF1C1C1C) : const Color(0xFF0B1220);
  Color get inkSoft =>
      isBasicPlan ? const Color(0xFF4A4033) : const Color(0xFF1E293B);
  Color get muted =>
      isBasicPlan ? const Color(0xFF6B7280) : const Color(0xFF64748B);
  Color get mutedSoft =>
      isBasicPlan ? const Color(0xFF9CA3AF) : const Color(0xFF94A3B8);

  // ── Brand (app signature yellow / gold) ───────────────────────────────────
  Color get primary =>
      isBasicPlan ? const Color(0xFFFFC812) : const Color(0xFFF4B400);
  Color get primaryDeep =>
      isBasicPlan ? const Color(0xFFD97706) : const Color(0xFFD97706);
  Color get accent =>
      isBasicPlan ? const Color(0xFFF59E0B) : const Color(0xFFEAB308);

  // ── Status ────────────────────────────────────────────────────────────────
  Color get onTrack =>
      isBasicPlan ? const Color(0xFF16A34A) : const Color(0xFF059669);
  Color get atRisk =>
      isBasicPlan ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get offTrack =>
      isBasicPlan ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  // ── Header band gradient (yellow → gold → amber) ─────────────────────────
  List<Color> get deepBand => isBasicPlan
      ? const [Color(0xFFFFC812), Color(0xFFFABD00), Color(0xFFF59E0B)]
      : const [Color(0xFFF4B400), Color(0xFFE8A000), Color(0xFFD97706)];

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
  /// (rich-gold) palette when no scope is present.
  static DashboardPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DashboardPaletteScope>();
    return scope?.palette ?? DashboardPalette(isBasicPlan: false);
  }

  @override
  bool updateShouldNotify(DashboardPaletteScope oldWidget) =>
      oldWidget.palette.isBasicPlan != palette.isBasicPlan;
}
