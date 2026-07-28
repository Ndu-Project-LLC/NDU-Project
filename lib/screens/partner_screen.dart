import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';

class PartnerScreen extends StatelessWidget {
  const PartnerScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PartnerScreen()),
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
            horizontal: isDesktop ? 96 : 24,
            vertical: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 32),
              _buildHero(),
              const SizedBox(height: 64),
              _buildSection('Why Partner with Ndu Project?', _whyPartner()),
              const SizedBox(height: 56),
              _buildSection('Partnership Opportunities', _partnershipOpportunities()),
              const SizedBox(height: 56),
              _buildSection('Partner Benefits', _partnerBenefits()),
              const SizedBox(height: 56),
              _buildSection('How We Work Together', _howWeWork()),
              const SizedBox(height: 56),
              _buildSection("Who We're Looking For", _whoWeLookFor()),
              const SizedBox(height: 56),
              _buildCTA(context),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Row(
      children: [
        // Ndu Project logo
        Image.asset(
          'assets/images/Logo.png',
          height: isDesktop ? 70 : 50,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        _buildBackButton(context),
        const SizedBox(width: 12),
        const LandingSubpageActions(),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
      label: const Text('Back', style: TextStyle(color: Colors.white70, fontSize: 14)),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.handshake, color: Color(0xFF34D399), size: 16),
              SizedBox(width: 8),
              Text('Partner With Ndu Project', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Build the Future of Project Delivery Together',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15, letterSpacing: -0.4),
        ),
        const SizedBox(height: 16),
        const Text(
          "Whether you're a consulting firm, technology provider, university, accelerator, or industry association, we're building a partner ecosystem that helps organizations deliver projects more successfully.\n\n"
          'Ndu Project is an AI-powered Project Delivery Operating System (PDOS) that helps organizations plan smarter, execute confidently, and improve project outcomes through integrated workflows, intelligent guidance, and explainable AI.\n\n'
          'Together, we can transform how projects are delivered.',
          style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.7),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _ctaButton('Become a Partner', const Color(0xFF10B981), true),
            _ctaButton('Schedule a Conversation', Colors.transparent, false),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
        const SizedBox(height: 24),
        content,
      ],
    );
  }

  Widget _whyPartner() {
    final items = [
      _PItem(icon: Icons.expand, title: 'Expand Your Service Offerings', desc: 'Enhance your existing consulting or technology services with a modern AI-powered project delivery platform.'),
      _PItem(icon: Icons.star, title: 'Deliver Greater Client Value', desc: 'Help clients improve project planning, reduce delivery risk, standardize processes, and increase project success rates.'),
      _PItem(icon: Icons.monetization_on, title: 'Generate New Revenue Opportunities', desc: 'Create recurring revenue through implementation services, training, referrals, and strategic partnerships.'),
      _PItem(icon: Icons.lightbulb, title: 'Co-Innovate', desc: 'Collaborate with our product team to shape future capabilities based on real customer needs.'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 800 ? 2 : 1;
      final w = cols == 1 ? c.maxWidth : (c.maxWidth - 20) / 2;
      return Wrap(
        spacing: 20, runSpacing: 20,
        children: items.map((i) => SizedBox(width: w, child: _pCard(i))).toList(),
      );
    });
  }

  Widget _partnershipOpportunities() {
    final opps = [
      _POpp(title: 'Project Management Consulting Firms', desc: 'Help your clients establish repeatable delivery processes while leveraging Ndu Project as the technology platform.', tags: ['PM Consulting Firms', 'PMO Advisory Firms', 'Business Transformation Consultants', 'Digital Transformation Consultants'], color: const Color(0xFFFBBF24)),
      _POpp(title: 'Technology & Systems Integrators', desc: 'Expand your implementation portfolio by integrating Ndu Project with your clients\' technology ecosystem.', tags: ['Microsoft 365', 'Jira', 'Monday.com', 'Asana', 'Salesforce', 'ERP systems', 'HR platforms'], color: const Color(0xFF8B5CF6)),
      _POpp(title: 'Universities & Educational Institutions', desc: 'Prepare students and professionals with practical project delivery experience through classroom licensing, research collaboration, and workforce development.', tags: ['Student access', 'Faculty collaboration', 'Capstone projects', 'Certification preparation', 'Research initiatives'], color: const Color(0xFF10B981)),
      _POpp(title: 'Government & Economic Development', desc: 'Support small businesses, nonprofits, and public agencies by providing access to structured project delivery tools.', tags: ['Small business support', 'Workforce development', 'Innovation hubs', 'Economic development', 'Public sector transformation'], color: const Color(0xFF06B6D4)),
      _POpp(title: 'Industry Associations', desc: 'Deliver additional value to your members through project delivery resources, workshops, webinars, and preferred access.', tags: ['Construction Associations', 'Manufacturing Associations', 'Healthcare Organizations', 'Technology Councils', 'Chambers of Commerce'], color: const Color(0xFFF59E0B)),
      _POpp(title: 'Startup Accelerators & Incubators', desc: 'Equip founders with structured project planning and execution capabilities to improve startup execution and investor readiness.', tags: ['Startup onboarding', 'Portfolio support', 'Workshops', 'Office hours', 'Mentor resources'], color: const Color(0xFFEC4899)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
      final w = cols == 1 ? c.maxWidth : (c.maxWidth - 40) / cols;
      return Wrap(
        spacing: 20, runSpacing: 20,
        children: opps.map((o) => SizedBox(width: w, child: _oppCard(o))).toList(),
      );
    });
  }

  Widget _partnerBenefits() {
    final benefits = [
      'Early access to new features', 'Dedicated partner support', 'Joint marketing opportunities',
      'Co-hosted webinars and events', 'Referral incentives', 'Implementation resources',
      'Product training and certification', 'Partner directory listing', 'Co-branded customer success stories',
    ];
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15))),
      child: Wrap(
        spacing: 16, runSpacing: 12,
        children: benefits.map((b) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 8),
            Text(b, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _howWeWork() {
    final steps = [
      _Step(num: '1', title: 'Connect', desc: 'Meet with our team to understand your goals and identify opportunities.'),
      _Step(num: '2', title: 'Explore', desc: 'Review partnership models and determine the best fit.'),
      _Step(num: '3', title: 'Onboard', desc: 'Receive training, resources, and access to the partner portal.'),
      _Step(num: '4', title: 'Grow', desc: 'Collaborate on customer engagements, marketing initiatives, and product innovation.'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 800 ? 4 : (c.maxWidth >= 500 ? 2 : 1);
      final w = cols == 1 ? c.maxWidth : (c.maxWidth - 60) / cols;
      return Wrap(
        spacing: 20, runSpacing: 20,
        children: steps.map((s) => SizedBox(width: w, child: _stepCard(s))).toList(),
      );
    });
  }

  Widget _whoWeLookFor() {
    final orgs = [
      'Project Management Consulting Firms', 'PMO Service Providers', 'Technology Consulting Firms',
      'System Integrators', 'Universities', 'Business Schools', 'Startup Accelerators',
      'Economic Development Organizations', 'Industry Associations', 'Independent PM Professionals',
      'AI and Technology Partners',
    ];
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: orgs.map((o) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(o, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Widget _buildCTA(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Let's Build Better Projects Together", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('The future of project delivery is collaborative, intelligent, and connected. If your organization is passionate about helping teams deliver better outcomes, we\'d love to explore how we can work together.', style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.6)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              _ctaButton('Become a Partner', Colors.white, true, textColor: const Color(0xFF059669)),
              _ctaButton('Schedule a Discovery Call', Colors.transparent, false, border: true),
              _ctaButton('Download the Partner Guide', Colors.transparent, false, border: true),
              _ctaButton('Contact Our Partnerships Team', Colors.transparent, false, border: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctaButton(String label, Color bg, bool filled, {Color? textColor, bool border = false}) {
    if (filled) {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: textColor ?? Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
    }
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: border ? Colors.white.withValues(alpha: 0.3) : Colors.transparent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _pCard(_PItem item) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: item.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: item.color, size: 22)),
        const SizedBox(height: 14),
        Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Text(item.desc, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65), height: 1.5)),
      ]),
    );
  }

  Widget _oppCard(_POpp opp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: opp.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: opp.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(opp.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: opp.color)),
        const SizedBox(height: 8),
        Text(opp.desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 4, runSpacing: 4, children: opp.tags.map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: opp.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(t, style: TextStyle(fontSize: 10, color: opp.color.withValues(alpha: 0.9))),
        )).toList()),
      ]),
    );
  }

  Widget _stepCard(_Step step) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle), child: Center(child: Text(step.num, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)))),
        const SizedBox(height: 12),
        Text(step.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text(step.desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
      ]),
    );
  }
}

class _PItem {
  final IconData icon; final String title; final String desc; final Color color;
  const _PItem({required this.icon, required this.title, required this.desc, this.color = const Color(0xFFFBBF24)});
}

class _POpp {
  final String title; final String desc; final List<String> tags; final Color color;
  const _POpp({required this.title, required this.desc, required this.tags, required this.color});
}

class _Step {
  final String num; final String title; final String desc;
  const _Step({required this.num, required this.title, required this.desc});
}
