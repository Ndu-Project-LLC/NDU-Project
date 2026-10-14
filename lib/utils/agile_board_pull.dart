import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/services/kanban_config_service.dart';

/// The rules behind pulling a backlog story onto the Kanban board.
///
/// The review: "you can pull them into the Kanban". Every story is already on
/// the board's first column (a new story's `workflowState` resolves to the
/// entry column), so pulling one in means moving it out of that entry column
/// into the first working column — the point at which the team has actually
/// picked it up.
///
/// The configured columns are read through [KanbanConfigService], the same
/// source the board and the configuration page use, so a renamed or reordered
/// column moves the entry point with it instead of drifting.
///
/// Pure (a task plus a config map in) so it is testable without Firestore.
class AgileBoardPull {
  AgileBoardPull._();

  /// The board's columns in board order, falling back to the defaults when the
  /// project has configured none.
  static List<KanbanColumnConfig> columns(Map<String, dynamic> config) {
    final configured = KanbanConfigService.columnsFromConfig(config);
    return configured.isEmpty
        ? KanbanConfigService.defaultColumns
        : configured;
  }

  static String _columnId(List<KanbanColumnConfig> columns, int index) =>
      KanbanConfigService.columnIdFor(columns[index].name,
          fallback: 'column_${index + 1}');

  /// The board's entry column, where a story sits before it is pulled in.
  static String entryColumnId(Map<String, dynamic> config) {
    final columns = AgileBoardPull.columns(config);
    return columns.isEmpty ? '' : _columnId(columns, 0);
  }

  /// Where a pulled-in story lands: the first column after the entry column,
  /// or the entry column itself when the board has only one.
  static String workingColumnId(Map<String, dynamic> config) {
    final columns = AgileBoardPull.columns(config);
    if (columns.isEmpty) return '';
    return _columnId(columns, columns.length > 1 ? 1 : 0);
  }

  /// Whether [story] has been pulled onto the board.
  static bool isOnBoard(AgileTask story, Map<String, dynamic> config) {
    final entry = entryColumnId(config);
    return story.workflowState.isNotEmpty && story.workflowState != entry;
  }

  /// [story] moved onto the board's first working column.
  static AgileTask pull(AgileTask story, Map<String, dynamic> config) =>
      story.copyWith(workflowState: workingColumnId(config));

  /// [story] moved back to the board's entry column, undoing a pull.
  static AgileTask release(AgileTask story, Map<String, dynamic> config) =>
      story.copyWith(workflowState: entryColumnId(config));

  /// The name of the board column [story] currently sits in.
  ///
  /// An unset or unknown state resolves to the entry column, which is exactly
  /// how the board itself groups such a story.
  static String columnTitle(AgileTask story, Map<String, dynamic> config) {
    final columns = AgileBoardPull.columns(config);
    for (var i = 0; i < columns.length; i++) {
      if (_columnId(columns, i) == story.workflowState) return columns[i].name;
    }
    return columns.isEmpty ? '' : columns.first.name;
  }
}
