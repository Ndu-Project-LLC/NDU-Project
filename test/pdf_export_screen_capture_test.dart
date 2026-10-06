import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/screen_capture.dart';

/// A tiny valid PNG (1x1, opaque white) so page assembly can be exercised
/// without a GPU.
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

int _pageCount(Uint8List bytes) {
  // The pdf package writes each page object as "/Type/Page"; the page tree
  // root is "/Type/Pages", which must not be counted.
  final text = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page(?![s])').allMatches(text).length;
}

/// Pumps a screen inside the capture boundary and hands it to [body].
///
/// The capture awaits real frames, so it has to run inside `runAsync` to
/// escape the fake-async zone the test body otherwise runs in.
Future<List<Uint8List>> _capture(
  WidgetTester tester, {
  required Widget child,
}) async {
  final result = await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: ScreenCapture.rootBoundaryKey,
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ScreenCapture.captureVisibleScreen();
  });
  return result ?? const [];
}

void main() {
  group('PdfExportHelper.buildDocumentBytes', () {
    test('emits one section page when there is no screen capture', () async {
      final bytes = await PdfExportHelper.buildDocumentBytes(
        screenTitle: 'Long Lead Equipment Ordering',
        projectName: 'Demo',
        generatedAt: DateTime(2026, 10, 3),
        sections: [
          PdfSection.text('Notes', 'Some notes.'),
        ],
      );

      expect(_pageCount(bytes), 1);
    });

    test('appends one page per captured screen viewport', () async {
      final bytes = await PdfExportHelper.buildDocumentBytes(
        screenTitle: 'Schedule',
        projectName: 'Demo',
        generatedAt: DateTime(2026, 10, 3),
        sections: const [],
        screenPages: [_onePixelPng, _onePixelPng, _onePixelPng],
      );

      // One section page plus one image page per viewport.
      expect(_pageCount(bytes), 4);
    });

    test('a captured screen alone still produces a full page', () async {
      final bytes = await PdfExportHelper.buildDocumentBytes(
        screenTitle: 'Risk Register',
        projectName: 'Demo',
        generatedAt: DateTime(2026, 10, 3),
        sections: const [],
        screenPages: [_onePixelPng],
      );

      expect(_pageCount(bytes), 2);
    });
  });

  group('ScreenCapture.planCaptureOffsets', () {
    test('captures a single viewport when there is nothing to scroll', () {
      expect(
        ScreenCapture.planCaptureOffsets(
          viewportHeight: 800,
          maxScrollExtent: 0,
        ),
        [0.0],
      );
    });

    test('walks a scrolled screen and stays under the cap', () {
      final offsets = ScreenCapture.planCaptureOffsets(
        viewportHeight: 800,
        maxScrollExtent: 100000,
      );

      expect(offsets.length, ScreenCapture.maxPages);
      expect(offsets.first, 0.0);
      expect(
        offsets,
        orderedEquals(
          List<double>.from(offsets)..sort(),
        ),
        reason: 'offsets must increase monotonically',
      );
    });

    test('never scrolls past the end of the content', () {
      final offsets = ScreenCapture.planCaptureOffsets(
        viewportHeight: 800,
        maxScrollExtent: 1200,
      );

      expect(offsets.every((o) => o < 1200), isTrue);
      // 1200 is only 1.5 viewports, so a handful of slices covers it.
      expect(offsets.length, lessThanOrEqualTo(2));
    });

    test('starts at the viewport the user was looking at', () {
      final offsets = ScreenCapture.planCaptureOffsets(
        viewportHeight: 800,
        maxScrollExtent: 5000,
        startOffset: 2400,
      );

      expect(offsets.first, 2400);
      expect(
        offsets.every((o) => o >= 2400),
        isTrue,
        reason: 'capture must not jump above the current position',
      );
    });

    test('falls back to a single offset for a degenerate viewport', () {
      expect(
        ScreenCapture.planCaptureOffsets(
          viewportHeight: 0,
          maxScrollExtent: 5000,
        ),
        [0.0],
      );
    });
  });

  group('ScreenCapture.captureVisibleScreen', () {
    testWidgets('returns no pages when the app root boundary is absent',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(
          await tester.runAsync(ScreenCapture.captureVisibleScreen), isEmpty);
    });

    testWidgets('captures a non-scrolling screen as a single page',
        (tester) async {
      final pages = await _capture(
        tester,
        child: const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Center(child: Text('on screen')),
        ),
      );

      expect(pages, hasLength(1));
      expect(pages.single, isNotEmpty);
      // A PNG always starts with the 8-byte PNG signature.
      expect(pages.single.take(4), _onePixelPng.take(4));
    });

    testWidgets('captures content below the fold of a scrollable screen',
        (tester) async {
      final pages = await _capture(
        tester,
        child: ListView.builder(
          itemCount: 300,
          itemBuilder: (context, index) => SizedBox(
            height: 80,
            child: Text('row $index'),
          ),
        ),
      );

      // More than one page proves the scroll view was walked rather than only
      // the visible viewport being captured.
      expect(pages.length, greaterThan(1));
      expect(pages.length, lessThanOrEqualTo(ScreenCapture.maxPages));
    });

    testWidgets('restores the original scroll position', (tester) async {
      final controller = ScrollController(initialScrollOffset: 400);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: ScreenCapture.rootBoundaryKey,
              child: ListView.builder(
                controller: controller,
                itemCount: 400,
                itemBuilder: (context, index) => SizedBox(
                  height: 80,
                  child: Text('row $index'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await ScreenCapture.captureVisibleScreen();
      });

      expect(controller.offset, 400);
    });

    testWidgets('clears the busy flag after capturing', (tester) async {
      await _capture(
        tester,
        child: ListView.builder(
          itemCount: 300,
          itemBuilder: (context, index) => SizedBox(
            height: 80,
            child: Text('row $index'),
          ),
        ),
      );

      expect(ScreenCapture.busy.value, isFalse);
    });
  });
}
