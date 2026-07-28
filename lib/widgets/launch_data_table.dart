import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/download_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

const double _defaultColumnWidth = 160;
const double _tableHorizontalPadding = 20;
const double _columnGap = 12;
const double _actionColumnWidth = 96;

class _TableLayoutInherited extends InheritedWidget {
  final double tableWidth;
  final List<LaunchColumn> columns;
  final bool hasRowActions;

  const _TableLayoutInherited({
    required this.tableWidth,
    required this.columns,
    required this.hasRowActions,
    required super.child,
  });

  static _TableLayoutInherited? of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_TableLayoutInherited>();
    return inherited;
  }

  @override
  bool updateShouldNotify(_TableLayoutInherited oldWidget) =>
      tableWidth != oldWidget.tableWidth ||
      columns != oldWidget.columns ||
      hasRowActions != oldWidget.hasRowActions;
}

class _EditingMode extends InheritedWidget {
  final bool isEditing;

  const _EditingMode({
    required this.isEditing,
    required super.child,
  });

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_EditingMode>()
            ?.isEditing ??
        false;
  }

  @override
  bool updateShouldNotify(_EditingMode oldWidget) =>
      isEditing != oldWidget.isEditing;
}

enum LaunchFieldType { text, date, dropdown }

class LaunchColumn {
  final String label;
  final double? width;
  final bool flexible;
  final LaunchFieldType fieldType;
  final List<String>? dropdownItems;
  final String? hint;

  const LaunchColumn({
    required this.label,
    this.width,
    this.flexible = false,
    this.fieldType = LaunchFieldType.text,
    this.dropdownItems,
    this.hint,
  }) : assert(
            width != null || flexible, 'Either width or flexible must be set');
}

class LaunchDataTable extends StatefulWidget {
  LaunchDataTable({
    super.key,
    required this.title,
    required List<dynamic> columns,
    required this.rowCount,
    required this.cellBuilder,
    this.subtitle,
    this.onAdd,
    this.onAddValues,
    this.addLabel = 'Add item',
    this.importLabel,
    this.onImport,
    this.emptyMessage = 'No entries yet. Add details to get started.',
    this.csvColumns,
    this.onCsvImport,
    this.onSearch,
    this.onFilter,
  }) : _columns = columns
            .map((c) => c is LaunchColumn
                ? c
                : LaunchColumn(label: c.toString(), flexible: true))
            .toList();

  final String title;
  final String? subtitle;
  final List<LaunchColumn> _columns;
  final int rowCount;
  final Widget Function(BuildContext context, int rowIdx) cellBuilder;
  final VoidCallback? onAdd;
  final ValueChanged<Map<String, String>>? onAddValues;
  final String addLabel;
  final String? importLabel;
  final VoidCallback? onImport;
  final String emptyMessage;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onFilter;

  /// CSV import column specifications — enables the "Import CSV" button.
  final List<CsvColumnSpec>? csvColumns;

  /// Callback when CSV rows are imported. Supports synchronous and async saves.
  final FutureOr<void> Function(List<Map<String, String>>)? onCsvImport;



  @override
  State<LaunchDataTable> createState() => _LaunchDataTableState();
}

class _LaunchDataTableState extends State<LaunchDataTable> {
  final TextEditingController _searchController = TextEditingController();

