import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/stakeholder_alignment_item.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// Custom Stakeholder Alignment Table with inline editing, CRUD actions, and AI capabilities
class StakeholderAlignmentTableWidget extends StatelessWidget {
  const StakeholderAlignmentTableWidget({
    super.key,
    required this.items,
    required this.onUpdated,
    required this.onDeleted,
  });

  final List<StakeholderAlignmentItem> items;
  final ValueChanged<StakeholderAlignmentItem> onUpdated;
  final ValueChanged<StakeholderAlignmentItem> onDeleted;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return buildNduTableEmptyState(
        context,
        message: 'No items added yet. Click + Add to get started.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
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
          child: ResponsiveDataTableWrapper(
            minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 900,
            maxHeight: 560,
            child: buildNduDataTable(
              context: context,
              columnSpacing: 24,
              horizontalMargin: 20,
              headingRowHeight: 56,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 120,
              columns: const [
                DataColumn(
                  label: Center(
                    child: Text('Stakeholder Name/Role',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Alignment Status',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Key Interest/Value',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Feedback Summary',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Last Engagement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Actions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
              ],
              rows: items.map((item) {
                return DataRow(
                  key: ValueKey(item.id),
                  cells: [
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_name'),
                      item: item,
                      column: _StakeholderAlignmentColumn.stakeholderName,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_status'),
                      item: item,
                      column: _StakeholderAlignmentColumn.alignmentStatus,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_interest'),
                      item: item,
                      column: _StakeholderAlignmentColumn.keyInterest,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_feedback'),
                      item: item,
                      column: _StakeholderAlignmentColumn.feedbackSummary,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_date'),
                      item: item,
                      column: _StakeholderAlignmentColumn.lastEngagementDate,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_StakeholderAlignmentRowWidget(
                      key: ValueKey('${item.id}_actions'),
                      item: item,
                      column: _StakeholderAlignmentColumn.actions,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

enum _StakeholderAlignmentColumn {
  stakeholderName,
  alignmentStatus,
  keyInterest,
  feedbackSummary,
  lastEngagementDate,
  actions,
}

class _StakeholderAlignmentRowWidget extends StatefulWidget {
  const _StakeholderAlignmentRowWidget({
    super.key,
    required this.item,
    required this.column,
    required this.onUpdated,
    required this.onDeleted,
  });

  final StakeholderAlignmentItem item;
  final _StakeholderAlignmentColumn column;
  final ValueChanged<StakeholderAlignmentItem> onUpdated;
  final ValueChanged<StakeholderAlignmentItem> onDeleted;

  @override
  State<_StakeholderAlignmentRowWidget> createState() =>
      _StakeholderAlignmentRowWidgetState();
}

class _StakeholderAlignmentRowWidgetState
    extends State<_StakeholderAlignmentRowWidget> {
  StakeholderAlignmentItem? _previousState;
  final _Debouncer _debouncer = _Debouncer();
  bool _isRegenerating = false;

  static const List<String> _keyInterests = [
    'ROI',
    'Security',
    'Ease of Use',
    'Cost Savings',
    'Revenue',
    'Compliance',
    'Performance',
    'Innovation',
    'Risk Mitigation',
    'User Experience',
  ];

  @override
  Widget build(BuildContext context) {
    switch (widget.column) {
      case _StakeholderAlignmentColumn.stakeholderName:
        return Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InlineEditableText(
                value: widget.item.stakeholderName,
                hint: 'Enter name',
                onChanged: (value) =>
                    _updateItem(widget.item.copyWith(stakeholderName: value)),
                textAlign: TextAlign.left,
                maxLines: 1,
              ),
              if (widget.item.stakeholderRole.isNotEmpty)
                Text(
                  widget.item.stakeholderRole,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
        );
      case _StakeholderAlignmentColumn.alignmentStatus:
        return Align(
          alignment: Alignment.centerLeft,
          child: _AlignmentStatusPill(
            status: widget.item.alignmentStatus,
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(alignmentStatus: value)),
          ),
        );
      case _StakeholderAlignmentColumn.keyInterest:
        return Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<String>(
            value: widget.item.keyInterest.isEmpty ||
                    !_keyInterests.contains(widget.item.keyInterest)
                ? null
                : widget.item.keyInterest,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Select interest', style: TextStyle(fontSize: 13)),
            items: _keyInterests.map((interest) {
              return DropdownMenuItem<String>(
                value: interest,
                child: Text(interest, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateItem(widget.item.copyWith(keyInterest: value));
              }
            },
          ),
        );
      case _StakeholderAlignmentColumn.feedbackSummary:
        return Align(
          alignment: Alignment.centerLeft,
          child: InlineEditableText(
            value: widget.item.feedbackSummary,
            hint: 'Enter feedback (prose, no bullets)',
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(feedbackSummary: value)),
            textAlign: TextAlign.left,
            maxLines: 2,
          ),
        );
      case _StakeholderAlignmentColumn.lastEngagementDate:
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.item.lastEngagementDate != null
                    ? DateFormat('MMM dd, yyyy')
                        .format(widget.item.lastEngagementDate!)
                    : 'Select date',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.item.lastEngagementDate != null
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        );
      case _StakeholderAlignmentColumn.actions:
        return Align(
          alignment: Alignment.centerLeft,
          child: MouseRegion(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.undo,
                      size: 16, color: Color(0xFF64748B)),
                  onPressed: _previousState != null ? _undo : null,
                  tooltip: 'Undo',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: _isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome,
                          size: 16, color: Color(0xFF64748B)),
                  onPressed:
                      _isRegenerating ? null : _regenerateEngagementStrategy,
                  tooltip: 'Regenerate Engagement Strategy',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteItem(widget.item),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.item.lastEngagementDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _updateItem(widget.item.copyWith(lastEngagementDate: picked));
    }
  }

  void _updateItem(StakeholderAlignmentItem updated) {
    _previousState = widget.item;
    widget.onUpdated(updated);
    _debouncer.debounce(() async {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) return;

      try {
        final currentItems =
            await ExecutionPhaseService.loadStakeholderAlignmentItems(
          projectId: projectId,
        );
        final index = currentItems.indexWhere((i) => i.id == updated.id);
        if (index >= 0) {
          currentItems[index] = updated;
        } else {
          currentItems.add(updated);
        }
        await ExecutionPhaseService.saveStakeholderAlignmentItems(
          projectId: projectId,
          items: currentItems,
        );
      } catch (e) {
        debugPrint('Error auto-saving stakeholder alignment item: $e');
      }
    });
  }

  Future<void> _regenerateEngagementStrategy() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) {
        setState(() => _isRegenerating = false);
        return;
      }

      // Build context
      final projectData = provider?.projectData;
      if (projectData == null) {
        setState(() => _isRegenerating = false);
        return;
      }
      final projectContext = ProjectDataHelper.buildExecutivePlanContext(
        projectData,
      );

      // Generate engagement strategy
      final openAiService = OpenAiServiceSecure();
      final strategy = await openAiService.generateEngagementStrategy(
        context: projectContext,
        stakeholderName: widget.item.stakeholderName,
        stakeholderRole: widget.item.stakeholderRole,
        keyInterest: widget.item.keyInterest,
        alignmentStatus: widget.item.alignmentStatus,
        feedbackSummary: widget.item.feedbackSummary,
      );

      if (strategy.isNotEmpty && mounted) {
        _updateItem(widget.item.copyWith(engagementStrategy: strategy));
      }
    } catch (e) {
      debugPrint('Error regenerating engagement strategy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate engagement strategy: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  void _undo() {
    if (_previousState != null) {
      _updateItem(_previousState!);
      _previousState = null;
    }
  }

  Future<void> _deleteItem(StakeholderAlignmentItem item) async {
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;
    if (projectId == null || projectId.isEmpty) return;

    // Save state for undo
    final previousItems =
        await ExecutionPhaseService.loadStakeholderAlignmentItems(
      projectId: projectId,
    );

    // Remove item
    widget.onDeleted(item);

    // Save changes
    try {
      final currentItems =
          await ExecutionPhaseService.loadStakeholderAlignmentItems(
        projectId: projectId,
      );
      currentItems.removeWhere((i) => i.id == item.id);
      await ExecutionPhaseService.saveStakeholderAlignmentItems(
        projectId: projectId,
        items: currentItems,
      );
    } catch (e) {
      debugPrint('Error deleting stakeholder alignment item: $e');
    }

    // Show undo snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stakeholder deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // Restore item
              previousItems.add(item);
              widget.onUpdated(item);
              try {
                await ExecutionPhaseService.saveStakeholderAlignmentItems(
                  projectId: projectId,
                  items: previousItems,
                );
              } catch (e) {
                debugPrint('Error undoing delete: $e');
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _AlignmentStatusPill extends StatelessWidget {
  const _AlignmentStatusPill({
    required this.status,
    required this.onChanged,
  });

  final String status;
  final ValueChanged<String> onChanged;

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Aligned':
        return const Color(0xFF10B981); // Green
      case 'Neutral':
        return const Color(0xFF9CA3AF); // Grey
      case 'Concerned':
        return const Color(0xFFF59E0B); // Yellow
      case 'Resistent':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Select Alignment Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['Aligned', 'Neutral', 'Concerned', 'Resistent']
                  .map((s) => ListTile(
                        title: Text(s),
                        selected: s == status,
                        onTap: () {
                          onChanged(s);
                          Navigator.of(dialogContext).pop();
                        },
                      ))
                  .toList(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _Debouncer {
  Timer? _timer;

  void debounce(VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 500)}) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}
