import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TEAM STATUS CHECK
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Provides a structured pulse check on the health of the project team.
/// Includes two sub-tabs:
/// 1. Team Capacity — relocated from Punchlist "Capacity Health"
/// 2. Team Operations — relocated from Punchlist "Shift Coverage"
class TeamStatusCheckScreen extends StatefulWidget {
  const TeamStatusCheckScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TeamStatusCheckScreen()),
    );
  }

  @override
  State<TeamStatusCheckScreen> createState() => _TeamStatusCheckScreenState();
}

class _TeamStatusCheckScreenState extends State<TeamStatusCheckScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Team Capacity data
  List<_CapacityRow> _capacityRows = [];
  // Team Operations data
  List<_OperationsRow> _operationsRows = [];
  // Status check entries
  List<_StatusCheckEntry> _statusEntries = [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_projectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Load from punchlist_actions doc (where Capacity Health + Shift Coverage were)
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_sections')
          .doc('punchlist_actions')
          .get();
      final data = doc.data() ?? {};

      final capList = data['capacityHealthRows'] as List? ?? [];
      _capacityRows = capList
          .map((e) => _CapacityRow.fromMap(e as Map<String, dynamic>))
          .toList();
      if (_capacityRows.isEmpty) {
        _capacityRows = _defaultCapacityRows();
      }

      final opsList = data['shiftCoverageRows'] as List? ?? [];
      _operationsRows = opsList
          .map((e) => _OperationsRow.fromMap(e as Map<String, dynamic>))
          .toList();
      if (_operationsRows.isEmpty) {
        _operationsRows = _defaultOperationsRows();
      }

      // Load status check entries from team_status_check doc
      try {
        final statusDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('execution_phase_entries')
            .doc('team_status_check')
            .get();
        final statusData = statusDoc.data() ?? {};
        final entries = statusData['statusEntries'] as List? ?? [];
        _statusEntries = entries
            .map((e) => _StatusCheckEntry.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Team Status Check load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_CapacityRow> _defaultCapacityRows() => [
        _CapacityRow(team: 'Engineering', plannedFte: 5, allocatedFte: 4, utilization: 80, riskLevel: 'Low'),
        _CapacityRow(team: 'Design', plannedFte: 3, allocatedFte: 3, utilization: 95, riskLevel: 'Medium'),
        _CapacityRow(team: 'QA', plannedFte: 2, allocatedFte: 1, utilization: 60, riskLevel: 'Low'),
      ];

  List<_OperationsRow> _defaultOperationsRows() => [
        _OperationsRow(shift: 'Day Shift', requiredHeadcount: 8, actualHeadcount: 7, coveragePercent: 87, riskFlag: 'Low'),
        _OperationsRow(shift: 'Evening Shift', requiredHeadcount: 5, actualHeadcount: 5, coveragePercent: 100, riskFlag: 'None'),
      ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 18 : 32;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Team Activities - Team Status Check'),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_isLoading) const SizedBox(height: 16),
                        const PlanningPhaseHeader(
                          title: 'Team Status Check',
                          showNavigationButtons: false,
                          showActivityLogAction: false,
                        ),
                        const SizedBox(height: 20),
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        _buildTabBar(),
                        const SizedBox(height: 24),
                        [_buildStatusCheckTab(), _buildCapacityTab(), _buildOperationsTab()][
                            _tabController.index],
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel:
                          'Project Team Activities - Team Status Check',
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

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.health_and_safety,
                    color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Team Health Pulse Check',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF064E3B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Provides a structured pulse check on the health of the project team. '
            'Team members periodically report progress, identify blockers, communicate workload '
            'concerns, and surface issues early. AI analyzes responses to identify trends, risks, '
            'and recommended actions for project managers.',
            style: TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF059669),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF059669),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Status Check'),
          Tab(text: 'Team Capacity'),
          Tab(text: 'Team Operations'),
        ],
        onTap: (index) => setState(() {}),
      ),
    );
  }

  // ── Tab 1: Status Check ────────────────────────────────────────────

  Widget _buildStatusCheckTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Team Status Updates',
            'Weekly or bi-weekly status updates from team members'),
        const SizedBox(height: 20),
        if (_statusEntries.isEmpty)
          _buildEmptyState('No status updates yet',
              'Team members can submit weekly status updates here')
        else
          ..._statusEntries.map((e) => _buildStatusCard(e)),
      ],
    );
  }

  Widget _buildStatusCard(_StatusCheckEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
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
              Text(entry.teamMember,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const Spacer(),
              Text(entry.reportingPeriod,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          if (entry.accomplishments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Accomplishments',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 4),
            Text(entry.accomplishments,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
          ],
          if (entry.blockers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Blockers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            const SizedBox(height: 4),
            Text(entry.blockers,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Team Capacity ───────────────────────────────────────────

  Widget _buildCapacityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Team Capacity',
            'Monitor resource capacity, allocation, utilization, productivity, workload balance, '
            'staffing adequacy, skill readiness, and delivery risks across project teams.'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Capacity Overview',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 16),
              ..._capacityRows.map((row) => _buildCapacityRow(row)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildAiInsightCard(
          'AI Capacity Insights',
          'AI continuously identifies trends, predicts capacity constraints, flags over-allocation, '
          'and recommends staffing or workload adjustments to maintain project performance.',
          const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildCapacityRow(_CapacityRow row) {
    final utilizationColor = row.utilization > 90
        ? const Color(0xFFEF4444)
        : row.utilization > 75
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.team,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('${row.allocatedFte}/${row.plannedFte} FTE allocated',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row.utilization}%',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: utilizationColor)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: row.utilization / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: row.riskLevel == 'High'
                  ? const Color(0xFFFEE2E2)
                  : row.riskLevel == 'Medium'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(row.riskLevel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: row.riskLevel == 'High'
                        ? const Color(0xFFDC2626)
                        : row.riskLevel == 'Medium'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669))),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Team Operations ─────────────────────────────────────────

  Widget _buildOperationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Team Operations',
            'Evaluate team execution during a configurable reporting period by tracking attendance, '
            'staffing coverage, availability, workload, productivity, compliance, overtime, and '
            'operational risks. AI continuously identifies trends, predicts capacity constraints, '
            'flags coverage gaps, and recommends staffing or workload adjustments.'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Operations Overview',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 16),
              ..._operationsRows.map((row) => _buildOperationsRow(row)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildAiInsightCard(
          'AI Operations Insights',
          'AI continuously identifies trends, predicts capacity constraints, flags coverage gaps, '
          'and recommends staffing or workload adjustments to maintain project performance.',
          const Color(0xFF0891B2),
        ),
      ],
    );
  }

  Widget _buildOperationsRow(_OperationsRow row) {
    final coverageColor = row.coveragePercent < 80
        ? const Color(0xFFEF4444)
        : row.coveragePercent < 95
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.shift,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('${row.actualHeadcount}/${row.requiredHeadcount} staff',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row.coveragePercent}%',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: coverageColor)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: row.coveragePercent / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(coverageColor),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: row.riskFlag == 'High'
                  ? const Color(0xFFFEE2E2)
                  : row.riskFlag == 'Medium'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(row.riskFlag,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: row.riskFlag == 'High'
                        ? const Color(0xFFDC2626)
                        : row.riskFlag == 'Medium'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669))),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard(String title, String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 8),
                Text(message,
                    style: TextStyle(
                        fontSize: 13, color: color.withValues(alpha: 0.8), height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ──────────────────────────────────────────────────────

class _CapacityRow {
  final String team;
  final int plannedFte;
  final int allocatedFte;
  final int utilization;
  final String riskLevel;

  _CapacityRow({
    required this.team,
    required this.plannedFte,
    required this.allocatedFte,
    required this.utilization,
    required this.riskLevel,
  });

  Map<String, dynamic> toMap() => {
        'team': team,
        'plannedFte': plannedFte,
        'allocatedFte': allocatedFte,
        'utilization': utilization,
        'riskLevel': riskLevel,
      };

  factory _CapacityRow.fromMap(Map<String, dynamic> m) => _CapacityRow(
        team: m['team']?.toString() ?? '',
        plannedFte: int.tryParse(m['plannedFte']?.toString() ?? '0') ?? 0,
        allocatedFte: int.tryParse(m['allocatedFte']?.toString() ?? '0') ?? 0,
        utilization: int.tryParse(m['utilization']?.toString() ?? '0') ?? 0,
        riskLevel: m['riskLevel']?.toString() ?? 'Low',
      );
}

class _OperationsRow {
  final String shift;
  final int requiredHeadcount;
  final int actualHeadcount;
  final int coveragePercent;
  final String riskFlag;

  _OperationsRow({
    required this.shift,
    required this.requiredHeadcount,
    required this.actualHeadcount,
    required this.coveragePercent,
    required this.riskFlag,
  });

  Map<String, dynamic> toMap() => {
        'shift': shift,
        'requiredHeadcount': requiredHeadcount,
        'actualHeadcount': actualHeadcount,
        'coveragePercent': coveragePercent,
        'riskFlag': riskFlag,
      };

  factory _OperationsRow.fromMap(Map<String, dynamic> m) => _OperationsRow(
        shift: m['shift']?.toString() ?? '',
        requiredHeadcount:
            int.tryParse(m['requiredHeadcount']?.toString() ?? '0') ?? 0,
        actualHeadcount:
            int.tryParse(m['actualHeadcount']?.toString() ?? '0') ?? 0,
        coveragePercent:
            int.tryParse(m['coveragePercent']?.toString() ?? '0') ?? 0,
        riskFlag: m['riskFlag']?.toString() ?? 'None',
      );
}

class _StatusCheckEntry {
  final String teamMember;
  final String reportingPeriod;
  final String accomplishments;
  final String blockers;

  _StatusCheckEntry({
    required this.teamMember,
    required this.reportingPeriod,
    required this.accomplishments,
    required this.blockers,
  });

  Map<String, dynamic> toMap() => {
        'teamMember': teamMember,
        'reportingPeriod': reportingPeriod,
        'accomplishments': accomplishments,
        'blockers': blockers,
      };

  factory _StatusCheckEntry.fromMap(Map<String, dynamic> m) => _StatusCheckEntry(
        teamMember: m['teamMember']?.toString() ?? '',
        reportingPeriod: m['reportingPeriod']?.toString() ?? '',
        accomplishments: m['accomplishments']?.toString() ?? '',
        blockers: m['blockers']?.toString() ?? '',
      );
}
