library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

/// Timeline zoom levels for the Gantt (Lusaka 28): the schedule has to be
/// able to show the WHOLE project (16 months, years) and then zoom in to the
/// working level (week / month / quarter) as you build each element.
enum _GanttScale {
  week('Week', 7),
  month('Month', 30),
  quarter('Quarter', 91),
  year('Year', 365);

  const _GanttScale(this.label, this.days);

  final String label;
  final int days;

  /// Pixel width of one scale-unit cell on the timeline.
  double get cellWidth => switch (this) {
        _GanttScale.week => 56.0,
        _GanttScale.month => 96.0,
        _GanttScale.quarter => 120.0,
        _GanttScale.year => 160.0,
      };

  String labelFor(DateTime date) => switch (this) {
        _GanttScale.week =>
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
        _GanttScale.month => _monthAbbrs[date.month - 1],
        _GanttScale.quarter => 'Q${((date.month - 1) ~/ 3) + 1} ${date.year % 100}',
        _GanttScale.year => date.year.toString(),
      };

  DateTime next(DateTime date) => switch (this) {
        _GanttScale.week => date.add(const Duration(days: 7)),
        _GanttScale.month => DateTime(date.year, date.month + 1, 1),
        _GanttScale.quarter => DateTime(date.year, date.month + 3, 1),
        _GanttScale.year => DateTime(date.year + 1, 1, 1),
      };

  /// Days remaining in the cell containing [date].
  int cellDaysLeft(DateTime date) => switch (this) {
        _GanttScale.week =>
          7 - ((date.weekday - DateTime.monday) % 7),
        _GanttScale.month =>
          DateTime(date.year, date.month + 1, 1)
              .difference(DateTime(date.year, date.month, 1))
              .inDays -
              date.day +
              1,
        _GanttScale.quarter =>
          DateTime(date.year, ((date.month - 1) ~/ 3) * 3 + 4, 1)
              .difference(DateTime(date.year, date.month, 1))
              .inDays -
              date.day +
              1,
        _GanttScale.year =>
          DateTime(date.year + 1, 1, 1)
              .difference(DateTime(date.year, 1, 1))
              .inDays -
              date.day +
              1,
      };

