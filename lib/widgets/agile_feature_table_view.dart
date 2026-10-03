import 'package:flutter/material.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/utils/agile_epic_feature_table.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

/// Every feature in the project in one table, with the epic it hangs off.
///
/// Presentational on purpose — it takes rows, not services — so the list view
/// the review asked for can be tested without Firestore. The screen builds the
/// rows with [AgileEpicFeatureTable] and keeps the cards for editing.
class AgileFeatureTableView extends StatelessWidget {
  const AgileFeatureTableView({
    super.key,
    required this.rows,
    this.epicsWithoutFeatures = const <Epic>[],
    this.emptyMessage =
        'No features yet. Add one from an epic card, or pull features from '
        'the WBS.',
  });

  /// One row per feature, already ordered epic by epic.
  final List<FeatureTableRow> rows;

  /// Epics that contribute no row, reported instead of silently missing.
  final List<Epic> epicsWithoutFeatures;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && epicsWithoutFeatures.isEmpty) return _empty();
    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _empty(),
          const SizedBox(height: 12),
          _featurelessNotice(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'All features',
          subtitle: _summary(),
        ),
        buildNduTableWithExpand(
          context: context,
          title: 'All features',
          columns: const [
            DataColumn(label: Text('Feature')),
            DataColumn(label: Text('Epic')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Points'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('WBS')),
          ],
          rows: [
            for (final row in rows)
              DataRow(cells: [
                DataCell(Text(row.title)),
                DataCell(Text(row.epicLabel.isNotEmpty ? row.epicLabel : '—')),
                DataCell(_priorityChip(row.feature.priority)),
                DataCell(Text(row.feature.storyPointEstimate.toStringAsFixed(0))),
                DataCell(Text(row.feature.status)),
                DataCell(Text(row.feature.wbsId.isNotEmpty ? 'Linked' : '—')),
              ]),
          ],
        ),
        if (epicsWithoutFeatures.isNotEmpty) ...[
          const SizedBox(height: 12),
          _featurelessNotice(),
        ],
      ],
    );
  }

  /// The table titles are only used by the full-screen view, so the table gets
  /// its own inline heading here.
  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: _kMuted)),
          ],
        ],
      ),
    );
  }

  String _summary() {
    final features = rows.length;
    final epics = AgileEpicFeatureTable.epicCount(rows);
    final points = AgileEpicFeatureTable.totalPoints(rows);
    return '$features feature${features == 1 ? '' : 's'} across '
        '$epics epic${epics == 1 ? '' : 's'} · '
        '${points.toStringAsFixed(0)} story points.';
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

  Widget _priorityChip(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent),
      ),
    );
  }

  Widget _featurelessNotice() {
    final names = epicsWithoutFeatures
        .map(AgileEpicFeatureTable.displayEpicTitle)
        .join(', ');
    final count = epicsWithoutFeatures.length;
    return Container(
      key: const ValueKey('epics-without-features-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_tree_outlined,
              size: 16, color: Color(0xFFB8860B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count epic${count == 1 ? '' : 's'} with no features yet: '
              '$names. Add a feature to break ${count == 1 ? 'it' : 'them'} '
              'down.',
              style: const TextStyle(fontSize: 12, color: _kHeadline),
            ),
          ),
        ],
      ),
    );
  }
}
