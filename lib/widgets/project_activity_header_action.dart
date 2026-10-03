import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';

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

  /// Pushes the assigned tasks as a full screen-filling page instead of a
  /// dialog, so long assignment lists stay searchable and every row can hand
  /// off to the screen that owns the activity.
  Future<void> _showOutstandingTasks(BuildContext context) async {
    final outstandingCount = _outstanding.length;
    final assigned = activities
        .where((activity) => (activity.assignedTo ?? '').trim().isNotEmpty)
        .toList();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => _OutstandingTasksPage(
          tasks: assigned,
          outstandingCount: outstandingCount,
          onOpenActivityLog: () {
            Navigator.of(pageContext).pop();
            onOpenActivityLog();
          },
          onOpenSource: (url) {
            Navigator.of(pageContext).pop();
            context.push(url);
          },
        ),
      ),
    );
  }
}

/// Full-screen view of the assigned tasks.
///
/// The list is intentionally unconstrained in height: it fills the viewport
/// and scrolls, rather than living inside a dialog-sized box. Search plus the
/// status filter keep long assignment lists scannable, and each row deep-links
/// back to the screen that owns the activity.
class _OutstandingTasksPage extends StatefulWidget {
  const _OutstandingTasksPage({
    required this.tasks,
    required this.outstandingCount,
    required this.onOpenActivityLog,
    required this.onOpenSource,
  });

  /// Every activity with an assignee, in any status.
  final List<ProjectActivity> tasks;

  /// Number of pending assigned activities — what the header badge counts.
  final int outstandingCount;

  final VoidCallback onOpenActivityLog;

  /// Receives the go_router URL of the screen that owns the tapped activity.
  final ValueChanged<String> onOpenSource;

  @override
  State<_OutstandingTasksPage> createState() => _OutstandingTasksPageState();
}

class _OutstandingTasksPageState extends State<_OutstandingTasksPage> {
  static const Map<ProjectActivityStatus?, String> _statusFilters = {
    null: 'All',
    ProjectActivityStatus.pending: 'Pending',
    ProjectActivityStatus.acknowledged: 'Acknowledged',
    ProjectActivityStatus.implemented: 'Implemented',
    ProjectActivityStatus.rejected: 'Rejected',
    ProjectActivityStatus.deferred: 'Deferred',
  };

  final TextEditingController _searchController = TextEditingController();

