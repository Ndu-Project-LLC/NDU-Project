import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import '../widgets/content_text.dart';
import '../services/auth_nav.dart';
import '../openai/openai_config.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// Removed AppLogo from header per request
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/widgets/business_case_navigation_buttons.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/select_project_kaz_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class InitiationPhaseScreen extends StatefulWidget {
 final bool scrollToBusinessCase;
 const InitiationPhaseScreen({super.key, this.scrollToBusinessCase = false});

 @override
 State<InitiationPhaseScreen> createState() => _InitiationPhaseScreenState();
}

class _InitiationPhaseScreenState extends State<InitiationPhaseScreen> {
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 final ScrollController _reviewScrollController = ScrollController();
 final TextEditingController _notesController = RichTextEditingController();
 final TextEditingController _businessCaseController =
 RichTextEditingController();
 final FocusNode _notesFocusNode = FocusNode();
 final FocusNode _businessFocusNode = FocusNode();
 // Anchor key for sidebar navigation
 final GlobalKey _businessCaseSectionKey = GlobalKey();
 bool _initiationExpanded = true;
 bool _reviewConfirmed = false;

 bool get _isBusinessCaseValid =>
 _meetsBusinessMinimum(_businessCaseController.text.trim());

 void _requireBusinessCaseBefore(
 String destinationName, VoidCallback proceed) async {
 if (_isBusinessCaseValid) {
 proceed();
 return;
 }
 final business = _businessCaseController.text.trim();
 final wordCount =
 business.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
 final shouldContinue = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Business Case Incomplete'),
 content: Text(
 wordCount == 0
 ? 'No Business Case has been entered yet. It is recommended to complete at least $_businessWordMinimum words before continuing to $destinationName.\n\nYou can add or edit the Business Case right here:'
 : 'The Business Case currently has $wordCount words (minimum $_businessWordMinimum recommended) before continuing to $destinationName.\n\nYou can add more content right here:',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Go Back & Edit'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Continue Anyway'),
 ),
 ],
 ),
 );
 if (shouldContinue == true) {
 proceed();
 } else {
 setState(() => _businessInvalid = true);
 _scrollToBusinessCase();
 }
 }

 void _openPotentialSolutions() async {
 final business = _businessCaseController.text.trim();
 _requireBusinessCaseBefore('Potential Solutions', () async {
 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'business_case',
 saveInBackground: true,
 nextScreenBuilder: () => const PotentialSolutionsScreen(),
 dataUpdater: (data) => data.copyWith(
 notes: _notesController.text.trim(),
 businessCase: business,
 ),
 );
 });
 }

 void _openRiskIdentification() {
 _requireBusinessCaseBefore('Risk Identification', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => RiskIdentificationScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 businessCase: _businessCaseController.text.trim(),
 ),
 ),
 );
 });
 }

 Timer? _notesDebounce;
 Timer? _businessDebounce;

 bool _notesSuggestLoading = false;
 bool _businessSuggestLoading = false;

 List<String> _notesSuggestions = [];
 List<String> _businessSuggestions = [];

 // ignore: unused_field
 String? _notesSuggestionError;
 String? _businessSuggestionError;

 String _notesLastQuery = '';
 String _businessLastQuery = '';
 final List<String> _notesUndoStack = [];
 final List<String> _businessUndoStack = [];
 bool _notesInvalid = false;
 bool _businessInvalid = false;
 static const int _notesWordMinimum = 5;
 static const int _businessWordMinimum = 10;

 @override
 void initState() {
 super.initState();
 _notesFocusNode.addListener(_handleNotesFocusChange);
 _businessFocusNode.addListener(_handleBusinessFocusChange);

 // Notes & Business Case = prose; no auto-bullet

 // Load existing data from provider
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 try {
 final projectData = ProjectDataHelper.getData(context);
 if (projectData.notes.isNotEmpty) {
 _notesController.text = projectData.notes;
 }
 if (projectData.businessCase.isNotEmpty) {
 _businessCaseController.text = projectData.businessCase;
 }

 // Show hint on first visit
 if (mounted) {
 Future.delayed(const Duration(milliseconds: 500), () {
 if (!mounted) return;
 PageHintDialog.showIfNeeded(
 context: context,
 pageId: 'initiation_phase',
 title: 'Business Case',
 message:
 'Enter your project notes and detailed business case here. Use the formatting toolbar above text fields for bold, underline, headings, and undo functionality.',
 );
 });
 }

 // If requested, scroll to Business Case
 if (widget.scrollToBusinessCase) {
 _scrollToBusinessCase();
 }

 if (mounted) setState(() {});
 } catch (e) {
 debugPrint('InitiationPhase initState error: $e');
 if (mounted) setState(() {});
 }
 });
 }

 void _handleNotesFocusChange() {
 if (!mounted) return;
 if (!_notesFocusNode.hasFocus) {
 _notesDebounce?.cancel();
 }
 setState(() {});
 }

 void _handleBusinessFocusChange() {
 if (!mounted) return;
 if (!_businessFocusNode.hasFocus) {
 _businessDebounce?.cancel();
 }
 setState(() {});
 }

 void _onNotesChanged(String value) {
 if (_notesInvalid && _meetsNotesMinimum(value)) {
 setState(() => _notesInvalid = false);
 }
 // Update provider state immediately for persistence
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateInitiationData(notes: value.trim());
 }

 void _onBusinessChanged(String value) {
 if (_businessInvalid && _meetsBusinessMinimum(value)) {
 setState(() => _businessInvalid = false);
 }
 _scheduleBusinessSuggestions(value);
 // Update provider state immediately for persistence
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateInitiationData(businessCase: value.trim());
 // Also rebuild so sidebar enable/disable state reflects current input
 setState(() {});
 }

 void _saveBeforeUndo() {
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateInitiationData(
 notes: _notesController.text.trim(),
 businessCase: _businessCaseController.text.trim(),
 );
 provider.saveToFirebase(checkpoint: 'business_case');
 }

 int _wordCount(String text) {
 final words =
 text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
 return words.length;
 }

 bool _meetsNotesMinimum(String text) => _wordCount(text) >= _notesWordMinimum;

 bool _meetsBusinessMinimum(String text) =>
 _wordCount(text) >= _businessWordMinimum;

 bool _canRequestNotesSuggestions(String text) => text.trim().length >= 12;
 bool _canRequestBusinessSuggestions(String text) => text.trim().length >= 18;

 // ignore: unused_element
 void _scheduleNotesSuggestions(String value) {
 _notesDebounce?.cancel();
 if (!_notesFocusNode.hasFocus) return;
 if (!_canRequestNotesSuggestions(value)) {
 setState(() {
 _notesSuggestions = [];
 _notesSuggestLoading = false;
 _notesSuggestionError = null;
 _notesLastQuery = '';
 });
 return;
 }

 _notesDebounce = Timer(const Duration(milliseconds: 600), () {
 _fetchNotesSuggestions(value.trim());
 });
 }

 void _scheduleBusinessSuggestions(String value) {
 _businessDebounce?.cancel();
 if (!_businessFocusNode.hasFocus) return;
 if (!_canRequestBusinessSuggestions(value)) {
 setState(() {
 _businessSuggestions = [];
 _businessSuggestLoading = false;
 _businessSuggestionError = null;
 _businessLastQuery = '';
 });
 return;
 }

 _businessDebounce = Timer(const Duration(milliseconds: 600), () {
 _fetchBusinessSuggestions(value.trim());
 });
 }

 Future<void> _fetchNotesSuggestions(String text) async {
 if (!_notesFocusNode.hasFocus || !_canRequestNotesSuggestions(text)) return;
 if (!_notesSuggestLoading &&
 text == _notesLastQuery &&
 _notesSuggestions.isNotEmpty) {
 return;
 }

 setState(() {
 _notesSuggestLoading = true;
 _notesSuggestionError = null;
 });

 try {
 final suggestions =
 await OpenAiAutocompleteService.instance.fetchSuggestions(
 fieldName: 'Initiation Notes',
 currentText: text,
 context: _businessCaseController.text,
 );
 if (!mounted) return;
 setState(() {
 _notesSuggestions = suggestions;
 _notesSuggestLoading = false;
 _notesLastQuery = text;
 });
 } on OpenAiNotConfiguredException catch (e) {
 if (!mounted) return;
 setState(() {
 _notesSuggestions = [];
 _notesSuggestLoading = false;
 _notesSuggestionError = _formatSuggestionError(e);
 _notesLastQuery = text;
 });
 } catch (e) {
 if (!mounted) return;
 setState(() {
 _notesSuggestions = [];
 _notesSuggestLoading = false;
 _notesSuggestionError = _formatSuggestionError(e);
 _notesLastQuery = text;
 });
 }
 }

 Future<void> _fetchBusinessSuggestions(String text) async {
 if (!_businessFocusNode.hasFocus || !_canRequestBusinessSuggestions(text)) {
 return;
 }
 if (!_businessSuggestLoading &&
 text == _businessLastQuery &&
 _businessSuggestions.isNotEmpty) {
 return;
 }

 setState(() {
 _businessSuggestLoading = true;
 _businessSuggestionError = null;
 });

 try {
 final suggestions =
 await OpenAiAutocompleteService.instance.fetchSuggestions(
 fieldName: 'Business Case',
 currentText: text,
 context: _notesController.text,
 );
 if (!mounted) return;
 setState(() {
 _businessSuggestions = suggestions;
 _businessSuggestLoading = false;
 _businessLastQuery = text;
 });
 } on OpenAiNotConfiguredException catch (e) {
 if (!mounted) return;
 setState(() {
 _businessSuggestions = [];
 _businessSuggestLoading = false;
 _businessSuggestionError = _formatSuggestionError(e);
 _businessLastQuery = text;
 });
 } catch (e) {
 if (!mounted) return;
 setState(() {
 _businessSuggestions = [];
 _businessSuggestLoading = false;
 _businessSuggestionError = _formatSuggestionError(e);
 _businessLastQuery = text;
 });
 }
 }

 void _applySuggestion(TextEditingController controller, String suggestion,
 {bool isNotes = false}) {
 final replacement = suggestion.trim();
 if (replacement.isEmpty) return;

 _pushUndo(controller, isNotes: isNotes);

 controller.value = TextEditingValue(
 text: replacement,
 selection: TextSelection.collapsed(offset: replacement.length),
 );

 if (isNotes) {
 _onNotesChanged(replacement);
 } else {
 _onBusinessChanged(replacement);
 }

 setState(() {
 if (isNotes) {
 _notesSuggestions = [];
 _notesLastQuery = replacement;
 } else {
 _businessSuggestions = [];
 _businessLastQuery = replacement;
 }
 });
 }

 void _insertSuggestion(TextEditingController controller, String suggestion,
 {bool isNotes = false}) {
 final insertion = suggestion.trim();
 if (insertion.isEmpty) return;
 final existing = controller.text.trim();
 final combined = existing.isEmpty ? insertion : '$existing\n$insertion';

 _pushUndo(controller, isNotes: isNotes);

 controller.value = TextEditingValue(
 text: combined,
 selection: TextSelection.collapsed(offset: combined.length),
 );

 if (isNotes) {
 _onNotesChanged(combined);
 } else {
 _onBusinessChanged(combined);
 }

 setState(() {
 if (isNotes) {
 _notesLastQuery = combined;
 } else {
 _businessLastQuery = combined;
 }
 });
 }

 Future<void> _copySuggestion(String suggestion) async {
 final value = suggestion.trim();
 if (value.isEmpty) return;
 await Clipboard.setData(ClipboardData(text: value));
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Suggestion copied to clipboard')),
 );
 }

 void _pushUndo(TextEditingController controller, {required bool isNotes}) {
 final stack = isNotes ? _notesUndoStack : _businessUndoStack;
 if (stack.isEmpty || stack.last != controller.text) {
 stack.add(controller.text);
 }
 }

 void _undoSuggestion(TextEditingController controller,
 {required bool isNotes}) {
 final stack = isNotes ? _notesUndoStack : _businessUndoStack;
 if (stack.isEmpty) return;
 final previous = stack.removeLast();
 controller.value = TextEditingValue(
 text: previous,
 selection: TextSelection.collapsed(offset: previous.length),
 );
 if (isNotes) {
 _onNotesChanged(previous);
 } else {
 _onBusinessChanged(previous);
 }
 setState(() {});
 }

 // ignore: unused_element
 void _retryNotesSuggestions() =>
 _fetchNotesSuggestions(_notesController.text.trim());

 void _retryBusinessSuggestions() =>
 _fetchBusinessSuggestions(_businessCaseController.text.trim());

 Future<void> _handleNextPressed() async {
 final notes = _notesController.text.trim();
 final business = _businessCaseController.text.trim();
 const notesValid = true;
 final businessValid = _meetsBusinessMinimum(business);

 if (!notesValid || !businessValid) {
 setState(() {
 _notesInvalid = false;
 _businessInvalid = !businessValid;
 });
 final wordCount =
 business.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
 final shouldContinue = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: const Text('Business Case Incomplete'),
 content: Text(
 wordCount == 0
 ? 'No Business Case has been entered yet. It is recommended to add at least $_businessWordMinimum words.\n\nYou can continue anyway and complete this later.'
 : 'The Business Case currently has $wordCount words (minimum $_businessWordMinimum recommended).\n\nYou can continue anyway and complete this later.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Go Back & Edit'),
 ),
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Continue Anyway'),
 ),
 ],
 ),
 );
 if (shouldContinue != true) return;
 }

 if (!mounted) return;
 FocusScope.of(context).unfocus();

 // Save data to provider before navigation
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateInitiationData(
 notes: notes,
 businessCase: business,
 );

 // Save to Firebase
 await provider.saveToFirebase(checkpoint: 'business_case');

 // Show a 3-second loading experience before navigation
 if (!mounted) return;
 await showDialog<void>(
 context: context,
 barrierDismissible: false,
 barrierColor: Colors.black.withOpacity(0.45),
 builder: (_) => const _RiskIdentificationTransitionDialog(),
 );

 if (!mounted) return;
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const PotentialSolutionsScreen(),
 ),
 );
 }

 bool _isGeneratingAI = false;

 Future<void> _handleSkipPressed() async {
 FocusScope.of(context).unfocus();

 // If business case is empty, generate it with AI
 if (_businessCaseController.text.trim().isEmpty) {
 if (!mounted) return;

 // Show loading overlay
 setState(() => _isGeneratingAI = true);

 try {
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;

 // Generate business case using AI
 final openAiService = OpenAiServiceSecure();
 final generatedBusinessCase = await openAiService.generateBusinessCase(
 projectName: projectData.projectName,
 notes: _notesController.text.trim(),
 solutionTitle: projectData.solutionTitle,
 solutionDescription: projectData.solutionDescription,
 );

 if (!mounted) return;

 // Populate the controller
 _businessCaseController.text = generatedBusinessCase;

 // Update provider state
 provider.updateInitiationData(
 notes: _notesController.text.trim(),
 businessCase: generatedBusinessCase,
 );

 // Save to Firebase
 await provider.saveToFirebase(checkpoint: 'business_case');

 if (!mounted) return;
 setState(() => _isGeneratingAI = false);

 // Show success message
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Business Case generated successfully!'),
 backgroundColor: Colors.green,
 duration: Duration(seconds: 2),
 ),
 );

 return; // Don't proceed to skip flow, user can now review/edit the generated content
 } catch (e) {
 if (!mounted) return;
 setState(() => _isGeneratingAI = false);

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to generate Business Case: ${e.toString()}'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 4),
 ),
 );
 return;
 }
 }

 // If business case already exists, show modal explaining skip requirements
 final shouldProceed = await showDialog<bool>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: const Row(
 children: [
 Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 28),
 SizedBox(width: 12),
 Expanded(child: Text('Skip Business Case')),
 ],
 ),
 content: const Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'To skip the Business Case, you must provide essential information in the following sections:',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 SizedBox(height: 16),
 _RequirementItem(
 icon: Icons.people_outline, text: 'Core Stakeholders'),
 _RequirementItem(
 icon: Icons.computer_outlined, text: 'IT Considerations'),
 _RequirementItem(
 icon: Icons.business_outlined,
 text: 'Infrastructure Considerations'),
 SizedBox(height: 12),
 Text(
 'You will be directed to fill these fields before proceeding to Front End Planning.',
 style: TextStyle(fontSize: 13, color: Colors.grey),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 ),
 child: const Text('Continue'),
 ),
 ],
 ),
 );

 if (shouldProceed != true || !mounted) return;

 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;

 // Check which mandatory fields are missing
 final missingFields = <String, String>{};

 // Check Core Stakeholders - validation: lists must not be empty (regardless of AI or manual entry)
 final hasCoreStakeholders = projectData.coreStakeholdersData != null &&
 projectData.coreStakeholdersData!.solutionStakeholderData.isNotEmpty &&
 projectData.coreStakeholdersData!.solutionStakeholderData
 .any((item) => item.notableStakeholders.trim().isNotEmpty);
 if (!hasCoreStakeholders) {
 missingFields['Core Stakeholders'] = 'core_stakeholders';
 }

 // Check IT Considerations - validation: lists must not be empty (regardless of AI or manual entry)
 final hasITConsiderations = projectData.itConsiderationsData != null &&
 projectData.itConsiderationsData!.solutionITData.isNotEmpty &&
 projectData.itConsiderationsData!.solutionITData
 .any((item) => item.coreTechnology.trim().isNotEmpty);
 if (!hasITConsiderations) {
 missingFields['IT Considerations'] = 'it_considerations';
 }

 // Check Infrastructure Considerations - validation: lists must not be empty (regardless of AI or manual entry)
 final hasInfrastructure = projectData.infrastructureConsiderationsData !=
 null &&
 projectData.infrastructureConsiderationsData!.solutionInfrastructureData
 .isNotEmpty &&
 projectData.infrastructureConsiderationsData!.solutionInfrastructureData
 .any((item) => item.majorInfrastructure.trim().isNotEmpty);
 if (!hasInfrastructure) {
 missingFields['Infrastructure Considerations'] =
 'infrastructure_considerations';
 }

 // Missing setup context should no longer block phase progression.
 if (missingFields.isNotEmpty) {
 if (!mounted) return;

 // Save current data first so the next phase still has the latest context.
 provider.updateInitiationData(
 notes: _notesController.text.trim(),
 businessCase: _businessCaseController.text.trim(),
 );
 await provider.saveToFirebase(checkpoint: 'business_case');
 if (!mounted) return;

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Continuing to Front End Planning with partial setup. Missing: ${missingFields.keys.join(', ')}.',
 ),
 backgroundColor: const Color(0xFFD97706),
 duration: const Duration(seconds: 4),
 action: SnackBarAction(
 label: 'Review',
 textColor: Colors.white,
 onPressed: () {
 final firstMissingCheckpoint = missingFields.values.first;
 _navigateToRequiredField(firstMissingCheckpoint);
 },
 ),
 ),
 );
 }

 // Proceed to Front End Planning even if some setup is still empty.
 provider.updateInitiationData(
 notes: _notesController.text.trim(),
 businessCase: _businessCaseController.text.trim(),
 );

 await provider.saveToFirebase(checkpoint: 'fep_summary');

 final projectId = provider.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .update({
 'status': 'Planning',
 'milestone': 'planning',
 'checkpointRoute': 'fep_summary',
 'checkpointAt': FieldValue.serverTimestamp(),
 'updatedAt': FieldValue.serverTimestamp(),
 });
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Warning: Unable to update project status. ${e.toString()}')),
 );
 }
 }
 }

 if (!mounted) return;

 // Show Select Project dialog on Scope Statement page so user can pick a solution
 final options = projectData.potentialSolutions
 .map((s) => SolutionOption(
 title: s.title, description: s.description, projectName: null))
 .toList(growable: false);

 final selection = await showDialog<SolutionOption?>(
 context: context,
 barrierDismissible: true,
 builder: (dialogCtx) {
 String? projectName;
 int? selectedIndex;
 String? nameError;
 return StatefulBuilder(builder: (ctx, setState) {
 return Dialog(
 insetPadding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 640),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(children: [
 const Expanded(
 child: Text('Choose a project to progress',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700))),
 IconButton(
 onPressed: () => Navigator.of(ctx).pop(null),
 icon: const Icon(Icons.close)),
 ]),
 const SizedBox(height: 12),
 const Text(
 'Pick the solution you want to advance and give your project a memorable name.',
 style:
 TextStyle(fontSize: 14, color: Colors.black54)),
 const SizedBox(height: 20),
 ConstrainedBox(
 constraints: BoxConstraints(
 maxHeight: options.length >= 3 ? 360 : 240),
 child: SingleChildScrollView(
 child: Column(children: [
 for (var i = 0; i < options.length; i++)
 ListTile(
 leading: Radio<int?>(
 value: i,
 // ignore: deprecated_member_use
 groupValue: selectedIndex,
 // ignore: deprecated_member_use
 onChanged: (v) =>
 setState(() => selectedIndex = v),
 ),
 title: Text(
 options[i].title.isNotEmpty
 ? options[i].title
 : 'Untitled Solution',
 style: const TextStyle(
 fontWeight: FontWeight.w700)),
 subtitle: Text(options[i].description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis),
 onTap: () {
 setState(() {
 selectedIndex = i;
 if (projectName == null ||
 projectName!.trim().isEmpty) {
 projectName = options[i].title;
 }
 });
 },
 ),
 ]),
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 decoration: InputDecoration(
 labelText: 'Project name',
 errorText: nameError,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12))),
 controller: TextEditingController(text: projectName),
 onChanged: (v) => projectName = v,
 ),
 const SizedBox(height: 20),
 Row(mainAxisAlignment: MainAxisAlignment.end, children: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(null),
 child: const Text('Cancel')),
 const SizedBox(width: 12),
 ElevatedButton(
 onPressed: () {
 if (selectedIndex == null) {
 ScaffoldMessenger.of(ctx).showSnackBar(
 const SnackBar(
 content:
 Text('Select a project first.')));
 return;
 }
 final name = (projectName ?? '').trim();
 if (name.isEmpty) {
 setState(() => nameError =
 'Give your project a name to continue.');
 return;
 }
 Navigator.of(ctx).pop(SolutionOption(
 title: options[selectedIndex!].title,
 description:
 options[selectedIndex!].description,
 projectName: name));
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black),
 child: const Text('Save & Continue'),
 ),
 ])
 ]),
 ),
 ),
 );
 });
 },
 );

 if (selection == null) return;

 // Create project using selection (mirror of PreferredSolutionAnalysisScreen flow)
 final user = FirebaseAuth.instance.currentUser;
 if (user == null) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Sign in to save your project.')));
 return;
 }

 final ownerName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'Leader');
 final trimmedNotes = _notesController.text.trim();
 final trimmedBusinessCase = _businessCaseController.text.trim();
 final tags = [
 'Initiation',
 if (selection.title.trim().isNotEmpty) selection.title.trim()
 ];

 bool dialogShown = false;
 if (mounted) {
 dialogShown = true;
 showDialog<void>(
 context: context,
 barrierDismissible: false,
 builder: (_) => const Center(child: CircularProgressIndicator()));
 }

 try {
 await ProjectService.createProject(
 ownerId: user.uid,
 ownerName: ownerName,
 name: selection.projectName ?? selection.title,
 solutionTitle: selection.title.trim(),
 solutionDescription: selection.description.trim(),
 businessCase: trimmedBusinessCase,
 notes: trimmedNotes,
 ownerEmail: user.email,
 tags: tags,
 checkpointRoute: 'project_decision_summary',
 );
 } catch (e) {
 if (dialogShown && mounted) {
 Navigator.of(context, rootNavigator: true).pop();
 }
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Unable to save project. Try again.')));
 return;
 }

 if (dialogShown && mounted) {
 Navigator.of(context, rootNavigator: true).pop();
 }

 if (!mounted) return;
 FrontEndPlanningSummaryScreen.open(context);
 }

 void _navigateToRequiredField(String checkpoint) {
 final provider = ProjectDataHelper.getProvider(context);
 final projectData = provider.projectData;

 Widget? screen;
 switch (checkpoint) {
 case 'core_stakeholders':
 screen = CoreStakeholdersScreen(
 notes: projectData.coreStakeholdersData?.notes ?? projectData.notes,
 solutions: projectData.potentialSolutions
 .map((s) =>
 AiSolutionItem(title: s.title, description: s.description))
 .toList(),
 );
 break;
 case 'it_considerations':
 screen = ITConsiderationsScreen(
 notes: projectData.itConsiderationsData?.notes ?? projectData.notes,
 solutions: projectData.potentialSolutions
 .map((s) =>
 AiSolutionItem(title: s.title, description: s.description))
 .toList(),
 );
 break;
 case 'infrastructure_considerations':
 screen = InfrastructureConsiderationsScreen(
 notes: projectData.infrastructureConsiderationsData?.notes ??
 projectData.notes,
 solutions: projectData.potentialSolutions
 .map((s) =>
 AiSolutionItem(title: s.title, description: s.description))
 .toList(),
 );
 break;
 }

 if (screen != null) {
 Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
 }
 }

 Future<void> _exportPdf() async {
 final notes = _notesController.text.trim();
 final businessCase = _businessCaseController.text.trim();
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Business Case',
 sections: [
 PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
 PdfSection.text('Business Case', businessCase.isEmpty ? 'No data recorded.' : businessCase),
 ],
 );
 }

 String _formatSuggestionError(Object error) {
 if (error is OpenAiNotConfiguredException) {
 return 'AI service is starting up. Please try again in a moment.';
 }
 final message = error.toString();
 final lower = message.toLowerCase();
 if (lower.contains('timed out')) {
 return 'OpenAI request timed out. Try again in a moment.';
 }
 if (lower.contains('rate limit')) {
 return 'OpenAI rate limit reached. Try again shortly.';
 }
 if (lower.contains('api key')) {
 return 'OpenAI API key not accepted. Please check the key in Settings or contact support.';
 }
 final sanitized = message.replaceFirst(RegExp(r'^Exception: '), '').trim();
 if (sanitized.length > 180) {
 return '${sanitized.substring(0, 177)}…';
 }
 return sanitized;
 }

 Widget _buildSuggestionPanel({
 required bool show,
 required bool loading,
 required List<String> suggestions,
 required String? error,
 required String label,
 required VoidCallback onRefresh,
 VoidCallback? onUndo,
 bool canUndo = false,
 required ValueChanged<String> onSelect,
 ValueChanged<String>? onInsert,
 ValueChanged<String>? onCopy,
 }) {
 if (!show) return const SizedBox.shrink();
 final hasError = (error ?? '').trim().isNotEmpty;
 final hasSuggestions = suggestions.isNotEmpty;
 if (!loading && !hasError && !hasSuggestions) {
 return const SizedBox.shrink();
 }

 final borderColor =
 hasError ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2);
 final canRefresh = !loading && OpenAiConfig.isConfigured;

 return Container(
 margin: const EdgeInsets.only(top: 8),
 padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: borderColor),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.auto_awesome,
 size: 18, color: Color(0xFFFFD700)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 if (canRefresh)
 TextButton.icon(
 onPressed: onRefresh,
 icon: const Icon(Icons.refresh, size: 16),
 label: const Text('Refresh'),
 style: TextButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 ),
 if (canUndo && onUndo != null)
 TextButton.icon(
 onPressed: onUndo,
 icon: const Icon(Icons.undo, size: 16),
 label: const Text('Undo'),
 style: TextButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (loading)
 const Center(
 child: SizedBox(
 width: 22,
 height: 22,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ),
 if (!loading && hasError)
 Text(
 error!,
 style: TextStyle(
 fontSize: 13,
 color: Colors.red[600],
 ),
 ),
 if (!loading && hasSuggestions) ...[
 const Text(
 'Tap a suggestion to replace, or use actions to insert or copy.',
 style: TextStyle(fontSize: 12.5, color: Colors.black54),
 ),
 const SizedBox(height: 8),
 ...suggestions.map(
 (suggestion) => Padding(
 padding: const EdgeInsets.only(top: 8),
 child: _buildSuggestionOption(
 suggestion,
 onTap: () => onSelect(suggestion),
 onInsert:
 onInsert == null ? null : () => onInsert(suggestion),
 onCopy: onCopy == null ? null : () => onCopy(suggestion),
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildSuggestionOption(
 String text, {
 required VoidCallback onTap,
 VoidCallback? onInsert,
 VoidCallback? onCopy,
 }) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8F9FB),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.grey.withOpacity(0.22)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 2),
 child: Icon(
 Icons.add_circle_outline,
 size: 18,
 color: Color(0xFFFFD700),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 13.5,
 height: 1.4,
 color: Colors.black87,
 ),
 ),
 ),
 if (onInsert != null || onCopy != null) ...[
 const SizedBox(width: 8),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (onInsert != null)
 _buildSuggestionActionButton(
 icon: Icons.content_paste_rounded,
 tooltip: 'Insert into draft',
 onPressed: onInsert,
 ),
 if (onCopy != null)
 _buildSuggestionActionButton(
 icon: Icons.copy_rounded,
 tooltip: 'Copy',
 onPressed: onCopy,
 ),
 ],
 ),
 ],
 ],
 ),
 ),
 );
 }

 Widget _buildSuggestionActionButton({
 required IconData icon,
 required String tooltip,
 required VoidCallback onPressed,
 }) {
 return Tooltip(
 message: tooltip,
 child: InkWell(
 onTap: onPressed,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 width: 32,
 height: 32,
 margin: const EdgeInsets.only(left: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
 ),
 ),
 );
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
 // Sidebar full height on the left; header + content on the right
 Row(
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Business Case Detail'),
 ),
 Expanded(
 child: Column(
 children: [
 // Header sits inside the content area (right of sidebar)
 BusinessCaseHeader(scaffoldKey: _scaffoldKey, onExportPdf: _exportPdf),
 Expanded(child: _buildMainContent()),
 ],
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Business Case Detail',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 // Loading overlay for AI generation
 if (_isGeneratingAI)
 Container(
 color: Colors.black.withOpacity(0.5),
 child: const Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircularProgressIndicator(
 valueColor:
 AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
 ),
 SizedBox(height: 16),
 Text(
 'Generating Business Case with AI...',
 style: TextStyle(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 // ignore: unused_element
 Widget _buildSidebar() {
 // Sidebar to match PreferredSolutionAnalysisScreen structure and add right border
 final isMobile = AppBreakpoints.isMobile(context);
 final double bannerHeight = isMobile ? 72 : 96;
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 return Container(
 width: sidebarWidth,
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(
 right: BorderSide(color: Colors.grey.withOpacity(0.25), width: 0.8),
 ),
 ),
 child: Column(
 children: [
 // Full-width banner image above "StackOne"
 SizedBox(
 width: double.infinity,
 height: bannerHeight,
 child: Center(child: AppLogo(height: 64)),
 ),
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
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(vertical: 20),
 children: [
 _buildMenuItem(Icons.home_outlined, 'Home',
 onTap: () => HomeScreen.open(context)),
 _buildExpandableHeader(
 Icons.flag_outlined,
 'Initiation Phase',
 expanded: _initiationExpanded,
 onTap: () => setState(
 () => _initiationExpanded = !_initiationExpanded),
 isActive: true,
 ),
 if (_initiationExpanded) ...[
 _buildSubMenuItem('Scope Statement',
 onTap: _scrollToBusinessCase, isActive: true),
 _buildSubMenuItem('Potential Solutions',
 onTap: _openPotentialSolutions,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('Risk Identification',
 onTap: _openRiskIdentification,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('IT Considerations',
 onTap: _openITConsiderations,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('Infrastructure Considerations',
 onTap: _openInfrastructureConsiderations,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('Core Stakeholders',
 onTap: _openCoreStakeholders,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('Initial Cost Estimate',
 onTap: _openCostAnalysis,
 disabled: !_isBusinessCaseValid),
 _buildSubMenuItem('Preferred Solution Analysis',
 onTap: _openPreferredSolutionAnalysis,
 disabled: !_isBusinessCaseValid),
 ],
 _buildMenuItem(
 Icons.timeline, 'Initiation: Front End Planning'),
 _buildMenuItem(Icons.account_tree_outlined, 'Workflow Roadmap'),
 _buildMenuItem(Icons.flash_on, 'Agile Roadmap'),
 _buildMenuItem(Icons.description_outlined, 'Contracting'),
 _buildMenuItem(Icons.shopping_cart_outlined, 'Procurement'),
 const SizedBox(height: 20),
 _buildMenuItem(Icons.settings_outlined, 'Settings',
 onTap: () => SettingsScreen.open(context)),
 _buildMenuItem(Icons.logout_outlined, 'LogOut',
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
 activeItemLabel: 'Business Case Detail',
 ),
 ),
 );
 }

 bool get _mobileDraftMode =>
 _businessCaseController.text.trim().isNotEmpty &&
 _wordCount(_businessCaseController.text) >= 8;

 void _applyAllMobileSuggestions() {
 final suggestions = _businessSuggestions.isEmpty
 ? const <String>[
 'Add specific budget constraints to clarify financial boundaries.',
 'Define exclusion criteria to avoid scope creep in Phase 2.',
 ]
 : _businessSuggestions.take(2).toList(growable: false);
 if (suggestions.isEmpty) return;
 final base = _businessCaseController.text.trim();
 final extra = suggestions.map((item) => '- $item').join('\n');
 final merged = base.isEmpty ? extra : '$base\n\n$extra';
 _businessCaseController.text = merged;
 _onBusinessChanged(merged);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI refinement suggestions applied.')),
 );
 }

 Widget _buildMobileTopBar({required bool draftMode}) {
 return Padding(
 padding: const EdgeInsets.fromLTRB(6, 8, 8, 6),
 child: Row(
 children: [
 IconButton(
 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
 icon: const Icon(Icons.menu_rounded, size: 20),
 visualDensity: VisualDensity.compact,
 ),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 draftMode ? 'Scope Statement' : 'Initiation Phase',
 style: const TextStyle(
 fontSize: 19,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFFFBBF24),
 child: Text(
 FirebaseAuthService.displayNameOrEmail(fallback: 'U')
 .trim()
 .characters
 .first
 .toUpperCase(),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 12.5,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMobilePhaseMeta({required bool draftMode}) {
 if (draftMode) {
 return Padding(
 padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
 child: Text(
 'INITIATION PHASE • PROJECT: ${ProjectDataHelper.getData(context).projectName.isEmpty ? 'PROJECT' : ProjectDataHelper.getData(context).projectName.toUpperCase()}',
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 9.8,
 letterSpacing: 0.45,
 color: Color(0xFF94A3B8),
 fontWeight: FontWeight.w700,
 ),
 ),
 );
 }
 return Container(
 margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(
 top: BorderSide(color: Colors.grey.withOpacity(0.2)),
 bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
 ),
 ),
 child: Row(
 children: const [
 _MobilePhaseStep(index: '1', label: 'Initiation', active: true),
 SizedBox(width: 10),
 _MobilePhaseStep(index: '2', label: 'Design'),
 SizedBox(width: 10),
 _MobilePhaseStep(index: '3', label: 'Execution'),
 ],
 ),
 );
 }

 Widget _buildMobileActionRow({required bool draftMode}) {
 return Padding(
 padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
 child: Row(
 children: [
 Expanded(
 child: OutlinedButton(
 onPressed: _handleSkipPressed,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF111827),
 backgroundColor: Colors.white,
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 padding: const EdgeInsets.symmetric(vertical: 14),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
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
 borderRadius: BorderRadius.circular(12),
 ),
 padding: const EdgeInsets.symmetric(vertical: 14),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w800,
 fontSize: 14,
 ),
 ),
 child: Text(draftMode ? 'Save & Next' : 'Next'),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMobileBottomNav() {
 return BottomAppBar(
 shape: const CircularNotchedRectangle(),
 notchMargin: 8,
 elevation: 12,
 child: SizedBox(
 height: 62,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 _MobileBottomItem(
 icon: Icons.home_filled,
 label: 'Home',
 onTap: () => HomeScreen.open(context),
 ),
 const _MobileBottomItem(
 icon: Icons.folder_open,
 label: 'Projects',
 active: true,
 ),
 const SizedBox(width: 36),
 const _MobileBottomItem(
 icon: Icons.notifications_none, label: 'Alerts'),
 _MobileBottomItem(
 icon: Icons.settings_outlined,
 label: 'Settings',
 onTap: () => SettingsScreen.open(context),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMobileEntryContent() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Notes',
 style: TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: VoiceTextField(
 controller: _notesController,
 focusNode: _notesFocusNode,
 minLines: 3,
 maxLines: 5,
 onChanged: _onNotesChanged,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Input your notes here...',
 ),
 ),
 ),
 const SizedBox(height: 18),
 const Text(
 'Scope Statement',
 style: TextStyle(
 fontSize: 27,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 3),
 Text(
 '(Describe the aim of this project)',
 style: TextStyle(
 fontSize: 12.5,
 color: Colors.grey.shade600,
 ),
 ),
 const SizedBox(height: 8),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: _businessInvalid ? Colors.red : const Color(0xFFE2E8F0)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: VoiceTextField(
 controller: _businessCaseController,
 focusNode: _businessFocusNode,
 minLines: 6,
 maxLines: 10,
 onChanged: _onBusinessChanged,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: '(Describe the aim of this project)',
 ),
 ),
 ),
 _buildMobileActionRow(draftMode: false),
 ],
 );
 }

 Widget _buildMobileDraftContent() {
 final suggestions = _businessSuggestions.isEmpty
 ? const <String>[
 'Add specific budget constraints to clarify financial boundaries.',
 'Define exclusion criteria to avoid scope creep in Phase 2.',
 ]
 : _businessSuggestions.take(2).toList(growable: false);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: const [
 Expanded(
 child: Text(
 'Draft Scope Statement',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 16.5,
 color: Color(0xFF111827),
 ),
 ),
 ),
 Icon(Icons.info_outline_rounded,
 color: Color(0xFFCBD5E1), size: 18),
 ],
 ),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: _businessCaseController,
 focusNode: _businessFocusNode,
 minLines: 6,
 maxLines: 10,
 onChanged: _onBusinessChanged,
 decoration: const InputDecoration(
 border: InputBorder.none,
 hintText: 'Write your scope statement...',
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF2F4FA),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE3E8F3)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'AI Refinement Suggestions',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 color: Color(0xFF3744A6),
 ),
 ),
 const SizedBox(height: 8),
 ...suggestions.map(
 (item) => Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE4E8F5)),
 ),
 child: Text(
 item,
 style: const TextStyle(
 fontSize: 12.5,
 height: 1.35,
 color: Color(0xFF334155),
 ),
 ),
 ),
 ),
 Align(
 alignment: Alignment.center,
 child: TextButton(
 onPressed: _applyAllMobileSuggestions,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF3347C4),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: const Text('Apply All Suggestions'),
 ),
 ),
 ],
 ),
 ),
 _buildMobileActionRow(draftMode: true),
 ],
 );
 }

 Widget _buildMobileScaffold() {
 final draftMode = _mobileDraftMode;
 return Scaffold(
 key: _scaffoldKey,
 drawer: _buildMobileDrawer(),
 backgroundColor: Colors.white,
 floatingActionButtonLocation: draftMode
 ? FloatingActionButtonLocation.centerDocked
 : FloatingActionButtonLocation.endFloat,
 floatingActionButton: FloatingActionButton(
 onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI assistant opened.')),
 ),
 backgroundColor:
 draftMode ? const Color(0xFF111827) : const Color(0xFFFBBF24),
 child: Icon(
 draftMode ? Icons.add : Icons.chat_outlined,
 color: draftMode ? Colors.white : Colors.black,
 ),
 ),
 bottomNavigationBar: draftMode ? _buildMobileBottomNav() : null,
 body: Stack(
 children: [
 SafeArea(
 child: Column(
 children: [
 _buildMobileTopBar(draftMode: draftMode),
 _buildMobilePhaseMeta(draftMode: draftMode),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
 child: draftMode
 ? _buildMobileDraftContent()
 : _buildMobileEntryContent(),
 ),
 ),
 ],
 ),
 ),
 if (_isGeneratingAI)
 Container(
 color: Colors.black.withOpacity(0.5),
 child: const Center(
 child: CircularProgressIndicator(
 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMenuItem(IconData icon, String title,
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

 Widget _buildSubMenuItem(String title,
 {VoidCallback? onTap, bool isActive = false, bool disabled = false}) {
 final primary = Theme.of(context).colorScheme.primary;
 return Padding(
 padding: const EdgeInsets.only(left: 48, right: 24, top: 2, bottom: 2),
 child: InkWell(
 onTap: () {
 if (disabled) {
 // Intercept taps when disabled and guide the user back
 _requireBusinessCaseBefore(title, () {});
 return;
 }
 onTap?.call();
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 Icon(
 Icons.circle,
 size: 8,
 color: isActive
 ? primary
 : (disabled ? Colors.grey[300] : Colors.grey[500]),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontSize: 13,
 color: isActive
 ? primary
 : (disabled ? Colors.black45 : Colors.black87),
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

 Widget _buildMainContent() {
 final isMobile = AppBreakpoints.isMobile(context);
 return ScrollIndicatorOverlay(
 controller: _reviewScrollController,
 child: SingleChildScrollView(
 controller: _reviewScrollController,
 padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Notes section
 const EditableContentText(
 contentKey: 'business_case_notes_heading',
 fallback: 'Notes',
 category: 'business_case',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: _notesInvalid
 ? Colors.red
 : Colors.grey.withOpacity(0.3)),
 ),
 child: VoiceTextField(
 controller: _notesController,
 focusNode: _notesFocusNode,
 style: TextStyle(
 fontSize: 14,
 color: Colors.grey[600],
 ),
 decoration: InputDecoration(
 hintText: 'Input your notes here...',
 hintStyle: TextStyle(color: Colors.grey[400]),
 border: InputBorder.none,
 contentPadding: EdgeInsets.zero,
 ),
 // Auto-expand as the user types; no internal scroll
 minLines: 1,
 maxLines: null,
 onChanged: _onNotesChanged,
 ),
 ),
 if (_notesInvalid)
 const Padding(
 padding: EdgeInsets.only(top: 8),
 child: Text(
 'Please enter at least 5 words for Notes.',
 style: TextStyle(
 fontSize: 13,
 color: Colors.red,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 const SizedBox(height: 8),
 SizedBox(height: AppBreakpoints.sectionGap(context)),
 // Business Case section
 EditableContentText(
 contentKey: 'business_case_heading',
 fallback: 'Scope Statement',
 category: 'business_case',
 key: _businessCaseSectionKey,
 style: const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 const SizedBox(height: 8),
 EditableContentText(
 contentKey: 'business_case_description',
 fallback: '(Describe the aim of this project)',
 category: 'business_case',
 style: TextStyle(
 fontSize: 16,
 color: Colors.grey[600],
 ),
 ),
 SizedBox(height: AppBreakpoints.fieldGap(context)),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: _businessInvalid
 ? Colors.red
 : Colors.grey.withOpacity(0.3)),
 ),
 child: VoiceTextField(
 controller: _businessCaseController,
 focusNode: _businessFocusNode,
 style: TextStyle(
 fontSize: 14,
 color: Colors.grey[600],
 ),
 decoration: InputDecoration(
 hintText: '(Describe the aim of this project)',
 hintStyle: TextStyle(color: Colors.grey[400]),
 border: InputBorder.none,
 contentPadding: EdgeInsets.zero,
 ),
 // Start tall, then grow with content; no internal scroll
 minLines: isMobile ? 6 : 10,
 maxLines: null,
 onChanged: _onBusinessChanged,
 ),
 ),
 if (_businessInvalid)
 Padding(
 padding: const EdgeInsets.only(top: 8),
 child: Text(
 'Please enter at least $_businessWordMinimum words for the Business Case.',
 style: const TextStyle(
 fontSize: 13,
 color: Colors.red,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 AnimatedSize(
 duration: const Duration(milliseconds: 200),
 curve: Curves.easeOutCubic,
 child: _buildSuggestionPanel(
 show: _businessFocusNode.hasFocus ||
 _businessSuggestLoading ||
 _businessSuggestions.isNotEmpty ||
 (_businessSuggestionError?.trim().isNotEmpty ?? false),
 loading: _businessSuggestLoading,
 suggestions: _businessSuggestions,
 error: _businessSuggestionError,
 label: 'AI suggestions for the business case',
 onRefresh: _retryBusinessSuggestions,
 onUndo: _businessUndoStack.isEmpty
 ? null
 : () => _undoSuggestion(
 _businessCaseController,
 isNotes: false,
 ),
 canUndo: _businessUndoStack.isNotEmpty,
 onSelect: (value) => _applySuggestion(
 _businessCaseController,
 value,
 ),
 onInsert: (value) => _insertSuggestion(
 _businessCaseController,
 value,
 ),
 onCopy: _copySuggestion,
 ),
 ),
 SizedBox(height: AppBreakpoints.sectionGap(context)),
 // Navigation Buttons
 BusinessCaseNavigationButtons(
 currentScreen: 'Business Case',
 padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
 onNext: _handleNextPressed,
 onSkip: _handleSkipPressed,
 skipLabel: 'Skip',
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
 );
 }

 @override
 void dispose() {
 _notesDebounce?.cancel();
 _businessDebounce?.cancel();
 _reviewScrollController.dispose();
 _notesFocusNode
 ..removeListener(_handleNotesFocusChange)
 ..dispose();
 _businessFocusNode
 ..removeListener(_handleBusinessFocusChange)
 ..dispose();
 _notesController.dispose();
 _businessCaseController.dispose();
 super.dispose();
 }

 void _scrollToBusinessCase() {
 final ctx = _businessCaseSectionKey.currentContext;
 if (ctx != null) {
 Scrollable.ensureVisible(
 ctx,
 duration: const Duration(milliseconds: 400),
 curve: Curves.easeOutCubic,
 alignment: 0.1,
 );
 }
 }

 void _openITConsiderations() {
 _requireBusinessCaseBefore('IT Considerations', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => ITConsiderationsScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 ),
 ),
 );
 });
 }

 void _openInfrastructureConsiderations() {
 _requireBusinessCaseBefore('Infrastructure Considerations', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => InfrastructureConsiderationsScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 ),
 ),
 );
 });
 }

 void _openCoreStakeholders() {
 _requireBusinessCaseBefore('Core Stakeholders', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CoreStakeholdersScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 ),
 ),
 );
 });
 }

 void _openCostAnalysis() {
 _requireBusinessCaseBefore('Initial Cost Estimate', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => CostAnalysisScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 ),
 ),
 );
 });
 }

 void _openPreferredSolutionAnalysis() {
 _requireBusinessCaseBefore('Preferred Solution Analysis', () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => PreferredSolutionAnalysisScreen(
 notes: _notesController.text.trim(),
 solutions: const [],
 businessCase: _businessCaseController.text.trim(),
 ),
 ),
 );
 });
 }
}

