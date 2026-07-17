/// NDU Project — World-Class Marketing Landing Page
///
/// Combines wireframe from Website Update.docx + nav structure from
/// Website Homepage Outline.pptx + use case strategy from Website Update
/// Suggestions.docx + inspiration from Jira, Asana, Monday.com.
///
/// 12 sections: Hero → Social Proof → Problem → Solution → How It Works →
/// Differentiators → Use Cases → KAZ AI → Benefits → Pricing → Services →
/// Final CTA → Footer
///
/// Plus: Careers page, Media/Blog links, Partner form

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Color System ──────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0E1A);
const _surface = Color(0xFF111827);
const _surfaceHigh = Color(0xFF1A2234);
const _surfaceCard = Color(0xFF151D2E);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);
const _border = Color(0xFF1E293B);
const _blue = Color(0xFF3B82F6);
const _blueLight = Color(0xFF60A5FA);
const _purple = Color(0xFF8B5CF6);
const _purpleLight = Color(0xFFA78BFA);
const _green = Color(0xFF10B981);
const _greenLight = Color(0xFF34D399);
const _gold = Color(0xFFFBBF24);
const _goldDeep = Color(0xFFD97706);
const _red = Color(0xFFEF4444);

class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LandingPageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Atmospheric background
          Positioned(top: -200, right: -200, child: _glowCircle(500, _blue.withValues(alpha: 0.06))),
          Positioned(bottom: -300, left: -200, child: _glowCircle(600, _purple.withValues(alpha: 0.04))),
          CustomScrollView(
            slivers: [
              _buildNav(context),
              SliverList(delegate: SliverChildListDelegate([
                _HeroSection(),
                _SocialProofSection(),
                _ProblemSection(),
                _SolutionSection(),
                _HowItWorksSection(),
                _DifferentiatorsSection(),
                _UseCasesSection(),
                _KazAISection(),
                _BenefitsSection(),
                _PricingSection(),
                _ServicesSection(),
                _FinalCTASection(),
                _FooterSection(),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])),
    );
  }

  SliverAppBar _buildNav(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 64,
      backgroundColor: _bg.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: _bg.withValues(alpha: 0.85),
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),              child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(children: [
                        Container(width: 32, height: 32, decoration: BoxDecoration(gradient: LinearGradient(colors: [_gold, _goldDeep]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.trending_up, color: Color(0xFF0A0E1A), size: 18)),
                        const SizedBox(width: 10),
                        Text('NDU', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: appFontFamily)),
                        Text(' Project', style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: appFontFamily)),
                      ]),
                      // Nav items (desktop)
                      if (MediaQuery.sizeOf(context).width > 900)
                        Row(children: [
                          _buildSolutionsDropdown(context),
                          _buildServicesDropdown(context),
                          _navLink('Why Ndu Project?', () => _scrollTo(context, 'why')),
                          _navLink('Pricing', () => _scrollTo(context, 'pricing')),
                          _buildResourcesDropdown(context),
                          _navLink('KAZ AI', () => _scrollTo(context, 'kaz')),
                        ]),
                      // Right side
                      Row(children: [
                        // Social icons
                        _socialIcon(Icons.facebook, 'https://facebook.com/nduproject'),
                        _socialIcon(Icons.camera_alt_outlined, 'https://instagram.com/nduproject'),
                        _socialIcon(Icons.business, 'https://linkedin.com/company/nduproject'),
                        _socialIcon(Icons.play_circle_outline, 'https://youtube.com/@nduproject'),
                        _socialIcon(Icons.music_note, 'https://tiktok.com/@nduproject'),
                        const SizedBox(width: 12),
                        TextButton(onPressed: () => context.go('/sign-in'), child: Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: appFontFamily))),
                        const SizedBox(width: 16),
                        _yellowButton('Start Your Project', () => context.go('/create-account')),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollTo(BuildContext context, String key) {
    final ctx = context;
    Scrollable.ensureVisible(
      ctx.findRenderObject() as BuildContext != null ? ctx : ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        child: Text(label, style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily)),
      ),
    );
  }

  Widget _buildSolutionsDropdown(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'how':
            _scrollTo(context, 'how');
            break;
          case 'diff':
            _scrollTo(context, 'diff');
            break;
          case 'usecases':
            _scrollTo(context, 'diff');
            break;
          case 'demo':
            _scrollTo(context, 'pricing');
            break;
          case 'partner':
            _scrollTo(context, 'services');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'how', child: Text('How It Works')),
        PopupMenuItem(value: 'diff', child: Text('Differentiator')),
        PopupMenuItem(value: 'usecases', child: Text('Use Cases')),
        PopupMenuItem(value: 'demo', child: Text('Demo')),
        PopupMenuItem(value: 'partner', child: Text('Partner with Us')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Solutions', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, color: _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesDropdown(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'services':
            _scrollTo(context, 'services');
            break;
          case 'delivery':
            _scrollTo(context, 'services');
            break;
          case 'training':
            _scrollTo(context, 'kaz');
            break;
          case 'consultation':
            _scrollTo(context, 'footer');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'services', child: Text('Services')),
        PopupMenuItem(value: 'delivery', child: Text('Project Delivery')),
        PopupMenuItem(value: 'training', child: Text('Training')),
        PopupMenuItem(value: 'consultation', child: Text('Consultation')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Services', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, color: _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesDropdown(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'contact':
            _scrollTo(context, 'footer');
            break;
          case 'support':
            _scrollTo(context, 'footer');
            break;
          case 'media':
            _launchUrl('https://nduproject.tech');
            break;
          case 'announcements':
            _scrollTo(context, 'footer');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'contact', child: Text('Contact Us')),
        PopupMenuItem(value: 'support', child: Text('Support')),
        PopupMenuItem(value: 'media', child: Text('Media')),
        PopupMenuItem(value: 'announcements', child: Text('Announcements')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Resources', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, color: _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, String url) {
    return IconButton(
      icon: Icon(icon, color: _textMuted, size: 16),
      onPressed: () => _launchUrl(url),
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(6),
    );
  }

  Widget _yellowButton(String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_gold, _goldDeep]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              label,
              style: TextStyle(
                color: _bg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 1: HERO
// ═════════════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('why'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Badge
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _blue.withValues(alpha: 0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, color: _blue, size: 14),
                const SizedBox(width: 6),
                Text('Project Delivery Operating System (PDOS)', style: TextStyle(color: _blueLight, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: appFontFamily)),
              ])),
              const SizedBox(height: 32),
              // Headline
              Text('42% of Projects Fail to meet original scope.\nFix Project Failure Before It Starts',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textPrimary, fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2, fontFamily: appFontFamily)),
              const SizedBox(height: 24),
              // Subheadline
              Text('Ndu Project is a Project Delivery Operating System — a SaaS platform that integrates AI, analytics, and human decision making to deliver projects from initiation through completion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 18, height: 1.6, fontFamily: appFontFamily)),
              const SizedBox(height: 32),
              // Value props
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _valueProp('Define, plan, and execute in one continuous system'),
                const SizedBox(width: 24),
                _valueProp('Predict risks, delays, and cost impacts before they happen'),
                const SizedBox(width: 24),
                _valueProp('Align teams and decisions in real time'),
              ]),
              const SizedBox(height: 40),
              // CTAs
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctaButton('Request a Demo', _blue, Colors.white, () => context.go('/create-account')),
                const SizedBox(width: 16),
                _ctaButton('See How It Works', Colors.transparent, _textPrimary, () {}, border: true),
              ]),
              const SizedBox(height: 60),
              // System diagram visual
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: _surfaceCard.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _phaseNode('Initiation', _blue),
                  _arrow(),
                  _phaseNode('Planning', _purple),
                  _arrow(),
                  _phaseNode('Execution', _green),
                  _arrow(),
                  _phaseNode('Launch', _gold),
                ]),
              ),
              // AI + Analytics + Human overlay
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _overlayChip('AI Guidance', _purple),
                _overlayChip('Analytics', _blue),
                _overlayChip('Human Decision', _green),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueProp(String text) {
    return Row(children: [Icon(Icons.check_circle, color: _green, size: 16), const SizedBox(width: 6), Text(text, style: TextStyle(color: _textSecondary, fontSize: 13, fontFamily: appFontFamily))]);
  }

  Widget _ctaButton(String label, Color bg, Color fg, VoidCallback onTap, {bool border = false}) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24), border: border ? Border.all(color: _border) : null, boxShadow: bg != Colors.transparent ? [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), child: Text(label, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: appFontFamily))),
      )),
    );
  }

  Widget _phaseNode(String label, Color color) {
    return Column(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))), child: Icon(Icons.circle, color: color, size: 12)),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: appFontFamily)),
    ]);
  }

  Widget _arrow() => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.arrow_forward, color: _textMuted, size: 20));

  Widget _overlayChip(String label, Color color) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: appFontFamily)));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 2: SOCIAL PROOF
