import 'package:flutter/material.dart';

/// One section of an Execution Phase page, shown as a tab.
class SectionTab {
  const SectionTab({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

/// Tab navigation for Execution Phase pages whose sections used to be stacked.
///
/// Only the selected section is built, so it works inside a page's outer
/// scroll view without a fixed height. The strip matches the Punchlist
/// Overview tabs.
class ExecutionSectionTabs extends StatefulWidget {
  const ExecutionSectionTabs({super.key, required this.tabs});

  final List<SectionTab> tabs;

  @override
  State<ExecutionSectionTabs> createState() => _ExecutionSectionTabsState();
}

class _ExecutionSectionTabsState extends State<ExecutionSectionTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.tabs.length, vsync: this);
    _controller.addListener(() {
      if (!_controller.indexIsChanging) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ExecutionSectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      final int previous = _controller.index;
      _controller.dispose();
      _controller = TabController(
        length: widget.tabs.length,
        vsync: this,
        initialIndex:
            previous < widget.tabs.length ? previous : widget.tabs.length - 1,
      );
      _controller.addListener(() {
        if (!_controller.indexIsChanging) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int selected = _controller.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF111827),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            indicator: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFC812)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [for (final tab in widget.tabs) Tab(text: tab.label)],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.tabs.isNotEmpty) widget.tabs[selected].builder(context),
      ],
    );
  }
}
