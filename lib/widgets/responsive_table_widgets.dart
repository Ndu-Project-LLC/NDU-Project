import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

/// Responsive wrapper for data tables with horizontal scroll support
class ResponsiveDataTableWrapper extends StatefulWidget {
  final Widget child;
  final double? minWidth;
  final double? maxHeight;

  const ResponsiveDataTableWrapper({
    super.key,
    required this.child,
    this.minWidth,
    this.maxHeight,
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
        // Guard against unbounded constraints — if the parent gives us
        // infinite width/height, we cannot lay out a Stack with Positioned
        // children. Fall back to a plain scroll view in that case.
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final hasBoundedHeight =
            widget.maxHeight != null || constraints.maxHeight.isFinite;

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
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: horizontalChild,
                  ),
                ),
              );

        // If we don't have bounded constraints, skip the Stack overlay
        // entirely — the Positioned children require a bounded parent to
        // compute their layout, and without it Flutter throws
        // `box.dart:2251 assert(hasSize)` and `mouse_tracker.dart:199`
        // assertion failures.
        if (!hasBoundedWidth || !hasBoundedHeight) {
          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.depth == 0 &&
                notification.metrics.axis == Axis.horizontal,
            child: tableContent,
          );
        }

        return SizedBox(
          // Explicitly bound the Stack so Positioned children always have
          // a deterministic parent size.
          width: constraints.maxWidth,
          height: widget.maxHeight ?? constraints.maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC812).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFFFC812).withValues(alpha: 0.3)),
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
          ),
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
              return isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF8E1);
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
  bool autoWrapCells = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final resolvedHeadingColor = headingRowColor ??
      (isDark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FC));

  // Auto-wrap any plain Text children inside cells so long text wraps
  // instead of overflowing the screen. This is a no-op for cells that
  // already use WrappedText or non-text children.
  final processedRows = autoWrapCells ? _wrapRowsCells(rows) : rows;
  final normalizedRows = zebra ? nduZebraRows(context, processedRows) : processedRows;

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

/// Walk every [DataRow] / [DataCell] and replace plain [Text] children with
/// [WrappedText] so the cell text wraps rather than overflows.
///
/// Cells that already use [WrappedText] (or non-text children) are passed
/// through unchanged. This is what powers `buildNduDataTable(autoWrapCells: true)`.
List<DataRow> _wrapRowsCells(List<DataRow> rows) {
  return rows
      .map((row) => DataRow(
            key: row.key,
            selected: row.selected,
            onSelectChanged: row.onSelectChanged,
            onLongPress: row.onLongPress,
            color: row.color,
            cells: row.cells.map(_wrapSingleCell).toList(growable: false),
          ))
      .toList(growable: false);
}

DataCell _wrapSingleCell(DataCell cell) {
  final child = cell.child;
  if (child is Text) {
    // If the Text was created with Text.rich() (data is null but
    // textSpan is not), fall back to a RichText so we don't lose the
    // spans. Otherwise use WrappedText for guaranteed wrapping.
    if (child.data == null && child.textSpan != null) {
      return DataCell(
        RichText(
          text: child.textSpan!,
          textAlign: child.textAlign ?? TextAlign.start,
          textDirection: child.textDirection,
          locale: child.locale,
          softWrap: true,
          overflow: TextOverflow.visible,
          maxLines: child.maxLines,
          strutStyle: child.strutStyle,
        ),
        placeholder: cell.placeholder,
        showEditIcon: cell.showEditIcon,
        onTap: cell.onTap,
        onLongPress: cell.onLongPress,
        onDoubleTap: cell.onDoubleTap,
        onTapDown: cell.onTapDown,
        onTapCancel: cell.onTapCancel,
      );
    }
    return DataCell(
      WrappedText(
        child.data ?? '',
        style: child.style,
        textAlign: child.textAlign,
        textDirection: child.textDirection,
        locale: child.locale,
        maxLines: child.maxLines,
        strutStyle: child.strutStyle,
        overflow: child.overflow ?? TextOverflow.visible,
      ),
      placeholder: cell.placeholder,
      showEditIcon: cell.showEditIcon,
      onTap: cell.onTap,
      onLongPress: cell.onLongPress,
      onDoubleTap: cell.onDoubleTap,
      onTapDown: cell.onTapDown,
      onTapCancel: cell.onTapCancel,
    );
  }
  return cell;
}

/// Convenience wrapper that combines [ResponsiveDataTableWrapper] +
/// [buildNduDataTable] + [FullScreenTableWrapper] so every table built this
/// way gets BOTH (a) auto-wrapped cells AND (b) a full-screen expand button.
///
/// Pass the same [columns] / [rows] you would pass to [buildNduDataTable].
/// The wrapper renders the table inline with horizontal scroll indicators
/// and a small "Expand" button in the top-right corner. Tapping Expand
/// opens the same table in a full-screen dialog.
Widget buildNduTableWithExpand({
  required BuildContext context,
  required List<DataColumn> columns,
  required List<DataRow> rows,
  String? title,
  double columnSpacing = 18,
  double horizontalMargin = 14,
  double headingRowHeight = 52,
  double dataRowMinHeight = 60,
  double dataRowMaxHeight = 220,
  TableBorder? border,
  bool zebra = true,
  bool showCheckboxColumn = false,
  double? minWidth,
  double? maxHeight,
  bool showExpandButton = true,
  VoidCallback? onFullscreenClose,
}) {
  final inlineTable = ResponsiveDataTableWrapper(
    minWidth: minWidth,
    maxHeight: maxHeight,
    child: buildNduDataTable(
      context: context,
      columns: columns,
      rows: rows,
      columnSpacing: columnSpacing,
      horizontalMargin: horizontalMargin,
      headingRowHeight: headingRowHeight,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      border: border,
      zebra: zebra,
      showCheckboxColumn: showCheckboxColumn,
    ),
  );

  if (!showExpandButton) {
    return inlineTable;
  }

  return FullScreenTableWrapper(
    title: title,
    onFullscreenClose: onFullscreenClose,
    child: inlineTable,
    tableBuilder: (fsContext) => buildNduDataTable(
      context: fsContext,
      columns: columns,
      rows: rows,
      columnSpacing: columnSpacing + 6,
      horizontalMargin: horizontalMargin + 6,
      headingRowHeight: headingRowHeight + 8,
      dataRowMinHeight: dataRowMinHeight + 8,
      dataRowMaxHeight: dataRowMaxHeight + 80,
      border: border,
      zebra: zebra,
      showCheckboxColumn: showCheckboxColumn,
    ),
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
