/// NDU Project — Careers Page
///
/// World-class careers page with job listings, company culture,
/// benefits, and application form — similar to Jira/Asana careers.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const _bg = Color(0xFF0A0E1A);
const _surface = Color(0xFF111827);
const _surfaceCard = Color(0xFF151D2E);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);
const _border = Color(0xFF1E293B);
const _blue = Color(0xFFFBBF24);
const _purple = Color(0xFF8B5CF6);
const _green = Color(0xFF10B981);
const _gold = Color(0xFFFBBF24);

class CareersPageScreen extends StatelessWidget {
  const CareersPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobs = [
      ('Senior Flutter Developer', 'Engineering', 'Remote', 'Full-time', Icons.code),
      ('Product Manager', 'Product', 'Zachary, LA', 'Full-time', Icons.assignment_outlined),
      ('Project Delivery Consultant', 'Services', 'Remote', 'Contract', Icons.support_agent_outlined),
      ('AI/ML Engineer', 'Engineering', 'Remote', 'Full-time', Icons.psychology),
      ('Sales Development Representative', 'Sales', 'Zachary, LA', 'Full-time', Icons.trending_up),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // Nav
          SliverAppBar(
            pinned: true,
            toolbarHeight: 56,
            backgroundColor: _bg.withValues(alpha: 0.9),
            surfaceTintColor: Colors.transparent,
            title: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_gold, Color(0xFFD97706)]), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.trending_up, color: _bg, size: 16)),
              const SizedBox(width: 8),
              Text('NDU', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: appFontFamily)),
              Text(' Project', style: TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: appFontFamily)),
            ]),
            actions: [
              TextButton(onPressed: () => context.go('/landing'), child: Text('Back to Home', style: TextStyle(color: _textSecondary, fontSize: 13, fontFamily: appFontFamily))),
              const SizedBox(width: 16),
            ],
          ),
          SliverList(delegate: SliverChildListDelegate([
            // Hero
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _green.withValues(alpha: 0.3))), child: Text('We\'re Hiring', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: appFontFamily))),
                  const SizedBox(height: 24),
                  Text('Join Our Mission', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, fontFamily: appFontFamily)),
                  const SizedBox(height: 16),
                  Text('Help us build the future of project delivery. We\'re on a mission to ensure every project starts right and stays right.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 16, height: 1.6, fontFamily: appFontFamily)),
                  const SizedBox(height: 40),
                ],
              ))),
            ),
            // Culture section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              color: _surface.withValues(alpha: 0.3),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _cultureValue('Innovation First', 'We push boundaries and challenge the status quo', Icons.lightbulb_outline, _purple),
                  _cultureValue('Remote-First', 'Work from anywhere, deliver from everywhere', Icons.home_work_outlined, _blue),
                  _cultureValue('Growth Mindset', 'Continuous learning and development', Icons.trending_up, _green),
                  _cultureValue('Impact Driven', 'Every role shapes how projects succeed', Icons.flag_outlined, _gold),
                ]),
              )),
            ),
            // Job listings
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(children: [
                  Text('Open Positions', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
                  const SizedBox(height: 32),
                  ...jobs.map((j) => _jobCard(j.$1, j.$2, j.$3, j.$4, j.$5)),
                ]),
              )),
            ),
            // Apply CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
              color: _surface.withValues(alpha: 0.3),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(children: [
                  Text('Don\'t see your role?', textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
                  const SizedBox(height: 12),
                  Text('Send us your resume and tell us how you\'d contribute to Ndu Project.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 15, fontFamily: appFontFamily)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl('mailto:contact@nduproject.com?subject=Career Application'),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Your Resume'),
                    style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                  ),
                ]),
              )),
            ),
          ])),
        ],
      ),
    );
  }

  Widget _cultureValue(String title, String desc, IconData icon, Color color) {
    return Container(width: 200, margin: const EdgeInsets.symmetric(horizontal: 10), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: appFontFamily)), const SizedBox(height: 6), Text(desc, textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: appFontFamily))]));
  }

  Widget _jobCard(String title, String dept, String location, String type, IconData icon) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _blue, size: 22)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: appFontFamily)),
        const SizedBox(height: 4),
        Row(children: [Text(dept, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily)), const SizedBox(width: 12), Icon(Icons.location_on_outlined, color: _textMuted, size: 12), const SizedBox(width: 4), Text(location, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily)), const SizedBox(width: 12), Icon(Icons.schedule, color: _textMuted, size: 12), const SizedBox(width: 4), Text(type, style: TextStyle(color: _textSecondary, fontSize: 12, fontFamily: appFontFamily))]),
      ])),
      IconButton(onPressed: () => _launchUrl('mailto:contact@nduproject.com?subject=Application: $title'), icon: Icon(Icons.arrow_forward, color: _blue, size: 18)),
    ]));
  }
}

void _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
