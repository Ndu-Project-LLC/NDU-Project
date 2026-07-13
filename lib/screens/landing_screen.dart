import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/screens/pricing_screen.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatefulWidget {
 const LandingScreen({super.key});

 @override
 State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
 with SingleTickerProviderStateMixin {
 late final AnimationController _animController;
 late final Animation<double> _fadeAnimation;
 late final ScrollController _scrollController;

 final GlobalKey _solutionKey = GlobalKey();
 final GlobalKey _howItWorksKey = GlobalKey();
 final GlobalKey _aiKey = GlobalKey();
 final GlobalKey _ctaKey = GlobalKey();
 final GlobalKey _problemKey = GlobalKey();
 final GlobalKey _differentiatorsKey = GlobalKey();
 final GlobalKey _benefitsKey = GlobalKey();
 final GlobalKey _trainingKey = GlobalKey();
 final GlobalKey _consultationKey = GlobalKey();
 final GlobalKey _newsBlogKey = GlobalKey();
 final GlobalKey _asSeenOnKey = GlobalKey();
 final GlobalKey _reviewsKey = GlobalKey();

 // Debug mode state
 bool _isDebugMode = false;
 int _kazAiTapCount = 0;
 DateTime? _lastKazAiTap;
 int _workflowTapCount = 0;
 DateTime? _lastWorkflowTap;

 @override
 void initState() {
 super.initState();
 _animController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1400),
 );
 _fadeAnimation =
 CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
 _scrollController = ScrollController();
 _animController.forward();
 }

 @override
 void dispose() {
 _animController.dispose();
 _scrollController.dispose();
 super.dispose();
 }

 void _scrollTo(GlobalKey key) {
 final target = key.currentContext;
 if (target != null) {
 Scrollable.ensureVisible(
 target,
 duration: const Duration(milliseconds: 600),
 curve: Curves.easeOutCubic,
 );
 }
 }

 void _handleKazAiTap() {
 final now = DateTime.now();
 if (_lastKazAiTap == null ||
 now.difference(_lastKazAiTap!) > const Duration(seconds: 2)) {
 _kazAiTapCount = 1;
 } else {
 _kazAiTapCount++;
 }
 _lastKazAiTap = now;

 if (_kazAiTapCount >= 4) {
 setState(() {
 _isDebugMode = !_isDebugMode;
 _kazAiTapCount = 0;
 });
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(_isDebugMode
 ? '🛠️ Debug mode enabled'
 : '✅ Debug mode disabled'),
 duration: const Duration(seconds: 2),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } else {
 _scrollTo(_aiKey);
 }
 }

 void _handleWorkflowTap() {
 final now = DateTime.now();
 if (_lastWorkflowTap == null ||
 now.difference(_lastWorkflowTap!) > const Duration(seconds: 2)) {
 _workflowTapCount = 1;
 } else {
 _workflowTapCount++;
 }
 _lastWorkflowTap = now;

 // Triple-tap Easter egg: navigate to the authenticate (sign-in) screen
 if (_workflowTapCount >= 3) {
 _workflowTapCount = 0;
 context.go('/${AppRoutes.signIn}');
 return;
 }

 _scrollTo(_howItWorksKey);
 }

 void _handleStartProject() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PricingScreen()),
 );
 }

 void _showComingSoonDialog() {
 showDialog(
 context: context,
 builder: (context) => Dialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: Container(
 constraints: const BoxConstraints(maxWidth: 500),
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: LightModeColors.accent.withValues(alpha: 0.1),
 shape: BoxShape.circle,
 ),
 child: Icon(
 Icons.rocket_launch_rounded,
 size: 48,
 color: LightModeColors.accent,
 ),
 ),
 const SizedBox(height: 24),
 const Text(
 'Coming Soon!',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w800,
 color: Color(0xFF1F2937),
 ),
 ),
 const SizedBox(height: 12),
 Text(
 'While we are actively consulting and helping companies drive profits through strong project delivery, we are also finalizing our project delivery platform for broader access. Join our waitlist to be notified when we launch.',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 16,
 color: Colors.grey[700],
 height: 1.5,
 ),
 ),
 const SizedBox(height: 32),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () {
 Navigator.pop(context);
 _launchExternalLink('https://forms.gle/K6dvU4T9fi7FGxhg9');
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: const Color(0xFF151515),
 padding: const EdgeInsets.symmetric(vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 child: const Text(
 'Join Waitlist',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 ),
 ),
 const SizedBox(height: 12),
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text(
 'Maybe Later',
 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Future<void> _launchExternalLink(String url) async {
 final uri = Uri.parse(url);
 final bool launched =
 await launchUrl(uri, mode: LaunchMode.externalApplication);
 if (!launched && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Unable to open link. Please try again.')),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 final size = MediaQuery.of(context).size;
 final bool isDesktop = size.width >= 1200;
 final bool isTablet = size.width >= 900 && size.width < 1200;

 return Scaffold(
 backgroundColor: Colors.black,
 body: SafeArea(
 child: Container(
 decoration: const BoxDecoration(
 color: Color(0xFF040404),
 ),
 child: Stack(
 children: [
 Positioned(
 top: -200,
 right: -120,
 child: Container(
 width: 380,
 height: 380,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.38),
 Colors.transparent,
 ],
 ),
 ),
 ),
 ),
 Positioned(
 bottom: -260,
 left: -120,
 child: Container(
 width: 420,
 height: 420,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [
 Colors.white.withValues(alpha: 0.08),
 Colors.transparent,
 ],
 ),
 ),
 ),
 ),
 ScrollConfiguration(
 behavior: _NoGlowScrollBehavior(),
 child: SingleChildScrollView(
 controller: _scrollController,
 child: Column(
 children: [
 SizedBox(height: isDesktop ? 140 : 110),
 _buildHeroSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 60),
 _buildSocialProofBar(isDesktop),
 SizedBox(height: isDesktop ? 80 : 60),
 _buildProblemSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildSolutionSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildHowItWorksSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildDifferentiatorsSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildBenefitsSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildTargetCustomersSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildOriginSection(context, isDesktop || isTablet),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildCoreInsightSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildCTASection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildTrainingSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildConsultationSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildNewsBlogSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildAsSeenOnSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildReviewsSection(context, isDesktop),
 SizedBox(height: isDesktop ? 80 : 56),
 _buildFAQSection(context, isDesktop),
 _buildFooter(context),
 ],
 ),
 ),
 ),
 _buildStickyHeader(context, isDesktop),
 const AdminEditToggle(),
 ],
 ),
 ),
 ),
 );
 }

 // ── Sticky Header ──────────────────────────────────────────────────────
 Widget _buildStickyHeader(BuildContext context, bool isDesktop) {
 final width = MediaQuery.of(context).size.width;
 final bool isTablet = width >= 900 && width < 1200;
 final bool isMobile = width < 700;

 Widget buildLogo() {
 return Image.asset(
 'assets/images/Logo.png',
 height: isDesktop
 ? 90
 : isTablet
 ? 70
 : 60,
 fit: BoxFit.contain,
 );
 }

 PopupMenuButton<String> buildMenuButton() {
 return PopupMenuButton<String>(
 icon: const Icon(Icons.menu_rounded, color: Colors.white),
 onSelected: (value) {
 switch (value) {
 case 'solution':
 _scrollTo(_solutionKey);
 break;
 case 'howitworks':
 _handleWorkflowTap();
 break;
 case 'differentiators':
 _scrollTo(_differentiatorsKey);
 break;
 case 'benefits':
 _scrollTo(_benefitsKey);
 break;
 case 'cta':
 _scrollTo(_ctaKey);
 break;
 }
 },
 itemBuilder: (context) => const [
 PopupMenuItem(value: 'solution', child: Text('Why Ndu Project?')),
 PopupMenuItem(value: 'howitworks', child: Text('How It Works')),
 PopupMenuItem(value: 'differentiators', child: Text('Differentiator')),
 PopupMenuItem(value: 'benefits', child: Text('Trusted By')),
 PopupMenuItem(value: 'cta', child: Text('KAZ AI')),
 ],
 );
 }

 Widget buildSignInButton({bool fullWidth = false}) {
 final button = TextButton(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const SignInScreen()),
 );
 },
 style: TextButton.styleFrom(
 foregroundColor: Colors.white,
 padding: EdgeInsets.symmetric(
 horizontal: fullWidth ? 16 : 20, vertical: 12),
 minimumSize: const Size(0, 44),
 ),
 child: const Text('Sign In',
 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
 );

 return fullWidth
 ? SizedBox(width: double.infinity, child: button)
 : button;
 }

 Widget buildStartProjectButton({bool fullWidth = false}) {
 final button = ElevatedButton(
 onPressed: _handleStartProject,
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: const Color(0xFF151515),
 padding: EdgeInsets.symmetric(
 horizontal: fullWidth ? 28 : 28, vertical: 16),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 minimumSize: const Size(200, 52),
 fixedSize: fullWidth
 ? const Size(double.infinity, 52)
 : null,
 ),
 child: const Text('Start Your Project',
 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
 );

 return fullWidth
 ? SizedBox(width: double.infinity, child: button)
 : button;
 }

 Widget buildTabletOrDesktopContent() {
 return Row(
 children: [
 buildLogo(),
 if (isDesktop) ...[
 const SizedBox(width: 32),
 _buildWhyNduDropdown(),
 _buildSolutionsDropdown(),
 _buildServicesDropdown(),
 _navButton('Pricing', () => _scrollTo(_ctaKey)),
 _buildResourcesDropdown(),
 ],
 const Spacer(),
 if (!isDesktop) ...[
 buildMenuButton(),
 const SizedBox(width: 12),
 ],
 buildSignInButton(),
 const SizedBox(width: 16),
 buildStartProjectButton(),
 ],
 );
 }

 Widget buildMobileContent() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(child: buildLogo()),
 const SizedBox(width: 12),
 buildMenuButton(),
 ],
 ),
 const SizedBox(height: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 buildSignInButton(fullWidth: true),
 const SizedBox(height: 10),
 buildStartProjectButton(fullWidth: true),
 ],
 ),
 ],
 );
 }

 return Positioned(
 top: 20,
 left: 0,
 right: 0,
 child: IgnorePointer(
 ignoring: false,
 child: Padding(
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop
 ? 64
 : isMobile
 ? 16
 : 32),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(18),
 child: Container(
 clipBehavior: Clip.hardEdge,
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop
 ? 32
 : isMobile
 ? 16
 : 20,
 vertical: 12),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: Colors.black.withValues(alpha: 0.92),
 border:
 Border.all(color: Colors.white.withValues(alpha: 0.08)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.4),
 blurRadius: 30,
 offset: const Offset(0, 18),
 ),
 ],
 ),
 child: isMobile
 ? buildMobileContent()
 : buildTabletOrDesktopContent(),
 ),
 ),
 ),
 ),
 );
 }

 Widget _navButton(String label, VoidCallback onTap) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Colors.white,
 ),
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildWhyNduDropdown() {
 return _buildPremiumDropdown(
 label: 'Why Ndu Project?',
 items: [
 _DropdownItem(icon: Icons.lightbulb_outline, label: 'Why Ndu Project?', onTap: () => _scrollTo(_solutionKey)),
 _DropdownItem(icon: Icons.play_circle_outline, label: 'How It Works', onTap: _handleWorkflowTap),
 _DropdownItem(icon: Icons.star_outline, label: 'Differentiator', onTap: () => _scrollTo(_differentiatorsKey)),
 _DropdownItem(icon: Icons.verified_outlined, label: 'Trusted By', onTap: () => _scrollTo(_benefitsKey)),
 _DropdownItem(icon: Icons.auto_awesome, label: 'KAZ AI', onTap: () => _scrollTo(_aiKey)),
 ],
 );
 }

 Widget _buildSolutionsDropdown() {
 return _buildPremiumDropdown(
 label: 'Solutions',
 items: [
 _DropdownItem(icon: Icons.play_circle_outline, label: 'How It Works', onTap: _handleWorkflowTap),
 _DropdownItem(icon: Icons.star_outline, label: 'Differentiator', onTap: () => _scrollTo(_differentiatorsKey)),
 _DropdownItem(icon: Icons.cases_outlined, label: 'Use Cases', onTap: () => _scrollTo(_differentiatorsKey)),
 _DropdownItem(icon: Icons.slideshow_outlined, label: 'Demo', onTap: () => _scrollTo(_benefitsKey)),
 _DropdownItem(icon: Icons.handshake_outlined, label: 'Partner with Us', onTap: () => _scrollTo(_aiKey)),
 ],
 );
 }

 Widget _buildServicesDropdown() {
 return _buildPremiumDropdown(
 label: 'Services',
 items: [
 _DropdownItem(icon: Icons.miscellaneous_services, label: 'Services', onTap: () => _scrollTo(_benefitsKey)),
 _DropdownItem(icon: Icons.delivery_dining_outlined, label: 'Project Delivery', onTap: () => _scrollTo(_benefitsKey)),
 _DropdownItem(icon: Icons.school_outlined, label: 'Training', onTap: () => _scrollTo(_aiKey)),
 _DropdownItem(icon: Icons.support_agent, label: 'Consultation', onTap: () => _scrollTo(_ctaKey)),
 ],
 );
 }

 Widget _buildResourcesDropdown() {
 return _buildPremiumDropdown(
 label: 'Resources',
 items: [
 _DropdownItem(icon: Icons.contact_page_outlined, label: 'Contact Us', onTap: () => _scrollTo(_newsBlogKey)),
 _DropdownItem(icon: Icons.help_outline, label: 'Support', onTap: () => _scrollTo(_reviewsKey)),
 _DropdownItem(icon: Icons.newspaper, label: 'Media', onTap: () => launchUrl(Uri.parse('https://nduproject.tech'), mode: LaunchMode.externalApplication)),
 _DropdownItem(icon: Icons.campaign_outlined, label: 'Announcements', onTap: () => _scrollTo(_asSeenOnKey)),
 ],
 );
 }

 /// World-class premium dropdown with hover states, icons, brand colors,
 /// rich typography, smooth animation, and elegant elevation.
 Widget _buildPremiumDropdown({
 required String label,
 required List<_DropdownItem> items,
 }) {
 return PopupMenuButton<int>(
 onSelected: (index) {
 if (index >= 0 && index < items.length) {
 items[index].onTap();
 }
 },
 offset: const Offset(0, 48),
 constraints: BoxConstraints(minWidth: 240, maxWidth: 320),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
 ),
 elevation: 16,
 shadowColor: Colors.black.withValues(alpha: 0.3),
 color: const Color(0xFF1A1D29),
 itemBuilder: (context) => [
 for (int i = 0; i < items.length; i++)
 PopupMenuItem<int>(
 value: i,
 padding: EdgeInsets.zero,
 child: _PremiumDropdownItem(item: items[i], isLast: i == items.length - 1),
 ),
 ],
 child: _PremiumDropdownTrigger(label: label),
 );
 }

 // ── Section 1: Hero (PDOS) ────────────────────────────────────────────
 Widget _buildHeroSection(BuildContext context, bool isDesktop) {
 return FadeTransition(
 opacity: _fadeAnimation,
 child: Padding(
 padding: EdgeInsets.symmetric(horizontal: isDesktop ? 96 : 24),
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(40),
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [Color(0xFF141414), Color(0xFF050505)],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.35),
 blurRadius: 60,
 offset: const Offset(0, 36),
 ),
 ],
 ),
 child: Stack(
 children: [
 Positioned(
 top: -40,
 right: -50,
 child: Container(
 width: 180,
 height: 180,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.32),
 Colors.transparent
 ],
 ),
 ),
 ),
 ),
 Positioned(
 bottom: -60,
 left: -50,
 child: Container(
 width: 220,
 height: 220,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [Color(0xFF101010), Colors.transparent],
 ),
 ),
 ),
 ),
 Padding(
 padding: EdgeInsets.all(isDesktop ? 64 : 36),
 child: isDesktop
 ? Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 child: _buildHeroContent(context, true)),
 const SizedBox(width: 54),
 Expanded(child: _buildHeroVisual(context)),
 ],
 )
 : Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 _buildHeroContent(context, false),
 const SizedBox(height: 40),
 _buildHeroVisual(context),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildHeroContent(BuildContext context, bool isDesktop) {
 const valueProps = [
 'Define, plan, and execute in one continuous system',
 'Predict risks, delays, and cost impacts before they happen',
 'Align teams and decisions in real time',
 ];

 return Column(
 crossAxisAlignment:
 isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.auto_awesome,
 size: 18,
 color: LightModeColors.accent.withValues(alpha: 0.95)),
 const SizedBox(width: 8),
 Text(
 'Project Delivery Operating System (PDOS)',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Colors.white.withValues(alpha: 0.88),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 26),
 Text(
 '42% of Projects Fail to meet original scope. Fix Project Failure Before It Starts',
 key: const Key('hero_tagline_text'),
 textAlign: isDesktop ? TextAlign.left : TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 46.0 : 32.0,
 fontWeight: FontWeight.w800,
 height: 1.12,
 letterSpacing: -0.6,
 color: const Color(0xFFFFF3C0),
 ),
 ),
 const SizedBox(height: 20),
 Text(
 'Ndu Project is a Project Delivery Operating System (PDOS)—a SaaS platform that integrates AI, analytics, and human decision making to deliver projects from initiation through completion.',
 textAlign: isDesktop ? TextAlign.left : TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 19 : 17,
 height: 1.6,
 color: Colors.white.withValues(alpha: 0.72),
 ),
 ),
 const SizedBox(height: 24),
 Wrap(
 alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
 spacing: 10,
 runSpacing: 10,
 children: valueProps
 .map(
 (prop) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(20),
 color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
 border: Border.all(
 color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
 width: 1),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.check_circle_rounded,
 color: Color(0xFF10B981), size: 16),
 const SizedBox(width: 8),
 Text(
 prop,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w600,
 fontSize: 13,
 ),
 ),
 ],
 ),
 ),
 )
 .toList(),
 ),
 const SizedBox(height: 32),
 Wrap(
 spacing: 16,
 runSpacing: 16,
 alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
 children: [
 ElevatedButton(
 onPressed: () => _launchExternalLink('https://calendar.app.google/aGQDFPpmEK9eDh5W6'),
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: const Color(0xFF151515),
 padding:
 const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 elevation: 0,
 ),
 child: const Text('Request a Demo',
 style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
 ),
 OutlinedButton(
 onPressed: _handleWorkflowTap,
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white.withValues(alpha: 0.92),
 padding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
 side: BorderSide(
 color: Colors.white.withValues(alpha: 0.26), width: 1.6),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Text('See How It Works',
 style:
 TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 SizedBox(width: 8),
 Icon(Icons.arrow_outward_rounded, size: 18),
 ],
 ),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildHeroVisual(BuildContext context) {
 return Container(
 constraints: const BoxConstraints(
 minHeight: 400,
 maxWidth: double.infinity,
 ),
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(32),
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [Color(0xFF171717), Color(0xFF060606)],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.35),
 blurRadius: 40,
 offset: const Offset(0, 28),
 ),
 ],
 ),
 child: Stack(
 children: [
 Positioned(
 top: -80,
 right: -60,
 child: Container(
 width: 200,
 height: 200,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [
 const Color(0xFF3B82F6).withValues(alpha: 0.35),
 Colors.transparent
 ],
 ),
 ),
 ),
 ),
 Positioned(
 bottom: -100,
 left: -80,
 child: Container(
 width: 240,
 height: 240,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [Color(0xFF8B5CF6), Colors.transparent],
 ),
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 // System diagram: Initiation → Planning → Execution loop
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 _buildDiagramNode('Initiation', Icons.flag_rounded, const Color(0xFF3B82F6)),
 _buildDiagramArrow(),
 _buildDiagramNode('Planning', Icons.architecture_rounded, const Color(0xFF8B5CF6)),
 _buildDiagramArrow(),
 _buildDiagramNode('Execution', Icons.rocket_launch_rounded, const Color(0xFF10B981)),
 ],
 ),
 const SizedBox(height: 28),
 // Loop-back arrow indicator
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.06),
 border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 18),
 SizedBox(width: 10),
 Text(
 'Continuous Delivery Loop',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w600,
 fontSize: 14,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 // Overlay text
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(20),
 gradient: LinearGradient(
 colors: [
 const Color(0xFF3B82F6).withValues(alpha: 0.15),
 const Color(0xFF8B5CF6).withValues(alpha: 0.15),
 ],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
 ),
 child: Column(
 children: [
 Text(
 'AI + Analytics + Human Decision Making',
 textAlign: TextAlign.center,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.92),
 fontWeight: FontWeight.w800,
 fontSize: 18,
 letterSpacing: 0.3,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'One system governing the full project lifecycle',
 textAlign: TextAlign.center,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.6),
 fontSize: 13,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildDiagramNode(String label, IconData icon, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 color.withValues(alpha: 0.25),
 color.withValues(alpha: 0.08),
 ],
 ),
 border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
 boxShadow: [
 BoxShadow(
 color: color.withValues(alpha: 0.2),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 children: [
 Icon(icon, color: color, size: 24),
 const SizedBox(height: 8),
 Text(
 label,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildDiagramArrow() {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Icon(Icons.arrow_forward_rounded,
 color: Colors.white.withValues(alpha: 0.5), size: 24),
 );
 }

 // ── Section 2: Social Proof / Credibility Bar ─────────────────────────
 Widget _buildSocialProofBar(bool isDesktop) {
 return Container(
 margin: EdgeInsets.symmetric(horizontal: isDesktop ? 96 : 24),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 48 : 24, vertical: isDesktop ? 28 : 22),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [Color(0xFF141414), Color(0xFF060606)],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.45),
 blurRadius: 36,
 offset: const Offset(0, 24),
 ),
 ],
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Flexible(
 child: Text(
 'Built from real-world delivery experience across global enterprises and high-growth organizations',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 18 : 16,
 fontWeight: FontWeight.w600,
 color: Colors.white.withValues(alpha: 0.8),
 height: 1.5,
 ),
 ),
 ),
 if (isDesktop) ...[
 const SizedBox(width: 32),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 gradient: const LinearGradient(
 colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
 ),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.science_rounded, color: Colors.white, size: 18),
 SizedBox(width: 8),
 Text(
 'NSF I-Corps Validated',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 ),
 ),
 ] else ...[
 const SizedBox(width: 16),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 gradient: const LinearGradient(
 colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.science_rounded, color: Colors.white, size: 16),
 SizedBox(width: 6),
 Text(
 'NSF I-Corps',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ],
 ),
 ),
 ],
 ],
 ),
 );
 }

 // ── Section 3: The Problem ────────────────────────────────────────────
 Widget _buildProblemSection(BuildContext context, bool wideLayout) {
 const painPoints = [
 _PainPointData(icon: Icons.fast_forward_rounded, label: 'No, or rushed, initiation and planning'),
 _PainPointData(icon: Icons.extension_rounded, label: 'Fragmented tools for different project stages'),
 _PainPointData(icon: Icons.sync_problem_rounded, label: 'Misalignment between teams and decisions'),
 _PainPointData(icon: Icons.warning_amber_rounded, label: 'Reactive risk management'),
 _PainPointData(icon: Icons.replay_rounded, label: 'Costly rework and delays'),
 ];

 return Container(
 key: _problemKey,
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
 padding: EdgeInsets.symmetric(
 horizontal: wideLayout ? 64 : 28, vertical: wideLayout ? 84 : 56),
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
 color: Colors.black.withValues(alpha: 0.45),
 blurRadius: 60,
 offset: const Offset(0, 34),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: const Color(0xFFEF4444).withValues(alpha: 0.12),
 border: Border.all(
 color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 16),
 SizedBox(width: 8),
 Text(
 'The Problem',
 style: TextStyle(
 color: Color(0xFFEF4444),
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 Text(
 "Projects Don't Fail in Execution.\nThey Fail Before Execution Begins",
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 16),
 Text(
 "Most project tools focus on tracking work after it starts. But by then, the most critical decisions have already been made… and often made poorly.",
 style: TextStyle(
 fontSize: 18,
 color: Colors.white.withValues(alpha: 0.75),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 40),
 LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final double spacing = 20;
 final int columns;
 if (maxWidth >= 900) {
 columns = 3;
 } else if (maxWidth >= 560) {
 columns = 2;
 } else {
 columns = 1;
 }
 final double itemWidth = columns == 1
 ? maxWidth
 : (maxWidth - spacing * (columns - 1)) / columns;

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: painPoints.map((pp) {
 return SizedBox(
 width: itemWidth,
 child: Container(
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(20),
 color: Colors.white.withValues(alpha: 0.04),
 border: Border.all(
 color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(12),
 color: const Color(0xFFEF4444).withValues(alpha: 0.12),
 ),
 child: Icon(pp.icon,
 color: const Color(0xFFEF4444), size: 20),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Text(
 pp.label,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.88),
 fontWeight: FontWeight.w600,
 fontSize: 15,
 height: 1.45,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }).toList(),
 );
 },
 ),
 const SizedBox(height: 36),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.06),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Row(
 children: [
 const Icon(Icons.format_quote_rounded,
 color: Color(0xFFEF4444), size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 "The issue isn't execution. It's the lack of a system governing the full lifecycle.",
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.85),
 fontWeight: FontWeight.w700,
 fontSize: 16,
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Section 4: The Solution / PDOS Intro ──────────────────────────────
 Widget _buildSolutionSection(BuildContext context, bool wideLayout) {
 final capabilities = [
 const _CapabilityData(
 icon: Icons.route_rounded,
 title: 'End-to-end delivery',
 description: 'Govern projects from initiation through launch in one unified system.',
 bulletPoints: [
 'Continuous lifecycle coverage',
 'No gaps between phases',
 'Single source of truth',
 ],
 gradient: [Color(0xFF3B82F6), Color(0xFF6366F1)],
 ),
 const _CapabilityData(
 icon: Icons.sync_rounded,
 title: 'Continuous lifecycle integration',
 description: 'Initiation → Planning → Execution → Launch—all connected seamlessly.',
 bulletPoints: [
 'Phase transitions with readiness gates',
 'Connected data flows',
 'Automated handoff protocols',
 ],
 gradient: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
 ),
 const _CapabilityData(
 icon: Icons.smart_toy_rounded,
 title: 'AI-driven recommendations',
 description: 'KAZ AI provides contextual guidance, summaries, and decision support.',
 bulletPoints: [
 'Context-aware answers',
 'Action acceleration',
 'Guided decisioning',
 ],
 gradient: [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
 ),
 const _CapabilityData(
 icon: Icons.insights_rounded,
 title: 'Predictive analytics for risk and cost',
 description: 'Identify risks and cost impacts before they materialize.',
 bulletPoints: [
 'Early warning indicators',
 'Scenario planning',
 'Variance tracking',
 ],
 gradient: [Color(0xFFF97316), Color(0xFFEF4444)],
 ),
 const _CapabilityData(
 icon: Icons.groups_rounded,
 title: 'Real-time cross-functional alignment',
 description: 'Keep every stakeholder and team aligned with live dashboards and governance.',
 bulletPoints: [
 'Stakeholder views',
 'Approval workflows',
 'Governance controls',
 ],
 gradient: [Color(0xFF10B981), Color(0xFF0EA5E9)],
 ),
 const _CapabilityData(
 icon: Icons.verified_rounded,
 title: 'Readiness-based execution',
 description: 'Execute only when conditions are met—no more premature launches.',
 bulletPoints: [
 'Readiness gates',
 'Quality checkpoints',
 'Go/no-go decisioning',
 ],
 gradient: [Color(0xFFF59E0B), Color(0xFFFACC15)],
 ),
 ];

 return Container(
 key: _solutionKey,
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
 padding: EdgeInsets.symmetric(
 horizontal: wideLayout ? 64 : 28, vertical: wideLayout ? 84 : 56),
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
 color: Colors.black.withValues(alpha: 0.45),
 blurRadius: 60,
 offset: const Offset(0, 34),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
 border: Border.all(
 color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Icon(Icons.auto_awesome_rounded, color: Color(0xFF3B82F6), size: 16),
 SizedBox(width: 8),
 Text(
 'The Solution',
 style: TextStyle(
 color: Color(0xFF3B82F6),
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 Text(
 'A New Category: Project Delivery Operating System (PDOS)',
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 letterSpacing: -0.4,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 14),
 Text(
 'Ndu Project replaces disconnected tools with a unified system that governs how projects are defined, planned, and delivered.',
 style: TextStyle(
 fontSize: 18,
 color: Colors.white.withValues(alpha: 0.75),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 44),
 LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final double spacing = 24;
 final int columns;
 if (maxWidth >= 1040) {
 columns = 3;
 } else if (maxWidth >= 680) {
 columns = 2;
 } else {
 columns = 1;
 }
 final double itemWidth = columns == 1
 ? maxWidth
 : (maxWidth - spacing * (columns - 1)) / columns;

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: capabilities
 .map(
 (cap) => SizedBox(
 width: itemWidth, child: _CapabilityCard(data: cap)),
 )
 .toList(),
 );
 },
 ),
 const SizedBox(height: 36),
 Center(
 child: OutlinedButton(
 onPressed: () => _scrollTo(_solutionKey),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white.withValues(alpha: 0.92),
 padding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
 side: BorderSide(
 color: Colors.white.withValues(alpha: 0.26), width: 1.6),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Text('Explore the Platform',
 style:
 TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 SizedBox(width: 8),
 Icon(Icons.arrow_outward_rounded, size: 18),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ── Section 5: How It Works ───────────────────────────────────────────
 Widget _buildHowItWorksSection(BuildContext context, bool wideLayout) {
 const steps = [
 _HowItWorksStep(
 number: '01',
 title: 'Define',
 description: 'Structure strong project foundations with disciplined initiation',
 icon: Icons.flag_rounded,
 color: Color(0xFF3B82F6),
 ),
 _HowItWorksStep(
 number: '02',
 title: 'Align',
 description: 'Integrate planning across engineering, procurement, and execution',
 icon: Icons.architecture_rounded,
 color: Color(0xFF8B5CF6),
 ),
 _HowItWorksStep(
 number: '03',
 title: 'Deliver',
 description: 'Execute with readiness gates, AI insights, and real-time alignment',
 icon: Icons.rocket_launch_rounded,
 color: Color(0xFF10B981),
 ),
 ];

 return Container(
 key: _howItWorksKey,
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
 padding: EdgeInsets.symmetric(
 horizontal: wideLayout ? 64 : 28, vertical: wideLayout ? 80 : 56),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(36),
 gradient: const LinearGradient(
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 colors: [Color(0xFF121212), Color(0xFF060606)],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.32),
 blurRadius: 48,
 offset: const Offset(0, 32),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 GestureDetector(
 onTap: _handleWorkflowTap,
 behavior: HitTestBehavior.opaque,
 child: Text(
 'How Ndu Project Delivers Results',
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
 ),
 ),
 ),
 const SizedBox(height: 48),
 LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final bool horizontal = maxWidth >= 700;

 if (horizontal) {
 return Row(
 children: [
 Expanded(child: _buildHowItWorksCard(steps[0])),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Icon(Icons.arrow_forward_rounded,
 color: Colors.white.withValues(alpha: 0.4), size: 28),
 ),
 Expanded(child: _buildHowItWorksCard(steps[1])),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Icon(Icons.arrow_forward_rounded,
 color: Colors.white.withValues(alpha: 0.4), size: 28),
 ),
 Expanded(child: _buildHowItWorksCard(steps[2])),
 ],
 );
 }

 return Column(
 children: [
 _buildHowItWorksCard(steps[0]),
 const SizedBox(height: 12),
 const Icon(Icons.arrow_downward_rounded,
 color: Colors.white54, size: 28),
 const SizedBox(height: 12),
 _buildHowItWorksCard(steps[1]),
 const SizedBox(height: 12),
 const Icon(Icons.arrow_downward_rounded,
 color: Colors.white54, size: 28),
 const SizedBox(height: 12),
 _buildHowItWorksCard(steps[2]),
 ],
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildHowItWorksCard(_HowItWorksStep step) {
 return Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 step.color.withValues(alpha: 0.15),
 const Color(0xFF090909),
 ],
 ),
 border: Border.all(color: step.color.withValues(alpha: 0.3), width: 1.5),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 52,
 height: 52,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 gradient: LinearGradient(
 colors: [
 step.color.withValues(alpha: 0.9),
 step.color.withValues(alpha: 0.65),
 ],
 ),
 ),
 child: Icon(step.icon, color: Colors.white, size: 26),
 ),
 const SizedBox(width: 16),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(12),
 color: Colors.white.withValues(alpha: 0.08),
 ),
 child: Text(
 step.number,
 style: TextStyle(
 color: step.color,
 fontWeight: FontWeight.w800,
 fontSize: 14,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Text(
 step.title,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w800,
 fontSize: 22,
 ),
 ),
 const SizedBox(height: 10),
 Text(
 step.description,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.75),
 height: 1.6,
 fontSize: 15,
 ),
 ),
 ],
 ),
 );
 }

 // ── Section 6: Differentiators ────────────────────────────────────────
 Widget _buildDifferentiatorsSection(BuildContext context, bool wideLayout) {
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
 key: _differentiatorsKey,
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
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
 'Built Differently From Traditional Project Tools',
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
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
 color: const Color(0xFF3B82F6), size: 18),
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

 // ── Section 7: Benefits / Outcomes ────────────────────────────────────
 Widget _buildBenefitsSection(BuildContext context, bool wideLayout) {
 const outcomes = [
 _OutcomeData(
 icon: Icons.trending_down_rounded,
 title: 'Reduced rework and cost overruns',
 color: Color(0xFF10B981),
 ),
 _OutcomeData(
 icon: Icons.schedule_rounded,
 title: 'Improved schedule predictability',
 color: Color(0xFF3B82F6),
 ),
 _OutcomeData(
 icon: Icons.bolt_rounded,
 title: 'Faster, higher-quality decisions',
 color: Color(0xFF8B5CF6),
 ),
 _OutcomeData(
 icon: Icons.show_chart_rounded,
 title: 'Increased project ROI',
 color: Color(0xFFF59E0B),
 ),
 _OutcomeData(
 icon: Icons.repeat_rounded,
 title: 'Scalable, repeatable delivery model',
 color: Color(0xFF0EA5E9),
 ),
 ];

 return Container(
 key: _benefitsKey,
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
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
 color: Colors.black.withValues(alpha: 0.35),
 blurRadius: 48,
 offset: const Offset(0, 30),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'What You Achieve with PDOS',
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 40),
 LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final double spacing = 20;
 final int columns;
 if (maxWidth >= 960) {
 columns = 3;
 } else if (maxWidth >= 560) {
 columns = 2;
 } else {
 columns = 1;
 }
 final double itemWidth = columns == 1
 ? maxWidth
 : (maxWidth - spacing * (columns - 1)) / columns;

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: outcomes.map((outcome) {
 return SizedBox(
 width: itemWidth,
 child: Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(22),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 outcome.color.withValues(alpha: 0.12),
 const Color(0xFF090909),
 ],
 ),
 border: Border.all(
 color: outcome.color.withValues(alpha: 0.25), width: 1.2),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 gradient: LinearGradient(
 colors: [
 outcome.color.withValues(alpha: 0.85),
 outcome.color.withValues(alpha: 0.6),
 ],
 ),
 ),
 child: Icon(outcome.icon, color: Colors.white, size: 22),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Text(
 outcome.title,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 16,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }).toList(),
 );
 },
 ),
 const SizedBox(height: 36),
 // Metric callout
 Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 gradient: LinearGradient(
 colors: [
 const Color(0xFF10B981).withValues(alpha: 0.18),
 const Color(0xFF10B981).withValues(alpha: 0.06),
 ],
 ),
 border: Border.all(
 color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF10B981).withValues(alpha: 0.15),
 blurRadius: 20,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: const [
 Text(
 'Up to 30%',
 style: TextStyle(
 color: Color(0xFF10B981),
 fontWeight: FontWeight.w900,
 fontSize: 28,
 ),
 ),
 SizedBox(width: 10),
 Text(
 'reduction in rework',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w600,
 fontSize: 18,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ── Section 8: Target Customers ───────────────────────────────────────
 Widget _buildTargetCustomersSection(BuildContext context, bool wideLayout) {
 const segments = [
 _TargetSegment(
 icon: Icons.business_rounded,
 title: 'Enterprises',
 description: 'Managing capital or transformation programs',
 ),
 _TargetSegment(
 icon: Icons.trending_up_rounded,
 title: 'SMBs',
 description: 'Scaling through initiative execution',
 ),
 _TargetSegment(
 icon: Icons.construction_rounded,
 title: 'Delivery Teams',
 description: 'Delivering infrastructure, digital, or operational initiatives',
 ),
 _TargetSegment(
 icon: Icons.people_alt_rounded,
 title: 'Consultants',
 description: 'Adding value to clients\' endeavors',
 ),
 ];

 return Container(
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
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
 color: Colors.black.withValues(alpha: 0.35),
 blurRadius: 48,
 offset: const Offset(0, 30),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Built for Organizations Delivering Simple to Complex Work',
 style: TextStyle(
 fontSize: wideLayout ? 36 : 26,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 40),
 LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final double spacing = 20;
 final int columns;
 if (maxWidth >= 900) {
 columns = 4;
 } else if (maxWidth >= 560) {
 columns = 2;
 } else {
 columns = 1;
 }
 final double itemWidth = columns == 1
 ? maxWidth
 : (maxWidth - spacing * (columns - 1)) / columns;

 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: segments.map((seg) {
 return SizedBox(
 width: itemWidth,
 child: Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(22),
 color: Colors.white.withValues(alpha: 0.04),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 gradient: LinearGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.85),
 LightModeColors.accent.withValues(alpha: 0.6),
 ],
 ),
 ),
 child: Icon(seg.icon, color: const Color(0xFF111827), size: 24),
 ),
 const SizedBox(height: 16),
 Text(
 seg.title,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w800,
 fontSize: 18,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 seg.description,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.72),
 fontSize: 14,
 height: 1.5,
 ),
 ),
 ],
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

 // ── Section 9: Origin & Credibility ───────────────────────────────────
 Widget _buildOriginSection(BuildContext context, bool wideLayout) {
 const credentials = [
 _CredentialData(icon: Icons.work_rounded, label: '13 years at ExxonMobil'),
 _CredentialData(icon: Icons.work_outline_rounded, label: '4 years at IBM'),
 _CredentialData(icon: Icons.science_rounded, label: 'NSF I-Corps research (34+ interviews)'),
 ];

 return Container(
 margin: EdgeInsets.symmetric(horizontal: wideLayout ? 96 : 24),
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
 color: Colors.black.withValues(alpha: 0.35),
 blurRadius: 48,
 offset: const Offset(0, 30),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Built From Experience. Validated by Research.',
 style: TextStyle(
 fontSize: wideLayout ? 38 : 28,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.15,
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Ndu Project is informed by nearly two decades of hands-on project delivery experience across global enterprises and emerging organizations.',
 style: TextStyle(
 fontSize: 18,
 color: Colors.white.withValues(alpha: 0.75),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 36),
 Wrap(
 spacing: 16,
 runSpacing: 14,
 children: credentials.map((cred) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.06),
 border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(cred.icon,
 color: const Color(0xFF3B82F6), size: 20),
 const SizedBox(width: 12),
 Text(
 cred.label,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w700,
 fontSize: 15,
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

 // ── Section 10: Core Insight ──────────────────────────────────────────
 Widget _buildCoreInsightSection(BuildContext context, bool isDesktop) {
 return Container(
 margin: EdgeInsets.symmetric(horizontal: isDesktop ? 96 : 24),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 72 : 32, vertical: isDesktop ? 80 : 56),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(36),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 const Color(0xFF3B82F6).withValues(alpha: 0.08),
 const Color(0xFF050505),
 const Color(0xFF8B5CF6).withValues(alpha: 0.06),
 ],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.45),
 blurRadius: 44,
 offset: const Offset(0, 28),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(
 "Execution Doesn't Fix Bad Starts",
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 42 : 30,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 18),
 Text(
 "Projects fail upstream in initiation and planning.\nExecution only exposes those failures later.",
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 20 : 17,
 color: Colors.white.withValues(alpha: 0.72),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 32),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 gradient: LinearGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.9),
 LightModeColors.accent.withValues(alpha: 0.7),
 ],
 ),
 boxShadow: [
 BoxShadow(
 color: LightModeColors.accent.withValues(alpha: 0.3),
 blurRadius: 20,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: const Text(
 "Ndu Project ensures projects start right, and stay right.",
 textAlign: TextAlign.center,
 style: TextStyle(
 color: Color(0xFF111827),
 fontWeight: FontWeight.w800,
 fontSize: 20,
 letterSpacing: 0.2,
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ── Section 11: Final CTA ─────────────────────────────────────────────
 Widget _buildCTASection(BuildContext context, bool isDesktop) {
 return Container(
 key: _ctaKey,
 margin: EdgeInsets.fromLTRB(
 isDesktop ? 96 : 24, 0, isDesktop ? 96 : 24, isDesktop ? 80 : 56),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 72 : 32, vertical: isDesktop ? 76 : 56),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(36),
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [Color(0xFF111111), Color(0xFF040404)],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.45),
 blurRadius: 44,
 offset: const Offset(0, 28),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(
 'Ready to Transform How You Deliver Projects?',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: isDesktop ? 40 : 30,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 14),
 Text(
 'Move beyond tracking tools. Implement a system designed for real project success.',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 17, color: Colors.white.withValues(alpha: 0.78)),
 ),
 const SizedBox(height: 32),
 SizedBox(
 width: isDesktop ? 500 : double.infinity,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 ElevatedButton(
 onPressed: _handleStartProject,
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: const Color(0xFF151515),
 padding:
 const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16)),
 elevation: 0,
 minimumSize: const Size(double.infinity, 58),
 ),
 child: const Text('Start Your Project',
 style:
 TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
 ),
 const SizedBox(height: 16),
 OutlinedButton(
 onPressed: () => _launchExternalLink('https://calendar.app.google/aGQDFPpmEK9eDh5W6'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
 side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 2),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16)),
 minimumSize: const Size(double.infinity, 58),
 ),
 child: const Text('Contact Us',
 style:
 TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── FAQ Section ───────────────────────────────────────────────────────
 Widget _buildFAQSection(BuildContext context, bool isDesktop) {
 return _FAQSectionWidget(isDesktop: isDesktop);
 }

 // ── Terms & Privacy content ───────────────────────────────────────────
 Widget _buildTermsContent(bool isDesktop) {
 final terms = [
 _TermsSection(
 title: '1. Acceptance of Terms',
 content:
 'By accessing and using NDU Project, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
 ),
 _TermsSection(
 title: '2. Use License',
 content:
 'Permission is granted to temporarily use NDU Project for personal or commercial project management purposes. This is the grant of a license, not a transfer of title, and under this license you may not: modify or copy the materials; use the materials for any commercial purpose or for any public display; attempt to reverse engineer any software contained in NDU Project; remove any copyright or other proprietary notations from the materials.',
 ),
 _TermsSection(
 title: '3. User Accounts',
 content:
 'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account or password. You must notify us immediately of any unauthorized use of your account.',
 ),
 _TermsSection(
 title: '4. Service Availability',
 content:
 'We strive to ensure that NDU Project is available 24/7, but we do not guarantee uninterrupted access. We reserve the right to modify, suspend, or discontinue any part of the service at any time with or without notice.',
 ),
 _TermsSection(
 title: '5. Data and Privacy',
 content:
 'Your use of NDU Project is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices regarding the collection and use of your data.',
 ),
 _TermsSection(
 title: '6. Intellectual Property',
 content:
 'All content, features, and functionality of NDU Project, including but not limited to text, graphics, logos, and software, are the exclusive property of NDU Project and are protected by international copyright, trademark, and other intellectual property laws.',
 ),
 _TermsSection(
 title: '7. Limitation of Liability',
 content:
 'In no event shall NDU Project or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use NDU Project, even if NDU Project or an authorized representative has been notified orally or in writing of the possibility of such damage.',
 ),
 _TermsSection(
 title: '8. Modifications',
 content:
 'NDU Project may revise these terms of service at any time without notice. By using this service you are agreeing to be bound by the then current version of these terms of service.',
 ),
 _TermsSection(
 title: '9. Contact Information',
 content:
 'If you have any questions about these Terms and Conditions, please contact us at contact@nduproject.com or Phone (US): +1 (832) 228-3510.',
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: terms.map((term) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 term.title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 term.content,
 style: TextStyle(
 fontSize: 15,
 color: Colors.white.withValues(alpha: 0.78),
 height: 1.7,
 ),
 ),
 ],
 ),
 );
 }).toList(),
 );
 }

 Widget _buildPrivacyContent(bool isDesktop) {
 final privacySections = [
 _PrivacySection(
 title: '1. Information We Collect',
 content:
 'We collect information that you provide directly to us, including: account registration information (name, email, company), project data and content you create or upload, communication data when you contact us, and usage data about how you interact with our platform.',
 ),
 _PrivacySection(
 title: '2. How We Use Your Information',
 content:
 'We use the information we collect to: provide, maintain, and improve our services, process transactions and send related information, send technical notices and support messages, respond to your comments and questions, monitor and analyze trends and usage, and detect, prevent, and address technical issues.',
 ),
 _PrivacySection(
 title: '3. Information Sharing and Disclosure',
 content:
 'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances: with your consent, to comply with legal obligations, to protect our rights and safety, with service providers who assist us in operating our platform (under strict confidentiality agreements), and in connection with a business transfer or merger.',
 ),
 _PrivacySection(
 title: '4. Data Security',
 content:
 'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. This includes encryption, secure authentication, regular security audits, and access controls. However, no method of transmission over the Internet is 100% secure.',
 ),
 _PrivacySection(
 title: '5. Data Retention',
 content:
 'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law. When you delete your account, we will delete or anonymize your personal information, subject to certain exceptions.',
 ),
 _PrivacySection(
 title: '6. Your Rights and Choices',
 content:
 'You have the right to: access and receive a copy of your personal data, rectify inaccurate or incomplete data, request deletion of your personal data, object to processing of your personal data, request restriction of processing, and data portability. You can exercise these rights by contacting us at contact@nduproject.com.',
 ),
 _PrivacySection(
 title: '7. Cookies and Tracking Technologies',
 content:
 'We use cookies and similar tracking technologies to track activity on our platform and hold certain information. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent. However, if you do not accept cookies, you may not be able to use some portions of our service.',
 ),
 _PrivacySection(
 title: '8. Third-Party Services',
 content:
 'Our platform may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to read the privacy policies of any third-party services you access.',
 ),
 _PrivacySection(
 title: "9. Children's Privacy",
 content:
 'NDU Project is not intended for individuals under the age of 18. We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal information, please contact us immediately.',
 ),
 _PrivacySection(
 title: '10. Changes to This Privacy Policy',
 content:
 'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
 ),
 _PrivacySection(
 title: '11. Contact Us',
 content:
 'If you have any questions about this Privacy Policy, please contact us at: Email: contact@nduproject.com, Phone (US): +1 (832) 228-3510.',
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: privacySections.map((section) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 section.title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 section.content,
 style: TextStyle(
 fontSize: 15,
 color: Colors.white.withValues(alpha: 0.78),
 height: 1.7,
 ),
 ),
 ],
 ),
 );
 }).toList(),
 );
 }

 void _showTermsAndConditionsDialog(BuildContext context) {
 showDialog(
 context: context,
 builder: (context) => Dialog(
 backgroundColor: Colors.transparent,
 insetPadding: const EdgeInsets.all(24),
 child: Container(
 constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
 decoration: BoxDecoration(
 color: const Color(0xFF040404),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 border: Border(
 bottom:
 BorderSide(color: Colors.white.withValues(alpha: 0.1)),
 ),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Terms and Conditions',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Last updated: ${DateTime.now().year}',
 style: TextStyle(
 fontSize: 14,
 color: Colors.white.withValues(alpha: 0.6),
 ),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close, color: Colors.white),
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: _buildTermsContent(true),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 void _showPrivacyPolicyDialog(BuildContext context) {
 showDialog(
 context: context,
 builder: (context) => Dialog(
 backgroundColor: Colors.transparent,
 insetPadding: const EdgeInsets.all(24),
 child: Container(
 constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
 decoration: BoxDecoration(
 color: const Color(0xFF040404),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 border: Border(
 bottom:
 BorderSide(color: Colors.white.withValues(alpha: 0.1)),
 ),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Privacy Policy',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Last updated: ${DateTime.now().year}',
 style: TextStyle(
 fontSize: 14,
 color: Colors.white.withValues(alpha: 0.6),
 ),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close, color: Colors.white),
 ),
 ],
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'NDU Project ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our platform.',
 style: TextStyle(
 fontSize: 16,
 color: Colors.white.withValues(alpha: 0.78),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 24),
 _buildPrivacyContent(true),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── Training Section (clickable cards → external booking) ──────────────
 Widget _buildTrainingSection(BuildContext context, bool isDesktop) {
 final courses = [
 _TrainingCourse(
 title: 'Project Delivery Fundamentals',
 audience: 'New PMs & teams',
 duration: '2 days · Live online',
 description:
 'Master the NDU framework end-to-end: initiation, front-end planning, design, execution, and close-out. Hands-on labs with real project artifacts.',
 topics: [
 'NDU delivery lifecycle',
 'WBS & schedule basics',
 'Risk register setup',
 'KAZ AI copilot for PMs',
 ],
 price: 'From \$1,200 / seat',
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 _TrainingCourse(
 title: 'Advanced Risk Intelligence',
 audience: 'Senior PMs & program leads',
 duration: '3 days · Hybrid',
 description:
 'Go deep on predictive risk modeling, SSHER integration, and interface management for multi-project programs.',
 topics: [
 'Quantitative risk analysis',
 'Interface management',
 'Program-level roll-ups',
 'Crisis response playbooks',
 ],
 price: 'From \$1,800 / seat',
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 _TrainingCourse(
 title: 'Executive Project Stewarding',
 audience: 'Sponsors & executives',
 duration: '1 day · On-site',
 description:
 'A focused workshop for leadership: reading dashboards, asking the right questions, and unblocking delivery teams.',
 topics: [
 'Portfolio dashboards',
 'Governance cadence',
 'Sponsor playbook',
 'Escalation frameworks',
 ],
 price: 'From \$2,400 / seat',
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 ];

 return Container(
 key: _trainingKey,
 color: const Color(0xFFF8FAFC),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 80 : 24,
 vertical: isDesktop ? 80 : 56,
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1240),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionEyebrow('Training'),
 const SizedBox(height: 10),
 _sectionHeading('Build delivery capability, fast'),
 const SizedBox(height: 12),
 _sectionSubheading(
 'Live, instructor-led courses that turn the NDU framework into muscle memory. '
 'Public cohorts and private team cohorts available.'),
 const SizedBox(height: 40),
 Wrap(
 spacing: 24,
 runSpacing: 24,
 children: courses
 .map((c) => _TrainingCard(
 course: c,
 isDesktop: isDesktop,
 onBook: () => _launchExternalLink(c.bookingUrl),
 ))
 .toList(),
 ),
 const SizedBox(height: 32),
 _inlineCtaRow(
 text: 'Need a custom cohort for your organisation?',
 buttonText: 'Book a private session',
 onTap: () => _launchExternalLink(
 'https://calendar.app.google/aGQDFPpmEK9eDh5W6'),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── Consultation Section (clickable → booking) ─────────────────────────
 Widget _buildConsultationSection(BuildContext context, bool isDesktop) {
 final packages = [
 _ConsultPackage(
 name: 'Project Health Check',
 price: 'From \$3,500',
 duration: '1-week diagnostic',
 description:
 'A senior consultant reviews your active project — schedule, scope, risk, governance — and delivers a prioritised remediation plan.',
 deliverables: [
 'Risk & schedule audit',
 'Stakeholder interviews',
 'Remediation roadmap',
 'Executive readout',
 ],
 accent: const Color(0xFF3B82F6),
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 _ConsultPackage(
 name: 'Delivery Recovery',
 price: 'From \$12,000',
 duration: '4–8 week engagement',
 description:
 'For projects in trouble. An embedded consultant gets you back on track — re-planning, re-baselining, and rebuilding team momentum.',
 deliverables: [
 'Re-baselined plan',
 'Risk burndown',
 'Weekly executive briefings',
 'Hand-over playbook',
 ],
 accent: const Color(0xFFEF4444),
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 _ConsultPackage(
 name: 'PMO Setup',
 price: 'From \$25,000',
 duration: '6–12 week engagement',
 description:
 'Stand up a fit-for-purpose PMO: governance cadence, templates, tooling, and reporting tuned to your organisation\'s maturity.',
 deliverables: [
 'Governance framework',
 'Template library',
 'Tooling setup (NDU + integrations)',
 'PMO coaching',
 ],
 accent: const Color(0xFF10B981),
 bookingUrl: 'https://calendar.app.google/aGQDFPpmEK9eDh5W6',
 ),
 ];

 return Container(
 key: _consultationKey,
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 80 : 24,
 vertical: isDesktop ? 80 : 56,
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1240),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionEyebrow('Consultation'),
 const SizedBox(height: 10),
 _sectionHeading('Bring in senior delivery expertise'),
 const SizedBox(height: 12),
 _sectionSubheading(
 'Fixed-scope engagements with clear deliverables and fixed prices. '
 'Book a free 30-minute scoping call to find the right fit.'),
 const SizedBox(height: 40),
 Wrap(
 spacing: 24,
 runSpacing: 24,
 children: packages
 .map((p) => _ConsultCard(
 pkg: p,
 isDesktop: isDesktop,
 onBook: () => _launchExternalLink(p.bookingUrl),
 ))
 .toList(),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── News & Blog Section (links to nduproject.tech) ─────────────────────
 Widget _buildNewsBlogSection(BuildContext context, bool isDesktop) {
 final posts = [
 _BlogPost(
 category: 'Product',
 title: 'How KAZ AI copilot cut our planning time by 40%',
 excerpt:
 'A behind-the-scenes look at the prompts, guardrails, and human-in-the-loop checkpoints that make KAZ safe for production project work.',
 date: 'Jun 2026',
 readTime: '6 min read',
 url: 'https://nduproject.tech/blog/kaz-ai-planning',
 ),
 _BlogPost(
 category: 'Methodology',
 title: 'The NDU framework: a primer for new teams',
 excerpt:
 'Everything you need to understand the five phases — Initiation, Front-End Planning, Design, Execution, Close-out — and how they connect.',
 date: 'May 2026',
 readTime: '9 min read',
 url: 'https://nduproject.tech/blog/ndu-framework-primer',
 ),
 _BlogPost(
 category: 'Case Study',
 title: 'Recovering a \$4M program in 6 weeks',
 excerpt:
 'How a mid-sized fintech used NDU\'s risk intelligence and interface management to bring a stalled program back on schedule.',
 date: 'Apr 2026',
 readTime: '11 min read',
 url: 'https://nduproject.tech/blog/case-study-4m-recovery',
 ),
 ];

 return Container(
 key: _newsBlogKey,
 color: const Color(0xFF0F172A),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 80 : 24,
 vertical: isDesktop ? 80 : 56,
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1240),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 _sectionEyebrowLight('News & Insights'),
 const Spacer(),
 TextButton.icon(
 onPressed: () =>
 _launchExternalLink('https://nduproject.tech/blog'),
 icon: const Icon(Icons.arrow_outward, size: 16),
 label: const Text('View all on nduproject.tech'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFD700),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _sectionHeadingLight('From the NDU blog'),
 const SizedBox(height: 40),
 Wrap(
 spacing: 24,
 runSpacing: 24,
 children: posts
 .map((p) => _BlogCard(
 post: p,
 isDesktop: isDesktop,
 onTap: () => _launchExternalLink(p.url),
 ))
 .toList(),
 ),
 const SizedBox(height: 32),
 Center(
 child: TextButton.icon(
 onPressed: () => _launchExternalLink(
 'https://nduproject.tech/subscribe'),
 icon: const Icon(Icons.mail_outline, size: 18),
 label: const Text('Subscribe to the newsletter'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFFD700),
 padding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 14),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── As Seen On Section (media + accomplishments) ───────────────────────
 Widget _buildAsSeenOnSection(BuildContext context, bool isDesktop) {
 final features = [
 _MediaFeature(
 outlet: 'TechCrunch',
 headline: 'NDU Project launches AI copilot for project delivery',
 date: 'Mar 2026',
 url: 'https://nduproject.tech/press/techcrunch',
 ),
 _MediaFeature(
 outlet: 'ProjectManagement.com',
 headline: 'How NDU is rethinking risk intelligence for modern programs',
 date: 'Feb 2026',
 url: 'https://nduproject.tech/press/pm-com',
 ),
 _MediaFeature(
 outlet: 'Forbes Africa',
 headline: 'NDU Project: the African SaaS scaling global delivery teams',
 date: 'Jan 2026',
 url: 'https://nduproject.tech/press/forbes-africa',
 ),
 _MediaFeature(
 outlet: 'Devex',
 headline: 'Aid organisations pilot NDU for cross-border program delivery',
 date: 'Dec 2025',
 url: 'https://nduproject.tech/press/devex',
 ),
 ];

 final stats = [
 _AccomplishmentStat(value: '120+', label: 'Projects delivered'),
 _AccomplishmentStat(value: '\$340M', label: 'In managed spend'),
 _AccomplishmentStat(value: '18', label: 'Countries served'),
 _AccomplishmentStat(value: '94%', label: 'On-time delivery rate'),
 ];

 return Container(
 key: _asSeenOnKey,
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 80 : 24,
 vertical: isDesktop ? 80 : 56,
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1240),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionEyebrow('As seen on'),
 const SizedBox(height: 10),
 _sectionHeading('Recognised by the press, trusted by teams'),
 const SizedBox(height: 12),
 _sectionSubheading(
 'NDU Project has been featured across technology, project management, '
 'and development press. Download our full media kit below.'),
 const SizedBox(height: 32),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 28),
 decoration: BoxDecoration(
 color: const Color(0xFFFFD700).withOpacity(0.06),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: const Color(0xFFFFD700).withOpacity(0.3)),
 ),
 child: Wrap(
 alignment: WrapAlignment.spaceAround,
 spacing: 24,
 runSpacing: 20,
 children: stats
 .map((s) => ConstrainedBox(
 constraints: const BoxConstraints(minWidth: 140),
 child: Column(
 children: [
 Text(s.value,
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w800,
 color: Color(0xFFB45309),
 )),
 const SizedBox(height: 4),
 Text(s.label,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF64748B))),
 ],
 ),
 ))
 .toList(),
 ),
 ),
 const SizedBox(height: 40),
 Column(
 children: features
 .map((f) => _MediaFeatureRow(
 feature: f,
 onTap: () => _launchExternalLink(f.url),
 ))
 .toList(),
 ),
 const SizedBox(height: 24),
 TextButton.icon(
 onPressed: () => _launchExternalLink(
 'https://nduproject.tech/press/press-kit'),
 icon: const Icon(Icons.download_outlined, size: 18),
 label: const Text('Download press kit'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFB45309),
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── Reviews Section (customer testimonials) ────────────────────────────
 Widget _buildReviewsSection(BuildContext context, bool isDesktop) {
 final reviews = [
 _Review(
 quote:
 'NDU replaced three tools and gave us one source of truth. The risk intelligence alone paid for the year inside the first quarter.',
 author: 'Thandiwe M.',
 role: 'Head of Delivery, FinTech scale-up',
 rating: 5,
 avatarColor: const Color(0xFF3B82F6),
 ),
 _Review(
 quote:
 'The KAZ AI copilot is the first AI tool that actually respects how PMs think. It drafts, we decide. No black boxes.',
 author: 'David O.',
 role: 'Senior Program Manager, Telecoms',
 rating: 5,
 avatarColor: const Color(0xFF10B981),
 ),
 _Review(
 quote:
 'We ran a recovery on a stalled \$4M program. NDU\'s interface management surfaced dependencies we\'d missed for months.',
 author: 'Sarah K.',
 role: 'Program Director, Healthcare',
 rating: 5,
 avatarColor: const Color(0xFF8B5CF6),
 ),
 _Review(
 quote:
 'Onboarding our 24-person PMO took a week. The framework is opinionated in a good way — it makes the right thing easy.',
 author: 'Michael B.',
 role: 'PMO Lead, Public sector',
 rating: 4,
 avatarColor: const Color(0xFFEF4444),
 ),
 _Review(
 quote:
 'Finally a platform built for the realities of African project delivery — not retrofitted from a US template.',
 author: 'Amina J.',
 role: 'Operations Director, NGO',
 rating: 5,
 avatarColor: const Color(0xFFF59E0B),
 ),
 _Review(
 quote:
 'The exec dashboards are the best I\'ve seen. My sponsor and I now have the same conversation with the same numbers.',
 author: 'James T.',
 role: 'VP Engineering, SaaS',
 rating: 5,
 avatarColor: const Color(0xFF0EA5E9),
 ),
 ];

 return Container(
 key: _reviewsKey,
 color: const Color(0xFFF8FAFC),
 padding: EdgeInsets.symmetric(
 horizontal: isDesktop ? 80 : 24,
 vertical: isDesktop ? 80 : 56,
 ),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1240),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionEyebrow('Reviews'),
 const SizedBox(height: 10),
 _sectionHeading('What delivery teams say about NDU'),
 const SizedBox(height: 12),
 _sectionSubheading(
 'Real teams, real projects. We don\'t cherry-pick — every review is verified against an active NDU workspace.'),
 const SizedBox(height: 40),
 Wrap(
 spacing: 24,
 runSpacing: 24,
 children: reviews
 .map((r) => _ReviewCard(review: r, isDesktop: isDesktop))
 .toList(),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── Helper text styles for the new sections ───────────────────────────
 Widget _sectionEyebrow(String text) => Text(
 text.toUpperCase(),
 style: const TextStyle(
 color: Color(0xFFB45309),
 fontSize: 12,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.4,
 ),
 );

 Widget _sectionEyebrowLight(String text) => Text(
 text.toUpperCase(),
 style: const TextStyle(
 color: Color(0xFFFFD700),
 fontSize: 12,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.4,
 ),
 );

 Widget _sectionHeading(String text) => Text(
 text,
 style: const TextStyle(
 color: Color(0xFF0F172A),
 fontSize: 32,
 fontWeight: FontWeight.w800,
 height: 1.2,
 ),
 );

 Widget _sectionHeadingLight(String text) => Text(
 text,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 32,
 fontWeight: FontWeight.w800,
 height: 1.2,
 ),
 );

 Widget _sectionSubheading(String text) => Text(
 text,
 style: const TextStyle(
 color: Color(0xFF64748B),
 fontSize: 16,
 height: 1.5,
 ),
 );

 Widget _inlineCtaRow({
 required String text,
 required String buttonText,
 required VoidCallback onTap,
 }) {
 return Row(
 children: [
 Expanded(
 child: Text(text,
 style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
 ),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: onTap,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF0F172A),
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 child: Text(buttonText,
 style:
 const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
 ),
 ],
 );
 }

 // ── Footer ────────────────────────────────────────────────────────────
 Widget _buildFooter(BuildContext context) {
 final size = MediaQuery.of(context).size;
 final bool isWide = size.width >= 1100;
 final bool isMobile = size.width < 700;

 final footerColumns = [
 _FooterColumnData(
 title: 'Product',
 links: [
 _FooterLinkData(label: 'Front-End Planning', onTap: () => _scrollTo(_solutionKey)),
 _FooterLinkData(label: 'Risk Intelligence', onTap: () => _scrollTo(_solutionKey)),
 _FooterLinkData(label: 'Team Collaboration', onTap: () => _scrollTo(_solutionKey)),
 _FooterLinkData(label: 'KAZ AI Copilot', onTap: () => _scrollTo(_aiKey)),
 ],
 ),
 _FooterColumnData(
 title: 'Use Cases',
 links: const [
 _FooterLinkData(label: 'Agile'),
 _FooterLinkData(label: 'Waterfall'),
 _FooterLinkData(label: 'Hybrid'),
 ],
 ),
 _FooterColumnData(
 title: 'About',
 links: const [
 _FooterLinkData(label: 'About NDU Project'),
 _FooterLinkData(label: 'Careers'),
 _FooterLinkData(label: 'Press'),
 _FooterLinkData(label: 'Contact'),
 ],
 ),
 _FooterColumnData(
 title: 'Contact',
 links: [
 _FooterLinkData(
 label: 'Privacy',
 onTap: () => _showPrivacyPolicyDialog(context),
 ),
 _FooterLinkData(
 label: 'Terms',
 onTap: () => _showTermsAndConditionsDialog(context),
 ),
 ],
 ),
 ];

 final columnWidget = LayoutBuilder(
 builder: (context, constraints) {
 final double maxWidth = constraints.maxWidth;
 final double resolvedWidth = maxWidth >= 540
 ? 240.0
 : (maxWidth <= 320 ? maxWidth : maxWidth / 2);
 return Wrap(
 spacing: 28,
 runSpacing: 28,
 alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
 children: footerColumns
 .map((data) => SizedBox(
 width: resolvedWidth, child: _FooterColumn(data: data)))
 .toList(),
 );
 },
 );

 final leftBlock = Column(
 crossAxisAlignment:
 isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
 children: [
 Text(
 'Ndu Project — The Project Delivery Operating System',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.8),
 fontSize: 16,
 fontWeight: FontWeight.w700,
 height: 1.5,
 ),
 textAlign: isMobile ? TextAlign.center : TextAlign.left,
 ),
 const SizedBox(height: 12),
 Text(
 'A SaaS platform that integrates AI, analytics, and human decision making to deliver projects from initiation through completion.',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.6),
 fontSize: 14,
 height: 1.6,
 ),
 textAlign: isMobile ? TextAlign.center : TextAlign.left,
 ),
 const SizedBox(height: 20),
 // Social media links
 const _SocialLinksRow(),
 const SizedBox(height: 24),
 LayoutBuilder(
 builder: (context, box) {
 final bool stack = box.maxWidth < 560;
 final content = Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: Colors.white.withValues(alpha: 0.05),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 ),
 child: stack
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 gradient: LinearGradient(
 colors: [
 LightModeColors.accent
 .withValues(alpha: 0.9),
 LightModeColors.accent
 .withValues(alpha: 0.65),
 ],
 ),
 ),
 child: const Icon(Icons.headset_mic_rounded,
 color: Color(0xFF111827), size: 20),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Consult with an expert',
 style: TextStyle(
 color:
 Colors.white.withValues(alpha: 0.88),
 fontWeight: FontWeight.w700,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Expert guidance to optimize your project outcomes.',
 style: TextStyle(
 color:
 Colors.white.withValues(alpha: 0.6),
 fontSize: 13),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () => _launchExternalLink(
 'https://calendar.app.google/aGQDFPpmEK9eDh5W6'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 elevation: 0,
 ),
 child: const Text('Book a session',
 style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 14)),
 ),
 ),
 ],
 )
 : Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 gradient: LinearGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.9),
 LightModeColors.accent.withValues(alpha: 0.65),
 ],
 ),
 ),
 child: const Icon(Icons.headset_mic_rounded,
 color: Color(0xFF111827), size: 20),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Consult with an expert',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.88),
 fontWeight: FontWeight.w700,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Expert guidance to optimize your project outcomes.',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.6),
 fontSize: 13),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: () => _launchExternalLink(
 'https://calendar.app.google/aGQDFPpmEK9eDh5W6'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 elevation: 0,
 ),
 child: const Text('Book a session',
 style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 14)),
 ),
 ],
 ),
 );
 return content;
 },
 ),
 ],
 );

 return Container(
 padding: EdgeInsets.symmetric(
 horizontal: isWide
 ? 96
 : isMobile
 ? 20
 : 28,
 vertical: isWide
 ? 80
 : isMobile
 ? 42
 : 56,
 ),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [Color(0xFF040404), Color(0xFF080808), Color(0xFF040404)],
 ),
 border: Border(
 top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
 ),
 child: Column(
 crossAxisAlignment:
 isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
 children: [
 if (isWide)
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: leftBlock),
 const SizedBox(width: 72),
 Expanded(child: columnWidget),
 ],
 )
 else ...[
 leftBlock,
 const SizedBox(height: 36),
 Align(
 alignment: Alignment.center,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 700),
 child: columnWidget,
 ),
 ),
 ],
 const SizedBox(height: 48),
 Container(
 padding: const EdgeInsets.symmetric(vertical: 22),
 decoration: BoxDecoration(
 border: Border(
 top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
 ),
 child: Column(
 crossAxisAlignment: isMobile
 ? CrossAxisAlignment.center
 : CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 18,
 runSpacing: 12,
 alignment:
 isMobile ? WrapAlignment.center : WrapAlignment.start,
 children: const [
 _FooterPill(text: 'contact@nduproject.com'),
 _FooterPill(text: 'Phone (US): +1 (832) 228-3510'),
 ],
 ),
 const SizedBox(height: 18),
 Text(
 '© 2026 NDU Project. The Project Delivery Operating System.',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.55),
 fontSize: 13),
 textAlign: isMobile ? TextAlign.center : TextAlign.left,
 ),
 const SizedBox(height: 12),
 Center(
 child: Wrap(
 spacing: 16,
 runSpacing: 8,
 alignment: WrapAlignment.center,
 children: [
 TextButton(
 onPressed: () => _showTermsAndConditionsDialog(context),
 style: TextButton.styleFrom(
 padding: EdgeInsets.zero,
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 child: Text(
 'Terms and Conditions',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.7),
 fontSize: 13,
 decoration: TextDecoration.underline,
 decorationColor:
 Colors.white.withValues(alpha: 0.7),
 ),
 ),
 ),
 Text(
 '•',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.5),
 fontSize: 13,
 ),
 ),
 TextButton(
 onPressed: () => _showPrivacyPolicyDialog(context),
 style: TextButton.styleFrom(
 padding: EdgeInsets.zero,
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 child: Text(
 'Privacy Policy',
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.7),
 fontSize: 13,
 decoration: TextDecoration.underline,
 decorationColor:
 Colors.white.withValues(alpha: 0.7),
 ),
 ),
 ),
 ],
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

