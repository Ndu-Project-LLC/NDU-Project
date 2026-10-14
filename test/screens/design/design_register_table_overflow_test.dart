// The hand-rolled registers on UI/UX Design and Specialized Design built their
// rows from fixed-width cells inside an unbounded `Row`:
//
//   Row(children: [Expanded(flex: 4, ...), SizedBox(width: 130), ...])
//
// Five columns of 90-130px is ~530px of width that cannot shrink, which at
// phone width is a guaranteed `RenderFlex overflowed` — the yellow/black stripe
// the owner saw down the right edge of the table.
//
// Measured, at 353px of usable width (an iPhone 16 minus the card padding), the
// pre-fix composition overflows by 217px.
//
// The fix keeps the columns exactly as wide as they are and gives the table a
// bounded horizontal scroll (`ResponsiveDataTableWrapper`), so a phone scrolls
// the register rather than overflowing it, and a wide screen is laid out
// exactly as before. `Flexible` was tried first and rejected: it removes the
// phone overflow but makes the columns compete for flex space, leaving a dead
// gap on the right — measured 503px at 1900px wide.
//
// The composition below mirrors `_buildTableHeader` / `_buildTableRow` on
// `UiUxDesignScreen` and `SpecializedDesignScreen`.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// The Journey register, as `UiUxDesignScreen` declares its columns.
const _fixedWidths = <double>[130, 110, 90, 100, 100];
const _labels = <String>['TOUCHPOINTS', 'OWNER', 'PRIORITY', 'STATUS', ''];
// 530 of fixed columns + a readable floor for the 4-flex first column.
const _tableMinWidth = 1010.0;

Widget _headerRow() => Row(
      children: [
        const Expanded(flex: 4, child: Text('JOURNEY')),
        for (var i = 0; i < _fixedWidths.length; i++)
          SizedBox(
            width: _fixedWidths[i],
            child: Text(_labels[i], style: const TextStyle(fontSize: 10)),
          ),
      ],
    );

Widget _bodyRow(String label) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: Text('$label journey description text')),
        const SizedBox(width: 130, child: Text('Touchpoints')),
        const SizedBox(width: 110, child: Text('Owner')),
        const SizedBox(width: 90, child: Text('Priority')),
        const SizedBox(width: 100, child: Text('Status')),
        const SizedBox(width: 100, child: Text('Actions')),
      ],
    );

/// The register as it ships: fixed columns inside the shared scroll wrapper.
Widget _registerAsShipped() => ResponsiveDataTableWrapper(
      minWidth: _tableMinWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerRow(),
          for (var i = 0; i < 6; i++) _bodyRow('Row $i'),
        ],
      ),
    );

/// The register as it was before the fix: no wrapper, no scroll.
Widget _registerBeforeFix() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _headerRow(),
        for (var i = 0; i < 6; i++) _bodyRow('Row $i'),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget table, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: table,
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// How far the rightmost child of [finder] extends past its own box.
double _rightOverflow(WidgetTester tester, Finder finder) {
  final flex = tester.renderObject<RenderFlex>(finder);
  var maxRight = 0.0;
  flex.visitChildren((child) {
    final box = child as RenderBox;
    final data = box.parentData as FlexParentData;
    final right = data.offset.dx + box.size.width;
    if (right > maxRight) maxRight = right;
  });
  return maxRight - flex.size.width;
}

/// Which table row to measure.
enum RowStyle { header, body }

Finder _tableRow(RowStyle style) => style == RowStyle.header
    ? find.ancestor(
        of: find.text('JOURNEY').first,
        matching: find.byType(Row),
      )
    : find.ancestor(
        of: find.text('Row 0 journey description text').first,
        matching: find.byType(Row),
      );

void main() {
  group('before the fix', () {
    testWidgets('the register overflows a phone-width viewport',
        (tester) async {
      await _pump(tester, _registerBeforeFix(), 393);

      // Flutter reports the overflow as a layout error; clear it, then assert
      // the geometry that caused it: the cells run past the row's own box.
      tester.takeException();
      expect(_rightOverflow(tester, _tableRow(RowStyle.header)),
          greaterThan(100),
          reason: 'fixed-width cells must overflow at 393px — this is the bug '
              'the scroll wrapper exists to prevent');
    });
  });

  group('as shipped', () {
    for (final width in const [360.0, 393.0, 427.0]) {
      testWidgets('the register scrolls instead of overflowing at ${width}px',
          (tester) async {
        await _pump(tester, _registerAsShipped(), width);

        expect(tester.takeException(), isNull,
            reason: 'no row may overflow once the table is wrapped');

        // The table is genuinely wider than the viewport, so it scrolls...
        final content = tester.getSize(find.byType(Column).first);
        expect(content.width, greaterThanOrEqualTo(_tableMinWidth),
            reason: 'the register keeps its readable width and scrolls');

        // ...and every column is still there.
        expect(find.text('TOUCHPOINTS'), findsOneWidget);
        expect(find.text('Status'), findsNWidgets(6));
      });
    }

    testWidgets('the register fills a wide viewport, leaving no dead gap',
        (tester) async {
      await _pump(tester, _registerAsShipped(), 1400);

      expect(tester.takeException(), isNull);

      // The table occupies the whole viewport, so nothing is dead space...
      final content = tester.getSize(find.byType(Column).first);
      expect(content.width, 1400 - 40);

      // ...and the columns reach the right edge, leaving no gap on the right.
      // (`Flexible` cells would leave one — measured 503px at 1900px wide.)
      for (final row in const [RowStyle.header, RowStyle.body]) {
        expect(_rightOverflow(tester, _tableRow(row)), closeTo(0, 0.5),
            reason: 'a wide screen must not leave a gap on the right — this is '
                'why the fix is a scroll wrapper and not Flexible cells');
      }
    });
  });
}
