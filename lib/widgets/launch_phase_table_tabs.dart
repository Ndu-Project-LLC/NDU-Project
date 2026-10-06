import 'package:flutter/material.dart';

import '../theme.dart';

/// One tab in [LaunchPhaseTableTabs]: a label plus the builder for the widget
/// that fills the tab body.
///
/// Every Launch Phase screen used to stack its registers in a single long
/// `Column`, so reaching the last table meant scrolling past four or five
/// others. Each register now gets its own tab.
///
/// The matching entry in [LaunchPhaseTableTabs.builders] is invoked by the
/// [TabBarView], which builds the active tab and its immediate drag neighbours
/// only — so tabs further away cost nothing to declare.
class LaunchPhaseTableTab {
  const LaunchPhaseTableTab({required this.label, this.icon, this.badge});

  /// Tab label. Doubles as the key in [LaunchPhaseTableTabs.builders].
  final String label;

  /// Optional leading glyph on the tab. When null the bar picks one from
  /// [LaunchPhaseTableTabs.iconForLabel] so the rail never looks half-finished
  /// with a glyph on only some tabs.
  final IconData? icon;

  /// Optional short count/status chip, e.g. the number of outstanding items.
  final String? badge;
}

/// Widget factory for a tab body. Takes no arguments so a screen can pass a
/// bare tear-off of one of its existing `_buildXPanel()` methods.
typedef LaunchPhaseTabBuilder = Widget Function();

/// Tab host for the 11 Launch Phase screens.
///
/// Owns the [TabController] lifecycle and renders the segmented rail that
/// matches the rest of the Launch Phase surfaces (see
/// `execution_quality_tracking_screen.dart`).
///
/// A leading "Overview" tab holds [overview] — the screen's KPI/insights band
/// and notes — followed by one tab per [tabs] entry, whose bodies come from
/// [builders].
///
/// [TabBarView] needs a bounded height, which the surrounding page
/// `SingleChildScrollView` cannot provide, so the body height is derived from
/// the viewport minus [chromeHeight] (the header/insights space the screen
/// already consumes above this widget).
class LaunchPhaseTableTabs extends StatefulWidget {
  const LaunchPhaseTableTabs({
    super.key,
    required this.tabs,
    required this.builders,
    this.overview,
    this.overviewLabel = 'Overview',
    this.overviewIcon = Icons.insights_outlined,
    this.chromeHeight = 300,
    this.minTabBodyHeight = 340,
  });

  final List<LaunchPhaseTableTab> tabs;

  /// Tab bodies by [LaunchPhaseTableTab.label].
  final Map<String, LaunchPhaseTabBuilder> builders;

  /// Content of the leading Overview tab. When null, no Overview tab renders.
  final Widget? overview;

  final String overviewLabel;
  final IconData overviewIcon;
  final double chromeHeight;
  final double minTabBodyHeight;

  /// Picks a glyph for a tab that did not supply one, keyed off the words in
  /// the label so a screen's rail reads consistently without every call site
  /// having to name an icon.
  ///
  /// First match wins, so more specific words come first.
  static IconData iconForLabel(String label) {
    final l = label.toLowerCase();
    bool has(List<String> words) => words.any(l.contains);

    if (has(['overview', 'summary', 'insight', 'dashboard'])) {
      return Icons.insights_outlined;
    }
    if (has(['risk', 'risk follow', 'issue', 'problem', 'escalat'])) {
      return Icons.warning_amber_rounded;
    }
    if (has(['outstanding', 'open item', 'todo', 'action', 'backlog'])) {
      return Icons.pending_actions_rounded;
    }
    if (has(['milestone', 'deliverable date', 'timeline', 'schedule'])) {
      return Icons.flag_outlined;
    }
    if (has(['acceptance', 'accept', 'sign-?off', 'signoff', 'approval'])) {
      return Icons.verified_outlined;
    }
    if (has(['financial', 'finance', 'cost', 'budget', 'invoice', 'payment'])) {
      return Icons.account_balance_wallet_outlined;
    }
    if (has(['resource', 'staff', 'team', 'people', 'vendor'])) {
      return Icons.groups_outlined;
    }
    if (has(['contract', 'agreement', 'sow'])) {
      return Icons.description_outlined;
    }
    if (has(['training', 'enable', 'readiness', 'checklist'])) {
      return Icons.school_outlined;
    }
    if (has(['quality', 'test', 'qa', 'review'])) {
      return Icons.fact_check_outlined;
    }
    if (has(['close', 'exit', 'demobil'])) {
      return Icons.logout_rounded;
    }
    return Icons.table_rows_outlined;
  }

  @override
  State<LaunchPhaseTableTabs> createState() => _LaunchPhaseTableTabsState();
}

