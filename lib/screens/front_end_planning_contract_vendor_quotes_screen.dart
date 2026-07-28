import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';

import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/widgets/procurement_tables.dart';
import 'package:ndu_project/widgets/procurement_dialogs.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// Layout Imports
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/responsive.dart'; // Added for AppBreakpoints

/// Front End Planning – Contracting screen (formerly Contract & Vendor Quotes).
/// Updated to use the standard FEP layout with DraggableSidebar and FrontEndPlanningHeader.
class FrontEndPlanningContractVendorQuotesScreen extends StatefulWidget {
 const FrontEndPlanningContractVendorQuotesScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningContractVendorQuotesScreen()),
 );
 }

 @override
 State<FrontEndPlanningContractVendorQuotesScreen> createState() =>
 _FrontEndPlanningContractVendorQuotesScreenState();
}

class _FrontEndPlanningContractVendorQuotesScreenState
 extends State<FrontEndPlanningContractVendorQuotesScreen> {
 static const int _initialContractsLimit = 40;
 static const int _initialItemsLimit = 40;
 static const int _loadMoreStep = 40;
 static const int _maxAiImportRows = 25;
 static const String _contractingNotesKey = 'planning_contracting_notes';
 static const String _contractingReportsKey = 'contracting_reports';
 static const String _contractingScopeSubtitle =
 'Identify the contract scope required for effective project execution and, where applicable, initiate contracting activities early to ensure the project schedule is maintained.';
 static const List<String> _contractTypeOptions = [
 'Lump Sum',
 'Reimbursable',
 'Unsure',
 ];
 static const List<String> _biddingOptions = ['Yes', 'No', 'Not Sure'];
 static const List<String> _startStageOptions = [
 'Initiation',
 'Planning',
 'Execution',
 'Launch',
 'Operations',
 'Unsure',
 ];
 static const List<String> _trackingStatusOptions = [
 'RFQ Drafted',
 'RFQ Sent',
 'Responses In',
 'Evaluation',
 'Awarded',
 'Contract Signed',
 ];
 static const List<String> _reportStatusOptions = [
 'Draft',
 'In Review',
 'Approved',
 'Published',
 ];
 static const String _workflowCollectionName = 'contracting_workflows';
 static const String _workflowGlobalDocId = 'global';
 static const String _scopeManagementCollectionName =
 'contracting_scope_management';
 static const List<String> _workflowDurationUnits = ['week', 'month'];
 static const List<_ContractingWorkflowStep> _defaultWorkflowTemplate = [
 _ContractingWorkflowStep(
 id: 'pre_qualification',
 name: 'Pre-Qualification',
 duration: 1,
 unit: 'week',
 ),
 _ContractingWorkflowStep(
 id: 'request_for_proposal',
 name: 'Request for Proposal (RFP)',
 duration: 3,
 unit: 'week',
 ),
 _ContractingWorkflowStep(
 id: 'bid_evaluation',
 name: 'Bid Evaluation',
 duration: 2,
 unit: 'week',
 ),
 _ContractingWorkflowStep(
 id: 'bid_clarification',
 name: 'Bid Clarification',
 duration: 1,
 unit: 'week',
 ),
 _ContractingWorkflowStep(
 id: 'contract_award',
 name: 'Contract Award',
 duration: 1,
 unit: 'week',
 ),
 _ContractingWorkflowStep(
 id: 'mobilization',
 name: 'Mobilization',
 duration: 1,
 unit: 'week',
 ),
 ];

 final TextEditingController _notesController = TextEditingController();
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 bool _isNotesSyncReady = false;
 final OpenAiServiceSecure _openAi = OpenAiServiceSecure();

 Stream<List<ProcurementItemModel>>? _itemsStream;
 Stream<List<ContractModel>>? _contractsStream;
 Stream<List<VendorModel>>? _contractorsStream;
 int _contractQueryLimit = _initialContractsLimit;
 int _itemQueryLimit = _initialItemsLimit;
 bool _generating = false;
 bool _showScopeDetails = false;
 bool _customizeWorkflowByScope = false;
 bool _workflowLoading = false;
 bool _workflowSaving = false;
 bool _scopeManagementLoading = false;
 bool _scopeManagementSaving = false;
 String? _selectedWorkflowScopeId;
 String _actingContractRole = '';
 _ContractingManagementTab _selectedManagementTab =
 _ContractingManagementTab.scopeManagement;
 String? _lastProjectId;
 String? _autoGenerationRequestedProjectId;
 bool _showAutoGenerationSpinner = false;
 String? _autoGenerationError;
 List<_ContractingWorkflowStep> _globalWorkflowSteps =
 List<_ContractingWorkflowStep>.from(_defaultWorkflowTemplate);
 List<_ContractingWorkflowStep> _workflowDraftSteps =
 List<_ContractingWorkflowStep>.from(_defaultWorkflowTemplate);
 Map<String, List<_ContractingWorkflowStep>> _scopeWorkflowOverrides = {};
 Map<String, _ContractScopeManagementState> _scopeManagementByScopeId = {};
 String? _prefilledNotesProjectId;

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 final data = ProjectDataHelper.getData(context);
 _notesController.text = data.frontEndPlanning.contractVendorQuotes;
 _notesController.addListener(_syncContractNotes);
 _isNotesSyncReady = true;
 _prefillContractingNotesIfMissing(data);
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Contract & Vendor Quotes',
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
 final projectData = ProjectDataHelper.getData(context);
 final projectId = projectData.projectId;

 if (projectId != _lastProjectId &&
 projectId != null &&
 projectId.isNotEmpty) {
 _lastProjectId = projectId;
 _bindProcurementStreams(projectId);
 _loadContractingWorkflowData(projectId);
 _loadScopeManagementData(projectId);
 _triggerAutoGenerationForProject(projectId);
 }
 }

 void _triggerAutoGenerationForProject(String projectId) {
 if (_autoGenerationRequestedProjectId == projectId) return;
 _autoGenerationRequestedProjectId = projectId;
 Future<void>(() async {
 await _generateContractingDataIfMissing(projectId);
 });
 }

 Future<void> _generateContractingDataIfMissing(String projectId) async {
 final checks = await Future.wait<bool>([
 ProcurementService.hasAnyContracts(projectId).timeout(
 const Duration(seconds: 6),
 onTimeout: () => true,
 ),
 ProcurementService.hasAnyItems(projectId).timeout(
 const Duration(seconds: 6),
 onTimeout: () => true,
 ),
 ]);

 final hasContracts = checks[0];
 final hasItems = checks[1];
 if (hasContracts) return;

 final existingItems = hasItems
 ? await ProcurementService.streamItems(
 projectId,
 limit: 500,
 ).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <ProcurementItemModel>[],
 )
 : const <ProcurementItemModel>[];
 if (!mounted) return;
 final needsScopeDetailCompletion =
 _hasIncompleteScopeDetails(existingItems);
 final data = ProjectDataHelper.getData(context);
 final needsProcurementNotes =
 data.frontEndPlanning.procurement.trim().isEmpty;

 if (mounted) {
 setState(() {
 _showAutoGenerationSpinner = true;
 _autoGenerationError = null;
 });
 }

 final generated = await _performGeneration(
 projectId,
 silent: true,
 seedContracts: !hasContracts,
 seedItems: !hasItems,
 enrichExistingItems: hasItems && needsScopeDetailCompletion,
 seedProcurementNotes: needsProcurementNotes,
 );

 if (!mounted) return;
 if (!generated) {
 setState(() {
 _autoGenerationError =
 'Unable to auto-generate contracting records. You can retry with "Generate with AI".';
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Automatic contracting generation failed. Please retry manually.',
 ),
 ),
 );
 }
 setState(() => _showAutoGenerationSpinner = false);
 }

 void _bindProcurementStreams(String projectId) {
 _itemsStream =
 ProcurementService.streamItems(projectId, limit: _itemQueryLimit);
 _contractsStream = ProcurementService.streamContracts(projectId,
 limit: _contractQueryLimit);
 _contractorsStream = VendorService.streamVendors(projectId, limit: 320);
 }

 CollectionReference<Map<String, dynamic>> _workflowCollection(
 String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_workflowCollectionName);
 }

 List<_ContractingWorkflowStep> _cloneWorkflowSteps(
 List<_ContractingWorkflowStep> steps) {
 return steps.map((step) => step.copyWith()).toList(growable: true);
 }

 List<_ContractingWorkflowStep> _parseWorkflowSteps(dynamic raw) {
 if (raw is! List) return <_ContractingWorkflowStep>[];
 final parsed = <_ContractingWorkflowStep>[];
 for (final entry in raw) {
 if (entry is Map<String, dynamic>) {
 parsed.add(_ContractingWorkflowStep.fromMap(entry));
 } else if (entry is Map) {
 parsed.add(
 _ContractingWorkflowStep.fromMap(Map<String, dynamic>.from(entry)));
 }
 }
 return parsed;
 }

 ProcurementItemModel? _findScopeById(
 List<ProcurementItemModel> items,
 String? scopeId,
 ) {
 if (scopeId == null || scopeId.isEmpty) return null;
 for (final item in items) {
 if (item.id == scopeId) return item;
 }
 return null;
 }

 bool _scopeRequiresBidding(ProcurementItemModel item) {
 final value = item.responsibleMember.trim().toLowerCase();
 if (value.isEmpty) return true;
 if (value == 'no' || value.startsWith('no ')) return false;
 if (value == 'not required' || value == 'none') return false;
 return true;
 }

 String? _resolveWorkflowScopeId(List<ProcurementItemModel> items) {
 if (items.isEmpty) return null;
 if (_selectedWorkflowScopeId != null &&
 items.any((item) => item.id == _selectedWorkflowScopeId)) {
 return _selectedWorkflowScopeId;
 }
 return items.first.id;
 }

 void _hydrateWorkflowDraftForSelection(List<ProcurementItemModel> items) {
 if (!_customizeWorkflowByScope) {
 _workflowDraftSteps = _cloneWorkflowSteps(_globalWorkflowSteps);
 return;
 }

 final scopeId = _resolveWorkflowScopeId(items);
 if (scopeId == null) {
 _workflowDraftSteps = <_ContractingWorkflowStep>[];
 return;
 }

 final selectedScope = _findScopeById(items, scopeId);
 if (selectedScope != null && !_scopeRequiresBidding(selectedScope)) {
 _workflowDraftSteps = <_ContractingWorkflowStep>[];
 return;
 }

 final scopedSteps = _scopeWorkflowOverrides[scopeId];
 _workflowDraftSteps =
 _cloneWorkflowSteps(scopedSteps ?? _globalWorkflowSteps);
 }

 Future<void> _loadContractingWorkflowData(String projectId) async {
 if (projectId.trim().isEmpty) return;
 if (mounted) {
 setState(() => _workflowLoading = true);
 }

 try {
 // Retry up to 3 times to guard against transient Firestore
 // "INTERNAL ASSERTION FAILED" errors in SDK 12.x.
 QuerySnapshot<Map<String, dynamic>>? snapshot;
 for (var attempt = 1; attempt <= 3; attempt++) {
 try {
 snapshot = await _workflowCollection(projectId).get();
 break;
 } catch (e) {
 final isAssertionError =
 e.toString().contains('INTERNAL ASSERTION') ||
 e.toString().contains('Unexpected state');
 if (!isAssertionError || attempt == 3) rethrow;
 await Future<void>.delayed(
 Duration(milliseconds: 500 * (1 << (attempt - 1))));
 }
 }

 var global = _cloneWorkflowSteps(_defaultWorkflowTemplate);
 final overrides = <String, List<_ContractingWorkflowStep>>{};

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
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(global);
 _scopeWorkflowOverrides = overrides;
 if (_customizeWorkflowByScope) {
 final selected = _selectedWorkflowScopeId;
 if (selected != null && selected.isNotEmpty) {
 _workflowDraftSteps =
 _cloneWorkflowSteps(overrides[selected] ?? global);
 } else {
 _workflowDraftSteps = _cloneWorkflowSteps(global);
 }
 } else {
 _workflowDraftSteps = _cloneWorkflowSteps(global);
 }
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
 if (mounted) {
 setState(() => _workflowLoading = false);
 }
 }
 }

 void _setCustomizeWorkflowByScope(
 bool customizeByScope,
 List<ProcurementItemModel> items,
 ) {
 setState(() {
 _customizeWorkflowByScope = customizeByScope;
 if (!customizeByScope) {
 _selectedWorkflowScopeId = null;
 } else {
 _selectedWorkflowScopeId = _resolveWorkflowScopeId(items);
 }
 _hydrateWorkflowDraftForSelection(items);
 });
 }

 void _selectWorkflowScope(
 String scopeId,
 List<ProcurementItemModel> items,
 ) {
 setState(() {
 _selectedWorkflowScopeId = scopeId;
 _hydrateWorkflowDraftForSelection(items);
 });
 }

 void _resetWorkflowDraftToPreset(List<ProcurementItemModel> items) {
 setState(() {
 _workflowDraftSteps = _cloneWorkflowSteps(_defaultWorkflowTemplate);
 if (_customizeWorkflowByScope) {
 final selected = _findScopeById(items, _resolveWorkflowScopeId(items));
 if (selected != null && !_scopeRequiresBidding(selected)) {
 _workflowDraftSteps = <_ContractingWorkflowStep>[];
 }
 }
 });
 }

 void _addWorkflowStepToDraft() {
 setState(() {
 _workflowDraftSteps = <_ContractingWorkflowStep>[
 ..._workflowDraftSteps,
 _ContractingWorkflowStep(
 id: 'step_${DateTime.now().microsecondsSinceEpoch}',
 name: 'New Step',
 duration: 1,
 unit: 'week',
 ),
 ];
 });
 }

 void _removeWorkflowStepFromDraft(String stepId) {
 setState(() {
 _workflowDraftSteps =
 _workflowDraftSteps.where((step) => step.id != stepId).toList();
 });
 }

 void _moveWorkflowStepInDraft(int index, int direction) {
 final target = index + direction;
 if (index < 0 || target < 0 || target >= _workflowDraftSteps.length) {
 return;
 }
 setState(() {
 final next = List<_ContractingWorkflowStep>.from(_workflowDraftSteps);
 final current = next[index];
 next[index] = next[target];
 next[target] = current;
 _workflowDraftSteps = next;
 });
 }

 void _adjustWorkflowDuration(String stepId, int delta) {
 final index = _workflowDraftSteps.indexWhere((step) => step.id == stepId);
 if (index < 0) return;
 final current = _workflowDraftSteps[index];
 final nextDuration = (current.duration + delta).clamp(1, 104);
 setState(() {
 _workflowDraftSteps = [
 for (var i = 0; i < _workflowDraftSteps.length; i++)
 if (i == index)
 current.copyWith(duration: nextDuration)
 else
 _workflowDraftSteps[i],
 ];
 });
 }

 void _setWorkflowStepUnit(String stepId, String unit) {
 if (!_workflowDurationUnits.contains(unit)) return;
 final index = _workflowDraftSteps.indexWhere((step) => step.id == stepId);
 if (index < 0) return;
 final current = _workflowDraftSteps[index];
 setState(() {
 _workflowDraftSteps = [
 for (var i = 0; i < _workflowDraftSteps.length; i++)
 if (i == index)
 current.copyWith(unit: unit)
 else
 _workflowDraftSteps[i],
 ];
 });
 }

 Future<void> _editWorkflowStep(_ContractingWorkflowStep step) async {
 final nameController = TextEditingController(text: step.name);
 final durationController =
 TextEditingController(text: step.duration.toString());
 var selectedUnit = step.unit;

 final result = await showDialog<_ContractingWorkflowStep>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: const Text('Edit Workflow Step'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(labelText: 'Step Name'),
 textCapitalization: TextCapitalization.sentences,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: durationController,
 decoration:
 const InputDecoration(labelText: 'Duration (number)'),
 keyboardType: TextInputType.number,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedUnit,
 decoration: const InputDecoration(labelText: 'Duration Unit'),
 items: _workflowDurationUnits
 .map(
 (unit) => DropdownMenuItem<String>(
 value: unit,
 child: Text(unit == 'month' ? 'Month(s)' : 'Week(s)'),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => selectedUnit = value);
 },
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
 step.duration;
 Navigator.of(dialogContext).pop(
 step.copyWith(
 name: name.isEmpty ? step.name : name,
 duration: duration < 1 ? 1 : duration,
 unit: selectedUnit,
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );

 nameController.dispose();
 durationController.dispose();
 if (result == null) return;

 final index =
 _workflowDraftSteps.indexWhere((entry) => entry.id == step.id);
 if (index < 0) return;
 setState(() {
 _workflowDraftSteps = [
 for (var i = 0; i < _workflowDraftSteps.length; i++)
 if (i == index) result else _workflowDraftSteps[i],
 ];
 });
 }

 Future<void> _saveWorkflowForSelection(
 List<ProcurementItemModel> items, {
 required String? effectiveScopeId,
 }) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot save workflow.'),
 ),
 );
 return;
 }

 if (_workflowSaving) return;
 setState(() => _workflowSaving = true);
 try {
 final workflowCol = _workflowCollection(projectId);

 if (!_customizeWorkflowByScope) {
 await workflowCol.doc(_workflowGlobalDocId).set({
 'scopeId': 'all',
 'steps': _workflowDraftSteps.map((step) => step.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 });

 if (!mounted) return;
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(_workflowDraftSteps);
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Procurement workflow saved for all scopes.'),
 ),
 );
 return;
 }

 if (effectiveScopeId == null || effectiveScopeId.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Select a contract scope to save custom workflow.'),
 ),
 );
 }
 return;
 }

 final scope = _findScopeById(items, effectiveScopeId);
 final blankForNoBid = scope != null && !_scopeRequiresBidding(scope);
 final payloadSteps =
 blankForNoBid ? <_ContractingWorkflowStep>[] : _workflowDraftSteps;

 await workflowCol.doc('scope_$effectiveScopeId').set({
 'scopeId': effectiveScopeId,
 'steps': payloadSteps.map((step) => step.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 });

 if (!mounted) return;
 setState(() {
 _scopeWorkflowOverrides = {
 ..._scopeWorkflowOverrides,
 effectiveScopeId: _cloneWorkflowSteps(payloadSteps),
 };
 });
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(blankForNoBid
 ? 'Bidding is not required for this scope. Saved as a blank cycle.'
 : 'Custom workflow saved for selected scope.'),
 ),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to save workflow: $e')),
 );
 } finally {
 if (mounted) {
 setState(() => _workflowSaving = false);
 }
 }
 }

 Future<void> _applyWorkflowDraftToAllScopes() async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot apply workflow.'),
 ),
 );
 return;
 }
 if (_workflowSaving) return;

 setState(() => _workflowSaving = true);
 try {
 final workflowCol = _workflowCollection(projectId);
 final batch = FirebaseFirestore.instance.batch();
 batch.set(workflowCol.doc(_workflowGlobalDocId), {
 'scopeId': 'all',
 'steps': _workflowDraftSteps.map((step) => step.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 });

 for (final scopeId in _scopeWorkflowOverrides.keys) {
 batch.delete(workflowCol.doc('scope_$scopeId'));
 }

 await batch.commit();

 if (!mounted) return;
 setState(() {
 _globalWorkflowSteps = _cloneWorkflowSteps(_workflowDraftSteps);
 _scopeWorkflowOverrides = <String, List<_ContractingWorkflowStep>>{};
 _customizeWorkflowByScope = false;
 _selectedWorkflowScopeId = null;
 _hydrateWorkflowDraftForSelection(const <ProcurementItemModel>[]);
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Workflow applied to all contract scopes (scope overrides cleared).'),
 ),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to apply workflow to all scopes: $e')),
 );
 } finally {
 if (mounted) {
 setState(() => _workflowSaving = false);
 }
 }
 }

 int _totalWorkflowDurationInWeeks(List<_ContractingWorkflowStep> steps) {
 var totalWeeks = 0;
 for (final step in steps) {
 totalWeeks += step.unit == 'month' ? step.duration * 4 : step.duration;
 }
 return totalWeeks;
 }

 Widget _buildWorkflowStepCard(
 _ContractingWorkflowStep step,
 int index,
 int totalCount,
 ) {
 final durationLabel = step.unit == 'month'
 ? '${step.duration} month${step.duration == 1 ? '' : 's'}'
 : '${step.duration} week${step.duration == 1 ? '' : 's'}';

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 CircleAvatar(
 radius: 11,
 backgroundColor: const Color(0xFFEFF6FF),
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 step.name,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 IconButton(
 tooltip: 'Rename or edit',
 onPressed: () => _editWorkflowStep(step),
 icon: const Icon(Icons.edit_outlined, size: 18),
 visualDensity: VisualDensity.compact,
 ),
 IconButton(
 tooltip: 'Delete step',
 onPressed: () => _removeWorkflowStepFromDraft(step.id),
 icon: const Icon(Icons.delete_outline, size: 18),
 visualDensity: VisualDensity.compact,
 color: Colors.red.shade600,
 ),
 ],
 ),
 const SizedBox(height: 8),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 durationLabel,
 style: const TextStyle(
 fontSize: 11.5,
 color: Color(0xFF1F2937),
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 OutlinedButton.icon(
 onPressed: () => _adjustWorkflowDuration(step.id, -1),
 icon: const Icon(Icons.remove, size: 14),
 label: const Text('1'),
 style: OutlinedButton.styleFrom(
 visualDensity: VisualDensity.compact,
 ),
 ),
 OutlinedButton.icon(
 onPressed: () => _adjustWorkflowDuration(step.id, 1),
 icon: const Icon(Icons.add, size: 14),
 label: const Text('1'),
 style: OutlinedButton.styleFrom(
 visualDensity: VisualDensity.compact,
 ),
 ),
 SizedBox(
 width: 130,
 child: DropdownButtonFormField<String>(
 value: step.unit,
 decoration: const InputDecoration(
 isDense: true,
 labelText: 'Unit',
 ),
 items: _workflowDurationUnits
 .map(
 (unit) => DropdownMenuItem<String>(
 value: unit,
 child: Text(
 unit == 'month' ? 'Month(s)' : 'Week(s)',
 style: const TextStyle(fontSize: 12),
 ),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 _setWorkflowStepUnit(step.id, value);
 },
 ),
 ),
 IconButton(
 tooltip: 'Move up',
 onPressed: index == 0
 ? null
 : () => _moveWorkflowStepInDraft(index, -1),
 icon: const Icon(Icons.arrow_upward_rounded, size: 18),
 visualDensity: VisualDensity.compact,
 ),
 IconButton(
 tooltip: 'Move down',
 onPressed: index == totalCount - 1
 ? null
 : () => _moveWorkflowStepInDraft(index, 1),
 icon: const Icon(Icons.arrow_downward_rounded, size: 18),
 visualDensity: VisualDensity.compact,
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildContractingWorkflowSection(List<ProcurementItemModel> items) {
 final effectiveScopeId = _resolveWorkflowScopeId(items);
 if (_customizeWorkflowByScope &&
 effectiveScopeId != _selectedWorkflowScopeId &&
 effectiveScopeId != null) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 setState(() {
 _selectedWorkflowScopeId = effectiveScopeId;
 _hydrateWorkflowDraftForSelection(items);
 });
 });
 }

 if (_customizeWorkflowByScope &&
 effectiveScopeId == null &&
 _selectedWorkflowScopeId != null) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 setState(() {
 _selectedWorkflowScopeId = null;
 _workflowDraftSteps = <_ContractingWorkflowStep>[];
 });
 });
 }

 final selectedScope = _findScopeById(items, effectiveScopeId);
 final requiresBidding =
 selectedScope == null || _scopeRequiresBidding(selectedScope);
 final showBlankCycle = _customizeWorkflowByScope && !requiresBidding;
 final disableCycleActions = showBlankCycle;
 final steps = showBlankCycle
 ? const <_ContractingWorkflowStep>[]
 : _workflowDraftSteps;
 final totalWeeks = _totalWorkflowDurationInWeeks(steps);

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
 selected: !_customizeWorkflowByScope,
 onSelected: (_) => _setCustomizeWorkflowByScope(false, items),
 ),
 ChoiceChip(
 label: const Text('Customize by Scope'),
 selected: _customizeWorkflowByScope,
 onSelected: items.isEmpty
 ? null
 : (_) => _setCustomizeWorkflowByScope(true, items),
 ),
 if (_customizeWorkflowByScope)
 SizedBox(
 width: 320,
 child: DropdownButtonFormField<String>(
 value: effectiveScopeId,
 decoration: const InputDecoration(
 labelText: 'Contract Scope',
 isDense: true,
 ),
 items: items
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
 onChanged: (value) {
 if (value == null) return;
 _selectWorkflowScope(value, items);
 },
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: disableCycleActions
 ? const Color(0xFFF3F4F6)
 : Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: disableCycleActions
 ? const Color(0xFFD1D5DB)
 : const Color(0xFFD1D5DB),
 ),
 ),
 child: Text(
 'Total Cycle: $totalWeeks week${totalWeeks == 1 ? '' : 's'}',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: disableCycleActions
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF1F2937),
 ),
 ),
 ),
 if (_workflowLoading)
 const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (_customizeWorkflowByScope &&
 selectedScope == null &&
 items.isNotEmpty)
 const Text(
 'Select a contract scope to configure its workflow.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 )
 else if (_customizeWorkflowByScope && items.isEmpty)
 const Text(
 'No contract scopes found. Add scope items first.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 )
 else if (showBlankCycle)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFD1D5DB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(
 Icons.lock_outline_rounded,
 size: 16,
 color: Color(0xFF6B7280),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Bidding is not required for "${selectedScope.name.trim().isEmpty ? 'this scope' : selectedScope.name.trim()}". The contracting workflow is greyed out for this selection.',
 style: const TextStyle(
 fontSize: 12,
 height: 1.35,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 ],
 ),
 )
 else ...[
 if (steps.isEmpty)
 Container(
 width: double.infinity,
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No workflow steps yet. Add your first step to build a bidding cycle.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 )
 else
 Column(
 children: [
 for (var i = 0; i < steps.length; i++) ...[
 _buildWorkflowStepCard(steps[i], i, steps.length),
 if (i != steps.length - 1) const SizedBox(height: 8),
 ],
 ],
 ),
 const SizedBox(height: 10),
 TextButton.icon(
 onPressed: _addWorkflowStepToDraft,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Step'),
 ),
 ],
 const SizedBox(height: 6),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 OutlinedButton.icon(
 onPressed: _workflowSaving || disableCycleActions
 ? null
 : () => _resetWorkflowDraftToPreset(items),
 icon: const Icon(Icons.restart_alt_rounded, size: 16),
 label: const Text('Reset Preset'),
 ),
 ElevatedButton.icon(
 onPressed: _workflowSaving || disableCycleActions
 ? null
 : () => _saveWorkflowForSelection(
 items,
 effectiveScopeId: effectiveScopeId,
 ),
 icon: _workflowSaving
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.save_outlined, size: 16),
 label: Text(
 _customizeWorkflowByScope
 ? 'Save Scope Workflow'
 : 'Save Workflow',
 ),
 ),
 TextButton.icon(
 onPressed: _workflowSaving
 ? null
 : () => _applyWorkflowDraftToAllScopes(),
 icon: const Icon(Icons.publish_rounded, size: 16),
 label: const Text('Apply to All Scopes'),
 ),
 ],
 ),
 ],
 ),
 );
 }

 CollectionReference<Map<String, dynamic>> _scopeManagementCollection(
 String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection(_scopeManagementCollectionName);
 }

 String _currentUserEmail() {
 return (FirebaseAuth.instance.currentUser?.email ?? '').trim();
 }

 String _currentUserRoleInProject() {
 if (AdminEditToggle.isAdmin()) return 'Admin';
 final data = ProjectDataHelper.getData(context);
 final email = _currentUserEmail().toLowerCase();
 if (email.isNotEmpty) {
 for (final member in data.teamMembers) {
 if (member.email.trim().toLowerCase() == email &&
 member.role.trim().isNotEmpty) {
 return member.role.trim();
 }
 }
 }
 return 'Member';
 }

 List<String> _availableContractRoles() {
 final data = ProjectDataHelper.getData(context);
 final ordered = <String>[
 'Contract Manager',
 'Project Manager',
 'Contracting Lead',
 'Sponsor',
 'Admin',
 'Member',
 ];
 final unique = <String, String>{};
 for (final role in ordered) {
 if (role.trim().isEmpty) continue;
 unique[role.toLowerCase()] = role;
 }
 for (final member in data.teamMembers) {
 final role = member.role.trim();
 if (role.isEmpty) continue;
 unique.putIfAbsent(role.toLowerCase(), () => role);
 }

 final list = unique.values.toList();
 list.sort((a, b) {
 final ia = ordered.indexWhere((entry) => entry == a);
 final ib = ordered.indexWhere((entry) => entry == b);
 if (ia == -1 && ib == -1) {
 return a.toLowerCase().compareTo(b.toLowerCase());
 }
 if (ia == -1) return 1;
 if (ib == -1) return -1;
 return ia.compareTo(ib);
 });
 return list;
 }

 String _defaultAuthorizedRole(List<String> roles) {
 for (final candidate in const [
 'Contract Manager',
 'Project Manager',
 'Contracting Lead',
 'Member'
 ]) {
 if (roles.contains(candidate)) return candidate;
 }
 return roles.isEmpty ? 'Member' : roles.first;
 }

 DateTime? _parseDateTime(dynamic value) {
 if (value is Timestamp) return value.toDate();
 if (value is DateTime) return value;
 if (value is String) return DateTime.tryParse(value);
 return null;
 }

 Future<void> _loadScopeManagementData(String projectId) async {
 if (projectId.trim().isEmpty) return;
 if (mounted) {
 setState(() => _scopeManagementLoading = true);
 }

 try {
 final snapshot = await _scopeManagementCollection(projectId).get();
 final next = <String, _ContractScopeManagementState>{};

 for (final doc in snapshot.docs) {
 final data = doc.data();
 final scopeId = (data['scopeId'] ?? doc.id).toString().trim();
 if (scopeId.isEmpty) continue;
 next[scopeId] = _ContractScopeManagementState(
 scopeId: scopeId,
 authorizedRole: (data['authorizedRole'] ?? '').toString().trim(),
 started: data['started'] == true,
 startedAt: _parseDateTime(data['startedAt']),
 startedByEmail: (data['startedByEmail'] ?? '').toString().trim(),
 startedByRole: (data['startedByRole'] ?? '').toString().trim(),
 );
 }

 if (!mounted) return;
 setState(() {
 _scopeManagementByScopeId = next;
 if (_actingContractRole.trim().isEmpty) {
 _actingContractRole = _currentUserRoleInProject();
 }
 });
 } catch (e) {
 if (!mounted) return;
 final denied = e is FirebaseException && e.code == 'permission-denied';
 final message = denied
 ? 'Scope management data is locked by Firestore permissions.'
 : 'Scope management data is temporarily unavailable. You can continue working.';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(message)),
 );
 } finally {
 if (mounted) {
 setState(() => _scopeManagementLoading = false);
 }
 }
 }

 _ContractScopeManagementState _scopeStateForItem(
 ProcurementItemModel item,
 List<String> roles,
 ) {
 final existing = _scopeManagementByScopeId[item.id];
 if (existing != null) {
 if (existing.authorizedRole.trim().isNotEmpty) return existing;
 final defaultRole = _defaultAuthorizedRole(roles);
 return existing.copyWith(authorizedRole: defaultRole);
 }
 return _ContractScopeManagementState(
 scopeId: item.id,
 authorizedRole: _defaultAuthorizedRole(roles),
 started: false,
 startedAt: null,
 startedByEmail: '',
 startedByRole: '',
 );
 }

 bool _canCommenceScope({
 required _ContractScopeManagementState state,
 required String actingRole,
 }) {
 if (AdminEditToggle.isAdmin()) return true;
 return state.authorizedRole.trim().toLowerCase() ==
 actingRole.trim().toLowerCase();
 }

 Future<void> _updateScopeAuthorizedRole(
 ProcurementItemModel item,
 String role,
 List<String> availableRoles,
 ) async {
 if (!AdminEditToggle.isAdmin()) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Only admins can change authorized role for scope commencement.',
 ),
 ),
 );
 return;
 }
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;

 final current = _scopeStateForItem(item, availableRoles);
 final next = current.copyWith(authorizedRole: role);
 setState(() {
 _scopeManagementByScopeId = {
 ..._scopeManagementByScopeId,
 item.id: next,
 };
 });

 try {
 await _scopeManagementCollection(projectId).doc(item.id).set({
 ...next.toMap(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (e) {
 if (!mounted) return;
 final denied = e is FirebaseException && e.code == 'permission-denied';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 denied
 ? 'Authorized role updated locally, but Firestore permissions blocked sync. Deploy updated rules to persist this change.'
 : 'Unable to update authorized role: $e',
 ),
 ),
 );
 }
 }

 Future<void> _startProcessForScope(
 ProcurementItemModel item,
 String actingRole,
 List<String> availableRoles,
 ) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot start scope process.'),
 ),
 );
 return;
 }
 final state = _scopeStateForItem(item, availableRoles);
 if (state.started) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('This scope process is already started.')),
 );
 return;
 }
 final canStart = _canCommenceScope(state: state, actingRole: actingRole);
 if (!canStart) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Only "${state.authorizedRole}" role can commence this scope.',
 ),
 ),
 );
 return;
 }

 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Start Scope Process?'),
 content: Text(
 'Commence contracting activities for "${item.name.trim().isEmpty ? 'this scope' : item.name.trim()}" now?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Start Process'),
 ),
 ],
 ),
 ) ??
 false;
 if (!confirmed) return;

 if (_scopeManagementSaving) return;
 final startedAt = DateTime.now();
 final startedState = state.copyWith(
 started: true,
 startedAt: startedAt,
 startedByEmail: _currentUserEmail(),
 startedByRole: actingRole,
 );
 setState(() => _scopeManagementSaving = true);
 try {
 await _scopeManagementCollection(projectId).doc(item.id).set({
 ...startedState.toMap(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));

 if (!mounted) return;
 setState(() {
 _scopeManagementByScopeId = {
 ..._scopeManagementByScopeId,
 item.id: startedState,
 };
 _selectedManagementTab = _ContractingManagementTab.contractingTemplates;
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Scope process started. Templates, tracking, and reports are now unlocked.',
 ),
 ),
 );
 } catch (e) {
 if (!mounted) return;
 if (e is FirebaseException && e.code == 'permission-denied') {
 final continueLocal = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Firestore Permission Required'),
 content: const Text(
 'This project cannot write to Contract Scope Management in Firestore yet. Continue locally for now and sync later?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Continue Locally'),
 ),
 ],
 ),
 ) ??
 false;
 if (!mounted || !continueLocal) return;
 setState(() {
 _scopeManagementByScopeId = {
 ..._scopeManagementByScopeId,
 item.id: startedState,
 };
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Scope process started locally for this session. Deploy updated Firestore rules to persist.',
 ),
 ),
 );
 return;
 }
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to start scope process: $e')),
 );
 } finally {
 if (mounted) {
 setState(() => _scopeManagementSaving = false);
 }
 }
 }

 String _formatDateTimeShort(DateTime value) {
 final month = value.month.toString().padLeft(2, '0');
 final day = value.day.toString().padLeft(2, '0');
 final hour = value.hour.toString().padLeft(2, '0');
 final minute = value.minute.toString().padLeft(2, '0');
 return '${value.year}-$month-$day $hour:$minute';
 }

 DateTime? _parseNotesDate(dynamic raw) {
 if (raw == null) return null;
 if (raw is Timestamp) return raw.toDate();
 if (raw is DateTime) return raw;
 final parsed = DateTime.tryParse(raw.toString());
 return parsed;
 }

 Widget _buildManagementTabButton({
 required String label,
 required _ContractingManagementTab tab,
 required bool enabled,
 }) {
 final selected = _selectedManagementTab == tab;
 final baseColor =
 selected ? const Color(0xFFEFF6FF) : const Color(0xFFFFFFFF);
 final borderColor = selected
 ? const Color(0xFF93C5FD)
 : (enabled ? const Color(0xFFE5E7EB) : const Color(0xFFE5E7EB));
 final textColor = selected
 ? const Color(0xFF1D4ED8)
 : (enabled ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF));

 return InkWell(
 onTap: enabled
 ? () {
 if (_selectedManagementTab == tab) return;
 setState(() => _selectedManagementTab = tab);
 }
 : null,
 borderRadius: BorderRadius.circular(9),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 120),
 curve: Curves.easeOut,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: enabled ? baseColor : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(9),
 border: Border.all(color: borderColor),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (!enabled) ...[
 const Icon(Icons.lock_outline_rounded,
 size: 13, color: Color(0xFF9CA3AF)),
 const SizedBox(width: 5),
 ],
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: textColor,
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildContractScopeManagementSection(
 List<ProcurementItemModel> items,
 List<VendorModel> contractors,
 ) {
 final availableRoles = _availableContractRoles();
 final inferredRole = _currentUserRoleInProject();
 var actingRole = _actingContractRole.trim().isEmpty
 ? inferredRole
 : _actingContractRole.trim();
 if (!availableRoles.contains(actingRole) && availableRoles.isNotEmpty) {
 actingRole = availableRoles.first;
 }
 if (_actingContractRole != actingRole) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 setState(() => _actingContractRole = actingRole);
 });
 }

 final hasStartedScope = items.any((item) {
 final state = _scopeManagementByScopeId[item.id];
 return state?.started == true;
 });

 if (!hasStartedScope &&
 _selectedManagementTab != _ContractingManagementTab.scopeManagement) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 setState(() =>
 _selectedManagementTab = _ContractingManagementTab.scopeManagement);
 });
 }

 final approvedMap = <String, String>{};
 for (final contractor in contractors) {
 final name = contractor.name.trim();
 if (name.isEmpty) continue;
 approvedMap.putIfAbsent(name.toLowerCase(), () => name);
 }
 for (final item in items) {
 for (final contractor in _splitContractorTokens(item.notes)) {
 approvedMap.putIfAbsent(contractor.toLowerCase(), () => contractor);
 }
 }
 final approvedContractors = approvedMap.values.toList()
 ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 _buildManagementTabButton(
 label: 'Contract Scope Management',
 tab: _ContractingManagementTab.scopeManagement,
 enabled: true,
 ),
 const SizedBox(width: 8),
 _buildManagementTabButton(
 label: 'Contracting Templates',
 tab: _ContractingManagementTab.contractingTemplates,
 enabled: hasStartedScope,
 ),
 const SizedBox(width: 8),
 _buildManagementTabButton(
 label: 'Contract Tracking',
 tab: _ContractingManagementTab.contractTracking,
 enabled: hasStartedScope,
 ),
 const SizedBox(width: 8),
 _buildManagementTabButton(
 label: 'Reports',
 tab: _ContractingManagementTab.reports,
 enabled: hasStartedScope,
 ),
 if (_scopeManagementLoading) ...[
 const SizedBox(width: 8),
 const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ],
 ],
 ),
 ),
 const SizedBox(height: 12),
 if (_selectedManagementTab !=
 _ContractingManagementTab.scopeManagement)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: _selectedManagementTab ==
 _ContractingManagementTab.contractingTemplates
 ? _buildTemplatesTab(items)
 : _selectedManagementTab ==
 _ContractingManagementTab.contractTracking
 ? _buildTrackingTab(items)
 : _buildReportsTab(items, contractors),
 )
 else ...[
 Row(
 children: [
 Expanded(
 child: Text(
 'Commence scope processes in this stage using role-based authority.',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 const SizedBox(width: 10),
 OutlinedButton.icon(
 onPressed: _scopeManagementSaving ? null : _openAddItemDialog,
 icon: const Icon(Icons.add_circle_outline, size: 16),
 label: const Text('Add Scope'),
 ),
 const SizedBox(width: 10),
 OutlinedButton.icon(
 onPressed: _scopeManagementSaving
 ? null
 : () => _openAddContractorDialog(
 existingContractors: contractors,
 ),
 icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
 label: const Text('Add Contractor'),
 ),
 const SizedBox(width: 10),
 SizedBox(
 width: 240,
 child: DropdownButtonFormField<String>(
 value: actingRole,
 decoration: const InputDecoration(
 labelText: 'Acting Role',
 isDense: true,
 ),
 items: availableRoles
 .map((role) => DropdownMenuItem<String>(
 value: role,
 child:
 Text(role, overflow: TextOverflow.ellipsis),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => _actingContractRole = value);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 if (items.isEmpty)
 Container(
 width: double.infinity,
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 const Expanded(
 child: Text(
 'No contract scopes found. Add scope items to manage commencement.',
 style:
 TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton(
 onPressed: _openAddItemDialog,
 child: const Text('Add Scope'),
 ),
 ],
 ),
 )
 else
 Column(
 children: [
 for (var i = 0; i < items.length; i++) ...[
 Builder(
 builder: (context) {
 final item = items[i];
 final state = _scopeStateForItem(item, availableRoles);
 final canStart = _canCommenceScope(
 state: state, actingRole: actingRole);
 final scopeContractors = _contractorsForScope(item);
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.name.trim().isEmpty
 ? 'Untitled Scope'
 : item.name.trim(),
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: state.started
 ? const Color(0xFFECFDF3)
 : const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(
 color: state.started
 ? const Color(0xFFB7E4C7)
 : const Color(0xFFFDE68A),
 ),
 ),
 child: Text(
 state.started
 ? 'In Progress'
 : 'Pending Start',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: state.started
 ? const Color(0xFF166534)
 : const Color(0xFF92400E),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Wrap(
 spacing: 10,
 runSpacing: 8,
 children: [
 SizedBox(
 width: 260,
 child: DropdownButtonFormField<String>(
 value: availableRoles
 .contains(state.authorizedRole)
 ? state.authorizedRole
 : _defaultAuthorizedRole(
 availableRoles),
 decoration: const InputDecoration(
 labelText: 'Authorized Role',
 isDense: true,
 ),
 items: availableRoles
 .map((role) =>
 DropdownMenuItem<String>(
 value: role,
 child: Text(role),
 ))
 .toList(),
 onChanged: !AdminEditToggle.isAdmin()
 ? null
 : (value) {
 if (value == null) return;
 _updateScopeAuthorizedRole(
 item,
 value,
 availableRoles,
 );
 },
 ),
 ),
 SizedBox(
 width: 220,
 child: VoiceTextFormField(
 initialValue:
 item.projectPhase.trim().isEmpty
 ? 'Planning'
 : item.projectPhase.trim(),
 readOnly: true,
 decoration: const InputDecoration(
 labelText: 'Current Stage',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contractors:',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: scopeContractors.isEmpty
 ? const Text(
 'None assigned yet.',
 style: TextStyle(
 fontSize: 11.5,
 color: Color(0xFF9CA3AF),
 ),
 )
 : Wrap(
 spacing: 6,
 runSpacing: 6,
 children: scopeContractors
 .map(
 (name) => Container(
 padding: const EdgeInsets
 .symmetric(
 horizontal: 8,
 vertical: 4),
 decoration: BoxDecoration(
 color: const Color(
 0xFFEFF6FF),
 borderRadius:
 BorderRadius.circular(
 999),
 border: Border.all(
 color: const Color(
 0xFFBFDBFE),
 ),
 ),
 child: Text(
 name,
 style: const TextStyle(
 fontSize: 11,
 fontWeight:
 FontWeight.w600,
 color:
 Color(0xFF1E3A8A),
 ),
 ),
 ),
 )
 .toList(),
 ),
 ),
 const SizedBox(width: 8),
 TextButton(
 onPressed: () async {
 await _promptAssignContractorToScopes(
 contractorName: '',
 scopes: [item],
 );
 },
 child: const Text('Assign'),
 ),
 const SizedBox(width: 4),
 TextButton(
 onPressed: () => _openEditItemDialog(item),
 child: const Text('Manage Scope'),
 ),
 ],
 ),
 const SizedBox(height: 8),
 if (state.startedAt != null)
 Text(
 'Started by ${state.startedByRole.trim().isEmpty ? '-' : state.startedByRole} (${state.startedByEmail.trim().isEmpty ? 'unknown user' : state.startedByEmail}) on ${_formatDateTimeShort(state.startedAt!)}',
 style: const TextStyle(
 fontSize: 11.5,
 color: Color(0xFF4B5563),
 ),
 ),
 if (!state.started && !canStart)
 Text(
 'Role authority required: "${state.authorizedRole}".',
 style: const TextStyle(
 fontSize: 11.5,
 color: Color(0xFFB45309),
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Align(
 alignment: Alignment.centerLeft,
 child: ElevatedButton.icon(
 onPressed: (state.started ||
 !canStart ||
 _scopeManagementSaving)
 ? null
 : () => _startProcessForScope(
 item,
 actingRole,
 availableRoles,
 ),
 icon: const Icon(Icons.play_arrow_rounded,
 size: 16),
 label: const Text(
 'Start Process for this Scope'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 ),
 ),
 ),
 ],
 ),
 );
 },
 ),
 if (i != items.length - 1) const SizedBox(height: 8),
 ],
 ],
 ),
 ],
 const SizedBox(height: 14),
 Row(
 children: [
 const Text(
 'Approved Contractors',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 OutlinedButton.icon(
 onPressed: () => _openAddContractorDialog(
 existingContractors: contractors,
 ),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Contractor'),
 ),
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: _openApprovedContractorList,
 icon: const Icon(Icons.fact_check_outlined, size: 15),
 label: const Text('View Full List'),
 ),
 ],
 ),
 const SizedBox(height: 8),
 _buildApprovedContractorsTable(
 contractors: contractors,
 items: items,
 approvedNames: approvedContractors,
 ),
 ],
 ),
 );
 }

 String? _activeProjectIdOrNull() {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.trim().isEmpty) {
 return null;
 }
 return projectId.trim();
 }

 void _loadMoreContracts() {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;
 setState(() {
 _contractQueryLimit += _loadMoreStep;
 _bindProcurementStreams(projectId);
 });
 }

 void _loadMoreItems() {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;
 setState(() {
 _itemQueryLimit += _loadMoreStep;
 _bindProcurementStreams(projectId);
 });
 }

 Future<void> _openAddContractDialog() async {
 final projectData = ProjectDataHelper.getData(context);
 final projectId = projectData.projectId;

 if (projectId == null || projectId.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot add contract.')),
 );
 return;
 }

 final categoryOptions = const [
 'Construction',
 'Services',
 'Consulting',
 'Other',
 ];
 final result = await showDialog<ContractModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (ctx) => AddContractDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 ),
 );

 if (result != null) {
 final contractToSave = result.copyWith(projectId: projectId);
 await ProcurementService.createContract(contractToSave);
 }
 }

 Future<void> _openEditContractDialog(ContractModel contract) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;

 final categoryOptions = const [
 'Construction',
 'Services',
 'Consulting',
 'Other',
 ];
 final result = await showDialog<ContractModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (ctx) => AddContractDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 initialContract: contract,
 ),
 );

 if (result == null) return;
 await ProcurementService.updateContract(
 projectId,
 contract.id,
 {
 'title': result.title,
 'description': result.description,
 'contractorName': result.contractorName,
 'estimatedCost': result.estimatedCost,
 'duration': result.duration,
 'status': result.status.name,
 'owner': result.owner,
 'startDate': result.startDate == null
 ? null
 : Timestamp.fromDate(result.startDate!),
 'endDate':
 result.endDate == null ? null : Timestamp.fromDate(result.endDate!),
 },
 );
 }

 Future<void> _deleteContract(ContractModel contract) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete contract?'),
 content: const Text('Are you sure you want to delete this contract?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context, false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(context, true),
 child: const Text('Delete', style: TextStyle(color: Colors.red)),
 ),
 ],
 ),
 );
 if (confirmed != true) return;

 await ProcurementService.deleteContract(projectId, contract.id);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contract deleted.')),
 );
 }

 Future<void> _openAddContractorDialog({
 List<VendorModel> existingContractors = const <VendorModel>[],
 }) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot add contractor.'),
 ),
 );
 return;
 }

 final categoryOptions = const [
 'Construction Services',
 'Services',
 'Consulting',
 'Materials',
 'Security',
 'Logistics',
 'Other',
 ];

 final result = await showDialog<VendorModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) => AddVendorDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 showAiGenerateButton: false,
 partnerLabel: 'Contractor',
 partnerPluralLabel: 'Contractors',
 existingPartners: existingContractors,
 allowExistingAutofill: true,
 ),
 );

 if (result == null) return;
 if (!mounted) return;

 final normalizedName = result.name.trim().toLowerCase();
 final alreadyExists = existingContractors.any(
 (contractor) => contractor.name.trim().toLowerCase() == normalizedName,
 );
 if (!alreadyExists) {
 try {
 await VendorService.createVendor(
 projectId: projectId,
 name: result.name.trim(),
 category: result.category.trim(),
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
 notes: result.notes,
 createdById: result.createdById,
 createdByEmail: result.createdByEmail,
 createdByName: result.createdByName,
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to add contractor: $e')),
 );
 return;
 }
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Contractor already exists. Existing details were reused.',
 ),
 ),
 );
 }

 final scopes = await (_itemsStream?.first.timeout(
 const Duration(seconds: 6),
 onTimeout: () => const <ProcurementItemModel>[],
 ) ??
 Future.value(const <ProcurementItemModel>[]));
 if (!mounted) return;
 await _promptAssignContractorToScopes(
 contractorName: result.name.trim(),
 scopes: scopes,
 );
 }

 Future<void> _openEditContractorDialog(VendorModel contractor) async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) return;

 final categoryOptions = const [
 'Construction Services',
 'Services',
 'Consulting',
 'Materials',
 'Security',
 'Logistics',
 'Other',
 ];

 final result = await showDialog<VendorModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) => AddVendorDialog(
 contextChips: _buildDialogContextChips(),
 categoryOptions: categoryOptions,
 showAiGenerateButton: false,
 partnerLabel: 'Contractor',
 partnerPluralLabel: 'Contractors',
 initialVendor: contractor,
 existingPartners: const <VendorModel>[],
 allowExistingAutofill: false,
 ),
 );

 if (result == null) return;
 try {
 await VendorService.updateVendor(
 projectId: projectId,
 vendorId: contractor.id,
 name: result.name.trim(),
 category: result.category.trim(),
 criticality: result.criticality,
 sla: result.sla,
 slaPerformance: result.slaPerformance,
 leadTime: result.leadTime,
 requiredDeliverables: result.requiredDeliverables,
 rating: result.rating,
 status: result.status,
 nextReview: result.nextReview,
 contractId: result.contractId,
 onTimeDelivery: result.onTimeDelivery,
 incidentResponse: result.incidentResponse,
 qualityScore: result.qualityScore,
 costAdherence: result.costAdherence,
 notes: result.notes,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contractor updated.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to update contractor: $e')),
 );
 }
 }

 Future<void> _confirmDeleteContractor(VendorModel contractor) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Remove contractor?'),
 content: Text(
 'Remove "${contractor.name}" from the approved contractors list?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 child:
 const Text('Remove', style: TextStyle(color: Colors.red)),
 ),
 ],
 ),
 ) ??
 false;
 if (!confirmed) return;

 try {
 await VendorService.deleteVendor(
 projectId: contractor.projectId,
 vendorId: contractor.id,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contractor removed.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to remove contractor: $e')),
 );
 }
 }

 Future<ProcurementItemModel?> _showContractScopeDialog({
 ProcurementItemModel? existing,
 }) async {
 final scopeController = TextEditingController(text: existing?.name ?? '');
 final descriptionController =
 TextEditingController(text: existing?.description ?? '');
 final contractorsController =
 TextEditingController(text: existing?.notes ?? '');
 final valueController = TextEditingController(
 text: existing != null ? existing.budget.toStringAsFixed(0) : '',
 );
 final durationController =
 TextEditingController(text: existing?.comments ?? '');

 var contractType = (existing?.category ?? '').trim();
 if (!_contractTypeOptions.contains(contractType)) {
 contractType = _contractTypeOptions.first;
 }
 var biddingRequired = (existing?.responsibleMember ?? '').trim();
 if (!_biddingOptions.contains(biddingRequired)) {
 biddingRequired = _biddingOptions.last;
 }
 var startStage = (existing?.projectPhase ?? '').trim();
 if (!_startStageOptions.contains(startStage)) {
 startStage = _startStageOptions[1];
 }

 final result = await showDialog<ProcurementItemModel>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: Text(existing == null
 ? 'Add Contracting Scope'
 : 'Edit Contracting Scope'),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: scopeController,
 decoration:
 const InputDecoration(labelText: 'Contract Scope'),
 textCapitalization: TextCapitalization.sentences,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 decoration: const InputDecoration(labelText: 'Description'),
 maxLines: 2,
 textCapitalization: TextCapitalization.sentences,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: contractorsController,
 decoration: const InputDecoration(
 labelText:
 'Potential Contractors (comma-separated names)',
 ),
 maxLines: 2,
 textCapitalization: TextCapitalization.words,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: contractType,
 items: _contractTypeOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => contractType = value);
 },
 decoration:
 const InputDecoration(labelText: 'Contract Type'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: valueController,
 decoration: const InputDecoration(
 labelText: 'Estimated Value (USD)',
 ),
 keyboardType:
 const TextInputType.numberWithOptions(decimal: true),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: durationController,
 decoration:
 const InputDecoration(labelText: 'Estimated Duration'),
 textCapitalization: TextCapitalization.sentences,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: biddingRequired,
 items: _biddingOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => biddingRequired = value);
 },
 decoration:
 const InputDecoration(labelText: 'Bidding Required'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: startStage,
 items: _startStageOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => startStage = value);
 },
 decoration: const InputDecoration(
 labelText: 'Contracting Start Stage',
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final scope = scopeController.text.trim();
 if (scope.isEmpty) return;
 final budget =
 double.tryParse(valueController.text.trim()) ?? 0.0;
 final base = existing ??
 ProcurementItemModel(
 id: '',
 projectId: '',
 name: '',
 description: '',
 category: contractType,
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 );

 Navigator.pop(
 dialogContext,
 base.copyWith(
 name: scope,
 description: descriptionController.text.trim(),
 category: contractType,
 budget: budget,
 notes: contractorsController.text.trim(),
 comments: durationController.text.trim(),
 responsibleMember: biddingRequired,
 projectPhase: startStage,
 status: ProcurementItemStatus.planning,
 updatedAt: DateTime.now(),
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );

 scopeController.dispose();
 descriptionController.dispose();
 contractorsController.dispose();
 valueController.dispose();
 durationController.dispose();
 return result;
 }

 Future<void> _openAddItemDialog() async {
 final projectData = ProjectDataHelper.getData(context);
 final projectId = projectData.projectId;

 if (projectId == null || projectId.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot add scope item.')),
 );
 return;
 }

 final result = await _showContractScopeDialog();

 if (result != null) {
 try {
 final itemToSave = result.copyWith(projectId: projectId);
 await ProcurementService.createItem(itemToSave);
 } catch (e) {
 debugPrint('Error creating item: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error creating item: $e')),
 );
 }
 }
 }
 }

 Future<void> _openEditItemDialog(ProcurementItemModel item) async {
 final result = await _showContractScopeDialog(existing: item);

 if (result == null) return;

 try {
 await ProcurementService.updateItem(item.projectId, item.id, {
 'name': result.name,
 'description': result.description,
 'category': result.category,
 'status': result.status.name,
 'priority': result.priority.name,
 'budget': result.budget,
 'spent': result.spent,
 'estimatedDelivery': result.estimatedDelivery,
 'actualDelivery': result.actualDelivery,
 'progress': result.progress,
 'vendorId': result.vendorId,
 'contractId': result.contractId,
 'events': result.events.map((e) => e.toJson()).toList(),
 'notes': result.notes,
 'projectPhase': result.projectPhase,
 'responsibleMember': result.responsibleMember,
 'comments': result.comments,
 });

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contracting scope item updated.')),
 );
 }
 } catch (e) {
 debugPrint('Error updating item: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error updating item: $e')),
 );
 }
 }
 }

 Future<void> _deleteItem(ProcurementItemModel item) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Delete contracting scope item?'),
 content: Text(
 'This will permanently remove "${item.name}" from this project.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text(
 'Delete',
 style: TextStyle(color: Colors.red),
 ),
 ),
 ],
 ),
 ) ??
 false;

 if (!confirmed) return;

 try {
 await ProcurementService.deleteItem(item.projectId, item.id);
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Contracting scope item deleted.')),
 );
 }
 } catch (e) {
 debugPrint('Error deleting item: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting item: $e')),
 );
 }
 }
 }

 List<String> _splitContractorTokens(String raw) {
 if (raw.trim().isEmpty) return const <String>[];
 final normalized = raw
 .replaceAll('\n', ',')
 .replaceAll(';', ',')
 .replaceAll('|', ',')
 .replaceAll(' / ', ',')
 .replaceAll('/', ',');
 final ignored = <String>{
 'tbd',
 'to be determined',
 'n/a',
 'na',
 'unknown',
 'unassigned',
 };
 return normalized
 .split(',')
 .map((entry) => entry.trim())
 .where((entry) => entry.isNotEmpty)
 .where((entry) => !ignored.contains(entry.toLowerCase()))
 .toList();
 }

 List<String> _contractorsForScope(ProcurementItemModel item) {
 return _splitContractorTokens(item.notes);
 }

 Future<void> _assignContractorToScopes({
 required String contractorName,
 required List<ProcurementItemModel> scopes,
 }) async {
 final trimmed = contractorName.trim();
 if (trimmed.isEmpty || scopes.isEmpty) return;

 for (final scope in scopes) {
 final existing = _contractorsForScope(scope);
 if (existing.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
 continue;
 }
 final next = [...existing, trimmed].join(', ');
 await ProcurementService.updateItem(scope.projectId, scope.id, {
 'notes': next,
 });
 }
 }

 Future<void> _promptAssignContractorToScopes({
 required String contractorName,
 required List<ProcurementItemModel> scopes,
 }) async {
 var selectedContractor = contractorName.trim();
 if (scopes.isEmpty) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No contract scopes yet. Add a scope first.'),
 ),
 );
 return;
 }

 if (selectedContractor.isEmpty) {
 final vendors = await (_contractorsStream?.first.timeout(
 const Duration(seconds: 6),
 onTimeout: () => const <VendorModel>[],
 ) ??
 Future.value(const <VendorModel>[]));
 final candidates = _collectApprovedContractors(const [], scopes, vendors);
 final controller = TextEditingController();
 if (!mounted) return;
 final picked = await showDialog<String>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Select Contractor'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<String>(
 value:
 candidates.isNotEmpty ? candidates.first : null,
 items: candidates
 .map((name) => DropdownMenuItem<String>(
 value: name,
 child: Text(name),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 controller.text = value;
 },
 decoration: const InputDecoration(
 labelText: 'Approved Contractors',
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: controller,
 decoration: const InputDecoration(
 labelText: 'Or enter contractor name',
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () =>
 Navigator.pop(dialogContext, controller.text.trim()),
 child: const Text('Continue'),
 ),
 ],
 ),
 ) ??
 '';
 controller.dispose();
 selectedContractor = picked.trim();
 }

 if (selectedContractor.isEmpty) return;

 final selected = <String>{};
 if (!mounted) return;
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: const Text('Assign Contractor to Scope'),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 'Select the scopes that should include "$selectedContractor".',
 style: const TextStyle(fontSize: 12.5),
 ),
 const SizedBox(height: 10),
 for (final scope in scopes)
 CheckboxListTile(
 value: selected.contains(scope.id),
 dense: true,
 onChanged: (value) {
 setState(() {
 if (value == true) {
 selected.add(scope.id);
 } else {
 selected.remove(scope.id);
 }
 });
 },
 title: Text(
 scope.name.trim().isEmpty
 ? 'Untitled Scope'
 : scope.name.trim(),
 ),
 subtitle: Text(
 scope.description.trim().isEmpty
 ? 'No description'
 : scope.description.trim(),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: selected.isEmpty
 ? null
 : () => Navigator.pop(dialogContext, true),
 child: const Text('Assign'),
 ),
 ],
 ),
 ),
 ) ??
 false;

 if (!confirmed || selected.isEmpty) return;
 final targets =
 scopes.where((scope) => selected.contains(scope.id)).toList();
 await _assignContractorToScopes(
 contractorName: selectedContractor,
 scopes: targets,
 );

 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Assigned "$selectedContractor" to ${targets.length} scope(s).'),
 ),
 );
 }

 String _templateKeyForScope(String scopeId) =>
 'contracting_template_$scopeId';

 String _trackingKeyForScope(String scopeId) =>
 'contracting_tracking_$scopeId';

 String _trackingUpdatedKeyForScope(String scopeId) =>
 'contracting_tracking_updated_$scopeId';

 String _trackingStatusForScope(
 String scopeId,
 Map<String, dynamic> notes,
 ) {
 return (notes[_trackingKeyForScope(scopeId)] ?? '')
 .toString()
 .trim()
 .isEmpty
 ? 'Not Started'
 : (notes[_trackingKeyForScope(scopeId)] ?? '').toString().trim();
 }

 String _trackingUpdatedLabel(
 String scopeId,
 Map<String, dynamic> notes,
 ) {
 final raw = notes[_trackingUpdatedKeyForScope(scopeId)];
 final parsed = _parseNotesDate(raw);
 if (parsed == null) return '-';
 return _formatDateTimeShort(parsed);
 }

 Future<void> _savePlanningNote(String key, String value) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 key: value.trim(),
 },
 ),
 showSnackbar: false,
 );
 }

 Future<void> _openTemplateEditor(ProcurementItemModel item) async {
 final data = ProjectDataHelper.getData(context);
 final key = _templateKeyForScope(item.id);
 final controller = TextEditingController(
 text: (data.planningNotes[key] ?? '').toString(),
 );

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(
 'Template for ${item.name.trim().isEmpty ? 'Scope' : item.name.trim()}',
 ),
 content: SizedBox(
 width: 560,
 child: VoiceTextField(
 controller: controller,
 maxLines: 8,
 decoration: const InputDecoration(
 hintText:
 'Capture scope-specific template clauses, milestones, SLAs, and deliverables.',
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 child: const Text('Save Template'),
 ),
 ],
 ),
 ) ??
 false;

 if (saved) {
 await _savePlanningNote(key, controller.text);
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Template saved.')),
 );
 }
 }
 controller.dispose();
 }

 Widget _buildTemplatesTab(List<ProcurementItemModel> items) {
 final started = items.where((item) {
 final state = _scopeManagementByScopeId[item.id];
 return state?.started == true;
 }).toList();
 if (started.isEmpty) {
 return const Text(
 'Start a scope process to generate and manage contracting templates.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 );
 }

 final notes = ProjectDataHelper.getData(context).planningNotes;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'What you should do',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 _templateGuidanceRow(
 'Confirm scope packages and key deliverables.'),
 _templateGuidanceRow(
 'Draft template clauses for SLAs, milestones, and approvals.'),
 _templateGuidanceRow(
 'Align templates with procurement and legal review.'),
 ],
 ),
 ),
 const SizedBox(height: 12),
 for (final item in started)
 Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.name.trim().isEmpty
 ? 'Untitled Scope'
 : item.name.trim(),
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700),
 ),
 ),
 const SizedBox(width: 8),
 _statusBadge(
 (notes[_templateKeyForScope(item.id)] ?? '')
 .toString()
 .trim()
 .isEmpty
 ? 'Draft Needed'
 : 'Template Ready',
 tone: (notes[_templateKeyForScope(item.id)] ?? '')
 .toString()
 .trim()
 .isEmpty
 ? const Color(0xFFF59E0B)
 : const Color(0xFF2563EB),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 (notes[_templateKeyForScope(item.id)] ?? '')
 .toString()
 .trim()
 .isEmpty
 ? 'No template yet. Create one for this scope.'
 : (notes[_templateKeyForScope(item.id)] ?? '')
 .toString()
 .trim(),
 maxLines: 3,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11.5,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton(
 onPressed: () => _openTemplateEditor(item),
 child: const Text('Edit Template'),
 ),
 ],
 ),
 ),
 ],
 );
 }

 Widget _buildTrackingTab(List<ProcurementItemModel> items) {
 final started = items.where((item) {
 final state = _scopeManagementByScopeId[item.id];
 return state?.started == true;
 }).toList();
 if (started.isEmpty) {
 return const Text(
 'Contract tracking will appear once at least one scope is started.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 );
 }

 final notes = ProjectDataHelper.getData(context).planningNotes;
 final sorted = [...started]
 ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Align(
 alignment: Alignment.centerRight,
 child: OutlinedButton.icon(
 onPressed: () => _openTrackingDialog(sorted),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Tracking Entry'),
 ),
 ),
 const SizedBox(height: 12),
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: ResponsiveDataTableWrapper(
 minWidth: 760,
 child: buildNduDataTable(
 context: context,
 columnSpacing: 24,
 horizontalMargin: 18,
 headingRowHeight: 48,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 80,
 columns: const [
 DataColumn(label: Text('Scope')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Last Updated')),
 DataColumn(label: Text('Actions')),
 ],
 rows: sorted.map((item) {
 final status = _trackingStatusForScope(item.id, notes);
 return DataRow(
 cells: [
 DataCell(
 Text(
 item.name.trim().isEmpty
 ? 'Untitled Scope'
 : item.name.trim(),
 ),
 ),
 DataCell(
 _statusBadge(
 status,
 tone: _trackingStatusTone(status),
 ),
 ),
 DataCell(
 Text(
 _trackingUpdatedLabel(item.id, notes),
 style: const TextStyle(fontSize: 12),
 ),
 ),
 DataCell(
 Row(
 children: [
 IconButton(
 onPressed: () =>
 _openTrackingDialog(sorted, initial: item),
 icon: const Icon(Icons.edit_outlined, size: 18),
 tooltip: 'Edit status',
 ),
 IconButton(
 onPressed: () => _clearTrackingStatus(item.id),
 icon: const Icon(Icons.delete_outline, size: 18),
 tooltip: 'Remove',
 ),
 ],
 ),
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

 Widget _buildReportsTab(
 List<ProcurementItemModel> items,
 List<VendorModel> contractors,
 ) {
 final startedCount = items.where((item) {
 final state = _scopeManagementByScopeId[item.id];
 return state?.started == true;
 }).length;
 final approvedCount = contractors
 .where((vendor) => vendor.status.toLowerCase() == 'approved')
 .length;
 final reports = _loadContractingReports(ProjectDataHelper.getData(context));
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Contracting Summary',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 Text(
 'Started scopes: $startedCount',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF374151)),
 ),
 const SizedBox(height: 2),
 Text(
 'Approved contractors: $approvedCount',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF374151)),
 ),
 ],
 ),
 ),
 OutlinedButton.icon(
 onPressed: () => _openReportDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Report'),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 if (reports.isEmpty)
 buildNduTableEmptyState(
 context,
 message:
 'No reports yet. Add a contracting report to track progress and approvals.',
 )
 else
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
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
 DataColumn(label: Text('Report')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Updated')),
 DataColumn(label: Text('Actions')),
 ],
 rows: reports.map((report) {
 return DataRow(
 cells: [
 DataCell(
 Text(
 report.title.trim().isEmpty
 ? 'Untitled Report'
 : report.title.trim(),
 ),
 ),
 DataCell(
 _statusBadge(
 report.status,
 tone: _reportStatusTone(report.status),
 ),
 ),
 DataCell(
 Text(
 report.owner.trim().isEmpty
 ? '-'
 : report.owner.trim(),
 ),
 ),
 DataCell(
 Text(
 _formatDateTimeShort(report.updatedAt),
 style: const TextStyle(fontSize: 12),
 ),
 ),
 DataCell(
 Row(
 children: [
 IconButton(
 onPressed: () =>
 _openReportDialog(existing: report),
 icon: const Icon(Icons.edit_outlined, size: 18),
 tooltip: 'Edit report',
 ),
 IconButton(
 onPressed: () => _removeReport(report.id),
 icon: const Icon(Icons.delete_outline, size: 18),
 tooltip: 'Remove',
 ),
 ],
 ),
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

 Widget _buildApprovedContractorsTable({
 required List<VendorModel> contractors,
 required List<ProcurementItemModel> items,
 required List<String> approvedNames,
 }) {
 final combined = <String, String>{};
 for (final name in approvedNames) {
 final trimmed = name.trim();
 if (trimmed.isEmpty) continue;
 combined.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
 }
 for (final vendor in contractors) {
 final name = vendor.name.trim();
 if (name.isEmpty) continue;
 combined.putIfAbsent(name.toLowerCase(), () => name);
 }
 final rows = combined.values.toList()
 ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

 if (rows.isEmpty) {
 return buildNduTableEmptyState(
 context,
 message:
 'No approved contractors yet. Add a contractor or assign one to a scope.',
 );
 }

 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: ResponsiveDataTableWrapper(
 minWidth: 760,
 child: buildNduDataTable(
 context: context,
 columnSpacing: 24,
 horizontalMargin: 18,
 headingRowHeight: 48,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 80,
 columns: const [
 DataColumn(label: Text('Contractor')),
 DataColumn(label: Text('Category')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Rating')),
 DataColumn(label: Text('Actions')),
 ],
 rows: rows.map((name) {
 final vendor = _vendorForName(contractors, name);
 final statusLabel = vendor == null || vendor.status.trim().isEmpty
 ? 'Untracked'
 : vendor.status.trim();
 return DataRow(
 cells: [
 DataCell(Text(name)),
 DataCell(Text(vendor?.category.trim().isEmpty ?? true
 ? '-'
 : vendor!.category.trim())),
 DataCell(
 _statusBadge(
 statusLabel,
 tone: _vendorStatusTone(statusLabel),
 ),
 ),
 DataCell(Text(vendor?.rating ?? '-')),
 DataCell(
 Row(
 children: [
 IconButton(
 onPressed: () => _promptAssignContractorToScopes(
 contractorName: name,
 scopes: items,
 ),
 icon:
 const Icon(Icons.assignment_ind_outlined, size: 18),
 tooltip: 'Assign to scope',
 ),
 if (vendor == null)
 TextButton(
 onPressed: () => _openAddContractorDialog(
 existingContractors: contractors,
 ),
 child: const Text('Add'),
 )
 else ...[
 IconButton(
 onPressed: () => _openEditContractorDialog(vendor),
 icon: const Icon(Icons.edit_outlined, size: 18),
 tooltip: 'Edit contractor',
 ),
 IconButton(
 onPressed: () => _confirmDeleteContractor(vendor),
 icon: const Icon(Icons.delete_outline, size: 18),
 tooltip: 'Remove',
 ),
 ],
 ],
 ),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 );
 }

 Widget _templateGuidanceRow(String text) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('• ',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 ),
 ],
 ),
 );
 }

 String _resolveContractingStage({
 required int contractsCount,
 required int scopeCount,
 required int startedCount,
 required int trackingCount,
 required int reportCount,
 }) {
 if (contractsCount == 0) {
 return 'Define contract packages';
 }
 if (scopeCount == 0) {
 return 'Map contracting scope';
 }
 if (startedCount == 0) {
 return 'Start scope processes';
 }
 if (trackingCount == 0) {
 return 'Set tracking status';
 }
 if (reportCount == 0) {
 return 'Publish contracting reports';
 }
 return 'Optimize contracting execution';
 }

 Widget _buildContractingOverviewCard({
 required int contractsCount,
 required int scopeCount,
 required int startedCount,
 required int trackingCount,
 required int reportCount,
 bool compact = false,
 }) {
 final stage = _resolveContractingStage(
 contractsCount: contractsCount,
 scopeCount: scopeCount,
 startedCount: startedCount,
 trackingCount: trackingCount,
 reportCount: reportCount,
 );
 final steps = [
 _overviewStepChip('Contracts', contractsCount > 0),
 _overviewStepChip('Scope', scopeCount > 0),
 _overviewStepChip('Start', startedCount > 0),
 _overviewStepChip('Tracking', trackingCount > 0),
 _overviewStepChip('Reports', reportCount > 0),
 ];

 return Container(
 width: double.infinity,
 padding: EdgeInsets.all(compact ? 12 : 16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Contracting flow',
 style: TextStyle(
 fontSize: compact ? 13 : 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Current focus: $stage',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 10),
 Wrap(spacing: 8, runSpacing: 6, children: steps),
 const SizedBox(height: 12),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _overviewMetric('Contracts', contractsCount),
 _overviewMetric('Scopes', scopeCount),
 _overviewMetric('Started', startedCount),
 _overviewMetric('Tracking', trackingCount),
 _overviewMetric('Reports', reportCount),
 ],
 ),
 ],
 ),
 );
 }

 Widget _overviewMetric(String label, int value) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 value.toString(),
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 Text(
 label,
 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
 ),
 ],
 ),
 );
 }

 Widget _overviewStepChip(String label, bool complete) {
 final tone = complete ? const Color(0xFF16A34A) : const Color(0xFFCBD5F5);
 final textColor =
 complete ? const Color(0xFF166534) : const Color(0xFF64748B);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: tone.withOpacity(0.2),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: tone.withOpacity(0.6)),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 10.5,
 fontWeight: FontWeight.w700,
 color: textColor,
 ),
 ),
 );
 }

 Widget _statusBadge(String label, {Color tone = const Color(0xFF2563EB)}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: tone.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: tone.withOpacity(0.35)),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 10.5,
 fontWeight: FontWeight.w700,
 color: tone,
 ),
 ),
 );
 }

 Color _trackingStatusTone(String status) {
 final normalized = status.toLowerCase();
 if (normalized.contains('draft')) return const Color(0xFF94A3B8);
 if (normalized.contains('sent')) return const Color(0xFF2563EB);
 if (normalized.contains('response')) return const Color(0xFF14B8A6);
 if (normalized.contains('evaluation')) return const Color(0xFFF59E0B);
 if (normalized.contains('award') || normalized.contains('signed')) {
 return const Color(0xFF16A34A);
 }
 return const Color(0xFF64748B);
 }

 Color _reportStatusTone(String status) {
 final normalized = status.toLowerCase();
 if (normalized.contains('draft')) return const Color(0xFF94A3B8);
 if (normalized.contains('review')) return const Color(0xFFF59E0B);
 if (normalized.contains('approved')) return const Color(0xFF2563EB);
 if (normalized.contains('publish')) return const Color(0xFF16A34A);
 return const Color(0xFF64748B);
 }

 Color _vendorStatusTone(String status) {
 final normalized = status.toLowerCase();
 if (normalized.contains('approved') || normalized.contains('active')) {
 return const Color(0xFF16A34A);
 }
 if (normalized.contains('denied') || normalized.contains('blocked')) {
 return const Color(0xFFDC2626);
 }
 if (normalized.contains('watch') || normalized.contains('pending')) {
 return const Color(0xFFF59E0B);
 }
 return const Color(0xFF64748B);
 }

 Future<void> _openTrackingDialog(
 List<ProcurementItemModel> scopes, {
 ProcurementItemModel? initial,
 }) async {
 if (scopes.isEmpty) return;
 final notes = ProjectDataHelper.getData(context).planningNotes;
 ProcurementItemModel selected = initial ?? scopes.first;
 var status = _trackingStatusForScope(selected.id, notes);
 if (status == 'Not Started') {
 status = _trackingStatusOptions.first;
 }

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: const Text('Update Tracking Status'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<String>(
 value: selected.id,
 decoration: const InputDecoration(labelText: 'Scope'),
 items: scopes
 .map((scope) => DropdownMenuItem<String>(
 value: scope.id,
 child: Text(scope.name.trim().isEmpty
 ? 'Untitled Scope'
 : scope.name.trim()),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 final match = scopes.firstWhere(
 (scope) => scope.id == value,
 orElse: () => scopes.first);
 setState(() {
 selected = match;
 final next = _trackingStatusForScope(match.id, notes);
 status = next == 'Not Started'
 ? _trackingStatusOptions.first
 : next;
 });
 },
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 decoration:
 const InputDecoration(labelText: 'Tracking Status'),
 items: _trackingStatusOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => status = value);
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 child: const Text('Save Status'),
 ),
 ],
 ),
 ),
 ) ??
 false;

 if (!saved) return;
 await _saveTrackingStatus(selected.id, status);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Tracking status updated.')),
 );
 }

 Future<void> _openReportDialog({
 _ContractingReportEntry? existing,
 }) async {
 final titleController = TextEditingController(text: existing?.title ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 final summaryController =
 TextEditingController(text: existing?.summary ?? '');
 var status = existing?.status ?? _reportStatusOptions.first;

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: Text(existing == null ? 'Add Report' : 'Edit Report'),
 content: SizedBox(
 width: 560,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration:
 const InputDecoration(labelText: 'Report Title'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status'),
 items: _reportStatusOptions
 .map((option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => status = value);
 },
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(labelText: 'Owner'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: summaryController,
 decoration: const InputDecoration(labelText: 'Summary'),
 maxLines: 4,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(dialogContext, true),
 child: Text(existing == null ? 'Add Report' : 'Save Changes'),
 ),
 ],
 ),
 ),
 ) ??
 false;

 if (!saved) return;
 final data = ProjectDataHelper.getData(context);
 final reports = _loadContractingReports(data);
 final entry = _ContractingReportEntry(
 id: existing?.id ?? 'report_${DateTime.now().microsecondsSinceEpoch}',
 title: titleController.text.trim(),
 status: status,
 owner: ownerController.text.trim(),
 summary: summaryController.text.trim(),
 updatedAt: DateTime.now(),
 );

 final next = [...reports];
 final index = existing == null
 ? -1
 : reports.indexWhere((report) => report.id == existing.id);
 if (index >= 0) {
 next[index] = entry;
 } else {
 next.add(entry);
 }
 await _saveContractingReports(next);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content:
 Text(existing == null ? 'Report added.' : 'Report updated.')),
 );
 }

 Future<void> _removeReport(String reportId) async {
 final data = ProjectDataHelper.getData(context);
 final reports = _loadContractingReports(data);
 final next = reports.where((report) => report.id != reportId).toList();
 await _saveContractingReports(next);
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Report removed.')),
 );
 }

 VendorModel? _vendorForName(
 List<VendorModel> contractors,
 String name,
 ) {
 final normalized = name.trim().toLowerCase();
 for (final vendor in contractors) {
 if (vendor.name.trim().toLowerCase() == normalized) return vendor;
 }
 return null;
 }

 Future<void> _setVendorStatus(VendorModel vendor, String status) async {
 try {
 await VendorService.updateVendor(
 projectId: vendor.projectId,
 vendorId: vendor.id,
 status: status,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Contractor marked as $status.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to update contractor: $e')),
 );
 }
 }

 Future<void> _openContractorActionsDialog({
 required String name,
 required VendorModel? vendor,
 required List<ProcurementItemModel> scopes,
 }) async {
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(name),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 vendor == null
 ? 'Status: Untracked (not yet in vendors list)'
 : 'Status: ${vendor.status}',
 style: const TextStyle(fontSize: 12.5),
 ),
 const SizedBox(height: 10),
 const Text(
 'Actions',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Close'),
 ),
 if (vendor != null) ...[
 TextButton(
 onPressed: () async {
 Navigator.pop(dialogContext);
 await _setVendorStatus(vendor, 'Approved');
 },
 child: const Text('Approve'),
 ),
 TextButton(
 onPressed: () async {
 Navigator.pop(dialogContext);
 await _setVendorStatus(vendor, 'Denied');
 },
 child: const Text('Deny', style: TextStyle(color: Colors.red)),
 ),
 ] else
 TextButton(
 onPressed: () async {
 Navigator.pop(dialogContext);
 await _openAddContractorDialog();
 },
 child: const Text('Add To Vendors'),
 ),
 TextButton(
 onPressed: () async {
 Navigator.pop(dialogContext);
 await _promptAssignContractorToScopes(
 contractorName: name,
 scopes: scopes,
 );
 },
 child: const Text('Assign to Scope'),
 ),
 ],
 ),
 );
 }

 List<String> _collectApprovedContractors(
 List<ContractModel> contracts,
 List<ProcurementItemModel> items,
 List<VendorModel> storedContractors,
 ) {
 final unique = <String, String>{};

 for (final contract in contracts) {
 for (final name in _splitContractorTokens(contract.contractorName)) {
 unique.putIfAbsent(name.toLowerCase(), () => name);
 }
 }

 for (final item in items) {
 for (final name in _splitContractorTokens(item.notes)) {
 unique.putIfAbsent(name.toLowerCase(), () => name);
 }
 }

 for (final contractor in storedContractors) {
 final name = contractor.name.trim();
 if (name.isEmpty) continue;
 unique.putIfAbsent(name.toLowerCase(), () => name);
 }

 final values = unique.values.toList()
 ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
 return values;
 }

 Future<void> _openApprovedContractorList() async {
 final projectId = _activeProjectIdOrNull();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Project not initialized. Cannot open approved contractor list.',
 ),
 ),
 );
 return;
 }

 try {
 final results = await Future.wait<dynamic>([
 ProcurementService.streamContracts(projectId, limit: 300).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <ContractModel>[],
 ),
 ProcurementService.streamItems(projectId, limit: 400).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <ProcurementItemModel>[],
 ),
 VendorService.streamVendors(projectId, limit: 320).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <VendorModel>[],
 ),
 ]);

 if (!mounted) return;
 final contracts = results[0] as List<ContractModel>;
 final items = results[1] as List<ProcurementItemModel>;
 final storedContractors = results[2] as List<VendorModel>;
 final contractors =
 _collectApprovedContractors(contracts, items, storedContractors);

 final vendorByName = <String, VendorModel>{};
 for (final vendor in storedContractors) {
 vendorByName[vendor.name.trim().toLowerCase()] = vendor;
 }

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: const Row(
 children: [
 Icon(Icons.fact_check_outlined, color: Color(0xFF2563EB)),
 SizedBox(width: 10),
 Text('Approved Contractor List'),
 ],
 ),
 content: SizedBox(
 width: 620,
 child: contractors.isEmpty
 ? const Text(
 'No approved contractors found yet. Add contract details or contractor candidates in scope items to populate this list.',
 style: TextStyle(height: 1.45),
 )
 : ConstrainedBox(
 constraints: const BoxConstraints(maxHeight: 420),
 child: ListView.separated(
 shrinkWrap: true,
 itemCount: contractors.length,
 separatorBuilder: (_, __) =>
 const Divider(height: 12, thickness: 0.5),
 itemBuilder: (_, index) {
 final name = contractors[index];
 final vendor =
 vendorByName[name.trim().toLowerCase()];
 final statusLabel = vendor == null
 ? 'Untracked'
 : vendor.status.trim().isEmpty
 ? 'Pending'
 : vendor.status.trim();
 return ListTile(
 dense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 0),
 leading: CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFFEFF6FF),
 child: Text(
 name.isEmpty
 ? '?'
 : name.trim()[0].toUpperCase(),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF2563EB),
 ),
 ),
 ),
 title: Text(
 name,
 style:
 const TextStyle(fontWeight: FontWeight.w600),
 ),
 subtitle: Text(
 'Status: $statusLabel',
 style: const TextStyle(fontSize: 11.5),
 ),
 trailing: vendor == null
 ? TextButton(
 onPressed: () async {
 Navigator.of(dialogContext).pop();
 await _openAddContractorDialog();
 },
 child: const Text('Add to Vendors'),
 )
 : Wrap(
 spacing: 6,
 children: [
 TextButton(
 onPressed: () async {
 await _setVendorStatus(
 vendor, 'Approved');
 },
 child: const Text('Approve'),
 ),
 TextButton(
 onPressed: () async {
 await _setVendorStatus(
 vendor, 'Denied');
 },
 child: const Text('Deny'),
 ),
 ],
 ),
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
 ),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to load contractor list: $e')),
 );
 }
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
 return chips;
 }

 Future<void> _regenerateAllContracts() async {
 final projectId = _activeProjectIdOrNull();

 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project not initialized. Cannot generate items.')),
 );
 return;
 }
 final generated = await _performGeneration(
 projectId,
 silent: false,
 seedContracts: true,
 seedItems: true,
 );
 if (!mounted) return;
 setState(() {
 _autoGenerationError = generated
 ? null
 : 'AI generation did not return new contracts. Adjust context and try again.';
 });
 }

 String _normalizeSignature(String value) =>
 value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

 String _normalizeField(dynamic value) =>
 value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

 double _safeDouble(dynamic value, {double fallback = 0}) {
 if (value is num) return value.toDouble();
 return double.tryParse(value?.toString() ?? '') ?? fallback;
 }

 String _normalizeStartStage(dynamic raw) {
 final value = _normalizeField(raw).toLowerCase();
 if (value.contains('init')) return 'Initiation';
 if (value.contains('plan')) return 'Planning';
 if (value.contains('exec')) return 'Execution';
 if (value.contains('launch') || value.contains('deploy')) return 'Launch';
 if (value.contains('oper')) return 'Operations';
 if (value.contains('unsure') || value.contains('unknown')) return 'Unsure';
 return 'Planning';
 }

 Future<void> _updateScopeItemFields(
 ProcurementItemModel item,
 Map<String, dynamic> fields, {
 String? successMessage,
 String? errorPrefix,
 }) async {
 try {
 await ProcurementService.updateItem(item.projectId, item.id, fields);
 if (!mounted || successMessage == null || successMessage.isEmpty) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(successMessage)),
 );
 } catch (e) {
 if (!mounted) return;
 final prefix = (errorPrefix == null || errorPrefix.isEmpty)
 ? 'Error updating scope item'
 : errorPrefix;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('$prefix: $e')),
 );
 }
 }

 Future<void> _savePotentialContractorsForScope(
 ProcurementItemModel item,
 List<String> contractors,
 ) async {
 final normalized = contractors
 .map((name) => name.trim())
 .where((name) => name.isNotEmpty)
 .toSet()
 .toList()
 ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
 await _updateScopeItemFields(
 item,
 {'notes': normalized.join(', ')},
 successMessage: 'Potential contractors updated.',
 errorPrefix: 'Unable to update contractors',
 );
 }

 Future<void> _setContractingStartStage(
 ProcurementItemModel item,
 String stage,
 ) async {
 await _updateScopeItemFields(
 item,
 {'projectPhase': _normalizeStartStage(stage)},
 successMessage: 'Contracting start stage updated.',
 errorPrefix: 'Unable to update start stage',
 );
 }

 Future<void> _suggestContractorsForScope(ProcurementItemModel item) async {
 final data = ProjectDataHelper.getData(context);
 final projectName =
 data.projectName.trim().isEmpty ? 'Project' : data.projectName.trim();
 final solutionTitle = data.solutionTitle.trim().isNotEmpty
 ? data.solutionTitle.trim()
 : data.solutionDescription.trim().isEmpty
 ? 'Project delivery'
 : data.solutionDescription.trim();
 final fullContext =
 ProjectDataHelper.buildFepContext(data, sectionLabel: 'Contracting');
 final contextScan = ProjectDataHelper.buildProjectContextScan(
 data,
 sectionLabel: 'Contracting',
 );

 final categories = <String>{
 if (item.category == 'Lump Sum') 'Construction Services',
 if (item.category == 'Reimbursable') 'Services',
 if (item.category == 'Unsure') 'Consulting',
 'Construction Services',
 'Services',
 'Consulting',
 }.toList();

 final existing = _splitContractorTokens(item.notes);
 final candidates = <String>{...existing};

 for (final category in categories.take(3)) {
 final suggested = await _openAi.generateVendorSuggestion(
 projectName: projectName,
 solutionTitle: solutionTitle,
 category: category,
 contextNotes: [
 'Scope: ${item.name}. ${item.description}. Contract type: ${item.category}. Start stage: ${_normalizeStartStage(item.projectPhase)}.',
 if (fullContext.isNotEmpty) fullContext,
 if (contextScan.isNotEmpty) contextScan,
 ].join('\n\n'),
 );
 final name = _normalizeField(suggested['name']);
 if (name.isNotEmpty) candidates.add(name);
 }

 await _savePotentialContractorsForScope(item, candidates.toList());
 }

 String _projectTypeFor(ProjectDataModel data) {
 if (data.overallFramework?.trim().isNotEmpty == true) {
 return data.overallFramework!.trim();
 }
 if (data.solutionTitle.trim().isNotEmpty) return data.solutionTitle.trim();
 if (data.solutionDescription.trim().isNotEmpty) {
 return data.solutionDescription.trim();
 }
 return 'General Project';
 }

 String _regionContextFor(ProjectDataModel data) {
 final parts = <String>[
 data.charterOrganizationalUnit.trim(),
 data.frontEndPlanning.infrastructure.trim(),
 data.notes.trim(),
 ].where((value) => value.isNotEmpty).toList();

 if (parts.isEmpty) return 'Project region not explicitly provided';
 final merged = parts.join(' | ');
 return merged.length > 420 ? '${merged.substring(0, 417)}...' : merged;
 }

 ContractStatus _parseContractStatus(dynamic raw) {
 final value = _normalizeField(raw).toLowerCase();
 if (value.contains('executed') || value.contains('active')) {
 return ContractStatus.executed;
 }
 if (value.contains('approved') || value.contains('award')) {
 return ContractStatus.approved;
 }
 if (value.contains('review')) return ContractStatus.under_review;
 if (value.contains('expire')) return ContractStatus.expired;
 if (value.contains('terminat')) return ContractStatus.terminated;
 return ContractStatus.draft;
 }

 ProcurementItemStatus _parseScopeStatus(dynamic raw) {
 final value = _normalizeField(raw).toLowerCase();
 if (value.contains('deliver')) return ProcurementItemStatus.delivered;
 if (value.contains('order')) return ProcurementItemStatus.ordered;
 if (value.contains('vendor') || value.contains('contractor')) {
 return ProcurementItemStatus.vendorSelection;
 }
 if (value.contains('rfq') || value.contains('quote')) {
 return ProcurementItemStatus.rfqReview;
 }
 if (value.contains('cancel')) return ProcurementItemStatus.cancelled;
 return ProcurementItemStatus.planning;
 }

 bool _hasIncompleteScopeDetails(List<ProcurementItemModel> items) {
 if (items.isEmpty) return true;
 return items.any(
 (item) =>
 item.budget <= 0 ||
 item.estimatedDelivery == null ||
 (item.vendorId ?? '').trim().isEmpty,
 );
 }

 String _generatedDurationText(Map<String, dynamic> item) {
 final duration = _normalizeField(item['estimated_duration']).isNotEmpty
 ? _normalizeField(item['estimated_duration'])
 : _normalizeField(item['comments']);
 return duration.isEmpty ? '6 weeks' : duration;
 }

 String _generatedPotentialContractors(Map<String, dynamic> item) {
 final contractors =
 _normalizeField(item['potential_contractors']).isNotEmpty
 ? _normalizeField(item['potential_contractors'])
 : _normalizeField(item['potential_vendors']);
 return contractors;
 }

 String _normalizedBiddingValue(Map<String, dynamic> item) {
 final biddingRequired = _normalizeField(item['bidding_required']).isNotEmpty
 ? _normalizeField(item['bidding_required'])
 : _normalizeField(item['responsible_member']);
 return _biddingOptions.contains(biddingRequired)
 ? biddingRequired
 : _biddingOptions.last;
 }

 DateTime _deliveryDateFromDurationText(String durationText) {
 final normalized = durationText.toLowerCase();
 final numberMatch = RegExp(r'(\d+)').firstMatch(normalized);
 final number = int.tryParse(numberMatch?.group(1) ?? '') ?? 6;

 int days;
 if (normalized.contains('day')) {
 days = number;
 } else if (normalized.contains('month')) {
 days = number * 30;
 } else {
 days = number * 7;
 }
 if (days < 7) days = 7;
 return DateTime.now().add(Duration(days: days));
 }

 List<String> _contractorNamesFromText(String raw) {
 return raw
 .replaceAll('\n', ',')
 .replaceAll(';', ',')
 .split(',')
 .map((entry) => entry.trim())
 .where((entry) => entry.isNotEmpty)
 .toList(growable: false);
 }

 Future<bool> _performGeneration(
 String projectId, {
 required bool silent,
 required bool seedContracts,
 required bool seedItems,
 bool enrichExistingItems = false,
 bool seedProcurementNotes = false,
 }) async {
 if (!seedContracts &&
 !seedItems &&
 !enrichExistingItems &&
 !seedProcurementNotes) {
 return false;
 }
 if (_generating) return false;

 setState(() => _generating = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final generated = await _openAi
 .generateContractingScopeSuggestions(
 projectName: projectData.projectName.trim().isEmpty
 ? 'Project'
 : projectData.projectName.trim(),
 solutionTitle: projectData.solutionTitle.trim().isEmpty
 ? projectData.solutionDescription.trim()
 : projectData.solutionTitle.trim(),
 projectType: _projectTypeFor(projectData),
 regionContext: _regionContextFor(projectData),
 contextNotes: [
 projectData.frontEndPlanning.contractVendorQuotes.trim(),
 projectData.frontEndPlanning.procurement.trim(),
 ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Contracting Scope',
 ),
 ].where((entry) => entry.isNotEmpty).join('\n\n'),
 contractCount: 8,
 scopeItemCount: 10,
 )
 .timeout(const Duration(seconds: 45));

 if (!mounted) return false;

 bool shouldImport = silent;
 if (!silent) {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (ctx) => _AiPreviewDialog(data: generated),
 );
 shouldImport = confirmed == true;
 }

 if (shouldImport) {
 final existingContracts = await ProcurementService.streamContracts(
 projectId,
 limit: 300,
 ).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <ContractModel>[],
 );
 final existingItems = await ProcurementService.streamItems(
 projectId,
 limit: 500,
 ).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <ProcurementItemModel>[],
 );
 final existingVendors = await VendorService.streamVendors(
 projectId,
 limit: 320,
 ).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <VendorModel>[],
 );
 final mutableVendors = <VendorModel>[...existingVendors];

 Future<String?> resolveOrCreateVendorId(String preferredName) async {
 final normalizedPreferred = preferredName.trim().toLowerCase();
 if (mutableVendors.isNotEmpty) {
 if (normalizedPreferred.isNotEmpty) {
 for (final vendor in mutableVendors) {
 final vendorName = vendor.name.trim().toLowerCase();
 if (vendorName == normalizedPreferred ||
 vendorName.contains(normalizedPreferred) ||
 normalizedPreferred.contains(vendorName)) {
 return vendor.id;
 }
 }
 }
 return mutableVendors.first.id;
 }
 if (preferredName.trim().isEmpty) return null;

 try {
 await VendorService.createVendor(
 projectId: projectId,
 name: preferredName.trim(),
 category: 'Services',
 criticality: 'Medium',
 rating: 'B',
 status: 'Pending',
 sla: '95%',
 slaPerformance: 0.9,
 leadTime: '30 Days',
 requiredDeliverables: 'Initial scope submission',
 nextReview: '',
 onTimeDelivery: 0.0,
 incidentResponse: 0.0,
 qualityScore: 0.0,
 costAdherence: 0.0,
 createdById: 'system',
 createdByEmail: 'system@nduproject.com',
 createdByName: 'System AI',
 );
 final refreshed = await VendorService.streamVendors(
 projectId,
 limit: 320,
 ).first.timeout(
 const Duration(seconds: 8),
 onTimeout: () => const <VendorModel>[],
 );
 mutableVendors
 ..clear()
 ..addAll(refreshed);
 if (mutableVendors.isEmpty) return null;
 for (final vendor in mutableVendors) {
 if (vendor.name.trim().toLowerCase() ==
 preferredName.trim().toLowerCase()) {
 return vendor.id;
 }
 }
 return mutableVendors.first.id;
 } catch (e) {
 debugPrint('Unable to auto-create vendor for contracting: $e');
 return null;
 }
 }

 final rawScopeItems =
 generated['contract_scope_items'] ?? generated['procurement_items'];
 final generatedScopeItems = <Map<String, dynamic>>[];
 if (rawScopeItems is List) {
 for (final item in rawScopeItems.take(_maxAiImportRows)) {
 if (item is Map<String, dynamic>) {
 generatedScopeItems.add(item);
 } else if (item is Map) {
 generatedScopeItems.add(Map<String, dynamic>.from(item));
 }
 }
 }

 final existingContractKeys = existingContracts
 .map((contract) =>
 '${_normalizeSignature(contract.title)}|${_normalizeSignature(contract.contractorName)}')
 .toSet();
 final existingItemKeys = existingItems
 .map((item) =>
 '${_normalizeSignature(item.name)}|${_normalizeSignature(item.category)}')
 .toSet();

 var importedContracts = 0;
 var importedItems = 0;
 var enrichedItems = 0;
 var seededProcurementNotes = false;

 if (seedContracts &&
 generated.containsKey('contracts') &&
 generated['contracts'] is List) {
 final List<dynamic> contracts =
 (generated['contracts'] as List).take(_maxAiImportRows).toList();
 for (final item in contracts) {
 if (item is Map<String, dynamic>) {
 final title = _normalizeField(item['title']);
 if (title.isEmpty) continue;
 final contractor = _normalizeField(item['contractor']).isEmpty
 ? 'To be determined'
 : _normalizeField(item['contractor']);
 final signature =
 '${_normalizeSignature(title)}|${_normalizeSignature(contractor)}';
 if (existingContractKeys.contains(signature)) continue;

 final contract = ContractModel(
 id: '',
 projectId: projectId,
 title: title,
 description: _normalizeField(item['description']),
 contractorName: contractor,
 estimatedCost: _safeDouble(item['cost']),
 duration: _normalizeField(item['duration']).isEmpty
 ? '3 Months'
 : _normalizeField(item['duration']),
 status: _parseContractStatus(item['status']),
 owner: _normalizeField(item['owner']).isEmpty
 ? 'Unassigned'
 : _normalizeField(item['owner']),
 createdAt: DateTime.now(),
 );
 await ProcurementService.createContract(contract);
 importedContracts += 1;
 existingContractKeys.add(signature);
 }
 }
 }

 if (seedItems && generatedScopeItems.isNotEmpty) {
 for (final item in generatedScopeItems) {
 final name = _normalizeField(item['name']);
 if (name.isEmpty) continue;
 final normalizedType =
 _normalizeField(item['contract_type']).isNotEmpty
 ? _normalizeField(item['contract_type'])
 : _normalizeField(item['category']);
 final category = _contractTypeOptions.contains(normalizedType)
 ? normalizedType
 : _contractTypeOptions.last;
 final signature =
 '${_normalizeSignature(name)}|${_normalizeSignature(category)}';
 if (existingItemKeys.contains(signature)) continue;

 final durationText = _generatedDurationText(item);
 final contractorsText = _generatedPotentialContractors(item);
 final contractorCandidates =
 _contractorNamesFromText(contractorsText);
 final preferredVendorName = contractorCandidates.isNotEmpty
 ? contractorCandidates.first
 : '';
 final vendorId = await resolveOrCreateVendorId(preferredVendorName);

 final newItem = ProcurementItemModel(
 id: '',
 projectId: projectId,
 name: name,
 description: _normalizeField(item['description']).isEmpty
 ? category
 : _normalizeField(item['description']),
 category: category,
 budget: _safeDouble(
 item['estimated_value'] ?? item['budget'],
 fallback: 50000,
 ),
 estimatedDelivery: _deliveryDateFromDurationText(durationText),
 vendorId: vendorId,
 notes: contractorsText,
 status: _parseScopeStatus(item['status']),
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 projectPhase: _normalizeStartStage(
 _normalizeField(item['contracting_start_stage']).isNotEmpty
 ? item['contracting_start_stage']
 : item['project_phase'],
 ),
 responsibleMember: _normalizedBiddingValue(item),
 comments: durationText,
 );
 await ProcurementService.createItem(newItem);
 importedItems += 1;
 existingItemKeys.add(signature);
 }
 }

 if (enrichExistingItems &&
 existingItems.isNotEmpty &&
 generatedScopeItems.isNotEmpty) {
 for (var index = 0; index < existingItems.length; index++) {
 final currentItem = existingItems[index];
 final currentSignature =
 '${_normalizeSignature(currentItem.name)}|${_normalizeSignature(currentItem.category)}';

 Map<String, dynamic>? source;
 for (final candidate in generatedScopeItems) {
 final candidateName = _normalizeField(candidate['name']);
 final candidateType =
 _normalizeField(candidate['contract_type']).isNotEmpty
 ? _normalizeField(candidate['contract_type'])
 : _normalizeField(candidate['category']);
 final candidateCategory =
 _contractTypeOptions.contains(candidateType)
 ? candidateType
 : _contractTypeOptions.last;
 final candidateSignature =
 '${_normalizeSignature(candidateName)}|${_normalizeSignature(candidateCategory)}';
 if (candidateSignature == currentSignature) {
 source = candidate;
 break;
 }
 }
 source ??= generatedScopeItems[index % generatedScopeItems.length];

 final updates = <String, dynamic>{};
 if (currentItem.budget <= 0) {
 updates['budget'] = _safeDouble(
 source['estimated_value'] ?? source['budget'],
 fallback: 50000,
 );
 }
 if (currentItem.estimatedDelivery == null) {
 updates['estimatedDelivery'] = _deliveryDateFromDurationText(
 _generatedDurationText(source),
 );
 }
 if ((currentItem.vendorId ?? '').trim().isEmpty) {
 final contractorsText = _generatedPotentialContractors(source);
 final contractorNames = _contractorNamesFromText(contractorsText);
 final preferredVendor = contractorNames.isNotEmpty
 ? contractorNames.first
 : currentItem.name.trim();
 final vendorId = await resolveOrCreateVendorId(preferredVendor);
 if ((vendorId ?? '').trim().isNotEmpty) {
 updates['vendorId'] = vendorId;
 }
 if (currentItem.notes.trim().isEmpty &&
 contractorsText.trim().isNotEmpty) {
 updates['notes'] = contractorsText.trim();
 }
 }
 if (currentItem.comments.trim().isEmpty) {
 updates['comments'] = _generatedDurationText(source);
 }
 if (currentItem.responsibleMember.trim().isEmpty) {
 updates['responsibleMember'] = _normalizedBiddingValue(source);
 }
 if (currentItem.projectPhase.trim().isEmpty) {
 updates['projectPhase'] = _normalizeStartStage(
 _normalizeField(source['contracting_start_stage']).isNotEmpty
 ? source['contracting_start_stage']
 : source['project_phase'],
 );
 }
 if (updates.isEmpty) continue;
 await ProcurementService.updateItem(
 projectId, currentItem.id, updates);
 enrichedItems += 1;
 }
 }

 if (seedProcurementNotes &&
 projectData.frontEndPlanning.procurement.trim().isEmpty) {
 final aiSummary = _normalizeField(generated['summary']);
 final fallbackNotes = generatedScopeItems.isEmpty
 ? 'Auto-generated contracting details have been prepared. Review scope, vendor readiness, and delivery windows before continuing.'
 : 'Auto-generated contracting details prepared for ${generatedScopeItems.length} scope items. Review vendor assignments and delivery commitments before continuing.';
 final nextProcurementNotes =
 aiSummary.isNotEmpty ? aiSummary : fallbackNotes;
 if (!mounted) return false;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 procurement: nextProcurementNotes,
 ),
 ),
 );
 await provider.saveToFirebase(
 checkpoint: 'fep_contract_vendor_quotes');
 seededProcurementNotes = true;
 }

 if (mounted && !silent) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Contracting AI added $importedContracts contracts, $importedItems scope items, and updated $enrichedItems existing scope records.',
 ),
 ),
 );
 }
 return importedContracts > 0 ||
 importedItems > 0 ||
 enrichedItems > 0 ||
 seededProcurementNotes;
 }
 return false;
 } catch (e) {
 debugPrint('Error regenerating contracts: $e');
 if (mounted && !silent) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error generating items: $e')),
 );
 }
 return false;
 } finally {
 if (mounted) setState(() => _generating = false);
 }
 }

 @override
 void dispose() {
 if (_isNotesSyncReady) {
 _notesController.removeListener(_syncContractNotes);
 }
 _notesController.dispose();
 super.dispose();
 }

 void _syncContractNotes() {
 if (!mounted || !_isNotesSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 final nextNotes = _notesController.text.trim();
 final currentNotes =
 provider.projectData.frontEndPlanning.contractVendorQuotes.trim();
 if (nextNotes == currentNotes) return;

 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contractVendorQuotes: nextNotes,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_contract_vendor_quotes');
 }

 void _prefillContractingNotesIfMissing(ProjectDataModel data) {
 final projectId = data.projectId?.trim() ?? '';
 if (projectId.isEmpty) return;
 if (_prefilledNotesProjectId == projectId) return;
 _prefilledNotesProjectId = projectId;

 final storedNotes =
 (data.planningNotes[_contractingNotesKey] ?? '').toString().trim();
 final fepNotes = data.frontEndPlanning.contractVendorQuotes.trim();
 if (storedNotes.isNotEmpty || fepNotes.isNotEmpty) return;

 final seed = _buildContractingNotesSeed(data).trim();
 if (seed.isEmpty) return;

 _notesController.text = seed;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractingNotesKey: seed,
 },
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contractVendorQuotes: seed,
 ),
 ),
 );
 ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractingNotesKey: seed,
 },
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contractVendorQuotes: seed,
 ),
 ),
 showSnackbar: false,
 );
 }

 Future<void> _saveTrackingStatus(String scopeId, String status) async {
 final timestamp = DateTime.now().toIso8601String();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _trackingKeyForScope(scopeId): status.trim(),
 _trackingUpdatedKeyForScope(scopeId): timestamp,
 },
 ),
 showSnackbar: false,
 );
 }

 Future<void> _clearTrackingStatus(String scopeId) async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _trackingKeyForScope(scopeId): '',
 _trackingUpdatedKeyForScope(scopeId): '',
 },
 ),
 showSnackbar: false,
 );
 }

 List<_ContractingReportEntry> _loadContractingReports(ProjectDataModel data) {
 final raw = data.planningNotes[_contractingReportsKey];
 dynamic decoded;
 if (raw is String) {
 final trimmed = raw.trim();
 if (trimmed.isNotEmpty) {
 try {
 decoded = jsonDecode(trimmed);
 } catch (e) {
 decoded = null;
 }
 }
 } else if (raw is List) {
 decoded = raw;
 }
 if (decoded is! List) return const <_ContractingReportEntry>[];
 return decoded
 .whereType<Map>()
 .map((entry) =>
 _ContractingReportEntry.fromMap(Map<String, dynamic>.from(entry)))
 .toList();
 }

 Future<void> _saveContractingReports(
 List<_ContractingReportEntry> reports) async {
 final payload = jsonEncode(
 reports.map((entry) => entry.toMap()).toList(),
 );
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 _contractingReportsKey: payload,
 },
 ),
 showSnackbar: false,
 );
 }

 String _buildContractingNotesSeed(ProjectDataModel data) {
 final lines = <String>[];
 final projectName = data.projectName.trim();
 final solutionTitle = data.solutionTitle.trim();
 final businessCase = data.businessCase.trim();
 final sponsor = data.charterProjectSponsorName.trim();
 final pm = data.charterProjectManagerName.trim();
 final withinScope = data.withinScopeItems
 .map((e) => e.description.trim())
 .where((e) => e.isNotEmpty)
 .toList();
 final outOfScope = data.outOfScopeItems
 .map((e) => e.description.trim())
 .where((e) => e.isNotEmpty)
 .toList();
 final milestones = data.keyMilestones
 .where((m) => m.name.trim().isNotEmpty || m.dueDate.trim().isNotEmpty)
 .toList();

 if (projectName.isNotEmpty || solutionTitle.isNotEmpty) {
 final title = projectName.isNotEmpty ? projectName : solutionTitle;
 final subtitle = projectName.isNotEmpty ? solutionTitle : '';
 lines.add(
 'Project: $title${subtitle.isNotEmpty ? ' — $subtitle' : ''}',
 );
 }
 if (sponsor.isNotEmpty || pm.isNotEmpty) {
 final parts = <String>[];
 if (sponsor.isNotEmpty) parts.add('Sponsor: $sponsor');
 if (pm.isNotEmpty) parts.add('PM: $pm');
 lines.add('Key stakeholders: ${parts.join(' | ')}');
 }
 if (businessCase.isNotEmpty) {
 lines.add('Business context: $businessCase');
 }
 if (withinScope.isNotEmpty) {
 lines.add('Scope highlights:');
 for (final item in withinScope.take(5)) {
 lines.add('- $item');
 }
 }
 if (outOfScope.isNotEmpty) {
 lines.add('Out of scope:');
 for (final item in outOfScope.take(3)) {
 lines.add('- $item');
 }
 }
 if (milestones.isNotEmpty) {
 lines.add('Key dates:');
 for (final milestone in milestones.take(4)) {
 final name = milestone.name.trim().isNotEmpty
 ? milestone.name.trim()
 : 'Milestone';
 final due = milestone.dueDate.trim();
 lines.add(due.isNotEmpty ? '- $name ($due)' : '- $name');
 }
 }

 return lines.join('\n');
 }

 String _resolveContractingNotesFallback(ProjectDataModel data) {
 final stored =
 (data.planningNotes[_contractingNotesKey] ?? '').toString().trim();
 if (stored.isNotEmpty) return stored;
 final fepNotes = data.frontEndPlanning.contractVendorQuotes.trim();
 if (fepNotes.isNotEmpty) return fepNotes;
 return _buildContractingNotesSeed(data);
 }

 void _handleContractingNotesChanged(String value) {
 if (_notesController.text != value) {
 _notesController.value = TextEditingValue(
 text: value,
 selection: TextSelection.collapsed(offset: value.length),
 );
 }
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contractVendorQuotes: value.trim(),
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_contract_vendor_quotes');
 }

 Future<void> _navigateToProcurement() async {
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'fep_contract_vendor_quotes',
 saveInBackground: true,
 nextScreenBuilder: () => const FrontEndPlanningProcurementScreen(),
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 contractVendorQuotes: data.frontEndPlanning.contractVendorQuotes,
 ),
 ),
 );
 }

 void _goToPreviousSection() {
 FrontEndPlanningNavigation.goToPrevious(
 context,
 'fep_contract_vendor_quotes',
 );
 }

 Widget _buildMobileScaffold(BuildContext context) {
 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: Drawer(
 width: MediaQuery.sizeOf(context).width * 0.88,
 child: const SafeArea(
 child: InitiationLikeSidebar(activeItemLabel: 'Contracting'),
 ),
 ),
 body: SafeArea(
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
 child: Row(
 children: [
 IconButton(
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu_rounded, size: 18),
 visualDensity: VisualDensity.compact,
 ),
 const Expanded(
 child: Text(
 'Contracting',
 style: TextStyle(
 fontSize: 17,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 ),
 const CircleAvatar(
 radius: 13,
 backgroundColor: Color(0xFF2563EB),
 child: Text('Ch',
 style: TextStyle(
 color: Colors.white,
 fontSize: 9,
 fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 ),
 Expanded(
 child: StreamBuilder<List<ContractModel>>(
 stream: _contractsStream,
 builder: (context, contractSnapshot) {
 if (contractSnapshot.hasError) {
 return _buildErrorState(context, contractSnapshot.error!);
 }
 if (contractSnapshot.connectionState ==
 ConnectionState.waiting &&
 !contractSnapshot.hasData) {
 return const Center(child: CircularProgressIndicator());
 }
 final contracts =
 contractSnapshot.data ?? const <ContractModel>[];
 return StreamBuilder<List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, itemSnapshot) {
 if (itemSnapshot.hasError) {
 return _buildErrorState(context, itemSnapshot.error!);
 }
 if (itemSnapshot.connectionState ==
 ConnectionState.waiting &&
 !itemSnapshot.hasData) {
 return const Center(child: CircularProgressIndicator());
 }
 final items =
 itemSnapshot.data ?? const <ProcurementItemModel>[];
 final summary =
 _buildMobileContractSummary(contracts, items);

 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(12, 2, 12, 120),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'FRONT END PLANNING',
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Notes',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Contracting',
 noteKey: _contractingNotesKey,
 checkpoint: 'fep_contract_vendor_quotes',
 onChanged: _handleContractingNotesChanged,
 fallbackText: _resolveContractingNotesFallback(
 ProjectDataHelper.getData(context),
 ),
 description:
 'Capture contracting priorities, package boundaries, and approval constraints.',
 ),
 const SizedBox(height: 12),
 StreamBuilder<List<ContractModel>>(
 stream: _contractsStream,
 builder: (context, contractSnapshot) {
 final contracts = contractSnapshot.data ??
 const <ContractModel>[];
 return StreamBuilder<
 List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, itemSnapshot) {
 final items = itemSnapshot.data ??
 const <ProcurementItemModel>[];
 final notes =
 ProjectDataHelper.getData(context)
 .planningNotes;
 final startedCount = items
 .where(
 (item) =>
 _scopeManagementByScopeId[item.id]
 ?.started ==
 true,
 )
 .length;
 final trackingCount = items
 .where(
 (item) =>
 _trackingStatusForScope(
 item.id,
 notes,
 ) !=
 'Not Started',
 )
 .length;
 final reportCount = _loadContractingReports(
 ProjectDataHelper.getData(context))
 .length;
 return _buildContractingOverviewCard(
 contractsCount: contracts.length,
 scopeCount: items.length,
 startedCount: startedCount,
 trackingCount: trackingCount,
 reportCount: reportCount,
 compact: true,
 );
 },
 );
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 const Expanded(
 child: Text(
 'Contracting Scope',
 style: TextStyle(
 fontSize: 22,
 height: 1.05,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 ),
 IconButton(
 onPressed: _generating
 ? null
 : _regenerateAllContracts,
 icon: _generating
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2),
 )
 : const Icon(Icons.refresh_rounded,
 color: Color(0xFF2563EB)),
 ),
 ],
 ),
 const Text(
 _contractingScopeSubtitle,
 style: TextStyle(
 fontSize: 11,
 color: Color(0xFF6B7280),
 height: 1.35),
 ),
 const SizedBox(height: 8),
 Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: _openApprovedContractorList,
 icon: const Icon(
 Icons.fact_check_outlined,
 size: 15,
 ),
 label: const Text('Approved Contractor List'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF1E3A8A),
 side: const BorderSide(
 color: Color(0xFFBFDBFE)),
 backgroundColor: const Color(0xFFEFF6FF),
 ),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding:
 const EdgeInsets.fromLTRB(12, 12, 12, 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border:
 Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 summary,
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF374151),
 height: 1.42,
 ),
 ),
 ),
 const SizedBox(height: 14),
 Text(
 'Missing contracting records can auto-generate on load. You can regenerate anytime.',
 style: TextStyle(
 fontSize: 11,
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 10),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(12),
 border:
 Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: const Row(
 children: [
 Icon(Icons.auto_awesome,
 size: 16, color: Color(0xFF2563EB)),
 SizedBox(width: 8),
 Expanded(
 child: Text(
 'AI suggests contract scope, package strategy, and contractor fit based on your project type and region.',
 style: TextStyle(
 fontSize: 11.5,
 color: Color(0xFF1F2937),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 const Text(
 'Contracting Workflow',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Edit bidding cycle stages and durations. Apply globally or customize by scope.',
 style: TextStyle(
 fontSize: 11.5,
 color: Color(0xFF6B7280),
 height: 1.35,
 ),
 ),
 const SizedBox(height: 10),
 _buildContractingWorkflowSection(items),
 const SizedBox(height: 20),
 const Text(
 'Contract Scope Management',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Start scope processes with role-based access and unlock downstream contracting views.',
 style: TextStyle(
 fontSize: 11.5,
 color: Color(0xFF6B7280),
 height: 1.35,
 ),
 ),
 const SizedBox(height: 10),
 StreamBuilder<List<VendorModel>>(
 stream: _contractorsStream,
 builder: (context, contractorSnapshot) {
 if (contractorSnapshot.hasError) {
 return _buildErrorState(
 context, contractorSnapshot.error!);
 }
 final contractors = contractorSnapshot.data ??
 const <VendorModel>[];
 return _buildContractScopeManagementSection(
 items,
 contractors,
 );
 },
 ),
 ],
 ),
 );
 },
 );
 },
 ),
 ),
 ],
 ),
 ),
 bottomNavigationBar: SafeArea(
 top: false,
 child: Padding(
 padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
 child: Row(
 children: [
 Expanded(
 child: TextButton(
 onPressed: _goToPreviousSection,
 child: const Text(
 'Back',
 style: TextStyle(
 fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: ElevatedButton(
 onPressed: _navigateToProcurement,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.black,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 13),
 ),
 child: const Text(
 'Next',
 style: TextStyle(fontWeight: FontWeight.w800),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 String _buildMobileContractSummary(
 List<ContractModel> contracts, List<ProcurementItemModel> items) {
 final contractLines = contracts
 .where((contract) => contract.title.trim().isNotEmpty)
 .take(4)
 .map((contract) =>
 '- ${contract.title.trim()}: ${contract.description.trim().isEmpty ? 'Coordinate contractor scope, pricing, and execution terms.' : contract.description.trim()}')
 .toList();

 final itemLines = items
 .where((item) => item.name.trim().isNotEmpty)
 .take(3)
 .map((item) =>
 '- ${item.name.trim()} (${item.category.trim().isEmpty ? 'General' : item.category.trim()})')
 .toList();

 final combined = <String>[
 if (contractLines.isNotEmpty) ...contractLines,
 if (itemLines.isNotEmpty) ...itemLines,
 ];
 if (combined.isNotEmpty) {
 return combined.join('\n\n');
 }

 return 'For the successful establishment of this project, secure contractors and contracts that align with scope and milestones.\n\n'
 '- Define contract packages that match project type and execution sequence.\n\n'
 '- Prioritize early contracting for long-lead or schedule-critical work.\n\n'
 '- Validate compliance, local constraints, and delivery capability before award.\n\n'
 '- Negotiate terms to reduce budget exposure and schedule risk.';
 }

 Widget _buildErrorState(BuildContext context, Object error) {
 debugPrint('Contracting stream error: $error');
 return Center(
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFEE2E2)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.cloud_off_outlined,
 size: 48, color: Color(0xFFEF4444)),
 const SizedBox(height: 16),
 const Text(
 'Unable to load contracting data',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: Color(0xFFB91C1C),
 fontSize: 16),
 ),
 const SizedBox(height: 8),
 const Text(
 'Please refresh the page or contact support if the issue persists.',
 textAlign: TextAlign.center,
 style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
 ),
 ],
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 if (isMobile) {
 return _buildMobileScaffold(context);
 }

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: null,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SafeArea(
 top: true,
 child: Stack(
 children: [
 Row(
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Contracting'),
 ),
 Expanded(
 child: Column(
 children: [
 FrontEndPlanningHeader(
 title: 'Contracting',
 scaffoldKey: _scaffoldKey, onExportPdf: _exportPdf),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Contracting',
 ),
 ),
 const AdminEditToggle(),
 SingleChildScrollView(
 padding: const EdgeInsets.symmetric(
 horizontal: 32, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ContractingTopBar(
 onBack: _goToPreviousSection,
 onForward: _navigateToProcurement,
 ),
 const SizedBox(height: 24),
 PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Contracting',
 noteKey: _contractingNotesKey,
 checkpoint: 'fep_contract_vendor_quotes',
 onChanged: _handleContractingNotesChanged,
 fallbackText:
 _resolveContractingNotesFallback(
 ProjectDataHelper.getData(context),
 ),
 description:
 'Capture contracting priorities, package boundaries, and approval constraints.',
 ),
 const SizedBox(height: 16),
 Align(
 alignment: Alignment.centerRight,
 child: Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 OutlinedButton.icon(
 onPressed:
 _openApprovedContractorList,
 icon: const Icon(
 Icons.fact_check_outlined,
 size: 16,
 ),
 label: const Text(
 'Approved Contractor List',
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor:
 const Color(0xFF1E3A8A),
 side: const BorderSide(
 color: Color(0xFFBFDBFE)),
 backgroundColor:
 const Color(0xFFEFF6FF),
 padding: const EdgeInsets.symmetric(
 horizontal: 14,
 vertical: 10,
 ),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(10),
 ),
 ),
 ),
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed =
 await showRegenerateAllConfirmation(
 context);
 if (confirmed && mounted) {
 await _regenerateAllContracts();
 }
 },
 isLoading: _generating,
 tooltip:
 'Generate contracts and contractors',
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 StreamBuilder<List<ContractModel>>(
 stream: _contractsStream,
 builder: (context, contractSnapshot) {
 final contracts = contractSnapshot.data ??
 const <ContractModel>[];
 return StreamBuilder<
 List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, itemSnapshot) {
 final items = itemSnapshot.data ??
 const <ProcurementItemModel>[];
 final notes =
 ProjectDataHelper.getData(context)
 .planningNotes;
 final startedCount = items
 .where(
 (item) =>
 _scopeManagementByScopeId[
 item.id]
 ?.started ==
 true,
 )
 .length;
 final trackingCount = items
 .where(
 (item) =>
 _trackingStatusForScope(
 item.id,
 notes,
 ) !=
 'Not Started',
 )
 .length;
 final reportCount =
 _loadContractingReports(
 ProjectDataHelper.getData(
 context))
 .length;
 return _buildContractingOverviewCard(
 contractsCount: contracts.length,
 scopeCount: items.length,
 startedCount: startedCount,
 trackingCount: trackingCount,
 reportCount: reportCount,
 );
 },
 );
 },
 ),
 const SizedBox(height: 32),

 // Contracts Section
 _SectionHeader(
 title: 'Contracts',
 subtitle:
 'Define contract packages, owners, and delivery responsibilities aligned to execution milestones.',
 actionLabel: 'Add Contract',
 onAction: _openAddContractDialog,
 ),
 const SizedBox(height: 12),
 StreamBuilder<List<ContractModel>>(
 stream: _contractsStream,
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return _buildErrorState(
 context, snapshot.error!);
 }
 if (_showAutoGenerationSpinner &&
 !(snapshot.hasData &&
 snapshot.data!.isNotEmpty)) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 40,
 ),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius:
 BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE5E7EB)),
 ),
 child: const Column(
 children: [
 CircularProgressIndicator(),
 SizedBox(height: 12),
 Text(
 'Generating initial contracts and contracting details...',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF64748B),
 ),
 ),
 ],
 ),
 );
 }
 if (!snapshot.hasData) {
 return const Center(
 child: CircularProgressIndicator());
 }
 final contracts = snapshot.data!;
 if (_autoGenerationError != null &&
 contracts.isEmpty) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(
 horizontal: 18,
 vertical: 24,
 ),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius:
 BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Text(
 _autoGenerationError!,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: Color(0xFFB91C1C),
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 10),
 OutlinedButton.icon(
 onPressed: _generating
 ? null
 : _regenerateAllContracts,
 icon: const Icon(
 Icons.auto_awesome_rounded,
 size: 16),
 label: const Text(
 'Generate with AI'),
 ),
 ],
 ),
 );
 }
 return Column(
 crossAxisAlignment:
 CrossAxisAlignment.stretch,
 children: [
 ContractsTable(
 contracts: contracts,
 onEdit: _openEditContractDialog,
 onDelete: _deleteContract,
 ),
 if (contracts.length >=
 _contractQueryLimit)
 Align(
 alignment: Alignment.centerRight,
 child: TextButton.icon(
 onPressed: _loadMoreContracts,
 icon: const Icon(
 Icons.unfold_more_rounded,
 size: 16,
 ),
 label: Text(
 'Load ${_loadMoreStep.toString()} more contracts',
 ),
 ),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 48),

 // Contracting Scope Section
 _ScopeSectionModeSwitcher(
 showDetails: _showScopeDetails,
 onChanged: (showDetails) {
 if (_showScopeDetails == showDetails) {
 return;
 }
 setState(() =>
 _showScopeDetails = showDetails);
 },
 ),
 const SizedBox(height: 14),
 _SectionHeader(
 title: _showScopeDetails
 ? 'Contract Details'
 : 'Contracting Scope',
 subtitle: _showScopeDetails
 ? 'Card-based scope details sourced from the Contracting Scope table, including contractors and the stage where contracting should begin.'
 : _contractingScopeSubtitle,
 actionLabel: 'Add Scope',
 onAction: _openAddItemDialog,
 ),
 const SizedBox(height: 12),
 StreamBuilder<List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return _buildErrorState(
 context, snapshot.error!);
 }
 if (snapshot.connectionState ==
 ConnectionState.waiting) {
 return const Center(
 child: CircularProgressIndicator());
 }
 final items = snapshot.data ??
 const <ProcurementItemModel>[];
 return Column(
 crossAxisAlignment:
 CrossAxisAlignment.stretch,
 children: [
 _showScopeDetails
 ? _ContractScopeDetailsBoard(
 items: items,
 stageOptions:
 _startStageOptions,
 onEdit: _openEditItemDialog,
 onDelete: _deleteItem,
 onStageChanged:
 _setContractingStartStage,
 onSavePotentialContractors:
 _savePotentialContractorsForScope,
 onSuggestContractors:
 _suggestContractorsForScope,
 onOpenApprovedContractorList:
 _openApprovedContractorList,
 )
 : _ContractingScopeTable(
 items: items,
 onEdit: _openEditItemDialog,
 onDelete: _deleteItem,
 ),
 if (items.length >= _itemQueryLimit)
 Align(
 alignment: Alignment.centerRight,
 child: TextButton.icon(
 onPressed: _loadMoreItems,
 icon: const Icon(
 Icons.unfold_more_rounded,
 size: 16,
 ),
 label: Text(
 'Load ${_loadMoreStep.toString()} more scope items',
 ),
 ),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 32),
 _SectionHeader(
 title: 'Contracting Workflow',
 subtitle:
 'Use editable bidding cycle stages with preset durations. Apply one cycle to all scopes or customize it per contract scope.',
 actionLabel: 'Reset Preset',
 onAction: () async {
 final items = await (_itemsStream?.first
 .timeout(
 const Duration(seconds: 6),
 onTimeout: () =>
 const <ProcurementItemModel>[],
 ) ??
 Future.value(
 const <ProcurementItemModel>[]));
 if (!mounted) return;
 _resetWorkflowDraftToPreset(items);
 },
 ),
 const SizedBox(height: 12),
 StreamBuilder<List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return _buildErrorState(
 context, snapshot.error!);
 }
 final items = snapshot.data ??
 const <ProcurementItemModel>[];
 return _buildContractingWorkflowSection(
 items);
 },
 ),
 const SizedBox(height: 32),
 _SectionHeader(
 title: 'Contract Scope Management',
 subtitle:
 'Commence scope processes with role-based authority. Contracting Templates, Contract Tracking, and Reports remain locked until a scope process starts.',
 actionLabel: 'Approved Contractors',
 onAction: _openApprovedContractorList,
 ),
 const SizedBox(height: 12),
 StreamBuilder<List<ProcurementItemModel>>(
 stream: _itemsStream,
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return _buildErrorState(
 context, snapshot.error!);
 }
 final items = snapshot.data ??
 const <ProcurementItemModel>[];
 return StreamBuilder<List<VendorModel>>(
 stream: _contractorsStream,
 builder: (context, contractorSnapshot) {
 if (contractorSnapshot.hasError) {
 return _buildErrorState(context,
 contractorSnapshot.error!);
 }
 final contractors =
 contractorSnapshot.data ??
 const <VendorModel>[];
 return _buildContractScopeManagementSection(
 items,
 contractors,
 );
 },
 );
 },
 ),

 // Actions Footer
 const SizedBox(height: 40),
 const SizedBox(height: 120), // Bottom padding
 ],
 ),
 ),
 ],
 ),
 ),
 _BottomOverlay(onNext: _navigateToProcurement),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }
}

