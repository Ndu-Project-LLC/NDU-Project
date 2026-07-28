import 'package:flutter/material.dart';
import 'package:ndu_project/screens/scope_tracking_implementation_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/models/stakeholder_alignment_item.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/stakeholder_alignment_table_widget.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class StakeholderAlignmentScreen extends StatefulWidget {
  const StakeholderAlignmentScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StakeholderAlignmentScreen()),
    );
  }

  @override
  State<StakeholderAlignmentScreen> createState() =>
      _StakeholderAlignmentScreenState();
}

class _StakeholderAlignmentScreenState
    extends State<StakeholderAlignmentScreen> {
  List<StakeholderAlignmentItem> _items = [];
  List<Map<String, String>> _coreStakeholders = [];
  bool _isLoading = false;
  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load persisted rows first, then seed from prior-phase stakeholders
      // only when the table is truly empty.
      await _loadItems();
      await _loadCoreStakeholders();
    });
  }

  Future<void> _loadItems() async {
    final projectId = _projectId;
    if (projectId == null) return;

    setState(() => _isLoading = true);
    try {
      final items = await ExecutionPhaseService.loadStakeholderAlignmentItems(
          projectId: projectId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stakeholder alignment items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCoreStakeholders() async {
    final projectId = _projectId;
    if (projectId == null) return;

    try {
      final stakeholders = await ExecutionPhaseService.loadCoreStakeholders(
          projectId: projectId);
      if (mounted) {
        setState(() {
          _coreStakeholders = stakeholders;
        });
        // Auto-populate stakeholders if none exist
        if (_items.isEmpty && stakeholders.isNotEmpty) {
          _autoPopulateStakeholders(stakeholders);
        } else if (_items.isEmpty && stakeholders.isEmpty) {
          _autoGenerateStakeholdersFromAi();
        }
      }
    } catch (e) {
      debugPrint('Error loading core stakeholders: $e');
    }
  }

  Future<void> _autoGenerateStakeholdersFromAi() async {
    if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
    _autoGenerationTriggered = true;
    _isAutoGenerating = true;
    try {
      final generated = await ExecutionPhaseAiSeed.generateEntries(
        context: context,
        section: 'Stakeholder Alignment',
        sections: const {
          'stakeholders': 'Key stakeholders to align during execution',
        },
        itemsPerSection: 4,
      );
      final entries = generated['stakeholders'] ?? const [];
      if (entries.isEmpty) return;

      final newItems = entries
          .map(
            (entry) => StakeholderAlignmentItem(
              stakeholderName: entry.title,
              stakeholderRole: 'Stakeholder',
              alignmentStatus: 'Neutral',
              keyInterest: 'ROI',
              feedbackSummary: entry.details,
            ),
          )
          .toList();

      if (newItems.isNotEmpty) {
        setState(() => _items.addAll(newItems));
        await _saveItems();
        for (final item in newItems) {
          _autoGenerateEngagementStrategy(item);
        }
      }
    } catch (e) {
      debugPrint('Error auto-generating stakeholders: $e');
    } finally {
      _isAutoGenerating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 18 : 32;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Stakeholder Alignment'),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_isLoading) const SizedBox(height: 16),
                        PlanningPhaseHeader(
                            title: 'Stakeholder Alignment',
                            showNavigationButtons: false,
                            onExportPdf: _exportPdf),
                        const SizedBox(height: 16),
                        _buildPageHeader(context),
                        const SizedBox(height: 20),
                        _buildStakeholderTable(),
                        const SizedBox(height: 24),
                        _buildFooterNavigation(context),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Stakeholder Alignment',
                    ),
                  ),
                  const KazAiChatBubble(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC812),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'STAKEHOLDER ALIGNMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stakeholder Alignment',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Stakeholder Alignment must pull from your earlier work to show how well you\'ve met expectations. Keep sponsors, operations, and governance aligned as execution closes.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            if (!isMobile) _buildHeaderActions(),
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 12),
          _buildHeaderActions(),
        ],
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        CsvTableImportButton(
          tableTitle: 'Stakeholder Alignment',
          columns: const [
            CsvColumnSpec(
              key: 'stakeholderName',
              label: 'Stakeholder Name',
              required: true,
              sampleValue: 'Community Liaison',
            ),
            CsvColumnSpec(
              key: 'stakeholderRole',
              label: 'Stakeholder Role',
              sampleValue: 'External',
            ),
            CsvColumnSpec(
              key: 'alignmentStatus',
              label: 'Alignment Status',
              allowedValues: ['Aligned', 'Neutral', 'Concerned', 'Resistent'],
              defaultValue: 'Neutral',
              sampleValue: 'Aligned',
            ),
            CsvColumnSpec(
              key: 'keyInterest',
              label: 'Key Interest',
              sampleValue: 'Schedule certainty',
            ),
            CsvColumnSpec(
              key: 'feedbackSummary',
              label: 'Feedback Summary',
              sampleValue: 'Supports staged delivery',
            ),
            CsvColumnSpec(
              key: 'engagementStrategy',
              label: 'Engagement Strategy',
              sampleValue: 'Monthly review meetings',
            ),
            CsvColumnSpec(
              key: 'lastEngagementDate',
              label: 'Last Engagement',
              sampleValue: '2026-07-10',
            ),
          ],
          onImport: _importStakeholdersFromCsv,
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _showAddStakeholderDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Stakeholder',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Future<void> _importStakeholdersFromCsv(
    List<Map<String, String>> rows,
  ) async {
    final imported = <StakeholderAlignmentItem>[];
    for (final row in rows) {
      final name = row['stakeholderName']?.trim() ?? '';
      if (name.isEmpty) continue;
      final status = row['alignmentStatus']?.trim() ?? '';
      final dateText = row['lastEngagementDate']?.trim() ?? '';
      imported.add(
        StakeholderAlignmentItem(
          stakeholderName: name,
          stakeholderRole: row['stakeholderRole']?.trim() ?? '',
          alignmentStatus: status.isNotEmpty ? status : 'Neutral',
          keyInterest: row['keyInterest']?.trim() ?? '',
          feedbackSummary: row['feedbackSummary']?.trim() ?? '',
          engagementStrategy: row['engagementStrategy']?.trim() ?? '',
          lastEngagementDate:
              dateText.isNotEmpty ? DateTime.tryParse(dateText) : null,
        ),
      );
    }

    if (imported.isEmpty) return;
    setState(() => _items.addAll(imported));
    await _saveItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Imported ${imported.length} stakeholder alignment row(s).'),
      ),
    );
  }

  Widget _buildStakeholderTable() {
    final allItems = _items;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stakeholder Alignment Table',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Track alignment status, engagement, and feedback for each stakeholder',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          StakeholderAlignmentTableWidget(
            items: allItems,
            onUpdated: (item) {
              setState(() {
                final index = _items.indexWhere((i) => i.id == item.id);
                if (index >= 0) {
                  _items[index] = item;
                } else {
                  _items.add(item);
                }
              });
            },
            onDeleted: (item) async {
              final ok = await launchConfirmDelete(context, itemName: 'stakeholder alignment item');
              if (!ok) return;
              setState(() {
                _items.removeWhere((i) => i.id == item.id);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddStakeholderDialog() async {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final feedbackController = TextEditingController();
    final engagementStrategyController = AutoBulletTextController();

    String? selectedStakeholder;
    String selectedStatus = 'Neutral';
    String? selectedKeyInterest;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Stakeholder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStakeholder,
                    decoration: const InputDecoration(
                      labelText: 'Stakeholder Name/Role',
                      hintText: 'Select from Core Stakeholders or enter new',
                    ),
                    items: [
                      ..._coreStakeholders.map((stakeholder) {
                        final displayName =
                            '${stakeholder['name']} - ${stakeholder['role']}';
                        return DropdownMenuItem<String>(
                          value: displayName,
                          child: Text(displayName),
                        );
                      }),
                      const DropdownMenuItem<String>(
                        value: '__NEW__',
                        child: Text('+ Add New Stakeholder'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == '__NEW__') {
                        selectedStakeholder = null;
                        nameController.clear();
                        roleController.clear();
                      } else if (value != null) {
                        selectedStakeholder = value;
                        final parts = value.split(' - ');
                        nameController.text = parts[0];
                        roleController.text = parts.length > 1 ? parts[1] : '';
                      }
                      setDialogState(() {});
                    },
                  ),
                  if (selectedStakeholder == null ||
                      selectedStakeholder == '__NEW__') ...[
                    VoiceTextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Stakeholder Name',
                      ),
                    ),
                    VoiceTextField(
                      controller: roleController,
                      decoration: const InputDecoration(
                        labelText: 'Stakeholder Role',
                      ),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration:
                        const InputDecoration(labelText: 'Alignment Status'),
                    items: ['Aligned', 'Neutral', 'Concerned', 'Resistent']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedKeyInterest,
                    decoration:
                        const InputDecoration(labelText: 'Key Interest/Value'),
                    items: [
                      'ROI',
                      'Security',
                      'Ease of Use',
                      'Cost Savings',
                      'Revenue',
                      'Compliance',
                      'Performance',
                      'Innovation',
                      'Risk Mitigation',
                      'User Experience',
                    ]
                        .map((interest) => DropdownMenuItem(
                              value: interest,
                              child: Text(interest),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedKeyInterest = value);
                    },
                  ),
                  VoiceTextField(
                    controller: feedbackController,
                    decoration: const InputDecoration(
                      labelText: 'Feedback Summary (prose, no bullets)',
                      hintText: 'Enter feedback...',
                    ),
                    maxLines: 3,
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
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Stakeholder Name is required.')),
                    );
                    return;
                  }
                  final newItem = StakeholderAlignmentItem(
                    stakeholderName: name,
                    stakeholderRole: roleController.text.trim(),
                    alignmentStatus: selectedStatus,
                    keyInterest: selectedKeyInterest ?? '',
                    feedbackSummary: feedbackController.text.trim(),
                    engagementStrategy:
                        engagementStrategyController.text.trim(),
                  );
                  setState(() {
                    _items.add(newItem);
                  });
                  Navigator.of(dialogContext).pop();
                  await _saveItems();

                  // Auto-generate engagement strategy if key fields are filled
                  if (name.isNotEmpty &&
                      (selectedKeyInterest != null ||
                          roleController.text.trim().isNotEmpty)) {
                    _autoGenerateEngagementStrategy(newItem);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _autoPopulateStakeholders(
      List<Map<String, String>> stakeholders) async {
    final projectId = _projectId;
    if (projectId == null) return;

    try {
      final newItems = <StakeholderAlignmentItem>[];
      for (final stakeholder in stakeholders.take(10)) {
        // Limit to first 10
        final name = stakeholder['name'] ?? '';
        final role = stakeholder['role'] ?? 'Stakeholder';
        if (name.isNotEmpty) {
          // Check if this stakeholder already exists
          final exists = _items.any((item) =>
              item.stakeholderName == name && item.stakeholderRole == role);
          if (!exists) {
            newItems.add(StakeholderAlignmentItem(
              stakeholderName: name,
              stakeholderRole: role,
              alignmentStatus: 'Neutral',
              keyInterest: '',
            ));
          }
        }
      }
      if (newItems.isNotEmpty) {
        setState(() {
          _items.addAll(newItems);
        });
        await _saveItems();
        // Auto-generate engagement strategies for new stakeholders
        for (final item in newItems) {
          _autoGenerateEngagementStrategy(item);
        }
      }
    } catch (e) {
      debugPrint('Error auto-populating stakeholders: $e');
    }
  }

  Future<void> _autoGenerateEngagementStrategy(
      StakeholderAlignmentItem item) async {
    if (item.stakeholderName.isEmpty) return;

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) return;

      final projectId = provider.projectData.projectId;
      if (projectId == null || projectId.isEmpty) return;

      final projectData = provider.projectData;

      final projectContext =
          ProjectDataHelper.buildExecutivePlanContext(projectData);
      final openAiService = OpenAiServiceSecure();
      final strategy = await openAiService.generateEngagementStrategy(
        context: projectContext,
        stakeholderName: item.stakeholderName,
        stakeholderRole: item.stakeholderRole,
        keyInterest: item.keyInterest.isNotEmpty ? item.keyInterest : 'ROI',
        alignmentStatus: item.alignmentStatus,
        feedbackSummary: item.feedbackSummary,
      );

      if (strategy.isNotEmpty && mounted) {
        setState(() {
          final index = _items.indexWhere((i) => i.id == item.id);
          if (index >= 0) {
            _items[index] = item.copyWith(engagementStrategy: strategy);
          }
        });
        await _saveItems();
      }
    } catch (e) {
      debugPrint('Error auto-generating engagement strategy: $e');
    }
  }

  Future<void> _saveItems() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;

    try {
      await ExecutionPhaseService.saveStakeholderAlignmentItems(
        projectId: projectId,
        items: _items,
      );
    } catch (e) {
      debugPrint('Error saving stakeholder alignment items: $e');
    }
  }

  Widget _buildFooterNavigation(BuildContext context) {
    return LaunchPhaseNavigation(
      backLabel: 'Back: Scope Tracking Implementation',
      nextLabel: 'Next: Update Ops & Maintenance Plans',
      onBack: () => ScopeTrackingImplementationScreen.open(context),
      onNext: () => UpdateOpsMaintenancePlansScreen.open(context),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Stakeholder Alignment',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Project Name': projectData.projectName.isNotEmpty
                ? projectData.projectName
                : 'N/A'
          },
          {
            'Solution Title': projectData.solutionTitle.isNotEmpty
                ? projectData.solutionTitle
                : 'N/A'
          },
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_stakeholder_alignment_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
