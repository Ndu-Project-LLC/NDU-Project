import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/widgets/business_case_navigation_buttons.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// Removed AppLogo from header per request
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SafeSection — Build-time error boundary that prevents a single failing child
// widget from blanking the entire page.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class SafeSection extends StatelessWidget {
  SafeSection({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    Widget child;
    try {
      child = builder(context);
    } catch (error, stack) {
      debugPrint('[RiskIdentification] Section "$title" failed: $error');
      debugPrint(stack.toString());
      return _SectionErrorCard(
        title: '$title unavailable',
        message:
            'This section encountered an error while rendering. Other parts of the page are unaffected.',
        details: error.toString(),
      );
    }
    return child;
  }
}

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard(
      {required this.title, required this.message, required this.details});
  final String title;
  final String message;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDA29B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Color(0xFFFEE4E2), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline,
                color: Color(0xFFD92D20), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB42318))),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF667085), height: 1.5)),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6)),
                    child: SelectableText(details,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: appFontFamily,
                            color: Color(0xFF475467)),
                        maxLines: 4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RiskIdentificationScreen extends StatefulWidget {
  final String notes;
  final List<AiSolutionItem> solutions;
  final String businessCase;
  const RiskIdentificationScreen({
    super.key,
    required this.notes,
    required this.solutions,
    this.businessCase = '',
  });

  @override
  State<RiskIdentificationScreen> createState() =>
      _RiskIdentificationScreenState();
}

