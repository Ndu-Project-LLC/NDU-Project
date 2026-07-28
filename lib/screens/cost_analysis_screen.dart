import 'dart:async';
import 'dart:math' as math;
import 'package:ndu_project/utils/finance.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/screens/team_management_screen.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/business_case_header.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/widgets/expanding_text_field.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/widgets/expandable_text.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';

class CostAnalysisScreen extends StatefulWidget {
  final String notes;
  final List<AiSolutionItem> solutions;
  final int? initialStepIndex;
  final int? initialSolutionIndex;
  const CostAnalysisScreen(
      {super.key,
      required this.notes,
      required this.solutions,
      this.initialStepIndex,
      this.initialSolutionIndex});

  @override
  State<CostAnalysisScreen> createState() => _CostAnalysisScreenState();
}

class _CostAnalysisScreenState extends State<CostAnalysisScreen>
    with SingleTickerProviderStateMixin {
  static const List<_StepDefinition> _stepDefinitions = [
    _StepDefinition(
      shortLabel: 'Project Value',
      title: 'Project Benefit Calculation',
      subtitle:
          'Capture project benefits, financial value assumptions, and monetised benefit entries in one place.',
    ),
    _StepDefinition(
      shortLabel: 'Initial Cost Estimate',
      title: 'Initial Cost Estimate',
      subtitle:
          'Every potential solution keeps an AI-assisted cost profile so you can compare spend before diving into detailed project benefits.',
    ),
    _StepDefinition(
      shortLabel: 'Profitability Analysis',
      title: 'Profitability Analysis',
      subtitle:
          'Pick a 3, 5, or 10-year horizon so every solution compares on the same timeframe before exporting to the Preferred Solution Analysis.',
    ),
  ];
  static const double _benefitColumnGap = 12;
  static const double _benefitIndexColumnWidth = 44;
  static const double _benefitCategoryColumnWidth = 170;
  static const double _benefitTitleColumnWidth = 220;
  static const double _benefitUnitValueColumnWidth = 170;
  static const double _benefitTotalUnitsColumnWidth = 140;
  static const double _benefitTotalValueColumnWidth = 170;
  static const double _benefitNotesColumnWidth = 240;
  static const double _benefitActionsColumnWidth = 132;
  static const double _initialCostActionsColumnWidth = 132;

  static const List<CsvColumnSpec> _costCsvColumns = [
    CsvColumnSpec(
      key: 'itemName',
      label: 'Item Name',
      required: true,
      sampleValue: 'Software licenses',
    ),
    CsvColumnSpec(
      key: 'description',
      label: 'Description',
      sampleValue: 'Annual licensing for core platform modules',
    ),
    CsvColumnSpec(
      key: 'cost',
      label: 'Cost',
      required: true,
      hint: 'Numeric value only (e.g. 50000)',
      sampleValue: '50000',
    ),
    CsvColumnSpec(
      key: 'assumptions',
      label: 'Assumptions',
      sampleValue: 'Based on vendor quote Q3 2026',
    ),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _benefitTableHorizontalController = ScrollController();
  final ScrollController _benefitTableRowsVerticalController =
      ScrollController();
  final ScrollController _initialCostTableHorizontalController =
      ScrollController();
  bool _initiationExpanded = true;
  bool _businessCaseExpanded = true;
  final GlobalKey _tablesSectionKey = GlobalKey();
  int _currentStepIndex = 0;
  bool _reviewConfirmed = false;
  // Full Cost Benefit Analysis is only available on the admin web host.
  bool _isFullAdminView = false;
  bool _hasUnsavedChanges = false;
  bool _suppressDirtyTracking = false;
  bool _syncingProjectValueEditors = false;
  bool _autosaveInFlight = false;
  Timer? _autosaveTimer;
  late final TextEditingController _notesController;
  late final List<List<_CostRow>> _rowsPerSolution;
  late final List<_SolutionCostContext> _solutionContexts;
  late final List<List<_BenefitLineItemEntry>> _benefitLineItemsBySolution;
  late final List<String> _projectValueContextHashesBySolution;
  late final List<String> _costBreakdownContextHashesBySolution;
  late final List<List<AiBenefitSavingsSuggestion>>
      _savingsSuggestionsBySolution;
  late final List<String> _savingsContextHashesBySolution;
  // High-level category cost matrix per solution (for Initial Cost Estimate)
  late final List<Map<String, _CategoryCostEntry>> _categoryCostsPerSolution;
  // AI idea pool: per-solution, per-category suggested line items (with costs)
  late final List<Map<String, List<AiCostItem>>> _categoryIdeasPerSolution;
  static const List<_QualitativeOption> _resourceOptions = [
    _QualitativeOption(
      label: 'Lean squad',
      detail: '3-5 FTEs covering core build',
      aiHint: 'Lean cross-functional squad of roughly 3-5 dedicated FTEs.',
    ),
    _QualitativeOption(
      label: 'Core programme team',
      detail: '6-10 FTEs incl. vendor support',
      aiHint:
          'Cross-functional programme team with 6-10 FTEs plus vendor support.',
    ),
    _QualitativeOption(
      label: 'Enterprise delivery model',
      detail: '10+ FTEs across business & IT',
      aiHint:
          'Enterprise-scale delivery model spanning 10+ internal and external FTEs.',
    ),
  ];
  static const List<_QualitativeOption> _timelineOptions = [
    _QualitativeOption(
      label: '0-6 months',
      detail: 'Accelerated delivery window',
      aiHint:
          'Aggressive implementation window under six months (parallelised sprints).',
    ),
    _QualitativeOption(
      label: '6-12 months',
      detail: 'Phased rollout cadence',
      aiHint: 'Phased delivery cadence spanning roughly six to twelve months.',
    ),
    _QualitativeOption(
      label: '12+ months',
      detail: 'Multi-phase programme',
      aiHint:
          'Multi-phase programme extending beyond twelve months with staged deployments.',
    ),
  ];
  static const List<_QualitativeOption> _complexityOptions = [
    _QualitativeOption(
      label: 'Foundational',
      detail: 'Limited integrations, low risk',
      aiHint:
          'Foundational complexity with limited integration and regulatory risk.',
    ),
    _QualitativeOption(
      label: 'Moderate',
      detail: 'Cross-team coordination required',
      aiHint:
          'Moderate complexity requiring cross-team coordination and controlled change.',
    ),
    _QualitativeOption(
      label: 'High',
      detail: 'Heavy integration & governance',
      aiHint:
          'High complexity with heavy integration, governance checks, and dependencies.',
    ),
  ];
  static const Map<String, String> _benefitMetrics = {
    'revenue':
        'A calculation of the income from the number of products/services that would come from the project multiplied by months/year for the number of years. Could be a lumpsum too.',
    'cost_saving':
        'Could be a lumpsum or similar math as #1 but with how much money would be saved from not buying, making something thanks to project.',
    'ops_efficiency':
        'Operational costs saved due to project. Could be same math as #1 and #2 if it\'s renting an equipment or something similar.',
    'productivity':
        'Directly tied to manpower. So, number of people multiplied by number of hours per month, per year. Multiply by salary rate.',
    'regulatory_compliance':
        'Could be a one-time or recurring non-compliance fee and/or cost of being fully shut down for a certain period of time.',
    'process_improvement':
        'Similar to productivity and/or operational efficiency. They can choose which applies the most.',
    'brand_image':
        'Estimation of how much more market gains, revenue (#1), or market loss, cost savings (#2) will result from project. Could also be %.',
    'stakeholder_commitment':
        'Could be gain (#1) or loss avoidance (#2) that\'s associated with meeting shareholder commitments.',
    'other':
        'They can decide which category and use any of the above formulas.',
  };
  static const Map<String, String> _projectValueCompactLabels = {
    'revenue': 'Revenue',
    'cost_saving': 'Cost Saving',
    'ops_efficiency': 'Ops Eff.',
    'productivity': 'Productivity',
    'regulatory_compliance': 'Reg. & Comp.',
    'process_improvement': 'P. Improve.',
    'brand_image': 'Brand Image',
    'stakeholder_commitment': 'SH Comm.',
    'other': 'Other',
  };
  static const List<MapEntry<String, String>> _projectValueFields = [
    MapEntry('revenue', 'Revenue'),
    MapEntry('cost_saving', 'Cost Saving'),
    MapEntry('ops_efficiency', 'Operational Efficiency'),
    MapEntry('productivity', 'Productivity'),
    MapEntry('regulatory_compliance', 'Regulatory & Compliance'),
    MapEntry('process_improvement', 'Process Improvement'),
    MapEntry('brand_image', 'Brand Image'),
    MapEntry('stakeholder_commitment', 'Stakeholder Commitment'),
    MapEntry('other', 'Other'),
  ];
  late final TextEditingController _projectValueAmountController;
  late final Map<String, TextEditingController> _projectValueBenefitControllers;
  late final TabController _benefitCategoryTabController;
  late final List<String> _projectValueAmountBySolution;
  late final List<Map<String, String>> _projectValueBenefitsBySolution;
  int _activeBenefitCategoryIndex = 0;
  int _activeTab = 0;
  String _currency = 'USD';
  String _lastCurrency = 'USD';
  static const Map<String, double> _currencyRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 155.0,
    'CNY': 7.25,
    'CAD': 1.37,
    'AUD': 1.53,
    'CHF': 0.89,
    'INR': 83.5,
    'BRL': 5.05,
    'MXN': 17.2,
    'ZAR': 18.5,
    'SGD': 1.35,
    'ZMW': 27.5,
    'NGN': 1550.0,
    'AED': 3.67,
  };
  late final OpenAiServiceSecure _openAi;
  bool _isGenerating = false;
  bool _isGeneratingValue = false;
  // Basis frequency for multi-year benefit calculations (required selection)
  String? _basisFrequency;
  static const List<String> _frequencyOptions = [
    'Monthly',
    'Quarterly',
    'Yearly'
  ];
  // Basis frequency for tracker table (Annual vs Monthly)
  String _trackerBasisFrequency = 'Annual';
  String? _error;
  String? _projectValueError;
  int _npvHorizon = 5;
  double _discountRate = 0.10; // Default 10% discount rate for NPV calculations
  static const List<double> _discountRateOptions = [0.08, 0.10, 0.12];
  final Set<int> _solutionLoading = <int>{};
  int _benefitTabIndex = 0;
  final TextEditingController _savingsNotesController = TextEditingController();
  final TextEditingController _savingsTargetController =
      TextEditingController(text: '10');
  bool _isSavingsGenerating = false;
  String? _savingsError;

  Future<void> _exportPdf() async {
    final notes = _notesController.text.trim();
    final sections = <PdfSection>[
      PdfSection.text('Notes', notes.isEmpty ? 'No data recorded.' : notes),
      PdfSection.keyValue('Configuration', [
        {'Currency': _currency},
        {'NPV Horizon': '$_npvHorizon years'},
        {'Discount Rate': '${(_discountRate * 100).toStringAsFixed(0)}%'},
        if (_basisFrequency != null) {'Basis Frequency': _basisFrequency!},
      ]),
    ];
    for (int i = 0; i < _rowsPerSolution.length; i++) {
      final solutionTitle = _solutionTitle(i);
      final costRows = _rowsPerSolution[i];
      final tableRows = <List<String>>[];
      for (final row in costRows) {
        final itemName = row.itemController.text.trim();
        final cost = row.costController.text.trim();
        if (itemName.isNotEmpty || cost.isNotEmpty) {
          tableRows.add([
            itemName.isEmpty ? 'N/A' : itemName,
            cost.isEmpty ? 'N/A' : cost,
          ]);
        }
      }
      sections.add(PdfSection.table(
        'Cost Estimate - $solutionTitle',
        headers: ['Item', 'Cost ($_currency)'],
        rows: tableRows,
      ));
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Cost Benefit Analysis',
      sections: sections,
    );
  }

  /// AI Assist — generates cost breakdown + benefit suggestions for all
  /// solutions using the project context. Shows a loading SnackBar while
  /// generating and a success SnackBar when complete.
  Future<void> _aiAssist() async {
    if (_isGenerating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Assist is already generating. Please wait...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('KAZ AI is generating cost benefit analysis...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    // Generate cost breakdown for all solutions
    await _populateCategoriesFromAi();

    // Generate project value if not already populated
    if (_projectValueAmountController.text.trim().isEmpty) {
      await _generateProjectValue();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('KAZ AI: Cost benefit analysis generated successfully!'),
        backgroundColor: Color(0xFF059669),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _suppressDirtyTracking = true;
    _notesController = TextEditingController(text: widget.notes);
    _notesController.addListener(_markDirty);
    _projectValueAmountController = TextEditingController();
    _projectValueBenefitControllers = {
      for (final field in _projectValueFields)
        field.key: TextEditingController(),
    };
    _benefitCategoryTabController =
        TabController(length: _projectValueFields.length, vsync: this);
    _activeBenefitCategoryIndex = _benefitCategoryTabController.index;
    _benefitCategoryTabController.addListener(() {
      if (_benefitCategoryTabController.indexIsChanging) return;
      if (!mounted) return;
      setState(() {
        _activeBenefitCategoryIndex = _benefitCategoryTabController.index;
      });
    });
    _rowsPerSolution = List.generate(
        widget.solutions.isEmpty ? 3 : widget.solutions.length, (i) {
      // Seed each tab with 3 placeholder rows to mirror the screenshot
      return List.generate(
          3, (j) => _CostRow(currencyProvider: () => _currency));
    });
    // Render the full workflow only on admin.nduproject.com.
    _isFullAdminView = AccessPolicy.isRestrictedAdminHost();
    if (_isFullAdminView) {
      _currentStepIndex = _boundedIndex(
        widget.initialStepIndex ?? _currentStepIndex,
        _stepDefinitions.length,
      );
    } else {
      // All non-admin-host renders land on Initial Cost Estimate (index 1).
      _currentStepIndex = 1;
    }
    _activeTab = _boundedIndex(
      widget.initialSolutionIndex ?? _activeTab,
      _rowsPerSolution.isEmpty ? 1 : _rowsPerSolution.length,
    );
    _projectValueAmountBySolution =
        List<String>.filled(_rowsPerSolution.length, '');
    _projectValueBenefitsBySolution = List.generate(
      _rowsPerSolution.length,
      (_) => <String, String>{},
    );
    _benefitLineItemsBySolution = List.generate(
      _rowsPerSolution.length,
      (_) => <_BenefitLineItemEntry>[],
    );
    _projectValueContextHashesBySolution =
        List<String>.filled(_rowsPerSolution.length, '');
    _costBreakdownContextHashesBySolution =
        List<String>.filled(_rowsPerSolution.length, '');
    _savingsSuggestionsBySolution = List.generate(
      _rowsPerSolution.length,
      (_) => <AiBenefitSavingsSuggestion>[],
    );
    _savingsContextHashesBySolution =
        List<String>.filled(_rowsPerSolution.length, '');
    _solutionContexts =
        List.generate(_rowsPerSolution.length, (_) => _SolutionCostContext());
    _categoryCostsPerSolution = List.generate(_rowsPerSolution.length, (_) {
      return {
        for (final field in _projectValueFields)
          field.key: _CategoryCostEntry(categoryKey: field.key)
            ..bind(_markDirtyAndRecalc),
      };
    });
    _categoryIdeasPerSolution = List.generate(_rowsPerSolution.length, (_) {
      return {
        for (final field in _projectValueFields) field.key: <AiCostItem>[],
      };
    });
    for (final context in _solutionContexts) {
      context.justificationController.addListener(_markDirty);
    }
    _projectValueAmountController.addListener(_onProjectValueFieldChanged);
    for (final controller in _projectValueBenefitControllers.values) {
      controller.addListener(_onProjectValueFieldChanged);
    }
    _savingsNotesController.addListener(_onSavingsContextChanged);
    _savingsTargetController.addListener(_onSavingsContextChanged);
    for (final list in _rowsPerSolution) {
      for (final row in list) {
        _attachRowDirtyListeners(row);
      }
    }
    for (int i = 0; i < _solutionContexts.length; i++) {
      _refreshJustificationFor(i, force: true);
    }
    ApiKeyManager.initializeApiKey();
    _openAi = OpenAiServiceSecure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        final hasExistingData = _loadExistingData();
        _loadProjectValueEditorsForSolution(_activeSolutionIndex());
        _autoPopulateForNewProject(hasExistingData: hasExistingData)
            .whenComplete(() {
          _suppressDirtyTracking = false;
        });
      } catch (e) {
        debugPrint('CostAnalysis initState error: $e');
        _suppressDirtyTracking = false;
      }
    });
  }

  List<_BenefitLineItemEntry> _benefitItemsForSolution(int index) {
    if (index < 0 || index >= _benefitLineItemsBySolution.length) {
      return const <_BenefitLineItemEntry>[];
    }
    return _benefitLineItemsBySolution[index];
  }

  List<_BenefitLineItemEntry> get _benefitLineItems =>
      _benefitItemsForSolution(_activeSolutionIndex());

  Iterable<_BenefitLineItemEntry> get _allBenefitLineItems sync* {
    for (final items in _benefitLineItemsBySolution) {
      yield* items;
    }
  }

  List<AiBenefitSavingsSuggestion> _savingsSuggestionsForSolution(int index) {
    if (index < 0 || index >= _savingsSuggestionsBySolution.length) {
      return const <AiBenefitSavingsSuggestion>[];
    }
    return _savingsSuggestionsBySolution[index];
  }

  List<AiBenefitSavingsSuggestion> get _savingsSuggestions =>
      _savingsSuggestionsForSolution(_activeSolutionIndex());

  Future<void> _autoPopulateForNewProject(
      {required bool hasExistingData}) async {
    if (widget.solutions.isEmpty) {
      return;
    }

    final projectValueTargets = <int>[];
    final costBreakdownTargets = <int>[];
    for (int i = 0; i < _rowsPerSolution.length; i++) {
      final projectValueHash = _projectValueContextHashForSolution(i);
      final projectValueContextChanged =
          _projectValueContextHashesBySolution[i].isNotEmpty &&
              _projectValueContextHashesBySolution[i] != projectValueHash;
      if (_needsProjectValueGeneration(solutionIndex: i) ||
          projectValueContextChanged) {
        projectValueTargets.add(i);
      }
      final costHash = _costBreakdownContextHashForSolution(i);
      final costContextChanged =
          _costBreakdownContextHashesBySolution[i].isNotEmpty &&
              _costBreakdownContextHashesBySolution[i] != costHash;
      if (!_hasMeaningfulCostRowsForSolution(i) || costContextChanged) {
        costBreakdownTargets.add(i);
      }
    }
    final activeIndex = _activeSolutionIndex();
    final savingsContextChanged =
        _savingsContextHashesBySolution[activeIndex].isNotEmpty &&
            _savingsContextHashesBySolution[activeIndex] !=
                _savingsContextHashForSolution(activeIndex);
    final needsSavings =
        _hasMeaningfulBenefitLineItems(solutionIndex: activeIndex) &&
            (_savingsSuggestionsForSolution(activeIndex).isEmpty ||
                savingsContextChanged);
    if (hasExistingData &&
        projectValueTargets.isEmpty &&
        costBreakdownTargets.isEmpty &&
        !needsSavings) {
      return;
    }

    for (final solutionIndex in projectValueTargets) {
      await _generateProjectValue(
        solutionIndex: solutionIndex,
        showFeedback: false,
        persist: false,
      );
    }
    if (_benefitItemsForSolution(activeIndex).isEmpty) {
      _seedDefaultProjectBenefits();
    }
    for (final solutionIndex in costBreakdownTargets) {
      await _generateCostBreakdownForSolution(
        solutionIndex,
        showFeedback: false,
        persist: false,
      );
    }
    if (_benefitItemsForSolution(activeIndex).isNotEmpty &&
        needsSavings &&
        !_isSavingsGenerating) {
      await _generateSavingsSuggestions(showFeedback: false);
    }
    await _saveCostAnalysisData();
  }

  void _seedDefaultProjectBenefits() {
    if (!mounted || _benefitLineItems.isNotEmpty) return;

    final provider = ProjectDataInherited.maybeOf(context);
    final projectData = provider?.projectData;
    final opportunities = (projectData?.opportunities ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: true);

    final candidateTitles = <String>[
      ...opportunities,
      for (int i = 0; i < _rowsPerSolution.length; i++)
        '${_solutionTitle(i)} value gain'
    ];
    if (candidateTitles.isEmpty) {
      candidateTitles.addAll(const [
        'Operational efficiency gain',
        'Cost avoidance',
        'Revenue uplift',
      ]);
    }

    // Detect project scale from project context for realistic default values
    final projectContext = [
      projectData?.projectName ?? '',
      projectData?.solutionTitle ?? '',
      projectData?.solutionDescription ?? '',
      projectData?.businessCase ?? '',
      ...opportunities,
    ].join(' ').toLowerCase();

    final isSmallProject = _isSmallScaleProject(projectContext);
    final isLargeProject = _isLargeScaleProject(projectContext);

    final baseEstimate =
        _parseCurrencyInput(_projectValueAmountController.text);
    // Scale-aware per-unit defaults based on detected project scale.
    // Small business (barbershop, salon): ~$200-$800/mo per benefit stream
    // Medium/department: ~$800-$2,500/mo
    // Large/enterprise: ~$2,500-$8,000/mo
    final double baseUnitValue;
    if (baseEstimate > 0) {
      baseUnitValue = baseEstimate / 36;
    } else if (isSmallProject) {
      baseUnitValue = 350.0; // ~$350/mo per benefit line for small businesses
    } else if (isLargeProject) {
      baseUnitValue = 4500.0; // ~$4,500/mo per benefit line for large projects
    } else {
      baseUnitValue = 850.0; // ~$850/mo per benefit line (medium default)
    }
    const categories = <String>[
      'process_improvement',
      'ops_efficiency',
      'cost_saving',
      'revenue',
      'productivity',
    ];

    setState(() {
      final itemsToSeed = math.min(3, candidateTitles.length);
      for (int i = 0; i < itemsToSeed; i++) {
        // Vary unit values modestly around the base, not with aggressive multipliers
        final unitValue = baseUnitValue * (1 + (i * 0.15));
        // Derive a simple, logical unit count based on the benefit title
        final units = _deriveUnitsFromTitle(candidateTitles[i]);
        final entry = _BenefitLineItemEntry(
          id: 'benefit-seed-${DateTime.now().microsecondsSinceEpoch}-$i',
          categoryKey: categories[i % categories.length],
          title: candidateTitles[i],
          unitValue: unitValue,
          units: units,
          notes:
              'Auto-seeded estimate based on project context; refine assumptions.',
        );
        entry.bind(_onBenefitEntryEdited);
        _benefitLineItems.add(entry);
      }
    });
  }

  /// Derives a simple, logical unit count from the benefit title.
  ///
  /// Instead of always using 12 (months), this method picks a sensible
  /// unit based on keywords in the benefit title:
  /// - Revenue/sales → number of transactions or customers
  /// - Cost saving → number of cost centers or departments
  /// - Efficiency/productivity → number of processes or workflows
  /// - Compliance → number of regulatory items
  /// - Default → 1 (single instance)
  static double _deriveUnitsFromTitle(String title) {
    final lower = title.toLowerCase();

    // Revenue-related: units = number of sales/transactions/customers
    if (lower.contains('revenue') ||
        lower.contains('sales') ||
        lower.contains('income') ||
        lower.contains('uplift')) {
      return 100; // 100 transactions/customers per period
    }

    // Cost saving: units = number of cost centers or departments
    if (lower.contains('cost') ||
        lower.contains('saving') ||
        lower.contains('avoidance') ||
        lower.contains('reduction')) {
      return 5; // 5 cost centers or departments
    }

    // Efficiency/productivity: units = number of processes or workflows
    if (lower.contains('efficiency') ||
        lower.contains('productivity') ||
        lower.contains('automation') ||
        lower.contains('workflow')) {
      return 10; // 10 processes or workflows improved
    }

    // Compliance: units = number of compliance items
    if (lower.contains('compliance') ||
        lower.contains('regulatory') ||
        lower.contains('audit') ||
        lower.contains('risk')) {
      return 8; // 8 compliance items addressed
    }

    // Process improvement: units = number of processes
    if (lower.contains('process') || lower.contains('improvement')) {
      return 6; // 6 processes improved
    }

    // Staffing/HR: units = number of employees
    if (lower.contains('staff') ||
        lower.contains('employee') ||
        lower.contains('hr') ||
        lower.contains('training')) {
      return 20; // 20 employees affected
    }

    // Default: single instance (1 unit)
    return 1;
  }

  /// Returns a short description of what the "Units" value represents
  /// for a given benefit line item, based on the benefit title.
  String _unitDescriptionForEntry(_BenefitLineItemEntry entry) {
    final title = entry.titleController.text.trim().toLowerCase();

    if (title.contains('revenue') ||
        title.contains('sales') ||
        title.contains('income') ||
        title.contains('uplift')) {
      return 'transactions';
    }
    if (title.contains('cost') ||
        title.contains('saving') ||
        title.contains('avoidance') ||
        title.contains('reduction')) {
      return 'cost centers';
    }
    if (title.contains('efficiency') ||
        title.contains('productivity') ||
        title.contains('automation') ||
        title.contains('workflow')) {
      return 'processes';
    }
    if (title.contains('compliance') ||
        title.contains('regulatory') ||
        title.contains('audit') ||
        title.contains('risk')) {
      return 'compliance items';
    }
    if (title.contains('process') || title.contains('improvement')) {
      return 'processes';
    }
    if (title.contains('staff') ||
        title.contains('employee') ||
        title.contains('hr') ||
        title.contains('training')) {
      return 'employees';
    }
    if (title.contains('customer') ||
        title.contains('user') ||
        title.contains('client')) {
      return 'users';
    }
    if (title.contains('month')) {
      return 'months';
    }
    if (title.contains('year') || title.contains('annual')) {
      return 'years';
    }
    return 'units';
  }

  /// Detects whether the project context suggests a small-scale project
  /// (barbershop, salon, small retail, local business, etc.)
  static bool _isSmallScaleProject(String context) {
    final smallIndicators = [
      'barbershop',
      'barber shop',
      'salon',
      'hair salon',
      'nail salon',
      'small business',
      'small retail',
      'sole proprietor',
      'mom and pop',
      'local shop',
      'local store',
      'boutique',
      'freelance',
      'solo',
      'micro business',
      'home-based',
      'pop-up',
      'food truck',
      'food cart',
      'corner store',
      'kiosk',
      'stall',
      'personal brand',
      'pet grooming',
      'dog walking',
      'tutoring',
      'cleaning service',
      'lawn care',
      'small clinic',
      'dental practice',
      'yoga studio',
      'gym studio',
      'personal training',
      'craft',
      'artisan',
      'personal app',
      'portfolio app',
      'booking app',
      'appointment app',
    ];
    return smallIndicators.any((term) => context.contains(term));
  }

  /// Detects whether the project context suggests a large-scale project
  /// (enterprise, infrastructure, government, etc.)
  static bool _isLargeScaleProject(String context) {
    final largeIndicators = [
      'enterprise',
      'corporation',
      'multi-site',
      'infrastructure',
      'government',
      'municipal',
      'federal',
      'hospital',
      'university',
      'campus',
      'city-wide',
      'nationwide',
      'global',
      'industrial',
      'manufacturing plant',
      'power plant',
      'data center',
      'data centre',
      'oil and gas',
      'mining',
      'pipeline',
      'railway',
      'airport',
      'large-scale',
      'large scale',
      'multi-phase',
      'multi-year',
      'multi-million',
      'digital transformation',
    ];
    return largeIndicators.any((term) => context.contains(term));
  }

  bool _hasMeaningfulBenefitLineItems({int? solutionIndex}) {
    final entries = solutionIndex == null
        ? _benefitLineItems
        : _benefitItemsForSolution(solutionIndex);
    return entries.any((entry) {
      final hasTitle = entry.titleController.text.trim().isNotEmpty;
      final hasValue = entry.totalValue > 0;
      final hasNotes = entry.notesController.text.trim().isNotEmpty;
      return hasTitle || hasValue || hasNotes;
    });
  }

  bool _hasMeaningfulCostRowsForSolution(int index) {
    if (index < 0 || index >= _rowsPerSolution.length) return false;
    return _rowsPerSolution[index].any((row) {
      final name = row.itemController.text.trim();
      final description = row.descriptionController.text.trim().toLowerCase();
      final assumptions = row.assumptionsController.text.trim();
      final hasName = name.isNotEmpty && name.toLowerCase() != 'name';
      final hasDescription =
          description.isNotEmpty && !description.startsWith('lorem ipsum');
      final hasAssumptions = assumptions.isNotEmpty;
      final hasCost = row.currentCost() > 0;
      return hasName || hasDescription || hasAssumptions || hasCost;
    });
  }

  bool _needsProjectValueGeneration({int? solutionIndex}) {
    final index = solutionIndex ?? _activeSolutionIndex();
    if (index < 0 || index >= _projectValueAmountBySolution.length) {
      return true;
    }
    final hasBaselineValue =
        _parseCurrencyInput(_projectValueAmountBySolution[index].trim()) > 0;
    if (!hasBaselineValue) return true;
    if (_projectValueBenefitsBySolution[index].isEmpty) return true;
    if (!_hasMeaningfulBenefitLineItems(solutionIndex: index)) return true;
    return false;
  }

  String _stableHash(String value) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _projectValueContextHashForSolution(int index) {
    final solution = _solutionAt(index);
    final buffer = StringBuffer()
      ..writeln(_buildUnifiedAiContext(
        sectionLabel: 'Cost Benefit Analysis - Project Benefit Calculation',
        forSolution: index,
      ))
      ..writeln(solution?.title ?? '')
      ..writeln(solution?.description ?? '')
      ..writeln(_currency)
      ..writeln(_basisFrequency ?? '');
    return _stableHash(buffer.toString());
  }

  String _costBreakdownContextHashForSolution(int index) {
    final solution = _solutionAt(index);
    final contextData = _contextFor(index);
    final buffer = StringBuffer()
      ..writeln(_buildUnifiedAiContext(
        sectionLabel: 'Cost Benefit Analysis - Initial Cost Estimate',
        forSolution: index,
      ))
      ..writeln(solution?.title ?? '')
      ..writeln(solution?.description ?? '')
      ..writeln(_currency)
      ..writeln(contextData.resourceIndex)
      ..writeln(contextData.timelineIndex)
      ..writeln(contextData.complexityIndex)
      ..writeln(contextData.justificationController.text.trim());
    return _stableHash(buffer.toString());
  }

  String _savingsContextHashForSolution(int index) {
    final buffer = StringBuffer()
      ..writeln(_buildUnifiedAiContext(
        sectionLabel: 'Cost Benefit Analysis - Savings Calculator',
        forSolution: index,
      ))
      ..writeln(_savingsTargetController.text.trim())
      ..writeln(_savingsNotesController.text.trim())
      ..writeln(_trackerBasisFrequency);
    for (final entry in _benefitItemsForSolution(index)) {
      buffer
        ..writeln(entry.categoryKey)
        ..writeln(entry.titleController.text.trim())
        ..writeln(entry.unitValueController.text.trim())
        ..writeln(entry.unitsController.text.trim())
        ..writeln(entry.notesController.text.trim());
    }
    return _stableHash(buffer.toString());
  }

  String _truncateAiContext(String text, {int maxChars = 18000}) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n\n[Context truncated for length]';
  }

  String _buildUnifiedAiContext({
    String sectionLabel = 'Cost Benefit Analysis',
    int? forSolution,
  }) {
    final provider = ProjectDataInherited.maybeOf(context);
    final projectData = provider?.projectData;
    final sections = <String>[];

    if (projectData != null) {
      final contextScan = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: sectionLabel,
      ).trim();
      if (contextScan.isNotEmpty) {
        sections.add('Project context scan:\n$contextScan');
      }

      final structured = ProjectDataHelper.buildFepContext(
        projectData,
        sectionLabel: sectionLabel,
      ).trim();
      if (structured.isNotEmpty) {
        sections.add('Structured project context:\n$structured');
      }
    }

    final costContext = _buildCostContextNotes(forSolution: forSolution).trim();
    if (costContext.isNotEmpty) {
      sections.add('Cost analysis context:\n$costContext');
    }

    return _truncateAiContext(sections.join('\n\n'));
  }

  String _normalizeBenefitCategoryKey(String rawCategory) {
    final normalized = rawCategory
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return _projectValueFields.first.key;

    final directKey = normalized.replaceAll(' ', '_');
    for (final field in _projectValueFields) {
      if (field.key == directKey) return field.key;
      if (field.value.toLowerCase() == normalized) return field.key;
    }

    if (normalized.contains('revenue') ||
        normalized.contains('financial gain') ||
        normalized == 'financial') {
      return 'revenue';
    }
    if (normalized.contains('cost saving') ||
        normalized.contains('cost reduction') ||
        normalized.contains('cost avoid')) {
      return 'cost_saving';
    }
    if (normalized.contains('operational') ||
        normalized.contains('ops efficiency') ||
        normalized.contains('efficiency')) {
      return 'ops_efficiency';
    }
    if (normalized.contains('productivity') ||
        normalized.contains('throughput') ||
        normalized.contains('cycle time')) {
      return 'productivity';
    }
    if (normalized.contains('regulatory') ||
        normalized.contains('compliance') ||
        normalized.contains('risk reduction')) {
      return 'regulatory_compliance';
    }
    if (normalized.contains('process') || normalized.contains('workflow')) {
      return 'process_improvement';
    }
    if (normalized.contains('brand') ||
        normalized.contains('reputation') ||
        normalized.contains('perception')) {
      return 'brand_image';
    }
    if (normalized.contains('stakeholder') ||
        normalized.contains('shareholder') ||
        normalized.contains('investor')) {
      return 'stakeholder_commitment';
    }
    if (normalized == 'other' || normalized.contains('misc')) {
      return 'other';
    }
    return 'other';
  }

  Map<String, String> _normalizeProjectValueBenefitEntries(Map rawEntries) {
    final normalized = <String, String>{};
    for (final entry in rawEntries.entries) {
      final value = (entry.value ?? '').toString().trim();
      if (value.isEmpty) continue;
      final key = _normalizeBenefitCategoryKey((entry.key ?? '').toString());
      final existing = normalized[key];
      if (existing == null || value.length > existing.length) {
        normalized[key] = value;
      }
    }
    return normalized;
  }

  bool _loadExistingData() {
    try {
      final provider = ProjectDataInherited.of(context);
      final costAnalysisData = provider.projectData.costAnalysisData;
      final savedCurrency = provider.projectData.costBenefitCurrency.trim();
      if (savedCurrency.isNotEmpty) {
        _currency = savedCurrency;
        _lastCurrency = savedCurrency;
      }

      if (costAnalysisData == null) {
        if (mounted) setState(() {});
        return false;
      }

      // Load notes
      if (costAnalysisData.notes.isNotEmpty) {
        _notesController.text = costAnalysisData.notes;
      }

      bool titlesMatch(String a, String b) =>
          a.trim().toLowerCase() == b.trim().toLowerCase();

      // Load Step 1: per-solution Project Value data.
      for (int i = 0; i < _projectValueAmountBySolution.length; i++) {
        _projectValueAmountBySolution[i] = '';
        _projectValueBenefitsBySolution[i] = <String, String>{};
        _projectValueContextHashesBySolution[i] = '';
        _costBreakdownContextHashesBySolution[i] = '';
        _savingsContextHashesBySolution[i] = '';
        for (final entry in _benefitItemsForSolution(i)) {
          entry.unbind();
          entry.dispose();
        }
        _benefitItemsForSolution(i).clear();
        _savingsSuggestionsBySolution[i].clear();
      }

      if (costAnalysisData.solutionProjectBenefits.isNotEmpty) {
        for (int i = 0; i < _rowsPerSolution.length; i++) {
          final expectedTitle = _solutionTitle(i);
          SolutionProjectBenefitData? match;
          for (final item in costAnalysisData.solutionProjectBenefits) {
            if (titlesMatch(item.solutionTitle, expectedTitle)) {
              match = item;
              break;
            }
          }
          match ??= i < costAnalysisData.solutionProjectBenefits.length
              ? costAnalysisData.solutionProjectBenefits[i]
              : null;
          if (match == null) continue;

          _projectValueAmountBySolution[i] = match.projectValueAmount;
          _projectValueBenefitsBySolution[i] =
              _normalizeProjectValueBenefitEntries(
            match.projectValueBenefits,
          );
          _projectValueContextHashesBySolution[i] = match.contextHash;
          for (final item in match.projectBenefits) {
            final loadedUnits = double.tryParse(item.units) ?? 0;
            // If units is the old hardcoded default of 12, re-derive from title
            final effectiveUnits = loadedUnits == 12
                ? _deriveUnitsFromTitle(item.title)
                : loadedUnits;
            final entry = _BenefitLineItemEntry(
              id: item.id,
              categoryKey: _normalizeBenefitCategoryKey(item.categoryKey),
              title: item.title,
              unitValue: double.tryParse(item.unitValue) ?? 0,
              units: effectiveUnits,
              notes: item.notes,
            );
            entry.bind(_onBenefitEntryEdited);
            _benefitItemsForSolution(i).add(entry);
          }
          if (_projectValueContextHashesBySolution[i].isEmpty &&
              (_parseCurrencyInput(_projectValueAmountBySolution[i]) > 0 ||
                  _projectValueBenefitsBySolution[i].isNotEmpty ||
                  _benefitItemsForSolution(i).isNotEmpty)) {
            _projectValueContextHashesBySolution[i] =
                _projectValueContextHashForSolution(i);
          }
        }
      } else {
        // Backward compatibility with single-solution legacy payloads.
        if (_projectValueAmountBySolution.isNotEmpty) {
          _projectValueAmountBySolution[0] =
              costAnalysisData.projectValueAmount;
          _projectValueBenefitsBySolution[0] =
              _normalizeProjectValueBenefitEntries(
            costAnalysisData.projectValueBenefits,
          );
          for (final item in costAnalysisData.benefitLineItems) {
            final loadedUnits = double.tryParse(item.units) ?? 0;
            // If units is the old hardcoded default of 12, re-derive from title
            final effectiveUnits = loadedUnits == 12
                ? _deriveUnitsFromTitle(item.title)
                : loadedUnits;
            final entry = _BenefitLineItemEntry(
              id: item.id,
              categoryKey: _normalizeBenefitCategoryKey(item.categoryKey),
              title: item.title,
              unitValue: double.tryParse(item.unitValue) ?? 0,
              units: effectiveUnits,
              notes: item.notes,
            );
            entry.bind(_onBenefitEntryEdited);
            _benefitItemsForSolution(0).add(entry);
          }
          if (_parseCurrencyInput(_projectValueAmountBySolution[0]) > 0 ||
              _projectValueBenefitsBySolution[0].isNotEmpty ||
              _benefitItemsForSolution(0).isNotEmpty) {
            _projectValueContextHashesBySolution[0] =
                _projectValueContextHashForSolution(0);
          }
        }
      }

      // Load savings data
      if (costAnalysisData.savingsNotes.isNotEmpty) {
        _savingsNotesController.text = costAnalysisData.savingsNotes;
      }
      if (costAnalysisData.savingsTarget.isNotEmpty) {
        _savingsTargetController.text = costAnalysisData.savingsTarget;
      }
      if (costAnalysisData.basisFrequency != null &&
          _frequencyOptions.contains(costAnalysisData.basisFrequency)) {
        _basisFrequency = costAnalysisData.basisFrequency;
      }
      if (costAnalysisData.trackerBasisFrequency.isNotEmpty &&
          (costAnalysisData.trackerBasisFrequency == 'Annual' ||
              costAnalysisData.trackerBasisFrequency == 'Quarterly' ||
              costAnalysisData.trackerBasisFrequency == 'Monthly')) {
        _trackerBasisFrequency = costAnalysisData.trackerBasisFrequency;
      }
      final savedDiscountRate = costAnalysisData.npvDiscountRate;
      if (_discountRateOptions
          .any((rate) => (savedDiscountRate - rate).abs() < 0.0001)) {
        _discountRate = savedDiscountRate;
      } else {
        _discountRate = 0.10;
      }

      // Load Step 2: Cost rows for each solution
      for (int i = 0; i < _rowsPerSolution.length; i++) {
        final expectedTitle = _solutionTitle(i);
        SolutionCostData? solutionCost;
        for (final item in costAnalysisData.solutionCosts) {
          if (titlesMatch(item.solutionTitle, expectedTitle)) {
            solutionCost = item;
            break;
          }
        }
        solutionCost ??= i < costAnalysisData.solutionCosts.length
            ? costAnalysisData.solutionCosts[i]
            : null;
        if (solutionCost == null) continue;
        _costBreakdownContextHashesBySolution[i] = solutionCost.contextHash;

        final rows = _rowsPerSolution[i];

        // Ensure we have enough rows
        while (rows.length < solutionCost.costRows.length) {
          final newRow = _CostRow(currencyProvider: () => _currency);
          _attachRowDirtyListeners(newRow);
          rows.add(newRow);
        }

        for (int j = 0;
            j < solutionCost.costRows.length && j < rows.length;
            j++) {
          final costRow = solutionCost.costRows[j];
          final row = rows[j];

          row.itemController.text = costRow.itemName;
          row.descriptionController.text = costRow.description;
          row.costController.text = costRow.cost;
          row.assumptionsController.text = costRow.assumptions;
        }
        if (_costBreakdownContextHashesBySolution[i].isEmpty &&
            _hasMeaningfulCostRowsForSolution(i)) {
          _costBreakdownContextHashesBySolution[i] =
              _costBreakdownContextHashForSolution(i);
        }
      }

      // Load per-solution category estimate values and notes.
      for (int i = 0; i < _categoryCostsPerSolution.length; i++) {
        final expectedTitle = _solutionTitle(i);
        SolutionCategoryCostData? categoryData;
        for (final item in costAnalysisData.solutionCategoryCosts) {
          if (titlesMatch(item.solutionTitle, expectedTitle)) {
            categoryData = item;
            break;
          }
        }
        categoryData ??= i < costAnalysisData.solutionCategoryCosts.length
            ? costAnalysisData.solutionCategoryCosts[i]
            : null;
        if (categoryData == null) continue;

        final categoryMap = _categoryCostsPerSolution[i];
        for (final field in _projectValueFields) {
          final entry = categoryMap[field.key];
          if (entry == null) continue;
          entry.costController.text =
              categoryData.categoryCosts[field.key] ?? '';
          entry.notesController.text =
              categoryData.categoryNotes[field.key] ?? '';
        }
      }

      // Load saved assumptions and cost-driver narrative per solution.
      for (int i = 0; i < _solutionContexts.length; i++) {
        final expectedTitle = _solutionTitle(i);
        SolutionCostAssumptionData? assumptionData;
        for (final item in costAnalysisData.solutionCostAssumptions) {
          if (titlesMatch(item.solutionTitle, expectedTitle)) {
            assumptionData = item;
            break;
          }
        }
        assumptionData ??= i < costAnalysisData.solutionCostAssumptions.length
            ? costAnalysisData.solutionCostAssumptions[i]
            : null;
        if (assumptionData == null) continue;
        final context = _solutionContexts[i];
        context.resourceIndex = assumptionData.resourceIndex;
        context.timelineIndex = assumptionData.timelineIndex;
        context.complexityIndex = assumptionData.complexityIndex;
        context.justificationController.text = assumptionData.justification;
      }

      for (int i = 0; i < _rowsPerSolution.length; i++) {
        final expectedTitle = _solutionTitle(i);
        SolutionSavingsData? savingsData;
        for (final item in costAnalysisData.solutionSavingsSuggestions) {
          if (titlesMatch(item.solutionTitle, expectedTitle)) {
            savingsData = item;
            break;
          }
        }
        savingsData ??= i < costAnalysisData.solutionSavingsSuggestions.length
            ? costAnalysisData.solutionSavingsSuggestions[i]
            : null;
        if (savingsData == null) continue;
        _savingsContextHashesBySolution[i] = savingsData.contextHash;
        _savingsSuggestionsBySolution[i] = savingsData.suggestions
            .map(
              (item) => AiBenefitSavingsSuggestion(
                lever: item.lever,
                recommendation: item.recommendation,
                projectedSavings: item.projectedSavings,
                timeframe: item.timeframe,
                confidence: item.confidence,
                rationale: item.rationale,
              ),
            )
            .toList();
        if (_savingsContextHashesBySolution[i].isEmpty &&
            _savingsSuggestionsBySolution[i].isNotEmpty) {
          _savingsContextHashesBySolution[i] =
              _savingsContextHashForSolution(i);
        }
      }

      if (mounted) setState(() {});
      final hasSolutionRows = costAnalysisData.solutionCosts.any(
        (solution) => solution.costRows.any((row) {
          final name = row.itemName.trim();
          final description = row.description.trim().toLowerCase();
          final assumptions = row.assumptions.trim();
          final hasName = name.isNotEmpty && name.toLowerCase() != 'name';
          final hasDescription =
              description.isNotEmpty && !description.startsWith('lorem ipsum');
          final hasAssumptions = assumptions.isNotEmpty;
          final hasText = hasName || hasDescription || hasAssumptions;
          final hasCost = _parseCurrencyInput(row.cost) > 0;
          return hasText || hasCost;
        }),
      );
      final hasProjectBenefits =
          costAnalysisData.solutionProjectBenefits.isNotEmpty ||
              costAnalysisData.projectValueAmount.trim().isNotEmpty ||
              costAnalysisData.benefitLineItems.isNotEmpty;
      final hasCategoryEstimates = costAnalysisData.solutionCategoryCosts.any(
        (solution) => solution.categoryCosts.values
            .any((value) => value.trim().isNotEmpty),
      );
      return hasSolutionRows || hasProjectBenefits || hasCategoryEstimates;
    } catch (e) {
      debugPrint('Error loading existing cost analysis data: $e');
      return false;
    }
  }

  AiSolutionItem? _solutionAt(int index) {
    if (index < 0 || index >= widget.solutions.length) return null;
    return widget.solutions[index];
  }

  String _solutionTitle(int index) {
    final solution = _solutionAt(index);
    final title = solution?.title.trim() ?? '';
    return title.isNotEmpty
        ? solution!.title
        : 'Potential Solution ${index + 1}';
  }

  int _activeSolutionIndex() {
    final count = _rowsPerSolution.isEmpty ? 1 : _rowsPerSolution.length;
    return _boundedIndex(_activeTab, count);
  }

  void _persistProjectValueEditorsForSolution(int index) {
    if (index < 0 || index >= _projectValueAmountBySolution.length) return;
    _projectValueAmountBySolution[index] = _projectValueAmountController.text;
    final values = <String, String>{};
    for (final field in _projectValueFields) {
      final text =
          _projectValueBenefitControllers[field.key]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        values[field.key] = text;
      }
    }
    _projectValueBenefitsBySolution[index] = values;
  }

  void _loadProjectValueEditorsForSolution(int index) {
    if (index < 0 || index >= _projectValueAmountBySolution.length) return;
    _syncingProjectValueEditors = true;
    _projectValueAmountController.text = _projectValueAmountBySolution[index];
    final storedBenefits = _projectValueBenefitsBySolution[index];
    for (final field in _projectValueFields) {
      final controller = _projectValueBenefitControllers[field.key];
      if (controller == null) continue;
      controller.text = storedBenefits[field.key] ?? '';
    }
    _syncingProjectValueEditors = false;
  }

  void _onActiveSolutionChanged(int index) {
    final nextIndex = _boundedIndex(
      index,
      _rowsPerSolution.isEmpty ? 1 : _rowsPerSolution.length,
    );
    final currentIndex = _activeSolutionIndex();
    _persistProjectValueEditorsForSolution(currentIndex);
    if (nextIndex != currentIndex) {
      setState(() {
        _activeTab = nextIndex;
        _savingsError = null;
      });
    }
    _loadProjectValueEditorsForSolution(nextIndex);
    if (mounted) {
      setState(() {});
    }
  }

  double _annualizedProjectValueForSolution(int index) {
    if (index < 0 || index >= _projectValueAmountBySolution.length) return 0;
    final value = _parseCurrencyInput(_projectValueAmountBySolution[index]);
    if (value <= 0) return 0;
    switch ((_basisFrequency ?? '').trim().toLowerCase()) {
      case 'monthly':
        return value * 12;
      case 'quarterly':
        return value * 4;
      default:
        return value;
    }
  }

  double _projectBenefitTotalForSolution(int index) {
    final solutionSpecificValue = _annualizedProjectValueForSolution(index);
    if (solutionSpecificValue > 0) {
      return solutionSpecificValue;
    }
    final benefitTotal = _benefitTotalValueForSolution(index);
    if (benefitTotal > 0) {
      return benefitTotal;
    }
    final hasAnySolutionSpecificValue = _projectValueAmountBySolution.any(
      (value) => _parseCurrencyInput(value) > 0,
    );
    if (hasAnySolutionSpecificValue || _rowsPerSolution.length > 1) {
      return 0;
    }
    return benefitTotal;
  }

  double _initialCostForSolution(int index) {
    final detailedCost = _solutionTotalCost(index);
    if (detailedCost > 0) {
      return detailedCost;
    }
    return _initialCostEstimateTotalFor(index);
  }

  double _currentProjectValueForSolution(int index) {
    // ROI is computed on a single-year basis to avoid inflation.
    // Multi-year horizon is only used for NPV/IRR cashflow calculations.
    return _projectBenefitTotalForSolution(index);
  }

  double _solutionRoiPercent({
    required double currentProjectValue,
    required double initialCost,
  }) {
    if (currentProjectValue <= 0 || initialCost <= 0) {
      return 0;
    }
    // ROI = (annual benefit - initial cost) / initial cost × 100
    // Simple first-year ROI: how much of the initial investment is recovered
    // in the first year of benefits. This avoids the inflation caused by
    // spreading a one-time cost over the horizon while benefits are annualized.
    return ((currentProjectValue - initialCost) / initialCost) * 100;
  }

  double _solutionNpv({
    required double annualProjectValue,
    required double initialCost,
  }) {
    if (annualProjectValue <= 0 || initialCost <= 0 || _npvHorizon <= 0) {
      return 0;
    }
    // Cashflows: Year 0 = -initialCost (one-time outflow),
    // Years 1..horizon = +annualProjectValue (annual benefit, already annualized)
    final cashflows = <double>[-initialCost];
    for (int year = 1; year <= _npvHorizon; year++) {
      cashflows.add(annualProjectValue);
    }
    return Finance.npv(_discountRate, cashflows);
  }

  double _solutionIrrPercent({
    required double currentProjectValue,
    required double initialCost,
  }) {
    if (currentProjectValue <= 0 || initialCost <= 0 || _npvHorizon <= 0) {
      return 0;
    }
    // IRR computed from the same cashflow list as NPV using Newton-Raphson.
    // Year 0 = -initialCost, Years 1..horizon = +currentProjectValue (annual).
    final cashflows = <double>[-initialCost];
    for (int year = 1; year <= _npvHorizon; year++) {
      cashflows.add(currentProjectValue);
    }
    final irr = Finance.irr(cashflows);
    if (irr.isNaN || !irr.isFinite) return 0;
    // Convert to percentage
    return irr * 100;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: isMobile ? _buildMobileDrawer() : null,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              Row(children: [
                DraggableSidebar(
                  openWidth: sidebarWidth,
                  child: const InitiationLikeSidebar(
                      activeItemLabel: 'Initial Cost Estimate'),
                ),
                Expanded(
                    child: Column(children: [
                  BusinessCaseHeader(
                      scaffoldKey: _scaffoldKey,
                      onExportPdf: _exportPdf,
                      onAiAssist: _aiAssist),
                  Expanded(child: _buildMainContent()),
                ])),
              ]),
              MobileSidebarHamburger(
                sidebar: const InitiationLikeSidebar(
                  activeItemLabel: 'Initial Cost Estimate',
                ),
              ),
              const KazAiChatBubble(),
              const AdminEditToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final isMobile = AppBreakpoints.isMobile(context);
    // Match InitiationPhaseScreen header: no logo, centered title, profile at right
    final double headerHeight = isMobile ? 72 : 88;
    return Container(
      height: headerHeight,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      child: Row(
        children: [
          Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                )
              else
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: _handleBackNavigation,
                ),
            ],
          ),
          const Spacer(),
          if (!isMobile)
            const Text(
              'Initiation Phase',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: const Color(0xFFD97706), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                StreamBuilder<bool>(
                  stream: UserService.watchAdminStatus(),
                  builder: (context, snapshot) {
                    final email =
                        FirebaseAuth.instance.currentUser?.email ?? '';
                    final isAdmin =
                        snapshot.data ?? UserService.isAdminEmail(email);
                    final role = isAdmin ? 'Admin' : 'Member';
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FirebaseAuthService.displayNameOrEmail(
                              fallback: 'User'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black),
                        ),
                        Text(role,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  },
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

  Widget _buildSidebar() {
    // Match RiskIdentificationScreen sidebar styling and structure
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
            child: Center(child: AppLogo(height: 64)),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFFFD700), width: 1)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFFFD700),
                  child: Icon(Icons.person_outline, color: Colors.black87),
                ),
                SizedBox(width: 12),
                Column(
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
                        isActive: true),
                    _buildNestedSubMenuItem('Preferred Solution Analysis',
                        onTap: _openPreferredSolutionAnalysis),
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

  Drawer _buildMobileDrawer() {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.88,
      child: const SafeArea(
        child: InitiationLikeSidebar(
          activeItemLabel: 'Initial Cost Estimate',
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title,
      {bool disabled = false, VoidCallback? onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    VoidCallback? handler;
    if (!disabled) {
      handler = onTap ??
          () {
            if (title == 'Home') {
              HomeScreen.open(context);
            } else if (title == 'SSHER') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SsherStackedScreen()));
            } else if (title == 'LogOut') {
              AuthNav.signOutAndExit(context);
            } else if (title == 'Team Management') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TeamManagementScreen()));
            } else if (title == 'Change Management') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const ChangeManagementModuleScreen()));
            } else if (title == 'Lessons Learned') {
              LessonsLearnedScreen.open(context);
            }
          };
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: handler,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
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
            ],
          ),
        ),
      ),
    );
  }

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

  void _openITConsiderations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ITConsiderationsScreen(
          notes: _notesController.text,
          solutions: widget.solutions,
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
          solutions: widget.solutions,
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
    final horizonLabel = '$_npvHorizon-year';
    final horizontalPadding = AppBreakpoints.isDesktop(context)
        ? 24.0
        : AppBreakpoints.pagePadding(context);
    final contentPadding = EdgeInsets.fromLTRB(
        horizontalPadding, 0, horizontalPadding, horizontalPadding);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _mainScrollController,
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding,
                        horizontalPadding, horizontalPadding, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: EditableContentText(
                              contentKey: 'cost_analysis_heading',
                              fallback: _isFullAdminView
                                  ? 'Cost Benefit Analysis'
                                  : 'Initial Cost Estimate',
                              category: 'business_case',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: EditableContentText(
                                contentKey: 'cost_analysis_description',
                                fallback: _isFullAdminView
                                    ? 'Analyze the selected solution\'s investment profile, project value, ROI and NPV in a consolidated workspace.'
                                    : 'Capture itemized cost items for each potential solution to build an AI-assisted initial cost estimate.',
                                category: 'business_case',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                            ),
                            // Page-level Regenerate All button
                            PageRegenerateAllButton(
                              onRegenerateAll: () async {
                                final confirmed =
                                    await showRegenerateAllConfirmation(
                                        context);
                                if (confirmed && mounted) {
                                  await _regenerateAllCostAnalysis();
                                }
                              },
                              isLoading: _isGeneratingValue,
                              tooltip: 'Regenerate all cost analysis content',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_isFullAdminView)
                          Center(child: _buildStepProgressIndicator()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStepPage(
                    index: _currentStepIndex,
                    isMobile: isMobile,
                    horizonLabel: horizonLabel,
                    padding: contentPadding,
                  ),
                  _buildStepNavigationControls(),
                  // Removed duplicate BusinessCaseNavigationButtons - navigation is handled by _buildStepNavigationControls()
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepProgressIndicator() {
    final totalSteps = _stepDefinitions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          if (isWide) {
            return Row(
              children: [
                for (int i = 0; i < totalSteps; i++) ...[
                  Expanded(child: _buildProgressChip(i, expand: true)),
                  if (i != totalSteps - 1) const SizedBox(width: 10),
                ],
              ],
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < totalSteps; i++) _buildProgressChip(i),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressChip(int index, {bool expand = false}) {
    final definition = _stepDefinitions[index];
    final isActive = index == _currentStepIndex;
    final backgroundColor =
        isActive ? const Color(0xFFFFF6CC) : const Color(0xFFFFFFFF);
    final borderColor =
        isActive ? const Color(0xFFFFD700) : const Color(0xFFE2E8F0);
    final textColor = isActive ? Colors.black : const Color(0xFF374151);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _goToStep(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.26),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle, size: 16),
                ),
              Flexible(
                child: Text(
                  definition.shortLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepPage({
    required int index,
    required bool isMobile,
    required String horizonLabel,
    required EdgeInsets padding,
  }) {
    final stepDefinition = _stepDefinitions[index];
    final children = <Widget>[];

    switch (index) {
      case 0:
        if (_projectValueError != null) {
          children.add(_errorBanner(_projectValueError!,
              onRetry: _isGeneratingValue ? null : _generateProjectValue));
        }
        children.add(_stepHeading(
            title: stepDefinition.title, subtitle: stepDefinition.subtitle));
        children.add(_buildProjectValueSection());
        children.add(const SizedBox(height: 24));
        break;
      case 1:
        // Initial Cost Estimate as Step 2
        children.add(_stepHeading(
            title: stepDefinition.title, subtitle: stepDefinition.subtitle));
        if (_error != null) {
          children.add(_errorBanner(_error!,
              onRetry: _isGenerating ? null : _generateCostBreakdown));
        }
        if (_isGenerating) {
          children.add(const LinearProgressIndicator(minHeight: 2));
          children.add(const SizedBox(height: 12));
        }
        children.add(_buildInitialCostEstimateTabs());
        children.add(const SizedBox(height: 24));
        break;
      case 2:
        // Profitability Analysis as Step 3
        children.add(_stepHeading(
            title: stepDefinition.title, subtitle: stepDefinition.subtitle));
        children.add(_buildMetricToolbar(
            isMobile: isMobile, horizonLabel: horizonLabel));
        children.add(const SizedBox(height: 16));
        children.add(_buildProfitabilitySummaryTable());
        children.add(const SizedBox(height: 16));
        // Moved from Step 2: Show solution cost snapshots within Probability Analysis
        children.add(_buildSolutionSummaries(isMobile: isMobile));
        children.add(const SizedBox(height: 16));
        children.add(_buildValuesGainedSummary());
        // Per request: remove all tables below the "Values gained per solution" section.
        children.add(const SizedBox(height: 24));
        break;
      case 3:
        children.add(_stepHeading(
            title: stepDefinition.title, subtitle: stepDefinition.subtitle));
        children.add(_buildNotesSection());
        children.add(const SizedBox(height: 16));
        children.add(_buildNotesCallout());
        children.add(const SizedBox(height: 24));
        break;
      default:
        children.add(_stepHeading(
            title: stepDefinition.title, subtitle: stepDefinition.subtitle));
        break;
    }

    if (children.isNotEmpty) {
      children.insert(0, const SizedBox(height: 12));
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStepNavigationControls() {
    final horizontalPadding = AppBreakpoints.pagePadding(context);
    final isMobile = AppBreakpoints.isMobile(context);
    final effectiveStepCount = _isFullAdminView ? _stepDefinitions.length : 1;
    final isFirst = !_isFullAdminView || _currentStepIndex == 0;
    final isLast =
        !_isFullAdminView || _currentStepIndex == _stepDefinitions.length - 1;
    final stepStatus =
        '${_stepDefinitions[_currentStepIndex].shortLabel} (${_isFullAdminView ? _currentStepIndex + 1 : 1}/$effectiveStepCount)';
    final primaryLabel =
        isLast ? 'Continue to Preferred Solution Analysis' : 'Next Tab';
    final primaryIcon = isLast ? Icons.check : Icons.arrow_forward_ios_rounded;

    final previousButton = TextButton.icon(
      onPressed: isFirst ? null : _handlePreviousStep,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
      label: const Text('Previous'),
    );
    final stepStatusText = Text(
      stepStatus,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
    );
    final saveButton = OutlinedButton.icon(
      onPressed: _handleSave,
      icon: const Icon(Icons.save_outlined, size: 16),
      label: const Text('Save'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey[800],
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final nextButton = ElevatedButton.icon(
      onPressed: () async {
        if (!_reviewConfirmed) {
          final continueAnyway = await showProceedWithoutReviewDialog(
            context,
            title: 'Please confirm before continuing',
            message:
                'You have not confirmed this tab yet. You can continue now and come back to complete it, or stay and update it now.',
          );
          if (!continueAnyway || !mounted) return;
        }

        if (isLast) {
          await _openPreferredSolution();
        } else {
          await _handleNextStep();
        }
      },
      icon: Icon(primaryIcon, size: 16),
      label: Text(primaryLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, 12, horizontalPadding, horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProceedConfirmationGate(
            value: _reviewConfirmed,
            onChanged: (value) {
              setState(() => _reviewConfirmed = value);
            },
            scrollController: _mainScrollController,
            padding: const EdgeInsets.only(bottom: 16),
          ),
          if (isMobile) ...[
            // Mobile: stack vertically to avoid overflow
            Row(
              children: [
                previousButton,
                const Spacer(),
                stepStatusText,
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: saveButton,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: nextButton,
            ),
          ] else ...[
            // Desktop: original horizontal Row layout
            Row(
              children: [
                previousButton,
                const SizedBox(width: 16),
                stepStatusText,
                const Spacer(),
                saveButton,
                const SizedBox(width: 12),
                nextButton,
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCallout() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFF87CEEB), shape: BoxShape.circle),
            child:
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Switch tabs as needed',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToStep(int index) async {
    if (!mounted || index == _currentStepIndex) return;
    if (index < 0 || index >= _stepDefinitions.length) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _currentStepIndex = index;
      _reviewConfirmed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mainScrollController.hasClients) {
        _mainScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handlePreviousStep() {
    final previous = _currentStepIndex - 1;
    if (previous >= 0) {
      _goToStep(previous);
    }
  }

  Future<void> _handleNextStep() async {
    // Save cost analysis data before navigating to next step
    await _saveCostAnalysisData();

    // Show 3-second loading dialog
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
                Text('Saving your progress...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    final next = _currentStepIndex + 1;
    if (next < _stepDefinitions.length) {
      _goToStep(next);
    }
  }

  Future<void> _openPreferredSolution() async {
    FocusScope.of(context).unfocus();

    // 1. Save data FIRST before validation
    await _saveCostAnalysisData();
    if (!mounted) return;

    // 2. Validate data completeness
    final provider = ProjectDataInherited.of(context);
    final projectData = provider.projectData;

    if (projectData.costAnalysisData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Continuing without completed cost analysis. You can complete it later or use AI to fill it in.',
            ),
          ),
        );
      }
    }

    // 3. Smart checkpoint check
    final nextCheckpoint =
        SidebarNavigationService.instance.getNextItem('cost_analysis');
    if (nextCheckpoint?.checkpoint != 'preferred_solution_analysis') {
      // Use standard lock check for non-sequential navigation
      final isLocked = ProjectDataHelper.isDestinationLocked(
          context, 'preferred_solution_analysis');
      if (isLocked) {
        ProjectDataHelper.showLockedDestinationMessage(
            context, 'Preferred Solution Analysis');
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
                Text('Processing cost analysis data...'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1)); // Reduced delay

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    // Navigate to Preferred Solution Analysis
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferredSolutionAnalysisScreen(
          notes: widget.notes,
          solutions: widget.solutions,
          businessCase: projectData.businessCase,
        ),
      ),
    );
  }

  Future<void> _saveCostAnalysisData() async {
    try {
      final provider = ProjectDataInherited.of(context);
      final activeSolutionIndex = _activeSolutionIndex();
      _persistProjectValueEditorsForSolution(activeSolutionIndex);

      // Collect Step 2 detailed cost rows for each solution.
      final solutionCosts = <SolutionCostData>[];
      for (int i = 0; i < _rowsPerSolution.length; i++) {
        final solutionTitle = _solutionTitle(i);
        final costRows = _rowsPerSolution[i].map((row) {
          return CostRowData(
            itemName: row.itemController.text,
            description: row.descriptionController.text,
            cost: row.costController.text,
            assumptions: row.assumptionsController.text,
          );
        }).toList();

        solutionCosts.add(SolutionCostData(
          solutionTitle: solutionTitle,
          costRows: costRows,
          contextHash: _costBreakdownContextHashesBySolution[i],
        ));
      }

      // Collect global project benefits entries (legacy + display layer).
      final benefitLineItems = _allBenefitLineItems.map((entry) {
        return BenefitLineItem(
          id: entry.id,
          categoryKey: entry.categoryKey,
          title: entry.titleController.text,
          unitValue: entry.unitValueController.text,
          units: entry.unitsController.text,
          notes: entry.notesController.text,
        );
      }).toList();

      // Persist Step 1 project value inputs per solution.
      final solutionProjectBenefits = <SolutionProjectBenefitData>[];
      for (int i = 0; i < _rowsPerSolution.length; i++) {
        final solutionBenefits = _benefitItemsForSolution(i)
            .map(
              (entry) => BenefitLineItem(
                id: entry.id,
                categoryKey: entry.categoryKey,
                title: entry.title,
                unitValue: entry.unitValueController.text,
                units: entry.unitsController.text,
                notes: entry.notes,
              ),
            )
            .toList(growable: false);
        solutionProjectBenefits.add(
          SolutionProjectBenefitData(
            solutionTitle: _solutionTitle(i),
            projectValueAmount: _projectValueAmountBySolution[i],
            projectValueBenefits:
                Map<String, String>.from(_projectValueBenefitsBySolution[i]),
            projectBenefits: solutionBenefits,
            contextHash: _projectValueContextHashesBySolution[i],
          ),
        );
      }

      // Persist Initial Cost Estimate category totals/notes for each solution.
      final solutionCategoryCosts = <SolutionCategoryCostData>[];
      for (int i = 0; i < _categoryCostsPerSolution.length; i++) {
        final costEntries = <String, String>{};
        final noteEntries = <String, String>{};
        final map = _categoryCostsPerSolution[i];
        for (final field in _projectValueFields) {
          final entry = map[field.key];
          if (entry == null) continue;
          final costText = entry.costController.text.trim();
          final noteText = entry.notesController.text.trim();
          if (costText.isNotEmpty) {
            costEntries[field.key] = costText;
          }
          if (noteText.isNotEmpty) {
            noteEntries[field.key] = noteText;
          }
        }
        solutionCategoryCosts.add(
          SolutionCategoryCostData(
            solutionTitle: _solutionTitle(i),
            categoryCosts: costEntries,
            categoryNotes: noteEntries,
          ),
        );
      }

      // Persist qualitative assumptions and narrative by solution.
      final solutionCostAssumptions = <SolutionCostAssumptionData>[];
      for (int i = 0; i < _solutionContexts.length; i++) {
        final contextData = _solutionContexts[i];
        solutionCostAssumptions.add(
          SolutionCostAssumptionData(
            solutionTitle: _solutionTitle(i),
            resourceIndex: contextData.resourceIndex,
            timelineIndex: contextData.timelineIndex,
            complexityIndex: contextData.complexityIndex,
            justification: contextData.justificationController.text,
          ),
        );
      }

      final solutionSavingsSuggestions = <SolutionSavingsData>[];
      for (int i = 0; i < _rowsPerSolution.length; i++) {
        solutionSavingsSuggestions.add(
          SolutionSavingsData(
            solutionTitle: _solutionTitle(i),
            contextHash: _savingsContextHashesBySolution[i],
            suggestions: _savingsSuggestionsForSolution(i)
                .map(
                  (suggestion) => SavingsSuggestionData(
                    lever: suggestion.lever,
                    recommendation: suggestion.recommendation,
                    projectedSavings: suggestion.projectedSavings,
                    timeframe: suggestion.timeframe,
                    confidence: suggestion.confidence,
                    rationale: suggestion.rationale,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }

      final legacyIndex =
          _projectValueAmountBySolution.isNotEmpty ? 0 : activeSolutionIndex;
      final legacyProjectValueAmount =
          _projectValueAmountBySolution[legacyIndex];
      final legacyProjectValueBenefits = Map<String, String>.from(
          _projectValueBenefitsBySolution[legacyIndex]);

      final costAnalysisData = CostAnalysisData(
        notes: _notesController.text,
        solutionCosts: solutionCosts,
        projectValueAmount: legacyProjectValueAmount,
        projectValueBenefits: legacyProjectValueBenefits,
        benefitLineItems: benefitLineItems,
        solutionProjectBenefits: solutionProjectBenefits,
        solutionCategoryCosts: solutionCategoryCosts,
        solutionCostAssumptions: solutionCostAssumptions,
        savingsNotes: _savingsNotesController.text,
        savingsTarget: _savingsTargetController.text,
        basisFrequency: _basisFrequency,
        trackerBasisFrequency: _trackerBasisFrequency,
        npvDiscountRate: _discountRate,
        solutionSavingsSuggestions: solutionSavingsSuggestions,
      );

      provider.updateProjectData(
        provider.projectData.copyWith(costAnalysisData: costAnalysisData),
      );

      // Save to Firebase with checkpoint
      await provider.saveToFirebase(checkpoint: 'cost_analysis');
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      } else {
        _hasUnsavedChanges = false;
      }
    } catch (e) {
      debugPrint('Error saving cost analysis data: $e');
    }
  }

  Future<void> _handleSave() async {
    // Show saving indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Saving...'),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF424242),
      ),
    );

    await _saveCostAnalysisData();

    if (!mounted) return;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 12),
            Text('Changes saved successfully'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _scheduleAutosave() {
    if (_suppressDirtyTracking || !mounted) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted || _suppressDirtyTracking) return;
      if (_autosaveInFlight) {
        _scheduleAutosave();
        return;
      }
      _autosaveInFlight = true;
      try {
        await _saveCostAnalysisData();
      } finally {
        _autosaveInFlight = false;
      }
    });
  }

  void _markDirty() {
    if (_suppressDirtyTracking || !mounted) {
      return;
    }
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    _scheduleAutosave();
  }

  void _markDirtyAndRecalc() {
    if (_suppressDirtyTracking || !mounted) {
      return;
    }
    _markDirty();
    if (mounted) {
      setState(() {});
    }
  }

  void _attachRowDirtyListeners(_CostRow row) {
    void handleChange() => _markDirtyAndRecalc();
    row.itemController.addListener(handleChange);
    row.descriptionController.addListener(handleChange);
    row.costController.addListener(handleChange);
    row.assumptionsController.addListener(handleChange);
  }

  Future<bool> _confirmExit() async {
    if (!mounted) return true;
    if (!_hasUnsavedChanges) return true;
    _autosaveTimer?.cancel();
    await _saveCostAnalysisData();
    return true;
  }

  Future<void> _handleBackNavigation() async {
    final shouldLeave = await _confirmExit();
    if (!shouldLeave) return;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    HomeScreen.open(context);
  }

  void _onProjectValueFieldChanged() {
    if (_syncingProjectValueEditors) {
      return;
    }
    _persistProjectValueEditorsForSolution(_activeSolutionIndex());
    _markDirty();
    if (mounted) setState(() {});
  }

  void _onSavingsContextChanged() {
    final solutionIndex = _activeSolutionIndex();
    if (!_isSavingsGenerating && _savingsSuggestions.isNotEmpty) {
      setState(() {
        _clearSavingsSuggestionsForSolution(solutionIndex);
        _savingsError = null;
      });
    }
    _markDirty();
  }

  double _parseCurrencyInput(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(sanitized) ?? 0;
  }

  _ValueSetupInvestmentSnapshot? _valueSetupInvestmentSnapshot(
      {int? solutionIndex}) {
    final index = solutionIndex ?? _activeSolutionIndex();
    final annualProjectValue = _projectBenefitTotalForSolution(index);
    if (annualProjectValue <= 0) {
      return null;
    }
    final currentProjectValue = _currentProjectValueForSolution(index);
    final estimatedCost = _initialCostForSolution(index);
    final activeBenefitCount = _benefitItemsForSolution(index)
        .where((entry) => entry.totalValue > 0 || entry.title.isNotEmpty)
        .length;
    final averageRoi = _solutionRoiPercent(
      currentProjectValue: currentProjectValue,
      initialCost: estimatedCost,
    );
    final npv = _solutionNpv(
      annualProjectValue: annualProjectValue,
      initialCost: estimatedCost,
    );
    return _ValueSetupInvestmentSnapshot(
      estimatedCost: estimatedCost,
      averageRoi: averageRoi,
      npv: npv,
      costRange:
          _CostRange(lower: estimatedCost * 0.85, upper: estimatedCost * 1.15),
      benefitLineItemCount: activeBenefitCount,
      totalBenefits: annualProjectValue,
    );
  }

  Widget _stepHeading({String? step, required String title, String? subtitle}) {
    final hasStepLabel = step != null && step.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (hasStepLabel) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFD700)),
            ),
            child: Text(step,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700))),
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildCurrencySelector() {
    final availableCurrencies = _currencyRates.keys.toSet();
    final selectedCurrency =
        availableCurrencies.contains(_currency) ? _currency : 'USD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Text(
            'Select Currency:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: selectedCurrency,
            items: _currencyRates.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                final factor = _currencyFactor(_lastCurrency, value);
                setState(() {
                  _currency = value;
                  _applyCurrencyConversion(factor);
                  _lastCurrency = value;
                });
                _markDirty();
                // Update provider
                final provider = ProjectDataHelper.getProvider(context);
                provider.updateCostBenefitCurrency(value);
              }
            },
            style: const TextStyle(fontSize: 14),
            underline: Container(height: 2, color: const Color(0xFFFFD700)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectValueSection() {
    const basisHelperText =
        'Enter the estimated project benefit value to calculate ROI, NPV, and IRR for 1, 3, 5, and 10 years.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final titleColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Project Benefit Calculation',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const _AiTag(),
                ]),
                const SizedBox(height: 4),
                Text(
                  'AI-assisted estimation to showcase project benefits',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
            final aiButton = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGeneratingValue)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2)),
                if (_isGeneratingValue) const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isGeneratingValue ? null : _generateProjectValue,
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('Populate with AI'),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleColumn,
                  const SizedBox(height: 10),
                  aiButton,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleColumn),
                const SizedBox(width: 12),
                aiButton,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (_rowsPerSolution.length > 1) ...[
          const Text(
            'Editing project benefits for',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _rowsPerSolution.length; i++)
                ChoiceChip(
                  label: Text(
                    _solutionTitle(i),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  selected: _activeSolutionIndex() == i,
                  onSelected: (_) => _onActiveSolutionChanged(i),
                  selectedColor: const Color(0xFFFFD700),
                  backgroundColor: Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('Estimated Project Benefit Value ($_currency)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        VoiceTextField(
          controller: _projectValueAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 250000',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFFD700))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 400;
            final basisWidth = constraints.maxWidth >= 980
                ? 220.0
                : math.max(150.0, constraints.maxWidth * 0.32);
            final basisControl = SizedBox(
              width: isVeryNarrow ? constraints.maxWidth : basisWidth,
              child: DropdownButtonFormField<String>(
                value: _basisFrequency,
                items: _frequencyOptions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _basisFrequency = value);
                  _markDirty();
                },
                decoration: InputDecoration(
                  labelText: 'Basis Frequency',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFFD700))),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                hint: const Text('Select'),
              ),
            );
            final currencyControl = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Currency:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _currencyDropdown(),
              ],
            );
            final helperText = Text(
              basisHelperText,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            );

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
              ),
              child: isVeryNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        currencyControl,
                        const SizedBox(height: 10),
                        helperText,
                      ],
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          currencyControl,
                          const SizedBox(width: 14),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth:
                                  math.max(240, constraints.maxWidth * 0.42),
                              maxWidth:
                                  math.max(260, constraints.maxWidth * 0.55),
                            ),
                            child: helperText,
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildFinancialBenefitsTrackerSection(),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildBenefitCategoryChip({
    required MapEntry<String, String> field,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final compactLabels = _useCompactCategoryLabels(context);
    final displayLabel =
        _benefitCategoryLabel(field.key, compact: compactLabels);
    final IconData icon;
    const Color accentColor = Color(0xFFFFC812);

    // Assign icons based on category
    switch (field.key) {
      case 'revenue':
        icon = Icons.trending_up;
        break;
      case 'cost_saving':
        icon = Icons.savings;
        break;
      case 'ops_efficiency':
        icon = Icons.speed;
        break;
      case 'productivity':
        icon = Icons.access_time;
        break;
      case 'regulatory_compliance':
        icon = Icons.verified_user;
        break;
      case 'process_improvement':
        icon = Icons.auto_awesome;
        break;
      case 'brand_image':
        icon = Icons.star;
        break;
      case 'stakeholder_commitment':
        icon = Icons.handshake;
        break;
      case 'other':
      default:
        icon = Icons.more_horiz;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDetailsTab() {
    final selectedField = _projectValueFields[_activeBenefitCategoryIndex];
    final categoryDescriptor = _benefitMetrics[selectedField.key] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InnerPageNavigationHint(
          pageId: 'cost_analysis',
          pageTitle: 'Benefit Categories',
          description: 'Navigate between benefit categories',
          currentSectionId:
              _projectValueFields[_activeBenefitCategoryIndex].key,
          compact: true,
          sections: [
            for (int i = 0; i < _projectValueFields.length; i++)
              InnerPageSection(
                id: _projectValueFields[i].key,
                label: _projectValueFields[i].value,
                status: _activeBenefitCategoryIndex == i
                    ? InnerPageSectionStatus.current
                    : InnerPageSectionStatus.available,
                stepNumber: i + 1,
              ),
          ],
          onSectionTap: (sectionId) {
            final index =
                _projectValueFields.indexWhere((f) => f.key == sectionId);
            if (index >= 0) {
              setState(() => _activeBenefitCategoryIndex = index);
              _benefitCategoryTabController.animateTo(index);
            }
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Estimated Benefits',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < _projectValueFields.length; i++)
              _buildBenefitCategoryChip(
                field: _projectValueFields[i],
                isSelected: _activeBenefitCategoryIndex == i,
                onTap: () {
                  setState(() {
                    _activeBenefitCategoryIndex = i;
                    _benefitCategoryTabController.animateTo(i);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildBenefitCategoryTabContent(
            field: selectedField,
            descriptor: categoryDescriptor,
          ),
        ),
        const SizedBox(height: 12),
        _buildMultiYearBenefitTable(),
      ],
    );
  }

  Widget _buildBenefitCategoryTabContent(
      {required MapEntry<String, String> field, required String descriptor}) {
    final controller = _projectValueBenefitControllers[field.key]!;
    final metricTags = _metricTagsFor(field.key);
    final displayLabel = _benefitCategoryLabel(field.key,
        compact: _useCompactCategoryLabels(context));

    return KeyedSubtree(
      key: ValueKey(field.key),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(displayLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        if (descriptor.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(descriptor,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
        const SizedBox(height: 12),
        const Text('Project Benefit Details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ExpandingTextField(
            key: ValueKey('${field.key}-input'),
            controller: controller,
            minLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Highlight primary project benefits, drivers, and realization strategy',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        if (metricTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Project Benefits Highlights',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in metricTags)
                Chip(
                  avatar: const Icon(Icons.insights_outlined, size: 16),
                  label: Text(tag,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _buildInlineYearBoxes() {
    return const SizedBox.shrink();
  }

  Widget _buildYearBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatCurrencyValue(value),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiYearBenefitTable() {
    final amountText = _projectValueAmountController.text.trim();
    final explicitValue = _parseCurrencyInput(amountText);

    if (_basisFrequency == null) {
      return const SizedBox.shrink();
    }

    // Calculate multiplier based on frequency
    int frequencyMultiplier;
    switch (_basisFrequency) {
      case 'Monthly':
        frequencyMultiplier = 12;
        break;
      case 'Quarterly':
        frequencyMultiplier = 4;
        break;
      case 'Yearly':
      default:
        frequencyMultiplier = 1;
    }

    final bool usingLineItems = explicitValue <= 0;
    final trackerDescriptor = _trackerBasisFrequency == 'Monthly' ||
            _trackerBasisFrequency == 'Quarterly'
        ? 'annualized'
        : 'annual';
    final double annualValue = usingLineItems
        ? _benefitTotalValueForSolution(_activeSolutionIndex())
        : explicitValue * frequencyMultiplier;

    // Multi-year calculations
    final year1 = annualValue;
    final year3 = annualValue * 3;
    final year5 = annualValue * 5;
    final year10 = annualValue * 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calculate_outlined,
              size: 20, color: Color(0xFFFF8F00)),
          const SizedBox(width: 8),
          const Text('Projected Benefit Horizons',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(
          usingLineItems
              ? 'Derived from line item totals ($trackerDescriptor basis).'
              : 'Based on $_basisFrequency basis${frequencyMultiplier > 1 ? " (x$frequencyMultiplier to annualize first)" : ""}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: Row(children: [
            Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.center,
                  child: Text('Time Horizon',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                )),
            Expanded(
                flex: 3,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('Projected Benefit ($_currency)',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
          ]),
        ),
        // Table rows
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
            border: Border.all(color: Colors.grey.withOpacity(0.25)),
          ),
          child: Column(children: [
            _multiYearRow('1 Year', year1, isFirst: true),
            _multiYearRow('3 Years', year3),
            _multiYearRow('5 Years', year5),
            _multiYearRow('10 Years', year10, isLast: true),
          ]),
        ),
      ]),
    );
  }

  Widget _multiYearRow(String label, double value,
      {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(children: [
        Expanded(
            flex: 2, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrencyValue(value),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                  color: isLast ? const Color(0xFF1B5E20) : null),
            ),
          ),
        ),
      ]),
    );
  }

  List<String> _metricTagsFor(String categoryKey) {
    final raw = _benefitMetrics[categoryKey];
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  bool _useCompactCategoryLabels(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 1024;
  }

  String _benefitCategoryLabel(String key, {bool compact = false}) {
    if (compact) {
      final compactLabel = _projectValueCompactLabels[key];
      if (compactLabel != null) return compactLabel;
    }
    final match = _projectValueFields.firstWhere(
      (entry) => entry.key == key,
      orElse: () => const MapEntry('other', 'Other'),
    );
    return match.value;
  }

  void _clearSavingsSuggestionsForSolution(int index) {
    if (index < 0 || index >= _savingsSuggestionsBySolution.length) {
      return;
    }
    _savingsSuggestionsBySolution[index] = <AiBenefitSavingsSuggestion>[];
    _savingsContextHashesBySolution[index] = '';
  }

  _BenefitLineItemEntry _createBenefitEntry({
    String? categoryKey,
    String? title,
    String? unitValue,
    String? units,
    String? notes,
  }) {
    final entry = _BenefitLineItemEntry(
      id: 'benefit-${DateTime.now().microsecondsSinceEpoch}',
      categoryKey: _normalizeBenefitCategoryKey(
          categoryKey ?? _projectValueFields.first.key),
      title: title ?? '',
      unitValue: double.tryParse(unitValue ?? '') ?? 0,
      units: double.tryParse(units ?? '') ?? 0,
      notes: notes ?? '',
    );
    entry.bind(_onBenefitEntryEdited);
    return entry;
  }

  Future<void> _addBenefitLineItem({String? categoryKey}) async {
    final draft = await _showBenefitLineItemDialog(
      mode: _EditorDialogMode.create,
      categoryKey: categoryKey,
    );
    if (draft == null) return;
    final solutionIndex = _activeSolutionIndex();
    final entry = _createBenefitEntry(
      categoryKey: draft.categoryKey,
      title: draft.title,
      unitValue: draft.unitValue,
      units: draft.units,
      notes: draft.notes,
    );
    setState(() {
      _benefitItemsForSolution(solutionIndex).add(entry);
      _clearSavingsSuggestionsForSolution(solutionIndex);
      _savingsError = null;
    });
    _markDirty();
  }

  Future<void> _editBenefitLineItem(_BenefitLineItemEntry entry) async {
    final draft = await _showBenefitLineItemDialog(
      mode: _EditorDialogMode.edit,
      entry: entry,
    );
    if (draft == null) return;
    final solutionIndex = _activeSolutionIndex();
    setState(() {
      entry.categoryKey = draft.categoryKey;
      entry.titleController.text = draft.title;
      entry.unitValueController.text = draft.unitValue;
      entry.unitsController.text = draft.units;
      entry.notesController.text = draft.notes;
      _clearSavingsSuggestionsForSolution(solutionIndex);
      _savingsError = null;
    });
    _markDirty();
  }

  Future<void> _viewBenefitLineItem(_BenefitLineItemEntry entry) async {
    await _showBenefitLineItemDialog(
      mode: _EditorDialogMode.view,
      entry: entry,
    );
  }

  Future<void> _removeBenefitLineItem(_BenefitLineItemEntry entry) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete benefit item',
      itemLabel: entry.title,
      message: 'Delete this benefit item? This action cannot be undone.',
    );

    if (!confirmed) return;

    final solutionIndex = _activeSolutionIndex();
    setState(() {
      _benefitItemsForSolution(solutionIndex).remove(entry);
      _clearSavingsSuggestionsForSolution(solutionIndex);
      _savingsError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
    _markDirty();
  }

  void _onBenefitEntryEdited() {
    if (!mounted) return;
    final solutionIndex = _activeSolutionIndex();
    setState(() {
      _savingsError = null;
      if (!_isSavingsGenerating && _savingsSuggestions.isNotEmpty) {
        _clearSavingsSuggestionsForSolution(solutionIndex);
      }
    });
    _markDirty();
  }

  Future<_BenefitLineItemDraft?> _showBenefitLineItemDialog({
    required _EditorDialogMode mode,
    _BenefitLineItemEntry? entry,
    String? categoryKey,
  }) async {
    final titleController =
        TextEditingController(text: entry?.titleController.text ?? '');
    final unitValueController =
        TextEditingController(text: entry?.unitValueController.text ?? '');
    final unitsController =
        TextEditingController(text: entry?.unitsController.text ?? '');
    final notesController =
        TextEditingController(text: entry?.notesController.text ?? '');
    String selectedCategory = _normalizeBenefitCategoryKey(
      entry?.categoryKey ?? categoryKey ?? _projectValueFields.first.key,
    );
    bool isSuggesting = false;
    final readOnly = mode == _EditorDialogMode.view;
    final result = await showDialog<_BenefitLineItemDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final title = switch (mode) {
            _EditorDialogMode.create => 'Add benefit item',
            _EditorDialogMode.edit => 'Edit benefit item',
            _EditorDialogMode.view => 'View benefit item',
          };
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: _projectValueFields
                          .map(
                            (field) => DropdownMenuItem<String>(
                              value: field.key,
                              child: Text(_benefitCategoryLabel(field.key)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: readOnly
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedCategory = value;
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: titleController,
                      readOnly: readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Benefit title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextField(
                            controller: unitValueController,
                            readOnly: readOnly,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Unit value ($_currency)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: VoiceTextField(
                            controller: unitsController,
                            readOnly: readOnly,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Units',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!readOnly) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: isSuggesting
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isSuggesting = true;
                                  });
                                  final suggestedValue =
                                      await _estimateBenefitUnitValue(
                                    title: titleController.text.trim(),
                                    categoryKey: selectedCategory,
                                    notes: notesController.text.trim(),
                                    unitsText: unitsController.text.trim(),
                                    baselineValue: _projectValueAmountController
                                        .text
                                        .trim(),
                                    solutionIndex: _activeSolutionIndex(),
                                    excludeEntryId: entry?.id,
                                  );
                                  if (!mounted || !dialogContext.mounted) {
                                    return;
                                  }
                                  if (suggestedValue != null &&
                                      suggestedValue > 0) {
                                    unitValueController.text =
                                        suggestedValue.toStringAsFixed(2);
                                  }
                                  setDialogState(() {
                                    isSuggesting = false;
                                  });
                                },
                          icon: isSuggesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_fix_high_outlined,
                                  size: 18,
                                ),
                          label: const Text('Suggest unit value with AI'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: notesController,
                      readOnly: readOnly,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Basis and notes',
                        hintText: 'Capture assumptions, timing, and basis.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(readOnly ? 'Close' : 'Cancel'),
              ),
              if (!readOnly)
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _BenefitLineItemDraft(
                        categoryKey: selectedCategory,
                        title: titleController.text.trim(),
                        unitValue: unitValueController.text.trim(),
                        units: unitsController.text.trim(),
                        notes: notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
            ],
          );
        },
      ),
    );
    titleController.dispose();
    unitValueController.dispose();
    unitsController.dispose();
    notesController.dispose();
    return result;
  }

  Map<String, _BenefitCategorySummary> _benefitSummaries() {
    final map = <String, _BenefitCategorySummary>{};
    for (final entry in _benefitLineItems) {
      final summary =
          map.putIfAbsent(entry.categoryKey, () => _BenefitCategorySummary());
      summary.add(entry, valueOverride: _effectiveBenefitValue(entry));
    }
    return map;
  }

  double _effectiveBenefitValue(_BenefitLineItemEntry entry) {
    if (_trackerBasisFrequency == 'Monthly') {
      return entry.totalValue * 12;
    }
    if (_trackerBasisFrequency == 'Quarterly') {
      return entry.totalValue * 4;
    }
    return entry.totalValue;
  }

  double _benefitTotalValueForSolution(int index) {
    return _benefitItemsForSolution(index).fold<double>(
      0,
      (sum, entry) => sum + _effectiveBenefitValue(entry),
    );
  }

  double _benefitTotalValue() {
    return _benefitTotalValueForSolution(_activeSolutionIndex());
  }

  double _benefitTotalUnitsForSolution(int index) {
    return _benefitItemsForSolution(index)
        .fold<double>(0, (sum, entry) => sum + entry.units);
  }

  double _benefitTotalUnits() {
    return _benefitTotalUnitsForSolution(_activeSolutionIndex());
  }

  double _calculateTotalBenefitsWithFrequency() {
    return _benefitTotalValue();
  }

  Widget _buildFinancialBenefitsTrackerSection() {
    final tabs = const [
      'Line Items',
      'Estimated Benefits',
      'Project Benefits Review'
    ];
    final activeTabIndex = math.min(_benefitTabIndex, tabs.length - 1);
    final summaries = _benefitSummaries();
    final totalValue = _benefitTotalValue();
    final totalUnits = _benefitTotalUnits();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 980;
            final helperText = Text(
              'Assign an estimated financial value to identified project benefits',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            );
            final isVeryNarrow = constraints.maxWidth < 500;
            final basisControls = isVeryNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Basis Frequency:',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      _BasisFrequencyToggle(
                        value: _trackerBasisFrequency,
                        onChanged: (value) {
                          final solutionIndex = _activeSolutionIndex();
                          setState(() {
                            _trackerBasisFrequency = value;
                            _clearSavingsSuggestionsForSolution(solutionIndex);
                          });
                          _markDirty();
                        },
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Select Basis Frequency:',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      _BasisFrequencyToggle(
                        value: _trackerBasisFrequency,
                        onChanged: (value) {
                          final solutionIndex = _activeSolutionIndex();
                          setState(() {
                            _trackerBasisFrequency = value;
                            _clearSavingsSuggestionsForSolution(solutionIndex);
                          });
                          _markDirty();
                        },
                      ),
                    ],
                  );
            final itemsChip = Chip(
              label: Text('${_benefitLineItems.length} items'),
              avatar: const Icon(Icons.table_chart_outlined, size: 16),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('Project Value Estimation',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      _AiTag(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  helperText,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [basisControls, itemsChip],
                  ),
                ],
              );
            }

            return Row(children: [
              const Text('Project Value Estimation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const _AiTag(),
              const SizedBox(width: 8),
              Expanded(child: helperText),
              const SizedBox(width: 12),
              basisControls,
              const SizedBox(width: 12),
              itemsChip,
            ]);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < tabs.length; i++)
              ChoiceChip(
                label: Text(tabs[i],
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                selected: activeTabIndex == i,
                onSelected: (selected) {
                  if (!selected) return;
                  if (activeTabIndex != i) {
                    setState(() {
                      _benefitTabIndex = i;
                    });
                  }
                },
                selectedColor: const Color(0xFFFFD700),
                backgroundColor: Colors.grey.shade200,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(activeTabIndex),
            child: _buildBenefitTrackerTabContent(
              activeTabIndex: activeTabIndex,
              summaries: summaries,
              totalValue: totalValue,
              totalUnits: totalUnits,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBenefitTrackerTabContent({
    required int activeTabIndex,
    required Map<String, _BenefitCategorySummary> summaries,
    required double totalValue,
    required double totalUnits,
  }) {
    switch (activeTabIndex) {
      case 0:
        return _buildBenefitLineItemsTab();
      case 1:
        return _buildCategoryDetailsTab();
      case 2:
      default:
        return _buildProjectBenefitsReviewTab(
          summaries: summaries,
          totalValue: totalValue,
          totalUnits: totalUnits,
        );
    }
  }

  Widget _buildBenefitLineItemsTab() {
    final hasItems = _benefitLineItems.isNotEmpty;
    final activeSolutionLabel = _solutionTitle(_activeSolutionIndex());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_rowsPerSolution.length > 1) ...[
        Text(
          'Showing benefit analysis for $activeSolutionLabel',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 10),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;
          final addButton = OutlinedButton.icon(
            onPressed: () => _addBenefitLineItem(),
            icon: const Icon(Icons.add),
            label: const Text('Add benefit item'),
          );
          final metadata = [
            Chip(
              avatar: Icon(Icons.attach_money,
                  size: 16, color: const Color(0xFF92400E)),
              label: Text('Currency: $_currency'),
            ),
            Chip(
              avatar: Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.orange.shade700),
              label: Text('Basis: $_trackerBasisFrequency'),
            ),
          ];

          if (isNarrow) {
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...metadata,
                addButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: metadata,
                ),
              ),
              const SizedBox(width: 12),
              addButton,
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth =
              math.max(constraints.maxWidth, _benefitLineItemsTableWidth());
          return Scrollbar(
            controller: _benefitTableHorizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            notificationPredicate: (notification) => notification.depth == 0,
            child: SingleChildScrollView(
              controller: _benefitTableHorizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(children: [
                          _benefitHeaderCell('#',
                              width: _benefitIndexColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Category',
                              width: _benefitCategoryColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Benefit Title',
                              width: _benefitTitleColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Unit Value',
                              width: _benefitUnitValueColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Units',
                              width: _benefitTotalUnitsColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Total Value',
                              width: _benefitTotalValueColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Basis',
                              width: _benefitNotesColumnWidth,
                              alignment: Alignment.center),
                          const SizedBox(width: _benefitColumnGap),
                          _benefitHeaderCell('Actions',
                              width: _benefitActionsColumnWidth,
                              alignment: Alignment.center),
                        ]),
                      ),
                      if (hasItems)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: Scrollbar(
                            controller: _benefitTableRowsVerticalController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            notificationPredicate: (notification) =>
                                notification.depth == 0,
                            child: SingleChildScrollView(
                              controller: _benefitTableRowsVerticalController,
                              child: Column(
                                children: [
                                  for (int i = 0;
                                      i < _benefitLineItems.length;
                                      i++)
                                    _benefitLineItemRow(
                                        i, _benefitLineItems[i]),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 500;
                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No project benefits yet. Add at least one item to unlock summaries, review highlights, and profitability rollups.',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () => _addBenefitLineItem(),
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                      label: const Text('Add first item'),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'No project benefits yet. Add at least one item to unlock summaries, review highlights, and profitability rollups.',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () => _addBenefitLineItem(),
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Add first item'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          border: Border(
                            top: BorderSide(
                                color:
                                    const Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: _benefitIndexColumnWidth,
                            child: const Text('',
                                textAlign: TextAlign.left,
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(
                            width: _benefitCategoryColumnWidth,
                            child: const Text(
                              'TOTAL benefits',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B5E20)),
                            ),
                          ),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(width: _benefitTitleColumnWidth),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(width: _benefitUnitValueColumnWidth),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(
                            width: _benefitTotalUnitsColumnWidth,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                '${_benefitLineItems.length} items',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(
                            width: _benefitTotalValueColumnWidth,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                _formatCurrencyValue(
                                    _calculateTotalBenefitsWithFrequency()),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B5E20)),
                              ),
                            ),
                          ),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(width: _benefitNotesColumnWidth),
                          const SizedBox(width: _benefitColumnGap),
                          SizedBox(width: _benefitActionsColumnWidth),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.swap_horiz, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            'Scroll horizontally to view all columns.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            '${_benefitLineItems.length} rows',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
          'Basis: $_trackerBasisFrequency${_trackerBasisFrequency == 'Monthly' ? ' (x12 annualized for roll-up)' : _trackerBasisFrequency == 'Quarterly' ? ' (x4 annualized for roll-up)' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }

  double _benefitLineItemsTableWidth() {
    return (_benefitIndexColumnWidth +
        _benefitCategoryColumnWidth +
        _benefitTitleColumnWidth +
        _benefitUnitValueColumnWidth +
        _benefitTotalUnitsColumnWidth +
        _benefitTotalValueColumnWidth +
        _benefitNotesColumnWidth +
        _benefitActionsColumnWidth +
        (_benefitColumnGap * 7) +
        32);
  }

  Widget _benefitHeaderCell(String label,
      {required double width, Alignment alignment = Alignment.center}) {
    return SizedBox(
      width: width,
      child: Tooltip(
        message: label,
        child: Align(
          alignment: alignment,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  Widget _benefitLineItemRow(int index, _BenefitLineItemEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: _benefitIndexColumnWidth,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              '${index + 1}.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitCategoryColumnWidth,
          child: Text(
            _benefitCategoryLabel(entry.categoryKey),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitTitleColumnWidth,
          child: Text(
            entry.titleController.text.trim().isEmpty
                ? 'Benefit item'
                : entry.titleController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitUnitValueColumnWidth,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              _formatCurrencyValue(
                _parseCurrencyInput(entry.unitValueController.text),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitTotalUnitsColumnWidth,
          child: Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.unitsController.text.trim().isEmpty
                      ? '0'
                      : entry.unitsController.text.trim(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _unitDescriptionForEntry(entry),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitTotalValueColumnWidth,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              _formatCurrencyValue(entry.totalValue),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
            ),
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitNotesColumnWidth,
          child: Text(
            entry.notesController.text.trim().isEmpty
                ? 'No basis provided'
                : entry.notesController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: _benefitColumnGap),
        SizedBox(
          width: _benefitActionsColumnWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'View item',
                onPressed: () => _viewBenefitLineItem(entry),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Edit item',
                onPressed: () => _editBenefitLineItem(entry),
                icon: const Icon(Icons.edit_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: () => _removeBenefitLineItem(entry),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('KAZ AI: Generating suggestions...'),
                        duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.auto_awesome,
                    size: 16, color: Color(0xFFF59E0B)),
                tooltip: 'KAZ AI',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _metricFocusCard(MapEntry<String, _BenefitCategorySummary> entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 16, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _benefitCategoryLabel(entry.key),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitSummaryCard({
    required String title,
    required String value,
    required String helper,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7CC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFF8F00)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(helper,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
        ),
      ]),
    );
  }

  Widget _benefitCategoryCard(
      {required String label, required _BenefitCategorySummary summary}) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Items: ${summary.itemCount}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text('Total value: ${_formatCurrencyValue(summary.valueTotal)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildProjectBenefitsReviewTab({
    required Map<String, _BenefitCategorySummary> summaries,
    required double totalValue,
    required double totalUnits,
  }) {
    // Calculate top 3 most selected categories from project benefits
    final categoryCounts = <String, int>{};
    for (final entry in _benefitLineItems) {
      categoryCounts[entry.categoryKey] =
          (categoryCounts[entry.categoryKey] ?? 0) + 1;
    }
    final topCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3CategoryKeys = topCategories.take(3).map((e) => e.key).toList();
    final top3CategoryLabels =
        top3CategoryKeys.map((key) => _benefitCategoryLabel(key)).toList();

    // Sort benefit categories by total value (highest first)
    final sortedCategories = summaries.entries.toList()
      ..sort((a, b) => b.value.valueTotal.compareTo(a.value.valueTotal));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Only show summaries if there are benefit items
      if (summaries.isEmpty) ...[
        const Text('No benefits tracked yet',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'Add project benefits in the "Line Items" tab to see a comprehensive review across all categories.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ] else ...[
        // Summary cards row
        LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final singleColumn = maxWidth < 600;
          final cards = [
            _benefitSummaryCard(
              title: 'Tracked project benefits',
              value: '${_benefitLineItems.length}',
              helper: 'With monetary values and unit drivers.',
              icon: Icons.list_alt,
            ),
            _benefitSummaryCard(
              title: 'Total monetised benefits',
              value: _formatCurrencyValue(totalValue),
              helper: 'Across all categories and portfolios.',
              icon: Icons.attach_money,
            ),
            _benefitSummaryCard(
              title: 'Line items',
              value: '${_benefitLineItems.length}',
              helper: 'Number of benefit entries captured.',
              icon: Icons.stacked_line_chart,
            ),
          ];

          if (singleColumn) {
            return Column(children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ]);
          }
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ]
            ],
          );
        }),
        const SizedBox(height: 20),

        // Project Benefits Highlights section (top 3 metrics)
        const Text('Project Benefits Highlights',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'Top 3 most selected project benefits from the 9 categories for this project.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (top3CategoryLabels.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.25)),
            ),
            child: Text(
              'No project benefits highlights yet. Add project benefits to see highlights.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final categoryLabel in top3CategoryLabels)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stacked_line_chart,
                          size: 18, color: const Color(0xFFFFD700)),
                      const SizedBox(width: 8),
                      Text(
                        categoryLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),

        // Project Benefits Value Summary section
        const Text('Project Benefits Value Summary',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'Total currency value ($_currency) of each of the 9 benefit categories for this project, ordered by highest amount.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            // Create a map of all 9 categories with their values
            final allCategoriesWithValues = <String, double>{};
            for (final field in _projectValueFields) {
              final summary = summaries[field.key];
              allCategoriesWithValues[field.key] = summary?.valueTotal ?? 0.0;
            }

            // Sort all categories by value (highest first)
            final sortedAllCategories = allCategoriesWithValues.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in sortedAllCategories)
                  _projectBenefitValueCard(
                    label: _benefitCategoryLabel(entry.key),
                    categoryKey: entry.key,
                    summary: summaries[entry.key],
                    isHighest:
                        entry == sortedAllCategories.first && entry.value > 0,
                  ),
              ],
            );
          },
        ),
      ],
      const SizedBox(height: 32),
      // Value Calculation Formulas Table (moved down)
      const Text('Value Calculation Formulas',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        'Each benefit category has a specific calculation method for determining financial impact.',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A3F),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: Text('#',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('Title',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Text('Value Calculation Formula',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...List.generate(_projectValueFields.length, (index) {
              final field = _projectValueFields[index];
              final formula = _benefitMetrics[field.key] ?? '';
              final isLast = index == _projectValueFields.length - 1;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: isLast
                      ? null
                      : Border(
                          bottom:
                              BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(field.value,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(formula,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ]);
  }

  Widget _projectBenefitValueCard({
    required String label,
    required String categoryKey,
    required _BenefitCategorySummary? summary,
    required bool isHighest,
  }) {
    final IconData icon;
    switch (categoryKey) {
      case 'revenue':
        icon = Icons.trending_up;
        break;
      case 'cost_saving':
        icon = Icons.savings;
        break;
      case 'ops_efficiency':
        icon = Icons.speed;
        break;
      case 'productivity':
        icon = Icons.access_time;
        break;
      case 'regulatory_compliance':
        icon = Icons.verified_user;
        break;
      case 'process_improvement':
        icon = Icons.auto_awesome;
        break;
      case 'brand_image':
        icon = Icons.star;
        break;
      case 'stakeholder_commitment':
        icon = Icons.handshake;
        break;
      case 'other':
      default:
        icon = Icons.more_horiz;
    }

    final hasValue = summary != null && summary.valueTotal > 0;
    final Color bgColor =
        isHighest && hasValue ? const Color(0xFF2196F3) : Colors.white;
    final Color textColor =
        isHighest && hasValue ? Colors.white : Colors.grey.shade800;
    final Color iconColor =
        isHighest && hasValue ? Colors.white : const Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighest && hasValue
              ? const Color(0xFF2196F3)
              : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (hasValue) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isHighest
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFFFF7CC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatCurrencyValue(summary.valueTotal),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isHighest ? Colors.white : const Color(0xFFFF8F00),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Initial Cost Estimate: per-solution itemized cost matrix (AI-derived items)
  Widget _buildCategoryCostMatrix() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Initial itemized estimates by solution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const _AiTag(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Enter high-level estimates per AI-identified cost item for each solution. These anchor your Initial Cost Estimate.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_categoryCostsPerSolution.isEmpty)
          Text(
              'Add at least one potential solution to start estimating per-category costs.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _categoryCostsPerSolution.length; i++) ...[
                _categoryCostCard(i),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ]),
    );
  }

  Widget _categoryCostCard(int solutionIndex) {
    final rows = _rowsPerSolution[solutionIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(_solutionTitle(solutionIndex),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700))),
          Chip(
            avatar: const Icon(Icons.summarize_outlined, size: 16),
            label: Text(
                'Total: ${_formatCurrencyValue(_solutionTotalCost(solutionIndex))}'),
          )
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.35))),
          child: Row(children: const [
            Expanded(
                flex: 3,
                child: Center(
                    child: Text('Item',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            SizedBox(width: 12),
            Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('Estimated cost',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            SizedBox(width: 12),
            Expanded(
                flex: 4,
                child: Center(
                    child: Text('Comments',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            SizedBox(width: 8),
            SizedBox(width: 36),
          ]),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.25))),
          child: Column(children: [
            for (final r in rows) _initialItemCostRow(r),
          ]),
        ),
      ]),
    );
  }

  Widget _categoryCostRow(int solutionIndex, String categoryKey, String label,
      _CategoryCostEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3, child: Text(label, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: VoiceTextField(
              controller: entry.costController,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: _costFieldAiPrefix(
                  loading: entry.aiLoading,
                  onSuggest: () => _suggestCategoryCost(
                      solutionIndex, categoryKey, label, entry),
                ),
                prefixIconConstraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                suffix: _currencySuffix(_currency),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: ExpandingTextField(
            controller: entry.notesController,
            decoration: const InputDecoration(
              hintText: 'Assumptions or notes for this category',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            minLines: 1,
          ),
        ),
      ]),
    );
  }

  // Row renderer for itemized initial estimate (reuses _CostRow controllers)
  Widget _initialItemCostRow(_CostRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          flex: 3,
          child: Center(
            child: ExpandableText(
              text: row.itemController.text.trim().isEmpty ||
                      row.itemController.text.trim().toLowerCase() == 'name'
                  ? 'Cost item'
                  : row.itemController.text.trim(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 2,
              expandButtonColor: const Color(0xFF0D6EFD),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              _formatCurrencyValue(row.currentCost()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Center(
            child: ExpandableText(
              text: row.assumptionsController.text.trim().isEmpty
                  ? (row.descriptionController.text.trim().isEmpty
                      ? 'No comments'
                      : row.descriptionController.text.trim())
                  : row.assumptionsController.text.trim(),
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              expandButtonColor: const Color(0xFF0D6EFD),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _initialCostActionsColumnWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'View details',
                onPressed: () => _viewInitialCostRow(row),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Edit row',
                onPressed: () => _editInitialCostRow(row),
                icon: const Icon(Icons.edit_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Delete row',
                onPressed: () => _removeInitialCostRow(row),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('KAZ AI: Generating suggestions...'),
                        duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.auto_awesome,
                    size: 16, color: Color(0xFFF59E0B)),
                tooltip: 'KAZ AI',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // Compact controls moved: AI icon at the start (prefix), currency at the end (suffix)
  Widget _costFieldAiPrefix(
      {required bool loading, required VoidCallback onSuggest}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      onPressed: onSuggest,
      tooltip: 'Suggest with AI',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
    );
  }

  Widget _currencySuffix(String currency) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(currency,
          style: TextStyle(fontSize: 11, color: Colors.grey[700])),
    );
  }

  Future<double?> _estimateCostForInputs({
    required String itemName,
    required String description,
    required String assumptions,
    required int solutionIndex,
  }) async {
    try {
      return await _openAi.estimateCostForItem(
        itemName: itemName,
        description: description,
        assumptions: assumptions,
        currency: _currency,
        contextNotes: _buildUnifiedAiContext(
          sectionLabel: 'Cost Benefit Analysis - Initial Cost Estimate',
          forSolution: solutionIndex,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to estimate cost: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _suggestCategoryCost(int solutionIndex, String categoryKey,
      String label, _CategoryCostEntry entry) async {
    if (entry.aiLoading) return;
    setState(() => entry.aiLoading = true);
    try {
      final cost = await _openAi.estimateCostForItem(
        itemName: '$label (category estimate)',
        description: 'High-level category estimate for $_currency',
        assumptions: entry.notesController.text,
        currency: _currency,
        contextNotes: _buildUnifiedAiContext(
          sectionLabel: 'Cost Benefit Analysis - Initial Cost Estimate',
          forSolution: solutionIndex,
        ),
      );
      if (!mounted) return;
      setState(() {
        final v = cost.isFinite ? cost : 0;
        entry.costController.text =
            v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
      });
    } catch (e) {
      debugPrint('Error estimating category cost: $e');
    } finally {
      if (mounted) setState(() => entry.aiLoading = false);
    }
  }

  double _initialCostEstimateTotalFor(int index) {
    if (index < 0 || index >= _categoryCostsPerSolution.length) return 0;
    final map = _categoryCostsPerSolution[index];
    double sum = 0;
    for (final entry in map.values) {
      sum += entry.cost;
    }
    return sum;
  }

  Widget _buildValuesGainedSummary() {
    if (_rowsPerSolution.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.25))),
        child: Text(
            'Add solutions to compare values gained in Profitability Analysis.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Project Value per solution',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final single = width < 760;
        final cards = [
          for (int i = 0; i < _rowsPerSolution.length; i++)
            _valuesGainedCard(i),
        ];
        if (single) {
          return Column(children: [
            for (final c in cards) ...[c, const SizedBox(height: 12)]
          ]);
        }
        return Row(children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i != cards.length - 1) const SizedBox(width: 12),
          ]
        ]);
      }),
    ]);
  }

  // Step 2: Initial Cost Estimate with solution tabs and currency selector
  Widget _buildInitialCostEstimateTabs() {
    final tabCount = _categoryCostsPerSolution.length;
    final activeIndex = _boundedIndex(_activeTab, tabCount == 0 ? 1 : tabCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final titleRow = Row(children: [
              const Text('Initial cost estimate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const _AiTag(),
            ]);
            final actionButtons = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _populateCategoriesFromAi,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('Populate categories (AI)'),
                ),
                const SizedBox(width: 8),
                _currencyDropdown(),
              ],
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [actionButtons],
                  ),
                ],
              );
            }
            return Row(children: [
              titleRow,
              const Spacer(),
              actionButtons,
            ]);
          },
        ),
        const SizedBox(height: 12),
        if (tabCount == 0)
          Text('Add solutions to start estimating per-solution costs.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]))
        else ...[
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < tabCount; i++)
                ChoiceChip(
                  label: Text(_solutionTitle(i),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: activeIndex == i,
                  onSelected: (_) => _onActiveSolutionChanged(i),
                  selectedColor: const Color(0xFFFFD700),
                  backgroundColor: Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInitialCostTable(activeIndex),
          const SizedBox(height: 12),
          _buildCategoryIdeasSection(activeIndex),
        ]
      ]),
    );
  }

  // Opportunity Savings Section for Step 2 (Initial Cost Estimate)
  // Shows savings that can be subtracted from total cost for identified opportunities
  Widget _buildOpportunitySavingsSection() {
    final activeIndex = _boundedIndex(
        _activeTab, _rowsPerSolution.isEmpty ? 1 : _rowsPerSolution.length);
    final totalValue = _projectBenefitTotalForSolution(activeIndex);
    final currentSolutionTotal =
        _rowsPerSolution.isNotEmpty ? _solutionTotalCost(activeIndex) : 0.0;

    // Calculate total savings from suggestions
    double totalSavings = 0.0;
    for (final suggestion in _savingsSuggestions) {
      totalSavings += suggestion.projectedSavings;
    }

    // Net cost after savings
    final netCost = currentSolutionTotal - totalSavings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Savings Calculator',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const _AiTag(),
          const Spacer(),
          ElevatedButton.icon(
            onPressed:
                _isSavingsGenerating ? null : _generateSavingsSuggestions,
            icon: _isSavingsGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Generate savings scenarios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Identify cost savings opportunities for this solution. Generated savings can be subtracted from the total estimated cost.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              height: 56,
              child: VoiceTextField(
                controller: _savingsTargetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Savings target (%)',
                  hintText: 'e.g. 10',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 280,
              height: 56,
              child: VoiceTextField(
                controller: _savingsNotesController,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Context notes',
                  hintText: 'Add constraints or priorities',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.payments_outlined,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Total benefits: ${_formatCurrencyValue(totalValue)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_savingsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(_savingsError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        if (_savingsSuggestions.isEmpty && _savingsError == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _benefitLineItems.isEmpty
                    ? 'Add project benefits in the "Line Items" tab to enable AI savings analysis.'
                    : 'Click "Generate savings scenarios" to identify cost reduction opportunities for this solution.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ]),
          ),
        if (_savingsSuggestions.isNotEmpty) ...[
          const Text('Identified Savings Opportunities',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(children: [
              for (int i = 0; i < _savingsSuggestions.length; i++)
                _savingsSuggestionTile(i, _savingsSuggestions[i]),
            ]),
          ),
          const SizedBox(height: 16),
          // Summary: Total savings to subtract from cost
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cost Summary',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Estimated Solution Cost:',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                                Text(_formatCurrencyValue(currentSolutionTotal),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        const Text('−',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Identified Savings:',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                                Text(_formatCurrencyValue(totalSavings),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green)),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        const Text('=',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Net Cost:',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                                Text(_formatCurrencyValue(netCost),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ]),
                    ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildContingencyButtons(int solutionIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('Contingency:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ...[10, 20, 25, 30, 35, 40].map((percent) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () => _applyContingency(solutionIndex, percent),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child:
                      Text('$percent%', style: const TextStyle(fontSize: 11)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInitialCostTable(int solutionIndex) {
    final rows = _rowsPerSolution[solutionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 920.0;
            final tableWidth = constraints.maxWidth < minTableWidth
                ? minTableWidth
                : constraints.maxWidth;

            return Scrollbar(
              controller: _initialCostTableHorizontalController,
              thumbVisibility: constraints.maxWidth < minTableWidth,
              trackVisibility: constraints.maxWidth < minTableWidth,
              interactive: true,
              notificationPredicate: (notification) => notification.depth == 0,
              child: SingleChildScrollView(
                controller: _initialCostTableHorizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.35))),
                        child: Row(children: [
                          SizedBox(
                            width: 300,
                            child: const Align(
                              alignment: Alignment.center,
                              child: Text('Item',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 150,
                            child: const Align(
                                alignment: Alignment.center,
                                child: Text('Estimated cost',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 300,
                            child: const Align(
                              alignment: Alignment.center,
                              child: Text('Comments',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: _initialCostActionsColumnWidth,
                            child: const Align(
                              alignment: Alignment.center,
                              child: Text('Actions',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.25))),
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 360),
                              child: Scrollbar(
                                thumbVisibility: rows.length > 4,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (final r in rows)
                                        _initialItemCostRow(r),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color:
                                              Colors.grey.withOpacity(0.2)))),
                              child: Row(children: [
                                Expanded(
                                  flex: 3,
                                  child: Center(
                                    child: Text('Total',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _formatCurrencyValue(
                                          _solutionTotalCost(solutionIndex)),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(flex: 4, child: const SizedBox()),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: _initialCostActionsColumnWidth,
                                  child: const SizedBox(),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildContingencyButtons(solutionIndex),
        const SizedBox(height: 10),
        Row(children: [
          CsvTableImportButton(
            tableTitle: 'Initial Cost Estimate',
            columns: _costCsvColumns,
            onImport: (rows) => _handleCostCsvImport(solutionIndex, rows),
            compact: true,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _addInitialCostRow(solutionIndex),
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ]),
      ],
    );
  }

  void _applyContingency(int solutionIndex, int percent) {
    if (solutionIndex < 0 || solutionIndex >= _rowsPerSolution.length) return;
    final currentTotal = _solutionTotalCost(solutionIndex);
    final contingencyAmount = currentTotal * (percent / 100);

    // Add a new row for contingency
    final row = _CostRow(currencyProvider: () => _currency);
    _attachRowDirtyListeners(row);
    row.setHorizon(_npvHorizon);
    row.itemController.text = 'Contingency ($percent%)';
    row.costController.text =
        contingencyAmount.toStringAsFixed(contingencyAmount % 1 == 0 ? 0 : 2);
    row.assumptionsController.text =
        '$percent% contingency applied to current estimated cost total of ${_formatCurrencyValue(currentTotal)}';

    setState(() {
      _rowsPerSolution[solutionIndex].add(row);
    });
    _markDirty();
  }

  Future<void> _addInitialCostRow(int solutionIndex) async {
    if (solutionIndex < 0 || solutionIndex >= _rowsPerSolution.length) return;
    final draft = await _showInitialCostRowDialog(
      mode: _EditorDialogMode.create,
      solutionIndex: solutionIndex,
    );
    if (draft == null) return;
    final row = _CostRow(currencyProvider: () => _currency);
    _attachRowDirtyListeners(row);
    row.setHorizon(_npvHorizon);
    row.itemController.text = draft.itemName;
    row.descriptionController.text = draft.description;
    row.costController.text = draft.cost;
    row.assumptionsController.text = draft.assumptions;
    setState(() {
      _rowsPerSolution[solutionIndex].add(row);
    });
    _refreshJustificationFor(solutionIndex, force: true);
    _markDirty();
  }

  void _handleCostCsvImport(int solutionIndex, List<Map<String, String>> rows) {
    if (solutionIndex < 0 || solutionIndex >= _rowsPerSolution.length) return;
    int imported = 0;
    for (final row in rows) {
      final itemName = row['itemName'] ?? '';
      final cost = row['cost'] ?? '';
      if (itemName.trim().isEmpty && cost.trim().isEmpty) continue;
      final costRow = _CostRow(currencyProvider: () => _currency);
      _attachRowDirtyListeners(costRow);
      costRow.setHorizon(_npvHorizon);
      costRow.itemController.text = itemName;
      costRow.descriptionController.text = row['description'] ?? '';
      costRow.costController.text = cost;
      costRow.assumptionsController.text = row['assumptions'] ?? '';
      setState(() {
        _rowsPerSolution[solutionIndex].add(costRow);
      });
      imported++;
    }
    _refreshJustificationFor(solutionIndex, force: true);
    _markDirty();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Imported $imported cost item${imported == 1 ? '' : 's'}'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  int _findSolutionIndexForRow(_CostRow row) {
    for (int i = 0; i < _rowsPerSolution.length; i++) {
      if (_rowsPerSolution[i].contains(row)) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _editInitialCostRow(_CostRow row) async {
    final solutionIndex = _findSolutionIndexForRow(row);
    if (solutionIndex == -1) return;
    final draft = await _showInitialCostRowDialog(
      mode: _EditorDialogMode.edit,
      solutionIndex: solutionIndex,
      row: row,
    );
    if (draft == null) return;
    setState(() {
      row.itemController.text = draft.itemName;
      row.descriptionController.text = draft.description;
      row.costController.text = draft.cost;
      row.assumptionsController.text = draft.assumptions;
    });
    _refreshJustificationFor(solutionIndex, force: true);
    _markDirty();
  }

  Future<void> _viewInitialCostRow(_CostRow row) async {
    final solutionIndex = _findSolutionIndexForRow(row);
    if (solutionIndex == -1) return;
    await _showInitialCostRowDialog(
      mode: _EditorDialogMode.view,
      solutionIndex: solutionIndex,
      row: row,
    );
  }

  Future<void> _removeInitialCostRow(_CostRow row) async {
    // Locate the solution index containing this row
    final foundIndex = _findSolutionIndexForRow(row);
    if (foundIndex == -1) return;

    bool hasMeaningfulData() {
      final name = row.itemController.text.trim();
      final desc = row.descriptionController.text.trim();
      final assumptions = row.assumptionsController.text.trim();
      final cost = row.currentCost();
      final hasName = name.isNotEmpty && name.toLowerCase() != 'name';
      final hasDesc =
          desc.isNotEmpty && !desc.toLowerCase().startsWith('lorem ipsum');
      final hasAssumptions = assumptions.isNotEmpty;
      return hasName || hasDesc || hasAssumptions || cost > 0;
    }

    bool proceed = true;
    if (hasMeaningfulData()) {
      proceed = await showDeleteConfirmationDialog(
        context,
        title: 'Delete cost row',
        itemLabel: row.itemController.text.trim(),
        message:
            'Delete this initial cost estimate row? This action cannot be undone.',
      );
    }
    if (!proceed) return;

    setState(() {
      _rowsPerSolution[foundIndex].remove(row);
    });
    // dispose controllers of the removed row
    row.dispose();
    _refreshJustificationFor(foundIndex, force: true);
    _markDirty();
  }

  Future<_InitialCostRowDraft?> _showInitialCostRowDialog({
    required _EditorDialogMode mode,
    required int solutionIndex,
    _CostRow? row,
  }) async {
    final itemController =
        TextEditingController(text: row?.itemController.text ?? '');
    final descriptionController =
        TextEditingController(text: row?.descriptionController.text ?? '');
    final costController =
        TextEditingController(text: row?.costController.text ?? '');
    final assumptionsController =
        TextEditingController(text: row?.assumptionsController.text ?? '');
    bool isSuggesting = false;
    final readOnly = mode == _EditorDialogMode.view;
    final result = await showDialog<_InitialCostRowDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final title = switch (mode) {
            _EditorDialogMode.create => 'Add cost row',
            _EditorDialogMode.edit => 'Edit cost row',
            _EditorDialogMode.view => 'View cost row',
          };
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VoiceTextField(
                      controller: itemController,
                      readOnly: readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: descriptionController,
                      readOnly: readOnly,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: costController,
                      readOnly: readOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Estimated cost ($_currency)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (!readOnly) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: isSuggesting
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isSuggesting = true;
                                  });
                                  final suggestedCost =
                                      await _estimateCostForInputs(
                                    itemName: itemController.text.trim(),
                                    description:
                                        descriptionController.text.trim(),
                                    assumptions:
                                        assumptionsController.text.trim(),
                                    solutionIndex: solutionIndex,
                                  );
                                  if (!mounted || !dialogContext.mounted) {
                                    return;
                                  }
                                  if (suggestedCost != null &&
                                      suggestedCost > 0) {
                                    costController.text =
                                        suggestedCost.toStringAsFixed(
                                      suggestedCost % 1 == 0 ? 0 : 2,
                                    );
                                  }
                                  setDialogState(() {
                                    isSuggesting = false;
                                  });
                                },
                          icon: isSuggesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Suggest with AI'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: assumptionsController,
                      readOnly: readOnly,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Comments / assumptions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(readOnly ? 'Close' : 'Cancel'),
              ),
              if (!readOnly)
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _InitialCostRowDraft(
                        itemName: itemController.text.trim(),
                        description: descriptionController.text.trim(),
                        cost: costController.text.trim(),
                        assumptions: assumptionsController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
            ],
          );
        },
      ),
    );
    itemController.dispose();
    descriptionController.dispose();
    costController.dispose();
    assumptionsController.dispose();
    return result;
  }

  Widget _buildCategoryIdeasSection(int solutionIndex) {
    final ideasMap = _categoryIdeasPerSolution[solutionIndex];
    final hasIdeas = ideasMap.values.any((list) => list.isNotEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('KAZ AI-generated Project Value category ideas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const _AiTag(),
          const Spacer(),
          TextButton.icon(
            onPressed: _isGenerating
                ? null
                : () =>
                    _populateCategoriesFromAi(targetSolution: solutionIndex),
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate ideas'),
          ),
        ]),
        const SizedBox(height: 8),
        if (!hasIdeas)
          Text(
              'Use Populate categories (AI) to see tailored ideas derived from earlier steps.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in _projectValueFields) ...[
                if ((ideasMap[field.key] ?? const []).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(field.value,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in ideasMap[field.key]!.take(20))
                        ActionChip(
                          label: Text(
                              '${item.item}${item.estimatedCost > 0 ? ' • ${_formatCurrencyValue(item.estimatedCost)}' : ''}',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.add, size: 16),
                          onPressed: () => _applyIdeaToCategory(
                              solutionIndex, field.key, item),
                        ),
                    ],
                  ),
                ]
              ],
            ],
          ),
      ]),
    );
  }

  // Step 3: Profitability analysis main table for all solutions
  Widget _buildProfitabilitySummaryTable() {
    final count = _rowsPerSolution.length;
    if (count == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2))),
        child: const Text(
            'Add one or more solutions to see ROI, NPV, and IRR results.'),
      );
    }
    final horizon = _npvHorizon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Profitability analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.35))),
          child: Row(children: [
            const Expanded(
                flex: 4,
                child: Center(
                    child: Text('Solution',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            const Expanded(
                flex: 2,
                child: Center(
                    child: Text('ROI',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 16),
            Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.center,
                    child: Text('NPV ($horizon-yr)',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 16),
            const Expanded(
                flex: 2,
                child: Center(
                    child: Text('IRR',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))),
          ]),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.25))),
          child: Column(children: [
            for (int i = 0; i < count; i++) _profitabilityRow(i),
          ]),
        ),
      ]),
    );
  }

  Widget _profitabilityRow(int index) {
    final solutionLabel = _solutionTitle(index);
    final annualProjectValue = _projectBenefitTotalForSolution(index);
    final currentProjectValue = _currentProjectValueForSolution(index);
    final initialCost = _initialCostForSolution(index);
    final roiPct = _solutionRoiPercent(
      currentProjectValue: currentProjectValue,
      initialCost: initialCost,
    );
    final npv = _solutionNpv(
      annualProjectValue: annualProjectValue,
      initialCost: initialCost,
    );
    final irrPercent = _solutionIrrPercent(
      currentProjectValue: currentProjectValue,
      initialCost: initialCost,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: Colors.grey.withOpacity(index == 0 ? 0 : 0.2)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            flex: 4,
            child: Center(
                child:
                    Text(solutionLabel, style: const TextStyle(fontSize: 13)))),
        Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.center,
                child: Text(_formatPercentValue(roiPct),
                    textAlign: TextAlign.center))),
        const SizedBox(width: 16),
        Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.center,
                child: Text(_formatCurrencyValue(npv)))),
        const SizedBox(width: 16),
        Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.center,
                child: Text(_formatPercentValue(irrPercent),
                    textAlign: TextAlign.center))),
      ]),
    );
  }

  Widget _valuesGainedCard(int index) {
    // Per requirement: use the total from the Initial cost estimate table (itemized rows)
    // for each solution. If there are no rows yet, fall back to any category total.
    final primaryCost = _solutionTotalCost(index);
    final fallbackCost = _initialCostEstimateTotalFor(index);
    final cost = primaryCost > 0 ? primaryCost : fallbackCost;
    final snapshot = _valueSetupInvestmentSnapshot(solutionIndex: index);
    final double effectiveBenefits =
        snapshot != null ? snapshot.totalBenefits : 0.0;
    final net = effectiveBenefits - cost;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_solutionTitle(index),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _summaryMetric(
                  label: 'Project Value',
                  value: _formatCurrencyValue(effectiveBenefits))),
          const SizedBox(width: 12),
          Expanded(
              child: _summaryMetric(
                  label: 'Initial cost', value: _formatCurrencyValue(cost))),
          const SizedBox(width: 12),
          Expanded(
              child: _summaryMetric(
                  label: 'Net value', value: _formatCurrencyValue(net))),
        ]),
      ]),
    );
  }

  Widget _savingsSuggestionTile(
      int index, AiBenefitSavingsSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.grey.withOpacity(index == 0 ? 0 : 0.2))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${index + 1}. ${suggestion.lever}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${suggestion.confidence} confidence',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
        const SizedBox(height: 4),
        Text(
          suggestion.recommendation,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            Chip(
              avatar: const Icon(Icons.savings_outlined, size: 16),
              label: Text(
                  'Projected savings: ${_formatCurrencyValue(suggestion.projectedSavings)}'),
            ),
            Chip(
              avatar: const Icon(Icons.schedule_outlined, size: 16),
              label: Text(
                  'Timeframe: ${suggestion.timeframe.isEmpty ? 'TBD' : suggestion.timeframe}'),
            ),
          ],
        ),
        if (suggestion.rationale.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            suggestion.rationale,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
        ],
      ]),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: ExpandingTextField(
        controller: _notesController,
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        decoration: const InputDecoration(
          hintText:
              'Capture assumptions, discount rates, or stakeholder feedback here...',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        minLines: 1,
      ),
    );
  }

  Widget _buildMetricToolbar(
      {required bool isMobile, required String horizonLabel}) {
    final horizons = [1, 3, 5, 10];
    final rateSelections = _discountRateOptions
        .map((rate) => (_discountRate - rate).abs() < 0.0001)
        .toList(growable: false);
    final toggleButtons = ToggleButtons(
      isSelected: horizons.map((year) => _npvHorizon == year).toList(),
      onPressed: (index) {
        final selectedYear = horizons[index];
        setState(() {
          _npvHorizon = selectedYear;
          for (final list in _rowsPerSolution) {
            for (final row in list) {
              row.setHorizon(selectedYear);
            }
          }
        });
        _markDirty();
      },
      borderRadius: BorderRadius.circular(20),
      selectedColor: Colors.black,
      fillColor: const Color(0xFFFFD700),
      constraints: const BoxConstraints(minHeight: 34, minWidth: 54),
      children: horizons
          .map((year) => Text('$year yr', style: const TextStyle(fontSize: 13)))
          .toList(),
    );
    final rateToggleButtons = ToggleButtons(
      isSelected: rateSelections,
      onPressed: (index) {
        final selectedRate = _discountRateOptions[index];
        setState(() {
          _discountRate = selectedRate;
        });
        _markDirty();
      },
      borderRadius: BorderRadius.circular(20),
      selectedColor: Colors.black,
      fillColor: const Color(0xFFFFD700),
      constraints: const BoxConstraints(minHeight: 34, minWidth: 56),
      children: _discountRateOptions
          .map((rate) => Text(
                '${(rate * 100).round()}%',
                style: const TextStyle(fontSize: 13),
              ))
          .toList(growable: false),
    );

    final generateButton = ElevatedButton.icon(
      onPressed: _isGenerating ? null : _generateCostBreakdown,
      icon: const Icon(Icons.bolt_outlined, size: 18),
      label: const Text('Regenerate with AI'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
    );

    if (isMobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Financial metric horizon',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            toggleButtons,
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('NPV discount rate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            rateToggleButtons,
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Tooltip(
            message:
                'NPV values update for the selected horizon so each solution compares on equal time frames.',
            child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          generateButton,
        ]),
        const SizedBox(height: 6),
        Text(
            'Current view: $horizonLabel cashflows across every solution at ${(_discountRate * 100).round()}% discount rate.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Financial metric horizon',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        toggleButtons,
        const SizedBox(width: 12),
        const Tooltip(
          message:
              'NPV values update for the selected horizon so each solution compares on equal time frames.',
          child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
        ),
        const Spacer(),
        generateButton,
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const Text('NPV discount rate',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        rateToggleButtons,
      ]),
      const SizedBox(height: 6),
      Text(
          'Current view: $horizonLabel cashflows across every solution at ${(_discountRate * 100).round()}% discount rate.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }

  Widget _buildSolutionSummaries({required bool isMobile}) {
    final cardCount = _rowsPerSolution.length;
    if (cardCount == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: const Text(
            'Add at least one potential solution to start modelling costs and benefits.'),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Solution cost snapshots',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        const _AiTag(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'AI can populate or refresh the cost structure for each option; edit any project benefits directly in the breakdown below.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        const spacing = 16.0;
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final safeWidth = viewportWidth <= 0
            ? MediaQuery.of(context).size.width
            : viewportWidth;
        final singleColumn = isMobile || safeWidth < 760;
        final computedColumns = (safeWidth / (340 + spacing)).floor();
        final int columns = singleColumn
            ? 1
            : computedColumns < 1
                ? 1
                : computedColumns > 3
                    ? 3
                    : computedColumns;
        final double tileWidth = singleColumn
            ? safeWidth
            : math.max(
                280.0,
                (safeWidth - (spacing * (columns - 1))) / columns,
              );
        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (int i = 0; i < cardCount; i++)
                SizedBox(width: tileWidth, child: _solutionSummaryCard(i)),
            ],
          ),
        );
      }),
    ]);
  }

  Widget _solutionSummaryCard(int index) {
    final hasSolutions = index < widget.solutions.length;
    final AiSolutionItem? solution =
        hasSolutions ? widget.solutions[index] : null;
    final title = (solution?.title ?? '').trim().isNotEmpty
        ? solution!.title
        : 'Potential Solution ${index + 1}';
    final description = (solution?.description ?? '').trim().isNotEmpty
        ? solution!.description
        : 'Describe how this solution creates value so ROI and NPV have clear context.';
    final valueSetupSnapshot =
        _valueSetupInvestmentSnapshot(solutionIndex: index);
    // Per requirement: Estimated cost must reflect the sum of the 'Estimated cost'
    // values entered in the 'Initial cost estimate' table for this solution.
    // We therefore prioritise the itemized table total; if missing, fall back to
    // any legacy/category totals.
    final double initialItemsTotal = _solutionTotalCost(index);
    final double fallbackCategoryTotal = _initialCostEstimateTotalFor(index);
    final double totalCost =
        initialItemsTotal > 0 ? initialItemsTotal : fallbackCategoryTotal;
    // Only calculate NPV and ROI if Initial Project Value is set
    final double totalNpv =
        valueSetupSnapshot != null ? (valueSetupSnapshot.npv ?? 0) : 0;
    final double avgRoi =
        valueSetupSnapshot != null ? (valueSetupSnapshot.averageRoi ?? 0) : 0;
    final int summaryCount =
        valueSetupSnapshot?.benefitLineItemCount ?? _solutionItemCount(index);
    final bool usesValueSetup = valueSetupSnapshot != null;
    final bool hasValueSetupBenefits =
        valueSetupSnapshot?.hasBenefitSignals ?? false;
    final helper = usesValueSetup
        ? (hasValueSetupBenefits
            ? 'Derived from Project Value baseline and monetised benefit entries. Adjust the "Line Items" tab to update this snapshot.'
            : 'Project Value baseline anchors this snapshot. Add monetised benefits in the "Line Items" tab to unlock ROI and NPV context.')
        : totalCost > 0
            ? 'AI generated total based on the current cost items. Adjust any project benefit to update this summary.'
            : 'Use AI or add cost items below to build this investment profile.';
    final isLoading = _solutionLoading.contains(index);
    final contextData = _contextFor(index);
    final costRange =
        valueSetupSnapshot?.costRange ?? _solutionCostRange(index);
    final assumptionHighlights = _assumptionHighlights(index);
    final driverHighlights = _topCostDrivers(index);
    final justification = contextData.justificationController.text.trim();
    final totalRows = index >= 0 && index < _rowsPerSolution.length
        ? _rowsPerSolution[index].length
        : 0;
    final summaryLine = usesValueSetup
        ? (hasValueSetupBenefits
            ? '$summaryCount project benefits captured | Update the "Line Items" tab to recalc ROI/NPV automatically.'
            : 'Project Value baseline captured | Add monetised benefits in the "Line Items" tab to enrich ROI/NPV context.')
        : '$summaryCount/$totalRows cost items tracked | ROI/NPV adjust automatically as you edit project benefits.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (isLoading)
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4)),
        ]),
        const SizedBox(height: 14),
        const Text('Estimated cost',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_formatCurrencyValue(totalCost),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        if (costRange != null) ...[
          const SizedBox(height: 4),
          Text(
              'Range: ${_formatCurrencyValue(costRange.lower)} – ${_formatCurrencyValue(costRange.upper)}',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 4),
        Text(helper, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _summaryMetric(
                  label: 'NPV ($_npvHorizon-year)',
                  value: _formatCurrencyValue(totalNpv))),
          const SizedBox(width: 12),
          Expanded(
              child: _summaryMetric(
                  label: 'Average ROI', value: _formatPercentValue(avgRoi))),
        ]),
        const SizedBox(height: 10),
        Text(summaryLine,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Divider(color: Colors.grey.withOpacity(0.2), height: 1),
        const SizedBox(height: 12),
        const Text('Cost assumptions',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 540;
          final selectors = [
            _assumptionSelector(
              label: 'Resources',
              value: contextData.resourceIndex,
              options: _resourceOptions,
              onChanged: (value) {
                setState(() {
                  contextData.resourceIndex = value;
                  contextData.autoGenerated = false;
                  _refreshJustificationFor(index);
                });
                _markDirty();
              },
            ),
            _assumptionSelector(
              label: 'Timeline',
              value: contextData.timelineIndex,
              options: _timelineOptions,
              onChanged: (value) {
                setState(() {
                  contextData.timelineIndex = value;
                  contextData.autoGenerated = false;
                  _refreshJustificationFor(index);
                });
                _markDirty();
              },
            ),
            _assumptionSelector(
              label: 'Complexity',
              value: contextData.complexityIndex,
              options: _complexityOptions,
              onChanged: (value) {
                setState(() {
                  contextData.complexityIndex = value;
                  contextData.autoGenerated = false;
                  _refreshJustificationFor(index);
                });
                _markDirty();
              },
            ),
          ];
          if (narrow) {
            return Column(children: [
              for (final selector in selectors) ...[
                selector,
                const SizedBox(height: 10),
              ],
            ]);
          }
          // Use Flexible to prevent overflow in Row
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (int i = 0; i < selectors.length; i++) ...[
              Flexible(
                flex: 1,
                child: selectors[i],
              ),
              if (i != selectors.length - 1) const SizedBox(width: 12),
            ],
          ]);
        }),
        const SizedBox(height: 8),
        Text('AI uses these assumptions when refreshing the estimate.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 12),
        if (assumptionHighlights.isNotEmpty) ...[
          const Text('Assumption snapshot',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final highlight in assumptionHighlights)
            _costDriverBullet(highlight),
          const SizedBox(height: 12),
        ],
        const Text('Drivers & justification',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (driverHighlights.isNotEmpty) ...[
          for (final driver in driverHighlights) _costDriverBullet(driver),
          if (justification.isNotEmpty) const SizedBox(height: 6),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                'Add or regenerate cost items to surface AI-driven cost drivers.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
        ExpandingTextField(
          controller: contextData.justificationController,
          minLines: 2,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          decoration: InputDecoration(
            hintText:
                'Explain why this investment level is appropriate (e.g., resourcing, integrations, governance).',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 12),
        // Wrap buttons in Flexible/Expanded to prevent overflow
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 300;
          return SizedBox(
            width: isNarrow ? double.infinity : null,
            child: OutlinedButton.icon(
              onPressed: (!hasSolutions || isLoading)
                  ? null
                  : () => _handleRefreshSolutionSnapshot(index),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high_outlined, size: 18),
              label: const Text('Refresh with AI'),
            ),
          );
        }),
      ]),
    );
  }

  Future<void> _handleRefreshSolutionSnapshot(int index) async {
    await _generateCostBreakdownForSolution(index);
  }

  Widget _summaryMetric(
      {required String label, required String value, String? helper}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (helper != null) ...[
        const SizedBox(height: 2),
        Text(helper, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    ]);
  }

  _SolutionCostContext _contextFor(int index) {
    var safeIndex = index;
    if (safeIndex < 0) safeIndex = 0;
    while (safeIndex >= _solutionContexts.length) {
      final context = _SolutionCostContext();
      context.justificationController.addListener(_markDirty);
      _solutionContexts.add(context);
    }
    return _solutionContexts[safeIndex];
  }

  int _boundedIndex(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }

  Widget _assumptionSelector(
      {required String label,
      required int value,
      required List<_QualitativeOption> options,
      required ValueChanged<int> onChanged}) {
    final boundedValue = _boundedIndex(value, options.length);
    return DropdownButtonFormField<int>(
      value: boundedValue,
      itemHeight: null, // allow multi-line menu entries without overflow
      menuMaxHeight: 320,
      isExpanded: true, // Prevent overflow by expanding to fill available space
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        for (int i = 0; i < options.length; i++)
          DropdownMenuItem<int>(
            value: i,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(options[i].label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
                const SizedBox(height: 2),
                Text(options[i].detail,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _costDriverBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 6, color: Colors.grey),
        ),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 11.5, color: Colors.grey[700]))),
      ]),
    );
  }

  List<String> _assumptionHighlights(int index) {
    if (index < 0 || index >= _solutionContexts.length) return const [];
    final context = _solutionContexts[index];
    final resource = _resourceOptions[
        _boundedIndex(context.resourceIndex, _resourceOptions.length)];
    final timeline = _timelineOptions[
        _boundedIndex(context.timelineIndex, _timelineOptions.length)];
    final complexity = _complexityOptions[
        _boundedIndex(context.complexityIndex, _complexityOptions.length)];
    return [
      'Resourcing: ${resource.label} — ${resource.detail}.',
      'Timeline: ${timeline.label} — ${timeline.detail}.',
      'Complexity: ${complexity.label} — ${complexity.detail}.',
    ];
  }

  _CostRange? _solutionCostRange(int index) {
    final total = _solutionTotalCost(index);
    if (total <= 0) return null;
    final lower = total * 0.85;
    final upper = total * 1.15;
    return _CostRange(lower: lower, upper: upper);
  }

  List<String> _topCostDrivers(int index) {
    if (index < 0 || index >= _rowsPerSolution.length) return const [];
    final rows = _rowsPerSolution[index];
    final entries = <MapEntry<String, double>>[];
    for (final row in rows) {
      final cost = row.currentCost();
      if (cost <= 0) continue;
      final name = row.itemController.text.trim();
      final label = name.isEmpty || name == 'Name' ? 'Item' : name;
      entries.add(MapEntry(label, cost));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(3)
        .map((e) => '${e.key} • ${_formatCurrencyValue(e.value)}')
        .toList();
  }

  void _refreshJustificationFor(int index, {bool force = false}) {
    if (index < 0 || index >= _solutionContexts.length) return;
    final context = _solutionContexts[index];
    final resource = _resourceOptions[
        _boundedIndex(context.resourceIndex, _resourceOptions.length)];
    final timeline = _timelineOptions[
        _boundedIndex(context.timelineIndex, _timelineOptions.length)];
    final complexity = _complexityOptions[
        _boundedIndex(context.complexityIndex, _complexityOptions.length)];
    final drivers = _topCostDrivers(index);
    final buffer = StringBuffer()
      ..write(
          'Resourcing requires ${resource.detail.toLowerCase()} (${resource.label.toLowerCase()}). ')
      ..write(
          'Delivery timeline: ${timeline.detail.toLowerCase()} (${timeline.label}). ')
      ..write(
          'Complexity: ${complexity.detail.toLowerCase()} (${complexity.label}).');
    if (drivers.isNotEmpty) {
      buffer.write(' Major cost drivers: ${drivers.join('; ')}.');
    }
    final narrative = buffer.toString().trim();
    final isEmpty = context.justificationController.text.trim().isEmpty;
    if (force || isEmpty || context.autoGenerated) {
      context.updateJustification(narrative);
    }
  }

  Widget _buildDetailedBreakdown(
      {required bool isMobile, required String horizonLabel}) {
    final tabsCount = _rowsPerSolution.length;
    final int activeIndex;
    if (tabsCount == 0) {
      activeIndex = 0;
    } else if (_activeTab >= tabsCount) {
      activeIndex = tabsCount - 1;
    } else if (_activeTab < 0) {
      activeIndex = 0;
    } else {
      activeIndex = _activeTab;
    }

    return Container(
      key: _tablesSectionKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header actions: currency only. Tabs removed per request.
        Row(children: [
          const Spacer(),
          _currencyDropdown(),
        ]),
        const SizedBox(height: 12),
        if (tabsCount > 0) ...[
          for (int i = 0; i < tabsCount; i++) ...[
            const SizedBox(height: 12),
            Text(_solutionTitle(i),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _tableForIndex(i, isMobile: isMobile, horizonLabel: horizonLabel),
          ]
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: const Text(
                'Add a solution to unlock the ROI and NPV breakdown.'),
          ),
        ],
      ]),
    );
  }

  Widget _errorBanner(String message, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (onRetry != null)
          TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(fontSize: 12))),
      ]),
    );
  }

  String _formatCurrencyValue(double value) {
    final prefix = value < 0 ? '-' : '';
    final formatted = _formatNumber(value.abs());
    return '$prefix$_currency $formatted';
  }

  String _formatNumber(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (abs >= 1000) {
      return _formatWithGrouping(value, 0);
    }
    return _formatWithGrouping(value, 2);
  }

  String _formatWithGrouping(double value, int decimals) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    final fixed = abs.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final reverseIndex = intPart.length - i - 1;
      buffer.write(intPart[i]);
      if (reverseIndex % 3 == 0 && i != intPart.length - 1) buffer.write(',');
    }
    final decimalPart = decimals > 0 ? '.${parts[1]}' : '';
    return '$sign$buffer$decimalPart';
  }

  String _formatPercentValue(double value) {
    if (!value.isFinite) return '0.0%';
    return '${value.toStringAsFixed(1)}%';
  }

  double _currencyFactor(String from, String to) {
    if (!_currencyRates.containsKey(from) || !_currencyRates.containsKey(to)) {
      return 1.0;
    }
    final fromRate = _currencyRates[from] ?? 1.0;
    final toRate = _currencyRates[to] ?? 1.0;
    if (fromRate <= 0) return 1.0;
    return toRate / fromRate;
  }

  void _applyCurrencyConversion(double factor) {
    if (factor == 1.0) return;
    final wasSuppressed = _suppressDirtyTracking;
    _suppressDirtyTracking = true;
    // Project value baseline for every solution.
    for (int i = 0; i < _projectValueAmountBySolution.length; i++) {
      final pv = _projectValueAmountBySolution[i].trim();
      if (pv.isEmpty) continue;
      final n = _parseCurrencyInput(pv) * factor;
      _projectValueAmountBySolution[i] = n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
    }
    _loadProjectValueEditorsForSolution(_activeSolutionIndex());
    // Project benefits (unit values only)
    for (final entry in _allBenefitLineItems) {
      final uv =
          _BenefitLineItemEntry._readDouble(entry.unitValueController.text) *
              factor;
      entry.unitValueController.text = uv.toStringAsFixed(uv % 1 == 0 ? 0 : 2);
    }
    // Category estimate costs
    for (final map in _categoryCostsPerSolution) {
      for (final entry in map.values) {
        final txt = entry.costController.text.trim();
        if (txt.isEmpty) continue;
        final n = _parseCurrencyInput(txt) * factor;
        entry.costController.text = n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
      }
    }
    // Detailed line items and baselines
    for (final list in _rowsPerSolution) {
      for (final row in list) {
        row.convertCurrency(factor);
      }
    }
    _suppressDirtyTracking = wasSuppressed;
  }

  double _solutionTotalCost(int index) {
    if (index >= _rowsPerSolution.length) return 0;
    return _rowsPerSolution[index]
        .fold<double>(0, (sum, row) => sum + row.currentCost());
  }

  double _solutionTotalNpv(int index) {
    if (index >= _rowsPerSolution.length) return 0;
    return _rowsPerSolution[index]
        .fold<double>(0, (sum, row) => sum + row.currentNpv());
  }

  double _solutionAverageRoi(int index) {
    if (index >= _rowsPerSolution.length) return 0;
    double total = 0;
    int count = 0;
    for (final row in _rowsPerSolution[index]) {
      final roi = row.currentRoi();
      final hasData = row.currentCost() > 0 || roi != 0;
      if (roi.isFinite && hasData) {
        total += roi;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  int _solutionItemCount(int index) {
    if (index >= _rowsPerSolution.length) return 0;
    int count = 0;
    for (final row in _rowsPerSolution[index]) {
      final hasName = row.itemController.text.trim().isNotEmpty &&
          row.itemController.text.trim() != 'Name';
      final hasCost = row.currentCost() > 0;
      if (hasName || hasCost) count++;
    }
    return count;
  }

  String _buildCostContextNotes({int? forSolution}) {
    final buffer = StringBuffer();

    // Get project data from provider
    final provider = ProjectDataInherited.maybeOf(context);
    final projectData = provider?.projectData;

    // Add Business Case context
    if (projectData != null) {
      if (projectData.businessCase.isNotEmpty) {
        buffer.write('Business Case: ${projectData.businessCase}. ');
      }

      // Add Solution Title and Description
      if (projectData.solutionTitle.isNotEmpty) {
        buffer.write('Project: ${projectData.solutionTitle}. ');
      }
      if (projectData.solutionDescription.isNotEmpty) {
        buffer.write('Description: ${projectData.solutionDescription}. ');
      }

      // Add Project Objective
      if (projectData.projectObjective.isNotEmpty) {
        buffer.write('Objective: ${projectData.projectObjective}. ');
      }

      // Add Work Breakdown Structure items as potential cost categories
      final wbsItems = <String>[];
      for (final goalWorkList in projectData.goalWorkItems) {
        for (final workItem in goalWorkList) {
          if (workItem.description.isNotEmpty) {
            wbsItems.add(workItem.description);
          }
        }
      }
      if (wbsItems.isNotEmpty) {
        buffer.write('Work breakdown items: ${wbsItems.take(15).join(', ')}. ');
      }

      // Add Risks that might require mitigation costs
      final risks = <String>[];
      for (final solutionRisk in projectData.solutionRisks) {
        for (final risk in solutionRisk.risks) {
          if (risk.isNotEmpty) {
            risks.add('${solutionRisk.solutionTitle}: $risk');
          }
        }
      }
      if (risks.isNotEmpty) {
        buffer.write(
            'Risk considerations (may require mitigation costs): ${risks.take(10).join('; ')}. ');
      }

      // Add IT Considerations
      if (projectData.itConsiderationsData != null) {
        final itData = projectData.itConsiderationsData!;
        if (itData.notes.isNotEmpty) {
          buffer.write('IT considerations: ${itData.notes}. ');
        }
        for (final solutionIT in itData.solutionITData) {
          if (solutionIT.coreTechnology.isNotEmpty) {
            buffer.write(
                'Technology for ${solutionIT.solutionTitle}: ${solutionIT.coreTechnology}. ');
          }
        }
      }

      // Add Infrastructure Considerations
      if (projectData.infrastructureConsiderationsData != null) {
        final infraData = projectData.infrastructureConsiderationsData!;
        if (infraData.notes.isNotEmpty) {
          buffer.write('Infrastructure considerations: ${infraData.notes}. ');
        }
        for (final solutionInfra in infraData.solutionInfrastructureData) {
          if (solutionInfra.majorInfrastructure.isNotEmpty) {
            buffer.write(
                'Infrastructure for ${solutionInfra.solutionTitle}: ${solutionInfra.majorInfrastructure}. ');
          }
        }
      }

      // Add Core Stakeholders (external stakeholders may have associated costs)
      if (projectData.coreStakeholdersData != null) {
        final stakeholderData = projectData.coreStakeholdersData!;
        if (stakeholderData.notes.isNotEmpty) {
          buffer.write('Stakeholder notes: ${stakeholderData.notes}. ');
        }
        for (final solutionStakeholder
            in stakeholderData.solutionStakeholderData) {
          if (solutionStakeholder.notableStakeholders.isNotEmpty) {
            buffer.write(
                'Stakeholders for ${solutionStakeholder.solutionTitle}: ${solutionStakeholder.notableStakeholders}. ');
          }
        }
      }

      // Add Team Members (personnel costs)
      if (projectData.teamMembers.isNotEmpty) {
        final teamRoles = projectData.teamMembers
            .map((m) => m.role.isEmpty ? m.name : m.role)
            .where((r) => r.isNotEmpty)
            .toList();
        if (teamRoles.isNotEmpty) {
          buffer.write('Team composition: ${teamRoles.take(15).join(', ')}. ');
        }
      }

      // Add Front End Planning data
      final fepData = projectData.frontEndPlanning;
      final fepNotes = <String>[];
      if (fepData.requirements.isNotEmpty) {
        fepNotes.add('Requirements: ${fepData.requirements}');
      }
      if (fepData.risks.isNotEmpty) {
        fepNotes.add('Planning risks: ${fepData.risks}');
      }
      if (fepData.opportunities.isNotEmpty) {
        fepNotes.add('Opportunities: ${fepData.opportunities}');
      }
      if (fepData.technology.isNotEmpty) {
        fepNotes.add('Technology: ${fepData.technology}');
      }
      if (fepData.infrastructure.isNotEmpty) {
        fepNotes.add('Infrastructure: ${fepData.infrastructure}');
      }
      if (fepData.contracts.isNotEmpty) {
        fepNotes.add('Contracts: ${fepData.contracts}');
      }
      if (fepData.procurement.isNotEmpty) {
        fepNotes.add('Procurement: ${fepData.procurement}');
      }
      if (fepNotes.isNotEmpty) {
        buffer.write('Front-end planning: ${fepNotes.take(5).join('; ')}. ');
      }
    }

    // Add current cost analysis notes
    final projectValueIndexes = <int>[];
    if (forSolution != null) {
      if (forSolution >= 0 &&
          forSolution < _projectValueAmountBySolution.length) {
        projectValueIndexes.add(forSolution);
      }
    } else {
      for (int i = 0; i < _projectValueAmountBySolution.length; i++) {
        projectValueIndexes.add(i);
      }
    }

    for (final idx in projectValueIndexes) {
      final amount = _projectValueAmountBySolution[idx].trim();
      if (amount.isNotEmpty) {
        buffer.write(
            'Project value baseline for "${_solutionTitle(idx)}": $amount $_currency. ');
      }
      final benefitSnippets = <String>[];
      final benefitMap = _projectValueBenefitsBySolution[idx];
      for (final field in _projectValueFields) {
        final benefit = benefitMap[field.key]?.trim() ?? '';
        if (benefit.isNotEmpty) {
          benefitSnippets.add('${field.value}: $benefit');
        }
      }
      if (benefitSnippets.isNotEmpty) {
        buffer.write(
            'Project benefits for "${_solutionTitle(idx)}": ${benefitSnippets.join(' | ')}. ');
      }
    }

    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      buffer.write('Analyst notes: $notes. ');
    }

    // Add solution-specific context
    final indexes = <int>[];
    if (forSolution != null) {
      if (forSolution >= 0 &&
          forSolution < _solutionContexts.length &&
          forSolution < widget.solutions.length) {
        indexes.add(forSolution);
      }
    } else {
      for (int i = 0;
          i < widget.solutions.length && i < _solutionContexts.length;
          i++) {
        indexes.add(i);
      }
    }
    for (final idx in indexes) {
      final context = _contextFor(idx);
      final resource = _resourceOptions[
          _boundedIndex(context.resourceIndex, _resourceOptions.length)];
      final timeline = _timelineOptions[
          _boundedIndex(context.timelineIndex, _timelineOptions.length)];
      final complexity = _complexityOptions[
          _boundedIndex(context.complexityIndex, _complexityOptions.length)];
      final solutionTitle = _solutionTitle(idx);
      buffer.write(
          ' Solution "$solutionTitle": ${resource.aiHint} ${timeline.aiHint} ${complexity.aiHint}');
      final narrative = context.justificationController.text.trim();
      if (narrative.isNotEmpty) {
        buffer.write(' Cost drivers: $narrative');
      }
      buffer.write('.');
    }
    return buffer.toString().trim();
  }

  // Treat these five benefit pillar labels as non-items so they never appear
  // under the 'Item' column in Initial cost estimate.
  bool _isProjectValueCategoryLabel(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    for (final entry in _projectValueFields) {
      if (entry.value.toLowerCase() == t) return true;
    }
    return false;
  }

  bool _containsTerm(String source, String term) {
    final normalizedSource = source.toLowerCase();
    final normalizedTerm = term.toLowerCase().trim();
    if (normalizedTerm.isEmpty) return false;
    if (normalizedTerm.contains(' ')) {
      return normalizedSource.contains(normalizedTerm);
    }
    return RegExp('\\b${RegExp.escape(normalizedTerm)}\\b')
        .hasMatch(normalizedSource);
  }

  bool _containsAnyTerm(String source, List<String> terms) {
    for (final term in terms) {
      if (_containsTerm(source, term)) return true;
    }
    return false;
  }

  bool _solutionLikelyPhysical(int index) {
    final solution = _solutionAt(index);
    final source =
        '${solution?.title ?? ''} ${solution?.description ?? ''}'.toLowerCase();
    final hasPhysicalCue = _containsAnyTerm(source, const [
      'construction',
      'building',
      'facility',
      'fire station',
      'infrastructure',
      'civil works',
      'site',
      'foundation',
      'procurement',
      'commissioning',
      'contractor',
      'modular',
    ]);
    final hasDigitalCue = _containsAnyTerm(source, const [
      'software',
      'application',
      'platform',
      'api',
      'mobile',
      'web portal',
      'cloud',
      'devops',
      'database',
      'data pipeline',
      'sprint',
      'mvp',
    ]);
    return hasPhysicalCue && !hasDigitalCue;
  }

  bool _isSoftwareLifecycleCostItem(String text) {
    final normalized = text.toLowerCase();
    return _containsAnyTerm(normalized, const [
      'discovery and planning',
      'discovery & planning',
      'mvp build',
      'integration & data',
      'integration and data',
      'sprint',
      'backlog',
      'user story',
      'api integration',
      'data migration',
      'release pipeline',
      'devops',
      'qa automation',
    ]);
  }

  List<AiCostItem> _physicalFallbackCostItems(int solutionIndex) {
    const templates = [
      (
        item: 'Site survey and feasibility studies',
        description:
            'Topographic surveys, engineering feasibility, and early design validation.',
        cost: 48200.0,
        roi: 10.5
      ),
      (
        item: 'Permitting and regulatory approvals',
        description:
            'Permit submissions, inspections, and statutory compliance documentation.',
        cost: 36500.0,
        roi: 9.2
      ),
      (
        item: 'Detailed engineering and technical drawings',
        description:
            'Final design packages, safety calculations, and construction-ready drawings.',
        cost: 72400.0,
        roi: 11.8
      ),
      (
        item: 'Materials and equipment procurement',
        description:
            'Purchase of long-lead materials, core equipment, and logistics handling.',
        cost: 156800.0,
        roi: 14.6
      ),
      (
        item: 'Civil works and installation',
        description:
            'Ground works, structural installation, electrical/mechanical fit-out, and supervision.',
        cost: 218500.0,
        roi: 16.3
      ),
    ];

    final indexScale = 1 + (solutionIndex * 0.08);
    return List<AiCostItem>.generate(templates.length, (i) {
      final template = templates[i];
      final scaledCost =
          (template.cost * indexScale * (1 + (i * 0.02))).roundToDouble();
      final roi = template.roi + ((solutionIndex - 1) * 0.4);
      final annualGain = scaledCost * (roi / 100);
      final npvByYear = <int, double>{
        3: (annualGain * 1.9) - (scaledCost * 0.12),
        5: (annualGain * 3.1) - (scaledCost * 0.18),
        10: (annualGain * 5.8) - (scaledCost * 0.25),
      };

      return AiCostItem(
        item: template.item,
        description: template.description,
        estimatedCost: scaledCost,
        roiPercent: roi,
        npvByYear: npvByYear,
      );
    });
  }

  void _applyCostItemsToRows(int index, List<AiCostItem> items) {
    if (index < 0 || index >= _rowsPerSolution.length) return;
    final enforcePhysical = _solutionLikelyPhysical(index);
    // Ensure we only place true cost items, not generic benefit pillar labels
    List<AiCostItem> filtered = items.where((it) {
      if (_isProjectValueCategoryLabel(it.item)) return false;
      if (enforcePhysical &&
          _isSoftwareLifecycleCostItem('${it.item} ${it.description}')) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (enforcePhysical && filtered.isEmpty && items.isNotEmpty) {
      filtered = _physicalFallbackCostItems(index);
    }

    // Ensure capacity up to number of items (cap at 20 for usability)
    final targetLen = filtered.length.clamp(0, 20);
    while (_rowsPerSolution[index].length < targetLen) {
      final newRow = _CostRow(currencyProvider: () => _currency);
      _attachRowDirtyListeners(newRow);
      _rowsPerSolution[index].add(newRow);
    }
    final rows = _rowsPerSolution[index];
    for (int j = 0; j < rows.length; j++) {
      final row = rows[j];
      if (j < targetLen) {
        final it = filtered[j];
        row.itemController.text = it.item.isEmpty ? 'Name' : it.item;
        row.descriptionController.text = it.description.isEmpty
            ? 'Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum...'
            : it.description;
        row.applyBaseline(
            cost: it.estimatedCost,
            roiPercent: it.roiPercent,
            npvByYears: it.npvByYear);
        row.setHorizon(_npvHorizon);
      } else if (filtered.isNotEmpty) {
        row.applyBaseline(
            cost: 0,
            roiPercent: 0,
            npvByYears: const {3: 0.0, 5: 0.0, 10: 0.0});
        row.setHorizon(_npvHorizon);
      }
    }
    _refreshJustificationFor(index, force: true);
  }

  // Categorize a cost item into a Project Value category using simple keyword heuristics
  String _categoryForItem(AiCostItem it) {
    final text = ('${it.item} ${it.description}').toLowerCase();
    bool hasAny(List<String> keys) => keys.any((k) => text.contains(k));
    if (hasAny([
      'revenue',
      'sales',
      'uplift',
      'growth',
      'gross margin',
      'pricing',
      'income'
    ])) {
      return 'revenue';
    }
    if (hasAny(['saving', 'cost avoid', 'not buying', 'reduction'])) {
      return 'cost_saving';
    }
    if (hasAny([
      'efficien',
      'automation',
      'cycle',
      'throughput',
      'waste',
      'rework',
      'opex',
      'maintenance',
      'operational'
    ])) {
      return 'ops_efficiency';
    }
    if (hasAny([
      'manpower',
      'hours',
      'salary',
      'time sav',
      'productive',
      'headcount'
    ])) {
      return 'productivity';
    }
    if (hasAny([
      'regulator',
      'compliance',
      'audit',
      'gdpr',
      'hipaa',
      'sox',
      'policy',
      'penalty'
    ])) {
      return 'regulatory_compliance';
    }
    if (hasAny([
      'process',
      'workflow',
      'time-to-market',
      'quality',
      'error',
      'improvement'
    ])) {
      return 'process_improvement';
    }
    if (hasAny(
        ['brand', 'reputation', 'marketing', 'nps', 'image', 'perception'])) {
      return 'brand_image';
    }
    if (hasAny(['stakeholder', 'shareholder', 'commitment', 'investor'])) {
      return 'stakeholder_commitment';
    }
    return 'other';
  }

  void _applyCategoryEstimatesFromItems(
      int solutionIndex, List<AiCostItem> items) {
    if (solutionIndex < 0 ||
        solutionIndex >= _categoryCostsPerSolution.length) {
      return;
    }
    final map = _categoryCostsPerSolution[solutionIndex];
    // reset existing estimates only if empty to not clobber user edits
    final totals = <String, double>{
      for (final f in _projectValueFields) f.key: 0
    };
    final notes = <String, List<String>>{
      for (final f in _projectValueFields) f.key: []
    };
    final ideas = _categoryIdeasPerSolution[solutionIndex];
    // clear and repopulate ideas
    for (final k in ideas.keys.toList()) {
      ideas[k] = [];
    }
    for (final it in items) {
      final key = _categoryForItem(it);
      totals[key] = (totals[key] ?? 0) +
          (it.estimatedCost.isFinite ? it.estimatedCost : 0);
      notes[key] = [...(notes[key] ?? const []), it.item];
      ideas[key] = [...(ideas[key] ?? const []), it];
    }
    // apply into controllers if their fields are blank or numeric zero
    for (final entry in map.entries) {
      final key = entry.key;
      final costCtrl = entry.value.costController;
      final noteCtrl = entry.value.notesController;
      final hasUserCost = (costCtrl.text.trim().isNotEmpty) &&
          (_parseCurrencyInput(costCtrl.text.trim()) > 0);
      final hasUserNotes = noteCtrl.text.trim().isNotEmpty;
      final t = (totals[key] ?? 0);
      if (!hasUserCost && t > 0) {
        costCtrl.text = t.toStringAsFixed(t % 1 == 0 ? 0 : 2);
      }
    }
    setState(() {});
  }

  Future<void> _populateCategoriesFromAi({int? targetSolution}) async {
    if (_isGenerating) return;
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final scopedSolutions = targetSolution == null
          ? widget.solutions
          : <AiSolutionItem>[
              if (_solutionAt(targetSolution) != null)
                _solutionAt(targetSolution)!,
            ];
      final map = await _openAi.generateCostBreakdownForSolutions(
        scopedSolutions,
        contextNotes: _buildUnifiedAiContext(
          sectionLabel: 'Cost Benefit Analysis - Initial Cost Estimate',
          forSolution: targetSolution,
        ),
        currency: _currency,
      );
      if (!mounted) return;
      if (targetSolution != null) {
        final sol = _solutionAt(targetSolution);
        if (sol != null) {
          final items = map[sol.title] ?? <AiCostItem>[];
          setState(() {
            _applyCostItemsToRows(targetSolution, items);
            _applyCategoryEstimatesFromItems(targetSolution, items);
          });
        }
      } else {
        for (int i = 0;
            i < _rowsPerSolution.length && i < widget.solutions.length;
            i++) {
          final title = widget.solutions[i].title;
          final items = map[title] ?? <AiCostItem>[];
          _applyCostItemsToRows(i, items);
          _applyCategoryEstimatesFromItems(i, items);
        }
        if (mounted) setState(() {});
      }
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
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _applyIdeaToCategory(
      int solutionIndex, String categoryKey, AiCostItem item) {
    if (solutionIndex < 0 || solutionIndex >= _rowsPerSolution.length) return;
    // Ignore generic benefit pillar labels as cost items
    if (_isProjectValueCategoryLabel(item.item)) return;
    // Add to Step 3 breakdown as a new row with baseline derived from AI
    final row = _CostRow(currencyProvider: () => _currency);
    _attachRowDirtyListeners(row);
    row.itemController.text = item.item.isEmpty ? 'Name' : item.item;
    row.descriptionController.text = item.description.isEmpty
        ? 'Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum...'
        : item.description;
    row.applyBaseline(
        cost: item.estimatedCost,
        roiPercent: item.roiPercent,
        npvByYears: item.npvByYear);
    row.setHorizon(_npvHorizon);
    setState(() {
      _rowsPerSolution[solutionIndex].add(row);
    });
    // Also append to category notes and sum cost into the category estimate field
    final entry = _categoryCostsPerSolution[solutionIndex][categoryKey];
    if (entry != null) {
      final existing = entry.notesController.text.trim();
      final bullet = item.item.trim();
      final sep = existing.isEmpty ? '' : '\n';
      entry.notesController.text = '$existing$sep$kListBullet$bullet';
      final cur = _parseCurrencyInput(entry.costController.text.trim());
      final add = item.estimatedCost.isFinite ? item.estimatedCost : 0;
      final next = (cur + add);
      if (next > 0) {
        entry.costController.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 2);
      }
    }
    _markDirty();
  }

  Widget _tabButton(
      {required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFFFFD700) : Colors.grey[200],
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  Widget _currencyDropdown() {
    final availableCurrencies = _currencyRates.keys.toSet();
    final selectedCurrency =
        availableCurrencies.contains(_currency) ? _currency : 'USD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.35))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCurrency,
          items: _currencyRates.keys
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            final selected = v ?? 'USD';
            final factor = _currencyFactor(_lastCurrency, selected);
            setState(() {
              _currency = selected;
              _applyCurrencyConversion(factor);
              _lastCurrency = selected;
            });
            _markDirty();
            final provider = ProjectDataHelper.getProvider(context);
            provider.updateCostBenefitCurrency(selected);
          },
        ),
      ),
    );
  }

  Widget _tableForIndex(int index,
      {required bool isMobile, required String horizonLabel}) {
    final rows = _rowsPerSolution[index];
    if (isMobile) {
      return Column(
          children: rows.map((r) => _mobileCard(r, horizonLabel)).toList());
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.withOpacity(0.35))),
        child: Row(children: [
          const Expanded(
              flex: 2,
              child: Text('Potential Solution',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          const Expanded(
              flex: 5,
              child: Text('Description',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          const Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Return On Investment',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: Text('Net Present Value ($horizonLabel)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.center,
                  child: Text('Estimated Cost',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 16),
          const Expanded(
              flex: 3,
              child: Text('Comments',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.withOpacity(0.35))),
        child: Column(children: rows.map((r) => _tableRow(r)).toList()),
      ),
    ]);
  }

  Widget _tableRow(_CostRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Colors.grey.withOpacity(0.25)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: ExpandingTextField(
            controller: row.itemController,
            decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Name'),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            minLines: 1,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: ExpandingTextField(
            controller: row.descriptionController,
            decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Lorem ipsum ...'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            minLines: 1,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: VoiceTextField(
              controller: row.roiController,
              textAlign: TextAlign.right,
              readOnly: true,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0%'),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: VoiceTextField(
              controller: row.npvController,
              textAlign: TextAlign.right,
              readOnly: true,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0.00'),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: VoiceTextField(
              controller: row.costController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0.00'),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: ExpandingTextField(
            controller: row.assumptionsController,
            minLines: 1,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Assumptions or notes',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ]),
    );
  }

  Widget _mobileCard(_CostRow row, String horizonLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Potential Solution',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ExpandingTextField(
            controller: row.itemController,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, hintText: 'Name'),
            minLines: 1),
        const SizedBox(height: 10),
        const Text('Description',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ExpandingTextField(
            controller: row.descriptionController,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'Lorem ipsum...'),
            minLines: 2),
        const SizedBox(height: 10),
        const Text('Return On Investment',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        VoiceTextField(
            controller: row.roiController,
            readOnly: true,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, hintText: '0%')),
        const SizedBox(height: 10),
        Text('Net Present Value ($horizonLabel)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        VoiceTextField(
            controller: row.npvController,
            readOnly: true,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, hintText: '0.00')),
        const SizedBox(height: 10),
        const Text('Estimated Cost',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        VoiceTextField(
            controller: row.costController,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, hintText: '0.00')),
        const SizedBox(height: 10),
        const Text('Comments',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ExpandingTextField(
          controller: row.assumptionsController,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'Assumptions or notes'),
          minLines: 2,
        ),
      ]),
    );
  }

  Widget _buildPhaseNavigation() {
    final phases = [
      'Initiation Phase',
      'Initiation: Front End Planning',
      'Workflow Roadmap',
      'Agile Roadmap',
      'Contracting',
      'Procurement'
    ];
    return Container(
      height: 80,
      color: Colors.white,
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          onPressed: () {
            _handleBackNavigation();
          },
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: phases.length,
            itemBuilder: (context, index) {
              final isActive = index == 0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                    color:
                        isActive ? const Color(0xFFFFD700) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20)),
                child: Center(
                  child: Text(
                    phases[index],
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? Colors.black : Colors.grey[600]),
                  ),
                ),
              );
            },
          ),
        ),
        IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {}),
      ]),
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _mainScrollController.dispose();
    _benefitTableHorizontalController.dispose();
    _benefitTableRowsVerticalController.dispose();
    _initialCostTableHorizontalController.dispose();
    _notesController.removeListener(_markDirty);
    _notesController.dispose();
    _projectValueAmountController.removeListener(_onProjectValueFieldChanged);
    _projectValueAmountController.dispose();
    for (final controller in _projectValueBenefitControllers.values) {
      controller.removeListener(_onProjectValueFieldChanged);
      controller.dispose();
    }
    _benefitCategoryTabController.dispose();
    for (final context in _solutionContexts) {
      context.justificationController.removeListener(_markDirty);
      context.dispose();
    }
    for (final list in _rowsPerSolution) {
      for (final r in list) {
        r.dispose();
      }
    }
    for (final map in _categoryCostsPerSolution) {
      for (final entry in map.values) {
        entry.dispose();
      }
    }
    for (final entry in _allBenefitLineItems) {
      entry.dispose();
    }
    _savingsNotesController.removeListener(_onSavingsContextChanged);
    _savingsNotesController.dispose();
    _savingsTargetController.removeListener(_onSavingsContextChanged);
    _savingsTargetController.dispose();
    super.dispose();
  }

  Future<void> _generateSavingsSuggestions({bool showFeedback = true}) async {
    if (_isSavingsGenerating) return;
    final activeIndex = _activeSolutionIndex();
    final eligible = _benefitLineItems
        .where((entry) => entry.totalValue > 0 && entry.title.isNotEmpty)
        .toList();
    if (eligible.isEmpty) {
      setState(() {
        _savingsError =
            'Add at least one benefit with unit value and units before generating savings scenarios.';
        _clearSavingsSuggestionsForSolution(activeIndex);
      });
      return;
    }

    double? parsePercent(String value) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
      final parsed = double.tryParse(sanitized);
      if (parsed == null || parsed <= 0) return null;
      return parsed;
    }

    final targetPercent = parsePercent(_savingsTargetController.text.trim());

    if (!mounted) return;
    setState(() {
      _isSavingsGenerating = true;
      _savingsError = null;
    });

    try {
      final payload = eligible.map((entry) => entry.toPayload()).toList();
      final contextNotes = _buildUnifiedAiContext(
        sectionLabel: 'Cost Benefit Analysis - Savings Calculator',
        forSolution: _activeSolutionIndex(),
      );
      final userSavingsNotes = _savingsNotesController.text.trim();
      final suggestions = await _openAi.generateBenefitSavingsSuggestions(
        payload,
        currency: _currency,
        savingsTargetPercent: targetPercent,
        contextNotes: userSavingsNotes.isEmpty
            ? contextNotes
            : '$contextNotes\n\nSavings focus notes: $userSavingsNotes',
      );
      if (!mounted) return;
      setState(() {
        _savingsSuggestionsBySolution[activeIndex] = suggestions;
        _savingsContextHashesBySolution[activeIndex] =
            _savingsContextHashForSolution(activeIndex);
      });
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Savings scenarios updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingsError = e.toString();
        _clearSavingsSuggestionsForSolution(activeIndex);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingsGenerating = false;
        });
      } else {
        _isSavingsGenerating = false;
      }
    }
  }

  Future<void> _generateProjectValue({
    int? solutionIndex,
    bool showFeedback = true,
    bool persist = true,
  }) async {
    if (_isGeneratingValue) return;
    final targetIndex = solutionIndex ?? _activeSolutionIndex();
    final scopedSolution = _solutionAt(targetIndex);
    final scopedSolutions = scopedSolution == null
        ? widget.solutions
        : <AiSolutionItem>[scopedSolution];
    if (!mounted) return;
    setState(() {
      _isGeneratingValue = true;
      _projectValueError = null;
    });
    try {
      final provider = ProjectDataHelper.getProvider(context);
      final contextNotes = _buildUnifiedAiContext(
        sectionLabel: 'Cost Benefit Analysis - Project Benefit Calculation',
        forSolution: targetIndex,
      );

      // Add current values to history before regenerating
      provider.addFieldToHistory('project_value_amount_$targetIndex',
          _projectValueAmountBySolution[targetIndex],
          isAiGenerated: true);
      for (final field in _projectValueFields) {
        provider.addFieldToHistory(
          'project_value_${field.key}_$targetIndex',
          _projectValueBenefitsBySolution[targetIndex][field.key] ?? '',
          isAiGenerated: true,
        );
      }

      final insights = await _openAi.generateProjectValueInsights(
        scopedSolutions,
        contextNotes: contextNotes,
      );
      if (!mounted) return;

      // Generate project benefits with numeric values
      List<BenefitLineItemInput> benefitLineItems = [];
      if (insights.estimatedProjectValue > 0) {
        try {
          benefitLineItems = await _openAi.generateBenefitLineItems(
            solutions: scopedSolutions,
            estimatedProjectValue: insights.estimatedProjectValue,
            contextNotes: contextNotes,
            currency: _currency,
          );
        } catch (e) {
          debugPrint('Error generating project benefits: $e');
          // Continue with project value even if project benefits fail
        }
      }

      if (!mounted) return;
      final normalizedBenefits =
          _normalizeProjectValueBenefitEntries(insights.benefits);
      setState(() {
        if (insights.estimatedProjectValue > 0) {
          _projectValueAmountBySolution[targetIndex] =
              insights.estimatedProjectValue.toStringAsFixed(0);
        }
        _projectValueBenefitsBySolution[targetIndex] = normalizedBenefits;

        // Clear existing project benefits and add generated ones
        for (final entry in _benefitItemsForSolution(targetIndex)) {
          entry.unbind();
          WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
        }
        _benefitItemsForSolution(targetIndex).clear();

        // Add generated project benefits
        final baseTimestamp = DateTime.now().microsecondsSinceEpoch;
        for (int i = 0; i < benefitLineItems.length; i++) {
          final item = benefitLineItems[i];
          final entry = _BenefitLineItemEntry(
            id: 'benefit-$baseTimestamp-$i',
            categoryKey: _normalizeBenefitCategoryKey(item.category),
            title: item.title,
            unitValue: item.unitValue,
            units: item.units,
            notes: item.notes,
          );
          entry.bind(_onBenefitEntryEdited);
          _benefitItemsForSolution(targetIndex).add(entry);
        }
        _projectValueContextHashesBySolution[targetIndex] =
            _projectValueContextHashForSolution(targetIndex);
        _clearSavingsSuggestionsForSolution(targetIndex);
      });
      if (targetIndex == _activeSolutionIndex()) {
        _syncingProjectValueEditors = true;
        _loadProjectValueEditorsForSolution(targetIndex);
        _syncingProjectValueEditors = false;
      }

      if (persist) {
        await _saveCostAnalysisData();
        await provider.saveToFirebase(checkpoint: 'cost_analysis_regenerated');
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Project value regenerated successfully')),
        );
      }

      _markDirty();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectValueError = e.toString();
      });
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate project value: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingValue = false;
        });
      } else {
        _isGeneratingValue = false;
      }
    }
  }

  Future<double?> _estimateBenefitUnitValue({
    required String title,
    required String categoryKey,
    required String notes,
    required String unitsText,
    required String baselineValue,
    required int solutionIndex,
    String? excludeEntryId,
  }) async {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) return null;

      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a benefit title first')),
        );
        return null;
      }

      final solutionLabel = _solutionTitle(solutionIndex);
      final categoryLabel = _benefitCategoryLabel(categoryKey);
      final baselineNumeric = _parseCurrencyInput(baselineValue);
      final unitsValue = _parseCurrencyInput(unitsText);
      final otherRows = _benefitItemsForSolution(solutionIndex)
          .where((row) => row.id != excludeEntryId);
      final peerValues = otherRows
          .map((row) => _parseCurrencyInput(row.unitValueController.text))
          .where((value) => value > 0)
          .toList(growable: false);
      final peerAverage = peerValues.isEmpty
          ? 0.0
          : peerValues.reduce((a, b) => a + b) / peerValues.length;
      final projectContext = ProjectDataHelper.buildFepContext(
        provider.projectData,
      );
      final contextBuffer = StringBuffer()
        ..writeln('Solution: $solutionLabel')
        ..writeln('Benefit category: $categoryLabel')
        ..writeln('Benefit title: $title')
        ..writeln('Tracker basis: $_trackerBasisFrequency')
        ..writeln('Primary basis frequency: ${_basisFrequency ?? "Not set"}')
        ..writeln(
            'Units for this line item: ${unitsValue <= 0 ? "Not set" : unitsValue}')
        ..writeln(
            'Current project benefit value baseline ($_currency): ${baselineValue.isEmpty ? "Not set" : baselineValue}')
        ..writeln(
            'Average unit value of other benefit rows ($_currency): ${peerAverage <= 0 ? "Not available" : peerAverage.toStringAsFixed(2)}')
        ..writeln('Project context: $projectContext')
        ..writeln(
            'Cost context: ${_buildUnifiedAiContext(sectionLabel: "Cost Benefit Analysis - Unit Value Suggestion", forSolution: solutionIndex)}')
        ..writeln(
            'Unit value mode: Return unit value only, not aggregate total.');
      if (notes.isNotEmpty) {
        contextBuffer.writeln('Benefit notes: $notes');
      }

      final suggestedValue = await _openAi.estimateCostForItem(
        itemName: title,
        description:
            'Project benefit category: $categoryLabel. Estimate the unit value for a single unit.',
        assumptions: notes,
        contextNotes: contextBuffer.toString(),
        currency: _currency,
        estimationMode: 'benefit_unit_value',
        basisFrequency: _trackerBasisFrequency,
      );

      if (!mounted) return null;
      if (_looksLikePlaceholderUnitValue(suggestedValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI suggestion looked generic. Add more assumptions or units and try again.',
            ),
          ),
        );
        return null;
      }

      final annualMultiplier = _trackerBasisFrequency == 'Monthly'
          ? 12.0
          : (_trackerBasisFrequency == 'Quarterly' ? 4.0 : 1.0);
      final projectedTotal = unitsValue > 0 ? suggestedValue * unitsValue : 0.0;
      if (baselineNumeric > 0 &&
          projectedTotal > 0 &&
          (projectedTotal * annualMultiplier) > (baselineNumeric * 3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI suggestion exceeded context limits. Add clearer assumptions and retry.',
            ),
          ),
        );
        return null;
      }

      if (suggestedValue > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI suggested unit value: ${_formatCurrencyValue(suggestedValue)}',
            ),
          ),
        );
        return suggestedValue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI could not produce a confident unit value for this item yet.',
          ),
        ),
      );
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate suggestion: ${e.toString()}'),
          ),
        );
      }
      return null;
    }
  }

  bool _looksLikePlaceholderUnitValue(double value) {
    if (!value.isFinite || value <= 0) return false;
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() > 0.01) return false;
    final intValue = rounded.toInt().abs();
    if (intValue < 50000) return false;
    return intValue % 50000 == 0 ||
        intValue == 250000 ||
        intValue == 500000 ||
        intValue == 1000000;
  }

  /// Derive resource (FTE band) and complexity indices from AI-generated cost items.
  /// Instead of defaulting all solutions to "Lean squad / 3-5 FTEs" and "Foundational"
  /// complexity, we infer both from the total cost magnitude and the number of
  /// distinct cost items returned by the AI.
  void _deriveAssumptionsFromCostItems(int index, List<AiCostItem> items) {
    if (index < 0 || items.isEmpty) return;
    final context = _contextFor(index);

    // ── Total cost magnitude ──
    double totalCost = 0;
    for (final item in items) {
      totalCost += item.estimatedCost;
    }

    // ── Derive resource (FTE band) index ──
    // _resourceOptions: 0=Lean squad (3-5), 1=Core programme (6-10), 2=Enterprise (10+)
    // Use total cost + item count as a proxy for team size
    int newResourceIndex;
    if (totalCost <= 0) {
      newResourceIndex = 0; // unknown → lean
    } else if (totalCost < 50000) {
      newResourceIndex = 0; // < $50k → lean squad (3-5 FTEs)
    } else if (totalCost < 250000) {
      newResourceIndex = 1; // $50k–$250k → core programme team (6-10 FTEs)
    } else {
      newResourceIndex = 2; // > $250k → enterprise delivery (10+ FTEs)
    }

    // ── Derive complexity index ──
    // _complexityOptions: 0=Foundational, 1=Moderate, 2=High
    // Use item count + cost as proxies: more line items / higher cost → more complex
    final itemCount = items.length;
    int newComplexityIndex;
    if (itemCount <= 3 && totalCost < 100000) {
      newComplexityIndex = 0; // Foundational
    } else if (itemCount <= 7 && totalCost < 500000) {
      newComplexityIndex = 1; // Moderate
    } else {
      newComplexityIndex = 2; // High
    }

    // Only update if the user hasn't manually overridden (autoGenerated flag)
    if (context.autoGenerated) {
      context.resourceIndex = newResourceIndex;
      context.complexityIndex = newComplexityIndex;
    }
  }

  Future<void> _generateCostBreakdownForSolution(
    int index, {
    bool showFeedback = true,
    bool persist = true,
  }) async {
    final solution = _solutionAt(index);
    if (solution == null || _solutionLoading.contains(index)) return;
    if (!mounted) return;
    setState(() {
      _solutionLoading.add(index);
      _error = null;
    });
    try {
      final map = await _openAi.generateCostBreakdownForSolutions(
        [solution],
        contextNotes: _buildUnifiedAiContext(
          sectionLabel: 'Cost Benefit Analysis - Initial Cost Estimate',
          forSolution: index,
        ),
        currency: _currency,
      );
      if (!mounted) return;
      final items = map[solution.title] ?? <AiCostItem>[];
      setState(() {
        // Apply detailed items to the editable rows
        _applyCostItemsToRows(index, items);
        // Also roll up into Project Value categories and surface ideas
        _applyCategoryEstimatesFromItems(index, items);
        // Derive resource (FTE band) + complexity per solution from cost items
        // so each solution card shows a customized snapshot instead of all
        // defaulting to "Lean squad / Foundational"
        _deriveAssumptionsFromCostItems(index, items);
        _costBreakdownContextHashesBySolution[index] =
            _costBreakdownContextHashForSolution(index);
        _solutionLoading.remove(index);
      });
      if (persist) {
        await _saveCostAnalysisData();
      }
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_solutionTitle(index)} cost breakdown updated'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = (e.toString().contains('Failed to fetch') ||
                e.toString().contains('ClientException') ||
                e.toString().contains('XMLHttpRequest') ||
                e.toString().contains('Connection refused'))
            ? 'AI assist is being set up. Please try again later or enter content manually.'
            : e.toString();
        _solutionLoading.remove(index);
      });
    }
  }

  Future<void> _generateCostBreakdown() async {
    if (_isGenerating) return;
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      for (int i = 0; i < _rowsPerSolution.length; i++) {
        await _generateCostBreakdownForSolution(
          i,
          showFeedback: false,
          persist: false,
        );
      }
      await _saveCostAnalysisData();
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      } else {
        _isGenerating = false;
      }
    }
  }

  Future<void> _regenerateAllCostAnalysis() async {
    // Regenerate all AI-derived sections to keep the page synchronized.
    for (int i = 0; i < _rowsPerSolution.length; i++) {
      await _generateProjectValue(
        solutionIndex: i,
        showFeedback: false,
        persist: false,
      );
      await _generateCostBreakdownForSolution(
        i,
        showFeedback: false,
        persist: false,
      );
      if (_benefitItemsForSolution(i).isNotEmpty) {
        final previousTab = _activeTab;
        if (previousTab != i) {
          _activeTab = i;
        }
        await _generateSavingsSuggestions(showFeedback: false);
        if (previousTab != i) {
          _activeTab = previousTab;
        }
      }
    }
    await _saveCostAnalysisData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cost analysis content regenerated')),
    );
  }
}

