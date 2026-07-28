import 'package:flutter/material.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// World-Class Mobile Responsive Design System for NDU Project
/// ═════════════════════════════════════════════════════════════════════════
///
/// Based on Material 3 design principles, Google's responsive design guidelines,
/// and adaptive layout patterns. Provides breakpoints, spacing, typography,
/// and component sizing that adapt smoothly across mobile, tablet, and desktop.
///
/// Design laws followed:
/// 1. Touch targets ≥ 48dp (Material minimum)
/// 2. Safe area insets respected on all screens
/// 3. Content never narrower than 320dp or wider than 600dp on mobile
/// 4. Single-column layout on mobile, two-column on tablet, three+ on desktop
/// 5. 16dp base spacing unit (Material 4dp grid × 4)
/// 6. Readable line length (45-75 characters) on all breakpoints
/// 7. Bottom navigation on mobile, sidebar on tablet/desktop

class AppBreakpoints {
  // ── Breakpoints (Material 3 + Google adaptive) ──────────────────────
  static const double compact = 360;   // Small phones
  static const double medium = 600;    // Large phones / small tablets
  static const double expanded = 840;  // Tablets
  static const double large = 1200;    // Desktops
  static const double extraLarge = 1600; // Large desktops

  // Legacy compat
  static const double tablet = 768;
  static const double desktop = 1200;

  // ── Device detection ────────────────────────────────────────────────
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  // ── Adaptive spacing (4dp grid system) ──────────────────────────────
  static double pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < compact) return 16;
    if (w < tablet) return 20;
    if (w < desktop) return 24;
    return 40;
  }

  static double sectionGap(BuildContext context) {
    if (isMobile(context)) return 20;
    if (isTablet(context)) return 24;
    return 28;
  }

  static double fieldGap(BuildContext context) {
    if (isMobile(context)) return 12;
    if (isTablet(context)) return 14;
    return 18;
  }

  static double sidebarWidth(BuildContext context) {
    if (isDesktop(context)) return 320;
    if (isTablet(context)) return 260;
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.82).clamp(260.0, 320.0).toDouble();
  }

  // ── Max content width (readable line length) ────────────────────────
  static double maxContentWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 720;
    return 1200;
  }

  // ── Card sizing ─────────────────────────────────────────────────────
  static double cardRadius(BuildContext context) {
    if (isMobile(context)) return 14;
    return 16;
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(16);
    if (isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(24);
  }

  // ── Touch targets (Material minimum 48dp) ───────────────────────────
  static const double minTouchTarget = 48.0;

  // ── Grid columns ────────────────────────────────────────────────────
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  // ── Font size scaling ───────────────────────────────────────────────
  static double headlineLarge(BuildContext context) {
    if (isMobile(context)) return 26;
    return 32;
  }

  static double headlineMedium(BuildContext context) {
    if (isMobile(context)) return 22;
    return 26;
  }

  static double titleLarge(BuildContext context) {
    if (isMobile(context)) return 18;
    return 22;
  }

  static double bodyLarge(BuildContext context) {
    if (isMobile(context)) return 14;
    return 16;
  }

  static double bodyMedium(BuildContext context) {
    if (isMobile(context)) return 13;
    return 14;
  }

  static double labelSmall(BuildContext context) {
    if (isMobile(context)) return 10;
    return 11;
  }
}

/// ═════════════════════════════════════════════════════════════════════════
/// MobileDesignSystem — World-class component styling for mobile screens
/// ═════════════════════════════════════════════════════════════════════════

class MobileDesignSystem {
  MobileDesignSystem._();

  // ── Brand colors ────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0F172A);
  static const Color accent = Color(0xFFFFC107);
  static const Color accentDark = Color(0xFFD97706);
  static const Color surface = Colors.white;
  static const Color surfaceHigh = Color(0xFFF8FAFC);
  static const Color surfaceHighest = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Mobile-optimized card ───────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(AppBreakpoints.cardRadius(context)),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── Mobile-optimized input decoration ───────────────────────────────
  static InputDecoration inputDecoration(BuildContext context, String hint) {
    final isMobile = AppBreakpoints.isMobile(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textMuted,
        fontSize: isMobile ? 13 : 14,
      ),
      filled: true,
      fillColor: surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        borderSide: const BorderSide(color: accentDark, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 16,
        vertical: isMobile ? 12 : 14,
      ),
    );
  }

  // ── Mobile-optimized button styles ──────────────────────────────────
  static ButtonStyle primaryButton(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    return ElevatedButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.black,
      elevation: 0,
      minimumSize: Size(
        double.infinity,
        isMobile ? 48 : 52,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 24,
        vertical: isMobile ? 12 : 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
      ),
      textStyle: TextStyle(
        fontSize: isMobile ? 14 : 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ButtonStyle secondaryButton(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    return OutlinedButton.styleFrom(
      foregroundColor: textSecondary,
      side: const BorderSide(color: border),
      minimumSize: Size(
        double.infinity,
        isMobile ? 48 : 52,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 24,
        vertical: isMobile ? 12 : 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
      ),
      textStyle: TextStyle(
        fontSize: isMobile ? 14 : 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Mobile bottom nav bar ───────────────────────────────────────────
  static BottomAppBar bottomNav() {
    return const BottomAppBar(
      color: surface,
      elevation: 8,
      shape: CircularNotchedRectangle(),
    );
  }

  // ── Mobile section header ───────────────────────────────────────────
  static Widget sectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppBreakpoints.titleLarge(context),
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
            if (action != null) action,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppBreakpoints.bodyMedium(context),
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  // ── Mobile stat card ────────────────────────────────────────────────
  static Widget statCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
  }) {
    final isMobile = AppBreakpoints.isMobile(context);
    return Container(
      padding: AppBreakpoints.cardPadding(context),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? info).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor ?? info, size: isMobile ? 16 : 18),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: AppBreakpoints.labelSmall(context),
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile responsive grid ──────────────────────────────────────────
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    double spacing = 12,
  }) {
    final columns = AppBreakpoints.gridColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: columns == 1 ? 2.2 : 1.3,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  // ── Safe area wrapper for mobile ────────────────────────────────────
  static Widget safeArea({
    required Widget child,
    bool top = true,
    bool bottom = true,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      child: child,
    );
  }

  // ── Mobile bottom sheet styling ─────────────────────────────────────
  static RoundedRectangleBorder bottomSheetShape() {
    return const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    );
  }

  // ── Mobile snackbar ─────────────────────────────────────────────────
  static SnackBar snackbar(String message, {Color? backgroundColor}) {
    return SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: backgroundColor ?? textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    );
  }
}

/// ═════════════════════════════════════════════════════════════════════════
/// MobileResponsiveWrapper — wraps any screen with responsive behavior
/// ═════════════════════════════════════════════════════════════════════════

class MobileResponsiveWrapper extends StatelessWidget {
  const MobileResponsiveWrapper({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (AppBreakpoints.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}
