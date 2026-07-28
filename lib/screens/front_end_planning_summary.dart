import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/screens/home_screen.dart';

import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/planning_dashboard_card.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
/// Front End Planning – Summary screen
/// Mirrors the provided layout with shared workspace chrome,
/// large notes area, summary text panel, and AI hint + Next controls.
class FrontEndPlanningSummaryScreen extends StatefulWidget {
 const FrontEndPlanningSummaryScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const FrontEndPlanningSummaryScreen(),
 destinationCheckpoint: 'fep_summary',
 );
 }

 @override
 State<FrontEndPlanningSummaryScreen> createState() =>
 _FrontEndPlanningSummaryScreenState();
}

class _FrontEndPlanningSummaryScreenState
 extends State<FrontEndPlanningSummaryScreen> {
 final GlobalKey<ScaffoldState> _mobileScaffoldKey =
 GlobalKey<ScaffoldState>();
 final ScrollController _contentScrollController = ScrollController();
 final TextEditingController _notes = RichTextEditingController();
 final TextEditingController _summaryNotes = RichTextEditingController();
 bool _isSyncReady = false;
 bool _reviewConfirmed = false;

 @override
 void initState() {
 super.initState();
 // Notes = prose; no auto-bullet

 WidgetsBinding.instance.addPostFrameCallback((_) {
 _summaryNotes.addListener(_syncSummaryToProvider);
 _notes.addListener(_syncNotesToProvider);
 _isSyncReady = true;
 final data = ProjectDataHelper.getData(context);
 _notes.text = data.frontEndPlanning.requirementsNotes;

 // Auto-populate summary if it's empty, concatenating from:
 // Project Vision (notes) + Core Stakeholders + Business Case + Selected Preferred Solution
 if (data.frontEndPlanning.summary.isEmpty) {
 final summary = _buildMasterSummary(data);
 _summaryNotes.text = summary;
 } else {
 _summaryNotes.text = data.frontEndPlanning.summary;
 }

 _syncSummaryToProvider();
 _syncNotesToProvider();
 if (mounted) setState(() {});
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Front End Planning Summary',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
/// Builds the master summary by concatenating Project Vision, Core Stakeholders,
 /// Business Case, and Selected Preferred Solution
 String _buildMasterSummary(dynamic data) {
 final parts = <String>[];

 // 1. Project Vision (from notes field)
 if (data.notes.isNotEmpty) {
 parts.add('Project Vision:');
 parts.add(data.notes);
 parts.add('');
 }

 // 2. Core Stakeholders
 if (data.coreStakeholdersData != null) {
 final stakeholders = data.coreStakeholdersData;
 if (stakeholders.solutionStakeholderData.isNotEmpty) {
 parts.add('Core Stakeholders:');
 for (final stakeholderData in stakeholders.solutionStakeholderData) {
 if (stakeholderData.solutionTitle.isNotEmpty) {
 parts.add('${stakeholderData.solutionTitle}:');
 }
 if (stakeholderData.notableStakeholders.isNotEmpty) {
 parts.add(stakeholderData.notableStakeholders);
 }
 }
 parts.add('');
 }
 }

 // 3. Business Case
 if (data.businessCase.isNotEmpty) {
 parts.add('Business Case:');
 parts.add(data.businessCase);
 parts.add('');
 }

 // 4. Selected Preferred Solution
 if (data.preferredSolutionAnalysis?.selectedSolutionTitle != null &&
 data.preferredSolutionAnalysis!.selectedSolutionTitle!.isNotEmpty) {
 parts.add('Selected Preferred Solution:');
 parts.add(data.preferredSolutionAnalysis!.selectedSolutionTitle!);
 }

 return parts.join('\n');
 }

 @override
 void dispose() {
 if (_isSyncReady) {
 _summaryNotes.removeListener(_syncSummaryToProvider);
 _notes.removeListener(_syncNotesToProvider);
 }
 _contentScrollController.dispose();
 _notes.dispose();
 _summaryNotes.dispose();
 super.dispose();
 }

 Future<void> _handleNext() async {
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'fep_summary',
 nextScreenBuilder: () => const FrontEndPlanningRequirementsScreen(),
 dataUpdater: (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 summary: _summaryNotes.text.trim(),
 requirementsNotes: _notes.text.trim(),
 ),
 ),
 );
 }

 void _syncSummaryToProvider() {
 if (!mounted) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 summary: _summaryNotes.text.trim(),
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_summary');
 }

 void _syncNotesToProvider() {
 if (!mounted) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 requirementsNotes: _notes.text.trim(),
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_summary');
 }

 @override
 Widget build(BuildContext context) {
 if (AppBreakpoints.isMobile(context)) {
 return _buildMobileScaffold(context);
 }

 return ResponsiveScaffold(
 activeItemLabel: 'Details',
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(onExportPdf: _exportPdf),
 Expanded(
 child: ScrollIndicatorOverlay(
 controller: _contentScrollController,
 child: SingleChildScrollView(
 controller: _contentScrollController,
 padding: const EdgeInsets.symmetric(
 horizontal: 32, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _formattedNotesEditor(
 controller: _notes,
 hint: 'Input your notes here...',
 minLines: 3,
 maxLines: 5),
 const SizedBox(height: 24),
 const _SectionTitle(),
 const SizedBox(height: 18),
 _SummaryPanel(controller: _summaryNotes),
 const SizedBox(height: 24),
 const _PlanningCardsSection(),
 const SizedBox(height: 24),
 ProceedConfirmationGate(
 value: _reviewConfirmed,
 onChanged: (value) {
 setState(() => _reviewConfirmed = value);
 },
 scrollController: _contentScrollController,
 ),
 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 _BottomOverlay(
 summaryController: _summaryNotes,
 onNext: _handleNext,
 nextEnabled: _reviewConfirmed,
 ),
 ],
 ),
 );
 }

 Widget _buildMobileScaffold(BuildContext context) {
 final data = ProjectDataHelper.getData(context);
 final projectName = data.projectName.trim().isEmpty
 ? 'Untitled Project'
 : data.projectName.trim();
 final stakeholders = data.coreStakeholdersData?.solutionStakeholderData
 .map((item) => item.notableStakeholders.trim())
 .where((value) => value.isNotEmpty)
 .toList() ??
 <String>[];

 return Scaffold(
 key: _mobileScaffoldKey,
 backgroundColor: Colors.white,
 drawer: Drawer(
 width: MediaQuery.sizeOf(context).width * 0.88,
 child: const SafeArea(
 child: InitiationLikeSidebar(activeItemLabel: 'Details'),
 ),
 ),
 body: SafeArea(
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(8, 10, 10, 6),
 child: Row(
 children: [
 IconButton(
 onPressed: () =>
 _mobileScaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu_rounded, size: 18),
 visualDensity: VisualDensity.compact,
 ),
 const SizedBox(width: 4),
 const Expanded(
 child: Text(
 'Details',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFF2563EB),
 child: Text(
 (projectName.isNotEmpty ? projectName[0] : 'P')
 .toUpperCase(),
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'FRONT END PLANNING',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 projectName,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563),
 ),
 ),
 const SizedBox(height: 18),
 _formattedNotesEditor(
 controller: _notes,
 hint: 'Input your notes here...',
 minLines: 3,
 maxLines: 5,
 showLabel: true,
 ),
 const SizedBox(height: 16),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: const [
 Text(
 'Description',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(width: 6),
 Expanded(
 child: Text(
 '(Summary of activities)',
 style: TextStyle(
 fontSize: 11,
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Text(
 'Project Vision :',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 6),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 data.notes.trim().isEmpty
 ? 'No project vision captured yet.'
 : data.notes.trim(),
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF374151),
 ),
 ),
 ),
 const SizedBox(height: 10),
 const Text(
 'Core Stakeholders:',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 6),
 if (stakeholders.isEmpty)
 const Text(
 '- No stakeholders captured yet.',
 style: TextStyle(
 fontSize: 12.5, color: Color(0xFF6B7280)),
 )
 else
 ...stakeholders.take(3).map(
 (entry) => Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 '- $entry',
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Business Case:',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 data.businessCase.trim().isEmpty
 ? 'No business case defined yet.'
 : data.businessCase.trim(),
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 bottomNavigationBar: SafeArea(
 top: false,
 child: Padding(
 padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
 child: Row(
 children: [
 IconButton(
 onPressed: () => HomeScreen.open(context),
 icon: const Icon(Icons.home_rounded, color: Color(0xFF94A3B8)),
 ),
 IconButton(
 onPressed: () => _mobileScaffoldKey.currentState?.openDrawer(),
 icon:
 const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
 ),
 Expanded(
 child: Center(
 child: InkWell(
 onTap: () => _mobileScaffoldKey.currentState?.openDrawer(),
 borderRadius: BorderRadius.circular(999),
 child: Container(
 width: 44,
 height: 44,
 decoration: const BoxDecoration(
 color: Color(0xFFF4B400),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.add, color: Colors.white),
 ),
 ),
 ),
 ),
 ElevatedButton(
 onPressed: () async {
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'fep_summary',
 nextScreenBuilder: () =>
 const FrontEndPlanningRequirementsScreen(),
 dataUpdater: (projectData) => projectData.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: projectData.frontEndPlanning,
 summary: _summaryNotes.text.trim(),
 requirementsNotes: _notes.text.trim(),
 ),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.white,
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20),
 ),
 ),
 child: const Text(
 'Next',
 style: TextStyle(fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _SectionTitle extends StatelessWidget {
 const _SectionTitle();

 @override
 Widget build(BuildContext context) {
 return RichText(
 text: const TextSpan(
 children: [
 TextSpan(
 text: 'Description ',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 TextSpan(
 text:
 '(Provide a comprehensive summary of the front end planning activities.)',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 );
 }
}

class _SummaryPanel extends StatelessWidget {
 const _SummaryPanel({required this.controller});

 final TextEditingController controller;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.all(16),
 child: VoiceTextField(
 controller: controller,
 minLines: 12,
 maxLines: null,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: '',
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
 ),
 );
 }
}

class _PlanningCardsSection extends StatefulWidget {
 const _PlanningCardsSection();

 @override
 State<_PlanningCardsSection> createState() => _PlanningCardsSectionState();
}

class _PlanningCardsSectionState extends State<_PlanningCardsSection> {
 // Track generating state for each section key
 final Map<String, bool> _generatingStates = {};
 final Map<String, List<List<PlanningDashboardItem>>> _listUndoHistory = {};
 static const int _maxUndoSnapshotsPerList = 20;

 final _openAiService = OpenAiServiceSecure();
 static const String _autoGeneratedHint =
 'Auto AI generated for core project type details based on initial information. '
 'They will be prompted to edit and add to the list.';
 static const String _aiNoticeText =
 'These were auto-generated by KAZ AI based on the defined project scope. '
 'Please review and refine them to ensure all relevant aspects of the project are accurately captured.';

 String _canonicalListKey(String listKey) {
 switch (listKey) {
 case 'withinScope':
 case 'withinScopeItems':
 return 'withinScopeItems';
 case 'outOfScope':
 case 'outOfScopeItems':
 return 'outOfScopeItems';
 case 'assumptions':
 case 'assumptionItems':
 return 'assumptionItems';
 case 'constraints':
 case 'constraintItems':
 return 'constraintItems';
 case 'successCriteria':
 case 'successCriteriaItems':
 return 'successCriteriaItems';
 default:
 return listKey;
 }
 }

 String _normalizeWhitespace(String value) =>
 value.trim().replaceAll(RegExp(r'\s+'), ' ');

 String _itemSignature(PlanningDashboardItem item) {
 final description = _normalizeWhitespace(item.description).toLowerCase();
 if (description.isNotEmpty) return description;
 return _normalizeWhitespace(item.title).toLowerCase();
 }

 List<PlanningDashboardItem> _cloneItems(List<PlanningDashboardItem> items) {
 return items
 .map(
 (item) => PlanningDashboardItem(
 id: item.id,
 title: item.title,
 description: item.description,
 createdAt: item.createdAt,
 isAiGenerated: item.isAiGenerated,
 ),
 )
 .toList();
 }

 bool _sameItemList(
 List<PlanningDashboardItem> a, List<PlanningDashboardItem> b) {
 if (a.length != b.length) return false;
 for (var i = 0; i < a.length; i++) {
 if (a[i].id != b[i].id ||
 _normalizeWhitespace(a[i].title) !=
 _normalizeWhitespace(b[i].title) ||
 _normalizeWhitespace(a[i].description) !=
 _normalizeWhitespace(b[i].description) ||
 a[i].isAiGenerated != b[i].isAiGenerated) {
 return false;
 }
 }
 return true;
 }

 List<PlanningDashboardItem> _dedupeAndNormalizeItems(
 List<PlanningDashboardItem> items) {
 final seen = <String>{};
 final normalized = <PlanningDashboardItem>[];

 for (final item in items) {
 final title = _normalizeWhitespace(item.title);
 final description = _normalizeWhitespace(item.description);
 if (description.isEmpty) continue;

 final normalizedItem = PlanningDashboardItem(
 id: item.id,
 title: title,
 description: description,
 createdAt: item.createdAt,
 isAiGenerated: item.isAiGenerated,
 );

 final signature = _itemSignature(normalizedItem);
 if (seen.add(signature)) {
 normalized.add(normalizedItem);
 }
 }

 return normalized;
 }

 String _deriveTitle(String sectionLabel, String description) {
 final lower = description.toLowerCase();

 if (sectionLabel.contains('Constraint')) {
 if (lower.contains('budget')) return 'Budget Constraint';
 if (lower.contains('timeline') || lower.contains('schedule')) {
 return 'Schedule Constraint';
 }
 if (lower.contains('resource')) return 'Resource Constraint';
 if (lower.contains('compliance') || lower.contains('regulator')) {
 return 'Compliance Constraint';
 }
 return 'Project Constraint';
 }

 if (sectionLabel.contains('Within Scope')) return 'Scope Deliverable';
 if (sectionLabel.contains('Out of Scope')) return 'Scope Exclusion';
 if (sectionLabel.contains('Assumption')) return 'Planning Assumption';
 if (sectionLabel.contains('Success Criteria')) return 'Success Criterion';

 final words = _normalizeWhitespace(description)
 .split(' ')
 .where((word) => word.isNotEmpty)
 .take(4)
 .toList();
 if (words.isEmpty) return sectionLabel;
 return words.join(' ');
 }

 List<PlanningDashboardItem> _prepareGeneratedItems(
 List<PlanningDashboardItem> currentList,
 List<PlanningDashboardItem> generatedItems,
 String sectionLabel,
 ) {
 final merged = <PlanningDashboardItem>[
 ..._cloneItems(currentList),
 ...generatedItems.map(
 (item) {
 final description = _normalizeWhitespace(item.description);
 final title = _normalizeWhitespace(item.title);
 final resolvedTitle = title.isNotEmpty
 ? title
 : _deriveTitle(sectionLabel, description);

 return PlanningDashboardItem(
 id: item.id,
 title: resolvedTitle,
 description: description,
 createdAt: item.createdAt,
 isAiGenerated: true,
 );
 },
 ),
 ];

 return _dedupeAndNormalizeItems(merged);
 }

 void _pushUndoSnapshot(String listKey, List<PlanningDashboardItem> items) {
 final canonicalKey = _canonicalListKey(listKey);
 final history = _listUndoHistory.putIfAbsent(
 canonicalKey, () => <List<PlanningDashboardItem>>[]);
 final snapshot = _cloneItems(items);

 if (history.isNotEmpty && _sameItemList(history.last, snapshot)) {
 return;
 }

 history.add(snapshot);
 if (history.length > _maxUndoSnapshotsPerList) {
 history.removeAt(0);
 }

 if (mounted) {
 setState(() {});
 }
 }

 bool _canUndo(String listKey) {
 final history = _listUndoHistory[_canonicalListKey(listKey)];
 return history != null && history.isNotEmpty;
 }

 Future<void> _undoListChange(BuildContext context, String listKey) async {
 final canonicalKey = _canonicalListKey(listKey);
 final history = _listUndoHistory[canonicalKey];
 if (history == null || history.isEmpty) return;

 final previous = history.removeLast();
 await _updateList(context, canonicalKey, previous);

 if (!mounted) return;
 setState(() {});
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Last change undone')),
 );
 }
 }

 List<PlanningDashboardItem> _removeSingleItem(
 List<PlanningDashboardItem> currentList, PlanningDashboardItem item) {
 final updatedList = _cloneItems(currentList);
 final targetId = item.id.trim();

 if (targetId.isNotEmpty) {
 final byIdIndex =
 updatedList.indexWhere((element) => element.id.trim() == targetId);
 if (byIdIndex != -1) {
 updatedList.removeAt(byIdIndex);
 return updatedList;
 }
 }

 final signature = _itemSignature(item);
 final byContentIndex = updatedList
 .indexWhere((element) => _itemSignature(element) == signature);
 if (byContentIndex != -1) {
 updatedList.removeAt(byContentIndex);
 return updatedList;
 }

 final byReferenceIndex =
 currentList.indexWhere((element) => identical(element, item));
 if (byReferenceIndex >= 0 && byReferenceIndex < updatedList.length) {
 updatedList.removeAt(byReferenceIndex);
 }

 return updatedList;
 }

 Future<void> _showAiGeneratedNotice() async {
 if (!mounted) return;
 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('KAZ AI Suggestions Added'),
 content: const Text(_aiNoticeText),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _checkAndAutoGenerate();
 });
 }

 void _checkAndAutoGenerate() {
 final data = ProjectDataHelper.getData(context);

 // Safety check: Only generate if ALL lists are empty to avoid spamming or overwriting
 // functionality if the user just hasn't added anything yet.
 // Actually user wants "automatically when u load in".
 // We will check each individually but maybe limit concurrency?
 // Let's do it sequentially to be safe.

 _autoGenerateIfEmpty(data.withinScopeItems, 'Within Scope', 'withinScope',
 'withinScopeItems')
 .then((_) => _autoGenerateIfEmpty(data.outOfScopeItems, 'Out of Scope',
 'outOfScope', 'outOfScopeItems'))
 .then((_) => _autoGenerateIfEmpty(data.assumptionItems, 'Assumptions',
 'assumptions', 'assumptionItems'))
 .then((_) => _autoGenerateIfEmpty(data.constraintItems, 'Constraints',
 'constraints', 'constraintItems'))
 .then((_) => _autoGenerateIfEmpty(
 data.frontEndPlanning.successCriteriaItems,
 'Success Criteria',
 'successCriteria',
 'successCriteriaItems'))
 .then((_) => _autoGenerateIfEmptyGoals(
 data.projectGoals, 'Project Objectives', 'projectGoals'));
 }

 Future<void> _autoGenerateIfEmpty(List<PlanningDashboardItem> items,
 String title, String loadingKey, String listKey) async {
 if (items.isEmpty && mounted) {
 // Check if we already generated this session to avoid infinite loops if AI returns nothing
 // For now, just call it.
 debugPrint('Auto-generating $title...');
 await _handleGenerateAI(
 context,
 title,
 loadingKey,
 items,
 listKey: listKey,
 );
 }
 }

 Future<void> _autoGenerateIfEmptyGoals(
 List<ProjectGoal> items, String title, String loadingKey) async {
 if (items.isEmpty && mounted) {
 debugPrint('Auto-generating $title...');
 await _handleGenerateGoalsAI(context, title, loadingKey, items);
 }
 }

 @override
 Widget build(BuildContext context) {
 // Listen to provider to rebuild when data changes
 final provider = Provider.of<ProjectDataProvider>(context);
 final data = provider.projectData;

 return Column(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _GoalsCard(
 title: 'Project Objectives',
 description:
 'Specific, measurable goals the project aims to achieve.',
 items: data.projectGoals,
 isGenerating: _generatingStates['projectGoals'] ?? false,
 onAdd: () => _handleAddGoal(
 context, 'Project Objectives', data.projectGoals),
 onEdit: (item) =>
 _handleEditGoal(context, item, data.projectGoals),
 onDelete: (item) =>
 _handleDeleteGoal(context, item, data.projectGoals),
 onGenerateAI: () => _handleGenerateGoalsAI(context,
 'Project Objectives', 'projectGoals', data.projectGoals),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: PlanningDashboardCard(
 title: 'Success Criteria',
 description:
 'Standards by which the project success will be judged.',
 items: data.frontEndPlanning.successCriteriaItems,
 isGenerating: _generatingStates['successCriteria'] ?? false,
 onUndo: () => _undoListChange(context, 'successCriteriaItems'),
 canUndo: _canUndo('successCriteriaItems'),
 onAdd: () => _handleAddItem(
 context,
 'successCriteriaItems',
 'Success Criteria',
 data.frontEndPlanning.successCriteriaItems),
 onEdit: (item) => _handleEditItem(
 context,
 'successCriteriaItems',
 item,
 data.frontEndPlanning.successCriteriaItems),
 onDelete: (item) => _handleDeleteItem(
 context,
 'successCriteriaItems',
 item,
 data.frontEndPlanning.successCriteriaItems),
 onGenerateAI: () => _handleGenerateAI(
 context,
 'Success Criteria',
 'successCriteria',
 data.frontEndPlanning.successCriteriaItems,
 listKey: 'successCriteriaItems',
 showNotice: true),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: PlanningDashboardCard(
 title: 'Within Project Scope',
 description:
 '(Description: Work, features, deliverables, and activities that are explicitly included and will be delivered to achieve the project\'s objectives.)',
 items: data.withinScopeItems,
 isGenerating: _generatingStates['withinScope'] ?? false,
 emptyStateText: _autoGeneratedHint,
 onUndo: () => _undoListChange(context, 'withinScopeItems'),
 canUndo: _canUndo('withinScopeItems'),
 onAdd: () => _handleAddItem(context, 'withinScopeItems',
 'Within Scope', data.withinScopeItems),
 onEdit: (item) => _handleEditItem(
 context, 'withinScopeItems', item, data.withinScopeItems),
 onDelete: (item) => _handleDeleteItem(
 context, 'withinScopeItems', item, data.withinScopeItems),
 onGenerateAI: () => _handleGenerateAI(context, 'Within Scope',
 'withinScope', data.withinScopeItems,
 listKey: 'withinScopeItems', showNotice: true),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: PlanningDashboardCard(
 title: 'Out of Project Scope',
 description:
 '(Description: Work, features, or activities that are explicitly excluded from project and will not be delivered as part of its objectives.)',
 items: data.outOfScopeItems,
 isGenerating: _generatingStates['outOfScope'] ?? false,
 emptyStateText: _autoGeneratedHint,
 onUndo: () => _undoListChange(context, 'outOfScopeItems'),
 canUndo: _canUndo('outOfScopeItems'),
 onAdd: () => _handleAddItem(context, 'outOfScopeItems',
 'Out of Scope', data.outOfScopeItems),
 onEdit: (item) => _handleEditItem(
 context, 'outOfScopeItems', item, data.outOfScopeItems),
 onDelete: (item) => _handleDeleteItem(
 context, 'outOfScopeItems', item, data.outOfScopeItems),
 onGenerateAI: () => _handleGenerateAI(
 context, 'Out of Scope', 'outOfScope', data.outOfScopeItems,
 listKey: 'outOfScopeItems', showNotice: true),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: PlanningDashboardCard(
 title: 'Project Assumptions',
 description:
 '(Description: Conditions or events assumed to be true that form the basis for planning and decision-making.)',
 items: data.assumptionItems,
 isGenerating: _generatingStates['assumptions'] ?? false,
 emptyStateText: _autoGeneratedHint,
 onUndo: () => _undoListChange(context, 'assumptionItems'),
 canUndo: _canUndo('assumptionItems'),
 onAdd: () => _handleAddItem(context, 'assumptionItems',
 'Assumptions', data.assumptionItems),
 onEdit: (item) => _handleEditItem(
 context, 'assumptionItems', item, data.assumptionItems),
 onDelete: (item) => _handleDeleteItem(
 context, 'assumptionItems', item, data.assumptionItems),
 onGenerateAI: () => _handleGenerateAI(
 context, 'Assumptions', 'assumptions', data.assumptionItems,
 listKey: 'assumptionItems', showNotice: true),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: PlanningDashboardCard(
 title: 'Project Constraints',
 description:
 '(Description: Fixed limitations or boundaries that restrict how a project can be planned and executed.)',
 items: data.constraintItems,
 isGenerating: _generatingStates['constraints'] ?? false,
 emptyStateText: _autoGeneratedHint,
 onUndo: () => _undoListChange(context, 'constraintItems'),
 canUndo: _canUndo('constraintItems'),
 onAdd: () => _handleAddItem(context, 'constraintItems',
 'Constraints', data.constraintItems),
 onEdit: (item) => _handleEditItem(
 context, 'constraintItems', item, data.constraintItems),
 onDelete: (item) => _handleDeleteItem(
 context, 'constraintItems', item, data.constraintItems),
 onGenerateAI: () => _handleGenerateAI(
 context, 'Constraints', 'constraints', data.constraintItems,
 listKey: 'constraintItems', showNotice: true),
 ),
 ),
 ],
 ),
 ],
 );
 }

 Future<void> _handleGenerateAI(BuildContext context, String sectionLabel,
 String loadingKey, List<PlanningDashboardItem> currentList,
 {String? listKey, bool showNotice = false}) async {
 setState(() => _generatingStates[loadingKey] = true);

 try {
 final data = ProjectDataHelper.getData(context);
 final projectContext =
 ProjectDataHelper.buildFepContext(data, sectionLabel: sectionLabel);

 final newItems = await _openAiService.generatePlanningItems(
 section: sectionLabel,
 context: projectContext,
 );

 if (!context.mounted) return;

 if (newItems.isNotEmpty) {
 final resolvedListKey = _canonicalListKey(listKey ?? loadingKey);
 _pushUndoSnapshot(resolvedListKey, currentList);

 final updatedList =
 _prepareGeneratedItems(currentList, newItems, sectionLabel);
 await _updateList(context, resolvedListKey, updatedList);

 if (showNotice && context.mounted) {
 await _showAiGeneratedNotice();
 }
 }
 } catch (e) {
 debugPrint('Error generating planning items: $e');
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to generate items: $e'),
 backgroundColor: Colors.red),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _generatingStates[loadingKey] = false);
 }
 }
 }

 Future<void> _handleDeleteItem(
 BuildContext context,
 String listKey,
 PlanningDashboardItem item,
 List<PlanningDashboardItem> currentList) async {
 final confirm = await showDeleteConfirmationDialog(
 context,
 title: 'Delete Item?',
 itemLabel: item.title,
 );

 if (confirm == true) {
 final canonicalListKey = _canonicalListKey(listKey);
 _pushUndoSnapshot(canonicalListKey, currentList);

 final updatedList = _removeSingleItem(currentList, item);
 if (context.mounted) {
 await _updateList(context, canonicalListKey, updatedList);
 }
 }
 }

 Future<void> _handleAddItem(BuildContext context, String listKey,
 String title, List<PlanningDashboardItem> currentList) async {
 final newItem = await _showItemDialog(context, title: 'Add $title Item');
 if (newItem != null) {
 final canonicalListKey = _canonicalListKey(listKey);
 _pushUndoSnapshot(canonicalListKey, currentList);

 final updatedList = List<PlanningDashboardItem>.from(currentList)
 ..add(newItem);
 if (context.mounted) {
 await _updateList(context, canonicalListKey, updatedList);
 }
 }
 }

 Future<void> _handleEditItem(
 BuildContext context,
 String listKey,
 PlanningDashboardItem item,
 List<PlanningDashboardItem> currentList) async {
 final editedItem =
 await _showItemDialog(context, title: 'Edit Item', existingItem: item);
 if (editedItem != null) {
 final updatedList = List<PlanningDashboardItem>.from(currentList);
 final itemId = item.id.trim();
 var index = itemId.isEmpty
 ? -1
 : updatedList.indexWhere((element) => element.id.trim() == itemId);
 if (index == -1) {
 final signature = _itemSignature(item);
 index = updatedList
 .indexWhere((element) => _itemSignature(element) == signature);
 }
 if (index != -1) {
 final canonicalListKey = _canonicalListKey(listKey);
 _pushUndoSnapshot(canonicalListKey, currentList);

 updatedList[index] = editedItem;
 if (context.mounted) {
 await _updateList(context, canonicalListKey, updatedList);
 }
 }
 }
 }

 Future<void> _handleGenerateGoalsAI(BuildContext context, String sectionLabel,
 String loadingKey, List<ProjectGoal> currentList) async {
 setState(() => _generatingStates[loadingKey] = true);
 try {
 final data = ProjectDataHelper.getData(context);
 final projectContext =
 ProjectDataHelper.buildFepContext(data, sectionLabel: sectionLabel);

 // Use standard planning item generation and map to goals
 final newItems = await _openAiService.generatePlanningItems(
 section: sectionLabel,
 context: projectContext,
 );

 if (!context.mounted) return;

 if (newItems.isNotEmpty) {
 final newGoals = newItems
 .map((i) => ProjectGoal(name: i.title, description: i.description))
 .toList();
 final updatedList = List<ProjectGoal>.from(currentList)
 ..addAll(newGoals);

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_summary',
 dataUpdater: (data) => data.copyWith(projectGoals: updatedList),
 );
 }
 } catch (e) {
 debugPrint('Error generating goals: $e');
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to generate goals: $e'),
 backgroundColor: Colors.red),
 );
 }
 } finally {
 if (mounted) {
 setState(() => _generatingStates[loadingKey] = false);
 }
 }
 }

 Future<void> _handleAddGoal(
 BuildContext context, String title, List<ProjectGoal> currentList) async {
 final newItem = await _showItemDialog(context, title: 'Add $title');
 if (newItem != null) {
 final updatedList = List<ProjectGoal>.from(currentList)
 ..add(
 ProjectGoal(name: newItem.title, description: newItem.description));
 if (context.mounted) {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_summary',
 dataUpdater: (data) => data.copyWith(projectGoals: updatedList),
 );
 }
 }
 }

 Future<void> _handleEditGoal(BuildContext context, ProjectGoal item,
 List<ProjectGoal> currentList) async {
 final itemAsDashboard =
 PlanningDashboardItem(title: item.name, description: item.description);
 final editedItem = await _showItemDialog(context,
 title: 'Edit Goal', existingItem: itemAsDashboard);
 if (!context.mounted) return;

 if (editedItem != null) {
 final updatedList = List<ProjectGoal>.from(currentList);
 final index = updatedList.indexOf(
 item); // ProjectGoal doesn't have ID, so use reference or index
 if (index != -1) {
 updatedList[index] = ProjectGoal(
 name: editedItem.title, description: editedItem.description);
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_summary',
 dataUpdater: (data) => data.copyWith(projectGoals: updatedList),
 );
 }
 }
 }

 Future<void> _handleDeleteGoal(BuildContext context, ProjectGoal item,
 List<ProjectGoal> currentList) async {
 final confirm = await showDeleteConfirmationDialog(
 context,
 title: 'Delete Goal?',
 itemLabel: item.name,
 );

 if (confirm == true) {
 final updatedList = List<ProjectGoal>.from(currentList)..remove(item);
 if (context.mounted) {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_summary',
 dataUpdater: (data) => data.copyWith(projectGoals: updatedList),
 );
 }
 }
 }

 // Updates the specific list in ProjectDataModel
 Future<void> _updateList(BuildContext context, String listKey,
 List<PlanningDashboardItem> newList) async {
 final canonicalListKey = _canonicalListKey(listKey);
 final normalizedList = _dedupeAndNormalizeItems(newList);

 // Map listKey to correct field update
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'fep_summary',
 dataUpdater: (data) {
 if (canonicalListKey == 'withinScopeItems') {
 return data.copyWith(withinScopeItems: normalizedList);
 } else if (canonicalListKey == 'outOfScopeItems') {
 return data.copyWith(outOfScopeItems: normalizedList);
 } else if (canonicalListKey == 'assumptionItems') {
 return data.copyWith(assumptionItems: normalizedList);
 } else if (canonicalListKey == 'constraintItems') {
 return data.copyWith(constraintItems: normalizedList);
 } else if (canonicalListKey == 'successCriteriaItems') {
 return data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 successCriteriaItems: normalizedList,
 ),
 );
 }
 return data;
 },
 );
 }

 Future<PlanningDashboardItem?> _showItemDialog(BuildContext context,
 {required String title, PlanningDashboardItem? existingItem}) {
 final titleController = TextEditingController(text: existingItem?.title);
 final descController =
 RichTextEditingController(text: existingItem?.description ?? '');

 return showDialog<PlanningDashboardItem>(
 context: context,
 builder: (context) => AlertDialog(
 title: Text(title),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Title (Optional)',
 hintText: 'e.g., Kitchen Equipment',
 ),
 textCapitalization: TextCapitalization.sentences,
 ),
 const SizedBox(height: 16),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: descController,
 decoration: const InputDecoration(
 labelText: 'Description',
 hintText: 'Enter detailed description...',
 border: OutlineInputBorder(),
 ),
 minLines: 4,
 maxLines: 8,
 textCapitalization: TextCapitalization.sentences,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (descController.text.trim().isEmpty) return;
 Navigator.pop(
 context,
 PlanningDashboardItem(
 id: existingItem?.id, // Preserve ID if editing
 title: titleController.text.trim(),
 description: descController.text.trim(),
 createdAt: existingItem?.createdAt,
 isAiGenerated: existingItem?.isAiGenerated ?? false,
 ),
 );
 },
 child: const Text('Save'),
 ),
 ],
 ),
 ).whenComplete(() {
 titleController.dispose();
 descController.dispose();
 });
 }
}

