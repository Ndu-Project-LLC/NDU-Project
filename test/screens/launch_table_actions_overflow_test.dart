import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';

/// Regression test for the yellow/black "RIGHT OVERFLOWED BY 52 PIXELS"
/// marker that used to run down the right edge of every row of the
/// Scope Acceptance table (and every other `LaunchDataTable`).
///
/// Cause: the row-actions column was 96px wide, but Material pads every
/// `IconButton` to the 48px touch-target minimum regardless of the smaller
/// `constraints` passed to it, so KAZ AI + edit + delete needed
/// 3 * 48 + 2 * 2 = 148px and every actions `Row` overflowed its slot.
class _Row {
  const _Row(this.deliverable, this.criteria, this.status, this.date);
  final String deliverable;
  final String criteria;
  final String status;
  final String date;
}

const _rows = <_Row>[
  _Row('Admin Dashboard', 'Admin role CRUD operations verified end-to-end',
      'Pending', '2026-09-04'),
  _Row('API Documentation',
      'All endpoints documented with examples and error codes', 'Accepted',
      '2026-08-28'),
  _Row('Deployment Scripts & CI/CD',
      'Automated deploy to staging succeeds; rollback tested', 'Pending',
      '2026-09-11'),
  _Row('Data Migration Package',
      'Production data migrated with zero data loss verified', 'Partial',
      '2026-09-11'),
];

/// Mirrors `_buildScopeAcceptancePanel` on `DeliverProjectClosureScreen`.
Widget _scopeAcceptanceTable() {
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LaunchDataTable(
            virtualizedBodyHeight: launchTableBodyCap,
            title: 'Scope Acceptance',
            subtitle:
                'Track acceptance status for each deliverable. Items are editable inline.',
            columns: const [
              LaunchColumn(label: 'Deliverable', flexible: true),
              LaunchColumn(label: 'Criteria', flexible: true),
              LaunchColumn(
                label: 'Status',
                width: 120,
                fieldType: LaunchFieldType.dropdown,
                dropdownItems: ['Pending', 'Accepted', 'Partial', 'Rejected'],
              ),
              LaunchColumn(
                  label: 'Date', width: 130, fieldType: LaunchFieldType.date),
            ],
            rowCount: _rows.length,
            onAddValues: (_) {},
            csvColumns: const [
              CsvColumnSpec(
                  key: 'deliverable',
                  label: 'Deliverable',
                  sampleValue: 'User Portal'),
              CsvColumnSpec(
                  key: 'criteria',
                  label: 'Criteria',
                  sampleValue: 'All acceptance tests pass'),
              CsvColumnSpec(
                  key: 'status',
                  label: 'Status',
                  sampleValue: 'Pending',
                  allowedValues: ['Pending', 'Accepted', 'Partial', 'Rejected']),
              CsvColumnSpec(
                  key: 'date', label: 'Date', sampleValue: '2025-01-15'),
            ],
            onCsvImport: (_) async {},
            cellBuilder: (ctx, i) => LaunchDataRow(
              onEdit: () {},
              onDelete: () {},
              onKazAi: () {},
              showDivider: i < _rows.length - 1,
              cells: [
                LaunchEditableCell(
                  value: _rows[i].deliverable,
                  hint: 'Deliverable',
                  expand: true,
                  bold: true,
                  onChanged: (v) {},
                ),
                LaunchEditableCell(
                  value: _rows[i].criteria,
                  hint: 'Criteria',
                  expand: true,
                  onChanged: (v) {},
                ),
                LaunchStatusDropdown(
                  value: _rows[i].status,
                  items: const ['Pending', 'Accepted', 'Partial', 'Rejected'],
                  onChanged: (v) {},
                ),
                LaunchDateCell(
                  value: _rows[i].date,
                  hint: 'Date',
                  width: 130,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The innermost [RenderFlex] ancestor of [child] — for a row-action button
/// that is the actions `Row` inside its fixed-width `SizedBox` slot.
RenderFlex _innermostFlexAncestor(RenderObject child) {
  RenderObject? current = child.parent;
  while (current != null && current is! RenderFlex) {
    current = current.parent;
  }
  return current! as RenderFlex;
}

/// True when [flex]'s children extend past its own box on the right, i.e.
/// the same overflow Flutter marks with the yellow/black striped indicator.
bool _overflowsRight(RenderFlex flex) {
  var maxRight = 0.0;
  flex.visitChildren((child) {
    final box = child as RenderBox;
    final parentData = box.parentData as dynamic;
    final right = parentData.offset.dx + box.size.width;
    if (right > maxRight) maxRight = right;
  });
  return maxRight > flex.size.width + 0.01;
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: _scopeAcceptanceTable()));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final size in const [Size(1052, 992), Size(2105, 986)]) {
    testWidgets('row actions fit their column at ${size.width}px',
        (tester) async {
      await _pumpAt(tester, size);

      // One KAZ AI button per row; each marks the actions Row it lives in.
      final actionsRows = find
          .byTooltip('KAZ AI')
          .evaluate()
          .map((element) =>
              _innermostFlexAncestor(element.findRenderObject()!))
          .toList();

      expect(actionsRows, isNotEmpty,
          reason: 'expected at least one built data row with row actions');
      for (final row in actionsRows) {
        expect(
          _overflowsRight(row),
          isFalse,
          reason: 'actions Row (size ${row.size}) overflows its slot — the '
              'column must fit 3 * 48px buttons + 2 * 2px gaps = 148px',
        );
      }
    });
  }
}