// ═════════════════════════════════════════════════════════════════════════

class _SocialProofSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('Built from real-world delivery experience across global enterprises and high-growth organizations',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 15, fontFamily: appFontFamily)),
          const SizedBox(height: 24),
          // Trust badges
          Wrap(spacing: 32, runSpacing: 16, alignment: WrapAlignment.center, children: [
            _trustBadge('NSF I-Corps', Icons.science_outlined),
            _trustBadge('IdeaVillage Accelerator', Icons.rocket_launch_outlined),
            _trustBadge('13 Years ExxonMobil', Icons.local_gas_station_outlined),
            _trustBadge('4 Years IBM', Icons.computer_outlined),
            _trustBadge('34+ Research Interviews', Icons.people_outline),
          ]),
          const SizedBox(height: 32),
          // Trusted by
          Text('TRUSTED BY', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: appFontFamily)),
          const SizedBox(height: 16),
          Wrap(spacing: 24, runSpacing: 12, alignment: WrapAlignment.center, children: [
            _trustedBy('Start-ups'),
            _trustedBy('MSMEs'),
            _trustedBy('Consultants'),
            _trustedBy('Community Organizations'),
          ]),
        ]),
      )),
    );
  }

  Widget _trustBadge(String label, IconData icon) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)), child: Row(children: [Icon(icon, color: _gold, size: 16), const SizedBox(width: 8), Text(label, style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: appFontFamily))]));
  }

  Widget _trustedBy(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: _surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Text(label, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: appFontFamily)));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 3: THE PROBLEM
