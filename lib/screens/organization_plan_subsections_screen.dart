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
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/premium_edit_dialog.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

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

    final List<_MetricData> metrics = [
      _MetricData(
          'Total Roles', roles.length.toString(), const Color(0xFF3B82F6)),
      _MetricData(
          'Deciplines',
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
      ),
      onAdd: () => _addRole(context),
      onAddPredefined: () => _showPredefinedRolesDialog(context),
    );
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

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Standard Roles'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: predefined.length,
              itemBuilder: (context, index) {
                final role = predefined[index];
                final alreadyAdded =
                    currentRoles.any((r) => r.title == role.title);
                return CheckboxListTile(
                  title: Text(role.title),
                  subtitle: Text(role.workstream),
                  value: selectedIndices.contains(index) || alreadyAdded,
                  enabled: !alreadyAdded,
                  onChanged: alreadyAdded
                      ? null
                      : (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedIndices.add(index);
                            } else {
                              selectedIndices.remove(index);
                            }
                          });
                        },
                );
              },
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
                      final newRoles =
                          selectedIndices.map((i) => predefined[i]).toList();
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
            updatedRoles[index] = RoleDefinition(
              title: titleValue,
              workstream: workstreamController.text.trim(),
              description: descController.text.trim(),
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
              value: selectedTitle,
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
            PremiumEditDialog.fieldLabel('Decipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
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
              value: selectedTitle,
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
            PremiumEditDialog.fieldLabel('Decipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
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
  static const List<String> _raciColumns = [
    'Phase changes',
    'Charter / Business Case',
    'Plans & Backlogs',
    'Tasks & Deliverables',
    'Financials',
    'Risks & Issues',
    'Changes',
    'Status Reports',
    'Phase / Project Close',
  ];

  static const List<_RaciSeedRole> _defaultRoles = [
    _RaciSeedRole('Project Sponsor (Owner)', 'Both', 'Management'),
    _RaciSeedRole('Project Manager', 'Both', 'Management'),
    _RaciSeedRole('PMO Manager', 'Both', 'Management'),
    _RaciSeedRole('Program Manager', 'Both', 'Management'),
    _RaciSeedRole('Product Owner', 'Agile', 'Management'),
    _RaciSeedRole('Project Controls Manager', 'Both', 'Management'),
    _RaciSeedRole('Interface Manager', 'Both', 'Management'),
    _RaciSeedRole('Business Manager', 'Waterfall', 'Management'),
    _RaciSeedRole('Contracts Manager', 'Both', 'Management'),
    _RaciSeedRole('Procurement Manager', 'Both', 'Management'),
    _RaciSeedRole('Release Manager', 'Agile', 'Management'),
    _RaciSeedRole('Startup Manager', 'Waterfall', 'Management'),
    _RaciSeedRole('Construction Manager', 'Waterfall', 'Management'),
    _RaciSeedRole('Project Engineer', 'Both', 'Engineering'),
    _RaciSeedRole('Engineering Manager', 'Waterfall', 'Engineering'),
    _RaciSeedRole('Technical Manager', 'Agile', 'Engineering'),
    _RaciSeedRole('Change Manager', 'Both', 'Engineering'),
    _RaciSeedRole('Quality Lead', 'Both', 'Engineering'),
    _RaciSeedRole('Lead Designer', 'Agile', 'Engineering'),
    _RaciSeedRole('Design Lead', 'Waterfall', 'Engineering'),
    _RaciSeedRole('Lead Developer', 'Agile', 'Engineering'),
    _RaciSeedRole('Schedule Lead', 'Both', 'Engineering'),
    _RaciSeedRole('Cost Lead', 'Both', 'Engineering'),
    _RaciSeedRole('Test Lead', 'Both', 'Engineering'),
    _RaciSeedRole('Change Lead', 'Both', 'Engineering'),
    _RaciSeedRole('Scrum Master', 'Agile', 'Engineering'),
    _RaciSeedRole('Cost Estimator', 'Both', 'Specialist'),
    _RaciSeedRole('Scheduler', 'Both', 'Specialist'),
    _RaciSeedRole('Business Analyst', 'Agile', 'Specialist'),
    _RaciSeedRole('Technical Architect', 'Agile', 'Specialist'),
    _RaciSeedRole('Solutions Architect', 'Agile', 'Specialist'),
    _RaciSeedRole('Developer - Backend', 'Agile', 'Development'),
    _RaciSeedRole('Developer - Frontend', 'Agile', 'Development'),
    _RaciSeedRole('Developer - Fullstack', 'Agile', 'Development'),
    _RaciSeedRole('Tester', 'Agile', 'QA'),
    _RaciSeedRole('Quality Control', 'Both', 'QA'),
    _RaciSeedRole('Procurement', 'Both', 'Operations'),
    _RaciSeedRole('Interface', 'Both', 'Operations'),
    _RaciSeedRole('Automation', 'Agile', 'Development'),
    _RaciSeedRole('DevOps Engineer', 'Agile', 'Development'),
    _RaciSeedRole('Operations Liason', 'Both', 'Operations'),
    _RaciSeedRole('Hypercare', 'Agile', 'Operations'),
    _RaciSeedRole('Design Engineer', 'Waterfall', 'Specialist'),
    _RaciSeedRole('Designer - UX', 'Agile', 'Design'),
    _RaciSeedRole('Designer - UI', 'Agile', 'Design'),
    _RaciSeedRole('Engineer', 'Both', 'Specialist'),
    _RaciSeedRole('Data Specialist', 'Agile', 'Specialist'),
    _RaciSeedRole('Create Role', 'Both', 'Custom'),
  ];

  bool _didSeed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didSeed) return;
      final provider = ProjectDataHelper.getProvider(context);
      if (provider.projectData.raciMatrixRows.isEmpty) {
        await _seedDefaultMatrix();
      }
      if (mounted) {
        setState(() {
          _didSeed = true;
        });
      }
    });
  }

  Future<void> _seedDefaultMatrix() async {
    final rows = _defaultRoles
        .map((role) => RaciMatrixRow(
              role: role.role,
              framework: role.framework,
              discipline: role.discipline,
              assignments:
                  _buildSuggestedAssignments(role.role, role.discipline),
            ))
        .toList();
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(raciMatrixRows: rows),
      showSnackbar: false,
    );
  }

  Future<void> _syncFromRoles() async {
    final provider = ProjectDataHelper.getProvider(context);
    final existing =
        List<RaciMatrixRow>.from(provider.projectData.raciMatrixRows);
    final existingTitles =
        existing.map((row) => row.role.trim().toLowerCase()).toSet();

    final additions = provider.projectData.projectRoles
        .where((role) => role.title.trim().isNotEmpty)
        .where(
            (role) => !existingTitles.contains(role.title.trim().toLowerCase()))
        .map((role) => RaciMatrixRow(
              role: role.title.trim(),
              framework: _inferFramework(role.title),
              discipline: role.workstream.trim().isEmpty
                  ? _inferDiscipline(role.title)
                  : role.workstream.trim(),
              assignments: _buildSuggestedAssignments(
                role.title.trim(),
                role.workstream.trim().isEmpty
                    ? _inferDiscipline(role.title)
                    : role.workstream.trim(),
              ),
            ))
        .toList();

    if (additions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'RACI Matrix is already aligned with Roles & Responsibilities.')),
      );
      return;
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) =>
          d.copyWith(raciMatrixRows: [...existing, ...additions]),
    );
    if (mounted) setState(() {});
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final rows = projectData.raciMatrixRows;
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'RACI Matrix',
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
          projectData.planningNotes['planning_organization_raci_matrix'] ??
              'No data recorded.',
        ),
        PdfSection.table(
          'RACI Matrix',
          headers: ['Role', 'Framework', 'Discipline', ..._raciColumns],
          rows: rows
              .map((row) => [
                    row.role,
                    row.framework,
                    row.discipline,
                    ..._raciColumns
                        .map((column) => row.assignments[column]?.trim() ?? ''),
                  ])
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final rows = projectData.raciMatrixRows;
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;
    final agileRoles =
        rows.where((row) => row.framework.toLowerCase() == 'agile').length;
    final waterfallRoles =
        rows.where((row) => row.framework.toLowerCase() == 'waterfall').length;
    final hybridRoles =
        rows.where((row) => row.framework.toLowerCase() == 'both').length;

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
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
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
                          onExportPdf: _exportPdf,
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
                          onAdd: () => _addRow(context),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'AI-seeded role coverage for governance, planning, delivery, financial, risk, and close-out responsibilities.',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 20),
                        PlanningAiNotesCard(
                          title: 'Notes',
                          sectionLabel: 'RACI Matrix',
                          noteKey: 'planning_organization_raci_matrix',
                          checkpoint: 'organization_raci_matrix',
                          description:
                              'Capture tailoring decisions for responsibility ownership and governance.',
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _MetricCard(
                              label: 'Total Roles',
                              value: rows.length.toString(),
                              accent: const Color(0xFF3B82F6),
                            ),
                            _MetricCard(
                              label: 'Agile Roles',
                              value: agileRoles.toString(),
                              accent: const Color(0xFF8B5CF6),
                            ),
                            _MetricCard(
                              label: 'Waterfall Roles',
                              value: waterfallRoles.toString(),
                              accent: const Color(0xFF10B981),
                            ),
                            _MetricCard(
                              label: 'Both Frameworks',
                              value: hybridRoles.toString(),
                              accent: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _RaciLegendChip(code: 'R', label: 'Responsible'),
                            _RaciLegendChip(code: 'A', label: 'Accountable'),
                            _RaciLegendChip(code: 'C', label: 'Consulted'),
                            _RaciLegendChip(code: 'I', label: 'Informed'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _addRow(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Role'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _syncFromRoles,
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync from Roles'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: const Color(0xFF1F2933),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _seedDefaultMatrix,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Reset AI Suggestions'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (rows.isEmpty)
                          const _SectionEmptyState(
                            title: 'No RACI roles yet',
                            message:
                                'Seed the standard matrix or sync the current Roles & Responsibilities page.',
                            icon: Icons.grid_on_outlined,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _RaciMatrixTable(
                                rows: rows,
                                columns: _raciColumns,
                                onView: (index, row) =>
                                    _viewRow(context, index, row),
                                onEdit: (index, row) =>
                                    _editRow(context, index, row),
                                onDelete: (index) => _deleteRow(context, index),
                              ),
                            ),
                          ),
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

  Future<void> _editRow(
      BuildContext context, int index, RaciMatrixRow row) async {
    final rootContext = context;
    final roleController = TextEditingController(text: row.role);
    final disciplineController = TextEditingController(text: row.discipline);
    String framework = row.framework;
    final assignmentValues = <String, String>{
      for (final column in _raciColumns) column: row.assignments[column] ?? '',
    };

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Edit RACI Row',
          icon: Icons.grid_on_outlined,
          onSave: () async {
            final updated = List<RaciMatrixRow>.from(
              ProjectDataHelper.getProvider(rootContext)
                  .projectData
                  .raciMatrixRows,
            );
            updated[index] = row.copyWith(
              role: roleController.text.trim(),
              framework: framework,
              discipline: disciplineController.text.trim(),
              assignments: Map<String, String>.from(assignmentValues),
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_raci_matrix',
              saveInBackground: true,
              nextScreenBuilder: () => const OrganizationRaciMatrixScreen(),
              dataUpdater: (d) => d.copyWith(raciMatrixRows: updated),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Role'),
            PremiumEditDialog.textField(
              controller: roleController,
              hint: 'Role name',
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Framework'),
            DropdownButtonFormField<String>(
              value: framework,
              items: const ['Both', 'Agile', 'Waterfall']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => framework = value);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
              controller: disciplineController,
              hint: 'e.g. Management',
            ),
            const SizedBox(height: 16),
            for (final column in _raciColumns) ...[
              PremiumEditDialog.fieldLabel(column),
              DropdownButtonFormField<String>(
                value: assignmentValues[column]?.isEmpty == true
                    ? ''
                    : assignmentValues[column],
                items: const ['', 'R', 'A', 'C', 'I']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.isEmpty ? '—' : value),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() {
                  assignmentValues[column] = value ?? '';
                }),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addRow(BuildContext context) async {
    final rootContext = context;
    final roleController = TextEditingController();
    final disciplineController = TextEditingController();
    String framework = 'Both';
    final assignmentValues = <String, String>{
      for (final column in _raciColumns) column: '',
    };

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Add RACI Role',
          icon: Icons.grid_on_outlined,
          onSave: () async {
            final role = roleController.text.trim();
            final discipline = disciplineController.text.trim();
            final newRow = RaciMatrixRow(
              role: role.isEmpty ? 'New Role' : role,
              framework: framework,
              discipline: discipline.isEmpty ? 'Management' : discipline,
              assignments: Map<String, String>.from(assignmentValues),
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_raci_matrix',
              saveInBackground: true,
              nextScreenBuilder: () => const OrganizationRaciMatrixScreen(),
              dataUpdater: (d) =>
                  d.copyWith(raciMatrixRows: [...d.raciMatrixRows, newRow]),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Role'),
            PremiumEditDialog.textField(
              controller: roleController,
              hint: 'e.g. PMO Analyst',
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Framework'),
            DropdownButtonFormField<String>(
              value: framework,
              items: const ['Both', 'Agile', 'Waterfall']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => framework = value);
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
              controller: disciplineController,
              hint: 'e.g. Engineering',
            ),
            const SizedBox(height: 16),
            for (final column in _raciColumns) ...[
              PremiumEditDialog.fieldLabel(column),
              DropdownButtonFormField<String>(
                value: assignmentValues[column],
                items: const ['', 'R', 'A', 'C', 'I']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.isEmpty ? '—' : value),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() {
                  assignmentValues[column] = value ?? '';
                }),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _viewRow(
      BuildContext context, int index, RaciMatrixRow row) async {
    final orderedAssignments = _raciColumns
        .map((column) =>
            MapEntry(column, row.assignments[column]?.trim() ?? '—'))
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row.role.isEmpty ? 'RACI Role ${index + 1}' : row.role),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Framework: ${row.framework.isEmpty ? 'Both' : row.framework}'),
              const SizedBox(height: 4),
              Text(
                  'Discipline: ${row.discipline.isEmpty ? 'Unassigned' : row.discipline}'),
              const SizedBox(height: 16),
              ...orderedAssignments.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _RaciValuePill(value: entry.value),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRow(BuildContext context, int index) async {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete RACI Row'),
        content: const Text(
          'Are you sure you want to remove this role from the RACI matrix?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final updated = List<RaciMatrixRow>.from(
                ProjectDataHelper.getProvider(rootContext)
                    .projectData
                    .raciMatrixRows,
              );
              updated.removeAt(index);
              Navigator.pop(dialogContext);
              await ProjectDataHelper.saveAndNavigate(
                context: rootContext,
                checkpoint: 'organization_raci_matrix',
                saveInBackground: true,
                nextScreenBuilder: () => const OrganizationRaciMatrixScreen(),
                dataUpdater: (d) => d.copyWith(raciMatrixRows: updated),
              );
              if (mounted) setState(() {});
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _buildSuggestedAssignments(
      String role, String discipline) {
    final normalizedRole = role.toLowerCase();
    final normalizedDiscipline = discipline.toLowerCase();
    final assignments = {for (final column in _raciColumns) column: ''};

    void apply(Map<String, String> values) {
      for (final entry in values.entries) {
        assignments[entry.key] = entry.value;
      }
    }

    if (normalizedRole.contains('sponsor')) {
      apply({
        'Phase changes': 'A',
        'Charter / Business Case': 'A',
        'Plans & Backlogs': 'I',
        'Tasks & Deliverables': 'I',
        'Financials': 'A',
        'Risks & Issues': 'I',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'A',
      });
    } else if (normalizedRole == 'project manager') {
      apply({
        'Phase changes': 'R',
        'Charter / Business Case': 'R',
        'Plans & Backlogs': 'A',
        'Tasks & Deliverables': 'A',
        'Financials': 'C',
        'Risks & Issues': 'A',
        'Changes': 'A',
        'Status Reports': 'A',
        'Phase / Project Close': 'R',
      });
    } else if (normalizedRole.contains('pmo')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'I',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'R',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('program manager')) {
      apply({
        'Phase changes': 'A',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'I',
        'Financials': 'C',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'C',
        'Phase / Project Close': 'I',
      });
    } else if (normalizedRole.contains('product owner')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'A',
        'Tasks & Deliverables': 'A',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('project controls')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'C',
        'Financials': 'A',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'R',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('change manager')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'A',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('change lead')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'R',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('scrum master')) {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'R',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('schedule')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'R',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'I',
        'Changes': 'C',
        'Status Reports': 'C',
        'Phase / Project Close': 'I',
      });
    } else if (normalizedRole.contains('cost')) {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'I',
        'Financials': 'R',
        'Risks & Issues': 'I',
        'Changes': 'C',
        'Status Reports': 'C',
        'Phase / Project Close': 'I',
      });
    } else if (normalizedRole.contains('procurement') ||
        normalizedRole.contains('contracts')) {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'C',
        'Risks & Issues': 'I',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('business analyst')) {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'R',
        'Plans & Backlogs': 'R',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'I',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'I',
      });
    } else if (normalizedRole.contains('architect')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedRole.contains('operations liason') ||
        normalizedRole.contains('hypercare')) {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'R',
      });
    } else if (normalizedRole.contains('startup') ||
        normalizedRole.contains('construction') ||
        normalizedRole.contains('release')) {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'R',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'management') {
      apply({
        'Phase changes': 'C',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'I',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'engineering') {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'development') {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'I',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'design') {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'C',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'I',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'qa') {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'C',
        'Status Reports': 'I',
        'Phase / Project Close': 'C',
      });
    } else if (normalizedDiscipline == 'operations') {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'R',
        'Financials': 'I',
        'Risks & Issues': 'C',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'R',
      });
    } else {
      apply({
        'Phase changes': 'I',
        'Charter / Business Case': 'I',
        'Plans & Backlogs': 'C',
        'Tasks & Deliverables': 'C',
        'Financials': 'I',
        'Risks & Issues': 'I',
        'Changes': 'I',
        'Status Reports': 'I',
        'Phase / Project Close': 'I',
      });
    }

    return assignments;
  }

  String _inferFramework(String role) {
    final normalized = role.toLowerCase();
    if (normalized.contains('product owner') ||
        normalized.contains('scrum master') ||
        normalized.contains('lead developer') ||
        normalized.contains('technical manager') ||
        normalized.contains('release manager') ||
        normalized.contains('developer') ||
        normalized.contains('designer -') ||
        normalized.contains('devops') ||
        normalized.contains('automation') ||
        normalized.contains('architect') ||
        normalized == 'tester' ||
        normalized.contains('hypercare')) {
      return 'Agile';
    }
    if (normalized.contains('business manager') ||
        normalized.contains('startup manager') ||
        normalized.contains('construction manager') ||
        normalized.contains('engineering manager') ||
        normalized.contains('design lead') ||
        normalized.contains('design engineer')) {
      return 'Waterfall';
    }
    return 'Both';
  }

  String _inferDiscipline(String role) {
    final normalized = role.toLowerCase();
    if (normalized.contains('manager') ||
        normalized.contains('sponsor') ||
        normalized.contains('owner')) {
      return 'Management';
    }
    if (normalized.contains('developer') ||
        normalized.contains('devops') ||
        normalized.contains('automation')) {
      return 'Development';
    }
    if (normalized.contains('designer -')) {
      return 'Design';
    }
    if (normalized.contains('tester') ||
        normalized.contains('quality control')) {
      return 'QA';
    }
    if (normalized.contains('procurement') ||
        normalized.contains('interface') ||
        normalized.contains('hypercare') ||
        normalized.contains('operations')) {
      return 'Operations';
    }
    if (normalized.contains('architect') ||
        normalized.contains('analyst') ||
        normalized.contains('estimator') ||
        normalized.contains('scheduler') ||
        normalized == 'engineer' ||
        normalized.contains('data specialist') ||
        normalized.contains('design engineer')) {
      return 'Specialist';
    }
    return 'Engineering';
  }
}

