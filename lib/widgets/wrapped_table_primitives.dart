// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// wrapped_table_primitives.dart
//
// Reusable primitives for wrapping table-cell text and expanding tables to a
// full-screen view. Existing call sites can keep using these widgets unchanged.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// A [Text] that wraps and does not ellipsize unless [overflow] is overridden.
class WrappedText extends StatelessWidget {
  const WrappedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.maxLines,
    this.maxWidth,
    this.strutStyle,
    this.overflow = TextOverflow.visible,
  }) : softWrap = true;

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final double? maxWidth;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      strutStyle: strutStyle,
    );
    if (maxWidth == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: text,
    );
  }
}

/// A flexible-width cell for custom Row-based tables.
class WrappedCell extends StatelessWidget {
  const WrappedCell({
    super.key,
    required this.child,
    this.flex = 1,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final int flex;
  final EdgeInsets padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

/// Shows [child] inline and provides an affordance to open [tableBuilder]
/// full-screen. Separate table builders allow each view to own its scroll
/// controllers instead of attaching one controller to two scroll positions.
class FullScreenTableWrapper extends StatelessWidget {
  const FullScreenTableWrapper({
    super.key,
    required this.child,
    required this.tableBuilder,
    this.title,
    this.showExpandButton = true,
    this.onFullscreenClose,
    this.expandButtonPadding = const EdgeInsets.only(top: 8, right: 8),
  });

  final Widget child;
  final WidgetBuilder tableBuilder;
  final String? title;
  final bool showExpandButton;
  final VoidCallback? onFullscreenClose;
  final EdgeInsets expandButtonPadding;

  @override
  Widget build(BuildContext context) {
    if (!showExpandButton) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: expandButtonPadding.top,
          right: expandButtonPadding.right,
          child: _ExpandButton(onTap: () => _openFullScreen(context)),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenTablePage(
          title: title,
          tableBuilder: tableBuilder,
          onClose: onFullscreenClose,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, page) =>
            FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: page,
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: 'Expand table to full screen',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1F2937) : Colors.white)
                  .withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fullscreen,
                  size: 16,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                ),
                const SizedBox(width: 4),
                Text(
                  'Expand',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen expansion route. This remains a separate widget so its builder
/// can own a distinct scroll controller from the inline table.
class _FullScreenTablePage extends StatelessWidget {
  const _FullScreenTablePage({
    required this.title,
    required this.tableBuilder,
    this.onClose,
  });

  final String? title;
  final WidgetBuilder tableBuilder;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          title ?? 'Table — Full Screen',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => _close(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () => _close(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.topLeft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minWidth =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minWidth),
                      child: tableBuilder(context),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _close(BuildContext context) {
    onClose?.call();
    Navigator.of(context).maybePop();
  }
}

/// Builds a responsive table with automatically wrapped text cells and an
/// optional full-screen view.
Widget buildWrappedDataTable({
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
  bool wrapCells = true,
  bool showExpandButton = true,
  VoidCallback? onFullscreenClose,
}) {
  final wrappedRows = wrapCells ? _wrapRows(rows) : rows;

  final inlineTable = ResponsiveDataTableWrapper(
    minWidth: 0,
    child: buildNduDataTable(
      context: context,
      columns: columns,
      rows: wrappedRows,
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

  if (!showExpandButton) return inlineTable;
  return FullScreenTableWrapper(
    title: title,
    onFullscreenClose: onFullscreenClose,
    child: inlineTable,
    tableBuilder: (fsContext) => buildNduDataTable(
      context: fsContext,
      columns: columns,
      rows: wrappedRows,
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

List<DataRow> _wrapRows(List<DataRow> rows) => rows
    .map((row) => DataRow(
          key: row.key,
          selected: row.selected,
          onSelectChanged: row.onSelectChanged,
          onLongPress: row.onLongPress,
          color: row.color,
          cells: row.cells.map(_wrapCell).toList(growable: false),
        ))
    .toList(growable: false);

DataCell _wrapCell(DataCell cell) {
  final child = cell.child;
  if (child is! Text) return cell;

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
