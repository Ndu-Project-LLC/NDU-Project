import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/s_curve_chart.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/services/forecast_service.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
class CostEstimateScreen extends StatefulWidget {
 const CostEstimateScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context)
 .push(MaterialPageRoute(builder: (_) => const CostEstimateScreen()));
 }

 @override
 State<CostEstimateScreen> createState() => _CostEstimateScreenState();
}

class _CostEstimateScreenState extends State<CostEstimateScreen> {
 static const Map<_CostView, _CostViewMeta> _viewMeta = {
 _CostView.direct: _CostViewMeta(
 label: 'Direct Costs',
 description: 'Delivery spend, capital allocation & external squads',
 ),
 _CostView.indirect: _CostViewMeta(
 label: 'Indirect Costs',
 description: 'Programme overheads, enablement, shared services',
 ),
 };

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 Future<bool> _isSectionInitialized(String flagKey) async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return false;
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('planning_meta')
 .doc('initialization_flags')
 .get();
 return doc.data()?[flagKey] == true;
 } catch (e) {
 return false;
 }
 }

 Future<void> _markSectionInitialized(String flagKey) async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('planning_meta')
 .doc('initialization_flags')
 .set({flagKey: true, '${flagKey}_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
 } catch (e) { debugPrint('Error: $e'); }
 }

 _CostView _activeView = _CostView.indirect;
 _CostStateFilter _activeStateFilter = _CostStateFilter.all;
 bool _includeSupersededLines = false;
 _CostWorkspaceTab _activeTab = _CostWorkspaceTab.overview;
 double _overheadRatePercent = 0;
 bool _loadedCostItems = false;
 bool _autoPopulated = false;
 bool _importingSources = false;
 bool _validating = false;
 DateTime? _baselineConfirmedAt;
 List<ProcurementItemModel> _procurementItems = const [];
 List<PurchaseOrderModel> _purchaseOrders = const [];
 List<ContractModel> _contracts = const [];

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadCostItemsFromFirestore().then((_) {
 if (mounted) {
 _loadCommercialSources();
 _loadWorkspaceState();
 _autoPopulateFromInitiationIfNeeded();
 }
 });
 });
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final bool isTablet = AppBreakpoints.isTablet(context) && !isMobile;
 final double horizontalPadding = isMobile ? 20 : (isTablet ? 28 : 36);
 final projectData = ProjectDataHelper.getData(context);
 final directItems = _itemsForView(projectData, _CostView.direct);
 final indirectItems = _itemsForView(projectData, _CostView.indirect);
 final forecastItems = ProjectDataHelper.getActiveCostEstimateItems(
 projectData,
 costState: 'forecast');
 final committedItems = ProjectDataHelper.getActiveCostEstimateItems(
 projectData,
 costState: 'committed');
 final actualItems = ProjectDataHelper.getActiveCostEstimateItems(
 projectData,
 costState: 'actual');
 final directBaseline =
 directItems.where((item) => item.isBaseline).toList();
 final indirectBaseline =
 indirectItems.where((item) => item.isBaseline).toList();
 final directAdjustments =
 directItems.where((item) => !item.isBaseline).toList();
 final indirectAdjustments =
 indirectItems.where((item) => !item.isBaseline).toList();
 final double directTotal = _sumCostItems(directItems);
 final double indirectTotal = _sumCostItems(indirectItems);
 final double total = _sumCostItems(forecastItems);
 final double forecastTotal = total;
 final double committedTotal = _sumCostItems(committedItems);
 final double actualTotal = _sumCostItems(actualItems);
 final double baselineTotal =
 _sumCostItems([...directBaseline, ...indirectBaseline]);
 final double adjustmentTotal = _sumCostItems([
 ...directAdjustments.where((item) => item.costState == 'forecast'),
 ...indirectAdjustments.where((item) => item.costState == 'forecast'),
 ]);
 final viewDefinitions = {
 _CostView.direct:
 _buildViewDefinition(_CostView.direct, directItems, directTotal),
 _CostView.indirect: _buildViewDefinition(
 _CostView.indirect, indirectItems, indirectTotal),
 };
 final _CostViewDefinition view = viewDefinitions[_activeView]!;
 final summaryMetrics = _buildSummaryMetrics(
 total: total,
 forecastTotal: forecastTotal,
 committedTotal: committedTotal,
 actualTotal: actualTotal,
 managementReserve: projectData.managementReserve,
 );
 final sourceSummaries = _buildSourceSummaries(projectData);
 final validationSummary = _buildValidationSummary(projectData);
 final reconciliationReport = _buildReconciliationReport(projectData);
 final overviewRows = _buildOverviewRows(
 projectData,
 baselineTotal: baselineTotal,
 total: forecastTotal,
 committedTotal: committedTotal,
 actualTotal: actualTotal,
 sourceSummaries: sourceSummaries,
 );

 final preferredTitle = _preferredSolutionTitle(projectData);
 final projectValueAmount =
 _projectValueForPreferred(projectData.costAnalysisData, preferredTitle);
 final benefitCount =
 _benefitCountForPreferred(projectData.costAnalysisData, preferredTitle);

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child:
 const InitiationLikeSidebar(activeItemLabel: 'Cost Estimate'),
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
 PlanningPhaseHeader(title: 'Cost Estimate', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _TopUtilityBar(
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'cost_estimate'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'cost_estimate'),
 ),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Cost Estimate',
 noteKey: 'planning_cost_estimate_notes',
 checkpoint: 'cost_estimate',
 description:
 'Summarize cost drivers, assumptions, and mitigation for budget risks.',
 ),
 const SizedBox(height: 24),
 _PhaseContextCard(
 projectName: projectData.projectName,
 preferredSolutionTitle: preferredTitle,
 projectValueAmount: projectValueAmount,
 benefitCount: benefitCount,
 baselineTotal: baselineTotal,
 costBenefitCurrency: projectData.costBenefitCurrency,
 onRefresh: _refreshFromInitiation,
 ),
 const SizedBox(height: 18),
 _BaselineDeltaStrip(
 total: forecastTotal,
 baseline: baselineTotal,
 adjustments: adjustmentTotal,
 isMobile: isMobile,
 ),
 const SizedBox(height: 24),
 _CostEstimateTopBar(
 baselineConfirmedAt: _baselineConfirmedAt,
 isImporting: _importingSources,
 isValidating: _validating,
 onRefreshBaseline: _refreshFromInitiation,
 onImportSources: _importAllSources,
 onAiGenerate: () => _showAiSuggestions(context),
 onValidate: _runValidation,
 onSetBaseline: _confirmBaseline,
 onReconcile: () => setState(() =>
 _activeTab = _CostWorkspaceTab.sourceImports),
 ),
 const SizedBox(height: 24),
 _WorkspaceTabs(
 activeTab: _activeTab,
 onChanged: (tab) => setState(() => _activeTab = tab),
 ),
 const SizedBox(height: 24),
 _buildTabContent(
 context,
 projectData,
 isMobile: isMobile,
 summaryMetrics: summaryMetrics,
 directBaseline: directBaseline,
 indirectBaseline: indirectBaseline,
 directAdjustments: directAdjustments,
 indirectAdjustments: indirectAdjustments,
 viewDefinitions: viewDefinitions,
 view: view,
 sourceSummaries: sourceSummaries,
 validationSummary: validationSummary,
 reconciliationReport: reconciliationReport,
 overviewRows: overviewRows,
 forecastItems: forecastItems,
 committedItems: committedItems,
 actualItems: actualItems,
 directTotal: directTotal,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'cost_estimate'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'cost_estimate'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'cost_estimate'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'cost_estimate'),
 ),
 const SizedBox(height: 80),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Cost Estimate',
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

 Widget _buildTabContent(
 BuildContext context,
 ProjectDataModel projectData, {
 required bool isMobile,
 required List<_CostSummary> summaryMetrics,
 required List<CostEstimateItem> directBaseline,
 required List<CostEstimateItem> indirectBaseline,
 required List<CostEstimateItem> directAdjustments,
 required List<CostEstimateItem> indirectAdjustments,
 required Map<_CostView, _CostViewDefinition> viewDefinitions,
 required _CostViewDefinition view,
 required List<_SourceSummary> sourceSummaries,
 required _ValidationSummary validationSummary,
 required _ReconciliationReport reconciliationReport,
 required List<_OverviewRow> overviewRows,
 required List<CostEstimateItem> forecastItems,
 required List<CostEstimateItem> committedItems,
 required List<CostEstimateItem> actualItems,
 required double directTotal,
 }) {
 switch (_activeTab) {
 case _CostWorkspaceTab.overview:
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _MetricStrip(metrics: summaryMetrics, isMobile: isMobile),
 const SizedBox(height: 24),
 _OverviewRollupCard(rows: overviewRows),
 const SizedBox(height: 24),
 _CoverageSummaryCard(
 sourceSummaries: sourceSummaries,
 validationSummary: validationSummary,
 reconciliationReport: reconciliationReport,
 ),
 const SizedBox(height: 24),
 _BoeSummaryCard(items: projectData.costEstimateItems),
 const SizedBox(height: 24),
 _CostProfileCard(
 items: projectData.costEstimateItems,
 workPackages: projectData.workPackages,
 ),
 ],
 );
 case _CostWorkspaceTab.estimateLines:
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ViewSelector(
 activeView: _activeView,
 definitions: viewDefinitions,
 onChanged: (nextView) => setState(() => _activeView = nextView),
 ),
 const SizedBox(height: 20),
 _CostStateSelector(
 activeFilter: _activeStateFilter,
 onChanged: (nextFilter) =>
 setState(() => _activeStateFilter = nextFilter),
 ),
 const SizedBox(height: 20),
 _SupersededToggle(
 enabled: _includeSupersededLines,
 onChanged: (value) =>
 setState(() => _includeSupersededLines = value),
 ),
 const SizedBox(height: 20),
 _SectionHeader(
 view: view,
 onAiSuggestions: () => _showAiSuggestions(context),
 onAddItem: () => _showAddItem(context),
 ),
 const SizedBox(height: 18),
 _SubsectionHeader(
 title: 'Initiation baseline',
 subtitle:
 'Imported baseline items confirmed for the current estimate.',
 ),
 const SizedBox(height: 12),
 _CostCategoryList(
 items: _activeView == _CostView.direct
 ? directBaseline
 : indirectBaseline,
 view: _activeView,
 iconForItem: _iconForItem,
 onEdit: (item) => _showEditItem(context, item),
 onDelete: (item) => _deleteItem(context, item),
 ),
 const SizedBox(height: 20),
 _SubsectionHeader(
 title: 'Planning adjustments',
 subtitle:
 'Manual lines and imported planning deltas linked to project sources.',
 ),
 const SizedBox(height: 12),
 _CostCategoryList(
 items: _activeView == _CostView.direct
 ? directAdjustments
 : indirectAdjustments,
 view: _activeView,
 iconForItem: _iconForItem,
 onEdit: (item) => _showEditItem(context, item),
 onDelete: (item) => _deleteItem(context, item),
 ),
 if (_includeSupersededLines) ...[
 const SizedBox(height: 20),
 _SubsectionHeader(
 title: 'Superseded by reconciliation',
 subtitle:
 'Raw imported lines that were collapsed because a stronger cost state exists for the same scope.',
 ),
 const SizedBox(height: 12),
 _SupersededCostList(
 items: _supersededItemsForView(
 reconciliationReport,
 _activeView,
 ),
 view: _activeView,
 activeFilter: _activeStateFilter,
 iconForItem: _iconForItem,
 ),
 ],
 if (_activeView == _CostView.indirect) ...[
 const SizedBox(height: 22),
 _OverheadConfigCard(
 ratePercent: _overheadRatePercent,
 directBaseTotal: directTotal,
 complexityIndex: _resolveComplexityIndex(projectData),
 onRateChanged: (v) => setState(() => _overheadRatePercent = v),
 ),
 ],
 const SizedBox(height: 22),
 _TrailingSummaryCard(view: view),
 ],
 );
 case _CostWorkspaceTab.cbsTree:
 return _CbsTreeWorkspace(
 projectData: projectData,
 forecastItems: forecastItems,
 committedItems: committedItems,
 actualItems: actualItems,
 );
 case _CostWorkspaceTab.sourceImports:
 return _SourceImportsTab(
 sourceSummaries: sourceSummaries,
 reconciliationReport: reconciliationReport,
 onImportAll: _importAllSources,
 onValidate: _runValidation,
 );
 case _CostWorkspaceTab.contractsProcurement:
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ContractStrategyCard(
 contracts: _contracts,
 costItems: projectData.costEstimateItems,
 ),
 const SizedBox(height: 20),
 _SourceDetailList(
 title: 'Contracts & Procurement',
 subtitle:
 'Commercial sources that should reconcile to the estimate total.',
 rows: _buildContractsProcurementRows(projectData),
 ),
 ],
 );
 case _CostWorkspaceTab.staffingInfrastructure:
 return _SourceDetailList(
 title: 'Staffing & Infrastructure',
 subtitle:
 'Structured and pending inputs for resource and infrastructure cost coverage.',
 rows: _buildStaffingInfrastructureRows(projectData),
 );
 case _CostWorkspaceTab.contingencyRisk:
 return _ContingencyRiskPanel(
 projectData: projectData,
 forecastItems: forecastItems,
 allItems: projectData.costEstimateItems,
 rows: _buildContingencyRiskRows(projectData),
 );
 case _CostWorkspaceTab.costVsSchedule:
 return _CostVsScheduleWorkspace(projectData: projectData);
 }
 }

 List<CostEstimateItem> _itemsForView(ProjectDataModel data, _CostView view) {
 final key = _viewKey(view);
 final selectedState = _activeStateFilter == _CostStateFilter.all
 ? 'forecast'
 : _costStateValue(_activeStateFilter);
 return ProjectDataHelper.getActiveCostEstimateItems(
 data,
 costState: selectedState,
 ).where((item) => item.costType == key).toList();
 }

 List<_ReconciliationEntry> _supersededItemsForView(
 _ReconciliationReport report,
 _CostView view,
 ) {
 final key = _viewKey(view);
 return report.entries.where((entry) {
 if (entry.superseded.costType != key) return false;
 if (_activeStateFilter == _CostStateFilter.all) return true;
 return entry.superseded.costState == _costStateValue(_activeStateFilter);
 }).toList();
 }

 double _sumCostItems(List<CostEstimateItem> items) {
 return items.fold(0.0, (total, item) => total + item.amount);
 }

 _CostViewDefinition _buildViewDefinition(
 _CostView view, List<CostEstimateItem> items, double total) {
 final meta = _viewMeta[view]!;
 final categories = items
 .map(
 (item) => _CostCategory(
 title: item.title,
 icon: _iconForItem(item, view),
 amount: item.amount,
 notes: item.notes,
 ),
 )
 .toList();
 return _CostViewDefinition(
 label: meta.label,
 description: meta.description,
 categories: categories,
 trailingSummaryLabel: view == _CostView.direct
 ? 'Total Direct Costs'
 : 'Total Indirect Costs',
 trailingSummaryAmount: total,
 );
 }

 List<_CostSummary> _buildSummaryMetrics({
 required double total,
 required double forecastTotal,
 required double committedTotal,
 required double actualTotal,
 required double managementReserve,
 }) {
 return [
 _CostSummary(
 title: 'Forecast',
 amount: forecastTotal,
 description: forecastTotal == 0
 ? 'No forecast costs yet'
 : 'Planning estimate and budget inputs',
 backgroundColor: Colors.white,
 accentColor: const Color(0xFF111827),
 descriptionColor: const Color(0xFF6B7280),
 badgeLabel: forecastTotal == 0 ? null : 'Forecast',
 ),
 _CostSummary(
 title: 'Committed',
 amount: committedTotal,
 description: committedTotal == 0
 ? 'No committed costs yet'
 : 'Reference-only downstream commitments',
 backgroundColor: const Color(0xFFEFF6FF),
 accentColor: const Color(0xFF1D4ED8),
 descriptionColor: const Color(0xFF1D4ED8),
 badgeLabel: committedTotal == 0 ? null : 'Committed',
 ),
 _CostSummary(
 title: 'Actual',
 amount: actualTotal,
 description: actualTotal == 0
 ? 'No actual costs yet'
 : 'Reference-only downstream actuals',
 backgroundColor: const Color(0xFFEFFDF5),
 accentColor: const Color(0xFF047857),
 descriptionColor: const Color(0xFF047857),
 badgeLabel: actualTotal == 0 ? null : 'Actual',
 ),
 _CostSummary(
 title: 'Planning Total',
 amount: total,
 description: total == 0
 ? 'No planning forecast costs yet'
 : 'Authoritative planning-phase forecast total',
 backgroundColor: const Color(0xFFFFFBEB),
 accentColor: const Color(0xFFB45309),
 descriptionColor: const Color(0xFFB45309),
 badgeLabel: total == 0 ? null : 'Planning',
 ),
 _CostSummary(
 title: 'Management Reserve',
 amount: managementReserve,
 description: managementReserve == 0
 ? 'No management reserve set'
 : 'Separate from delivery forecast',
 backgroundColor: const Color(0xFFF5F3FF),
 accentColor: const Color(0xFF7C3AED),
 descriptionColor: const Color(0xFF7C3AED),
 badgeLabel: managementReserve == 0 ? null : 'Reserve',
 ),
 ];
 }

 IconData _iconForItem(CostEstimateItem item, _CostView view) {
 final iconSet = view == _CostView.direct
 ? const [
 Icons.handyman_outlined,
 Icons.apps_outlined,
 Icons.router_outlined,
 Icons.groups_2_outlined,
 Icons.verified_outlined,
 Icons.savings_outlined,
 Icons.precision_manufacturing_outlined,
 Icons.build_circle_outlined,
 ]
 : const [
 Icons.business_outlined,
 Icons.lightbulb_outline,
 Icons.handyman_outlined,
 Icons.inventory_2_outlined,
 Icons.people_alt_outlined,
 Icons.calculate_outlined,
 Icons.support_agent_outlined,
 Icons.apartment_outlined,
 ];
 final index =
 item.title.isEmpty ? 0 : item.title.hashCode.abs() % iconSet.length;
 return iconSet[index];
 }

 String _viewKey(_CostView view) =>
 view == _CostView.direct ? 'direct' : 'indirect';

 String _costStateValue(_CostStateFilter filter) {
 switch (filter) {
 case _CostStateFilter.all:
 return 'all';
 case _CostStateFilter.forecast:
 return 'forecast';
 case _CostStateFilter.committed:
 return 'committed';
 case _CostStateFilter.actual:
 return 'actual';
 }
 }

 Future<void> _showAiSuggestions(BuildContext context) async {
 final provider = ProjectDataHelper.getProvider(context);
 final pd = provider.projectData;
 final messenger = ScaffoldMessenger.of(context);
 final structuredContext = ProjectDataHelper.buildFepContext(
 pd,
 sectionLabel: 'Cost Estimate',
 ).trim();
 final scanContext = ProjectDataHelper.buildProjectContextScan(
 pd,
 sectionLabel: 'Cost Estimate',
 ).trim();

 // Build a context payload that carries forward upstream project data.
 final projectContext = [
 '''
Project Info:
Name: ${pd.projectName}
Objective: ${pd.projectObjective}
Description: ${pd.solutionDescription}
Business Case: ${pd.businessCase}
Current Cost Items: ${pd.costEstimateItems.map((e) => "${e.title} (${e.costType})").join(", ")}
''',
 if (structuredContext.isNotEmpty)
 'Structured Project Context:\n$structuredContext',
 if (scanContext.isNotEmpty) 'Project Context Scan:\n$scanContext',
 ].join('\n\n');

 final selectedItems = await showDialog<List<CostEstimateItem>>(
 context: context,
 builder: (ctx) => _AiSuggestionsDialog(projectContext: projectContext),
 );

 if (selectedItems != null && selectedItems.isNotEmpty) {
 final normalized = selectedItems
 .map(
 (item) => CostEstimateItem(
 title: item.title,
 notes: item.notes,
 amount: item.amount,
 costType: item.costType,
 source: 'ai',
 costState: 'forecast',
 isBaseline: false,
 ),
 )
 .toList();
 final items = List<CostEstimateItem>.from(pd.costEstimateItems)
 ..addAll(normalized);
 provider.updateField((data) => data.copyWith(costEstimateItems: items));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');

 // Also persist individually if needed, though saving full list usually suffices
 for (final item in normalized) {
 await _persistCostItem(item);
 }

 if (mounted) {
 messenger.showSnackBar(
 SnackBar(
 content:
 Text('Added ${normalized.length} items from AI suggestions'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }
 }

 Future<void> _showAddItem(BuildContext context) async {
 final provider = ProjectDataHelper.getProvider(context);
 final selected = await showDialog<CostEstimateItem>(
 context: context,
 builder: (dialogContext) => _AddCostItemDialog(
 initialView: _activeView,
 projectData: provider.projectData,
 ),
 );

 if (selected == null) return;

 final items =
 List<CostEstimateItem>.from(provider.projectData.costEstimateItems)
 ..add(selected);
 provider.updateField((data) => data.copyWith(costEstimateItems: items));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');
 await _persistCostItem(selected);
 }

 Future<void> _showEditItem(
 BuildContext context, CostEstimateItem existing) async {
 final provider = ProjectDataHelper.getProvider(context);
 final updated = await showDialog<CostEstimateItem>(
 context: context,
 builder: (dialogContext) => _AddCostItemDialog(
 initialView: existing.costType == 'direct'
 ? _CostView.direct
 : _CostView.indirect,
 existingItem: existing,
 projectData: provider.projectData,
 ),
 );

 if (updated == null) return;

 final items = provider.projectData.costEstimateItems
 .map((i) => i.id == existing.id ? updated : i)
 .toList();
 provider.updateField((data) => data.copyWith(costEstimateItems: items));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');
 await _persistCostItem(updated);
 }

 Future<void> _deleteItem(BuildContext context, CostEstimateItem item) async {
 final provider = ProjectDataHelper.getProvider(context);
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete cost item?'),
 content: const Text('This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel')),
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 child: const Text('Delete', style: TextStyle(color: Colors.red))),
 ],
 ),
 );
 if (confirmed != true) return;

 final items = provider.projectData.costEstimateItems
 .where((i) => i.id != item.id)
 .toList();
 provider.updateField((data) => data.copyWith(costEstimateItems: items));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');

 // Delete from Firestore
 final projectId = provider.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('cost_estimate_items')
 .doc(item.id)
 .delete();
 }
 }

 Future<void> _autoPopulateFromInitiationIfNeeded() async {
 if (_autoPopulated) return;
 final provider = ProjectDataHelper.getProvider(context);
 if (provider.projectData.costEstimateItems.isNotEmpty) {
 _autoPopulated = true;
 return;
 }

 final initialized = await _isSectionInitialized('cost_estimate_initialized');
 if (initialized) {
 _autoPopulated = true;
 return;
 }

 final baselineItems =
 _buildBaselineItemsFromInitiation(provider.projectData);
 if (baselineItems.isEmpty) {
 _autoPopulated = true;
 return;
 }

 provider.updateField(
 (data) => data.copyWith(costEstimateItems: baselineItems),
 );
 await provider.saveToFirebase(checkpoint: 'cost_estimate');
 for (final item in baselineItems) {
 await _persistCostItem(item);
 }
 _autoPopulated = true;
 await _markSectionInitialized('cost_estimate_initialized');

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Cost estimate seeded from initiation data.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

 Future<void> _refreshFromInitiation() async {
 final provider = ProjectDataHelper.getProvider(context);
 final baselineItems =
 _buildBaselineItemsFromInitiation(provider.projectData);
 if (baselineItems.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No initiation cost data available to import.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 return;
 }

 final replace = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Refresh initiation baseline?'),
 content: const Text(
 'This will replace current baseline items while keeping your planning adjustments.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel')),
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 child: const Text('Replace baseline')),
 ],
 ),
 );

 if (replace != true) return;

 final manualItems = provider.projectData.costEstimateItems
 .where((item) => !item.isBaseline)
 .toList();
 final merged = [...manualItems, ...baselineItems];
 provider.updateField((data) => data.copyWith(costEstimateItems: merged));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');
 for (final item in baselineItems) {
 await _persistCostItem(item);
 }

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Baseline refreshed from initiation data.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

 List<CostEstimateItem> _buildBaselineItemsFromInitiation(
 ProjectDataModel data,
 ) {
 final items = <CostEstimateItem>[];
 final seen = <String>{};
 final preferredTitle = _preferredSolutionTitle(data);

 void addItem(CostEstimateItem item) {
 final key = '${item.title}|${item.costType}|${item.source}';
 if (seen.contains(key)) return;
 seen.add(key);
 items.add(item);
 }

 final cba = data.costAnalysisData;
 if (cba != null) {
 final costRows = _solutionCostRows(cba, preferredTitle);
 for (final row in costRows) {
 final amount = _parseCurrency(row.cost);
 if (amount <= 0) continue;
 addItem(
 CostEstimateItem(
 title: row.itemName.isEmpty ? 'Cost Item' : row.itemName,
 notes: row.assumptions,
 amount: amount,
 costType: _inferCostType(row.itemName),
 source: 'initiation_cost_rows',
 isBaseline: true,
 ),
 );
 }

 if (items.isEmpty) {
 final categoryData = _solutionCategoryCosts(cba, preferredTitle) ?? {};
 final categoryNotes = _solutionCategoryNotes(cba, preferredTitle) ?? {};
 categoryData.forEach((key, value) {
 final amount = _parseCurrency(value);
 if (amount <= 0) return;
 final label = _categoryLabelForKey(key);
 addItem(
 CostEstimateItem(
 title: label,
 notes: categoryNotes[key] ?? '',
 amount: amount,
 costType: _inferCostTypeByKey(key),
 source: 'initiation_category_costs',
 isBaseline: true,
 ),
 );
 });
 }
 }

 final preferred = data.preferredSolutionAnalysis;
 if (preferred != null && items.isEmpty) {
 final costs = _preferredSolutionCosts(preferred);
 for (final cost in costs) {
 if (cost.estimatedCost <= 0) continue;
 addItem(
 CostEstimateItem(
 title: cost.item.isEmpty ? 'Cost Item' : cost.item,
 notes: cost.description,
 amount: cost.estimatedCost,
 costType: _inferCostType(cost.item),
 source: 'preferred_solution',
 isBaseline: true,
 ),
 );
 }
 }

 return items;
 }

 String? _preferredSolutionTitle(ProjectDataModel data) {
 final preferred = data.preferredSolutionAnalysis;
 if (preferred != null) {
 final selectedTitle = preferred.selectedSolutionTitle?.trim() ?? '';
 if (selectedTitle.isNotEmpty) return selectedTitle;
 final index = preferred.selectedSolutionIndex;
 if (index != null &&
 index >= 0 &&
 index < preferred.solutionAnalyses.length) {
 final title = preferred.solutionAnalyses[index].solutionTitle.trim();
 if (title.isNotEmpty) return title;
 }
 }
 final preferredSolution = data.preferredSolution;
 if (preferredSolution != null &&
 preferredSolution.title.trim().isNotEmpty) {
 return preferredSolution.title.trim();
 }
 if (data.solutionTitle.trim().isNotEmpty) {
 return data.solutionTitle.trim();
 }
 return null;
 }

 String _projectValueForPreferred(
 CostAnalysisData? cba,
 String? preferredTitle,
 ) {
 if (cba == null) return '';
 if (cba.solutionProjectBenefits.isNotEmpty) {
 if (preferredTitle != null) {
 for (final solution in cba.solutionProjectBenefits) {
 if (solution.solutionTitle.trim().toLowerCase() ==
 preferredTitle.toLowerCase()) {
 return solution.projectValueAmount;
 }
 }
 }
 if (cba.solutionProjectBenefits.length == 1) {
 return cba.solutionProjectBenefits.first.projectValueAmount;
 }
 }
 return cba.projectValueAmount;
 }

 int _benefitCountForPreferred(
 CostAnalysisData? cba,
 String? preferredTitle,
 ) {
 if (cba == null) return 0;
 if (cba.solutionProjectBenefits.isNotEmpty) {
 if (preferredTitle != null) {
 for (final solution in cba.solutionProjectBenefits) {
 if (solution.solutionTitle.trim().toLowerCase() ==
 preferredTitle.toLowerCase()) {
 return solution.projectBenefits.length;
 }
 }
 }
 if (cba.solutionProjectBenefits.length == 1) {
 return cba.solutionProjectBenefits.first.projectBenefits.length;
 }
 }
 return cba.benefitLineItems.length;
 }

 List<CostRowData> _solutionCostRows(
 CostAnalysisData cba,
 String? preferredTitle,
 ) {
 if (cba.solutionCosts.isEmpty) return const [];
 if (preferredTitle != null) {
 for (final solution in cba.solutionCosts) {
 if (solution.solutionTitle.trim().toLowerCase() ==
 preferredTitle.toLowerCase()) {
 return solution.costRows;
 }
 }
 }
 return cba.solutionCosts.length == 1
 ? cba.solutionCosts.first.costRows
 : const [];
 }

 Map<String, String>? _solutionCategoryCosts(
 CostAnalysisData cba,
 String? preferredTitle,
 ) {
 if (cba.solutionCategoryCosts.isEmpty) return null;
 if (preferredTitle != null) {
 for (final solution in cba.solutionCategoryCosts) {
 if (solution.solutionTitle.trim().toLowerCase() ==
 preferredTitle.toLowerCase()) {
 return solution.categoryCosts;
 }
 }
 }
 return cba.solutionCategoryCosts.length == 1
 ? cba.solutionCategoryCosts.first.categoryCosts
 : null;
 }

 Map<String, String>? _solutionCategoryNotes(
 CostAnalysisData cba,
 String? preferredTitle,
 ) {
 if (cba.solutionCategoryCosts.isEmpty) return null;
 if (preferredTitle != null) {
 for (final solution in cba.solutionCategoryCosts) {
 if (solution.solutionTitle.trim().toLowerCase() ==
 preferredTitle.toLowerCase()) {
 return solution.categoryNotes;
 }
 }
 }
 return cba.solutionCategoryCosts.length == 1
 ? cba.solutionCategoryCosts.first.categoryNotes
 : null;
 }

 List<CostItem> _preferredSolutionCosts(PreferredSolutionAnalysis preferred) {
 if (preferred.solutionAnalyses.isEmpty) return const [];
 if (preferred.selectedSolutionTitle != null &&
 preferred.selectedSolutionTitle!.trim().isNotEmpty) {
 final title = preferred.selectedSolutionTitle!.trim().toLowerCase();
 for (final solution in preferred.solutionAnalyses) {
 if (solution.solutionTitle.trim().toLowerCase() == title) {
 return solution.costs;
 }
 }
 }
 final index = preferred.selectedSolutionIndex;
 if (index != null &&
 index >= 0 &&
 index < preferred.solutionAnalyses.length) {
 return preferred.solutionAnalyses[index].costs;
 }
 return preferred.solutionAnalyses.first.costs;
 }

 double _parseCurrency(String input) {
 final cleaned = input.replaceAll(RegExp(r'[^0-9.\\-]'), '');
 return double.tryParse(cleaned) ?? 0.0;
 }

 String _categoryLabelForKey(String key) {
 const labels = {
 'revenue': 'Revenue',
 'cost_saving': 'Cost Saving',
 'ops_efficiency': 'Operational Efficiency',
 'productivity': 'Productivity',
 'regulatory_compliance': 'Regulatory & Compliance',
 'process_improvement': 'Process Improvement',
 'brand_image': 'Brand Image',
 'stakeholder_commitment': 'Stakeholder Commitment',
 'other': 'Other',
 };
 return labels[key] ?? key;
 }

 String _inferCostTypeByKey(String key) {
 const indirectKeys = {
 'cost_saving',
 'ops_efficiency',
 'regulatory_compliance',
 'brand_image',
 'stakeholder_commitment',
 };
 return indirectKeys.contains(key) ? 'indirect' : 'direct';
 }

 String _inferCostType(String title) {
 final lower = title.toLowerCase();
 const indirectTokens = [
 'overhead',
 'admin',
 'support',
 'training',
 'maintenance',
 'license',
 'subscription',
 'compliance',
 'legal',
 'audit',
 'insurance',
 'facility',
 'utilities',
 'travel',
 'security',
 'governance',
 ];
 for (final token in indirectTokens) {
 if (lower.contains(token)) return 'indirect';
 }
 return 'direct';
 }

 Future<void> _loadCostItemsFromFirestore() async {
 if (_loadedCostItems) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (provider.projectData.costEstimateItems.isNotEmpty) {
 _loadedCostItems = true;
 return;
 }

 try {
 final snapshot = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('cost_estimate_items')
 .get();
 if (snapshot.docs.isEmpty) {
 _loadedCostItems = true;
 return;
 }

 final items = snapshot.docs
 .map((doc) => CostEstimateItem.fromJson(doc.data()))
 .toList();
 provider.updateField(
 (data) => data.copyWith(costEstimateItems: _reconcileCostItems(items)),
 );
 _loadedCostItems = true;
 } catch (error) {
 debugPrint('Failed to load cost estimate items: $error');
 }
 }

 Future<void> _persistCostItem(CostEstimateItem item) async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('cost_estimate_items')
 .doc(item.id)
 .set(item.toJson(), SetOptions(merge: true));
 await _markSectionInitialized('cost_estimate_initialized');
 }

 Future<void> _loadWorkspaceState() async {
 final notes = ProjectDataHelper.getData(context).planningNotes;
 final baselineValue =
 notes['planning_cost_estimate_baseline_date']?.trim() ?? '';
 if (baselineValue.isNotEmpty) {
 _baselineConfirmedAt = DateTime.tryParse(baselineValue);
 }
 }

 Future<void> _confirmBaseline() async {
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'cost_estimate',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_cost_estimate_baseline_date':
 DateTime.now().toIso8601String(),
 },
 ),
 showSnackbar: false,
 );
 if (!mounted || !success) return;
 setState(() => _baselineConfirmedAt = DateTime.now());
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Cost estimate baseline confirmed.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 Future<void> _runValidation() async {
 if (_validating) return;
 setState(() => _validating = true);
 final summary = _buildValidationSummary(ProjectDataHelper.getData(context));
 await Future<void>.delayed(const Duration(milliseconds: 250));
 if (!mounted) return;
 setState(() => _validating = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 summary.issues.isEmpty
 ? 'Validation complete. No critical reconciliation issues found.'
 : 'Validation found ${summary.issues.length} issue(s). Review Source Imports.',
 ),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 Future<void> _importAllSources() async {
 if (_importingSources) return;
 final provider = ProjectDataHelper.getProvider(context);
 await _loadCommercialSources();
 final projectData = provider.projectData;
 final imported = _buildImportedSourceItems(projectData);
 if (imported.isEmpty) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No structured cost sources available to import.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }

 setState(() => _importingSources = true);
 try {
 final existingManual = provider.projectData.costEstimateItems.where(
 (item) => !_isAutoImportedCostSource(item.source) && !item.isBaseline,
 );
 final existingBaseline = provider.projectData.costEstimateItems.where(
 (item) => item.isBaseline,
 );
 final merged = _reconcileCostItems([
 ...existingBaseline,
 ...existingManual,
 ...imported,
 ]);
 provider.updateField((data) => data.copyWith(costEstimateItems: merged));
 await provider.saveToFirebase(checkpoint: 'cost_estimate');
 await _replaceAutoImportedDocs(imported);
 if (!mounted) return;
 setState(() => _activeTab = _CostWorkspaceTab.sourceImports);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Imported ${merged.where((item) => _isAutoImportedCostSource(item.source)).length} active cost lines from project sources.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } finally {
 if (mounted) {
 setState(() => _importingSources = false);
 }
 }
 }

 Future<void> _loadCommercialSources() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 final procurementItems =
 await ProcurementService.streamItems(projectId, limit: 400).first;
 final purchaseOrders =
 await ProcurementService.streamPos(projectId, limit: 400).first;
 final contracts =
 await ProcurementService.streamContracts(projectId, limit: 300).first;
 if (!mounted) return;
 setState(() {
 _procurementItems = procurementItems;
 _purchaseOrders = purchaseOrders;
 _contracts = contracts;
 });
 } catch (error) {
 debugPrint('Failed to load commercial sources for cost estimate: $error');
 }
 }

 Future<void> _replaceAutoImportedDocs(List<CostEstimateItem> imported) async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final collection = FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('cost_estimate_items');
 final snapshot = await collection.get();
 final batch = FirebaseFirestore.instance.batch();
 for (final doc in snapshot.docs) {
 final existing = CostEstimateItem.fromJson(doc.data());
 if (_isAutoImportedCostSource(existing.source)) {
 batch.delete(doc.reference);
 }
 }
 for (final item in imported) {
 final reconciled = provider.projectData.costEstimateItems
 .any((existing) => existing.id == item.id);
 if (!reconciled) continue;
 batch.set(
 collection.doc(item.id), item.toJson(), SetOptions(merge: true));
 }
 await batch.commit();
 }

 bool _isAutoImportedCostSource(String source) {
 const autoSources = {
 'project_contractor',
 'project_vendor',
 'project_contract',
 'project_procurement_item',
 'project_procurement_actual',
 'project_purchase_order',
 'planning_allowance',
 'risk_mitigation',
 'project_work_package',
 'project_work_package_actual',
 'planning_staffing',
 'planning_infrastructure',
 'planning_technology',
 };
 return autoSources.contains(source);
 }

 List<CostEstimateItem> _reconcileCostItems(List<CostEstimateItem> items) {
 return _computeReconciliationOutcome(items).activeItems;
 }

 _ReconciliationOutcome _computeReconciliationOutcome(
 List<CostEstimateItem> items) {
 final grouped = <String, List<CostEstimateItem>>{};
 final passthrough = <CostEstimateItem>[];
 for (final item in items) {
 if (!_isAutoImportedCostSource(item.source) || item.isBaseline) {
 passthrough.add(item);
 continue;
 }
 final key = _reconciliationGroupKey(item);
 if (key == null) {
 passthrough.add(item);
 continue;
 }
 grouped.putIfAbsent(key, () => <CostEstimateItem>[]).add(item);
 }

 final reconciled = <CostEstimateItem>[...passthrough];
 final reportEntries = <_ReconciliationEntry>[];
 for (final entry in grouped.entries) {
 final groupItems = entry.value;
 final highestPriority = groupItems
 .map(_costStatePriority)
 .fold<int>(0, (highest, value) => value > highest ? value : highest);
 final retained = groupItems
 .where((item) => _costStatePriority(item) == highestPriority)
 .toList();
 final superseded = groupItems
 .where((item) => _costStatePriority(item) < highestPriority)
 .toList();
 reconciled.addAll(retained);
 for (final replaced in superseded) {
 final winner = retained.first;
 reportEntries.add(
 _ReconciliationEntry(
 key: entry.key,
 superseded: replaced,
 retained: winner,
 reason:
 '${_costStateLabel(winner.costState)} supersedes ${_costStateLabel(replaced.costState)} for the same scope.',
 ),
 );
 }
 }
 return _ReconciliationOutcome(
 activeItems: reconciled,
 reportEntries: reportEntries,
 );
 }

 _ReconciliationReport _buildReconciliationReport(ProjectDataModel data) {
 final imported = _buildImportedSourceItems(data);
 final outcome = _computeReconciliationOutcome(imported);
 return _ReconciliationReport(
 totalImported: imported.length,
 activeImported: outcome.activeItems.length,
 supersededCount: outcome.reportEntries.length,
 entries: outcome.reportEntries,
 );
 }

 String? _reconciliationGroupKey(CostEstimateItem item) {
 if (item.reconciliationReference.trim().isNotEmpty) {
 return item.reconciliationReference.trim();
 }
 if (item.workPackageId.trim().isNotEmpty) {
 return 'work_package:${item.workPackageId.trim()}';
 }
 if (item.contractId.trim().isNotEmpty) {
 return 'contract:${item.contractId.trim()}';
 }
 final procurementId = _procurementRecordKey(item);
 if (procurementId != null) {
 return 'procurement:$procurementId';
 }
 return null;
 }

 String? _procurementRecordKey(CostEstimateItem item) {
 const prefixes = {
 'src_procurement_actual_',
 'src_procurement_',
 };
 for (final prefix in prefixes) {
 if (item.id.startsWith(prefix)) {
 return item.id.substring(prefix.length);
 }
 }
 return null;
 }

 int _costStatePriority(CostEstimateItem item) {
 switch (item.costState) {
 case 'actual':
 return 3;
 case 'committed':
 return 2;
 case 'forecast':
 default:
 return 1;
 }
 }

 List<CostEstimateItem> _buildImportedSourceItems(ProjectDataModel data) {
 final items = <CostEstimateItem>[];

 for (final contractor in data.contractors) {
 final label = contractor.service.trim().isNotEmpty
 ? contractor.service.trim()
 : contractor.name.trim();
 if (label.isEmpty || contractor.estimatedCost <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_contractor_${contractor.id}',
 title: label,
 notes: contractor.notes.trim(),
 amount: contractor.estimatedCost,
 costType: 'direct',
 source: 'project_contractor',
 costState: 'forecast',
 reconciliationReference: 'contractor:${contractor.id}',
 phase: 'planning',
 estimatingMethod: 'analogous',
 estimatingBasis: 'Imported from contractor estimate',
 quoteReference: contractor.status.trim(),
 ),
 );
 }

 for (final vendor in data.vendors) {
 final label = vendor.name.trim();
 if (label.isEmpty || vendor.estimatedPrice <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_vendor_${vendor.id}',
 title: label,
 notes: vendor.notes.trim().isNotEmpty
 ? vendor.notes.trim()
 : vendor.equipmentOrService.trim(),
 amount: vendor.estimatedPrice,
 costType: _inferCostType(vendor.equipmentOrService),
 source: 'project_vendor',
 costState: 'forecast',
 reconciliationReference: 'vendor:${vendor.id}',
 phase: 'planning',
 estimatingMethod: 'quote_based',
 estimatingBasis: 'Imported from vendor estimate',
 quoteReference: vendor.procurementStage.trim(),
 ),
 );
 }

 for (final contract in _contracts) {
 final label = contract.title.trim();
 if (label.isEmpty || contract.estimatedCost <= 0) continue;
 final reconciliationReference =
 _contractReconciliationReference(contract.id);
 items.add(
 CostEstimateItem(
 id: 'src_contract_${contract.id}',
 title: label,
 notes: _joinNotes([
 contract.contractorName.trim(),
 contract.description.trim(),
 ]),
 amount: contract.estimatedCost,
 costType: 'direct',
 source: 'project_contract',
 costState: _contractCostState(contract),
 reconciliationReference: reconciliationReference,
 phase: 'planning',
 estimatingMethod: 'quote_based',
 estimatingBasis: 'Imported from contract plan',
 contractId: contract.id,
 quoteReference: contract.status.name,
 ),
 );
 }

 for (final item in _procurementItems) {
 if (item.name.trim().isEmpty || item.budget <= 0) continue;
 final reconciliationReference = _procurementReconciliationReference(item);
 items.add(
 CostEstimateItem(
 id: 'src_procurement_${item.id}',
 title: item.name.trim(),
 notes: _joinNotes([
 item.category.trim(),
 item.description.trim(),
 item.comments.trim(),
 ]),
 amount: item.budget,
 costType: 'direct',
 source: 'project_procurement_item',
 costState: 'forecast',
 reconciliationReference: reconciliationReference,
 phase: item.projectPhase.trim().toLowerCase(),
 estimatingMethod: 'bottoms_up',
 estimatingBasis: 'Imported from procurement budget',
 scheduleActivityId: item.linkedMilestoneId ?? '',
 wbsItemId: item.linkedWbsId ?? '',
 contractId: item.contractId ?? '',
 ),
 );
 if (item.spent > 0) {
 items.add(
 CostEstimateItem(
 id: 'src_procurement_actual_${item.id}',
 title: '${item.name.trim()} actual spend',
 notes: _joinNotes([
 item.category.trim(),
 item.description.trim(),
 'Imported from procurement actual spend',
 ]),
 amount: item.spent,
 costType: 'direct',
 source: 'project_procurement_actual',
 costState: 'actual',
 reconciliationReference: reconciliationReference,
 phase: item.projectPhase.trim().toLowerCase(),
 estimatingMethod: 'actual',
 estimatingBasis: 'Imported from procurement actual spend',
 scheduleActivityId: item.linkedMilestoneId ?? '',
 wbsItemId: item.linkedWbsId ?? '',
 contractId: item.contractId ?? '',
 ),
 );
 }
 }

 for (final order in _purchaseOrders) {
 final label = order.poNumber.trim().isNotEmpty
 ? order.poNumber.trim()
 : order.vendorName.trim();
 if (label.isEmpty || order.amount <= 0) continue;
 final reconciliationReference =
 _purchaseOrderReconciliationReference(order);
 items.add(
 CostEstimateItem(
 id: 'src_purchase_order_${order.id}',
 title: label,
 notes: _joinNotes([
 order.vendorName.trim(),
 order.category.trim(),
 'Approval: ${order.approvalStatusDisplay}',
 ]),
 amount: order.amount,
 costType: 'direct',
 source: 'project_purchase_order',
 costState: _purchaseOrderCostState(order),
 reconciliationReference: reconciliationReference,
 phase: 'planning',
 estimatingMethod: 'quote_based',
 estimatingBasis: 'Imported from purchase order commitment',
 quoteReference: order.poNumber.trim(),
 ),
 );
 }

 for (final allowance in data.frontEndPlanning.allowanceItems) {
 if (allowance.name.trim().isEmpty || allowance.amount <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_allowance_${allowance.id}',
 title: allowance.name.trim(),
 notes: allowance.notes.trim(),
 amount: allowance.amount,
 costType: allowance.type.toLowerCase().contains('contingency')
 ? 'indirect'
 : 'direct',
 source: 'planning_allowance',
 costState: 'forecast',
 reconciliationReference: 'allowance:${allowance.id}',
 phase: 'planning',
 estimatingMethod: 'top_down',
 estimatingBasis: 'Imported from allowance register',
 contingencyAmount: allowance.amount,
 ),
 );
 if (allowance.releasedAmount > 0) {
 items.add(
 CostEstimateItem(
 id: 'src_allowance_released_${allowance.id}',
 title: '${allowance.name.trim()} released',
 notes: _joinNotes([
 allowance.notes.trim(),
 'Release status: ${allowance.releaseStatus.trim()}',
 ]),
 amount: allowance.releasedAmount,
 costType: 'indirect',
 source: 'planning_allowance',
 costState: 'committed',
 reconciliationReference: 'allowance:${allowance.id}',
 phase: 'planning',
 estimatingMethod: 'allowance_release',
 estimatingBasis: 'Imported from allowance released amount',
 contingencyAmount: allowance.releasedAmount,
 ),
 );
 }
 if (allowance.actualAmount > 0) {
 items.add(
 CostEstimateItem(
 id: 'src_allowance_actual_${allowance.id}',
 title: '${allowance.name.trim()} actual',
 notes: allowance.notes.trim(),
 amount: allowance.actualAmount,
 costType: 'indirect',
 source: 'planning_allowance',
 costState: 'actual',
 reconciliationReference: 'allowance:${allowance.id}',
 phase: 'planning',
 estimatingMethod: 'actual',
 estimatingBasis: 'Imported from allowance actual usage',
 contingencyAmount: allowance.actualAmount,
 ),
 );
 }
 }

 for (var index = 0; index < data.technologyInventory.length; index++) {
 final item = data.technologyInventory[index];
 final label = (item['name'] ?? item['title'] ?? '').toString().trim();
 final amount = _technologyAmount(item, 'cost');
 if (label.isEmpty || amount <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_technology_inventory_$index',
 title: label,
 notes: _joinNotes([
 (item['category'] ?? '').toString().trim(),
 (item['description'] ?? '').toString().trim(),
 'Imported from technology inventory',
 ]),
 amount: amount,
 costType: 'direct',
 source: 'planning_technology',
 costState: 'forecast',
 reconciliationReference: 'technology:inventory:$index',
 phase: 'planning',
 estimatingMethod: 'bottoms_up',
 estimatingBasis: 'Imported from technology inventory',
 ),
 );
 }

 for (var index = 0; index < data.aiIntegrations.length; index++) {
 final item = data.aiIntegrations[index];
 final label = (item['name'] ?? item['title'] ?? '').toString().trim();
 final amount = _technologyAmount(item, 'cost');
 if (label.isEmpty || amount <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_ai_integration_$index',
 title: label,
 notes: _joinNotes([
 (item['status'] ?? '').toString().trim(),
 (item['description'] ?? '').toString().trim(),
 'Imported from AI integrations plan',
 ]),
 amount: amount,
 costType: 'direct',
 source: 'planning_technology',
 costState: 'forecast',
 reconciliationReference: 'technology:ai:$index',
 phase: 'planning',
 estimatingMethod: 'analogous',
 estimatingBasis: 'Imported from AI integration plan',
 ),
 );
 }

 for (var index = 0; index < data.externalIntegrations.length; index++) {
 final item = data.externalIntegrations[index];
 final label = (item['name'] ?? item['title'] ?? '').toString().trim();
 final amount = _technologyAmount(item, 'implementationCost');
 if (label.isEmpty || amount <= 0) continue;
 items.add(
 CostEstimateItem(
 id: 'src_external_integration_$index',
 title: label,
 notes: _joinNotes([
 (item['vendor'] ?? '').toString().trim(),
 (item['description'] ?? '').toString().trim(),
 'Imported from external integrations plan',
 ]),
 amount: amount,
 costType: 'direct',
 source: 'planning_technology',
 costState: 'forecast',
 reconciliationReference: 'technology:external:$index',
 phase: 'planning',
 estimatingMethod: 'quote_based',
 estimatingBasis: 'Imported from external integration plan',
 ),
 );
 }

 for (final workPackage in data.workPackages) {
 if (workPackage.title.trim().isEmpty || workPackage.budgetedCost <= 0) {
 continue;
 }
 items.add(
 CostEstimateItem(
 id: 'src_work_package_${workPackage.id}',
 title: workPackage.title.trim(),
 notes: workPackage.description.trim(),
 amount: workPackage.budgetedCost,
 costType: 'direct',
 source: 'project_work_package',
 costState: 'forecast',
 reconciliationReference: 'work_package:${workPackage.id}',
 isBaseline: false,
 workPackageId: workPackage.id,
 workPackageTitle: workPackage.title.trim(),
 phase: workPackage.phase.trim(),
 estimatingMethod: 'bottoms_up',
 estimatingBasis: 'Imported from work package budget',
 ),
 );
 if (workPackage.actualCost > 0) {
 items.add(
 CostEstimateItem(
 id: 'src_work_package_actual_${workPackage.id}',
 title: '${workPackage.title.trim()} actual',
 notes: workPackage.description.trim(),
 amount: workPackage.actualCost,
 costType: 'direct',
 source: 'project_work_package_actual',
 costState: 'actual',
 reconciliationReference: 'work_package:${workPackage.id}',
 isBaseline: false,
 workPackageId: workPackage.id,
 workPackageTitle: workPackage.title.trim(),
 phase: workPackage.phase.trim(),
 estimatingMethod: 'actual',
 estimatingBasis: 'Imported from work package actual cost',
 ),
 );
 }
 }

 for (final staffing in data.staffingRequirements) {
 if (staffing.title.trim().isEmpty || staffing.estimatedTotal <= 0) {
 continue;
 }
 items.add(
 CostEstimateItem(
 id: 'src_staffing_requirement_${staffing.id}',
 title: staffing.title.trim(),
 notes: _joinNotes([
 staffing.personName.trim(),
 staffing.location.trim(),
 staffing.notes.trim(),
 ]),
 amount: staffing.estimatedTotal,
 costType: 'direct',
 source: 'planning_staffing',
 costState: 'forecast',
 reconciliationReference: 'staffing_requirement:${staffing.id}',
 phase: 'planning',
 estimatingMethod: 'bottoms_up',
 estimatingBasis: 'Imported from organization staffing plan',
 quantity: staffing.headcount,
 unitRate: staffing.monthlyCost,
 unitOfMeasure: 'staff-month',
 ),
 );
 }

 for (final infrastructureItem in data.planningInfrastructureItems) {
 if (infrastructureItem.name.trim().isEmpty ||
 infrastructureItem.potentialCost <= 0) {
 continue;
 }
 items.add(
 CostEstimateItem(
 id: 'src_planning_infrastructure_${infrastructureItem.id}',
 title: infrastructureItem.name.trim(),
 notes: _joinNotes([
 infrastructureItem.summary.trim(),
 infrastructureItem.details.trim(),
 ]),
 amount: infrastructureItem.potentialCost,
 costType: 'direct',
 source: 'planning_infrastructure',
 costState: 'forecast',
 reconciliationReference:
 'planning_infrastructure:${infrastructureItem.id}',
 phase: 'planning',
 estimatingMethod: 'analogous',
 estimatingBasis: 'Imported from planning infrastructure register',
 ),
 );
 }

 return items;
 }

 List<_SourceSummary> _buildSourceSummaries(ProjectDataModel data) {
 final items = data.costEstimateItems;
 final technologySourceCount = data.technologyInventory
 .where((item) => _technologyAmount(item, 'cost') > 0)
 .length +
 data.aiIntegrations
 .where((item) => _technologyAmount(item, 'cost') > 0)
 .length +
 data.externalIntegrations
 .where((item) => _technologyAmount(item, 'implementationCost') > 0)
 .length;
 final technologyTotal = data.technologyInventory.fold<double>(
 0,
 (totalValue, item) => totalValue + _technologyAmount(item, 'cost'),
 ) +
 data.aiIntegrations.fold<double>(
 0,
 (totalValue, item) => totalValue + _technologyAmount(item, 'cost'),
 ) +
 data.externalIntegrations.fold<double>(
 0,
 (totalValue, item) =>
 totalValue + _technologyAmount(item, 'implementationCost'),
 );
 return [
 _SourceSummary(
 title: 'Initiation baseline',
 subtitle: 'Cost benefit analysis and preferred solution inputs',
 sourceKey: 'initiation',
 total: _sumBySources(items, const {
 'initiation_cost_rows',
 'initiation_category_costs',
 'preferred_solution',
 }),
 sourceCount: items
 .where((item) => {
 'initiation_cost_rows',
 'initiation_category_costs',
 'preferred_solution',
 }.contains(item.source))
 .length,
 status: items.any((item) => item.isBaseline)
 ? _SourceSummaryStatus.imported
 : _SourceSummaryStatus.missing,
 ),
 _SourceSummary(
 title: 'Contractors',
 subtitle:
 '${data.contractors.length} contractor entries with estimated cost',
 sourceKey: 'contractors',
 total: data.contractors.fold<double>(0,
 (totalValue, contractor) => totalValue + contractor.estimatedCost),
 sourceCount: data.contractors.where((c) => c.estimatedCost > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_contractor').length,
 status: _coverageStatus(
 expectedCount:
 data.contractors.where((c) => c.estimatedCost > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_contractor').length,
 ),
 ),
 _SourceSummary(
 title: 'Vendors',
 subtitle: '${data.vendors.length} vendor estimates',
 sourceKey: 'vendors',
 total: data.vendors.fold<double>(
 0, (totalValue, vendor) => totalValue + vendor.estimatedPrice),
 sourceCount: data.vendors.where((v) => v.estimatedPrice > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_vendor').length,
 status: _coverageStatus(
 expectedCount: data.vendors.where((v) => v.estimatedPrice > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_vendor').length,
 ),
 ),
 _SourceSummary(
 title: 'Contracts',
 subtitle: '${_contracts.length} planned contract values',
 sourceKey: 'contracts',
 total: _contracts.fold<double>(
 0, (totalValue, contract) => totalValue + contract.estimatedCost),
 sourceCount:
 _contracts.where((contract) => contract.estimatedCost > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_contract').length,
 status: _coverageStatus(
 expectedCount:
 _contracts.where((contract) => contract.estimatedCost > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_contract').length,
 ),
 ),
 _SourceSummary(
 title: 'Allowances & contingency',
 subtitle:
 '${data.frontEndPlanning.allowanceItems.length} allowance items',
 sourceKey: 'allowances',
 total: data.frontEndPlanning.allowanceItems
 .fold<double>(0, (totalValue, item) => totalValue + item.amount),
 sourceCount: data.frontEndPlanning.allowanceItems
 .where((item) => item.amount > 0)
 .length,
 importedCount:
 items.where((item) => item.source == 'planning_allowance').length,
 status: _coverageStatus(
 expectedCount: data.frontEndPlanning.allowanceItems
 .where((item) => item.amount > 0)
 .length,
 importedCount:
 items.where((item) => item.source == 'planning_allowance').length,
 ),
 ),
 _SourceSummary(
 title: 'Procurement budgets',
 subtitle: '${_procurementItems.length} procurement items with budgets',
 sourceKey: 'procurement',
 total: _procurementItems.fold<double>(
 0, (totalValue, item) => totalValue + item.budget),
 sourceCount: _procurementItems.where((item) => item.budget > 0).length,
 importedCount: items
 .where((item) => item.source == 'project_procurement_item')
 .length,
 status: _coverageStatus(
 expectedCount:
 _procurementItems.where((item) => item.budget > 0).length,
 importedCount: items
 .where((item) => item.source == 'project_procurement_item')
 .length,
 ),
 ),
 _SourceSummary(
 title: 'Purchase orders',
 subtitle:
 '${_purchaseOrders.length} committed or pending purchase orders',
 sourceKey: 'purchase_orders',
 total: _purchaseOrders.fold<double>(
 0, (totalValue, order) => totalValue + order.amount),
 sourceCount: _purchaseOrders.where((order) => order.amount > 0).length,
 importedCount: items
 .where((item) => item.source == 'project_purchase_order')
 .length,
 status: _coverageStatus(
 expectedCount:
 _purchaseOrders.where((order) => order.amount > 0).length,
 importedCount: items
 .where((item) => item.source == 'project_purchase_order')
 .length,
 ),
 ),
 _SourceSummary(
 title: 'Work packages',
 subtitle: '${data.workPackages.length} packages with budget linkage',
 sourceKey: 'work_packages',
 total: data.workPackages.fold<double>(
 0, (totalValue, item) => totalValue + item.budgetedCost),
 sourceCount:
 data.workPackages.where((item) => item.budgetedCost > 0).length,
 importedCount:
 items.where((item) => item.source == 'project_work_package').length,
 status: _coverageStatus(
 expectedCount:
 data.workPackages.where((item) => item.budgetedCost > 0).length,
 importedCount: items
 .where((item) => item.source == 'project_work_package')
 .length,
 ),
 ),
 _SourceSummary(
 title: 'Technology planning',
 subtitle:
 '${data.technologyInventory.length + data.aiIntegrations.length + data.externalIntegrations.length} structured technology cost inputs',
 sourceKey: 'technology',
 total: technologyTotal,
 sourceCount: technologySourceCount,
 importedCount:
 items.where((item) => item.source == 'planning_technology').length,
 status: _coverageStatus(
 expectedCount: technologySourceCount,
 importedCount: items
 .where((item) => item.source == 'planning_technology')
 .length,
 ),
 ),
 _SourceSummary(
 title: 'Infrastructure',
 subtitle:
 '${data.planningInfrastructureItems.length} structured infrastructure cost items from the planning infrastructure page',
 sourceKey: 'infrastructure',
 total: data.planningInfrastructureItems.fold<double>(
 0,
 (totalValue, item) => totalValue + item.potentialCost,
 ),
 sourceCount: data.planningInfrastructureItems
 .where((item) => item.potentialCost > 0)
 .length,
 importedCount: items
 .where((item) => item.source == 'planning_infrastructure')
 .length,
 status: _coverageStatus(
 expectedCount: data.planningInfrastructureItems
 .where((item) => item.potentialCost > 0)
 .length,
 importedCount: items
 .where((item) => item.source == 'planning_infrastructure')
 .length,
 ),
 ),
 _SourceSummary(
 title: 'Personnel / staffing',
 subtitle:
 '${data.staffingRequirements.length} staffing requirements from the organization staffing plan',
 sourceKey: 'staffing',
 total: data.staffingRequirements.fold<double>(
 0,
 (totalValue, item) => totalValue + item.estimatedTotal,
 ),
 sourceCount: data.staffingRequirements
 .where((item) => item.estimatedTotal > 0)
 .length,
 importedCount:
 items.where((item) => item.source == 'planning_staffing').length,
 status: _coverageStatus(
 expectedCount: data.staffingRequirements
 .where((item) => item.estimatedTotal > 0)
 .length,
 importedCount:
 items.where((item) => item.source == 'planning_staffing').length,
 ),
 ),
 ];
 }

 double _sumBySources(List<CostEstimateItem> items, Set<String> sources) {
 return items
 .where((item) => sources.contains(item.source))
 .fold<double>(0, (totalValue, item) => totalValue + item.amount);
 }

 _SourceSummaryStatus _coverageStatus({
 required int expectedCount,
 required int importedCount,
 }) {
 if (expectedCount == 0) return _SourceSummaryStatus.missing;
 if (importedCount == 0) return _SourceSummaryStatus.missing;
 if (importedCount < expectedCount) return _SourceSummaryStatus.partial;
 return _SourceSummaryStatus.imported;
 }

 _ValidationSummary _buildValidationSummary(ProjectDataModel data) {
 final issues = <String>[];
 if (data.contractors.any((c) => c.estimatedCost > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_contractor')) {
 issues.add(
 'Contractor estimates exist but are not imported into the cost estimate.');
 }
 if (data.vendors.any((v) => v.estimatedPrice > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_vendor')) {
 issues.add(
 'Vendor estimates exist but are not imported into the cost estimate.');
 }
 if (_contracts.any((contract) => contract.estimatedCost > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_contract')) {
 issues.add(
 'Planned contracts exist but are not imported into the cost estimate.');
 }
 if (data.frontEndPlanning.allowanceItems.any((a) => a.amount > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'planning_allowance')) {
 issues.add(
 'Allowance items exist but are not represented in the estimate.');
 }
 if (_procurementItems.any((item) => item.budget > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_procurement_item')) {
 issues.add(
 'Procurement budgets exist but are not imported into the estimate.');
 }
 if (_purchaseOrders.any((order) => order.amount > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_purchase_order')) {
 issues.add(
 'Purchase order commitments exist but are not imported into the estimate.');
 }
 if (data.workPackages.any((wp) => wp.budgetedCost > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'project_work_package')) {
 issues
 .add('Budgeted work packages are not yet linked to estimate lines.');
 }
 final technologySourceCount = data.technologyInventory
 .where((item) => _technologyAmount(item, 'cost') > 0)
 .length +
 data.aiIntegrations
 .where((item) => _technologyAmount(item, 'cost') > 0)
 .length +
 data.externalIntegrations
 .where((item) => _technologyAmount(item, 'implementationCost') > 0)
 .length;
 if (technologySourceCount > 0 &&
 !data.costEstimateItems
 .any((item) => item.source == 'planning_technology')) {
 issues.add(
 'Technology budget inputs exist but are not imported into the estimate.');
 }
 if (data.staffingRequirements.any((item) => item.estimatedTotal > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'planning_staffing')) {
 issues.add(
 'Staffing costs exist in the organization staffing plan but are not imported into the estimate.');
 }
 if (data.planningInfrastructureItems
 .any((item) => item.potentialCost > 0) &&
 !data.costEstimateItems
 .any((item) => item.source == 'planning_infrastructure')) {
 issues.add(
 'Infrastructure cost items exist in the planning infrastructure page but are not imported into the estimate.');
 }
 if (data.executionRiskMitigations.isNotEmpty) {
 issues.add(
 'Execution risk mitigations are intentionally excluded from the planning cost estimate.');
 }
 if (data.frontEndPlanning.technologyPersonnelItems.isEmpty &&
 (data.technologyInventory.isNotEmpty ||
 data.aiIntegrations.isNotEmpty ||
 data.externalIntegrations.isNotEmpty)) {
 issues.add(
 'Technology cost sources exist but no structured technology ownership rows have been captured.');
 }
 final unlinkedManual = data.costEstimateItems.where((item) {
 if (item.isBaseline) return false;
 if (_isAutoImportedCostSource(item.source)) return false;
 return item.workPackageId.trim().isEmpty &&
 item.scheduleActivityId.trim().isEmpty &&
 item.estimatingBasis.trim().isEmpty;
 }).length;
 if (unlinkedManual > 0) {
 issues.add(
 '$unlinkedManual manual cost item(s) have no linkage or estimating basis.');
 }
 return _ValidationSummary(issues: issues);
 }

 List<_OverviewRow> _buildOverviewRows(
 ProjectDataModel data, {
 required double baselineTotal,
 required double total,
 required double committedTotal,
 required double actualTotal,
 required List<_SourceSummary> sourceSummaries,
 }) {
 final contractorTotal = data.contractors.fold<double>(
 0, (totalValue, contractor) => totalValue + contractor.estimatedCost);
 final vendorTotal = data.vendors.fold<double>(
 0, (totalValue, vendor) => totalValue + vendor.estimatedPrice);
 final contractTotal = _contracts.fold<double>(
 0, (totalValue, contract) => totalValue + contract.estimatedCost);
 final allowanceTotal = data.frontEndPlanning.allowanceItems.fold<double>(
 0, (totalValue, allowance) => totalValue + allowance.amount);
 final procurementTotal = _procurementItems.fold<double>(
 0, (totalValue, item) => totalValue + item.budget);
 final purchaseOrderTotal = _purchaseOrders.fold<double>(
 0, (totalValue, order) => totalValue + order.amount);
 final workPackageTotal = data.workPackages
 .fold<double>(0, (totalValue, wp) => totalValue + wp.budgetedCost);
 final staffingTotal = data.staffingRequirements
 .fold<double>(0, (totalValue, row) => totalValue + row.estimatedTotal);
 final infrastructureTotal = data.planningInfrastructureItems
 .fold<double>(0, (totalValue, item) => totalValue + item.potentialCost);
 final technologyTotal = data.technologyInventory.fold<double>(
 0,
 (totalValue, item) => totalValue + _technologyAmount(item, 'cost'),
 ) +
 data.aiIntegrations.fold<double>(
 0,
 (totalValue, item) => totalValue + _technologyAmount(item, 'cost'),
 ) +
 data.externalIntegrations.fold<double>(
 0,
 (totalValue, item) =>
 totalValue + _technologyAmount(item, 'implementationCost'),
 );
 final importedSourcesTotal = sourceSummaries.fold<double>(
 0,
 (totalValue, source) => totalValue + source.total,
 );
 return [
 _OverviewRow(label: 'Planning forecast total', value: total),
 _OverviewRow(label: 'Committed reference total', value: committedTotal),
 _OverviewRow(label: 'Actual reference total', value: actualTotal),
 _OverviewRow(label: 'Initiation baseline', value: baselineTotal),
 _OverviewRow(label: 'Management reserve', value: data.managementReserve),
 _OverviewRow(
 label: 'Imported source coverage', value: importedSourcesTotal),
 _OverviewRow(label: 'Contractor estimates', value: contractorTotal),
 _OverviewRow(label: 'Vendor estimates', value: vendorTotal),
 _OverviewRow(label: 'Contract values', value: contractTotal),
 _OverviewRow(label: 'Allowance / contingency', value: allowanceTotal),
 _OverviewRow(label: 'Procurement budgets', value: procurementTotal),
 _OverviewRow(
 label: 'Purchase order commitments', value: purchaseOrderTotal),
 _OverviewRow(label: 'Work package budgets', value: workPackageTotal),
 _OverviewRow(label: 'Staffing plan costs', value: staffingTotal),
 _OverviewRow(
 label: 'Infrastructure plan costs', value: infrastructureTotal),
 _OverviewRow(label: 'Technology plan costs', value: technologyTotal),
 ];
 }

 List<_SourceDetailRow> _buildContractsProcurementRows(ProjectDataModel data) {
 final rows = <_SourceDetailRow>[];
 for (final contractor in data.contractors) {
 if (contractor.estimatedCost <= 0) continue;
 rows.add(_SourceDetailRow(
 title: contractor.service.trim().isNotEmpty
 ? contractor.service.trim()
 : contractor.name.trim(),
 subtitle: contractor.status.trim().isEmpty
 ? 'Contractor estimate'
 : contractor.status.trim(),
 amount: contractor.estimatedCost,
 ));
 }
 for (final vendor in data.vendors) {
 if (vendor.estimatedPrice <= 0) continue;
 rows.add(_SourceDetailRow(
 title: vendor.name.trim(),
 subtitle: vendor.equipmentOrService.trim().isEmpty
 ? 'Vendor estimate'
 : vendor.equipmentOrService.trim(),
 amount: vendor.estimatedPrice,
 ));
 }
 for (final contract in _contracts) {
 if (contract.estimatedCost <= 0) continue;
 rows.add(_SourceDetailRow(
 title: contract.title.trim(),
 subtitle: contract.contractorName.trim().isEmpty
 ? 'Planned contract'
 : contract.contractorName.trim(),
 amount: contract.estimatedCost,
 ));
 }
 for (final item in _procurementItems) {
 if (item.budget <= 0) continue;
 rows.add(_SourceDetailRow(
 title: item.name.trim(),
 subtitle: item.category.trim().isEmpty
 ? 'Procurement budget'
 : item.category.trim(),
 amount: item.budget,
 ));
 }
 for (final order in _purchaseOrders) {
 if (order.amount <= 0) continue;
 rows.add(_SourceDetailRow(
 title: order.poNumber.trim().isEmpty
 ? order.vendorName.trim()
 : order.poNumber.trim(),
 subtitle: order.vendorName.trim().isEmpty
 ? 'Purchase order'
 : order.vendorName.trim(),
 amount: order.amount,
 ));
 }
 if (rows.isEmpty) {
 rows.add(const _SourceDetailRow(
 title: 'No structured contract or procurement costs',
 subtitle: 'Add contractor or vendor estimates to surface them here.',
 amount: 0,
 ));
 }
 return rows;
 }

 List<_SourceDetailRow> _buildStaffingInfrastructureRows(
 ProjectDataModel data) {
 final rows = <_SourceDetailRow>[];
 for (final staffing in data.staffingRequirements) {
 if (staffing.estimatedTotal <= 0) continue;
 rows.add(
 _SourceDetailRow(
 title: staffing.title.trim().isEmpty
 ? 'Unnamed staffing requirement'
 : staffing.title.trim(),
 subtitle: _joinNotes([
 staffing.personName.trim(),
 '${staffing.headcount} x ${staffing.plannedMonths.toStringAsFixed(1)} months',
 staffing.notes.trim(),
 ]),
 amount: staffing.estimatedTotal,
 ),
 );
 }
 for (final infrastructureItem in data.planningInfrastructureItems) {
 if (infrastructureItem.potentialCost <= 0) continue;
 rows.add(
 _SourceDetailRow(
 title: infrastructureItem.name.trim().isEmpty
 ? 'Unnamed infrastructure item'
 : infrastructureItem.name.trim(),
 subtitle: _joinNotes([
 infrastructureItem.summary.trim(),
 infrastructureItem.owner.trim(),
 infrastructureItem.status.trim(),
 ]),
 amount: infrastructureItem.potentialCost,
 ),
 );
 }
 if (rows.isEmpty) {
 rows.add(const _SourceDetailRow(
 title: 'No structured staffing or infrastructure costs',
 subtitle:
 'Add staffing costs in the organization staffing plan and infrastructure costs in the planning infrastructure page.',
 amount: 0,
 ));
 }
 return rows;
 }

 List<_SourceDetailRow> _buildContingencyRiskRows(ProjectDataModel data) {
 final rows = <_SourceDetailRow>[];
 for (final allowance in data.frontEndPlanning.allowanceItems) {
 if (allowance.amount <= 0) continue;
 rows.add(_SourceDetailRow(
 title: allowance.name.trim().isEmpty
 ? 'Allowance ${allowance.number}'
 : allowance.name.trim(),
 subtitle: _joinNotes([
 allowance.type.trim().isEmpty ? 'Allowance' : allowance.type.trim(),
 'Release: ${allowance.releaseStatus.trim()}',
 allowance.releasedAmount > 0
 ? 'Released ${allowance.releasedAmount.toStringAsFixed(2)}'
 : '',
 allowance.actualAmount > 0
 ? 'Actual ${allowance.actualAmount.toStringAsFixed(2)}'
 : '',
 ]),
 amount: allowance.amount,
 ));
 }
 if (rows.isEmpty) {
 rows.add(const _SourceDetailRow(
 title: 'No structured contingency exposure',
 subtitle: 'Allowance inputs have not been added yet.',
 amount: 0,
 ));
 }
 if (data.executionRiskMitigations.isNotEmpty) {
 rows.add(const _SourceDetailRow(
 title: 'Execution risk mitigations are excluded here',
 subtitle:
 'Risk mitigation costs are tracked downstream and are intentionally not part of the planning cost estimate.',
 amount: 0,
 ));
 }
 return rows;
 }

 double _technologyAmount(Map<String, dynamic> item, String key) {
 final raw = (item[key] ?? '').toString();
 if (raw.trim().isEmpty) return 0;
 return _parseCurrency(raw);
 }

 String _joinNotes(List<String> values) {
 return values.where((value) => value.trim().isNotEmpty).join('\n');
 }

 String _contractReconciliationReference(String contractId) {
 return 'commercial_contract:${contractId.trim()}';
 }

 String _procurementReconciliationReference(ProcurementItemModel item) {
 final contractId = (item.contractId ?? '').trim();
 if (contractId.isNotEmpty) {
 return _contractReconciliationReference(contractId);
 }
 final vendorId = (item.vendorId ?? '').trim();
 final category = _normalizeReconciliationToken(item.category);
 if (vendorId.isNotEmpty && category.isNotEmpty) {
 return 'commercial_vendor:$vendorId:$category';
 }
 if (vendorId.isNotEmpty) {
 return 'commercial_vendor:$vendorId';
 }
 return 'commercial_procurement:${item.id}';
 }

 String _purchaseOrderReconciliationReference(PurchaseOrderModel order) {
 final vendorId = (order.vendorId ?? '').trim();
 final normalizedCategory = _normalizeReconciliationToken(order.category);

 final exactProcurementMatches = _procurementItems.where((item) {
 return (item.vendorId ?? '').trim() == vendorId &&
 vendorId.isNotEmpty &&
 _normalizeReconciliationToken(item.category) == normalizedCategory;
 }).toList();
 final vendorProcurementMatches = _procurementItems.where((item) {
 return (item.vendorId ?? '').trim() == vendorId && vendorId.isNotEmpty;
 }).toList();

 final exactContractMatches = exactProcurementMatches
 .map((item) => (item.contractId ?? '').trim())
 .where((value) => value.isNotEmpty)
 .toSet()
 .toList();
 if (exactContractMatches.length == 1) {
 return _contractReconciliationReference(exactContractMatches.single);
 }

 final vendorContractMatches = vendorProcurementMatches
 .map((item) => (item.contractId ?? '').trim())
 .where((value) => value.isNotEmpty)
 .toSet()
 .toList();
 if (vendorContractMatches.length == 1) {
 return _contractReconciliationReference(vendorContractMatches.single);
 }

 if (exactProcurementMatches.length == 1) {
 return _procurementReconciliationReference(
 exactProcurementMatches.single);
 }
 if (vendorProcurementMatches.length == 1) {
 return _procurementReconciliationReference(
 vendorProcurementMatches.single);
 }

 final vendorName = _normalizeReconciliationToken(order.vendorName);
 final contractNameMatches = _contracts.where((contract) {
 return _normalizeReconciliationToken(contract.contractorName) ==
 vendorName &&
 vendorName.isNotEmpty;
 }).toList();
 if (contractNameMatches.length == 1) {
 return _contractReconciliationReference(contractNameMatches.single.id);
 }

 if (vendorId.isNotEmpty && normalizedCategory.isNotEmpty) {
 return 'commercial_vendor:$vendorId:$normalizedCategory';
 }
 if (vendorId.isNotEmpty) {
 return 'commercial_vendor:$vendorId';
 }
 return 'commercial_po:${order.id}';
 }

 String _normalizeReconciliationToken(String value) {
 return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
 }

 String _purchaseOrderCostState(PurchaseOrderModel order) {
 if (order.status == PurchaseOrderStatus.received) return 'actual';
 if (order.approvalStatus == 'approved' ||
 order.status == PurchaseOrderStatus.issued ||
 order.status == PurchaseOrderStatus.inTransit) {
 return 'committed';
 }
 return 'forecast';
 }

 String _contractCostState(ContractModel contract) {
 switch (contract.status) {
 case ContractStatus.approved:
 case ContractStatus.executed:
 return 'committed';
 case ContractStatus.expired:
 case ContractStatus.terminated:
 return 'actual';
 case ContractStatus.draft:
 case ContractStatus.under_review:
 return 'forecast';
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Cost Estimate',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_cost_estimate_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _TopUtilityBar extends StatelessWidget {
 const _TopUtilityBar({required this.onBack, required this.onForward});

 final VoidCallback onBack;
 final VoidCallback onForward;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 _circleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 12),
 _circleButton(
 icon: Icons.arrow_forward_ios_rounded, onTap: onForward),
 const SizedBox(width: 20),
 const Text(
 'Cost Estimate',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 const SizedBox(width: 8),
 const _UserChip(name: '', role: ''),
 ],
 ),
 );
 }

 Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
 ),
 );
 }
}

class _HeroBanner extends StatelessWidget {
 const _HeroBanner();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFFFFB200),
 borderRadius: BorderRadius.circular(24),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFFFFB200).withOpacity(0.25),
 blurRadius: 24,
 offset: const Offset(0, 16),
 ),
 ],
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Project Cost Estimate',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Colors.white),
 ),
 SizedBox(height: 8),
 Text(
 'Comprehensive breakdown of all project costs by category.',
 style: TextStyle(fontSize: 14, color: Colors.white),
 ),
 ],
 ),
 ),
 const SizedBox(width: 32),
 const Icon(Icons.stacked_bar_chart_rounded,
 color: Colors.white, size: 46),
 ],
 ),
 );
 }
}

