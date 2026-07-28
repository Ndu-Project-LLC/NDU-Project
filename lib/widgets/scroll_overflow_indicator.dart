import 'package:flutter/material.dart';

class ScrollOverflowIndicator extends StatefulWidget {
  const ScrollOverflowIndicator({
    super.key,
    required this.controller,
    required this.child,
    this.bottomInset = 0,
  });

  final ScrollController controller;
  final Widget child;
  final double bottomInset;

  @override
  State<ScrollOverflowIndicator> createState() =>
      _ScrollOverflowIndicatorState();
}

class _ScrollOverflowIndicatorState extends State<ScrollOverflowIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void didUpdateWidget(covariant ScrollOverflowIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_updateVisibility);
    widget.controller.addListener(_updateVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateVisibility);
    _animationController.dispose();
    super.dispose();
  }

  void _updateVisibility() {
    if (!mounted) return;
    final shouldShow = widget.controller.hasClients &&
        widget.controller.position.maxScrollExtent > 0 &&
        widget.controller.offset <
            widget.controller.position.maxScrollExtent - 1;
    if (shouldShow == _showIndicator) return;
    setState(() => _showIndicator = shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomInset,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showIndicator ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.94),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final dy = 4 * _animationController.value;
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: child,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: Color(0xFF94A3B8),
                      ),
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
