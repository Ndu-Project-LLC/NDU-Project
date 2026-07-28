import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/models/project_data_model.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class StakeholderManagementScreen extends StatefulWidget {
 const StakeholderManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const StakeholderManagementScreen()),
 );
 }

 @override
 State<StakeholderManagementScreen> createState() =>
 _StakeholderManagementScreenState();
}

class _StakeholderManagementScreenState
 extends State<StakeholderManagementScreen> {
 int _activeTabIndex = 0; // 0 = Stakeholders, 1 = Engagement Plans, 2 = Project Team, 3 = Mapping, 4 = Announcements

 final _stakeholderSaveDebounce = _Debouncer();
 final _planSaveDebounce = _Debouncer();
 final ScrollController _pageScrollController = ScrollController();
 String _searchQuery = '';

 @override
 void initState() {
 super.initState();
 // Auto-populate stakeholders from initiation phase on first load
 // if the stakeholders list is empty.
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final data = ProjectDataHelper.getData(context);
 if (data.stakeholderEntries.isEmpty) {
 _autoPopulateFromInitiation();
 }
 });
 }

 @override
 void dispose() {
 _stakeholderSaveDebounce.dispose();
 _planSaveDebounce.dispose();
 _pageScrollController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 36;
 final projectData = ProjectDataHelper.getDataListening(context);

 // Filter stakeholders and plans based on search
 final filteredStakeholders = projectData.stakeholderEntries.where((s) {
 if (_searchQuery.isEmpty) return true;
 final q = _searchQuery.toLowerCase();
 return s.name.toLowerCase().contains(q) ||
 s.organization.toLowerCase().contains(q) ||
 s.role.toLowerCase().contains(q);
 }).toList();

 final filteredPlans = projectData.engagementPlanEntries.where((p) {
 if (_searchQuery.isEmpty) return true;
 final q = _searchQuery.toLowerCase();
 return p.stakeholder.toLowerCase().contains(q) ||
 p.objective.toLowerCase().contains(q);
 }).toList();

 final sidebarWidth = AppBreakpoints.sidebarWidth(context);

 final header = PlanningPhaseHeader(
 title: 'Stakeholder Management Plan',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'Stakeholder Management Plan',
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'stakeholder_management'),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(context, 'stakeholder_management'), onExportPdf: _exportPdf);

 final scrollableContent = SingleChildScrollView(
 controller: _pageScrollController,
 child: Padding(
 padding:
 EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _TitleSection(
 showButtonsBelow: isMobile,
 onExport: () {},
 onAddProject: () {},
 onAutoPopulate: _autoPopulateFromInitiation,
 ),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Stakeholder Notes',
 sectionLabel: 'Stakeholder Management',
 noteKey: 'planning_stakeholder_notes',
 checkpoint: 'stakeholder_management',
 description:
 'Capture overall stakeholder strategy, risks, and communication protocols.',
 ),
 const SizedBox(height: 32),
 _StatsRow(
 totalStakeholders: projectData.stakeholderEntries.length,
 externalCount: projectData.stakeholderEntries
 .where((s) => s.organization.toLowerCase() != 'internal')
 .length,
 ),
 const SizedBox(height: 32),
 _InfluenceInterestMatrix(
 stakeholders: projectData.stakeholderEntries),
 const SizedBox(height: 32),
  _EngagementSection(
  activeTabIndex: _activeTabIndex,
  onTabChanged: (idx) => setState(() => _activeTabIndex = idx),
  stakeholderTable: _StakeholdersTable(
  entries: filteredStakeholders,
  isLoading: false,
  onChanged: _updateStakeholder,
  onDelete: _deleteStakeholder,
  ),
  planTable: _EngagementPlansTable(
  entries: filteredPlans,
  isLoading: false,
  onChanged: _updateEngagementPlan,
  onDelete: _deleteEngagementPlan,
  ),
  teamTable: _ProjectTeamTable(
  entries: projectData.engagementPlanEntries,
  staffingRequirements: projectData.staffingRequirements,
  isLoading: false,
  onChanged: _updateEngagementPlan,
  onDelete: _deleteEngagementPlan,
  onImport: _importFromStaffingPlan,
  ),
  mappingTable: _StakeholderMappingTab(
  stakeholders: projectData.stakeholderEntries,
  ),
  announcementsWidget: _AnnouncementsTab(
  stakeholders: projectData.stakeholderEntries,
  ),
  onAdd:
  _activeTabIndex == 0 ? _addStakeholder : _addEngagementPlan,
  onImportTeam: _importFromStaffingPlan,
  onSearch: (v) => setState(() => _searchQuery = v),
  ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel:
 PlanningPhaseNavigation.backLabel('stakeholder_management'),
 nextLabel:
 PlanningPhaseNavigation.nextLabel('stakeholder_management'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'stakeholder_management'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'stakeholder_management'),
 ),
 const SizedBox(height: 60),
 ],
 ),
 ),
 );

 // --- Mobile layout ---
 if (isMobile) {
 return Scaffold(
 backgroundColor: Colors.white,
 drawer: Drawer(
 width: sidebarWidth,
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Stakeholder Management',
 showHeader: true,
 ),
 ),
 ),
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 header,
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Stakeholder Management',
 ),
 ),
 scrollableContent,
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 // --- Desktop layout ---
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 header,
 Expanded(
 child: Row(
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Stakeholder Management'),
 ),
 Expanded(
 child: Stack(
 children: [
 scrollableContent,
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 // Manual persistence methods removed as we now use ProjectDataHelper.updateAndSave

 void _addStakeholder() async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'stakeholder_management',
 dataUpdater: (d) => d.copyWith(
 stakeholderEntries: [...d.stakeholderEntries, StakeholderEntry.empty()],
 ),
 );
 _scrollToLatestInlineRow();
 }

 void _updateStakeholder(StakeholderEntry updated) async {
 final provider = ProjectDataHelper.getProvider(context);
 final entries =
 List<StakeholderEntry>.from(provider.projectData.stakeholderEntries);
 final index = entries.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 entries[index] = updated.copyWith(updatedAt: DateTime.now());

 // Update local state immediately for responsive UI (matrix updates),
 // then debounce the remote save to reduce write volume.
 provider.updateField((d) => d.copyWith(stakeholderEntries: entries));
 _stakeholderSaveDebounce.run(() async {
 await provider.saveToFirebase(checkpoint: 'stakeholder_management');
 });
 }

  void _deleteStakeholder(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'stakeholder');
  if (!ok) return;
  await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'stakeholder_management',
 dataUpdater: (d) => d.copyWith(
 stakeholderEntries:
 d.stakeholderEntries.where((e) => e.id != id).toList(),
 ),
 );
 }

 void _addEngagementPlan() async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'stakeholder_management',
 dataUpdater: (d) => d.copyWith(
 engagementPlanEntries: [
 ...d.engagementPlanEntries,
 EngagementPlanEntry.empty()
 ],
 ),
 );
 _scrollToLatestInlineRow();
 }

 void _updateEngagementPlan(EngagementPlanEntry updated) async {
 final projectData = ProjectDataHelper.getDataListening(context);
 final entries =
 List<EngagementPlanEntry>.from(projectData.engagementPlanEntries);
 final index = entries.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 entries[index] = updated.copyWith(updatedAt: DateTime.now());

 _planSaveDebounce.run(() async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'stakeholder_management',
 showSnackbar: false,
 dataUpdater: (d) => d.copyWith(engagementPlanEntries: entries),
 );
 });
 }

  void _deleteEngagementPlan(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'engagement plan');
  if (!ok) return;
  await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'stakeholder_management',
 dataUpdater: (d) => d.copyWith(
 engagementPlanEntries:
 d.engagementPlanEntries.where((e) => e.id != id).toList(),
 ),
  );
  }

  void _importFromStaffingPlan() async {
  final projectData = ProjectDataHelper.getDataListening(context);
  final requirements = projectData.staffingRequirements;
  if (requirements.isEmpty) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  content: Text('No staffing plan entries found. Add positions in the Staffing Plan first.')));
  return;
  }

  final selected = await showDialog<List<StaffingRequirement>>(
  context: context,
  builder: (ctx) => _ImportFromStaffingDialog(requirements: requirements),
  );
  if (selected == null || selected.isEmpty || !mounted) return;

  final now = DateTime.now();
  final newPlans = selected.map((r) {
  final displayName = r.personName.trim().isNotEmpty ? r.personName.trim() : r.title;
  return EngagementPlanEntry(
  id: '${now.microsecondsSinceEpoch}_${r.id}',
  stakeholder: displayName,
  objective: 'Engage $displayName — manage closely as project team member',
  method: 'Email + Team Meeting',
  frequency: 'Weekly',
  owner: 'Project Manager',
  status: 'Planned',
  nextTouchpoint: '',
  notes: 'Imported from Staffing Plan (${r.title})',
  email: r.email,
  phone: r.phone,
  location: r.location,
  quarter: '',
  dataLinks: '',
  isProjectTeam: true,
  createdAt: now,
  updatedAt: now,
  );
  }).toList();

  await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'stakeholder_management',
  dataUpdater: (d) => d.copyWith(
  engagementPlanEntries: [...d.engagementPlanEntries, ...newPlans],
  ),
  );
  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('Imported ${newPlans.length} team member(s) from Staffing Plan.'),
  backgroundColor: const Color(0xFF10B981),
  ));
  }
  }

  void _scrollToLatestInlineRow() {
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 await Future<void>.delayed(const Duration(milliseconds: 120));
 if (!mounted || !_pageScrollController.hasClients) return;
 final position = _pageScrollController.position;
 await _pageScrollController.animateTo(
 position.maxScrollExtent,
 duration: const Duration(milliseconds: 420),
 curve: Curves.easeOutCubic,
 );
 });
 }

 Future<void> _autoPopulateFromInitiation() async {
 final projectData = ProjectDataHelper.getProvider(context).projectData;
 final coreStakeholders = projectData.coreStakeholdersData;
 if (coreStakeholders == null) {
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('No stakeholder data found in Initiation Phase.')));
 return;
 }

 final solutionData = coreStakeholders.solutionStakeholderData.firstWhere(
 (s) => s.solutionTitle == projectData.preferredSolution?.title,
 orElse: () => coreStakeholders.solutionStakeholderData.isNotEmpty
 ? coreStakeholders.solutionStakeholderData.first
 : SolutionStakeholderData(),
 );

 if (solutionData.solutionTitle.isEmpty &&
 coreStakeholders.solutionStakeholderData.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('No stakeholder data found in Initiation Phase.')));
 return;
 }

 final List<StakeholderEntry> newEntries = [];

 void parseAndAdd(String text, String org) {
 final lines = text.split('\n');
 for (var line in lines) {
 final cleaned = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
 if (cleaned.isNotEmpty) {
 newEntries.add(StakeholderEntry(
 id: DateTime.now().microsecondsSinceEpoch.toString() +
 cleaned.hashCode.toString(),
 name: cleaned,
 organization: org,
 role: 'TBD',
 contactInfo: '',
 influence: 'Medium',
 interest: 'Medium',
 channel: 'Email',
 owner: 'Project Manager',
 notes: 'Added from Initiation Phase',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 ));
 }
 }
 }

 parseAndAdd(solutionData.internalStakeholders, 'Internal');
 parseAndAdd(solutionData.externalStakeholders, 'External');

 // Also parse organisation context for additional internal teams/groups
 // that may influence or be influenced by the project.
 final orgContext = coreStakeholders.organisationContext.trim();
 if (orgContext.isNotEmpty) {
 // Extract team/group names from organisation description
 // Look for lines or phrases mentioning teams, departments, groups
 final orgLines = orgContext.split('\n');
 for (var line in orgLines) {
 final cleaned = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
 if (cleaned.isNotEmpty &&
 !newEntries.any((e) => e.name.toLowerCase() == cleaned.toLowerCase())) {
 // Only add if it looks like a team/group/department reference
 final lowerLine = cleaned.toLowerCase();
 if (lowerLine.contains('team') ||
 lowerLine.contains('department') ||
 lowerLine.contains('group') ||
 lowerLine.contains('division') ||
 lowerLine.contains('unit') ||
 lowerLine.contains('office') ||
 lowerLine.contains('finance') ||
 lowerLine.contains('it ') ||
 lowerLine.contains('operations') ||
 lowerLine.contains('hr') ||
 lowerLine.contains('legal') ||
 lowerLine.contains('marketing') ||
 lowerLine.contains('sales') ||
 lowerLine.contains('engineering') ||
 lowerLine.contains('design') ||
 lowerLine.contains('quality') ||
 lowerLine.contains('security')) {
 newEntries.add(StakeholderEntry(
 id: DateTime.now().microsecondsSinceEpoch.toString() +
 cleaned.hashCode.toString(),
 name: cleaned,
 organization: 'Internal',
 role: 'Team/Group',
 contactInfo: '',
 influence: 'Medium',
 interest: 'Medium',
 channel: 'Email',
 owner: 'Project Manager',
 notes: 'Identified from organisation context in Initiation Phase',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 ));
 }
 }
 }
 }

 // Show prompt asking about additional teams/groups
 if (mounted) {
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Teams & Groups Check'),
 content: const Text(
 'Are there any other teams or groups in your organisation that would '
 'influence this project or be influenced by it?\n\n'
 'Consider:\n'
 '• Teams that will contribute resources or expertise\n'
 '• Departments affected by the project outcomes\n'
 '• Groups that need to be consulted or informed\n'
 '• External partners or vendors with influence\n\n'
 'You can add them manually using the "Add Stakeholder" button.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Got it'),
 ),
 ],
 ),
 );
 }

 if (newEntries.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('No stakeholders found in Initiation Phase.')));
 return;
 }

  // Generate engagement plans for each stakeholder
  final now = DateTime.now();
  final engagementPlans = newEntries
  .map((s) => EngagementPlanEntry(
  id: '${now.microsecondsSinceEpoch}_${s.id}',
  stakeholder: s.name,
  objective:
  'Engage ${s.name} to align on project objectives and gather input',
  method: 'Regular meetings',
  frequency: 'Weekly',
  owner: 'Project Manager',
  status: 'Planned',
  nextTouchpoint: '',
  notes: 'Auto-generated from Initiation Phase stakeholder data',
  createdAt: now,
  updatedAt: now,
  ))
  .toList();

  // Also generate engagement plans for project team members from staffing plan
  final staffingRequirements = projectData.staffingRequirements;
  final teamPlans = staffingRequirements
  .where((r) => r.personName.trim().isNotEmpty || r.title.trim().isNotEmpty)
  .map((r) {
  final displayName = r.personName.trim().isNotEmpty ? r.personName.trim() : r.title;
  return EngagementPlanEntry(
  id: '${now.microsecondsSinceEpoch}_team_${r.id}',
  stakeholder: displayName,
  objective: 'Engage $displayName — manage closely as project team member',
  method: 'Email + Team Meeting',
  frequency: 'Weekly',
  owner: 'Project Manager',
  status: 'Planned',
  nextTouchpoint: '',
  notes: 'Auto-generated from Staffing Plan (${r.title})',
  email: r.email,
  phone: r.phone,
  location: r.location,
  quarter: '',
  dataLinks: '',
  isProjectTeam: true,
  createdAt: now,
  updatedAt: now,
  );
  })
  .toList();

  await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'stakeholder_management',
  dataUpdater: (d) => d.copyWith(
  stakeholderEntries: newEntries,
  engagementPlanEntries: [
  ...d.engagementPlanEntries,
  ...engagementPlans,
  ...teamPlans,
  ],
  ),
  );
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text(
  'Loaded ${newEntries.length} stakeholders, ${engagementPlans.length} plans, and ${teamPlans.length} team members.',
  ),
  ),
  );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getDataListening(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Stakeholder Management Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_stakeholder_management_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _TitleSection extends StatelessWidget {
 const _TitleSection(
 {required this.showButtonsBelow,
 required this.onExport,
 required this.onAddProject,
 this.onAutoPopulate});

 final bool showButtonsBelow;
 final VoidCallback onExport;
 final VoidCallback onAddProject;
 final VoidCallback? onAutoPopulate;

 @override
 Widget build(BuildContext context) {
 const buttons = SizedBox.shrink();

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Stakeholder Management Plan',
 style: TextStyle(
 fontSize: 32,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 10),
 Text(
 'Define how each influence/interest stakeholder group will be engaged, communicated with, and managed throughout the project. AI should help develop a landing plan that states how each of the sections would be communicated with (email, meetings, announcements, etc.)',
 style: TextStyle(
 fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
 ),
 ],
 ),
 ),
 if (!showButtonsBelow) ...[
 if (onAutoPopulate != null)
 _topButton(
 label: 'Auto-populate',
 icon: Icons.auto_awesome,
 color: const Color(0xFFFFC107),
 textColor: Colors.black,
 onPressed: onAutoPopulate!),
 const SizedBox(width: 12),
 buttons,
 ],
 ],
 ),
 if (showButtonsBelow) ...[
 const SizedBox(height: 16),
 if (onAutoPopulate != null) ...[
 _topButton(
 label: 'Auto-populate from Initiation',
 icon: Icons.auto_awesome,
 color: const Color(0xFFFFC107),
 textColor: Colors.black,
 onPressed: onAutoPopulate!),
 const SizedBox(height: 12),
 ],
 buttons,
 ],
 ],
 );
 }

 Widget _topButton(
 {required String label,
 required IconData icon,
 required Color color,
 required Color textColor,
 required VoidCallback onPressed}) {
 return ElevatedButton.icon(
 onPressed: onPressed,
 icon: Icon(icon, size: 16, color: textColor),
 label: Text(label,
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
 style: ElevatedButton.styleFrom(
 backgroundColor: color,
 foregroundColor: textColor,
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }
}

class _StatsRow extends StatelessWidget {
 const _StatsRow({
 required this.totalStakeholders,
 required this.externalCount,
 });

 final int totalStakeholders;
 final int externalCount;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 final children = [
 _MetricCard(
 title: 'Total Stakeholders',
 value: totalStakeholders.toString(),
 icon: Icons.people_alt_outlined,
 accentColor: const Color(0xFFFBBF24),
 ),
 _MetricCard(
 title: 'External Partners',
 value: externalCount.toString(),
 icon: Icons.public_rounded,
 accentColor: const Color(0xFF10B981),
 ),
 ];

 if (isMobile) {
 return Column(
 children: [
 for (int i = 0; i < children.length; i++) ...[
 if (i != 0) const SizedBox(height: 16),
 children[i],
 ],
 ],
 );
 }

 return Row(
 children: [
 for (int i = 0; i < children.length; i++) ...[
 if (i != 0) const SizedBox(width: 16),
 Expanded(child: children[i]),
 ],
 ],
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard(
 {required this.title,
 required this.value,
 required this.icon,
 required this.accentColor});

 final String title;
 final String value;
 final IconData icon;
 final Color accentColor;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000), blurRadius: 24, offset: Offset(0, 10)),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 color: accentColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(icon, color: accentColor, size: 26),
 ),
 const SizedBox(width: 16),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style:
 const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Text(value,
 style: const TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 ],
 ),
 ],
 ),
 );
 }
}