class _ContractingTopBar extends StatelessWidget {
 const _ContractingTopBar({required this.onBack, required this.onForward});

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
 const Spacer(),
 const _ContractingUserBadge(),
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

class _ContractingUserBadge extends StatelessWidget {
 const _ContractingUserBadge();

 @override
 Widget build(BuildContext context) {
 final projectName = ProjectDataHelper.getData(context).projectName.trim();
 final displayName = projectName.isEmpty ? 'Contracting Team' : projectName;
 final roleLabel = projectName.isEmpty ? 'Contracting' : 'Contracting Plan';

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

class _BottomOverlay extends StatelessWidget {
 const _BottomOverlay({required this.onNext});

 final VoidCallback onNext;

 @override
 Widget build(BuildContext context) {
 return SafeArea(
 top: false,
 child: Container(
 padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(
 top: BorderSide(color: Colors.grey.withOpacity(0.2)),
 ),
 ),
 child: Row(
 children: [
 Expanded(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: const Row(
 children: [
 Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
 SizedBox(width: 10),
 Text(
 'AI',
 style: TextStyle(
 fontWeight: FontWeight.w800,
 color: Color(0xFF2563EB),
 ),
 ),
 SizedBox(width: 12),
 Expanded(
 child: Text(
 'AI suggests contracting scope and contractor packages based on project type and region.',
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(color: Color(0xFF1F2937)),
 ),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: onNext,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF6C437),
 foregroundColor: const Color(0xFF111827),
 padding:
 const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 child: const Text(
 'Next',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _ScopeSectionModeSwitcher extends StatelessWidget {
 const _ScopeSectionModeSwitcher({
 required this.showDetails,
 required this.onChanged,
 });

 final bool showDetails;
 final ValueChanged<bool> onChanged;

 @override
 Widget build(BuildContext context) {
 Widget buildOption({
 required String label,
 required bool selected,
 required VoidCallback onTap,
 }) {
 return Expanded(
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 140),
 curve: Curves.easeOut,
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: BoxDecoration(
 color: selected ? const Color(0xFFEFF6FF) : Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: selected
 ? const Color(0xFF93C5FD)
 : const Color(0xFFE5E7EB),
 ),
 ),
 alignment: Alignment.center,
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12.5,
 fontWeight: FontWeight.w700,
 color: selected
 ? const Color(0xFF1D4ED8)
 : const Color(0xFF6B7280),
 ),
 ),
 ),
 ),
 );
 }

 return Row(
 children: [
 buildOption(
 label: 'Contracting Overview',
 selected: !showDetails,
 onTap: () => onChanged(false),
 ),
 const SizedBox(width: 12),
 buildOption(
 label: 'Contract Details',
 selected: showDetails,
 onTap: () => onChanged(true),
 ),
 ],
 );
 }
}

class _ContractScopeDetailsBoard extends StatelessWidget {
 const _ContractScopeDetailsBoard({
 required this.items,
 required this.stageOptions,
 required this.onStageChanged,
 required this.onSavePotentialContractors,
 required this.onSuggestContractors,
 required this.onOpenApprovedContractorList,
 this.onEdit,
 this.onDelete,
 });

 final List<ProcurementItemModel> items;
 final List<String> stageOptions;
 final Future<void> Function(ProcurementItemModel, String) onStageChanged;
 final Future<void> Function(ProcurementItemModel, List<String>)
 onSavePotentialContractors;
 final Future<void> Function(ProcurementItemModel) onSuggestContractors;
 final VoidCallback onOpenApprovedContractorList;
 final ValueChanged<ProcurementItemModel>? onEdit;
 final ValueChanged<ProcurementItemModel>? onDelete;

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
 decoration: BoxDecoration(
 color: const Color(0xFFFAFAFA),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No contract details available yet. Add scope items in the Contract Details tab first.',
 textAlign: TextAlign.center,
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 final cardsPerRow = width > 1380
 ? 3
 : width > 940
 ? 2
 : 1;
 final spacing = 12.0;
 final cardWidth = cardsPerRow == 1
 ? width
 : (width - ((cardsPerRow - 1) * spacing)) / cardsPerRow;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFF),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFDCEAFE)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Scope details pulled from Contracting Scope',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1E3A8A),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Review each card to confirm scope summary, contractors, contract type, value, duration, bidding requirement, and start stage.',
 style: TextStyle(
 fontSize: 11.5,
 height: 1.35,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 6),
 TextButton.icon(
 onPressed: onOpenApprovedContractorList,
 style: TextButton.styleFrom(
 padding: EdgeInsets.zero,
 minimumSize: const Size(0, 32),
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 icon: const Icon(Icons.fact_check_outlined, size: 15),
 label: const Text('Approved Contractor List'),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: items
 .map(
 (item) => SizedBox(
 width: cardWidth,
 child: _ContractScopeDetailCard(
 item: item,
 stageOptions: stageOptions,
 onStageChanged: onStageChanged,
 onSavePotentialContractors: onSavePotentialContractors,
 onSuggestContractors: onSuggestContractors,
 onOpenApprovedContractorList:
 onOpenApprovedContractorList,
 onEdit: onEdit,
 onDelete: onDelete,
 ),
 ),
 )
 .toList(),
 ),
 ],
 );
 },
 );
 }
}

class _ContractScopeDetailCard extends StatefulWidget {
 const _ContractScopeDetailCard({
 required this.item,
 required this.stageOptions,
 required this.onStageChanged,
 required this.onSavePotentialContractors,
 required this.onSuggestContractors,
 required this.onOpenApprovedContractorList,
 this.onEdit,
 this.onDelete,
 });

