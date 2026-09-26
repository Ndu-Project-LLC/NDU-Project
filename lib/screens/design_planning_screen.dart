import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/ai_error_message.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/architecture_module_labels.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
// import 'package:ndu_project/widgets/launch_phase_navigation.dart'; // removed: UI redesign
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';

import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/utils/section_flow_gate.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const Color _kSurface = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kText = Color(0xFF111827);
const Color _kMuted = Color(0xFF6B7280);
const Color _kPrimary = Color(0xFFFFC812);
const Color _kSuccess = Color(0xFF0F9D58);
const Color _kWarning = Color(0xFFF59E0B);
// Brand colors from HTML design
const Color _kBrandYellow = Color(0xFFFFC107);
const Color _kBrandDark = Color(0xFF1A1A1A);
const Color _kGray400 = Color(0xFF9CA3AF);
const Color _kGray500 = Color(0xFF6B7280);
const Color _kGray700 = Color(0xFF374151);
const Color _kGray900 = Color(0xFF111827);
const Color _kBlue600 = Color(0xFFFFC812);
const String _kSectionProgressNotesKey = 'planning_design_section_progress';

enum _SectionProgressState { pending, complete, notApplicable }

/// Presentation mode for the Design Specifications rows.
enum _SpecViewMode {
  /// Table first: every row visible together, which is what was asked for.
  table,

  /// The per-row cards, where a specification is written and edited.
  cards,
}

class DesignPlanningScreen extends StatefulWidget {
  const DesignPlanningScreen({
    super.key,
    this.initialSectionId,
    this.activeItemLabel,
  });

  /// Optional section id to land on when the screen opens (e.g.
  /// 'architecture', 'work_packages'). When null the screen picks the first
  /// unresolved section (existing guided-flow behaviour). When provided the
  /// matching section is expanded and treated as active on first build,
  /// enabling deep links from the sidebar sub-pages.
  final String? initialSectionId;

  /// Optional sidebar active item label. When null the screen reports
  /// 'Design Planning' to the sidebar so the parent header stays highlighted.
  /// When provided (e.g. 'Design Planning - Architecture Basis') the matching
  /// sidebar sub-page is highlighted instead.
  final String? activeItemLabel;

  static void open(BuildContext context) {
    context.push('/design-planning');
  }

  @override
  State<DesignPlanningScreen> createState() => _DesignPlanningScreenState();
}

