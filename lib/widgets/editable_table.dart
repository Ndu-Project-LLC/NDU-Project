// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// editable_table.dart
//
// The app's *editable* data tables — the ones whose cells are live inputs
// rather than plain text, so they cannot be built with Flutter's DataTable —
// were five near-identical private copies of the same widget. This is the one
// shared implementation.
//
// Two looks are supported, because the copies had drifted into two shapes:
//
//   * [EditableTableVariant.stacked] — every row is its own rounded card
//     (project plan, backend design, long-lead ordering).
//   * [EditableTableVariant.sheet] — one bordered sheet with a header row and
//     dividers between the rows (contracts, stakeholder registers).
//
// On a phone neither shape is usable: a 6-column editable table has to be
// scrolled sideways, so the user only ever sees the first column and a sliver
// of the second. Both variants therefore render as cards at phone width, using
// the same card language as [NduDataTableCards] so the app stays consistent:
// one card per row, each column's label above its value.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

import 'responsive.dart';

/// One column of an [EditableTable]: the heading shown in the table header (and
/// as the label on each card in the mobile presentation) plus the fixed width
/// the column occupies in the table presentation.
class EditableTableColumn {
  const EditableTableColumn(this.label, this.width);

  final String label;
  final double width;
}

/// One row of an [EditableTable], described as one cell per column.
///
/// A row carries its own [columns] because the table renders rows lazily and
/// needs the width of each cell; they are the same list the table was built
/// with.
class EditableTableRow extends StatelessWidget {
  const EditableTableRow({
    super.key,
    required this.columns,
    required this.cells,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<EditableTableColumn> columns;
  final List<Widget> cells;
  final CrossAxisAlignment crossAxisAlignment;

  /// How many cells this row actually has (rows may be short of the columns).
  int get cellCount => cells.length < columns.length ? cells.length : columns.length;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: List.generate(
        cellCount,
        (index) => SizedBox(width: columns[index].width, child: cells[index]),
      ),
    );
  }
}

/// The two table looks carried over from the duplicated widgets.
enum EditableTableVariant {
  /// Each row is its own rounded, bordered card (no outer frame).
  stacked,

  /// One bordered sheet: header row, then dividers between rows.
  sheet,
}

/// An editable table of [columns] x [rows].
///
/// Wide layouts get the table; phone-width layouts get one card per row.
class EditableTable extends StatelessWidget {
  const EditableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.variant = EditableTableVariant.stacked,
  });

  final List<EditableTableColumn> columns;
  final List<Widget> rows;
  final EditableTableVariant variant;

  double get _contentWidth =>
      columns.fold<double>(0, (total, column) => total + column.width);

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) return _buildCards(context);
    return variant == EditableTableVariant.sheet
        ? _buildSheet(context)
        : _buildStacked(context);
  }

  // ── phone presentation ───────────────────────────────────────────────────
  //
  // Mirrors NduDataTableCards: one card per row, each column as a label /
  // value pair, so nothing has to be scrolled sideways and every field is
  // reachable. Rows that are not EditableTableRows (a custom row widget) still
  // get a card, they just cannot show per-column labels.
  Widget _buildCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _EditableTableCard(columns: columns, row: rows[i]),
          if (i < rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ── wide presentations ───────────────────────────────────────────────────

  Widget _buildStacked(BuildContext context) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: columns
            .map((column) => SizedBox(
                  width: column.width,
                  child: Text(
                    column.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF6B7280)),
                  ),
                ))
            .toList(),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: _contentWidth),
        child: Column(
          children: [
            header,
            const SizedBox(height: 8),
            for (int i = 0; i < rows.length; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: rows[i],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    const horizontalPadding = 16.0;
    final minTableWidth = _contentWidth + (horizontalPadding * 2);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    width: tableWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18)),
                    ),
                    child: Row(
                      children: columns
                          .map((column) => SizedBox(
                                width: column.width,
                                child: Center(
                                  child: Text(
                                    column.label.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  for (int i = 0; i < rows.length; i++)
                    Container(
                      width: tableWidth,
                      padding: const EdgeInsets.symmetric(
                          horizontal: horizontalPadding, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(
                              color: const Color(0xFFE5E7EB),
                              width: i == 0 ? 1 : 0.5),
                        ),
                      ),
                      child: rows[i],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditableTableCard extends StatelessWidget {
  const _EditableTableCard({required this.columns, required this.row});

  final List<EditableTableColumn> columns;
  final Widget row;

  @override
  Widget build(BuildContext context) {
    final source = row is EditableTableRow ? row as EditableTableRow : null;
    final cells = source?.cells ?? const <Widget>[];
    final count =
        cells.length < columns.length ? cells.length : columns.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      // A row that is not an EditableTableRow keeps its own layout.
      child: count == 0
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const Divider(height: 16, thickness: 0.6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // An empty heading marks an unlabelled column (row
                      // actions); it gets the full card width instead of a
                      // label gutter.
                      if (columns[i].label.isNotEmpty) ...[
                        SizedBox(
                          width: 104,
                          child: Text(
                            columns[i].label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: cells[i]),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
