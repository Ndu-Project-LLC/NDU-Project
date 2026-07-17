import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/form_validation_engine.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/screens/front_end_planning_security.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/procurement_dialogs.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/procurement/procurement_items_list_view.dart';
import 'package:ndu_project/widgets/procurement/procurement_vendor_management.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
enum ProcurementScreenMode { fep, planning }

enum _MissingProcurementAction {
 manual,
 autoFill,
 skip,
}

/// Front End Planning â€“ Procurement screen
/// Recreates the provided procurement workspace mock with strategies and vendor table.
class FrontEndPlanningProcurementScreen extends StatefulWidget {
 const FrontEndPlanningProcurementScreen({
 super.key,
 this.mode = ProcurementScreenMode.fep,
 this.activeItemLabel,
 });

 final ProcurementScreenMode mode;
 final String? activeItemLabel;

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningProcurementScreen()),
 );
 }

 @override
 State<FrontEndPlanningProcurementScreen> createState() =>
 _FrontEndPlanningProcurementScreenState();
}

class _FrontEndPlanningProcurementScreenState
 extends State<FrontEndPlanningProcurementScreen> {
 static const int _initialStreamLimit = 60;
 static const int _streamLimitStep = 40;
 static const String _procurementNotesKey = 'planning_procurement_notes';
 static const String _procurementPlanNoteKey = 'planning_procurement_plan';
 static const String _procurementSeededKey =
 'planning_procurement_seeded_from_initiation';
 static const String _workflowCollectionName = 'procurement_workflows';
 static const String _workflowGlobalDocId = 'global';
 static const List<_ProcurementWorkflowStep>
 _defaultProcurementWorkflowTemplate = [
 _ProcurementWorkflowStep(
 id: 'request_for_quote',
 name: 'Request for Quote (RFQ)',
 duration: 2,
 unit: 'week',
 ),
 _ProcurementWorkflowStep(
 id: 'quote_evaluation',
 name: 'Quote Evaluation',
 duration: 2,
 unit: 'week',
 ),
 _ProcurementWorkflowStep(
 id: 'request_for_information',
 name: 'Request for Information',
 duration: 1,
 unit: 'week',
 ),
 _ProcurementWorkflowStep(
 id: 'purchase_order',
 name: 'Purchase Order',
 duration: 1,
 unit: 'week',
 ),
 ];

 final GlobalKey _notesFieldKey = GlobalKey();
 final GlobalKey _itemsSectionKey = GlobalKey();
 final GlobalKey _vendorSectionKey = GlobalKey();
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 Map<String, String> _validationErrors = const {};
 final Set<_ProcurementTab> _tabsWithErrors = <_ProcurementTab>{};
 bool _showPendingSecurityPrompt = false;
 List<ValidationIssue> _pendingSecurityIssues = const <ValidationIssue>[];

 bool _approvedOnly = false;
 bool _preferredOnly = false;
 bool _listView = true;
 bool _purchaseOrdersEarlyStartEnabled = false;
 bool _customizeWorkflowByScope = false;
 String _categoryFilter = 'All Categories';
 String? _selectedWorkflowScopeId;

 _ProcurementTab _selectedTab = _ProcurementTab.procurementDashboard;
 int _selectedTrackableIndex = 0;
 late final NumberFormat _currencyFormat =
 NumberFormat.currency(symbol: '\$', decimalDigits: 0);

 List<ProcurementItemModel> _items = [];

 final List<ProcurementItemModel> _trackableItems = [];

 List<ProcurementStrategyModel> _strategies = [];

 List<VendorModel> _vendors = [];
 List<ProcurementAssignableMemberOption> _assignableMembers =
 const <ProcurementAssignableMemberOption>[];
 final Set<String> _selectedVendorIds = {};

 final List<VendorHealthMetric> _vendorHealthMetrics = [];

 final List<VendorOnboardingTask> _vendorOnboardingTasks = [];

 final List<VendorRiskItem> _vendorRiskItems = [];

 List<RfqModel> _rfqs = [];

 final List<_RfqCriterion> _rfqCriteria = [];
 List<_ProcurementWorkflowStep> _globalWorkflowSteps =
 List<_ProcurementWorkflowStep>.from(_defaultProcurementWorkflowTemplate);
 List<_ProcurementWorkflowStep> _workflowDraftSteps =
 List<_ProcurementWorkflowStep>.from(_defaultProcurementWorkflowTemplate);
 Map<String, List<_ProcurementWorkflowStep>> _scopeWorkflowOverrides = {};

 List<PurchaseOrderModel> _purchaseOrders = [];

 final List<_TrackingAlert> _trackingAlerts = [];

 final List<_CarrierPerformance> _carrierPerformance = [];

 final List<_ReportKpi> _reportKpis = [];

 final List<_SpendBreakdown> _spendBreakdown = [];

 final List<_LeadTimeMetric> _leadTimeMetrics = [];

 final List<_SavingsOpportunity> _savingsOpportunities = [];

 final List<_ComplianceMetric> _complianceMetrics = [];

 late final OpenAiServiceSecure _openAi;
 bool _isGeneratingData = false;
 bool _isSeedingFromInitiation = false;
 bool _workflowLoading = false;
 bool _workflowSaving = false;
 String? _streamError;
 String? _activeProjectId;
 String? _autoGenerationRequestedProjectId;
 String? _scheduledProjectBootstrapId;
 String? _autoSeededStrategiesProjectId;

 int _itemsLimit = _initialStreamLimit;
 int _strategiesLimit = _initialStreamLimit;
 int _vendorsLimit = _initialStreamLimit;
 int _rfqsLimit = _initialStreamLimit;
 int _purchaseOrdersLimit = _initialStreamLimit;

 StreamSubscription<List<ProcurementItemModel>>? _itemsSub;
 StreamSubscription<List<ProcurementStrategyModel>>? _strategiesSub;
 StreamSubscription<List<VendorModel>>? _vendorsSub;
 StreamSubscription<List<RfqModel>>? _rfqsSub;
 StreamSubscription<List<PurchaseOrderModel>>? _purchaseOrdersSub;
 bool _isAutoAssigningVendors = false;
 bool _isEnsuringPurchaseOrders = false;

 bool get _canCommenceContractingActivities => AdminEditToggle.isAdmin();

 bool get _hasCommencedContractingActivities {
 final startedItems = _items.any(
 (item) => item.status != ProcurementItemStatus.planning,
 );
 return startedItems || _rfqs.isNotEmpty || _purchaseOrders.isNotEmpty;
 }

 bool get _isPurchaseOrdersSectionEnabled =>
 _hasCommencedContractingActivities || _purchaseOrdersEarlyStartEnabled;

 bool _isVitalLleItem(ProcurementItemModel item) {
 final category = item.category.toLowerCase();
 final hasLongLeadCategory = category.contains('equipment') ||
 category.contains('material') ||
 category.contains('logistics') ||
 category.contains('infrastructure') ||
 category.contains('construction');
 final priorityCritical = item.priority == ProcurementPriority.critical ||
 item.priority == ProcurementPriority.high;
 return hasLongLeadCategory || priorityCritical;
 }

 List<ProcurementItemModel> get _vitalLleItems {
 final prioritized = _items.where(_isVitalLleItem).toList();
 prioritized.sort((a, b) {
 int priorityRank(ProcurementPriority value) {
 switch (value) {
 case ProcurementPriority.critical:
 return 4;
 case ProcurementPriority.high:
 return 3;
 case ProcurementPriority.medium:
 return 2;
 case ProcurementPriority.low:
 return 1;
 }
 }

 final priorityCompare =
 priorityRank(b.priority).compareTo(priorityRank(a.priority));
 if (priorityCompare != 0) return priorityCompare;
 final aDate =
 a.estimatedDelivery ?? DateTime.fromMillisecondsSinceEpoch(0);
 final bDate =
 b.estimatedDelivery ?? DateTime.fromMillisecondsSinceEpoch(0);
 return aDate.compareTo(bDate);
 });
 return prioritized;
 }

 List<_ProcurementWorkflowStep> _cloneWorkflowSteps(
 List<_ProcurementWorkflowStep> steps) {
 return steps.map((step) => step.copyWith()).toList(growable: true);
 }

 CollectionReference<Map<String, dynamic>> _workflowCollection(
 String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_workflowCollectionName);
 }

 List<_ProcurementWorkflowStep> _parseWorkflowSteps(dynamic raw) {
 if (raw is! List) return const <_ProcurementWorkflowStep>[];
 final steps = <_ProcurementWorkflowStep>[];
 for (final entry in raw) {
 if (entry is Map<String, dynamic>) {
 steps.add(_ProcurementWorkflowStep.fromMap(entry));
 } else if (entry is Map) {
 steps.add(
 _ProcurementWorkflowStep.fromMap(Map<String, dynamic>.from(entry)),
 );
 }
 }
 return steps;
 }

 String _scopeDocId(String scopeId) => 'scope_${scopeId.trim()}';

 Future<void> _loadProcurementWorkflowData(String projectId) async {
 if (projectId.trim().isEmpty) return;
 _setStateWhenSafe(() => _workflowLoading = true);

 try {
 // Retry up to 3 times to guard against transient Firestore
 // "INTERNAL ASSERTION FAILED" errors in SDK 12.x.
 QuerySnapshot<Map<String, dynamic>>? snapshot;
 for (var attempt = 1; attempt <= 3; attempt++) {
 try {
 snapshot = await _workflowCollection(projectId).get();
 break;
 } catch (e) {
 final isAssertionError = e.toString().contains('INTERNAL ASSERTION') ||
 e.toString().contains('Unexpected state');
 if (!isAssertionError || attempt == 3) rethrow;
 await Future<void>.delayed(Duration(milliseconds: 500 * (1 << (attempt - 1))));
 }
 }

 var global = _cloneWorkflowSteps(_defaultProcurementWorkflowTemplate);
 final overrides = <String, List<_ProcurementWorkflowStep>>{};

 for (final doc in snapshot!.docs) {
 final data = doc.data();
 final scopeIdFromDoc = (data['scopeId'] ?? '').toString().trim();
 final normalizedScope = scopeIdFromDoc.isNotEmpty
 ? scopeIdFromDoc
 : (doc.id == _workflowGlobalDocId
 ? 'all'
 : doc.id.replaceFirst('scope_', '').trim());
 final steps = _parseWorkflowSteps(data['steps']);

 if (normalizedScope == 'all') {
 if (steps.isNotEmpty) {
 global = steps;
 }
 continue;
 }

 if (normalizedScope.isNotEmpty) {
 overrides[normalizedScope] = steps;
 }
 }

 if (!mounted) return;
 _setStateWhenSafe(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(global);
 _scopeWorkflowOverrides = overrides;
 if (_customizeWorkflowByScope) {
 _selectedWorkflowScopeId = _resolveWorkflowScopeId();
 _hydrateWorkflowDraftForSelection();
 } else {
 _selectedWorkflowScopeId = null;
 _workflowDraftSteps = _cloneWorkflowSteps(global);
 }
 _syncWorkflowStateWithScopes();
 });
 } catch (e) {
 if (!mounted) return;
 final msg = e.toString().contains('INTERNAL ASSERTION')
 ? 'Network glitch while loading workflow — please refresh the page.'
 : 'Unable to load procurement workflow. Please try again.';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(msg)),
 );
 } finally {
 _setStateWhenSafe(() => _workflowLoading = false);
 }
 }

 Future<void> _persistProcurementWorkflowData({
 required String successMessage,
 }) async {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) return;
 _setStateWhenSafe(() => _workflowSaving = true);

 try {
 final collection = _workflowCollection(projectId);
 final existingSnapshot = await collection.get();
 final existingDocIds = existingSnapshot.docs.map((doc) => doc.id).toSet();
 final batch = FirebaseFirestore.instance.batch();

 final desiredPayloads = <String, Map<String, dynamic>>{
 _workflowGlobalDocId: {
 'scopeId': 'all',
 'steps': _globalWorkflowSteps.map((step) => step.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 },
 };

 for (final entry in _scopeWorkflowOverrides.entries) {
 final scopeId = entry.key.trim();
 if (scopeId.isEmpty) continue;
 desiredPayloads[_scopeDocId(scopeId)] = {
 'scopeId': scopeId,
 'steps': entry.value.map((step) => step.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 };
 }

 for (final entry in desiredPayloads.entries) {
 batch.set(
 collection.doc(entry.key),
 entry.value,
 SetOptions(merge: true),
 );
 }

 for (final docId in existingDocIds) {
 if (!desiredPayloads.containsKey(docId)) {
 batch.delete(collection.doc(docId));
 }
 }

 await batch.commit();
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
 _setStateWhenSafe(() => _workflowSaving = false);
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
 if (value.isEmpty) return true;
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

 int _totalWorkflowDurationInWeeks(List<_ProcurementWorkflowStep> steps) {
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
 _workflowDraftSteps = <_ProcurementWorkflowStep>[];
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
 _scopeWorkflowOverrides
 .removeWhere((scopeId, _) => !validScopeIds.contains(scopeId));

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

 Future<_ProcurementWorkflowStep?> _showWorkflowStepDialog({
 _ProcurementWorkflowStep? initialStep,
 }) async {
 final nameController = TextEditingController(text: initialStep?.name ?? '');
 final durationController = TextEditingController(
 text: (initialStep?.duration ?? 1).toString(),
 );
 var unit = initialStep?.unit == 'month' ? 'month' : 'week';

 final result = await showDialog<_ProcurementWorkflowStep>(
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
 value: 'month', child: Text('Month')),
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
 _ProcurementWorkflowStep(
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

 Future<void> _editWorkflowStep(_ProcurementWorkflowStep step) async {
 final result = await _showWorkflowStepDialog(initialStep: step);
 if (result == null) return;

 setState(() {
 final next = List<_ProcurementWorkflowStep>.from(_workflowDraftSteps);
 final index = next.indexWhere((entry) => entry.id == step.id);
 if (index == -1) return;
 next[index] = result.copyWith(id: step.id);
 _workflowDraftSteps = next;
 });
 }

 void _deleteWorkflowStepFromDraft(String stepId) {
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
 final next = List<_ProcurementWorkflowStep>.from(_workflowDraftSteps);
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
 _scopeWorkflowOverrides[scopeId] =
 _cloneWorkflowSteps(_workflowDraftSteps);
 });
 } else {
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(_workflowDraftSteps);
 _scopeWorkflowOverrides = {};
 });
 }
 unawaited(
 _persistProcurementWorkflowData(
 successMessage: _customizeWorkflowByScope
 ? 'Saved workflow for selected scope.'
 : 'Saved global procurement workflow.',
 ),
 );
 }

 void _applyWorkflowDraftToAllScopes() {
 if (_workflowSaving) return;
 final normalized = _cloneWorkflowSteps(_workflowDraftSteps);
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(normalized);
 final next = <String, List<_ProcurementWorkflowStep>>{};
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
 unawaited(
 _persistProcurementWorkflowData(
 successMessage: 'Applied workflow to all scopes requiring bidding.',
 ),
 );
 }

 Map<String, String> get _itemNumberById {
 final mapping = <String, String>{};
 for (var i = 0; i < _items.length; i++) {
 final itemId = _items[i].id.trim();
 if (itemId.isEmpty) continue;
 mapping[itemId] = 'ITM-${(i + 1).toString().padLeft(3, '0')}';
 }
 return mapping;
 }

 bool _isTabAccessible(_ProcurementTab tab) {
 if (tab == _ProcurementTab.reports) {
 return _hasCommencedContractingActivities;
 }
 return true;
 }

 String _tabAccessMessage(_ProcurementTab tab) {
 if (tab == _ProcurementTab.reports) {
 return 'Reports unlock after a scope process is started.';
 }
 return 'This section is not accessible at this stage.';
 }

 Set<_ProcurementTab> get _tabsWithRestrictedAccess {
 final restricted = <_ProcurementTab>{};
 if (!_hasCommencedContractingActivities) {
 restricted.add(_ProcurementTab.reports);
 }
 return restricted;
 }

 void _scheduleProjectBootstrap() {
 final data = ProjectDataHelper.getData(context);
 final projectId = (data.projectId ?? '').trim();
 if (projectId.isEmpty) return;
 if (_activeProjectId == projectId) return;
 if (_scheduledProjectBootstrapId == projectId) return;

 _scheduledProjectBootstrapId = projectId;
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final scheduledProjectId = _scheduledProjectBootstrapId;
 _scheduledProjectBootstrapId = null;
 if (!mounted || scheduledProjectId == null) return;

 final latestData = ProjectDataHelper.getData(context);
 final latestProjectId = (latestData.projectId ?? '').trim();
 if (latestProjectId != scheduledProjectId) {
 if (latestProjectId.isNotEmpty && _activeProjectId != latestProjectId) {
 _scheduleProjectBootstrap();
 }
 return;
 }

 unawaited(_loadAssignableMembers(latestData));
 _subscribeToStreams(scheduledProjectId);
 unawaited(_loadProcurementWorkflowData(scheduledProjectId));
 _triggerAutoGenerationForProject(scheduledProjectId);

 if (_isPlanningMode) {
 await _seedFromInitiationIfNeeded(scheduledProjectId, latestData);
 }
 });
 }

 @override
 void initState() {
 super.initState();
 _openAi = OpenAiServiceSecure();
 ApiKeyManager.initializeApiKey();
 _scheduleProjectBootstrap();
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Procurement',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
@override
 void didChangeDependencies() {
 super.didChangeDependencies();
 _scheduleProjectBootstrap();
 }

 Future<void> _loadAssignableMembers(ProjectDataModel data) async {
 final merged = <ProcurementAssignableMemberOption>[];
 final seen = <String>{};

 void addMember({
 required String id,
 required String name,
 required String email,
 required String role,
 required String source,
 }) {
 final normalizedEmail = email.trim().toLowerCase();
 final normalizedName = name.trim().toLowerCase();
 final normalizedId = id.trim().toLowerCase();
 final key = normalizedEmail.isNotEmpty
 ? 'email:$normalizedEmail'
 : (normalizedId.isNotEmpty
 ? 'id:$normalizedId'
 : 'name:$normalizedName');
 if (key.trim().isEmpty || seen.contains(key)) return;
 seen.add(key);
 merged.add(
 ProcurementAssignableMemberOption(
 id: id.trim(),
 name: name.trim(),
 email: email.trim(),
 role: role.trim(),
 source: source,
 ),
 );
 }

 for (final member in data.teamMembers) {
 if (member.name.trim().isEmpty && member.email.trim().isEmpty) continue;
 addMember(
 id: member.id,
 name: member.name,
 email: member.email,
 role: member.role,
 source: 'Project Team',
 );
 }

 try {
 final users = await UserService.searchUsers('');
 for (final user in users) {
 if (user.displayName.trim().isEmpty && user.email.trim().isEmpty) {
 continue;
 }
 addMember(
 id: user.uid,
 name: user.displayName,
 email: user.email,
 role: user.isAdmin ? 'Admin' : 'Member',
 source: 'Company Members',
 );
 }
 } catch (e) {
 debugPrint('Failed loading company members for procurement: $e');
 }

 merged.sort((a, b) {
 final sourceWeight =
 a.source == b.source ? 0 : (a.source == 'Project Team' ? -1 : 1);
 if (sourceWeight != 0) return sourceWeight;
 return a.displayLabel
 .toLowerCase()
 .compareTo(b.displayLabel.toLowerCase());
 });

 if (!mounted) return;
 setState(() => _assignableMembers = merged);
 }

 double _textSimilarity(String a, String b) {
 if (a.isEmpty || b.isEmpty) return 0;
 final tokensA = a
 .split(RegExp(r'[^a-z0-9]+'))
 .where((token) => token.isNotEmpty)
 .toSet();
 final tokensB = b
 .split(RegExp(r'[^a-z0-9]+'))
 .where((token) => token.isNotEmpty)
 .toSet();
 if (tokensA.isEmpty || tokensB.isEmpty) return 0;
 final union = tokensA.union(tokensB).length.toDouble();
 if (union == 0) return 0;
 final overlap = tokensA.intersection(tokensB).length.toDouble();
 return overlap / union;
 }

 ProcurementAssignableMemberOption? _matchAssignableMemberByRole(
 String rawRole) {
 final role = rawRole.trim().toLowerCase();
 if (role.isEmpty) return null;
 for (final member in _assignableMembers) {
 final memberRole = member.role.trim().toLowerCase();
 if (memberRole.isEmpty) continue;
 if (memberRole == role ||
 memberRole.contains(role) ||
 role.contains(memberRole)) {
 return member;
 }
 }
 return null;
 }

 String _resolveResponsibleSelection(String rawValue, {String roleHint = ''}) {
 final value = rawValue.trim();
 if (value.isEmpty) {
 return _matchAssignableMemberByRole(roleHint)?.displayLabel ?? '';
 }

 final normalized = value.toLowerCase();
 ProcurementAssignableMemberOption? exactMatch;
 ProcurementAssignableMemberOption? fuzzyMatch;
 var bestScore = 0.0;
 for (final member in _assignableMembers) {
 final label = member.displayLabel.toLowerCase();
 final email = member.email.toLowerCase();
 if (label == normalized || email == normalized) {
 exactMatch = member;
 break;
 }
 if (label.contains(normalized) ||
 normalized.contains(label) ||
 (email.isNotEmpty &&
 (email.contains(normalized) || normalized.contains(email)))) {
 fuzzyMatch = member;
 bestScore = 1.0;
 continue;
 }
 final score = _textSimilarity(normalized, label);
 if (score > bestScore) {
 bestScore = score;
 fuzzyMatch = member;
 }
 }

 if (exactMatch != null) return exactMatch.displayLabel;
 if (fuzzyMatch != null && bestScore >= 0.5) return fuzzyMatch.displayLabel;
 final roleMatch = _matchAssignableMemberByRole(roleHint);
 if (roleMatch != null) return roleMatch.displayLabel;
 return value;
 }

 void _cancelSubscriptions() {
 _itemsSub?.cancel();
 _strategiesSub?.cancel();
 _vendorsSub?.cancel();
 _rfqsSub?.cancel();
 _purchaseOrdersSub?.cancel();
 }

 void _setStateWhenSafe(VoidCallback update) {
 if (!mounted) return;
 final phase = SchedulerBinding.instance.schedulerPhase;
 if (phase == SchedulerPhase.persistentCallbacks ||
 phase == SchedulerPhase.midFrameMicrotasks) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 setState(update);
 });
 return;
 }
 setState(update);
 }

 String _describeStreamError(Object error) {
 if (error is FirebaseException) {
 final message = (error.message ?? '').trim();
 if (message.isEmpty) return '[${error.code}]';
 return '[${error.code}] $message';
 }
 return error.toString();
 }

 void _subscribeToStreams(String projectId) {
 _cancelSubscriptions();
 _activeProjectId = projectId;

 _itemsSub =
 ProcurementService.streamItems(projectId, limit: _itemsLimit).listen(
 (data) {
 if (!mounted) return;
 _setStateWhenSafe(() {
 _items = data;
 _streamError = null;
 _recomputeDerivedProcurementData();
 _syncWorkflowStateWithScopes();
 });
 _clearResolvedValidationErrors();
 unawaited(_autoAssignVendorsToItemsIfMissing());
 },
 onError: (error) {
 if (!mounted) return;
 final details = _describeStreamError(error);
 _setStateWhenSafe(
 () => _streamError = 'Unable to load procurement items: $details');
 debugPrint('Procurement items stream error: $error');
 },
 );

 _strategiesSub = ProcurementService.streamStrategies(
 projectId,
 limit: _strategiesLimit,
 ).listen(
 (data) {
 if (!mounted) return;
 _setStateWhenSafe(() {
 _strategies = data;
 _streamError = null;
 _recomputeDerivedProcurementData();
 });
 _clearResolvedValidationErrors();
 if (data.isEmpty &&
 !_isGeneratingData &&
 _autoSeededStrategiesProjectId != projectId) {
 _autoSeededStrategiesProjectId = projectId;
 unawaited(_seedStrategies(projectId));
 }
 },
 onError: (error) {
 if (!mounted) return;
 final details = _describeStreamError(error);
 _setStateWhenSafe(() =>
 _streamError = 'Unable to load procurement strategies: $details');
 debugPrint('Procurement strategies stream error: $error');
 },
 );

 _vendorsSub = VendorService.streamVendors(
 projectId,
 limit: _vendorsLimit,
 ).listen(
 (data) {
 if (!mounted) return;
 _setStateWhenSafe(() {
 _vendors = data;
 _streamError = null;
 _recomputeDerivedProcurementData();
 });
 _clearResolvedValidationErrors();
 unawaited(_autoAssignVendorsToItemsIfMissing());
 },
 onError: (error) {
 if (!mounted) return;
 final details = _describeStreamError(error);
 _setStateWhenSafe(
 () => _streamError = 'Unable to load vendors: $details');
 debugPrint('Vendors stream error: $error');
 },
 );

 _rfqsSub = ProcurementService.streamRfqs(
 projectId,
 limit: _rfqsLimit,
 ).listen(
 (data) {
 if (!mounted) return;
 _setStateWhenSafe(() {
 _rfqs = data;
 _streamError = null;
 _recomputeDerivedProcurementData();
 });
 _clearResolvedValidationErrors();
 },
 onError: (error) {
 if (!mounted) return;
 final details = _describeStreamError(error);
 _setStateWhenSafe(() => _streamError = 'Unable to load RFQs: $details');
 debugPrint('RFQ stream error: $error');
 },
 );

 _purchaseOrdersSub = ProcurementService.streamPos(
 projectId,
 limit: _purchaseOrdersLimit,
 ).listen(
 (data) {
 if (!mounted) return;
 _setStateWhenSafe(() {
 _purchaseOrders = data;
 _streamError = null;
 _recomputeDerivedProcurementData();
 });
 _clearResolvedValidationErrors();
 },
 onError: (error) {
 if (!mounted) return;
 final details = _describeStreamError(error);
 _setStateWhenSafe(
 () => _streamError = 'Unable to load purchase orders: $details');
 debugPrint('Purchase orders stream error: $error');
 },
 );
 }

 void _refreshSubscriptionsForActiveProject() {
 final projectId = _activeProjectId;
 if (projectId == null || projectId.isEmpty) return;
 _subscribeToStreams(projectId);
 }

 String _resolveProjectId() {
 final dataProjectId = ProjectDataHelper.getData(context).projectId ?? '';
 final projectId = (_activeProjectId ?? dataProjectId).trim();
 return projectId;
 }

 int _categoryMatchScore(String itemCategory, String vendorCategory) {
 final item = itemCategory.trim().toLowerCase();
 final vendor = vendorCategory.trim().toLowerCase();
 if (item.isEmpty || vendor.isEmpty) return 0;
 if (item == vendor) return 100;
 if (item.contains(vendor) || vendor.contains(item)) return 70;

 final itemTokens = item
 .split(RegExp(r'[^a-z0-9]+'))
 .where((token) => token.isNotEmpty)
 .toSet();
 final vendorTokens = vendor
 .split(RegExp(r'[^a-z0-9]+'))
 .where((token) => token.isNotEmpty)
 .toSet();
 if (itemTokens.isEmpty || vendorTokens.isEmpty) return 0;
 final overlap = itemTokens.intersection(vendorTokens).length;
 return overlap * 15;
 }

 VendorModel? _bestVendorForItem(ProcurementItemModel item) {
 if (_vendors.isEmpty) return null;
 VendorModel? best;
 var bestScore = -1;
 for (final vendor in _vendors) {
 var score = _categoryMatchScore(item.category, vendor.category);
 if (vendor.isApproved) score += 8;
 if (vendor.isPreferred) score += 5;
 if (score > bestScore) {
 best = vendor;
 bestScore = score;
 }
 }
 return best ?? _vendors.first;
 }

 Future<void> _autoAssignVendorsToItemsIfMissing() async {
 if (_isAutoAssigningVendors) return;
 if (_items.isEmpty || _vendors.isEmpty) return;

 final projectId = _resolveProjectId();
 if (projectId.isEmpty) return;

 final targets = _items
 .where((item) => (item.vendorId ?? '').trim().isEmpty)
 .toList(growable: false);
 if (targets.isEmpty) return;

 _isAutoAssigningVendors = true;
 try {
 for (final item in targets) {
 final vendor = _bestVendorForItem(item);
 if (vendor == null || vendor.id.trim().isEmpty) continue;
 await ProcurementService.updateItem(projectId, item.id, {
 'vendorId': vendor.id,
 });
 }
 } catch (e) {
 debugPrint('Auto vendor assignment failed: $e');
 } finally {
 _isAutoAssigningVendors = false;
 }
 }

 Future<void> _ensurePurchaseOrdersSeeded({bool silent = true}) async {
 if (_isEnsuringPurchaseOrders) return;
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) return;

 _isEnsuringPurchaseOrders = true;
 try {
 final hasPos = await ProcurementService.hasAnyPos(projectId).timeout(
 const Duration(seconds: 6),
 onTimeout: () => _purchaseOrders.isNotEmpty,
 );
 if (!hasPos && _purchaseOrders.isEmpty) {
 if (!mounted) return;
 final data = ProjectDataHelper.getData(context);
 final projectName =
 data.projectName.trim().isEmpty ? 'Project' : data.projectName;
 final solutionTitle =
 data.solutionTitle.trim().isEmpty ? 'Solution' : data.solutionTitle;
 await _seedPurchaseOrders(
 projectId,
 projectName,
 solutionTitle,
 _buildProcurementAiContext(data),
 );
 _refreshSubscriptionsForActiveProject();
 if (!silent && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Purchase orders generated successfully.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
 }

 await _autoAssignVendorsToItemsIfMissing();
 } catch (e) {
 debugPrint('Failed ensuring purchase orders: $e');
 if (!silent && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to prepare purchase orders: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 } finally {
 _isEnsuringPurchaseOrders = false;
 }
 }

 void _recomputeDerivedProcurementData() {
 _trackableItems
 ..clear()
 ..addAll(_items);

 if (_trackableItems.isEmpty) {
 _selectedTrackableIndex = 0;
 } else if (_selectedTrackableIndex >= _trackableItems.length) {
 _selectedTrackableIndex = _trackableItems.length - 1;
 }

 final now = DateTime.now();
 final dateLabel = DateFormat('MMM d, yyyy');

 _trackingAlerts.clear();
 final activeItems = _items
 .where((item) =>
 item.estimatedDelivery != null &&
 item.status != ProcurementItemStatus.delivered &&
 item.status != ProcurementItemStatus.cancelled)
 .toList()
 ..sort((a, b) =>
 (a.estimatedDelivery ?? now).compareTo(b.estimatedDelivery ?? now));

 for (final item in activeItems.take(6)) {
 final due = item.estimatedDelivery ?? now;
 final daysRemaining = due.difference(now).inDays;
 final severity = daysRemaining < 0
 ? _AlertSeverity.high
 : (daysRemaining <= 7 ? _AlertSeverity.medium : _AlertSeverity.low);
 final title = daysRemaining < 0
 ? '${item.name} is overdue'
 : '${item.name} delivery due soon';
 final description = daysRemaining < 0
 ? 'Expected ${dateLabel.format(due)} and still not delivered.'
 : 'Expected ${dateLabel.format(due)} ($daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining).';
 _trackingAlerts.add(
 _TrackingAlert(
 title: title,
 description: description,
 severity: severity,
 date: now.toIso8601String(),
 ),
 );
 }

 _carrierPerformance.clear();
 if (_purchaseOrders.isNotEmpty) {
 final byVendor = <String, List<PurchaseOrderModel>>{};
 for (final order in _purchaseOrders) {
 final key = order.vendorName.trim().isEmpty
 ? 'Unassigned Vendor'
 : order.vendorName.trim();
 byVendor.putIfAbsent(key, () => <PurchaseOrderModel>[]).add(order);
 }

 final vendorGroups = byVendor.entries.toList()
 ..sort((a, b) => b.value.length.compareTo(a.value.length));
 for (final group in vendorGroups.take(4)) {
 final orders = group.value;
 final total = orders.length;
 final delivered = orders
 .where((order) => order.status == PurchaseOrderStatus.received)
 .length;
 final onTimeRate = total == 0 ? 0 : ((delivered / total) * 100).round();
 final totalDays = orders.fold<int>(
 0,
 (total, order) {
 final days =
 order.expectedDate.difference(order.orderedDate).inDays;
 return total + (days < 1 ? 1 : days);
 },
 );
 final averageDays = total == 0 ? 0 : (totalDays / total).round();

 _carrierPerformance.add(
 _CarrierPerformance(
 carrier: group.key,
 onTimeRate: onTimeRate.clamp(0, 100),
 avgDays: averageDays,
 ),
 );
 }
 }

 final totalBudget =
 _items.fold<double>(0, (total, item) => total + item.budget);
 final totalSpend =
 _purchaseOrders.fold<double>(0, (total, order) => total + order.amount);
 final openOrders = _purchaseOrders
 .where((order) =>
 order.status != PurchaseOrderStatus.received &&
 order.status != PurchaseOrderStatus.cancelled)
 .length;
 final awaitingApprovals = _purchaseOrders
 .where((order) => order.status == PurchaseOrderStatus.awaitingApproval)
 .length;
 final budgetUtilization =
 totalBudget <= 0 ? 0.0 : (totalSpend / totalBudget).clamp(0.0, 5.0);

 final deliveredItems =
 _items.where((item) => item.status == ProcurementItemStatus.delivered);
 final deliveredCount = deliveredItems.length;
 final onTimeDeliveries = deliveredItems.where((item) {
 if (item.estimatedDelivery == null || item.actualDelivery == null) {
 return false;
 }
 return !item.actualDelivery!.isAfter(item.estimatedDelivery!);
 }).length;
 final onTimeRate =
 deliveredCount == 0 ? 0.0 : (onTimeDeliveries / deliveredCount);

 final leadDaySamples =
 _items.where((item) => item.estimatedDelivery != null).map((item) {
 final days = item.estimatedDelivery!.difference(item.createdAt).inDays;
 return days < 1 ? 1 : days;
 }).toList();
 final averageLeadDays = leadDaySamples.isEmpty
 ? 0
 : (leadDaySamples.reduce((a, b) => a + b) / leadDaySamples.length)
 .round();

 _reportKpis
 ..clear()
 ..addAll([
 _ReportKpi(
 label: 'Total Spend',
 value: _currencyFormat.format(totalSpend),
 delta: 'Budget utilization ${(budgetUtilization * 100).round()}%',
 positive: budgetUtilization <= 1.0,
 ),
 _ReportKpi(
 label: 'Open Orders',
 value: '$openOrders',
 delta: '$awaitingApprovals awaiting approval',
 positive: awaitingApprovals <= (openOrders == 0 ? 1 : openOrders),
 ),
 _ReportKpi(
 label: 'Avg Lead Time',
 value: averageLeadDays == 0 ? 'N/A' : '$averageLeadDays days',
 delta:
 '${_items.length} tracked item${_items.length == 1 ? '' : 's'}',
 positive: averageLeadDays <= 45 || averageLeadDays == 0,
 ),
 _ReportKpi(
 label: 'On-time Delivery',
 value: '${(onTimeRate * 100).round()}%',
 delta:
 '$deliveredCount delivered item${deliveredCount == 1 ? '' : 's'}',
 positive: onTimeRate >= 0.8 || deliveredCount == 0,
 ),
 ]);

 _spendBreakdown.clear();
 final categoryTotals = <String, double>{};
 if (_purchaseOrders.isNotEmpty) {
 for (final order in _purchaseOrders) {
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
 const Color(0xFF2563EB),
 const Color(0xFF10B981),
 const Color(0xFFF59E0B),
 const Color(0xFF6D28D9),
 const Color(0xFFEF4444),
 ];
 final categoryEntries = categoryTotals.entries.toList()
 ..sort((a, b) => b.value.compareTo(a.value));
 final totalCategories =
 categoryEntries.fold<double>(0, (total, entry) => total + entry.value);
 for (var i = 0; i < categoryEntries.length && i < palette.length; i++) {
 final entry = categoryEntries[i];
 _spendBreakdown.add(
 _SpendBreakdown(
 label: entry.key,
 amount: entry.value.round(),
 percent: totalCategories == 0
 ? 0
 : (entry.value / totalCategories).clamp(0.0, 1.0),
 color: palette[i],
 ),
 );
 }

 _leadTimeMetrics.clear();
 final categories = _items.map((item) => item.category.trim()).toSet()
 ..removeWhere((value) => value.isEmpty);
 for (final category in categories.take(4)) {
 final categoryItems =
 _items.where((item) => item.category.trim() == category).toList();
 if (categoryItems.isEmpty) continue;
 final deliveredCategory = categoryItems
 .where((item) => item.status == ProcurementItemStatus.delivered)
 .length;
 final onTime = categoryItems
 .where((item) =>
 item.status == ProcurementItemStatus.delivered &&
 item.actualDelivery != null &&
 item.estimatedDelivery != null &&
 !item.actualDelivery!.isAfter(item.estimatedDelivery!))
 .length;
 final rate = deliveredCategory == 0
 ? 0.0
 : (onTime / deliveredCategory).clamp(0.0, 1.0);
 _leadTimeMetrics.add(_LeadTimeMetric(label: category, onTimeRate: rate));
 }

 _savingsOpportunities.clear();
 final totalRfqBudget =
 _rfqs.fold<double>(0, (total, rfq) => total + rfq.budget);
 if (totalRfqBudget > 0) {
 _savingsOpportunities.add(
 _SavingsOpportunity(
 title: 'Competitive RFQ consolidation',
 value: _currencyFormat.format(totalRfqBudget * 0.08),
 owner: 'Sourcing Lead',
 ),
 );
 }
 if (_vendors.length > 2) {
 _savingsOpportunities.add(
 _SavingsOpportunity(
 title: 'Preferred vendor renegotiation',
 value: _currencyFormat.format(totalSpend * 0.04),
 owner: 'Procurement Manager',
 ),
 );
 }
 if (_savingsOpportunities.isEmpty && totalSpend > 0) {
 _savingsOpportunities.add(
 _SavingsOpportunity(
 title: 'Spend optimization review',
 value: _currencyFormat.format(totalSpend * 0.03),
 owner: 'Finance Partner',
 ),
 );
 }

 _complianceMetrics
 ..clear()
 ..addAll([
 _ComplianceMetric(
 label: 'PO ownership',
 value: _purchaseOrders.isEmpty
 ? 0
 : (_purchaseOrders
 .where((order) => order.owner.trim().isNotEmpty)
 .length /
 _purchaseOrders.length)
 .clamp(0.0, 1.0),
 ),
 _ComplianceMetric(
 label: 'Items with delivery date',
 value: _items.isEmpty
 ? 0
 : (_items.where((item) => item.estimatedDelivery != null).length /
 _items.length)
 .clamp(0.0, 1.0),
 ),
 _ComplianceMetric(
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
 _ComplianceMetric(
 label: 'Active vendor coverage',
 value: _vendors.isEmpty
 ? 0
 : (_vendors.where((vendor) => vendor.isApproved).length /
 _vendors.length)
 .clamp(0.0, 1.0),
 ),
 ]);

 if (!_isTabAccessible(_selectedTab)) {
 _selectedTab = _ProcurementTab.procurementDashboard;
 }
 }

 void _triggerAutoGenerationForProject(String projectId) {
 if (projectId.isEmpty) return;
 if (_autoGenerationRequestedProjectId == projectId) return;

 _autoGenerationRequestedProjectId = projectId;
 Future<void>.delayed(const Duration(milliseconds: 350), () async {
 if (!mounted) return;
 await _generateProcurementDataIfNeeded(silent: true);
 });
 }

 void _loadMoreForTab(_ProcurementTab tab) {
 setState(() {
 switch (tab) {
 case _ProcurementTab.procurementDashboard:
 _strategiesLimit += _streamLimitStep;
 break;
 case _ProcurementTab.itemsList:
 _itemsLimit += _streamLimitStep;
 break;
 case _ProcurementTab.itemTracking:
 break;
 case _ProcurementTab.vendorManagement:
 _vendorsLimit += _streamLimitStep;
 break;
 case _ProcurementTab.rfqWorkflow:
 _rfqsLimit += _streamLimitStep;
 break;
 case _ProcurementTab.purchaseOrders:
 _purchaseOrdersLimit += _streamLimitStep;
 break;
 case _ProcurementTab.reports:
 if (_hasCommencedContractingActivities) {
 _itemsLimit += _streamLimitStep;
 }
 break;
 }
 });
 _refreshSubscriptionsForActiveProject();
 }

 Future<void> _regenerateAllProcurement() async {
 await _generateProcurementDataIfNeeded(showIfAlreadySeeded: true);
 }

 Future<void> _seedProcurementDataIfNeeded(
 String projectId,
 ProjectDataModel data, {
 required bool seedItems,
 required bool seedStrategies,
 required bool seedVendors,
 required bool seedRfqs,
 required bool seedPurchaseOrders,
 }) async {
 if (_isGeneratingData) return;

 setState(() => _isGeneratingData = true);

 try {
 final projectName =
 data.projectName.trim().isEmpty ? 'Project' : data.projectName.trim();
 final solutionTitle = data.solutionTitle.trim().isEmpty
 ? 'Solution'
 : data.solutionTitle.trim();
 final aiContext = _buildProcurementAiContext(data);

 if (seedItems) {
 await _seedItems(projectId, projectName, solutionTitle, data);
 }
 if (seedStrategies) {
 await _seedStrategies(projectId);
 }
 if (seedVendors) {
 await _seedVendors(projectId, projectName, solutionTitle, data);
 }
 if (seedRfqs) {
 await _seedRfqs(projectId, projectName, solutionTitle, aiContext);
 }
 if (seedPurchaseOrders) {
 await _seedPurchaseOrders(
 projectId, projectName, solutionTitle, aiContext);
 }
 // Trackable items are just items with status. No need to seed separately if items cover it.
 } catch (e) {
 debugPrint('Error seeding procurement data: $e');
 } finally {
 if (mounted) {
 setState(() => _isGeneratingData = false);
 }
 }
 }

 Future<void> _seedItems(String projectId, String projectName,
 String solutionTitle, ProjectDataModel data) async {
 final now = DateTime.now();
 final categories = _seedCategoriesFor(data);

 String roleHintForCategory(String category) {
 final normalized = category.trim().toLowerCase();
 if (normalized.contains('it') || normalized.contains('network')) {
 return 'IT Lead';
 }
 if (normalized.contains('construction') ||
 normalized.contains('material') ||
 normalized.contains('equipment')) {
 return 'Engineering';
 }
 if (normalized.contains('security')) return 'Security';
 if (normalized.contains('logistics')) return 'Operations';
 if (normalized.contains('service') || normalized.contains('consult')) {
 return 'Project Manager';
 }
 return 'Procurement';
 }

 try {
 // Try AI generation first
 final resultList = <ProcurementItemModel>[];
 try {
 for (int i = 0; i < categories.length; i++) {
 final category = categories[i];
 final contextNotes =
 _buildProcurementAiContext(data, focusCategory: category);
 final result = await _openAi.generateProcurementItemSuggestion(
 projectName: projectName,
 solutionTitle: solutionTitle,
 category: category,
 contextNotes: contextNotes,
 );

 final deliveryDays = (result['estimatedDeliveryDays'] as int?) ??
 _defaultLeadTimeDaysForCategory(category);
 final deliveryDate = DateTime.now().add(Duration(days: deliveryDays));

 ProcurementPriority priority;
 final priorityStr = (result['priority'] ?? 'medium').toString();
 switch (priorityStr.toLowerCase()) {
 case 'critical':
 priority = ProcurementPriority.critical;
 break;
 case 'high':
 priority = ProcurementPriority.high;
 break;
 case 'low':
 priority = ProcurementPriority.low;
 break;
 default:
 priority = ProcurementPriority.medium;
 }

 ProcurementItemStatus status;
 switch (i % 5) {
 case 0:
 status = ProcurementItemStatus.planning;
 break;
 case 1:
 status = ProcurementItemStatus.rfqReview;
 break;
 case 2:
 status = ProcurementItemStatus.vendorSelection;
 break;
 case 3:
 status = ProcurementItemStatus.ordered;
 break;
 default:
 status = ProcurementItemStatus.delivered;
 }

 final aiResponsible = (result['responsible'] ??
 result['responsibleMember'] ??
 result['owner'] ??
 result['person'] ??
 '')
 .toString()
 .trim();
 final aiRole = (result['role'] ??
 result['responsibleRole'] ??
 result['ownerRole'] ??
 roleHintForCategory(category))
 .toString()
 .trim();
 final resolvedResponsible = _resolveResponsibleSelection(
 aiResponsible,
 roleHint: aiRole,
 );

 final progress = [0.0, 0.25, 0.5, 0.75, 1.0][i % 5];

 // Create events based on status for tracking
 final events = <ProcurementEvent>[];
 if (status.index >= ProcurementItemStatus.ordered.index) {
 events.add(ProcurementEvent(
 title: 'Order Placed',
 description: 'Order confirmed with vendor',
 subtext: 'Ordered',
 date: now.subtract(const Duration(days: 10)),
 ));
 }
 if (status == ProcurementItemStatus.delivered) {
 events.add(ProcurementEvent(
 title: 'Delivered',
 description: 'Item received at site',
 subtext: 'Delivered',
 date: now,
 ));
 }

 resultList.add(ProcurementItemModel(
 id: '', // Service handles ID
 projectId: projectId,
 name: (result['name'] ?? '$category Procurement').toString(),
 description: (result['description'] ??
 'Procurement item for $category category')
 .toString(),
 category: category,
 status: status,
 priority: priority,
 budget: ((result['budget'] as int?) ?? (50000 + (i * 10000)))
 .toDouble(),
 estimatedDelivery: deliveryDate,
 progress: progress,
 responsibleMember: resolvedResponsible,
 createdAt: now,
 updatedAt: now,
 events: events,
 ));
 }
 } catch (e) {
 debugPrint('AI generation failed, using fallback: $e');
 // Fallback
 for (int i = 0; i < categories.length; i++) {
 resultList.add(ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: '${categories[i]} Procurement',
 description: 'Procurement item for ${categories[i]}',
 category: categories[i],
 status: ProcurementItemStatus.planning,
 priority: ProcurementPriority.medium,
 budget: (50000 + (i * 10000)).toDouble(),
 estimatedDelivery: now.add(
 Duration(days: _defaultLeadTimeDaysForCategory(categories[i])),
 ),
 progress: 0.0,
 responsibleMember: _resolveResponsibleSelection(
 '',
 roleHint: roleHintForCategory(categories[i]),
 ),
 createdAt: now,
 updatedAt: now,
 ));
 }
 }

 // Save to Firestore
 for (final item in resultList) {
 await ProcurementService.createItem(item);
 }
 } catch (e) {
 debugPrint('Error seeding items: $e');
 }
 }

 Future<void> _seedStrategies(String projectId) async {
 // Create default strategies
 final strategies = [
 ProcurementStrategyModel(
 id: '',
 projectId: projectId,
 title: 'IT Infrastructure Procurement',
 category: 'IT Infrastructure',
 status: StrategyStatus.active,
 itemCount: 1,
 description:
 'Strategic approach for acquiring IT infrastructure components and equipment.',
 createdAt: DateTime.now(),
 ),
 ProcurementStrategyModel(
 id: '',
 projectId: projectId,
 title: 'Construction & Facilities',
 category: 'Construction Services',
 status: StrategyStatus.active,
 itemCount: 1,
 description:
 'Procurement strategy for construction services and facility improvements.',
 createdAt: DateTime.now(),
 ),
 ProcurementStrategyModel(
 id: '',
 projectId: projectId,
 title: 'Office & Workspace',
 category: 'Office & Workspace',
 status: StrategyStatus.draft,
 itemCount: 1,
 description:
 'Strategy for furnishing and equipping office spaces and work areas.',
 createdAt: DateTime.now(),
 ),
 ];

 for (final s in strategies) {
 try {
 await ProcurementService.createStrategy(s);
 } catch (e) {
 debugPrint('Unable to seed strategy "${s.title}": $e');
 }
 }
 }

 Future<void> _seedVendors(String projectId, String projectName,
 String solutionTitle, ProjectDataModel data) async {
 try {
 final categories = _seedCategoriesFor(data);
 final vendors = await _openAi.generateProcurementVendors(
 projectName: projectName,
 solutionTitle: solutionTitle,
 contextNotes: _buildProcurementAiContext(data),
 count: categories.length.clamp(5, 8),
 preferredCategories: categories,
 );

 final list = <VendorModel>[];
 if (vendors.isNotEmpty) {
 for (final v in vendors) {
 final name = (v['name'] ?? '').toString().trim();
 final safeName = name.isEmpty ? 'Vendor ${list.length + 1}' : name;
 list.add(VendorModel(
 // Need full constructor
 id: '', // Service handles
 projectId: projectId,
 name: safeName,
 category: (v['category'] ?? 'IT Equipment').toString(),
 criticality: 'Medium',
 sla: '98%',
 rating: 'A', // Default to string A
 status: ((v['approved'] as bool? ?? true) ? 'Active' : 'Pending'),
 nextReview: DateFormat('MMM d, yyyy')
 .format(DateTime.now().add(const Duration(days: 180))),
 slaPerformance: 0.95,
 leadTime: '14 Days',
 requiredDeliverables: '• Quarterly review\n• SLA adherence',
 onTimeDelivery: 0.95,
 incidentResponse: 0.95,
 qualityScore: 0.95,
 costAdherence: 0.95,
 createdById: '',
 createdByEmail: '',
 createdByName: '',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 ));
 }
 } else {
 // Fallback
 list.add(VendorModel(
 id: '',
 projectId: projectId,
 name: 'TechCorp Solutions',
 category: 'IT Equipment',
 criticality: 'Medium',
 rating: 'A',
 status: 'Active',
 sla: '99%',
 nextReview: DateFormat('MMM d, yyyy')
 .format(DateTime.now().add(const Duration(days: 180))),
 slaPerformance: 0.98,
 leadTime: '14 Days',
 requiredDeliverables: '• Quarterly review\n• SLA adherence',
 onTimeDelivery: 1.0,
 incidentResponse: 1.0,
 qualityScore: 1.0,
 costAdherence: 1.0,
 createdById: '',
 createdByEmail: '',
 createdByName: '',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now()));
 }

 for (final v in list) {
 // Use createVendor which handles auth fields
 await VendorService.createVendor(
 projectId: projectId,
 name: v.name,
 category: v.category,
 criticality: v.criticality,
 rating: v.rating,
 status: v.status,
 sla: v.sla,
 slaPerformance: v.slaPerformance,
 leadTime: v.leadTime,
 requiredDeliverables: v.requiredDeliverables,
 nextReview: v.nextReview,
 onTimeDelivery: v.onTimeDelivery,
 incidentResponse: v.incidentResponse,
 qualityScore: v.qualityScore,
 costAdherence: v.costAdherence,
 createdById: 'system',
 createdByEmail: 'system@ndu.com',
 createdByName: 'System AI');
 }
 } catch (e) {
 debugPrint('Error seeding vendors: $e');
 }
 }

 Future<void> _seedRfqs(String projectId, String projectName,
 String solutionTitle, String notes) async {
 // Basic seeding
 try {
 final rfqs = <RfqModel>[
 RfqModel(
 id: '',
 projectId: projectId,
 title: 'Network Equip',
 category: 'IT',
 owner: 'Manager',
 dueDate: DateTime.now().add(const Duration(days: 30)),
 invitedCount: 5,
 responseCount: 3,
 budget: 50000,
 status: RfqStatus.inMarket,
 priority: ProcurementPriority.high,
 createdAt: DateTime.now())
 ];
 for (final r in rfqs) {
 await ProcurementService.createRfq(r);
 }
 } catch (e) {
 debugPrint('$e');
 }
 }

 Future<void> _seedPurchaseOrders(String projectId, String projectName,
 String solutionTitle, String notes) async {
 try {
 final now = DateTime.now();
 final aiGenerated = await _openAi.generateProcurementPurchaseOrders(
 projectName: projectName,
 solutionTitle: solutionTitle,
 contextNotes: notes,
 count: 4,
 );

 DateTime parseDate(dynamic rawValue, DateTime fallback) {
 if (rawValue is DateTime) return rawValue;
 if (rawValue is Timestamp) return rawValue.toDate();
 if (rawValue is String) {
 final trimmed = rawValue.trim();
 if (trimmed.isEmpty) return fallback;
 final parsedIso = DateTime.tryParse(trimmed);
 if (parsedIso != null) return parsedIso;
 try {
 return DateFormat('yyyy-MM-dd').parseStrict(trimmed);
 } catch (e) {
 return fallback;
 }
 }
 return fallback;
 }

 double parseAmount(dynamic rawValue, double fallback) {
 if (rawValue is num) return rawValue.toDouble();
 if (rawValue is String) {
 final cleaned = rawValue.replaceAll(RegExp(r'[^0-9.\-]'), '');
 return double.tryParse(cleaned) ?? fallback;
 }
 return fallback;
 }

 double parseProgress(dynamic rawValue, double fallback) {
 final parsed = parseAmount(rawValue, fallback);
 if (parsed.isNaN || !parsed.isFinite) return fallback;
 if (parsed > 1.0 && parsed <= 100.0) return (parsed / 100.0);
 if (parsed < 0.0) return 0.0;
 if (parsed > 1.0) return 1.0;
 return parsed;
 }

 PurchaseOrderStatus parseStatus(dynamic rawValue) {
 final normalized = (rawValue ?? '')
 .toString()
 .trim()
 .toLowerCase()
 .replaceAll(RegExp(r'[^a-z]'), '');
 switch (normalized) {
 case 'awaitingapproval':
 return PurchaseOrderStatus.awaitingApproval;
 case 'issued':
 return PurchaseOrderStatus.issued;
 case 'intransit':
 return PurchaseOrderStatus.inTransit;
 case 'received':
 return PurchaseOrderStatus.received;
 case 'cancelled':
 return PurchaseOrderStatus.cancelled;
 default:
 return PurchaseOrderStatus.draft;
 }
 }

 final pos = <PurchaseOrderModel>[];
 if (aiGenerated.isNotEmpty) {
 for (var i = 0; i < aiGenerated.length; i++) {
 final row = aiGenerated[i];
 final fallbackOrdered = now.subtract(Duration(days: i * 3));
 final orderedDate = parseDate(row['orderedDate'], fallbackOrdered);
 var expectedDate = parseDate(
 row['expectedDate'],
 orderedDate.add(const Duration(days: 14)),
 );
 if (expectedDate.isBefore(orderedDate)) {
 expectedDate = orderedDate.add(const Duration(days: 14));
 }

 final fallbackAmount = 20000.0 + (i * 15000.0);
 final amount =
 parseAmount(row['amount'], fallbackAmount).clamp(1000.0, 1e9);
 final progress = parseProgress(row['progress'], 0.25);
 final status = parseStatus(row['status']);
 final vendorName =
 (row['vendor'] ?? row['vendorName'] ?? '').toString().trim();
 final category = (row['category'] ?? '').toString().trim().isNotEmpty
 ? row['category'].toString().trim()
 : 'Services';
 final owner = (row['owner'] ?? '').toString().trim().isNotEmpty
 ? row['owner'].toString().trim()
 : 'Procurement Lead';
 final poNumber = (row['id'] ?? row['poNumber'] ?? '')
 .toString()
 .trim()
 .toUpperCase();
 final resolvedPoNumber =
 poNumber.isEmpty ? 'PO-${1001 + i}' : poNumber;

 pos.add(
 PurchaseOrderModel(
 id: '',
 poNumber: resolvedPoNumber,
 projectId: projectId,
 vendorName: vendorName.isEmpty ? 'Vendor ${i + 1}' : vendorName,
 category: category,
 owner: owner,
 orderedDate: orderedDate,
 expectedDate: expectedDate,
 amount: amount,
 progress: progress,
 createdAt: now,
 status: status,
 ),
 );
 }
 }

 if (pos.isEmpty) {
 pos.addAll([
 PurchaseOrderModel(
 id: '',
 poNumber: 'PO-1001',
 projectId: projectId,
 vendorName: 'TechCorp',
 category: 'IT',
 owner: 'Procurement Lead',
 orderedDate: now,
 expectedDate: now.add(const Duration(days: 10)),
 amount: 50000,
 progress: 0.65,
 createdAt: now,
 status: PurchaseOrderStatus.issued),
 PurchaseOrderModel(
 id: '',
 poNumber: 'PO-1002',
 projectId: projectId,
 vendorName: 'BuildRight Services',
 category: 'Construction Services',
 owner: 'Delivery Manager',
 orderedDate: now.subtract(const Duration(days: 5)),
 expectedDate: now.add(const Duration(days: 14)),
 amount: 82000,
 progress: 0.25,
 createdAt: now,
 status: PurchaseOrderStatus.awaitingApproval),
 PurchaseOrderModel(
 id: '',
 poNumber: 'PO-1003',
 projectId: projectId,
 vendorName: 'Office Source',
 category: 'Furniture',
 owner: 'Operations',
 orderedDate: now.subtract(const Duration(days: 16)),
 expectedDate: now.subtract(const Duration(days: 2)),
 amount: 24000,
 progress: 1.0,
 createdAt: now,
 status: PurchaseOrderStatus.received),
 ]);
 }

 for (final po in pos) {
 await ProcurementService.createPo(po);
 }
 } catch (e) {
 debugPrint('$e');
 }
 }

 // _generateTrackableItems removed as trackable items are derived from _items logic.

 @override
 void dispose() {
 _cancelSubscriptions();
 super.dispose();
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

 void _toggleVendorSelection(String vendorId, bool selected) {
 setState(() {
 if (selected) {
 _selectedVendorIds.add(vendorId);
 } else {
 _selectedVendorIds.remove(vendorId);
 }
 });
 _clearResolvedValidationErrors();
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
 content:
 Text('Enter a valid email address to send invite.'),
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
 content: Text('Invitation sent successfully.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
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
 barrierColor: Colors.black.withOpacity(0.45),
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

 if (result != null) {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Project not initialized. Unable to edit vendor.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 await VendorService.updateVendor(
 projectId: projectId,
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
 _refreshSubscriptionsForActiveProject();
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
 }

 void _removeVendor(String vendorId) async {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Project not initialized. Unable to remove vendor.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 await VendorService.deleteVendor(
 projectId: projectId, vendorId: vendorId);
 if (mounted) {
 setState(() {
 _vendors.removeWhere((vendor) => vendor.id == vendorId);
 _selectedVendorIds.remove(vendorId);
 _recomputeDerivedProcurementData();
 });
 }
 _refreshSubscriptionsForActiveProject();
 _clearResolvedValidationErrors();
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

 void _handleNotesChanged(String value) {
 if (_validationErrors.containsKey('procurement_notes')) {
 _clearResolvedValidationErrors();
 }
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 procurement: value,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: _checkpointId);
 }

 bool get _isPlanningMode => widget.mode == ProcurementScreenMode.planning;
 String get _checkpointId =>
 _isPlanningMode ? 'procurement' : 'fep_procurement';

 String _nextFlowDestinationLabel() {
 if (!_isPlanningMode) return 'Security';
 final rawLabel = PlanningPhaseNavigation.nextLabel('procurement').trim();
 if (rawLabel.startsWith('Next:')) {
 final parsed = rawLabel.substring('Next:'.length).trim();
 if (parsed.isNotEmpty && parsed.toLowerCase() != 'next') {
 return parsed;
 }
 }
 return 'the next planning step';
 }

 Future<void> _seedFromInitiationIfNeeded(
 String projectId, ProjectDataModel data) async {
 if (_isSeedingFromInitiation) return;
 final seededFlag =
 (data.planningNotes[_procurementSeededKey] ?? '').toString();
 if (seededFlag == 'true') return;

 final hasItems = await ProcurementService.hasAnyItems(projectId).timeout(
 const Duration(seconds: 6),
 onTimeout: () => true,
 );
 final hasVendors = await VendorService.streamVendors(projectId, limit: 1)
 .first
 .timeout(const Duration(seconds: 6), onTimeout: () => const []);
 if (hasItems || hasVendors.isNotEmpty) return;

 final contractors = data.contractors
 .where((c) => c.name.trim().isNotEmpty || c.service.trim().isNotEmpty)
 .toList();
 final vendors =
 data.vendors.where((v) => v.name.trim().isNotEmpty).toList();
 final allowances = data.frontEndPlanning.allowanceItems
 .where((a) => a.name.trim().isNotEmpty)
 .toList();
 final costItems =
 data.costEstimateItems.where((c) => c.title.trim().isNotEmpty).toList();

 if (contractors.isEmpty &&
 vendors.isEmpty &&
 allowances.isEmpty &&
 costItems.isEmpty) {
 return;
 }

 _isSeedingFromInitiation = true;
 try {
 final now = DateTime.now();
 final eta = now.add(const Duration(days: 60));

 for (final vendor in vendors) {
 await VendorService.createVendor(
 projectId: projectId,
 name: vendor.name.trim(),
 category: vendor.equipmentOrService.trim().isNotEmpty
 ? vendor.equipmentOrService.trim()
 : 'General',
 sla: '0%',
 rating: 'C',
 status: vendor.status.trim().isNotEmpty
 ? vendor.status.trim()
 : 'Onboard',
 nextReview: '',
 onTimeDelivery: 0.0,
 incidentResponse: 0.0,
 qualityScore: 0.0,
 costAdherence: 0.0,
 notes: vendor.notes.trim().isNotEmpty
 ? '${vendor.notes.trim()} (Imported from initiation vendors)'
 : 'Imported from initiation vendors',
 );
 }

 final items = <ProcurementItemModel>[];

 for (final contractor in contractors) {
 final name = contractor.name.trim().isNotEmpty
 ? contractor.name.trim()
 : 'Contracted Services';
 final service = contractor.service.trim();
 items.add(ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: name,
 description:
 service.isNotEmpty ? service : 'Imported contractor scope',
 category: 'Services',
 status: ProcurementItemStatus.planning,
 priority: ProcurementPriority.medium,
 budget: contractor.estimatedCost,
 estimatedDelivery: eta,
 createdAt: now,
 updatedAt: now,
 notes: contractor.notes.trim().isNotEmpty
 ? '${contractor.notes.trim()} (Imported from initiation contractors)'
 : 'Imported from initiation contractors',
 ));
 }

 for (final allowance in allowances) {
 items.add(ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: allowance.name.trim(),
 description: allowance.notes.trim().isNotEmpty
 ? allowance.notes.trim()
 : 'Imported allowance item',
 category: allowance.type.trim().isNotEmpty
 ? allowance.type.trim()
 : 'Allowance',
 status: ProcurementItemStatus.planning,
 priority: ProcurementPriority.low,
 budget: allowance.amount,
 estimatedDelivery: eta,
 createdAt: now,
 updatedAt: now,
 notes: 'Imported from initiation allowance items',
 ));
 }

 for (final cost in costItems) {
 items.add(ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: cost.title.trim(),
 description: cost.notes.trim().isNotEmpty
 ? cost.notes.trim()
 : 'Imported cost item',
 category:
 cost.costType.trim().isNotEmpty ? cost.costType.trim() : 'Cost',
 status: ProcurementItemStatus.planning,
 priority: cost.amount >= 100000
 ? ProcurementPriority.high
 : ProcurementPriority.medium,
 budget: cost.amount,
 estimatedDelivery: eta,
 createdAt: now,
 updatedAt: now,
 notes: 'Imported from initiation cost estimates',
 ));
 }

 for (final item in items) {
 await ProcurementService.createItem(item);
 }

 if (!mounted) return;
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: _checkpointId,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _procurementSeededKey: 'true',
 },
 ),
 showSnackbar: false,
 );
 } catch (e) {
 debugPrint('Failed to seed procurement from initiation: $e');
 } finally {
 if (mounted) {
 setState(() => _isSeedingFromInitiation = false);
 }
 }
 }

 Future<void> _generateProcurementDataIfNeeded(
 {bool showIfAlreadySeeded = false, bool silent = false}) async {
 final data = ProjectDataHelper.getData(context);
 final projectId = data.projectId ?? '';
 if (projectId.isEmpty) {
 if (!silent && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Unable to generate data.'),
 ),
 );
 }
 return;
 }

 final checks = await Future.wait<bool>([
 ProcurementService.hasAnyItems(projectId)
 .timeout(const Duration(seconds: 6), onTimeout: () => false)
 .catchError((_) => false),
 ProcurementService.hasAnyStrategies(projectId)
 .timeout(const Duration(seconds: 6), onTimeout: () => false)
 .catchError((_) => false),
 VendorService.hasAnyVendors(projectId)
 .timeout(const Duration(seconds: 6), onTimeout: () => false)
 .catchError((_) => false),
 ProcurementService.hasAnyRfqs(projectId)
 .timeout(const Duration(seconds: 6), onTimeout: () => false)
 .catchError((_) => false),
 ProcurementService.hasAnyPos(projectId)
 .timeout(const Duration(seconds: 6), onTimeout: () => false)
 .catchError((_) => false),
 ]);

 final hasItems = checks[0];
 final hasStrategies = checks[1];
 final hasVendors = checks[2];
 final hasRfqs = checks[3];
 final hasPos = checks[4];

 final needsItems = !hasItems || (showIfAlreadySeeded && _items.isEmpty);
 final needsStrategies =
 !hasStrategies || (showIfAlreadySeeded && _strategies.isEmpty);
 final needsVendors =
 !hasVendors || (showIfAlreadySeeded && _vendors.isEmpty);
 final needsRfqs = !hasRfqs || (showIfAlreadySeeded && _rfqs.isEmpty);
 final needsPos =
 !hasPos || (showIfAlreadySeeded && _purchaseOrders.isEmpty);

 final missingSections = <String>[
 if (needsItems) 'Items',
 if (needsStrategies) 'Strategies',
 if (needsVendors) 'Vendors',
 if (needsRfqs) 'RFQs',
 if (needsPos) 'Purchase Orders',
 ];

 if (missingSections.isEmpty) {
 if (showIfAlreadySeeded && !silent && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Starter procurement data already exists. Add/edit records directly.'),
 ),
 );
 }
 return;
 }

 if (needsItems && _assignableMembers.isEmpty) {
 await _loadAssignableMembers(data);
 }

 await _seedProcurementDataIfNeeded(
 projectId,
 data,
 seedItems: needsItems,
 seedStrategies: needsStrategies,
 seedVendors: needsVendors,
 seedRfqs: needsRfqs,
 seedPurchaseOrders: needsPos,
 );
 _refreshSubscriptionsForActiveProject();

 if (!silent && mounted) {
 final message = 'Generated missing procurement data: '
 '${missingSections.join(', ')}.';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(message),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 }
 }

 void _handleItemListTap() {
 setState(() => _selectedTab = _ProcurementTab.itemsList);
 }

 void _handleTabSelected(_ProcurementTab tab) {
 if (_selectedTab == tab) return;
 if (!_isTabAccessible(tab)) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(_tabAccessMessage(tab))),
 );
 }
 return;
 }
 setState(() => _selectedTab = tab);
 if (tab == _ProcurementTab.purchaseOrders) {
 unawaited(_ensurePurchaseOrdersSeeded(silent: false));
 }
 }

 void _handleTrackableSelected(int index) {
 if (_selectedTrackableIndex == index) return;
 setState(() => _selectedTrackableIndex = index);
 }

 String _currentProcurementNotes([ProjectDataModel? data]) {
 final source = data ?? ProjectDataHelper.getData(context);
 final aiNotes = source.planningNotes[_procurementNotesKey] ?? '';
 if (aiNotes.trim().isNotEmpty) {
 return aiNotes.trim();
 }
 return source.frontEndPlanning.procurement.trim();
 }

 String _projectTypeContext(ProjectDataModel data) {
 if (data.overallFramework?.trim().isNotEmpty == true) {
 return data.overallFramework!.trim();
 }
 if (data.solutionTitle.trim().isNotEmpty) {
 return data.solutionTitle.trim();
 }
 if (data.solutionDescription.trim().isNotEmpty) {
 return data.solutionDescription.trim();
 }
 return 'General project';
 }

 String _regionContext(ProjectDataModel data) {
 final regionBits = <String>[
 data.charterOrganizationalUnit.trim(),
 data.frontEndPlanning.infrastructure.trim(),
 data.notes.trim(),
 ].where((entry) => entry.isNotEmpty).toList();
 if (regionBits.isEmpty) return 'Region not explicitly specified';
 final merged = regionBits.join(' | ');
 return merged.length > 420 ? '${merged.substring(0, 417)}...' : merged;
 }

 String _scopeSignalContext(ProjectDataModel data) {
 final withinScope = data.withinScopeItems
 .map((item) => item.description.trim())
 .where((entry) => entry.isNotEmpty)
 .take(5)
 .toList();
 final milestones = data.keyMilestones
 .map((item) => item.name.trim())
 .where((entry) => entry.isNotEmpty)
 .take(4)
 .toList();
 final constraints = data.constraintItems
 .map((item) => item.description.trim())
 .where((entry) => entry.isNotEmpty)
 .take(4)
 .toList();

 return [
 if (withinScope.isNotEmpty) 'Within scope: ${withinScope.join('; ')}',
 if (milestones.isNotEmpty) 'Milestones: ${milestones.join('; ')}',
 if (constraints.isNotEmpty) 'Constraints: ${constraints.join('; ')}',
 ].join('\n');
 }

 String _buildProcurementAiContext(
 ProjectDataModel data, {
 String focusCategory = '',
 }) {
 final notes = _currentProcurementNotes(data);
 final scopeSignals = _scopeSignalContext(data);
 final focus = focusCategory.trim();
 final fullContext =
 ProjectDataHelper.buildFepContext(data, sectionLabel: 'Procurement');
 final contextScan = ProjectDataHelper.buildProjectContextScan(
 data,
 sectionLabel: 'Procurement',
 );

 return [
 if (focus.isNotEmpty) 'Focus category: $focus',
 'Project type: ${_projectTypeContext(data)}',
 'Region and local context: ${_regionContext(data)}',
 if (fullContext.isNotEmpty) fullContext,
 if (contextScan.isNotEmpty) contextScan,
 if (notes.isNotEmpty) 'Procurement notes: $notes',
 if (scopeSignals.isNotEmpty) scopeSignals,
 'Guidance: prioritize long-lead and schedule-critical items first.',
 'Guidance: tailor recommendations to local market constraints, practical availability, and project type.',
 'Guidance: suggest realistic procurement packages similar to successful projects of this type.',
 'Guidance: avoid generic or unrelated items.',
 ].join('\n');
 }

 List<String> _seedCategoriesFor(ProjectDataModel data) {
 final text = [
 _projectTypeContext(data).toLowerCase(),
 _currentProcurementNotes(data).toLowerCase(),
 data.solutionDescription.toLowerCase(),
 ].join(' ');

 final categories = <String>[
 // Prioritize long-lead categories by default.
 'Equipment',
 'Materials',
 'IT Equipment',
 'Construction Services',
 'Security',
 'Logistics',
 'Services',
 'Furniture',
 ];

 if (text.contains('software') ||
 text.contains('digital') ||
 text.contains('platform')) {
 categories.insert(0, 'IT Equipment');
 categories.insert(1, 'Security');
 categories.insert(2, 'Services');
 }

 if (text.contains('construction') ||
 text.contains('facility') ||
 text.contains('infrastructure')) {
 categories.insert(0, 'Construction Services');
 categories.insert(1, 'Materials');
 categories.insert(2, 'Logistics');
 }

 final unique = <String>[];
 for (final category in categories) {
 if (!unique.contains(category)) unique.add(category);
 if (unique.length >= 6) break;
 }
 return unique;
 }

 int _defaultLeadTimeDaysForCategory(String category) {
 final lower = category.trim().toLowerCase();
 if (lower.contains('equipment')) return 140;
 if (lower.contains('material')) return 120;
 if (lower.contains('construction')) return 110;
 if (lower.contains('logistics')) return 95;
 if (lower.contains('security')) return 90;
 if (lower.contains('furniture')) return 85;
 if (lower.contains('service')) return 75;
 return 90;
 }

 _ProcurementTab? _nextTab() {
 final tabs = _ProcurementTab.values;
 final index = tabs.indexOf(_selectedTab);
 if (index == -1 || index >= tabs.length - 1) return null;
 for (var i = index + 1; i < tabs.length; i++) {
 if (_isTabAccessible(tabs[i])) {
 return tabs[i];
 }
 }
 return null;
 }

 bool get _hasVendorSelection {
 if (_selectedVendorIds.isNotEmpty) return true;
 if (_vendors.isNotEmpty) return true;
 return _items.any((item) => (item.vendorId ?? '').trim().isNotEmpty);
 }

 _ProcurementTab? _tabForFieldId(String fieldId) {
 switch (fieldId) {
 case 'procurement_notes':
 return _ProcurementTab.procurementDashboard;
 case 'item_list':
 case 'project_budget':
 case 'expected_delivery_date':
 return _ProcurementTab.itemsList;
 case 'vendor_selection':
 return _ProcurementTab.vendorManagement;
 default:
 return null;
 }
 }

 List<String> _pendingIssueSummaries([Iterable<ValidationIssue>? issues]) {
 final source = issues ?? _pendingSecurityIssues;
 final summaries = <String>[];
 final seen = <String>{};
 for (final issue in source) {
 final tabLabel = _tabForFieldId(issue.id)?.label;
 final summary =
 tabLabel == null ? issue.label : '${issue.label} ($tabLabel)';
 if (seen.add(summary)) {
 summaries.add(summary);
 }
 }
 return summaries;
 }

 void _dismissPendingSecurityPrompt() {
 if (!_showPendingSecurityPrompt) return;
 setState(() {
 _showPendingSecurityPrompt = false;
 _pendingSecurityIssues = const <ValidationIssue>[];
 });
 }

 FormValidationResult _validateProcurementForNavigation() {
 return FormValidationEngine.validateForm([
 ValidationFieldRule(
 id: 'procurement_notes',
 label: 'Procurement Notes',
 section: 'Procurement Details',
 type: ValidationFieldType.text,
 value: _currentProcurementNotes(),
 fieldKey: _notesFieldKey,
 required: false,
 ),
 ValidationFieldRule(
 id: 'item_list',
 label: 'Scope Details',
 section: 'Procurement Details',
 type: ValidationFieldType.custom,
 value: _items,
 fieldKey: _itemsSectionKey,
 errorText: 'Add at least one procurement item',
 isMissing: (_) => _items.isEmpty,
 ),
 ValidationFieldRule(
 id: 'project_budget',
 label: 'Project Budget',
 section: 'Procurement Details',
 type: ValidationFieldType.custom,
 value: _items,
 fieldKey: _itemsSectionKey,
 isMissing: (_) => !_items.any((item) => item.budget > 0),
 ),
 ValidationFieldRule(
 id: 'expected_delivery_date',
 label: 'Expected Delivery Date',
 section: 'Procurement Details',
 type: ValidationFieldType.custom,
 value: _items,
 fieldKey: _itemsSectionKey,
 isMissing: (_) => !_items.any((item) => item.estimatedDelivery != null),
 ),
 ValidationFieldRule(
 id: 'vendor_selection',
 label: 'Vendor Selection',
 section: 'Procurement Details',
 type: ValidationFieldType.custom,
 value: _selectedVendorIds,
 fieldKey: _vendorSectionKey,
 isMissing: (_) => !_hasVendorSelection,
 ),
 ]);
 }

 String? _itemsSectionErrorText() {
 final missing = <String>[];
 if (_validationErrors.containsKey('item_list')) {
 missing.add('Scope Details');
 }
 if (_validationErrors.containsKey('project_budget')) {
 missing.add('Project Budget');
 }
 if (_validationErrors.containsKey('expected_delivery_date')) {
 missing.add('Expected Delivery Date');
 }
 if (missing.isEmpty) return null;
 return 'Complete required fields: ${missing.join(', ')}';
 }

 String? _vendorSectionErrorText() {
 if (!_validationErrors.containsKey('vendor_selection')) {
 return null;
 }
 return 'Select at least one vendor before continuing.';
 }

 // ignore: unused_element
 void _setValidationState(FormValidationResult validation) {
 final tabErrors = validation.issues
 .map((issue) => _tabForFieldId(issue.id))
 .whereType<_ProcurementTab>()
 .toSet();

 setState(() {
 _validationErrors = validation.errorByFieldId;
 _tabsWithErrors
 ..clear()
 ..addAll(tabErrors);
 });
 }

 void _clearResolvedValidationErrors() {
 if (_validationErrors.isEmpty && _tabsWithErrors.isEmpty) return;

 final next = Map<String, String>.from(_validationErrors);
 next.remove('procurement_notes');
 if (_items.isNotEmpty) {
 next.remove('item_list');
 }
 if (_items.any((item) => item.budget > 0)) {
 next.remove('project_budget');
 }
 if (_items.any((item) => item.estimatedDelivery != null)) {
 next.remove('expected_delivery_date');
 }
 if (_hasVendorSelection) {
 next.remove('vendor_selection');
 }

 final tabErrors =
 next.keys.map(_tabForFieldId).whereType<_ProcurementTab>().toSet();

 final promptValidation =
 _showPendingSecurityPrompt ? _validateProcurementForNavigation() : null;

 _setStateWhenSafe(() {
 _validationErrors = next;
 _tabsWithErrors
 ..clear()
 ..addAll(tabErrors);
 if (promptValidation != null) {
 _pendingSecurityIssues = promptValidation.issues;
 _showPendingSecurityPrompt = promptValidation.hasIssues;
 }
 });
 }

 Future<void> _focusFirstProcurementIssue(
 FormValidationResult validation) async {
 final issue = validation.firstIssue;
 if (issue == null) return;

 final targetTab = _tabForFieldId(issue.id);
 if (targetTab != null && targetTab != _selectedTab) {
 setState(() => _selectedTab = targetTab);
 await Future<void>.delayed(const Duration(milliseconds: 80));
 }

 await FormValidationEngine.scrollToFirstIssue(validation);
 }

 bool _hasValidationIssue(FormValidationResult validation, String fieldId) {
 return validation.issues.any((issue) => issue.id == fieldId);
 }

 Future<void> _syncValidationSourcesFromBackend() async {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) return;

 try {
 final latestItemsFuture =
 ProcurementService.streamItems(projectId, limit: _itemsLimit).first;
 final latestVendorsFuture =
 VendorService.streamVendors(projectId, limit: _vendorsLimit).first;
 final latestItems = await latestItemsFuture.timeout(
 const Duration(seconds: 8),
 onTimeout: () => _items,
 );
 final latestVendors = await latestVendorsFuture.timeout(
 const Duration(seconds: 8),
 onTimeout: () => _vendors,
 );
 if (!mounted) return;
 setState(() {
 _items = latestItems;
 _vendors = latestVendors;
 _recomputeDerivedProcurementData();
 });
 } catch (e) {
 debugPrint('Unable to sync procurement validation sources: $e');
 }
 }

 Future<_MissingProcurementAction?> _showMissingRequirementsDialog(
 FormValidationResult validation,
 ) {
 final summaries = _pendingIssueSummaries(validation.issues);
 final visible = summaries.take(6).toList(growable: false);
 final hiddenCount = summaries.length - visible.length;

 return showDialog<_MissingProcurementAction>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Row(
 children: [
 Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
 SizedBox(width: 10),
 Text('Procurement Requirements Missing'),
 ],
 ),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'You still have missing procurement details. You can add them now, auto-fill them, or continue and update later.',
 style: TextStyle(fontSize: 13, height: 1.35),
 ),
 const SizedBox(height: 10),
 for (final item in visible)
 Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(
 '- $item',
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 ),
 if (hiddenCount > 0)
 Text(
 '- +$hiddenCount more',
 style: const TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 12),
 const Text(
 'Choose one option:',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () =>
 Navigator.of(dialogContext).pop(_MissingProcurementAction.skip),
 child: const Text('Skip for now'),
 ),
 OutlinedButton(
 onPressed: () => Navigator.of(dialogContext)
 .pop(_MissingProcurementAction.manual),
 child: const Text('Add Missing Info'),
 ),
 ElevatedButton.icon(
 onPressed: () => Navigator.of(dialogContext)
 .pop(_MissingProcurementAction.autoFill),
 icon: const Icon(Icons.auto_awesome, size: 16),
 label: const Text('Auto-fill with AI'),
 ),
 ],
 ),
 );
 }

 Future<void> _openManualCompletionForIssues(
 FormValidationResult validation,
 ) async {
 final issue = validation.firstIssue;
 if (issue == null) return;

 switch (issue.id) {
 case 'item_list':
 setState(() => _selectedTab = _ProcurementTab.itemsList);
 await Future<void>.delayed(const Duration(milliseconds: 80));
 await _openAddItemDialog();
 return;
 case 'project_budget':
 case 'expected_delivery_date':
 setState(() => _selectedTab = _ProcurementTab.itemsList);
 await Future<void>.delayed(const Duration(milliseconds: 80));
 ProcurementItemModel? target;
 if (issue.id == 'project_budget') {
 for (final item in _items) {
 if (item.budget <= 0) {
 target = item;
 break;
 }
 }
 } else {
 for (final item in _items) {
 if (item.estimatedDelivery == null) {
 target = item;
 break;
 }
 }
 }
 target ??= _items.isNotEmpty ? _items.first : null;
 if (target == null) {
 await _openAddItemDialog();
 } else {
 await _openEditItemDialog(target);
 }
 return;
 case 'vendor_selection':
 setState(() => _selectedTab = _ProcurementTab.vendorManagement);
 await Future<void>.delayed(const Duration(milliseconds: 80));
 if (_vendors.isEmpty) {
 await _openAddVendorDialog();
 } else if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Select at least one vendor checkbox to continue to Security.',
 ),
 ),
 );
 }
 return;
 default:
 await _focusFirstProcurementIssue(validation);
 }
 }

 Future<void> _createFallbackProcurementItem(String projectId) async {
 final data = ProjectDataHelper.getData(context);
 final projectName = data.projectName.trim();
 final solutionTitle = data.solutionTitle.trim();
 final itemName = solutionTitle.isNotEmpty
 ? '$solutionTitle Starter Procurement'
 : (projectName.isNotEmpty
 ? '$projectName Starter Procurement'
 : 'Starter Procurement Item');

 final item = ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: itemName,
 description:
 'Auto-created to satisfy minimum procurement requirements before security.',
 category: 'General',
 status: ProcurementItemStatus.planning,
 priority: ProcurementPriority.medium,
 budget: 10000,
 estimatedDelivery: DateTime.now().add(const Duration(days: 30)),
 responsibleMember: _vendors.isNotEmpty ? 'Yes' : 'Not Sure',
 comments: '4 weeks',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 );
 await ProcurementService.createItem(item);
 }

 Future<void> _createFallbackVendor(String projectId) async {
 final data = ProjectDataHelper.getData(context);
 final projectName = data.projectName.trim().isNotEmpty
 ? data.projectName.trim()
 : 'Project';
 final nextReview = DateFormat('yyyy-MM-dd')
 .format(DateTime.now().add(const Duration(days: 90)));
 await VendorService.createVendor(
 projectId: projectId,
 name: '$projectName Preferred Vendor',
 category: 'Services',
 sla: '95%',
 rating: 'A',
 status: 'Active',
 nextReview: nextReview,
 onTimeDelivery: 0.95,
 incidentResponse: 0.9,
 qualityScore: 0.9,
 costAdherence: 0.9,
 notes: 'Auto-created to satisfy procurement vendor requirement.',
 );
 }

 // ignore: unused_element
 Future<bool> _autoFillMissingProcurementFields(
 FormValidationResult validation,
 ) async {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Cannot auto-fill procurement requirements.',
 ),
 backgroundColor: Colors.red,
 ),
 );
 }
 return false;
 }

 final needsItems = _hasValidationIssue(validation, 'item_list');
 final needsBudget = _hasValidationIssue(validation, 'project_budget');
 final needsDelivery =
 _hasValidationIssue(validation, 'expected_delivery_date');
 final needsVendor = _hasValidationIssue(validation, 'vendor_selection');

 try {
 await _generateProcurementDataIfNeeded(
 showIfAlreadySeeded: true,
 silent: true,
 );
 await _syncValidationSourcesFromBackend();

 if ((needsItems || _items.isEmpty) && _items.isEmpty) {
 await _createFallbackProcurementItem(projectId);
 await _syncValidationSourcesFromBackend();
 }

 if (needsBudget &&
 _items.isNotEmpty &&
 !_items.any((item) => item.budget > 0)) {
 final target = _items.first;
 await ProcurementService.updateItem(projectId, target.id, {
 'budget': 10000.0,
 });
 }

 if (needsDelivery &&
 _items.isNotEmpty &&
 !_items.any((item) => item.estimatedDelivery != null)) {
 final target = _items.first;
 await ProcurementService.updateItem(projectId, target.id, {
 'estimatedDelivery': DateTime.now().add(const Duration(days: 30)),
 });
 }

 if (needsVendor) {
 if (_vendors.isEmpty) {
 await _createFallbackVendor(projectId);
 await _syncValidationSourcesFromBackend();
 }
 if (_vendors.isNotEmpty) {
 final vendor = _vendors.first;
 if (mounted) {
 setState(() => _selectedVendorIds.add(vendor.id));
 }
 ProcurementItemModel? itemWithoutVendor;
 for (final item in _items) {
 if ((item.vendorId ?? '').trim().isEmpty) {
 itemWithoutVendor = item;
 break;
 }
 }
 if (itemWithoutVendor != null) {
 await ProcurementService.updateItem(
 projectId, itemWithoutVendor.id, {
 'vendorId': vendor.id,
 });
 }
 }
 }

 await _syncValidationSourcesFromBackend();
 _clearResolvedValidationErrors();
 return true;
 } catch (e) {
 debugPrint('Auto-fill procurement requirements failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Auto-fill failed: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return false;
 }
 }

 void _clearNavigationValidationState() {
 if (_validationErrors.isEmpty &&
 _tabsWithErrors.isEmpty &&
 !_showPendingSecurityPrompt &&
 _pendingSecurityIssues.isEmpty) {
 return;
 }
 setState(() {
 _validationErrors = const {};
 _tabsWithErrors.clear();
 _showPendingSecurityPrompt = false;
 _pendingSecurityIssues = const <ValidationIssue>[];
 });
 }

 Future<void> _saveAndNavigateToSecurity({
 bool skippedValidation = false,
 }) async {
 final provider = ProjectDataHelper.getProvider(context);
 final messenger = ScaffoldMessenger.of(context);
 try {
 await provider.saveToFirebase(checkpoint: _checkpointId);
 } catch (e) {
 debugPrint('Error saving before navigation: $e');
 if (mounted) {
 messenger.showSnackBar(
 const SnackBar(
 content: Text(
 'Could not fully save right now. Continuing and you can save again on the next page.',
 ),
 backgroundColor: Colors.orange,
 ),
 );
 }
 }

 if (!mounted) return;

 if (skippedValidation) {
 messenger.showSnackBar(
 SnackBar(
 content: Text(
 'Continuing to ${_nextFlowDestinationLabel()}. You can complete remaining procurement fields later.',
 ),
 duration: Duration(seconds: 3),
 ),
 );
 }

 if (_isPlanningMode) {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: _checkpointId,
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 procurement: _currentProcurementNotes(data),
 ),
 ),
 showSnackbar: false,
 );
 if (!mounted) return;
 PlanningPhaseNavigation.navigateToNext(context, 'procurement');
 return;
 }

 final nextCheckpoint =
 FrontEndPlanningNavigation.nextCheckpoint(context, _checkpointId) ??
 'fep_security';
 final nextScreen =
 FrontEndPlanningNavigation.resolveScreen(context, nextCheckpoint) ??
 const FrontEndPlanningSecurityScreen();

 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: _checkpointId,
 saveInBackground: true,
 nextScreenBuilder: () => nextScreen,
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 procurement: _currentProcurementNotes(data),
 ),
 ),
 );
 }

 Future<void> _skipMissingDataAndContinue() async {
 _clearNavigationValidationState();
 await _saveAndNavigateToSecurity(
 skippedValidation: true,
 );
 }

 Future<void> _goToNextSection() async {
 final nextTab = _nextTab();
 if (nextTab != null) {
 setState(() => _selectedTab = nextTab);
 if (nextTab == _ProcurementTab.purchaseOrders) {
 unawaited(_ensurePurchaseOrdersSeeded());
 }
 return;
 }
 await _ensurePurchaseOrdersSeeded();

 final validation = _validateProcurementForNavigation();
 if (!validation.isValid) {
 final tabErrors = validation.issues
 .map((issue) => _tabForFieldId(issue.id))
 .whereType<_ProcurementTab>()
 .toSet();
 if (mounted) {
 setState(() {
 _validationErrors = validation.errorByFieldId;
 _tabsWithErrors
 ..clear()
 ..addAll(tabErrors);
 _pendingSecurityIssues = validation.issues;
 _showPendingSecurityPrompt = true;
 });
 }
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Some procurement fields are still missing. You can continue now and complete them later.',
 ),
 duration: Duration(seconds: 3),
 backgroundColor: Color(0xFFF59E0B),
 ),
 );
 await _saveAndNavigateToSecurity(skippedValidation: true);
 return;
 }

 _clearNavigationValidationState();
 await _saveAndNavigateToSecurity();
 }

 void _goToPreviousSection() {
 _clearNavigationValidationState();
 if (_isPlanningMode) {
 PlanningPhaseNavigation.navigateToPrevious(context, 'procurement');
 return;
 }
 FrontEndPlanningNavigation.goToPrevious(context, _checkpointId);
 }

 Widget _buildTabContent() {
 switch (_selectedTab) {
 case _ProcurementTab.procurementDashboard:
 return _buildDashboardSection();
 case _ProcurementTab.itemsList:
 return _withSectionValidation(
 sectionKey: _itemsSectionKey,
 errorText: _itemsSectionErrorText(),
 child: ProcurementItemsListView(
 key: const ValueKey('procurement_items_list'),
 items: _items,
 trackableItems: _trackableItems,
 selectedIndex: _selectedTrackableIndex,
 onSelectTrackable: _handleTrackableSelected,
 currencyFormat: _currencyFormat,
 onAddItem: _openAddItemDialog,
 onEditItem: _openEditItemDialog,
 onDeleteItem: _removeItem,
 ),
 );
 case _ProcurementTab.vendorManagement:
 return _withSectionValidation(
 sectionKey: _vendorSectionKey,
 errorText: _vendorSectionErrorText(),
 child: VendorManagementView(
 key: const ValueKey('procurement_vendor_management'),
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
 onApprovedChanged: (value) => setState(() => _approvedOnly = value),
 onPreferredChanged: (value) =>
 setState(() => _preferredOnly = value),
 onCategoryChanged: (value) =>
 setState(() => _categoryFilter = value),
 onViewModeChanged: (value) => setState(() => _listView = value),
 onToggleVendorSelected: _toggleVendorSelection,
 onEditVendor: _openEditVendorDialog,
 onDeleteVendor: _removeVendor,
 onOpenApprovedVendorList: _openApprovedVendorList,
 ),
 );
 case _ProcurementTab.rfqWorkflow:
 final workflowScopeId = _resolveWorkflowScopeId();
 final workflowScope = _findWorkflowScopeById(workflowScopeId);
 final workflowDisabledForSelection = _customizeWorkflowByScope &&
 workflowScope != null &&
 !_scopeRequiresProcurementWorkflow(workflowScope);
 final workflowSteps = workflowDisabledForSelection
 ? const <_ProcurementWorkflowStep>[]
 : _workflowDraftSteps;
 return _RfqWorkflowView(
 key: const ValueKey('procurement_rfq_workflow'),
 scopeItems: _items,
 rfqs: _rfqs,
 criteria: _rfqCriteria,
 currencyFormat: _currencyFormat,
 customizeWorkflowByScope: _customizeWorkflowByScope,
 selectedScopeId: workflowScopeId,
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
 onCreateRfq: _openCreateRfqDialog,
 onEditRfq: _openEditRfqDialog,
 onDeleteRfq: _deleteRfq,
 onOpenTemplates: () =>
 _handleTabSelected(_ProcurementTab.itemTracking),
 );
 case _ProcurementTab.purchaseOrders:
 return _PurchaseOrdersView(
 key: const ValueKey('procurement_purchase_orders'),
 orders: _purchaseOrders,
 currencyFormat: _currencyFormat,
 processStarted: _hasCommencedContractingActivities,
 earlyStartEnabled: _purchaseOrdersEarlyStartEnabled,
 canEnableEarlyStart: _canCommenceContractingActivities,
 onEnableEarlyStart: _enablePurchaseOrdersEarlyStart,
 vitalLleItems: _vitalLleItems,
 itemNumberById: _itemNumberById,
 trackableItems: _trackableItems,
 selectedTrackableIndex: _selectedTrackableIndex,
 onSelectTrackable: _handleTrackableSelected,
 selectedTrackableItem: (_selectedTrackableIndex >= 0 &&
 _selectedTrackableIndex < _trackableItems.length)
 ? _trackableItems[_selectedTrackableIndex]
 : null,
 trackingAlerts: _trackingAlerts,
 carrierPerformance: _carrierPerformance,
 onUpdateTrackingStatus: _updateSelectedTrackingStatus,
 onCreatePo: _openCreatePoDialog,
 onEditPo: _openEditPoDialog,
 onDeletePo: _deletePo,
 );
 case _ProcurementTab.itemTracking:
 return _ProcurementTemplatesView(
 key: const ValueKey('procurement_templates'),
 processStarted: _hasCommencedContractingActivities,
 );
 case _ProcurementTab.reports:
 if (!_hasCommencedContractingActivities) {
 return const _StageLockedView(
 title: 'Reports Locked',
 message:
 'No access at this stage. Start at least one contract scope process to unlock procurement reports.',
 );
 }
 return _ReportsView(
 key: const ValueKey('procurement_reports'),
 kpis: _reportKpis,
 spendBreakdown: _spendBreakdown,
 leadTimeMetrics: _leadTimeMetrics,
 savingsOpportunities: _savingsOpportunities,
 complianceMetrics: _complianceMetrics,
 currencyFormat: _currencyFormat,
 onGenerateReports: _generateReportData,
 );
 }
 }

 Widget _withSectionValidation({
 required Widget child,
 required Key sectionKey,
 String? errorText,
 }) {
 final hasError = (errorText ?? '').trim().isNotEmpty;
 return Column(
 key: sectionKey,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 child,
 if (hasError) ...[
 const SizedBox(height: 8),
 Text(
 errorText!,
 style: const TextStyle(
 color: Color(0xFFDC2626),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ],
 );
 }

 Widget _buildStreamWindowControls() {
 switch (_selectedTab) {
 case _ProcurementTab.procurementDashboard:
 final showStrategies = _strategies.length >= _strategiesLimit;
 final showVendors = _vendors.length >= _vendorsLimit;
 if (!showStrategies && !showVendors) {
 return const SizedBox.shrink();
 }
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 if (showStrategies)
 OutlinedButton.icon(
 onPressed: () =>
 _loadMoreForTab(_ProcurementTab.procurementDashboard),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label:
 Text('Load ${_streamLimitStep.toString()} more strategies'),
 ),
 if (showVendors)
 OutlinedButton.icon(
 onPressed: () =>
 _loadMoreForTab(_ProcurementTab.vendorManagement),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more vendors'),
 ),
 ],
 );
 case _ProcurementTab.itemsList:
 if (_items.length < _itemsLimit) return const SizedBox.shrink();
 return OutlinedButton.icon(
 onPressed: () => _loadMoreForTab(_ProcurementTab.itemsList),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more items'),
 );
 case _ProcurementTab.itemTracking:
 return const SizedBox.shrink();
 case _ProcurementTab.reports:
 if (!_hasCommencedContractingActivities ||
 _items.length < _itemsLimit) {
 return const SizedBox.shrink();
 }
 return OutlinedButton.icon(
 onPressed: () => _loadMoreForTab(_ProcurementTab.reports),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more records'),
 );
 case _ProcurementTab.vendorManagement:
 if (_vendors.length < _vendorsLimit) return const SizedBox.shrink();
 return OutlinedButton.icon(
 onPressed: () => _loadMoreForTab(_ProcurementTab.vendorManagement),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more vendors'),
 );
 case _ProcurementTab.rfqWorkflow:
 if (_rfqs.length < _rfqsLimit) return const SizedBox.shrink();
 return OutlinedButton.icon(
 onPressed: () => _loadMoreForTab(_ProcurementTab.rfqWorkflow),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more RFQs'),
 );
 case _ProcurementTab.purchaseOrders:
 if (!_isPurchaseOrdersSectionEnabled) {
 return const SizedBox.shrink();
 }
 if (_purchaseOrders.length < _purchaseOrdersLimit) {
 return const SizedBox.shrink();
 }
 return OutlinedButton.icon(
 onPressed: () => _loadMoreForTab(_ProcurementTab.purchaseOrders),
 icon: const Icon(Icons.unfold_more_rounded, size: 16),
 label: Text('Load ${_streamLimitStep.toString()} more orders'),
 );
 }
 }

 Widget _buildStreamErrorBanner() {
 final error = _streamError;
 if (error == null || error.isEmpty) return const SizedBox.shrink();
 return Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 14),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFECACA)),
 ),
 child: Row(
 children: [
 const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 error,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF991B1B),
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildNextSectionButton() {
 final nextTab = _nextTab();
 final nextLabel = nextTab?.label ?? 'Security';
 return Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton.icon(
 onPressed: _goToNextSection,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF6C437),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 icon: const Icon(Icons.arrow_forward_rounded, size: 18),
 label: Text('Next: $nextLabel',
 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
 ),
 );
 }

 Widget? _buildPendingSecurityPromptBar() {
 if (!_showPendingSecurityPrompt || _pendingSecurityIssues.isEmpty) {
 return null;
 }
 final summaries = _pendingIssueSummaries();
 final visible = summaries.take(4).toList(growable: false);
 final hiddenCount = summaries.length - visible.length;
 final pendingText = hiddenCount > 0
 ? '${visible.join(', ')}, +$hiddenCount more'
 : visible.join(', ');

 return _PendingSecurityPromptBar(
 message:
 'We recommend completing the current requirements before continuing to ${_nextFlowDestinationLabel()}.',
 pendingText: pendingText,
 onAcknowledge: _dismissPendingSecurityPrompt,
 onSkip: () {
 _skipMissingDataAndContinue();
 },
 );
 }

 Widget _buildDashboardSection({Key? key}) {
 return Column(
 key: key ?? const ValueKey('procurement_dashboard'),
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: _PlanHeader(onItemListTap: _handleItemListTap)),
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed = await showRegenerateAllConfirmation(context);
 if (confirmed && mounted) {
 await _regenerateAllProcurement();
 }
 },
 isLoading: _isGeneratingData,
 tooltip: 'Generate starter procurement data',
 ),
 ],
 ),
 const SizedBox(height: 10),
 const Text(
 'Missing procurement records auto-generate on load, and you can regenerate manually anytime.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 _ContractScopeManagementSection(
 scopes: _items,
 canStartProcess: _canCommenceContractingActivities,
 startedScopeCount: _items
 .where((item) => item.status != ProcurementItemStatus.planning)
 .length,
 onStartProcessForScope: _startProcessForScope,
 ),
 const SizedBox(height: 16),
 _ProcurementStrategiesSection(
 strategies: _strategies,
 onAddStrategy: _openAddStrategyDialog,
 onEditStrategy: _openEditStrategyDialog,
 onDeleteStrategy: _deleteStrategy,
 ),
 const SizedBox(height: 20),
 _StrategiesSection(
 items: _items,
 currencyFormat: _currencyFormat,
 onAddScope: _openAddItemDialog,
 ),
 const SizedBox(height: 20),
 _buildWhatToProcureSection(),
 const SizedBox(height: 32),
 _VendorsSection(
 vendors: _filteredVendors,
 allVendorsCount: _vendors.length,
 selectedVendorIds: _selectedVendorIds,
 approvedOnly: _approvedOnly,
 preferredOnly: _preferredOnly,
 listView: _listView,
 categoryFilter: _categoryFilter,
 categoryOptions: _categoryOptions,
 onAddVendor: _openAddVendorDialog,
 onApprovedChanged: (value) => setState(() => _approvedOnly = value),
 onPreferredChanged: (value) => setState(() => _preferredOnly = value),
 onCategoryChanged: (value) => setState(() => _categoryFilter = value),
 onViewModeChanged: (value) => setState(() => _listView = value),
 onToggleVendorSelected: _toggleVendorSelection,
 onEditVendor: _openEditVendorDialog,
 onDeleteVendor: _removeVendor,
 onOpenApprovedVendorList: _openApprovedVendorList,
 ),
 ],
 );
 }

 Widget _buildWhatToProcureSection() {
 final data = ProjectDataHelper.getData(context);
 final needs = _deriveProcurementNeeds(data);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'What to procure',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const Spacer(),
 OutlinedButton.icon(
 onPressed: _openAddItemDialog,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Item'),
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text(
 'Auto-populated from project requirements and scope. Adjust or add items as needed.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 12),
 if (needs.isEmpty)
 buildNduTableEmptyState(
 context,
 message:
 'No procurement needs identified yet. Add scope items or requirements to populate this list.',
 )
 else
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: ResponsiveDataTableWrapper(
 minWidth: 820,
 child: buildNduDataTable(
 context: context,
 columnSpacing: 24,
 horizontalMargin: 18,
 headingRowHeight: 48,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 80,
 columns: const [
 DataColumn(label: Text('Item')),
 DataColumn(label: Text('Source')),
 DataColumn(label: Text('Qty')),
 DataColumn(label: Text('Est. Cost')),
 DataColumn(label: Text('Priority')),
 ],
 rows: needs.map((need) {
 return DataRow(
 cells: [
 DataCell(Text(need.name)),
 DataCell(Text(need.source)),
 DataCell(Text(need.quantity.toString())),
 DataCell(Text(need.estimatedCost <= 0
 ? '-'
 : _currencyFormat.format(need.estimatedCost))),
 DataCell(
 _PriorityPill(label: need.priority),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 ),
 ],
 );
 }

 List<_ProcurementNeed> _deriveProcurementNeeds(ProjectDataModel data) {
 final needs = <_ProcurementNeed>[];
 final seen = <String>{};

 void addNeed({
 required String name,
 required String source,
 String priorityHint = '',
 }) {
 final trimmed = name.trim();
 if (trimmed.isEmpty) return;
 final key = trimmed.toLowerCase();
 if (seen.contains(key)) return;
 seen.add(key);
 final match = _matchProcurementItem(trimmed);
 final cost = match?.budget ?? 0.0;
 final priority = match != null
 ? _priorityLabel(match.priority)
 : _priorityFromHint(priorityHint);
 needs.add(
 _ProcurementNeed(
 name: trimmed,
 source: source,
 quantity: 1,
 estimatedCost: cost,
 priority: priority,
 ),
 );
 }

 if (data.frontEndPlanning.requirementItems.isNotEmpty) {
 for (final req in data.frontEndPlanning.requirementItems) {
 addNeed(
 name: req.description,
 source: 'Requirements',
 priorityHint: req.requirementType,
 );
 }
 }

 if (needs.isEmpty && data.withinScopeItems.isNotEmpty) {
 for (final item in data.withinScopeItems) {
 addNeed(
 name: item.description,
 source: 'Scope',
 priorityHint: item.description,
 );
 }
 }

 if (needs.isEmpty && _items.isNotEmpty) {
 for (final item in _items) {
 addNeed(
 name: item.name,
 source: 'Procurement',
 priorityHint: item.priority.name,
 );
 }
 }

 return needs;
 }

 ProcurementItemModel? _matchProcurementItem(String name) {
 final normalized = name.toLowerCase();
 for (final item in _items) {
 final itemName = item.name.toLowerCase();
 if (itemName == normalized ||
 itemName.contains(normalized) ||
 normalized.contains(itemName)) {
 return item;
 }
 }
 return null;
 }

 String _priorityLabel(ProcurementPriority priority) {
 switch (priority) {
 case ProcurementPriority.critical:
 return 'Critical';
 case ProcurementPriority.high:
 return 'High';
 case ProcurementPriority.medium:
 return 'Medium';
 case ProcurementPriority.low:
 return 'Low';
 }
 }

 String _priorityFromHint(String hint) {
 final normalized = hint.toLowerCase();
 if (normalized.contains('critical')) return 'Critical';
 if (normalized.contains('high')) return 'High';
 if (normalized.contains('low')) return 'Low';
 return 'Medium';
 }

 List<Widget> _buildDialogContextChips() {
 final data = ProjectDataHelper.getData(context);
 final chips = <Widget>[
 const ContextChip(label: 'Phase', value: 'Front End Planning'),
 ];
 final projectName = data.projectName.trim();
 if (projectName.isNotEmpty) {
 chips.insert(0, ContextChip(label: 'Project', value: projectName));
 }
 final solution = data.solutionTitle.trim();
 if (solution.isNotEmpty) {
 chips.add(ContextChip(label: 'Solution', value: solution));
 }
 return chips;
 }

 String _strategyStatusLabel(StrategyStatus status) {
 switch (status) {
 case StrategyStatus.draft:
 return 'Draft';
 case StrategyStatus.active:
 return 'Active';
 case StrategyStatus.complete:
 return 'Complete';
 }
 }

 Future<ProcurementStrategyModel?> _showStrategyDialog({
 ProcurementStrategyModel? existing,
 }) async {
 final titleController = TextEditingController(text: existing?.title ?? '');
 final categoryController =
 TextEditingController(text: existing?.category ?? '');
 final itemCountController = TextEditingController(
 text: (existing?.itemCount ?? 0).toString(),
 );
 var selectedStatus = existing?.status ?? StrategyStatus.draft;

 final result = await showDialog<ProcurementStrategyModel>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Text(
 existing == null ? 'Add Procurement Strategy' : 'Edit Strategy',
 ),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Strategy Name',
 hintText: 'e.g. IT Infrastructure',
 ),
 textCapitalization: TextCapitalization.words,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: categoryController,
 decoration: const InputDecoration(
 labelText: 'Category',
 hintText: 'e.g. Office & Workspace',
 ),
 textCapitalization: TextCapitalization.words,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<StrategyStatus>(
 value: selectedStatus,
 decoration: const InputDecoration(labelText: 'Status'),
 items: StrategyStatus.values
 .map(
 (status) => DropdownMenuItem<StrategyStatus>(
 value: status,
 child: Text(_strategyStatusLabel(status)),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => selectedStatus = value);
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: itemCountController,
 decoration: const InputDecoration(
 labelText: 'Number of Items (Optional)',
 hintText: '0',
 ),
 keyboardType: TextInputType.number,
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
 final projectId = _resolveProjectId();
 final strategyName = titleController.text.trim();
 final category = categoryController.text.trim();
 final itemCount =
 int.tryParse(itemCountController.text.trim()) ?? 0;
 if (projectId.isEmpty ||
 strategyName.isEmpty ||
 category.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Strategy name and category are required.'),
 ),
 );
 return;
 }
 Navigator.of(dialogContext).pop(
 ProcurementStrategyModel(
 id: existing?.id ?? '',
 projectId: projectId,
 title: strategyName,
 category: category,
 status: selectedStatus,
 itemCount: itemCount < 0 ? 0 : itemCount,
 description: existing?.description ??
 'Strategy for $category procurement activities.',
 createdAt: existing?.createdAt ?? DateTime.now(),
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );

 titleController.dispose();
 categoryController.dispose();
 itemCountController.dispose();
 return result;
 }

 Future<void> _openAddStrategyDialog() async {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Unable to add strategy.'),
 ),
 );
 return;
 }
 final strategy = await _showStrategyDialog();
 if (strategy == null) return;
 try {
 await ProcurementService.createStrategy(strategy);
 _refreshSubscriptionsForActiveProject();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Strategy added.')),
 );
 } catch (e) {
 debugPrint('Unable to add strategy: $e');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Unable to add strategy. Please try again in a moment.')),
 );
 }
 }

 Future<void> _openEditStrategyDialog(
 ProcurementStrategyModel strategy) async {
 final updated = await _showStrategyDialog(existing: strategy);
 if (updated == null) return;
 try {
 await ProcurementService.updateStrategy(updated.projectId, strategy.id, {
 'title': updated.title,
 'category': updated.category,
 'description': updated.description,
 'status': updated.status.name,
 'itemCount': updated.itemCount,
 });
 _refreshSubscriptionsForActiveProject();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Strategy updated.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to update strategy: $e')),
 );
 }
 }

 Future<void> _deleteStrategy(ProcurementStrategyModel strategy) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Delete strategy?'),
 content: Text(
 'Are you sure you want to delete "${strategy.title}"?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFDC2626),
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 ) ??
 false;
 if (!confirmed) return;

 try {
 await ProcurementService.deleteStrategy(strategy.projectId, strategy.id);
 _refreshSubscriptionsForActiveProject();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Strategy deleted.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to delete strategy: $e')),
 );
 }
 }

 Future<void> _openAddItemDialog() async {
 final categoryOptions = const [
 'Materials',
 'Equipment',
 'Services',
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Other',
 ];

 final result = await showDialog<ProcurementItemModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return AddItemDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 responsibleOptions: _assignableMembers,
 showAiGenerateButton: false,
 itemDomainLabel: 'Procurement',
 );
 },
 );

 if (result != null) {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Unable to add procurement item.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 final normalized = result.copyWith(projectId: projectId);
 await ProcurementService.createItem(normalized);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error creating procurement item: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }
 }

 Future<void> _openEditItemDialog(ProcurementItemModel item) async {
 final categoryOptions = const [
 'Materials',
 'Equipment',
 'Services',
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Other',
 ];

 final result = await showDialog<ProcurementItemModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return AddItemDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 responsibleOptions: _assignableMembers,
 initialItem: item,
 showAiGenerateButton: false,
 itemDomainLabel: 'Procurement',
 );
 },
 );

 if (result == null) return;
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || item.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to edit item.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 await ProcurementService.updateItem(projectId, item.id, {
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
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to edit item: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _removeItem(ProcurementItemModel item) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) {
 return AlertDialog(
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
 );
 },
 ) ??
 false;
 if (!confirmed) return;

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || item.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to delete item.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 await ProcurementService.deleteItem(projectId, item.id);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to delete item: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
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
 barrierColor: Colors.black.withOpacity(0.45),
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

 if (result != null) {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Unable to add vendor.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 final normalizedName = result.name.trim().toLowerCase();
 final alreadyExists = _vendors.any(
 (vendor) => vendor.name.trim().toLowerCase() == normalizedName,
 );
 if (alreadyExists) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Vendor already exists. Existing details were reused.',
 ),
 ),
 );
 }
 return;
 }
 await VendorService.createVendor(
 projectId: projectId,
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
 _refreshSubscriptionsForActiveProject();
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
 }

 Future<void> _openCreateRfqDialog() async {
 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Services',
 'Materials',
 'Other',
 ];

 final result = await showDialog<RfqModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return CreateRfqDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 );
 },
 );

 if (result != null) {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Unable to create RFQ.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 final normalized = RfqModel(
 id: result.id,
 projectId: projectId,
 title: result.title,
 category: result.category,
 owner: result.owner,
 dueDate: result.dueDate,
 invitedCount: result.invitedCount,
 responseCount: result.responseCount,
 budget: result.budget,
 status: result.status,
 priority: result.priority,
 createdAt: result.createdAt,
 );
 await ProcurementService.createRfq(normalized);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to create RFQ: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }
 }

 Future<void> _openEditRfqDialog(RfqModel rfq) async {
 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Services',
 'Materials',
 'Other',
 ];

 final result = await showDialog<RfqModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return CreateRfqDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 initialRfq: rfq,
 );
 },
 );

 if (result == null) return;

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || rfq.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Unable to edit RFQ.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 final invitedCount = result.invitedCount < 0 ? 0 : result.invitedCount;
 final responseCount = result.responseCount.clamp(0, invitedCount).toInt();

 await ProcurementService.updateRfq(projectId, rfq.id, {
 'projectId': projectId,
 'title': result.title.trim(),
 'category': result.category.trim(),
 'owner': result.owner.trim(),
 'dueDate': result.dueDate,
 'invitedCount': invitedCount,
 'responseCount': responseCount,
 'budget': result.budget,
 'status': result.status.name,
 'priority': result.priority.name,
 });
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to edit RFQ: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _deleteRfq(RfqModel rfq) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) {
 return AlertDialog(
 title: const Text('Delete RFQ'),
 content: Text(
 'Delete ${rfq.title.trim().isEmpty ? 'this RFQ' : '"${rfq.title}"'}? This action cannot be undone.',
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
 );
 },
 ) ??
 false;

 if (!confirmed) return;

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || rfq.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to delete RFQ.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 await ProcurementService.deleteRfq(projectId, rfq.id);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to delete RFQ: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _openApprovedVendorList() async {
 final approvedVendors = _vendors
 .where((vendor) => vendor.isApproved)
 .toList()
 ..sort(
 (a, b) =>
 a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()),
 );

 if (!mounted) return;

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Row(
 children: [
 Icon(Icons.fact_check_outlined, color: Color(0xFF2563EB)),
 SizedBox(width: 10),
 Text('Approved Vendor List'),
 ],
 ),
 content: SizedBox(
 width: 560,
 child: approvedVendors.isEmpty
 ? const Text(
 'No approved vendors found yet. Set vendor status to Active or Approved to populate this list.',
 style: TextStyle(height: 1.45),
 )
 : ConstrainedBox(
 constraints: const BoxConstraints(maxHeight: 360),
 child: ListView.separated(
 shrinkWrap: true,
 itemCount: approvedVendors.length,
 separatorBuilder: (_, __) =>
 const Divider(height: 12, thickness: 0.5),
 itemBuilder: (_, index) {
 final vendor = approvedVendors[index];
 final name = vendor.name.trim();
 return ListTile(
 dense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 0),
 leading: CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFFEFF6FF),
 child: Text(
 name.isEmpty ? '?' : name[0].toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF2563EB),
 ),
 ),
 ),
 title: Text(
 name.isEmpty ? 'Unnamed vendor' : name,
 style: const TextStyle(fontWeight: FontWeight.w600),
 ),
 subtitle: Text(
 vendor.category.trim().isEmpty
 ? 'Category not set'
 : vendor.category.trim(),
 ),
 trailing: _RatingStars(rating: vendor.ratingScore),
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
 ],
 ),
 );
 }

 Future<void> _openCreatePoDialog() async {
 if (!_isPurchaseOrdersSectionEnabled) {
 _enablePurchaseOrdersEarlyStart();
 if (!_isPurchaseOrdersSectionEnabled) return;
 }

 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Services'
 ];
 final sourceItems = (!_hasCommencedContractingActivities &&
 _purchaseOrdersEarlyStartEnabled &&
 _vitalLleItems.isNotEmpty)
 ? _vitalLleItems
 : _items;

 final result = await showDialog<PurchaseOrderModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return CreatePoDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 sourceItems: sourceItems,
 sourceItemNumberById: _itemNumberById,
 prioritizeLongLeadSelection: !_hasCommencedContractingActivities &&
 _purchaseOrdersEarlyStartEnabled,
 );
 },
 );

 if (result != null) {
 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Unable to create purchase order.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }
 final normalized = PurchaseOrderModel(
 id: result.id,
 poNumber: result.poNumber,
 projectId: projectId,
 vendorName: result.vendorName,
 vendorId: result.vendorId,
 category: result.category,
 owner: result.owner,
 orderedDate: result.orderedDate,
 expectedDate: result.expectedDate,
 amount: result.amount,
 progress: result.progress,
 status: result.status,
 createdAt: result.createdAt,
 );
 await ProcurementService.createPo(normalized);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to create purchase order: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }
 }

 Future<void> _openEditPoDialog(PurchaseOrderModel order) async {
 final categoryOptions = const [
 'IT Equipment',
 'Construction Services',
 'Furniture',
 'Security',
 'Logistics',
 'Services'
 ];

 final result = await showDialog<PurchaseOrderModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) {
 return CreatePoDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 initialPo: order,
 sourceItems: _items,
 sourceItemNumberById: _itemNumberById,
 );
 },
 );

 if (result == null) return;

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || order.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Unable to edit purchase order.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 await ProcurementService.updatePo(projectId, order.id, {
 'poNumber': result.poNumber.trim(),
 'projectId': projectId,
 'vendorName': result.vendorName.trim(),
 'vendorId': result.vendorId,
 'category': result.category.trim(),
 'owner': result.owner.trim(),
 'orderedDate': result.orderedDate,
 'expectedDate': result.expectedDate,
 'amount': result.amount,
 'progress': result.progress.clamp(0.0, 1.0),
 'status': result.status.name,
 });
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to edit purchase order: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _deletePo(PurchaseOrderModel order) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) {
 return AlertDialog(
 title: const Text('Remove Purchase Order'),
 content: Text(
 'Delete ${order.poNumber.isNotEmpty ? order.poNumber : order.id}? This action cannot be undone.',
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
 );
 },
 ) ??
 false;
 if (!confirmed) return;

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty || order.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to remove purchase order.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 await ProcurementService.deletePo(projectId, order.id);
 _refreshSubscriptionsForActiveProject();
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to remove purchase order: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _startProcessForScope(ProcurementItemModel item) async {
 if (!_canCommenceContractingActivities) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Only authorized procurement roles can start process for a scope.',
 ),
 ),
 );
 }
 return;
 }
 if (item.id.trim().isEmpty) return;
 if (item.status != ProcurementItemStatus.planning) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('"${item.name}" has already started.')),
 );
 }
 return;
 }

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Unable to start scope process.',
 ),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 final nextDelivery = item.estimatedDelivery ??
 DateTime.now().add(
 Duration(days: _defaultLeadTimeDaysForCategory(item.category)),
 );

 await ProcurementService.updateItem(
 projectId,
 item.id,
 {
 'status': ProcurementItemStatus.rfqReview.name,
 'progress': item.progress < 0.2 ? 0.2 : item.progress.clamp(0.0, 1.0),
 if (item.estimatedDelivery == null) 'estimatedDelivery': nextDelivery,
 },
 );
 _refreshSubscriptionsForActiveProject();
 if (!mounted) return;
 setState(() => _selectedTab = _ProcurementTab.purchaseOrders);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Started process for "${item.name}". Purchase Orders and Reports are now available.',
 ),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to start scope process: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 void _enablePurchaseOrdersEarlyStart() {
 if (!_canCommenceContractingActivities) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Only authorized roles can enable early Purchase Orders in initiation.',
 ),
 ),
 );
 }
 return;
 }
 if (_purchaseOrdersEarlyStartEnabled) return;
 setState(() {
 _purchaseOrdersEarlyStartEnabled = true;
 _selectedTab = _ProcurementTab.purchaseOrders;
 });
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Purchase Orders enabled early for vital long-lead items.',
 ),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
 }

 double _statusProgressTarget(ProcurementItemStatus status) {
 switch (status) {
 case ProcurementItemStatus.planning:
 return 0.1;
 case ProcurementItemStatus.rfqReview:
 return 0.3;
 case ProcurementItemStatus.vendorSelection:
 return 0.5;
 case ProcurementItemStatus.ordered:
 return 0.8;
 case ProcurementItemStatus.delivered:
 return 1.0;
 case ProcurementItemStatus.cancelled:
 return 0.0;
 }
 }

 Future<void> _updateSelectedTrackingStatus() async {
 if (_trackableItems.isEmpty ||
 _selectedTrackableIndex < 0 ||
 _selectedTrackableIndex >= _trackableItems.length) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No trackable item selected.')),
 );
 }
 return;
 }

 final item = _trackableItems[_selectedTrackableIndex];
 if (item.id.trim().isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Select a saved item to update status.')),
 );
 }
 return;
 }

 final nextStatus = await showModalBottomSheet<ProcurementItemStatus>(
 context: context,
 builder: (sheetContext) {
 return SafeArea(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const SizedBox(height: 8),
 const ListTile(
 title: Text(
 'Update Item Status',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 subtitle: Text('Choose the next status for this tracked item.'),
 ),
 for (final status in ProcurementItemStatus.values)
 ListTile(
 title: Text(status.label),
 trailing: status == item.status
 ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
 : null,
 onTap: () => Navigator.of(sheetContext).pop(status),
 ),
 const SizedBox(height: 8),
 ],
 ),
 );
 },
 );

 if (nextStatus == null || nextStatus == item.status) {
 return;
 }

 try {
 final projectId = _resolveProjectId();
 if (projectId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Project not initialized. Unable to update status.'),
 backgroundColor: Colors.red,
 ),
 );
 }
 return;
 }

 final nextProgress = item.progress > _statusProgressTarget(nextStatus)
 ? item.progress
 : _statusProgressTarget(nextStatus);

 await ProcurementService.updateItem(
 projectId,
 item.id,
 {
 'status': nextStatus.name,
 'progress': nextProgress.clamp(0.0, 1.0),
 if (nextStatus == ProcurementItemStatus.delivered)
 'actualDelivery': DateTime.now(),
 },
 );
 _refreshSubscriptionsForActiveProject();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Updated "${item.name}" to ${nextStatus.label}.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to update item status: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 Future<void> _generateReportData() async {
 if (_items.isEmpty && _purchaseOrders.isEmpty && _rfqs.isEmpty) {
 await _generateProcurementDataIfNeeded(silent: false);
 }
 if (!mounted) return;
 setState(_recomputeDerivedProcurementData);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Procurement reports refreshed from current data.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final projectData = ProjectDataHelper.getData(context);
 final isMobile = AppBreakpoints.isMobile(context);
 final content = Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(
 scaffoldKey: isMobile ? _scaffoldKey : null, onExportPdf: _exportPdf),
 Expanded(
 child: Container(
 color: const Color(0xFFF5F6FA),
 child: SingleChildScrollView(
 padding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Removed duplicate top bar to avoid a second app header.
 _buildStreamErrorBanner(),
 const SizedBox(height: 24),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Procurement',
 noteKey: _procurementNotesKey,
 checkpoint: _checkpointId,
 fieldKey: _notesFieldKey,
 errorText: _validationErrors['procurement_notes'],
 onChanged: _handleNotesChanged,
 fallbackText: ProjectDataHelper.getData(context)
 .frontEndPlanning
 .procurement,
 description:
 'Capture procurement priorities, vendors, and approval constraints.',
 ),
 const SizedBox(height: 16),
 Align(
 alignment: Alignment.centerRight,
 child: OutlinedButton.icon(
 onPressed: _openApprovedVendorList,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF1E3A8A),
 side: const BorderSide(color: Color(0xFFBFDBFE)),
 backgroundColor: const Color(0xFFEFF6FF),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(
 Icons.verified_user_outlined,
 size: 18,
 ),
 label: const Text(
 'Approved Vendor List'),
 ),
 ),
 if (_isPlanningMode) ...[
 const SizedBox(height: 20),
 _ProcurementPlanCard(
 initialText: projectData
 .planningNotes[_procurementPlanNoteKey],
 checkpointId: _checkpointId,
 ),
 ],
 const SizedBox(height: 32),
 _ProcurementTabBar(
 selectedTab: _selectedTab,
 onSelected: _handleTabSelected,
 tabsWithErrors: _tabsWithErrors,
 disabledTabs: _tabsWithRestrictedAccess,
 ),
 const SizedBox(height: 16),
 InnerPageNavigationHint(
 pageId: _isPlanningMode ? 'planning_procurement' : 'fep_procurement',
 pageTitle: 'Procurement',
 description: 'Navigate between procurement sections',
 currentSectionId: _selectedTab.name,
 onSectionTap: (sectionId) {
 final tab = _ProcurementTab.values.firstWhere(
 (t) => t.name == sectionId,
 orElse: () => _selectedTab,
 );
 _handleTabSelected(tab);
 },
 sections: _ProcurementTab.values.map((tab) {
 final isRestricted = _tabsWithRestrictedAccess.contains(tab);
 final isCurrent = tab == _selectedTab;
 return InnerPageSection(
 id: tab.name,
 label: tab.label,
 stepNumber: _ProcurementTab.values.indexOf(tab) + 1,
 status: isRestricted
 ? InnerPageSectionStatus.locked
 : isCurrent
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 );
 }).toList(),
 ),
 const SizedBox(height: 24),
 AnimatedSwitcher(
 duration: const Duration(milliseconds: 250),
 child: _buildTabContent(),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerLeft,
 child: _buildStreamWindowControls(),
 ),
 const SizedBox(height: 24),
 _buildNextSectionButton(),
 const SizedBox(height: 40),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 const KazAiChatBubble(),
 ],
 );

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: isMobile
 ? Drawer(
 child: InitiationLikeSidebar(
 activeItemLabel: widget.activeItemLabel ??
 (_isPlanningMode
 ? 'Planning Procurement'
 : 'FEP Procurement'),
 ),
 )
 : null,
 bottomNavigationBar: _buildPendingSecurityPromptBar(),
 body: SafeArea(
 child: isMobile
 ? content
 : Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: widget.activeItemLabel ??
 (_isPlanningMode
 ? 'Planning Procurement'
 : 'FEP Procurement'),
 ),
 ),
 Expanded(child: content),
 ],
 ),
 ),
 );
 }
}

