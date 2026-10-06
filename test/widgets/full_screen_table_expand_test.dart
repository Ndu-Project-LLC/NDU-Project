// Tests for the shared table "Expand" affordance (FullScreenTableWrapper in
// wrapped_table_primitives.dart) — the owner's ask, 2026-09-30:
//
//   "When the 'Expand' is clicked, it does not extend to the entire screen
//    across all of them in the application"
//
// Every table in the app expands through this one primitive, so these tests
// pin the contract once: the expanded page must cover the whole window and
// the table inside must span the full body width instead of bunching up at
// its intrinsic size on the left.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

void main() {
  Future<void> pumpHostedTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) => buildWrappedDataTable(
                  context: context,
                  columns: List<DataColumn>.generate(
                      8, (i) => DataColumn(label: Text('Column $i'))),
                  rows: List<DataRow>.generate(
                    6,
                    (r) => DataRow(
                      cells: List<DataCell>.generate(
                          8, (c) => DataCell(Text('R$r C$c'))),
                    ),
                  ),
                  title: 'Expanded Table',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('expanded table spans the entire screen width',
      (tester) async {
    await pumpHostedTable(tester);

    // Open the expanded view.
    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    // The expanded page's scaffold must cover the whole window.
    final scaffoldRect = tester.getRect(find.byType(Scaffold).last);
    expect(scaffoldRect.left, 0.0);
    expect(scaffoldRect.top, 0.0);
    expect(scaffoldRect.width, 1600.0);
    expect(scaffoldRect.height, 1000.0);

    // The table inside must span the full body width: window (1600) minus
    // the page's 16px padding and the 1px card border on each side.
    // Anything narrower is the "doesn't extend to the entire screen" bug.
    final tableRect = tester.getRect(find.byType(DataTable).last);
    expect(tableRect.left, closeTo(17, 2.0),
        reason: 'table starts at the card edge, not bunched mid-screen');
    expect(tableRect.right, closeTo(1583, 2.0),
        reason: 'table reaches the right edge of the screen');
    expect(tableRect.width, greaterThan(1550));
  });

  testWidgets('wide tables still scroll horizontally when expanded',
      (tester) async {
    await pumpHostedTable(tester);

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    // Shrink the window after opening: the table must now overflow and be
    // horizontally scrollable rather than clipped.
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final horizontalScroll = find
        .descendant(
          of: find.byType(Scaffold).last,
          matching: find.byWidgetPredicate((w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal),
        )
        .first;
    final position = tester.state<ScrollableState>(
      find.ancestor(
        of: horizontalScroll,
        matching: find.byType(Scrollable),
      ).first,
    ).position;
    expect(position.maxScrollExtent, greaterThan(0),
        reason: 'a too-wide table must remain scrollable, never clipped');
  });
}
