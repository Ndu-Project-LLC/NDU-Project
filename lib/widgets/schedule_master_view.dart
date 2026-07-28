import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/theme.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ScheduleMasterView extends StatefulWidget {
  const ScheduleMasterView({
    super.key,
    required this.workPackages,
    required this.scheduleActivities,
    this.onWorkPackageTap,
    this.onActivityTap,
  });

  final List<WorkPackage> workPackages;
  final List<ScheduleActivity> scheduleActivities;
  final ValueChanged<WorkPackage>? onWorkPackageTap;
  final ValueChanged<ScheduleActivity>? onActivityTap;

  @override
  State<ScheduleMasterView> createState() => _ScheduleMasterViewState();
}

class _ScheduleMasterViewState extends State<ScheduleMasterView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Normalize status strings: treat 'complete' and 'completed' the same.
  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'in_progress':
        return const Color(0xFFFBBF24);
      case 'complete':
      case 'completed':
        return const Color(0xFF10B981);
      case 'blocked':
      case 'on_hold':
        return const Color(0xFFEF4444);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  bool _matchesSearch(WorkPackage wp) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    if (wp.title.toLowerCase().contains(q)) return true;
    if (wp.description.toLowerCase().contains(q)) return true;
    if (wp.owner.toLowerCase().contains(q)) return true;
    if (wp.type.toLowerCase().contains(q)) return true;
    if (wp.phase.toLowerCase().contains(q)) return true;
    if (wp.wbsLevel2Title.toLowerCase().contains(q)) return true;
    // Also search activities within the WP
    final activities = widget.scheduleActivities
        .where((a) => a.workPackageId == wp.id)
        .toList();
    for (final a in activities) {
      if (a.title.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final byWbsLevel2 = <String, List<WorkPackage>>{};
    for (final wp in widget.workPackages) {
      final key = wp.wbsLevel2Id.isNotEmpty ? wp.wbsLevel2Id : 'unassigned';
      byWbsLevel2.putIfAbsent(key, () => []).add(wp);
    }

    final wbsLevel2Titles = <String, String>{};
    for (final wp in widget.workPackages) {
      if (wp.wbsLevel2Id.isNotEmpty && wp.wbsLevel2Title.isNotEmpty) {
        wbsLevel2Titles[wp.wbsLevel2Id] = wp.wbsLevel2Title;
      }
    }

    final activitiesByWp = <String, List<ScheduleActivity>>{};
    for (final activity in widget.scheduleActivities) {
      if (activity.workPackageId.isNotEmpty) {
        activitiesByWp
            .putIfAbsent(activity.workPackageId, () => [])
            .add(activity);
      }
    }

    final unassignedWps = byWbsLevel2.remove('unassigned') ?? [];

    // Apply search filter
    final filteredByWbsLevel2 = <String, List<WorkPackage>>{};
    for (final entry in byWbsLevel2.entries) {
      final filtered = entry.value.where(_matchesSearch).toList();
      if (filtered.isNotEmpty) {
        filteredByWbsLevel2[entry.key] = filtered;
      }
    }
    final filteredUnassigned = unassignedWps.where(_matchesSearch).toList();

    final hasResults =
        filteredByWbsLevel2.isNotEmpty || filteredUnassigned.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Master Schedule - WBS Level 2',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 280,
                height: 40,
                child: VoiceTextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search work packages, activities...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF6B7280)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppSemanticColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppSemanticColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFF59E0B), width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasResults && widget.workPackages.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.search_off,
                      size: 40, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 8),
                  Text(
                    'No results for "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          else if (widget.workPackages.isEmpty)
            const _EmptyMasterView()
          else ...[
            ...filteredByWbsLevel2.entries.map((entry) {
              final title =
                  wbsLevel2Titles[entry.key] ?? 'Untitled Phase';
              return _WbsLevel2Section(
                wbsLevel2Id: entry.key,
                title: title,
                workPackages: entry.value,
                activitiesByWp: activitiesByWp,
                onWorkPackageTap: widget.onWorkPackageTap,
                onActivityTap: widget.onActivityTap,
              );
            }),
            if (filteredUnassigned.isNotEmpty) ...[
              const SizedBox(height: 16),
              _WbsLevel2Section(
                wbsLevel2Id: 'unassigned',
                title: 'Unassigned Work Packages',
                workPackages: filteredUnassigned,
                activitiesByWp: activitiesByWp,
                onWorkPackageTap: widget.onWorkPackageTap,
                onActivityTap: widget.onActivityTap,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Collapsible WBS Level 2 section (P5).
class _WbsLevel2Section extends StatefulWidget {
  const _WbsLevel2Section({
    required this.wbsLevel2Id,
    required this.title,
    required this.workPackages,
    required this.activitiesByWp,
    this.onWorkPackageTap,
    this.onActivityTap,
  });

  final String wbsLevel2Id;
  final String title;
  final List<WorkPackage> workPackages;
  final Map<String, List<ScheduleActivity>> activitiesByWp;
  final ValueChanged<WorkPackage>? onWorkPackageTap;
  final ValueChanged<ScheduleActivity>? onActivityTap;

  @override
  State<_WbsLevel2Section> createState() => _WbsLevel2SectionState();
}

class _WbsLevel2SectionState extends State<_WbsLevel2Section> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _isExpanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        size: 20, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.folder,
                      size: 18, color: Color(0xFF4B5563)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.workPackages.length} WP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            ...widget.workPackages.map((wp) {
              final activities = widget.activitiesByWp[wp.id] ?? [];
              return _WorkPackageTile(
                workPackage: wp,
                activities: activities,
                onTap: widget.onWorkPackageTap,
                onActivityTap: widget.onActivityTap,
              );
            }),
        ],
      ),
    );
  }
}