enum _EditorDialogMode { create, edit, view }

class _BenefitLineItemDraft {
  final String categoryKey;
  final String title;
  final String unitValue;
  final String units;
  final String notes;

  const _BenefitLineItemDraft({
    required this.categoryKey,
    required this.title,
    required this.unitValue,
    required this.units,
    required this.notes,
  });
}

class _InitialCostRowDraft {
  final String itemName;
  final String description;
  final String cost;
  final String assumptions;

  const _InitialCostRowDraft({
    required this.itemName,
    required this.description,
    required this.cost,
    required this.assumptions,
  });
}

class _StepDefinition {
  final String shortLabel;
  final String title;
  final String subtitle;

  const _StepDefinition(
      {required this.shortLabel, required this.title, required this.subtitle});
}

class _ValueSetupInvestmentSnapshot {
  final double estimatedCost;
  final double? averageRoi;
  final double? npv;
  final _CostRange costRange;
  final int benefitLineItemCount;
  final double totalBenefits;

  const _ValueSetupInvestmentSnapshot({
    required this.estimatedCost,
    required this.averageRoi,
    required this.npv,
    required this.costRange,
    required this.benefitLineItemCount,
    required this.totalBenefits,
  });

  bool get hasBenefitSignals => totalBenefits > 0 && benefitLineItemCount > 0;
}

