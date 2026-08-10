import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/kanban_config_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

class AgileTaskBoardScreen extends StatefulWidget {
  const AgileTaskBoardScreen({
    super.key,
    required this.initialTasks,
    required this.workflowColumns,
    required this.availableRoles,
  });

  final List<AgileTask> initialTasks;
  final List<String> workflowColumns;
  final List<String> availableRoles;

  @override
  State<AgileTaskBoardScreen> createState() => _AgileTaskBoardScreenState();
}

class _AgileTaskBoardScreenState extends State<AgileTaskBoardScreen> {
  late List<AgileTask> _tasks;
  late List<String> _workflowColumns;

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _workflowColumns =
        KanbanConfigService.alignStatusesToWorkflow(widget.workflowColumns);
    _tasks = widget.initialTasks
        .map((task) => task.copyWith(
              status: KanbanConfigService.coerceTaskStatus(
                  task.status, _workflowColumns),
            ))
        .toList();
  }

  Future<void> _persistTasks() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;
    await ExecutionPhaseService.saveAgileTasks(
        projectId: projectId, tasks: _tasks);
  }

  List<AgileTask> _tasksForColumn(String column) {
    return _tasks
        .where((task) =>
            KanbanConfigService.coerceTaskStatus(
                task.status, _workflowColumns) ==
            column)
        .toList();
  }

  void _moveTask(AgileTask task, String targetColumn) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(status: targetColumn);
      }
    });
    _persistTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            PlanningPhaseHeader(
              title: 'Agile Task Board',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operational Kanban Board',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Drag tasks between workflow stages to update their status in real time.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _workflowColumns.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final column = _workflowColumns[index];
                          final tasks = _tasksForColumn(column);
                          return _BoardColumn(
                            title: column,
                            tasks: tasks,
                            onAccept: (task) => _moveTask(task, column),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.tasks,
    required this.onAccept,
  });

  final String title;
  final List<AgileTask> tasks;
  final ValueChanged<AgileTask> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<AgileTask>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return Container(
          width: 300,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isActive ? const Color(0xFFD97706) : const Color(0xFFE5E7EB),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text('${tasks.length}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'Drop tasks here',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _BoardTaskCard(task: tasks[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BoardTaskCard extends StatelessWidget {
  const _BoardTaskCard({required this.task});

  final AgileTask task;

  @override
  Widget build(BuildContext context) {
    return Draggable<AgileTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: _taskCardBody(task, dragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _taskCardBody(task, dragging: false),
      ),
      child: _taskCardBody(task, dragging: false),
    );
  }

  Widget _taskCardBody(AgileTask task, {required bool dragging}) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.userStory.isEmpty ? 'Untitled task' : task.userStory,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            task.assignedRole.isEmpty ? 'Unassigned' : task.assignedRole,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            '${task.storyPoints} pts • ${task.priority}',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