class _MetricStrip extends StatelessWidget {
 const _MetricStrip({required this.metrics, required this.isMobile});

 final List<_CostSummary> metrics;
 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: metrics
 .map(
 (metric) => _MetricCard(
 summary: metric,
 width: isMobile ? double.infinity : 260,
 ),
 )
 .toList(),
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({required this.summary, required this.width});

 final _CostSummary summary;
 final double width;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: width,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: summary.backgroundColor,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: summary.accentColor.withOpacity(0.12)),
 boxShadow: [
 BoxShadow(
 color: summary.accentColor.withOpacity(0.08),
 blurRadius: 18,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (summary.badgeLabel != null) ...[
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: summary.accentColor.withOpacity(0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.stacked_line_chart,
 size: 14, color: summary.accentColor),
 const SizedBox(width: 6),
 Text(
 summary.badgeLabel!,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: summary.accentColor),
 ),
 ],
 ),
 ),
 const SizedBox(height: 14),
 ],
 Text(
 summary.title,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: summary.accentColor.withOpacity(0.9)),
 ),
 const SizedBox(height: 12),
 Text(
 formatCurrency(summary.amount),
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: summary.accentColor),
 ),
 const SizedBox(height: 8),
 Text(
 summary.description,
 style: TextStyle(fontSize: 12, color: summary.descriptionColor),
 ),
 ],
 ),
 );
 }
}