class _ProcurementTopBar extends StatelessWidget {
 const _ProcurementTopBar({required this.onBack, required this.onForward});

 final VoidCallback onBack;
 final VoidCallback onForward;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 child: Row(
 children: [
 _circleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 12),
 _circleButton(
 icon: Icons.arrow_forward_ios_rounded, onTap: onForward),
 const SizedBox(width: 20),
 const Spacer(),
 const _UserBadge(),
 ],
 ),
 );
 }

 Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(999),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
 ),
 );
 }
}

class _PendingSecurityPromptBar extends StatelessWidget {
 const _PendingSecurityPromptBar({
 required this.message,
 required this.pendingText,
 required this.onAcknowledge,
 required this.onSkip,
 });

 final String message;
 final String pendingText;
 final VoidCallback onAcknowledge;
 final VoidCallback onSkip;

 @override
 Widget build(BuildContext context) {
 return Material(
 color: const Color(0xFFF59E0B),
 child: SafeArea(
 top: false,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 2),
 child: Icon(
 Icons.warning_amber_rounded,
 color: Color(0xFF7C2D12),
 size: 20,
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: RichText(
 text: TextSpan(
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF7C2D12),
 fontWeight: FontWeight.w600,
 height: 1.3,
 ),
 children: [
 TextSpan(text: '$message '),
 const TextSpan(
 text: 'Pending: ',
 style: TextStyle(fontWeight: FontWeight.w800),
 ),
 TextSpan(
 text: pendingText,
 style: const TextStyle(fontWeight: FontWeight.w800),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 12),
 Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 OutlinedButton(
 onPressed: onSkip,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF7C2D12),
 side: const BorderSide(color: Color(0xFFB45309)),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 minimumSize: const Size(0, 36),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8),
 ),
 ),
 child: const Text(
 'Skip for now',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 ),
 const SizedBox(height: 6),
 TextButton(
 onPressed: onAcknowledge,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFFFFF),
 backgroundColor: const Color(0xFFEA580C),
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 10),
 minimumSize: const Size(0, 36),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8),
 ),
 ),
 child: const Text(
 'OK',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _UserBadge extends StatelessWidget {
 const _UserBadge();

 @override
 Widget build(BuildContext context) {
 final projectName = ProjectDataHelper.getData(context).projectName.trim();
 final displayName = projectName.isEmpty ? 'Procurement Team' : projectName;
 final roleLabel = projectName.isEmpty ? 'Procurement' : 'Procurement Plan';

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const CircleAvatar(
 radius: 16,
 backgroundColor: Color(0xFFD1D5DB),
 child: Icon(Icons.person, size: 18, color: Color(0xFF374151)),
 ),
 const SizedBox(width: 10),
 Text(
 displayName,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(width: 6),
 Text(
 roleLabel,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 );
 }
}

class _ProcurementPlanCard extends StatelessWidget {
 const _ProcurementPlanCard({
 required this.initialText,
 required this.checkpointId,
 });

 final String? initialText;
 final String checkpointId;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Procurement Plan',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Draft the procurement plan based on initiation inputs and project context.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 14),
 AiSuggestingTextField(
 fieldLabel: 'Procurement Plan',
 hintText:
 'Outline sourcing approach, key packages, vendor strategy, and critical timelines.',
 sectionLabel: 'Procurement Plan',
 showLabel: false,
 autoGenerate: true,
 autoGenerateSection: 'Procurement Plan',
 initialText: initialText,
 onChanged: (value) async {
 final trimmed = value.trim();
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _FrontEndPlanningProcurementScreenState
 ._procurementPlanNoteKey: trimmed,
 },
 ),
 );
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: checkpointId,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _FrontEndPlanningProcurementScreenState
 ._procurementPlanNoteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 onAutoGenerated: (value) async {
 final trimmed = value.trim();
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _FrontEndPlanningProcurementScreenState
 ._procurementPlanNoteKey: trimmed,
 },
 ),
 );
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: checkpointId,
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _FrontEndPlanningProcurementScreenState
 ._procurementPlanNoteKey: trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 ),
 ],
 ),
 );
 }
}

