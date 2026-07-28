import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// AiSolutionItem is exported from openai_service_secure.dart
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/widgets/business_case_navigation_buttons.dart';
// Removed AppLogo to match updated header pattern
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

enum _MissingItConsiderationsAction { manual, autoFill, skip }

class _ItAutoFillPreviewRow {
  const _ItAutoFillPreviewRow({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}

class ITConsiderationsScreen extends StatefulWidget {
  final String notes;
  final List<AiSolutionItem> solutions;
  const ITConsiderationsScreen(
      {super.key, required this.notes, required this.solutions});

  @override
  State<ITConsiderationsScreen> createState() => _ITConsiderationsScreenState();
}

class _ITConsiderationsScreenState extends State<ITConsiderationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _reviewScrollController = ScrollController();
  late final TextEditingController _notesController;
  late List<TextEditingController>
      _techControllers; // one per solution (now mutable)
  late final List<AiSolutionItem> _solutions; // Local mutable list
  final OpenAiServiceSecure _openAi = OpenAiServiceSecure();
  bool _isGenerating = false;
  String? _error;
  bool _initiationExpanded = true;
  bool _businessCaseExpanded = true;
  bool _frontEndExpanded = true;
  bool _isAdmin = false;
  bool _didInitFromProvider = false;
  bool _reviewConfirmed = false;

  // ignore: unused_element
  void _addNewItem() {
    if (!_isAdmin) return; // Only admins can add items
    setState(() {
      _solutions.add(AiSolutionItem(
          title: '', description: '')); // Add a new solution item
      final newController = RichTextEditingController();
      newController.enableAutoBullet(); // Enable auto-bullet for new field
      _techControllers.add(newController); // Add a new controller
    });
  }

  Future<void> _exportPdf() async {
    final notes = _notesController.text.trim();
    final techRows = <List<String>>[];
    for (int i = 0; i < _solutions.length && i < _techControllers.length; i++) {
      final title = _solutions[i].title.trim().isEmpty
          ? 'Solution ${i + 1}'
          : _solutions[i].title.trim();
      final tech = _techControllers[i].text.trim();
      techRows.add([title, tech.isEmpty ? 'No data recorded.' : tech]);
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'IT Considerations',
      sections: [
        PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
        if (techRows.isNotEmpty)
          PdfSection.table(
            'Core Technology by Solution',
            headers: ['Solution', 'Core Technology'],
            rows: techRows,
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // IMPORTANT: don't read inherited widgets in initState (causes dependOnInheritedWidget errors).
    // We'll hydrate from provider in didChangeDependencies.
    _notesController = RichTextEditingController(text: widget.notes);
    // Notes = prose; no auto-bullet

    _solutions = List.from(widget.solutions); // Create mutable copy
    // Initialize with at least one empty item if solutions list is empty
    if (_solutions.isEmpty) {
      _solutions.add(AiSolutionItem(title: '', description: ''));
    }
    _techControllers = List.generate(_solutions.length, (_) {
      final controller = RichTextEditingController();
      controller.enableAutoBullet(); // Enable auto-bullet for each tech field
      return controller;
    });

    // Check admin status
    UserService.isCurrentUserAdmin().then((isAdmin) {
      if (mounted) setState(() => _isAdmin = isAdmin);
    });
    ApiKeyManager.initializeApiKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _loadExistingData();
      } catch (e) {
        debugPrint('initState error: $e');
      }

      // Only auto-generate if there is NO existing IT data with content
      // AND we have solutions to generate for
      final provider = ProjectDataInherited.maybeOf(context);
      final existingItData = provider?.projectData.itConsiderationsData;
      final hasExistingData = existingItData != null &&
          existingItData.solutionITData.isNotEmpty &&
          existingItData.solutionITData
              .any((item) => item.coreTechnology.trim().isNotEmpty);

      // Ensure _techControllers aligns with ALL solutions
      if (mounted) {
        setState(() {
          while (_techControllers.length < _solutions.length) {
            final controller = RichTextEditingController();
            controller.enableAutoBullet();
            _techControllers.add(controller);
          }
        });
      }

      if (_solutions.isNotEmpty && !hasExistingData) {
        _generateTechnologies();
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        PageHintDialog.showIfNeeded(
          context: context,
          pageId: 'it_considerations',
          title: 'IT Considerations',
          message:
              'List the core technology considerations for each potential solution. Click "Generate Technologies" to get AI suggestions tailored to each solution.',
        );
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFromProvider) return;
    _didInitFromProvider = true;

    final provider = ProjectDataInherited.maybeOf(context);
    final existingNotes = provider?.projectData.itConsiderationsData?.notes;
    if (existingNotes != null && existingNotes.trim().isNotEmpty) {
      _notesController.text = existingNotes;
    }
  }

  void _loadExistingData() {
    try {
      final provider = ProjectDataInherited.read(context);
      final itData = provider.projectData.itConsiderationsData;

      if (itData == null) return;

      // Load notes
      if (itData.notes.isNotEmpty) {
        _notesController.text = itData.notes;
      }

      // Load IT data for each solution
      final maxItems = itData.solutionITData.length;

      while (_techControllers.length < maxItems) {
        _solutions.add(AiSolutionItem(title: '', description: ''));
        final newController = RichTextEditingController();
        newController.enableAutoBullet(); // Enable auto-bullet for new field
        _techControllers.add(newController);
      }
      for (int i = 0; i < maxItems && i < _techControllers.length; i++) {
        final solutionIT = itData.solutionITData[i];
        if (i < _solutions.length) {
          _solutions[i] = AiSolutionItem(
            title: _cleanSolutionTitle(solutionIT.solutionTitle),
            description: '',
          );
        }
        _techControllers[i].text = solutionIT.coreTechnology;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading existing IT considerations data: $e');
    }
  }

  Future<void> _generateTechnologies() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final provider = ProjectDataHelper.getProvider(context);

      // Add current values to history before regenerating
      for (int i = 0;
          i < _solutions.length && i < _techControllers.length;
          i++) {
        final fieldKey = 'it_tech_${_solutions[i].title}_$i';
        provider.addFieldToHistory(fieldKey, _techControllers[i].text,
            isAiGenerated: true);
      }

      // Get project context for fallback if solutions are empty
      final projectData = provider.projectData;
      final projectName = projectData.projectName;
      final projectDescription = projectData.solutionDescription;

      // Use solutions if available, otherwise create a placeholder from project name
      final solutionsToUse = _solutions
          .where((s) => s.title.isNotEmpty || s.description.isNotEmpty)
          .toList();
      if (solutionsToUse.isEmpty && projectName.isNotEmpty) {
        solutionsToUse.add(AiSolutionItem(
          title: projectName,
          description: projectDescription,
        ));
        // Ensure we have a controller for this
        if (_techControllers.isEmpty) {
          _techControllers.add(RichTextEditingController());
        }
        if (_solutions.isEmpty) {
          _solutions.addAll(solutionsToUse);
        }
      }

      if (solutionsToUse.isEmpty) {
        setState(() {
          _error =
              'Please add at least one solution or project name to generate IT considerations.';
          _isGenerating = false;
        });
        return;
      }

      // Build context notes with project info if available
      String contextNotes = _notesController.text.trim();
      if (contextNotes.isEmpty && projectName.isNotEmpty) {
        contextNotes = 'Project: $projectName';
        if (projectDescription.isNotEmpty) {
          contextNotes += '\nDescription: $projectDescription';
        }
      }

      final map = await _openAi.generateTechnologiesForSolutions(
        solutionsToUse,
        contextNotes: contextNotes,
      );

      // Apply generated data to controllers
      for (int i = 0;
          i < solutionsToUse.length && i < _techControllers.length;
          i++) {
        final title = solutionsToUse[i].title;
        final tech = map[title] ?? const <String>[];
        _techControllers[i].text = tech.isEmpty
            ? 'Not applicable based on the current project context. Add your own IT considerations for this solution.'
            : tech.map((e) => '- $e').join('\n');
      }

      // Auto-save after regeneration
      await provider.saveToFirebase(
          checkpoint: 'it_considerations_regenerated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('IT considerations regenerated successfully')),
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
          SnackBar(content: Text('Failed to regenerate IT considerations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        // Auto-save after generation
        _saveITConsiderationsData();
      }
    }
  }

  Future<void> _regenerateAllTechnologies() async {
    await _generateTechnologies();
  }

  @override
  Widget build(BuildContext context) {
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
            Row(children: [
              DraggableSidebar(
                openWidth: sidebarWidth,
                child: const InitiationLikeSidebar(
                    activeItemLabel: 'IT Considerations'),
              ),
              Expanded(
                  child: Column(children: [
                BusinessCaseHeader(
                    scaffoldKey: _scaffoldKey, onExportPdf: _exportPdf),
                Expanded(child: _buildMainContent()),
              ])),
            ]),
            MobileSidebarHamburger(
              sidebar: const InitiationLikeSidebar(
                activeItemLabel: 'IT Considerations',
              ),
            ),
            const KazAiChatBubble(),
            const AdminEditToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileScaffold() {
    final projectName = ProjectDataHelper.getData(context).projectName.trim();
    final displayCount = _isAdmin
        ? _techControllers.length
        : (_techControllers.length > 3 ? 3 : _techControllers.length);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildMobileDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded, size: 18),
                  ),
                  const Expanded(
                    child: Text(
                      'IT Considerations',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isGenerating ? null : _regenerateAllTechnologies,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFFF59E0B), size: 18),
                    tooltip: 'Regenerate all',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 94),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${projectName.isEmpty ? 'PROJECT' : projectName.toUpperCase()} > Initiation Phase',
                      style: const TextStyle(
                        fontSize: 9.2,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'IT Considerations',
                      style: TextStyle(
                        fontSize: 37,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'List core IT considerations for each potential solution.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCE3EE)),
                      ),
                      child: VoiceTextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 6,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF374151),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter overall project IT notes here...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SOLUTION TECH BREAKDOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < displayCount; i++) ...[
                      _buildMobileSolutionCard(i),
                      const SizedBox(height: 10),
                    ],
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5F9),
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _saveITConsiderationsData();
                    if (!mounted) return;
                    _openRiskIdentification();
                  },
                  icon: const Icon(Icons.chevron_left_rounded, size: 17),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _openInfrastructureConsiderations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  child: const Text('Next Step'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSolutionCard(int index) {
    final provider = ProjectDataHelper.getProvider(context);
    final canUndo =
        provider.canUndoField('it_tech_${_solutions[index].title}_$index');
    final solution = _solutions[index];
    final title = _cleanSolutionTitle(solution.title).trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 21,
                height: 21,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Potential Solution ${index + 1}' : title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        height: 1.05,
                      ),
                    ),
                    if (solution.description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          solution.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE3EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CORE TECHNOLOGY',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _regenerateSingleTechField(
                          _techControllers[index], index),
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      tooltip: 'Regenerate field',
                    ),
                    IconButton(
                      onPressed: canUndo
                          ? () async {
                              final previous = provider.projectData.undoField(
                                  'it_tech_${_solutions[index].title}_$index');
                              if (previous != null) {
                                _techControllers[index].text = previous;
                                await provider.saveToFirebase(
                                    checkpoint: 'it_tech_undo');
                              }
                            }
                          : null,
                      icon: const Icon(Icons.undo_rounded, size: 15),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      tooltip: 'Undo',
                    ),
                  ],
                ),
                VoiceTextField(
                  controller: _techControllers[index],
                  minLines: 4,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 12.2,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        '- HTML5 for web-based interfaces\n- JavaScript frameworks ...',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopHeader() {
    final isMobile = AppBreakpoints.isMobile(context);
    return Container(
      height: isMobile ? 72 : 88,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      child: Row(children: [
        Row(children: [
          if (isMobile)
            IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          if (!isMobile)
            IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                onPressed: () => Navigator.pop(context)),
        ]),
        const Spacer(),
        if (!isMobile)
          const Text('Initiation Phase',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        const Spacer(),
        Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: const Color(0xFFD97706), shape: BoxShape.circle),
              child: const Icon(Icons.person, color: Colors.white, size: 20)),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(FirebaseAuthService.displayNameOrEmail(fallback: 'User'),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black)),
                  const Text('Owner',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
          ],
        ]),
      ]),
    );
  }

  // ignore: unused_element
  Widget _buildSidebar() {
    final isMobile = AppBreakpoints.isMobile(context);
    final double bannerHeight = isMobile ? 72 : 96;
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.withOpacity(0.25), width: 0.8),
        ),
      ),
      child: Column(children: [
        // Full-width banner image above "StackOne"
        SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: Center(child: AppLogo(height: 64)),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFFFD700), width: 1),
            ),
          ),
          child: const Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFFFD700),
              child: Icon(Icons.person_outline, color: Colors.black87),
            ),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('StackOne',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
            ])
          ]),
        ),
        Expanded(
          child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildMenuItem(Icons.home_outlined, 'Home',
                    onTap: () => HomeScreen.open(context)),
                _buildExpandableHeader(
                  Icons.flag_outlined,
                  'Initiation Phase',
                  expanded: _initiationExpanded,
                  onTap: () => setState(
                      () => _initiationExpanded = !_initiationExpanded),
                  isActive: true,
                ),
                if (_initiationExpanded) ...[
                  _buildExpandableHeader(
                    Icons.business_center_outlined,
                    'Business Case',
                    expanded: _businessCaseExpanded,
                    onTap: () => setState(
                        () => _businessCaseExpanded = !_businessCaseExpanded),
                    isActive: false,
                  ),
                  if (_businessCaseExpanded) ...[
                    _buildNestedSubMenuItem('Potential Solutions',
                        onTap: _openPotentialSolutions),
                    _buildNestedSubMenuItem('Risk Identification',
                        onTap: _openRiskIdentification),
                    _buildNestedSubMenuItem('IT Considerations',
                        isActive: true),
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
                    Icons.timeline,
                    'Initiation: Front End Planning',
                    expanded: _frontEndExpanded,
                    onTap: () =>
                        setState(() => _frontEndExpanded = !_frontEndExpanded),
                    isActive: false,
                  ),
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
                _buildMenuItem(Icons.settings_outlined, 'Settings'),
                _buildMenuItem(Icons.logout_outlined, 'LogOut'),
              ]),
        ),
      ]),
    );
  }

  Drawer _buildMobileDrawer() {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.88,
      child: const SafeArea(
        child: InitiationLikeSidebar(
          activeItemLabel: 'IT Considerations',
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {VoidCallback? onTap, bool selected = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: onTap ??
            () {
              if (title == 'LogOut') {
                AuthNav.signOutAndExit(context);
              } else if (title == 'Settings') {
                SettingsScreen.open(context);
              }
            },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: selected
              ? BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: primary, width: 3)),
                )
              : null,
          child: Row(children: [
            Icon(icon, size: 20, color: selected ? primary : Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: 14,
                    color: selected ? primary : Colors.black87,
                    fontWeight: FontWeight.w600),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
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
          child: Row(children: [
            Icon(Icons.circle,
                size: 8, color: isActive ? primary : Colors.grey[500]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      color: isActive ? primary : Colors.black87,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
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
          child: Row(children: [
            Icon(Icons.circle,
                size: 6, color: isActive ? primary : Colors.grey[400]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: isActive ? primary : Colors.black87,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
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
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
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

  void _openRiskIdentification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiskIdentificationScreen(
          notes: _notesController.text,
          solutions: widget.solutions,
        ),
      ),
    );
  }

  bool _hasRequiredItData(ProjectDataModel projectData) {
    final data = projectData.itConsiderationsData;
    if (data == null || data.solutionITData.isEmpty) return false;
    return data.solutionITData
        .any((item) => item.coreTechnology.trim().isNotEmpty);
  }

  Future<_MissingItConsiderationsAction?> _showMissingItDataDialog() {
    return showDialog<_MissingItConsiderationsAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('IT Considerations Incomplete'),
        content: const Text(
          'No IT considerations were found. Add them manually, let AI generate them, or continue and complete later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(_MissingItConsiderationsAction.manual),
            child: const Text('Add Manually'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(_MissingItConsiderationsAction.autoFill),
            child: const Text('Auto Fill with AI'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(_MissingItConsiderationsAction.skip),
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }

  List<AiSolutionItem> _resolveItSolutionsForAutofill(
    ProjectDataModel projectData,
  ) {
    final solutions = _solutions
        .where(
            (s) => s.title.trim().isNotEmpty || s.description.trim().isNotEmpty)
        .toList(growable: true);
    if (solutions.isEmpty && projectData.projectName.trim().isNotEmpty) {
      solutions.add(
        AiSolutionItem(
          title: projectData.projectName.trim(),
          description: projectData.solutionDescription.trim(),
        ),
      );
    }
    return solutions;
  }

  Future<List<_ItAutoFillPreviewRow>> _buildItAutofillPreview() async {
    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;
    final solutionsToUse = _resolveItSolutionsForAutofill(projectData);
    if (solutionsToUse.isEmpty) return const <_ItAutoFillPreviewRow>[];

    var contextNotes = _notesController.text.trim();
    if (contextNotes.isEmpty && projectData.projectName.trim().isNotEmpty) {
      contextNotes = 'Project: ${projectData.projectName.trim()}';
      if (projectData.solutionDescription.trim().isNotEmpty) {
        contextNotes +=
            '\nDescription: ${projectData.solutionDescription.trim()}';
      }
    }

    final generated = await _openAi.generateTechnologiesForSolutions(
      solutionsToUse,
      contextNotes: contextNotes,
    );

    final preview = <_ItAutoFillPreviewRow>[];
    for (var i = 0; i < solutionsToUse.length; i++) {
      final sourceTitle = solutionsToUse[i].title.trim();
      final title = _cleanSolutionTitle(sourceTitle).trim().isEmpty
          ? 'Solution ${i + 1}'
          : _cleanSolutionTitle(sourceTitle).trim();
      final suggestions = (generated[sourceTitle] ?? const <String>[])
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
      if (suggestions.isEmpty) continue;
      preview.add(_ItAutoFillPreviewRow(title: title, items: suggestions));
    }
    return preview;
  }

  Future<bool> _showItAutofillPreviewDialog(
    List<_ItAutoFillPreviewRow> previewRows,
  ) async {
    if (previewRows.isEmpty) return false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm AI Autofill'),
        content: SizedBox(
          width: 620,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review what AI will add before applying:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < previewRows.length; i++) ...[
                    Text(
                      previewRows[i].title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      previewRows[i].items.map((item) => '- $item').join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (i != previewRows.length - 1) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apply AI Suggestions'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<bool> _autoFillItWithConfirmation() async {
    if (_isGenerating) return false;
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final previewRows = await _buildItAutofillPreview();
      if (!mounted) return false;

      if (previewRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI could not generate IT suggestions. Add an entry manually or try again.',
            ),
          ),
        );
        return false;
      }

      final approved = await _showItAutofillPreviewDialog(previewRows);
      if (!mounted || !approved) return false;

      final provider = ProjectDataHelper.getProvider(context);
      setState(() {
        while (_solutions.length < previewRows.length) {
          _solutions.add(
            AiSolutionItem(
                title: previewRows[_solutions.length].title, description: ''),
          );
        }
        while (_techControllers.length < previewRows.length) {
          final controller = RichTextEditingController();
          controller.enableAutoBullet();
          _techControllers.add(controller);
        }

        for (var i = 0; i < previewRows.length; i++) {
          final row = previewRows[i];
          final previous =
              i < _techControllers.length ? _techControllers[i].text : '';
          final fieldKey = 'it_tech_${row.title}_$i';
          provider.addFieldToHistory(fieldKey, previous, isAiGenerated: true);
          _solutions[i] = AiSolutionItem(
            title: row.title,
            description: _solutions[i].description,
          );
          _techControllers[i].text =
              row.items.map((item) => '- $item').join('\n');
        }
      });

      await provider.saveToFirebase(
          checkpoint: 'it_considerations_regenerated');
      await _saveITConsiderationsData();

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI IT suggestions applied.')),
      );
      return true;
    } catch (e) {
      _error = (e.toString().contains('Failed to fetch') ||
              e.toString().contains('ClientException') ||
              e.toString().contains('XMLHttpRequest') ||
              e.toString().contains('Connection refused'))
          ? 'AI assist is being set up. Please try again later or enter content manually.'
          : e.toString();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI autofill failed: $e')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _openInfrastructureConsiderations() async {
    // 1. Save data FIRST before validation
    await _saveITConsiderationsData();
    if (!mounted) return;

    // 2. Validate data completeness
    var hasITData =
        _hasRequiredItData(ProjectDataInherited.read(context).projectData);

    if (!hasITData) {
      final action = await _showMissingItDataDialog();
      if (!mounted || action == null) return;

      if (action == _MissingItConsiderationsAction.manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Continuing without IT considerations. You can complete this later or let AI fill it in later.',
            ),
          ),
        );
      }

      if (action == _MissingItConsiderationsAction.autoFill) {
        final applied = await _autoFillItWithConfirmation();
        if (!mounted || !applied) return;
        if (!mounted) return;
        hasITData =
            _hasRequiredItData(ProjectDataInherited.read(context).projectData);
        if (!hasITData) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'AI could not generate IT considerations right now. Continuing anyway so you can complete this later.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Continuing without IT considerations. You can complete this later.',
            ),
          ),
        );
      }
    }

    // 3. Smart checkpoint check
    final nextCheckpoint =
        SidebarNavigationService.instance.getNextItem('it_considerations');
    if (nextCheckpoint?.checkpoint != 'infrastructure_considerations') {
      // Use standard lock check for non-sequential navigation
      final isLocked = ProjectDataHelper.isDestinationLocked(
          context, 'infrastructure_considerations');
      if (isLocked) {
        ProjectDataHelper.showLockedDestinationMessage(
            context, 'Infrastructure Considerations');
        return;
      }
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing IT considerations data...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1)); // Reduced delay

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfrastructureConsiderationsScreen(
          notes: _notesController.text,
          solutions: widget.solutions,
        ),
      ),
    );
  }

  Future<void> _saveITConsiderationsData() async {
    try {
      final provider = ProjectDataInherited.read(context);

      // Collect all IT data from all solutions — persist ALL rows (even empty)
      // so the saved list stays index-aligned with _solutions and load doesn't shift rows.
      final solutionITData = <SolutionITData>[];
      for (int i = 0;
          i < _solutions.length && i < _techControllers.length;
          i++) {
        final solutionTitle = _solutions[i].title.isNotEmpty
            ? _solutions[i].title
            : 'IT Entry ${i + 1}';
        final coreTechnology = _techControllers[i].text.trim();

        solutionITData.add(SolutionITData(
          solutionTitle: solutionTitle,
          coreTechnology: coreTechnology,
        ));
      }

      final itConsiderationsData = ITConsiderationsData(
        notes: _notesController.text,
        solutionITData: solutionITData,
      );

      provider.updateProjectData(
        provider.projectData
            .copyWith(itConsiderationsData: itConsiderationsData),
      );

      // Save to Firebase with checkpoint
      await provider.saveToFirebase(checkpoint: 'it_considerations');
    } catch (e) {
      debugPrint('Error saving IT considerations data: $e');
    }
  }

  void _openCoreStakeholders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoreStakeholdersScreen(
          notes: _notesController.text,
          solutions: widget.solutions,
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
          solutions: widget.solutions,
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
          solutions: widget.solutions,
          businessCase: '',
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final isMobile = AppBreakpoints.isMobile(context);
    return ScrollIndicatorOverlay(
      controller: _reviewScrollController,
      child: SingleChildScrollView(
        controller: _reviewScrollController,
        padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const EditableContentText(
                contentKey: 'it_considerations_heading',
                fallback: 'IT Considerations ',
                category: 'business_case',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            Expanded(
              child: EditableContentText(
                  contentKey: 'it_considerations_description',
                  fallback: '(List core IT considerations for each solution)',
                  category: 'business_case',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ),
            // Page-level Regenerate All button
            PageRegenerateAllButton(
              onRegenerateAll: () async {
                final confirmed = await showRegenerateAllConfirmation(context);
                if (confirmed && mounted) {
                  await _regenerateAllTechnologies();
                }
              },
              isLoading: _isGenerating,
              tooltip: 'Regenerate all IT considerations',
            ),
          ]),
          SizedBox(height: AppBreakpoints.fieldGap(context)),
          const EditableContentText(
            contentKey: 'it_considerations_notes_heading',
            fallback: 'Notes',
            category: 'business_case',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3))),
            child: VoiceTextField(
              controller: _notesController,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              decoration: InputDecoration(
                  hintText: 'Input your notes here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero),
              minLines: 1,
              maxLines: null,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.cloud_off_outlined,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed:
                              _isGenerating ? null : _generateTechnologies,
                          child: const Text('Retry')),
                    ),
                  ]),
            ),
          const SizedBox(height: 8),
          const Text('IT Considerations for each potential solution',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
          const SizedBox(height: 6),
          Text('Reminder: update text within each Core Technology box.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          if (isMobile) ...[
            Column(
                children:
                    List.generate(_techControllers.length, (i) => _row(i))),
          ] else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: const Color(0xFFE4E7EC))),
              child: const Row(children: [
                Expanded(
                    flex: 2,
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Solution',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475467))))),
                SizedBox(width: 16),
                Expanded(
                    flex: 3,
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Core Technology',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475467))))),
              ]),
            ),
            // Table body
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border.all(color: const Color(0xFFE4E7EC))),
              child: _techControllers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No solutions added yet. Add solutions from the Potential Solutions page to generate IT considerations.',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(
                          _techControllers.length, (i) => _row(i))),
            ),
          ],
          const SizedBox(height: 24),

          // Navigation Buttons
          BusinessCaseNavigationButtons(
            currentScreen: 'IT Considerations',
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
            onNext: _openInfrastructureConsiderations,
            isNextEnabled: _reviewConfirmed,
            showReviewGate: true,
            reviewConfirmed: _reviewConfirmed,
            onReviewChanged: (value) {
              setState(() => _reviewConfirmed = value);
            },
            reviewScrollController: _reviewScrollController,
          ),
        ]),
      ),
    );
  }

  String _potentialSolutionLabel(int index) {
    final number = index + 1;
    if (index < 0 || index >= _solutions.length) {
      return 'Solution $number';
    }
    final title = _cleanSolutionTitle(_solutions[index].title).trim();
    if (title.isEmpty) {
      return 'Solution $number';
    }
    return title;
  }

  static String _cleanSolutionTitle(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    // Remove legacy prefixes like:
    // "Potential Solution 1", "Potential Solution 2: Foo", etc.
    return t
        .replaceFirst(
          RegExp(r'^Potential\s+Solution\s+\d+\s*:?\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  Widget _row(int index) {
    final isMobile = AppBreakpoints.isMobile(context);
    final isStriped = index.isOdd;
    // Handle cases where we have more controllers than solutions (user added items)
    final s = index < _solutions.length
        ? _solutions[index]
        : AiSolutionItem(title: '', description: '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          color: isStriped ? const Color(0xFFF9FAFC) : Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFE4E7EC)))),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _numberBadge(index + 1),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_potentialSolutionLabel(index),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
              if (s.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(s.description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 10),
              _techTextArea(_techControllers[index], index),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _numberBadge(index + 1),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _potentialSolutionLabel(index),
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1F2937),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                        if (s.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(s.description,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
                              maxLines: 5,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis),
                        ]
                      ]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _techTextArea(_techControllers[index], index),
              ),
            ]),
    );
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text('$number',
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _techTextArea(TextEditingController controller, [int? index]) {
    final provider = ProjectDataHelper.getProvider(context);
    final idx = index ?? _techControllers.indexOf(controller);
    final solutionTitle =
        idx >= 0 && idx < _solutions.length ? _solutions[idx].title : '';
    final fieldKey = 'it_tech_${solutionTitle}_$idx';
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
        // Regenerate this specific tech field
        await _regenerateSingleTechField(controller, idx);
      },
      onUndo: () async {
        final previousValue = provider.projectData.undoField(fieldKey);
        if (previousValue != null) {
          controller.text = previousValue;
          await provider.saveToFirebase(checkpoint: 'it_tech_undo');
        }
      },
      onRedo: () async {
        final nextValue = provider.projectData.redoField(fieldKey);
        if (nextValue != null) {
          controller.text = nextValue;
          await provider.saveToFirebase(checkpoint: 'it_tech_redo');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC))),
            child: VoiceTextField(
              controller: controller,
              minLines: 3,
              maxLines: null,
              onChanged: (value) {
                provider.addFieldToHistory(fieldKey, value,
                    isAiGenerated: true);
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText:
                    'Enter core technologies specific to this solution (e.g., platforms, frameworks, databases, tools)...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF334155), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateSingleTechField(
      TextEditingController controller, int index) async {
    if (index >= _solutions.length) return;

    final provider = ProjectDataHelper.getProvider(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final solution = _solutions[index];
      final solutionsToUse = [solution];
      final contextNotes = _notesController.text.trim();

      final map = await _openAi.generateTechnologiesForSolutions(
        solutionsToUse,
        contextNotes: contextNotes,
      );
      if (!mounted) return;

      final tech = map[solution.title] ?? const <String>[];
      controller.text = tech.isEmpty ? '' : tech.map((e) => '- $e').join('\n');

      await provider.saveToFirebase(checkpoint: 'it_tech_field_regenerated');

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('IT tech field regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _reviewScrollController.dispose();
    _notesController.dispose();
    for (final c in _techControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