class _BenefitLineItemEntry {
  final String id;
  String categoryKey;
  final TextEditingController titleController;
  final TextEditingController unitValueController;
  final TextEditingController unitsController;
  final TextEditingController notesController;
  VoidCallback? _listener;

  _BenefitLineItemEntry({
    required this.id,
    required this.categoryKey,
    String title = '',
    double unitValue = 0,
    double units = 0,
    String notes = '',
  })  : titleController = TextEditingController(text: title),
        unitValueController = TextEditingController(
          text: unitValue == 0
              ? ''
              : unitValue.toStringAsFixed(unitValue % 1 == 0 ? 0 : 2),
        ),
        unitsController = TextEditingController(
          text: units == 0 ? '' : units.toStringAsFixed(units % 1 == 0 ? 0 : 2),
        ),
        notesController = TextEditingController(text: notes);

  String get title => titleController.text.trim();

  double get unitValue => _readDouble(unitValueController.text);

  double get units => _readDouble(unitsController.text);

  String get notes => notesController.text.trim();

  double get totalValue => unitValue * units;

  void bind(VoidCallback listener) {
    _listener = listener;
    titleController.addListener(listener);
    unitValueController.addListener(listener);
    unitsController.addListener(listener);
    notesController.addListener(listener);
  }

  void unbind() {
    if (_listener == null) return;
    titleController.removeListener(_listener!);
    unitValueController.removeListener(_listener!);
    unitsController.removeListener(_listener!);
    notesController.removeListener(_listener!);
    _listener = null;
  }

