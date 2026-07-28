import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';
import 'package:ndu_project/models/procurement/procurement_workflow_step.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/services/contract_service.dart'
 as planning_contracts;
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/services/planning_contracting_service.dart';
import 'package:ndu_project/services/procurement_seeding_service.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/services/procurement_workflow_service.dart';
import 'package:ndu_project/services/schedule_linkage_service.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/procurement/budget_tracking_table.dart';
import 'package:ndu_project/widgets/procurement/po_approval_dialog.dart';
import 'package:ndu_project/widgets/procurement_dialogs.dart';
import 'package:ndu_project/widgets/procurement/procurement_common_widgets.dart';
import 'package:ndu_project/widgets/procurement/procurement_items_list_view.dart';
import 'package:ndu_project/widgets/procurement/procurement_reports_view.dart';
import 'package:ndu_project/widgets/procurement/procurement_timeline_view.dart';
import 'package:ndu_project/widgets/procurement/procurement_vendor_management.dart';
import 'package:ndu_project/widgets/procurement/procurement_workflow_builder.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class PlanningProcurementV2Screen extends StatefulWidget {
 const PlanningProcurementV2Screen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const PlanningProcurementV2Screen()),
 );
 }

 @override
 State<PlanningProcurementV2Screen> createState() =>
 _PlanningProcurementV2ScreenState();
}