class OrganizationStaffingPlanScreen extends StatefulWidget {
  const OrganizationStaffingPlanScreen({super.key});

  @override
  State<OrganizationStaffingPlanScreen> createState() =>
      _OrganizationStaffingPlanScreenState();
}

class _OrganizationStaffingPlanScreenState
    extends State<OrganizationStaffingPlanScreen> {
  bool _didAutoPopulate = false;

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Staffing Plan',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                            title: 'Staffing Plan', onExportPdf: _exportPdf),
                        const SizedBox(height: 16),
                        // Header row
                        Row(
                          children: [
                            _CircleIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => PlanningPhaseNavigation.goToPrevious(
                                context,
                                'organization_staffing_plan',
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CircleIconButton(
                              icon: Icons.arrow_forward_ios_rounded,
                              onTap: () async {
                                final nextScreen =
                                    PlanningPhaseNavigation.resolveNextScreen(
                                          context,
                                          'organization_staffing_plan',
                                        ) ??
                                        const TeamTrainingAndBuildingScreen();
                                await ProjectDataHelper.saveAndNavigate(
                                  context: context,
                                  checkpoint: 'organization_staffing_plan',
                                  saveInBackground: true,
                                  nextScreenBuilder: () => nextScreen,
                                  dataUpdater: (d) => d,
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Staffing Plan',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827)),
                            ),
                            const Spacer(),
                            const _UserChip(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Plan resource needs, staffing timeline, and onboarding cadence.',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 24),

                        // Metrics row
                        Row(
                          children: [
                            _MetricCard(
                                label: 'Total Staff',
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
                        const SizedBox(height: 24),

                        // Staffing Table
                        if (requirements.isEmpty)
                          const _SectionEmptyState(
                            title: 'No staffing positions yet',
                            message:
                                'Sync from defined roles to populate this view.',
                            icon: Icons.group_outlined,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 6)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _StaffingPlanTable(
                                requirements: requirements,
                                onEdit: (index, req) =>
                                    _editStaffing(context, index, req),
                                onDelete: (index) =>
                                    _deleteStaffing(context, index),
                              ),
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
                        ),
                        const SizedBox(height: 40),
                      ],
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
            PremiumEditDialog.fieldLabel('Person Name'),
            PremiumEditDialog.textField(
                controller: personController, hint: 'Assign to...'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Location'),
            PremiumEditDialog.textField(
                controller: locationController,
                hint: 'e.g. Remote, Office, Site'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumEditDialog.fieldLabel('Employment'),
                      DropdownButtonFormField<String>(
                        value: empType,
                        items: ['FT', 'PT']
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
}

class _RaciSeedRole {
  const _RaciSeedRole(this.role, this.framework, this.discipline);

  final String role;
  final String framework;
  final String discipline;
}

class _RaciLegendChip extends StatelessWidget {
  const _RaciLegendChip({required this.code, required this.label});

  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaciMatrixTable extends StatelessWidget {
  const _RaciMatrixTable({
    required this.rows,
    required this.columns,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<RaciMatrixRow> rows;
  final List<String> columns;
  final void Function(int index, RaciMatrixRow row) onView;
  final void Function(int index, RaciMatrixRow row) onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    const rowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final defs = <_RaciColumnDef>[
      const _RaciColumnDef('#', 54),
      const _RaciColumnDef('Role', 240),
      const _RaciColumnDef('Framework', 105),
      const _RaciColumnDef('Discipline', 140),
      ...columns.map((column) => _RaciColumnDef(column, 150)),
      const _RaciColumnDef('Actions', 132),
    ];

    final contentWidth =
        defs.fold<double>(0, (sum, column) => sum + column.width);
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
                    children: defs
                        .map(
                          (column) => SizedBox(
                            width: column.width,
                            child: Text(
                              column.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                for (int i = 0; i < rows.length; i++)
                  Container(
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
                    child: _RaciMatrixTableRow(
                      index: i,
                      row: rows[i],
                      columns: columns,
                      defs: defs,
                      onView: () => onView(i, rows[i]),
                      onEdit: () => onEdit(i, rows[i]),
                      onDelete: () => onDelete(i),
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

class _RaciMatrixTableRow extends StatelessWidget {
  const _RaciMatrixTableRow({
    required this.index,
    required this.row,
    required this.columns,
    required this.defs,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final RaciMatrixRow row;
  final List<String> columns;
  final List<_RaciColumnDef> defs;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
      _StaffingTextCell(
        row.role.trim().isEmpty ? 'Untitled Role' : row.role,
        fontWeight: FontWeight.w700,
      ),
      _RaciFrameworkCell(framework: row.framework),
      _StaffingTextCell(
        row.discipline.trim().isEmpty ? 'Unassigned' : row.discipline,
      ),
      ...columns.map(
        (column) => Center(
          child: _RaciValuePill(value: row.assignments[column]?.trim() ?? ''),
        ),
      ),
      Align(
        alignment: Alignment.topCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              tooltip: 'View row',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onView,
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit row',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete row',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        cells.length,
        (cellIndex) => SizedBox(
          width: defs[cellIndex].width,
          child: cells[cellIndex],
        ),
      ),
    );
  }
}

class _RaciFrameworkCell extends StatelessWidget {
  const _RaciFrameworkCell({required this.framework});

  final String framework;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    switch (framework.toLowerCase()) {
      case 'agile':
        bgColor = const Color(0xFFEDE9FE);
        fgColor = const Color(0xFF6D28D9);
        break;
      case 'waterfall':
        bgColor = const Color(0xFFDBEAFE);
        fgColor = const Color(0xFF1D4ED8);
        break;
      default:
        bgColor = const Color(0xFFFEF3C7);
        fgColor = const Color(0xFFB45309);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          framework.isEmpty ? 'Both' : framework,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}

class _RaciValuePill extends StatelessWidget {
  const _RaciValuePill({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toUpperCase();
    final Map<String, ({Color bg, Color fg})> styles = {
      'R': (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8)),
      'A': (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C)),
      'C': (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D)),
      'I': (bg: const Color(0xFFF3E8FF), fg: const Color(0xFF7E22CE)),
    };
    final style = styles[normalized] ??
        (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF6B7280));

    return Container(
      width: 34,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? '—' : normalized,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: style.fg,
        ),
      ),
    );
  }
}

class _RaciColumnDef {
  const _RaciColumnDef(this.label, this.width);

  final String label;
  final double width;
}

class _PlanningSubsectionScreen extends StatelessWidget {
  const _PlanningSubsectionScreen(
      {required this.config, this.onAdd, this.onAddPredefined});

  final _PlanningSubsectionConfig config;
  final VoidCallback? onAdd;
  final VoidCallback? onAddPredefined;

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
              child: InitiationLikeSidebar(
                  activeItemLabel: config.activeItemLabel),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        const gap = 24.0;
                        final twoCol = width >= 980;
                        final halfWidth = twoCol ? (width - gap) / 2 : width;
                        final hasContent = config.metrics.isNotEmpty ||
                            config.sections.isNotEmpty;
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
                              onAdd: onAdd,
                              onAddPredefined: onAddPredefined,
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

class _PlanningSubsectionConfig {
  _PlanningSubsectionConfig({
    required this.title,
    required this.subtitle,
    required this.noteKey,
    required this.checkpoint,
    required this.activeItemLabel,
    required this.metrics,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String noteKey;
  final String checkpoint;
  final String activeItemLabel;
  final List<_MetricData> metrics;
  final List<_SectionData> sections;
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
      _StaffingColumnDef('#', 72),
      _StaffingColumnDef('Position', 220),
      _StaffingColumnDef('Person', 180),
      _StaffingColumnDef('Location', 170),
      _StaffingColumnDef('Type', 170),
      _StaffingColumnDef('Load', 140),
      _StaffingColumnDef('Est. Cost', 150),
      _StaffingColumnDef('Status', 150),
      _StaffingColumnDef('Timeline', 180),
      _StaffingColumnDef('Actions', 110),
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
                for (int i = 0; i < requirements.length; i++)
                  Container(
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
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
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
      _StaffingTextCell(
        requirement.title.trim().isEmpty
            ? 'Untitled Position'
            : requirement.title,
        fontWeight: FontWeight.w700,
      ),
      _StaffingTextCell(
        requirement.personName.trim().isEmpty ? 'TBD' : requirement.personName,
      ),
      _StaffingTextCell(
        requirement.location.trim().isEmpty ? 'TBD' : requirement.location,
      ),
      _StaffingTextCell(
        '${requirement.employmentType} / ${requirement.employeeType}',
      ),
      _StaffingTextCell(
        '${requirement.headcount} x ${requirement.plannedMonths.toStringAsFixed(1)} mo',
      ),
      _StaffingTextCell(
        requirement.monthlyCost > 0 && requirement.plannedMonths > 0
            ? currency.format(requirement.estimatedTotal)
            : '—',
        fontWeight: FontWeight.w700,
      ),
      Center(
        child: _StaffingStatusPill(
          label:
              requirement.status.trim().isEmpty ? 'Open' : requirement.status,
        ),
      ),
      _StaffingTextCell(
        '${requirement.startDate.trim().isEmpty ? 'TBD' : requirement.startDate} -> ${requirement.endDate.trim().isEmpty ? 'TBD' : requirement.endDate}',
        textAlign: TextAlign.center,
      ),
      Align(
        alignment: Alignment.topCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit position',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete position',
              onPressed: onDelete,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          StreamBuilder<bool>(
            stream: UserService.watchAdminStatus(),
            builder: (context, snapshot) {
              final email = user?.email ?? '';
              final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<_BulletData> bullets;
  final List<_StatusRowData> statusRows;
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
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
              color: data.color.withOpacity(0.12),
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

/// Entry in the role bank — maps a role title to a description and workstream.
class _RoleBankEntry {
  final String description;
  final String workstream;

  const _RoleBankEntry({
    required this.description,
    required this.workstream,
  });
}