class _CostStateSelector extends StatelessWidget {
 const _CostStateSelector({
 required this.activeFilter,
 required this.onChanged,
 });

 final _CostStateFilter activeFilter;
 final ValueChanged<_CostStateFilter> onChanged;

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: _CostStateFilter.values.map((filter) {
 final isActive = filter == activeFilter;
 return InkWell(
 onTap: () => onChanged(filter),
 borderRadius: BorderRadius.circular(999),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: isActive ? const Color(0xFF0F172A) : Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: isActive
 ? const Color(0xFF0F172A)
 : const Color(0xFFE5E7EB),
 ),
 ),
 child: Text(
 _costStateFilterLabel(filter),
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: isActive ? Colors.white : const Color(0xFF334155),
 ),
 ),
 ),
 );
 }).toList(),
 );
 }
}

class _CostStateBadge extends StatelessWidget {
 const _CostStateBadge({required this.costState});

 final String costState;

 @override
 Widget build(BuildContext context) {
 final tone = _costStateTone(costState);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: tone.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: tone.withValues(alpha: 0.2)),
 ),
 child: Text(
 _costStateLabel(costState),
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: tone,
 ),
 ),
 );
 }
}

class _DesignMaturityBadge extends StatelessWidget {
 const _DesignMaturityBadge({required this.designMaturity});

