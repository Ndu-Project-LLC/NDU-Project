import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';

class PlanningDashboardCard extends StatelessWidget {
  final String title;
  final String description;
  final List<PlanningDashboardItem> items;
  final VoidCallback? onAdd;
  final Function(PlanningDashboardItem)? onEdit;
  final Function(PlanningDashboardItem)? onDelete;
  final VoidCallback? onUndo;
  final bool canUndo;
  final VoidCallback? onGenerateAI;
  final bool isGenerating;
  final String emptyStateText;
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Stable key for this section — used as the DragTarget payload
  /// identifier so items dragged from other sections can be routed
  /// to the correct list.
  final String? sectionKey;

  /// Called when an item is dropped onto this card from another section.
  final void Function(String itemId, String sourceSectionKey)? onItemReceived;

  const PlanningDashboardCard({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onUndo,
    this.canUndo = false,
    this.onGenerateAI,
    this.isGenerating = false,
    this.emptyStateText = 'No items yet. Add manually or generate with AI.',
    this.onReorder,
    this.sectionKey,
    this.onItemReceived,
  });

  /// Payload string for cross-section drag. Format: `sectionKey::itemId`
  String _dragPayload(PlanningDashboardItem item) =>
      '${sectionKey ?? title}::${item.id}';

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onUndo != null || onGenerateAI != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onUndo != null)
                      IconButton(
                        onPressed: canUndo ? onUndo : null,
                        tooltip:
                            canUndo ? 'Undo last delete' : 'Nothing to undo',
                        icon: const Icon(
                          Icons.undo_rounded,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    if (onGenerateAI != null)
                      IconButton(
                        onPressed: isGenerating ? null : onGenerateAI,
                        tooltip: 'Generate with AI',
                        icon: isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome,
                                color: Color(0xFFB8860B)),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),

          // Items List
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  emptyStateText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (onReorder != null)
            ReorderableListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: onReorder!,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final elevation = Tween<double>(begin: 0, end: 6)
                        .animate(animation)
                        .value;
                    return Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(
                      '${title}_item_${index}_${item.description.hashCode}'),
                  index: index,
                  child: _wrapWithCrossSectionDrag(
                    context,
                    item,
                    _buildItemRow(context, item, showDragHandle: true),
                  ),
                );
              },
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _wrapWithCrossSectionDrag(
                  context,
                  item,
                  _buildItemRow(context, item),
                );
              },
            ),

          const SizedBox(height: 16),

          // Add Button
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFD1D5DB), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF4B5563)),
                    SizedBox(width: 8),
                    Text(
                      'Add Item',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    // Wrap with DragTarget when sectionKey is provided
    if (sectionKey != null && onItemReceived != null) {
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final payload = details.data;
          if (!payload.contains('::')) return false;
          final sourceSection = payload.split('::').first;
          return sourceSection != sectionKey;
        },
        onAcceptWithDetails: (details) {
          final payload = details.data;
          final parts = payload.split('::');
          if (parts.length >= 2) {
            onItemReceived!(parts[1], parts[0]);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHovering
                  ? Border.all(color: const Color(0xFFF59E0B), width: 2)
                  : null,
            ),
            child: card,
          );
        },
      );
    }

    return card;
  }

  Widget _wrapWithCrossSectionDrag(
      BuildContext context, PlanningDashboardItem item, Widget child) {
    if (sectionKey == null) return child;
    return LongPressDraggable<String>(
      data: _dragPayload(item),
      delay: const Duration(milliseconds: 250),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Opacity(
            opacity: 0.92,
            child: _buildItemRow(context, item, showDragHandle: false),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: child,
      ),
      child: child,
    );
  }

  Widget _buildItemRow(BuildContext context, PlanningDashboardItem item,
      {bool showDragHandle = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDragHandle) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.isAiGenerated
                    ? const Color(0xFFB8860B)
                    : const Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty)
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                if (item.title.isNotEmpty) const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () => onEdit!(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit',
                ),
              const SizedBox(width: 8),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: Color(0xFFEF4444)),
                  onPressed: () => onDelete!(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
