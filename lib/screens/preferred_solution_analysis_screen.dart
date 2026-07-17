import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/header_banner_image.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/screens/project_decision_summary_screen.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/select_project_kaz_button.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/page_hint_dialog.dart';
import 'package:ndu_project/widgets/solution_detail_section.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class PreferredSolutionAnalysisScreen extends StatefulWidget {
  final String notes;
  final List<AiSolutionItem> solutions;
  final String businessCase;
  const PreferredSolutionAnalysisScreen(
      {super.key,
      required this.notes,
      required this.solutions,
      this.businessCase = ''});

  @override
  State<PreferredSolutionAnalysisScreen> createState() =>
      _PreferredSolutionAnalysisScreenState();
}

class _PreferredSolutionAnalysisScreenState
    extends State<PreferredSolutionAnalysisScreen>
    with SingleTickerProviderStateMixin {
  static const String _finalSelectionWarning =
      'This selection will form the basis of the entire project and cannot be changed once confirmed. Please ensure you have reviewed all options carefully.';
  static const Set<String> _authorizedSelectionRoles = {
    'admin',
    'owner',
    'project manager',
    'founder',
  };
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController _notesController;
  late List<AiSolutionItem> _solutions;
  late final OpenAiServiceSecure _openAi;
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  bool _initiationExpanded = true;
  bool _businessCaseExpanded = true;
  List<_SolutionAnalysisData> _analysis = const [];
  int? _selectedSolutionIndex;
  bool _showTableView = true; // Default to table view
  late final TextEditingController _projectNameController;
  String? _projectNameError;
  Timer? _notesSaveTimer;
  String _currentUserRole = 'Member';
  int? _expandedSolutionIndex;

  @override
  void initState() {
    super.initState();
    ApiKeyManager.initializeApiKey();
    _openAi = OpenAiServiceSecure();
    _solutions = widget.solutions.isNotEmpty
        ? widget.solutions
            .map((s) =>
                AiSolutionItem(title: s.title, description: s.description))
            .toList()
        : _fallbackSolutions();
    _tabController = TabController(length: _solutions.length, vsync: this);
    _notesController = RichTextEditingController(text: widget.notes);
    _notesController.addListener(_handleNotesChanged);
    _projectNameController = TextEditingController();
    _analysis = _solutions
        .map((s) => _SolutionAnalysisData(
              solution: s,
              stakeholders: const [],
              risks: const [],
              technologies: const [],
              infrastructure: const [],
              costs: const [],
            ))
        .toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingDataAndAnalysis().then((_) {
        if (!mounted) return;
        _resolveCurrentUserRole();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          PageHintDialog.showIfNeeded(
            context: context,
            pageId: 'preferred_solution_analysis',
            title: 'Preferred Solution Analysis',
            message:
                'Review each solution\'s analysis, then select your preferred option. Use "View More Details" to see full information before selecting. Complete this step before continuing to Work Breakdown Structure.',
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _notesSaveTimer?.cancel();
    _notesController.removeListener(_handleNotesChanged);
    _notesController.dispose();
    _projectNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDataAndAnalysis() async {
    try {
      final provider = ProjectDataHelper.getProvider(context);
      final existingData = provider.projectData.preferredSolutionAnalysis;
      final projectData = provider.projectData;

      if (existingData != null && existingData.solutionAnalyses.isNotEmpty) {
        _notesController.text = existingData.workingNotes;

        final loadedAnalyses = existingData.solutionAnalyses.map((item) {
          return _SolutionAnalysisData(
            solution: AiSolutionItem(
                title: item.solutionTitle,
                description: item.solutionDescription),
            stakeholders: item.stakeholders,
            risks: item.risks,
            technologies: item.technologies,
            infrastructure: item.infrastructure,
            costs: item.costs
                .map((c) => AiCostItem(
                      item: c.item,
                      description: c.description,
                      estimatedCost: c.estimatedCost,
                      roiPercent: c.roiPercent,
                      npvByYear: c.npvByYear,
                    ))
                .toList(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _analysis = loadedAnalyses;
            _isLoading = false;
          });
          _enrichAnalysisFromProjectData();

          // Restore selection using UUID/Index fallback
          if (existingData.selectedSolutionIndex != null &&
              existingData.selectedSolutionIndex! >= 0 &&
              existingData.selectedSolutionIndex! < _analysis.length) {
            _selectedSolutionIndex = existingData.selectedSolutionIndex;
          } else if (existingData.selectedSolutionId != null) {
            // Try to match by UUID
            for (int i = 0; i < projectData.potentialSolutions.length; i++) {
              if (projectData.potentialSolutions[i].id ==
                  existingData.selectedSolutionId) {
                if (i < _analysis.length) {
                  _selectedSolutionIndex = i;
                  break;
                }
              }
            }
          } else if (existingData.selectedSolutionTitle != null &&
              existingData.selectedSolutionTitle!.isNotEmpty) {
            // Fallback to title matching
            for (int i = 0; i < _analysis.length; i++) {
              if (_matchSolutionTitle(_analysis[i].solution.title,
                  existingData.selectedSolutionTitle!)) {
                _selectedSolutionIndex = i;
                break;
              }
            }
          }
        }
      } else {
        await _loadAnalysis();
      }
    } catch (e) {
      await _loadAnalysis();
    }
  }

  @override
  void didUpdateWidget(covariant PreferredSolutionAnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.solutions != widget.solutions ||
        oldWidget.notes != widget.notes) {
      final updatedSolutions = widget.solutions.isNotEmpty
          ? widget.solutions
              .map((s) =>
                  AiSolutionItem(title: s.title, description: s.description))
              .toList()
          : _fallbackSolutions();
      _tabController.dispose();
      setState(() {
        _solutions = updatedSolutions;
        _tabController = TabController(length: _solutions.length, vsync: this);
        _analysis = _solutions
            .map((s) => _SolutionAnalysisData(
                  solution: s,
                  stakeholders: const [],
                  risks: const [],
                  technologies: const [],
                  infrastructure: const [],
                  costs: const [],
                ))
            .toList(growable: false);
        _notesController.text = widget.notes;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalysis());
    }
  }

  List<AiSolutionItem> _fallbackSolutions() {
    return [
      AiSolutionItem(title: 'Potential Opportunity', description: 'Discipline'),
      AiSolutionItem(title: 'Potential Opportunity', description: 'Discipline'),
      AiSolutionItem(title: 'Potential Opportunity', description: 'Discipline'),
    ];
  }

  Future<void> _loadAnalysis() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = ProjectDataHelper.getProvider(context);
      final projectData = provider.projectData;
      final notes = _notesController.text.trim();
      final structuredContext = ProjectDataHelper.buildFepContext(
        projectData,
        sectionLabel: 'Preferred Solution Analysis',
      ).trim();
      final scanContext = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: 'Preferred Solution Analysis',
      ).trim();
      final combinedContext = [
        if (notes.isNotEmpty) notes,
        if (structuredContext.isNotEmpty) structuredContext,
        if (scanContext.isNotEmpty) scanContext,
      ].join('\n\n');
      final results = await Future.wait([
        _openAi.generateStakeholdersForSolutions(_solutions,
            contextNotes: combinedContext),
        _openAi.generateRisksForSolutions(_solutions,
            contextNotes: combinedContext),
        _openAi.generateTechnologiesForSolutions(_solutions,
            contextNotes: combinedContext),
        _openAi.generateInfrastructureForSolutions(_solutions,
            contextNotes: combinedContext),
        _openAi.generateCostBreakdownForSolutions(_solutions,
            contextNotes: combinedContext,
            currency: projectData.costBenefitCurrency),
      ]);

      // Stakeholders API returns Map<String, Map<String, List<String>>> with 'internal' / 'external'
      final rawStakeholders = results[0];
      final Map<String, List<String>> stakeholdersMap = {};
      if (rawStakeholders is Map<String, Map<String, List<String>>>) {
        final internal = rawStakeholders['internal'] ?? {};
        final external = rawStakeholders['external'] ?? {};
        for (final s in _solutions) {
          final key = s.title;
          final inList = internal[key] ?? const <String>[];
          final extList = external[key] ?? const <String>[];
          stakeholdersMap[key] = [...inList, ...extList];
        }
      } else if (rawStakeholders is Map<String, List<String>>) {
        for (final e in rawStakeholders.entries) {
          stakeholdersMap[e.key] = List<String>.from(e.value);
        }
      }

      final risksMap = results[1] as Map<String, List<String>>;
      final technologiesMap = results[2] as Map<String, List<String>>;
      final infrastructureMap = results[3] as Map<String, List<String>>;
      final costsMap = results[4] as Map<String, List<AiCostItem>>;

      final data = <_SolutionAnalysisData>[];
      for (var i = 0; i < _solutions.length; i++) {
        final solution = _solutions[i];
        final key = solution.title;
        data.add(
          _SolutionAnalysisData(
            solution: solution,
            stakeholders:
                List<String>.from(stakeholdersMap[key] ?? const <String>[]),
            risks: List<String>.from(risksMap[key] ?? const <String>[]),
            technologies:
                List<String>.from(technologiesMap[key] ?? const <String>[]),
            infrastructure:
                List<String>.from(infrastructureMap[key] ?? const <String>[]),
            costs: List<AiCostItem>.from(costsMap[key] ?? const <AiCostItem>[]),
            internalStakeholders: null,
            externalStakeholders: null,
            itConsiderationText: null,
            infraConsiderationText: null,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _analysis = data;
      });
      _enrichAnalysisFromProjectData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = (e.toString().contains('Failed to fetch') ||
                e.toString().contains('ClientException') ||
                e.toString().contains('XMLHttpRequest') ||
                e.toString().contains('Connection refused'))
            ? 'AI assist is being set up. Please try again later or enter content manually.'
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static bool _matchSolutionTitle(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    return x.isNotEmpty && y.isNotEmpty && x == y;
  }

  String _normalizeRole(String role) {
    final lower = role.trim().toLowerCase();
    if (lower == 'administrator') {
      return 'admin';
    }
    if (lower == 'project_manager' || lower == 'project manager') {
      return 'project manager';
    }
    return lower;
  }

  bool _isUserAuthorizedToFinalize() {
    return _authorizedSelectionRoles.contains(_normalizeRole(_currentUserRole));
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

  Future<void> _resolveCurrentUserRole() async {
    String resolvedRole = 'Member';

    try {
      final user = FirebaseAuth.instance.currentUser;
      final provider = ProjectDataHelper.getProvider(context);
      final projectData = provider.projectData;
      final email = user?.email?.trim().toLowerCase() ?? '';
      final uid = user?.uid ?? '';
      final displayName =
          FirebaseAuthService.displayNameOrEmail(fallback: '').trim();

      final isAdmin = await UserService.isCurrentUserAdmin();
      if (isAdmin) {
        resolvedRole = 'Admin';
      } else {
        final projectId = projectData.projectId?.trim() ?? '';
        if (uid.isNotEmpty && projectId.isNotEmpty) {
          final project = await ProjectService.getProjectById(projectId);
          if (project != null) {
            final ownerEmail = project.ownerEmail.trim().toLowerCase();
            if (project.ownerId == uid ||
                (email.isNotEmpty && ownerEmail == email)) {
              resolvedRole = 'Owner';
            }
          }
        }

        if (!_authorizedSelectionRoles.contains(_normalizeRole(resolvedRole))) {
          for (final member in projectData.teamMembers) {
            final memberEmail = member.email.trim().toLowerCase();
            final memberName = member.name.trim().toLowerCase();
            final role = member.role.trim();
            final matchesByEmail = email.isNotEmpty &&
                memberEmail.isNotEmpty &&
                memberEmail == email;
            final matchesByName = displayName.isNotEmpty &&
                memberName.isNotEmpty &&
                memberName == displayName.toLowerCase();

            if ((matchesByEmail || matchesByName) && role.isNotEmpty) {
              resolvedRole = role;
              break;
            }
          }
        }

        if (!_authorizedSelectionRoles.contains(_normalizeRole(resolvedRole))) {
          final pmName = projectData.charterProjectManagerName.trim();
          if (_matchesIdentity(pmName, displayName, email)) {
            resolvedRole = 'Project Manager';
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving user role: $e');
    }

    if (!mounted) return;
    setState(() {
      _currentUserRole = resolvedRole;
    });
  }

  Future<void> _exportPdf() async {
    final notes = _notesController.text.trim();
    final sections = <PdfSection>[
      PdfSection.text(
          'Working Notes', notes.isEmpty ? 'No data recorded.' : notes),
    ];
    if (_selectedSolutionIndex != null &&
        _selectedSolutionIndex! < _analysis.length) {
      sections.add(PdfSection.keyValue('Selected Solution', [
        {'Solution': _analysis[_selectedSolutionIndex!].solution.title},
      ]));
    }
    for (int i = 0; i < _analysis.length; i++) {
      final a = _analysis[i];
      final label = a.solution.title.trim().isEmpty
          ? 'Solution ${i + 1}'
          : a.solution.title.trim();
      final rows = <List<String>>[];
      if (a.stakeholders.isNotEmpty) {
        for (final s in a.stakeholders) {
          rows.add(['Stakeholder', s]);
        }
      }
      if (a.risks.isNotEmpty) {
        for (final r in a.risks) {
          rows.add(['Risk', r]);
        }
      }
      if (a.technologies.isNotEmpty) {
        for (final t in a.technologies) {
          rows.add(['Technology', t]);
        }
      }
      if (a.infrastructure.isNotEmpty) {
        for (final inf in a.infrastructure) {
          rows.add(['Infrastructure', inf]);
        }
      }
      if (a.costs.isNotEmpty) {
        for (final c in a.costs) {
          rows.add([
            'Cost: ${c.item}',
            '${c.estimatedCost > 0 ? c.estimatedCost : "N/A"}'
          ]);
        }
      }
      sections.add(PdfSection.table(
        label,
        headers: ['Category', 'Detail'],
        rows: rows.isEmpty ? [] : rows,
      ));
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Preferred Solution Analysis',
      sections: sections,
    );
  }

  static List<String> _lines(String s) {
    if (s.trim().isEmpty) return [];
    return s
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _enrichAnalysisFromProjectData() {
    if (!mounted) return;
    final projectData = ProjectDataHelper.getData(context);
    final enriched = <_SolutionAnalysisData>[];
    for (int i = 0; i < _analysis.length; i++) {
      final item = _analysis[i];
      final title = item.solution.title;
      List<String>? risks;
      List<String>? stakeholders;
      List<String>? internalSh;
      List<String>? externalSh;
      String? itText;
      String? infraText;
      List<AiCostItem>? cbaCosts;

      for (final sr in projectData.solutionRisks) {
        if (_matchSolutionTitle(sr.solutionTitle, title)) {
          risks =
              sr.risks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          break;
        }
      }
      final itData = projectData.itConsiderationsData?.solutionITData ?? [];
      for (final it in itData) {
        if (_matchSolutionTitle(it.solutionTitle, title)) {
          itText = it.coreTechnology.trim();
          if (itText.isEmpty) itText = null;
          break;
        }
      }
      final infraData = projectData
              .infrastructureConsiderationsData?.solutionInfrastructureData ??
          [];
      for (final inf in infraData) {
        if (_matchSolutionTitle(inf.solutionTitle, title)) {
          infraText = inf.majorInfrastructure.trim();
          if (infraText.isEmpty) infraText = null;
          break;
        }
      }
      final shData =
          projectData.coreStakeholdersData?.solutionStakeholderData ?? [];
      for (final sh in shData) {
        if (_matchSolutionTitle(sh.solutionTitle, title)) {
          internalSh = _lines(sh.internalStakeholders);
          externalSh = _lines(sh.externalStakeholders);
          final notable = _lines(sh.notableStakeholders);
          stakeholders = [...notable, ...internalSh, ...externalSh];
          if (stakeholders.isEmpty) stakeholders = null;
          break;
        }
      }

      cbaCosts = _buildCostsFromCostAnalysis(
        projectData,
        title,
        solutionIndex: i,
      );

      enriched.add(_SolutionAnalysisData(
        solution: item.solution,
        stakeholders: stakeholders ?? item.stakeholders,
        risks: risks ?? item.risks,
        technologies: item.technologies,
        infrastructure: item.infrastructure,
        costs: cbaCosts ?? item.costs,
        internalStakeholders: internalSh,
        externalStakeholders: externalSh,
        itConsiderationText: itText ?? item.itConsiderationText,
        infraConsiderationText: infraText ?? item.infraConsiderationText,
      ));
    }
    if (!mounted) return;
    setState(() {
      _analysis = enriched;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isMobile = AppBreakpoints.isMobile(context);
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile
          ? const Drawer(
              child: InitiationLikeSidebar(
                  activeItemLabel: 'Preferred Solution Analysis'))
          : null,
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Row(children: [
              DraggableSidebar(
                openWidth: sidebarWidth,
                child: const InitiationLikeSidebar(
                    activeItemLabel: 'Preferred Solution Analysis'),
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
                activeItemLabel: 'Preferred Solution Analysis',
              ),
            ),
            const KazAiChatBubble(),
            const AdminEditToggle(),
          ],
        ),
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
      child: Row(children: [
        Row(children: [
          if (isMobile)
            IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          if (!isMobile) ...[
            IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                onPressed: () => Navigator.pop(context)),
          ],
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
                  color: Colors.blue, shape: BoxShape.circle),
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
    // Match CostAnalysisScreen sidebar styling and structure
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    // Keep banner height consistent with other initiation-like sidebars
    final double bannerHeight = AppBreakpoints.isMobile(context) ? 72 : 96;
    return Container(
      width: sidebarWidth,
      color: Colors.white,
      child: Column(
        children: [
          // Full-width banner image above "StackOne"
          SizedBox(
            width: double.infinity,
            height: bannerHeight,
            child: const HeaderBannerImage(),
          ),
          Builder(
            builder: (builderContext) {
              final provider = ProjectDataHelper.getProvider(builderContext);
              final projectName = provider.projectData.projectName;
              final displayName =
                  (projectName.isNotEmpty) ? projectName : 'Untitled Project';

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFFFD700), width: 1)),
                ),
                child: Text(
                  displayName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
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
                  _buildExpandableHeaderLikeCost(
                    Icons.business_center_outlined,
                    'Business Case',
                    expanded: _businessCaseExpanded,
                    onTap: () => setState(
                        () => _businessCaseExpanded = !_businessCaseExpanded),
                    isActive: false,
                  ),
                  if (_businessCaseExpanded) ...[
                    _buildNestedSubMenuItem('Business Case',
                        onTap: _openBusinessCase),
                    _buildNestedSubMenuItem('Potential Solutions',
                        onTap: _openPotentialSolutions),
                    _buildNestedSubMenuItem('Risk Identification',
                        onTap: _openRiskIdentification),
                    _buildNestedSubMenuItem('IT Considerations',
                        onTap: _openITConsiderations),
                    _buildNestedSubMenuItem('Infrastructure Considerations',
                        onTap: _openInfrastructureConsiderations),
                    _buildNestedSubMenuItem('Core Stakeholders',
                        onTap: _openCoreStakeholders),
                    _buildNestedSubMenuItem('Initial Cost Estimate',
                        onTap: _openCostAnalysis),
                    _buildNestedSubMenuItem('Preferred Solution Analysis',
                        isActive: true),
                  ],
                ],
                _buildMenuItem(
                    Icons.timeline, 'Initiation: Front End Planning'),
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

  // ignore: unused_element
  Drawer _buildMobileDrawer() {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.88,
      child: const SafeArea(
        child: InitiationLikeSidebar(
          activeItemLabel: 'Preferred Solution Analysis',
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {bool disabled = false, VoidCallback? onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon,
                size: 20,
                color: isActive
                    ? primary
                    : (disabled ? Colors.grey[400] : Colors.black87)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive
                      ? primary
                      : (disabled ? Colors.grey[500] : Colors.black87),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
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
          child: Row(children: [
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
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[700], size: 20),
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

  Widget _buildExpandableHeaderLikeCost(IconData icon, String title,
      {required bool expanded,
      required VoidCallback onTap,
      bool isActive = false}) {
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
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[600], size: 18),
          ]),
        ),
      ),
    );
  }

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
          ]),
        ),
      ),
    );
  }

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
          solutions: _solutions,
          businessCase: widget.businessCase,
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

  void _openCostAnalysisForSolution(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CostAnalysisScreen(
          notes: _notesController.text,
          solutions: _solutions,
          initialStepIndex: 1,
          initialSolutionIndex: index,
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppBreakpoints.pagePadding(context),
            right: AppBreakpoints.pagePadding(context),
            top: 0,
            bottom: 100,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Breadcrumbs
            _buildBreadcrumbs(),
            const SizedBox(height: 16),
            // Section title & description
            _buildHeaderRow(),
            const SizedBox(height: 12),
            // Authorized banner
            if (_isUserAuthorizedToFinalize()) _buildAuthorizedBanner(),
            if (_isUserAuthorizedToFinalize()) const SizedBox(height: 12),
            if (_isLoading) _buildLoadingBlock(),
            if (!_isLoading && _error != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 16),
            ],
            if (!_isLoading) ...[
              _showTableView ? _buildTabSection() : _buildCardBasedView(),
              const SizedBox(height: 16),
              // Selection summary
              _buildSelectionSummary(),
              const SizedBox(height: 16),
              // Action links row
              _buildActionLinksRow(),
              const SizedBox(height: 16),
              // Working notes
              _buildNotesField(),
              const SizedBox(height: 24),
            ],
            if (_isLoading) const SizedBox(height: 24),
          ]),
        ),
        // Fixed bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildFixedFooter(),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs() {
    final provider = ProjectDataHelper.getProvider(context);
    final projectName = provider.projectData.projectName.trim().isNotEmpty
        ? provider.projectData.projectName.trim()
        : 'Untitled Project';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_left, size: 18, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Preferred Solution - $projectName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            const Spacer(),
            // Next button
            ElevatedButton.icon(
              onPressed: _analysis.isEmpty ? null : _handleNextToSelectionPage,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF1a1a1a),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _effectiveSelectedSolutionIndex() {
    if (_selectedSolutionIndex != null &&
        _selectedSolutionIndex! >= 0 &&
        _selectedSolutionIndex! < _analysis.length) {
      return _selectedSolutionIndex;
    }

    final projectData = ProjectDataHelper.getData(context);
    final preferred = projectData.preferredSolutionAnalysis;
    if (preferred?.selectedSolutionIndex != null) {
      final index = preferred!.selectedSolutionIndex!;
      if (index >= 0 && index < _analysis.length) {
        return index;
      }
    }

    final selectedTitle = preferred?.selectedSolutionTitle?.trim() ?? '';
    if (selectedTitle.isNotEmpty) {
      for (int i = 0; i < _analysis.length; i++) {
        if (_matchSolutionTitle(_analysis[i].solution.title, selectedTitle)) {
          return i;
        }
      }
    }

    return null;
  }

  Widget _buildBottomPreferredActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Step',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Review all potential solutions and select preferred option.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _analysis.isEmpty ? null : _handleNextToSelectionPage,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveSolutionIdForIndex(
      ProjectDataModel projectData, int index, String solutionTitle) {
    if (index >= 0 && index < projectData.potentialSolutions.length) {
      return projectData.potentialSolutions[index].id;
    }

    for (final solution in projectData.potentialSolutions) {
      if (_matchSolutionTitle(solution.title, solutionTitle)) {
        final id = solution.id.trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<bool> _persistPreferredSelection({
    required int index,
    bool showSuccessMessage = true,
    bool finalizeSelection = false,
  }) async {
    if (index < 0 || index >= _analysis.length) return false;
    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;
    final currentAnalysis = projectData.preferredSolutionAnalysis;
    final analysis = _analysis[index];

    if (currentAnalysis?.isSelectionFinalized == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preferred solution is already finalized and cannot be changed.',
            ),
          ),
        );
      }
      return false;
    }

    final solutionId = _resolveSolutionIdForIndex(
      projectData,
      index,
      analysis.solution.title,
    );

    if (solutionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not match solution to save selection.',
            ),
          ),
        );
      }
      return false;
    }

    await provider.setPreferredSolution(
      solutionId,
      checkpoint: 'preferred_solution_selected',
    );

    final updatedAnalysis = PreferredSolutionAnalysis(
      workingNotes:
          currentAnalysis?.workingNotes ?? _notesController.text.trim(),
      solutionAnalyses: currentAnalysis?.solutionAnalyses ?? const [],
      selectedSolutionTitle: analysis.solution.title,
      selectedSolutionId: solutionId,
      selectedSolutionIndex: index,
      isSelectionFinalized:
          finalizeSelection || (currentAnalysis?.isSelectionFinalized ?? false),
    );

    provider.updateField((data) => data.copyWith(
          preferredSolutionAnalysis: updatedAnalysis,
        ));
    await provider.saveToFirebase(checkpoint: 'preferred_solution_selected');

    if (mounted) {
      setState(() {
        _selectedSolutionIndex = index;
      });
      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(finalizeSelection
                  ? 'Preferred solution finalized'
                  : 'Preferred solution saved')),
        );
      }
    }
    return true;
  }

  Future<void> _openPreferredSelectionPage({int? preferredIndex}) async {
    await _saveAnalysisData();
    if (!mounted) return;

    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;
    final allSolutions = _analysis
        .map((item) => AiSolutionItem(
              title: item.solution.title,
              description: item.solution.description,
            ))
        .toList(growable: false);

    if (allSolutions.isEmpty) return;

    final safeIndex = (preferredIndex ?? _effectiveSelectedSolutionIndex() ?? 0)
        .clamp(0, allSolutions.length - 1)
        .toInt();
    final selectedSolution = allSolutions[safeIndex];
    final projectName = projectData.projectName.trim().isNotEmpty
        ? projectData.projectName.trim()
        : selectedSolution.title;
    final businessCase = projectData.businessCase.trim().isNotEmpty
        ? projectData.businessCase.trim()
        : widget.businessCase.trim();

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDecisionSummaryScreen(
          projectName: projectName.isEmpty ? 'Untitled Project' : projectName,
          selectedSolution: selectedSolution,
          allSolutions: allSolutions,
          businessCase: businessCase,
          notes: _notesController.text.trim(),
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _handleBottomSelectPreferred() async {
    final selectedIndex = _effectiveSelectedSolutionIndex();
    if (selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a solution first')),
      );
      return;
    }

    setState(() {
      _isSavingPreferredSelection = true;
      _savingPreferredIndex = selectedIndex;
    });
    try {
      await _persistPreferredSelection(index: selectedIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferred solution: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPreferredSelection = false;
          _savingPreferredIndex = null;
        });
      }
    }
  }

  // ignore: unused_element
  Future<void> _showPreferredSelectionDialog() async {
    await _resolveCurrentUserRole();
    if (!mounted) return;

    final provider = ProjectDataHelper.getProvider(context);
    final finalized =
        provider.projectData.preferredSolutionAnalysis?.isSelectionFinalized ==
            true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Preferred Solution',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  finalized
                      ? 'Preferred solution is already finalized. You can only view details.'
                      : 'Select one solution for preferred status. You can review full details for each option before selecting.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: _analysis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final solution = _analysis[index].solution;
                      final title = solution.title.trim().isNotEmpty
                          ? solution.title
                          : 'Solution ${index + 1}';
                      final selected =
                          _effectiveSelectedSolutionIndex() == index;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solution ${index + 1}: $title',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (solution.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                solution.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _navigateToSolutionDetails(index);
                                  },
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 18),
                                  label: const Text('View This Solution'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: finalized
                                      ? null
                                      : () async {
                                          Navigator.of(context).pop();
                                          await _attemptSelectPreferredFromDialog(
                                              index: index);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD700),
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 18),
                                  label: const Text(
                                      'Select as Preferred Solution'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _attemptSelectPreferredFromDialog({required int index}) async {
    if (!_isUserAuthorizedToFinalize()) {
      _showAuthorizationBlockedDialog();
      return;
    }
    await _showFinalPreferredConfirmation(index: index);
  }

  void _showAuthorizationBlockedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selection Blocked'),
        content: Text(
          'Only Owner, Project Manager, or Founder can finalize preferred solution selection.\n\nYour current role: $_currentUserRole',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFinalPreferredConfirmation({required int index}) async {
    if (index < 0 || index >= _analysis.length) return;
    bool authorityChecked = false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Finalize Preferred Solution'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _finalSelectionWarning,
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: authorityChecked,
                    onChanged: (value) {
                      setModalState(() {
                        authorityChecked = value ?? false;
                      });
                    },
                    title: const Text(
                      'I have the authority to select a preferred solution and have aligned with stakeholders.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: authorityChecked
                    ? () => Navigator.of(context).pop(true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                child: const Text('Proceed with this Preferred Solution'),
              ),
            ],
          );
        },
      ),
    );

    if (proceed != true || !mounted) return;

    setState(() {
      _isSavingPreferredSelection = true;
      _savingPreferredIndex = index;
    });
    try {
      await _persistPreferredSelection(
        index: index,
        showSuccessMessage: true,
        finalizeSelection: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferred solution: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPreferredSelection = false;
          _savingPreferredIndex = null;
        });
      }
    }
  }

  Future<void> _handleNextToSelectionPage() async {
    final preferredIndex = _effectiveSelectedSolutionIndex();
    await _openPreferredSelectionPage(preferredIndex: preferredIndex);
  }

  // ignore: unused_element
  Widget _buildNextButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _handleNextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text(
            'Next',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _handleNextStep() async {
    // Save all data to Firebase
    await _saveAnalysisData();

    // Show 3-second loading dialog
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFD700)),
            SizedBox(height: 16),
            Text(
              'Saving your progress...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;
    FrontEndPlanningSummaryScreen.open(context);
  }

  Widget _buildHeaderRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Preferred Solution Selection',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a1a1a))),
        SizedBox(height: 4),
        Text('Review all potential solutions and select preferred option.',
            style:
                TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4)),
      ],
    );
  }

  Future<void> _confirmRegenerateAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate All Solutions'),
        content: const Text(
          'This will regenerate all KAZ AI-generated solution analysis on this page. Your current content will be lost. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _regenerateAllAnalysis();
    }
  }

  Future<void> _regenerateAllAnalysis() async {
    setState(() => _isLoading = true);
    try {
      await _loadExistingDataAndAnalysis();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All solutions regenerated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element
  Widget _buildSelectedSolutionIndicator(ProjectDataModel projectData) {
    final preferredAnalysis = projectData.preferredSolutionAnalysis;
    final selectedTitle = preferredAnalysis?.selectedSolutionTitle ?? '';
    final selectedIndex = preferredAnalysis?.selectedSolutionIndex;

    if (selectedTitle.isEmpty) return const SizedBox.shrink();

    // Find the selected solution number
    int? solutionNumber;
    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < _analysis.length) {
      solutionNumber = selectedIndex + 1;
    } else {
      // Try to find by title match
      for (int i = 0; i < _analysis.length; i++) {
        if (_matchSolutionTitle(_analysis[i].solution.title, selectedTitle)) {
          solutionNumber = i + 1;
          break;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFFFFD700),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Solution Selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  solutionNumber != null
                      ? 'Solution #$solutionNumber: $selectedTitle'
                      : selectedTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF424242),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Working notes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1a1a1a))),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Format',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              VoiceTextField(
                controller: _notesController,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1a1a1a)),
                decoration: const InputDecoration(
                    hintText:
                        'Capture rationale, assumptions, or follow-ups here...',
                    hintStyle:
                        TextStyle(color: Color(0xFF666666), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.all(12)),
                minLines: 4,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleNotesChanged() {
    if (!mounted) return;
    final provider = ProjectDataHelper.getProvider(context);
    final current = provider.projectData.preferredSolutionAnalysis;
    final updated = PreferredSolutionAnalysis(
      workingNotes: _notesController.text,
      solutionAnalyses: current?.solutionAnalyses ?? const [],
      selectedSolutionTitle: current?.selectedSolutionTitle,
      selectedSolutionId: current?.selectedSolutionId,
      selectedSolutionIndex: current?.selectedSolutionIndex,
      isSelectionFinalized: current?.isSelectionFinalized ?? false,
    );

    provider.updateField((data) => data.copyWith(
          preferredSolutionAnalysis: updated,
        ));

    _notesSaveTimer?.cancel();
    _notesSaveTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _saveAnalysisData();
    });
  }

  Widget _buildLoadingBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.2))),
      child: Row(children: const [
        SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3)),
        SizedBox(width: 16),
        Expanded(
            child: Text(
                'Gathering stakeholders, risks, and cost insights for each solution...',
                style: TextStyle(fontSize: 14))),
      ]),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                _error ?? 'Unable to refresh analysis details right now.',
                style: const TextStyle(fontSize: 13, color: Colors.red))),
        TextButton(
            onPressed: _isLoading ? null : _loadAnalysis,
            child: const Text('Retry')),
      ]),
    );
  }

  // ignore: unused_element
  Widget _buildTabSection() {
    if (_analysis.isEmpty) {
      return _buildEmptyState();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.25))),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          tabs: List.generate(_analysis.length, (index) {
            final solution = _analysis[index].solution;
            final label = solution.title.isNotEmpty
                ? solution.title
                : 'Solution ${index + 1}';
            return Tab(text: label);
          }),
        ),
      ),
      const SizedBox(height: 18),
      AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final safeIndex = (_analysis.isEmpty ? 0 : _tabController.index)
              .clamp(0, _analysis.length - 1);
          final data = _analysis[safeIndex];
          return _buildSolutionDetail(data: data, index: safeIndex);
        },
      ),
    ]);
  }

  Widget _buildSolutionDetail(
      {required _SolutionAnalysisData data, required int index}) {
    final title = data.solution.title.isNotEmpty
        ? data.solution.title
        : 'Solution ${index + 1}';
    final description = data.solution.description.isNotEmpty
        ? data.solution.description
        : 'Discipline';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(description,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black54)),
              ])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(
              onPressed: () => _showViewMoreDetails(context, data, index),
              icon: const Icon(Icons.read_more, size: 18),
              label: const Text('View More Details'),
            ),
            const _AiTag(),
          ]),
        ]),
        const SizedBox(height: 20),
        _buildSectionBlock(title: 'Key stakeholders', items: data.stakeholders),
        const SizedBox(height: 20),
        _buildSectionBlock(title: 'Top risks', items: data.risks),
        if (data.technologies.any((e) => e.trim().isNotEmpty)) ...[
          const SizedBox(height: 20),
          _buildSectionBlock(
              title: 'IT consideration', items: data.technologies),
        ],
        if (data.infrastructure.any((e) => e.trim().isNotEmpty)) ...[
          const SizedBox(height: 20),
          _buildSectionBlock(
              title: 'Infrastructure consideration',
              items: data.infrastructure),
        ],
        const SizedBox(height: 20),
        _buildCostsSection(data.costs),
      ]),
    );
  }

  static const Map<String, String> _costCategoryLabels = {
    'revenue': 'Revenue',
    'cost_saving': 'Cost Saving',
    'ops_efficiency': 'Operations Efficiency',
    'productivity': 'Productivity',
    'regulatory_compliance': 'Regulatory & Compliance',
    'process_improvement': 'Process Improvement',
    'brand_image': 'Brand Image',
    'stakeholder_commitment': 'Stakeholder Commitment',
    'other': 'Other',
  };

  String _normalizedTitle(String value) => value.trim().toLowerCase();

  bool _hasMeaningfulCostRow(CostRowData row) {
    final hasName = row.itemName.trim().isNotEmpty;
    final hasDescription = row.description.trim().isNotEmpty;
    final hasAssumptions = row.assumptions.trim().isNotEmpty;
    final hasCost = _parseNumericAmount(row.cost) > 0;
    return hasName || hasDescription || hasAssumptions || hasCost;
  }

  List<CostRowData> _meaningfulRows(List<CostRowData> rows) =>
      rows.where(_hasMeaningfulCostRow).toList(growable: false);

  List<CostRowData> _categoryRowsFromCostAnalysis(
    ProjectDataModel projectData,
    String solutionTitle, {
    int? solutionIndex,
  }) {
    final cba = projectData.costAnalysisData;
    if (cba == null) return const [];

    SolutionCategoryCostData? categoryData;
    for (final item in cba.solutionCategoryCosts) {
      if (_matchSolutionTitle(item.solutionTitle, solutionTitle)) {
        categoryData = item;
        break;
      }
    }

    if (categoryData == null &&
        solutionIndex != null &&
        solutionIndex >= 0 &&
        solutionIndex < cba.solutionCategoryCosts.length) {
      categoryData = cba.solutionCategoryCosts[solutionIndex];
    }

    if (categoryData == null) return const [];

    final rows = <CostRowData>[];
    for (final entry in categoryData.categoryCosts.entries) {
      final rawCost = entry.value.trim();
      if (rawCost.isEmpty) continue;
      final parsedCost = _parseNumericAmount(rawCost);
      if (parsedCost <= 0) continue;
      final label = _costCategoryLabels[entry.key] ?? entry.key;
      final note = categoryData.categoryNotes[entry.key]?.trim() ?? '';
      rows.add(
        CostRowData(
          itemName: '$label estimate',
          description: 'Initial cost estimate category',
          cost: rawCost,
          assumptions: note,
        ),
      );
    }
    return rows;
  }

  List<CostRowData> _getCbaCostRowsForSolution(
    ProjectDataModel projectData,
    String solutionTitle, {
    int? solutionIndex,
  }) {
    final cba = projectData.costAnalysisData;
    if (cba == null) return const [];

    final normalized = _normalizedTitle(solutionTitle);
    final solutionCosts = cba.solutionCosts;

    for (final solutionCost in solutionCosts) {
      if (_normalizedTitle(solutionCost.solutionTitle) != normalized) continue;
      final rows = _meaningfulRows(solutionCost.costRows);
      if (rows.isNotEmpty) return rows;
    }

    if (solutionIndex != null &&
        solutionIndex >= 0 &&
        solutionIndex < solutionCosts.length) {
      final indexedRows =
          _meaningfulRows(solutionCosts[solutionIndex].costRows);
      if (indexedRows.isNotEmpty) return indexedRows;
    }

    if (solutionIndex != null &&
        solutionIndex >= 0 &&
        solutionIndex < projectData.potentialSolutions.length) {
      final potentialTitle =
          projectData.potentialSolutions[solutionIndex].title;
      for (final solutionCost in solutionCosts) {
        if (!_matchSolutionTitle(solutionCost.solutionTitle, potentialTitle)) {
          continue;
        }
        final rows = _meaningfulRows(solutionCost.costRows);
        if (rows.isNotEmpty) return rows;
      }
    }

    return _categoryRowsFromCostAnalysis(
      projectData,
      solutionTitle,
      solutionIndex: solutionIndex,
    );
  }

  double _parseNumericAmount(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(sanitized) ?? 0.0;
  }

  double _annualizeProjectValue(double value, String? basisFrequency) {
    if (value <= 0) return 0;
    switch ((basisFrequency ?? '').trim().toLowerCase()) {
      case 'monthly':
        return value * 12;
      case 'quarterly':
        return value * 4;
      default:
        return value;
    }
  }

  double _benefitTotalFromLineItems(CostAnalysisData cba) {
    double total = 0.0;
    for (final item in cba.benefitLineItems) {
      final unitValue = _parseNumericAmount(item.unitValue);
      final units = _parseNumericAmount(item.units);
      final value = unitValue * units;
      if (value <= 0) continue;
      total += cba.trackerBasisFrequency == 'Monthly' ? value * 12 : value;
    }
    return total;
  }

  double _benefitTotalForSolution(
    ProjectDataModel projectData,
    String solutionTitle, {
    int? solutionIndex,
  }) {
    final cba = projectData.costAnalysisData;
    if (cba == null) return 0.0;

    SolutionProjectBenefitData? matchedSolutionBenefit;
    for (final entry in cba.solutionProjectBenefits) {
      if (_matchSolutionTitle(entry.solutionTitle, solutionTitle)) {
        matchedSolutionBenefit = entry;
        break;
      }
    }
    if (matchedSolutionBenefit == null &&
        solutionIndex != null &&
        solutionIndex >= 0 &&
        solutionIndex < cba.solutionProjectBenefits.length) {
      matchedSolutionBenefit = cba.solutionProjectBenefits[solutionIndex];
    }
    matchedSolutionBenefit ??=
        SolutionProjectBenefitData(solutionTitle: solutionTitle);

    final solutionProjectValue = _annualizeProjectValue(
      _parseNumericAmount(matchedSolutionBenefit.projectValueAmount),
      cba.basisFrequency,
    );
    if (solutionProjectValue > 0) {
      return solutionProjectValue;
    }

    final legacyProjectValue = _annualizeProjectValue(
      _parseNumericAmount(cba.projectValueAmount),
      cba.basisFrequency,
    );
    if (legacyProjectValue > 0) {
      return legacyProjectValue;
    }

    if (matchedSolutionBenefit.projectBenefits.isNotEmpty) {
      double total = 0.0;
      for (final item in matchedSolutionBenefit.projectBenefits) {
        final unitValue = _parseNumericAmount(item.unitValue);
        final units = _parseNumericAmount(item.units);
        final value = unitValue * units;
        if (value <= 0) continue;
        total += cba.trackerBasisFrequency == 'Monthly' ? value * 12 : value;
      }
      if (total > 0) {
        return total;
      }
    }

    return _benefitTotalFromLineItems(cba);
  }

  double _solutionNpv({
    required double totalCost,
    required double totalBenefits,
    int horizonYears = 5,
    double discountRate = 0.10,
  }) {
    if (totalCost <= 0 || totalBenefits <= 0 || horizonYears <= 0) {
      return 0.0;
    }
    final annualBenefit = totalBenefits / horizonYears;
    double npv = -totalCost;
    for (int year = 1; year <= horizonYears; year++) {
      npv += annualBenefit / math.pow(1 + discountRate, year);
    }
    return npv;
  }

  List<AiCostItem>? _buildCostsFromCostAnalysis(
    ProjectDataModel projectData,
    String solutionTitle, {
    int? solutionIndex,
  }) {
    final cbaRows = _getCbaCostRowsForSolution(
      projectData,
      solutionTitle,
      solutionIndex: solutionIndex,
    );
    if (cbaRows.isEmpty) return null;

    final totalCost = cbaRows.fold<double>(
      0.0,
      (sum, row) => sum + _parseNumericAmount(row.cost),
    );
    final totalBenefits = _benefitTotalForSolution(
      projectData,
      solutionTitle,
      solutionIndex: solutionIndex,
    );
    final roi = (totalCost > 0 && totalBenefits > 0)
        ? ((totalBenefits - totalCost) / totalCost) * 100
        : 0.0;
    final npv5 = _solutionNpv(
      totalCost: totalCost,
      totalBenefits: totalBenefits,
      horizonYears: 5,
    );

    return cbaRows
        .map(
          (row) => AiCostItem(
            item: row.itemName.trim().isEmpty ? 'Cost item' : row.itemName,
            description: row.description,
            estimatedCost: _parseNumericAmount(row.cost),
            roiPercent: roi,
            npvByYear: {5: npv5},
          ),
        )
        .toList(growable: false);
  }

  void _showViewMoreDetails(
      BuildContext context, _SolutionAnalysisData data, int index) {
    final title = data.solution.title.isNotEmpty
        ? data.solution.title
        : 'Solution ${index + 1}';
    final projectData = ProjectDataHelper.getData(context);
    final cbaRows = _getCbaCostRowsForSolution(
      projectData,
      data.solution.title,
      solutionIndex: index,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 860),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.solution.description.isNotEmpty)
                        _buildDetailSectionCard(
                          title: 'Description',
                          child: Text(data.solution.description,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Colors.black87)),
                        ),
                      _buildDetailSectionCard(
                        title: 'Risk information',
                        child: _buildDetailList(data.risks),
                      ),
                      _buildDetailSectionCard(
                        title: 'IT consideration',
                        child: _buildITOrInfraContent(
                          data.itConsiderationText,
                          data.technologies,
                        ),
                      ),
                      _buildDetailSectionCard(
                        title: 'Infrastructure consideration',
                        child: _buildITOrInfraContent(
                          data.infraConsiderationText,
                          data.infrastructure,
                        ),
                      ),
                      _buildDetailSectionCard(
                        title: 'Core stakeholders',
                        child: _buildStakeholdersDetail(data),
                      ),
                      _buildCostBenefitSection(cbaRows),
                      _buildDetailSectionCard(
                        title: 'Investment overview (AI)',
                        child: _buildInvestmentOverviewBody(data.costs),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSectionCard(
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCostBenefitSection(List<CostRowData> cbaRows) {
    if (cbaRows.isEmpty) {
      return _buildDetailSectionCard(
        title: 'Cost benefit & financial metrics',
        child: const Text(
          'No cost benefit analysis captured yet.',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
      );
    }
    return _buildDetailSectionCard(
      title: 'Cost benefit & financial metrics',
      child: _buildCbaCostRows(cbaRows),
    );
  }

  Widget _buildDetailList(List<String> items) {
    final filtered =
        items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (filtered.isEmpty) {
      return const Text(
        'No information captured yet.',
        style: TextStyle(fontSize: 14, color: Colors.black45),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filtered
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('. ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.black87))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildITOrInfraContent(String? fullText, List<String> listItems) {
    if (fullText != null && fullText.trim().isNotEmpty) {
      return Text(fullText.trim(),
          style: const TextStyle(
              fontSize: 14, height: 1.45, color: Colors.black87));
    }
    final filtered =
        listItems.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (filtered.isEmpty) {
      return const Text(
        'No information captured yet.',
        style: TextStyle(fontSize: 14, color: Colors.black45),
      );
    }
    return _buildDetailList(filtered);
  }

  Widget _buildStakeholdersDetail(_SolutionAnalysisData data) {
    final hasInternal = data.internalStakeholders != null &&
        data.internalStakeholders!.any((e) => e.trim().isNotEmpty);
    final hasExternal = data.externalStakeholders != null &&
        data.externalStakeholders!.any((e) => e.trim().isNotEmpty);
    if (hasInternal || hasExternal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasInternal) ...[
            const Text('Internal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildDetailList(data.internalStakeholders!),
            const SizedBox(height: 12),
          ],
          if (hasExternal) ...[
            const Text('External',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildDetailList(data.externalStakeholders!),
          ],
        ],
      );
    }
    return _buildDetailList(data.stakeholders);
  }

  Widget _buildCbaCostRows(List<CostRowData> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.itemName.isNotEmpty ? r.itemName : 'Cost item',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (r.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(r.description,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              if (r.cost.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Cost: ${r.cost}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
              if (r.assumptions.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Assumptions: ${r.assumptions}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInvestmentOverviewBody(List<AiCostItem> items) {
    if (items.isEmpty) {
      return const Text(
        'No cost analysis generated yet. Capture financial assumptions before finalizing.',
        style: TextStyle(fontSize: 14, color: Colors.black45),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.item.isNotEmpty ? item.item : 'Cost item',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildCostBadge(
                      'Est. cost', _formatCurrency(item.estimatedCost)),
                  _buildCostBadge(
                      'ROI', '${item.roiPercent.toStringAsFixed(1)}%'),
                  _buildCostBadge('NPV', _formatCurrency(item.npv)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _buildFullCostsSection(List<AiCostItem> items) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Investment overview',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          Text(
              'No cost analysis generated yet. Capture financial assumptions before finalizing.',
              style: TextStyle(fontSize: 13, color: Colors.black45)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Investment overview',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF9FBFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.15))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.item.isNotEmpty ? item.item : 'Cost item',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.description,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildCostBadge(
                        'Est. cost', _formatCurrency(item.estimatedCost)),
                    _buildCostBadge(
                        'ROI', '${item.roiPercent.toStringAsFixed(1)}%'),
                    _buildCostBadge('NPV', _formatCurrency(item.npv)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionBlock(
      {required String title, required List<String> items}) {
    final hasContent = items.any((e) => e.trim().isNotEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      hasContent
          ? _buildBulletList(items)
          : const Text(
              'No insights captured yet. Add notes or rerun AI to populate this section.',
              style: TextStyle(fontSize: 13, color: Colors.black45)),
    ]);
  }

  Widget _buildBulletList(List<String> items) {
    final filtered = items.where((e) => e.trim().isNotEmpty).toList();
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filtered
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('- ',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87))),
                    ]),
              ))
          .toList(),
    );
  }

  Widget _buildCostsSection(List<AiCostItem> items) {
    if (items.isEmpty) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Investment overview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 10),
            Text(
                'No cost analysis generated yet. Capture financial assumptions before finalizing.',
                style: TextStyle(fontSize: 13, color: Colors.black45)),
          ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Investment overview',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.take(4).map((item) {
          final metrics = <Widget>[
            _buildCostBadge('Est. cost', _formatCurrency(item.estimatedCost)),
            _buildCostBadge('ROI', '${item.roiPercent.toStringAsFixed(1)}%'),
            _buildCostBadge('NPV', _formatCurrency(item.npv)),
          ];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF9FBFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.15))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.item.isNotEmpty ? item.item : 'Cost item',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: metrics),
            ]),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildCostBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7CC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ]),
    );
  }

  Widget _buildCardBasedView() {
    if (_analysis.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_analysis.length, (index) {
          final analysis = _analysis[index];
          final isSelected = _selectedSolutionIndex == index;
          final solutionTitle = analysis.solution.title.trim().isNotEmpty
              ? analysis.solution.title
              : 'Proposed Solution ${index + 1}';
          final solutionDesc = analysis.solution.description.trim().isNotEmpty
              ? analysis.solution.description
              : 'Discipline';

          // Compute Cost / ROI / NPV from costs
          final costs = analysis.costs;
          final totalCost =
              costs.fold<double>(0, (sum, c) => sum + c.estimatedCost);
          final avgRoi = costs.isEmpty
              ? 0.0
              : costs.fold<double>(0, (sum, c) => sum + c.roiPercent) /
                  costs.length;
          final bestNpv = costs.isEmpty
              ? 0.0
              : costs.fold<double>(0, (sum, c) => math.max(sum, c.npv));

          // Stakeholders (max 2)
          final allStakeholders = <String>[
            ...analysis.stakeholders,
            if (analysis.internalStakeholders != null)
              ...analysis.internalStakeholders!,
            if (analysis.externalStakeholders != null)
              ...analysis.externalStakeholders!,
          ];
          final displayStakeholders = allStakeholders.toSet().take(2).toList();
          final hasStakeholders = displayStakeholders.isNotEmpty;

          // Risks (max 2)
          final displayRisks = analysis.risks.take(2).toList();
          final hasRisks = displayRisks.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _onInlineSelect(index),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFC107)
                        : const Color(0xFFE5E7EB),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: label + title + radio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SOLUTION ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                solutionTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1a1a1a),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Radio indicator
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFC107)
                                  : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFC107),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      solutionDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Badge row: Cost, ROI, NPV
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildMetricBadge('Cost', _formatCurrency(totalCost)),
                        _buildMetricBadge(
                            'ROI', '${avgRoi.toStringAsFixed(1)}%'),
                        _buildMetricBadge('NPV', _formatCurrency(bestNpv)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Core Stakeholders summary
                    const Text(
                      'CORE STAKEHOLDERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasStakeholders)
                      ...displayStakeholders.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4B5563))),
                                Expanded(
                                  child: Text(s,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4B5563)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ))
                    else
                      const Text('No data available',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    // Key Risks summary
                    const Text(
                      'KEY RISKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasRisks)
                      ...displayRisks.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4B5563))),
                                Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4B5563)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ))
                    else
                      const Text('No data available',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    // Bottom action links
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                      ),
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _navigateToSolutionDetails(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.visibility_outlined,
                                    size: 16, color: Color(0xFF0084ff)),
                                SizedBox(width: 4),
                                Text('View This Solution',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF0084ff))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          InkWell(
                            onTap: () => _navigateToSolutionDetails(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.expand_more,
                                    size: 16, color: Color(0xFF0084ff)),
                                SizedBox(width: 4),
                                Text('View more',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF0084ff))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1a1a1a))),
        ],
      ),
    );
  }

  Widget _buildAuthorizedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Authorized role detected: $_currentUserRole. You can finalize the preferred solution.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSummary() {
    final hasSelection = _selectedSolutionIndex != null &&
        _selectedSolutionIndex! >= 0 &&
        _selectedSolutionIndex! < _analysis.length;
    final selectedTitle =
        hasSelection ? _analysis[_selectedSolutionIndex!].solution.title : null;
    final isAuthorized = _isUserAuthorizedToFinalize();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred Solution Selection',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSelection
                ? 'Selected candidate: Solution ${_selectedSolutionIndex! + 1} of ${_analysis.length} - $selectedTitle'
                : 'No solution selected yet',
            style: TextStyle(
              fontSize: 14,
              color: hasSelection
                  ? const Color(0xFF1a1a1a)
                  : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This selection will form the basis of the entire project and cannot be changed once confirmed. Please ensure you have reviewed all options carefully.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (hasSelection && isAuthorized)
                  ? () => _showFinalPreferredConfirmation(
                      index: _selectedSolutionIndex!)
                  : (!hasSelection)
                      ? null
                      : () => _showAuthorizationBlockedDialog(),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Select Preferred Solution',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF1a1a1a),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSolutionAccordion(int index) {
    setState(() {
      if (_expandedSolutionIndex == index) {
        _expandedSolutionIndex = null;
      } else {
        _expandedSolutionIndex = index;
      }
    });
  }

  Widget _buildActionLinksRow() {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (int i = 0; i < _analysis.length; i++)
            InkWell(
              onTap: () => _navigateToSolutionDetails(i),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: Color(0xFF0084ff)),
                  const SizedBox(width: 4),
                  Text(
                    'View Solution ${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0084ff)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildComparisonTable(ProjectDataModel projectData) {
    // Define the categories for comparison
    final categories = [
      'Solution Description',
      'Risk Identification',
      'IT Considerations',
      'Infrastructure Considerations',
      'Core Stakeholders',
      'Cost Benefit Analysis Overview',
    ];

    // Responsive column widths based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final categoryWidth = screenWidth < 900 ? 120.0 : 150.0;
    // Calculate minimum width for each solution column
    final solutionColumnMinWidth = 280.0;
    final totalMinWidth =
        categoryWidth + (solutionColumnMinWidth * _analysis.length);

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: totalMinWidth),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade200),
          verticalInside: BorderSide(color: Colors.grey.shade200),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        columnWidths: {
          0: FixedColumnWidth(categoryWidth),
          for (int i = 0; i < _analysis.length; i++)
            i + 1: const FlexColumnWidth(1),
        },
        children: [
          // Header Row
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            children: [
              _buildTableHeaderCell('Category'),
              for (int i = 0; i < _analysis.length; i++)
                _buildSolutionHeaderCell(i, _analysis[i].solution.title),
            ],
          ),
          // Data Rows
          for (final category in categories)
            TableRow(
              children: [
                _buildCategoryCellClickable(category),
                for (int i = 0; i < _analysis.length; i++)
                  _buildExpandableComparisonCell(
                    category: category,
                    index: i,
                    analysis: _analysis[i],
                    projectData: projectData,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonTableFillWidth(
      ProjectDataModel projectData, double tableWidth) {
    // Define the categories for comparison
    final categories = [
      'Solution Description',
      'Risk Identification',
      'IT Considerations',
      'Infrastructure Considerations',
      'Core Stakeholders',
      'Cost Benefit Analysis Overview',
    ];

    // Category column: ~15% of table width (min 100, max 180)
    final categoryWidth = (tableWidth * 0.15).clamp(100.0, 180.0);
    // Solution columns split remaining width equally
    final remainingWidth = tableWidth - categoryWidth;
    final solutionColumnWidth = remainingWidth / _analysis.length;

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200),
        verticalInside: BorderSide(color: Colors.grey.shade200),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      columnWidths: {
        0: FixedColumnWidth(categoryWidth),
        for (int i = 0; i < _analysis.length; i++)
          i + 1: FixedColumnWidth(solutionColumnWidth),
      },
      children: [
        // Header Row
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          children: [
            _buildTableHeaderCell('Category'),
            for (int i = 0; i < _analysis.length; i++)
              _buildSolutionHeaderCell(i, _analysis[i].solution.title),
          ],
        ),
        // Data Rows
        for (final category in categories)
          TableRow(
            children: [
              _buildCategoryCellClickable(category),
              for (int i = 0; i < _analysis.length; i++)
                _buildExpandableComparisonCell(
                  category: category,
                  index: i,
                  analysis: _analysis[i],
                  projectData: projectData,
                ),
            ],
          ),
      ],
    );
  }

  // Track expanded state for each cell
  final Map<String, bool> _expandedCells = {};

  String _getCellKey(String category, int index) => '${category}_$index';

  Widget _buildExpandableComparisonCell({
    required String category,
    required int index,
    required _SolutionAnalysisData analysis,
    required ProjectDataModel projectData,
  }) {
    final fullContent =
        _getFullCellContent(category, index, analysis, projectData);
    final cellKey = _getCellKey(category, index);
    final isExpanded = _expandedCells[cellKey] ?? false;

    // Check if content needs expansion (more than ~150 chars or 4 lines)
    final needsExpansion =
        fullContent.length > 150 || fullContent.split('\n').length > 4;
    final displayContent = isExpanded || !needsExpansion
        ? fullContent
        : _truncateContent(fullContent);

    final isCostOverview = category == 'Cost Benefit Analysis Overview';
    return InkWell(
      onTap: isCostOverview ? null : () => _navigateToSolutionDetails(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayContent,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
              softWrap: true,
            ),
            if (needsExpansion) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedCells[cellKey] = !isExpanded;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? 'Show less' : 'View more',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
            if (category == 'Cost Benefit Analysis Overview') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToSolutionDetails(index),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text(
                      'View This Solution',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _navigateToSolutionDetails(index),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.expand_more, size: 14),
                    label: const Text(
                      'View more',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openCostAnalysisForSolution(index),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text(
                      'Open Cost Analysis',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _truncateContent(String content) {
    final lines = content.split('\n');
    if (lines.length > 4) {
      return '${lines.take(4).join('\n')}...';
    }
    if (content.length > 150) {
      return '${content.substring(0, 150)}...';
    }
    return content;
  }

  String _getFullCellContent(
    String category,
    int index,
    _SolutionAnalysisData analysis,
    ProjectDataModel projectData,
  ) {
    switch (category) {
      case 'Solution Description':
        final desc = analysis.solution.description;
        return desc.isNotEmpty ? desc : 'No description available';

      case 'Risk Identification':
        final risks = analysis.risks;
        if (risks.isEmpty) return 'No risks identified';
        return risks.map((r) => '- $r').join('\n');

      case 'IT Considerations':
        final tech = analysis.technologies;
        if (tech.isEmpty) return 'No IT considerations';
        return tech.map((t) => '- $t').join('\n');

      case 'Infrastructure Considerations':
        final infra = analysis.infrastructure;
        if (infra.isEmpty) return 'No infrastructure considerations';
        return infra.map((i) => '- $i').join('\n');

      case 'Core Stakeholders':
        final internal = analysis.internalStakeholders ?? [];
        final external = analysis.externalStakeholders ?? [];
        final lines = <String>[];
        if (internal.isNotEmpty) {
          lines.add('Internal:');
          lines.addAll(internal.map((s) => '- $s'));
        }
        if (external.isNotEmpty) {
          if (lines.isNotEmpty) lines.add('');
          lines.add('External:');
          lines.addAll(external.map((s) => '- $s'));
        }
        return lines.isEmpty ? 'No stakeholders identified' : lines.join('\n');

      case 'Cost Benefit Analysis Overview':
        final cbaRows = _getCbaCostRowsForSolution(
          projectData,
          analysis.solution.title,
          solutionIndex: index,
        );
        if (cbaRows.isEmpty) return 'No cost analysis available';
        final totalCost = cbaRows.fold<double>(
          0,
          (sum, row) => sum + _parseNumericAmount(row.cost),
        );
        final totalBenefits = _benefitTotalForSolution(
          projectData,
          analysis.solution.title,
          solutionIndex: index,
        );
        final items =
            cbaRows.map((r) => '- ${r.itemName}: ${r.cost}').join('\n');
        final benefitLine = totalBenefits > 0
            ? 'Total benefits: ${_formatCurrency(totalBenefits)}\n'
            : '';
        return 'Total cost: ${_formatCurrency(totalCost)}\n$benefitLine\n$items';

      default:
        return '';
    }
  }

  Widget _buildTableHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildSolutionHeaderCell(int index, String title) {
    final displayTitle = title.isNotEmpty ? title : 'Solution ${index + 1}';
    return InkWell(
      onTap: () => _navigateToSolutionDetails(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _navigateToSolutionDetails(index),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  'View This Solution',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCellClickable(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildComparisonCellClickable({
    required String category,
    required int index,
    required _SolutionAnalysisData analysis,
    required ProjectDataModel projectData,
  }) {
    final content = _getCellContent(category, index, analysis, projectData);

    return InkWell(
      onTap: () => _navigateToSolutionDetails(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minHeight: 80),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  String _getCellContent(
    String category,
    int index,
    _SolutionAnalysisData analysis,
    ProjectDataModel projectData,
  ) {
    switch (category) {
      case 'Solution Description':
        final desc = analysis.solution.description;
        // Show more text on larger screens
        final maxLength = MediaQuery.of(context).size.width > 1200 ? 300 : 200;
        return desc.isNotEmpty
            ? (desc.length > maxLength
                ? '${desc.substring(0, maxLength)}...'
                : desc)
            : 'No description available';

      case 'Risk Identification':
        final risks = analysis.risks;
        if (risks.isEmpty) return 'No risks identified';
        return risks.take(3).map((r) => '- $r').join('\n');

      case 'IT Considerations':
        final tech = analysis.technologies;
        if (tech.isEmpty) return 'No IT considerations';
        return tech.take(3).map((t) => '- $t').join('\n');

      case 'Infrastructure Considerations':
        final infra = analysis.infrastructure;
        if (infra.isEmpty) return 'No infrastructure considerations';
        return infra.take(3).map((i) => '- $i').join('\n');

      case 'Core Stakeholders':
        final internal = analysis.internalStakeholders ?? [];
        final external = analysis.externalStakeholders ?? [];
        final allStakeholders = [...internal, ...external];
        if (allStakeholders.isEmpty) return 'No stakeholders identified';
        return allStakeholders.take(3).map((s) => '- $s').join('\n');

      case 'Cost Benefit Analysis Overview':
        final cbaRows = _getCbaCostRowsForSolution(
          projectData,
          analysis.solution.title,
          solutionIndex: index,
        );
        if (cbaRows.isEmpty) return 'No cost analysis available';

        final totalCost = cbaRows.fold<double>(
          0,
          (sum, row) => sum + _parseNumericAmount(row.cost),
        );
        final totalBenefits = _benefitTotalForSolution(
          projectData,
          analysis.solution.title,
          solutionIndex: index,
        );

        final items =
            cbaRows.take(3).map((r) => '- ${r.itemName}: ${r.cost}').join('\n');
        final benefitLine = totalBenefits > 0
            ? 'Project Benefits: ${_formatCurrency(totalBenefits)}'
            : 'Project Benefits: Not set';
        return '$benefitLine\nEstimated Cost: ${_formatCurrency(totalCost)}\n$items';

      default:
        return '';
    }
  }

  bool _isSavingPreferredSelection = false;
  // ignore: unused_field
  int? _savingPreferredIndex;

  // ignore: unused_element
  Future<void> _confirmSelectPreferredFromCard({
    required int index,
  }) async {
    await _attemptSelectPreferredFromDialog(index: index);
  }

  // ignore: unused_element
  Future<void> _selectPreferredAndContinue({required int index}) async {
    if (index < 0 || index >= _analysis.length) return;
    if (_isSavingPreferredSelection) return;

    setState(() {
      _isSavingPreferredSelection = true;
      _savingPreferredIndex = index;
    });

    try {
      final saved = await _persistPreferredSelection(
        index: index,
        showSuccessMessage: false,
      );
      if (!saved || !mounted) return;
      await _openPreferredSelectionPage(preferredIndex: index);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select solution: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPreferredSelection = false;
          _savingPreferredIndex = null;
        });
      }
    }
  }

  void _navigateToSolutionDetails(int index) {
    if (index < 0 || index >= _analysis.length) return;

    setState(() {
      _selectedSolutionIndex = index;
    });

    final analysis = _analysis[index];
    final projectData = ProjectDataHelper.getData(context);
    final cbaRows = _getCbaCostRowsForSolution(
      projectData,
      analysis.solution.title,
      solutionIndex: index,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PreferredSolutionDetailsScreen(
          analysis: analysis,
          index: index,
          cbaRows: cbaRows,
          onSelectPreferred: () => _confirmSelectPreferredFromDetails(
            index: index,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSelectPreferredFromDetails({
    required int index,
  }) async {
    await _attemptSelectPreferredFromDialog(index: index);
  }

  // ignore: unused_element
  void _showSolutionDetailsDialog(_SolutionAnalysisData analysis, int index) {
    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;
    final cbaRows = _getCbaCostRowsForSolution(
      projectData,
      analysis.solution.title,
      solutionIndex: index,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Column(
            children: [
              AppBar(
                title:
                    Text('Solution #${index + 1}: ${analysis.solution.title}'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  FilledButton.icon(
                    onPressed: () async {
                      // Set as preferred and continue
                      final solutionId = projectData.potentialSolutions
                          .where((s) => s.title == analysis.solution.title)
                          .firstOrNull
                          ?.id;

                      if (solutionId != null) {
                        await provider.setPreferredSolution(solutionId,
                            checkpoint: 'preferred_solution_selected');
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Selected as preferred solution')),
                          );
                          // Navigate to next step
                          FrontEndPlanningSummaryScreen.open(context);
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Select as Preferred & Continue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SolutionDetailSection(
                        title: 'Scope Statement',
                        content: Text(
                          analysis.solution.description.isNotEmpty
                              ? analysis.solution.description
                              : 'No scope statement provided.',
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        initiallyExpanded: false,
                      ),
                      SolutionDetailSection(
                        title: 'Risks Identified',
                        content: analysis.risks.isEmpty
                            ? const Text('No risks identified.',
                                style: TextStyle(fontSize: 14))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: analysis.risks
                                    .map((risk) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('. ',
                                                  style:
                                                      TextStyle(fontSize: 14)),
                                              Expanded(
                                                  child: Text(risk,
                                                      style: const TextStyle(
                                                          fontSize: 14))),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                      ),
                      SolutionDetailSection(
                        title: 'IT Considerations',
                        content: analysis.itConsiderationText?.isNotEmpty ==
                                true
                            ? Text(analysis.itConsiderationText!,
                                style:
                                    const TextStyle(fontSize: 14, height: 1.5))
                            : (analysis.technologies.isEmpty
                                ? const Text('No IT considerations recorded.',
                                    style: TextStyle(fontSize: 14))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: analysis.technologies
                                        .map((tech) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('. ',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  Expanded(
                                                      child: Text(tech,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      14))),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  )),
                      ),
                      SolutionDetailSection(
                        title: 'Infrastructure Considerations',
                        content: analysis.infraConsiderationText?.isNotEmpty ==
                                true
                            ? Text(analysis.infraConsiderationText!,
                                style:
                                    const TextStyle(fontSize: 14, height: 1.5))
                            : (analysis.infrastructure.isEmpty
                                ? const Text(
                                    'No infrastructure considerations recorded.',
                                    style: TextStyle(fontSize: 14))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: analysis.infrastructure
                                        .map((infra) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('. ',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  Expanded(
                                                      child: Text(infra,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      14))),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  )),
                      ),
                      SolutionDetailSection(
                        title: 'Cost Benefit Analysis',
                        content: cbaRows.isEmpty
                            ? const Text('No cost analysis available.',
                                style: TextStyle(fontSize: 14))
                            : _buildCostBenefitTable(cbaRows),
                      ),
                      SolutionDetailSection(
                        title: 'Core Stakeholders',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (analysis.externalStakeholders?.isNotEmpty ==
                                true) ...[
                              const Text('External:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              ...analysis.externalStakeholders!
                                  .map((s) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('. ',
                                                style: TextStyle(fontSize: 14)),
                                            Expanded(
                                                child: Text(s,
                                                    style: const TextStyle(
                                                        fontSize: 14))),
                                          ],
                                        ),
                                      )),
                              const SizedBox(height: 16),
                            ],
                            if (analysis.internalStakeholders?.isNotEmpty ==
                                true) ...[
                              const Text('Internal:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              ...analysis.internalStakeholders!
                                  .map((s) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('. ',
                                                style: TextStyle(fontSize: 14)),
                                            Expanded(
                                                child: Text(s,
                                                    style: const TextStyle(
                                                        fontSize: 14))),
                                          ],
                                        ),
                                      )),
                            ],
                            if ((analysis.externalStakeholders?.isEmpty ??
                                    true) &&
                                (analysis.internalStakeholders?.isEmpty ??
                                    true))
                              const Text('No stakeholders identified.',
                                  style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostBenefitTable(List<CostRowData> cbaRows) {
    if (cbaRows.isEmpty) {
      return const Text('No cost data available.',
          style: TextStyle(fontSize: 14));
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                  child: Text('Item',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                  child: Text('Cost',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))),
            ),
          ],
        ),
        for (final row in cbaRows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(row.itemName, style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child:
                        Text(row.cost, style: const TextStyle(fontSize: 12))),
              ),
            ],
          ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildComparisonMatrix() {
    final headers = [
      for (var i = 0; i < _analysis.length; i++)
        '${i + 1}. '
            '${_analysis[i].solution.title.isNotEmpty ? _analysis[i].solution.title : 'Solution ${i + 1}'}',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Side-by-side Solution Comparison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Make columns evenly share width when there are few columns; still allow horizontal scroll if needed
            final available = constraints.maxWidth - 32; // minus padding below
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildMatrixTable(headers, availableWidth: available),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildMatrixTable(List<String> headers, {double? availableWidth}) {
    // Use fixed widths so the table lays out correctly and can scroll horizontally
    const leftCol = 240.0;
    final columnWidths = <int, TableColumnWidth>{};
    columnWidths[0] = const FixedColumnWidth(leftCol);
    // Compute equal widths for value columns to keep spacing even
    final count = headers.length;
    double perCol = 320; // default, slightly wider for better readability
    if (availableWidth != null && availableWidth > leftCol + 100) {
      final remain = availableWidth - leftCol;
      perCol = (remain / count).clamp(260, 450);
    }
    for (var i = 1; i <= count; i++) {
      columnWidths[i] = FixedColumnWidth(perCol);
    }
    final summaryRows = <TableRow>[];

    // Get project data for enhanced comparison
    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Category', isHeader: true),
        for (final header in headers)
          _buildMatrixCellText(header, isHeader: true),
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Solution Description', emphasize: true),
        for (final data in _analysis)
          _buildMatrixCellText(data.solution.description.isNotEmpty
              ? data.solution.description
              : 'N/A')
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Risk Identification', emphasize: true),
        for (final data in _analysis)
          _buildMatrixCellText(
              _getRiskDataForSolution(projectData, data.solution.title))
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('IT Considerations', emphasize: true),
        for (final data in _analysis)
          _buildMatrixCellText(
              _getITDataForSolution(projectData, data.solution.title))
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Infrastructure Considerations', emphasize: true),
        for (final data in _analysis)
          _buildMatrixCellText(_getInfrastructureDataForSolution(
              projectData, data.solution.title))
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Core Stakeholders', emphasize: true),
        for (final data in _analysis)
          _buildMatrixCellText(
              _getStakeholderDataForSolution(projectData, data.solution.title))
      ]),
    );

    summaryRows.add(
      TableRow(children: [
        _buildMatrixCellText('Cost Benefit Analysis Overview', emphasize: true),
        for (int i = 0; i < _analysis.length; i++)
          _buildMatrixCellText(_getCostBenefitDataForSolution(
            projectData,
            _analysis[i].solution.title,
            solutionIndex: i,
          ))
      ]),
    );

    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3), width: 0.7),
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: summaryRows,
    );
  }

  Widget _buildMatrixCellText(String text,
      {bool isHeader = false, bool emphasize = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader
          ? FontWeight.w700
          : emphasize
              ? FontWeight.w600
              : FontWeight.w400,
      color: Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text.isNotEmpty ? text : 'N/A',
        style: style,
        softWrap: true,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInlineSelection(List<String> headers) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose a project to progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Pick the solution you want to advance and give your project a memorable name.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (int i = 0; i < _analysis.length; i++)
                ChoiceChip(
                  label: Text(_analysis[i].solution.title.isNotEmpty
                      ? _analysis[i].solution.title
                      : 'Solution ${i + 1}'),
                  selected: _selectedSolutionIndex == i,
                  onSelected: (_) => _onInlineSelect(i),
                  selectedColor: const Color(0xFFFFF8DC),
                  labelStyle: const TextStyle(color: Colors.black87),
                  side: BorderSide(
                      color: _selectedSolutionIndex == i
                          ? const Color(0xFFFFD700)
                          : Colors.grey.withOpacity(0.3)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          VoiceTextField(
            controller: _projectNameController,
            onChanged: (_) {
              if (_projectNameError != null) {
                setState(() => _projectNameError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Project name',
              hintText: _selectedSolutionIndex != null &&
                      _selectedSolutionIndex! < _analysis.length
                  ? _analysis[_selectedSolutionIndex!].solution.title
                  : 'People Operations Transformation',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _projectNameError,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              ElevatedButton(
                onPressed: _handleInlineContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save & Continue',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Add KAZ Select Project button below the inline selection container
  // ignore: unused_element
  Widget _buildSelectProjectButton() {
    final options = _analysis
        .map((d) => SolutionOption(
            title: d.solution.title,
            description: d.solution.description,
            projectName: null))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SelectProjectKazButton(
        solutions: options,
        onSolutionSelected: (selected) async {
          await _createProjectAndNavigate(
            selectedSolution: AiSolutionItem(
                title: selected.title, description: selected.description),
            projectName: selected.projectName ?? selected.title,
          );
        },
      ),
    );
  }

  // ignore: unused_element
  String _formatListForMatrix(List<String> items, {int maxItems = 4}) {
    final trimmed =
        items.where((e) => e.trim().isNotEmpty).take(maxItems).toList();
    if (trimmed.isEmpty) return 'N/A';
    return trimmed.map((value) => '- ${value.trim()}').join('\n');
  }

  // ignore: unused_element
  List<String> _topStrings(List<String> source, {int maxItems = 4}) {
    return source
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .take(maxItems)
        .toList();
  }

  // ignore: unused_element
  String _financialSummaryText(_SolutionAnalysisData data) {
    final costs = data.costs;
    if (costs.isEmpty) {
      return 'No financial insights available yet.';
    }
    final totalCost =
        costs.fold<double>(0.0, (sum, item) => sum + item.estimatedCost);
    final avgRoi =
        costs.map((item) => item.roiPercent).reduce((a, b) => a + b) /
            costs.length;
    final bestNpv = costs.map((item) => item.npv).reduce(math.max);
    return 'Total: ${_formatCurrency(totalCost)}\nAvg ROI: ${avgRoi.toStringAsFixed(1)}%\nBest NPV: ${_formatCurrency(bestNpv)}';
  }

  // ignore: unused_element
  Widget _buildFooterActions({required bool isMobile}) {
    final info = Container(
      width: 48,
      height: 48,
      decoration:
          const BoxDecoration(color: Color(0xFFB3D9FF), shape: BoxShape.circle),
      child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
    );

    final buttonChild = const Text('Next',
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black));
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFFD700),
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );

    if (isMobile) {
      return Row(
        children: [
          info,
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed:
                    _canNavigateToComparison ? _openComparisonPage : null,
                style: buttonStyle,
                child: buttonChild,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        info,
        const Spacer(),
        ElevatedButton(
          onPressed: _canNavigateToComparison ? _openComparisonPage : null,
          style: buttonStyle,
          child: buttonChild,
        ),
      ],
    );
  }

  bool get _canNavigateToComparison => !_isLoading;

  Future<void> _openComparisonPage() async {
    if (!_canNavigateToComparison) {
      if (_isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Hold on while we finish preparing the comparison.')));
        return;
      }
      if (_error != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Comparison data is incomplete right now. Opening anyway so you can continue.')));
      }
      if (_error == null && _analysis.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Opening comparison without completed analysis. You can fill this in later.')));
      }
    }

    // 1. Save data FIRST before validation
    await _saveAnalysisData();
    if (!mounted) return;

    // 2. Validate data completeness
    // Note: Provider is updated by _saveAnalysisData
    final provider = ProjectDataInherited.read(context);
    if (provider.projectData.preferredSolutionAnalysis == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Continuing without completed preferred solution analysis. You can complete it later.',
            ),
          ),
        );
      }
    }

    // Show 3-second loading dialog
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final analysis = _analysis
        .map(
          (item) => _SolutionAnalysisData(
            solution: AiSolutionItem(
                title: item.solution.title,
                description: item.solution.description),
            stakeholders: List<String>.from(item.stakeholders),
            risks: List<String>.from(item.risks),
            technologies: List<String>.from(item.technologies),
            infrastructure: List<String>.from(item.infrastructure),
            costs: item.costs
                .map(
                  (e) => AiCostItem(
                    item: e.item,
                    description: e.description,
                    estimatedCost: e.estimatedCost,
                    roiPercent: e.roiPercent,
                    npvByYear: Map<int, double>.from(e.npvByYear),
                  ),
                )
                .toList(growable: false),
            internalStakeholders: item.internalStakeholders != null
                ? List<String>.from(item.internalStakeholders!)
                : null,
            externalStakeholders: item.externalStakeholders != null
                ? List<String>.from(item.externalStakeholders!)
                : null,
            itConsiderationText: item.itConsiderationText,
            infraConsiderationText: item.infraConsiderationText,
          ),
        )
        .toList(growable: false);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PreferredSolutionComparisonScreen(
          notes: _notesController.text,
          analysis: analysis,
          solutions: _solutions
              .map((solution) => AiSolutionItem(
                  title: solution.title, description: solution.description))
              .toList(growable: false),
          businessCase: widget.businessCase,
          onViewMore: _showSolutionDetailsDialog,
        ),
      ),
    );
  }

  Future<void> _saveAnalysisData() async {
    try {
      final provider = ProjectDataHelper.getProvider(context);
      final currentAnalysis = provider.projectData.preferredSolutionAnalysis;

      // Preserve selectedSolutionTitle if it exists
      final analysisData = PreferredSolutionAnalysis(
        workingNotes: _notesController.text.trim(),
        solutionAnalyses: _analysis.map((item) {
          return SolutionAnalysisItem(
            solutionTitle: item.solution.title,
            solutionDescription: item.solution.description,
            stakeholders: item.stakeholders,
            risks: item.risks,
            technologies: item.technologies,
            infrastructure: item.infrastructure,
            costs: item.costs
                .map((c) => CostItem(
                      item: c.item,
                      description: c.description,
                      estimatedCost: c.estimatedCost,
                      roiPercent: c.roiPercent,
                      npvByYear: c.npvByYear,
                    ))
                .toList(),
          );
        }).toList(),
        selectedSolutionTitle:
            currentAnalysis?.selectedSolutionTitle, // Preserve selection
        selectedSolutionId: currentAnalysis?.selectedSolutionId,
        selectedSolutionIndex: currentAnalysis?.selectedSolutionIndex,
        isSelectionFinalized: currentAnalysis?.isSelectionFinalized ?? false,
      );

      provider.updateField((data) => data.copyWith(
            preferredSolutionAnalysis: analysisData,
          ));

      await provider.saveToFirebase(checkpoint: 'preferred_solution_analysis');
    } catch (e) {
      // Silent fail - navigation continues
      debugPrint('Error saving analysis data: $e');
    }
  }

  void _onInlineSelect(int index) {
    final provider = ProjectDataHelper.getProvider(context);
    final currentAnalysis = provider.projectData.preferredSolutionAnalysis;
    if (currentAnalysis?.isSelectionFinalized == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preferred solution is already finalized and cannot be changed.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedSolutionIndex = index;
      // Sync the tab controller so the detail view (IT considerations, Benefits, etc.) updates
      if (_tabController.index != index && index < _tabController.length) {
        _tabController.animateTo(index);
      }
      if (_projectNameController.text.trim().isEmpty) {
        _projectNameController
          ..text = _analysis[index].solution.title
          ..selection = TextSelection.collapsed(
              offset: _projectNameController.text.length);
      }
      _projectNameError = null;
    });

    // Immediately save selectedSolutionTitle to provider for state persistence
    final selectedTitle = _analysis[index].solution.title;
    final selectedId = index < provider.projectData.potentialSolutions.length
        ? provider.projectData.potentialSolutions[index].id
        : null;

    final updatedAnalysis = PreferredSolutionAnalysis(
      workingNotes:
          currentAnalysis?.workingNotes ?? _notesController.text.trim(),
      solutionAnalyses: currentAnalysis?.solutionAnalyses ?? [],
      selectedSolutionTitle: selectedTitle,
      selectedSolutionId: selectedId ?? currentAnalysis?.selectedSolutionId,
      selectedSolutionIndex: index,
      isSelectionFinalized: currentAnalysis?.isSelectionFinalized ?? false,
    );

    provider.updateField((data) => data.copyWith(
          preferredSolutionAnalysis: updatedAnalysis,
        ));

    // Save to Firebase in background without blocking UI
    provider.saveToFirebase(checkpoint: 'preferred_solution_analysis').then(
      (_) {},
      onError: (e) {
        debugPrint('Error saving selected solution: $e');
      },
    );
  }

  Future<void> _handleInlineContinue() async {
    final index = _selectedSolutionIndex;
    if (index == null) {
      setState(() => _projectNameError = 'Select a project first.');
      return;
    }

    final name = _projectNameController.text.trim();
    if (name.isEmpty) {
      setState(
          () => _projectNameError = 'Give your project a name to continue.');
      return;
    }

    final selected = AiSolutionItem(
      title: _analysis[index].solution.title,
      description: _analysis[index].solution.description,
    );

    await _createProjectAndNavigate(
        selectedSolution: selected, projectName: name);
  }

  Future<void> _createProjectAndNavigate({
    required AiSolutionItem selectedSolution,
    required String projectName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    final filteredSolutions = _solutions
        .map((solution) => AiSolutionItem(
            title: solution.title.trim(),
            description: solution.description.trim()))
        .where((item) => item.title.isNotEmpty || item.description.isNotEmpty)
        .toList();

    if (filteredSolutions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content:
                Text('Add at least one solution option before continuing.')),
      );
      return;
    }

    final trimmedNotes = _notesController.text.trim();
    final trimmedBusinessCase = widget.businessCase.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Sign in to save your project.')));
      return;
    }

    final ownerName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'Leader');
    final tags = {
      'Initiation',
      if (selectedSolution.title.trim().isNotEmpty)
        selectedSolution.title.trim(),
    }.toList();

    // Allow duplicate project names (do not block the user).
    // We still create a new project document with a new id, even if the name matches an existing one.
    try {
      final existing = await ProjectService.projectNameExists(
          ownerId: user.uid, name: projectName.trim());
      if (existing && mounted) {
        setState(() => _projectNameError = null);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Project name already exists. Continuing anyway (projects can share the same name).',
            ),
          ),
        );
      }
    } catch (e) {
      // If uniqueness check fails, do not block project creation.
    }

    bool dialogShown = false;
    if (mounted) {
      dialogShown = true;
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      await ProjectService.createProject(
        ownerId: user.uid,
        ownerName: ownerName,
        name: projectName,
        solutionTitle: selectedSolution.title.trim(),
        solutionDescription: selectedSolution.description.trim(),
        businessCase: trimmedBusinessCase,
        notes: trimmedNotes,
        ownerEmail: user.email,
        tags: tags,
        checkpointRoute: 'project_decision_summary',
      );
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to create project: $error\n$stack');
      if (dialogShown && mounted) {
        rootNavigator.pop();
      }
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Unable to save project. Try again.')));
      return;
    }

    if (dialogShown && mounted) {
      rootNavigator.pop();
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProjectDecisionSummaryScreen(
          projectName: projectName,
          selectedSolution: selectedSolution,
          allSolutions: filteredSolutions,
          businessCase: trimmedBusinessCase,
          notes: trimmedNotes,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.2))),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('No solutions available yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text(
            'Add potential solutions to see their stakeholders, risks, and cost signals in one place.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
      ]),
    );
  }

  // ignore: unused_element
  String _formatCurrencyLegacy(double value) {
    if (value == 0) return '2430';
    final absValue = value.abs();
    final decimals = absValue >= 1000
        ? 0
        : absValue >= 100
            ? 1
            : 2;
    var text = absValue.toStringAsFixed(decimals);
    final parts = text.split('.');
    final whole = parts.first;
    final withCommas =
        whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    final hasDecimals = parts.length > 1 && int.tryParse(parts[1]) != 0;
    final decimalPart = hasDecimals ? '.${parts[1]}' : '';
    final symbol = value < 0 ? '-24' : '24';
    return '$symbol$withCommas$decimalPart';
  }

  String _formatCurrency(double value) {
    if (value == 0) return r'$0';
    final absValue = value.abs();
    final decimals = absValue >= 1000
        ? 0
        : absValue >= 100
            ? 1
            : 2;
    final text = absValue.toStringAsFixed(decimals);
    final parts = text.split('.');
    final whole = parts.first;
    final withCommas =
        whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    final hasDecimals = parts.length > 1 && int.tryParse(parts[1]) != 0;
    final decimalPart = hasDecimals ? '.${parts[1]}' : '';
    final symbol = value < 0 ? '-\$' : '\$';
    return '$symbol$withCommas$decimalPart';
  }

  // Helper methods to extract data from project model for each solution
  String _getRiskDataForSolution(
      ProjectDataModel projectData, String solutionTitle) {
    final solutionRisk = projectData.solutionRisks.firstWhere(
      (risk) =>
          risk.solutionTitle.trim().toLowerCase() ==
          solutionTitle.trim().toLowerCase(),
      orElse: () => SolutionRisk(solutionTitle: solutionTitle),
    );

    final risks = solutionRisk.risks.where((r) => r.trim().isNotEmpty).toList();
    if (risks.isEmpty) return 'No risks identified';

    return risks.take(4).map((risk) => '- $risk').join('\n');
  }

  String _getITDataForSolution(
      ProjectDataModel projectData, String solutionTitle) {
    if (projectData.itConsiderationsData == null) {
      return 'No IT considerations recorded';
    }

    final itData = projectData.itConsiderationsData!.solutionITData.firstWhere(
      (it) =>
          it.solutionTitle.trim().toLowerCase() ==
          solutionTitle.trim().toLowerCase(),
      orElse: () => SolutionITData(solutionTitle: solutionTitle),
    );

    if (itData.coreTechnology.trim().isEmpty) {
      return 'No IT considerations recorded';
    }
    return itData.coreTechnology;
  }

  String _getInfrastructureDataForSolution(
      ProjectDataModel projectData, String solutionTitle) {
    if (projectData.infrastructureConsiderationsData == null) {
      return 'No infrastructure considerations recorded';
    }

    final infraData = projectData
        .infrastructureConsiderationsData!.solutionInfrastructureData
        .firstWhere(
      (infra) =>
          infra.solutionTitle.trim().toLowerCase() ==
          solutionTitle.trim().toLowerCase(),
      orElse: () => SolutionInfrastructureData(solutionTitle: solutionTitle),
    );

    if (infraData.majorInfrastructure.trim().isEmpty) {
      return 'No infrastructure considerations recorded';
    }
    return infraData.majorInfrastructure;
  }

  String _getStakeholderDataForSolution(
      ProjectDataModel projectData, String solutionTitle) {
    if (projectData.coreStakeholdersData == null) {
      return 'No stakeholders identified';
    }

    final stakeholderData =
        projectData.coreStakeholdersData!.solutionStakeholderData.firstWhere(
      (sh) =>
          sh.solutionTitle.trim().toLowerCase() ==
          solutionTitle.trim().toLowerCase(),
      orElse: () => SolutionStakeholderData(solutionTitle: solutionTitle),
    );

    if (stakeholderData.notableStakeholders.trim().isEmpty) {
      return 'No stakeholders identified';
    }
    return stakeholderData.notableStakeholders;
  }

  String _getCostBenefitDataForSolution(
    ProjectDataModel projectData,
    String solutionTitle, {
    int? solutionIndex,
  }) {
    final cbaRows = _getCbaCostRowsForSolution(
      projectData,
      solutionTitle,
      solutionIndex: solutionIndex,
    );
    if (cbaRows.isEmpty) return 'No cost analysis available';

    final totalCost = cbaRows.fold<double>(
      0,
      (sum, row) => sum + _parseNumericAmount(row.cost),
    );
    final totalBenefits = _benefitTotalForSolution(
      projectData,
      solutionTitle,
      solutionIndex: solutionIndex,
    );

    final lines = <String>[
      'Estimated Cost: ${_formatCurrency(totalCost)}',
      'Project Benefits: ${totalBenefits > 0 ? _formatCurrency(totalBenefits) : 'Not set'}',
    ];

    final topCosts =
        cbaRows.where((row) => row.itemName.trim().isNotEmpty).take(3);
    for (final cost in topCosts) {
      final costStr = cost.cost.trim().isNotEmpty ? cost.cost : 'TBD';
      lines.add('- ${cost.itemName}: $costStr');
    }

    return lines.join('\n');
  }
}

// ─── Accordion Card Widget for each solution ───────────────────────
class _SolutionAccordionCard extends StatelessWidget {
  const _SolutionAccordionCard({
    required this.index,
    required this.analysis,
    required this.isExpanded,
    required this.onToggle,
    required this.onViewSolution,
    required this.onViewCostAnalysis,
    required this.projectData,
  });

  final int index;
  final _SolutionAnalysisData analysis;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onViewSolution;
  final VoidCallback onViewCostAnalysis;
  final ProjectDataModel projectData;

  static const List<Color> _numberBgColors = [
    Color(0xFFFFEDD5), // orange-100
    Color(0xFFFEF9C3), // yellow-100
    Color(0xFFFFEDD5), // orange-100
  ];
  static const List<Color> _numberBorderColors = [
    Color(0xFFFDBA74), // orange-300
    Color(0xFFFDE047), // yellow-300
    Color(0xFFFDBA74), // orange-300
  ];
  static const List<Color> _numberTextColors = [
    Color(0xFFEA580C), // orange-600
    Color(0xFFCA8A04), // yellow-600
    Color(0xFFEA580C), // orange-600
  ];

  Color get _bg => _numberBgColors[index % 3];
  Color get _border => _numberBorderColors[index % 3];
  Color get _text => _numberTextColors[index % 3];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion header
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Number circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      analysis.solution.title.trim().isNotEmpty
                          ? analysis.solution.title
                          : 'Proposed Solution ${index + 1}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                  ),
                  // View This Solution link
                  InkWell(
                    onTap: onViewSolution,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.open_in_new_outlined,
                            size: 14, color: Color(0xFF0084ff)),
                        SizedBox(width: 4),
                        Text(
                          'View This Solution',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0084ff),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildAccordionContent(),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Solution Description
          _buildCategorySection(
            title: 'Solution Description',
            child: Text(
              analysis.solution.description.trim().isNotEmpty
                  ? analysis.solution.description
                  : 'Describe how this option addresses the project\'s needs, assumptions, constraints, and expected benefits.',
              style: TextStyle(
                fontSize: 14,
                color: analysis.solution.description.trim().isNotEmpty
                    ? const Color(0xFF1a1a1a)
                    : const Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),
          _categoryDivider(),
          // Risk Identification
          _buildCategorySection(
            title: 'Risk Identification',
            child: _buildBulletList(analysis.risks, maxItems: 2),
          ),
          _categoryDivider(),
          // IT Considerations
          _buildCategorySection(
            title: 'IT Considerations',
            child: _buildBulletList(analysis.technologies, maxItems: 4),
          ),
          _categoryDivider(),
          // Infrastructure Considerations
          _buildCategorySection(
            title: 'Infrastructure Considerations',
            child: _buildBulletList(analysis.infrastructure, maxItems: 2),
          ),
          _categoryDivider(),
          // Core Stakeholders
          _buildCategorySection(
            title: 'Core Stakeholders',
            child: _buildStakeholdersContent(),
          ),
          _categoryDivider(),
          // Cost Benefit Analysis Overview
          _buildCategorySection(
            title: 'Cost Benefit Analysis Overview',
            child: _buildCostBenefitContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _categoryDivider() {
    return const Divider(height: 24, color: Color(0xFFE5E7EB));
  }

  Widget _buildBulletList(List<String> items, {int maxItems = 3}) {
    if (items.isEmpty) {
      return const Text(
        'No data available',
        style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
      );
    }
    final displayItems = items.take(maxItems).toList();
    final hasMore = items.length > maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('— ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  Expanded(
                    child: Text(
                      item.trim(),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1a1a1a)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        if (hasMore)
          InkWell(
            onTap: onViewSolution,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'View more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0084ff),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down,
                    size: 14, color: Color(0xFF0084ff)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStakeholdersContent() {
    final internal = analysis.internalStakeholders ?? const [];
    final external = analysis.externalStakeholders ?? const [];
    final allStakeholders = analysis.stakeholders;

    if (internal.isEmpty && external.isEmpty && allStakeholders.isEmpty) {
      return const Text(
        'No stakeholder data available',
        style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (internal.isNotEmpty) ...[
          const Text('Internal:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1a1a1a))),
          ...internal.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('— ',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF666666))),
                    Expanded(
                        child: Text(item.trim(),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1a1a1a)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        ],
        if (external.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('External:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1a1a1a))),
          ...external.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('— ',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF666666))),
                    Expanded(
                        child: Text(item.trim(),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1a1a1a)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        ],
        if (internal.isEmpty && external.isEmpty && allStakeholders.isNotEmpty)
          ...allStakeholders.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('— ',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF666666))),
                    Expanded(
                        child: Text(item.trim(),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1a1a1a)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        InkWell(
          onTap: onViewSolution,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('View more',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0084ff))),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  size: 14, color: Color(0xFF0084ff)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostBenefitContent() {
    final costs = analysis.costs;
    if (costs.isEmpty) {
      return const Text(
        'No cost data available',
        style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
      );
    }

    final totalCost =
        costs.fold<double>(0, (sum, c) => sum + (c.estimatedCost));
    // Calculate total benefits (approximate from ROI)
    final totalBenefits = costs.fold<double>(0, (sum, c) {
      final roi = c.roiPercent;
      return sum + (c.estimatedCost * (1 + roi / 100));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total cost: \$${_formatCurrency(totalCost)}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF1a1a1a))),
        Text('Total benefits: \$${_formatCurrency(totalBenefits)}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF1a1a1a))),
        const SizedBox(height: 8),
        ...costs.take(2).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '— ${c.item}: ${c.estimatedCost.toStringAsFixed(2)}...',
                style: const TextStyle(fontSize: 14, color: Color(0xFF1a1a1a)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
        const SizedBox(height: 4),
        InkWell(
          onTap: onViewSolution,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('View more',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0084ff))),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  size: 14, color: Color(0xFF0084ff)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Action links at bottom of cost section
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            InkWell(
              onTap: onViewSolution,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.visibility_outlined,
                      size: 14, color: Color(0xFF0084ff)),
                  SizedBox(width: 4),
                  Text('View This Solution',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0084ff))),
                ],
              ),
            ),
            InkWell(
              onTap: onViewSolution,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.keyboard_arrow_down,
                      size: 14, color: Color(0xFF0084ff)),
                  SizedBox(width: 4),
                  Text('View more',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0084ff))),
                ],
              ),
            ),
            InkWell(
              onTap: onViewCostAnalysis,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.open_in_new_outlined,
                      size: 14, color: Color(0xFF0084ff)),
                  SizedBox(width: 4),
                  Text('Open Cost Analysis',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0084ff))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _SolutionAnalysisData {
  final AiSolutionItem solution;
  final List<String> stakeholders;
  final List<String> risks;
  final List<String> technologies;
  final List<String> infrastructure;
  final List<AiCostItem> costs;
  final List<String>? internalStakeholders;
  final List<String>? externalStakeholders;
  final String? itConsiderationText;
  final String? infraConsiderationText;

  const _SolutionAnalysisData({
    required this.solution,
    required this.stakeholders,
    required this.risks,
    required this.technologies,
    required this.infrastructure,
    required this.costs,
    this.internalStakeholders,
    this.externalStakeholders,
    this.itConsiderationText,
    this.infraConsiderationText,
  });
}

