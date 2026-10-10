/// App-wide page walkthrough.
///
/// A short guided tour of whatever page the user is currently on, launched from
/// the "Walkthrough" chip beside Tasks in the phase headers.
///
/// Rather than hand-authoring a tour per screen — there are hundreds of them
/// and hand-written tours silently rot as layouts change — the tour is derived
/// from the page itself. The engine introspects the live element tree, finds
/// the section headings currently on screen, and walks the user through them in
/// visual order, scrolling each into view and punching a spotlight hole around
/// it.
///
/// Visual language (punched scrim, breathing accent ring, floating card with
/// step dots) deliberately matches `SpotlightWalkthrough`, which the Project
/// Charter uses for its Project Manager coach mark.
///
/// Pages that want bespoke copy can register an override with
/// [PageWalkthroughRegistry.register]; everything else falls back to the
/// derived tour.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand accents shared with the rest of the app.
const _kBrandGold = Color(0xFFFFC812);
const _kBrandAmber = Color(0xFFB45309);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E7EB);
const _kMuted = Color(0xFF6B7280);

/// One stop in a page tour: a section heading to spotlight.
class PageTourStop {
  const PageTourStop({
    required this.label,
    required this.box,
    this.detail,
  });

  /// The heading text found on the page.
  final String label;

  /// The render box to highlight. Re-read every frame the pulse animates so
  /// the hole stays glued to the target while the page scrolls.
  final RenderBox box;

  /// Optional extra guidance, set by a registry override.
  final String? detail;
}

/// Bespoke tours for pages that want copy the derived tour cannot infer.
typedef PageTourBuilder = List<SpotlightStep> Function(List<PageTourStop> stops);

class PageWalkthroughRegistry {
  PageWalkthroughRegistry._();

  static final Map<String, PageTourBuilder> _builders = {};

  /// Registers bespoke copy for [pageId] (a route name or page title).
  static void register(String pageId, PageTourBuilder builder) {
    _builders[pageId] = builder;
  }

  static void clear() => _builders.clear();

  static PageTourBuilder? builderFor(String pageId) => _builders[pageId];
}

/// A single card in the tour.
class SpotlightStep {
  const SpotlightStep({
    required this.title,
    this.description = '',
    this.bullets = const [],
    this.icon,
    this.badgeLabel,
  });

  final String title;
  final String description;
  final List<String> bullets;
  final IconData? icon;
  final String? badgeLabel;
}

/// The header chip that launches the tour for the current page.
class PageWalkthroughButton extends StatelessWidget {
  const PageWalkthroughButton({
    super.key,
    required this.pageId,
    this.pageTitle,
    this.label = 'Walkthrough',
    this.compact = false,
    this.maxWidth,
  });

  /// Identifies the page for registry lookups; falls back to the derived tour.
  final String pageId;

  /// Human-readable page name used as the tour's opening card.
  final String? pageTitle;

  final String label;
  final bool compact;