class _PlanningProcurementV2ScreenState
 extends State<PlanningProcurementV2Screen> {
 static const List<ProcurementWorkflowStep> _defaultProcurementWorkflowTemplate = [
 ProcurementWorkflowStep(
 id: 'request_for_quote',
 name: 'Request for Quote (RFQ)',
 duration: 2,
 unit: 'week',
 ),
 ProcurementWorkflowStep(
 id: 'quote_evaluation',
 name: 'Quote Evaluation',
 duration: 2,
 unit: 'week',
 ),
 ProcurementWorkflowStep(
 id: 'request_for_information',
 name: 'Request for Information',
 duration: 1,
 unit: 'week',
 ),
 ProcurementWorkflowStep(
 id: 'purchase_order',
 name: 'Purchase Order',
 duration: 1,
 unit: 'week',
 ),
 ];

 static const List<String> _tabLabels = [
 'Overview',
 'Procurement Items',
 'Timeline',
 'Vendor Management',
 'Purchase Orders',
 'Budget Tracking',
 'Workflows',
 'Reports',
 ];

 final List<StreamSubscription<dynamic>> _subscriptions = [];

 int _selectedTab = 0;
 String _projectId = '';
 bool _didInitialize = false;
 bool _seedCheckRunning = false;
 bool _workflowLoading = false;
 bool _workflowSaving = false;
 bool _customizeWorkflowByScope = false;

 List<ProcurementItemModel> _items = const [];
 List<ProcurementItemModel> _trackableItems = const [];
 int _selectedTrackableIndex = 0;
 List<PurchaseOrderModel> _pos = const [];
 List<PlanningRfq> _rfqs = const [];
 List<planning_contracts.ContractModel> _contracts = const [];
 String? _selectedWorkflowScopeId;
 List<ProcurementWorkflowStep> _globalWorkflowSteps =
 List<ProcurementWorkflowStep>.from(_defaultProcurementWorkflowTemplate);
 List<ProcurementWorkflowStep> _workflowDraftSteps =
 List<ProcurementWorkflowStep>.from(_defaultProcurementWorkflowTemplate);
 Map<String, List<ProcurementWorkflowStep>> _scopeWorkflowOverrides = const {};

 List<VendorModel> _vendors = const [];
 final Set<String> _selectedVendorIds = {};
 bool _approvedOnly = false;
 bool _preferredOnly = false;
 bool _listView = true;
 String _categoryFilter = 'All Categories';

 final List<VendorHealthMetric> _vendorHealthMetrics = const [];
 final List<VendorOnboardingTask> _vendorOnboardingTasks = const [];
 final List<VendorRiskItem> _vendorRiskItems = const [];

 List<ReportKpi> _reportKpis = const [];
 List<SpendBreakdown> _spendBreakdownList = const [];
 List<LeadTimeMetric> _leadTimeMetrics = const [];
 List<SavingsOpportunity> _savingsOpportunities = const [];
 List<ComplianceMetric> _complianceMetrics = const [];

 StreamSubscription<List<VendorModel>>? _vendorsSub;

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_didInitialize) return;

 final data = ProjectDataHelper.getData(context);
 _projectId = data.projectId ?? '';
 _didInitialize = true;

 if (_projectId.isEmpty) {
 return;
 }

 _subscribeToData();
 Future.microtask(() async {
 if (!mounted) return;
 await _loadProcurementWorkflowData();
 if (!mounted) return;
 await ScheduleLinkageService.checkAndSyncOnOpen(context);
 if (!mounted) return;
 await _checkAutoSeed();
 });
 }

 @override
 void dispose() {
 for (final subscription in _subscriptions) {
 subscription.cancel();
 }
 _vendorsSub?.cancel();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Planning Procurement',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 20 : 40,
 vertical: isMobile ? 20 : 32,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Procurement', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(context),
 const SizedBox(height: 24),
 _buildTabBar(),
 const SizedBox(height: 24),
 _buildTabContent(),
 const SizedBox(height: 96),
 ],
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Planning Procurement',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context) {
 final data = ProjectDataHelper.getData(context, listen: true);
 final summaryCards = [
 _SummaryCardData(
 label: 'Items',
 value: '${_items.length}',
 supporting: 'Procurement records in planning',
 ),
 _SummaryCardData(
 label: 'Pending POs',
 value: '${_pos.where((po) => po.approvalStatus == 'pending').length}',
 supporting: 'Awaiting approval',
 ),
 _SummaryCardData(
 label: 'RFQs',
 value: '${_rfqs.length}',
 supporting: 'Planning RFQs feeding procurement',
 ),
 _SummaryCardData(
 label: 'Contracts',
 value: '${_contracts.length}',
 supporting: 'Live procurement contracts',
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Planning Procurement',
 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Continue procurement planning with contracting handoff, '
 'schedule-linked items, and approval tracking for ${data.projectName.isNotEmpty ? data.projectName : 'this project'}.',
 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
 color: const Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => PlanningContractingScreen.open(context),
 icon: const Icon(Icons.arrow_back),
 label: const Text('Open Contracting'),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: summaryCards
 .map((card) => _SummaryCard(card: card))
 .toList(growable: false),
 ),
 ],
 );
 }

 Widget _buildTabBar() {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: List<Widget>.generate(_tabLabels.length, (index) {
 final selected = index == _selectedTab;
 return ChoiceChip(
 label: Text(_tabLabels[index]),
 selected: selected,
 onSelected: (_) => setState(() => _selectedTab = index),
 selectedColor: const Color(0xFF111827),
 labelStyle: TextStyle(
 color: selected ? Colors.white : const Color(0xFF111827),
 fontWeight: FontWeight.w600,
 ),
 backgroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 side: BorderSide(
 color: selected
 ? const Color(0xFF111827)
 : const Color(0xFFE5E7EB),
 ),
 ),
 );
 }),
 );
 }

 Widget _buildTabContent() {
 switch (_selectedTab) {
 case 0:
 return _buildOverviewTab();
 case 1:
 return _buildItemsTab();
 case 2:
 return _buildTimelineTab();
 case 3:
 return _buildVendorManagementTab();
 case 4:
 return _buildPurchaseOrdersTab();
 case 5:
 return _buildBudgetTrackingTab();
 case 6:
 return _buildWorkflowsTab();
 case 7:
 return _buildReportsTab();
 default:
 return const SizedBox.shrink();
 }
 }

 Widget _buildOverviewTab() {
 final data = ProjectDataHelper.getData(context, listen: true);
 final pendingApprovals =
 _pos.where((po) => po.approvalStatus == 'pending').toList();
 final overdueItems =
 ScheduleLinkageService.getOverdueItems(_items).take(5).toList();
 final totalBudget =
 _items.fold<double>(0, (v, i) => v + i.budget);
 final totalSpend =
 _pos.fold<double>(0, (t, po) => t + po.amount);
 final committedRate = totalBudget == 0
 ? 0
 : ((totalSpend / totalBudget) * 100).round();

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFF78350F), Color(0xFF2D5A8E)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(18),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Planning Procurement Overview',
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Plan and manage procurement items, vendors, purchase orders, '
 'and budgets for ${data.projectName.isNotEmpty ? data.projectName : 'this project'}. '
 'Items flow in from contracting handoff.',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.8),
 fontSize: 13,
 ),
 ),
 const SizedBox(height: 20),
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _OverviewStat(
 label: 'Procurement Items',
 value: '${_items.length}',
 icon: Icons.inventory_2_outlined,
 ),
 _OverviewStat(
 label: 'Pending Approvals',
 value: '${pendingApprovals.length}',
 icon: Icons.approval_outlined,
 ),
 _OverviewStat(
 label: 'Overdue Items',
 value: '${overdueItems.length}',
 icon: Icons.warning_amber_rounded,
 ),
 _OverviewStat(
 label: 'Budget Committed',
 value: '$committedRate%',
 icon: Icons.attach_money_outlined,
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _SectionCard(
 title: 'Contracting Handoff',
 subtitle:
 'RFQs from contract planning feed procurement items. '
 'Complete evaluation in contracting to push RFQs here.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StatRow(
 label: 'RFQs in handoff',
 value: '${_rfqs.length}',
 icon: Icons.request_quote_outlined,
 ),
 const SizedBox(height: 8),
 _StatRow(
 label: 'Active contracts',
 value: '${_contracts.length}',
 icon: Icons.assignment_outlined,
 ),
 const SizedBox(height: 12),
 OutlinedButton.icon(
 onPressed: () =>
 PlanningContractingScreen.open(context),
 icon: const Icon(Icons.arrow_forward, size: 16),
 label: const Text('Open Contracting'),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: _SectionCard(
 title: 'Schedule Alignment',
 subtitle:
 'Items linked to schedule milestones sync '
 'required-by dates automatically.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StatRow(
 label: 'Linked to milestone',
 value:
 '${_items.where((i) => i.linkedMilestoneId != null).length}',
 icon: Icons.event_outlined,
 ),
 const SizedBox(height: 8),
 _StatRow(
 label: 'Overdue items',
 value: '${overdueItems.length}',
 icon: Icons.schedule_outlined,
 ),
 const SizedBox(height: 12),
 OutlinedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.sync, size: 16),
 label: const Text('Sync Schedule'),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: _SectionCard(
 title: 'Vendors & Reports',
 subtitle:
 'Manage vendor relationships and view procurement '
 'performance metrics.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _StatRow(
 label: 'Active vendors',
 value: '${_vendors.length}',
 icon: Icons.storefront_outlined,
 ),
 const SizedBox(height: 8),
 _StatRow(
 label: 'Purchase orders',
 value: '${_pos.length}',
 icon: Icons.receipt_long_outlined,
 ),
 const SizedBox(height: 12),
 OutlinedButton.icon(
 onPressed: () =>
 setState(() => _selectedTab = 7),
 icon: const Icon(Icons.auto_awesome, size: 16),
 label: const Text('View Reports'),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildItemsTab() {
 final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
 return ProcurementItemsListView(
 items: _items,
 trackableItems: _trackableItems,
 selectedIndex: _selectedTrackableIndex,
 onSelectTrackable: (index) =>
 setState(() => _selectedTrackableIndex = index),
 currencyFormat: currencyFormat,
 onAddItem: _openAddItemDialog,
 onEditItem: (item) => _openEditItemDialog(item),
 onDeleteItem: (item) => _removeItem(item),
 );
 }

 List<Widget> _buildDialogContextChips() {
 final data = ProjectDataHelper.getData(context);
 return [
 if (data.projectName.trim().isNotEmpty)
 ContextChip(label: 'Project', value: data.projectName.trim()),
 if (data.solutionTitle.trim().isNotEmpty)
 ContextChip(label: 'Solution', value: data.solutionTitle.trim()),
 ContextChip(label: 'Phase', value: 'Planning'),
 ];
 }

 List<ProcurementAssignableMemberOption> _assignableMembers() {
 final data = ProjectDataHelper.getData(context);
 final options = <ProcurementAssignableMemberOption>[];
 if (data.charterProjectManagerName.trim().isNotEmpty) {
 options.add(
 ProcurementAssignableMemberOption(
 id: 'project_manager',
 name: data.charterProjectManagerName.trim(),
 email: '',
 role: 'Project Manager',
 source: 'Charter',
 ),
 );
 }
 if (data.charterProjectSponsorName.trim().isNotEmpty) {
 options.add(
 ProcurementAssignableMemberOption(
 id: 'project_sponsor',
 name: data.charterProjectSponsorName.trim(),
 email: '',
 role: 'Project Sponsor',
 source: 'Charter',
 ),
 );
 }
 return options;
 }

 Future<void> _openAddItemDialog() async {
 final result = await showDialog<ProcurementItemModel>(
 context: context,
 builder: (dialogContext) {
 return AddItemDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: const [
 'Materials',
 'Equipment',
 'Services',
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Other',
 ],
 responsibleOptions: _assignableMembers(),
 showAiGenerateButton: false,
 itemDomainLabel: 'Procurement',
 );
 },
 );

 if (result == null) return;
 try {
 final normalized = result.copyWith(projectId: _projectId);
 await ProcurementService.createItem(normalized);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Added item "${normalized.name}".')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error creating procurement item: $e')),
 );
 }
 }

 Future<void> _openEditItemDialog(ProcurementItemModel item) async {
 final result = await showDialog<ProcurementItemModel>(
 context: context,
 builder: (dialogContext) {
 return AddItemDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: const [
 'Materials',
 'Equipment',
 'Services',
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Other',
 ],
 responsibleOptions: _assignableMembers(),
 initialItem: item,
 showAiGenerateButton: false,
 itemDomainLabel: 'Procurement',
 );
 },
 );

 if (result == null) return;
 try {
 await ProcurementService.updateItem(_projectId, item.id, {
 'name': result.name.trim(),
 'description': result.description.trim(),
 'category': result.category.trim(),
 'status': result.status.name,
 'priority': result.priority.name,
 'budget': result.budget,
 'spent': result.spent,
 'estimatedDelivery': result.estimatedDelivery,
 'actualDelivery': result.actualDelivery,
 'progress': result.progress.clamp(0.0, 1.0),
 'vendorId': result.vendorId,
 'contractId': result.contractId,
 'events': result.events.map((event) => event.toJson()).toList(),
 'notes': result.notes,
 'projectPhase': result.projectPhase,
 'responsibleMember': result.responsibleMember,
 'comments': result.comments,
 });
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Updated item "${result.name}".')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to edit item: $e')),
 );
 }
 }

 Future<void> _removeItem(ProcurementItemModel item) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Remove Procurement Item'),
 content: Text(
 'Delete "${item.name}"? This action cannot be undone.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFDC2626),
 foregroundColor: Colors.white,
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 ) ??
 false;
 if (!confirmed) return;

 try {
 await ProcurementService.deleteItem(_projectId, item.id);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Deleted item "${item.name}".')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to delete item: $e')),
 );
 }
 }

 Future<void> _openAddVendorDialog() async {
 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Services',
 'Materials',
 'Other',
 ];

 final result = await showDialog<VendorModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withValues(alpha: 0.45),
 builder: (dialogContext) {
 return AddVendorDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 showAiGenerateButton: false,
 partnerLabel: 'Vendor',
 partnerPluralLabel: 'Vendors',
 existingPartners: _vendors,
 allowExistingAutofill: true,
 );
 },
 );

 if (result == null) return;
 try {
 final normalizedName = result.name.trim().toLowerCase();
 final alreadyExists = _vendors.any(
 (vendor) => vendor.name.trim().toLowerCase() == normalizedName,
 );
 if (alreadyExists) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Vendor already exists.'),
 ),
 );
 }
 return;
 }
 await VendorService.createVendor(
 projectId: _projectId,
 name: result.name,
 category: result.category,
 criticality: result.criticality,
 rating: result.rating,
 status: result.status,
 sla: result.sla,
 slaPerformance: result.slaPerformance,
 leadTime: result.leadTime,
 requiredDeliverables: result.requiredDeliverables,
 nextReview: result.nextReview,
 onTimeDelivery: result.onTimeDelivery,
 incidentResponse: result.incidentResponse,
 qualityScore: result.qualityScore,
 costAdherence: result.costAdherence,
 createdById: 'user',
 createdByEmail: 'user@email',
 createdByName: 'User',
 );
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Vendor added.')),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to add vendor: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _openEditVendorDialog(VendorModel vendor) async {
 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Services',
 'Materials',
 'Other',
 ];

 final result = await showDialog<VendorModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withValues(alpha: 0.45),
 builder: (dialogContext) {
 return AddVendorDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 initialVendor: vendor,
 showAiGenerateButton: false,
 partnerLabel: 'Vendor',
 partnerPluralLabel: 'Vendors',
 existingPartners: _vendors,
 allowExistingAutofill: true,
 );
 },
 );

 if (result == null) return;
 try {
 await VendorService.updateVendor(
 projectId: _projectId,
 vendorId: vendor.id,
 name: result.name,
 category: result.category,
 criticality: result.criticality,
 sla: result.sla,
 slaPerformance: result.slaPerformance,
 leadTime: result.leadTime,
 requiredDeliverables: result.requiredDeliverables,
 rating: result.rating,
 status: result.status,
 nextReview: result.nextReview,
 onTimeDelivery: result.onTimeDelivery,
 incidentResponse: result.incidentResponse,
 qualityScore: result.qualityScore,
 costAdherence: result.costAdherence,
 notes: result.notes,
 );
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Vendor updated.')),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to update vendor: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _openInviteVendorDialog() async {
 final nameController = TextEditingController();
 final emailController = TextEditingController();

 final sent = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Invite Vendor'),
 content: SizedBox(
 width: 460,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Vendor or Contact Name (Optional)',
 hintText: 'e.g. Acme Supplies',
 ),
 textCapitalization: TextCapitalization.words,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: emailController,
 decoration: const InputDecoration(
 labelText: 'Email Address',
 hintText: 'name@company.com',
 ),
 keyboardType: TextInputType.emailAddress,
 textInputAction: TextInputAction.send,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final email = emailController.text.trim();
 final isEmailValid = RegExp(
 r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
 ).hasMatch(email);
 if (!isEmailValid) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Enter a valid email address.'),
 ),
 );
 return;
 }
 Navigator.of(dialogContext).pop(true);
 },
 child: const Text('Send Invite'),
 ),
 ],
 ),
 );

 nameController.dispose();
 emailController.dispose();
 if (sent != true || !mounted) return;

 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Invitation sent.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }

  Future<void> _removeVendor(String vendorId) async {
  final vendor = _vendors.where((v) => v.id == vendorId).firstOrNull;
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title: 'Remove Vendor',
    itemLabel: vendor?.name,
  );
  if (!confirmed) return;
  try {
  await VendorService.deleteVendor(
  projectId: _projectId, vendorId: vendorId);
  if (mounted) {
  setState(() {
  _vendors.removeWhere((vendor) => vendor.id == vendorId);
  _selectedVendorIds.remove(vendorId);
  _recomputeDerivedProcurementData();
  });
  }
  } catch (e) {
  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text('Unable to remove vendor: $e'),
  backgroundColor: Colors.red,
  ),
  );
  }
  }
  }

 Widget _buildTimelineTab() {
 return _SectionCard(
 title: 'Timeline',
 subtitle:
 'Schedule-linked items already sync through `ScheduleLinkageService`. This tab now uses an extracted shared timeline view.',
 child: ProcurementTimelineView(items: _items),
 );
 }

 Widget _buildVendorManagementTab() {
 if (_vendors.isEmpty && _contracts.isEmpty) {
 return Center(
 child: ProcurementEmptyStateCard(
 icon: Icons.storefront_outlined,
 title: 'No vendors yet',
 message:
 'Add vendors to manage approvals, ratings, and performance.',
 actionLabel: 'Add Vendor',
 onAction: _openAddVendorDialog,
 ),
 );
 }

 return VendorManagementView(
 vendors: _filteredVendors,
 allVendors: _vendors,
 selectedVendorIds: _selectedVendorIds,
 approvedOnly: _approvedOnly,
 preferredOnly: _preferredOnly,
 listView: _listView,
 categoryFilter: _categoryFilter,
 categoryOptions: _categoryOptions,
 healthMetrics: _vendorHealthMetrics,
 onboardingTasks: _vendorOnboardingTasks,
 riskItems: _vendorRiskItems,
 onAddVendor: _openAddVendorDialog,
 onInviteVendor: _openInviteVendorDialog,
 onApprovedChanged: (v) => setState(() => _approvedOnly = v),
 onPreferredChanged: (v) => setState(() => _preferredOnly = v),
 onCategoryChanged: (v) => setState(() => _categoryFilter = v),
 onViewModeChanged: (v) => setState(() => _listView = v),
 onToggleVendorSelected: (id, selected) {
 setState(() {
 if (selected) {
 _selectedVendorIds.add(id);
 } else {
 _selectedVendorIds.remove(id);
 }
 });
 },
 onEditVendor: _openEditVendorDialog,
 onDeleteVendor: _removeVendor,
 onOpenApprovedVendorList: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Company approved vendor list feature coming soon.'),
 ),
 );
 },
 );
 }

 Widget _buildPurchaseOrdersTab() {
 final data = ProjectDataHelper.getData(context, listen: true);
 final pendingApprovals =
 _pos.where((po) => po.approvalStatus == 'pending').length;
 final overdueApprovals =
 _pos.where((po) => po.approvalStatus == 'pending' && po.isPendingApproval).length;

 return _SectionCard(
 title: 'Purchase orders',
 subtitle:
 'Approval workflow methods are now wired into this tab. Draft POs can be submitted, pending POs can be reviewed, and overdue requests can be escalated.',
 child: _pos.isEmpty
 ? const Text(
 'No purchase orders yet.',
 style: TextStyle(color: Color(0xFF6B7280)),
 )
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _MetricTile(
 label: 'POs',
 value: '${_pos.length}',
 ),
 _MetricTile(
 label: 'Pending approvals',
 value: '$pendingApprovals',
 ),
 _MetricTile(
 label: 'Overdue approvals',
 value: '$overdueApprovals',
 ),
 ],
 ),
 const SizedBox(height: 18),
 for (var i = 0; i < _pos.length; i++) ...[
 _PurchaseOrderCard(
 po: _pos[i],
 projectOwnerName: _projectOwnerName(data),
 onSubmit: () => _submitPoForApproval(_pos[i], data),
 onReview: () => _reviewPo(_pos[i], data),
 onEscalate: () => _escalatePo(_pos[i], data),
 ),
 if (i != _pos.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }

 Future<void> _submitPoForApproval(
 PurchaseOrderModel po,
 ProjectDataModel data,
 ) async {
 final approverId = _primaryApproverId(data);
 final approverName = _projectOwnerName(data);
 try {
 await ProcurementService.submitPoForApproval(
 _projectId,
 po.id,
 approverId,
 approverName,
 po.escalationDays,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Submitted PO #${po.poNumber} for approval.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to submit PO for approval: $e')),
 );
 }
 }

 Future<void> _reviewPo(
 PurchaseOrderModel po,
 ProjectDataModel data,
 ) async {
 final result = await showPoApprovalDialog(
 context,
 po: po,
 projectOwnerId: _primaryApproverId(data),
 projectOwnerName: _projectOwnerName(data),
 );
 if (result == null) return;

 try {
 if (result.isApprove) {
 await ProcurementService.approvePo(
 _projectId,
 po.id,
 comments: result.comments,
 );
 } else if (result.isReject) {
 await ProcurementService.rejectPo(
 _projectId,
 po.id,
 result.comments,
 );
 }
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 result.isApprove
 ? 'Approved PO #${po.poNumber}.'
 : 'Rejected PO #${po.poNumber}.',
 ),
 ),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to update PO approval: $e')),
 );
 }
 }

 Future<void> _escalatePo(
 PurchaseOrderModel po,
 ProjectDataModel data,
 ) async {
 final targets = _escalationTargets(data);
 if (targets.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No escalation targets configured.')),
 );
 return;
 }

 final targetId = await showDialog<String>(
 context: context,
 builder: (context) => PoEscalationDialog(
 po: po,
 availableEscalationTargets: targets,
 ),
 );
 if (targetId == null) return;

 try {
 await ProcurementService.escalatePo(_projectId, po.id, targetId);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Escalated PO #${po.poNumber}.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to escalate PO: $e')),
 );
 }
 }

 String _projectOwnerName(ProjectDataModel data) {
 final manager = data.charterProjectManagerName.trim();
 final sponsor = data.charterProjectSponsorName.trim();
 if (manager.isNotEmpty) return manager;
 if (sponsor.isNotEmpty) return sponsor;
 return 'Project Owner';
 }

 String _primaryApproverId(ProjectDataModel data) {
 final manager = data.charterProjectManagerName.trim();
 if (manager.isNotEmpty) return 'project_manager';
 final sponsor = data.charterProjectSponsorName.trim();
 if (sponsor.isNotEmpty) return 'project_sponsor';
 return 'project_owner';
 }

 List<EscalationTarget> _escalationTargets(ProjectDataModel data) {
 final targets = <EscalationTarget>[];
 final manager = data.charterProjectManagerName.trim();
 final sponsor = data.charterProjectSponsorName.trim();
 if (manager.isNotEmpty) {
 targets.add(
 EscalationTarget(
 id: 'project_manager',
 name: manager,
 role: 'Project Manager',
 ),
 );
 }
 if (sponsor.isNotEmpty) {
 targets.add(
 EscalationTarget(
 id: 'project_sponsor',
 name: sponsor,
 role: 'Project Sponsor',
 ),
 );
 }
 if (targets.isEmpty) {
 targets.add(
 const EscalationTarget(
 id: 'project_owner',
 name: 'Project Owner',
 role: 'Owner',
 ),
 );
 }
 return targets;
 }

 Widget _buildBudgetTrackingTab() {
 return _SectionCard(
 title: 'Budget tracking',
 subtitle:
 'Committed amount now calculates from approved, issued POs. This tab now uses the shared budget tracking table widget.',
 child: BudgetTrackingTable(
 items: _items,
 purchaseOrders: _pos,
 ),
 );
 }

 Widget _buildWorkflowsTab() {
 final workflowScopeId = _resolveWorkflowScopeId();
 final workflowScope = _findWorkflowScopeById(workflowScopeId);
 final workflowDisabledForSelection = _customizeWorkflowByScope &&
 workflowScope != null &&
 !_scopeRequiresProcurementWorkflow(workflowScope);
 final workflowSteps =
 workflowDisabledForSelection ? const <ProcurementWorkflowStep>[] : _workflowDraftSteps;

 return _SectionCard(
 title: 'Workflows',
 subtitle:
 'The workflow builder is now extracted into a shared widget and persists per project. Global and scope-specific procurement cycles can be managed here.',
 child: ProcurementWorkflowBuilder(
 scopeItems: _items,
 customizeWorkflowByScope: _customizeWorkflowByScope,
 selectedScopeId: workflowScopeId,
 selectedScopeName: workflowScope?.name ?? '',
 workflowDisabledForSelection: workflowDisabledForSelection,
 workflowTotalWeeks: _totalWorkflowDurationInWeeks(workflowSteps),
 workflowSteps: workflowSteps,
 workflowLoading: _workflowLoading,
 workflowSaving: _workflowSaving,
 onCustomizeByScopeChanged: _setCustomizeWorkflowByScope,
 onWorkflowScopeSelected: _selectWorkflowScope,
 onAddWorkflowStep: _addWorkflowStepToDraft,
 onEditWorkflowStep: _editWorkflowStep,
 onDeleteWorkflowStep: _deleteWorkflowStepFromDraft,
 onMoveWorkflowStep: _moveWorkflowStepInDraft,
 onResetWorkflow: _resetWorkflowDraftToPreset,
 onSaveWorkflow: _saveWorkflowForSelection,
 onApplyWorkflowToAllScopes: _applyWorkflowDraftToAllScopes,
 ),
 );
 }

 Widget _buildReportsTab() {
 final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
 return ProcurementReportsView(
 kpis: _reportKpis,
 spendBreakdown: _spendBreakdownList,
 leadTimeMetrics: _leadTimeMetrics,
 savingsOpportunities: _savingsOpportunities,
 complianceMetrics: _complianceMetrics,
 currencyFormat: currencyFormat,
 onGenerateReports: () {
 _recomputeDerivedProcurementData();
 if (mounted) {
 setState(() {});
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Reports refreshed from current data.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
 },
 );
 }

 Future<void> _checkAutoSeed() async {
 if (_seedCheckRunning || _projectId.isEmpty) {
 return;
 }

 _seedCheckRunning = true;
 try {
 final data = ProjectDataHelper.getData(context);
 if (ProcurementSeedingService.hasSeeded(data) || _items.isNotEmpty) {
 return;
 }

 final created =
 await ProcurementSeedingService.seedFromContracting(context);
 if (created > 0 && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Imported $created procurement item(s) from contracting.'),
 ),
 );
 }
 } finally {
 _seedCheckRunning = false;
 }
 }

 void _subscribeToData() {
 _subscriptions.addAll([
 ProcurementService.streamItems(_projectId).listen((items) {
 if (!mounted) return;
 setState(() {
 _items = items;
 _trackableItems = items.where(
 (item) => item.status != ProcurementItemStatus.planning,
 ).toList();
 _syncWorkflowStateWithScopes();
 _recomputeDerivedProcurementData();
 });
 }),
 ProcurementService.streamPos(_projectId).listen((pos) {
 if (!mounted) return;
 setState(() {
 _pos = pos;
 _recomputeDerivedProcurementData();
 });
 }),
 PlanningContractingService.streamRfqs(_projectId).listen((rfqs) {
 if (!mounted) return;
 setState(() {
 _rfqs = rfqs;
 _recomputeDerivedProcurementData();
 });
 }),
 planning_contracts.ContractService.streamContracts(_projectId)
 .listen((contracts) {
 if (!mounted) return;
 setState(() => _contracts = contracts);
 }),
 ]);

 _vendorsSub = VendorService.streamVendors(_projectId).listen((vendors) {
 if (!mounted) return;
 setState(() {
 _vendors = vendors;
 _recomputeDerivedProcurementData();
 });
 }, onError: (error) {
 debugPrint('Vendors stream error: $error');
 });
 }

 List<ProcurementWorkflowStep> _cloneWorkflowSteps(
 List<ProcurementWorkflowStep> steps,
 ) {
 return ProcurementWorkflowService.cloneSteps(steps);
 }

 List<String> get _categoryOptions {
 final categories =
 _vendors.map((vendor) => vendor.category).toSet().toList()..sort();
 return ['All Categories', ...categories];
 }

 List<VendorModel> get _filteredVendors {
 return _vendors.where((vendor) {
 if (_approvedOnly && !vendor.isApproved) return false;
 if (_preferredOnly && !vendor.isPreferred) return false;
 if (_categoryFilter != 'All Categories' &&
 vendor.category != _categoryFilter) {
 return false;
 }
 return true;
 }).toList();
 }

 void _recomputeDerivedProcurementData() {
 if (_projectId.isEmpty) return;

 final totalSpend =
 _pos.fold<double>(0, (total, order) => total + order.amount);
 final openOrders =
 _pos.where((po) => po.status == PurchaseOrderStatus.awaitingApproval)
 .length;
 final awaitingApprovals =
 _pos.where((po) => po.approvalStatus == 'pending').length;
 final deliveredCount = _items
 .where((item) => item.status == ProcurementItemStatus.delivered)
 .length;
 final onTimeDelivered = _items
 .where((item) =>
 item.status == ProcurementItemStatus.delivered &&
 item.actualDelivery != null &&
 item.estimatedDelivery != null &&
 !item.actualDelivery!.isAfter(item.estimatedDelivery!))
 .length;
 final onTimeRate = deliveredCount == 0 ? 1.0 : onTimeDelivered / deliveredCount;
 final totalBudget = _items.fold<double>(0, (v, i) => v + i.budget);
 final budgetUtilization = totalBudget == 0 ? 0.0 : totalSpend / totalBudget;
 final averageLeadDays = deliveredCount == 0
 ? 0
 : _items
 .where((item) =>
 item.status == ProcurementItemStatus.delivered &&
 item.actualDelivery != null &&
 item.estimatedDelivery != null)
 .fold<int>(
 0,
 (sum, item) =>
 sum +
 item.actualDelivery!
 .difference(item.estimatedDelivery!)
 .inDays
 .abs(),
 ) ~/
 deliveredCount;

 _reportKpis = [
 ReportKpi(
 label: 'Total Spend',
 value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
 .format(totalSpend),
 delta: 'Budget utilization ${(budgetUtilization * 100).round()}%',
 positive: budgetUtilization <= 1.0,
 ),
 ReportKpi(
 label: 'Open Orders',
 value: '$openOrders',
 delta: '$awaitingApprovals awaiting approval',
 positive: awaitingApprovals <= (openOrders == 0 ? 1 : openOrders),
 ),
 ReportKpi(
 label: 'Avg Lead Time',
 value: averageLeadDays == 0 ? 'N/A' : '$averageLeadDays days',
 delta:
 '${_items.length} tracked item${_items.length == 1 ? '' : 's'}',
 positive: averageLeadDays <= 45 || averageLeadDays == 0,
 ),
 ReportKpi(
 label: 'On-time Delivery',
 value: '${(onTimeRate * 100).round()}%',
 delta:
 '$deliveredCount delivered item${deliveredCount == 1 ? '' : 's'}',
 positive: onTimeRate >= 0.8 || deliveredCount == 0,
 ),
 ];

 final categoryTotals = <String, double>{};
 if (_pos.isNotEmpty) {
 for (final order in _pos) {
 final key =
 order.category.trim().isEmpty ? 'Uncategorized' : order.category;
 categoryTotals[key] = (categoryTotals[key] ?? 0) + order.amount;
 }
 } else {
 for (final item in _items) {
 final key =
 item.category.trim().isEmpty ? 'Uncategorized' : item.category;
 categoryTotals[key] = (categoryTotals[key] ?? 0) + item.budget;
 }
 }

 final palette = <Color>[
 const Color(0xFFD97706),
 const Color(0xFF10B981),
 const Color(0xFFF59E0B),
 const Color(0xFF6D28D9),
 const Color(0xFFEF4444),
 ];
 final categoryEntries = categoryTotals.entries.toList()
 ..sort((a, b) => b.value.compareTo(a.value));
 final totalCategories =
 categoryEntries.fold<double>(0, (t, e) => t + e.value);
 final spendList = <SpendBreakdown>[];
 for (var i = 0; i < categoryEntries.length && i < palette.length; i++) {
 final entry = categoryEntries[i];
 spendList.add(SpendBreakdown(
 label: entry.key,
 amount: entry.value.round(),
 percent: totalCategories == 0
 ? 0
 : (entry.value / totalCategories).clamp(0.0, 1.0),
 color: palette[i],
 ));
 }
 _spendBreakdownList = spendList;

 final categories = _items.map((item) => item.category.trim()).toSet()
 ..removeWhere((value) => value.isEmpty);
 final leadList = <LeadTimeMetric>[];
 for (final category in categories.take(4)) {
 final catItems =
 _items.where((item) => item.category.trim() == category).toList();
 if (catItems.isEmpty) continue;
 final delivered = catItems
 .where((item) => item.status == ProcurementItemStatus.delivered)
 .length;
 final onTime = catItems
 .where((item) =>
 item.status == ProcurementItemStatus.delivered &&
 item.actualDelivery != null &&
 item.estimatedDelivery != null &&
 !item.actualDelivery!.isAfter(item.estimatedDelivery!))
 .length;
 final rate =
 delivered == 0 ? 0.0 : (onTime / delivered).clamp(0.0, 1.0);
 leadList.add(LeadTimeMetric(label: category, onTimeRate: rate));
 }
 _leadTimeMetrics = leadList;

 final savingsList = <SavingsOpportunity>[];
 if (_rfqs.isNotEmpty) {
 savingsList.add(SavingsOpportunity(
 title: 'Competitive RFQ consolidation',
 value: 'Based on ${_rfqs.length} active RFQ${_rfqs.length == 1 ? '' : 's'}',
 owner: 'Sourcing Lead',
 ));
 }
 if (_vendors.length > 2) {
 savingsList.add(SavingsOpportunity(
 title: 'Preferred vendor renegotiation',
 value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
 .format(totalSpend * 0.04),
 owner: 'Procurement Manager',
 ));
 }
 if (savingsList.isEmpty && totalSpend > 0) {
 savingsList.add(SavingsOpportunity(
 title: 'Spend optimization review',
 value: NumberFormat.currency(symbol: '\$', decimalDigits: 0)
 .format(totalSpend * 0.03),
 owner: 'Finance Partner',
 ));
 }
 _savingsOpportunities = savingsList;

 _complianceMetrics = [
 ComplianceMetric(
 label: 'PO ownership',
 value: _pos.isEmpty
 ? 0
 : (_pos.where((order) => order.owner.trim().isNotEmpty).length /
 _pos.length)
 .clamp(0.0, 1.0),
 ),
 ComplianceMetric(
 label: 'Items with delivery date',
 value: _items.isEmpty
 ? 0
 : (_items
 .where((item) => item.estimatedDelivery != null)
 .length /
 _items.length)
 .clamp(0.0, 1.0),
 ),
 ComplianceMetric(
 label: 'Items with vendor assigned',
 value: _items.isEmpty
 ? 0
 : (_items
 .where(
 (item) => (item.vendorId ?? '').trim().isNotEmpty)
 .length /
 _items.length)
 .clamp(0.0, 1.0),
 ),
 ComplianceMetric(
 label: 'Active vendor coverage',
 value: _vendors.isEmpty
 ? 0
 : (_vendors.where((vendor) => vendor.isApproved).length /
 _vendors.length)
 .clamp(0.0, 1.0),
 ),
 ];
 }

 Future<void> _loadProcurementWorkflowData() async {
 if (_projectId.isEmpty) return;
 setState(() => _workflowLoading = true);

 try {
 final snapshot = await ProcurementWorkflowService.load(_projectId);
 if (!mounted) return;
 setState(() {
 _globalWorkflowSteps = snapshot.globalSteps.isEmpty
 ? _cloneWorkflowSteps(_defaultProcurementWorkflowTemplate)
 : _cloneWorkflowSteps(snapshot.globalSteps);
 _scopeWorkflowOverrides = snapshot.scopeOverrides;
 if (_customizeWorkflowByScope) {
 _selectedWorkflowScopeId = _resolveWorkflowScopeId();
 _hydrateWorkflowDraftForSelection();
 } else {
 _selectedWorkflowScopeId = null;
 _workflowDraftSteps = _cloneWorkflowSteps(_globalWorkflowSteps);
 }
 _syncWorkflowStateWithScopes();
 });
 } catch (e) {
 if (!mounted) return;
 // Show user-friendly message instead of raw Firestore internals
 final msg = e.toString().contains('INTERNAL ASSERTION')
 ? 'Network glitch while loading workflow — please refresh the page.'
 : 'Unable to load procurement workflow. Please try again.';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(msg)),
 );
 } finally {
 if (mounted) {
 setState(() => _workflowLoading = false);
 }
 }
 }

 bool _scopeRequiresProcurementWorkflow(ProcurementItemModel item) {
 final value = item.responsibleMember.trim().toLowerCase();
 if ((item.vendorId ?? '').trim().isNotEmpty) return false;
 if (value == 'no' || value.startsWith('no ')) return false;
 if (value == 'not required' || value == 'none') return false;
 final potentialVendors = item.notes
 .replaceAll('\n', ',')
 .replaceAll(';', ',')
 .split(',')
 .map((entry) => entry.trim())
 .where((entry) => entry.isNotEmpty)
 .toList();
 if (potentialVendors.length == 1) {
 return false;
 }
 return true;
 }

 ProcurementItemModel? _findWorkflowScopeById(String? scopeId) {
 if (scopeId == null || scopeId.isEmpty) return null;
 for (final item in _items) {
 if (item.id == scopeId) return item;
 }
 return null;
 }

 String? _resolveWorkflowScopeId() {
 if (_items.isEmpty) return null;
 if (_selectedWorkflowScopeId != null &&
 _items.any((item) => item.id == _selectedWorkflowScopeId)) {
 return _selectedWorkflowScopeId;
 }
 return _items.first.id;
 }

 int _totalWorkflowDurationInWeeks(List<ProcurementWorkflowStep> steps) {
 var total = 0;
 for (final step in steps) {
 final duration = step.duration <= 0 ? 1 : step.duration;
 total += step.unit == 'month' ? duration * 4 : duration;
 }
 return total;
 }

 void _hydrateWorkflowDraftForSelection() {
 if (!_customizeWorkflowByScope) {
 _workflowDraftSteps = _cloneWorkflowSteps(_globalWorkflowSteps);
 return;
 }

 final scopeId = _resolveWorkflowScopeId();
 if (scopeId == null) {
 _selectedWorkflowScopeId = null;
 _workflowDraftSteps = <ProcurementWorkflowStep>[];
 return;
 }

 _selectedWorkflowScopeId = scopeId;
 final scoped = _scopeWorkflowOverrides[scopeId];
 if (scoped != null) {
 _workflowDraftSteps = _cloneWorkflowSteps(scoped);
 } else {
 _workflowDraftSteps = _cloneWorkflowSteps(_globalWorkflowSteps);
 }
 }

 void _syncWorkflowStateWithScopes() {
 final validScopeIds = _items
 .map((item) => item.id.trim())
 .where((id) => id.isNotEmpty)
 .toSet();
 _scopeWorkflowOverrides =
 Map<String, List<ProcurementWorkflowStep>>.from(_scopeWorkflowOverrides)
 ..removeWhere((scopeId, _) => !validScopeIds.contains(scopeId));

 var shouldHydrate = false;
 if (_customizeWorkflowByScope) {
 final resolved = _resolveWorkflowScopeId();
 if (_selectedWorkflowScopeId != resolved) {
 _selectedWorkflowScopeId = resolved;
 shouldHydrate = true;
 }
 } else if (_workflowDraftSteps.isEmpty) {
 shouldHydrate = true;
 }

 if (shouldHydrate) {
 _hydrateWorkflowDraftForSelection();
 }
 }

 void _setCustomizeWorkflowByScope(bool value) {
 setState(() {
 _customizeWorkflowByScope = value;
 if (!value) {
 _selectedWorkflowScopeId = null;
 }
 _hydrateWorkflowDraftForSelection();
 });
 }

 void _selectWorkflowScope(String scopeId) {
 setState(() {
 _selectedWorkflowScopeId = scopeId;
 _hydrateWorkflowDraftForSelection();
 });
 }

 void _resetWorkflowDraftToPreset() {
 setState(() {
 _workflowDraftSteps =
 _cloneWorkflowSteps(_defaultProcurementWorkflowTemplate);
 });
 }

 Future<ProcurementWorkflowStep?> _showWorkflowStepDialog({
 ProcurementWorkflowStep? initialStep,
 }) async {
 final nameController = TextEditingController(text: initialStep?.name ?? '');
 final durationController = TextEditingController(
 text: (initialStep?.duration ?? 1).toString(),
 );
 var unit = initialStep?.unit == 'month' ? 'month' : 'week';

 final result = await showDialog<ProcurementWorkflowStep>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Text(initialStep == null ? 'Add Workflow Step' : 'Edit Step'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Step name',
 hintText: 'e.g. Quote Evaluation',
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: durationController,
 keyboardType: TextInputType.number,
 decoration:
 const InputDecoration(labelText: 'Duration'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: unit,
 decoration: const InputDecoration(labelText: 'Unit'),
 items: const [
 DropdownMenuItem(value: 'week', child: Text('Week')),
 DropdownMenuItem(
 value: 'month',
 child: Text('Month'),
 ),
 ],
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => unit = value);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final name = nameController.text.trim();
 final duration = int.tryParse(durationController.text.trim()) ??
 initialStep?.duration ??
 1;
 if (name.isEmpty || duration <= 0) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Provide a step name and valid duration.'),
 ),
 );
 return;
 }

 Navigator.of(dialogContext).pop(
 ProcurementWorkflowStep(
 id: initialStep?.id ??
 'wf_${DateTime.now().microsecondsSinceEpoch}',
 name: name,
 duration: duration,
 unit: unit,
 ),
 );
 },
 child: Text(initialStep == null ? 'Add Step' : 'Save'),
 ),
 ],
 ),
 ),
 );

 nameController.dispose();
 durationController.dispose();
 return result;
 }

 Future<void> _addWorkflowStepToDraft() async {
 final result = await _showWorkflowStepDialog();
 if (result == null) return;
 setState(() => _workflowDraftSteps = [..._workflowDraftSteps, result]);
 }

 Future<void> _editWorkflowStep(ProcurementWorkflowStep step) async {
 final result = await _showWorkflowStepDialog(initialStep: step);
 if (result == null) return;

 setState(() {
 final next = List<ProcurementWorkflowStep>.from(_workflowDraftSteps);
 final index = next.indexWhere((entry) => entry.id == step.id);
 if (index == -1) return;
 next[index] = result.copyWith(id: step.id);
 _workflowDraftSteps = next;
 });
 }

  Future<void> _deleteWorkflowStepFromDraft(String stepId) async {
  final step = _workflowDraftSteps.where((s) => s.id == stepId).firstOrNull;
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title: 'Delete Workflow Step',
    itemLabel: step?.name,
  );
  if (!confirmed) return;
  setState(() {
  _workflowDraftSteps =
  _workflowDraftSteps.where((step) => step.id != stepId).toList();
  });
  }

 void _moveWorkflowStepInDraft(int index, int direction) {
 final target = index + direction;
 if (index < 0 ||
 index >= _workflowDraftSteps.length ||
 target < 0 ||
 target >= _workflowDraftSteps.length) {
 return;
 }

 setState(() {
 final next = List<ProcurementWorkflowStep>.from(_workflowDraftSteps);
 final step = next.removeAt(index);
 next.insert(target, step);
 _workflowDraftSteps = next;
 });
 }

 void _saveWorkflowForSelection() {
 if (_workflowSaving) return;
 if (_customizeWorkflowByScope) {
 final scopeId = _resolveWorkflowScopeId();
 if (scopeId == null) return;
 setState(() {
 _scopeWorkflowOverrides = {
 ..._scopeWorkflowOverrides,
 scopeId: _cloneWorkflowSteps(_workflowDraftSteps),
 };
 });
 } else {
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(_workflowDraftSteps);
 _scopeWorkflowOverrides = {};
 });
 }
 _persistProcurementWorkflowData(
 successMessage: _customizeWorkflowByScope
 ? 'Saved workflow for selected scope.'
 : 'Saved global procurement workflow.',
 );
 }

 void _applyWorkflowDraftToAllScopes() {
 if (_workflowSaving) return;
 final normalized = _cloneWorkflowSteps(_workflowDraftSteps);
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(normalized);
 final next = <String, List<ProcurementWorkflowStep>>{};
 for (final item in _items) {
 if (!_scopeRequiresProcurementWorkflow(item)) {
 continue;
 }
 next[item.id] = _cloneWorkflowSteps(normalized);
 }
 _scopeWorkflowOverrides = next;
 _customizeWorkflowByScope = false;
 _selectedWorkflowScopeId = null;
 _hydrateWorkflowDraftForSelection();
 });
 _persistProcurementWorkflowData(
 successMessage: 'Applied workflow to all scopes requiring bidding.',
 );
 }

 Future<void> _persistProcurementWorkflowData({
 required String successMessage,
 }) async {
 if (_projectId.isEmpty) return;
 setState(() => _workflowSaving = true);

 try {
 await ProcurementWorkflowService.save(
 projectId: _projectId,
 globalSteps: _globalWorkflowSteps,
 scopeOverrides: _scopeWorkflowOverrides,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(successMessage)),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to save procurement workflow: $e')),
 );
 } finally {
 if (mounted) {
 setState(() => _workflowSaving = false);
 }
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Planning Procurement',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_procurement_v2_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _SummaryCardData {
 const _SummaryCardData({
 required this.label,
 required this.value,
 required this.supporting,
 });

 final String label;
 final String value;
 final String supporting;
}

