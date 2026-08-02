import 'package:flutter/material.dart';

import '../services/navigation_context_service.dart';

/// World-class, interactive app logo widget that automatically switches between
/// assets/images/Logo.png (light mode) and assets/images/Ndu_logodarkmode.png (dark mode).
/// Features smooth hover animations and professional visual feedback.
class AppLogo extends StatefulWidget {
  const AppLogo({
    super.key,
    this.height,
    this.width,
    this.semanticLabel,
    this.enableTapToDashboard = true,
  });

  /// Desired rendered height. If null, defaults to 56 for compact headers.
  final double? height;

  /// Optional explicit width. If null, width is unconstrained and aspect ratio is preserved.
  final double? width;

  /// Optional semantic label for accessibility/readers.
  final String? semanticLabel;

  /// When true, tapping the logo will navigate to the landing page. Defaults to true.
  final bool enableTapToDashboard;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use theme-aware logo selection: dark mode uses dark logo, light mode uses standard logo
    final assetPath = isDark
        ? 'assets/images/Ndu_logodarkmode.png' // Dark mode logo
        : 'assets/images/Logo.png'; // Light mode logo (using Logo.png as requested)

    final image = Image.asset(
      assetPath,
      height: h,
      width: widget.width,
      fit: BoxFit.contain,
      semanticLabel: widget.semanticLabel,
    );

    if (!widget.enableTapToDashboard) {
      return SizedBox(height: h, width: widget.width, child: image);
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
              child: Container(
                height: h,
                width: widget.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isHovering
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Semantics(
                  button: true,
                  label: widget.semanticLabel ?? 'Go to landing page',
                  child: child,
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
      ),
    );
  }
}
