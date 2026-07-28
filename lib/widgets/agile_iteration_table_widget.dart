import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

/// Custom Agile Iteration Table with inline editing, CRUD actions, and AI capabilities
class AgileIterationTableWidget extends StatelessWidget {
  const AgileIterationTableWidget({
    super.key,
    required this.tasks,
    required this.onUpdated,
    required this.onDeleted,
    required this.availableRoles,
  });

  final List<AgileTask> tasks;
  final ValueChanged<AgileTask> onUpdated;
  final ValueChanged<AgileTask> onDeleted;
  final List<String> availableRoles;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return buildNduTableEmptyState(
        context,
        message: 'No tasks added yet. Click + Add to get started.',
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
                    child: Text('User Story/Task',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Assigned Role',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Story Points',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Priority',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text('Status',
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
              rows: tasks.map((task) {
                return DataRow(
                  cells: [
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.userStory,
                      availableRoles: availableRoles,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.assignedRole,
                      availableRoles: availableRoles,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.storyPoints,
                      availableRoles: availableRoles,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.priority,
                      availableRoles: availableRoles,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.status,
                      availableRoles: availableRoles,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                    DataCell(_AgileTaskRowWidget(
                      task: task,
                      column: _AgileTaskColumn.actions,
                      availableRoles: availableRoles,
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

enum _AgileTaskColumn {
  userStory,
  assignedRole,
  storyPoints,
  priority,
  status,
  actions,
}

class _AgileTaskRowWidget extends StatefulWidget {
  const _AgileTaskRowWidget({
    required this.task,
    required this.column,
    required this.availableRoles,
    required this.onUpdated,
    required this.onDeleted,
  });

  final AgileTask task;
  final _AgileTaskColumn column;
  final List<String> availableRoles;
  final ValueChanged<AgileTask> onUpdated;
  final ValueChanged<AgileTask> onDeleted;

  @override
  State<_AgileTaskRowWidget> createState() => _AgileTaskRowWidgetState();
}

class _AgileTaskRowWidgetState extends State<_AgileTaskRowWidget> {
  AgileTask? _previousState;
  AgileTask? _redoState;
  final _Debouncer _debouncer = _Debouncer();
  bool _isRegenerating = false;

  @override
  Widget build(BuildContext context) {
    switch (widget.column) {
      case _AgileTaskColumn.userStory:
        return Center(
          child: InlineEditableText(
            value: widget.task.userStory,
            hint: 'Enter user story',
            onChanged: (value) =>
                _updateTask(widget.task.copyWith(userStory: value)),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        );
      case _AgileTaskColumn.assignedRole:
        return Center(
          child: DropdownButton<String>(
            value: widget.task.assignedRole.isEmpty ||
                    !widget.availableRoles.contains(widget.task.assignedRole)
                ? null
                : widget.task.assignedRole,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Select role', style: TextStyle(fontSize: 13)),
            items: widget.availableRoles.map((role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateTask(widget.task.copyWith(assignedRole: value));
              }
            },
          ),
        );
      case _AgileTaskColumn.storyPoints:
        return Center(
          child: DropdownButton<int>(
            value: widget.task.storyPoints,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [1, 2, 3, 5, 8].map((points) {
              return DropdownMenuItem<int>(
                value: points,
                child: Text('$points', style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateTask(widget.task.copyWith(storyPoints: value));
              }
            },
          ),
        );
      case _AgileTaskColumn.priority:
        return Center(
          child: _PriorityPill(
            priority: widget.task.priority,
            onChanged: (value) =>
                _updateTask(widget.task.copyWith(priority: value)),
          ),
        );
      case _AgileTaskColumn.status:
        return Center(
          child: _StatusPill(
            status: widget.task.status,
            onChanged: (value) =>
                _updateTask(widget.task.copyWith(status: value)),
          ),
        );
      case _AgileTaskColumn.actions:
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
                icon:
                    const Icon(Icons.redo, size: 16, color: Color(0xFF64748B)),
                onPressed: _redoState != null ? _redo : null,
                tooltip: 'Redo',
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
                onPressed: _isRegenerating ? null : _regenerateTaskDescription,
                tooltip: 'Regenerate Task Description',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFEF4444)),
                onPressed: () => _deleteTask(widget.task),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
    }
  }

  void _updateTask(AgileTask updated) {
    _previousState ??= widget.task;
    _redoState = null;
    widget.onUpdated(updated);
    _debouncer.run(() async {
      final projectId =
          ProjectDataInherited.maybeOf(context)?.projectData.projectId;
      if (projectId == null) return;
      try {
        final tasks =
            await ExecutionPhaseService.loadAgileTasks(projectId: projectId);
        final index = tasks.indexWhere((t) => t.id == updated.id);
        if (index != -1) {
          tasks[index] = updated;
        } else {
          tasks.add(updated);
        }
        await ExecutionPhaseService.saveAgileTasks(
          projectId: projectId,
          tasks: tasks,
        );
      } catch (e) {
        debugPrint('Error saving agile task: $e');
      }
    });
  }

  Future<void> _regenerateTaskDescription() async {
    setState(() => _isRegenerating = true);
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) return;

      // Load design components for context
      final projectId = provider.projectData.projectId;
      if (projectId == null || projectId.isEmpty) return;

      final designComponents = await ExecutionPhaseService.loadDesignComponents(
        projectId: projectId,
      );
      final componentNames =
          designComponents.map((c) => c.componentName).toList();

      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        provider.projectData,
        sectionLabel: 'Agile Development Iterations',
      );

      final ai = OpenAiServiceSecure();
      final breakdown = await ai.breakDownUserStory(
        context: contextText,
        userStory: widget.task.userStory,
        designComponents: componentNames,
      );

      if (mounted) {
        _updateTask(widget.task.copyWith(
          taskDescription: breakdown,
        ));
      }
    } catch (e) {
      debugPrint('Error regenerating task description: $e');
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _undo() async {
    if (_previousState != null) {
      final current = widget.task;
      _updateTask(_previousState!);
      _redoState = current;
      _previousState = null;
    }
  }

  Future<void> _redo() async {
    if (_redoState != null) {
      final current = widget.task;
      _updateTask(_redoState!);
      _previousState = current;
      _redoState = null;
    }
  }

  Future<void> _deleteTask(AgileTask task) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Task',
      itemLabel: task.userStory,
    );
    if (!confirmed) return;
    final projectId =
        ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    if (projectId == null) return;

    widget.onDeleted(task);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              final tasks = await ExecutionPhaseService.loadAgileTasks(
                  projectId: projectId);
              tasks.add(task);
              await ExecutionPhaseService.saveAgileTasks(
                projectId: projectId,
                tasks: tasks,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task restored')),
                );
              }
            } catch (e) {
              debugPrint('Error undoing delete: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error restoring task: $e')),
                );
              }
            }
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    // Actually delete after delay
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final tasks =
            await ExecutionPhaseService.loadAgileTasks(projectId: projectId);
        tasks.removeWhere((t) => t.id == task.id);
        await ExecutionPhaseService.saveAgileTasks(
          projectId: projectId,
          tasks: tasks,
        );
      } catch (e) {
        debugPrint('Error deleting task: $e');
      }
    });
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority, required this.onChanged});

  final String priority;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: priority,
      isExpanded: true,
      underline: const SizedBox(),
      items: const ['Critical', 'High', 'Medium', 'Low'].map((p) {
        return DropdownMenuItem<String>(
          value: p,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _PriorityPill._getStaticColor(p),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              p,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  static Color _getStaticColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFFFBBF24);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.onChanged});

  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: status,
      isExpanded: true,
      underline: const SizedBox(),
      items: const ['To-Do', 'In-Progress', 'Testing', 'Done'].map((s) {
        return DropdownMenuItem<String>(
          value: s,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _StatusPill._getStaticColor(s),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  static Color _getStaticColor(String status) {
    switch (status.toLowerCase()) {
      case 'to-do':
        return const Color(0xFF6B7280);
      case 'in-progress':
        return const Color(0xFFFBBF24);
      case 'testing':
        return const Color(0xFFF59E0B);
      case 'done':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _Debouncer {
  Timer? _timer;
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), action);
  }

  void dispose() => _timer?.cancel();
}