 final String designMaturity;

 @override
 Widget build(BuildContext context) {
 if (designMaturity.isEmpty) return const SizedBox.shrink();
 final color = _designMaturityColor(designMaturity);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withValues(alpha: 0.2)),
 ),
 child: Text(
 _designMaturityLabel(designMaturity),
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }
}

class _SupersededToggle extends StatelessWidget {
 const _SupersededToggle({
 required this.enabled,
 required this.onChanged,
 });

 final bool enabled;
 final ValueChanged<bool> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Include Superseded Lines',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Show raw imported lines that were collapsed by reconciliation.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 Switch(
 value: enabled,
 onChanged: onChanged,
 ),
 ],
 ),
 );
 }
}

class _CostEstimateTopBar extends StatelessWidget {
 const _CostEstimateTopBar({
 required this.baselineConfirmedAt,
 required this.isImporting,
 required this.isValidating,
 required this.onRefreshBaseline,
 required this.onImportSources,
 required this.onAiGenerate,
 required this.onValidate,
 required this.onSetBaseline,
 required this.onReconcile,
 });

 final DateTime? baselineConfirmedAt;
 final bool isImporting;
 final bool isValidating;
 final VoidCallback onRefreshBaseline;
 final VoidCallback onImportSources;
 final VoidCallback onAiGenerate;
 final VoidCallback onValidate;
 final VoidCallback onSetBaseline;
 final VoidCallback onReconcile;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Cost Workspace Controls',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 if (baselineConfirmedAt != null)
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFECFDF5),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 'Baseline ${_formatShortDate(baselineConfirmedAt!)}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF059669),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _OutlinedActionButton(
 label: 'Refresh Baseline',
 icon: Icons.refresh,
 onPressed: onRefreshBaseline,
 ),
 _FilledActionButton(
 label: isImporting ? 'Importing...' : 'Import Sources',
 icon: isImporting ? Icons.sync : Icons.download_outlined,
 onPressed: isImporting ? () {} : onImportSources,
 ),
 _OutlinedActionButton(
 label: 'AI Generate',
 icon: Icons.auto_awesome,
 onPressed: onAiGenerate,
 ),
 _OutlinedActionButton(
 label: isValidating ? 'Validating...' : 'Validate',
 icon: Icons.fact_check_outlined,
 onPressed: isValidating ? () {} : onValidate,
 ),
 _OutlinedActionButton(
 label: 'Set Baseline',
 icon: Icons.lock_outline,
 onPressed: onSetBaseline,
 ),
 _OutlinedActionButton(
 label: 'Reconcile Totals',
 icon: Icons.balance_outlined,
 onPressed: onReconcile,
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _WorkspaceTabs extends StatelessWidget {
 const _WorkspaceTabs({
 required this.activeTab,
 required this.onChanged,
 });

 final _CostWorkspaceTab activeTab;
 final ValueChanged<_CostWorkspaceTab> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _CostWorkspaceTab.values.map((tab) {
 final isActive = tab == activeTab;
 return GestureDetector(
 onTap: () => onChanged(tab),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: isActive
 ? const Color(0xFF0F172A)
 : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Text(
 tab.label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: isActive ? Colors.white : const Color(0xFF475569),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }
}

class _OverviewRollupCard extends StatelessWidget {
 const _OverviewRollupCard({required this.rows});

 final List<_OverviewRow> rows;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Cost Rollup',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 14),
 ...rows.map((row) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Expanded(
 child: Text(
 row.label,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF475569),
 ),
 ),
 ),
 Text(
 formatCurrency(row.value),
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }
}

class _CoverageSummaryCard extends StatelessWidget {
 const _CoverageSummaryCard({
 required this.sourceSummaries,
 required this.validationSummary,
 required this.reconciliationReport,
 });

 final List<_SourceSummary> sourceSummaries;
 final _ValidationSummary validationSummary;
 final _ReconciliationReport reconciliationReport;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Coverage & Validation',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 14),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: sourceSummaries.take(5).map((source) {
 return _StatusChip(
 label: source.title,
 status: source.status,
 );
 }).toList(),
 ),
 const SizedBox(height: 16),
 if (reconciliationReport.supersededCount > 0) ...[
 Text(
 '${reconciliationReport.supersededCount} imported line(s) are currently superseded by stronger cost states.',
 style: const TextStyle(fontSize: 13, color: Color(0xFF1D4ED8)),
 ),
 const SizedBox(height: 12),
 ],
 if (validationSummary.issues.isEmpty)
 const Text(
 'No validation issues detected in structured sources.',
 style: TextStyle(fontSize: 13, color: Color(0xFF059669)),
 )
 else
 ...validationSummary.issues.map(
 (issue) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 3),
 child: Icon(Icons.warning_amber_rounded,
 size: 16, color: Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 issue,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _BoeSummaryCard extends StatelessWidget {
 const _BoeSummaryCard({required this.items});

 final List<CostEstimateItem> items;

 @override
 Widget build(BuildContext context) {
 final methods = <String, int>{};
 final rateSources = <String, int>{};
 final maturityLevels = <String, int>{};
 int totalItems = items.length;
 int documentedScope = 0;
 int withEstimatingBasis = 0;

 for (final item in items) {
 methods[item.estimatingMethod] = (methods[item.estimatingMethod] ?? 0) + 1;
 if (item.rateSource.isNotEmpty) {
 rateSources[item.rateSource] = (rateSources[item.rateSource] ?? 0) + 1;
 }
 if (item.designMaturity.isNotEmpty) {
 maturityLevels[item.designMaturity] = (maturityLevels[item.designMaturity] ?? 0) + 1;
 }
 if (item.scopeIncluded.isNotEmpty || item.scopeExcluded.isNotEmpty) {
 documentedScope++;
 }
 if (item.estimatingBasis.isNotEmpty) {
 withEstimatingBasis++;
 }
 }

 final missingBasis = totalItems - withEstimatingBasis;
 final missingScope = totalItems - documentedScope;

 final methodLabels = <String, String>{
 'bottoms_up': 'Bottom-Up',
 'top_down': 'Top-Down',
 'unit_rate': 'Unit Rate',
 'analogous': 'Analogy',
 'quote_based': 'Quote-Based',
 'actual': 'Actual',
 'allowance_release': 'Allowance',
 'manual': 'Manual',
 };

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Basis of Estimate Summary',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '$totalItems items',
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _boeColumn(
 'Estimating Methods',
 methods.entries
 .where((e) => e.value > 0)
 .map((e) => _boeRow(
 methodLabels[e.key] ?? e.key,
 e.value,
 totalItems,
 ))
 .toList(),
 ),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _boeColumn(
 'Design Maturity',
 maturityLevels.entries
 .where((e) => e.value > 0)
 .map((e) => _boeRow(
 _designMaturityLabel(e.key),
 e.value,
 totalItems,
 ))
 .toList(),
 ),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _boeColumn(
 'Rate Sources',
 rateSources.entries
 .where((e) => e.value > 0)
 .map((e) => _boeRow(
 _rateSourceLabel(e.key),
 e.value,
 totalItems,
 ))
 .toList(),
 emptyMessage: 'No rate sources documented',
 ),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _boeColumn(
 'Documentation Gap',
 [
 _boeGapRow('Estimating Basis', withEstimatingBasis, totalItems, missingBasis),
 _boeGapRow('Scope In/Excluded', documentedScope, totalItems, missingScope),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _boeColumn(String title, List<Widget> rows, {String? emptyMessage}) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
 ),
 const SizedBox(height: 8),
 if (rows.isEmpty && emptyMessage != null)
 Padding(
 padding: const EdgeInsets.only(top: 4),
 child: Text(
 emptyMessage,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
 ),
 )
 else
 ...rows,
 ],
 );
 }

 Widget _boeRow(String label, int count, int total) {
 final pct = total > 0 ? count / total : 0.0;
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
 Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 ],
 ),
 const SizedBox(height: 2),
 ClipRRect(
 borderRadius: BorderRadius.circular(2),
 child: LinearProgressIndicator(
 value: pct,
 minHeight: 4,
 backgroundColor: Colors.white,
 valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
 ),
 ),
 ],
 ),
 );
 }

 Widget _boeGapRow(String label, int documented, int total, int missing) {
 final pct = total > 0 ? documented / total : 0.0;
 final color = missing == 0 ? const Color(0xFF059669) : const Color(0xFFC2410C);
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
 Text('$documented/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 ],
 ),
 const SizedBox(height: 2),
 ClipRRect(
 borderRadius: BorderRadius.circular(2),
 child: LinearProgressIndicator(
 value: pct,
 minHeight: 4,
 backgroundColor: Colors.white,
 valueColor: AlwaysStoppedAnimation<Color>(color),
 ),
 ),
 ],
 ),
 );
 }

 String _rateSourceLabel(String key) {
 switch (key) {
 case 'vendor_quote': return 'Vendor Quote';
 case 'historical': return 'Historical';
 case 'published_index': return 'Published Index';
 case 'benchmark': return 'Benchmark';
 case 'expert_judgment': return 'Expert Judgment';
 default: return key;
 }
 }
}