  bool get _hasActions =>
      widget.onAdd != null ||
      widget.onAddValues != null ||
      widget.onImport != null ||
      widget.csvColumns != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context),
          if (widget.onSearch != null || _hasActions) _buildActionBar(context),
          if (widget.rowCount == 0) _buildEmpty() else _buildRows(context),
        ],
      ),
    );
  }  Widget _buildCardHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          if (widget.onSearch != null)
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          widget.onSearch?.call(value);
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.mic, size: 20, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.onSearch != null) const SizedBox(width: 12),
          if (widget.onFilter != null) ...[
            OutlinedButton(
              onPressed: widget.onFilter,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (widget.onAdd != null || widget.onAddValues != null) ...[
            ElevatedButton(
              onPressed: () => _showAddDialog(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    widget.addLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.csvColumns != null && widget.onCsvImport != null) ...[
            OutlinedButton.icon(
              onPressed: () => _showCsvImportDialog(context),
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFFDE68A)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _downloadCsvTemplate(),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Template'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                foregroundColor: const Color(0xFF4B5563),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onImport != null && widget.importLabel != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: Text(widget.importLabel!),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                foregroundColor: const Color(0xFF4B5563),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCsvImportDialog(BuildContext context) async {
    if (widget.csvColumns == null || widget.onCsvImport == null) return;
    final result = await showCsvImportDialog(
      context,
      tableTitle: widget.title,
      columns: widget.csvColumns!,
    );
    if (result != null && result.isNotEmpty) {
      await widget.onCsvImport!(result);
    }
  }

  void _downloadCsvTemplate() {
    if (widget.csvColumns == null) return;
    final csv = CsvImportHelper.generateTemplate(widget.csvColumns!);
    final filename = CsvImportHelper.templateFilename(widget.title);
    downloadFile(
      utf8.encode(csv),
      filename,
      mimeType: 'text/csv',
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    if (widget.onAddValues != null) {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (ctx) => _AddItemDialog(
          title: widget.title,
          columns: widget._columns,
        ),
      );
      if (result != null) widget.onAddValues!(result);
    } else {
      widget.onAdd?.call();
    }
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF9CA3AF), size: 32),
            const SizedBox(height: 12),
            Text(
              widget.emptyMessage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRows(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = List.generate(widget.rowCount, (i) => widget.cellBuilder(context, i));
        final effectiveColumns = _resolveColumns(rows);
        final hasRowActions = rows.any(
          (row) =>
              row is LaunchDataRow &&
              (row.onDelete != null || row.onEdit != null || row.onKazAi != null),
        );
        final minTableWidth = _minTableWidth(effectiveColumns, hasRowActions);
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _TableLayoutInherited(
            tableWidth: tableWidth,
            columns: effectiveColumns,
            hasRowActions: hasRowActions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumnHeaders(
                    tableWidth, effectiveColumns, hasRowActions),
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<LaunchColumn> _resolveColumns(List<Widget> rows) {
    return List.generate(widget._columns.length, (index) {
      final column = widget._columns[index];
      if (!column.flexible) return column;

      final widths = rows
          .whereType<LaunchDataRow>()
          .map((row) => index < row.cells.length ? row.cells[index] : null)
          .map(_fixedWidthForCell)
          .whereType<double>()
          .toList();

      if (widths.isEmpty) return column;

      return LaunchColumn(
        label: column.label,
        width: widths.reduce((a, b) => a > b ? a : b),
      );
    });
  }

  double? _fixedWidthForCell(Widget? cell) {
    if (cell is LaunchEditableCell && cell.width != null && !cell.expand) {
      return cell.width;
    }
    if (cell is LaunchDateCell) return cell.width;
    if (cell is LaunchStatusDropdown) return cell.width;
    return null;
  }

  double _minTableWidth(List<LaunchColumn> columns, bool hasRowActions) {
    final columnWidths = columns.fold<double>(0, (sum, col) {
      if (col.flexible) return sum + _defaultColumnWidth;
      return sum + (col.width ?? _defaultColumnWidth);
    });
    final gapWidth = columns.isEmpty ? 0 : _columnGap * (columns.length - 1);
    final rowPadding = _tableHorizontalPadding * 2;
    final actionWidth = hasRowActions ? _actionColumnWidth : 0.0;
    return columnWidths + gapWidth + rowPadding + actionWidth;
  }

  Widget _buildColumnHeaders(
    double tableWidth,
    List<LaunchColumn> columns,
    bool hasRowActions,
  ) {
    return Container(
      width: tableWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: _tableHorizontalPadding,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          ..._buildColumnSlots(
            columns,
            (col, _) => Center(
              child: Text(
                col.label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ),
          if (hasRowActions)
            SizedBox(
              width: _actionColumnWidth,
              child: const Center(
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<Widget> _buildColumnSlots(
  List<LaunchColumn> columns,
  Widget Function(LaunchColumn column, int index) builder,
) {
  final slots = <Widget>[];
  for (var i = 0; i < columns.length; i++) {
    final column = columns[i];
    final child = builder(column, i);
    slots.add(
      column.flexible
          ? Expanded(child: child)
          : SizedBox(width: column.width, child: child),
    );
    if (i < columns.length - 1) {
      slots.add(const SizedBox(width: _columnGap));
    }
  }
  return slots;
}

class LaunchDataRow extends StatefulWidget {
  const LaunchDataRow({
    super.key,
    required this.cells,
    this.onDelete,
    this.onEdit,
    this.onKazAi,
    this.showDivider = false,
  });

  final List<Widget> cells;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onKazAi;
  final bool showDivider;

  @override
  State<LaunchDataRow> createState() => _LaunchDataRowState();
}

class _LaunchDataRowState extends State<LaunchDataRow> {
  bool _hovering = false;
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final tableLayout = _TableLayoutInherited.of(context);
    final columns = tableLayout?.columns;
    final hasActions = widget.onDelete != null || widget.onEdit != null || widget.onKazAi != null;
    return MouseRegion(
      onEnter: (_) => Future.microtask(() {
        if (mounted) setState(() => _hovering = true);
      }),
      onExit: (_) => Future.microtask(() {
        if (mounted) setState(() => _hovering = false);
      }),
      child: Column(
        children: [
          Container(
            width: tableLayout?.tableWidth,
            decoration: BoxDecoration(
              color: _isEditing
                  ? const Color(0xFFFFFDF5)
                  : (_hovering ? const Color(0xFFF8FAFC) : Colors.white),
              border: _isEditing
                  ? const Border(
                      left: BorderSide(color: Color(0xFFF59E0B), width: 3))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _tableHorizontalPadding,
              vertical: 10,
            ),
            child: _EditingMode(
              isEditing: _isEditing,
              child: Row(
                children: [
                  if (columns == null)
                    ...widget.cells
                  else
                    ..._buildColumnSlots(
                      columns,
                      (_, index) {
                        if (index >= widget.cells.length) {
                          return const SizedBox.shrink();
                        }
                        return _CellSlot(child: widget.cells[index]);
                      },
                    ),
                  if (hasActions)
                    SizedBox(
                      width: _actionColumnWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.onKazAi != null)
                            Tooltip(
                              message: 'KAZ AI',
                              child: IconButton(
                                icon: const Icon(Icons.auto_awesome,
                                    size: 16, color: Color(0xFFF59E0B)),
                                onPressed: widget.onKazAi,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                splashRadius: 14,
                              ),
                            ),
                          if (widget.onKazAi != null &&
                              (widget.onEdit != null || widget.onDelete != null))
                            const SizedBox(width: 2),
                          if (widget.onEdit != null)
                            Tooltip(
                              message: _isEditing ? 'Save' : 'Edit',
                              child: IconButton(
                                icon: Icon(
                                  _isEditing
                                      ? Icons.check_circle_rounded
                                      : Icons.edit_outlined,
                                  size: 16,
                                  color: _isEditing
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF9CA3AF),
                                ),
                                onPressed: () {
                                  setState(() => _isEditing = !_isEditing);
                                  // Call onEdit when exiting edit mode (Save)
                                  if (!_isEditing) {
                                    widget.onEdit?.call();
                                  }
                                },
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                splashRadius: 14,
                              ),
                            ),
                          if (widget.onEdit != null && widget.onDelete != null)
                            const SizedBox(width: 2),
                          if (widget.onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Color(0xFFEF4444)),
                              onPressed: widget.onDelete,
                              tooltip: 'Delete',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              splashRadius: 14,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Use a constrained height with padding so dropdowns and status pills
    // never clip vertically, but still keep rows compact.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// A styled editable cell that renders as a proper input field
/// with a subtle border, rounded corners, and background fill
/// — matching the checklist table style from the screenshot.
class LaunchEditableCell extends StatefulWidget {
  const LaunchEditableCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.width,
    this.bold = false,
    this.expand = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final double? width;
  final bool bold;
  final bool expand;

  @override
  State<LaunchEditableCell> createState() => _LaunchEditableCellState();
}

class _LaunchEditableCellState extends State<LaunchEditableCell> {
  late final TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant LaunchEditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _controller.text) return;

    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _EditingMode.of(context);

    if (!isEditing) {
      return Align(
        alignment: Alignment.center,
        child:        Text(
          widget.value.isEmpty ? '—' : widget.value,
          softWrap: true,
          style: TextStyle(
            fontSize: 13,
            color: widget.value.isEmpty
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF111827),
            fontWeight: widget.bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
    }

    final borderColor =
        _isFocused ? const Color(0xFFD97706) : const Color(0xFFE5E7EB);
    final bgColor = _isFocused ? Colors.white : const Color(0xFFF9FAFB);

    final child = Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: _isFocused ? 1.5 : 1),
        ),
        child: VoiceTextField(
          controller: _controller,
          onChanged: widget.onChanged,
          style: TextStyle(
            fontSize: 12.5,
            color: const Color(0xFF111827),
            fontWeight: widget.bold ? FontWeight.w600 : FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ),
    );
    final inTable = _TableLayoutInherited.of(context) != null;
    if (inTable) return child;
    if (widget.width != null) {
      return SizedBox(width: widget.width, child: child);
    }
    if (widget.expand) return Expanded(child: child);
    return child;
  }
}

class LaunchDateCell extends StatefulWidget {
  const LaunchDateCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Date',
    this.width = 120,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  State<LaunchDateCell> createState() => _LaunchDateCellState();
}

class _LaunchDateCellState extends State<LaunchDateCell> {
  late String _displayValue;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant LaunchDateCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _displayValue) {
      _displayValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _displayValue.trim();
    final isEmpty = text.isEmpty;
    final isEditing = _EditingMode.of(context);

    if (!isEditing) {
      return Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEmpty) ...[
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
            ],
            Text(
              isEmpty ? '—' : text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color:
                    isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: 40,
      child: MouseRegion(
        onEnter: (_) => Future.microtask(() {
          if (mounted) setState(() => _isHovering = true);
        }),
        onExit: (_) => Future.microtask(() {
          if (mounted) setState(() => _isHovering = false);
        }),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickDate(context),
          child: Container(
            decoration: BoxDecoration(
              color: _isHovering ? Colors.white : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovering
                    ? const Color(0xFFD97706)
                    : const Color(0xFFE5E7EB),
                width: _isHovering ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEmpty ? widget.hint : text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isEmpty
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseDate(_displayValue) ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );

    if (selected == null) return;

    final formatted = _formatDate(selected);
    setState(() => _displayValue = formatted);
    widget.onChanged(formatted);
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final parts = text.split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    if (parts[0].length == 4) return DateTime(first, second, third);
    if (parts[2].length == 4) return DateTime(third, second, first);
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class LaunchStatusDropdown extends StatelessWidget {
  const LaunchStatusDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 140,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final menuItems = _normalizedItems();
    final effective = _effectiveValue(menuItems);
    final statusColor = _statusColor(effective ?? '');
    final isEditing = _EditingMode.of(context);

    if (!isEditing) {
      final label = effective ?? 'Not set';
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      );
    }

    if (menuItems.isEmpty || effective == null) {
      return SizedBox(
        width: width,
        height: 40,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              'Not set',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effective,
              isDense: true,
              isExpanded: true,
              iconSize: 14,
              iconDisabledColor: statusColor.withValues(alpha: 0.5),
              iconEnabledColor: statusColor,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
              items: items
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  List<String> _normalizedItems() {
    final seen = <String>{};
    final normalized = <String>[];

    void addIfValid(String raw) {
      final item = raw.trim();
      if (item.isEmpty || !seen.add(item)) return;
      normalized.add(item);
    }

    for (final item in items) {
      addIfValid(item);
    }
    addIfValid(value);

    return normalized;
  }

  String? _effectiveValue(List<String> menuItems) {
    if (menuItems.isEmpty) return null;
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return menuItems.first;
    return menuItems.contains(trimmedValue) ? trimmedValue : menuItems.first;
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complet') ||
        s.contains('done') ||
        s.contains('closed') ||
        s.contains('ready')) {
      return const Color(0xFF10B981);
    }
    if (s.contains('progress') || s.contains('active') || s.contains('track')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('overdue') || s.contains('at risk') || s.contains('delay')) {
      return const Color(0xFFEF4444);
    }
    if (s.contains('pending') ||
        s.contains('review') ||
        s.contains('planned') ||
        s.contains('open')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF6B7280);
  }
}

Future<bool> launchConfirmDelete(BuildContext context,
    {String itemName = 'item'}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => LaunchModalShell(
      icon: Icons.delete_outline_rounded,
      accent: const Color(0xFFEF4444),
      title: 'Delete Entry',
      subtitle: 'This action cannot be undone.',
      body: Text(
        'Are you sure you want to delete this $itemName? '
        'Once removed, the entry cannot be recovered.',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF4B5563),
          height: 1.5,
        ),
      ),
      actions: [
        LaunchModalCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        LaunchModalDangerButton(
          label: 'Delete',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// World-class Add Item dialog with staggered field entrance animations,
/// inline validation, success feedback, and keyboard shortcuts.
class _AddItemDialog extends StatefulWidget {
  final String title;
  final List<LaunchColumn> columns;

  const _AddItemDialog({
    required this.title,
    required this.columns,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _dateValues = <String, String>{};
  final _dropdownValues = <String, String?>{};
  final _errors = <String, String?>{};
  final _focusNodes = <String, FocusNode>{};
  final _kazAiLoading = <String, bool>{};

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late bool _submitted;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _submitted = false;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    for (final col in widget.columns) {
      _focusNodes[col.label] = FocusNode();
      switch (col.fieldType) {
        case LaunchFieldType.text:
          _controllers[col.label] = TextEditingController();
        case LaunchFieldType.date:
          _dateValues[col.label] = '';
        case LaunchFieldType.dropdown:
          _dropdownValues[col.label] =
              (col.dropdownItems != null && col.dropdownItems!.isNotEmpty)
                  ? col.dropdownItems!.first
                  : null;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _validate() {
    _errors.clear();
    for (final col in widget.columns) {
      if (col.fieldType == LaunchFieldType.text) {
        final text = _controllers[col.label]?.text.trim() ?? '';
        if (text.isEmpty) {
          _errors[col.label] = '${col.label} is required';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_showSuccess) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: LaunchModalShell(
          icon: Icons.add_rounded,
          title: 'Add to ${widget.title}',
          subtitle: 'Fill in the fields below to add a new entry to this table.',
          body: AnimatedBuilder(
            animation: _fadeIn,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeIn.value,
                child: _showSuccess ? _buildSuccessState(theme) : child,
              );
            },
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildAnimatedFields(),
              ),
            ),
          ),
          actions: _showSuccess
              ? []
              : [
                  LaunchModalCancelButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  _buildSubmitButton(),
                ],
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedFields() {
    final widgets = <Widget>[];
    for (int i = 0; i < widget.columns.length; i++) {
      final col = widget.columns[i];
      final delay = i * 50;
      widgets.add(
        AnimatedBuilder(
          animation: _fadeIn,
          builder: (context, child) {
            final progress = (_fadeIn.value * 1000 - delay).clamp(0.0, 1.0) / 1.0;
            final slide = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
            return Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - slide)),
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i > 0) const SizedBox(height: 14),
              _buildField(col, i),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildField(LaunchColumn col, int index) {
    final error = _errors[col.label];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            LaunchModalLabel(col.label),
            if (col.fieldType == LaunchFieldType.text) ...[
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            ],
          ],
        ),
        const SizedBox(height: 4),
        _buildInput(col, index),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInput(LaunchColumn col, int index) {
    switch (col.fieldType) {
      case LaunchFieldType.text:
        return VoiceTextField(
          controller: _controllers[col.label],
          focusNode: _focusNodes[col.label],
          enableDocxImport: false,
          enableKazAi: false,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D1F)),
          decoration: _modalInputDecoration(
            hint: col.hint,
            error: _errors[col.label],
          ).copyWith(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // KAZ AI button — generates AI content for this field
                IconButton(
                  tooltip: 'KAZ AI',
                  icon: _kazAiLoading[col.label] == true
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome,
                          color: Color(0xFFF59E0B), size: 16),
                  onPressed: _kazAiLoading[col.label] == true
                      ? null
                      : () => _generateFieldWithAi(col.label),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
                // Clear-all button — deletes all content
                if ((_controllers[col.label]?.text ?? '').isNotEmpty)
                  IconButton(
                    tooltip: 'Clear all content',
                    icon: const Icon(Icons.delete_sweep,
                        color: Color(0xFFEF4444), size: 16),
                    onPressed: () {
                      _controllers[col.label]?.clear();
                      setState(() {});
                    },
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
          ),
          onChanged: (_) => setState(() {}),
        );
      case LaunchFieldType.date:
        return _buildDateField(col);
      case LaunchFieldType.dropdown:
        return _buildDropdownField(col);
    }
  }

  /// Generate AI content for a specific field in the Add dialog.
  /// Uses OpenAiServiceSecure with the dialog title as context.
  Future<void> _generateFieldWithAi(String fieldLabel) async {
    setState(() => _kazAiLoading[fieldLabel] = true);
    try {
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Suggest a concise value for the "$fieldLabel" field in a '
        '"${widget.title}" table entry for a project management application. '
        'Return ONLY the text value (no JSON, no markdown, no explanation).',
        maxTokens: 100,
        temperature: 0.6,
      );
      final cleaned = result.trim();
      if (cleaned.isNotEmpty && _controllers.containsKey(fieldLabel)) {
        _controllers[fieldLabel]!.text = cleaned;
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KAZ AI failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _kazAiLoading[fieldLabel] = false);
  }

  Widget _buildDateField(LaunchColumn col) {
    final value = _dateValues[col.label] ?? '';
    final display = value.isEmpty ? '' : value;
    return InkWell(
      onTap: () => _pickDate(col.label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: display.isEmpty
                ? const Color(0xFFE4E7EC)
                : const Color(0xFFFFC107),
            width: display.isEmpty ? 1 : 1.6,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                display.isEmpty ? (col.hint ?? 'Select date') : display,
                style: TextStyle(
                  fontSize: 13,
                  color: display.isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF1A1D1F),
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(String label) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (selected == null) return;
    final formatted =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    setState(() => _dateValues[label] = formatted);
  }

  Widget _buildDropdownField(LaunchColumn col) {
    final items = col.dropdownItems ?? [];
    final current = _dropdownValues[col.label];
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF6B7280), size: 20),
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D1F)),
      decoration: InputDecoration(
        hintText: col.hint ?? 'Select ${col.label.toLowerCase()}',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.6),
        ),
      ),
      items: items
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() => _dropdownValues[col.label] = v),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: _showSuccess ? null : _submit,
        icon: _showSuccess
            ? const Icon(Icons.check_circle_rounded, size: 16)
            : const Icon(Icons.check_rounded, size: 16),
        label: Text(_showSuccess ? 'Added!' : 'Add Item'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _showSuccess
              ? const Color(0xFF10B981)
              : const Color(0xFFFFC107),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Item Added Successfully',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The new entry has been added to the table.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    setState(() {
      _submitted = true;
      _validate();
    });
    if (_errors.isNotEmpty) return;
    final values = <String, String>{};
    for (final col in widget.columns) {
      switch (col.fieldType) {
        case LaunchFieldType.text:
          values[col.label] = _controllers[col.label]?.text ?? '';
        case LaunchFieldType.date:
          values[col.label] = _dateValues[col.label] ?? '';
        case LaunchFieldType.dropdown:
          values[col.label] = _dropdownValues[col.label] ?? '';
      }
    }
    setState(() => _showSuccess = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pop(context, values);
    });
  }
}

InputDecoration _modalInputDecoration({String? hint, String? error}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
    ),
  );
}
