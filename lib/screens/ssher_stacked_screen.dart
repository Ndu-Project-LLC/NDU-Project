import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_add_safety_item_dialog.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/ssher_export_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/web_utils_stub.dart'
    if (dart.library.html) 'package:ndu_project/utils/web_utils_web.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';

/// Six categories: Safety, Security, Health, Environment, Regulatory, Cost (Cost tab is a roll-up)
enum _SsherCategory { safety, security, health, environment, regulatory, cost }

String _categoryKey(_SsherCategory category) => category.name;

// ── Color Palette (matching HTML design tokens) ──
class _Palette {
  static const Color primary = Color(0xFFB45309);
  static const Color primaryContainer = Color(0xFFD97706);
  static const Color tertiaryFixedDim = Color(0xFFFABD00);
  static const Color tertiaryContainer = Color(0xFF946F00);
  static const Color onTertiaryFixed = Color(0xFF261A00);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceBright = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceVariant = Color(0xFFE0E3E5);
  static const Color surfaceDim = Color(0xFFD8DADC);
  static const Color onBackground = Color(0xFF191C1E);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF414754);
  static const Color outline = Color(0xFF717786);
  static const Color outlineVariant = Color(0xFFC0C6D6);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color primaryFixed = Color(0xFFD6E3FF);
  static const Color secondaryContainer = Color(0xFFE8DEF8);
  static const Color onSecondaryContainer = Color(0xFF1D192B);
  static const Color headerBg = Color(0xFF1C1B1B);
}

/// Heading text per category (e.g. "Safety Plan", "Security Plan", ...)
String _categoryPlanHeading(_SsherCategory cat) {
  switch (cat) {
    case _SsherCategory.safety:
      return 'Safety Plan';
    case _SsherCategory.security:
      return 'Security Plan';
    case _SsherCategory.health:
      return 'Health Plan';
    case _SsherCategory.environment:
      return 'Environment Plan';
    case _SsherCategory.regulatory:
      return 'Regulatory Plan';
    case _SsherCategory.cost:
      return 'SSHER Cost Summary';
  }
}

/// Display label per category (just "Safety", "Security", ...)
String _categoryLabel(_SsherCategory cat) {
  switch (cat) {
    case _SsherCategory.safety:
      return 'Safety';
    case _SsherCategory.security:
      return 'Security';
    case _SsherCategory.health:
      return 'Health';
    case _SsherCategory.environment:
      return 'Environment';
    case _SsherCategory.regulatory:
      return 'Regulatory';
    case _SsherCategory.cost:
      return 'Cost Summary';
  }
}

class SsherStackedScreen extends StatefulWidget {
  const SsherStackedScreen({super.key});

  @override
  State<SsherStackedScreen> createState() => _SsherStackedScreenState();
}