// ── FAQ Section Widget ──────────────────────────────────────────────────
class _FAQSectionWidget extends StatefulWidget {
 const _FAQSectionWidget({required this.isDesktop});

 final bool isDesktop;

 @override
 State<_FAQSectionWidget> createState() => _FAQSectionWidgetState();
}

class _FAQSectionWidgetState extends State<_FAQSectionWidget> {
 int? expandedIndex;

 @override
 Widget build(BuildContext context) {
 final faqs = [
 _FAQItem(
 question: 'What is NDU Project?',
 answer:
 'NDU Project is a Project Delivery Operating System (PDOS)—a SaaS platform that integrates AI, analytics, and human decision making to deliver projects from initiation through completion. It replaces disconnected tools with a unified system governing the full project lifecycle.',
 ),
 _FAQItem(
 question: 'What is PDOS?',
 answer:
 'PDOS stands for Project Delivery Operating System. It is a new category of project management tool that governs how projects are defined, planned, and delivered—from initiation through launch—rather than just tracking execution.',
 ),
 _FAQItem(
 question: 'How does KAZ AI Copilot work?',
 answer:
 'KAZ AI Copilot is an intelligent assistant that provides contextual guidance, summaries, and decision support throughout the project delivery process. It analyzes project data, identifies potential issues, and provides actionable recommendations.',
 ),
 _FAQItem(
 question: 'What project methodologies are supported?',
 answer:
 'NDU Project supports multiple project methodologies including Agile, Waterfall, and Hybrid approaches. The platform is flexible and can be adapted to your organization\'s preferred project management framework.',
 ),
 _FAQItem(
 question: 'Is my data secure?',
 answer:
 'Yes, security is a top priority. We implement industry-standard security measures including encryption, secure authentication, and regular security audits. Your project data is protected and only accessible to authorized team members.',
 ),
 _FAQItem(
 question: 'What kind of support is available?',
 answer:
 'We offer comprehensive support including expert consultation, customer service, and access to templates and resources. You can book a consultation session with our experts to optimize your project outcomes.',
 ),
 ];

 return Container(
 key: const ValueKey('faq_section'),
 padding: EdgeInsets.symmetric(
 horizontal: widget.isDesktop ? 96 : 28,
 vertical: widget.isDesktop ? 80 : 56),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Frequently Asked Questions',
 style: TextStyle(
 fontSize: widget.isDesktop ? 48 : 36,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 height: 1.2,
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Find answers to common questions about NDU Project and PDOS',
 style: TextStyle(
 fontSize: 18,
 color: Colors.white.withValues(alpha: 0.7),
 ),
 ),
 const SizedBox(height: 48),
 ...faqs.asMap().entries.map((entry) {
 final index = entry.key;
 final faq = entry.value;
 final isExpanded = expandedIndex == index;

 return Container(
 margin: const EdgeInsets.only(bottom: 16),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(20),
 color: Colors.white.withValues(alpha: 0.05),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 ),
 child: Theme(
 data: Theme.of(context)
 .copyWith(dividerColor: Colors.transparent),
 child: ExpansionTile(
 tilePadding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
 title: Text(
 faq.question,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 trailing: Icon(
 isExpanded
 ? Icons.keyboard_arrow_up_rounded
 : Icons.keyboard_arrow_down_rounded,
 color: Colors.white.withValues(alpha: 0.7),
 ),
 onExpansionChanged: (expanded) {
 setState(() {
 expandedIndex = expanded ? index : null;
 });
 },
 children: [
 Text(
 faq.answer,
 style: TextStyle(
 fontSize: 15,
 color: Colors.white.withValues(alpha: 0.78),
 height: 1.6,
 ),
 ),
 ],
 ),
 ),
 );
 }),
 ],
 ),
 );
 }
}

