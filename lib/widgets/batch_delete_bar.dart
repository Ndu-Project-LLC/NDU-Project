import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

/// A floating action bar that appears when items are selected for batch deletion.
/// Shows selected count and a "Delete Selected" button with confirmation dialog.
///
/// Usage:
/// ```dart
/// BatchDeleteBar(
///   selectedCount: _selectedIds.length,
///   onDelete: () async {
///     final deleted = await _batchDeleteSelected();
///     if (deleted) _selectedIds.clear();
///   },
///   onClear: () => setState(() => _selectedIds.clear()),
/// )
/// ```
class BatchDeleteBar extends StatelessWidget {
  const BatchDeleteBar({
    super.key,
    required this.selectedCount,
    required this.onDelete,
    required this.onClear,
    this.itemLabel = 'items',
    this.confirmTitle = 'Delete selected items?',
    this.backgroundColor,
  });

  /// Number of currently selected items
  final int selectedCount;

  /// Called when the user confirms batch deletion
  final Future<bool> Function() onDelete;

  /// Called when the user clears the selection
  final VoidCallback onClear;

  /// Label for the items being deleted (e.g. 'contracts', 'tasks')
  final String itemLabel;

  /// Custom confirmation dialog title
  final String confirmTitle;

  /// Background color override
  final Color? backgroundColor;

  bool get _hasSelection => selectedCount > 0;

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showBatchDeleteConfirmationDialog(
      context,
      count: selectedCount,
      itemLabel: itemLabel,
      title: confirmTitle,
    );
    if (!confirmed) return;
    final success = await onDelete();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $selectedCount $itemLabel'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: _hasSelection ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _hasSelection ? 1.0 : 0.0,
        child: _hasSelection
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: backgroundColor ?? const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$itemLabel selected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _handleDelete(context),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text(
                        'Delete Selected',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 16),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(28, 28),
                      ),
                      tooltip: 'Clear selection',
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Show a batch deletion confirmation dialog with item count.
Future<bool> showBatchDeleteConfirmationDialog(
  BuildContext context, {
  required int count,
  required String itemLabel,
  String? title,
}) async {
  return showDeleteConfirmationDialog(
    context,
    title: title ?? 'Delete selected $itemLabel?',
    message: 'Are you sure you want to delete $count $itemLabel? This action cannot be undone.',
    confirmLabel: count == 1 ? 'Delete' : 'Delete All ($count)',
  );
}