class _SummaryCard extends StatelessWidget {
 const _SummaryCard({required this.card});

 final _SummaryCardData card;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 220,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 card.label,
 style: Theme.of(context).textTheme.labelLarge?.copyWith(
 color: const Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 card.value,
 style: Theme.of(context).textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 card.supporting,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: const Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 );
 }
}

class _SectionCard extends StatelessWidget {
 const _SectionCard({
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
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 subtitle,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: const Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 18),
 child,
 ],
 ),
 );
 }
}

class _MetricTile extends StatelessWidget {
 const _MetricTile({
 required this.label,
 required this.value,
 });

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 180,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: Theme.of(context).textTheme.labelLarge?.copyWith(
 color: const Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 value,
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 );
 }
}

class _OverviewStat extends StatelessWidget {
 const _OverviewStat({
 required this.label,
 required this.value,
 required this.icon,
 });

 final String label;
 final String value;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return SizedBox(
 width: 160,
 child: Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, size: 18, color: Colors.white),
 ),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 value,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 color: Colors.white.withValues(alpha: 0.7),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _StatRow extends StatelessWidget {
 const _StatRow({
 required this.label,
 required this.value,
 required this.icon,
 });

 final String label;
 final String value;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Icon(icon, size: 16, color: const Color(0xFF6B7280)),
 const SizedBox(width: 8),
 Text(
 '$value $label',
 style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
 ),
 ],
 );
 }
}

