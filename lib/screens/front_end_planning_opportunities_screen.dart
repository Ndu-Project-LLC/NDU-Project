import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_contract_vendor_quotes_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/screens/project_charter_screen.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/batch_delete_bar.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Front End Planning – Project Opportunities page
/// Built to match the provided screenshot exactly:
/// - Left ProgramWorkspaceSidebar
/// - Top bar with back/forward, centered title, and user chip
/// - Rounded notes input
/// - Section title: Project Opportunities (List out opportunities that would benefit the project here)
/// - Table with headers: No | Potential Opportunity | Discipline | Stakeholder | Potential Cost | Potential Cost | Apply
/// - Three sample rows (1..3)
/// - Bottom-left circular info icon
/// - Bottom-right yellow Submit pill button and blue AI hint card (as shown)
class FrontEndPlanningOpportunitiesScreen extends StatefulWidget {
  const FrontEndPlanningOpportunitiesScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const FrontEndPlanningOpportunitiesScreen()),
    );
  }

  @override
  State<FrontEndPlanningOpportunitiesScreen> createState() =>
      _FrontEndPlanningOpportunitiesScreenState();
}

class _FrontEndPlanningOpportunitiesScreenState
    extends State<FrontEndPlanningOpportunitiesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _notes = RichTextEditingController();
  bool _isSyncReady = false;
  bool _hasAttemptedInitialAutofill = false;

  // Backing rows for the table; built from incoming requirements (if any).
  late List<OpportunityItem> _rows;
  bool _isGeneratingOpportunities = false;

  // Multi-select batch deletion state
  final Set<String> _selectedIds = {};
  bool get _hasSelection => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    ApiKeyManager.initializeApiKey();
    _rows = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectData = ProjectDataHelper.getData(context);
      _notes.text = projectData.frontEndPlanning.opportunities.trim();

      _isSyncReady = true;

      // Check if selectedSolutionTitle exists, warn if missing
      final selectedSolution =
          projectData.preferredSolutionAnalysis?.selectedSolutionTitle;
      if (selectedSolution == null || selectedSolution.trim().isEmpty) {
        debugPrint(
            'Warning: selectedSolutionTitle is missing. State may not have persisted from selection page.');
      }

      // Load saved opportunities
      _loadSavedOpportunities(projectData);
      _syncOpportunitiesToProvider();
      _checkAndAutoGenerateOpportunities();
      if (mounted) setState(() {});
    });
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final fep = projectData.frontEndPlanning;
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Project Opportunities',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
      ],
    );
  }

  Future<void> _checkAndAutoGenerateOpportunities() async {
    if (_hasAttemptedInitialAutofill) return;
    if (_isGeneratingOpportunities) return;
    if (_rows.where((r) => r.opportunity.trim().isNotEmpty).isNotEmpty) return;

    final initialized =
        await _isSectionInitialized('opportunities_initialized');
    if (!initialized && mounted) {
      _hasAttemptedInitialAutofill = true;
      _generateOpportunitiesFromContext(autoTriggered: true);
    }
  }

  bool _shouldAutofillInitialOpportunities() {
    if (_hasAttemptedInitialAutofill) return false;
    if (_isGeneratingOpportunities) return false;
    return _rows.where((r) => r.opportunity.trim().isNotEmpty).isEmpty;
  }

  void _loadSavedOpportunities(ProjectDataModel data) {
    if (data.frontEndPlanning.opportunityItems.isNotEmpty) {
      // FIX: Pass index to ensure unique IDs per row (prevents checkbox select-all bug)
      _rows = data.frontEndPlanning.opportunityItems
          .asMap()
          .entries
          .map((entry) => _normalizeOpportunityItem(entry.value, index: entry.key))
          .toList();
    } else {
      // Migration: Try to parse legacy string format "opportunity: discipline"
      final savedOpportunitiesText = data.frontEndPlanning.opportunities.trim();
      if (savedOpportunitiesText.isNotEmpty) {
        final lines = savedOpportunitiesText
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          _rows = lines.asMap().entries.map((entry) {
            final line = entry.value;
            final parts = line.split(':');
            final opportunity = parts.isNotEmpty ? parts[0].trim() : '';
            final discipline = parts.length > 1 ? parts[1].trim() : '';

            return _normalizeOpportunityItem(OpportunityItem(
              id: '${DateTime.now().microsecondsSinceEpoch}_${entry.key + 1}',
              opportunity: opportunity,
              discipline: discipline,
              stakeholder: '',
              responsibleRole: '',
              potentialCostSavings: '',
              potentialScheduleSavings: '',
              implementationStrategy: '',
              applicablePhase: '',
              owner: '',
              status: 'Identified',
            ));
          }).toList();
          // Initial sync to persist migration
          _syncOpportunitiesToProvider();
        }
      }
    }
  }

  void _useFallbackOpportunities() {
    if (!mounted) return;
    final fallbackList = [
      {
        'opportunity': 'Automate manual data entry processes',
        'discipline': 'IT',
        'responsibleRole': 'IT Operations Manager',
        'owner': 'IT Systems Lead',
        'potentialCostSavings': '50,000',
        'potentialScheduleSavings': '4 weeks faster',
        'implementationStrategy':
            'Deploy workflow automation in high-volume tasks first, then expand.',
        'applicablePhase': 'Planning',
        'status': 'Identified',
      },
      {
        'opportunity': 'Consolidate vendor contracts for better pricing',
        'discipline': 'Procurement',
        'responsibleRole': 'Procurement Director',
        'owner': 'Strategic Sourcing Lead',
        'potentialCostSavings': '75,000',
        'potentialScheduleSavings': '6 weeks faster',
        'implementationStrategy':
            'Bundle overlapping contracts into framework agreements with fixed rates.',
        'applicablePhase': 'Planning',
        'status': 'Identified',
      },
      {
        'opportunity': 'Implement early quality and risk detection mechanisms',
        'discipline': 'Project Management',
        'responsibleRole': 'Program Manager',
        'owner': 'PMO Coordinator',
        'potentialCostSavings': '30,000',
        'potentialScheduleSavings': '2 weeks faster',
        'implementationStrategy':
            'Run weekly control gates with issue trend dashboards.',
        'applicablePhase': 'Execution',
        'status': 'Identified',
      },
      {
        'opportunity': 'Streamline approval workflows',
        'discipline': 'Operations',
        'responsibleRole': 'Operations Lead',
        'owner': 'Process Improvement Analyst',
        'potentialCostSavings': '40,000',
        'potentialScheduleSavings': '3 weeks faster',
        'implementationStrategy':
            'Introduce delegated approval thresholds and parallel review steps.',
        'applicablePhase': 'Design',
        'status': 'Identified',
      },
      {
        'opportunity': 'Leverage existing infrastructure investments',
        'discipline': 'IT',
        'responsibleRole': 'IT Infrastructure Manager',
        'owner': 'Infrastructure Architect',
        'potentialCostSavings': '100,000',
        'potentialScheduleSavings': '8 weeks faster',
        'implementationStrategy':
            'Reuse approved environments and templates instead of greenfield provisioning.',
        'applicablePhase': 'Execution',
        'status': 'Identified',
      },
    ];

    setState(() {
      _rows = fallbackList
          .asMap()
          .entries
          .map((entry) => _normalizeOpportunityItem(OpportunityItem(
                id: '${DateTime.now().microsecondsSinceEpoch}_${entry.key + 1}',
                opportunity: (entry.value['opportunity'] ?? '').toString(),
                discipline: (entry.value['discipline'] ?? '').toString(),
                stakeholder: (entry.value['responsibleRole'] ?? '').toString(),
                responsibleRole:
                    (entry.value['responsibleRole'] ?? '').toString(),
                potentialCostSavings:
                    (entry.value['potentialCostSavings'] ?? '').toString(),
                potentialScheduleSavings:
                    (entry.value['potentialScheduleSavings'] ?? '').toString(),
                implementationStrategy:
                    (entry.value['implementationStrategy'] ?? '').toString(),
                applicablePhase:
                    (entry.value['applicablePhase'] ?? '').toString(),
                owner: (entry.value['owner'] ?? '').toString(),
                status: (entry.value['status'] ?? 'Identified').toString(),
                assignedTo: (entry.value['owner'] ?? '').toString(),
                impact: (entry.value['impact'] ?? 'Medium').toString(),
              )))
          .toList();
    });
    _syncOpportunitiesToProvider();
  }

  OpportunityItem _normalizeOpportunityItem(OpportunityItem item,
      {int index = 0}) {
    final rawId = item.id.trim();
    // Use stable IDs - don't append index to avoid duplicate checkboxes
    final fallbackId =
        '${DateTime.now().microsecondsSinceEpoch}_${index + 1}_${item.opportunity.hashCode.abs()}';
    final id = rawId.isNotEmpty ? rawId : fallbackId;
    final role = item.responsibleRole.trim().isNotEmpty
        ? item.responsibleRole.trim()
        : item.stakeholder.trim();
    final owner = item.owner.trim().isNotEmpty
        ? item.owner.trim()
        : item.assignedTo.trim();
    final phase = item.applicablePhase.trim().isNotEmpty
        ? item.applicablePhase.trim()
        : _phaseFromTags(item.appliesTo);
    final status =
        item.status.trim().isNotEmpty ? item.status.trim() : 'Identified';
    final opportunity = item.opportunity.trim().isNotEmpty
        ? item.opportunity.trim()
        : 'Opportunity ${index + 1}';
    final implementationStrategy = item.implementationStrategy.trim().isNotEmpty
        ? item.implementationStrategy.trim()
        : 'Define implementation steps, owner handoffs, and validation checkpoints.';
    return OpportunityItem(
      id: id,
      opportunity: opportunity,
      discipline: item.discipline.trim(),
      stakeholder: role,
      responsibleRole: role,
      potentialCostSavings: item.potentialCostSavings.trim(),
      potentialScheduleSavings: item.potentialScheduleSavings.trim(),
      implementationStrategy: implementationStrategy,
      applicablePhase: phase,
      owner: owner,
      status: status,
      appliesTo: item.appliesTo.isNotEmpty
          ? List<String>.from(item.appliesTo)
          : _tagsFromPhase(phase),
      assignedTo: owner,
      impact: item.impact.trim().isNotEmpty ? item.impact.trim() : 'Medium',
      isAccepted: item.isAccepted,
    );
  }

  String _phaseFromTags(List<String> tags) {
    if (tags.isEmpty) return '';
    final normalized = tags.map((e) => e.trim().toLowerCase()).toSet();
    if (normalized.contains('project wide')) return 'All';
    if (normalized.contains('schedule') && normalized.contains('estimate')) {
      return 'Planning';
    }
    if (normalized.contains('training')) return 'Execution';
    return '';
  }

  List<String> _tagsFromPhase(String phase) {
    final normalized = phase.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    if (normalized == 'all') {
      return const <String>['Project Wide', 'Estimate', 'Schedule', 'Training'];
    }
    if (normalized == 'planning') {
      return const <String>['Estimate', 'Schedule'];
    }
    if (normalized == 'execution') {
      return const <String>['Schedule', 'Training'];
    }
    if (normalized == 'launch') {
      return const <String>['Training'];
    }
    return const <String>[];
  }

  @override
  void dispose() {
    // No specific listeners to remove other than controllers
    _notes.dispose();
    super.dispose();
  }

  String? _projectId() => ProjectDataHelper.getData(context).projectId;

  Future<bool> _isSectionInitialized(String flagKey) async {
    final projectId = _projectId();
    if (projectId == null || projectId.isEmpty) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('planning_meta')
          .doc('initialization_flags')
          .get();
      return doc.data()?[flagKey] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _markSectionInitialized(String flagKey) async {
    final projectId = _projectId();
    if (projectId == null || projectId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('planning_meta')
          .doc('initialization_flags')
          .set({flagKey: true, '${flagKey}_at': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _syncOpportunitiesToProvider() {
    if (!mounted || !_isSyncReady) return;

    // Legacy string format
    final oppText = _rows
        .map((r) {
          final parts = <String>[
            r.opportunity.trim(),
            if (r.discipline.trim().isNotEmpty)
              'Discipline: ${r.discipline.trim()}',
            if (r.responsibleRole.trim().isNotEmpty)
              'Role: ${r.responsibleRole.trim()}',
            if (r.owner.trim().isNotEmpty) 'Owner: ${r.owner.trim()}',
            if (r.status.trim().isNotEmpty) 'Status: ${r.status.trim()}',
          ];
          return parts.where((p) => p.isNotEmpty).join(' | ');
        })
        .where((s) => s.trim().isNotEmpty)
        .join('\n');

    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField(
      (data) {
        final updated = data.copyWith(
          frontEndPlanning: ProjectDataHelper.updateFEPField(
            current: data.frontEndPlanning,
            opportunities: oppText, // Legacy
            opportunityItems: _rows, // New structured list
          ),
        );
        return ProjectDataHelper.applyTaggedFrontEndPlanningData(updated);
      },
    );
    provider.saveToFirebase(checkpoint: 'fep_opportunities');
    if (_rows.where((r) => r.opportunity.trim().isNotEmpty).isNotEmpty) {
      _markSectionInitialized('opportunities_initialized');
    }
  }

  String _resolvePreferredSolutionTitle(ProjectDataModel data) {
    final preferred = data.preferredSolutionAnalysis;
    final directTitle = preferred?.selectedSolutionTitle?.trim() ?? '';
    if (directTitle.isNotEmpty) return directTitle;

    final preferredIndex = preferred?.selectedSolutionIndex;
    if (preferredIndex != null &&
        preferredIndex >= 0 &&
        preferredIndex < data.potentialSolutions.length) {
      final indexedTitle = data.potentialSolutions[preferredIndex].title.trim();
      if (indexedTitle.isNotEmpty) return indexedTitle;
    }

    final preferredId = preferred?.selectedSolutionId?.trim() ?? '';
    if (preferredId.isNotEmpty) {
      for (final solution in data.potentialSolutions) {
        if (solution.id.trim() == preferredId &&
            solution.title.trim().isNotEmpty) {
          return solution.title.trim();
        }
      }
    }

    if (data.preferredSolution?.title.trim().isNotEmpty == true) {
      return data.preferredSolution!.title.trim();
    }
    if (data.solutionTitle.trim().isNotEmpty) return data.solutionTitle.trim();
    return data.potentialSolution.trim();
  }

  Future<void> _regenerateAllOpportunities() async {
    await _generateOpportunitiesFromContext();
  }

  Future<void> _generateOpportunitiesFromContext(
      {bool autoTriggered = false}) async {
    if (_isGeneratingOpportunities) return; // Prevent duplicate calls
    setState(() {
      _isGeneratingOpportunities = true;
    });

    try {
      final data = ProjectDataHelper.getData(context);
      final provider = ProjectDataHelper.getProvider(context);

      // Track field history before regenerating
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        if (row.opportunity.trim().isNotEmpty) {
          provider.addFieldToHistory(
            'fep_opportunity_${row.id}_opportunity',
            row.opportunity,
            isAiGenerated: true,
          );
        }
      }

      // Verify selectedSolutionTitle exists - if not, log warning
      final selectedSolution = _resolvePreferredSolutionTitle(data);
      if (selectedSolution.trim().isEmpty) {
        debugPrint(
            'Warning: selectedSolutionTitle is blank. Opportunities generation may be incomplete.');
        // Still proceed with generation, but context will be missing selected solution
      }

      final baseContext = ProjectDataHelper.buildFepContext(data,
          sectionLabel: 'Project Opportunities');
      final focusedContext = '''
$baseContext

Selected Preferred Solution:
${selectedSolution.trim().isEmpty ? 'Not specified' : selectedSolution.trim()}

Opportunity generation constraints:
- Match the exact project scope and business case details.
- Match region/location, industry type, and practical delivery constraints.
- Generate opportunities that are directly transferable into the project activities log with clear discipline, role, owner, phase, and status.
''';
      final ai = OpenAiServiceSecure();
      final list = await ai.generateOpportunitiesFromContext(focusedContext);

      if (!mounted) return;
      if (list.isNotEmpty) {
        setState(() {
          _rows = list
              .asMap()
              .entries
              .map((entry) =>
                  _normalizeOpportunityItem(entry.value, index: entry.key))
              .toList();
        });
        _syncOpportunitiesToProvider();
        await ProjectDataHelper.getProvider(context)
            .saveToFirebase(checkpoint: 'fep_opportunities');
      } else {
        // If generation returned empty, use fallback
        debugPrint('No opportunities generated, using fallback');
        _useFallbackOpportunities();
      }
    } catch (e) {
      debugPrint('AI opportunities suggestion failed: $e');
      // On error, use fallback opportunities
      _useFallbackOpportunities();
      if (!autoTriggered && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Opportunity generation failed. Using fallback suggestions.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingOpportunities = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    if (isMobile) {
      return _buildMobileScaffold(context);
    }

    return Scaffold(
      // Ensure white background as requested
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use the same sidebar pattern as PreferredSolutionAnalysisScreen
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Opportunities'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Project Opportunities',
                    ),
                  ),
                  const AdminEditToggle(),
                  Column(
                    children: [
                      FrontEndPlanningHeader(onExportPdf: _exportPdf),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _roundedField(
                                  controller: _notes,
                                  hint: 'Input your notes here...',
                                  minLines: 3),
                              const SizedBox(height: 22),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 1120;
                                  final titleSection = const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      EditableContentText(
                                        contentKey: 'fep_opportunities_title',
                                        fallback: 'Project Opportunities',
                                        category: 'front_end_planning',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      EditableContentText(
                                        contentKey:
                                            'fep_opportunities_subtitle',
                                        fallback:
                                            '(List out opportunities that would benefit the project here)',
                                        category: 'front_end_planning',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  );

                                  final actions = Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      PageRegenerateAllButton(
                                        onRegenerateAll: () async {
                                          final confirmed =
                                              await showRegenerateAllConfirmation(
                                                  context);
                                          if (confirmed && mounted) {
                                            await _regenerateAllOpportunities();
                                          }
                                        },
                                        isLoading: _isGeneratingOpportunities,
                                        tooltip: 'Regenerate all opportunities',
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddOpportunityDialog(),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text(
                                          'Add Opportunity',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF111827),
                                          side: const BorderSide(
                                              color: Color(0xFFD1D5DB)),
                                          minimumSize: const Size(0, 40),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  );

                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        titleSection,
                                        const SizedBox(height: 12),
                                        actions,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: titleSection),
                                      const SizedBox(width: 12),
                                      actions,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: Color(0xFF6B7280)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Use the Action column or double-click a row cell to update. Use Undo in each row to roll back the latest edit.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_isGeneratingOpportunities)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 12),
                                        Text(
                                            'Generating project opportunities from project context...'),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    _OpportunityTable(
                                      rows: _rows,
                                      onEdit: (item) {
                                        _showAddOpportunityDialog(
                                            existingItem: item);
                                      },
                                      onDelete: _confirmDeleteOpportunity,
                                      onUndo: _undoOpportunityRow,
                                      canUndoRow: _canUndoOpportunityRow,
                                      selectedIds: _selectedIds,
                                      onToggleSelect: _toggleSelection,
                                      onAcceptReject: _handleAcceptReject,
                                    ),
                                    if (_hasSelection)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: BatchDeleteBar(
                                          selectedCount: _selectedIds.length,
                                          onDelete: () async {
                                            await _handleBatchDelete();
                                            return true;
                                          },
                                          onClear: () => setState(
                                              () => _selectedIds.clear()),
                                          itemLabel: 'opportunities',
                                          confirmTitle:
                                              'Delete selected opportunities?',
                                        ),
                                      ),
                                  ],
                                ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _BottomOverlays(onSubmit: _submitOpportunities),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateOpportunityRow(int index, OpportunityItem next,
      {bool trackHistory = true}) {
    if (index < 0 || index >= _rows.length) return;
    final normalized = _normalizeOpportunityItem(next, index: index);
    if (trackHistory) {
      _recordOpportunityFieldHistory(
          index: index, previous: _rows[index], next: normalized);
    }
    setState(() {
      _rows[index] = normalized;
    });
    _syncOpportunitiesToProvider();
  }

  void _recordOpportunityFieldHistory({
    required int index,
    required OpportunityItem previous,
    required OpportunityItem next,
  }) {
    final provider = ProjectDataHelper.getProvider(context);
    final prev = {
      'opportunity': previous.opportunity,
      'potential_cost_savings': previous.potentialCostSavings,
      'schedule_impact': previous.potentialScheduleSavings,
      'implementation_strategy': previous.implementationStrategy,
      'discipline': previous.discipline,
      'responsible_role': previous.responsibleRole,
      'owner': previous.owner,
      'applicable_phase': previous.applicablePhase,
      'status': previous.status,
    };
    final cur = {
      'opportunity': next.opportunity,
      'potential_cost_savings': next.potentialCostSavings,
      'schedule_impact': next.potentialScheduleSavings,
      'implementation_strategy': next.implementationStrategy,
      'discipline': next.discipline,
      'responsible_role': next.responsibleRole,
      'owner': next.owner,
      'applicable_phase': next.applicablePhase,
      'status': next.status,
    };
    for (final entry in prev.entries) {
      final oldValue = entry.value.trim();
      final newValue = (cur[entry.key] ?? '').trim();
      if (oldValue == newValue) continue;
      provider.addFieldToHistory(
        'fep_opportunity_${previous.id}_${entry.key}',
        entry.value,
        isAiGenerated: false,
      );
    }
  }

  bool _canUndoOpportunityRow(int index) {
    if (index < 0 || index >= _rows.length) return false;
    final data = ProjectDataHelper.getData(context);
    final id = _rows[index].id;
    final keys = [
      'fep_opportunity_${id}_opportunity',
      'fep_opportunity_${id}_potential_cost_savings',
      'fep_opportunity_${id}_schedule_impact',
      'fep_opportunity_${id}_implementation_strategy',
      'fep_opportunity_${id}_discipline',
      'fep_opportunity_${id}_responsible_role',
      'fep_opportunity_${id}_owner',
      'fep_opportunity_${id}_applicable_phase',
      'fep_opportunity_${id}_status',
    ];
    return keys.any(data.canUndoField);
  }

  void _undoOpportunityRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    final data = ProjectDataHelper.getData(context);
    String undoOrCurrent(String suffix, String current) {
      final key = 'fep_opportunity_${row.id}_$suffix';
      return data.undoField(key) ?? current;
    }

    final reverted = _normalizeOpportunityItem(
      OpportunityItem(
        id: row.id,
        opportunity: undoOrCurrent('opportunity', row.opportunity),
        potentialCostSavings:
            undoOrCurrent('potential_cost_savings', row.potentialCostSavings),
        potentialScheduleSavings:
            undoOrCurrent('schedule_impact', row.potentialScheduleSavings),
        implementationStrategy: undoOrCurrent(
            'implementation_strategy', row.implementationStrategy),
        discipline: undoOrCurrent('discipline', row.discipline),
        responsibleRole: undoOrCurrent('responsible_role', row.responsibleRole),
        stakeholder: undoOrCurrent('responsible_role', row.stakeholder),
        owner: undoOrCurrent('owner', row.owner),
        assignedTo: undoOrCurrent('owner', row.assignedTo),
        applicablePhase: undoOrCurrent('applicable_phase', row.applicablePhase),
        status: undoOrCurrent('status', row.status),
        appliesTo: List<String>.from(row.appliesTo),
        impact: row.impact,
      ),
      index: index,
    );

    setState(() {
      _rows[index] = reverted;
    });
    _syncOpportunitiesToProvider();
  }

  Future<void> _confirmDeleteOpportunity(String id) async {
    final index = _rows.indexWhere((row) => row.id == id);
    if (index == -1) return;
    final opportunityTitle = _rows[index].opportunity.trim();
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Opportunity?',
      itemLabel: opportunityTitle.isEmpty
          ? 'Opportunity ${index + 1}'
          : opportunityTitle,
    );
    if (!confirmed) return;
    setState(() {
      _rows.removeAt(index);
    });
    _syncOpportunitiesToProvider();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleAcceptReject(int index) {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    final updated = row.copyWithAcceptance(accepted: !row.isAccepted);
    setState(() {
      _rows[index] = _normalizeOpportunityItem(updated, index: index);
    });
    _syncOpportunitiesToProvider();
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Selected Opportunities?',
      itemLabel: '$count item${count == 1 ? '' : 's'}',
    );
    if (!confirmed) return;
    setState(() {
      _rows.removeWhere((row) => _selectedIds.contains(row.id));
      _selectedIds.clear();
    });
    _syncOpportunitiesToProvider();
  }

  Future<void> _submitOpportunities() async {
    // If any opportunities are selected, only submit those; otherwise submit all
    final rowsToSubmit = _selectedIds.isNotEmpty
        ? _rows.where((r) => _selectedIds.contains(r.id)).toList()
        : _rows;

    final oppText = rowsToSubmit
        .map((r) {
          final parts = <String>[
            r.opportunity.trim(),
            if (r.discipline.trim().isNotEmpty)
              'Discipline: ${r.discipline.trim()}',
            if (r.responsibleRole.trim().isNotEmpty)
              'Role: ${r.responsibleRole.trim()}',
            if (r.owner.trim().isNotEmpty) 'Owner: ${r.owner.trim()}',
            if (r.applicablePhase.trim().isNotEmpty)
              'Phase: ${r.applicablePhase.trim()}',
            if (r.status.trim().isNotEmpty) 'Status: ${r.status.trim()}',
          ];
          return parts.where((p) => p.isNotEmpty).join(' | ');
        })
        .where((s) => s.trim().isNotEmpty)
        .join('\n');

    final isBasicPlan = ProjectDataHelper.getData(context).isBasicPlanProject;
    final nextItem = SidebarNavigationService.instance
        .getNextAccessibleItem('fep_opportunities', isBasicPlan);

    Widget nextScreen;
    if (nextItem?.checkpoint == 'fep_contract_vendor_quotes') {
      nextScreen = const FrontEndPlanningContractVendorQuotesScreen();
    } else if (nextItem?.checkpoint == 'fep_procurement') {
      nextScreen = const FrontEndPlanningProcurementScreen();
    } else if (nextItem?.checkpoint == 'project_charter') {
      nextScreen = const ProjectCharterScreen();
    } else {
      nextScreen = const FrontEndPlanningContractVendorQuotesScreen();
    }

    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'fep_opportunities',
      nextScreenBuilder: () => nextScreen,
      dataUpdater: (data) => data.copyWith(
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          opportunities: oppText,
          opportunityItems: rowsToSubmit,
        ),
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final projectName = ProjectDataHelper.getData(context).projectName.trim();
    final topSummary = _rows.isEmpty
        ? 'No opportunities captured yet.'
        : _rows
            .take(2)
            .map((item) => item.opportunity.trim())
            .where((value) => value.isNotEmpty)
            .join(' ');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOpportunityDialog(),
        backgroundColor: const Color(0xFFF4B400),
        foregroundColor: Colors.black,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.88,
        child: const SafeArea(
          child:
              InitiationLikeSidebar(activeItemLabel: 'Project Opportunities'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Expanded(
                    child: Text(
                      'Front End Planning',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 13,
                    backgroundColor: Color(0xFFD97706),
                    child: Text('C',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 128),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FRONT END PLANNING > ${projectName.isEmpty ? 'ZAMBIA HUB' : projectName.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI-Generated Summaries',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showAddOpportunityDialog(),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        topSummary.isEmpty
                            ? 'No summary available.'
                            : topSummary,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF374151),
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rows.length > 2
                          ? 'Showing ${_rows.length} opportunities...'
                          : 'No additional opportunities.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'ACTIVE OPPORTUNITIES',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                              letterSpacing: 0.4),
                        ),
                        const Spacer(),
                        Text(
                          '${_rows.length} ITEMS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._rows.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildMobileOpportunityCard(
                                context, entry.key, entry.value),
                          ),
                        ),
                    OutlinedButton.icon(
                      onPressed: () => _showAddOpportunityDialog(),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text(
                        ' Add Opportunity',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        foregroundColor: const Color(0xFF374151),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitOpportunities,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B400),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mobileNavItem(
                icon: Icons.home_filled,
                label: 'Home',
                active: false,
                onTap: () => HomeScreen.open(context),
              ),
              _mobileNavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'AI Planning',
                active: true,
                onTap: () {},
              ),
              const SizedBox(width: 30),
              _mobileNavItem(
                icon: Icons.design_services_rounded,
                label: 'Design',
                active: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DesignPhaseScreen(
                        activeItemLabel: 'Design Management'),
                  ),
                ),
              ),
              _mobileNavItem(
                icon: Icons.engineering_rounded,
                label: 'Execution',
                active: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StaffTeamScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileOpportunityCard(
      BuildContext context, int index, OpportunityItem item) {
    return InkWell(
      onTap: () => _showAddOpportunityDialog(existingItem: item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                Expanded(
                  child: Text(
                    item.opportunity.trim().isEmpty
                        ? 'Unnamed opportunity'
                        : item.opportunity.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _showAddOpportunityDialog(existingItem: item),
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 17, color: Color(0xFF9CA3AF)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.discipline.trim().isEmpty
                        ? 'Discipline TBD'
                        : item.discipline,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.responsibleRole.trim().isEmpty
                        ? 'Role TBD'
                        : item.responsibleRole,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (item.owner.trim().isNotEmpty ||
                item.status.trim().isNotEmpty ||
                item.applicablePhase.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Owner: ${item.owner.trim().isEmpty ? 'Not set' : item.owner.trim()} | Phase: ${item.applicablePhase.trim().isEmpty ? 'Not set' : item.applicablePhase.trim()} | Status: ${item.status.trim().isEmpty ? 'Identified' : item.status.trim()}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.potentialCostSavings.trim().isEmpty ? '0' : item.potentialCostSavings} USD',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.potentialScheduleSavings.trim().isEmpty
                        ? '0 weeks'
                        : item.potentialScheduleSavings,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNavItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? const Color(0xFFD97706) : const Color(0xFF9CA3AF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 9.5, color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOpportunityDialog({OpportunityItem? existingItem}) {
    showDialog(
      context: context,
      builder: (context) => _OpportunityDialog(item: existingItem),
    ).then((val) {
      if (val != null && val is OpportunityItem) {
        if (existingItem != null) {
          final index = _rows.indexWhere((r) => r.id == existingItem.id);
          if (index != -1) {
            _updateOpportunityRow(index, val);
          }
        } else {
          setState(() {
            _rows.add(_normalizeOpportunityItem(val, index: _rows.length));
          });
          _syncOpportunitiesToProvider();
        }
      }
    });
  }
}

class _OpportunityDialog extends StatefulWidget {
  final OpportunityItem? item;
  const _OpportunityDialog({this.item});

  @override
  State<_OpportunityDialog> createState() => _OpportunityDialogState();
}

class _OpportunityDialogState extends State<_OpportunityDialog> {
  final _oppCtrl = TextEditingController();
  final _costSavingsCtrl = TextEditingController();
  final _scheduleImpactCtrl = TextEditingController();
  final _implementationCtrl = TextEditingController();
  final _disciplineCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  String _selectedApplicablePhase = 'Planning';
  String _selectedStatus = 'Identified';
  List<String> _selectedAppliesTo = [];

  final List<String> _applyOptions = ['Estimate', 'Schedule', 'Training'];
  final List<String> _phaseOptions = [
    'Initiation',
    'Planning',
    'Design',
    'Execution',
    'Launch',
    'All',
  ];
  final List<String> _statusOptions = [
    'Identified',
    'Proposed',
    'Approved',
    'In Progress',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _oppCtrl.text = widget.item!.opportunity;
      _costSavingsCtrl.text = widget.item!.potentialCostSavings;
      _scheduleImpactCtrl.text = widget.item!.potentialScheduleSavings;
      _implementationCtrl.text = widget.item!.implementationStrategy;
      _disciplineCtrl.text = widget.item!.discipline;
      _roleCtrl.text = widget.item!.responsibleRole.isNotEmpty
          ? widget.item!.responsibleRole
          : widget.item!.stakeholder;
      _ownerCtrl.text = widget.item!.owner.isNotEmpty
          ? widget.item!.owner
          : widget.item!.assignedTo;
      _selectedApplicablePhase = widget.item!.applicablePhase.isNotEmpty
          ? widget.item!.applicablePhase
          : 'Planning';
      _selectedStatus =
          widget.item!.status.isNotEmpty ? widget.item!.status : 'Identified';
      if (!_phaseOptions.contains(_selectedApplicablePhase)) {
        _selectedApplicablePhase = 'Planning';
      }
      if (!_statusOptions.contains(_selectedStatus)) {
        _selectedStatus = 'Identified';
      }
      _selectedAppliesTo = List.from(widget.item!.appliesTo);
    }
  }

  @override
  void dispose() {
    _oppCtrl.dispose();
    _costSavingsCtrl.dispose();
    _scheduleImpactCtrl.dispose();
    _implementationCtrl.dispose();
    _disciplineCtrl.dispose();
    _roleCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: Color(0xFF111827)),
                      const SizedBox(width: 8),
                      Text(
                          widget.item == null
                              ? 'Add Opportunity'
                              : 'Edit Opportunity',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(
                      label: 'Potential Opportunity',
                      controller: _oppCtrl,
                      autofocus: widget.item == null,
                      hintText: 'Describe the opportunity',
                      minLines: 2,
                      maxLines: 3),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _LabeledField(
                            label: 'Potential Cost Savings',
                            controller: _costSavingsCtrl,
                            hintText: 'e.g. 75,000')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _LabeledField(
                            label: 'Potential Schedule Savings',
                            controller: _scheduleImpactCtrl,
                            hintText: 'e.g. 2 weeks faster')),
                  ]),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Implementation Strategy',
                    controller: _implementationCtrl,
                    hintText:
                        'Describe execution approach, checkpoints, and controls',
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _LabeledField(
                              label: 'Discipline',
                              controller: _disciplineCtrl,
                              hintText: 'e.g. IT, Operations')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _LabeledField(
                              label: 'Responsible Role',
                              controller: _roleCtrl,
                              hintText: 'e.g. Program Manager')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _LabeledField(
                              label: 'Owner',
                              controller: _ownerCtrl,
                              hintText: 'e.g. Jane Doe')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledDropdown(
                          label: 'Applicable Phase',
                          value: _selectedApplicablePhase,
                          items: _phaseOptions,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedApplicablePhase = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LabeledDropdown(
                    label: 'Status',
                    value: _selectedStatus,
                    items: _statusOptions,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Auto Feed Targets',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _applyOptions.map((option) {
                          final isSelected =
                              _selectedAppliesTo.contains(option);
                          return FilterChip(
                            label: Text(option),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAppliesTo.add(option);
                                } else {
                                  _selectedAppliesTo.remove(option);
                                }
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFFFFF7E6),
                            checkmarkColor: const Color(0xFFFBBF24),
                            side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFE5E7EB)),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF374151),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel')),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.black),
                        label: const Text('Save',
                            style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onPressed: () {
                          final opp = _oppCtrl.text.trim();
                          if (opp.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please enter a Potential Opportunity')));
                            return;
                          }
                          final tags = <String>{..._selectedAppliesTo};
                          final phase = _selectedApplicablePhase.trim();
                          if (phase.toLowerCase() == 'all') {
                            tags.addAll(const [
                              'Project Wide',
                              'Estimate',
                              'Schedule',
                              'Training'
                            ]);
                          } else if (phase.toLowerCase() == 'planning') {
                            tags.addAll(const ['Estimate', 'Schedule']);
                          } else if (phase.toLowerCase() == 'execution') {
                            tags.addAll(const ['Schedule', 'Training']);
                          } else if (phase.toLowerCase() == 'launch') {
                            tags.add('Training');
                          }
                          Navigator.of(context).pop(OpportunityItem(
                            id: widget.item?.id ??
                                DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                            opportunity: opp,
                            potentialCostSavings: _costSavingsCtrl.text.trim(),
                            potentialScheduleSavings:
                                _scheduleImpactCtrl.text.trim(),
                            implementationStrategy:
                                _implementationCtrl.text.trim(),
                            discipline: _disciplineCtrl.text.trim(),
                            stakeholder: _roleCtrl.text.trim(),
                            responsibleRole: _roleCtrl.text.trim(),
                            owner: _ownerCtrl.text.trim(),
                            applicablePhase: _selectedApplicablePhase,
                            status: _selectedStatus,
                            impact: 'Medium',
                            appliesTo: tags.toList(),
                            assignedTo: _ownerCtrl.text.trim(),
                          ));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityTable extends StatefulWidget {
  const _OpportunityTable({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
    required this.onUndo,
    required this.canUndoRow,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onAcceptReject,
  });

  final List<OpportunityItem> rows;
  final Function(OpportunityItem) onEdit;
  final Future<void> Function(String) onDelete;
  final ValueChanged<int> onUndo;
  final bool Function(int) canUndoRow;
  final Set<String> selectedIds;
  final void Function(String) onToggleSelect;
  final void Function(int) onAcceptReject;

  @override
  State<_OpportunityTable> createState() => _OpportunityTableState();
}

class _OpportunityTableState extends State<_OpportunityTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = const BorderSide(color: Color(0xFFE5E7EB));
    final headerStyle = const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4B5563));
    final cellStyle = const TextStyle(fontSize: 14, color: Color(0xFF111827));

    Widget td(Widget child, {VoidCallback? onDoubleTap}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: onDoubleTap == null
              ? child
              : GestureDetector(
                  onDoubleTap: onDoubleTap,
                  behavior: HitTestBehavior.translucent,
                  child: child,
                ),
        );

    final rows = widget.rows;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minTableWidth =
              constraints.maxWidth > 2220 ? constraints.maxWidth : 2220.0;

          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(48),
                    1: FixedColumnWidth(52),
                    2: FixedColumnWidth(260),
                    3: FixedColumnWidth(150),
                    4: FixedColumnWidth(150),
                    5: FixedColumnWidth(320),
                    6: FixedColumnWidth(150),
                    7: FixedColumnWidth(150),
                    8: FixedColumnWidth(150),
                    9: FixedColumnWidth(170),
                    10: FixedColumnWidth(160),
                    11: FixedColumnWidth(180),
                  },
                  border: TableBorder(
                    horizontalInside: border,
                    verticalInside: border,
                    top: border,
                    bottom: border,
                    left: border,
                    right: border,
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                      children: [
                        _th('Select', headerStyle),
                        _th('No', headerStyle),
                        _th('Potential Opportunity', headerStyle),
                        _th('Potential Cost Savings', headerStyle),
                        _th('Potential Schedule Savings', headerStyle),
                        _th('Implementation Strategy', headerStyle),
                        _th('Discipline', headerStyle),
                        _th('Responsible Role', headerStyle),
                        _th('Owner', headerStyle),
                        _th('Applicable Phase', headerStyle),
                        _th('Status', headerStyle),
                        _th('Action', headerStyle),
                      ],
                    ),
                    ...List<TableRow>.generate(rows.length, (i) {
                      final r = rows[i];
                      final role = r.responsibleRole.trim().isNotEmpty
                          ? r.responsibleRole
                          : r.stakeholder;
                      final owner =
                          r.owner.trim().isNotEmpty ? r.owner : r.assignedTo;
                      final phase = r.applicablePhase.trim().isNotEmpty
                          ? r.applicablePhase
                          : (r.appliesTo.isEmpty
                              ? '-'
                              : r.appliesTo.join(', '));
                      final status =
                          r.status.trim().isNotEmpty ? r.status : 'Identified';
                      final canUndo = widget.canUndoRow(i);
                      final isAccepted = r.isAccepted;

                      return TableRow(
                          decoration: BoxDecoration(
                            color: isAccepted
                                ? const Color(0xFFF0FDF4)
                                : Colors.transparent,
                          ),
                          children: [
                            // Checkbox column
                            td(Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: widget.selectedIds.contains(r.id),
                                  onChanged: (_) => widget.onToggleSelect(r.id),
                                  activeColor: const Color(0xFFD97706),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            )),
                            // Number column
                            td(Text('${i + 1}', style: cellStyle),
                                onDoubleTap: () => widget.onEdit(r)),
                            td(
                              _ExpandableCellText(
                                text: r.opportunity,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: r.potentialCostSavings,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: r.potentialScheduleSavings,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: r.implementationStrategy,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: r.discipline,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: role,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: owner,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(
                              _ExpandableCellText(
                                text: phase,
                                style: cellStyle,
                                collapsedLines: 2,
                              ),
                              onDoubleTap: () => widget.onEdit(r),
                            ),
                            td(status.isEmpty
                                ? const SizedBox.shrink()
                                : _statusPill(status)),
                            // Action column with Accept/Reject toggle + edit/undo/delete
                            td(
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Accept/Reject toggle
                                    InkWell(
                                      onTap: () => widget.onAcceptReject(i),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isAccepted
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isAccepted
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: isAccepted
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Edit
                                    InkWell(
                                      onTap: () => widget.onEdit(r),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.edit_outlined,
                                            size: 16, color: Color(0xFF4B5563)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Undo
                                    InkWell(
                                      onTap: canUndo
                                          ? () => widget.onUndo(i)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: canUndo
                                              ? const Color(0xFFFFF7E6)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.undo_rounded,
                                            size: 16,
                                            color: canUndo
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF9CA3AF)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Delete
                                    InkWell(
                                      onTap: () => widget.onDelete(r.id),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.delete_outline,
                                            size: 16, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]);
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _th(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: EditableContentText(
          contentKey:
              'fep_opp_header_${text.toLowerCase().replaceAll(' ', '_')}',
          fallback: text,
          category: 'front_end_planning',
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final normalized = status.trim().toLowerCase();
    Color bg;
    Color fg;
    if (normalized.contains('approved') || normalized.contains('closed')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (normalized.contains('progress')) {
      bg = const Color(0xFFFFF7E6);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFC2410C);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BottomOverlays extends StatelessWidget {
  const _BottomOverlays({required this.onSubmit});
  final Future<void> Function() onSubmit;
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              bottom: 24,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: Color(0xFFB3D9FF), shape: BoxShape.circle),
                child: const Icon(Icons.info_outline, color: Colors.white),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: Row(
                children: [
                  _aiHint(),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => onSubmit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      elevation: 0,
                    ),
                    child: const Text('Submit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E5FF)),
      ),
      child: Row(
        children: const [
          Icon(Icons.lightbulb_outline, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Text('Hint',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
          SizedBox(width: 10),
          Text(
              'Keep opportunities tied to scope, discipline, role, owner, and phase.',
              style: TextStyle(color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: VoiceTextField(
            controller: controller,
            autofocus: autofocus,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandableCellText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int collapsedLines;

  const _ExpandableCellText({
    required this.text,
    required this.style,
    this.collapsedLines = 2,
  });

  @override
  State<_ExpandableCellText> createState() => _ExpandableCellTextState();
}

class _ExpandableCellTextState extends State<_ExpandableCellText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) {
      return Text('-',
          style: widget.style.copyWith(color: const Color(0xFF9CA3AF)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: trimmed, style: widget.style),
          textDirection: Directionality.of(context),
          maxLines: widget.collapsedLines,
        )..layout(maxWidth: constraints.maxWidth);

        if (!painter.didExceedMaxLines) {
          return Text(trimmed, style: widget.style, softWrap: true);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trimmed,
              style: widget.style,
              maxLines: _isExpanded ? null : widget.collapsedLines,
              overflow:
                  _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              softWrap: true,
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  _isExpanded ? 'View less' : 'View more',
                  style: widget.style.copyWith(
                    color: const Color(0xFFD97706),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _roundedField(
    {required TextEditingController controller,
    required String hint,
    int minLines = 1}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        VoiceTextField(
          controller: controller,
          minLines: minLines,
          maxLines: null,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          ),
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
      ],
    ),
  );
}