// ═════════════════════════════════════════════════════════════════════════

class _ProblemSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final problems = [
      ('No, or rushed, initiation and planning', Icons.timer_off_outlined, _red),
      ('Fragmented tools for different project stages', Icons.layers_outlined, _red),
      ('Misalignment between teams and decisions', Icons.group_off_outlined, _red),
      ('Reactive risk management', Icons.warning_amber_rounded, _red),
      ('Costly rework and delays', Icons.money_off_csred_outlined, _red),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _surface.withValues(alpha: 0.3),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('Projects Don\'t Fail in Execution.\nThey Fail Before Execution Begins',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.3, fontFamily: appFontFamily)),
          const SizedBox(height: 16),
          Text('Most project tools focus on tracking work after it starts. But by then, the most critical decisions have already been made… and often made poorly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 16, height: 1.6, fontFamily: appFontFamily)),
          const SizedBox(height: 40),
          Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: problems.map((p) => _problemCard(p.$1, p.$2, p.$3)).toList()),
          const SizedBox(height: 40),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withValues(alpha: 0.2))), child: Text('The issue isn\'t execution. It\'s the lack of a system governing the full lifecycle.', textAlign: TextAlign.center, style: TextStyle(color: _red, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: appFontFamily))),
        ]),
      )),
    );
  }

  Widget _problemCard(String text, IconData icon, Color color) {
    return Container(width: 220, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 4: THE SOLUTION (PDOS)
// ═════════════════════════════════════════════════════════════════════════

class _SolutionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final caps = [
      ('End-to-end delivery', 'Continuous lifecycle integration from initiation to launch', Icons.all_inclusive, _blue),
      ('AI-driven recommendations', 'Predictive analytics for risk and cost', Icons.psychology, _purple),
      ('Real-time alignment', 'Cross-functional teams in sync', Icons.sync, _green),
      ('Readiness-based execution', 'Gates ensure work starts right', Icons.verified_outlined, _gold),
    ];
    return Container(
      key: const Key('solution'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('A New Category: Project Delivery Operating System',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 16),
          Text('Ndu Project replaces disconnected tools with a unified system that governs how projects are defined, planned, and delivered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 16, height: 1.6, fontFamily: appFontFamily)),
          const SizedBox(height: 40),
          // Capability grid
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.0, children: caps.map((c) => _capCard(c.$1, c.$2, c.$3, c.$4)).toList()),
          const SizedBox(height: 40),
          // Comparison table
          Container(decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _surfaceHigh.withValues(alpha: 0.5), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))), child: Row(children: [Expanded(child: Text('Traditional Tools', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: appFontFamily))), Expanded(child: Text('Ndu Project (PDOS)', textAlign: TextAlign.center, style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: appFontFamily)))])),
            _compareRow('Focus on tracking', 'Governs full lifecycle'),
            _compareRow('Reactive insights', 'Predictive analytics'),
            _compareRow('Siloed workflows', 'Integrated system'),
            _compareRow('Execution-focused', 'Initiation-first approach'),
          ])),
        ]),
      )),
    );
  }

  Widget _capCard(String title, String desc, IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(height: 12), Text(title, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: appFontFamily)), const SizedBox(height: 6), Text(desc, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))]));
  }

  Widget _compareRow(String trad, String ndu) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))), child: Row(children: [Expanded(child: Row(children: [Icon(Icons.close, color: _red, size: 14), const SizedBox(width: 6), Text(trad, style: TextStyle(color: _textSecondary, fontSize: 13, fontFamily: appFontFamily))])), Expanded(child: Row(children: [Icon(Icons.check, color: _green, size: 14), const SizedBox(width: 6), Text(ndu, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: appFontFamily))]))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 5: HOW IT WORKS
// ═════════════════════════════════════════════════════════════════════════

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('01', 'Define', 'Structure strong project foundations with disciplined initiation', Icons.foundation_outlined, _blue),
      ('02', 'Align', 'Integrate planning across engineering, procurement, and execution', Icons.hub_outlined, _purple),
      ('03', 'Deliver', 'Execute with readiness gates, AI insights, and real-time alignment', Icons.rocket_launch_outlined, _green),
    ];
    return Container(
      key: const Key('how'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _surface.withValues(alpha: 0.3),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('How Ndu Project Delivers Results', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 8),
          Text('For projects, programs, and portfolios — Agile, Waterfall, and Hybrid', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 15, fontFamily: appFontFamily)),
          const SizedBox(height: 48),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: steps.map((s) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _stepCard(s.$1, s.$2, s.$3, s.$4, s.$5),
            if (s.$1 != '03') Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), child: Icon(Icons.arrow_forward, color: _textMuted, size: 28)),
          ])).toList()),
        ]),
      )),
    );
  }

  Widget _stepCard(String num, String title, String desc, IconData icon, Color color) {
    return Container(width: 240, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)), child: Column(children: [
      Text(num, style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 36, fontWeight: FontWeight.w900, fontFamily: appFontFamily)),
      const SizedBox(height: 8),
      Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
      const SizedBox(height: 16),
      Text(title, style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
      const SizedBox(height: 8),
      Text(desc, textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5, fontFamily: appFontFamily)),
    ]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 6: DIFFERENTIATORS