  /// Null means "all statuses". Defaults to pending, which is exactly the
  /// outstanding set the header badge counts.
  ProjectActivityStatus? _status = ProjectActivityStatus.pending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProjectActivity> get _visibleTasks {
    final query = _searchController.text.trim().toLowerCase();
    return widget.tasks.where((task) {
      if (_status != null && task.status != _status) return false;
      if (query.isEmpty) return true;
      return [
        task.title,
        task.description,
        task.assignedTo ?? '',
        task.sourceSection,
        task.phase,
        task.discipline,
        task.role,
        task.dueDate,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  bool get _isFiltered =>
      _status != ProjectActivityStatus.pending ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() => _status = ProjectActivityStatus.pending);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _visibleTasks;
    return Scaffold(
      appBar: AppBar(
        title: Text('Outstanding tasks (${widget.outstandingCount})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Project Activity Log',
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenActivityLog();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            controller: _searchController,
            status: _status,
            statusLabels: _statusFilters,
            onSearchChanged: () => setState(() {}),
            onStatusChanged: (status) => setState(() => _status = status),
            resultLabel: tasks.length == widget.tasks.length
                ? '${tasks.length} assigned ${tasks.length == 1 ? 'task' : 'tasks'}'
                : '${tasks.length} of ${widget.tasks.length} assigned tasks',
          ),
          const Divider(height: 1),
          Expanded(child: _buildList(context, tasks)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: widget.onOpenActivityLog,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open activity log'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ProjectActivity> tasks) {
    if (widget.tasks.isEmpty) {
      return const _TaskListMessage(
        message: 'There are no assigned outstanding tasks.',
      );
    }
    if (tasks.isEmpty) {
      return _TaskListMessage(
        message: 'No tasks match the current filters.',
        actionLabel: _isFiltered ? 'Clear filters' : null,
        onAction: _clearFilters,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OutstandingTaskCard(
        task: tasks[index],
        onOpenSource: widget.onOpenSource,
        onUnmappedSource: (message) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }
}

/// Search field plus the status filter chips shown above the task list.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.status,
    required this.statusLabels,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.resultLabel,
  });

  final TextEditingController controller;
  final ProjectActivityStatus? status;
  final Map<ProjectActivityStatus?, String> statusLabels;
  final VoidCallback onSearchChanged;
  final ValueChanged<ProjectActivityStatus?> onStatusChanged;
  final String resultLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: (_) => onSearchChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search tasks, assignees or sections',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        onSearchChanged();
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusLabels.entries.map((entry) {
                final selected = entry.key == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color(0xFF111827),
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(
                      side: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    onSelected: (_) => onStatusChanged(entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            resultLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _TaskListMessage extends StatelessWidget {
  const _TaskListMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutstandingTaskCard extends StatelessWidget {
  const _OutstandingTaskCard({
    required this.task,
    required this.onOpenSource,
    required this.onUnmappedSource,
  });

  final ProjectActivity task;
  final ValueChanged<String> onOpenSource;
  final ValueChanged<String> onUnmappedSource;

  /// Deep link to the screen that owns this activity, or null when the
  /// source section has no mapped route (e.g. a manually added activity).
  String? get _sourceUrl =>
      NavigationRouteResolver.tryResolveCheckpointToUrl(task.sourceSection);

  void _handleTap() {
    final url = _sourceUrl;
    if (url == null) {
      onUnmappedSource(
        'No screen is mapped to "${_sourceLabel(task.sourceSection)}" yet.',
      );
      return;
    }
    onOpenSource(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignee = (task.assignedTo ?? '').trim();
    final dueDate = task.dueDate.trim();
    final meta = <String>[
      if (assignee.isNotEmpty) 'Assigned to: $assignee',
      if (dueDate.isNotEmpty) 'Due: $dueDate',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF1C2),
                child:
                    Icon(Icons.person_outline, color: Color(0xFF92400E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta.join(' · '),
                          style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(
                          label: _statusLabel(task.status),
                          color: _statusColor(task.status),
                        ),
                        _Tag(
                          label: _sourceLabel(task.sourceSection),
                          color: const Color(0xFF475569),
                          icon: _sourceUrl == null
                              ? Icons.link_off
                              : Icons.open_in_new,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(ProjectActivityStatus status) {
  switch (status) {
    case ProjectActivityStatus.pending:
      return 'Pending';
    case ProjectActivityStatus.acknowledged:
      return 'Acknowledged';
    case ProjectActivityStatus.implemented:
      return 'Implemented';
    case ProjectActivityStatus.rejected:
      return 'Rejected';
    case ProjectActivityStatus.deferred:
      return 'Deferred';
  }
}

Color _statusColor(ProjectActivityStatus status) {
  switch (status) {
    case ProjectActivityStatus.pending:
      return const Color(0xFFB45309);
    case ProjectActivityStatus.acknowledged:
      return const Color(0xFF1D4ED8);
    case ProjectActivityStatus.implemented:
      return const Color(0xFF15803D);
    case ProjectActivityStatus.rejected:
      return const Color(0xFFB91C1C);
    case ProjectActivityStatus.deferred:
      return const Color(0xFF6B7280);
  }
}

String _sourceLabel(String sourceSection) {
  final value = sourceSection.replaceAll('_', ' ').trim();
  if (value.isEmpty) return 'Manual entry';
  return value[0].toUpperCase() + value.substring(1);
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
