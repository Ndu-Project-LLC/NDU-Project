import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';
import 'package:ndu_project/models/procurement_log.dart';
import 'package:ndu_project/widgets/procurement/procurement_common_widgets.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

/// Which way the procurement log is read: the table (default) or the cards.
///
/// Lusaka 27: "this procurement table now [can] be called a procurement log …
/// the table makes sense". The table is the log — numbered rows, expandable to
/// full screen — and the cards stay as the secondary view.
enum ProcurementLogView { table, card }

class ProcurementItemsListView extends StatefulWidget {
  const ProcurementItemsListView({
    super.key,
    required this.items,
    required this.trackableItems,
    required this.selectedIndex,
    required this.onSelectTrackable,
    required this.currencyFormat,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onSearchChanged,
    this.onCategoryChanged,
    this.onStatusChanged,
    this.categoryOptions = const <String>['All Categories'],
    this.statusOptions = const <String>['All Statuses'],
    this.selectedCategory = 'All Categories',
    this.selectedStatus = 'All Statuses',
    this.onPullToWbsCost,
    this.initialView = ProcurementLogView.table,
    this.vendorNames = const <String, String>{},
  });

  /// Which view the log opens in. The table is the log; the cards are the
  /// secondary view.
  final ProcurementLogView initialView;

  /// Vendor id → vendor name, so the log's Vendor column can show a name even
  /// though an item only stores an id.
  final Map<String, String> vendorNames;

  final List<ProcurementItemModel> items;
  final List<ProcurementItemModel> trackableItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectTrackable;
  final NumberFormat currencyFormat;
  final VoidCallback onAddItem;
  final ValueChanged<ProcurementItemModel> onEditItem;
  final ValueChanged<ProcurementItemModel> onDeleteItem;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onCategoryChanged;
  final ValueChanged<String>? onStatusChanged;
  final List<String> categoryOptions;
  final List<String> statusOptions;
  final String selectedCategory;
  final String selectedStatus;
  final ValueChanged<ProcurementItemModel>? onPullToWbsCost;

  @override
  State<ProcurementItemsListView> createState() =>
      _ProcurementItemsListViewState();
}

class _ProcurementItemsListViewState extends State<ProcurementItemsListView> {
  late ProcurementLogView _view = widget.initialView;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final trackableItems = widget.trackableItems;
    final selectedIndex = widget.selectedIndex;
    final totalItems = items.length;
    final criticalItems = items
        .where((item) => item.priority == ProcurementPriority.critical)
        .length;
    final pendingApprovals = items
        .where((item) =>
            item.status == ProcurementItemStatus.vendorSelection &&
            item.priority == ProcurementPriority.critical)
        .length;
    final totalBudget =
        items.fold<int>(0, (value, item) => value + item.budget.toInt());
    final selectedTrackable =
        (selectedIndex >= 0 && selectedIndex < trackableItems.length)
            ? trackableItems[selectedIndex]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryMetricsRow(
          totalItems: totalItems,
          criticalItems: criticalItems,
          pendingApprovals: pendingApprovals,
          totalBudgetLabel: widget.currencyFormat.format(totalBudget),
        ),
        const SizedBox(height: 24),
        _ItemsToolbar(
          onAddItem: widget.onAddItem,
          onSearchChanged: widget.onSearchChanged,
          onCategoryChanged: widget.onCategoryChanged,
          onStatusChanged: widget.onStatusChanged,
          categoryOptions: widget.categoryOptions,
          statusOptions: widget.statusOptions,
          selectedCategory: widget.selectedCategory,
          selectedStatus: widget.selectedStatus,
          view: _view,
          onViewChanged: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: 20),
        if (_view == ProcurementLogView.table)
          _ProcurementLogTable(
            items: widget.items,
            vendorNames: widget.vendorNames,
            onAddItem: widget.onAddItem,
            onEditItem: widget.onEditItem,
            onDeleteItem: widget.onDeleteItem,
          )
        else
          _ItemsGrid(
            items: widget.items,
            currencyFormat: widget.currencyFormat,
            onAddItem: widget.onAddItem,
            onEditItem: widget.onEditItem,
            onDeleteItem: widget.onDeleteItem,
            onPullToWbsCost: widget.onPullToWbsCost,
          ),
        const SizedBox(height: 28),
        _TrackableAndTimeline(
          trackableItems: widget.trackableItems,
          selectedIndex: widget.selectedIndex,
          onSelectTrackable: widget.onSelectTrackable,
          selectedItem: selectedTrackable,
        ),
      ],
    );
  }
}

