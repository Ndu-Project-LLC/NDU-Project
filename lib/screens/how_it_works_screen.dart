import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';
import 'package:ndu_project/screens/create_account_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// HOW IT WORKS — World-Class Standalone Page
/// ═══════════════════════════════════════════════════════════════════════════
///
/// A dedicated page explaining the Ndu Project delivery lifecycle:
/// Initiation → Planning → Execution & Launch, with detailed breakdowns
/// of each phase, methodology badges, and a visual timeline.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 96 : 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 48),
              _buildHeroSection(isDesktop),
              const SizedBox(height: 64),
              _buildPhaseTimeline(isDesktop),
              const SizedBox(height: 64),
              _buildDetailedPhases(isDesktop),
              const SizedBox(height: 64),
              _buildStepByStepSection(isDesktop),
              const SizedBox(height: 64),
              _buildMethodologySection(isDesktop),
              const SizedBox(height: 64),
              _buildWhyItWorksSection(isDesktop),
              const SizedBox(height: 64),
              _buildCTASection(context, isDesktop),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar with Logo ──────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Row(
      children: [
        Image.asset(
          'assets/images/Logo.png',
          height: isDesktop ? 70 : 50,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
          label: const Text('Back to Landing',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        const LandingSubpageActions(),
      ],
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────

  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 56 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF312E81),
            Color(0xFF4338CA),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill, color: Color(0xFFFBBF24), size: 18),
                SizedBox(width: 8),
                Text(
                  'HOW IT WORKS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Full Project Lifecycle Delivery',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ndu Project embodies a full project framework supporting Agile, Waterfall, and Hybrid methodologies. '
            'Whether you\'re managing a single project, a program of interconnected projects, or an entire portfolio, '
            'the Project Delivery Operating System (PDOS) scales seamlessly across all levels.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFC7D2FE),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroBadge(Icons.flash_on, 'Agile', const Color(0xFF10B981)),
              _heroBadge(Icons.water_drop, 'Waterfall', const Color(0xFFFBBF24)),
              _heroBadge(Icons.merge, 'Hybrid', const Color(0xFF8B5CF6)),
              _heroBadge(Icons.assignment, 'Projects', const Color(0xFFF59E0B)),
              _heroBadge(Icons.view_module, 'Programs', const Color(0xFF0EA5E9)),
              _heroBadge(Icons.dashboard, 'Portfolios', const Color(0xFFEC4899)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Phase Timeline (visual overview) ───────────────────────────────

  Widget _buildPhaseTimeline(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Delivery Journey',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Three structured phases, gated for quality — from initiation through launch.',
          style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6),
        ),
        const SizedBox(height: 40),
        _buildTimelineRow(isDesktop),
      ],
    );
  }

  Widget _buildTimelineRow(bool isDesktop) {
    final phases = [
      _PhaseTimelineItem(
        number: '01',
        title: 'Initiation',
        icon: Icons.flag_rounded,
        color: const Color(0xFFFBBF24),
        duration: 'Weeks 1–4',
      ),
      _PhaseTimelineItem(
        number: '02',
        title: 'Planning',
        icon: Icons.architecture_rounded,
        color: const Color(0xFF8B5CF6),
        duration: 'Weeks 4–12',
      ),
      _PhaseTimelineItem(
        number: '03',
        title: 'Execution & Launch',
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFF10B981),
        duration: 'Weeks 12+',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < phases.length; i++) ...[
            Expanded(child: _buildTimelineNode(phases[i])),
            if (i < phases.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: phases[i].color.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < phases.length; i++) ...[
          _buildTimelineNode(phases[i]),
          if (i < phases.length - 1) ...[
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward, color: Colors.white30, size: 24),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildTimelineNode(_PhaseTimelineItem item) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.color.withValues(alpha: 0.15),
            const Color(0xFF090909),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: item.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  item.color.withValues(alpha: 0.9),
                  item.color.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Text(
              item.number,
              style: TextStyle(
                color: item.color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            item.duration,
            style: TextStyle(
              color: item.color.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Detailed Phases ────────────────────────────────────────────────

  Widget _buildDetailedPhases(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phase Breakdown',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Each phase is gated for quality and completeness before the next begins.',
          style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6),
        ),
        const SizedBox(height: 40),
        _buildDetailedPhaseCard(
          number: '01',
          title: 'Initiation',
          icon: Icons.flag_rounded,
          color: const Color(0xFFFBBF24),
          description:
              'Charter approval, stakeholder alignment, cost-benefit analysis, and preferred solution selection — all gated before planning begins.',
          activities: [
            'Business case development',
            'Cost-benefit analysis & ROI modeling',
            'Core stakeholders identification',
            'Potential solutions evaluation',
            'Preferred solution selection',
            'Project charter approval',
          ],
          outcomes: [
            'Approved project charter',
            'Validated business case',
            'Selected delivery methodology',
            'Defined success criteria',
          ],
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 32),
        _buildDetailedPhaseCard(
          number: '02',
          title: 'Planning',
          icon: Icons.architecture_rounded,
          color: const Color(0xFF8B5CF6),
          description:
              'Full project framework: WBS, cost estimate, schedule, procurement, risk, quality, and organizational planning for projects, programs, and portfolios.',
          activities: [
            'Work breakdown structure (WBS)',
            'Cost estimating & budgeting',
            'Schedule development',
            'Procurement & contracting planning',
            'Risk management planning',
            'Quality management planning',
            'Organizational & team planning',
            'Front-end planning (FEP)',
          ],
          outcomes: [
            'Approved project baseline',
            'Complete WBS & schedule',
            'Risk register & mitigation plan',
            'Resource-loaded project plan',
          ],
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 32),
        _buildDetailedPhaseCard(
          number: '03',
          title: 'Execution & Launch',
          icon: Icons.rocket_launch_rounded,
          color: const Color(0xFF10B981),
          description:
              'Readiness-gated execution with real-time tracking, issue management, and structured closeout — from deliverables to demobilization.',
          activities: [
            'Team mobilization & staffing',
            'Progress tracking & reporting',
            'Issue & risk management',
            'Deliverable status updates',
            'Vendor & contract management',
            'Quality assurance',
            'Launch readiness assessment',
            'Project closeout & lessons learned',
          ],
          outcomes: [
            'Delivered project scope',
            'Closed contracts & vendors',
            'Realized benefits',
            'Lessons learned captured',
            'Team demobilization',
          ],
          isDesktop: isDesktop,
        ),
      ],
    );
  }

  Widget _buildDetailedPhaseCard({
    required String number,
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required List<String> activities,
    required List<String> outcomes,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            const Color(0xFF0C0C0C),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: color.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            'Phase $number',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 28),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildActivitiesList(activities, color)),
                const SizedBox(width: 24),
                Expanded(child: _buildOutcomesList(outcomes, color)),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActivitiesList(activities, color),
                const SizedBox(height: 20),
                _buildOutcomesList(outcomes, color),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList(List<String> activities, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: color, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Key Activities',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...activities.map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activity,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildOutcomesList(List<String> outcomes, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: color, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Phase Outcomes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...outcomes.map((outcome) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        outcome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ── Methodology Section ────────────────────────────────────────────

  Widget _buildMethodologySection(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 48 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF111111),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Methodology-Aware Delivery',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ndu Project adapts to your delivery approach — not the other way around.',
            style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.6),
          ),
          const SizedBox(height: 32),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                    child: _buildMethodologyCard(
                        'Agile',
                        Icons.flash_on,
                        const Color(0xFF10B981),
                        'Sprint planning, backlogs, Kanban boards, retrospectives, and velocity tracking for software and product teams.')),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildMethodologyCard(
                        'Waterfall',
                        Icons.water_drop,
                        const Color(0xFFFBBF24),
                        'Sequential phase-gated delivery with WBS, Gantt schedules, and milestone tracking for engineering and construction.')),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildMethodologyCard(
                        'Hybrid',
                        Icons.merge,
                        const Color(0xFF8B5CF6),
                        'Blended approach combining structured upfront planning with iterative execution for complex, multi-disciplinary projects.')),
              ],
            )
          else
            Column(
              children: [
                _buildMethodologyCard(
                    'Agile',
                    Icons.flash_on,
                    const Color(0xFF10B981),
                    'Sprint planning, backlogs, Kanban boards, retrospectives, and velocity tracking for software and product teams.'),
                const SizedBox(height: 16),
                _buildMethodologyCard(
                    'Waterfall',
                    Icons.water_drop,
                    const Color(0xFFFBBF24),
                    'Sequential phase-gated delivery with WBS, Gantt schedules, and milestone tracking for engineering and construction.'),
                const SizedBox(height: 16),
                _buildMethodologyCard(
                    'Hybrid',
                    Icons.merge,
                    const Color(0xFF8B5CF6),
                    'Blended approach combining structured upfront planning with iterative execution for complex, multi-disciplinary projects.'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMethodologyCard(
      String title, IconData icon, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Why It Works Section ───────────────────────────────────────────

  Widget _buildWhyItWorksSection(bool isDesktop) {
    final reasons = [
      _WhyItWorksItem(
        icon: Icons.verified_outlined,
        title: 'Phase-Gated Quality',
        description:
            'Every phase has readiness gates that ensure completeness before progressing — no skipped steps, no surprises.',
        color: const Color(0xFFFBBF24),
      ),
      _WhyItWorksItem(
        icon: Icons.insights_outlined,
        title: 'AI-Powered Guidance',
        description:
            'KAZ AI assistant embedded throughout — generating content, analyzing risks, and recommending next steps.',
        color: const Color(0xFFA855F7),
      ),
      _WhyItWorksItem(
        icon: Icons.layers_outlined,
        title: 'Scales Across Levels',
        description:
            'From individual projects to programs and portfolios — the PDOS framework adapts to your delivery scope.',
        color: const Color(0xFF10B981),
      ),
      _WhyItWorksItem(
        icon: Icons.integration_instructions,
        title: 'PDOS Integrated',
        description:
            'Seamlessly connects initiation, planning, execution, and launch into one unified delivery operating system.',
        color: const Color(0xFFF59E0B),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why It Works',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The principles that make Ndu Project\'s delivery model effective.',
          style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6),
        ),
        const SizedBox(height: 32),
        if (isDesktop)
          Row(
            children: [
              for (int i = 0; i < reasons.length; i++) ...[
                Expanded(child: _buildWhyItWorksCard(reasons[i])),
                if (i < reasons.length - 1) const SizedBox(width: 16),
              ],
            ],
          )
        else
          Column(
            children: [
              for (int i = 0; i < reasons.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(child: _buildWhyItWorksCard(reasons[i])),
                    const SizedBox(width: 12),
                    if (i + 1 < reasons.length)
                      Expanded(child: _buildWhyItWorksCard(reasons[i + 1]))
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
                if (i + 2 < reasons.length) const SizedBox(height: 16),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildWhyItWorksCard(_WhyItWorksItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF111111),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA Section ────────────────────────────────────────────────────

  Widget _buildCTASection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 48 : 28),
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to See It in Action?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start your project with Ndu Project and experience the full lifecycle delivery — from initiation through launch.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFA7F3D0),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                  );
                },
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('Start Your Project',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF064E3B),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.explore, color: Colors.white70, size: 18),
                label: const Text('Explore Use Cases',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ── Step-by-Step Project Delivery (moved from landing page) ─────────
// ── Step-by-Step Project Delivery (moved from landing page) ─────────
   Widget _buildStepByStepSection(bool isDesktop) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [ const SizedBox(height: 44),
  // ── Projects → Programs → Portfolios ──
  Text('How It Works — Project Delivers Results', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
  const SizedBox(height: 20),
  LayoutBuilder(builder: (context, c) {
  final horizontal = c.maxWidth >= 700;
  final cards = [
  _ScaleCard(num: '01', title: 'Projects', desc: 'Waterfall, Agile and Hybrid Project Delivery', icon: Icons.flag_rounded, color: const Color(0xFFFBBF24)),
  _ScaleCard(num: '02', title: 'Programs', desc: 'Multiple project implementation', icon: Icons.groups_rounded, color: const Color(0xFF8B5CF6)),
  _ScaleCard(num: '03', title: 'Portfolios', desc: 'Project and program stewardship in one glance', icon: Icons.rocket_launch_rounded, color: const Color(0xFF10B981)),
  ];
  if (horizontal) {
  return Row(children: [
  for (int i = 0; i < 3; i++) ...[
  if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.white.withValues(alpha: 0.4), size: 24)),
  Expanded(child: _scaleCardWidget(cards[i])),
  ],
  ]);
  }
  return Column(children: [
  for (int i = 0; i < 3; i++) ...[
  _scaleCardWidget(cards[i]),
  if (i < 2) const SizedBox(height: 12),
  ],
  ]);
  }),
  const SizedBox(height: 36),
  // ── 6-Step Delivery Process ──
  Text('Step-by-Step Project Delivery', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
  const SizedBox(height: 20),
  LayoutBuilder(builder: (context, c) {
  final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
  final w = cols == 1 ? c.maxWidth : (c.maxWidth - 40) / cols;
  final steps = [
  _DeliveryStep(num: '0', title: 'AI Assisted Due Diligence', color: const Color(0xFFFBBF24), items: ['Editable AI suggestions at every step that prompts the thought process', 'Continuity through all phases which eliminates fragmentation gap', 'Search access for similar applicable go-bys', 'Dynamic dashboards at project, program and portfolio levels', 'Core project delivery process integration with hints']),
  _DeliveryStep(num: '1', title: 'Start Right', color: const Color(0xFFF59E0B), items: ['Guided vital process to identify and analyze potential solutions, initial risks, internal and external stakeholders, IT and infrastructure, Project boundaries including in and out of scope, opportunities', 'Project requirements contracts, procurement and technical framework']),
  _DeliveryStep(num: '2', title: 'Meticulous Planning', color: const Color(0xFF10B981), items: ['Project framework, Team identification, Work Breakdown Structure', 'Safety, Security, Health, Environmental and Regulatory readiness', 'Quality requirements and early design planning', 'Execution planning, interface management, and set delivery plans', 'Cost, Schedule, Scope tracking, and change management alignment']),
  _DeliveryStep(num: '3', title: 'Build', color: const Color(0xFFF59E0B), items: ['Technical specifications, codes, and requirements mapping', 'Tool selection, onboarding, Design and engineering', 'Design and engineering execution (framework dependent)', 'Design work package development and execution mapping', 'Design implementation for success']),
  _DeliveryStep(num: '4', title: 'Execute', color: const Color(0xFF10B981), items: ['Work the plan, implement the design, build the product, facility, item', 'Monitor and control, cost, schedule and changes', 'Iterate as applicable', 'Plan for launch, develop handover plans, operations manuals, etc.']),
  _DeliveryStep(num: '5', title: 'Launch', color: const Color(0xFFF59E0B), items: ['Address punch list or technical debts', 'Commission and start up facility (waterfall). Final release (agile)', 'Close out contracts, vendor agreements, activate warranties', 'Hand over to operation or production team']),
  ];
  return Wrap(spacing: 20, runSpacing: 20, children: steps.map((s) => SizedBox(width: w, child: _deliveryStepCard(s))).toList());
  }),
  const SizedBox(height: 36),
  // ── 3 Pillar Cards ──
  LayoutBuilder(builder: (context, c) {
  final cols = c.maxWidth >= 900 ? 3 : 1;
  final w = cols == 1 ? c.maxWidth : (c.maxWidth - 40) / cols;
  final pillars = [
  _DeliveryStep(num: '', title: 'Proactive and Predictive Analytics', color: const Color(0xFFF59E0B), items: ['Identify risks, cost and schedule impacts in real time', 'Early warning indicators', 'Informed change management and stewardship', 'Variance tracking']),
  _DeliveryStep(num: '', title: 'Real-time Cross-functional Alignment', color: const Color(0xFF10B981), items: ['Keep every stakeholder and team aligned with live dashboards and governance', 'Stakeholder views', 'Approval workflows', 'Role-based access']),
  _DeliveryStep(num: '', title: 'Readiness-based Execution', color: const Color(0xFFF59E0B), items: ['Integrated process that ensures execution within plan launches', 'No-rushed execution', 'Visibility on changes and impact to scope', 'Stakeholder alignment']),
  ];
  return Wrap(spacing: 20, runSpacing: 20, children: pillars.map((p) => SizedBox(width: w, child: _deliveryStepCard(p))).toList());
  }),
  const SizedBox(height: 44),
       ],
     );
   }

  Widget _scaleCardWidget(_ScaleCard card) {
   return Container(
   padding: const EdgeInsets.all(20),
   decoration: BoxDecoration(
   color: card.color.withValues(alpha: 0.08),
   borderRadius: BorderRadius.circular(16),
   border: Border.all(color: card.color.withValues(alpha: 0.25)),
   ),
   child: Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
   Row(
   children: [
   Container(
   width: 36, height: 36,
   decoration: BoxDecoration(color: card.color, shape: BoxShape.circle),
   child: Center(child: Text(card.num, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
   ),
   const SizedBox(width: 12),
   Icon(card.icon, color: card.color, size: 22),
   ],
   ),
   const SizedBox(height: 12),
   Text(card.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
   const SizedBox(height: 6),
   Text(card.desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.4)),
   ],
   ),
   );
   }

Widget _deliveryStepCard(_DeliveryStep step) {
   return Container(
   padding: const EdgeInsets.all(20),
   decoration: BoxDecoration(
   color: step.color.withValues(alpha: 0.06),
   borderRadius: BorderRadius.circular(16),
   border: Border.all(color: step.color.withValues(alpha: 0.2)),
   ),
   child: Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
   Row(
   children: [
   if (step.num.isNotEmpty)
   Container(
   width: 32, height: 32,
   decoration: BoxDecoration(color: step.color, shape: BoxShape.circle),
   child: Center(child: Text(step.num, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
   )
   else
   Container(
   width: 32, height: 32,
   decoration: BoxDecoration(color: step.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
   child: Icon(Icons.bolt, color: step.color, size: 18),
   ),
   const SizedBox(width: 12),
   Expanded(
   child: Text(step.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: step.color)),
   ),
   ],
   ),
   const SizedBox(height: 12),
   ...step.items.map((item) => Padding(
   padding: const EdgeInsets.only(bottom: 6),
   child: Row(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
   Icon(Icons.circle, size: 5, color: step.color.withValues(alpha: 0.7)),
   const SizedBox(width: 8),
   Expanded(child: Text(item, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65), height: 1.4))),
   ],
   ),
   )),
   ],
   ),
   );
   }
}

class _PhaseTimelineItem {
  final String number;
  final String title;
  final IconData icon;
  final Color color;
  final String duration;

  const _PhaseTimelineItem({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.duration,
  });
}

class _WhyItWorksItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _WhyItWorksItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _ScaleCard {
  final String num;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _ScaleCard({required this.num, required this.title, required this.desc, required this.icon, required this.color});
}

class _DeliveryStep {
  final String num;
  final String title;
  final Color color;
  final List<String> items;
  const _DeliveryStep({required this.num, required this.title, required this.color, required this.items});
}