class _ProcurementTabBar extends StatelessWidget {
 const _ProcurementTabBar(
 {required this.selectedTab,
 required this.onSelected,
 required this.tabsWithErrors,
 required this.disabledTabs});

 final _ProcurementTab selectedTab;
 final ValueChanged<_ProcurementTab> onSelected;
 final Set<_ProcurementTab> tabsWithErrors;
 final Set<_ProcurementTab> disabledTabs;

 @override
 Widget build(BuildContext context) {
 final tabs = _ProcurementTab.values;
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.all(6),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final isCompact = constraints.maxWidth < 960;
 if (isCompact) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 for (final tab in tabs)
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4),
 child: SizedBox(
 width: 160,
 child: _TabButton(
 label: tab.label,
 selected: tab == selectedTab,
 hasError: tabsWithErrors.contains(tab),
 disabled: disabledTabs.contains(tab),
 onTap: () => onSelected(tab),
 ),
 ),
 ),
 ],
 ),
 );
 }

 final double tabWidth =
 (constraints.maxWidth - (tabs.length - 1) * 8) / tabs.length;
 return Row(
 children: [
 for (final tab in tabs) ...[
 SizedBox(
 width: tabWidth,
 child: _TabButton(
 label: tab.label,
 selected: tab == selectedTab,
 hasError: tabsWithErrors.contains(tab),
 disabled: disabledTabs.contains(tab),
 onTap: () => onSelected(tab),
 ),
 ),
 if (tab != tabs.last) const SizedBox(width: 8),
 ],
 ],
 );
 },
 ),
 );
 }
}

