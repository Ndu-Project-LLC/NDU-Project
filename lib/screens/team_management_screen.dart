import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/team_management_plan.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/team_management_service.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class TeamManagementScreen extends StatefulWidget {
 const TeamManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const TeamManagementScreen()),
 );
 }

 @override
 State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
 bool _loadedMembers = false;
 late TabController _tabController;
 TeamManagementPlan _plan = TeamManagementPlan.empty();
 bool _loadingPlan = true;
 bool _isBasicPlan = false;

 static const _tabs = [
   Tab(icon: Icon(Icons.group_outlined, size: 16), text: 'Members'),
   Tab(icon: Icon(Icons.rocket_launch_outlined, size: 16), text: 'Mobilization'),
   Tab(icon: Icon(Icons.description_outlined, size: 16), text: 'Onboarding'),
   Tab(icon: Icon(Icons.emoji_events_outlined, size: 16), text: 'Recognition'),
   Tab(icon: Icon(Icons.swap_horiz_outlined, size: 16), text: 'Handover'),
   Tab(icon: Icon(Icons.campaign_outlined, size: 16), text: 'Activities'),
 ];

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: _tabs.length, vsync: this);
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadMembersFromFirestore();
 _loadPlanFromFirestore();
 _checkBasicPlan();
 });
 }

 @override
 void dispose() {
 _tabController.dispose();
 super.dispose();
 }

 void _checkBasicPlan() {
   try {
     final provider = ProjectDataHelper.getProvider(context);
     setState(() {
       _isBasicPlan = provider.projectData.isBasicPlanProject;
     });
   } catch (_) {
     // Default to non-basic if we can't determine.
   }
 }

 // ── Plan persistence (Firestore) ───────────────────────────────────

 Future<void> _loadPlanFromFirestore() async {
   if (!_loadingPlan) return;
   final provider = ProjectDataHelper.getProvider(context);
   final projectId = provider.projectData.projectId;
   if (projectId == null || projectId.isEmpty) {
     setState(() => _loadingPlan = false);
     return;
   }
   try {
     final doc = await FirebaseFirestore.instance
         .collection('projects')
         .doc(projectId)
         .collection('team_management')
         .doc('plan')
         .get();
     if (doc.exists && doc.data() != null) {
       setState(() {
         _plan = TeamManagementPlan.fromJson(doc.data()!);
         _loadingPlan = false;
       });
     } else {
       setState(() => _loadingPlan = false);
     }
   } catch (e) {
     debugPrint('TeamManagement: failed to load plan: $e');
     setState(() => _loadingPlan = false);
   }
 }

 Future<void> _savePlan() async {
   final provider = ProjectDataHelper.getProvider(context);
   final projectId = provider.projectData.projectId;
   if (projectId == null || projectId.isEmpty) return;
   try {
     await FirebaseFirestore.instance
         .collection('projects')
         .doc(projectId)
         .collection('team_management')
         .doc('plan')
         .set(_plan.toJson(), SetOptions(merge: true));
   } catch (e) {
     debugPrint('TeamManagement: failed to save plan: $e');
   }
 }

 void _updatePlan(TeamManagementPlan Function(TeamManagementPlan) updater) {
   setState(() {
     _plan = updater(_plan);
   });
   _savePlan();
 }

 Future<void> _openAddMemberDialog(List<TeamMember> members) async {
 final nameController = TextEditingController();
 final roleController = TextEditingController();
 final emailController = TextEditingController();
 final responsibilitiesController = TextEditingController();
 final formKey = GlobalKey<FormState>();
 const focusColor = Color(0xFFFFD700);
 const List<String> suggestedRoles = [
 'Product Manager',
 'Project Lead',
 'Engineering Lead',
 'QA Lead',
 'Designer',
 'Data Analyst',
 ];

 final result = await showDialog<TeamMember>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setState) {
 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 child: Container(
 width: 520,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 ),
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Icon(Icons.group_add_outlined, color: Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Add team member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 SizedBox(height: 4),
 Text('Define role ownership and responsibilities.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
 splashRadius: 20,
 ),
 ],
 ),
 const SizedBox(height: 20),
 const _DialogSectionTitle(title: 'Identity'),
 const SizedBox(height: 10),
 _DialogTextField(
 controller: nameController,
 label: 'Full name',
 validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required' : null,
 ),
 const SizedBox(height: 12),
 _DialogTextField(
 controller: emailController,
 label: 'Work email',
 hintText: 'name@company.com',
 keyboardType: TextInputType.emailAddress,
 ),
 const SizedBox(height: 20),
 const _DialogSectionTitle(title: 'Role & coverage'),
 const SizedBox(height: 10),
 _DialogTextField(
 controller: roleController,
 label: 'Role',
 hintText: 'e.g., Project Lead',
 focusColor: focusColor,
 onChanged: (_) => setState(() {}),
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: suggestedRoles
 .map(
 (role) => ChoiceChip(
 label: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 selected: roleController.text == role,
 onSelected: (_) => setState(() => roleController.text = role),
 selectedColor: const Color(0xFFFFF3CD),
 backgroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
 ),
 )
 .toList(),
 ),
 const SizedBox(height: 20),
 const _DialogSectionTitle(title: 'Responsibilities'),
 const SizedBox(height: 10),
 _DialogTextField(
 controller: responsibilitiesController,
 label: 'Key responsibilities',
 maxLines: 4,
 hintText: 'Add key responsibilities, separated by line breaks.',
 ),
 const SizedBox(height: 22),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 const Spacer(),
 ElevatedButton(
 onPressed: () {
 if (formKey.currentState?.validate() != true) {
 return;
 }
 final member = TeamMember(
 name: nameController.text.trim(),
 role: roleController.text.trim(),
 email: emailController.text.trim(),
 responsibilities: responsibilitiesController.text.trim(),
 );
 Navigator.of(dialogContext).pop(member);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 child: const Text('Add member'),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 },
 );

 if (result == null || !mounted) {
 return;
 }

 final updated = [...members, result];
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'team_management',
 dataUpdater: (data) => data.copyWith(teamMembers: updated),
 showSnackbar: false,
 );
 await _persistMember(result);
 }

 Future<void> _loadMembersFromFirestore() async {
 if (_loadedMembers) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (provider.projectData.teamMembers.isNotEmpty) {
 _loadedMembers = true;
 return;
 }

 try {
 final snapshot = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('team_members')
 .get();
 if (snapshot.docs.isEmpty) {
 _loadedMembers = true;
 return;
 }
 final members = snapshot.docs.map((doc) => TeamMember.fromJson(doc.data())).toList();
 provider.updateField((data) => data.copyWith(teamMembers: members));
 _loadedMembers = true;
 } catch (error) {
 debugPrint('Failed to load team members: $error');
 }
 }

 Future<void> _persistMember(TeamMember member) async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('team_members')
 .doc(member.id)
 .set(member.toJson(), SetOptions(merge: true));
 }

 @override
 Widget build(BuildContext context) {
 final members = context.select<ProjectDataProvider, List<TeamMember>>(
 (provider) => provider.projectData.teamMembers,
 );
 return Scaffold(
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Team Management'),
 ),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Header + Tab bar (fixed) ──
 Container(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Team Management', onExportPdf: _exportPdf),
 const SizedBox(height: 12),
 const Text(
 'Plan the Execution phase team activities: mobilization, onboarding, recognition, and handover.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 16),
 TabBar(
 controller: _tabController,
 isScrollable: true,
 labelColor: const Color(0xFF111827),
 unselectedLabelColor: const Color(0xFF6B7280),
 indicatorColor: const Color(0xFFFFD700),
 indicatorSize: TabBarIndicatorSize.label,
 indicatorWeight: 3,
 tabs: _tabs,
 ),
 ],
 ),
 ),
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 // ── Tab content (scrollable) ──
 Expanded(
 child: TabBarView(
 controller: _tabController,
 children: [
 _buildMembersTab(members),
 _buildMobilizationTab(members),
 _buildOnboardingTab(members),
 _buildRecognitionTab(),
 _buildHandoverTab(members),
 _buildActivitiesTab(),
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

 // ── Tab 1: Members (existing functionality) ──────────────────────────
 Widget _buildMembersTab(List<TeamMember> members) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 final columns = width >= 1200
 ? 3
 : width >= 840
 ? 2
 : 1;
 const gap = 24.0;
 final cardAspectRatio = width >= 1200 ? 0.95 : width >= 840 ? 0.9 : 0.85;

 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Manage roles and responsibilities',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ),
 ElevatedButton.icon(
 onPressed: () => _openAddMemberDialog(members),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 ),
 icon: const Icon(Icons.add, size: 18),
 label: const Text(
 'Add New Member',
 style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Team Management',
 noteKey: 'planning_team_management_notes',
 checkpoint: 'team_management',
 description: 'Capture team structure, ownership, and role coverage.',
 ),
 const SizedBox(height: 24),
 if (members.isEmpty)
 _EmptyStateCard(
 title: 'No team members yet',
 message: 'Add team members to define roles, responsibilities, and ownership.',
 onAdd: () => _openAddMemberDialog(members),
 )
 else
 GridView.builder(
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 itemCount: members.length,
 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: columns,
 mainAxisSpacing: gap,
 crossAxisSpacing: gap,
 childAspectRatio: cardAspectRatio,
 ),
 itemBuilder: (context, index) => _TeamRoleCard(member: members[index]),
 ),
 const SizedBox(height: 28),
 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: () => PlanningPhaseNavigation.goToNext(
 context,
 'team_management',
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 ),
 child: const Text('Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
 ),
 ),
 ],
 ),
 );
 },
 );
 }

 // ── Tab 2: Mobilization ──────────────────────────────────────────────
 Widget _buildMobilizationTab(List<TeamMember> members) {
 if (_loadingPlan) {
 return const Center(child: CircularProgressIndicator());
 }
 final overallProgress =
 TeamManagementService.overallMobilizationProgress(_plan);
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Team Mobilization Process',
 icon: Icons.rocket_launch_outlined,
 description:
 'Outline the process by which team members will be mobilized into the Execution phase. This plan triggers the "Mobilize team" aspect of Execution for each team member.',
 child: _EditableTextBlock(
 initialText: _plan.mobilizationProcess,
 hint:
 'Describe the mobilization process: notification, access provisioning, kickoff scheduling, etc.',
 onChanged: (text) => _updatePlan((p) =>
 p.copyWith(mobilizationProcess: text)),
 ),
 ),
 const SizedBox(height: 24),
 _SectionCard(
 title: 'Mobilization Progress',
 icon: Icons.trending_up_outlined,
 description:
 'Overall mobilization completion across all team members. Each member\'s checklist must be fully checked before they are mobilized for Execution.',
 child: _ProgressIndicator(progress: overallProgress),
 ),
 const SizedBox(height: 24),
 _SectionCard(
 title: 'Member Mobilization Checklists',
 icon: Icons.checklist_outlined,
 description:
 'Each team member has an onboarding checklist. Complete all items to mobilize a member for the Execution phase.',
 child: members.isEmpty
 ? const _InfoText(
 'No team members yet. Add members on the Members tab first.')
 : Column(
 children: members.map((m) {
 final mob = TeamManagementService
 .getOrCreateMemberMobilization(
 plan: _plan, memberId: m.id);
 return _MemberChecklistCard(
 member: m,
 mobilization: mob,
 onToggle: (itemIndex, checked) {
 _updatePlan((p) {
 final mobs = List<MemberMobilization>.from(
 p.memberMobilizations);
 final idx = mobs.indexWhere(
 (mm) => mm.memberId == m.id);
 if (idx == -1) {
 mobs.add(mob);
 }
 final targetIdx = idx == -1 ? mobs.length - 1 : idx;
 final checklist = List<MobilizationChecklistItem>.from(
 mobs[targetIdx].checklist);
 checklist[itemIndex] = checklist[itemIndex]
 .copyWith(
 isChecked: checked,
 completedAt: checked
 ? DateTime.now().toIso8601String()
 : null,
 );
 mobs[targetIdx] = MemberMobilization(
 memberId: m.id,
 checklist: checklist,
 mobilizedAt: checklist.every((c) => c.isChecked)
 ? DateTime.now().toIso8601String()
 : mobs[targetIdx].mobilizedAt,
 );
 return p.copyWith(memberMobilizations: mobs);
 });
 },
 );
 }).toList(),
 ),
 ),
 ],
 ),
 );
 }

 // ── Tab 3: Onboarding Documents ──────────────────────────────────────
 Widget _buildOnboardingTab(List<TeamMember> members) {
 if (_loadingPlan) {
 return const Center(child: CircularProgressIndicator());
 }
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Project Onboarding Summary',
 icon: Icons.summarize_outlined,
 description:
 'Auto-generated from the Project Details (Initiation phase) and Planning phase. Planning overrides Initiation for conflicts. In-scope, out-of-scope, and boundaries remain fixed throughout the project.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_plan.projectOnboardingSummary.isEmpty)
 const _InfoText(
 'No summary generated yet. Click "Generate Summary" to create one from the project data.')
 else
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: SelectableText(
 _plan.projectOnboardingSummary,
 style: const TextStyle(
 fontSize: 13,
 height: 1.6,
 color: Color(0xFF374151),
 fontFamily: 'monospace',
 ),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 ElevatedButton.icon(
 onPressed: () {
 final data =
 ProjectDataHelper.getData(context);
 final summary =
 TeamManagementService.generateProjectOnboardingSummary(
 data);
 _updatePlan((p) => p.copyWith(
 projectOnboardingSummary: summary,
 summaryGeneratedAt: DateTime.now(),
 ));
 },
 icon: const Icon(Icons.auto_fix_high, size: 16),
 label: Text(
 _plan.projectOnboardingSummary.isEmpty
 ? 'Generate Summary'
 : 'Regenerate Summary'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 foregroundColor: Colors.white,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 if (_plan.summaryGeneratedAt != null) ...[
 const SizedBox(width: 12),
 Text(
 'Generated ${_formatDate(_plan.summaryGeneratedAt!)}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF9CA3AF)),
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 _SectionCard(
 title: 'Role Onboarding Requirements',
 icon: Icons.badge_outlined,
 description:
 'Specific credentials, training, or documents each role must provide. Projects can identify these or skip them. Click "Suggest from Team" to pull real, curated requirements based on the roles already in the team (no AI hallucination — every suggestion maps to a verifiable certification).',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 ElevatedButton.icon(
 onPressed: members.isEmpty
 ? null
 : () {
 final suggestions =
 RoleOnboardingKnowledgeBase
 .suggestForTeam(members);
 _updatePlan((p) => p.copyWith(
 roleOnboardingRequirements:
 suggestions));
 },
 icon: const Icon(Icons.lightbulb_outline, size: 16),
 label: const Text('Suggest from Team'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: () =>
 _addRoleRequirementDialog(members),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Requirement'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (_plan.roleOnboardingRequirements.isEmpty)
 const _InfoText(
 'No role requirements identified yet. Use "Suggest from Team" or add manually.')
 else
 ..._plan.roleOnboardingRequirements.map((r) =>
 _RoleRequirementCard(
 requirement: r,
 onDelete: () => _updatePlan((p) => p.copyWith(
 roleOnboardingRequirements: p
 .roleOnboardingRequirements
 .where((x) => x.id != r.id)
 .toList())),
 onToggleSkip: () => _updatePlan((p) => p.copyWith(
 roleOnboardingRequirements: p
 .roleOnboardingRequirements
 .map((x) => x.id == r.id
 ? RoleOnboardingRequirement(
 id: x.id,
 role: x.role,
 requirement: x.requirement,
 description: x.description,
 isRequired: x.isRequired,
 isSkipped: !x.isSkipped,
 )
 : x)
 .toList())),
 )),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Tab 4: Recognition ───────────────────────────────────────────────
 Widget _buildRecognitionTab() {
 if (_isBasicPlan) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(48),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.lock_outline,
 size: 48, color: Color(0xFF9CA3AF)),
 const SizedBox(height: 16),
 const Text(
 'Team member recognition is not available on the Basic plan.',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 8),
 const Text(
 'Upgrade to a Standard plan to define a recognition process for your project team.',
 style: TextStyle(
 fontSize: 13, color: Color(0xFF9CA3AF)),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 );
 }
 if (_loadingPlan) {
 return const Center(child: CircularProgressIndicator());
 }
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Team Member Recognition Process',
 icon: Icons.emoji_events_outlined,
 description:
 'Define how team members will be recognized for their contributions during the project. This can be skipped if not applicable.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_plan.recognitionSkipped)
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFCD34D)),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline,
 size: 18, color: Color(0xFFF59E0B)),
 const SizedBox(width: 8),
 const Expanded(
 child: Text(
 'Recognition process skipped. You can re-enable it anytime.',
 style: TextStyle(
 fontSize: 13, color: Color(0xFF92400E))),
 ),
 TextButton(
 onPressed: () => _updatePlan((p) =>
 p.copyWith(recognitionSkipped: false)),
 child: const Text('Re-enable'),
 ),
 ],
 ),
 )
 else
 _EditableTextBlock(
 initialText: _plan.recognitionProcess,
 hint:
 'Describe the recognition process: milestones, awards, shout-outs, performance bonuses, etc.',
 onChanged: (text) => _updatePlan((p) =>
 p.copyWith(recognitionProcess: text)),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerLeft,
 child: TextButton.icon(
 onPressed: () => _updatePlan((p) => p.copyWith(
 recognitionSkipped: !_plan.recognitionSkipped)),
 icon: Icon(
 _plan.recognitionSkipped
 ? Icons.undo
 : Icons.skip_next,
 size: 16),
 label: Text(_plan.recognitionSkipped
 ? 'Re-enable Recognition'
 : 'Skip Recognition'),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Tab 5: Role Handover ─────────────────────────────────────────────
 Widget _buildHandoverTab(List<TeamMember> members) {
 if (_loadingPlan) {
 return const Center(child: CircularProgressIndicator());
 }
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Role Handover Template',
 icon: Icons.swap_horiz_outlined,
 description:
 'A handover record must be completed before any team member leaves the project. It captures responsibilities, knowledge transfer, open action items, and asset handover notes.',
 child: members.isEmpty
 ? const _InfoText(
 'No team members yet. Add members on the Members tab first.')
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ElevatedButton.icon(
 onPressed: () =>
 _createHandoverDialog(members),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Create Handover Record'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(height: 16),
 if (_plan.handoverRecords.isEmpty)
 const _InfoText(
 'No handover records yet. Create one when a team member is moving on.')
 else
 ..._plan.handoverRecords.map((h) =>
 _HandoverRecordCard(
 record: h,
 onTap: () =>
 _viewHandoverDialog(h),
 )),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Tab 6: Team Activities (low priority) ────────────────────────────
 Widget _buildActivitiesTab() {
 if (_loadingPlan) {
 return const Center(child: CircularProgressIndicator());
 }
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Team Activities',
 icon: Icons.campaign_outlined,
 description:
 'A feed for project team activities only — similar to the announcement tab in Stakeholder Management. Post updates, milestones, or team-wide notices here.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ActivityComposer(
 onPost: (message) {
 if (message.trim().isEmpty) return;
 final user = FirebaseAuth.instance.currentUser;
 _updatePlan((p) => p.copyWith(
 activityPosts: [
 TeamActivityPost(
 authorName:
 user?.displayName ?? user?.email ?? 'Team Member',
 message: message.trim(),
 ),
 ...p.activityPosts,
 ]));
 },
 ),
 const SizedBox(height: 16),
 if (_plan.activityPosts.isEmpty)
 const _InfoText(
 'No team activities posted yet. Share an update above.')
 else
 ..._plan.activityPosts.map((a) =>
 _ActivityPostCard(post: a)),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Dialogs ──────────────────────────────────────────────────────────

 Future<void> _addRoleRequirementDialog(List<TeamMember> members) async {
 final roleController = TextEditingController();
 final reqController = TextEditingController();
 final descController = TextEditingController();
 final formKey = GlobalKey<FormState>();
 final result = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Add Role Requirement'),
 content: SizedBox(
 width: 480,
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<String>(
 value: members.isNotEmpty ? members.first.role : '',
 decoration: const InputDecoration(
 labelText: 'Role',
 border: OutlineInputBorder(),
 ),
 items: [
 ...members.map((m) => DropdownMenuItem(
 value: m.role,
 child: Text(m.role.isEmpty ? '(unnamed role)' : m.role))),
 const DropdownMenuItem(value: '', child: Text('Custom role')),
 ],
 onChanged: (v) => roleController.text = v ?? '',
 ),
 const SizedBox(height: 12),
 TextFormField(
 controller: reqController,
 decoration: const InputDecoration(
 labelText: 'Requirement',
 hintText: 'e.g. PMP Certification (copy)',
 border: OutlineInputBorder()),
 validator: (v) =>
 v!.isEmpty ? 'Required' : null,
 ),
 const SizedBox(height: 12),
 TextFormField(
 controller: descController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder()),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () {
 if (formKey.currentState!.validate()) {
 _updatePlan((p) => p.copyWith(
 roleOnboardingRequirements: [
 ...p.roleOnboardingRequirements,
 RoleOnboardingRequirement(
 role: roleController.text,
 requirement: reqController.text,
 description: descController.text,
 ),
 ]));
 Navigator.pop(ctx, true);
 }
 },
 child: const Text('Add')),
 ],
 ),
 );
 return;
 }

 Future<void> _createHandoverDialog(List<TeamMember> members) async {
 if (members.isEmpty) return;
 final selectedMember = ValueNotifier<TeamMember?>(null);
 final incomingController = TextEditingController();
 final notesController = TextEditingController();
 final actionsController = TextEditingController();
 final assetsController = TextEditingController();
 final result = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Create Handover Record'),
 content: SizedBox(
 width: 520,
 child: ValueListenableBuilder<TeamMember?>(
 valueListenable: selectedMember,
 builder: (_, member, __) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<TeamMember>(
 value: member,
 decoration: const InputDecoration(
 labelText: 'Outgoing team member',
 border: OutlineInputBorder()),
 items: members
 .map((m) => DropdownMenuItem(
 value: m,
 child: Text(
 '${m.name} (${m.role})')))
 .toList(),
 onChanged: (v) => selectedMember.value = v,
 ),
 const SizedBox(height: 12),
 TextField(
 controller: incomingController,
 decoration: const InputDecoration(
 labelText: 'Incoming member name',
 border: OutlineInputBorder()),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: notesController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Knowledge transfer notes',
 border: OutlineInputBorder()),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: actionsController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Open action items',
 border: OutlineInputBorder()),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: assetsController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Asset handover notes',
 border: OutlineInputBorder()),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () {
 final m = selectedMember.value;
 if (m == null) return;
 _updatePlan((p) => p.copyWith(
 handoverRecords: [
 ...p.handoverRecords,
 RoleHandoverRecord(
 memberId: m.id,
 memberName: m.name,
 memberRole: m.role,
 outgoingResponsibilities: m.responsibilities,
 incomingMemberName: incomingController.text,
 knowledgeTransferNotes: notesController.text,
 openActionItems: actionsController.text,
 assetHandoverNotes: assetsController.text,
 ),
 ]));
 Navigator.pop(ctx, true);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827)),
 child: const Text('Create')),
 ],
 ),
 );
 return;
 }

 Future<void> _viewHandoverDialog(RoleHandoverRecord h) async {
 await showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text('Handover: ${h.memberName}'),
 content: SizedBox(
 width: 520,
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _handoverField('Role', h.memberRole),
 _handoverField('Outgoing responsibilities',
 h.outgoingResponsibilities),
 _handoverField('Incoming member', h.incomingMemberName),
 _handoverField('Knowledge transfer notes',
 h.knowledgeTransferNotes),
 _handoverField('Open action items', h.openActionItems),
 _handoverField('Asset handover notes',
 h.assetHandoverNotes),
 if (h.isCompleted)
 _handoverField('Completed at', h.completedAt ?? ''),
 ],
 ),
 ),
 ),
 actions: [
 if (!h.isCompleted)
 ElevatedButton(
 onPressed: () {
 _updatePlan((p) => p.copyWith(
 handoverRecords: p.handoverRecords
 .map((x) => x.id == h.id
 ? RoleHandoverRecord(
 id: x.id,
 memberId: x.memberId,
 memberName: x.memberName,
 memberRole: x.memberRole,
 outgoingResponsibilities:
 x.outgoingResponsibilities,
 incomingMemberName:
 x.incomingMemberName,
 knowledgeTransferNotes:
 x.knowledgeTransferNotes,
 openActionItems: x.openActionItems,
 assetHandoverNotes:
 x.assetHandoverNotes,
 completedAt: DateTime.now()
 .toIso8601String(),
 completedBy:
 FirebaseAuth.instance.currentUser
 ?.displayName ??
 'Unknown',
 isCompleted: true,
 )
 : x)
 .toList()));
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.green,
 foregroundColor: Colors.white),
 child: const Text('Mark Complete')),
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Close')),
 ],
 ),
 );
 }

 Widget _handoverField(String label, String value) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280))),
 const SizedBox(height: 4),
 Text(value.isEmpty ? '—' : value,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF111827))),
 ],
 ),
 );
 }

 String _formatDate(DateTime dt) {
 final m = dt.toLocal();
 return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')} '
 '${m.hour.toString().padLeft(2, '0')}:${m.minute.toString().padLeft(2, '0')}';
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Team Management',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_team_management_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}


class _TeamRoleCard extends StatelessWidget {
 const _TeamRoleCard({required this.member});

 final TeamMember member;

 List<String> _responsibilityItems() {
 final raw = member.responsibilities.trim();
 if (raw.isEmpty) return [];
 return raw
 .split(RegExp(r'[\n;]+'))
 .map((item) => item.trim())
 .where((item) => item.isNotEmpty)
 .toList();
 }

 @override
 Widget build(BuildContext context) {
 final responsibilities = _responsibilityItems();
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFEAF2FF),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.work_outline, color: Color(0xFF2563EB), size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 member.name.isNotEmpty ? member.name : 'Team member',
 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 4),
 Text(
 member.role.isNotEmpty ? member.role : 'Role not set',
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
 ),
 ],
 ),
 ),
 const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF)),
 ],
 ),
 const SizedBox(height: 14),
 const Text(
 'Key Responsibilities',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 if (responsibilities.isEmpty)
 const Text(
 'Add responsibilities to outline ownership.',
 style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
 )
 else
 for (final item in responsibilities) _ResponsibilityRow(text: item),
 ],
 ),
 );
 }
}

