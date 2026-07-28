import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/openai/openai_config.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/widgets/business_case_navigation_buttons.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SafeSection — Build-time error boundary that prevents a single failing child
// widget from blanking the entire page.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class SafeSection extends StatelessWidget {
 SafeSection({
 super.key,
 required this.title,
 required this.builder,
 });

 final String title;
 final WidgetBuilder builder;

 @override
 Widget build(BuildContext context) {
 Widget child;
 try {
 child = builder(context);
 } catch (error, stack) {
 debugPrint('[PotentialSolutions] Section "$title" failed: $error');
 debugPrint(stack.toString());
 return _SectionErrorCard(
 title: '$title unavailable',
 message:
 'This section encountered an error while rendering. Other parts of the page are unaffected.',
 details: error.toString(),
 );
 }
 return child;
 }
}

class _SectionErrorCard extends StatelessWidget {
 const _SectionErrorCard(
 {required this.title, required this.message, required this.details});
 final String title;
 final String message;
 final String details;

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.symmetric(vertical: 8),
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF3F2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFDA29B)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(
 color: Color(0xFFFEE4E2), shape: BoxShape.circle),
 child: const Icon(Icons.error_outline,
 color: Color(0xFFD92D20), size: 18),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFFB42318))),
 const SizedBox(height: 4),
 Text(message,
 style: const TextStyle(
 fontSize: 12.5, color: Color(0xFF667085), height: 1.5)),
 if (kDebugMode) ...[
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(6)),
 child: SelectableText(details,
 style: const TextStyle(
 fontSize: 11,fontFamily: appFontFamily,
            color: Color(0xFF475467)),
 maxLines: 4),
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class PotentialSolutionsScreen extends StatefulWidget {
 const PotentialSolutionsScreen({super.key});

 @override
 State<PotentialSolutionsScreen> createState() =>
 _PotentialSolutionsScreenState();
}

class _PotentialSolutionsScreenState extends State<PotentialSolutionsScreen> {
 static const String _notesFieldKey = 'potential_solutions_notes';

  static const List<CsvColumnSpec> _solutionCsvColumns = [
    CsvColumnSpec(
      key: 'title',
      label: 'Solution Title',
      required: true,
      sampleValue: 'Cloud Migration Platform',
    ),
    CsvColumnSpec(
      key: 'description',
      label: 'Description',
      required: true,
      sampleValue: 'Migrate on-premise infrastructure to AWS cloud services',
    ),
  ];

 // ignore: unused_field
 static const List<_SidebarItem> _sidebarItems = [
 _SidebarItem(icon: Icons.home, title: 'Home', enabled: true),
 _SidebarItem(
 icon: Icons.flag_circle_outlined,
 title: 'Initiation Phase',
 isActive: true,
 ),
 _SidebarItem(
 icon: Icons.calendar_month_outlined,
 title: 'Initiation: Front End Planning'),
 _SidebarItem(icon: Icons.device_hub_outlined, title: 'Workflow Roadmap'),
 _SidebarItem(icon: Icons.alt_route_outlined, title: 'Agile Roadmap'),
 _SidebarItem(icon: Icons.handshake_outlined, title: 'Contracting'),
 _SidebarItem(icon: Icons.shopping_cart_outlined, title: 'Procurement'),
 ];
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 final TextEditingController _notesController = RichTextEditingController();
 final ScrollController _reviewScrollController = ScrollController();
 String _incomingBusinessCase =
 ''; // Fixed: was late final, could crash with LateInitializationError
 late final TextEditingController _projectNameController;
 final List<SolutionRow> _solutions = [];
 final OpenAiServiceSecure _openAiService = OpenAiServiceSecure();
 bool _isLoadingSolutions = true;
 // ignore: unused_field
 String? _loadingError;
 // Anchor to allow sidebar sub-item to scroll to the solutions section
 final GlobalKey _solutionsSectionKey = GlobalKey();
 bool _hintShown = false;
 // Expand/collapse state to mirror Cost Analysis sidebar
 bool _initiationExpanded = true;
 bool _businessCaseExpanded = true;
 bool _frontEndExpanded = true;
 bool _reviewConfirmed = false;
 final Set<String> _expandedDescriptionRows = <String>{};

 bool get _isAdminHost => AccessPolicy.isRestrictedAdminHost();

 TextEditingController _createDescriptionController({String text = ''}) {
 return RichTextEditingController(text: text);
 }

