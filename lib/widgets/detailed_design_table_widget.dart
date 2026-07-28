import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_component.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

/// World-class Design Specification table with inline editing, CRUD actions,
/// and AI specification generation. Columns conform to IEEE 1016 and
/// industry-standard design specification practices for waterfall, hybrid,
/// and agile methodologies.
class DetailedDesignTableWidget extends StatelessWidget {
  const DetailedDesignTableWidget({
    super.key,
    required this.components,
    required this.onUpdated,
    required this.onDeleted,
    this.methodology = 'Hybrid',
  });

  final List<DesignComponent> components;
  final ValueChanged<DesignComponent> onUpdated;
  final ValueChanged<DesignComponent> onDeleted;
  final String methodology;

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) {
      return buildNduTableEmptyState(
        context,
        message:
            'No design specifications added yet. Click + Add Specification to define your first design element.',
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
            minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 1200,
            maxHeight: 560,
            child: buildNduDataTable(
              context: context,
              columnSpacing: 16,
              horizontalMargin: 16,
              headingRowHeight: 52,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 120,
              columns: const [
                DataColumn(
                  label: Center(
                    child: Text('Spec ID',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Design Element',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Type',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Specification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Priority',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Phase',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Owner',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Traceability',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Status',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Actions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ),
                ),
              ],
              rows: components.map((component) {
                return DataRow(
                  cells: [
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'specId',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'name',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'type',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'specification',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'priority',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'phase',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'owner',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'traceability',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'status',
                      methodology: methodology,
                    )),
                    DataCell(_DesignSpecRowWidget(
                      component: component,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                      column: 'actions',
                      methodology: methodology,
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

class _DesignSpecRowWidget extends StatefulWidget {
  const _DesignSpecRowWidget({
    required this.component,
    required this.onUpdated,
    required this.onDeleted,
    required this.column,
    required this.methodology,
  });

  final DesignComponent component;
  final ValueChanged<DesignComponent> onUpdated;
  final ValueChanged<DesignComponent> onDeleted;
  final String column;
  final String methodology;

  @override
  State<_DesignSpecRowWidget> createState() => _DesignSpecRowWidgetState();
}

class _DesignSpecRowWidgetState extends State<_DesignSpecRowWidget> {
  late DesignComponent _component;
  DesignComponent? _previousState;
  bool _isHovering = false;
  bool _isRegenerating = false;
  final _Debouncer _saveDebouncer = _Debouncer();

  @override
  void initState() {
    super.initState();
    _component = widget.component;
  }

  @override
  void didUpdateWidget(_DesignSpecRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component != widget.component) {
      _component = widget.component;
    }
  }

  @override
  void dispose() {
    _saveDebouncer.dispose();
    super.dispose();
  }

  Future<void> _updateComponent(DesignComponent updated) async {
    setState(() {
      _previousState = _component;
      _component = updated;
    });

    _saveDebouncer.run(() async {
      final projectId = _getProjectId();
      if (projectId == null) return;

      try {
        final components = await ExecutionPhaseService.loadDesignComponents(
          projectId: projectId,
        );
        final index = components.indexWhere((c) => c.id == updated.id);
        if (index != -1) {
          components[index] = updated;
        } else {
          components.add(updated);
        }
        await ExecutionPhaseService.saveDesignComponents(
          projectId: projectId,
          components: components,
        );
      } catch (e) {
        debugPrint('Error saving design component: $e');
      }
    });

    widget.onUpdated(updated);
  }

  String? _getProjectId() {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      return provider?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _undo() async {
    if (_previousState != null) {
      final previous = _previousState!;
      setState(() {
        _component = previous;
        _previousState = null;
      });
      await _updateComponent(previous);
    }
  }

  Future<void> _regenerateSpecification() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) return;

      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        provider.projectData,
        sectionLabel: 'Design Specifications',
      );

      final ai = OpenAiServiceSecure();
      final specifications = await ai.generateDesignSpecification(
        context: contextText,
        componentName: _component.componentName,
        category: _component.specificationType,
      );

      final updated = _component.copyWith(
        specificationDetails: specifications,
      );

      await _updateComponent(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Specification regenerated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating specification: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _deleteComponent() async {
    final deleted = _component;
    final projectId = _getProjectId();

    try {
      if (projectId != null) {
        final components = await ExecutionPhaseService.loadDesignComponents(
          projectId: projectId,
        );
        components.removeWhere((c) => c.id == deleted.id);
        await ExecutionPhaseService.saveDesignComponents(
          projectId: projectId,
          components: components,
        );
      }
    } catch (e) {
      debugPrint('Error deleting design component: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting component: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    widget.onDeleted(deleted);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Specification deleted'),
              Spacer(),
            ],
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              try {
                final projectId = _getProjectId();
                if (projectId != null) {
                  final components =
                      await ExecutionPhaseService.loadDesignComponents(
                    projectId: projectId,
                  );
                  components.add(deleted);
                  await ExecutionPhaseService.saveDesignComponents(
                    projectId: projectId,
                    components: components,
                  );
                  widget.onUpdated(deleted);
                }
              } catch (e) {
                debugPrint('Error restoring component: $e');
              }
            },
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF111827),
        ),
      );
    }
  }

  // ── Status color mapping ──
  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'draft' => const Color(0xFF9CA3AF),
      'in review' => const Color(0xFF0EA5E9),
      'reviewed' => const Color(0xFF6366F1),
      'approved' => const Color(0xFF10B981),
      'baseline' => const Color(0xFF2563EB),
      'superseded' => const Color(0xFFEF4444),
      _ => const Color(0xFF9CA3AF),
    };
  }

  // ── Priority color mapping ──
  Color _getPriorityColor(String priority) {
    return switch (priority.toLowerCase()) {
      'must have' => const Color(0xFFDC2626),
      'should have' => const Color(0xFF2563EB),
      'could have' => const Color(0xFFD97706),
      "won't have" => const Color(0xFF6B7280),
      _ => const Color(0xFF6B7280),
    };
  }

  // ── Spec type color mapping ──
  Color _getSpecTypeColor(String type) {
    return switch (type.toLowerCase()) {
      'architecture' => const Color(0xFF7C3AED),
      'interface' => const Color(0xFF2563EB),
      'data' => const Color(0xFF0891B2),
      'component' => const Color(0xFF059669),
      'security' => const Color(0xFFDC2626),
      'nfr' => const Color(0xFFD97706),
      'infrastructure' => const Color(0xFF475569),
      'ui/ux' => const Color(0xFFEC4899),
      _ => const Color(0xFF6B7280),
    };
  }

  DesignComponent _createUpdatedComponent({
    String? specId,
    String? componentName,
    String? specificationType,
    String? category,
    String? specificationDetails,
    String? integrationPoint,
    String? priority,
    String? methodologyPhase,
    String? owner,
    String? traceability,
    String? status,
    String? designNotes,
  }) {
    return _component.copyWith(
      specId: specId,
      componentName: componentName,
      specificationType: specificationType,
      category: category ?? specificationType,
      specificationDetails: specificationDetails,
      integrationPoint: integrationPoint,
      priority: priority,
      methodologyPhase: methodologyPhase,
      owner: owner,
      traceability: traceability,
      status: status,
      designNotes: designNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.column) {
      case 'specId':
        return Center(
          child: InlineEditableText(
            value: _component.specId,
            isListField: false,
            onChanged: (v) =>
                _updateComponent(_createUpdatedComponent(specId: v)),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _getSpecTypeColor(_component.specificationType),
            ),
            textAlign: TextAlign.center,
          ),
        );
      case 'name':
        return Center(
          child: InlineEditableText(
            value: _component.componentName,
            isListField: false,
            onChanged: (v) =>
                _updateComponent(_createUpdatedComponent(componentName: v)),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            textAlign: TextAlign.center,
          ),
        );
      case 'type':
        final typeColor = _getSpecTypeColor(_component.specificationType);
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<String>(
              value: DesignComponent.specificationTypes.contains(
                      _component.specificationType)
                  ? _component.specificationType
                  : 'Component',
              isDense: true,
              underline: const SizedBox(),
              iconSize: 14,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: typeColor,
              ),
              items: DesignComponent.specificationTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _updateComponent(
                      _createUpdatedComponent(specificationType: v, category: v));
                }
              },
            ),
          ),
        );
      case 'specification':
        return SizedBox(
          width: 180,
          child: InlineEditableText(
            value: _component.specificationDetails,
            isListField: true,
            onChanged: (v) => _updateComponent(
                _createUpdatedComponent(specificationDetails: v)),
            style: const TextStyle(fontSize: 10, color: Color(0xFF374151)),
            textAlign: TextAlign.left,
          ),
        );
      case 'priority':
        final priorityColor = _getPriorityColor(_component.priority);
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<String>(
              value: DesignComponent.priorities.contains(_component.priority)
                  ? _component.priority
                  : 'Should Have',
              isDense: true,
              underline: const SizedBox(),
              iconSize: 14,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: priorityColor,
              ),
              items: DesignComponent.priorities
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _updateComponent(_createUpdatedComponent(priority: v));
                }
              },
            ),
          ),
        );
      case 'phase':
        return Center(
          child: DropdownButton<String>(
            value: _component.methodologyPhase.isNotEmpty
                ? _component.methodologyPhase
                : 'Baseline',
            isDense: true,
            underline: const SizedBox(),
            iconSize: 14,
            style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
            items: _getPhaseOptions()
                .map((phase) => DropdownMenuItem(
                      value: phase,
                      child: Text(phase),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _updateComponent(
                    _createUpdatedComponent(methodologyPhase: v));
              }
            },
          ),
        );
      case 'owner':
        return Center(
          child: DropdownButton<String>(
            value: _component.owner.isNotEmpty ? _component.owner : 'Engineering',
            isDense: true,
            underline: const SizedBox(),
            iconSize: 14,
            style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
            items: DesignComponent.ownerRoles
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _updateComponent(_createUpdatedComponent(owner: v));
              }
            },
          ),
        );
      case 'traceability':
        return Center(
          child: InlineEditableText(
            value: _component.traceability,
            isListField: false,
            onChanged: (v) =>
                _updateComponent(_createUpdatedComponent(traceability: v)),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB)),
            textAlign: TextAlign.center,
          ),
        );
      case 'status':
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _getStatusColor(_component.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: DesignComponent.statuses.contains(_component.status)
                  ? _component.status
                  : 'Draft',
              isDense: true,
              underline: const SizedBox(),
              iconSize: 14,
              items: DesignComponent.statuses
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(status))),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _updateComponent(_createUpdatedComponent(status: v));
                }
              },
            ),
          ),
        );
      case 'actions':
        return MouseRegion(
          onEnter: (_) =>
              Future.microtask(() => setState(() => _isHovering = true)),
          onExit: (_) =>
              Future.microtask(() => setState(() => _isHovering = false)),
          child: Center(
            child: _isHovering
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_previousState != null)
                        IconButton(
                          icon: const Icon(Icons.undo,
                              size: 14, color: Color(0xFF64748B)),
                          onPressed: _undo,
                          tooltip: 'Undo',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      IconButton(
                        icon: _isRegenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7C3AED),
                                ),
                              )
                            : const Icon(Icons.auto_awesome,
                                size: 14, color: Color(0xFF7C3AED)),
                        onPressed:
                            _isRegenerating ? null : _regenerateSpecification,
                        tooltip: 'AI Regenerate',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 14, color: Color(0xFF9CA3AF)),
                        onPressed: _deleteComponent,
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  )
                : const SizedBox(width: 36),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  List<String> _getPhaseOptions() {
    switch (widget.methodology.toLowerCase()) {
      case 'waterfall':
        return DesignComponent.waterfallPhases;
      case 'agile':
        return DesignComponent.agilePhases;
      case 'hybrid':
      default:
        return DesignComponent.hybridPhases;
    }
  }
}

class _Debouncer {
  Timer? _timer;

  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}