// ═════════════════════════════════════════════════════════════════════════

class _DifferentiatorsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('diff'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('Built Differently From Traditional Project Tools', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 32),
          // Value prop statement
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _purple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: _purple.withValues(alpha: 0.2))), child: Text('Our AI-powered end-to-end platform helps project managers and executives improve profitability through more effective delivery. It reduces implementation costs by 15–30% and cuts rework by 30–50% via structured initiation and planning. Unlike execution-focused tools that primarily track execution across only a few later phases, our platform drives disciplined, integrated delivery across the full project lifecycle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textPrimary, fontSize: 15, height: 1.7, fontFamily: appFontFamily))),
          const SizedBox(height: 32),
          // Stats
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stat('15-30%', 'Reduction in\nimplementation costs', _green),
            _stat('30-50%', 'Reduction in\nrework', _blue),
            _stat('20 yrs', 'Project delivery\nexpertise', _gold),
          ]),
          const SizedBox(height: 32),
          // Experience badges
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            _expBadge('ExxonMobil (Energy)', Icons.local_gas_station),
            _expBadge('IBM (IT)', Icons.computer),
            _expBadge('Education', Icons.school),
            _expBadge('Healthcare', Icons.local_hospital),
            _expBadge('Financial', Icons.account_balance),
            _expBadge('NSF I-Corps Research', Icons.science),
            _expBadge('IdeaVillage Accelerator', Icons.rocket_launch),
          ]),
        ]),
      )),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: appFontFamily)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))]));
  }

  Widget _expBadge(String label, IconData icon) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)), child: Row(children: [Icon(icon, color: _gold, size: 14), const SizedBox(width: 6), Text(label, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 7: USE CASES (Projects We Help You Deliver)
// ═════════════════════════════════════════════════════════════════════════

class _UseCasesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cases = [
      ('Launch New Products', 'Turn ideas into market-ready products with structured planning and AI guidance.', Icons.rocket_launch_outlined, _blue),
      ('Implement New Software', 'Deploy CRM, ERP, or operational systems with stakeholder alignment and risk management.', Icons.computer_outlined, _purple),
      ('Grow Your Business', 'Manage expansions, new services, and strategic initiatives with confidence.', Icons.trending_up, _green),
      ('Deliver Community Programs', 'Coordinate grants, events, and community projects from start to finish.', Icons.volunteer_activism_outlined, _gold),
      ('Manage Multiple Projects', 'Gain visibility across projects, programs, and portfolios.', Icons.dashboard_outlined, _blue),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _surface.withValues(alpha: 0.3),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('Projects We Help You Deliver', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 8),
          Text('Industry-agnostic — project delivery is the heart of every business', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 15, fontFamily: appFontFamily)),
          const SizedBox(height: 40),
          Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: cases.map((c) => _useCaseCard(c.$1, c.$2, c.$3, c.$4)).toList()),
        ]),
      )),
    );
  }

  Widget _useCaseCard(String title, String desc, IconData icon, Color color) {
    return Container(width: 280, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 16), Text(title, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: appFontFamily)), const SizedBox(height: 8), Text(desc, style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5, fontFamily: appFontFamily))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 8: KAZ AI
