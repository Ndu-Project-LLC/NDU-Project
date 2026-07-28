import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/work_package_dialog.dart';
import 'package:ndu_project/widgets/work_package_detail.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_success_snackbar.dart';
import 'package:ndu_project/theme.dart';

class PlanningWorkPackagesTab extends StatefulWidget {
  const PlanningWorkPackagesTab({super.key});

  @override
  State<PlanningWorkPackagesTab> createState() =>
      _PlanningWorkPackagesTabState();
}

class _PlanningWorkPackagesTabState extends State<PlanningWorkPackagesTab> {
  String _searchQuery = '';
  String _sortField = 'title';
  bool _sortAscending = true;
  String _selectedMethodology = 'Waterfall';

  @override
  void initState() {
    super.initState();
    final data = ProjectDataHelper.getData(context, listen: false);
    final methodology = data.planningNotes['planning_schedule_methodology'];
    if (methodology != null && methodology is String && methodology.isNotEmpty) {
      _selectedMethodology = methodology;
    }
  }

  ProjectDataModel _getData() =>
      ProjectDataHelper.getData(context, listen: false);

  List<WorkPackage> _sortedAndFiltered(List<WorkPackage> packages) {
    var result = packages.where((wp) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return wp.title.toLowerCase().contains(query) ||
          wp.owner.toLowerCase().contains(query) ||
          wp.type.toLowerCase().contains(query) ||
          wp.status.toLowerCase().contains(query) ||
          wp.phase.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'owner':
          cmp = a.owner.compareTo(b.owner);
          break;
        case 'phase':
          cmp = a.phase.compareTo(b.phase);
          break;
        case 'budget':
          cmp = a.budgetedCost.compareTo(b.budgetedCost);
          break;
        default:
          cmp = a.title.compareTo(b.title);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return result;
  }

  Future<void> _generatePackageChains() async {
    final data = _getData();
    if (data.wbsTree.isEmpty) {
      _showInfo('No WBS items found.');
      return;
    }

    final designDoc = DesignPlanningDocument.fromProjectData(data);
    final designSpecs = designDoc.specifications;

    var generated = IntegratedWorkPackageService.generatePackageChainsFromWbs(
      wbsTree: data.wbsTree,
      methodology: _selectedMethodology,
      designSpecifications: designSpecs,
    );

    generated = IntegratedWorkPackageService
        .deriveProcurementScopeFromEwpDeliverables(generated);

    generated = IntegratedWorkPackageService.rollUpChildCostsAndDates(generated);

    generated = IntegratedWorkPackageService.enforceEstimateBasis(
      generated,
      methodology: _selectedMethodology,
    );

    if (generated.isEmpty) {
      _showInfo('No WBS leaf node package candidates found.');
      return;
    }

    final existingIds = data.workPackages.map((wp) => wp.id).toSet();
    final newPackages =
        generated.where((wp) => !existingIds.contains(wp.id)).toList();
    if (newPackages.isEmpty) {
      _showInfo('Integrated package chains are already generated.');
      return;
    }

    final specLinkedCount = newPackages
        .where((wp) =>
            wp.packageClassification ==
            IntegratedWorkPackageService.engineeringEwp)
        .expand((wp) => wp.deliverables)
        .where((d) => d.linkedSpecificationIds.isNotEmpty)
        .length;

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Integrated Package Chains'),
        content: Text(
          'Found ${newPackages.length} new EWP, procurement, and execution '
          'packages from WBS leaf nodes (all depths).'
          '${specLinkedCount > 0 ? "\n\n$specLinkedCount deliverable(s) linked to design specifications." : ""}'
          '\n\nGenerate them now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'schedule',
      dataUpdater: (data) =>
          data.copyWith(workPackages: [...data.workPackages, ...newPackages]),
      showSnackbar: false,
    );

    if (mounted) {
      setState(() {});
      _showInfo(
        'Generated ${newPackages.length} integrated work packages'
        '${specLinkedCount > 0 ? " with $specLinkedCount spec-linked deliverables" : ""}.',
      );
    }
  }

  Future<void> _createScheduleNetwork() async {
    final data = _getData();
    if (data.workPackages.isEmpty) {
      _showInfo('No work packages found.');
      return;
    }

    final generated =
        IntegratedWorkPackageService.generateScheduleActivitiesFromPackages(
      packages: data.workPackages,
      existingActivities: data.scheduleActivities,
    );

    if (generated.isEmpty) {
      _showInfo('Integrated schedule network is already generated.');
      return;
    }

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Integrated Schedule Network'),
        content: Text(
          'Found ${generated.length} work package activities not yet in the '
          'schedule. Add them with engineering, procurement, and execution '
          'logic links?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create Network'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;

    final updatedActivities = [...data.scheduleActivities, ...generated];
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'schedule',
      dataUpdater: (data) =>
          data.copyWith(scheduleActivities: updatedActivities),
      showSnackbar: false,
    );

    if (mounted) {
      setState(() {});
      _showInfo('Added ${generated.length} integrated schedule activities.');
    }
  }

  Future<void> _addWorkPackage() async {
    final data = _getData();
    final wbsLevel2Ids = <Map<String, String>>[];
    for (final item in data.wbsTree) {
      for (final child in item.children) {
        wbsLevel2Ids.add({'id': child.id, 'title': child.title});
      }
    }

    final result = await showDialog<WorkPackage>(
      context: context,
      builder: (context) => WorkPackageDialog(
        wbsLevel2Options: wbsLevel2Ids,
      ),
    );

    if (result != null && mounted) {
      final updated = [...data.workPackages, result];
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'schedule',
        dataUpdater: (data) => data.copyWith(workPackages: updated),
        showSnackbar: false,
      );
      setState(() {});
      _showInfo('Work package created.');
    }
  }

