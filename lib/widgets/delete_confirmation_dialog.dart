import 'package:flutter/material.dart';

Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required String title,
  String? itemLabel,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final trimmedLabel = itemLabel?.trim() ?? '';
  final resolvedMessage = message ??
      (trimmedLabel.isEmpty
          ? 'This action cannot be undone.'
          : 'Delete "$trimmedLabel"? This action cannot be undone.');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        resolvedMessage,
        style: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF4B5563),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4B5563),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
