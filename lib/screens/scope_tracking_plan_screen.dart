import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';

import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/models/scope_tracking_item.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/scope_tracking_table_widget.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
enum _ScopeTab { overview, registry, traceability, baseline }

const List<String> _tabLabels = [
 'Overview',
 'Scope Registry',
 'Traceability',
 'Baseline & Variance',
];

class ScopeTrackingPlanScreen extends StatefulWidget {
 const ScopeTrackingPlanScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ScopeTrackingPlanScreen()),
 );
 }

 @override
 State<ScopeTrackingPlanScreen> createState() =>
 _ScopeTrackingPlanScreenState();
}

class _ScopeTrackingPlanScreenState extends State<ScopeTrackingPlanScreen> {
 _ScopeTab _activeTab = _ScopeTab.overview;
 List<ScopeTrackingItem> _items = [];
 List<String> _availableRoles = [];
 bool _isLoading = false;
 bool _isAutoGenerating = false;
 bool _autoPopulated = false;
 Timer? _saveDebounce;

 Set<String> _selectedFilters = {'All'};

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 super.dispose();
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null) return;
 if (!mounted) return;

 setState(() => _isLoading = true);
 try {
 final items = await ExecutionPhaseService.loadScopeTrackingItems(
 projectId: projectId);
 final staffRows =
 await ExecutionPhaseService.loadStaffingRows(projectId: projectId);
 final roles = staffRows
 .map((row) => row.role)
 .where((r) => r.isNotEmpty)
 .toSet()
 .toList();

 if (mounted) {
 setState(() {
 _items = items;
 _availableRoles = roles;
 _isLoading = false;
 });
 }

 if (!_autoPopulated && items.isEmpty) {
 await _autoPopulateFromPlanning(projectId);
 }
 } catch (e) {
 debugPrint('ScopeTrackingPlanScreen._loadData error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 Future<void> _autoPopulateFromPlanning(String projectId) async {
 final provider =
 Provider.of<ProjectDataProvider>(context, listen: false);
 final data = provider.projectData;

 final newItems = <ScopeTrackingItem>[];

 for (final req in data.planningRequirementItems) {
 final text = req.plannedText.trim();
 if (text.isEmpty) continue;
 newItems.add(ScopeTrackingItem(
 scopeItem: text,
 owner: req.owner,
 requirementId: req.id,
 wbsId: req.wbsRef,
 verificationMethod: req.verificationMethod,
 isBaseline: true,
 ));
 }

 if (newItems.isNotEmpty) {
 await ExecutionPhaseService.saveScopeTrackingItems(
 projectId: projectId,
 items: newItems,
 );
 if (mounted) {
 setState(() => _items = newItems);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Scope items seeded from planning requirements.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }
 _autoPopulated = true;
 }

 Future<void> _regenerateAllFromAi() async {
 final projectId = _projectId;
 if (projectId == null) return;
 if (!mounted) return;

 setState(() => _isAutoGenerating = true);
 try {
 final data = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildExecutivePlanContext(data);

 final openAiService = OpenAiServiceSecure();
 final generated = await openAiService.generateScopeTrackingItems(
 context: contextText,
 existingScopeItems:
 _items.map((i) => i.scopeItem).where((s) => s.isNotEmpty).toList(),
 );

 if (generated.isNotEmpty && mounted) {
 final newItems = generated.map((itemText) {
 return ScopeTrackingItem(
 scopeItem: itemText,
 isBaseline: true,
 );
 }).toList();

 setState(() => _items = newItems);
 await ExecutionPhaseService.saveScopeTrackingItems(
 projectId: projectId,
 items: newItems,
 );

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Generated ${newItems.length} scope items.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 } catch (e) {
 debugPrint('ScopeTrackingPlanScreen._regenerateAll error: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('AI generation failed: $e'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 } finally {
 if (mounted) setState(() => _isAutoGenerating = false);
 }
 }

 Future<void> _saveItems() async {
 final projectId = _projectId;
 if (projectId == null) return;
 try {
 await ExecutionPhaseService.saveScopeTrackingItems(
 projectId: projectId,
 items: _items,
 );
 } catch (e) {
 debugPrint('ScopeTrackingPlanScreen._saveItems error: $e');
 }
 }

 void _scheduleSave() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 700), _saveItems);
 }

 void _addItem(ScopeTrackingItem item) {
 setState(() => _items.add(item));
 _scheduleSave();
 }

 void _updateItem(ScopeTrackingItem updated) {
 setState(() {
 final idx = _items.indexWhere((i) => i.id == updated.id);
 if (idx >= 0) {
 _items[idx] = updated;
 } else {
 _items.add(updated);
 }
 });
 _scheduleSave();
 }

  void _deleteItem(ScopeTrackingItem item) async {
  final ok = await launchConfirmDelete(context, itemName: 'scope item');
  if (!ok) return;
  setState(() => _items.removeWhere((i) => i.id == item.id));
  _scheduleSave();
  }

 void _setBaseline() async {
 final projectId = _projectId;
 if (projectId == null) return;

 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Set Scope Baseline?'),
 content: const Text(
 'This will mark all current scope items as baseline. Items added later will be tracked as scope changes.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 child: const Text('Set Baseline'),
 ),
 ],
 ),
 );

 if (confirm != true) return;

 setState(() {
 _items = _items.map((i) => i.copyWith(isBaseline: true)).toList();
 });
 await _saveItems();

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Scope baseline set.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

 List<ScopeTrackingItem> get _filteredItems {
 if (_selectedFilters.contains('All')) return _items;
 return _items
 .where((i) => _selectedFilters.contains(i.implementationStatus))
 .toList();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 24;

 return Scaffold(
 backgroundColor: const Color(0xFFF7F9FC),
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Scope Tracking Plan'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Scope Tracking Plan', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _ScopeTrackingHeader(
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'scope_tracking_plan'),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(
 context, 'scope_tracking_plan'),
 onRegenerateAll: _regenerateAllFromAi,
 isRegenerating: _isAutoGenerating,
 ),
 const SizedBox(height: 20),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Scope Tracking Plan',
 noteKey: 'planning_scope_tracking_notes',
 checkpoint: 'scope_tracking_plan',
 description:
 'Capture scope boundaries, governance decisions, and change thresholds.',
 ),
 const SizedBox(height: 20),
 _buildTabs(),
 const SizedBox(height: 20),
 if (_isLoading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(48),
 child: CircularProgressIndicator(),
 ),
 )
 else
 _buildTabContent(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'scope_tracking_plan'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'scope_tracking_plan'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'scope_tracking_plan'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'scope_tracking_plan'),
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Scope Tracking Plan',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildTabs() {
 final isCompact = MediaQuery.sizeOf(context).width < 900;
 return Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: isCompact
 ? SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(children: _buildChips()),
 )
 : Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _buildChips(),
 ),
 );
 }

 List<Widget> _buildChips() {
 return List.generate(_tabLabels.length, (index) {
 final tab = _ScopeTab.values[index];
 return ChoiceChip(
 label: Text(_tabLabels[index]),
 selected: _activeTab == tab,
 onSelected: (_) => setState(() => _activeTab = tab),
 selectedColor: const Color(0xFFF59E0B),
 labelStyle: TextStyle(
 color: _activeTab == tab
 ? const Color(0xFF111827)
 : const Color(0xFF4B5563),
 fontWeight: FontWeight.w600,
 fontSize: 12,
 ),
 );
 });
 }

 Widget _buildTabContent() {
 switch (_activeTab) {
 case _ScopeTab.overview:
 return _buildOverviewTab();
 case _ScopeTab.registry:
 return _buildRegistryTab();
 case _ScopeTab.traceability:
 return _buildTraceabilityTab();
 case _ScopeTab.baseline:
 return _buildBaselineTab();
 }
 }

 Widget _buildOverviewTab() {
 final total = _items.length;
 final inProgress =
 _items.where((i) => i.implementationStatus == 'In-Progress').length;
 final verified =
 _items.where((i) => i.implementationStatus == 'Verified').length;
 final notStarted =
 _items.where((i) => i.implementationStatus == 'Not Started').length;
 final creep = _items.where((i) => !i.isBaseline).length;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildMetricsStrip(
 metrics: [
 _ScopeMetricData('Total Items', total, const Color(0xFFD97706),
 'All scope items', Icons.list),
 _ScopeMetricData('Not Started', notStarted,
 const Color(0xFF9CA3AF), 'Awaiting work', Icons.schedule),
 _ScopeMetricData('In Progress', inProgress,
 const Color(0xFFF59E0B), 'Items being worked', Icons.sync),
 _ScopeMetricData('Verified', verified, const Color(0xFF10B981),
 'Completed & verified', Icons.check_circle),
 _ScopeMetricData('Creep', creep, const Color(0xFFEF4444),
 'Items not in baseline', Icons.warning_amber),
 ],
 ),
 const SizedBox(height: 24),
 const _ScopeTrackingHero(),
 const SizedBox(height: 20),
 const _ScopeControlPlaybook(),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 children: const [
 _GovernanceCadenceCard(),
 SizedBox(height: 20),
 _ChangeIntakeCard(),
 ],
 ),
 ),
 const SizedBox(width: 20),
 const Expanded(
 child: _DriftSignalsCard(),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildMetricsStrip({
 required List<_ScopeMetricData> metrics,
 }) {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: metrics
 .map((m) => _ScopeMetricCard(
 data: m,
 width: MediaQuery.sizeOf(context).width < 900 ? 160 : 180,
 ))
 .toList(),
 );
 }

 Widget _buildRegistryTab() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 FilledButton.icon(
 onPressed: _showAddItemDialog,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Scope Item'),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 12),
 if (_items.isNotEmpty)
 OutlinedButton.icon(
 onPressed: _generateMissingScopeItems,
 icon: const Icon(Icons.auto_awesome, size: 16),
 label: const Text('AI Suggest Missing'),
 style: OutlinedButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const Spacer(),
 Text(
 '${_items.length} items',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w500),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _buildFilterChips(),
 const SizedBox(height: 16),
 ScopeTrackingTableWidget(
 items: _filteredItems,
 onUpdated: _updateItem,
 onDeleted: (item) {
 _deleteItem(item);
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: const Text('Scope item deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 _addItem(item);
 },
 ),
 duration: const Duration(seconds: 5),
 ),
 );
 }
 },
 availableRoles: _availableRoles,
 ),
 ],
 );
 }

 Widget _buildFilterChips() {
 const statuses = ['All', 'Not Started', 'In-Progress', 'Verified', 'Out-of-Scope'];
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: statuses.map((s) {
 final selected = _selectedFilters.contains(s);
 return Padding(
 padding: const EdgeInsets.only(right: 8),
 child: FilterChip(
 label: Text(s,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
 selected: selected,
 onSelected: (_) {
 setState(() {
 if (s == 'All') {
 _selectedFilters = {'All'};
 } else {
 _selectedFilters.remove('All');
 if (selected) {
 _selectedFilters.remove(s);
 } else {
 _selectedFilters.add(s);
 }
 if (_selectedFilters.isEmpty) {
 _selectedFilters = {'All'};
 }
 }
 });
 },
 selectedColor: const Color(0xFFFDE68A),
 checkmarkColor: const Color(0xFF92400E),
 backgroundColor: Colors.white,
 side: BorderSide(
 color: selected ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }

 Widget _buildTraceabilityTab() {
 final data = ProjectDataHelper.getData(context);
 final requirements = data.planningRequirementItems;
 final wbsTree = data.wbsTree;
 final scheduleActivities = data.scheduleActivities;

 final flatWbs = _flattenWbsItems(wbsTree);

 if (_items.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(48),
 child: Column(
 children: [
 Icon(Icons.account_tree_outlined,
 size: 64, color: Colors.grey.shade300),
 const SizedBox(height: 16),
 const Text('No scope items yet.',
 style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
 const SizedBox(height: 8),
 const Text('Add scope items in the Scope Registry tab first.',
 style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
 ],
 ),
 ),
 );
 }

 final linkedToWbs = _items.where((i) => i.wbsId.isNotEmpty).length;
 final linkedToReq = _items.where((i) => i.requirementId.isNotEmpty).length;
 final linkedToSched = _items.where((i) => i.scheduleActivityId.isNotEmpty).length;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 16,
 runSpacing: 12,
 children: [
 _TraceStat(
 label: 'Linked to WBS',
 value: '$linkedToWbs/${_items.length}',
 color: linkedToWbs == _items.length
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 ),
 _TraceStat(
 label: 'Linked to Requirements',
 value: '$linkedToReq/${_items.length}',
 color: linkedToReq == _items.length
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 ),
 _TraceStat(
 label: 'Linked to Schedule',
 value: '$linkedToSched/${_items.length}',
 color: linkedToSched == _items.length
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: DataTable(
 columnSpacing: 20,
 horizontalMargin: 16,
 headingRowHeight: 48,
 dataRowMinHeight: 44,
 dataRowMaxHeight: 80,
 columns: const [
 DataColumn(label: Center(child: Text('Scope Item',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))))),
 DataColumn(label: Center(child: Text('WBS',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))))),
 DataColumn(label: Center(child: Text('Requirement',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))))),
 DataColumn(label: Center(child: Text('Schedule',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))))),
 DataColumn(label: Center(child: Text('Status',
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))))),
 ],
 rows: _items.map((item) {
 final wbsTitle = item.wbsId.isNotEmpty
 ? flatWbs.where((w) => w.id == item.wbsId).firstOrNull?.title ?? 'Unknown'
 : '';
 final reqText = item.requirementId.isNotEmpty
 ? requirements.where((r) => r.id == item.requirementId).firstOrNull?.plannedText ?? ''
 : '';
 final schedTitle = item.scheduleActivityId.isNotEmpty
 ? scheduleActivities.where((s) => s.id == item.scheduleActivityId).firstOrNull?.title ?? ''
 : '';

 return DataRow(cells: [
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 180),
 child: Text(item.scopeItem,
 style: const TextStyle(fontSize: 11),
 maxLines: 2, overflow: TextOverflow.ellipsis),
 )),
 DataCell(Center(
 child: _LinkBadge(
 label: wbsTitle.isEmpty ? 'Unlinked' : wbsTitle,
 linked: item.wbsId.isNotEmpty,
 ),
 )),
 DataCell(Center(
 child: _LinkBadge(
 label: reqText.isEmpty ? 'Unlinked' : reqText,
 linked: item.requirementId.isNotEmpty,
 ),
 )),
 DataCell(Center(
 child: _LinkBadge(
 label: schedTitle.isEmpty ? 'Unlinked' : schedTitle,
 linked: item.scheduleActivityId.isNotEmpty,
 ),
 )),
 DataCell(Center(
 child: _StatusBadge(status: item.implementationStatus),
 )),
 ]);
 }).toList(),
 ),
 ),
 ),
 const SizedBox(height: 24),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFFEAD0)),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline, size: 18, color: Color(0xFF9A3412)),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 'To link scope items, edit them in the Scope Registry tab and set the WBS, Requirement, or Schedule Activity ID fields.',
 style: const TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }

 Widget _buildBaselineTab() {
 final baselineItems = _items.where((i) => i.isBaseline).toList();
 final creepItems = _items.where((i) => !i.isBaseline).toList();
 final completed = _items.where((i) => i.implementationStatus == 'Verified').length;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 FilledButton.icon(
 onPressed: _setBaseline,
 icon: const Icon(Icons.lock_outline, size: 18),
 label: const Text('Set Baseline'),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF10B981),
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 12),
 if (baselineItems.isNotEmpty)
 TextButton.icon(
 onPressed: () => _showCompareDialog(baselineItems, creepItems),
 icon: const Icon(Icons.compare_arrows, size: 16),
 label: const Text('Compare'),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _BaselineStatCard(
 label: 'Baseline Scope',
 value: '${baselineItems.length} items',
 color: const Color(0xFFD97706),
 icon: Icons.lock_outline,
 ),
 _BaselineStatCard(
 label: 'Completed',
 value: '$completed/${_items.length}',
 color: const Color(0xFF10B981),
 icon: Icons.check_circle_outline,
 ),
 _BaselineStatCard(
 label: 'Scope Creep',
 value: '${creepItems.length} items',
 color: creepItems.isEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFFEF4444),
 icon: Icons.warning_amber_outlined,
 ),
 _BaselineStatCard(
 label: 'Scope Growth',
 value: baselineItems.isEmpty
 ? '0%'
 : '${((creepItems.length / baselineItems.length) * 100).toStringAsFixed(0)}%',
 color: creepItems.isEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 icon: Icons.trending_up,
 ),
 ],
 ),
 const SizedBox(height: 24),
 if (baselineItems.isNotEmpty) ...[
 const Text('Baseline Scope Items',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const SizedBox(height: 12),
 _buildItemList(baselineItems, const Color(0xFF10B981)),
 ],
 if (creepItems.isNotEmpty) ...[
 const SizedBox(height: 20),
 Row(
 children: [
 const Text('Scope Added Since Baseline',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const SizedBox(width: 8),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFFEE2E2),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text('${creepItems.length}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFFEF4444))),
 ),
 ],
 ),
 const SizedBox(height: 12),
 _buildItemList(creepItems, const Color(0xFFEF4444)),
 ],
 ],
 );
 }

 Widget _buildItemList(List<ScopeTrackingItem> items, Color accent) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Material(
  type: MaterialType.transparency,
  child: Column(
 children: items.map((item) {
 return ListTile(
 dense: true,
 leading: Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: accent,
 shape: BoxShape.circle,
 ),
 ),
 title: Text(item.scopeItem,
 style: const TextStyle(fontSize: 13)),
 subtitle: item.owner.isNotEmpty
 ? Text(item.owner,
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
 : null,
 trailing: _StatusBadge(status: item.implementationStatus),
 );
 }).toList(),
 ),
 ),
 );
 }

 void _showCompareDialog(
 List<ScopeTrackingItem> baseline, List<ScopeTrackingItem> creep) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Baseline Comparison'),
 content: SizedBox(
 width: 400,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _compareRow('Baseline Items', '${baseline.length}',
 const Color(0xFFD97706)),
 const SizedBox(height: 12),
 _compareRow('Scope Creep', '${creep.length}',
 const Color(0xFFEF4444)),
 const SizedBox(height: 12),
 _compareRow(
 'Total',
 '${baseline.length + creep.length}',
 const Color(0xFF111827)),
 const SizedBox(height: 12),
 _compareRow(
 'Creep Ratio',
 baseline.isEmpty
 ? 'N/A'
 : '${((creep.length / baseline.length) * 100).toStringAsFixed(1)}%',
 creep.length > baseline.length * 0.1
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981)),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Close'),
 ),
 ],
 ),
 );
 }

 Widget _compareRow(String label, String value, Color color) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
 Text(value,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 );
 }

 void _showAddItemDialog() {
 final nameCtrl = TextEditingController();
 final typeCtrl = TextEditingController(text: 'predictive');
 final statusCtrl = TextEditingController(text: 'Not Started');
 final ownerCtrl = TextEditingController();

 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Add Scope Item'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameCtrl,
 decoration: const InputDecoration(
 labelText: 'Scope Item',
 hintText: 'Describe the scope item',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 style: const TextStyle(fontSize: 13),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<String>(
 value: 'predictive',
 decoration: const InputDecoration(
 labelText: 'Scope Type',
 border: OutlineInputBorder(),
 isDense: true,
 contentPadding:
 EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 items: const [
 DropdownMenuItem(
 value: 'predictive', child: Text('Predictive', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'ewp', child: Text('Engineering WP', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'cwp', child: Text('Construction WP', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'epic', child: Text('Agile Epic', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'feature', child: Text('Agile Feature', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'story', child: Text('User Story', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'procurement',
 child: Text('Procurement Package', style: TextStyle(fontSize: 13))),
 ],
 onChanged: (v) => typeCtrl.text = v ?? 'predictive',
 style: const TextStyle(fontSize: 13),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<String>(
 value: 'Not Started',
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 isDense: true,
 contentPadding:
 EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 items: const [
 DropdownMenuItem(
 value: 'Not Started', child: Text('Not Started', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'In-Progress', child: Text('In Progress', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'Verified', child: Text('Verified', style: TextStyle(fontSize: 13))),
 DropdownMenuItem(
 value: 'Out-of-Scope',
 child: Text('Out of Scope', style: TextStyle(fontSize: 13))),
 ],
 onChanged: (v) => statusCtrl.text = v ?? 'Not Started',
 style: const TextStyle(fontSize: 13),
 ),
 const SizedBox(height: 16),
 Autocomplete<String>(
 optionsBuilder: (textEditingValue) {
 if (textEditingValue.text.isEmpty) {
 return _availableRoles;
 }
 return _availableRoles.where((role) => role
 .toLowerCase()
 .contains(textEditingValue.text.toLowerCase()));
 },
 fieldViewBuilder:
 (context, controller, focusNode, onSubmitted) {
 ownerCtrl.text = controller.text;
 return VoiceTextField(
 controller: controller,
 focusNode: focusNode,
 decoration: const InputDecoration(
 labelText: 'Owner',
 hintText: 'Select or type owner',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 style: const TextStyle(fontSize: 13),
 );
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () {
 final name = nameCtrl.text.trim();
 if (name.isEmpty) return;
 _addItem(ScopeTrackingItem(
 scopeItem: name,
 scopeType: typeCtrl.text,
 implementationStatus: statusCtrl.text,
 owner: ownerCtrl.text,
 isBaseline: _items.every((i) => i.isBaseline) || _items.isEmpty,
 ));
 Navigator.of(ctx).pop();
 },
 child: const Text('Add'),
 ),
 ],
 ),
 );
 }

 Future<void> _generateMissingScopeItems() async {
 final projectId = _projectId;
 if (projectId == null) return;

 final usedNames =
 _items.map((i) => i.scopeItem.trim().toLowerCase()).toSet();

 final data = ProjectDataHelper.getData(context);
 final existingDescriptions = [
 ...data.planningRequirementItems.map((r) => r.plannedText),
 ..._flattenWbsItems(data.wbsTree).map((w) => w.title),
 ];

 final missing = existingDescriptions
 .where((d) => d.trim().isNotEmpty && !usedNames.contains(d.trim().toLowerCase()))
 .toSet()
 .toList();

 if (missing.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No missing scope items found.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 return;
 }

 final newItems = missing.map((text) {
 return ScopeTrackingItem(
 scopeItem: text,
 isBaseline: true,
 scopeType: 'predictive',
 );
 }).toList();

 setState(() => _items.addAll(newItems));
 await _saveItems();

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Added ${newItems.length} missing scope items.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

 List<WorkItem> _flattenWbsItems(List<WorkItem>? items) {
 final result = <WorkItem>[];
 void walk(List<WorkItem> list) {
 for (final item in list) {
 result.add(item);
 if (item.children.isNotEmpty) walk(item.children);
 }
 }
 if (items != null) walk(items);
 return result;
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Scope Tracking Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_scope_tracking_plan_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _ScopeMetricData {
 final String label;
 final int value;
 final Color color;
 final String description;
 final IconData icon;

 const _ScopeMetricData(this.label, this.value, this.color, this.description, this.icon);
}

class _ScopeMetricCard extends StatelessWidget {
 final _ScopeMetricData data;
 final double width;

 const _ScopeMetricCard({required this.data, required this.width});

 @override
 Widget build(BuildContext context) {
 return Container(
 width: width,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: data.color.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(
 color: data.color.withOpacity(0.06),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(data.icon, size: 16, color: data.color),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: data.color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 data.label,
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w600,
 color: data.color),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 '${data.value}',
 style: TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: data.color),
 ),
 const SizedBox(height: 6),
 Text(
 data.description,
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 );
 }
}

class _TraceStat extends StatelessWidget {
 final String label;
 final String value;
 final Color color;

 const _TraceStat(
 {required this.label, required this.value, required this.color});

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.2)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
 ),
 const SizedBox(width: 10),
 Text(label,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(width: 10),
 Text(value,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 ),
 );
 }
}

class _LinkBadge extends StatelessWidget {
 final String label;
 final bool linked;

 const _LinkBadge({required this.label, required this.linked});

 @override
 Widget build(BuildContext context) {
 final color =
 linked ? const Color(0xFF10B981) : const Color(0xFF9CA3AF);
 return Container(
 constraints: const BoxConstraints(maxWidth: 140),
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w500,
 color: color),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 textAlign: TextAlign.center,
 ),
 );
 }
}

class _StatusBadge extends StatelessWidget {
 final String status;

 const _StatusBadge({required this.status});

 Color _color() {
 switch (status) {
 case 'Not Started':
 return const Color(0xFF9CA3AF);
 case 'In-Progress':
 return const Color(0xFFD97706);
 case 'Verified':
 return const Color(0xFF10B981);
 case 'Out-of-Scope':
 return const Color(0xFFEF4444);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 @override
 Widget build(BuildContext context) {
 final c = _color();
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: c.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 10, fontWeight: FontWeight.w600, color: c),
 ),
 );
 }
}

class _BaselineStatCard extends StatelessWidget {
 final String label;
 final String value;
 final Color color;
 final IconData icon;

 const _BaselineStatCard(
 {required this.label,
 required this.value,
 required this.color,
 required this.icon});

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 180,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: color.withOpacity(0.15)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(icon, size: 20, color: color),
 const SizedBox(height: 12),
 Text(value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: color)),
 const SizedBox(height: 4),
 Text(label,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ],
 ),
 );
 }
}

class _ScopeTrackingHeader extends StatelessWidget {
 const _ScopeTrackingHeader({
 required this.onBack,
 required this.onForward,
 this.onRegenerateAll,
 this.isRegenerating = false,
 });

 final VoidCallback onBack;
 final VoidCallback onForward;
 final VoidCallback? onRegenerateAll;
 final bool isRegenerating;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Row(
 children: [
 _RoundIconButton(
 icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 10),
 _RoundIconButton(
 icon: Icons.arrow_forward_ios_rounded, onTap: onForward),
 const SizedBox(width: 16),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Scope Tracking Plan',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Govern scope integrity, change control, and variance signals across delivery.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 if (onRegenerateAll != null)
 Padding(
 padding: const EdgeInsets.only(right: 12),
 child: IconButton(
 onPressed: isRegenerating ? null : onRegenerateAll,
 icon: isRegenerating
 ? const SizedBox(
 width: 18,
 height: 18,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome),
 tooltip: 'Regenerate All Scope Items',
 style: IconButton.styleFrom(
 backgroundColor: const Color(0xFFFFF7ED),
 foregroundColor: const Color(0xFF9A3412),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 const SizedBox(width: 8),
 const _PlanStatusPill(label: 'Active'),
 ],
 ),
 );
 }
}

class _RoundIconButton extends StatelessWidget {
 const _RoundIconButton({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(16),
 child: Container(
 width: 34,
 height: 34,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 14, color: const Color(0xFF6B7280)),
 ),
 );
 }
}

class _PlanStatusPill extends StatelessWidget {
 const _PlanStatusPill({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFF10B981),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
 ),
 );
 }
}