 final ProcurementItemModel item;
 final List<String> stageOptions;
 final Future<void> Function(ProcurementItemModel, String) onStageChanged;
 final Future<void> Function(ProcurementItemModel, List<String>)
 onSavePotentialContractors;
 final Future<void> Function(ProcurementItemModel) onSuggestContractors;
 final VoidCallback onOpenApprovedContractorList;
 final ValueChanged<ProcurementItemModel>? onEdit;
 final ValueChanged<ProcurementItemModel>? onDelete;

 @override
 State<_ContractScopeDetailCard> createState() =>
 _ContractScopeDetailCardState();
}

class _ContractScopeDetailCardState extends State<_ContractScopeDetailCard> {
 bool _expanded = false;
 bool _savingStage = false;
 bool _suggestingContractors = false;

 List<String> _splitNames(String raw) {
 if (raw.trim().isEmpty) return const <String>[];
 return raw
 .replaceAll('\n', ',')
 .replaceAll(';', ',')
 .replaceAll('|', ',')
 .split(',')
 .map((entry) => entry.trim())
 .where((entry) => entry.isNotEmpty)
 .toSet()
 .toList()
 ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
 }

 String _formatCurrency(double value) {
 if (!value.isFinite || value <= 0) return '-';
 final whole = value.round().toString();
 final grouped =
 whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
 return '\$$grouped';
 }