// ignore: unused_element
class _InfoCardsRow extends StatelessWidget {
 const _InfoCardsRow({required this.isMobile});

 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 final cards = [
 const _CommunicationFrequencyCard(),
 const _LevelDistributionCard(),
 ];

 if (isMobile) {
 return Column(
 children: [
 cards[0],
 const SizedBox(height: 16),
 cards[1],
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: cards[0]),
 const SizedBox(width: 16),
 Expanded(child: cards[1]),
 ],
 );
 }
}

class _CommunicationFrequencyCard extends StatelessWidget {
 const _CommunicationFrequencyCard();

 static const List<String> _items = [];

 @override
 Widget build(BuildContext context) {
 if (_items.isEmpty) {
 return const _SectionEmptyState(
 title: 'No cadence defined',
 message: 'Add communication frequency to align stakeholders.',
 icon: Icons.forum_outlined,
 );
 }
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Communication Frequency',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 16),
 for (var item in _items)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 4),
 child:
 Icon(Icons.circle, size: 8, color: Color(0xFF111827)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(item,
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF374151))),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _LevelDistributionCard extends StatelessWidget {
 const _LevelDistributionCard();

 @override
 Widget build(BuildContext context) {
 return const _SectionEmptyState(
 title: 'No influence distribution yet',
 message: 'Map stakeholder influence to visualize engagement tiers.',
 icon: Icons.pie_chart_outline,
 );
 }
}