  BenefitLineItemInput toPayload() => BenefitLineItemInput(
        category: categoryKey,
        title: title,
        unitValue: unitValue,
        units: units,
        notes: notes,
      );

  void dispose() {
    unbind();
    titleController.dispose();
    unitValueController.dispose();
    unitsController.dispose();
    notesController.dispose();
  }

  static double _readDouble(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(sanitized) ?? 0;
  }
}

class _BenefitCategorySummary {
  int itemCount = 0;
  double unitTotal = 0;
  double valueTotal = 0;

  void add(_BenefitLineItemEntry entry, {double? valueOverride}) {
    itemCount += 1;
    unitTotal += entry.units;
    valueTotal += valueOverride ?? entry.totalValue;
  }
}

class _CostRow {
  final TextEditingController itemController =
      TextEditingController(text: 'Name');
  final TextEditingController descriptionController = TextEditingController(
      text: 'Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum...');
  final TextEditingController costController = TextEditingController();
  final TextEditingController roiController = TextEditingController();
  final TextEditingController npvController = TextEditingController();
  final TextEditingController assumptionsController = TextEditingController();
  bool aiLoading = false;

  // Baseline values used for recomputation
  double _baseCost = 0;
  double _baseRoiPct = 0;
  double _baseBenefit = 0; // derived from ROI% and cost
  Map<int, double> _baseNpvs = const {5: 0};
  int _selectedHorizon = 5;

