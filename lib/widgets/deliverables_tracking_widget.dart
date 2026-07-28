import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/deliverable_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:intl/intl.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Deliverables Tracking sub-page with Timeline view and full CRUD
class DeliverablesTrackingWidget extends StatefulWidget {
  const DeliverablesTrackingWidget({
    super.key,
    required this.deliverables,
    required this.onDeliverablesChanged,
  });

  final List<DeliverableRow> deliverables;
  final ValueChanged<List<DeliverableRow>> onDeliverablesChanged;

  @override
  State<DeliverablesTrackingWidget> createState() =>
      _DeliverablesTrackingWidgetState();
}

class _DeliverablesTrackingWidgetState
    extends State<DeliverablesTrackingWidget> {
  List<DeliverableRow> get _deliverables => widget.deliverables;
  DeliverableRow? _deletedItem;
  int? _deletedIndex;
  Timer? _undoTimer;

  void _updateDeliverable(int index, DeliverableRow updated) {
    final updatedList = List<DeliverableRow>.from(_deliverables);
    updatedList[index] = updated;
    widget.onDeliverablesChanged(updatedList);
  }

  void _deleteDeliverable(int index) {
    final deleted = _deliverables[index];
    final updated = List<DeliverableRow>.from(_deliverables);
    updated.removeAt(index);
    widget.onDeliverablesChanged(updated);

    // Store for undo
    setState(() {
      _deletedItem = deleted;
      _deletedIndex = index;
    });

    // Show undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Deliverable deleted'),
            Spacer(),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            _undoTimer?.cancel();
            if (_deletedItem != null && _deletedIndex != null) {
              final restored = List<DeliverableRow>.from(_deliverables);
              restored.insert(_deletedIndex!, _deletedItem!);
              widget.onDeliverablesChanged(restored);
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

    // Auto-commit deletion after 5 seconds
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _deletedItem = null;
        _deletedIndex = null;
      });
    });
  }

  Future<void> _regenerateDeliverable(int index) async {
    final deliverable = _deliverables[index];

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final data = provider?.projectData;
      if (data == null) return;

      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Deliverable Status Updates',
      );

      final ai = OpenAiServiceSecure();

      // Predict delays and get suggestions
      final delayPrediction = await ai.predictDeliverableDelays(
        context: contextText,
        deliverableTitle:
            deliverable.title.isNotEmpty ? deliverable.title : 'Deliverable',
        dueDate: deliverable.dueDate != null
            ? DateFormat('yyyy-MM-dd').format(deliverable.dueDate!)
            : 'Not set',
        currentStatus: deliverable.status,
      );

      // Update deliverable with AI suggestions
      final mitigationSuggestions =
          (delayPrediction['mitigationSuggestions'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .join('\n') ??
              '';

      final recommendedAction =
          delayPrediction['recommendedAction'] as String? ?? '';

      final updated = deliverable.copyWith(
        nextSteps: mitigationSuggestions.isNotEmpty
            ? mitigationSuggestions
            : deliverable.nextSteps,
        description: recommendedAction.isNotEmpty
            ? (deliverable.description.isNotEmpty
                ? '${deliverable.description}\n\n$recommendedAction'
                : recommendedAction)
            : deliverable.description,
      );

      _updateDeliverable(index, updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI analysis: ${delayPrediction['riskLevel']} risk level. ${delayPrediction['predictedDelayDays']} days predicted delay.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
        // Deliverables Table
        _buildDeliverablesTable(),
      ],
    );
  }

  Widget _buildDeliverablesTable() {
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
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Deliverable status updates',
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
          // Table
          if (_deliverables.isEmpty) _buildEmptyState() else _buildTable(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF9CA3AF), size: 32),
            const SizedBox(height: 12),
            const Text(
              'No deliverables yet. Add details to get started.',
              style: TextStyle(
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

  Widget _buildTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              _TableHeaderCell('Deliverable', flex: 4),
              _TableHeaderCell('Owner', flex: 2),
              _TableHeaderCell('Due Date', flex: 2),
              _TableHeaderCell('Status', flex: 2),
              _TableHeaderCell('Actions', flex: 2),
            ],
          ),
        ),
        // Table Rows
        ...List.generate(_deliverables.length, (index) {
          final deliverable = _deliverables[index];
          final isLast = index == _deliverables.length - 1;
          return _DeliverableRowWidget(
            deliverable: deliverable,
            onChanged: (updated) => _updateDeliverable(index, updated),
            onDelete: () => _deleteDeliverable(index),
            onRegenerate: () => _regenerateDeliverable(index),
            showDivider: !isLast,
          );
        }),
      ],
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DeliverableRowWidget extends StatefulWidget {
  const _DeliverableRowWidget({
    required this.deliverable,
    required this.onChanged,
    required this.onDelete,
    required this.onRegenerate,
    required this.showDivider,
  });

  final DeliverableRow deliverable;
  final ValueChanged<DeliverableRow> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final bool showDivider;

  @override
  State<_DeliverableRowWidget> createState() => _DeliverableRowWidgetState();
}