class _InfluenceInterestMatrix extends StatelessWidget {
  const _InfluenceInterestMatrix({required this.stakeholders});

  final List<StakeholderEntry> stakeholders;

  /// Classifies a stakeholder into a quadrant using Mendelow's matrix.
  /// Medium values are routed to the most appropriate quadrant.
  static String _quadrantFor(StakeholderEntry s) {
    final influence = s.influence.toLowerCase();
    final interest = s.interest.toLowerCase();
    final highInfluence =
        influence == 'high' || influence.contains('significant');
    final highInterest =
        interest == 'high' || interest.contains('significant');
    final lowInfluence =
        influence == 'low' || influence.contains('minimal');
    final lowInterest =
        interest == 'low' || interest.contains('minimal');

    if (highInfluence && highInterest) return 'Manage Closely';
    if (highInfluence && !highInterest) return 'Keep Satisfied';
    if (!highInfluence && highInterest) return 'Keep Informed';
    return 'Monitor';
  }

  @override
  Widget build(BuildContext context) {
    final manageClosely =
        stakeholders.where((s) => _quadrantFor(s) == 'Manage Closely').toList();
    final keepSatisfied =
        stakeholders.where((s) => _quadrantFor(s) == 'Keep Satisfied').toList();
    final keepInformed =
        stakeholders.where((s) => _quadrantFor(s) == 'Keep Informed').toList();
    final monitor =
        stakeholders.where((s) => _quadrantFor(s) == 'Monitor').toList();

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Influence / Interest Matrix',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 16),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x05000000),
 blurRadius: 10,
 offset: Offset(0, 4)),
 ],
 ),
 child: Column(
 children: [
 // Column Headers (Interest)
 Padding(
 padding: const EdgeInsets.only(top: 16, bottom: 8),
 child: Row(
 children: [
 const SizedBox(width: 40), // Spacing for Y-axis label
 Expanded(child: _axisHeader('LOW INTEREST')),
 Expanded(child: _axisHeader('HIGH INTEREST')),
 ],
 ),
 ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Y-axis label (Influence)
                      _verticalAxisLabel('HIGH INFLUENCE'),
                      Expanded(
                        child: _matrixQuadrant(
                          label: 'Keep Satisfied',
                          color: const Color(0xFFFFF7E6),
                          accentColor: const Color(0xFFFBBF24),
                          stakeholders: keepSatisfied,
                        ),
                      ),
                      Expanded(
                        child: _matrixQuadrant(
                          label: 'Manage Closely (Key Players)',
                          color: const Color(0xFFFEF2F2),
                          accentColor: const Color(0xFFEF4444),
                          stakeholders: manageClosely,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _verticalAxisLabel('LOW INFLUENCE'),
                      Expanded(
                        child: _matrixQuadrant(
                          label: 'Monitor (Minimal Effort)',
                          color: const Color(0xFFF9FAFB),
                          accentColor: const Color(0xFF6B7280),
                          stakeholders: monitor,
                        ),
                      ),
                      Expanded(
                        child: _matrixQuadrant(
                          label: 'Keep Informed',
                          color: const Color(0xFFECFDF5),
                          accentColor: const Color(0xFF10B981),
                          stakeholders: keepInformed,
                        ),
                      ),
                    ],
                  ),
 const SizedBox(height: 16),
 ],
 ),
 ),
 ],
 );
 }

 Widget _axisHeader(String text) {
 return Center(
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.2,
 color: Color(0xFF9CA3AF)),
 ),
 );
 }

 Widget _verticalAxisLabel(String text) {
 return Container(
 width: 40,
 height: 140,
 alignment: Alignment.center,
 child: RotatedBox(
 quarterTurns: 3,
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.2,
 color: Color(0xFF9CA3AF)),
 ),
 ),
 );
 }

 Widget _matrixQuadrant({
 required String label,
 required Color color,
 required Color accentColor,
 required List<StakeholderEntry> stakeholders,
 }) {
 return Container(
 height: 140,
 margin: const EdgeInsets.all(4),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: accentColor.withOpacity(0.2)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 8,
 height: 8,
 decoration:
 BoxDecoration(color: accentColor, shape: BoxShape.circle),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: accentColor),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Expanded(
 child: stakeholders.isEmpty
 ? Center(
 child: Text(
 'None',
 style: TextStyle(
 fontSize: 11,
 fontStyle: FontStyle.italic,
 color: accentColor.withOpacity(0.5)),
 ),
 )
 : SingleChildScrollView(
 child: Wrap(
 spacing: 6,
 runSpacing: 6,
 children: stakeholders
 .map((s) => _stakeholderChip(s, accentColor))
 .toList(),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _stakeholderChip(StakeholderEntry s, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.7),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: color.withOpacity(0.1)),
 ),
 child: Text(
 s.name.isEmpty ? 'Unnamed' : s.name,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: color.withOpacity(0.8)),
 ),
 );
 }
}