  Future<void> _editWorkPackage(WorkPackage wp) async {
    final data = _getData();
    final wbsLevel2Ids = <Map<String, String>>[];
    for (final item in data.wbsTree) {
      for (final child in item.children) {
        wbsLevel2Ids.add({'id': child.id, 'title': child.title});
      }
    }

    final result = await showDialog<WorkPackage>(
      context: context,
      builder: (context) => WorkPackageDialog(
        initialWorkPackage: wp,
        wbsLevel2Options: wbsLevel2Ids,
      ),
    );

    if (result != null && mounted) {
      final updated = data.workPackages.map((p) => p.id == wp.id ? result : p).toList();
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'schedule',
        dataUpdater: (data) => data.copyWith(workPackages: updated),
        showSnackbar: false,
      );
      setState(() {});
      _showInfo('Work package updated.');
    }
  }

  Future<void> _deleteWorkPackage(WorkPackage wp) async {
    final confirm = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Work Package',
      itemLabel: wp.title,
    );

    if (confirm && mounted) {
      final data = _getData();
      final updated = data.workPackages.where((p) => p.id != wp.id).toList();
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'schedule',
        dataUpdater: (data) => data.copyWith(workPackages: updated),
        showSnackbar: false,
      );
      setState(() {});
      showDeleteSuccessSnackBar(context, itemLabel: 'Work package');
    }
  }

  Future<void> _showWorkPackageDetail(WorkPackage wp) async {
    final data = _getData();
    final activities =
        data.scheduleActivities.where((a) => a.workPackageId == wp.id).toList();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => WorkPackageDetailView(
        workPackage: wp,
        activities: activities,
        onEdit: () {
          Navigator.of(context).pop();
          _editWorkPackage(wp);
        },
        onReleaseForExecution: () async {
          try {
            final released =
                IntegratedWorkPackageService.releaseEwpForExecution(wp);
            Navigator.of(context).pop();
            final updated = _getData()
                .workPackages
                .map((p) => p.id == wp.id ? released : p)
                .toList();
            await ProjectDataHelper.updateAndSave(
              context: context,
              checkpoint: 'schedule',
              dataUpdater: (data) => data.copyWith(workPackages: updated),
              showSnackbar: false,
            );
            if (mounted) {
              setState(() {});
              _showInfo('EWP "${wp.title}" released for execution.');
            }
          } on StateError catch (e) {
            Navigator.of(context).pop();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildResourceConflictBanner(List<WorkPackage> packages) {
    final conflicts = IntegratedWorkPackageService.detectResourceConflicts(packages);
    if (conflicts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${conflicts.length} resource conflict(s) detected — '
                '${conflicts.map((c) => c.owner).toSet().join(", ")} '
                'have overlapping assignments.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _getData();
    final workPackages = data.workPackages;
    final scheduleActivities = data.scheduleActivities;

    final activitiesByWp = <String, List<ScheduleActivity>>{};
    for (final activity in scheduleActivities) {
      if (activity.workPackageId.isNotEmpty) {
        activitiesByWp
            .putIfAbsent(activity.workPackageId, () => [])
            .add(activity);
      }
    }

    final filtered = _sortedAndFiltered(workPackages);

    if (workPackages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppSemanticColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.work_outline,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Work Packages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create work packages to organize schedule activities.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _generatePackageChains,
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('Generate Package Chains'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _createScheduleNetwork,
              icon: const Icon(Icons.timeline_outlined, size: 16),
              label: const Text('Create Schedule Network'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addWorkPackage,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Work Package'),
            ),
          ],
        ),
      );
    }

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
                'Work Packages',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                height: 38,
                child: VoiceTextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search work packages...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF6B7280)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
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
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppSemanticColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort,
                        size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortField,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortField = value;
                            });
                          }
                        },
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'title', child: Text('Title')),
                          DropdownMenuItem(
                              value: 'status', child: Text('Status')),
                          DropdownMenuItem(
                              value: 'owner', child: Text('Owner')),
                          DropdownMenuItem(
                              value: 'phase', child: Text('Phase')),
                          DropdownMenuItem(
                              value: 'budget', child: Text('Budget')),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                      },
                      tooltip: _sortAscending
                          ? 'Sort ascending'
                          : 'Sort descending',
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _generatePackageChains,
                icon:
                    const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('Generate Package Chains'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _createScheduleNetwork,
                icon: const Icon(Icons.timeline_outlined, size: 16),
                label: const Text('Create Schedule Network'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addWorkPackage,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Work Package'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResourceConflictBanner(workPackages),
          ...filtered.map((wp) {
            final activities = activitiesByWp[wp.id] ?? [];
            return PlanningWorkPackageCard(
              workPackage: wp,
              activities: activities,
              onTap: () => _showWorkPackageDetail(wp),
              onEdit: () => _editWorkPackage(wp),
              onDelete: () => _deleteWorkPackage(wp),
            );
          }),
        ],
      ),
    );
  }
}

