// Performance benchmark scaffold for the NDU Project Flutter app.
//
// This file establishes the shared helpers used by every benchmark in
// test/perf/. Each benchmark measures the wall-clock time of a specific
// operation (startup, navigation, list rendering, etc.) and prints a
// structured result line that the CI runner can collect.
//
// Usage in a benchmark file:
//
//   import 'scaffold.dart';
//
//   void main() => benchmark('cold-start', (report) async {
//     final stopwatch = Stopwatch()..start();
//     await pumpApp(report.tester);
//     report.record('first-frame', stopwatch.elapsedMilliseconds);
//   });
//
// Run benchmarks with:
//   flutter test test/perf/ --release --platform chrome
//
// All benchmarks require the Flutter SDK (NOT available in the agent's
// sandbox) — the user runs these locally or in CI.


import 'package:flutter_test/flutter_test.dart';

/// Result of a single measurement within a benchmark.
class PerfResult {
  PerfResult(this.label, this.milliseconds, {this.unit = 'ms'});
  final String label;
  final int milliseconds;
  final String unit;

  @override
  String toString() => 'PERF|$label|$milliseconds$unit';
}

/// Collects measurements during a benchmark run.
class PerfReport {
  PerfReport(this.name, this.tester);
  final String name;
  final WidgetTester tester;
  final List<PerfResult> results = [];

  void record(String label, int milliseconds, {String unit = 'ms'}) {
    final r = PerfResult(label, milliseconds, unit: unit);
    results.add(r);
    // Print to stdout so CI can grep the lines out.
    // ignore: avoid_print
    print(r);
  }

  /// Convenience for frame-budget checks: pass the result of
  /// `tester.pumpAndSettle()` and this records the time it took to settle.
  Future<void> recordSettle(String label) async {
    final stopwatch = Stopwatch()..start();
    await tester.pumpAndSettle();
    stopwatch.stop();
    record(label, stopwatch.elapsedMilliseconds);
  }
}

/// Run a benchmark function and print a header/footer around it.
void benchmark(String name, Future<void> Function(PerfReport) body) {
  testWidgets('perf: $name', (tester) async {
    final report = PerfReport(name, tester);
    // ignore: avoid_print
    print('=== PERF START: $name ===');
    await body(report);
    // ignore: avoid_print
    print('=== PERF END: $name ===');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Assert that a measurement stayed within a frame budget.
/// Use 16 ms for 60 Hz, 8 ms for 120 Hz.
void expectWithinBudget(PerfResult result, int budgetMs) {
  expect(
    result.milliseconds,
    lessThanOrEqualTo(budgetMs),
    reason:
        '${result.label} took ${result.milliseconds}ms, budget is ${budgetMs}ms',
  );
}
