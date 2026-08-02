import 'package:flutter/material.dart';

import 'package:ndu_project/utils/sidebar_accumulated_context.dart';

/// Banner shown at the top of every sidebar screen that participates in the
/// accumulated-context flow. Renders the real carried context (from prior
/// sidebar pages) inside a collapsible card so the user can see exactly what
/// data the current page inherited — and that nothing was hallucinated.
class CarriedContextBanner extends StatelessWidget {
  const CarriedContextBanner({
    super.key,
    required this.checkpoint,
    required this.contextText,
    this.compact = false,
  });

  /// The sidebar checkpoint this banner is shown on (used for the title).
  final String checkpoint;

  /// The accumulated context string (real data only — never hallucinated).
  final String contextText;

  /// When true, renders a single-line summary instead of the expandable
  /// card. Useful for very small screens.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (contextText.trim().isEmpty) return const SizedBox.shrink();

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 14, color: Color(0xFF005BB3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Inheriting real context from prior sidebar pages → '
                '${labelForCheckpoint(checkpoint)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        title: Row(
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 18, color: Color(0xFF005BB3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Carried context from prior sidebar pages → '
                '${labelForCheckpoint(checkpoint)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Real data only — no AI-generated content.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              contextText,
              style: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                height: 1.4,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small progress indicator shown while a sidebar screen is auto-populating
/// from real prior-phase data. Pairs visually with [CarriedContextBanner].
class AutoPopulatingIndicator extends StatelessWidget {
  const AutoPopulatingIndicator({
    super.key,
    this.message = 'Auto-populating from prior phases…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