class _ProjectSelectionResult {
  final AiSolutionItem solution;
  final String projectName;

  const _ProjectSelectionResult(
      {required this.solution, required this.projectName});
}

class _ProjectSelectionDialog extends StatefulWidget {
  final List<AiSolutionItem> solutions;

  const _ProjectSelectionDialog({required this.solutions});

  @override
  State<_ProjectSelectionDialog> createState() =>
      _ProjectSelectionDialogState();
}

class _ProjectSelectionDialogState extends State<_ProjectSelectionDialog> {
  int? _selectedIndex;
  late final TextEditingController _nameController;
  String? _error;
  bool _nameManuallyEdited = false;
  bool _suppressNameChange = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choose a project to progress',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Pick the solution you want to advance and give your project a memorable name.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.solutions.length >= 3 ? 360 : 280,
                ),
                child: Scrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (int i = 0; i < widget.solutions.length; i++)
                        _ProjectOptionCard(
                          solution: widget.solutions[i],
                          isSelected: _selectedIndex == i,
                          onTap: () => _onSelect(i),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              VoiceTextField(
                controller: _nameController,
                onChanged: (_) {
                  if (_suppressNameChange) return;
                  setState(() {
                    _nameManuallyEdited = true;
                    if (_error != null) _error = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Project name',
                  hintText:
                      'e.g. ${_selectedIndex != null ? widget.solutions[_selectedIndex!].title : 'People Operations Transformation'}',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Save & Continue',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSelect(int index) {
    setState(() {
      _selectedIndex = index;
      _error = null;
      if (!_nameManuallyEdited || _nameController.text.trim().isEmpty) {
        _suppressNameChange = true;
        _nameController
          ..text = widget.solutions[index].title
          ..selection =
              TextSelection.collapsed(offset: _nameController.text.length);
        _suppressNameChange = false;
        _nameManuallyEdited = false;
      }
    });
  }

  void _confirmSelection() {
    final index = _selectedIndex;
    if (index == null) {
      setState(() => _error = 'Select a project first.');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your project a name to continue.');
      return;
    }

    Navigator.of(context).pop(
      _ProjectSelectionResult(
        solution: widget.solutions[index],
        projectName: name,
      ),
    );
  }
}

class _ProjectOptionCard extends StatelessWidget {
  final AiSolutionItem solution;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectOptionCard({
    required this.solution,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFFFFD700) : Colors.grey.withOpacity(0.2);
    final background = isSelected ? const Color(0xFFFFF8DC) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSelected ? const Color(0xFFFFD700) : Colors.grey[200],
                ),
                alignment: Alignment.center,
                child: Icon(
                  isSelected ? Icons.check : Icons.lightbulb_outline,
                  color: isSelected ? Colors.black : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solution.title.isNotEmpty
                          ? solution.title
                          : 'Untitled Solution',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      solution.description.isNotEmpty
                          ? solution.description
                          : 'Describe the outcomes, value proposition, and key enablers for this option.',
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferredSolutionComparisonScreen extends StatelessWidget {
  final String notes;
  final List<_SolutionAnalysisData> analysis;
  final List<AiSolutionItem> solutions;
  final String businessCase;

  _PreferredSolutionComparisonScreen({
    super.key,
    required this.notes,
    required this.analysis,
    required this.solutions,
    required this.businessCase,
    this.onViewMore,
  });

  final void Function(_SolutionAnalysisData, int)? onViewMore;

  @override
  Widget build(BuildContext context) {
    final pagePadding = AppBreakpoints.pagePadding(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Preferred Solution Comparison',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Side-by-side comparison ready for export or print.',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Confirm the best approach with the full picture in view.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ComparisonContent(
                analysis: analysis,
              ),
              const SizedBox(height: 16),
              // View More Details - mirrors the analysis screen's View More
              if (analysis.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onViewMore != null
                        ? () => onViewMore!(analysis.first, 0)
                        : null,
                    icon: const Icon(Icons.read_more, size: 18),
                    label: const Text('View More Details'),
                  ),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _handleNext(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Next',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleNext(BuildContext context) async {
    final provider = ProjectDataInherited.read(context);
    final projectData = provider.projectData;

    if (projectData.preferredSolutionAnalysis == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Continuing to the summary without completed preferred solution analysis.',
            ),
          ),
        );
      }
    }

    // Smart Checkpoint Check
    final nextCheckpoint = SidebarNavigationService.instance
        .getNextItem('preferred_solution_analysis');
    if (nextCheckpoint?.checkpoint != 'fep_summary') {
      final isLocked =
          ProjectDataHelper.isDestinationLocked(context, 'fep_summary');
      if (isLocked) {
        if (context.mounted) {
          ProjectDataHelper.showLockedDestinationMessage(
              context, 'Front End Planning Summary');
        }
        return;
      }
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FrontEndPlanningSummaryScreen(),
        ),
      );
    }
  }
}

class _ComparisonContent extends StatelessWidget {
  final List<_SolutionAnalysisData> analysis;

  const _ComparisonContent({required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrintToolbar(context),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final canDisplayColumns =
                constraints.maxWidth >= 900 && analysis.length <= 3;
            if (canDisplayColumns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < analysis.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == analysis.length - 1 ? 0 : 16),
                        child: _buildComparisonCard(context,
                            data: analysis[i], index: i),
                      ),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < analysis.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == analysis.length - 1 ? 0 : 16),
                    child: _buildComparisonCard(context,
                        data: analysis[i], index: i),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('No solutions available yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Add potential solutions to see their stakeholders, risks, and cost signals in one place.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrintToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, color: Colors.black54),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Side-by-side comparison ready for export or print. Confirm the best approach with the full picture in view.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Opens printer-friendly guidance',
            waitDuration: const Duration(milliseconds: 200),
            child: OutlinedButton.icon(
              onPressed: () => _showPrintDialog(context),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print tips',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  static void _showPrintDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Print this comparison'),
          content: const Text(
            'Use your browser\'s print shortcut (Ctrl/Cmd + P) to export this consolidated view. For best fidelity choose landscape orientation and reduce margins so each solution column fits on a single page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildComparisonCard(BuildContext context,
      {required _SolutionAnalysisData data, required int index}) {
    final title = data.solution.title.isNotEmpty
        ? data.solution.title
        : 'Solution ${index + 1}';
    final description = data.solution.description.isNotEmpty
        ? data.solution.description
        : 'Discipline';
    final stakeholders = _topStrings(data.stakeholders, maxItems: 5);
    final risks = _topStrings(data.risks, maxItems: 5);
    final costs = data.costs;
    final hasCosts = costs.isNotEmpty;
    final totalCost = hasCosts
        ? costs.fold<double>(0.0, (sum, item) => sum + item.estimatedCost)
        : 0.0;
    final averageRoi = hasCosts
        ? costs.map((item) => item.roiPercent).reduce((a, b) => a + b) /
            costs.length
        : 0.0;
    final bestNpv =
        hasCosts ? costs.map((item) => item.npv).reduce(math.max) : 0.0;
    final strongestCost = hasCosts
        ? costs.reduce((prev, next) =>
            next.estimatedCost > prev.estimatedCost ? next : prev)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(description,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                const _AiTag(),
              ],
            ),
            const SizedBox(height: 18),
            _buildCardSection(
              title: 'Engage these stakeholders',
              child: stakeholders.isEmpty
                  ? _buildCardPlaceholder('No stakeholder insights yet.')
                  : _buildCardList(stakeholders),
            ),
            const SizedBox(height: 18),
            _buildCardSection(
              title: 'Risks to monitor',
              child: risks.isEmpty
                  ? _buildCardPlaceholder('No risk considerations generated.')
                  : _buildCardList(risks),
            ),
            const SizedBox(height: 18),
            _buildCardSection(
              title: 'Financial signals',
              child: hasCosts
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFinancialHighlights(
                            totalCost: totalCost,
                            averageRoi: averageRoi,
                            bestNpv: bestNpv,
                            strongestCost: strongestCost),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: costs.take(5).map((item) {
                            final label =
                                item.item.isNotEmpty ? item.item : 'Cost item';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FBFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(item.description,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54)),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _buildCostBadge('Est. cost',
                                          _formatCurrency(item.estimatedCost)),
                                      _buildCostBadge('ROI',
                                          '${item.roiPercent.toStringAsFixed(1)}%'),
                                      _buildCostBadge('NPV (5yr)',
                                          _formatCurrency(item.npvForYear(5))),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    )
                  : _buildCardPlaceholder('No cost analysis generated yet.'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCardSection(
      {required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  static Widget _buildCardPlaceholder(String message) {
    return Text(message,
        style: const TextStyle(fontSize: 12, color: Colors.black38));
  }

  static Widget _buildCardList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('- ',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static Widget _buildFinancialHighlights(
      {required double totalCost,
      required double averageRoi,
      required double bestNpv,
      AiCostItem? strongestCost}) {
    final badges = <Widget>[
      _buildCostBadge('Total investment', _formatCurrency(totalCost)),
      _buildCostBadge('Avg ROI', '${averageRoi.toStringAsFixed(1)}%'),
      _buildCostBadge('Best NPV (5yr)', _formatCurrency(bestNpv)),
    ];

    if (strongestCost != null) {
      final label =
          strongestCost.item.isNotEmpty ? strongestCost.item : 'Cost item';
      badges.add(_buildCostBadge('Largest cost driver',
          '$label - ${_formatCurrency(strongestCost.estimatedCost)}'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: badges,
    );
  }

  static Widget _buildCostBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7CC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  // ignore: unused_element
  static Widget _buildComparisonMatrix(
      BuildContext context, List<_SolutionAnalysisData> analysis) {
    final headers = [
      for (var i = 0; i < analysis.length; i++)
        '${i + 1}. ${analysis[i].solution.title.isNotEmpty ? analysis[i].solution.title : 'Solution ${i + 1}'}',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              'Side-by-side summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth - 32;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildMatrixTable(analysis, headers,
                      availableWidth: available),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Table _buildMatrixTable(
      List<_SolutionAnalysisData> analysis, List<String> headers,
      {double? availableWidth}) {
    const leftCol = 220.0;
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(leftCol)
    };
    final count = headers.length;
    double perCol = 300;
    if (availableWidth != null && availableWidth > leftCol + 100) {
      final remain = availableWidth - leftCol;
      perCol = (remain / count).clamp(240, 420);
    }
    for (var i = 1; i <= count; i++) {
      columnWidths[i] = FixedColumnWidth(perCol);
    }

    final rows = <TableRow>[];

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Category', isHeader: true),
          for (final header in headers)
            _buildMatrixCellText(header, isHeader: true),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Focus summary', emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(
                _formatListForMatrix([data.solution.description])),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Core stakeholders', emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(_formatListForMatrix(
                _topStrings(data.stakeholders, maxItems: 6))),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Risk identification', emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(
                _formatListForMatrix(_topStrings(data.risks, maxItems: 6))),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('IT considerations', emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(_formatListForMatrix(
                _topStrings(data.technologies, maxItems: 6))),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Infrastructure considerations',
              emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(_formatListForMatrix(
                _topStrings(data.infrastructure, maxItems: 6))),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Cost-benefit & financial metrics',
              emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(_financialSummaryText(data)),
        ],
      ),
    );

    rows.add(
      TableRow(
        children: [
          _buildMatrixCellText('Cost drivers', emphasize: true),
          for (final data in analysis)
            _buildMatrixCellText(
              _formatListForMatrix(
                data.costs
                    .map((e) =>
                        '${e.item.isNotEmpty ? e.item : 'Cost item'} - ${_formatCurrency(e.estimatedCost)}')
                    .toList(),
                maxItems: 5,
              ),
            ),
        ],
      ),
    );

    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.3), width: 0.7),
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
  }

  static Widget _buildMatrixCellText(String text,
      {bool isHeader = false, bool emphasize = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader
          ? FontWeight.w700
          : emphasize
              ? FontWeight.w600
              : FontWeight.w400,
      color: Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text.isNotEmpty ? text : 'N/A', style: style, softWrap: true),
    );
  }

  static String _formatListForMatrix(List<String> items, {int maxItems = 4}) {
    final trimmed =
        items.where((e) => e.trim().isNotEmpty).take(maxItems).toList();
    if (trimmed.isEmpty) return 'N/A';
    return trimmed.map((value) => '- ${value.trim()}').join('\n');
  }

  static List<String> _topStrings(List<String> source, {int maxItems = 4}) {
    return source
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .take(maxItems)
        .toList();
  }

  static String _financialSummaryText(_SolutionAnalysisData data) {
    final costs = data.costs;
    if (costs.isEmpty) {
      return 'No financial insights available yet.';
    }
    final totalCost =
        costs.fold<double>(0.0, (sum, item) => sum + item.estimatedCost);
    final avgRoi =
        costs.map((item) => item.roiPercent).reduce((a, b) => a + b) /
            costs.length;
    final bestNpv = costs.map((item) => item.npv).reduce(math.max);
    return 'Total: ${_formatCurrency(totalCost)}\nAvg ROI: ${avgRoi.toStringAsFixed(1)}%\nBest NPV: ${_formatCurrency(bestNpv)}';
  }

  static String _formatCurrency(double value) {
    if (value == 0) return r'$0';
    final absValue = value.abs();
    final decimals = absValue >= 1000
        ? 0
        : absValue >= 100
            ? 1
            : 2;
    final text = absValue.toStringAsFixed(decimals);
    final parts = text.split('.');
    final whole = parts.first;
    final withCommas =
        whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    final hasDecimals = parts.length > 1 && int.tryParse(parts[1]) != 0;
    final decimalPart = hasDecimals ? '.${parts[1]}' : '';
    final symbol = value < 0 ? '-\$' : '\$';
    return '$symbol$withCommas$decimalPart';
  }
}

