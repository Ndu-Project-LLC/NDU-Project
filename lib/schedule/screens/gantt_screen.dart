library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

class GanttScreen extends StatelessWidget {
  const GanttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final schedule = provider.schedule!;
        final allActivities = _flatten(schedule.activities);
        final rows = _buildRows(allActivities);

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

        final totalDays = maxEndDate.difference(baseDate).inDays + 1;
        final weekCount = (totalDays / 7).ceil().clamp(1, 52);
        const cellWidth = 56.0;

        final weekLabels = List<String>.generate(weekCount, (i) {
          final start = baseDate.add(Duration(days: i * 7));
          return '${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')}';
        });

        final criticalCount = rows.where((r) => r.isCritical).length;

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
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${allActivities.length} activities · $criticalCount on critical path · $weekCount-week view',
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GanttHeaderRow(
                            weekLabels: weekLabels,
                            leftColWidth: 280,
                            cellWidth: cellWidth),
                        const Divider(
                            color: Color(0xFFE4E7EC), height: 1, thickness: 1),
                        ...rows.map((r) => _GanttRow(
                              row: r,
                              baseDate: baseDate,
                              weekCount: weekCount,
                              cellWidth: cellWidth,
                              leftColWidth: 280,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
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

  List<ScheduleActivity> _flatten(List<ScheduleActivity> roots) {
    final result = <ScheduleActivity>[];
    void walk(ScheduleActivity node) {
      result.add(node);
      for (final c in node.children) walk(c);
    }

    for (final r in roots) walk(r);
    return result;
  }

  List<_GanttRowData> _buildRows(List<ScheduleActivity> activities) {
    final result = <_GanttRowData>[];
    for (final a in activities) {
      if (a.type == ActivityType.summary) continue;
      final start = a.startDate;
      final end = a.endDate;
      if (start == null || end == null) continue;
      result.add(_GanttRowData(
        code: a.code,
        name: a.name,
        domainColor: a.domain.color,
        isCritical: a.isCriticalPath,
        startDate: start,
        endDate: end,
        sprintLabel: a.sprintLabel ?? '',
        releaseLabel: a.releaseLabel ?? '',
        agileEpicTitle: a.agileEpicTitle ?? '',
        agileFeatureTitle: a.agileFeatureTitle ?? '',
        hasWbs: a.wbsNodeId != null && a.wbsNodeId!.isNotEmpty,
        hasAgileStory: a.agileTaskId != null && a.agileTaskId!.isNotEmpty,
        prerequisiteCount: a.prerequisites?.length ?? 0,
      ));
    }
    result.sort((a, b) => a.startDate.compareTo(b.startDate));
    return result;
  }
}

class _GanttHeaderRow extends StatelessWidget {
  final List<String> weekLabels;
  final double leftColWidth;
  final double cellWidth;

  const _GanttHeaderRow({
    required this.weekLabels,
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
        ...weekLabels.map((label) => Container(
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
  final DateTime baseDate;
  final int weekCount;
  final double cellWidth;
  final double leftColWidth;

  const _GanttRow({
    required this.row,
    required this.baseDate,
    required this.weekCount,
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
    if (row.agileFeatureTitle.isNotEmpty)
      parts.add('Feature: ${row.agileFeatureTitle}');
    if (row.sprintLabel.isNotEmpty) parts.add('Sprint: ${row.sprintLabel}');
    if (row.releaseLabel.isNotEmpty) parts.add('Release: ${row.releaseLabel}');
    if (row.hasWbs) parts.add('WBS linked');
    if (row.hasAgileStory) parts.add('Agile story linked');
    if (row.prerequisiteCount > 0)
      parts.add('Prerequisites: ${row.prerequisiteCount}');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final daysSinceBase = row.startDate.difference(baseDate).inDays;
    final durationDays = row.endDate.difference(row.startDate).inDays + 1;
    final pxPerDay = cellWidth / 7;

    final barLeft = daysSinceBase * pxPerDay;
    final barWidth = durationDays * pxPerDay;
    final timelineWidth = weekCount * cellWidth;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: leftColWidth,
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
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(row.name,
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (_subtitleText().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 20),
                        child: Text(
                          _subtitleText(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              height: 36,
              color: Colors.white,
              child: Stack(
                children: [
                  ...List.generate(weekCount + 1, (i) {
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
                  Positioned(
                    left: barLeft + 2,
                    top: 8,
                    bottom: 8,
                    width: barWidth - 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: row.isCritical
                            ? Color(row.domainColor).withValues(alpha: 0.85)
                            : Color(row.domainColor).withValues(alpha: 0.6),
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
                            '${durationDays}d',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
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
    this.sprintLabel = '',
    this.releaseLabel = '',
    this.agileEpicTitle = '',
    this.agileFeatureTitle = '',
    this.hasWbs = false,
    this.hasAgileStory = false,
    this.prerequisiteCount = 0,
  });
}
