import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/screens/salvage_disposal_team_screen.dart';
import 'package:ndu_project/screens/technical_debt_management_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/services/ops_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:go_router/go_router.dart';
class IdentifyStaffOpsTeamScreen extends StatefulWidget {
  const IdentifyStaffOpsTeamScreen({super.key});

  static void open(BuildContext context) {
    context.push('/identify-staff-ops-team');
  }

  @override
  State<IdentifyStaffOpsTeamScreen> createState() =>
      _IdentifyStaffOpsTeamScreenState();
}

class _IdentifyStaffOpsTeamScreenState
    extends State<IdentifyStaffOpsTeamScreen> {
  String? get _projectId {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      return provider?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _autoPopulateIfNeeded());
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Identify Staff & Ops Team',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['identify_staff_ops_team_screen'] ??
                'No data recorded.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 980;
    final padding = AppBreakpoints.pagePadding(context);

    return ResponsiveScaffold(
      activeItemLabel: 'Identify and Staff Ops Team',
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanningPhaseHeader(
                title: 'Identify and Staff Ops Team',
                showNavigationButtons: false,
                onExportPdf: _exportPdf),
            const SizedBox(height: 16),
            _buildHeader(isNarrow),
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRosterPanel(),
                const SizedBox(height: 20),
                _buildChecklistPanel(),
                const SizedBox(height: 24),
                LaunchPhaseNavigation(
                  backLabel: PlanningPhaseNavigation.backLabel('identify_staff_ops_team'),
                  nextLabel: PlanningPhaseNavigation.nextLabel('identify_staff_ops_team'),
                  onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'identify_staff_ops_team'),
                  onNext: () => PlanningPhaseNavigation.goToNext(context, 'identify_staff_ops_team'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC812),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'OPS READINESS',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identify & Staff Ops Team',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Confirm operational roles, coverage, and training readiness before handover.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            if (!isNarrow) const SizedBox.shrink(),
          ],
        ),
        if (isNarrow) ...[
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(Icons.upload_file_outlined, 'Import CSV',
            onPressed: () async {
          final rows = await showCsvImportDialog(context,
              tableTitle: 'Ops Team',
              columns: [
                const CsvColumnSpec(
                    key: 'name', label: 'Member Name', sampleValue: 'John Doe'),
                const CsvColumnSpec(
                    key: 'role', label: 'Role', sampleValue: 'Operations Lead'),
                const CsvColumnSpec(
                    key: 'email',
                    label: 'Email',
                    sampleValue: 'john@company.com'),
              ]);
          if (rows == null || !mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${rows.length} members imported from CSV'),
              backgroundColor: Colors.green));
        }),
        _actionButton(Icons.person_add_alt_1, 'Add role',
            onPressed: () => _showAddMemberDialog(context)),
        _actionButton(Icons.assignment_ind_outlined, 'Assign member'),
        _actionButton(Icons.description_outlined, 'Export roster'),
        _primaryButton('Publish handoff'),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B))),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _primaryButton(String label) {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Ops handoff published. Continue updating checklist completion as evidence.')),
        );
      },
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC812),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _autoPopulateIfNeeded() async {
    if (_autoGenerationTriggered || _isAutoGenerating) return;
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;
    _autoGenerationTriggered = true;
    setState(() => _isAutoGenerating = true);

    final membersSnap = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('ops_members')
        .limit(1)
        .get();
    final checklistSnap = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('ops_checklist')
        .limit(1)
        .get();

    final needsMembers = membersSnap.docs.isEmpty;
    final needsChecklist = checklistSnap.docs.isEmpty;

    if (!needsMembers && !needsChecklist) {
      if (mounted) setState(() => _isAutoGenerating = false);
      return;
    }

    Map<String, List<LaunchEntry>> generated = {};
    try {
      generated = await ExecutionPhaseAiSeed.generateEntries(
        context: context,
        section: 'Identify & Staff Ops Team',
        sections: const {
          'roles': 'Ops roles with responsibilities and readiness',
          'checklist': 'Ops readiness checklist items',
        },
        itemsPerSection: 4,
      );
    } catch (error) {
      debugPrint('Ops team AI call failed: $error');
    }

    if (!mounted) return;
    if (needsMembers) {
      final members = _mapOpsMembers(generated['roles']);
      for (final member in members) {
        await OpsService.createMember(
          projectId: projectId,
          name: member.name,
          role: member.role,
          responsibility: member.responsibility,
          status: member.status,
          readinessScore: member.readinessScore,
          notes: member.notes,
        );
      }
    }
    if (needsChecklist) {
      final items = _mapChecklistItems(generated['checklist']);
      for (final item in items) {
        await OpsService.createChecklistItem(
          projectId: projectId,
          item: item,
          completed: false,
        );
      }
    }

    if (mounted) {
      setState(() => _isAutoGenerating = false);
    }
  }

  List<_OpsMemberSeed> _mapOpsMembers(List<LaunchEntry>? entries) {
    if (entries == null) return [];
    return entries
        .map((entry) {
          final details = entry.details;
          final name = _extractField(details, 'Name');
          final role = _extractField(details, 'Role');
          final responsibility = _extractField(details, 'Responsibility');
          final status = _extractField(details, 'Status');
          final readiness = _extractNumber(details, fallback: 75);
          return _OpsMemberSeed(
            name: name.isNotEmpty ? name : entry.title.trim(),
            role: role.isNotEmpty ? role : 'Ops Specialist',
            responsibility:
                responsibility.isNotEmpty ? responsibility : entry.details,
            status: status.isNotEmpty ? status : 'Active',
            readinessScore: readiness,
            notes: entry.status,
          );
        })
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  List<String> _mapChecklistItems(List<LaunchEntry>? entries) {
    if (entries == null) return [];
    return entries
        .map((entry) => entry.title.trim().isNotEmpty
            ? entry.title.trim()
            : entry.details.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  String _extractField(String text, String key) {
    final match = RegExp('$key\\s*[:=-]\\s*([^|;\\n]+)', caseSensitive: false)
        .firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  int _extractNumber(String text, {required int fallback}) {
    final match = RegExp(r'(\\d{1,3})').firstMatch(text);
    return match != null ? int.parse(match.group(1) ?? '$fallback') : fallback;
  }

  Widget _buildRosterPanel() {
    if (_projectId == null) {
      return const _PanelShell(
        title: 'Ops roster',
        subtitle: 'Role assignments, workload, and focus areas',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No project selected. Please open a project first.',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
        ),
      );
    }

    return _PanelShell(
      title: 'Ops roster',
      subtitle: 'Role assignments, workload, and focus areas',
      trailing: _actionButton(Icons.filter_list, 'Filter'),
      child: RepaintBoundary(
        child: StreamBuilder<List<OpsMemberModel>>(
        stream: OpsService.streamMembers(_projectId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator()));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading members: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('No ops members found.',
                        style: TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMemberDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add First Member'),
                    ),
                  ],
                ),
              ),
            );
          }


 return FullScreenTableWrapper(
 title: 'Staff & Ops Team',
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: DataTable(
 headingRowHeight: 32,
 dataRowMinHeight: 28,
 dataRowMaxHeight: 36,
 columnSpacing: 14,
 horizontalMargin: 12,
 headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2937)),
 columns: const [
 DataColumn(
 label: Text('Name',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Role',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Responsibility',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Readiness',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Actions',
 style: TextStyle(fontWeight: FontWeight.w600))),
 ],
 rows: members.map((member) {
 return DataRow(cells: [
 DataCell(
 Text(member.name, style: const TextStyle(fontSize: 13))),
 DataCell(
 Text(member.role, style: const TextStyle(fontSize: 13))),
 DataCell(Text(member.responsibility,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B)))),
 DataCell(_statusChip(member.status)),
 DataCell(_capacityChip(member.readinessScore)),
 DataCell(
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () =>
 _showEditMemberDialog(context, member),
 borderRadius: BorderRadius.circular(4),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.edit,
 size: 16, color: Color(0xFF64748B)),
 ),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () =>
 _showDeleteMemberDialog(context, member),
 borderRadius: BorderRadius.circular(4),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.delete,
 size: 16, color: Color(0xFFEF4444)),
 ),
 ),
 ],
 ),
 ),
 ]);
 }).toList(),
 ),
 ),
 tableBuilder: (fsContext) => DataTable(
 headingRowHeight: 32,
 dataRowMinHeight: 28,
 dataRowMaxHeight: 36,
 columnSpacing: 14,
 horizontalMargin: 12,
 headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2937)),
 columns: const [
 DataColumn(
 label: Text('Name',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Role',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Responsibility',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Readiness',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Actions',
 style: TextStyle(fontWeight: FontWeight.w600))),
 ],
 rows: members.map((member) {
 return DataRow(cells: [
 DataCell(
 Text(member.name, style: const TextStyle(fontSize: 13))),
 DataCell(
 Text(member.role, style: const TextStyle(fontSize: 13))),
 DataCell(Text(member.responsibility,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B)))),
 DataCell(_statusChip(member.status)),
 DataCell(_capacityChip(member.readinessScore)),
 DataCell(
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () =>
 _showEditMemberDialog(fsContext, member),
 borderRadius: BorderRadius.circular(4),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.edit,
 size: 16, color: Color(0xFF64748B)),
 ),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () =>
 _showDeleteMemberDialog(fsContext, member),
 borderRadius: BorderRadius.circular(4),
 child: const Padding(
 padding: EdgeInsets.all(4),
 child: Icon(Icons.delete,
 size: 16, color: Color(0xFFEF4444)),
 ),
 ),
 ],
 ),
 ),
 ]);
 }).toList(),
 ),
 );
 },
 ),
      ),
    );
 }

  Widget _buildChecklistPanel() {
    if (_projectId == null) {
      return const _PanelShell(
        title: 'Readiness checklist',
        subtitle: 'Pre-handover verification',
        child: SizedBox.shrink(),
      );
    }


    return RepaintBoundary(
      child: StreamBuilder<List<OpsChecklistItemModel>>(
        stream: OpsService.streamChecklist(_projectId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PanelShell(
              title: 'Readiness checklist',
              subtitle: 'Pre-handover verification',
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator())),
            );
          }

          if (snapshot.hasError) {
            return _PanelShell(
              title: 'Readiness checklist',
              subtitle: 'Pre-handover verification',
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading checklist: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];

          return LaunchDataTable(
            title: 'Readiness Checklist',
            subtitle:
                'Pre-handover verification — add, edit, or remove items inline',
            columns: const [
              LaunchColumn(
                  label: 'Item',
                  flexible: true,
                  fieldType: LaunchFieldType.text,
                  hint: 'Checklist item'),
              LaunchColumn(
                  label: 'Notes',
                  flexible: true,
                  fieldType: LaunchFieldType.text,
                  hint: 'Notes / evidence'),
              LaunchColumn(
                  label: 'Status',
                  width: 130,
                  fieldType: LaunchFieldType.dropdown,
                  dropdownItems: [
                    'Complete',
                    'Pending',
                    'In Progress',
                    'Not Applicable'
                  ]),
            ],
            rowCount: items.length,
            onAddValues: (values) async {
              try {
                await OpsService.createChecklistItem(
                  projectId: _projectId!,
                  item: values['Item'] ?? '',
                  completed: values['Status'] == 'Complete',
                  notes: values['Notes'] ?? '',
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding item: $e')),
                  );
                }
              }
            },
            emptyMessage:
                'No checklist items yet. Add items to track pre-handover verification.',
            cellBuilder: (context, i) {
              final item = items[i];
              return LaunchDataRow(
                onEdit: () {},
                onDelete: () async {
                  final confirmed = await launchConfirmDelete(context,
                      itemName: 'checklist item');
                  if (!confirmed || !mounted) return;
                  try {
                    await OpsService.deleteChecklistItem(
                      projectId: _projectId!,
                      itemId: item.id,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting item: $e')),
                      );
                    }
                  }
                },
                showDivider: i < items.length - 1,
                cells: [
                  LaunchEditableCell(
                    value: item.item,
                    hint: 'Checklist item',
                    bold: true,
                    expand: true,
                    onChanged: (v) {
                      OpsService.updateChecklistItem(
                        projectId: _projectId!,
                        itemId: item.id,
                        item: v,
                      );
                    },
                  ),
                  LaunchEditableCell(
                    value: item.notes ?? '',
                    hint: 'Notes / evidence',
                    expand: true,
                    onChanged: (v) {
                      OpsService.updateChecklistItem(
                        projectId: _projectId!,
                        itemId: item.id,
                        notes: v,
                      );
                    },
                  ),
                  LaunchStatusDropdown(
                    value: item.completed ? 'Complete' : 'Pending',
                    items: const [
                      'Complete',
                      'Pending',
                      'In Progress',
                      'Not Applicable'
                    ],
                    width: 130,
                    onChanged: (v) {
                      if (v == null) return;
                      OpsService.updateChecklistItem(
                        projectId: _projectId!,
                        itemId: item.id,
                        completed: v == 'Complete',
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(String label) {
    final color =
        label == 'Active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _capacityChip(int value) {
    final color = value >= 80
        ? const Color(0xFF10B981)
        : value >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$value%',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final projectId = _projectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No project selected. Please open a project first.')),
      );
      return;
    }
    _showMemberDialog(context, null, projectId);
  }

  void _showEditMemberDialog(BuildContext context, OpsMemberModel member) {
    final projectId = _projectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No project selected. Please open a project first.')),
      );
      return;
    }
    _showMemberDialog(context, member, projectId);
  }

  Future<void> _showMemberDialog(
      BuildContext context, OpsMemberModel? member, String projectId) async {
    final isEdit = member != null;
    final nameController = TextEditingController(text: member?.name ?? '');
    final roleController = TextEditingController(text: member?.role ?? '');
    final responsibilityController =
        TextEditingController(text: member?.responsibility ?? '');
    final statusController =
        TextEditingController(text: member?.status ?? 'Active');
    final readinessController =
        TextEditingController(text: member?.readinessScore.toString() ?? '0');
    final notesController = TextEditingController(text: member?.notes ?? '');

    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => LaunchModalShell(
            icon: isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
            accent: const Color(0xFF10B981),
            title: isEdit ? 'Edit Ops Member' : 'Add Ops Member',
            subtitle: isEdit
                ? 'Update the operations team member profile.'
                : 'Capture a new operations team member with role and readiness.',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LaunchModalTextField(
                  label: 'Name *',
                  controller: nameController,
                  hint: 'Full name of the team member',
                ),
                const SizedBox(height: 12),
                LaunchModalTextField(
                  label: 'Role *',
                  controller: roleController,
                  hint: 'e.g. Operations Lead',
                ),
                const SizedBox(height: 12),
                LaunchModalTextField(
                  label: 'Responsibility *',
                  controller: responsibilityController,
                  hint: 'Primary responsibility on the ops team',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LaunchModalDropdown<String>(
                        label: 'Status *',
                        value: statusController.text,
                        items: const ['Active', 'Pending', 'Inactive'],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => statusController.text = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LaunchModalTextField(
                        label: 'Readiness Score (0-100) *',
                        controller: readinessController,
                        hint: '0–100',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LaunchModalTextField(
                  label: 'Notes',
                  controller: notesController,
                  hint: 'Optional context about this member',
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              LaunchModalCancelButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(ctx),
              ),
              LaunchModalPrimaryButton(
                label: isEdit ? 'Update' : 'Add Member',
                icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      roleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please fill in required fields')),
                    );
                    return;
                  }

                  try {
                    final readiness =
                        int.tryParse(readinessController.text) ?? 0;

                    if (isEdit) {
                      await OpsService.updateMember(
                        projectId: projectId,
                        memberId: member.id,
                        name: nameController.text,
                        role: roleController.text,
                        responsibility: responsibilityController.text,
                        status: statusController.text,
                        readinessScore: readiness,
                        notes: notesController.text.isEmpty
                            ? null
                            : notesController.text,
                      );
                    } else {
                      await OpsService.createMember(
                        projectId: projectId,
                        name: nameController.text,
                        role: roleController.text,
                        responsibility: responsibilityController.text,
                        status: statusController.text,
                        readinessScore: readiness,
                        notes: notesController.text.isEmpty
                            ? null
                            : notesController.text,
                      );
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEdit
                                ? 'Member updated successfully'
                                : 'Member added successfully')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      roleController.dispose();
      responsibilityController.dispose();
      statusController.dispose();
      readinessController.dispose();
      notesController.dispose();
    }
  }

  void _showDeleteMemberDialog(BuildContext context, OpsMemberModel member) {
    final projectId = _projectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No project selected. Please open a project first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LaunchModalShell(
        icon: Icons.delete_outline_rounded,
        accent: const Color(0xFFEF4444),
        title: 'Delete Member',
        subtitle: 'This action cannot be undone.',
        body: Text(
          'Are you sure you want to delete "${member.name}"? '
          'Once removed, the member record cannot be recovered.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
        actions: [
          LaunchModalCancelButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          LaunchModalDangerButton(
            label: 'Delete',
            onPressed: () async {
              try {
                await OpsService.deleteMember(
                    projectId: projectId, memberId: member.id);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Member deleted successfully')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting member: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OpsMemberSeed {
  const _OpsMemberSeed({
    required this.name,
    required this.role,
    required this.responsibility,
    required this.status,
    required this.readinessScore,
    this.notes,
  });

  final String name;
  final String role;
  final String responsibility;
  final String status;
  final int readinessScore;
  final String? notes;
}