class _GoalsCard extends StatelessWidget {
 final String title;
 final String description;
 final List<ProjectGoal> items;
 final bool isGenerating;
 final VoidCallback onAdd;
 final Function(ProjectGoal) onEdit;
 final Function(ProjectGoal) onDelete;
 final VoidCallback onGenerateAI;

 const _GoalsCard({
 required this.title,
 required this.description,
 required this.items,
 required this.isGenerating,
 required this.onAdd,
 required this.onEdit,
 required this.onDelete,
 required this.onGenerateAI,
 });

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 4,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // Header
 Padding(
 padding: const EdgeInsets.all(16),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 description,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 // Quick confirm
 final confirmed =
 await showRegenerateAllConfirmation(context);
 if (confirmed) onGenerateAI();
 },
 isLoading: isGenerating,
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: onAdd,
 icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
 tooltip: 'Add Item',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 splashRadius: 20,
 ),
 ],
 ),
 ),
 const Divider(height: 1),
 // List
 if (items.isEmpty)
 Container(
 padding: const EdgeInsets.all(24),
 alignment: Alignment.center,
 child: const Text(
 'No goals added yet.\nUse + or AI to generate.',
 textAlign: TextAlign.center,
 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
 ),
 )
 else
 ListView.separated(
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 itemCount: items.length,
 separatorBuilder: (_, __) => const Divider(height: 1),
 itemBuilder: (context, index) {
 final item = items[index];
 return ListTile(
 title: Text(item.name,
 style: const TextStyle(
 fontWeight: FontWeight.w600, fontSize: 14)),
 subtitle: item.description.isNotEmpty
 ? Text(item.description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13))
 : null,
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit,
 size: 16, color: Colors.grey),
 onPressed: () => onEdit(item),
 splashRadius: 20,
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Colors.red),
 onPressed: () => onDelete(item),
 splashRadius: 20,
 ),
 ],
 ),
 );
 },
 ),
 ],
 ),
 );
 }
}