class _TabButton extends StatelessWidget {
 const _TabButton(
 {required this.label,
 required this.selected,
 required this.onTap,
 this.hasError = false,
 this.disabled = false});

 final String label;
 final bool selected;
 final VoidCallback onTap;
 final bool hasError;
 final bool disabled;

 @override
 Widget build(BuildContext context) {
 return AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 curve: Curves.easeOut,
 decoration: BoxDecoration(
 color: disabled
 ? const Color(0xFFF8FAFC)
 : (selected ? Colors.white : Colors.transparent),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: disabled
 ? const Color(0xFFE2E8F0)
 : (selected
 ? const Color(0xFF2563EB)
 : (hasError
 ? const Color(0xFFEF4444)
 : Colors.transparent)),
 width: 1.2),
 boxShadow: selected && !disabled
 ? const [
 BoxShadow(
 color: Color(0x0C1D4ED8),
 offset: Offset(0, 6),
 blurRadius: 12,
 ),
 ]
 : null,
 ),
 child: InkWell(
 borderRadius: BorderRadius.circular(12),
 onTap: onTap,
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 14),
 child: Center(
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 mainAxisSize: MainAxisSize.min,
 children: [
 if (disabled) ...[
 const Icon(
 Icons.lock_outline_rounded,
 size: 14,
 color: Color(0xFF94A3B8),
 ),
 const SizedBox(width: 6),
 ],
 Text(
 label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: disabled
 ? const Color(0xFF94A3B8)
 : (selected
 ? const Color(0xFF1D4ED8)
 : (hasError
 ? const Color(0xFFB91C1C)
 : const Color(0xFF475569))),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }
}

class _ContractScopeManagementSection extends StatelessWidget {
 const _ContractScopeManagementSection({
 required this.scopes,
 required this.canStartProcess,
 required this.startedScopeCount,
 required this.onStartProcessForScope,
 });

 final List<ProcurementItemModel> scopes;
 final bool canStartProcess;
 final int startedScopeCount;
 final ValueChanged<ProcurementItemModel> onStartProcessForScope;

 @override
 Widget build(BuildContext context) {
 final roleLabel = canStartProcess
 ? 'Authorized to commence procurement'
 : 'View only at this stage';

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Contract Scope Management',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: canStartProcess
 ? const Color(0xFFE8FFF4)
 : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: canStartProcess
 ? const Color(0xFF34D399)
 : const Color(0xFFE2E8F0),
 ),
 ),
 child: Text(
 roleLabel,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: canStartProcess
 ? const Color(0xFF047857)
 : const Color(0xFF64748B),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 const Text(
 'Start process for each scope only when this initiation-stage procurement should commence.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 6),
 Text(
 '$startedScopeCount of ${scopes.length} scopes started',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF1D4ED8),
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 16),
 if (scopes.isEmpty)
 const _EmptyStateCard(
 icon: Icons.inventory_2_outlined,
 title: 'No scopes available yet',
 message:
 'Add procurement items to create scope-level start controls.',
 compact: true,
 )
 else
 Column(
 children: [
 for (var i = 0; i < scopes.length; i++) ...[
 _ContractScopeRow(
 scope: scopes[i],
 canStartProcess: canStartProcess,
 onStartProcessForScope: () => onStartProcessForScope(
 scopes[i],
 ),
 ),
 if (i != scopes.length - 1)
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 ],
 ],
 ),
 ],
 ),
 );
 }
}

