library;

/// List View Screen — flat sortable/filterable table of all activities.
///
/// Rendered inside the parent module's `ResponsiveScaffold` body — no
/// per-screen Scaffold wrapper. Includes summary cards (Total / Critical /
/// % Complete), a search box, domain filter chips.
///
/// The Duration / Start / Finish cells are EDITABLE INLINE (Lusaka 28): when
/// you are building a schedule you must be able to type in dates and durations
/// across many rows without opening each item's editor. Milestone rows also
/// surface a date-mismatch warning when the activity's finish lands after a
/// FEP milestone it feeds (or before it starts after it).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/utils/schedule_duplicate_guard.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

class ListViewScreen extends StatefulWidget {
  const ListViewScreen({super.key});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  String _search = '';
  ScheduleDomain? _domainFilter;
  _SortBy _sortBy = _SortBy.code;
  bool _sortAsc = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final schedule = provider.schedule;
        if (schedule == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(LightModeColors.accent),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading schedule...',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }
        final rows = _buildRows(schedule);
        final filtered = _applyFilters(rows);
        final criticalCount = rows.where((r) => r.isCritical).length;
        final inProgressCount =
            rows.where((r) => r.status == 'In Progress').length;
        final completeCount = rows.where((r) => r.status == 'Complete').length;
        final pctComplete =
            rows.isEmpty ? 0.0 : (completeCount / rows.length) * 100;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.list,
                      color: LightModeColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('List View — ${schedule.projectName}',
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Flat, sortable view of all activities. Use the search box and domain chips to filter.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total Activities',
                      value: '${rows.length}',
                      icon: Icons.list_alt,
                      color: const Color(0xFFFFC812),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Critical Path',
                      value: '$criticalCount',
                      icon: Icons.flag,
                      color: LightModeColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'In Progress',
                      value: '$inProgressCount',
                      icon: Icons.pending_actions,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: '% Complete',
                      value: '${pctComplete.toStringAsFixed(0)}%',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search box + domain filter chips
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F), fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by name, code, cost, or status…',
                          hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Color(0xFF6B7280)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: LightModeColors.accent, width: 1.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Domain filter chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _domainFilter == null,
                    onTap: () => setState(() => _domainFilter = null),
                  ),
                  ...ScheduleDomain.values.map((d) => _FilterChip(
                        label: d.label,
                        color: Color(d.color),
                        selected: _domainFilter == d,
                        onTap: () => setState(() => _domainFilter = d),
                      )),
                ],
              ),
              const SizedBox(height: 16),
              // Activity table
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: filtered.isEmpty
                    ? _EmptyState(query: _search)
                    : FullScreenTableWrapper(
                    title: 'Schedule Activities',
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                          dataRowColor:
                              WidgetStateProperty.all(Colors.transparent),
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          sortColumnIndex: _sortBy.index,
                          sortAscending: _sortAsc,
                          columns: [
                            DataColumn(
                              label: const Text('Code',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.code, asc),
                            ),
                            DataColumn(
                              label: const Text('Name',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.name, asc),
                            ),
                            DataColumn(
                              label: const Text('Domain',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.domain, asc),
                            ),
                            DataColumn(
                              label: const Text('Duration',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) =>
                                  _onSort(_SortBy.duration, asc),
                            ),
                            DataColumn(
                              label: const Text('Start',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.start, asc),
                            ),
                            DataColumn(
                              label: const Text('Finish',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.finish, asc),
                            ),
                            DataColumn(
                              label: const Text('Cost',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.cost, asc),
                            ),
                            DataColumn(
                              label: const Text('Status',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.status, asc),
                            ),
                            const DataColumn(
                              label: Text('Traceability',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          rows: filtered
                              .map((r) => DataRow(cells: [
                                    DataCell(Text(r.code,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 11,
                                            fontFamily: appFontFamily,
                                            fontWeight: FontWeight.bold))),
                                    DataCell(Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: Color(r.domainColor),
                                              shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(r.name,
                                            style: const TextStyle(
                                                color: Color(0xFF1A1D1F),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    )),
                                    DataCell(Text(r.domainLabel,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    // Lusaka 28: Duration / Start / Finish are
                                    // editable inline — mass-populate a schedule
                                    // without opening each item's editor.
                                    DataCell(_InlineDurationCell(
                                      value: r.sortDuration,
                                      unit: r.durationUnit,
                                      enabled: r.activityId != null,
                                      onChanged: (days) => _updateActivityDates(
                                          r, durationDays: days),
                                    )),
                                    DataCell(_InlineDateCell(
                                      value: r.sortStart == 0
                                          ? null
                                          : DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  r.sortStart),
                                      enabled: r.activityId != null,
                                      onChanged: (date) => _updateActivityDates(
                                          r, start: date),
                                    )),
                                    DataCell(_InlineDateCell(
                                      value: r.sortFinish == 0
                                          ? null
                                          : DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  r.sortFinish),
                                      enabled: r.activityId != null,
                                      onChanged: (date) => _updateActivityDates(
                                          r, finish: date),
                                    )),
                                    // Lusaka 32: cost is the headline
                                    // number per work package — bold and
                                    // dark when linked, muted when not.
                                    DataCell(Text(r.cost,
                                        style: TextStyle(
                                            color: r.sortCost == null
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF1A1D1F),
                                            fontSize: 13,
                                            fontWeight: r.sortCost == null
                                                ? FontWeight.w400
                                                : FontWeight.w800))),
                                    DataCell(_StatusBadge(status: r.status)),
                                    DataCell(r.dateMismatchMessage.isEmpty
                                        ? _TraceabilityCell(row: r)
                                        : _MilestoneMismatchCell(
                                            message: r.dateMismatchMessage,
                                            child: _TraceabilityCell(row: r),
                                          )),
                                  ]))
                              .toList(),
                        ),
                      ),
                    tableBuilder: (fsContext) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                          dataRowColor:
                              WidgetStateProperty.all(Colors.transparent),
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          sortColumnIndex: _sortBy.index,
                          sortAscending: _sortAsc,
                          columns: [
                            DataColumn(
                              label: const Text('Code',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.code, asc),
                            ),
                            DataColumn(
                              label: const Text('Name',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.name, asc),
                            ),
                            DataColumn(
                              label: const Text('Domain',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.domain, asc),
                            ),
                            DataColumn(
                              label: const Text('Duration',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) =>
                                  _onSort(_SortBy.duration, asc),
                            ),
                            DataColumn(
                              label: const Text('Start',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.start, asc),
                            ),
                            DataColumn(
                              label: const Text('Finish',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.finish, asc),
                            ),
                            DataColumn(
                              label: const Text('Cost',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.cost, asc),
                            ),
                            DataColumn(
                              label: const Text('Status',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.status, asc),
                            ),
                            const DataColumn(
                              label: Text('Traceability',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          rows: filtered
                              .map((r) => DataRow(cells: [
                                    DataCell(Text(r.code,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 11,
                                            fontFamily: appFontFamily,
                                            fontWeight: FontWeight.bold))),
                                    DataCell(Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: Color(r.domainColor),
                                              shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(r.name,
                                            style: const TextStyle(
                                                color: Color(0xFF1A1D1F),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    )),
                                    DataCell(Text(r.domainLabel,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    // Lusaka 28: Duration / Start / Finish are
                                    // editable inline — mass-populate a schedule
                                    // without opening each item's editor.
                                    DataCell(_InlineDurationCell(
                                      value: r.sortDuration,
                                      unit: r.durationUnit,
                                      enabled: r.activityId != null,
                                      onChanged: (days) => _updateActivityDates(
                                          r, durationDays: days),
                                    )),
                                    DataCell(_InlineDateCell(
                                      value: r.sortStart == 0
                                          ? null
                                          : DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  r.sortStart),
                                      enabled: r.activityId != null,
                                      onChanged: (date) => _updateActivityDates(
                                          r, start: date),
                                    )),
                                    DataCell(_InlineDateCell(
                                      value: r.sortFinish == 0
                                          ? null
                                          : DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  r.sortFinish),
                                      enabled: r.activityId != null,
                                      onChanged: (date) => _updateActivityDates(
                                          r, finish: date),
                                    )),
                                    // Lusaka 32: cost is the headline
                                    // number per work package — bold and
                                    // dark when linked, muted when not.
                                    DataCell(Text(r.cost,
                                        style: TextStyle(
                                            color: r.sortCost == null
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF1A1D1F),
                                            fontSize: 13,
                                            fontWeight: r.sortCost == null
                                                ? FontWeight.w400
                                                : FontWeight.w800))),
                                    DataCell(_StatusBadge(status: r.status)),
                                    DataCell(r.dateMismatchMessage.isEmpty
                                        ? _TraceabilityCell(row: r)
                                        : _MilestoneMismatchCell(
                                            message: r.dateMismatchMessage,
                                            child: _TraceabilityCell(row: r),
                                          )),
                                  ]))
                              .toList(),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              // Footer note (wraps on narrow windows)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${filtered.length} of ${rows.length} activities',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                  const Text('·',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  const Text(
                      'Sample data shown alongside live activities added via the Builder tab.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSort(_SortBy by, bool asc) {
    setState(() {
      if (_sortBy == by) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = by;
        _sortAsc = true;
      }
    });
  }

  List<_ListRow> _buildRows(Schedule schedule) {
    // Combine: live provider activities + sample demo data
    final rows = <_ListRow>[];

    // Lusaka 28: milestone date-mismatch warnings — a schedule item whose
    // finish lands after a FEP milestone's due date (or starts after it)
    // carries a visible warning so the crew can discuss and fix the dates.
    // Milestone rows themselves compare their due date against the
    // committed FEP milestone date from Goals & Milestones.
    final fepMilestones = ProjectDataHelper.getData(context, listen: false)
        .keyMilestones
        .where((m) => m.name.trim().isNotEmpty)
        .toList();

    String? mismatchFor(ScheduleActivity node) {
      final finish = node.endDate;
      if (finish == null) return null;
      if (node.type == ActivityType.milestone) {
        for (final m in fepMilestones) {
          final due = DateTime.tryParse(m.dueDate);
          if (due == null) continue;
          final same = finish.year == due.year &&
              finish.month == due.month &&
              finish.day == due.day;
          if (!same) {
            final committed = DateFormat('MMM d, y').format(due);
            return 'Milestone date differs from the committed date in Goals & Milestones ($committed).';
          }
        }
        return null;
      }
      for (final m in fepMilestones) {
        final due = DateTime.tryParse(m.dueDate);
        if (due == null) continue;
        if (finish.isAfter(due)) {
          final committed = DateFormat('MMM d, y').format(due);
          return 'Finishes ${DateFormat('MMM d, y').format(finish)} — after the committed milestone date ($committed).';
        }
        if (node.startDate != null && node.startDate!.isAfter(due)) {
          final committed = DateFormat('MMM d, y').format(due);
          return 'Starts ${DateFormat('MMM d, y').format(node.startDate!)} — after the committed milestone date ($committed).';
        }
      }
      return null;
    }

    // Live activities from the provider (skip the root project node).
    void walk(ScheduleActivity node) {
      if (node.level > 0) {
        // Lusaka 32: cost per work package, resolved from the
        // cost estimate so the schedule table shows real numbers.
        final cost = _costFor(node);
        rows.add(_ListRow(
          code: node.code,
          name: node.name,
          domainColor: node.domain.color,
          domainLabel: node.domain.label,
          duration: formatDuration(node.duration, node.durationUnit),
          start: formatDate(node.startDate),
          finish: formatDate(node.endDate),
          cost: cost.text,
          sortCost: cost.amount,
          status: node.status ?? 'Not Started',
          isCritical: node.isCriticalPath,
          activityId: node.id,
          isSummary: node.children.isNotEmpty,
          durationUnit: node.durationUnit ?? 'day',
          dateMismatchMessage: mismatchFor(node) ?? '',
          hasWbs: node.wbsNodeId != null && node.wbsNodeId!.isNotEmpty,
          hasAgileStory:
              node.agileTaskId != null && node.agileTaskId!.isNotEmpty,
          hasSprint: node.sprintId != null && node.sprintId!.isNotEmpty,
          hasRelease: node.releaseId != null && node.releaseId!.isNotEmpty,
          sprintLabel: node.sprintLabel ?? '',
          releaseLabel: node.releaseLabel ?? '',
          agileEpicTitle: node.agileEpicTitle ?? '',
          agileFeatureTitle: node.agileFeatureTitle ?? '',
          importSource: node.importSource ?? '',
          prerequisiteCount: node.prerequisites?.length ?? 0,
          sortStart: node.startDate?.millisecondsSinceEpoch ?? 0,
          sortFinish: node.endDate?.millisecondsSinceEpoch ?? 0,
          sortDuration: node.duration ?? 0,
        ));
      }
      for (final c in node.children) {
        walk(c);
      }
    }

    if (schedule.activities.isNotEmpty) {
      walk(schedule.activities[0]);
    }

    // Append sample rows so the view is always populated, then drop any row
    // that repeats another — a live activity and a sample row reading as one
    // item is exactly the duplicate the owner is asking to remove.
    rows.addAll(_sampleRows());
    return dedupeScheduleItems(
      rows,
      nameOf: (row) => row.name,
      identityOf: (row) => row.activityId == null
          ? null
          : 'activity:${row.activityId}',
    );
  }

  /// Writes an inline edit from the Duration / Start / Finish cells back to
  /// the provider (and storage). Lusaka 28: building a schedule has to be a
  /// mass-edit flow, not open-card → edit → save per row.
  void _updateActivityDates(
    _ListRow row, {
    double? durationDays,
    DateTime? start,
    DateTime? finish,
  }) {
    final id = row.activityId;
    if (id == null || id.isEmpty) return;
    final provider = context.read<ScheduleProvider>();
    final schedule = provider.schedule;
    if (schedule == null) return;
    ScheduleActivity? current;
    void find(List<ScheduleActivity> nodes) {
      for (final n in nodes) {
        if (current != null) return;
        if (n.id == id) {
          current = n;
          return;
        }
        find(n.children);
      }
    }

    find(schedule.activities);
    if (current == null) return;
    final a = current!;

    double? nextDuration = durationDays ?? a.duration;
    var nextStart = start ?? a.startDate;
    var nextFinish = finish ?? a.endDate;

    // Keep the other end of the window consistent with the typed value, the
    // same way the Gantt places single-dated activities.
    if (durationDays != null) {
      if (nextStart != null) {
        nextFinish =
            nextStart.add(Duration(days: durationDays.round().clamp(0, 3650)));
      } else if (nextFinish != null) {
        nextStart = nextFinish
            .subtract(Duration(days: durationDays.round().clamp(0, 3650)));
      }
    } else if (start != null) {
      if (nextFinish != null && nextFinish.isBefore(start)) {
        nextFinish = start;
      }
      if ((a.duration ?? 0) <= 0 && nextFinish != null) {
        nextDuration =
            nextFinish.difference(start).inDays.clamp(0, 3650).toDouble();
      }
    } else if (finish != null) {
      if (nextStart != null && finish.isBefore(nextStart)) {
        nextStart = finish;
      }
      if ((a.duration ?? 0) <= 0 && nextStart != null) {
        nextDuration =
            finish.difference(nextStart).inDays.clamp(0, 3650).toDouble();
      }
    }

    provider.updateActivity(
      id,
      a.copyWith(
        duration: nextDuration,
        startDate: nextStart,
        endDate: nextFinish,
      ),
    );
  }

  /// Lusaka 32: resolve the cost a work package carries in the Cost
  /// Estimate — "the cost needs to be very clear … obvious and
  /// jumping out".
  ///
  /// The Builder stamps `ScheduleActivity.costLineId` when a line is
  /// created or pulled from the schedule, so that link wins. If it
  /// was never stamped (or the line was pulled by an older build),
  /// fall back to in-schedule estimate lines that carry the same WBS
  /// code, then the same name. Returns a muted "—" when the activity
  /// has no cost line yet.
  ///
  /// The CostEstimateProvider is optional here — the list view is
  /// also hosted in tests that only wire the schedule — so a missing
  /// provider just leaves the cost column blank.
  ({String text, double? amount}) _costFor(ScheduleActivity node) {
    final List<CostLine> lines;
    try {
      lines =
          context.read<CostEstimateProvider>().estimate?.lines ?? const [];
    } catch (_) {
      return (text: '—', amount: null);
    }
    final linkedId = node.costLineId;
    if (linkedId != null && linkedId.isNotEmpty) {
      for (final l in lines) {
        if (l.id == linkedId) {
          return (text: formatCurrency(l.total), amount: l.total);
        }
      }
    }
    final wbsCode = node.wbsCode;
    CostLine? fallback;
    for (final l in lines) {
      if (!l.inSchedule) continue;
      if (wbsCode != null && wbsCode.isNotEmpty && l.wbsRef == wbsCode) {
        fallback = l;
        break;
      }
      if (fallback == null && l.description == node.name) {
        fallback = l;
      }
    }
    if (fallback == null) return (text: '—', amount: null);
    return (text: formatCurrency(fallback.total), amount: fallback.total);
  }

  List<_ListRow> _sampleRows() {
    return [
      _ListRow(
        code: '1',
        name: 'Engineering — Process Design',
        domainColor: ScheduleDomain.engineering.color,
        domainLabel: ScheduleDomain.engineering.label,
        duration: '20 d',
        start: '01/06/26',
        finish: '01/30/26',
        cost: '\$185,000',
        sortCost: 185000,
        status: 'Complete',
        isCritical: false,
        sortStart: DateTime(2026, 1, 6).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 1, 30).millisecondsSinceEpoch,
        sortDuration: 20,
      ),
      _ListRow(
        code: '2',
        name: 'Procurement — Long-Lead Vessels',
        domainColor: ScheduleDomain.procurement.color,
        domainLabel: ScheduleDomain.procurement.label,
        duration: '45 d',
        start: '02/02/26',
        finish: '03/20/26',
        cost: '\$1,240,000',
        sortCost: 1240000,
        status: 'In Progress',
        isCritical: true,
        sortStart: DateTime(2026, 2, 2).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 3, 20).millisecondsSinceEpoch,
        sortDuration: 45,
      ),
      _ListRow(
        code: '3',
        name: 'Execution — Fabrication Phase A',
        domainColor: ScheduleDomain.execution.color,
        domainLabel: ScheduleDomain.execution.label,
        duration: '60 d',
        start: '03/23/26',
        finish: '05/22/26',
        cost: '\$860,000',
        sortCost: 860000,
        status: 'Not Started',
        isCritical: true,
        sortStart: DateTime(2026, 3, 23).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 5, 22).millisecondsSinceEpoch,
        sortDuration: 60,
      ),
      _ListRow(
        code: '4',
        name: 'Construction — Site Mobilization',
        domainColor: ScheduleDomain.construction.color,
        domainLabel: ScheduleDomain.construction.label,
        duration: '10 d',
        start: '05/25/26',
        finish: '06/05/26',
        cost: '\$95,000',
        sortCost: 95000,
        status: 'Not Started',
        isCritical: false,
        sortStart: DateTime(2026, 5, 25).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 6, 5).millisecondsSinceEpoch,
        sortDuration: 10,
      ),
      _ListRow(
        code: '5',
        name: 'Construction — Mechanical Install',
        domainColor: ScheduleDomain.construction.color,
        domainLabel: ScheduleDomain.construction.label,
        duration: '35 d',
        start: '06/08/26',
        finish: '07/17/26',
        cost: '\$410,000',
        sortCost: 410000,
        status: 'Not Started',
        isCritical: true,
        sortStart: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 7, 17).millisecondsSinceEpoch,
        sortDuration: 35,
      ),
      _ListRow(
        code: '6',
        name: 'Commissioning — Cold Commissioning',
        domainColor: ScheduleDomain.commissioning.color,
        domainLabel: ScheduleDomain.commissioning.label,
        duration: '15 d',
        start: '07/20/26',
        finish: '08/07/26',
        cost: '\$60,000',
        sortCost: 60000,
        status: 'Not Started',
        isCritical: true,
        sortStart: DateTime(2026, 7, 20).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 8, 7).millisecondsSinceEpoch,
        sortDuration: 15,
      ),
      _ListRow(
        code: '7',
        name: 'Commissioning — Hot Commissioning & Handover',
        domainColor: ScheduleDomain.commissioning.color,
        domainLabel: ScheduleDomain.commissioning.label,
        duration: '12 d',
        start: '08/10/26',
        finish: '08/22/26',
        cost: '\$75,000',
        sortCost: 75000,
        status: 'Not Started',
        isCritical: true,
        sortStart: DateTime(2026, 8, 10).millisecondsSinceEpoch,
        sortFinish: DateTime(2026, 8, 22).millisecondsSinceEpoch,
        sortDuration: 12,
      ),
    ];
  }

  List<_ListRow> _applyFilters(List<_ListRow> rows) {
    var out = rows;
    if (_domainFilter != null) {
      out = out.where((r) => r.domainLabel == _domainFilter!.label).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      out = out.where((r) {
        return r.name.toLowerCase().contains(q) ||
            r.code.toLowerCase().contains(q) ||
            r.cost.toLowerCase().contains(q) ||
            r.status.toLowerCase().contains(q);
      }).toList();
    }
    // Sort
    out.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case _SortBy.code:
          cmp = a.code.compareTo(b.code);
          break;
        case _SortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortBy.domain:
          cmp = a.domainLabel.compareTo(b.domainLabel);
          break;
        case _SortBy.duration:
          cmp = a.sortDuration.compareTo(b.sortDuration);
          break;
        case _SortBy.start:
          cmp = a.sortStart.compareTo(b.sortStart);
          break;
        case _SortBy.finish:
          cmp = a.sortFinish.compareTo(b.sortFinish);
          break;
        case _SortBy.cost:
          cmp = (a.sortCost ?? -1).compareTo(b.sortCost ?? -1);
          break;
        case _SortBy.status:
          cmp = a.status.compareTo(b.status);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return out;
  }
}

