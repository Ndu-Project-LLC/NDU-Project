# NDU Project — Performance Benchmark Suite

This directory contains the performance benchmark suite for the NDU Project
Flutter app. It is part of the multi-phase performance overhaul.

## Running the benchmarks

The benchmark suite requires the **Flutter SDK** to run. It is NOT part of
the default `flutter test` run — it must be invoked explicitly.

### Prerequisites

```bash
# From the project root:
flutter pub get
```

### Running all benchmarks

```bash
# Web (Chrome) — release mode for realistic numbers
flutter test test/perf/ --release --platform chrome

# Desktop (macOS / Linux / Windows) — release mode
flutter test test/perf/ --release
```

### Running a single benchmark

```bash
flutter test test/perf/cold_start_test.dart --release --platform chrome
flutter test test/perf/list_rendering_test.dart --release --platform chrome
```

### Interpreting the output

Each benchmark prints structured `PERF|<label>|<milliseconds>ms` lines to
stdout, wrapped in `=== PERF START: <name> ===` / `=== PERF END: <name> ===`
markers. Example:

```
=== PERF START: list-render-100-rows ===
PERF|build-100-rows|42ms
PERF|settle-100-rows|58ms
=== PERF END: list-render-100-rows ===
```

To collect results in CI:

```bash
flutter test test/perf/ --release --platform chrome 2>&1 \
  | grep '^PERF|' > perf-results.tsv
```

## Benchmark inventory

| Benchmark file | What it measures | Target |
|----------------|------------------|--------|
| `cold_start_test.dart` | Time from app launch to first frame | < 1500 ms (release, web) |
| `list_rendering_test.dart` | Build / scroll time for ListView.builder with 100 / 1000 rows | < 16 ms per frame (60 Hz) |
| `navigation_test.dart` | (Planned) Route transition time between heavy screens | < 200 ms |
| `memory_test.dart` | (Planned) Heap size after navigating through N screens | < 200 MB |

## Adding a new benchmark

1. Create `test/perf/<name>_test.dart`.
2. Import `'scaffold.dart'`.
3. Wrap your test in `benchmark('<name>', (report) async { ... })`.
4. Call `report.record('<label>', <milliseconds>)` for each measurement.
5. Document the target in the table above.

## Profiling with DevTools

For deeper analysis, run the app in profile mode and use Flutter DevTools:

```bash
flutter run --profile -d chrome
# Open the DevTools URL printed in the console.
# Use the "Performance" tab to record a trace, then look for:
#   - Frames exceeding the 16 ms budget
#   - Widget rebuilds (filter by rebuild count)
#   - Shader compilations (jank on first occurrence)
```

## Pre-overhaul baseline (record these BEFORE applying Phase 1+ changes)

Run the full benchmark suite on the unmodified `ci-pipeline` branch and
record the results here:

| Benchmark | Baseline (ms) | Date measured |
|-----------|---------------|---------------|
| cold-start.first-frame | TBD | TBD |
| cold-start.initial-settle | TBD | TBD |
| list-render-100-rows.build-100-rows | TBD | TBD |
| list-render-100-rows.settle-100-rows | TBD | TBD |
| list-render-1000-rows.build-1000-rows | TBD | TBD |
| list-render-1000-rows.settle-1000-rows | TBD | TBD |
| list-scroll-100-rows.scroll-100-rows | TBD | TBD |

After each phase is merged, re-run the suite and update this file with the
post-phase numbers. The diff between baseline and post-phase is the
measurable improvement.
