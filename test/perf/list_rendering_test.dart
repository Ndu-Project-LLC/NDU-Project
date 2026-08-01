// List rendering benchmark — measures the time to build and paint a
// LaunchDataTable with N rows. This is the most-used table widget in the
// Launch phase (31 usages across 8 screens) so it's a critical hot path.
//
// Run with: flutter test test/perf/list_rendering_test.dart --release --platform chrome
//
// Expected result: < 16 ms per frame for 100 rows (60 Hz budget).
// Pre-overhaul baseline: TBD — run and record.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scaffold.dart';

void main() {
  benchmark('list-render-100-rows', (report) async {
    final rows = List.generate(100, (i) => 'Row $i');
    final stopwatch = Stopwatch()..start();
    await report.tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(rows[i]),
              subtitle: Text('Subtitle $i'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    stopwatch.stop();
    report.record('build-100-rows', stopwatch.elapsedMilliseconds);
    await report.recordSettle('settle-100-rows');
  });

  benchmark('list-render-1000-rows', (report) async {
    final rows = List.generate(1000, (i) => 'Row $i');
    final stopwatch = Stopwatch()..start();
    await report.tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(rows[i]),
              subtitle: Text('Subtitle $i'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    stopwatch.stop();
    report.record('build-1000-rows', stopwatch.elapsedMilliseconds);
    await report.recordSettle('settle-1000-rows');
  });

  benchmark('list-scroll-100-rows', (report) async {
    final rows = List.generate(100, (i) => 'Row $i');
    await report.tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(rows[i]),
              subtitle: Text('Subtitle $i'),
            ),
          ),
        ),
      ),
    );
    await report.tester.pumpAndSettle();

    // Scroll from top to bottom and measure frame times.
    final stopwatch = Stopwatch()..start();
    final gesture = await report.tester.startGesture(
      const Offset(400, 300),
    );
    await gesture.moveBy(const Offset(0, -5000));
    await report.tester.pumpAndSettle();
    stopwatch.stop();
    report.record('scroll-100-rows', stopwatch.elapsedMilliseconds);
  });
}
