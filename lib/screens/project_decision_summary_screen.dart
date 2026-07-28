import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class ProjectDecisionSummaryScreen extends StatefulWidget {
 final String projectName;
 final AiSolutionItem selectedSolution;
 final List<AiSolutionItem> allSolutions;
 final String businessCase;
 final String notes;

 const ProjectDecisionSummaryScreen({
 super.key,
 required this.projectName,
 required this.selectedSolution,
 required this.allSolutions,
 required this.businessCase,
 required this.notes,
 });

 @override
 State<ProjectDecisionSummaryScreen> createState() =>
 _ProjectDecisionSummaryScreenState();
}

class _ProjectDecisionSummaryScreenState
 extends State<ProjectDecisionSummaryScreen> {
 static const String _finalSelectionWarning =
 'This selection will form the basis of the entire project and cannot be changed once confirmed. Please ensure you have reviewed all options carefully.';
 static const Set<String> _authorizedRoles = {
 'owner',
 'project manager',
 'founder',
 };

 String? _selectedSolutionTitle;
 int? _selectedSolutionIndex;
 bool _isSelectionFinalized = false;
 bool _isSavingSelection = false;
 bool _isBootstrapping = true;
 bool _guideShown = false;
 String _currentUserRole = 'Member';

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapPage());
 }

 List<AiSolutionItem> get _comparisonSolutions {
 final seeded = widget.allSolutions
 .where(
 (s) => s.title.trim().isNotEmpty || s.description.trim().isNotEmpty)
 .map((s) => AiSolutionItem(
 title: s.title,
 description: s.description,
 ))
 .toList(growable: true);

 if (seeded.isEmpty) {
 seeded.add(AiSolutionItem(
 title: widget.selectedSolution.title,
 description: widget.selectedSolution.description,
 ));
 }

 while (seeded.length < 3) {
 seeded.add(AiSolutionItem(
 title: 'Potential Solution ${seeded.length + 1}',
 description: '',
 ));
 }

 if (seeded.length > 3) {
 return seeded.take(3).toList(growable: false);
 }

 return seeded;
 }

 bool get _isUserAuthorized {
 final normalized = _normalizeRole(_currentUserRole);
 return _authorizedRoles.contains(normalized);
 }

 String get _safeProjectName {
 final trimmed = widget.projectName.trim();
 if (trimmed.isNotEmpty) return trimmed;
 final selectedTitle = widget.selectedSolution.title.trim();
 return selectedTitle.isNotEmpty ? selectedTitle : 'Untitled Project';
 }

 Future<void> _bootstrapPage() async {
 await _loadExistingSelection();
 await _resolveCurrentUserRole();
 if (!mounted) return;
 setState(() {
 _isBootstrapping = false;
 });
 _showSelectionGuide();
 }

 Future<void> _loadExistingSelection() async {
 try {
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;
 final preferred = projectData.preferredSolutionAnalysis;
 final solutions = _comparisonSolutions;

 int? resolvedIndex;
 if (preferred?.selectedSolutionIndex != null) {
 final index = preferred!.selectedSolutionIndex!;
 if (index >= 0 && index < solutions.length) {
 resolvedIndex = index;
 }
 }

 final selectedId = preferred?.selectedSolutionId?.trim() ?? '';
 if (resolvedIndex == null && selectedId.isNotEmpty) {
 for (int i = 0; i < projectData.potentialSolutions.length; i++) {
 if (projectData.potentialSolutions[i].id == selectedId) {
 if (i < solutions.length) {
 resolvedIndex = i;
 }
 break;
 }
 }
 }

 final selectedTitle = preferred?.selectedSolutionTitle?.trim() ?? '';
 if (resolvedIndex == null && selectedTitle.isNotEmpty) {
 for (int i = 0; i < solutions.length; i++) {
 if (_titlesMatch(solutions[i].title, selectedTitle)) {
 resolvedIndex = i;
 break;
 }
 }
 }

 if (resolvedIndex == null) {
 for (int i = 0; i < solutions.length; i++) {
 if (_titlesMatch(solutions[i].title, widget.selectedSolution.title)) {
 resolvedIndex = i;
 break;
 }
 }
 }

 if (!mounted) return;
 setState(() {
 _selectedSolutionIndex = resolvedIndex ?? 0;
 _selectedSolutionTitle = selectedTitle.isNotEmpty
 ? selectedTitle
 : solutions[(resolvedIndex ?? 0).clamp(0, solutions.length - 1)]
 .title;
 _isSelectionFinalized = preferred?.isSelectionFinalized == true;
 });
 } catch (e) {
 debugPrint('Error loading preferred selection state: $e');
 if (!mounted) return;
 setState(() {
 _selectedSolutionIndex = 0;
 });
 }
 }

 Future<void> _resolveCurrentUserRole() async {
 String resolvedRole = 'Member';

 try {
 final user = FirebaseAuth.instance.currentUser;
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;
 final email = user?.email?.trim().toLowerCase() ?? '';
 final uid = user?.uid ?? '';
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: '').trim();

 final projectId = projectData.projectId?.trim() ?? '';
 if (uid.isNotEmpty && projectId.isNotEmpty) {
 final project = await ProjectService.getProjectById(projectId);
 if (project != null) {
 final ownerEmail = project.ownerEmail.trim().toLowerCase();
 if (project.ownerId == uid ||
 (email.isNotEmpty && ownerEmail == email)) {
 resolvedRole = 'Owner';
 }
 }
 }

 if (!_isRoleAuthorizedValue(resolvedRole)) {
 for (final member in projectData.teamMembers) {
 final memberEmail = member.email.trim().toLowerCase();
 final memberName = member.name.trim().toLowerCase();
 final role = member.role.trim();
 final matchesByEmail = email.isNotEmpty &&
 memberEmail.isNotEmpty &&
 memberEmail == email;
 final matchesByName = displayName.isNotEmpty &&
 memberName.isNotEmpty &&
 memberName == displayName.toLowerCase();

 if ((matchesByEmail || matchesByName) && role.isNotEmpty) {
 resolvedRole = role;
 break;
 }
 }
 }

 if (!_isRoleAuthorizedValue(resolvedRole)) {
 final pmName = projectData.charterProjectManagerName.trim();
 if (_matchesIdentity(pmName, displayName, email)) {
 resolvedRole = 'Project Manager';
 }
 }
 } catch (e) {
 debugPrint('Error resolving user role for preferred selection: $e');
 }

 if (!mounted) return;
 setState(() {
 _currentUserRole = resolvedRole;
 });
 }

 bool _matchesIdentity(String candidate, String displayName, String email) {
 final normalizedCandidate = candidate.trim().toLowerCase();
 if (normalizedCandidate.isEmpty) return false;

 final normalizedDisplay = displayName.trim().toLowerCase();
 final emailLocal = email.contains('@')
 ? email.split('@').first.trim().toLowerCase()
 : email.trim().toLowerCase();

 if (normalizedDisplay.isNotEmpty) {
 if (normalizedCandidate == normalizedDisplay) return true;
 if (normalizedDisplay.contains(normalizedCandidate) ||
 normalizedCandidate.contains(normalizedDisplay)) {
 return true;
 }
 }

 if (emailLocal.isNotEmpty) {
 if (normalizedCandidate == emailLocal) return true;
 if (emailLocal.contains(normalizedCandidate) ||
 normalizedCandidate.contains(emailLocal)) {
 return true;
 }
 }

 return false;
 }

 String _normalizeRole(String role) {
 final lower = role.trim().toLowerCase();
 if (lower.contains('project manager')) return 'project manager';
 if (lower.contains('founder')) return 'founder';
 if (lower.contains('owner')) return 'owner';
 return lower;
 }

 bool _isRoleAuthorizedValue(String role) {
 return _authorizedRoles.contains(_normalizeRole(role));
 }

 bool _titlesMatch(String a, String b) {
 final normalizedA = a.trim().toLowerCase();
 final normalizedB = b.trim().toLowerCase();
 if (normalizedA.isEmpty || normalizedB.isEmpty) return false;
 return normalizedA == normalizedB;
 }

 void _showSelectionGuide() {
 if (_guideShown || !mounted) return;
 _guideShown = true;

 showDialog<void>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Preferred Solution Selection'),
 content: const Text(
 'Compare all three solutions, pick one option, then complete the two-step confirmation to confirm your preferred solution.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Continue'),
 ),
 ],
 ),
 );
 }

 Future<void> _handleSelectSolutionCandidate(int index) async {
 if (_isSelectionFinalized) {
 _showBlockedMessage(
 'Preferred solution is already finalized and cannot be changed.',
 attemptedIndex: index,
 );
 return;
 }

 if (!mounted) return;
 setState(() {
 _selectedSolutionIndex = index;
 _selectedSolutionTitle = _comparisonSolutions[index].title;
 });
 }

 Future<void> _startFinalSelectionFlow() async {
 final selectedIndex = _selectedSolutionIndex;
 if (selectedIndex == null ||
 selectedIndex < 0 ||
 selectedIndex >= _comparisonSolutions.length) {
 _showBlockedMessage('Select one solution before finalizing.');
 return;
 }

 if (_isSelectionFinalized) {
 _showBlockedMessage(
 'Preferred solution is already finalized and cannot be changed.',
 );
 return;
 }

 if (!_isUserAuthorized) {
 _showBlockedMessage(
 'Only Owner, Project Manager, or Founder can finalize the preferred solution. Your role is "$_currentUserRole".',
 );
 return;
 }

 final warningAccepted = await _showWarningStep();
 if (warningAccepted != true) return;

 final proceedConfirmed = await _showConfirmationStep();
 if (proceedConfirmed != true) return;

 await _finalizePreferredSelection(index: selectedIndex);
 }

 Future<bool?> _showWarningStep() {
 return showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Warning'),
 content: const Text(_finalSelectionWarning),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () => Navigator.of(context).pop(true),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 ),
 child: const Text('Continue'),
 ),
 ],
 ),
 );
 }

 Future<bool?> _showConfirmationStep() {
 bool acknowledged = false;

 return showDialog<bool>(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: const Text('Confirmation'),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Checkbox(
 value: acknowledged,
 onChanged: (value) {
 setDialogState(() {
 acknowledged = value ?? false;
 });
 },
 ),
 const Expanded(
 child: Padding(
 padding: EdgeInsets.only(top: 12),
 child: Text(
 'I acknowledge that this preferred solution cannot be changed after confirmation.',
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed:
 acknowledged ? () => Navigator.of(context).pop(true) : null,
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 ),
 child: const Text('Proceed'),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _finalizePreferredSelection({required int index}) async {
 if (_isSavingSelection) return;

 setState(() {
 _isSavingSelection = true;
 });

 if (!mounted) return;
 showDialog<void>(
 context: context,
 barrierDismissible: false,
 builder: (_) => const Center(
 child: CircularProgressIndicator(color: Color(0xFFFFD700)),
 ),
 );

 try {
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;
 final selectedSolution = _comparisonSolutions[index];
 final selectedTitle = selectedSolution.title.trim().isNotEmpty
 ? selectedSolution.title.trim()
 : 'Solution ${index + 1}';

 final currentAnalysis = projectData.preferredSolutionAnalysis;
 final resolvedSolutionId =
 _resolveSolutionId(projectData, index, selectedTitle);

 if (resolvedSolutionId != null && resolvedSolutionId.isNotEmpty) {
 await provider.setPreferredSolution(
 resolvedSolutionId,
 checkpoint: 'preferred_solution_finalized',
 );
 }

 final updatedAnalysis = PreferredSolutionAnalysis(
 workingNotes: currentAnalysis?.workingNotes ?? widget.notes,
 solutionAnalyses: currentAnalysis?.solutionAnalyses ?? const [],
 selectedSolutionTitle: selectedTitle,
 selectedSolutionId:
 resolvedSolutionId ?? currentAnalysis?.selectedSolutionId,
 selectedSolutionIndex: index,
 isSelectionFinalized: true,
 );

 provider.updateField(
 (data) => data.copyWith(
 preferredSolutionAnalysis: updatedAnalysis,
 currentCheckpoint: 'preferred_solution_finalized',
 ),
 );
 await provider.saveToFirebase(checkpoint: 'preferred_solution_finalized');

 final projectId = provider.projectData.projectId;
 if (projectId != null && projectId.trim().isNotEmpty) {
 await ProjectService.updateCheckpoint(
 projectId: projectId,
 checkpointRoute: 'preferred_solution_finalized',
 );
 }

 if (!mounted) return;
 setState(() {
 _selectedSolutionIndex = index;
 _selectedSolutionTitle = selectedTitle;
 _isSelectionFinalized = true;
 });

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Preferred solution finalized: $selectedTitle',
 ),
 ),
 );
 } catch (e) {
 if (mounted) {
 _showBlockedMessage('Failed to finalize preferred solution: $e');
 }
 } finally {
 if (mounted) {
 Navigator.of(context, rootNavigator: true).pop();
 setState(() {
 _isSavingSelection = false;
 });
 }
 }
 }

 String? _resolveSolutionId(
 ProjectDataModel projectData,
 int index,
 String solutionTitle,
 ) {
 if (index >= 0 && index < projectData.potentialSolutions.length) {
 final id = projectData.potentialSolutions[index].id.trim();
 if (id.isNotEmpty) return id;
 }

 for (final solution in projectData.potentialSolutions) {
 if (_titlesMatch(solution.title, solutionTitle)) {
 final id = solution.id.trim();
 if (id.isNotEmpty) return id;
 }
 }

 return null;
 }

 void _showBlockedMessage(String message, {int? attemptedIndex}) {
 if (!mounted) return;
 showDialog<void>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Action Blocked'),
 content: Text(message),
 actions: [
 if (attemptedIndex != null &&
 attemptedIndex >= 0 &&
 attemptedIndex < _comparisonSolutions.length)
 TextButton(
 onPressed: () {
 Navigator.of(context).pop();
 _showStartNewProjectDialog(attemptedIndex);
 },
 child: const Text('Start New Project'),
 ),
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 }

 Future<void> _showStartNewProjectDialog(int index) async {
 final solution = _comparisonSolutions[index];
 final defaultTitle = solution.title.trim().isNotEmpty
 ? solution.title.trim()
 : 'Solution ${index + 1}';
 final nameController =
 TextEditingController(text: '$defaultTitle - New Project');
 String? errorText;

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => AlertDialog(
 title: const Text('Start New Project'),
 content: SizedBox(
 width: 460,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Create a new project using "${solution.title.trim().isNotEmpty ? solution.title.trim() : 'Solution ${index + 1}'}" as the preferred solution.',
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: nameController,
 decoration: InputDecoration(
 labelText: 'Project name',
 errorText: errorText,
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () async {
 final trimmed = nameController.text.trim();
 if (trimmed.isEmpty) {
 setDialogState(() {
 errorText = 'Project name is required.';
 });
 return;
 }
 Navigator.of(dialogContext).pop();
 await _startNewProjectWithSolution(
 index: index,
 projectName: trimmed,
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 ),
 child: const Text('Create Project'),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _startNewProjectWithSolution({
 required int index,
 required String projectName,
 }) async {
 final user = FirebaseAuth.instance.currentUser;
 if (user == null) {
 _showBlockedMessage('Sign in to create a new project.');
 return;
 }

 final selected = _comparisonSolutions[index];
 final ownerName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'Leader');
 final tags = <String>[
 'Initiation',
 if (selected.title.trim().isNotEmpty) selected.title.trim(),
 ];

 if (!mounted) return;
 showDialog<void>(
 context: context,
 barrierDismissible: false,
 builder: (_) => const Center(
 child: CircularProgressIndicator(color: Color(0xFFFFD700)),
 ),
 );

 try {
 final projectId = await ProjectService.createProject(
 ownerId: user.uid,
 ownerName: ownerName,
 ownerEmail: user.email,
 name: projectName,
 solutionTitle: selected.title.trim(),
 solutionDescription: selected.description.trim(),
 businessCase: widget.businessCase,
 notes: widget.notes,
 tags: tags,
 checkpointRoute: 'project_decision_summary',
 );

 if (!mounted) return;
 final provider = ProjectDataHelper.getProvider(context);
 await provider.loadFromFirebase(projectId);

 if (!mounted) return;
 Navigator.of(context, rootNavigator: true).pop();

 final allSolutions = _comparisonSolutions
 .map((item) =>
 AiSolutionItem(title: item.title, description: item.description))
 .toList(growable: false);

 Navigator.of(context).pushReplacement(
 MaterialPageRoute(
 builder: (_) => ProjectDecisionSummaryScreen(
 projectName: projectName,
 selectedSolution: selected,
 allSolutions: allSolutions,
 businessCase: widget.businessCase,
 notes: widget.notes,
 ),
 ),
 );

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('New project created: $projectName')),
 );
 } catch (e) {
 if (mounted) {
 Navigator.of(context, rootNavigator: true).pop();
 _showBlockedMessage('Could not create new project: $e');
 }
 }
 }

 Future<void> _handleNextNavigation() async {
 if (!_isSelectionFinalized) {
 _showBlockedMessage(
 'Select the preferred solution before moving to the next page.',
 );
 return;
 }

 if (!mounted) return;
 showDialog<void>(
 context: context,
 barrierDismissible: false,
 builder: (_) => const Center(
 child: CircularProgressIndicator(color: Color(0xFFFFD700)),
 ),
 );

 try {
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(currentCheckpoint: 'fep_summary'));
 await provider.saveToFirebase(checkpoint: 'fep_summary');

 if (provider.projectData.projectId != null) {
 await ProjectService.updateCheckpoint(
 projectId: provider.projectData.projectId!,
 checkpointRoute: 'fep_summary',
 );
 }
 } catch (e) {
 debugPrint('Error saving checkpoint before next navigation: $e');
 } finally {
 if (mounted) {
 Navigator.of(context, rootNavigator: true).pop();
 }
 }

 if (!mounted) return;
 FrontEndPlanningSummaryScreen.open(context);
 }

 SolutionAnalysisItem? _analysisForSolution(
 AiSolutionItem solution, int index) {
 final preferred =
 ProjectDataHelper.getData(context).preferredSolutionAnalysis;
 final items = preferred?.solutionAnalyses ?? const <SolutionAnalysisItem>[];

 if (index >= 0 && index < items.length) {
 final indexed = items[index];
 if (_titlesMatch(indexed.solutionTitle, solution.title)) {
 return indexed;
 }
 }

 for (final item in items) {
 if (_titlesMatch(item.solutionTitle, solution.title)) {
 return item;
 }
 }

 if (index >= 0 && index < items.length) {
 return items[index];
 }
 return null;
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return Scaffold(
 backgroundColor: Colors.white,
 drawer: isMobile
 ? Drawer(
 width: AppBreakpoints.sidebarWidth(context),
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Preferred Solution',
 showHeader: true,
 ),
 ),
 )
 : null,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Preferred Solution',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 Column(
 children: [
 _Header(
 projectName: _safeProjectName,
 roleLabel: _currentUserRole,
 ),
 Expanded(
 child: _isBootstrapping
 ? const Center(
 child: CircularProgressIndicator(
 color: Color(0xFFFFD700),
 ),
 )
 : _buildMainContent(),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Preferred Solution',
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

 Widget _buildMainContent() {
 final solutions = _comparisonSolutions;
 final selectedIndex =
 (_selectedSolutionIndex ?? 0).clamp(0, solutions.length - 1);

 return SingleChildScrollView(
 padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Project Decision Summary', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 const Text(
 'Preferred Solution Selection',
 style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 8),
 const Text(
 'Review all potential solutions and select preferred option.',
 style: TextStyle(fontSize: 14, color: Colors.black54),
 ),
 const SizedBox(height: 20),
 _buildAuthorizationBanner(),
 const SizedBox(height: 20),
 _buildComparisonGrid(solutions),
 const SizedBox(height: 24),
 _buildSelectionActions(
 selectedIndex: selectedIndex,
 totalSolutions: solutions.length,
 ),
 const SizedBox(height: 24),
 Align(
 alignment: Alignment.centerRight,
 child: _NextButton(onPressed: _handleNextNavigation),
 ),
 ],
 ),
 );
 }

 Widget _buildAuthorizationBanner() {
 if (_isUserAuthorized) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFEFFAF3),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFF86EFAC)),
 ),
 child: Text(
 'Authorized role detected: $_currentUserRole. You can finalize the preferred solution.',
 style: const TextStyle(color: Color(0xFF166534), fontSize: 13),
 ),
 );
 }

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFCA5A5)),
 ),
 child: Text(
 'Only Owner, Project Manager, or Founder can finalize this selection. Current role: $_currentUserRole.',
 style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
 ),
 );
 }

 Widget _buildComparisonGrid(List<AiSolutionItem> solutions) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final isMobile = AppBreakpoints.isMobile(context);
 final cardWidth = isMobile
 ? constraints.maxWidth
 : ((constraints.maxWidth - 32) / 3).clamp(280.0, 520.0);

 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 for (int i = 0; i < solutions.length; i++)
 SizedBox(
 width: cardWidth,
 child: _buildSolutionCard(
 index: i,
 solution: solutions[i],
 analysis: _analysisForSolution(solutions[i], i),
 selected: _selectedSolutionIndex == i,
 ),
 ),
 ],
 );
 },
 );
 }

 Widget _buildSolutionCard({
 required int index,
 required AiSolutionItem solution,
 required SolutionAnalysisItem? analysis,
 required bool selected,
 }) {
 final title = solution.title.trim().isNotEmpty
 ? solution.title.trim()
 : 'Solution ${index + 1}';
 final description = solution.description.trim().isNotEmpty
 ? solution.description.trim()
 : 'No description provided.';

 final stakeholders = analysis?.stakeholders
 .where((item) => item.trim().isNotEmpty)
 .take(3)
 .toList() ??
 const <String>[];
 final risks = analysis?.risks
 .where((item) => item.trim().isNotEmpty)
 .take(3)
 .toList() ??
 const <String>[];
 final costs = analysis?.costs ?? const <CostItem>[];

 final totalCost =
 costs.fold<double>(0, (sum, cost) => sum + cost.estimatedCost);
 final avgRoi = costs.isEmpty
 ? 0.0
 : costs.fold<double>(0, (sum, cost) => sum + cost.roiPercent) /
 costs.length;
 var bestNpv = 0.0;
 for (final cost in costs) {
 final npv = cost.npvByYear[5] ?? 0.0;
 if (npv > bestNpv) {
 bestNpv = npv;
 }
 }

 return InkWell(
 onTap: () => _handleSelectSolutionCandidate(index),
 borderRadius: BorderRadius.circular(14),
 child: Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: selected ? const Color(0xFFFFD700) : const Color(0xFFE5E7EB),
 width: selected ? 2 : 1,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 10,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 'Solution ${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 InkWell(
 onTap: _isSelectionFinalized
 ? null
 : () => _handleSelectSolutionCandidate(index),
 borderRadius: BorderRadius.circular(20),
 child: Padding(
 padding: const EdgeInsets.all(4),
 child: Icon(
 selected
 ? Icons.radio_button_checked
 : Icons.radio_button_off,
 color: selected
 ? const Color(0xFFFFD700)
 : const Color(0xFF9CA3AF),
 size: 22,
 ),
 ),
 ),
 ],
 ),
 Text(
 title,
 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 Text(
 description,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 _metricChip('Cost ${_formatCurrency(totalCost)}'),
 _metricChip('ROI ${avgRoi.toStringAsFixed(1)}%'),
 _metricChip('NPV ${_formatCurrency(bestNpv)}'),
 ],
 ),
 const SizedBox(height: 12),
 _miniList('Core stakeholders', stakeholders),
 const SizedBox(height: 10),
 _miniList('Key risks', risks),
 const SizedBox(height: 12),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 TextButton.icon(
 onPressed: () => _showSolutionDetailsDialog(
 index: index,
 solution: solution,
 analysis: analysis,
 ),
 icon: const Icon(Icons.visibility_outlined, size: 16),
 label: const Text('View This Solution'),
 ),
 TextButton.icon(
 onPressed: () => _showSolutionDetailsDialog(
 index: index,
 solution: solution,
 analysis: analysis,
 ),
 icon: const Icon(Icons.expand_more, size: 16),
 label: const Text('View more'),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }

 void _showSolutionDetailsDialog({
 required int index,
 required AiSolutionItem solution,
 required SolutionAnalysisItem? analysis,
 }) {
 final title = solution.title.trim().isNotEmpty
 ? solution.title.trim()
 : 'Solution ${index + 1}';
 final description = solution.description.trim().isNotEmpty
 ? solution.description.trim()
 : 'No description provided.';

 List<String> clean(List<String> source) => source
 .map((item) => item.trim())
 .where((item) => item.isNotEmpty)
 .toList(growable: false);

 final stakeholders = clean(analysis?.stakeholders ?? const <String>[]);
 final risks = clean(analysis?.risks ?? const <String>[]);
 final technologies = clean(analysis?.technologies ?? const <String>[]);
 final infrastructure = clean(analysis?.infrastructure ?? const <String>[]);

 showDialog<void>(
 context: context,
 builder: (dialogContext) => Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 760, maxHeight: 740),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 title,
 style: const TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700),
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 icon: const Icon(Icons.close),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Expanded(
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _detailsBlock('Solution Description', [description]),
 _detailsBlock('Core Stakeholders', stakeholders),
 _detailsBlock('Key Risks', risks),
 _detailsBlock('IT Considerations', technologies),
 _detailsBlock(
 'Infrastructure Considerations', infrastructure),
 ],
 ),
 ),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerRight,
 child: FilledButton.icon(
 onPressed: () {
 Navigator.of(dialogContext).pop();
 _handleSelectSolutionCandidate(index);
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 ),
 icon: const Icon(Icons.check_circle_outline, size: 18),
 label: const Text('Select Preferred Solution'),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _detailsBlock(String title, List<String> lines) {
 final hasLines = lines.isNotEmpty;
 return Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 if (!hasLines)
 const Text('No data available',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))
 else
 for (final line in lines.take(8))
 Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 '- $line',
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 ],
 ),
 );
 }

 Widget _miniList(String title, List<String> items) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 if (items.isEmpty)
 const Text(
 'No data available',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 )
 else
 for (final item in items)
 Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(
 '- $item',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 ],
 );
 }

 Widget _metricChip(String value) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBE6),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFFFE58A)),
 ),
 child: Text(
 value,
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
 ),
 );
 }

 String _formatCurrency(double amount) {
 final rounded = amount.round();
 final digits = rounded.abs().toString();
 final chunks = <String>[];
 for (int i = digits.length; i > 0; i -= 3) {
 final start = (i - 3).clamp(0, digits.length);
 chunks.add(digits.substring(start, i));
 }
 final joined = chunks.reversed.join(',');
 final value = rounded < 0 ? '-$joined' : joined;
 return '\$$value';
 }

 Widget _buildSelectionActions({
 required int selectedIndex,
 required int totalSolutions,
 }) {
 final selectedTitle =
 _comparisonSolutions[selectedIndex].title.trim().isNotEmpty
 ? _comparisonSolutions[selectedIndex].title.trim()
 : 'Solution ${selectedIndex + 1}';

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Preferred Solution Selection',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 8),
 Text(
 'Selected candidate: Solution ${selectedIndex + 1} of $totalSolutions - $selectedTitle',
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
 ),
 const SizedBox(height: 12),
 if (_isSelectionFinalized)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFEFFAF3),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFF86EFAC)),
 ),
 child: Text(
 'Finalized: ${_selectedSolutionTitle ?? selectedTitle}. This selection is locked.',
 style: const TextStyle(fontSize: 13, color: Color(0xFF166534)),
 ),
 ),
 if (!_isSelectionFinalized)
 Text(
 _finalSelectionWarning,
 style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 14),
 ElevatedButton.icon(
 onPressed: _isSavingSelection || _isSelectionFinalized
 ? null
 : _startFinalSelectionFlow,
 icon: _isSavingSelection
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.check_circle_outline, size: 18),
 label: const Text('Select Preferred Solution'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Decision Summary',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_project_decision_summary_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _Header extends StatelessWidget {
 final String projectName;
 final String roleLabel;

 const _Header({required this.projectName, required this.roleLabel});

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return Container(
 height: isMobile ? 56 : 70,
 color: Colors.white,
 padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
 child: Row(
 children: [
 if (isMobile)
 IconButton(
 icon: const Icon(Icons.menu),
 onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
 ),
 if (!isMobile) ...[
 const SizedBox(width: 20),
 IconButton(
 icon: const Icon(Icons.arrow_back_ios, size: 16),
 onPressed: () => Navigator.of(context).pop(),
 ),
 ],
 const Spacer(),
 if (!isMobile)
 Text(
 'Preferred Solution - $projectName',
 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.grey[100],
 borderRadius: BorderRadius.circular(24),
 ),
 child: Row(
 children: [
 CircleAvatar(
 radius: 18,
 backgroundColor: Colors.blue[400],
 child: Text(
 FirebaseAuthService.displayNameOrEmail(fallback: 'U')
 .characters
 .first
 .toUpperCase(),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 if (!isMobile) ...[
 const SizedBox(width: 10),
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
 Text(
 roleLabel,
 style:
 const TextStyle(fontSize: 10, color: Colors.grey),
 ),
 ],
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

class _NextButton extends StatelessWidget {
 final VoidCallback onPressed;

 const _NextButton({required this.onPressed});

 @override
 Widget build(BuildContext context) {
 return ElevatedButton(
 onPressed: onPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
 elevation: 2,
 ),
 child: const Text(
 'Next',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
 ),
 );
 }
}
