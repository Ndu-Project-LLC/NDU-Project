import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/form_validation_engine.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/utils/front_end_planning_navigation.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:intl/intl.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

/// Front End Planning – Milestone screen
/// Allows users to define project start date, key milestones, and end date.
class FrontEndPlanningMilestoneScreen extends StatefulWidget {
  const FrontEndPlanningMilestoneScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FrontEndPlanningMilestoneScreen(),
      ),
    );
  }

  @override
  State<FrontEndPlanningMilestoneScreen> createState() =>
      _FrontEndPlanningMilestoneScreenState();
}

class _FrontEndPlanningMilestoneScreenState
    extends State<FrontEndPlanningMilestoneScreen> {
  final GlobalKey _timelineSectionKey = GlobalKey();
  final GlobalKey _startDateFieldKey = GlobalKey();
  final GlobalKey _endDateFieldKey = GlobalKey();
  final GlobalKey _milestonesSectionKey = GlobalKey();
  final Map<int, GlobalKey> _milestoneNameFieldKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey> _milestoneDateFieldKeys = <int, GlobalKey>{};
  String _startDateStr = '';
  String _endDateStr = '';
  List<Milestone> _milestones = [];
  bool _isSyncReady = false;
  bool _isGenerating = false;
  bool _autoGenerationTriggered = false;
  bool _isMilestonesExpanded = false;
  // 2-Step SME Review Verification
  // Step 1: User confirms they have reviewed the milestones.
  // Step 2: User confirms the milestones have been discussed with the
  // applicable subject matter experts (SMEs).
  bool _smeReviewConfirmedStep1 = false;
  bool _smeReviewConfirmedStep2 = false;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final ScrollController _milestonesHorizontalScroll = ScrollController();
  final List<TextEditingController> _milestoneNameControllers =
      <TextEditingController>[];
  final List<TextEditingController> _milestoneDisciplineControllers =
      <TextEditingController>[];
  final List<TextEditingController> _milestoneCommentControllers =
      <TextEditingController>[];
  late final OpenAiServiceSecure _openAi;
  Map<String, String> _validationErrors = const {};

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
          .set({
            flagKey: true,
            '${flagKey}_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _openAi = OpenAiServiceSecure();
    ApiKeyManager.initializeApiKey();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadMilestoneData();
      await _triggerAutoMilestoneGenerationIfMissing();
    });
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final fep = projectData.frontEndPlanning;
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Milestone Planning',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
      ],
    );
  }

  void _loadMilestoneData() {
    final data = ProjectDataHelper.getData(context);

    // Load start and end dates from front end planning notes
    _startDateStr = data.frontEndPlanning.milestoneStartDate;
    _endDateStr = data.frontEndPlanning.milestoneEndDate;

    // Load 2-step SME review verification state
    _smeReviewConfirmedStep1 = data.frontEndPlanning.milestoneSmeReviewStep1;
    _smeReviewConfirmedStep2 = data.frontEndPlanning.milestoneSmeReviewStep2;

    // Load milestones from project data
    _milestones = data.keyMilestones
        .map(
          (milestone) => Milestone(
            name: _sanitizeMilestoneName(milestone.name),
            discipline: milestone.discipline,
            dueDate: milestone.dueDate,
            references: milestone.references,
            comments: milestone.comments,
          ),
        )
        .toList();
    _rebuildMilestoneCommentControllers();

    _isSyncReady = true;
    if (mounted) setState(() {});
  }

  String _sanitizeMilestoneName(String rawName) {
    return rawName
        .replaceAll(
          RegExp(r'^opportunity\s*[:\-]\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'^opportunity\s+', caseSensitive: false), '')
        .trim();
  }

  void _rebuildMilestoneCommentControllers() {
    for (final controller in _milestoneNameControllers) {
      controller.dispose();
    }
    for (final controller in _milestoneDisciplineControllers) {
      controller.dispose();
    }
    for (final controller in _milestoneCommentControllers) {
      controller.dispose();
    }
    _milestoneNameControllers
      ..clear()
      ..addAll(
        _milestones.map(
          (milestone) => TextEditingController(text: milestone.name),
        ),
      );
    _milestoneDisciplineControllers
      ..clear()
      ..addAll(
        _milestones.map(
          (milestone) => TextEditingController(text: milestone.discipline),
        ),
      );
    _milestoneCommentControllers
      ..clear()
      ..addAll(
        _milestones.map(
          (milestone) => RichTextEditingController(text: milestone.comments),
        ),
      );
  }

  Future<void> _triggerAutoMilestoneGenerationIfMissing() async {
    if (_autoGenerationTriggered || _isGenerating || !mounted) return;
    final datesMissing =
        _startDateStr.trim().isEmpty || _endDateStr.trim().isEmpty;
    final milestonesMissing = _milestones.isEmpty;
    if (!datesMissing && !milestonesMissing) return;

    final datesInitialized = await _isSectionInitialized(
      'milestone_dates_initialized',
    );
    final itemsInitialized = await _isSectionInitialized(
      'milestone_items_initialized',
    );

    _autoGenerationTriggered = true;
    if (datesMissing && !datesInitialized) {
      await _generateDatesWithAI(silent: true);
    }
    if (milestonesMissing && !itemsInitialized) {
      await _generateMilestonesWithAI(silent: true);
    }
  }

  void _syncToProvider() {
    if (!_isSyncReady || !mounted) return;
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField(
      (data) => data.copyWith(
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          milestoneStartDate: _startDateStr,
          milestoneEndDate: _endDateStr,
          milestoneSmeReviewStep1: _smeReviewConfirmedStep1,
          milestoneSmeReviewStep2: _smeReviewConfirmedStep2,
        ),
        keyMilestones: List.from(_milestones),
      ),
    );
    provider.saveToFirebase(checkpoint: 'fep_milestone');
    if (_startDateStr.trim().isNotEmpty || _endDateStr.trim().isNotEmpty) {
      _markSectionInitialized('milestone_dates_initialized');
    }
    if (_milestones.isNotEmpty) {
      _markSectionInitialized('milestone_items_initialized');
    }
  }

  GlobalKey _milestoneNameKey(int index) {
    return _milestoneNameFieldKeys.putIfAbsent(index, GlobalKey.new);
  }

  GlobalKey _milestoneDateKey(int index) {
    return _milestoneDateFieldKeys.putIfAbsent(index, GlobalKey.new);
  }

  FormValidationResult _validateMilestoneSection() {
    final rules = <ValidationFieldRule>[
      ValidationFieldRule(
        id: 'project_start_date',
        label: 'Project Start Date',
        section: 'Milestones',
        type: ValidationFieldType.date,
        value: _startDateStr,
        fieldKey: _startDateFieldKey,
      ),
      ValidationFieldRule(
        id: 'project_end_date',
        label: 'Project End Date',
        section: 'Milestones',
        type: ValidationFieldType.date,
        value: _endDateStr,
        fieldKey: _endDateFieldKey,
      ),
      ValidationFieldRule(
        id: 'key_milestones',
        label: 'Key Milestones',
        section: 'Milestones',
        type: ValidationFieldType.multiSelect,
        value: _milestones,
        fieldKey: _milestonesSectionKey,
      ),
    ];

    for (var index = 0; index < _milestones.length; index++) {
      final milestone = _milestones[index];
      rules.add(
        ValidationFieldRule(
          id: 'milestone_name_$index',
          label: 'Milestone ${index + 1} Name',
          section: 'Milestones',
          type: ValidationFieldType.text,
          value: milestone.name,
          fieldKey: _milestoneNameKey(index),
        ),
      );
      rules.add(
        ValidationFieldRule(
          id: 'milestone_date_$index',
          label: 'Milestone ${index + 1} Target Date',
          section: 'Milestones',
          type: ValidationFieldType.date,
          value: milestone.dueDate,
          fieldKey: _milestoneDateKey(index),
        ),
      );
    }

    return FormValidationEngine.validateForm(rules);
  }

  Future<void> _saveAndNavigate({bool skippedValidation = false}) async {
    if (skippedValidation && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved progress. You can complete remaining milestone details later.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    await ProjectDataHelper.getProvider(
      context,
    ).saveToFirebase(checkpoint: 'fep_milestone');
    if (!mounted) return;
    FrontEndPlanningNavigation.goToNext(context, 'fep_milestone');
  }

  Future<void> _autoFillMilestoneRequirements(
    FormValidationResult validation,
  ) async {
    final needsDates = validation.issues.any(
      (issue) =>
          issue.id == 'project_start_date' ||
          issue.id == 'project_end_date' ||
          issue.id.startsWith('milestone_date_'),
    );
    final needsMilestones = validation.issues.any(
      (issue) =>
          issue.id == 'key_milestones' ||
          issue.id.startsWith('milestone_name_') ||
          issue.id.startsWith('milestone_date_'),
    );

    if (needsDates) {
      await _generateDatesWithAI(silent: true);
    }
    if (needsMilestones) {
      await _generateMilestonesWithAI(silent: true);
    }
  }

  Future<void> _handleSaveAndContinue() async {
    if (!_smeReviewConfirmedStep1 || !_smeReviewConfirmedStep2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete both SME review verification steps before continuing.',
          ),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final validation = _validateMilestoneSection();
    if (!validation.isValid) {
      setState(() {
        _validationErrors = validation.errorByFieldId;
      });

      FormValidationEngine.showValidationSnackBar(
        context,
        validation,
        intro:
            'Milestone details are recommended before proceeding. You can continue now and complete them later.',
        backgroundColor: const Color(0xFFF59E0B),
      );

      await _saveAndNavigate(skippedValidation: true);
      return;
    }

    if (_validationErrors.isNotEmpty) {
      setState(() => _validationErrors = const {});
    }

    await _saveAndNavigate();
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return _dateFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> _selectStartDate() async {
    final currentDate = _parseDate(_startDateStr);
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Project Start Date',
    );
    if (picked != null) {
      final endDate = _parseDate(_endDateStr);
      setState(() {
        _startDateStr = _dateFormat.format(picked);
        // Validate: if end date is before start date, clear it
        if (endDate != null && endDate.isBefore(picked)) {
          _endDateStr = '';
        }
        final nextErrors = Map<String, String>.from(_validationErrors);
        nextErrors.remove('project_start_date');
        if (_endDateStr.isNotEmpty) {
          nextErrors.remove('project_end_date');
        }
        _validationErrors = nextErrors;
      });
      _syncToProvider();
    }
  }

  Future<void> _selectEndDate() async {
    final startDate = _parseDate(_startDateStr);
    final currentEndDate = _parseDate(_endDateStr);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          currentEndDate ??
          (startDate ?? DateTime.now()).add(const Duration(days: 90)),
      firstDate: startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Project End Date',
    );
    if (picked != null) {
      if (startDate != null && picked.isBefore(startDate)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('End date cannot be before start date'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() {
        _endDateStr = _dateFormat.format(picked);
        final nextErrors = Map<String, String>.from(_validationErrors);
        nextErrors.remove('project_end_date');
        _validationErrors = nextErrors;
      });
      _syncToProvider();
    }
  }

  Future<void> _selectMilestoneDate(int index) async {
    final milestone = _milestones[index];
    final currentDate = _parseDate(milestone.dueDate);
    final startDate = _parseDate(_startDateStr);
    final endDate = _parseDate(_endDateStr);

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? (startDate ?? DateTime.now()),
      firstDate: startDate ?? DateTime(2020),
      lastDate: endDate ?? DateTime(2035),
      helpText: 'Select Milestone Date',
    );
    if (picked != null) {
      setState(() {
        _milestones[index].dueDate = _dateFormat.format(picked);
        final nextErrors = Map<String, String>.from(_validationErrors);
        nextErrors.remove('milestone_date_$index');
        _validationErrors = nextErrors;
      });
      _syncToProvider();
    }
  }

  void _addMilestone() {
    setState(() {
      _milestones.add(
        Milestone(
          name: '',
          discipline: '',
          dueDate: '',
          references: '',
          comments: '',
        ),
      );
      _rebuildMilestoneCommentControllers();
      _validationErrors = Map<String, String>.from(_validationErrors)
        ..remove('key_milestones');
    });
    _syncToProvider();
  }

  void _removeMilestone(int index) {
    setState(() {
      _milestones.removeAt(index);
      _rebuildMilestoneCommentControllers();
      _milestoneNameFieldKeys.clear();
      _milestoneDateFieldKeys.clear();
      final nextErrors = Map<String, String>.from(_validationErrors)
        ..removeWhere(
          (key, _) =>
              key.startsWith('milestone_name_') ||
              key.startsWith('milestone_date_'),
        );
      _validationErrors = nextErrors;
    });
    _syncToProvider();
  }

  Future<void> _confirmDeleteMilestone(int index) async {
    if (index < 0 || index >= _milestones.length) return;
    final milestoneName = _milestones[index].name.trim();
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Milestone?',
      itemLabel: milestoneName.isEmpty
          ? 'Milestone ${index + 1}'
          : milestoneName,
    );
    if (!confirmed) return;
    _removeMilestone(index);
  }

  void _updateMilestoneField(int index, String field, String value) {
    setState(() {
      final nextErrors = Map<String, String>.from(_validationErrors);
      switch (field) {
        case 'name':
          _milestones[index].name = _sanitizeMilestoneName(value);
          if (_milestoneNameControllers[index].text !=
              _milestones[index].name) {
            _milestoneNameControllers[index].value = TextEditingValue(
              text: _milestones[index].name,
              selection: TextSelection.collapsed(
                offset: _milestones[index].name.length,
              ),
            );
          }
          nextErrors.remove('milestone_name_$index');
          break;
        case 'discipline':
          _milestones[index].discipline = value;
          break;
        case 'comments':
          _milestones[index].comments = value;
          break;
      }
      _validationErrors = nextErrors;
    });
    _syncToProvider();
  }

  Future<void> _generateMilestonesWithAI({bool silent = false}) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final data = ProjectDataHelper.getData(context);
      final projectContext = ProjectDataHelper.buildFepContext(data);

      // IMPORTANT: These are KEY MILESTONES (significant project checkpoints),
      // NOT opportunities. Do NOT prefix any milestone name with the word
      // "Opportunity" or treat these as opportunity items.
      final prompt =
          '''Based on the following project information, suggest 5-7 KEY PROJECT MILESTONES — significant checkpoints that mark major progress points in the project lifecycle. These are MILESTONES ONLY, not opportunities, risks, or requirements.

Project Information:
$projectContext

Project Name: ${data.projectName}
Solution: ${data.solutionDescription}
Objectives: ${data.projectObjective}
Start Date: ${_startDateStr.isNotEmpty ? _startDateStr : 'Not set'}
End Date: ${_endDateStr.isNotEmpty ? _endDateStr : 'Not set'}

RULES:
- Each line must be a single KEY MILESTONE (e.g., Project Kickoff, Planning Complete, Design Review, Execution Start, User Acceptance Testing, Go-Live).
- Do NOT use the word "Opportunity" anywhere in the milestone name, description, or discipline.
- Do NOT generate risk items, requirements, or potential benefits.
- Leave DUE_DATE BLANK if start/end dates are not set; the user will fill in dates manually.

Please generate milestones in the following format, one per line:
MILESTONE_NAME | DISCIPLINE | DUE_DATE (MMM dd, yyyy format, or leave blank) | DESCRIPTION

Example:
Project Kickoff | Project Management | | Initial project kickoff meeting with all stakeholders
Planning Complete | Planning | | All planning documents finalized and approved
Go-Live | Operations | | Project goes live and transitions to operations

Generate milestones that cover the typical project lifecycle phases.''';

      final response = await _openAi.generateFepSectionText(
        section: 'Project Milestones',
        context: prompt,
        maxTokens: 800,
      );

      if (mounted && response.isNotEmpty) {
        final generatedMilestones = _parseMilestonesFromResponse(response);

        if (generatedMilestones.isNotEmpty) {
          setState(() {
            _milestones = generatedMilestones;
            _rebuildMilestoneCommentControllers();
          });
          _syncToProvider();

          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Generated ${generatedMilestones.length} milestones successfully',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } else {
          // Fallback to defaults if parsing failed
          _useDefaultMilestones(silent: silent);
        }
      } else {
        // Fallback if response is empty
        _useDefaultMilestones(silent: silent);
      }
    } catch (e) {
      // CRITICAL: Defensive error handling - fallback to defaults, never show error to user
      debugPrint('AI milestone generation failed: $e');
      _useDefaultMilestones(silent: silent);
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Fallback to default milestones when AI generation fails
  void _useDefaultMilestones({bool silent = false}) {
    if (!mounted) return;
    setState(() {
      _milestones = getDefaultMilestones();
      _rebuildMilestoneCommentControllers();
    });
    _syncToProvider();

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Using default milestones - you can edit them as needed',
          ),
          backgroundColor: Color(0xFFFBBF24),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  List<Milestone> _parseMilestonesFromResponse(String response) {
    final milestones = <Milestone>[];
    final lines = response.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      // Skip headers or explanatory text
      if (line.startsWith('MILESTONE') ||
          line.startsWith('Example') ||
          line.startsWith('Generate') ||
          line.startsWith('Please') ||
          !line.contains('|')) {
        continue;
      }

      final parts = line.split('|').map((p) => p.trim()).toList();

      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        final cleanedName = _sanitizeMilestoneName(parts[0]);
        if (cleanedName.isEmpty) continue;
        // Filter out lines that are clearly NOT milestones.
        final lower = cleanedName.toLowerCase();
        if (lower.startsWith('opportunity') ||
            lower.startsWith('risk:') ||
            lower.startsWith('requirement:')) {
          continue;
        }
        milestones.add(
          Milestone(
            name: cleanedName,
            discipline: parts.length > 1 ? parts[1] : '',
            dueDate: '',
            references: '',
            comments: parts.length > 3 ? parts[3] : '',
          ),
        );
      }
    }

    // If no milestones parsed with pipe format, try to parse natural text
    if (milestones.isEmpty) {
      final naturalLines = response.split('\n').where((line) {
        final trimmed = line.trim();
        return trimmed.isNotEmpty &&
            (trimmed.startsWith('-') ||
                trimmed.startsWith('•') ||
                trimmed.startsWith('1') ||
                trimmed.startsWith('2') ||
                trimmed.startsWith('3') ||
                trimmed.startsWith('4') ||
                trimmed.startsWith('5') ||
                trimmed.startsWith('6') ||
                trimmed.startsWith('7'));
      });

      for (final line in naturalLines) {
        final cleanLine = line.replaceAll(RegExp(r'^[-•\d.)\s]+'), '').trim();
        if (cleanLine.isEmpty) continue;
        // Strip "Opportunity:" prefix if present, and skip lines that
        // are clearly not milestones.
        final lower = cleanLine.toLowerCase();
        if (lower.startsWith('opportunity') ||
            lower.startsWith('risk:') ||
            lower.startsWith('requirement:')) {
          continue;
        }
        final milestoneText = _sanitizeMilestoneName(cleanLine);
        if (milestoneText.isEmpty) continue;
        milestones.add(
          Milestone(
            name: milestoneText.length > 60
                ? milestoneText.substring(0, 60)
                : milestoneText,
            discipline: 'General',
            dueDate: '',
            references: '',
            comments: milestoneText.length > 60 ? milestoneText : '',
          ),
        );
      }
    }

    return milestones.take(7).toList();
  }

  Future<void> _generateDatesWithAI({bool silent = false}) async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final data = ProjectDataHelper.getData(context);

      final prompt =
          '''Based on the project information below, suggest appropriate start and end dates.

Project: ${data.projectName}
Solution: ${data.solutionDescription}
Number of milestones: ${_milestones.length}

Respond with exactly two lines:
START: MMM dd, yyyy
END: MMM dd, yyyy

Consider typical project timelines and ensure end date is after start date.''';

      final response = await _openAi.generateFepSectionText(
        section: 'Project Timeline',
        context: prompt,
        maxTokens: 100,
      );

      if (mounted && response.isNotEmpty) {
        // Parse dates from response
        bool foundStart = false;
        bool foundEnd = false;
        final lines = response.split('\n');

        for (final line in lines) {
          if (line.toUpperCase().contains('START')) {
            final dateMatch = RegExp(
              r'[A-Za-z]{3}\s+\d{1,2},\s+\d{4}',
            ).firstMatch(line);
            if (dateMatch != null) {
              setState(() => _startDateStr = dateMatch.group(0)!);
              foundStart = true;
            }
          } else if (line.toUpperCase().contains('END')) {
            final dateMatch = RegExp(
              r'[A-Za-z]{3}\s+\d{1,2},\s+\d{4}',
            ).firstMatch(line);
            if (dateMatch != null) {
              setState(() => _endDateStr = dateMatch.group(0)!);
              foundEnd = true;
            }
          }
        }

        if (foundStart || foundEnd) {
          _syncToProvider();
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project dates generated'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      }
    } catch (e) {
      // DEFENSIVE: Silent failure - dates are optional, no error to user
      debugPrint('AI date generation failed (non-critical): $e');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _milestoneNameControllers) {
      controller.dispose();
    }
    for (final controller in _milestoneDisciplineControllers) {
      controller.dispose();
    }
    for (final controller in _milestoneCommentControllers) {
      controller.dispose();
    }
    _milestonesHorizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(activeItemLabel: 'Milestone'),
            ),
            Expanded(
              child: Stack(
                children: [
                  const AdminEditToggle(),
                  Column(
                    children: [
                      FrontEndPlanningHeader(onExportPdf: _exportPdf),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Milestone',
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

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: Color(0xFFF59E0B),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Estimated Project Timeline',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Key milestones represent the minimum requirements that must be completed for the project to operate successfully.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),

          // Project Dates Section
          Container(
            key: _timelineSectionKey,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Project Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isGenerating ? null : _generateDatesWithAI,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Generate Dates with AI'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Start Date
                    Expanded(
                      child: _buildDateCard(
                        fieldKey: _startDateFieldKey,
                        title: 'Start Date',
                        icon: Icons.play_circle_outline,
                        dateStr: _startDateStr,
                        onTap: _selectStartDate,
                        iconColor: const Color(0xFF10B981),
                        errorText: _validationErrors['project_start_date'],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Duration indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _calculateDuration(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // End Date
                    Expanded(
                      child: _buildDateCard(
                        fieldKey: _endDateFieldKey,
                        title: 'End Date',
                        icon: Icons.stop_circle_outlined,
                        dateStr: _endDateStr,
                        onTap: _selectEndDate,
                        iconColor: const Color(0xFFEF4444),
                        errorText: _validationErrors['project_end_date'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Key Milestones Section
          Container(
            key: _milestonesSectionKey,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _validationErrors.containsKey('key_milestones')
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Key Milestones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : _generateMilestonesWithAI,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Generate with AI'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _milestones.isEmpty
                          ? null
                          : () => setState(
                              () => _isMilestonesExpanded =
                                  !_isMilestonesExpanded,
                            ),
                      icon: Icon(
                        _isMilestonesExpanded
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        size: 18,
                      ),
                      label: Text(
                        _isMilestonesExpanded ? 'Collapse' : 'Expand',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addMilestone,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Milestone'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_milestones.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No milestones defined yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add Milestone" to create your first milestone',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildMilestonesTable(expanded: _isMilestonesExpanded),
                if (_validationErrors.containsKey('key_milestones')) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationErrors['key_milestones']!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2-Step SME Review Verification
          _buildSmeReviewCard(),

          const SizedBox(height: 32),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () => FrontEndPlanningNavigation.goToPrevious(
                  context,
                  'fep_milestone',
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _handleSaveAndContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Save & Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100), // Space for KAZ chat bubble
        ],
      ),
    );
  }

  Widget _buildSmeReviewCard() {
    final bothConfirmed = _smeReviewConfirmedStep1 && _smeReviewConfirmedStep2;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bothConfirmed
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bothConfirmed
              ? const Color(0xFF10B981)
              : const Color(0xFFF59E0B),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bothConfirmed
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                size: 20,
                color: bothConfirmed
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Subject Matter Expert (SME) Review Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (bothConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'VERIFIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm that the milestones above have been reviewed and discussed with the appropriate subject matter experts before proceeding.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildVerificationCheckbox(
            value: _smeReviewConfirmedStep1,
            label:
                'Step 1 — I have personally reviewed each milestone name, target date, and discipline for accuracy.',
            onChanged: (val) {
              setState(() => _smeReviewConfirmedStep1 = val ?? false);
              _syncToProvider();
            },
          ),
          const SizedBox(height: 8),
          _buildVerificationCheckbox(
            value: _smeReviewConfirmedStep2,
            enabled: _smeReviewConfirmedStep1,
            label:
                'Step 2 — I have discussed these milestones with the relevant subject matter experts (engineering, schedule, procurement, operations) and incorporated their feedback.',
            onChanged: (val) {
              setState(() => _smeReviewConfirmedStep2 = val ?? false);
              _syncToProvider();
            },
          ),
          if (!_smeReviewConfirmedStep1) ...[
            const SizedBox(height: 8),
            const Text(
              'Complete Step 1 before confirming the SME discussion step.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (!bothConfirmed) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Both confirmations are required before the milestone plan is considered final.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: enabled
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard({
    Key? fieldKey,
    required String title,
    required IconData icon,
    required String dateStr,
    required VoidCallback onTap,
    required Color iconColor,
    String? errorText,
  }) {
    final hasError = (errorText ?? '').trim().isNotEmpty;
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr.isNotEmpty ? dateStr : 'Select date',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: dateStr.isNotEmpty
                              ? const Color(0xFF111827)
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _milestoneFieldBorder(bool hasError) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: hasError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildMilestonesTable({bool expanded = false}) {
    const border = BorderSide(color: Color(0xFFE5E7EB));
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF374151),
    );

    final table = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Expandable: use the full available width when wider than the
          // minimum readable width; otherwise fall back to horizontal
          // scrolling so the table always fills the screen as much as
          // possible.
          final minTableWidth = 1100.0;
          final tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          // Proportional column widths so the table expands to fill the
          // available space (rather than the old fixed-pixel widths that
          // always left a fixed table size regardless of viewport).
          final col0 = 60.0; // #
          final col1 = tableWidth * 0.22; // Milestone Name
          final col2 = tableWidth * 0.16; // Target Date
          final col3 = tableWidth * 0.16; // Discipline
          final col4 = tableWidth * 0.36; // Notes (expandable)
          final col5 = 70.0; // Actions
          // Adjust to exactly fill tableWidth
          final allocated = col0 + col1 + col2 + col3 + col4 + col5;
          final slack = tableWidth - allocated;
          final col4Adjusted = col4 + (slack > 0 ? slack : 0);

          return Scrollbar(
            controller: _milestonesHorizontalScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _milestonesHorizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  border: const TableBorder(
                    horizontalInside: border,
                    verticalInside: border,
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  columnWidths: {
                    0: FixedColumnWidth(col0),
                    1: FixedColumnWidth(col1),
                    2: FixedColumnWidth(col2),
                    3: FixedColumnWidth(col3),
                    4: FixedColumnWidth(col4Adjusted),
                    5: FixedColumnWidth(col5),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: [
                        _milestoneHeaderCell('#', headerStyle),
                        _milestoneHeaderCell('Milestone Name', headerStyle),
                        _milestoneHeaderCell('Target Date', headerStyle),
                        _milestoneHeaderCell('Discipline', headerStyle),
                        _milestoneHeaderCell('Notes', headerStyle),
                        _milestoneHeaderCell('Actions', headerStyle),
                      ],
                    ),
                    ...List.generate(_milestones.length, (index) {
                      final milestone = _milestones[index];
                      final nameError =
                          _validationErrors['milestone_name_$index'];
                      final dateError =
                          _validationErrors['milestone_date_$index'];
                      return TableRow(
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.white
                              : const Color(0xFFFAFAFA),
                        ),
                        children: [
                          _milestoneDataCell(
                            Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                          _milestoneDataCell(
                            VoiceTextFormField(
                              key: _milestoneNameKey(index),
                              controller: _milestoneNameControllers[index],
                              onChanged: (value) =>
                                  _updateMilestoneField(index, 'name', value),
                              decoration: InputDecoration(
                                hintText: 'Enter milestone name',
                                errorText: nameError,
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                border: _milestoneFieldBorder(
                                  nameError != null,
                                ),
                                enabledBorder: _milestoneFieldBorder(
                                  nameError != null,
                                ),
                                focusedBorder: _milestoneFieldBorder(
                                  nameError != null,
                                ),
                                errorBorder: _milestoneFieldBorder(true),
                                focusedErrorBorder: _milestoneFieldBorder(true),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          _milestoneDataCell(
                            Column(
                              key: _milestoneDateKey(index),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => _selectMilestoneDate(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: dateError != null
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            milestone.dueDate.isNotEmpty
                                                ? milestone.dueDate
                                                : 'Select date',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  milestone.dueDate.isNotEmpty
                                                  ? const Color(0xFF111827)
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (dateError != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dateError,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _milestoneDataCell(
                            VoiceTextFormField(
                              controller:
                                  _milestoneDisciplineControllers[index],
                              onChanged: (value) => _updateMilestoneField(
                                index,
                                'discipline',
                                value,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Discipline',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                border: _milestoneFieldBorder(false),
                                enabledBorder: _milestoneFieldBorder(false),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          _milestoneDataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VoiceTextFormField(
                                  controller:
                                      _milestoneCommentControllers[index],
                                  onChanged: (value) => _updateMilestoneField(
                                    index,
                                    'comments',
                                    value,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add notes (optional)',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                    border: _milestoneFieldBorder(false),
                                    enabledBorder: _milestoneFieldBorder(false),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  minLines: 1,
                                  maxLines: null,
                                ),
                              ],
                            ),
                          ),
                          _milestoneDataCell(
                            Center(
                              child: IconButton(
                                onPressed: () => _confirmDeleteMilestone(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
                                tooltip: 'Remove milestone',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!expanded) {
      return table;
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.68,
      ),
      child: table,
    );
  }

  Widget _milestoneHeaderCell(String label, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Center(
        child: Text(label, style: style, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _milestoneDataCell(Widget child) {
    return Padding(padding: const EdgeInsets.all(12), child: child);
  }

  String _calculateDuration() {
    final startDate = _parseDate(_startDateStr);
    final endDate = _parseDate(_endDateStr);

    if (startDate == null || endDate == null) {
      return 'Set dates';
    }
    final difference = endDate.difference(startDate);
    final days = difference.inDays;
    if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      final months = (days / 30).round();
      return '$months month${months > 1 ? 's' : ''}';
    } else {
      final years = (days / 365).round();
      final remainingMonths = ((days % 365) / 30).round();
      if (remainingMonths > 0) {
        return '$years yr${years > 1 ? 's' : ''} $remainingMonths mo';
      }
      return '$years year${years > 1 ? 's' : ''}';
    }
  }
}
