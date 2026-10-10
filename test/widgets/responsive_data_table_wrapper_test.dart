// A table whose columns are divided with `Expanded` must survive the wrapper.
//
// `ResponsiveDataTableWrapper` scrolls horizontally, and a horizontally
// scrolling viewport hands its child an *unbounded* width. A `Row` with flexed
// children cannot resolve against infinity, so layout threw
// `RenderFlex children have non-zero flex but incoming width constraints are
// unbounded`. That is a layout failure, not a build failure: it poisons the
// whole page's render subtree, which is how a page ends up with a live sidebar
// and header and an empty body and no console output to explain it.
//
// The wrapper now gives its child one definite width — the viewport, or
// `minWidth` when the table must not shrink below it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// One table row built the way the app's shared table primitives build theirs.
Widget _flexRow(String label) {
  return Row(
    children: [
      Expanded(flex: 2, child: Text('$label A')),
      Expanded(flex: 5, child: Text('$label B')),
      Expanded(flex: 3, child: Text('$label C')),
    ],
  );
}

Widget _host(Widget child, {double width = 420, double height = 300}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('a flexed table lays out at the viewport width', (tester) async {
    await tester.pumpWidget(_host(ResponsiveDataTableWrapper(
      minWidth: 0,
      maxHeight: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_flexRow('Row 1'), _flexRow('Row 2')],
      ),
    )));

    expect(tester.takeException(), isNull,
        reason: 'An unbounded width must never reach a flexed table row.');

    final row = tester.widget<Row>(find.byType(Row).first);
    expect(row.children.length, 3);
    expect(find.text('Row 1 A'), findsOneWidget);
    expect(find.text('Row 2 C'), findsOneWidget);

    // And the columns actually divided the available width.
    final firstCell = tester.getSize(find.text('Row 1 A').first);
    expect(firstCell.width, greaterThan(0));
  });

  testWidgets('minWidth still wins, so the table scrolls instead of squashing',
      (tester) async {
    await tester.pumpWidget(_host(ResponsiveDataTableWrapper(
      minWidth: 720,
      maxHeight: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_flexRow('Row 1')],
      ),
    )));

    expect(tester.takeException(), isNull);

    final table = tester.getSize(find.byType(SingleChildScrollView).first);
    // The wrapper itself is the width of the viewport it was given...
    expect(table.width, 420);
    // ...while the table content inside it is the requested 720.
    final content = tester.getSize(find.descendant(
      of: find.byType(SingleChildScrollView).first,
      matching: find.byType(Column).first,
    ));
    expect(content.width, 720);
  });

  testWidgets('an unbounded parent falls back to a readable width',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResponsiveDataTableWrapper(
            maxHeight: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_flexRow('Row 1')],
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Row 1 B'), findsOneWidget);
  });
}
