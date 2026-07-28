import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/widgets/expandable_text.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/theme.dart';
class ContractsTable extends StatefulWidget {
  const ContractsTable({
    super.key,
    required this.contracts,
    this.onEdit,
    this.onDelete,
  });

  final List<ContractModel> contracts;
  final Function(ContractModel)? onEdit;
  final Function(ContractModel)? onDelete;

  @override
  State<ContractsTable> createState() => _ContractsTableState();
}

class _ContractsTableState extends State<ContractsTable> {
  static const int _rowsPerPage = 12;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant ContractsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contracts.length == widget.contracts.length) return;
    final totalPages = ((widget.contracts.length - 1) ~/ _rowsPerPage) + 1;
    if (_pageIndex >= totalPages) {
      _pageIndex = totalPages - 1;
    }
    if (_pageIndex < 0) _pageIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contracts.isEmpty) {
      return _EmptyState(label: 'contracts');
    }

    final totalPages = ((widget.contracts.length - 1) ~/ _rowsPerPage) + 1;
    final safePageIndex = _pageIndex.clamp(0, totalPages - 1);
    final start = safePageIndex * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, widget.contracts.length);
    final visible = widget.contracts.sublist(start, end);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveDataTableWrapper(
              minWidth: constraints.maxWidth,
              maxHeight: 560,
              child: buildNduDataTable(
                context: context,
                columnSpacing: 24,
                horizontalMargin: 16,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                border: TableBorder(
                  bottom: BorderSide(color: Colors.grey[200]!),
                  verticalInside: BorderSide.none,
                ),
                columns: const [
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CONTRACT ITEM',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CONTRACTOR',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('VALUE',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('TIMELINE',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('OWNER',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(
                      label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('STATUS',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 12,
                            color: Color(0xFF64748B))),
                  )),
                  DataColumn(label: Center(child: Text(''))),
                ],
                rows: visible.map((contract) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contract.title,
                              textAlign: TextAlign.left,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              contract.description,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      DataCell(_TextCell(contract.contractorName)),
                      DataCell(_PriceCell(contract.estimatedCost)),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (contract.startDate != null)
                              Text(
                                'Start: ${DateFormat('MMM dd, yyyy').format(contract.startDate!)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            if (contract.endDate != null)
                              Text(
                                'End: ${DateFormat('MMM dd, yyyy').format(contract.endDate!)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            if (contract.startDate == null &&
                                contract.endDate == null)
                              const Text('-',
                                  style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      DataCell(_OwnerBadge(name: contract.owner)),
                      DataCell(_ContractStatusBadge(status: contract.status)),
                      DataCell(
                        PopupMenuButton(
                          icon:
                              const Icon(Icons.more_horiz, color: Colors.grey),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Contract'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit' && widget.onEdit != null) {
                              widget.onEdit!(contract);
                            } else if (value == 'delete' &&
                                widget.onDelete != null) {
                              widget.onDelete!(contract);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            _TablePager(
              totalCount: widget.contracts.length,
              pageIndex: safePageIndex,
              pageSize: _rowsPerPage,
              onPrev: safePageIndex > 0
                  ? () => setState(() => _pageIndex = safePageIndex - 1)
                  : null,
              onNext: safePageIndex < totalPages - 1
                  ? () => setState(() => _pageIndex = safePageIndex + 1)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class ProcurementTable extends StatefulWidget {
  const ProcurementTable({
    super.key,
    required this.items,
    this.onEdit,
    this.onDelete,
    this.responsibleOptions = const <String>[],
    this.onResponsibleChanged,
  });

  final List<ProcurementItemModel> items;
  final Function(ProcurementItemModel)? onEdit;
  final Function(ProcurementItemModel)? onDelete;
  final List<String> responsibleOptions;
  final FutureOr<void> Function(ProcurementItemModel item, String responsible)?
      onResponsibleChanged;

  @override
  State<ProcurementTable> createState() => _ProcurementTableState();
}

class _ProcurementTableState extends State<ProcurementTable> {
  static const int _rowsPerPage = 12;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant ProcurementTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length == widget.items.length) return;
    final totalPages = ((widget.items.length - 1) ~/ _rowsPerPage) + 1;
    if (_pageIndex >= totalPages) {
      _pageIndex = totalPages - 1;
    }
    if (_pageIndex < 0) _pageIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _EmptyState(label: 'vendors/items');
    }

    final totalPages = ((widget.items.length - 1) ~/ _rowsPerPage) + 1;
    final safePageIndex = _pageIndex.clamp(0, totalPages - 1);
    final start = safePageIndex * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, widget.items.length);
    final visible = widget.items.sublist(start, end);
    final hasActions = widget.onEdit != null || widget.onDelete != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveDataTableWrapper(
              minWidth: constraints.maxWidth,
              maxHeight: 560,
              child: buildNduDataTable(
                context: context,
                columnSpacing: 24,
                horizontalMargin: 12,
                border: TableBorder.all(
                    color: Colors.grey[300]!,
                    width: 0.5,
                    borderRadius: BorderRadius.circular(8)),
                columns: [
                  const DataColumn(
                    label: Center(
                        child: Text('Item / Equipment',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const DataColumn(
                    label: Center(
                        child: Text('Stage',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const DataColumn(
                    label: Center(
                        child: Text('Responsible',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const DataColumn(
                    label: Center(
                        child: Text('Est. Price',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const DataColumn(
                    label: Center(
                        child: Text('Status',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const DataColumn(
                    label: Center(
                        child: Text('Comments',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  if (hasActions)
                    const DataColumn(label: Center(child: Text(''))),
                ],
                rows: visible.map((item) {
                  final actionItems = <PopupMenuEntry<String>>[];
                  if (widget.onEdit != null) {
                    actionItems.add(
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit item'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (widget.onDelete != null) {
                    actionItems.add(
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  }

                  return DataRow(
                    cells: [
                      DataCell(_TextCell(item.name, bold: true)),
                      DataCell(_TextCell(item.projectPhase.isNotEmpty
                          ? item.projectPhase
                          : 'Planning')),
                      DataCell(
                        _ResponsiblePickerCell(
                          value: item.responsibleMember,
                          options: widget.responsibleOptions,
                          onChanged: widget.onResponsibleChanged == null
                              ? null
                              : (nextValue) => widget.onResponsibleChanged!(
                                    item,
                                    nextValue,
                                  ),
                        ),
                      ),
                      DataCell(_PriceCell(item.budget)),
                      DataCell(_StatusCell(item.status.name)),
                      DataCell(_ExpandableCell(item.comments)),
                      if (hasActions)
                        DataCell(
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz,
                                color: Colors.grey),
                            itemBuilder: (_) => actionItems,
                            onSelected: (value) {
                              if (value == 'edit' && widget.onEdit != null) {
                                widget.onEdit!(item);
                              } else if (value == 'delete' &&
                                  widget.onDelete != null) {
                                widget.onDelete!(item);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            _TablePager(
              totalCount: widget.items.length,
              pageIndex: safePageIndex,
              pageSize: _rowsPerPage,
              onPrev: safePageIndex > 0
                  ? () => setState(() => _pageIndex = safePageIndex - 1)
                  : null,
              onNext: safePageIndex < totalPages - 1
                  ? () => setState(() => _pageIndex = safePageIndex + 1)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _TablePager extends StatelessWidget {
  const _TablePager({
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int totalCount;
  final int pageIndex;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (totalCount <= pageSize) return const SizedBox.shrink();
    final start = pageIndex * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pages = ((totalCount - 1) ~/ pageSize) + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text(
            'Showing ${start + 1}-$end of $totalCount',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Page ${pageIndex + 1} of $pages',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return buildNduTableEmptyState(
      context,
      message: 'No $label added yet. Click + Add to get started.',
    );
  }
}

class _ResponsiblePickerCell extends StatelessWidget {
  const _ResponsiblePickerCell({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final FutureOr<void> Function(String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final noMembers = options.isEmpty;
    final isInteractive = !noMembers && onChanged != null;

    return InkWell(
      onTap: !isInteractive
          ? null
          : () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (dialogContext) => _ResponsiblePickerDialog(
                  options: options,
                  initialQuery: value,
                ),
              );
              if (selected == null || selected.trim().isEmpty) return;
              await onChanged!(selected.trim());
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                noMembers
                    ? 'No members available'
                    : (hasValue ? value.trim() : 'Unassigned'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: noMembers
                      ? const Color(0xFF9CA3AF)
                      : (hasValue
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF6B7280)),
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: isInteractive
                  ? const Color(0xFF64748B)
                  : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiblePickerDialog extends StatefulWidget {
  const _ResponsiblePickerDialog({
    required this.options,
    required this.initialQuery,
  });

  final List<String> options;
  final String initialQuery;

  @override
  State<_ResponsiblePickerDialog> createState() =>
      _ResponsiblePickerDialogState();
}

class _ResponsiblePickerDialogState extends State<_ResponsiblePickerDialog> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filteredOptions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where((option) => option.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions();
    final dialogWidth = MediaQuery.sizeOf(context).width > 560
        ? 440.0
        : MediaQuery.sizeOf(context).width * 0.86;
    return AlertDialog(
      title: const Text('Select Responsible Member'),
      content: SizedBox(
        width: dialogWidth,
        height: 380,
        child: Column(
          children: [
            VoiceTextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search members...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No members available',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _TextCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _TextCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Text(
        text,
        textAlign: TextAlign.left,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.fade,
        style: (bold ? const TextStyle(fontWeight: FontWeight.w600) : null)
            ?.copyWith(height: 1.3),
      ),
    );
  }
}

class _ExpandableCell extends StatelessWidget {
  final String text;
  const _ExpandableCell(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const Text('-');
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      child: ExpandableText(
        text: text,
        maxLines: 1,
        style: const TextStyle(fontSize: 13),
        expandButtonColor: const Color(0xFFD97706),
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  final double amount;
  const _PriceCell(this.amount);

  @override
  Widget build(BuildContext context) {
    return Text(
      NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount),
      textAlign: TextAlign.center,
      style:
          const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w600),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  final String name;
  const _OwnerBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty || name == 'Unassigned') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Unassigned',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0xFFFDE68A),
          child: Text(name[0].toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ContractStatusBadge extends StatelessWidget {
  final ContractStatus status;
  const _ContractStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label = status.name.replaceAll('_', ' ').toUpperCase();

    switch (status) {
      case ContractStatus.draft:
        color = Colors.grey[700]!;
        bg = Colors.grey[100]!;
        break;
      case ContractStatus.under_review:
        color = const Color(0xFFB45309)!;
        bg = const Color(0xFFFFF7E6)!;
        break;
      case ContractStatus.approved:
        color = Colors.purple[700]!;
        bg = Colors.purple[50]!;
        break;
      case ContractStatus.executed:
        color = Colors.green[700]!;
        bg = Colors.green[50]!;
        break;
      case ContractStatus.expired:
        color = Colors.orange[800]!;
        bg = Colors.orange[50]!;
        break;
      case ContractStatus.terminated:
        color = Colors.red[800]!;
        bg = Colors.red[50]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final String status;
  const _StatusCell(this.status);
  // ... existing implementation for Procurement Items ...
  @override
  Widget build(BuildContext context) {
    // ... existing logic ...
    final s = status.toLowerCase();
    Color color = Colors.grey;
    if (s.contains('planning') || s.contains('draft')) color = Colors.blue;
    if (s.contains('active') || s.contains('issued')) color = Colors.green;
    if (s.contains('ordered') || s.contains('transit')) color = Colors.orange;
    if (s.contains('delivered') || s.contains('received')) color = Colors.teal;
    if (s.contains('cancelled')) color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