class _LaunchPhaseTableTabsState extends State<LaunchPhaseTableTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  int get _tabCount => (widget.overview == null ? 0 : 1) + widget.tabs.length;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabCount, vsync: this);
  }

  @override
  void didUpdateWidget(LaunchPhaseTableTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.length != _tabCount) {
      final previousIndex = _controller.index;
      final length = _tabCount;
      _controller.dispose();
      _controller = TabController(
        length: length,
        vsync: this,
        initialIndex: previousIndex.clamp(0, length - 1),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabCount == 0) return const SizedBox.shrink();

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bodyHeight = (viewportHeight - widget.chromeHeight)
        .clamp(widget.minTabBodyHeight, double.infinity);

    final specs = <_TabSpec>[
      if (widget.overview != null)
        _TabSpec(
          label: widget.overviewLabel,
          icon: widget.overviewIcon,
          badge: null,
        ),
      for (final t in widget.tabs)
        _TabSpec(
          label: t.label,
          icon: t.icon ?? LaunchPhaseTableTabs.iconForLabel(t.label),
          badge: t.badge,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LaunchTabRail(controller: _controller, specs: specs),
        const SizedBox(height: 16),
        SizedBox(
          height: bodyHeight,
          child: TabBarView(
            controller: _controller,
            children: [
              if (widget.overview != null) _buildBody(widget.overview!),
              for (final t in widget.tabs)
                _buildBody(widget.builders[t.label]!()),
            ],
          ),
        ),
      ],
    );
  }

  /// Each tab scrolls independently so a long table does not push the tab bar
  /// or the screen navigation off-screen.
  Widget _buildBody(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(alignment: Alignment.topCenter, child: child),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.icon, this.badge});
  final String label;
  final IconData icon;
  final String? badge;
}

/// Segmented tab rail for the Launch Phase screens.
///
/// Replaces the previous flat `#F4B422` slab. That treatment failed on three
/// counts: unselected labels sat at roughly 3.5:1 against the amber, the
/// active white pill was painted narrower than the label it sat under (so
/// "Post-Delivery Risks" spilled outside its own pill), and only the Overview
/// tab carried a glyph, which read as an unfinished control.
///
/// The rail is now a neutral, bordered surface that sits on the page rather
/// than shouting over it, with the brand yellow reserved for the *active*
/// state. Every tab gets a glyph, and the active pill is measured from the
/// tab's own box so it can never be narrower than its contents.
class _LaunchTabRail extends StatelessWidget {
  const _LaunchTabRail({required this.controller, required this.specs});

  final TabController controller;
  final List<_TabSpec> specs;

  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Track: a step quieter than the page so the rail reads as a container
    // without adding a heavy fill.
    final track = isDark ? const Color(0xFF161922) : const Color(0xFFF8FAFC);
    final trackBorder =
        isDark ? const Color(0xFF2D3139) : const Color(0xFFE5E7EB);

    final idle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    const activeInk = Color(0xFF111827);
    const brand = LightModeColors.lightPrimary;

    return Semantics(
      container: true,
      label: 'Section navigator',
      child: AnimatedBuilder(
        // Rebuild the rail on every index change so the per-tab badge
        // treatment follows selection.
        animation: controller,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: trackBorder),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // The indicator is what paints the active pill, so its size has to
            // come from the tab box itself. TabBar sizes it from the tab's
            // measured rect, which is why each tab below is given explicit
            // padding and an unbounded-safe Row: the label is always inside.
            indicator: BoxDecoration(
              color: brand,
              borderRadius: BorderRadius.circular(_radius - 4),
              boxShadow: [
                BoxShadow(
                  color: brand.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: activeInk,
            unselectedLabelColor: idle,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return activeInk.withValues(alpha: 0.07);
              }
              if (states.contains(WidgetState.hovered)) {
                return activeInk.withValues(alpha: 0.045);
              }
              return Colors.transparent;
            }),
            splashBorderRadius: BorderRadius.circular(_radius - 4),
            tabs: [
              for (var i = 0; i < specs.length; i++)
                // TabBar rebuilds this list, but the badge needs to know which
                // index is live; the controller is the single source of truth
                // and drives the rebuild through the AnimatedBuilder below.
                Builder(builder: (context) {
                  return Tab(
                    key: ValueKey<String>('launch-phase-tab-${specs[i].label}'),
                    height: 42,
                    child: Padding(
                      // Explicit horizontal padding keeps the painted indicator
                      // at least as wide as icon + gap + label + badge.
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _TabContent(
                        spec: specs[i],
                        selected: controller.index == i,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + label (+ optional badge) for one tab.
///
/// The label is wrapped in [FittedBox] with a downscale-only boxFit so a long
/// label on a narrow viewport shrinks instead of overflowing its pill.
class _TabContent extends StatelessWidget {
  const _TabContent({required this.spec, required this.selected});

  final _TabSpec spec;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(spec.icon, size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
        if (spec.badge != null) ...[
          const SizedBox(width: 8),
          _TabBadge(text: spec.badge!, selected: selected),
        ],
      ],
    );
  }
}

/// Small count/status chip shown on the right of a tab label.
class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF111827).withValues(alpha: 0.14)
            : const Color(0xFF111827).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? const Color(0xFF111827) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
