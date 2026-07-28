library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart' hide ContractModel;
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/services/contract_service.dart' show ContractModel, ContractService;
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/work_package_dialog.dart';
import 'package:ndu_project/widgets/work_package_detail.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/utils/wbs_to_work_item_converter.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

class ExecutionWorkPackagesScreen extends StatefulWidget {
  const ExecutionWorkPackagesScreen({super.key});

  @override
  State<ExecutionWorkPackagesScreen> createState() =>
      _ExecutionWorkPackagesScreenState();
}

class _ExecutionWorkPackagesScreenState
    extends State<ExecutionWorkPackagesScreen> {
  String _searchQuery = '';
  String _sortField = 'title';
  bool _sortAscending = true;
  String _selectedMethodology = 'Waterfall';
  String _activeTab = 'all'; // all | ewp | procurement | cwp | precomm | comm
  List<ContractModel> _contracts = [];
  List<ProcurementItemModel> _procurementItems = [];
  bool _loadingLinked = false;

  @override
  void initState() {
    super.initState();
    final data = ProjectDataHelper.getData(context, listen: false);
    final methodology = data.planningNotes['planning_schedule_methodology'];
    if (methodology != null && methodology is String && methodology.isNotEmpty) {
      _selectedMethodology = methodology;
    }
    _loadLinkedData();
  }

  Future<void> _loadLinkedData() async {
    setState(() => _loadingLinked = true);
    try {
      final data = ProjectDataHelper.getData(context, listen: false);
      final pid = data.projectName.isNotEmpty ? data.projectName : 'default';
      if (data.projectName.isNotEmpty) {
        final contracts = await ContractService.streamContracts(pid).first;
        final procItems = await ProcurementService.streamItems(pid).first;
        if (mounted) {
          setState(() {
            _contracts = contracts;
            _procurementItems = procItems;
          });
        }
      }
    } catch (_) {
      // Silently fail — linked data is non-critical
    } finally {
      if (mounted) setState(() => _loadingLinked = false);
    }
  }

  ProjectDataModel _getData() =>
      ProjectDataHelper.getData(context, listen: false);

  String _classificationCount(List<WorkPackage> packages, String cls) {
    final count = packages.where((p) => p.packageClassification == cls).length;
    return '$count';
  }

  List<WorkPackage> _filteredByTab(List<WorkPackage> packages) {
    if (_activeTab == 'all') return packages;
    return packages.where((p) {
      return switch (_activeTab) {
        'ewp' => p.packageClassification == IntegratedWorkPackageService.engineeringEwp,
        'procurement' => p.packageClassification == IntegratedWorkPackageService.procurementPackage,
        'cwp' => p.packageClassification == IntegratedWorkPackageService.constructionCwp || p.packageClassification == IntegratedWorkPackageService.implementationWorkPackage,
        'precomm' => p.packageClassification == IntegratedWorkPackageService.preCommissioningPackage,
        'comm' => p.packageClassification == IntegratedWorkPackageService.commissioningPackage,
        _ => true,
      };
    }).toList();
  }

  List<WorkPackage> _sortedAndFiltered(List<WorkPackage> packages) {
    var filtered = _filteredByTab(packages);
    var result = filtered.where((wp) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return wp.title.toLowerCase().contains(query) ||
          wp.owner.toLowerCase().contains(query) ||
          wp.type.toLowerCase().contains(query) ||
          wp.status.toLowerCase().contains(query) ||
          wp.phase.toLowerCase().contains(query) ||
          wp.packageClassification.toLowerCase().contains(query);
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
        case 'classification':
          cmp = a.packageClassification.compareTo(b.packageClassification);
          break;
        default:
          cmp = a.title.compareTo(b.title);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return result;
  }

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

  Color _classificationColor(String cls) {
    return _classificationColorMap[cls] ?? const Color(0xFF6B7280);
  }

  String _classificationLabel(String cls) {
    return _classificationDisplayLabel(cls);
  }

  String _classificationFullLabel(String cls) {
    return switch (cls) {
      IntegratedWorkPackageService.engineeringEwp => 'Engineering Work Package',
      IntegratedWorkPackageService.procurementPackage => 'Procurement Package',
      IntegratedWorkPackageService.constructionCwp => 'Construction Work Package',
      IntegratedWorkPackageService.implementationWorkPackage => 'Implementation Work Package',
      IntegratedWorkPackageService.preCommissioningPackage => 'Pre-Commissioning Package',
      IntegratedWorkPackageService.commissioningPackage => 'Commissioning Package',
      IntegratedWorkPackageService.deliveryPackage => 'Delivery Work Package',
      _ => cls,
    };
  }

  List<ContractModel> _contractsForPackage(WorkPackage wp) {
    final ids = wp.contractIds.map((e) => e.trim()).toSet();
    return _contracts.where((c) => ids.contains(c.id)).toList();
  }

  List<ProcurementItemModel> _procurementItemsForPackage(WorkPackage wp) {
    final ids = <String>{wp.id};
    ids.addAll(wp.linkedProcurementPackageIds);
    return _procurementItems
        .where((p) => ids.contains(p.id) || ids.contains(p.contractId))
        .toList();
  }

  // ─── Actions ───────────────────────────────────────────────────────────

  Future<void> _generatePackageChains() async {
    final dataProvider = ProjectDataHelper.getProvider(context);
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;

    if (wbs != null && wbs.level0.children.isNotEmpty) {
      final workItems = wbsNodeToWorkItems(wbs.level0);
      dataProvider.updateWBSData(wbsTree: workItems);
    }

    final data = dataProvider.projectData;
    if (data.wbsTree.isEmpty) {
      _showInfo('No WBS items found. Create a WBS first.');
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
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Integrated Package Chains'),
        content: Text(
          'Found ${newPackages.length} new EWP, procurement, and execution '
          'packages from WBS leaf nodes (all depths).'
          '${specLinkedCount > 0 ? "\n\n$specLinkedCount deliverable(s) linked to design specifications." : ""}'
          '\n\nGenerate them now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'execution_work_packages',
      dataUpdater: (d) =>
          d.copyWith(workPackages: [...d.workPackages, ...newPackages]),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Create Integrated Schedule Network'),
        content: Text(
          'Found ${generated.length} work package activities not yet in the '
          'schedule. Add them with engineering, procurement, and execution '
          'logic links?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create Network'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;

    final updatedActivities = [...data.scheduleActivities, ...generated];
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'execution_work_packages',
      dataUpdater: (d) => d.copyWith(scheduleActivities: updatedActivities),
      showSnackbar: false,
    );

    if (mounted) {
      setState(() {});
      _showInfo('Added ${generated.length} integrated schedule activities.');
    }
  }

  Future<void> _validateAll() async {
    final data = _getData();
    if (data.workPackages.isEmpty) {
      _showInfo('No work packages to validate.');
      return;
    }

    int totalWarnings = 0;
    final details = <String>[];
    for (final wp in data.workPackages) {
      final warnings = IntegratedWorkPackageService.validateReadiness(wp);
      if (warnings.isNotEmpty) {
        totalWarnings += warnings.length;
        details.add('${wp.title} (${warnings.length}):');
        details.addAll(warnings.map((w) => '  • $w'));
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          totalWarnings == 0
              ? 'All Packages Ready'
              : '$totalWarnings Warning(s) Found',
          style: TextStyle(
            color: totalWarnings == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        ),
        content: SizedBox(
          width: 560,
          child: totalWarnings == 0
              ? const Text('All work packages passed readiness validation.')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: details.map((d) => Text(d, style: const TextStyle(fontSize: 12))).toList(),
                  ),
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
      builder: (ctx) => WorkPackageDialog(
        wbsLevel2Options: wbsLevel2Ids,
      ),
    );

    if (result != null && mounted) {
      final updated = [...data.workPackages, result];
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'execution_work_packages',
        dataUpdater: (d) => d.copyWith(workPackages: updated),
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
      builder: (ctx) => WorkPackageDialog(
        initialWorkPackage: wp,
        wbsLevel2Options: wbsLevel2Ids,
      ),
    );

    if (result != null && mounted) {
      final updated =
          data.workPackages.map((p) => p.id == wp.id ? result : p).toList();
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'execution_work_packages',
        dataUpdater: (d) => d.copyWith(workPackages: updated),
        showSnackbar: false,
      );
      setState(() {});
      _showInfo('Work package updated.');
    }
  }

  Future<void> _deleteWorkPackage(WorkPackage wp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Work Package'),
        content: const Text('Are you sure you want to delete this work package?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final data = _getData();
      final updated = data.workPackages.where((p) => p.id != wp.id).toList();
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'execution_work_packages',
        dataUpdater: (d) => d.copyWith(workPackages: updated),
        showSnackbar: false,
      );
      setState(() {});
      _showInfo('Work package deleted.');
    }
  }

  Future<void> _showWorkPackageDetail(WorkPackage wp) async {
    final data = _getData();
    final activities =
        data.scheduleActivities.where((a) => a.workPackageId == wp.id).toList();
    final contracts = _contractsForPackage(wp);
    final procItems = _procurementItemsForPackage(wp);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => WorkPackageDetailView(
        workPackage: wp,
        activities: activities,
        onEdit: () {
          Navigator.of(ctx).pop();
          _editWorkPackage(wp);
        },
        onReleaseForExecution: () async {
          try {
            final released = IntegratedWorkPackageService.releaseEwpForExecution(wp);
            Navigator.of(ctx).pop();
            final updated = _getData()
                .workPackages
                .map((p) => p.id == wp.id ? released : p)
                .toList();
            await ProjectDataHelper.updateAndSave(
              context: context,
              checkpoint: 'execution_work_packages',
              dataUpdater: (d) => d.copyWith(workPackages: updated),
              showSnackbar: false,
            );
            if (mounted) {
              setState(() {});
              _showInfo('EWP "${wp.title}" released for execution.');
            }
          } on StateError catch (e) {
            Navigator.of(ctx).pop();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  // ─── Inline Contract Dialog ────────────────────────────────────────────

  Future<void> _addContractForPackage(WorkPackage wp) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final contractorCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String contractType = 'Fixed Price';
    String paymentType = 'Lump Sum';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link Contract to Work Package'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Contract Name *'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                VoiceTextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contractorCtrl,
                  decoration: const InputDecoration(labelText: 'Contractor Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ownerCtrl,
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(labelText: 'Estimated Value'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: contractType,
                  decoration: const InputDecoration(labelText: 'Contract Type'),
                  items: const [
                    DropdownMenuItem(value: 'Fixed Price', child: Text('Fixed Price')),
                    DropdownMenuItem(value: 'Cost Plus', child: Text('Cost Plus')),
                    DropdownMenuItem(value: 'Time & Material', child: Text('Time & Material')),
                    DropdownMenuItem(value: 'Unit Price', child: Text('Unit Price')),
                  ],
                  onChanged: (v) => contractType = v ?? 'Fixed Price',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentType,
                  decoration: const InputDecoration(labelText: 'Payment Type'),
                  items: const [
                    DropdownMenuItem(value: 'Lump Sum', child: Text('Lump Sum')),
                    DropdownMenuItem(value: 'Milestone', child: Text('Milestone')),
                    DropdownMenuItem(value: 'Progress', child: Text('Progress')),
                  ],
                  onChanged: (v) => paymentType = v ?? 'Lump Sum',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final data = _getData();
              final projectId = data.projectName.isNotEmpty ? data.projectName : 'default';
              try {
                final contractId = await ContractService.createContract(
                  name: name,
                  description: descCtrl.text.trim(),
                  estimatedValue: double.tryParse(valueCtrl.text) ?? 0,
                  contractType: contractType,
                  paymentType: paymentType,
                  status: 'draft',
                  projectId: projectId,
                  scope: '',
                  discipline: '',
                  notes: '',
                  createdById: '',
                  createdByEmail: '',
                  createdByName: '',
                );
                if (contractId.isNotEmpty && mounted) {
                  final updatedWp = wp.copyWith(
                    contractIds: [...wp.contractIds, contractId],
                  );
                  final updated = _getData()
                      .workPackages
                      .map((p) => p.id == wp.id ? updatedWp : p)
                      .toList();
                  await ProjectDataHelper.updateAndSave(
                    context: context,
                    checkpoint: 'execution_work_packages',
                    dataUpdater: (d) => d.copyWith(workPackages: updated),
                    showSnackbar: false,
                  );
                  if (mounted) {
                    setState(() {});
                    _loadLinkedData();
                  }
                }
                Navigator.of(ctx).pop(true);
                _showInfo('Contract "$name" created and linked.');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating contract: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Create & Link'),
          ),
        ],
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

  // ─── Resource Conflict Banner ──────────────────────────────────────────

  Widget _buildResourceConflictBanner(List<WorkPackage> packages) {
    final conflicts =
        IntegratedWorkPackageService.detectResourceConflicts(packages);
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

  // ─── Readiness Bar ─────────────────────────────────────────────────────

  Widget _buildReadinessBar(WorkPackage wp) {
    final warnings = IntegratedWorkPackageService.validateReadiness(wp);
    final maxChecks = 8;
    final passed = maxChecks - warnings.length;
    final progress = (passed / maxChecks).clamp(0.0, 1.0);
    final color = progress >= 0.8
        ? const Color(0xFF10B981)
        : progress >= 0.5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Tooltip(
      message: warnings.isEmpty
          ? 'Ready'
          : warnings.take(4).join('\n'),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppSemanticColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work_outline, size: 56, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              'No Execution Work Packages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate integrated package chains from your WBS, or add packages manually.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generatePackageChains,
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Generate Package Chains'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addWorkPackage,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Work Package Manually'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────

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

    return ResponsiveScaffold(
      activeItemLabel: 'Execution Work Packages',
      appBarTitle: 'Execution Work Packages',
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: workPackages.isEmpty
            ? _buildEmptyState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary bar
                  _buildSummaryBar(workPackages),
                  const SizedBox(height: 20),
                  // Category filter tabs
                  _buildCategoryTabs(),
                  const SizedBox(height: 16),
                  // Action bar
                  _buildActionBar(),
                  const SizedBox(height: 16),
                  // Resource conflict banner
                  _buildResourceConflictBanner(workPackages),
                  // Package list
                  ...filtered.map((wp) {
                    final activities = activitiesByWp[wp.id] ?? [];
                    final contracts = _contractsForPackage(wp);
                    final procItems = _procurementItemsForPackage(wp);
                    return _buildPackageCard(
                      wp, activities, contracts, procItems);
                  }),
                ],
              ),
      ),
    );
  }

  static const Map<String, String> _classificationFullLabelMap = {
    'engineeringEwp': 'Engineering / Design',
    'procurementPackage': 'Procurement',
    'constructionCwp': 'Construction',
    'implementationWorkPackage': 'Implementation',
    'preCommissioningPackage': 'Pre-Commissioning',
    'commissioningPackage': 'Commissioning',
    'deliveryPackage': 'Delivery',
  };

  static const Map<String, Color> _classificationColorMap = {
    'engineeringEwp': Color(0xFFFBBF24),
    'procurementPackage': Color(0xFF22C55E),
    'constructionCwp': Color(0xFFF97316),
    'implementationWorkPackage': Color(0xFF8B5CF6),
    'preCommissioningPackage': Color(0xFFC084FC),
    'commissioningPackage': Color(0xFFEC4899),
    'deliveryPackage': Color(0xFF14B8A6),
  };

  String _classificationDisplayLabel(String cls) {
    return _classificationFullLabelMap[cls] ?? _classificationFullLabel(cls);
  }

  Widget _buildSummaryBar(List<WorkPackage> packages) {
    final classifications = [
      IntegratedWorkPackageService.engineeringEwp,
      IntegratedWorkPackageService.procurementPackage,
      IntegratedWorkPackageService.constructionCwp,
      IntegratedWorkPackageService.implementationWorkPackage,
      IntegratedWorkPackageService.preCommissioningPackage,
      IntegratedWorkPackageService.commissioningPackage,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline, size: 20, color: Color(0xFF374151)),
              const SizedBox(width: 8),
              Text(
                '${packages.length} Work Packages',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: classifications.map((cls) {
              final count = _classificationCount(packages, cls);
              if (count == '0') return const SizedBox.shrink();
              final color = _classificationColorMap[cls] ?? const Color(0xFF6B7280);
              final label = _classificationDisplayLabel(cls);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
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
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = ['All', 'Engineering / Design', 'Procurement', 'Construction', 'Pre-Commissioning', 'Commissioning'];
    final values = ['all', 'ewp', 'procurement', 'cwp', 'precomm', 'comm'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _activeTab == values[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = values[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isActive
                      ? [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? const Color(0xFF111827) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 36,
            child: VoiceTextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search packages...',
                hintStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                prefixIcon:
                    const Icon(Icons.search, size: 16, color: Color(0xFF6B7280)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppSemanticColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppSemanticColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppSemanticColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortField,
                    onChanged: (value) {
                      if (value != null) setState(() => _sortField = value);
                    },
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'title', child: Text('Title')),
                      DropdownMenuItem(value: 'classification', child: Text('Type')),
                      DropdownMenuItem(value: 'status', child: Text('Status')),
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                      DropdownMenuItem(value: 'budget', child: Text('Budget')),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                  ),
                  onPressed: () =>
                      setState(() => _sortAscending = !_sortAscending),
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Spacer(),
          _actionChip(Icons.account_tree_outlined, 'Generate', _generatePackageChains),
          _actionChip(Icons.timeline_outlined, 'Schedule Network', _createScheduleNetwork),
          _actionChip(Icons.checklist_outlined, 'Validate All', _validateAll),
          _actionChip(Icons.add, 'Add Package', _addWorkPackage),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppSemanticColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF374151)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(
    WorkPackage wp,
    List<ScheduleActivity> activities,
    List<ContractModel> contracts,
    List<ProcurementItemModel> procItems,
  ) {
    final clsColor = _classificationColor(wp.packageClassification);
    final clsLabel = _classificationDisplayLabel(wp.packageClassification);
    final clsFull = _classificationFullLabel(wp.packageClassification);
    final progress = wp.budgetedCost > 0
        ? (wp.actualCost / wp.budgetedCost).clamp(0.0, 1.0)
        : 0.0;
    final warnings = IntegratedWorkPackageService.validateReadiness(wp);

    return GestureDetector(
      onTap: () => _showWorkPackageDetail(wp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppSemanticColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + classification badge + status + actions
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: clsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: clsColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    clsLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: clsColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wp.title.isNotEmpty ? wp.title : 'Untitled Work Package',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(wp.status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    wp.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: warnings.take(3).join('\n'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF97316)),
                      ),
                      child: Text(
                        '${warnings.length}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _editWorkPackage(wp),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteWorkPackage(wp),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete',
                ),
              ],
            ),
            if (wp.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                wp.description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            // Info row: type, owner, phase, classification
            Row(
              children: [
                _infoChip(Icons.person_outline, wp.owner.isNotEmpty ? wp.owner : 'Unassigned'),
                const SizedBox(width: 12),
                _infoChip(Icons.category_outlined, wp.type.toUpperCase()),
                const SizedBox(width: 12),
                _infoChip(Icons.flag_outlined, wp.phase.toUpperCase()),
                const SizedBox(width: 12),
                _infoChip(Icons.label_outline, clsFull),
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
            // Linked contracts row
            if (contracts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 12, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    'Contracts: ${contracts.map((c) => c.name).join(", ")}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _addContractForPackage(wp),
                    child: const Icon(Icons.add_circle_outline, size: 12, color: Color(0xFFFBBF24)),
                  ),
                ],
              ),
            ],
            // Linked procurement items row
            if (procItems.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 12, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Procurement: ${procItems.map((p) => p.name).join(", ")}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Readiness bar + budget progress
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 3, child: _buildReadinessBar(wp)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFBBF24)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
