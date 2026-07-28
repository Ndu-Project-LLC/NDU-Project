import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/theme.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ScheduleGanttEnhanced extends StatefulWidget {
  const ScheduleGanttEnhanced({
    super.key,
    required this.scheduleActivities,
    required this.workPackages,
    this.onActivityTap,
    this.onActivityHover,
    this.selectedActivityId,
    this.hoveredActivityId,
  });

  final List<ScheduleActivity> scheduleActivities;
  final List<WorkPackage> workPackages;
  final ValueChanged<ScheduleActivity>? onActivityTap;
  final ValueChanged<ScheduleActivity?>? onActivityHover;
  final String? selectedActivityId;
  final String? hoveredActivityId;

  @override
  State<ScheduleGanttEnhanced> createState() => _ScheduleGanttEnhancedState();
}

class _ScheduleGanttEnhancedState extends State<ScheduleGanttEnhanced> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  String? _selectedId;
  String? _hoveredId;
  String _searchQuery = '';

  final double _leftColumnWidth = 320;
  final double _chartHeightPerRow = 48;
  double _pxPerDay = 3.0;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _selectedId = widget.selectedActivityId;
    _hoveredId = widget.hoveredActivityId;
  }

  @override
  void didUpdateWidget(covariant ScheduleGanttEnhanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedActivityId != oldWidget.selectedActivityId) {
      _selectedId = widget.selectedActivityId;
    }
    if (widget.hoveredActivityId != oldWidget.hoveredActivityId) {
      _hoveredId = widget.hoveredActivityId;
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  List<_GanttItem> _buildGanttItems() {
    final items = <_GanttItem>[];
    final wpById = <String, WorkPackage>{};
    for (final wp in widget.workPackages) {
      wpById[wp.id] = wp;
    }

    for (final activity in widget.scheduleActivities) {
      final wp = activity.workPackageId.isNotEmpty
          ? wpById[activity.workPackageId]
          : null;
      items.add(
        _GanttItem(
          id: activity.id,
          title: activity.title,
          startDate: _parseDate(activity.startDate),
          endDate: _parseDate(activity.dueDate),
          durationDays: activity.durationDays,
          progress: activity.progress,
          isCriticalPath: activity.isCriticalPath,
          isMilestone: activity.isMilestone,
          status: activity.status,
          workPackageTitle: wp?.title ?? '',
          wbsLevel2Title: activity.wbsLevel2Title,
          predecessorIds: activity.predecessorIds,
        ),
      );
    }

    items.sort((a, b) {
      if (a.wbsLevel2Title != b.wbsLevel2Title) {
        return a.wbsLevel2Title.compareTo(b.wbsLevel2Title);
      }
      if (a.workPackageTitle != b.workPackageTitle) {
        return a.workPackageTitle.compareTo(b.workPackageTitle);
      }
      final aDate = a.startDate ?? DateTime(2000);
      final bDate = b.startDate ?? DateTime(2000);
      return aDate.compareTo(bDate);
    });

    return items;
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    var items = _buildGanttItems();
    if (items.isEmpty) {
      return const _EmptyGanttView();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((item) =>
              item.title.toLowerCase().contains(q) ||
              item.workPackageTitle.toLowerCase().contains(q) ||
              item.wbsLevel2Title.toLowerCase().contains(q) ||
              item.status.toLowerCase().contains(q))
          .toList();
      if (items.isEmpty) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppSemanticColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Enhanced Gantt Chart',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  _buildSearchBar(),
                ],
              ),
              const SizedBox(height: 24),
              const Icon(Icons.search_off, size: 40, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 8),
              Text('No activities match "$_searchQuery"',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ],
          ),
        );
      }
    }

    final dates = items
        .expand((item) => [item.startDate, item.endDate])
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) {
      return const _EmptyGanttView();
    }

    dates.sort();
    final minDate = dates.first;
    final maxDate = dates.last;
    final totalDays = maxDate.difference(minDate).inDays + 1;
    final timelineWidth = (totalDays * _pxPerDay).clamp(800.0, 4000.0);
    final chartHeight = (items.length * _chartHeightPerRow + 80).toDouble();

    final monthSegments = _generateMonthSegments(minDate, maxDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Enhanced Gantt Chart',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              // Zoom controls (P8)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: () {
                        setState(() {
                          _pxPerDay = (_pxPerDay - 0.5).clamp(1.0, 8.0);
                        });
                      },
                      tooltip: 'Zoom out',
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${(_pxPerDay * 100 / 3).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () {
                        setState(() {
                          _pxPerDay = (_pxPerDay + 0.5).clamp(1.0, 8.0);
                        });
                      },
                      tooltip: 'Zoom in',
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_outlined, size: 16),
                      onPressed: () {
                        setState(() {
                          _pxPerDay = 3.0; // Reset to default (100%)
                        });
                      },
                      tooltip: 'Fit to screen',
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSearchBar(),
              const SizedBox(width: 12),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight.clamp(300.0, 600.0),
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _leftColumnWidth + timelineWidth + 2,
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(
                            timelineWidth,
                            monthSegments,
                            _pxPerDay,
                            minDate,
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size(
                                  _leftColumnWidth + timelineWidth,
                                  (items.length * _chartHeightPerRow + 36).toDouble(),
                                ),
                                painter: _EnhancedGanttGridPainter(
                                  rowHeight: _chartHeightPerRow,
                                  rowCount: items.length,
                                  monthSegments: monthSegments,
                                  pxPerDay: _pxPerDay,
                                  leftColumnWidth: _leftColumnWidth,
                                ),
                              ),
                              CustomPaint(
                                size: Size(
                                  _leftColumnWidth + timelineWidth,
                                  (items.length * _chartHeightPerRow + 36).toDouble(),
                                ),
                                painter: _EnhancedDependencyPainter(
                                  items: items,
                                  leftColumnWidth: _leftColumnWidth,
                                  rowHeight: _chartHeightPerRow,
                                  startDate: minDate,
                                  pxPerDay: _pxPerDay,
                                  selectedId: _selectedId,
                                  hoveredId: _hoveredId,
                                ),
                              ),
                              for (int i = 0; i < items.length; i++)
                                _buildGanttRow(
                                  items[i],
                                  i,
                                  minDate,
                                  timelineWidth,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: 220,
      height: 34,
      child: VoiceTextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search activities...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          prefixIcon:
              const Icon(Icons.search, size: 16, color: Color(0xFF6B7280)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppSemanticColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppSemanticColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(const Color(0xFFEF4444), 'Critical Path'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFF3B82F6), 'Normal'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFF59E0B), 'Milestone'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildHeader(
    double timelineWidth,
    List<_MonthSegment> segments,
    double pxPerDay,
    DateTime startDate,
  ) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppSemanticColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _leftColumnWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'Task / Work Package / WBS Level 2',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            height: 32,
            child: Row(
              children: segments.map((seg) {
                final width = seg.dayCount * pxPerDay;
                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatMonth(seg),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttRow(
    _GanttItem item,
    int index,
    DateTime startDate,
    double timelineWidth,
  ) {
    final top = index * _chartHeightPerRow + 6;
    final leftOffset =
        (item.startDate ?? startDate).difference(startDate).inDays * _pxPerDay;
    final durationDays = item.durationDays == 0 ? 1 : item.durationDays;
    final width = (durationDays * _pxPerDay).clamp(20.0, 800.0);

    final color = item.isMilestone
        ? const Color(0xFFF59E0B)
        : item.isCriticalPath
            ? const Color(0xFFEF4444)
            : const Color(0xFF3B82F6);

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: _chartHeightPerRow - 10,
      child: Row(
        children: [
          SizedBox(
            width: _leftColumnWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (item.isCriticalPath)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.title.isNotEmpty ? item.title : 'Untitled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.workPackageTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'WP: ${item.workPackageTitle}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  left: leftOffset,
                  top: 4,
                  child: MouseRegion(
                    onEnter: (_) {
                      Future.microtask(() {
                        if (mounted) setState(() => _hoveredId = item.id);
                      });
                      widget.onActivityHover
                          ?.call(_findActivity(item.id));
                    },
                    onExit: (_) {
                      Future.microtask(() {
                        if (mounted) setState(() => _hoveredId = null);
                      });
                      widget.onActivityHover?.call(null);
                    },
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedId = item.id);
                        widget.onActivityTap
                            ?.call(_findActivity(item.id));
                      },
                      child: Container(
                        height: _chartHeightPerRow - 18,
                        width: width,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedId == item.id
                              ? Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 2,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: item.isMilestone
                            ? const Icon(
                                Icons.flag,
                                size: 14,
                                color: Colors.white,
                              )
                            : Text(
                                '${(item.progress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
    );
  }

  ScheduleActivity _findActivity(String id) {
    return widget.scheduleActivities.firstWhere(
      (a) => a.id == id,
      orElse: () => ScheduleActivity(id: id),
    );
  }

  String _formatMonth(_MonthSegment seg) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[seg.month - 1]} ${seg.year}';
  }

  List<_MonthSegment> _generateMonthSegments(DateTime start, DateTime end) {
    final segments = <_MonthSegment>[];
    var current = DateTime(start.year, start.month, 1);
    while (!current.isAfter(DateTime(end.year, end.month, 31))) {
      final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
      final days = daysInMonth - (current.isAtSameMomentAs(DateTime(start.year, start.month, start.day)) ? start.day - 1 : 0);
      segments.add(_MonthSegment(
        year: current.year,
        month: current.month,
        dayCount: days,
      ));
      current = DateTime(current.year, current.month + 1, 1);
    }
    return segments;
  }
}

class _GanttItem {
  const _GanttItem({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.progress,
    required this.isCriticalPath,
    required this.isMilestone,
    required this.status,
    required this.workPackageTitle,
    required this.wbsLevel2Title,
    required this.predecessorIds,
  });

  final String id;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final int durationDays;
  final double progress;
  final bool isCriticalPath;
  final bool isMilestone;
  final String status;
  final String workPackageTitle;
  final String wbsLevel2Title;
  final List<String> predecessorIds;
}

class _MonthSegment {
  const _MonthSegment({
    required this.year,
    required this.month,
    required this.dayCount,
  });

  final int year;
  final int month;
  final int dayCount;
}

class _EnhancedGanttGridPainter extends CustomPainter {
  const _EnhancedGanttGridPainter({
    required this.rowHeight,
    required this.rowCount,
    required this.monthSegments,
    required this.pxPerDay,
    required this.leftColumnWidth,
  });

  final double rowHeight;
  final int rowCount;
  final List<_MonthSegment> monthSegments;
  final double pxPerDay;
  final double leftColumnWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rowPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int row = 0; row <= rowCount; row++) {
      final y = row * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rowPaint);
    }

    final dividerPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1;

    double x = leftColumnWidth;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    for (final segment in monthSegments) {
      x += segment.dayCount * pxPerDay;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedGanttGridPainter old) => false;
}

class _EnhancedDependencyPainter extends CustomPainter {
  const _EnhancedDependencyPainter({
    required this.items,
    required this.leftColumnWidth,
    required this.rowHeight,
    required this.startDate,
    required this.pxPerDay,
    required this.selectedId,
    required this.hoveredId,
  });

  final List<_GanttItem> items;
  final double leftColumnWidth;
  final double rowHeight;
  final DateTime startDate;
  final double pxPerDay;
  final String? selectedId;
  final String? hoveredId;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedId == null && hoveredId == null) return;

    final focusIds = <String>{};
    if (selectedId != null) focusIds.add(selectedId!);
    if (hoveredId != null) focusIds.add(hoveredId!);

    final byId = {for (final item in items) item.id: item};

    final paint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final targetId in focusIds) {
      final target = byId[targetId];
      if (target == null) continue;

      final targetRow = items.indexWhere((e) => e.id == target.id);
      final targetY = targetRow * rowHeight + (rowHeight / 2);
      final targetX =
          leftColumnWidth + (target.startDate ?? startDate).difference(startDate).inDays * pxPerDay;

      for (final predId in target.predecessorIds) {
        final pred = byId[predId];
        if (pred == null) continue;

        final predRow = items.indexWhere((e) => e.id == pred.id);
        final predY = predRow * rowHeight + (rowHeight / 2);
        final predWidth =
            (pred.durationDays == 0 ? 1 : pred.durationDays) * pxPerDay;
        final predX = leftColumnWidth +
            (pred.startDate ?? startDate).difference(startDate).inDays * pxPerDay +
            predWidth;

        final path = Path()
          ..moveTo(predX, predY)
          ..lineTo(predX + 12, predY)
          ..lineTo(predX + 12, targetY)
          ..lineTo(targetX, targetY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedDependencyPainter old) {
    return old.selectedId != selectedId ||
        old.hoveredId != hoveredId ||
        old.items != items;
  }
}

class _EmptyGanttView extends StatelessWidget {
  const _EmptyGanttView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.view_timeline_outlined,
            size: 48,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Schedule Activities',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add schedule activities or import from WBS to see the Gantt chart.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
