import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/utils/agile_backlog_table.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);

/// The planning backlog as a table: every story with the feature and epic it
/// descends from, plus an explicit group for stories no feature claims.
///
/// Presentational on purpose — it takes rows, not services — so the table the
/// review asked for can be tested without Firestore. The screen builds the
/// rows with [AgileBacklogTable.build].
class AgileBacklogTableView extends StatelessWidget {
  const AgileBacklogTableView({
    super.key,
    required this.rows,
    required this.sprintLabel,
    required this.releaseLabel,
    this.featuresWithoutStories = 0,
    this.onMoveUp,
    this.onMoveDown,
    this.boardLabel,
    this.emptyMessage =
        'No stories in the backlog yet. Switch to Cards to add a story to a feature.',
  });

  final List<BacklogTableRow> rows;

  /// Move a story one place earlier in its feature's priority.
  ///
  /// The table is the default view, so prioritising cannot live only in the
  /// drag handle on the cards — the review asked to be able to reorder the
  /// backlog ("drag them up and down to prioritize them").
  final void Function(AgileTask story)? onMoveUp;

  /// Move a story one place later in its feature's priority.
  final void Function(AgileTask story)? onMoveDown;

  /// Which board column a story currently sits in, when the caller knows it.
  /// The column is only rendered when this is supplied.
  final String Function(AgileTask story)? boardLabel;

  /// Resolves a target sprint id for display.
  final String Function(String id) sprintLabel;

  /// Resolves a target release id for display.
  final String Function(String id) releaseLabel;

  /// How many features still have no stories (the breakdown gap).
  final int featuresWithoutStories;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final linked = [for (final row in rows) if (!row.isUnlinked) row];
    final unlinked = [for (final row in rows) if (row.isUnlinked) row];

    if (linked.isEmpty && unlinked.isEmpty) return _empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linked.isNotEmpty)
          _table(context, linked, title: 'Planning backlog'),
        if (unlinked.isNotEmpty) ...[
          if (linked.isNotEmpty) const SizedBox(height: 20),
          _unlinkedGroup(context, unlinked),
        ],
        if (featuresWithoutStories > 0) ...[
          const SizedBox(height: 12),
          _notice(
            featuresWithoutStories == 1
                ? '1 feature has no stories yet — break it down before it '
                    'reaches an iteration.'
                : '$featuresWithoutStories features have no stories yet — break '
                    'them down before they reach an iteration.',
          ),
        ],
      ],
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(emptyMessage, style: const TextStyle(color: _kMuted)),
    );
  }

  Widget _table(
    BuildContext context,
    List<BacklogTableRow> rows, {
    required String title,
    bool showParentColumns = true,
  }) {
    // With no parent to show, say why instead of rendering two blank columns.
    final columns = showParentColumns
        ? [
            const DataColumn(label: Text('Epic')),
            const DataColumn(label: Text('Feature')),
            const DataColumn(label: Text('Story')),
            const DataColumn(label: Text('Order')),
            const DataColumn(label: Text('Priority')),
            const DataColumn(label: Text('Points'), numeric: true),
            const DataColumn(label: Text('Readiness')),
            const DataColumn(label: Text('Sprint')),
            const DataColumn(label: Text('Release')),
            if (boardLabel != null) const DataColumn(label: Text('Board')),
            const DataColumn(label: Text('WBS')),
          ]
        : const [
            DataColumn(label: Text('Story')),
            DataColumn(label: Text('Why unlinked')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Points'), numeric: true),
            DataColumn(label: Text('Readiness')),
          ];

    return buildNduTableWithExpand(
      context: context,
      title: title,
      columns: columns,
      rows: [
        for (final row in rows)
          DataRow(cells: showParentColumns
              ? [
                  DataCell(Text(row.epicTitle.isNotEmpty ? row.epicTitle : '—')),
                  DataCell(Text(
                      row.featureTitle.isNotEmpty ? row.featureTitle : '—')),
                  DataCell(Text(row.story.userStory.isNotEmpty
                      ? row.story.userStory
                      : 'Untitled story')),
                  DataCell(_orderCell(row.story)),
                  DataCell(Text(row.story.priority)),
                  DataCell(Text('${row.story.storyPoints}')),
                  DataCell(Text(row.story.readinessStatus)),
                  DataCell(Text(sprintLabel(row.story.plannedSprintId))),
                  DataCell(Text(releaseLabel(row.story.plannedReleaseId))),
                  if (boardLabel != null) DataCell(Text(boardLabel!(row.story))),
                  DataCell(Text(row.story.wbsId.isNotEmpty ? 'Linked' : '—')),
                ]
              : [
                  DataCell(Text(row.story.userStory.isNotEmpty
                      ? row.story.userStory
                      : 'Untitled story')),
                  DataCell(Text(row.unlinkedLabel)),
                  DataCell(Text(row.story.priority)),
                  DataCell(Text('${row.story.storyPoints}')),
                  DataCell(Text(row.story.readinessStatus)),
                ]),
      ],
    );
  }

  /// The story's stored priority, plus the move actions when the screen wired
  /// them up.
  Widget _orderCell(AgileTask story) {
    if (onMoveUp == null && onMoveDown == null) {
      return Text('#${story.backlogOrder}');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('#${story.backlogOrder}'),
        const SizedBox(width: 4),
        _moveButton(
          key: ValueKey('backlog-up-${story.id}'),
          tooltip: 'Move earlier',
          icon: Icons.keyboard_arrow_up,
          onPressed: onMoveUp == null ? null : () => onMoveUp!(story),
        ),
        _moveButton(
          key: ValueKey('backlog-down-${story.id}'),
          tooltip: 'Move later',
          icon: Icons.keyboard_arrow_down,
          onPressed: onMoveDown == null ? null : () => onMoveDown!(story),
        ),
      ],
    );
  }

  Widget _moveButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      icon: Icon(icon, size: 16, color: _kMuted),
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _unlinkedGroup(BuildContext context, List<BacklogTableRow> rows) {
    return Container(
      key: const ValueKey('backlog-unlinked-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_off, size: 18, color: Color(0xFFB8860B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${rows.length} story${rows.length == 1 ? '' : 's'} no feature claims',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'These stories are in the backlog but no feature owns them, so they '
            'cannot roll up to an epic. Move them under a feature in Cards view '
            'or in Epics & Features.',
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
          const SizedBox(height: 12),
          _table(context, rows,
              title: 'Stories without a feature', showParentColumns: false),
        ],
      ),
    );
  }

  Widget _notice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: _kMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: _kMuted)),
          ),
        ],
      ),
    );
  }
}
