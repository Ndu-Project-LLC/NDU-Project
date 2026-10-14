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
| `list_rendering_test.dart` | Build / scroll time for a synthetic ListView.builder with 100 / 1000 rows | < 16 ms per frame (60 Hz) |
| `app_table_test.dart` | **The real app widgets:** `LaunchDataTable` (31 usages) eager vs virtualized at 100 / 500 / 1000 rows, inside the page scroll view screens actually use it in | eager 1000-row build ≤ 3000 ms, virtualized ≤ 250 ms (see budgets in the file) |
| `navigation_test.dart` | (Planned) Route transition time between heavy screens | < 200 ms |
| `memory_test.dart` | (Planned) Heap size after navigating through N screens | < 200 MB |

### `LaunchDataTable.virtualizedBodyHeight`

The table body has no bounded height of its own (pages embed the table inside
their own vertical scroll view), so it builds every row eagerly. Passing
`virtualizedBodyHeight` gives the body its own viewport and only the visible
rows run their `cellBuilder`. Opt in per table; the eager path is the default
and is unchanged.

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

## Measurements

All numbers are from `flutter test test/perf/` in **debug mode on a laptop**
(widget-test wall clock, single run — treat them as relative, not absolute).
Release numbers on the real target come from DevTools or the integration
benchmarks.

The first benchmark of a file pays Flutter's first-pump warm-up (~600 ms), so
the 100-row figures read high; the 500/1000-row figures are the comparable ones.

### 2026-09-21 — Phase 0 baseline + Phase 1 `LaunchDataTable` virtualization

| Benchmark | Eager body (baseline) | Virtualized body |
|-----------|----------------------|------------------|
| launch-table-100-rows build | 784 ms (warm-up) | 88 ms |
| launch-table-100-rows settle | 17 ms | 9 ms |
| launch-table-500-rows build | 633 ms | 35 ms |
| launch-table-500-rows settle | 48 ms | 3 ms |
| launch-table-1000-rows build | 812 ms | 27 ms |
| launch-table-1000-rows settle | 33 ms | 4 ms |

The virtualized body's cost is flat in row count (35 ms at 500 rows, 27 ms at
1000), while the eager body's grows with it — that is the property the budget
asserts now guard.

### 2026-09-21 — Phase 1 call sites: 41 tables across 12 screens

Every `LaunchDataTable` in the app (41 of them, across 12 launch screens) now
passes `virtualizedBodyHeight: launchTableBodyCap`, so they all render through
the measured path above. They share one cell shape (editable + dropdown +
text cells with a row action), measured here rather than by pumping each screen
because several of those screens need Firestore or providers a widget test
cannot supply:

| Migrated table shape | Eager body | Capped body |
|----------------------|-----------|-------------|
| 500 rows build | 1623 ms | 38 ms |
| 1000 rows build | 1948 ms | 31 ms |
| 1000 rows settle | — | 3 ms |

Correctness of the migration is guarded by
`test/screens/launch_table_virtualization_smoke_test.dart` (11 screens build
their table with the capped body). Five screens are note-worthy there:
`training_project_tasks_screen` needs a Firebase app before its table renders,
`identify_staff_ops_team_screen` builds its table behind a future that never
resolves under test, and four screens (`contract_close_out`,
`deliver_project_closure`, `project_close_out`, `transition_to_prod_team`)
already threw a `RenderFlex` overflow at the test viewport *before* the
migration — verified by forcing the eager body — so they are asserted to build
the table rather than to be exception-free.

| Benchmark | Value | Date measured |
|-----------|-------|---------------|
| cold-start.first-frame | 341 ms (placeholder app — see note) | 2026-09-21 |
| cold-start.initial-settle | 0 ms | 2026-09-21 |
| list-render-100-rows.build-100-rows | 625 ms | 2026-09-21 |
| list-render-1000-rows.build-1000-rows | 138 ms | 2026-09-21 |
| list-render-1000-rows.settle-1000-rows | 12 ms | 2026-09-21 |
| list-scroll-100-rows.scroll-100-rows | 367 ms | 2026-09-21 |

**Note on `cold_start_test.dart`:** it still pumps the placeholder `MyApp`
(`_import()` returns a stub), so its numbers do not measure this app's startup
at all — the real ~210 eagerly imported screens in `app_router.dart` are not in
that measurement. Replacing it with a real cold-start benchmark (or an
`integration_test` run) is still open.

After each phase is merged, re-run the suite and update the tables above. The
diff between baseline and post-phase is the measurable improvement.