class _DeliverableRowWidgetState extends State<_DeliverableRowWidget> {
  late DeliverableRow _deliverable;
  bool _isHovering = false;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _deliverable = widget.deliverable;
  }

  @override
  void didUpdateWidget(_DeliverableRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliverable != widget.deliverable) {
      _deliverable = widget.deliverable;
    }
  }

  void _updateDeliverable(DeliverableRow updated) {
    setState(() => _deliverable = updated);
    widget.onChanged(updated);
  }

  Future<void> _showFullEditDialog() async {
    final titleController = TextEditingController(text: _deliverable.title);
    // Prose fields - no bullets
    final descriptionController =
        RichTextEditingController(text: _deliverable.description);
    final notesController = RichTextEditingController(text: _deliverable.notes);
    // List fields - use AutoBulletTextController for "." bullet format
    final blockersController =
        AutoBulletTextController(text: _deliverable.blockers);
    final nextStepsController =
        AutoBulletTextController(text: _deliverable.nextSteps);
    final ownerController = TextEditingController(text: _deliverable.owner);

    var selectedStatus = _deliverable.status;
    DateTime? selectedDueDate = _deliverable.dueDate;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Deliverable', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VoiceTextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Deliverable Title *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 6),
                  VoiceTextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Prose)',
                      hintText: 'Prose description, no bullets',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: ownerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: TextEditingController(
                      text: selectedDueDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDueDate!)
                          : '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Due Date (YYYY-MM-DD)',
                      hintText: '2024-01-15',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      try {
                        selectedDueDate = DateFormat('yyyy-MM-dd').parse(value);
                      } catch (e) {
                        selectedDueDate = null;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value:
                        selectedStatus.isEmpty ? null : selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: const [
                      'Not Started',
                      'In Progress',
                      'Completed',
                      'At Risk',
                      'Blocked',
                    ]
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => selectedStatus = v ?? 'Not Started');
                    },
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: blockersController,
                    decoration: const InputDecoration(
                      labelText: 'Blockers',
                      hintText: 'Use "." bullet format',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: nextStepsController,
                    decoration: const InputDecoration(
                      labelText: 'Next Steps',
                      hintText: 'Use "." bullet format',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 6),
                  VoiceTextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Manual notes only',
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _updateDeliverable(_deliverable.copyWith(
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  owner: ownerController.text.trim(),
                  dueDate: selectedDueDate,
                  status: selectedStatus,
                  blockers: blockersController.text.trim(),
                  nextSteps: nextStepsController.text.trim(),
                  notes: notesController.text.trim(),
                ));
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: InlineEditableText(
                      value: _deliverable.title,
                      hint: 'Deliverable title',
                      onChanged: (v) =>
                          _updateDeliverable(_deliverable.copyWith(title: v)),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: InlineEditableText(
                      value: _deliverable.owner,
                      hint: 'Owner',
                      onChanged: (v) =>
                          _updateDeliverable(_deliverable.copyWith(owner: v)),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _deliverable.dueDate != null
                            ? DateFormat('MMM d, yyyy')
                                .format(_deliverable.dueDate!)
                            : 'Not set',
                        style: TextStyle(
                          fontSize: 12,
                          color: _deliverable.isOverdue
                              ? const Color(0xFFEF4444)
                              : _deliverable.isAtRisk
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF111827),
                          fontWeight:
                              _deliverable.isOverdue || _deliverable.isAtRisk
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                        ),
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
                          color: _getStatusColor(_deliverable.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _deliverable.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(_deliverable.status),
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
                                  icon: _isRegenerating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF7C3AED),
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome,
                                          size: 16, color: Color(0xFF7C3AED)),
                                  onPressed: _isRegenerating
                                      ? null
                                      : () {
                                          setState(
                                              () => _isRegenerating = true);
                                          widget.onRegenerate();
                                          Future.delayed(
                                              const Duration(seconds: 2), () {
                                            if (mounted) {
                                              setState(() =>
                                                  _isRegenerating = false);
                                            }
                                          });
                                        },
                                  tooltip: 'Regenerate',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: Color(0xFF64748B)),
                                  onPressed: _showFullEditDialog,
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

  Color _getStatusColor(String status) {
    return switch (status) {
      'Completed' => const Color(0xFF10B981),
      'In Progress' => const Color(0xFF2563EB),
      'At Risk' => const Color(0xFFF59E0B),
      'Blocked' => const Color(0xFFEF4444),
      _ => const Color(0xFF9CA3AF),
    };
  }
}
