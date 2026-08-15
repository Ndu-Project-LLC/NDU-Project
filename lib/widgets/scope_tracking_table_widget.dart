import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/scope_tracking_item.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

/// Column flex weights — proportional widths that distribute content evenly
/// across the available table width. The exact pixel width of each column is
/// derived from these weights at runtime via [FlexColumnWidth] inside a
/// [Table] widget, so the table fills its container with no orphaned wide
/// column and no squished right-edge cluster.
const List<double> _kScopeColumnFlex = [
  2.6, // Scope Item / Deliverable
  1.0, // Status
  1.2, // Owner
  1.2, // Verification
  2.0, // Verification Steps
  1.8, // Tracking Notes
  1.1, // Actions
];

const List<String> _kScopeColumnLabels = [
  'Scope Item/Deliverable',
  'Status',
  'Owner',
  'Verification',
  'Verification Steps',
  'Tracking Notes',
  'Actions',
];

/// Minimum column widths (in dp) — used as a floor so cells never collapse
/// below their content's natural fit. When the available container width is
/// less than the sum of these minima, horizontal scrolling kicks in.
const List<double> _kScopeColumnMinWidth = [
  180, // Scope Item / Deliverable
  96,  // Status
  120, // Owner
  120, // Verification
  160, // Verification Steps
  140, // Tracking Notes
  112, // Actions
];

/// Custom Scope Tracking Table with inline editing, CRUD actions, and AI capabilities.
///
/// Uses [Table] + [FlexColumnWidth] (rather than [DataTable]) so column widths
/// are distributed proportionally across the full available width. This avoids
/// the default `DataTable` behaviour where one column (usually the last)
/// absorbs all leftover horizontal space — producing the uneven, squished-right
/// layout previously visible on this table.
class ScopeTrackingTableWidget extends StatelessWidget {
  const ScopeTrackingTableWidget({
    super.key,
    required this.items,
    required this.onUpdated,
    required this.onDeleted,
    required this.availableRoles,
  });

  final List<ScopeTrackingItem> items;
  final ValueChanged<ScopeTrackingItem> onUpdated;
  final ValueChanged<ScopeTrackingItem> onDeleted;
  final List<String> availableRoles;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return buildNduTableEmptyState(
        context,
        message: 'No items added yet. Click + Add to get started.',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FC);
    final dividerColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final headingStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      letterSpacing: 0.2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth > 0 ? constraints.maxWidth : 1200.0;
        final minTotalWidth =
            _kScopeColumnMinWidth.reduce((a, b) => a + b);
        final useHorizontalScroll = availableWidth < minTotalWidth;
        final tableWidth =
            useHorizontalScroll ? minTotalWidth : availableWidth;

        final columnWidths = <int, TableColumnWidth>{
          for (var i = 0; i < _kScopeColumnFlex.length; i++)
            i: useHorizontalScroll
                ? FixedColumnWidth(_kScopeColumnMinWidth[i])
                : FlexColumnWidth(_kScopeColumnFlex[i]),
        };

        final headerRow = TableRow(
          decoration: BoxDecoration(
            color: headingColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          children: [
            for (var i = 0; i < _kScopeColumnLabels.length; i++)
              _ScopeHeaderCell(
                label: _kScopeColumnLabels[i],
                style: headingStyle,
              ),
          ],
        );

        final dataRows = items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isOdd = index.isOdd;
          final rowColor = isDark
              ? (isOdd ? const Color(0xFF10151D) : const Color(0xFF151922))
              : (isOdd ? const Color(0xFFFAFCFF) : Colors.white);
          return TableRow(
            decoration: BoxDecoration(color: rowColor),
            children: [
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.scopeItem,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.implementationStatus,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.owner,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.verificationMethod,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.verificationSteps,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.trackingNotes,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
              _ScopeTrackingRowWidget(
                item: item,
                column: _ScopeTrackingColumn.actions,
                availableRoles: availableRoles,
                onUpdated: onUpdated,
                onDeleted: onDeleted,
              ),
            ],
          );
        }).toList();

        final table = Table(
          columnWidths: columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            top: BorderSide(color: dividerColor, width: 0.8),
            bottom: BorderSide(color: dividerColor, width: 0.8),
            horizontalInside:
                BorderSide(color: dividerColor.withOpacity(0.6), width: 0.6),
          ),
          children: [headerRow, ...dataRows],
        );

        // Table needs a bounded width so FlexColumnWidth can compute. We
        // wrap it in a SizedBox with the resolved width. If the available
        // width is below the minimum threshold we keep the wider SizedBox and
        // wrap it in a horizontal scroll view so the user can pan.
        final sizedTable = SizedBox(
          width: tableWidth,
          child: table,
        );

        Widget tableHost = sizedTable;
        if (useHorizontalScroll) {
          tableHost = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: sizedTable,
          );
        }

        // Cap vertical height and enable vertical scroll when rows exceed the
        // visible viewport. Mirrors the prior `maxHeight: 560` behaviour.
        tableHost = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: tableHost,
            ),
          ),
        );

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: tableHost,
          ),
        );
      },
    );
  }
}

