import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_risks_screen.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/download_helper.dart' as dl;

/// Front End Planning - Project Requirements page
/// Implements the layout from the provided screenshot exactly:
/// - Top notes field
/// - "Project Requirements" table with No, Requirement, Requirement type
/// - Add another row button
/// - Bottom AI hint chip and yellow Submit button
/// - Bottom-left and bottom-right pager chevrons
class FrontEndPlanningRequirementsScreen extends StatefulWidget {
  const FrontEndPlanningRequirementsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const FrontEndPlanningRequirementsScreen()),
    );
  }

  @override
  State<FrontEndPlanningRequirementsScreen> createState() =>
      _FrontEndPlanningRequirementsScreenState();
}

class _FrontEndPlanningRequirementsScreenState
    extends State<FrontEndPlanningRequirementsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _notesController = RichTextEditingController();
  final ScrollController _mainContentScrollController = ScrollController();
  final ScrollController _requirementsHorizontalController = ScrollController();
  final ScrollController _requirementsVerticalController = ScrollController();
  bool _isGeneratingRequirements = false;
  bool _isTableView = true;
  bool _isRegeneratingRow = false;
  int? _regeneratingRowIndex;
  Timer? _autoSaveTimer;
  DateTime? _lastAutoSaveSnackAt;
  bool _didInitialGenerationCheck = false;
  bool _showInitialGenerationSpinner = false;
  String? _initialGenerationError;
  bool _showHorizontalScrollHint = false;
  bool _showVerticalScrollHint = false;
  List<_AssignableMember> _memberOptions = const <_AssignableMember>[];
  final List<_RequirementRow> _deletedRequirements = [];

  static const Set<String> _authorizedRequirementSubmitRoles = {
    'owner',
    'project manager',
    'technical manager',
  };

  // Start with a single requirement row; additional rows are added via "Add another"
  final List<_RequirementRow> _rows = [];

  @override
  void initState() {
    super.initState();
    // Ensure OpenAI key/env is loaded for per-row regenerate.
    ApiKeyManager.initializeApiKey();
    _requirementsHorizontalController.addListener(_updateScrollHints);
    _requirementsVerticalController.addListener(_updateScrollHints);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final projectData = ProjectDataHelper.getData(context);
      _notesController.text = projectData.frontEndPlanning.requirementsNotes;
      _notesController.addListener(_handleNotesChanged);
      _loadSavedRequirements(projectData);
      unawaited(_initializeMemberContext(projectData));
      if (mounted) setState(() {});
    });
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final fep = projectData.frontEndPlanning;
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Requirements',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
      ],
    );
  }

  _RequirementRow _createRow(int number, {bool expanded = false}) {
    return _RequirementRow(
      number: number,
      onChanged: _scheduleAutoSave,
      isExpanded: expanded,
    );
  }

  Future<void> _initializeMemberContext(ProjectDataModel data) async {
    await _loadAssignableMembers(data);
    await _runInitialAutoGenerationIfNeeded(data);
  }

  Future<void> _loadAssignableMembers(ProjectDataModel data) async {
    final merged = <_AssignableMember>[];
    final seen = <String>{};

    void addMember({
      required String id,
      required String name,
      required String email,
      required String role,
      required String source,
    }) {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedName = name.trim().toLowerCase();
      final key = normalizedEmail.isNotEmpty
          ? 'email:$normalizedEmail'
          : (id.trim().isNotEmpty
              ? 'id:${id.trim().toLowerCase()}'
              : 'name:$normalizedName');
      if (key.trim().isEmpty || seen.contains(key)) return;
      seen.add(key);
      merged.add(
        _AssignableMember(
          id: id.trim(),
          name: name.trim(),
          email: email.trim(),
          role: role.trim(),
          source: source,
        ),
      );
    }

    for (final member in data.teamMembers) {
      if (member.name.trim().isEmpty && member.email.trim().isEmpty) continue;
      addMember(
        id: member.id,
        name: member.name,
        email: member.email,
        role: member.role,
        source: 'Project Team',
      );
    }

    try {
      final users = await UserService.searchUsers('');
      for (final user in users) {
        if (user.displayName.trim().isEmpty && user.email.trim().isEmpty) {
          continue;
        }
        addMember(
          id: user.uid,
          name: user.displayName,
          email: user.email,
          role: user.isAdmin ? 'Admin' : 'Member',
          source: 'Company Members',
        );
      }
    } catch (e) {
      debugPrint('Failed loading company members for requirements: $e');
    }

    merged.sort((a, b) {
      final sourceWeight =
          a.source == b.source ? 0 : (a.source == 'Project Team' ? -1 : 1);
      if (sourceWeight != 0) return sourceWeight;
      return a.displayLabel
          .toLowerCase()
          .compareTo(b.displayLabel.toLowerCase());
    });

    if (!mounted) return;
    setState(() => _memberOptions = merged);
  }

  bool _hasAnySavedRequirements(ProjectDataModel data) {
    if (data.frontEndPlanning.requirementItems.isNotEmpty) return true;
    if (data.frontEndPlanning.requirements.trim().isNotEmpty) return true;
    return _rows.any((row) => row.descriptionController.text.trim().isNotEmpty);
  }

  Future<void> _runInitialAutoGenerationIfNeeded(ProjectDataModel data) async {
    if (_didInitialGenerationCheck) return;
    _didInitialGenerationCheck = true;

    if (_hasAnySavedRequirements(data)) {
      if (_rows.isEmpty) {
        setState(() => _rows.add(_createRow(1, expanded: true)));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _showInitialGenerationSpinner = true;
        _initialGenerationError = null;
      });
    }

    final generated = await _generateRequirementsFromContext(
      showSeedNotice: false,
    );
    if (!mounted) return;

    if (generated) {
      setState(() {
        _showInitialGenerationSpinner = false;
        _initialGenerationError = null;
      });
      return;
    }

    setState(() {
      _showInitialGenerationSpinner = false;
      _initialGenerationError =
          'Could not auto-generate requirements. You can retry manually.';
      if (_rows.isEmpty) {
        _rows.add(_createRow(1, expanded: true));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Requirements generation failed. Please use "Generate with AI" to retry.',
        ),
      ),
    );
  }

  void _updateScrollHints() {
    final showHorizontal = _requirementsHorizontalController.hasClients &&
        _requirementsHorizontalController.position.maxScrollExtent > 0 &&
        _requirementsHorizontalController.offset <
            _requirementsHorizontalController.position.maxScrollExtent;
    final showVertical = _requirementsVerticalController.hasClients &&
        _requirementsVerticalController.position.maxScrollExtent > 0 &&
        _requirementsVerticalController.offset <
            _requirementsVerticalController.position.maxScrollExtent;
    if (showHorizontal == _showHorizontalScrollHint &&
        showVertical == _showVerticalScrollHint) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _showHorizontalScrollHint = showHorizontal;
      _showVerticalScrollHint = showVertical;
    });
  }

  void _loadSavedRequirements(ProjectDataModel data) {
    final savedItems = data.frontEndPlanning.requirementItems;
    if (savedItems.isNotEmpty) {
      _replaceRowsSafely(
        savedItems.asMap().entries.map((entry) {
          final item = entry.value;
          final row = _createRow(entry.key + 1);
          row.setDescriptionFromCode(item.description);
          row.commentsController.text = item.comments;
          row.selectedType = _normalizeRequirementTypeSelection(
            item.requirementType,
          );
          row.selectedDiscipline =
              _normalizeDisciplineSelection(item.discipline);
          row.roleController.text = item.role;
          row.personController.text =
              _resolvePersonSelection(item.person, roleHint: item.role);
          row.selectedPhase = _normalizePhaseSelection(item.phase);
          row.sourceController.text = item.requirementSource;
          return row;
        }).toList(),
      );
      return;
    }

    final savedText = data.frontEndPlanning.requirements.trim();
    if (savedText.isNotEmpty) {
      final lines = savedText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        _replaceRowsSafely(
          lines.asMap().entries.map((entry) {
            final row = _createRow(entry.key + 1);
            row.setDescriptionFromCode(entry.value);
            return row;
          }).toList(),
        );
      }
    }
  }

  Future<bool> _generateRequirementsFromContext({
    bool showSeedNotice = true,
  }) async {
    if (_isGeneratingRequirements) return false;
    setState(() {
      _isGeneratingRequirements = true;
      _initialGenerationError = null;
    });
    try {
      final data = ProjectDataHelper.getData(context);
      final provider = ProjectDataHelper.getProvider(context);
      final structuredContext = ProjectDataHelper.buildFepContext(
        data,
        sectionLabel: 'Project Requirements',
      ).trim();
      final scanContext = ProjectDataHelper.buildProjectContextScan(
        data,
        sectionLabel: 'Project Requirements',
      ).trim();
      // Enhanced fallback context to prevent "Data not available" errors
      final fallbackContext = <String>[
        if (data.projectName.trim().isNotEmpty)
          'Project name: ${data.projectName.trim()}',
        if (data.solutionTitle.trim().isNotEmpty)
          'Solution: ${data.solutionTitle.trim()}',
        if (data.solutionDescription.trim().isNotEmpty)
          'Description: ${data.solutionDescription.trim()}',
        if (data.businessCase.trim().isNotEmpty)
          'Business case: ${data.businessCase.trim()}',
        // Add Overall Framework context
        if ((data.overallFramework ?? '').trim().isNotEmpty)
          'Overall Framework: ${(data.overallFramework ?? '').trim()}',
        // Add existing requirements notes for continuity
        if (data.frontEndPlanning.requirementsNotes.trim().isNotEmpty)
          'Requirements Notes: ${data.frontEndPlanning.requirementsNotes.trim()}',
        // Add top risk considerations for context
        if (data.frontEndPlanning.riskRegisterItems.isNotEmpty)
          'Top Risks: ${data.frontEndPlanning.riskRegisterItems.take(3).map((r) => '${r.riskName} (Impact: ${r.impactLevel})').join('; ')}',
        // Add opportunity items for context
        if (data.frontEndPlanning.opportunityItems.isNotEmpty)
          'Opportunities: ${data.frontEndPlanning.opportunityItems.take(3).map((o) => o.opportunity).join('; ')}',
      ].join('\n');

      final combinedContext = [
        structuredContext,
        scanContext,
        fallbackContext,
      ].where((value) => value.trim().isNotEmpty).join('\n\n');

      final ctx = StringBuffer()
        ..writeln(combinedContext)
        ..writeln()
        ..writeln('Discipline assignment instructions:')
        ..writeln(
          '- Return a specific discipline for each requirement from this list whenever possible:',
        )
        ..writeln(_RequirementRow.disciplineOptions.join(', '))
        ..writeln('- Never return placeholder text like "Discipline".')
        ..writeln('- If no discipline fits, return "Other".');
      final ai = OpenAiServiceSecure();
      final reqs = await ai.generateRequirementsFromBusinessCase(
        ctx.toString(),
      );
      if (!mounted) return false;
      if (reqs.isNotEmpty) {
        // Track field history before replacing
        for (final row in _rows) {
          if (row.descriptionController.text.trim().isNotEmpty) {
            provider.addFieldToHistory(
              'fep_requirement_${row.number}_description',
              row.descriptionController.text,
              isAiGenerated: true,
            );
          }
        }

        final nextRows = reqs.asMap().entries.map((e) {
          final r = _createRow(e.key + 1);
          final requirementText = (e.value['requirement'] ?? '').toString();
          r.setDescriptionFromCode(requirementText);
          r.commentsController.text = '';
          r.selectedType = _normalizeRequirementTypeSelection(
            (e.value['requirementType'] ?? 'Functional').toString(),
          );
          final aiDiscipline = (e.value['discipline'] ?? '').toString();
          final aiRole = (e.value['role'] ?? '').toString();
          final aiPerson = (e.value['person'] ?? '').toString();
          r.selectedDiscipline = _normalizeDisciplineSelection(aiDiscipline);
          r.roleController.text = aiRole;
          r.personController.text =
              _resolvePersonSelection(aiPerson, roleHint: aiRole);
          r.selectedPhase =
              _normalizePhaseSelection((e.value['phase'] ?? '').toString());
          r.sourceController.text =
              (e.value['requirementSource'] ?? '').toString();

          // Track new AI-generated content
          if (requirementText.isNotEmpty) {
            provider.addFieldToHistory(
              'fep_requirement_${r.number}_description',
              requirementText,
              isAiGenerated: true,
            );
          }

          return r;
        }).toList();

        setState(() {
          _isGeneratingRequirements = false;
        });
        _replaceRowsSafely(nextRows);
        _commitAutoSave(showSnack: false);
        if (mounted && showSeedNotice) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('KAZ AI Requirements Seeded'),
              content: const Text(
                'These initial requirements were auto-generated by KAZ AI based on the defined project scope. Please review and refine them to ensure all relevant aspects of the project are accurately captured.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return true;
      }
      if (mounted) {
        setState(() {
          _initialGenerationError =
              'AI returned no requirements. Please add a few manually or retry.';
        });
      }
    } catch (e) {
      debugPrint('AI requirements suggestion failed: $e');
      if (mounted) {
        final message = e.toString();
        setState(() {
          if (message.contains('OpenAI API key') ||
              message.contains('not configured')) {
            _initialGenerationError =
                'AI service is starting up. Please try again in a moment.';
          } else if (message.contains('response_format')) {
            _initialGenerationError =
                'AI response formatting failed. Please retry or check your OpenAI proxy configuration.';
          } else if (message.contains('Data not available') ||
              message.contains('insufficient context') ||
              message.contains('no data') ||
              message.toLowerCase().contains('context.*empty')) {
            // Specific handling for "Data not available in current context" error
            _initialGenerationError =
                'Insufficient project data for AI generation. Please fill in more project details (Business Case, Solution, or Risks) and try again.';
          } else {
            _initialGenerationError =
                'AI requirements suggestion failed. Please try again.';
          }
        });
      }
    }
    if (mounted) {
      setState(() => _isGeneratingRequirements = false);
    }
    return false;
  }

  Future<void> _regenerateRequirementRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    if (_isGeneratingRequirements || _isRegeneratingRow) return;
    setState(() {
      _isRegeneratingRow = true;
      _regeneratingRowIndex = index;
    });

    try {
      final data = ProjectDataHelper.getData(context);
      final ctx = StringBuffer()
        ..writeln(
          ProjectDataHelper.buildFepContext(
            data,
            sectionLabel: 'Project Requirements',
          ),
        )
        ..writeln()
        ..writeln(
          'Discipline options: ${_RequirementRow.disciplineOptions.join(', ')}',
        )
        ..writeln(
          'Return a specific discipline option and avoid placeholder values.',
        );
      final ai = OpenAiServiceSecure();
      final reqs = await ai.generateRequirementsFromBusinessCase(
        ctx.toString(),
      );
      if (!mounted) return;

      final pickedIndex = reqs.isNotEmpty ? (index % reqs.length) : null;
      final picked = pickedIndex == null ? null : reqs[pickedIndex];
      final nextText = pickedIndex == null
          ? ''
          : (picked?['requirement'] ?? '').toString().trim();
      if (nextText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI returned no requirement text.')),
          );
        }
        return;
      }
      final row = _rows[index];
      final provider = ProjectDataHelper.getProvider(context);
      final fieldKey = 'fep_requirement_${row.number}_description';

      // Track history before regenerating
      if (row.descriptionController.text.trim().isNotEmpty) {
        provider.addFieldToHistory(
          fieldKey,
          row.descriptionController.text,
          isAiGenerated: true,
        );
      }

      row.aiUndoText = row.descriptionController.text;
      row.setDescriptionFromCode(nextText);
      final nextType = (picked?['requirementType'] ?? '').toString().trim();
      final nextDiscipline = (picked?['discipline'] ?? '').toString().trim();
      final nextRole = (picked?['role'] ?? '').toString().trim();
      final nextPerson = (picked?['person'] ?? '').toString().trim();
      final nextPhase = (picked?['phase'] ?? '').toString().trim();
      final nextSource = (picked?['requirementSource'] ?? '').toString().trim();

      if (nextType.isNotEmpty) {
        row.selectedType = _normalizeRequirementTypeSelection(nextType);
      }
      if (nextDiscipline.isNotEmpty) {
        row.selectedDiscipline = _normalizeDisciplineSelection(nextDiscipline);
      }
      if (nextRole.isNotEmpty) row.roleController.text = nextRole;
      if (nextPerson.isNotEmpty) {
        row.personController.text =
            _resolvePersonSelection(nextPerson, roleHint: nextRole);
      }
      row.selectedPhase = _normalizePhaseSelection(
        nextPhase.isEmpty ? row.selectedPhase : nextPhase,
      );
      if (nextSource.isNotEmpty) row.sourceController.text = nextSource;

      // Track new AI-generated content
      if (nextText.isNotEmpty) {
        provider.addFieldToHistory(
          fieldKey,
          nextText,
          isAiGenerated: true,
        );
      }

      _commitAutoSave(showSnack: false);
      // Persist so the regenerated version is what Firestore gets.
      await provider.saveToFirebase(checkpoint: 'fep_requirements');
      if (mounted) setState(() {}); // refresh undo enabled state
    } catch (e) {
      debugPrint('Row requirement regenerate failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to regenerate this requirement right now. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegeneratingRow = false;
          _regeneratingRowIndex = null;
        });
      }
    }
  }

  Future<void> _undoRequirementRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    final provider = ProjectDataHelper.getProvider(context);
    final fieldKey = 'fep_requirement_${row.number}_description';

    // Try provider's undo first, then fallback to local row-level undo.
    final data = provider.projectData;
    final previousValue = data.undoField(fieldKey);
    final previous = previousValue ?? row.manualUndoText ?? row.aiUndoText;

    if (previous == null || previous.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to undo for this requirement yet.'),
          ),
        );
      }
      return;
    }

    row.setDescriptionFromCode(previous);
    row.clearLocalUndoState();
    _commitAutoSave(showSnack: false);
    // Persist so the undone version is what Firestore gets.
    await provider.saveToFirebase(checkpoint: 'fep_requirements');
    if (mounted) setState(() {}); // refresh undo enabled state
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _mainContentScrollController.dispose();
    _requirementsHorizontalController.removeListener(_updateScrollHints);
    _requirementsVerticalController.removeListener(_updateScrollHints);
    _requirementsHorizontalController.dispose();
    _requirementsVerticalController.dispose();
    _notesController.removeListener(_handleNotesChanged);
    _notesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
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
            // Use the exact same sidebar style as PreferredSolutionAnalysisScreen
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Requirements'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Project Requirements',
                    ),
                  ),
                  const AdminEditToggle(),
                  Column(
                    children: [
                      FrontEndPlanningHeader(onExportPdf: _exportPdf),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _mainContentScrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _roundedField(
                                      controller: _notesController,
                                      hint: 'Input your notes here...',
                                      minLines: 3,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const EditableContentText(
                                                contentKey:
                                                    'fep_requirements_title',
                                                fallback:
                                                    'Project Requirements',
                                                category: 'front_end_planning',
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF111827)),
                                              ),
                                              const SizedBox(height: 6),
                                              const EditableContentText(
                                                contentKey:
                                                    'fep_requirements_subtitle',
                                                fallback:
                                                    'Identify actual needs, conditions, or capabilities that this project must meet to be considered successful',
                                                category: 'front_end_planning',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF6B7280),
                                                    height: 1.2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Page-level regenerate button
                                        PageRegenerateAllButton(
                                          onRegenerateAll: () async {
                                            final confirmed =
                                                await showRegenerateAllConfirmation(
                                                    context);
                                            if (confirmed && mounted) {
                                              await _generateRequirementsFromContext();
                                            }
                                          },
                                          isLoading: _isGeneratingRequirements,
                                          tooltip:
                                              'Regenerate all requirements',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            _buildImportCsvButton(),
                                            const SizedBox(width: 12),
                                            _buildDownloadTemplateButton(),
                                          ],
                                        ),
                                        _buildViewToggle(),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (_deletedRequirements.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _undoLastDeletedRequirement,
                                          icon: const Icon(Icons.undo, size: 16),
                                          label: const Text('Undo last delete'),
                                        ),
                                      ),
                                    if (_deletedRequirements.isNotEmpty)
                                      const SizedBox(height: 10),
                                    _buildRequirementsTable(context),
                                    const SizedBox(height: 16),
                                    _buildAddButton(),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 96, 24),
                              child: _buildDesktopFooter(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 112,
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

  Widget _buildDesktopFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton(
            onPressed: () => FrontEndPlanningNavigation.goToPrevious(
              context,
              'fep_requirements',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          const SizedBox(width: 16),
          const Expanded(child: SizedBox.shrink()),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Submit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Cards', Icons.view_agenda_outlined, !_isTableView),
          _toggleButton('Table', Icons.table_chart_outlined, _isTableView),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, IconData icon, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isTableView = label == 'Table'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06), blurRadius: 2)
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    active ? const Color(0xFFD97706) : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6B7280),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsTable(BuildContext context) {
    final hasAnyRowData = _rows.any((row) {
      return row.descriptionController.text.trim().isNotEmpty ||
          row.commentsController.text.trim().isNotEmpty ||
          row.roleController.text.trim().isNotEmpty ||
          row.personController.text.trim().isNotEmpty ||
          row.sourceController.text.trim().isNotEmpty ||
          (row.selectedDiscipline ?? '').trim().isNotEmpty ||
          (row.selectedType ?? '').trim().isNotEmpty;
    });

    if (_showInitialGenerationSpinner && !hasAnyRowData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Generating project requirements with AI...',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      );
    }

    if ((_initialGenerationError ?? '').isNotEmpty && !hasAnyRowData) {
      return _buildRequirementsEmptyState(
        context,
        message: _initialGenerationError!,
        actionLabel: 'Generate with AI',
        onAction: _isGeneratingRequirements
            ? null
            : () async {
                final generated = await _generateRequirementsFromContext();
                if (!mounted) return;
                setState(() {
                  _initialGenerationError =
                      generated ? null : _initialGenerationError;
                });
              },
      );
    }

    if (_rows.isEmpty) {
      return _buildRequirementsEmptyState(
        context,
        message: 'Add your first requirement to get started.',
        actionLabel: 'Add requirement',
        onAction: _addRequirementViaEditor,
      );
    }

    final showErrorBanner =
        (_initialGenerationError ?? '').trim().isNotEmpty && hasAnyRowData;

    if (_isTableView && _rows.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showErrorBanner)
            _buildGenerationErrorBanner(context,
                message: _initialGenerationError!),
          _buildTableView(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showErrorBanner)
          _buildGenerationErrorBanner(
            context,
            message: _initialGenerationError!,
          ),
        ..._rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isRowLoading =
              _isRegeneratingRow && _regeneratingRowIndex == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RequirementCard(
              row: row,
              index: index,
              isRegenerating: isRowLoading,
              onToggleExpanded: () {
                setState(() {
                  row.isExpanded = !row.isExpanded;
                });
              },
              onDelete: () => _deleteRow(index),
              onRegenerate: () => _regenerateRequirementRow(index),
              onUndo: () async => _undoRequirementRow(index),
              personOptions: _memberOptions,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTableView() {
    final headerStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF4B5563),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Scrollbar(
        controller: _requirementsHorizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _requirementsHorizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 100,
            ),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      _tableHeaderCell('#', 50, headerStyle),
                      _tableHeaderCell('Requirement', 300, headerStyle),
                      _tableHeaderCell('Type', 140, headerStyle),
                      _tableHeaderCell('Discipline', 140, headerStyle),
                      _tableHeaderCell('Role', 120, headerStyle),
                      _tableHeaderCell('Person', 120, headerStyle),
                      _tableHeaderCell('Phase', 100, headerStyle),
                      _tableHeaderCell('Source', 160, headerStyle),
                      _tableHeaderCell('Comments', 200, headerStyle),
                      _tableHeaderCell('Actions', 80, headerStyle),
                    ],
                  ),
                ),
                ..._rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return Container(
                    key: ValueKey('req_table_row_$index'),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: const Color(0xFFE5E7EB)),
                      ),
                      color:
                          index.isEven ? Colors.white : const Color(0xFFFAFBFC),
                    ),
                    child: Row(
                      children: [
                        _tableDataCell('${index + 1}', 50, center: true),
                        _tableDataCell(
                          row.descriptionController.text.trim().isEmpty
                              ? '—'
                              : row.descriptionController.text.trim(),
                          300,
                        ),
                        _tableDataCell(
                          row.selectedType ?? '—',
                          140,
                          center: true,
                        ),
                        _tableDataCell(
                          row.selectedDiscipline ?? '—',
                          140,
                          center: true,
                        ),
                        _tableDataCell(
                          row.roleController.text.trim().isEmpty
                              ? '—'
                              : row.roleController.text.trim(),
                          120,
                        ),
                        _tableDataCell(
                          row.personController.text.trim().isEmpty
                              ? '—'
                              : row.personController.text.trim(),
                          120,
                        ),
                        _tableDataCell(
                          row.selectedPhase ?? '—',
                          100,
                          center: true,
                        ),
                        _tableDataCell(
                          row.sourceController.text.trim().isEmpty
                              ? '—'
                              : row.sourceController.text.trim(),
                          160,
                        ),
                        _tableDataCell(
                          row.commentsController.text.trim().isEmpty
                              ? '—'
                              : row.commentsController.text.trim(),
                          200,
                        ),
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Color(0xFFD97706),
                                ),
                                tooltip: 'Edit',
                                onPressed: () => _openMobileRequirementEditor(
                                  context,
                                  index,
                                  row,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _deleteRow(index),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, double width, TextStyle style) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _tableDataCell(String text, double width, {bool center = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 12,
              color: text == '—'
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827)),
          textAlign: center ? TextAlign.center : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGenerationErrorBanner(
    BuildContext context, {
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: _isGeneratingRequirements
                ? null
                : _generateRequirementsFromContext,
            child: const Text('Retry'),
          ),
          IconButton(
            onPressed: () {
              setState(() => _initialGenerationError = null);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final projectName = projectData.projectName.trim().isEmpty
        ? 'Project Workspace'
        : projectData.projectName.trim();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.88,
        child: const SafeArea(
          child: InitiationLikeSidebar(activeItemLabel: 'Project Requirements'),
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
                    onPressed: () => FrontEndPlanningNavigation.goToPrevious(
                      context,
                      'fep_requirements',
                    ),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Expanded(
                    child: Text(
                      'Front End Planning',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    borderRadius: BorderRadius.circular(20),
                    child: const CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFFD97706),
                      child: Text(
                        'C',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _mainContentScrollController,
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROJECT WORKSPACE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INTERNAL NOTES',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 8),
                          VoiceTextField(
                            controller: _notesController,
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (_) =>
                                _scheduleAutoSave(showSnack: false),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'Add context or notes for these requirements...',
                              hintStyle: TextStyle(color: Color(0xFFB6BDC8)),
                            ),
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'REQUIREMENTS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_rows.length} Items',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_showInitialGenerationSpinner &&
                        _rows.every((row) =>
                            row.descriptionController.text.trim().isEmpty))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text(
                                'Generating requirements...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if ((_initialGenerationError ?? '').isNotEmpty &&
                        _rows.every((row) =>
                            row.descriptionController.text.trim().isEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Text(
                              _initialGenerationError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _isGeneratingRequirements
                                  ? null
                                  : () => _generateRequirementsFromContext(),
                              icon: const Icon(Icons.auto_awesome_rounded,
                                  size: 16),
                              label: const Text('Generate with AI'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ..._rows.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildMobileRequirementCard(
                                  context, entry.key, entry.value),
                            ),
                          ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _addRequirementViaEditor,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Requirement',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingRequirements
                          ? null
                          : _generateRequirementsFromContext,
                      icon: _isGeneratingRequirements
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text(
                        'AI Insights',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4B400),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Submit Requirements',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRequirementCard(
      BuildContext context, int index, _RequirementRow row) {
    final typeLabel = (row.selectedType ?? '').trim().isEmpty
        ? 'GENERAL'
        : (row.selectedType ?? '').trim().toUpperCase();
    final disciplineLabel = (row.selectedDiscipline ?? '').trim().isEmpty
        ? 'UNASSIGNED DISCIPLINE'
        : (row.selectedDiscipline ?? '').trim().toUpperCase();
    final phaseLabel = (row.selectedPhase ?? '').trim().isEmpty
        ? 'PHASE TBD'
        : (row.selectedPhase ?? '').trim().toUpperCase();
    final roleLabel = row.roleController.text.trim();
    final personLabel = row.personController.text.trim();
    final ownerLabel = personLabel.isNotEmpty
        ? personLabel
        : (roleLabel.isNotEmpty ? roleLabel : 'Role/Person not assigned');
    final sourceLabel = row.sourceController.text.trim();
    final title = row.descriptionController.text.trim().isEmpty
        ? 'Tap to add requirement'
        : row.descriptionController.text.trim();
    final commentsLabel = row.commentsController.text.trim().isEmpty
        ? 'No comments yet.'
        : row.commentsController.text.trim();

    return InkWell(
      onTap: () => _openMobileRequirementEditor(context, index, row),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    phaseLabel,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4338CA),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      _openMobileRequirementEditor(context, index, row),
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF9CA3AF)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disciplineLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Owner: $ownerLabel',
              style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 4),
            if (sourceLabel.isNotEmpty) ...[
              Text(
                'Source: $sourceLabel',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              commentsLabel,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMobileRequirementEditor(
      BuildContext context, int index, _RequirementRow row,
      {bool isNew = false}) async {
    final descriptionController =
        TextEditingController(text: row.descriptionController.text);
    final commentsController =
        TextEditingController(text: row.commentsController.text);
    final roleController = TextEditingController(text: row.roleController.text);
    final personController =
        TextEditingController(text: row.personController.text);
    final sourceController =
        TextEditingController(text: row.sourceController.text);
    String? selectedType = _normalizeRequirementTypeSelection(row.selectedType);
    String? selectedDiscipline =
        _normalizeDisciplineSelection(row.selectedDiscipline);
    String? selectedPhase = _normalizePhaseSelection(row.selectedPhase);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final inset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, inset + 14),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'Add Requirement' : 'Edit Requirement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Requirement',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        hint: const Text('Requirement Type'),
                        isExpanded: true,
                        items: const [
                          'Technical',
                          'Regulatory',
                          'Functional',
                          'Operational',
                          'Non-Functional',
                          'Safety',
                          'Sustainability',
                          'Business',
                          'Stakeholder',
                          'Solutions',
                          'Transitional',
                          'Other'
                        ]
                            .map((value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setLocalState(() => selectedType = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDiscipline,
                        hint: const Text('Discipline'),
                        isExpanded: true,
                        items: _RequirementRow.disciplineOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocalState(() => selectedDiscipline = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPhase,
                        hint: const Text('Implementation Phase'),
                        isExpanded: true,
                        items: _RequirementRow.phaseOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocalState(() => selectedPhase = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  VoiceTextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PersonDropdownField(
                    value: personController.text,
                    options: _memberOptions,
                    hint: 'Person',
                    dense: false,
                    onChanged: (value) {
                      personController.text = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  VoiceTextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Requirement Source',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  VoiceTextField(
                    controller: commentsController,
                    decoration: const InputDecoration(
                      labelText: 'Comments and Requirement Source Links',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (isNew || (index >= 0 && index < _rows.length)) {
                            if (isNew && !_rows.contains(row)) {
                              setState(() => _rows.add(row));
                            }
                            setState(() {
                              final previousDescription =
                                  row.descriptionController.text;
                              final nextDescription =
                                  descriptionController.text;
                              if (previousDescription.trim().isNotEmpty &&
                                  previousDescription != nextDescription) {
                                row.manualUndoText = previousDescription;
                              }
                              row.setDescriptionFromCode(nextDescription);
                              row.commentsController.text =
                                  commentsController.text;
                              row.roleController.text = roleController.text;
                              row.personController.text =
                                  _resolvePersonSelection(
                                personController.text,
                                roleHint: roleController.text,
                              );
                              row.sourceController.text = sourceController.text;
                              row.selectedType =
                                  _normalizeRequirementTypeSelection(
                                selectedType,
                              );
                              row.selectedDiscipline =
                                  _normalizeDisciplineSelection(
                                selectedDiscipline,
                              );
                              row.selectedPhase =
                                  _normalizePhaseSelection(selectedPhase);
                            });
                            _scheduleAutoSave(showSnack: false);
                          }
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    descriptionController.dispose();
    commentsController.dispose();
    roleController.dispose();
    personController.dispose();
    sourceController.dispose();
  }

  Future<void> _deleteRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final requirementTitle = _rows[index].descriptionController.text.trim();
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Requirement?',
      itemLabel: requirementTitle.isEmpty
          ? 'Requirement ${index + 1}'
          : requirementTitle,
    );
    if (!confirmed) return;

    final deleted = _rows[index];
    setState(() {
      _deletedRequirements.add(deleted);
      _rows.removeAt(index);
      // Renumber remaining rows
      for (int i = 0; i < _rows.length; i++) {
        _rows[i].number = i + 1;
      }
    });

    // Update provider state and Firebase
    _commitAutoSave(showSnack: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Requirement "${requirementTitle.isEmpty ? 'Requirement ${index + 1}' : requirementTitle}" deleted successfully.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: _undoLastDeletedRequirement,
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF111827),
        ),
      );
    }
  }

  Future<void> _undoLastDeletedRequirement() async {
    if (_deletedRequirements.isEmpty) return;
    final restored = _deletedRequirements.removeLast();
    setState(() {
      _rows.add(restored);
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].number = i + 1;
      }
    });
    _commitAutoSave(showSnack: false);
  }

  Widget _th(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: EditableContentText(
          contentKey:
              'fep_req_header_${text.toLowerCase().replaceAll(' ', '_')}',
          fallback: text,
          category: 'front_end_planning',
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<CsvColumnSpec> get _csvColumns => [
        CsvColumnSpec(
            key: 'description',
            label: 'Requirement',
            required: true,
            sampleValue: 'The system shall support user authentication'),
        CsvColumnSpec(
            key: 'type',
            label: 'Type',
            allowedValues: _RequirementRow.requirementTypeOptions,
            defaultValue: 'Functional',
            sampleValue: 'Functional'),
        CsvColumnSpec(
            key: 'discipline',
            label: 'Discipline',
            allowedValues: _RequirementRow.disciplineOptions,
            defaultValue: 'IT',
            sampleValue: 'IT'),
        CsvColumnSpec(
            key: 'role', label: 'Role', sampleValue: 'Requirements Lead'),
        CsvColumnSpec(key: 'person', label: 'Person', sampleValue: 'John Doe'),
        CsvColumnSpec(
            key: 'phase',
            label: 'Phase',
            allowedValues: _RequirementRow.phaseOptions,
            defaultValue: 'Planning',
            sampleValue: 'Planning'),
        CsvColumnSpec(
            key: 'source',
            label: 'Source',
            sampleValue: 'Stakeholder interview'),
        CsvColumnSpec(
            key: 'comments', label: 'Comments', sampleValue: 'High priority'),
      ];

  void _downloadTemplate() {
    final template = CsvImportHelper.generateTemplate(_csvColumns);
    final filename = CsvImportHelper.templateFilename('Project Requirements');
    final bytes = utf8.encode(template);
    dl.downloadFile(bytes, filename, mimeType: 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV template downloaded!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildImportCsvButton() {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () async {
          final rows = await showCsvImportDialog(
            context,
            tableTitle: 'Project Requirements',
            columns: _csvColumns,
          );
          if (rows == null || !mounted) return;
          setState(() {
            for (final row in rows) {
              final newRow = _createRow(_rows.length + 1, expanded: false);
              newRow.descriptionController.text = row['description'] ?? '';
              newRow.selectedType =
                  _RequirementRow.requirementTypeOptions.contains(row['type'])
                      ? row['type']
                      : 'Functional';
              newRow.selectedDiscipline =
                  _RequirementRow.disciplineOptions.contains(row['discipline'])
                      ? row['discipline']
                      : 'IT';
              newRow.selectedPhase =
                  _RequirementRow.phaseOptions.contains(row['phase'])
                      ? row['phase']
                      : 'Planning';
              newRow.roleController.text = row['role'] ?? '';
              newRow.personController.text = row['person'] ?? '';
              newRow.sourceController.text = row['source'] ?? '';
              newRow.commentsController.text = row['comments'] ?? '';
              _rows.add(newRow);
            }
          });
          _scheduleAutoSave(showSnack: false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${rows.length} requirements imported from CSV'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: const Text('Import CSV',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFD97706),
          side: const BorderSide(color: Color(0xFFFDE68A)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDownloadTemplateButton() {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _downloadTemplate,
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Template',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFD97706),
          side: const BorderSide(color: Color(0xFFFDE68A)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: _addRequirementViaEditor,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF2F4F7),
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        child: const Text('Add requirement',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _addRequirementViaEditor() {
    final newRow = _createRow(_rows.length + 1, expanded: true);
    _openMobileRequirementEditor(context, _rows.length, newRow, isNew: true);
  }

  Widget _buildRequirementsEmptyState(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined,
              size: 34, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF111827),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() async {
    final continueAnyway = await showProceedWithoutReviewDialog(
      context,
      title: 'Confirm before submitting requirements',
      message:
          'You are about to continue to the next step. You can proceed now and return later to refine details, or cancel and review first.',
    );
    if (!continueAnyway) return;

    final requirementItems = _buildRequirementItems();
    if (requirementItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one requirement before submitting.'),
        ),
      );
      return;
    }

    final missingAssignmentRows = <int>[];
    final missingPhaseRows = <int>[];
    for (var i = 0; i < requirementItems.length; i++) {
      final item = requirementItems[i];
      final hasAssignment = item.discipline.trim().isNotEmpty ||
          item.role.trim().isNotEmpty ||
          item.person.trim().isNotEmpty;
      if (!hasAssignment) {
        missingAssignmentRows.add(i + 1);
      }
      if (item.phase.trim().isEmpty) {
        missingPhaseRows.add(i + 1);
      }
    }

    if (missingAssignmentRows.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assignment Guidance'),
          content: Text(
            'Discipline, Role, and Person help route each requirement to the right owners. Rows ${missingAssignmentRows.join(', ')} do not have any assignment yet.\n\nYou can continue now and complete those assignments later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Review Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );
    }

    if (missingPhaseRows.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phase Guidance'),
          content: Text(
            'Rows ${missingPhaseRows.join(', ')} do not have an implementation phase yet. This is recommended for sequencing, but it should not block progression.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Review Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Requirement Coverage'),
        content: const Text(
          'Please confirm that all applicable project requirements, particularly regulatory, functional, and operational, are fully captured here, as this will serve as the foundation for the defined project scope.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm and Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final requirementsText = requirementItems
        .map((item) => item.description.trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
    final requirementsNotes = _notesController.text.trim();

    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'fep_requirements',
      saveInBackground: true,
      nextScreenBuilder: () => const FrontEndPlanningRisksScreen(),
      dataUpdater: (data) => data.copyWith(
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          requirements: requirementsText,
          requirementsNotes: requirementsNotes,
          requirementItems: requirementItems,
        ),
      ),
    );
  }

  List<RequirementItem> _buildRequirementItems() {
    return _rows
        .map((row) => RequirementItem(
              description: row.descriptionController.text.trim(),
              requirementType: row.selectedType ?? '',
              discipline: row.selectedDiscipline ?? '',
              role: row.roleController.text.trim(),
              person: row.personController.text.trim(),
              phase: row.selectedPhase ?? '',
              requirementSource: row.sourceController.text.trim(),
              comments: row.commentsController.text.trim(),
            ))
        .where((item) =>
            item.description.isNotEmpty ||
            item.requirementType.isNotEmpty ||
            item.discipline.isNotEmpty ||
            item.role.isNotEmpty ||
            item.person.isNotEmpty ||
            item.phase.isNotEmpty ||
            item.requirementSource.isNotEmpty ||
            item.comments.isNotEmpty)
        .toList();
  }

  String _normalizePhaseSelection(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return 'Planning';

    for (final option in _RequirementRow.phaseOptions) {
      if (option.toLowerCase() == value.toLowerCase()) {
        return option;
      }
    }

    final normalized = value.toLowerCase();
    if (normalized.startsWith('init')) return 'Initiation';
    if (normalized.startsWith('plan')) return 'Planning';
    if (normalized.startsWith('des')) return 'Design';
    if (normalized.startsWith('exec') || normalized.contains('implement')) {
      return 'Execution';
    }
    if (normalized.startsWith('launch') ||
        normalized.contains('go live') ||
        normalized.contains('golive')) {
      return 'Launch';
    }
    if (normalized == 'all phases' || normalized == 'all phase') return 'ALL';
    return 'Planning';
  }

  String? _normalizeRequirementTypeSelection(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;

    for (final option in _RequirementRow.requirementTypeOptions) {
      if (option.toLowerCase() == value.toLowerCase()) {
        return option;
      }
    }

    final normalized = value.toLowerCase();
    if (normalized.contains('functional') &&
        !normalized.contains('non-functional')) {
      return 'Functional';
    }
    if (normalized.contains('non') && normalized.contains('functional')) {
      return 'Non-Functional';
    }
    if (normalized.contains('technical') || normalized == 'tech') {
      return 'Technical';
    }
    if (normalized.contains('regulat') || normalized.contains('compliance')) {
      return 'Regulatory';
    }
    if (normalized.contains('operat')) {
      return 'Operational';
    }
    if (normalized.contains('safe')) {
      return 'Safety';
    }
    if (normalized.contains('sustain')) {
      return 'Sustainability';
    }
    if (normalized.contains('business')) {
      return 'Business';
    }
    if (normalized.contains('stakeholder')) {
      return 'Stakeholder';
    }
    if (normalized.contains('solution')) {
      return 'Solutions';
    }
    if (normalized.contains('transition')) {
      return 'Transitional';
    }
    if (normalized == 'other' || normalized == 'general') {
      return 'Other';
    }

    return null;
  }

  String? _normalizeDisciplineSelection(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;

    for (final option in _RequirementRow.disciplineOptions) {
      if (option.toLowerCase() == value.toLowerCase()) {
        return option;
      }
    }

    final normalized = value.toLowerCase();
    if (normalized == 'discipline') return 'Other';
    if (normalized.contains('arch')) return 'Architecture';
    if (normalized.contains('civil')) return 'Civil';
    if (normalized.contains('elect')) return 'Electrical';
    if (normalized.contains('mech')) return 'Mechanical';
    if (normalized == 'it' || normalized.contains('information technology')) {
      return 'IT';
    }
    if (normalized.contains('operat')) return 'Operations';
    if (normalized.contains('safe')) return 'Safety';
    if (normalized.contains('secur')) return 'Security';
    if (normalized.contains('procure')) return 'Procurement';
    if (normalized.contains('commerc')) return 'Commercial';
    if (normalized.contains('qualit')) return 'Quality';
    if (normalized.contains('regulat') || normalized.contains('compliance')) {
      return 'Regulatory';
    }
    if (normalized.contains('program') ||
        normalized.contains('project management')) {
      return 'Program Management';
    }

    var best = 'Other';
    var bestScore = 0.0;
    for (final option in _RequirementRow.disciplineOptions) {
      final score = _textSimilarity(normalized, option.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        best = option;
      }
    }
    return bestScore >= 0.45 ? best : 'Other';
  }

  String _resolvePersonSelection(String rawValue, {String roleHint = ''}) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return _matchMemberByRole(roleHint)?.displayLabel ?? '';
    }

    _AssignableMember? exactMatch;
    _AssignableMember? fuzzyMatch;
    var fuzzyScore = 0.0;
    final normalizedValue = value.toLowerCase();
    for (final member in _memberOptions) {
      final memberLabel = member.displayLabel.toLowerCase();
      final memberEmail = member.email.toLowerCase();
      if (memberLabel == normalizedValue || memberEmail == normalizedValue) {
        exactMatch = member;
        break;
      }
      if (memberLabel.contains(normalizedValue) ||
          normalizedValue.contains(memberLabel) ||
          (memberEmail.isNotEmpty &&
              (memberEmail.contains(normalizedValue) ||
                  normalizedValue.contains(memberEmail)))) {
        fuzzyMatch = member;
        fuzzyScore = 1.0;
        continue;
      }
      final score = _textSimilarity(normalizedValue, memberLabel);
      if (score > fuzzyScore) {
        fuzzyScore = score;
        fuzzyMatch = member;
      }
    }

    if (exactMatch != null) return exactMatch.displayLabel;
    if (fuzzyMatch != null && fuzzyScore >= 0.5) return fuzzyMatch.displayLabel;

    final roleMatch = _matchMemberByRole(roleHint);
    if (roleMatch != null) return roleMatch.displayLabel;
    return value;
  }

  _AssignableMember? _matchMemberByRole(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role.isEmpty) return null;
    for (final member in _memberOptions) {
      final memberRole = member.role.trim().toLowerCase();
      if (memberRole.isEmpty) continue;
      if (memberRole == role ||
          memberRole.contains(role) ||
          role.contains(memberRole)) {
        return member;
      }
    }
    return null;
  }

  double _textSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final tokensA = a
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    final tokensB = b
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0;
    final intersection = tokensA.intersection(tokensB).length.toDouble();
    final union = tokensA.union(tokensB).length.toDouble();
    if (union == 0) return 0;
    return intersection / union;
  }

  Future<String> _resolveCurrentUserRoleForRequirementsSubmit() async {
    var resolvedRole = 'Member';

    try {
      final user = FirebaseAuth.instance.currentUser;
      final provider = ProjectDataHelper.getProvider(context);
      final data = provider.projectData;
      final email = user?.email?.trim().toLowerCase() ?? '';
      final uid = user?.uid ?? '';
      final displayName =
          FirebaseAuthService.displayNameOrEmail(fallback: '').trim();

      if (UserService.isAdminEmail(email)) {
        resolvedRole = 'Owner';
      }

      final projectId = data.projectId?.trim() ?? '';
      if (projectId.isNotEmpty && uid.isNotEmpty) {
        final project = await ProjectService.getProjectById(projectId);
        if (project != null) {
          final ownerEmail = project.ownerEmail.trim().toLowerCase();
          if (project.ownerId == uid ||
              (email.isNotEmpty && ownerEmail == email)) {
            resolvedRole = 'Owner';
          }
        }
      }

      if (!_isRoleAuthorizedForRequirementSubmit(resolvedRole)) {
        for (final member in data.teamMembers) {
          final memberEmail = member.email.trim().toLowerCase();
          final memberName = member.name.trim().toLowerCase();
          final role = member.role.trim();
          final matchesByEmail = email.isNotEmpty &&
              memberEmail.isNotEmpty &&
              memberEmail == email;
          final matchesByName = displayName.isNotEmpty &&
              memberName.isNotEmpty &&
              (memberName == displayName.toLowerCase() ||
                  memberName.contains(displayName.toLowerCase()) ||
                  displayName.toLowerCase().contains(memberName));
          if ((matchesByEmail || matchesByName) && role.isNotEmpty) {
            resolvedRole = role;
            break;
          }
        }
      }

      if (!_isRoleAuthorizedForRequirementSubmit(resolvedRole)) {
        final pmName = data.charterProjectManagerName.trim();
        if (_matchesIdentity(pmName, displayName, email)) {
          resolvedRole = 'Project Manager';
        }
      }
    } catch (e) {
      debugPrint('Failed to resolve submitter role for requirements: $e');
    }

    return resolvedRole;
  }

  bool _matchesIdentity(String candidate, String displayName, String email) {
    final normalizedCandidate = candidate.trim().toLowerCase();
    if (normalizedCandidate.isEmpty) return false;

    final normalizedDisplay = displayName.trim().toLowerCase();
    final emailLocal = email.contains('@')
        ? email.split('@').first.trim().toLowerCase()
        : email.trim().toLowerCase();

    if (normalizedDisplay.isNotEmpty) {
      if (normalizedCandidate == normalizedDisplay) return true;
      if (normalizedDisplay.contains(normalizedCandidate) ||
          normalizedCandidate.contains(normalizedDisplay)) {
        return true;
      }
    }

    if (emailLocal.isNotEmpty) {
      if (normalizedCandidate == emailLocal) return true;
      if (emailLocal.contains(normalizedCandidate) ||
          normalizedCandidate.contains(emailLocal)) {
        return true;
      }
    }

    return false;
  }

  String _normalizeRole(String role) {
    final lower = role.trim().toLowerCase();
    if (lower.contains('project manager')) return 'project manager';
    if (lower.contains('technical manager')) return 'technical manager';
    if (lower.contains('founder')) return 'owner';
    if (lower.contains('owner')) return 'owner';
    return lower;
  }

  bool _isRoleAuthorizedForRequirementSubmit(String role) {
    return _authorizedRequirementSubmitRoles.contains(_normalizeRole(role));
  }

  void _handleNotesChanged() {
    _scheduleAutoSave();
  }

  void _scheduleAutoSave({bool showSnack = true}) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _commitAutoSave(showSnack: showSnack);
    });
  }

  void _commitAutoSave({bool showSnack = true}) {
    if (!mounted) return;
    final items = _buildRequirementItems();
    final requirementsText = items
        .map((item) => item.description.trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
    final requirementsNotes = _notesController.text.trim();
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField(
      (data) => data.copyWith(
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          requirements: requirementsText,
          requirementsNotes: requirementsNotes,
          requirementItems: items,
        ),
      ),
    );
    provider.saveToFirebase(checkpoint: 'fep_requirements');

    if (showSnack) {
      _showAutoSaveSnack();
    }
  }

  void _showAutoSaveSnack() {
    final now = DateTime.now();
    if (_lastAutoSaveSnackAt != null &&
        now.difference(_lastAutoSaveSnackAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastAutoSaveSnackAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  void _replaceRowsSafely(List<_RequirementRow> nextRows) {
    final previousRows = List<_RequirementRow>.from(_rows);
    if (!mounted) {
      for (final row in previousRows) {
        row.dispose();
      }
      for (final row in nextRows) {
        row.dispose();
      }
      return;
    }
    setState(() {
      _rows
        ..clear()
        ..addAll(nextRows);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in previousRows) {
        row.dispose();
      }
    });
  }
}

class _AssignableMember {
  const _AssignableMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.source,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String source;

  String get displayLabel {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Unknown member';
  }

  String get subtitle {
    final segments = <String>[];
    if (email.trim().isNotEmpty) {
      segments.add(email.trim());
    }
    if (role.trim().isNotEmpty) {
      segments.add(role.trim());
    }
    segments.add(source);
    return segments.join(' · ');
  }
}

class _RequirementRow {
  static const List<String> requirementTypeOptions = [
    'Technical',
    'Regulatory',
    'Functional',
    'Operational',
    'Non-Functional',
    'Safety',
    'Sustainability',
    'Business',
    'Stakeholder',
    'Solutions',
    'Transitional',
    'Other',
  ];

  static const List<String> disciplineOptions = [
    'Architecture',
    'Civil',
    'Electrical',
    'Mechanical',
    'IT',
    'Operations',
    'Safety',
    'Security',
    'Procurement',
    'Commercial',
    'Quality',
    'Regulatory',
    'Program Management',
    'Other',
  ];

  static const List<String> phaseOptions = [
    'Initiation',
    'Planning',
    'Design',
    'Execution',
    'Launch',
    'ALL',
  ];

  _RequirementRow({
    required this.number,
    this.onChanged,
    bool isExpanded = false,
  })  : descriptionController = TextEditingController(),
        commentsController = TextEditingController(),
        roleController = TextEditingController(),
        personController = TextEditingController(),
        sourceController = TextEditingController(),
        descriptionFocusNode = FocusNode(),
        isExpanded = isExpanded {
    descriptionFocusNode.addListener(_handleDescriptionFocusChange);
  }

  int number;

  final TextEditingController descriptionController;
  final TextEditingController commentsController;
  final TextEditingController roleController;
  final TextEditingController personController;
  final TextEditingController sourceController;
  final FocusNode descriptionFocusNode;
  bool isExpanded;
  String? selectedType;
  String? selectedDiscipline;
  String? selectedPhase = 'Planning';
  final VoidCallback? onChanged;
  String? aiUndoText;
  String? manualUndoText;
  String _descriptionValueAtFocusStart = '';
  String _focusSessionUndoCandidate = '';

  void _handleDescriptionFocusChange() {
    if (descriptionFocusNode.hasFocus) {
      _descriptionValueAtFocusStart = descriptionController.text;
      _focusSessionUndoCandidate = descriptionController.text;
      return;
    }

    final before = _descriptionValueAtFocusStart.trim();
    final after = descriptionController.text.trim();
    if (after.isEmpty && _focusSessionUndoCandidate.trim().isNotEmpty) {
      manualUndoText = _focusSessionUndoCandidate;
    } else if (before.isNotEmpty && before != after) {
      manualUndoText = _descriptionValueAtFocusStart;
    }
    _descriptionValueAtFocusStart = descriptionController.text;
    _focusSessionUndoCandidate = descriptionController.text;
  }

  void handleDescriptionChanged(String value) {
    if (value.trim().isNotEmpty &&
        value.trim().length >= _focusSessionUndoCandidate.trim().length) {
      _focusSessionUndoCandidate = value;
    }
    onChanged?.call();
  }

  void setDescriptionFromCode(String value) {
    descriptionController.text = value;
    _descriptionValueAtFocusStart = value;
    _focusSessionUndoCandidate = value;
  }

  void clearLocalUndoState() {
    aiUndoText = null;
    manualUndoText = null;
    _descriptionValueAtFocusStart = descriptionController.text;
    _focusSessionUndoCandidate = descriptionController.text;
  }

  String get summaryDescription {
    final value = descriptionController.text.trim();
    if (value.isEmpty) return 'Tap to add a requirement description.';
    return value;
  }

  String get summaryType {
    final value = selectedType?.trim() ?? '';
    return value.isEmpty ? 'Unclassified' : value;
  }

  String get summaryDiscipline {
    final value = selectedDiscipline?.trim() ?? '';
    return value.isEmpty ? 'Unassigned' : value;
  }

  String get summaryOwner {
    final person = personController.text.trim();
    if (person.isNotEmpty) return person;
    final role = roleController.text.trim();
    if (role.isNotEmpty) return role;
    return 'Role not assigned';
  }

  String get summarySource {
    return sourceController.text.trim();
  }

  void dispose() {
    descriptionFocusNode.removeListener(_handleDescriptionFocusChange);
    descriptionFocusNode.dispose();
    descriptionController.dispose();
    commentsController.dispose();
    roleController.dispose();
    personController.dispose();
    sourceController.dispose();
  }

  TableRow buildRow(
    BuildContext context,
    int index,
    Future<void> Function(int) onDelete, {
    required List<_AssignableMember> personOptions,
    required bool isRegenerating,
    required VoidCallback onRegenerate,
    required Future<void> Function() onUndo,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text('$number',
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating action row above the field
              Container(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Regenerate (AI)',
                      child: IconButton(
                        onPressed: isRegenerating ? null : onRegenerate,
                        icon: isRegenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh,
                                size: 18, color: Color(0xFFD97706)),
                        padding: const EdgeInsets.all(6),
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        splashRadius: 18,
                      ),
                    ),
                    Tooltip(
                      message: 'Undo last requirement change',
                      child: IconButton(
                        onPressed: onUndo,
                        icon: const Icon(
                          Icons.undo,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        splashRadius: 18,
                      ),
                    ),
                  ],
                ),
              ),
              // Text field
              VoiceTextField(
                controller: descriptionController,
                focusNode: descriptionFocusNode,
                minLines: 2,
                maxLines: null,
                onChanged: handleDescriptionChanged,
                decoration: const InputDecoration(
                  hintText: 'Requirement description',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _TypeDropdown(
            value: selectedType,
            onChanged: (v) {
              selectedType = v;
              onChanged?.call();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _DisciplineDropdown(
            value: selectedDiscipline,
            onChanged: (v) {
              selectedDiscipline = v;
              onChanged?.call();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: VoiceTextField(
            controller: roleController,
            maxLines: 1,
            onChanged: (_) => onChanged?.call(),
            decoration: const InputDecoration(
              hintText: 'Role',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _PersonDropdownField(
            value: personController.text,
            options: personOptions,
            hint: 'Person',
            onChanged: (value) {
              personController.text = value;
              onChanged?.call();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _PhaseDropdown(
            value: selectedPhase,
            onChanged: (v) {
              selectedPhase = v;
              onChanged?.call();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: VoiceTextField(
            controller: sourceController,
            maxLines: 1,
            onChanged: (_) => onChanged?.call(),
            decoration: const InputDecoration(
              hintText: 'Requirement source',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: VoiceTextField(
            controller: commentsController,
            minLines: 2,
            maxLines: null,
            onChanged: (_) => onChanged?.call(),
            decoration: const InputDecoration(
              hintText: 'Comments / source links',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Color(0xFFEF4444)),
            onPressed: () => onDelete(index),
            tooltip: 'Delete requirement',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.row,
    required this.index,
    required this.isRegenerating,
    required this.onToggleExpanded,
    required this.onDelete,
    required this.onRegenerate,
    required this.onUndo,
    required this.personOptions,
  });

  final _RequirementRow row;
  final int index;
  final bool isRegenerating;
  final VoidCallback onToggleExpanded;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final Future<void> Function() onUndo;
  final List<_AssignableMember> personOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${row.number}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.summaryDescription,
                              maxLines: row.isExpanded ? null : 2,
                              overflow: row.isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RequirementSummaryChip(
                                  label: row.summaryType,
                                  backgroundColor: const Color(0xFFECFDF5),
                                  textColor: const Color(0xFF047857),
                                ),
                                _RequirementSummaryChip(
                                  label: row.summaryDiscipline,
                                  backgroundColor: const Color(0xFFFFF7E6),
                                  textColor: const Color(0xFFD97706),
                                ),
                                _RequirementSummaryChip(
                                  label: row.summaryOwner,
                                  backgroundColor: const Color(0xFFFFF7ED),
                                  textColor: const Color(0xFFC2410C),
                                  icon: Icons.person_outline_rounded,
                                ),
                                if (row.summarySource.isNotEmpty)
                                  _RequirementSummaryChip(
                                    label: row.summarySource,
                                    backgroundColor: Colors.white,
                                    textColor: const Color(0xFF475569),
                                    icon: Icons.link_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          IconButton(
                            onPressed: isRegenerating ? null : onRegenerate,
                            tooltip: 'Regenerate requirement',
                            icon: isRegenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFD97706),
                                  ),
                          ),
                          IconButton(
                            onPressed: onUndo,
                            tooltip: 'Undo last requirement change',
                            icon: const Icon(
                              Icons.undo_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          IconButton(
                            onPressed: onDelete,
                            tooltip: 'Delete requirement',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        row.isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: row.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _RequirementFieldLabel('Requirement description'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: VoiceTextField(
                      controller: row.descriptionController,
                      focusNode: row.descriptionFocusNode,
                      minLines: 3,
                      maxLines: null,
                      onChanged: row.handleDescriptionChanged,
                      decoration: const InputDecoration(
                        hintText: 'Describe the requirement',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _RequirementLabeledControl(
                          label: 'Requirement type',
                          child: _TypeDropdown(
                            value: row.selectedType,
                            onChanged: (value) {
                              row.selectedType = value;
                              row.onChanged?.call();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RequirementLabeledControl(
                          label: 'Discipline',
                          child: _DisciplineDropdown(
                            value: row.selectedDiscipline,
                            onChanged: (value) {
                              row.selectedDiscipline = value;
                              row.onChanged?.call();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _RequirementTextFieldBlock(
                          label: 'Role',
                          controller: row.roleController,
                          hintText: 'Project role',
                          onChanged: (_) => row.onChanged?.call(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RequirementLabeledControl(
                          label: 'Person',
                          child: _PersonDropdownField(
                            value: row.personController.text,
                            options: personOptions,
                            hint: 'Select person',
                            dense: false,
                            onChanged: (value) {
                              row.personController.text = value;
                              row.onChanged?.call();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _RequirementLabeledControl(
                          label: 'Phase',
                          child: _PhaseDropdown(
                            value: row.selectedPhase,
                            onChanged: (value) {
                              row.selectedPhase = value;
                              row.onChanged?.call();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RequirementTextFieldBlock(
                          label: 'Requirement source',
                          controller: row.sourceController,
                          hintText: 'Contract, brief, regulation, workshop...',
                          onChanged: (_) => row.onChanged?.call(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _RequirementTextFieldBlock(
                    label: 'Comments / source links',
                    controller: row.commentsController,
                    hintText: 'Additional notes, assumptions, or links',
                    minLines: 2,
                    onChanged: (_) => row.onChanged?.call(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementSummaryChip extends StatelessWidget {
  const _RequirementSummaryChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementFieldLabel extends StatelessWidget {
  const _RequirementFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475569),
      ),
    );
  }
}

class _RequirementLabeledControl extends StatelessWidget {
  const _RequirementLabeledControl({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementFieldLabel(label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RequirementTextFieldBlock extends StatelessWidget {
  const _RequirementTextFieldBlock({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.minLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: VoiceTextField(
            controller: controller,
            minLines: minLines,
            maxLines: minLines == 1 ? 1 : null,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeDropdown extends StatefulWidget {
  const _TypeDropdown({this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_TypeDropdown> createState() => _TypeDropdownState();
}

class _TypeDropdownState extends State<_TypeDropdown> {
  late String? _value = _coerceValue(widget.value);

  String? _coerceValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _RequirementRow.requirementTypeOptions.contains(value)
        ? value
        : null;
  }

  @override
  void didUpdateWidget(covariant _TypeDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = _coerceValue(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _value,
          hint: const Text('Select...',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280), size: 20),
          isExpanded: true,
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged(v);
          },
          items: _RequirementRow.requirementTypeOptions
              .map((e) => DropdownMenuItem<String?>(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _DisciplineDropdown extends StatefulWidget {
  const _DisciplineDropdown({this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_DisciplineDropdown> createState() => _DisciplineDropdownState();
}

class _DisciplineDropdownState extends State<_DisciplineDropdown> {
  late String? _value = _coerceValue(widget.value);

  String? _coerceValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _RequirementRow.disciplineOptions.contains(value) ? value : null;
  }

  @override
  void didUpdateWidget(covariant _DisciplineDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = _coerceValue(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _value,
          hint: const Text('Discipline',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280), size: 20),
          isExpanded: true,
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged(v);
          },
          items: _RequirementRow.disciplineOptions
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PhaseDropdown extends StatefulWidget {
  const _PhaseDropdown({this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_PhaseDropdown> createState() => _PhaseDropdownState();
}

class _PhaseDropdownState extends State<_PhaseDropdown> {
  late String? _value = _coerceValue(widget.value);

  String? _coerceValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _RequirementRow.phaseOptions.contains(value) ? value : null;
  }

  @override
  void didUpdateWidget(covariant _PhaseDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = _coerceValue(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _value,
          hint: const Text('Phase',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280), size: 20),
          isExpanded: true,
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged(v);
          },
          items: _RequirementRow.phaseOptions
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PersonDropdownField extends StatelessWidget {
  const _PersonDropdownField({
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
    this.dense = true,
  });

  final String value;
  final List<_AssignableMember> options;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final noMembers = options.isEmpty;

    return InkWell(
      onTap: noMembers
          ? null
          : () async {
              final selected = await showDialog<_AssignableMember>(
                context: context,
                builder: (dialogContext) => _MemberPickerDialog(
                  options: options,
                  initialQuery: value,
                ),
              );
              if (selected != null) {
                onChanged(selected.displayLabel);
              }
            },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: dense ? 40 : null,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: dense ? 0 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                noMembers
                    ? 'No members available'
                    : (hasValue ? value.trim() : hint),
                style: TextStyle(
                  fontSize: 14,
                  color: noMembers
                      ? const Color(0xFF9CA3AF)
                      : (hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search_rounded,
              size: 18,
              color:
                  noMembers ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPickerDialog extends StatefulWidget {
  const _MemberPickerDialog({
    required this.options,
    required this.initialQuery,
  });

  final List<_AssignableMember> options;
  final String initialQuery;

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_AssignableMember> _filteredMembers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options.where((member) {
      final name = member.name.toLowerCase();
      final email = member.email.toLowerCase();
      final role = member.role.toLowerCase();
      final source = member.source.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          source.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers();
    final grouped = <String, List<_AssignableMember>>{};
    for (final member in filtered) {
      grouped
          .putIfAbsent(member.source, () => <_AssignableMember>[])
          .add(member);
    }

    return AlertDialog(
      title: const Text('Select Person'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            VoiceTextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search project team or company members...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No members available',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView(
                      children: grouped.entries.map((entry) {
                        final source = entry.key;
                        final members = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                              child: Text(
                                source,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            ...members.map(
                              (member) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFFFF7E6),
                                  child: Text(
                                    member.displayLabel[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  member.displayLabel,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  member.subtitle,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => Navigator.pop(context, member),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
      ],
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