// ═════════════════════════════════════════════════════════════════════════

class _KazAISection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('kaz'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: _purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text('KAZ AI', style: TextStyle(color: _purpleLight, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: appFontFamily))),
            const SizedBox(height: 16),
            Text('Your knowledgeable project delivery sidekick', style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
            const SizedBox(height: 16),
            Text('KAZ AI provides intelligent suggestions, continuity across the project lifecycle, and core AI capabilities within the platform.', style: TextStyle(color: _textSecondary, fontSize: 15, height: 1.6, fontFamily: appFontFamily)),
            const SizedBox(height: 24),
            _aiFeature('AI Suggestions', 'Contextual recommendations at every project stage'),
            _aiFeature('Continuity', 'Knowledge carries across initiation, planning, and execution'),
            _aiFeature('Core Capabilities', 'Risk prediction, cost forecasting, schedule optimization'),
          ])),
          const SizedBox(width: 48),
          Expanded(child: Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withValues(alpha: 0.2))), child: Column(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple, _blue]), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.psychology, color: Colors.white, size: 32)),
            const SizedBox(height: 16),
            Text('KAZ AI', style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: appFontFamily)),
            const SizedBox(height: 4),
            Text('Project Delivery Intelligence', style: TextStyle(color: _purpleLight, fontSize: 13, fontFamily: appFontFamily)),
            const SizedBox(height: 24),
            _chatBubble('What risks should I watch for in Phase 2?'),
            _chatBubble('Suggest a mitigation plan for the supply chain delay.'),
            _chatBubble('How does this change impact my budget?'),
          ])),
          ),
        ]),
      )),
    );
  }

  Widget _aiFeature(String title, String desc) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle, color: _purple, size: 18), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: appFontFamily)), Text(desc, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))]))]));
  }

  Widget _chatBubble(String text) {
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.auto_awesome, color: _purple, size: 14), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: _textPrimary, fontSize: 12, fontFamily: appFontFamily)))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 9: BENEFITS
// ═════════════════════════════════════════════════════════════════════════

