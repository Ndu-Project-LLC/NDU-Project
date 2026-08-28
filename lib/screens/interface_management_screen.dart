import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/delete_success_snackbar.dart';
// ─── Tab definitions ────────────────────────────────────────────────────────

enum _ImTab {
  register('Interface Register'),
  architecture('Architecture'),
  raci('RACI & Governance'),
  risks('Risks & Decisions'),
  dependencies('Dependencies'),
  handoff('Handoff Readiness'),
  maturity('Maturity'),
  dashboard('Status Dashboard'),
  audit('Audit Trail');

  const _ImTab(this.label);
  final String label;
}

// ─── Constants ──────────────────────────────────────────────────────────────

const _kInterfaceTypes = [
  'Technical',
  'Contractual',
  'Organizational',
  'Physical',
  'Procedural',
];

const _kInterfaceClassifications = ['Internal', 'External'];
const _kDependencyTypes = [
  'Deliverable',
  'Schedule',
  'Resource',
  'Procurement',
  'Technical',
];
const _kPriorities = ['High', 'Medium', 'Low'];
const _kCriticalities = ['Critical', 'Major', 'Minor'];
const _kDataFlows = ['Bidirectional', 'A to B', 'B to A'];
const _kProtocols = ['API', 'File Transfer', 'Manual', 'Email', 'Shared DB'];
const _kStatuses = [
  'Active',
  'Pending',
  'Under Review',
  'Approved',
  'Closed',
  'Resolved',
];
const _kCadences = [
  'Daily',
  'Weekly',
  'Bi-weekly',
  'Monthly',
  'Quarterly',
  'As Needed',
];

// ─── Main Screen ────────────────────────────────────────────────────────────

class InterfaceManagementScreen extends StatefulWidget {
  const InterfaceManagementScreen({super.key});

  static void open(BuildContext context) {
    context.push('/interface-management');
  }

  @override
  State<InterfaceManagementScreen> createState() =>
      _InterfaceManagementScreenState();
}

