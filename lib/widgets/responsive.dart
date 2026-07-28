import 'package:flutter/material.dart';

/// Central breakpoints and helpers for responsive layouts.
class AppBreakpoints {
  // Tune breakpoints to match common device classes
  static const double tablet = 768; // < 768 = mobile
  static const double desktop = 1200; // >= 1200 = desktop

  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < tablet;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tablet && w < desktop;
  }
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;

  static double pagePadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 40;
  }

  static double sectionGap(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 28;
  }

  static double fieldGap(BuildContext context) {
    if (isMobile(context)) return 10;
    if (isTablet(context)) return 14;
    return 18;
  }

  static double sidebarWidth(BuildContext context) {
    if (isDesktop(context)) return 320;
    if (isTablet(context)) return 240;
    final width = MediaQuery.sizeOf(context).width;
    final double mobileWidth = (width * 0.85).clamp(240.0, 320.0).toDouble();
    return mobileWidth;
  }
}