class _ScopeTrackingHero extends StatelessWidget {
 const _ScopeTrackingHero();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFFFFF7CC), Color(0xFFFFFBEB)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFF5E7A5)),
 ),
 child: Row(
 children: [
 Container(
 width: 52,
 height: 52,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFF2E2A4)),
 ),
 child: const Icon(Icons.track_changes_outlined,
 color: Color(0xFFB45309)),
 ),
 const SizedBox(width: 16),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Scope Guardrails',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF92400E)),
 ),
 SizedBox(height: 6),
 Text(
 'Baseline scope, govern changes, and detect drift before impact escalates.',
 style: TextStyle(fontSize: 13, color: Color(0xFF7C5C1A)),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFF2E2A4)),
 ),
 child: const Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Scope Health',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 SizedBox(height: 4),
 Text('Stable',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _ScopeControlPlaybook extends StatelessWidget {
 const _ScopeControlPlaybook();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Scope Control Playbook',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Use AI to draft scope boundaries, approval criteria, and escalation triggers.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 SizedBox(height: 16),
 _ScopeTrackingTextField(
 fieldLabel: 'Scope Baseline Statement',
 noteKey: 'scope_tracking_baseline_statement',
 hintText: 'Define what is in-scope, out-of-scope, and assumptions.',
 ),
 SizedBox(height: 16),
 _ScopeTrackingTextField(
 fieldLabel: 'Change Control Criteria',
 noteKey: 'scope_tracking_change_criteria',
 hintText: 'Document thresholds and criteria for approval.',
 ),
 SizedBox(height: 16),
 _ScopeTrackingTextField(
 fieldLabel: 'Escalation Triggers',
 noteKey: 'scope_tracking_escalation_triggers',
 hintText: 'Specify conditions that require executive review.',
 ),
 ],
 ),
 );
 }
}