 String _normalizedStage(String raw) {
 final value = raw.trim().toLowerCase();
 if (value.contains('init')) return 'Initiation';
 if (value.contains('plan')) return 'Planning';
 if (value.contains('exec')) return 'Execution';
 if (value.contains('launch') || value.contains('deploy')) return 'Launch';
 if (value.contains('oper')) return 'Operations';
 if (value.contains('unsure') || value.contains('unknown')) return 'Unsure';
 return 'Planning';
 }

 Future<void> _addContractorManually() async {
 final controller = TextEditingController();
 final result = await showDialog<String>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Add Potential Contractors'),
 content: VoiceTextField(
 controller: controller,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Names (comma-separated)',
 hintText: 'Contractor A, Contractor B',
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(controller.text),
 child: const Text('Save'),
 ),
 ],
 ),
 );
 controller.dispose();
 if (result == null || result.trim().isEmpty) return;

 final current = _splitNames(widget.item.notes);
 final merged = <String>{...current, ..._splitNames(result)}.toList();
 await widget.onSavePotentialContractors(widget.item, merged);
 }

 @override
 Widget build(BuildContext context) {
 final item = widget.item;
 final contractors = _splitNames(item.notes);
 final hasSummary = item.description.trim().isNotEmpty;
 final hasType = item.category.trim().isNotEmpty;
 final hasDuration = item.comments.trim().isNotEmpty;
 final hasValue = item.budget.isFinite && item.budget > 0;
 final hasBidding = item.responsibleMember.trim().isNotEmpty;
 final stage = widget.stageOptions.contains(item.projectPhase)
 ? item.projectPhase
 : _normalizedStage(item.projectPhase);

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 item.name.trim().isEmpty
 ? 'Untitled Scope'
 : item.name.trim(),
 style: const TextStyle(
 fontSize: 14.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 ),
 child: Text(
 item.category.trim().isEmpty
 ? 'Unsure'
 : item.category.trim(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1D4ED8),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Scope Summary',
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 hasSummary
 ? item.description.trim()
 : 'Add a concise scope summary so team members can validate intent quickly.',
 maxLines: _expanded ? 8 : 3,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 12.2,
 color: hasSummary
 ? const Color(0xFF4B5563)
 : const Color(0xFF92400E),
 height: 1.35,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: [
 _RequiredAspectChip(label: 'Summary', complete: hasSummary),
 _RequiredAspectChip(label: 'Contract Type', complete: hasType),
 _RequiredAspectChip(label: 'Duration', complete: hasDuration),
 _RequiredAspectChip(label: 'Value', complete: hasValue),
 _RequiredAspectChip(label: 'Bidding', complete: hasBidding),
 _RequiredAspectChip(
 label: 'Contractors', complete: contractors.isNotEmpty),
 ],
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 _InfoPill(
 label: 'Estimated Value',
 value: _formatCurrency(item.budget)),
 _InfoPill(
 label: 'Estimated Duration',
 value:
 item.comments.trim().isEmpty ? '-' : item.comments.trim(),
 ),
 _InfoPill(
 label: 'Bidding Required',
 value: item.responsibleMember.trim().isEmpty
 ? 'Not Sure'
 : item.responsibleMember.trim(),
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: stage,
 decoration: const InputDecoration(
 labelText: 'Contracting Start Stage',
 isDense: true,
 ),
 items: widget.stageOptions
 .map(
 (option) => DropdownMenuItem<String>(
 value: option,
 child: Text(option),
 ),
 )
 .toList(),
 onChanged: _savingStage
 ? null
 : (value) async {
 if (value == null) return;
 setState(() => _savingStage = true);
 await widget.onStageChanged(item, value);
 if (!mounted) return;
 setState(() => _savingStage = false);
 },
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 const Text(
 'Potential Contractors',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const Spacer(),
 TextButton.icon(
 onPressed: widget.onOpenApprovedContractorList,
 style: TextButton.styleFrom(
 visualDensity: VisualDensity.compact,
 minimumSize: const Size(0, 32),
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 icon: const Icon(Icons.fact_check_outlined, size: 14),
 label: const Text('Approved List'),
 ),
 ],
 ),
 const SizedBox(height: 8),
 if (contractors.isEmpty)
 const Text(
 'No contractors listed yet.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 )
 else
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: contractors
 .map(
 (name) => Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 name,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF374151),
 ),
 ),
 ),
 )
 .toList(),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 OutlinedButton.icon(
 onPressed: _suggestingContractors
 ? null
 : () async {
 setState(() => _suggestingContractors = true);
 await widget.onSuggestContractors(item);
 if (!mounted) return;
 setState(() => _suggestingContractors = false);
 },
 icon: _suggestingContractors
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome, size: 15),
 label: const Text('AI Suggest'),
 ),
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: _addContractorManually,
 icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
 label: const Text('Add Contractor'),
 ),
 const Spacer(),
 IconButton(
 onPressed: () => setState(() => _expanded = !_expanded),
 tooltip: _expanded ? 'Collapse' : 'Expand',
 icon: Icon(
 _expanded
 ? Icons.expand_less_rounded
 : Icons.expand_more_rounded,
 ),
 ),
 ],
 ),
 if (_expanded) ...[
 const Divider(height: 16),
 Row(
 children: [
 const Text(
 'Scope Detail Actions',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const Spacer(),
 TextButton.icon(
 onPressed:
 widget.onEdit == null ? null : () => widget.onEdit!(item),
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit'),
 ),
 TextButton.icon(
 onPressed: widget.onDelete == null
 ? null
 : () => widget.onDelete!(item),
 icon: const Icon(Icons.delete_outline, size: 16),
 label: const Text('Delete'),
 style: TextButton.styleFrom(foregroundColor: Colors.red),
 ),
 ],
 ),
 ],
 ],
 ),
 );
 }
}