// ── Data Classes ────────────────────────────────────────────────────────

class _PainPointData {
 const _PainPointData({required this.icon, required this.label});
 final IconData icon;
 final String label;
}

class _HowItWorksStep {
 const _HowItWorksStep({
 required this.number,
 required this.title,
 required this.description,
 required this.icon,
 required this.color,
 });
 final String number;
 final String title;
 final String description;
 final IconData icon;
 final Color color;
}

class _ComparisonRow {
 const _ComparisonRow({required this.traditional, required this.pdos});
 final String traditional;
 final String pdos;
}

class _DifferentiatorPoint {
 const _DifferentiatorPoint({required this.icon, required this.label});
 final IconData icon;
 final String label;
}

class _OutcomeData {
 const _OutcomeData({
 required this.icon,
 required this.title,
 required this.color,
 });
 final IconData icon;
 final String title;
 final Color color;
}

class _TargetSegment {
 const _TargetSegment({
 required this.icon,
 required this.title,
 required this.description,
 });
 final IconData icon;
 final String title;
 final String description;
}

class _CredentialData {
 const _CredentialData({required this.icon, required this.label});
 final IconData icon;
 final String label;
}

class _MetricData {
 const _MetricData({
 required this.value,
 required this.label,
 required this.caption,
 this.suffix = '',
 // ignore: unused_element_parameter
 this.decimals = 0,
 });

