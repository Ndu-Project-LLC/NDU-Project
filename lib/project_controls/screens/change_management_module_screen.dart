/// Change Management Screen — World-class UI
///
/// Embedded in the existing sidebar/phase screen pattern via ResponsiveScaffold.
/// 8 tabs: Dashboard, Change Register, Impact & Approval Summary, Audit Trail,
/// Create CR, Impact Detail, Workflow, Implementation.
///
/// Features:
/// - Executive dashboard with KPI cards, contingency/reserve tracking,
///   7-day CR-volume sparkline, approval-cycle-time + re-baseline-quarter KPIs
/// - Change register with filter (status / priority / search) + composite-impact badge
/// - Impact assessment visualization (15 dimensions) + horizontal bar chart
/// - Approval workflow with step-by-step visualization
/// - Audit trail timeline with actor/action/date-range filters + CSV export
/// - Emergency change support
/// - Agile routine refinement vs controlled baseline change
/// - Re-baseline trigger detection
/// - CR Creation multi-section form
/// - Impact Assessment Detail interactive 15-dimension grid
/// - Approval Workflow Builder with add-step + per-step decisions + finalize
/// - Implementation & Baseline tracker with apply-to-baseline / rollback
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/project_controls/models/change_management_models.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';
import 'package:ndu_project/utils/download_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/section_navigator.dart';
import 'package:ndu_project/theme.dart';

class ChangeManagementModuleScreen extends StatefulWidget {
  const ChangeManagementModuleScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangeManagementModuleScreen()),
    );
  }

  @override
  State<ChangeManagementModuleScreen> createState() =>
      _ChangeManagementModuleScreenState();
}