class _ScopeTrackingTextField extends StatefulWidget {
 const _ScopeTrackingTextField({
 required this.fieldLabel,
 required this.noteKey,
 required this.hintText,
 });

 final String fieldLabel;
 final String noteKey;
 final String hintText;

 @override
 State<_ScopeTrackingTextField> createState() =>
 _ScopeTrackingTextFieldState();
}

class _ScopeTrackingTextFieldState extends State<_ScopeTrackingTextField> {
 String _currentText = '';
 Timer? _saveDebounce;
 DateTime? _lastSavedAt;

 @override
 void dispose() {
 _saveDebounce?.cancel();
 super.dispose();
 }

 void _handleChanged(String value) {
 _currentText = value;
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 700), () async {
 final trimmed = value.trim();
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'planning_${widget.noteKey}',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 widget.noteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 if (mounted && success) {
 setState(() => _lastSavedAt = DateTime.now());
 }
 });
 }

 @override
 Widget build(BuildContext context) {
 if (_currentText.isEmpty) {
 final saved =
 ProjectDataHelper.getData(context).planningNotes[widget.noteKey] ??
 '';
 if (saved.trim().isNotEmpty) {
 _currentText = saved;
 }
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 AiSuggestingTextField(
 fieldLabel: widget.fieldLabel,
 hintText: widget.hintText,
 sectionLabel: 'Scope Tracking Plan',
 autoGenerate: true,
 autoGenerateSection: widget.fieldLabel,
 initialText:
 ProjectDataHelper.getData(context).planningNotes[widget.noteKey],
 onChanged: _handleChanged,
 ),
 if (_lastSavedAt != null)
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
 ),
 ),
 ],
 );
 }
}

