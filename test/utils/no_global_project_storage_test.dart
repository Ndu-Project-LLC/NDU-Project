import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard: **no project-owned data may be persisted to a global
/// SharedPreferences key.**
///
/// The Planning Phase modules (WBS, Cost Estimate, Schedule) and the PBS each
/// used to write their entire state under a single global key, so opening a
/// different project showed whichever project was edited last — one project's
/// deliverable tree, cost lines, activities or product breakdown appearing
/// inside another project.
///
/// Every one of them now writes per project through
/// [projectScopedPrefsKey] (`lib/utils/project_scoped_storage.dart`), and the
/// old global entries are adopted once, by the project they belong to.
///
/// These assertions read the source on purpose: they fail at the moment a NEW
/// store is added with a global key, before it can leak anything at runtime.
///
/// If a failure here looks wrong, the fix is almost always to scope the key by
/// project (or, for user/UI-level preferences only, to add the store to
/// [globalPreferenceStores] with a reason).

/// Stores that keep user/UI-level preferences rather than project data. Keys
/// here are intentionally shared by every project, so they are exempt.
const Map<String, String> globalPreferenceStores = {
  'lib/providers/theme_provider.dart':
      'The light/dark/system choice is a user preference, not project data.',
  'lib/services/currency_service.dart':
      'The display currency is a user preference, not project data.',
  'lib/providers/app_content_provider.dart':
      'Admin content overrides are app-wide copy, not project data.',
  'lib/providers/display_preferences_provider.dart':
      'Font size, compact mode, reduced animations, and the speech-to-text '
      'toggle describe the person using the app, not the project they are '
      'working on.',
};

/// `class X extends ChangeNotifier` / `with ChangeNotifier` / mixes both.
final RegExp _notifier =
    RegExp(r'class\s+\w+[^{]*\bChangeNotifier\b');

/// SharedPreferences read/write calls, capturing the method verb and the key
/// argument (`prefs.getString(key)`, `prefs.setBool('x', v)`, …). Matches any
/// instance name, not just `prefs`.
final RegExp _prefsCall = RegExp(
  r'\.(set|get)(?:String|StringList|Bool|Int|Double)\(\s*([^,)\n]+)',
);

/// `Name = 'literal'` declarations (const/final/static/String), used to resolve
/// an identifier key back to the literal it holds.
final RegExp _stringLiteralDecl =
    RegExp(r"(?:String|var)\s+([A-Za-z_]\w*)\s*=\s*'([^']*)'");

/// The shape of the original bug: one global key for a whole module.
final RegExp _globalKeyConst = RegExp(r'const\s+String\s+_storageKey\s*=');

/// Package root, found by walking up for `pubspec.yaml` (tests run from the
/// package root, but this keeps the test working from any cwd).
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

/// Files that persist to SharedPreferences AND keep state in a ChangeNotifier —
/// i.e. the module/project data stores this test is about.
Map<String, String> _dataStores(Map<String, String> sources) {
  final out = <String, String>{};
  sources.forEach((path, source) {
    if (!source.contains('SharedPreferences')) return;
    if (!_notifier.hasMatch(source)) return;
    if (!RegExp(r'\.set(?:String|StringList|Bool|Int|Double)\(')
        .hasMatch(source)) {
      return;
    }
    if (globalPreferenceStores.containsKey(path)) return;
    out[path] = source;
  });
  return out;
}

/// Resolves a prefs key argument to its literal value, or null when the key is
/// built at runtime (interpolation, function call, parameter).
String? _literalKey(String argument, Map<String, String> fileLiterals) {
  final arg = argument.trim();
  if (arg.startsWith("'")) {
    final end = arg.lastIndexOf("'");
    if (end <= 0) return null;
    final value = arg.substring(1, end);
    return value.contains(r'$') ? null : value;
  }
  if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(arg)) return fileLiterals[arg];
  return null;
}

void main() {
  late Map<String, String> sources;

  setUpAll(() => sources = _libSources());

  test('project data stores are found (the scan is really reading the code)',
      () {
    final stores = _dataStores(sources);
    expect(
      stores.keys,
      containsAll(<String>[
        'lib/wbs/providers/wbs_provider.dart',
        'lib/cost_estimate/providers/cost_estimate_provider.dart',
        'lib/schedule/providers/schedule_provider.dart',
        'lib/pbs/providers/pbs_provider.dart',
      ]),
      reason: 'If these are missing the scan regexes have gone stale, and the '
          'guard below is checking nothing.',
    );
  });

  test('every project data store persists per project', () {
    final offenders = <String>[];

    _dataStores(sources).forEach((path, source) {
      final missing = <String>[
        if (!source.contains('projectScopedPrefsKey('))
          'no projectScopedPrefsKey() — keys must be scoped to a project',
        if (!RegExp(r'get\s+activeProjectId\b').hasMatch(source))
          'no `get activeProjectId` — callers cannot tell which project it holds',
      ];
      if (missing.isNotEmpty) offenders.add('$path:\n    - ${missing.join('\n    - ')}');
    });

    expect(
      offenders,
      isEmpty,
      reason: 'These stores persist state that belongs to a project, so writing '
          'it to a global key would show one project\'s content inside another.\n'
          'Scope the key with projectScopedPrefsKey() and expose activeProjectId '
          '(see lib/utils/project_scoped_storage.dart), or — for user/UI-level '
          'preferences only — add the file to globalPreferenceStores with a '
          'reason.\n\n${offenders.join('\n')}',
    );
  });

  test('no project data store keeps a single global key constant', () {
    final offenders = <String>[
      for (final entry in _dataStores(sources).entries)
        if (_globalKeyConst.hasMatch(entry.value)) entry.key,
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'A single `const String _storageKey` is the exact shape of the '
          'original cross-project leak — one key shared by every project. Use a '
          '`_storageName` (or equivalent) plus projectScopedPrefsKey().\n'
          '${offenders.join('\n')}',
    );
  });

  test('module-namespaced keys are never written directly', () {
    final offenders = <String>[];

    sources.forEach((path, source) {
      if (!source.contains('SharedPreferences')) return;

      final literals = <String, String>{};
      for (final match in _stringLiteralDecl.allMatches(source)) {
        literals[match.group(1)!] = match.group(2)!;
      }

      for (final match in _prefsCall.allMatches(source)) {
        final isWrite = match.group(1) == 'set';
        final literal = _literalKey(match.group(2)!, literals);
        // Runtime-built keys (interpolation, helper functions) are covered by
        // the store-level assertions above.
        if (literal == null) continue;
        // `ndu_*` is the module data namespace. User/UI preferences use their
        // own prefixes (`pref_`, `user_`, `secure_`, `remembered_`, …).
        if (!literal.startsWith('ndu_')) continue;

        if (isWrite) {
          offenders.add(
              '$path writes the global module key "$literal" directly — writes '
              'must go through projectScopedPrefsKey()');
        } else if (!source.contains('projectScopedPrefsKey(')) {
          offenders.add(
              '$path reads the module key "$literal" without '
              'projectScopedPrefsKey()');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'A global `ndu_*` key may only be read, as the one-time legacy '
          'record of a store that also scopes its keys per project (see '
          'lib/utils/project_scoped_storage.dart).\n${offenders.join('\n')}',
    );
  });

  test('the global-preference allow-list cannot rot', () {
    final missing = <String>[
      for (final path in globalPreferenceStores.keys)
        if (!sources.containsKey(path)) path,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'These files are exempted from the project-scoping guard but no '
          'longer exist — update globalPreferenceStores in this test.\n'
          '${missing.join('\n')}',
    );
  });
}