  final String Function() currencyProvider;
  VoidCallback? _listener;

  _CostRow({required this.currencyProvider});

  void applyBaseline(
      {required double cost,
      required double roiPercent,
      required Map<int, double> npvByYears}) {
    _baseCost = cost;
    _baseRoiPct = roiPercent;
    _baseBenefit = _baseCost * (1 + _baseRoiPct / 100);
    _baseNpvs =
        npvByYears.isEmpty ? const {5: 0} : Map<int, double>.from(npvByYears);
    _selectedHorizon = _baseNpvs.containsKey(5) ? 5 : _baseNpvs.keys.first;

    costController.text = _num(cost);
    // Set initial computed fields
    roiController.text = _formatPercent(_baseRoiPct);
    npvController.text = _num(_baseNpvs[_selectedHorizon] ?? 0);

    // Re-attach listener for live recalculation
    if (_listener != null) costController.removeListener(_listener!);
    _listener = () {
      refreshComputed();
    };
    costController.addListener(_listener!);
  }

  void setHorizon(int years) {
    if (_selectedHorizon == years) return;
    _selectedHorizon = years;
    refreshComputed();
  }

  void refreshComputed() {
    final newCost = _parseCurrency(costController.text);
    final baseNpv = _baseNpvs[_selectedHorizon] ??
        (_baseNpvs.values.isNotEmpty ? _baseNpvs.values.first : 0);
    if (newCost <= 0) {
      roiController.text = _formatPercent(0);
      npvController.text = _num(baseNpv);
      return;
    }
    // Assume benefits remain constant at baseline benefit; recompute ROI given new cost
    final newRoiPct = ((_baseBenefit - newCost) / newCost) * 100;
    // Adjust NPV assuming only upfront cost changes (benefits unchanged)
    final newNpv = baseNpv - (newCost - _baseCost);
    roiController.text = _formatPercent(newRoiPct);
    npvController.text = _num(newNpv);
  }

