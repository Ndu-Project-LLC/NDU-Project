import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';

/// Shared navigation footer used across the Launch Phase pages.
class LaunchPhaseNavigation extends StatelessWidget {
  const LaunchPhaseNavigation({
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
    this.nextEnabled = true,
    super.key,
  });

  final String backLabel;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool nextEnabled;

  static const _kAccentColor = Color(0xFFFFC812);

  Future<void> _handleNextTap(BuildContext context) async {
    if (!nextEnabled) {
      final continueAnyway = await showProceedWithoutReviewDialog(
        context,
        title: 'Please confirm you have reviewed and understood this step',
        message:
            'You have not confirmed this page yet. You can continue now and return to update missing information later, or stay and complete it now.',
      );
      if (!continueAnyway) return;
    }
    onNext();
  }

  @override
  Widget build(BuildContext context) {
    final backButton = OutlinedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back, size: 18, color: _kAccentColor),
      label: Text(
        backLabel,
        overflow: TextOverflow.ellipsis,
        style:
            const TextStyle(fontWeight: FontWeight.w600, color: _kAccentColor),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _kAccentColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final nextButton = ElevatedButton.icon(
      onPressed: () {
        _handleNextTap(context);
      },
      icon: const Icon(Icons.arrow_forward, size: 18),
      label: Text(
        nextLabel,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kAccentColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              backButton,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: nextButton),
            ],
          );
        }

        return Padding(
          // Right padding prevents the Next button from overlapping with
          // the KAZ AI chat bubble (positioned at bottom-right ~64px wide).
          padding: const EdgeInsets.only(right: 72),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              backButton,
              nextButton,
            ],
          ),
        );
      },
    );
  }
}