class _InterfaceManagementScreenState extends State<InterfaceManagementScreen> {
  _ImTab _selectedTab = _ImTab.register;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    // Per Task 14: extend content to the full screen width. We no longer
    // reserve 104px on the right for the floating KAZ AI bubble — the
    // bubble sits above the content with a shadow and is non-blocking,
    // so content can flow underneath it. Horizontal padding is kept
    // symmetric for visual balance.
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final bottomPadding = isMobile ? 24.0 : 120.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Interface Management'),
            ),
            Expanded(
              child: Column(
                children: [
                  // ── Unified page header (matches other planning screens) ──
                  PlanningPhaseHeader(
                    title: 'Interface Management Plan',
                    breadcrumbPhase: 'Planning Phase',
                    breadcrumbTitle: 'Interface Management Plan',
                    onBack: () => PlanningPhaseNavigation.goToPrevious(
                        context, 'interface_management'),
                    onForward: () => PlanningPhaseNavigation.goToNext(
                        context, 'interface_management'),
                    onExportPdf: _exportPdf,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        const MobileSidebarHamburger(
                          sidebar: InitiationLikeSidebar(
                            activeItemLabel: 'Interface Management',
                          ),
                        ),
                        SingleChildScrollView(
                          padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: horizontalPadding,
                              top: 24,
                              bottom: bottomPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              // ── Page title + description (header section) ──
                              Text(
                                'Interface Management Plan',
                                style: TextStyle(
                                  fontSize: isMobile ? 22 : 26,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Define how project interfaces will be identified, coordinated, and managed to ensure effective integration across stakeholders, organizations, systems, disciplines, and deliverables.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4B5563),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const PlanningAiNotesCard(
                                title: 'Notes',
                                sectionLabel: 'Interface Management',
                                noteKey: 'planning_interface_management_notes',
                                checkpoint: 'interface_management',
                                description:
                                    'Summarize interface ownership, dependency risks, and governance cadence.',
                              ),
                              const SizedBox(height: 24),
                              const InterfacePlanCard(),
                              const SizedBox(height: 24),
                              _buildMetricsRow(),
                              const SizedBox(height: 24),
                              _buildTabBar(),
                              const SizedBox(height: 16),
                              _buildTabContent(),
                              const SizedBox(height: 24),
                              LaunchPhaseNavigation(
                                backLabel: PlanningPhaseNavigation.backLabel(
                                    'interface_management'),
                                nextLabel: PlanningPhaseNavigation.nextLabel(
                                    'interface_management'),
                                onBack: () =>
                                    PlanningPhaseNavigation.goToPrevious(
                                        context, 'interface_management'),
                                onNext: () => PlanningPhaseNavigation.goToNext(
                                    context, 'interface_management'),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                        const Positioned(
                            right: 24,
                            bottom: 24,
                            child: KazAiChatBubble(positioned: false)),
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
  }

  // ── Metrics ────────────────────────────────────────────────────────────

  Widget _buildMetricsRow() {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;
    final extIntegrations = data.externalIntegrations;

    final activeInterfaces = entries.length;
    final criticalCount = entries
        .where((e) =>
            e.criticality.toLowerCase() == 'critical' ||
            _isCriticalRisk(e.risk))
        .length;
    final ownerCount = entries
        .map((e) => e.owner.trim())
        .where((o) => o.isNotEmpty)
        .toSet()
        .length;
    final openCount = entries.where((e) => _isOpenStatus(e.status)).length;
    final techLinkCount = extIntegrations.length;

    final cards = <_MetricCard>[
      _MetricCard(
          label: 'Total Interfaces',
          value: '$activeInterfaces',
          accent: const Color(0xFFFFC812)),
      _MetricCard(
          label: 'Critical',
          value: '$criticalCount',
          accent: const Color(0xFFEF4444)),
      _MetricCard(
          label: 'Owners',
          value: '$ownerCount',
          accent: const Color(0xFF10B981)),
      _MetricCard(
          label: 'Open Issues',
          value: '$openCount',
          accent: const Color(0xFFF59E0B)),
      _MetricCard(
          label: 'Tech Integrations',
          value: '$techLinkCount',
          accent: const Color(0xFFB8860B),
          tooltip: 'From Technology Planning'),
      _MetricCard(
          label: 'At Risk',
          value:
              '${entries.where((e) => _calculateHealth(e) == 'red').length}',
          accent: const Color(0xFFEF4444),
          tooltip: 'Critical + open status or blocker risk'),
      _MetricCard(
          label: 'Healthy',
          value:
              '${entries.where((e) => _calculateHealth(e) == 'green').length}',
          accent: const Color(0xFF10B981),
          tooltip: 'Approved/resolved/closed'),
    ];

    // On wide screens, lay the metric cards out in a single Row with each
    // card Expanded to fill equal shares of the available width — eliminating
    // the right-side whitespace the previous Wrap left on desktop. On narrow
    // viewports, fall back to Wrap so cards reflow to multiple rows.
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardMinWidth = 160.0;
        const gap = 12.0;
        // How many cards can fit on one row at min width?
        final perRow = ((constraints.maxWidth + gap) / (cardMinWidth + gap))
            .floor()
            .clamp(1, cards.length);
        final wouldAllFit = perRow >= cards.length;
        if (wouldAllFit) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((c) => SizedBox(width: cardMinWidth, child: c))
              .toList(),
        );
      },
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4B422),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: _ImTab.values.map((tab) {
          final selected = tab == _selectedTab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = tab),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF111827) : Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedTab.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (_selectedTab == _ImTab.register)
                ElevatedButton.icon(
                  onPressed: () =>
                      _InterfaceRegisterSection.showAddDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Interface'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          switch (_selectedTab) {
            _ImTab.register => const _InterfaceRegisterSection(),
            _ImTab.architecture => const _ArchitectureSection(),
            _ImTab.raci => const _RaciGovernanceSection(),
            _ImTab.risks => const _RisksDecisionsSection(),
            _ImTab.dependencies => const _DependencyManagementSection(),
            _ImTab.handoff => const _HandoffReadinessSection(),
            _ImTab.maturity => const _MaturitySection(),
            _ImTab.dashboard => const _InterfaceStatusDashboardSection(),
            _ImTab.audit => const _AuditTrailSection(),
          },
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Interface Management Plan',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_interface_management_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

// ─── Top Header ──────────────────────────────────────────────────────────────

class InterfacePlanCard extends StatefulWidget {
  const InterfacePlanCard({super.key});

  @override
  State<InterfacePlanCard> createState() => _InterfacePlanCardState();
}

class _InterfacePlanCardState extends State<InterfacePlanCard> {
  static const String _noteKey = 'planning_interface_management_plan';
  Timer? _saveDebounce;
  DateTime? _lastSavedAt;
  late String _initialText;

  @override
  void initState() {
    super.initState();
    _initialText =
        ProjectDataHelper.getData(context).planningNotes[_noteKey] ?? '';
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _handleChanged(String value) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () async {
      final trimmed = value.trim();
      final success = await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'interface_management',
        dataUpdater: (data) => data.copyWith(
          planningNotes: {
            ...data.planningNotes,
            _noteKey: trimmed,
          },
        ),
        showSnackbar: false,
      );
      if (!mounted) return;
      if (success) {
        setState(() => _lastSavedAt = DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Interface Management Plan',
      subtitle:
          'Describe ownership, cadence, and risk handling so teams coordinate before handoffs.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiSuggestingTextField(
            fieldLabel: 'Interface Plan',
            hintText:
                'Outline the governance rhythm, ownership, and risk mitigations for key interfaces.',
            sectionLabel: 'Interface Management',
            showLabel: false,
            autoGenerate: true,
            autoGenerateSection: 'Interface Management Plan',
            initialText: _initialText,
            onChanged: _handleChanged,
          ),
          if (_lastSavedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Metric Card ─────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color accent;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: accent),
          ),
        ],
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: Interface Register
// ═══════════════════════════════════════════════════════════════════════════════

class _InterfaceRegisterSection extends StatefulWidget {
  const _InterfaceRegisterSection();

  static void showAddDialog(BuildContext context) {
    final data = ProjectDataHelper.getData(context);
    final entries = List<InterfaceEntry>.from(data.interfaceEntries);
    final extIntegrations = data.externalIntegrations;

    // Suggest names from Technology Planning external integrations
    final suggestedNames = extIntegrations
        .map((e) => e['name']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .where((n) => !entries.any(
            (entry) => entry.boundary.trim().toLowerCase() == n.toLowerCase()))
        .toList();

    _InterfaceEntryDialog.show(context, null, suggestedNames);
  }

  @override
  State<_InterfaceRegisterSection> createState() =>
      _InterfaceRegisterSectionState();
}

class _InterfaceRegisterSectionState extends State<_InterfaceRegisterSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InterfaceEntry> _applyFilters(List<InterfaceEntry> entries) {
    var filtered = entries;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((e) =>
              e.boundary.toLowerCase().contains(q) ||
              e.partyA.toLowerCase().contains(q) ||
              e.partyB.toLowerCase().contains(q) ||
              e.owner.toLowerCase().contains(q) ||
              e.notes.toLowerCase().contains(q))
          .toList();
    }
    if (_typeFilter != 'All') {
      filtered = filtered.where((e) => e.interfaceType == _typeFilter).toList();
    }
    if (_statusFilter != 'All') {
      filtered = filtered.where((e) => e.status == _statusFilter).toList();
    }
    if (_priorityFilter != 'All') {
      filtered = filtered.where((e) => e.priority == _priorityFilter).toList();
    }
    return filtered;
  }

  Widget _buildFilterBar() {
    final hasActiveFilters = _searchQuery.trim().isNotEmpty ||
        _typeFilter != 'All' ||
        _statusFilter != 'All' ||
        _priorityFilter != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = _buildSearchField(
            hint: constraints.maxWidth >= 820
                ? 'Search by boundary, party, owner, or notes…'
                : 'Search interfaces…',
          );
          const wideThreshold = 900.0;
          if (constraints.maxWidth >= wideThreshold) {
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: _buildTypeFilter(),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: _buildStatusFilter(),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: _buildPriorityFilter(),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 12),
                  _buildClearButton(),
                ],
              ],
            );
          }
          final singleColumn = constraints.maxWidth < 540;
          final filterWidth = singleColumn
              ? constraints.maxWidth
              : (constraints.maxWidth - 20) / 3;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: double.infinity, child: search),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: filterWidth, child: _buildTypeFilter()),
                  SizedBox(width: filterWidth, child: _buildStatusFilter()),
                  SizedBox(width: filterWidth, child: _buildPriorityFilter()),
                  if (hasActiveFilters) _buildClearButton(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField({required String hint}) {
    return VoiceTextField(
      controller: _searchController,
      maxLines: 1,
      enableVoice: false,
      enableKazAi: false,
      enableTextFormatting: false,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
    );
  }

  Widget _buildTypeFilter() => _buildFilterDropdown(
        label: 'Type',
        value: _typeFilter,
        items: const ['All', ..._kInterfaceTypes],
        onChanged: (value) {
          if (value != null) setState(() => _typeFilter = value);
        },
      );

  Widget _buildStatusFilter() => _buildFilterDropdown(
        label: 'Status',
        value: _statusFilter,
        items: const ['All', ..._kStatuses],
        onChanged: (value) {
          if (value != null) setState(() => _statusFilter = value);
        },
      );

  Widget _buildPriorityFilter() => _buildFilterDropdown(
        label: 'Priority',
        value: _priorityFilter,
        items: const ['All', ..._kPriorities],
        onChanged: (value) {
          if (value != null) setState(() => _priorityFilter = value);
        },
      );

  /// Builds a styled dropdown for a filter field. Used inside the filter bar
  /// so all dropdowns share consistent visual treatment.
  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      dropdownColor: Colors.white,
      items: items
          .map((s) => DropdownMenuItem(
              value: s,
              child: Text(s,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// "Clear" pill button shown in the filter bar when any filter is active.
  /// Resets all filters back to their defaults.
  Widget _buildClearButton() {
    return InkWell(
      onTap: () => setState(() {
        _searchController.clear();
        _searchQuery = '';
        _typeFilter = 'All';
        _statusFilter = 'All';
        _priorityFilter = 'All';
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_outlined,
                size: 14, color: Color(0xFFB45309)),
            SizedBox(width: 6),
            Text('Clear filters',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final allEntries = data.interfaceEntries;
    final entries = _applyFilters(allEntries);

    if (allEntries.isEmpty) {
      // Show link to auto-import from Technology Planning
      final extCount = data.externalIntegrations.length;
      return Column(
        children: [
          _buildFilterBar(),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No interfaces registered yet. Add entries manually or import from Technology Planning.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ),
          if (extCount > 0) ...[
            const SizedBox(height: 16),
            _ImportFromTechButton(count: extCount),
          ],
        ],
      );
    }

    return Column(
      children: [
        // Import hint if there are unlinked external integrations
        Builder(builder: (context) {
          final extIntegrations = data.externalIntegrations;
          final unlinked = extIntegrations.where((ext) {
            final name = ext['name']?.toString().trim().toLowerCase() ?? '';
            if (name.isEmpty) return false;
            return !allEntries.any((e) =>
                e.boundary.trim().toLowerCase() == name ||
                e.partyA.trim().toLowerCase() == name ||
                e.partyB.trim().toLowerCase() == name);
          }).length;
          if (unlinked > 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ImportFromTechButton(count: unlinked),
            );
          }
          return const SizedBox.shrink();
        }),
        // Filter bar
        _buildFilterBar(),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No interfaces match your filters.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          )
        else
          // Wrap the table in a horizontal scroll with a minimum width floor
          // so columns never overflow on narrow viewports — instead, the user
          // scrolls horizontally. On wide viewports the table fills the
          // available width thanks to the Expanded "Boundary / Name" column.
          LayoutBuilder(
            builder: (context, constraints) {
              const minTableWidth = 1200.0;
              final needsScroll = constraints.maxWidth < minTableWidth;
              final table = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTableHeader(),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _InterfaceRegisterRow(
                        index: index + 1,
                        entry: entry,
                      );
                    },
                  ),
                ],
              );
              if (!needsScroll) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minTableWidth,
                  child: table,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF374151),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB))),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 36,
              child:
                  Text('#', style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 12),
          Expanded(
              flex: 3, child: Text('Boundary / Name', style: headerStyle)),
          SizedBox(width: 12),
          SizedBox(width: 130, child: Text('Type', style: headerStyle)),
          SizedBox(width: 12),
          SizedBox(
              width: 130, child: Text('Party A', style: headerStyle)),
          SizedBox(width: 12),
          SizedBox(
              width: 130, child: Text('Party B', style: headerStyle)),
          SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text('Criticality',
                  style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text('Priority',
                  style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text('Status',
                  style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text('Actions',
                  style: headerStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _ImportFromTechButton extends StatelessWidget {
  const _ImportFromTechButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final data = ProjectDataHelper.getData(context);
        final entries = List<InterfaceEntry>.from(data.interfaceEntries);
        final extIntegrations = data.externalIntegrations;
        final logEntries =
            List<InterfaceChangeLogEntry>.from(data.interfaceChangeLog);
        final now = DateTime.now().toIso8601String();

        int added = 0;
        for (final ext in extIntegrations) {
          final name = ext['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final alreadyExists = entries.any(
              (e) => e.boundary.trim().toLowerCase() == name.toLowerCase());
          if (alreadyExists) continue;

          final newEntry = InterfaceEntry(
            boundary: name,
            owner: ext['description']?.toString() ?? '',
            interfaceType: 'Technical',
            protocol: ext['connectionType']?.toString() ?? 'API',
            status: ext['status']?.toString().isNotEmpty == true
                ? ext['status'].toString()
                : 'Pending',
            notes: 'Imported from Technology Planning',
          );
          entries.add(newEntry);
          logEntries.add(InterfaceChangeLogEntry(
            interfaceId: newEntry.id,
            interfaceName: name,
            action: 'Imported',
            newValue: name,
            changedAt: now,
          ));
          added++;
        }

        if (added > 0) {
          await ProjectDataHelper.updateAndSave(
            context: context,
            checkpoint: 'interface_management',
            dataUpdater: (d) => d.copyWith(
              interfaceEntries: entries,
              interfaceChangeLog: logEntries,
            ),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Imported $added interface(s) from Technology Planning')),
            );
          }
        }
      },
      icon: const Icon(Icons.download_outlined, size: 16),
      label: Text('Import $count from Technology Planning'),
    );
  }
}

class _InterfaceRegisterRow extends StatelessWidget {
  const _InterfaceRegisterRow({
    required this.index,
    required this.entry,
  });

  final int index;
  final InterfaceEntry entry;

  @override
  Widget build(BuildContext context) {
    final name =
        entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFE5E7EB)),
          right: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('$index',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _HealthDot(entry: entry),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: _TypeBadge(type: entry.interfaceType),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(entry.partyA.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(entry.partyB.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _CriticalityBadge(criticality: entry.criticality),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _PriorityBadge(priority: entry.priority),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _StatusBadge(label: entry.status),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () =>
                      _InterfaceEntryDialog.show(context, entry, const []),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deleteEntry(context, entry.id),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove interface entry'),
        content: const Text(
            'This will delete the interface entry and remove it from AI context.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final data = ProjectDataHelper.getData(context);
    final entryToDelete = data.interfaceEntries.where((e) => e.id == id).firstOrNull;
if (entryToDelete == null) return;
final entries = data.interfaceEntries.where((e) => e.id != id).toList();
    final logEntries =
        List<InterfaceChangeLogEntry>.from(data.interfaceChangeLog);
    logEntries.add(InterfaceChangeLogEntry(
      interfaceId: entryToDelete.id,
      interfaceName: entryToDelete.boundary.trim().isNotEmpty
          ? entryToDelete.boundary.trim()
          : 'Unnamed',
      action: 'Deleted',
      oldValue: entryToDelete.boundary,
      changedAt: DateTime.now().toIso8601String(),
    ));
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'interface_management',
      dataUpdater: (d) => d.copyWith(
        interfaceEntries: entries,
        interfaceChangeLog: logEntries,
      ),
      showSnackbar: false,
    );
      showDeleteSuccessSnackBar(context, itemLabel: 'Entry');
  }
}

// ─── Entry Dialog (enhanced with new fields) ─────────────────────────────────

class _InterfaceEntryDialog extends StatefulWidget {
  const _InterfaceEntryDialog({
    this.initial,
    this.suggestedNames = const [],
  });

  final InterfaceEntry? initial;
  final List<String> suggestedNames;

  static void show(
      BuildContext context, InterfaceEntry? initial, List<String> suggested) {
    showDialog<InterfaceEntry>(
      context: context,
      builder: (_) => _InterfaceEntryDialog(
        initial: initial,
        suggestedNames: suggested,
      ),
    ).then((result) {
      if (result == null) return;
      final data = ProjectDataHelper.getData(context);
      final entries = List<InterfaceEntry>.from(data.interfaceEntries);
      final logEntries =
          List<InterfaceChangeLogEntry>.from(data.interfaceChangeLog);
      final index = entries.indexWhere((e) => e.id == result.id);
      final isCreate = index == -1;
      if (isCreate) {
        entries.add(result);
        logEntries.add(InterfaceChangeLogEntry(
          interfaceId: result.id,
          interfaceName: result.boundary.trim().isNotEmpty
              ? result.boundary.trim()
              : 'Unnamed',
          action: 'Created',
          newValue: result.boundary,
          changedAt: DateTime.now().toIso8601String(),
        ));
      } else {
        final old = entries[index];
        entries[index] = result;
        // Create log entries for each changed field
        final name = result.boundary.trim().isNotEmpty
            ? result.boundary.trim()
            : 'Unnamed';
        final now = DateTime.now().toIso8601String();
        final fields = <(String, String, String)>[
          ('Boundary', old.boundary, result.boundary),
          ('Interface Type', old.interfaceType, result.interfaceType),
          ('Party A', old.partyA, result.partyA),
          ('Party B', old.partyB, result.partyB),
          ('Criticality', old.criticality, result.criticality),
          ('Priority', old.priority, result.priority),
          ('Data Flow', old.dataFlow, result.dataFlow),
          ('Protocol', old.protocol, result.protocol),
          ('Owner', old.owner, result.owner),
          ('Status', old.status, result.status),
          ('Cadence', old.cadence, result.cadence),
          ('Notes', old.notes, result.notes),
        ];
        for (final (fieldName, oldVal, newVal) in fields) {
          if (oldVal.trim() != newVal.trim()) {
            final action = fieldName == 'Status' ? 'Status Changed' : 'Updated';
            logEntries.add(InterfaceChangeLogEntry(
              interfaceId: result.id,
              interfaceName: name,
              action: action,
              fieldName: fieldName,
              oldValue: oldVal,
              newValue: newVal,
              changedAt: now,
            ));
          }
        }
      }
      ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'interface_management',
        dataUpdater: (d) => d.copyWith(
          interfaceEntries: entries,
          interfaceChangeLog: logEntries,
        ),
        showSnackbar: false,
      );
    });
  }

  @override
  State<_InterfaceEntryDialog> createState() => _InterfaceEntryDialogState();
}

class _InterfaceEntryDialogState extends State<_InterfaceEntryDialog> {
  late final TextEditingController _boundaryCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _partyACtrl;
  late final TextEditingController _partyBCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _dependenciesCtrl;
  late final TextEditingController _conflictResolutionCtrl;
  late final TextEditingController _escalationPathCtrl;
  late final TextEditingController _assumptionsCtrl;
  late final TextEditingController _changeImpactsCtrl;

  String _interfaceType = '';
  String _priority = '';
  String _criticality = '';
  String _dataFlow = '';
  String _protocol = '';
  String _status = '';
  String _cadence = '';
  String _interfaceClassification = '';

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _boundaryCtrl = TextEditingController(text: e?.boundary ?? '');
    _ownerCtrl = TextEditingController(text: e?.owner ?? '');
    _partyACtrl = TextEditingController(text: e?.partyA ?? '');
    _partyBCtrl = TextEditingController(text: e?.partyB ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _dependenciesCtrl = TextEditingController(text: e?.dependencies ?? '');
    _conflictResolutionCtrl = TextEditingController(text: e?.conflictResolution ?? '');
    _escalationPathCtrl = TextEditingController(text: e?.escalationPath ?? '');
    _assumptionsCtrl = TextEditingController(text: e?.assumptions ?? '');
    _changeImpactsCtrl = TextEditingController(text: e?.changeImpacts ?? '');
    _interfaceType = e?.interfaceType ?? 'Technical';
    _priority = e?.priority ?? 'Medium';
    _criticality = e?.criticality ?? 'Major';
    _dataFlow = e?.dataFlow ?? 'Bidirectional';
    _protocol = e?.protocol ?? 'API';
    _status = e?.status ?? 'Pending';
    _cadence = e?.cadence ?? 'As Needed';
    _interfaceClassification = e?.interfaceClassification ?? 'Internal';
  }

  @override
  void dispose() {
    _boundaryCtrl.dispose();
    _ownerCtrl.dispose();
    _partyACtrl.dispose();
    _partyBCtrl.dispose();
    _notesCtrl.dispose();
    _dependenciesCtrl.dispose();
    _conflictResolutionCtrl.dispose();
    _escalationPathCtrl.dispose();
    _assumptionsCtrl.dispose();
    _changeImpactsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final entry = InterfaceEntry(
      id: widget.initial?.id,
      boundary: _boundaryCtrl.text.trim(),
      owner: _ownerCtrl.text.trim(),
      cadence: _cadence,
      risk: widget.initial?.risk ?? '',
      status: _status,
      lastSync: widget.initial?.lastSync ?? '',
      notes: _notesCtrl.text.trim(),
      interfaceType: _interfaceType,
      partyA: _partyACtrl.text.trim(),
      partyB: _partyBCtrl.text.trim(),
      priority: _priority,
      criticality: _criticality,
      dataFlow: _dataFlow,
      protocol: _protocol,
      interfaceClassification: _interfaceClassification,
      dependencies: _dependenciesCtrl.text.trim(),
      conflictResolution: _conflictResolutionCtrl.text.trim(),
      escalationPath: _escalationPathCtrl.text.trim(),
      assumptions: _assumptionsCtrl.text.trim(),
      changeImpacts: _changeImpactsCtrl.text.trim(),
    );
    Navigator.of(context).pop(entry);
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VoiceTextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border:
             OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border:
             OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            if (label == 'Interface Type *') {
              _interfaceType = v;
            } else if (label == 'Priority *') {
              _priority = v;
            } else if (label == 'Criticality *') {
              _criticality = v;
            } else if (label == 'Data Flow') {
              _dataFlow = v;
            } else if (label == 'Protocol') {
              _protocol = v;
            } else if (label == 'Status *') {
              _status = v;
            } else if (label == 'Review Cadence') {
              _cadence = v;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null
          ? 'Add Interface Entry'
          : 'Edit Interface Entry'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Suggested names from Technology Planning
                if (widget.suggestedNames.isNotEmpty &&
                    widget.initial == null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Suggested from Technology Planning:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280))),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.suggestedNames.take(8).map((name) {
                      return ActionChip(
                        label: Text(name),
                        onPressed: () {
                          _boundaryCtrl.text = name;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                _field('Interface Name / Boundary *', _boundaryCtrl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _dropdown('Interface Type *', _interfaceType,
                            _kInterfaceTypes)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _dropdown('Priority *', _priority, _kPriorities)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _field('Party A (Provider) *', _partyACtrl)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field('Party B (Receiver) *', _partyBCtrl)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _dropdown(
                            'Criticality *', _criticality, _kCriticalities)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _dropdown('Data Flow', _dataFlow, _kDataFlows)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _dropdown('Protocol', _protocol, _kProtocols)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown('Status *', _status, _kStatuses)),
                  ],
                ),
                _field('Owner', _ownerCtrl),
                _dropdown('Review Cadence', _cadence, _kCadences),
                _field('Notes', _notesCtrl, maxLines: 3),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                // Interface Management Plan fields
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Interface Management Plan Details',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _dropdown('Classification', _interfaceClassification,
                            _kInterfaceClassifications)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _dropdown('Dependencies',
                            _dependenciesCtrl.text.isEmpty ? 'Deliverable' : _dependenciesCtrl.text,
                            _kDependencyTypes)),
                  ],
                ),
                _field('Conflict Resolution Process', _conflictResolutionCtrl),
                _field('Escalation Path', _escalationPathCtrl),
                _field('Assumptions', _assumptionsCtrl),
                _field('Change Impacts', _changeImpactsCtrl),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: Architecture
