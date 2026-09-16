import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard: **row ids must not be minted from the clock.**
///
/// The editable tables (components, entities, work packages, checklist rows,
/// staffing and meeting grids, …) key their rows by id and update them with
/// `indexWhere((row) => row.id == updated.id)`. Ids were minted with
/// `DateTime.now().microsecondsSinceEpoch`, and those ids are minted in LOOPS —
/// a dozen seeded rows in one statement, or a batch import. On the web (and on
/// coarser clocks) `DateTime.now()` ticks about once a millisecond, so every
/// row in one loop received the SAME id. The visible effect was that typing in
/// one row changed another: the edit was written to the first row carrying that
/// id, and the two rows ended up holding the same text.
///
/// Every id is now minted through [newId] (`lib/utils/unique_id.dart`), which
/// is unique within the process, and data saved with a duplicated id is
/// repaired on load with [persistedId].
///
/// This test reads the source on purpose: it fails at the moment a new clock
/// derived id is introduced, before it can merge two rows at runtime.
///
/// If a failure here looks wrong, either pass a value from `newId()`, or — when
/// the value is genuinely not an id — add the file to [clockUseAllowList] with a
/// reason.

/// Files that still read the clock for something other than a bare row id.
const Map<String, String> clockUseAllowList = {
  'lib/models/project_data_model.dart':
      'The timestamp is combined with a monotonic counter, so it cannot repeat.',
  'lib/screens/cost_analysis_screen.dart':
      'One timestamp is read once and suffixed with the loop index.',
  'lib/screens/stakeholder_management_screen.dart':
      'The timestamp is combined with a stable per-row suffix.',
  'lib/services/security_services.dart':
      'Used as a Random seed, not as an id.',
  'lib/services/openai_service_secure.dart':
      'The timestamp is combined with a counter or the row index.',
};

/// The shape that merged rows: an id taken straight from the clock.
final RegExp _clockId = RegExp(r'DateTime\.now\(\)\.microsecondsSinceEpoch');

Directory _projectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  return Directory.current;
}

/// Every Dart source under `lib/`, keyed by package-relative path.
Map<String, String> _libSources() {
  final root = _projectRoot();
  final lib = Directory('${root.path}/lib');
  final out = <String, String>{};
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    out[relative] = entity.readAsStringSync();
  }
  return out;
}

void main() {
  late Map<String, String> sources;

  setUpAll(() => sources = _libSources());

  test('the scan is really reading the code', () {
    expect(sources.keys, contains('lib/utils/unique_id.dart'));
    expect(
      sources.values.where((source) => source.contains('newId()')).length,
      greaterThan(20),
      reason: 'If no file mints ids through newId() the guard below is '
          'checking nothing.',
    );
  });

  test('no id is minted from the clock', () {
    final offenders = <String>[];
    sources.forEach((path, source) {
      // The helper is the one place allowed to read the clock: it mixes the
      // timestamp with a counter and a random salt.
      if (path == 'lib/utils/unique_id.dart') return;
      if (clockUseAllowList.containsKey(path)) return;
      if (!_clockId.hasMatch(source)) return;
      offenders.add(path);
    });

    expect(
      offenders,
      isEmpty,
      reason: 'A clock-derived id repeats for every row minted in the same '
          'millisecond, and rows are looked up by id — so an edit lands on the '
          'wrong row. Use newId() from lib/utils/unique_id.dart.\n'
          '${offenders.join('\n')}',
    );
  });

  test('the clock-use allow-list cannot rot', () {
    final stale = <String>[
      for (final path in clockUseAllowList.keys)
        if (!(sources[path] != null && _clockId.hasMatch(sources[path]!)))
          path,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'These files are exempted from the clock-id guard but no longer '
          'read the clock — remove them from clockUseAllowList.\n'
          '${stale.join('\n')}',
    );
  });

  test('the design tables repair duplicated ids when they load', () {
    // Minting unique ids fixes new data; rows already saved with a shared id
    // are only fixed if the load path repairs them.
    final backend = sources['lib/screens/backend_design_screen.dart'];
    expect(backend, isNotNull);
    expect(
      'persistedId('.allMatches(backend!).length,
      greaterThanOrEqualTo(5),
      reason: 'Every decoded list on the screen must pass its stored id '
          'through persistedId(), or a project saved before the fix keeps its '
          'merged rows.',
    );
  });
}