class _SectionEmptyState extends StatelessWidget {
 const _SectionEmptyState(
 {required this.title, required this.message, required this.icon});

 final String title;
 final String message;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Icon(icon, color: const Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(message,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _EngagementSection extends StatelessWidget {
  const _EngagementSection({
    required this.activeTabIndex,
    required this.onTabChanged,
    required this.stakeholderTable,
    required this.planTable,
    required this.teamTable,
    required this.mappingTable,
    required this.announcementsWidget,
    required this.onAdd,
    required this.onImportTeam,
    required this.onSearch,
  });

  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final Widget stakeholderTable;
  final Widget planTable;
  final Widget teamTable;
  final Widget mappingTable;
  final Widget announcementsWidget;
  final VoidCallback onAdd;
  final VoidCallback onImportTeam;
  final ValueChanged<String> onSearch;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 decoration: const BoxDecoration(
 color: Color(0xFFF4F5FB),
 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
 ),
  child: Row(
  children: [
  _tabButton(title: 'Stakeholders', index: 0),
  _tabButton(title: 'Engagement Plans', index: 1),
  _tabButton(title: 'Project Team', index: 2),
  _tabButton(title: 'Stakeholder Mapping', index: 3),
  _tabButton(title: 'Announcements', index: 4),
  ],
  ),
 ),
 Padding(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
  if (activeTabIndex < 3) ...[
  Row(
  children: [
  Expanded(
  child: _SearchField(
  enabled: true,
  value: '',
  onChanged: onSearch,
  ),
  ),
  const SizedBox(width: 12),
  if (activeTabIndex == 2)
  ElevatedButton.icon(
  onPressed: onImportTeam,
  icon: const Icon(Icons.download_outlined),
  label: const Text('Import from Staffing Plan'),
  style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF10B981),
  foregroundColor: Colors.white,
  elevation: 0,
  padding: const EdgeInsets.symmetric(
  horizontal: 18, vertical: 14),
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12)),
  ),
  ),
  if (activeTabIndex == 2) const SizedBox(width: 8),
  if (activeTabIndex != 2)
  ElevatedButton.icon(
  onPressed: onAdd,
  icon: const Icon(Icons.add),
  label: Text(
  activeTabIndex == 0 ? 'Add stakeholder' : 'Add plan'),
  style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFFFFD84D),
  foregroundColor: const Color(0xFF1F2937),
  elevation: 0,
  padding: const EdgeInsets.symmetric(
  horizontal: 18, vertical: 14),
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12)),
  ),
  ),
  ],
  ),
  const SizedBox(height: 24),
  ],
  IndexedStack(
  index: activeTabIndex,
  children: [
  stakeholderTable,
  planTable,
  teamTable,
  mappingTable,
  announcementsWidget,
  ],
  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _tabButton({required String title, required int index}) {
 final active = activeTabIndex == index;
 return InkWell(
 onTap: () => onTabChanged(index),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 decoration: BoxDecoration(
 border: Border(
 bottom: BorderSide(
 color: active ? const Color(0xFF1F2937) : Colors.transparent,
 width: 2,
 ),
 ),
 ),
 child: Text(
 title,
 style: TextStyle(
 fontSize: 14,
 fontWeight: active ? FontWeight.w700 : FontWeight.w500,
 color: active ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
 ),
 ),
 ),
 );
 }
}