class _ChangeManagementModuleScreenState extends State<ChangeManagementModuleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Currently-selected CR id (drives Impact Detail / Workflow / Implementation tabs).
  String? _selectedCRId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChangeManagementProvider>();
      // Load real data from Firestore — no phantom/demo data
      provider.loadFromFirestore();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Theme tokens are defined per-tab-widget to keep each tab self-contained.

  void _selectCR(String id) {
    setState(() => _selectedCRId = id);
  }

  void _navigateToTab(int index) {
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChangeManagementProvider>(
      builder: (context, provider, _) {
        // Resolve the currently-selected CR (fall back to first CR).
        CMChangeRequest? selectedCR;
        if (_selectedCRId != null) {
          selectedCR = provider.changeRequests
              .where((c) => c.id == _selectedCRId)
              .firstOrNull;
        }
        selectedCR ??= provider.changeRequests.firstOrNull;
        if (selectedCR != null && selectedCR.id != _selectedCRId) {
          // selected id became stale (e.g. new seed) — refresh silently.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCRId = selectedCR!.id);
          });
        }

        return ResponsiveScaffold(
          activeItemLabel: 'Change Management',
          appBarTitle: 'Change Management',
          breadcrumbPhase: 'Execution Phase',
          breadcrumbTitle: 'Change Management',
          body: Column(
            children: [
              // ── World-class Section Navigator ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'Change Management Navigation',
                  subtitle: 'Navigate between change management sections',
                  icon: Icons.sync_alt,
                  tabs: [
                    SectionTab(icon: Icons.dashboard_outlined, label: 'Dashboard'),
                    SectionTab(icon: Icons.list_alt, label: 'Change Register'),
                    SectionTab(icon: Icons.assessment_outlined, label: 'Impact & Approval Summary'),
                    SectionTab(icon: Icons.history, label: 'Audit Trail'),
                    SectionTab(icon: Icons.add_circle_outline, label: 'Create CR'),
                    SectionTab(icon: Icons.tune, label: 'Impact Detail'),
                    SectionTab(icon: Icons.account_tree_outlined, label: 'Workflow'),
                    SectionTab(icon: Icons.build_circle_outlined, label: 'Implementation'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(provider: provider),
                    _ChangeRegisterTab(
                      provider: provider,
                      selectedCRId: _selectedCRId,
                      onSelectCR: _selectCR,
                    ),
                    _ImpactApprovalSummaryTab(provider: provider),
                    _AuditTrailTab(provider: provider),
                    _CreateCRTab(
                      provider: provider,
                      onCreated: (crId) {
                        _selectCR(crId);
                        _navigateToTab(1);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Change request created'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    _ImpactDetailTab(
                      provider: provider,
                      selectedCR: selectedCR,
                      onSelectCR: _selectCR,
                    ),
                    _WorkflowTab(
                      provider: provider,
                      selectedCR: selectedCR,
                      onSelectCR: _selectCR,
                    ),
                    _ImplementationTab(
                      provider: provider,
                      selectedCR: selectedCR,
                      onSelectCR: _selectCR,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Dashboard
// ═════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final ChangeManagementProvider provider;
  const _DashboardTab({required this.provider});

  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final volume = provider.crVolumeLast7Days();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row — 7 cards in one row (desktop), wraps on tablet/mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final kpiCards = <Widget>[
                _kpiCard('Open CRs', '${provider.openCRs}', Icons.pending_actions, const Color(0xFFF59E0B)),
                _kpiCard('Pending Approval', '${provider.pendingApprovals}', Icons.assignment_late, const Color(0xFF8B5CF6)),
                _kpiCard('Approved', '${provider.approvedCRs}', Icons.check_circle, const Color(0xFF10B981)),
                _kpiCard('Emergency', '${provider.emergencyCRs}', Icons.emergency, const Color(0xFFEF4444)),
                _kpiCard('Re-baselines', '${provider.rebaselineCount}', Icons.history, const Color(0xFF6366F1)),
                _kpiCard(
                  'Approval Cycle (avg)',
                  provider.avgApprovalCycleDays == 0 ? '—' : '${provider.avgApprovalCycleDays.toStringAsFixed(1)}d',
                  Icons.timer_outlined,
                  const Color(0xFF06B6D4),
                ),
                _kpiCard(
                  'Re-baselines (Qtr)',
                  '${provider.rebaselineCountThisQuarter}',
                  Icons.event_repeat,
                  const Color(0xFFD97706),
                ),
              ];

              // Desktop: all 7 in one row using Expanded (no overflow)
              if (constraints.maxWidth > 1100) {
                return Row(
                  children: kpiCards.asMap().entries.map((entry) {
                    final i = entry.key;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < kpiCards.length - 1 ? 12 : 0),
                        child: entry.value,
                      ),
                    );
                  }).toList(),
                );
              }

              // Tablet/mobile: GridView with 4 or 2 columns
              final count = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: kpiCards,
              );
            },
          ),
          const SizedBox(height: 24),
          // 7-day CR-volume sparkline + Contingency & Reserve
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _crVolumeSparklineCard(volume)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _contingencyReserveCard()),
            ],
          ),
          const SizedBox(height: 24),
          // Impact Summary + Changes by Category
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _impactSummaryCard()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _categoryBreakdownCard()),
            ],
          ),
          const SizedBox(height: 24),
          // Recent CRs (full width)
          _recentCRsCard(),
        ],
      ),
    );
  }

  Widget _crVolumeSparklineCard(List<int> volume) {
    final total = volume.fold<int>(0, (s, v) => s + v);
    final maxV = volume.fold<int>(0, (m, v) => v > m ? v : m);
    final todayLabel = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.now().weekday - 1];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('CR VOLUME — LAST 7 DAYS', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text('$total CRs', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SparklinePainter(
              values: volume,
              color: const Color(0xFF6366F1),
              max: maxV == 0 ? 1 : maxV.toDouble(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('7 days ago', style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 10)),
          Text('today ($todayLabel)', style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Peak day', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$maxV CRs', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                child: Icon(icon, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: appFontFamily),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contingencyReserveCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CONTINGENCY & RESERVE', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        // Contingency
        _reserveBar('Contingency', provider.usedContingency, provider.totalContingency, const Color(0xFFD97706)),
        const SizedBox(height: 12),
        // Reserve
        _reserveBar('Management Reserve', provider.usedReserve, provider.totalReserve, const Color(0xFF6366F1)),
        const SizedBox(height: 16),
        // Total impact
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Cost Impact (Approved)', style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('\$${provider.totalCostImpact.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Schedule Impact (Approved)', style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${provider.totalScheduleImpact > 0 ? "+" : ""}${provider.totalScheduleImpact.round()} days', style: TextStyle(color: provider.totalScheduleImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  Widget _reserveBar(String label, double used, double total, Color color) {
    final pct = total > 0 ? used / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        Text('\$${(used / 1000).round()}K / \$${(total / 1000).round()}K', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFE4E7EC), valueColor: AlwaysStoppedAnimation(color), minHeight: 8)),
    ]);
  }

  Widget _impactSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CHANGE IMPACT SUMMARY', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        ...provider.changeRequests.take(4).map((cr) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 4, height: 32, decoration: BoxDecoration(color: cr.changeType.color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cr.title, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${cr.crNumber} • ${cr.changeType.label}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
            ])),
            if (cr.impact.totalCostImpact > 0) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('+\$${(cr.impact.totalCostImpact / 1000).round()}K', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700))),
            if (cr.impact.totalScheduleImpact != 0) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (cr.impact.totalScheduleImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('${cr.impact.totalScheduleImpact > 0 ? "+" : ""}${cr.impact.totalScheduleImpact.round()}d', style: TextStyle(color: cr.impact.totalScheduleImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cr.status.bgColor, borderRadius: BorderRadius.circular(4)), child: Text(cr.status.label, style: TextStyle(color: cr.status.color, fontSize: 9, fontWeight: FontWeight.w700))),
          ]),
        )),
      ]),
    );
  }

  Widget _recentCRsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RECENT CHANGE REQUESTS', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        ...provider.changeRequests.take(3).map((cr) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Icon(cr.changeType.icon, color: cr.changeType.color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cr.title, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${cr.crNumber} • ${cr.submittedBy} • ${cr.dateSubmitted.day}/${cr.dateSubmitted.month}/${cr.dateSubmitted.year}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cr.status.bgColor, borderRadius: BorderRadius.circular(4)), child: Text(cr.status.label, style: TextStyle(color: cr.status.color, fontSize: 9, fontWeight: FontWeight.w700))),
          ]),
        )),
      ]),
    );
  }

  Widget _categoryBreakdownCard() {
    final byType = <CMChangeType, int>{};
    for (final cr in provider.changeRequests) {
      byType[cr.changeType] = (byType[cr.changeType] ?? 0) + 1;
    }
    final sorted = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CHANGES BY CATEGORY', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        ...sorted.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(e.key.icon, color: e.key.color, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(e.key.label, style: const TextStyle(color: _textPrimary, fontSize: 12))),
            Text('${e.value}', style: TextStyle(color: e.key.color, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Change Register
// ═════════════════════════════════════════════════════════════════════════

class _ChangeRegisterTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  final String? selectedCRId;
  final ValueChanged<String> onSelectCR;
  const _ChangeRegisterTab({
    required this.provider,
    required this.selectedCRId,
    required this.onSelectCR,
  });

  @override
  State<_ChangeRegisterTab> createState() => _ChangeRegisterTabState();
}

class _ChangeRegisterTabState extends State<_ChangeRegisterTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  // Filter state — uses sentinel values for "All".
  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  final _searchCtrl = TextEditingController();
  bool _isTableView = false; // false = card view, true = table view

  static const _statusOptions = ['All', 'Draft', 'Submitted', 'Pending Approval', 'Approved', 'Rejected', 'Implemented', 'Closed'];
  static const _priorityOptions = ['All', 'Low', 'Medium', 'High', 'Critical', 'Emergency'];

  CMStatus? _statusFromString(String s) {
    switch (s) {
      case 'Draft': return CMStatus.draft;
      case 'Submitted': return CMStatus.submitted;
      case 'Pending Approval': return CMStatus.pendingApproval;
      case 'Approved': return CMStatus.approved;
      case 'Rejected': return CMStatus.rejected;
      case 'Implemented': return CMStatus.implemented;
      case 'Closed': return CMStatus.closed;
    }
    return null;
  }

  CMPriority? _priorityFromString(String s) {
    switch (s) {
      case 'Low': return CMPriority.low;
      case 'Medium': return CMPriority.medium;
      case 'High': return CMPriority.high;
      case 'Critical': return CMPriority.critical;
      case 'Emergency': return CMPriority.emergency;
    }
    return null;
  }

  List<CMChangeRequest> get _filtered {
    final status = _statusFromString(_statusFilter);
    final priority = _priorityFromString(_priorityFilter);
    final q = _searchCtrl.text.trim().toLowerCase();
    return widget.provider.changeRequests.where((cr) {
      if (status != null && cr.status != status) return false;
      if (priority != null && cr.priority != priority) return false;
      if (q.isNotEmpty) {
        final haystack = '${cr.crNumber} ${cr.title} ${cr.description} ${cr.submittedBy}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Change Register', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            Row(
              children: [
                // View toggle: Card / Table
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      _viewToggleBtn(Icons.view_agenda_outlined, !_isTableView, () => setState(() => _isTableView = false), 'Card view'),
                      _viewToggleBtn(Icons.table_chart_outlined, _isTableView, () => setState(() => _isTableView = true), 'Table view'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showNewCRDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Quick CR'),
                  style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: _textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 4),
          Text('${widget.provider.changeRequests.length} total • ${filtered.length} shown • ${widget.provider.openCRs} open • ${widget.provider.approvedCRs} approved', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // Filter row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FILTERS', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              // Responsive: 3 columns on wide screens, stacked on narrow.
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 720;
                final children = <Widget>[
                  _filterDropdown('Status', _statusFilter, _statusOptions, (v) => setState(() => _statusFilter = v!)),
                  const SizedBox(width: 12),
                  _filterDropdown('Priority', _priorityFilter, _priorityOptions, (v) => setState(() => _priorityFilter = v!)),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _searchField()),
                ];
                if (wide) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.end, children: children);
                }
                return Column(children: [
                  children[0], const SizedBox(height: 8), children[2], const SizedBox(height: 8), children[4],
                ]);
              }),
              if (_statusFilter != 'All' || _priorityFilter != 'All' || _searchCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(
                  onPressed: () => setState(() {
                    _statusFilter = 'All';
                    _priorityFilter = 'All';
                    _searchCtrl.clear();
                  }),
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Clear filters'),
                )),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
              child: Center(child: Column(children: [
                const Icon(Icons.search_off, color: _textSecondary, size: 36),
                const SizedBox(height: 12),
                const Text('No change requests match your filters', style: TextStyle(color: _textSecondary, fontSize: 13)),
              ])),
            )
          else if (_isTableView)
            _buildTableView(filtered)
          else
            ...filtered.map((cr) => _changeRequestCard(cr, context)),
        ],
      ),
    );
  }

  Widget _viewToggleBtn(IconData icon, bool isActive, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? LightModeColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: isActive ? _textPrimary : _textSecondary),
        ),
      ),
    );
  }

  Widget _buildTableView(List<CMChangeRequest> crs) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FB)),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? LightModeColors.accent.withValues(alpha: 0.08) : null;
          }),
          columns: const [
            DataColumn(label: Text('CR #', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Title', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Type', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Priority', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Status', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Score', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Cost Impact', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Schedule', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Originator', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Date', style: TextStyle(color: Color(0xFF475467), fontSize: 12, fontWeight: FontWeight.w700))),
          ],
          rows: crs.map((cr) {
            final isSelected = cr.id == widget.selectedCRId;
            return DataRow(
              selected: isSelected,
              onSelectChanged: (_) => widget.onSelectCR(cr.id),
              cells: [
                DataCell(Text(cr.id, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(cr.title, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(cr.changeType.label, style: const TextStyle(color: _textSecondary, fontSize: 12))),
                DataCell(_priorityBadge(cr.priority)),
                DataCell(_statusBadge(cr.status)),
                DataCell(Text(cr.impact.compositeImpactScore.toStringAsFixed(2), style: TextStyle(color: _scoreColor(cr.impact.compositeImpactScore), fontSize: 12, fontWeight: FontWeight.w700))),
                DataCell(Text('\$${cr.impact.totalCostImpact.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(Text('${cr.impact.totalScheduleImpact > 0 ? "+" : ""}${cr.impact.totalScheduleImpact.toStringAsFixed(0)}d', style: TextStyle(color: cr.impact.totalScheduleImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(Text(cr.submittedBy, style: const TextStyle(color: _textSecondary, fontSize: 12))),
                DataCell(Text(_formatDate(cr.dateSubmitted), style: const TextStyle(color: _textSecondary, fontSize: 12))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 4.0) return const Color(0xFFEF4444);
    if (score >= 3.0) return const Color(0xFFF59E0B);
    if (score >= 2.0) return const Color(0xFF10B981);
    return const Color(0xFF6B7280);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _priorityBadge(CMPriority p) {
    final colors = <CMPriority, Color>{
      CMPriority.low: const Color(0xFF6B7280),
      CMPriority.medium: const Color(0xFF3B82F6),
      CMPriority.high: const Color(0xFFF59E0B),
      CMPriority.critical: const Color(0xFFEF4444),
      CMPriority.emergency: const Color(0xFFDC2626),
    };
    final color = colors[p] ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(p.name[0].toUpperCase() + p.name.substring(1), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(CMStatus s) {
    final colors = <CMStatus, Color>{
      CMStatus.draft: const Color(0xFF6B7280),
      CMStatus.submitted: const Color(0xFF3B82F6),
      CMStatus.underReview: const Color(0xFF8B5CF6),
      CMStatus.pendingApproval: const Color(0xFFF59E0B),
      CMStatus.approved: const Color(0xFF10B981),
      CMStatus.rejected: const Color(0xFFEF4444),
      CMStatus.implemented: const Color(0xFF06B6D4),
      CMStatus.closed: const Color(0xFF64748B),
    };
    final color = colors[s] ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(s.name[0].toUpperCase() + s.name.substring(1), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _filterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
              style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _searchField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Search', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'CR number, title, originator…',
          hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 16, color: _textSecondary),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
        ),
        style: const TextStyle(color: _textPrimary, fontSize: 12),
      ),
    ]);
  }

  Widget _changeRequestCard(CMChangeRequest cr, BuildContext context) {
    final isSelected = widget.selectedCRId == cr.id;
    final composite = cr.impact.compositeImpactScore;
    final compositeColor = composite >= 3.5 ? const Color(0xFFEF4444) : (composite >= 2 ? const Color(0xFFF59E0B) : (composite > 0 ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? LightModeColors.accent : cr.status.color.withValues(alpha: 0.3), width: isSelected ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cr.status.bgColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: cr.changeType.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(cr.changeType.icon, color: cr.changeType.color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cr.title, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${cr.crNumber} • ${cr.changeType.label} • ${cr.priority.label} Priority', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ])),
            // Composite impact score badge
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: compositeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: compositeColor.withValues(alpha: 0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('COMPOSITE', style: TextStyle(color: Color(0xFF6B7280), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                Text(composite.toStringAsFixed(2), style: TextStyle(color: compositeColor, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (cr.isEmergency) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)), child: const Text('EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
            if (cr.isAgileRoutineRefinement) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: const Text('AGILE', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 9, fontWeight: FontWeight.w700))),
            Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: cr.status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text(cr.status.label, style: TextStyle(color: cr.status.color, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Description
            Text(cr.description, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            // Justification
            Text('Justification: ${cr.businessJustification}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
            if (cr.rootCause != null) ...[const SizedBox(height: 4), Text('Root Cause: ${cr.rootCause}', style: const TextStyle(color: _textSecondary, fontSize: 12))],
            const SizedBox(height: 12),
            // Impact chips
            if (cr.impact.impactedCount > 0) ...[
              const Text('IMPACT ANALYSIS', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: _buildImpactChips(cr)),
            ],
            const SizedBox(height: 12),
            // Approval workflow
            if (cr.approvalSteps.isNotEmpty) ...[
              const Text('APPROVAL WORKFLOW', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: cr.approvalSteps.map((step) {
                final idx = cr.approvalSteps.indexOf(step);
                final isCurrent = idx == cr.currentStepIndex;
                return Expanded(child: Row(children: [
                  if (idx > 0) Container(width: 8, height: 2, color: step.decision == ApprovalDecision.approved ? const Color(0xFF10B981) : const Color(0xFFE4E7EC)),
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: step.decision == ApprovalDecision.approved ? const Color(0xFF10B981) : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFFE4E7EC)), shape: BoxShape.circle, border: Border.all(color: step.decision == ApprovalDecision.approved ? const Color(0xFF10B981) : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFFE4E7EC)), width: 2)), child: step.decision == ApprovalDecision.approved ? const Icon(Icons.check, color: Colors.white, size: 14) : (isCurrent ? const Icon(Icons.hourglass_top, color: Colors.white, size: 12) : null)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(step.roleLabel, style: TextStyle(color: step.decision == ApprovalDecision.approved ? const Color(0xFF10B981) : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF)), fontSize: 10, fontWeight: step.decision == ApprovalDecision.approved || isCurrent ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                ]));
              }).toList()),
            ],
            // Select + action buttons
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () => widget.onSelectCR(cr.id),
                icon: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, size: 14),
                label: Text(isSelected ? 'Selected' : 'Select for detail tabs'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isSelected ? const Color(0xFFD97706) : _textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  side: BorderSide(color: isSelected ? LightModeColors.accent : _surfaceBorder),
                ),
              ),
              const Spacer(),
              if (cr.status == CMStatus.underReview || cr.status == CMStatus.pendingApproval) ...[
                ElevatedButton(onPressed: () => widget.provider.approveStep(cr.id), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: Text('Approve as ${cr.currentStepIndex < cr.approvalSteps.length ? cr.approvalSteps[cr.currentStepIndex].roleLabel : "N/A"}')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => widget.provider.rejectCR(cr.id, reason: 'Rejected from UI'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Reject')),
              ],
              if (cr.status == CMStatus.approved) ...[
                ElevatedButton(onPressed: () => widget.provider.implementCR(cr.id, notes: 'Implemented from UI'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Implement Change')),
              ],
            ]),
            // Re-baseline warning
            if (cr.triggersRebaseline) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2))), child: Row(children: [
                const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('This change triggers a re-baseline. Affected: ${cr.affectedBaselines.join(", ")}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11))),
              ])),
            ],
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buildImpactChips(CMChangeRequest cr) {
    final chips = <Widget>[];
    for (final d in cr.impact.all) {
      if (!d.hasImpact) continue;
      final color = d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
      final labelParts = <String>[];
      if (d.scheduleDays != null && d.scheduleDays != 0) labelParts.add('${d.scheduleDays! > 0 ? "+" : ""}${d.scheduleDays!.round()}d');
      if (d.costAmount != null && d.costAmount != 0) labelParts.add('\$${(d.costAmount! / 1000).round()}K');
      if (d.impactLevel > 0) labelParts.add('L${d.impactLevel}');
      if (d.impact != null) labelParts.add(d.impact!.length > 30 ? '${d.impact!.substring(0, 30)}...' : d.impact!);
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
          Text(labelParts.join(' • '), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ));
    }
    return chips;
  }

  void _showNewCRDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final justCtrl = TextEditingController();
    var type = CMChangeType.scope;
    var priority = CMPriority.medium;
    var isEmergency = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Quick Change Request',
              style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title'), style: const TextStyle(color: Color(0xFF1A1D1F))),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description'), style: const TextStyle(color: Color(0xFF1A1D1F))),
                const SizedBox(height: 12),
                TextField(controller: justCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Business Justification'), style: const TextStyle(color: Color(0xFF1A1D1F))),
                const SizedBox(height: 12),
                DropdownButtonFormField<CMChangeType>(value: type, decoration: const InputDecoration(labelText: 'Change Type'), items: CMChangeType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(), onChanged: (v) => setState(() => type = v!)),
                const SizedBox(height: 8),
                DropdownButtonFormField<CMPriority>(value: priority, decoration: const InputDecoration(labelText: 'Priority'), items: CMPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(), onChanged: (v) => setState(() => priority = v!)),
                const SizedBox(height: 8),
                CheckboxListTile(value: isEmergency, onChanged: (v) => setState(() => isEmergency = v ?? false), title: const Text('Emergency Change', style: TextStyle(fontSize: 13)), dense: true, activeColor: LightModeColors.accent, contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  final crId = context.read<ChangeManagementProvider>().createChangeRequest(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    changeType: type,
                    priority: priority,
                    businessJustification: justCtrl.text.trim(),
                    isEmergency: isEmergency,
                  );
                  Navigator.pop(ctx);
                  widget.onSelectCR(crId);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: const Color(0xFF1A1D1F)),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Impact & Approval Summary (read-only overview; per-dimension editing
// is on the dedicated Impact Detail tab)
// ═════════════════════════════════════════════════════════════════════════

class _ImpactApprovalSummaryTab extends StatelessWidget {
  final ChangeManagementProvider provider;
  const _ImpactApprovalSummaryTab({required this.provider});

  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final crsWithImpact = provider.changeRequests.where((cr) =>
        cr.impact.impactedCount > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Impact & Approval Summary', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${crsWithImpact.length} change requests with impact assessments • read-only aggregation', style: const TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        // Aggregate composite score overview
        _aggregateCard(crsWithImpact),
        const SizedBox(height: 20),
        ...crsWithImpact.map((cr) => _impactApprovalCard(cr)),
      ]),
    );
  }

  Widget _aggregateCard(List<CMChangeRequest> crs) {
    if (crs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
        child: const Center(child: Text('No impact assessments recorded yet.', style: TextStyle(color: _textSecondary, fontSize: 13))),
      );
    }
    // Aggregate per-dimension max impact level across all CRs for the bar chart.
    final dims = crs.first.impact.all;
    final aggregateLevels = List<int>.filled(dims.length, 0);
    for (final cr in crs) {
      final all = cr.impact.all;
      for (var i = 0; i < all.length && i < aggregateLevels.length; i++) {
        if (all[i].impactLevel > aggregateLevels[i]) aggregateLevels[i] = all[i].impactLevel;
      }
    }
    final avgComposite = crs.map((c) => c.impact.compositeImpactScore).fold<double>(0, (s, v) => s + v) / crs.length;
    final maxDimIdx = aggregateLevels.indexOf(aggregateLevels.reduce((a, b) => a > b ? a : b));
    final maxDimName = dims[maxDimIdx].name;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('PER-DIMENSION IMPACT (MAX ACROSS ALL CRs)', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text('Avg composite ${avgComposite.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 360,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ImpactBarChartPainter(
              dimensionNames: dims.map((d) => d.name).toList(),
              levels: aggregateLevels,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Highest-impact dimension', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$maxDimName (L${aggregateLevels[maxDimIdx]})', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  Widget _impactApprovalCard(CMChangeRequest cr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cr.changeType.color.withValues(alpha: 0.05), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))), child: Row(children: [
          Icon(cr.changeType.icon, color: cr.changeType.color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cr.title, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${cr.crNumber} - ${cr.changeType.label}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
          ])),
          // Composite badge
          Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('COMPOSITE', style: TextStyle(color: Color(0xFF6B7280), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text(cr.impact.compositeImpactScore.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w800)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: cr.status.bgColor, borderRadius: BorderRadius.circular(6)), child: Text(cr.status.label, style: TextStyle(color: cr.status.color, fontSize: 10, fontWeight: FontWeight.w700))),
        ])),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('IMPACT ASSESSMENT (15 DIMENSIONS)', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 12),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.5, children: cr.impact.all.map((d) {
            final hasImpact = d.hasImpact;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: hasImpact ? (d.isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.06) : const Color(0xFF6366F1).withValues(alpha: 0.04)) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6), border: Border.all(color: hasImpact ? (d.isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.15)) : _surfaceBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(d.name, style: TextStyle(color: hasImpact ? (d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1)) : _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
                  if (d.impactLevel > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: (d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)), child: Text('L${d.impactLevel}', style: TextStyle(color: d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1), fontSize: 8, fontWeight: FontWeight.w800))),
                ]),
                if (hasImpact) ...[
                  if (d.scheduleDays != null && d.scheduleDays != 0) Text('${d.scheduleDays! > 0 ? "+" : ""}${d.scheduleDays!.round()} days', style: TextStyle(color: d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.w700)),
                  if (d.costAmount != null && d.costAmount != 0) Text('\$${(d.costAmount! / 1000).round()}K', style: TextStyle(color: d.isCritical ? const Color(0xFFEF4444) : const Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.w700)),
                  if (d.impact != null) Text(d.impact!, style: const TextStyle(color: _textSecondary, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                ] else Text('No impact', style: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 9)),
              ]),
            );
          }).toList()),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _totalChip('Schedule', '${cr.impact.totalScheduleImpact > 0 ? "+" : ""}${cr.impact.totalScheduleImpact.round()}d', cr.impact.totalScheduleImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
            _totalChip('Cost', '\$${(cr.impact.totalCostImpact / 1000).round()}K', cr.impact.totalCostImpact > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
            _totalChip('Dimensions', '${cr.impact.impactedCount}/${cr.impact.all.length}', const Color(0xFF6366F1)),
            _totalChip('Composite', cr.impact.compositeImpactScore.toStringAsFixed(2), const Color(0xFFD97706)),
          ])),
        ])),
      ]),
    );
  }

  Widget _totalChip(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Audit Trail
// ═════════════════════════════════════════════════════════════════════════

class _AuditTrailTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  const _AuditTrailTab({required this.provider});

  @override
  State<_AuditTrailTab> createState() => _AuditTrailTabState();
}