  /// Hard cap for the chip. The header action row is a fixed [Row] that can be
  /// at capacity on tablet widths, so the chip is clamped rather than allowed
  /// to push the row into an overflow.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    // Squeeze mode: the header action row is at capacity and cannot spare even
    // the bordered chip, so fall back to a bare icon. Keeping the affordance
    // visible beats overflowing the row or hiding the feature entirely.
    if (maxWidth != null && maxWidth! < 34) {
      return Semantics(
        button: true,
        label: 'Page walkthrough',
        child: InkWell(
          onTap: () => showPageWalkthrough(
            context,
            pageId: pageId,
            pageTitle: pageTitle,
          ),
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(
            width: 22,
            height: 28,
            child: Icon(
              Icons.play_circle_outline,
              size: 19,
              color: _kBrandAmber,
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Take a guided tour of this page',
      child: Semantics(
        button: true,
        label: 'Page walkthrough',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPageWalkthrough(
            context,
            pageId: pageId,
            pageTitle: pageTitle,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 8,
            ),
            constraints: maxWidth == null
                ? null
                : BoxConstraints(maxWidth: maxWidth!),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD873)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 19,
                  color: _kBrandAmber,
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kBrandAmber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Launches the tour for the page identified by [pageId].
Future<void> showPageWalkthrough(
  BuildContext context, {
  required String pageId,
  String? pageTitle,
}) {
  // The page title is itself a heading, so discovery finds it — but the
  // opening card already names the page, so spotlighting the title would be a
  // wasted step. Drop it when it leads the list.
  final subject = (pageTitle ?? pageId).trim();
  var stops = discoverPageStops(context);
  if (stops.isNotEmpty && stops.first.label == subject && stops.length > 1) {
    stops = stops.sublist(1);
  }
  final steps = _buildSteps(pageId: pageId, pageTitle: pageTitle, stops: stops);

  return showOverlayTour(
    context,
    steps: steps,
    stopForStep: (index) => index == 0 || index >= stops.length + 1
        ? null
        : stops[index - 1].box,
    scrollTargetForStep: (index) {
      if (index == 0 || index >= stops.length + 1) return null;
      return stops[index - 1].box;
    },
  );
}

/// Derives the card copy: a bespoke registry tour when one exists, otherwise
/// an intro, one card per discovered section, and a closer.
List<SpotlightStep> _buildSteps({
  required String pageId,
  String? pageTitle,
  required List<PageTourStop> stops,
}) {
  final custom = PageWalkthroughRegistry.builderFor(pageId);
  if (custom != null) return custom(stops);

  final subject = (pageTitle ?? pageId).trim();
  final steps = <SpotlightStep>[
    SpotlightStep(
      icon: Icons.explore_outlined,
      badgeLabel: 'Quick tour',
      title: subject.isEmpty ? 'Tour of this page' : subject,
      description: stops.isEmpty
          ? 'This page is still loading its content. Close the tour and try '
              'again once the data has loaded.'
          : 'This page has ${stops.length} '
              '${stops.length == 1 ? 'section' : 'sections'}. We will walk you '
              'through each one, then you can get to work.',
      bullets: const [
        'Use Next and Back to move between sections',
        'Press Escape at any time to leave the tour',
      ],
    ),
  ];

  for (final stop in stops) {
    steps.add(SpotlightStep(
      icon: Icons.looks_one_outlined,
      title: stop.label,
      description: stop.detail ??
          'This is "${stop.label}" — the highlighted area on screen. Everything '
              'in this block belongs to this part of the page.',
    ));
  }

  steps.add(const SpotlightStep(
    icon: Icons.check_circle_outline,
    badgeLabel: 'All set',
    title: "That's the whole page",
    description:
        'You can revisit this tour at any time with the Walkthrough button. '
        'Your work saves automatically as you go.',
  ));
  return steps;
}

/// Finds the section headings currently visible on screen.
///
/// Walks the live element tree and keeps `Text` widgets that look like section
/// headings: large enough to be a heading, short enough to be a label, and
/// currently intersecting the viewport. Because only on-screen headings
/// qualify, the tour naturally describes the page the user is actually on.
List<PageTourStop> discoverPageStops(BuildContext context) {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return const [];

  // The viewport comes from MediaQuery rather than an ancestor Overlay, which
  // may sit below the router.
  if (!context.mounted) return const [];
  final viewport = MediaQuery.maybeOf(context)?.size;
  final screenRect = viewport == null
      ? null
      : Offset.zero & viewport;
  final found = <({String label, RenderBox box, double dy})>[];

  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final label = widget.data ?? widget.textSpan?.toPlainText().trim();
      if (label != null && _looksLikeHeading(widget, label)) {
        final box = element.renderObject;
        if (box is RenderBox &&
            box.attached &&
            box.hasSize &&
            box.size.width > 0 &&
            box.size.height > 0) {
          final origin = box.localToGlobal(Offset.zero);
          final rect = origin & box.size;
          final onScreen = screenRect == null || rect.overlaps(screenRect);
          if (onScreen) {
            found.add((label: label.trim(), box: box, dy: origin.dy));
          }
        }
      }
    }
    element.visitChildren(visit);
  }

  root.visitChildren(visit);

  // Reading the label can rebuild layout, so re-read before relying on it.
  final seen = <String>{};
  final unique = <({String label, RenderBox box, double dy})>[];
  for (final item in found.toList()
    ..sort((a, b) => a.dy.compareTo(b.dy))) {
    if (item.label.isEmpty || !seen.add(item.label)) continue;
    unique.add(item);
  }

  // A tour longer than this stops being a tour.
  return [
    for (final item in unique.take(8))
      PageTourStop(label: item.label, box: item.box),
  ];
}

bool _looksLikeHeading(Text text, String label) {
  final trimmed = label.trim();
  // Headings are short labels, not paragraphs.
  if (trimmed.isEmpty || trimmed.length > 70) return false;
  final style = text.style;
  final size = style?.fontSize ?? 14;
  final weight = style?.fontWeight ?? FontWeight.w400;
  final isBig = size >= 16;
  final isBold = weight.index >= FontWeight.w600.index;
  return isBig && isBold;
}

/// Shows the tour as a full-screen overlay.
///
/// [stopForStep] returns the box to spotlight for a step (null for the intro
/// and closer, which dim the whole page instead), and
/// [scrollTargetForStep] returns a box to bring into view first.
Future<void> showOverlayTour(
  BuildContext context, {
  required List<SpotlightStep> steps,
  required RenderBox? Function(int index) stopForStep,
  RenderBox? Function(int index)? scrollTargetForStep,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future<void>.value();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PageTourOverlay(
      steps: steps,
      stopForStep: stopForStep,
      scrollTargetForStep: scrollTargetForStep,
      onClose: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return Future<void>.value();
}

class _PageTourOverlay extends StatefulWidget {
  const _PageTourOverlay({
    required this.steps,
    required this.stopForStep,
    required this.scrollTargetForStep,
    required this.onClose,
  });

  final List<SpotlightStep> steps;
  final RenderBox? Function(int index) stopForStep;
  final RenderBox? Function(int index)? scrollTargetForStep;
  final VoidCallback onClose;

  @override
  State<_PageTourOverlay> createState() => _PageTourOverlayState();
}

class _PageTourOverlayState extends State<_PageTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  int _index = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    if (next < 0 || next >= widget.steps.length) return;
    HapticFeedback.selectionClick();
    setState(() => _index = next);

    // Bring the incoming section into view before it is spotlighted, so the
    // hole lands on something the user can actually see.
    final target = widget.scrollTargetForStep?.call(next);
    if (target == null || !target.attached || !target.hasSize) return;
    final elementContext = _elementFor(target);
    if (elementContext == null) return;
    Scrollable.ensureVisible(
      elementContext,
      alignment: 0.25,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Walks the element tree to recover the [BuildContext] for [box], which is
  /// what `Scrollable.ensureVisible` needs.
  BuildContext? _elementFor(RenderBox box) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    BuildContext? match;
    void visit(Element element) {
      if (match != null) return;
      if (element.renderObject == box) {
        match = element;
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return match;
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.lightImpact();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final box = widget.stopForStep(_index);
    final rect = box != null && box.attached && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    return FocusScope(
      autofocus: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(_pulse.value);
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: CustomPaint(
                        painter: _TourScrimPainter(
                          rect: rect,
                          pulse: pulse,
                        ),
                      ),
                    ),
                  ),
                  // Card
                  Positioned(
                    left: 16,
                    right: 16,
                    top: rect == null ? 24 : null,
                    bottom: rect == null ? null : (rect.bottom + 24).clamp(16.0, constraints.maxHeight - 320),
                    child: _TourCard(
                      step: step,
                      index: _index,
                      total: widget.steps.length,
                      onNext: _index == widget.steps.length - 1
                          ? _close
                          : () => _goTo(_index + 1),
                      onPrev: _index == 0 ? null : () => _goTo(_index - 1),
                      onClose: _close,
                      onJump: (i) => _goTo(i),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TourScrimPainter extends CustomPainter {
  _TourScrimPainter({required this.rect, required this.pulse});

  final Rect? rect;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (rect == null) {
      // Intro/closer steps dim the whole page.
      canvas.drawPath(full, Paint()..color = const Color(0xE60B1220));
      return;
    }

    const radius = 14.0;
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(radius)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      Paint()..color = const Color(0xE60B1220),
    );

    final glow = 10.0 + 8.0 * pulse;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect!.inflate(2 + 2 * pulse), const Radius.circular(radius + 2)),
      Paint()
        ..color = _kBrandGold.withValues(alpha: 0.10 + 0.10 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect!, const Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + 0.75 * pulse
        ..color = _kBrandGold.withValues(alpha: 0.65 + 0.35 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter old) =>
      old.rect != rect || old.pulse != pulse;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
    required this.onJump,
  });

  final SpotlightStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback? onPrev;
  final VoidCallback onClose;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        color: _kSurface,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.icon != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(step.icon, color: _kBrandAmber, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (step.badgeLabel != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kBrandGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              step.badgeLabel!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _kBrandAmber,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: _kMuted),
                    ),
                  ),
                ],
              ),
              if (step.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
              if (step.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final bullet in step.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 8),
                          child: Icon(Icons.circle, size: 6, color: _kBrandGold),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  // Step dots
                  for (var i = 0; i < total; i++)
                    GestureDetector(
                      onTap: () => onJump(i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: i == index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == index
                              ? _kBrandGold
                              : _kBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (onPrev != null)
                    TextButton(
                      onPressed: onPrev,
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBrandGold,
                      foregroundColor: const Color(0xFF111827),
                    ),
                    child: Text(isLast ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
