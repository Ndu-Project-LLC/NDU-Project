import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/screens/agile_backlog_governance_screen.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';
import 'package:ndu_project/screens/agile_sprint_calendar_screen.dart';
import 'package:ndu_project/screens/agile_team_structure_screen.dart';
import 'package:ndu_project/screens/agile_roadmap_screen.dart';
import 'package:ndu_project/screens/agile_dashboard_screen.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart';
import 'package:ndu_project/screens/agile_daily_standups_screen.dart';
import 'package:ndu_project/screens/agile_sprint_reviews_screen.dart';
import 'package:ndu_project/screens/agile_retrospectives_screen.dart';
import 'package:ndu_project/screens/agile_metrics_screen.dart';
import 'package:ndu_project/screens/agile_risks_screen.dart';
import 'package:ndu_project/screens/agile_ai_coach_screen.dart';
import 'package:ndu_project/screens/agile_iteration_management_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE PROJECT HUB — World-Class Landing Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileProjectHubScreen extends StatefulWidget {
  const AgileProjectHubScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileProjectHubScreen()),
    );
  }

  @override
  State<AgileProjectHubScreen> createState() => _AgileProjectHubScreenState();
}

class _AgileProjectHubScreenState extends State<AgileProjectHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  int _totalStories = 0;
  int _totalEpics = 0;
  int _activeSprints = 0;
  int _teamMembers = 0;

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHubMetrics();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadHubMetrics() async {
    if (_projectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final wireframeDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('planning_phase_entries')
          .doc('agile_wireframe')
          .get();

      final wireframeData = wireframeDoc.data() ?? {};
      final teamStructure = wireframeData['teamStructure'] as List? ?? [];
      _teamMembers = teamStructure.length;

      final sprintCalendar = wireframeData['sprintCalendar'] as List? ?? [];
      _activeSprints = sprintCalendar
          .where((s) =>
              (s['status'] ?? '').toString().toLowerCase() == 'active')
          .length;

      try {
        final epicsSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('planning_phase_entries')
            .doc('agile_epics')
            .collection('epics')
            .get();
        _totalEpics = epicsSnapshot.docs.length;
      } catch (_) {
        _totalEpics = 0;
      }

      try {
        final iterationsDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('execution_phase_entries')
            .doc('agile_development_iterations')
            .get();
        final iterData = iterationsDoc.data() ?? {};
        final tasks = iterData['agileTasks'] as List? ?? [];
        _totalStories = tasks.length;
      } catch (_) {
        _totalStories = 0;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Agile Hub metrics load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const List<_HubSection> _sections = [
    _HubSection(
      number: 1,
      title: 'Agile Dashboard',
      subtitle: 'Real-time delivery performance',
      icon: Icons.dashboard_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Active sprint overview',
        'Velocity trends',
        'Burnup/Burndown charts',
        'Cycle time trends',
        'Delivery forecasts',
        'AI delivery recommendations',
      ],
    ),
    _HubSection(
      number: 2,
      title: 'Product Backlog',
      subtitle: 'Central repository for all work items',
      icon: Icons.list_alt_outlined,
      gradientStart: Color(0xFFFFC812),
      gradientEnd: Color(0xFFEAB308),
      features: [
        'User stories, Epics, Features',
        'Story point estimation',
        'Priority management',
        'Business value scoring',
        'AI story suggestions',
        'Requirement traceability',
      ],
    ),
    _HubSection(
      number: 3,
      title: 'Sprint / Iteration Planning',
      subtitle: 'Plan each development iteration',
      icon: Icons.event_note_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Sprint creation & goals',
        'Team capacity planning',
        'Velocity recommendations',
        'Story selection',
        'Definition of Ready',
        'AI sprint planning',
      ],
    ),
    _HubSection(
      number: 4,
      title: 'Iteration Management',
      subtitle: 'Manage the lifecycle of each sprint',
      icon: Icons.repeat_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Sprint kickoff',
        'Daily progress tracking',
        'Blocker management',
        'Sprint completion',
        'Velocity calculation',
        'AI sprint summary',
      ],
    ),
    _HubSection(
      number: 5,
      title: 'Kanban Board',
      subtitle: 'Visual work management board',
      icon: Icons.view_kanban_outlined,
      gradientStart: Color(0xFFEAB308),
      gradientEnd: Color(0xFFCA8A04),
      features: [
        'Standard & configurable columns',
        'Drag-and-drop workflow',
        'WIP limits',
        'Cycle time tracking',
        'Swimlanes',
        'AI recommendations',
      ],
    ),
    _HubSection(
      number: 6,
      title: 'Daily Standups',
      subtitle: 'Daily Agile ceremonies',
      icon: Icons.groups_outlined,
      gradientStart: Color(0xFFD97706),
      gradientEnd: Color(0xFFB45309),
      features: [
        'Yesterday / Today / Blockers',
        'Team attendance',
        'Action items',
        'Decision log',
        'AI standup summaries',
        'Team sentiment',
      ],
    ),
    _HubSection(
      number: 7,
      title: 'Sprint Reviews',
      subtitle: 'Review completed work with stakeholders',
      icon: Icons.rate_review_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Completed story review',
        'Demonstrations',
        'Stakeholder feedback',
        'Product increment summary',
        'Action items',
        'AI review summary',
      ],
    ),
    _HubSection(
      number: 8,
      title: 'Sprint Retrospectives',
      subtitle: 'Continuous improvement',
      icon: Icons.lightbulb_outline,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Start / Stop / Continue',
        'Mad / Sad / Glad',
        '4Ls & Sailboat templates',
        'Anonymous participation',
        'Action item tracking',
        'AI pattern recognition',
      ],
    ),
    _HubSection(
      number: 9,
      title: 'Backlog Grooming',
      subtitle: 'Maintain backlog readiness',
      icon: Icons.tune_outlined,
      gradientStart: Color(0xFFEAB308),
      gradientEnd: Color(0xFFCA8A04),
      features: [
        'Story refinement & splitting',
        'Estimation updates',
        'Dependency review',
        'Duplicate detection',
        'AI story quality scoring',
        'Readiness assessment',
      ],
    ),
    _HubSection(
      number: 10,
      title: 'Agile Metrics & Reporting',
      subtitle: 'Comprehensive delivery analytics',
      icon: Icons.analytics_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFEAB308),
      features: [
        'Velocity & predictability',
        'Burndown & Burnup',
        'Lead time & Cycle time',
        'Escaped defects',
        'Sprint completion rate',
        'Release readiness',
      ],
    ),
    _HubSection(
      number: 11,
      title: 'Release Planning',
      subtitle: 'Coordinate multiple sprints into releases',
      icon: Icons.rocket_launch_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Release roadmap',
        'Sprint-to-release mapping',
        'Feature readiness',
        'Release forecasting',
        'Go-live checklist',
        'AI release risk analysis',
      ],
    ),
    _HubSection(
      number: 12,
      title: 'Agile Risks & Impediments',
      subtitle: 'Track delivery blockers',
      icon: Icons.warning_amber_outlined,
      gradientStart: Color(0xFFD97706),
      gradientEnd: Color(0xFFB45309),
      features: [
        'Blocker log',
        'Escalation workflow',
        'Risk register integration',
        'Root cause tracking',
        'Resolution SLA',
        'AI risk prediction',
      ],
    ),
    _HubSection(
      number: 13,
      title: 'Team Capacity & Workload',
      subtitle: 'Support sustainable delivery',
      icon: Icons.fitness_center_outlined,
      gradientStart: Color(0xFFEAB308),
      gradientEnd: Color(0xFFCA8A04),
      features: [
        'Capacity planning',
        'Team allocation',
        'Vacation & leave tracking',
        'Skill coverage',
        'Burnout indicators',
        'AI workload optimization',
      ],
    ),
    _HubSection(
      number: 14,
      title: 'AI Agile Coach',
      subtitle: 'Embedded guidance throughout execution',
      icon: Icons.auto_awesome,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      features: [
        'Sprint planning recommendations',
        'Story writing assistance',
        'Estimation suggestions',
        'Risk identification',
        'Retrospective insights',
        'Agile maturity coaching',
      ],
    ),
    _HubSection(
      number: 15,
      title: 'Agile Roadmap',
      subtitle: 'Strategic visual roadmap',
      icon: Icons.map_outlined,
      gradientStart: Color(0xFFD97706),
      gradientEnd: Color(0xFFB45309),
      features: [
        'Timeline & Hierarchical views',
        'Project progress tracking',
        'Milestone management',
        'Dependency mapping',
        'Business value tracking',
        'AI roadmap advisor',
      ],
    ),
  ];

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        AgileDashboardScreen.open(context);
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AgileBacklogGovernanceScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AgileSprintCalendarScreen()));
        break;
      case 3:
        AgileIterationManagementScreen.open(context);
        break;
      case 4:
        AgileKanbanBoardScreen.open(context);
        break;
      case 5:
        AgileDailyStandupsScreen.open(context);
        break;
      case 6:
        AgileSprintReviewsScreen.open(context);
        break;
      case 7:
        AgileRetrospectivesScreen.open(context);
        break;
      case 8:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AgileBacklogGovernanceScreen()));
        break;
      case 9:
        AgileMetricsScreen.open(context);
        break;
      case 10:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AgileReleasePlanScreen()));
        break;
      case 11:
        AgileRisksScreen.open(context);
        break;
      case 12:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AgileTeamStructureScreen()));
        break;
      case 13:
        AgileAiCoachScreen.open(context);
        break;
      case 14:
        AgileRoadmapScreen.open(context);
        break;
    }
  }

  void _showComingSoon(String sectionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(sectionName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This section is being activated as part of the Agile Project Hub rollout.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data from earlier phases (team structure, epics, sprint calendar, release plan) flows into this module automatically.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
                  activeItemLabel: 'Agile Project Hub'),
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
                          _buildMetricsRow(),
                          const SizedBox(height: 32),
                          _buildSectionGrid(isMobile),
                          const SizedBox(height: 48),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Project Hub',
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

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF312E81),
            Color(0xFFCA8A04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCA8A04).withValues(alpha: 0.3),
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
                Icon(Icons.flash_on, color: Color(0xFFFBBF24), size: 16),
                SizedBox(width: 6),
                Text(
                  'AGILE IMPLEMENTATION',
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
            'Agile Project Hub',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A structured environment for teams using Scrum, Kanban, or hybrid Agile approaches. '
            'Centralizes sprint planning, backlog management, team collaboration, delivery tracking, '
            'and continuous improvement — integrated with the Project Delivery Operating System (PDOS).',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFC7D2FE),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroBadge(Icons.speed, 'AI Guidance Throughout'),
              _heroBadge(Icons.integration_instructions, 'PDOS Integrated'),
              _heroBadge(Icons.trending_up, 'Program & Portfolio Roll-up'),
              _heroBadge(Icons.history_edu, 'Prior Phase Data Flow'),
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
          Icon(icon, size: 16, color: const Color(0xFFA5B4FC)),
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

  Widget _buildMetricsRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final metrics = [
        _MetricCard(
          label: 'Total Stories',
          value: '$_totalStories',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFFFC812),
        ),
        _MetricCard(
          label: 'Total Epics',
          value: '$_totalEpics',
          icon: Icons.layers_outlined,
          color: const Color(0xFFD97706),
        ),
        _MetricCard(
          label: 'Active Sprints',
          value: '$_activeSprints',
          icon: Icons.play_circle_outline,
          color: const Color(0xFFF59E0B),
        ),
        _MetricCard(
          label: 'Team Members',
          value: '$_teamMembers',
          icon: Icons.people_outline,
          color: const Color(0xFFF59E0B),
        ),
      ];

      if (isWide) {
        return Row(
          children: [
            for (int i = 0; i < metrics.length; i++) ...[
              Expanded(child: metrics[i]),
              if (i < metrics.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (int i = 0; i < metrics.length; i += 2) ...[
            Row(
              children: [
                Expanded(child: metrics[i]),
                const SizedBox(width: 16),
                if (i + 1 < metrics.length)
                  Expanded(child: metrics[i + 1])
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
            if (i + 2 < metrics.length) const SizedBox(height: 16),
          ],
        ],
      );
    });
  }

  Widget _buildSectionGrid(bool isMobile) {
    final crossAxisCount =
        isMobile ? 1 : (MediaQuery.sizeOf(context).width > 1200 ? 3 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Module Components',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '15 Sections',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCA8A04),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: _sections.map((s) {
            final sidebarW = AppBreakpoints.sidebarWidth(context);
            final availableWidth =
                MediaQuery.sizeOf(context).width - sidebarW - 64;
            final width = crossAxisCount == 1
                ? double.infinity
                : (availableWidth - (crossAxisCount - 1) * 20) /
                    crossAxisCount;
            return SizedBox(
              width: width,
              child: _buildSectionCard(s),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionCard(_HubSection section) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSection(section.number - 1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [section.gradientStart, section.gradientEnd],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(section.icon, color: Colors.white, size: 24),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${section.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: section.features.take(4).map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  section.gradientStart.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: section.gradientStart,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Explore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: section.gradientStart,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward,
                              size: 14, color: section.gradientStart),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Integration Across the Agile Module',
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
            'AI is embedded throughout every Agile activity to provide proactive guidance, improve planning quality, '
            'identify delivery risks early, automate routine tasks, and help both novice and experienced Agile teams '
            'make informed decisions. It learns from project history, team performance, and organizational delivery '
            'patterns to continuously recommend improvements, forecast outcomes, and enhance sprint execution.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF065F46),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubSection {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final List<String> features;

  const _HubSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.features,
  });
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
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
          ),
        ],
      ),
    );
  }
}