class _AuditTrailTabState extends State<_AuditTrailTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  String _actorFilter = 'All';
  String _actionFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  List<String> get _actorOptions {
    final set = <String>{};
    for (final e in widget.provider.auditTrail) {
      set.add(e.user);
    }
    return ['All', ...set.toList()..sort()];
  }

  List<String> get _actionOptions {
    final set = <String>{};
    for (final e in widget.provider.auditTrail) {
      set.add(e.action);
    }
    return ['All', ...set.toList()..sort()];
  }

  List<CMAuditEntry> get _filtered {
    return widget.provider.auditTrail.where((e) {
      if (_actorFilter != 'All' && e.user != _actorFilter) return false;
      if (_actionFilter != 'All' && e.action != _actionFilter) return false;
      if (_fromDate != null && e.timestamp.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) return false;
      if (_toDate != null) {
        final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
        if (e.timestamp.isAfter(end)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _pickDate(BuildContext ctx, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now.subtract(const Duration(days: 30))) : (_toDate ?? now);
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _exportCsv() {
    final entries = _filtered;
    final buf = StringBuffer();
    buf.writeln('id,user,timestamp,action,details,linkedCRId,baselineVersion');
    for (final e in entries) {
      final ts = e.timestamp.toIso8601String();
      final user = _csvEscape(e.user);
      final action = _csvEscape(e.action);
      final details = _csvEscape(e.details ?? '');
      final crId = _csvEscape(e.linkedCRId ?? '');
      final bv = _csvEscape(e.baselineVersion ?? '');
      buf.writeln('${e.id},$user,$ts,$action,$details,$crId,$bv');
    }
    final bytes = Uint8List.fromList(utf8.encode(buf.toString()));
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    downloadFile(bytes, 'cm_audit_trail_$stamp.csv', mimeType: 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${entries.length} audit entries to CSV'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Audit Trail', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${widget.provider.auditTrail.length} total • ${filtered.length} shown • Immutable record', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ])),
          ElevatedButton.icon(
            onPressed: filtered.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        const SizedBox(height: 16),
        // Filter card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FILTERS', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 720;
              final actorDropdown = _filterDropdown('Actor', _actorFilter, _actorOptions, (v) => setState(() => _actorFilter = v!));
              final actionDropdown = _filterDropdown('Action Type', _actionFilter, _actionOptions, (v) => setState(() => _actionFilter = v!));
              final fromBtn = _dateButton('From', _fromDate, () => _pickDate(context, true));
              final toBtn = _dateButton('To', _toDate, () => _pickDate(context, false));
              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: actorDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: actionDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: fromBtn),
                  const SizedBox(width: 12),
                  Expanded(child: toBtn),
                ]);
              }
              return Column(children: [
                Row(children: [Expanded(child: actorDropdown), const SizedBox(width: 12), Expanded(child: actionDropdown)]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: fromBtn), const SizedBox(width: 12), Expanded(child: toBtn)]),
              ]);
            }),
            if (_actorFilter != 'All' || _actionFilter != 'All' || _fromDate != null || _toDate != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: () => setState(() {
                  _actorFilter = 'All';
                  _actionFilter = 'All';
                  _fromDate = null;
                  _toDate = null;
                }),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear filters'),
              )),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        if (widget.provider.baselineHistory.isNotEmpty) ...[
          const Text('BASELINE REVISION HISTORY', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...widget.provider.baselineHistory.reversed.map((rev) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2))),
            child: Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: const Center(child: Text('v', style: TextStyle(color: Color(0xFF6366F1), fontSize: 14, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Baseline v${rev.version} - ${rev.reason}', style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('By ${rev.revisedBy} • ${rev.revisionDate.day}/${rev.revisionDate.month}/${rev.revisionDate.year}${rev.approver != null ? " • Approver: ${rev.approver}" : ""}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
                if (rev.previousBudget != null && rev.revisedBudget != null) Text('BAC \$${rev.previousBudget!.toStringAsFixed(0)} → \$${rev.revisedBudget!.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700)),
                if (rev.previousScopeHash != null && rev.revisedScopeHash != null) Text('Scope ${_shortHash(rev.previousScopeHash)} → ${_shortHash(rev.revisedScopeHash)}', style: const TextStyle(color: _textSecondary, fontSize: 9)),
              ])),
            ]),
          )),
          const SizedBox(height: 24),
        ],
        const Text('ACTIVITY LOG', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
            child: Center(child: Column(children: [
              const Icon(Icons.filter_alt_off, color: _textSecondary, size: 32),
              const SizedBox(height: 12),
              const Text('No audit entries match your filters', style: TextStyle(color: _textSecondary, fontSize: 13)),
            ])),
          )
        else
          ...filtered.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(entry.action, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(_formatTimestamp(entry.timestamp), style: const TextStyle(color: _textSecondary, fontSize: 10)),
                  ]),
                  if (entry.details != null) ...[const SizedBox(height: 4), Text(entry.details!, style: const TextStyle(color: _textSecondary, fontSize: 11))],
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline, size: 10, color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(entry.user, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                    if (entry.linkedCRId != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.link, size: 10, color: _textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('linked CR', style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 10)),
                    ],
                  ]),
                ]),
              )),
            ]),
          )),
      ]),
    );
  }

  String _formatTimestamp(DateTime t) {
    return '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _shortHash(String? hash) {
    if (hash == null) return '—';
    if (hash.length <= 14) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';
  }

  Widget _filterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
            style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: _textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              value == null ? 'Any date' : '${value.day}/${value.month}/${value.year}',
              style: TextStyle(color: value == null ? _textSecondary.withValues(alpha: 0.5) : _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            )),
            if (value != null) GestureDetector(
              onTap: () => setState(() {
                if (label == 'From') {
                  _fromDate = null;
                } else {
                  _toDate = null;
                }
              }),
              child: const Icon(Icons.clear, size: 14, color: _textSecondary),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Create CR — multi-section form (5 sections A-E)
// ═════════════════════════════════════════════════════════════════════════

/// Static WBS list for the Scope Impact multi-select. In production this
/// would come from the project controls provider, but to avoid cross-module
/// coupling we surface a representative WBS drawn from the project's plan.
const List<String> _kWbsOptions = [
  'WP-1.1 Mobilization',
  'WP-1.2 Site Prep',
  'WP-2.1 Structural Steel',
  'WP-2.2 Enclosure',
  'WP-3.3 Electrical Rough-In',
  'WP-3.4 Mechanical Rough-In',
  'WP-4.2 HVAC',
  'WP-4.3 Controls',
  'WP-5.1 Commissioning',
  'WP-6.1 Closeout',
];

class _CreateCRTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  final ValueChanged<String> onCreated;
  const _CreateCRTab({required this.provider, required this.onCreated});

  @override
  State<_CreateCRTab> createState() => _CreateCRTabState();
}

