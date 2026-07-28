import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';

/// Trusted By — standalone subpage accessible from the
/// 'Why Ndu Project?' dropdown on the landing page. Shows who the
/// platform is built for (Enterprises, SMBs, Delivery Teams,
/// Consultants), a foundation section with experience credentials,
/// and a CTA. Retains the app's dark theme.
class TrustedByScreen extends StatelessWidget {
  const TrustedByScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrustedByScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 96 : 24, vertical: 32),
                child: _buildTopBar(context, isDesktop),
              ),
              // Hero section
              _buildHeroSection(isDesktop),
              const SizedBox(height: 64),
              // Foundation section
              _buildFoundationSection(isDesktop),
              const SizedBox(height: 64),
              // CTA section
              _buildCTASection(context),
              const SizedBox(height: 48),
              // Footer
              _buildFooter(isDesktop),
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
    final orgs = [
      _OrgCard(
        icon: Icons.corporate_fare,
        title: 'Enterprises',
        desc: 'Managing capital or transformation programs at scale with rigorous oversight.',
      ),
      _OrgCard(
        icon: Icons.trending_up,
        title: 'SMBs',
        desc: 'Scaling rapidly through agile initiative execution and operational efficiency.',
      ),
      _OrgCard(
        icon: Icons.engineering,
        title: 'Delivery Teams',
        desc: 'Delivering infrastructure, digital, or complex operational initiatives.',
      ),
      _OrgCard(
        icon: Icons.groups,
        title: 'Consultants',
        desc: 'Adding strategic value and specialized expertise to high-stakes client endeavors.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 96 : 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1C30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Text(
                  'BUILT FOR STRATEGIC EXCELLENCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD3E4FE),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Headline
              Text(
                'Built for Organizations Delivering Simple to Complex Initiatives',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 48 : 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 8),
              // Underline accent
              Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFD8A42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 48),
              // Organization grid
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: orgs
                          .map((o) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _orgCard(o),
                                ),
                              ))
                          .toList(),
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: orgs
                          .map((o) => SizedBox(
                                width: double.infinity,
                                child: _orgCard(o),
                              ))
                          .toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orgCard(_OrgCard org) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFD8A42).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFD8A42).withOpacity(0.3)),
            ),
            child: Icon(org.icon, color: const Color(0xFFFD8A42), size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            org.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            org.desc,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Foundation Section ───────────────────────────────────────────
  Widget _buildFoundationSection(bool isDesktop) {
    final credentials = [
      _Credential(icon: Icons.work_outline, label: '13 years at ExxonMobil'),
      _Credential(icon: Icons.terminal_outlined, label: '4 years at IBM'),
      _Credential(icon: Icons.science_outlined, label: 'NSF I-Corps (34+ interviews)'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 96 : 24, vertical: 56),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Built From Experience.\nValidated by Research.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'NDU Project is informed by nearly two decades of hands-on project delivery experience across global enterprises and emerging organizations.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white54,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: credentials.map((c) => _credentialCard(c)).toList(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Built From Experience.\nValidated by Research.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'NDU Project is informed by nearly two decades of hands-on project delivery experience across global enterprises and emerging organizations.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white54,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...credentials.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _credentialCard(c),
                    )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _credentialCard(_Credential cred) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cred.icon, color: const Color(0xFFFD8A42), size: 20),
          const SizedBox(width: 12),
          Text(
            cred.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA Section ──────────────────────────────────────────────────
  Widget _buildCTASection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Transform How You Deliver Projects?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Move beyond tracking tools. Implement a system designed for real project success and executive oversight.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white54,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFD8A42),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 8,
                ),
                child: const Text(
                  'Start Your Project',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  side: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Contact Us',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────
  Widget _buildFooter(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'NDU Project',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '© 2024 NDU Project. Built for Strategic Excellence.',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 24,
                      children: [
                        'Privacy Policy',
                        'Terms of Service',
                        'Research Papers',
                        'Contact Support',
                      ]
                          .map((l) => Text(
                                l,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white54),
                              ))
                          .toList(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'NDU Project',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '© 2024 NDU Project. Built for Strategic Excellence.',
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        'Privacy Policy',
                        'Terms of Service',
                        'Research Papers',
                        'Contact Support',
                      ]
                          .map((l) => Text(
                                l,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white54),
                              ))
                          .toList(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrgCard {
  final IconData icon;
  final String title;
  final String desc;
  const _OrgCard({required this.icon, required this.title, required this.desc});
}

class _Credential {
  final IconData icon;
  final String label;
  const _Credential({required this.icon, required this.label});
}
