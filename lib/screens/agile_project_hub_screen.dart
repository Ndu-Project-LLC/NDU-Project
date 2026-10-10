import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/agile_hub_sections.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:go_router/go_router.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE PROJECT HUB — World-Class Landing Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileProjectHubScreen extends StatefulWidget {
  const AgileProjectHubScreen({super.key});

  static void open(BuildContext context) {
    context.push('/agile-project-hub');
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
          .where(
              (s) => (s['status'] ?? '').toString().toLowerCase() == 'active')
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

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 18 : 32;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
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
              color: Color(0xFFFEF3C7),
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
          Icon(icon, size: 16, color: const Color(0xFFFDE68A)),
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
                color: Color(0xFFFFC107),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${agileHubSections.length} Sections',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCA8A04),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: agileHubSections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, i) => RepaintBoundary(
            key: ValueKey('agile_hub_section_$i'),
            child: SizedBox(
              width: double.infinity,
              child: _buildSectionCard(agileHubSections[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(AgileHubSection section) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => section.open(context),
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
                        child:
                            Icon(section.icon, color: Colors.white, size: 24),
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