  void convertCurrency(double factor) {
    // Scale baseline values
    _baseCost *= factor;
    _baseBenefit *= factor;
    _baseNpvs = _baseNpvs.map((k, v) => MapEntry(k, v * factor));

    // Scale current entered cost
    final curCost = _parseCurrency(costController.text);
    if (curCost != 0) {
      final n = curCost * factor;
      costController.text = _num(n);
    }
    // Scale current NPV field if present
    final curNpv = _parseCurrency(npvController.text);
    if (curNpv != 0) {
      final n = curNpv * factor;
      npvController.text = _num(n);
    }
    // Recompute ROI/NPV to keep relationships intact
    refreshComputed();
  }

  double currentCost() => _parseCurrency(costController.text);

  double currentNpv() => _parseCurrency(npvController.text);

  double currentRoi() => _parsePercent(roiController.text);

  double baselineNpvFor(int years) =>
      _baseNpvs[years] ??
      (_baseNpvs.values.isNotEmpty ? _baseNpvs.values.first : 0);

  double _parseCurrency(String v) {
    final s = v.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(s) ?? 0;
  }

  double _parsePercent(String v) {
    final s = v.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(s) ?? 0;
  }

  String _num(double v) => (v.isFinite ? v : 0).toStringAsFixed(2);

  String _formatCurrency(double v) {
    final formatted = _formatNumber(v);
    final code = currencyProvider();
    return '$code $formatted';
  }

