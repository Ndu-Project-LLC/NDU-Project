import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE DASHBOARD — World-Class Delivery Performance Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileDashboardScreen extends StatefulWidget {
  const AgileDashboardScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileDashboardScreen()),
    );
  }

  @override
  State<AgileDashboardScreen> createState() => _AgileDashboardScreenState();
}

class _AgileDashboardScreenState extends State<AgileDashboardScreen> {
  // Brand palette — yellow / amber
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

  // Sprint metrics
  String _activeSprint = 'Sprint 24';
  int _sprintDay = 6;
  int _sprintTotalDays = 10;
  int _velocity = 42;
  int _storiesCompleted = 18;
  int _storiesTotal = 24;
  int _teamCapacity = 88;
  double _sprintCompletion = 0.72;

  // Burn-down data (story points remaining per day)
  final List<double> _burnDown = [
    48, 44, 41, 38, 34, 30, 26, 21, 16, 10
  ];
  final List<double> _idealBurn = [
    48, 43.2, 38.4, 33.6, 28.8, 24, 19.2, 14.4, 9.6, 4.8
  ];

  // Sprint health indicators
  final List<_HealthIndicator> _health = [
    _HealthIndicator('Scope Stability', 0.92, Colors.green, 'Stable'),
    _HealthIndicator('Velocity Trend', 0.78, _kAccent, 'On Track'),
    _HealthIndicator('Blocker Backlog', 0.45, Colors.red, 'At Risk'),
    _HealthIndicator('Team Capacity', 0.88, Colors.green, 'Healthy'),
  ];