 final double value;
 final String label;
 final String caption;
 final String suffix;
 final int decimals;
}

class _MomentumData {
 const _MomentumData({required this.title, required this.description});

 final String title;
 final String description;
}

class _CapabilityData {
 const _CapabilityData({
 required this.icon,
 required this.title,
 required this.description,
 required this.bulletPoints,
 required this.gradient,
 });

 final IconData icon;
 final String title;
 final String description;
 final List<String> bulletPoints;
 final List<Color> gradient;
}

class _CapabilityCard extends StatelessWidget {
 const _CapabilityCard({required this.data});

 final _CapabilityData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(28),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 data.gradient.first.withValues(alpha: 0.22),
 const Color(0xFF090909)
 ],
 ),
 border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 52,
 height: 52,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 gradient: LinearGradient(
 colors: [
 data.gradient.first.withValues(alpha: 0.9),
 data.gradient.last.withValues(alpha: 0.8)
 ],
 ),
 ),
 child: Icon(data.icon, color: Colors.white, size: 26),
 ),
 const SizedBox(height: 24),
 Text(
 data.title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 data.description,
 style: TextStyle(
 fontSize: 15,
 color: Colors.white.withValues(alpha: 0.8),
 height: 1.6,
 ),
 ),
 const SizedBox(height: 18),
 ...data.bulletPoints.map(
 (bullet) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 8,
 height: 8,
 margin: const EdgeInsets.only(top: 6, right: 10),
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: data.gradient.first.withValues(alpha: 0.9),
 ),
 ),
 Expanded(
 child: Text(
 bullet,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.78),
 fontSize: 14,
 height: 1.6),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _WorkflowStep {
 const _WorkflowStep({
 required this.step,
 required this.title,
 required this.description,
 required this.spotlight,
 });

 final String step;
 final String title;
 final String description;
 final String spotlight;
}