  String _formatPercent(double v) {
    final n = v.isFinite ? v : 0;
    return '${n.toStringAsFixed(1)}%';
  }

  String _formatNumber(double v) {
    final abs = v.abs();
    String s;
    if (abs >= 1000000000) {
      s = '${(v / 1000000000).toStringAsFixed(2)}B';
    } else if (abs >= 1000000) {
      s = '${(v / 1000000).toStringAsFixed(2)}M';
    } else if (abs >= 1000) {
      s = _thousands(v);
    } else {
      s = v.toStringAsFixed(2);
    }
    return s;
  }

  String _thousands(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final reverseIndex = intPart.length - i - 1;
      buffer.write(intPart[i]);
      if (reverseIndex % 3 == 0 && i != intPart.length - 1) buffer.write(',');
    }
    return '$buffer.$decPart';
  }

  void dispose() {
    itemController.dispose();
    descriptionController.dispose();
    costController.dispose();
    roiController.dispose();
    npvController.dispose();
    assumptionsController.dispose();
  }
}

class _SolutionCostContext {
  int resourceIndex = 0;
  int timelineIndex = 1;
  int complexityIndex = 0;
  final TextEditingController justificationController = TextEditingController();
  bool autoGenerated = true;
  bool _updating = false;

  _SolutionCostContext() {
    justificationController.addListener(_handleEdit);
  }

