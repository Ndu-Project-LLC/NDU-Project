// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// wrapped_table_primitives.dart
//
// Reusable primitives that guarantee:
//   1. Table cell text always wraps (never overflows the screen).
//   2. Every table can be expanded to a full-screen view.
//
// Public API:
//   - WrappedText           : A Text that always wraps soft words and never
//                             overflows. Drop-in replacement for Text inside
//                             any table cell.
//   - WrappedCell           : A table cell that constrains its child to a
//                             flexible width and lets long text wrap.
//   - FullScreenTableWrapper: Wraps any table widget and renders an "Expand"
//                             FAB in the top-right corner. Tapping it opens
//                             a full-screen dialog re-building the same table
//                             with relaxed constraints so it can use all the
//                             available width.
//   - buildWrappedDataTable  : Convenience builder that returns a
//                             FullScreenTableWrapper around an NDU-styled
//                             DataTable whose cells use WrappedText.
//
// These primitives are pure additions — they do not modify any existing
// widget. Existing call sites continue to work unchanged; new call sites
// should prefer these primitives.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// A [Text] that ALWAYS wraps and never overflows.
///
/// Use this anywhere a normal [Text] would otherwise trigger a
/// "RenderFlex overflowed by N pixels" warning — most commonly inside
/// [DataRow] cells, [Row]-based custom tables, and grid layouts.
///
/// Behaviour:
///   * `softWrap: true` (always).
///   * `overflow: TextOverflow.visible` (never clip / never ellipsize).
///   * Optional `maxLines` (defaults to unset = unlimited).
///   * Optional `maxWidth` to constrain the text to a fixed column width.
class WrappedText extends StatelessWidget {
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
  })  : softWrap = true,
        overflow = TextOverflow.visible;

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
    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: text,
      );
    }
    return text;
  }
}

/// A table cell that wraps its child to a flexible width.
///
/// Use inside [DataRow] cells or any [Row]-based custom table layout.
/// The child — typically a [WrappedText] — is given an [Expanded] or
/// [Flexible] parent so it claims a share of the row width and wraps
/// internally instead of pushing siblings off-screen.
class WrappedCell extends StatelessWidget {
  final Widget child;
  final int flex;
  final EdgeInsets padding;
  final Alignment alignment;

  const WrappedCell({
    super.key,
    required this.child,
    this.flex = 1,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: child,
        ),
      ),
    );
  }
}

/// Wraps any table widget and lets the user expand it to full-screen.
///
/// The wrapper renders the [child] table inline. A small "Expand" button
/// is overlaid in the top-right corner of the table. When tapped, the
/// [tableBuilder] is invoked inside a full-screen [Dialog] so the same
/// table can be re-rendered with relaxed constraints (full available
/// width / height). This avoids the common Flutter "RenderFlex overflow"
/// issue when a wide table is squeezed into a narrow parent.
///
/// Both [child] and [tableBuilder] are required. [child] is what shows
/// inline; [tableBuilder] is what shows full-screen. They can be the
/// same widget tree, but [tableBuilder] typically uses wider column
/// widths and a larger heading row height.
///
/// The optional [title] is shown in the full-screen app bar.
/// The optional [onFullscreenClose] is invoked when the user closes the
/// full-screen dialog (e.g. to persist any edits).
class FullScreenTableWrapper extends StatefulWidget {
  final Widget child;
  final WidgetBuilder tableBuilder;
  final String? title;
  final bool showExpandButton;
  final VoidCallback? onFullscreenClose;
  final EdgeInsets expandButtonPadding;

  const FullScreenTableWrapper({
    super.key,
    required this.child,
    required this.tableBuilder,
    this.title,
    this.showExpandButton = true,
    this.onFullscreenClose,
    this.expandButtonPadding =
        const EdgeInsets.only(top: 8, right: 8),
  });

  @override
  State<FullScreenTableWrapper> createState() =>
      _FullScreenTableWrapperState();
}

class _FullScreenTableWrapperState extends State<FullScreenTableWrapper> {
  @override
  Widget build(BuildContext context) {
    if (!widget.showExpandButton) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: widget.expandButtonPadding.top,
          right: widget.expandButtonPadding.right,
          child: _ExpandButton(
            onTap: _openFullScreen,
          ),
        ),
      ],
    );
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenTablePage(
            title: widget.title,
            tableBuilder: widget.tableBuilder,
            onClose: widget.onFullscreenClose,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

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
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
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

class _FullScreenTablePage extends StatelessWidget {
  final String? title;
  final WidgetBuilder tableBuilder;
  final VoidCallback? onClose;

  const _FullScreenTablePage({
    required this.title,
    required this.tableBuilder,
    this.onClose,
  });

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
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () {
            if (onClose != null) onClose!();
            Navigator.of(context).maybePop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () {
              if (onClose != null) onClose!();
              Navigator.of(context).maybePop();
            },
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
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tableBuilder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience builder: wraps a [DataTable] (built via [buildNduDataTable])
/// in a [FullScreenTableWrapper] and ensures the inner table can scroll
/// both horizontally and vertically when expanded.
///
/// Pass the same [columns] / [rows] you would normally pass to
/// [buildNduDataTable]. The wrapper renders the table inline and offers
/// an "Expand" button. When expanded, the same [columns] / [rows] are
/// re-rendered in a full-screen dialog with horizontal + vertical
/// scroll.
///
/// Set [wrapCells] = true (default) to automatically wrap any
/// [DataCell] whose child is a plain [Text] in a [WrappedText]. This is
/// a no-op for cells that already use [WrappedText] or non-text children.
Widget buildWrappedDataTable({
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
  bool wrapCells = true,
  bool showExpandButton = true,
  VoidCallback? onFullscreenClose,
}) {
  List<DataRow> wrappedRows = rows;
  if (wrapCells) {
    wrappedRows = rows
        .map((row) => DataRow(
              key: row.key,
              selected: row.selected,
              onSelectChanged: row.onSelectChanged,
              onLongPress: row.onLongPress,
              color: row.color,
              cells: row.cells.map(_wrapCell).toList(growable: false),
            ))
        .toList(growable: false);
  }

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

  if (!showExpandButton) {
    return inlineTable;
  }

  return FullScreenTableWrapper(
    title: title,
    onFullscreenClose: onFullscreenClose,
    tableBuilder: (fsContext) => buildNduDataTable(
      context: fsContext,
      columns: columns,
      rows: wrappedRows,
      columnSpacing: columnSpacing + 6,
      horizontalMargin: horizontalMargin + 6,
      headingRowHeight: headingRowHeight + 8,
      dataRowMinHeight: dataRowMinHeight + 8,
      dataRowMaxHeight: dataRowMaxHeight + 80,
      border: border,
      zebra: zebra,
      showCheckboxColumn: showCheckboxColumn,
    ),
    child: inlineTable,
  );
}

DataCell _wrapCell(DataCell cell) {
  if (cell.child is Text) {
    final t = cell.child as Text;
    return DataCell(
      WrappedText(
        t.data ?? '',
        style: t.style,
        textAlign: t.textAlign,
        textDirection: t.textDirection,
        locale: t.locale,
        maxLines: t.maxLines,
        strutStyle: t.strutStyle,
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
  // Already wrapped or non-text — leave alone.
  return cell;
}