class _ContractScopeRow extends StatelessWidget {
 const _ContractScopeRow({
 required this.scope,
 required this.canStartProcess,
 required this.onStartProcessForScope,
 });

 final ProcurementItemModel scope;
 final bool canStartProcess;
 final VoidCallback onStartProcessForScope;

 @override
 Widget build(BuildContext context) {
 final started = scope.status != ProcurementItemStatus.planning;
 final canStart = canStartProcess && !started;
 final isMobile = AppBreakpoints.isMobile(context);

 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 14),
 child: isMobile
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 scope.name.trim().isEmpty ? 'Untitled Scope' : scope.name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 scope.description.trim().isEmpty
 ? 'No scope details yet.'
 : scope.description,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Category: ${scope.category.trim().isEmpty ? 'Uncategorized' : scope.category}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Status: ${scope.status.label}',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: started
 ? const Color(0xFF16A34A)
 : const Color(0xFF64748B),
 ),
 ),
 const SizedBox(height: 10),
 _scopeActionWidget(started, canStart),
 ],
 )
 : Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 scope.name.trim().isEmpty
 ? 'Untitled Scope'
 : scope.name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 scope.description.trim().isEmpty
 ? 'No scope details yet.'
 : scope.description,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 1,
 child: Text(
 scope.category.trim().isEmpty
 ? 'Uncategorized'
 : scope.category,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF475569)),
 ),
 ),
 Expanded(
 flex: 1,
 child: Text(
 scope.status.label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: started
 ? const Color(0xFF16A34A)
 : const Color(0xFF64748B),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.centerRight,
 child: _scopeActionWidget(started, canStart),
 ),
 ),
 ],
 ),
 );
 }

 Widget _scopeActionWidget(bool started, bool canStart) {
 if (started) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFE8FFF4),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFBBF7D0)),
 ),
 child: const Text(
 'Started',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF15803D),
 ),
 ),
 );
 }
 return ElevatedButton(
 onPressed: canStart ? onStartProcessForScope : null,
 style: ElevatedButton.styleFrom(
 backgroundColor:
 canStart ? const Color(0xFFF6C437) : const Color(0xFFE2E8F0),
 foregroundColor:
 canStart ? const Color(0xFF111827) : const Color(0xFF64748B),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 child: const Text(
 'Start Process for this Scope',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 );
 }
}

class _PlanHeader extends StatelessWidget {
 const _PlanHeader({required this.onItemListTap});

 final VoidCallback onItemListTap;

 @override
 Widget build(BuildContext context) {
 final projectName = ProjectDataHelper.getData(context).projectName.trim();
 final title = projectName.isEmpty
 ? 'Procurement Plan'
 : '$projectName Procurement Plan';

 return Row(
 children: [
 Expanded(
 child: Row(
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(width: 8),
 const Icon(Icons.lock_outline,
 size: 18, color: Color(0xFF6B7280)),
 ],
 ),
 ),
 OutlinedButton(
 onPressed: onItemListTap,
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 foregroundColor: const Color(0xFF0F172A),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Scope Details'),
 ),
 ],
 );
 }
}

class _ItemsListView extends StatelessWidget {
 const _ItemsListView({
 required this.items,
 required this.trackableItems,
 required this.selectedIndex,
 required this.onSelectTrackable,
 required this.currencyFormat,
 required this.onAddItem,
 required this.onEditItem,
 required this.onDeleteItem,
 });

 final List<ProcurementItemModel> items;
 final List<ProcurementItemModel> trackableItems;
 final int selectedIndex;
 final ValueChanged<int> onSelectTrackable;
 final NumberFormat currencyFormat;
 final VoidCallback onAddItem;
 final ValueChanged<ProcurementItemModel> onEditItem;
 final ValueChanged<ProcurementItemModel> onDeleteItem;

 @override
 Widget build(BuildContext context) {
 final totalItems = items.length;
 final criticalItems = items
 .where((item) => item.priority == ProcurementPriority.critical)
 .length;
 final pendingApprovals = items
 .where((item) =>
 item.status == ProcurementItemStatus.vendorSelection &&
 item.priority == ProcurementPriority.critical)
 .length;
 final totalBudget =
 items.fold<int>(0, (value, item) => value + item.budget.toInt());
 final selectedTrackable =
 (selectedIndex >= 0 && selectedIndex < trackableItems.length)
 ? trackableItems[selectedIndex]
 : null;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SummaryMetricsRow(
 totalItems: totalItems,
 criticalItems: criticalItems,
 pendingApprovals: pendingApprovals,
 totalBudgetLabel: currencyFormat.format(totalBudget),
 ),
 const SizedBox(height: 24),
 _ItemsToolbar(onAddItem: onAddItem),
 const SizedBox(height: 20),
 _ItemsGrid(
 items: items,
 currencyFormat: currencyFormat,
 onAddItem: onAddItem,
 onEditItem: onEditItem,
 onDeleteItem: onDeleteItem,
 ),
 const SizedBox(height: 28),
 _TrackableAndTimeline(
 trackableItems: trackableItems,
 selectedIndex: selectedIndex,
 onSelectTrackable: onSelectTrackable,
 selectedItem: selectedTrackable,
 ),
 ],
 );
 }
}

class _SummaryMetricsRow extends StatelessWidget {
 const _SummaryMetricsRow({
 required this.totalItems,
 required this.criticalItems,
 required this.pendingApprovals,
 required this.totalBudgetLabel,
 });

 final int totalItems;
 final int criticalItems;
 final int pendingApprovals;
 final String totalBudgetLabel;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final cards = [
 _SummaryCard(
 icon: Icons.inventory_2_outlined,
 iconBackground: const Color(0xFFEFF6FF),
 value: '$totalItems',
 label: 'Total Items',
 ),
 _SummaryCard(
 icon: Icons.warning_amber_rounded,
 iconBackground: const Color(0xFFFFF7ED),
 value: '$criticalItems',
 label: 'Critical Items',
 valueColor: const Color(0xFFDC2626),
 ),
 _SummaryCard(
 icon: Icons.access_time,
 iconBackground: const Color(0xFFF5F3FF),
 value: '$pendingApprovals',
 label: 'Pending Approvals',
 valueColor: const Color(0xFF1F2937),
 ),
 _SummaryCard(
 icon: Icons.attach_money,
 iconBackground: const Color(0xFFECFEFF),
 value: totalBudgetLabel,
 label: 'Total Budget',
 valueColor: const Color(0xFF047857),
 ),
 ];

 if (isMobile) {
 return Column(
 children: [
 cards[0],
 const SizedBox(height: 12),
 cards[1],
 const SizedBox(height: 12),
 cards[2],
 const SizedBox(height: 12),
 cards[3],
 ],
 );
 }

 return Row(
 children: [
 for (var i = 0; i < cards.length; i++) ...[
 Expanded(child: cards[i]),
 if (i != cards.length - 1) const SizedBox(width: 16),
 ],
 ],
 );
 }
}

class _SummaryCard extends StatelessWidget {
 const _SummaryCard({
 required this.icon,
 required this.iconBackground,
 required this.value,
 required this.label,
 this.valueColor,
 });

 final IconData icon;
 final Color iconBackground;
 final String value;
 final String label;
 final Color? valueColor;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: iconBackground, borderRadius: BorderRadius.circular(12)),
 child: Icon(icon, color: const Color(0xFF1D4ED8)),
 ),
 const SizedBox(width: 16),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 value,
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: valueColor ?? const Color(0xFF0F172A)),
 ),
 const SizedBox(height: 4),
 Text(label,
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
 ],
 ),
 ],
 ),
 );
 }
}

class _ItemsToolbar extends StatelessWidget {
 const _ItemsToolbar({required this.onAddItem});

 final VoidCallback onAddItem;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);

 if (isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SearchField(),
 const SizedBox(height: 12),
 Row(
 children: const [
 Expanded(child: _DropdownField(label: 'All Categories')),
 SizedBox(width: 12),
 Expanded(child: _DropdownField(label: 'All Statuses')),
 ],
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerRight,
 child: _AddItemButton(onPressed: onAddItem),
 ),
 ],
 );
 }

 return Row(
 children: [
 const SizedBox(width: 320, child: _SearchField()),
 const SizedBox(width: 16),
 const SizedBox(
 width: 190, child: _DropdownField(label: 'All Categories')),
 const SizedBox(width: 16),
 const SizedBox(
 width: 190, child: _DropdownField(label: 'All Statuses')),
 const Spacer(),
 _AddItemButton(onPressed: onAddItem),
 ],
 );
 }
}

class _SearchField extends StatelessWidget {
 const _SearchField();

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: const VoiceTextField(
 decoration: InputDecoration(
 border: InputBorder.none,
 icon: Icon(Icons.search, color: Color(0xFF94A3B8)),
 hintText: 'Search items...',
 hintStyle: TextStyle(color: Color(0xFF94A3B8)),
 ),
 ),
 );
 }
}

class _DropdownField extends StatelessWidget {
 const _DropdownField({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 final options = label == 'All Categories'
 ? const ['All Categories', 'Materials', 'Equipment', 'Services']
 : const [
 'All Statuses',
 'Planning',
 'RFQ Review',
 'Vendor Selection',
 'Ordered',
 'Delivered'
 ];

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: label,
 icon: const Icon(Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF64748B)),
 items: options
 .map(
 (option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF334155))),
 ),
 )
 .toList(),
 onChanged: (_) {},
 ),
 ),
 );
 }
}

class _AddItemButton extends StatelessWidget {
 const _AddItemButton({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return ElevatedButton.icon(
 onPressed: onPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 icon: const Icon(Icons.add_rounded),
 label:
 const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
 );
 }
}

class _ItemsGrid extends StatelessWidget {
 const _ItemsGrid(
 {required this.items,
 required this.currencyFormat,
 required this.onAddItem,
 required this.onEditItem,
 required this.onDeleteItem});

 final List<ProcurementItemModel> items;
 final NumberFormat currencyFormat;
 final VoidCallback onAddItem;
 final ValueChanged<ProcurementItemModel> onEditItem;
 final ValueChanged<ProcurementItemModel> onDeleteItem;

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return _EmptyStateCard(
 icon: Icons.inventory_2_outlined,
 title: 'No procurement items yet',
 message:
 'Add items to track budgets, approvals, and delivery timelines.',
 actionLabel: 'Add Item',
 onAction: onAddItem,
 );
 }

 return LayoutBuilder(builder: (context, constraints) {
 final double width = constraints.maxWidth;
 int columns = 1;
 if (width > 1200) {
 columns = 3;
 } else if (width > 800) {
 columns = 2;
 }

 final double cardWidth = (width - ((columns - 1) * 24)) / columns;

 return Wrap(
 spacing: 24,
 runSpacing: 24,
 children: List<Widget>.generate(items.length, (index) {
 final item = items[index];
 return SizedBox(
 width: cardWidth,
 child: _ProcurementItemCard(
 item: item,
 itemNumberLabel: 'ITM-${(index + 1).toString().padLeft(3, '0')}',
 currencyFormat: currencyFormat,
 onEdit: () => onEditItem(item),
 onDelete: () => onDeleteItem(item),
 ),
 );
 }),
 );
 });
 }
}

class _ProcurementItemCard extends StatelessWidget {
 const _ProcurementItemCard({
 required this.item,
 required this.itemNumberLabel,
 required this.currencyFormat,
 required this.onEdit,
 required this.onDelete,
 });

 final ProcurementItemModel item;
 final String itemNumberLabel;
 final NumberFormat currencyFormat;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 final dateLabel = item.estimatedDelivery != null
 ? DateFormat('MMM d, yyyy').format(item.estimatedDelivery!)
 : 'TBD';
 final progressLabel = '${(item.progress * 100).round()}%';

 Color progressColor;
 if (item.progress >= 1.0) {
 progressColor = const Color(0xFF10B981);
 } else if (item.progress >= 0.5) {
 progressColor = const Color(0xFF2563EB);
 } else if (item.progress == 0) {
 progressColor = const Color(0xFFD1D5DB);
 } else {
 progressColor = const Color(0xFF38BDF8);
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
 ],
 ),
 padding: const EdgeInsets.all(20),
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
 itemNumberLabel,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 item.name,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 4),
 Text(
 item.category,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 _BadgePill(
 label: item.status.label,
 background: item.status.backgroundColor,
 border: item.status.borderColor,
 foreground: item.status.textColor,
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 item.description,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 _MetricItem(
 label: 'Budget',
 value: currencyFormat.format(item.budget),
 ),
 const SizedBox(width: 24),
 _MetricItem(label: 'Delivery', value: dateLabel),
 ],
 ),
 const SizedBox(height: 16),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('Progress',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 Text(progressLabel,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: progressColor)),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: item.progress.clamp(0, 1).toDouble(),
 minHeight: 6,
 backgroundColor: Colors.white,
 valueColor: AlwaysStoppedAnimation<Color>(progressColor),
 ),
 ),
 ],
 ),
 const SizedBox(height: 18),
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 const SizedBox(height: 14),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _BadgePill(
 label: item.priority.label,
 background: item.priority.backgroundColor,
 border: item.priority.borderColor,
 foreground: item.priority.textColor,
 ),
 Row(
 children: [
 _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit),
 const SizedBox(width: 8),
 PopupMenuButton<String>(
 onSelected: (value) {
 if (value == 'edit') {
 onEdit();
 } else if (value == 'delete') {
 onDelete();
 }
 },
 itemBuilder: (_) => const [
 PopupMenuItem(value: 'edit', child: Text('Edit item')),
 PopupMenuItem(
 value: 'delete', child: Text('Remove item')),
 ],
 child: const _ActionIcon(icon: Icons.more_horiz_rounded),
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _MetricItem extends StatelessWidget {
 const _MetricItem({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
 const SizedBox(height: 2),
 Text(value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF334155))),
 ],
 );
 }
}

class _BadgePill extends StatelessWidget {
 const _BadgePill({
 required this.label,
 required this.background,
 required this.border,
 required this.foreground,
 });

 final String label;
 final Color background;
 final Color border;
 final Color foreground;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: border),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
 ),
 );
 }
}

class _ActionIcon extends StatelessWidget {
 const _ActionIcon({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, size: 18, color: const Color(0xFF475569)),
 ),
 );
 }
}

class _TrackableAndTimeline extends StatelessWidget {
 const _TrackableAndTimeline({
 required this.trackableItems,
 required this.selectedIndex,
 required this.onSelectTrackable,
 required this.selectedItem,
 });

 final List<ProcurementItemModel> trackableItems;
 final int selectedIndex;
 final ValueChanged<int> onSelectTrackable;
 final ProcurementItemModel? selectedItem;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);

 if (isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _TrackableItemsCard(
 trackableItems: trackableItems,
 selectedIndex: selectedIndex,
 onSelectTrackable: onSelectTrackable,
 ),
 const SizedBox(height: 20),
 _TrackingTimelineCard(item: selectedItem),
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: _TrackableItemsCard(
 trackableItems: trackableItems,
 selectedIndex: selectedIndex,
 onSelectTrackable: onSelectTrackable,
 ),
 ),
 const SizedBox(width: 24),
 Expanded(
 flex: 2,
 child: _TrackingTimelineCard(item: selectedItem),
 ),
 ],
 );
 }
}

class _TrackableItemsCard extends StatelessWidget {
 const _TrackableItemsCard(
 {required this.trackableItems,
 required this.selectedIndex,
 required this.onSelectTrackable});

 final List<ProcurementItemModel> trackableItems;
 final int selectedIndex;
 final ValueChanged<int> onSelectTrackable;

 @override
 Widget build(BuildContext context) {
 if (trackableItems.isEmpty) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(24),
 child: const _EmptyStateBody(
 icon: Icons.local_shipping_outlined,
 title: 'No trackable items yet',
 message: 'Add procurement items to begin shipment tracking.',
 compact: true,
 ),
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
 child: Text(
 'Trackable Items',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 const Divider(height: 1, color: Color(0xFFE2E8F0)),
 for (var i = 0; i < trackableItems.length; i++)
 _TrackableRow(
 item: trackableItems[i],
 selected: i == selectedIndex,
 onTap: () => onSelectTrackable(i),
 showDivider: i != trackableItems.length - 1,
 ),
 ],
 ),
 );
 }
}