// ═══════════════════════════════════════════════════════════════════════════════

class _ArchitectureSection extends StatelessWidget {
  const _ArchitectureSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;
    final extIntegrations = data.externalIntegrations;

    // Categorize entries by type
    final technical = entries
        .where((e) =>
            e.interfaceType.toLowerCase().contains('tech') ||
            e.interfaceType.isEmpty)
        .toList();
    final contractual = entries
        .where((e) => e.interfaceType.toLowerCase().contains('contract'))
        .toList();
    final organizational = entries
        .where((e) => e.interfaceType.toLowerCase().contains('org'))
        .toList();
    final physical = entries
        .where((e) => e.interfaceType.toLowerCase().contains('physical'))
        .toList();
    final procedural = entries
        .where((e) => e.interfaceType.toLowerCase().contains('procedural'))
        .toList();

    // Also use external integrations data
    final extNames = extIntegrations
        .map((e) => e['name']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interface architecture shows how systems connect, what data flows between them, and which protocols govern each connection. This visual summary draws from your Interface Register and Technology Planning data to give teams a shared understanding of integration touchpoints.',
          style: TextStyle(
              fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 24),

        // External Systems layer
        if (extNames.isNotEmpty || contractual.isNotEmpty) ...[
          _ArchitectureLayer(
            title: 'External Systems',
            color: const Color(0xFFFFE4CC),
            borderColor: const Color(0xFFD97706),
            items: [
              ...extNames.map((n) => _ArchCard(
                  title: n,
                  subtitle: 'External',
                  color: const Color(0xFFFFE4CC),
                  dataFlow: null)),
              ...contractual.map((e) => _ArchCard(
                    title: e.boundary.trim().isNotEmpty
                        ? e.boundary.trim()
                        : 'Contract',
                    subtitle: e.partyA.trim(),
                    color: const Color(0xFFFFE4CC),
                    dataFlow: e.dataFlow,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          _ArrowRow(),
          const SizedBox(height: 16),
        ],

        // API / Protocol layer
        _ArchitectureLayer(
          title: 'Integration Layer',
          color: const Color(0xFFD4E4FF),
          borderColor: const Color(0xFFFFC812),
          items: technical.isEmpty
              ? [
                  const _ArchCard(
                      title: 'No technical interfaces defined',
                      subtitle: 'Add entries to the register',
                      color: Color(0xFFE5E7EB),
                      dataFlow: null)
                ]
              : technical
                  .map((e) => _ArchCard(
                        title: e.boundary.trim().isNotEmpty
                            ? e.boundary.trim()
                            : 'Interface',
                        subtitle: e.protocol.trim().isNotEmpty
                            ? e.protocol.trim()
                            : 'API',
                        color: const Color(0xFFD4E4FF),
                        dataFlow: e.dataFlow,
                      ))
                  .toList(),
        ),
        const SizedBox(height: 16),
        _ArrowRow(),
        const SizedBox(height: 16),

        // Internal Systems layer
        _ArchitectureLayer(
          title: 'Internal Systems',
          color: const Color(0xFFD4FFD4),
          borderColor: const Color(0xFF10B981),
          items: organizational.isEmpty
              ? [
                  const _ArchCard(
                      title: 'Add organizational interfaces',
                      subtitle: 'Define Party A/B connections',
                      color: Color(0xFFE5E7EB),
                      dataFlow: null)
                ]
              : organizational
                  .map((e) => _ArchCard(
                        title: e.boundary.trim().isNotEmpty
                            ? e.boundary.trim()
                            : 'Interface',
                        subtitle: '${e.partyA.trim()} ↔ ${e.partyB.trim()}',
                        color: const Color(0xFFD4FFD4),
                        dataFlow: e.dataFlow,
                      ))
                  .toList(),
        ),
        if (physical.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ArrowRow(),
          const SizedBox(height: 16),
          _ArchitectureLayer(
            title: 'Physical Systems',
            color: const Color(0xFFE8D5F5),
            borderColor: const Color(0xFFB8860B),
            items: physical
                .map((e) => _ArchCard(
                      title: e.boundary.trim().isNotEmpty
                          ? e.boundary.trim()
                          : 'Interface',
                      subtitle: '${e.partyA.trim()} ↔ ${e.partyB.trim()}',
                      color: const Color(0xFFE8D5F5),
                      dataFlow: e.dataFlow,
                    ))
                .toList(),
          ),
        ],
        if (procedural.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ArrowRow(),
          const SizedBox(height: 16),
          _ArchitectureLayer(
            title: 'Procedural Interfaces',
            color: const Color(0xFFFFE0E6),
            borderColor: const Color(0xFFD97706),
            items: procedural
                .map((e) => _ArchCard(
                      title: e.boundary.trim().isNotEmpty
                          ? e.boundary.trim()
                          : 'Interface',
                      subtitle: '${e.partyA.trim()} ↔ ${e.partyB.trim()}',
                      color: const Color(0xFFFFE0E6),
                      dataFlow: e.dataFlow,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ArchitectureLayer extends StatelessWidget {
  const _ArchitectureLayer({
    required this.title,
    required this.color,
    required this.borderColor,
    required this.items,
  });

  final String title;
  final Color color;
  final Color borderColor;
  final List<_ArchCard> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          ),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: items),
      ],
    );
  }
}

class _ArchCard extends StatelessWidget {
  const _ArchCard({
    required this.title,
    required this.subtitle,
    required this.color,
    this.dataFlow,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String? dataFlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          if (dataFlow != null &&
              dataFlow!.trim().isNotEmpty &&
              dataFlow!.trim() != 'Bidirectional')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                dataFlow!.trim() == 'A to B'
                    ? '→'
                    : dataFlow!.trim() == 'B to A'
                        ? '←'
                        : '↔',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.arrow_downward, color: Color(0xFF9CA3AF), size: 24),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3: RACI & Governance
// ═══════════════════════════════════════════════════════════════════════════════

class _RaciGovernanceSection extends StatelessWidget {
  const _RaciGovernanceSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The RACI matrix clarifies who is Responsible, Accountable, Consulted, and Informed for each interface. Governance defines review cadence, escalation paths, and last sync dates to keep interfaces aligned throughout the project lifecycle.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 20),

        // RACI Table
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Add interface entries to populate the RACI matrix.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const minTableWidth = 560.0;
              final needsScroll = constraints.maxWidth < minTableWidth;
              final table = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRaciHeader(),
                  // Tooltip row
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Text('',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF9CA3AF))),
                        ),
                        SizedBox(width: 8),
                        _RaciTooltipBadge(
                            label: 'R', tip: 'Responsible — does the work'),
                        SizedBox(width: 8),
                        _RaciTooltipBadge(
                            label: 'A', tip: 'Accountable — owns the outcome'),
                        SizedBox(width: 8),
                        _RaciTooltipBadge(
                            label: 'C', tip: 'Consulted — provides input'),
                        SizedBox(width: 8),
                        _RaciTooltipBadge(
                            label: 'I', tip: 'Informed — kept up to date'),
                      ],
                    ),
                  ),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _buildRaciRow(entries[index]),
                  ),
                ],
              );
              if (!needsScroll) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minTableWidth, child: table),
              );
            },
          ),

        const SizedBox(height: 32),

        // Governance Cadence Summary
        _SectionSubcard(
          title: 'Governance & Cadence',
          subtitle:
              'Review rhythm, escalation, and last synchronization for each interface.',
          child: entries.every(
                  (e) => e.cadence.trim().isEmpty && e.owner.trim().isEmpty)
              ? const Text(
                  'Define interface owners and cadences to anchor your governance.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                )
              : Column(
                  children: entries
                      .where((e) =>
                          e.cadence.trim().isNotEmpty ||
                          e.owner.trim().isNotEmpty)
                      .map((entry) {
                    final name = entry.boundary.trim().isNotEmpty
                        ? entry.boundary.trim()
                        : 'Unnamed';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle,
                              size: 8, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$name | Owner: ${entry.owner.trim().isNotEmpty ? entry.owner.trim() : "Unassigned"}'
                              '${entry.cadence.trim().isNotEmpty ? " | Cadence: ${entry.cadence.trim()}" : ""}'
                              '${entry.lastSync.trim().isNotEmpty ? " | Last sync: ${entry.lastSync.trim()}" : ""}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildRaciHeader() {
    const style = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB))),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Interface', style: style)),
          SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text('R', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text('A', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text('C', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text('I', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildRaciRow(InterfaceEntry entry) {
    final name =
        entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';
    const cellStyle = TextStyle(fontSize: 12, color: Color(0xFF4B5563));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFE5E7EB)),
          right: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.partyA.trim().isNotEmpty ? entry.partyA.trim() : '-',
                style: cellStyle,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.owner.trim().isNotEmpty ? entry.owner.trim() : '-',
                style: cellStyle,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.partyB.trim().isNotEmpty ? entry.partyB.trim() : '-',
                style: cellStyle,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Team',
                style: cellStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4: Risks & Decisions
// ═══════════════════════════════════════════════════════════════════════════════

class _RisksDecisionsSection extends StatelessWidget {
  const _RisksDecisionsSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;
    final isMobile = AppBreakpoints.isMobile(context);

    final riskEntries = entries.where((e) => e.risk.trim().isNotEmpty).toList();
    final decisionEntries =
        entries.where((e) => e.notes.trim().isNotEmpty).toList();

    // Build the two cards once so they can be reused in either the wide
    // (side-by-side Row with Expanded) or narrow (stacked Column) layout
    // without duplicating their contents.
    final dependencyRisksCard = _SectionSubcard(
      title: 'Dependency Risks',
      subtitle: 'Critical issues to resolve before baseline freeze.',
      child: riskEntries.isEmpty
          ? const Text(
              'Record interface risks so teams can address blockers early.',
              style:
                  TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk summary
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RiskCountChip(
                          label: 'Critical',
                          count: riskEntries
                              .where((e) =>
                                  e.criticality.toLowerCase() ==
                                  'critical')
                              .length,
                          color: const Color(0xFFEF4444)),
                      _RiskCountChip(
                          label: 'Major',
                          count: riskEntries
                              .where((e) =>
                                  e.criticality.toLowerCase() ==
                                  'major')
                              .length,
                          color: const Color(0xFFF59E0B)),
                      _RiskCountChip(
                          label: 'Minor',
                          count: riskEntries
                              .where((e) =>
                                  e.criticality.toLowerCase() ==
                                  'minor')
                              .length,
                          color: const Color(0xFF6B7280)),
                    ],
                  ),
                ),
                // Risk items sorted by criticality
                ..._sortedByCriticality(riskEntries).map((entry) {
                  final name = entry.boundary.trim().isNotEmpty
                      ? entry.boundary.trim()
                      : 'Interface';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _isCriticalRisk(entry.risk)
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827))),
                                  if (entry.interfaceType
                                      .trim()
                                      .isNotEmpty)
                                    _TypeBadge(
                                        type: entry.interfaceType),
                                  if (entry.dataFlow
                                      .trim()
                                      .isNotEmpty)
                                    Text('(${entry.dataFlow.trim()})',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color:
                                                Color(0xFF9CA3AF))),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(entry.risk.trim(),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                      height: 1.4)),
                              if (entry.criticality.trim().isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4),
                                  child: _CriticalityBadge(
                                      criticality: entry.criticality),
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
    );

    final decisionLogCard = _SectionSubcard(
      title: 'Decision Log',
      subtitle: 'Recent interface decisions and approvals.',
      child: decisionEntries.isEmpty
          ? const Text(
              'Add notes to capture decisions, approvals, and alignment.',
              style:
                  TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            )
          : Column(
              children: decisionEntries.map((entry) {
                final name = entry.boundary.trim().isNotEmpty
                    ? entry.boundary.trim()
                    : 'Interface note';
                final timestamp = entry.lastSync.trim().isNotEmpty
                    ? entry.lastSync.trim()
                    : 'Recent';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('$name ($timestamp)',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827))),
                            const SizedBox(height: 2),
                            Text(entry.notes.trim(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interface risks highlight dependencies that could delay deliverables or create rework. The decision log captures key approvals, alignment decisions, and change agreements made during interface coordination meetings.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        // Wide screens: cards side-by-side, each Expanded to fill half the
        // available width (no right-side whitespace). Narrow screens: stack.
        LayoutBuilder(
          builder: (context, constraints) {
            if (!isMobile && constraints.maxWidth >= 720) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: dependencyRisksCard),
                    const SizedBox(width: 24),
                    Expanded(child: decisionLogCard),
                  ],
                ),
              );
            }
            return Column(
              children: [
                dependencyRisksCard,
                const SizedBox(height: 24),
                decisionLogCard,
              ],
            );
          },
        ),
      ],
    );
  }

  List<InterfaceEntry> _sortedByCriticality(List<InterfaceEntry> entries) {
    final sorted = List<InterfaceEntry>.from(entries);
    sorted.sort((a, b) {
      const order = {'critical': 0, 'major': 1, 'minor': 2};
      final aOrder = order[a.criticality.toLowerCase()] ?? 9;
      final bOrder = order[b.criticality.toLowerCase()] ?? 9;
      return aOrder.compareTo(bOrder);
    });
    return sorted;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 6: Maturity Score
// ═══════════════════════════════════════════════════════════════════════════════

class _MaturitySection extends StatefulWidget {
  const _MaturitySection();

  @override
  State<_MaturitySection> createState() => _MaturitySectionState();
}

class _MaturitySectionState extends State<_MaturitySection> {
  bool _showAll = false;

  int _calculateMaturityScore(InterfaceEntry entry) {
    int score = 0;
    if (entry.boundary.trim().isNotEmpty) score += 10;
    if (entry.interfaceType.trim().isNotEmpty) score += 10;
    if (entry.partyA.trim().isNotEmpty && entry.partyB.trim().isNotEmpty) {
      score += 15;
    }
    if (entry.criticality.trim().isNotEmpty) score += 10;
    if (entry.priority.trim().isNotEmpty) score += 10;
    if (entry.dataFlow.trim().isNotEmpty) score += 10;
    if (entry.protocol.trim().isNotEmpty) score += 10;
    if (entry.owner.trim().isNotEmpty) score += 10;
    if (!_isOpenStatus(entry.status)) score += 10;
    if (entry.notes.trim().isNotEmpty) score += 5;
    return score;
  }

  String _maturityLabel(int score) {
    if (score <= 30) return 'Immature';
    if (score <= 60) return 'Developing';
    if (score <= 80) return 'Mature';
    return 'Optimized';
  }

  Color _maturityColor(int score) {
    if (score <= 30) return const Color(0xFFEF4444);
    if (score <= 60) return const Color(0xFFF59E0B);
    if (score <= 80) return const Color(0xFFFFC812);
    return const Color(0xFF10B981);
  }

  Color _maturityBgColor(int score) {
    if (score <= 30) return const Color(0xFFFEE2E2);
    if (score <= 60) return const Color(0xFFFEF3C7);
    if (score <= 80) return const Color(0xFFFEF3C7);
    return const Color(0xFFD1FAE5);
  }

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Add interface entries to calculate maturity scores.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    final scores = entries.map((e) => _calculateMaturityScore(e)).toList();
    final avgScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final avgRounded = avgScore.round();

    // Breakdown by maturity level
    final immature = scores.where((s) => s <= 30).length;
    final developing = scores.where((s) => s > 30 && s <= 60).length;
    final mature = scores.where((s) => s > 60 && s <= 80).length;
    final optimized = scores.where((s) => s > 80).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interface maturity measures how completely each interface is defined across key attributes — boundary, type, parties, criticality, priority, data flow, protocol, owner, status, and notes. A higher score indicates better readiness for coordination and handoff.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 24),

        // Overall portfolio maturity gauge
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: avgRounded / 100,
                      strokeWidth: 12,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _maturityColor(avgRounded)),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$avgRounded',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: _maturityColor(avgRounded),
                              )),
                          Text(_maturityLabel(avgRounded),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _maturityColor(avgRounded),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('Portfolio Maturity Score',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Breakdown by maturity level
        Row(
          children: [
            _MaturityBreakdownCard(
                label: 'Immature',
                count: immature,
                color: const Color(0xFFEF4444)),
            const SizedBox(width: 12),
            _MaturityBreakdownCard(
                label: 'Developing',
                count: developing,
                color: const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _MaturityBreakdownCard(
                label: 'Mature', count: mature, color: const Color(0xFFFFC812)),
            const SizedBox(width: 12),
            _MaturityBreakdownCard(
                label: 'Optimized',
                count: optimized,
                color: const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 24),

        // Per-interface maturity bars
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final score = scores[index];
            if (!_showAll && index >= 10) return const SizedBox.shrink();
            return _MaturityBar(
              name: entry.boundary.trim().isNotEmpty
                  ? entry.boundary.trim()
                  : 'Unnamed',
              score: score,
              color: _maturityColor(score),
              bgColor: _maturityBgColor(score),
              label: _maturityLabel(score),
            );
          },
        ),

        if (entries.length > 10) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showAll = !_showAll),
            icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more,
                size: 18),
            label:
                Text(_showAll ? 'Show Less' : 'Show All (${entries.length})'),
          ),
        ],
      ],
    );
  }
}

