import 'dart:async';

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/rate_card_management_dialog.dart';
import 'package:ndu_project/models/rate_card.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/role_descriptions.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

const Color _kAccent = Color(0xFFFFC107);
const Color _kPrimaryText = Color(0xFF1E293B);
const Color _kSecondaryText = Color(0xFF64748B);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kCardShadow = Color(0x14000000);
const Color _kLightYellow = Color(0xFFFFF8E1);

/// CSV column specifications for Team Member import
const List<CsvColumnSpec> _teamMemberCsvColumns = [
  CsvColumnSpec(key: 'name', label: 'Full Name', required: true, sampleValue: 'John Smith'),
  CsvColumnSpec(key: 'role', label: 'Role', required: true, sampleValue: 'Project Manager'),
  CsvColumnSpec(key: 'email', label: 'Work Email', hint: 'name@company.com', sampleValue: 'john.smith@company.com'),
  CsvColumnSpec(key: 'responsibilities', label: 'Key Responsibilities', hint: 'Key responsibilities for this role', sampleValue: 'Overall project delivery, stakeholder management'),
  CsvColumnSpec(key: 'reportsTo', label: 'Reports To', hint: 'Name or ID of supervisor (optional)'),
];

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
  late final TabController _tabController = TabController(
    length: 7,
    vsync: this,
  );
  bool _loadedMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembersFromFirestore();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddMemberDialog(List<TeamMember> members) async {
  final nameController = TextEditingController();
  final roleController = TextEditingController();
  final emailController = TextEditingController();
  final responsibilitiesController = TextEditingController();
  String reportsTo = '';
  final formKey = GlobalKey<FormState>();
  final focusColor = const Color(0xFFFFD700);
  String? autoFilledDescription;

  void onRoleSelected(String role, StateSetter dialogSetState) {
    roleController.text = role;
    final entry = getRoleDescription(role);
    if (entry != null && responsibilitiesController.text.isEmpty) {
      responsibilitiesController.text = entry.description;
      autoFilledDescription = entry.description;
    }
    dialogSetState(() {});
  }

  final result = await showDialog<TeamMember>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) {
  return StatefulBuilder(
  builder: (context, dialogSetState) {
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
  onChanged: (value) {
    if (responsibilitiesController.text.isEmpty && autoFilledDescription == null) {
      final entry = getRoleDescription(value);
      if (entry != null) {
        responsibilitiesController.text = entry.description;
        autoFilledDescription = entry.description;
      }
    }
    dialogSetState(() {});
  },
  ),
  const SizedBox(height: 10),
  ...roleCategories.map((category) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          category.label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
        ),
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: category.roles.map((role) => ChoiceChip(
          label: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          selected: roleController.text == role,
          onSelected: (_) => onRoleSelected(role, dialogSetState),
          selectedColor: const Color(0xFFFFF3CD),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
        )).toList(),
      ),
      const SizedBox(height: 8),
    ],
  )),
  const SizedBox(height: 20),
  const _DialogSectionTitle(title: 'Reporting Line'),
  const SizedBox(height: 10),
  DropdownButtonFormField<String>(
  value: reportsTo.isEmpty ? null : reportsTo,
  onChanged: (v) => setState(() => reportsTo = v ?? ''),
  items: [
  const DropdownMenuItem(value: '', child: Text('None (Top-level)')),
  ...members.map((m) => DropdownMenuItem(
  value: m.id,
  child: Text('${m.name} (${m.role})'),
  )),
  ],
  decoration: InputDecoration(
  labelText: 'Reports To',
  filled: true,
  fillColor: const Color(0xFFF9FAFB),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
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
  reportsTo: reportsTo,
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

  Future<void> _openEditMemberDialog(int index, TeamMember member, List<TeamMember> members) async {
  final nameController = TextEditingController(text: member.name);
  final roleController = TextEditingController(text: member.role);
  final emailController = TextEditingController(text: member.email);
  final responsibilitiesController = TextEditingController(text: member.responsibilities);
  String reportsTo = member.reportsTo;
  final formKey = GlobalKey<FormState>();
  final focusColor = const Color(0xFFFFD700);

  final result = await showDialog<TeamMember>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) {
  return StatefulBuilder(
  builder: (context, dialogSetState) {
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
  color: const Color(0xFFEFF6FF),
  borderRadius: BorderRadius.circular(14),
  ),
  child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6)),
  ),
  const SizedBox(width: 12),
  const Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text('Edit team member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
  SizedBox(height: 4),
  Text('Update role, responsibilities, or reporting line.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
  controller: nameController, label: 'Full name',
  validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required' : null,
  ),
  const SizedBox(height: 12),
  _DialogTextField(
  controller: emailController, label: 'Work email',
  hintText: 'name@company.com', keyboardType: TextInputType.emailAddress,
  ),
  const SizedBox(height: 20),
  const _DialogSectionTitle(title: 'Role & coverage'),
  const SizedBox(height: 10),
  _DialogTextField(
  controller: roleController, label: 'Role',
  hintText: 'e.g., Project Lead', focusColor: focusColor,
  onChanged: (value) {
    if (responsibilitiesController.text.isEmpty && responsibilitiesController.text != member.responsibilities) {
      final entry = getRoleDescription(value);
      if (entry != null) {
        responsibilitiesController.text = entry.description;
      }
    }
    dialogSetState(() {});
  },
  ),
  const SizedBox(height: 10),
  ...roleCategories.map((category) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          category.label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
        ),
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: category.roles.map((role) => ChoiceChip(
          label: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          selected: roleController.text == role,
          onSelected: (_) {
            roleController.text = role;
            final entry = getRoleDescription(role);
            if (entry != null && responsibilitiesController.text.isEmpty) {
              responsibilitiesController.text = entry.description;
            }
            dialogSetState(() {});
          },
          selectedColor: const Color(0xFFFFF3CD),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
        )).toList(),
      ),
      const SizedBox(height: 8),
    ],
  )),
  const SizedBox(height: 20),
  const _DialogSectionTitle(title: 'Reporting Line'),
  const SizedBox(height: 10),
  DropdownButtonFormField<String>(
  value: reportsTo.isEmpty ? null : reportsTo,
  onChanged: (v) => setState(() => reportsTo = v ?? ''),
  items: [
  const DropdownMenuItem(value: '', child: Text('None (Top-level)')),
  ...members.where((m) => m.id != member.id).map((m) => DropdownMenuItem(
  value: m.id, child: Text('${m.name} (${m.role})'),
  )),
  ],
  decoration: InputDecoration(
  labelText: 'Reports To',
  filled: true, fillColor: const Color(0xFFF9FAFB),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
  ),
  const SizedBox(height: 20),
  const _DialogSectionTitle(title: 'Responsibilities'),
  const SizedBox(height: 10),
  _DialogTextField(
  controller: responsibilitiesController, label: 'Key responsibilities',
  maxLines: 4, hintText: 'Add key responsibilities, separated by line breaks.',
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
  if (formKey.currentState?.validate() != true) return;
  Navigator.of(dialogContext).pop(TeamMember(
  id: member.id,
  name: nameController.text.trim(),
  role: roleController.text.trim(),
  email: emailController.text.trim(),
  responsibilities: responsibilitiesController.text.trim(),
  reportsTo: reportsTo,
  ));
  },
  style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFFFFD700),
  foregroundColor: const Color(0xFF111827),
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  child: const Text('Save'),
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

  if (result == null || !mounted) return;

  final updated = List<TeamMember>.from(members);
  updated[index] = result;
  await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'team_management',
  dataUpdater: (data) => data.copyWith(teamMembers: updated),
  showSnackbar: false,
  );
  if (!mounted) return;
  await FirebaseFirestore.instance
  .collection('projects')
  .doc(ProjectDataHelper.getProvider(context).projectData.projectId)
  .collection('team_members')
  .doc(result.id)
  .set(result.toJson(), SetOptions(merge: true));
  }

  Future<void> _deleteMember(int index, List<TeamMember> members) async {
  final member = members[index];
  final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
  title: const Text('Remove team member'),
  content: Text('Remove ${member.name.isNotEmpty ? member.name : 'this member'} from the team?'),
  actions: [
  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
  TextButton(
  onPressed: () => Navigator.pop(ctx, true),
  child: const Text('Remove', style: TextStyle(color: Colors.red)),
  ),
  ],
  ),
  );
  if (confirmed != true || !mounted) return;

  final updated = List<TeamMember>.from(members)..removeAt(index);
  await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'team_management',
  dataUpdater: (data) => data.copyWith(teamMembers: updated),
  showSnackbar: false,
  );
  if (!mounted) return;
  final projectId = ProjectDataHelper.getProvider(context).projectData.projectId;
  if (projectId != null && projectId.isNotEmpty) {
  await FirebaseFirestore.instance
  .collection('projects')
  .doc(projectId)
  .collection('team_members')
  .doc(member.id)
  .delete();
  }
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
      final members =
          snapshot.docs.map((doc) => TeamMember.fromJson(doc.data())).toList();
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

  Future<void> _openPersonnelRates() async {
    final data = ProjectDataHelper.getData(context);
    final existingCards = List<RateCard>.from(data.rateCards);
    final result = await RateCardManagementDialog.show(
      context,
      existingCards: existingCards,
    );
    if (result != null && mounted) {
      final provider = ProjectDataHelper.getProvider(context);
      provider.updateField((pd) => pd.copyWith(rateCards: result));
      await provider.saveToFirebase(checkpoint: 'rate_cards');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length} rate card(s) saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
  final columns = width >= 1200 ? 3 : width >= 840 ? 2 : 1;
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
  OutlinedButton.icon(
  onPressed: _openPersonnelRates,
  icon: const Icon(Icons.attach_money, size: 16),
  label: const Text('Rates'),
  style: OutlinedButton.styleFrom(
  foregroundColor: const Color(0xFF059669),
  side: const BorderSide(color: Color(0xFF059669)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  ),
  const SizedBox(width: 10),
  CsvTableImportButton(
    tableTitle: 'Team Members',
    columns: _teamMemberCsvColumns,
    onImport: (rows) async {
      for (final row in rows) {
        final member = TeamMember(
          name: row['name'] ?? '',
          role: row['role'] ?? '',
          email: row['email'] ?? '',
          responsibilities: row['responsibilities'] ?? '',
          reportsTo: row['reportsTo'] ?? '',
        );
        await _persistMember(member);
        // Update provider data
        if (!mounted) return;
        final currentMembers = context.read<ProjectDataProvider>().projectData.teamMembers;
        final updated = [...currentMembers, member];
        await ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'team_management',
          dataUpdater: (data) => data.copyWith(teamMembers: updated),
          showSnackbar: false,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rows.length} team member(s) imported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    },
    compact: true,
  ),
  const SizedBox(width: 10),
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
  label: const Text('Add New Member', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
  if (members.isNotEmpty) ...[
  _OrgChartWidget(members: members),
  const SizedBox(height: 24),
  ],
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
  itemBuilder: (context, index) => _TeamRoleCard(
  member: members[index],
  onEdit: () => _openEditMemberDialog(index, members[index], members),
  onDelete: () => _deleteMember(index, members),
  ),
  ),
  const SizedBox(height: 28),
  Align(
  alignment: Alignment.centerRight,
  child: ElevatedButton(
  onPressed: () => PlanningPhaseNavigation.goToNext(context, 'team_management'),
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
        PdfSection.text(
            'Notes',
            projectData
                    .planningNotes['planning_team_management_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

// ─── Team Members Tab ──────────────────────────────────────────────

class _TeamMembersTab extends StatelessWidget {
  const _TeamMembersTab({
    required this.onAddMember,
    required this.onPersist,
  });

  final Future<void> Function(List<TeamMember>) onAddMember;
  final Future<void> Function(TeamMember) onPersist;

  @override
  Widget build(BuildContext context) {
    final members = context.select<ProjectDataProvider, List<TeamMember>>(
      (provider) => provider.projectData.teamMembers,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Team Roles & Responsibilities',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => onAddMember(members),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Member',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (members.isEmpty)
            _EmptyStateCard(
              title: 'No team members yet',
              message:
                  'Add team members to define roles, responsibilities, and ownership.',
              onAdd: () => onAddMember(members),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: members
                  .map((m) => SizedBox(
                        width: 300,
                        child: _TeamRoleCard(member: m),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Mobilization Checklist Tab ─────────────────────────────────────

class _MobilizationChecklistTab extends StatefulWidget {
  const _MobilizationChecklistTab();

  @override
  State<_MobilizationChecklistTab> createState() =>
      _MobilizationChecklistTabState();
}

class _MobilizationChecklistTabState
    extends State<_MobilizationChecklistTab> {
  static const _categories = [
    'Documentation',
    'Access',
    'Training',
    'Equipment',
    'Other',
  ];

  void _addItem() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Documentation';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Mobilization Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => selectedCategory = v ?? selectedCategory),
                decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final item = MobilizationChecklistItem(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  category: selectedCategory,
                );
                Navigator.pop(ctx, item);
              },
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((item) {
      if (item != null && item is MobilizationChecklistItem) {
        ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'team_management',
          dataUpdater: (d) => d.copyWith(
            mobilizationChecklist: [...d.mobilizationChecklist, item],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checklist = context.select<ProjectDataProvider,
        List<MobilizationChecklistItem>>(
      (provider) => provider.projectData.mobilizationChecklist,
    );
    final completed =
        checklist.where((i) => i.isCompleted).length;
    final progress =
        checklist.isEmpty ? 0.0 : completed / checklist.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mobilization Checklist',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              if (checklist.isNotEmpty)
                Text(
                  '$completed/${checklist.length} complete',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _kSecondaryText,
                      fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Track onboarding tasks for each team member. Completed items trigger the Mobilize Team aspect in Execution.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          if (checklist.isNotEmpty) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : _kAccent),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),
          ],
          if (checklist.isEmpty)
            _EmptyStateCard(
              title: 'No mobilization items',
              message:
                  'Add checklist items for team onboarding tasks.',
              onAdd: _addItem,
            )
          else
            ...checklist.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.isCompleted
                      ? const Color(0xFFF0FDF4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: item.isCompleted
                          ? const Color(0xFF86EFAC)
                          : _kBorderColor),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: item.isCompleted,
                      onChanged: (val) {
                        final provider = ProjectDataHelper.getProvider(
                            context);
                        final updated = [...provider.projectData.mobilizationChecklist];
                        updated[i] = item.copyWith(
                            isCompleted: val ?? false);
                        provider.updateField((d) => d.copyWith(
                            mobilizationChecklist: updated));
                      },
                      activeColor: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _categoryColor(item.category)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item.category,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _categoryColor(item.category))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kPrimaryText,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null)),
                          if (item.description.isNotEmpty)
                            Text(item.description,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _kSecondaryText)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFEF4444)),
                      onPressed: () {
                        final provider = ProjectDataHelper.getProvider(
                            context);
                        final updated = [...provider.projectData.mobilizationChecklist];
                        updated.removeAt(i);
                        provider.updateField((d) => d.copyWith(
                            mobilizationChecklist: updated));
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Documentation':
        return const Color(0xFF3B82F6);
      case 'Access':
        return const Color(0xFF8B5CF6);
      case 'Training':
        return const Color(0xFF10B981);
      case 'Equipment':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ─── Project Onboarding Documents Tab ──────────────────────────────

class _ProjectOnboardingTab extends StatelessWidget {
  const _ProjectOnboardingTab();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getData(context);
    final docs = data.onboardingDocuments;

    // Build auto-generated content from project data
    final projectSummary = _buildProjectSummary(data);
    final scopeDoc = _buildScopeDocument(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Project Onboarding Documents',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateDocuments(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate from Project Data',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Project summary is auto-generated from Project Details (Planning phase overrides Initiation for any conflicts). Scope, out-of-scope, and boundaries remain consistent throughout.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          // Auto-generated Project Summary
          _DocumentCard(
            title: 'Project Summary',
            type: 'project_summary',
            content: projectSummary,
            isAutoGenerated: true,
          ),
          const SizedBox(height: 12),
          // Auto-generated Scope Document
          _DocumentCard(
            title: 'Scope, In-Scope & Out-of-Scope',
            type: 'scope',
            content: scopeDoc,
            isAutoGenerated: true,
          ),
          // Manual documents
          ...docs
              .where((d) => d.type != 'project_summary' && d.type != 'scope')
              .map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DocumentCard(
                      title: doc.title,
                      type: doc.type,
                      content: doc.content,
                      isAutoGenerated: doc.isAutoGenerated,
                    ),
                  )),
        ],
      ),
    );
  }

  String _buildProjectSummary(data) {
    final parts = <String>[];
    final name =
        data.projectName?.toString().trim() ?? '';
    if (name.isNotEmpty) parts.add('Project Name: $name');

    final obj = data.projectObjective?.toString().trim() ?? '';
    if (obj.isNotEmpty) parts.add('Project Objective: $obj');

    final solution = data.potentialSolution?.toString().trim() ?? '';
    if (solution.isNotEmpty) parts.add('Proposed Solution: $solution');

    // Prefer planning goals over project goals
    final planGoals = data.planningGoals;
    if (planGoals.isNotEmpty) {
      parts.add('Project Goals:');
      for (final g in planGoals) {
        parts.add('  • ${g.title}: ${g.description}');
      }
    } else {
      final goals = data.projectGoals;
      if (goals.isNotEmpty) {
        parts.add('Project Goals:');
        for (final g in goals) {
          parts.add('  • ${g.name}: ${g.description}');
        }
      }
    }

    final framework = data.overallFramework?.toString() ?? '';
    if (framework.isNotEmpty) parts.add('Methodology: $framework');

    return parts.isEmpty
        ? 'No project data available. Complete Project Details first.'
        : parts.join('\n\n');
  }

  String _buildScopeDocument(data) {
    final parts = <String>[];

    final inScope = data.withinScopeItems;
    if (inScope.isNotEmpty) {
      parts.add('In Scope:');
      for (final item in inScope) {
        parts.add('  • ${item.title}: ${item.description}');
      }
    }

    final outScope = data.outOfScopeItems;
    if (outScope.isNotEmpty) {
      parts.add('Out of Scope:');
      for (final item in outScope) {
        parts.add('  • ${item.title}: ${item.description}');
      }
    }

    final constraints = data.constraintItems;
    if (constraints.isNotEmpty) {
      parts.add('Constraints & Boundaries:');
      for (final item in constraints) {
        parts.add('  • ${item.title}: ${item.description}');
      }
    }

    final assumptions = data.assumptionItems;
    if (assumptions.isNotEmpty) {
      parts.add('Assumptions:');
      for (final item in assumptions) {
        parts.add('  • ${item.title}: ${item.description}');
      }
    }

    return parts.isEmpty
        ? 'No scope data available. Complete Project Details first.'
        : parts.join('\n\n');
  }

  void _generateDocuments(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Onboarding documents refreshed from project data.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}

// ─── Role Onboarding Documents Tab ─────────────────────────────────

class _RoleOnboardingTab extends StatefulWidget {
  const _RoleOnboardingTab();

  @override
  State<_RoleOnboardingTab> createState() => _RoleOnboardingTabState();
}

class _RoleOnboardingTabState extends State<_RoleOnboardingTab> {
  bool _isGenerating = false;

  Future<void> _generateSuggestions() async {
    setState(() => _isGenerating = true);
    // Simulate AI suggestion generation
    await Future.delayed(const Duration(seconds: 2));

    final provider = ProjectDataHelper.getProvider(context);
    final roles = provider.projectData.projectRoles;
    final existing = provider.projectData.roleOnboardingRequirements;

    final suggestions = <RoleOnboardingRequirement>[];
    for (final role in roles) {
      final roleLower = role.title.toLowerCase();
      // Skip if already has requirements for this role
      if (existing.any((r) => r.roleTitle == role.title)) continue;

      if (roleLower.contains('project manager') ||
          roleLower.contains('pm')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'PMP/PRINCE2 Certification',
          description:
              'Valid project management certification required.',
          category: 'Certification',
          isRequired: true,
        ));
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'NDU Project Access',
          description:
              'Full access to project management tools and dashboards.',
          category: 'Access',
          isRequired: true,
        ));
      } else if (roleLower.contains('security')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'Security Clearance',
          description:
              'Current security clearance for the project classification level.',
          category: 'Certification',
          isRequired: true,
        ));
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'Security Training Completion',
          description:
              'Completion of project-specific security protocols training.',
          category: 'Training',
          isRequired: true,
        ));
      } else if (roleLower.contains('engineer') ||
          roleLower.contains('developer')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'Technical Onboarding',
          description:
              'Codebase walkthrough, development environment setup, and coding standards review.',
          category: 'Training',
          isRequired: true,
        ));
      } else if (roleLower.contains('qa') ||
          roleLower.contains('quality')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'QA Standards Review',
          description:
              'Review of quality assurance standards and testing protocols.',
          category: 'Training',
          isRequired: true,
        ));
      } else if (roleLower.contains('designer')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'Design System Access',
          description:
              'Access to design tools, brand guidelines, and design system.',
          category: 'Access',
          isRequired: true,
        ));
      } else if (roleLower.contains('procurement') ||
          roleLower.contains('contract')) {
        suggestions.add(RoleOnboardingRequirement(
          roleTitle: role.title,
          requirement: 'Procurement Authorization',
          description:
              'Authorization level for procurement and contract management.',
          category: 'Certification',
          isRequired: true,
        ));
      }
    }

    if (suggestions.isNotEmpty && mounted) {
      provider.updateField((d) => d.copyWith(
          roleOnboardingRequirements: [
            ...d.roleOnboardingRequirements,
            ...suggestions,
          ]));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Generated ${suggestions.length} role-specific requirements.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }

    if (mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final requirements = context.select<ProjectDataProvider,
        List<RoleOnboardingRequirement>>(
      (provider) => provider.projectData.roleOnboardingRequirements,
    );

    // Group by role
    final grouped = <String, List<RoleOnboardingRequirement>>{};
    for (final r in requirements) {
      grouped.putIfAbsent(r.roleTitle, () => []).add(r);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Role Onboarding Requirements',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    _isGenerating ? null : _generateSuggestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                    _isGenerating
                        ? 'Generating...'
                        : 'AI Suggest Requirements',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Role-specific onboarding requirements. AI suggests applicable certifications, training, and access based on project roles.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            _EmptyStateCard(
              title: 'No role requirements yet',
              message:
                  'Click "AI Suggest Requirements" to generate role-specific onboarding needs, or add them manually.',
              onAdd: _generateSuggestions,
            )
          else
            ...grouped.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
                  boxShadow: const [
                    BoxShadow(
                        color: _kCardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined,
                              size: 18, color: _kAccent),
                          const SizedBox(width: 8),
                          Text(entry.key,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimaryText)),
                          const Spacer(),
                          Text(
                              '${entry.value.where((r) => r.isRequired).length} required',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _kSecondaryText)),
                        ],
                      ),
                    ),
                    ...entry.value.asMap().entries.map((re) {
                      final req = re.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: _kBorderColor.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              req.isCompleted
                                  ? Icons.check_circle
                                  : req.isRequired
                                      ? Icons.warning_amber
                                      : Icons.info_outline,
                              size: 16,
                              color: req.isCompleted
                                  ? Colors.green
                                  : req.isRequired
                                      ? const Color(0xFFF59E0B)
                                      : _kSecondaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(req.requirement,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: _kPrimaryText)),
                                  if (req.description.isNotEmpty)
                                    Text(req.description,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color:
                                                _kSecondaryText)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _categoryColor(req.category)
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(req.category,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: _categoryColor(
                                          req.category))),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Certification':
        return const Color(0xFF3B82F6);
      case 'Training':
        return const Color(0xFF10B981);
      case 'Access':
        return const Color(0xFF8B5CF6);
      case 'Document':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ─── Team Recognition Tab ──────────────────────────────────────────

