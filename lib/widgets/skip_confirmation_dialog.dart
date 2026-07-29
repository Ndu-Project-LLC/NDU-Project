import 'package:flutter/material.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

/// A confirmation dialog shown when user wants to skip a page as "Not Applicable".
///
/// This ensures users intentionally mark pages as N/A rather than accidentally
/// skipping important planning steps.
class SkipConfirmationDialog extends StatelessWidget {
  const SkipConfirmationDialog({
    super.key,
    required this.pageTitle,
    this.onConfirmed,
    this.onCancelled,
  });

  /// The title of the page being skipped
  final String pageTitle;

  /// Called when user confirms the skip
  final VoidCallback? onConfirmed;

  /// Called when user cancels the skip
  final VoidCallback? onCancelled;

  /// Shows the skip confirmation dialog and returns true if user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String pageTitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SkipConfirmationDialog(pageTitle: pageTitle),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.skip_next_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Skip "$pageTitle"?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This page will be marked as "Not Applicable". '
                    'You can always return later to complete it if needed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StatefulBuilder(
            builder: (context, setDialogState) {
              bool dontAskAgain = false;
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: dontAskAgain,
                onChanged: (value) {
                  dontAskAgain = value ?? false;
                  setDialogState(() {});
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Don\'t ask again for skipped pages',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onCancelled?.call();
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            // Save skip preference if needed
            onConfirmed?.call();
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          icon: const Icon(Icons.skip_next, size: 16),
          label: const Text(
            'Confirm Skip',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirmed?.call();
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC812),
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Skip & Continue'),
        ),
      ],
    );
  }
}
