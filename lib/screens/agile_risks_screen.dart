import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/agile_project_context_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE RISKS & IMPEDIMENTS — Blocker Log, Heatmap, Escalation, Trends
/// ═══════════════════════════════════════════════════════════════════════════
class AgileRisksScreen extends StatefulWidget {
  const AgileRisksScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileRisksScreen()),
    );
  }

  @override
  State<AgileRisksScreen> createState() => _AgileRisksScreenState();
}

class _AgileRisksScreenState extends State<AgileRisksScreen> {
  static const Color _kAccent = Color(0xFFF59E0B);
  static const Color _kAccentLight = Color(0xFFFFC812);
  static const Color _kAccentBg = Color(0xFFFEF3C7);
  static const Color _kBackground = Color(0xFFF8FAFC);
  static const Color _kSurface = Colors.white;
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kHeadline = Color(0xFF111827);
  static const Color _kMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isSaving = false;

  List<_Blocker> _blockers = [];
  final List<_EscalationStep> _escalation = [];
  final List<_TrendPoint> _trend = [];

  // Risk heatmap matrix (probability x impact) — counts
  late final List<List<int>> _heatMatrix;

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _heatMatrix = List.generate(5, (_) => List.generate(5, (_) => 0));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    final projectData = ProjectDataHelper.getData(context);
    if (pid == null) {
      _seedProjectData(projectData);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_risks')
          .get();
      final data = doc.data() ?? {};
      final blockers = (data['blockers'] as List?)
              ?.map((e) => _Blocker.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final escalation = (data['escalation'] as List?)
              ?.map((e) => _EscalationStep.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final trend = (data['trend'] as List?)
              ?.map((e) => _TrendPoint.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (blockers.isEmpty) _seedProjectData(projectData);
      if (mounted) {
        setState(() {
          if (blockers.isNotEmpty) _blockers = blockers;
          if (escalation.isNotEmpty) {
            _escalation.clear();
            _escalation.addAll(escalation);
          }
          if (trend.isNotEmpty) {
            _trend.clear();
            _trend.addAll(trend);
          }
          _rebuildHeatmap();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Risks load error: $e');
      _seedProjectData(projectData);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedProjectData(dynamic projectData) {
    final risks = AgileProjectContextHelper.risks(projectData, limit: 8);
    final issues = AgileProjectContextHelper.issues(projectData, limit: 4);
    _blockers = [
      for (final risk in risks)
        _Blocker(
          id: risk.id,
          item: risk.title,
          owner: risk.owner.isEmpty ? 'Project Team' : risk.owner,
          status: risk.status,
          sla: 'This sprint',
          resolution: risk.mitigation.isEmpty
              ? 'Track via agile risk workflow'
              : risk.mitigation,
          probability: risk.probability.clamp(1, 5).toInt(),
          impact: risk.impact.clamp(1, 5).toInt(),
          raised: 'From project context',
        ),
      for (final issue in issues)
        _Blocker(
          id: issue.id,
          item: issue.title,
          owner: issue.owner.isEmpty ? 'Project Team' : issue.owner,
          status: issue.status,
          sla: issue.due.isEmpty ? 'Next review' : issue.due,
          resolution: issue.description.isEmpty
              ? 'Resolve through issue log follow-up'
              : issue.description,
          probability: 3,
          impact: issue.severity.toLowerCase().contains('high') ? 4 : 3,
          raised: 'From issue log',
        ),
    ];
    _escalation.clear();
    _escalation.addAll([
      _EscalationStep(
          level: 'L1 — Team',
          owner: 'Scrum Master',
          sla: '24 hours',
          description: 'Surface impediment in daily standup. Scrum Master facilitates resolution.',
          status: 'Active',
          color: Colors.green),
      _EscalationStep(
          level: 'L2 — Engineering Manager',
          owner: 'Engineering Manager',
          sla: '48 hours',
          description: 'If unresolved, escalate to Engineering Manager for resource or decision support.',
          status: 'Active',
          color: _kAccent),
      _EscalationStep(
          level: 'L3 — Director',
          owner: 'Engineering Director',
          sla: '72 hours',
          description: 'Cross-team or external blockers escalated to Director for org-level intervention.',
          status: 'On Standby',
          color: Colors.orange),
      _EscalationStep(
          level: 'L4 — Executive',
          owner: 'VP Engineering',
          sla: '5 days',
          description: 'Strategic blockers (e.g. vendor, contract) escalated to VP for executive action.',
          status: 'On Standby',
          color: Colors.red),
    ]);
    _trend.clear();
    final sprintLabel = AgileProjectContextHelper.activeSprintLabel(projectData);
    _trend.addAll([
      _TrendPoint(
        sprint: 'Baseline',
        blockers: (_blockers.length / 2).roundToDouble(),
        resolved: 1,
      ),
      _TrendPoint(
        sprint: 'Current - 2',
        blockers: (_blockers.length * 0.7).roundToDouble(),
        resolved: 2,
      ),
      _TrendPoint(
        sprint: 'Current - 1',
        blockers: (_blockers.length * 0.85).roundToDouble(),
        resolved: 2,
      ),
      _TrendPoint(
        sprint: sprintLabel.replaceAll('Sprint ', 'S'),
        blockers: _blockers.length.toDouble(),
        resolved:
            _blockers.where((blocker) => blocker.status == 'Resolved').length.toDouble(),
      ),
    ]);
    _rebuildHeatmap();
  }

  void _rebuildHeatmap() {
    for (final row in _heatMatrix) {
      for (int i = 0; i < row.length; i++) row[i] = 0;
    }
    for (final b in _blockers) {
      final p = (b.probability - 1).clamp(0, 4);
      final i = (b.impact - 1).clamp(0, 4);
      _heatMatrix[4 - i][p] = _heatMatrix[4 - i][p] + 1;
    }
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_risks')
          .set({
        'blockers': _blockers.map((b) => b.toMap()).toList(),
        'escalation': _escalation.map((e) => e.toMap()).toList(),
        'trend': _trend.map((t) => t.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Risks & impediments saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Risks save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resolveBlocker(_Blocker b) {
    setState(() {
      final idx = _blockers.indexWhere((x) => x.id == b.id);
      if (idx >= 0) {
        _blockers[idx] = _Blocker(
          id: b.id,
          item: b.item,
          owner: b.owner,
          status: b.status == 'Resolved' ? 'Open' : 'Resolved',
          sla: b.sla,
          resolution: b.resolution,
          probability: b.probability,
          impact: b.impact,
          raised: b.raised,
        );
      }
      _rebuildHeatmap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Risks & Impediments'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Risks & Impediments',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: hp, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 20),
                        PlanningPhaseHeader(
                          title: 'Agile Risks & Impediments',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Risks & Impediments',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryRow(),
                          const SizedBox(height: 24),
                          _buildBlockerLogTable(),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildRiskHeatmap()),
                                const SizedBox(width: 24),
                                Expanded(child: _buildTrendSection()),
                              ],
                            )
                          else ...[
                            _buildRiskHeatmap(),
                            const SizedBox(height: 24),
                            _buildTrendSection(),
                          ],
                          const SizedBox(height: 24),
                          _buildEscalationSection(),
                          const SizedBox(height: 24),
                          _buildActionBar(),
                          const SizedBox(height: 64),
                        ],
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Image.asset('assets/images/Logo.png', height: 36),
        const SizedBox(width: 12),
        const Text('Ndu Project',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kHeadline)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccentBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text('RISK REGISTER',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final open = _blockers.where((b) => b.status != 'Resolved').length;
    final resolved =
        _blockers.where((b) => b.status == 'Resolved').length;
    final escalated =
        _blockers.where((b) => b.status == 'Escalated').length;
    final overdue =
        _blockers.where((b) => b.sla.toLowerCase().contains('overdue')).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
              child: _summaryCell('Open', '$open', Icons.error_outline)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Escalated', '$escalated', Icons.arrow_upward)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Overdue SLA', '$overdue', Icons.warning)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Resolved', '$resolved', Icons.check_circle)),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBlockerLogTable() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Blocker Log',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Blocker'),
                style: TextButton.styleFrom(foregroundColor: _kAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBlockerHeader(),
          const Divider(height: 1, color: _kBorder),
          ..._blockers.map((b) => _buildBlockerRow(b)),
        ],
      ),
    );
  }

  Widget _buildBlockerHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: const [
          SizedBox(width: 70,
              child: Text('ID',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 4,
              child: Text('Blocker Item',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Owner',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('SLA',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 3,
              child: Text('Resolution',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Status',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildBlockerRow(_Blocker b) {
    final overdue = b.sla.toLowerCase().contains('overdue');
    final resolved = b.status == 'Resolved';
    return InkWell(
      onTap: () => _resolveBlocker(b),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(b.id,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted)),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.item,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: resolved ? _kMuted : _kHeadline,
                          decoration:
                              resolved ? TextDecoration.lineThrough : null)),
                  Text('Raised ${b.raised} · P${b.probability} × I${b.impact}',
                      style: const TextStyle(
                          fontSize: 10, color: _kMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: _kAccent.withOpacity(0.15),
                    child: Text(
                        b.owner.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                        style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: _kAccent)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.owner,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: _kHeadline)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: overdue
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(b.sla,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: overdue ? Colors.red : _kAccent)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(b.resolution,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: _kHeadline, height: 1.3)),
            ),
            Expanded(
              flex: 2,
              child: _statusChip(b.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'Resolved'
        ? Colors.green
        : status == 'Escalated'
            ? Colors.red
            : status == 'In Progress'
                ? Colors.blue
                : _kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildRiskHeatmap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Risk Heatmap',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              const Text('Probability →',
                  style: TextStyle(fontSize: 11, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Impact ↑', style: TextStyle(fontSize: 11, color: _kMuted)),
              Text('Risk score = Probability × Impact',
                  style: TextStyle(fontSize: 10, color: _kMuted, fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmapLegend(),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    return Column(
      children: List.generate(5, (rowIdx) {
        return Row(
          children: List.generate(5, (colIdx) {
            final count = _heatMatrix[rowIdx][colIdx];
            final impact = 5 - rowIdx;
            final prob = colIdx + 1;
            final score = impact * prob;
            Color color;
            if (score >= 16) {
              color = const Color(0xFFDC2626);
            } else if (score >= 9) {
              color = const Color(0xFFF59E0B);
            } else if (score >= 4) {
              color = const Color(0xFFFFC812);
            } else {
              color = const Color(0xFF10B981);
            }
            return Expanded(
              child: AspectRatio(
                aspectRatio: 1.4,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: count > 0 ? color : color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withOpacity(0.4), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      count > 0 ? '$count' : '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: count > 0 ? Colors.white : _kMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildHeatmapLegend() {
    final items = [
      ('Low', const Color(0xFF10B981)),
      ('Medium', const Color(0xFFFFC812)),
      ('High', const Color(0xFFF59E0B)),
      ('Critical', const Color(0xFFDC2626)),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items
          .map((i) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: i.$2, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(i.$1,
                      style: const TextStyle(
                          fontSize: 11, color: _kMuted)),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildTrendSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Blocker Trend Analysis',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendPainter(trend: _trend),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _trend
                .map((t) => Text(t.sprint,
                    style: const TextStyle(fontSize: 10, color: _kMuted)))
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: const BorderSide(color: Colors.red, width: 3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sprint 24 shows a 100% increase in open blockers. Recommend immediate root-cause review and WIP limit reinforcement.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.red[800], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Escalation Workflow',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 16),
          ..._escalation.map((e) => _buildEscalationCard(e)),
        ],
      ),
    );
  }

  Widget _buildEscalationCard(_EscalationStep e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: e.color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: e.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.layers, size: 18, color: e.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.level,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kHeadline)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: e.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('SLA ${e.sla}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: e.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(e.description,
                    style: const TextStyle(
                        fontSize: 12, color: _kMuted, height: 1.4)),
                const SizedBox(height: 4),
                Text('Owner: ${e.owner}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _kHeadline,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusChip(e.status),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveData,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_isSaving ? 'Saving…' : 'Save Risk Register'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper models & painters
// ═══════════════════════════════════════════════════════════════════════════
class _Blocker {
  final String id;
  final String item;
  final String owner;
  final String status;
  final String sla;
  final String resolution;
  final int probability;
  final int impact;
  final String raised;

  const _Blocker({
    required this.id,
    required this.item,
    required this.owner,
    required this.status,
    required this.sla,
    required this.resolution,
    required this.probability,
    required this.impact,
    required this.raised,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item': item,
        'owner': owner,
        'status': status,
        'sla': sla,
        'resolution': resolution,
        'probability': probability,
        'impact': impact,
        'raised': raised,
      };

  factory _Blocker.fromMap(Map<String, dynamic> m) => _Blocker(
        id: m['id'] as String? ?? '',
        item: m['item'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        status: m['status'] as String? ?? 'Open',
        sla: m['sla'] as String? ?? '',
        resolution: m['resolution'] as String? ?? '',
        probability: (m['probability'] as num?)?.toInt() ?? 1,
        impact: (m['impact'] as num?)?.toInt() ?? 1,
        raised: m['raised'] as String? ?? '',
      );
}

class _EscalationStep {
  final String level;
  final String owner;
  final String sla;
  final String description;
  final String status;
  final Color color;

  const _EscalationStep({
    required this.level,
    required this.owner,
    required this.sla,
    required this.description,
    required this.status,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
        'level': level,
        'owner': owner,
        'sla': sla,
        'description': description,
        'status': status,
        'color': color.toARGB32(),
      };

  factory _EscalationStep.fromMap(Map<String, dynamic> m) => _EscalationStep(
        level: m['level'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        sla: m['sla'] as String? ?? '',
        description: m['description'] as String? ?? '',
        status: m['status'] as String? ?? 'Active',
        color: Color(m['color'] as int? ?? 0xFFF59E0B),
      );
}

class _TrendPoint {
  final String sprint;
  final double blockers;
  final double resolved;
  const _TrendPoint({
    required this.sprint,
    required this.blockers,
    required this.resolved,
  });

  Map<String, dynamic> toMap() => {
        'sprint': sprint,
        'blockers': blockers,
        'resolved': resolved,
      };

  factory _TrendPoint.fromMap(Map<String, dynamic> m) => _TrendPoint(
        sprint: m['sprint'] as String? ?? '',
        blockers: (m['blockers'] as num?)?.toDouble() ?? 0,
        resolved: (m['resolved'] as num?)?.toDouble() ?? 0,
      );
}

class _TrendPainter extends CustomPainter {
  final List<_TrendPoint> trend;
  _TrendPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = 12.0;
    final maxVal = trend
        .map((t) => t.blockers > t.resolved ? t.blockers : t.resolved)
        .reduce((a, b) => a > b ? a : b);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    // Resolved line
    final resolvedPath = Path();
    for (int i = 0; i < trend.length; i++) {
      final x = pad + (w - 2 * pad) * i / (trend.length - 1);
      final y = pad + (h - 2 * pad) * (1 - trend[i].resolved / maxVal);
      if (i == 0) resolvedPath.moveTo(x, y);
      else resolvedPath.lineTo(x, y);
    }
    canvas.drawPath(
        resolvedPath,
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Blockers line
    final blockersPath = Path();
    for (int i = 0; i < trend.length; i++) {
      final x = pad + (w - 2 * pad) * i / (trend.length - 1);
      final y = pad + (h - 2 * pad) * (1 - trend[i].blockers / maxVal);
      if (i == 0) blockersPath.moveTo(x, y);
      else blockersPath.lineTo(x, y);
    }
    // Fill area under blockers
    final areaPath = Path.from(blockersPath)
      ..lineTo(w - pad, h - pad)
      ..lineTo(pad, h - pad)
      ..close();
    canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF59E0B).withOpacity(0.25), const Color(0xFFF59E0B).withOpacity(0.0)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawPath(
        blockersPath,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Points
    for (int i = 0; i < trend.length; i++) {
      final x = pad + (w - 2 * pad) * i / (trend.length - 1);
      final y = pad + (h - 2 * pad) * (1 - trend[i].blockers / maxVal);
      canvas.drawCircle(Offset(x, y), 4,
          Paint()..color = const Color(0xFFF59E0B));
      canvas.drawCircle(
          Offset(x, y), 4, Paint()..color = Colors.white..style = PaintingStyle.fill..strokeWidth = 2);
      canvas.drawCircle(
          Offset(x, y), 4, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.trend != trend;
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF59E0B)),
            SizedBox(height: 16),
            Text('Loading risk register…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
