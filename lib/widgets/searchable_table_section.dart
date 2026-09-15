import 'package:flutter/material.dart';

/// A reusable section wrapper that adds:
/// 1. Search bar to filter table content
/// 2. Card ↔ Table view toggle
///
/// Usage: Wrap any table or list of items with [SearchableTableSection].
/// The caller provides:
/// - [title] / [subtitle] for the section header
/// - [tableBuilder] for the full table view
/// - [cardBuilder] for the card list view
/// - [items] + [searchFilter] for search filtering
/// - [totalCount] for the result count display
class SearchableTableSection extends StatefulWidget {
  const SearchableTableSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.tableBuilder,
    required this.cardBuilder,
    required this.items,
    required this.searchFilter,
    this.initialView = TableViewType.table,
    this.searchHint = 'Search...',
    this.headerActions,
  });

  final String title;
  final String? subtitle;
  final Widget Function(BuildContext context, String query) tableBuilder;
  final Widget Function(BuildContext context, String query) cardBuilder;
  final List<dynamic> items;
  final bool Function(dynamic item, String query) searchFilter;
  final TableViewType initialView;
  final String searchHint;
  final List<Widget>? headerActions;

  @override
  State<SearchableTableSection> createState() => _SearchableTableSectionState();
}

enum TableViewType { table, card }

class _SearchableTableSectionState extends State<SearchableTableSection> {
  final TextEditingController _searchController = TextEditingController();
  TableViewType _viewType = TableViewType.table;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _viewType = widget.initialView;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredItems {
    if (_query.isEmpty) return widget.items;
    return widget.items.where((item) => widget.searchFilter(item, _query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──
        _buildHeader(),
        const SizedBox(height: 14),
        // ── Toolbar: Search + View Toggle ──
        _buildToolbar(),
        const SizedBox(height: 16),
        // ── Content ──
        _viewType == TableViewType.table
            ? widget.tableBuilder(context, _query)
            : widget.cardBuilder(context, _query),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.headerActions != null) ...[
          const SizedBox(width: 12),
          ...widget.headerActions!,
        ],
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // ── Search Bar ──
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Result Count ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_filteredItems.length} ${_filteredItems.length == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── View Toggle ──
          _ViewToggle(
            currentView: _viewType,
            onChanged: (view) => setState(() => _viewType = view),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.currentView,
    required this.onChanged,
  });

  final TableViewType currentView;
  final ValueChanged<TableViewType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.table_chart_outlined,
            tooltip: 'Table view',
            isActive: currentView == TableViewType.table,
            onTap: () => onChanged(TableViewType.table),
            isFirst: true,
          ),
          Container(
            width: 1,
            height: 28,
            color: const Color(0xFFE5E7EB),
          ),
          _ToggleButton(
            icon: Icons.view_agenda_outlined,
            tooltip: 'Card view',
            isActive: currentView == TableViewType.card,
            onTap: () => onChanged(TableViewType.card),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(7) : Radius.zero,
          right: isLast ? const Radius.circular(7) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(7) : Radius.zero,
              right: isLast ? const Radius.circular(7) : Radius.zero,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
