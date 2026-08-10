import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:ndu_project/screens/create_account_screen.dart';

/// KAZ AI — standalone subpage accessible from the 'Why Ndu Project?'
/// dropdown on the landing page. Shows the KAZ AI Project Delivery
/// Copilot hero, a mock chat interface, a 4-phase feature grid, and
/// a bottom CTA. Retains the app's dark theme (black background, white
/// text, yellow accent).
class KazAiScreen extends StatelessWidget {
  const KazAiScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KazAiScreen()),
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
              _buildTopBar(context, isDesktop),
              const SizedBox(height: 48),
              _buildHeroSection(isDesktop),
              const SizedBox(height: 80),
              _buildFeatureGrid(isDesktop),
              const SizedBox(height: 80),
              _buildCTASection(context),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, bool isDesktop) {
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

  // ── Hero Section ─────────────────────────────────────────────────
  Widget _buildHeroSection(bool isDesktop) {
    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildHeroLeft()),
              const SizedBox(width: 32),
              Expanded(flex: 7, child: _buildChatMockup()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroLeft(),
              const SizedBox(height: 32),
              _buildChatMockup(),
            ],
          );
  }

  Widget _buildHeroLeft() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC812),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.smart_toy, size: 18, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'KAZ AI PROJECT DELIVERY COPILOT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Headline
        const Text(
          'Customized AI Assistance\nthroughout project delivery',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        // Description
        const Text(
          'KAZ AI is wired into each workspace, turning your planning artifacts into conversational intelligence. Seamlessly bridge the gap between data and action.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        // Feature list
        _heroFeature(
          icon: Icons.check_circle_outline,
          iconBg: const Color(0xFFE6E8EA),
          iconColor: Colors.white,
          title: 'Context-aware answers',
          desc: 'Core project content prompts training and get answers citing the exact workspace.',
        ),
        const SizedBox(height: 16),
        _heroFeature(
          icon: Icons.bolt_outlined,
          iconBg: const Color(0xFFFD8A42).withOpacity(0.2),
          iconColor: const Color(0xFFFD8A42),
          title: 'Action acceleration (Smart Continuity)',
          titleColor: const Color(0xFFFD8A42),
          desc: 'KAZ AI integrates details to ensure continuity through all project phases, eliminating gaps.',
        ),
        const SizedBox(height: 16),
        _heroFeature(
          icon: Icons.insights_outlined,
          iconBg: const Color(0xFFE6E8EA),
          iconColor: Colors.white,
          title: 'Guided decisioning',
          desc: 'KAZ AI helps with details that make the project delivery process more robust.',
        ),
        const SizedBox(height: 24),
        // Governance note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.lock_outline, color: Color(0xFFFD8A42), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'KAZ AI follows your governance rules—keeping approvals tracked, content scoped, and data secure.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroFeature({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
    Color? titleColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Chat Mockup ──────────────────────────────────────────────────
  Widget _buildChatMockup() {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF131B2E),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Color(0xFFFFC812), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'KAZ AI Live Assistant',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Always-on copilot across your program',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Chat area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User bubble
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E8EA),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'EXECUTIVE USER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'KAZ AI, what are the potential risks with launching a virtual fitting room in the APAC market?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // AI bubble 1 — Risk analysis
                    Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.smart_toy, size: 16, color: Color(0xFFFD8A42)),
                              SizedBox(width: 6),
                              Text(
                                'KAZ AI RISK ANALYSIS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFD8A42),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Based on your portfolio documentation, here are the critical risk themes to monitor:',
                            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          _riskRow('Data Privacy Compliance (GDPR/PIPL)', 'CRITICAL', const Color(0xFFBA1A1A)),
                          const SizedBox(height: 8),
                          _riskRow('Store Associate Adoption', 'MEDIUM', const Color(0xFFFD8A42)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // AI bubble 2 — Mitigation Playbook
                    Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.description_outlined, size: 16, color: Color(0xFFFD8A42)),
                              SizedBox(width: 6),
                              Text(
                                'MITIGATION PLAYBOOK DRAFTED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFD8A42),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _bullet('Schedule security validation with Regional IT.'),
                          _bullet('Align change management enablement with local HR.'),
                          _bullet('Add rollout checkpoints for pilot markets.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.white38, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Text(
                        "Ask KAZ AI to accelerate this week's milestone...",
                        style: TextStyle(fontSize: 13, color: Colors.white38),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFD8A42),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskRow(String label, String level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          Text(
            level,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '• $text',
        style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
      ),
    );
  }

  // ── 4-Phase Feature Grid ─────────────────────────────────────────
  Widget _buildFeatureGrid(bool isDesktop) {
    final phases = [
      _KazPhase(
        num: '01',
        icon: Icons.rocket_launch_outlined,
        title: 'KAZ AI in Initiation',
        desc: 'Analyze potential solutions, early risks per solution, and IT infrastructure considerations. Bridge stakeholder alignment early with AI-driven summaries.',
        tags: ['Project Charter', 'Early Contracts'],
      ),
      _KazPhase(
        num: '02',
        icon: Icons.architecture_outlined,
        title: 'KAZ AI in Planning',
        desc: 'WBS development, organizational planning, team building, and cost schedule estimation. Lessons learned and SSHER integration automated.',
        tags: ['Baseline', 'Scope Tracking'],
      ),
      _KazPhase(
        num: '03',
        icon: Icons.draw_outlined,
        title: 'KAZ AI in Design',
        desc: 'Precise code mapping and API integration analysis. Validation against design output and engineering standards to ensure high-fidelity implementation.',
        tags: ['API Docs', 'Engineering'],
      ),
      _KazPhase(
        num: '04',
        icon: Icons.task_alt_outlined,
        title: 'KAZ AI in Execution',
        desc: 'Execution work package implementation, real-time scope tracking, and change management automation for agile delivery environments.',
        tags: ['Completed Scope', 'Start up'],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading
        Center(
          child: Column(
            children: const [
              Text(
                'Implement every phase of the project, program\nand portfolio with confidence',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Guided and prompted workflows that incorporate pertinent project management processes, procedures, and expertise across the entire lifecycle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white60,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Grid
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: phases
                    .map((p) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _phaseCard(p),
                          ),
                        ))
                    .toList(),
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: phases
                    .map((p) => SizedBox(
                          width: double.infinity,
                          child: _phaseCard(p),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _phaseCard(_KazPhase phase) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase.num,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.06),
                  height: 1,
                ),
              ),
              Icon(phase.icon, color: const Color(0xFFFFC812), size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            phase.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            phase.desc,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white60,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: phase.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── CTA Section ──────────────────────────────────────────────────
  Widget _buildCTASection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131B2E), Color(0xFF0B1C30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Experience KAZ AI?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start your project with Ndu Project and let KAZ AI guide you through every phase — from initiation through launch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  backgroundColor: const Color(0xFFFFC812),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.explore, color: Colors.white70, size: 18),
                label: const Text('Back to Landing',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KazPhase {
  final String num;
  final IconData icon;
  final String title;
  final String desc;
  final List<String> tags;

  const _KazPhase({
    required this.num,
    required this.icon,
    required this.title,
    required this.desc,
    required this.tags,
  });
}
