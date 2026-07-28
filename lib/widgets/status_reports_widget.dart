import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/status_report_row.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/progress_quick_actions.dart';
import 'package:intl/intl.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Status Reports & Asks Tracking sub-page
class StatusReportsWidget extends StatefulWidget {
  const StatusReportsWidget({
    super.key,
    required this.statusReports,
    required this.onStatusReportsChanged,
  });

  final List<StatusReportRow> statusReports;
  final ValueChanged<List<StatusReportRow>> onStatusReportsChanged;

  @override
  State<StatusReportsWidget> createState() => _StatusReportsWidgetState();
}

class _StatusReportsWidgetState extends State<StatusReportsWidget> {
  List<StatusReportRow> get _reports => widget.statusReports;
  StatusReportRow? _deletedItem;
  int? _deletedIndex;
  Timer? _undoTimer;

  void _addNew() {
    final newReport = StatusReportRow(
      reportType: '',
      stakeholder: '',
      reportDate: DateTime.now(),
      status: 'Draft',
    );
    widget.onStatusReportsChanged([newReport, ..._reports]);
  }

  void _update(int index, StatusReportRow updated) {
    final updatedList = List<StatusReportRow>.from(_reports);
    updatedList[index] = updated;
    widget.onStatusReportsChanged(updatedList);
  }

  void _delete(int index) {
    final deleted = _reports[index];
    final updated = List<StatusReportRow>.from(_reports);
    updated.removeAt(index);
    widget.onStatusReportsChanged(updated);

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
            Text('Status report deleted'),
            Spacer(),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            _undoTimer?.cancel();
            if (_deletedItem != null && _deletedIndex != null) {
              final restored = List<StatusReportRow>.from(_reports);
              restored.insert(_deletedIndex!, _deletedItem!);
              widget.onStatusReportsChanged(restored);
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
                    'Status reports & asks',
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
          if (_reports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: Color(0xFF9CA3AF), size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'No status reports yet.',
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      _TableHeaderCell('Report Type', flex: 2),
                      _TableHeaderCell('Stakeholder', flex: 2),
                      _TableHeaderCell('Date', flex: 2),
                      _TableHeaderCell('Status', flex: 2),
                      _TableHeaderCell('Action', flex: 1),
                    ],
                  ),
                ),
                ...List.generate(_reports.length, (index) {
                  final report = _reports[index];
                  final isLast = index == _reports.length - 1;
                  return _StatusReportRowWidget(
                    report: report,
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

class _StatusReportRowWidget extends StatefulWidget {
  const _StatusReportRowWidget({
    required this.report,
    required this.onChanged,
    required this.onDelete,
    required this.showDivider,
  });

  final StatusReportRow report;
  final ValueChanged<StatusReportRow> onChanged;
  final VoidCallback onDelete;
  final bool showDivider;

  @override
  State<_StatusReportRowWidget> createState() => _StatusReportRowWidgetState();
}

class _StatusReportRowWidgetState extends State<_StatusReportRowWidget> {
  late StatusReportRow _report;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  @override
  void didUpdateWidget(_StatusReportRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report) {
      _report = widget.report;
    }
  }

  void _update(StatusReportRow updated) {
    setState(() => _report = updated);
    widget.onChanged(updated);
  }

  Future<void> _showEditDialog() async {
    final reportTypeController =
        TextEditingController(text: _report.reportType);
    final stakeholderController =
        TextEditingController(text: _report.stakeholder);
    final summaryController = TextEditingController(text: _report.summary);
    final keyWinsController = TextEditingController(text: _report.keyWins);
    final blockersController = TextEditingController(text: _report.blockers);
    final asksController = TextEditingController(text: _report.asks);
    final followUpsController = TextEditingController(text: _report.followUps);
    final notesController = TextEditingController(text: _report.notes);
    DateTime selectedDate = _report.reportDate;
    var selectedStatus = _report.status;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Status Report'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoiceTextField(
                          controller: reportTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Report Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: stakeholderController,
                          decoration: const InputDecoration(
                            labelText: 'Stakeholder',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Report Date: ${DateFormat('MMM d, yyyy').format(selectedDate)}',
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
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) return;
                                setDialogState(() => selectedDate = picked);
                              },
                              child: const Text('Select Date'),
                            ),
                          ],
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
                                value: 'Draft', child: Text('Draft')),
                            DropdownMenuItem(
                                value: 'Sent', child: Text('Sent')),
                            DropdownMenuItem(
                                value: 'Acknowledged',
                                child: Text('Acknowledged')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedStatus = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: summaryController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Summary',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: keyWinsController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Key Wins',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: blockersController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Blockers',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: asksController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Asks',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VoiceTextField(
                          controller: followUpsController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Follow-ups',
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
                      final updated = _report.copyWith(
                        reportType: reportTypeController.text.trim(),
                        stakeholder: stakeholderController.text.trim(),
                        reportDate: selectedDate,
                        status: selectedStatus,
                        summary: summaryController.text.trim(),
                        keyWins: keyWinsController.text.trim(),
                        blockers: blockersController.text.trim(),
                        asks: asksController.text.trim(),
                        followUps: followUpsController.text.trim(),
                        notes: notesController.text.trim(),
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
      reportTypeController.dispose();
      stakeholderController.dispose();
      summaryController.dispose();
      keyWinsController.dispose();
      blockersController.dispose();
      asksController.dispose();
      followUpsController.dispose();
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
                    flex: 3,
                    child: InlineEditableText(
                      value: _report.reportType,
                      hint: 'Report type',
                      onChanged: (v) =>
                          _update(_report.copyWith(reportType: v)),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: InlineEditableText(
                      value: _report.stakeholder,
                      hint: 'Stakeholder',
                      onChanged: (v) =>
                          _update(_report.copyWith(stakeholder: v)),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        DateFormat('MMM d, yyyy').format(_report.reportDate),
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
                          color: _report.status == 'Sent'
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : _report.status == 'Draft'
                                  ? const Color(0xFFF59E0B)
                                      .withOpacity(0.1)
                                  : const Color(0xFF2563EB)
                                      .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _report.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _report.status == 'Sent'
                                ? const Color(0xFF10B981)
                                : _report.status == 'Draft'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF2563EB),
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