class _ChangeIntakeCard extends StatelessWidget {
 const _ChangeIntakeCard();

 @override
 Widget build(BuildContext context) {
 return _ScopeCardShell(
 title: 'Change Intake Workflow',
 subtitle: 'Standardize how scope changes move through governance.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 _WorkflowStep(
 step: '1',
 title: 'Submit request',
 detail: 'Form + business case'),
 _WorkflowStep(
 step: '2',
 title: 'Triage & assign',
 detail: 'PMO + workstream lead'),
 _WorkflowStep(
 step: '3',
 title: 'Impact analysis',
 detail: 'Cost, schedule, risk'),
 _WorkflowStep(
 step: '4',
 title: 'Board review',
 detail: 'Weekly change control'),
 _WorkflowStep(
 step: '5',
 title: 'Approve & baseline',
 detail: 'Update scope logs'),
 ],
 ),
 );
 }
}

class _GovernanceCadenceCard extends StatelessWidget {
 const _GovernanceCadenceCard();

 @override
 Widget build(BuildContext context) {
 return _ScopeCardShell(
 title: 'Governance Cadence',
 subtitle: 'Oversight rhythm for scope health.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _CadenceRow(
 label: 'Change control board', value: 'Weekly • Tue 10:00'),
 const _CadenceRow(
 label: 'Scope health review', value: 'Bi-weekly • Fri 14:00'),
 const _CadenceRow(
 label: 'Executive checkpoint', value: 'Monthly • 1st Thu'),
 const SizedBox(height: 16),
 const Text(
 'Next session agenda',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 const _ScopeBullet(text: 'Review open CRs and fast-track decisions'),
 const _ScopeBullet(text: 'Validate variance vs baseline'),
 const _ScopeBullet(text: 'Confirm mitigation owners'),
 ],
 ),
 );
 }
}

