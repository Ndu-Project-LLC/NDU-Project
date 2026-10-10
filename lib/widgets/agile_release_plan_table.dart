import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/agile_release_scope.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

/// The Release Plan as tables: what the project has (epics and the milestones
/// tied to them) and what each release covers.
///
/// Presentational on purpose — it takes rows, not services — so the table view
/// the review asked for ("I can type view, like the [table] view") can be tested
/// without Firestore. The screen builds the rows with [AgileReleaseScope].
class AgileReleasePlanTableView extends StatelessWidget {
  const AgileReleasePlanTableView({
    super.key,
    required this.rows,
    required this.epicRows,
    this.unclaimedMilestones = const <Milestone>[],
    this.emptyMessage =
        'No release plans yet. The epics and milestones above are what is '
        'available to scope one.',
  });

  /// One row per release and the epic it covers.
  final List<ReleasePlanTableRow> rows;

  /// Every project epic and the milestones the project ties to it.
  final List<EpicMilestoneRow> epicRows;

  /// Project milestones no release claims yet.
  final List<Milestone> unclaimedMilestones;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && epicRows.isEmpty) return _empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (epicRows.isNotEmpty) _projectReference(context),
        if (epicRows.isNotEmpty && rows.isNotEmpty) const SizedBox(height: 24),
        if (rows.isNotEmpty) _releases(context) else _empty(),
        if (unclaimedMilestones.isNotEmpty) ...[
          const SizedBox(height: 12),
          _unclaimedNotice(),
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

  /// The table titles are only used by the full-screen view, so each table gets
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

  Widget _projectReference(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Project epics & milestones',
          subtitle: 'Every epic, with the milestones already tied to it.',
        ),
        buildNduTableWithExpand(
          context: context,
          title: 'Project epics & milestones',
          columns: const [
            DataColumn(label: Text('Epic')),
            DataColumn(label: Text('WBS')),
            DataColumn(label: Text('Milestones')),
          ],
          rows: [
            for (final row in epicRows)
              DataRow(cells: [
                DataCell(Text(row.epic.title.isNotEmpty
                    ? row.epic.title
                    : 'Untitled epic')),
                DataCell(Text(row.epic.wbsId.isNotEmpty ? row.epic.wbsId : '—')),
                DataCell(row.milestones.isEmpty
                    ? const Text('—')
                    : _milestoneNames(row.milestones)),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _releases(BuildContext context) {
    final df = DateFormat('MMM dd, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Release plan',
          subtitle: 'One row per release and the epic it covers. Milestones are '
              'resolved automatically from the work.',
        ),
        buildNduTableWithExpand(
          context: context,
          title: 'Release plan',
          columns: const [
            DataColumn(label: Text('Release')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Epic')),
            DataColumn(label: Text('Milestones')),
            DataColumn(label: Text('Stories'), numeric: true),
            DataColumn(label: Text('Points'), numeric: true),
          ],
          rows: [
            for (final row in rows)
              DataRow(cells: [
                DataCell(Text(row.release.releaseLabel.isNotEmpty
                    ? row.release.releaseLabel
                    : 'Untitled release')),
                DataCell(Text(row.release.releaseDate != null
                    ? df.format(row.release.releaseDate!)
                    : '—')),
                DataCell(Text(row.release.status)),
                DataCell(Text(row.epic != null
                    ? (row.epic!.title.isNotEmpty
                        ? row.epic!.title
                        : 'Untitled epic')
                    : 'No epic linked')),
                DataCell(row.milestones.isEmpty
                    ? const Text('—')
                    : _milestoneNames(row.milestones)),
                DataCell(Text('${row.storyCount}')),
                DataCell(Text('${row.storyPoints}')),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _milestoneNames(List<Milestone> milestones) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final milestone in milestones)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              milestone.name.isNotEmpty ? milestone.name : 'Unnamed milestone',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB8860B)),
            ),
          ),
      ],
    );
  }

  Widget _unclaimedNotice() {
    final names = unclaimedMilestones
        .map((m) => m.name.isNotEmpty ? m.name : 'Unnamed milestone')
        .join(', ');
    return Container(
      key: const ValueKey('release-plan-unclaimed-milestones'),
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
          const Icon(Icons.flag_outlined, size: 16, color: Color(0xFFB8860B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${unclaimedMilestones.length} project milestone'
              '${unclaimedMilestones.length == 1 ? '' : 's'} not tied to a '
              'release yet: $names',
              style: const TextStyle(fontSize: 12, color: _kHeadline),
            ),
          ),
        ],
      ),
    );
  }
}