class _InfoPill extends StatelessWidget {
 const _InfoPill({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(9),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 10.5,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 value,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF111827),
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 );
 }
}

class _RequiredAspectChip extends StatelessWidget {
 const _RequiredAspectChip({required this.label, required this.complete});

 final String label;
 final bool complete;

 @override
 Widget build(BuildContext context) {
 final bg = complete ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2);
 final border = complete ? const Color(0xFFB7E4C7) : const Color(0xFFFCCFCB);
 final fg = complete ? const Color(0xFF166534) : const Color(0xFFB42318);

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: bg,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: border),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 complete ? Icons.check_circle_rounded : Icons.error_outline_rounded,
 size: 13,
 color: fg,
 ),
 const SizedBox(width: 4),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: fg,
 ),
 ),
 ],
 ),
 );
 }
}

enum _ContractingManagementTab {
 scopeManagement,
 contractingTemplates,
 contractTracking,
 reports,
}

class _ContractScopeManagementState {
 const _ContractScopeManagementState({
 required this.scopeId,
 required this.authorizedRole,
 required this.started,
 required this.startedAt,
 required this.startedByEmail,
 required this.startedByRole,
 });

 final String scopeId;
 final String authorizedRole;
 final bool started;
 final DateTime? startedAt;
 final String startedByEmail;
 final String startedByRole;