class _TrackableRow extends StatelessWidget {
 const _TrackableRow(
 {required this.item,
 required this.selected,
 required this.onTap,
 required this.showDivider});

 final ProcurementItemModel item;
 final bool selected;
 final VoidCallback onTap;
 final bool showDivider;

 @override
 Widget build(BuildContext context) {
 final lastUpdateLabel = DateFormat('M/d/yyyy').format(item.updatedAt);

 return Material(
 color: selected ? const Color(0xFFF8FAFC) : Colors.white,
 child: InkWell(
 onTap: onTap,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
 child: Column(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.inventory_2_outlined,
 size: 20, color: Color(0xFF2563EB)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 item.name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(item.description,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(
 item.status.label.toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF334155)),
 ),
 ),
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.centerLeft,
 child: _BadgePill(
 label: item.status.label,
 background: item.status.backgroundColor,
 border: item.status.borderColor,
 foreground: item.status.textColor,
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(lastUpdateLabel,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF334155))),
 ),
 const _UpdateButton(),
 ],
 ),
 if (showDivider) const SizedBox(height: 18),
 if (showDivider)
 const Divider(height: 1, color: Color(0xFFE2E8F0)),
 ],
 ),
 ),
 ),
 );
 }
}

class _UpdateButton extends StatelessWidget {
 const _UpdateButton();

 @override
 Widget build(BuildContext context) {
 return ElevatedButton(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Tracking updates are applied from the status and progress controls above.',
 ),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF1F2937),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 elevation: 0,
 ),
 child: const Text('Update',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 );
 }
}

class _TrackingTimelineCard extends StatelessWidget {
 const _TrackingTimelineCard({required this.item});

 final ProcurementItemModel? item;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
 child: item == null
 ? const Center(
 child: Text(
 'Select an item to view tracking timeline.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 )
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Tracking Timeline',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 16),
 Text(
 item!.name,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 6),
 const Text(
 'Click on an item to view its tracking timeline',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 _BadgePill(
 label: item!.status.label,
 background: item!.status.backgroundColor,
 border: item!.status.borderColor,
 foreground: item!.status.textColor,
 ),
 const SizedBox(height: 16),
 for (final event in item!.events) ...[
 _TimelineEntry(event: event),
 const SizedBox(height: 16),
 ],
 ],
 ),
 );
 }
}

class _TimelineEntry extends StatelessWidget {
 const _TimelineEntry({required this.event});

 final ProcurementEvent event;

 @override
 Widget build(BuildContext context) {
 final dateLabel = DateFormat('M/d/yyyy').format(event.date);

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(999),
 ),
 child: const Icon(Icons.local_shipping_outlined,
 size: 18, color: Color(0xFF2563EB)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 event.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 6),
 Text(
 event.description,
 style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
 ),
 const SizedBox(height: 6),
 Text(
 event.subtext,
 style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
 ),
 const SizedBox(height: 6),
 Text(
 dateLabel,
 style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _ProcurementStrategiesSection extends StatelessWidget {
 const _ProcurementStrategiesSection({
 required this.strategies,
 required this.onAddStrategy,
 required this.onEditStrategy,
 required this.onDeleteStrategy,
 });

 final List<ProcurementStrategyModel> strategies;
 final VoidCallback onAddStrategy;
 final ValueChanged<ProcurementStrategyModel> onEditStrategy;
 final ValueChanged<ProcurementStrategyModel> onDeleteStrategy;

 String _statusLabel(StrategyStatus status) {
 switch (status) {
 case StrategyStatus.draft:
 return 'Draft';
 case StrategyStatus.active:
 return 'Active';
 case StrategyStatus.complete:
 return 'Complete';
 }
 }

 Color _statusBackground(StrategyStatus status) {
 switch (status) {
 case StrategyStatus.draft:
 return const Color(0xFFF1F5F9);
 case StrategyStatus.active:
 return const Color(0xFFEFF6FF);
 case StrategyStatus.complete:
 return const Color(0xFFE8FFF4);
 }
 }

 Color _statusForeground(StrategyStatus status) {
 switch (status) {
 case StrategyStatus.draft:
 return const Color(0xFF64748B);
 case StrategyStatus.active:
 return const Color(0xFF2563EB);
 case StrategyStatus.complete:
 return const Color(0xFF047857);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Procurement Strategies',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 OutlinedButton.icon(
 onPressed: onAddStrategy,
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('+ Add Strategy'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text(
 'Define and maintain procurement strategy rows manually or refine AI-seeded entries.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 14),
 if (strategies.isEmpty)
 _EmptyStateCard(
 icon: Icons.view_list_outlined,
 title: 'No procurement strategies yet',
 message:
 'Click "+ Add Strategy" to create your first procurement strategy.',
 actionLabel: 'Add Strategy',
 onAction: onAddStrategy,
 )
 else
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Scrollbar(
 thumbVisibility: true,
 scrollbarOrientation: ScrollbarOrientation.bottom,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: const BoxConstraints(minWidth: 920),
 child: Table(
 border: const TableBorder(
 horizontalInside: BorderSide(color: Color(0xFFE5E7EB)),
 verticalInside: BorderSide(color: Color(0xFFE5E7EB)),
 ),
 columnWidths: const {
 0: FixedColumnWidth(260),
 1: FixedColumnWidth(230),
 2: FixedColumnWidth(170),
 3: FixedColumnWidth(140),
 4: FixedColumnWidth(120),
 },
 children: [
 const TableRow(
 decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
 children: [
 _ScopeHeaderCell('Strategy Name'),
 _ScopeHeaderCell('Category'),
 _ScopeHeaderCell('Status'),
 _ScopeHeaderCell('Items'),
 _ScopeHeaderCell('Actions'),
 ],
 ),
 ...strategies.map((strategy) {
 return TableRow(
 children: [
 _ScopeValueCell(strategy.title.trim().isEmpty
 ? '-'
 : strategy.title.trim()),
 _ScopeValueCell(strategy.category.trim().isEmpty
 ? '-'
 : strategy.category.trim()),
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 12),
 child: Align(
 alignment: Alignment.centerLeft,
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: _statusBackground(strategy.status),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 _statusLabel(strategy.status),
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: _statusForeground(strategy.status),
 ),
 ),
 ),
 ),
 ),
 _ScopeValueCell('${strategy.itemCount}'),
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 6, vertical: 6),
 child: Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined,
 size: 18),
 tooltip: 'Edit Strategy',
 onPressed: () => onEditStrategy(strategy),
 ),
 IconButton(
 icon: const Icon(
 Icons.delete_outline_rounded,
 size: 18,
 color: Color(0xFFDC2626)),
 tooltip: 'Delete Strategy',
 onPressed: () => onDeleteStrategy(strategy),
 ),
 ],
 ),
 ),
 ],
 );
 }),
 ],
 ),
 ),
 ),
 ),
 ),
 ],
 );
 }
}

class _StrategiesSection extends StatelessWidget {
 const _StrategiesSection({
 required this.items,
 required this.currencyFormat,
 required this.onAddScope,
 });

 final List<ProcurementItemModel> items;
 final NumberFormat currencyFormat;
 final VoidCallback onAddScope;

 bool _isLongLead(ProcurementItemModel item) {
 return item.priority == ProcurementPriority.critical ||
 item.priority == ProcurementPriority.high ||
 item.category.toLowerCase().contains('logistics') ||
 item.category.toLowerCase().contains('material') ||
 item.category.toLowerCase().contains('equipment');
 }

 String _durationLabel(ProcurementItemModel item) {
 if (item.comments.trim().isNotEmpty) {
 return item.comments.trim();
 }
 if (item.estimatedDelivery == null) {
 return 'TBD';
 }
 final days = item.estimatedDelivery!.difference(DateTime.now()).inDays;
 if (days <= 0) return 'Due now';
 final weeks = (days / 7).ceil();
 return '$weeks week${weeks == 1 ? '' : 's'}';
 }

 String _contractTypeLabel(ProcurementItemModel item) {
 final normalized = item.projectPhase.trim().toLowerCase();
 if (normalized.contains('lump')) return 'Lump Sum';
 if (normalized.contains('reimb')) return 'Reimbursable';
 if (normalized.contains('unsure') || normalized.contains('unknown')) {
 return 'Unsure';
 }

 final category = item.category.trim().toLowerCase();
 if (category.contains('material') ||
 category.contains('equipment') ||
 category.contains('furniture') ||
 category.contains('logistics')) {
 return 'Lump Sum';
 }
 if (category.contains('service') ||
 category.contains('consult') ||
 category.contains('security')) {
 return 'Reimbursable';
 }
 return 'Unsure';
 }

 String _potentialVendors(ProcurementItemModel item) {
 if (item.notes.trim().isNotEmpty) {
 return item.notes.trim();
 }
 if ((item.vendorId ?? '').trim().isNotEmpty) {
 return 'Linked vendor';
 }
 return 'To be identified';
 }

 String _biddingRequired(ProcurementItemModel item) {
 final normalized = item.responsibleMember.trim().toLowerCase();
 if (normalized == 'yes') return 'Yes';
 if (normalized == 'no') return 'No';
 if (normalized == 'not sure' || normalized == 'unsure') return 'Not Sure';
 return _isLongLead(item) ? 'Yes' : 'Not Sure';
 }

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Procurement Scope',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 Text(
 '${items.length} ${items.length == 1 ? 'scope' : 'scopes'}',
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text(
 'Auto-generated from project context. Update rows for contract type, estimated duration, value, and bidding requirements.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 16),
 if (items.isEmpty)
 const _EmptyStateCard(
 icon: Icons.insights_outlined,
 title: 'No procurement scope rows yet',
 message:
 'Add procurement scope items to define potential vendors, contract type, estimated duration, value, and bidding requirements.',
 )
 else
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Scrollbar(
 thumbVisibility: true,
 scrollbarOrientation: ScrollbarOrientation.bottom,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: const BoxConstraints(minWidth: 1160),
 child: Table(
 border: const TableBorder(
 horizontalInside: BorderSide(color: Color(0xFFE5E7EB)),
 verticalInside: BorderSide(color: Color(0xFFE5E7EB)),
 ),
 columnWidths: const {
 0: FixedColumnWidth(50),
 1: FixedColumnWidth(230),
 2: FixedColumnWidth(290),
 3: FixedColumnWidth(200),
 4: FixedColumnWidth(140),
 5: FixedColumnWidth(150),
 6: FixedColumnWidth(150),
 7: FixedColumnWidth(140),
 },
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 children: [
 const TableRow(
 decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
 children: [
 _ScopeHeaderCell('No'),
 _ScopeHeaderCell('Procurement Item'),
 _ScopeHeaderCell('Description'),
 _ScopeHeaderCell('Potential Vendors'),
 _ScopeHeaderCell('Contract Type'),
 _ScopeHeaderCell('Estimated Duration'),
 _ScopeHeaderCell('Estimated Value'),
 _ScopeHeaderCell('Bidding Required'),
 ],
 ),
 ...List<TableRow>.generate(items.length, (index) {
 final item = items[index];
 return TableRow(
 children: [
 _ScopeValueCell('${index + 1}'),
 _ScopeValueCell(item.name.trim().isEmpty
 ? 'Untitled scope'
 : item.name.trim()),
 _ScopeValueCell(item.description.trim().isEmpty
 ? '-'
 : item.description.trim()),
 _ScopeValueCell(_potentialVendors(item)),
 _ScopeValueCell(_contractTypeLabel(item)),
 _ScopeValueCell(_durationLabel(item)),
 _ScopeValueCell(currencyFormat.format(item.budget)),
 _ScopeValueCell(_biddingRequired(item)),
 ],
 );
 }),
 ],
 ),
 ),
 ),
 ),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: onAddScope,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 ),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add Scope Row'),
 )),
 ],
 );
 }
}

class _ScopeHeaderCell extends StatelessWidget {
 const _ScopeHeaderCell(this.text);
 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF334155),
 ),
 ),
 );
 }
}

class _ScopeValueCell extends StatelessWidget {
 const _ScopeValueCell(this.text);
 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
 child: Text(
 text.isEmpty ? '-' : text,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF0F172A),
 ),
 ),
 );
 }
}

class _VendorsSection extends StatelessWidget {
 const _VendorsSection({
 required this.vendors,
 required this.allVendorsCount,
 required this.selectedVendorIds,
 required this.approvedOnly,
 required this.preferredOnly,
 required this.listView,
 required this.categoryFilter,
 required this.categoryOptions,
 required this.onApprovedChanged,
 required this.onPreferredChanged,
 required this.onCategoryChanged,
 required this.onViewModeChanged,
 required this.onToggleVendorSelected,
 required this.onEditVendor,
 required this.onDeleteVendor,
 required this.onOpenApprovedVendorList,
 this.onAddVendor,
 });

 final List<VendorModel> vendors;
 final int allVendorsCount;
 final Set<String> selectedVendorIds;
 final bool approvedOnly;
 final bool preferredOnly;
 final bool listView;
 final String categoryFilter;
 final List<String> categoryOptions;
 final ValueChanged<bool> onApprovedChanged;
 final ValueChanged<bool> onPreferredChanged;
 final ValueChanged<String> onCategoryChanged;
 final ValueChanged<bool> onViewModeChanged;
 final void Function(String vendorId, bool selected) onToggleVendorSelected;
 final ValueChanged<VendorModel> onEditVendor;
 final ValueChanged<String> onDeleteVendor;
 final VoidCallback onOpenApprovedVendorList;
 final VoidCallback? onAddVendor;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Vendors',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 Text(
 '${vendors.length} of $allVendorsCount vendors',
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 OutlinedButton.icon(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Use the Approved, Preferred, and Category filters to refine vendors.',
 ),
 ),
 );
 },
 icon: const Icon(Icons.filter_alt_outlined, size: 18),
 label: const Text('Filters'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 FilterChip(
 label: const Text('Approved Only'),
 selected: approvedOnly,
 onSelected: onApprovedChanged,
 selectedColor: const Color(0xFFEFF6FF),
 showCheckmark: false,
 labelStyle: TextStyle(
 color: approvedOnly
 ? const Color(0xFF2563EB)
 : const Color(0xFF475569),
 fontWeight: FontWeight.w600,
 ),
 ),
 FilterChip(
 label: const Text('Preferred Only'),
 selected: preferredOnly,
 onSelected: onPreferredChanged,
 selectedColor: const Color(0xFFF1F5F9),
 showCheckmark: false,
 labelStyle: TextStyle(
 color: preferredOnly
 ? const Color(0xFF2563EB)
 : const Color(0xFF475569),
 fontWeight: FontWeight.w600,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: categoryFilter,
 items: categoryOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) onCategoryChanged(value);
 },
 ),
 ),
 ),
 const SizedBox(width: 12),
 ToggleButtons(
 borderRadius: BorderRadius.circular(12),
 constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
 isSelected: [listView, !listView],
 onPressed: (index) => onViewModeChanged(index == 0),
 children: const [
 Icon(Icons.view_list_rounded, size: 20),
 Icon(Icons.grid_view_rounded, size: 20),
 ],
 ),
 OutlinedButton.icon(
 onPressed: onOpenApprovedVendorList,
 icon: const Icon(Icons.visibility_outlined, size: 18),
 label: const Text('View Company Approved Vendor List'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 if (vendors.isEmpty)
 _EmptyStateCard(
 icon: Icons.storefront_outlined,
 title: allVendorsCount == 0 ? 'No vendors yet' : 'No vendors match',
 message: allVendorsCount == 0
 ? 'Add your first vendor to track approvals, ratings, and performance.'
 : 'Adjust filters or add new vendors to expand coverage.',
 actionLabel: allVendorsCount == 0 ? 'Add Vendor' : null,
 onAction: onAddVendor,
 )
 else if (listView)
 _VendorDataTable(
 vendors: vendors,
 selectedVendorIds: selectedVendorIds,
 onToggleSelected: onToggleVendorSelected,
 onEditVendor: onEditVendor,
 onDeleteVendor: onDeleteVendor,
 )
 else
 _VendorGrid(
 vendors: vendors,
 selectedVendorIds: selectedVendorIds,
 onToggleSelected: onToggleVendorSelected,
 onEditVendor: onEditVendor,
 onDeleteVendor: onDeleteVendor,
 ),
 ],
 );
 }
}

class _ApprovedVendorsSection extends StatelessWidget {
 const _ApprovedVendorsSection({required this.approvedVendors});

 final List<VendorModel> approvedVendors;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Approved Vendors',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Text(
 '${approvedVendors.length}',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (approvedVendors.isEmpty)
 const _EmptyStateCard(
 icon: Icons.verified_user_outlined,
 title: 'No approved vendors yet',
 message:
 'Approved vendors appear here once vendor status is set to Active or Approved.',
 compact: true,
 )
 else
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 for (var i = 0; i < approvedVendors.length; i++) ...[
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 14,
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(
 approvedVendors[i].name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(
 approvedVendors[i].category,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: _RatingStars(
 rating: approvedVendors[i].ratingScore,
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(
 approvedVendors[i].nextReview.trim().isEmpty
 ? 'Review date N/A'
 : approvedVendors[i].nextReview,
 textAlign: TextAlign.end,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ],
 ),
 ),
 if (i != approvedVendors.length - 1)
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 ],
 ],
 ),
 ),
 ],
 );
 }
}

class _VendorDataTable extends StatelessWidget {
 const _VendorDataTable({
 required this.vendors,
 required this.selectedVendorIds,
 required this.onToggleSelected,
 required this.onEditVendor,
 required this.onDeleteVendor,
 });

 final List<VendorModel> vendors;
 final Set<String> selectedVendorIds;
 final void Function(String vendorId, bool selected) onToggleSelected;
 final ValueChanged<VendorModel> onEditVendor;
 final ValueChanged<String> onDeleteVendor;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Scrollbar(
 thumbVisibility: true,
 scrollbarOrientation: ScrollbarOrientation.bottom,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: buildNduDataTable(
 context: context,
 columnSpacing: 18,
 horizontalMargin: 24,
 headingTextStyle: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569)),
 dataTextStyle:
 const TextStyle(fontSize: 14, color: Color(0xFF111827)),
 showCheckboxColumn: false,
 columns: const [
 DataColumn(label: Center(child: SizedBox(width: 24))),
 DataColumn(label: Center(child: Text('Vendor Name'))),
 DataColumn(label: Center(child: Text('Category'))),
 DataColumn(label: Center(child: Text('Status'))),
 DataColumn(label: Center(child: Text('Contact'))),
 DataColumn(label: Center(child: Text('Rating'))),
 DataColumn(label: Center(child: Text('Actions'))),
 ],
 rows: vendors
 .map(
 (vendor) => DataRow(
 cells: [
 DataCell(
 Checkbox(
 value: selectedVendorIds.contains(vendor.id),
 onChanged: (value) =>
 onToggleSelected(vendor.id, value ?? false),
 ),
 ),
 DataCell(_VendorNameCell(vendor: vendor)),
 DataCell(Text(vendor.category)),
 DataCell(_VendorStatusPill(status: vendor.status)),
 DataCell(Text(vendor.contactLabel)),
 DataCell(_RatingStars(rating: vendor.ratingScore)),
 DataCell(_VendorActionsMenu(
 vendor: vendor,
 onEdit: () => onEditVendor(vendor),
 onDelete: () => onDeleteVendor(vendor.id),
 )),
 ],
 ),
 )
 .toList(),
 ),
 ),
 ),
 ),
 );
 },
 );
 }
}

class _VendorGrid extends StatelessWidget {
 const _VendorGrid({
 required this.vendors,
 required this.selectedVendorIds,
 required this.onToggleSelected,
 required this.onEditVendor,
 required this.onDeleteVendor,
 });

 final List<VendorModel> vendors;
 final Set<String> selectedVendorIds;
 final void Function(String vendorId, bool selected) onToggleSelected;
 final ValueChanged<VendorModel> onEditVendor;
 final ValueChanged<String> onDeleteVendor;

 @override
 Widget build(BuildContext context) {
 return GridView.builder(
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: 3,
 childAspectRatio: 3.2,
 mainAxisSpacing: 16,
 crossAxisSpacing: 16,
 ),
 itemCount: vendors.length,
 itemBuilder: (_, index) {
 final vendor = vendors[index];
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Align(
 alignment: Alignment.centerRight,
 child: Checkbox(
 value: selectedVendorIds.contains(vendor.id),
 onChanged: (value) =>
 onToggleSelected(vendor.id, value ?? false),
 ),
 ),
 _VendorNameCell(vendor: vendor),
 const SizedBox(height: 8),
 Text(vendor.category,
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
 const SizedBox(height: 8),
 _VendorStatusPill(status: vendor.status),
 const SizedBox(height: 6),
 Text(
 vendor.contactLabel,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 8),
 _RatingStars(rating: vendor.ratingScore),
 const Spacer(),
 Row(
 children: [
 const Spacer(),
 _VendorActionsMenu(
 vendor: vendor,
 onEdit: () => onEditVendor(vendor),
 onDelete: () => onDeleteVendor(vendor.id),
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

class _VendorActionsMenu extends StatelessWidget {
 const _VendorActionsMenu({
 required this.vendor,
 required this.onEdit,
 required this.onDelete,
 });

 final VendorModel vendor;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return PopupMenuButton<String>(
 icon: const Icon(Icons.more_horiz_rounded),
 onSelected: (value) {
 if (value == 'edit') {
 onEdit();
 } else if (value == 'delete') {
 onDelete();
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(value: 'edit', child: Text('Edit vendor')),
 PopupMenuItem(value: 'delete', child: Text('Remove vendor')),
 ],
 );
 }
}

class _VendorNameCell extends StatelessWidget {
 const _VendorNameCell({required this.vendor});

 final VendorModel vendor;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFE2E8F0),
 child: Text(
 vendor.name.substring(0, 2).toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 ),
 const SizedBox(width: 12),
 Flexible(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 vendor.name,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 2),
 Text(
 vendor.contactLabel,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _RatingStars extends StatelessWidget {
 const _RatingStars({required this.rating});

 final int rating;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: List.generate(
 5,
 (index) => Icon(
 index < rating ? Icons.star_rounded : Icons.star_border_rounded,
 color: const Color(0xFFFACC15),
 size: 18,
 ),
 ),
 );
 }
}

class _YesNoBadge extends StatelessWidget {
 const _YesNoBadge({required this.value, this.showStar = false});

 final bool value;
 final bool showStar;

 @override
 Widget build(BuildContext context) {
 final Color background =
 value ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC);
 final Color foreground =
 value ? const Color(0xFF2563EB) : const Color(0xFF64748B);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: value ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(value ? 'Yes' : 'No',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: foreground)),
 if (showStar) ...[
 const SizedBox(width: 6),
 Icon(value ? Icons.star_rounded : Icons.star_border_rounded,
 size: 16, color: foreground),
 ],
 ],
 ),
 );
 }
}

class _VendorStatusPill extends StatelessWidget {
 const _VendorStatusPill({required this.status});

 final String status;

 @override
 Widget build(BuildContext context) {
 final normalized = status.trim().toLowerCase();
 Color tone;
 if (normalized.contains('active') || normalized.contains('approved')) {
 tone = const Color(0xFF16A34A);
 } else if (normalized.contains('watch') ||
 normalized.contains('pending') ||
 normalized.contains('review')) {
 tone = const Color(0xFFF59E0B);
 } else if (normalized.contains('blocked') ||
 normalized.contains('denied') ||
 normalized.contains('inactive')) {
 tone = const Color(0xFFDC2626);
 } else {
 tone = const Color(0xFF64748B);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: tone.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: tone.withOpacity(0.35)),
 ),
 child: Text(
 status.trim().isEmpty ? 'Unknown' : status.trim(),
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: tone,
 ),
 ),
 );
 }
}

class _PriorityPill extends StatelessWidget {
 const _PriorityPill({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 final normalized = label.toLowerCase();
 Color tone;
 if (normalized.contains('critical')) {
 tone = const Color(0xFFDC2626);
 } else if (normalized.contains('high')) {
 tone = const Color(0xFFF59E0B);
 } else if (normalized.contains('low')) {
 tone = const Color(0xFF64748B);
 } else {
 tone = const Color(0xFF2563EB);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: tone.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: tone.withOpacity(0.35)),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: tone,
 ),
 ),
 );
 }
}

class _VendorManagementView extends StatelessWidget {
 const _VendorManagementView({
 required this.vendors,
 required this.allVendors,
 required this.selectedVendorIds,
 required this.approvedOnly,
 required this.preferredOnly,
 required this.listView,
 required this.categoryFilter,
 required this.categoryOptions,
 required this.healthMetrics,
 required this.onboardingTasks,
 required this.riskItems,
 required this.onAddVendor,
 required this.onInviteVendor,
 required this.onApprovedChanged,
 required this.onPreferredChanged,
 required this.onCategoryChanged,
 required this.onViewModeChanged,
 required this.onToggleVendorSelected,
 required this.onEditVendor,
 required this.onDeleteVendor,
 required this.onOpenApprovedVendorList,
 });

 final List<VendorModel> vendors;
 final List<VendorModel> allVendors;
 final Set<String> selectedVendorIds;
 final bool approvedOnly;
 final bool preferredOnly;
 final bool listView;
 final String categoryFilter;
 final List<String> categoryOptions;
 final List<_VendorHealthMetric> healthMetrics;
 final List<_VendorOnboardingTask> onboardingTasks;
 final List<_VendorRiskItem> riskItems;
 final VoidCallback onAddVendor;
 final VoidCallback onInviteVendor;
 final ValueChanged<bool> onApprovedChanged;
 final ValueChanged<bool> onPreferredChanged;
 final ValueChanged<String> onCategoryChanged;
 final ValueChanged<bool> onViewModeChanged;
 final void Function(String vendorId, bool selected) onToggleVendorSelected;
 final ValueChanged<VendorModel> onEditVendor;
 final ValueChanged<String> onDeleteVendor;
 final VoidCallback onOpenApprovedVendorList;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final totalVendors = allVendors.length;
 final preferredCount =
 allVendors.where((vendor) => vendor.isPreferred).length;
 final avgRating = totalVendors == 0
 ? 0
 : allVendors.fold<int>(
 0, (total, vendor) => total + vendor.ratingScore) /
 totalVendors;
 final preferredRate =
 totalVendors == 0 ? 0 : (preferredCount / totalVendors * 100).round();

 final metricCards = [
 _SummaryCard(
 icon: Icons.inventory_2_outlined,
 iconBackground: const Color(0xFFEFF6FF),
 value: '$totalVendors',
 label: 'Active Vendors',
 ),
 _SummaryCard(
 icon: Icons.star_outline,
 iconBackground: const Color(0xFFFFF7ED),
 value: '$preferredRate%',
 label: 'Preferred Coverage',
 valueColor: const Color(0xFFF97316),
 ),
 _SummaryCard(
 icon: Icons.thumb_up_alt_outlined,
 iconBackground: const Color(0xFFF1F5F9),
 value: avgRating.toStringAsFixed(1),
 label: 'Avg Rating',
 ),
 _SummaryCard(
 icon: Icons.shield_outlined,
 iconBackground: const Color(0xFFFFF1F2),
 value: '${riskItems.length}',
 label: 'Compliance Actions',
 valueColor: const Color(0xFFDC2626),
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Vendor Management',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 OutlinedButton.icon(
 onPressed: onInviteVendor,
 icon: const Icon(Icons.send_outlined, size: 18),
 label: const Text('Invite Vendor'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ElevatedButton.icon(
 onPressed: onAddVendor,
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add Vendor'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 metricCards[0],
 const SizedBox(height: 12),
 metricCards[1],
 const SizedBox(height: 12),
 metricCards[2],
 const SizedBox(height: 12),
 metricCards[3],
 ],
 )
 else
 Row(
 children: [
 for (var i = 0; i < metricCards.length; i++) ...[
 Expanded(child: metricCards[i]),
 if (i != metricCards.length - 1) const SizedBox(width: 16),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _VendorHealthCard(metrics: healthMetrics),
 const SizedBox(height: 16),
 _VendorOnboardingCard(tasks: onboardingTasks),
 const SizedBox(height: 16),
 _VendorRiskCard(riskItems: riskItems),
 ],
 )
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: _VendorHealthCard(metrics: healthMetrics)),
 const SizedBox(width: 16),
 Expanded(child: _VendorOnboardingCard(tasks: onboardingTasks)),
 const SizedBox(width: 16),
 Expanded(child: _VendorRiskCard(riskItems: riskItems)),
 ],
 ),
 const SizedBox(height: 24),
 _VendorsSection(
 vendors: vendors,
 allVendorsCount: allVendors.length,
 selectedVendorIds: selectedVendorIds,
 approvedOnly: approvedOnly,
 preferredOnly: preferredOnly,
 listView: listView,
 categoryFilter: categoryFilter,
 categoryOptions: categoryOptions,
 onAddVendor: onAddVendor,
 onApprovedChanged: onApprovedChanged,
 onPreferredChanged: onPreferredChanged,
 onCategoryChanged: onCategoryChanged,
 onViewModeChanged: onViewModeChanged,
 onToggleVendorSelected: onToggleVendorSelected,
 onEditVendor: onEditVendor,
 onDeleteVendor: onDeleteVendor,
 onOpenApprovedVendorList: onOpenApprovedVendorList,
 ),
 const SizedBox(height: 24),
 _ApprovedVendorsSection(
 approvedVendors:
 allVendors.where((vendor) => vendor.isApproved).toList(),
 ),
 ],
 );
 }
}

class _VendorHealthCard extends StatelessWidget {
 const _VendorHealthCard({required this.metrics});

 final List<_VendorHealthMetric> metrics;

 Color _scoreColor(double score) {
 if (score >= 0.85) return const Color(0xFF10B981);
 if (score >= 0.7) return const Color(0xFF2563EB);
 return const Color(0xFFF97316);
 }

