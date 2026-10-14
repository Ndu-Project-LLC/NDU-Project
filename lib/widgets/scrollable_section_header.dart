/// One vertical scroll experience for a module screen's header + tab content.
///
/// The old design capped the header stack (section navigator, context banner,
/// status cards) at half the viewport and scrolled it inside that cap — a
/// scrollport inside the scrollport. On any real window that meant the stack
/// clipped its own content behind a "Scroll for more" pill, fought the tab
/// content's own scroll gesture below, and auto-collapsed itself out from
/// under the user's finger mid-scroll.
///
/// This widget replaces all of it with a single [NestedScrollView]:
///
/// - The header stack renders as ordinary slivers of the page's outer scroll,
///   so it scrolls away naturally with the content. No cap, no clipping, no
///   second scrollport, no hint pill, no collapse timers.
/// - A slim pinned bar (module label + active tab) stays available however
///   deep the user is in the tab content; tapping it scrolls the header back
///   in.
/// - The tab body inherits the [NestedScrollView] inner controller through the
///   [PrimaryScrollController], so one continuous drag hands off between
///   header and content exactly once.
///
/// The name is kept for continuity with the four module screens that host
/// their stacks here (Schedule, WBS, Cost Estimate, Project Controls).
///
/// Layout contract: this widget adapts to its parent. Under a bounded parent
/// (the module screens' `ResponsiveScaffold`, a Scaffold body, an `Expanded`)
/// it fills the available height. Under an unbounded parent (a [Column] or
/// scrollable handing down infinite height) it sizes itself to the viewport
/// height instead of crashing, so it can be dropped into any layout — the
/// internal [NestedScrollView] always needs a bounded scrollport.
library;

import 'package:flutter/material.dart';

class ScrollableSectionHeader extends StatefulWidget {
  const ScrollableSectionHeader({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.label = '',
    this.icon,
    this.summary,
    this.scrollKey,
    this.showPinnedBar = true,
    this.pinnedBarHeight = 44,
  });

  /// The section-header stack — section navigator, context banner, status
  /// cards. Rendered as the first sliver of the page scroll, uncapped: it is
  /// always fully laid out and simply scrolls away with the page.
  final Widget header;

  /// The tab content. Its primary vertical scrollable attaches to the
  /// [NestedScrollView] inner controller automatically, so header and content
  /// scroll as one continuous surface.
  final Widget body;

  /// Optional row rendered underneath the scroll (e.g. the WBS module's
  /// back/next phase navigation), outside the scroll so it never scrolls off.
  final Widget? footer;

  /// Short module name shown on the pinned bar.
  final String label;

  /// Icon shown on the pinned bar.
  final IconData? icon;

  /// Active tab label, shown as a chip on the pinned bar so the bar still says
  /// which section the user is in after the stack has scrolled away.
  final String? summary;

  /// Key for the underlying [NestedScrollView], so tests can drive the page
  /// scroll.
  final Key? scrollKey;

  /// Whether the pinned summary bar is shown at all.
  final bool showPinnedBar;

  /// Height of the pinned summary bar.
  final double pinnedBarHeight;

  @override
  State<ScrollableSectionHeader> createState() =>
      _ScrollableSectionHeaderState();
}

class _ScrollableSectionHeaderState extends State<ScrollableSectionHeader> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textMuted = Color(0xFF9CA3AF);
  static const _border = Color(0xFFE4E7EC);
  static const _accent = Color(0xFFB8860B);

  final ScrollController _outerController = ScrollController();

  @override
  void dispose() {
    _outerController.dispose();
    super.dispose();
  }

  /// Brings the header stack back into view — the pinned bar's one job.
  void _scrollToHeader() {
    if (!_outerController.hasClients) return;
    _outerController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final footer = widget.footer;

    // The NestedScrollView needs a bounded height. Under a bounded parent the
    // outer Column fills it (Expanded) and the footer renders below the
    // scroll; under an unbounded parent (plain Column, scrollable) a flex
    // child would crash, so the scrollport is sized to the viewport instead.
    // Sizing to the viewport keeps the one-scroll-surface behaviour even in
    // that layout: the header stack scrolls away inside the scrollport and
    // the pinned bar stays reachable.
    final scroll = NestedScrollView(
      key: widget.scrollKey,
      controller: _outerController,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        if (widget.showPinnedBar)
          SliverAppBar(
            primary: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: widget.pinnedBarHeight,
            titleSpacing: 16,
            shape: Border(
              bottom: BorderSide(
                color: _border.withValues(alpha: 0.7),
              ),
            ),
            title: _buildPinnedBar(),
          ),
        SliverToBoxAdapter(child: widget.header),
      ],
      body: widget.body,
    );

    return LayoutBuilder(builder: (context, constraints) {
      final hasBoundedHeight = constraints.hasBoundedHeight;
      return Column(children: [
        if (hasBoundedHeight)
          Expanded(child: scroll)
        else
          // Viewport-sized, so the scrollport stays bounded even when the
          // parent hands down infinite height. As a non-flex child it cannot
          // share space with a footer, so the footer renders over the bottom
          // edge of the scroll instead of below it.
          SizedBox(
            height: MediaQuery.heightOf(context),
            child: footer == null
                ? scroll
                : Stack(children: [
                    Positioned.fill(child: scroll),
                    Positioned(left: 0, right: 0, bottom: 0, child: footer),
                  ]),
          ),
        if (footer != null && hasBoundedHeight) footer,
      ]);
    });
  }

  /// The slim always-available bar: module label + active tab, tap to return
  /// to the header stack.
  Widget _buildPinnedBar() {
    final summary = widget.summary?.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _scrollToHeader,
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 15, color: _accent),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ),
          ],
          const Spacer(),
          const Tooltip(
            message: 'Back to top',
            child: Icon(Icons.vertical_align_top, size: 15, color: _textMuted),
          ),
        ],
      ),
    );
  }
}
