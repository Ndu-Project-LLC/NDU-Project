import 'package:flutter/material.dart';

import '../services/navigation_context_service.dart';

/// World-class, interactive app logo widget for the entire NDU Project
/// application.
///
/// Renders the canonical brand asset — `assets/images/Logo.png`, the dark
/// NDU squircle (gold trend-arrow icon, white "NDU" + gold "PROJECT"
/// wordmark, "Navigate. Deliver. Upgrade." tagline). The same asset is used
/// for both light and dark surfaces because the squircle carries its own
/// dark background.
///
/// Visibility on dark surfaces: the squircle is near-black, so when it sits
/// on a dark background (dark theme, black landing page) a 1px gold
/// hairline border + subtle gold glow is applied so the logo always reads
/// clearly. On light surfaces the squircle's own contrast needs no help.
///
/// Features smooth hover animations and professional visual feedback.
class AppLogo extends StatefulWidget {
  const AppLogo({
    super.key,
    this.height,
    this.width,
    this.semanticLabel,
    this.enableTapToDashboard = true,
    this.onDarkBackground,
  });

  /// Desired rendered height. If null, defaults to 56 for compact headers.
  final double? height;

  /// Optional explicit width. If null, width is unconstrained and aspect ratio is preserved.
  final double? width;

  /// Optional semantic label for accessibility/readers.
  final String? semanticLabel;

  /// When true, tapping the logo will navigate to the landing page. Defaults to true.
  final bool enableTapToDashboard;

  /// Explicit control over the dark-background hairline treatment.
  ///
  /// * `null` (default) — auto-detect from the ambient [Theme] brightness.
  /// * `true` — always apply the gold hairline border + glow (e.g. the
  ///   black landing page, which is dark regardless of platform theme).
  /// * `false` — never apply it (e.g. white cards).
  final bool? onDarkBackground;

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverChange(bool hovering) {
    setState(() => _isHovering = hovering);
    if (hovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 56;
    final themeIsDark = Theme.of(context).brightness == Brightness.dark;
    // The squircle asset is used on every surface; only the hairline
    // treatment varies so the near-black logo stays visible in the dark.
    final onDark = widget.onDarkBackground ?? themeIsDark;
    const assetPath = 'assets/images/Logo.png';

    final image = Image.asset(
      assetPath,
      height: h,
      width: widget.width,
      fit: BoxFit.contain,
      semanticLabel: widget.semanticLabel,
      cacheHeight: (MediaQuery.devicePixelRatioOf(context) * h).round(),
    );

    // ── Dark-background visibility treatment ──
    // The squircle is near-black (#0d0d0d); on dark surfaces it needs a
    // 1px gold hairline + soft gold glow to read clearly. On light
    // surfaces the squircle's own contrast is sufficient.
    final hairline = onDark
        ? Border.all(
            color: const Color(0xFFFFC60B).withValues(alpha: 0.55),
            width: 1,
          )
        : null;
    final glow = onDark
        ? [
            BoxShadow(
              // Gold-tinted glow that frames the squircle in the dark.
              color: const Color(0xFFFFC60B).withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ]
        : <BoxShadow>[];

    // The squircle's own rounded corners must NOT be cropped or re-rounded
    // by a ClipRRect — padding keeps the border floating just outside it.
    final framed = Container(
      height: h,
      width: widget.width,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h * 0.18),
        border: hairline,
        boxShadow: glow,
      ),
      child: image,
    );

    if (!widget.enableTapToDashboard) {
      return SizedBox(height: h, width: widget.width, child: framed);
    }

    // World-class interactive logo with smooth animations and hover effects
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!mounted) return;
          NavigationContextService.instance.navigateFromLogo(context);
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Semantics(
                button: true,
                label: widget.semanticLabel ?? 'Go to landing page',
                child: child,
              ),
            ),
          ),
          child: framed,
        ),
      ),
    );
  }
}