class PlanningWorkPackageCard extends StatefulWidget {
  const PlanningWorkPackageCard({
    super.key,
    required this.workPackage,
    required this.activities,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final WorkPackage workPackage;
  final List<ScheduleActivity> activities;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<PlanningWorkPackageCard> createState() =>
      _PlanningWorkPackageCardState();
}

class _PlanningWorkPackageCardState extends State<PlanningWorkPackageCard> {
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
    final progress = wp.budgetedCost > 0
        ? (wp.actualCost / wp.budgetedCost).clamp(0.0, 1.0)
        : 0.0;
    final readinessWarnings =
        IntegratedWorkPackageService.validateReadiness(wp);
    final displayedActivities =
        _activitiesExpanded ? activities : activities.take(3).toList();
    final hasMore = activities.length > 3 && !_activitiesExpanded;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppSemanticColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    wp.title.isNotEmpty
                        ? wp.title
                        : 'Untitled Work Package',
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
                    color: _statusColor(wp.status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    wp.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (readinessWarnings.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: readinessWarnings.take(5).join('\n'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: const Color(0xFFF97316)),
                      ),
                      child: Text(
                        '${readinessWarnings.length} WARN',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.onEdit != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: widget.onEdit,
                    tooltip: 'Edit',
                  ),
                ],
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFEF4444)),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (wp.description.isNotEmpty) ...[
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
            ],
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  wp.owner.isNotEmpty ? wp.owner : 'Unassigned',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.category_outlined,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  wp.type.isNotEmpty ? wp.type.toUpperCase() : 'N/A',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${wp.budgetedCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            if (activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Activities (${activities.length}):',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              ...displayedActivities.map((activity) {
                return Container(
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFBBF24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