  // Recent activity feed
  final List<_ActivityItem> _activity = [
    _ActivityItem('Sarah Chen', 'completed', 'NDU-1042: Login validation',
        '12m ago', Icons.check_circle, Colors.green),
    _ActivityItem('Marcus Reed', 'moved', 'NDU-1038: API rate limiting',
        '34m ago', Icons.swap_horiz, Colors.blue),
    _ActivityItem('Kaz AI', 'flagged', 'Velocity drift detected on Sprint 24',
        '1h ago', Icons.auto_awesome, _kAccent),
    _ActivityItem('Priya Nair', 'commented on', 'NDU-1031: Dashboard widgets',
        '2h ago', Icons.chat_bubble_outline, Colors.purple),
    _ActivityItem('James Okoro', 'blocked', 'NDU-1029: SSO integration',
        '3h ago', Icons.block, Colors.red),
    _ActivityItem('Lena Park', 'started', 'NDU-1045: Reporting module',
        '4h ago', Icons.play_arrow, _kAccent),
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
          .doc('agile_dashboard')
          .get();
      final data = doc.data() ?? {};
      if (mounted) {
        setState(() {
          _activeSprint = data['activeSprint'] as String? ?? _activeSprint;
          _sprintDay = (data['sprintDay'] as num?)?.toInt() ?? _sprintDay;
          _sprintTotalDays =
              (data['sprintTotalDays'] as num?)?.toInt() ?? _sprintTotalDays;
          _velocity = (data['velocity'] as num?)?.toInt() ?? _velocity;
          _storiesCompleted =
              (data['storiesCompleted'] as num?)?.toInt() ?? _storiesCompleted;
          _storiesTotal =
              (data['storiesTotal'] as num?)?.toInt() ?? _storiesTotal;
          _teamCapacity =
              (data['teamCapacity'] as num?)?.toInt() ?? _teamCapacity;
          final completion = _storiesTotal == 0
              ? 0.0
              : _storiesCompleted / _storiesTotal;
          _sprintCompletion = completion;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Agile dashboard load error: $e');
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
          .doc('agile_dashboard')
          .set({
        'activeSprint': _activeSprint,
        'sprintDay': _sprintDay,
        'sprintTotalDays': _sprintTotalDays,
        'velocity': _velocity,
        'storiesCompleted': _storiesCompleted,
        'storiesTotal': _storiesTotal,
        'teamCapacity': _teamCapacity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dashboard metrics saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Agile dashboard save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                  activeItemLabel: 'Agile Dashboard'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Dashboard',
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
                          title: 'Agile Dashboard',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Dashboard',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildMetricsRow(isMobile),
                          const SizedBox(height: 24),
                          _buildSprintProgressCard(),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: _buildBurnDownCard()),
                                const SizedBox(width: 24),
                                Expanded(
                                    flex: 2,
                                    child: _buildHealthCard()),
                              ],
                            )
                          else ...[
                            _buildBurnDownCard(),
                            const SizedBox(height: 24),
                            _buildHealthCard(),
                          ],
                          const SizedBox(height: 24),
                          _buildActivityFeed(),
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

  // ── Top bar with logo ────────────────────────────────────────────────────
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.flash_on, size: 14, color: _kAccent),
              SizedBox(width: 6),
              Text('LIVE DASHBOARD',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                      letterSpacing: 1.1)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Metric cards row ─────────────────────────────────────────────────────
  Widget _buildMetricsRow(bool isMobile) {
    final cards = <_MetricCard>[
      _MetricCard(
        title: 'Active Sprint',
        value: _activeSprint,
        sublabel: 'Day $_sprintDay of $_sprintTotalDays',
        icon: Icons.directions_run,
        accent: _kAccent,
        accentBg: _kAccentBg,
        trend: '+2 days',
        trendUp: true,
      ),
      _MetricCard(
        title: 'Velocity',
        value: '$_velocity pts',
        sublabel: '3-sprint avg: 40 pts',
        icon: Icons.speed,
        accent: Colors.green,
        accentBg: const Color(0xFFD1FAE5),
        trend: '+5%',
        trendUp: true,
      ),
      _MetricCard(
        title: 'Stories Completed',
        value: '$_storiesCompleted / $_storiesTotal',
        sublabel:
            '${(_sprintCompletion * 100).toInt()}% of sprint goal',
        icon: Icons.task_alt,
        accent: Colors.blue,
        accentBg: const Color(0xFFDBEAFE),
        trend: '6 in progress',
        trendUp: true,
      ),
      _MetricCard(
        title: 'Team Capacity',
        value: '$_teamCapacity%',
        sublabel: '7 of 8 members active',
        icon: Icons.groups,
        accent: Colors.purple,
        accentBg: const Color(0xFFEDE9FE),
        trend: 'Healthy',
        trendUp: true,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMetricCard(c),
                ))
            .toList(),
      );
    }
    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildMetricCard(c),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(_MetricCard c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(c.icon, size: 18, color: c.accent),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.trendUp
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      c.trendUp
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 12,
                      color: c.trendUp ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(c.trend,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.trendUp
                                ? Colors.green[700]
                                : Colors.red[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(c.title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _kMuted)),
          const SizedBox(height: 4),
          Text(c.value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          Text(c.sublabel,
              style: const TextStyle(fontSize: 11, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Sprint progress card ─────────────────────────────────────────────────
  Widget _buildSprintProgressCard() {
    final pct = (_sprintCompletion * 100).clamp(0, 100);
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
              const Icon(Icons.flag_outlined, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              Text('Sprint Progress — $_activeSprint',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${pct.toInt()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _sprintCompletion,
              minHeight: 14,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_kAccentLight),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('$_storiesCompleted Completed', Colors.green),
              const SizedBox(width: 8),
              _chip(
                  '${_storiesTotal - _storiesCompleted} Remaining', _kAccent),
              const SizedBox(width: 8),
              _chip('Day $_sprintDay/$_sprintTotalDays', Colors.blue),
              const Spacer(),
              Text(
                  'ETA: ${DateTime.now().add(Duration(days: _sprintTotalDays - _sprintDay)).day}/${DateTime.now().month}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  // ── Burn-down chart ──────────────────────────────────────────────────────
  Widget _buildBurnDownCard() {
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
              const Icon(Icons.show_chart, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Burn-down',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _legendDot(_kAccentLight, 'Actual'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFCBD5E1), 'Ideal'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BurnDownPainter(
                actual: _burnDown,
                ideal: _idealBurn,
                accent: _kAccentLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                _burnDown.length, (i) => Text('D${i + 1}',
                    style: const TextStyle(fontSize: 10, color: _kMuted))),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: _kMuted)),
      ],
    );
  }

  // ── Health indicators ────────────────────────────────────────────────────
  Widget _buildHealthCard() {
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
              const Icon(Icons.health_and_safety_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Health',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 16),
          ..._health.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(h.label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kHeadline)),
                        const Spacer(),
                        Text(h.status,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: h.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: h.value,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(h.color),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Activity feed ─────────────────────────────────────────────────────────
  Widget _buildActivityFeed() {
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
              const Icon(Icons.history, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 14),
                label: const Text('Filter'),
                style: TextButton.styleFrom(foregroundColor: _kAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._activity.map((a) => _buildActivityItem(a)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(_ActivityItem a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(a.icon, size: 16, color: a.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: _kHeadline, height: 1.4),
                children: [
                  TextSpan(
                      text: a.actor,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: ' ${a.verb} ',
                      style: const TextStyle(color: _kMuted)),
                  TextSpan(
                      text: a.target,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Text(a.time,
              style: const TextStyle(
                  fontSize: 11, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Action bar (save / refresh) ───────────────────────────────────────────
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
          label: Text(_isSaving ? 'Saving…' : 'Save Metrics'),
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
class _MetricCard {
  final String title;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String trend;
  final bool trendUp;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.trend,
    required this.trendUp,
  });
}

class _HealthIndicator {
  final String label;
  final double value;
  final Color color;
  final String status;
  const _HealthIndicator(this.label, this.value, this.color, this.status);
}

class _ActivityItem {
  final String actor;
  final String verb;
  final String target;
  final String time;
  final IconData icon;
  final Color color;
  const _ActivityItem(
      this.actor, this.verb, this.target, this.time, this.icon, this.color);
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
            Text('Loading sprint dashboard…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BurnDownPainter extends CustomPainter {
  final List<double> actual;
  final List<double> ideal;
  final Color accent;
  _BurnDownPainter({
    required this.actual,
    required this.ideal,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = actual.reduce((a, b) => a > b ? a : b);
    final w = size.width;
    final h = size.height;
    final pad = 8.0;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    // Ideal line
    final idealPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final idealPath = Path();
    for (int i = 0; i < ideal.length; i++) {
      final x = pad + (w - 2 * pad) * i / (ideal.length - 1);
      final y = pad + (h - 2 * pad) * (ideal[i] / maxVal);
      if (i == 0) {
        idealPath.moveTo(x, y);
      } else {
        idealPath.lineTo(x, y);
      }
    }
    canvas.drawPath(idealPath, idealPaint);

    // Actual filled area
    final actualPath = Path();
    for (int i = 0; i < actual.length; i++) {
      final x = pad + (w - 2 * pad) * i / (actual.length - 1);
      final y = pad + (h - 2 * pad) * (actual[i] / maxVal);
      if (i == 0) {
        actualPath.moveTo(x, y);
      } else {
        actualPath.lineTo(x, y);
      }
    }
    final areaPath = Path.from(actualPath)
      ..lineTo(w - pad, h - pad)
      ..lineTo(pad, h - pad)
      ..close();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.3), accent.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Actual line
    final actualPaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(actualPath, actualPaint);

    // Points
    final pointPaint = Paint()..color = accent;
    for (int i = 0; i < actual.length; i++) {
      final x = pad + (w - 2 * pad) * i / (actual.length - 1);
      final y = pad + (h - 2 * pad) * (actual[i] / maxVal);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(
          Offset(x, y), 4, Paint()..color = Colors.white..style = PaintingStyle.fill..strokeWidth = 2);
      canvas.drawCircle(
          Offset(x, y), 4, Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _BurnDownPainter old) =>
      old.actual != actual || old.ideal != ideal || old.accent != accent;
}
