/// A height-capped, scrollable host for a module screen's section-header stack.
///
/// Each module screen (Schedule, Cost Estimate, WBS, Project Controls) used to
/// pin its header stack — the section navigator, the context banner and the
/// status cards — above the tab content. On a short window, or as soon as one of
/// those cards was expanded, the pinned stack squeezed the tab content instead
/// of getting out of the way. Wrapping the stack in this widget instead:
///
/// - caps it at half the viewport (never shorter than [minHeight]), so the tab
///   content below always keeps its half,
/// - scrolls the stack inside that cap,
/// - floats a subtle "Scroll for more" pill while there is more below,
/// - auto-collapses the whole stack to a slim summary bar once the user has
///   scrolled it partway ([autoCollapseAfter]) and the scroll has settled,
///   handing the freed height to the content below. The bar's "Show header"
///   button brings the stack back.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScrollableSectionHeader extends StatefulWidget {
  const ScrollableSectionHeader({
    super.key,
    required this.child,
    required this.label,
    this.icon = Icons.dashboard_outlined,
    this.summary,
    this.scrollKey,
    this.autoCollapseAfter = 56,
    this.minHeight = 200,
    this.maxHeightFactor = 0.5,
  });

  /// The section-header stack itself.
  final Widget child;

  /// Short module name, shown on the collapsed summary bar.
  final String label;

  /// Icon for the collapsed summary bar.
  final IconData icon;

  /// Optional context for the collapsed bar — the active tab's label is a good
  /// fit, so the bar still says which section the user is in.
  final String? summary;

  /// Key for the stack's scroll view, so tests can drive it.
  final Key? scrollKey;

  /// How far the user must scroll the stack before it auto-collapses.
  final double autoCollapseAfter;

  /// Floor for the cap, so the navigator stays usable on short windows.
  final double minHeight;

  /// Share of the viewport the stack may occupy before it starts scrolling.
  final double maxHeightFactor;

  @override
  State<ScrollableSectionHeader> createState() =>
      _ScrollableSectionHeaderState();
}

class _ScrollableSectionHeaderState extends State<ScrollableSectionHeader> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textMuted = Color(0xFF9CA3AF);
  static const _border = Color(0xFFE4E7EC);
  static const _accent = Color(0xFFB8860B);

  /// `keepScrollOffset: false`: the stack is rebuilt from scratch each time it
  /// is shown again, and a restored offset would immediately re-collapse it.
  final ScrollController _controller =
      ScrollController(keepScrollOffset: false);

  bool _collapsed = false;
  bool _hasMoreBelow = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    // The hint has to know about the very first layout's metrics.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromPosition());
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _syncFromPosition();
    return false;
  }

  bool _onScrollMetricsNotification(ScrollMetricsNotification notification) {
    _syncFromPosition();
    return false;
  }

  /// Re-reads this stack's own position. Notifications bubble up from the
  /// scroll views nested inside the stack (the context banner and the tab
  /// pills scroll horizontally) and carry copies of their metrics, so taking
  /// the position from [_controller] is the only reliable source.
  void _syncFromPosition() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;

    final hasMore = position.extentAfter > 8;
    if (hasMore != _hasMoreBelow) {
      _hasMoreBelow = hasMore;
      // Scroll metrics change during layout, so rebuild on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (!_collapsed && position.pixels > widget.autoCollapseAfter) {
      _scheduleAutoCollapse();
    }
  }

  /// Collapses once the scroll settles, so the stack is never torn down while
  /// the user is still dragging it.
  void _scheduleAutoCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || _collapsed) return;
      final position = _controller.hasClients ? _controller.position : null;
      if (position == null || position.pixels <= widget.autoCollapseAfter) {
        return;
      }
      setState(() {
        _collapsed = true;
        _hasMoreBelow = false;
      });
    });
  }

  void _expand() {
    setState(() {
      _collapsed = false;
      _hasMoreBelow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Half the viewport, floored so the navigator stays usable on short
        // windows. The stack is a non-flexible child of the screen's Column, so
        // it is laid out with an unbounded main axis: fall back to the window
        // height whenever the incoming constraints do not bound it.
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final maxHeight = math.max(
          widget.minHeight,
          availableHeight * widget.maxHeightFactor,
        );

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _collapsed
              ? _buildCollapsedBar()
              : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child:
                            NotificationListener<ScrollMetricsNotification>(
                          onNotification: _onScrollMetricsNotification,
                          child: Scrollbar(
                            controller: _controller,
                            child: SingleChildScrollView(
                              key: widget.scrollKey,
                              controller: _controller,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            key: const ValueKey('sectionHeaderScrollHint'),
                            opacity: _hasMoreBelow ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: _buildScrollHint(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// The subtle "there is more above/below" cue for the header stack.
  Widget _buildScrollHint() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_arrow_down, size: 13, color: _textMuted),
            SizedBox(width: 4),
            Text(
              'Scroll for more',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The slim bar the stack collapses into, so the tab content gains the room.
  Widget _buildCollapsedBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: _accent),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          if (widget.summary != null && widget.summary!.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.summary!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: _expand,
            icon: const Icon(Icons.unfold_more, size: 14),
            label: const Text(
              'Show header',
              style: TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