/// Work package tile with expandable activities (P3) and fixed status (P6).
class _WorkPackageTile extends StatefulWidget {
  const _WorkPackageTile({
    required this.workPackage,
    required this.activities,
    this.onTap,
    this.onActivityTap,
  });

  final WorkPackage workPackage;
  final List<ScheduleActivity> activities;
  final ValueChanged<WorkPackage>? onTap;
  final ValueChanged<ScheduleActivity>? onActivityTap;

  @override
  State<_WorkPackageTile> createState() => _WorkPackageTileState();
}

class _WorkPackageTileState extends State<_WorkPackageTile> {
  bool _activitiesExpanded = false;

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'in_progress':
        return const Color(0xFFFBBF24);
      case 'complete':
      case 'completed':
        return const Color(0xFF10B981);
      case 'blocked':
      case 'on_hold':
        return const Color(0xFFEF4444);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = widget.workPackage;
    final activities = widget.activities;
    final statusColor = _statusColor(wp.status);
    final progress = wp.budgetedCost > 0
        ? (wp.actualCost / wp.budgetedCost).clamp(0.0, 1.0)
        : 0.0;

    // Show up to 3 initially, or all when expanded
    final displayedActivities =
        _activitiesExpanded ? activities : activities.take(3).toList();
    final hasMore = activities.length > 3 && !_activitiesExpanded;

    return GestureDetector(
      onTap: () => widget.onTap?.call(wp),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppSemanticColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wp.title.isNotEmpty
                        ? wp.title
                        : 'Untitled Work Package',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    wp.type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (wp.description.isNotEmpty)
              Text(
                wp.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _phaseIcon(wp.phase),
                  size: 14,
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  wp.phase.isNotEmpty
                      ? wp.phase.toUpperCase()
                      : 'N/A',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  wp.owner.isNotEmpty ? wp.owner : 'Unassigned',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${wp.budgetedCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            if (activities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Activities (${activities.length}):',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              ...displayedActivities.map((activity) {
                return GestureDetector(
                  onTap: () => widget.onActivityTap?.call(activity),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppSemanticColors.border),
                    ),
                    child: Row(
                      children: [
                        if (activity.isCriticalPath)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            activity.title.isNotEmpty
                                ? activity.title
                                : 'Untitled Activity',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF374151),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(activity.progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (hasMore || _activitiesExpanded)
                InkWell(
                  onTap: () {
                    setState(() {
                      _activitiesExpanded = !_activitiesExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _activitiesExpanded
                          ? 'Show less'
                          : '+ ${activities.length - 3} more...',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _phaseIcon(String phase) {
    switch (phase) {
      case 'design':
        return Icons.brush_outlined;
      case 'execution':
        return Icons.build_outlined;
      case 'launch':
        return Icons.rocket_launch_outlined;
      default:
        return Icons.help_outline;
    }
  }
}

class _EmptyMasterView extends StatelessWidget {
  const _EmptyMasterView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Work Packages Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create work packages and link them to schedule activities '
            'to see the master schedule view.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
