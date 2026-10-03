import 'package:flutter/material.dart';

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
  const LaunchPhaseTableTab({required this.label, this.icon});

  /// Tab label. Doubles as the key in [LaunchPhaseTableTabs.builders].
  final String label;

  /// Optional leading glyph on the tab.
  final IconData? icon;
}

/// Widget factory for a tab body. Takes no arguments so a screen can pass a
/// bare tear-off of one of its existing `_buildXPanel()` methods.
typedef LaunchPhaseTabBuilder = Widget Function();

/// Tab host for the 11 Launch Phase screens.
///
/// Owns the [TabController] lifecycle and renders the yellow pill [TabBar]
/// that matches the rest of the Launch Phase surfaces (see
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
        _TabSpec(label: widget.overviewLabel, icon: widget.overviewIcon),
      for (final t in widget.tabs) _TabSpec(label: t.label, icon: t.icon),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LaunchTabBar(controller: _controller, specs: specs),
        const SizedBox(height: 12),
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
  const _TabSpec({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

/// Yellow pill tab bar matching the other Launch Phase surfaces.
class _LaunchTabBar extends StatelessWidget {
  const _LaunchTabBar({required this.controller, required this.specs});

  final TabController controller;
  final List<_TabSpec> specs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4B422),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF111827),
        unselectedLabelColor: const Color(0xFF6B4E00),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        dividerColor: Colors.transparent,
        tabs: [
          for (final spec in specs)
            Tab(
              key: ValueKey<String>('launch-phase-tab-${spec.label}'),
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (spec.icon != null) ...[
                    Icon(spec.icon, size: 16),
                    const SizedBox(width: 7),
                  ],
                  Text(spec.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}