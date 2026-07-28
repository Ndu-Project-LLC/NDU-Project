import 'dart:math' as math;
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
/// AGILE METRICS — Velocity, Predictability, Lead/Cycle Time, Defects
/// ═══════════════════════════════════════════════════════════════════════════
class AgileMetricsScreen extends StatefulWidget {
  const AgileMetricsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileMetricsScreen()),
    );
  }

  @override
  State<AgileMetricsScreen> createState() => _AgileMetricsScreenState();
}

class _AgileMetricsScreenState extends State<AgileMetricsScreen> {
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

  // Velocity trend data (last 6 sprints)
  final List<_VelocityPoint> _velocity = [
    _VelocityPoint(sprint: 'S19', planned: 38, completed: 35),
    _VelocityPoint(sprint: 'S20', planned: 40, completed: 42),
    _VelocityPoint(sprint: 'S21', planned: 40, completed: 38),
    _VelocityPoint(sprint: 'S22', planned: 44, completed: 41),
    _VelocityPoint(sprint: 'S23', planned: 42, completed: 44),
    _VelocityPoint(sprint: 'S24', planned: 45, completed: 42),
  ];

  double _predictability = 0.84;
  double _leadTime = 6.2; // days
  double _cycleTime = 3.4; // days
  int _escapedDefects = 4;
  int _openDefects = 11;
  final List<_DefectPoint> _defectTrend = [
    _DefectPoint(sprint: 'S19', found: 6, escaped: 2),
    _DefectPoint(sprint: 'S20', found: 8, escaped: 3),
    _DefectPoint(sprint: 'S21', found: 7, escaped: 1),
    _DefectPoint(sprint: 'S22', found: 9, escaped: 4),
    _DefectPoint(sprint: 'S23', found: 5, escaped: 2),
    _DefectPoint(sprint: 'S24', found: 7, escaped: 4),
  ];