 Future<void> _exportPdf() async {
 final notes = _notesController.text.trim();
 final solutionRows = <List<String>>[];
 for (int i = 0; i < _solutions.length; i++) {
 final solution = _solutions[i];
 final title = solution.titleController.text.trim();
 final description = solution.descriptionController.text.trim();
 solutionRows.add([
 title.isEmpty ? 'Solution ${i + 1}' : title,
 description.isEmpty ? 'No description provided.' : description,
 ]);
 }
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Potential Solutions',
 sections: [
 PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
 PdfSection.table(
 'Solutions',
 headers: ['Title', 'Description'],
 rows: solutionRows,
 ),
 ],
 );
 }

 @override
 void initState() {
 super.initState();
 _projectNameController = TextEditingController();

 // Initialize API key manager
 ApiKeyManager.initializeApiKey();

 // Load data from provider and defer generation
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;

 try {
 final projectData = ProjectDataHelper.getData(context);
 _notesController.text = projectData.notes;
 _incomingBusinessCase = projectData.businessCase;

 // Load saved solutions if they exist
 if (projectData.potentialSolutions.isNotEmpty) {
 final targetCount =
 _isAdminHost ? projectData.potentialSolutions.length : 3;
 setState(() {
 _solutions.clear();
 for (final solution
 in projectData.potentialSolutions.take(targetCount)) {
 _solutions.add(
 SolutionRow(
 id: solution.id,
 number: solution.number,
 titleController: TextEditingController(text: solution.title),
 descriptionController:
 _createDescriptionController(text: solution.description),
 isAiGenerated: true,
 ),
 );
 }
 _isLoadingSolutions = false;
 });
 _seedFieldHistories();
 } else {
 _showHintDialogOnce();
 // Auto-populate from AI: show shimmer loading state while
 // the AI generates real solutions. If the AI fails, fall back
 // to placeholder text.
 _generateInitialSolutions();
 }

 if (mounted) setState(() {});
 } catch (e) {
 debugPrint('PotentialSolutions initState error: $e');
 // Ensure page always renders, even if data loading fails
 if (mounted) {
 setState(() {
 _isLoadingSolutions = false;
 if (_solutions.isEmpty) {
 _applyFallback('Unable to load data. Add content manually.');
 }
 });
 }
 }
 });
 }

 void _showHintDialogOnce() {
 if (_hintShown) return;
 _hintShown = true;
 Future.delayed(const Duration(milliseconds: 500), () {
 if (!mounted) return;
 PageHintDialog.showIfNeeded(
 context: context,
 pageId: 'potential_solutions',
 title: 'Notification',
 message:
 'Although KAZ AI-generated outputs can provide valuable insights, please review and refine them as needed to ensure they align with your project requirements.',
 );
 });
 }

 void _seedSolutionFieldHistory(SolutionRow solution) {
 final provider = ProjectDataHelper.getProvider(context);
 provider.addFieldToHistory(
 'solution_${solution.id}_title',
 solution.titleController.text,
 isAiGenerated: true,
 );
 provider.addFieldToHistory(
 'solution_${solution.id}_description',
 solution.descriptionController.text,
 isAiGenerated: true,
 );
 }

 void _seedFieldHistories() {
 final provider = ProjectDataHelper.getProvider(context);
 provider.addFieldToHistory(
 _notesFieldKey,
 _notesController.text,
 isAiGenerated: true,
 );
 for (final solution in _solutions) {
 _seedSolutionFieldHistory(solution);
 }
 }

 void _syncDraftToProvider() {
 final provider = ProjectDataHelper.getProvider(context);
 final solutions = _solutions
 .map((s) => PotentialSolution(
 id: s.id,
 number: s.number,
 title: s.titleController.text.trim(),
 description: s.descriptionController.text.trim(),
 ))
 .toList();

 provider.updateInitiationData(
 notes: _notesController.text.trim(),
 potentialSolutions: solutions,
 );
 }

 void _recordNotesEdit(String value) {
 final provider = ProjectDataHelper.getProvider(context);
 provider.addFieldToHistory(_notesFieldKey, value, isAiGenerated: true);
 _syncDraftToProvider();
 }

 void _recordSolutionFieldEdit(
 SolutionRow solution, String fieldName, String value) {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_$fieldName';
 provider.addFieldToHistory(fieldKey, value, isAiGenerated: true);
 _syncDraftToProvider();
 }

 Future<void> _undoNotesField() async {
 final provider = ProjectDataHelper.getProvider(context);
 if (!provider.canUndoField(_notesFieldKey)) return;
 final previous = provider.projectData.undoField(_notesFieldKey);
 if (previous == null) return;
 _notesController.value = TextEditingValue(
 text: previous,
 selection: TextSelection.collapsed(offset: previous.length),
 );
 _syncDraftToProvider();
 await provider.saveToFirebase(checkpoint: 'potential_solutions_notes_undo');
 }

 Future<void> _redoNotesField() async {
 final provider = ProjectDataHelper.getProvider(context);
 if (!provider.canRedoField(_notesFieldKey)) return;
 final next = provider.projectData.redoField(_notesFieldKey);
 if (next == null) return;
 _notesController.value = TextEditingValue(
 text: next,
 selection: TextSelection.collapsed(offset: next.length),
 );
 _syncDraftToProvider();
 await provider.saveToFirebase(checkpoint: 'potential_solutions_notes_redo');
 }

 Future<void> _regenerateNotesField() async {
 if (_incomingBusinessCase.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Business case is required to regenerate notes'),
 ),
 );
 return;
 }

 final provider = ProjectDataHelper.getProvider(context);
 final contextScan = ProjectDataHelper.buildProjectContextScan(
 provider.projectData,
 sectionLabel: 'Potential Solutions Notes',
 );
 provider.addFieldToHistory(
 _notesFieldKey,
 _notesController.text,
 isAiGenerated: true,
 );

 try {
 final generated = await _openAiService.generateCompletion(
 '''
Create concise working notes for the "Potential Solutions" section.
Use the business case and current notes context below.

Business case:
${_incomingBusinessCase.trim()}

Current notes:
${_notesController.text.trim().isEmpty ? 'None' : _notesController.text.trim()}

Project context:
${contextScan.trim().isEmpty ? 'No additional project context available.' : contextScan}
''',
 maxTokens: 320,
 temperature: 0.5,
 );

 if (!mounted) return;
 final nextValue = generated.trim();
 if (nextValue.isEmpty) return;
 _notesController.value = TextEditingValue(
 text: nextValue,
 selection: TextSelection.collapsed(offset: nextValue.length),
 );
 _recordNotesEdit(nextValue);
 await provider.saveToFirebase(
 checkpoint: 'potential_solutions_notes_regenerated');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Notes regenerated successfully')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to regenerate notes: $e')),
 );
 }
 }

 Future<void> _generateInitialSolutions() async {
 // If API is not configured, skip directly to fallback
 if (!OpenAiConfig.isConfigured) {
 _applyFallback('AI service not configured. Add content manually.');
 return;
 }

 // Build the prompt context — use business case if available, otherwise
 // fall back to project name + notes + objective so the AI always has
 // something to work with.
 final projectData = ProjectDataHelper.getData(context);
 String promptContext = _incomingBusinessCase.trim();

 if (promptContext.isEmpty) {
 // Use project name, objective, and notes as context when business
 // case is empty — the AI can still generate meaningful solutions.
 final projectName = projectData.projectName.trim();
 final projectObjective = projectData.projectObjective.trim();
 final notes = projectData.notes.trim();

 final parts = <String>[];
 if (projectName.isNotEmpty) parts.add('Project: $projectName');
 if (projectObjective.isNotEmpty) parts.add('Objective: $projectObjective');
 if (notes.isNotEmpty) parts.add('Notes: $notes');

 promptContext = parts.isNotEmpty
 ? parts.join('\n')
 : 'General project delivery — suggest 3 high-level approaches.';
 }

 try {
 final aiSolutions =
 await _openAiService.generateSolutionsFromBusinessCase(
 promptContext,
 contextNotes: _buildPotentialSolutionsContext(),
 );
 _applySolutions(aiSolutions);
 } catch (e) {
 debugPrint('Error generating solutions: $e');
 _applyFallback(e.toString());
 }
 }

 String _buildPotentialSolutionsContext() {
 final data = ProjectDataHelper.getData(context);
 return ProjectDataHelper.buildProjectContextScan(
 data,
 sectionLabel: 'Potential Solutions',
 );
 }

 void _applySolutions(List<AiSolutionItem> aiSolutions) {
 final targetCount = _isAdminHost ? 5 : 3;

 setState(() {
 _solutions.clear();
 final solutionsToUse = aiSolutions.take(targetCount).toList();

 for (int i = 0; i < solutionsToUse.length; i++) {
 _solutions.add(
 SolutionRow(
 number: i + 1,
 titleController:
 TextEditingController(text: solutionsToUse[i].title),
 descriptionController: _createDescriptionController(
 text: solutionsToUse[i].description),
 isAiGenerated: true,
 ),
 );
 }
 _loadingError = null;
 _isLoadingSolutions = false;
 });
 _seedFieldHistories();
 _syncDraftToProvider();
 }

 void _applyFallback(String errorMessage) {
 final targetCount = _isAdminHost ? 5 : 3;

 setState(() {
 _loadingError = errorMessage;
 _solutions.clear();
 for (int i = 0; i < targetCount; i++) {
 _solutions.add(
 SolutionRow(
 number: i + 1,
 titleController:
 TextEditingController(text: 'Proposed Solution ${i + 1}'),
 descriptionController: _createDescriptionController(
 text:
 'Describe how this option addresses the project\'s needs, assumptions, constraints, and expected benefits.',
 ),
 isAiGenerated: true,
 ),
 );
 }
 _isLoadingSolutions = false;
 });
 _seedFieldHistories();
 _syncDraftToProvider();
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 if (isMobile) {
 return _buildMobileScaffold();
 }

 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 body: SafeArea(
 top: true,
 child: Stack(
 children: [
 Row(
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Potential Solutions',
 ),
 ),
 Expanded(
 child: Column(
 children: [
 BusinessCaseHeader(
 scaffoldKey: _scaffoldKey,
 onExportPdf: _exportPdf,
 ),
 Expanded(
 child: SafeSection(
 title: 'Potential Solutions content',
 builder: (_) => _buildMainContent(),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Potential Solutions',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 );
 }

 Widget _buildMobileScaffold() {
 final projectName = ProjectDataHelper.getData(context).projectName.trim();
 final displayCount = _isAdminHost
 ? _solutions.length
 : (_solutions.length > 3 ? 3 : _solutions.length);

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: _buildMobileDrawer(),
 floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
 floatingActionButton: FloatingActionButton(
 onPressed: _solutions.length >= 3 ? null : _addManualSolution,
 backgroundColor: const Color(0xFFFBBF24),
 foregroundColor: Colors.black,
 elevation: 0,
 child: const Icon(Icons.add),
 ),
 body: SafeArea(
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
 child: Row(
 children: [
 IconButton(
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu_rounded, size: 18),
 visualDensity: VisualDensity.compact,
 splashRadius: 18,
 ),
 const Icon(Icons.workspaces_outline,
 size: 15, color: Color(0xFFFBBF24)),
 const SizedBox(width: 8),
 const Text(
 'PROJECT WORKSPACE',
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.45,
 ),
 ),
 ],
 ),
 ),
 Padding(
 padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
 child: Row(
 children: [
 Expanded(
 child: Text(
 projectName.isEmpty ? 'Project Workspace' : projectName,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: const Color(0xFFEAFBF2),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Text(
 'INITIATION PHASE',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: Color(0xFF16A34A),
 ),
 ),
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(10, 8, 10, 96),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Potential Solutions',
 style: TextStyle(
 fontSize: 35,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 height: 1,
 ),
 ),
 const SizedBox(height: 5),
 Text(
 'List and describe up to 3 high-level solutions to achieve the project\'s needs.',
 style: TextStyle(
 fontSize: 12.5,
 color: Colors.grey.shade600,
 ),
 ),
 const SizedBox(height: 10),
 if (_isLoadingSolutions) _buildShimmerLoader(),
 if (!_isLoadingSolutions && _solutions.isEmpty)
 _buildEmptyState(),
 for (int i = 0; i < displayCount; i++) ...[
 _buildScreenshotMobileSolutionCard(_solutions[i], i),
 const SizedBox(height: 10),
 ],
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 12),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: const Color(0xFFD1D5DB),
 style: BorderStyle.solid,
 ),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.add_circle_outline,
 size: 16,
 color: _solutions.length >= 3
 ? const Color(0xFF9CA3AF)
 : const Color(0xFFD97706),
 ),
 const SizedBox(width: 6),
 Text(
 _solutions.length >= 3
 ? 'Max 3 Solutions reached'
 : 'Add another solution',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w600,
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
 child: Container(
 padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
 decoration: const BoxDecoration(
 color: Color(0xFFF3F5F9),
 border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
 ),
 child: Row(
 children: [
 Expanded(
 child: OutlinedButton(
 onPressed: _openBusinessCase,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 backgroundColor: Colors.white,
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700, fontSize: 13.5),
 ),
 child: const Text('Skip'),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: ElevatedButton(
 onPressed: _handleNextPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFBBF24),
 foregroundColor: Colors.black,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w800, fontSize: 13.5),
 ),
 child: const Text('Next'),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildScreenshotMobileSolutionCard(SolutionRow solution, int index) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 20,
 height: 20,
 decoration: const BoxDecoration(
 color: Color(0xFFE5E7EB),
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Solution #${index + 1}',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 ),
 IconButton(
 tooltip: 'Delete solution',
 onPressed: () => _confirmDeleteSolution(index),
 icon: const Icon(Icons.delete_outline_rounded, size: 16),
 visualDensity: VisualDensity.compact,
 splashRadius: 18,
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text(
 'SOLUTION TITLE',
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.3,
 ),
 ),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: solution.titleController,
 onChanged: (_) => _saveSolutions(),
 decoration: InputDecoration(
 hintText: 'Solution title',
 filled: true,
 fillColor: const Color(0xFFF3F4F6),
 isDense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide.none,
 ),
 ),
 style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 8),
 const Text(
 'DESCRIPTION',
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.3,
 ),
 ),
 const SizedBox(height: 4),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: solution.descriptionController,
 minLines: 3,
 maxLines: 5,
 onChanged: (_) => _saveSolutions(),
 decoration: InputDecoration(
 hintText: 'Describe this solution...',
 filled: true,
 fillColor: const Color(0xFFF3F4F6),
 isDense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide.none,
 ),
 ),
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF374151),
 height: 1.35,
 ),
 ),
 ],
 ),
 );
 }

 // ignore: unused_element
 Widget _buildTopHeader() {
 final isMobile = AppBreakpoints.isMobile(context);
 return Container(
 height: isMobile ? 88 : 110,
 color: Colors.white,
 padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
 child: Row(
 children: [
 // Navigation
 Row(
 children: [
 if (isMobile)
 IconButton(
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu),
 )
 else
 IconButton(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back_ios),
 color: Colors.grey[600],
 ),
 ],
 ),
 const Spacer(),
 // Page Title
 if (!isMobile)
 const Text(
 'Initiation Phase',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w500,
 color: Colors.black,
 ),
 ),
 const Spacer(),
 // User Profile
 if (!isMobile)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.grey[100],
 borderRadius: BorderRadius.circular(20),
 ),
 child: Row(
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFFBBF24),
 child: Text(
 FirebaseAuthService.displayNameOrEmail(fallback: 'U')
 .characters
 .first
 .toUpperCase(),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 14,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 FirebaseAuthService.displayNameOrEmail(
 fallback: 'User'),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 const Text(
 'Owner',
 style: TextStyle(
 fontSize: 10,
 color: Colors.grey,
 ),
 ),
 ],
 ),
 const SizedBox(width: 8),
 Icon(
 Icons.keyboard_arrow_down,
 color: Colors.grey[600],
 size: 16,
 ),
 ],
 ),
 )
 else
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFFBBF24),
 child: Text(
 FirebaseAuthService.displayNameOrEmail(fallback: 'U')
 .characters
 .first
 .toUpperCase(),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 14),
 ),
 ),
 ],
 ),
 );
 }

 // ignore: unused_element
 Widget _buildSidebar() {
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 final double bannerHeight = AppBreakpoints.isMobile(context) ? 72 : 96;
 // Match RiskIdentificationScreen sidebar styling and structure
 return Container(
 width: sidebarWidth,
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(
 right: BorderSide(color: Colors.grey.shade300, width: 1),
 ),
 ),
 child: Column(
 children: [
 // Full-width logo banner above the "StackOne" text
 SizedBox(
 width: double.infinity,
 height: bannerHeight,
 child: Center(child: AppLogo(height: 64)),
 ),
 // Header with brand divider (gold)
 Container(
 padding: const EdgeInsets.all(24),
 decoration: const BoxDecoration(
 border: Border(
 bottom: BorderSide(color: Color(0xFFFFD700), width: 1),
 ),
 ),
 child: Row(
 children: const [
 CircleAvatar(
 radius: 20,
 backgroundColor: Color(0xFFFFD700),
 child: Icon(Icons.person_outline, color: Colors.black87),
 ),
 SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('StackOne',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black)),
 ],
 )
 ],
 ),
 ),
 // Menu Items
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(vertical: 20),
 children: [
 _buildMenuItemLikeRisk(Icons.home_outlined, 'Home',
 onTap: () => HomeScreen.open(context)),
 _buildExpandableHeaderLikeCost(
 Icons.flag_outlined,
 'Initiation Phase',
 expanded: _initiationExpanded,
 onTap: () => setState(
 () => _initiationExpanded = !_initiationExpanded),
 isActive: true,
 ),
 if (_initiationExpanded) ...[
 _buildExpandableHeaderLikeCost(
 Icons.business_center_outlined,
 'Business Case',
 expanded: _businessCaseExpanded,
 onTap: () => setState(
 () => _businessCaseExpanded = !_businessCaseExpanded),
 isActive: false,
 ),
 if (_businessCaseExpanded) ...[
 _buildNestedSubMenuItem('Potential Solutions',
 onTap: _scrollToSolutions, isActive: true),
 _buildNestedSubMenuItem('Risk Identification',
 onTap: _openRiskIdentification),
 _buildNestedSubMenuItem('IT Considerations',
 onTap: _openITConsiderations),
 _buildNestedSubMenuItem('Infrastructure Considerations',
 onTap: _openInfrastructureConsiderations),
 _buildNestedSubMenuItem('Core Stakeholders',
 onTap: _openCoreStakeholders),
 _buildNestedSubMenuItem(
 'Initial Cost Estimate',
 onTap: _openCostAnalysis),
 _buildNestedSubMenuItem('Preferred Solution Analysis',
 onTap: _openPreferredSolutionAnalysis),
 ],
 _buildExpandableHeaderLikeCost(
 Icons.timeline, 'Initiation: Front End Planning',
 expanded: _frontEndExpanded, onTap: () {
 setState(() => _frontEndExpanded = !_frontEndExpanded);
 }, isActive: false),
 if (_frontEndExpanded) ...[
 _buildNestedSubMenuItem('Project Requirements'),
 _buildNestedSubMenuItem('Project Risks'),
 _buildNestedSubMenuItem('Project Opportunities'),
 ],
 ],
 _buildMenuItemLikeRisk(
 Icons.account_tree_outlined, 'Workflow Roadmap'),
 _buildMenuItemLikeRisk(Icons.flash_on, 'Agile Roadmap'),
 _buildMenuItemLikeRisk(
 Icons.description_outlined, 'Contracting'),
 _buildMenuItemLikeRisk(
 Icons.shopping_cart_outlined, 'Procurement'),
 const SizedBox(height: 20),
 _buildMenuItemLikeRisk(Icons.settings_outlined, 'Settings',
 onTap: () => SettingsScreen.open(context)),
 _buildMenuItemLikeRisk(Icons.logout_outlined, 'LogOut',
 onTap: () => AuthNav.signOutAndExit(context)),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Drawer _buildMobileDrawer() {
 return Drawer(
 width: MediaQuery.sizeOf(context).width * 0.88,
 child: const SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Potential Solutions',
 ),
 ),
 );
 }

 // Sidebar tile that mimics RiskIdentificationScreen's _buildMenuItem
 Widget _buildMenuItemLikeRisk(IconData icon, String title,
 {VoidCallback? onTap, bool isActive = false}) {
 final primary = Theme.of(context).colorScheme.primary;
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
 child: InkWell(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(icon, size: 20, color: isActive ? primary : Colors.black87),
 const SizedBox(width: 16),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 14,
 color: isActive ? primary : Colors.black87,
 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
 ),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ignore: unused_element
 Widget _buildSubMenuItemLikeRisk(String title,
 {VoidCallback? onTap, bool isActive = false}) {
 final primary = Theme.of(context).colorScheme.primary;
 return Padding(
 padding: const EdgeInsets.only(left: 48, right: 24, top: 2, bottom: 2),
 child: InkWell(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(Icons.circle,
 size: 8, color: isActive ? primary : Colors.grey[500]),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 13,
 color: isActive ? primary : Colors.black87,
 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // Third-level nested menu item (under Business Case)
 Widget _buildNestedSubMenuItem(String title,
 {VoidCallback? onTap, bool isActive = false}) {
 final primary = Theme.of(context).colorScheme.primary;
 return Padding(
 padding: const EdgeInsets.only(left: 72, right: 24, top: 2, bottom: 2),
 child: InkWell(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(Icons.circle,
 size: 6, color: isActive ? primary : Colors.grey[400]),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 12,
 color: isActive ? primary : Colors.black87,
 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // Expandable header matching Cost Analysis look and behavior
 Widget _buildExpandableHeaderLikeCost(IconData icon, String title,
 {required bool expanded,
 required VoidCallback onTap,
 bool isActive = false}) {
 final primary = Theme.of(context).colorScheme.primary;
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
 child: InkWell(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(icon, size: 20, color: isActive ? primary : Colors.black87),
 const SizedBox(width: 16),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 14,
 color: isActive ? primary : Colors.black87,
 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
 ),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 Icon(
 expanded
 ? Icons.keyboard_arrow_up
 : Icons.keyboard_arrow_down,
 color: Colors.grey[700],
 size: 20),
 ],
 ),
 ),
 ),
 );
 }

 // ignore: unused_element
 void _openBusinessCase() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const InitiationPhaseScreen(scrollToBusinessCase: true),
 ),
 );
 }

 List<AiSolutionItem> _collectSolutions() {
 return _solutions
 .map((s) => AiSolutionItem(
 title: s.titleController.text.trim(),
 description: s.descriptionController.text.trim(),
 ))
 .where((item) => item.title.isNotEmpty || item.description.isNotEmpty)
 .toList();
 }

 void _openRiskIdentification() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => RiskIdentificationScreen(
 notes: notes,
 solutions: solutions,
 businessCase: _incomingBusinessCase,
 ),
 ),
 );
 }

 void _openITConsiderations() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => ITConsiderationsScreen(
 notes: notes,
 solutions: solutions,
 ),
 ),
 );
 }

 void _openInfrastructureConsiderations() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => InfrastructureConsiderationsScreen(
 notes: notes,
 solutions: solutions,
 ),
 ),
 );
 }

 void _openCoreStakeholders() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CoreStakeholdersScreen(
 notes: notes,
 solutions: solutions,
 ),
 ),
 );
 }

 void _openCostAnalysis() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CostAnalysisScreen(
 notes: notes,
 solutions: solutions,
 ),
 ),
 );
 }

 void _openPreferredSolutionAnalysis() {
 final notes = _notesController.text.trim();
 final solutions = _collectSolutions();
 final businessCase = _incomingBusinessCase.trim();
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => PreferredSolutionAnalysisScreen(
 notes: notes,
 solutions: solutions,
 businessCase: businessCase,
 ),
 ),
 );
 }

 void _scrollToSolutions() {
 final ctx = _solutionsSectionKey.currentContext;
 if (ctx != null) {
 Scrollable.ensureVisible(
 ctx,
 duration: const Duration(milliseconds: 400),
 curve: Curves.easeOutCubic,
 alignment: 0.1,
 );
 }
 }

 // ignore: unused_element
 void _handleMenuTap(String title) {
 if (title == 'Home') {
 HomeScreen.open(context);
 } else if (title == 'LogOut') {
 AuthNav.signOutAndExit(context);
 }
 }

 Widget _buildMainContent() {
 try {
 final pagePadding = AppBreakpoints.pagePadding(context);
 final sectionGap = AppBreakpoints.sectionGap(context);
 final fieldGap = AppBreakpoints.fieldGap(context);
 final provider = ProjectDataHelper.getProvider(context);
 final canUndoNotes = provider.canUndoField(_notesFieldKey);
 final canRedoNotes = provider.canRedoField(_notesFieldKey);

 return LayoutBuilder(
 builder: (context, constraints) {
 return ScrollIndicatorOverlay(
 controller: _reviewScrollController,
 child: SingleChildScrollView(
 controller: _reviewScrollController,
 padding: EdgeInsets.all(pagePadding),
 child: ConstrainedBox(
 constraints: BoxConstraints(minHeight: constraints.maxHeight),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const EditableContentText(
 contentKey: 'potential_solutions_phase_title',
 fallback: 'Potential Solutions',
 category: 'business_case',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.bold,
 color: Colors.black,
 ),
 ),
 SizedBox(height: sectionGap),
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0D000000),
 blurRadius: 10,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
 child: const Text(
 'Notes',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 child: Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border:
 Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 HoverableFieldControls(
 isAiGenerated: true,
 isLoading: false,
 canUndo: canUndoNotes,
 canRedo: canRedoNotes,
 onUndo: _undoNotesField,
 onRedo: _redoNotesField,
 onRegenerate: _regenerateNotesField,
 child: Container(
 width: double.infinity,
 constraints:
 const BoxConstraints(minHeight: 160),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE4E7EC),
 ),
 ),
 child: VoiceTextField(
 controller: _notesController,
 keyboardType: TextInputType.multiline,
 style: const TextStyle(
 fontSize: 14,
 color: Colors.black87,
 ),
 decoration: const InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 hintText: 'Input your notes here...',
 hintStyle: TextStyle(
 color: Color(0xFF9CA3AF),
 ),
 ),
 minLines: 5,
 maxLines: null,
 onChanged: _recordNotesEdit,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 SizedBox(height: sectionGap),
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 EditableContentText(
 contentKey: 'potential_solutions_heading',
 fallback: 'Potential Solution(s)',
 category: 'business_case',
 key: _solutionsSectionKey,
 style: const TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.bold,
 color: Colors.black,
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: EditableContentText(
 contentKey: 'potential_solutions_description',
 fallback: AccessPolicy.isRestrictedAdminHost()
 ? '(5 KAZ AI-generated solutions)'
 : "(Describe 1 to 3 high level solutions to achieve the project's needs)",
 category: 'business_case',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 const SizedBox(width: 12),
 _buildRegenerateButton(),
 ],
 ),
 SizedBox(height: fieldGap),
 _buildSolutionsSection(),
 if (_solutions.length < 3 && !_isLoadingSolutions) ...[
 const SizedBox(height: 16),
        Row(
              children: [
                CsvTableImportButton(
                  tableTitle: 'Potential Solutions',
                  columns: _solutionCsvColumns,
                  onImport: (rows) => _handleSolutionCsvImport(rows),
                  compact: true,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isLoadingSolutions ? null : _addManualSolution,
                  icon: const Icon(Icons.add),
                  label: Text('Add Solution (${_solutions.length}/3)'),
                ),
              ],
            ),
 ],
 const SizedBox(height: 24),
 BusinessCaseNavigationButtons(
 currentScreen: 'Potential Solutions',
 padding: const EdgeInsets.symmetric(
 horizontal: 0, vertical: 24),
 onNext: _handleNextPressed,
 isNextEnabled: _reviewConfirmed,
 showReviewGate: true,
 reviewConfirmed: _reviewConfirmed,
 onReviewChanged: (value) {
 setState(() => _reviewConfirmed = value);
 },
 reviewScrollController: _reviewScrollController,
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 } catch (e) {
 debugPrint('PotentialSolutions _buildMainContent error: $e');
 return SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Potential Solutions',
 style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 const Text(
 'List and describe up to 3 high-level solutions to achieve the project\'s needs.',
 style: TextStyle(fontSize: 13, color: Colors.grey),
 ),
 const SizedBox(height: 24),
 if (_isLoadingSolutions)
 const Center(child: CircularProgressIndicator())
 else if (_solutions.isEmpty)
 const Text(
 'No solutions yet. Add one manually or try regenerating.')
 else
 ..._solutions.map(
 (s) => Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: TextField(
 controller: s.titleController,
 decoration: const InputDecoration(
 labelText: 'Solution Title',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ),
 const SizedBox(height: 16),
 OutlinedButton.icon(
 onPressed: _addManualSolution,
 icon: const Icon(Icons.add),
 label: Text('Add Solution (${_solutions.length}/3)'),
 ),
 ],
 ),
 );
 }
 }

 /// Blue circular refresh button used to regenerate all solutions.
 Widget _buildRegenerateButton() {
 final isDisabled = _isLoadingSolutions;
 return Tooltip(
 message: 'Regenerate all solutions',
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 borderRadius: BorderRadius.circular(20),
 onTap: isDisabled ? null : _confirmRegenerateAll,
 child: Opacity(
 opacity: isDisabled ? 0.5 : 1.0,
 child: Container(
 width: 36,
 height: 36,
 decoration: const BoxDecoration(
 color: Color(0xFFD97706),
 shape: BoxShape.circle,
 ),
 child: const Icon(
 Icons.refresh,
 size: 18,
 color: Colors.white,
 ),
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildSolutionsSection() {
 if (_isLoadingSolutions) {
 return _buildShimmerLoader();
 }

 if (_solutions.isEmpty) {
 return _buildEmptyState();
 }

 if (AppBreakpoints.isMobile(context)) {
 final displayCount = _isAdminHost
 ? _solutions.length
 : (_solutions.length > 3 ? 3 : _solutions.length);
 return Column(
 children: [
 for (int i = 0; i < displayCount; i++)
 _buildSolutionCardMobile(_solutions[i], i),
 ],
 );
 }

 return _buildDesktopSolutionsTable();
 }

 Widget _buildDesktopSolutionsTable() {
 final displayCount = _isAdminHost
 ? _solutions.length
 : (_solutions.length > 3 ? 3 : _solutions.length);
 final showDeleteColumn = _solutions.length > 1;
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 clipBehavior: Clip.antiAlias,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // Header row — light gray background with centered column titles.
 Container(
 color: const Color(0xFFF5F7FB),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(
 children: [
 // Spacer matching the number badge column.
 const SizedBox(width: 32, height: 20),
 const SizedBox(width: 12),
 const Expanded(
 flex: 3,
 child: Center(
 child: Text(
 'Solution Title',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475467),
 ),
 ),
 ),
 ),
 const SizedBox(width: 16),
 const Expanded(
 flex: 5,
 child: Center(
 child: Text(
 'Description',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475467),
 ),
 ),
 ),
 ),
 SizedBox(width: showDeleteColumn ? 48 : 0, height: 20),
 ],
 ),
 ),
 // Solution rows separated by thin gray divider lines.
 for (int i = 0; i < displayCount; i++)
 _buildSolutionRow(
 _solutions[i],
 index: i,
 isLast: i == displayCount - 1,
 showDelete: showDeleteColumn,
 ),
 ],
 ),
 );
 }

 Widget _buildShimmerLoader() {
 return Shimmer.fromColors(
 baseColor: Colors.grey[300]!,
 highlightColor: Colors.grey[100]!,
 child: Column(
 children: List.generate(3, (index) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
 decoration: BoxDecoration(
 border: Border(
 bottom: BorderSide(color: Colors.grey.shade300),
 ),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 2,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 width: 120,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 20),
 Expanded(
 flex: 5,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 width: 200,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 ),
 );
 }

 Widget _buildEmptyState() {
 return Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.lightbulb_outline, size: 40, color: Colors.grey),
 const SizedBox(height: 8),
 const Text(
 'No solutions yet',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 6),
 const Text(
 'Add your own or let AI suggest options.',
 style: TextStyle(fontSize: 12, color: Colors.grey),
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 children: [
 FilledButton.icon(
 onPressed: _isLoadingSolutions
 ? null
 : () {
 setState(() {
 _loadingError = null;
 _isLoadingSolutions = true;
 });
 _generateInitialSolutions();
 },
 icon: const Icon(Icons.auto_awesome),
 label: const Text('Generate with AI'),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildSolutionRow(SolutionRow solution,
 {required int index, bool isLast = false, bool showDelete = true}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 border: isLast
 ? null
 : const Border(
 bottom: BorderSide(color: Color(0xFFE4E7EC), width: 1),
 ),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Number badge — small gray square with the row number.
 Container(
 width: 32,
 height: 32,
 alignment: Alignment.center,
 decoration: BoxDecoration(
 color: const Color(0xFFE0E0E0),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 const SizedBox(width: 12),
 // Solution Title input cell.
 Expanded(
 flex: 3,
 child: _buildTitleCell(solution),
 ),
 const SizedBox(width: 16),
 // Description input cell (toolbar + textarea).
 Expanded(
 flex: 5,
 child: _buildDescriptionCell(solution),
 ),
 if (showDelete) ...[
 const SizedBox(width: 8),
 SizedBox(
 width: 40,
 child: IconButton(
 tooltip: 'Delete solution',
 onPressed: () => _confirmDeleteSolution(index),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
 icon: const Icon(
 Icons.delete_outline,
 color: Color(0xFFEF4444),
 size: 22,
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 /// Light-gray Solution Title input cell with a [VoiceTextField] bound to
 /// the solution's [SolutionRow.titleController]. Wrapped in
 /// [HoverableFieldControls] so undo/redo/regenerate stay available.
 Widget _buildTitleCell(SolutionRow solution) {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_title';
 final canUndo = provider.canUndoField(fieldKey);
 final canRedo = provider.canRedoField(fieldKey);
 return HoverableFieldControls(
 isAiGenerated: true,
 isLoading: false,
 canUndo: canUndo,
 canRedo: canRedo,
 onRegenerate: () => _regenerateSolutionField(solution, 'title'),
 onUndo: () => _undoSolutionField(solution, 'title'),
 onRedo: () => _redoSolutionField(solution, 'title'),
 child: Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF8F8F8),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: VoiceTextField(
 controller: solution.titleController,
 style: const TextStyle(fontSize: 14, color: Colors.black87),
 decoration: const InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 hintText: 'Enter solution title',
 hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
 ),
 minLines: 1,
 maxLines: 2,
 onChanged: (value) =>
 _recordSolutionFieldEdit(solution, 'title', value),
 ),
 ),
 );
 }

 /// Light-blue Description input cell with a [TextFormattingToolbar] above a
 /// multiline [VoiceTextField] bound to [SolutionRow.descriptionController].
 /// Wrapped in [HoverableFieldControls] for undo/redo/regenerate.
 Widget _buildDescriptionCell(SolutionRow solution) {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_description';
 final canUndo = provider.canUndoField(fieldKey);
 final canRedo = provider.canRedoField(fieldKey);
 return HoverableFieldControls(
 isAiGenerated: true,
 isLoading: false,
 canUndo: canUndo,
 canRedo: canRedo,
 onRegenerate: () => _regenerateSolutionField(solution, 'description'),
 onUndo: () => _undoSolutionField(solution, 'description'),
 onRedo: () => _redoSolutionField(solution, 'description'),
 child: Container(
 decoration: BoxDecoration(
 color: const Color(0xFFF0F4FF),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 mainAxisSize: MainAxisSize.min,
 children: [
 const SizedBox(height: 6),
 VoiceTextField(
 controller: solution.descriptionController,
 style: const TextStyle(fontSize: 14, color: Colors.black87),
 decoration: const InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 hintText: 'Describe the solution...',
 hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
 ),
 minLines: 3,
 maxLines: null,
 onChanged: (value) =>
 _recordSolutionFieldEdit(solution, 'description', value),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildSolutionCardMobile(SolutionRow solution, int index) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: Colors.grey.shade300,
 width: 1,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Solution ${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Colors.black54)),
 IconButton(
 tooltip: 'Delete solution',
 onPressed: () => _confirmDeleteSolution(index),
 icon: const Icon(Icons.delete_outline,
 size: 20, color: Colors.redAccent),
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text('Solution Title',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 const SizedBox(height: 6),
 _buildFieldWithControls(
 solution: solution,
 fieldName: 'title',
 controller: solution.titleController,
 hintText: 'Solution title',
 isMobile: true,
 ),
 const SizedBox(height: 10),
 const Text('Description',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 const SizedBox(height: 6),
 _buildFieldWithControls(
 solution: solution,
 fieldName: 'description',
 controller: solution.descriptionController,
 hintText: 'Solution description',
 isMobile: true,
 ),
 ],
 ),
 );
 }

 Future<void> _handleNextPressed() async {
 if (_isLoadingSolutions) return;

 final trimmedNotes = _notesController.text.trim();
 final solutions = _solutions
 .map(
 (s) => AiSolutionItem(
 title: s.titleController.text.trim(),
 description: s.descriptionController.text.trim(),
 ),
 )
 .where((item) => item.title.isNotEmpty || item.description.isNotEmpty)
 .toList();

 if (solutions.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Continuing without saved solution options. You can add them later or let AI generate them.',
 ),
 ),
 );
 }

 FocusScope.of(context).unfocus();

 // Save solutions to provider
 final provider = ProjectDataHelper.getProvider(context);
 final rowsToPersist =
 _isAdminHost ? _solutions : _solutions.take(3).toList();
 final potentialSolutions = rowsToPersist
 .map(
 (s) => PotentialSolution(
 id: s.id,
 number: s.number,
 title: s.titleController.text.trim(),
 description: s.descriptionController.text.trim(),
 ),
 )
 .toList();

 provider.updateInitiationData(
 notes: trimmedNotes,
 potentialSolutions: potentialSolutions,
 );

 // Save to Firebase
 await provider.saveToFirebase(checkpoint: 'potential_solutions');

 // Show 3-second loading dialog
 if (!mounted) return;
 await showDialog<void>(
 context: context,
 barrierDismissible: false,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (_) => const _LoadingDialog(),
 );

 if (!mounted) return;

 // Navigate to Risk Identification
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => RiskIdentificationScreen(
 notes: trimmedNotes,
 solutions: solutions,
 businessCase: _incomingBusinessCase,
 ),
 ),
 );
 }

 @override
 void dispose() {
 _notesController.dispose();
 _reviewScrollController.dispose();
 _projectNameController.dispose();
 for (var solution in _solutions) {
 solution.titleController.dispose();
 solution.descriptionController.dispose();
 }
 super.dispose();
 }

 Future<void> _addManualSolution() async {
 if (_solutions.length >= 3) return;

 late final SolutionRow created;
 setState(() {
 created = SolutionRow(
 number: _solutions.length + 1,
 titleController: TextEditingController(),
 descriptionController: _createDescriptionController(),
 isAiGenerated: false,
 );
 _solutions.add(created);
 });
 _seedSolutionFieldHistory(created);
 _syncDraftToProvider();

 // Auto-focus on first field of new solution
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted && _solutions.isNotEmpty) {
 final lastSolution = _solutions.last;
 FocusScope.of(context).requestFocus(FocusNode());
 Future.delayed(const Duration(milliseconds: 100), () {
 if (mounted) {
 lastSolution.titleController.selection = TextSelection.collapsed(
 offset: lastSolution.titleController.text.length,
 );
 }
 });
 }
 });

 // Auto-save empty solution to Firebase
 await _saveSolutions();
 }

 Future<void> _confirmDeleteSolution(int index) async {
 if (index < 0 || index >= _solutions.length) return;

 final solutionTitle = _solutions[index].titleController.text.trim();
 final confirmed = await showDeleteConfirmationDialog(
 context,
 title: 'Delete Solution?',
 itemLabel: solutionTitle.isEmpty
 ? 'Potential Solution ${index + 1}'
 : solutionTitle,
 );

 if (confirmed == true && mounted) {
 final row = _solutions.removeAt(index);
 _expandedDescriptionRows.remove(row.id);
 row.titleController.dispose();
 row.descriptionController.dispose();

 // Renumber remaining solutions
 for (int i = 0; i < _solutions.length; i++) {
 _solutions[i].number = i + 1;
 }

 setState(() {});
 await _saveSolutions();

 }
 }

  void _handleSolutionCsvImport(List<Map<String, String>> rows) {
    if (_solutions.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 solutions allowed. Please delete one first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    int imported = 0;
    for (final row in rows) {
      if (_solutions.length >= 3) break;
      final title = row['title'] ?? '';
      final description = row['description'] ?? '';
      if (title.trim().isEmpty && description.trim().isEmpty) continue;
      final created = SolutionRow(
        number: _solutions.length + 1,
        titleController: TextEditingController(text: title),
        descriptionController: _createDescriptionController(text: description),
        isAiGenerated: false,
      );
      _seedSolutionFieldHistory(created);
      _solutions.add(created);
      imported++;
    }
    _syncDraftToProvider();
    setState(() {});
    _saveSolutions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $imported solution${imported == 1 ? '' : 's'}'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

 Future<void> _saveSolutions() async {
 final provider = ProjectDataHelper.getProvider(context);
 _syncDraftToProvider();
 await provider.saveToFirebase(checkpoint: 'potential_solutions');
 }

 Future<void> _confirmRegenerateAll() async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Regenerate All Solutions'),
 content: const Text(
 'This will regenerate all KAZ AI-generated solutions on this page. Your current content will be lost. Continue?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () => Navigator.of(context).pop(true),
 child: const Text('Regenerate All'),
 ),
 ],
 ),
 );

 if (confirmed == true && mounted) {
 await _regenerateAllSolutions();
 }
 }

 Future<void> _regenerateAllSolutions() async {
 if (_incomingBusinessCase.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Business case is required to regenerate solutions')),
 );
 return;
 }

 final messenger = ScaffoldMessenger.of(context);
 setState(() => _isLoadingSolutions = true);

 try {
 final aiSolutions =
 await _openAiService.generateSolutionsFromBusinessCase(
 _incomingBusinessCase,
 contextNotes: _buildPotentialSolutionsContext(),
 );
 final targetCount = _isAdminHost ? 5 : 3;

 setState(() {
 // Dispose old controllers
 for (final solution in _solutions) {
 solution.titleController.dispose();
 solution.descriptionController.dispose();
 }

 _solutions.clear();
 _expandedDescriptionRows.clear();
 final solutionsToUse = aiSolutions.take(targetCount).toList();

 for (int i = 0; i < solutionsToUse.length; i++) {
 _solutions.add(
 SolutionRow(
 number: i + 1,
 titleController:
 TextEditingController(text: solutionsToUse[i].title),
 descriptionController: _createDescriptionController(
 text: solutionsToUse[i].description,
 ),
 isAiGenerated: true,
 ),
 );
 }
 _isLoadingSolutions = false;
 });
 _seedFieldHistories();

 await _saveSolutions();

 if (!mounted) return;
 messenger.showSnackBar(
 const SnackBar(content: Text('All solutions regenerated successfully')),
 );
 } catch (e) {
 if (!mounted) return;
 setState(() => _isLoadingSolutions = false);
 messenger.showSnackBar(
 SnackBar(content: Text('Failed to regenerate solutions: $e')),
 );
 }
 }

 Future<void> _regenerateSolutionField(
 SolutionRow solution, String fieldName) async {
 if (_incomingBusinessCase.trim().isEmpty) return;

 final provider = ProjectDataHelper.getProvider(context);
 final messenger = ScaffoldMessenger.of(context);

 try {
 final generated = await _openAiService.generateSolutionsFromBusinessCase(
 _incomingBusinessCase,
 contextNotes: _buildPotentialSolutionsContext(),
 );
 final rowIndex = _solutions.indexOf(solution);
 if (generated.isEmpty || rowIndex < 0) return;
 final source =
 rowIndex < generated.length ? generated[rowIndex] : generated.first;
 final newValue = fieldName == 'title' ? source.title : source.description;

 // Add to history
 final fieldKey = 'solution_${solution.id}_$fieldName';
 provider.addFieldToHistory(
 fieldKey,
 fieldName == 'title'
 ? solution.titleController.text
 : solution.descriptionController.text,
 isAiGenerated: true);

 // Update field
 if (fieldName == 'title') {
 solution.titleController.text = newValue;
 } else {
 solution.descriptionController.text = newValue;
 }

 _syncDraftToProvider();
 await _saveSolutions();

 if (!mounted) return;
 messenger.showSnackBar(
 const SnackBar(content: Text('Field regenerated successfully')),
 );
 } catch (e) {
 if (!mounted) return;
 messenger.showSnackBar(
 SnackBar(content: Text('Failed to regenerate field: $e')));
 }
 }

 Future<void> _undoSolutionField(
 SolutionRow solution, String fieldName) async {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_$fieldName';

 if (provider.canUndoField(fieldKey)) {
 final previousValue = provider.projectData.undoField(fieldKey);
 if (previousValue != null) {
 if (fieldName == 'title') {
 solution.titleController.text = previousValue;
 } else {
 solution.descriptionController.text = previousValue;
 }
 _syncDraftToProvider();
 await _saveSolutions();

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Undo successful')),
 );
 }
 }
 }
 }

 Future<void> _redoSolutionField(
 SolutionRow solution, String fieldName) async {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_$fieldName';

 if (provider.canRedoField(fieldKey)) {
 final nextValue = provider.projectData.redoField(fieldKey);
 if (nextValue != null) {
 if (fieldName == 'title') {
 solution.titleController.text = nextValue;
 } else {
 solution.descriptionController.text = nextValue;
 }
 _syncDraftToProvider();
 await _saveSolutions();

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Redo successful')),
 );
 }
 }
 }
 }

 Widget _buildFieldWithControls({
 required SolutionRow solution,
 required String fieldName,
 required TextEditingController controller,
 required String hintText,
 bool isMobile = false,
 }) {
 final provider = ProjectDataHelper.getProvider(context);
 final fieldKey = 'solution_${solution.id}_$fieldName';
 final canUndo = provider.canUndoField(fieldKey);
 final canRedo = provider.canRedoField(fieldKey);
 final isDescriptionField = fieldName == 'description';
 final isDescriptionExpanded =
 _expandedDescriptionRows.contains(solution.id);
 final canToggleDescription =
 isDescriptionField && _shouldShowDescriptionToggle(controller.text);

 return HoverableFieldControls(
 isAiGenerated: true,
 isLoading: false,
 canUndo: canUndo,
 canRedo: canRedo,
 onRegenerate: () => _regenerateSolutionField(solution, fieldName),
 onUndo: () => _undoSolutionField(solution, fieldName),
 onRedo: () => _redoSolutionField(solution, fieldName),
 child: isDescriptionField
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 const SizedBox(height: 6),
 if (isMobile)
 VoiceTextField(
 controller: controller,
 decoration: InputDecoration(
 hintText: hintText,
 border: const OutlineInputBorder(),
 isDense: true,
 ),
 style: const TextStyle(fontSize: 14),
 minLines: 2,
 maxLines: 5,
 onChanged: (value) {
 _recordSolutionFieldEdit(solution, fieldName, value);
 },
 )
 else
 VoiceTextField(
 controller: controller,
 style: const TextStyle(
 fontSize: 14,
 color: Colors.grey,
 ),
 decoration: const InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 ).copyWith(hintText: hintText),
 minLines: isDescriptionExpanded ? 4 : 2,
 maxLines: isDescriptionExpanded ? 12 : 4,
 onChanged: (value) {
 _recordSolutionFieldEdit(solution, fieldName, value);
 final shouldShowToggle =
 _shouldShowDescriptionToggle(value);
 if (shouldShowToggle != canToggleDescription) {
 setState(() {});
 }
 if (_expandedDescriptionRows.contains(solution.id) &&
 !shouldShowToggle) {
 setState(() {
 _expandedDescriptionRows.remove(solution.id);
 });
 }
 },
 ),
 if (!isMobile && canToggleDescription)
 Align(
 alignment: Alignment.centerRight,
 child: TextButton(
 onPressed: () => _toggleDescriptionExpansion(solution.id),
 style: TextButton.styleFrom(
 visualDensity: VisualDensity.compact,
 minimumSize: const Size(0, 28),
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 padding: const EdgeInsets.symmetric(
 horizontal: 8,
 vertical: 2,
 ),
 ),
 child: Text(
 isDescriptionExpanded ? 'Show less' : 'Show more',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ),
 ],
 )
 : isMobile
 ? VoiceTextField(
 controller: controller,
 decoration: InputDecoration(
 hintText: hintText,
 border: const OutlineInputBorder(),
 isDense: true,
 ),
 style: const TextStyle(fontSize: 14),
 minLines: 1,
 maxLines: 1,
 onChanged: (value) =>
 _recordSolutionFieldEdit(solution, fieldName, value),
 )
 : VoiceTextField(
 controller: controller,
 style: const TextStyle(
 fontSize: 14,
 color: Colors.black87,
 ),
 decoration: const InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 ).copyWith(hintText: hintText),
 minLines: 1,
 maxLines: 2,
 onChanged: (value) {
 _recordSolutionFieldEdit(solution, fieldName, value);
 },
 ),
 );
 }

 bool _shouldShowDescriptionToggle(String value) {
 final trimmed = value.trim();
 if (trimmed.isEmpty) {
 return false;
 }
 if (trimmed.length > 260) {
 return true;
 }
 final lines = '\n'.allMatches(trimmed).length + 1;
 return lines > 4;
 }

 void _toggleDescriptionExpansion(String solutionId) {
 setState(() {
 if (_expandedDescriptionRows.contains(solutionId)) {
 _expandedDescriptionRows.remove(solutionId);
 } else {
 _expandedDescriptionRows.add(solutionId);
 }
 });
 }
}