class _SearchField extends StatelessWidget {
 const _SearchField(
 {required this.enabled, required this.value, required this.onChanged});

 final bool enabled;
 final String value;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return VoiceTextField(
 enabled: enabled,
 onChanged: onChanged,
 decoration: InputDecoration(
 hintText: 'Search stakeholders...',
 prefixIcon:
 const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
 filled: true,
 fillColor: Colors.white,
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 disabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFFFC812), width: 1.2),
 ),
 ),
 );
 }
}

// _FilterButton removed as per plan

class _StakeholdersTable extends StatelessWidget {
 const _StakeholdersTable({
 required this.entries,
 required this.isLoading,
 required this.onChanged,
 required this.onDelete,
 });

 final List<StakeholderEntry> entries;
 final bool isLoading;
 final ValueChanged<StakeholderEntry> onChanged;
 final ValueChanged<String> onDelete;

 @override
 Widget build(BuildContext context) {
 final columns = [
 const _TableColumnDef('#', 72),
 const _TableColumnDef('Stakeholder', 200),
 const _TableColumnDef('Organization', 180),
 const _TableColumnDef('Role/Title', 160),
 const _TableColumnDef('Contact Info', 200),
 const _TableColumnDef('Influence', 140),
 const _TableColumnDef('Interest', 140),
 const _TableColumnDef('Channel', 180),
 const _TableColumnDef('Owner', 160),
 const _TableColumnDef('Notes', 240),
 const _TableColumnDef('', 70),
 ];

 if (isLoading) {
 return const LinearProgressIndicator(minHeight: 2);
 }

 if (entries.isEmpty) {
 return const _SectionEmptyState(
 title: 'No stakeholders yet',
 message: 'Add stakeholders to build your engagement register.',
 icon: Icons.group_outlined,
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (int index = 0; index < entries.length; index++)
 _EditableRow(
 key: ValueKey(entries[index].id),
 columns: columns,
 cells: [
 _IndexCell(number: index + 1),
 _TextCell(
 value: entries[index].name,
 fieldKey: '${entries[index].id}_name',
 hintText: 'Name',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(name: value)),
 ),
 _TextCell(
 value: entries[index].organization,
 fieldKey: '${entries[index].id}_organization',
 hintText: 'Organization',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(organization: value)),
 ),
 _TextCell(
 value: entries[index].role,
 fieldKey: '${entries[index].id}_role',
 hintText: 'Role/Title',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(role: value)),
 ),
 _TextCell(
 value: entries[index].contactInfo,
 fieldKey: '${entries[index].id}_contactInfo',
 hintText: 'Email/Phone',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(contactInfo: value)),
 ),
 _DropdownCell(
 value: entries[index].influence,
 fieldKey: '${entries[index].id}_influence',
 options: const ['High', 'Medium', 'Low'],
 onChanged: (value) =>
 onChanged(entries[index].copyWith(influence: value)),
 ),
 _DropdownCell(
 value: entries[index].interest,
 fieldKey: '${entries[index].id}_interest',
 options: const ['High', 'Medium', 'Low'],
 onChanged: (value) =>
 onChanged(entries[index].copyWith(interest: value)),
 ),
 _TextCell(
 value: entries[index].channel,
 fieldKey: '${entries[index].id}_channel',
 hintText: 'Channel',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(channel: value)),
 ),
 _TextCell(
 value: entries[index].owner,
 fieldKey: '${entries[index].id}_owner',
 hintText: 'Owner',
 onChanged: (value) =>
 onChanged(entries[index].copyWith(owner: value)),
 ),
 _TextCell(
 value: entries[index].notes,
 fieldKey: '${entries[index].id}_notes',
 hintText: 'Notes',
 minLines: 1,
 maxLines: null,
 onChanged: (value) =>
 onChanged(entries[index].copyWith(notes: value)),
 ),
 _DeleteCell(
 itemName:
 'stakeholder "${entries[index].name.trim().isEmpty ? 'Untitled' : entries[index].name.trim()}"',
 onPressed: () => onDelete(entries[index].id),
 ),
 ],
 ),
 ],
 );
 }
}

class _EngagementPlansTable extends StatelessWidget {
 const _EngagementPlansTable({
 required this.entries,
 required this.isLoading,
 required this.onChanged,
 required this.onDelete,
 });

 final List<EngagementPlanEntry> entries;
 final bool isLoading;
 final ValueChanged<EngagementPlanEntry> onChanged;
 final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = [
    const _TableColumnDef('#', 72),
    const _TableColumnDef('Stakeholder', 200),
    const _TableColumnDef('Email', 200),
    const _TableColumnDef('Objective', 220),
    const _TableColumnDef('Method', 160),
    const _TableColumnDef('Frequency', 140),
    const _TableColumnDef('Location', 160),
    const _TableColumnDef('Phone', 160),
    const _TableColumnDef('Owner', 160),
    const _TableColumnDef('Status', 140),
    const _TableColumnDef('Next Touchpoint', 160),
    const _TableColumnDef('Notes', 240),
    const _TableColumnDef('', 70),
    ];