class _ResponsibilityRow extends StatelessWidget {
 const _ResponsibilityRow({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 children: [
 const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
 ),
 ),
 ],
 ),
 );
 }
}

class _EmptyStateCard extends StatelessWidget {
 const _EmptyStateCard({required this.title, required this.message, required this.onAdd});

 final String title;
 final String message;
 final VoidCallback onAdd;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
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
 child: const Icon(Icons.group_outlined, color: Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 6),
 Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: onAdd,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add member'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF111827),
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 ),
 ],
 ),
 );
 }
}

class _DialogSectionTitle extends StatelessWidget {
 const _DialogSectionTitle({required this.title});

 final String title;

 @override
 Widget build(BuildContext context) {
 return Text(
 title,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 );
 }
}

class _DialogTextField extends StatelessWidget {
 const _DialogTextField({
 required this.controller,
 required this.label,
 this.hintText,
 this.validator,
 this.maxLines = 1,
 this.keyboardType,
 this.focusColor,
 this.onChanged,
 });

 final TextEditingController controller;
 final String label;
 final String? hintText;
 final String? Function(String?)? validator;
 final int maxLines;
 final TextInputType? keyboardType;
 final Color? focusColor;
 final ValueChanged<String>? onChanged;

 @override
 Widget build(BuildContext context) {
 return VoiceTextFormField(
 controller: controller,
 validator: validator,
 maxLines: maxLines,
 keyboardType: keyboardType,
 onChanged: onChanged,
 decoration: InputDecoration(
 labelText: label,
 hintText: hintText,
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide(color: focusColor ?? const Color(0xFFFFD700), width: 1.6),
 ),
 ),
 );
 }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Helper widgets for the Team Management plan tabs
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionCard extends StatelessWidget {
 const _SectionCard({
 required this.title,
 required this.icon,
 required this.description,
 required this.child,
 });

 final String title;
 final IconData icon;
 final String description;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, color: const Color(0xFFF59E0B), size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Text(description,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

class _InfoText extends StatelessWidget {
 const _InfoText(this.text);
 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 16),
 child: Center(
 child: Text(text,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic),
 textAlign: TextAlign.center),
 ),
 );
 }
}