/// The procurement log itself: numbered rows, the item, its category, priority,
/// whether it is long lead, what it costs, when it lands, who is supplying it
/// and where it is in the process.
class _ProcurementLogTable extends StatelessWidget {
  const _ProcurementLogTable({
    required this.items,
    required this.vendorNames,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<ProcurementItemModel> items;
  final Map<String, String> vendorNames;
  final VoidCallback onAddItem;
  final ValueChanged<ProcurementItemModel> onEditItem;
  final ValueChanged<ProcurementItemModel> onDeleteItem;

  List<ProcurementLogRow> get _rows => <ProcurementLogRow>[
        for (var i = 0; i < items.length; i++)
          ProcurementLogRow.fromItem(
            items[i],
            number: i + 1,
            vendorName: vendorNames[items[i].vendorId ?? ''] ?? '',
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) {
      return ProcurementEmptyStateCard(
        icon: Icons.inventory_2_outlined,
        title: 'No procurement items yet',
        message:
            'Add the items you plan to buy — equipment, long-lead purchases, '
            'and everything else on the bill.',
        actionLabel: 'Add Item',
        onAction: onAddItem,
      );
    }
    return buildNduTableWithExpand(
      context: context,
      title: 'Procurement Log',
      minWidth: 1560,
      columnSpacing: 16,
      columns: <DataColumn>[
        for (final column in procurementLogColumns)
          DataColumn(label: Text(column.label)),
        const DataColumn(label: Text('')),
      ],
      rows: <DataRow>[
        for (var i = 0; i < rows.length; i++)
          DataRow(cells: <DataCell>[
            for (final column in procurementLogColumns)
              DataCell(_cell(context, column.key, rows[i])),
            DataCell(_actions(items[i])),
          ]),
      ],
    );
  }

  Widget _actions(ProcurementItemModel item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => onEditItem(item),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB45309),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
          child: const Text('Edit', style: TextStyle(fontSize: 12)),
        ),
        IconButton(
          onPressed: () => onDeleteItem(item),
          tooltip: 'Delete item',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline,
              color: Color(0xFFDC2626)),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, String key, ProcurementLogRow row) {
    final value = row.valueFor(key);
    switch (key) {
      case 'item':
        return WrappedText(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600));
      case 'longLead':
        if (!row.longLead) return const Text('No');
        return const _BadgePill(
          label: 'Long lead',
          background: Color(0xFFFFF7ED),
          foreground: Color(0xFFC2410C),
        );
      case 'priority':
        return _BadgePill(
          label: value,
          background: const Color(0xFFF1F5F9),
          foreground: const Color(0xFF334155),
        );
      case 'status':
        return _BadgePill(
          label: value,
          background: const Color(0xFFFFF8E1),
          foreground: const Color(0xFF92400E),
        );
      case 'number':
        return Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B)));
      case 'budget':
        return Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857)));
      default:
        return WrappedText(value, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
  }
}

class _SummaryMetricsRow extends StatelessWidget {
  const _SummaryMetricsRow({
    required this.totalItems,
    required this.criticalItems,
    required this.pendingApprovals,
    required this.totalBudgetLabel,
  });

