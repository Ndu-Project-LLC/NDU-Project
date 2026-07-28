import 'package:flutter/material.dart';
import 'package:ndu_project/models/page_hint_model.dart';
import 'package:ndu_project/services/hint_content_service.dart';
import 'package:ndu_project/services/hint_service.dart';

class PageHintDialog {
  /// Shows a hint dialog if policy allows it for [pageId].
  ///
  /// This also marks the page as viewed on first display.
  static Future<void> showIfNeeded({
    required BuildContext context,
    required String pageId,
    required String title,
    required String message,
  }) async {
    final PageHintConfig resolvedHint =
        await HintContentService.getResolvedHint(
      pageId: pageId,
      fallbackTitle: title,
      fallbackMessage: message,
    );
    if (!resolvedHint.enabled) return;

    final shouldShow = await HintService.shouldShowHint(pageId);
    if (!shouldShow) return;

    // Mark viewed immediately so it won't be treated as new again
    await HintService.markViewed(pageId);

    if (!context.mounted) return;

    final disableViewedInitially = await HintService.disableViewedHints();
    if (!context.mounted) return;

    bool disableViewed = disableViewedInitially;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            resolvedHint.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      resolvedHint.message,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Disable hints for pages I’ve viewed before.',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: disableViewed,
                            onChanged: (v) {
                              setLocal(() => disableViewed = v);
                              HintService.setDisableViewedHints(v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