enum _SortBy { code, name, domain, duration, start, finish, cost, status }

class _ListRow {
  final String code;
  final String name;
  final int domainColor;
  final String domainLabel;
  final String duration;
  final String start;
  final String finish;

  /// Lusaka 32: the cost associated with this work package, resolved
  /// from the cost estimate. `sortCost` is null when nothing is
  /// linked, so unlinked rows sort first and render a muted "—".
  final String cost;
  final double? sortCost;
  final String status;
  final bool isCritical;

  /// Lusaka 28: live provider linkage + inline-edit support. `activityId` is
  /// null for demo rows, so their cells render read-only text.
  final String? activityId;
  final bool isSummary;
  final String durationUnit;
  final String dateMismatchMessage;

  final bool hasWbs;
  final bool hasAgileStory;
  final bool hasSprint;
  final bool hasRelease;
  final String sprintLabel;
  final String releaseLabel;
  final String agileEpicTitle;
  final String agileFeatureTitle;
  final String importSource;
  final int prerequisiteCount;
  final int sortStart;
  final int sortFinish;
  final double sortDuration;

  const _ListRow({
    required this.code,
    required this.name,
    required this.domainColor,
    required this.domainLabel,
    required this.duration,
    required this.start,
    required this.finish,
    required this.cost,
    this.sortCost,
    required this.status,
    required this.isCritical,
    this.activityId,
    this.isSummary = false,
    this.durationUnit = 'day',
    this.dateMismatchMessage = '',
    this.hasWbs = false,
    this.hasAgileStory = false,
    this.hasSprint = false,
    this.hasRelease = false,
    this.sprintLabel = '',
    this.releaseLabel = '',
    this.agileEpicTitle = '',
    this.agileFeatureTitle = '',
    this.importSource = '',
    this.prerequisiteCount = 0,
    required this.sortStart,
    required this.sortFinish,
    required this.sortDuration,
  });
}