 @override
 Widget build(BuildContext context) {
 if (metrics.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.health_and_safety_outlined,
 title: 'Vendor health by category',
 message:
 'Health metrics will appear once vendor performance is tracked.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Vendor health by category',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < metrics.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 metrics[i].category,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 '${(metrics[i].score * 100).round()}%',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: metrics[i].score,
 minHeight: 8,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation<Color>(
 _scoreColor(metrics[i].score)),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 metrics[i].change,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 if (i != metrics.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _VendorOnboardingCard extends StatelessWidget {
 const _VendorOnboardingCard({required this.tasks});

 final List<_VendorOnboardingTask> tasks;

 @override
 Widget build(BuildContext context) {
 if (tasks.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.assignment_turned_in_outlined,
 title: 'Onboarding pipeline',
 message: 'No onboarding tasks yet. Add vendors to start the pipeline.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Onboarding pipeline',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < tasks.length; i++) ...[
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 tasks[i].title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 4),
 Text(
 'Owner: ${tasks[i].owner} Â· Due ${DateFormat('M/d').format(DateTime.parse(tasks[i].dueDate))}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 _VendorTaskStatusPill(status: tasks[i].status),
 ],
 ),
 if (i != tasks.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _VendorRiskCard extends StatelessWidget {
 const _VendorRiskCard({required this.riskItems});

 final List<_VendorRiskItem> riskItems;

 @override
 Widget build(BuildContext context) {
 if (riskItems.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.shield_outlined,
 title: 'Risk watchlist',
 message: 'Risk items will appear once vendors are assessed.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Risk watchlist',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < riskItems.length; i++) ...[
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 riskItems[i].vendor,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 4),
 Text(
 riskItems[i].risk,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 4),
 Text(
 'Last incident: ${DateFormat('M/d').format(DateTime.parse(riskItems[i].lastIncident))}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 _RiskSeverityPill(severity: riskItems[i].severity),
 ],
 ),
 if (i != riskItems.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _VendorTaskStatusPill extends StatelessWidget {
 const _VendorTaskStatusPill({required this.status});

 final _VendorTaskStatus status;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: status.backgroundColor,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: status.borderColor),
 ),
 child: Text(
 status.label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: status.textColor),
 ),
 );
 }
}

class _RiskSeverityPill extends StatelessWidget {
 const _RiskSeverityPill({required this.severity});

 final _RiskSeverity severity;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: severity.backgroundColor,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: severity.borderColor),
 ),
 child: Text(
 severity.label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: severity.textColor),
 ),
 );
 }
}

class _RfqWorkflowView extends StatelessWidget {
 const _RfqWorkflowView({
 super.key,
 required this.scopeItems,
 required this.rfqs,
 required this.criteria,
 required this.currencyFormat,
 required this.customizeWorkflowByScope,
 required this.selectedScopeId,
 required this.workflowDisabledForSelection,
 required this.workflowTotalWeeks,
 required this.workflowSteps,
 required this.workflowLoading,
 required this.workflowSaving,
 required this.onCustomizeByScopeChanged,
 required this.onWorkflowScopeSelected,
 required this.onAddWorkflowStep,
 required this.onEditWorkflowStep,
 required this.onDeleteWorkflowStep,
 required this.onMoveWorkflowStep,
 required this.onResetWorkflow,
 required this.onSaveWorkflow,
 required this.onApplyWorkflowToAllScopes,
 required this.onCreateRfq,
 required this.onEditRfq,
 required this.onDeleteRfq,
 required this.onOpenTemplates,
 });

 final List<ProcurementItemModel> scopeItems;
 final List<RfqModel> rfqs;
 final List<_RfqCriterion> criteria;
 final NumberFormat currencyFormat;
 final bool customizeWorkflowByScope;
 final String? selectedScopeId;
 final bool workflowDisabledForSelection;
 final int workflowTotalWeeks;
 final List<_ProcurementWorkflowStep> workflowSteps;
 final bool workflowLoading;
 final bool workflowSaving;
 final ValueChanged<bool> onCustomizeByScopeChanged;
 final ValueChanged<String> onWorkflowScopeSelected;
 final VoidCallback onAddWorkflowStep;
 final ValueChanged<_ProcurementWorkflowStep> onEditWorkflowStep;
 final ValueChanged<String> onDeleteWorkflowStep;
 final void Function(int index, int direction) onMoveWorkflowStep;
 final VoidCallback onResetWorkflow;
 final VoidCallback onSaveWorkflow;
 final VoidCallback onApplyWorkflowToAllScopes;
 final VoidCallback onCreateRfq;
 final ValueChanged<RfqModel> onEditRfq;
 final ValueChanged<RfqModel> onDeleteRfq;
 final VoidCallback onOpenTemplates;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 ProcurementItemModel? selectedScope;
 if (selectedScopeId != null) {
 for (final item in scopeItems) {
 if (item.id == selectedScopeId) {
 selectedScope = item;
 break;
 }
 }
 }

 final totalInvited =
 rfqs.fold<int>(0, (total, rfq) => total + rfq.invitedCount);
 final totalResponses =
 rfqs.fold<int>(0, (total, rfq) => total + rfq.responseCount);
 final responseRate =
 totalInvited == 0 ? 0 : (totalResponses / totalInvited * 100).round();
 final inEvaluation =
 rfqs.where((rfq) => rfq.status == RfqStatus.evaluation).length;
 final pipelineValue =
 rfqs.fold<double>(0, (total, rfq) => total + rfq.budget).round();

 final metrics = [
 _SummaryCard(
 icon: Icons.assignment_outlined,
 iconBackground: const Color(0xFFEFF6FF),
 value: '${rfqs.length}',
 label: 'Open RFQs',
 ),
 _SummaryCard(
 icon: Icons.checklist_rounded,
 iconBackground: const Color(0xFFF1F5F9),
 value: '$inEvaluation',
 label: 'In Evaluation',
 ),
 _SummaryCard(
 icon: Icons.groups_outlined,
 iconBackground: const Color(0xFFFFF7ED),
 value: '$responseRate%',
 label: 'Response Rate',
 valueColor: const Color(0xFFF97316),
 ),
 _SummaryCard(
 icon: Icons.account_balance_wallet_outlined,
 iconBackground: const Color(0xFFECFEFF),
 value: currencyFormat.format(pipelineValue),
 label: 'Pipeline Value',
 valueColor: const Color(0xFF047857),
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Procurement Workflow',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 OutlinedButton(
 onPressed: onOpenTemplates,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('View Templates'),
 ),
 ElevatedButton.icon(
 onPressed: onCreateRfq,
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Create RFQ'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 16),
 const Text(
 'Use the preset procurement cycle, adjust durations in weeks or months, add steps, or customize by scope.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 10),
 _ProcurementWorkflowPlannerCard(
 scopeItems: scopeItems,
 customizeWorkflowByScope: customizeWorkflowByScope,
 selectedScopeId: selectedScopeId,
 selectedScopeName: selectedScope?.name ?? '',
 workflowDisabledForSelection: workflowDisabledForSelection,
 workflowTotalWeeks: workflowTotalWeeks,
 workflowSteps: workflowSteps,
 workflowLoading: workflowLoading,
 workflowSaving: workflowSaving,
 onCustomizeByScopeChanged: onCustomizeByScopeChanged,
 onWorkflowScopeSelected: onWorkflowScopeSelected,
 onAddWorkflowStep: onAddWorkflowStep,
 onEditWorkflowStep: onEditWorkflowStep,
 onDeleteWorkflowStep: onDeleteWorkflowStep,
 onMoveWorkflowStep: onMoveWorkflowStep,
 onResetWorkflow: onResetWorkflow,
 onSaveWorkflow: onSaveWorkflow,
 onApplyWorkflowToAllScopes: onApplyWorkflowToAllScopes,
 ),
 const SizedBox(height: 20),
 if (isMobile)
 Column(
 children: [
 metrics[0],
 const SizedBox(height: 12),
 metrics[1],
 const SizedBox(height: 12),
 metrics[2],
 const SizedBox(height: 12),
 metrics[3],
 ],
 )
 else
 Row(
 children: [
 for (var i = 0; i < metrics.length; i++) ...[
 Expanded(child: metrics[i]),
 if (i != metrics.length - 1) const SizedBox(width: 16),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _RfqListCard(
 rfqs: rfqs,
 currencyFormat: currencyFormat,
 onCreateRfq: onCreateRfq,
 onEditRfq: onEditRfq,
 onDeleteRfq: onDeleteRfq,
 ),
 const SizedBox(height: 16),
 _RfqSidebarCard(rfqs: rfqs, criteria: criteria),
 ],
 )
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _RfqListCard(
 rfqs: rfqs,
 currencyFormat: currencyFormat,
 onCreateRfq: onCreateRfq,
 onEditRfq: onEditRfq,
 onDeleteRfq: onDeleteRfq,
 ),
 ),
 const SizedBox(width: 24),
 SizedBox(
 width: 320,
 child: _RfqSidebarCard(rfqs: rfqs, criteria: criteria)),
 ],
 ),
 ],
 );
 }
}

class _ProcurementWorkflowPlannerCard extends StatelessWidget {
 const _ProcurementWorkflowPlannerCard({
 required this.scopeItems,
 required this.customizeWorkflowByScope,
 required this.selectedScopeId,
 required this.selectedScopeName,
 required this.workflowDisabledForSelection,
 required this.workflowTotalWeeks,
 required this.workflowSteps,
 required this.workflowLoading,
 required this.workflowSaving,
 required this.onCustomizeByScopeChanged,
 required this.onWorkflowScopeSelected,
 required this.onAddWorkflowStep,
 required this.onEditWorkflowStep,
 required this.onDeleteWorkflowStep,
 required this.onMoveWorkflowStep,
 required this.onResetWorkflow,
 required this.onSaveWorkflow,
 required this.onApplyWorkflowToAllScopes,
 });

 final List<ProcurementItemModel> scopeItems;
 final bool customizeWorkflowByScope;
 final String? selectedScopeId;
 final String selectedScopeName;
 final bool workflowDisabledForSelection;
 final int workflowTotalWeeks;
 final List<_ProcurementWorkflowStep> workflowSteps;
 final bool workflowLoading;
 final bool workflowSaving;
 final ValueChanged<bool> onCustomizeByScopeChanged;
 final ValueChanged<String> onWorkflowScopeSelected;
 final VoidCallback onAddWorkflowStep;
 final ValueChanged<_ProcurementWorkflowStep> onEditWorkflowStep;
 final ValueChanged<String> onDeleteWorkflowStep;
 final void Function(int index, int direction) onMoveWorkflowStep;
 final VoidCallback onResetWorkflow;
 final VoidCallback onSaveWorkflow;
 final VoidCallback onApplyWorkflowToAllScopes;

 @override
 Widget build(BuildContext context) {
 final hasScopes = scopeItems.isNotEmpty;
 final disableActions = workflowDisabledForSelection || workflowSaving;
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 10,
 runSpacing: 10,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 ChoiceChip(
 label: const Text('Apply to All Scopes'),
 selected: !customizeWorkflowByScope,
 onSelected: workflowSaving
 ? null
 : (_) => onCustomizeByScopeChanged(false),
 ),
 ChoiceChip(
 label: const Text('Customize by Scope'),
 selected: customizeWorkflowByScope,
 onSelected: hasScopes && !workflowSaving
 ? (_) => onCustomizeByScopeChanged(true)
 : null,
 ),
 if (customizeWorkflowByScope)
 SizedBox(
 width: 320,
 child: DropdownButtonFormField<String>(
 value: selectedScopeId,
 decoration: const InputDecoration(
 labelText: 'Procurement Scope',
 isDense: true,
 ),
 items: scopeItems
 .map(
 (item) => DropdownMenuItem<String>(
 value: item.id,
 child: Text(
 item.name.trim().isEmpty
 ? 'Untitled Scope'
 : item.name.trim(),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 )
 .toList(),
 onChanged: workflowSaving
 ? null
 : (value) {
 if (value == null) return;
 onWorkflowScopeSelected(value);
 },
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: workflowDisabledForSelection
 ? const Color(0xFFF3F4F6)
 : Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 child: Text(
 'Total Cycle: $workflowTotalWeeks week${workflowTotalWeeks == 1 ? '' : 's'}',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: workflowDisabledForSelection
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF1F2937),
 ),
 ),
 ),
 if (workflowLoading || workflowSaving)
 const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (customizeWorkflowByScope && !hasScopes)
 const Text(
 'No procurement scopes found. Add scope rows first.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 )
 else if (workflowDisabledForSelection)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 child: Text(
 'Bidding is not required for "${selectedScopeName.trim().isEmpty ? 'this scope' : selectedScopeName.trim()}". The procurement workflow is greyed out for this selection.',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF4B5563),
 height: 1.35,
 ),
 ),
 )
 else if (workflowSteps.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No workflow steps yet. Add your first step to build the procurement cycle.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 )
 else
 Column(
 children: [
 for (var i = 0; i < workflowSteps.length; i++) ...[
 _ProcurementWorkflowStepRow(
 step: workflowSteps[i],
 index: i,
 onEdit: () => onEditWorkflowStep(workflowSteps[i]),
 onDelete: () => onDeleteWorkflowStep(workflowSteps[i].id),
 onMoveUp: i == 0 ? null : () => onMoveWorkflowStep(i, -1),
 onMoveDown: i == workflowSteps.length - 1
 ? null
 : () => onMoveWorkflowStep(i, 1),
 ),
 if (i != workflowSteps.length - 1) const SizedBox(height: 8),
 ],
 ],
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 TextButton.icon(
 onPressed: disableActions ? null : onAddWorkflowStep,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Step'),
 ),
 OutlinedButton.icon(
 onPressed: disableActions ? null : onResetWorkflow,
 icon: const Icon(Icons.restart_alt_rounded, size: 16),
 label: const Text('Reset Preset'),
 ),
 ElevatedButton.icon(
 onPressed: disableActions ? null : onSaveWorkflow,
 icon: workflowSaving
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.save_outlined, size: 16),
 label: Text(
 customizeWorkflowByScope
 ? 'Save Scope Workflow'
 : 'Save Workflow',
 ),
 ),
 TextButton.icon(
 onPressed: disableActions ? null : onApplyWorkflowToAllScopes,
 icon: const Icon(Icons.publish_rounded, size: 16),
 label: const Text('Apply to All Scopes'),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ProcurementWorkflowStepRow extends StatelessWidget {
 const _ProcurementWorkflowStepRow({
 required this.step,
 required this.index,
 required this.onEdit,
 required this.onDelete,
 required this.onMoveUp,
 required this.onMoveDown,
 });

 final _ProcurementWorkflowStep step;
 final int index;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final VoidCallback? onMoveUp;
 final VoidCallback? onMoveDown;

 @override
 Widget build(BuildContext context) {
 final unitLabel = step.duration == 1 ? step.unit : '${step.unit}s';
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 26,
 height: 26,
 alignment: Alignment.center,
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 step.name.trim().isEmpty ? 'Untitled Step' : step.name.trim(),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 '${step.duration} $unitLabel',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 IconButton(
 tooltip: 'Edit',
 visualDensity: VisualDensity.compact,
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined, size: 18),
 ),
 IconButton(
 tooltip: 'Delete',
 visualDensity: VisualDensity.compact,
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline, size: 18),
 ),
 IconButton(
 tooltip: 'Move up',
 visualDensity: VisualDensity.compact,
 onPressed: onMoveUp,
 icon: const Icon(Icons.arrow_upward_rounded, size: 18),
 ),
 IconButton(
 tooltip: 'Move down',
 visualDensity: VisualDensity.compact,
 onPressed: onMoveDown,
 icon: const Icon(Icons.arrow_downward_rounded, size: 18),
 ),
 ],
 ),
 );
 }
}

class _RfqListCard extends StatelessWidget {
 const _RfqListCard({
 required this.rfqs,
 required this.currencyFormat,
 required this.onCreateRfq,
 required this.onEditRfq,
 required this.onDeleteRfq,
 });

 final List<RfqModel> rfqs;
 final NumberFormat currencyFormat;
 final VoidCallback onCreateRfq;
 final ValueChanged<RfqModel> onEditRfq;
 final ValueChanged<RfqModel> onDeleteRfq;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Text(
 'Active RFQs',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 SizedBox(width: 8),
 Text(
 'Prioritized by due date',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (rfqs.isEmpty)
 _EmptyStateBody(
 icon: Icons.request_quote_outlined,
 title: 'No active RFQs',
 message: 'Create an RFQ to begin vendor outreach.',
 actionLabel: 'Create RFQ',
 onAction: onCreateRfq,
 compact: true,
 )
 else
 for (var i = 0; i < rfqs.length; i++) ...[
 _RfqItemCard(
 rfq: rfqs[i],
 currencyFormat: currencyFormat,
 onEdit: onEditRfq,
 onDelete: onDeleteRfq,
 ),
 if (i != rfqs.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _RfqItemCard extends StatelessWidget {
 const _RfqItemCard({
 required this.rfq,
 required this.currencyFormat,
 required this.onEdit,
 required this.onDelete,
 });

 final RfqModel rfq;
 final NumberFormat currencyFormat;
 final ValueChanged<RfqModel> onEdit;
 final ValueChanged<RfqModel> onDelete;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final double responseRate =
 rfq.invitedCount == 0 ? 0.0 : rfq.responseCount / rfq.invitedCount;
 final dueLabel = DateFormat('MMM d').format(rfq.dueDate);

 return Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.all(16),
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
 rfq.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 4),
 Text(
 '${rfq.category} Â· Owner ${rfq.owner}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 _RfqStatusPill(status: rfq.status),
 const SizedBox(width: 6),
 _BadgePill(
 label: rfq.priority.label,
 background: rfq.priority.backgroundColor,
 border: rfq.priority.borderColor,
 foreground: rfq.priority.textColor,
 ),
 const SizedBox(width: 4),
 PopupMenuButton<String>(
 icon: const Icon(Icons.more_horiz_rounded, size: 20),
 onSelected: (value) {
 if (value == 'edit') {
 onEdit(rfq);
 } else if (value == 'delete') {
 onDelete(rfq);
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(value: 'edit', child: Text('Edit RFQ')),
 PopupMenuItem(value: 'delete', child: Text('Delete RFQ')),
 ],
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (isMobile)
 Column(
 children: [
 _RfqMeta(label: 'Due', value: dueLabel),
 const SizedBox(height: 8),
 _RfqMeta(
 label: 'Responses',
 value: '${rfq.responseCount}/${rfq.invitedCount}'),
 const SizedBox(height: 8),
 _RfqMeta(
 label: 'Budget', value: currencyFormat.format(rfq.budget)),
 ],
 )
 else
 Row(
 children: [
 Expanded(child: _RfqMeta(label: 'Due', value: dueLabel)),
 Expanded(
 child: _RfqMeta(
 label: 'Responses',
 value: '${rfq.responseCount}/${rfq.invitedCount}')),
 Expanded(
 child: _RfqMeta(
 label: 'Budget',
 value: currencyFormat.format(rfq.budget))),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 const Expanded(
 child: Text(
 'Vendor response progress',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ),
 Text(
 '${(responseRate * 100).round()}%',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1D4ED8)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: responseRate,
 minHeight: 6,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
 ),
 ),
 ],
 ),
 );
 }
}

class _RfqMeta extends StatelessWidget {
 const _RfqMeta({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
 const SizedBox(height: 4),
 Text(value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A))),
 ],
 );
 }
}

class _RfqStatusPill extends StatelessWidget {
 const _RfqStatusPill({required this.status});

 final RfqStatus status;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: status.backgroundColor,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: status.borderColor),
 ),
 child: Text(
 status.label,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: status.textColor),
 ),
 );
 }
}

class _RfqSidebarCard extends StatelessWidget {
 const _RfqSidebarCard({required this.rfqs, required this.criteria});

 final List<RfqModel> rfqs;
 final List<_RfqCriterion> criteria;

 @override
 Widget build(BuildContext context) {
 final upcoming = [...rfqs]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
 final topUpcoming = upcoming.take(3).toList();

 return Column(
 children: [
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Evaluation criteria',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 if (criteria.isEmpty)
 const Text(
 'Define evaluation criteria once the RFQ scope is approved.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 )
 else
 for (var i = 0; i < criteria.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 criteria[i].label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 '${(criteria[i].weight * 100).round()}%',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: criteria[i].weight,
 minHeight: 6,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: const AlwaysStoppedAnimation<Color>(
 Color(0xFF2563EB)),
 ),
 ),
 if (i != criteria.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 ),
 const SizedBox(height: 16),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Upcoming deadlines',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 if (topUpcoming.isEmpty)
 const Text(
 'Deadlines will surface once RFQs are created.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 )
 else
 for (var i = 0; i < topUpcoming.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 topUpcoming[i].title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 DateFormat('MMM d').format(topUpcoming[i].dueDate),
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 if (i != topUpcoming.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 ),
 ],
 );
 }
}

class _PurchaseOrdersView extends StatelessWidget {
 const _PurchaseOrdersView({
 super.key,
 required this.orders,
 required this.currencyFormat,
 required this.processStarted,
 required this.earlyStartEnabled,
 required this.canEnableEarlyStart,
 required this.onEnableEarlyStart,
 required this.vitalLleItems,
 required this.itemNumberById,
 required this.trackableItems,
 required this.selectedTrackableIndex,
 required this.onSelectTrackable,
 required this.selectedTrackableItem,
 required this.trackingAlerts,
 required this.carrierPerformance,
 required this.onUpdateTrackingStatus,
 required this.onCreatePo,
 required this.onEditPo,
 required this.onDeletePo,
 });

 final List<PurchaseOrderModel> orders;
 final NumberFormat currencyFormat;
 final bool processStarted;
 final bool earlyStartEnabled;
 final bool canEnableEarlyStart;
 final VoidCallback onEnableEarlyStart;
 final List<ProcurementItemModel> vitalLleItems;
 final Map<String, String> itemNumberById;
 final List<ProcurementItemModel> trackableItems;
 final int selectedTrackableIndex;
 final ValueChanged<int> onSelectTrackable;
 final ProcurementItemModel? selectedTrackableItem;
 final List<_TrackingAlert> trackingAlerts;
 final List<_CarrierPerformance> carrierPerformance;
 final VoidCallback onUpdateTrackingStatus;
 final VoidCallback onCreatePo;
 final ValueChanged<PurchaseOrderModel> onEditPo;
 final ValueChanged<PurchaseOrderModel> onDeletePo;

 @override
 Widget build(BuildContext context) {
 final enabled = processStarted || earlyStartEnabled;
 if (!enabled) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _PurchaseOrdersInitiationLockedView(
 canEnableEarlyStart: canEnableEarlyStart,
 onEnableEarlyStart: onEnableEarlyStart,
 vitalLleItems: vitalLleItems,
 itemNumberById: itemNumberById,
 ),
 const SizedBox(height: 16),
 const _StageLockedView(
 title: 'Purchase Orders Locked in Initiation',
 message:
 'This section remains greyed out during initiation unless you turn it on early.',
 ),
 ],
 );
 }

 final isMobile = AppBreakpoints.isMobile(context);
 final awaitingApproval = orders
 .where((order) => order.status == PurchaseOrderStatus.awaitingApproval)
 .length;
 final inTransit = orders
 .where((order) => order.status == PurchaseOrderStatus.inTransit)
 .length;
 final openOrders = orders
 .where((order) => order.status != PurchaseOrderStatus.received)
 .length;
 final totalSpend =
 orders.fold<double>(0, (total, order) => total + order.amount);

 final metrics = [
 _SummaryCard(
 icon: Icons.receipt_long_outlined,
 iconBackground: const Color(0xFFEFF6FF),
 value: '$openOrders',
 label: 'Open Orders',
 ),
 _SummaryCard(
 icon: Icons.approval_outlined,
 iconBackground: const Color(0xFFFFF7ED),
 value: '$awaitingApproval',
 label: 'Awaiting Approval',
 valueColor: const Color(0xFFF97316),
 ),
 _SummaryCard(
 icon: Icons.local_shipping_outlined,
 iconBackground: const Color(0xFFF1F5F9),
 value: '$inTransit',
 label: 'In Transit',
 ),
 _SummaryCard(
 icon: Icons.attach_money,
 iconBackground: const Color(0xFFECFEFF),
 value: currencyFormat.format(totalSpend),
 label: 'Total Spend',
 valueColor: const Color(0xFF047857),
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Purchase Orders & Item Tracking',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 ElevatedButton.icon(
 onPressed: onCreatePo,
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Create PO'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 metrics[0],
 const SizedBox(height: 12),
 metrics[1],
 const SizedBox(height: 12),
 metrics[2],
 const SizedBox(height: 12),
 metrics[3],
 ],
 )
 else
 Row(
 children: [
 for (var i = 0; i < metrics.length; i++) ...[
 Expanded(child: metrics[i]),
 if (i != metrics.length - 1) const SizedBox(width: 16),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (orders.isEmpty)
 _EmptyStateCard(
 icon: Icons.receipt_long_outlined,
 title: 'No purchase orders yet',
 message: 'Create a PO to track approvals, shipments, and invoices.',
 actionLabel: 'Create PO',
 onAction: onCreatePo,
 )
 else
 Column(
 children: [
 for (var i = 0; i < orders.length; i++) ...[
 _PurchaseOrderCard(
 order: orders[i],
 currencyFormat: currencyFormat,
 onEdit: () => onEditPo(orders[i]),
 onDelete: () => onDeletePo(orders[i]),
 ),
 if (i != orders.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _ApprovalQueueCard(orders: orders),
 const SizedBox(height: 16),
 _InvoiceMatchCard(orders: orders),
 ],
 )
 else
 Row(
 children: [
 Expanded(child: _ApprovalQueueCard(orders: orders)),
 const SizedBox(width: 16),
 Expanded(child: _InvoiceMatchCard(orders: orders)),
 ],
 ),
 const SizedBox(height: 32),
 _ItemTrackingView(
 trackableItems: trackableItems,
 selectedIndex: selectedTrackableIndex,
 onSelectTrackable: onSelectTrackable,
 selectedItem: selectedTrackableItem,
 alerts: trackingAlerts,
 carriers: carrierPerformance,
 onUpdateStatus: onUpdateTrackingStatus,
 title: 'Item Tracking (Combined with Purchase Orders)',
 ),
 ],
 );
 }
}

class _PurchaseOrderTable extends StatefulWidget {
 const _PurchaseOrderTable({
 required this.orders,
 required this.currencyFormat,
 required this.onCreatePo,
 required this.onEditPo,
 required this.onDeletePo,
 });

 final List<PurchaseOrderModel> orders;
 final NumberFormat currencyFormat;
 final VoidCallback onCreatePo;
 final ValueChanged<PurchaseOrderModel> onEditPo;
 final ValueChanged<PurchaseOrderModel> onDeletePo;

 @override
 State<_PurchaseOrderTable> createState() => _PurchaseOrderTableState();
}

class _PurchaseOrderTableState extends State<_PurchaseOrderTable> {
 final ScrollController _horizontalScrollController = ScrollController();

 @override
 void dispose() {
 _horizontalScrollController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 if (widget.orders.isEmpty) {
 return _EmptyStateCard(
 icon: Icons.receipt_long_outlined,
 title: 'No purchase orders yet',
 message: 'Create a PO to track approvals, shipments, and invoices.',
 actionLabel: 'Create PO',
 onAction: widget.onCreatePo,
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Scrollbar(
 controller: _horizontalScrollController,
 thumbVisibility: true,
 scrollbarOrientation: ScrollbarOrientation.bottom,
 child: SingleChildScrollView(
 controller: _horizontalScrollController,
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: Column(
 children: [
 const Padding(
 padding:
 EdgeInsets.symmetric(horizontal: 24, vertical: 18),
 child: _PurchaseOrderHeaderRow(),
 ),
 const Divider(height: 1, color: Color(0xFFE2E8F0)),
 for (var i = 0; i < widget.orders.length; i++) ...[
 _PurchaseOrderRow(
 order: widget.orders[i],
 currencyFormat: widget.currencyFormat,
 onEdit: () => widget.onEditPo(widget.orders[i]),
 onDelete: () => widget.onDeletePo(widget.orders[i]),
 ),
 if (i != widget.orders.length - 1)
 const Divider(height: 1, color: Color(0xFFE2E8F0)),
 ],
 ],
 ),
 ),
 ),
 ),
 );
 },
 );
 }
}

class _PurchaseOrderHeaderRow extends StatelessWidget {
 const _PurchaseOrderHeaderRow();

 @override
 Widget build(BuildContext context) {
 return Row(
 children: const [
 _HeaderCell(label: 'PO', flex: 2),
 _HeaderCell(label: 'Vendor', flex: 3),
 _HeaderCell(label: 'Category', flex: 2),
 _HeaderCell(label: 'Status', flex: 2),
 _HeaderCell(label: 'Amount', flex: 2),
 _HeaderCell(label: 'Expected', flex: 2),
 _HeaderCell(label: 'Progress', flex: 2),
 _HeaderCell(label: 'Actions', flex: 2, alignEnd: true),
 ],
 );
 }
}

class _HeaderCell extends StatelessWidget {
 const _HeaderCell({
 required this.label,
 required this.flex,
 this.alignEnd = false,
 });

 final String label;
 final int flex;
 final bool alignEnd;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 flex: flex,
 child: Text(
 label,
 textAlign: alignEnd ? TextAlign.end : TextAlign.start,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B),
 ),
 ),
 );
 }
}

class _PurchaseOrderRow extends StatelessWidget {
 const _PurchaseOrderRow({
 required this.order,
 required this.currencyFormat,
 required this.onEdit,
 required this.onDelete,
 });

 final PurchaseOrderModel order;
 final NumberFormat currencyFormat;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 double _normalizeProgress(double raw) {
 if (raw.isNaN || !raw.isFinite) return 0.0;
 if (raw > 1.0 && raw <= 100.0) return raw / 100.0;
 if (raw < 0.0) return 0.0;
 if (raw > 1.0) return 1.0;
 return raw;
 }