class SolutionRow {
 final String id;
 int number;
 final TextEditingController titleController;
 final TextEditingController descriptionController;
 final bool isAiGenerated;

 SolutionRow({
 String? id,
 required this.number,
 required this.titleController,
 required this.descriptionController,
 this.isAiGenerated = false,
 }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class _SidebarItem {
 final IconData icon;
 final String title;
 final bool enabled;
 final bool isActive;

 const _SidebarItem({
 required this.icon,
 required this.title,
 this.enabled = false,
 this.isActive = false,
 });
}

class _LoadingDialog extends StatefulWidget {
 const _LoadingDialog();

 @override
 State<_LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<_LoadingDialog>
 with SingleTickerProviderStateMixin {
 late final AnimationController _controller;

 @override
 void initState() {
 super.initState();
 _controller = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1200),
 )..repeat();

 // Auto-dismiss after 3 seconds
 Future.delayed(const Duration(seconds: 3), () {
 if (mounted) Navigator.of(context).pop();
 });
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Dialog(
 backgroundColor: Colors.transparent,
 elevation: 0,
 child: Center(
 child: Container(
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 boxShadow: const [
 BoxShadow(
 color: Color(0x22000000),
 blurRadius: 20,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 RotationTransition(
 turns: _controller,
 child: const Icon(
 Icons.sync,
 color: Color(0xFFFFD700),
 size: 48,
 ),
 ),
 const SizedBox(height: 20),
 const Text(
 'Saving Solutions...',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Preparing data for next phase',
 style: TextStyle(
 fontSize: 14,
 color: Colors.black54,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}