class _PurchaseOrderCard extends StatelessWidget {
 const _PurchaseOrderCard({
 required this.po,
 required this.projectOwnerName,
 required this.onSubmit,
 required this.onReview,
 required this.onEscalate,
 });

 final PurchaseOrderModel po;
 final String projectOwnerName;
 final VoidCallback onSubmit;
 final VoidCallback onReview;
 final VoidCallback onEscalate;

 @override
 Widget build(BuildContext context) {
 final amount = NumberFormat.currency(symbol: '\$', decimalDigits: 0)
 .format(po.amount);
 final isPending = po.approvalStatus == 'pending';
 final canSubmit =
 po.approvalStatus == 'draft' || po.approvalStatus == 'rejected';
 final canReview = isPending || po.approvalStatus == 'escalated';
 final showEscalate = isPending || po.isEscalated;

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'PO #${po.poNumber}',
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 po.vendorName,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 _ApprovalStatusBadge(status: po.approvalStatusDisplay),
 ],
 ),
 const SizedBox(height: 14),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _PurchaseInfoChip(
 icon: Icons.category_outlined,
 label: po.category,
 ),
 _PurchaseInfoChip(icon: Icons.payments_outlined, label: amount),
 _PurchaseInfoChip(
 icon: Icons.local_shipping_outlined,
 label: po.status.label,
 ),
 _PurchaseInfoChip(
 icon: Icons.person_outline,
 label: po.approverName?.trim().isNotEmpty == true
 ? po.approverName!
 : projectOwnerName,
 ),
 ],
 ),
 if (po.rejectionReason?.trim().isNotEmpty == true) ...[
 const SizedBox(height: 12),
 Text(
 'Rejection reason: ${po.rejectionReason!.trim()}',
 style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
 ),
 ],
 if (po.approverComments?.trim().isNotEmpty == true) ...[
 const SizedBox(height: 8),
 Text(
 'Approver comments: ${po.approverComments!.trim()}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
 ),
 ],
 if (po.daysUntilEscalation != null) ...[
 const SizedBox(height: 8),
 Text(
 po.daysUntilEscalation == 0
 ? 'Approval is overdue and ready for escalation.'
 : 'Escalation deadline in ${po.daysUntilEscalation} day${po.daysUntilEscalation == 1 ? '' : 's'}.',
 style: TextStyle(
 fontSize: 12,
 color: po.daysUntilEscalation == 0
 ? const Color(0xFFB91C1C)
 : const Color(0xFF92400E),
 ),
 ),
 ],
 const SizedBox(height: 14),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 if (canSubmit)
 ElevatedButton.icon(
 onPressed: onSubmit,
 icon: const Icon(Icons.send_outlined, size: 16),
 label: const Text('Submit for Approval'),
 ),
 if (canReview)
 OutlinedButton.icon(
 onPressed: onReview,
 icon: const Icon(Icons.approval_outlined, size: 16),
 label: const Text('Review'),
 ),
 if (showEscalate)
 TextButton.icon(
 onPressed: onEscalate,
 icon: const Icon(Icons.priority_high_rounded, size: 16),
 label: const Text('Escalate'),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ApprovalStatusBadge extends StatelessWidget {
 const _ApprovalStatusBadge({required this.status});

 final String status;

 @override
 Widget build(BuildContext context) {
 late final Color background;
 late final Color border;
 late final Color foreground;

 switch (status.toLowerCase()) {
 case 'approved':
 background = const Color(0xFFDCFCE7);
 border = const Color(0xFF86EFAC);
 foreground = const Color(0xFF15803D);
 break;
 case 'rejected':
 background = const Color(0xFFFEE2E2);
 border = const Color(0xFFFCA5A5);
 foreground = const Color(0xFFB91C1C);
 break;
 case 'overdue':
 case 'escalated':
 background = const Color(0xFFFFEDD5);
 border = const Color(0xFFFDBA74);
 foreground = const Color(0xFFC2410C);
 break;
 case 'pending':
 default:
 background = const Color(0xFFFFF7E6);
 border = const Color(0xFFFDE68A);
 foreground = const Color(0xFFD97706);
 break;
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: border),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: foreground,
 ),
 ),
 );
 }
}

class _PurchaseInfoChip extends StatelessWidget {
 const _PurchaseInfoChip({
 required this.icon,
 required this.label,
 });

 final IconData icon;
 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 14, color: const Color(0xFF64748B)),
 const SizedBox(width: 6),
 Text(
 label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
 ),
 ],
 ),
 );
 }
}


