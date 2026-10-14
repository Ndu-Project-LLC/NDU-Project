// The app's editable tables (live inputs as cells, so Flutter's DataTable
// cannot build them) used to render the same fixed-width row at every width. On
// a phone that meant a six- or ten-column row inside a horizontal scroll view:
// the user saw the first column and a sliver of the second, and had to drag
// sideways to reach the rest of the row.
//
// `EditableTable` now switches on `AppBreakpoints.isMobile`: the table on
// tablets and up, one labelled card per row on phones, with no horizontal
// scrolling at all. These tests pin both presentations, including the
// `EditableTableRow` subclass the contracts table builds its rows with.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/widgets/editable_table.dart';

/// The widths the app's own audit uses: the narrowest supported phone and the
/// device the design reviews are done on.
const _phone = Size(360, 800);

const _columns = [
  EditableTableColumn('Milestone', 220),
  EditableTableColumn('Target date', 140),
  EditableTableColumn('', 64),
];

EditableTableRow _row(String name, String date) => EditableTableRow(
      columns: _columns,
      cells: [
        Text(name),
        Text(date),
        const Icon(Icons.edit_outlined, size: 16),
      ],
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

/// A card presentation has no sideways scroll view anywhere inside it — that
/// scroll view is the defect, not an implementation detail: it is what hides
/// every column after the first behind a drag.
void _expectNoSidewaysScrolling(WidgetTester tester) {
  final sideways = find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  );
  expect(sideways, findsNothing,
      reason: 'a phone-width table must lay its columns out, not scroll them');
}

void main() {
  testWidgets('phone width renders one labelled card per row', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      EditableTable(
        columns: _columns,
        rows: [_row('Pilot launch', 'June 30, 2027')],
      ),
    ));

    expect(tester.takeException(), isNull);
    _expectNoSidewaysScrolling(tester);

    // The value is visible without scrolling sideways...
    expect(find.text('Pilot launch'), findsOneWidget);
    expect(find.text('June 30, 2027'), findsOneWidget);
    // ...and it carries its column heading as a label.
    expect(find.text('MILESTONE'), findsOneWidget);
    expect(find.text('TARGET DATE'), findsOneWidget);

    // The date sat in the table's second column, at x = 220 in a 424px-wide
    // table, so on a 360px phone it used to be off the right-hand edge.
    final date = tester.getRect(find.text('June 30, 2027'));
    expect(date.right, lessThanOrEqualTo(_phone.width));

    // The card is the width of the phone, not of the table.
    expect(tester.getSize(find.byType(EditableTable)).width,
        lessThanOrEqualTo(_phone.width));
  });

  testWidgets('phone width labels every row, one card each', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      EditableTable(
        columns: _columns,
        rows: [
          _row('Pilot launch', 'June 30, 2027'),
          _row('Commercial launch', 'August 25, 2027'),
        ],
      ),
    ));

    expect(tester.takeException(), isNull);
    _expectNoSidewaysScrolling(tester);

    // A table has one heading row, so 'MILESTONE' would appear once; cards show
    // the heading on every row.
    expect(find.text('MILESTONE'), findsNWidgets(2));
    expect(find.text('Pilot launch'), findsOneWidget);
    expect(find.text('Commercial launch'), findsOneWidget);
  });

  testWidgets('phone width keeps an unlabelled actions column full width',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      EditableTable(
        columns: _columns,
        rows: [_row('Pilot launch', 'June 30, 2027')],
      ),
    ));

    expect(tester.takeException(), isNull);
    _expectNoSidewaysScrolling(tester);

    // The empty heading marks a row action, which gets the full card width
    // rather than an (empty) label gutter — so the icon is reachable.
    final edit = tester.getRect(find.byIcon(Icons.edit_outlined));
    expect(edit.right, lessThanOrEqualTo(_phone.width));
    expect(edit.height, greaterThan(0));
    expect(find.text(''), findsNothing);
  });

  testWidgets('a row widget that extends EditableTableRow still gets cards',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The contracts table derives its cells from a model, so its row is a
    // subclass rather than a literal EditableTableRow.
    await tester.pumpWidget(_host(
      EditableTable(
        columns: _columns,
        rows: [
          _DerivedRow(
            key: const ValueKey('contract-1'),
            columns: _columns,
            name: 'Build contract',
            date: 'March 3, 2027',
          ),
          _DerivedRow(
            key: const ValueKey('contract-2'),
            columns: _columns,
            name: 'Supply contract',
            date: 'April 4, 2027',
          ),
        ],
      ),
    ));

    expect(tester.takeException(), isNull);
    _expectNoSidewaysScrolling(tester);

    expect(find.text('MILESTONE'), findsNWidgets(2));
    expect(find.text('Build contract'), findsOneWidget);
    expect(find.text('Supply contract'), findsOneWidget);
    expect(find.text('TARGET DATE'), findsNWidgets(2));
    expect(find.text('April 4, 2027'), findsOneWidget);
  });

  testWidgets('tablet width keeps the table, and scrolls sideways when needed',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          child: EditableTable(
            columns: _columns,
            rows: [_row('Pilot launch', 'June 30, 2027')],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    // The heading row is back, uppercase, and the table can scroll.
    expect(find.text('MILESTONE'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollView.scrollDirection, Axis.horizontal);
  });

  testWidgets('the sheet variant still draws one bordered sheet on tablet',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableTable(
          variant: EditableTableVariant.sheet,
          columns: _columns,
          rows: [_row('Kabwe water works', 'April 15, 2027')],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('KABWE WATER WORKS'), findsNothing);
    expect(find.text('Kabwe water works'), findsOneWidget);
    expect(find.text('MILESTONE'), findsOneWidget);
  });
}

/// A row that computes its cells from a model, the way the contracts table does.
class _DerivedRow extends EditableTableRow {
  _DerivedRow({
    super.key,
    required super.columns,
    required String name,
    required String date,
  }) : super(
          cells: [
            Text(name),
            Text(date),
            const Icon(Icons.edit_outlined, size: 16),
          ],
        );
}
