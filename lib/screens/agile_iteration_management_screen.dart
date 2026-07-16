import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE ITERATION MANAGEMENT — Sprint Lifecycle (Start → During → End)
/// ═══════════════════════════════════════════════════════════════════════════
class AgileIterationManagementScreen extends StatefulWidget {
  const AgileIterationManagementScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const AgileIterationManagementScreen()),
    );
  }

  @override
  State<AgileIterationManagementScreen> createState() =>
      _AgileIterationManagementScreenState();
}

class _AgileIterationManagementScreenState
    extends State<AgileIterationManagementScreen> {
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
  int _activeTab = 1; // 0=Start, 1=During, 2=End
  String _currentSprint = 'Sprint 24';

  // Sprint kickoff checklist
  final List<_KickoffItem> _kickoff = [
    _KickoffItem(id: 'K1', text: 'Sprint goal defined and communicated', owner: 'Product Owner', done: true),
    _KickoffItem(id: 'K2', text: 'Capacity confirmed for all team members', owner: 'Scrum Master', done: true),
    _KickoffItem(id: 'K3', text: 'Backlog stories meet Definition of Ready', owner: 'Team', done: true),
    _KickoffItem(id: 'K4', text: 'Sprint backlog committed in tool', owner: 'Scrum Master', done: true),
    _KickoffItem(id: 'K5', text: 'Sprint planning meeting completed', owner: 'Scrum Master', done: true),
    _KickoffItem(id: 'K6', text: 'Dependencies identified and tracked', owner: 'Tech Lead', done: false),
    _KickoffItem(id: 'K7', text: 'Risk register reviewed', owner: 'Scrum Master', done: false),
    _KickoffItem(id: 'K8', text: 'Definition of Done reaffirmed', owner: 'Team', done: true),
  ];

  // Daily progress tracker (story points burned per day)
  final List<_DailyProgress> _daily = [
    _DailyProgress(day: 1, planned: 8, actual: 7),
    _DailyProgress(day: 2, planned: 9, actual: 10),
    _DailyProgress(day: 3, planned: 9, actual: 8),
    _DailyProgress(day: 4, planned: 10, actual: 6),
    _DailyProgress(day: 5, planned: 9, actual: 11),
    _DailyProgress(day: 6, planned: 8, actual: 5),
  ];

  // Sprint completion metrics
  double _completionPct = 0.72;
  int _committedPoints = 45;
  int _completedPoints = 32;
  int _carryoverPoints = 8;
  int _sprintGoalPct = 80;

  // Carryover identification
  final List<_CarryoverItem> _carryover = [
    _CarryoverItem(id: 'NDU-1048', title: 'Audit log retention policy',
        reason: 'Blocked on infra ticket', points: 5, owner: 'Priya Nair'),
    _CarryoverItem(id: 'NDU-1051', title: 'Reporting module: export to PDF',
        reason: 'Started late, not enough time', points: 3, owner: 'Lena Park'),
    _CarryoverItem(id: 'NDU-1052', title: 'Notification preferences UI',
        reason: 'Velocity drift reduced capacity', points: 5, owner: 'James Okoro'),
    _CarryoverItem(id: 'NDU-1044', title: 'Dark mode theme tokens',
        reason: 'Awaiting Figma tokens from Design', points: 2, owner: 'James Okoro'),
  ];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_iteration_management')
          .get();
      final data = doc.data() ?? {};
      if (mounted) {
        setState(() {
          _currentSprint = data['currentSprint'] as String? ?? _currentSprint;
          _completionPct =
              (data['completionPct'] as num?)?.toDouble() ?? _completionPct;
          _committedPoints =
              (data['committedPoints'] as num?)?.toInt() ?? _committedPoints;
          _completedPoints =
              (data['completedPoints'] as num?)?.toInt() ?? _completedPoints;
          _carryoverPoints =
              (data['carryoverPoints'] as num?)?.toInt() ?? _carryoverPoints;
          _sprintGoalPct =
              (data['sprintGoalPct'] as num?)?.toInt() ?? _sprintGoalPct;
          final kickoff = data['kickoff'] as List?;
          if (kickoff != null) {
            _kickoff.clear();
            _kickoff.addAll(kickoff
                .map((e) => _KickoffItem.fromMap(e as Map<String, dynamic>)));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Iteration mgmt load error: $e');
      if (mounted) setState(() => _isLoading = false);
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
          .doc('agile_iteration_management')
          .set({
        'currentSprint': _currentSprint,
        'completionPct': _completionPct,
        'committedPoints': _committedPoints,
        'completedPoints': _completedPoints,
        'carryoverPoints': _carryoverPoints,
        'sprintGoalPct': _sprintGoalPct,
        'kickoff': _kickoff.map((k) => k.toMap()).toList(),
        'daily': _daily.map((d) => d.toMap()).toList(),
        'carryover': _carryover.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Iteration management data saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Iteration mgmt save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleKickoff(_KickoffItem item) {
    setState(() {
      final idx = _kickoff.indexWhere((k) => k.id == item.id);
      if (idx >= 0) {
        _kickoff[idx] = _KickoffItem(
          id: item.id,
          text: item.text,
          owner: item.owner,
          done: !item.done,
        );
      }
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
                  activeItemLabel: 'Agile Iteration Management'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Iteration Management',
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
                          title: 'Iteration Management',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Iteration Management',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildLifecycleTabs(),
                          const SizedBox(height: 20),
                          if (_activeTab == 0) ...[
                            _buildKickoffChecklist(),
                            const SizedBox(height: 24),
                            _buildSprintGoalCard(),
                          ] else if (_activeTab == 1) ...[
                            _buildDuringSummary(),
                            const SizedBox(height: 24),
                            _buildDailyProgressTracker(),
                            const SizedBox(height: 24),
                            _buildActiveBlockers(),
                          ] else ...[
                            _buildCompletionMetrics(),
                            const SizedBox(height: 24),
                            _buildCarryoverSection(),
                            const SizedBox(height: 24),
                            _buildCompletionChecklist(),
                          ],
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
          child: Text('$_currentSprint · DAY 6',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildLifecycleTabs() {
    final tabs = [
      _LifecycleTab('Start', Icons.play_arrow, Colors.green),
      _LifecycleTab('During', Icons.loop, _kAccent),
      _LifecycleTab('End', Icons.flag, Colors.purple),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          final selected = i == _activeTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? t.color : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon,
                        size: 14,
                        color: selected ? Colors.white : _kMuted),
                    const SizedBox(width: 6),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : _kHeadline)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── START tab ──────────────────────────────────────────────────────────────
  Widget _buildKickoffChecklist() {
    final doneCount = _kickoff.where((k) => k.done).length;
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
              const Icon(Icons.checklist, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Kickoff Checklist',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: doneCount == _kickoff.length
                      ? Colors.green.withOpacity(0.1)
                      : _kAccentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$doneCount/${_kickoff.length} complete',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: doneCount == _kickoff.length
                            ? Colors.green
                            : _kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: doneCount / _kickoff.length,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
            ),
          ),
          const SizedBox(height: 14),
          ..._kickoff.map((k) => _buildKickoffRow(k)),
        ],
      ),
    );
  }

  Widget _buildKickoffRow(_KickoffItem k) {
    return InkWell(
      onTap: () => _toggleKickoff(k),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              k.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: k.done ? Colors.green : _kMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.text,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: k.done ? _kMuted : _kHeadline,
                          decoration:
                              k.done ? TextDecoration.lineThrough : null)),
                  Text('Owner: ${k.owner}',
                      style: const TextStyle(
                          fontSize: 10, color: _kMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: k.done
                    ? Colors.green.withOpacity(0.1)
                    : _kAccentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(k.done ? 'Done' : 'Open',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: k.done ? Colors.green : _kAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSprintGoalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('$_currentSprint Goal',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
              'Ship SSO integration, refresh token rotation, notification service v1, and Kanban board UI. Establish audit log viewer scaffolding for next sprint.',
              style: TextStyle(
                  fontSize: 14, color: Colors.white, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalMetric('Committed', '$_committedPoints pts'),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _goalMetric('Sprint Goal', '$_sprintGoalPct%'),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _goalMetric('Capacity', '88%'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalMetric(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── DURING tab ─────────────────────────────────────────────────────────────
  Widget _buildDuringSummary() {
    final totalPlanned =
        _daily.fold<int>(0, (a, d) => a + d.planned);
    final totalActual =
        _daily.fold<int>(0, (a, d) => a + d.actual);
    final burnRate = totalPlanned == 0
        ? 0.0
        : totalActual / totalPlanned;
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
            child: _summaryCell('Day', '6 / 10', Icons.today),
          ),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell(
                'Burn Rate', '${(burnRate * 100).toInt()}%', Icons.local_fire_department),
          ),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('Remaining', '13 pts', Icons.hourglass_empty),
          ),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('Blockers', '3', Icons.block),
          ),
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

  Widget _buildDailyProgressTracker() {
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
              const Text('Daily Progress Tracker',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _legendDot(_kAccent, 'Actual'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFCBD5E1), 'Planned'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: Size.infinite,
              painter: _DailyProgressPainter(daily: _daily, accent: _kAccent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _daily
                .map((d) => Text('D${d.day}',
                    style: const TextStyle(fontSize: 10, color: _kMuted)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: _kMuted)),
      ],
    );
  }

  Widget _buildActiveBlockers() {
    final blockers = [
      ('BLK-501', 'Redis staging instance not provisioned', 'DevOps', '2 days overdue'),
      ('BLK-505', 'Velocity drift -8% on Sprint 24', 'Kaz AI', '5 days'),
      ('BLK-506', 'Cycle time exceeding 3-day target', 'Marcus R.', 'This sprint'),
    ];
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
              const Text('Active Blockers',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('3 active',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...blockers.map((b) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: _kBorder, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(b.$1,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.$2,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kHeadline)),
                          Text('Owner: ${b.$3}',
                              style: const TextStyle(
                                  fontSize: 10, color: _kMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kAccentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(b.$4,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kAccent)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── END tab ────────────────────────────────────────────────────────────────
  Widget _buildCompletionMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.celebration, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Sprint Completion Metrics',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryCell('Completed', '$_completedPoints pts',
                    Icons.check_circle),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _summaryCell('Committed', '$_committedPoints pts',
                    Icons.flag),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _summaryCell('Completion',
                    '${(_completionPct * 100).toInt()}%', Icons.pie_chart),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _summaryCell('Carryover', '$_carryoverPoints pts',
                    Icons.forward),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _completionPct,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              '${(_completionPct * 100).toInt()}% of committed points delivered. Sprint goal achieved at $_sprintGoalPct%.',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCarryoverSection() {
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
              const Icon(Icons.forward, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Carryover Identification',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Text('${_carryover.length} stories · $_carryoverPoints pts',
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCarryoverHeader(),
          const Divider(height: 1, color: _kBorder),
          ..._carryover.map((c) => _buildCarryoverRow(c)),
        ],
      ),
    );
  }

  Widget _buildCarryoverHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: const [
          SizedBox(width: 70,
              child: Text('Story',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 4,
              child: Text('Title & Reason',
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
              flex: 1,
              child: Text('Pts',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildCarryoverRow(_CarryoverItem c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(c.id,
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
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kHeadline)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 11, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(c.reason,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontStyle: FontStyle.italic))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(c.owner,
                style: const TextStyle(
                    fontSize: 12, color: _kHeadline)),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kAccentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${c.points}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionChecklist() {
    final items = [
      ('C1', 'Sprint review held with stakeholders', true),
      ('C2', 'Retrospective completed with action items', true),
      ('C3', 'Demo recordings shared', true),
      ('C4', 'Release notes updated', false),
      ('C5', 'Carryover stories triaged for next sprint', false),
      ('C6', 'Velocity recalculated and baselined', false),
      ('C7', 'Stakeholder feedback captured', true),
      ('C8', 'Risk register updated', false),
    ];
    final doneCount = items.where((i) => i.$3).length;
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
              const Icon(Icons.fact_check_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Closeout Checklist',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$doneCount/${items.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      i.$3
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: i.$3 ? Colors.green : _kMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(i.$2,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: i.$3 ? _kMuted : _kHeadline,
                              decoration: i.$3
                                  ? TextDecoration.lineThrough
                                  : null)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: i.$3
                            ? Colors.green.withOpacity(0.1)
                            : _kAccentBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(i.$3 ? 'Done' : 'Pending',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i.$3 ? Colors.green : _kAccent)),
                    ),
                  ],
                ),
              )),
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
          label: Text(_isSaving ? 'Saving…' : 'Save Iteration'),
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
class _LifecycleTab {
  final String label;
  final IconData icon;
  final Color color;
  const _LifecycleTab(this.label, this.icon, this.color);
}

class _KickoffItem {
  final String id;
  final String text;
  final String owner;
  final bool done;
  const _KickoffItem({
    required this.id,
    required this.text,
    required this.owner,
    required this.done,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'owner': owner,
        'done': done,
      };

  factory _KickoffItem.fromMap(Map<String, dynamic> m) => _KickoffItem(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        done: m['done'] as bool? ?? false,
      );
}

class _DailyProgress {
  final int day;
  final int planned;
  final int actual;
  const _DailyProgress({
    required this.day,
    required this.planned,
    required this.actual,
  });

  Map<String, dynamic> toMap() => {
        'day': day,
        'planned': planned,
        'actual': actual,
      };
}

class _CarryoverItem {
  final String id;
  final String title;
  final String reason;
  final int points;
  final String owner;
  const _CarryoverItem({
    required this.id,
    required this.title,
    required this.reason,
    required this.points,
    required this.owner,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'reason': reason,
        'points': points,
        'owner': owner,
      };
}

class _DailyProgressPainter extends CustomPainter {
  final List<_DailyProgress> daily;
  final Color accent;
  _DailyProgressPainter({required this.daily, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = 12.0;
    final maxVal = daily
        .map((d) => d.planned > d.actual ? d.planned : d.actual)
        .reduce((a, b) => a > b ? a : b);
    final barWidth = (w - 2 * pad) / daily.length;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    for (int i = 0; i < daily.length; i++) {
      final d = daily[i];
      final x = pad + barWidth * i + barWidth * 0.15;
      final bw = barWidth * 0.7;
      final halfBar = bw / 2;

      // Planned bar
      final plannedH = (h - 2 * pad) * (d.planned / maxVal);
      final plannedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h - pad - plannedH, halfBar - 2, plannedH),
        const Radius.circular(3),
      );
      canvas.drawRRect(plannedRect, Paint()..color = const Color(0xFFCBD5E1));

      // Actual bar
      final actualH = (h - 2 * pad) * (d.actual / maxVal);
      final actualRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x + halfBar + 2, h - pad - actualH, halfBar - 2, actualH),
        const Radius.circular(3),
      );
      canvas.drawRRect(actualRect, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _DailyProgressPainter old) =>
      old.daily != daily || old.accent != accent;
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
            Text('Loading iteration management…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