class _MaturityBreakdownCard extends StatelessWidget {
  const _MaturityBreakdownCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.08), Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

class _MaturityBar extends StatelessWidget {
  const _MaturityBar({
    required this.name,
    required this.score,
    required this.color,
    required this.bgColor,
    required this.label,
  });

  final String name;
  final int score;
  final Color color;
  final Color bgColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text('$score',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  Color.alphaBlend(color.withValues(alpha: 0.15), Colors.white),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 5: Dependency Management
// ═══════════════════════════════════════════════════════════════════════════════

class _DependencyManagementSection extends StatelessWidget {
  const _DependencyManagementSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Add interface entries to track dependencies.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    // Categorize by dependency type
    final deliverableDeps = entries.where((e) => e.dependencies.toLowerCase().contains('deliverable')).toList();
    final scheduleDeps = entries.where((e) => e.dependencies.toLowerCase().contains('schedule')).toList();
    final resourceDeps = entries.where((e) => e.dependencies.toLowerCase().contains('resource')).toList();
    final procurementDeps = entries.where((e) => e.dependencies.toLowerCase().contains('procurement')).toList();
    final technicalDeps = entries.where((e) => e.dependencies.toLowerCase().contains('technical')).toList();
    final uncategorized = entries.where((e) => e.dependencies.trim().isEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dependency management tracks deliverable, schedule, resource, procurement, and technical dependencies between interfaces. Identifying these dependencies early helps prevent conflicts and ensures seamless coordination between stakeholders.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 24),

        // Dependency Summary Cards
        _buildDependencySummaryCards(entries),
        const SizedBox(height: 24),

        // Dependency Categories
        if (deliverableDeps.isNotEmpty) ...[
          _buildDependencyCategory('Deliverable Dependencies', deliverableDeps, const Color(0xFF10B981)),
          const SizedBox(height: 16),
        ],
        if (scheduleDeps.isNotEmpty) ...[
          _buildDependencyCategory('Schedule Dependencies', scheduleDeps, const Color(0xFFF59E0B)),
          const SizedBox(height: 16),
        ],
        if (resourceDeps.isNotEmpty) ...[
          _buildDependencyCategory('Resource Dependencies', resourceDeps, const Color(0xFF3B82F6)),
          const SizedBox(height: 16),
        ],
        if (procurementDeps.isNotEmpty) ...[
          _buildDependencyCategory('Procurement & Contract Dependencies', procurementDeps, const Color(0xFF8B5CF6)),
          const SizedBox(height: 16),
        ],
        if (technicalDeps.isNotEmpty) ...[
          _buildDependencyCategory('Technical & Operational Dependencies', technicalDeps, const Color(0xFFEF4444)),
          const SizedBox(height: 16),
        ],
        if (uncategorized.isNotEmpty) ...[
          _buildDependencyCategory('Uncategorized', uncategorized, const Color(0xFF6B7280)),
          const SizedBox(height: 16),
        ],

        // Conflict Resolution & Escalation
        _buildConflictResolutionSection(entries),
      ],
    );
  }

  Widget _buildDependencySummaryCards(List<InterfaceEntry> entries) {
    final withDeps = entries.where((e) => e.dependencies.trim().isNotEmpty).length;
    final withConflictResolution = entries.where((e) => e.conflictResolution.trim().isNotEmpty).length;
    final withEscalation = entries.where((e) => e.escalationPath.trim().isNotEmpty).length;

    return Row(
      children: [
        Expanded(child: _DependencySummaryCard(
          label: 'With Dependencies',
          value: '$withDeps',
          total: entries.length,
          color: const Color(0xFF10B981),
        )),
        const SizedBox(width: 12),
        Expanded(child: _DependencySummaryCard(
          label: 'Conflict Resolution',
          value: '$withConflictResolution',
          total: entries.length,
          color: const Color(0xFFF59E0B),
        )),
        const SizedBox(width: 12),
        Expanded(child: _DependencySummaryCard(
          label: 'Escalation Defined',
          value: '$withEscalation',
          total: entries.length,
          color: const Color(0xFF3B82F6),
        )),
      ],
    );
  }

  Widget _buildDependencyCategory(String title, List<InterfaceEntry> entries, Color color) {
    return _SectionSubcard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) {
          final name = entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      if (entry.dependencies.trim().isNotEmpty)
                        Text(entry.dependencies, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      if (entry.partyA.trim().isNotEmpty || entry.partyB.trim().isNotEmpty)
                        Text('${entry.partyA.trim()} ↔ ${entry.partyB.trim()}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConflictResolutionSection(List<InterfaceEntry> entries) {
    final withConflictRes = entries.where((e) => e.conflictResolution.trim().isNotEmpty).toList();
    final withEscalation = entries.where((e) => e.escalationPath.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conflict Resolution & Escalation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        if (withConflictRes.isEmpty && withEscalation.isEmpty)
          const Text(
            'Define conflict resolution processes and escalation paths for interfaces.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          )
        else ...[
          if (withConflictRes.isNotEmpty) ...[
            _SectionSubcard(
              title: 'Conflict Resolution Processes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: withConflictRes.map((entry) {
                  final name = entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.gavel, size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              Text(entry.conflictResolution, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (withEscalation.isNotEmpty) ...[
            _SectionSubcard(
              title: 'Escalation Paths',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: withEscalation.map((entry) {
                  final name = entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_upward, size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              Text(entry.escalationPath, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _DependencySummaryCard extends StatelessWidget {
  const _DependencySummaryCard({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final String value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 4),
              Text('/ $total', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? int.parse(value) / total : 0,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 8: Interface Status Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class _InterfaceStatusDashboardSection extends StatelessWidget {
  const _InterfaceStatusDashboardSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Add interface entries to view the status dashboard.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    // Status distribution
    final statusCounts = <String, int>{};
    for (final entry in entries) {
      final status = entry.status.trim().isNotEmpty ? entry.status.trim() : 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    // Priority distribution
    final priorityCounts = <String, int>{};
    for (final entry in entries) {
      final priority = entry.priority.trim().isNotEmpty ? entry.priority.trim() : 'Unknown';
      priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
    }

    // Classification distribution
    final classificationCounts = <String, int>{};
    for (final entry in entries) {
      final classification = entry.interfaceClassification.trim().isNotEmpty
          ? entry.interfaceClassification.trim()
          : 'Unclassified';
      classificationCounts[classification] = (classificationCounts[classification] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interface status dashboard provides a comprehensive view of all interface statuses, priorities, and classifications. Use this view to track progress and identify interfaces requiring attention.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 24),

        // Status Distribution
        _buildStatusDistribution(statusCounts, entries.length),
        const SizedBox(height: 24),

        // Priority Distribution
        _buildPriorityDistribution(priorityCounts, entries.length),
        const SizedBox(height: 24),

        // Classification Distribution
        _buildClassificationDistribution(classificationCounts, entries.length),
        const SizedBox(height: 24),

        // Interface List by Status
        _buildInterfaceListByStatus(entries),
      ],
    );
  }

  Widget _buildStatusDistribution(Map<String, int> statusCounts, int total) {
    final colors = {
      'Active': const Color(0xFF10B981),
      'Pending': const Color(0xFFF59E0B),
      'Under Review': const Color(0xFF3B82F6),
      'Approved': const Color(0xFF10B981),
      'Closed': const Color(0xFF6B7280),
      'Resolved': const Color(0xFF8B5CF6),
      'Unknown': const Color(0xFF9CA3AF),
    };

    return _SectionSubcard(
      title: 'Status Distribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: statusCounts.entries.map((entry) {
          final color = colors[entry.key] ?? const Color(0xFF6B7280);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? entry.value / total : 0,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 40, child: Text('${entry.value}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriorityDistribution(Map<String, int> priorityCounts, int total) {
    final colors = {
      'High': const Color(0xFFEF4444),
      'Medium': const Color(0xFFF59E0B),
      'Low': const Color(0xFF10B981),
      'Unknown': const Color(0xFF9CA3AF),
    };

    return _SectionSubcard(
      title: 'Priority Distribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: priorityCounts.entries.map((entry) {
          final color = colors[entry.key] ?? const Color(0xFF6B7280);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? entry.value / total : 0,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 40, child: Text('${entry.value}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClassificationDistribution(Map<String, int> classificationCounts, int total) {
    final colors = {
      'Internal': const Color(0xFF10B981),
      'External': const Color(0xFFF59E0B),
      'Unclassified': const Color(0xFF9CA3AF),
    };

    return _SectionSubcard(
      title: 'Classification Distribution (Internal vs External)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: classificationCounts.entries.map((entry) {
          final color = colors[entry.key] ?? const Color(0xFF6B7280);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? entry.value / total : 0,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 40, child: Text('${entry.value}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInterfaceListByStatus(List<InterfaceEntry> entries) {
    final grouped = <String, List<InterfaceEntry>>{};
    for (final entry in entries) {
      final status = entry.status.trim().isNotEmpty ? entry.status.trim() : 'Unknown';
      grouped.putIfAbsent(status, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interfaces by Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) {
          final status = entry.key;
          final interfaces = entry.value;
          return _SectionSubcard(
            title: '$status (${interfaces.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: interfaces.map((e) {
                final name = e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Unnamed';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _HealthDot(entry: e),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      if (e.owner.trim().isNotEmpty)
                        Text('Owner: ${e.owner}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 9: Audit Trail
// ═══════════════════════════════════════════════════════════════════════════════

class _AuditTrailSection extends StatelessWidget {
  const _AuditTrailSection();

  Color _actionColor(String action) {
    switch (action) {
      case 'Created':
        return const Color(0xFF10B981);
      case 'Updated':
        return const Color(0xFFFFC812);
      case 'Deleted':
        return const Color(0xFFEF4444);
      case 'Status Changed':
        return const Color(0xFFF59E0B);
      case 'Imported':
        return const Color(0xFFB8860B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'Created':
        return Icons.add_circle_outline;
      case 'Updated':
        return Icons.edit_outlined;
      case 'Deleted':
        return Icons.delete_outline;
      case 'Status Changed':
        return Icons.swap_horiz;
      case 'Imported':
        return Icons.download_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTimestamp(String iso) {
    if (iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final logEntries =
        List<InterfaceChangeLogEntry>.from(data.interfaceChangeLog)
          ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The audit trail records every change made to interface entries — creations, edits, deletions, status changes, and imports. Use this log to trace who changed what and when, supporting governance, compliance, and incident investigation.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        if (logEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No changes logged yet. Changes will appear here as you create, edit, or delete interface entries.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const minTableWidth = 760.0;
              final needsScroll = constraints.maxWidth < minTableWidth;
              final table = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border.fromBorderSide(
                          BorderSide(color: Color(0xFFE5E7EB))),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                            width: 140,
                            child: Text('Timestamp',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151)))),
                        SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: Text('Interface',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151)))),
                        SizedBox(width: 12),
                        SizedBox(
                            width: 130,
                            child: Text('Action',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151)))),
                        SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: Text('Field',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151)))),
                        SizedBox(width: 12),
                        Expanded(
                            flex: 3,
                            child: Text('Change',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151)))),
                      ],
                    ),
                  ),
                  // Log rows
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logEntries.length,
                    itemBuilder: (context, index) {
                      final entry = logEntries[index];
                      final color = _actionColor(entry.action);
                      final icon = _actionIcon(entry.action);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xFFE5E7EB)),
                            right: BorderSide(color: Color(0xFFE5E7EB)),
                            bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(_formatTimestamp(entry.changedAt),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  entry.interfaceName.trim().isNotEmpty
                                      ? entry.interfaceName.trim()
                                      : 'Unnamed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                      color.withValues(alpha: 0.12),
                                      Colors.white),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 12, color: color),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(entry.action,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: color)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  entry.fieldName.trim().isNotEmpty
                                      ? entry.fieldName.trim()
                                      : '-',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4B5563))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildChangeValue(entry, color),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
              if (!needsScroll) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minTableWidth, child: table),
              );
            },
          ),
      ],
    );
  }

  Widget _buildChangeValue(InterfaceChangeLogEntry entry, Color color) {
    if (entry.action == 'Created') {
      return Text(
          entry.newValue.trim().isNotEmpty ? entry.newValue.trim() : '-',
          style: TextStyle(fontSize: 11, color: color));
    }
    if (entry.action == 'Deleted') {
      return Text(
          entry.oldValue.trim().isNotEmpty ? entry.oldValue.trim() : '-',
          style: TextStyle(fontSize: 11, color: color));
    }
    // Updated / Status Changed / Imported
    final oldV = entry.oldValue.trim();
    final newV = entry.newValue.trim();
    if (oldV.isEmpty && newV.isEmpty) {
      return const Text('-',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        children: [
          if (oldV.isNotEmpty)
            TextSpan(
                text: oldV,
                style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Color(0xFF9CA3AF))),
          if (oldV.isNotEmpty && newV.isNotEmpty) const TextSpan(text: ' → '),
          if (newV.isNotEmpty)
            TextSpan(
                text: newV,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 5: Handoff Readiness
// ═══════════════════════════════════════════════════════════════════════════════

class _HandoffReadinessSection extends StatelessWidget {
  const _HandoffReadinessSection();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getDataListening(context);
    final entries = data.interfaceEntries;

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Add interface entries to track handoff readiness.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Handoff readiness shows which interfaces are fully prepared for transition between parties. Each checkmark indicates a key attribute is defined; gaps highlight where coordination is incomplete before work can proceed.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        // Overall readiness summary
        _buildOverallSummary(entries),
        const SizedBox(height: 20),
        // Per-interface readiness cards
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) => _HandoffCard(entry: entries[index]),
        ),
      ],
    );
  }

  Widget _buildOverallSummary(List<InterfaceEntry> entries) {
    int ready = 0;
    int partial = 0;
    int notReady = 0;
    for (final entry in entries) {
      final score = _handoffScore(entry);
      if (score >= 5) {
        ready++;
      } else if (score >= 3) {
        partial++;
      } else {
        notReady++;
      }
    }
    final cards = <Widget>[
      _ReadinessSummaryCard(
          label: 'Ready', count: ready, color: const Color(0xFF10B981)),
      _ReadinessSummaryCard(
          label: 'Partial', count: partial, color: const Color(0xFFF59E0B)),
      _ReadinessSummaryCard(
          label: 'Not Ready', count: notReady, color: const Color(0xFFEF4444)),
    ];
    // On wide screens, lay the summary cards out in a single Row with each
    // card Expanded — eliminating right-side whitespace. On narrow screens,
    // Wrap so cards reflow to multiple rows.
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardMinWidth = 160.0;
        const gap = 12.0;
        final perRow = ((constraints.maxWidth + gap) / (cardMinWidth + gap))
            .floor()
            .clamp(1, cards.length);
        if (perRow >= cards.length) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((c) => SizedBox(width: cardMinWidth, child: c))
              .toList(),
        );
      },
    );
  }

  int _handoffScore(InterfaceEntry entry) {
    int score = 0;
    if (entry.partyA.trim().isNotEmpty && entry.partyB.trim().isNotEmpty) {
      score++;
    }
    if (entry.owner.trim().isNotEmpty) score++;
    if (entry.protocol.trim().isNotEmpty) score++;
    if (entry.cadence.trim().isNotEmpty) score++;
    if (!_isOpenStatus(entry.status)) score++;
    if (entry.dataFlow.trim().isNotEmpty) score++;
    return score;
  }
}

class _HandoffCard extends StatelessWidget {
  const _HandoffCard({required this.entry});
  final InterfaceEntry entry;

  @override
  Widget build(BuildContext context) {
    final name =
        entry.boundary.trim().isNotEmpty ? entry.boundary.trim() : 'Unnamed';
    final checks = [
      (
        'Parties Defined',
        entry.partyA.trim().isNotEmpty && entry.partyB.trim().isNotEmpty
      ),
      ('Owner Assigned', entry.owner.trim().isNotEmpty),
      ('Protocol Set', entry.protocol.trim().isNotEmpty),
      ('Cadence Defined', entry.cadence.trim().isNotEmpty),
      ('Status Active', !_isOpenStatus(entry.status)),
      ('Data Flow Set', entry.dataFlow.trim().isNotEmpty),
    ];
    final passed = checks.where((c) => c.$2).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
              ),
              Text('$passed/6 Ready',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: passed >= 5
                        ? const Color(0xFF10B981)
                        : passed >= 3
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: checks.map((check) {
              final passed = check.$2;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passed
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      passed
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 14,
                      color: passed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(check.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: passed
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReadinessSummaryCard extends StatelessWidget {
  const _ReadinessSummaryCard(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SectionSubcard extends StatelessWidget {
  const _SectionSubcard({
    required this.title,
    this.subtitle = '',
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280), height: 1.3)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon}) : onTap = null;

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }
}

// ─── Badge Widgets ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return const SizedBox.shrink();

    final color = normalized.contains('active')
        ? const Color(0xFF166534)
        : normalized.contains('approved') || normalized.contains('resolved')
            ? const Color(0xFFFFC812)
            : normalized.contains('closed') || normalized.contains('complete')
                ? const Color(0xFF6B7280)
                : normalized.contains('review')
                    ? const Color(0xFF92400E)
                    : const Color(0xFF92400E); // Pending / default

    final bg = Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.trim(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    if (type.trim().isEmpty) return const SizedBox.shrink();

    final color = type.toLowerCase().contains('tech')
        ? const Color(0xFFFFC812)
        : type.toLowerCase().contains('contract')
            ? const Color(0xFFD97706)
            : type.toLowerCase().contains('org')
                ? const Color(0xFF10B981)
                : type.toLowerCase().contains('physical')
                    ? const Color(0xFFB8860B)
                    : const Color(0xFF6B7280);

    final bg = Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.trim(),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    if (priority.trim().isEmpty) return const SizedBox.shrink();

    final color = priority.toLowerCase() == 'high'
        ? const Color(0xFFEF4444)
        : priority.toLowerCase() == 'medium'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF6B7280);

    final bg = Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.trim(),
        textAlign: TextAlign.center,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _CriticalityBadge extends StatelessWidget {
  const _CriticalityBadge({required this.criticality});

  final String criticality;

  @override
  Widget build(BuildContext context) {
    final color = criticality.toLowerCase() == 'critical'
        ? const Color(0xFFEF4444)
        : criticality.toLowerCase() == 'major'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF6B7280);

    final bg = Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        criticality.trim(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Helper Functions ────────────────────────────────────────────────────────

bool _isCriticalRisk(String risk) {
  final normalized = risk.toLowerCase();
  return normalized.contains('high') ||
      normalized.contains('critical') ||
      normalized.contains('blocker') ||
      normalized.contains('severe');
}

bool _isOpenStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return !{
    'approved',
    'closed',
    'resolved',
    'done',
    'complete',
  }.contains(normalized);
}

// ─── RACI Tooltip Badge ──────────────────────────────────────────────────────

class _RaciTooltipBadge extends StatelessWidget {
  const _RaciTooltipBadge({required this.label, required this.tip});
  final String label;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Tooltip(
        message: tip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }
}

class _RiskCountChip extends StatelessWidget {
  const _RiskCountChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Health Dot Widget ────────────────────────────────────────────────────────

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.entry});
  final InterfaceEntry entry;

  @override
  Widget build(BuildContext context) {
    final health = _calculateHealth(entry);
    final color = health == 'red'
        ? const Color(0xFFEF4444)
        : health == 'green'
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B);

    return Tooltip(
      message: health == 'red'
          ? 'At Risk — critical or has blocker'
          : health == 'green'
              ? 'Healthy — approved/resolved'
              : 'In Progress — pending review',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

String _calculateHealth(InterfaceEntry entry) {
  if ((entry.criticality.toLowerCase() == 'critical' &&
          _isOpenStatus(entry.status)) ||
      _isCriticalRisk(entry.risk)) {
    return 'red';
  }
  if (['approved', 'resolved', 'closed']
      .contains(entry.status.trim().toLowerCase())) {
    return 'green';
  }
  return 'yellow';
}