class _PreferredSolutionDetailsScreen extends StatefulWidget {
  const _PreferredSolutionDetailsScreen({
    // ignore: unused_element_parameter
    super.key,
    required this.analysis,
    required this.index,
    required this.cbaRows,
    required this.onSelectPreferred,
  });

  final _SolutionAnalysisData analysis;
  final int index;
  final List<CostRowData> cbaRows;
  final Future<void> Function() onSelectPreferred;

  @override
  State<_PreferredSolutionDetailsScreen> createState() =>
      _PreferredSolutionDetailsScreenState();
}

class _PreferredSolutionDetailsScreenState
    extends State<_PreferredSolutionDetailsScreen> {
  _SolutionAnalysisData get analysis => widget.analysis;
  int get index => widget.index;
  List<CostRowData> get cbaRows => widget.cbaRows;
  Future<void> Function() get onSelectPreferred => widget.onSelectPreferred;

  Widget _buildCbaDataTable(List<CostRowData> cbaRows, String currency) {
    if (cbaRows.isEmpty) {
      return const Text('No cost analysis available.',
          style: TextStyle(fontSize: 14));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 800.0;
        final tableWidth = constraints.maxWidth < minTableWidth
            ? minTableWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Currency indicator at top
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_money,
                          size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Currency: $currency',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Header row - center-aligned, reduced font/padding
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'Item',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Cost',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'Description',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Data rows
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < cbaRows.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              top: i > 0
                                  ? BorderSide(
                                      color: Colors.grey.withOpacity(0.2))
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    cbaRows[i].itemName.isEmpty
                                        ? 'Cost item'
                                        : cbaRows[i].itemName,
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    cbaRows[i].cost.isEmpty
                                        ? '-'
                                        : cbaRows[i].cost,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    cbaRows[i].description.isEmpty
                                        ? '-'
                                        : cbaRows[i].description,
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Calculate stats for overview card
  int get _riskCount => analysis.risks.length;
  int get _techCount => analysis.technologies.length;
  int get _infraCount => analysis.infrastructure.length;
  int get _stakeholderCount =>
      (analysis.internalStakeholders?.length ?? 0) +
      (analysis.externalStakeholders?.length ?? 0) +
      (analysis.stakeholders.length);

  Widget _buildOverviewCard(bool isSelected, List<CostRowData> cbaRows) {
    final totalCost = cbaRows.fold<double>(
        0,
        (sum, row) =>
            sum +
            (double.tryParse(row.cost.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFF59E0B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.solution.title.isNotEmpty
                          ? analysis.solution.title
                          : 'Solution ${index + 1}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Preferred Solution',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (analysis.solution.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              analysis.solution.description.length > 200
                  ? '${analysis.solution.description.substring(0, 200)}...'
                  : analysis.solution.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Stats row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatChip(Icons.warning_amber, '$_riskCount Risks',
                  _riskCount > 0 ? const Color(0xFFEF4444) : Colors.grey),
              _buildStatChip(Icons.computer, '$_techCount Technologies',
                  _techCount > 0 ? const Color(0xFF3B82F6) : Colors.grey),
              _buildStatChip(Icons.construction, '$_infraCount Infrastructure',
                  _infraCount > 0 ? const Color(0xFF8B5CF6) : Colors.grey),
              _buildStatChip(
                  Icons.people,
                  '$_stakeholderCount Stakeholders',
                  _stakeholderCount > 0
                      ? const Color(0xFF10B981)
                      : Colors.grey),
              if (cbaRows.isNotEmpty)
                _buildStatChip(
                    Icons.attach_money,
                    '\$${totalCost.toStringAsFixed(0)}',
                    const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRisksSection() {
    if (analysis.risks.isEmpty) {
      return _buildEmptyState(
          'No risks identified', Icons.check_circle, Colors.green);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < analysis.risks.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    analysis.risks[i],
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancedTechSection() {
    if (analysis.technologies.isEmpty &&
        (analysis.itConsiderationText?.isEmpty ?? true)) {
      return _buildEmptyState(
          'No IT considerations recorded', Icons.computer, Colors.blue);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.itConsiderationText?.isNotEmpty == true) ...[
          Text(
            analysis.itConsiderationText!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (analysis.technologies.isNotEmpty) const SizedBox(height: 16),
        ],
        if (analysis.technologies.isNotEmpty) ...[
          const Text(
            'Technologies & Tools:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: analysis.technologies
                .map((tech) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code,
                              size: 14, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Text(
                            tech,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedInfraSection() {
    if (analysis.infrastructure.isEmpty &&
        (analysis.infraConsiderationText?.isEmpty ?? true)) {
      return _buildEmptyState('No infrastructure considerations',
          Icons.construction, Colors.purple);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.infraConsiderationText?.isNotEmpty == true) ...[
          Text(
            analysis.infraConsiderationText!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (analysis.infrastructure.isNotEmpty) const SizedBox(height: 16),
        ],
        if (analysis.infrastructure.isNotEmpty)
          for (final item in analysis.infrastructure)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildEnhancedStakeholdersSection() {
    final hasStakeholders = analysis.stakeholders.isNotEmpty ||
        (analysis.internalStakeholders?.isNotEmpty ?? false) ||
        (analysis.externalStakeholders?.isNotEmpty ?? false);

    if (!hasStakeholders) {
      return _buildEmptyState(
          'No stakeholders identified', Icons.people, Colors.teal);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.externalStakeholders?.isNotEmpty ?? false) ...[
          _buildStakeholderGroup('External Stakeholders',
              analysis.externalStakeholders!, const Color(0xFF059669)),
          const SizedBox(height: 16),
        ],
        if (analysis.internalStakeholders?.isNotEmpty ?? false)
          _buildStakeholderGroup('Internal Stakeholders',
              analysis.internalStakeholders!, const Color(0xFF0891B2)),
        if (analysis.stakeholders.isNotEmpty &&
            (analysis.externalStakeholders?.isEmpty ?? true) &&
            (analysis.internalStakeholders?.isEmpty ?? true))
          _buildStakeholderGroup(
              'Stakeholders', analysis.stakeholders, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildStakeholderGroup(
      String title, List<String> stakeholders, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${stakeholders.length})',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stakeholders
              .map((s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: TextStyle(
                              fontSize: 13, color: color.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color.withOpacity(0.5)),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ProjectDataHelper.getProvider(context);
    final projectData = provider.projectData;
    final preferredAnalysis = projectData.preferredSolutionAnalysis;
    final selectedId = preferredAnalysis?.selectedSolutionId;
    final selectedIndex = preferredAnalysis?.selectedSolutionIndex;
    final selectedTitle = preferredAnalysis?.selectedSolutionTitle ?? '';

    // Check if selected: Primary by index, fallback to UUID, then title
    bool isSelected = false;
    bool titlesMatch(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();
    if (selectedIndex != null && selectedIndex == index) {
      isSelected = true;
    } else if (selectedId != null &&
        index < projectData.potentialSolutions.length) {
      isSelected = projectData.potentialSolutions[index].id == selectedId;
    } else if (selectedTitle.isNotEmpty) {
      isSelected = titlesMatch(selectedTitle, analysis.solution.title);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Comparison',
        ),
        title: Text(
          'Solution Details',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.compare_arrows,
                size: 18, color: Color(0xFF6B7280)),
            label: const Text('Back to Comparison',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Card
                    _buildOverviewCard(isSelected, cbaRows),

                    // Cost Benefit Analysis - Always Expanded
                    _buildSectionCard(
                      icon: Icons.attach_money,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Cost Benefit Analysis',
                      subtitle: cbaRows.isEmpty
                          ? 'No data available'
                          : '${cbaRows.length} cost items',
                      initiallyExpanded: false,
                      content: cbaRows.isEmpty
                          ? _buildEmptyState('No cost analysis available',
                              Icons.attach_money, Colors.amber)
                          : _buildCbaDataTable(
                              cbaRows, projectData.costBenefitCurrency),
                    ),

                    // Risks Identified
                    _buildSectionCard(
                      icon: Icons.warning_amber,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Risks Identified',
                      subtitle: analysis.risks.isEmpty
                          ? 'No risks'
                          : '${analysis.risks.length} risks identified',
                      initiallyExpanded: analysis.risks.isNotEmpty,
                      content: _buildEnhancedRisksSection(),
                    ),

                    // IT Considerations
                    _buildSectionCard(
                      icon: Icons.computer,
                      iconColor: const Color(0xFF3B82F6),
                      title: 'IT Considerations',
                      subtitle: analysis.technologies.isEmpty
                          ? 'No data'
                          : '${analysis.technologies.length} technologies',
                      initiallyExpanded: analysis.technologies.isNotEmpty,
                      content: _buildEnhancedTechSection(),
                    ),

                    // Infrastructure
                    _buildSectionCard(
                      icon: Icons.construction,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Infrastructure Considerations',
                      subtitle: analysis.infrastructure.isEmpty
                          ? 'No data'
                          : '${analysis.infrastructure.length} items',
                      initiallyExpanded: analysis.infrastructure.isNotEmpty,
                      content: _buildEnhancedInfraSection(),
                    ),

                    // Stakeholders
                    _buildSectionCard(
                      icon: Icons.people,
                      iconColor: const Color(0xFF10B981),
                      title: 'Core Stakeholders',
                      subtitle: _stakeholderCount == 0
                          ? 'No stakeholders'
                          : '$_stakeholderCount stakeholders',
                      initiallyExpanded: _stakeholderCount > 0,
                      content: _buildEnhancedStakeholdersSection(),
                    ),

                    // Scope Statement
                    _buildSectionCard(
                      icon: Icons.description,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Scope Statement',
                      subtitle: analysis.solution.description.isEmpty
                          ? 'Not provided'
                          : 'View full scope',
                      initiallyExpanded:
                          analysis.solution.description.isNotEmpty,
                      content: analysis.solution.description.isNotEmpty
                          ? Text(
                              analysis.solution.description,
                              style: const TextStyle(fontSize: 14, height: 1.6),
                            )
                          : _buildEmptyState('No scope statement provided',
                              Icons.description, Colors.indigo),
                    ),

                    const SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ),
            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Selection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async => onSelectPreferred(),
                    icon: const Icon(Icons.check_circle),
                    label: Text(isSelected
                        ? 'Preferred Solution Selected'
                        : 'Select Preferred Solution'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget content,
    bool initiallyExpanded = false,
  }) {
    return _ExpandableSectionCard(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      content: content,
      initiallyExpanded: initiallyExpanded,
    );
  }
}

class _ExpandableSectionCard extends StatefulWidget {
  const _ExpandableSectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.content,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget content;
  final bool initiallyExpanded;

  @override
  State<_ExpandableSectionCard> createState() => _ExpandableSectionCardState();
}

class _ExpandableSectionCardState extends State<_ExpandableSectionCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 22, color: widget.iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  widget.content,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AiTag extends StatelessWidget {
  const _AiTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          borderRadius: BorderRadius.all(Radius.circular(4))),
      child: const Text('AI', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
