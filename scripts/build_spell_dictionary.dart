// ─────────────────────────────────────────────────────────────────────────────
// build_spell_dictionary.dart
//
// Generates the word list that backs the app-wide spell checker
// (assets/config/spell_dictionary.txt, loaded by SpellCheckService).
//
//   dart run scripts/build_spell_dictionary.dart
//   dart run scripts/build_spell_dictionary.dart --source /path/to/words
//
// The list is generated from a system dictionary rather than downloaded, so the
// output is reproducible on any machine that has one, and the generated file is
// committed so builds never depend on this script running.
//
// Source candidates, in order:
//   /usr/share/dict/web2              macOS, Webster's Second International
//   /usr/share/dict/words             macOS symlink / Linux (aspell, wamerican)
//   /usr/share/dict/american-english
//   /usr/share/dict/british-english
//
// Filtering: lowercase, ASCII letters only, 2–24 characters, de-duplicated and
// sorted. The list is intentionally inclusive — a word that is present but
// obscure only ever means the checker accepts it; it can never cause a false
// positive. Dropping valid words is what would create noise, so the filter
// removes only things that are not words (punctuation, digits, single letters).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

const List<String> _defaultSources = <String>[
  '/usr/share/dict/web2',
  '/usr/share/dict/words',
  '/usr/share/dict/american-english',
  '/usr/share/dict/british-english',
];

const String _outputPath = 'assets/config/spell_dictionary.txt';

/// Shortest and longest word kept, in characters.
const int _minLength = 2;
const int _maxLength = 24;

/// Words the checker should accept even if the source list lacks them. These are
/// modern/inline forms rather than names, so they belong in the shared list.
const Set<String> _supplement = <String>{
  'agile',
  'agility',
  'analytics',
  'api',
  'apis',
  'app',
  'apps',
  'async',
  'autocomplete',
  'backend',
  'backlog',
  'bim',
  'budgeting',
  'cellphone',
  'chatbot',
  'checklist',
  'checklists',
  'cloud',
  'clouds',
  'config',
  'configs',
  'crm',
  'csv',
  'dashboard',
  'datastore',
  'dataset',
  'datasets',
  'deadline',
  'deadlines',
  'deliverable',
  'deliverables',
  'deployment',
  'deployments',
  'dropdown',
  'downtime',
  'ecosystem',
  'email',
  'emails',
  'endpoint',
  'endpoints',
  'erp',
  'escalation',
  'escalations',
  'escalate',
  'escalated',
  'fields',
  'firewall',
  'firewalls',
  'frontend',
  'geospatial',
  'golive',
  'governance',
  'granularity',
  'handover',
  'handovers',
  'helpdesk',
  'hosting',
  'inbox',
  'inboxes',
  'integration',
  'integrations',
  'interface',
  'interfaces',
  'iot',
  'kanban',
  'kpi',
  'kpis',
  'laptop',
  'laptops',
  'latency',
  'login',
  'logins',
  'logout',
  'maps',
  'metadata',
  'microservice',
  'microservices',
  'middleware',
  'milestone',
  'milestones',
  'mitigation',
  'mitigations',
  'mobile',
  'mou',
  'multiuser',
  'ok',
  'okay',
  'offboarding',
  'onboarding',
  'online',
  'organisational',
  'organisation',
  'organisations',
  'payment',
  'payments',
  'percent',
  'performance',
  'pipeline',
  'pipelines',
  'platform',
  'platforms',
  'portfolio',
  'portfolios',
  'procurement',
  'procurements',
  'programme',
  'programmes',
  'qgis',
  'realtime',
  'reporting',
  'rfi',
  'rfp',
  'roadmap',
  'roadmaps',
  'rollout',
  'rollouts',
  'roi',
  'scalable',
  'scalability',
  'scope',
  'scopes',
  'scoping',
  'scrum',
  'signoff',
  'signoffs',
  'sms',
  'spreadsheet',
  'spreadsheets',
  'sql',
  'stakeholder',
  'stakeholders',
  'standup',
  'standups',
  'subtask',
  'subtasks',
  'subsystem',
  'subsystems',
  'sync',
  'synced',
  'syncs',
  'tablet',
  'tablets',
  'telemetry',
  'timeframe',
  'timeframes',
  'timestamp',
  'timestamps',
  'tooltip',
  'tooltips',
  'ui',
  'upload',
  'uploads',
  'uptime',
  'usability',
  'username',
  'usernames',
  'ux',
  'validator',
  'vendors',
  'videoconference',
  'workflow',
  'workflows',
  'workshop',
  'workshops',
  'workstream',
  'workstreams',
  'wysiwyg',
};

Future<void> main(List<String> args) async {
  final sourceArgIndex = args.indexOf('--source');
  final explicitSource = sourceArgIndex >= 0 && args.length > sourceArgIndex + 1
      ? args[sourceArgIndex + 1]
      : null;

  final candidates =
      explicitSource != null ? <String>[explicitSource] : _defaultSources;
  final source = candidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => '',
  );
  if (source.isEmpty) {
    stderr.writeln('No system dictionary found. Tried:');
    for (final path in candidates) {
      stderr.writeln('  $path');
    }
    stderr.writeln('Pass one explicitly with --source <path>.');
    exitCode = 1;
    return;
  }

  final words = <String>{};
  var total = 0;
  for (final line in File(source).readAsLinesSync()) {
    total++;
    final word = line.trim().toLowerCase();
    if (word.length < _minLength || word.length > _maxLength) continue;
    if (!_isAsciiLetters(word)) continue;
    words.add(word);
  }
  words.addAll(_supplement);

  final sorted = words.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('# NDU Project spell-check dictionary')
    ..writeln('# Generated by scripts/build_spell_dictionary.dart — do not edit.')
    ..writeln('# Source: $source ($total lines read)')
    ..writeln('# Generated: ${DateTime.now().toIso8601String()}')
    ..writeln('# One lowercase word per line. Lines starting with # are ignored.');

  for (final word in sorted) {
    buffer.writeln(word);
  }

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(buffer.toString());

  final sizeMb = output.lengthSync() / (1024 * 1024);
  stdout.writeln('Wrote ${sorted.length} words to $_outputPath '
      '(${sizeMb.toStringAsFixed(1)} MB).');
}

bool _isAsciiLetters(String value) {
  for (final code in value.codeUnits) {
    if (code < 0x61 || code > 0x7A) return false; // a-z
  }
  return value.isNotEmpty;
}