class _BenefitsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final benefits = [
      ('Reduced rework and cost overruns', Icons.savings_outlined, _green),
      ('Improved schedule predictability', Icons.schedule_outlined, _blue),
      ('Faster, higher-quality decisions', Icons.bolt_outlined, _gold),
      ('Increased project ROI', Icons.trending_up, _purple),
      ('Scalable, repeatable delivery model', Icons.expand_outlined, _blue),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _surface.withValues(alpha: 0.3),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('What You Achieve with PDOS', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 40),
          Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: benefits.map((b) => _benefitCard(b.$1, b.$2, b.$3)).toList()),
          const SizedBox(height: 32),
          Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: _green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _green.withValues(alpha: 0.2))), child: Text('Up to 30% reduction in rework', style: TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: appFontFamily))),
        ]),
      )),
    );
  }

  Widget _benefitCard(String text, IconData icon, Color color) {
    return Container(width: 260, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 14), Expanded(child: Text(text, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: appFontFamily)))]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 10: PRICING
// ═════════════════════════════════════════════════════════════════════════

class _PricingSection extends StatefulWidget {
  @override
  State<_PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<_PricingSection> {
  bool _isAnnual = false;

  // Gold/Yellow accent colors matching the design image
  static const _accentGold = Color(0xFFF59E0B);
  static const _accentGoldLight = Color(0xFFFEF3C7);
  static const _accentGoldDark = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pricing'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: Colors.white,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(children: [
          // Back navigation hint
          Align(alignment: Alignment.centerLeft, child: Row(children: [
            Icon(Icons.arrow_back, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('Select a plan that fits your needs', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontFamily: appFontFamily)),
          ])),
          const SizedBox(height: 32),

          // Main Title
          Text('Simple, Scalable Pricing for Every Level of Project Delivery',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text("Whether you're managing a single project or an enterprise portfolio, Ndu Project grows with your organization.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              height: 1.5,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 8),

          // Underline accent
          Container(width: 80, height: 3, decoration: BoxDecoration(color: _accentGold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 40),

          // Monthly/Annual Toggle Row
          Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text("Annual will save 1 month's payment",
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: appFontFamily)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => setState(() => _isAnnual = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isAnnual ? _accentGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Monthly',
                      style: TextStyle(
                        color: !_isAnnual ? Colors.white : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isAnnual = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isAnnual ? _accentGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Annual',
                      style: TextStyle(
                        color: _isAnnual ? Colors.white : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 32),

          // Pricing Cards Grid
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;
            final cardWidth = isMobile ? double.infinity : (constraints.maxWidth - 48) / 4;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildPricingCard(
                  context: context,
                  badgeText: 'Regular Project',
                  badgeColor: _accentGold,
                  description: 'No Fuss routine project delivered at a fraction of the cost',
                  price: _isAnnual ? '\$351' : '\$39',
                  period: _isAnnual ? '/year' : 'per month',
                  subText: 'First month free',
                  features: [
                    'Free for the first month',
                    '1 user',
                    'Full project delivery from initiation to Launch',
                    'Auto AI assist',
                    'One-time incremental AI assist per section',
                    'Limited Documentation features',
                    'Upgrade tier any time',
                  ],
                  isSelected: false,
                  width: cardWidth,
                ),
                _buildPricingCard(
                  context: context,
                  badgeText: 'Project',
                  badgeColor: _accentGold,
                  description: 'Robust project delivered at an affordable rate',
                  price: _isAnnual ? '\$1161' : '\$129',
                  period: _isAnnual ? '/year' : 'per month',
                  features: [
                    'Maximum 7 users included',
                    'Robust project delivery with full features including organization planning, design, change management, work breakdown structure, and more',
                    'Auto AI assist',
                    'One-time incremental AI assist per section',
                    'Document print out feature',
                    'Upgrade tier anytime',
                  ],
                  isSelected: false,
                  width: cardWidth,
                ),
                _buildPricingCard(
                  context: context,
                  badgeText: 'Program',
                  badgeColor: _accentGold,
                  showSelectedBadge: true,
                  description: 'Up to 3 projects at a discounted rate with interface management',
                  price: _isAnnual ? '\$2871' : '\$319',
                  period: _isAnnual ? '/year' : 'per month',
                  features: [
                    'Everything in Project',
                    'Maximum 12 users included',
                    'Monthly. Annual at a discount.',
                    'Interface management',
                    'Project dependency tracking',
                    'Program level reports for cost, schedule, scope tracking',
                  ],
                  isSelected: true,
                  width: cardWidth,
                ),
                _buildPricingCard(
                  context: context,
                  badgeText: 'Portfolio',
                  badgeColor: _accentGold,
                  description: 'Up to 9 projects at a bulk rate with integrated stewarding',
                  price: _isAnnual ? '\$6750' : '\$750',
                  period: _isAnnual ? '/year' : 'per month',
                  features: [
                    'Everything in Program',
                    'Maximum 24 users included',
                    'Portfolio level reports for cost, schedule, scope tracking',
                  ],
                  isSelected: false,
                  width: cardWidth,
                ),
              ],
            );
          }),
        ]),
      )),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String price,
    required String period,
    String? subText,
    required List<String> features,
    required bool isSelected,
    required double width,
    bool showSelectedBadge = false,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _accentGoldDark : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: _accentGold.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Badge row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentGoldLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badgeText,
              style: TextStyle(
                color: _accentGoldDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          if (showSelectedBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accentGoldLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentGold.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: _accentGoldDark, size: 14),
                const SizedBox(width: 4),
                Text('Selected',
                  style: TextStyle(
                    color: _accentGoldDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: appFontFamily,
                  ),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 16),

        // Description
        Text(description,
          style: TextStyle(
            color: const Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
            fontFamily: appFontFamily,
          ),
        ),
        const SizedBox(height: 20),

        // Price
        Row(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(price,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 36,
              fontWeight: FontWeight.w800,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(width: 6),
          Text(period,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontFamily: appFontFamily,
            ),
          ),
        ]),

        // Sub text (e.g., "First month free")
        if (subText != null) ...[
          const SizedBox(height: 4),
          Text(subText,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontFamily: appFontFamily,
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Features list
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _accentGold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(feature,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12.5,
                  height: 1.4,
                  fontFamily: appFontFamily,
                ),
              ),
            ),
          ]),
        )),

        const SizedBox(height: 24),

        // CTA Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.go('/create-account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isSelected ? Colors.white : _accentGoldDark,
              backgroundColor: isSelected ? _accentGold : Colors.transparent,
              side: BorderSide(color: isSelected ? _accentGoldDark : _accentGold),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isSelected ? 'Selected' : 'Select Plan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: appFontFamily,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 11: SERVICES