/// Header cell — left-aligned, padded, single-line with ellipsis fallback so
/// longer labels (e.g. "Verification Steps") never wrap awkwardly.
class _ScopeHeaderCell extends StatelessWidget {
  const _ScopeHeaderCell({required this.label, required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

enum _ScopeTrackingColumn {
  scopeItem,
  implementationStatus,
  owner,
  verificationMethod,
  verificationSteps,
  trackingNotes,
  actions,
}

class _ScopeTrackingRowWidget extends StatefulWidget {
  const _ScopeTrackingRowWidget({
    required this.item,
    required this.column,
    required this.availableRoles,
    required this.onUpdated,
    required this.onDeleted,
  });

  final ScopeTrackingItem item;
  final _ScopeTrackingColumn column;
  final List<String> availableRoles;
  final ValueChanged<ScopeTrackingItem> onUpdated;
  final ValueChanged<ScopeTrackingItem> onDeleted;

  @override
  State<_ScopeTrackingRowWidget> createState() =>
      _ScopeTrackingRowWidgetState();
}

class _ScopeTrackingRowWidgetState extends State<_ScopeTrackingRowWidget> {
  ScopeTrackingItem? _previousState;
  final _Debouncer _debouncer = _Debouncer();
  bool _isRegenerating = false;

  static const List<String> _verificationMethods = [
    'Testing',
    'UAT',
    'Stakeholder Review',
  ];

  @override
  Widget build(BuildContext context) {
    switch (widget.column) {
      case _ScopeTrackingColumn.scopeItem:
        return Center(
          child: InlineEditableText(
            value: widget.item.scopeItem,
            hint: 'Enter scope item',
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(scopeItem: value)),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        );
      case _ScopeTrackingColumn.implementationStatus:
        return Center(
          child: _StatusPill(
            status: widget.item.implementationStatus,
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(implementationStatus: value)),
          ),
        );
      case _ScopeTrackingColumn.owner:
        return Center(
          child: DropdownButton<String>(
            value: widget.item.owner.isEmpty ||
                    !widget.availableRoles.contains(widget.item.owner)
                ? null
                : widget.item.owner,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Select owner', style: TextStyle(fontSize: 13)),
            items: widget.availableRoles.map((role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateItem(widget.item.copyWith(owner: value));
              }
            },
          ),
        );
      case _ScopeTrackingColumn.verificationMethod:
        return Center(
          child: DropdownButton<String>(
            value: widget.item.verificationMethod.isEmpty ||
                    !_verificationMethods
                        .contains(widget.item.verificationMethod)
                ? null
                : widget.item.verificationMethod,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Select method', style: TextStyle(fontSize: 13)),
            items: _verificationMethods.map((method) {
              return DropdownMenuItem<String>(
                value: method,
                child: Text(method, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateItem(widget.item.copyWith(verificationMethod: value));
              }
            },
          ),
        );
      case _ScopeTrackingColumn.verificationSteps:
        return Center(
          child: _VerificationStepsCell(
            value: widget.item.verificationSteps,
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(verificationSteps: value)),
            onRegenerate: _regenerateVerificationSteps,
            isRegenerating: _isRegenerating,
          ),
        );
      case _ScopeTrackingColumn.trackingNotes:
        return Center(
          child: InlineEditableText(
            value: widget.item.trackingNotes,
            hint: 'Enter tracking notes',
            onChanged: (value) =>
                _updateItem(widget.item.copyWith(trackingNotes: value)),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        );
      case _ScopeTrackingColumn.actions:
        return MouseRegion(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.undo, size: 16, color: Color(0xFF64748B)),
                onPressed: _previousState != null ? _undo : null,
                tooltip: 'Undo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                    _isRegenerating ? null : _regenerateVerificationSteps,
                tooltip: 'Regenerate Verification Steps',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFEF4444)),
                onPressed: () => _deleteItem(widget.item),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
    }
  }

  void _updateItem(ScopeTrackingItem updated) {
    _previousState = widget.item;
    widget.onUpdated(updated);
    _debouncer.debounce(() async {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) return;

      try {
        final currentItems = await ExecutionPhaseService.loadScopeTrackingItems(
          projectId: projectId,
        );
        final index = currentItems.indexWhere((i) => i.id == updated.id);
        if (index >= 0) {
          currentItems[index] = updated;
        } else {
          currentItems.add(updated);
        }
        await ExecutionPhaseService.saveScopeTrackingItems(
          projectId: projectId,
          items: currentItems,
        );
      } catch (e) {
        debugPrint('Error auto-saving scope tracking item: $e');
      }
    });
  }

  Future<void> _regenerateVerificationSteps() async {
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

      // Load design components
      final designComponents = await ExecutionPhaseService.loadDesignComponents(
        projectId: projectId,
      );
      final componentNames =
          designComponents.map((c) => c.componentName).toList();

      // Generate verification steps
      final openAiService = OpenAiServiceSecure();
      final steps = await openAiService.generateVerificationSteps(
        context: projectContext,
        scopeItem: widget.item.scopeItem,
        designComponents: componentNames,
      );

      if (steps.isNotEmpty && mounted) {
        _updateItem(widget.item.copyWith(verificationSteps: steps));
      }
    } catch (e) {
      debugPrint('Error regenerating verification steps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate verification steps: $e'),
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

  Future<void> _deleteItem(ScopeTrackingItem item) async {
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;
    if (projectId == null || projectId.isEmpty) return;

    // Save state for undo
    final previousItems = await ExecutionPhaseService.loadScopeTrackingItems(
      projectId: projectId,
    );

    // Remove item
    widget.onDeleted(item);

    // Save changes
    try {
      final currentItems = await ExecutionPhaseService.loadScopeTrackingItems(
        projectId: projectId,
      );
      currentItems.removeWhere((i) => i.id == item.id);
      await ExecutionPhaseService.saveScopeTrackingItems(
        projectId: projectId,
        items: currentItems,
      );
    } catch (e) {
      debugPrint('Error deleting scope tracking item: $e');
    }

    // Show undo snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scope item deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // Restore item
              previousItems.add(item);
              widget.onUpdated(item);
              try {
                await ExecutionPhaseService.saveScopeTrackingItems(
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.onChanged,
  });

  final String status;
  final ValueChanged<String> onChanged;

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Not Started':
        return const Color(0xFF9CA3AF); // Grey
      case 'In-Progress':
        return const Color(0xFFFFC812); // Blue
      case 'Verified':
        return const Color(0xFF10B981); // Green
      case 'Out-of-Scope':
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
            title: const Text('Select Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  ['Not Started', 'In-Progress', 'Verified', 'Out-of-Scope']
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

class _VerificationStepsCell extends StatefulWidget {
  const _VerificationStepsCell({
    required this.value,
    required this.onChanged,
    required this.onRegenerate,
    required this.isRegenerating,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onRegenerate;
  final bool isRegenerating;

  @override
  State<_VerificationStepsCell> createState() => _VerificationStepsCellState();
}

class _VerificationStepsCellState extends State<_VerificationStepsCell> {
  late AutoBulletTextController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = AutoBulletTextController(text: widget.value);
  }

  @override
  void didUpdateWidget(_VerificationStepsCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceTextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Enter verification steps (use "." bullets)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
              isDense: true,
            ),
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              widget.onChanged(value);
            },
            onSubmitted: (_) {
              setState(() => _isEditing = false);
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _isEditing = false);
                },
                child: const Text('Done', style: TextStyle(fontSize: 11)),
              ),
              if (widget.isRegenerating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  onPressed: widget.onRegenerate,
                  tooltip: 'Regenerate',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _isEditing = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: widget.value.isEmpty
            ? const Text(
                'Click to add verification steps',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              )
            : Text(
                widget.value,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
