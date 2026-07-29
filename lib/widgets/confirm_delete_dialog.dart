import 'package:flutter/material.dart';

/// Reusable delete confirmation dialog for consistent UX across the app
/// 
/// Usage:
/// ```dart
/// final confirmed = await showDeleteConfirmation(
///   context: context,
///   itemName: 'Issue #123',
///   itemType: 'issue',
/// );
/// if (confirmed == true) {
///   // Perform deletion
/// }
/// ```
class ConfirmDeleteDialog extends StatelessWidget {
  final String itemName;
  final String itemType;
  final String? customMessage;
  final IconData icon;
  final Color? iconColor;
  
  const ConfirmDeleteDialog({
    super.key,
    required this.itemName,
    this.itemType = 'item',
    this.customMessage,
    this.icon = Icons.delete_outline,
    this.iconColor,
  });
  
  /// Show delete confirmation dialog and return true if user confirms
  static Future<bool> show({
    required BuildContext context,
    String itemName = '',
    String itemType = 'item',
    String? customMessage,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDeleteDialog(
        itemName: itemName,
        itemType: itemType,
        customMessage: customMessage,
        icon: isDangerous ? Icons.warning_amber_rounded : Icons.delete_outline,
        iconColor: isDangerous ? Colors.orange : null,
      ),
    );
    
    return result ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dangerColor = Colors.red.shade600;
    final displayIconColor = iconColor ?? dangerColor;
    
    // Build the message
    String message = customMessage ?? '';
    if (message.isEmpty) {
      if (itemName.isNotEmpty) {
        message = 'Are you sure you want to delete "$itemName"?\n\nThis action cannot be undone.';
      } else {
        message = 'Are you sure you want to delete this $itemType?\n\nThis action cannot be undone.';
      }
    }
    
    // Build title
    String title;
    if (itemName.isNotEmpty) {
      title = 'Delete $itemType?';
    } else {
      title = 'Delete ${itemType[0].toUpperCase()}${itemType.substring(1)}?';
    }
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: displayIconColor, size: 24),
          SizedBox(width: 12),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.8)),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        
        // Delete button
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 6),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Extension method for easier usage on VoidCallback onDelete handlers
extension DeleteConfirmation on BuildContext {
  /// Wraps an onDelete callback with confirmation dialog
  Future<void> confirmAndExecute({
    required VoidCallback onConfirm,
    String itemName = '',
    String itemType = 'item',
    String? customMessage,
  }) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: this,
      itemName: itemName,
      itemType: itemType,
      customMessage: customMessage,
    );
    
    if (confirmed == true && mounted) {
      onConfirm();
    }
  }
}

/// Widget wrapper for delete buttons with built-in confirmation
class ConfirmDeleteIconButton extends StatelessWidget {
  final VoidCallback onConfirmed;
  final String itemName;
  final String itemType;
  final String tooltip;
  final Color? color;
  final double size;
  
  const ConfirmDeleteIconButton({
    super.key,
    required this.onConfirmed,
    this.itemName = '',
    this.itemType = 'item',
    this.tooltip = 'Delete',
    this.color,
    this.size = 18,
  });
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showConfirmation(context),
      icon: Icon(Icons.delete_outline, size: size),
      color: color ?? Colors.red.shade600,
      splashRadius: 18,
      tooltip: tooltip,
    );
  }
  
  void _showConfirmation(BuildContext context) {
    ConfirmDeleteDialog.show(
      context: context,
      itemName: itemName,
      itemType: itemType,
    ).then((confirmed) {
      if (confirmed == true) {
        onConfirmed();
      }
    });
  }
}

/// SnackBar notification shown after successful deletion
void showDeletionSuccessSnackBar(BuildContext context, {String itemName = '', String itemType = 'item'}) {
  final message = itemName.isNotEmpty 
      ? '"$itemName" has been deleted' 
      : '$itemType deleted successfully';
      
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(message),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: () {
          // Can be extended with undo functionality
        },
      ),
    ),
  );
}
