import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

/// Responsive wrapper for data tables with horizontal scroll support
/// Width a table falls back to when its parent gives it no width at all
/// (an unbounded parent and no `minWidth`), so its columns still have
/// something to divide up.
const double _kFallbackTableWidth = 720;

/// Mobile presentation for a [DataTable]: each row becomes a labeled card,
/// while preserving selection, row callbacks, cell callbacks and native cell
/// controls. Use it directly where a caller owns its own table construction.
class NduDataTableCards extends StatelessWidget {
  const NduDataTableCards({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
    this.dataTextStyle,
    this.border,
    this.decoration,
    this.headingRowColor,
    this.dataRowColor,
    this.headingTextStyle,
    this.numericTextAlign = TextAlign.start,
    this.headingRowHeight,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.dividerThickness,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;
  final TextStyle? dataTextStyle;
  final TableBorder? border;
  final Decoration? decoration;
  final WidgetStateProperty<Color?>? headingRowColor;
  final WidgetStateProperty<Color?>? dataRowColor;
  final TextStyle? headingTextStyle;
  final TextAlign numericTextAlign;
  final double? headingRowHeight;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? dividerThickness;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueSetter<bool?>? onSelectAll;

  Widget _buildSelectAllControl() {
    final selectableRows = rows
        .where((row) => row.onSelectChanged != null)
        .toList(growable: false);
    final selectedCount = selectableRows.where((row) => row.selected).length;
    final allSelected = selectedCount == selectableRows.length;
    final someSelected = selectedCount > 0 && !allSelected;

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select all'),
          Checkbox(
            tristate: true,
            value: someSelected ? null : allSelected,
            onChanged: (value) {
              final selected = someSelected || (value ?? false);
              if (onSelectAll != null) {
                onSelectAll!(selected);
              } else {
                for (final row in selectableRows) {
                  if (row.selected != selected) {
                    row.onSelectChanged!(selected);
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final style = dataTextStyle ?? theme.textTheme.bodyMedium;
    final defaultBorder = BorderSide(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (MediaQuery.sizeOf(context).width - 32)
                .clamp(0.0, double.infinity);
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCheckboxColumn &&
                  rows.any((row) => row.onSelectChanged != null))
                _buildSelectAllControl(),
              for (var index = 0; index < rows.length; index++) ...[
                _NduDataTableCard(
                  key: rows[index].key ??
                      ValueKey<String>('ndu-mobile-table-card-$index'),
                  columns: columns,
                  row: rows[index],
                  showCheckboxColumn: showCheckboxColumn,
                  dataTextStyle: style,
                  headingRowHeight: headingRowHeight,
                  dataRowMinHeight: dataRowMinHeight,
                  dataRowMaxHeight: dataRowMaxHeight,
                  dividerThickness: dividerThickness,
                  headingRowColor: headingRowColor,
                  dataRowColor: dataRowColor,
                  headingTextStyle: headingTextStyle,
                  numericTextAlign: numericTextAlign,
                  sortColumnIndex: sortColumnIndex,
                  sortAscending: sortAscending,
                  border: border?.top ?? defaultBorder,
                ),
                if (index < rows.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NduDataTableCard extends StatelessWidget {
  const _NduDataTableCard({
    super.key,
    required this.columns,
    required this.row,
    required this.showCheckboxColumn,
    required this.dataTextStyle,
    required this.headingRowHeight,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.dividerThickness,
    required this.headingRowColor,
    required this.dataRowColor,
    required this.headingTextStyle,
    required this.numericTextAlign,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.border,
  });

  final List<DataColumn> columns;
  final DataRow row;
  final bool showCheckboxColumn;
  final TextStyle? dataTextStyle;
  final double? headingRowHeight;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? dividerThickness;
  final WidgetStateProperty<Color?>? headingRowColor;
  final WidgetStateProperty<Color?>? dataRowColor;
  final TextStyle? headingTextStyle;
  final TextAlign numericTextAlign;
  final int? sortColumnIndex;
  final bool sortAscending;
  final BorderSide border;

  Widget _cell(DataCell cell) {
    Widget child = DefaultTextStyle.merge(
      style: dataTextStyle,
      child: cell.child,
    );
    if (cell.placeholder) child = Opacity(opacity: 0.6, child: child);
    if (cell.showEditIcon) {
      child = Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 6),
          const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
        ],
      );
    }
    if (cell.onTap != null || cell.onLongPress != null) {
      child = InkWell(
        onTap: cell.onTap,
        onLongPress: cell.onLongPress,
        onDoubleTap: cell.onDoubleTap,
        onTapDown: cell.onTapDown,
        onTapCancel: cell.onTapCancel,
        child: child,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count =
        columns.length < row.cells.length ? columns.length : row.cells.length;
    final selectionStates = <WidgetState>{
      if (row.selected) WidgetState.selected,
    };
    final rowColor = row.color?.resolve(selectionStates) ??
        dataRowColor?.resolve(selectionStates) ??
        theme.cardColor;

    return Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: row.onSelectChanged == null
            ? null
            : () => row.onSelectChanged!(!row.selected),
        onLongPress: row.onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.fromBorderSide(border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCheckboxColumn && row.onSelectChanged != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Checkbox(
                    value: row.selected,
                    onChanged: row.onSelectChanged,
                  ),
                ),
              for (var cellIndex = 0; cellIndex < count; cellIndex++) ...[
                if (cellIndex > 0)
                  Divider(
                    height: 16,
                    thickness: dividerThickness ?? 0.6,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              headingRowColor?.resolve(const <WidgetState>{}),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: columns[cellIndex].onSort == null
                                      ? null
                                      : () => columns[cellIndex].onSort!(
                                            cellIndex,
                                            sortColumnIndex != cellIndex ||
                                                !sortAscending,
                                          ),
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ).merge(headingTextStyle),
                                    child: columns[cellIndex].label,
                                  ),
                                ),
                              ),
                              if (sortColumnIndex == cellIndex) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: columns[cellIndex].numeric
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: DefaultTextStyle.merge(
                          textAlign: columns[cellIndex].numeric
                              ? numericTextAlign
                              : TextAlign.start,
                          child: _cell(row.cells[cellIndex]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop-in responsive alternative to Flutter's [DataTable].
///
/// Desktop/tablet retain Flutter's native table. On phones every row is a
/// labeled card, so screens do not have to maintain separate hand-built mobile
/// and desktop renderers. The constructor mirrors the table settings used
/// throughout this app so callers can migrate with a one-word change.
class NduResponsiveDataTable extends StatelessWidget {
  const NduResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
    this.decoration,
    this.dataRowColor,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.headingRowHeight,
    this.headingTextStyle,
    this.horizontalMargin,
    this.columnSpacing,
    this.showCheckboxColumn = true,
    this.showBottomBorder = false,
    this.dividerThickness,
    this.checkboxHorizontalMargin,
    this.border,
    this.clipBehavior = Clip.none,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueSetter<bool?>? onSelectAll;
  final Decoration? decoration;
  final WidgetStateProperty<Color?>? dataRowColor;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final TextStyle? dataTextStyle;
  final WidgetStateProperty<Color?>? headingRowColor;
  final double? headingRowHeight;
  final TextStyle? headingTextStyle;
  final double? horizontalMargin;
  final double? columnSpacing;
  final bool showCheckboxColumn;
  final bool showBottomBorder;
  final double? dividerThickness;
  final double? checkboxHorizontalMargin;
  final TableBorder? border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isMobile(context)) {
      return DataTable(
        columns: columns,
        rows: rows,
        sortColumnIndex: sortColumnIndex,
        sortAscending: sortAscending,
        onSelectAll: onSelectAll,
        decoration: decoration,
        dataRowColor: dataRowColor,
        dataRowMinHeight: dataRowMinHeight,
        dataRowMaxHeight: dataRowMaxHeight,
        dataTextStyle: dataTextStyle,
        headingRowColor: headingRowColor,
        headingRowHeight: headingRowHeight,
        headingTextStyle: headingTextStyle,
        horizontalMargin: horizontalMargin,
        columnSpacing: columnSpacing,
        showCheckboxColumn: showCheckboxColumn,
        showBottomBorder: showBottomBorder,
        dividerThickness: dividerThickness,
        checkboxHorizontalMargin: checkboxHorizontalMargin,
        border: border,
        clipBehavior: clipBehavior,
      );
    }

    return NduDataTableCards(
      columns: columns,
      rows: rows,
      showCheckboxColumn: showCheckboxColumn,
      dataTextStyle: dataTextStyle,
      headingRowColor: headingRowColor,
      dataRowColor: dataRowColor,
      headingTextStyle: headingTextStyle,
      headingRowHeight: headingRowHeight,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      dividerThickness: dividerThickness,
      border: border,
      decoration: decoration,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll,
    );
  }
}

class ResponsiveDataTableWrapper extends StatefulWidget {
  final Widget child;
  final double? minWidth;
  final double? maxHeight;
  final bool mobileCards;

  const ResponsiveDataTableWrapper({
    super.key,
    required this.child,
    this.minWidth,
    this.maxHeight,
    this.mobileCards = true,
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
    if (AppBreakpoints.isMobile(context) && widget.child is NduDataTableCards) {
      if (widget.maxHeight == null) return widget.child;
      return SizedBox(
        height: widget.maxHeight,
        child: SingleChildScrollView(child: widget.child),
      );
    }

    if (widget.mobileCards &&
        AppBreakpoints.isMobile(context) &&
        widget.child is DataTable) {
      final table = widget.child as DataTable;
      final cards = NduDataTableCards(
        columns: table.columns,
        rows: table.rows,
        showCheckboxColumn: table.showCheckboxColumn,
        dataTextStyle: table.dataTextStyle,
        border: table.border,
        headingRowColor: table.headingRowColor,
        sortColumnIndex: table.sortColumnIndex,
        sortAscending: table.sortAscending,
        onSelectAll: table.onSelectAll,
        dataRowColor: table.dataRowColor,
        headingTextStyle: table.headingTextStyle,
        headingRowHeight: table.headingRowHeight,
        dataRowMinHeight: table.dataRowMinHeight,
        dataRowMaxHeight: table.dataRowMaxHeight,
        dividerThickness: table.dividerThickness,
        numericTextAlign: TextAlign.end,
        decoration: table.decoration,
      );
      if (widget.maxHeight == null) return cards;
      return SizedBox(
        height: widget.maxHeight,
        child: SingleChildScrollView(child: cards),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against unbounded constraints — if the parent gives us
        // infinite width/height, we cannot lay out a Stack with Positioned
        // children. Fall back to a plain scroll view in that case.
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final hasBoundedHeight =
            widget.maxHeight != null || constraints.maxHeight.isFinite;

        // A horizontally scrolling viewport hands its child an *unbounded*
        // width. Some of these tables divide their columns with `Expanded`, and
        // a flexed child cannot resolve against infinity: layout throws
        // `RenderFlex children have non-zero flex but incoming width
        // constraints are unbounded`, which poisons the whole page's render
        // subtree — the sidebar and header still draw, the body comes up
        // empty, and nothing on screen explains why.
        //
        // `IntrinsicWidth` supplies the missing definite width without
        // capping it: the child is laid out at its own intrinsic width (so a
        // genuinely wide table still overflows and scrolls, never squashes or
        // clips), lifted to the viewport width — or [minWidth], when the table
        // must not shrink below it — by the ConstrainedBox around it.
        final double minTableWidth;
        if (constraints.maxWidth.isFinite) {
          minTableWidth = math.max(widget.minWidth ?? 0, constraints.maxWidth);
        } else if ((widget.minWidth ?? 0) > 0) {
          minTableWidth = widget.minWidth!;
        } else {
          // Unbounded parent and no minimum: a table with nothing to divide
          // between its columns would collapse, so give it a readable floor.
          minTableWidth = _kFallbackTableWidth;
        }

        final horizontalChild = SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minTableWidth),
            child: IntrinsicWidth(child: widget.child),
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

Widget buildNduDataTable({
  required BuildContext context,
  required List<DataColumn> columns,
  required List<DataRow> rows,
  double columnSpacing = 18,
  double horizontalMargin = 14,
  double headingRowHeight = 44,
  double dataRowMinHeight = 48,
  double dataRowMaxHeight = 120,
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
  final normalizedRows =
      zebra ? nduZebraRows(context, processedRows) : processedRows;

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

  if (AppBreakpoints.isMobile(context)) {
    return NduDataTableCards(
      columns: columns,
      rows: normalizedRows,
      showCheckboxColumn: showCheckboxColumn,
      dataTextStyle: resolvedDataTextStyle,
      headingRowColor: WidgetStatePropertyAll(resolvedHeadingColor),
      headingTextStyle: resolvedHeadingTextStyle,
      dividerThickness: 0.8,
    );
  }

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
  double headingRowHeight = 44,
  double dataRowMinHeight = 48,
  double dataRowMaxHeight = 120,
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
      headingRowHeight: headingRowHeight + 4,
      dataRowMinHeight: dataRowMinHeight + 4,
      dataRowMaxHeight: dataRowMaxHeight + 40,
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
