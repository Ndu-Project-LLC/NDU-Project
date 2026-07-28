import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/screens/team_meetings_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/recognition_awards_screen.dart';
import 'package:ndu_project/screens/team_status_check_screen.dart';
import 'package:ndu_project/screens/team_handover_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PROJECT TEAM ACTIVITIES — World-Class Hub Landing Screen
/// ═══════════════════════════════════════════════════════════════════════════
///
/// A centralized workspace for building, organizing, and managing the project
/// delivery team throughout execution. Ensures every team member understands
/// their role, responsibilities, workload, and current status while giving
/// project managers visibility into team performance, collaboration, and
/// resource availability.
class ProjectTeamActivitiesScreen extends StatefulWidget {
  const ProjectTeamActivitiesScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectTeamActivitiesScreen()),
    );
  }

  @override
  State<ProjectTeamActivitiesScreen> createState() =>
      _ProjectTeamActivitiesScreenState();
}

class _ProjectTeamActivitiesScreenState extends State<ProjectTeamActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  // Hub metrics loaded from prior phases
  int _totalPersonnel = 0;
  int _totalRoles = 0;
  int _upcomingMeetings = 0;
  int _activeTrainings = 0;

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
      // Load staffing rows from execution phase
      try {
        final staffDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('execution_phase_entries')
            .doc('staff_team')
            .get();
        final staffData = staffDoc.data() ?? {};
        final rows = staffData['staffingRows'] as List? ?? [];
        _totalPersonnel = rows.length;
      } catch (_) {}

      // Load roles from planning phase (central project doc)
      try {
        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .get();
        final pData = projectDoc.data() ?? {};
        final roles = pData['projectRoles'] as List? ?? [];
        _totalRoles = roles.length;
      } catch (_) {}

      // Load upcoming meetings
      try {
        final meetingsDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(_projectId!)
            .collection('execution_phase_entries')
            .doc('team_meetings')
            .get();
        final meetingsData = meetingsDoc.data() ?? {};
        final meetings = meetingsData['meetingRows'] as List? ?? [];
        _upcomingMeetings = meetings.length;
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Project Team Hub metrics load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const List<_HubSection> _sections = [
    _HubSection(
      number: 1,
      title: 'Mobilize Team',
      subtitle: 'Team directory and resource management hub',
      icon: Icons.groups_outlined,
      gradientStart: Color(0xFF4F46E5),
      gradientEnd: Color(0xFF4338CA),
      description:
          'Captures information about every individual assigned to the project. '
          'Details follow through from the Organizational Plan in the Planning Phase — '
          'reflecting baselined positions, roles, responsibilities, and team member names.',
      features: [
        'Add, edit, remove team members',
        'Assign roles & responsibilities',
        'Track availability & allocation',
        'View workload across work packages',
        'Record certifications & skills',
        'Identify backup resources',
      ],
      dataFields: [
        'Name', 'Role/Title', 'Department', 'Email & Phone',
        'Manager/Supervisor', 'Project Role', 'Responsibility Area',
        'Skill Set', 'Certifications', 'Start/End Date',
        'Availability %', 'Time Zone', 'Location', 'Employment Type', 'Status',
      ],
    ),
    _HubSection(
      number: 2,
      title: 'Team Meetings',
      subtitle: 'Recurring meetings, agendas, and action items',
      icon: Icons.video_call_outlined,
      gradientStart: Color(0xFF0891B2),
      gradientEnd: Color(0xFF0E7490),
      description:
          'Manages recurring project meetings and provides a single location for planning, '
          'documenting, and following up on team discussions. AI generates agendas, summarizes '
          'discussions, identifies decisions, and captures action items.',
      features: [
        'Schedule recurring meetings',
        'Agenda management',
        'Attendance tracking',
        'AI meeting summaries',
        'Decisions log',
        'Action item tracking',
      ],
      dataFields: [
        'Meeting Name', 'Type', 'Date & Time', 'Frequency',
        'Organizer', 'Participants', 'Agenda', 'Objectives',
        'Discussion Notes', 'Decisions', 'Risks', 'Issues',
        'Action Items', 'Owner', 'Due Dates', 'Attachments',
      ],
    ),
    _HubSection(
      number: 3,
      title: 'Training & Team Building',
      subtitle: 'Follows through from Planning Phase',
      icon: Icons.school_outlined,
      gradientStart: Color(0xFF7C3AED),
      gradientEnd: Color(0xFF6D28D9),
      description:
          'In line with the corresponding section of the Planning Phase. The page naturally '
          'reflects here and is stewarded in this phase. Tracks onboarding, discipline-specific '
          'trainings, and team building activities.',
      features: [
        'Welcome & project onboarding',
        'Team & vacation planning',
        'Discipline-specific trainings',
        'Team building activities',
        'Activity scheduling',
        'Completion tracking',
      ],
      dataFields: [
        'Activity Name', 'Category', 'Date', 'Duration',
        'Participants', 'Facilitator', 'Status', 'Notes',
      ],
    ),
    _HubSection(
      number: 4,
      title: 'Recognition & Awards',
      subtitle: 'Celebrate achievements and outstanding contributions',
      icon: Icons.emoji_events_outlined,
      gradientStart: Color(0xFFF59E0B),
      gradientEnd: Color(0xFFD97706),
      description:
          'Celebrate project achievements by recognizing individuals and teams for outstanding '
          'contributions throughout the project lifecycle. Reinforces positive behaviors, improves '
          'engagement, and fosters a culture of accountability and collaboration.',
      features: [
        'Customizable award categories',
        'Nominate & approve recognitions',
        'Track milestones & performance',
        'Digital badges',
        'Peer & manager recognition',
        'Recognition reports',
      ],
      dataFields: [
        'Award Category', 'Recipient', 'Team', 'Nominated By',
        'Approved By', 'Date', 'Evidence', 'Comments',
        'Linked Milestone', 'Status',
      ],
    ),
    _HubSection(
      number: 5,
      title: 'Team Status Check',
      subtitle: 'Pulse check on team health and capacity',
      icon: Icons.health_and_safety_outlined,
      gradientStart: Color(0xFF10B981),
      gradientEnd: Color(0xFF059669),
      description:
          'Structured pulse check on the health of the project team. Includes Team Capacity '
          '(relocated from Punchlist — monitor resource capacity, allocation, utilization, '
          'productivity, workload balance) and Team Operations (relocated from Shift Coverage — '
          'evaluate team execution during a configurable reporting period).',
      features: [
        'Weekly/bi-weekly status updates',
        'Workload assessment',
        'Blocker identification',
        'Team morale tracking',
        'Team Capacity dashboard',
        'Team Operations dashboard',
      ],
      dataFields: [
        'Team Member', 'Reporting Period', 'Progress Status',
        '% Complete', 'Workload Rating', 'Confidence Level',
        'Risks', 'Blockers', 'Support Needed', 'Accomplishments',
        'Team Health Rating', 'Manager Comments',
      ],
    ),
    _HubSection(
      number: 6,
      title: 'Team Handover',
      subtitle: 'Checklist for team member demobilization',
      icon: Icons.swap_horiz_outlined,
      gradientStart: Color(0xFFEC4899),
      gradientEnd: Color(0xFFDB2777),
      description:
          'Ensures all responsibilities, knowledge, and project work are successfully transferred '
          'before a team member leaves the project. Methodology-neutral — suitable for Agile, '
          'Waterfall, and Hybrid projects across all industries.',
      features: [
        'Work & deliverables handover',
        'Documentation & knowledge transfer',
        'Risks & open items review',
        'Systems & stakeholder transition',
        'Sign-off capture',
        'Methodology-neutral',
      ],
      dataFields: [
        'Team Member', 'Receiving Member', 'Project Manager',
        'Work packages transferred', 'Documentation updated',
        'KT session completed', 'Stakeholders notified', 'Sign-off date',
      ],
    ),
    _HubSection(
      number: 7,
      title: 'Lessons Learned',
      subtitle: 'Continuous capture throughout execution',
      icon: Icons.lightbulb_outline,
      gradientStart: Color(0xFF6366F1),
      gradientEnd: Color(0xFF4F46E5),
      description:
          'Capture lessons learned continuously throughout project execution rather than waiting '
          'until project closeout. Follows through from the Planning Phase lessons learned section. '
          'AI prompts the team at reviews, milestones, and retrospectives to document lessons.',
      features: [
        'Capture at any time',
        'Schedule-based capture (monthly/quarterly/milestones)',
        'Categorize by area (Scope, Schedule, Cost, Quality, etc.)',
        'Assign owners & due dates',
        'Link to risks, issues, changes',
        'AI recommendations & trend analysis',
      ],
      dataFields: [
        'Lesson Title', 'Date Identified', 'Category', 'Description',
        'Root Cause', 'Recommendation', 'Action Required', 'Owner',
        'Due Date', 'Status', 'Business Impact', 'Related Risk/Issue',
      ],
    ),
  ];

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StaffTeamScreen()));
        break;
      case 1:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TeamMeetingsScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const TeamTrainingAndBuildingScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const RecognitionAwardsScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const TeamStatusCheckScreen()));
        break;
      case 5:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TeamHandoverScreen()));
        break;
      case 6:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LessonsLearnedScreen()));
        break;
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
                  activeItemLabel: 'Project Team Activities'),
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
                          _buildSectionList(isMobile),
                          const SizedBox(height: 48),
                          _buildAiFooter(),
                        ],
                      ),
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Project Team Activities',
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
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: 0.3),
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
                Icon(Icons.groups, color: Color(0xFFFBBF24), size: 16),
                SizedBox(width: 6),
                Text(
                  'EXECUTION PHASE',
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
            'Project Team Activities',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A centralized workspace for building, organizing, and managing the project delivery team '
            'throughout execution. Ensures every team member understands their role, responsibilities, '
            'workload, and current status while giving project managers visibility into team performance, '
            'collaboration, and resource availability.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFCBD5E1),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroBadge(Icons.people, 'Team Directory'),
              _heroBadge(Icons.calendar_today, 'Meeting Intelligence'),
              _heroBadge(Icons.trending_up, 'Capacity & Workload'),
              _heroBadge(Icons.auto_awesome, 'AI Guidance Throughout'),
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
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
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

  // ── Metrics Row ────────────────────────────────────────────────────

  Widget _buildMetricsRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final metrics = [
        _MetricCard(
          label: 'Total Personnel',
          value: '$_totalPersonnel',
          icon: Icons.badge_outlined,
          color: const Color(0xFF4F46E5),
        ),
        _MetricCard(
          label: 'Defined Roles',
          value: '$_totalRoles',
          icon: Icons.work_outline,
          color: const Color(0xFF7C3AED),
        ),
        _MetricCard(
          label: 'Upcoming Meetings',
          value: '$_upcomingMeetings',
          icon: Icons.event_outlined,
          color: const Color(0xFF0891B2),
        ),
        _MetricCard(
          label: 'Active Sections',
          value: '7',
          icon: Icons.dashboard_outlined,
          color: const Color(0xFF10B981),
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

  // ── Section List (vertical cards, world-class design) ──────────────

  Widget _buildSectionList(bool isMobile) {
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '7 Sections',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._sections.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildSectionCard(s),
            )),
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
                // ── Gradient header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(section.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              section.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${section.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Body ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Features row
                      const Text(
                        'Key Capabilities',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: section.features.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: section.gradientStart.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 14, color: section.gradientStart),
                                const SizedBox(width: 6),
                                Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: section.gradientStart,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Data fields row
                      const Text(
                        'Required Data',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: section.dataFields.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              f,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Explore button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  section.gradientStart,
                                  section.gradientEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Explore Section',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward,
                                    color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.bookmark_border,
                              size: 18, color: Colors.grey[400]),
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

  // ── AI Footer ──────────────────────────────────────────────────────

  Widget _buildAiFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E6), Color(0xFFFFF7E6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Recommendations Throughout the Project Team Module',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            'Recommending staffing adjustments based on workload and resource utilization.',
            'Identifying resource shortages or over-allocation before they impact delivery.',
            'Highlighting missing skills or expertise required for upcoming work.',
            'Detecting recurring blockers and recommending mitigation actions.',
            'Summarizing meeting outcomes and automatically generating action items.',
            'Identifying overdue actions and accountability gaps.',
            'Monitoring team health trends and predicting potential delivery risks.',
            'Suggesting coaching, collaboration, or resource balancing opportunities.',
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E40AF),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────

class _HubSection {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final String description;
  final List<String> features;
  final List<String> dataFields;

  const _HubSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.description,
    required this.features,
    required this.dataFields,
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