class _CreateCRTabState extends State<_CreateCRTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;
  static const _bgColor = Color(0xFFF9FAFB);

  // Section A — Identification
  final _titleCtrl = TextEditingController();
  final _originatorCtrl = TextEditingController();
  DateTime _dateRaised = DateTime.now();
  CMChangeType _type = CMChangeType.scope;
  CMPriority _priority = CMPriority.medium;
  bool _isEmergency = false;

  // Section B — Description
  final _descCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  final _altCtrl = TextEditingController();

  // Section C — Scope Impact
  final Set<String> _selectedWbs = {};
  final _addedCtrl = TextEditingController(text: '0');
  final _modifiedCtrl = TextEditingController(text: '0');
  final _removedCtrl = TextEditingController(text: '0');

  // Section D — Cost & Schedule
  final _costCtrl = TextEditingController();
  final _schedCtrl = TextEditingController();
  final _contingencyCtrl = TextEditingController();
  final _reserveCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_titleCtrl, _originatorCtrl, _descCtrl, _justCtrl, _altCtrl, _addedCtrl, _modifiedCtrl, _removedCtrl, _costCtrl, _schedCtrl, _contingencyCtrl, _reserveCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid => _titleCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().isNotEmpty && _justCtrl.text.trim().isNotEmpty;

  Future<void> _pickDateRaised() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateRaised,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dateRaised = picked);
  }

  void _submit() {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title, description and justification.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    final sched = int.tryParse(_schedCtrl.text.trim()) ?? 0;
    final cont = double.tryParse(_contingencyCtrl.text.trim()) ?? 0;
    final res = double.tryParse(_reserveCtrl.text.trim()) ?? 0;
    final added = int.tryParse(_addedCtrl.text.trim()) ?? 0;
    final modified = int.tryParse(_modifiedCtrl.text.trim()) ?? 0;
    final removed = int.tryParse(_removedCtrl.text.trim()) ?? 0;
    final crId = widget.provider.createChangeRequest(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      changeType: _type,
      priority: _priority,
      businessJustification: _justCtrl.text.trim(),
      alternativesConsidered: _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      submittedBy: _originatorCtrl.text.trim().isEmpty ? null : _originatorCtrl.text.trim(),
      dateSubmitted: _dateRaised,
      isEmergency: _isEmergency,
      affectedWorkPackages: _selectedWbs.toList(),
      deliverablesAdded: added,
      deliverablesModified: modified,
      deliverablesRemoved: removed,
      initialCostEstimate: cost,
      scheduleDaysImpact: sched,
      contingencyDrawdownRequested: cont,
      reserveDrawdownRequested: res,
    );
    widget.onCreated(crId);
    // Reset form for next entry.
    setState(() {
      _titleCtrl.clear();
      _originatorCtrl.clear();
      _descCtrl.clear();
      _justCtrl.clear();
      _altCtrl.clear();
      _costCtrl.clear();
      _schedCtrl.clear();
      _contingencyCtrl.clear();
      _reserveCtrl.clear();
      _addedCtrl.text = '0';
      _modifiedCtrl.text = '0';
      _removedCtrl.text = '0';
      _selectedWbs.clear();
      _type = CMChangeType.scope;
      _priority = CMPriority.medium;
      _isEmergency = false;
      _dateRaised = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auto-generated CR number preview (provider increments internally on submit).
    final year = DateTime.now().year;
    final previewCrNumber = 'CR-$year-${(widget.provider.changeRequests.length + 1).toString().padLeft(3, '0')}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Create Change Request', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Submit a new CR with identification, scope, cost & schedule impact, and supporting documents.', style: TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        // SECTION A — IDENTIFICATION
        _sectionCard(
          'A',
          'Identification',
          Icons.badge_outlined,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _readOnlyField('CR Number (auto)', previewCrNumber)),
              const SizedBox(width: 12),
              Expanded(child: _readOnlyField('Status (auto)', _isEmergency ? 'Emergency' : 'Submitted')),
            ]),
            const SizedBox(height: 12),
            _textField('Title *', _titleCtrl, 'e.g. Add Fire Suppression System'),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _textField('Originator', _originatorCtrl, 'Name & role')),
              const SizedBox(width: 12),
              Expanded(child: _dateField('Date Raised', _dateRaised, _pickDateRaised)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _dropdownField<CMChangeType>('Change Type', _type, CMChangeType.values, (t) => t.label, (v) => setState(() => _type = v!))),
              const SizedBox(width: 12),
              Expanded(child: _dropdownField<CMPriority>('Priority', _priority, CMPriority.values, (p) => p.label, (v) => setState(() => _priority = v!))),
            ]),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isEmergency,
              onChanged: (v) => setState(() => _isEmergency = v ?? false),
              title: const Text('Emergency Change', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Emergency changes bypass standard workflow and require sponsor sign-off within 24h.', style: TextStyle(fontSize: 11, color: _textSecondary)),
              dense: true,
              activeColor: LightModeColors.accent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // SECTION B — DESCRIPTION
        _sectionCard(
          'B',
          'Description',
          Icons.description_outlined,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _textField('Rich Description *', _descCtrl, 'Detailed description of the requested change', maxLines: 4),
            const SizedBox(height: 12),
            _textField('Business Justification *', _justCtrl, 'Why this change is needed and the cost of inaction', maxLines: 3),
            const SizedBox(height: 12),
            _textField('Alternatives Considered', _altCtrl, 'Other options evaluated and why they were rejected', maxLines: 3),
          ]),
        ),
        const SizedBox(height: 16),
        // SECTION C — SCOPE IMPACT
        _sectionCard(
          'C',
          'Scope Impact',
          Icons.account_tree_outlined,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AFFECTED WORK PACKAGES (multi-select)', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _kWbsOptions.map((w) {
              final selected = _selectedWbs.contains(w);
              return FilterChip(
                label: Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : _textPrimary)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedWbs.add(w);
                  } else {
                    _selectedWbs.remove(w);
                  }
                }),
                selectedColor: LightModeColors.accent,
                checkmarkColor: _textPrimary,
                backgroundColor: _bgColor,
                side: const BorderSide(color: _surfaceBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              );
            }).toList()),
            if (_selectedWbs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${_selectedWbs.length} work package(s) selected', style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            const Text('DELIVERABLES IMPACT', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numberField('Added', _addedCtrl, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _numberField('Modified', _modifiedCtrl, const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              Expanded(child: _numberField('Removed', _removedCtrl, const Color(0xFFEF4444))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // SECTION D — COST & SCHEDULE IMPACT
        _sectionCard(
          'D',
          'Cost & Schedule Impact',
          Icons.attach_money,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _currencyField('Initial Cost Estimate (\$)', _costCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numberField('Schedule Days Impact', _schedCtrl, const Color(0xFF8B5CF6), allowNegative: true)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _currencyField('Contingency Drawdown (\$)', _contingencyCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _currencyField('Reserve Drawdown (\$)', _reserveCtrl)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Contingency: \$${widget.provider.remainingContingency.toStringAsFixed(0)} available • Reserve: \$${widget.provider.remainingReserve.toStringAsFixed(0)} available', style: const TextStyle(color: _textSecondary, fontSize: 11))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // SECTION E — DOCUMENTS (placeholder upload zone)
        _sectionCard(
          'E',
          'Documents',
          Icons.upload_file,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document upload — wire to your file picker integration.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _surfaceBorder, style: BorderStyle.solid),
                ),
                child: Column(children: [
                  const Icon(Icons.upload_file, size: 36, color: Color(0xFF6366F1)),
                  const SizedBox(height: 8),
                  const Text('Drop supporting documents here or click to upload', style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Drawings, cost estimates, vendor quotes, RFIs — PDF, DOCX, XLSX up to 25 MB', style: TextStyle(color: _textSecondary.withValues(alpha: 0.8), fontSize: 10)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        // Submit
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(
            onPressed: () => setState(() {
              for (final c in [_titleCtrl, _originatorCtrl, _descCtrl, _justCtrl, _altCtrl, _costCtrl, _schedCtrl, _contingencyCtrl, _reserveCtrl]) {
                c.clear();
              }
              _addedCtrl.text = '0';
              _modifiedCtrl.text = '0';
              _removedCtrl.text = '0';
              _selectedWbs.clear();
              _type = CMChangeType.scope;
              _priority = CMPriority.medium;
              _isEmergency = false;
              _dateRaised = DateTime.now();
            }),
            style: OutlinedButton.styleFrom(foregroundColor: _textSecondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Reset form'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isValid ? _submit : null,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Submit Change Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              foregroundColor: _textPrimary,
              disabledBackgroundColor: const Color(0xFFE4E7EC),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionCard(String letter, String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: LightModeColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(letter, style: const TextStyle(color: Color(0xFFD97706), fontSize: 14, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 12),
          Icon(icon, color: const Color(0xFF6366F1), size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const Divider(color: _surfaceBorder, height: 24),
        child,
      ]),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: _bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
        ),
        style: const TextStyle(color: _textPrimary, fontSize: 12),
      ),
    ]);
  }

  Widget _readOnlyField(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
        child: Text(value, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: _textSecondary),
            const SizedBox(width: 8),
            Text('${value.day}/${value.month}/${value.year}', style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _dropdownField<T>(String label, T value, List<T> options, String Function(T) labelOf, ValueChanged<T?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
            style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(labelOf(o), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }

  Widget _numberField(String label, TextEditingController ctrl, Color color, {bool allowNegative = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: _bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          prefixIcon: allowNegative ? Icon(Icons.remove_circle_outline, size: 14, color: color.withValues(alpha: 0.5)) : null,
        ),
        style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ]);
  }

  Widget _currencyField(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: _bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceBorder)),
          prefixIcon: const Icon(Icons.attach_money, size: 14, color: Color(0xFF6B7280)),
        ),
        style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Impact Detail — interactive 15-dimension grid for the selected CR
// ═════════════════════════════════════════════════════════════════════════

class _ImpactDetailTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  final CMChangeRequest? selectedCR;
  final ValueChanged<String> onSelectCR;
  const _ImpactDetailTab({
    required this.provider,
    required this.selectedCR,
    required this.onSelectCR,
  });

  @override
  State<_ImpactDetailTab> createState() => _ImpactDetailTabState();
}

class _ImpactDetailTabState extends State<_ImpactDetailTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;
  static const _bgColor = Color(0xFFF9FAFB);

  FullImpactAssessment? _draft;
  String? _draftCRId;
  bool _showComposite = false;

  // Per-dimension text controllers (keyed by dimension index).
  final Map<int, TextEditingController> _narrativeCtrls = {};
  final Map<int, TextEditingController> _ownerCtrls = {};
  final Map<int, DateTime?> _dueDates = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDraft();
  }

  void _syncDraft() {
    final cr = widget.selectedCR;
    if (cr == null) {
      _draft = null;
      _draftCRId = null;
      return;
    }
    if (_draftCRId != cr.id) {
      // New CR selected — initialize draft from the CR's current impact.
      _draft = cr.impact;
      _draftCRId = cr.id;
      _showComposite = false;
      // Dispose old controllers and rebuild for the new dimensions.
      for (final c in _narrativeCtrls.values) {
        c.dispose();
      }
      for (final c in _ownerCtrls.values) {
        c.dispose();
      }
      _narrativeCtrls.clear();
      _ownerCtrls.clear();
      _dueDates.clear();
      for (var i = 0; i < cr.impact.all.length; i++) {
        _narrativeCtrls[i] = TextEditingController(text: cr.impact.all[i].narrative ?? '');
        _ownerCtrls[i] = TextEditingController(text: cr.impact.all[i].owner ?? '');
        _dueDates[i] = cr.impact.all[i].dueDate;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _narrativeCtrls.values) {
      c.dispose();
    }
    for (final c in _ownerCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setLevel(int index, int level) {
    final dims = _draft!.all.toList();
    dims[index] = dims[index].copyWith(impactLevel: level);
    setState(() => _draft = _draft!.updateDimension(index, dims[index]));
  }

  Future<void> _pickDueDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDates[index] ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDates[index] = picked);
    }
  }

  void _save() {
    final cr = widget.selectedCR;
    final draft = _draft;
    if (cr == null || draft == null) return;
    // Apply narrative/owner/dueDate from controllers to the draft.
    var updated = draft;
    for (var i = 0; i < updated.all.length; i++) {
      final dim = updated.all[i];
      updated = updated.updateDimension(
        i,
        dim.copyWith(
          narrative: _narrativeCtrls[i]?.text.trim(),
          owner: _ownerCtrls[i]?.text.trim(),
          dueDate: _dueDates[i],
        ),
      );
    }
    widget.provider.saveImpactAssessment(cr.id, updated);
    setState(() {
      _draft = updated;
      _showComposite = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impact assessment saved for ${cr.crNumber} • composite ${updated.compositeImpactScore.toStringAsFixed(2)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cr = widget.selectedCR;
    if (cr == null) {
      return _emptyState('No change requests available', 'Create a CR first to perform an impact assessment.');
    }
    // Ensure draft is initialized for the current CR.
    if (_draft == null || _draftCRId != cr.id) _syncDraft();
    final draft = _draft!;
    final composite = draft.compositeImpactScore;
    final compositeColor = composite >= 3.5 ? const Color(0xFFEF4444) : (composite >= 2 ? const Color(0xFFF59E0B) : (composite > 0 ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header with CR selector + composite
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Impact Assessment Detail', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Editing ${cr.crNumber} • ${cr.title}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: compositeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: compositeColor.withValues(alpha: 0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('COMPOSITE SCORE', style: TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text(_showComposite ? composite.toStringAsFixed(2) : '—', style: TextStyle(color: compositeColor, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
        ]),
        const SizedBox(height: 12),
        // CR switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cr.id,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
              style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              items: widget.provider.changeRequests.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.crNumber} • ${c.title}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) widget.onSelectCR(v); },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Action bar
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            ElevatedButton.icon(
              onPressed: () => setState(() => _showComposite = true),
              icon: const Icon(Icons.calculate, size: 14),
              label: const Text('Auto-calculate composite'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            if (_showComposite) ...[
              const SizedBox(width: 12),
              Text('Composite = ${composite.toStringAsFixed(2)} / 5.00', style: TextStyle(color: compositeColor, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ]),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 14),
            label: const Text('Save assessment'),
            style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: _textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        const SizedBox(height: 16),
        // 15-dimension grid (3 columns on wide screens)
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 700 ? 2 : 1);
          final dims = draft.all;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 3 ? 0.95 : (cols == 2 ? 1.2 : 2.2),
            ),
            itemCount: dims.length,
            itemBuilder: (ctx, i) => _dimensionCard(i, dims[i]),
          );
        }),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _dimensionCard(int index, ImpactDimension d) {
    final level = d.impactLevel;
    final levelColor = level >= 4 ? const Color(0xFFEF4444) : (level >= 3 ? const Color(0xFFF59E0B) : (level >= 1 ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)));
    final isCritical = d.isCritical;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.3) : _surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            if (isCritical) const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 14),
            const SizedBox(width: 4),
            Text(d.name, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text('Level $level', style: TextStyle(color: levelColor, fontSize: 11, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        // Slider 0-5 with label
        Row(children: [
          const Text('0', style: TextStyle(color: _textSecondary, fontSize: 10)),
          Expanded(child: Slider(
            value: level.toDouble(),
            min: 0, max: 5, divisions: 5,
            activeColor: levelColor,
            onChanged: (v) => _setLevel(index, v.round()),
          )),
          const Text('5', style: TextStyle(color: _textSecondary, fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        // Narrative
        TextField(
          controller: _narrativeCtrls[index],
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Narrative for ${d.name}…',
            hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 11),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            filled: true,
            fillColor: _bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _surfaceBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _surfaceBorder)),
          ),
          style: const TextStyle(color: _textPrimary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        // Owner
        TextField(
          controller: _ownerCtrls[index],
          decoration: InputDecoration(
            hintText: 'Owner (e.g. Engineering Lead)',
            hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 11),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            filled: true,
            fillColor: _bgColor,
            prefixIcon: const Icon(Icons.person_outline, size: 12, color: _textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _surfaceBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _surfaceBorder)),
          ),
          style: const TextStyle(color: _textPrimary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        // Due date
        InkWell(
          onTap: () => _pickDueDate(index),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _surfaceBorder)),
            child: Row(children: [
              const Icon(Icons.event, size: 12, color: _textSecondary),
              const SizedBox(width: 6),
              Text(_dueDates[index] == null ? 'Due date' : 'Due ${_dueDates[index]!.day}/${_dueDates[index]!.month}/${_dueDates[index]!.year}', style: TextStyle(color: _dueDates[index] == null ? _textSecondary.withValues(alpha: 0.5) : _textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_dueDates[index] != null) GestureDetector(
                onTap: () => setState(() => _dueDates[index] = null),
                child: const Icon(Icons.clear, size: 12, color: _textSecondary),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox, color: _textSecondary, size: 48),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Workflow — approval workflow builder for the selected CR
// ═════════════════════════════════════════════════════════════════════════

class _WorkflowTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  final CMChangeRequest? selectedCR;
  final ValueChanged<String> onSelectCR;
  const _WorkflowTab({
    required this.provider,
    required this.selectedCR,
    required this.onSelectCR,
  });

  @override
  State<_WorkflowTab> createState() => _WorkflowTabState();
}

class _WorkflowTabState extends State<_WorkflowTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;
  static const _bgColor = Color(0xFFF9FAFB);

  void _showAddStepDialog() {
    final cr = widget.selectedCR;
    if (cr == null) return;
    var role = ApprovalRole.projectControls;
    final nameCtrl = TextEditingController();
    DateTime? dueDate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Approval Step', style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<ApprovalRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Approval Role'),
                items: ApprovalRole.values.map((r) => DropdownMenuItem(value: r, child: Row(children: [Icon(r.icon, size: 14, color: const Color(0xFF6366F1)), const SizedBox(width: 8), Text(r.label)]))).toList(),
                onChanged: (v) => setDlgState(() => role = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Decision-maker name'), style: const TextStyle(color: Color(0xFF1A1D1F))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: dueDate ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setDlgState(() => dueDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
                    child: Row(children: [
                      const Icon(Icons.event, size: 14, color: _textSecondary),
                      const SizedBox(width: 8),
                      Text(dueDate == null ? 'Due date (optional)' : 'Due ${dueDate!.day}/${dueDate!.month}/${dueDate!.year}', style: TextStyle(color: dueDate == null ? _textSecondary : _textPrimary, fontSize: 12)),
                    ]),
                  ),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.provider.addApprovalStep(
                  cr.id,
                  role: role,
                  decisionMakerName: nameCtrl.text.trim(),
                  dueDate: dueDate,
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: _textPrimary),
              child: const Text('Add step'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDecisionDialog(String stepId, String roleLabel, ApprovalDecision decision) {
    final cr = widget.selectedCR;
    if (cr == null) return;
    final commentsCtrl = TextEditingController();
    final escalationTargetCtrl = TextEditingController();
    final escalationReasonCtrl = TextEditingController();
    final delegatedFromCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(children: [
          Icon(decision.icon, color: decision.color, size: 18),
          const SizedBox(width: 8),
          Text('${decision.label} — $roleLabel', style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recording decision on ${cr.crNumber} step "$roleLabel".', style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: commentsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Comments', alignLabelWithHint: true),
              style: const TextStyle(color: Color(0xFF1A1D1F)),
            ),
            if (decision == ApprovalDecision.escalated) ...[
              const SizedBox(height: 12),
              TextField(controller: escalationTargetCtrl, decoration: const InputDecoration(labelText: 'Escalation target (role/name)'), style: const TextStyle(color: Color(0xFF1A1D1F))),
              const SizedBox(height: 8),
              TextField(controller: escalationReasonCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Escalation reason', alignLabelWithHint: true), style: const TextStyle(color: Color(0xFF1A1D1F))),
            ],
            if (decision == ApprovalDecision.delegated) ...[
              const SizedBox(height: 12),
              TextField(controller: delegatedFromCtrl, decoration: const InputDecoration(labelText: 'Delegated from (original decision-maker)'), style: const TextStyle(color: Color(0xFF1A1D1F))),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.provider.recordApprovalDecision(
                cr.id,
                stepId,
                decision: decision,
                comments: commentsCtrl.text.trim().isEmpty ? null : commentsCtrl.text.trim(),
                escalationTarget: decision == ApprovalDecision.escalated ? (escalationTargetCtrl.text.trim().isEmpty ? null : escalationTargetCtrl.text.trim()) : null,
                escalationReason: decision == ApprovalDecision.escalated ? (escalationReasonCtrl.text.trim().isEmpty ? null : escalationReasonCtrl.text.trim()) : null,
                delegatedFrom: decision == ApprovalDecision.delegated ? (delegatedFromCtrl.text.trim().isEmpty ? null : delegatedFromCtrl.text.trim()) : null,
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: decision.color, foregroundColor: Colors.white),
            child: Text(decision.label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cr = widget.selectedCR;
    if (cr == null) {
      return _emptyState('No change requests available', 'Create a CR first to build its approval workflow.');
    }
    final steps = cr.approvalSteps;
    final allTerminal = steps.isNotEmpty && steps.every((s) => s.isTerminal);
    final canFinalize = allTerminal && (cr.status == CMStatus.submitted || cr.status == CMStatus.underReview || cr.status == CMStatus.pendingApproval || cr.status == CMStatus.returned);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Approval Workflow Builder', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${cr.crNumber} • ${cr.title} • ${steps.length} step(s)', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ])),
          Row(children: [
            ElevatedButton.icon(
              onPressed: _showAddStepDialog,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Step'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: canFinalize ? () {
                widget.provider.finalizeApproval(cr.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(cr.approvalSteps.every((s) => s.decision == ApprovalDecision.approved) ? '${cr.crNumber} finalized → APPROVED' : '${cr.crNumber} finalized → REJECTED'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: cr.approvalSteps.every((s) => s.decision == ApprovalDecision.approved) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  );
                }
              } : null,
              icon: const Icon(Icons.gavel, size: 14),
              label: const Text('Finalize Workflow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: _textPrimary,
                disabledBackgroundColor: const Color(0xFFE4E7EC),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // CR switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cr.id,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
              style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              items: widget.provider.changeRequests.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.crNumber} • ${c.title}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) widget.onSelectCR(v); },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Status summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statChip('Total Steps', '${steps.length}', const Color(0xFF6366F1)),
            _statChip('Approved', '${steps.where((s) => s.decision == ApprovalDecision.approved).length}', const Color(0xFF10B981)),
            _statChip('Pending', '${steps.where((s) => s.decision == ApprovalDecision.pending).length}', const Color(0xFFF59E0B)),
            _statChip('Escalated', '${steps.where((s) => s.decision == ApprovalDecision.escalated).length}', const Color(0xFFDC2626)),
            _statChip('Delegated', '${steps.where((s) => s.decision == ApprovalDecision.delegated).length}', const Color(0xFF8B5CF6)),
          ]),
        ),
        if (!canFinalize) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(allTerminal ? 'All steps have terminal decisions — but the CR status is ${cr.status.label}. Finalize is available for in-flight CRs only.' : 'Finalize is enabled once every step has a terminal decision (approved / rejected / delegated / escalated / returned).', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11))),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        // Vertical timeline
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isLast = i == steps.length - 1;
          return _stepTimelineCard(i + 1, step, cr.currentStepIndex == i, isLast);
        }),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _stepTimelineCard(int stepNum, CMApprovalStep step, bool isCurrent, bool isLast) {
    final decision = step.decision;
    final dColor = decision.color;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Timeline rail
        SizedBox(
          width: 40,
          child: Column(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: decision == ApprovalDecision.pending ? const Color(0xFFF9FAFB) : dColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: dColor, width: 2),
              ),
              child: Center(child: decision == ApprovalDecision.pending
                  ? Text('$stepNum', style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w700))
                  : Icon(decision.icon, color: dColor, size: 14)),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: decision == ApprovalDecision.approved ? const Color(0xFF10B981) : _surfaceBorder)),
          ]),
        ),
        const SizedBox(width: 12),
        // Card
        Expanded(child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCurrent ? LightModeColors.accent : _surfaceBorder, width: isCurrent ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(step.role?.icon ?? Icons.person_outline, size: 14, color: const Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Expanded(child: Text(step.roleLabel, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: dColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(decision.icon, size: 10, color: dColor),
                const SizedBox(width: 4),
                Text(decision.label, style: TextStyle(color: dColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ])),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline, size: 12, color: _textSecondary),
              const SizedBox(width: 4),
              Text('Decision-maker: ', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              Text(step.assigneeName ?? 'Unassigned', style: const TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              if (step.dueDate != null) ...[
                const Icon(Icons.event, size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Text('Due ${step.dueDate!.day}/${step.dueDate!.month}/${step.dueDate!.year}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
              const Spacer(),
              if (step.decidedAt != null) ...[
                const Icon(Icons.check, size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Text('Decided ${step.decidedAt!.day}/${step.decidedAt!.month}/${step.decidedAt!.year}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ]),
            if (step.comments != null && step.comments!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.comment_outlined, size: 12, color: _textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(step.comments!, style: const TextStyle(color: _textSecondary, fontSize: 11, fontStyle: FontStyle.italic))),
              ])),
            ],
            // Delegation indicator
            if (step.delegatedFrom != null) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2))), child: Row(children: [
                const Icon(Icons.forward, size: 12, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Expanded(child: Text('Delegated from: ${step.delegatedFrom}', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w600))),
              ])),
            ],
            // Escalation indicator
            if (step.escalationTarget != null) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.arrow_upward, size: 12, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Escalated to: ${step.escalationTarget}', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                if (step.escalationReason != null) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${step.escalationReason}', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10)),
                ],
              ])),
            ],
            // Decision action buttons (current pending step only)
            if (decision == ApprovalDecision.pending) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _decisionButton('Approve', ApprovalDecision.approved, step.id, step.roleLabel),
                _decisionButton('Reject', ApprovalDecision.rejected, step.id, step.roleLabel),
                _decisionButton('Defer', ApprovalDecision.returnRevision, step.id, step.roleLabel),
                _decisionButton('Delegate', ApprovalDecision.delegated, step.id, step.roleLabel),
                _decisionButton('Escalate', ApprovalDecision.escalated, step.id, step.roleLabel),
              ]),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _decisionButton(String label, ApprovalDecision decision, String stepId, String roleLabel) {
    return ElevatedButton(
      onPressed: () => _showDecisionDialog(stepId, roleLabel, decision),
      style: ElevatedButton.styleFrom(
        backgroundColor: decision.color.withValues(alpha: 0.12),
        foregroundColor: decision.color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: decision.color.withValues(alpha: 0.3))),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox, color: _textSecondary, size: 48),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Implementation & Baseline — for approved CRs only