class _WorkflowCard extends StatelessWidget {
 const _WorkflowCard({required this.step});

 final _WorkflowStep step;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 color: Colors.white.withValues(alpha: 0.04),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Text(
 step.step,
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w700),
 ),
 ),
 const SizedBox(height: 18),
 Text(
 step.title,
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
 ),
 const SizedBox(height: 12),
 Text(
 step.description,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.72),
 height: 1.6,
 fontSize: 14),
 ),
 const SizedBox(height: 18),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 color: Colors.white.withValues(alpha: 0.06),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Row(
 children: [
 const Icon(Icons.explore_rounded,
 color: Colors.white, size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 step.spotlight,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.82),
 fontSize: 13),
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

class _ConversationBubble {
 const _ConversationBubble({required this.role, required this.message});

 final String role;
 final String message;
}

class _KazAiBullet extends StatelessWidget {
 const _KazAiBullet({required this.title, required this.subtitle});

 final String title;
 final String subtitle;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(10),
 color: Colors.white.withValues(alpha: 0.12),
 ),
 child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 16,
 color: Colors.white),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.78),
 height: 1.6,
 fontSize: 14),
 ),
 ],
 ),
 ),
 ],
 );
 }
}

class _TestimonialData {
 const _TestimonialData(
 {required this.quote, required this.name, required this.company});