/// Summary stat card at the top of the list view.
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Domain filter chip.
class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? LightModeColors.accent).withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? (color ?? LightModeColors.accent)
                : const Color(0xFFE4E7EC),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                  color: selected
                      ? (color ?? LightModeColors.accent)
                      : const Color(0xFF495057),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

/// Status badge — colored pill based on activity status.
class _TraceabilityCell extends StatelessWidget {
  final _ListRow row;
  const _TraceabilityCell({required this.row});

  /// Every traceability card carries its own tint, taken from the strongest
  /// link the row carries, so rows are told apart at a glance instead of every
  /// card reading as the same block of white. Ordered by how specific the link
  /// is: a release says more than a sprint, which says more than a WBS link.
  Color get _cardColor {
    if (row.hasRelease) return const Color(0xFFD97706);
    if (row.hasSprint) return const Color(0xFF16A34A);
    if (row.hasAgileStory) return const Color(0xFFB8860B);
    if (row.hasWbs) return const Color(0xFFD4AF37);
    if (row.importSource.isNotEmpty) return const Color(0xFF475467);
    return const Color(0xFF9CA3AF);
  }

  /// The tinted panel that holds one row's traceability content.
  Widget _card({required Widget child, double width = 260}) {
    final color = _cardColor;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (row.importSource.isNotEmpty) {
      chips.add(
          _miniChip(_sourceLabel(row.importSource), const Color(0xFF475467)));
    }
    if (row.hasWbs) {
      chips.add(_miniChip('WBS', const Color(0xFFFFC812)));
    }
    if (row.hasAgileStory) {
      chips.add(_miniChip(
          row.agileFeatureTitle.isNotEmpty ? row.agileFeatureTitle : 'Story',
          const Color(0xFFB8860B)));
    }
    if (row.hasSprint) {
      chips.add(_miniChip(
          row.sprintLabel.isNotEmpty ? row.sprintLabel : 'Sprint',
          const Color(0xFF16A34A)));
    }
    if (row.hasRelease) {
      chips.add(_miniChip(
          row.releaseLabel.isNotEmpty ? row.releaseLabel : 'Release',
          const Color(0xFFD97706)));
    }
    if (row.prerequisiteCount > 0) {
      chips.add(_miniChip(
          '${row.prerequisiteCount} prereq', const Color(0xFF6B7280)));
    }
    if (chips.isEmpty) {
      return _card(
        width: 48,
        child: const Text('—',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
      );
    }
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.agileEpicTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Epic: ${row.agileEpicTitle}${row.agileFeatureTitle.isNotEmpty ? ' · Feature: ${row.agileFeatureTitle}' : ''}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              ),
            ),
          Wrap(spacing: 4, runSpacing: 4, children: chips),
        ],
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'agile_story':
        return 'Agile Import';
      case 'work_package':
        return 'Package Import';
      case 'wbs':
        return 'WBS Import';
      case 'fep_milestone':
        return 'FEP Milestone';
      default:
        return source;
    }
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'in progress':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFF9A3412);
        break;
      case 'not started':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF495057);
        break;
      case 'delayed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF495057);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Empty-state shown when no activities match the search/filter.