class _EditableTextBlock extends StatefulWidget {
 const _EditableTextBlock({
 required this.initialText,
 required this.hint,
 required this.onChanged,
 });

 final String initialText;
 final String hint;
 final ValueChanged<String> onChanged;

 @override
 State<_EditableTextBlock> createState() => _EditableTextBlockState();
}

class _EditableTextBlockState extends State<_EditableTextBlock> {
 late final TextEditingController _controller;
 @override
 void initState() {
 super.initState();
 _controller = TextEditingController(text: widget.initialText);
 }

 @override
 void didUpdateWidget(covariant _EditableTextBlock oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.initialText != widget.initialText &&
 _controller.text != widget.initialText) {
 _controller.text = widget.initialText;
 }
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return TextField(
 controller: _controller,
 maxLines: 6,
 onChanged: widget.onChanged,
 decoration: InputDecoration(
 hintText: widget.hint,
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.6)),
 ),
 );
 }
}

class _ProgressIndicator extends StatelessWidget {
 const _ProgressIndicator({required this.progress});
 final double progress; // 0.0 – 1.0

 @override
 Widget build(BuildContext context) {
 final pct = (progress * 100).round();
 final color = pct == 100
 ? const Color(0xFF10B981)
 : pct >= 50
 ? const Color(0xFFF59E0B)
 : const Color(0xFFEF4444);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: LinearProgressIndicator(
 value: progress,
 minHeight: 12,
 backgroundColor: const Color(0xFFF3F4F6),
 valueColor: AlwaysStoppedAnimation<Color>(color),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Text('$pct%',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 progress == 1.0
 ? 'All team members fully mobilized.'
 : 'Complete all checklist items to mobilize the team for Execution.',
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ],
 );
 }
}

