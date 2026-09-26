import 'package:flutter/material.dart';

import 'package:ndu_project/utils/sidebar_accumulated_context.dart';

/// Banner shown at the top of every sidebar screen that participates in the
/// accumulated-context flow. Renders the real carried context (from prior
/// sidebar pages) inside a collapsible card so the user can see exactly what
/// data the current page inherited — and that nothing was hallucinated.
///
/// NOTE: This widget deliberately avoids [ExpansionTile]. [ExpansionTile]
/// uses [MergeableMaterial] internally, which can trigger
/// `mouse_tracker.dart` and `box.dart` assertion failures when nested
/// inside a decorated [Container] within a scroll view. Instead we use a
/// lightweight [StatefulWidget] with [AnimatedCrossFade] for the
/// expand/collapse animation.
class CarriedContextBanner extends StatefulWidget {
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
  State<CarriedContextBanner> createState() => _CarriedContextBannerState();
}

class _CarriedContextBannerState extends State<CarriedContextBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.contextText.trim().isEmpty) return const SizedBox.shrink();

    if (widget.compact) {
      return _buildCompact();
    }
    return _buildExpandable();
  }

  Widget _buildCompact() {
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
              size: 14, color: Color(0xFFFFC812)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Inheriting real context from prior sidebar pages → '
              '${labelForCheckpoint(widget.checkpoint)}',
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

  Widget _buildExpandable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row — tappable to toggle expansion.
          InkWell(
            onTap: () {
              if (mounted) setState(() => _expanded = !_expanded);
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 18, color: Color(0xFFFFC812)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Carried context from prior sidebar pages → '
                          '${labelForCheckpoint(widget.checkpoint)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Real data only — no AI-generated content.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content — uses AnimatedCrossFade to avoid
          // MergeableMaterial (ExpansionTile) which can cause assertion
          // failures in scroll views.
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildContextContent(),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }

  Widget _buildContextContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
          widget.contextText,
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 11,
            height: 1.4,
            color: Color(0xFF374151),
          ),
        ),
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