class _CostProfileCard extends StatelessWidget {
 const _CostProfileCard({
 required this.items,
 required this.workPackages,
 });

 final List<CostEstimateItem> items;
 final List<WorkPackage> workPackages;

 @override
 Widget build(BuildContext context) {
 final totalCost = items.fold<double>(0, (s, item) => s + item.amount);
 final avgCostPerItem = items.isNotEmpty ? totalCost / items.length : 0.0;

 final byPhase = <String, double>{};
 final byPhaseCount = <String, int>{};
 for (final item in items) {
 final phase = item.phase.isEmpty ? 'unassigned' : item.phase;
 byPhase[phase] = (byPhase[phase] ?? 0) + item.amount;
 byPhaseCount[phase] = (byPhaseCount[phase] ?? 0) + 1;
 }

 final wpCount = workPackages.length;
 final wpTotalBudget = workPackages.fold<double>(0, (s, wp) => s + wp.budgetedCost);
 final wpAvgBudget = wpCount > 0 ? wpTotalBudget / wpCount : 0.0;

 final agileWps = workPackages.where((wp) => wp.type == 'agile').toList();
 final agileCost = agileWps.fold<double>(0, (s, wp) => s + wp.budgetedCost);
 final agileCount = agileWps.length;

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Cost Profile & Benchmarks',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _profileColumn('Summary', [
 _profileRow('Total Items', '${items.length}'),
 _profileRow('Total Cost', formatCurrency(totalCost)),
 _profileRow('Avg / Item', formatCurrency(avgCostPerItem)),
 ]),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _profileColumn('Work Packages', [
 _profileRow('Total Packages', '$wpCount'),
 _profileRow('Total Budget', formatCurrency(wpTotalBudget)),
 _profileRow('Avg / Package', formatCurrency(wpAvgBudget)),
 ]),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _profileColumn('By Phase', byPhase.entries.map((e) =>
 _profileRow('${e.key} (${byPhaseCount[e.key] ?? 0})', formatCurrency(e.value))
 ).toList()),
 ),
 const SizedBox(width: 24),
 Expanded(
 child: _profileColumn('Agile Delivery', [
 if (agileCount > 0) ...[
 _profileRow('Agile Packages', '$agileCount'),
 _profileRow('Agile Budget', formatCurrency(agileCost)),
 _profileRow('% of Total Budget', wpTotalBudget > 0 ? '${(agileCost / wpTotalBudget * 100).toStringAsFixed(1)}%' : '0%'),
 ] else
 _profileRow('Status', 'No Agile packages'),
 ]),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _profileColumn(String title, List<Widget> rows) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
 ),
 const SizedBox(height: 8),
 ...rows,
 ],
 );
 }

 Widget _profileRow(String label, String value) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
 const SizedBox(width: 8),
 Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 ],
 ),
 );
 }
}

class _ContractStrategyCard extends StatelessWidget {
 const _ContractStrategyCard({
 required this.contracts,
 required this.costItems,
 });

 final List<ContractModel> contracts;
 final List<CostEstimateItem> costItems;

 @override
 Widget build(BuildContext context) {
 final byStatus = <ContractStatus, double>{};
 final byStatusCount = <ContractStatus, int>{};
 for (final c in contracts) {
 byStatus[c.status] = (byStatus[c.status] ?? 0) + c.estimatedCost;
 byStatusCount[c.status] = (byStatusCount[c.status] ?? 0) + 1;
 }

 final contractIds = costItems
 .where((item) => item.contractId.isNotEmpty)
 .map((item) => item.contractId)
 .toSet();
 final linkedCost = costItems
 .where((item) => item.contractId.isNotEmpty)
 .fold<double>(0, (s, item) => s + item.amount);

 final totalContractValue = contracts.fold<double>(0, (s, c) => s + c.estimatedCost);
 final totalCostValue = costItems.fold<double>(0, (s, item) => s + item.amount);
 final pctLinkedToContracts = totalCostValue > 0 ? (linkedCost / totalCostValue * 100) : 0.0;

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Contract Strategy',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '${contracts.length} contracts',
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 _strategyStat('Total Contract Value', formatCurrency(totalContractValue), const Color(0xFF1E293B)),
 const SizedBox(width: 16),
 _strategyStat('Linked Cost Items', '${contractIds.length} linked', const Color(0xFF2563EB)),
 const SizedBox(width: 16),
 _strategyStat('Coverage', '${pctLinkedToContracts.toStringAsFixed(1)}% of total', pctLinkedToContracts > 50 ? const Color(0xFF059669) : const Color(0xFFC2410C)),
 ],
 ),
 const SizedBox(height: 16),
 const Text(
 'By Status',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
 ),
 const SizedBox(height: 8),
 ...ContractStatus.values.where((s) => (byStatusCount[s] ?? 0) > 0).map((status) {
 final value = byStatus[status] ?? 0;
 final count = byStatusCount[status] ?? 0;
 final pct = totalContractValue > 0 ? value / totalContractValue : 0.0;
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 children: [
 SizedBox(
 width: 100,
 child: Text(
 _contractStatusLabel(status),
 style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(2),
 child: LinearProgressIndicator(
 value: pct,
 minHeight: 6,
 backgroundColor: Colors.white,
 valueColor: AlwaysStoppedAnimation<Color>(_contractStatusColor(status)),
 ),
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 width: 80,
 child: Text(
 formatCurrency(value),
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
 textAlign: TextAlign.right,
 ),
 ),
 const SizedBox(width: 4),
 Text(
 '($count)',
 style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 );
 }),
 if (contracts.isEmpty)
 const Padding(
 padding: EdgeInsets.only(top: 4),
 child: Text(
 'No contracts added yet. Add contracts in the procurement screen.',
 style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
 ),
 ),
 ],
 ),
 );
 }

 Widget _strategyStat(String label, String value, Color color) {
 return Expanded(
 child: Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.06),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
 const SizedBox(height: 4),
 Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
 ],
 ),
 ),
 );
 }

 String _contractStatusLabel(ContractStatus status) {
 switch (status) {
 case ContractStatus.draft: return 'Draft';
 case ContractStatus.under_review: return 'Under Review';
 case ContractStatus.approved: return 'Approved';
 case ContractStatus.executed: return 'Executed';
 case ContractStatus.expired: return 'Expired';
 case ContractStatus.terminated: return 'Terminated';
 }
 }

 Color _contractStatusColor(ContractStatus status) {
 switch (status) {
 case ContractStatus.draft: return const Color(0xFF94A3B8);
 case ContractStatus.under_review: return const Color(0xFFC2410C);
 case ContractStatus.approved: return const Color(0xFF2563EB);
 case ContractStatus.executed: return const Color(0xFF059669);
 case ContractStatus.expired: return const Color(0xFF64748B);
 case ContractStatus.terminated: return const Color(0xFFDC2626);
 }
 }
}

class _SourceImportsTab extends StatelessWidget {
 const _SourceImportsTab({
 required this.sourceSummaries,
 required this.reconciliationReport,
 required this.onImportAll,
 required this.onValidate,
 });

 final List<_SourceSummary> sourceSummaries;
 final _ReconciliationReport reconciliationReport;
 final VoidCallback onImportAll;
 final VoidCallback onValidate;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Source Imports',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Track which project cost sources are already represented in estimate lines.',
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 _OutlinedActionButton(
 label: 'Validate',
 icon: Icons.fact_check_outlined,
 onPressed: onValidate,
 ),
 const SizedBox(width: 12),
 _FilledActionButton(
 label: 'Import Available Sources',
 icon: Icons.download_outlined,
 onPressed: onImportAll,
 ),
 ],
 ),
 const SizedBox(height: 18),
 _ReconciliationReportCard(report: reconciliationReport),
 const SizedBox(height: 18),
 ...sourceSummaries.map(
 (summary) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _SourceSummaryCard(summary: summary),
 ),
 ),
 ],
 );
 }
}

class _SourceSummaryCard extends StatelessWidget {
 const _SourceSummaryCard({required this.summary});

 final _SourceSummary summary;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 summary.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 summary.subtitle,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 const SizedBox(height: 10),
 Text(
 'Source total ${formatCurrency(summary.total)}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 _StatusChip(label: summary.status.label, status: summary.status),
 const SizedBox(height: 10),
 Text(
 'Imported ${summary.importedCount}/${summary.sourceCount}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ReconciliationReportCard extends StatelessWidget {
 const _ReconciliationReportCard({required this.report});

 final _ReconciliationReport report;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Reconciliation Report',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 report.supersededCount == 0
 ? 'No imported lines are currently being collapsed by reconciliation.'
 : '${report.activeImported} active of ${report.totalImported} imported lines. ${report.supersededCount} line(s) were superseded.',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 if (report.entries.isNotEmpty) ...[
 const SizedBox(height: 14),
 ...report.entries.take(8).map(
 (entry) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _ReconciliationEntryTile(entry: entry),
 ),
 ),
 if (report.entries.length > 8)
 Text(
 '${report.entries.length - 8} more superseded line(s) not shown.',
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF94A3B8),
 ),
 ),
 ],
 ],
 ),
 );
 }
}

class _ReconciliationEntryTile extends StatelessWidget {
 const _ReconciliationEntryTile({required this.entry});

 final _ReconciliationEntry entry;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 entry.superseded.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 _CostStateBadge(costState: entry.superseded.costState),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'Superseded by ${entry.retained.title} (${_costStateLabel(entry.retained.costState)})',
 style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
 ),
 const SizedBox(height: 4),
 Text(
 entry.reason,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 4),
 Text(
 'Scope key: ${entry.key}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 );
 }
}

class _SourceDetailList extends StatelessWidget {
 const _SourceDetailList({
 required this.title,
 required this.subtitle,
 required this.rows,
 });

 final String title;
 final String subtitle;
 final List<_SourceDetailRow> rows;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
 style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 18),
 ...rows.map((row) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 row.title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 row.subtitle,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Text(
 formatCurrency(row.amount),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }
}

class _ContingencyRiskPanel extends StatelessWidget {
 const _ContingencyRiskPanel({
 required this.projectData,
 required this.forecastItems,
 required this.allItems,
 required this.rows,
 });

 final ProjectDataModel projectData;
 final List<CostEstimateItem> forecastItems;
 final List<CostEstimateItem> allItems;
 final List<_SourceDetailRow> rows;