  final int totalItems;
  final int criticalItems;
  final int pendingApprovals;
  final String totalBudgetLabel;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final cards = [
      ProcurementSummaryCard(
        icon: Icons.inventory_2_outlined,
        iconBackground: const Color(0xFFFFF8E1),
        value: '$totalItems',
        label: 'Total Items',
      ),
      ProcurementSummaryCard(
        icon: Icons.warning_amber_rounded,
        iconBackground: const Color(0xFFFFF7ED),
        value: '$criticalItems',
        label: 'Critical Items',
        valueColor: const Color(0xFFDC2626),
      ),
      ProcurementSummaryCard(
        icon: Icons.access_time,
        iconBackground: const Color(0xFFFFF8E1),
        value: '$pendingApprovals',
        label: 'Pending Approvals',
        valueColor: const Color(0xFF1F2937),
      ),
      ProcurementSummaryCard(
        icon: Icons.attach_money,
        iconBackground: const Color(0xFFFFF8E1),
        value: totalBudgetLabel,
        label: 'Total Budget',
        valueColor: const Color(0xFF047857),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
          const SizedBox(height: 12),
          cards[3],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _ItemsToolbar extends StatelessWidget {
  const _ItemsToolbar({
    required this.onAddItem,
    this.onSearchChanged,
    this.onCategoryChanged,
    this.onStatusChanged,
    required this.categoryOptions,
    required this.statusOptions,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.view,
    required this.onViewChanged,
  });

  final VoidCallback onAddItem;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onCategoryChanged;
  final ValueChanged<String>? onStatusChanged;
  final List<String> categoryOptions;
  final List<String> statusOptions;
  final String selectedCategory;
  final String selectedStatus;
  final ProcurementLogView view;
  final ValueChanged<ProcurementLogView> onViewChanged;

  /// A control only earns its place when it does something: the owner's note on
  /// this section was "if you have an overview then you can remove the search
  /// [section]", and the screen used to render a search box with no handler
  /// behind it.
  bool get _hasSearch => onSearchChanged != null;
  bool get _hasCategoryFilter =>
      onCategoryChanged != null && categoryOptions.length > 1;
  bool get _hasStatusFilter =>
      onStatusChanged != null && statusOptions.length > 1;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final toggle = _LogViewToggle(view: view, onChanged: onViewChanged);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasSearch) ...[
            _SearchField(onChanged: onSearchChanged),
            const SizedBox(height: 12),
          ],
          if (_hasCategoryFilter || _hasStatusFilter) ...[
            Row(
              children: [
                if (_hasCategoryFilter)
                  Expanded(
                    child: _DropdownField(
                      label: selectedCategory,
                      options: categoryOptions,
                      onChanged: onCategoryChanged,
                    ),
                  ),
                if (_hasCategoryFilter && _hasStatusFilter)
                  const SizedBox(width: 12),
                if (_hasStatusFilter)
                  Expanded(
                    child: _DropdownField(
                      label: selectedStatus,
                      options: statusOptions,
                      onChanged: onStatusChanged,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              toggle,
              const Spacer(),
              _AddItemButton(onPressed: onAddItem),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        if (_hasSearch) ...[
          SizedBox(
            width: 320,
            child: _SearchField(onChanged: onSearchChanged),
          ),
          const SizedBox(width: 16),
        ],
        if (_hasCategoryFilter) ...[
          SizedBox(
            width: 190,
            child: _DropdownField(
              label: selectedCategory,
              options: categoryOptions,
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(width: 16),
        ],
        if (_hasStatusFilter) ...[
          SizedBox(
            width: 190,
            child: _DropdownField(
              label: selectedStatus,
              options: statusOptions,
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 16),
        ],
        const Spacer(),
        toggle,
        const SizedBox(width: 12),
        _AddItemButton(onPressed: onAddItem),
      ],
    );
  }
}

/// Table (the log) / card toggle.
class _LogViewToggle extends StatelessWidget {
  const _LogViewToggle({required this.view, required this.onChanged});

  final ProcurementLogView view;
  final ValueChanged<ProcurementLogView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.table_chart_outlined,
            tooltip: 'Log view',
            isActive: view == ProcurementLogView.table,
            onTap: () => onChanged(ProcurementLogView.table),
          ),
          Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
          _ToggleButton(
            icon: Icons.view_agenda_outlined,
            tooltip: 'Card view',
            isActive: view == ProcurementLogView.card,
            onTap: () => onChanged(ProcurementLogView.card),
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
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF8E1) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? const Color(0xFF92400E)
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VoiceTextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Color(0xFF94A3B8)),
          hintText: 'Search items...',
          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.options,
    this.onChanged,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: label,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B)),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF334155))),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged?.call(value);
          },
        ),
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC812),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: const Icon(Icons.add_rounded),
      label:
          const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ItemsGrid extends StatelessWidget {
  const _ItemsGrid({
    required this.items,
    required this.currencyFormat,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onPullToWbsCost,
  });

  final List<ProcurementItemModel> items;
  final NumberFormat currencyFormat;
  final VoidCallback onAddItem;
  final ValueChanged<ProcurementItemModel> onEditItem;
  final ValueChanged<ProcurementItemModel> onDeleteItem;
  final ValueChanged<ProcurementItemModel>? onPullToWbsCost;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ProcurementEmptyStateCard(
        icon: Icons.inventory_2_outlined,
        title: 'No procurement items yet',
        message:
            'Add items to track budgets, approvals, and delivery timelines.',
        actionLabel: 'Add Item',
        onAction: onAddItem,
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final double width = constraints.maxWidth;
      int columns = 1;
      if (width > 1200) {
        columns = 3;
      } else if (width > 800) {
        columns = 2;
      }

      final double cardWidth = (width - ((columns - 1) * 24)) / columns;

      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: List<Widget>.generate(items.length, (index) {
          final item = items[index];
          return SizedBox(
            width: cardWidth,
            child: _ProcurementItemCard(
              item: item,
              itemNumberLabel: 'ITM-${(index + 1).toString().padLeft(3, '0')}',
              currencyFormat: currencyFormat,
              onEdit: () => onEditItem(item),
              onDelete: () => onDeleteItem(item),
              onPullToWbsCost: onPullToWbsCost == null
                  ? null
                  : () => onPullToWbsCost!(item),
            ),
          );
        }),
      );
    });
  }
}