class _MobilePhaseStep extends StatelessWidget {
 const _MobilePhaseStep({
 required this.index,
 required this.label,
 this.active = false,
 });

 final String index;
 final String label;
 final bool active;

 @override
 Widget build(BuildContext context) {
 return Expanded(
 child: Row(
 children: [
 Container(
 width: 16,
 height: 16,
 decoration: BoxDecoration(
 color: active ? const Color(0xFFFBBF24) : const Color(0xFFE5E7EB),
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 index,
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: active ? Colors.black : const Color(0xFF6B7280),
 ),
 ),
 ),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 label,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 10.5,
 fontWeight: FontWeight.w700,
 color:
 active ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _MobileBottomItem extends StatelessWidget {
 const _MobileBottomItem({
 required this.icon,
 required this.label,
 this.active = false,
 this.onTap,
 });

 final IconData icon;
 final String label;
 final bool active;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 final color = active ? const Color(0xFFD97706) : const Color(0xFF94A3B8);
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(16),
 child: SizedBox(
 width: 58,
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(icon, size: 17, color: color),
 const SizedBox(height: 3),
 Text(
 label,
 style: TextStyle(
 fontSize: 9.5,
 fontWeight: FontWeight.w600,
 color: color,
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _RiskIdentificationTransitionDialog extends StatefulWidget {
 const _RiskIdentificationTransitionDialog();

 @override
 State<_RiskIdentificationTransitionDialog> createState() =>
 _RiskIdentificationTransitionDialogState();
}

class _RiskIdentificationTransitionDialogState
 extends State<_RiskIdentificationTransitionDialog>
 with TickerProviderStateMixin {
 late final AnimationController _rotationController;
 late final AnimationController _pulseController;
 Timer? _dismissTimer;

 @override
 void initState() {
 super.initState();
 _rotationController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1400),
 )..repeat();

 _pulseController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1600),
 lowerBound: 0.0,
 upperBound: 1.0,
 )..repeat(reverse: true);

 // Keep the dialog for 3 seconds, then proceed
 _dismissTimer = Timer(const Duration(seconds: 3), () {
 if (mounted) {
 Navigator.of(context).pop();
 }
 });
 }

 @override
 void dispose() {
 _dismissTimer?.cancel();
 _rotationController.dispose();
 _pulseController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Dialog(
 backgroundColor: Colors.transparent,
 elevation: 0,
 insetPadding: const EdgeInsets.symmetric(horizontal: 24),
 child: Center(
 child: TweenAnimationBuilder<double>(
 tween: Tween(begin: 0, end: 1),
 duration: const Duration(seconds: 10),
 builder: (context, progress, _) {
 final percent = (progress * 100).clamp(0, 100).toInt();
 return AnimatedScale(
 scale: 1.0 + (_pulseController.value * 0.02),
 duration: const Duration(milliseconds: 200),
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 boxShadow: const [
 BoxShadow(
 color: Color(0x22000000),
 blurRadius: 30,
 offset: Offset(0, 24),
 ),
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 gradient: RadialGradient(
 center: const Alignment(-0.4, -0.6),
 radius: 1.2,
 colors: [
 const Color(0xFFFFF5B0).withOpacity(0.40),
 Colors.white,
 ],
 stops: const [0.0, 1.0],
 ),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFD700),
 borderRadius: BorderRadius.circular(40),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 RotationTransition(
 turns: _rotationController,
 child: const Icon(
 Icons.auto_awesome,
 color: Colors.black,
 size: 22,
 ),
 ),
 const SizedBox(width: 12),
 const Text(
 'Preparing Workspace',
 style: TextStyle(
 color: Colors.black,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 _ShimmerText(
 text: 'Transferring initiation notes and context…',
 baseColor: const Color(0xFF3A3C41),
 highlightColor: const Color(0xFF90939A),
 ),
 const SizedBox(height: 18),
 SizedBox(
 width: 160,
 height: 160,
 child: Stack(
 alignment: Alignment.center,
 children: [
 CustomPaint(
 size: const Size.square(160),
 painter: _RingPainter(progress: progress),
 ),
 Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '$percent%',
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w800,
 color: Color(0xFF2F3136),
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Optimizing',
 style: TextStyle(
 fontSize: 12.5,
 color: Color(0xFF666A71),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 const Text(
 'This will take about 10 seconds…',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF8A8D93),
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),
 );
 }
}

class _ShimmerText extends StatefulWidget {
 const _ShimmerText(
 {required this.text,
 required this.baseColor,
 required this.highlightColor});

 final String text;
 final Color baseColor;
 final Color highlightColor;

 @override
 State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
 with SingleTickerProviderStateMixin {
 late final AnimationController _controller;

 @override
 void initState() {
 super.initState();
 _controller = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 2200),
 )..repeat();
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return AnimatedBuilder(
 animation: _controller,
 builder: (_, __) {
 return ShaderMask(
 blendMode: BlendMode.srcIn,
 shaderCallback: (bounds) {
 final width = bounds.width;
 return LinearGradient(
 begin: Alignment.centerLeft,
 end: Alignment.centerRight,
 colors: [
 widget.baseColor.withOpacity(0.6),
 widget.highlightColor,
 widget.baseColor.withOpacity(0.6),
 ],
 stops: [
 (_controller.value - 0.3).clamp(0.0, 1.0),
 _controller.value.clamp(0.0, 1.0),
 (_controller.value + 0.3).clamp(0.0, 1.0),
 ],
 transform: GradientRotation(0),
 ).createShader(Rect.fromLTWH(0, 0, width, bounds.height));
 },
 child: Text(
 widget.text,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 );
 },
 );
 }
}

class _RingPainter extends CustomPainter {
 _RingPainter({required this.progress});

 final double progress; // 0..1

 @override
 void paint(Canvas canvas, Size size) {
 final center = Offset(size.width / 2, size.height / 2);
 final radius = size.width / 2 - 8;

 // Track
 final trackPaint = Paint()
 ..color = const Color(0xFFF0F1F4)
 ..strokeWidth = 10
 ..style = PaintingStyle.stroke
 ..strokeCap = StrokeCap.round;
 canvas.drawCircle(center, radius, trackPaint);

 // Progress arc with sweep gradient
 final rect = Rect.fromCircle(center: center, radius: radius);
 final startAngle = -90 * 3.1415926535 / 180; // -90 degrees
 final sweep = progress * 2 * 3.1415926535;

 final gradient = SweepGradient(
 startAngle: 0,
 endAngle: 2 * 3.1415926535,
 colors: const [
 Color(0xFFFFD700),
 Color(0xFFFFA800),
 Color(0xFFFFD700),
 ],
 stops: const [0.0, 0.5, 1.0],
 );

 final progressPaint = Paint()
 ..shader = gradient.createShader(rect)
 ..strokeWidth = 10
 ..style = PaintingStyle.stroke
 ..strokeCap = StrokeCap.round;

 canvas.drawArc(rect, startAngle, sweep, false, progressPaint);

 // Small moving dot at the end of arc
 final endX = center.dx + radius * math.cos(startAngle + sweep);
 final endY = center.dy + radius * math.sin(startAngle + sweep);
 final dotPaint = Paint()..color = const Color(0xFFFFA800);
 canvas.drawCircle(Offset(endX, endY), 4, dotPaint);
 }

 @override
 bool shouldRepaint(covariant _RingPainter oldDelegate) =>
 oldDelegate.progress != progress;
}

class _RequirementItem extends StatelessWidget {
 const _RequirementItem({required this.icon, required this.text});

 final IconData icon;
 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 Icon(icon, size: 20, color: const Color(0xFFFFD700)),
 const SizedBox(width: 12),
 Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
 ],
 ),
 );
 }
}