 @override
 Widget build(BuildContext context) {
 final pertItems = forecastItems
 .where((item) => item.rangeLow > 0 && item.rangeHigh > 0)
 .toList();
 final pertBaseTotal = pertItems.fold<double>(
 0, (total, item) => total + item.amount);
 final pertMeanTotal = pertItems.fold<double>(
 0, (total, item) => total + item.pertMean);
 final pertExposureTotal = pertItems.fold<double>(
 0, (total, item) => total + item.pertExposure);
 final reserve = projectData.managementReserve;
 final forecastTotal = forecastItems.fold<double>(
 0, (total, item) => total + item.amount);

 double pertVarianceSum = 0;
 for (final item in pertItems) {
 final range = item.rangeHigh - item.rangeLow;
 pertVarianceSum += (range * range) / 36;
 }
 final pertStdDev = pertVarianceSum > 0 ? math.sqrt(pertVarianceSum) : 0.0;
 final p80 = pertMeanTotal + 0.84 * pertStdDev;
 final p90 = pertMeanTotal + 1.28 * pertStdDev;

 double engRisk = 0, procRisk = 0, execRisk = 0;
 int engCount = 0, procCount = 0, execCount = 0;
 for (final item in allItems) {
 if (item.phase == 'design' ||
 item.source.contains('design') ||
 item.source.contains('technology')) {
 engRisk += item.amount;
 engCount++;
 } else if (item.source.contains('procurement') ||
 item.source.contains('purchase') ||
 item.source.contains('contract') ||
 item.source.contains('vendor')) {
 procRisk += item.amount;
 procCount++;
 } else if (item.phase == 'execution' ||
 item.source.contains('work_package') ||
 item.source == 'initiation_cost_rows') {
 execRisk += item.amount;
 execCount++;
 }
 }

 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contingency & Risk',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Allowance, management reserve, and PERT risk exposure.',
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 20),
 if (reserve > 0) ...[
 _ContingencyRow(
 label: 'Management Reserve',
 amount: reserve,
 color: const Color(0xFF7C3AED),
 ),
 const Divider(height: 24),
 ],
 if (pertItems.isNotEmpty) ...[
 const Text(
 'PERT Risk Analysis',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 _ContingencyRow(
 label: 'Items with PERT ranges',
 amount: pertItems.length.toDouble(),
 color: const Color(0xFF475569),
 isCount: true,
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'Base estimate (P50)',
 amount: pertBaseTotal,
 color: const Color(0xFFB45309),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'PERT mean estimate',
 amount: pertMeanTotal,
 color: const Color(0xFF2563EB),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'PERT exposure (mean - base)',
 amount: pertExposureTotal,
 color: pertExposureTotal > 0
 ? const Color(0xFFDC2626)
 : const Color(0xFF059669),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'Adjusted total (forecast + exposure)',
 amount: forecastTotal + pertExposureTotal,
 color: const Color(0xFF111827),
 ),
 const SizedBox(height: 8),
 if (pertStdDev > 0) ...[
 const Divider(height: 16),
 const Text(
 'Confidence Levels (Normal Approximation)',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 _ContingencyRow(
 label: 'P80 (80% confidence)',
 amount: p80,
 color: const Color(0xFF7C3AED),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'P90 (90% confidence)',
 amount: p90,
 color: const Color(0xFFDC2626),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'P80 exposure vs P50',
 amount: p80 - pertBaseTotal,
 color: const Color(0xFFC2410C),
 ),
 const SizedBox(height: 4),
 _ContingencyRow(
 label: 'Std Dev',
 amount: pertStdDev,
 color: const Color(0xFF64748B),
 ),
 ],
 const SizedBox(height: 16),
 const Divider(height: 24),
 ],
 const Divider(height: 16),
 const Text(
 'Risk Exposure by Domain',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 _riskDomainTile(
 'Engineering / Design',
 engCount,
 engRisk,
 forecastTotal,
 Icons.design_services_outlined,
 'Design changes, tech uncertainty, rework',
 const Color(0xFF2563EB),
 ),
 const SizedBox(height: 6),
 _riskDomainTile(
 'Procurement / Supply Chain',
 procCount,
 procRisk,
 forecastTotal,
 Icons.inventory_2_outlined,
 'Price volatility, delays, logistics',
 const Color(0xFFC2410C),
 ),
 const SizedBox(height: 6),
 _riskDomainTile(
 'Execution / Construction',
 execCount,
 execRisk,
 forecastTotal,
 Icons.construction_outlined,
 'Productivity, weather, site access',
 const Color(0xFF059669),
 ),
 const SizedBox(height: 16),
 const Text(
 'Contingency Allowances',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 ...rows.map((row) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 row.title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 row.subtitle,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Text(
 formatCurrency(row.amount),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }

 Widget _riskDomainTile(String label, int count, double total, double forecastTotal, IconData icon, String description, Color color) {
 final pct = forecastTotal > 0 ? (total / forecastTotal * 100) : 0.0;
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.06),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 children: [
 Icon(icon, size: 18, color: color),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
 ),
 Text(
 description,
 style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 formatCurrency(total),
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
 ),
 Text(
 '$count items (${pct.toStringAsFixed(1)}%)',
 style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ContingencyRow extends StatelessWidget {
 const _ContingencyRow({
 required this.label,
 required this.amount,
 required this.color,
 this.isCount = false,
 });

 final String label;
 final double amount;
 final Color color;
 final bool isCount;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Expanded(
 child: Text(
 label,
 style: TextStyle(
 fontSize: 13,
 color: color,
 ),
 ),
 ),
 Text(
 isCount ? amount.toInt().toString() : formatCurrency(amount),
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ],
 );
 }
}

class _CbsTreeNode {
 const _CbsTreeNode({
 required this.label,
 required this.planned,
 this.committed = 0,
 this.actual = 0,
 this.children = const [],
 this.depth = 0,
 this.designMaturity = '',
 });

 final String label;
 final double planned;
 final double committed;
 final double actual;
 final List<_CbsTreeNode> children;
 final int depth;
 final String designMaturity;

 double get total => planned + committed + actual;
}

class _CbsTreeWorkspace extends StatelessWidget {
 const _CbsTreeWorkspace({
 required this.projectData,
 required this.forecastItems,
 required this.committedItems,
 required this.actualItems,
 });

 final ProjectDataModel projectData;
 final List<CostEstimateItem> forecastItems;
 final List<CostEstimateItem> committedItems;
 final List<CostEstimateItem> actualItems;

 @override
 Widget build(BuildContext context) {
 final tree = _buildTree();
 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Cost Breakdown Structure (CBS)',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Row(
 children: [
 _legendDot(const Color(0xFFB45309), 'Forecast'),
 const SizedBox(width: 16),
 _legendDot(const Color(0xFF1D4ED8), 'Committed'),
 const SizedBox(width: 16),
 _legendDot(const Color(0xFF047857), 'Actual'),
 const Spacer(),
 Text(
 'Total: ${formatCurrency(tree.total)}',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 if (tree.children.isEmpty)
 const Center(
 child: Padding(
 padding: EdgeInsets.symmetric(vertical: 40),
 child: Text(
 'No WBS items available yet.\n'
 'Create a Work Breakdown Structure to see cost hierarchy.',
 textAlign: TextAlign.center,
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 ),
 )
 else
 ...tree.children.map((node) => _CbsTreeTile(node: node)),
 ],
 ),
 );
 }

 Widget _legendDot(Color color, String label) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
 const SizedBox(width: 6),
 Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
 ],
 );
 }

 _CbsTreeNode _buildTree() {
 final wbsItems = projectData.wbsTree;
 final itemsByWbs = <String, List<CostEstimateItem>>{};
 final allItems = [
 ...forecastItems.map((e) => (item: e, state: 'forecast')),
 ...committedItems.map((e) => (item: e, state: 'committed')),
 ...actualItems.map((e) => (item: e, state: 'actual')),
 ];

 for (final entry in allItems) {
 final wbsId = entry.item.wbsItemId.trim();
 if (wbsId.isNotEmpty) {
 itemsByWbs.putIfAbsent(wbsId, () => []).add(entry.item);
 }
 }

 final unlinkedItems = allItems
 .where((e) => e.item.wbsItemId.trim().isEmpty)
 .map((e) => e.item)
 .toList();

 final children = <_CbsTreeNode>[];
 for (final wbs in wbsItems) {
 final node = _buildWbsNode(wbs, itemsByWbs, 0);
 if (node != null) children.add(node);
 }

 if (unlinkedItems.isNotEmpty) {
 double plan = 0, comm = 0, act = 0;
 for (final item in unlinkedItems) {
 switch (item.costState) {
 case 'committed': comm += item.amount;
 case 'actual': act += item.amount;
 default: plan += item.amount;
 }
 }
 children.add(_CbsTreeNode(
 label: 'Unlinked Items',
 planned: plan,
 committed: comm,
 actual: act,
 depth: 0,
 ));
 }

 double rootPlan = 0, rootComm = 0, rootAct = 0;
 for (final c in children) {
 rootPlan += c.planned;
 rootComm += c.committed;
 rootAct += c.actual;
 }
 return _CbsTreeNode(label: 'Total Project', planned: rootPlan, committed: rootComm, actual: rootAct, children: children);
 }

 _CbsTreeNode? _buildWbsNode(
 WorkItem wbs,
 Map<String, List<CostEstimateItem>> itemsByWbs,
 int depth,
 ) {
 final childNodes = <_CbsTreeNode>[];
 for (final child in wbs.children) {
 final node = _buildWbsNode(child, itemsByWbs, depth + 1);
 if (node != null) childNodes.add(node);
 }

 final directItems = itemsByWbs[wbs.id] ?? [];
 double plan = 0, comm = 0, act = 0;
 int minRank = 999;
 for (final item in directItems) {
 switch (item.costState) {
 case 'committed': comm += item.amount;
 case 'actual': act += item.amount;
 default: plan += item.amount;
 }
 if (item.designMaturity.isNotEmpty) {
 final r = _maturityRank(item.designMaturity);
 if (r > 0 && r < minRank) minRank = r;
 }
 }

 for (final child in childNodes) {
 plan += child.planned;
 comm += child.committed;
 act += child.actual;
 if (child.designMaturity.isNotEmpty) {
 final r = _maturityRank(child.designMaturity);
 if (r > 0 && r < minRank) minRank = r;
 }
 }

 if (plan == 0 && comm == 0 && act == 0 && childNodes.isEmpty) return null;

 final maturity = minRank < 999
 ? ['', '10%', '30%', '60%', '90%', 'IFC', 'AsBuilt'][minRank]
 : '';

 return _CbsTreeNode(
 label: wbs.title.trim().isEmpty ? 'Unnamed WBS Item' : wbs.title.trim(),
 planned: plan,
 committed: comm,
 actual: act,
 children: childNodes,
 depth: depth,
 designMaturity: maturity,
 );
 }
}

class _CbsTreeTile extends StatefulWidget {
 const _CbsTreeTile({required this.node});

 final _CbsTreeNode node;

 @override
 State<_CbsTreeTile> createState() => _CbsTreeTileState();
}

class _CbsTreeTileState extends State<_CbsTreeTile> {
 bool _expanded = true;

 @override
 Widget build(BuildContext context) {
 final node = widget.node;
 final hasChildren = node.children.isNotEmpty;
 final indent = node.depth * 24.0;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 InkWell(
 onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
 child: Container(
 padding: EdgeInsets.only(left: 12 + indent, right: 12),
 height: 44,
 decoration: BoxDecoration(
 border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))),
 ),
 child: Row(
 children: [
 if (hasChildren)
 Icon(
 _expanded ? Icons.expand_more : Icons.chevron_right,
 size: 18,
 color: const Color(0xFF64748B),
 )
 else
 const SizedBox(width: 18),
 const SizedBox(width: 6),
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: hasChildren ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 node.label,
 style: TextStyle(
 fontSize: 13,
 fontWeight: hasChildren ? FontWeight.w700 : FontWeight.w500,
 color: const Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (node.designMaturity.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(right: 8),
 child: _DesignMaturityBadge(designMaturity: node.designMaturity),
 ),
 SizedBox(width: 100, child: Text(formatCurrency(node.planned), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)), textAlign: TextAlign.right)),
 SizedBox(width: 100, child: Text(node.committed > 0 ? formatCurrency(node.committed) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: node.committed > 0 ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)), textAlign: TextAlign.right)),
 SizedBox(width: 100, child: Text(node.actual > 0 ? formatCurrency(node.actual) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: node.actual > 0 ? const Color(0xFF047857) : const Color(0xFFCBD5E1)), textAlign: TextAlign.right)),
 ],
 ),
 ),
 ),
 if (_expanded && hasChildren)
 ...node.children.map((child) => _CbsTreeTile(node: child)),
 ],
 );
 }
}

class _CostVsScheduleWorkspace extends StatelessWidget {
 const _CostVsScheduleWorkspace({required this.projectData});

 final ProjectDataModel projectData;

 static const _monthNames = [
 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
 ];

 DateTime? _tryParseDate(String? raw) {
 if (raw == null || raw.trim().isEmpty) return null;
 return DateTime.tryParse(raw.trim());
 }

 @override
 Widget build(BuildContext context) {
 final now = DateTime.now();
 final workPackages = projectData.workPackages;

 final monthlyPlanned = <String, double>{};
 final monthlyActual = <String, double>{};
 DateTime? earliestStart;
 DateTime? latestEnd;

 for (final wp in workPackages) {
 final start = _tryParseDate(wp.plannedStart) ?? _tryParseDate(wp.actualStart);
 final end = _tryParseDate(wp.plannedEnd) ?? _tryParseDate(wp.actualEnd);
 if (start == null || end == null || end.isBefore(start)) continue;

 if (earliestStart == null || start.isBefore(earliestStart)) earliestStart = start;
 if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;

 final months = _monthSpan(start, end);
 if (months <= 0) continue;
 final monthlyPlannedAmount = wp.budgetedCost / months;
 final monthlyActualAmount = wp.actualCost > 0 ? wp.actualCost / months : 0.0;

 var cursor = DateTime(start.year, start.month, 1);
 while (!cursor.isAfter(end)) {
 final key = _monthKey(cursor);
 monthlyPlanned.update(key, (v) => v + monthlyPlannedAmount, ifAbsent: () => monthlyPlannedAmount);
 if (monthlyActualAmount > 0) {
 monthlyActual.update(key, (v) => v + monthlyActualAmount, ifAbsent: () => monthlyActualAmount);
 }
 cursor = DateTime(cursor.year, cursor.month + 1, 1);
 }
 }

 final plannedData = <SCurveDataPoint>[];
 final actualData = <SCurveDataPoint>[];
 final sortedMonths = monthlyPlanned.keys.toList()..sort();
 double plannedCumulative = 0;
 double actualCumulative = 0;

 for (final key in sortedMonths) {
 final parts = key.split('-');
 final month = int.parse(parts[1]);
 final year = int.parse(parts[0]);
 plannedCumulative += monthlyPlanned[key] ?? 0;
 actualCumulative += monthlyActual[key] ?? 0;
 final date = DateTime(year, month, 1);
 plannedData.add(SCurveDataPoint(date: date, cumulativeCost: plannedCumulative));
 actualData.add(SCurveDataPoint(date: date, cumulativeCost: actualCumulative));
 }

 final chartStart = earliestStart ?? now;
 final chartEnd = latestEnd ?? now;
 final linkedCount = projectData.costEstimateItems.where((item) {
 return item.workPackageId.trim().isNotEmpty ||
 item.scheduleActivityId.trim().isNotEmpty;
 }).length;

 final double bac = workPackages.fold<double>(0, (s, wp) => s + wp.budgetedCost);
 final double totalActual = workPackages.fold<double>(0, (s, wp) => s + wp.actualCost);

 final String currentMonthKey = _monthKey(now);
 double pvAtNow = 0;
 for (final key in sortedMonths) {
 if (key.compareTo(currentMonthKey) <= 0) {
 pvAtNow += monthlyPlanned[key] ?? 0;
 }
 }

 double ev = 0;
 for (final wp in workPackages) {
 if (wp.status == 'complete') {
 ev += wp.budgetedCost;
 } else if (wp.status == 'in_progress') {
 ev += wp.budgetedCost > 0
 ? (wp.actualCost / wp.budgetedCost).clamp(0, 1) * wp.budgetedCost
 : 0;
 }
 }

 final double ac = totalActual;
 final double cv = ev - ac;
 final double sv = ev - pvAtNow;

 final forecast = ForecastService.calculateEac(
 bac: bac,
 ev: ev,
 ac: ac,
 pv: pvAtNow,
 );
 final double cpi = ac > 0 ? ev / ac : 1.0;
 final double spi = pvAtNow > 0 ? ev / pvAtNow : 1.0;
 final double eac = forecast.eac;

 final bool hasData = bac > 0 || totalActual > 0;

 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Cost vs Schedule',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (hasData) ...[
 const SizedBox(height: 16),
 _EarnedValueMetricsRow(
 bac: bac,
 pv: pvAtNow,
 ev: ev,
 ac: ac,
 cpi: cpi,
 spi: spi,
 cv: cv,
 sv: sv,
 eac: eac,
 etc: forecast.etc,
 tcpii: forecast.tcpii,
 ),
 ],
 const SizedBox(height: 16),
 SizedBox(
 height: 320,
 child: SCurveChart(
 plannedData: plannedData,
 actualData: actualData,
 startDate: chartStart,
 endDate: chartEnd,
 height: 320,
 ),
 ),
 const SizedBox(height: 24),
 const Text(
 'Monthly Cash Flow',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 10),
 if (sortedMonths.isEmpty)
 const Text(
 'No scheduled work packages with dates for cash flow projection.',
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 )
 else
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: DataTable(
 columnSpacing: 24,
 headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2937)),
 columns: const [
 DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
 DataColumn(label: Text('Planned', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
 DataColumn(label: Text('Actual', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
 DataColumn(label: Text('Variance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
 ],
 rows: sortedMonths.map((key) {
 final parts = key.split('-');
 final month = int.parse(parts[1]);
 final year = int.parse(parts[0]);
 final label = '${_monthNames[month - 1]} $year';
 final planned = monthlyPlanned[key] ?? 0;
 final actual = monthlyActual[key] ?? 0;
 final variance = planned - actual;
 return DataRow(cells: [
 DataCell(Text(label, style: const TextStyle(fontSize: 12))),
 DataCell(Text(formatCurrency(planned), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
 DataCell(Text(actual > 0 ? formatCurrency(actual) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actual > 0 ? const Color(0xFF047857) : const Color(0xFFCBD5E1)))),
 DataCell(Text(variance != 0 ? formatCurrency(variance) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: variance > 0 ? const Color(0xFF059669) : variance < 0 ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)))),
 ]);
 }).toList(),
 ),
 ),
 const SizedBox(height: 24),
 const Text(
 'Work Package Budgets',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 '$linkedCount estimate line(s) linked to work packages or schedule activities.',
 style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 12),
 if (workPackages.isEmpty)
 const Text(
 'No work packages available yet for cost/schedule mapping.',
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 )
 else
 ...workPackages.map((wp) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 wp.title.trim().isEmpty ? 'Untitled Work Package' : wp.title.trim(),
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 if (wp.plannedStart != null || wp.plannedEnd != null)
 Text(
 '${wp.plannedStart ?? '?'} \u2192 ${wp.plannedEnd ?? '?'}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),
 Text(
 formatCurrency(wp.budgetedCost),
 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }

 int _monthSpan(DateTime start, DateTime end) {
 return (end.year - start.year) * 12 + (end.month - start.month) + 1;
 }

 String _monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

class _EarnedValueMetricsRow extends StatelessWidget {
 const _EarnedValueMetricsRow({
 required this.bac,
 required this.pv,
 required this.ev,
 required this.ac,
 required this.cpi,
 required this.spi,
 required this.cv,
 required this.sv,
 required this.eac,
 required this.etc,
 required this.tcpii,
 });

 final double bac;
 final double pv;
 final double ev;
 final double ac;
 final double cpi;
 final double spi;
 final double cv;
 final double sv;
 final double eac;
 final double etc;
 final double tcpii;

 @override
 Widget build(BuildContext context) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 _evmMetric('BAC', formatCurrency(bac), const Color(0xFF1E293B)),
 _evmMetric('PV', formatCurrency(pv), const Color(0xFF2563EB)),
 _evmMetric('EV', formatCurrency(ev), const Color(0xFF059669)),
 _evmMetric('AC', formatCurrency(ac), const Color(0xFFB45309)),
 _evmMetric('CPI', cpi.toStringAsFixed(2), _evmColor(cpi, 1.0)),
 _evmMetric('SPI', spi.toStringAsFixed(2), _evmColor(spi, 1.0)),
 _evmMetric('CV', formatCurrency(cv), cv >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
 _evmMetric('SV', formatCurrency(sv), sv >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
 _evmMetric('EAC', formatCurrency(eac), const Color(0xFF7C3AED)),
 _evmMetric('ETC', formatCurrency(etc), const Color(0xFF9333EA)),
 _evmMetric('TCPI', tcpii.toStringAsFixed(2), const Color(0xFF0891B2)),
 ],
 ),
 );
 }

 Widget _evmMetric(String label, String value, Color color) {
 return Container(
 width: 120,
 margin: const EdgeInsets.only(right: 8),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 4),
 Text(
 value,
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
 ),
 ],
 ),
 );
 }

 Color _evmColor(double ratio, double target) {
 if (ratio >= target * 0.95 && ratio <= target * 1.05) return const Color(0xFF059669);
 if (ratio >= target * 0.85) return const Color(0xFFC2410C);
 return const Color(0xFFDC2626);
 }
}

class _StatusChip extends StatelessWidget {
 const _StatusChip({
 required this.label,
 required this.status,
 });

 final String label;
 final _SourceSummaryStatus status;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: status.backgroundColor,
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: status.foregroundColor,
 ),
 ),
 );
 }
}

class _ViewSelector extends StatelessWidget {
 const _ViewSelector(
 {required this.activeView,
 required this.definitions,
 required this.onChanged});

 final _CostView activeView;
 final Map<_CostView, _CostViewDefinition> definitions;
 final ValueChanged<_CostView> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: _CostView.values.map((view) {
 final bool isActive = view == activeView;
 final _CostViewDefinition definition = definitions[view]!;
 return Expanded(
 child: GestureDetector(
 onTap: () => onChanged(view),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 220),
 padding:
 const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
 decoration: BoxDecoration(
 color:
 isActive ? const Color(0xFFFFB200) : Colors.transparent,
 borderRadius: BorderRadius.circular(14),
 ),
 child: Column(
 children: [
 Text(
 definition.label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color:
 isActive ? Colors.white : const Color(0xFF475569),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 definition.description,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 11,
 color: isActive
 ? Colors.white.withOpacity(0.82)
 : const Color(0xFF94A3B8),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }
}

class _SectionHeader extends StatelessWidget {
 const _SectionHeader({
 required this.view,
 required this.onAiSuggestions,
 required this.onAddItem,
 });

 final _CostViewDefinition view;
 final VoidCallback onAiSuggestions;
 final VoidCallback onAddItem;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '${view.label} Categories',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 view.description,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Flexible(
 child: Align(
 alignment: isMobile ? Alignment.centerLeft : Alignment.centerRight,
 child: Wrap(
 spacing: 12,
 runSpacing: 12,
 alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
 children: [
 _OutlinedActionButton(
 label: 'AI Suggestions',
 icon: Icons.bolt_outlined,
 onPressed: onAiSuggestions,
 ),
 _OutlinedActionButton(
 label: 'Import CSV',
 icon: Icons.upload_file_outlined,
 onPressed: () async {
 final rows = await showCsvImportDialog(context, tableTitle: 'Cost Items', columns: [
 CsvColumnSpec(key: 'item', label: 'Item', sampleValue: 'Development'),
 CsvColumnSpec(key: 'cost', label: 'Cost', sampleValue: '50000'),
 ]);
 
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows?.length ?? 0} cost items imported from CSV'), backgroundColor: Colors.green));
 },
 ),
 _FilledActionButton(
 label: 'Add Cost Item',
 icon: Icons.add,
 onPressed: onAddItem,
 ),
 ],
 ),
 ),
 ),
 ],
 );
 }
}

class _OutlinedActionButton extends StatelessWidget {
 const _OutlinedActionButton(
 {required this.label, required this.icon, required this.onPressed});

 final String label;
 final IconData icon;
 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return OutlinedButton.icon(
 onPressed: onPressed,
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 foregroundColor: const Color(0xFF0F172A),
 textStyle: const TextStyle(fontWeight: FontWeight.w600),
 ),
 icon: Icon(icon, size: 18),
 label: Text(label),
 );
 }
}

class _FilledActionButton extends StatelessWidget {
 const _FilledActionButton(
 {required this.label, required this.icon, required this.onPressed});

 final String label;
 final IconData icon;
 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return FilledButton.icon(
 onPressed: onPressed,
 style: FilledButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
 backgroundColor: const Color(0xFFFFB200),
 foregroundColor: Colors.white,
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 icon: Icon(icon, size: 20),
 label: Text(label),
 );
 }
}

class _CostCategoryList extends StatelessWidget {
 const _CostCategoryList({
 required this.items,
 required this.view,
 required this.iconForItem,
 required this.onEdit,
 required this.onDelete,
 });

 final List<CostEstimateItem> items;
 final _CostView view;
 final IconData Function(CostEstimateItem, _CostView) iconForItem;
 final void Function(CostEstimateItem) onEdit;
 final void Function(CostEstimateItem) onDelete;

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return _EmptyCostState(
 viewLabel:
 view == _CostView.direct ? 'Direct Costs' : 'Indirect Costs');
 }

 return Column(
 children: items
 .map(
 (item) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _CategoryTile(
 item: item,
 icon: iconForItem(item, view),
 onEdit: () => onEdit(item),
 onDelete: () => onDelete(item),
 ),
 ),
 )
 .toList(),
 );
 }
}

class _SupersededCostList extends StatelessWidget {
 const _SupersededCostList({
 required this.items,
 required this.view,
 required this.activeFilter,
 required this.iconForItem,
 });

 final List<_ReconciliationEntry> items;
 final _CostView view;
 final _CostStateFilter activeFilter;
 final IconData Function(CostEstimateItem, _CostView) iconForItem;

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 activeFilter == _CostStateFilter.all
 ? 'No superseded lines for this cost view.'
 : 'No superseded ${_costStateFilterLabel(activeFilter).toLowerCase()} lines for this cost view.',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 );
 }

 return Column(
 children: items
 .map(
 (entry) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _SupersededCategoryTile(
 entry: entry,
 icon: iconForItem(entry.superseded, view),
 ),
 ),
 )
 .toList(),
 );
 }
}

class _PhaseContextCard extends StatelessWidget {
 const _PhaseContextCard({
 required this.projectName,
 required this.preferredSolutionTitle,
 required this.projectValueAmount,
 required this.benefitCount,
 required this.baselineTotal,
 required this.costBenefitCurrency,
 required this.onRefresh,
 });

 final String projectName;
 final String? preferredSolutionTitle;
 final String projectValueAmount;
 final int benefitCount;
 final double baselineTotal;
 final String costBenefitCurrency;
 final VoidCallback onRefresh;