// ═════════════════════════════════════════════════════════════════════════

class _ServicesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('services'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _surface.withValues(alpha: 0.3),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Text('Services', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 8),
          Text('Beyond software — we help you deliver', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 15, fontFamily: appFontFamily)),
          const SizedBox(height: 40),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _serviceCard('Project Delivery', 'Access our PDOS platform with full lifecycle tools. Start a project now and move from initiation to launch.', Icons.assignment_outlined, _blue, 'Start a Project', () => context.go('/create-account')),
            const SizedBox(width: 20),
            _serviceCard('Training', 'Ensure individuals, students, and teams are knowledgeable on core project delivery processes. Request training or sign up.', Icons.school_outlined, _green, 'Request Training', () => _launchUrl('https://nduproject.tech')),
            const SizedBox(width: 20),
            _serviceCard('Consultation', 'Get expert help with your project needs. Book a consultation session with our delivery experts.', Icons.support_agent_outlined, _purple, 'Book Consultation', () => _launchUrl('https://calendar.app.google/aGQDFPpmEK9eDh5W6')),
          ]),
        ]),
      )),
    );
  }

  Widget _serviceCard(String title, String desc, IconData icon, Color color, String cta, VoidCallback onTap) {
    return Expanded(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 16),
      Text(title, style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
      const SizedBox(height: 8),
      Text(desc, style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5, fontFamily: appFontFamily)),
      const SizedBox(height: 20),
      TextButton(onPressed: onTap, child: Row(children: [Text(cta, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: appFontFamily)), const SizedBox(width: 4), Icon(Icons.arrow_forward, color: color, size: 14)])),
    ])));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION 12: FINAL CTA
// ═════════════════════════════════════════════════════════════════════════