  void _handleEdit() {
    if (_updating) return;
    autoGenerated = false;
  }

  void updateJustification(String value) {
    _updating = true;
    justificationController.text = value;
    _updating = false;
    autoGenerated = true;
  }

  void dispose() {
    justificationController.dispose();
  }
}

class _QualitativeOption {
  final String label;
  final String detail;
  final String aiHint;

  const _QualitativeOption(
      {required this.label, required this.detail, required this.aiHint});
}

class _CostRange {
  final double lower;
  final double upper;

  const _CostRange({required this.lower, required this.upper});
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

class _BasisFrequencyToggleButton extends StatelessWidget {
  const _BasisFrequencyToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _BasisFrequencyToggle extends StatelessWidget {
  const _BasisFrequencyToggle({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BasisFrequencyToggleButton(
            label: 'Annual',
            isSelected: value == 'Annual',
            onTap: () => onChanged('Annual'),
          ),
          _BasisFrequencyToggleButton(
            label: 'Quarterly',
            isSelected: value == 'Quarterly',
            onTap: () => onChanged('Quarterly'),
          ),
          _BasisFrequencyToggleButton(
            label: 'Monthly',
            isSelected: value == 'Monthly',
            onTap: () => onChanged('Monthly'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCostEntry {
  final String categoryKey;
  final TextEditingController costController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  VoidCallback? _listener;
  bool aiLoading = false;

  _CategoryCostEntry({required this.categoryKey});

  void bind(VoidCallback listener) {
    _listener = listener;
    costController.addListener(listener);
    notesController.addListener(listener);
  }

  double get cost {
    final s = costController.text.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(s) ?? 0;
  }

  void dispose() {
    if (_listener != null) {
      costController.removeListener(_listener!);
      notesController.removeListener(_listener!);
    }
    costController.dispose();
    notesController.dispose();
  }
}
