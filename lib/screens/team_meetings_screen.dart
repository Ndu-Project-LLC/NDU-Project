import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/meeting_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/progress_tracking_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/team_meetings_resource_grid.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart' as launch;
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class TeamMeetingsScreen extends StatefulWidget {
 const TeamMeetingsScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const TeamMeetingsScreen(),
 destinationCheckpoint: 'team_meetings',
 );
 }

 @override
 State<TeamMeetingsScreen> createState() => _TeamMeetingsScreenState();
}

class _TeamMeetingsScreenState extends State<TeamMeetingsScreen> {
 List<MeetingRow> _meetingRows = [];
 List<launch.LaunchEntry> _agendasPrep = [];
 List<launch.LaunchEntry> _decisionsOutcomes = [];
 List<String> _staffRoles = []; // Roles from Staff Team section
 bool _loading = true;
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;
 Timer? _autoSaveDebounce;

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
 _loadData();
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) {
 if (mounted) setState(() => _loading = false);
 return;
 }

 try {
 // Load meeting rows
 final meetings =
 await ExecutionPhaseService.loadMeetingRows(projectId: projectId);

 // Load staff roles from Staff Team section
 final staffRows =
 await ExecutionPhaseService.loadStaffingRows(projectId: projectId);
 final roles =
 staffRows.map((r) => r.role).where((r) => r.isNotEmpty).toList();

 // Load other sections
 final data = await ExecutionPhaseService.loadPageData(
 projectId: projectId,
 pageKey: 'team_meetings',
 );

 if (mounted) {
 setState(() {
 _meetingRows = meetings;
 _staffRoles = roles;
 _agendasPrep = data?['agendas']
 ?.map((e) => launch.LaunchEntry(
 title: e.title,
 details: e.details,
 status: e.status,
 ))
 .toList() ??
 [];
 _decisionsOutcomes = data?['decisions']
 ?.map((e) => launch.LaunchEntry(
 title: e.title,
 details: e.details,
 status: e.status,
 ))
 .toList() ??
 [];
 _loading = false;
 });
 }
 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading team meetings data: $e');
 if (mounted) setState(() => _loading = false);
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_meetingRows.isNotEmpty &&
 _agendasPrep.isNotEmpty &&
 _decisionsOutcomes.isNotEmpty) {
 return;
 }

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final contextText =
 ExecutionPhaseAiSeed.buildContext(context, section: 'Team Meetings');
 final ai = OpenAiServiceSecure();

 final generatedMeetings = _meetingRows.isEmpty
 ? await ai.generateMeetingRows(
 context: contextText,
 availableRoles: _staffRoles,
 maxRows: 3,
 )
 : _meetingRows;

 final generatedEntries = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Team Meetings',
 sections: const {
 'agendas': 'Agendas and pre-read items for team meetings',
 'decisions': 'Key decisions and outcomes to capture',
 },
 itemsPerSection: 3,
 );

 final agendas =
 generatedEntries['agendas']?.take(4).toList() ?? const [];
 final decisions =
 generatedEntries['decisions']?.take(4).toList() ?? const [];

 if (!mounted) return;
 setState(() {
 if (_meetingRows.isEmpty && generatedMeetings.isNotEmpty) {
 _meetingRows = generatedMeetings;
 }
 if (_agendasPrep.isEmpty && agendas.isNotEmpty) {
 _agendasPrep = agendas;
 }
 if (_decisionsOutcomes.isEmpty && decisions.isNotEmpty) {
 _decisionsOutcomes = decisions;
 }
 });

 await _persistChanges();
 } catch (e) {
 debugPrint('Error auto-generating team meetings data: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 void _onMeetingsChanged(List<MeetingRow> meetings) {
 setState(() => _meetingRows = meetings);
 _autoSave();
 }

 void _autoSave() {
 _autoSaveDebounce?.cancel();
 _autoSaveDebounce = Timer(const Duration(milliseconds: 1500), () {
 _persistChanges();
 });
 }

 Future<void> _persistChanges() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 await ExecutionPhaseService.saveMeetingRows(
 projectId: projectId,
 rows: _meetingRows,
 userId: FirebaseAuth.instance.currentUser?.uid,
 );

 // Also save other sections
 await ExecutionPhaseService.savePageData(
 projectId: projectId,
 pageKey: 'team_meetings',
 sections: {
 'agendas': _agendasPrep,
 'decisions': _decisionsOutcomes,
 },
 userId: FirebaseAuth.instance.currentUser?.uid,
 );
 } catch (e) {
 debugPrint('Error persisting team meetings data: $e');
 }
 }

 @override
 void dispose() {
 _autoSaveDebounce?.cancel();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 16 : 32;

 return ResponsiveScaffold(
 activeItemLabel: 'Team Meetings',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: isMobile ? 16 : 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Team Meetings',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 if (_loading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: CircularProgressIndicator(),
 ))
 else ...[
 // Meeting Planner - Resource Grid
 TeamMeetingsResourceGrid(
 meetings: _meetingRows,
 staffRoles: _staffRoles,
 onMeetingsChanged: _onMeetingsChanged,
 ),
 const SizedBox(height: 24),
 // Agendas & Prep
 launch.LaunchEditableSection(
 title: 'Agendas & prep',
 description:
 'Capture agenda templates, pre-reads, and facilitation notes.',
 entries: _agendasPrep,
 onAdd: () => _addAgendaPrep(),
  onRemove: (i) async {
  final ok = await launchConfirmDelete(context, itemName: 'agenda item');
  if (!ok) return;
  setState(() => _agendasPrep.removeAt(i));
  _autoSave();
  },
 onEdit: (i, entry) => _editAgendaPrep(i, entry),
 showStatusChip: false,
 ),
 const SizedBox(height: 16),
 // Decisions & Outcomes
 launch.LaunchEditableSection(
 title: 'Decisions & outcomes',
 description: 'Log decisions and follow-ups from meetings.',
 entries: _decisionsOutcomes,
 onAdd: () => _addDecisionOutcome(),
  onRemove: (i) async {
  final ok = await launchConfirmDelete(context, itemName: 'decision');
  if (!ok) return;
  setState(() => _decisionsOutcomes.removeAt(i));
  _autoSave();
  },
 onEdit: (i, entry) => _editDecisionOutcome(i, entry),
 ),
 ],
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Staff Team',
 nextLabel: 'Next: Progress Tracking',
 onBack: () => StaffTeamScreen.open(context),
 onNext: () => ProgressTrackingScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Meeting Intelligence Hub',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 _loading ? 'Execution Phase · Loading...' : 'Execution Phase',
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: const Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 ],
 );
 }

 Future<void> _addAgendaPrep() async {
 final entry = await launch.showLaunchEntryDialog(
 context,
 titleLabel: 'Agenda item',
 detailsLabel: 'Details',
 includeStatus: false,
 );
 if (entry != null && mounted) {
 setState(() => _agendasPrep.add(entry));
 _autoSave();
 }
 }

 Future<void> _editAgendaPrep(
 int index, launch.LaunchEntry currentEntry) async {
 final entry = await launch.showLaunchEntryDialog(
 context,
 titleLabel: 'Agenda item',
 detailsLabel: 'Details',
 includeStatus: false,
 initialEntry: currentEntry,
 );
 if (entry != null && mounted) {
 setState(() => _agendasPrep[index] = entry);
 _autoSave();
 }
 }

 Future<void> _addDecisionOutcome() async {
 final entry = await launch.showLaunchEntryDialog(
 context,
 titleLabel: 'Decision',
 detailsLabel: 'Details',
 includeStatus: true,
 );
 if (entry != null && mounted) {
 setState(() => _decisionsOutcomes.add(entry));
 _autoSave();
 }
 }

 Future<void> _editDecisionOutcome(
 int index, launch.LaunchEntry currentEntry) async {
 final entry = await launch.showLaunchEntryDialog(
 context,
 titleLabel: 'Decision',
 detailsLabel: 'Details',
 includeStatus: true,
 initialEntry: currentEntry,
 );
 if (entry != null && mounted) {
 setState(() => _decisionsOutcomes[index] = entry);
 _autoSave();
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Team Meetings',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_team_meetings_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