class _MemberChecklistCard extends StatelessWidget {
 const _MemberChecklistCard({
 required this.member,
 required this.mobilization,
 required this.onToggle,
 });

 final TeamMember member;
 final MemberMobilization mobilization;
 final void Function(int itemIndex, bool checked) onToggle;

 @override
 Widget build(BuildContext context) {
 final progress = mobilization.progress;
 final pct = (progress * 100).round();
 return Container(
 margin: const EdgeInsets.only(bottom: 16),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: mobilization.isFullyMobilized
 ? const Color(0xFFD1FAE5)
 : const Color(0xFFEAF2FF),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(
 mobilization.isFullyMobilized
 ? Icons.check_circle
 : Icons.person_outline,
 color: mobilization.isFullyMobilized
 ? const Color(0xFF10B981)
 : const Color(0xFF2563EB),
 size: 18,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(member.name.isNotEmpty ? member.name : 'Team member',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 Text(member.role.isNotEmpty ? member.role : 'Role not set',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 Text('$pct%',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: mobilization.isFullyMobilized
 ? const Color(0xFF10B981)
 : const Color(0xFF6B7280))),
 ],
 ),
 const SizedBox(height: 12),
 if (mobilization.checklist.isEmpty)
 const Text('No checklist items. Default items will be added on first toggle.',
 style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic))
 else
 ...mobilization.checklist.asMap().entries.map((entry) {
 final idx = entry.key;
 final item = entry.value;
 return CheckboxListTile(
 value: item.isChecked,
 onChanged: (v) => onToggle(idx, v ?? false),
 title: Text(item.label,
 style: TextStyle(
 fontSize: 12,
 color: item.isChecked
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF374151),
 decoration: item.isChecked
 ? TextDecoration.lineThrough
 : TextDecoration.none)),
 dense: true,
 contentPadding: EdgeInsets.zero,
 controlAffinity: ListTileControlAffinity.leading,
 );
 }),
 if (mobilization.isFullyMobilized)
 Padding(
 padding: const EdgeInsets.only(top: 8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFD1FAE5),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
 SizedBox(width: 4),
 Text('MOBILIZED',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF065F46))),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _RoleRequirementCard extends StatelessWidget {
 const _RoleRequirementCard({
 required this.requirement,
 required this.onDelete,
 required this.onToggleSkip,
 });

 final RoleOnboardingRequirement requirement;
 final VoidCallback onDelete;
 final VoidCallback onToggleSkip;

 @override
 Widget build(BuildContext context) {
 final isSkipped = requirement.isSkipped;
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: isSkipped ? const Color(0xFFF9FAFB) : Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSkipped
 ? const Color(0xFFE5E7EB)
 : requirement.isRequired
 ? const Color(0xFFFCD34D)
 : const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(
 requirement.isRequired ? Icons.priority_high : Icons.info_outline,
 size: 18,
 color: isSkipped
 ? const Color(0xFF9CA3AF)
 : requirement.isRequired
 ? const Color(0xFFDC2626)
 : const Color(0xFF6B7280)),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFEAF2FF),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(requirement.role.isEmpty ? 'All roles' : requirement.role,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF2563EB))),
 ),
 const SizedBox(width: 8),
 if (requirement.isRequired)
 const Text('REQUIRED',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: Color(0xFFDC2626))),
 if (isSkipped) ...[
 const SizedBox(width: 8),
 const Text('SKIPPED',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: Color(0xFF9CA3AF))),
 ],
 ],
 ),
 const SizedBox(height: 6),
 Text(requirement.requirement,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: isSkipped
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF111827))),
 if (requirement.description.isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(requirement.description,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF6B7280),
 height: 1.4)),
 ],
 ],
 ),
 ),
 Column(
 children: [
 IconButton(
 icon: Icon(
 isSkipped ? Icons.undo : Icons.block,
 size: 16,
 color: const Color(0xFF9CA3AF)),
 tooltip: isSkipped ? 'Re-enable' : 'Skip',
 onPressed: onToggleSkip),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFEF4444)),
 tooltip: 'Delete',
 onPressed: onDelete),
 ],
 ),
 ],
 ),
 );
 }
}