class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 36, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text('No matching activities',
                style: TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              query.trim().isEmpty
                  ? 'Try changing the domain filter.'
                  : 'No activities match "$query". Try a different search term.',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline duration editor for the Duration column (Lusaka 28).
///
/// Renders as plain text until tapped; commits on submit / focus loss. Demo
/// rows (enabled = false) render as read-only text.
class _InlineDurationCell extends StatefulWidget {
  const _InlineDurationCell({
    required this.value,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<_InlineDurationCell> createState() => _InlineDurationCellState();
}

class _InlineDurationCellState extends State<_InlineDurationCell> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.value > 0 ? widget.value.round().toString() : '');
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineDurationCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.value != oldWidget.value) {
      _controller.text =
          widget.value > 0 ? widget.value.round().toString() : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    _editing = false;
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed != null && parsed >= 0 && parsed != widget.value) {
      widget.onChanged(parsed);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _PlainTextCell(
        text: _display,
      );
    }
    return SizedBox(
        width: 84,
        child: _editing
            ? TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D1F)),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                onSubmitted: (_) => _commit(),
              )
            : InkWell(
                onTap: () => setState(() => _editing = true),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _display,
                        style: const TextStyle(
                            color: Color(0xFF495057), fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined,
                          size: 12, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
    );
  }

  String get _display {
    if (widget.value <= 0) return '—';
    final unit = widget.unit == 'day' || widget.unit == 'days'
        ? 'd'
        : widget.unit;
    return '${widget.value.round()} $unit';
  }
}

/// Inline date editor for the Start / Finish columns (Lusaka 28).
///
/// Renders as plain text; tapping opens a date picker and commits immediately.
class _InlineDateCell extends StatelessWidget {
  const _InlineDateCell({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  String get _formatted {
    if (value == null) return '—';
    return DateFormat('MM/dd/yy').format(value!);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _PlainTextCell(text: _formatted);
    }
    return InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onChanged(DateTime(picked.year, picked.month, picked.day));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatted,
                style: TextStyle(
                  color: value == null
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF495057),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined,
                  size: 12, color: Colors.grey.shade400),
            ],
          ),
        ),
    );
  }
}

/// Plain-text stand-in used by non-editable (demo / sample) rows so they keep
/// the same table look as editable ones.
class _PlainTextCell extends StatelessWidget {
  const _PlainTextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF495057), fontSize: 12),
      ),
    );
  }
}

/// Warning cell wrapper for milestone date mismatches (Lusaka 28).
///
/// Shows the traceability cell content plus an amber warning chip; tapping it
/// explains which committed milestone date conflicts.
class _MilestoneMismatchCell extends StatelessWidget {
  const _MilestoneMismatchCell({
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFF59E0B)),
                ),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 11,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
