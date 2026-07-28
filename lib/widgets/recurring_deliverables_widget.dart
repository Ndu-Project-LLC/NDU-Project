import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/recurring_deliverable_row.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/progress_quick_actions.dart';
import 'package:intl/intl.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Recurring Deliverables Tracking sub-page
class RecurringDeliverablesWidget extends StatefulWidget {
  const RecurringDeliverablesWidget({
    super.key,
    required this.recurringDeliverables,
    required this.onRecurringChanged,
  });

  final List<RecurringDeliverableRow> recurringDeliverables;
  final ValueChanged<List<RecurringDeliverableRow>> onRecurringChanged;

  @override
  State<RecurringDeliverablesWidget> createState() =>
      _RecurringDeliverablesWidgetState();
}

class _RecurringDeliverablesWidgetState
    extends State<RecurringDeliverablesWidget> {
  List<RecurringDeliverableRow> get _recurring => widget.recurringDeliverables;
  RecurringDeliverableRow? _deletedItem;
  int? _deletedIndex;
  Timer? _undoTimer;

  void _addNew() {
    final newItem = RecurringDeliverableRow(
      title: '',
      description: '',
      frequency: 'Weekly',
      status: 'Active',
    );
    widget.onRecurringChanged([newItem, ..._recurring]);
  }

  void _update(int index, RecurringDeliverableRow updated) {
    final updatedList = List<RecurringDeliverableRow>.from(_recurring);
    updatedList[index] = updated;
    widget.onRecurringChanged(updatedList);
  }

  void _delete(int index) {
    final deleted = _recurring[index];
    final updated = List<RecurringDeliverableRow>.from(_recurring);
    updated.removeAt(index);
    widget.onRecurringChanged(updated);

    setState(() {
      _deletedItem = deleted;
      _deletedIndex = index;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Recurring deliverable deleted'),
            Spacer(),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            _undoTimer?.cancel();
            if (_deletedItem != null && _deletedIndex != null) {
              final restored = List<RecurringDeliverableRow>.from(_recurring);
              restored.insert(_deletedIndex!, _deletedItem!);
              widget.onRecurringChanged(restored);
              setState(() {
                _deletedItem = null;
                _deletedIndex = null;
              });
            }
          },
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF111827),
      ),
    );

    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _deletedItem = null;
        _deletedIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ProgressQuickActions(
              onAdd: _addNew,
              showRegenerate: false,
              showExport: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTable(),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recurring deliverables',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (_recurring.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.repeat_outlined,
                        color: Color(0xFF9CA3AF), size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'No recurring deliverables yet.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      _TableHeaderCell('Recurring Item', flex: 4),
                      _TableHeaderCell('Frequency', flex: 2),
                      _TableHeaderCell('Next Occurrence', flex: 2),
                      _TableHeaderCell('Status', flex: 2),
                      _TableHeaderCell('Actions', flex: 2),
                    ],
                  ),
                ),
                ...List.generate(_recurring.length, (index) {
                  final item = _recurring[index];
                  final isLast = index == _recurring.length - 1;
                  return _RecurringRowWidget(
                    item: item,
                    onChanged: (updated) => _update(index, updated),
                    onDelete: () => _delete(index),
                    showDivider: !isLast,
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RecurringRowWidget extends StatefulWidget {
  const _RecurringRowWidget({
    required this.item,
    required this.onChanged,
    required this.onDelete,
    required this.showDivider,
  });

  final RecurringDeliverableRow item;
  final ValueChanged<RecurringDeliverableRow> onChanged;
  final VoidCallback onDelete;
  final bool showDivider;

  @override
  State<_RecurringRowWidget> createState() => _RecurringRowWidgetState();
}

class _RecurringRowWidgetState extends State<_RecurringRowWidget> {
  late RecurringDeliverableRow _item;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void didUpdateWidget(_RecurringRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _item = widget.item;
    }
  }

  void _update(RecurringDeliverableRow updated) {
    setState(() => _item = updated);
    widget.onChanged(updated);
  }

  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: _item.title);
    final descriptionController =
        TextEditingController(text: _item.description);
    final ownerController = TextEditingController(text: _item.owner);
    final notesController = TextEditingController(text: _item.notes);
    var selectedFrequency = _item.frequency;
    var selectedStatus = _item.status;
    DateTime? nextOccurrence = _item.nextOccurrence;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Recurring Deliverable'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoiceTextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Daily', child: Text('Daily')),
                            DropdownMenuItem(
                                value: 'Weekly', child: Text('Weekly')),
                            DropdownMenuItem(
                                value: 'Bi-Weekly', child: Text('Bi-Weekly')),
                            DropdownMenuItem(
                                value: 'Monthly', child: Text('Monthly')),
                            DropdownMenuItem(
                                value: 'Quarterly', child: Text('Quarterly')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedFrequency = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'Paused', child: Text('Paused')),
                            DropdownMenuItem(
                                value: 'Completed', child: Text('Completed')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedStatus = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Owner',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nextOccurrence == null
                                    ? 'Next Occurrence: Not set'
                                    : 'Next Occurrence: ${DateFormat('MMM d, yyyy').format(nextOccurrence!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: nextOccurrence ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) return;
                                setDialogState(() => nextOccurrence = picked);
                              },
                              child: const Text('Select Date'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final updated = _item.copyWith(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        frequency: selectedFrequency,
                        status: selectedStatus,
                        owner: ownerController.text.trim(),
                        notes: notesController.text.trim(),
                        nextOccurrence: nextOccurrence,
                      );
                      _update(updated);
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      ownerController.dispose();
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) =>
          Future.microtask(() => setState(() => _isHovering = true)),
      onExit: (_) =>
          Future.microtask(() => setState(() => _isHovering = false)),
      child: Container(
        color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: InlineEditableText(
                      value: _item.title,
                      hint: 'Recurring item title',
                      onChanged: (v) => _update(_item.copyWith(title: v)),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: DropdownButton<String>(
                        value: _item.frequency,
                        isDense: true,
                        underline: const SizedBox(),
                        items: const [
                          'Daily',
                          'Weekly',
                          'Bi-Weekly',
                          'Monthly',
                          'Quarterly',
                        ]
                            .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f,
                                      style: const TextStyle(fontSize: 12)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _update(_item.copyWith(frequency: v));
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _item.nextOccurrence != null
                            ? DateFormat('MMM d, yyyy')
                                .format(_item.nextOccurrence!)
                            : 'Not set',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF111827)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _item.status == 'Active'
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFF9CA3AF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _item.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _item.status == 'Active'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _isHovering
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: Color(0xFF64748B)),
                                  onPressed: _showEditDialog,
                                  tooltip: 'Edit',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Color(0xFF9CA3AF)),
                                  onPressed: widget.onDelete,
                                  tooltip: 'Delete',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            )
                          : const SizedBox(width: 40),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
      ),
    );
  }
}
