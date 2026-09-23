// Real-app table benchmark — the LaunchDataTable hot path.
//
// LaunchDataTable is the most-used table widget in the app (31 usages across 8
// screens), so its row cost is the app's table cost. This benchmark renders it
// with 100, 500 and 1000 rows so the list-virtualization work has a number
// attached, and it asserts a budget so the cost cannot silently regress.
//
// The table is benchmarked exactly as screens embed it — inside the page's own
// vertical SingleChildScrollView — because that nesting is what forces the
// eager `Column(children: rows)` body.
//
// Budgets are widget-test (debug) numbers with headroom for slower CI machines:
// they exist to catch catastrophic regressions, not to pin an exact figure.
//
// Run: flutter test test/perf/app_table_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/widgets/launch_data_table.dart';

import 'scaffold.dart';

Widget _table(int rows, {double? virtualizedBodyHeight}) => LaunchDataTable(
      title: 'Benchmark table',
      columns: const [
        LaunchColumn(label: 'Name', flexible: true),
        LaunchColumn(label: 'Role', width: 140),
        LaunchColumn(label: 'Status', width: 120),
      ],
      rowCount: rows,
      virtualizedBodyHeight: virtualizedBodyHeight,
      cellBuilder: (context, i) => LaunchDataRow(
        cells: [
          Text('Row $i'),
          Text('Role $i'),
          Text('Status $i'),
        ],
      ),
    );

Widget _page(Widget table) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: table),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // A virtualized body must not open a fixed empty panel for a short table:
  // the viewport follows the content up to the caller's cap.
  testWidgets('virtualized body follows the content up to its cap',
      (tester) async {
    await tester.pumpWidget(_page(_table(3, virtualizedBodyHeight: 520)));
    expect(tester.getSize(find.byType(ListView)).height, 3 * 56);

    await tester.pumpWidget(_page(_table(20, virtualizedBodyHeight: 520)));
    expect(tester.getSize(find.byType(ListView)).height, 520);
  });

  // The 41 tables migrated across the 12 launch screens share this shape: a
  // mix of editable, date and dropdown cells. Measured here rather than by
  // pumping each screen, because several of those screens need Firestore or
  // providers a widget test cannot supply — the cost measured is the row cost
  // those screens now pay, on the same widget classes with the same cap.
  Widget migratedShape(int rows, {double? cap}) => LaunchDataTable(
        title: 'Migrated table shape',
        columns: const [
          LaunchColumn(label: 'Item', flexible: true),
          LaunchColumn(label: 'Owner', width: 160),
          LaunchColumn(
              label: 'Status',
              width: 160,
              fieldType: LaunchFieldType.dropdown,
              dropdownItems: ['Open', 'In Progress', 'Closed']),
          LaunchColumn(label: 'Notes', width: 160),
        ],
        rowCount: rows,
        virtualizedBodyHeight: cap,
        cellBuilder: (context, i) => LaunchDataRow(
          onEdit: () {},
          cells: [
            LaunchEditableCell(value: 'Item $i', onChanged: (v) {}),
            LaunchEditableCell(value: 'Owner $i', onChanged: (v) {}),
            LaunchStatusDropdown(
              value: 'Open',
              items: const ['Open', 'In Progress', 'Closed'],
              onChanged: (v) {},
            ),
            Text('Note $i'),
          ],
        ),
      );

  // Eager and capped are measured in separate benchmarks: pumping the capped
  // table in the same test would bill the eager tree's teardown to it.
  for (final rows in [500, 1000]) {
    benchmark('migrated-shape-eager-$rows-rows', (report) async {
      report.tester.view.physicalSize = const Size(1600, 1200);
      report.tester.view.devicePixelRatio = 1.0;
      addTearDown(report.tester.view.reset);

      final stopwatch = Stopwatch()..start();
      await report.tester.pumpWidget(_page(migratedShape(rows)));
      stopwatch.stop();
      report.record('eager-build-$rows-rows', stopwatch.elapsedMilliseconds);
    });

    benchmark('migrated-shape-capped-$rows-rows', (report) async {
      report.tester.view.physicalSize = const Size(1600, 1200);
      report.tester.view.devicePixelRatio = 1.0;
      addTearDown(report.tester.view.reset);

      final stopwatch = Stopwatch()..start();
      await report.tester
          .pumpWidget(_page(migratedShape(rows, cap: launchTableBodyCap)));
      stopwatch.stop();
      report.record('capped-build-$rows-rows', stopwatch.elapsedMilliseconds);
      await report.recordSettle('capped-settle-$rows-rows');
    });
  }

  // Eager body: every row is built and laid out, however long the table is.
  for (final rows in [100, 500, 1000]) {
    benchmark('launch-table-$rows-rows', (report) async {
      final stopwatch = Stopwatch()..start();
      await report.tester.pumpWidget(_page(_table(rows)));
      stopwatch.stop();
      report.record('build-$rows-rows', stopwatch.elapsedMilliseconds);
      await report.recordSettle('settle-$rows-rows');
      if (rows == 1000) {
        expect(
          stopwatch.elapsedMilliseconds,
          lessThanOrEqualTo(3000),
          reason: 'the eager 1000-row body blew its budget — a regression here '
              'is what the virtualized body exists to avoid',
        );
      }
    });
  }

  // Virtualized body (opt-in viewport): only the visible rows are built, so the
  // cost should stop growing with rowCount.
  for (final rows in [100, 500, 1000]) {
    benchmark('launch-table-virtualized-$rows-rows', (report) async {
      final stopwatch = Stopwatch()..start();
      await report.tester.pumpWidget(
          _page(_table(rows, virtualizedBodyHeight: 520)));
      stopwatch.stop();
      report.record('build-$rows-rows', stopwatch.elapsedMilliseconds);
      await report.recordSettle('settle-$rows-rows');
      if (rows == 1000) {
        expect(
          stopwatch.elapsedMilliseconds,
          lessThanOrEqualTo(250),
          reason: 'the virtualized 1000-row body should stay well under the '
              'eager budget — it builds only the visible rows',
        );
      }
    });
  }
}