// ═════════════════════════════════════════════════════════════════════════

class _ImplementationTab extends StatefulWidget {
  final ChangeManagementProvider provider;
  final CMChangeRequest? selectedCR;
  final ValueChanged<String> onSelectCR;
  const _ImplementationTab({
    required this.provider,
    required this.selectedCR,
    required this.onSelectCR,
  });

  @override
  State<_ImplementationTab> createState() => _ImplementationTabState();
}

class _ImplementationTabState extends State<_ImplementationTab> {
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _surfaceBorder = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;
  static const _bgColor = Color(0xFFF9FAFB);

  static const List<String> _assigneeOptions = [
    'Engineering Lead', 'Project Manager', 'Project Controls', 'Procurement Lead',
    'Quality Manager', 'Safety Officer', 'Construction Supervisor', 'Controls Engineer',
    'Carlos Mendez', 'Priya Singh', 'Sarah Chen', 'Aisha Patel', 'James Wong',
  ];

  Future<void> _pickTaskDueDate(String taskId, DateTime? current) async {
    final cr = widget.selectedCR;
    if (cr == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      widget.provider.updateImplementationTask(cr.id, taskId, dueDate: picked);
    }
  }

  void _confirmApplyToBaseline() {
    final cr = widget.selectedCR;
    if (cr == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Apply to Baseline?', style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'This will create a new BaselineRevisionRecord for ${cr.crNumber}, update the project BAC by \$${cr.impact.totalCostImpact.toStringAsFixed(0)}, and trigger a re-baseline audit entry.\n\nThis action is logged to the immutable audit trail.',
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = widget.provider.applyToBaseline(cr.id);
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Baseline v$v applied — BAC now \$${widget.provider.currentBAC.toStringAsFixed(0)}'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: _textPrimary),
            child: const Text('Apply to Baseline'),
          ),
        ],
      ),
    );
  }

  void _confirmRollback() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Rollback Baseline?', style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'This reverts the most recent baseline revision, restoring the prior BAC, scope hash, and finish date. The rollback itself is logged to the audit trail.',
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final ok = widget.provider.rollbackBaseline();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Baseline rolled back — BAC restored to \$${widget.provider.currentBAC.toStringAsFixed(0)}' : 'No baseline revisions to roll back.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: ok ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cr = widget.selectedCR;
    if (cr == null) {
      return _emptyState('No change requests available', 'Select an approved CR to track its implementation.');
    }
    final isApproved = cr.status == CMStatus.approved ||
        cr.status == CMStatus.implemented ||
        cr.status == CMStatus.closed;
    final tasks = cr.implementationTasks;
    final doneCount = tasks.where((t) => t.status == ImplementationStatus.done).length;
    final progress = tasks.isEmpty ? 0.0 : doneCount / tasks.length;
    final baselineHistory = widget.provider.baselineHistory;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Implementation & Baseline', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${cr.crNumber} • ${cr.title} • ${cr.status.label}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ])),
          Row(children: [
            ElevatedButton.icon(
              onPressed: isApproved && cr.impact.requiresRebaseline ? _confirmApplyToBaseline : null,
              icon: const Icon(Icons.publish, size: 14),
              label: const Text('Apply to Baseline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: _textPrimary,
                disabledBackgroundColor: const Color(0xFFE4E7EC),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: baselineHistory.isNotEmpty ? _confirmRollback : null,
              icon: const Icon(Icons.undo, size: 14),
              label: const Text('Rollback Baseline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE4E7EC),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        // CR switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cr.id,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16, color: _textSecondary),
              style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              items: widget.provider.changeRequests.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.crNumber} • ${c.title} [${c.status.label}]', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) widget.onSelectCR(v); },
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!isApproved) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.lock_outline, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 12),
              const Expanded(child: Text('Implementation tasks are only available for approved / implemented CRs. Approve this CR via the Workflow tab first.', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12))),
            ]),
          ),
        ] else ...[
          // Implementation progress bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('IMPLEMENTATION PROGRESS', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                Text('$doneCount of ${tasks.length} work packages complete', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: _bgColor,
                  valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? const Color(0xFF10B981) : LightModeColors.accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _progressChip('To-Do', '${tasks.where((t) => t.status == ImplementationStatus.todo).length}', const Color(0xFF6B7280)),
                _progressChip('In Progress', '${tasks.where((t) => t.status == ImplementationStatus.inProgress).length}', const Color(0xFFF59E0B)),
                _progressChip('Done', '$doneCount', const Color(0xFF10B981)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // Implementation task tracker
          const Text('IMPLEMENTATION TASKS', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
              child: const Center(child: Text('No implementation tasks. Add some via the provider.addImplementationTask method.', style: TextStyle(color: _textSecondary, fontSize: 12))),
            )
          else
            ...tasks.map((t) => _taskCard(t, cr.id)),
          const SizedBox(height: 24),
        ],
        // Baseline revision history
        const Text('BASELINE REVISION HISTORY', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        // Current baseline summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _baselineStat('Current BAC', '\$${widget.provider.currentBAC.toStringAsFixed(0)}', const Color(0xFF6366F1)),
            _baselineStat('Baseline Finish', '${widget.provider.currentBaselineFinish.day}/${widget.provider.currentBaselineFinish.month}/${widget.provider.currentBaselineFinish.year}', const Color(0xFF10B981)),
            _baselineStat('Scope Hash', _shortHash(widget.provider.currentScopeHash), const Color(0xFF8B5CF6)),
            _baselineStat('Re-baselines', '${widget.provider.rebaselineCount}', const Color(0xFFD97706)),
          ]),
        ),
        const SizedBox(height: 12),
        if (baselineHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _surfaceBorder)),
            child: const Center(child: Text('No baseline revisions recorded yet.', style: TextStyle(color: _textSecondary, fontSize: 12))),
          )
        else
          ...baselineHistory.reversed.map((rev) => _baselineRevisionCard(rev)),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _taskCard(ImplementationTask task, String crId) {
    final sColor = task.status.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(task.status.icon, color: sColor, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.workPackageName, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${task.workPackageId}${task.assignee != null ? " • ${task.assignee}" : ""}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ])),
          if (task.completedAt != null) Text('Done ${task.completedAt!.day}/${task.completedAt!.month}/${task.completedAt!.year}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status dropdown
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Status', style: TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _surfaceBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ImplementationStatus>(
                  value: task.status,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more, size: 14, color: _textSecondary),
                  style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w700),
                  items: ImplementationStatus.values.map((s) => DropdownMenuItem(value: s, child: Row(children: [Icon(s.icon, size: 12, color: s.color), const SizedBox(width: 6), Text(s.label)]))).toList(),
                  onChanged: (v) { if (v != null) widget.provider.updateImplementationTask(crId, task.id, status: v); },
                ),
              ),
            ),
          ])),
          const SizedBox(width: 8),
          // Assignee dropdown
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assignee', style: TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _surfaceBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: task.assignee != null && _assigneeOptions.contains(task.assignee) ? task.assignee : null,
                  hint: Text(task.assignee ?? 'Assign…', style: const TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more, size: 14, color: _textSecondary),
                  style: const TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                  items: _assigneeOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) { if (v != null) widget.provider.updateImplementationTask(crId, task.id, assignee: v); },
                ),
              ),
            ),
          ])),
          const SizedBox(width: 8),
          // Due date
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Due date', style: TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _pickTaskDueDate(task.id, task.dueDate),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _surfaceBorder)),
                child: Row(children: [
                  const Icon(Icons.event, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(task.dueDate == null ? 'Set date' : '${task.dueDate!.day}/${task.dueDate!.month}', style: TextStyle(color: task.dueDate == null ? _textSecondary.withValues(alpha: 0.5) : _textPrimary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ])),
        ]),
        if (task.notes != null && task.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.notes, size: 12, color: _textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(task.notes!, style: const TextStyle(color: _textSecondary, fontSize: 11, fontStyle: FontStyle.italic))),
          ])),
        ],
      ]),
    );
  }

  Widget _baselineRevisionCard(BaselineRevisionRecord rev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('v', style: TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Baseline v${rev.version} — ${rev.reason}', style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('By ${rev.revisedBy} • ${rev.revisionDate.day}/${rev.revisionDate.month}/${rev.revisionDate.year}${rev.approver != null ? " • Approver: ${rev.approver}" : ""}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            // BAC diff
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              const Expanded(child: Text('BAC', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              if (rev.previousBudget != null && rev.revisedBudget != null) ...[
                Text('\$${rev.previousBudget!.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11, decoration: TextDecoration.lineThrough)),
                const Icon(Icons.arrow_forward, size: 12, color: _textSecondary),
                Text('\$${rev.revisedBudget!.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w800)),
              ] else
                const Text('—', style: TextStyle(color: _textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            // Scope hash diff
            Row(children: [
              const Icon(Icons.fingerprint, size: 14, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              const Expanded(child: Text('Scope hash', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              if (rev.previousScopeHash != null && rev.revisedScopeHash != null) ...[
                Text(_shortHash(rev.previousScopeHash), style: const TextStyle(color: _textSecondary, fontSize: 10)),
                const Icon(Icons.arrow_forward, size: 12, color: _textSecondary),
                Text(_shortHash(rev.revisedScopeHash), style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w700)),
              ] else
                const Text('—', style: TextStyle(color: _textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            // Finish diff
            Row(children: [
              const Icon(Icons.event, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              const Expanded(child: Text('Baseline finish', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              if (rev.previousFinish != null && rev.revisedFinish != null) ...[
                Text('${rev.previousFinish!.day}/${rev.previousFinish!.month}/${rev.previousFinish!.year}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                const Icon(Icons.arrow_forward, size: 12, color: _textSecondary),
                Text('${rev.revisedFinish!.day}/${rev.revisedFinish!.month}/${rev.revisedFinish!.year}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
              ] else
                const Text('—', style: TextStyle(color: _textSecondary, fontSize: 11)),
            ]),
          ]),
        ),
        if (rev.updatedBaselines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: rev.updatedBaselines.map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
              child: Text(b, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ]),
    );
  }

  Widget _progressChip(String label, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$value $label', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _baselineStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
    ]);
  }

  String _shortHash(String? hash) {
    if (hash == null) return '—';
    if (hash.length <= 14) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox, color: _textSecondary, size: 48),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// CustomPainters
// ═════════════════════════════════════════════════════════════════════════

/// 7-day CR-volume sparkline. Renders a smooth area+line chart from
/// [values] (oldest → newest). [max] clamps the y-scale.
class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;
  final double max;
  _SparklinePainter({required this.values, required this.color, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final n = values.length;
    final dx = n > 1 ? w / (n - 1) : w;
    final yScale = (h - 8) / (max <= 0 ? 1 : max);

    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      pts.add(Offset(i * dx, h - 4 - values[i] * yScale));
    }

    // Baseline grid
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), Paint()..color = const Color(0xFFE4E7EC)..strokeWidth = 1);
    for (var g = 1; g <= 3; g++) {
      final y = h - (h * g / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), Paint()..color = const Color(0xFFE4E7EC).withValues(alpha: 0.4)..strokeWidth = 0.5);
    }

    // Area fill
    if (pts.length >= 2) {
      final areaPath = Path()
        ..moveTo(pts.first.dx, h)
        ..addPolygon(pts, false)
        ..lineTo(pts.last.dx, h)
        ..close();
      canvas.drawPath(areaPath, Paint()..color = color.withValues(alpha: 0.15));
    }

    // Line
    if (pts.length >= 2) {
      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        linePath.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(linePath, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    }

    // Dots at each data point
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = color);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    // Highlight last point with a glow
    if (pts.isNotEmpty) {
      final last = pts.last;
      canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawCircle(last, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values.length != values.length ||
      old.max != max ||
      old.color != color;
}

/// Horizontal bar chart for 15 impact dimensions. Each row is a dimension;
/// the bar length is proportional to the impact level (0-5).
class _ImpactBarChartPainter extends CustomPainter {
  final List<String> dimensionNames;
  final List<int> levels;
  _ImpactBarChartPainter({required this.dimensionNames, required this.levels});

  @override
  void paint(Canvas canvas, Size size) {
    if (dimensionNames.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final n = dimensionNames.length;
    final rowH = h / n;
    // Reserve space on the left for labels (35% of width) and a small gap.
    final labelW = w * 0.32;
    final barX = labelW + 6;
    final barMaxW = w - barX - 28; // 28 for level number on right.

    // Background grid lines for levels 0-5
    for (var lvl = 0; lvl <= 5; lvl++) {
      final x = barX + (barMaxW * lvl / 5);
      canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()..color = const Color(0xFFE4E7EC).withValues(alpha: lvl == 0 ? 0.7 : 0.3)..strokeWidth = 0.5);
    }

    for (var i = 0; i < n; i++) {
      final name = dimensionNames[i];
      final lvl = i < levels.length ? levels[i] : 0;
      final rowTop = i * rowH;
      final rowCenter = rowTop + rowH / 2;
      final barH = (rowH * 0.6).clamp(8.0, 18.0);
      final barTop = rowCenter - barH / 2;
      final barLen = barMaxW * (lvl / 5);

      // Label
      final labelTp = TextPainter(
        text: TextSpan(text: name, style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: labelW - 4);
      labelTp.paint(canvas, Offset(0, rowCenter - labelTp.height / 2));

      // Bar background (track)
      final trackR = RRect.fromRectAndRadius(Rect.fromLTWH(barX, barTop, barMaxW, barH), const Radius.circular(3));
      canvas.drawRRect(trackR, Paint()..color = const Color(0xFFF3F4F6));

      // Bar fill — color by level (green/yellow/orange/red)
      Color barColor;
      if (lvl == 0) {
        barColor = const Color(0xFFD1D5DB);
      } else if (lvl <= 1) {
        barColor = const Color(0xFF10B981);
      } else if (lvl <= 2) {
        barColor = const Color(0xFF3B82F6);
      } else if (lvl <= 3) {
        barColor = const Color(0xFFF59E0B);
      } else if (lvl <= 4) {
        barColor = const Color(0xFFEF4444);
      } else {
        barColor = const Color(0xFFDC2626);
      }

      if (lvl > 0) {
        final barR = RRect.fromRectAndRadius(Rect.fromLTWH(barX, barTop, barLen, barH), const Radius.circular(3));
        canvas.drawRRect(barR, Paint()..color = barColor);
      }

      // Level number on right
      final lvlTp = TextPainter(
        text: TextSpan(text: 'L$lvl', style: TextStyle(color: barColor, fontSize: 9, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      lvlTp.paint(canvas, Offset(barX + barMaxW + 4, rowCenter - lvlTp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactBarChartPainter old) {
    if (old.dimensionNames.length != dimensionNames.length) return true;
    for (var i = 0; i < levels.length && i < old.levels.length; i++) {
      if (old.levels[i] != levels[i]) return true;
    }
    return false;
  }
}
