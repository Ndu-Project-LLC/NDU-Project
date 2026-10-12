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
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

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

  testWidgets('standard DataTable becomes labeled cards at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = false;
    final table = NduResponsiveDataTable(
      columns: const [
        DataColumn(label: Text('Requirement')),
        DataColumn(label: Text('Status')),
      ],
      rows: [
        DataRow(
          selected: selected,
          onSelectChanged: (value) => selected = value ?? false,
          cells: const [
            DataCell(Text('Encrypt stored data')),
            DataCell(Text('Open'))
          ],
        ),
      ],
    );

    await tester.pumpWidget(_host(table, width: 390, height: 700));

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(NduDataTableCards), findsOneWidget);
    expect(find.text('Requirement'), findsOneWidget);
    expect(find.text('Encrypt stored data'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Encrypt stored data'));
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('responsive NDU builder uses row cards on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Widget table;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          table = buildNduDataTable(
            context: context,
            columns: const [DataColumn(label: Text('Name'))],
            rows: const [
              DataRow(cells: [DataCell(Text('Mobile row'))])
            ],
          );
          return Scaffold(body: table);
        },
      ),
    ));

    expect(table, isA<NduDataTableCards>());
    expect(find.text('Mobile row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrapped table builder uses labeled cards on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: buildWrappedDataTable(
            context: context,
            columns: const [DataColumn(label: Text('Requirement'))],
            rows: const [
              DataRow(cells: [DataCell(Text('Wrapped mobile row'))]),
            ],
          ),
        ),
      ),
    ));

    expect(find.byType(NduDataTableCards), findsOneWidget);
    expect(find.text('Requirement'), findsOneWidget);
    expect(find.text('Wrapped mobile row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive tables retain DataTable on desktop', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const NduResponsiveDataTable(
        columns: [DataColumn(label: Text('Name'))],
        rows: [
          DataRow(cells: [DataCell(Text('Desktop row'))])
        ],
      ),
      width: 1024,
    ));

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(NduDataTableCards), findsNothing);
    expect(find.text('Desktop row'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
