import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart'; // provides AiSolutionItem model
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/widgets/business_case_navigation_buttons.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// Removed AppLogo from the top header for this screen per request
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

enum _MissingInfrastructureAction { manual, autoFill, skip }

class _InfrastructureAutoFillPreviewRow {
 const _InfrastructureAutoFillPreviewRow({
 required this.title,
 required this.items,
 });

 final String title;
 final List<String> items;
}

class InfrastructureConsiderationsScreen extends StatefulWidget {
 final String notes;
 final List<AiSolutionItem> solutions;
 const InfrastructureConsiderationsScreen(
 {super.key, required this.notes, required this.solutions});

 @override
 State<InfrastructureConsiderationsScreen> createState() =>
 _InfrastructureConsiderationsScreenState();
}

class _InfrastructureConsiderationsScreenState
 extends State<InfrastructureConsiderationsScreen> {
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 final ScrollController _reviewScrollController = ScrollController();
 late final TextEditingController _notesController;
 late List<TextEditingController>
 _infraControllers; // Made mutable for dynamic addition
 late final List<AiSolutionItem> _solutions; // Local mutable list
 bool _initiationExpanded = true;
 bool _businessCaseExpanded = true;
 bool _isAdmin = false;
 bool get _canUseAdminControls =>
 _isAdmin && AccessPolicy.isRestrictedAdminHost();
 final OpenAiServiceSecure _openAi = OpenAiServiceSecure();
 bool _isGeneratingInfra = false;
 bool _reviewConfirmed = false;

 void _addNewItem() {
 if (!_canUseAdminControls) return;
 setState(() {
 _solutions.add(AiSolutionItem(title: '', description: ''));
 _infraControllers.add(RichTextEditingController());
 });
 }

 Future<void> _exportPdf() async {
 final notes = _notesController.text.trim();
 final infraRows = <List<String>>[];
 for (int i = 0; i < _solutions.length && i < _infraControllers.length; i++) {
 final title = _solutions[i].title.trim().isEmpty
 ? 'Solution ${i + 1}'
 : _solutions[i].title.trim();
 final infra = _infraControllers[i].text.trim();
 infraRows.add([title, infra.isEmpty ? 'No data recorded.' : infra]);
 }
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Infrastructure Considerations',
 sections: [
 PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
 PdfSection.table(
 'Major Infrastructure by Solution',
 headers: ['Solution', 'Infrastructure'],
 rows: infraRows,
 ),
 ],
 );
 }

 @override
 void initState() {
 super.initState();
 _notesController = RichTextEditingController(text: widget.notes);
 _solutions = List.from(widget.solutions); // Create mutable copy
 // Initialize with at least one empty item if solutions list is empty
 if (_solutions.isEmpty) {
 _solutions.add(AiSolutionItem(title: '', description: ''));
 }
 _infraControllers =
 List.generate(_solutions.length, (_) => RichTextEditingController());

 // Initialize API key manager
 ApiKeyManager.initializeApiKey();

 // Check admin status (controls Add Item visibility)
 UserService.isCurrentUserAdmin().then((isAdmin) {
 if (mounted) setState(() => _isAdmin = isAdmin);
 });

 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 try {
 _loadExistingData();
 } catch (e) { debugPrint('initState error: $e'); }
 Future.delayed(const Duration(milliseconds: 500), () {
 if (!mounted) return;
 PageHintDialog.showIfNeeded(
 context: context,
 pageId: 'infrastructure_considerations',
 title: 'Infrastructure Considerations',
 message:
 'List the main infrastructure considerations for each potential solution. If suggestions look repetitive, refine each entry to match the specific solution.',
 );
 });
 _generateInfrastructureIfNeeded();
 });
 }

 void _loadExistingData() {
 try {
 final provider = ProjectDataInherited.read(context);
 final infraData = provider.projectData.infrastructureConsiderationsData;

 if (infraData == null) return;

 // Load notes
 if (infraData.notes.isNotEmpty) {
 _notesController.text = infraData.notes;
 }

 // Load infrastructure data for each solution
 // Ensure we have enough controllers and solutions
 while (_infraControllers.length <
 infraData.solutionInfrastructureData.length) {
 _solutions.add(AiSolutionItem(title: '', description: ''));
 _infraControllers.add(RichTextEditingController());
 }
 for (int i = 0;
 i < infraData.solutionInfrastructureData.length &&
 i < _infraControllers.length;
 i++) {
 final solutionInfra = infraData.solutionInfrastructureData[i];
 if (i < _solutions.length) {
 _solutions[i] = AiSolutionItem(
 title: solutionInfra.solutionTitle,
 description: '',
 );
 }
 _infraControllers[i].text = solutionInfra.majorInfrastructure;
 }

 if (mounted) setState(() {});
 } catch (e) {
 debugPrint(
 'Error loading existing infrastructure considerations data: $e');
 }
 }

 Future<void> _generateInfrastructureIfNeeded() async {
 if (!mounted) return;
 if (_isGeneratingInfra) return;

 // If any row already has content, do not overwrite.
 final hasAny = _infraControllers.any((c) => c.text.trim().isNotEmpty);
 if (hasAny) return;

 if (_solutions.isEmpty) return;
 setState(() => _isGeneratingInfra = true);

 try {
 final provider = ProjectDataHelper.getProvider(context);

 // Add current values to history before regenerating
 for (int i = 0;
 i < _solutions.length && i < _infraControllers.length;
 i++) {
 final fieldKey = 'infra_${_solutions[i].title}_$i';
 provider.addFieldToHistory(fieldKey, _infraControllers[i].text,
 isAiGenerated: true);
 }

 // Generate infrastructure suggestions (with tailored fallback if OpenAI not configured)
 final result = await _openAi.generateInfrastructureForSolutions(
 _solutions,
 contextNotes: _notesController.text,
 );

 if (!mounted) return;
 for (int i = 0;
 i < _solutions.length && i < _infraControllers.length;
 i++) {
 final title = _solutions[i].title.trim();
 final items = result[title] ?? const <String>[];
 if (items.isEmpty) continue;
 _infraControllers[i].text = items.map((e) => '- $e').join('\n');
 }

 // Auto-save after regeneration
 await provider.saveToFirebase(checkpoint: 'infrastructure_regenerated');

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Infrastructure considerations regenerated successfully')),
 );
 }
 } catch (e) {
 debugPrint('Error generating infrastructure considerations: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to regenerate infrastructure: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _isGeneratingInfra = false);
 }
 }

 Future<void> _regenerateAllInfrastructure() async {
 if (_isGeneratingInfra) return;
 setState(() => _isGeneratingInfra = true);

 try {
 final provider = ProjectDataHelper.getProvider(context);

 // Add current values to history
 for (int i = 0;
 i < _solutions.length && i < _infraControllers.length;
 i++) {
 final fieldKey = 'infra_${_solutions[i].title}_$i';
 provider.addFieldToHistory(fieldKey, _infraControllers[i].text,
 isAiGenerated: true);
 }

 final result = await _openAi.generateInfrastructureForSolutions(
 _solutions,
 contextNotes: _notesController.text,
 );

 for (int i = 0;
 i < _solutions.length && i < _infraControllers.length;
 i++) {
 final title = _solutions[i].title.trim();
 final items = result[title] ?? const <String>[];
 _infraControllers[i].text =
 items.isEmpty ? '' : items.map((e) => '- $e').join('\n');
 }

 await provider.saveToFirebase(checkpoint: 'infrastructure_regenerated');

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Infrastructure regenerated successfully')),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to regenerate: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _isGeneratingInfra = false);
 }
 }

 @override
 void dispose() {
 _reviewScrollController.dispose();
 _notesController.dispose();
 for (final controller in _infraControllers) {
 controller.dispose();
 }
 super.dispose();
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
 drawer: null,
 body: SafeArea(
 top: true,
 child: Stack(
 children: [
 Row(children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Infrastructure Considerations'),
 ),
 Expanded(
 child: Column(children: [
 BusinessCaseHeader(scaffoldKey: _scaffoldKey, onExportPdf: _exportPdf),
 Expanded(child: _buildMainContent()),
 ])),
 ]),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Infrastructure Considerations',
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
 final displayCount = _isAdmin
 ? _solutions.length
 : (_solutions.length > 3 ? 3 : _solutions.length);
 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: _buildMobileDrawer(),
 body: SafeArea(
 child: Column(
 children: [
 Container(
 height: 56,
 padding: const EdgeInsets.symmetric(horizontal: 6),
 child: Row(
 children: [
 IconButton(
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu_rounded, size: 18),
 ),
 const Expanded(
 child: Text(
 'Infrastructure Considerations',
 style: TextStyle(
 fontSize: 15.7,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 ),
 IconButton(
 onPressed: _isGeneratingInfra
 ? null
 : _regenerateAllInfrastructure,
 icon: const Icon(Icons.refresh_rounded,
 color: Color(0xFFF59E0B), size: 18),
 tooltip: 'Regenerate all',
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(10, 0, 10, 94),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '${projectName.isEmpty ? 'PROJECT' : projectName.toUpperCase()} > Initiation Phase',
 style: const TextStyle(
 fontSize: 9.2,
 color: Color(0xFFF59E0B),
 fontWeight: FontWeight.w700,
 letterSpacing: 0.35,
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Technical Foundations',
 style: TextStyle(
 fontSize: 36,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 height: 1,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Define and document the physical and digital infrastructure requirements for proposed solutions.',
 style: TextStyle(
 fontSize: 12.3, color: Colors.grey.shade600),
 ),
 const SizedBox(height: 12),
 const Text(
 'Notes',
 style: TextStyle(
 fontSize: 13.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 6),
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFDCE3EE)),
 ),
 child: VoiceTextField(
 controller: _notesController,
 minLines: 3,
 maxLines: 6,
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF374151),
 ),
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Enter infrastructure notes here...',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(height: 14),
 const Text(
 'SOLUTION ANALYSIS',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.45,
 ),
 ),
 const SizedBox(height: 8),
 for (int i = 0; i < displayCount; i++) ...[
 _buildMobileInfrastructureCard(i),
 const SizedBox(height: 10),
 ],
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
 child: OutlinedButton.icon(
 onPressed: () async {
 await _saveInfrastructureConsiderationsData();
 if (!mounted) return;
 _openITConsiderations();
 },
 icon: const Icon(Icons.chevron_left_rounded, size: 17),
 label: const Text('Back'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF374151),
 backgroundColor: Colors.white,
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700, fontSize: 13.5),
 ),
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
 borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w800, fontSize: 13.5),
 ),
 child: const Text('Next Step'),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildMobileInfrastructureCard(int index) {
 final provider = ProjectDataHelper.getProvider(context);
 final solution = _solutions[index];
 final title = solution.title.trim().isEmpty
 ? 'Potential Solution ${index + 1}'
 : solution.title.trim();
 final fieldKey = 'infra_${solution.title}_$index';
 final canUndo = provider.canUndoField(fieldKey);
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 21,
 height: 21,
 decoration: const BoxDecoration(
 color: Color(0xFFFBBF24),
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 19,
 fontWeight: FontWeight.w800,
 color: Color(0xFF1F2937),
 height: 1.05,
 ),
 ),
 if (solution.description.trim().isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 4),
 child: Text(
 solution.description.trim(),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 11.5,
 color: Colors.grey.shade500,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFDDE3EE)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 'MAJOR INFRASTRUCTURE',
 style: TextStyle(
 fontSize: 9.5,
 color: Colors.grey.shade500,
 fontWeight: FontWeight.w800,
 letterSpacing: 0.35,
 ),
 ),
 const Spacer(),
 IconButton(
 onPressed: () => _regenerateSingleInfraField(
 _infraControllers[index], index),
 icon: const Icon(Icons.refresh_rounded, size: 15),
 visualDensity: VisualDensity.compact,
 splashRadius: 18,
 tooltip: 'Regenerate field',
 ),
 IconButton(
 onPressed: canUndo
 ? () async {
 final previous =
 provider.projectData.undoField(fieldKey);
 if (previous != null) {
 _infraControllers[index].text = previous;
 await provider.saveToFirebase(
 checkpoint: 'infra_undo');
 }
 }
 : null,
 icon: const Icon(Icons.undo_rounded, size: 15),
 visualDensity: VisualDensity.compact,
 splashRadius: 18,
 tooltip: 'Undo',
 ),
 ],
 ),
 VoiceTextField(
 controller: _infraControllers[index],
 minLines: 4,
 maxLines: null,
 style: const TextStyle(
 fontSize: 12.2,
 color: Color(0xFF334155),
 height: 1.4,
 ),
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText:
 '- Cloud server hosting ...\n- Dedicated database ...',
 isDense: true,
 ),
 ),
 ],
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
 padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
 child: Row(children: [
 Row(children: [
 if (isMobile)
 IconButton(
 icon: const Icon(Icons.menu),
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 ),
 // Top-left logo removed; keep only a back button on larger screens
 if (!isMobile)
 IconButton(
 icon: const Icon(Icons.arrow_back_ios, size: 16),
 onPressed: () => Navigator.pop(context),
 ),
 // Forward chevron (>) removed per request
 ]),
 const Spacer(),
 if (!isMobile)
 const Text('Initiation Phase',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.black)),
 const Spacer(),
 Row(children: [
 Container(
 width: 40,
 height: 40,
 decoration: const BoxDecoration(
 color: const Color(0xFFD97706), shape: BoxShape.circle),
 child: const Icon(Icons.person, color: Colors.white, size: 20)),
 if (!isMobile) ...[
 const SizedBox(width: 12),
 StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final email = FirebaseAuth.instance.currentUser?.email ?? '';
 final isAdmin =
 snapshot.data ?? UserService.isAdminEmail(email);
 final role = isAdmin ? 'Admin' : 'Member';
 return Column(
 mainAxisAlignment: MainAxisAlignment.center,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 FirebaseAuthService.displayNameOrEmail(fallback: 'User'),
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Colors.black),
 ),
 Text(role,
 style:
 const TextStyle(fontSize: 12, color: Colors.grey)),
 ],
 );
 },
 ),
 const SizedBox(width: 8),
 const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
 ],
 ]),
 ]),
 );
 }

 // ignore: unused_element
 Widget _buildSidebar() {
 final isMobile = AppBreakpoints.isMobile(context);
 final double bannerHeight = isMobile ? 72 : 96;
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 return Container(
 width: sidebarWidth,
 color: Colors.white,
 child: Column(children: [
 // Full-width banner image above the "StackOne" text
 SizedBox(
 width: double.infinity,
 height: bannerHeight,
 child: Center(child: AppLogo(height: 64)),
 ),
 Container(
 padding: const EdgeInsets.all(24),
 decoration: const BoxDecoration(
 border:
 Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
 child: const Row(children: [
 CircleAvatar(radius: 20, backgroundColor: Colors.grey),
 SizedBox(width: 12),
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text('StackOne',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black)),
 ])
 ]),
 ),
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(vertical: 20),
 children: [
 _buildMenuItem(Icons.home_outlined, 'Home'),
 _buildExpandableHeader(
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
 _buildNestedSubMenuItem('Business Case',
 onTap: _openBusinessCase),
 _buildNestedSubMenuItem('Potential Solutions',
 onTap: _openPotentialSolutions),
 _buildNestedSubMenuItem('Risk Identification',
 onTap: _openRiskIdentification),
 _buildNestedSubMenuItem('IT Considerations',
 onTap: _openITConsiderations),
 _buildNestedSubMenuItem('Infrastructure Considerations',
 isActive: true),
 _buildNestedSubMenuItem('Core Stakeholders',
 onTap: _openCoreStakeholders),
 _buildNestedSubMenuItem(
 'Initial Cost Estimate',
 onTap: _openCostAnalysis),
 _buildNestedSubMenuItem('Preferred Solution Analysis',
 onTap: _openPreferredSolutionAnalysis),
 ],
 ],
 _buildMenuItem(
 Icons.timeline_outlined, 'Initiation: Front End Planning'),
 _buildMenuItem(Icons.account_tree_outlined, 'Workflow Roadmap'),
 _buildMenuItem(Icons.bolt_outlined, 'Agile Roadmap'),
 _buildMenuItem(Icons.description_outlined, 'Contracting'),
 _buildMenuItem(Icons.shopping_cart_outlined, 'Procurement'),
 const SizedBox(height: 20),
 _buildMenuItem(Icons.settings_outlined, 'Settings'),
 _buildMenuItem(Icons.logout_outlined, 'LogOut'),
 ]),
 ),
 ]),
 );
 }

 Drawer _buildMobileDrawer() {
 return Drawer(
 width: MediaQuery.sizeOf(context).width * 0.88,
 child: const SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Infrastructure Considerations',
 ),
 ),
 );
 }

 Widget _buildMenuItem(IconData icon, String title, {bool active = false}) {
 final theme = Theme.of(context);
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
 child: InkWell(
 onTap: () {
 if (title == 'LogOut') {
 AuthNav.signOutAndExit(context);
 } else if (title == 'Settings') {
 SettingsScreen.open(context);
 }
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: active
 ? BoxDecoration(
 color: theme.colorScheme.primary.withOpacity(0.08),
 borderRadius: BorderRadius.circular(8),
 )
 : null,
 child: Row(children: [
 Icon(icon,
 size: 20,
 color: active ? theme.colorScheme.primary : Colors.black87),
 const SizedBox(width: 16),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 14,
 color: active ? theme.colorScheme.primary : Colors.black87,
 fontWeight: active ? FontWeight.w700 : FontWeight.w500,
 ),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 )),
 ]),
 ),
 ),
 );
 }

 // ignore: unused_element
 Widget _buildSubMenuItem(String title,
 {VoidCallback? onTap, bool isActive = false}) {
 final theme = Theme.of(context);
 final primary = theme.colorScheme.primary;
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
 child: Row(children: [
 Icon(Icons.circle,
 size: 8, color: isActive ? primary : Colors.grey[500]),
 const SizedBox(width: 12),
 Expanded(
 child: Text(title,
 style: TextStyle(
 fontSize: 13,
 color: isActive ? primary : Colors.black87,
 fontWeight:
 isActive ? FontWeight.w600 : FontWeight.normal),
 maxLines: 2,
 overflow: TextOverflow.ellipsis),
 ),
 ]),
 ),
 ),
 );
 }

 Widget _buildExpandableHeader(IconData icon, String title,
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
 child: Row(children: [
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
 Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
 color: Colors.grey[700], size: 20),
 ]),
 ),
 ),
 );
 }

 Widget _buildExpandableHeaderLikeCost(IconData icon, String title,
 {required bool expanded,
 required VoidCallback onTap,
 bool isActive = false}) {
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
 child: Row(children: [
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
 Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
 color: Colors.grey[600], size: 18),
 ]),
 ),
 ),
 );
 }

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
 child: Row(children: [
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
 ]),
 ),
 ),
 );
 }

 void _openBusinessCase() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const InitiationPhaseScreen(scrollToBusinessCase: true),
 ),
 );
 }

 void _openPotentialSolutions() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const PotentialSolutionsScreen(),
 ),
 );
 }

 void _openRiskIdentification() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => RiskIdentificationScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 ),
 ),
 );
 }

 void _openITConsiderations() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => ITConsiderationsScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 ),
 ),
 );
 }

 void _openCoreStakeholders() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CoreStakeholdersScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 ),
 ),
 );
 }

 void _openCostAnalysis() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CostAnalysisScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 ),
 ),
 );
 }

 void _openPreferredSolutionAnalysis() {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => PreferredSolutionAnalysisScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 businessCase: '',
 ),
 ),
 );
 }

 Widget _buildMainContent() {
 final isMobile = AppBreakpoints.isMobile(context);
 return ScrollIndicatorOverlay(
 controller: _reviewScrollController,
 child: SingleChildScrollView(
 controller: _reviewScrollController,
 padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
 const EditableContentText(
 contentKey: 'infrastructure_considerations_heading',
 fallback: 'Infrastructure Considerations ',
 category: 'business_case',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Colors.black)),
 Expanded(
 child: EditableContentText(
 contentKey: 'infrastructure_considerations_description',
 fallback:
 '(List major required infrastructure considerations for each Potential Solution.)',
 category: 'business_case',
 style: TextStyle(fontSize: 14, color: Colors.grey[600])),
 ),
 // Page-level Regenerate All button
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed = await showRegenerateAllConfirmation(context);
 if (confirmed && mounted) {
 await _regenerateAllInfrastructure();
 }
 },
 isLoading: _isGeneratingInfra,
 tooltip: 'Regenerate all infrastructure considerations',
 ),
 ]),
 const SizedBox(height: 16),
 const EditableContentText(
 contentKey: 'infrastructure_considerations_notes_heading',
 fallback: 'Notes',
 category: 'business_case',
 style: TextStyle(
 fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.grey.withOpacity(0.3))),
 child: VoiceTextField(
 controller: _notesController,
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 decoration: InputDecoration(
 hintText: 'Input your notes here...',
 hintStyle: TextStyle(color: Colors.grey[400]),
 border: InputBorder.none,
 contentPadding: EdgeInsets.zero),
 minLines: 1,
 maxLines: null,
 ),
 ),
 const SizedBox(height: 24),
 if (isMobile) ...[
 Text('Reminder: update text within each box.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 fontStyle: FontStyle.italic)),
 const SizedBox(height: 8),
 Column(children: List.generate(_solutions.length, (i) => _row(i))),
 ] else ...[
 const Text(
 'Main Infrastructure Consideration for each potential solution',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black)),
 const SizedBox(height: 6),
 Text('Reminder: update text within each box.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 fontStyle: FontStyle.italic)),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF5F7FB),
 borderRadius:
 const BorderRadius.vertical(top: Radius.circular(8)),
 border: Border.all(color: const Color(0xFFE4E7EC))),
 child: const Row(children: [
 Expanded(
 flex: 2,
 child: Center(
 child: Text('Potential Solution',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475467))))),
 SizedBox(width: 16),
 Expanded(
 flex: 3,
 child: Center(
 child: Text('Major Infrastructure',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475467))))),
 ]),
 ),
 const SizedBox(height: 8),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius:
 const BorderRadius.vertical(bottom: Radius.circular(8)),
 border: Border.all(color: const Color(0xFFE4E7EC))),
 child: _solutions.isEmpty
 ? Padding(
 padding: const EdgeInsets.all(32),
 child: Center(
 child: Text(
 'No solutions added yet. Add solutions from the Potential Solutions page to generate infrastructure considerations.',
 style:
 TextStyle(fontSize: 14, color: Colors.grey[500]),
 textAlign: TextAlign.center,
 ),
 ),
 )
 : Column(
 children:
 List.generate(_solutions.length, (i) => _row(i))),
 ),
 ],
 if (_canUseAdminControls) ...[
 const SizedBox(height: 16),
 // Add Item button (admin-only)
 Row(children: [
 Tooltip(
 message:
 'Add a new infrastructure consideration entry manually',
 child:
 const Icon(Icons.lightbulb_outline, color: Colors.black87),
 ),
 const SizedBox(width: 8),
 ElevatedButton.icon(
 onPressed: _addNewItem,
 icon: const Icon(Icons.add),
 label: const Text('Add Item'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 12),
 ]),
 const SizedBox(height: 24),
 ],

 // Navigation Buttons
 BusinessCaseNavigationButtons(
 currentScreen: 'Infrastructure Considerations',
 padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
 onNext: _handleNextPressed,
 isNextEnabled: _reviewConfirmed,
 showReviewGate: true,
 reviewConfirmed: _reviewConfirmed,
 onReviewChanged: (value) {
 setState(() => _reviewConfirmed = value);
 },
 reviewScrollController: _reviewScrollController,
 ),
 ]),
 ),
 );
 }

 bool _hasRequiredInfrastructureData(ProjectDataModel projectData) {
 final data = projectData.infrastructureConsiderationsData;
 if (data == null || data.solutionInfrastructureData.isEmpty) return false;
 return data.solutionInfrastructureData
 .any((item) => item.majorInfrastructure.trim().isNotEmpty);
 }

 Future<_MissingInfrastructureAction?> _showMissingInfrastructureDialog() {
 return showDialog<_MissingInfrastructureAction>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Infrastructure Considerations Incomplete'),
 content: const Text(
 'No infrastructure considerations were found. Add them manually, let AI generate them, or continue and complete later.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext)
 .pop(_MissingInfrastructureAction.manual),
 child: const Text('Add Manually'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext)
 .pop(_MissingInfrastructureAction.autoFill),
 child: const Text('Auto Fill with AI'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext)
 .pop(_MissingInfrastructureAction.skip),
 child: const Text('Skip for Now'),
 ),
 ],
 ),
 );
 }

 List<AiSolutionItem> _resolveInfrastructureSolutionsForAutofill(
 ProjectDataModel projectData,
 ) {
 final solutions = _solutions
 .where(
 (s) => s.title.trim().isNotEmpty || s.description.trim().isNotEmpty)
 .toList(growable: true);
 if (solutions.isEmpty && projectData.projectName.trim().isNotEmpty) {
 solutions.add(
 AiSolutionItem(
 title: projectData.projectName.trim(),
 description: projectData.solutionDescription.trim(),
 ),
 );
 }
 return solutions;
 }

 Future<List<_InfrastructureAutoFillPreviewRow>>
 _buildInfrastructureAutofillPreview() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;
 final solutionsToUse =
 _resolveInfrastructureSolutionsForAutofill(projectData);
 if (solutionsToUse.isEmpty) {
 return const <_InfrastructureAutoFillPreviewRow>[];
 }

 var contextNotes = _notesController.text.trim();
 if (contextNotes.isEmpty && projectData.projectName.trim().isNotEmpty) {
 contextNotes = 'Project: ${projectData.projectName.trim()}';
 if (projectData.solutionDescription.trim().isNotEmpty) {
 contextNotes +=
 '\nDescription: ${projectData.solutionDescription.trim()}';
 }
 }

 final generated = await _openAi.generateInfrastructureForSolutions(
 solutionsToUse,
 contextNotes: contextNotes,
 );

 final preview = <_InfrastructureAutoFillPreviewRow>[];
 for (var i = 0; i < solutionsToUse.length; i++) {
 final sourceTitle = solutionsToUse[i].title.trim();
 final title = sourceTitle.isEmpty ? 'Solution ${i + 1}' : sourceTitle;
 final suggestions = (generated[sourceTitle] ?? const <String>[])
 .map((entry) => entry.trim())
 .where((entry) => entry.isNotEmpty)
 .toList(growable: false);
 if (suggestions.isEmpty) continue;
 preview.add(
 _InfrastructureAutoFillPreviewRow(title: title, items: suggestions),
 );
 }
 return preview;
 }

 Future<bool> _showInfrastructureAutofillPreviewDialog(
 List<_InfrastructureAutoFillPreviewRow> previewRows,
 ) async {
 if (previewRows.isEmpty) return false;
 final approved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Confirm AI Autofill'),
 content: SizedBox(
 width: 620,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxHeight: 420),
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Review what AI will add before applying:',
 style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < previewRows.length; i++) ...[
 Text(
 previewRows[i].title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 previewRows[i].items.map((item) => '- $item').join('\n'),
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF334155),
 ),
 ),
 if (i != previewRows.length - 1) ...[
 const SizedBox(height: 10),
 const Divider(height: 1, color: Color(0xFFE2E8F0)),
 const SizedBox(height: 10),
 ],
 ],
 ],
 ),
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Apply AI Suggestions'),
 ),
 ],
 ),
 );
 return approved == true;
 }

 Future<bool> _autoFillInfrastructureWithConfirmation() async {
 if (_isGeneratingInfra) return false;
 setState(() => _isGeneratingInfra = true);

 try {
 final previewRows = await _buildInfrastructureAutofillPreview();
 if (!mounted) return false;

 if (previewRows.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'AI could not generate infrastructure suggestions. Add an entry manually or try again.',
 ),
 ),
 );
 return false;
 }

 final approved =
 await _showInfrastructureAutofillPreviewDialog(previewRows);
 if (!mounted || !approved) return false;

 final provider = ProjectDataHelper.getProvider(context);
 setState(() {
 while (_solutions.length < previewRows.length) {
 _solutions.add(
 AiSolutionItem(
 title: previewRows[_solutions.length].title,
 description: '',
 ),
 );
 }
 while (_infraControllers.length < previewRows.length) {
 _infraControllers.add(RichTextEditingController());
 }

 for (var i = 0; i < previewRows.length; i++) {
 final row = previewRows[i];
 final previous =
 i < _infraControllers.length ? _infraControllers[i].text : '';
 final fieldKey = 'infra_${row.title}_$i';
 provider.addFieldToHistory(fieldKey, previous, isAiGenerated: true);
 _solutions[i] = AiSolutionItem(
 title: row.title,
 description: _solutions[i].description,
 );
 _infraControllers[i].text =
 row.items.map((item) => '- $item').join('\n');
 }
 });

 await provider.saveToFirebase(checkpoint: 'infrastructure_regenerated');
 await _saveInfrastructureConsiderationsData();
 if (!mounted) return false;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI infrastructure suggestions applied.')),
 );
 return true;
 } catch (e) {
 if (!mounted) return false;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI autofill failed: $e')),
 );
 return false;
 } finally {
 if (mounted) setState(() => _isGeneratingInfra = false);
 }
 }

 Future<void> _handleNextPressed() async {
 // 1. Save data FIRST before validation
 await _saveInfrastructureConsiderationsData();
 if (!mounted) return;

 // 2. Validate data completeness
 var hasInfraData = _hasRequiredInfrastructureData(
 ProjectDataInherited.read(context).projectData,
 );

 if (!hasInfraData) {
 final action = await _showMissingInfrastructureDialog();
 if (!mounted || action == null) return;

 if (action == _MissingInfrastructureAction.manual) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Continuing without infrastructure considerations. You can complete this later or let AI fill it in later.',
 ),
 ),
 );
 }

 if (action == _MissingInfrastructureAction.autoFill) {
 final applied = await _autoFillInfrastructureWithConfirmation();
 if (!mounted || !applied) return;
 if (!mounted) return;
 hasInfraData = _hasRequiredInfrastructureData(
 ProjectDataInherited.read(context).projectData,
 );
 if (!hasInfraData) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'AI could not generate infrastructure considerations right now. Continuing anyway so you can complete this later.',
 ),
 ),
 );
 }
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Continuing without infrastructure considerations. You can complete this later.',
 ),
 ),
 );
 }
 }

 // 3. Smart checkpoint check
 final nextCheckpoint = SidebarNavigationService.instance
 .getNextItem('infrastructure_considerations');
 if (nextCheckpoint?.checkpoint != 'core_stakeholders') {
 // Use standard lock check for non-sequential navigation
 final isLocked =
 ProjectDataHelper.isDestinationLocked(context, 'core_stakeholders');
 if (isLocked) {
 ProjectDataHelper.showLockedDestinationMessage(
 context, 'Core Stakeholders');
 return;
 }
 }

 if (!mounted) return;
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => const Center(
 child: Card(
 child: Padding(
 padding: EdgeInsets.all(24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircularProgressIndicator(),
 SizedBox(height: 16),
 Text('Processing infrastructure considerations data...'),
 ],
 ),
 ),
 ),
 ),
 );

 // Reduced delay
 await Future.delayed(const Duration(seconds: 1));

 if (!mounted) return;
 Navigator.of(context).pop();

 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => CoreStakeholdersScreen(
 notes: _notesController.text,
 solutions: widget.solutions,
 ),
 ),
 );
 }

 // ignore: unused_element
 Widget _nextButton({required bool expand}) {
 final button = ElevatedButton(
 onPressed: _handleNextPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 elevation: 0,
 minimumSize: expand ? const Size.fromHeight(52) : null,
 ),
 child: const Text('Next',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 );
 if (expand) {
 return SizedBox(width: double.infinity, child: button);
 }
 return button;
 }

 Future<void> _saveInfrastructureConsiderationsData() async {
 try {
 final provider = ProjectDataInherited.read(context);

 // Collect all infrastructure data from all solutions (including manually added items)
 final solutionInfrastructureData = <SolutionInfrastructureData>[];
 for (int i = 0;
 i < _solutions.length && i < _infraControllers.length;
 i++) {
 final solutionTitle = _solutions[i].title.isNotEmpty
 ? _solutions[i].title
 : 'Potential Solution ${i + 1}';
 final majorInfrastructure = _infraControllers[i].text.trim();

 // Only add if there's actual content (majorInfrastructure is not empty)
 if (majorInfrastructure.isNotEmpty) {
 solutionInfrastructureData.add(SolutionInfrastructureData(
 solutionTitle: solutionTitle,
 majorInfrastructure: majorInfrastructure,
 ));
 }
 }

 final infrastructureConsiderationsData = InfrastructureConsiderationsData(
 notes: _notesController.text,
 solutionInfrastructureData: solutionInfrastructureData,
 );

 provider.updateProjectData(
 provider.projectData.copyWith(
 infrastructureConsiderationsData: infrastructureConsiderationsData),
 );

 // Save to Firebase with checkpoint
 await provider.saveToFirebase(
 checkpoint: 'infrastructure_considerations');
 } catch (e) {
 debugPrint('Error saving infrastructure considerations data: $e');
 }
 }

 Widget _row(int index) {
 final isMobile = AppBreakpoints.isMobile(context);
 final isStriped = index.isOdd;
 // Handle cases where we have more controllers than initial solutions (user added items)
 final s = index < _solutions.length
 ? _solutions[index]
 : AiSolutionItem(title: '', description: '');
 return Container(
 constraints: BoxConstraints(
 minHeight: isMobile ? 0 : 168,
 ),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: isStriped ? const Color(0xFFF9FAFC) : Colors.white,
 border: Border(top: BorderSide(color: const Color(0xFFE4E7EC)))),
 child: isMobile
 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text(
 s.title.isEmpty ? 'Potential Solution ${index + 1}' : s.title,
 style:
 const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 if (s.description.isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(s.description,
 style: const TextStyle(fontSize: 12, color: Colors.grey)),
 ],
 const SizedBox(height: 10),
 _infraTextArea(_infraControllers[index], index: index),
 ])
 : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(
 flex: 2,
 child: Align(
 alignment: Alignment.topLeft,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _numberBadge(index + 1),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 s.title.isEmpty
 ? 'Potential Solution ${index + 1}'
 : s.title,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF1F2937),
 fontWeight: FontWeight.w600),
 ),
 ),
 ]),
 if (s.description.isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(s.description,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)),
 maxLines: 5,
 softWrap: true,
 overflow: TextOverflow.ellipsis),
 ]
 ]),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 flex: 3,
 child:
 _infraTextArea(_infraControllers[index], index: index)),
 ]),
 );
 }

 Widget _numberBadge(int number) {
 final theme = Theme.of(context);
 return Container(
 width: 20,
 height: 20,
 alignment: Alignment.center,
 decoration: BoxDecoration(
 color: theme.colorScheme.primary,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 '$number',
 style: const TextStyle(
 fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
 ),
 );
 }

 Widget _infraTextArea(TextEditingController controller,
 {required int index}) {
 final provider = ProjectDataHelper.getProvider(context);
 final solutionTitle =
 index < _solutions.length ? _solutions[index].title : '';
 final fieldKey = 'infra_${solutionTitle}_$index';
 final canUndo = provider.canUndoField(fieldKey);
 final canRedo = provider.canRedoField(fieldKey);

 return HoverableFieldControls(
 isAiGenerated: true,
 isLoading: false,
 canUndo: canUndo,
 canRedo: canRedo,
 onRegenerate: () async {
 // Add current value to history
 provider.addFieldToHistory(fieldKey, controller.text,
 isAiGenerated: true);
 // Regenerate this specific infrastructure field
 await _regenerateSingleInfraField(controller, index);
 },
 onUndo: () async {
 final previousValue = provider.projectData.undoField(fieldKey);
 if (previousValue != null) {
 controller.text = previousValue;
 await provider.saveToFirebase(checkpoint: 'infra_undo');
 }
 },
 onRedo: () async {
 final nextValue = provider.projectData.redoField(fieldKey);
 if (nextValue != null) {
 controller.text = nextValue;
 await provider.saveToFirebase(checkpoint: 'infra_redo');
 }
 },
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 constraints: const BoxConstraints(minHeight: 108),
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: Colors.grey.withOpacity(0.25))),
 child: VoiceTextField(
 controller: controller,
 minLines: 4,
 maxLines: null,
 textAlign: TextAlign.start,
 textAlignVertical: TextAlignVertical.top,
 onChanged: (value) {
 provider.addFieldToHistory(fieldKey, value,
 isAiGenerated: true);
 },
 decoration: InputDecoration(
 border: InputBorder.none,
 isDense: true,
 contentPadding: EdgeInsets.zero,
 hintText:
 'Enter main infrastructure considerations for Solution ${index + 1}...',
 hintStyle: TextStyle(color: Colors.grey[400]),
 ),
 style: const TextStyle(
 fontSize: 12,
 color: Colors.black87,
 height: 1.45,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _regenerateSingleInfraField(
 TextEditingController controller, int index) async {
 if (index >= _solutions.length) return;

 final provider = ProjectDataHelper.getProvider(context);
 final messenger = ScaffoldMessenger.of(context);
 try {
 final solution = _solutions[index];
 final solutionsToUse = [solution];

 final result = await _openAi.generateInfrastructureForSolutions(
 solutionsToUse,
 contextNotes: _notesController.text,
 );
 if (!mounted) return;

 final items = result[solution.title] ?? const <String>[];
 controller.text =
 items.isEmpty ? '' : items.map((e) => '- $e').join('\n');

 await provider.saveToFirebase(checkpoint: 'infra_field_regenerated');

 if (mounted) {
 messenger.showSnackBar(
 const SnackBar(content: Text('Infrastructure field regenerated')),
 );
 }
 } catch (e) {
 if (mounted) {
 messenger.showSnackBar(
 SnackBar(content: Text('Failed to regenerate: $e')),
 );
 }
 }
 }
}