 @override
 Widget build(BuildContext context) {
 final title = projectName.trim().isEmpty
 ? 'Planning Cost Estimate'
 : '$projectName Cost Estimate';
 final solutionLabel =
 preferredSolutionTitle == null || preferredSolutionTitle!.trim().isEmpty
 ? 'Preferred solution not set'
 : preferredSolutionTitle!;
 final projectValue =
 projectValueAmount.trim().isEmpty ? 'TBD' : projectValueAmount.trim();
 final baselineText =
 '${costBenefitCurrency.toUpperCase()} ${formatCurrency(baselineTotal)}';

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Build planning adjustments on top of initiation costs and financial assumptions.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 OutlinedButton.icon(
 onPressed: onRefresh,
 icon: const Icon(Icons.refresh, size: 16),
 label: const Text('Refresh from initiation'),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 16,
 runSpacing: 12,
 children: [
 _ContextBadge(label: 'Preferred solution', value: solutionLabel),
 _ContextBadge(label: 'Project value', value: projectValue),
 _ContextBadge(
 label: 'Benefits captured',
 value: benefitCount == 0 ? 'None yet' : '$benefitCount',
 ),
 _ContextBadge(
 label: 'Initiation baseline',
 value: baselineText,
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ContextBadge extends StatelessWidget {
 const _ContextBadge({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
 const SizedBox(height: 4),
 Text(
 value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 ],
 ),
 );
 }
}

class _BaselineDeltaStrip extends StatelessWidget {
 const _BaselineDeltaStrip({
 required this.total,
 required this.baseline,
 required this.adjustments,
 required this.isMobile,
 });

 final double total;
 final double baseline;
 final double adjustments;
 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 final delta = total - baseline;
 final items = [
 _DeltaMetric(
 label: 'Baseline',
 value: formatCurrency(baseline),
 tone: const Color(0xFF1D4ED8),
 ),
 _DeltaMetric(
 label: 'Adjustments',
 value: formatCurrency(adjustments),
 tone: const Color(0xFFF97316),
 ),
 _DeltaMetric(
 label: 'Current total',
 value: formatCurrency(total),
 tone: const Color(0xFF0F172A),
 helper: delta == 0 ? 'No delta' : 'Delta ${formatCurrency(delta)}',
 ),
 ];
 return isMobile
 ? Column(
 children: items
 .map((metric) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _DeltaMetricCard(metric: metric),
 ))
 .toList(),
 )
 : Row(
 children: items
 .map((metric) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _DeltaMetricCard(metric: metric),
 ),
 ))
 .toList(),
 );
 }
}

class _DeltaMetric {
 const _DeltaMetric({
 required this.label,
 required this.value,
 required this.tone,
 this.helper,
 });

 final String label;
 final String value;
 final Color tone;
 final String? helper;
}

class _DeltaMetricCard extends StatelessWidget {
 const _DeltaMetricCard({required this.metric});

 final _DeltaMetric metric;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(metric.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 10),
 Text(
 metric.value,
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.w700, color: metric.tone),
 ),
 if (metric.helper != null) ...[
 const SizedBox(height: 6),
 Text(metric.helper!,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
 ],
 ],
 ),
 );
 }
}

class _SubsectionHeader extends StatelessWidget {
 const _SubsectionHeader({required this.title, required this.subtitle});

 final String title;
 final String subtitle;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _EmptyCostState extends StatelessWidget {
 const _EmptyCostState({required this.viewLabel});

 final String viewLabel;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 46,
 height: 46,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF3CD),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Icon(Icons.add_task, color: Color(0xFFB45309)),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'No $viewLabel yet',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 4),
 const Text(
 'Add your first cost item to start tracking estimates here.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _CategoryTile extends StatelessWidget {
 const _CategoryTile({
 required this.item,
 required this.icon,
 required this.onEdit,
 required this.onDelete,
 });

 final CostEstimateItem item;
 final IconData icon;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withOpacity(0.02),
 blurRadius: 14,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(icon, size: 20, color: const Color(0xFF1E293B)),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 ),
 const SizedBox(width: 10),
 _CostStateBadge(costState: item.costState),
 const SizedBox(width: 6),
 _DesignMaturityBadge(designMaturity: item.designMaturity),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 item.notes.isEmpty ? 'No notes added' : item.notes,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Text(
 formatCurrency(item.amount),
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined,
 size: 18, color: Color(0xFF64748B)),
 tooltip: 'Edit',
 splashRadius: 18,
 ),
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline,
 size: 18, color: Color(0xFFEF4444)),
 tooltip: 'Delete',
 splashRadius: 18,
 ),
 ],
 ),
 );
 }
}

class _SupersededCategoryTile extends StatelessWidget {
 const _SupersededCategoryTile({
 required this.entry,
 required this.icon,
 });

 final _ReconciliationEntry entry;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(icon, size: 20, color: const Color(0xFF92400E)),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 entry.superseded.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 ),
 ),
 const SizedBox(width: 10),
 _CostStateBadge(costState: entry.superseded.costState),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 entry.superseded.notes.isEmpty
 ? 'No notes added'
 : entry.superseded.notes,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 const SizedBox(height: 8),
 Text(
 'Superseded by ${entry.retained.title} (${_costStateLabel(entry.retained.costState)})',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Text(
 formatCurrency(entry.superseded.amount),
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF92400E),
 ),
 ),
 ],
 ),
 );
 }
}

class _OverheadConfigCard extends StatelessWidget {
 const _OverheadConfigCard({
 required this.ratePercent,
 required this.directBaseTotal,
 required this.complexityIndex,
 required this.onRateChanged,
 });

 final double ratePercent;
 final double directBaseTotal;
 final int complexityIndex;
 final ValueChanged<double> onRateChanged;

 @override
 Widget build(BuildContext context) {
 final overheadAmount = directBaseTotal * ratePercent / 100;

 String validationNote;
 String validationStatus;
 if (ratePercent <= 0) {
 validationNote = 'Set an overhead rate to apply G&A to direct costs.';
 validationStatus = 'info';
 } else {
 final suggestedLow = _suggestedOverheadLow(complexityIndex);
 final suggestedHigh = _suggestedOverheadHigh(complexityIndex);
 if (ratePercent >= suggestedLow && ratePercent <= suggestedHigh) {
 validationNote =
 'Project complexity $complexityIndex/10 suggests $suggestedLow\u2013$suggestedHigh%. Rate is within expected range.';
 validationStatus = 'ok';
 } else if (ratePercent < suggestedLow) {
 validationNote =
 'Project complexity $complexityIndex/10 suggests $suggestedLow\u2013$suggestedHigh%. Rate may be low for this complexity.';
 validationStatus = 'low';
 } else {
 validationNote =
 'Project complexity $complexityIndex/10 suggests $suggestedLow\u2013$suggestedHigh%. Rate is above typical range.';
 validationStatus = 'high';
 }
 }

 final statusColor = validationStatus == 'ok'
 ? const Color(0xFF059669)
 : validationStatus == 'low'
 ? const Color(0xFFC2410C)
 : validationStatus == 'high'
 ? const Color(0xFFDC2626)
 : const Color(0xFF64748B);

 return Container(
 width: 360,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Overhead & G&A',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 2),
 const Text(
 'Corporate overhead and G&A allocation',
 style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 const Text(
 'Rate (%)',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1E293B),
 ),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 80,
 height: 36,
 child: VoiceTextField(
 controller: TextEditingController(
 text: ratePercent > 0 ? ratePercent.toStringAsFixed(1) : '',
 )
 ..selection = TextSelection.fromPosition(
 TextPosition(offset: (ratePercent > 0 ? ratePercent.toStringAsFixed(1) : '').length),
 ),
 keyboardType: TextInputType.numberWithOptions(decimal: true),
 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
 decoration: const InputDecoration(
 contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 border: OutlineInputBorder(),
 isDense: true,
 suffixText: '%',
 suffixStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
 ),
 onSubmitted: (v) {
 final parsed = double.tryParse(v.trim());
 onRateChanged(parsed != null && parsed >= 0 ? parsed : 0);
 },
 ),
 ),
 ],
 ),
 if (ratePercent > 0) ...[
 const SizedBox(height: 12),
 _overheadRow('Direct Cost Base', directBaseTotal),
 _overheadRow('Overhead Amount', overheadAmount),
 if (ratePercent > 0) ...[
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 6),
 child: Divider(height: 1),
 ),
 _overheadRow('Total incl. Overhead', directBaseTotal + overheadAmount,
 bold: true),
 ],
 ],
 const SizedBox(height: 10),
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: statusColor.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(
 validationStatus == 'ok'
 ? Icons.check_circle
 : Icons.info_outline,
 size: 14,
 color: statusColor,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 validationNote,
 style: TextStyle(
 fontSize: 11,
 color: statusColor,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _overheadRow(String label, double amount, {bool bold = false}) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 2),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
 color: bold ? const Color(0xFF111827) : const Color(0xFF475569),
 ),
 ),
 Text(
 formatCurrency(amount),
 style: TextStyle(
 fontSize: 12,
 fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
 color: const Color(0xFF111827),
 ),
 ),
 ],
 ),
 );
 }

 static int _suggestedOverheadLow(int complexity) {
 if (complexity <= 3) return 5;
 if (complexity <= 6) return 10;
 return 15;
 }

 static int _suggestedOverheadHigh(int complexity) {
 if (complexity <= 3) return 10;
 if (complexity <= 6) return 15;
 return 25;
 }
}

class _TrailingSummaryCard extends StatelessWidget {
 const _TrailingSummaryCard({required this.view});

 final _CostViewDefinition view;

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: Alignment.centerRight,
 child: Container(
 width: 260,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withOpacity(0.04),
 blurRadius: 14,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 view.trailingSummaryLabel,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1E293B)),
 ),
 const SizedBox(height: 10),
 Text(
 formatCurrency(view.trailingSummaryAmount),
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ],
 ),
 ),
 );
 }
}

class _AddCostItemDialog extends StatefulWidget {
 const _AddCostItemDialog({
 required this.initialView,
 required this.projectData,
 this.existingItem,
 });

 final _CostView initialView;
 final ProjectDataModel projectData;
 final CostEstimateItem? existingItem;

 @override
 State<_AddCostItemDialog> createState() => _AddCostItemDialogState();
}

class _AddCostItemDialogState extends State<_AddCostItemDialog> {
 final _titleController = TextEditingController();
 final _amountController = TextEditingController();
 final _notesController = TextEditingController();
 final _estimatingBasisController = TextEditingController();
 final _quantityController = TextEditingController();
 final _unitRateController = TextEditingController();
 final _unitOfMeasureController = TextEditingController();
 final _contingencyPercentController = TextEditingController();
 final _contingencyAmountController = TextEditingController();
 final _quoteReferenceController = TextEditingController();
 final _contractReferenceController = TextEditingController();
 // Structured BOE (P1)
 final _scopeIncludedController = TextEditingController();
 final _scopeExcludedController = TextEditingController();
 final _designMaturityNoteController = TextEditingController();
 // PERT risk ranges (P1)
 final _rangeLowController = TextEditingController();
 final _rangeHighController = TextEditingController();
 final _formKey = GlobalKey<FormState>();
 late _CostView _selectedView = widget.initialView;
 late String _selectedSource;
 late String _selectedCostState;
 late String _selectedPhase;
 late String _selectedEstimatingMethod;
 late String _selectedDesignMaturity;
 late String _selectedRateSource;
 String? _selectedWorkPackageId;
 String? _selectedScheduleActivityId;
 bool _showValidation = false;

 bool get _isEditing => widget.existingItem != null;

 @override
 void initState() {
 super.initState();
 final existing = widget.existingItem;
 if (existing != null) {
 _titleController.text = existing.title;
 _amountController.text = existing.amount.toStringAsFixed(2);
 _notesController.text = existing.notes;
 _estimatingBasisController.text = existing.estimatingBasis;
 _quantityController.text =
 existing.quantity <= 0 ? '' : existing.quantity.toString();
 _unitRateController.text =
 existing.unitRate <= 0 ? '' : existing.unitRate.toStringAsFixed(2);
 _unitOfMeasureController.text = existing.unitOfMeasure;
 _contingencyPercentController.text = existing.contingencyPercent <= 0
 ? ''
 : existing.contingencyPercent.toStringAsFixed(2);
 _contingencyAmountController.text = existing.contingencyAmount <= 0
 ? ''
 : existing.contingencyAmount.toStringAsFixed(2);
 _quoteReferenceController.text = existing.quoteReference;
 _contractReferenceController.text = existing.contractId;
 _scopeIncludedController.text = existing.scopeIncluded;
 _scopeExcludedController.text = existing.scopeExcluded;
 _designMaturityNoteController.text = existing.designMaturityNote;
 _rangeLowController.text =
 existing.rangeLow > 0 ? existing.rangeLow.toStringAsFixed(0) : '';
 _rangeHighController.text =
 existing.rangeHigh > 0 ? existing.rangeHigh.toStringAsFixed(0) : '';
 }
 _selectedSource = existing?.source ?? 'manual';
 _selectedCostState = existing?.costState ?? 'forecast';
 _selectedPhase = existing?.phase.trim().isNotEmpty == true
 ? existing!.phase
 : 'planning';
 _selectedEstimatingMethod =
 existing?.estimatingMethod.trim().isNotEmpty == true
 ? existing!.estimatingMethod
 : 'manual';
 _selectedDesignMaturity =
 existing?.designMaturity.trim().isNotEmpty == true
 ? existing!.designMaturity
 : '';
 _selectedRateSource =
 existing?.rateSource.trim().isNotEmpty == true
 ? existing!.rateSource
 : '';
 _selectedWorkPackageId = existing?.workPackageId.trim().isNotEmpty == true
 ? existing!.workPackageId
 : null;
 _selectedScheduleActivityId =
 existing?.scheduleActivityId.trim().isNotEmpty == true
 ? existing!.scheduleActivityId
 : null;
 }