class _RiskIdentificationScreenState extends State<RiskIdentificationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _reviewScrollController = ScrollController();
  late final TextEditingController _notesController;
  // Maintain local solutions so we can bootstrap from the business case when needed.
  List<AiSolutionItem> _solutions = const <AiSolutionItem>[];
  late List<TextEditingController>
      _solutionTitleControllers; // Controllers for solution titles
  late List<List<TextEditingController>>
      _riskControllers; // [solutionIndex][riskIndex]
  final OpenAiServiceSecure _openAi = OpenAiServiceSecure();
  bool _isGenerating = false;
  String? _error;
  bool _initiationExpanded = true;
  bool _businessCaseExpanded = true;
  bool _frontEndExpanded = true;

  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSavedAt;
  bool _reviewConfirmed = false;

  static const List<CsvColumnSpec> _riskCsvColumns = [
    CsvColumnSpec(
        key: 'solutionTitle',
        label: 'Solution Title',
        required: true,
        sampleValue: 'Cloud Migration'),
    CsvColumnSpec(
        key: 'risk1',
        label: 'Risk 1',
        sampleValue: 'Budget overrun due to unforeseen costs'),
    CsvColumnSpec(
        key: 'risk2',
        label: 'Risk 2',
        sampleValue: 'Timeline delays from resource constraints'),
    CsvColumnSpec(
        key: 'risk3',
        label: 'Risk 3',
        sampleValue: 'Technical complexity causing scope creep'),
  ];

  // Admin status
  bool _isAdmin = false;

  bool get _canUseAdminControls =>
      _isAdmin && AccessPolicy.isRestrictedAdminHost();

  TextEditingController _createRiskController({String text = ''}) {
    final controller = RichAutoBulletTextController(text: text);
    controller.addListener(_onDataChanged);
    return controller;
  }

  Future<void> _exportPdf() async {
    final notes = _notesController.text.trim();
    final riskRows = <List<String>>[];
    for (int i = 0; i < _solutions.length; i++) {
      final title = i < _solutionTitleControllers.length
          ? _solutionTitleControllers[i].text.trim()
          : _solutions[i].title;
      final displayTitle = title.isEmpty ? 'Solution ${i + 1}' : title;
      for (int r = 0; r < 3; r++) {
        final riskText =
            (i < _riskControllers.length && r < _riskControllers[i].length)
                ? _riskControllers[i][r].text.trim()
                : '';
        if (riskText.isNotEmpty) {
          riskRows.add([displayTitle, 'Risk ${r + 1}', riskText]);
        }
      }
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Risk Identification',
      sections: [
        PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
        PdfSection.table(
          'Risks by Solution',
          headers: ['Solution', 'Risk #', 'Description'],
          rows: riskRows,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _notesController = RichTextEditingController(text: widget.notes);
    _notesController.addListener(_onDataChanged);
    // Notes = prose; no auto-bullet

    _solutions = List<AiSolutionItem>.from(widget.solutions);
    // Initialize solution title controllers
    _solutionTitleControllers = _solutions.map((s) {
      final controller = TextEditingController(text: s.title);
      controller.addListener(_onDataChanged);
      return controller;
    }).toList();

    _riskControllers = List.generate(_solutions.length,
        (_) => List.generate(3, (_) => _createRiskController()));
    ApiKeyManager.initializeApiKey();

    // Check admin status
    UserService.isCurrentUserAdmin().then((isAdmin) {
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    });

    // Auto-bootstrap or generate risks after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _bootstrapSolutionsFromProjectData();
        // Load saved risks from provider if available
        final projectData = ProjectDataHelper.getData(context);
        if (projectData.solutionRisks.isNotEmpty) {
          _loadSavedRisks(projectData.solutionRisks);
    } else if (_solutions.isNotEmpty) {
      // Auto-generate risks for all solutions on first load
      _generateRisks(showSuccessSnack: false);
    }
      } catch (e) {
        debugPrint('RiskIdentification initState error: $e');
      }

      // Delay hint so page content renders first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        PageHintDialog.showIfNeeded(
          context: context,
          pageId: 'risk_identification',
          title: 'Risk Identification',
          message:
              'Identify up to 3 delivery risks per potential solution. Use "Generate risks" for AI suggestions tailored to each solution. Risks auto-save as you edit.',
        );
      });
    });
  }

  void _bootstrapSolutionsFromProjectData() {
    if (_solutions.isNotEmpty) return;
    final projectData = ProjectDataHelper.getData(context);
    final derivedSolutions = <AiSolutionItem>[
      for (final solution in projectData.potentialSolutions)
        if (solution.title.trim().isNotEmpty ||
            solution.description.trim().isNotEmpty)
          AiSolutionItem(
            title: solution.title.trim(),
            description: solution.description.trim(),
          ),
    ];
    if (derivedSolutions.isEmpty &&
        projectData.solutionTitle.trim().isNotEmpty) {
      derivedSolutions.add(
        AiSolutionItem(
          title: projectData.solutionTitle.trim(),
          description: projectData.solutionDescription.trim(),
        ),
      );
    }
    if (derivedSolutions.isEmpty) return;

    _solutions = derivedSolutions;
    _solutionTitleControllers = _solutions.map((s) {
      final controller = TextEditingController(text: s.title);
      controller.addListener(_onDataChanged);
      return controller;
    }).toList();
    _riskControllers = List.generate(
      _solutions.length,
      (_) => List.generate(3, (_) => _createRiskController()),
    );
  }

  /// Called whenever any text field changes - triggers debounced auto-save
  void _onDataChanged() {
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  /// Auto-save risks to Firebase
  Future<void> _autoSave() async {
    if (!mounted || _isSaving || !_hasUnsavedChanges) return;

    setState(() => _isSaving = true);

    try {
      // Collect all risk data
      final solutionRisks = <SolutionRisk>[];
      for (int i = 0; i < _solutions.length; i++) {
        final risks = <String>[];
        for (int r = 0; r < 3; r++) {
          if (i < _riskControllers.length && r < _riskControllers[i].length) {
            risks.add(_riskControllers[i][r].text.trim());
          } else {
            risks.add('');
          }
        }
        // Get solution title from controller if available, otherwise from solution object
        final solutionTitle = i < _solutionTitleControllers.length
            ? _solutionTitleControllers[i].text.trim()
            : _solutions[i].title;
        solutionRisks.add(SolutionRisk(
          solutionTitle: solutionTitle.isNotEmpty
              ? solutionTitle
              : 'Potential Solution ${i + 1}',
          risks: risks,
        ));
      }

      // Save to provider
      final provider = ProjectDataHelper.getProvider(context);
      provider.updateInitiationData(
        notes: _notesController.text.trim(),
        solutionRisks: solutionRisks,
      );

      // Save to Firebase silently
      final success =
          await provider.saveToFirebase(checkpoint: 'risk_identification');

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = !success;
          if (success) _lastSavedAt = DateTime.now();
        });

        if (success) {
          debugPrint('✅ Risks auto-saved successfully');
        } else {
          debugPrint('⚠️ Auto-save failed: ${provider.lastError}');
        }
      }
    } catch (e) {
      debugPrint('❌ Auto-save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _loadSavedRisks(List<SolutionRisk> savedRisks) {
    setState(() {
      for (int i = 0; i < _solutions.length && i < savedRisks.length; i++) {
        final solutionRisk = savedRisks[i];
        for (int r = 0; r < 3 && r < solutionRisk.risks.length; r++) {
          if (i < _riskControllers.length && r < _riskControllers[i].length) {
            _riskControllers[i][r].text = solutionRisk.risks[r];
          }
        }
      }
    });
  }

  void _addNewRisk() {
    // Only allow admins (on admin host) to add risks.
    if (!_canUseAdminControls) return;
    if (_solutions.length >= 3) {
      return;
    }

    // Add a new solution row with empty risk fields
    setState(() {
      _solutions.add(AiSolutionItem(title: '', description: ''));
      _riskControllers.add(List.generate(3, (_) => _createRiskController()));
    });
    _onDataChanged(); // Trigger auto-save
  }

  Future<void> _generateRisks({bool showSuccessSnack = true}) async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      if (_solutions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No solutions found. Please add potential solutions first in the Initiation Phase before generating risks.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final provider = ProjectDataHelper.getProvider(context);

      // Add current values to history before regenerating
      for (int i = 0; i < _solutions.length; i++) {
        for (int r = 0; r < 3; r++) {
          if (i < _riskControllers.length && r < _riskControllers[i].length) {
            final fieldKey = 'risk_${_solutions[i].title}_$r';
            provider.addFieldToHistory(fieldKey, _riskControllers[i][r].text,
                isAiGenerated: true);
          }
        }
      }

      final map = await _openAi.generateRisksForSolutions(_solutions,
          contextNotes: _notesController.text.trim());
      for (int i = 0; i < _solutions.length; i++) {
        final title = _solutions[i].title;
        final risks = map[title] ?? const <String>[];
        for (int r = 0; r < 3; r++) {
          final text = r < risks.length ? risks[r] : '';
          if (i < _riskControllers.length && r < _riskControllers[i].length) {
            _riskControllers[i][r].text = text;
          }
        }
      }

      // Auto-save after regeneration
      await provider.saveToFirebase(checkpoint: 'risk_regenerated');

    if (mounted && showSuccessSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risks regenerated successfully')),
      );
    }
    } catch (e) {
      _error = (e.toString().contains('Failed to fetch') ||
              e.toString().contains('ClientException') ||
              e.toString().contains('XMLHttpRequest') ||
              e.toString().contains('Connection refused'))
          ? 'AI assist is being set up. Please try again later or enter content manually.'
          : e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate risks: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _regenerateAllRisks() async {
    await _generateRisks();
  }

  void _handleCsvImport(List<Map<String, String>> rows) {
    int imported = 0;
    for (final row in rows) {
      final solutionTitle = row['solutionTitle']?.trim() ?? '';
      if (solutionTitle.isEmpty) continue;
      setState(() {
        _solutions.add(AiSolutionItem(title: solutionTitle, description: ''));
        final risks = [
          row['risk1']?.trim() ?? '',
          row['risk2']?.trim() ?? '',
          row['risk3']?.trim() ?? '',
        ];
        _solutionTitleControllers.add(TextEditingController(text: solutionTitle)
          ..addListener(_onDataChanged));
        _riskControllers.add(List.generate(3, (r) {
          final c = _createRiskController(text: risks[r]);
          return c;
        }));
        imported++;
      });
    }
    _onDataChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Imported $imported solution(s) with risks from CSV')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isMobile = AppBreakpoints.isMobile(context);
      if (isMobile) {
        return _buildMobileScaffold();
      }
      final sidebarWidth = AppBreakpoints.sidebarWidth(context);
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: null,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.white)),
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        DraggableSidebar(
                          openWidth: sidebarWidth,
                          child: const InitiationLikeSidebar(
                              activeItemLabel: 'Risk Identification'),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white,
                            child: Column(
                              children: [
                                BusinessCaseHeader(
                                  scaffoldKey: _scaffoldKey,
                                  onExportPdf: _exportPdf,
                                ),
                                Expanded(
                                  child: SafeSection(
                                    title: 'RiskIdentification content',
                                    builder: (_) => _buildMainContent(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              MobileSidebarHamburger(
                sidebar: const InitiationLikeSidebar(
                  activeItemLabel: 'Risk Identification',
                ),
              ),
              const KazAiChatBubble(),
              const AdminEditToggle(),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('RiskIdentification build error: $e');
      debugPrint(stack.toString());
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 36, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text(
                    'Risk Identification is loading',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The desktop view hit a rendering issue. Please refresh and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMobileScaffold() {
    final projectName = ProjectDataHelper.getData(context).projectName.trim();
    final displayCount = _isAdmin
        ? _solutions.length
        : (_solutions.length > 3 ? 3 : _solutions.length);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  const Icon(Icons.workspaces_outline,
                      size: 15, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 8),
                  const Text(
                    'PROJECT WORKSPACE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.45,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.more_horiz, size: 18),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      projectName.isEmpty ? 'Project Workspace' : projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAFBF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'INITIATION PHASE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Identification',
                      style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Identify and describe up to 3 risks for each solution defined in the previous step.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < displayCount; i++) ...[
                      _buildMobileRiskCard(i),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: _buildMobileDrawer(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5F9),
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleNextPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRiskCard(int index) {
    final solution = _solutions[index];
    final title = solution.title.trim().isEmpty
        ? 'Potential Solution'
        : solution.title.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showKazAiSuggestions(
                    _riskControllers[index][0], index, 0, solution.title),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE2F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 12, color: Color(0xFF4F46E5)),
                      SizedBox(width: 4),
                      Text(
                        'AI ASSISTANCE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int r = 0; r < 3; r++) ...[
            Text(
              'RISK #${r + 1}',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: VoiceTextField(
                controller: _riskControllers[index][r],
                minLines: 1,
                maxLines: 2,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: r == 0
                      ? 'Potential risk...'
                      : r == 1
                          ? 'Another risk...'
                          : 'Third risk...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            if (r < 2) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopHeader() {
    final isMobile = AppBreakpoints.isMobile(context);
    return Container(
      height: isMobile ? 88 : 110,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      child: Row(
        children: [
          Row(
            children: [
              if (isMobile)
                IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              if (!isMobile) ...[
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () => Navigator.pop(context)),
              ],
            ],
          ),
          const Spacer(),
          if (!isMobile)
            const Text('Initiation Phase',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          const Spacer(),
          Row(
            children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: const Color(0xFFD97706), shape: BoxShape.circle),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 20)),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        FirebaseAuthService.displayNameOrEmail(
                            fallback: 'User'),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                    const Text('Owner',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.grey, size: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSidebar() {
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double bannerHeight = isMobile ? 72 : 96;
    return Container(
      width: sidebarWidth,
      color: Colors.white,
      child: Column(
        children: [
          // Full-width banner image above the "StackOne" text
          SizedBox(
            width: double.infinity,
            height: bannerHeight,
            child: Center(child: AppLogo(height: 64)),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFFFD700), width: 1)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFFFD700),
                  child: Icon(Icons.person_outline, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('StackOne',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildMenuItem(Icons.home_outlined, 'Home',
                    onTap: () => HomeScreen.open(context)),
                _buildExpandableHeader(Icons.flag_outlined, 'Initiation Phase',
                    expanded: _initiationExpanded, onTap: () {
                  setState(() => _initiationExpanded = !_initiationExpanded);
                }, isActive: true),
                if (_initiationExpanded) ...[
                  _buildExpandableHeader(
                      Icons.business_center_outlined, 'Business Case',
                      expanded: _businessCaseExpanded, onTap: () {
                    setState(
                        () => _businessCaseExpanded = !_businessCaseExpanded);
                  }, isActive: false),
                  if (_businessCaseExpanded) ...[
                    _buildNestedSubMenuItem('Potential Solutions',
                        onTap: _openPotentialSolutions),
                    _buildNestedSubMenuItem('Risk Identification',
                        isActive: true),
                    _buildNestedSubMenuItem('IT Considerations',
                        onTap: _openITConsiderations),
                    _buildNestedSubMenuItem('Infrastructure Considerations',
                        onTap: _openInfrastructureConsiderations),
                    _buildNestedSubMenuItem('Core Stakeholders',
                        onTap: _openCoreStakeholders),
                    _buildNestedSubMenuItem('Initial Cost Estimate',
                        onTap: _openCostAnalysis),
                    _buildNestedSubMenuItem('Preferred Solution Analysis',
                        onTap: _openPreferredSolutionAnalysis),
                  ],
                  _buildExpandableHeader(
                      Icons.timeline, 'Initiation: Front End Planning',
                      expanded: _frontEndExpanded, onTap: () {
                    setState(() => _frontEndExpanded = !_frontEndExpanded);
                  }, isActive: false),
                  if (_frontEndExpanded) ...[
                    _buildNestedSubMenuItem('Project Requirements'),
                    _buildNestedSubMenuItem('Project Risks'),
                    _buildNestedSubMenuItem('Project Opportunities'),
                  ],
                ],
                _buildMenuItem(Icons.account_tree_outlined, 'Workflow Roadmap'),
                _buildMenuItem(Icons.flash_on, 'Agile Roadmap'),
                _buildMenuItem(Icons.description_outlined, 'Contracting'),
                _buildMenuItem(Icons.shopping_cart_outlined, 'Procurement'),
                const SizedBox(height: 20),
                _buildMenuItem(Icons.settings_outlined, 'Settings',
                    onTap: () => SettingsScreen.open(context)),
                _buildMenuItem(Icons.logout_outlined, 'LogOut',
                    onTap: () => AuthNav.signOutAndExit(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildMobileDrawer() {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.88,
      child: const SafeArea(
        child: InitiationLikeSidebar(
          activeItemLabel: 'Risk Identification',
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {VoidCallback? onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? primary : Colors.black87),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      color: isActive ? primary : Colors.black87,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSubMenuItem(String title,
      {VoidCallback? onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 24, top: 2, bottom: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 8, color: isActive ? primary : Colors.grey[500]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? primary : Colors.black87,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Third-level nested menu item (under Business Case)
  Widget _buildNestedSubMenuItem(String title,
      {VoidCallback? onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 72, right: 24, top: 2, bottom: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 6, color: isActive ? primary : Colors.grey[400]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? primary : Colors.black87,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableHeader(IconData icon, String title,
      {required bool expanded,
      required VoidCallback onTap,
      bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? primary : Colors.black87),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      color: isActive ? primary : Colors.black87,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey[700],
                  size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _openBusinessCase() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InitiationPhaseScreen(scrollToBusinessCase: true),
      ),
    );
  }

  void _openPotentialSolutions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PotentialSolutionsScreen(),
      ),
    );
  }

  Future<void> _handleNextPressed() async {
    FocusScope.of(context).unfocus();

    // Collect all risk data
    final solutionRisks = <SolutionRisk>[];
    for (int i = 0; i < _solutions.length; i++) {
      final risks = <String>[];
      for (int r = 0; r < 3; r++) {
        if (i < _riskControllers.length && r < _riskControllers[i].length) {
          risks.add(_riskControllers[i][r].text.trim());
        } else {
          risks.add('');
        }
      }
      solutionRisks.add(SolutionRisk(
        solutionTitle: _solutions[i].title,
        risks: risks,
      ));
    }

    // Save to provider
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateInitiationData(
      notes: _notesController.text.trim(),
      solutionRisks: solutionRisks,
    );

    // Save to Firebase
    await provider.saveToFirebase(checkpoint: 'risk_identification');

    // Show 3-second loading dialog
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => const _LoadingDialog(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ITConsiderationsScreen(
          notes: _notesController.text,
          solutions: _solutions,
        ),
      ),
    );
  }

  void _openITConsiderations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ITConsiderationsScreen(
          notes: _notesController.text,
          solutions: _solutions,
        ),
      ),
    );
  }

  void _openInfrastructureConsiderations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfrastructureConsiderationsScreen(
          notes: _notesController.text,
          solutions: _solutions,
        ),
      ),
    );
  }

  void _openCoreStakeholders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoreStakeholdersScreen(
          notes: _notesController.text,
          solutions: _solutions,
        ),
      ),
    );
  }

  void _openCostAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CostAnalysisScreen(
          notes: _notesController.text,
          solutions: _solutions,
        ),
      ),
    );
  }

  void _openPreferredSolutionAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreferredSolutionAnalysisScreen(
          notes: _notesController.text,
          solutions: _solutions,
          businessCase: widget.businessCase,
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    try {
      final isMobile = AppBreakpoints.isMobile(context);
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _reviewScrollController,
            padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EditableContentText(
                    contentKey: 'risk_identification_notes_heading',
                    fallback: 'Notes',
                    category: 'business_case',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        VoiceTextField(
                          controller: _notesController,
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                          decoration: InputDecoration(
                            hintText: 'Input your notes here...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          minLines: 1,
                          maxLines: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const EditableContentText(
                              contentKey: 'risk_identification_heading',
                              fallback: 'Risk Identification ',
                              category: 'business_case',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            EditableContentText(
                              contentKey: 'risk_identification_description',
                              fallback:
                                  '(Identify up to 3 risks for each potential solution here)',
                              category: 'business_case',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      PageRegenerateAllButton(
                        onRegenerateAll: () async {
                          final confirmed =
                              await showRegenerateAllConfirmation(context);
                          if (confirmed && mounted) {
                            await _regenerateAllRisks();
                          }
                        },
                        isLoading: _isGenerating,
                        tooltip: 'Regenerate all risks',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isGenerating ? null : _generateRisks,
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isMobile) ...[
                    if (_solutions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No potential solutions yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Define potential solutions on the Potential Solutions page first, then return here to identify risks for each solution.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                  height: 1.5),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: List.generate(
                          _isAdmin
                              ? _solutions.length
                              : (_solutions.length > 3 ? 3 : _solutions.length),
                          (i) => _riskRow(i),
                        ),
                      ),
                  ] else ...[
                    if (_solutions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 36, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              'No potential solutions yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Define potential solutions first, then return here to identify risks.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  height: 1.5),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: List.generate(
                          _isAdmin
                              ? _solutions.length
                              : (_solutions.length > 3 ? 3 : _solutions.length),
                          (i) => _riskRow(i),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  _buildAutoSaveIndicator(),
                  const SizedBox(height: 16),
                  // CSV import available to all users
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB3D9FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 24),
                        CsvTableImportButton(
                          tableTitle: 'Risk Identification',
                          columns: _riskCsvColumns,
                          onImport: _handleCsvImport,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _addNewRisk,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Risk'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  BusinessCaseNavigationButtons(
                    currentScreen: 'Risk Identification',
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                    onNext: _handleNextPressed,
                    isNextEnabled: _reviewConfirmed,
                    showReviewGate: true,
                    reviewConfirmed: _reviewConfirmed,
                    onReviewChanged: (value) {
                      setState(() => _reviewConfirmed = value);
                    },
                    reviewScrollController: _reviewScrollController,
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('RiskIdentification _buildMainContent error: $e');
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Risk Identification',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text(
              'Identify up to 3 delivery risks per potential solution.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: VoiceTextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                decoration: const InputDecoration(
                  hintText: 'Input your notes here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                minLines: 3,
                maxLines: null,
              ),
            ),
            const SizedBox(height: 24),
            if (_solutions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No potential solutions yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Define potential solutions on the Potential Solutions page first, then return here to identify risks.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          height: 1.5),
                    ),
                  ],
                ),
              )
            else
              ..._solutions.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solution ${i + 1}: ${s.title.isEmpty ? 'Untitled' : s.title}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      VoiceTextField(
                        controller: TextEditingController(text: ''),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                        decoration: const InputDecoration(
                          labelText: 'Risk description',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 4,
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

  Widget _riskRow(int index) {
    final solution = _solutions[index];
    final isMobile = AppBreakpoints.isMobile(context);
    // Safety: ensure risk controllers exist for this row
    final hasControllers =
        index < _riskControllers.length && _riskControllers[index].length >= 3;
    final risk1Controller =
        hasControllers ? _riskControllers[index][0] : TextEditingController();
    final risk2Controller =
        hasControllers ? _riskControllers[index][1] : TextEditingController();
    final risk3Controller =
        hasControllers ? _riskControllers[index][2] : TextEditingController();

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: const Color(0xFFE4E7EC)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _numberBadge(index + 1),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    solution.title.isEmpty
                        ? 'Potential Solution'
                        : solution.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
          ]),
          if (solution.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(solution.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
          const SizedBox(height: 12),
          _labeled('Risk 1',
              _riskTextAreaWithAI(risk1Controller, index, 0, solution.title)),
          const SizedBox(height: 8),
          _labeled('Risk 2',
              _riskTextAreaWithAI(risk2Controller, index, 1, solution.title)),
          const SizedBox(height: 8),
          _labeled('Risk 3',
              _riskTextAreaWithAI(risk3Controller, index, 2, solution.title)),
        ]),
      );
    }

    // Desktop: Card-based layout with solution info on top, risks below
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solution header with badge and title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _numberBadge(index + 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solution.title.isEmpty
                          ? 'Potential Solution'
                          : solution.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (solution.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        solution.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Risk fields in a row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _riskFieldWithLabel(
                  'Risk 1',
                  _riskTextAreaWithAI(
                    risk1Controller,
                    index,
                    0,
                    solution.title,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _riskFieldWithLabel(
                  'Risk 2',
                  _riskTextAreaWithAI(
                    risk2Controller,
                    index,
                    1,
                    solution.title,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _riskFieldWithLabel(
                  'Risk 3',
                  _riskTextAreaWithAI(
                    risk3Controller,
                    index,
                    2,
                    solution.title,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      child,
    ]);
  }

  Widget _riskFieldWithLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  /// Risk text area with hint text and KAZ AI suggestion button
  Widget _riskTextAreaWithAI(TextEditingController controller,
      int solutionIndex, int riskIndex, String solutionTitle) {
    final hintTexts = [
      'e.g., Budget overrun due to unforeseen costs',
      'e.g., Timeline delays from resource constraints',
      'e.g., Technical complexity causing scope creep',
    ];
    final provider = ProjectDataHelper.getProvider(context);
    final fieldKey = 'risk_${solutionTitle}_$riskIndex';
    final canUndo = provider.canUndoField(fieldKey);
    final canRedo = provider.canRedoField(fieldKey);

    return HoverableFieldControls(
      isAiGenerated: true,
      isLoading: false,
      canUndo: canUndo,
      canRedo: canRedo,
      onRegenerate: () async {
        // Add current value to history
        provider.addFieldToHistory(fieldKey, controller.text,
            isAiGenerated: true);
        // Regenerate this specific risk
        await _regenerateSingleRisk(
            controller, solutionIndex, riskIndex, solutionTitle);
      },
      onUndo: () async {
        final data = provider.projectData;
        final previousValue = data.undoField(fieldKey);
        if (previousValue != null) {
          controller.text = previousValue;
          await provider.saveToFirebase(checkpoint: 'risk_undo');
        }
      },
      onRedo: () async {
        final nextValue = provider.projectData.redoField(fieldKey);
        if (nextValue != null) {
          controller.text = nextValue;
          await provider.saveToFirebase(checkpoint: 'risk_redo');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  VoiceTextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      provider.addFieldToHistory(fieldKey, value,
                          isAiGenerated: true);
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintTexts[riskIndex % 3],
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic),
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            // KAZ AI suggestion button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildKazAiButton(
                      controller, solutionIndex, riskIndex, solutionTitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _regenerateSingleRisk(TextEditingController controller,
      int solutionIndex, int riskIndex, String solutionTitle) async {
    try {
      final solution = _solutions[solutionIndex];
      final provider = ProjectDataHelper.getProvider(context);
      final messenger = ScaffoldMessenger.of(context);
      final risks = await _openAi.generateRisksForSolutions(
        [solution],
        contextNotes: _notesController.text.trim(),
      );

      if (risks.containsKey(solution.title) &&
          risks[solution.title]!.isNotEmpty) {
        final riskList = risks[solution.title]!;
        final riskText = riskIndex < riskList.length
            ? riskList[riskIndex]
            : (riskList.isNotEmpty ? riskList.first : '');
        controller.text = riskText;

        await provider.saveToFirebase(checkpoint: 'risk_field_regenerated');

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Risk field regenerated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to regenerate: $e')));
    }
  }

  /// Get existing risks for a solution to avoid duplicates
  List<String> _getExistingRisksForSolution(int solutionIndex) {
    if (solutionIndex >= _riskControllers.length) return [];
    return _riskControllers[solutionIndex]
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Build KAZ AI suggestion button inline
  Widget _buildKazAiButton(TextEditingController controller, int solutionIndex,
      int riskIndex, String solutionTitle) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Get KAZ AI suggestions',
      child: InkWell(
        onTap: () => _showKazAiSuggestions(
            controller, solutionIndex, riskIndex, solutionTitle),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withOpacity(0.1),
                scheme.secondary.withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                'KAZ AI',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show KAZ AI suggestions dialog
  Future<void> _showKazAiSuggestions(TextEditingController controller,
      int solutionIndex, int riskIndex, String solutionTitle) async {
    final existingRisks = _getExistingRisksForSolution(solutionIndex);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 16),
            const Text('Generating suggestions...'),
          ],
        ),
      ),
    );

    try {
      final suggestions = await _openAi.generateSingleRiskSuggestions(
        solutionTitle: solutionTitle,
        riskNumber: riskIndex + 1,
        existingRisks: existingRisks,
        contextNotes: _notesController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No suggestions available')),
        );
        return;
      }

      // Show suggestions dialog
      final scheme = Theme.of(context).colorScheme;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('KAZ AI Risk Suggestions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select a risk suggestion for "$solutionTitle":',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 16),
                ...suggestions.map((suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          final provider =
                              ProjectDataHelper.getProvider(context);
                          final fieldKey = 'risk_${solutionTitle}_$riskIndex';
                          provider.addFieldToHistory(fieldKey, controller.text,
                              isAiGenerated: true);
                          controller.text =
                              TextSanitizer.sanitizeAiText(suggestion);
                          _onDataChanged();
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.orange[600]),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(suggestion,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87))),
                              Icon(Icons.add_circle_outline,
                                  size: 18, color: scheme.primary),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      debugPrint('Error generating risk suggestions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to generate suggestions: ${e.toString()}'),
            backgroundColor: Colors.red[600]),
      );
    }
  }

  /// Build auto-save status indicator
  Widget _buildAutoSaveIndicator() {
    final scheme = Theme.of(context).colorScheme;

    if (_isSaving) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Saving...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    if (_hasUnsavedChanges) {
      return Row(
        children: [
          Icon(Icons.edit_note, size: 16, color: Colors.orange[600]),
          const SizedBox(width: 8),
          Text(
            'Unsaved changes',
            style: TextStyle(fontSize: 12, color: Colors.orange[600]),
          ),
        ],
      );
    }

    if (_lastSavedAt != null) {
      final timeAgo = DateTime.now().difference(_lastSavedAt!);
      String timeText;
      if (timeAgo.inSeconds < 60) {
        timeText = 'just now';
      } else if (timeAgo.inMinutes < 60) {
        timeText = '${timeAgo.inMinutes}m ago';
      } else {
        timeText = '${timeAgo.inHours}h ago';
      }

      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Text(
            'Saved $timeText',
            style: TextStyle(fontSize: 12, color: Colors.green[600]),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFFBBC24),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // Final save before disposing if there are unsaved changes
    if (_hasUnsavedChanges) {
      _autoSave();
    }
    _reviewScrollController.dispose();
    _notesController.removeListener(_onDataChanged);
    _notesController.dispose();
    _disposeRiskControllers();
    super.dispose();
  }

  void _disposeRiskControllers() {
    for (final row in _riskControllers) {
      for (final c in row) {
        c.removeListener(_onDataChanged);
        c.dispose();
      }
    }
  }
}

class _LoadingDialog extends StatefulWidget {
  const _LoadingDialog();

  @override
  State<_LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<_LoadingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: const Icon(
                  Icons.sync,
                  color: Color(0xFFFFD700),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Saving Risk Data...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preparing data for next phase',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