 _ContractScopeManagementState copyWith({
 String? scopeId,
 String? authorizedRole,
 bool? started,
 DateTime? startedAt,
 String? startedByEmail,
 String? startedByRole,
 }) {
 return _ContractScopeManagementState(
 scopeId: scopeId ?? this.scopeId,
 authorizedRole: authorizedRole ?? this.authorizedRole,
 started: started ?? this.started,
 startedAt: startedAt ?? this.startedAt,
 startedByEmail: startedByEmail ?? this.startedByEmail,
 startedByRole: startedByRole ?? this.startedByRole,
 );
 }

 Map<String, dynamic> toMap() {
 return {
 'scopeId': scopeId,
 'authorizedRole': authorizedRole,
 'started': started,
 'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
 'startedByEmail': startedByEmail,
 'startedByRole': startedByRole,
 };
 }
}

class _ContractingWorkflowStep {
 const _ContractingWorkflowStep({
 required this.id,
 required this.name,
 required this.duration,
 required this.unit,
 });

 final String id;
 final String name;
 final int duration;
 final String unit;

 _ContractingWorkflowStep copyWith({
 String? id,
 String? name,
 int? duration,
 String? unit,
 }) {
 return _ContractingWorkflowStep(
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

 factory _ContractingWorkflowStep.fromMap(Map<String, dynamic> map) {
 final id = (map['id'] ?? '').toString().trim();
 final name = (map['name'] ?? map['stage'] ?? '').toString().trim();
 final rawDuration = map['duration'];
 var duration = 1;
 if (rawDuration is num) {
 duration = rawDuration.toInt();
 } else {
 duration = int.tryParse(rawDuration?.toString() ?? '') ?? 1;
 }
 if (duration < 1) duration = 1;
 final unit = (map['unit'] ?? '').toString().trim().toLowerCase() == 'month'
 ? 'month'
 : 'week';

 return _ContractingWorkflowStep(
 id: id.isEmpty ? 'step_${DateTime.now().microsecondsSinceEpoch}' : id,
 name: name.isEmpty ? 'Untitled Step' : name,
 duration: duration,
 unit: unit,
 );
 }
}

class _ContractingReportEntry {
 const _ContractingReportEntry({
 required this.id,
 required this.title,
 required this.status,
 required this.owner,
 required this.summary,
 required this.updatedAt,
 });

 final String id;
 final String title;
 final String status;
 final String owner;
 final String summary;
 final DateTime updatedAt;

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'status': status,
 'owner': owner,
 'summary': summary,
 'updatedAt': updatedAt.toIso8601String(),
 };

 factory _ContractingReportEntry.fromMap(Map<String, dynamic> map) {
 DateTime parse(dynamic raw) {
 if (raw is Timestamp) return raw.toDate();
 if (raw is DateTime) return raw;
 final parsed = DateTime.tryParse(raw?.toString() ?? '');
 return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
 }

 return _ContractingReportEntry(
 id: (map['id'] ?? '').toString().trim().isEmpty
 ? 'report_${DateTime.now().microsecondsSinceEpoch}'
 : (map['id'] ?? '').toString(),
 title: (map['title'] ?? '').toString(),
 status: (map['status'] ?? 'Draft').toString(),
 owner: (map['owner'] ?? '').toString(),
 summary: (map['summary'] ?? '').toString(),
 updatedAt: parse(map['updatedAt']),
 );
 }
}

class _SectionHeader extends StatelessWidget {
 final String title;
 final String? subtitle;
 final String actionLabel;
 final VoidCallback onAction;