class _FinalCTASection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 100),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(children: [
          Text('Ready to Transform How You Deliver Projects?', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5, fontFamily: appFontFamily)),
          const SizedBox(height: 16),
          Text('Move beyond tracking tools. Implement a system designed for real project success.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 17, fontFamily: appFontFamily)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_blue, _purple]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.3), blurRadius: 16)]), child: Material(color: Colors.transparent, child: InkWell(onTap: () => context.go('/create-account'), borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), child: Text('Start Your Project', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: appFontFamily)))))),
            const SizedBox(width: 16),
            Container(decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border)), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _launchUrl('mailto:contact@nduproject.com'), borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), child: Text('Contact Us', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: appFontFamily)))))),
          ]),
          const SizedBox(height: 24),
          Text('Execution Doesn\'t Fix Bad Starts.\nNdu Project ensures projects start right, and stay right.', textAlign: TextAlign.center, style: TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, height: 1.6, fontFamily: appFontFamily)),
        ]),
      )),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// FOOTER
// ═════════════════════════════════════════════════════════════════════════

class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('footer'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
      decoration: BoxDecoration(color: _surface, border: Border(top: BorderSide(color: _border))),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Brand column
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(gradient: LinearGradient(colors: [_gold, _goldDeep]), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.trending_up, color: Color(0xFF0A0E1A), size: 16)), const SizedBox(width: 8), Text('NDU', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: appFontFamily)), Text(' Project', style: TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: appFontFamily))]),
              const SizedBox(height: 12),
              Text('The Project Delivery Operating System', style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily)),
              const SizedBox(height: 16),
              // Social icons
              Row(children: [
                _footerSocial(Icons.facebook, 'https://facebook.com/nduproject'),
                _footerSocial(Icons.camera_alt_outlined, 'https://instagram.com/nduproject'),
                _footerSocial(Icons.business, 'https://linkedin.com/company/nduproject'),
                _footerSocial(Icons.play_circle_outline, 'https://youtube.com/@nduproject'),
                _footerSocial(Icons.music_note, 'https://tiktok.com/@nduproject'),
              ]),
            ])),
            // Product
            _footerCol('Product', ['Why Ndu Project', 'How It Works', 'Pricing', 'KAZ AI', 'Demo']),
            // Use Cases
            _footerCol('Use Cases', ['Launch Products', 'Software Implementation', 'Business Growth', 'Community Programs']),
            // About
            _footerCol('About', ['Our Story', 'Careers', 'Partners', 'Blog', 'Contact']),
            // Contact
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Contact', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
              const SizedBox(height: 12),
              _contactRow(Icons.email_outlined, 'contact@nduproject.com', () => _launchUrl('mailto:contact@nduproject.com')),
              _contactRow(Icons.phone_outlined, '+1 (225) 555-0199', () => _launchUrl('https://wa.me/12255550199')),
              _contactRow(Icons.location_on_outlined, '5635 Main Street, Suite A-160\nZachary, LA 70791', () {}),
              const SizedBox(height: 12),
              // Careers link
              InkWell(onTap: () => context.go('/careers'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _blue.withValues(alpha: 0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.work_outline, color: _blue, size: 14), const SizedBox(width: 6), Text('We\'re Hiring — View Careers', style: TextStyle(color: _blueLight, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: appFontFamily))]))),
            ])),
          ]),
          const SizedBox(height: 40),
          Divider(color: _border),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('© 2026 Ndu Project. All rights reserved.', style: TextStyle(color: _textMuted, fontSize: 11, fontFamily: appFontFamily)),
            Row(children: [TextButton(onPressed: () {}, child: Text('Privacy', style: TextStyle(color: _textMuted, fontSize: 11, fontFamily: appFontFamily))), TextButton(onPressed: () {}, child: Text('Terms', style: TextStyle(color: _textMuted, fontSize: 11, fontFamily: appFontFamily)))]),
          ]),
        ]),
      )),
    );
  }

  Widget _footerCol(String title, List<String> items) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
      const SizedBox(height: 12),
      ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextButton(onPressed: () {}, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero), child: Text(item, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))))),
    ]));
  }

  Widget _footerSocial(IconData icon, String url) {
    return Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(onPressed: () => _launchUrl(url), icon: Icon(icon, color: _textMuted, size: 18), constraints: const BoxConstraints(), padding: const EdgeInsets.all(6)));
  }

  Widget _contactRow(IconData icon, String text, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: onTap, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _textMuted, size: 14), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: _textSecondary, fontSize: 11, height: 1.4, fontFamily: appFontFamily)))])));
  }
}
