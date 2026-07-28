import 'package:flutter/material.dart';

/// Reusable page-level "Regenerate All" button widget
/// Should be placed in the header/top section of AI-enabled pages
class PageRegenerateAllButton extends StatelessWidget {
  const PageRegenerateAllButton({
    super.key,
    required this.onRegenerateAll,
    this.isLoading = false,
    this.tooltip = 'Regenerate all AI content on this page',
  });

  final VoidCallback onRegenerateAll;
  final bool isLoading;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF2563EB),
              ),
            )
          : const Icon(Icons.refresh, size: 20, color: Color(0xFF2563EB)),
      tooltip: tooltip,
      onPressed: isLoading ? null : () => onRegenerateAll(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

/// Helper function to show confirmation dialog before regenerating
Future<bool> showRegenerateAllConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Regenerate All Content'),
      content: const Text(
        'This will regenerate all KAZ AI-generated content on this page. Your current content will be lost. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Regenerate All'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