 const _SectionHeader(
 {required this.title,
 this.subtitle,
 required this.actionLabel,
 required this.onAction});

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
 color: Color(0xFF111827),
 ),
 ),
 if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 subtitle!,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 ],
 ],
 ),
 ),
 const SizedBox(width: 16),
 ElevatedButton.icon(
 onPressed: onAction,
 icon: const Icon(Icons.add, size: 16),
 label: Text(actionLabel),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFEFF6FF),
 foregroundColor: const Color(0xFF2563EB),
 elevation: 0,
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 );
 }
}

class _ContractingScopeTable extends StatelessWidget {
 const _ContractingScopeTable({
 required this.items,
 this.onEdit,
 this.onDelete,
 });

 final List<ProcurementItemModel> items;
 final ValueChanged<ProcurementItemModel>? onEdit;
 final ValueChanged<ProcurementItemModel>? onDelete;

 String _formatCurrency(double value) {
 if (!value.isFinite || value <= 0) return '-';
 final whole = value.round().toString();
 final grouped =
 whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
 return '\$$grouped';
 }

 Widget _cellText(String text, {double width = 140, bool bold = false}) {
 final value = text.trim().isEmpty ? '-' : text.trim();
 return SizedBox(
 width: width,
 child: Text(
 value,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 12.5,
 color: const Color(0xFF111827),
 fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return buildNduTableEmptyState(
 context,
 message:
 'No contracting scope items added yet. Use AI regenerate or click Add Scope to get started.',
 );
 }

 final hasActions = onEdit != null || onDelete != null;

 return LayoutBuilder(
 builder: (context, constraints) {
 final minWidth =
 constraints.maxWidth > 1500 ? constraints.maxWidth : 1500.0;
 return ResponsiveDataTableWrapper(
 minWidth: minWidth,
 maxHeight: 560,
 child: buildNduDataTable(
 context: context,
 columnSpacing: 16,
 horizontalMargin: 12,
 border: TableBorder.all(
 color: const Color(0xFFE5E7EB),
 width: 0.7,
 borderRadius: BorderRadius.circular(10),
 ),
 columns: const [
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'No',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Contract Scope',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Description',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Potential Contractors',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Contract Type',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Estimated Duration',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Estimated Value',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(
 label: Align(
 alignment: Alignment.centerLeft,
 child: Text(
 'Bidding Required',
 textAlign: TextAlign.left,
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
 ),
 ),
 ),
 DataColumn(label: Center(child: Text(''))),
 ],
 rows: items.asMap().entries.map((entry) {
 final index = entry.key;
 final item = entry.value;
 final actionItems = <PopupMenuEntry<String>>[];
 if (onEdit != null) {
 actionItems.add(
 const PopupMenuItem<String>(
 value: 'edit',
 child: Row(
 children: [
 Icon(Icons.edit_outlined, size: 16),
 SizedBox(width: 8),
 Text('Edit scope'),
 ],
 ),
 ),
 );
 }
 if (onDelete != null) {
 actionItems.add(
 const PopupMenuItem<String>(
 value: 'delete',
 child: Row(
 children: [
 Icon(Icons.delete_outline, size: 16, color: Colors.red),
 SizedBox(width: 8),
 Text('Delete', style: TextStyle(color: Colors.red)),
 ],
 ),
 ),
 );
 }

 return DataRow(
 cells: [
 DataCell(Text('${index + 1}')),
 DataCell(_cellText(item.name, width: 170, bold: true)),
 DataCell(_cellText(item.description, width: 220)),
 DataCell(_cellText(item.notes, width: 190)),
 DataCell(_cellText(item.category, width: 120)),
 DataCell(_cellText(item.comments, width: 150)),
 DataCell(_cellText(_formatCurrency(item.budget), width: 130)),
 DataCell(_cellText(
 item.responsibleMember.trim().isEmpty
 ? 'Not Sure'
 : item.responsibleMember.trim(),
 width: 130,
 )),
 DataCell(
 hasActions
 ? PopupMenuButton<String>(
 icon: const Icon(Icons.more_horiz,
 color: Colors.grey),
 itemBuilder: (_) => actionItems,
 onSelected: (value) {
 if (value == 'edit' && onEdit != null) {
 onEdit!(item);
 } else if (value == 'delete' &&
 onDelete != null) {
 onDelete!(item);
 }
 },
 )
 : const SizedBox.shrink(),
 ),
 ],
 );
 }).toList(),
 ),
 );
 },
 );
 }
}

class _AiPreviewDialog extends StatelessWidget {
 final Map<String, dynamic> data;

