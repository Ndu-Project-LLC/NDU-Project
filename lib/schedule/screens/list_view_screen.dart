library;

/// List View Screen — flat sortable/filterable table of all activities.
///
/// Rendered inside the parent module's `ResponsiveScaffold` body — no
/// per-screen Scaffold wrapper. Includes summary cards (Total / Critical /
/// % Complete), a search box, domain filter chips, and a sample dataset so the
/// view is always populated.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

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
        final schedule = provider.schedule!;
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
                      color: const Color(0xFF3B82F6),
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
                          hintText: 'Search by name, code, or owner…',
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
                    : SingleChildScrollView(
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
                              label: const Text('Owner',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onSort: (c, asc) => _onSort(_SortBy.owner, asc),
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
                                    DataCell(Text(r.duration,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    DataCell(Text(r.start,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    DataCell(Text(r.finish,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    DataCell(Text(r.owner,
                                        style: const TextStyle(
                                            color: Color(0xFF495057),
                                            fontSize: 12))),
                                    DataCell(_StatusBadge(status: r.status)),
                                    DataCell(_TraceabilityCell(row: r)),
                                  ]))
                              .toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              // Footer note
              Row(
                children: [
                  Text('${filtered.length} of ${rows.length} activities',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                  const SizedBox(width: 8),
                  const Text('·',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  const SizedBox(width: 8),
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

    // Live activities from the provider (skip the root project node).
    void walk(ScheduleActivity node) {
      if (node.level > 0) {
        rows.add(_ListRow(
          code: node.code,
          name: node.name,
          domainColor: node.domain.color,
          domainLabel: node.domain.label,
          duration: formatDuration(node.duration, node.durationUnit),
          start: formatDate(node.startDate),
          finish: formatDate(node.endDate),
          owner: node.owner ?? '—',
          status: node.status ?? 'Not Started',
          isCritical: node.isCriticalPath,
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

    // Append sample rows so the view is always populated.
    rows.addAll(_sampleRows());
    return rows;
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
        owner: 'Process Eng',
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
        owner: 'Buyer',
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
        owner: 'Fab Shop',
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
        owner: 'Site Sup',
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
        owner: 'Mech Crew',
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
        owner: 'Commissioning Eng',
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
        owner: 'Commissioning Eng',
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
            r.owner.toLowerCase().contains(q) ||
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
        case _SortBy.owner:
          cmp = a.owner.toLowerCase().compareTo(b.owner.toLowerCase());
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

enum _SortBy { code, name, domain, duration, start, finish, owner, status }

class _ListRow {
  final String code;
  final String name;
  final int domainColor;
  final String domainLabel;
  final String duration;
  final String start;
  final String finish;
  final String owner;
  final String status;
  final bool isCritical;
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
    required this.owner,
    required this.status,
    required this.isCritical,
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

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (row.importSource.isNotEmpty) {
      chips.add(
          _miniChip(_sourceLabel(row.importSource), const Color(0xFF475467)));
    }
    if (row.hasWbs) {
      chips.add(_miniChip('WBS', const Color(0xFF0EA5E9)));
    }
    if (row.hasAgileStory) {
      chips.add(_miniChip(
          row.agileFeatureTitle.isNotEmpty ? row.agileFeatureTitle : 'Story',
          const Color(0xFF8B5CF6)));
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
      return const Text('—',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12));
    }
    return SizedBox(
      width: 260,
      child: Column(
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
