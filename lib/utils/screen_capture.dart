import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Captures the visual contents of the currently visible screen so that a PDF
/// export contains everything the user can actually see — not just the handful
/// of data fields a screen bothered to hand to [PdfExportHelper].
///
/// Screens in this app build their exports from hardcoded section lists (often
/// only "Project Name" plus one notes field), which is why exported PDFs used to
/// come out nearly empty even though the screen itself was full of content.
/// Rather than hand-authoring a section for every widget on every screen, the
/// exporter rasterises the screen itself and appends those pages to the PDF.
///
/// The capture walks the screen's main scroll view so that content below the
/// fold is included, not just the first viewport.
class ScreenCapture {
  ScreenCapture._();

  /// Boundary that wraps the whole app; see `lib/main.dart`.
  ///
  /// Screens must be captured from the app root rather than from a local
  /// `RepaintBoundary` so that whatever the scroll view has painted is
  /// included, and so that content clipped by an inner scroll view still shows
  /// up on the following pages.
  static final GlobalKey rootBoundaryKey =
      GlobalKey(debugLabel: 'screen-capture-root');

  /// Drives the indeterminate progress bar shown under the app while an export
  /// is rasterising screens. It is deliberately rendered *outside*
  /// [rootBoundaryKey] so the progress bar never appears in its own capture.
  static final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// Maximum number of viewports to capture for a single screen.
  ///
  /// Guards against runaway scrolling on screens with huge or unexpectedly
  /// large scroll extents.
  static const int maxPages = 60;

  /// Rasterises the visible screen, scrolling the primary scroll view to its
  /// end, and returns one PNG per viewport (already in document order).
  ///
  /// Returns an empty list when the screen is not ready to be captured (not yet
  /// painted, offstage, in a test harness, or web without a rendering surface),
  /// so callers can fall back to structured sections only.
  static Future<List<Uint8List>> captureVisibleScreen() async {
    final boundaryContext = rootBoundaryKey.currentContext;
    if (boundaryContext == null) return const [];
    final boundary = boundaryContext.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return const [];
    if (!boundary.hasSize || boundary.size.isEmpty) return const [];

    // A higher ratio keeps small table text legible once the page is scaled to
    // A4, but 3x is plenty and bounds memory for long pages.
    final media = MediaQuery.maybeOf(boundaryContext);
    final devicePixelRatio = media?.devicePixelRatio ?? 1.0;
    final pixelRatio = devicePixelRatio.clamp(2.0, 3.0);

    final scrollable = _findPrimaryScrollable(boundaryContext as Element);
    final pages = <Uint8List>[];

    busy.value = true;
    try {
      if (scrollable == null) {
        // Fixed-layout screen: the single viewport is all there is.
        final png = await _captureViewport(boundary, pixelRatio);
        if (png != null) pages.add(png);
        return pages;
      }

      final position = scrollable.position;
      final originalOffset = position.pixels;
      final maxExtent = position.maxScrollExtent;
      final offsets = planCaptureOffsets(
        viewportHeight: boundary.size.height,
        maxScrollExtent: maxExtent,
        startOffset: originalOffset,
      );

      // Capture the first viewport as-is, then step down the page.
      for (var index = 0; index < offsets.length; index++) {
        if (index > 0) {
          position.jumpTo(offsets[index]);
          await _endOfFrame();
        }
        final png = await _captureViewport(boundary, pixelRatio);
        if (png == null) break;
        pages.add(png);
      }

      // Always hand the screen back exactly as the user left it.
      position.jumpTo(originalOffset);
      await _endOfFrame();
      return pages;
    } finally {
      busy.value = false;
    }
  }

  /// How long to wait for a single frame before capturing regardless.
  static const Duration _frameWaitTimeout = Duration(milliseconds: 400);

  /// Scroll offsets to capture, in order, starting at [startOffset].
  ///
  /// Steps by one viewport minus a small overlap so that a row of table text
  /// straddling a page break still appears whole on one of the two pages.
  /// Always starts with [startOffset] so the user sees what they were looking
  /// at, and is capped at [maxPages] to bound work on very long screens.
  @visibleForTesting
  static List<double> planCaptureOffsets({
    required double viewportHeight,
    required double maxScrollExtent,
    double startOffset = 0.0,
  }) {
    if (viewportHeight <= 0 || !viewportHeight.isFinite) {
      return const [0.0];
    }
    final overlap = (viewportHeight * 0.04).clamp(24.0, 64.0);
    final step = viewportHeight - overlap;
    // Never step by less than a sensible slice even on very short viewports.
    final stride = step > 1.0 ? step : viewportHeight;

    final offsets = <double>[startOffset];
    for (var index = 1; index < maxPages; index++) {
      final next = startOffset + index * stride;
      if (next >= maxScrollExtent - 0.5) break;
      offsets.add(next);
    }
    return offsets;
  }

  /// Paints the boundary into a PNG, waiting a frame first so the raster we
  /// take matches what is on screen.
  static Future<Uint8List?> _captureViewport(
    RenderRepaintBoundary boundary,
    double pixelRatio,
  ) async {
    await _endOfFrame();
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      // Rasterisation can fail on surfaces without a GPU backend (headless
      // tests, some web canvases). A partial capture is better than a crash.
      return null;
    }
  }

  /// Waits for the next frame so a scroll jump has actually been painted before
  /// it is captured.
  ///
  /// Bounded on purpose: an export must never leave the UI stuck on a progress
  /// bar because a frame was not scheduled (backgrounded tab, throttled or
  /// headless surface). If no frame arrives we capture what is on screen rather
  /// than waiting forever.
  static Future<void> _endOfFrame() async {
    SchedulerBinding.instance.scheduleFrame();
    await Future.any(<Future<void>>[
      SchedulerBinding.instance.endOfFrame,
      Future<void>.delayed(_frameWaitTimeout),
    ]);
  }

  /// Finds the tallest vertical scroll view currently mounted, which in this
  /// app is the screen's main content area.
  static ScrollableState? _findPrimaryScrollable(Element root) {
    ScrollableState? best;
    var bestExtent = 0.0;

    void visit(Element element) {
      // A Scrollable's Element is a StatefulElement wrapping a ScrollableState,
      // so the state — not the element — is what exposes the position.
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.vertical &&
            position.hasContentDimensions &&
            position.maxScrollExtent > bestExtent) {
          best = element.state as ScrollableState;
          bestExtent = position.maxScrollExtent;
        }
      }
      element.visitChildren(visit);
    }

    visit(root);
    return best;
  }
}