 const _AiPreviewDialog({required this.data});

 @override
 Widget build(BuildContext context) {
 final contracts = data['contracts'] as List? ?? [];
 final items = data['contract_scope_items'] as List? ??
 data['procurement_items'] as List? ??
 [];

 return AlertDialog(
 title: const Row(
 children: [
 Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
 SizedBox(width: 12),
 Text('AI Suggested Contracting Scope'),
 ],
 ),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 'Found ${contracts.length} contracts and ${items.length} contracting scope items.',
 style: const TextStyle(fontSize: 14),
 ),
 const SizedBox(height: 16),
 if (contracts.isNotEmpty) ...[
 const Text(
 'Contracts Preview:',
 style: TextStyle(fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 ...contracts.take(3).map(
 (contract) => Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 '- ${contract['title']} (${contract['contractor'] ?? 'TBD'})',
 style: const TextStyle(fontSize: 12),
 ),
 ),
 ),
 if (contracts.length > 3)
 Text(
 '+ ${contracts.length - 3} more contracts...',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 const SizedBox(height: 16),
 ],
 if (items.isNotEmpty) ...[
 const Text(
 'Contracting Scope Preview:',
 style: TextStyle(fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 ...items.take(3).map(
 (scope) => Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 '- ${scope['name']} (${scope['contract_type'] ?? scope['category'] ?? 'Unsure'})',
 style: const TextStyle(fontSize: 12),
 ),
 ),
 ),
 if (items.length > 3)
 Text(
 '+ ${items.length - 3} more items...',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(context).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 ),
 child: const Text('Confirm & Save'),
 ),
 ],
 );
 }
}
