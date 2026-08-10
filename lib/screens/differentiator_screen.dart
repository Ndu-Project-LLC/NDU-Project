import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';

/// Differentiator — standalone subpage accessible from the
/// 'Why Ndu Project?' dropdown on the landing page. Shows the
/// "Minimize Rework. Maximize Profitability." section with the
/// comparison table, expertise section, key differentiator points,
/// and the integrated capabilities feature grid.
class DifferentiatorScreen extends StatelessWidget {
  const DifferentiatorScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DifferentiatorScreen()),
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
              _buildDifferentiatorsSection(isDesktop),
              const SizedBox(height: 56),
              _buildFeatureGridSection(isDesktop),
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

  // ── Differentiators Section ──────────────────────────────────────
  Widget _buildDifferentiatorsSection(bool wideLayout) {
    const comparisons = [
      _ComparisonRow(traditional: 'Focus on tracking', pdos: 'Governs full lifecycle'),
      _ComparisonRow(traditional: 'Reactive insights', pdos: 'Predictive analytics'),
      _ComparisonRow(traditional: 'Siloed workflows', pdos: 'Integrated system'),
      _ComparisonRow(traditional: 'Execution-focused', pdos: 'Initiation-first approach'),
    ];

    const keyPoints = [
      _DifferentiatorPoint(icon: Icons.account_tree_rounded, label: 'Lifecycle-native architecture'),
      _DifferentiatorPoint(icon: Icons.psychology_rounded, label: 'AI + human decision framework'),
      _DifferentiatorPoint(icon: Icons.gpp_maybe_rounded, label: 'Constraint-driven execution'),
      _DifferentiatorPoint(icon: Icons.hub_rounded, label: 'Real-time system alignment'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: wideLayout ? 64 : 28, vertical: wideLayout ? 80 : 56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121212), Color(0xFF050505)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 48,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minimize Rework. Maximize Profitability.',
            style: TextStyle(
              fontSize: wideLayout ? 38 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 20),
          // Value proposition
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
            ),
            child: const Text(
              'Our AI-powered end-to-end platform helps project managers and executives improve profitability through more effective delivery. It reduces implementation costs by 15–30% and cuts rework by 30–50% via structured initiation and planning. Unlike execution-focused tools that primarily track execution across only a few later phases, our platform drives disciplined, integrated delivery across the full project lifecycle.',
              style: TextStyle(fontSize: 15, color: Color(0xFFD6DCE5), height: 1.7),
            ),
          ),
          const SizedBox(height: 24),
          // Research & credibility
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _credibilityBadge('NSF I-Corps IdeaLaunch Research', Icons.science_outlined, const Color(0xFFFBBF24)),
              _credibilityBadge('Tens of Companies Surveyed', Icons.groups_outlined, const Color(0xFF10B981)),
              _credibilityBadge('IdeaVillage Accelerator', Icons.rocket_launch_outlined, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 16),
          // Expertise
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Nearly 20 Years of Project Delivery Expertise',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                SizedBox(height: 10),
                Text('Energy (ExxonMobil)  •  IT (IBM)  •  Education  •  Healthcare  •  Financial',
                    style: TextStyle(fontSize: 13, color: Colors.white70, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Comparison table
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Traditional Tools',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: LightModeColors.accent.withValues(alpha: 0.15),
                                ),
                                child: const Text(
                                  'PDOS',
                                  style: TextStyle(
                                    color: LightModeColors.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ndu Project',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data rows
                  ...comparisons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    row.traditional,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    row.pdos,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Key points
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: keyPoints.map((kp) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(kp.icon,
                        color: const Color(0xFFFBBF24), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      kp.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _credibilityBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature Grid Section ─────────────────────────────────────────
  Widget _buildFeatureGridSection(bool wideLayout) {
    const features = [
      'Quality Metrics', 'SSHER', 'Initiation', 'Requirements', 'Charter Development', 'Step by Step Project Delivery',
      'Contract Management', 'WBS Development', 'Integrated Schedule', 'Scope Tracking', 'Cost Estimation', 'Procurement',
      'Opportunities', 'Integrated Risk Management', 'Project Activities Log Tracker', 'Team Training', 'Scope Boundaries', 'Program and Portfolio Dashboards',
      'Baseline & Scope Tracking', 'Agile Ceremonies', 'Design and Engineering Hub', 'Program and Portfolio Interfaces', 'Role Based Approvals', 'Launch Readiness and Execution',
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: wideLayout ? 64 : 28, vertical: wideLayout ? 64 : 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E1A), Color(0xFF050810)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Integrated Capabilities Across the Full Lifecycle',
            style: TextStyle(
              fontSize: wideLayout ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every feature you need to govern projects from initiation through launch — all in one platform.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              final double spacing = 10;
              final int columns = maxWidth >= 1000 ? 6 : (maxWidth >= 600 ? 4 : (maxWidth >= 400 ? 3 : 2));
              final double itemWidth = (maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: features.map((label) {
                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  final String traditional;
  final String pdos;
  const _ComparisonRow({required this.traditional, required this.pdos});
}

class _DifferentiatorPoint {
  final IconData icon;
  final String label;
  const _DifferentiatorPoint({required this.icon, required this.label});
}
