library;

/// NDU PROJECT Logo Banner — a branded, horizontally centered banner that
/// displays the NDU PROJECT logo (assets/images/Logo.png) on a clean white
/// surface with a subtle hairline border and soft shadow.
///
/// This widget replaces the previously embedded CrossSectionSyncCard on the
/// Cost Estimate module screen (and is reusable on any other module screen
/// that wants to lead with the NDU PROJECT brand identity). It is fully
/// tappable — tapping anywhere on the banner calls the optional [onTap]
/// callback (typically used to navigate back to the landing/dashboard page).
///
/// Design language:
///   - White surface card (matches the rest of the app's light mode)
///   - 12 px rounded corners
///   - 1 px hairline border (`#E4E7EC`)
///   - Soft drop shadow for subtle elevation
///   - Logo centered horizontally with vertical padding
///   - Optional [height] for the rendered logo (defaults to 56 px, matching
///     the standard `AppLogo` header height)
///
/// Usage:
/// ```dart
/// NduLogoBanner(
///   onTap: () => NavigationContextService.instance.navigateFromLogo(context),
/// )
/// ```

import 'package:flutter/material.dart';

import 'package:ndu_project/theme.dart';

class NduLogoBanner extends StatelessWidget {
  const NduLogoBanner({
    super.key,
    this.onTap,
    this.height = 56,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
    this.subtitle,
  });

  /// Called when the user taps anywhere on the banner. Pass null to disable
  /// the tap affordance (banner becomes purely decorative).
  final VoidCallback? onTap;

  /// Rendered height of the logo image. Defaults to 56 (matching the
  /// standard `AppLogo` header height). Width is unconstrained and the
  /// aspect ratio is preserved.
  final double height;

  /// Outer margin around the banner card. Defaults to a slim top margin
  /// that visually separates the banner from the [ContextBanner] above it
  /// while staying tight against the tab content below.
  final EdgeInsets margin;

  /// Optional small caption rendered beneath the logo. When null, the banner
  /// shows only the logo. When provided, the caption uses a muted caption
  /// style so it does not compete with the logo itself.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              isDark
                  ? 'assets/images/Ndu_logodarkmode.png'
                  : 'assets/images/Logo.png',
              height: height,
              fit: BoxFit.contain,
              semanticLabel: 'NDU PROJECT logo',
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                    fontFamily: appFontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }
}