class _SsherStackedScreenState extends State<SsherStackedScreen>
    with SingleTickerProviderStateMixin {
  final Color _safetyAccent = const Color(0xFF34A853);
  final Color _securityAccent = const Color(0xFFEF5350);
  final Color _healthAccent = const Color(0xFF1E88E5);
  final Color _environmentAccent = const Color(0xFF2E7D32);
  final Color _regulatoryAccent = const Color(0xFF8E24AA);
  final Color _costAccent = const Color(0xFFD97706);

  late List<SsherEntry> _safetyEntries;
  late List<SsherEntry> _securityEntries;
  late List<SsherEntry> _healthEntries;
  late List<SsherEntry> _environmentEntries;
  late List<SsherEntry> _regulatoryEntries;

  // Per-category AI Plan summaries (each saved in ssherData.categoryPlans)
  final Map<String, String> _categoryPlans = {};
  final Map<String, bool> _categoryPlanLoading = {};
  final Map<String, bool> _categoryPlanLoaded = {};

  // UN SDG recommendations
  List<Map<String, String>> _sdgRecommendations = [];
  bool _isGeneratingSdgs = false;
  bool _sdgsLoaded = false;

  _SsherCategory _selectedCategory = _SsherCategory.safety;
  late TabController _tabController;

  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tracking: which SSHER tabs the user has visited (excludes cost tab)
  final Set<_SsherCategory> _visitedTabs = {};
  bool _stakeholderConfirmed = false;
  bool _entriesGenerated = false;
  bool _isGeneratingEntries = false;
  bool _initiationSecurityPulled = false;
  // Auto-sync toggle: when true, SSHER cost items push to Cost Estimate on save
  bool _autoSyncToCostEstimate = false;
  // Tracks the SSHER entry IDs that have already been pushed via auto-sync,
  // so we don't duplicate them on subsequent saves.
  final Set<String> _autoSyncedEntryIds = {};

  @override
  void initState() {
    super.initState();
    _safetyEntries = [];
    _securityEntries = [];
    _healthEntries = [];
    _environmentEntries = [];
    _regulatoryEntries = [];
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _SsherCategory.values[_tabController.index];
          // Track tab visits (exclude cost tab from the requirement)
          if (_selectedCategory != _SsherCategory.cost) {
            _visitedTabs.add(_selectedCategory);
          }
          // Save the visit state
          _saveTabsVisited();
          // Generate the category plan on first visit
          if (_selectedCategory != _SsherCategory.cost) {
            _ensureCategoryPlanLoaded(_selectedCategory);
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedEntries();
      _loadSavedState();
      _loadNotes();
      _pullInitiationSecurityData();
      // Mark the default tab as visited
      _visitedTabs.add(_SsherCategory.safety);
      _ensureCategoryPlanLoaded(_SsherCategory.safety);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Load saved state (visited tabs, stakeholder confirmation, plans, SDGs) ──
  void _loadSavedState() {
    final ssherData = ProjectDataHelper.getData(context).ssherData;
    setState(() {
      _stakeholderConfirmed = ssherData.stakeholderConfirmed;
      _autoSyncToCostEstimate = ssherData.autoSyncToCostEstimate;
      // Restore visited tabs from persistent storage
      for (final cat in _SsherCategory.values) {
        if (cat == _SsherCategory.cost) continue;
        if (ssherData.categoryApplicability[cat.name] == false) {
          _visitedTabs.add(cat);
        }
        if (ssherData.tabsVisited[cat.name] == true) {
          _visitedTabs.add(cat);
        }
      }
      // Restore per-category plans
      for (final entry in ssherData.categoryPlans.entries) {
        if (entry.value.trim().isNotEmpty) {
          _categoryPlans[entry.key] = entry.value;
          _categoryPlanLoaded[entry.key] = true;
        }
      }
    });
    // If auto-sync is enabled, mark all existing entries as already-synced
    // so we don't retroactively push them on the first save.
    if (_autoSyncToCostEstimate) {
      for (final e in ssherData.entries) {
        _autoSyncedEntryIds.add(e.id);
      }
    }
  }

  Future<void> _saveTabsVisited() async {
    final visitedMap = <String, bool>{};
    for (final cat in _SsherCategory.values) {
      if (cat == _SsherCategory.cost) continue;
      visitedMap[cat.name] = _visitedTabs.contains(cat);
    }
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher',
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        ssherData: data.ssherData.copyWith(tabsVisited: visitedMap),
      ),
    );
  }

  bool _isCategoryApplicable(_SsherCategory category) {
    final data = ProjectDataHelper.getData(context).ssherData;
    return data.categoryApplicability[category.name] != false;
  }

  Future<void> _setCategoryApplicable(
    _SsherCategory category,
    bool applicable,
  ) async {
    final current = ProjectDataHelper.getData(context).ssherData;
    final updatedMap = Map<String, bool>.from(current.categoryApplicability)
      ..[category.name] = applicable;
    final updatedVisited = Map<String, bool>.from(current.tabsVisited);
    if (!applicable) {
      updatedVisited[category.name] = true;
      _visitedTabs.add(category);
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher',
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        ssherData: data.ssherData.copyWith(
          categoryApplicability: updatedMap,
          tabsVisited: updatedVisited,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveStakeholderConfirmation(bool value) async {
    final confirmedAt = value ? DateTime.now().toIso8601String() : '';
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher',
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        ssherData: data.ssherData.copyWith(
          stakeholderConfirmed: value,
          stakeholderConfirmedAt: confirmedAt,
        ),
      ),
    );
  }

  void _loadNotes() {
    final data = ProjectDataHelper.getData(context);
    final existingNotes = data.ssherData.screen2Data.trim();
    if (existingNotes.isNotEmpty) {
      _notesController.text = existingNotes;
    }
  }

  Future<void> _saveNotes() async {
    final notes = _notesController.text.trim();
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher',
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        ssherData: data.ssherData.copyWith(screen2Data: notes),
      ),
    );
  }

  void _loadSavedEntries() {
    final ssherData = ProjectDataHelper.getData(context).ssherData;
    final entries = ssherData.entries;
    setState(() {
      _safetyEntries = entries
          .where((e) => e.category == _categoryKey(_SsherCategory.safety))
          .toList();
      _securityEntries = entries
          .where((e) => e.category == _categoryKey(_SsherCategory.security))
          .toList();
      _healthEntries = entries
          .where((e) => e.category == _categoryKey(_SsherCategory.health))
          .toList();
      _environmentEntries = entries
          .where((e) => e.category == _categoryKey(_SsherCategory.environment))
          .toList();
      _regulatoryEntries = entries
          .where((e) => e.category == _categoryKey(_SsherCategory.regulatory))
          .toList();
    });
    if (entries.isEmpty) {
      _populateSsherEntriesFromAi();
    } else {
      _entriesGenerated = true;
    }
  }

  /// Pull the Initiation phase (Front End Planning) security section data
  /// into the Security tab so the user has continuity. Only runs once.
  void _pullInitiationSecurityData() {
    if (_initiationSecurityPulled) return;
    final data = ProjectDataHelper.getData(context);
    final fep = data.frontEndPlanning;
    final securityText = fep.security.trim();

    // Pull the security notes as a single entry on the Security tab if we don't already have one
    final hasSecurityEntry = _securityEntries.any((e) =>
        e.concern.toLowerCase().contains('initiation') ||
        e.notes.toLowerCase().contains('initiation security') ||
        e.concern == 'Initiation Phase Security Plan');

    if (securityText.isNotEmpty && !hasSecurityEntry) {
      // Summarize the initiation security text into a 200-char entry
      final summary = securityText.length > 280
          ? '${securityText.substring(0, 280)}...'
          : securityText;
      final entry = SsherEntry(
        category: 'security',
        department: 'IT Security',
        teamMember: 'Security Analyst (carried from Initiation)',
        concern: 'Initiation Phase Security Plan (carried forward)',
        riskLevel: 'High',
        mitigation: summary,
        notes: 'Auto-imported from Front End Planning – Security section.',
      );
      setState(() {
        _securityEntries.insert(0, entry);
        _initiationSecurityPulled = true;
      });
      _saveEntries();
    } else if (hasSecurityEntry) {
      _initiationSecurityPulled = true;
    }
  }

  Future<void> _populateSsherEntriesFromAi() async {
    if (_entriesGenerated || _isGeneratingEntries) return;
    if (_allEntries().isNotEmpty) {
      _entriesGenerated = true;
      return;
    }

    final projectData = ProjectDataHelper.getData(context);
    final contextText =
        ProjectDataHelper.buildFepContext(projectData, sectionLabel: 'SSHER');
    if (contextText.trim().isEmpty) {
      _entriesGenerated = true;
      return;
    }

    setState(() => _isGeneratingEntries = true);

    List<SsherEntry> generatedEntries = [];
    try {
      generatedEntries = await OpenAiServiceSecure()
          .generateSsherEntries(context: contextText, itemsPerCategory: 2);
    } catch (error) {
      debugPrint('SSHER entries AI call failed: $error');
    }

    if (!mounted) return;

    if (_allEntries().isNotEmpty) {
      setState(() => _isGeneratingEntries = false);
      _entriesGenerated = true;
      return;
    }

    final safety = <SsherEntry>[];
    final security = <SsherEntry>[];
    final health = <SsherEntry>[];
    final environment = <SsherEntry>[];
    final regulatory = <SsherEntry>[];

    for (final entry in generatedEntries) {
      switch (entry.category) {
        case 'safety':
          safety.add(entry);
          break;
        case 'security':
          security.add(entry);
          break;
        case 'health':
          health.add(entry);
          break;
        case 'environment':
          environment.add(entry);
          break;
        case 'regulatory':
          regulatory.add(entry);
          break;
      }
    }

    setState(() {
      _safetyEntries = safety;
      _securityEntries = security;
      _healthEntries = health;
      _environmentEntries = environment;
      _regulatoryEntries = regulatory;
      _isGeneratingEntries = false;
    });
    _entriesGenerated = true;
    await _saveEntries();
    // After AI generation, also pull in Initiation security data
    _pullInitiationSecurityData();
  }

  /// Ensures the per-category AI plan is loaded (lazy-loaded on first tab visit)
  Future<void> _ensureCategoryPlanLoaded(_SsherCategory cat) async {
    if (cat == _SsherCategory.cost) return;
    final key = cat.name;
    if (_categoryPlanLoaded[key] == true) return;
    if (_categoryPlans[key]?.isNotEmpty == true) {
      _categoryPlanLoaded[key] = true;
      return;
    }
    if (_categoryPlanLoading[key] == true) return;

    setState(() => _categoryPlanLoading[key] = true);

    final projectData = ProjectDataHelper.getData(context);
    final contextText =
        ProjectDataHelper.buildFepContext(projectData, sectionLabel: 'SSHER');
    if (contextText.trim().isEmpty) {
      setState(() {
        _categoryPlanLoaded[key] = true;
        _categoryPlanLoading[key] = false;
      });
      return;
    }

    String plan = '';
    try {
      plan = await OpenAiServiceSecure().generateSsherCategoryPlan(
        context: contextText,
        category: key,
      );
    } catch (e) {
      debugPrint('generateSsherCategoryPlan failed for $key: $e');
    }

    if (!mounted) return;

    final trimmed = plan.trim();
    setState(() {
      if (trimmed.isNotEmpty) {
        _categoryPlans[key] = trimmed;
      }
      _categoryPlanLoaded[key] = true;
      _categoryPlanLoading[key] = false;
    });

    if (trimmed.isNotEmpty) {
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'ssher',
        showSnackbar: false,
        dataUpdater: (data) => data.copyWith(
          ssherData: data.ssherData.copyWith(
            categoryPlans: Map<String, String>.from(_categoryPlans),
          ),
        ),
      );
    }
  }

  Future<void> _retryCategoryPlan(_SsherCategory cat) async {
    final key = cat.name;
    setState(() {
      _categoryPlanLoaded[key] = false;
      _categoryPlans[key] = '';
    });
    await _ensureCategoryPlanLoaded(cat);
  }

  /// Generates SDG recommendations (for the Environment tab)
  Future<void> _loadSdgRecommendations() async {
    if (_sdgsLoaded || _isGeneratingSdgs) return;
    setState(() => _isGeneratingSdgs = true);

    final projectData = ProjectDataHelper.getData(context);
    final contextText =
        ProjectDataHelper.buildFepContext(projectData, sectionLabel: 'SSHER');
    if (contextText.trim().isEmpty) {
      setState(() {
        _isGeneratingSdgs = false;
        _sdgsLoaded = true;
      });
      return;
    }

    List<Map<String, String>> recs = [];
    try {
      recs = await OpenAiServiceSecure()
          .generateSdgRecommendations(context: contextText);
    } catch (e) {
      debugPrint('generateSdgRecommendations failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _sdgRecommendations = recs;
      _isGeneratingSdgs = false;
      _sdgsLoaded = true;
    });

    if (recs.isNotEmpty) {
      final sdgList = recs.map((r) => r['goal'] ?? '').where((g) => g.isNotEmpty).toList();
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'ssher',
        showSnackbar: false,
        dataUpdater: (data) => data.copyWith(
          ssherData: data.ssherData.copyWith(applicableSdgs: sdgList),
        ),
      );
    }
  }

  List<SsherEntry> _entriesForCategory(_SsherCategory category) {
    switch (category) {
      case _SsherCategory.safety:
        return _safetyEntries;
      case _SsherCategory.security:
        return _securityEntries;
      case _SsherCategory.health:
        return _healthEntries;
      case _SsherCategory.environment:
        return _environmentEntries;
      case _SsherCategory.regulatory:
        return _regulatoryEntries;
      case _SsherCategory.cost:
        return _allEntries();
    }
  }

  List<SsherEntry> _allEntries() {
    return [
      ..._safetyEntries,
      ..._securityEntries,
      ..._healthEntries,
      ..._environmentEntries,
      ..._regulatoryEntries,
    ];
  }

  Future<void> _saveEntries() async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher',
      dataUpdater: (data) => data.copyWith(
        ssherData: data.ssherData.copyWith(entries: _allEntries()),
      ),
      showSnackbar: false,
    );
    // Auto-sync any new SSHER cost items to Cost Estimate (if enabled)
    await _autoSyncNewCostItems();
  }

  Future<void> _deleteEntry(SsherEntry entry) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete SSHER Item',
      itemLabel: entry.concern,
    );
    if (!confirmed) return;
    setState(() {
      if (entry.category == 'safety') {
        _safetyEntries.removeWhere((e) => e.id == entry.id);
      }
      if (entry.category == 'security') {
        _securityEntries.removeWhere((e) => e.id == entry.id);
      }
      if (entry.category == 'health') {
        _healthEntries.removeWhere((e) => e.id == entry.id);
      }
      if (entry.category == 'environment') {
        _environmentEntries.removeWhere((e) => e.id == entry.id);
      }
      if (entry.category == 'regulatory') {
        _regulatoryEntries.removeWhere((e) => e.id == entry.id);
      }
    });
    await _saveEntries();
  }

  Future<void> _editEntry(SsherEntry entry) async {
    Color accentColor;
    IconData icon;
    String heading;
    String blurb;
    String concernLabel;

    switch (entry.category) {
      case 'safety':
        accentColor = _safetyAccent;
        icon = Icons.health_and_safety;
        heading = 'Edit Safety Item';
        blurb = 'Update details for the safety record.';
        concernLabel = 'Safety Concern';
        break;
      case 'security':
        accentColor = _securityAccent;
        icon = Icons.shield_outlined;
        heading = 'Edit Security Item';
        blurb = 'Update the security exposure details.';
        concernLabel = 'Security Concern';
        break;
      case 'health':
        accentColor = _healthAccent;
        icon = Icons.volunteer_activism_outlined;
        heading = 'Edit Health Item';
        blurb = 'Update the health-related concern.';
        concernLabel = 'Health Concern';
        break;
      case 'environment':
        accentColor = _environmentAccent;
        icon = Icons.eco_outlined;
        heading = 'Edit Environment Item';
        blurb = 'Update log of environmental impact.';
        concernLabel = 'Environmental Concern';
        break;
      case 'regulatory':
        accentColor = _regulatoryAccent;
        icon = Icons.gavel_outlined;
        heading = 'Edit Regulatory Item';
        blurb = 'Update compliance requirement details.';
        concernLabel = 'Regulatory Requirement';
        break;
      default:
        return;
    }

    final projectData = ProjectDataHelper.getData(context);
    final input = await showDialog<SsherItemInput>(
      context: context,
      builder: (ctx) => AddSsherItemDialog(
        accentColor: accentColor,
        icon: icon,
        heading: heading,
        blurb: blurb,
        concernLabel: concernLabel,
        saveButtonLabel: 'Save Changes',
        initialData: SsherItemInput(
          department: entry.department,
          teamMember: entry.teamMember,
          concern: entry.concern,
          riskLevel: entry.riskLevel,
          mitigation: entry.mitigation,
          estimatedCost: entry.estimatedCost,
          costCurrency: entry.costCurrency,
          costFrequency: entry.costFrequency,
          costUnit: entry.costUnit,
          linkedRiskIds: entry.linkedRiskIds,
          linkedStaffingRoleIds: entry.linkedStaffingRoleIds,
          linkedRequirementIds: entry.linkedRequirementIds,
          notes: entry.notes,
        ),
        riskRegisterItems: projectData.frontEndPlanning.riskRegisterItems,
        staffingRows: projectData.frontEndPlanning.staffingRows,
        requirementItems: projectData.frontEndPlanning.requirementItems,
      ),
    );

    if (input == null) return;

    setState(() {
      entry.department = input.department;
      entry.teamMember = input.teamMember;
      entry.concern = input.concern;
      entry.riskLevel = input.riskLevel;
      entry.mitigation = input.mitigation;
      entry.estimatedCost = input.estimatedCost;
      entry.costCurrency = input.costCurrency;
      entry.costFrequency = input.costFrequency;
      entry.costUnit = input.costUnit;
      entry.linkedRiskIds = List<String>.from(input.linkedRiskIds);
      entry.linkedStaffingRoleIds = List<String>.from(input.linkedStaffingRoleIds);
      entry.linkedRequirementIds = List<String>.from(input.linkedRequirementIds);
      entry.notes = input.notes;
    });
    await _saveEntries();
  }

  Future<void> _addEntry(_SsherCategory category, SsherItemInput input) async {
    final entry = SsherEntry(
      category: _categoryKey(category),
      department: input.department,
      teamMember: input.teamMember,
      concern: input.concern,
      riskLevel: input.riskLevel,
      mitigation: input.mitigation,
      estimatedCost: input.estimatedCost,
      costCurrency: input.costCurrency,
      costFrequency: input.costFrequency,
      costUnit: input.costUnit,
      linkedRiskIds: List<String>.from(input.linkedRiskIds),
      linkedStaffingRoleIds: List<String>.from(input.linkedStaffingRoleIds),
      linkedRequirementIds: List<String>.from(input.linkedRequirementIds),
      notes: input.notes,
    );
    setState(() => _entriesForCategory(category).add(entry));
    await _saveEntries();
  }

  Future<void> _downloadAll() async {
    final isAdmin = await UserService.isCurrentUserAdmin();
    final hostname = getCurrentHostname() ?? '';
    final allowCsv = isAdmin && hostname.startsWith('admin.');

    final map = {
      'SAFETY': _safetyEntries,
      'SECURITY': _securityEntries,
      'HEALTH': _healthEntries,
      'ENVIRONMENT': _environmentEntries,
      'REGULATORY': _regulatoryEntries,
    };

    if (allowCsv) {
      final csv = SsherExportHelper.allEntriesToCsv(map);
      await SsherExportHelper.downloadCsv(csv, 'ssher_all_categories.csv');
    } else {
      await SsherExportHelper.exportAllToPdf(map);
    }
  }

  Color _accentForCategory(_SsherCategory cat) {
    switch (cat) {
      case _SsherCategory.safety:
        return _safetyAccent;
      case _SsherCategory.security:
        return _securityAccent;
      case _SsherCategory.health:
        return _healthAccent;
      case _SsherCategory.environment:
        return _environmentAccent;
      case _SsherCategory.regulatory:
        return _regulatoryAccent;
      case _SsherCategory.cost:
        return _costAccent;
    }
  }

  IconData _iconForCategory(_SsherCategory cat) {
    switch (cat) {
      case _SsherCategory.safety:
        return Icons.health_and_safety;
      case _SsherCategory.security:
        return Icons.security;
      case _SsherCategory.health:
        return Icons.medical_services;
      case _SsherCategory.environment:
        return Icons.eco;
      case _SsherCategory.regulatory:
        return Icons.gavel;
      case _SsherCategory.cost:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile
          ? Drawer(
              width: AppBreakpoints.sidebarWidth(context),
              child: SafeArea(
                child: InitiationLikeSidebar(
                  activeItemLabel: 'SSHER',
                  showHeader: true,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: StreamBuilder<bool>(
            stream: UserService.watchAdminStatus(),
            builder: (context, snapshot) {
              final isAdmin = snapshot.data ?? false;
              final hostname = getCurrentHostname() ?? '';
              final allowCsv = isAdmin && hostname.startsWith('admin.');

              if (!isMobile) {
                return _buildDesktopLayout(allowCsv);
              }
              return _buildMobileLayout(allowCsv);
            }),
      ),
    );
  }

  // ── Desktop Layout ──
  Widget _buildDesktopLayout(bool allowCsv) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(activeItemLabel: 'SSHER'),
            ),
            Expanded(
              child: Column(
                children: [
                  PlanningPhaseHeader(
                    title: 'SSHER Hub',
                    breadcrumbPhase: 'Planning Phase',
                    breadcrumbTitle:
                        'Safety, Security, Health, Environmental, and Regulatory (SSHER) Hub',
                    onBack: () =>
                        PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
                    onForward: () => _handleNextWithConfirmation(),
                    onExportPdf: _exportPdf,
                  ),
                  Expanded(child: _buildMainContent(allowCsv)),
                ],
              ),
            ),
          ],
        ),
        const MobileSidebarHamburger(
          sidebar: InitiationLikeSidebar(
            activeItemLabel: 'SSHER',
          ),
        ),
        const KazAiChatBubble(),
        const AdminEditToggle(),
      ],
    );
  }

  // ── Mobile Layout ──
  Widget _buildMobileLayout(bool allowCsv) {
    return Column(
      children: [
        PlanningPhaseHeader(
          title: 'SSHER Hub',
          breadcrumbPhase: 'Planning Phase',
          breadcrumbTitle:
              'Safety, Security, Health, Environmental, and Regulatory (SSHER) Hub',
          onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
          onForward: () => _handleNextWithConfirmation(),
          onExportPdf: _exportPdf,
        ),
        Expanded(child: _buildMainContent(allowCsv)),
      ],
    );
  }

  /// Validates that the user has visited all 5 SSHER tabs AND checked the
  /// confirmation checkbox before navigating to the next phase.
  Future<void> _handleNextWithConfirmation() async {
    final requiredTabs = {
      _SsherCategory.safety,
      _SsherCategory.security,
      _SsherCategory.health,
      _SsherCategory.environment,
      _SsherCategory.regulatory,
    }.where(_isCategoryApplicable).toSet();
    final unvisited = requiredTabs.difference(_visitedTabs).toList();
    if (unvisited.isNotEmpty) {
      final labels = unvisited.map(_categoryLabel).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please review all SSHER sections before continuing. Unvisited: $labels'),
          duration: const Duration(seconds: 4),
        ),
      );
      // Jump to the first unvisited tab
      _tabController.animateTo(unvisited.first.index);
      setState(() => _selectedCategory = unvisited.first);
      return;
    }
    if (!_stakeholderConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please confirm the stakeholder review checkbox before continuing.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    PlanningPhaseNavigation.goToNext(context, 'ssher');
  }

  // ── Shared Main Content ──
  Widget _buildMainContent(bool allowCsv) {
    final isMobile = AppBreakpoints.isMobile(context);

    return SingleChildScrollView(
      padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Breadcrumbs ──
          if (isMobile) _buildBreadcrumbs(),

          // ── Context Section (Title + PDF download) ──
          _buildContextSection(allowCsv, isMobile),

          // ── Notes Input ──
          _buildNotesSection(isMobile),

          _buildApplicabilitySection(isMobile),

          // ── Phase Navigation (Scrollable Pill Tabs) ──
          _buildPhaseTabs(isMobile),

          // ── Inner Page Navigation Hint ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
            child: InnerPageNavigationHint(
              pageId: 'ssher_stacked',
              pageTitle: 'SSHER Hub',
              description: 'Navigate between SSHER categories',
              currentSectionId: _selectedCategory.name,
              accentColor: _accentForCategory(_selectedCategory),
              sections: [
                InnerPageSection(
                    id: _SsherCategory.safety.name,
                    label: 'Safety',
                    icon: Icons.health_and_safety,
                    status: _selectedCategory == _SsherCategory.safety
                        ? InnerPageSectionStatus.current
                        : (_visitedTabs.contains(_SsherCategory.safety)
                            ? InnerPageSectionStatus.completed
                            : InnerPageSectionStatus.available),
                    stepNumber: 1),
                InnerPageSection(
                    id: _SsherCategory.security.name,
                    label: 'Security',
                    icon: Icons.security,
                    status: _selectedCategory == _SsherCategory.security
                        ? InnerPageSectionStatus.current
                        : (_visitedTabs.contains(_SsherCategory.security)
                            ? InnerPageSectionStatus.completed
                            : InnerPageSectionStatus.available),
                    stepNumber: 2),
                InnerPageSection(
                    id: _SsherCategory.health.name,
                    label: 'Health',
                    icon: Icons.medical_services,
                    status: _selectedCategory == _SsherCategory.health
                        ? InnerPageSectionStatus.current
                        : (_visitedTabs.contains(_SsherCategory.health)
                            ? InnerPageSectionStatus.completed
                            : InnerPageSectionStatus.available),
                    stepNumber: 3),
                InnerPageSection(
                    id: _SsherCategory.environment.name,
                    label: 'Environment',
                    icon: Icons.eco,
                    status: _selectedCategory == _SsherCategory.environment
                        ? InnerPageSectionStatus.current
                        : (_visitedTabs.contains(_SsherCategory.environment)
                            ? InnerPageSectionStatus.completed
                            : InnerPageSectionStatus.available),
                    stepNumber: 4),
                InnerPageSection(
                    id: _SsherCategory.regulatory.name,
                    label: 'Regulatory',
                    icon: Icons.gavel,
                    status: _selectedCategory == _SsherCategory.regulatory
                        ? InnerPageSectionStatus.current
                        : (_visitedTabs.contains(_SsherCategory.regulatory)
                            ? InnerPageSectionStatus.completed
                            : InnerPageSectionStatus.available),
                    stepNumber: 5),
                InnerPageSection(
                    id: _SsherCategory.cost.name,
                    label: 'Cost Summary',
                    icon: Icons.attach_money,
                    status: _selectedCategory == _SsherCategory.cost
                        ? InnerPageSectionStatus.current
                        : InnerPageSectionStatus.available,
                    stepNumber: 6),
              ],
              onSectionTap: (sectionId) {
                final cat = _SsherCategory.values
                    .firstWhere((c) => c.name == sectionId);
                setState(() => _selectedCategory = cat);
                _tabController.animateTo(cat.index);
                if (cat != _SsherCategory.cost) {
                  _visitedTabs.add(cat);
                  _saveTabsVisited();
                  _ensureCategoryPlanLoaded(cat);
                }
              },
            ),
          ),

          // ── Data Cards Section ──
          _buildDataCardsSection(isMobile, allowCsv),

          // ── Stakeholder Confirmation ──
          _buildStakeholderConfirmation(),

          // ── Save & Continue Button ──
          if (isMobile)
            _buildSaveContinueButton()
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: LaunchPhaseNavigation(
                backLabel: 'Back',
                nextLabel: 'Next',
                onBack: () =>
                    PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
                onNext: () => _handleNextWithConfirmation(),
              ),
            ),

          // Bottom padding for mobile
          if (isMobile) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildApplicabilitySection(bool isMobile) {
    final categories = _SsherCategory.values
        .where((category) => category != _SsherCategory.cost)
        .toList();

    return Padding(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 16 : 0, 16, isMobile ? 16 : 0, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applicable SSHER Sections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Turn off sections that do not apply to this project. Skipped sections will not block completion.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            ...categories.map((category) {
              final applicable = _isCategoryApplicable(category);
              return SwitchListTile.adaptive(
                value: applicable,
                contentPadding: EdgeInsets.zero,
                title: Text(_categoryLabel(category)),
                subtitle: Text(
                  applicable
                      ? 'Included in SSHER review and completion checks.'
                      : 'Marked not applicable and skipped from review requirements.',
                ),
                onChanged: (value) => _setCategoryApplicable(category, value),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Breadcrumbs ──
  Widget _buildBreadcrumbs() {
    final projectName =
        ProjectDataHelper.getData(context).projectName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Projects',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: _Palette.onSurfaceVariant,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right,
                  size: 14, color: _Palette.onSurfaceVariant),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                projectName.isNotEmpty ? projectName : 'Project',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: _Palette.onSurfaceVariant,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right,
                  size: 14, color: _Palette.onSurfaceVariant),
            ),
            const Text(
              'SSHER Hub',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                color: _Palette.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Context Section ──
  Widget _buildContextSection(bool allowCsv, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 0, isMobile ? 16 : 0, isMobile ? 16 : 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Safety, Security, Health, Environmental, and Regulatory (SSHER) Hub',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w700,
                    color: _Palette.onBackground,
                    letterSpacing: isMobile ? -0.02 : 0,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isMobile)
                OutlinedButton.icon(
                  onPressed: _downloadAll,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('PDF',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.05)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Palette.onSurface,
                    side: const BorderSide(color: _Palette.outlineVariant),
                    backgroundColor: _Palette.surfaceContainerLowest,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _downloadAll,
                  icon: Icon(allowCsv
                      ? Icons.download_for_offline
                      : Icons.picture_as_pdf),
                  label: Text(allowCsv
                      ? 'Download All (CSV)'
                      : 'Download All (PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Identify and plan for the Safety, Security, Health, Environmental, and Regulatory aspects required to support safe and compliant project delivery. AI tailors each section to the project type, location, and applicable rules. The Security section automatically pulls the Initiation phase security plan. The Cost Summary tab aggregates all SSHER costs into a single view.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: _Palette.onSurfaceVariant,
              height: 1.55,
              letterSpacing: 0.01,
            ),
          ),
          const SizedBox(height: 12),
          // Auto-sync toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _autoSyncToCostEstimate
                  ? const Color(0xFFECFDF5)
                  : _Palette.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _autoSyncToCostEstimate
                    ? const Color(0xFFA7F3D0)
                    : _Palette.surfaceVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _autoSyncToCostEstimate
                      ? Icons.sync
                      : Icons.sync_disabled,
                  size: 16,
                  color: _autoSyncToCostEstimate
                      ? const Color(0xFF047857)
                      : _Palette.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSHER → Cost Estimate Auto-Sync',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _autoSyncToCostEstimate
                              ? const Color(0xFF047857)
                              : _Palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _autoSyncToCostEstimate
                            ? 'ON — new SSHER cost items are pushed to Cost Estimate automatically on save.'
                            : 'OFF — use the "Push to Cost Estimate" button on the Cost Summary tab to push manually.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _autoSyncToCostEstimate
                              ? const Color(0xFF047857)
                              : _Palette.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoSyncToCostEstimate,
                  onChanged: _setAutoSyncToCostEstimate,
                  activeColor: const Color(0xFF047857),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // One-click Push All Integrations button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _Palette.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _Palette.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: _Palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'One-Click Push All Integrations',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _Palette.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pushes Cost Estimate + Risk Register + Schedule + Requirements in sequence with a progress dialog.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _Palette.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pushAllIntegrations,
                  icon: const Icon(Icons.bolt, size: 14),
                  label: const Text('Run All',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes Section ──
  Widget _buildNotesSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 0, isMobile ? 16 : 16, isMobile ? 16 : 0, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _Palette.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Palette.surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notes, size: 16, color: _Palette.outline),
                  SizedBox(width: 6),
                  Text(
                    'General SSHER Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.05,
                      color: _Palette.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VoiceTextField(
                controller: _notesController,
                maxLines: 2,
                onChanged: (_) => _saveNotes(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _Palette.surfaceBright,
                  hintText:
                      'Add any overarching SSHER notes for this project phase...',
                  hintStyle: TextStyle(
                    color: _Palette.outlineVariant,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: _Palette.primaryContainer, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: _Palette.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phase Navigation Tabs (Scrollable Pills with check marks) ──
  Widget _buildPhaseTabs(bool isMobile) {
    final categories = _SsherCategory.values;

    return Container(
      decoration: isMobile
          ? BoxDecoration(
              color: _Palette.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 0, vertical: isMobile ? 12 : 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = cat == _selectedCategory;
            final icon = _iconForCategory(cat);
            final label = _categoryLabel(cat);
            final isVisited = cat == _SsherCategory.cost
                ? false
                : _visitedTabs.contains(cat);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _tabController.animateTo(cat.index);
                    if (cat != _SsherCategory.cost) {
                      _visitedTabs.add(cat);
                      _saveTabsVisited();
                      _ensureCategoryPlanLoaded(cat);
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _Palette.primaryContainer
                          : _Palette.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected
                          ? null
                          : Border.all(color: _Palette.outlineVariant),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _Palette.primaryContainer
                                    .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : _Palette.onSurfaceVariant,
                            fill: isSelected ? 1.0 : 0.0),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : _Palette.onSurfaceVariant,
                          ),
                        ),
                        if (isVisited && !isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF34A853)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Data Cards Section ──
  Widget _buildDataCardsSection(bool isMobile, bool allowCsv) {
    if (_selectedCategory == _SsherCategory.cost) {
      return _buildCostSummaryTab(isMobile);
    }

    final entries = _entriesForCategory(_selectedCategory);
    final accent = _accentForCategory(_selectedCategory);
    final catLabel = _categoryLabel(_selectedCategory);

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          _buildSectionHeader(catLabel, entries.length, accent),

          const SizedBox(height: 12),

          // Per-category integration actions: Push to Risk Register
          _buildIntegrationActionsRow(accent, catLabel),

          const SizedBox(height: 16),

          // Per-category AI Plan (Safety Plan, Security Plan, etc.)
          _buildCategoryPlanCard(accent),

          const SizedBox(height: 16),

          // Environment tab: UN SDG section
          if (_selectedCategory == _SsherCategory.environment) ...[
            _buildSdgCard(isMobile),
            const SizedBox(height: 16),
          ],

          // Security tab: Initiation phase security carried forward callout
          if (_selectedCategory == _SsherCategory.security) ...[
            _buildInitiationSecurityCallout(),
            const SizedBox(height: 16),
          ],

          // Loading state
          if (_isGeneratingEntries)
            _buildLoadingState()
          else if (entries.isEmpty)
            _buildEmptyState(accent, catLabel)
          else
            _buildEntriesTable(entries, accent, isMobile),

          const SizedBox(height: 24),

          // Logs / Checklists / Documents subsections (per entry-level: aggregated summary)
          _buildSubsectionSummary(accent, isMobile),

          const SizedBox(height: 24),

          // Staffing Gap Analysis (shows on all SSHER tabs — analyzes full project)
          _buildStaffingGapAnalysis(accent, isMobile),

          const SizedBox(height: 24),

          // Requirements Gap Analysis (regulatory/compliance language detection)
          _buildRequirementsGapAnalysis(accent, isMobile),
        ],
      ),
    );
  }

  // ── Integration Actions Row (per-tab) ──
  Widget _buildIntegrationActionsRow(Color accent, String catLabel) {
    final entries = _entriesForCategory(_selectedCategory);
    final highMedRiskCount = entries.where((e) {
      final level = e.riskLevel.trim().toLowerCase();
      return level == 'high' || level == 'medium';
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Cross-Discipline Integration',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          if (highMedRiskCount > 0)
            TextButton.icon(
              onPressed: () => _pushToRiskRegister(_selectedCategory),
              icon: const Icon(Icons.warning_amber, size: 14),
              label: Text(
                  'Push $highMedRiskCount High/Med Risk${highMedRiskCount == 1 ? '' : 's'} to Risk Register',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            )
          else
            Text('No High/Medium risks to push',
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: _Palette.outline)),
        ],
      ),
    );
  }

  // ── Staffing Gap Analysis Section ──
  Widget _buildStaffingGapAnalysis(Color accent, bool isMobile) {
    final gaps = _computeStaffingGaps();
    final projectData = ProjectDataHelper.getData(context);
    final staffingCount = projectData.frontEndPlanning.staffingRows.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Staffing Plan Gap Analysis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (gaps.isNotEmpty)
                TextButton.icon(
                  onPressed: _addAllStaffingGaps,
                  icon: const Icon(Icons.add_circle, size: 14),
                  label: const Text('Add All to Staffing Plan',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SSHER items reference ${gaps.length} role${gaps.length == 1 ? '' : 's'} not yet present in your Staffing Plan ($staffingCount current ${staffingCount == 1 ? 'role' : 'roles'}). Closing these gaps ensures every SSHER responsibility has a named owner on the project team.',
            style: const TextStyle(
              fontSize: 12,
              color: _Palette.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          if (gaps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No staffing gaps detected. All SSHER-referenced roles are present in your Staffing Plan.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: gaps.map((gap) {
                final role = gap['role'] as String;
                final count = gap['count'] as int;
                final examples = gap['examples'] as List<SsherEntry>;
                final exampleText = examples
                    .map((e) => e.concern.isNotEmpty
                        ? (e.concern.length > 40
                            ? '${e.concern.substring(0, 40)}...'
                            : e.concern)
                        : 'Item')
                    .take(2)
                    .join('; ');
                return Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              role,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _Palette.onBackground,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${count}x',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (exampleText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Referenced in: $exampleText',
                          style: const TextStyle(
                              fontSize: 11,
                              color: _Palette.onSurfaceVariant,
                              fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _addRoleToStaffingPlan(role),
                        icon: const Icon(Icons.add, size: 12),
                        label: const Text('Add to Staffing Plan',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(
                              color: accent.withValues(alpha: 0.5)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Requirements Gap Analysis Section ──
  Widget _buildRequirementsGapAnalysis(Color accent, bool isMobile) {
    final gaps = _computeRequirementsGaps();
    final projectData = ProjectDataHelper.getData(context);
    final reqCount = projectData.frontEndPlanning.requirementItems.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Requirements Gap Analysis (Regulatory / Compliance)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (gaps.isNotEmpty)
                TextButton.icon(
                  onPressed: _addAllRequirementsGaps,
                  icon: const Icon(Icons.add_circle, size: 14),
                  label: const Text('Add All to Requirements',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SSHER items often imply regulatory/compliance requirements. This section scans your SSHER items for regulatory language (permit, regulation, compliance, OSHA, ISO, audit, certification, license, etc.) and suggests any that are not yet captured in your Requirements list ($reqCount current ${reqCount == 1 ? 'requirement' : 'requirements'}).',
            style: const TextStyle(
              fontSize: 12,
              color: _Palette.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          if (gaps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No regulatory/compliance gaps detected. All SSHER items with regulatory language are already captured in your Requirements list.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: gaps.map((gap) {
                final entry = gap['entry'] as SsherEntry;
                final desc = gap['proposedDescription'] as String;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Regulatory',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _Palette.outline)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _Palette.onBackground,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _addRequirementToProject(gap),
                        icon: const Icon(Icons.add, size: 12),
                        label: const Text('Add to Requirements',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(
                              color: accent.withValues(alpha: 0.5)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(String label, int count, Color accent) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _Palette.surfaceVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _Palette.onSurface,
                  letterSpacing: -0.01,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _Palette.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _Palette.onSurfaceVariant,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _handleAddItem(),
            child: const Row(
              children: [
                Icon(Icons.add_circle,
                    size: 18, color: _Palette.primary),
                SizedBox(width: 4),
                Text(
                  'Add Item',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Palette.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Per-Category AI Plan Card ──
  Widget _buildCategoryPlanCard(Color accent) {
    final key = _selectedCategory.name;
    final planText = _categoryPlans[key] ?? '';
    final isLoading = _categoryPlanLoading[key] == true;
    final planHeading = _categoryPlanHeading(_selectedCategory);

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  'KAZ AI is preparing a tailored $planHeading for this project...',
                  style: TextStyle(color: accent, fontSize: 13)),
            ),
          ],
        ),
      );
    } else if (planText.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    planHeading,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _retryCategoryPlan(_selectedCategory),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Regenerate',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              planText,
              style: TextStyle(
                color: _Palette.onSurfaceVariant,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome_outlined,
                color: Color(0xFFB45309), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$planHeading unavailable',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap regenerate to have KAZ AI prepare a tailored, concise plan to get started.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _retryCategoryPlan(_selectedCategory),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text('Generate $planHeading'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF92400E),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── UN SDG Card (Environment tab only) ──
  Widget _buildSdgCard(bool isMobile) {
    if (_isGeneratingSdgs) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _environmentAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _environmentAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  'KAZ AI is identifying applicable UN Sustainable Development Goals...',
                  style: TextStyle(color: _environmentAccent, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    if (_sdgRecommendations.isEmpty && _sdgsLoaded) {
      // No SDGs available
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.public,
                color: Color(0xFFB45309), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UN Sustainable Development Goals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No SDG recommendations generated yet.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      _sdgsLoaded = false;
                      _loadSdgRecommendations();
                    },
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Generate SDG Recommendations'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF92400E),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _environmentAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _environmentAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 16, color: _environmentAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'UN Sustainable Development Goals (Applicable)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _environmentAccent,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _sdgsLoaded = false;
                  _sdgRecommendations.clear();
                  _loadSdgRecommendations();
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Regenerate',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: _environmentAccent,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI has identified the following UN SDGs as most applicable to this project. They are integrated into the environmental planning approach and tracked through KPIs.',
            style: TextStyle(fontSize: 12, color: _Palette.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _sdgRecommendations.map((sdg) {
              return Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _environmentAccent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _environmentAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sdg['goal'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _environmentAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sdg['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _Palette.onBackground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((sdg['rationale'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sdg['rationale']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _Palette.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Initiation Phase Security Callout (Security tab only) ──
  Widget _buildInitiationSecurityCallout() {
    final fep = ProjectDataHelper.getData(context).frontEndPlanning;
    final securityText = fep.security.trim();
    if (securityText.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _securityAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _securityAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 16, color: _securityAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Carried forward from Initiation Phase – Security',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _securityAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The Security plan from the Initiation (Front End Planning) phase has been auto-imported into this section to ensure continuity.',
            style: TextStyle(
              fontSize: 12,
              color: _Palette.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (fep.securityRoles.isNotEmpty ||
              fep.securityPermissions.isNotEmpty ||
              fep.securitySettings.isNotEmpty ||
              fep.securityAccessLogs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (fep.securityRoles.isNotEmpty)
                  _carryForwardChip('Roles', fep.securityRoles.length),
                if (fep.securityPermissions.isNotEmpty)
                  _carryForwardChip('Permissions', fep.securityPermissions.length),
                if (fep.securitySettings.isNotEmpty)
                  _carryForwardChip('Settings', fep.securitySettings.length),
                if (fep.securityAccessLogs.isNotEmpty)
                  _carryForwardChip('Access Logs', fep.securityAccessLogs.length),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _carryForwardChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _securityAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _securityAccent,
        ),
      ),
    );
  }

  // ── Entries Table (scrollable + expandable) ──
  Widget _buildEntriesTable(
      List<SsherEntry> entries, Color accent, bool isMobile) {
    return LayoutBuilder(builder: (context, constraints) {
      // Use horizontal scroll for very wide tables; expandable per row
      return Container(
        decoration: BoxDecoration(
          color: _Palette.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Palette.surfaceVariant),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: isMobile ? 1100 : 1400,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    border: Border(
                        bottom:
                            BorderSide(color: _Palette.surfaceVariant)),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                          width: 40,
                          child: Text('',
                              style: TextStyle(fontSize: 11))),
                      SizedBox(width: 12),
                      Expanded(
                          flex: 3,
                          child: Text('Concern / Item',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 110,
                          child: Text('Department',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 150,
                          child: Text('Owner / Team Member',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 90,
                          child: Text('Risk',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 110,
                          child: Text('Est. Cost',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 120,
                          child: const Text('Sync Status',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 70,
                          child: Text('Actions',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: _Palette.onSurfaceVariant))),
                    ],
                  ),
                ),
                // Rows (each expandable)
                ...entries.map((entry) => _buildExpandableRow(entry, accent)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildExpandableRow(SsherEntry entry, Color accent) {
    // Compute sync status across all integration targets
    final projectData = ProjectDataHelper.getData(context);
    final costEstimateProvider = context.read<CostEstimateProvider>();
    final syncStatus = _computeSyncStatus(entry, projectData, costEstimateProvider);
    return _ExpandableSsherRow(
      entry: entry,
      accent: accent,
      syncStatus: syncStatus,
      onEdit: () => _editEntry(entry),
      onDelete: () => _deleteEntry(entry),
      onAddLog: () => _addLogToEntry(entry),
      onAddChecklist: () => _addChecklistToEntry(entry),
      onAddDocument: () => _addDocumentToEntry(entry),
      onToggleChecklist: (itemId, value) =>
          _toggleChecklistItem(entry, itemId, value),
      onEditLog: (log) => _editLogInEntry(entry, log),
      onDeleteLog: (log) => _deleteLogFromEntry(entry, log),
      onEditChecklist: (item) => _editChecklistInEntry(entry, item),
      onDeleteChecklist: (item) => _deleteChecklistFromEntry(entry, item),
      onEditDocument: (doc) => _editDocumentInEntry(entry, doc),
      onDeleteDocument: (doc) => _deleteDocumentFromEntry(entry, doc),
    );
  }

  /// Computes the sync status of an SSHER entry across all integration targets.
  /// Returns a map of integration name -> boolean (true if pushed).
  Map<String, bool> _computeSyncStatus(
    SsherEntry entry,
    ProjectDataModel projectData,
    CostEstimateProvider costEstimateProvider,
  ) {
    // Cost Estimate: check if any CostLine has basisReference containing 'SSHER:<id>'
    final inCostEstimate = costEstimateProvider.estimate?.lines.any((l) =>
            l.basisReference != null &&
            l.basisReference!.contains('SSHER:${entry.id}')) ??
        false;

    // Risk Register: check if any RiskRegisterItem has riskName 'SSHER <category>: <concern>'
    final expectedRiskName =
        'SSHER ${entry.category}: ${entry.concern}'.trim().toLowerCase();
    final inRiskRegister = projectData.frontEndPlanning.riskRegisterItems
        .any((r) => r.riskName.trim().toLowerCase() == expectedRiskName);

    // Schedule: check if any ScheduleActivity has title 'SSHER <category>: <concern>'
    final expectedActivityTitle = expectedRiskName;
    final inSchedule = projectData.scheduleActivities
        .any((a) => a.title.trim().toLowerCase() == expectedActivityTitle);

    // Requirements: check if any RequirementItem has description 'SSHER <category>: <concern>'
    final inRequirements = projectData.frontEndPlanning.requirementItems
        .any((r) => r.description.trim().toLowerCase() == expectedActivityTitle);

    return {
      'costEstimate': inCostEstimate,
      'riskRegister': inRiskRegister,
      'schedule': inSchedule,
      'requirements': inRequirements,
    };
  }

  // ── Logs / Checklists / Documents per-entry operations ──
  Future<void> _addLogToEntry(SsherEntry entry) async {
    final log = await _showLogDialog();
    if (log == null) return;
    setState(() {
      entry.logs.add(log);
    });
    await _saveEntries();
  }

  Future<void> _addChecklistToEntry(SsherEntry entry) async {
    final item = await _showChecklistDialog();
    if (item == null) return;
    setState(() {
      entry.checklists.add(item);
    });
    await _saveEntries();
  }

  Future<void> _addDocumentToEntry(SsherEntry entry) async {
    final doc = await _showDocumentDialog();
    if (doc == null) return;
    setState(() {
      entry.documents.add(doc);
    });
    await _saveEntries();
  }

  void _toggleChecklistItem(SsherEntry entry, String itemId, bool value) {
    setState(() {
      final item =
          entry.checklists.firstWhere((c) => c.id == itemId, orElse: () => SsherChecklistItem());
      item.checked = value;
    });
    _saveEntries();
  }

  Future<void> _editLogInEntry(SsherEntry entry, SsherLogEntry log) async {
    final updated = await _showLogDialog(initial: log);
    if (updated == null) return;
    setState(() {
      final idx = entry.logs.indexWhere((l) => l.id == log.id);
      if (idx >= 0) entry.logs[idx] = updated;
    });
    await _saveEntries();
  }

  Future<void> _deleteLogFromEntry(SsherEntry entry, SsherLogEntry log) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Log Entry',
      itemLabel: log.title,
    );
    if (!confirmed) return;
    setState(() {
      entry.logs.removeWhere((l) => l.id == log.id);
    });
    await _saveEntries();
  }

  Future<void> _editChecklistInEntry(
      SsherEntry entry, SsherChecklistItem item) async {
    final updated = await _showChecklistDialog(initial: item);
    if (updated == null) return;
    setState(() {
      final idx = entry.checklists.indexWhere((c) => c.id == item.id);
      if (idx >= 0) entry.checklists[idx] = updated;
    });
    await _saveEntries();
  }

  Future<void> _deleteChecklistFromEntry(
      SsherEntry entry, SsherChecklistItem item) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Checklist Item',
      itemLabel: item.label,
    );
    if (!confirmed) return;
    setState(() {
      entry.checklists.removeWhere((c) => c.id == item.id);
    });
    await _saveEntries();
  }

  Future<void> _editDocumentInEntry(SsherEntry entry, SsherDocument doc) async {
    final updated = await _showDocumentDialog(initial: doc);
    if (updated == null) return;
    setState(() {
      final idx = entry.documents.indexWhere((d) => d.id == doc.id);
      if (idx >= 0) entry.documents[idx] = updated;
    });
    await _saveEntries();
  }

  Future<void> _deleteDocumentFromEntry(
      SsherEntry entry, SsherDocument doc) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Document',
      itemLabel: doc.title,
    );
    if (!confirmed) return;
    setState(() {
      entry.documents.removeWhere((d) => d.id == doc.id);
    });
    await _saveEntries();
  }

  Future<SsherLogEntry?> _showLogDialog({SsherLogEntry? initial}) async {
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    final detailsCtrl = TextEditingController(text: initial?.details ?? '');
    final loggedByCtrl = TextEditingController(text: initial?.loggedBy ?? '');
    String type = initial?.type ?? 'Inspection';
    String date = initial?.date ?? DateTime.now().toIso8601String().substring(0, 10);

    return showDialog<SsherLogEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initial == null ? 'Add Log Entry' : 'Edit Log Entry'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Inspection', child: Text('Inspection')),
                      DropdownMenuItem(value: 'Incident', child: Text('Incident')),
                      DropdownMenuItem(value: 'Audit', child: Text('Audit')),
                      DropdownMenuItem(value: 'Review', child: Text('Review')),
                      DropdownMenuItem(value: 'Drill', child: Text('Drill')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => type = v ?? 'Inspection'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsCtrl,
                    decoration: const InputDecoration(labelText: 'Details'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: loggedByCtrl,
                    decoration: const InputDecoration(labelText: 'Logged By'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Date (yyyy-MM-dd)',
                      hintText: date,
                    ),
                    onChanged: (v) {
                      if (v.trim().isNotEmpty) date = v.trim();
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  SsherLogEntry(
                    id: initial?.id,
                    type: type,
                    title: titleCtrl.text.trim(),
                    details: detailsCtrl.text.trim(),
                    loggedBy: loggedByCtrl.text.trim(),
                    date: date,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<SsherChecklistItem?> _showChecklistDialog(
      {SsherChecklistItem? initial}) async {
    final labelCtrl = TextEditingController(text: initial?.label ?? '');
    final notesCtrl = TextEditingController(text: initial?.notes ?? '');
    final dueDateCtrl = TextEditingController(text: initial?.dueDate ?? '');
    bool checked = initial?.checked ?? false;

    return showDialog<SsherChecklistItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initial == null ? 'Add Checklist Item' : 'Edit Checklist Item'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Item Label'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Due Date (yyyy-MM-dd)'),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: checked,
                  onChanged: (v) => setState(() => checked = v ?? false),
                  title: const Text('Completed'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  SsherChecklistItem(
                    id: initial?.id,
                    label: labelCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    dueDate: dueDateCtrl.text.trim(),
                    checked: checked,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<SsherDocument?> _showDocumentDialog({SsherDocument? initial}) async {
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    final ownerCtrl = TextEditingController(text: initial?.owner ?? '');
    final dueDateCtrl = TextEditingController(text: initial?.dueDate ?? '');
    String type = initial?.type ?? 'Plan';
    String status = initial?.status ?? 'Required';

    return showDialog<SsherDocument>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initial == null ? 'Add Document' : 'Edit Document'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Document Title'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'Policy', child: Text('Policy')),
                    DropdownMenuItem(value: 'Plan', child: Text('Plan')),
                    DropdownMenuItem(value: 'Permit', child: Text('Permit')),
                    DropdownMenuItem(value: 'Certificate', child: Text('Certificate')),
                    DropdownMenuItem(value: 'Report', child: Text('Report')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'Plan'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'Required', child: Text('Required')),
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                  ],
                  onChanged: (v) => setState(() => status = v ?? 'Required'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ownerCtrl,
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Due Date (yyyy-MM-dd)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  SsherDocument(
                    id: initial?.id,
                    title: titleCtrl.text.trim(),
                    type: type,
                    status: status,
                    owner: ownerCtrl.text.trim(),
                    dueDate: dueDateCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-section Summary (Logs / Checklists / Documents) ──
  Widget _buildSubsectionSummary(Color accent, bool isMobile) {
    final entries = _entriesForCategory(_selectedCategory);
    final totalLogs =
        entries.fold<int>(0, (sum, e) => sum + e.logs.length);
    final totalChecklists =
        entries.fold<int>(0, (sum, e) => sum + e.checklists.length);
    final completedChecklists = entries.fold<int>(
        0,
        (sum, e) =>
            sum + e.checklists.where((c) => c.checked).length);
    final totalDocs =
        entries.fold<int>(0, (sum, e) => sum + e.documents.length);
    final approvedDocs = entries.fold<int>(
        0, (sum, e) => sum + e.documents.where((d) => d.status == 'Approved').length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'Logs, Checklists & Documents Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _summaryChip('Logs', totalLogs, Icons.receipt_long, accent),
              _summaryChip(
                  'Checklists', '$completedChecklists/$totalChecklists', Icons.checklist, accent),
              _summaryChip(
                  'Documents', '$approvedDocs/$totalDocs approved', Icons.description, accent),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Expand any item row above to view, add, or edit logs, checklists, and documents for that SSHER element.',
            style: TextStyle(
              fontSize: 12,
              color: _Palette.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, dynamic count, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _Palette.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cost Summary Tab ──
  Widget _buildCostSummaryTab(bool isMobile) {
    final allEntries = _allEntries();
    final totalCostByCategory = <String, double>{};
    final currencyTotals = <String, double>{};

    for (final entry in allEntries) {
      final cost = double.tryParse(
              entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      totalCostByCategory[entry.category] =
          (totalCostByCategory[entry.category] ?? 0) + cost;
      currencyTotals[entry.costCurrency] =
          (currencyTotals[entry.costCurrency] ?? 0) + cost;
    }

    final grandTotal =
        totalCostByCategory.values.fold<double>(0, (sum, v) => sum + v);

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _Palette.surfaceVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: _costAccent, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'SSHER Cost Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _Palette.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _Palette.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${allEntries.length} items',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _Palette.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _costAccent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _costAccent.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'This tab aggregates every cost-bearing item from each SSHER tab into a single cost table. Costs are captured per element and roll up into category totals. Use this view to feed the project cost estimate and ensure all SSHER obligations are budgeted.',
              style: TextStyle(
                fontSize: 13,
                color: _Palette.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Integration actions row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _pushToCostEstimate,
                icon: const Icon(Icons.cloud_upload, size: 16),
                label: const Text('Push to Cost Estimate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pullFromCostEstimate,
                icon: const Icon(Icons.cloud_download, size: 16),
                label: const Text('Pull from Cost Estimate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF047857),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pushToSchedule,
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('Push to Schedule'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Palette.primaryContainer,
                  side: BorderSide(
                      color: _Palette.primaryContainer.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadCostSummaryCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _costAccent,
                  side: BorderSide(color: _costAccent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadCostSummaryPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Palette.onSurfaceVariant,
                  side: const BorderSide(color: _Palette.outlineVariant),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category totals cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final cat in [
                _SsherCategory.safety,
                _SsherCategory.security,
                _SsherCategory.health,
                _SsherCategory.environment,
                _SsherCategory.regulatory,
              ])
                _categoryCostCard(
                    cat, totalCostByCategory[cat.name] ?? 0.0),
            ],
          ),
          const SizedBox(height: 16),

          // Grand Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _Palette.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total SSHER Cost (all categories)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _formatCurrency(grandTotal, 'USD'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detailed cost table (scrollable + expandable)
          if (allEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _Palette.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _Palette.surfaceVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Icon(Icons.attach_money,
                      size: 40, color: _costAccent.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'No SSHER items yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _Palette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add items to any SSHER tab to populate the cost summary.',
                    style: TextStyle(
                        fontSize: 14, color: _Palette.outline),
                  ),
                ],
              ),
            )
          else
            _buildCostDetailTable(allEntries, isMobile),
        ],
      ),
    );
  }

  Widget _categoryCostCard(_SsherCategory cat, double total) {
    final accent = _accentForCategory(cat);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForCategory(cat), size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                _categoryLabel(cat),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(total, 'USD'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _Palette.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostDetailTable(List<SsherEntry> entries, bool isMobile) {
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        decoration: BoxDecoration(
          color: _Palette.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Palette.surfaceVariant),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: isMobile ? 1100 : 1400,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _costAccent.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    border: Border(
                        bottom:
                            BorderSide(color: _Palette.surfaceVariant)),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                          width: 90,
                          child: Text('Category',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      Expanded(
                          flex: 4,
                          child: Text('Item / Concern',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 120,
                          child: Text('Department',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 110,
                          child: Text('Amount',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 90,
                          child: Text('Currency',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 110,
                          child: Text('Frequency',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 110,
                          child: Text('Unit',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _Palette.onSurfaceVariant))),
                    ],
                  ),
                ),
                // Rows
                ...entries.map((entry) {
                  final accent = _accentForCategory(_SsherCategory.values
                      .firstWhere((c) => c.name == entry.category,
                          orElse: () => _SsherCategory.safety));
                  final cost = double.tryParse(entry.estimatedCost
                          .replaceAll(',', '')
                          .replaceAll('\$', '')) ??
                      0.0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: _Palette.surfaceVariant
                                  .withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoryLabel(_SsherCategory.values.firstWhere(
                                (c) => c.name == entry.category,
                                orElse: () => _SsherCategory.safety)),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Text(
                            entry.concern.isNotEmpty
                                ? entry.concern
                                : 'Untitled',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _Palette.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Text(
                            entry.department,
                            style: const TextStyle(
                                fontSize: 12,
                                color: _Palette.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _formatCurrency(cost, entry.costCurrency),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _Palette.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Text(entry.costCurrency,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _Palette.onSurfaceVariant)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(entry.costFrequency,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _Palette.onSurfaceVariant)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(entry.costUnit,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _Palette.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  );
                }),
                // Footer total
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _costAccent.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                    border: Border(
                        top:
                            BorderSide(color: _costAccent.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 90),
                      const SizedBox(width: 12),
                      const Expanded(
                        flex: 4,
                        child: Text('GRAND TOTAL',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _Palette.onBackground)),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 120),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: Text(
                          _formatCurrency(grandTotalValue(entries), 'USD'),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _Palette.onBackground,
                          ),
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
    });
  }

  double grandTotalValue(List<SsherEntry> entries) {
    return entries.fold<double>(
        0,
        (sum, e) =>
            sum +
            (double.tryParse(e.estimatedCost
                    .replaceAll(',', '')
                    .replaceAll('\$', '')) ??
                0.0));
  }

  String _formatCurrency(double amount, String currency) {
    final symbol = currency == 'USD'
        ? '\$'
        : currency == 'ZMW'
            ? 'K '
            : currency == 'EUR'
                ? '€'
                : currency == 'GBP'
                    ? '£'
                    : currency == 'ZAR'
                        ? 'R '
                        : '$currency ';
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  // ── Stakeholder Confirmation ──
  Widget _buildStakeholderConfirmation() {
    final requiredTabs = {
      _SsherCategory.safety,
      _SsherCategory.security,
      _SsherCategory.health,
      _SsherCategory.environment,
      _SsherCategory.regulatory,
    };
    final visitedCount =
        requiredTabs.intersection(_visitedTabs).length;
    final allVisited = visitedCount == requiredTabs.length;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _stakeholderConfirmed
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _stakeholderConfirmed
                ? const Color(0xFFA7F3D0)
                : const Color(0xFFFDE68A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _stakeholderConfirmed
                      ? Icons.verified
                      : Icons.pending_actions,
                  color: _stakeholderConfirmed
                      ? const Color(0xFF047857)
                      : const Color(0xFFB45309),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSHER Stakeholder Review & Confirmation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _stakeholderConfirmed
                              ? const Color(0xFF047857)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tab review progress: $visitedCount / ${requiredTabs.length} sections visited.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _stakeholderConfirmed
                              ? const Color(0xFF047857)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final cat in requiredTabs)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                _visitedTabs.contains(cat)
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: _visitedTabs.contains(cat)
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Safety · Security · Health · Environment · Regulatory',
                              style: TextStyle(
                                fontSize: 11,
                                color: _stakeholderConfirmed
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: allVisited ? 1.0 : 0.5,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _stakeholderConfirmed,
                              onChanged: allVisited
                                  ? (v) {
                                      setState(() {
                                        _stakeholderConfirmed = v ?? false;
                                      });
                                      _saveStakeholderConfirmation(
                                          _stakeholderConfirmed);
                                    }
                                  : null,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I confirm that the appropriate stakeholders have reviewed and aligned on the applicable SSHER sections.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _stakeholderConfirmed
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF92400E),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!allVisited) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'You must visit all 5 SSHER tabs before you can confirm.',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading State ──
  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              'KAZ AI is generating SSHER entries...',
              style: TextStyle(color: _Palette.primary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState(Color accent, String catLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _Palette.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _Palette.surfaceVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline,
              size: 40, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No $catLabel items yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _Palette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Item" to create your first $catLabel entry, or let KAZ AI generate suggestions.',
            style: TextStyle(fontSize: 14, color: _Palette.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _handleAddItem(),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add $catLabel Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save & Continue Button ──
  Widget _buildSaveContinueButton() {
    final requiredTabs = {
      _SsherCategory.safety,
      _SsherCategory.security,
      _SsherCategory.health,
      _SsherCategory.environment,
      _SsherCategory.regulatory,
    };
    final allVisited =
        requiredTabs.difference(_visitedTabs).isEmpty;
    final canContinue = allVisited && _stakeholderConfirmed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: _ScaleOnTap(
          onTap: () => _handleNextWithConfirmation(),
          child: Container(
            decoration: BoxDecoration(
              color: canContinue
                  ? _Palette.tertiaryFixedDim
                  : _Palette.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              boxShadow: canContinue
                  ? [
                      BoxShadow(
                        color: _Palette.tertiaryFixedDim
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _handleNextWithConfirmation(),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        canContinue
                            ? 'Save & Continue to Quality'
                            : 'Review all tabs & confirm to continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: canContinue
                              ? _Palette.onTertiaryFixed
                              : _Palette.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward,
                          size: 20,
                          color: canContinue
                              ? _Palette.onTertiaryFixed
                              : _Palette.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Handle Add Item ──
  Future<void> _handleAddItem() async {
    Color accentColor;
    IconData icon;
    String heading;
    String blurb;
    String concernLabel;

    switch (_selectedCategory) {
      case _SsherCategory.safety:
        accentColor = _safetyAccent;
        icon = Icons.health_and_safety;
        heading = 'Add Safety Item';
        blurb = 'Provide details for the new safety record.';
        concernLabel = 'Safety Concern';
        break;
      case _SsherCategory.security:
        accentColor = _securityAccent;
        icon = Icons.shield_outlined;
        heading = 'Add Security Item';
        blurb = 'Provide details for the new security record.';
        concernLabel = 'Security Concern';
        break;
      case _SsherCategory.health:
        accentColor = _healthAccent;
        icon = Icons.volunteer_activism_outlined;
        heading = 'Add Health Item';
        blurb = 'Provide details for the new health record.';
        concernLabel = 'Health Concern';
        break;
      case _SsherCategory.environment:
        accentColor = _environmentAccent;
        icon = Icons.eco_outlined;
        heading = 'Add Environment Item';
        blurb = 'Provide details for the new environmental record.';
        concernLabel = 'Environmental Concern';
        break;
      case _SsherCategory.regulatory:
        accentColor = _regulatoryAccent;
        icon = Icons.gavel_outlined;
        heading = 'Add Regulatory Item';
        blurb = 'Provide details for the new compliance record.';
        concernLabel = 'Regulatory Requirement';
        break;
      case _SsherCategory.cost:
        // Cost tab is read-only summary
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'The Cost Summary tab is a roll-up of all SSHER items. Add items in Safety, Security, Health, Environment, or Regulatory tabs.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
    }

    final projectData = ProjectDataHelper.getData(context);
    final result = await showDialog<SsherItemInput>(
      context: context,
      builder: (ctx) => AddSsherItemDialog(
        accentColor: accentColor,
        icon: icon,
        heading: heading,
        blurb: blurb,
        concernLabel: concernLabel,
        riskRegisterItems: projectData.frontEndPlanning.riskRegisterItems,
        staffingRows: projectData.frontEndPlanning.staffingRows,
        requirementItems: projectData.frontEndPlanning.requirementItems,
      ),
    );
    if (result == null) return;
    await _addEntry(_selectedCategory, result);
  }

  // ── Cross-Discipline Integration: Push to Cost Estimate ──
  Future<void> _pushToCostEstimate() async {
    final allEntries = _allEntries();
    final costableEntries = allEntries.where((e) {
      final cost = double.tryParse(
          e.estimatedCost.replaceAll(',', '').replaceAll('\$', ''));
      return cost != null && cost > 0;
    }).toList();

    if (costableEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No SSHER items with a non-zero estimated cost to push. Add cost amounts to your SSHER items first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push SSHER Costs to Cost Estimate'),
        content: Text(
            'This will create ${costableEntries.length} new cost line items in the Cost Estimate module (one per SSHER item with a cost). Each item will be categorized as SSHER and reference the originating SSHER entry. Existing cost lines will not be modified.\n\nDo you want to proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Push to Cost Estimate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = context.read<CostEstimateProvider>();

    // Auto-setup a default Cost Estimate if none exists yet
    if (provider.estimate == null) {
      final projectName =
          ProjectDataHelper.getData(context).projectName;
      provider.setup(
        projectName: projectName.isNotEmpty ? projectName : 'SSHER Import',
        className: EstimateClass.class3,
        deliveryModel: DeliveryModel.waterfall,
      );
    }

    int pushed = 0;
    int skipped = 0;
    for (final entry in costableEntries) {
      final cost = double.tryParse(
              entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      if (cost <= 0) {
        skipped++;
        continue;
      }
      // De-dup: skip if a line with the same basisReference already exists
      final existing = provider.estimate?.lines.any((l) =>
              l.basisReference != null &&
              l.basisReference!.contains('SSHER:${entry.id}')) ??
          false;
      if (existing) {
        skipped++;
        continue;
      }
      final line = CostLine(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CostCategory.ssher,
        subCategory:
            '${_categoryLabel(_SsherCategory.values.firstWhere((c) => c.name == entry.category, orElse: () => _SsherCategory.safety))} — ${entry.department}',
        description: entry.concern.isNotEmpty
            ? '${entry.concern} — ${entry.mitigation}'
            : 'SSHER ${entry.category} item',
        quantity: 1,
        unit: entry.costUnit.isNotEmpty ? entry.costUnit : 'lump sum',
        rate: cost,
        total: cost,
        inSchedule: false,
        basisSource: CostSourceType.expertJudgment,
        basisReference: 'SSHER:${entry.id} — Imported from SSHER Hub',
        aiGenerated: false,
        confidence: Confidence.med,
      );
      provider.addLine(line);
      pushed++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Pushed $pushed SSHER cost item${pushed == 1 ? '' : 's'} to Cost Estimate${skipped > 0 ? ' ($skipped skipped — already present or zero cost)' : ''}.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View Cost Estimate',
          onPressed: () {
            // Navigate to cost estimate screen
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _CostEstimateRoutePlaceholder(),
            ));
          },
        ),
      ),
    );
  }

  // ── Reverse-Sync: Pull from Cost Estimate ──
  /// Scans the CostEstimateProvider for CostLines whose basisReference
  /// contains 'SSHER:<id>' and updates the corresponding SSHER entry's
  /// estimatedCost to match the CostLine's current total. Used when the user
  /// has refined the cost in the Cost Estimate module and wants to pull
  /// those changes back into the SSHER Hub.
  Future<void> _pullFromCostEstimate() async {
    final provider = context.read<CostEstimateProvider>();
    final estimate = provider.estimate;
    if (estimate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No Cost Estimate exists yet. Set up the Cost Estimate module first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Build a map of ssherEntryId -> latest CostLine total
    final costLineBySsherId = <String, double>{};
    for (final line in estimate.lines) {
      final ref = line.basisReference ?? '';
      if (!ref.contains('SSHER:')) continue;
      // Extract the SSHER id (text after 'SSHER:' up to the next space or dash)
      final match = RegExp(r'SSHER:([^\s—–-]+)').firstMatch(ref);
      if (match == null) continue;
      final ssherId = match.group(1)!.trim();
      // Use the most recent (highest total) value if there are duplicates
      costLineBySsherId[ssherId] = line.total;
    }

    if (costLineBySsherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No Cost Estimate lines reference SSHER items. Push SSHER costs to the Cost Estimate first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pull Cost Updates from Cost Estimate'),
        content: Text(
            'This will scan the Cost Estimate for lines linked to SSHER items and update ${costLineBySsherId.length} SSHER entr${costLineBySsherId.length == 1 ? 'y' : 'ies'} with the current cost from the Cost Estimate. Any manual edits to the SSHER estimatedCost field will be overwritten.\n\nDo you want to proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Pull Updates'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int updated = 0;
    int unchanged = 0;
    final allEntries = _allEntries();
    for (final entry in allEntries) {
      final newCost = costLineBySsherId[entry.id];
      if (newCost == null) continue;
      final currentCost = double.tryParse(
              entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      if ((newCost - currentCost).abs() < 0.01) {
        unchanged++;
        continue;
      }
      entry.estimatedCost = newCost.toStringAsFixed(2);
      updated++;
    }

    if (updated > 0) {
      await _saveEntries();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Pulled cost updates from Cost Estimate: $updated updated, $unchanged unchanged.'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Push All Integrations (one-click orchestrator) ──
  /// Runs Push to Cost Estimate + Push to Risk Register (all categories) +
  /// Push to Schedule + Add All Requirements in sequence, with a progress
  /// dialog showing each step. Skips steps that have nothing to push.
  Future<void> _pushAllIntegrations() async {
    final allEntries = _allEntries();
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No SSHER items to push. Add items in the SSHER tabs first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Confirm with the user before running
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push All SSHER Integrations'),
        content: const Text(
            'This will run all four integrations in sequence:\n\n'
            '1. Push to Cost Estimate — creates CostLine items for every SSHER item with a cost\n'
            '2. Push to Risk Register — creates RiskRegisterItem entries from High/Medium-risk SSHER items (all 5 categories)\n'
            '3. Push to Schedule — creates ScheduleActivity items for every SSHER item\n'
            '4. Add All Requirements — adds regulatory/compliance requirements suggested by SSHER items\n\n'
            'Each step de-duplicates against existing entries so nothing will be created twice. '
            'A progress dialog will show the status of each step.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Run All Integrations'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show a progress dialog
    final progressController = StreamController<_PushAllProgress>.broadcast();

    // Run the steps in a microtask so the dialog can render first
    final resultFuture = _executePushAllSteps(progressController);

    // Show the progress dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PushAllProgressDialog(
        progressStream: progressController.stream,
      ),
    );

    final result = await resultFuture;
    await progressController.close();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Push All Integrations complete: ${result.costEstimatePushed} cost items, ${result.riskRegisterPushed} risks, ${result.schedulePushed} activities, ${result.requirementsPushed} requirements.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<_PushAllResult> _executePushAllSteps(
    StreamController<_PushAllProgress> controller) async {
    int costPushed = 0;
    int riskPushed = 0;
    int schedulePushed = 0;
    int reqsPushed = 0;

    // Step 1: Push to Cost Estimate
    controller.add(_PushAllProgress(
      step: 1,
      totalSteps: 4,
      label: 'Pushing to Cost Estimate…',
      inProgress: true,
    ));
    try {
      final provider = context.read<CostEstimateProvider>();
      if (provider.estimate == null) {
        final projectName = ProjectDataHelper.getData(context).projectName;
        provider.setup(
          projectName: projectName.isNotEmpty ? projectName : 'SSHER Import',
          className: EstimateClass.class3,
          deliveryModel: DeliveryModel.waterfall,
        );
      }
      for (final entry in _allEntries()) {
        final cost = double.tryParse(
                entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
            0.0;
        if (cost <= 0) continue;
        final existing = provider.estimate?.lines.any((l) =>
                l.basisReference != null &&
                l.basisReference!.contains('SSHER:${entry.id}')) ??
            false;
        if (existing) continue;
        provider.addLine(CostLine(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          category: CostCategory.ssher,
          subCategory:
              '${_categoryLabel(_SsherCategory.values.firstWhere((c) => c.name == entry.category, orElse: () => _SsherCategory.safety))} — ${entry.department}',
          description: entry.concern.isNotEmpty
              ? '${entry.concern} — ${entry.mitigation}'
              : 'SSHER ${entry.category} item',
          quantity: 1,
          unit: entry.costUnit.isNotEmpty ? entry.costUnit : 'lump sum',
          rate: cost,
          total: cost,
          inSchedule: false,
          basisSource: CostSourceType.expertJudgment,
          basisReference: 'SSHER:${entry.id} — Pushed via Push All Integrations',
          aiGenerated: false,
          confidence: Confidence.med,
        ));
        costPushed++;
      }
    } catch (e) {
      debugPrint('PushAll: Cost Estimate step failed: $e');
    }
    controller.add(_PushAllProgress(
      step: 1,
      totalSteps: 4,
      label: 'Cost Estimate: $costPushed item${costPushed == 1 ? '' : 's'} pushed',
      inProgress: false,
    ));

    // Step 2: Push to Risk Register (all 5 categories)
    controller.add(_PushAllProgress(
      step: 2,
      totalSteps: 4,
      label: 'Pushing to Risk Register…',
      inProgress: true,
    ));
    try {
      final projectData = ProjectDataHelper.getData(context);
      final existingRiskNames = projectData.frontEndPlanning.riskRegisterItems
          .where((r) => r.requirementType.trim().toLowerCase() == 'ssher')
          .map((r) => r.riskName.trim().toLowerCase())
          .toSet();
      for (final cat in [
        _SsherCategory.safety,
        _SsherCategory.security,
        _SsherCategory.health,
        _SsherCategory.environment,
        _SsherCategory.regulatory,
      ]) {
        for (final e in _entriesForCategory(cat)) {
          final level = e.riskLevel.trim().toLowerCase();
          if (level != 'high' && level != 'medium') continue;
          final riskName = 'SSHER ${e.category}: ${e.concern}';
          if (existingRiskNames.contains(riskName.trim().toLowerCase())) {
            continue;
          }
          await ProjectDataHelper.upsertRiskToRegister(
            context: context,
            sourceSection: 'SSHER',
            riskName: riskName,
            description: e.mitigation.isNotEmpty
                ? 'SSHER ${e.category} concern: ${e.concern}. Mitigation: ${e.mitigation}'
                : 'SSHER ${e.category} concern: ${e.concern}',
            category: _categoryLabel(cat),
            impactLevel: e.riskLevel,
            likelihood: 'Medium',
            mitigationStrategy: e.mitigation.isNotEmpty
                ? e.mitigation
                : 'Mitigation plan in progress — see SSHER Hub for details.',
            discipline: e.department,
            owner: e.teamMember,
            status: 'Open',
          );
          unawaited(ProjectDataHelper.logActivityToCentral(
            context: context,
            sourceSection: 'SSHER',
            title: 'SSHER risk pushed: $riskName',
            description: 'Category: ${_categoryLabel(cat)}. Impact: ${e.riskLevel}',
            phase: 'Planning',
            discipline: e.department,
            role: e.teamMember,
          ));
          existingRiskNames.add(riskName.trim().toLowerCase());
          riskPushed++;
        }
      }
    } catch (e) {
      debugPrint('PushAll: Risk Register step failed: $e');
    }
    controller.add(_PushAllProgress(
      step: 2,
      totalSteps: 4,
      label: 'Risk Register: $riskPushed risk${riskPushed == 1 ? '' : 's'} pushed',
      inProgress: false,
    ));

    // Step 3: Push to Schedule
    controller.add(_PushAllProgress(
      step: 3,
      totalSteps: 4,
      label: 'Pushing to Schedule…',
      inProgress: true,
    ));
    try {
      final projectData = ProjectDataHelper.getData(context);
      final existingTitles = projectData.scheduleActivities
          .map((a) => a.title.trim().toLowerCase())
          .toSet();
      final milestoneStart =
          projectData.frontEndPlanning.milestoneStartDate.trim();
      DateTime startDate;
      if (milestoneStart.isNotEmpty) {
        startDate = DateTime.tryParse(milestoneStart) ?? DateTime.now();
      } else {
        startDate = DateTime.now().add(const Duration(days: 30));
      }
      final dueDate = startDate.add(const Duration(days: 5));
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final newActivities = <ScheduleActivity>[];
      for (final e in _allEntries()) {
        final title = 'SSHER ${e.category}: ${e.concern}'.trim().toLowerCase();
        if (existingTitles.contains(title)) continue;
        newActivities.add(ScheduleActivity(
          title: 'SSHER ${e.category}: ${e.concern}',
          durationDays: 5,
          isMilestone: false,
          status: 'pending',
          priority: e.riskLevel.toLowerCase() == 'high'
              ? 'high'
              : e.riskLevel.toLowerCase() == 'medium'
                  ? 'medium'
                  : 'low',
          assignee: e.teamMember,
          discipline: e.department,
          progress: 0,
          startDate: fmt(startDate),
          dueDate: fmt(dueDate),
          phase: 'execution',
          estimatingBasis:
              'Auto-created via Push All Integrations. Mitigation: ${e.mitigation}',
        ));
        existingTitles.add(title);
      }
      if (newActivities.isNotEmpty) {
        final combined = [
          ...projectData.scheduleActivities,
          ...newActivities,
        ];
        await ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: 'ssher_push_all_schedule',
          showSnackbar: false,
          dataUpdater: (d) => d.copyWith(scheduleActivities: combined),
        );
        schedulePushed = newActivities.length;
      }
    } catch (e) {
      debugPrint('PushAll: Schedule step failed: $e');
    }
    controller.add(_PushAllProgress(
      step: 3,
      totalSteps: 4,
      label: 'Schedule: $schedulePushed activit${schedulePushed == 1 ? 'y' : 'ies'} pushed',
      inProgress: false,
    ));

    // Step 4: Add All Requirements
    controller.add(_PushAllProgress(
      step: 4,
      totalSteps: 4,
      label: 'Adding Requirements…',
      inProgress: true,
    ));
    try {
      final gaps = _computeRequirementsGaps();
      if (gaps.isNotEmpty) {
        final projectData = ProjectDataHelper.getData(context);
        final reqs = List<RequirementItem>.from(
            projectData.frontEndPlanning.requirementItems);
        final existingDescs = reqs
            .map((r) => r.description.trim().toLowerCase())
            .toSet();
        for (final gap in gaps) {
          final desc = (gap['proposedDescription'] as String).trim();
          if (existingDescs.contains(desc.toLowerCase())) continue;
          reqs.add(RequirementItem(
            description: desc,
            requirementType:
                (gap['proposedType'] as String?) ?? 'Regulatory',
            discipline: (gap['proposedDiscipline'] as String?) ?? '',
            role: (gap['proposedRole'] as String?) ?? '',
            requirementSource: 'SSHER Hub Push All Integrations',
            comments: 'Auto-suggested from SSHER ${gap['category']} item.',
          ));
          existingDescs.add(desc.toLowerCase());
          reqsPushed++;
        }
        if (reqsPushed > 0) {
          await ProjectDataHelper.updateAndSave(
            context: context,
            checkpoint: 'ssher_push_all_reqs',
            showSnackbar: false,
            dataUpdater: (d) => d.copyWith(
              frontEndPlanning:
                  d.frontEndPlanning.copyWith(requirementItems: reqs),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('PushAll: Requirements step failed: $e');
    }
    controller.add(_PushAllProgress(
      step: 4,
      totalSteps: 4,
      label: 'Requirements: $reqsPushed added',
      inProgress: false,
      done: true,
    ));

    return _PushAllResult(
      costEstimatePushed: costPushed,
      riskRegisterPushed: riskPushed,
      schedulePushed: schedulePushed,
      requirementsPushed: reqsPushed,
    );
  }

  // ── Cross-Discipline Integration: Export Cost Summary as CSV ──
  Future<void> _downloadCostSummaryCsv() async {
    final allEntries = _allEntries();
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No SSHER items to export.'),
            duration: Duration(seconds: 3)),
      );
      return;
    }
    final csv = SsherExportHelper.costSummaryToCsv(allEntries);
    await SsherExportHelper.downloadCsv(csv, 'ssher_cost_summary.csv');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Exported ${allEntries.length} SSHER cost items to ssher_cost_summary.csv. Import this file in the Cost Estimate module.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Cross-Discipline Integration: Export Cost Summary as PDF ──
  Future<void> _downloadCostSummaryPdf() async {
    final allEntries = _allEntries();
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No SSHER items to export.'),
            duration: Duration(seconds: 3)),
      );
      return;
    }
    await SsherExportHelper.exportCostSummaryToPdf(allEntries);
  }

  // ── Cross-Discipline Integration: Push to Risk Register ──
  Future<void> _pushToRiskRegister(_SsherCategory cat) async {
    final entries = _entriesForCategory(cat);
    // Only push high and medium risk items
    final riskableEntries = entries.where((e) {
      final level = e.riskLevel.trim().toLowerCase();
      return level == 'high' || level == 'medium';
    }).toList();

    if (riskableEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No High or Medium risk ${_categoryLabel(cat)} items to push. Only High/Medium risk SSHER items are pushed to the Risk Register.'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Check for duplicates against existing risk register items
    final projectData = ProjectDataHelper.getData(context);
    final existingRiskNames = projectData.frontEndPlanning.riskRegisterItems
        .map((r) => r.riskName.trim().toLowerCase())
        .toSet();

    final toPush = riskableEntries
        .where((e) =>
            !existingRiskNames.contains(
                'SSHER ${e.category}: ${e.concern}'.trim().toLowerCase()))
        .toList();

    if (toPush.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'All ${riskableEntries.length} ${_categoryLabel(cat)} risk item${riskableEntries.length == 1 ? '' : 's'} already exist in the Risk Register.'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push SSHER Risks to Risk Register'),
        content: Text(
            '${toPush.length} new risk item${toPush.length == 1 ? '' : 's'} will be created in the Risk Register from your ${_categoryLabel(cat)} tab. Each will be flagged with category="${_categoryLabel(cat)}" and owner=the SSHER team member. Existing risks will not be modified.\n\nDo you want to proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Push to Risk Register'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Use the bidirectional sync helper — upserts each risk with
    // sourceSection='SSHER' (stored in requirementType) and preserves the
    // per-discipline category label. Also logs to central activities log.
    int pushed = 0;
    for (final e in toPush) {
      final riskName = 'SSHER ${e.category}: ${e.concern}';
      await ProjectDataHelper.upsertRiskToRegister(
        context: context,
        sourceSection: 'SSHER',
        riskName: riskName,
        description: e.mitigation.isNotEmpty
            ? 'SSHER ${e.category} concern: ${e.concern}. Mitigation: ${e.mitigation}'
            : 'SSHER ${e.category} concern: ${e.concern}',
        category: _categoryLabel(cat),
        impactLevel: e.riskLevel,
        likelihood: 'Medium',
        mitigationStrategy: e.mitigation.isNotEmpty
            ? e.mitigation
            : 'Mitigation plan in progress — see SSHER Hub for details.',
        discipline: e.department,
        owner: e.teamMember,
        status: 'Open',
      );
      unawaited(ProjectDataHelper.logActivityToCentral(
        context: context,
        sourceSection: 'SSHER',
        title: 'SSHER risk pushed: $riskName',
        description: 'Category: ${_categoryLabel(cat)}. Impact: ${e.riskLevel}. Owner: ${e.teamMember}',
        phase: 'Planning',
        discipline: e.department,
        role: e.teamMember,
      ));
      pushed++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Pushed $pushed ${_categoryLabel(cat)} risk item${pushed == 1 ? '' : 's'} to the Risk Register.'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Staffing Gap Analysis ──
  /// Returns a list of SSHER-required roles (teamMember field) that are not
  /// present in the Staffing Plan. Each entry is a tuple of (role name, count).
  List<Map<String, dynamic>> _computeStaffingGaps() {
    final projectData = ProjectDataHelper.getData(context);
    final staffingRows = projectData.frontEndPlanning.staffingRows;
    final staffingRoles = staffingRows
        .map((r) => r.role.trim().toLowerCase())
        .where((r) => r.isNotEmpty)
        .toSet();

    final allEntries = _allEntries();
    final roleCounts = <String, int>{};
    final roleExamples = <String, List<SsherEntry>>{};

    for (final e in allEntries) {
      final role = e.teamMember.trim();
      if (role.isEmpty) continue;
      // Skip generic placeholder roles
      if (role.toLowerCase() == 'owner' ||
          role.toLowerCase() == 'unassigned' ||
          role.toLowerCase().startsWith('owner ')) {
        continue;
      }
      final roleKey = role.toLowerCase();
      if (!staffingRoles.contains(roleKey)) {
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
        roleExamples.putIfAbsent(role, () => []);
        if (roleExamples[role]!.length < 3) {
          roleExamples[role]!.add(e);
        }
      }
    }

    return roleCounts.entries
        .map((e) => {
              'role': e.key,
              'count': e.value,
              'examples': roleExamples[e.key]!,
            })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Future<void> _addRoleToStaffingPlan(String role) async {
    final projectData = ProjectDataHelper.getData(context);
    final staffingRows =
        List<StaffingRow>.from(projectData.frontEndPlanning.staffingRows);

    // De-dup check
    final exists = staffingRows.any((r) =>
        r.role.trim().toLowerCase() == role.trim().toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$role" is already in the Staffing Plan.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    staffingRows.add(StaffingRow(
      role: role,
      quantity: 1,
      isInternal: true,
      status: 'Not Started',
      notes: 'Added from SSHER Hub gap analysis',
    ));

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_staffing_gap_add',
      dataUpdater: (d) => d.copyWith(
        frontEndPlanning: d.frontEndPlanning.copyWith(
          staffingRows: staffingRows,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {}); // Refresh the gap view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$role" to the Staffing Plan.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _addAllStaffingGaps() async {
    final gaps = _computeStaffingGaps();
    if (gaps.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add All SSHER Roles to Staffing Plan'),
        content: Text(
            'This will add ${gaps.length} new role${gaps.length == 1 ? '' : 's'} to the Staffing Plan:\n\n${gaps.map((g) => '• ${g['role']}').join('\n')}\n\nEach role will be added with quantity=1 and status=Not Started. Existing roles will not be modified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Add All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final projectData = ProjectDataHelper.getData(context);
    final staffingRows =
        List<StaffingRow>.from(projectData.frontEndPlanning.staffingRows);
    final existingRoles = staffingRows
        .map((r) => r.role.trim().toLowerCase())
        .toSet();

    int added = 0;
    for (final gap in gaps) {
      final role = gap['role'] as String;
      if (existingRoles.contains(role.toLowerCase())) continue;
      staffingRows.add(StaffingRow(
        role: role,
        quantity: 1,
        isInternal: true,
        status: 'Not Started',
        notes: 'Added from SSHER Hub gap analysis',
      ));
      existingRoles.add(role.toLowerCase());
      added++;
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_staffing_gap_add_all',
      dataUpdater: (d) => d.copyWith(
        frontEndPlanning: d.frontEndPlanning.copyWith(
          staffingRows: staffingRows,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Added $added role${added == 1 ? '' : 's'} to the Staffing Plan.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Auto-Sync to Cost Estimate ──
  Future<void> _setAutoSyncToCostEstimate(bool value) async {
    setState(() => _autoSyncToCostEstimate = value);
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_autosync_toggle',
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        ssherData:
            data.ssherData.copyWith(autoSyncToCostEstimate: value),
      ),
    );
    // If turning on, mark all current entries as already-synced so we don't
    // retroactively push them. New/edited entries from now on will auto-sync.
    if (value) {
      _autoSyncedEntryIds.clear();
      for (final e in _allEntries()) {
        _autoSyncedEntryIds.add(e.id);
      }
    } else {
      _autoSyncedEntryIds.clear();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Auto-sync enabled. New SSHER cost items will be pushed to Cost Estimate automatically on save.'
            : 'Auto-sync disabled. Use the "Push to Cost Estimate" button on the Cost Summary tab to push manually.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Called from `_saveEntries` after entries are persisted. If auto-sync is
  /// on, any entry with a non-zero cost that hasn't been synced yet is pushed
  /// to the CostEstimateProvider as a CostLine.
  Future<void> _autoSyncNewCostItems() async {
    if (!_autoSyncToCostEstimate) return;
    final provider = context.read<CostEstimateProvider>();
    // Auto-setup a default Cost Estimate if none exists yet
    if (provider.estimate == null) {
      final projectName = ProjectDataHelper.getData(context).projectName;
      provider.setup(
        projectName: projectName.isNotEmpty ? projectName : 'SSHER Import',
        className: EstimateClass.class3,
        deliveryModel: DeliveryModel.waterfall,
      );
    }
    int pushed = 0;
    for (final entry in _allEntries()) {
      if (_autoSyncedEntryIds.contains(entry.id)) continue;
      final cost = double.tryParse(
              entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      if (cost <= 0) {
        _autoSyncedEntryIds.add(entry.id);
        continue;
      }
      // De-dup: skip if a line with the same basisReference already exists
      final existing = provider.estimate?.lines.any((l) =>
              l.basisReference != null &&
              l.basisReference!.contains('SSHER:${entry.id}')) ??
          false;
      if (existing) {
        _autoSyncedEntryIds.add(entry.id);
        continue;
      }
      final line = CostLine(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CostCategory.ssher,
        subCategory:
            '${_categoryLabel(_SsherCategory.values.firstWhere((c) => c.name == entry.category, orElse: () => _SsherCategory.safety))} — ${entry.department}',
        description: entry.concern.isNotEmpty
            ? '${entry.concern} — ${entry.mitigation}'
            : 'SSHER ${entry.category} item',
        quantity: 1,
        unit: entry.costUnit.isNotEmpty ? entry.costUnit : 'lump sum',
        rate: cost,
        total: cost,
        inSchedule: false,
        basisSource: CostSourceType.expertJudgment,
        basisReference: 'SSHER:${entry.id} — Auto-synced from SSHER Hub',
        aiGenerated: false,
        confidence: Confidence.med,
      );
      provider.addLine(line);
      _autoSyncedEntryIds.add(entry.id);
      pushed++;
    }
    if (pushed > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Auto-synced $pushed new SSHER cost item${pushed == 1 ? '' : 's'} to Cost Estimate.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Push to Schedule ──
  Future<void> _pushToSchedule() async {
    final allEntries = _allEntries();
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No SSHER items to push to the Schedule.'),
            duration: Duration(seconds: 3)),
      );
      return;
    }

    final projectData = ProjectDataHelper.getData(context);
    final existingActivityTitles = projectData.scheduleActivities
        .map((a) => a.title.trim().toLowerCase())
        .toSet();

    // Build a candidate schedule activity for each SSHER entry that doesn't
    // already exist. Default duration is 5 days, default start = +30 days
    // from project milestone start (or today if missing).
    final candidates = allEntries.where((e) {
      final title = 'SSHER ${e.category}: ${e.concern}'.trim().toLowerCase();
      return !existingActivityTitles.contains(title);
    }).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'All ${allEntries.length} SSHER item${allEntries.length == 1 ? '' : 's'} already have corresponding schedule activities.'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push SSHER Items to Schedule'),
        content: Text(
            '${candidates.length} new schedule activit${candidates.length == 1 ? 'y' : 'ies'} will be created from your SSHER items. Each activity will be:\n\n• Title: "SSHER <category>: <concern>"\n• Duration: 5 days\n• Start: ${projectData.frontEndPlanning.milestoneStartDate.isNotEmpty ? projectData.frontEndPlanning.milestoneStartDate : "today + 30 days"}\n• Discipline: <SSHER department>\n• Assignee: <SSHER team member>\n• Status: pending\n• Linked to this SSHER entry via notes\n\nExisting schedule activities will not be modified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Push to Schedule'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final milestoneStart =
        projectData.frontEndPlanning.milestoneStartDate.trim();
    DateTime startDate;
    if (milestoneStart.isNotEmpty) {
      startDate = DateTime.tryParse(milestoneStart) ?? DateTime.now();
    } else {
      startDate = DateTime.now().add(const Duration(days: 30));
    }
    final dueDate = startDate.add(const Duration(days: 5));

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final newActivities = candidates
        .map((e) => ScheduleActivity(
              title: 'SSHER ${e.category}: ${e.concern}',
              durationDays: 5,
              isMilestone: false,
              status: 'pending',
              priority: e.riskLevel.toLowerCase() == 'high'
                  ? 'high'
                  : e.riskLevel.toLowerCase() == 'medium'
                      ? 'medium'
                      : 'low',
              assignee: e.teamMember,
              discipline: e.department,
              progress: 0,
              startDate: fmt(startDate),
              dueDate: fmt(dueDate),
              phase: 'execution',
              estimatingBasis:
                  'Auto-created from SSHER Hub. Mitigation: ${e.mitigation}',
            ))
        .toList();

    final existingActivities =
        List<ScheduleActivity>.from(projectData.scheduleActivities);
    final combined = [...existingActivities, ...newActivities];

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_to_schedule',
      dataUpdater: (d) => d.copyWith(scheduleActivities: combined),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Pushed ${newActivities.length} SSHER activit${newActivities.length == 1 ? 'y' : 'ies'} to the Schedule.'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Requirements Gap Analysis ──
  /// Returns a list of SSHER items whose concern or mitigation text contains
  /// regulatory/compliance language (e.g. "permit", "regulation", "compliance",
  /// "OSHA", "EPA", "ISO", "law", "statute", "mandatory") AND whose concern is
  /// not already captured in the project's requirementItems list.
  List<Map<String, dynamic>> _computeRequirementsGaps() {
    final projectData = ProjectDataHelper.getData(context);
    final existingReqs = projectData.frontEndPlanning.requirementItems;
    final existingReqTexts = existingReqs
        .map((r) => r.description.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    // Keywords that suggest a regulatory/compliance requirement
    const keywords = [
      'permit', 'regulation', 'regulatory', 'compliance', 'compliant',
      'osha', 'epa', 'iso', 'ieee', 'astm', 'asme', 'nfpa', 'nec',
      'law', 'statute', 'mandatory', 'required by', 'must comply',
      'audit', 'certification', 'license', 'registered', 'approved',
      'standard', 'code ', 'inspection', 'reporting requirement',
    ];

    final allEntries = _allEntries();
    final gaps = <Map<String, dynamic>>[];

    for (final e in allEntries) {
      final text = '${e.concern} ${e.mitigation}'.toLowerCase();
      final isRegulatory = keywords.any((k) => text.contains(k));
      if (!isRegulatory) continue;

      final proposedDesc = 'SSHER ${e.category}: ${e.concern}';
      if (existingReqTexts.contains(proposedDesc.trim().toLowerCase())) {
        continue;
      }

      gaps.add({
        'entry': e,
        'proposedDescription': proposedDesc,
        'proposedType': 'Regulatory',
        'proposedDiscipline': e.department,
        'proposedRole': e.teamMember,
        'category': e.category,
      });
    }

    return gaps;
  }

  Future<void> _addRequirementToProject(Map<String, dynamic> gap) async {
    final projectData = ProjectDataHelper.getData(context);
    final reqs = List<RequirementItem>.from(
        projectData.frontEndPlanning.requirementItems);

    // De-dup
    final desc = (gap['proposedDescription'] as String).trim();
    final exists = reqs.any((r) =>
        r.description.trim().toLowerCase() == desc.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$desc" is already in the Requirements list.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    reqs.add(RequirementItem(
      description: desc,
      requirementType: (gap['proposedType'] as String?) ?? 'Regulatory',
      discipline: (gap['proposedDiscipline'] as String?) ?? '',
      role: (gap['proposedRole'] as String?) ?? '',
      requirementSource: 'SSHER Hub gap analysis',
      comments: 'Auto-suggested from SSHER ${gap['category']} item.',
    ));

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_req_gap_add',
      dataUpdater: (d) => d.copyWith(
        frontEndPlanning:
            d.frontEndPlanning.copyWith(requirementItems: reqs),
      ),
    );

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added requirement: "$desc".'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _addAllRequirementsGaps() async {
    final gaps = _computeRequirementsGaps();
    if (gaps.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add All SSHER-Suggested Requirements'),
        content: Text(
            'This will add ${gaps.length} new regulatory/compliance requirement${gaps.length == 1 ? '' : 's'} to the Requirements list:\n\n${gaps.map((g) => '• ${g['proposedDescription']}').take(8).join('\n')}${gaps.length > 8 ? '\n…and ${gaps.length - 8} more.' : ''}\n\nEach will be added with type=Regulatory and source=SSHER Hub gap analysis.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white),
            child: const Text('Add All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final projectData = ProjectDataHelper.getData(context);
    final reqs = List<RequirementItem>.from(
        projectData.frontEndPlanning.requirementItems);
    final existingDescs = reqs
        .map((r) => r.description.trim().toLowerCase())
        .toSet();

    int added = 0;
    for (final gap in gaps) {
      final desc = (gap['proposedDescription'] as String).trim();
      if (existingDescs.contains(desc.toLowerCase())) continue;
      reqs.add(RequirementItem(
        description: desc,
        requirementType: (gap['proposedType'] as String?) ?? 'Regulatory',
        discipline: (gap['proposedDiscipline'] as String?) ?? '',
        role: (gap['proposedRole'] as String?) ?? '',
        requirementSource: 'SSHER Hub gap analysis',
        comments: 'Auto-suggested from SSHER ${gap['category']} item.',
      ));
      existingDescs.add(desc.toLowerCase());
      added++;
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'ssher_req_gap_add_all',
      dataUpdater: (d) => d.copyWith(
        frontEndPlanning:
            d.frontEndPlanning.copyWith(requirementItems: reqs),
      ),
    );

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Added $added requirement${added == 1 ? '' : 's'} to the Requirements list.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'SSHER Hub',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text('Notes', projectData.planningNotes['planning_ssher_stacked_notes'] ?? 'No data recorded.'),
      ],
    );
  }
}

// ── Expandable SSHER Row widget ──
class _ExpandableSsherRow extends StatefulWidget {
  final SsherEntry entry;
  final Color accent;
  final Map<String, bool> syncStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddLog;
  final VoidCallback onAddChecklist;
  final VoidCallback onAddDocument;
  final void Function(String, bool) onToggleChecklist;
  final void Function(SsherLogEntry) onEditLog;
  final void Function(SsherLogEntry) onDeleteLog;
  final void Function(SsherChecklistItem) onEditChecklist;
  final void Function(SsherChecklistItem) onDeleteChecklist;
  final void Function(SsherDocument) onEditDocument;
  final void Function(SsherDocument) onDeleteDocument;

  const _ExpandableSsherRow({
    required this.entry,
    required this.accent,
    required this.syncStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onAddLog,
    required this.onAddChecklist,
    required this.onAddDocument,
    required this.onToggleChecklist,
    required this.onEditLog,
    required this.onDeleteLog,
    required this.onEditChecklist,
    required this.onDeleteChecklist,
    required this.onEditDocument,
    required this.onDeleteDocument,
  });

  @override
  State<_ExpandableSsherRow> createState() => _ExpandableSsherRowState();
}

class _ExpandableSsherRowState extends State<_ExpandableSsherRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accent = widget.accent;
    final riskLevel = entry.riskLevel.trim().toLowerCase();

    Color riskBadgeBg;
    Color riskBadgeText;
    String riskLabel;
    switch (riskLevel) {
      case 'high':
        riskBadgeBg = _Palette.errorContainer;
        riskBadgeText = _Palette.onErrorContainer;
        riskLabel = 'High';
        break;
      case 'medium':
        riskBadgeBg = _Palette.tertiaryFixedDim;
        riskBadgeText = _Palette.tertiaryContainer;
        riskLabel = 'Medium';
        break;
      default:
        riskBadgeBg = _Palette.surfaceContainer;
        riskBadgeText = _Palette.onSurfaceVariant;
        riskLabel = 'Low';
    }

    final cost = double.tryParse(
            entry.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
        0.0;
    final costText = cost > 0
        ? '${entry.costCurrency} ${cost.toStringAsFixed(0)}'
        : '—';
    final integrationCount = entry.linkedRiskIds.length +
        entry.linkedStaffingRoleIds.length +
        entry.linkedRequirementIds.length;

    return Column(
      children: [
        // Main row
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: _Palette.surfaceVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                // Expand icon
                SizedBox(
                  width: 40,
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: _Palette.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                // Concern
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.concern.isNotEmpty
                            ? entry.concern
                            : 'Untitled Concern',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _Palette.onBackground,
                          height: 1.3,
                        ),
                      ),
                      if (entry.mitigation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.mitigation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _Palette.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Department
                SizedBox(
                  width: 110,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _Palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.department.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08,
                        color: _Palette.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Owner
                SizedBox(
                  width: 150,
                  child: Text(
                    entry.teamMember.isNotEmpty
                        ? entry.teamMember
                        : 'Unassigned',
                    style: TextStyle(
                      fontSize: 12,
                      color: entry.teamMember.isNotEmpty
                          ? _Palette.onSurface
                          : _Palette.outline,
                      fontStyle: entry.teamMember.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Risk
                SizedBox(
                  width: 90,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: riskBadgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      riskLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08,
                        color: riskBadgeText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Est. Cost
                SizedBox(
                  width: 110,
                  child: Text(
                    costText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cost > 0
                          ? _Palette.onBackground
                          : _Palette.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sync Status (Cost / Risk / Schedule / Requirements)
                _buildSyncStatusChips(),
                const SizedBox(width: 12),
                // Actions (edit + delete)
                SizedBox(
                  width: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: widget.onEdit,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: _Palette.primary),
                        ),
                      ),
                      InkWell(
                        onTap: widget.onDelete,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.delete_outline,
                              size: 16, color: _Palette.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded section: logs, checklists, documents
        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(60, 8, 16, 16),
            decoration: BoxDecoration(
              color: _Palette.surfaceContainerLow,
              border: Border(
                  top: BorderSide(
                      color: _Palette.surfaceVariant
                          .withValues(alpha: 0.3))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mitigation full text
                if (entry.mitigation.isNotEmpty) ...[
                  const Text(
                    'Mitigation Strategy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _Palette.outline,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _Palette.surfaceBright,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _Palette.surfaceVariant
                              .withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      entry.mitigation,
                      style: const TextStyle(
                          fontSize: 13, height: 1.45, color: _Palette.onSurface),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Notes
                if (entry.notes.isNotEmpty) ...[
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _Palette.outline,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.notes,
                    style: const TextStyle(
                        fontSize: 12, color: _Palette.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                ],
                // Logs section
                _subsection(
                  title: 'Logs',
                  icon: Icons.receipt_long,
                  count: entry.logs.length,
                  onAdd: widget.onAddLog,
                  child: entry.logs.isEmpty
                      ? const Text('No logs recorded.',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: _Palette.outline))
                      : Column(
                          children: entry.logs.map((log) {
                            return _logRow(log);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                // Checklists
                _subsection(
                  title: 'Checklists',
                  icon: Icons.checklist,
                  count: entry.checklists.length,
                  onAdd: widget.onAddChecklist,
                  child: entry.checklists.isEmpty
                      ? const Text('No checklist items.',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: _Palette.outline))
                      : Column(
                          children: entry.checklists.map((item) {
                            return _checklistRow(item);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                // Documents
                _subsection(
                  title: 'Documents',
                  icon: Icons.description,
                  count: entry.documents.length,
                  onAdd: widget.onAddDocument,
                  child: entry.documents.isEmpty
                      ? const Text('No documents tracked.',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: _Palette.outline))
                      : Column(
                          children: entry.documents.map((doc) {
                            return _documentRow(doc);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                // Integrations
                if (entry.linkedRiskIds.isNotEmpty ||
                    entry.linkedStaffingRoleIds.isNotEmpty ||
                    entry.linkedRequirementIds.isNotEmpty) ...[
                  const Text(
                    'Cross-Discipline Integrations',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _Palette.outline,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...entry.linkedRiskIds.map((id) => _integrationBadge(
                          'Risk: ${id.length > 24 ? '${id.substring(0, 24)}...' : id}',
                          Icons.warning_amber,
                          _Palette.error)),
                      ...entry.linkedStaffingRoleIds.map((id) =>
                          _integrationBadge(
                              'Staffing: ${id.length > 24 ? '${id.substring(0, 24)}...' : id}',
                              Icons.person_outline,
                              _Palette.primary)),
                      ...entry.linkedRequirementIds.map((id) =>
                          _integrationBadge(
                              'Requirement: ${id.length > 24 ? '${id.substring(0, 24)}...' : id}',
                              Icons.assignment_outlined,
                              _Palette.tertiaryContainer)),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _subsection({
    required String title,
    required IconData icon,
    required int count,
    required VoidCallback onAdd,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: widget.accent),
            const SizedBox(width: 6),
            Text(
              '$title ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accent,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onAdd,
              child: Row(
                children: [
                  Icon(Icons.add, size: 14, color: widget.accent),
                  const SizedBox(width: 2),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _logRow(SsherLogEntry log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.type,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      log.date,
                      style: const TextStyle(
                          fontSize: 11, color: _Palette.outline),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _Palette.onBackground,
                        ),
                      ),
                    ),
                  ],
                ),
                if (log.details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.details,
                    style: const TextStyle(
                        fontSize: 11, color: _Palette.onSurfaceVariant),
                  ),
                ],
                if (log.loggedBy.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'By: ${log.loggedBy}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: _Palette.outline),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: () => widget.onEditLog(log),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.edit_outlined,
                  size: 14, color: _Palette.primary),
            ),
          ),
          InkWell(
            onTap: () => widget.onDeleteLog(log),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.delete_outline,
                  size: 14, color: _Palette.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(SsherChecklistItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.checked,
            onChanged: (v) => widget.onToggleChecklist(item.id, v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.checked
                        ? _Palette.outline
                        : _Palette.onBackground,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (item.notes.isNotEmpty || item.dueDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.dueDate.isNotEmpty) 'Due: ${item.dueDate}',
                      if (item.notes.isNotEmpty) item.notes,
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10, color: _Palette.outline),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: () => widget.onEditChecklist(item),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.edit_outlined,
                  size: 14, color: _Palette.primary),
            ),
          ),
          InkWell(
            onTap: () => widget.onDeleteChecklist(item),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.delete_outline,
                  size: 14, color: _Palette.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentRow(SsherDocument doc) {
    Color statusColor;
    switch (doc.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF047857);
        break;
      case 'expired':
        statusColor = _Palette.error;
        break;
      case 'submitted':
        statusColor = _Palette.primary;
        break;
      case 'in progress':
        statusColor = _Palette.tertiaryContainer;
        break;
      default:
        statusColor = _Palette.outline;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.type,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        doc.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _Palette.onBackground,
                        ),
                      ),
                    ),
                  ],
                ),
                if (doc.owner.isNotEmpty || doc.dueDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (doc.owner.isNotEmpty) 'Owner: ${doc.owner}',
                      if (doc.dueDate.isNotEmpty) 'Due: ${doc.dueDate}',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10, color: _Palette.outline),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: () => widget.onEditDocument(doc),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.edit_outlined,
                  size: 14, color: _Palette.primary),
            ),
          ),
          InkWell(
            onTap: () => widget.onDeleteDocument(doc),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.delete_outline,
                  size: 14, color: _Palette.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _integrationBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  /// Builds the sync-status chip cluster for the row. Shows 4 mini icons
  /// (Cost / Risk / Schedule / Requirements), each filled in green when the
  /// entry has been pushed to that target, outline gray when not.
  Widget _buildSyncStatusChips() {
    final status = widget.syncStatus;
    final chips = <Widget>[];
    final entries = [
      ('costEstimate', Icons.attach_money, 'CE'),
      ('riskRegister', Icons.warning_amber, 'RR'),
      ('schedule', Icons.event, 'SC'),
      ('requirements', Icons.fact_check_outlined, 'RQ'),
    ];
    for (final entry in entries) {
      final key = entry.$1;
      final icon = entry.$2;
      final label = entry.$3;
      final pushed = status[key] == true;
      chips.add(_syncChip(icon, label, pushed));
      chips.add(const SizedBox(width: 4));
    }
    if (chips.isNotEmpty) chips.removeLast();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }

  Widget _syncChip(IconData icon, String label, bool pushed) {
    final color = pushed ? const Color(0xFF047857) : _Palette.outline;
    final bg = pushed
        ? const Color(0xFFECFDF5)
        : _Palette.surfaceContainerLow;
    final border = pushed
        ? const Color(0xFFA7F3D0)
        : _Palette.surfaceVariant;
    return Tooltip(
      message: pushed
          ? 'Pushed to $label'
          : 'Not yet pushed to $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 12, color: color),
      ),
    );
  }
}

// ── Scale-on-tap widget for press effect ──
class _ScaleOnTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _ScaleOnTap({required this.onTap, required this.child});
  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Lightweight placeholder route that opens the Cost Estimate module screen
/// when the user taps "View Cost Estimate" in the SSHER push snackbar.
class _CostEstimateRoutePlaceholder extends StatelessWidget {
  const _CostEstimateRoutePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const CostEstimateModuleScreen();
  }
}

/// Progress update emitted by `_pushAllIntegrations` while running.
class _PushAllProgress {
  final int step;
  final int totalSteps;
  final String label;
  final bool inProgress;
  final bool done;

  const _PushAllProgress({
    required this.step,
    required this.totalSteps,
    required this.label,
    required this.inProgress,
    this.done = false,
  });
}

/// Final result of `_pushAllIntegrations`.
class _PushAllResult {
  final int costEstimatePushed;
  final int riskRegisterPushed;
  final int schedulePushed;
  final int requirementsPushed;

  const _PushAllResult({
    required this.costEstimatePushed,
    required this.riskRegisterPushed,
    required this.schedulePushed,
    required this.requirementsPushed,
  });
}

/// Modal dialog that streams `_PushAllProgress` updates and dismisses itself
/// when the `done` flag is set on a progress event.
class _PushAllProgressDialog extends StatefulWidget {
  final Stream<_PushAllProgress> progressStream;

  const _PushAllProgressDialog({required this.progressStream});

  @override
  State<_PushAllProgressDialog> createState() => _PushAllProgressDialogState();
}

class _PushAllProgressDialogState extends State<_PushAllProgressDialog> {
  final List<_PushAllProgress> _steps = [];
  final Set<int> _completedSteps = {};

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((p) {
      if (!mounted) return;
      setState(() {
        // Replace any existing entry for this step, else append
        final idx = _steps.indexWhere((s) => s.step == p.step);
        if (idx >= 0) {
          _steps[idx] = p;
        } else {
          _steps.add(p);
        }
        if (!p.inProgress) _completedSteps.add(p.step);
      });
      if (p.done) {
        // Give the user a brief moment to see "Done" state, then close
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.bolt, color: _Palette.primary, size: 22),
          const SizedBox(width: 10),
          const Text('Push All Integrations'),
          const Spacer(),
          if (_completedSteps.length == 4)
            const Icon(Icons.check_circle,
                color: Color(0xFF047857), size: 22),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 1; i <= 4; i++) _stepRow(i),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _completedSteps.length / 4,
              backgroundColor: _Palette.surfaceContainerLow,
              valueColor: const AlwaysStoppedAnimation<Color>(_Palette.primary),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              _completedSteps.length == 4
                  ? 'All integrations complete.'
                  : 'Running step ${_completedSteps.length + 1} of 4…',
              style: const TextStyle(
                  fontSize: 12, color: _Palette.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _completedSteps.length == 4
              ? () => Navigator.of(context).pop()
              : null,
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _stepRow(int stepNumber) {
    final labels = {
      1: 'Push to Cost Estimate',
      2: 'Push to Risk Register',
      3: 'Push to Schedule',
      4: 'Add All Requirements',
    };
    final progress = _steps.where((s) => s.step == stepNumber).toList();
    final hasProgress = progress.isNotEmpty;
    final latest = hasProgress ? progress.last : null;
    final isCompleted = _completedSteps.contains(stepNumber);
    final isInProgress = latest?.inProgress == true;

    Widget icon;
    Color iconColor;
    if (isCompleted) {
      icon = const Icon(Icons.check_circle, size: 18);
      iconColor = const Color(0xFF047857);
    } else if (isInProgress) {
      icon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      iconColor = _Palette.primary;
    } else {
      icon = const Icon(Icons.radio_button_unchecked, size: 18);
      iconColor = _Palette.outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels[stepNumber] ?? 'Step $stepNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCompleted || isInProgress
                        ? _Palette.onBackground
                        : _Palette.outline,
                  ),
                ),
                if (hasProgress && latest!.label.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    latest.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCompleted
                          ? const Color(0xFF047857)
                          : _Palette.onSurfaceVariant,
                      fontStyle: isCompleted
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check, size: 14, color: Color(0xFF047857)),
        ],
      ),
    );
  }
}