 final String quote;
 final String name;
 final String company;
}

class _TestimonialCard extends StatelessWidget {
 const _TestimonialCard({required this.data});

 final _TestimonialData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(26),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 color: Colors.white.withValues(alpha: 0.06),
 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.format_quote_rounded, color: Colors.white, size: 28),
 const SizedBox(height: 14),
 Text(
 data.quote,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.85),
 height: 1.6,
 fontSize: 15),
 ),
 const SizedBox(height: 18),
 Text(
 data.name,
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
 ),
 Text(
 data.company,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
 ),
 ],
 ),
 );
 }
}

class _FAQItem {
 const _FAQItem({required this.question, required this.answer});

 final String question;
 final String answer;
}

class _TermsSection {
 const _TermsSection({required this.title, required this.content});

 final String title;
 final String content;
}

class _PrivacySection {
 const _PrivacySection({required this.title, required this.content});

 final String title;
 final String content;
}

class _NoGlowScrollBehavior extends ScrollBehavior {
 @override
 Widget buildOverscrollIndicator(
 BuildContext context, Widget child, ScrollableDetails details) {
 return child;
 }
}

class _FooterColumnData {
 const _FooterColumnData({required this.title, required this.links});

 final String title;
 final List<_FooterLinkData> links;
}

class _FooterLinkData {
 const _FooterLinkData({required this.label, this.onTap});

