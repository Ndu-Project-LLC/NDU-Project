import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:ndu_project/theme.dart' show appFontFamily;

/// Build-time error boundary for one section of a page.
///
/// A page is assembled from many independent sections (registers, panels,
/// matrices, notes). If one of them throws while building, the framework's
/// `ErrorWidget` takes over that part of the tree — and with the app-wide
/// policy silently hiding framework noise, or a layout failure poisoning the
/// render subtree, the user is left looking at a page whose body is simply
/// empty while the shell (sidebar + header) still draws. That looks like a
/// broken app, and the failure is invisible.
///
/// [SafeSection] contains the blast radius: the failing section renders
/// [SectionErrorCard] — a compact banner naming what failed — and every other
/// section on the page keeps rendering. The failure is also printed, so the
/// console is never silent about it.
///
/// This mirrors the pattern already used by the risk, solutions and procurement
/// screens; it is the shared version of it so the Design Phase pages can use
/// it without importing another screen.
///
/// Scope, deliberately: this guards the section's *construction* — the inline
/// `_buildStableXxx()` / `_buildWebXxx()` helper that walks project data and
/// assembles the subtree, which is where these pages do their work and where
/// they actually throw. An exception raised later, by a nested widget's own
/// `build` or during layout, runs in that widget's element and cannot be caught
/// here; the app-wide policy (`lib/utils/error_widget_policy.dart`) is what
/// makes those visible instead of blank, and the layout guards in
/// `test/design_phase_pages_render_test.dart` cover them.
class SafeSection extends StatelessWidget {
  const SafeSection({
    super.key,
    required this.title,
    required this.builder,
  });

  /// Human-readable name of the section, used in the failure card and the log.
  final String title;

  /// Builds the section's content.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (error, stack) {
      debugPrint('[SafeSection] "$title" failed to build: $error');
      debugPrint(stack.toString());
      return SectionErrorCard(title: title, error: error);
    }
  }
}

/// The inline fallback [SafeSection] renders in place of a failed section.
///
/// Deliberately compact: an error the size of a whole page is indistinguishable
/// from the page being broken, and it hides the sections that still work.
class SectionErrorCard extends StatelessWidget {
  const SectionErrorCard({
    super.key,
    required this.title,
    required this.error,
  });

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$title" could not be displayed',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The rest of the page is still usable.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFA16207),
                    height: 1.5,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      error.toString(),
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: appFontFamily,
                        color: Color(0xFF475467),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
