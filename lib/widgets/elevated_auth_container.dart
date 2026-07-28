import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';

/// A modern, elegant elevated container tailored for authentication forms.
///
/// Design goals:
/// - Subtle elevation without heavy drop shadows
/// - Frosted/soft surface with gentle gradient and border
/// - Smooth entrance animation
/// - Responsive paddings
class ElevatedAuthContainer extends StatefulWidget {
  const ElevatedAuthContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  State<ElevatedAuthContainer> createState() => _ElevatedAuthContainerState();
}

class _ElevatedAuthContainerState extends State<ElevatedAuthContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 0.985, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_controller);
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final EdgeInsetsGeometry contentPadding =
        widget.padding ?? EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: isMobile ? 16 : 24);

    final Color surface = theme.colorScheme.surface;
    final Color border = AppSemanticColors.border;
    final Color accent = theme.brightness == Brightness.dark
        ? DarkModeColors.accent
        : LightModeColors.accent;

    final Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surface,
                surface.withOpacity(0.92),
              ],
            ),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              // very subtle ambient and key shadows
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accent.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth ?? 560),
            padding: contentPadding,
            child: widget.child,
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: card,
      ),
    );
  }
}
