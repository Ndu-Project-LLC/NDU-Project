import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_activity.dart';

/// Header affordance for active project activities that have a named owner.
/// The list is intentionally derived from the shared project activity stream,
/// so every phase header shows the same outstanding assignments.
class ProjectActivityHeaderAction extends StatelessWidget {
  const ProjectActivityHeaderAction({
    super.key,
    required this.activities,
    required this.onOpenActivityLog,
    this.compact = false,
  });

  final List<ProjectActivity> activities;
  final VoidCallback onOpenActivityLog;
  final bool compact;

  List<ProjectActivity> get _outstanding {
    final tasks = activities
        .where((activity) =>
            activity.status == ProjectActivityStatus.pending &&
            (activity.assignedTo ?? '').trim().isNotEmpty)
        .toList();
    tasks.sort((a, b) {
      final aDue = a.dueDate.trim();
      final bDue = b.dueDate.trim();
      if (aDue.isEmpty && bDue.isNotEmpty) return 1;
      if (aDue.isNotEmpty && bDue.isEmpty) return -1;
      return aDue.compareTo(bDue);
    });
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final count = _outstanding.length;
    return Tooltip(
      message: count == 0
          ? 'No assigned outstanding tasks'
          : '$count assigned outstanding ${count == 1 ? 'task' : 'tasks'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOutstandingTasks(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD873)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.assignment_late_outlined,
                    size: 19,
                    color: Color(0xFFB45309),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB91C1C),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(
                  'Tasks ($count)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOutstandingTasks(BuildContext context) async {
    final tasks = _outstanding;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Outstanding tasks (${tasks.length})'),
        content: SizedBox(
          width: 520,
          child: tasks.isEmpty
              ? const Text('There are no assigned outstanding tasks.')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final assignee = task.assignedTo!.trim();
                      final dueDate = task.dueDate.trim();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF1C2),
                          child: Icon(
                            Icons.person_outline,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        title: Text(task.title),
                        subtitle: Text([
                          'Assigned to: $assignee',
                          if (dueDate.isNotEmpty) 'Due: $dueDate',
                        ].join(' · ')),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onOpenActivityLog();
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open activity log'),
          ),
        ],
      ),
    );
  }
}
