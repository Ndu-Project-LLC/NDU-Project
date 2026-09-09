import 'package:flutter/material.dart';

/// Inline fallback shown when a single Procurement section throws during
/// build. Instead of letting the framework's global ErrorWidget replace the
/// whole page ("Something went wrong — Bad state: No element"), the rest of
/// the screen stays usable and the failed section shows a compact retry card.
class ProcurementSectionErrorCard extends StatefulWidget {
  const ProcurementSectionErrorCard({
    super.key,
    required this.label,
    required this.message,
    required this.onRetry,
  });

  final String label;
  final String message;
  final Future<void> Function() onRetry;

  @override
  State<ProcurementSectionErrorCard> createState() =>
      _ProcurementSectionErrorCardState();
}

class _ProcurementSectionErrorCardState
    extends State<ProcurementSectionErrorCard> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB45309), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"${widget.label}" could not be displayed',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The rest of the page is still usable. Technical details: '
              '${widget.message}',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFA16207),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _retrying ? null : _handleRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF1F2937),
                ),
                icon: _retrying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1F2937),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: const Text('Retry section'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
