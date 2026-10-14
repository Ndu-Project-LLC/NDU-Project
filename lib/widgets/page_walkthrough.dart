/// App-wide page walkthrough.
///
/// A detailed, page-by-page guided tour of whatever page the user is currently
/// on, launched from the "Walkthrough" chip beside Tasks in the phase headers.
/// It works like the Project Charter's spotlight coach mark: a punched hole
/// highlights each section of that particular screen, one at a time, with a
/// floating card explaining what the section is for.
///
/// Rather than hand-authoring a tour per screen — there are hundreds of them
/// and hand-written tours silently rot as layouts change — the tour is derived
/// from the page itself. The engine maps the WHOLE page, not just the first
/// screenful: when the tour opens, a "Mapping this page" pass briefly scrolls
/// the page from top to bottom under a dimmed scrim and records every section
/// heading it passes (including everything below the fold), then restores the
/// scroll position and walks the user through each section in reading order,
/// scrolling each into view and punching a spotlight hole around it.
///
/// Visual language (punched scrim, breathing accent ring, floating card with
/// step progress) deliberately matches `SpotlightWalkthrough`, which the
/// Project Charter uses for its Project Manager coach mark.
///
/// Pages that want bespoke copy can register an override with
/// [PageWalkthroughRegistry.register]; pages with authored [PageTour] copy in
/// `page_tours/page_tour_index.dart` get tailored section descriptions;
/// everything else falls back to the derived tour.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ndu_project/widgets/page_tours/page_tour_index.dart';

/// Brand accents shared with the rest of the app.
const _kBrandGold = Color(0xFFFFC812);
const _kBrandAmber = Color(0xFFB45309);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E7EB);
const _kMuted = Color(0xFF6B7280);

/// Upper bound on how many sections a single tour will visit. Beyond this the
/// tour stops being a tour; real pages land far below it.
const int _kMaxTourStops = 24;

/// One stop in a page tour: a section heading to spotlight.
class PageTourStop {
  const PageTourStop({
    required this.label,
    this.box,
    this.detail,
    this.contentDy,
  });

  /// The heading text found on the page.
  final String label;

  /// The render box to highlight, when one was captured at discovery time.
  /// May be null for below-fold sections that are not built yet; the tour
  /// re-resolves the live box by [label] when it reaches the stop.
  final RenderBox? box;