class _HandoverRecordCard extends StatelessWidget {
 const _HandoverRecordCard({required this.record, required this.onTap});

 final RoleHandoverRecord record;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(12),
 child: Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: record.isCompleted
 ? const Color(0xFFF0FDF4)
 : const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: record.isCompleted
 ? const Color(0xFF86EFAC)
 : const Color(0xFFFCD34D)),
 ),
 child: Row(
 children: [
 Icon(
 record.isCompleted
 ? Icons.check_circle
 : Icons.pending_actions,
 color: record.isCompleted
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B)),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('${record.memberName} → ${record.incomingMemberName.isEmpty ? 'TBD' : record.incomingMemberName}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(record.memberRole,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 Text(
 record.isCompleted ? 'COMPLETE' : 'PENDING',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: record.isCompleted
 ? const Color(0xFF065F46)
 : const Color(0xFF92400E))),
 ],
 ),
 ),
 );
 }
}

class _ActivityComposer extends StatefulWidget {
 const _ActivityComposer({required this.onPost});
 final ValueChanged<String> onPost;

 @override
 State<_ActivityComposer> createState() => _ActivityComposerState();
}

class _ActivityComposerState extends State<_ActivityComposer> {
 final _controller = TextEditingController();

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Expanded(
 child: TextField(
 controller: _controller,
 decoration: InputDecoration(
 hintText: 'Share a team activity update...',
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.6)),
 ),
 ),
 ),
 const SizedBox(width: 12),
 ElevatedButton(
 onPressed: () {
 widget.onPost(_controller.text);
 _controller.clear();
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Post')),
 ],
 );
 }
}

class _ActivityPostCard extends StatelessWidget {
 const _ActivityPostCard({required this.post});
 final TeamActivityPost post;

 @override
 Widget build(BuildContext context) {
 final timeStr = _formatTime(post.createdAt);
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: const BoxDecoration(
 color: Color(0xFFEAF2FF),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.person, color: Color(0xFF2563EB), size: 18),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(post.authorName,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 if (post.authorRole.isNotEmpty) ...[
 const SizedBox(width: 8),
 Text(post.authorRole,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ],
 const Spacer(),
 Text(timeStr,
 style: const TextStyle(
 fontSize: 10, color: Color(0xFF9CA3AF))),
 ],
 ),
 const SizedBox(height: 6),
 Text(post.message,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF374151), height: 1.5)),
 ],
 ),
 ),
 ],
 ),
 );
 }

 String _formatTime(DateTime dt) {
 final now = DateTime.now();
 final diff = now.difference(dt);
 if (diff.inMinutes < 1) return 'just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
 if (diff.inHours < 24) return '${diff.inHours}h ago';
 if (diff.inDays < 7) return '${diff.inDays}d ago';
 return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
 }
}