class _TeamRecognitionTab extends StatefulWidget {
  const _TeamRecognitionTab();

  @override
  State<_TeamRecognitionTab> createState() => _TeamRecognitionTabState();
}

class _TeamRecognitionTabState extends State<_TeamRecognitionTab> {
  static const _categories = [
    'Milestone Achievement',
    'Innovation Award',
    'Collaboration Award',
    'Leadership Excellence',
    'Quality Excellence',
    'Rising Star',
  ];

  void _addRecognition() {
    final recipientController = TextEditingController();
    final roleController = TextEditingController();
    final descController = TextEditingController();
    final nominatedByController = TextEditingController();
    String selectedCategory = 'Milestone Achievement';

    // Pre-fill from team members
    final members = ProjectDataHelper.getData(context).teamMembers;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nominate Recognition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (members.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    hint: const Text('Select team member'),
                    items: members
                        .map((m) => DropdownMenuItem(
                            value: m.name, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        recipientController.text = v ?? '';
                        final member = members.firstWhere(
                            (m) => m.name == v,
                            orElse: () => members.first);
                        roleController.text = member.role;
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Recipient',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: recipientController,
                  decoration: const InputDecoration(
                      labelText: 'Recipient Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                      labelText: 'Role', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCategory = v ?? selectedCategory),
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nominatedByController,
                  decoration: const InputDecoration(
                      labelText: 'Nominated By',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (recipientController.text.trim().isEmpty) return;
                final recognition = TeamRecognition(
                  recipientName: recipientController.text.trim(),
                  recipientRole: roleController.text.trim(),
                  category: selectedCategory,
                  description: descController.text.trim(),
                  nominatedBy: nominatedByController.text.trim(),
                  date: DateTime.now().toString().split(' ').first,
                );
                Navigator.pop(ctx, recognition);
              },
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    ).then((item) {
      if (item != null && item is TeamRecognition) {
        ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'team_management',
          dataUpdater: (d) => d.copyWith(
            teamRecognitions: [...d.teamRecognitions, item],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recognitions = context.select<ProjectDataProvider,
        List<TeamRecognition>>(
      (provider) => provider.projectData.teamRecognitions,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Team Member Recognition',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addRecognition,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nominate',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Recognize outstanding contributions. This section is optional and not available for regular projects.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          if (recognitions.isEmpty)
            _EmptyStateCard(
              title: 'No recognitions yet',
              message:
                  'Nominate team members for outstanding contributions.',
              onAdd: _addRecognition,
            )
          else
            ...recognitions.asMap().entries.map((entry) {
              final r = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
                  boxShadow: const [
                    BoxShadow(
                        color: _kCardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kLightYellow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events,
                          color: _kAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.recipientName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimaryText)),
                          const SizedBox(height: 2),
                          Text('${r.category} • ${r.recipientRole}',
                              style: const TextStyle(
                                  fontSize: 11, color: _kSecondaryText)),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.description,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: _kPrimaryText)),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.status == 'Approved'
                            ? const Color(0xFFDCFCE7)
                            : r.status == 'Rejected'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(r.status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: r.status == 'Approved'
                                  ? const Color(0xFF16A34A)
                                  : r.status == 'Rejected'
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706))),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Role Handover Tab ─────────────────────────────────────────────

class _RoleHandoverTab extends StatefulWidget {
  const _RoleHandoverTab();

  @override
  State<_RoleHandoverTab> createState() => _RoleHandoverTabState();
}

class _RoleHandoverTabState extends State<_RoleHandoverTab> {
  void _createHandover() {
    final members = ProjectDataHelper.getData(context).teamMembers;

    final memberNameController = TextEditingController();
    final memberRoleController = TextEditingController();
    final receivingNameController = TextEditingController();
    final receivingRoleController = TextEditingController();
    final handoverDateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Handover Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Required before any team member leaves the project.',
                  style: TextStyle(fontSize: 12, color: _kSecondaryText),
                ),
                const SizedBox(height: 16),
                if (members.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    hint: const Text('Select departing member'),
                    items: members
                        .map((m) => DropdownMenuItem(
                            value: m.name, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        memberNameController.text = v ?? '';
                        final member = members.firstWhere(
                            (m) => m.name == v,
                            orElse: () => members.first);
                        memberRoleController.text = member.role;
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Departing Team Member',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: memberNameController,
                  decoration: const InputDecoration(
                      labelText: 'Team Member Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memberRoleController,
                  decoration: const InputDecoration(
                      labelText: 'Role', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receivingNameController,
                  decoration: const InputDecoration(
                      labelText: 'Receiving Team Member',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receivingRoleController,
                  decoration: const InputDecoration(
                      labelText: 'Receiving Role',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: handoverDateController,
                  decoration: const InputDecoration(
                      labelText: 'Handover Date',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (memberNameController.text.trim().isEmpty) return;
                final handover = RoleHandoverTemplate(
                  teamMemberName: memberNameController.text.trim(),
                  teamMemberRole: memberRoleController.text.trim(),
                  receivingMemberName:
                      receivingNameController.text.trim(),
                  receivingMemberRole:
                      receivingRoleController.text.trim(),
                  handoverDate: handoverDateController.text.trim(),
                );
                Navigator.pop(ctx, handover);
              },
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((item) {
      if (item != null && item is RoleHandoverTemplate) {
        ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'team_management',
          dataUpdater: (d) => d.copyWith(
            roleHandoverTemplates: [...d.roleHandoverTemplates, item],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.select<ProjectDataProvider,
        List<RoleHandoverTemplate>>(
      (provider) => provider.projectData.roleHandoverTemplates,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Role Handover Templates',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createHandover,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Handover',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Must be completed before any team member leaves the project.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          if (templates.isEmpty)
            _EmptyStateCard(
              title: 'No handover templates',
              message:
                  'Create a handover template when a team member is transitioning off the project.',
              onAdd: _createHandover,
            )
          else
            ...templates.asMap().entries.map((entry) {
              final h = entry.value;
              final completed = [
                h.workDeliverablesComplete,
                h.documentationComplete,
                h.risksOpenItemsComplete,
                h.systemsAccessComplete,
              ];
              final progress =
                  completed.where((c) => c).length / completed.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
                  boxShadow: const [
                    BoxShadow(
                        color: _kCardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.swap_horiz,
                              color: Color(0xFF8B5CF6), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${h.teamMemberName} → ${h.receivingMemberName}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _kPrimaryText)),
                              const SizedBox(height: 2),
                              Text(
                                  '${h.teamMemberRole} • ${h.handoverDate}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: _kSecondaryText)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: h.status == 'Completed'
                                ? const Color(0xFFDCFCE7)
                                : h.status == 'In Progress'
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(h.status,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: h.status == 'Completed'
                                      ? const Color(0xFF16A34A)
                                      : h.status == 'In Progress'
                                          ? const Color(0xFFD97706)
                                          : _kSecondaryText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? Colors.green
                              : _kAccent),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '${(progress * 100).toInt()}% complete • ${completed.where((c) => c).length}/4 categories',
                        style: const TextStyle(
                            fontSize: 11, color: _kSecondaryText)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Team Activities Tab ───────────────────────────────────────────

class _TeamActivitiesTab extends StatefulWidget {
  const _TeamActivitiesTab();

  @override
  State<_TeamActivitiesTab> createState() => _TeamActivitiesTabState();
}

class _TeamActivitiesTabState extends State<_TeamActivitiesTab> {
  void _addActivity() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final postedByController = TextEditingController();
    String selectedCategory = 'Update';

    final members = ProjectDataHelper.getData(context).teamMembers;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Post Team Activity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (members.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    hint: const Text('Select team member'),
                    items: members
                        .map((m) => DropdownMenuItem(
                            value: m.name, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => postedByController.text = v ?? ''),
                    decoration: const InputDecoration(
                        labelText: 'Posted By',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: const [
                    'Update',
                    'Announcement',
                    'Event',
                    'Action Required',
                  ]
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCategory = v ?? selectedCategory),
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final activity = TeamActivity(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  postedBy: postedByController.text.trim(),
                  date: DateTime.now().toString().split(' ').first,
                  category: selectedCategory,
                );
                Navigator.pop(ctx, activity);
              },
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    ).then((item) {
      if (item != null && item is TeamActivity) {
        ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'team_management',
          dataUpdater: (d) => d.copyWith(
            teamActivities: [item, ...d.teamActivities],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activities = context.select<ProjectDataProvider, List<TeamActivity>>(
      (provider) => provider.projectData.teamActivities,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Team Activities',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kPrimaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Post Activity',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Activity feed for project team communications and updates.',
            style: TextStyle(fontSize: 12, color: _kSecondaryText),
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            _EmptyStateCard(
              title: 'No activities yet',
              message: 'Post team activities and updates here.',
              onAdd: _addActivity,
            )
          else
            ...activities.map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
                  boxShadow: const [
                    BoxShadow(
                        color: _kCardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _activityCategoryColor(a.category)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(a.category,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _activityCategoryColor(a.category))),
                        ),
                        const SizedBox(width: 8),
                        Text(a.date,
                            style: const TextStyle(
                                fontSize: 11, color: _kSecondaryText)),
                        const Spacer(),
                        Text('by ${a.postedBy}',
                            style: const TextStyle(
                                fontSize: 11, color: _kSecondaryText)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kPrimaryText)),
                    if (a.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(a.description,
                          style: const TextStyle(
                              fontSize: 12, color: _kSecondaryText)),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _activityCategoryColor(String category) {
    switch (category) {
      case 'Update':
        return const Color(0xFF3B82F6);
      case 'Announcement':
        return const Color(0xFF8B5CF6);
      case 'Event':
        return const Color(0xFF10B981);
      case 'Action Required':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────

class _TeamRoleCard extends StatelessWidget {
  const _TeamRoleCard({required this.member, this.onEdit, this.onDelete});

  final TeamMember member;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
  child: const Icon(Icons.work_outline, color: Color(0xFFD97706), size: 20),
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
  PopupMenuButton<String>(
  icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
  onSelected: (v) {
  if (v == 'edit') onEdit?.call();
  if (v == 'delete') onDelete?.call();
  },
  itemBuilder: (_) => [
  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')])),
  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))])),
  ],
  ),
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

/// Tree layout node for the org chart
class _OrgNode {
  final TeamMember member;
  List<_OrgNode> children;
  double x;
  double y;
  _OrgNode(this.member)
      : children = [],
        x = 0,
        y = 0;
}

/// Auto-generated organisational chart based on the reporting structure.
class _OrgChartWidget extends StatelessWidget {
  const _OrgChartWidget({required this.members});
  final List<TeamMember> members;

  List<_OrgNode> _buildTree() {
    final byId = <String, _OrgNode>{};
    for (final m in members) {
      byId[m.id] = _OrgNode(m);
    }
    final roots = <_OrgNode>[];
    for (final m in members) {
      final node = byId[m.id]!;
      if (m.reportsTo.isEmpty || !byId.containsKey(m.reportsTo)) {
        roots.add(node);
      } else {
        byId[m.reportsTo]?.children.add(node);
      }
    }
    return roots;
  }

  void _layout(List<_OrgNode> roots, double startX, double startY) {
    final nodeW = 160.0;
    final nodeH = 60.0;
    final hGap = 24.0;
    final vGap = 64.0;
    int count = 0;

    void dfs(_OrgNode node, int depth) {
      node.y = startY + depth * (nodeH + vGap);
      if (node.children.isEmpty) {
        node.x = startX + count * (nodeW + hGap);
        count++;
      } else {
        for (final child in node.children) {
          dfs(child, depth + 1);
        }
        node.x = (node.children.first.x + node.children.last.x) / 2;
      }
    }

    for (final root in roots) {
      dfs(root, 0);
      count = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final roots = _buildTree();
    if (roots.isEmpty) return const SizedBox.shrink();

    _layout(roots, 0, 0);

    final allNodes = <_OrgNode>[];
    void collect(_OrgNode n) {
      allNodes.add(n);
      for (final c in n.children) collect(c);
    }
    for (final r in roots) collect(r);

    final nodeW = 160.0;
    final nodeH = 60.0;
    final minX = allNodes.fold<double>(0, (p, n) => math.min(p, n.x));
    final maxX = allNodes.fold<double>(0, (p, n) => math.max(p, n.x + nodeW));
    final minY = allNodes.fold<double>(0, (p, n) => math.min(p, n.y));
    final maxY = allNodes.fold<double>(0, (p, n) => math.max(p, n.y + nodeH));

    final data = _OrgChartData(nodes: allNodes, roots: roots);
    final painter = _OrgChartPainter(data: data, nodeW: nodeW, nodeH: nodeH);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            const Text(
              'Organisational Chart',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            const Spacer(),
            Text(
              '${members.length} member${members.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (maxX - minX) + 40,
                height: (maxY - minY) + 40,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size((maxX - minX) + 40, (maxY - minY) + 40),
                      painter: painter,
                    ),
                    ...allNodes.map((node) {
                      final left = (node.x - minX) + 20;
                      final top = (node.y - minY) + 20;
                      return Positioned(
                        left: left,
                        top: top,
                        child: _OrgNodeCard(node: node),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Data holder for the org chart painter
class _OrgChartData {
  final List<_OrgNode> nodes;
  final List<_OrgNode> roots;
  _OrgChartData({required this.nodes, required this.roots});
}

/// Custom painter that draws connecting lines between parent and child nodes.
class _OrgChartPainter extends CustomPainter {
  final _OrgChartData data;
  final double nodeW;
  final double nodeH;

  _OrgChartPainter({required this.data, required this.nodeW, required this.nodeH});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final allById = <String, _OrgNode>{};
    for (final n in data.nodes) {
      allById[n.member.id] = n;
    }

    for (final node in data.nodes) {
      if (node.member.reportsTo.isEmpty) continue;
      final parent = allById[node.member.reportsTo];
      if (parent == null) continue;

      final parentCenterX = parent.x + nodeW / 2;
      final parentBottom = parent.y + nodeH;
      final childCenterX = node.x + nodeW / 2;
      final childTop = node.y;

      final midY = parentBottom + (childTop - parentBottom) / 2;

      final path = Path();
      path.moveTo(parentCenterX, parentBottom);
      path.lineTo(parentCenterX, midY);
      path.lineTo(childCenterX, midY);
      path.lineTo(childCenterX, childTop);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrgChartPainter oldDelegate) => true;
}

/// A single card in the org chart tree
class _OrgNodeCard extends StatelessWidget {
  const _OrgNodeCard({required this.node});
  final _OrgNode node;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.member.name.isNotEmpty ? node.member.name : 'Unnamed',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            node.member.role.isNotEmpty ? node.member.role : 'Role not set',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (node.children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('IC', style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.onAdd,
  });

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
        border: Border.all(color: _kBorderColor),
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
            child: const Icon(Icons.group_outlined,
                color: Color(0xFFF59E0B)),
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
                        color: _kPrimaryText)),
                const SizedBox(height: 6),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: _kSecondaryText)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimaryText,
              side: const BorderSide(color: _kBorderColor),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.type,
    required this.content,
    required this.isAutoGenerated,
  });

  final String title;
  final String type;
  final String content;
  final bool isAutoGenerated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [
          BoxShadow(
              color: _kCardShadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAutoGenerated ? Icons.auto_awesome : Icons.description,
                size: 18,
                color: _kAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kPrimaryText)),
              ),
              if (isAutoGenerated)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Auto-generated',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(content,
                style: const TextStyle(
                    fontSize: 12,
                    color: _kPrimaryText,
                    height: 1.6)),
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
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _kPrimaryText),
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
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorderColor)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: focusColor ?? _kAccent, width: 1.6),
        ),
      ),
    );
  }
}