  static const _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends State<GanttScreen> {
  /// Current timeline zoom. Week keeps the legacy default; a 16-month project
  /// should still be viewable whole (quarter / year) per Lusaka 28.
  _GanttScale _scale = _GanttScale.week;

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
        final gantt = _buildRows(schedule.activities);
        final rows = gantt.rows;
        final unscheduledCount = gantt.unscheduled;
        final totalCount = gantt.total;

        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart,
                      size: 48,
                      color: LightModeColors.accent.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('No activities yet',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the Builder tab to create activities from work packages, then run CPM to calculate dates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final baseDate = rows
            .map((r) => r.startDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final maxEndDate =
            rows.map((r) => r.endDate).reduce((a, b) => a.isAfter(b) ? a : b);

        // Walk the timeline in scale-sized cells from the base date until it
        // covers the last finish. A 16-month project at Year zoom renders 2
        // cells; at Week zoom it renders ~70 — same data, chosen altitude.
        final cellLabels = <String>[];
        final cellStarts = <DateTime>[];
        var cursor = DateTime(baseDate.year, baseDate.month, baseDate.day);
        final cellWidth = _scale.cellWidth;
        while (cellStarts.isEmpty ||
            cursor.isBefore(maxEndDate.add(Duration(days: _scale.days))) ) {
          cellLabels.add(_scale.labelFor(cursor));
          cellStarts.add(cursor);
          cursor = _scale.next(cursor);
          if (cellStarts.length > 400) break; // safety valve
        }
        final cellCount = cellStarts.length;
        final timelineStart = cellStarts.first;

        // The Gantt has to fill the width it is given. The timeline used to
        // shrink-wrap to `leftColWidth + cellCount * cellWidth`, so a short
        // project (a few week cells) left most of the screen empty and the
        // chart looked broken rather than narrow. Stretching the cells to reach
        // the viewport keeps the whole grid edge-to-edge; when there are enough
        // cells to overflow, the per-scale minimum still applies and the table
        // scrolls horizontally as before.
        const leftColWidth = 280.0;
        final tableWidth = LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final stretchedCellWidth = cellCount == 0
                ? cellWidth
                : ((available - leftColWidth) / cellCount)
                    .clamp(cellWidth, double.infinity);
            return _GanttTable(
              cellLabels: cellLabels,
              cellStarts: cellStarts,
              rows: rows,
              timelineStart: timelineStart,
              scale: _scale,
              cellWidth: stretchedCellWidth,
              leftColWidth: leftColWidth,
            );
          },
        );

        final criticalCount = rows.where((r) => r.isCritical).length;
        final milestoneCount = rows.where((r) => r.isMilestone).length;
        final goalCount = rows
            .map((r) => r.goalKey)
            .where((g) => g.isNotEmpty)
            .toSet()
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart,
                      color: LightModeColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Gantt Chart — ${schedule.projectName}',
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  // Zoom selector (Lusaka 28): week / month / quarter / year.
                  SegmentedButton<_GanttScale>(
                    segments: _GanttScale.values
                        .map((s) => ButtonSegment(
                              value: s,
                              label: Text(s.label,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    selected: {_scale},
                    showSelectedIcon: false,
                    // Brand yellow, matching the rest of the schedule module.
                    // Without this the control falls back to the Material
                    // seed colour (blue), which reads as a different product.
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: LightModeColors.accent,
                      selectedForegroundColor: const Color(0xFF1A1D1F),
                      foregroundColor: const Color(0xFF495057),
                      side: const BorderSide(color: Color(0xFFE4E7EC)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (selection) {
                      setState(() => _scale = selection.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$totalCount activities · $criticalCount on critical path · $milestoneCount milestones · $cellCount ${_scale.label.toLowerCase()} view',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    ...ScheduleDomain.values.map((d) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: Color(d.color),
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 4),
                            Text(d.label,
                                style: const TextStyle(
                                    color: Color(0xFF495057), fontSize: 11)),
                          ],
                        )),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color:
                                  LightModeColors.accent.withValues(alpha: 0.3),
                              border: Border.all(
                                  color: LightModeColors.accent, width: 1.5)),
                        ),
                        const SizedBox(width: 4),
                        const Text('Critical path',
                            style: TextStyle(
                                color: Color(0xFF495057), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              tableWidth,
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insights,
                        size: 16, color: LightModeColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${rows.length} activities displayed. '
                        '$criticalCount on critical path. '
                        '$milestoneCount milestones shown as diamonds. '
                        '${goalCount > 0 ? 'Color-coded by $goalCount goal(s). ' : ''}'
                        '${unscheduledCount > 0 ? "$unscheduledCount work package${unscheduledCount == 1 ? ' has' : 's have'} no dates yet and cannot be placed on the timeline — " : ''}'
                        'Use "Run CPM" in the Builder tab to recompute dates and critical path.',
                        style: const TextStyle(
                            color: Color(0xFF495057),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Rows for the timeline, plus how many work packages could not be placed.
  ///
  /// Containers are included and their window is ROLLED UP from their
  /// descendants (earliest start → latest finish), which is what the product
  /// owner asked for (2026-09-10): "it's supposed to show the duration of each
  /// work package and roll up to each one".
  ///
  /// This replaces two silent drops that made real work packages disappear from
  /// the Gantt while the tree view still listed them:
  ///   - every `ActivityType.summary` node was skipped — and `_typeForPackage`
  ///     falls back to `summary` for any work-package classification it does not
  ///     recognise, so unrecognised work packages vanished outright;
  ///   - any activity missing either date was skipped. Those genuinely cannot be
  ///     drawn on a time axis, so they are now COUNTED and surfaced instead of
  ///     vanishing without explanation.
  ({List<_GanttRowData> rows, int unscheduled, int total}) _buildRows(
      List<ScheduleActivity> roots) {
    final rows = <_GanttRowData>[];
    var unscheduled = 0;
    var total = 0;

    void count(ScheduleActivity node) {
      total++;
      for (final child in node.children) {
        count(child);
      }
    }

    for (final root in roots) {
      count(root);
    }

    /// Earliest start / latest finish across [node] and all its descendants.
    ({DateTime? start, DateTime? finish}) windowOf(ScheduleActivity node) {
      var start = node.startDate;
      var finish = node.endDate;
      for (final child in node.children) {
        final w = windowOf(child);
        if (w.start != null && (start == null || w.start!.isBefore(start))) {
          start = w.start;
        }
        if (w.finish != null && (finish == null || w.finish!.isAfter(finish))) {
          finish = w.finish;
        }
      }
      return (start: start, finish: finish);
    }

    void addRow(ScheduleActivity a) {
      final window = windowOf(a);
      var start = window.start;
      var finish = window.finish;
      // A node carrying only one date can still be placed using its planned
      // duration — CPM may not have run yet to fill in the other end.
      final durationDays = (a.duration ?? 0).round();
      if (start != null && finish == null && durationDays > 0) {
        finish = start.add(Duration(days: durationDays - 1));
      } else if (finish != null && start == null && durationDays > 0) {
        start = finish.subtract(Duration(days: durationDays - 1));
      }
      if (start == null || finish == null) {
        // Count leaf work packages only, so an undated branch reports once
        // rather than once per ancestor.
        if (a.children.isEmpty) unscheduled++;
        return;
      }
      rows.add(_GanttRowData(
        code: a.code,
        name: a.name,
        domainColor: a.domain.color,
        isCritical: a.isCriticalPath,
        isMilestone: a.type == ActivityType.milestone,
        goalKey: _goalKeyOf(a),
        startDate: start,
        endDate: finish,
        sprintLabel: a.sprintLabel ?? '',
        releaseLabel: a.releaseLabel ?? '',
        agileEpicTitle: a.agileEpicTitle ?? '',
        agileFeatureTitle: a.agileFeatureTitle ?? '',
        hasWbs: a.wbsNodeId != null && a.wbsNodeId!.isNotEmpty,
        hasAgileStory: a.agileTaskId != null && a.agileTaskId!.isNotEmpty,
        prerequisiteCount: a.prerequisites?.length ?? 0,
      ));
    }

    void draw(ScheduleActivity node) {
      addRow(node);
      for (final child in node.children) {
        draw(child);
      }
    }

    for (final root in roots) {
      // The project root is the schedule itself, not a work package, so it is
      // descended into but never drawn as its own row.
      if (root.children.isEmpty) {
        addRow(root);
      } else {
        for (final child in root.children) {
          draw(child);
        }
      }
    }

    rows.sort((a, b) => a.startDate.compareTo(b.startDate));
    return (rows: rows, unscheduled: unscheduled, total: total);
  }

  /// The goal (top-level WBS element, e.g. G1 / G2) an activity rolls up to.
  ///
  /// Lusaka 28: "everything under goal one might all be this specific color,
  /// anything that fits goal two, goal three…" — color coding by goal makes
  /// misplaced items visually obvious. Derived from the G-prefixed WBS code
  /// (G1.2.3 → G1); activities without a WBS code fall back to their domain.
  String _goalKeyOf(ScheduleActivity a) {
    var node = a;
    String? code;
    // Prefer the activity's own WBS code; parents are materialised in the
    // tree, so walking up covers summary-level placements.
    while (code == null || code.isEmpty) {
      final c = node.wbsCode?.trim() ?? '';
      if (c.isNotEmpty) {
        code = c;
        break;
      }
      if (node.wbsNodeId != null && node.wbsNodeId!.trim().isNotEmpty) {
        code = node.wbsCode ?? '';
        break;
      }
      break;
    }
    if (code != null && code.isNotEmpty) {
      final topLevel = code.split('.').first.trim();
      if (topLevel.isNotEmpty) return topLevel;
    }
    return '';
  }

  /// Deterministic bar color per goal key (G1 → color 0, G2 → color 1, …).
  /// Activities outside any goal keep their domain color.
  static const List<int> _goalPalette = [
    0xFF6366F1, // indigo
    0xFF0EA5E9, // sky
    0xFF10B981, // emerald
    0xFFF97316, // orange
    0xFFEC4899, // pink
    0xFF8B5CF6, // violet
    0xFF14B8A6, // teal
    0xFFEF4444, // red
  ];

  static Color colorForGoal(String goalKey, int domainColor) {
    if (goalKey.isEmpty) return Color(domainColor);
    final idx = goalKey.hashCode.abs() % _goalPalette.length;
    return Color(_goalPalette[idx]);
  }
}

/// The Gantt grid card: header row plus one row per activity, in a horizontal
/// scroll view so a long timeline can still be panned.
///
/// Split out of [_GanttScreenState] so the width calculation lives in a
/// `LayoutBuilder` with a bounded parent. The cell width is already resolved by
/// the caller; this widget just lays the grid out at it.
class _GanttTable extends StatelessWidget {
  final List<String> cellLabels;
  final List<DateTime> cellStarts;
  final List<_GanttRowData> rows;
  final DateTime timelineStart;
  final _GanttScale scale;
  final double cellWidth;
  final double leftColWidth;

  const _GanttTable({
    required this.cellLabels,
    required this.cellStarts,
    required this.rows,
    required this.timelineStart,
    required this.scale,
    required this.cellWidth,
    required this.leftColWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GanttHeaderRow(
                cellLabels: cellLabels,
                leftColWidth: leftColWidth,
                cellWidth: cellWidth),
            const Divider(color: Color(0xFFE4E7EC), height: 1, thickness: 1),
            ...rows.map((r) => _GanttRow(
                  row: r,
                  timelineStart: timelineStart,
                  cellStarts: cellStarts,
                  scale: scale,
                  cellWidth: cellWidth,
                  leftColWidth: leftColWidth,
                )),
          ],
        ),
      ),
    );
  }
}

class _GanttHeaderRow extends StatelessWidget {
  final List<String> cellLabels;
  final double leftColWidth;
  final double cellWidth;

  const _GanttHeaderRow({
    required this.cellLabels,
    required this.leftColWidth,
    required this.cellWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: leftColWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border:
                Border(right: BorderSide(color: Color(0xFFE4E7EC), width: 1)),
          ),
          child: const Text('Activity',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        ...cellLabels.map((label) => Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                    right: BorderSide(color: Color(0xFFE4E7EC), width: 0.5)),
              ),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontFamily: appFontFamily)),
            )),
      ],
    );
  }
}