    if (isLoading) {
    return const LinearProgressIndicator(minHeight: 2);
    }

    final stakeholderEntries = entries.where((e) => !e.isProjectTeam).toList();

    if (stakeholderEntries.isEmpty) {
    return const _SectionEmptyState(
    title: 'No engagement plans yet',
    message: 'Add engagement plans to define stakeholder touchpoints.',
    icon: Icons.playlist_add_check_outlined,
    );
    }

    return _EditableTable(
    columns: columns,
    rows: [
    for (int index = 0; index < stakeholderEntries.length; index++)
    _EditableRow(
    key: ValueKey(stakeholderEntries[index].id),
    columns: columns,
    cells: [
    _IndexCell(number: index + 1),
    _TextCell(
    value: stakeholderEntries[index].stakeholder,
    fieldKey: '${stakeholderEntries[index].id}_stakeholder',
    hintText: 'Stakeholder',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(stakeholder: value)),
    ),
    _EmailCell(
    value: stakeholderEntries[index].email,
    fieldKey: '${stakeholderEntries[index].id}_email',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(email: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].objective,
    fieldKey: '${stakeholderEntries[index].id}_objective',
    hintText: 'Objective',
    minLines: 1,
    maxLines: null,
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(objective: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].method,
    fieldKey: '${stakeholderEntries[index].id}_method',
    hintText: 'Method',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(method: value)),
    ),
    _DropdownCell(
    value: stakeholderEntries[index].frequency,
    fieldKey: '${stakeholderEntries[index].id}_frequency',
    options: const ['Weekly', 'Bi-weekly', 'Monthly', 'Quarterly', 'Ad-hoc'],
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(frequency: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].location,
    fieldKey: '${stakeholderEntries[index].id}_location',
    hintText: 'Location',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(location: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].phone,
    fieldKey: '${stakeholderEntries[index].id}_phone',
    hintText: '+[country] [number]',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(phone: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].owner,
    fieldKey: '${stakeholderEntries[index].id}_owner',
    hintText: 'Owner',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(owner: value)),
    ),
    _DropdownCell(
    value: stakeholderEntries[index].status,
    fieldKey: '${stakeholderEntries[index].id}_status',
    options: const [
    'Planned',
    'In progress',
    'At risk',
    'Completed'
    ],
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(status: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].nextTouchpoint,
    fieldKey: '${stakeholderEntries[index].id}_next_touchpoint',
    hintText: 'Next touchpoint',
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(nextTouchpoint: value)),
    ),
    _TextCell(
    value: stakeholderEntries[index].notes,
    fieldKey: '${stakeholderEntries[index].id}_notes',
    hintText: 'Notes',
    minLines: 1,
    maxLines: null,
    onChanged: (value) =>
    onChanged(stakeholderEntries[index].copyWith(notes: value)),
    ),
    _DeleteCell(
    itemName:
    'engagement plan for "${stakeholderEntries[index].stakeholder.trim().isEmpty ? 'Untitled' : stakeholderEntries[index].stakeholder.trim()}"',
    onPressed: () => onDelete(stakeholderEntries[index].id),
    ),
    ],
    ),
    ],
    );
  }
}

// ── Project Team Tab ────────────────────────────────────────────────────
class _ProjectTeamTable extends StatelessWidget {
  const _ProjectTeamTable({
    required this.entries,
    required this.staffingRequirements,
    required this.isLoading,
    required this.onChanged,
    required this.onDelete,
    required this.onImport,
  });

  final List<EngagementPlanEntry> entries;
  final List<StaffingRequirement> staffingRequirements;
  final bool isLoading;
  final ValueChanged<EngagementPlanEntry> onChanged;
  final ValueChanged<String> onDelete;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _TableColumnDef('#', 72),
      const _TableColumnDef('Name', 180),
      const _TableColumnDef('Role / Position', 180),
      const _TableColumnDef('Email', 200),
      const _TableColumnDef('Phone', 160),
      const _TableColumnDef('Location', 160),
      const _TableColumnDef('Frequency', 140),
      const _TableColumnDef('Status', 140),
      const _TableColumnDef('Notes', 240),
      const _TableColumnDef('', 70),
    ];

    if (isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    final teamEntries = entries.where((e) => e.isProjectTeam).toList();

    if (teamEntries.isEmpty) {
      return _SectionEmptyState(
        title: 'No project team members yet',
        message: staffingRequirements.isEmpty
            ? 'Add positions in the Staffing Plan, then import them here.'
            : 'Tap "Import from Staffing Plan" to add team members.',
        icon: Icons.group_add_outlined,
      );
    }

    return _EditableTable(
      columns: columns,
      rows: [
        for (int index = 0; index < teamEntries.length; index++)
          _EditableRow(
            key: ValueKey(teamEntries[index].id),
            columns: columns,
            cells: [
              _IndexCell(number: index + 1),
              _TextCell(
                value: teamEntries[index].stakeholder,
                fieldKey: '${teamEntries[index].id}_stakeholder',
                hintText: 'Name',
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(stakeholder: value)),
              ),
              _TextCell(
                value: teamEntries[index].notes.replaceAll('Imported from Staffing Plan (', '').replaceAll(')', ''),
                fieldKey: '${teamEntries[index].id}_role',
                hintText: 'Role',
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(notes: 'Imported from Staffing Plan ($value)')),
              ),
              _EmailCell(
                value: teamEntries[index].email,
                fieldKey: '${teamEntries[index].id}_email',
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(email: value)),
              ),
              _TextCell(
                value: teamEntries[index].phone,
                fieldKey: '${teamEntries[index].id}_phone',
                hintText: '+[country] [number]',
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(phone: value)),
              ),
              _TextCell(
                value: teamEntries[index].location,
                fieldKey: '${teamEntries[index].id}_location',
                hintText: 'Location',
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(location: value)),
              ),
              _DropdownCell(
                value: teamEntries[index].frequency,
                fieldKey: '${teamEntries[index].id}_frequency',
                options: const ['Daily', 'Weekly', 'Bi-weekly', 'Monthly', 'Quarterly'],
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(frequency: value)),
              ),
              _DropdownCell(
                value: teamEntries[index].status,
                fieldKey: '${teamEntries[index].id}_status',
                options: const ['Planned', 'In progress', 'At risk', 'Completed'],
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(status: value)),
              ),
              _TextCell(
                value: teamEntries[index].notes,
                fieldKey: '${teamEntries[index].id}_notes',
                hintText: 'Notes',
                minLines: 1,
                maxLines: null,
                onChanged: (value) =>
                    onChanged(teamEntries[index].copyWith(notes: value)),
              ),
              _DeleteCell(
                itemName: 'team member "${teamEntries[index].stakeholder.trim().isEmpty ? 'Untitled' : teamEntries[index].stakeholder.trim()}"',
                onPressed: () => onDelete(teamEntries[index].id),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Import from Staffing Plan Dialog ────────────────────────────────────
class _ImportFromStaffingDialog extends StatefulWidget {
  const _ImportFromStaffingDialog({required this.requirements});

  final List<StaffingRequirement> requirements;

  @override
  State<_ImportFromStaffingDialog> createState() => _ImportFromStaffingDialogState();
}

class _ImportFromStaffingDialogState extends State<_ImportFromStaffingDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.group_add_outlined, color: Color(0xFF10B981), size: 24),
          const SizedBox(width: 10),
          Text('Import from Staffing Plan (${widget.requirements.length})'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select team members to add to the Project Team engagement plan.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedIds.length == widget.requirements.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(widget.requirements.map((r) => r.id));
                    }
                  }),
                  child: Text(
                    _selectedIds.length == widget.requirements.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.requirements.length,
                itemBuilder: (context, index) {
                  final r = widget.requirements[index];
                  final displayName = r.personName.trim().isNotEmpty
                      ? r.personName.trim()
                      : r.title;
                  final isSelected = _selectedIds.contains(r.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selectedIds.add(r.id);
                      } else {
                        _selectedIds.remove(r.id);
                      }
                    }),
                    title: Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${r.title} • ${r.employmentType} • ${r.location.isNotEmpty ? r.location : "No location"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    secondary: r.email.isNotEmpty
                        ? const Icon(Icons.email_outlined, size: 18, color: Color(0xFF10B981))
                        : const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  );
                },
              ),
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
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.requirements
                      .where((r) => _selectedIds.contains(r.id))
                      .toList();
                  Navigator.pop(context, selected);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          child: Text('Import ${_selectedIds.length} Member${_selectedIds.length == 1 ? "" : "s"}'),
        ),
      ],
    );
  }
}