class _DesignPlanningScreenState extends State<DesignPlanningScreen> {
  static const _mappingStatusOptions = [
    'Draft',
    'Planned',
    'Active',
    'Blocked'
  ];
  static const _workStatusOptions = ['Draft', 'Planned', 'In Review', 'Ready'];
  static const _riskStatusOptions = ['Open', 'Monitoring', 'Closed'];
  static const _approvalStatusOptions = ['Pending', 'In Review', 'Approved'];
  static const _specRuleTypeOptions = ['Internal', 'External'];
  static const _specSourceTypeOptions = [
    'Contracts',
    'Vendors',
    'Regulatory',
    'Standards',
  ];
  static const _specificationTypeOptions = [
    'Code',
    'Law',
    'Standard',
    'Criteria',
    'Guideline',
    'Contract',
    'Other',
  ];
  static const _specDisciplineOptions = [
    'Architecture',
    'Civil',
    'Structural',
    'Geotechnical',
    'Mechanical (HVAC)',
    'Electrical',
    'Plumbing',
    'Fire Protection',
    'Survey / Geomatics',
    'Landscape',
    'Environmental',
    'Telecommunications / ICT',
    'Frontend',
    'Backend',
    'Full-Stack',
    'Data / Analytics',
    'Integration / APIs',
    'DevOps / Platform / SRE',
    'QA / Testing',
    'Cybersecurity',
    'IT / Infrastructure',
    'Operations',
    'Procurement',
    'Commercial / Contracts',
    'Quality / QA-QC',
    'Regulatory / Compliance',
    'Program / Project Management',
    'Safety / HSE',
  ];
  static const _specAreaOptions = [
    'General',
    'Design',
    'Construction',
    'Operations',
    'Security',
    'Compliance',
    'Testing',
    'Data',
    'Integration',
    'Quality',
    'Safety',
    'Environmental',
    'UI/UX',
    'Frontend',
    'Backend',
    'Infrastructure',
    'Procurement',
    'Commercial',
  ];
  static const _specRowStatusOptions = ['Draft', 'Planned', 'In Review'];
  static const _designAreaOptions = [
    'Architecture',
    'UI/UX',
    'Technical',
    'Data',
    'Security',
    'Validation',
  ];
  static const _dependencyTypeOptions = [
    'System',
    'Team',
    'Vendor',
    'Approval',
    'Tooling',
    'Data',
    'Interface',
  ];

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    for (final section in _sectionOrder) section.id: GlobalKey(),
  };
  final Map<String, GlobalKey> _specificationRowKeys = {};
  Timer? _saveDebounce;
  bool _didInit = false;
  bool _saving = false;
  bool _pendingSave = false;
  bool _generatingPackages = false;
  final Set<String> _selectedWbsNodeIds = {};
  DateTime? _lastSavedAt;
  // ValueNotifier for lightweight save-indicator rebuilds without full setState
  final ValueNotifier<_SaveIndicatorState> _saveIndicatorNotifier =
      ValueNotifier<_SaveIndicatorState>(const _SaveIndicatorState(
          saving: false, pending: false, lastSavedAt: null));
  final Map<String, bool> _aiGenerating = {};
  late Map<String, _SectionProgressState> _sectionProgress;

  /// How the Design Specifications rows are presented. The table is the
  /// default — the owner asked for the rows to be readable as a set, with the
  /// cards still one tap away for editing (Lusaka 25 (copy), 2026-09-17).
  _SpecViewMode _specViewMode = _SpecViewMode.table;
  late Map<String, bool> _sectionExpanded;
  late Map<String, int> _sectionTileVersion;
  String _activeSectionId = _sectionOrder.first.id;

  late DesignPlanningDocument _document;
  late TextEditingController _overviewController;
  late TextEditingController _designWhoController;
  late TextEditingController _designHowController;
  late TextEditingController _designVendorsController;
  late TextEditingController _designInterfacesController;
  late TextEditingController _objectivesController;
  late TextEditingController _successCriteriaController;
  late TextEditingController _scopeController;
  late TextEditingController _outOfScopeController;
  late TextEditingController _architectureController;
  late TextEditingController _diagramReferenceController;
  late TextEditingController _dataFlowController;
  late TextEditingController _uiUxController;
  late TextEditingController _designSystemController;
  late TextEditingController _technicalFrontendController;
  late TextEditingController _technicalBackendController;
  late TextEditingController _technicalDataController;
  late TextEditingController _constraintsController;
  late TextEditingController _assumptionsController;
  late TextEditingController _validationController;
  late TextEditingController _governanceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    ApiKeyManager.initializeApiKey();
    final data = ProjectDataHelper.getData(context);
    _document = DesignPlanningDocument.fromProjectData(data);
    _overviewController =
        SpellCheckTextEditingController(text: _document.overviewSummary);
    _designWhoController =
        SpellCheckTextEditingController(text: _document.designWhoAndOwnership);
    _designHowController = SpellCheckTextEditingController(
        text: _document.designExecutionApproach);
    _designVendorsController = SpellCheckTextEditingController(
        text: _document.designVendorContractInputs);
    _designInterfacesController = SpellCheckTextEditingController(
        text: _document.designInterfacesAndConstraints);
    _objectivesController =
        SpellCheckTextEditingController(text: _document.objectives);
    _successCriteriaController =
        SpellCheckTextEditingController(text: _document.successCriteria);
    _scopeController = SpellCheckTextEditingController(text: _document.scope);
    _outOfScopeController =
        SpellCheckTextEditingController(text: _document.outOfScope);
    _architectureController =
        SpellCheckTextEditingController(text: _document.architectureSummary);
    _diagramReferenceController =
        SpellCheckTextEditingController(text: _document.diagramReference);
    _dataFlowController =
        SpellCheckTextEditingController(text: _document.dataFlowSummary);
    _uiUxController =
        SpellCheckTextEditingController(text: _document.uiUxSummary);
    _designSystemController =
        SpellCheckTextEditingController(text: _document.designSystemNotes);
    _technicalFrontendController =
        SpellCheckTextEditingController(text: _document.technicalFrontend);
    _technicalBackendController =
        SpellCheckTextEditingController(text: _document.technicalBackend);
    _technicalDataController =
        SpellCheckTextEditingController(text: _document.technicalData);
    _constraintsController =
        SpellCheckTextEditingController(text: _document.constraints.join('\n'));
    _assumptionsController =
        SpellCheckTextEditingController(text: _document.assumptions.join('\n'));
    _validationController =
        SpellCheckTextEditingController(text: _document.validationSummary);
    _governanceController =
        SpellCheckTextEditingController(text: _document.governanceNotes);
    _ensureSpecificationRowKeys();
    _hydrateGuidedSectionState(data);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveIndicatorNotifier.dispose();
    _scrollController.dispose();
    _overviewController.dispose();
    _designWhoController.dispose();
    _designHowController.dispose();
    _designVendorsController.dispose();
    _designInterfacesController.dispose();
    _objectivesController.dispose();
    _successCriteriaController.dispose();
    _scopeController.dispose();
    _outOfScopeController.dispose();
    _architectureController.dispose();
    _diagramReferenceController.dispose();
    _dataFlowController.dispose();
    _uiUxController.dispose();
    _designSystemController.dispose();
    _technicalFrontendController.dispose();
    _technicalBackendController.dispose();
    _technicalDataController.dispose();
    _constraintsController.dispose();
    _assumptionsController.dispose();
    _validationController.dispose();
    _governanceController.dispose();
    super.dispose();
  }

  Future<void> _scrollToSectionStart(String id) async {
    final firstContext = _sectionKeys[id]?.currentContext;
    if (firstContext == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final targetContext = _sectionKeys[id]?.currentContext;
    if (targetContext == null || !mounted || !targetContext.mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.0,
    );
    // Re-run once after tile animation to keep the section header at the top.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final settleContext = _sectionKeys[id]?.currentContext;
    if (settleContext == null || !settleContext.mounted) return;
    await Scrollable.ensureVisible(
      settleContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      alignment: 0.0,
    );
  }

  void _hydrateGuidedSectionState(ProjectDataModel data) {
    final progress = <String, _SectionProgressState>{
      for (final section in _sectionOrder)
        section.id: _SectionProgressState.pending,
    };
    final raw = data.planningNotes[_kSectionProgressNotesKey];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (!progress.containsKey(key)) return;
            progress[key] = _parseProgressState(value?.toString());
          });
        }
      } catch (e) {
        // Keep defaults if progress payload is malformed.
      }
    } // Agile delivery has no design work package: the design lives inside the
    // iteration (epics → features → stories) instead of being handed to a
    // separate work package — "for agile projects there wouldn't necessarily be
    // a design work package … design is part of the iteration anyways"
    // (Lusaka 25 (copy)).
    //
    // Only a *pending* section is defaulted, so an explicit Complete / Not
    // applicable the user already saved is never overwritten.
    final methodology = ProjectDataHelper.resolvedProjectMethodology(data).name;
    if (progress['work_packages'] == _SectionProgressState.pending &&
        workPackagesSectionStartsNotApplicable(
          methodology: methodology,
          hasWorkPackageContent: data.wbsTree.isNotEmpty ||
              data.workPackages.isNotEmpty,
        )) {
      progress['work_packages'] = _SectionProgressState.notApplicable;
    }

    _sectionProgress = progress;
    // Resolve the initial active section.
    //
    // 1. If the caller passed an `initialSectionId` that maps to a known
    //    section, land on it directly (sidebar deep-link).
    // 2. Otherwise keep the existing guided-flow behaviour: jump to the first
    //    unresolved section, or fall back to the very first section.
    final requestedSectionId = widget.initialSectionId?.trim();
    final hasValidInitialSection = requestedSectionId != null &&
        requestedSectionId.isNotEmpty &&
        _sectionOrder.any((section) => section.id == requestedSectionId);
    _activeSectionId = hasValidInitialSection
        ? requestedSectionId
        : _sectionOrder
            .firstWhere(
              (section) => !_isSectionResolved(section.id),
              orElse: () => _sectionOrder.first,
            )
            .id;
    _sectionExpanded = {
      for (final section in _sectionOrder)
        section.id: section.id == _activeSectionId,
    };
    _sectionTileVersion = {
      for (final section in _sectionOrder) section.id: 0,
    };
  }

  _SectionProgressState _parseProgressState(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'complete':
        return _SectionProgressState.complete;
      case 'notapplicable':
      case 'not_applicable':
        return _SectionProgressState.notApplicable;
      default:
        return _SectionProgressState.pending;
    }
  }

  String _encodeSectionProgress() {
    final payload = <String, String>{
      for (final section in _sectionOrder)
        section.id: _sectionProgress[section.id]!.name,
    };
    return jsonEncode(payload);
  }

  bool _isSectionResolved(String sectionId) =>
      _sectionProgress[sectionId] != _SectionProgressState.pending;

  bool _canOpenSection(String sectionId) {
    final targetIndex =
        _sectionOrder.indexWhere((section) => section.id == sectionId);
    if (targetIndex <= 0) return true;
    for (var i = 0; i < targetIndex; i++) {
      if (!_isSectionResolved(_sectionOrder[i].id)) return false;
    }
    return true;
  }

  String? _firstBlockingSectionLabel(String sectionId) {
    final targetIndex =
        _sectionOrder.indexWhere((section) => section.id == sectionId);
    if (targetIndex <= 0) return null;
    for (var i = 0; i < targetIndex; i++) {
      final id = _sectionOrder[i].id;
      if (!_isSectionResolved(id)) {
        return _sectionOrder[i].label;
      }
    }
    return null;
  }

  void _showLockedSectionFeedback(String sectionId) {
    final blocking = _firstBlockingSectionLabel(sectionId);
    final blockingId = _sectionOrder
        .firstWhere(
          (s) => s.label == blocking,
          orElse: () => _sectionOrder.first,
        )
        .id;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text(blocking == null
              ? 'Complete prior sections first.'
              : 'Finish "$blocking" first — it feeds this section.'),
          action: SnackBarAction(
            label: 'Go to ${blocking == null ? 'start' : blocking}',
            onPressed: () => _activateSection(blockingId),
          ),
        ),
      );
  }

  Future<void> _activateSection(String sectionId) async {
    if (!_canOpenSection(sectionId)) {
      _showLockedSectionFeedback(sectionId);
      setState(() {
        // Collapse the section the user tried to open (it was auto-expanded
        // by the ExpansionTile tap before this callback fired).
        _sectionExpanded[sectionId] = false;
      });
      return;
    }
    setState(() {
      // Collapse the previously active section, expand the new one.
      // Modifying the existing map in-place avoids changing the ValueKey
      // for sections whose expanded state didn't change, preventing
      // unnecessary subtree recreation.
      for (final section in _sectionOrder) {
        final shouldExpand = section.id == sectionId;
        if (_sectionExpanded[section.id] != shouldExpand) {
          _sectionExpanded[section.id] = shouldExpand;
          // Bump tile version so the ExpansionTile animates correctly.
          _sectionTileVersion[section.id] =
              (_sectionTileVersion[section.id] ?? 0) + 1;
        }
      }
      _activeSectionId = sectionId;
    });
    await _scrollToSectionStart(sectionId);
  }

  Future<void> _onSectionExpansionChanged(
      String sectionId, bool expanded) async {
    if (!expanded) {
      setState(() => _sectionExpanded[sectionId] = false);
      return;
    }
    if (!_canOpenSection(sectionId)) {
      _showLockedSectionFeedback(sectionId);
      setState(() {
        _sectionExpanded[sectionId] = false;
        _sectionTileVersion[sectionId] =
            (_sectionTileVersion[sectionId] ?? 0) + 1;
      });
      return;
    }
    await _activateSection(sectionId);
  }

  Future<void> _setSectionProgress({
    required String sectionId,
    required _SectionProgressState state,
  }) async {
    final current =
        _sectionProgress[sectionId] ?? _SectionProgressState.pending;
    if (current == state) return;
    if (state == _SectionProgressState.complete &&
        (sectionId == 'requirements' ||
            sectionId == 'design_specifications_workspace')) {
      final requirementOptions =
          _requirementAttachmentOptions(ProjectDataHelper.getData(context));
      final missing = _unlinkedRequirements(requirementOptions);
      if (missing.isNotEmpty) {
        final preview = missing.take(3).map((item) => item.label).join(', ');
        _showToast(
          'Link specifications to all requirements first. '
          '${missing.length} requirement(s) still unlinked'
          '${preview.isEmpty ? '' : ': $preview'}',
        );
        return;
      }
    }
    if (state != _SectionProgressState.pending) {
      final confirmed = await _confirmStatusChange(state);
      if (!confirmed) return;
    }
    setState(() {
      _sectionProgress[sectionId] = state;
    });
    _queueSave();
  }

  Future<bool> _confirmStatusChange(_SectionProgressState state) async {
    final label = state == _SectionProgressState.complete
        ? 'mark this section as complete'
        : 'mark this section as not applicable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Section Status'),
          content: Text('Are you sure you want to $label?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Widget _buildSectionProgressControls(String sectionId) {
    final state = _sectionProgress[sectionId] ?? _SectionProgressState.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip(
                sectionId: sectionId,
                state: state,
                target: _SectionProgressState.complete,
                label: 'Mark complete',
                doneLabel: 'Complete',
                icon: Icons.check_circle_outline,
                activeColor: _kSuccess,
              ),
              const SizedBox(width: 8),
              _statusChip(
                sectionId: sectionId,
                state: state,
                target: _SectionProgressState.notApplicable,
                label: 'Not applicable',
                doneLabel: 'Not applicable',
                icon: Icons.do_disturb_on_outlined,
                activeColor: _kWarning,
              ),
              const Spacer(),
              if (state != _SectionProgressState.pending)
                TextButton.icon(
                  onPressed: () => _setSectionProgress(
                    sectionId: sectionId,
                    state: _SectionProgressState.pending,
                  ),
                  icon: const Icon(Icons.undo, size: 14),
                  label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: _kGray700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (state == _SectionProgressState.pending) ...[
            const SizedBox(height: 6),
            const Text(
              'Working through it? Leave it open — reopen sections anytime.',
              style: TextStyle(fontSize: 11.5, color: _kGray500),
            ),
          ],
        ],
      ),
    );
  }

  /// One of the two section-status chips: a single tap does the thing its
  /// label says ("Mark complete"), with no hidden checkbox semantics to
  /// decode. An active chip renders filled, and tapping the active chip is
  /// what reopens the section — the undo affordance sits beside it, too.
  Widget _statusChip({
    required String sectionId,
    required _SectionProgressState state,
    required _SectionProgressState target,
    required String label,
    required String doneLabel,
    required IconData icon,
    required Color activeColor,
  }) {
    final active = state == target;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _setSectionProgress(
        sectionId: sectionId,
        state: active ? _SectionProgressState.pending : target,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.fromBorderSide(
            BorderSide(
              color: active ? activeColor : _kBorder,
              width: active ? 1.4 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle : icon,
              size: 15,
              color: active ? activeColor : _kGray700,
            ),
            const SizedBox(width: 6),
            Text(
              active ? doneLabel : label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : _kGray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCoreFields() {
    _document.overviewSummary = _overviewController.text.trim();
    _document.designWhoAndOwnership = _designWhoController.text.trim();
    _document.designExecutionApproach = _designHowController.text.trim();
    _document.designVendorContractInputs = _designVendorsController.text.trim();
    _document.designInterfacesAndConstraints =
        _designInterfacesController.text.trim();
    _document.objectives = _objectivesController.text.trim();
    _document.successCriteria = _successCriteriaController.text.trim();
    _document.scope = _scopeController.text.trim();
    _document.outOfScope = _outOfScopeController.text.trim();
    _document.architectureSummary = _architectureController.text.trim();
    _document.diagramReference = _diagramReferenceController.text.trim();
    _document.dataFlowSummary = _dataFlowController.text.trim();
    _document.uiUxSummary = _uiUxController.text.trim();
    _document.designSystemNotes = _designSystemController.text.trim();
    _document.technicalFrontend = _technicalFrontendController.text.trim();
    _document.technicalBackend = _technicalBackendController.text.trim();
    _document.technicalData = _technicalDataController.text.trim();
    _document.constraints = _splitLines(_constraintsController.text);
    _document.assumptions = _splitLines(_assumptionsController.text);
    _document.validationSummary = _validationController.text.trim();
    _document.governanceNotes = _governanceController.text.trim();
  }

  void _queueSave() {
    _updateCoreFields();
    _document.touch();
    _saveDebounce?.cancel();
    _pendingSave = true;
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveDocument);
    // Update save indicator via lightweight ValueNotifier — avoids full rebuild
    _saveIndicatorNotifier.value = _SaveIndicatorState(
      saving: _saving,
      pending: _pendingSave,
      lastSavedAt: _lastSavedAt,
    );
  }

  Future<void> _saveDocument() async {
    if (!mounted || _saving) return;
    _updateCoreFields();
    _document.touch();
    _saving = true;
    _saveIndicatorNotifier.value = _SaveIndicatorState(
      saving: _saving,
      pending: _pendingSave,
      lastSavedAt: _lastSavedAt,
    );
    final data = ProjectDataHelper.getData(context);
    final notesPatch = {
      ...data.planningNotes,
      ..._document.toPlanningNotesPatch(),
      _kSectionProgressNotesKey: _encodeSectionProgress(),
    };
    final riskPlans = {
      ...data.riskMitigationPlans,
      ..._document.toRiskMitigationPlans(),
    };
    final success = await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'design',
      showSnackbar: false,
      dataUpdater: (current) {
        final mappedMethodology =
            ProjectDataHelper.projectMethodologyFromOverallFramework(
          current.overallFramework,
        );
        final designManagementData = mappedMethodology == null
            ? current.designManagementData
            : (current.designManagementData ?? DesignManagementData()).copyWith(
                methodology: mappedMethodology ??
                    current.designManagementData?.methodology,
              );

        return current.copyWith(
          planningNotes: notesPatch,
          planningRequirementItems: _document.toPlanningRequirementItems(),
          designDeliverablesData: _document
              .toDesignDeliverablesData(current.designDeliverablesData),
          withinScopeItems: _document.toScopeItems(),
          outOfScopeItems: _document.toOutOfScopeItems(),
          constraintItems: _document.toConstraintItems(),
          assumptionItems: _document.toAssumptionItems(),
          riskMitigationPlans: riskPlans,
          designManagementData: designManagementData,
        );
      },
    );
    if (!mounted) return;
    _saving = false;
    if (success) {
      _pendingSave = false;
      _lastSavedAt = DateTime.now();
    }
    _saveIndicatorNotifier.value = _SaveIndicatorState(
      saving: _saving,
      pending: _pendingSave,
      lastSavedAt: _lastSavedAt,
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Pre-populate [_specificationRowKeys] for every row in
  /// [_document.specifications] so that the build method never mutates state
  /// via `putIfAbsent` / `??=`.
  void _ensureSpecificationRowKeys() {
    for (final row in _document.specifications) {
      _specificationRowKeys.putIfAbsent(
        row.id,
        () => GlobalKey(debugLabel: 'spec_row_${row.id}'),
      );
    }
  }

  void _addSpecificationRow() {
    setState(() {
      final newRow = DesignSpecificationPlanRow(
        specificationType: _specificationTypeOptions[2],
        sourceType: _specSourceTypeOptions.first,
        ruleType: _specRuleTypeOptions.first,
      );
      _document.specifications.add(newRow);
      _specificationRowKeys[newRow.id] = GlobalKey(
        debugLabel: 'spec_row_${newRow.id}',
      );
    });
    _queueSave();
  }

  void _addDeviation() {
    setState(() {
      _document.deviations.add(DesignSpecificationDeviation());
    });
    _queueSave();
  }

  Future<void> _showSpecificationsTableDialog() async {
    final rows = _specificationOptions();
    final searchController = SpellCheckTextEditingController();
    var query = '';
    var disciplineFilter = 'All';
    var areaFilter = 'All';
    var typeFilter = 'All';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final disciplineOptions = _dedupeOptions([
              'All',
              ...rows.map((row) => row.discipline).where((e) => e.isNotEmpty),
            ]);
            final areaOptions = _dedupeOptions([
              'All',
              ...rows.map((row) => row.area).where((e) => e.isNotEmpty),
            ]);
            final typeOptions = _dedupeOptions([
              'All',
              ...rows
                  .map((row) => row.specificationType)
                  .where((e) => e.isNotEmpty),
            ]);

            final filteredRows = rows.where((row) {
              final haystack = [
                row.title,
                row.details,
                row.discipline,
                row.area,
                row.specificationType,
                row.sourceType,
                row.owner,
                row.status,
                row.wbsWorkPackageTitle,
              ].join(' ').toLowerCase();
              final matchesQuery = query.isEmpty ||
                  haystack.contains(query.toLowerCase().trim());
              final matchesDiscipline = disciplineFilter == 'All' ||
                  row.discipline == disciplineFilter;
              final matchesArea = areaFilter == 'All' || row.area == areaFilter;
              final matchesType =
                  typeFilter == 'All' || row.specificationType == typeFilter;
              return matchesQuery &&
                  matchesDiscipline &&
                  matchesArea &&
                  matchesType;
            }).toList(growable: false);

            return AlertDialog(
              title: const Text('Specifications Table'),
              content: SizedBox(
                width: 1320,
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No specification rows available.',
                          style: TextStyle(color: _kMuted),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FourColumnGrid(
                            children: [
                              VoiceTextField(
                                controller: searchController,
                                decoration:
                                    _inputDecoration('Search specifications'),
                                onChanged: (value) {
                                  setDialogState(() => query = value);
                                },
                              ),
                              _DropdownField(
                                value: disciplineFilter,
                                label: 'Discipline',
                                options: disciplineOptions,
                                onChanged: (value) => setDialogState(
                                    () => disciplineFilter = value),
                              ),
                              _DropdownField(
                                value: areaFilter,
                                label: 'Area',
                                options: areaOptions,
                                onChanged: (value) =>
                                    setDialogState(() => areaFilter = value),
                              ),
                              _DropdownField(
                                value: typeFilter,
                                label: 'Document type',
                                options: typeOptions,
                                onChanged: (value) =>
                                    setDialogState(() => typeFilter = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${filteredRows.length} row(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FullScreenTableWrapper(
                            title: 'Design Specifications',
                            child: SizedBox(
                              height: 420,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minWidth: 1240),
                                      child: buildNduDataTable(
                                        context: context,
                                        columnSpacing: 30,
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 76,
                                        columns: const [
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 220,
                                                  child: Text('Title'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Spec type'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 140,
                                                  child: Text('Discipline'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 140,
                                                  child: Text('Area'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 170,
                                                  child: Text(
                                                      'WBS Work Package'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Source type'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Owner'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 90,
                                                  child: Text('Status'))),
                                        ],
                                        rows: filteredRows
                                            .map(
                                              (item) => DataRow(
                                                cells: [
                                                  DataCell(SizedBox(
                                                    width: 220,
                                                    child: Text(
                                                      item.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.specificationType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 140,
                                                    child: Text(
                                                      item.discipline.isEmpty
                                                          ? '-'
                                                          : item.discipline,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 140,
                                                    child: Text(
                                                      item.area.isEmpty
                                                          ? '-'
                                                          : item.area,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 170,
                                                    child: Text(
                                                      item.wbsWorkPackageTitle
                                                              .isEmpty
                                                          ? '-'
                                                          : item
                                                              .wbsWorkPackageTitle,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.sourceType.isEmpty
                                                          ? '-'
                                                          : item.sourceType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.owner.isEmpty
                                                          ? '-'
                                                          : item.owner,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.status.isEmpty
                                                          ? '-'
                                                          : item.status,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                ],
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            tableBuilder: (fsContext) => SizedBox(
                              height: 420,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minWidth: 1240),
                                      child: buildNduDataTable(
                                        context: context,
                                        columnSpacing: 30,
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 76,
                                        columns: const [
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 220,
                                                  child: Text('Title'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Spec type'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 140,
                                                  child: Text('Discipline'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 140,
                                                  child: Text('Area'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 170,
                                                  child: Text(
                                                      'WBS Work Package'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Source type'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 120,
                                                  child: Text('Owner'))),
                                          DataColumn(
                                              label: SizedBox(
                                                  width: 90,
                                                  child: Text('Status'))),
                                        ],
                                        rows: filteredRows
                                            .map(
                                              (item) => DataRow(
                                                cells: [
                                                  DataCell(SizedBox(
                                                    width: 220,
                                                    child: Text(
                                                      item.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.specificationType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 140,
                                                    child: Text(
                                                      item.discipline.isEmpty
                                                          ? '-'
                                                          : item.discipline,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 140,
                                                    child: Text(
                                                      item.area.isEmpty
                                                          ? '-'
                                                          : item.area,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 170,
                                                    child: Text(
                                                      item.wbsWorkPackageTitle
                                                              .isEmpty
                                                          ? '-'
                                                          : item
                                                              .wbsWorkPackageTitle,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.sourceType.isEmpty
                                                          ? '-'
                                                          : item.sourceType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 120,
                                                    child: Text(
                                                      item.owner.isEmpty
                                                          ? '-'
                                                          : item.owner,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                  DataCell(SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.status.isEmpty
                                                          ? '-'
                                                          : item.status,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )),
                                                ],
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                FilledButton.icon(
                  onPressed: filteredRows.isEmpty
                      ? null
                      : () => _exportSpecificationsTablePdf(filteredRows),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Export PDF'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  String _pdfCellValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _buildSpecificationsPdfFilename() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'design_specifications_table_$stamp.pdf';
  }

  Future<void> _exportSpecificationsTablePdf(
    List<_SpecificationOption> rows,
  ) async {
    if (rows.isEmpty) {
      _showToast('No table rows to export.');
      return;
    }

    final filename = _buildSpecificationsPdfFilename();

    try {
      final doc = pw.Document();
      final generatedAt = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(
              'Design Specifications Table',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${generatedAt.toLocal().toIso8601String()}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.topLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              headers: const [
                'Title',
                'Spec type',
                'Discipline',
                'Area',
                'WBS Work Package',
                'Source type',
                'Owner',
                'Status',
              ],
              data: rows
                  .map(
                    (item) => [
                      _pdfCellValue(item.title),
                      _pdfCellValue(item.specificationType),
                      _pdfCellValue(item.discipline),
                      _pdfCellValue(item.area),
                      _pdfCellValue(item.wbsWorkPackageTitle),
                      _pdfCellValue(item.sourceType),
                      _pdfCellValue(item.owner),
                      _pdfCellValue(item.status),
                    ],
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      if (kIsWeb) {
        download_helper.downloadFile(
          bytes,
          filename,
          mimeType: 'application/pdf',
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }

      if (!mounted) return;
      _showToast('PDF exported: $filename');
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to export PDF: $e');
    }
  }

  void _addSpecificationDocument() {
    setState(() {
      _document.specificationDocuments.add(
        DesignPlanningReferenceDoc(category: _specSourceTypeOptions.first),
      );
    });
    _queueSave();
  }

  Future<void> _uploadSpecificationArtifact(String rowId) async {
    final uploaded = await _pickAndUploadAttachment(
      folder: 'planning-design-spec-artifacts',
    );
    if (uploaded == null) return;
    final index =
        _document.specifications.indexWhere((item) => item.id == rowId);
    if (index == -1) return;
    setState(() {
      _document.specifications[index].referenceLink = uploaded.url;
      _document.specifications[index].uploadedFileName = uploaded.name;
      _document.specifications[index].uploadedStoragePath =
          uploaded.storagePath;
    });
    _queueSave();
    _showToast('Specification artifact uploaded.');
  }

  Future<void> _uploadSpecificationDocument(String documentId) async {
    final uploaded = await _pickAndUploadAttachment(
      folder: 'planning-design-spec-documents',
    );
    if (uploaded == null) return;
    final index = _document.specificationDocuments
        .indexWhere((item) => item.id == documentId);
    if (index == -1) return;
    setState(() {
      _document.specificationDocuments[index].link = uploaded.url;
      _document.specificationDocuments[index].fileName = uploaded.name;
      _document.specificationDocuments[index].storagePath =
          uploaded.storagePath;
    });
    _queueSave();
    _showToast('Design specification document uploaded.');
  }

  Future<_UploadedDoc?> _pickAndUploadAttachment({
    required String folder,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showToast('Sign in is required before uploading files.');
      return null;
    }
    final data = ProjectDataHelper.getData(context);
    final projectId = data.projectId;
    if (projectId == null || projectId.trim().isEmpty) {
      _showToast('Select a project before uploading files.');
      return null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'csv',
          'png',
          'jpg',
          'jpeg'
        ],
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        _showToast('Unable to read selected file.');
        return null;
      }
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          'projects/${projectId.trim()}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(file.extension),
      );
      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();
      return _UploadedDoc(
        name: file.name,
        url: downloadUrl,
        storagePath: storagePath,
      );
    } on FirebaseException catch (error) {
      _showToast('Failed to upload file: ${error.message ?? error.code}');
      return null;
    } catch (error) {
      _showToast('Failed to upload file: $error');
      return null;
    }
  }

  String _contentTypeForExtension(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isGenerating(String key) => _aiGenerating[key] == true;

  Future<void> _runAiGenerate({
    required String key,
    required String section,
    required TextEditingController controller,
  }) async {
    if (_isGenerating(key)) return;
    setState(() => _aiGenerating[key] = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: section,
      );
      final generated = await OpenAiServiceSecure().generateFepSectionText(
        section: section,
        context: contextText,
        maxTokens: 900,
        temperature: 0.45,
      );
      if (!mounted) return;
      if (generated.trim().isEmpty) {
        _showToast('AI returned an empty result for $section.');
        return;
      }
      controller.text = generated.trim();
      _queueSave();
      _showToast('$section generated from project context.');
    } catch (e) {
      if (!mounted) return;
      _showToast('AI generation failed for $section: ${aiErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _aiGenerating[key] = false);
      }
    }
  }

  void _autofillOverview(ProjectDataModel data) {
    _overviewController.text = [
      data.solutionDescription.trim(),
      data.businessCase.trim(),
      data.notes.trim(),
    ].where((value) => value.isNotEmpty).join('\n\n');
    _objectivesController.text = [
      data.projectObjective.trim(),
      ...data.planningGoals
          .map((goal) => goal.title.trim())
          .where((value) => value.isNotEmpty),
    ].where((value) => value.isNotEmpty).join('\n');
    _successCriteriaController.text = data.frontEndPlanning.successCriteriaItems
        .map((item) => item.description.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    _scopeController.text = data.withinScopeItems
        .map((item) => item.description.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    _outOfScopeController.text = data.outOfScopeItems
        .map((item) => item.description.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    _queueSave();
    _showToast('Overview autofilled from initiation/planning context.');
  }

  void _autofillDesignOverview(ProjectDataModel data) {
    _designWhoController.text = [
      if (data.charterProjectManagerName.trim().isNotEmpty)
        'Project Manager: ${data.charterProjectManagerName.trim()}',
      if (data.charterProjectSponsorName.trim().isNotEmpty)
        'Project Sponsor: ${data.charterProjectSponsorName.trim()}',
      if (data.charterReviewedBy.trim().isNotEmpty)
        'Reviewer: ${data.charterReviewedBy.trim()}',
      ...data.teamMembers
          .where((member) =>
              member.name.trim().isNotEmpty || member.role.trim().isNotEmpty)
          .take(8)
          .map((member) => [
                if (member.name.trim().isNotEmpty) member.name.trim(),
                if (member.role.trim().isNotEmpty) member.role.trim(),
                if (member.responsibilities.trim().isNotEmpty)
                  member.responsibilities.trim(),
              ].join(' | ')),
    ].where((value) => value.isNotEmpty).join('\n');

    _designHowController.text = [
      if ((data.overallFramework ?? '').trim().isNotEmpty)
        'Framework: ${data.overallFramework!.trim()}',
      if (data.projectObjective.trim().isNotEmpty)
        'Objective: ${data.projectObjective.trim()}',
      if (data.designManagementData != null)
        'Methodology: ${data.designManagementData!.methodology.name}',
      if (data.designManagementData != null)
        'Execution strategy: ${data.designManagementData!.executionStrategy.name}',
      if (data.designManagementData != null &&
          data.designManagementData!.applicableStandards.isNotEmpty)
        'Applicable standards: ${data.designManagementData!.applicableStandards.join(', ')}',
      ...data.planningGoals
          .map((goal) => goal.title.trim())
          .where((value) => value.isNotEmpty)
          .take(5)
          .map((value) => 'Design priority: $value'),
    ].where((value) => value.isNotEmpty).join('\n');

    _designVendorsController.text = [
      if (data.frontEndPlanning.contracts.trim().isNotEmpty)
        'Contracts context: ${data.frontEndPlanning.contracts.trim()}',
      if (data.frontEndPlanning.contractVendorQuotes.trim().isNotEmpty)
        'Vendor quotes context: ${data.frontEndPlanning.contractVendorQuotes.trim()}',
      if (data.frontEndPlanning.procurement.trim().isNotEmpty)
        'Procurement context: ${data.frontEndPlanning.procurement.trim()}',
      if (data.contractors.isNotEmpty)
        'Contractors:\n${data.contractors.map((item) => [
              item.name.trim(),
              item.service.trim(),
              item.status.trim(),
            ].where((value) => value.isNotEmpty).join(' | ')).where((value) => value.isNotEmpty).join('\n')}',
      if (data.vendors.isNotEmpty)
        'Vendors:\n${data.vendors.map((item) => [
              item.name.trim(),
              item.equipmentOrService.trim(),
              item.procurementStage.trim(),
              item.status.trim(),
            ].where((value) => value.isNotEmpty).join(' | ')).where((value) => value.isNotEmpty).join('\n')}',
    ].where((value) => value.isNotEmpty).join('\n\n');

    _designInterfacesController.text = [
      if (data.interfaceEntries.isNotEmpty)
        'Interfaces:\n${data.interfaceEntries.map((entry) => [
              entry.boundary.trim(),
              if (entry.owner.trim().isNotEmpty) 'Owner: ${entry.owner.trim()}',
              if (entry.status.trim().isNotEmpty)
                'Status: ${entry.status.trim()}',
              if (entry.risk.trim().isNotEmpty) 'Risk: ${entry.risk.trim()}',
            ].whereType<String>().join(' | ')).where((value) => value.isNotEmpty).join('\n')}',
      ...data.constraintItems
          .map((item) => item.description.trim())
          .where((value) => value.isNotEmpty)
          .take(6)
          .map((value) => 'Constraint: $value'),
      ...data.assumptionItems
          .map((item) => item.description.trim())
          .where((value) => value.isNotEmpty)
          .take(6)
          .map((value) => 'Assumption: $value'),
      ...data.frontEndPlanning.riskRegisterItems
          .map((item) => item.riskName.trim())
          .where((value) => value.isNotEmpty)
          .take(4)
          .map((value) => 'Risk driver: $value'),
    ].where((value) => value.isNotEmpty).join('\n');

    _queueSave();
    _showToast('Design Overview seeded from initiation and planning context.');
  }

  void _autofillArchitecture(ProjectDataModel data) {
    _architectureController.text = [
      data.frontEndPlanning.infrastructure.trim(),
      data.planningNotes[kDesignPlanningArchitectureKey]?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join('\n\n');
    _dataFlowController.text = data.interfaceEntries
        .map((entry) => [
              entry.boundary.trim(),
              entry.owner.trim().isEmpty
                  ? null
                  : 'Owner: ${entry.owner.trim()}',
              entry.status.trim().isEmpty
                  ? null
                  : 'Status: ${entry.status.trim()}',
            ].whereType<String>().join(' | '))
        .where((value) => value.isNotEmpty)
        .join('\n');
    _document.modules = data.designDeliverablesData.register
        .where((item) => item.name.trim().isNotEmpty)
        .map(
          (item) => DesignPlanningWorkItem(
            name: item.name.trim(),
            purpose: item.risk.trim(),
            owner: item.owner.trim(),
            status: item.status.trim().isEmpty ? 'Planned' : item.status.trim(),
          ),
        )
        .toList();
    _queueSave();
    _showToast('Architecture basis autofilled from planning data.');
  }

  void _autofillUiUx(ProjectDataModel data) {
    _uiUxController.text = [
      data.frontEndPlanning.summary.trim(),
      data.planningNotes[kDesignPlanningUiUxKey]?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join('\n\n');
    _designSystemController.text =
        data.frontEndPlanning.requirementsNotes.trim();
    _document.journeys = data.planningGoals
        .where((goal) => goal.title.trim().isNotEmpty)
        .map(
          (goal) => DesignPlanningWorkItem(
            name: goal.title.trim(),
            purpose: goal.description.trim(),
            status: 'Planned',
          ),
        )
        .toList();
    _document.interfaces = data.interfaceEntries
        .where((entry) => entry.boundary.trim().isNotEmpty)
        .map(
          (entry) => DesignPlanningWorkItem(
            name: entry.boundary.trim(),
            purpose: entry.notes.trim(),
            owner: entry.owner.trim(),
            status:
                entry.status.trim().isEmpty ? 'Planned' : entry.status.trim(),
          ),
        )
        .toList();
    _queueSave();
    _showToast('UI/UX basis autofilled from previous context.');
  }

  void _autofillTechnical(ProjectDataModel data) {
    _technicalFrontendController.text = data.frontEndPlanning.technology.trim();
    _technicalBackendController.text = data.technologyDefinitions
        .map((item) => item['name']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(', ');
    _technicalDataController.text = [
      data.notes.trim(),
      data.frontEndPlanning.infrastructure.trim(),
    ].where((value) => value.isNotEmpty).join('\n\n');
    _document.integrations = data.interfaceEntries
        .where((entry) => entry.boundary.trim().isNotEmpty)
        .map(
          (entry) => DesignPlanningWorkItem(
            name: entry.boundary.trim(),
            purpose: entry.notes.trim(),
            owner: entry.owner.trim(),
            status:
                entry.status.trim().isEmpty ? 'Planned' : entry.status.trim(),
          ),
        )
        .toList();
    _queueSave();
    _showToast('Technical basis autofilled from technology/interface context.');
  }

  void _autofillValidation(ProjectDataModel data) {
    _validationController.text = [
      ...data.planningRequirementItems
          .map((item) => item.acceptanceCriteria.trim())
          .where((value) => value.isNotEmpty),
      ...data.planningRequirementItems
          .map((item) => item.verificationMethod.trim())
          .where((value) => value.isNotEmpty),
    ].join('\n');
    _queueSave();
    _showToast('Validation criteria seeded from planning requirements.');
  }

  List<String> _ownerOptions(ProjectDataModel data) {
    final options = <String>{
      for (final member in data.teamMembers)
        if (member.name.trim().isNotEmpty)
          member.name.trim()
        else if (member.role.trim().isNotEmpty)
          member.role.trim(),
      if (data.charterProjectManagerName.trim().isNotEmpty)
        data.charterProjectManagerName.trim(),
      if (data.charterProjectSponsorName.trim().isNotEmpty)
        data.charterProjectSponsorName.trim(),
    };
    if (options.isEmpty) {
      return const ['Owner'];
    }
    return options.toList()..sort();
  }

  List<_RequirementAttachmentOption> _requirementAttachmentOptions(
    ProjectDataModel projectData,
  ) {
    final options = <_RequirementAttachmentOption>[];
    for (var index = 0;
        index < projectData.frontEndPlanning.requirementItems.length;
        index++) {
      final item = projectData.frontEndPlanning.requirementItems[index];
      final description = item.description.trim();
      if (description.isEmpty && item.id.trim().isEmpty) continue;
      final id = item.id.trim().isNotEmpty
          ? item.id.trim()
          : 'fep_req_${index + 1}_${description.toLowerCase().hashCode.abs()}';
      options.add(
        _RequirementAttachmentOption(
          id: id,
          label: description.isEmpty ? 'Requirement ${index + 1}' : description,
        ),
      );
    }
    options
        .sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  List<_SpecificationOption> _specificationOptions() {
    final options = <_SpecificationOption>[];
    for (var index = 0; index < _document.specifications.length; index++) {
      final row = _document.specifications[index];
      final fallback = 'Specification ${index + 1}';
      final title = row.title.trim().isEmpty ? fallback : row.title.trim();
      options.add(
        _SpecificationOption(
          id: row.id,
          title: title,
          details: row.details.trim(),
          specificationType: row.specificationType.trim(),
          discipline: row.discipline.trim(),
          area: row.area.trim(),
          sourceType: row.sourceType.trim(),
          owner: row.owner.trim(),
          status: row.status.trim(),
          referenceLink: row.referenceLink.trim(),
          wbsWorkPackageId: row.wbsWorkPackageId.trim(),
          wbsWorkPackageTitle: row.wbsWorkPackageTitle.trim(),
        ),
      );
    }
    return options;
  }

  String _stripWbsPrefix(String title) {
    final pattern = RegExp(r'^[GS]\d+(?:\.\d+)*(?:\s*[:\-])?\s*');
    return title.replaceFirst(pattern, '').trim();
  }

  List<_WbsWorkPackageOption> _extractWbsWorkPackages(ProjectDataModel data) {
    final output = <_WbsWorkPackageOption>[];

    void addOption({
      required WorkItem item,
      required String parentTitle,
      required String disciplineSeed,
      required String areaSeed,
      required int level,
    }) {
      final title = _stripWbsPrefix(item.title);
      if (title.isEmpty) return;
      final rawId = item.id.trim();
      final id = rawId.isNotEmpty
          ? rawId
          : 'wbs_pkg_${level}_${output.length + 1}_${parentTitle.hashCode.abs()}_${title.hashCode.abs()}';
      output.add(
        _WbsWorkPackageOption(
          id: id,
          title: title,
          parentTitle: parentTitle,
          level: level,
          disciplineSeed: disciplineSeed,
          areaSeed: areaSeed,
        ),
      );
    }

    for (final topLevel in data.wbsTree) {
      final topTitle = _stripWbsPrefix(topLevel.title);
      if (topLevel.children.isNotEmpty) {
        for (final level2 in topLevel.children) {
          final level2Title = _stripWbsPrefix(level2.title);
          addOption(
            item: level2,
            parentTitle: topTitle,
            disciplineSeed: topTitle,
            areaSeed: level2Title.isEmpty ? topTitle : level2Title,
            level: 2,
          );
        }
      } else {
        addOption(
          item: topLevel,
          parentTitle: '',
          disciplineSeed: topTitle,
          areaSeed: topTitle,
          level: 1,
        );
      }
    }

    return output;
  }

  List<String> _wbsDisciplineOptions(
    List<_WbsWorkPackageOption> packages,
    List<String> fallback,
  ) {
    final values = <String>[
      ...packages
          .map((item) => item.disciplineSeed.trim())
          .where((value) => value.isNotEmpty),
      ...fallback,
    ];
    return _dedupeOptions(values);
  }

  List<String> _wbsAreaOptions(
    List<_WbsWorkPackageOption> packages,
    List<String> fallback,
  ) {
    final values = <String>[
      ...packages
          .map((item) => item.areaSeed.trim())
          .where((value) => value.isNotEmpty),
      ...fallback,
    ];
    return _dedupeOptions(values);
  }

  List<String> _dedupeOptions(List<String> values) {
    final output = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      output.add(trimmed);
    }
    return output;
  }

  List<_RequirementAttachmentOption> _unlinkedRequirements(
    List<_RequirementAttachmentOption> requirementOptions,
  ) {
    final linkedIds = <String>{};
    for (final row in _document.specifications) {
      for (final id in row.attachedRequirementIds) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) linkedIds.add(trimmed);
      }
    }
    return requirementOptions
        .where((option) => !linkedIds.contains(option.id))
        .toList(growable: false);
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Design Planning',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Project Name': projectData.projectName.isEmpty
                ? 'N/A'
                : projectData.projectName
          },
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['design_planning_screen'] ??
                'No data recorded.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final owners = _ownerOptions(projectData);
    final isMobile = AppBreakpoints.isMobile(context);

    return ResponsiveScaffold(
      activeItemLabel: widget.activeItemLabel ?? 'Design Planning',
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: Column(
        children: [
          PlanningPhaseHeader(
              title: 'Design Planning', onExportPdf: _exportPdf),
          _buildPageContext(projectData),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              child: _buildMainColumn(projectData, owners),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(ProjectDataModel data) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kBrandDark,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Text(
              'NDU',
              style: TextStyle(
                color: _kBrandYellow,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'PROJECT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kGray900,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, size: 22),
            color: _kGray500,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: _kBlue600,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContext(ProjectDataModel data) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  data.projectName.trim().isEmpty
                      ? 'Unnamed Project'
                      : data.projectName.trim(),
                  style: const TextStyle(fontSize: 12, color: _kGray500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 14, color: _kGray400),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'Planning Phase',
                  style: TextStyle(fontSize: 12, color: _kGray500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Design Planning',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kGray900,
                ),
              ),
              const Spacer(),
              Flexible(child: _buildProgressSummary()),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<_SaveIndicatorState>(
            valueListenable: _saveIndicatorNotifier,
            builder: (context, state, _) => _AutoSaveIndicator(
              saving: state.saving,
              pending: state.pending,
              lastSavedAt: state.lastSavedAt,
            ),
          ),
        ],
      ),
    );
  }

  /// Header progress summary: how many guided sections are resolved and a
  /// one-tap jump into the next pending one.
  ///
  /// Replaces the old dead "Activity" button — a control that did nothing is
  /// the opposite of intuitive — with the two things this page must say at a
  /// glance: where the user is in the flow, and what comes next.
  Widget _buildProgressSummary() {
    final total = _sectionOrder.length;
    final done = _sectionOrder.where((s) => _isSectionResolved(s.id)).length;
    final allDone = done == total;
    final next = _sectionOrder.firstWhere(
      (s) => !_isSectionResolved(s.id),
      orElse: () => _sectionOrder.first,
    );
    return Tooltip(
      message: allDone
          ? 'Every section is complete or marked not applicable.'
          : 'Next up: ${next.label}',
      child: FilledButton.icon(
        onPressed: allDone ? null : _openFirstUnresolvedSection,
        icon: Icon(
          allDone ? Icons.verified_outlined : Icons.flag_outlined,
          size: 15,
        ),
        label: Text(
          allDone
              ? 'All $total sections done'
              : '$done of $total sections · Next: ${next.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: allDone ? _kSuccess : _kBrandYellow,
          foregroundColor: allDone ? Colors.white : _kBrandDark,
          disabledBackgroundColor: _kSuccess.withValues(alpha: 0.15),
          disabledForegroundColor: _kSuccess,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          minimumSize: Size.zero,
        ),
      ),
    );
  }

  /// Jumps to the first still-pending section — the button inside
  /// [_buildProgressSummary], and the mental model the whole page should
  /// support: "always know, always one tap away from, what's next".
  Future<void> _openFirstUnresolvedSection() async {
    final next = _sectionOrder.firstWhere(
      (s) => !_isSectionResolved(s.id),
      orElse: () => _sectionOrder.first,
    );
    await _activateSection(next.id);
  }

  /// The inner sections that are still pending.
  ///
  /// Design Planning is one planning step spread over 15 guided sections, so
  /// leaving it early skips work the user never saw — "if they go all the way
  /// down … they might click next and they'll skip everything else here"
  /// (Lusaka 25 (copy)). A section counts as done once it is Complete or marked
  /// Not applicable; only *pending* blocks.
  List<SectionTab> get _unfinishedSections => unvisitedTabs(
        'design',
        _sectionOrder
            .map((section) => section.id)
            .where(_isSectionResolved)
            .toList(growable: false),
      );

  /// Next is only allowed once every inner section has been resolved. Returns
  /// true when the caller may navigate; otherwise it says what is missing.
  bool _confirmSectionsFinished() {
    final missing = _unfinishedSections;
    if (missing.isEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sectionIncompleteMessage('design', missing)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    return false;
  }

  /// Names the sections still to resolve, so the gate teaches the flow instead
  /// of just refusing to move.
  Widget _buildFlowGateNotice(List<SectionTab> missing) {
    final names = missing.map((section) => section.label).join(', ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Finish the flow within Design Planning before moving on. '
              'Still to resolve: $names.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isMobile = AppBreakpoints.isMobile(context);
    final unfinished = _unfinishedSections;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding + 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unfinished.isNotEmpty) _buildFlowGateNotice(unfinished),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      PlanningPhaseNavigation.goToPrevious(context, 'design'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: isMobile ? 8 : 16,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: _kBorder),
                    foregroundColor: _kGray700,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child:
                              Text(PlanningPhaseNavigation.backLabel('design')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  // Grayed out rather than hidden: the destination stays
                  // discoverable, and pressing it explains what is missing instead
                  // of silently refusing.
                  onPressed: () {
                    if (!_confirmSectionsFinished()) return;
                    PlanningPhaseNavigation.goToNext(context, 'design');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: unfinished.isEmpty
                        ? _kBrandYellow
                        : const Color(0xFFE5E7EB),
                    foregroundColor: unfinished.isEmpty
                        ? _kBrandDark
                        : const Color(0xFF9CA3AF),
                    padding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: isMobile ? 8 : 16,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child:
                              Text(PlanningPhaseNavigation.nextLabel('design')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainColumn(ProjectDataModel data, List<String> owners) {
    final sections = <String, Widget>{
      'overview': _buildOverviewSection(data),
      'design_overview': _buildDesignOverviewSection(data),
      'design_specifications_workspace':
          _buildDesignSpecificationsWorkspaceSection(),
      'deviations': _buildDeviationsSection(),
      'requirements': _buildRequirementsSection(owners),
      'architecture': _buildArchitectureSection(owners),
      'uiux': _buildUiUxSection(owners),
      'technical': _buildTechnicalSection(owners),
      'constraints': _buildConstraintsSection(),
      'risks': _buildRisksSection(owners),
      'dependencies': _buildDependenciesSection(owners),
      'decisions': _buildDecisionLogSection(owners),
      'validation': _buildValidationSection(),
      'approvals': _buildApprovalsSection(owners),
      'work_packages': _buildWorkPackagesSection(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The original inner-page navigation hint was removed; clear, numbered
        // groups now make the guided flow easy to scan without changing its order.
        for (var index = 0; index < _sectionGroups.length; index++) ...[
          _buildSectionGroupHeader(index, _sectionGroups[index]),
          for (final sectionId in _sectionGroups[index].sectionIds)
            if (sections[sectionId] case final section?) section,
        ],
      ],
    );
  }

  Widget _buildSectionGroupHeader(int index, _SectionGroupMeta group) {
    final resolved = group.sectionIds.where(_isSectionResolved).length;
    final allResolved = resolved == group.sectionIds.length;
    final compact = MediaQuery.sizeOf(context).width < 420;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, index == 0 ? 16 : 28, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: allResolved
                  ? _kSuccess.withValues(alpha: 0.1)
                  : _kBrandYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: allResolved
                ? const Icon(Icons.check_rounded, size: 18, color: _kSuccess)
                : Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: _kBrandDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    color: _kGray900,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kGray500, fontSize: 12),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: resolved / group.sectionIds.length,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE9ECEF),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allResolved ? _kSuccess : _kBrandYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: allResolved
                  ? const Color(0xFFECFDF3)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              compact
                  ? '$resolved/${group.sectionIds.length}'
                  : '$resolved / ${group.sectionIds.length} resolved',
              style: TextStyle(
                color: allResolved ? _kSuccess : _kGray700,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Note: The original _mapSectionProgress() helper that mapped section
  // progress state to InnerPageSectionStatus was removed along with the
  // InnerPageNavigationHint modal. If you need it again, restore the
  // import of inner_page_navigation_hint.dart and re-implement based
  // on git history (commit prior to this change).

  Widget _buildGuidedSectionCard({
    required String sectionId,
    required GlobalKey sectionKey,
    required String title,
    required String subtitle,
    required Color accent,
    required Widget child,
  }) {
    final isExpanded = _sectionExpanded[sectionId] == true;
    final progressState =
        _sectionProgress[sectionId] ?? _SectionProgressState.pending;
    // The next pending section in flow order is the one the user should be
    // in — give it the "Continue" affordance so the page answers "what do I
    // do now?" without reading a single label.
    final nextPendingId = _sectionOrder
        .firstWhere(
          (s) => !_isSectionResolved(s.id),
          orElse: () => _sectionOrder.first,
        )
        .id;
    final isNextUp = sectionId == nextPendingId &&
        progressState == _SectionProgressState.pending;
    return Container(
      key: sectionKey,
      child: _SectionCard(
        expansionKey: ValueKey(
            'tile_${sectionId}_${_sectionTileVersion[sectionId] ?? 0}'),
        title: title,
        subtitle: subtitle,
        accent: accent,
        expanded: isExpanded,
        enabled: true,
        progressState: progressState,
        isNextUp: isNextUp,
        stepNumber:
            _sectionOrder.indexWhere((section) => section.id == sectionId) + 1,
        onExpansionChanged: (expanded) =>
            _onSectionExpansionChanged(sectionId, expanded),
        child: isExpanded
            ? Column(
                children: [
                  _buildSectionProgressControls(sectionId),
                  child,
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOverviewSection(ProjectDataModel data) {
    return _buildGuidedSectionCard(
      sectionId: 'overview',
      sectionKey: _sectionKeys['overview']!,
      title: 'Project Overview',
      subtitle:
          'Capture the design basis, objectives, success criteria, and the planning boundary for the whole design effort.',
      accent: _kPrimary,
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () => _autofillOverview(data),
            generating: _isGenerating('overview'),
            onGenerate: () => _runAiGenerate(
              key: 'overview',
              section: 'Project Overview',
              controller: _overviewController,
            ),
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _overviewController,
            label: 'Design basis summary',
            hintText:
                'Describe the design basis and the project design intent.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _ResponsivePair(
            left: _TextAreaField(
              controller: _objectivesController,
              label: 'Objectives',
              hintText: 'One item per line',
              minLines: 5,
              onChanged: (_) => _queueSave(),
            ),
            right: _TextAreaField(
              controller: _successCriteriaController,
              label: 'Success criteria',
              hintText: 'One item per line',
              minLines: 5,
              onChanged: (_) => _queueSave(),
            ),
          ),
          const SizedBox(height: 14),
          _ResponsivePair(
            left: _TextAreaField(
              controller: _scopeController,
              label: 'In scope',
              hintText: 'One item per line',
              minLines: 4,
              onChanged: (_) => _queueSave(),
            ),
            right: _TextAreaField(
              controller: _outOfScopeController,
              label: 'Out of scope',
              hintText: 'One item per line',
              minLines: 4,
              onChanged: (_) => _queueSave(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection(List<String> owners) {
    final specificationOptions = _specificationOptions();
    final requirementOptions =
        _requirementAttachmentOptions(ProjectDataHelper.getData(context));
    final unlinkedRequirements = _unlinkedRequirements(requirementOptions);
    return _buildGuidedSectionCard(
      sectionId: 'requirements',
      sectionKey: _sectionKeys['requirements']!,
      title: 'Requirements to Design Mapping',
      // Lusaka 25 (copy): "specifications and requirements mapping are not the
      // same thing — split them." The two are separate sections, and this
      // wording keeps them apart: specifications are written on the Design
      // Specifications section, and this section records which planning
      // requirement each one satisfies.
      subtitle:
          'Map each planning requirement to the specification that satisfies '
          'it. Write the specifications themselves on the Design Specifications '
          'section; this is the link between the two.',
      accent: const Color(0xFF0F9D58),
      child: Column(
        children: [
          if (unlinkedRequirements.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Text(
                '${unlinkedRequirements.length} requirement(s) are not linked to specifications yet.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          _SubHeader(
            title: 'Mappings',
            actionLabel: 'Add mapping',
            onAction: () {
              setState(
                  () => _document.requirements.add(DesignRequirementMapping()));
              _queueSave();
              _showToast('Mapping row added.');
            },
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _document.requirements.length; i++) ...[
            _MappingCard(
              data: _document.requirements[i],
              availableSpecifications: specificationOptions,
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.requirements.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.requirements.length - 1)
              const SizedBox(height: 12),
          ],
          if (_document.requirements.isEmpty)
            const _EmptyState(
              message:
                  'No mappings yet. Add rows here to make the design basis traceable.',
            ),
        ],
      ),
    );
  }

  Widget _buildDesignOverviewSection(ProjectDataModel data) {
    return _buildGuidedSectionCard(
      sectionId: 'design_overview',
      sectionKey: _sectionKeys['design_overview']!,
      title: 'Design Overview',
      subtitle:
          'Document design basis details covering who owns design outcomes, how design will be executed, and what vendor/contract/interface constraints shape the solution.',
      accent: const Color(0xFFFFC812),
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () => _autofillDesignOverview(data),
            generating: _isGenerating('design_overview'),
            onGenerate: () => _runAiGenerate(
              key: 'design_overview',
              section: 'Design Overview (Who, How, Vendors, Contracts)',
              controller: _designHowController,
            ),
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _designWhoController,
            label: 'Responsibilities',
            hintText:
                'Who leads architecture, UI/UX, technical design, reviews, and approvals.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _designHowController,
            label: 'Design Execution Strategy',
            hintText:
                'Methodology, cadence, standards, decision flow, and governance approach.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _designVendorsController,
            label: 'Vendor & contract inputs',
            hintText:
                'Contractors, vendors, procurement stage, and contract dependencies impacting design.',
            minLines: 5,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _designInterfacesController,
            label: 'Interfaces, constraints, and risk drivers',
            hintText:
                'Key interfaces plus constraints/assumptions that must be honored by design.',
            minLines: 5,
            onChanged: (_) => _queueSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'architecture',
      sectionKey: _sectionKeys['architecture']!,
      title: 'System Architecture Basis',
      subtitle:
          'Define the architecture direction, modules, diagram references, and data flow that downstream design must honor.',
      accent: const Color(0xFFB8860B),
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () =>
                _autofillArchitecture(ProjectDataHelper.getData(context)),
            generating: _isGenerating('architecture'),
            onGenerate: () => _runAiGenerate(
              key: 'architecture',
              section: 'System Architecture Basis',
              controller: _architectureController,
            ),
          ),
          const SizedBox(height: 12),
          // Lusaka 25 (copy): the owner could not tell what "Model 1, 2, 3"
          // referred to. The rows are architecture *modules*, so the section
          // now says what one is before showing numbered cards.
          const _ArchitectureModuleExplainer(),
          const SizedBox(height: 14),
          _SubHeader(
            title: 'Modules',
            actionLabel: 'Add module',
            onAction: () {
              setState(() => _document.modules.add(DesignPlanningWorkItem()));
              _queueSave();
              _showToast('Architecture module row added.');
            },
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _architectureController,
            label: 'Architecture summary',
            hintText:
                'Describe the intended system architecture and boundaries.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextField(
            controller: _diagramReferenceController,
            label: 'Diagram reference / upload link',
            hintText:
                'Figma, Miro, Draw.io, URL, or internal artifact reference',
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _dataFlowController,
            label: 'Data flow summary',
            hintText:
                'Summarize key flows, boundaries, and integration routes.',
            minLines: 3,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(
              height:
                  14), // The table view of the same rows, for scanning and for pasting
          // into a design pack — the owner asked for a pop-out table because
          // the numbered cards could not be read as a whole
          // (Lusaka 25 (copy)).
          if (_document.modules.isNotEmpty) ...[
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showArchitectureModulesTable(),
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: Text(
                    'Open module table (${_document.modules.length})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < _document.modules.length; i++) ...[
            _WorkItemCard(
              // Names the module when it has one, so the card does not read as
              // an arbitrary "Model 2". The number is kept as a position cue.
              title: architectureModuleLabel(_document.modules[i], i),
              data: _document.modules[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.modules.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.modules.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// The column set shared by the specifications import and export, so a file
  /// that came out of the table can always go back in.
  static const List<CsvColumnSpec> _specCsvColumns = [
    CsvColumnSpec(
        key: 'title',
        label: 'Title',
        required: true,
        hint: 'Specification title'),
    CsvColumnSpec(
        key: 'specificationType',
        label: 'Spec type',
        allowedValues: [
          'Code',
          'Law',
          'Standard',
          'Criteria',
          'Guideline',
          'Contract',
          'Other'
        ],
        defaultValue: 'Standard'),
    CsvColumnSpec(
        key: 'discipline',
        label: 'Discipline',
        hint: 'e.g. Architecture, Civil, Frontend'),
    CsvColumnSpec(
        key: 'area', label: 'Area', hint: 'e.g. Design, Security, Data'),
    CsvColumnSpec(
        key: 'wbsWorkPackageTitle',
        label: 'WBS Work Package',
        hint: 'WBS work package title'),
    CsvColumnSpec(
        key: 'sourceType',
        label: 'Source type',
        allowedValues: ['Contracts', 'Vendors', 'Regulatory', 'Standards'],
        defaultValue: 'Standards'),
    CsvColumnSpec(key: 'owner', label: 'Owner', hint: 'Specification owner'),
    CsvColumnSpec(
        key: 'status',
        label: 'Status',
        allowedValues: ['Draft', 'Planned', 'In Review'],
        defaultValue: 'Draft'),
  ];

  /// Export the specification rows as the same CSV the importer accepts, so the
  /// round trip is: export → edit in a spreadsheet → import.
  Future<void> _exportSpecificationRows() async {
    final rows = _document.specifications
        .map((row) => <String, String>{
              'title': row.title,
              'specificationType': row.specificationType,
              'discipline': row.discipline,
              'area': row.area,
              'wbsWorkPackageTitle': row.wbsWorkPackageTitle,
              'sourceType': row.sourceType,
              'owner': row.owner,
              'status': row.status,
            })
        .toList(growable: false);

    final csv = CsvImportHelper.exportRows(_specCsvColumns, rows);
    final filename = CsvImportHelper.templateFilename('Specifications')
        .replaceFirst('template', 'export');

    try {
      download_helper.downloadFile(
        Uint8List.fromList(utf8.encode(csv)),
        filename,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      _showToast(
        rows.isEmpty
            ? 'Exported an empty specifications file: $filename'
            : 'Exported ${rows.length} specification row'
                '${rows.length == 1 ? '' : 's'}: $filename',
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('Could not export specifications: $e');
    }
  }

  /// Pop the architecture modules out as a single table.
  ///
  /// Read-only: the cards remain the place to edit, because a table cell is a
  /// poor place to write a module's purpose. This view exists to answer "what
  /// have I actually got?" at a glance.
  Future<void> _showArchitectureModulesTable() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Architecture Modules'),
        content: SizedBox(
          width: 820,
          child: _ArchitectureModulesTable(modules: _document.modules),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignSpecificationsWorkspaceSection() {
    final projectData = ProjectDataHelper.getData(context);
    final owners = _ownerOptions(projectData);
    final requirementOptions = _requirementAttachmentOptions(projectData);
    final wbsWorkPackages = _extractWbsWorkPackages(projectData);
    final disciplineOptions =
        _wbsDisciplineOptions(wbsWorkPackages, _specDisciplineOptions);
    final areaOptions = _wbsAreaOptions(wbsWorkPackages, _specAreaOptions);
    final unlinkedRequirements = _unlinkedRequirements(requirementOptions);
    return _buildGuidedSectionCard(
      sectionId: 'design_specifications_workspace',
      sectionKey: _sectionKeys['design_specifications_workspace']!,
      title: 'Design Specifications',
      subtitle:
          'Plan the configuration, rows, links, and supporting documents that feed the Design Phase specifications workspace.',
      accent: const Color(0xFF0F766E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use this workspace for executable design specifications:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prepare spec rows and document references here, then open the design-phase workspace to continue with full implementation and section approval.',
            style: TextStyle(
              fontSize: 12.5,
              color: _kMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: 'Open Design Phase Workspace',
                icon: Icons.open_in_new,
                onPressed: () {
                  context.push('/design-phase');
                },
              ),
            ],
          ),
          AnimatedCrossFade(
            crossFadeState: CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unlinkedRequirements.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Text(
                          'Requirement coverage gap: ${unlinkedRequirements.length} requirement(s) not linked to any specification row.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A3412),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (wbsWorkPackages.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'WBS continuity warning: no WBS work packages found. Populate Work Breakdown Structure first to auto-seed Discipline and Area.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        const Text(
                          'Specification rows',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                        const Spacer(),
                        // Export / re-import round trip. The same column set drives both, so
                        // an exported file is always accepted back
                        // (Lusaka 25 (copy): "import/export template").
                        TextButton.icon(
                          onPressed: _exportSpecificationRows,
                          icon: const Icon(Icons.file_download_outlined,
                              size: 16),
                          label: const Text('Export rows'),
                        ),
                        const SizedBox(width: 4),
                        CsvTableImportButton(
                          compact: true,
                          tableTitle: 'Specifications',
                          columns: _specCsvColumns,
                          onImport: (rows) {
                            setState(() {
                              for (final row in rows) {
                                final newRow = DesignSpecificationPlanRow(
                                  title: row['title'] ?? '',
                                  specificationType:
                                      row['specificationType'] ?? 'Standard',
                                  discipline: row['discipline'] ?? '',
                                  area: row['area'] ?? '',
                                  wbsWorkPackageTitle:
                                      row['wbsWorkPackageTitle'] ?? '',
                                  sourceType: row['sourceType'] ?? 'Standards',
                                  owner: row['owner'] ?? '',
                                  status: row['status'] ?? 'Draft',
                                  ruleType: 'Internal',
                                );
                                _document.specifications.add(newRow);
                                _specificationRowKeys[newRow.id] = GlobalKey(
                                  debugLabel: 'spec_row_${newRow.id}',
                                );
                              }
                            });
                            _queueSave();
                          },
                        ),
                        const SizedBox(width: 4),
                        _InlineAddButton(
                            label: 'Add row', onPressed: _addSpecificationRow),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // The table is the default view: the owner asked to read the rows as
                    // a whole, and the cards are still one tap away for editing
                    // (Lusaka 25 (copy): "specifications need a table view, and the table
                    // view should be the default … cards stay available").
                    Row(
                      children: [
                        _SpecViewToggle(
                          mode: _specViewMode,
                          onChanged: (mode) =>
                              setState(() => _specViewMode = mode),
                        ),
                        const Spacer(),
                        _ActionButton(
                          label: 'Open full table',
                          icon: Icons.open_in_full,
                          onPressed: _showSpecificationsTableDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_specViewMode == _SpecViewMode.table &&
                        _document.specifications.isNotEmpty) ...[
                      _SpecificationsInlineTable(
                        rows: _specificationOptions(),
                        onOpenCards: () =>
                            setState(() => _specViewMode = _SpecViewMode.cards),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_specViewMode == _SpecViewMode.cards ||
                        _document.specifications.isEmpty)
                      for (var i = 0;
                          i < _document.specifications.length;
                          i++) ...[
                        Container(
                          key: _specificationRowKeys[
                              _document.specifications[i].id],
                          child: _SpecificationPlanRowCard(
                            key: ValueKey(_document.specifications[i].id),
                            index: i + 1,
                            data: _document.specifications[i],
                            owners: owners,
                            requirementOptions: requirementOptions,
                            specificationTypeOptions: _specificationTypeOptions,
                            disciplineOptions: disciplineOptions,
                            areaOptions: areaOptions,
                            wbsWorkPackages: wbsWorkPackages,
                            sourceTypeOptions: _specSourceTypeOptions,
                            ruleTypeOptions: _specRuleTypeOptions,
                            statusOptions: _specRowStatusOptions,
                            uploadsEnabled: true,
                            onChanged: _queueSave,
                            onUpload: () => _uploadSpecificationArtifact(
                              _document.specifications[i].id,
                            ),
                            onRemove: () {
                              final removedId = _document.specifications[i].id;
                              setState(() {
                                _document.specifications.removeAt(i);
                                _specificationRowKeys.remove(removedId);
                              });
                              _queueSave();
                            },
                          ),
                        ),
                        if (i != _document.specifications.length - 1)
                          const SizedBox(height: 12),
                      ],
                    if (_document.specifications.isEmpty)
                      const _EmptyState(
                        message:
                            'No specification planning rows yet. Add rows to define internal/external rules and source context.',
                      ),
                    const SizedBox(height: 14),
                    _SubHeader(
                      title: 'Documents and links',
                      actionLabel: 'Add document',
                      onAction: _addSpecificationDocument,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0;
                        i < _document.specificationDocuments.length;
                        i++) ...[
                      _SpecificationDocumentCard(
                        key: ValueKey(_document.specificationDocuments[i].id),
                        index: i + 1,
                        data: _document.specificationDocuments[i],
                        requirementOptions: requirementOptions,
                        sourceTypeOptions: _specSourceTypeOptions,
                        uploadsEnabled: true,
                        onChanged: _queueSave,
                        onUpload: () => _uploadSpecificationDocument(
                          _document.specificationDocuments[i].id,
                        ),
                        onRemove: () {
                          setState(() =>
                              _document.specificationDocuments.removeAt(i));
                          _queueSave();
                        },
                      ),
                      if (i != _document.specificationDocuments.length - 1)
                        const SizedBox(height: 12),
                    ],
                    if (_document.specificationDocuments.isEmpty)
                      const _EmptyState(
                        message:
                            'No specification reference documents yet. Add links or upload files to seed the Design Phase workspace.',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviationsSection() {
    final specificationOptions = _specificationOptions();
    return _buildGuidedSectionCard(
      sectionId: 'deviations',
      sectionKey: _sectionKeys['deviations']!,
      title: 'Deviations',
      subtitle:
          'Record approved exceptions that deviate from planned specification items before execution begins.',
      accent: const Color(0xFFFFC812),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubHeader(
            title: 'Deviation entries',
            actionLabel: 'Add deviation',
            onAction: _addDeviation,
          ),
          const SizedBox(height: 8),
          const Text(
            'Exceptions from Specifications, Codes, Standards and Criteria',
            style: TextStyle(
              fontSize: 12.5,
              color: _kMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _document.deviations.length; i++) ...[
            _SpecificationDeviationCard(
              key: ValueKey(_document.deviations[i].id),
              index: i + 1,
              data: _document.deviations[i],
              specificationOptions: specificationOptions,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.deviations.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.deviations.length - 1)
              const SizedBox(height: 12),
          ],
          if (_document.deviations.isEmpty)
            const _EmptyState(
              message:
                  'No deviations logged. Add deviations to capture approved exceptions.',
            ),
        ],
      ),
    );
  }

  Widget _buildUiUxSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'uiux',
      sectionKey: _sectionKeys['uiux']!,
      title: 'UI/UX Design Basis',
      subtitle:
          'Capture journeys, interface areas, and design-system expectations that should feed the later UI/UX design work.',
      accent: const Color(0xFFD97706),
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () => _autofillUiUx(ProjectDataHelper.getData(context)),
            generating: _isGenerating('uiux'),
            onGenerate: () => _runAiGenerate(
              key: 'uiux',
              section: 'UI/UX Design Basis',
              controller: _uiUxController,
            ),
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _uiUxController,
            label: 'Experience summary',
            hintText:
                'Describe the intended experience, primary outcomes, and user focus.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _designSystemController,
            label: 'Design system expectations',
            hintText:
                'Colors, typography, accessibility, components, interaction rules.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _SubHeader(
            title: 'User journeys',
            actionLabel: 'Add journey',
            onAction: () {
              setState(() => _document.journeys.add(DesignPlanningWorkItem()));
              _queueSave();
              _showToast('UI/UX journey row added.');
            },
          ),
          for (var i = 0; i < _document.journeys.length; i++) ...[
            _WorkItemCard(
              title: 'Journey ${i + 1}',
              data: _document.journeys[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.journeys.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.journeys.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          _SubHeader(
            title: 'Interface areas',
            actionLabel: 'Add interface',
            onAction: () {
              setState(
                  () => _document.interfaces.add(DesignPlanningWorkItem()));
              _queueSave();
              _showToast('Interface row added.');
            },
          ),
          for (var i = 0; i < _document.interfaces.length; i++) ...[
            _WorkItemCard(
              title: 'Interface ${i + 1}',
              data: _document.interfaces[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.interfaces.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.interfaces.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTechnicalSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'technical',
      sectionKey: _sectionKeys['technical']!,
      title: 'Technical Design Basis',
      subtitle:
          'Record the planning-level stack, integrations, and technical rules the engineering design work should inherit.',
      accent: const Color(0xFF0F766E),
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () =>
                _autofillTechnical(ProjectDataHelper.getData(context)),
            generating: _isGenerating('technical'),
            onGenerate: () => _runAiGenerate(
              key: 'technical',
              section: 'Technical Design Basis',
              controller: _technicalDataController,
            ),
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _TextAreaField(
              controller: _technicalFrontendController,
              label: 'Frontend / application stack',
              hintText: 'Frameworks, platforms, client architecture.',
              minLines: 4,
              onChanged: (_) => _queueSave(),
            ),
            right: _TextAreaField(
              controller: _technicalBackendController,
              label: 'Backend / service stack',
              hintText: 'Services, APIs, integrations, backend expectations.',
              minLines: 4,
              onChanged: (_) => _queueSave(),
            ),
          ),
          const SizedBox(height: 14),
          _TextAreaField(
            controller: _technicalDataController,
            label: 'Database / data / platform notes',
            hintText:
                'Data model, storage, environments, platform constraints.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          _SubHeader(
            title: 'Integrations',
            actionLabel: 'Add integration',
            onAction: () {
              setState(
                  () => _document.integrations.add(DesignPlanningWorkItem()));
              _queueSave();
              _showToast('Integration row added.');
            },
          ),
          for (var i = 0; i < _document.integrations.length; i++) ...[
            _WorkItemCard(
              title: 'Integration ${i + 1}',
              data: _document.integrations[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.integrations.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.integrations.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildConstraintsSection() {
    return _buildGuidedSectionCard(
      sectionId: 'constraints',
      sectionKey: _sectionKeys['constraints']!,
      title: 'Constraints & Assumptions',
      subtitle:
          'State the basis conditions the design is planning against. One item per line keeps this compact and traceable.',
      accent: const Color(0xFFF59E0B),
      child: _ResponsivePair(
        left: _TextAreaField(
          controller: _constraintsController,
          label: 'Constraints',
          hintText: 'Budget, timeline, technology, policy, staffing...',
          minLines: 6,
          onChanged: (_) => _queueSave(),
        ),
        right: _TextAreaField(
          controller: _assumptionsController,
          label: 'Assumptions',
          hintText: 'Availability, dependencies, approvals, environments...',
          minLines: 6,
          onChanged: (_) => _queueSave(),
        ),
      ),
    );
  }

  Widget _buildRisksSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'risks',
      sectionKey: _sectionKeys['risks']!,
      title: 'Risks & Mitigation',
      subtitle:
          'Expose design-planning risks early so the design phase can inherit mitigations instead of rediscovering them.',
      accent: const Color(0xFFDC2626),
      child: Column(
        children: [
          _SubHeader(
            title: 'Risk register',
            actionLabel: 'Add risk',
            onAction: () {
              setState(() => _document.risks.add(DesignRiskEntry()));
              _queueSave();
              _showToast('Risk row added.');
            },
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _document.risks.length; i++) ...[
            _RiskCard(
              data: _document.risks[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.risks.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.risks.length - 1) const SizedBox(height: 12),
          ],
          if (_document.risks.isEmpty)
            const _EmptyState(
              message: 'No design-planning risks logged yet.',
            ),
        ],
      ),
    );
  }

  Widget _buildDependenciesSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'dependencies',
      sectionKey: _sectionKeys['dependencies']!,
      title: 'Dependencies',
      subtitle:
          'Track the external systems, teams, approvals, and vendors the design effort depends on.',
      accent: const Color(0xFFD97706),
      child: Column(
        children: [
          _SubHeader(
            title: 'Dependency register',
            actionLabel: 'Add dependency',
            onAction: () {
              setState(
                  () => _document.dependencies.add(DesignDependencyEntry()));
              _queueSave();
              _showToast('Dependency row added.');
            },
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _document.dependencies.length; i++) ...[
            _DependencyCard(
              data: _document.dependencies[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.dependencies.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.dependencies.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDecisionLogSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'decisions',
      sectionKey: _sectionKeys['decisions']!,
      title: 'Design Decision Log',
      subtitle:
          'Keep rationale visible so architecture, UI/UX, and engineering decisions remain traceable during execution.',
      accent: const Color(0xFF4F46E5),
      child: Column(
        children: [
          _SubHeader(
            title: 'Decision entries',
            actionLabel: 'Add decision',
            onAction: () {
              setState(() => _document.decisions.add(DesignDecisionEntry()));
              _queueSave();
              _showToast('Decision log row added.');
            },
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _document.decisions.length; i++) ...[
            _DecisionCard(
              data: _document.decisions[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.decisions.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.decisions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildValidationSection() {
    return _buildGuidedSectionCard(
      sectionId: 'validation',
      sectionKey: _sectionKeys['validation']!,
      title: 'Validation & Acceptance Criteria',
      subtitle:
          'Define how the planned design will be tested, reviewed, and accepted before execution starts.',
      accent: const Color(0xFF15803D),
      child: Column(
        children: [
          _AssistActions(
            onAutofill: () =>
                _autofillValidation(ProjectDataHelper.getData(context)),
            generating: _isGenerating('validation'),
            onGenerate: () => _runAiGenerate(
              key: 'validation',
              section: 'Validation & Acceptance Criteria',
              controller: _validationController,
            ),
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _validationController,
            label: 'Validation and acceptance',
            hintText:
                'One item per line or structured notes covering review and approval criteria.',
            minLines: 6,
            onChanged: (_) => _queueSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsSection(List<String> owners) {
    return _buildGuidedSectionCard(
      sectionId: 'approvals',
      sectionKey: _sectionKeys['approvals']!,
      title: 'Approvals & Governance',
      subtitle:
          'Define reviewer roles, approval state, and governance notes that must remain visible in the design phase.',
      accent: const Color(0xFF7C2D12),
      child: Column(
        children: [
          _SubHeader(
            title: 'Reviewer approvals',
            actionLabel: 'Add reviewer',
            onAction: () {
              setState(() => _document.approvals.add(DesignApprovalEntry()));
              _queueSave();
              _showToast('Reviewer row added.');
            },
          ),
          const SizedBox(height: 12),
          _TextAreaField(
            controller: _governanceController,
            label: 'Governance notes',
            hintText:
                'Review workflow, governance gates, compliance expectations.',
            minLines: 4,
            onChanged: (_) => _queueSave(),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _document.approvals.length; i++) ...[
            _ApprovalCard(
              key: ValueKey(_document.approvals[i].id),
              data: _document.approvals[i],
              owners: owners,
              onChanged: _queueSave,
              onRemove: () {
                setState(() => _document.approvals.removeAt(i));
                _queueSave();
              },
            ),
            if (i != _document.approvals.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkPackagesSection() {
    final data = ProjectDataHelper.getData(context);
    final wbsTree = data.wbsTree;
    final methodology = ProjectDataHelper.resolvedProjectMethodology(data);

    // An agile project is told this section does not apply to it rather than
    // being asked to fill it in (Lusaka 25 (copy) ask 22) — but only while it
    // has no work packages of its own. Blanking a section whose content the
    // project already holds was reported as the error in the walkthrough
    // ("last time it was pulling the work packages … it's saying agile
    // delivery has no design packages"), so content always wins.
    if (workPackagesSectionStartsNotApplicable(
      methodology: methodology.name,
      hasWorkPackageContent: wbsTree.isNotEmpty || data.workPackages.isNotEmpty,
    )) {
      return _buildGuidedSectionCard(
        sectionId: 'work_packages',
        sectionKey: _sectionKeys['work_packages']!,
        title: 'Design Work Packages',
        subtitle: 'Not applicable to agile delivery.',
        accent: const Color(0xFFD97706),
        child: const _EmptyState(
          message: 'Agile delivery has no design work package — the design '
              'lives inside the iteration (epics → features → stories). This '
              'section is marked Not applicable. Untick it below if this '
              'project does need one.',
        ),
      );
    }

    return _buildGuidedSectionCard(
      sectionId: 'work_packages',
      sectionKey: _sectionKeys['work_packages']!,
      title: 'Design Work Packages',
      subtitle:
          'Select WBS items to generate design work package chains (EWP → Procurement → Execution).',
      accent: const Color(0xFFD97706),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (methodology == ProjectMethodology.agile) ...[
            const Text(
              'Agile delivery normally keeps design inside the iteration '
              '(epics → features → stories), so this section is optional '
              'here — your work packages are still shown below. Mark the '
              'section Not applicable above if your project does not need '
              'one.',
              style:
                  TextStyle(fontSize: 12, height: 1.4, color: _kMuted),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Work Breakdown Structure',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
          ),
          const SizedBox(height: 10),
          if (wbsTree.isEmpty)
            const _EmptyState(message: 'No WBS items found.')
          else
            ..._buildWbsTree(wbsTree),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedWbsNodeIds.isEmpty || _generatingPackages
                  ? null
                  : _generateWorkPackages,
              icon: _generatingPackages
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _generatingPackages
                    ? 'Generating...'
                    : 'Create Design Work Packages from Selected',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFFD97706).withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWbsTree(List<WorkItem> items, {int depth = 1}) {
    final widgets = <Widget>[];
    for (final item in items) {
      final isSelected = _selectedWbsNodeIds.contains(item.id);
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: (depth - 1) * 20.0),
          child: Row(
            children: [
              if (depth >= 2)
                Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedWbsNodeIds.add(item.id);
                      } else {
                        _selectedWbsNodeIds.remove(item.id);
                      }
                    });
                  },
                ),
              if (depth < 2)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.folder, size: 18, color: _kMuted),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    item.title.isEmpty ? '(untitled)' : item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          depth <= 1 ? FontWeight.w600 : FontWeight.w400,
                      color: _kText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (item.children.isNotEmpty) {
        widgets.addAll(_buildWbsTree(item.children, depth: depth + 1));
      }
    }
    return widgets;
  }

  Future<void> _generateWorkPackages() async {
    final context_ = context;
    final wbsTree = ProjectDataHelper.getData(context_).wbsTree;

    List<WorkItem> collectSelected(List<WorkItem> items) {
      final result = <WorkItem>[];
      for (final item in items) {
        if (_selectedWbsNodeIds.contains(item.id)) {
          final childSelected = item.children
              .where((c) => _selectedWbsNodeIds.contains(c.id))
              .toList();
          result.add(WorkItem(
            id: item.id,
            parentId: item.parentId,
            title: item.title,
            description: item.description,
            status: item.status,
            framework: item.framework,
            children: childSelected,
            dependencies: List.from(item.dependencies),
            controlAccountId: item.controlAccountId,
            wbsCode: item.wbsCode,
            deliverableDescription: item.deliverableDescription,
            acceptanceCriteria: item.acceptanceCriteria,
            workPackageDefinition: item.workPackageDefinition,
            weight: item.weight,
            cbsId: item.cbsId,
            obsId: item.obsId,
          ));
        } else {
          final filtered = collectSelected(item.children);
          if (filtered.isNotEmpty) {
            result.add(WorkItem(
              id: item.id,
              parentId: item.parentId,
              title: item.title,
              description: item.description,
              status: item.status,
              framework: item.framework,
              children: filtered,
              dependencies: List.from(item.dependencies),
              controlAccountId: item.controlAccountId,
              wbsCode: item.wbsCode,
              deliverableDescription: item.deliverableDescription,
              acceptanceCriteria: item.acceptanceCriteria,
              workPackageDefinition: item.workPackageDefinition,
              weight: item.weight,
              cbsId: item.cbsId,
              obsId: item.obsId,
            ));
          }
        }
      }
      return result;
    }

    final selectedTree = collectSelected(wbsTree);

    if (selectedTree.isEmpty) {
      _showToast('No WBS items selected.');
      return;
    }

    final selectedTitles = <String>[];
    void collectTitles(List<WorkItem> items) {
      for (final item in items) {
        selectedTitles.add(item.title);
        collectTitles(item.children);
      }
    }

    collectTitles(selectedTree);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Design Work Packages'),
        content: Text(
          'Generate work packages for ${selectedTitles.length} selected WBS item(s)?\n\n'
          'Selected: ${selectedTitles.take(5).join(", ")}${selectedTitles.length > 5 ? ', +${selectedTitles.length - 5} more' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _generatingPackages = true);

    try {
      final packages =
          IntegratedWorkPackageService.generatePackageChainsFromWbs(
        wbsTree: selectedTree,
        methodology: 'waterfall',
        designSpecifications: _document.specifications,
      );

      if (!mounted) return;

      var created = 0;
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'design_planning_generate_work_packages',
        dataUpdater: (data) {
          // Identity dedupe: this action appends directly (unlike the other
          // generation screens, which filter by id before saving), so a second
          // run — or a run after the WBS was rebuilt with fresh node ids —
          // would otherwise stack a second copy of every package and, through
          // the planning sync, a second copy of every schedule row.
          final fresh = IntegratedWorkPackageService.dedupePackagesAgainst(
            packages,
            data.workPackages,
          );
          created = fresh.length;
          data.workPackages.addAll(fresh);
          return data;
        },
      );

      if (!mounted) return;
      _showToast(created == packages.length
          ? '$created design work package(s) created.'
          : created == 0
              ? 'All generated packages already exist — nothing added.'
              : '$created created, ${packages.length - created} '
                  'duplicates skipped.');
    } catch (e) {
      if (mounted) {
        _showToast('Failed to generate work packages: $e');
      }
    } finally {
      if (mounted) setState(() => _generatingPackages = false);
    }
  }

  static List<String> _splitLines(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _SectionMeta {
  const _SectionMeta(this.id, this.label, this.accent);

  final String id;
  final String label;
  final Color accent;
}

class _SectionGroupMeta {
  const _SectionGroupMeta(this.title, this.subtitle, this.sectionIds);

  final String title;
  final String subtitle;
  final List<String> sectionIds;
}

const List<_SectionGroupMeta> _sectionGroups = [
  _SectionGroupMeta(
    'Set the design direction',
    'Establish the brief, design inputs, and the basis for your decisions.',
    [
      'overview',
      'design_overview',
      'design_specifications_workspace',
      'deviations'
    ],
  ),
  _SectionGroupMeta(
    'Shape the solution',
    'Translate requirements into a coherent, feasible design.',
    ['requirements', 'architecture', 'uiux', 'technical', 'constraints'],
  ),
  _SectionGroupMeta(
    'Prepare for delivery',
    'Resolve uncertainty, confirm acceptance, and align stakeholders.',
    [
      'risks',
      'dependencies',
      'decisions',
      'validation',
      'approvals',
      'work_packages'
    ],
  ),
];

const List<_SectionMeta> _sectionOrder = [
  _SectionMeta('overview', 'Project Overview', _kPrimary),
  _SectionMeta('design_overview', 'Design Overview', Color(0xFFFFC812)),
  _SectionMeta('design_specifications_workspace', 'Design Specifications',
      Color(0xFF0F766E)),
  _SectionMeta('deviations', 'Deviations', Color(0xFFFFC812)),
  _SectionMeta('requirements', 'Requirements Mapping', Color(0xFF0F9D58)),
  _SectionMeta('architecture', 'Architecture Basis', Color(0xFFB8860B)),
  _SectionMeta('uiux', 'UI/UX Basis', Color(0xFFD97706)),
  _SectionMeta('technical', 'Technical Basis', Color(0xFF0F766E)),
  _SectionMeta('constraints', 'Constraints & Assumptions', Color(0xFFF59E0B)),
  _SectionMeta('risks', 'Risks & Mitigation', Color(0xFFDC2626)),
  _SectionMeta('dependencies', 'Dependencies', Color(0xFFD97706)),
  _SectionMeta('decisions', 'Decision Log', Color(0xFF4F46E5)),
  _SectionMeta('validation', 'Validation', Color(0xFF15803D)),
  _SectionMeta('approvals', 'Approvals', Color(0xFF7C2D12)),
  _SectionMeta('work_packages', 'Work Packages', Color(0xFFD97706)),
];

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.expansionKey,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    required this.expanded,
    required this.enabled,
    this.progressState = _SectionProgressState.pending,
    this.isNextUp = false,
    required this.stepNumber,
    required this.onExpansionChanged,
  });

  final Key? expansionKey;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final bool expanded;
  final bool enabled;
  final _SectionProgressState progressState;

  /// True on the one pending section the user should work through next —
  /// renders a "Next up" affordance so the page always points forward.
  final bool isNextUp;
  final int stepNumber;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final stateColor = switch (progressState) {
      _SectionProgressState.complete => _kSuccess,
      _SectionProgressState.notApplicable => _kWarning,
      _SectionProgressState.pending => _kGray500,
    };
    final statusLabel = switch (progressState) {
      _SectionProgressState.complete => 'Complete',
      _SectionProgressState.notApplicable => 'Not applicable',
      _SectionProgressState.pending => 'Needs review',
    };
    final statusIcon = switch (progressState) {
      _SectionProgressState.complete => Icons.check_circle_rounded,
      _SectionProgressState.notApplicable => Icons.do_not_disturb_on_rounded,
      _SectionProgressState.pending => Icons.circle_outlined,
    };
    final stepBadge = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNextUp
            ? _kBrandYellow.withValues(alpha: 0.22)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: isNextUp ? Border.all(color: _kBrandYellow) : null,
      ),
      child: Text(
        stepNumber.toString().padLeft(2, '0'),
        style: TextStyle(
          color: isNextUp ? _kBrandDark : _kGray700,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final statusBadge = Tooltip(
      message: statusLabel,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 7),
        decoration: BoxDecoration(
          color: stateColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 15, color: stateColor),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: stateColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (expanded) {
      return Container(
        key: expansionKey,
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A111827),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: accent.withValues(alpha: 0.07),
                child: InkWell(
                  onTap: () => onExpansionChanged(false),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Row(
                      children: [
                        stepBadge,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kGray900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        statusBadge,
                        IconButton(
                          tooltip: 'Collapse section',
                          onPressed: () => onExpansionChanged(false),
                          icon: const Icon(Icons.expand_less_rounded),
                          color: _kGray500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kGray500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: expansionKey,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: isNextUp ? const Color(0xFFFFFCF0) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNextUp ? _kBrandYellow : const Color(0xFFE8EBEF),
          width: isNextUp ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onExpansionChanged(true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                stepBadge,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kGray900,
                              ),
                            ),
                          ),
                          if (isNextUp) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kBrandYellow.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NEXT',
                                style: TextStyle(
                                  color: _kBrandDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kGray500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                statusBadge,
                const SizedBox(width: 7),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: _kGray400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) {
      return Column(
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGray500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        VoiceTextField(
          controller: controller,
          onChanged: onChanged,
          decoration: _inputDecoration(hintText),
        ),
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.minLines,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final int minLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGray500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        VoiceTextField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines + 2,
          onChanged: onChanged,
          decoration: _inputDecoration(hintText),
        ),
      ],
    );
  }
}

class _MappingCard extends StatelessWidget {
  const _MappingCard({
    required this.data,
    required this.availableSpecifications,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final DesignRequirementMapping data;
  final List<_SpecificationOption> availableSpecifications;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final specificationOptions = <_SpecificationOption>[
      ...availableSpecifications.where(
        (item) => item.title.trim().isNotEmpty || item.id.trim().isNotEmpty,
      ),
    ];
    final selectedId = specificationOptions.any(
      (item) => item.id == data.requirementId,
    )
        ? data.requirementId
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Mapping Row',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (specificationOptions.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: _inputDecoration('Select specification item'),
              items: specificationOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) {
                return specificationOptions
                    .map(
                      (item) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList();
              },
              onChanged: (value) {
                if (value == null) return;
                final selected = specificationOptions.firstWhere(
                  (item) => item.id == value,
                  orElse: () => _SpecificationOption(id: value, title: ''),
                );
                data.requirementId = selected.id;
                data.requirementText =
                    selected.title.isEmpty ? selected.details : selected.title;
                if (selected.details.isNotEmpty) {
                  data.designResponse = selected.details;
                }
                final mappedArea = selected.area.isNotEmpty
                    ? selected.area
                    : selected.discipline;
                if (mappedArea.isNotEmpty) {
                  data.designArea = mappedArea;
                }
                if (selected.owner.isNotEmpty) {
                  data.owner = selected.owner;
                }
                if (selected.referenceLink.isNotEmpty) {
                  data.linkedArtifact = selected.referenceLink;
                  data.verificationMethod = selected.referenceLink;
                }
                onChanged();
              },
            ),
          if (specificationOptions.isNotEmpty) const SizedBox(height: 12),
          VoiceTextFormField(
            initialValue: data.requirementText,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration('Specification item'),
            onChanged: (value) {
              data.requirementText = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          VoiceTextFormField(
            initialValue: data.designResponse,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration('Details'),
            onChanged: (value) {
              data.designResponse = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _FourColumnGrid(
            children: [
              _TextFormField(
                initialValue: data.designArea,
                label: 'Design area',
                suggestions: _DesignPlanningScreenState._designAreaOptions,
                onChanged: (value) {
                  data.designArea = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.owner,
                label: 'Owner',
                options: owners,
                onChanged: (value) {
                  data.owner = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.status,
                label: 'Status',
                options: _DesignPlanningScreenState._mappingStatusOptions,
                onChanged: (value) {
                  data.status = value;
                  onChanged();
                },
              ),
              _TextFormField(
                initialValue: data.linkedArtifact,
                label: 'Linked artifacts',
                onChanged: (value) {
                  data.linkedArtifact = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.acceptanceCriteria,
              label: 'Acceptance criteria',
              maxLines: 3,
              onChanged: (value) {
                data.acceptanceCriteria = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.verificationMethod,
              label: 'Verification method',
              maxLines: 3,
              onChanged: (value) {
                data.verificationMethod = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Table / Cards switch for the Design Specifications rows.
class _SpecViewToggle extends StatelessWidget {
  const _SpecViewToggle({required this.mode, required this.onChanged});

  final _SpecViewMode mode;
  final ValueChanged<_SpecViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_SpecViewMode>(
      segments: const [
        ButtonSegment(
          value: _SpecViewMode.table,
          label: Text('Table'),
          icon: Icon(Icons.table_chart_outlined, size: 16),
        ),
        ButtonSegment(
          value: _SpecViewMode.cards,
          label: Text('Cards'),
          icon: Icon(Icons.view_agenda_outlined, size: 16),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Read-only table of the Design Specifications rows, shown as the default view.
///
/// Reading only on purpose: a table cell is a poor place to write a
/// specification's details, so editing stays on the cards — [onOpenCards] takes
/// the user there.
class _SpecificationsInlineTable extends StatelessWidget {
  const _SpecificationsInlineTable({
    required this.rows,
    required this.onOpenCards,
  });

  final List<_SpecificationOption> rows;
  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF99F6E4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${rows.length} specification row'
                  '${rows.length == 1 ? '' : 's'}. Edit a row on the Cards view, '
                  'or export the rows, change them in a spreadsheet, and import '
                  'them back.',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF115E59)),
                ),
              ),
              TextButton(
                onPressed: onOpenCards,
                child: const Text('Edit as cards'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 64,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Spec type')),
              DataColumn(label: Text('Discipline')),
              DataColumn(label: Text('Area')),
              DataColumn(label: Text('WBS Work Package')),
              DataColumn(label: Text('Source type')),
              DataColumn(label: Text('Owner')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (var i = 0; i < rows.length; i++)
                DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(SizedBox(
                    width: 220,
                    child: Text(
                      rows[i].title.isEmpty ? 'Untitled' : rows[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  DataCell(Text(rows[i].specificationType)),
                  DataCell(Text(rows[i].discipline)),
                  DataCell(Text(rows[i].area)),
                  DataCell(SizedBox(
                    width: 170,
                    child: Text(
                      rows[i].wbsWorkPackageTitle.isEmpty
                          ? '—'
                          : rows[i].wbsWorkPackageTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  DataCell(Text(rows[i].sourceType)),
                  DataCell(Text(rows[i].owner)),
                  DataCell(Text(rows[i].status)),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain-language note above the Architecture Basis module rows, so the
/// numbered cards mean something before they are read (Lusaka 25 (copy):
/// "model 1, 2, 3 … it is not intelligible").
class _ArchitectureModuleExplainer extends StatelessWidget {
  const _ArchitectureModuleExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              architectureModuleExplainer,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF7C2D12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only table view of the architecture modules, shown in a pop-out so the
/// rows can be scanned together.
class _ArchitectureModulesTable extends StatelessWidget {
  const _ArchitectureModulesTable({required this.modules});

  final List<DesignPlanningWorkItem> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const Text(
        'No modules yet. Add one from the Architecture Basis section.',
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 72,
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Module')),
          DataColumn(label: Text('Purpose')),
          DataColumn(label: Text('Owner')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (var i = 0; i < modules.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(
                modules[i].name.trim().isEmpty
                    ? 'Unnamed'
                    : modules[i].name.trim(),
              )),
              DataCell(SizedBox(
                width: 300,
                child: Text(
                  modules[i].purpose.trim().isEmpty
                      ? '—'
                      : modules[i].purpose.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              )),
              DataCell(Text(
                modules[i].owner.trim().isEmpty
                    ? 'Unassigned'
                    : modules[i].owner.trim(),
              )),
              DataCell(Text(modules[i].status)),
            ]),
        ],
      ),
    );
  }
}

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.title,
    required this.data,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final String title;
  final DesignPlanningWorkItem data;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.name,
              label: 'Name',
              onChanged: (value) {
                data.name = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.purpose,
              label: 'Purpose / notes',
              maxLines: 3,
              onChanged: (value) {
                data.purpose = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _DropdownField(
              value: data.owner,
              label: 'Owner',
              options: owners,
              onChanged: (value) {
                data.owner = value;
                onChanged();
              },
            ),
            right: _DropdownField(
              value: data.status,
              label: 'Status',
              options: _DesignPlanningScreenState._workStatusOptions,
              onChanged: (value) {
                data.status = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecificationPlanRowCard extends StatelessWidget {
  const _SpecificationPlanRowCard({
    super.key,
    required this.index,
    required this.data,
    required this.owners,
    required this.requirementOptions,
    required this.specificationTypeOptions,
    required this.disciplineOptions,
    required this.areaOptions,
    required this.wbsWorkPackages,
    required this.sourceTypeOptions,
    required this.ruleTypeOptions,
    required this.statusOptions,
    required this.uploadsEnabled,
    required this.onChanged,
    required this.onUpload,
    required this.onRemove,
  });

  final int index;
  final DesignSpecificationPlanRow data;
  final List<String> owners;
  final List<_RequirementAttachmentOption> requirementOptions;
  final List<String> specificationTypeOptions;
  final List<String> disciplineOptions;
  final List<String> areaOptions;
  final List<_WbsWorkPackageOption> wbsWorkPackages;
  final List<String> sourceTypeOptions;
  final List<String> ruleTypeOptions;
  final List<String> statusOptions;
  final bool uploadsEnabled;
  final VoidCallback onChanged;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final wbsPackageLabels = wbsWorkPackages
        .map((item) => item.displayLabel)
        .toList(growable: false);
    String selectedWbsPackageLabel = '';
    if (data.wbsWorkPackageTitle.trim().isNotEmpty) {
      for (final item in wbsWorkPackages) {
        if (item.displayLabel == data.wbsWorkPackageTitle.trim()) {
          selectedWbsPackageLabel = item.displayLabel;
          break;
        }
      }
    }
    if (selectedWbsPackageLabel.isEmpty) {
      for (final item in wbsWorkPackages) {
        if (item.id == data.wbsWorkPackageId) {
          selectedWbsPackageLabel = item.displayLabel;
          break;
        }
      }
    }
    if (selectedWbsPackageLabel.isEmpty &&
        data.wbsWorkPackageTitle.trim().isNotEmpty) {
      selectedWbsPackageLabel = data.wbsWorkPackageTitle.trim();
    }
    final wbsValue = selectedWbsPackageLabel.isEmpty
        ? 'Not mapped'
        : selectedWbsPackageLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Spec Row $index',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (uploadsEnabled)
                TextButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload'),
                ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.title,
              label: 'Title',
              onChanged: (value) {
                data.title = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.referenceLink,
              label: 'Reference link',
              onChanged: (value) {
                data.referenceLink = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _TextFormField(
            initialValue: data.details,
            label: 'Details',
            maxLines: 3,
            onChanged: (value) {
              data.details = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _RequirementMultiSelectField(
            label: 'Attached requirements',
            options: requirementOptions,
            selectedIds: data.attachedRequirementIds,
            onChanged: (ids) {
              data.attachedRequirementIds = ids;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _FourColumnGrid(
            children: [
              _DropdownField(
                value: data.specificationType,
                label: 'Specification type',
                options: specificationTypeOptions,
                onChanged: (value) {
                  data.specificationType = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.ruleType,
                label: 'Source',
                options: ruleTypeOptions,
                onChanged: (value) {
                  data.ruleType = value;
                  onChanged();
                },
              ),
              _FilterableCreatableDropdownField(
                value: data.discipline,
                label: 'Discipline',
                options: disciplineOptions,
                onChanged: (value) {
                  data.discipline = value.trim();
                  onChanged();
                },
              ),
              _FilterableCreatableDropdownField(
                value: data.area,
                label: 'Area',
                options: areaOptions,
                onChanged: (value) {
                  data.area = value.trim();
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.sourceType,
                label: 'Source type',
                options: sourceTypeOptions,
                onChanged: (value) {
                  data.sourceType = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.owner,
                label: 'Owner',
                options: owners,
                onChanged: (value) {
                  data.owner = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.status,
                label: 'Status',
                options: statusOptions,
                onChanged: (value) {
                  data.status = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DropdownField(
            value: wbsValue,
            label: 'WBS work package',
            options: ['Not mapped', ...wbsPackageLabels],
            onChanged: (value) {
              if (value.trim() == 'Not mapped') {
                data.wbsWorkPackageId = '';
                data.wbsWorkPackageTitle = '';
                onChanged();
                return;
              }
              _WbsWorkPackageOption? selected;
              for (final item in wbsWorkPackages) {
                if (item.displayLabel == value) {
                  selected = item;
                  break;
                }
              }
              if (selected == null || value.trim().isEmpty) {
                data.wbsWorkPackageId = '';
                data.wbsWorkPackageTitle = '';
                onChanged();
                return;
              }
              data.wbsWorkPackageId = selected.id;
              data.wbsWorkPackageTitle = selected.displayLabel;
              if (data.discipline.trim().isEmpty &&
                  selected.disciplineSeed.trim().isNotEmpty) {
                data.discipline = selected.disciplineSeed.trim();
              }
              if (data.area.trim().isEmpty &&
                  selected.areaSeed.trim().isNotEmpty) {
                data.area = selected.areaSeed.trim();
              }
              onChanged();
            },
          ),
          if (data.uploadedFileName.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Uploaded file: ${data.uploadedFileName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecificationDeviationCard extends StatelessWidget {
  const _SpecificationDeviationCard({
    super.key,
    required this.index,
    required this.data,
    required this.specificationOptions,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final DesignSpecificationDeviation data;
  final List<_SpecificationOption> specificationOptions;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedId = specificationOptions.any(
      (item) => item.id == data.specificationId,
    )
        ? data.specificationId
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Deviation $index',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (specificationOptions.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: _inputDecoration('Select specification item'),
              items: specificationOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                data.specificationId = value;
                onChanged();
              },
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add specification rows before selecting a specification item.',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
            ),
          const SizedBox(height: 12),
          VoiceTextFormField(
            initialValue: data.description,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration('Deviation description'),
            onChanged: (value) {
              data.description = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _SpecificationDocumentCard extends StatelessWidget {
  const _SpecificationDocumentCard({
    super.key,
    required this.index,
    required this.data,
    required this.requirementOptions,
    required this.sourceTypeOptions,
    required this.uploadsEnabled,
    required this.onChanged,
    required this.onUpload,
    required this.onRemove,
  });

  final int index;
  final DesignPlanningReferenceDoc data;
  final List<_RequirementAttachmentOption> requirementOptions;
  final List<String> sourceTypeOptions;
  final bool uploadsEnabled;
  final VoidCallback onChanged;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Document $index',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (uploadsEnabled)
                TextButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload'),
                ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.title,
              label: 'Title',
              onChanged: (value) {
                data.title = value;
                onChanged();
              },
            ),
            right: _DropdownField(
              value: data.category,
              label: 'Category',
              options: sourceTypeOptions,
              onChanged: (value) {
                data.category = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _RequirementMultiSelectField(
            label: 'Attached requirements',
            options: requirementOptions,
            selectedIds: data.attachedRequirementIds,
            onChanged: (ids) {
              data.attachedRequirementIds = ids;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.link,
              label: 'Link',
              onChanged: (value) {
                data.link = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.notes,
              label: 'Notes',
              maxLines: 2,
              onChanged: (value) {
                data.notes = value;
                onChanged();
              },
            ),
          ),
          if (data.fileName.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Uploaded file: ${data.fileName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.data,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final DesignRiskEntry data;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Risk', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _TextFormField(
            initialValue: data.risk,
            label: 'Risk',
            onChanged: (value) {
              data.risk = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _FourColumnGrid(
            children: [
              _TextFormField(
                initialValue: data.impact,
                label: 'Impact',
                onChanged: (value) {
                  data.impact = value;
                  onChanged();
                },
              ),
              _TextFormField(
                initialValue: data.likelihood,
                label: 'Likelihood',
                onChanged: (value) {
                  data.likelihood = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.owner,
                label: 'Owner',
                options: owners,
                onChanged: (value) {
                  data.owner = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.status,
                label: 'Status',
                options: _DesignPlanningScreenState._riskStatusOptions,
                onChanged: (value) {
                  data.status = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TextFormField(
            initialValue: data.mitigation,
            label: 'Mitigation',
            maxLines: 3,
            onChanged: (value) {
              data.mitigation = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _DependencyCard extends StatelessWidget {
  const _DependencyCard({
    required this.data,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final DesignDependencyEntry data;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Dependency',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.name,
              label: 'Dependency',
              onChanged: (value) {
                data.name = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.source,
              label: 'Source',
              onChanged: (value) {
                data.source = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _FourColumnGrid(
            children: [
              _DropdownField(
                value: data.type,
                label: 'Type',
                options: _DesignPlanningScreenState._dependencyTypeOptions,
                onChanged: (value) {
                  data.type = value;
                  onChanged();
                },
              ),
              _TextFormField(
                initialValue: data.neededBy,
                label: 'Needed by',
                onChanged: (value) {
                  data.neededBy = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.owner,
                label: 'Owner',
                options: owners,
                onChanged: (value) {
                  data.owner = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.status,
                label: 'Status',
                options: _DesignPlanningScreenState._workStatusOptions,
                onChanged: (value) {
                  data.status = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TextFormField(
            initialValue: data.notes,
            label: 'Notes',
            maxLines: 3,
            onChanged: (value) {
              data.notes = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.data,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final DesignDecisionEntry data;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Decision',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _TextFormField(
            initialValue: data.decision,
            label: 'Decision',
            onChanged: (value) {
              data.decision = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _TextFormField(
              initialValue: data.rationale,
              label: 'Rationale',
              maxLines: 3,
              onChanged: (value) {
                data.rationale = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.alternatives,
              label: 'Alternatives considered',
              maxLines: 3,
              onChanged: (value) {
                data.alternatives = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _FourColumnGrid(
            children: [
              _DropdownField(
                value: data.owner,
                label: 'Owner',
                options: owners,
                onChanged: (value) {
                  data.owner = value;
                  onChanged();
                },
              ),
              _TextFormField(
                initialValue: data.date,
                label: 'Date',
                onChanged: (value) {
                  data.date = value;
                  onChanged();
                },
              ),
              _DropdownField(
                value: data.status,
                label: 'Status',
                options: _DesignPlanningScreenState._mappingStatusOptions,
                onChanged: (value) {
                  data.status = value;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    super.key,
    required this.data,
    required this.owners,
    required this.onChanged,
    required this.onRemove,
  });

  final DesignApprovalEntry data;
  final List<String> owners;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Reviewer',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          _ResponsivePair(
            left: _DropdownField(
              value: data.reviewer,
              label: 'Reviewer',
              options: owners,
              onChanged: (value) {
                data.reviewer = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.role,
              label: 'Role',
              onChanged: (value) {
                data.role = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            left: _DropdownField(
              value: data.status,
              label: 'Status',
              options: _DesignPlanningScreenState._approvalStatusOptions,
              onChanged: (value) {
                data.status = value;
                onChanged();
              },
            ),
            right: _TextFormField(
              initialValue: data.comment,
              label: 'Comments',
              maxLines: 3,
              onChanged: (value) {
                data.comment = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final String label;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim();
    final items =
        options.toSet().where((item) => item.trim().isNotEmpty).toList();
    if (normalized.isNotEmpty && !items.contains(normalized)) {
      items.insert(0, normalized);
    }
    if (items.isEmpty) {
      items.add('Select');
    }
    final selected = items.contains(normalized) ? normalized : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: _inputDecoration(''),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          selectedItemBuilder: (context) {
            return items
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList();
          },
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
      ],
    );
  }
}

class _FilterableCreatableDropdownField extends StatefulWidget {
  const _FilterableCreatableDropdownField({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final String label;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  State<_FilterableCreatableDropdownField> createState() =>
      _FilterableCreatableDropdownFieldState();
}

class _FilterableCreatableDropdownFieldState
    extends State<_FilterableCreatableDropdownField> {
  static const _createTokenPrefix = '__create__:';

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = SpellCheckTextEditingController(text: widget.value.trim());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _FilterableCreatableDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final next = widget.value.trim();
      if (_controller.text.trim() != next) {
        _controller.text = next;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _normalizedOptions() {
    final deduped = <String>[];
    final seen = <String>{};
    for (final option in widget.options) {
      final normalized = option.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      deduped.add(normalized);
    }
    return deduped;
  }

  Iterable<String> _buildOptions(String query) {
    final trimmed = query.trim();
    final all = _normalizedOptions();
    if (trimmed.isEmpty) return all;

    final needle = trimmed.toLowerCase();
    final matches = all
        .where((option) => option.toLowerCase().contains(needle))
        .toList(growable: false);
    if (matches.isNotEmpty) return matches;
    return ['$_createTokenPrefix$trimmed'];
  }

  String _displayLabel(String option) {
    if (option.startsWith(_createTokenPrefix)) {
      final custom = option.substring(_createTokenPrefix.length);
      return 'Create "$custom"';
    }
    return option;
  }

  String _resolvedValue(String option) {
    if (!option.startsWith(_createTokenPrefix)) return option;
    return option.substring(_createTokenPrefix.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (textEditingValue) {
            return _buildOptions(textEditingValue.text);
          },
          displayStringForOption: _displayLabel,
          onSelected: (selected) {
            final value = _resolvedValue(selected).trim();
            _controller.text = value;
            widget.onChanged(value);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return VoiceTextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: _inputDecoration(
                'Type to filter options. If no match, create custom.',
              ),
              onFieldSubmitted: (raw) {
                final value = raw.trim();
                if (value.isEmpty) return;
                widget.onChanged(value);
                onSubmitted();
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final list = options.toList(growable: false);
            if (list.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: _kSurface,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    minWidth: 260,
                    maxWidth: 440,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _kBorder),
                    itemBuilder: (context, index) {
                      final option = list[index];
                      final isCreate = option.startsWith(_createTokenPrefix);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCreate ? Icons.add_circle : Icons.list_alt,
                                size: 16,
                                color: isCreate ? _kPrimary : _kMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _displayLabel(option),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isCreate ? _kPrimary : _kText,
                                    fontWeight: isCreate
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RequirementAttachmentOption {
  const _RequirementAttachmentOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _SpecificationOption {
  const _SpecificationOption({
    required this.id,
    required this.title,
    this.details = '',
    this.specificationType = '',
    this.discipline = '',
    this.area = '',
    this.sourceType = '',
    this.owner = '',
    this.status = '',
    this.referenceLink = '',
    this.wbsWorkPackageId = '',
    this.wbsWorkPackageTitle = '',
  });

  final String id;
  final String title;
  final String details;
  final String specificationType;
  final String discipline;
  final String area;
  final String sourceType;
  final String owner;
  final String status;
  final String referenceLink;
  final String wbsWorkPackageId;
  final String wbsWorkPackageTitle;
}

class _WbsWorkPackageOption {
  const _WbsWorkPackageOption({
    required this.id,
    required this.title,
    required this.parentTitle,
    required this.level,
    required this.disciplineSeed,
    required this.areaSeed,
  });

  final String id;
  final String title;
  final String parentTitle;
  final int level;
  final String disciplineSeed;
  final String areaSeed;

  String get displayLabel {
    if (parentTitle.trim().isEmpty) return title;
    return '$parentTitle > $title';
  }
}

class _RequirementMultiSelectField extends StatefulWidget {
  const _RequirementMultiSelectField({
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });

  final String label;
  final List<_RequirementAttachmentOption> options;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_RequirementMultiSelectField> createState() =>
      _RequirementMultiSelectFieldState();
}

class _RequirementMultiSelectFieldState
    extends State<_RequirementMultiSelectField> {
  late List<String> _localSelection;

  @override
  void initState() {
    super.initState();
    _localSelection = List.of(widget.selectedIds);
  }

  @override
  void didUpdateWidget(_RequirementMultiSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localSelection = List.of(widget.selectedIds);
  }

  Future<void> _openSelector() async {
    final selected = {..._localSelection};
    final searchController = SpellCheckTextEditingController();
    String query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = widget.options.where((option) {
              return option.label.toLowerCase().contains(query.toLowerCase());
            }).toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            selected.clear();
                            setModalState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    VoiceTextField(
                      controller: searchController,
                      decoration: _inputDecoration(
                        'Filter requirements by text',
                      ),
                      onChanged: (value) {
                        setModalState(() => query = value.trim());
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No matching requirements.',
                                style: TextStyle(color: _kMuted),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final checked = selected.contains(option.id);
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: checked,
                                  title: Text(
                                    option.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        selected.add(option.id);
                                      } else {
                                        selected.remove(option.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final newSelection = selected.toList(growable: false);
                          widget.onChanged(newSelection);
                          setState(() => _localSelection = newSelection);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply selection'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelsById = {
      for (final option in widget.options) option.id: option.label,
    };
    final selectedLabels = _localSelection
        .where((id) => id.trim().isNotEmpty)
        .map((id) => labelsById[id] ?? 'Requirement (unavailable)')
        .toList(growable: false);
    final summary =
        selectedLabels.isEmpty ? 'None' : '${selectedLabels.length} selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: widget.options.isEmpty ? null : _openSelector,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _inputDecoration(
              widget.options.isEmpty ? 'No requirements available' : '',
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: const TextStyle(color: _kText),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kMuted,
                ),
              ],
            ),
          ),
        ),
        if (selectedLabels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedLabels
                .take(6)
                .map(
                  (label) => Chip(
                    label: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _TextFormField extends StatelessWidget {
  const _TextFormField({
    required this.initialValue,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
    this.suggestions = const [],
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        VoiceTextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          decoration: _inputDecoration(
              suggestions.isEmpty ? '' : suggestions.join(', ')),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FourColumnGrid extends StatelessWidget {
  const _FourColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final isTablet = AppBreakpoints.isTablet(context);
    final preferredColumns = isMobile ? 1 : (isTablet ? 2 : 4);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        var columns = preferredColumns;
        var available = maxWidth - (spacing * (columns - 1));
        while (columns > 1 && available <= 0) {
          columns -= 1;
          available = maxWidth - (spacing * (columns - 1));
        }
        final width = columns == 1
            ? maxWidth
            : (available <= 0 ? maxWidth : available / columns);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(
                  width: width.clamp(0, double.infinity), child: child))
              .toList(),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kText,
        side: const BorderSide(color: _kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Lightweight state object for the auto-save indicator, used with
/// [ValueNotifier] so that save-status updates do NOT trigger a full
/// `setState` rebuild of the entire page.
class _SaveIndicatorState {
  const _SaveIndicatorState({
    required this.saving,
    required this.pending,
    required this.lastSavedAt,
  });
  final bool saving;
  final bool pending;
  final DateTime? lastSavedAt;
}

class _AutoSaveIndicator extends StatelessWidget {
  const _AutoSaveIndicator({
    required this.saving,
    required this.pending,
    required this.lastSavedAt,
  });

  final bool saving;
  final bool pending;
  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    late final IconData icon;
    if (saving) {
      label = 'Auto-save: saving...';
      color = const Color(0xFF0F62FE);
      icon = Icons.sync;
    } else if (pending) {
      label = 'Auto-save: unsaved changes';
      color = const Color(0xFFB45309);
      icon = Icons.schedule;
    } else if (lastSavedAt != null) {
      label =
          'Auto-save: saved ${TimeOfDay.fromDateTime(lastSavedAt!).format(context)}';
      color = const Color(0xFF15803D);
      icon = Icons.check_circle_outline;
    } else {
      label = 'Auto-save: waiting for first change';
      color = _kGray500;
      icon = Icons.info_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AssistActions extends StatelessWidget {
  const _AssistActions({
    required this.onAutofill,
    required this.onGenerate,
    required this.generating,
  });

  final VoidCallback onAutofill;
  final VoidCallback onGenerate;
  final bool generating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onAutofill,
          icon: const Icon(Icons.bolt, size: 16),
          label: const Text('Autofill From Context'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kGray700,
            side: const BorderSide(color: _kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: generating ? null : onGenerate,
          icon: generating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kBrandYellow),
                )
              : const Icon(Icons.star, size: 16, color: _kBrandYellow),
          label: Text(generating ? 'Generating...' : 'Generate With AI'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGray900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: generating ? null : onGenerate,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Regenerate'),
          style: TextButton.styleFrom(
            foregroundColor: _kGray500,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const Spacer(),
        _InlineAddButton(label: actionLabel, onPressed: onAction),
      ],
    );
  }
}

class _InlineAddButton extends StatelessWidget {
  const _InlineAddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: _kMuted, height: 1.45),
      ),
    );
  }
}

class _UploadedDoc {
  const _UploadedDoc({
    required this.name,
    required this.url,
    required this.storagePath,
  });

  final String name;
  final String url;
  final String storagePath;
}

InputDecoration _inputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText.isEmpty ? null : hintText,
    filled: true,
    fillColor: const Color(0xFFF9FAFB).withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: _kBrandYellow, width: 1.5),
    ),
  );
}