class _ProcurementItemCard extends StatelessWidget {
  const _ProcurementItemCard({
    required this.item,
    required this.itemNumberLabel,
    required this.currencyFormat,
    required this.onEdit,
    required this.onDelete,
    this.onPullToWbsCost,
  });

  final ProcurementItemModel item;
  final String itemNumberLabel;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPullToWbsCost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BadgePill(label: itemNumberLabel),
                        const SizedBox(width: 4),
                        _BadgePill(label: item.status.label),
                      ],
                    ),
                  ],
                ),
              ),
              _ActionIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              const SizedBox(width: 4),
              if (onPullToWbsCost != null) ...[
                _ActionIcon(
                  icon: Icons.account_tree_outlined,
                  tooltip: 'Pull to WBS and Cost',
                  onTap: onPullToWbsCost!,
                ),
                const SizedBox(width: 4),
              ],
              _ActionIcon(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricItem(
                label: 'Category',
                value: item.category,
              ),
              const SizedBox(width: 16),
              _MetricItem(
                label: 'Priority',
                value: item.priority.label,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricItem(
                label: 'Budget',
                value: currencyFormat.format(item.budget),
              ),
              const SizedBox(width: 16),
              _MetricItem(
                label: 'Spent',
                value: currencyFormat.format(item.spent),
              ),
            ],
          ),
          if (item.responsibleMember.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetricItem(
              label: 'Responsible',
              value: item.responsibleMember.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937)),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    this.background = const Color(0xFFF1F5F9),
    this.foreground = const Color(0xFF64748B),
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: foreground),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class _TrackableAndTimeline extends StatelessWidget {
  const _TrackableAndTimeline({
    required this.trackableItems,
    required this.selectedIndex,
    required this.onSelectTrackable,
    required this.selectedItem,
  });

  final List<ProcurementItemModel> trackableItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectTrackable;
  final ProcurementItemModel? selectedItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrackableItemsCard(
          trackableItems: trackableItems,
          selectedIndex: selectedIndex,
          onSelectTrackable: onSelectTrackable,
        ),
        if (selectedItem != null) ...[
          const SizedBox(height: 20),
          _TrackingTimelineCard(item: selectedItem!),
        ],
      ],
    );
  }
}

class _TrackableItemsCard extends StatelessWidget {
  const _TrackableItemsCard({
    required this.trackableItems,
    required this.selectedIndex,
    required this.onSelectTrackable,
  });

  final List<ProcurementItemModel> trackableItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectTrackable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracked Items',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          if (trackableItems.isEmpty)
            const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'No trackable items yet. Mark items as trackable to monitor progress.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trackableItems.length,
              itemBuilder: (context, index) {
                final item = trackableItems[index];
                return RepaintBoundary(
                  key: ValueKey('trackable_item_$index'),
                  child: _TrackableRow(
                    item: item,
                    index: index,
                    isSelected: index == selectedIndex,
                    onTap: () => onSelectTrackable(index),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TrackableRow extends StatelessWidget {
  const _TrackableRow({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final ProcurementItemModel item;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8E1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFC812)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(item.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingTimelineCard extends StatelessWidget {
  const _TrackingTimelineCard({required this.item});

  final ProcurementItemModel item;

  @override
  Widget build(BuildContext context) {
    final events = item.events;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline: ${item.name}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'No timeline events for this item.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return RepaintBoundary(
                  key: ValueKey('timeline_event_$index'),
                  child: _TimelineEntry(
                      event: event, isLast: index == events.length - 1),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event, required this.isLast});

  final ProcurementEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    switch (event.status) {
      case 'completed':
        dotColor = const Color(0xFF10B981);
      case 'pending':
        dotColor = const Color(0xFFF97316);
      case 'issue':
        dotColor = const Color(0xFFDC2626);
      default:
        dotColor = const Color(0xFF94A3B8);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.subtext} \u00b7 ${DateFormat('MMM dd, yyyy').format(event.date)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