  // Capacity utilization per team member
  final List<_CapacityMember> _capacity = [
    _CapacityMember('Sarah Chen', 0.92, 'Tech Lead'),
    _CapacityMember('Marcus Reed', 0.88, 'Backend'),
    _CapacityMember('Priya Nair', 0.95, 'Frontend'),
    _CapacityMember('James Okoro', 0.78, 'Frontend'),
    _CapacityMember('Lena Park', 0.85, 'Frontend'),
    _CapacityMember('DevOps Team', 0.70, 'DevOps'),
  ];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
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
          .doc('agile_metrics')
          .get();
      final data = doc.data() ?? {};
      if (data.isEmpty) {
        _seedProjectData(projectData);
      }
      if (mounted) {
        setState(() {
          _predictability =
              (data['predictability'] as num?)?.toDouble() ?? _predictability;
          _leadTime = (data['leadTime'] as num?)?.toDouble() ?? _leadTime;
          _cycleTime = (data['cycleTime'] as num?)?.toDouble() ?? _cycleTime;
          _escapedDefects =
              (data['escapedDefects'] as num?)?.toInt() ?? _escapedDefects;
          _openDefects =
              (data['openDefects'] as num?)?.toInt() ?? _openDefects;
          final velocity = data['velocity'] as List?;
          if (velocity != null) {
            _velocity
              ..clear()
              ..addAll(velocity
                  .map((e) => _VelocityPoint.fromMap(e as Map<String, dynamic>)));
          }
          final defectTrend = data['defectTrend'] as List?;
          if (defectTrend != null) {
            _defectTrend
              ..clear()
              ..addAll(defectTrend
                  .map((e) => _DefectPoint.fromMap(e as Map<String, dynamic>)));
          }
          final capacity = data['capacity'] as List?;
          if (capacity != null) {
            _capacity
              ..clear()
              ..addAll(capacity
                  .map((e) => _CapacityMember.fromMap(e as Map<String, dynamic>)));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Agile metrics load error: $e');
      _seedProjectData(projectData);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedProjectData(dynamic projectData) {
    final people = AgileProjectContextHelper.people(projectData, limit: 6);
    final workItems = AgileProjectContextHelper.workItems(projectData, limit: 12);
    final issues = AgileProjectContextHelper.issues(projectData, limit: 8);

    final totalPoints = workItems.fold<int>(
      0,
      (sum, item) => sum + AgileProjectContextHelper.estimateStoryPoints(item.title),
    );
    final completedPoints = workItems
        .where((item) => item.status == 'Done' || item.status == 'In Review')
        .fold<int>(
          0,
          (sum, item) => sum + AgileProjectContextHelper.estimateStoryPoints(item.title),
        );
    _predictability = totalPoints == 0 ? 0.75 : completedPoints / totalPoints;
    _leadTime = math.max(2, workItems.length / 2).toDouble();
    _cycleTime = math.max(1.5, _leadTime / 2);
    _escapedDefects = issues
        .where((issue) => issue.status != 'Done' && issue.severity.toLowerCase().contains('high'))
        .length;
    _openDefects = issues.where((issue) => issue.status != 'Done').length;

    _velocity
      ..clear()
      ..addAll(List.generate(4, (index) {
        final planned =
            math.max<double>(8, (totalPoints * (0.8 + (index * 0.05))).roundToDouble());
        final completed = math.max<double>(
          6,
          (planned * (_predictability.clamp(0.55, 0.98))).roundToDouble(),
        );
        return _VelocityPoint(
          sprint: 'S${index + 1}',
          planned: planned,
          completed: completed,
        );
      }));
    _defectTrend
      ..clear()
      ..addAll(List.generate(4, (index) {
        final found = math.max<double>(1, (_openDefects + index + 1).toDouble());
        final escaped = math.min<double>(
          found,
          math.max<double>(0, (_escapedDefects + (index ~/ 2)).toDouble()),
        );
        return _DefectPoint(sprint: 'S${index + 1}', found: found, escaped: escaped);
      }));
    _capacity
      ..clear()
      ..addAll([
        for (final person in people)
          _CapacityMember(
            person.name,
            person.notes.isEmpty ? 0.8 : 0.9,
            person.role,
          ),
      ]);
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
          .doc('agile_metrics')
          .set({
        'predictability': _predictability,
        'leadTime': _leadTime,
        'cycleTime': _cycleTime,
        'escapedDefects': _escapedDefects,
        'openDefects': _openDefects,
        'velocity': _velocity.map((v) => v.toMap()).toList(),
        'defectTrend': _defectTrend.map((d) => d.toMap()).toList(),
        'capacity': _capacity.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Metrics saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Agile metrics save error: $e');
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
                  activeItemLabel: 'Agile Metrics'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Metrics',
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
                          title: 'Agile Metrics',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Metrics',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryRow(),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 3, child: _buildVelocityChart()),
                                const SizedBox(width: 24),
                                Expanded(
                                    flex: 2, child: _buildPredictabilityGauge()),
                              ],
                            )
                          else ...[
                            _buildVelocityChart(),
                            const SizedBox(height: 24),
                            _buildPredictabilityGauge(),
                          ],
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeadCycleCard()),
                                const SizedBox(width: 24),
                                Expanded(child: _buildDefectTrend()),
                              ],
                            )
                          else ...[
                            _buildLeadCycleCard(),
                            const SizedBox(height: 24),
                            _buildDefectTrend(),
                          ],
                          const SizedBox(height: 24),
                          _buildCapacityCard(),
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
          child: const Text('DELIVERY ANALYTICS',
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
              child: _summaryCell('Avg Velocity',
                  '${(_velocity.map((v) => v.completed).reduce((a, b) => a + b) / _velocity.length).toStringAsFixed(1)} pts', Icons.speed)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Predictability',
                  '${(_predictability * 100).toInt()}%', Icons.track_changes)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Lead Time',
                  '${_leadTime.toStringAsFixed(1)} d', Icons.timer)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Escaped Defects',
                  '$_escapedDefects', Icons.bug_report)),
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

  Widget _buildVelocityChart() {
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
              const Icon(Icons.bar_chart, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Velocity Trend',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _legendDot(_kAccent, 'Completed'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFCBD5E1), 'Planned'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: Size.infinite,
              painter: _VelocityPainter(velocity: _velocity, accent: _kAccent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _velocity
                .map((v) => Text(v.sprint,
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

  Widget _buildPredictabilityGauge() {
    final pct = (_predictability * 100);
    final status = pct >= 90 ? 'Excellent' : pct >= 75 ? 'On Track' : 'At Risk';
    final color = pct >= 90
        ? Colors.green
        : pct >= 75
            ? _kAccent
            : Colors.red;
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
              const Icon(Icons.track_changes, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Predictability',
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
              painter: _GaugePainter(value: _predictability, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Text(status,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 4),
                const Text('Say-Do ratio across last 6 sprints',
                    style: TextStyle(fontSize: 11, color: _kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCycleCard() {
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
              const Icon(Icons.timeline, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Lead Time vs Cycle Time',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimeBar('Lead Time', _leadTime, 10, const Color(0xFFD97706)),
          const SizedBox(height: 14),
          _buildTimeBar('Cycle Time', _cycleTime, 10, _kAccent),
          const SizedBox(height: 14),
          _buildTimeBar('Wait Time', _leadTime - _cycleTime, 10, Colors.purple),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: _kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cycle time improved 12% this sprint. Wait time is the largest contributor to lead time — consider reducing queue hand-offs.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.brown[800],
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBar(String label, double value, double max, Color color) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline)),
            const Spacer(),
            Text('${value.toStringAsFixed(1)} days',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDefectTrend() {
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
              const Icon(Icons.bug_report_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Defect Trends',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _legendDot(_kAccent, 'Found'),
              const SizedBox(width: 12),
              _legendDot(Colors.red, 'Escaped'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size.infinite,
              painter: _DefectPainter(trend: _defectTrend),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _defectTrend
                .map((d) => Text(d.sprint,
                    style: const TextStyle(fontSize: 10, color: _kMuted)))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _defectStat('Open', '$_openDefects', _kAccent),
              const SizedBox(width: 12),
              _defectStat('Escaped', '$_escapedDefects', Colors.red),
              const SizedBox(width: 12),
              _defectStat('Trend',
                  _defectTrend.length > 1
                      ? '${((_defectTrend.last.escaped - _defectTrend[_defectTrend.length - 2].escaped) >= 0 ? '+' : '')}${(_defectTrend.last.escaped - _defectTrend[_defectTrend.length - 2].escaped)}'
                      : '0',
                  const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _defectStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: _kMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityCard() {
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
              const Icon(Icons.fitness_center_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Team Capacity Utilization',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Text('Avg ${(_capacity.map((c) => c.utilization).reduce((a, b) => a + b) / _capacity.length * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kAccent)),
            ],
          ),
          const SizedBox(height: 16),
          ..._capacity.map((c) => _buildCapacityRow(c)),
        ],
      ),
    );
  }

  Widget _buildCapacityRow(_CapacityMember c) {
    final pct = (c.utilization * 100).clamp(0, 100);
    final color = c.utilization >= 0.95
        ? Colors.red
        : c.utilization >= 0.85
            ? _kAccent
            : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                    c.name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 8),
              Text(c.name,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(c.role,
                    style: const TextStyle(
                        fontSize: 9, color: _kMuted)),
              ),
              const Spacer(),
              Text('${pct.toInt()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: c.utilization,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
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
class _VelocityPoint {
  final String sprint;
  final double planned;
  final double completed;
  const _VelocityPoint({
    required this.sprint,
    required this.planned,
    required this.completed,
  });

  Map<String, dynamic> toMap() => {
        'sprint': sprint,
        'planned': planned,
        'completed': completed,
      };

  factory _VelocityPoint.fromMap(Map<String, dynamic> m) => _VelocityPoint(
        sprint: m['sprint'] as String? ?? '',
        planned: (m['planned'] as num?)?.toDouble() ?? 0,
        completed: (m['completed'] as num?)?.toDouble() ?? 0,
      );
}

class _DefectPoint {
  final String sprint;
  final double found;
  final double escaped;
  const _DefectPoint({
    required this.sprint,
    required this.found,
    required this.escaped,
  });

  Map<String, dynamic> toMap() => {
        'sprint': sprint,
        'found': found,
        'escaped': escaped,
      };

  factory _DefectPoint.fromMap(Map<String, dynamic> m) => _DefectPoint(
        sprint: m['sprint'] as String? ?? '',
        found: (m['found'] as num?)?.toDouble() ?? 0,
        escaped: (m['escaped'] as num?)?.toDouble() ?? 0,
      );
}

class _CapacityMember {
  final String name;
  final double utilization;
  final String role;
  const _CapacityMember(this.name, this.utilization, this.role);

  Map<String, dynamic> toMap() => {
        'name': name,
        'utilization': utilization,
        'role': role,
      };

  factory _CapacityMember.fromMap(Map<String, dynamic> m) => _CapacityMember(
        m['name'] as String? ?? '',
        (m['utilization'] as num?)?.toDouble() ?? 0,
        m['role'] as String? ?? '',
      );
}

class _VelocityPainter extends CustomPainter {
  final List<_VelocityPoint> velocity;
  final Color accent;
  _VelocityPainter({required this.velocity, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = 12.0;
    final maxVal = velocity
        .map((v) => v.planned > v.completed ? v.planned : v.completed)
        .reduce((a, b) => a > b ? a : b);
    final barWidth = (w - 2 * pad) / velocity.length;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    for (int i = 0; i < velocity.length; i++) {
      final v = velocity[i];
      final x = pad + barWidth * i + barWidth * 0.15;
      final wBar = barWidth * 0.7;
      final halfBar = wBar / 2;
      // Planned bar (background)
      final plannedH = (h - 2 * pad) * (v.planned / maxVal);
      final plannedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x, h - pad - plannedH, halfBar - 2, plannedH),
        const Radius.circular(3),
      );
      canvas.drawRRect(
          plannedRect,
          Paint()..color = const Color(0xFFCBD5E1));

      // Completed bar (foreground)
      final completedH = (h - 2 * pad) * (v.completed / maxVal);
      final completedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x + halfBar + 2, h - pad - completedH, halfBar - 2, completedH),
        const Radius.circular(3),
      );
      canvas.drawRRect(completedRect, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _VelocityPainter old) =>
      old.velocity != velocity || old.accent != accent;
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.75);
    final radius = (size.width * 0.4).clamp(40.0, 90.0);
    final startAngle = math.pi;
    final sweepAngle = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Center text
    final pctText = TextSpan(
      text: '${(value * 100).toInt()}%',
      style: TextStyle(
          color: color, fontSize: 30, fontWeight: FontWeight.w800),
    );
    final tp = TextPainter(
        text: pctText,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    tp.layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height - 12));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}

class _DefectPainter extends CustomPainter {
  final List<_DefectPoint> trend;
  _DefectPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = 12.0;
    final maxVal = trend
        .map((d) => d.found > d.escaped ? d.found : d.escaped)
        .reduce((a, b) => a > b ? a : b);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    // Found bars
    final barWidth = (w - 2 * pad) / trend.length;
    for (int i = 0; i < trend.length; i++) {
      final d = trend[i];
      final x = pad + barWidth * i + barWidth * 0.2;
      final bw = barWidth * 0.6;
      final foundH = (h - 2 * pad) * (d.found / maxVal);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h - pad - foundH, bw, foundH),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFFF59E0B));

      // Escaped bar (overlay)
      final escapedH = (h - 2 * pad) * (d.escaped / maxVal);
      final escapedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x, h - pad - escapedH, bw, escapedH),
        const Radius.circular(3),
      );
      canvas.drawRRect(escapedRect,
          Paint()..color = Colors.red.withOpacity(0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _DefectPainter old) => old.trend != trend;
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
            Text('Loading agile metrics…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
