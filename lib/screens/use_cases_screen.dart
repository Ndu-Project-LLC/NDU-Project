import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/landing_subpage_action_bar.dart';

class UseCasesScreen extends StatelessWidget {
  const UseCasesScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UseCasesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 96 : 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 32),
              _header(),
              const SizedBox(height: 48),
              _exploreChips(),
              const SizedBox(height: 48),
              _sectionTitle('Explore by Industry'),
              const SizedBox(height: 24),
              _industryGrid(context, isDesktop),
              const SizedBox(height: 56),
              _sectionTitle('Explore by Delivery Methodology'),
              const SizedBox(height: 24),
              _methodologyGrid(context, isDesktop),
              const SizedBox(height: 56),
              _sectionTitle('Program & Portfolio Demonstrations'),
              const SizedBox(height: 8),
              const Text('See how Ndu Project scales beyond individual projects to support coordinated programs and enterprise portfolios.',
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.5)),
              const SizedBox(height: 24),
              _programPortfolioRow(isDesktop),
              const SizedBox(height: 56),
              _sectionTitle('Demo Center'),
              const SizedBox(height: 8),
              const Text('Experience realistic project delivery scenarios that demonstrate how Ndu Project supports planning, execution, monitoring, and reporting across projects, programs, and portfolios.',
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.5)),
              const SizedBox(height: 24),
              _sectionSubTitle('Project Demonstrations'),
              const SizedBox(height: 16),
              _demoGrid(context, isDesktop),
              const SizedBox(height: 32),
              _sectionSubTitle('Program Demonstration'),
              const SizedBox(height: 16),
              _demoCard(_Demo('Enterprise Digital Transformation Program', 'Multi-Industry', 'Program', Icons.view_module, const Color(0xFF0EA5E9),
                ['Program Dashboard', 'Interface Management', 'Cross Project Dependencies', 'Benefits Tracking', 'Shared Resources', 'Program Timeline', 'Executive Reporting'])),
              const SizedBox(height: 24),
              _sectionSubTitle('Portfolio Demonstration'),
              const SizedBox(height: 16),
              _demoCard(_Demo('Strategic Enterprise Portfolio', 'Enterprise', 'Portfolio', Icons.dashboard, const Color(0xFFEC4899),
                ['Portfolio Dashboard', 'Executive KPIs', 'Portfolio Heat Maps', 'Resource Capacity', 'Financial Performance', 'Strategic Alignment', 'Portfolio Prioritization', 'Cross Program Reporting'])),
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
        Image.asset(
          'assets/images/Logo.png',
          height: isDesktop ? 70 : 50,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        _backButton(context),
        const SizedBox(width: 12),
        const LandingSubpageActions(),
      ],
    );
  }

  Widget _backButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
      label: const Text('Back to Landing', style: TextStyle(color: Colors.white70, fontSize: 14)),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.explore, color: Color(0xFF22D3EE), size: 16),
              SizedBox(width: 8),
              Text('Use Cases & Demo Center', style: TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Project Delivery for Every Industry', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
        const SizedBox(height: 14),
        const Text(
          'Whether you\'re delivering software, constructing facilities, implementing enterprise systems, or launching strategic initiatives, Ndu Project provides the structure, visibility, and AI-powered guidance to improve project outcomes.',
          style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
        ),
      ],
    );
  }

  Widget _exploreChips() {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _chip('Explore by Industry', Icons.business),
      _chip('Explore by Methodology', Icons.merge_type),
      _chip('Explore Program and Portfolio Delivery', Icons.dashboard),
    ]);
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF06B6D4).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFF22D3EE)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF22D3EE))),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white));
  }

  Widget _sectionSubTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70));
  }

  Widget _industryGrid(BuildContext context, bool isDesktop) {
    final industries = [
      _Industry(icon: Icons.bolt, name: 'Energy', demo: 'Solar Farm Expansion', color: const Color(0xFFF59E0B), highlights: ['Business Case', 'WBS', 'Procurement', 'Contractor Mgmt', 'Schedule', 'Risk Register', 'Exec Dashboard']),
      _Industry(icon: Icons.computer, name: 'Information Technology', demo: 'AI Customer Support Platform', color: const Color(0xFFFBBF24), highlights: ['Business Case', 'Frontend Planning', 'Sprint Planning', 'Kanban Board', 'Burndown Charts', 'Release Planning']),
      _Industry(icon: Icons.local_hospital, name: 'Healthcare', demo: 'Hospital Imaging Center Construction', color: const Color(0xFFEF4444), highlights: ['Regulatory Planning', 'Equipment Procurement', 'Construction Tracking', 'Budget Control', 'Commissioning']),
      _Industry(icon: Icons.school, name: 'Education', demo: 'University Mobile Student App', color: const Color(0xFF10B981), highlights: ['Product Discovery', 'Sprint Planning', 'Stakeholder Mgmt', 'UAT']),
      _Industry(icon: Icons.factory, name: 'Manufacturing', demo: 'Smart Manufacturing Transformation', color: const Color(0xFF8B5CF6), highlights: ['Facility Upgrades', 'IoT Integration', 'ERP Integration', 'Agile Software Delivery']),
      _Industry(icon: Icons.account_balance, name: 'Government', demo: 'City Infrastructure Modernization', color: const Color(0xFF06B6D4), highlights: ['Capital Planning', 'Procurement', 'Public Stakeholders', 'Executive Reporting']),
    ];
    final cols = isDesktop ? 3 : 1;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = cols == 1 ? double.infinity : (screenWidth - 240) / cols;
    return Wrap(spacing: 20, runSpacing: 20, children: industries.map((i) => SizedBox(width: cardWidth, child: _industryCard(i))).toList());
  }

  Widget _industryCard(_Industry ind) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ind.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: ind.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: ind.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(ind.icon, color: ind.color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(ind.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ind.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('Featured Demo: ${ind.demo}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ind.color))),
        const SizedBox(height: 12),
        Text('Highlights', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: ind.highlights.map((h) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
          child: Text(h, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))))).toList()),
        const SizedBox(height: 14),
        Center(child: TextButton(onPressed: () {}, style: TextButton.styleFrom(foregroundColor: ind.color),
          child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('View Project Demo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(width: 4), const Icon(Icons.arrow_forward, size: 14)]))),
      ]),
    );
  }

  Widget _methodologyGrid(BuildContext context, bool isDesktop) {
    final meths = [
      _Methodology(name: 'Waterfall Projects', desc: 'Designed for engineering, construction, infrastructure, capital projects, and regulated industries.', demos: ['Solar Farm Expansion', 'Hospital Imaging Center Construction'], color: const Color(0xFFFBBF24)),
      _Methodology(name: 'Agile Projects', desc: 'Built for software development, innovation, and product teams.', demos: ['AI Customer Support Platform', 'University Mobile Student App'], color: const Color(0xFF10B981)),
      _Methodology(name: 'Hybrid Projects', desc: 'Combines structured planning with iterative execution.', demos: ['Smart Manufacturing Transformation', 'Enterprise EHR Modernization'], color: const Color(0xFF8B5CF6)),
    ];
    final cols = isDesktop ? 3 : 1;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = cols == 1 ? double.infinity : (screenWidth - 240) / cols;
    return Wrap(spacing: 20, runSpacing: 20, children: meths.map((m) => SizedBox(width: cardWidth, child: _methodologyCard(m))).toList());
  }

  Widget _methodologyCard(_Methodology m) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: m.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: m.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.color)),
        const SizedBox(height: 8),
        Text(m.desc, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
        const SizedBox(height: 12),
        Text('Available Demos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 6),
        ...m.demos.map((d) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
          Icon(Icons.check_circle_outline, size: 12, color: m.color.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(d, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        ]))),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: () {}, style: TextButton.styleFrom(foregroundColor: m.color),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text('View ${m.name.split(' ')[0]} Demos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(width: 4), const Icon(Icons.arrow_forward, size: 14)]))),
      ]),
    );
  }

  Widget _programPortfolioRow(bool isDesktop) {
    if (isDesktop) {
      return Row(children: [Expanded(child: _programCard()), const SizedBox(width: 20), Expanded(child: _portfolioCard())]);
    }
    return Column(children: [_programCard(), const SizedBox(height: 20), _portfolioCard()]);
  }

  Widget _programCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.view_module, color: Color(0xFF0EA5E9), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Program Management Demo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text('Digital Transformation Program', style: TextStyle(fontSize: 12, color: const Color(0xFF0EA5E9))),
          ])),
        ]),
        const SizedBox(height: 12),
        const Text('Manage multiple related projects through a single program workspace while maintaining visibility into dependencies, milestones, and benefits realization.', style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.5)),
        const SizedBox(height: 12),
        const Text('You\'ll Experience', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: ['Program Dashboard', 'Program Roadmap', 'Cross Project Dependencies', 'Interface Management', 'Integrated Milestone Tracking', 'Benefits Realization', 'Resource Coordination', 'Program Risk Register', 'Program Financial Summary', 'Executive Status Reporting'].map((item) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(item, style: const TextStyle(fontSize: 10, color: Color(0xFF7DD3FC))))).toList()),
        const SizedBox(height: 16),
        Center(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          child: const Text('View Program Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
      ]),
    );
  }

  Widget _portfolioCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.dashboard, color: Color(0xFFEC4899), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Portfolio Management Demo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text('Enterprise Strategic Portfolio', style: TextStyle(fontSize: 12, color: const Color(0xFFEC4899))),
          ])),
        ]),
        const SizedBox(height: 12),
        const Text('Monitor organizational initiatives across departments while aligning investments with strategic objectives.', style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.5)),
        const SizedBox(height: 12),
        const Text('You\'ll Experience', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: ['Portfolio Dashboard', 'Strategic Alignment', 'Portfolio Health Indicators', 'Investment Prioritization', 'Capacity Planning', 'Resource Allocation', 'Financial Performance', 'Executive Scorecards', 'KPI Tracking', 'Portfolio Reporting'].map((item) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(item, style: const TextStyle(fontSize: 10, color: Color(0xFFF9A8D4))))).toList()),
        const SizedBox(height: 16),
        Center(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          child: const Text('View Portfolio Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
      ]),
    );
  }

  Widget _demoGrid(BuildContext context, bool isDesktop) {
    final demos = [
      _Demo('Solar Farm Expansion', 'Energy', 'Waterfall', Icons.wb_sunny, const Color(0xFFF59E0B), ['Project Charter', 'AI-generated WBS', 'Schedule Builder', 'Procurement Planning', 'Contractor Management', 'Risk Dashboard', 'Executive Reporting']),
      _Demo('AI Customer Support Platform', 'Information Technology', 'Agile', Icons.support_agent, const Color(0xFFFBBF24), ['Product Vision', 'Product Backlog', 'Sprint Planning', 'AI Story Generation', 'Sprint Boards', 'Sprint Reviews', 'Burndown Charts']),
      _Demo('Hospital Imaging Center Construction', 'Healthcare', 'Waterfall', Icons.local_hospital, const Color(0xFFEF4444), ['Business Case', 'Scope Planning', 'Budget Management', 'Procurement', 'Construction Tracking', 'Equipment Installation', 'Project Closeout']),
      _Demo('University Student Mobile App', 'Education', 'Agile', Icons.school, const Color(0xFF10B981), ['User Personas', 'Product Roadmap', 'Sprint Planning', 'Feature Prioritization', 'User Testing', 'Release Management']),
      _Demo('Smart Manufacturing Transformation', 'Manufacturing', 'Hybrid', Icons.factory, const Color(0xFF8B5CF6), ['Facility Assessment', 'Engineering Planning', 'ERP Integration', 'IoT Dashboard', 'Agile Software Delivery', 'Executive Reporting']),
      _Demo('Enterprise EHR Modernization', 'Healthcare', 'Hybrid', Icons.favorite, const Color(0xFFEC4899), ['Program Governance', 'Multi-site Rollout', 'Vendor Management', 'Data Migration', 'Sprint Planning', 'Change Management', 'Executive Reporting']),
    ];
    final cols = isDesktop ? 3 : 1;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = cols == 1 ? double.infinity : (screenWidth - 240) / cols;
    return Wrap(spacing: 20, runSpacing: 20, children: demos.map((d) => SizedBox(width: cardWidth, child: _demoCard(d))).toList());
  }

  Widget _demoCard(_Demo d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: d.color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: d.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(d.icon, color: d.color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text('Industry: ${d.industry}  •  ${d.methodology}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          ])),
        ]),
        const SizedBox(height: 12),
        const Text('Experience', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 4, children: d.experience.map((e) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: d.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(e, style: TextStyle(fontSize: 10, color: d.color.withValues(alpha: 0.9))))).toList()),
        const SizedBox(height: 14),
        Center(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Launch Demo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(foregroundColor: d.color, side: BorderSide(color: d.color.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)))),
      ]),
    );
  }
}

class _Industry { final IconData icon; final String name; final String demo; final Color color; final List<String> highlights; const _Industry({required this.icon, required this.name, required this.demo, required this.color, required this.highlights}); }
class _Methodology { final String name; final String desc; final List<String> demos; final Color color; const _Methodology({required this.name, required this.desc, required this.demos, required this.color}); }
class _Demo { final String title; final String industry; final String methodology; final IconData icon; final Color color; final List<String> experience; const _Demo(this.title, this.industry, this.methodology, this.icon, this.color, this.experience); }
