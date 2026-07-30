import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/premium_edit_dialog.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/table_import_helper.dart';
import 'package:ndu_project/models/rate_card.dart';
import 'package:ndu_project/widgets/rate_card_management_dialog.dart';
import 'package:ndu_project/utils/role_descriptions.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/providers/user_role_provider.dart';
import 'package:ndu_project/models/user_role.dart';
import 'package:ndu_project/utils/staffing_reminder_helper.dart';

Future<void> _exportPlanningSubsectionPdf(BuildContext context) async {
  final projectData = ProjectDataHelper.getData(context);
  await PdfExportHelper.exportScreenPdf(
    context: context,
    screenTitle: 'Organization Plan',
    sections: [
      PdfSection.keyValue('Project Info', [
        {
          'Project Name':
              projectData.projectName.isEmpty ? 'N/A' : projectData.projectName
        },
        {
          'Solution Title': projectData.solutionTitle.isEmpty
              ? 'N/A'
              : projectData.solutionTitle
        },
      ]),
      PdfSection.text(
          'Notes',
          projectData.planningNotes[
                  'planning_organization_plan_subsections_notes'] ??
              'No data recorded.'),
    ],
  );
}

class OrganizationRolesResponsibilitiesScreen extends StatefulWidget {
  const OrganizationRolesResponsibilitiesScreen({super.key});

  @override
  State<OrganizationRolesResponsibilitiesScreen> createState() =>
      _OrganizationRolesResponsibilitiesScreenState();
}

/// Alias used by sidebar / router entries that refer to the "Staffing Plan"
/// subsection. The Staffing Plan is rendered as the table view inside
/// [OrganizationRolesResponsibilitiesScreen], so both route keys resolve to
/// the same widget.
class OrganizationStaffingPlanScreen extends OrganizationRolesResponsibilitiesScreen {
  const OrganizationStaffingPlanScreen({super.key});
}