 @override
 Widget build(BuildContext context) {
 final expectedLabel = DateFormat('M/d/yyyy').format(order.expectedDate);
 final progressValue = _normalizeProgress(order.progress);
 final progressLabel = '${(progressValue * 100).round()}%';

 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: Text(order.poNumber,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A))),
 ),
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(order.vendorName,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A))),
 const SizedBox(height: 4),
 Text('Owner ${order.owner}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(order.category,
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.centerLeft,
 child: _PurchaseOrderStatusPill(status: order.status),
 ),
 ),
 Expanded(
 flex: 2,
 child: Text(currencyFormat.format(order.amount),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A))),
 ),
 Expanded(
 flex: 2,
 child: Text(expectedLabel,
 style:
 const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
 Expanded(
 flex: 2,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(progressLabel,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1D4ED8))),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: progressValue,
 minHeight: 6,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.centerRight,
 child: PopupMenuButton<String>(
 onSelected: (value) {
 if (value == 'edit') {
 onEdit();
 } else if (value == 'delete') {
 onDelete();
 }
 },
 itemBuilder: (_) => const [
 PopupMenuItem(
 value: 'edit',
 child: Text('Edit purchase order'),
 ),
 PopupMenuItem(
 value: 'delete',
 child: Text('Remove purchase order'),
 ),
 ],
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: const Icon(Icons.more_horiz_rounded,
 size: 18, color: Color(0xFF475569)),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _PurchaseOrderCard extends StatelessWidget {
 const _PurchaseOrderCard({
 required this.order,
 required this.currencyFormat,
 required this.onEdit,
 required this.onDelete,
 });

 final PurchaseOrderModel order;
 final NumberFormat currencyFormat;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 double _normalizeProgress(double raw) {
 if (raw.isNaN || !raw.isFinite) return 0.0;
 if (raw > 1.0 && raw <= 100.0) return raw / 100.0;
 if (raw < 0.0) return 0.0;
 if (raw > 1.0) return 1.0;
 return raw;
 }

 @override
 Widget build(BuildContext context) {
 final expectedLabel = DateFormat('M/d/yyyy').format(order.expectedDate);
 final progressValue = _normalizeProgress(order.progress);
 final progressLabel = '${(progressValue * 100).round()}%';

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(order.id,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A))),
 ),
 _PurchaseOrderStatusPill(status: order.status),
 ],
 ),
 const SizedBox(height: 8),
 Text(order.vendorName,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937))),
 const SizedBox(height: 4),
 Text(order.category,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _RfqMeta(label: 'Expected', value: expectedLabel)),
 Expanded(
 child: _RfqMeta(
 label: 'Amount',
 value: currencyFormat.format(order.amount))),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _RfqMeta(label: 'Progress', value: progressLabel)),
 Expanded(
 child: _RfqMeta(
 label: 'Owner',
 value:
 order.owner.trim().isEmpty ? 'Unassigned' : order.owner,
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: progressValue,
 minHeight: 6,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 TextButton.icon(
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit'),
 ),
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline, size: 16),
 label: const Text('Remove'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFDC2626),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _PurchaseOrderStatusPill extends StatelessWidget {
 const _PurchaseOrderStatusPill({required this.status});

 final PurchaseOrderStatus status;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: status.backgroundColor,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: status.borderColor),
 ),
 child: Text(
 status.label,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: status.textColor),
 ),
 );
 }
}

class _ApprovalQueueCard extends StatelessWidget {
 const _ApprovalQueueCard({required this.orders});

 final List<PurchaseOrderModel> orders;

 @override
 Widget build(BuildContext context) {
 final approvals = orders
 .where((order) => order.status == PurchaseOrderStatus.awaitingApproval)
 .toList();

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Approval queue',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 if (approvals.isEmpty)
 const Text('No approvals pending.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
 else
 for (var i = 0; i < approvals.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 '${approvals[i].id} Â· ${approvals[i].vendorName}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 DateFormat('MMM d').format(approvals[i].orderedDate),
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 if (i != approvals.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _InvoiceMatchCard extends StatelessWidget {
 const _InvoiceMatchCard({required this.orders});

 final List<PurchaseOrderModel> orders;

 @override
 Widget build(BuildContext context) {
 final completed = orders
 .where((order) => order.status == PurchaseOrderStatus.received)
 .toList();
 final inProgress = orders
 .where((order) => order.status == PurchaseOrderStatus.inTransit)
 .toList();

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Invoice matching',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 Text(
 'Completed matches: ${completed.length}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 12),
 Text(
 'In progress: ${inProgress.length}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 12),
 OutlinedButton(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Invoice matching is available in Purchase Orders and Item Tracking details.',
 ),
 ),
 );
 },
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 child: const Text('Open match workspace'),
 ),
 ],
 ),
 );
 }
}

class _ItemTrackingView extends StatelessWidget {
 const _ItemTrackingView({
 required this.trackableItems,
 required this.selectedIndex,
 required this.onSelectTrackable,
 required this.selectedItem,
 required this.alerts,
 required this.carriers,
 required this.onUpdateStatus,
 this.title = 'Item Tracking',
 });

 final List<ProcurementItemModel> trackableItems;
 final int selectedIndex;
 final ValueChanged<int> onSelectTrackable;
 final ProcurementItemModel? selectedItem;
 final List<_TrackingAlert> alerts;
 final List<_CarrierPerformance> carriers;
 final VoidCallback onUpdateStatus;
 final String title;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final inTransit = trackableItems
 .where((item) => item.status == ProcurementItemStatus.ordered)
 .length;
 final delivered = trackableItems
 .where((item) => item.status == ProcurementItemStatus.delivered)
 .length;
 final highAlerts =
 alerts.where((alert) => alert.severity == _AlertSeverity.high).length;
 final onTimeRate = carriers.isEmpty
 ? 0
 : (carriers.fold<int>(
 0, (total, carrier) => total + carrier.onTimeRate) /
 carriers.length)
 .round();

 final metrics = [
 _SummaryCard(
 icon: Icons.local_shipping_outlined,
 iconBackground: const Color(0xFFEFF6FF),
 value: '$inTransit',
 label: 'In Transit',
 ),
 _SummaryCard(
 icon: Icons.check_circle_outline,
 iconBackground: const Color(0xFFE8FFF4),
 value: '$delivered',
 label: 'Delivered',
 valueColor: const Color(0xFF047857),
 ),
 _SummaryCard(
 icon: Icons.warning_amber_rounded,
 iconBackground: const Color(0xFFFFF1F2),
 value: '$highAlerts',
 label: 'High Priority Alerts',
 valueColor: const Color(0xFFDC2626),
 ),
 _SummaryCard(
 icon: Icons.track_changes_outlined,
 iconBackground: const Color(0xFFF1F5F9),
 value: '$onTimeRate%',
 label: 'On-time Rate',
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 ElevatedButton.icon(
 onPressed: onUpdateStatus,
 icon: const Icon(Icons.sync_rounded, size: 18),
 label: const Text('Update Status'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 metrics[0],
 const SizedBox(height: 12),
 metrics[1],
 const SizedBox(height: 12),
 metrics[2],
 const SizedBox(height: 12),
 metrics[3],
 ],
 )
 else
 Row(
 children: [
 for (var i = 0; i < metrics.length; i++) ...[
 Expanded(child: metrics[i]),
 if (i != metrics.length - 1) const SizedBox(width: 16),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _TrackableItemsCard(
 trackableItems: trackableItems,
 selectedIndex: selectedIndex,
 onSelectTrackable: onSelectTrackable,
 ),
 const SizedBox(height: 16),
 _TrackingTimelineCard(item: selectedItem),
 const SizedBox(height: 16),
 _TrackingAlertsCard(alerts: alerts),
 const SizedBox(height: 16),
 _CarrierPerformanceCard(carriers: carriers),
 ],
 )
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Column(
 children: [
 _TrackableItemsCard(
 trackableItems: trackableItems,
 selectedIndex: selectedIndex,
 onSelectTrackable: onSelectTrackable,
 ),
 const SizedBox(height: 16),
 _TrackingAlertsCard(alerts: alerts),
 ],
 ),
 ),
 const SizedBox(width: 24),
 Expanded(
 flex: 2,
 child: Column(
 children: [
 _TrackingTimelineCard(item: selectedItem),
 const SizedBox(height: 16),
 _CarrierPerformanceCard(carriers: carriers),
 ],
 ),
 ),
 ],
 ),
 ],
 );
 }
}

class _TrackingAlertsCard extends StatelessWidget {
 const _TrackingAlertsCard({required this.alerts});

 final List<_TrackingAlert> alerts;

 DateTime _parseAlertDate(String rawValue) {
 final raw = rawValue.trim();
 if (raw.isEmpty) return DateTime.now();
 final parsedIso = DateTime.tryParse(raw);
 if (parsedIso != null) return parsedIso;
 try {
 return DateFormat('MMM d, yyyy').parseLoose(raw);
 } catch (e) {
 return DateTime.now();
 }
 }

 @override
 Widget build(BuildContext context) {
 if (alerts.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.warning_amber_rounded,
 title: 'Logistics alerts',
 message: 'Alerts will surface once shipments are in motion.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Logistics alerts',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < alerts.length; i++) ...[
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 alerts[i].title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 4),
 Text(
 alerts[i].description,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 4),
 Text(
 DateFormat('M/d')
 .format(_parseAlertDate(alerts[i].date)),
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 _AlertSeverityPill(severity: alerts[i].severity),
 ],
 ),
 if (i != alerts.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _AlertSeverityPill extends StatelessWidget {
 const _AlertSeverityPill({required this.severity});

 final _AlertSeverity severity;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: _AlertSeverityExtension(severity).backgroundColor,
 borderRadius: BorderRadius.circular(999),
 border:
 Border.all(color: _AlertSeverityExtension(severity).borderColor),
 ),
 child: Text(
 _AlertSeverityExtension(severity).label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: _AlertSeverityExtension(severity).textColor),
 ),
 );
 }
}

class _CarrierPerformanceCard extends StatelessWidget {
 const _CarrierPerformanceCard({required this.carriers});

 final List<_CarrierPerformance> carriers;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Carrier performance',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < carriers.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 carriers[i].carrier,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 '${carriers[i].onTimeRate}%',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF2563EB)),
 ),
 const SizedBox(width: 12),
 Text(
 '${carriers[i].avgDays}d avg',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: carriers[i].onTimeRate / 100,
 minHeight: 6,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
 ),
 ),
 if (i != carriers.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _ProcurementTemplatesView extends StatelessWidget {
 const _ProcurementTemplatesView({
 super.key,
 required this.processStarted,
 });

 final bool processStarted;

 @override
 Widget build(BuildContext context) {
 final templates = const <Map<String, String>>[
 {
 'title': 'RFQ Template',
 'description':
 'Standard request-for-quotation structure for supplier bidding.',
 },
 {
 'title': 'Purchase Order Template',
 'description':
 'PO format aligned with approval controls and tracking fields.',
 },
 {
 'title': 'Vendor Onboarding Template',
 'description':
 'Checklist for compliance documentation and kickoff activities.',
 },
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Procurement Templates',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 ),
 if (!processStarted)
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: const Text(
 'Process not started',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF92400E),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Text(
 'Templates are available at initiation stage. Item Tracking details are now combined under Purchase Orders.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 20),
 for (var i = 0; i < templates.length; i++) ...[
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 templates[i]['title'] ?? '',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 templates[i]['description'] ?? '',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 if (i != templates.length - 1) const SizedBox(height: 10),
 ],
 ],
 );
 }
}

class _StageLockedView extends StatelessWidget {
 const _StageLockedView({
 required this.title,
 required this.message,
 });

 final String title;
 final String message;

 @override
 Widget build(BuildContext context) {
 return _EmptyStateCard(
 icon: Icons.lock_outline_rounded,
 title: title,
 message: message,
 compact: true,
 );
 }
}

class _PurchaseOrdersInitiationLockedView extends StatelessWidget {
 const _PurchaseOrdersInitiationLockedView({
 required this.canEnableEarlyStart,
 required this.onEnableEarlyStart,
 required this.vitalLleItems,
 required this.itemNumberById,
 });

 final bool canEnableEarlyStart;
 final VoidCallback onEnableEarlyStart;
 final List<ProcurementItemModel> vitalLleItems;
 final Map<String, String> itemNumberById;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Purchase Orders (Initiation)',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB),
 borderRadius: BorderRadius.circular(999),
 ),
 child: const Text(
 'Greyed Out',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 const Text(
 'Enable early only when needed. Vital long-lead items (LLEs) should be prioritized first.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 12),
 if (vitalLleItems.isNotEmpty) ...[
 const Text(
 'Vital LLE candidates',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 8),
 for (var i = 0; i < vitalLleItems.length && i < 5; i++) ...[
 Row(
 children: [
 Text(
 itemNumberById[vitalLleItems[i].id] ?? 'ITM-${i + 1}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 vitalLleItems[i].name,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 ],
 ),
 if (i < 4 && i != vitalLleItems.length - 1)
 const SizedBox(height: 6),
 ],
 const SizedBox(height: 14),
 ],
 ElevatedButton.icon(
 onPressed: canEnableEarlyStart ? onEnableEarlyStart : null,
 icon: const Icon(Icons.play_arrow_rounded, size: 16),
 label: const Text('Turn On Early for LLEs'),
 style: ElevatedButton.styleFrom(
 backgroundColor: canEnableEarlyStart
 ? const Color(0xFFF6C437)
 : const Color(0xFFD1D5DB),
 foregroundColor: canEnableEarlyStart
 ? const Color(0xFF111827)
 : const Color(0xFF6B7280),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ReportsView extends StatelessWidget {
 const _ReportsView({
 super.key,
 required this.kpis,
 required this.spendBreakdown,
 required this.leadTimeMetrics,
 required this.savingsOpportunities,
 required this.complianceMetrics,
 required this.currencyFormat,
 required this.onGenerateReports,
 });

 final List<_ReportKpi> kpis;
 final List<_SpendBreakdown> spendBreakdown;
 final List<_LeadTimeMetric> leadTimeMetrics;
 final List<_SavingsOpportunity> savingsOpportunities;
 final List<_ComplianceMetric> complianceMetrics;
 final NumberFormat currencyFormat;
 final VoidCallback onGenerateReports;

 @override
 Widget build(BuildContext context) {
 void showShareFeedback() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Report sharing has been queued. Export PDF first to distribute a static file.',
 ),
 ),
 );
 }

 void showExportFeedback() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'PDF export started. Refresh in a few seconds if the file is not ready yet.',
 ),
 ),
 );
 }

 final isMobile = AppBreakpoints.isMobile(context);
 final hasData = kpis.isNotEmpty ||
 spendBreakdown.isNotEmpty ||
 leadTimeMetrics.isNotEmpty ||
 savingsOpportunities.isNotEmpty ||
 complianceMetrics.isNotEmpty;

 if (!hasData) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Procurement Reports',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 ElevatedButton.icon(
 onPressed: onGenerateReports,
 icon: const Icon(Icons.auto_awesome, size: 18),
 label: const Text('Generate Data'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF0EA5E9),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 OutlinedButton(
 onPressed: showShareFeedback,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Share'),
 ),
 ElevatedButton.icon(
 onPressed: showExportFeedback,
 icon: const Icon(Icons.file_download_outlined, size: 18),
 label: const Text('Export PDF'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 16),
 const _EmptyStateCard(
 icon: Icons.insert_chart_outlined,
 title: 'No report data yet',
 message:
 'Reports will populate as procurement activity is recorded.',
 ),
 ],
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Procurement Reports',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 ElevatedButton.icon(
 onPressed: onGenerateReports,
 icon: const Icon(Icons.auto_awesome, size: 18),
 label: const Text('Generate Data'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF0EA5E9),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 OutlinedButton(
 onPressed: showShareFeedback,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF0F172A),
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Share'),
 ),
 ElevatedButton.icon(
 onPressed: showExportFeedback,
 icon: const Icon(Icons.file_download_outlined, size: 18),
 label: const Text('Export PDF'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 children: [
 for (var i = 0; i < kpis.length; i++) ...[
 _ReportKpiCard(kpi: kpis[i]),
 if (i != kpis.length - 1) const SizedBox(height: 12),
 ],
 ],
 )
 else
 Row(
 children: [
 for (var i = 0; i < kpis.length; i++) ...[
 Expanded(child: _ReportKpiCard(kpi: kpis[i])),
 if (i != kpis.length - 1) const SizedBox(width: 16),
 ],
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _SpendBreakdownCard(
 breakdown: spendBreakdown, currencyFormat: currencyFormat),
 const SizedBox(height: 16),
 _LeadTimePerformanceCard(metrics: leadTimeMetrics),
 ],
 )
 else
 Row(
 children: [
 Expanded(
 child: _SpendBreakdownCard(
 breakdown: spendBreakdown,
 currencyFormat: currencyFormat)),
 const SizedBox(width: 16),
 Expanded(
 child: _LeadTimePerformanceCard(metrics: leadTimeMetrics)),
 ],
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 children: [
 _SavingsOpportunitiesCard(items: savingsOpportunities),
 const SizedBox(height: 16),
 _ComplianceSnapshotCard(metrics: complianceMetrics),
 ],
 )
 else
 Row(
 children: [
 Expanded(
 child:
 _SavingsOpportunitiesCard(items: savingsOpportunities)),
 const SizedBox(width: 16),
 Expanded(
 child: _ComplianceSnapshotCard(metrics: complianceMetrics)),
 ],
 ),
 ],
 );
 }
}

class _ReportKpiCard extends StatelessWidget {
 const _ReportKpiCard({required this.kpi});

 final _ReportKpi kpi;

 @override
 Widget build(BuildContext context) {
 final Color deltaColor =
 kpi.positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
 final IconData deltaIcon = kpi.positive
 ? Icons.arrow_upward_rounded
 : Icons.arrow_downward_rounded;

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(18),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(kpi.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 8),
 Text(kpi.value,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A))),
 const SizedBox(height: 8),
 Row(
 children: [
 Icon(deltaIcon, size: 16, color: deltaColor),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 kpi.delta,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: deltaColor),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _SpendBreakdownCard extends StatelessWidget {
 const _SpendBreakdownCard(
 {required this.breakdown, required this.currencyFormat});

 final List<_SpendBreakdown> breakdown;
 final NumberFormat currencyFormat;

 @override
 Widget build(BuildContext context) {
 if (breakdown.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.pie_chart_outline,
 title: 'Spend by category',
 message: 'Category spend will appear after items and POs are logged.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Spend by category',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < breakdown.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 breakdown[i].label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 currencyFormat.format(breakdown[i].amount),
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 LayoutBuilder(
 builder: (context, constraints) {
 return Stack(
 children: [
 Container(
 height: 8,
 decoration: BoxDecoration(
 color: const Color(0xFFE2E8F0),
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 Container(
 height: 8,
 width: constraints.maxWidth * breakdown[i].percent,
 decoration: BoxDecoration(
 color: breakdown[i].color,
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 ],
 );
 },
 ),
 if (i != breakdown.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _LeadTimePerformanceCard extends StatelessWidget {
 const _LeadTimePerformanceCard({required this.metrics});

 final List<_LeadTimeMetric> metrics;

 @override
 Widget build(BuildContext context) {
 if (metrics.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.schedule_outlined,
 title: 'Lead time performance',
 message: 'Lead time data will appear once deliveries are tracked.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Lead time performance',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < metrics.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 metrics[i].label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 '${(metrics[i].onTimeRate * 100).round()}%',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: metrics[i].onTimeRate,
 minHeight: 8,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
 ),
 ),
 if (i != metrics.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _SavingsOpportunitiesCard extends StatelessWidget {
 const _SavingsOpportunitiesCard({required this.items});

 final List<_SavingsOpportunity> items;

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.savings_outlined,
 title: 'Savings opportunities',
 message: 'Savings will appear as sourcing insights are captured.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Savings opportunities',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < items.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 items[i].title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 4),
 Text(
 'Owner ${items[i].owner}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 ),
 Text(
 items[i].value,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF16A34A)),
 ),
 ],
 ),
 if (i != items.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _ComplianceSnapshotCard extends StatelessWidget {
 const _ComplianceSnapshotCard({required this.metrics});

 final List<_ComplianceMetric> metrics;

 @override
 Widget build(BuildContext context) {
 if (metrics.isEmpty) {
 return const _EmptyStateCard(
 icon: Icons.verified_outlined,
 title: 'Compliance snapshot',
 message:
 'Compliance tracking appears after vendors and orders are recorded.',
 compact: true,
 );
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Compliance snapshot',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < metrics.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 metrics[i].label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 Text(
 '${(metrics[i].value * 100).round()}%',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: metrics[i].value,
 minHeight: 8,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
 ),
 ),
 if (i != metrics.length - 1) const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }
}

class _EmptyStateBody extends StatelessWidget {
 const _EmptyStateBody({
 required this.icon,
 required this.title,
 required this.message,
 this.actionLabel,
 this.onAction,
 this.compact = false,
 });

 final IconData icon;
 final String title;
 final String message;
 final String? actionLabel;
 final VoidCallback? onAction;
 final bool compact;

 @override
 Widget build(BuildContext context) {
 final double iconSize = compact ? 40 : 52;
 return Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: iconSize,
 height: iconSize,
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(icon,
 color: const Color(0xFF2563EB), size: compact ? 20 : 24),
 ),
 SizedBox(height: compact ? 10 : 14),
 Text(
 title,
 style: TextStyle(
 fontSize: compact ? 14 : 16,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF0F172A),
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 6),
 Text(
 message,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 textAlign: TextAlign.center,
 ),
 if (actionLabel != null && onAction != null) ...[
 const SizedBox(height: 12),
 ElevatedButton(
 onPressed: onAction,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 child: Text(actionLabel!,
 style: const TextStyle(fontWeight: FontWeight.w700)),
 ),
 ],
 ],
 );
 }
}

class _EmptyStateCard extends StatelessWidget {
 const _EmptyStateCard({
 required this.icon,
 required this.title,
 required this.message,
 this.actionLabel,
 this.onAction,
 this.compact = false,
 });

 final IconData icon;
 final String title;
 final String message;
 final String? actionLabel;
 final VoidCallback? onAction;
 final bool compact;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 8)),
 ],
 ),
 padding:
 EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 24 : 32),
 child: _EmptyStateBody(
 icon: icon,
 title: title,
 message: message,
 actionLabel: actionLabel,
 onAction: onAction,
 compact: compact,
 ),
 );
 }
}

class _ProcurementWorkflowStep {
 const _ProcurementWorkflowStep({
 required this.id,
 required this.name,
 required this.duration,
 required this.unit,
 });

 final String id;
 final String name;
 final int duration;
 final String unit;

 _ProcurementWorkflowStep copyWith({
 String? id,
 String? name,
 int? duration,
 String? unit,
 }) {
 return _ProcurementWorkflowStep(
 id: id ?? this.id,
 name: name ?? this.name,
 duration: duration ?? this.duration,
 unit: unit ?? this.unit,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'name': name,
 'duration': duration,
 'unit': unit,
 };

 factory _ProcurementWorkflowStep.fromMap(Map<String, dynamic> map) {
 final rawId = (map['id'] ?? '').toString().trim();
 final rawName = (map['name'] ?? map['stage'] ?? '').toString().trim();
 final rawDuration = map['duration'];
 var parsedDuration = 1;
 if (rawDuration is num) {
 parsedDuration = rawDuration.toInt();
 } else {
 parsedDuration = int.tryParse(rawDuration?.toString() ?? '') ?? 1;
 }
 if (parsedDuration < 1) parsedDuration = 1;
 final rawUnit = (map['unit'] ?? '').toString().trim().toLowerCase();
 final parsedUnit = rawUnit == 'month' ? 'month' : 'week';

 return _ProcurementWorkflowStep(
 id: rawId.isEmpty ? 'wf_${DateTime.now().microsecondsSinceEpoch}' : rawId,
 name: rawName.isEmpty ? 'Untitled Step' : rawName,
 duration: parsedDuration,
 unit: parsedUnit,
 );
 }
}

enum _ProcurementTab {
 procurementDashboard,
 itemsList,
 rfqWorkflow,
 vendorManagement,
 purchaseOrders,
 itemTracking,
 reports
}

extension _ProcurementTabExtension on _ProcurementTab {
 String get label {
 switch (this) {
 case _ProcurementTab.procurementDashboard:
 return 'Procurement';
 case _ProcurementTab.itemsList:
 return 'Scope Details';
 case _ProcurementTab.rfqWorkflow:
 return 'Procurement Workflow';
 case _ProcurementTab.vendorManagement:
 return 'Vendor Management';
 case _ProcurementTab.purchaseOrders:
 return 'Purchase Orders';
 case _ProcurementTab.itemTracking:
 return 'Procurement Templates';
 case _ProcurementTab.reports:
 return 'Reports';
 }
 }
}

class _VendorHealthMetric {
 const _VendorHealthMetric(
 {required this.category, required this.score, required this.change});

 final String category;
 final double score;
 final String change;
}

class _VendorOnboardingTask {
 const _VendorOnboardingTask({
 required this.title,
 required this.owner,
 required this.dueDate,
 required this.status,
 });

 final String title;
 final String owner;
 final String dueDate;
 final _VendorTaskStatus status;
}

enum _VendorTaskStatus { pending, inReview, complete }

extension _VendorTaskStatusExtension on _VendorTaskStatus {
 String get label {
 switch (this) {
 case _VendorTaskStatus.pending:
 return 'Pending';
 case _VendorTaskStatus.inReview:
 return 'In Review';
 case _VendorTaskStatus.complete:
 return 'Complete';
 }
 }

 Color get backgroundColor {
 switch (this) {
 case _VendorTaskStatus.pending:
 return const Color(0xFFF1F5F9);
 case _VendorTaskStatus.inReview:
 return const Color(0xFFFFF7ED);
 case _VendorTaskStatus.complete:
 return const Color(0xFFE8FFF4);
 }
 }

 Color get textColor {
 switch (this) {
 case _VendorTaskStatus.pending:
 return const Color(0xFF64748B);
 case _VendorTaskStatus.inReview:
 return const Color(0xFFF97316);
 case _VendorTaskStatus.complete:
 return const Color(0xFF047857);
 }
 }

 Color get borderColor {
 switch (this) {
 case _VendorTaskStatus.pending:
 return const Color(0xFFE2E8F0);
 case _VendorTaskStatus.inReview:
 return const Color(0xFFFED7AA);
 case _VendorTaskStatus.complete:
 return const Color(0xFFBBF7D0);
 }
 }
}

class _VendorRiskItem {
 const _VendorRiskItem({
 required this.vendor,
 required this.risk,
 required this.severity,
 required this.lastIncident,
 });

 final String vendor;
 final String risk;
 final _RiskSeverity severity;
 final String lastIncident;
}

enum _RiskSeverity { low, medium, high }

extension _RiskSeverityExtension on _RiskSeverity {
 String get label {
 switch (this) {
 case _RiskSeverity.low:
 return 'Low';
 case _RiskSeverity.medium:
 return 'Medium';
 case _RiskSeverity.high:
 return 'High';
 }
 }

 Color get backgroundColor {
 switch (this) {
 case _RiskSeverity.low:
 return const Color(0xFFF1F5F9);
 case _RiskSeverity.medium:
 return const Color(0xFFFFF7ED);
 case _RiskSeverity.high:
 return const Color(0xFFFFF1F2);
 }
 }

 Color get textColor {
 switch (this) {
 case _RiskSeverity.low:
 return const Color(0xFF64748B);
 case _RiskSeverity.medium:
 return const Color(0xFFF97316);
 case _RiskSeverity.high:
 return const Color(0xFFDC2626);
 }
 }

 Color get borderColor {
 switch (this) {
 case _RiskSeverity.low:
 return const Color(0xFFE2E8F0);
 case _RiskSeverity.medium:
 return const Color(0xFFFED7AA);
 case _RiskSeverity.high:
 return const Color(0xFFFECACA);
 }
 }
}

class _RfqCriterion {
 const _RfqCriterion({required this.label, required this.weight});

 final String label;
 final double weight;
}

class _TrackingAlert {
 const _TrackingAlert({
 required this.title,
 required this.description,
 required this.severity,
 required this.date,
 });

 final String title;
 final String description;
 final _AlertSeverity severity;
 final String date;
}

enum _AlertSeverity { low, medium, high }

extension _AlertSeverityExtension on _AlertSeverity {
 String get label {
 switch (this) {
 case _AlertSeverity.low:
 return 'Low';
 case _AlertSeverity.medium:
 return 'Medium';
 case _AlertSeverity.high:
 return 'High';
 }
 }

 Color get backgroundColor {
 switch (this) {
 case _AlertSeverity.low:
 return const Color(0xFFF1F5F9);
 case _AlertSeverity.medium:
 return const Color(0xFFFFF7ED);
 case _AlertSeverity.high:
 return const Color(0xFFFFF1F2);
 }
 }

 Color get textColor {
 switch (this) {
 case _AlertSeverity.low:
 return const Color(0xFF64748B);
 case _AlertSeverity.medium:
 return const Color(0xFFF97316);
 case _AlertSeverity.high:
 return const Color(0xFFDC2626);
 }
 }

 Color get borderColor {
 switch (this) {
 case _AlertSeverity.low:
 return const Color(0xFFE2E8F0);
 case _AlertSeverity.medium:
 return const Color(0xFFFED7AA);
 case _AlertSeverity.high:
 return const Color(0xFFFECACA);
 }
 }
}

class _ProcurementNeed {
 const _ProcurementNeed({
 required this.name,
 required this.source,
 required this.quantity,
 required this.estimatedCost,
 required this.priority,
 });

 final String name;
 final String source;
 final int quantity;
 final double estimatedCost;
 final String priority;
}

class _CarrierPerformance {
 const _CarrierPerformance(
 {required this.carrier, required this.onTimeRate, required this.avgDays});

 final String carrier;
 final int onTimeRate;
 final int avgDays;
}

class _ReportKpi {
 const _ReportKpi(
 {required this.label,
 required this.value,
 required this.delta,
 required this.positive});

 final String label;
 final String value;
 final String delta;
 final bool positive;
}

class _SpendBreakdown {
 const _SpendBreakdown({
 required this.label,
 required this.amount,
 required this.percent,
 required this.color,
 });

 final String label;
 final int amount;
 final double percent;
 final Color color;
}

class _LeadTimeMetric {
 const _LeadTimeMetric({required this.label, required this.onTimeRate});

 final String label;
 final double onTimeRate;
}

class _SavingsOpportunity {
 const _SavingsOpportunity(
 {required this.title, required this.value, required this.owner});

 final String title;
 final String value;
 final String owner;
}

class _ComplianceMetric {
 const _ComplianceMetric({required this.label, required this.value});

 final String label;
 final double value;
}
