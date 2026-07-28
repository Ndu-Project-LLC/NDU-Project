import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
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

class _TeamManagementScreenState extends State<TeamManagementScreen> {
 bool _loadedMembers = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadMembersFromFirestore();
 });
 }

 Future<void> _openAddMemberDialog(List<TeamMember> members) async {
 final nameController = TextEditingController();
 final roleController = TextEditingController();
 final emailController = TextEditingController();
 final responsibilitiesController = TextEditingController();
 final formKey = GlobalKey<FormState>();
 final focusColor = const Color(0xFFFFD700);
 final List<String> suggestedRoles = const [
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
 child: LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 final columns = width >= 1200
 ? 3
 : width >= 840
 ? 2
 : 1;
 final gap = 24.0;
 final cardAspectRatio = width >= 1200 ? 0.95 : width >= 840 ? 0.9 : 0.85;

 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Team Management', onExportPdf: _exportPdf),
 const SizedBox(height: 20),
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
 ),
 ),
 ],
 ),
 ),
 );
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