class _EditableTable extends StatelessWidget {
 const _EditableTable({required this.columns, required this.rows});

 final List<_TableColumnDef> columns;
 final List<_EditableRow> rows;

 @override
 Widget build(BuildContext context) {
 const horizontalPadding = 16.0;
 final contentWidth =
 columns.fold<double>(0, (total, column) => total + column.width);
 final minTableWidth = contentWidth + (horizontalPadding * 2);

 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 color: Colors.white,
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth = constraints.maxWidth > minTableWidth
 ? constraints.maxWidth
 : minTableWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Column(
 children: [
 Container(
 width: tableWidth,
 padding: const EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 14),
 decoration: const BoxDecoration(
 color: Color(0xFFF3F4F6),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(18),
 topRight: Radius.circular(18)),
 ),
 child: Row(
 children: columns
 .map((column) => SizedBox(
 width: column.width,
 child: Center(
 child: Text(
 column.label.toUpperCase(),
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.8,
 color: Color(0xFF6B7280)),
 ),
 ),
 ))
 .toList(),
 ),
 ),
 for (int i = 0; i < rows.length; i++)
 Container(
 width: tableWidth,
 padding: const EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 12),
 decoration: BoxDecoration(
 color:
 i.isEven ? Colors.white : const Color(0xFFF9FAFB),
 border: Border(
 top: BorderSide(
 color: const Color(0xFFE5E7EB),
 width: i == 0 ? 1 : 0.5),
 ),
 ),
 child: rows[i],
 ),
 ],
 ),
 ),
 );
 },
 ),
 );
 }
}

class _IndexCell extends StatelessWidget {
 const _IndexCell({required this.number});

 final int number;

 @override
 Widget build(BuildContext context) {
 return Center(
 child: Text(
 '$number',
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 ),
 ),
 );
 }
}

class _TableFieldShell extends StatelessWidget {
 const _TableFieldShell({required this.child});

 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
 child: child,
 );
 }
}

class _EditableRow extends StatelessWidget {
 const _EditableRow({super.key, required this.columns, required this.cells});

 final List<_TableColumnDef> columns;
 final List<Widget> cells;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: List.generate(
 cells.length,
 (index) => SizedBox(width: columns[index].width, child: cells[index]),
 ),
 );
 }
}

class _TableColumnDef {
 const _TableColumnDef(this.label, this.width);

 final String label;
 final double width;
}

class _TextCell extends StatefulWidget {
 const _TextCell({
 required this.value,
 required this.fieldKey,
 required this.onChanged,
 this.hintText,
 this.minLines = 1,
 this.maxLines,
 });

 final String value;
 final String fieldKey;
 final String? hintText;
 final int minLines;
 final int? maxLines;
 final ValueChanged<String> onChanged;

 @override
 State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
 late TextEditingController _controller;

 @override
 void initState() {
 super.initState();
 _controller = TextEditingController(text: widget.value);
 }

 @override
 void didUpdateWidget(_TextCell oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.value != widget.value && _controller.text != widget.value) {
 _controller.text = widget.value;
 }
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return _TableFieldShell(
 child: VoiceTextFormField(
 controller: _controller,
 minLines: widget.minLines,
 maxLines: widget.maxLines,
 decoration: InputDecoration(
 hintText: widget.hintText,
 isDense: true,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 filled: true,
 fillColor: Colors.white,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 onChanged: widget.onChanged,
 ),
 );
 }
}

/// Email cell that shows a red warning icon when empty.
class _EmailCell extends StatefulWidget {
  const _EmailCell({
    required this.value,
    required this.fieldKey,
    required this.onChanged,
  });

  final String value;
  final String fieldKey;
  final ValueChanged<String> onChanged;

  @override
  State<_EmailCell> createState() => _EmailCellState();
}

