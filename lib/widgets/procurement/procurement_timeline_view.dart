import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';

class ProcurementTimelineView extends StatefulWidget {
  const ProcurementTimelineView({
    super.key,
    required this.items,
    this.initialSelectedItemId,
    this.onItemTap,
  });

  final List<ProcurementItemModel> items;
  final String? initialSelectedItemId;
  final ValueChanged<ProcurementItemModel>? onItemTap;

  @override
  State<ProcurementTimelineView> createState() => _ProcurementTimelineViewState();
}

class _ProcurementTimelineViewState extends State<ProcurementTimelineView> {
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.initialSelectedItemId;
  }

  @override
  void didUpdateWidget(covariant ProcurementTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedItemId != oldWidget.initialSelectedItemId &&
        widget.initialSelectedItemId != null) {
      _selectedItemId = widget.initialSelectedItemId;
    }
    if (_selectedItemId != null &&
        widget.items.every((item) => item.id != _selectedItemId)) {
      _selectedItemId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.cast<ProcurementItemModel?>().firstWhere(
          (item) => item?.id == _selectedItemId,
          orElse: () => widget.items.isNotEmpty ? widget.items.first : null,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 960;
        if (isStacked) {
          return Column(
            children: [
              _TimelineList(
                items: widget.items,
                selectedItemId: selectedItem?.id,
                onItemTap: _handleItemTap,
              ),
              const SizedBox(height: 16),
              _TrackingTimelineCard(item: selectedItem),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimelineList(
                items: widget.items,
                selectedItemId: selectedItem?.id,
                onItemTap: _handleItemTap,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: _TrackingTimelineCard(item: selectedItem)),
          ],
        );
      },
    );
  }

  void _handleItemTap(ProcurementItemModel item) {
    setState(() => _selectedItemId = item.id);
    widget.onItemTap?.call(item);
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.items,
    required this.selectedItemId,
    required this.onItemTap,
  });

  final List<ProcurementItemModel> items;
  final String? selectedItemId;
  final ValueChanged<ProcurementItemModel> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _PanelFrame(
        child: Text(
          'No procurement items available for timeline tracking yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
        ),
      );
    }

    final sorted = [...items]
      ..sort((a, b) {
        final aDate = a.requiredByDate ?? a.estimatedDelivery ?? a.updatedAt;
        final bDate = b.requiredByDate ?? b.estimatedDelivery ?? b.updatedAt;
        return aDate.compareTo(bDate);
      });

    return _PanelFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracked Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length; i++) ...[
            _TimelineListRow(
              item: sorted[i],
              selected: sorted[i].id == selectedItemId,
              onTap: () => onItemTap(sorted[i]),
            ),
            if (i != sorted.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TimelineListRow extends StatelessWidget {
  const _TimelineListRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ProcurementItemModel item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastUpdateLabel = DateFormat('MMM dd, yyyy').format(item.updatedAt);
    final targetDate = item.requiredByDate ?? item.estimatedDelivery;
    final targetLabel = targetDate != null
        ? DateFormat('MMM dd, yyyy').format(targetDate)
        : 'Not scheduled';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _BadgePill(
                  label: item.status.label,
                  background: item.status.backgroundColor,
                  border: item.status.borderColor,
                  foreground: item.status.textColor,
                ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label: item.priority.label,
                ),
                _InfoChip(
                  icon: Icons.schedule_outlined,
                  label: targetLabel,
                ),
                _InfoChip(
                  icon: Icons.update_outlined,
                  label: 'Updated $lastUpdateLabel',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingTimelineCard extends StatelessWidget {
  const _TrackingTimelineCard({required this.item});

  final ProcurementItemModel? item;

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      child: item == null
          ? const Center(
              child: Text(
                'Select an item to view its procurement timeline.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item!.requiredByDate != null
                      ? 'Required by ${DateFormat('MMM dd, yyyy').format(item!.requiredByDate!)}'
                      : 'No required-by date linked yet.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),
                _BadgePill(
                  label: item!.status.label,
                  background: item!.status.backgroundColor,
                  border: item!.status.borderColor,
                  foreground: item!.status.textColor,
                ),
                const SizedBox(height: 18),
                if (item!.events.isEmpty)
                  const Text(
                    'No timeline events recorded yet.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  )
                else
                  for (var i = 0; i < item!.events.length; i++) ...[
                    _TimelineEntry(event: item!.events[i]),
                    if (i != item!.events.length - 1) const SizedBox(height: 16),
                  ],
              ],
            ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event});

  final ProcurementEvent event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM dd, yyyy').format(event.date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            size: 18,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                event.description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              if (event.subtext.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  event.subtext,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: child,
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}