  /// Position of the heading within the page content, used as the scroll hint
  /// for bringing not-yet-built sections into view. Null when unknown.
  final double? contentDy;

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
///
/// The overlay opens immediately in a "Mapping this page" state, sweeps the
/// page to discover every section (including everything below the fold), then
/// starts the walkthrough with the full stop list.
Future<void> showPageWalkthrough(
  BuildContext context, {
  required String pageId,
  String? pageTitle,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future<void>.value();

  // The Walkthrough chip sits INSIDE the page body's scrollable (the phase
  // header is part of the scrolling content), so the nearest vertical
  // ScrollableState above the chip IS the page body. Anchoring discovery
  // there is deterministic: stacked-but-still-mounted screens elsewhere in
  // the tree can never leak into the tour.
  ScrollableState? bodyScrollable;
  bool findBodyAncestor(Element element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final s = element.state as ScrollableState;
      try {
        if (s.position.axis == Axis.vertical) {
          bodyScrollable = s;
          return false; // nearest vertical scrollable wins
        }
      } catch (_) {}
    }
    return true; // keep climbing
  }

  try {
    context.visitAncestorElements(findBodyAncestor);
  } catch (_) {
    bodyScrollable = null;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PageTourOverlay.page(
      pageId: pageId,
      pageTitle: pageTitle,
      bodyScrollable: bodyScrollable,
      onClose: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return Future<void>.value();
}

/// Shows a pre-built tour as a full-screen overlay (steps mode).
///
/// Kept for callers that already hold a step list and target boxes; the
/// page-mode overlay built by [showPageWalkthrough] maps the page itself.
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
    builder: (_) => _PageTourOverlay.steps(
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

/// Derives the card copy: a bespoke registry tour when one exists, otherwise
/// an intro, one card per discovered section, and a closer.
List<SpotlightStep> buildTourSteps({
  required String pageId,
  String? pageTitle,
  required List<PageTourStop> stops,
}) {
  final custom = PageWalkthroughRegistry.builderFor(pageId);
  if (custom != null) return custom(stops);

  final tour = pageTours[pageId];
  if (tour != null) return _stepsFromTour(tour, stops);

  final subject = (pageTitle ?? pageId).trim();
  final steps = <SpotlightStep>[
    SpotlightStep(
      icon: Icons.explore_outlined,
      badgeLabel: 'Quick tour',
      title: subject.isEmpty ? 'Tour of this page' : subject,
      description: stops.isEmpty
          ? 'This page is still loading its content. Close the tour and try '
              'again once the data has loaded.'
          : 'We mapped the whole page and found ${stops.length} '
              '${stops.length == 1 ? 'section' : 'sections'} — including '
              'everything further down. We will walk you through each one.',
      bullets: const [
        'Use Next and Back to move between sections',
        'Use the arrow keys; press Escape at any time to leave the tour',
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

List<SpotlightStep> _buildSteps({
  required String pageId,
  String? pageTitle,
  required List<PageTourStop> stops,
}) =>
    buildTourSteps(pageId: pageId, pageTitle: pageTitle, stops: stops);

/// Turns an authored [PageTour] into cards. Each discovered section heading is
/// matched to its authored description; headings without one fall back to a
/// generic line.
List<SpotlightStep> _stepsFromTour(PageTour tour, List<PageTourStop> stops) {
  final steps = <SpotlightStep>[
    SpotlightStep(
      icon: tour.icon,
      badgeLabel: 'Quick tour',
      title: tour.title,
      description: tour.intro,
      bullets: tour.bullets,
    ),
  ];
  for (final stop in stops) {
    steps.add(SpotlightStep(
      icon: Icons.looks_one_outlined,
      title: stop.label,
      description: tour.sections[stop.label] ??
          stop.detail ??
          'This is "${stop.label}" on this page. Work through it, then move '
              'on to the next section.',
    ));
  }
  steps.add(SpotlightStep(
    icon: Icons.check_circle_outline,
    badgeLabel: 'All set',
    title: "That's the whole page",
    description: tour.outro ??
        'You can revisit this tour at any time with the Walkthrough button. '
            'Your work saves automatically as you go.',
  ));
  return steps;
}

/// Finds the section headings currently visible on screen.
///
/// Walks the live element tree and keeps `Text` widgets that look like section
/// headings: large enough to be a heading, short enough to be a label, and
/// currently intersecting the viewport. This is the fallback discovery path
/// for pages with nothing to scroll; page-mode tours normally use the
/// full-page sweep instead, which also captures headings below the fold.
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
    _visitLiveChildren(element, visit);
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
    for (final item in unique.take(_kMaxTourStops))
      PageTourStop(
        label: item.label,
        box: item.box,
        contentDy: item.dy,
      ),
  ];
}

/// Visits [element]'s children, skipping hidden subtrees.
///
/// Covered routes stay mounted in the Navigator stack wrapped in
/// `Offstage(offstage: true)` — without this guard the tour would happily
/// spotlight the PREVIOUS page (its scrollables and headings are still in the
/// tree). Hidden panels on the current page are skipped for the same reason.
void _visitLiveChildren(Element element, void Function(Element) visitor) {
  element.visitChildren((child) {
    final w = child.widget;
    if (w is Offstage && w.offstage) return;
    visitor(child);
  });
}

bool _looksLikeHeading(Text text, String label) {
  final trimmed = label.trim();
  // Headings are short labels, not paragraphs.
  if (trimmed.isEmpty || trimmed.length > 70) return false;
  // Numbers, currency and percentages are KPI values, not section headings.
  if (!trimmed.contains(RegExp(r'[A-Za-z]'))) return false;
  final style = text.style;
  final size = style?.fontSize ?? 14;
  final weight = style?.fontWeight ?? FontWeight.w400;
  final isBig = size >= 16;
  final isBold = weight.value >= FontWeight.w600.value;
  // Bold 15px display headings (the app's sectionTitle / notes-title style)
  // also qualify.
  final isDisplayHeading =
      size >= 15 && weight.value >= FontWeight.w700.value;
  return (isBig && isBold) || isDisplayHeading;
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-page sweep
// ─────────────────────────────────────────────────────────────────────────────

/// The result of a successful page sweep.
class _SweepResult {
  const _SweepResult({required this.stops, required this.scrollable});

  /// Every section heading on the page, ordered by content position.
  final List<PageTourStop> stops;

  /// The scrollable that was swept, kept so the tour can bring far-away
  /// sections into view when their boxes are not built yet.
  final ScrollableState scrollable;
}

/// Walks the element tree for [Scrollable] states.
void _collectScrollables(Element element, List<ScrollableState> out) {
  if (element is StatefulElement && element.state is ScrollableState) {
    out.add(element.state as ScrollableState);
  }
  _visitLiveChildren(element, (child) => _collectScrollables(child, out));
}

/// Counts the section headings inside an element subtree.
int _countHeadingsIn(Element? element) {
  if (element == null || !element.mounted) return 0;
  var count = 0;
  void visit(Element el) {
    final w = el.widget;
    if (w is Text) {
      final label = w.data ?? w.textSpan?.toPlainText().trim();
      if (label != null && _looksLikeHeading(w, label)) count++;
    }
    _visitLiveChildren(el, visit);
  }

  _visitLiveChildren(element, visit);
  return count;
}

/// Finds the PAGE BODY scrollable — the vertical scrollable that actually
/// hosts the page content.
///
/// Extent alone is not enough: on short pages (or tall viewports) the body
/// barely scrolls while the sidebar menu still does, and extent would pick
/// the sidebar. So candidates are scored by how many section headings live
/// in their subtree; extent and viewport size only break ties.
ScrollableState? _findBodyScrollable() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return null;
  final scrollables = <ScrollableState>[];
  _collectScrollables(root, scrollables);

  ScrollableState? best;
  var bestScore = 0;
  var bestExtent = -1.0;
  var bestViewport = -1.0;
  for (final s in scrollables) {
    try {
      final position = s.position;
      if (!position.hasContentDimensions || !position.hasPixels) continue;
      if (position.axis != Axis.vertical) continue;
      final extent = position.maxScrollExtent;
      if (extent.isNaN) continue;
      final score = _countHeadingsIn(
          s.context is Element ? s.context as Element : null);
      final viewport = position.viewportDimension;
      final better = score > bestScore ||
          (score == bestScore &&
              (extent > bestExtent ||
                  (extent == bestExtent && viewport > bestViewport)));
      if (better) {
        bestScore = score;
        bestExtent = extent;
        bestViewport = viewport;
        best = s;
      }
    } catch (_) {
      // A scrollable mid-disposal; skip it.
    }
  }
  return best;
}

/// Sweeps the page from top to bottom, recording every section heading it
/// passes. The scrim hides the jumps from the user; a "Mapping this page"
/// pill explains what is happening.
///
/// Pages that fit on screen (no scroll) are mapped with a single on-screen
/// pass instead — same result, no scrolling.
///
/// [anchor] is the page body scrollable captured from the Walkthrough chip's
/// ancestor chain; when unusable, a scored fallback picks the best candidate.
Future<_SweepResult?> _sweepPage(ScrollableState? anchor) async {
  var scrollable = anchor;
  if (scrollable == null || !scrollable.mounted) {
    scrollable = _findBodyScrollable();
  }
  if (scrollable == null) return null;
  final position = scrollable.position;
  if (!position.hasContentDimensions || !position.hasPixels) {
    if (scrollable == anchor) return _sweepPage(null);
    return null;
  }

  // Only headings INSIDE the page body scrollable qualify. Walking the whole
  // tree would sweep fixed chrome too — the sidebar project name, menu
  // groups, the header — none of which are sections of this page.
  // State.context is the StatefulElement itself, so the cast is exact.
  final bodyElement =
      scrollable.context is Element ? scrollable.context as Element : null;
  if (bodyElement == null) return null;

  if (position.maxScrollExtent <= 24) {
    return _SweepResult(
      stops: _visibleStopsIn(bodyElement),
      scrollable: scrollable,
    );
  }

  final original = position.pixels.clamp(0.0, position.maxScrollExtent);
  final viewportH =
      position.viewportDimension > 0 ? position.viewportDimension : 800.0;

  // (label, contentDy) pairs; boxes are re-resolved lazily per stop because
  // far-from-viewport children unmount as the sweep scrolls past them.
  final collected = <({String label, double contentDy})>[];
  final seenLabels = <String>{};

  Future<void> collectAt(double offset) async {
    try {
      position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    } catch (_) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    final actual = position.pixels;

    if (!bodyElement.mounted) return;
    final found = <({String label, double dy})>[];
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
            found.add((label: label.trim(), dy: box.localToGlobal(Offset.zero).dy));
          }
        }
      }
      _visitLiveChildren(element, visit);
    }

    bodyElement.visitChildren(visit);
    for (final item in found) {
      final contentDy = item.dy + actual;
      // Keep the top-most occurrence of each label (repeated card titles
      // would otherwise pad the tour with duplicates).
      if (seenLabels.add(item.label)) {
        collected.add((label: item.label, contentDy: contentDy));
      }
    }
  }

  // Step down the page in ~65% viewport hops so overlapping coverage catches
  // headings between cacheExtent boundaries; capped for very long pages.
  const maxHops = 40;
  var offset = 0.0;
  for (var hop = 0; hop <= maxHops; hop++) {
    await collectAt(offset);
    final max = position.maxScrollExtent;
    if (!max.isFinite) break;
    final next = offset + viewportH * 0.65;
    if (next >= max) {
      if (offset < max) await collectAt(max);
      break;
    }
    offset = next;
  }

  // Restore where the user was.
  try {
    position.jumpTo(original);
  } catch (_) {}
  await WidgetsBinding.instance.endOfFrame;

  collected.sort((a, b) => a.contentDy.compareTo(b.contentDy));
  return _SweepResult(
    stops: [
      for (final item in collected.take(_kMaxTourStops))
        PageTourStop(label: item.label, contentDy: item.contentDy),
    ],
    scrollable: scrollable,
  );
}

/// Collects the section headings currently on screen inside [bodyElement],
/// for pages that fit (or fit after being scrolled) without a full sweep.
List<PageTourStop> _visibleStopsIn(Element bodyElement) {
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
          found.add(
              (label: label.trim(), box: box, dy: box.localToGlobal(Offset.zero).dy));
        }
      }
    }
    _visitLiveChildren(element, visit);
  }

  bodyElement.visitChildren(visit);

  final seen = <String>{};
  final stops = <PageTourStop>[];
  for (final item in found.toList()..sort((a, b) => a.dy.compareTo(b.dy))) {
    if (item.label.isEmpty || !seen.add(item.label)) continue;
    if (item.dy < -40) continue; // scrolled just above the viewport
    stops.add(PageTourStop(
      label: item.label,
      box: item.box,
      contentDy: item.dy,
    ));
    if (stops.length >= _kMaxTourStops) break;
  }
  return stops;
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _PageTourOverlay extends StatefulWidget {
  const _PageTourOverlay.page({
    required this.pageId,
    required this.pageTitle,
    required this.onClose,
    this.bodyScrollable,
  })  : steps = null,
        stopForStep = null,
        scrollTargetForStep = null;

  const _PageTourOverlay.steps({
    required this.steps,
    required this.stopForStep,
    required this.scrollTargetForStep,
    required this.onClose,
  })  : pageId = null,
        pageTitle = null,
        bodyScrollable = null;

  final String? pageId;
  final String? pageTitle;

  /// The page body scrollable captured from the Walkthrough chip's own
  /// ancestor chain; discovery sweeps only this subtree. Null when the chip
  /// is not inside a scrollable, in which case a scored fallback is used.
  final ScrollableState? bodyScrollable;

  final List<SpotlightStep>? steps;
  final RenderBox? Function(int index)? stopForStep;
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

  /// Page-mode state: discovered stops + resolved boxes.
  List<PageTourStop>? _pageStops;
  ScrollableState? _pageScrollable;
  final Map<int, RenderBox> _resolvedBoxes = {};

  /// True while the page is being mapped (page-mode only).
  bool _scanning = false;

  int _index = 0;
  bool _closing = false;
  List<SpotlightStep> _steps = const [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    // Global key handling: an overlay tour cannot rely on widget focus
    // (nothing may hold primary focus, and stealing it from page inputs is
    // rude). HardwareKeyboard sees every key before focus dispatch.
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _steps = widget.steps ?? const [];
    _scanning = widget.steps == null;
    if (_scanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pulse.dispose();
    super.dispose();
  }

  /// Keyboard controls: Escape closes, → / Enter / Space advance, ← goes back.
  /// Returns true when the key was consumed by the tour.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_scanning) {
      // Only Escape works while the page is still being mapped.
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _close();
        return true;
      }
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _close();
        return true;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.numpadEnter:
        _advance();
        return true;
      case LogicalKeyboardKey.arrowLeft:
        _goTo(_index - 1);
        return true;
      default:
        return false;
    }
  }

  /// Page-mode preparation: sweep the page, build the step list, start.
  Future<void> _prepare() async {
    List<PageTourStop> stops;
    ScrollableState? scrollable;
    try {
      final swept = await _sweepPage(widget.bodyScrollable);
      scrollable = swept?.scrollable;
      stops = swept?.stops ?? const [];
    } catch (_) {
      stops = const [];
    }
    if (!mounted) return;

    // Fall back to a viewport scan when the page has nothing to scroll (or
    // the sweep came up empty).
    if (stops.isEmpty) {
      stops = discoverPageStops(context);
    }

    // The page title is itself a heading, so discovery finds it — but the
    // opening card already names the page, so spotlighting the title would be
    // a wasted step. Drop it when it leads the list.
    final subject = (widget.pageTitle ?? widget.pageId ?? '').trim();
    if (stops.isNotEmpty &&
        stops.length > 1 &&
        stops.first.label == subject) {
      stops = stops.sublist(1);
    }

    setState(() {
      _pageStops = stops;
      _pageScrollable = scrollable;
      _steps = _buildSteps(
        pageId: widget.pageId ?? '',
        pageTitle: widget.pageTitle,
        stops: stops,
      );
      _scanning = false;
    });
  }

  bool get _isPageMode => widget.stopForStep == null;

  /// Card top for a spotlight [rect]: just below the hole when there is room
  /// for a ~300px card, otherwise just above it, otherwise pinned to the top
  /// of the screen. Keeps the card glued to its section in any viewport.
  double _cardTopFor(Rect rect, double maxHeight) {
    const cardEstimate = 300.0;
    final below = rect.bottom + 24;
    if (maxHeight - below >= cardEstimate) return below;
    final above = rect.top - 24 - cardEstimate;
    if (above >= 16) return above;
    return 16.0;
  }

  PageTourStop? _stopFor(int index) {
    if (_isPageMode) {
      final stops = _pageStops;
      if (stops == null) return null;
      if (index <= 0 || index > stops.length) return null;
      return stops[index - 1];
    }
    return null;
  }

  bool get _isIntroOrCloser =>
      _index == 0 || _index >= _steps.length - 1;

  /// Resolves the live render box for a page-mode stop.
  RenderBox? _boxForStop(int index) {
    final stop = _stopFor(index);
    if (stop == null) return null;

    final cached = _resolvedBoxes[index];
    if (cached != null &&
        cached.attached &&
        cached.hasSize &&
        cached.size.width > 0) {
      return cached;
    }

    // Re-find the heading by label. Several sections can share a label; when
    // a content position hint exists, prefer the box closest to it. Walk the
    // page body subtree only, so fixed chrome can never re-bind a stop.
    final candidates = <RenderBox>[];
    final bodyElement = (_pageScrollable?.context is Element)
        ? _pageScrollable!.context as Element
        : WidgetsBinding.instance.rootElement;
    if (bodyElement == null || !bodyElement.mounted) return null;
    void visit(Element element) {
      final w = element.widget;
      if (w is Text) {
        final label = w.data ?? w.textSpan?.toPlainText().trim();
        // The sweep only collected heading-styled texts, so re-resolution
        // must too — a TextField label with the same text must never steal
        // the spotlight.
        if (label != null &&
            label.trim() == stop.label &&
            _looksLikeHeading(w, label)) {
          final box = element.renderObject;
          if (box is RenderBox && box.attached && box.hasSize) {
            candidates.add(box);
          }
        }
      }
      _visitLiveChildren(element, visit);
    }

    bodyElement.visitChildren(visit);
    if (candidates.isEmpty) return null;

    RenderBox best = candidates.first;
    if (stop.contentDy != null && candidates.length > 1) {
      final pixels = _pageScrollable?.position.pixels ?? 0;
      var bestScore = double.infinity;
      for (final box in candidates) {
        final contentDy = box.localToGlobal(Offset.zero).dy + pixels;
        final score = (contentDy - stop.contentDy!).abs();
        if (score < bestScore) {
          bestScore = score;
          best = box;
        }
      }
    }
    _resolvedBoxes[index] = best;
    return best;
  }

  RenderBox? _boxForStep(int index) {
    if (!_isPageMode) return widget.stopForStep?.call(index);
    if (_isIntroOrCloser) return null;
    return _boxForStop(index);
  }

  /// Spotlight rect for the current step, inflated slightly so the hole reads
  /// as a section band rather than a tight text outline.
  Rect? _rectForStep(int index) {
    final box = _boxForStep(index);
    if (box == null || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTRB(
      origin.dx - 14,
      origin.dy - 10,
      origin.dx + box.size.width + 14,
      origin.dy + box.size.height + 10,
    );
  }

  void _goTo(int next) {
    if (next < 0 || next >= _steps.length) return;
    HapticFeedback.selectionClick();
    setState(() => _index = next);
    _resolvedBoxes.remove(next);

    if (!_isPageMode) {
      // Steps mode: bring the caller-provided target into view.
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
      return;
    }

    _revealStop(next);
  }

  /// Makes sure the section for [index] is on screen before its spotlight
  /// paints: scroll to the recorded content position when the box is not
  /// built yet, retry resolution for a few frames, then fine-tune with
  /// [Scrollable.ensureVisible].
  Future<void> _revealStop(int index) async {
    final stop = _stopFor(index);
    if (stop == null) return;

    var box = _boxForStop(index);
    if (box == null && stop.contentDy != null) {
      final position = _pageScrollable?.position;
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions) {
        final viewport =
            position.viewportDimension > 0 ? position.viewportDimension : 800.0;
        final target =
            (stop.contentDy! - viewport * 0.25).clamp(0.0, position.maxScrollExtent);
        if ((position.pixels - target).abs() > 4) {
          try {
            await position.animateTo(
              target,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          } catch (_) {
            return;
          }
        }
        for (var frame = 0; frame < 20 && box == null; frame++) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          box = _boxForStop(index);
        }
        if (!mounted) return;
        setState(() {}); // re-read the rect now that the box exists
      }
    }

    if (box == null || !box.attached) return;
    final elementContext = _elementFor(box);
    if (elementContext == null || !elementContext.mounted || !mounted) return;
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
      _visitLiveChildren(element, visit);
    }

    root.visitChildren(visit);
    return match;
  }

  void _advance() {
    if (_index >= _steps.length - 1) {
      _close();
    } else {
      _goTo(_index + 1);
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.lightImpact();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) return _buildScanning();
    if (_steps.isEmpty) return _buildScanning(); // keeps the pill while retrying
    final step = _steps[_index];
    final rect = _rectForStep(_index);

    return AnimatedBuilder(
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
                  // Dock the card just below the spotlighted section so
                  // the card and the hole read as one unit. When there is
                  // no room below (short viewports), flip above the hole;
                  // as a last resort pin to the top.
                  top: rect == null
                      ? 24
                      : _cardTopFor(rect, constraints.maxHeight),
                  child: _TourCard(
                    step: step,
                    index: _index,
                    total: _steps.length,
                    onNext: _index == _steps.length - 1
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
    );
  }

  /// The "Mapping this page" state shown while the sweep runs.
  Widget _buildScanning() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulse = Curves.easeInOut.transform(_pulse.value);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TourScrimPainter(rect: null, pulse: pulse),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD873)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.explore_outlined,
                      color: _kBrandAmber,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mapping this page',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Gathering every section for the tour…',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Animated dots driven by the shared pulse.
                    Row(
                      children: List.generate(3, (i) {
                        final phase = (pulse * 3 - i).abs() % 1;
                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: _kBrandGold
                                .withValues(alpha: 0.25 + 0.75 * (1 - phase)),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
                  // Step dots for short tours; a compact counter for long ones
                  // (a 20-dot row would overflow the card).
                  if (total <= 8)
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
                      )
                  else
                    Text(
                      'Step ${index + 1} of $total',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _kMuted,
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