class _GanttRow extends StatelessWidget {
  final _GanttRowData row;
  final DateTime timelineStart;
  final List<DateTime> cellStarts;
  final _GanttScale scale;
  final double cellWidth;
  final double leftColWidth;

  const _GanttRow({
    required this.row,
    required this.timelineStart,
    required this.cellStarts,
    required this.scale,
    required this.cellWidth,
    required this.leftColWidth,
  });

  String _subtitleText() {
    final parts = <String>[];
    if (row.agileEpicTitle.isNotEmpty) {
      parts.add('Epic: ${row.agileEpicTitle}');
    }
    if (row.agileFeatureTitle.isNotEmpty) {
      parts.add('Feature: ${row.agileFeatureTitle}');
    }
    if (row.sprintLabel.isNotEmpty) {
      parts.add(row.sprintLabel);
    }
    if (row.releaseLabel.isNotEmpty) {
      parts.add(row.releaseLabel);
    }
    return parts.join(' · ');
  }

  String _tooltipText() {
    final parts = <String>[
      row.name,
      'Code: ${row.code}',
      'Start: ${row.startDate.month}/${row.startDate.day}/${row.startDate.year}',
      'Finish: ${row.endDate.month}/${row.endDate.day}/${row.endDate.year}',
    ];
    if (row.agileEpicTitle.isNotEmpty) parts.add('Epic: ${row.agileEpicTitle}');
    if (row.agileFeatureTitle.isNotEmpty) {
      parts.add('Feature: ${row.agileFeatureTitle}');
    }
    if (row.sprintLabel.isNotEmpty) parts.add('Sprint: ${row.sprintLabel}');
    if (row.releaseLabel.isNotEmpty) parts.add('Release: ${row.releaseLabel}');
    if (row.hasWbs) parts.add('WBS linked');
    if (row.hasAgileStory) parts.add('Agile story linked');
    if (row.prerequisiteCount > 0) {
      parts.add('Prerequisites: ${row.prerequisiteCount}');
    }
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    // Scale-aware placement: interpolate pixel offsets directly from dates
    // across the visible timeline.
    final pxPerDay = cellWidth / scale.days;
    final barLeft = row.startDate.difference(timelineStart).inDays * pxPerDay;
    final barRight =
        (row.endDate.difference(timelineStart).inDays + 1) * pxPerDay;
    final barWidth = (barRight - barLeft).clamp(cellWidth / scale.days, double.infinity);
    final timelineWidth = cellStarts.length * cellWidth;
    final isMilestone = row.isMilestone;

    return Column(
      children: [
        // The table sits in a HORIZONTAL scroll view, so its cross axis
        // (height) is unbounded. `CrossAxisAlignment.stretch` against unbounded
        // height forces the children to infinite height and throws during
        // layout — which meant NO row could be drawn at all. IntrinsicHeight
        // gives the row a concrete height (tall enough for a wrapped label)
        // that stretch can then apply to both cells.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Container(
              width: leftColWidth,
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                    right: BorderSide(color: Color(0xFFE4E7EC), width: 1)),
              ),
              child: Tooltip(
                message: _tooltipText(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Color(row.domainColor),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(row.code,
                            style: const TextStyle(
                                color: Color(0xFF495057),
                                fontSize: 10,
                                fontFamily: appFontFamily,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 14),
                      child: Text(
                        row.name,
                        softWrap: true,
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_subtitleText().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 20),
                        child: Text(
                          _subtitleText(),
                          softWrap: true,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: timelineWidth,
              constraints: const BoxConstraints(minHeight: 76),
              color: Colors.white,
              child: Stack(
                children: [
                  ...List.generate(cellStarts.length + 1, (i) {
                    return Positioned(
                      left: i * cellWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 0.5,
                        color: const Color(0xFFE4E7EC),
                      ),
                    );
                  }),
                  if (isMilestone)
                    // Milestones render as diamonds (Lusaka 28): they have to
                    // be visually distinct from work bars so the crew can see
                    // what the schedule is being built around.
                    Positioned(
                      left: barLeft - 7,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Tooltip(
                          message:
                              '${row.name} — ${row.endDate.month}/${row.endDate.day}/${row.endDate.year}',
                          child: Transform.rotate(
                            angle: 3.14159 / 4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _GanttScreenState.colorForGoal(
                                    row.goalKey, row.domainColor),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: barLeft + 2,
                      top: 8,
                      bottom: 8,
                      width: (barWidth - 4).clamp(4.0, double.infinity),
                      child: Container(
                        decoration: BoxDecoration(
                          // Lusaka 28: color-code by GOAL (top-level WBS
                          // element) so everything under G1 reads as one
                          // family, G2 another, etc. Activities without a WBS
                          // link keep their domain color.
                          color: _GanttScreenState
                              .colorForGoal(row.goalKey, row.domainColor)
                              .withValues(alpha: row.isCritical ? 0.85 : 0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: row.isCritical
                                ? LightModeColors.accent
                                : Color(row.domainColor),
                            width: row.isCritical ? 1.5 : 0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${row.endDate.difference(row.startDate).inDays + 1}d',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ],
          ),
        ),
        const Divider(color: Color(0xFFE4E7EC), height: 1, thickness: 0.5),
      ],
    );
  }
}

class _GanttRowData {
  final String code;
  final String name;
  final int domainColor;
  final bool isCritical;
  final bool isMilestone;
  final String goalKey;
  final DateTime startDate;
  final DateTime endDate;
  final String sprintLabel;
  final String releaseLabel;
  final String agileEpicTitle;
  final String agileFeatureTitle;
  final bool hasWbs;
  final bool hasAgileStory;
  final int prerequisiteCount;

  const _GanttRowData({
    required this.code,
    required this.name,
    required this.domainColor,
    required this.isCritical,
    required this.startDate,
    required this.endDate,
    this.isMilestone = false,
    this.goalKey = '',
    this.sprintLabel = '',
    this.releaseLabel = '',
    this.agileEpicTitle = '',
    this.agileFeatureTitle = '',
    this.hasWbs = false,
    this.hasAgileStory = false,
    this.prerequisiteCount = 0,
  });
}