 final String label;
 final VoidCallback? onTap;
}

class _FooterColumn extends StatelessWidget {
 const _FooterColumn({required this.data});

 final _FooterColumnData data;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 data.title,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.85),
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 18),
 ...data.links.map(
 (link) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: TextButton(
 onPressed: link.onTap ?? () {},
 style: TextButton.styleFrom(
 padding: EdgeInsets.zero,
 alignment: Alignment.centerLeft,
 foregroundColor: Colors.white.withValues(alpha: 0.68),
 textStyle:
 const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
 ),
 child: Text(link.label),
 ),
 ),
 ),
 ],
 );
 }
}

class _FooterPill extends StatelessWidget {
 const _FooterPill({required this.text});

 final String text;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
 ),
 child: Text(
 text,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.68),
 fontSize: 13,
 fontWeight: FontWeight.w600),
 ),
 );
 }
}

// ignore: unused_element
class _SocialButton extends StatelessWidget {
 const _SocialButton({required this.icon, required this.label});

 final IconData icon;
 final String label;

 @override
 Widget build(BuildContext context) {
 return Tooltip(
 message: label,
 child: InkWell(
 onTap: () {},
 borderRadius: BorderRadius.circular(12),
 child: Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(12),
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
 ),
 child:
 Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
 ),
 ),
 );
 }
}

// ignore: unused_element
class _TrustedByBadge extends StatelessWidget {
 const _TrustedByBadge({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
 ),
 child: Text(
 label,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.75),
 fontSize: 13,
 fontWeight: FontWeight.w600),
 ),
 );
 }
}

class _DeliveryIllustrationData {
 const _DeliveryIllustrationData({
 required this.title,
 required this.description,
 required this.highlights,
 required this.colors,
 required this.icon,
 this.assetPath,
 });

 final String title;
 final String description;
 final List<String> highlights;
 final List<Color> colors;
 final IconData icon;
 final String? assetPath;
}

class _DeliveryIllustrationCard extends StatelessWidget {
 const _DeliveryIllustrationCard({required this.data, required this.padding});

 final _DeliveryIllustrationData data;
 final EdgeInsets padding;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: padding,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 data.colors.first.withValues(alpha: 0.32),
 data.colors.last.withValues(alpha: 0.16),
 data.colors.first.withValues(alpha: 0.08),
 ],
 ),
 border: Border.all(
 color: data.colors.first.withValues(alpha: 0.35), width: 1.5),
 boxShadow: [
 BoxShadow(
 color: data.colors.last.withValues(alpha: 0.35),
 blurRadius: 32,
 offset: const Offset(0, 16),
 spreadRadius: 2,
 ),
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.25),
 blurRadius: 48,
 offset: const Offset(0, 24),
 ),
 ],
 ),
 child: Stack(
 children: [
 Positioned(
 top: -20,
 right: -20,
 child: Container(
 width: 100,
 height: 100,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: RadialGradient(
 colors: [
 data.colors.first.withValues(alpha: 0.25),
 Colors.transparent,
 ],
 ),
 ),
 ),
 ),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 data.colors.first.withValues(alpha: 0.9),
 data.colors.last.withValues(alpha: 0.7),
 ],
 ),
 border: Border.all(
 color: Colors.white.withValues(alpha: 0.3), width: 2),
 boxShadow: [
 BoxShadow(
 color: data.colors.last.withValues(alpha: 0.4),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: data.assetPath != null
 ? ClipOval(
 child: Image.asset(
 data.assetPath!,
 width: 24,
 height: 24,
 fit: BoxFit.cover,
 ),
 )
 : Icon(data.icon, color: Colors.white, size: 24),
 ),
 const SizedBox(height: 18),
 Text(
 data.title,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w900,
 fontSize: 18,
 letterSpacing: 0.2,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 10),
 Text(
 data.description,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.85),
 height: 1.5,
 fontSize: 13,
 fontWeight: FontWeight.w500,
 ),
 maxLines: 3,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: data.highlights
 .map(
 (highlight) => Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 color: Colors.white.withValues(alpha: 0.18),
 border: Border.all(
 color: Colors.white.withValues(alpha: 0.3),
 width: 1),
 boxShadow: [
 BoxShadow(
 color: data.colors.first.withValues(alpha: 0.15),
 blurRadius: 8,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Text(
 highlight,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 )
 .toList(),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _HeroActionButton extends StatelessWidget {
 const _HeroActionButton({
 required this.label,
 required this.icon,
 required this.onTap,
 this.isSecondary = false,
 });

 final String label;
 final IconData icon;
 final VoidCallback onTap;
 final bool isSecondary;

 @override
 Widget build(BuildContext context) {
 final BorderRadius radius = BorderRadius.circular(18);
 final BoxDecoration decoration = isSecondary
 ? BoxDecoration(
 borderRadius: radius,
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.18),
 blurRadius: 18,
 offset: const Offset(0, 14),
 ),
 ],
 )
 : BoxDecoration(
 borderRadius: radius,
 gradient: LinearGradient(
 colors: [
 LightModeColors.accent.withValues(alpha: 0.95),
 LightModeColors.accent.withValues(alpha: 0.75),
 ],
 ),
 boxShadow: [
 BoxShadow(
 color: LightModeColors.accent.withValues(alpha: 0.35),
 blurRadius: 20,
 offset: const Offset(0, 18),
 ),
 ],
 );

 final Color textColor = isSecondary
 ? Colors.white.withValues(alpha: 0.88)
 : const Color(0xFF14213D);

 return Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: onTap,
 borderRadius: radius,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
 decoration: decoration,
 child: LayoutBuilder(
 builder: (context, constraints) {
 final bool shouldWrap = constraints.maxWidth < 300;

 if (shouldWrap) {
 return Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 20, color: textColor),
 const SizedBox(height: 8),
 Text(
 label,
 textAlign: TextAlign.center,
 style: TextStyle(
 color: textColor,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 ],
 );
 }

 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 20, color: textColor),
 const SizedBox(width: 12),
 Flexible(
 child: Text(
 label,
 style: TextStyle(
 color: textColor,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 overflow: TextOverflow.ellipsis,
 maxLines: 2,
 ),
 ),
 const SizedBox(width: 10),
 Icon(Icons.arrow_outward_rounded,
 size: 18, color: textColor.withValues(alpha: 0.9)),
 ],
 );
 },
 ),
 ),
 ),
 );
 }
}

class _HeroMetricChip extends StatelessWidget {
 const _HeroMetricChip({required this.label, required this.icon});

 final String label;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 color: Colors.white.withValues(alpha: 0.08),
 border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon,
 color: LightModeColors.accent.withValues(alpha: 0.9), size: 18),
 const SizedBox(width: 10),
 Text(
 label,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.86),
 fontWeight: FontWeight.w600,
 fontSize: 13,
 ),
 ),
 ],
 ),
 );
 }
}


// ── Data classes + card widgets for the new landing sections ──────────────

class _TrainingCourse {
 final String title;
 final String audience;
 final String duration;
 final String description;
 final List<String> topics;
 final String price;
 final String bookingUrl;
 const _TrainingCourse({
 required this.title,
 required this.audience,
 required this.duration,
 required this.description,
 required this.topics,
 required this.price,
 required this.bookingUrl,
 });
}