class _DriftSignalsCard extends StatelessWidget {
 const _DriftSignalsCard();

 @override
 Widget build(BuildContext context) {
 return _ScopeCardShell(
 title: 'Scope Drift Signals',
 subtitle: 'Early warnings to protect delivery.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _ScopeBullet(text: 'Unplanned work added in sprints'),
 const _ScopeBullet(text: 'Variance > 3% for two cycles'),
 const _ScopeBullet(text: 'Dependencies added without CR'),
 const SizedBox(height: 16),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: const [
 _ScopeTag(label: '3 Active Alerts', tone: Color(0xFFF59E0B)),
 _ScopeTag(label: '1 Escalation', tone: Color(0xFFEF4444)),
 _ScopeTag(label: 'Risk Score: Medium', tone: Color(0xFF6366F1)),
 ],
 ),
 ],
 ),
 );
 }
}

class _ScopeCardShell extends StatelessWidget {
 const _ScopeCardShell({
 required this.title,
 required this.subtitle,
 required this.child,
 });

 final String title;
 final String subtitle;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(subtitle,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

class _ScopeBullet extends StatelessWidget {
 const _ScopeBullet({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.check_circle_outline,
 size: 16, color: Color(0xFF10B981)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF374151), height: 1.4),
 ),
 ),
 ],
 ),
 );
 }
}

class _ScopeTag extends StatelessWidget {
 const _ScopeTag({required this.label, this.tone});

 final String label;
 final Color? tone;

 @override
 Widget build(BuildContext context) {
 final color = tone ?? const Color(0xFF111827);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style:
 TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
 ),
 );
 }
}

class _WorkflowStep extends StatelessWidget {
 const _WorkflowStep({
 required this.step,
 required this.title,
 required this.detail,
 });

 final String step;
 final String title;
 final String detail;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: const Color(0xFFFDE68A),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Center(
 child: Text(
 step,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF92400E)),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(detail,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _CadenceRow extends StatelessWidget {
 const _CadenceRow({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Expanded(
 child: Text(label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
 ),
 Text(
 value,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ],
 ),
 );
 }
}
