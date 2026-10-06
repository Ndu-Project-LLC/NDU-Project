import 'package:flutter/foundation.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';

/// One Kanban workflow column as saved in the project's Kanban
/// configuration: the name the board renders and the work-in-progress limit
/// that gates pulls into it.
class KanbanColumnConfig {
  const KanbanColumnConfig({
    required this.name,
    this.wipLimit = KanbanConfigService.noWipLimit,
  });

  final String name;
  final int wipLimit;

  KanbanColumnConfig copyWith({String? name, int? wipLimit}) =>
      KanbanColumnConfig(
        name: name ?? this.name,
        wipLimit: wipLimit ?? this.wipLimit,
      );

  Map<String, dynamic> toMap() => {'name': name, 'wipLimit': wipLimit};

  @override
  bool operator ==(Object other) =>
      other is KanbanColumnConfig &&
      other.name == name &&
      other.wipLimit == wipLimit;

  @override
  int get hashCode => Object.hash(name, wipLimit);

  @override
  String toString() => 'KanbanColumnConfig($name, wip: $wipLimit)';
}

class KanbanConfigService {
  KanbanConfigService._();

  /// WIP limit value the board reads as "no limit".
  static const int noWipLimit = 999;

  /// The board's built-in columns, used when a project has saved no Kanban
  /// configuration. Mirrors what `agile_kanban_board_screen.dart` renders, so
  /// the configuration page and the board can never disagree about the
  /// starting workflow.
  ///
  /// This is deliberately *not* [simpleTemplate]: that three-status vocabulary
  /// is what the task board coerces statuses into.
  static const List<KanbanColumnConfig> defaultColumns = [
    KanbanColumnConfig(name: 'Backlog'),
    KanbanColumnConfig(name: 'Ready', wipLimit: 8),
    KanbanColumnConfig(name: 'In Progress', wipLimit: 5),
    KanbanColumnConfig(name: 'In Review', wipLimit: 3),
    KanbanColumnConfig(name: 'Done'),
  ];

  /// Board column id for a configured column name.
  ///
  /// Column state is derived from the name rather than stored, which is why
  /// renaming a column re-states its cards on the board.
  static String columnIdFor(String name, {String fallback = 'column'}) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  /// Whether [value] counts as "no limit".
  static bool isUnlimited(int wipLimit) => wipLimit >= noWipLimit;

  /// The board's label for a WIP limit.
  static String wipLimitLabel(int wipLimit) =>
      isUnlimited(wipLimit) ? 'No limit' : '$wipLimit';

  /// Parse a WIP limit out of stored JSON or a text field. Blank, non-numeric
  /// and non-positive input all mean "no limit".
  static int parseWipLimit(Object? value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed <= 0) return noWipLimit;
    return parsed;
  }

  /// Columns saved in [data] (`{columns: [{name, wipLimit}]}`), in board
  /// order. Returns an empty list when nothing usable is stored — callers
  /// decide whether to fall back to [defaultColumns].
  static List<KanbanColumnConfig> columnsFromConfig(Map<String, dynamic> data) {
    final raw = data['columns'];
    if (raw is! List) return const [];
    final columns = <KanbanColumnConfig>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      columns.add(KanbanColumnConfig(
        name: name,
        wipLimit: parseWipLimit(entry['wipLimit']),
      ));
    }
    return columns;
  }

  /// The project's configured columns in board order, falling back to
  /// [defaultColumns] when none are saved.
  static Future<List<KanbanColumnConfig>> loadColumns(String projectId) async {
    try {
      final data = await AgileWireframeService.loadKanbanConfig(projectId);
      final columns = columnsFromConfig(data);
      if (columns.isNotEmpty) return columns;
    } catch (error) {
      debugPrint('KanbanConfigService.loadColumns error: $error');
    }
    return List<KanbanColumnConfig>.from(defaultColumns);
  }

  /// Persist the workflow columns for [projectId].
  ///
  /// Names are written as given — they are what the board renders and what its
  /// column ids derive from — so this must not run them through
  /// [alignStatusesToWorkflow], which collapses synonyms (Backlog / Ready) into
  /// a single status and would silently merge the owner's columns.
  static Future<void> saveColumns({
    required String projectId,
    required List<KanbanColumnConfig> columns,
  }) async {
    final cleaned = [
      for (final column in columns)
        if (column.name.trim().isNotEmpty)
          column.copyWith(name: column.name.trim()),
    ];
    if (cleaned.isEmpty) {
      throw ArgumentError('A Kanban workflow needs at least one column.');
    }
    await AgileWireframeService.saveKanbanConfig(
      projectId: projectId,
      data: {'columns': cleaned.map((c) => c.toMap()).toList()},
    );
  }

  static const List<String> simpleTemplate = [
    'To Do',
    'In Progress',
    'Done',
  ];

  static const List<String> softwareTemplate = [
    'Backlog',
    'Ready',
    'In Progress',
    'Code Review',
    'Testing',
    'Ready for Release',
    'Done',
  ];

  static String normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', ' ');
    switch (normalized) {
      case 'todo':
      case 'to do':
      case 'to-do':
      case 'backlog':
      case 'ready':
        return 'To Do';
      case 'in progress':
      case 'inprogress':
      case 'in-progress':
        return 'In Progress';
      case 'code review':
        return 'Code Review';
      case 'testing':
      case 'qa':
        return 'Testing';
      case 'ready for release':
      case 'release ready':
        return 'Ready for Release';
      case 'done':
      case 'complete':
      case 'completed':
        return 'Done';
      default:
        return value.trim().isEmpty ? 'To Do' : value.trim();
    }
  }

  static Future<List<String>> loadWorkflowColumns(String projectId) async {
    try {
      final data = await AgileWireframeService.loadKanbanConfig(projectId);
      final raw = data['columns'];
      if (raw is List && raw.isNotEmpty) {
        final names = raw
            .whereType<Map>()
            .map((item) => item['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .map(normalizeStatus)
            .toList();
        if (names.isNotEmpty) return names;
      }
    } catch (error) {
      debugPrint('KanbanConfigService.loadWorkflowColumns error: $error');
    }
    return List<String>.from(simpleTemplate);
  }

  static List<String> alignStatusesToWorkflow(
    List<String> configuredColumns,
  ) {
    final normalized = configuredColumns
        .map(normalizeStatus)
        .where((value) => value.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return List<String>.from(simpleTemplate);
    return normalized.toSet().toList();
  }

  static String coerceTaskStatus(
    String status,
    List<String> configuredColumns,
  ) {
    final normalizedConfigured = alignStatusesToWorkflow(configuredColumns);
    final normalizedStatus = normalizeStatus(status);
    if (normalizedConfigured.contains(normalizedStatus)) {
      return normalizedStatus;
    }
    return normalizedConfigured.first;
  }
}
