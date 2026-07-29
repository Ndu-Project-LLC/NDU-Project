import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/skip_confirmation_dialog.dart';

/// Shared navigation footer used across the Launch/Execution Phase pages.
///
/// Supports Back, Next, and Skip (Not Applicable) buttons with confirmation dialogs.
class LaunchPhaseNavigation extends StatelessWidget {
  const LaunchPhaseNavigation({
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
    this.nextEnabled = true,
    this.onSkip,
    this.skipLabel = 'Skip',
    this.pageTitle,
    super.key,
  });

  final String backLabel;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool nextEnabled;

  /// Optional callback when user wants to skip this page as "Not Applicable"
  final VoidCallback? onSkip;

  /// Label for the skip button
  final String skipLabel;

  /// Page title shown in the skip confirmation dialog
  final String? pageTitle;

  static const _kAccentColor = Color(0xFFFFC812);

  void _handleNextTap(BuildContext context) {
    if (!nextEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please check the acknowledgment box above before proceeding.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    showProceedWithoutReviewDialog(
      context,
      title: 'Proceed to ${nextLabel.replaceFirst('Next: ', '')}?',
    ).then((confirmed) {
      if (confirmed == true) onNext();
    });
  }

  void _handleSkipTap(BuildContext context) {
    final title = pageTitle ?? nextLabel.replaceFirst('Next: ', '');
    SkipConfirmationDialog.show(
      context,
      pageTitle: title,
    ).then((confirmed) {
      if (confirmed == true && onSkip != null) {
        onSkip!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSkip = onSkip != null;

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

    final skipButton = OutlinedButton.icon(
      onPressed: () => _handleSkipTap(context),
      icon: const Icon(Icons.skip_next, size: 18, color: Color(0xFF6B7280)),
      label: Text(
        skipLabel,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        backgroundColor:
            nextEnabled ? _kAccentColor : const Color(0xFFE5E7EB),
        foregroundColor:
            nextEnabled ? Colors.white : const Color(0xFF9CA3AF),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        
        // Build the right-side buttons (Skip + Next)
        final rightButtons = <Widget>[];
        if (hasSkip) {
          rightButtons.add(skipButton);
        }
        rightButtons.add(nextButton);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              backButton,
              if (hasSkip) ...[
                const SizedBox(height: 8),
                skipButton,
              ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSkip) ...[
                    skipButton,
                    const SizedBox(width: 12),
                  ],
                  nextButton,
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