 @override
 void dispose() {
 _titleController.dispose();
 _amountController.dispose();
 _notesController.dispose();
 _estimatingBasisController.dispose();
 _quantityController.dispose();
 _unitRateController.dispose();
 _unitOfMeasureController.dispose();
 _contingencyPercentController.dispose();
 _contingencyAmountController.dispose();
 _quoteReferenceController.dispose();
 _contractReferenceController.dispose();
 _scopeIncludedController.dispose();
 _scopeExcludedController.dispose();
 _designMaturityNoteController.dispose();
 _rangeLowController.dispose();
 _rangeHighController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final accent = _accentForView(_selectedView);
 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
 backgroundColor: Colors.white,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 accent.withOpacity(0.16),
 accent.withOpacity(0.05),
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius:
 const BorderRadius.vertical(top: Radius.circular(28)),
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.15),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(
 _isEditing
 ? Icons.edit_outlined
 : Icons.add_circle_outline,
 color: accent),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 _isEditing ? 'Edit Cost Item' : 'Add Cost Item',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 4),
 Text(
 _isEditing
 ? 'Update cost details for ${_viewLabel(_selectedView)}.'
 : 'Capture a new cost line under ${_viewLabel(_selectedView)}.',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 Padding(
 padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
 child: Form(
 key: _formKey,
 autovalidateMode: _showValidation
 ? AutovalidateMode.always
 : AutovalidateMode.disabled,
 child: SizedBox(
 height: 620,
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _DialogLabel(label: 'Category'),
 const SizedBox(height: 8),
 _TypeSelector(
 selectedView: _selectedView,
 onChanged: (value) =>
 setState(() => _selectedView = value),
 ),
 const SizedBox(height: 18),
 Row(
 children: [
 Expanded(
 child: _dropdownField<String>(
 label: 'Source',
 value: _selectedSource,
 items: const [
 DropdownMenuItem(
 value: 'manual', child: Text('Manual')),
 DropdownMenuItem(
 value: 'project_contractor',
 child: Text('Contractor')),
 DropdownMenuItem(
 value: 'project_vendor',
 child: Text('Vendor')),
 DropdownMenuItem(
 value: 'project_contract',
 child: Text('Contract')),
 DropdownMenuItem(
 value: 'project_procurement_item',
 child: Text('Procurement Budget')),
 DropdownMenuItem(
 value: 'project_procurement_actual',
 child: Text('Procurement Actual')),
 DropdownMenuItem(
 value: 'project_purchase_order',
 child: Text('Purchase Order')),
 DropdownMenuItem(
 value: 'planning_allowance',
 child: Text('Allowance')),
 DropdownMenuItem(
 value: 'risk_mitigation',
 child: Text('Risk Mitigation')),
 DropdownMenuItem(
 value: 'planning_technology',
 child: Text('Technology')),
 DropdownMenuItem(
 value: 'project_work_package',
 child: Text('Work Package')),
 DropdownMenuItem(
 value: 'project_work_package_actual',
 child: Text('Work Package Actual')),
 DropdownMenuItem(
 value: 'planning_staffing',
 child: Text('Staffing')),
 DropdownMenuItem(
 value: 'planning_infrastructure',
 child: Text('Infrastructure')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedSource = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _dropdownField<String>(
 label: 'Phase',
 value: _selectedPhase,
 items: const [
 DropdownMenuItem(
 value: 'planning',
 child: Text('Planning')),
 DropdownMenuItem(
 value: 'design', child: Text('Design')),
 DropdownMenuItem(
 value: 'execution',
 child: Text('Execution')),
 DropdownMenuItem(
 value: 'launch', child: Text('Launch')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedPhase = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _dropdownField<String>(
 label: 'Cost State',
 value: _selectedCostState,
 items: const [
 DropdownMenuItem(
 value: 'forecast', child: Text('Forecast')),
 DropdownMenuItem(
 value: 'committed', child: Text('Committed')),
 DropdownMenuItem(
 value: 'actual', child: Text('Actual')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedCostState = value);
 },
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'Cost item'),
 const SizedBox(height: 8),
 VoiceTextFormField(
 controller: _titleController,
 decoration: _inputDecoration(
 'e.g., Vendor integration services'),
 textCapitalization: TextCapitalization.sentences,
 validator: (value) {
 if (value == null || value.trim().isEmpty) {
 return 'Add a short name for this cost item';
 }
 return null;
 },
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: _dropdownField<String?>(
 label: 'Work Package',
 value: _selectedWorkPackageId,
 items: [
 const DropdownMenuItem<String?>(
 value: null,
 child: Text('Not linked'),
 ),
 ...widget.projectData.workPackages.map(
 (workPackage) => DropdownMenuItem<String?>(
 value: workPackage.id,
 child: Text(
 workPackage.title.trim().isEmpty
 ? 'Untitled Work Package'
 : workPackage.title.trim(),
 ),
 ),
 ),
 ],
 onChanged: (value) => setState(
 () => _selectedWorkPackageId = value),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _dropdownField<String?>(
 label: 'Schedule Activity',
 value: _selectedScheduleActivityId,
 items: [
 const DropdownMenuItem<String?>(
 value: null,
 child: Text('Not linked'),
 ),
 ...widget.projectData.scheduleActivities.map(
 (activity) => DropdownMenuItem<String?>(
 value: activity.id,
 child: Text(
 activity.title.trim().isEmpty
 ? 'Untitled Activity'
 : activity.title.trim(),
 ),
 ),
 ),
 ],
 onChanged: (value) => setState(
 () => _selectedScheduleActivityId = value),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'Estimated amount'),
 const SizedBox(height: 8),
 VoiceTextFormField(
 controller: _amountController,
 keyboardType: const TextInputType.numberWithOptions(
 decimal: true),
 decoration: _inputDecoration('0.00', prefix: '\$'),
 validator: (value) {
 final amount = _parseAmount(value ?? '');
 if (amount <= 0) {
 return 'Enter a valid amount';
 }
 return null;
 },
 ),
 const SizedBox(height: 16),
 _dropdownField<String>(
 label: 'Estimating Method',
 value: _selectedEstimatingMethod,
 items: const [
 DropdownMenuItem(
 value: 'manual', child: Text('Manual')),
 DropdownMenuItem(
 value: 'bottoms_up', child: Text('Bottoms up')),
 DropdownMenuItem(
 value: 'top_down', child: Text('Top down')),
 DropdownMenuItem(
 value: 'unit_rate', child: Text('Unit rate')),
 DropdownMenuItem(
 value: 'analogous', child: Text('Analogous')),
 DropdownMenuItem(
 value: 'quote_based',
 child: Text('Quote based')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedEstimatingMethod = value);
 },
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'Estimating basis'),
 const SizedBox(height: 8),
 VoiceTextFormField(
 controller: _estimatingBasisController,
 minLines: 2,
 maxLines: 3,
 decoration: _inputDecoration(
 'Describe the assumptions, source quote, or method behind this estimate',
 ),
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'Scope / BOE (optional)'),
 const SizedBox(height: 8),
 VoiceTextFormField(
 controller: _scopeIncludedController,
 minLines: 2,
 maxLines: 3,
 decoration: _inputDecoration('Scope included'),
 ),
 const SizedBox(height: 10),
 VoiceTextFormField(
 controller: _scopeExcludedController,
 minLines: 2,
 maxLines: 3,
 decoration: _inputDecoration('Scope excluded'),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _dropdownField<String>(
 label: 'Design Maturity',
 value: _selectedDesignMaturity,
 items: const [
 DropdownMenuItem(value: '', child: Text('Not specified')),
 DropdownMenuItem(value: '10%', child: Text('10% - Concept')),
 DropdownMenuItem(value: '30%', child: Text('30% - Preliminary')),
 DropdownMenuItem(value: '60%', child: Text('60% - Detailed')),
 DropdownMenuItem(value: '90%', child: Text('90% - Pre-IFC')),
 DropdownMenuItem(value: 'IFC', child: Text('IFC')),
 DropdownMenuItem(value: 'AsBuilt', child: Text('As-Built')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedDesignMaturity = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _dropdownField<String>(
 label: 'Rate Source',
 value: _selectedRateSource,
 items: const [
 DropdownMenuItem(value: '', child: Text('Not specified')),
 DropdownMenuItem(value: 'vendor_quote', child: Text('Vendor Quote')),
 DropdownMenuItem(value: 'historical', child: Text('Historical Data')),
 DropdownMenuItem(value: 'published_index', child: Text('Published Index')),
 DropdownMenuItem(value: 'benchmark', child: Text('Benchmark')),
 DropdownMenuItem(value: 'expert_judgment', child: Text('Expert Judgment')),
 ],
 onChanged: (value) {
 if (value == null) return;
 setState(() => _selectedRateSource = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 VoiceTextFormField(
 controller: _designMaturityNoteController,
 decoration: _inputDecoration('Design maturity note (optional)'),
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _quantityController,
 keyboardType: TextInputType.number,
 decoration: _inputDecoration('Quantity'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _unitRateController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true),
 decoration:
 _inputDecoration('Unit rate', prefix: '\$'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _unitOfMeasureController,
 decoration: _inputDecoration('Unit of measure'),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _contingencyPercentController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true),
 decoration: _inputDecoration('Contingency %'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _contingencyAmountController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true),
 decoration: _inputDecoration(
 'Contingency amount',
 prefix: '\$',
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'PERT Risk Ranges (optional)'),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _rangeLowController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true),
 decoration: _inputDecoration(
 'Optimistic (low)',
 prefix: '\$',
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _rangeHighController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true),
 decoration: _inputDecoration(
 'Pessimistic (high)',
 prefix: '\$',
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _quoteReferenceController,
 decoration: _inputDecoration('Quote reference'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _contractReferenceController,
 decoration: _inputDecoration(
 'Contract / commercial reference'),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _DialogLabel(label: 'Notes (optional)'),
 const SizedBox(height: 8),
 VoiceTextFormField(
 controller: _notesController,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(
 'Add vendor notes, scope details, or assumptions'),
 ),
 const SizedBox(height: 22),
 Row(
 children: [
 Expanded(
 child: OutlinedButton(
 onPressed: () => Navigator.of(context).pop(),
 style: OutlinedButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 side: const BorderSide(
 color: Color(0xFFE2E8F0)),
 foregroundColor: const Color(0xFF475569),
 ),
 child: const Text('Cancel',
 style:
 TextStyle(fontWeight: FontWeight.w600)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton(
 onPressed: _submit,
 style: ElevatedButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(vertical: 14),
 backgroundColor: accent,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 elevation: 0,
 ),
 child: Text(
 _isEditing ? 'Update item' : 'Add item',
 style: const TextStyle(
 fontWeight: FontWeight.w700)),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 void _submit() {
 if (!(_formKey.currentState?.validate() ?? false)) {
 setState(() => _showValidation = true);
 return;
 }

 final amount = _parseAmount(_amountController.text);
 final item = CostEstimateItem(
 id: _isEditing ? widget.existingItem!.id : null,
 title: _titleController.text.trim(),
 notes: _notesController.text.trim(),
 amount: amount,
 costType: _viewKey(_selectedView),
 source: _selectedSource,
 costState: _selectedCostState,
 isBaseline: _isEditing ? widget.existingItem!.isBaseline : false,
 workPackageId: _selectedWorkPackageId ?? '',
 workPackageTitle: _workPackageTitle(_selectedWorkPackageId),
 scheduleActivityId: _selectedScheduleActivityId ?? '',
 phase: _selectedPhase,
 estimatingMethod: _selectedEstimatingMethod,
 estimatingBasis: _estimatingBasisController.text.trim(),
 quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
 unitRate: _parseAmount(_unitRateController.text),
 unitOfMeasure: _unitOfMeasureController.text.trim(),
 contingencyPercent: _parseAmount(_contingencyPercentController.text),
 contingencyAmount: _parseAmount(_contingencyAmountController.text),
 rangeLow: _parseAmount(_rangeLowController.text),
 rangeHigh: _parseAmount(_rangeHighController.text),
 scopeIncluded: _scopeIncludedController.text.trim(),
 scopeExcluded: _scopeExcludedController.text.trim(),
 designMaturity: _selectedDesignMaturity,
 designMaturityNote: _designMaturityNoteController.text.trim(),
 rateSource: _selectedRateSource,
 contractId: _contractReferenceController.text.trim(),
 quoteReference: _quoteReferenceController.text.trim(),
 reconciliationReference:
 _isEditing ? widget.existingItem!.reconciliationReference : '',
 );
 Navigator.of(context).pop(item);
 }

 double _parseAmount(String input) {
 final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
 return double.tryParse(cleaned) ?? 0.0;
 }

 InputDecoration _inputDecoration(String hint, {String? prefix}) {
 return InputDecoration(
 hintText: hint,
 prefixText: prefix,
 prefixStyle: const TextStyle(color: Color(0xFF64748B)),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 );
 }

 Color _accentForView(_CostView view) => view == _CostView.direct
 ? const Color(0xFF2563EB)
 : const Color(0xFF047857);

 String _viewLabel(_CostView view) =>
 view == _CostView.direct ? 'Direct Costs' : 'Indirect Costs';

 String _viewKey(_CostView view) =>
 view == _CostView.direct ? 'direct' : 'indirect';

 Widget _dropdownField<T>({
 required String label,
 required T? value,
 required List<DropdownMenuItem<T>> items,
 required ValueChanged<T?> onChanged,
 }) {
 return DropdownButtonFormField<T>(
 value: value,
 items: items,
 onChanged: onChanged,
 decoration: _inputDecoration(label),
 );
 }

 String _workPackageTitle(String? workPackageId) {
 if (workPackageId == null || workPackageId.isEmpty) return '';
 for (final workPackage in widget.projectData.workPackages) {
 if (workPackage.id == workPackageId) {
 return workPackage.title.trim();
 }
 }
 return '';
 }
}

class _TypeSelector extends StatelessWidget {
 const _TypeSelector({required this.selectedView, required this.onChanged});

 final _CostView selectedView;
 final ValueChanged<_CostView> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: _CostView.values.map((view) {
 final bool isActive = view == selectedView;
 final Color accent = view == _CostView.direct
 ? const Color(0xFF2563EB)
 : const Color(0xFF047857);
 return Expanded(
 child: GestureDetector(
 onTap: () => onChanged(view),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: BoxDecoration(
 color: isActive ? accent : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 view == _CostView.direct
 ? Icons.trending_up
 : Icons.layers_outlined,
 size: 16,
 color: isActive ? Colors.white : const Color(0xFF64748B),
 ),
 const SizedBox(width: 6),
 Text(
 view == _CostView.direct
 ? 'Direct Costs'
 : 'Indirect Costs',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color:
 isActive ? Colors.white : const Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }
}

class _DialogLabel extends StatelessWidget {
 const _DialogLabel({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Text(
 label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
 );
 }
}

class _UserChip extends StatelessWidget {
 const _UserChip({required this.name, required this.role});

 final String name;
 final String role;

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName = FirebaseAuthService.displayNameOrEmail(
 fallback: name.isNotEmpty ? name : 'User');
 final email = user?.email ?? '';
 final primary = displayName.isNotEmpty
 ? displayName
 : (email.isNotEmpty ? email : name);
 final photoUrl = user?.photoURL ?? '';

 return StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
 final resolvedRole = isAdmin ? 'Admin' : 'Member';
 final roleText = role.isNotEmpty ? role : resolvedRole;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFE5E7EB),
 backgroundImage:
 photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
 child: photoUrl.isEmpty
 ? Text(
 primary.isNotEmpty ? primary[0].toUpperCase() : 'U',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 )
 : null,
 ),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 primary,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 Text(
 roleText,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ],
 ),
 );
 },
 );
 }
}

class _CostSummary {
 const _CostSummary({
 required this.title,
 required this.amount,
 required this.description,
 this.backgroundColor = Colors.white,
 this.accentColor = const Color(0xFF111827),
 this.descriptionColor = const Color(0xFF6B7280),
 this.badgeLabel,
 });

 final String title;
 final double amount;
 final String description;
 final Color backgroundColor;
 final Color accentColor;
 final Color descriptionColor;
 final String? badgeLabel;
}

class _CostViewMeta {
 const _CostViewMeta({required this.label, required this.description});

 final String label;
 final String description;
}

class _CostCategory {
 const _CostCategory(
 {required this.title,
 required this.icon,
 required this.amount,
 this.notes = ''});

 final String title;
 final IconData icon;
 final double amount;
 final String notes;
}

enum _CostView { direct, indirect }

enum _CostStateFilter { all, forecast, committed, actual }

enum _CostWorkspaceTab {
 overview,
 estimateLines,
 cbsTree,
 sourceImports,
 contractsProcurement,
 staffingInfrastructure,
 contingencyRisk,
 costVsSchedule,
}

class _CostViewDefinition {
 const _CostViewDefinition({
 required this.label,
 required this.description,
 required this.categories,
 required this.trailingSummaryLabel,
 required this.trailingSummaryAmount,
 });

 final String label;
 final String description;
 final List<_CostCategory> categories;
 final String trailingSummaryLabel;
 final double trailingSummaryAmount;
}

class _SourceSummary {
 const _SourceSummary({
 required this.title,
 required this.subtitle,
 required this.sourceKey,
 required this.total,
 required this.sourceCount,
 required this.status,
 this.importedCount = 0,
 });

 final String title;
 final String subtitle;
 final String sourceKey;
 final double total;
 final int sourceCount;
 final int importedCount;
 final _SourceSummaryStatus status;
}

enum _SourceSummaryStatus {
 imported,
 partial,
 missing,
 needsStructuring,
}

extension _SourceSummaryStatusX on _SourceSummaryStatus {
 String get label {
 switch (this) {
 case _SourceSummaryStatus.imported:
 return 'Imported';
 case _SourceSummaryStatus.partial:
 return 'Partial';
 case _SourceSummaryStatus.missing:
 return 'Missing';
 case _SourceSummaryStatus.needsStructuring:
 return 'Needs Structuring';
 }
 }

 Color get backgroundColor {
 switch (this) {
 case _SourceSummaryStatus.imported:
 return const Color(0xFFECFDF5);
 case _SourceSummaryStatus.partial:
 return const Color(0xFFFFF7ED);
 case _SourceSummaryStatus.missing:
 return const Color(0xFFFEF2F2);
 case _SourceSummaryStatus.needsStructuring:
 return const Color(0xFFF1F5F9);
 }
 }

 Color get foregroundColor {
 switch (this) {
 case _SourceSummaryStatus.imported:
 return const Color(0xFF059669);
 case _SourceSummaryStatus.partial:
 return const Color(0xFFC2410C);
 case _SourceSummaryStatus.missing:
 return const Color(0xFFDC2626);
 case _SourceSummaryStatus.needsStructuring:
 return const Color(0xFF475569);
 }
 }
}

extension _CostWorkspaceTabX on _CostWorkspaceTab {
 String get label {
 switch (this) {
 case _CostWorkspaceTab.overview:
 return 'Overview';
 case _CostWorkspaceTab.estimateLines:
 return 'Estimate Lines';
 case _CostWorkspaceTab.cbsTree:
 return 'CBS Tree';
 case _CostWorkspaceTab.sourceImports:
 return 'Source Imports';
 case _CostWorkspaceTab.contractsProcurement:
 return 'Contracts & Procurement';
 case _CostWorkspaceTab.staffingInfrastructure:
 return 'Staffing & Infrastructure';
 case _CostWorkspaceTab.contingencyRisk:
 return 'Contingency & Risk';
 case _CostWorkspaceTab.costVsSchedule:
 return 'Cost vs Schedule';
 }
 }
}

class _ValidationSummary {
 const _ValidationSummary({required this.issues});

 final List<String> issues;
}

class _ReconciliationReport {
 const _ReconciliationReport({
 required this.totalImported,
 required this.activeImported,
 required this.supersededCount,
 required this.entries,
 });

 final int totalImported;
 final int activeImported;
 final int supersededCount;
 final List<_ReconciliationEntry> entries;
}

class _ReconciliationEntry {
 const _ReconciliationEntry({
 required this.key,
 required this.superseded,
 required this.retained,
 required this.reason,
 });

 final String key;
 final CostEstimateItem superseded;
 final CostEstimateItem retained;
 final String reason;
}

class _ReconciliationOutcome {
 const _ReconciliationOutcome({
 required this.activeItems,
 required this.reportEntries,
 });

 final List<CostEstimateItem> activeItems;
 final List<_ReconciliationEntry> reportEntries;
}

class _OverviewRow {
 const _OverviewRow({required this.label, required this.value});

 final String label;
 final double value;
}

class _SourceDetailRow {
 const _SourceDetailRow({
 required this.title,
 required this.subtitle,
 required this.amount,
 });

 final String title;
 final String subtitle;
 final double amount;
}

String _costStateFilterLabel(_CostStateFilter filter) {
 switch (filter) {
 case _CostStateFilter.all:
 return 'Planning Forecast';
 case _CostStateFilter.forecast:
 return 'Forecast';
 case _CostStateFilter.committed:
 return 'Committed';
 case _CostStateFilter.actual:
 return 'Actual';
 }
}

String _costStateLabel(String costState) {
 switch (costState) {
 case 'committed':
 return 'Committed';
 case 'actual':
 return 'Actual';
 case 'forecast':
 default:
 return 'Forecast';
 }
}

Color _costStateTone(String costState) {
 switch (costState) {
 case 'committed':
 return const Color(0xFF1D4ED8);
 case 'actual':
 return const Color(0xFF047857);
 case 'forecast':
 default:
 return const Color(0xFFB45309);
 }
}

int _maturityRank(String designMaturity) {
 switch (designMaturity) {
 case 'AsBuilt': return 6;
 case 'IFC': return 5;
 case '90%': return 4;
 case '60%': return 3;
 case '30%': return 2;
 case '10%': return 1;
 default: return 0;
 }
}

int _resolveComplexityIndex(ProjectDataModel projectData) {
 final assumptions = projectData.costAnalysisData?.solutionCostAssumptions;
 if (assumptions != null && assumptions.isNotEmpty) {
 return assumptions.first.complexityIndex;
 }
 return 3;
}

Color _designMaturityColor(String designMaturity) {
 switch (designMaturity) {
 case '10%':
 return const Color(0xFFDC2626);
 case '30%':
 return const Color(0xFFEA580C);
 case '60%':
 return const Color(0xFFCA8A04);
 case '90%':
 return const Color(0xFF059669);
 case 'IFC':
 return const Color(0xFF2563EB);
 case 'AsBuilt':
 return const Color(0xFF7C3AED);
 default:
 return const Color(0xFF94A3B8);
 }
}

String _designMaturityLabel(String designMaturity) {
 switch (designMaturity) {
 case '10%':
 return '10% Concept';
 case '30%':
 return '30% Prelim';
 case '60%':
 return '60% Detail';
 case '90%':
 return '90% Pre-IFC';
 case 'IFC':
 return 'IFC';
 case 'AsBuilt':
 return 'As-Built';
 default:
 return '';
 }
}

String formatCurrency(double value) {
 final parts = value.toStringAsFixed(2).split('.');
 final whole = parts.first.replaceAllMapped(
 RegExp(r'(?<!^)(?=(\d{3})+(?!\d))'),
 (match) => ',',
 );
 return "\$$whole.${parts.last}";
}

String _formatShortDate(DateTime value) {
 final month = <int, String>{
 1: 'Jan',
 2: 'Feb',
 3: 'Mar',
 4: 'Apr',
 5: 'May',
 6: 'Jun',
 7: 'Jul',
 8: 'Aug',
 9: 'Sep',
 10: 'Oct',
 11: 'Nov',
 12: 'Dec',
 }[value.month];
 return '${month ?? value.month}/${value.day}/${value.year}';
}

class _AiSuggestionsDialog extends StatefulWidget {
 const _AiSuggestionsDialog({required this.projectContext});

 final String projectContext;

 @override
 State<_AiSuggestionsDialog> createState() => _AiSuggestionsDialogState();
}

class _AiSuggestionsDialogState extends State<_AiSuggestionsDialog> {
 final _service = OpenAiServiceSecure();
 bool _loading = false;
 List<CostEstimateItem> _suggestions = [];
 final Set<int> _selectedIndices = {};
 String? _error;

 @override
 void initState() {
 super.initState();
 _fetchSuggestions();
 }

 Future<void> _fetchSuggestions() async {
 setState(() {
 _loading = true;
 _error = null;
 _suggestions = [];
 _selectedIndices.clear();
 });

 try {
 final projectData = ProjectDataHelper.getData(context);
 final items = await _service.generateCostEstimateSuggestions(
 context: widget.projectContext,
 currency: projectData.costBenefitCurrency);
 if (mounted) {
 setState(() {
 _suggestions = items;
 _loading = false;
 });
 }
 } catch (e) {
 if (mounted) {
 setState(() {
 _error = e.toString().replaceAll('Exception:', '').trim();
 _loading = false;
 });
 }
 }
 }

 void _toggleSelection(int index) {
 setState(() {
 if (_selectedIndices.contains(index)) {
 _selectedIndices.remove(index);
 } else {
 _selectedIndices.add(index);
 }
 });
 }

 void _addSelected() {
 final selected = _selectedIndices.map((i) => _suggestions[i]).toList();
 Navigator.of(context).pop(selected);
 }

 @override
 Widget build(BuildContext context) {
 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
 backgroundColor: Colors.white,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Header
 Container(
 padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius:
 const BorderRadius.vertical(top: Radius.circular(28)),
 border:
 Border(bottom: BorderSide(color: const Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFFDBEAFE),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(Icons.auto_awesome,
 color: Color(0xFF2563EB), size: 24),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'AI Cost Suggestions',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1E293B)),
 ),
 SizedBox(height: 4),
 Text(
 'Select suggested items to add to your estimate.',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),

 // Content
 Flexible(
 child: _loading
 ? const Center(
 child: Padding(
 padding: EdgeInsets.all(40),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircularProgressIndicator(strokeWidth: 3),
 SizedBox(height: 16),
 Text('Generating realistic estimates...',
 style: TextStyle(color: Color(0xFF64748B))),
 ],
 ),
 ),
 )
 : _error != null
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.error_outline,
 size: 48, color: Color(0xFFEF4444)),
 const SizedBox(height: 16),
 Text(
 _error!,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: Color(0xFF1E293B),
 fontWeight: FontWeight.w500),
 ),
 const SizedBox(height: 24),
 FilledButton.icon(
 onPressed: _fetchSuggestions,
 icon: const Icon(Icons.refresh),
 label: const Text('Try Again'),
 ),
 ],
 ),
 ),
 )
 : _suggestions.isEmpty
 ? const Center(
 child: Padding(
 padding: EdgeInsets.all(40),
 child: Text(
 'No suggestions found. Try regenerating.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 )
 : ListView.separated(
 padding: const EdgeInsets.all(24),
 shrinkWrap: true,
 itemCount: _suggestions.length,
 separatorBuilder: (_, __) =>
 const SizedBox(height: 12),
 itemBuilder: (ctx, index) {
 final item = _suggestions[index];
 final isSelected =
 _selectedIndices.contains(index);
 return InkWell(
 onTap: () => _toggleSelection(index),
 borderRadius: BorderRadius.circular(16),
 child: Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFEFF6FF)
 : Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isSelected
 ? const Color(0xFF3B82F6)
 : const Color(0xFFE5E7EB),
 width: isSelected ? 2 : 1,
 ),
 ),
 child: Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Padding(
 padding:
 const EdgeInsets.only(top: 2),
 child: Icon(
 isSelected
 ? Icons.check_circle
 : Icons.circle_outlined,
 color: isSelected
 ? const Color(0xFF3B82F6)
 : const Color(0xFFCBD5E1),
 size: 22,
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight:
 FontWeight.w600,
 color:
 Color(0xFF1E293B),
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets
 .symmetric(
 horizontal: 8,
 vertical: 2),
 decoration: BoxDecoration(
 color: const Color(
 0xFFF1F5F9),
 borderRadius:
 BorderRadius.circular(
 6),
 ),
 child: Text(
 item.costType
 .toUpperCase(),
 style: const TextStyle(
 fontSize: 10,
 fontWeight:
 FontWeight.w700,
 color:
 Color(0xFF64748B),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 item.notes,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 6),
 Text(
 formatCurrency(item.amount),
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(
 0xFF2563EB), // Blue-600
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),

 // Footer
 Padding(
 padding: const EdgeInsets.all(24),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 TextButton.icon(
 onPressed: _loading ? null : _fetchSuggestions,
 icon: const Icon(Icons.refresh, size: 18),
 label: const Text('Regenerate'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF64748B),
 ),
 ),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF64748B),
 ),
 child: const Text('Cancel'),
 ),
 const SizedBox(width: 12),
 FilledButton(
 onPressed:
 _selectedIndices.isEmpty ? null : _addSelected,
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 padding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child:
 Text('Add Selected (${_selectedIndices.length})'),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}