class _BottomOverlay extends StatelessWidget {
 const _BottomOverlay({
 required this.summaryController,
 required this.onNext,
 required this.nextEnabled,
 });

 final TextEditingController summaryController;
 final Future<void> Function() onNext;
 final bool nextEnabled;

 @override
 Widget build(BuildContext context) {
 return Positioned.fill(
 child: IgnorePointer(
 ignoring: false,
 child: Stack(
 children: [
 Positioned(
 left: 24,
 bottom: 24,
 child: Container(
 width: 48,
 height: 48,
 decoration: const BoxDecoration(
 color: Color(0xFFB3D9FF), shape: BoxShape.circle),
 child: const Icon(Icons.info_outline, color: Colors.white),
 ),
 ),
 Positioned(
 right: 24,
 bottom: 24,
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 16),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
 SizedBox(width: 10),
 Text('AI',
 style: TextStyle(
 fontWeight: FontWeight.w800,
 color: Color(0xFF2563EB))),
 SizedBox(width: 12),
 Text(
 'Generate a summary of all front end planning activities.',
 style: TextStyle(color: Color(0xFF1F2937)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 const KazAiChatBubble(positioned: false),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: () async {
 if (!nextEnabled) {
 final continueAnyway =
 await showProceedWithoutReviewDialog(
 context,
 title: 'Please confirm you have reviewed and understood this step',
 message:
 'You have not confirmed this page yet. You can continue now and return later to complete details, or stay and update information now.',
 );
 if (!continueAnyway || !context.mounted) return;
 }
 await onNext();
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(
 horizontal: 34, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 child: const Text('Next',
 style: TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700)),
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

Widget _formattedNotesEditor(
 {required TextEditingController controller,
 required String hint,
 int minLines = 1,
 int? maxLines,
 bool showLabel = false}) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.all(14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (showLabel)
 const Padding(
 padding: EdgeInsets.only(bottom: 8),
 child: Text(
 'NOTES',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.6,
 ),
 ),
 ),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: maxLines,
 decoration: InputDecoration(
 isDense: true,
 border: InputBorder.none,
 hintText: hint,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
 ),
 ],
 ),
 );
}