class _EmailCellState extends State<_EmailCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EmailCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.value.trim().isEmpty;
    return _TableFieldShell(
      child: Row(
        children: [
          Expanded(
            child: VoiceTextFormField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'email@example.com',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
              onChanged: widget.onChanged,
            ),
          ),
          if (isEmpty) ...[
            const SizedBox(width: 4),
            const Tooltip(
              message: 'Email missing',
              child: Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropdownCell extends StatelessWidget {
 const _DropdownCell({
 required this.value,
 required this.fieldKey,
 required this.options,
 required this.onChanged,
 });

 final String value;
 final String fieldKey;
 final List<String> options;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 final resolvedValue = options.contains(value) ? value : options.first;
 return _TableFieldShell(
 child: DropdownButtonFormField<String>(
 key: ValueKey(fieldKey),
 value: resolvedValue,
 items: options
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (value) {
 if (value != null) onChanged(value);
 },
 decoration: InputDecoration(
 isDense: true,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
 ),
 filled: true,
 fillColor: Colors.white,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 );
 }
}

class _DeleteCell extends StatelessWidget {
 const _DeleteCell({
 required this.onPressed,
 this.itemName = 'this item',
 });

 final VoidCallback onPressed;
 final String itemName;

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: Alignment.topCenter,
 child: IconButton(
 icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
 onPressed: () => _showDeleteConfirmation(context, onPressed),
 ),
 );
 }

 Future<void> _showDeleteConfirmation(
 BuildContext context,
 VoidCallback onConfirm,
 ) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Item'),
 content: Text('Are you sure you want to delete $itemName?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(context).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444),
 foregroundColor: Colors.white,
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 if (confirmed == true) {
 onConfirm();
 }
 }
}

// Private entry classes removed in favor of StakeholderEntry and EngagementPlanEntry in project_data_model.dart

class _Debouncer {
 _Debouncer({Duration? delay})
 : delay = delay ?? const Duration(milliseconds: 700);

 final Duration delay;
 Timer? _timer;

 void run(void Function() action) {
 _timer?.cancel();
 _timer = Timer(delay, action);
 }

 void dispose() {
 _timer?.cancel();
 }
}

// ── Stakeholder Mapping Tab ──────────────────────────────────────────────
/// Groups stakeholders by influence/interest quadrant with color-coded
/// cells and sorting by quadrant. AI auto-suggests ratings.
class _StakeholderMappingTab extends StatelessWidget {
  const _StakeholderMappingTab({required this.stakeholders});

  final List<StakeholderEntry> stakeholders;

  String _quadrantFor(StakeholderEntry s) {
    final influence = s.influence.toLowerCase();
    final interest = s.interest.toLowerCase();
    final highInfluence = influence.contains('high') || influence.contains('significant');
    final highInterest = interest.contains('high') || interest.contains('significant');
    if (highInfluence && highInterest) return 'Manage Closely';
    if (highInfluence && !highInterest) return 'Keep Satisfied';
    if (!highInfluence && highInterest) return 'Keep Informed';
    return 'Monitor';
  }

  Color _colorFor(String quadrant) {
    switch (quadrant) {
      case 'Manage Closely':
        return const Color(0xFFDC2626); // Red — high priority
      case 'Keep Satisfied':
        return const Color(0xFFD97706); // Amber
      case 'Keep Informed':
        return const Color(0xFFD97706); // Blue
      default:
        return const Color(0xFF6B7280); // Gray — Monitor
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group by quadrant
    final groups = <String, List<StakeholderEntry>>{
      'Manage Closely': [],
      'Keep Satisfied': [],
      'Keep Informed': [],
      'Monitor': [],
    };
    for (final s in stakeholders) {
      final q = _quadrantFor(s);
      groups[q]!.add(s);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stakeholder Mapping — Influence / Interest Matrix',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Stakeholders are grouped by their influence and interest level. '
            'AI auto-suggests ratings based on project data. Edit stakeholder '
            'influence/interest in the Stakeholders tab to update mappings.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          for (final entry in groups.entries) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _colorFor(entry.key).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colorFor(entry.key).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _colorFor(entry.key),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${entry.value.length} stakeholder${entry.value.length == 1 ? "" : "s"})',
                        style: TextStyle(fontSize: 12, color: _colorFor(entry.key), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (entry.value.isEmpty)
                    Text('No stakeholders in this quadrant.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _colorFor(entry.key).withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            if (s.role.isNotEmpty)
                              Text(s.role, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            if (s.organization.isNotEmpty)
                              Text(s.organization, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Announcements Tab ────────────────────────────────────────────────────
/// Announcement templates for each engagement level (Manage Closely,
/// Keep Satisfied, Keep Informed, Monitor) and the project team.
class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({required this.stakeholders});

  final List<StakeholderEntry> stakeholders;

  static const _templates = [
    _AnnouncementTemplate(
      group: 'Manage Closely',
      subject: 'Project Update - Action Required',
      body: 'Dear [Name],\n\nThis is a critical project update for [Project Name]. Your input is required on [specific item]. Please review the attached documentation and provide feedback by [date].\n\nKey highlights:\n- [Milestone 1]\n- [Milestone 2]\n- [Risk/Issue]\n\nBest regards,\n[Project Manager]',
      channel: 'Email + Direct Meeting',
      frequency: 'Weekly',
    ),
    _AnnouncementTemplate(
      group: 'Keep Satisfied',
      subject: 'Project Status Report',
      body: 'Dear [Name],\n\nHere is the latest status update for [Project Name]. The project is currently [on track / at risk / ahead of schedule]. Key developments include:\n- [Update 1]\n- [Update 2]\n\nPlease reach out if you have any questions.\n\nBest regards,\n[Project Manager]',
      channel: 'Email',
      frequency: 'Bi-weekly',
    ),
    _AnnouncementTemplate(
      group: 'Keep Informed',
      subject: 'Project Newsletter',
      body: 'Hello [Name],\n\nHere is what is happening with [Project Name]:\n- [Milestone update]\n- [Team highlight]\n- [Upcoming event]\n\nStay tuned for more updates!\n\n[Project Team]',
      channel: 'Email / Dashboard Announcement',
      frequency: 'Monthly',
    ),
    _AnnouncementTemplate(
      group: 'Monitor',
      subject: 'Quarterly Project Summary',
      body: 'Hello [Name],\n\nQuarterly summary for [Project Name]:\n- Overall status: [status]\n- Budget: [budget status]\n- Schedule: [schedule status]\n\nFull report available on the project portal.\n\n[Project Team]',
      channel: 'Email',
      frequency: 'Quarterly',
    ),
    _AnnouncementTemplate(
      group: 'Project Team',
      subject: 'Weekly Team Update',
      body: 'Team,\n\nWeekly update for [Project Name]:\n\nThis weeks priorities:\n1. [Priority 1]\n2. [Priority 2]\n3. [Priority 3]\n\nRisks/Blockers:\n- [Risk 1]\n\nNext standup: [Day/Time]\n\n[Project Manager]',
      channel: 'Email + Team Meeting',
      frequency: 'Weekly',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcement Templates',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pre-built templates for each stakeholder engagement level. '
            'Customize and send to keep stakeholders informed.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          ..._templates.map((t) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.group, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t.channel, style: const TextStyle(fontSize: 10, color: Color(0xFF1E40AF))),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t.frequency, style: const TextStyle(fontSize: 10, color: Color(0xFF166534))),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF6B7280)),
                      tooltip: 'Copy template',
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    t.body,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.5),
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

class _AnnouncementTemplate {
  final String group;
  final String subject;
  final String body;
  final String channel;
  final String frequency;

  const _AnnouncementTemplate({
    required this.group,
    required this.subject,
    required this.body,
    required this.channel,
    required this.frequency,
  });
}
