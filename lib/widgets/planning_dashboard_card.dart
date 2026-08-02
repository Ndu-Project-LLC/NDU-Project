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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                        tooltip: canUndo ? 'Undo last delete' : 'Nothing to undo',
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome,
                                color: Color(0xFF7C3AED)), // Purple accent
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
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemRow(context, item);
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
  }

  Widget _buildItemRow(BuildContext context, PlanningDashboardItem item) {
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
          // Icon based on context (hard to guess, generic dot for now)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.isAiGenerated
                    ? const Color(0xFF8B5CF6) // Purple for AI
                    : const Color(0xFF10B981), // Green for Manual
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
          // Actions
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
                      size: 16, color: Color(0xFFEF4444)), // Red close
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
