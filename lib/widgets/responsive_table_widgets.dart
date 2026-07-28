import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Responsive wrapper for data tables with horizontal scroll support
class ResponsiveDataTableWrapper extends StatefulWidget {
  final Widget child;
  final double? minWidth;
  final double? maxHeight;
  final String? title;
  final bool enableFullscreen;

  const ResponsiveDataTableWrapper({
    super.key,
    required this.child,
    this.minWidth,
    this.maxHeight,
    this.title,
    this.enableFullscreen = false,
  });

  @override
  State<ResponsiveDataTableWrapper> createState() =>
      _ResponsiveDataTableWrapperState();
}

class _ResponsiveDataTableWrapperState
    extends State<ResponsiveDataTableWrapper> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _canScrollRight = false;
  bool _canScrollDown = false;

  Future<void> _scrollForMore() async {
    if (_canScrollRight && _horizontalController.hasClients) {
      final position = _horizontalController.position;
      await _horizontalController.animateTo(
        (position.pixels + 360).clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_canScrollDown && _verticalController.hasClients) {
      final position = _verticalController.position;
      await _verticalController.animateTo(
        (position.pixels + 320).clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openFullscreenTable() {
    final screenSize = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width - 36,
            maxHeight: screenSize.height - 36,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title ?? 'Table view',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ResponsiveDataTableWrapper(
                    minWidth: widget.minWidth,
                    maxHeight: screenSize.height - 150,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_updateScrollIndicators);
    _verticalController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _horizontalController
      ..removeListener(_updateScrollIndicators)
      ..dispose();
    _verticalController
      ..removeListener(_updateScrollIndicators)
      ..dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!mounted) return;
    final h = _horizontalController.hasClients
        ? _horizontalController.position
        : null;
    final v =
        _verticalController.hasClients ? _verticalController.position : null;
    final canRight =
        h != null && h.maxScrollExtent > 0 && h.pixels < h.maxScrollExtent - 1;
    final canDown =
        v != null && v.maxScrollExtent > 0 && v.pixels < v.maxScrollExtent - 1;
    if (canRight != _canScrollRight || canDown != _canScrollDown) {
      _setStateWhenSafe(() {
        _canScrollRight = canRight;
        _canScrollDown = canDown;
      });
    }
  }

  void _setStateWhenSafe(VoidCallback update) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(update);
      });
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalChild = SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth ?? constraints.maxWidth,
            ),
            child: widget.child,
          ),
        );

        final tableContent = widget.maxHeight == null
            ? horizontalChild
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: horizontalChild,
                  ),
                ),
              );

        final tableStack = Stack(
          children: [
            Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              interactive: true,
              notificationPredicate: (notification) =>
                  notification.depth == 0 &&
                  notification.metrics.axis == Axis.horizontal,
              child: tableContent,
            ),
            if (_canScrollRight)
              Positioned(
                top: 0,
                right: 0,
                bottom: widget.maxHeight == null ? 0 : 18,
                child: IgnorePointer(
                  child: Container(
                    width: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0x00FFFFFF), Color(0xFFF8FAFC)],
                      ),
                    ),
                  ),
                ),
              ),
            if (_canScrollDown)
              Positioned(
                left: 0,
                right: 18,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FFFFFF), Color(0xFFF8FAFC)],
                      ),
                    ),
                  ),
                ),
              ),
            if (_canScrollRight)
              Positioned(
                right: 8,
                bottom: 2,
                child: GestureDetector(
                  onTap: () {
                    _horizontalController.animateTo(
                      _horizontalController.offset + 300,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  },
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC812).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFC812).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Scroll to see more ->',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        if (!widget.enableFullscreen && widget.title == null) {
          return tableStack;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null || widget.enableFullscreen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (widget.title != null)
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (widget.enableFullscreen)
                      OutlinedButton.icon(
                        onPressed: _openFullscreenTable,
                        icon: const Icon(Icons.open_in_full, size: 16),
                        label: const Text('Full view'),
                      ),
                  ],
                ),
              ),
            tableStack,
          ],
        );
      },
    );
  }
}

/// Truncated cell for data tables with tooltip
class TruncatedTableCell extends StatelessWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final double? maxWidth;

  const TruncatedTableCell({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.style,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    if (text.length > 30) {
      return Tooltip(
        message: text,
        child: maxWidth != null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth!),
                child: textWidget,
              )
            : textWidget,
      );
    }

    return maxWidth != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: textWidget,
          )
        : textWidget;
  }
}

List<DataRow> nduZebraRows(
  BuildContext context,
  List<DataRow> rows, {
  Color? oddRowColor,
  Color? evenRowColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final resolvedEven =
      evenRowColor ?? (isDark ? const Color(0xFF151922) : Colors.white);
  final resolvedOdd = oddRowColor ??
      (isDark ? const Color(0xFF10151D) : const Color(0xFFFAFCFF));

  return rows.asMap().entries.map((entry) {
    final index = entry.key;
    final row = entry.value;
    return DataRow.byIndex(
      index: index,
      selected: row.selected,
      onSelectChanged: row.onSelectChanged,
      onLongPress: row.onLongPress,
      mouseCursor: row.mouseCursor,
      color: row.color ??
          WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF7E6);
            }
            return index.isOdd ? resolvedOdd : resolvedEven;
          }),
      cells: row.cells,
    );
  }).toList(growable: false);
}

DataTable buildNduDataTable({
  required BuildContext context,
  required List<DataColumn> columns,
  required List<DataRow> rows,
  double columnSpacing = 18,
  double horizontalMargin = 14,
  double headingRowHeight = 52,
  double dataRowMinHeight = 60,
  double dataRowMaxHeight = 220,
  TableBorder? border,
  bool zebra = true,
  Color? headingRowColor,
  bool showCheckboxColumn = false,
  TextStyle? headingTextStyle,
  TextStyle? dataTextStyle,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final resolvedHeadingColor = headingRowColor ??
      (isDark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FC));
  final normalizedRows = zebra ? nduZebraRows(context, rows) : rows;

  final resolvedHeadingTextStyle = headingTextStyle ??
      TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        letterSpacing: 0.2,
      );
  final resolvedDataTextStyle = dataTextStyle ??
      TextStyle(
        fontSize: 13,
        height: 1.45,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
      );

  return DataTable(
    showCheckboxColumn: showCheckboxColumn,
    headingRowColor: WidgetStatePropertyAll(resolvedHeadingColor),
    headingTextStyle: resolvedHeadingTextStyle,
    dataTextStyle: resolvedDataTextStyle,
    dividerThickness: 0.8,
    columnSpacing: columnSpacing,
    horizontalMargin: horizontalMargin,
    headingRowHeight: headingRowHeight,
    dataRowMinHeight: dataRowMinHeight,
    dataRowMaxHeight: dataRowMaxHeight,
    border: border,
    columns: columns,
    rows: normalizedRows,
  );
}

Widget buildNduTableEmptyState(
  BuildContext context, {
  required String message,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
        ),
      ),
    ),
  );
}
