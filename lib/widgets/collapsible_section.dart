import 'package:flutter/material.dart';

/// A collapsible section with a header row that the user can tap to
/// expand or collapse the child content. The header shows a title,
/// an optional item count badge, and a chevron icon that rotates.
///
/// Used on the Project and Portfolio dashboards to make the "Project
/// status" grid retractable.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.itemCount,
    this.initiallyExpanded = true,
    this.accentColor = const Color(0xFF0F172A),
  });

  final String title;
  final Widget child;
  final int? itemCount;
  final bool initiallyExpanded;
  final Color accentColor;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _chevronRotation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _chevronRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header (tappable) ──────────────────────────────────────────
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    decoration: TextDecoration.none,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                  ),
                ),
                if (widget.itemCount != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.itemCount}',
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedBuilder(
                  animation: _chevronRotation,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _chevronRotation.value * 3.14159265,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: const Color(0xFF94A3B8),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Collapsible content ─────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              widget.child,
            ],
          ),
        ),
      ],
    );
  }
}