class _TrainingCard extends StatelessWidget {
 const _TrainingCard({
 required this.course,
 required this.isDesktop,
 required this.onBook,
 });
 final _TrainingCourse course;
 final bool isDesktop;
 final VoidCallback onBook;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: isDesktop ? 360 : double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFFFD700).withOpacity(0.12),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(course.audience,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFB45309))),
 ),
 const Spacer(),
 Icon(Icons.school_outlined, color: Colors.grey.shade400, size: 20),
 ],
 ),
 const SizedBox(height: 14),
 Text(course.title,
 style: const TextStyle(
 fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
 const SizedBox(height: 6),
 Text(course.duration,
 style: const TextStyle(
 color: Color(0xFF64748B), fontSize: 12.5)),
 const SizedBox(height: 12),
 Text(course.description,
 style: const TextStyle(
 color: Color(0xFF475569), fontSize: 13, height: 1.5)),
 const SizedBox(height: 16),
 ...course.topics.map((t) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 children: [
 const Icon(Icons.check_circle,
 size: 14, color: Color(0xFF10B981)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(t,
 style: const TextStyle(
 fontSize: 12.5, color: Color(0xFF334155)))),
 ],
 ),
 )),
 const SizedBox(height: 18),
 Row(
 children: [
 Text(course.price,
 style: const TextStyle(
 fontSize: 15, fontWeight: FontWeight.w800)),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: onBook,
 icon: const Icon(Icons.calendar_today_outlined, size: 15),
 label: const Text('Book',
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF0F172A),
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ConsultPackage {
 final String name;
 final String price;
 final String duration;
 final String description;
 final List<String> deliverables;
 final Color accent;
 final String bookingUrl;
 const _ConsultPackage({
 required this.name,
 required this.price,
 required this.duration,
 required this.description,
 required this.deliverables,
 required this.accent,
 required this.bookingUrl,
 });
}

class _ConsultCard extends StatelessWidget {
 const _ConsultCard({
 required this.pkg,
 required this.isDesktop,
 required this.onBook,
 });
 final _ConsultPackage pkg;
 final bool isDesktop;
 final VoidCallback onBook;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: isDesktop ? 360 : double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: pkg.accent.withOpacity(0.3), width: 1.5),
 boxShadow: [
 BoxShadow(
 color: pkg.accent.withOpacity(0.08),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: pkg.accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(pkg.duration,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: pkg.accent)),
 ),
 const SizedBox(height: 14),
 Text(pkg.name,
 style: const TextStyle(
 fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
 const SizedBox(height: 8),
 Text(pkg.description,
 style: const TextStyle(
 color: Color(0xFF475569), fontSize: 13, height: 1.5)),
 const SizedBox(height: 16),
 const Text('Deliverables',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF64748B),
 letterSpacing: 0.6)),
 const SizedBox(height: 8),
 ...pkg.deliverables.map((d) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 3),
 child: Row(
 children: [
 Icon(Icons.arrow_right, size: 16, color: pkg.accent),
 const SizedBox(width: 4),
 Expanded(
 child: Text(d,
 style: const TextStyle(
 fontSize: 12.5, color: Color(0xFF334155)))),
 ],
 ),
 )),
 const SizedBox(height: 18),
 Row(
 children: [
 Text(pkg.price,
 style: const TextStyle(
 fontSize: 15, fontWeight: FontWeight.w800)),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: onBook,
 icon: const Icon(Icons.phone_in_talk_outlined, size: 15),
 label: const Text('Book call',
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
 style: ElevatedButton.styleFrom(
 backgroundColor: pkg.accent,
 foregroundColor: Colors.white,
 elevation: 0,
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _BlogPost {
 final String category;
 final String title;
 final String excerpt;
 final String date;
 final String readTime;
 final String url;
 const _BlogPost({
 required this.category,
 required this.title,
 required this.excerpt,
 required this.date,
 required this.readTime,
 required this.url,
 });
}

class _BlogCard extends StatelessWidget {
 const _BlogCard({
 required this.post,
 required this.isDesktop,
 required this.onTap,
 });
 final _BlogPost post;
 final bool isDesktop;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(14),
 child: Container(
 width: isDesktop ? 360 : double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFF1E293B),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFF334155)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFFFD700).withOpacity(0.15),
 borderRadius: BorderRadius.circular(5),
 ),
 child: Text(post.category,
 style: const TextStyle(
 fontSize: 10.5,
 fontWeight: FontWeight.w700,
 color: Color(0xFFFFD700))),
 ),
 const Spacer(),
 Icon(Icons.arrow_outward,
 size: 16, color: Colors.white.withOpacity(0.4)),
 ],
 ),
 const SizedBox(height: 14),
 Text(post.title,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 height: 1.3)),
 const SizedBox(height: 10),
 Text(post.excerpt,
 style: TextStyle(
 color: Colors.white.withOpacity(0.6),
 fontSize: 13,
 height: 1.5)),
 const SizedBox(height: 16),
 Row(
 children: [
 Text(post.date,
 style: TextStyle(
 color: Colors.white.withOpacity(0.4), fontSize: 12)),
 const Text(' · ',
 style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
 Text(post.readTime,
 style: TextStyle(
 color: Colors.white.withOpacity(0.4), fontSize: 12)),
 ],
 ),
 ],
 ),
 ),
 );
 }
}

class _MediaFeature {
 final String outlet;
 final String headline;
 final String date;
 final String url;
 const _MediaFeature({
 required this.outlet,
 required this.headline,
 required this.date,
 required this.url,
 });
}

class _AccomplishmentStat {
 final String value;
 final String label;
 const _AccomplishmentStat({required this.value, required this.label});
}

class _MediaFeatureRow extends StatelessWidget {
 const _MediaFeatureRow({required this.feature, required this.onTap});
 final _MediaFeature feature;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 margin: const EdgeInsets.only(bottom: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 children: [
 Container(
 width: 80,
 padding: const EdgeInsets.symmetric(vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFF0F172A),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(feature.outlet,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 11,
 fontWeight: FontWeight.w700)),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(feature.headline,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0F172A))),
 const SizedBox(height: 2),
 Text(feature.date,
 style: const TextStyle(
 fontSize: 11.5, color: Color(0xFF94A3B8))),
 ],
 ),
 ),
 const Icon(Icons.arrow_outward,
 size: 18, color: Color(0xFF94A3B8)),
 ],
 ),
 ),
 );
 }
}

class _Review {
 final String quote;
 final String author;
 final String role;
 final int rating;
 final Color avatarColor;
 const _Review({
 required this.quote,
 required this.author,
 required this.role,
 required this.rating,
 required this.avatarColor,
 });
}

class _ReviewCard extends StatelessWidget {
 const _ReviewCard({required this.review, required this.isDesktop});
 final _Review review;
 final bool isDesktop;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: isDesktop ? 380 : double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.03),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: List.generate(
 5,
 (i) => Icon(
 i < review.rating ? Icons.star : Icons.star_border,
 size: 16,
 color: const Color(0xFFFFD700),
 ),
 ),
 ),
 const SizedBox(height: 12),
 Text('"${review.quote}"',
 style: const TextStyle(
 fontSize: 14, height: 1.6, color: Color(0xFF334155))),
 const SizedBox(height: 16),
 Row(
 children: [
 CircleAvatar(
 radius: 18,
 backgroundColor: review.avatarColor,
 child: Text(review.author.substring(0, 1),
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w700)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(review.author,
 style: const TextStyle(
 fontSize: 13.5, fontWeight: FontWeight.w700)),
 Text(review.role,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

// ── Social media links row (used in footer) ───────────────────────────────
class _SocialLinksRow extends StatelessWidget {
 const _SocialLinksRow();
 static const _links = [
 _SocialLink(
 icon: Icons.alternate_email,
 label: 'X / Twitter',
 url: 'https://twitter.com/nduproject'),
 _SocialLink(
 icon: Icons.business_center_outlined,
 label: 'LinkedIn',
 url: 'https://www.linkedin.com/company/ndu-project'),
 _SocialLink(
 icon: Icons.facebook_outlined,
 label: 'Facebook',
 url: 'https://www.facebook.com/nduproject'),
 _SocialLink(
 icon: Icons.camera_alt_outlined,
 label: 'Instagram',
 url: 'https://www.instagram.com/nduproject'),
 _SocialLink(
 icon: Icons.smart_display_outlined,
 label: 'YouTube',
 url: 'https://www.youtube.com/@nduproject'),
 ];

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: _links
 .map((l) => _SocialIconBubble(link: l))
 .toList(),
 );
 }
}

class _SocialLink {
 final IconData icon;
 final String label;
 final String url;
 const _SocialLink({
 required this.icon,
 required this.label,
 required this.url,
 });
}

class _SocialIconBubble extends StatelessWidget {
 const _SocialIconBubble({required this.link});
 final _SocialLink link;

 @override
 Widget build(BuildContext context) {
 return Tooltip(
 message: link.label,
 child: InkWell(
 onTap: () async {
 final uri = Uri.parse(link.url);
 await launchUrl(uri, mode: LaunchMode.externalApplication);
 },
 borderRadius: BorderRadius.circular(10),
 child: Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.06),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
 ),
 child: Icon(link.icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
 ),
 ),
 );
 }
}

/// Data model for a premium dropdown item.
class _DropdownItem {
 final IconData icon;
 final String label;
 final VoidCallback onTap;
 const _DropdownItem({required this.icon, required this.label, required this.onTap});
}

/// Premium dropdown trigger button with hover animation.
class _PremiumDropdownTrigger extends StatefulWidget {
 final String label;
 const _PremiumDropdownTrigger({super.key, required this.label});

 @override
 State<_PremiumDropdownTrigger> createState() => _PremiumDropdownTriggerState();
}

class _PremiumDropdownTriggerState extends State<_PremiumDropdownTrigger> {
 bool _isHovered = false;

 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 onEnter: (_) => setState(() => _isHovered = true),
 onExit: (_) => setState(() => _isHovered = false),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 curve: Curves.easeOutCubic,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: _isHovered
 ? Colors.white.withValues(alpha: 0.12)
 : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: _isHovered
 ? Colors.white.withValues(alpha: 0.2)
 : Colors.transparent,
 width: 1,
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 widget.label,
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.92),
 letterSpacing: 0.2,
 ),
 ),
 const SizedBox(width: 6),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _isHovered ? 0.5 : 0,
 child: Icon(
 Icons.keyboard_arrow_down,
 color: Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.7),
 size: 18,
 ),
 ),
 ],
 ),
 ),
 );
 }
}

/// Premium dropdown item with icon, hover state, and elegant styling.
class _PremiumDropdownItem extends StatefulWidget {
 final _DropdownItem item;
 final bool isLast;
 const _PremiumDropdownItem({super.key, required this.item, this.isLast = false});

 @override
 State<_PremiumDropdownItem> createState() => _PremiumDropdownItemState();
}

class _PremiumDropdownItemState extends State<_PremiumDropdownItem> {
 bool _isHovered = false;

 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 onEnter: (_) => setState(() => _isHovered = true),
 onExit: (_) => setState(() => _isHovered = false),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 150),
 curve: Curves.easeOut,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: _isHovered
 ? const Color(0xFF2563EB).withValues(alpha: 0.15)
 : Colors.transparent,
 border: !widget.isLast
 ? Border(
 bottom: BorderSide(
 color: Colors.white.withValues(alpha: 0.06),
 width: 0.5,
 ),
 )
 : null,
 ),
 child: Row(
 children: [
 // Icon with background circle
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: _isHovered
 ? const Color(0xFF2563EB).withValues(alpha: 0.2)
 : Colors.white.withValues(alpha: 0.06),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(
 widget.item.icon,
 size: 16,
 color: _isHovered
 ? const Color(0xFF60A5FA)
 : Colors.white.withValues(alpha: 0.7),
 ),
 ),
 const SizedBox(width: 12),
 // Label
 Expanded(
 child: Text(
 widget.item.label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
 color: _isHovered
 ? Colors.white
 : Colors.white.withValues(alpha: 0.85),
 letterSpacing: 0.1,
 ),
 ),
 ),
 // Arrow on hover
 AnimatedOpacity(
 duration: const Duration(milliseconds: 150),
 opacity: _isHovered ? 1.0 : 0.0,
 child: Icon(
 Icons.arrow_forward_ios,
 size: 12,
 color: const Color(0xFF60A5FA).withValues(alpha: _isHovered ? 1.0 : 0.0),
 ),
 ),
 ],
 ),
 ),
 );
 }
}
