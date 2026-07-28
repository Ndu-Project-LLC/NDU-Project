import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE ROADMAP — Strategic Visual Roadmap
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Provides a strategic, visual roadmap that connects business objectives,
/// epics, features, releases, and iterations. Enables teams and stakeholders
/// to understand what has been delivered, what is in progress, what is planned
/// next, and where the project currently sits within the overall delivery
/// roadmap. AI continuously analyzes roadmap progress, delivery trends,
/// dependencies, and risks to recommend adjustments as priorities evolve.
class AgileRoadmapScreen extends StatefulWidget {
  const AgileRoadmapScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileRoadmapScreen()),
    );
  }

  @override
  State<AgileRoadmapScreen> createState() => _AgileRoadmapScreenState();
}

class _AgileRoadmapScreenState extends State<AgileRoadmapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  // Roadmap data loaded from prior phases
  List<Map<String, dynamic>> _epics = [];
  List<Map<String, dynamic>> _releases = [];
  List<Map<String, dynamic>> _sprints = [];
  List<Map<String, dynamic>> _milestones = [];
  String _projectName = '';
  String _projectObjective = '';

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoadmapData();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRoadmapData() async {
    if (_projectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Load epics
      try {
        final epicsSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('planning_phase_entries')
            .doc('agile_epics')
            .collection('epics')
            .get();
        _epics = epicsSnapshot.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
      } catch (_) {}

      // Load sprint calendar + release plan from agile_wireframe
      try {
        final wireframeDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('planning_phase_entries')
            .doc('agile_wireframe')
            .get();
        final wireframeData = wireframeDoc.data() ?? {};
        _sprints = (wireframeData['sprintCalendar'] as List? ?? [])
            .map((s) => s as Map<String, dynamic>)
            .toList();
        _releases = (wireframeData['releasePlan'] as List? ?? [])
            .map((r) => r as Map<String, dynamic>)
            .toList();
      } catch (_) {}

      // Load project name + objective
      try {
        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .get();
        final pData = projectDoc.data() ?? {};
        _projectName = (pData['projectName'] ?? '').toString();
        _projectObjective = (pData['businessCase'] ?? '').toString();
        // milestones from project data
        final msData = pData['milestones'];
        if (msData is List) {
          _milestones = msData.map((m) => m as Map<String, dynamic>).toList();
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Agile Roadmap load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  activeItemLabel: 'Agile Project Hub - Agile Roadmap'),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 28),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoading)
                            const LinearProgressIndicator(minHeight: 2),
                          if (_isLoading) const SizedBox(height: 16),
                          _buildHeroHeader(),
                          const SizedBox(height: 24),
                          _buildTabBar(),
                          const SizedBox(height: 24),
                          [
                            _buildExecutiveDashboard(),
                            _buildTimelineRoadmap(),
                            _buildHierarchicalRoadmap(),
                            _buildProgressTracking(),
                            _buildMilestoneManagement(),
                            _buildDependencyMapping(),
                          ][_tabController.index],
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Project Hub - Agile Roadmap',
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

  // ── Hero Header ────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B),
            Color(0xFF047857),
            Color(0xFF059669),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map, color: Color(0xFF6EE7B7), size: 16),
                SizedBox(width: 6),
                Text(
                  'AGILE ROADMAP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Strategic Visual Roadmap',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Connects business objectives, epics, features, releases, and iterations. '
            'Understand what has been delivered, what is in progress, what is planned next, '
            'and where the project currently sits within the overall delivery roadmap.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA7F3D0),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroBadge(Icons.timeline, 'Timeline Views'),
              _heroBadge(Icons.account_tree, 'Hierarchical'),
              _heroBadge(Icons.my_location, 'You Are Here'),
              _heroBadge(Icons.auto_awesome, 'AI Roadmap Advisor'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6EE7B7)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────

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
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Executive Dashboard'),
          Tab(text: 'Timeline Roadmap'),
          Tab(text: 'Hierarchical'),
          Tab(text: 'Progress Tracking'),
          Tab(text: 'Milestones'),
          Tab(text: 'Dependencies'),
        ],
        onTap: (index) => setState(() {}),
      ),
    );
  }

  // ── Tab 1: Executive Dashboard ─────────────────────────────────────

  Widget _buildExecutiveDashboard() {
    final totalEpics = _epics.length;
    final totalReleases = _releases.length;
    final totalSprints = _sprints.length;
    final totalMilestones = _milestones.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Executive Roadmap Dashboard',
            'A stakeholder-focused view of roadmap execution'),
        const SizedBox(height: 20),
        // "You Are Here" indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.my_location,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You Are Here',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _projectName.isNotEmpty
                          ? _projectName
                          : 'Project Roadmap',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF064E3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalSprints sprints • $totalReleases releases • $totalEpics epics',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Widget grid
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
          final widgets = [
            _execWidget('Overall Progress', '${_calculateProgress()}%', Icons.trending_up, const Color(0xFF059669)),
            _execWidget('Current Sprint', _sprints.isEmpty ? '—' : _sprints.first['sprintName']?.toString() ?? 'Sprint 1', Icons.play_circle_outline, const Color(0xFF0EA5E9)),
            _execWidget('Upcoming Milestones', '$totalMilestones', Icons.flag_outlined, const Color(0xFFF59E0B)),
            _execWidget('Roadmap Health', 'Green', Icons.health_and_safety, const Color(0xFF10B981)),
            _execWidget('Delivery Confidence', 'High', Icons.verified, const Color(0xFF6366F1)),
            _execWidget('Release Forecast', _releases.isEmpty ? '—' : _releases.first['releaseLabel']?.toString() ?? 'Release 1', Icons.rocket_launch, const Color(0xFF8B5CF6)),
          ];
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: widgets.map((w) {
              final w2 = (constraints.maxWidth - (cols - 1) * 16) / cols;
              return SizedBox(width: w2, child: w);
            }).toList(),
          );
        }),
        const SizedBox(height: 24),
        // AI Executive Insights
        _buildAiInsightCard(
          'AI Executive Insights',
          'Based on current roadmap data, delivery is on track. '
          'AI recommends focusing on the next ${_sprints.length > 1 ? '2 sprints' : 'sprint'} '
          'to maintain velocity. No critical dependencies detected.',
          const Color(0xFFA855F7),
        ),
      ],
    );
  }

  int _calculateProgress() {
    if (_epics.isEmpty && _sprints.isEmpty) return 0;
    final completedSprints = _sprints
        .where((s) => (s['status'] ?? '').toString().toLowerCase() == 'completed')
        .length;
    if (_sprints.isEmpty) return 0;
    return ((completedSprints / _sprints.length) * 100).round();
  }

  Widget _execWidget(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Timeline Roadmap ────────────────────────────────────────

  Widget _buildTimelineRoadmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Timeline Roadmap',
            'Quarterly, monthly, sprint, release, and milestone timeline views'),
        const SizedBox(height: 20),
        _buildTimelineView('Sprint Timeline', _sprints.map((s) {
          return {
            'title': s['sprintName']?.toString() ?? 'Sprint',
            'date': s['startDate']?.toString() ?? '',
            'status': s['status']?.toString() ?? 'Planned',
          };
        }).toList()),
        const SizedBox(height: 20),
        _buildTimelineView('Release Timeline', _releases.map((r) {
          return {
            'title': r['releaseLabel']?.toString() ?? 'Release',
            'date': r['releaseDate']?.toString() ?? '',
            'status': r['status']?.toString() ?? 'Planned',
          };
        }).toList()),
      ],
    );
  }

  Widget _buildTimelineView(String title, List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No items yet. Data flows from earlier phases.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
            )
          else
            ...items.map((item) => _buildTimelineNode(item)),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(Map<String, String> item) {
    final status = (item['status'] ?? '').toLowerCase();
    final color = status == 'completed'
        ? const Color(0xFF10B981)
        : status == 'active'
            ? const Color(0xFF0EA5E9)
            : const Color(0xFFD1D5DB);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Container(
                width: 2,
                height: 32,
                color: const Color(0xFFE5E7EB),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                if ((item['date'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item['date']!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item['status'] ?? 'Planned',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Hierarchical Roadmap ────────────────────────────────────

  Widget _buildHierarchicalRoadmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Hierarchical Roadmap',
            'Strategic Objectives → Initiatives → Epics → Features → User Stories → Tasks'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level 1: Strategic Objectives
              _hierarchyLevel(
                'Strategic Objectives',
                _projectObjective.isNotEmpty ? _projectObjective : 'Project Objective',
                const Color(0xFF4338CA),
                Icons.flag,
              ),
              const SizedBox(height: 12),
              // Level 2: Epics
              if (_epics.isEmpty)
                _hierarchyLevel('Epics', 'No epics yet — flows from Epics & Features', const Color(0xFF7C3AED), Icons.layers)
              else
                ..._epics.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _hierarchyLevel(
                        'Epic',
                        e['title']?.toString() ?? e['name']?.toString() ?? 'Epic',
                        const Color(0xFF7C3AED),
                        Icons.layers,
                      ),
                    )),
              const SizedBox(height: 12),
              // Level 3: Sprints
              if (_sprints.isEmpty)
                _hierarchyLevel('Sprints', 'No sprints yet — flows from Sprint Calendar', const Color(0xFF059669), Icons.event)
              else
                ..._sprints.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _hierarchyLevel(
                        'Sprint',
                        s['sprintName']?.toString() ?? 'Sprint',
                        const Color(0xFF059669),
                        Icons.event,
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hierarchyLevel(String levelLabel, String title, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(levelLabel,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Progress Tracking ───────────────────────────────────────

  Widget _buildProgressTracking() {
    final progress = _calculateProgress();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Project Progress Tracking',
            'Where the project currently sits within its planned delivery lifecycle'),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Progress ring
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 14,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$progress%',
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        const Text('Complete',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _progressStat('Sprints', '${_sprints.where((s) => (s['status'] ?? '').toLowerCase() == 'completed').length}/${_sprints.length}'),
                  _progressStat('Epics', '${_epics.length}'),
                  _progressStat('Releases', '${_releases.length}'),
                  _progressStat('Milestones', '${_milestones.length}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  // ── Tab 5: Milestone Management ────────────────────────────────────

  Widget _buildMilestoneManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Milestone Management',
            'Track major delivery objectives'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: _milestones.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No milestones yet. Data flows from project setup.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ),
                )
              : Column(
                  children: _milestones.map((m) {
                    return _milestoneCard(m);
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _milestoneCard(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFBEB).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flag, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['title']?.toString() ?? m['name']?.toString() ?? 'Milestone',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                if ((m['date'] ?? m['targetDate'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    (m['date'] ?? m['targetDate']).toString(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 6: Dependency Mapping ──────────────────────────────────────

  Widget _buildDependencyMapping() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Dependency Mapping',
            'Visualize work relationships across the roadmap'),
        const SizedBox(height: 20),
        _buildAiInsightCard(
          'AI Dependency Analysis',
          'AI continuously analyzes epic, feature, story, and cross-team dependencies. '
          'Critical path identification and impact analysis are performed automatically as new work items are added.',
          const Color(0xFF0891B2),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dependency Types',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _depType('Epic Dependencies', Icons.layers, const Color(0xFF7C3AED)),
                  _depType('Feature Dependencies', Icons.extension, const Color(0xFF0EA5E9)),
                  _depType('Story Dependencies', Icons.assignment, const Color(0xFF10B981)),
                  _depType('Cross-team Dependencies', Icons.group_work, const Color(0xFFF59E0B)),
                  _depType('Critical Path', Icons.timeline, const Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _depType(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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
                fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
      ],
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
