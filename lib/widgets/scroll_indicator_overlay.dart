import 'package:flutter/material.dart';

/// Subtle passive hint that more content exists below the current viewport.
class ScrollIndicatorOverlay extends StatefulWidget {
  const ScrollIndicatorOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.bottomPadding = 12,
  });

  final ScrollController controller;
  final Widget child;
  final double bottomPadding;

  @override
  State<ScrollIndicatorOverlay> createState() => _ScrollIndicatorOverlayState();
}

class _ScrollIndicatorOverlayState extends State<ScrollIndicatorOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateIndicator);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicator());
  }

  @override
  void didUpdateWidget(covariant ScrollIndicatorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateIndicator);
      widget.controller.addListener(_updateIndicator);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicator());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateIndicator);
    _animationController.dispose();
    super.dispose();
  }

  void _updateIndicator() {
    if (!mounted || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    final nextValue = position.maxScrollExtent > 1 &&
        position.pixels < position.maxScrollExtent - 8;
    if (nextValue != _showIndicator) {
      setState(() => _showIndicator = nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomPadding,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showIndicator ? 1 : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.92),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final offset = 2 + (_animationController.value * 6);
                      return Transform.translate(
                        offset: Offset(0, offset),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