class _OrganizationRolesResponsibilitiesScreenState
    extends State<OrganizationRolesResponsibilitiesScreen> {
  static const List<String> _roleTitleOptions = [
    'Project Manager',
    'Program Manager',
    'Product Owner',
    'Scrum Master',
    'Business Analyst',
    'PMO Lead',
    'Delivery Manager',
    'Operations Manager',
    'Risk Manager',
    'Quality Assurance Lead',
    'Change Manager',
    'Stakeholder Manager',
    'Planning Engineer',
    'Project Coordinator',
    'Portfolio Manager',
  ];
  static const String _customRoleOption = 'Custom';

  /// Role bank: maps role title → (description, workstream).
  /// When a user selects a title from the dropdown, the description is auto-filled.
  static const Map<String, _RoleBankEntry> _roleBank = {
    'Project Manager': _RoleBankEntry(
      description:
          'Overall project leadership, planning, and coordination across all phases.',
      workstream: 'Management',
    ),
    'Program Manager': _RoleBankEntry(
      description:
          'Multi-project program coordination and strategic alignment.',
      workstream: 'Management',
    ),
    'Product Owner': _RoleBankEntry(
      description:
          'Agile product owner — backlog prioritization and stakeholder representation.',
      workstream: 'Management',
    ),
    'Scrum Master': _RoleBankEntry(
      description:
          'Facilitates Agile ceremonies, removes impediments, and coaches the team on Scrum practices.',
      workstream: 'Management',
    ),
    'Business Analyst': _RoleBankEntry(
      description:
          'Elicits, documents, and manages requirements. Bridges business stakeholders and delivery teams.',
      workstream: 'Management',
    ),
    'PMO Lead': _RoleBankEntry(
      description:
          'Project Management Office oversight, governance, and standards.',
      workstream: 'Management',
    ),
    'Delivery Manager': _RoleBankEntry(
      description:
          'Coordinates delivery across teams, manages dependencies, and ensures timely execution.',
      workstream: 'Management',
    ),
    'Operations Manager': _RoleBankEntry(
      description:
          'Manages day-to-day operations, resource allocation, and process optimization.',
      workstream: 'Operations',
    ),
    'Risk Manager': _RoleBankEntry(
      description:
          'Identifies, assesses, and mitigates project risks. Maintains the risk register.',
      workstream: 'Management',
    ),
    'Quality Assurance Lead': _RoleBankEntry(
      description:
          'Owns quality planning, QA/QC processes, and compliance with standards.',
      workstream: 'Quality',
    ),
    'Change Manager': _RoleBankEntry(
      description:
          'Manages organizational change, stakeholder adoption, and transition planning.',
      workstream: 'Management',
    ),
    'Stakeholder Manager': _RoleBankEntry(
      description:
          'Manages stakeholder engagement, communication, and alignment throughout the project.',
      workstream: 'Management',
    ),
    'Planning Engineer': _RoleBankEntry(
      description:
          'Develops and maintains project schedules, WBS, and progress tracking.',
      workstream: 'Engineering',
    ),
    'Project Coordinator': _RoleBankEntry(
      description:
          'Supports project administration, documentation, and meeting coordination.',
      workstream: 'Management',
    ),
    'Portfolio Manager': _RoleBankEntry(
      description:
          'Oversees portfolio of projects, prioritizes investments, and aligns with strategic objectives.',
      workstream: 'Management',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final roles = projectData.projectRoles;

    final totalPersonnel = roles.fold<int>(
        0, (sum, role) => sum + (role.headcount > 0 ? role.headcount : 1));

    final List<_MetricData> metrics = [
      _MetricData(
          'Total Roles', roles.length.toString(), const Color(0xFF3B82F6)),
      _MetricData(
          'Total Personnel',
          totalPersonnel.toString(),
          const Color(0xFF8B5CF6)),
      _MetricData(
          'Disciplines',
          roles.map<String>((r) => r.workstream).toSet().length.toString(),
          const Color(0xFF10B981)),
    ];

    final List<_SectionData> sections =
        roles.asMap().entries.map<_SectionData>((entry) {
      final index = entry.key;
      final role = entry.value;
      return _SectionData(
        title: role.title,
        subtitle: role.workstream,
        bullets: [
          _BulletData(role.description, false),
        ],
        headcount: role.headcount > 0 ? role.headcount : 1,
        onEdit: () => _editRole(context, index, role),
        onDelete: () => _deleteRole(context, index),
      );
    }).toList();

    return _PlanningSubsectionScreen(
      config: _PlanningSubsectionConfig(
        title: 'Roles & Responsibilities',
        subtitle: 'Clarify ownership across workstreams and decision points.',
        noteKey: 'planning_organization_roles_responsibilities',
        checkpoint: 'organization_roles_responsibilities',
        activeItemLabel: 'Organization Plan - Roles & Responsibilities',
        metrics: metrics,
        sections: sections,
        roles: roles,
        showTableView: true,
      ),
      onAdd: () => _addRole(context),
      onAddPredefined: () => _showPredefinedRolesDialog(context),
      onEditRole: (index, role) => _editRole(context, index, role),
      onDeleteRole: (index) => _deleteRole(context, index),
      onUpdateRoleHeadcount: (index, headcount) =>
          _updateRoleHeadcount(context, index, headcount),
    );
  }

  Future<void> _updateRoleHeadcount(
      BuildContext context, int index, int headcount) async {
    final rootContext = context;
    if (headcount < 1) return;
    final updatedRoles = List<RoleDefinition>.from(
        ProjectDataHelper.getProvider(rootContext).projectData.projectRoles);
    if (index < 0 || index >= updatedRoles.length) return;
    updatedRoles[index] =
        updatedRoles[index].copyWith(headcount: headcount);
    await ProjectDataHelper.saveAndNavigate(
      context: rootContext,
      checkpoint: 'organization_roles_responsibilities',
      saveInBackground: true,
      nextScreenBuilder: () =>
          const OrganizationRolesResponsibilitiesScreen(),
      dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
    );
    if (mounted) setState(() {});
  }

  void _showPredefinedRolesDialog(BuildContext context) {
    final rootContext = context;
    // ── Standard roles from the Role-Based Access spreadsheet (June 2022) ──
    // All 48 roles are organized by Framework category (Both / Waterfall / Agile)
    // and mapped to user-friendly workstream labels.
    final List<RoleDefinition> predefined = [
      // ── Management ──
      RoleDefinition(
          title: 'Project Sponsor (Owner)',
          description:
              'Executive sponsor and project owner. Provides strategic direction and funding approval.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Project Manager',
          description:
              'Overall project leadership, planning, and coordination across all phases.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'PMO Manager',
          description:
              'Project Management Office oversight, governance, and standards.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Program Manager',
          description:
              'Multi-project program coordination and strategic alignment.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Product Owner',
          description:
              'Agile product owner — backlog prioritization and stakeholder representation.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Project Controls Manager',
          description: 'Cost, schedule, and performance baseline management.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Interface Manager',
          description:
              'Cross-project interface coordination and conflict resolution.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Business Manager',
          description:
              'Business operations and stakeholder relationship management.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Contracts Manager',
          description: 'Contract administration, negotiation, and compliance.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Procurement Manager',
          description:
              'Procurement strategy, vendor selection, and supply chain.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Release Manager',
          description:
              'Agile release planning, deployment coordination, and go-live governance.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Startup Manager',
          description:
              'Commissioning and startup planning for waterfall projects.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Construction Manager',
          description: 'On-site construction execution and field coordination.',
          workstream: 'Management',
          isPredefined: true),
      // ── Engineering ──
      RoleDefinition(
          title: 'Project Engineer',
          description: 'Technical engineering across all project phases.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Engineering Manager',
          description:
              'Engineering team leadership and technical deliverable ownership.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Technical Manager',
          description:
              'Agile technical team management and architecture oversight.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Change Manager',
          description:
              'Change control process ownership and impact assessment.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Quality Lead',
          description: 'Quality assurance leadership and compliance oversight.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Lead Designer',
          description: 'Agile design leadership and UX direction.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Design Lead',
          description:
              'Waterfall design team leadership and technical drawing ownership.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Lead Developer',
          description: 'Agile development team leadership and code quality.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Schedule Lead',
          description:
              'Schedule planning, critical path analysis, and progress tracking.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Cost Lead',
          description: 'Cost estimation leadership and budget control.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Test Lead',
          description:
              'Testing strategy, test plan ownership, and QA execution.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Change Lead',
          description:
              'Change request analysis and implementation coordination.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Scrum Master',
          description: 'Agile ceremony facilitation and team coaching.',
          workstream: 'Engineering',
          isPredefined: true),
      // ── Specialists ──
      RoleDefinition(
          title: 'Cost Estimator',
          description: 'Detailed cost estimation and quantity takeoff.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Scheduler',
          description: 'Schedule development, updates, and milestone tracking.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Business Analyst',
          description: 'Requirements elicitation, analysis, and documentation.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Technical Architect',
          description: 'System architecture design and technology selection.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Solutions Architect',
          description:
              'End-to-end solution design and integration architecture.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Design Engineer',
          description: 'Engineering design and technical drawing development.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Engineer',
          description: 'General engineering support across disciplines.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Data Specialist',
          description: 'Data modeling, migration, and analytics.',
          workstream: 'Specialist',
          isPredefined: true),
      // ── Development ──
      RoleDefinition(
          title: 'Developer - Backend',
          description: 'Server-side development and API implementation.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Developer - Frontend',
          description: 'Client-side UI development and user experience.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Developer - Fullstack',
          description: 'End-to-end development across frontend and backend.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'DevOps Engineer',
          description:
              'CI/CD pipelines, infrastructure automation, and deployment.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Automation',
          description: 'Test automation and process scripting.',
          workstream: 'Development',
          isPredefined: true),
      // ── Design ──
      RoleDefinition(
          title: 'Designer - UX',
          description:
              'User experience research, wireframing, and prototyping.',
          workstream: 'Design',
          isPredefined: true),
      RoleDefinition(
          title: 'Designer - UI',
          description: 'Visual design, component styling, and design system.',
          workstream: 'Design',
          isPredefined: true),
      // ── QA ──
      RoleDefinition(
          title: 'Tester',
          description: 'Quality assurance and testing of deliverables.',
          workstream: 'QA',
          isPredefined: true),
      RoleDefinition(
          title: 'Quality Control',
          description:
              'Quality inspection, defect tracking, and compliance verification.',
          workstream: 'QA',
          isPredefined: true),
      // ── Operations ──
      RoleDefinition(
          title: 'Procurement',
          description: 'Purchase order processing and vendor coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Interface',
          description: 'Interface management and cross-team coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Operations Liason',
          description:
              'Operational handover and production support coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Hypercare',
          description: 'Post-go-live hypercare support and issue resolution.',
          workstream: 'Operations',
          isPredefined: true),
      // ── Custom ──
      RoleDefinition(
          title: 'Create Role',
          description: 'Define a custom role not listed above.',
          workstream: 'Custom',
          isPredefined: true),
    ];

    final currentRoles =
        ProjectDataHelper.getProvider(context).projectData.projectRoles;
    final selectedIndices = <int>{};
    final headcounts = <int, int>{};

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Standard Roles'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tick the roles you want to add, then set the number of personnel for each in one pass.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: predefined.length,
                    itemBuilder: (context, index) {
                      final role = predefined[index];
                      final alreadyAdded =
                          currentRoles.any((r) => r.title == role.title);
                      final isSelected =
                          selectedIndices.contains(index) || alreadyAdded;
                      final headcount = headcounts[index] ?? 1;
                      return _PredefinedRoleRow(
                        title: role.title,
                        workstream: role.workstream,
                        isSelected: isSelected,
                        enabled: !alreadyAdded,
                        headcount: headcount,
                        onToggle: alreadyAdded
                            ? null
                            : (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedIndices.add(index);
                                    headcounts[index] = 1;
                                  } else {
                                    selectedIndices.remove(index);
                                    headcounts.remove(index);
                                  }
                                });
                              },
                        onHeadcountChanged: alreadyAdded || !isSelected
                            ? null
                            : (value) {
                                setDialogState(() {
                                  headcounts[index] = value;
                                });
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedIndices.isEmpty
                  ? null
                  : () async {
                      final newRoles = selectedIndices.map((i) {
                        final base = predefined[i];
                        final hc = headcounts[i] ?? 1;
                        return base.copyWith(
                            headcount: hc < 1 ? 1 : hc, isPredefined: true);
                      }).toList();
                      Navigator.pop(dialogContext);
                      await ProjectDataHelper.saveAndNavigate(
                        context: rootContext,
                        checkpoint: 'organization_roles_responsibilities',
                        saveInBackground: true,
                        nextScreenBuilder: () =>
                            const OrganizationRolesResponsibilitiesScreen(),
                        dataUpdater: (d) => d.copyWith(
                            projectRoles: [...d.projectRoles, ...newRoles]),
                      );
                      if (mounted) setState(() {});
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black),
              child: const Text('Add Selected'),
            ),
          ],
        ),
      ),
    );
  }

  void _editRole(BuildContext context, int index, RoleDefinition role) {
    final rootContext = context;
    String selectedTitle =
        _roleTitleOptions.contains(role.title) ? role.title : _customRoleOption;
    final customTitleController = TextEditingController(
      text: selectedTitle == _customRoleOption ? role.title : '',
    );
    final workstreamController = TextEditingController(text: role.workstream);
    final descController = TextEditingController(text: role.description);
    int headcount = role.headcount > 0 ? role.headcount : 1;

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Edit Role',
          icon: Icons.badge_outlined,
          onSave: () async {
            final updatedRoles = List<RoleDefinition>.from(
                ProjectDataHelper.getProvider(rootContext)
                    .projectData
                    .projectRoles);
            final titleValue = selectedTitle == _customRoleOption
                ? customTitleController.text.trim()
                : selectedTitle;
            updatedRoles[index] = updatedRoles[index].copyWith(
              title: titleValue,
              workstream: workstreamController.text.trim(),
              description: descController.text.trim(),
              headcount: headcount,
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_roles_responsibilities',
              saveInBackground: true,
              nextScreenBuilder: () =>
                  const OrganizationRolesResponsibilitiesScreen(),
              dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Title'),
            DropdownButtonFormField<String>(
              initialValue: selectedTitle,
              items: [
                ..._roleTitleOptions,
                _customRoleOption,
              ]
                  .map((title) =>
                      DropdownMenuItem(value: title, child: Text(title)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  selectedTitle = value;
                  // Auto-fill description and workstream from role bank
                  final entry = _roleBank[value];
                  if (entry != null) {
                    descController.text = entry.description;
                    workstreamController.text = entry.workstream;
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Select a role title',
                border: OutlineInputBorder(),
              ),
            ),
            if (selectedTitle == _customRoleOption) ...[
              const SizedBox(height: 12),
              PremiumEditDialog.textField(
                controller: customTitleController,
                hint: 'Enter custom role title',
              ),
            ],
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Number of personnel'),
            _DialogHeadcountStepper(
              headcount: headcount,
              onChanged: (value) =>
                  setDialogState(() => headcount = value),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Description'),
            PremiumEditDialog.textField(
                controller: descController,
                hint: 'Role responsibilities...',
                maxLines: 4),
          ],
        ),
      ),
    );
  }

  void _addRole(BuildContext context) {
    final rootContext = context;
    String selectedTitle = _roleTitleOptions.first;
    final customTitleController = TextEditingController();
    final workstreamController = TextEditingController();
    final descController = TextEditingController();
    int headcount = 1;

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Add Role',
          icon: Icons.badge_outlined,
          onSave: () async {
            final titleValue = selectedTitle == _customRoleOption
                ? customTitleController.text.trim()
                : selectedTitle;
            final workstream = workstreamController.text.trim();
            final description = descController.text.trim();
            final newRole = RoleDefinition(
              title: titleValue.isNotEmpty ? titleValue : 'New Role',
              workstream: workstream.isNotEmpty ? workstream : 'Default',
              description:
                  description.isNotEmpty ? description : 'Role description',
              headcount: headcount,
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_roles_responsibilities',
              saveInBackground: true,
              nextScreenBuilder: () =>
                  const OrganizationRolesResponsibilitiesScreen(),
              dataUpdater: (d) =>
                  d.copyWith(projectRoles: [...d.projectRoles, newRole]),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Title'),
            DropdownButtonFormField<String>(
              initialValue: selectedTitle,
              items: [
                ..._roleTitleOptions,
                _customRoleOption,
              ]
                  .map((title) =>
                      DropdownMenuItem(value: title, child: Text(title)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  selectedTitle = value;
                  // Auto-fill description and workstream from role bank
                  final entry = _roleBank[value];
                  if (entry != null) {
                    descController.text = entry.description;
                    workstreamController.text = entry.workstream;
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Select a role title',
                border: OutlineInputBorder(),
              ),
            ),
            if (selectedTitle == _customRoleOption) ...[
              const SizedBox(height: 12),
              PremiumEditDialog.textField(
                controller: customTitleController,
                hint: 'Enter custom role title',
              ),
            ],
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Number of personnel'),
            _DialogHeadcountStepper(
              headcount: headcount,
              onChanged: (value) =>
                  setDialogState(() => headcount = value),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Description'),
            PremiumEditDialog.textField(
                controller: descController,
                hint: 'Role responsibilities...',
                maxLines: 4),
          ],
        ),
      ),
    );
  }

  void _deleteRole(BuildContext context, int index) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Role'),
        content: const Text('Are you sure you want to delete this role?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final updatedRoles = List<RoleDefinition>.from(
                  ProjectDataHelper.getProvider(rootContext)
                      .projectData
                      .projectRoles);
              updatedRoles.removeAt(index);
              Navigator.pop(dialogContext);
              await ProjectDataHelper.saveAndNavigate(
                context: rootContext,
                checkpoint: 'organization_roles_responsibilities',
                saveInBackground: true,
                nextScreenBuilder: () =>
                    const OrganizationRolesResponsibilitiesScreen(),
                dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
              );
              if (mounted) setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class OrganizationRaciMatrixScreen extends StatefulWidget {
  const OrganizationRaciMatrixScreen({super.key});

  @override
  State<OrganizationRaciMatrixScreen> createState() =>
      _OrganizationRaciMatrixScreenState();
}

class _OrganizationRaciMatrixScreenState
    extends State<OrganizationRaciMatrixScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                activeItemLabel: 'Organization Plan - RACI Matrix',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - RACI Matrix',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'RACI Matrix',
                          onExportPdf: _exportRaciPdf,
                        ),
                        const SizedBox(height: 16),
                        _TopHeader(
                          title: 'RACI Matrix',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                            context,
                            'organization_raci_matrix',
                          ),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                            context,
                            'organization_raci_matrix',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Auto-customized to your project scope. The matrix '
                          'pulls every sidebar deliverable (Planning → '
                          'Launch) and every position identified on the '
                          'Roles & Responsibilities page, then takes a '
                          'first stab at distributing RACI designations '
                          'based on the Staffing Plan.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        const PlanningAiNotesCard(
                          title: 'Notes',
                          sectionLabel: 'RACI Matrix',
                          noteKey: 'planning_organization_raci_matrix',
                          checkpoint: 'organization_raci_matrix',
                          description:
                              'Capture tailoring decisions for responsibility ownership and governance.',
                        ),
                        const SizedBox(height: 24),
                        const RaciDeliverableMatrix(),
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                            'organization_raci_matrix',
                          ),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                            'organization_raci_matrix',
                          ),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                            context,
                            'organization_raci_matrix',
                          ),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                            context,
                            'organization_raci_matrix',
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(positioned: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRaciPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final rows = projectData.raciDeliverableRows;
    // Build dedup'd column list (Staffing Plan first, then any extra
    // roles from Roles & Responsibilities).
    final dedup = <String>[];
    for (final c in [
      ...projectData.staffingRequirements.map((s) => s.title.trim()),
      ...projectData.projectRoles.map((r) => r.title.trim()),
    ]) {
      if (c.isEmpty) continue;
      final key = c.toLowerCase();
      if (dedup.any((d) => d.toLowerCase() == key)) continue;
      dedup.add(c);
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'RACI Deliverable Matrix',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Project Name': projectData.projectName.isEmpty
                ? 'N/A'
                : projectData.projectName
          },
          {
            'Solution Title': projectData.solutionTitle.isEmpty
                ? 'N/A'
                : projectData.solutionTitle
          },
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['organization_staffing_plan'] ??
                'No data recorded.'),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didAutoPopulate) return;
      final provider = ProjectDataHelper.getProvider(context);
      final roles = provider.projectData.projectRoles;
      final requirements = provider.projectData.staffingRequirements;
      if (roles.isNotEmpty) {
        final roleTitles =
            roles.map((r) => r.title.trim()).where((t) => t.isNotEmpty).toSet();

        final filteredRequirements = requirements
            .where((r) => roleTitles.contains(r.title.trim()))
            .toList();

        final existingTitles = filteredRequirements
            .map((r) => r.title.trim())
            .where((t) => t.isNotEmpty)
            .toSet();

        final newStaff = roles
            .where((role) => !existingTitles.contains(role.title.trim()))
            .map((role) => StaffingRequirement(
                  title: role.title,
                  startDate: 'TBD',
                  endDate: 'TBD',
                  employeeType: role.workstream == 'Engineering' ||
                          role.workstream == 'Development'
                      ? 'Contractor'
                      : 'Employee',
                ))
            .toList();

        final updated = [...filteredRequirements, ...newStaff];
        if (updated.length != requirements.length || newStaff.isNotEmpty) {
          await ProjectDataHelper.updateAndSave(
            context: context,
            checkpoint: 'organization_staffing_plan',
            dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
            showSnackbar: false,
          );
        }
        if (mounted) {
          setState(() {
            _didAutoPopulate = true;
          });
        }
      } else {
        _didAutoPopulate = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final requirements = projectData.staffingRequirements;
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                activeItemLabel: 'Organization Plan - Staffing Plan',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - Staffing Plan',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Text(
                          'Reflect the planned allocation of project personnel by role and time to support resource planning, workload management, and successful project delivery.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 20),
                        // Metrics row
                        Row(
                          children: [
                            _MetricCard(
                                label: 'Total Personnel',
                                value: requirements
                                    .fold<int>(0, (sum, r) => sum + r.headcount)
                                    .toString(),
                                accent: const Color(0xFFF59E0B)),
                            const SizedBox(width: 16),
                            _MetricCard(
                                label: 'Positions',
                                value: requirements.length.toString(),
                                accent: const Color(0xFF8B5CF6)),
                          ],
                        ),
                        
                        // Staffing Reminders Alert Banner
                        FutureBuilder<List<StaffingReminder>>(
                          future: _loadReminders(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            final reminders = snapshot.data!;
                            final criticalCount = reminders
                                .where((r) => r.priority == Priority.critical)
                                .length;
                            final highCount = reminders
                                .where((r) => r.priority == Priority.high)
                                .length;
                            
                            if (criticalCount == 0 && highCount == 0) {
                              return const SizedBox.shrink();
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: GestureDetector(
                                onTap: () => _showRemindersDialog(reminders),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: criticalCount > 0
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: criticalCount > 0
                                          ? const Color(0xFECACA)
                                          : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        criticalCount > 0
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline,
                                        color: criticalCount > 0
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFFD97706),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$criticalCount critical, $highCount high-priority staffing alert${(criticalCount + highCount) != 1 ? 's' : ''} require attention',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: criticalCount > 0
                                                ? const Color(0xFF991B1B)
                                                : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),

                        // Import & Template buttons
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _showImportDialog,
                              icon: const Icon(Icons.upload_file_outlined,
                                  size: 16),
                              label: const Text('Import'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4338CA),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _openPersonnelRates,
                              icon: const Icon(Icons.attach_money, size: 16),
                              label: const Text('Rates'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF059669),
                                side:
                                    const BorderSide(color: Color(0xFF059669)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _downloadTemplate,
                              icon:
                                  const Icon(Icons.download_outlined, size: 16),
                              label: const Text('Download Template'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                side:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // AI Suggest Roles button
                            OutlinedButton.icon(
                              onPressed: _aiSuggestRoles,
                              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                              label: const Text('AI Suggest Roles'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF8B5CF6),
                                side: const BorderSide(color: Color(0xFF8B5CF6)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Tab Bar for Personnel | Timeline | Costs
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            labelColor: const Color(0xFF111827),
                            unselectedLabelColor: const Color(0xFF6B7280),
                            indicatorColor: const Color(0xFFFFC107),
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            tabs: [
                              const Tab(text: 'Personnel Table'),
                              const Tab(text: 'Timeline'),
                              Tab(child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Costs '),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: const Text('RESTRICTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                                  ),
                                ],
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Views
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.52,
                          child: TabBarView(
                            children: [
                              // TAB 1: Personnel Table
                              _buildPersonnelTabContent(context, requirements),
                              
                              // TAB 2: Timeline View
                              _buildTimelineTabContent(requirements),
                              
                              // TAB 3: Cost View (Restricted)
                              _buildCostTabContent(requirements),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'organization_staffing_plan'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'organization_staffing_plan'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'organization_staffing_plan'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'organization_staffing_plan'),
                          onSkip: () => PlanningPhaseNavigation.goToSkip(
                              context, 'organization_staffing_plan'),
                          pageTitle: 'Organization Staffing Plan',
                        ),
                        const SizedBox(height: 40),
                      ],
                      ),
                    ),
                  ),
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

  void _editStaffing(BuildContext context, int index, StaffingRequirement req) {
    final rootContext = context;
    final titleController = TextEditingController(text: req.title);
    final personController = TextEditingController(text: req.personName);
    final locationController = TextEditingController(text: req.location);
    final statusController = TextEditingController(text: req.status);
    final startController = TextEditingController(text: req.startDate);
    final endController = TextEditingController(text: req.endDate);
    final headcountController =
        TextEditingController(text: req.headcount.toString());
    final monthlyCostController = TextEditingController(
        text: req.monthlyCost == 0 ? '' : req.monthlyCost.toStringAsFixed(2));
    final plannedMonthsController = TextEditingController(
        text:
            req.plannedMonths == 0 ? '' : req.plannedMonths.toStringAsFixed(1));
    final notesController = TextEditingController(text: req.notes);
    String empType = req.employmentType;
    String employeeType = req.employeeType;
    bool nduAccess = req.nduAccess;
    
    // Autocomplete state for name field
    List<UserModel> _nameSuggestions = [];
    bool _isSearchingName = false;
    Timer? _nameSearchTimer;
    final _nameFocusNode = FocusNode();

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Edit Staffing Requirement',
          icon: Icons.person_add_alt_1_outlined,
          onSave: () async {
            final updated = List<StaffingRequirement>.from(
                ProjectDataHelper.getProvider(rootContext)
                    .projectData
                    .staffingRequirements);
            updated[index] = req.copyWith(
              title: titleController.text.trim(),
              headcount: int.tryParse(headcountController.text.trim()) ?? 1,
              monthlyCost:
                  double.tryParse(monthlyCostController.text.trim()) ?? 0,
              plannedMonths:
                  double.tryParse(plannedMonthsController.text.trim()) ?? 0,
              personName: personController.text.trim(),
              location: locationController.text.trim(),
              status: statusController.text.trim(),
              startDate: startController.text.trim(),
              endDate: endController.text.trim(),
              employmentType: empType,
              employeeType: employeeType,
              nduAccess: nduAccess,
              notes: notesController.text.trim(),
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_staffing_plan',
              saveInBackground: true,
              nextScreenBuilder: () => const OrganizationStaffingPlanScreen(),
              dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Job Title'),
            PremiumEditDialog.textField(
                controller: titleController, hint: 'e.g. Senior Developer'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Headcount'),
                      PremiumEditDialog.textField(
                          controller: headcountController, hint: '1'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Planned Months'),
                      PremiumEditDialog.textField(
                          controller: plannedMonthsController, hint: '6'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Monthly Rate'),
            PremiumEditDialog.textField(
                controller: monthlyCostController, hint: '2500'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Name'),
            _NameAutocompleteField(
              controller: personController,
              focusNode: _nameFocusNode,
              suggestions: _nameSuggestions,
              isSearching: _isSearchingName,
              onTextChanged: (text) {
                _nameSearchTimer?.cancel();
                if (text.length < 2) {
                  setDialogState(() {
                    _nameSuggestions = [];
                    _isSearchingName = false;
                  });
                  return;
                }
                setDialogState(() => _isSearchingName = true);
                _nameSearchTimer = Timer(const Duration(milliseconds: 300), () async {
                  try {
                    final users = await UserService.searchUsers(text);
                    if (context.mounted) {
                      setDialogState(() {
                        _nameSuggestions = users;
                        _isSearchingName = false;
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setDialogState(() => _isSearchingName = false);
                    }
                  }
                });
              },
              onSuggestionSelected: (user) {
                personController.text = user.displayName;
                setDialogState(() => _nameSuggestions = []);
                _nameFocusNode.unfocus();
              },
              onClearSuggestions: () {
                setDialogState(() => _nameSuggestions = []);
              },
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Location'),
            PremiumEditDialog.textField(
                controller: locationController,
                hint: 'e.g. Remote, Office, Site'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('NDU Platform Access'),
            StatefulBuilder(
              builder: (context, setDialogState) => SwitchListTile(
                title: const Text('Grant access to NDU Project Delivery Platform'),
                subtitle: Text(nduAccess ? 'User will have platform access' : 'No platform access'),
                value: nduAccess,
                onChanged: (v) => setDialogState(() => nduAccess = v),
                activeColor: Color(0xFF059669),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Employment Type'),
                      DropdownButtonFormField<String>(
                        value: empType,
                        items: ['Full Time', 'Part Time']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => empType = v!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Category'),
                      DropdownButtonFormField<String>(
                        value: employeeType,
                        items: ['Employee', 'Contractor']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => employeeType = v!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Status'),
                      PremiumEditDialog.textField(
                          controller: statusController, hint: 'e.g. Hired'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Mobilization Date'),
                      PremiumEditDialog.textField(
                          controller: startController, hint: 'Q1 2024'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Release Date'),
                      PremiumEditDialog.textField(
                          controller: endController, hint: 'Q4 2024'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // AI Suggest Dates button
            Row(
              children: [
                const Expanded(child: SizedBox()), // spacer
                TextButton.icon(
                  onPressed: () => _aiSuggestDates(req, startController, endController, setDialogState),
                  icon: Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B5CF6)),
                  label: Text('Suggest Dates', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Cost / Sourcing Notes'),
            PremiumEditDialog.textField(
                controller: notesController,
                hint: 'Assumptions, rate basis, sourcing notes'),
          ],
        ),
      ),
    );
  }

  void _deleteStaffing(BuildContext context, int index) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Position'),
        content: const Text(
            'Are you sure you want to delete this staffing position?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final updated = List<StaffingRequirement>.from(
                  ProjectDataHelper.getProvider(rootContext)
                      .projectData
                      .staffingRequirements);
              updated.removeAt(index);
              Navigator.pop(dialogContext);
              await ProjectDataHelper.saveAndNavigate(
                context: rootContext,
                checkpoint: 'organization_staffing_plan',
                saveInBackground: true,
                nextScreenBuilder: () => const OrganizationStaffingPlanScreen(),
                dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
              );
              if (mounted) setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() async {
    final headers = [
      'Position',
      'Headcount',
      'Monthly Rate',
      'Planned Months',
      'Start Date',
      'End Date',
      'Status',
      'Person',
      'Employment',
      'Location',
      'Category',
      'Notes'
    ];
    final sampleRows = [
      [
        'Project Manager',
        '1',
        '4000',
        '6',
        'Jan 2024',
        'Jun 2024',
        'Active',
        '',
        'FT',
        'Office',
        'Employee',
        ''
      ],
      [
        'Technical Lead',
        '1',
        '5000',
        '8',
        'Jan 2024',
        'Aug 2024',
        'Active',
        '',
        'FT',
        'Office',
        'Employee',
        ''
      ],
      [
        'Business Analyst',
        '1',
        '3500',
        '4',
        'Feb 2024',
        'May 2024',
        'Not Started',
        '',
        'PT',
        'Remote',
        'Contractor',
        ''
      ],
    ];

    final rows = await TableImportHelper.showImportDialog(
      context,
      tableTitle: 'Staffing Plan',
      headers: headers,
      sampleRows: sampleRows,
    );

    if (rows == null || rows.isEmpty || !mounted) return;

    final newRequirements = <StaffingRequirement>[];
    for (final parts in rows) {
      newRequirements.add(StaffingRequirement(
        title: parts.isNotEmpty ? parts[0] : '',
        headcount: parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1,
        monthlyCost: parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0,
        plannedMonths: parts.length > 3 ? double.tryParse(parts[3]) ?? 0 : 0,
        startDate: parts.length > 4 ? parts[4] : '',
        endDate: parts.length > 5 ? parts[5] : '',
        status: parts.length > 6 ? parts[6] : 'Not Started',
        personName: parts.length > 7 ? parts[7] : '',
        employmentType: parts.length > 8 ? parts[8] : 'FT',
        location: parts.length > 9 ? parts[9] : '',
        employeeType: parts.length > 10 ? parts[10] : 'Employee',
        notes: parts.length > 11 ? parts[11] : '',
      ));
    }

    if (newRequirements.isNotEmpty) {
      final updated = List<StaffingRequirement>.from(
        ProjectDataHelper.getProvider(context).projectData.staffingRequirements,
      )..addAll(newRequirements);
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'organization_staffing_plan',
        dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newRequirements.length} positions'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _downloadTemplate() {
    TableImportHelper.downloadTemplate(
      filename: 'staffing_plan_template.csv',
      headers: [
        'Position',
        'Headcount',
        'Monthly Rate',
        'Planned Months',
        'Start Date',
        'End Date',
        'Status',
        'Person',
        'Employment',
        'Location',
        'Category',
        'Notes'
      ],
      sampleRows: [
        [
          'Project Manager',
          '1',
          '4000',
          '6',
          'Jan 2024',
          'Jun 2024',
          'Active',
          '',
          'FT',
          'Office',
          'Employee',
          ''
        ],
        [
          'Technical Lead',
          '1',
          '5000',
          '8',
          'Jan 2024',
          'Aug 2024',
          'Active',
          '',
          'FT',
          'Office',
          'Employee',
          ''
        ],
        [
          'Business Analyst',
          '1',
          '3500',
          '4',
          'Feb 2024',
          'May 2024',
          'Not Started',
          '',
          'PT',
          'Remote',
          'Contractor',
          ''
        ],
      ],
    );
  }

  // ==================== AI SUGGESTIONS METHODS ====================
  
  /// AI Suggest Roles - calls OpenAI to get role suggestions based on project context
  Future<void> _aiSuggestRoles() async {
    final projectData = ProjectDataHelper.getData(context);
    
    // Build context string for AI
    final contextStr = '''
Project: ${projectData.projectName}
Solution: ${projectData.solutionTitle}
Type: ${projectData.projectType ?? 'Regular'}
Current Roles: ${projectData.staffingRequirements.map((r) => r.title).join(', ')}
''';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Call OpenAI service for role suggestions
      final suggestions = await OpenAIServiceSecure.generateStaffingRoleSuggestions(
        context: contextStr,
        maxSuggestions: 10,
      );
      
      Navigator.pop(context); // Remove loading
      
      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No role suggestions available'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      
      // Show suggestions dialog for user to accept/reject
      await _showRoleSuggestionsDialog(suggestions);
      
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI suggestion failed: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
  
  /// Show dialog with AI-suggested roles for user to select which to add
  Future<void> _showRoleSuggestionsDialog(List<String> suggestions) async {
    final selected = <String>{};
    
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 24),
              SizedBox(width: 8),
              Text('AI Role Suggestions'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select roles to add to your staffing plan:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final role = suggestions[index];
                      final isSelected = selected.contains(role);
                      return CheckboxListTile(
                        title: Text(role, style: TextStyle(fontSize: 14)),
                        value: isSelected,
                        activeColor: Color(0xFF8B5CF6),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(role);
                            } else {
                              selected.remove(role);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected.toList()),
              style: FilledButton.styleFrom(backgroundColor: Color(0xFF8B5CF6)),
              child: Text('Add ${selected.length} Roles'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty && mounted) {
      final newRoles = result.map((title) => StaffingRequirement(
        title: title,
        startDate: 'TBD',
        endDate: 'TBD',
        employeeType: 'Employee',
      )).toList();
      
      final updated = List<StaffingRequirement>.from(
        ProjectDataHelper.getProvider(context).projectData.staffingRequirements
      )..addAll(newRoles);
      
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'organization_staffing_plan',
        dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
      );
      
      if (mounted) setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${result.length} role(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// AI Suggest Dates - suggests start/end dates based on project context and role type
  void _aiSuggestDates(
    StaffingRequirement req,
    TextEditingController startController,
    TextEditingController endController,
    StateSetter setDialogState,
  ) {
    final projectData = ProjectDataHelper.getData(context);
    final currentReqs = projectData.staffingRequirements;
    
    // Simple date suggestion logic based on role type
    String suggestedStart = 'Q1 2025';
    String suggestedEnd = 'Q4 2025';
    
    // Adjust based on role title patterns
    final titleLower = req.title.toLowerCase();
    if (titleLower.contains('manager') || titleLower.contains('lead')) {
      suggestedStart = 'Q1 2025'; // PM/Leads start early
      suggestedEnd = 'Q4 2025'; // Stay through project
    } else if (titleLower.contains('developer') || titleLower.contains('engineer')) {
      suggestedStart = 'Q1 2025';
      suggestedEnd = 'Q3 2025'; // Core phase
    } else if (titleLower.contains('qa') || titleLower.contains('test')) {
      suggestedStart = 'Q2 2025'; // Start later
      suggestedEnd = 'Q4 2025';
    } else if (titleLower.contains('analyst')) {
      suggestedStart = 'Q1 2025';
      suggestedEnd = 'Q2 2025'; // Early phase
    } else if (titleLower.contains('design') || titleLower.contains('ux')) {
      suggestedStart = 'Q1 2025';
      suggestedEnd = 'Q2 2025';
    }
    
    // Look at existing dates for reference
    if (currentReqs.isNotEmpty) {
      final existingStarts = currentReqs
          .where((r) => r.startDate != 'TBD' && r.startDate.isNotEmpty)
          .map((r) => r.startDate)
          .toList();
      if (existingStarts.isNotEmpty) {
        // Use earliest existing start as reference
        suggestedStart = existingStarts.first;
      }
    }
    
    setDialogState(() {
      startController.text = suggestedStart;
      endController.text = suggestedEnd;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suggested dates: $suggestedStart → $suggestedEnd'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ==================== STAFFING REMINDERS ====================

  /// Load reminders from staffing requirements
  Future<List<StaffingReminder>> _loadReminders() async {
    final projectData = ProjectDataHelper.getData(context);
    return StaffingReminderHelper.generateReminders(projectData.staffingRequirements);
  }

  /// Show reminders dialog with all active staffing alerts
  void _showRemindersDialog(List<StaffingReminder> reminders) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Staffing Plan Reminders'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${reminders.length} item${reminders.length != 1 ? 's' : ''} need attention',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReminderCard(reminder: reminder),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addRemindersToCalendar(reminders);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            child: const Text('Add All to Calendar'),
          ),
        ],
      ),
    );
  }

  /// Add reminders to team calendar as activities
  void _addRemindersToCalendar(List<StaffingReminder> reminders) async {
    final events = StaffingReminderHelper.toCalendarEvents(reminders);
    
    // Get current activities and add new ones
    final provider = ProjectDataHelper.getProvider(context);
    final currentActivities = List<TeamActivity>.from(
      provider.projectData.teamActivities ?? [],
    );
    currentActivities.addAll(events);
    
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'staffing_reminders',
      dataUpdater: (d) => d.copyWith(teamActivities: currentActivities),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${events.length} reminder${events.length != 1 ? 's' : ''} added to team calendar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==================== TAB CONTENT BUILDERS ====================
  
  /// Build the Personnel Table tab content
  Widget _buildPersonnelTabContent(BuildContext context, List<StaffingRequirement> requirements) {
    if (requirements.isEmpty) {
      return const _SectionEmptyState(
        title: 'No staffing positions yet',
        message: 'Sync from defined roles or use "AI Suggest Roles" to populate this view.',
        icon: Icons.group_outlined,
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _StaffingPlanTable(
          requirements: requirements,
          onEdit: (index, req) => _editStaffing(context, index, req),
          onDelete: (index) => _deleteStaffing(context, index),
        ),
      ),
    );
  }
  
  /// Build the Timeline tab content (Gantt chart view)
  Widget _buildTimelineTabContent(List<StaffingRequirement> requirements) {
    return _StaffingGanttChart(requirements: requirements);
  }
  
  /// Build the Cost tab content (with restricted access)
  Widget _buildCostTabContent(List<StaffingRequirement> requirements) {
    // Check user authorization - editors and above can view costs
    bool isAuthorized = true; // Default to authorized for now
    
    try {
      final userRole = UserRoleProvider.of(context)?.siteRole ?? SiteRole.user;
      isAuthorized = userRole.level >= SiteRole.editor.level;
    } catch (e) {
      // If provider not found, default to restricted view
      isAuthorized = false;
    }
    
    if (!isAuthorized) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 32, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 20),
              Text(
                'RESTRICTED CONTENT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cost information requires Editor-level access or higher.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your project administrator for access.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFFD97706)),
              ),
            ],
          ),
        ),
      );
    }
    
    // Authorized cost view
    if (requirements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money_outlined, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No cost data available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
            SizedBox(height: 8),
            Text(
              'Add staffing positions with rates to see cost breakdown',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    
    // Calculate totals
    double grandTotal = 0;
    for (final req in requirements) {
      grandTotal += req.estimatedTotal;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text(
                  'Cost Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('POSITION', style: _costHeaderStyle)),
                Expanded(flex: 2, child: Text('MONTHLY RATE', style: _costHeaderStyle, textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('MONTHS', style: _costHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('TOTAL', style: _costHeaderStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Table rows
          ...requirements.asMap().entries.map((entry) {
            final idx = entry.key;
            final req = entry.value;
            final total = req.estimatedTotal;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(req.title.isEmpty ? 'Untitled' : req.title, style: _costCellStyle, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text('\$${req.monthlyCost.toStringAsFixed(0)}', style: _costCellStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(req.plannedMonths.toStringAsFixed(1), style: _costCellStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('\$${total.toStringAsFixed(0)}', style: _costCellStyle.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
          Divider(height: 1),
          // Grand total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              border: Border(top: BorderSide(color: Color(0xFF059669), width: 2)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF065F46)))),
                Expanded(flex: 2, child: SizedBox()),
                Expanded(flex: 1, child: SizedBox()),
                Expanded(flex: 2, child: Text('\$${grandTotal.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF065F46)), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Cost table header style
  static TextStyle get _costHeaderStyle => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: Color(0xFF6B7280),
  );
  
  /// Cost table cell style
  static TextStyle get _costCellStyle => TextStyle(
    fontSize: 13,
    color: Color(0xFF374151),
  );
}

/// Timeline item card widget for Gantt-style display
class _TimelineItemCard extends StatelessWidget {
  const _TimelineItemCard({required this.requirement, required this.index});
  
  final StaffingRequirement requirement;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Determine bar width based on duration (simplified)
    double barWidth = 100;
    if (requirement.plannedMonths > 0) {
      barWidth = (requirement.plannedMonths * 30).clamp(40, 200).toDouble();
    }
    
    // Determine color based on status
    Color barColor = Color(0xFF8B5CF6);
    if (requirement.status == 'Active') {
      barColor = Color(0xFF10B981);
    } else if (requirement.status == 'Hired' || requirement.status == 'Confirmed') {
      barColor = Color(0xFF059669);
    } else if (requirement.status == 'Not Started') {
      barColor = Color(0xFF9CA3AF);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: barColor)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  requirement.title.isEmpty ? 'Untitled Position' : requirement.title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (requirement.personName.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(requirement.personName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E40AF))),
                ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
              SizedBox(width: 4),
              Text(
                '${requirement.startDate} → ${requirement.endDate}',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              SizedBox(width: 16),
              Icon(Icons.schedule_outlined, size: 14, color: Color(0xFF6B7280)),
              SizedBox(width: 4),
              Text(
                '${requirement.plannedMonths.toStringAsFixed(1)} months',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Duration bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              width: barWidth,
              color: barColor.withOpacity(0.3),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gantt-style chart for visualizing staffing timeline
class _StaffingGanttChart extends StatelessWidget {
  const _StaffingGanttChart({required this.requirements});

  final List<StaffingRequirement> requirements;

  @override
  Widget build(BuildContext context) {
    if (requirements.isEmpty) {
      return const _SectionEmptyState(
        title: 'No timeline data',
        message: 'Add positions with dates to see the Gantt chart.',
        icon: Icons.bar_chart_outlined,
      );
    }

    // Calculate date range from all requirements
    final DateTime now = DateTime.now();
    DateTime minDate = now;
    DateTime maxDate = now.add(const Duration(days: 365));

    // Parse dates and find range
    for (final req in requirements) {
      try {
        if (req.startDate.isNotEmpty) {
          final start = DateFormat('yyyy-MM-dd').parse(req.startDate);
          if (start.isBefore(minDate)) minDate = start;
        }
        if (req.endDate.isNotEmpty) {
          final end = DateFormat('yyyy-MM-dd').parse(req.endDate);
          if (end.isAfter(maxDate)) maxDate = end;
        }
      } catch (e) {
        /* skip invalid dates */
      }
    }

    // Ensure at least 6 month window
    if (_daysBetween(minDate, maxDate) < 180) {
      maxDate = minDate.add(const Duration(days: 180));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and legend
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.timeline, size: 20, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text(
                  'Project Timeline Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                Spacer(),
                _buildLegend(),
              ],
            ),
          ),
          Divider(height: 1),
          // Header row with month labels
          _buildGanttHeader(minDate, maxDate),
          Divider(height: 1),
          // Expanded scrollable area for bars
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildGanttBody(minDate, maxDate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the status legend
  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendItem(color: Color(0xFF10B981), label: 'Active'),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFF3B82F6), label: 'Hired'),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFFF59E0B), label: 'Released'),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFFD1D5DB), label: 'Open'),
      ],
    );
  }

  Widget _buildGanttHeader(DateTime minDate, DateTime maxDate) {
    final monthWidth = 100.0; // pixels per month

    return Container(
      height: 40,
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          // Position label column (fixed width)
          SizedBox(
            width: 160,
            child: Center(
              child: Text(
                'POSITION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
              ),
            ),
          ),
          // Month columns
          ..._generateMonths(minDate, maxDate).map((month) => SizedBox(
                width: monthWidth,
                child: Center(
                  child: Text(
                    DateFormat('MMM yy').format(month),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGanttBody(DateTime minDate, DateTime maxDate) {
    return Column(
      children: requirements.asMap().entries.map((entry) {
        final index = entry.key;
        final req = entry.value;
        return _GanttRow(
          requirement: req,
          index: index,
          minDate: minDate,
          maxDate: maxDate,
        );
      }).toList(),
    );
  }

  List<DateTime> _generateMonths(DateTime minDate, DateTime maxDate) {
    final months = <DateTime>[];
    DateTime current = DateTime(minDate.year, minDate.month, 1);
    while (!current.isAfter(maxDate)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  int _daysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }
}

/// Legend item widget
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

/// Single row in the Gantt chart representing one position
class _GanttRow extends StatelessWidget {
  const _GanttRow({
    required this.requirement,
    required this.index,
    required this.minDate,
    required this.maxDate,
  });

  final StaffingRequirement requirement;
  final int index;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  Widget build(BuildContext context) {
    final totalDays = _daysBetween(minDate, maxDate).toDouble();
    final monthWidth = 100.0;
    final totalMonths = _monthsBetween(minDate, maxDate);
    final totalWidth = (totalMonths * monthWidth).toDouble();

    double? barStart;
    double? barWidth;

    try {
      if (requirement.startDate.isNotEmpty && requirement.endDate.isNotEmpty) {
        final start = DateFormat('yyyy-MM-dd').parse(requirement.startDate);
        final end = DateFormat('yyyy-MM-dd').parse(requirement.endDate);

        final startDaysFromMin = _daysBetween(minDate, start).toDouble();
        final durationDays = _daysBetween(start, end).toDouble();

        barStart = (startDaysFromMin / totalDays) * totalWidth;
        barWidth = (durationDays / totalDays) * totalWidth;
      }
    } catch (e) {
      // Invalid dates, no bar shown
    }

    final bool isEven = index.isEven;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: const Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Row(
        children: [
          // Position name cell
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  // Status indicator dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(requirement.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: _buildTooltipText(),
                      child: Text(
                        requirement.title.trim().isEmpty ? 'Position ${index + 1}' : requirement.title,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gantt bar area
          SizedBox(
            width: totalWidth,
            height: 48,
            child: Stack(
              children: [
                // Today line
                Positioned(
                  left: _getTodayPosition(totalDays, totalWidth),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: const Color(0xFFEF4444),
                  ),
                ),

                // Today label (only on first row)
                if (index == 0)
                  Positioned(
                    left: _getTodayPosition(totalDays, totalWidth) - 16,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: Color(0xFFEF4444),
                      child: Text(
                        'TODAY',
                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),

                // Duration bar (if dates valid)
                if (barStart != null && barWidth != null)
                  Positioned(
                    left: barStart,
                    top: 10,
                    bottom: 10,
                    width: barWidth!.clamp(4.0, totalWidth), // minimum 4px width
                    child: Tooltip(
                      message: _buildTooltipText(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getStatusColor(requirement.status),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: barWidth! > 30
                              ? Text(
                                  requirement.personName.isNotEmpty
                                      ? requirement.personName.split(' ').first
                                      : '',
                                  style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                // No date indicator
                if (barStart == null && barWidth == null)
                  Center(
                    child: Text(
                      'No dates set',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTooltipText() {
    final buffer = StringBuffer();
    buffer.writeln(requirement.title.isEmpty ? 'Untitled Position' : requirement.title);
    if (requirement.personName.isNotEmpty) {
      buffer.writeln('Person: ${requirement.personName}');
    }
    buffer.writeln('Status: ${requirement.status}');
    if (requirement.startDate.isNotEmpty) {
      buffer.write('Start: ${_formatDate(requirement.startDate)}');
    }
    if (requirement.endDate.isNotEmpty) {
      buffer.write(' → End: ${_formatDate(requirement.endDate)}');
    }
    return buffer.toString().trim();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('active') || s.contains('mobilized')) return const Color(0xFF10B981);
    if (s.contains('hired') || s.contains('confirmed')) return const Color(0xFF3B82F6);
    if (s.contains('released')) return const Color(0xFFF59E0B);
    if (s.contains('not started') || s.contains('open')) return const Color(0xFFD1D5DB);
    return const Color(0xFF8B5CF6); // Default purple
  }

  double _getTodayPosition(double totalDays, double totalWidth) {
    final today = DateTime.now();
    final daysFromStart = _daysBetween(minDate, today).toDouble();
    return (daysFromStart / totalDays) * totalWidth;
  }

  int _daysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  int _monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }
}

/// Base Organisation Plan screen.
/// Captures the project organization structure, staffing sources, working
/// hours, location, and communication modes.
class OrganizationBasePlanScreen extends StatefulWidget {
  const OrganizationBasePlanScreen({super.key});

  @override
  State<OrganizationBasePlanScreen> createState() =>
      _OrganizationBasePlanScreenState();
}

class _OrganizationBasePlanScreenState
    extends State<OrganizationBasePlanScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _staffingSourceController =
      TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _communicationController =
      TextEditingController();
  Timer? _saveDebounce;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    if (_loaded) return;
    final data = ProjectDataHelper.getData(context);
    _descriptionController.text = data.orgPlanDescription;
    _staffingSourceController.text = data.orgStaffingSource;
    _workingHoursController.text = data.orgWorkingHours;
    _locationController.text = data.orgLocation;
    _communicationController.text = data.orgCommunicationMode;
    _loaded = true;

    for (final c in [
      _descriptionController,
      _staffingSourceController,
      _workingHoursController,
      _locationController,
      _communicationController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _saveData();
    });
  }

  void _saveData() {
    if (!mounted) return;
    ProjectDataHelper.getProvider(context).updateField(
      (data) => data.copyWith(
        orgPlanDescription: _descriptionController.text.trim(),
        orgStaffingSource: _staffingSourceController.text.trim(),
        orgWorkingHours: _workingHoursController.text.trim(),
        orgLocation: _locationController.text.trim(),
        orgCommunicationMode: _communicationController.text.trim(),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Base Organisation Plan',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Approval Status': projectData.raciApprovalStatus.isApproved
                ? 'Approved by ${projectData.raciApprovalStatus.approverName}'
                : 'Draft'
          },
        ]),
        PdfSection.table(
          'RACI Matrix',
          headers: ['Deliverable', 'Phase', ...dedup],
          rows: rows
              .map((row) => [
                    row.label,
                    row.phase,
                    ...dedup.map((c) =>
                        row.assignments[c.toLowerCase()]?.toUpperCase() ?? ''),
                  ])
              .toList(),
        ),
      ],
    );
  }
}

class _PlanningSubsectionScreen extends StatefulWidget {
  const _PlanningSubsectionScreen(
      {required this.config,
      this.onAdd,
      this.onAddPredefined,
      this.onEditRole,
      this.onDeleteRole,
      this.onUpdateRoleHeadcount});

  final _PlanningSubsectionConfig config;
  final VoidCallback? onAdd;
  final VoidCallback? onAddPredefined;
  final void Function(int index, RoleDefinition role)? onEditRole;
  final void Function(int index)? onDeleteRole;
  final void Function(int index, int headcount)? onUpdateRoleHeadcount;

  @override
  State<_PlanningSubsectionScreen> createState() =>
      _PlanningSubsectionScreenState();
}

class _PlanningSubsectionScreenState extends State<_PlanningSubsectionScreen> {
  bool _isTableView = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: InitiationLikeSidebar(
                  activeItemLabel: config.activeItemLabel),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - Staffing Plan',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        const gap = 24.0;
                        final twoCol = width >= 980;
                        final halfWidth = twoCol ? (width - gap) / 2 : width;
                        final hasContent = config.metrics.isNotEmpty ||
                            config.sections.isNotEmpty;
                        final showViewToggle =
                            config.showTableView && config.roles.isNotEmpty;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlanningPhaseHeader(
                                title: 'Roles & Responsibilities',
                                onExportPdf: () =>
                                    _exportPlanningSubsectionPdf(context)),
                            const SizedBox(height: 16),
                            _TopHeader(
                              title: config.title,
                              onBack: () =>
                                  PlanningPhaseNavigation.goToPrevious(
                                      context, config.checkpoint),
                              onNext: () => PlanningPhaseNavigation.goToNext(
                                  context, config.checkpoint),
                              onAdd: widget.onAdd,
                              onAddPredefined: widget.onAddPredefined,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              config.subtitle,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 20),
                            PlanningAiNotesCard(
                              title: 'Notes',
                              sectionLabel: config.title,
                              noteKey: config.noteKey,
                              checkpoint: config.checkpoint,
                              description:
                                  'Capture ownership, staffing needs, and role coverage.',
                            ),
                            const SizedBox(height: 24),
                            if (hasContent) ...[
                              _MetricsRow(metrics: config.metrics),
                              const SizedBox(height: 24),
                              if (showViewToggle) ...[
                                Row(
                                  children: [
                                    _ViewToggle(
                                      isTableView: _isTableView,
                                      onChanged: (value) => setState(
                                          () => _isTableView = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_isTableView && config.roles.isNotEmpty)
                                _RolesTable(
                                  roles: config.roles,
                                  onEdit: widget.onEditRole,
                                  onDelete: widget.onDeleteRole,
                                  onUpdateHeadcount:
                                      widget.onUpdateRoleHeadcount,
                                )
                              else
                                Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: config.sections
                                      .map((section) => SizedBox(
                                          width: halfWidth,
                                          child: _SectionCard(data: section)))
                                      .toList(),
                                ),
                            ] else
                              const _SectionEmptyState(
                                title: 'No staffing details yet',
                                message:
                                    'Add roles, responsibilities, and staffing notes to populate this view.',
                                icon: Icons.group_outlined,
                              ),
                            const SizedBox(height: 24),
                            LaunchPhaseNavigation(
                              backLabel: PlanningPhaseNavigation.backLabel(
                                  config.checkpoint),
                              nextLabel: PlanningPhaseNavigation.nextLabel(
                                  config.checkpoint),
                              onBack: () =>
                                  PlanningPhaseNavigation.goToPrevious(
                                      context, config.checkpoint),
                              onNext: () => PlanningPhaseNavigation.goToNext(
                                  context, config.checkpoint),
                            ),
                            const SizedBox(height: 40),
                          ],
                        );
                      },
                    ),
                  ),
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
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTableView, required this.onChanged});

  final bool isTableView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem(
            label: 'Cards',
            icon: Icons.dashboard_outlined,
            selected: !isTableView,
            onTap: () => onChanged(false),
          ),
          _toggleItem(
            label: 'Table',
            icon: Icons.table_rows_outlined,
            selected: isTableView,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF111827)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Roles table view with inline headcount editing.
class _RolesTable extends StatelessWidget {
  const _RolesTable({
    required this.roles,
    this.onEdit,
    this.onDelete,
    this.onUpdateHeadcount,
  });

  final List<RoleDefinition> roles;
  final void Function(int index, RoleDefinition role)? onEdit;
  final void Function(int index)? onDelete;
  final void Function(int index, int headcount)? onUpdateHeadcount;

  @override
  Widget build(BuildContext context) {
    const rowPadding =
        EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    const columns = <_RoleColumnDef>[
      _RoleColumnDef('#', 56),
      _RoleColumnDef('Position', 220),
      _RoleColumnDef('Discipline', 150),
      _RoleColumnDef('Description', 320),
      _RoleColumnDef('Headcount', 140),
      _RoleColumnDef('Actions', 110),
    ];

    final contentWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);
    final minTableWidth = contentWidth + 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Header row
                  Container(
                    width: tableWidth,
                    padding: rowPadding,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: columns
                          .map(
                            (column) => SizedBox(
                              width: column.width,
                              child: Text(
                                column.label.toUpperCase(),
                                textAlign: column.label == '#'
                                    ? TextAlign.center
                                    : column.label == 'Headcount' ||
                                            column.label == 'Actions'
                                        ? TextAlign.center
                                        : TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // Body rows
                  if (roles.isEmpty)
                    Container(
                      width: tableWidth,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: const Center(
                        child: Text(
                          'No roles yet. Use "Add Role" or "Standard Roles" to begin.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: roles.length,
                      itemBuilder: (context, i) {
                        final role = roles[i];
                        return Container(
                          width: tableWidth,
                          padding: rowPadding,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xFFF9FAFB),
                            border: const Border(
                              top: BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: _RolesTableRow(
                            index: i,
                            role: role,
                            columns: columns,
                            onEdit: onEdit != null
                                ? () => onEdit!(i, role)
                                : null,
                            onDelete: onDelete != null
                                ? () => onDelete!(i)
                                : null,
                            onUpdateHeadcount: onUpdateHeadcount != null
                                ? (value) =>
                                    onUpdateHeadcount!(i, value)
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RolesTableRow extends StatelessWidget {
  const _RolesTableRow({
    required this.index,
    required this.role,
    required this.columns,
    this.onEdit,
    this.onDelete,
    this.onUpdateHeadcount,
  });

  final int index;
  final RoleDefinition role;
  final List<_RoleColumnDef> columns;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<int>? onUpdateHeadcount;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      Center(
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          role.title.trim().isEmpty ? 'Untitled Role' : role.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            role.workstream.trim().isEmpty
                ? 'Uncategorized'
                : role.workstream,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4338CA),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          role.description.trim().isEmpty
              ? '—'
              : role.description,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF374151),
          ),
        ),
      ),
      _HeadcountCell(
        headcount: role.headcount,
        onChanged: onUpdateHeadcount,
      ),
      Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit role',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete role',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(
        cells.length,
        (cellIndex) => SizedBox(
            width: columns[cellIndex].width, child: cells[cellIndex]),
      ),
    );
  }
}

class _HeadcountCell extends StatefulWidget {
  const _HeadcountCell({
    required this.headcount,
    required this.onChanged,
  });

  final int headcount;
  final ValueChanged<int>? onChanged;

  @override
  State<_HeadcountCell> createState() => _HeadcountCellState();
}

class _HeadcountCellState extends State<_HeadcountCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.headcount.toString());
  }

  @override
  void didUpdateWidget(covariant _HeadcountCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentText = _controller.text.trim();
    final currentValue = int.tryParse(currentText) ?? 0;
    if (currentValue != widget.headcount) {
      _controller.text = widget.headcount.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCallback = widget.onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeadcountStepButton(
            icon: Icons.remove,
            onTap: hasCallback
                ? () {
                    final current =
                        int.tryParse(_controller.text.trim()) ?? 1;
                    final next = current > 1 ? current - 1 : 1;
                    _controller.text = next.toString();
                    widget.onChanged!(next);
                  }
                : null,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 54,
            child: TextFormField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF111827), width: 1.4),
                ),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null) return;
                if (parsed < 1) return;
                widget.onChanged?.call(parsed);
              },
            ),
          ),
          const SizedBox(width: 6),
          _HeadcountStepButton(
            icon: Icons.add,
            onTap: hasCallback
                ? () {
                    final current =
                        int.tryParse(_controller.text.trim()) ?? 1;
                    final next = current + 1;
                    _controller.text = next.toString();
                    widget.onChanged!(next);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _HeadcountStepButton extends StatelessWidget {
  const _HeadcountStepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFFFCD34D)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? const Color(0xFF92400E)
              : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _RoleColumnDef {
  const _RoleColumnDef(this.label, this.width);

  final String label;
  final double width;
}

class _PlanningSubsectionConfig {
  _PlanningSubsectionConfig({
    required this.title,
    required this.subtitle,
    required this.noteKey,
    required this.checkpoint,
    required this.activeItemLabel,
    required this.metrics,
    required this.sections,
    this.roles = const [],
    this.showTableView = false,
  });

  final String title;
  final String subtitle;
  final String noteKey;
  final String checkpoint;
  final String activeItemLabel;
  final List<_MetricData> metrics;
  final List<_SectionData> sections;
  final List<RoleDefinition> roles;
  final bool showTableView;
}

class _StaffingPlanTable extends StatelessWidget {
  const _StaffingPlanTable({
    required this.requirements,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StaffingRequirement> requirements;
  final void Function(int index, StaffingRequirement req) onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    const rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    const columns = <_StaffingColumnDef>[
      _StaffingColumnDef('#', 50),
      _StaffingColumnDef('Position', 180),
      _StaffingColumnDef('Name', 140),
      _StaffingColumnDef('Location', 130),
      _StaffingColumnDef('Employment', 110),
      _StaffingColumnDef('Category', 100),
      _StaffingColumnDef('Start', 120),
      _StaffingColumnDef('End', 120),
      _StaffingColumnDef('NDU Access', 90),
      _StaffingColumnDef('Status', 110),
      _StaffingColumnDef('Actions', 80),
    ];

    final contentWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);
    final minTableWidth = contentWidth + 32;

    return LayoutBuilder(
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
                  padding: rowPadding,
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    children: columns
                        .map(
                          (column) => SizedBox(
                            width: column.width,
                            child: Text(
                              column.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requirements.length,
                  itemBuilder: (context, i) => Container(
                    width: tableWidth,
                    padding: rowPadding,
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFE5E7EB),
                          width: i == 0 ? 1 : 0.5,
                        ),
                      ),
                    ),
                    child: _StaffingTableRow(
                      index: i,
                      requirement: requirements[i],
                      columns: columns,
                      onEdit: () => onEdit(i, requirements[i]),
                      onDelete: () => onDelete(i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaffingTableRow extends StatelessWidget {
  const _StaffingTableRow({
    required this.index,
    required this.requirement,
    required this.columns,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final StaffingRequirement requirement;
  final List<_StaffingColumnDef> columns;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      // # - Index number
      Center(
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
      // Position - Title (bold)
      _StaffingTextCell(
        requirement.title.trim().isEmpty
            ? 'Untitled Position'
            : requirement.title,
        fontWeight: FontWeight.w700,
      ),
      // Name - Person name
      _StaffingTextCell(
        requirement.personName.trim().isEmpty ? 'TBD' : requirement.personName,
      ),
      // Location
      _StaffingTextCell(
        requirement.location.trim().isEmpty ? 'TBD' : requirement.location,
      ),
      // Employment - FT/PT
      _StaffingTextCell(
        requirement.employmentType.trim().isEmpty ? 'FT' : requirement.employmentType,
        textAlign: TextAlign.center,
      ),
      // Category - Employee/Contractor
      _StaffingTextCell(
        requirement.employeeType.trim().isEmpty ? 'Employee' : requirement.employeeType,
        textAlign: TextAlign.center,
      ),
      // Start date
      _StaffingTextCell(
        requirement.startDate.trim().isEmpty ? 'TBD' : requirement.startDate,
        textAlign: TextAlign.center,
      ),
      // End date
      _StaffingTextCell(
        requirement.endDate.trim().isEmpty ? 'TBD' : requirement.endDate,
        textAlign: TextAlign.center,
      ),
      // NDU Access indicator
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: requirement.nduAccess
                ? const Color(0xFFD1FAE5) // Green background
                : const Color(0xFFF3F4F6), // Gray background
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                requirement.nduAccess ? Icons.check_circle : Icons.remove_circle_outline,
                size: 14,
                color: requirement.nduAccess
                    ? const Color(0xFF059669) // Green
                    : const Color(0xFF9CA3AF), // Gray
              ),
              const SizedBox(width: 4),
              Text(
                requirement.nduAccess ? 'Yes' : 'No',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: requirement.nduAccess
                      ? const Color(0xFF059669)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
      // Status pill
      Center(
        child: _StaffingStatusPill(
          label:
              requirement.status.trim().isEmpty ? 'Open' : requirement.status,
        ),
      ),
      // Actions - Edit/Delete icons
      Align(
        alignment: Alignment.topCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit position',
              onPressed: onEdit,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete position',
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        cells.length,
        (cellIndex) =>
            SizedBox(width: columns[cellIndex].width, child: cells[cellIndex]),
      ),
    );
  }
}

class _StaffingTextCell extends StatelessWidget {
  const _StaffingTextCell(
    this.text, {
    this.fontWeight = FontWeight.w500,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        textAlign: textAlign,
        softWrap: true,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: fontWeight,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _StaffingStatusPill extends StatelessWidget {
  const _StaffingStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    final bool hired = normalized == 'hired';
    final bool active =
        normalized == 'active' || normalized == 'mobilized' || hired;
    final bgColor =
        hired || active ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    final fgColor =
        hired || active ? const Color(0xFF059669) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}

class _StaffingColumnDef {
  const _StaffingColumnDef(this.label, this.width);

  final String label;
  final double width;
}

class _TopHeader extends StatelessWidget {
  const _TopHeader(
      {required this.title,
      required this.onBack,
      this.onNext,
      this.onAdd,
      this.onAddPredefined});

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onAdd;
  final VoidCallback? onAddPredefined;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 12),
        _CircleIconButton(icon: Icons.arrow_forward_ios_rounded, onTap: onNext),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
        const SizedBox(width: 24),
        if (onAddPredefined != null) ...[
          _yellowButton(
            label: onAddPredefined!.toString().contains('SyncRoles')
                ? 'Sync from Roles'
                : 'Standard Roles',
            icon: onAddPredefined!.toString().contains('SyncRoles')
                ? Icons.sync
                : Icons.assignment_outlined,
            onPressed: onAddPredefined!,
          ),
          const SizedBox(width: 12),
        ],
        if (onAdd != null)
          _yellowButton(
            label: 'Add Role',
            icon: Icons.add,
            onPressed: onAdd!,
          ),
        const Spacer(),
        const SizedBox(width: 12),
        const _UserChip(),
      ],
    );
  }

  Widget _yellowButton(
      {required String label,
      required IconData icon,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: const Color(0xFF1F2933),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'User';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151)),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          RepaintBoundary(
            child: StreamBuilder<bool>(
              stream: UserService.watchAdminStatus(),
              builder: (context, snapshot) {
                final email = user?.email ?? '';
                final isAdmin =
                    snapshot.data ?? UserService.isAdminEmail(email);
                final role = isAdmin ? 'Admin' : 'Member';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(role,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              size: 18, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics
          .map((metric) => _MetricCard(
              label: metric.label, value: metric.value, accent: metric.color))
          .toList(),
    );
  }
}

class _MetricData {
  _MetricData(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: accent),
          ),
        ],
      ),
    );
  }
}

class _SectionData {
  _SectionData({
    required this.title,
    required this.subtitle,
    this.bullets = const [],
    // ignore: unused_element_parameter
    this.statusRows = const [],
    this.headcount = 0,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<_BulletData> bullets;
  final List<_StatusRowData> statusRows;
  final int headcount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
}

class _BulletData {
  _BulletData(this.text, this.isCheck);

  final String text;
  final bool isCheck;
}

class _StatusRowData {
  _StatusRowData(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.data});

  final _SectionData data;

  @override
  Widget build(BuildContext context) {
    final showBullets = data.bullets.isNotEmpty;
    final showStatus = data.statusRows.isNotEmpty;
    final showHeadcount = data.headcount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(data.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
              ),
              if (showHeadcount)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_2,
                          size: 13, color: Color(0xFF92400E)),
                      const SizedBox(width: 4),
                      Text(
                        '${data.headcount} ${data.headcount == 1 ? 'person' : 'people'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data.onEdit != null || data.onDelete != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.onEdit != null)
                      IconButton(
                        onPressed: data.onEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (data.onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: data.onDelete,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFEF4444)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data.subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 16),
          if (showBullets)
            ...data.bullets.map((bullet) => _BulletRow(data: bullet)),
          if (showStatus)
            ...data.statusRows.map((row) => _StatusRow(data: row)),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.data});

  final _BulletData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.isCheck ? Icons.check_circle_outline : Icons.circle,
            size: data.isCheck ? 16 : 8,
            color: data.isCheck
                ? const Color(0xFF10B981)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF374151), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.data});

  final _StatusRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: data.color),
            ),
          ),
        ],
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
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(0xFFFFF7ED),
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

/// Custom autocomplete text field for user name selection
class _NameAutocompleteField extends StatelessWidget {
  const _NameAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.isSearching,
    required this.onTextChanged,
    required this.onSuggestionSelected,
    required this.onClearSuggestions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<UserModel> suggestions;
  final bool isSearching;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<UserModel> onSuggestionSelected;
  final VoidCallback onClearSuggestions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onTextChanged,
          onTap: () {
            // Show suggestions again if there's text and we have cached results
            if (controller.text.isNotEmpty && suggestions.isEmpty) {
              onTextChanged(controller.text);
            }
          },
          decoration: InputDecoration(
            hintText: 'Type name or select...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
            ),
            suffixIcon: isSearching
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.person_search, size: 18, color: Color(0xFF6B7280)),
          ),
        ),
        if (suggestions.isNotEmpty && focusNode.hasFocus)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey[200],
                indent: 52,
              ),
              itemBuilder: (context, index) {
                final user = suggestions[index];
                return InkWell(
                  onTap: () => onSuggestionSelected(user),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE5E7EB),
                          child: Text(
                            user.displayName.isNotEmpty 
                                ? user.displayName[0].toUpperCase() 
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Widget for displaying a single staffing reminder card
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final StaffingReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: reminder.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: reminder.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: reminder.priority == Priority.critical
                  ? const Color(0xFFFEE2E2)
                  : reminder.priority == Priority.high
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              reminder.typeIcon,
              size: 18,
              color: reminder.priorityColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: reminder.priorityColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTypeLabel(reminder.type),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (reminder.daysUntil > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: reminder.priority == Priority.critical
                    ? const Color(0xFFFEE2E2)
                    : reminder.priority == Priority.high
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${reminder.daysUntil}d',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: reminder.priority == Priority.critical
                      ? const Color(0xFFDC2626)
                      : reminder.priority == Priority.high
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${reminder.daysUntil.abs()}d overdue',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.upcomingMobilization:
        return 'Upcoming Mobilization';
      case ReminderType.overdueMobilization:
        return 'Overdue Mobilization';
      case ReminderType.upcomingRelease:
        return 'Upcoming Release';
      case ReminderType.overdueRelease:
        return 'Overdue Release';
      case ReminderType.unfilledPosition:
        return 'Unfilled Position';
    }
  }
}
