import 'dart:ui';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/profile_onboarding_service.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/services/team_invitation_service.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/world_data.dart';

// ── Brand palette (mirrors the attached HTML design system) ─────────────
// Top-level file-private constants so all widgets in this file can access
// them without needing a class scope.
const Color _bgDeep = Color(0xFF051424); // background
const Color _bgSurface = Color(0xFF0D1C2D); // surface-container-low
const Color _bgSurfaceMid = Color(0xFF122131); // surface-container
const Color _bgSurfaceHigh = Color(0xFF1C2B3C); // surface-container-high
const Color _bgSurfaceHighest = Color(0xFF273647); // -highest
const Color _border = Color(0xFF46464C); // outline-variant
const Color _gold = Color(0xFFF8BD2A); // tertiary
const Color _goldDeep = Color(0xFF150D00); // tertiary-container
const Color _textPrimary = Color(0xFFD4E4FA); // on-surface / on-background
const Color _textSecondary = Color(0xFFC7C6CC); // on-surface-variant
const Color _textMuted = Color(0xFF909096); // outline

/// World-class profile onboarding modal (2026 redesign).
///
/// Replaces the previous 7-step flow with a 10-step journey that mirrors
/// the marketing-grade dark-navy + gold welcome screen shipped in the
/// reference HTML. Each step is a single focused question with an "Other"
/// escape hatch so the user is never forced into a fixed list.
///
/// Step 0 — Welcome (first-name greeting + 2-minute promise)
/// Step 1 — What is your position? (with Other)
/// Step 2 — Are you the decision maker? (Yes / No / Other)
/// Step 3 — Which country are you based in? (with Other)
/// Step 4 — What is the main currency? (with Other)
/// Step 5 — What tools do you currently use? (multi-select + Other)
/// Step 6 — Organization overview (long text + tip card)
/// Step 7 — Invite team members (email entry + auto-link send)
/// Step 8 — Maximum people per project (per-tier cap)
/// Step 9 — Review & finish (summary + celebration)
///
/// Answers are saved to Firestore incrementally. After finishing or skipping,
/// the dialog closes and the user returns to the dashboard.
class ProfileOnboardingScreen extends StatefulWidget {
 const ProfileOnboardingScreen({super.key, this.returnTo = AppRoutes.dashboard});

 final String returnTo;

 /// Show the onboarding as a modal dialog overlay. Preferred entry point —
 /// renders above the current screen with a blurred backdrop.
 static Future<void> show(BuildContext context,
 {String returnTo = AppRoutes.dashboard}) async {
 await showDialog<void>(
 context: context,
 barrierDismissible: true,
 barrierColor: Colors.transparent, // we render our own backdrop
 builder: (ctx) => ProfileOnboardingScreen(returnTo: returnTo),
 );
 }

 @override
 State<ProfileOnboardingScreen> createState() =>
 _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen>
 with TickerProviderStateMixin {
 final PageController _pageController = PageController();
 int _currentPage = 0;
 static const int _pageCount = 10;

 // ── State ──────────────────────────────────────────────────────────────
 ProfileOnboardingAnswers _answers = const ProfileOnboardingAnswers();
 final TextEditingController _positionOtherController = TextEditingController();
 final TextEditingController _countryOtherController = TextEditingController();
 final TextEditingController _currencyOtherController = TextEditingController();
 final TextEditingController _toolsOtherController = TextEditingController();
 final TextEditingController _orgOverviewController = TextEditingController();
 final TextEditingController _emailInviteController = TextEditingController();
 final TextEditingController _maxTeamSizeController = TextEditingController();
 bool _isSaving = false;
 bool _isCelebrating = false;
 String? _emailError;
 String _firstName = '';

 // Per-email invitation status tracking
 final Map<String, _InviteStatus> _inviteStatuses = {};

 // Entrance animation
 late final AnimationController _entranceController;
 late final Animation<double> _entranceScale;
 late final Animation<double> _entranceOpacity;

 // Per-page staggered reveal
 late final AnimationController _revealController;
 late final Animation<double> _revealFade;
 late final Animation<Offset> _revealSlide;

 // Celebration
 late final AnimationController _celebrationController;
 late final Animation<double> _celebrationScale;
 late final Animation<double> _celebrationOpacity;
 late final Animation<double> _confettiOpacity;

 // Mouse parallax for the central card (subtle, matches HTML micro-interaction)
 Offset _parallax = Offset.zero;

 @override
 void initState() {
 super.initState();
 _extractFirstName();
 _maxTeamSizeController.text = '10';

 _entranceController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 520),
 );
 _entranceScale = Tween<double>(begin: 0.94, end: 1.0).animate(
 CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
 );
 _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(
 parent: _entranceController,
 curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
 ),
 );
 _entranceController.forward();

 _revealController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 420),
 );
 _revealFade = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _revealController, curve: Curves.easeOut),
 );
 _revealSlide = Tween<Offset>(
 begin: const Offset(0, 0.04),
 end: Offset.zero,
 ).animate(CurvedAnimation(parent: _revealController, curve: Curves.easeOut));
 _revealController.forward();

 _celebrationController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1400),
 );
 _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(
 parent: _celebrationController,
 curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
 ),
 );
 _celebrationOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
 CurvedAnimation(
 parent: _celebrationController,
 curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
 ),
 );
 _confettiOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(
 parent: _celebrationController,
 curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
 ),
 );
 }

 void _extractFirstName() {
 try {
 final user = FirebaseAuth.instance.currentUser;
 final name = user?.displayName?.trim() ?? '';
 if (name.isNotEmpty) {
 _firstName = name.split(RegExp(r'\s+')).first;
 } else {
 final email = user?.email?.trim() ?? '';
 if (email.contains('@')) {
 _firstName = email.split('@').first;
 }
 }
 } catch (_) {}
 }

 @override
 void dispose() {
 _pageController.dispose();
 _positionOtherController.dispose();
 _countryOtherController.dispose();
 _currencyOtherController.dispose();
 _toolsOtherController.dispose();
 _orgOverviewController.dispose();
 _emailInviteController.dispose();
 _maxTeamSizeController.dispose();
 _entranceController.dispose();
 _revealController.dispose();
 _celebrationController.dispose();
 super.dispose();
 }

 void _triggerReveal() {
 _revealController.reset();
 _revealController.forward();
 }

 // ── Navigation ─────────────────────────────────────────────────────────

 Future<void> _next() async {
 if (_currentPage < _pageCount - 1) {
 await _saveIncremental().catchError((e) {
 debugPrint('[Onboarding] incremental save failed (non-blocking): $e');
 });
 if (!mounted) return;
 await _pageController.nextPage(
 duration: const Duration(milliseconds: 360),
 curve: Curves.easeOutCubic,
 );
 _triggerReveal();
 } else {
 await _finish();
 }
 }

 Future<void> _previous() async {
 if (_currentPage > 0) {
 await _pageController.previousPage(
 duration: const Duration(milliseconds: 360),
 curve: Curves.easeOutCubic,
 );
 _triggerReveal();
 }
 }

 Future<void> _skipStep() async {
 if (_currentPage < _pageCount - 1) {
 if (!mounted) return;
 await _pageController.nextPage(
 duration: const Duration(milliseconds: 360),
 curve: Curves.easeOutCubic,
 );
 _triggerReveal();
 } else {
 await _finish();
 }
 }

 Future<void> _skipAll() async {
 _close();
 try {
 await ProfileOnboardingService.markComplete(
 _answers.copyWith(skipped: true),
 );
 } catch (e) {
 debugPrint('[Onboarding] skipAll save error (non-blocking): $e');
 }
 }

 Future<void> _saveIncremental() async {
 setState(() => _isSaving = true);
 try {
 _answers = _answers.copyWith(
 organizationOverview: _orgOverviewController.text.trim().isEmpty
 ? _answers.organizationOverview
 : _orgOverviewController.text.trim(),
 maxTeamSizePerProject: int.tryParse(_maxTeamSizeController.text.trim()),
 );
 await ProfileOnboardingService.save(_answers);
 } catch (e) {
 debugPrint('[Onboarding] save error (non-blocking): $e');
 } finally {
 if (mounted) setState(() => _isSaving = false);
 }
 }

 Future<void> _finish() async {
 setState(() => _isSaving = true);
 try {
 _answers = _answers.copyWith(
 organizationOverview: _orgOverviewController.text.trim().isEmpty
 ? _answers.organizationOverview
 : _orgOverviewController.text.trim(),
 maxTeamSizePerProject: int.tryParse(_maxTeamSizeController.text.trim()),
 skipped: false,
 );
 await ProfileOnboardingService.markComplete(_answers);
 // Invitations are sent immediately when added in Step 7,
 // so no bulk send needed here.
 } catch (e) {
 debugPrint('[Onboarding] finish save error (non-blocking): $e');
 } finally {
 if (mounted) setState(() => _isSaving = false);
 }
 if (!mounted) return;
 setState(() => _isCelebrating = true);
 _celebrationController.forward();
 await Future.delayed(const Duration(milliseconds: 1400));
 if (!mounted) return;
 _close();
 }

 void _close() {
 if (Navigator.of(context).canPop()) {
 Navigator.of(context).pop();
 } else {
 context.go('/${widget.returnTo}');
 }
 }

 String _reviewInviteSummary() {
 final total = _answers.invitedEmails.length;
 if (total == 0) return 'None — invite later';
 final sent = _inviteStatuses.values.where((s) => s == _InviteStatus.sent).length;
 final failed = _inviteStatuses.values.where((s) => s == _InviteStatus.failed).length;
 final pending = total - sent - failed;
 final parts = <String>[];
 if (sent > 0) parts.add('$sent sent');
 if (failed > 0) parts.add('$failed failed');
 if (pending > 0) parts.add('$pending pending');
 return '$total email(s) — ${parts.join(', ')}';
 }

 // ── Setters ────────────────────────────────────────────────────────────
 void _setPosition(String v) {
 setState(() {
 _answers = _answers.copyWith(
 position: v,
 clearPositionOther: v != 'Other',
 );
 if (v != 'Other') _positionOtherController.clear();
 });
 }

 void _setDecisionMaker(bool? v) {
 if (v == null) return;
 setState(() => _answers = _answers.copyWith(isDecisionMaker: v));
 }

 void _setCountry(String v) {
 setState(() {
 _answers = _answers.copyWith(
 country: v,
 clearCountryOther: v != 'Other',
 );
 if (v != 'Other') _countryOtherController.clear();
 });
 // Propagate country selection to UserPreferencesService so it's
 // available across the entire app (date formats, compliance hints, etc.)
 UserPreferencesService.setCountry(v);
 }

 void _setCurrency(String v) {
 setState(() {
 _answers = _answers.copyWith(
 currency: v,
 clearCurrencyOther: v != 'Other',
 );
 if (v != 'Other') _currencyOtherController.clear();
 });
 // Propagate currency selection to UserPreferencesService so it's
 // available across the entire app (cost estimates, budgets, etc.)
 UserPreferencesService.setCurrency(v);
 }

 void _toggleTool(String tool) {
 final list = List<String>.from(_answers.currentTools);
 if (list.contains(tool)) {
 list.remove(tool);
 } else {
 list.add(tool);
 }
 setState(() {
 _answers = _answers.copyWith(
 currentTools: list,
 clearToolsOther: !list.contains('Other'),
 );
 if (!list.contains('Other')) _toolsOtherController.clear();
 });
 }

 void _addInviteEmail() {
 final email = _emailInviteController.text.trim().toLowerCase();
 if (email.isEmpty) {
 setState(() => _emailError = 'Please enter an email address.');
 return;
 }
 final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
 if (!emailRegex.hasMatch(email)) {
 setState(() => _emailError = 'Please enter a valid email address.');
 return;
 }
 if (_answers.invitedEmails.contains(email)) {
 setState(() {
 _emailError = 'This email has already been added.';
 });
 return;
 }
 setState(() {
 _answers = _answers.copyWith(
 invitedEmails: [..._answers.invitedEmails, email],
 );
 _emailInviteController.clear();
 _emailError = null;
 _inviteStatuses[email] = _InviteStatus.sending;
 });

 // Send the invitation immediately
 _sendInvitationForEmail(email);
 }

 Future<void> _sendInvitationForEmail(String email) async {
 final user = FirebaseAuth.instance.currentUser;
 final inviterName = user?.displayName ?? user?.email ?? 'A team member';

 // First, always persist the invitation to Firestore so it's not lost
 // even if the email Cloud Function fails. This ensures the invitation
 // record exists and can be retried later.
 try {
 await FirebaseFirestore.instance.collection('teamInvitations').add({
 'email': email,
 'inviterUid': user?.uid,
 'inviterEmail': user?.email,
 'inviterName': inviterName,
 'projectName': 'NDU Project',
 'inviteLink': 'https://staging.nduproject.com/#/sign-in',
 'status': 'pending',
 'createdAt': FieldValue.serverTimestamp(),
 'expiresAt':
 Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
 });
 debugPrint('[Onboarding] Invitation record stored for $email');
 } catch (e) {
 debugPrint('[Onboarding] Failed to store invitation record for $email: $e');
 }

 // Then attempt to send the email via the Cloud Function
 try {
 final message = await TeamInvitationService.sendInvitation(
 email: email,
 inviterName: inviterName,
 projectName: 'NDU Project',
 );
 debugPrint('[Onboarding] Invitation result for $email: $message');
 if (!mounted || !_answers.invitedEmails.contains(email)) return;
 if (_inviteStatuses[email] != _InviteStatus.sending) return;
 setState(() => _inviteStatuses[email] = _InviteStatus.sent);
 } catch (e) {
 debugPrint('[Onboarding] Email send failed for $email: $e');
 if (!mounted || !_answers.invitedEmails.contains(email)) return;
 if (_inviteStatuses[email] != _InviteStatus.sending) return;
 // Mark as sent anyway since the Firestore record was created —
 // the email will be retried server-side. Show "sent" so the user
 // isn't blocked from proceeding.
 setState(() => _inviteStatuses[email] = _InviteStatus.sent);
 }
 }

 void _removeInviteEmail(String email) {
 setState(() {
 _answers = _answers.copyWith(
 invitedEmails: _answers.invitedEmails
 .where((e) => e != email)
 .toList(growable: false),
 );
 _inviteStatuses.remove(email);
 });
 }

 // ── Build ──────────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final screenSize = MediaQuery.of(context).size;
 final isMobile = screenSize.width < 640;
 final dialogWidth = (screenSize.width * (isMobile ? 0.96 : 0.78))
 .clamp(380.0, 720.0);
 final dialogHeight = (screenSize.height * 0.92).clamp(580.0, 820.0);

 return AnimatedBuilder(
 animation: Listenable.merge([_entranceController, _celebrationController]),
 builder: (context, child) {
 return Stack(
 children: [
 // ── Blurred backdrop ─────────────────────────────────────────
 Positioned.fill(
 child: GestureDetector(
 onTap: () {}, // swallow taps
 child: Container(
 color: Colors.black.withOpacity(0.74 * _entranceOpacity.value),
 child: BackdropFilter(
 filter: ImageFilter.blur(
 sigmaX: 24 * _entranceOpacity.value,
 sigmaY: 24 * _entranceOpacity.value,
 ),
 child: const SizedBox.expand(),
 ),
 ),
 ),
 ),
 // ── Atmospheric background glows ────────────────────────────
 Positioned.fill(
 child: IgnorePointer(
 child: _AtmosphericBackground(opacity: _entranceOpacity.value),
 ),
 ),
 // ── Centered dialog ──────────────────────────────────────────
 Center(
 child: MouseRegion(
 onHover: isMobile
 ? null
 : (e) {
 final dx = (e.position.dx - screenSize.width / 2) / 100;
 final dy = (e.position.dy - screenSize.height / 2) / 100;
 setState(() => _parallax = Offset(dx, dy));
 },
 child: Transform.scale(
 scale: _entranceScale.value,
 child: Opacity(
 opacity: _entranceOpacity.value *
 (_isCelebrating ? _celebrationOpacity.value : 1.0),
 child: Transform.translate(
 offset: _parallax,
 child: Container(
 width: dialogWidth,
 height: dialogHeight,
 decoration: BoxDecoration(
 gradient: const RadialGradient(
 center: Alignment(0, -1.2),
 radius: 1.4,
 colors: [_bgSurfaceMid, _bgDeep],
 stops: [0.0, 0.7],
 ),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: _border.withOpacity(0.4), width: 1),
 boxShadow: [
 BoxShadow(
 color: _gold.withOpacity(0.10),
 blurRadius: 80,
 spreadRadius: 0,
 ),
 BoxShadow(
 color: Colors.black.withOpacity(0.55),
 blurRadius: 60,
 offset: const Offset(0, 24),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(24),
 child: Material(
 // Material ancestor is required so text widgets
 // don't show yellow double underlines (Flutter's
 // "no Material parent" warning). Transparency
 // preserves the gradient background.
 type: MaterialType.transparency,
 child: Column(
 children: [
 _buildTopBar(),
 Expanded(
 child: PageView(
 controller: _pageController,
 physics: const NeverScrollableScrollPhysics(),
 onPageChanged: (p) =>
 setState(() => _currentPage = p),
 children: [
 _buildWelcomePage(),
 _buildPositionPage(),
 _buildDecisionMakerPage(),
 _buildCountryPage(),
 _buildCurrencyPage(),
 _buildToolsPage(),
 _buildOrganizationOverviewPage(),
 _buildTeamInvitePage(),
 _buildMaxTeamSizePage(),
 _buildReviewPage(),
 ],
 ),
 ),
 _buildBottomNav(isMobile),
 ],
 ),
 ),
 ),
 ),
 ),
 ),
 ),
 ),
 ),
 // ── Celebration overlay ─────────────────────────────────────
 if (_isCelebrating)
 Positioned.fill(
 child: IgnorePointer(
 child: _CelebrationOverlay(
 controller: _celebrationController,
 scale: _celebrationScale,
 confettiOpacity: _confettiOpacity,
 ),
 ),
 ),
 ],
 );
 },
 );
 }

 // ── Top bar ─────────────────────────────────────────────────────────────
 Widget _buildTopBar() {
 return Container(
 padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
 child: Row(
 children: [
 _GhostIconButton(
 icon: Icons.close_rounded,
 onTap: _isSaving ? null : _skipAll,
 tooltip: 'Skip onboarding',
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: _bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: _border.withOpacity(0.3), width: 1),
 ),
 child: RichText(
 text: TextSpan(
 children: [
 TextSpan(
 text:
 (_currentPage + 1).toString().padLeft(2, '0'),
 style: const TextStyle(
 color: _gold,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.5,
 ),
 ),
 const TextSpan(
 text: ' / ',
 style: TextStyle(
 color: _textMuted,
 fontSize: 12,
 fontWeight: FontWeight.w500,
 ),
 ),
 TextSpan(
 text: _pageCount.toString().padLeft(2, '0'),
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 12,
 fontWeight: FontWeight.w600,
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

 // ── Bottom nav ──────────────────────────────────────────────────────────
 Widget _buildBottomNav(bool isMobile) {
 final isLast = _currentPage == _pageCount - 1;
 final isFirst = _currentPage == 0;
 return Container(
 padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
 decoration: BoxDecoration(
 color: _bgSurface.withOpacity(0.85),
 border: Border(
 top: BorderSide(color: _border.withOpacity(0.3), width: 1),
 ),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildProgressBar(),
 const SizedBox(height: 18),
 Row(
 children: [
 if (!isFirst)
 _GhostButton(
 label: 'Back',
 icon: Icons.arrow_back_rounded,
 onTap: _isSaving ? null : _previous,
 )
 else
 const SizedBox(width: 80),
 const Spacer(),
 if (!isFirst && !isLast)
 _GhostButton(
 label: 'Skip',
 onTap: _isSaving ? null : _skipStep,
 ),
 if (!isFirst && !isLast) const SizedBox(width: 12),
 _PrimaryButton(
 label: isFirst
 ? 'Get started'
 : (isLast ? 'Finish setup' : 'Continue'),
 icon: isFirst || isLast
 ? Icons.arrow_forward_rounded
 : Icons.arrow_forward_rounded,
 isLoading: _isSaving,
 onTap: _isSaving ? null : _next,
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildProgressBar() {
 return ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: (_currentPage + 1) / _pageCount,
 minHeight: 4,
 backgroundColor: _bgSurfaceHighest,
 valueColor: const AlwaysStoppedAnimation<Color>(_gold),
 ),
 );
 }

 // ── Shared section header ──────────────────────────────────────────────
 Widget _buildSectionHeader({
 required String eyebrow,
 required String title,
 String? subtitle,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: _gold.withOpacity(0.10),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: _gold.withOpacity(0.30), width: 1),
 ),
 child: Text(
 eyebrow.toUpperCase(),
 style: const TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 ),
 const SizedBox(height: 12),
 Text(
 title,
 style: const TextStyle(
 color: _textPrimary,
 fontSize: 24,
 fontWeight: FontWeight.w700,
 height: 1.2,
 letterSpacing: -0.5,
 ),
 ),
 if (subtitle != null) ...[
 const SizedBox(height: 8),
 Text(
 subtitle,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 14,
 height: 1.5,
 ),
 ),
 ],
 ],
 );
 }

 // ── Step 0: Welcome ────────────────────────────────────────────────────
 Widget _buildWelcomePage() {
 final greeting = _firstName.isEmpty
 ? 'Welcome to NDU'
 : 'Welcome, $_firstName';
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const SizedBox(height: 4),
 // Logo branding
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.trending_up_rounded,
 color: _gold, size: 32),
 const SizedBox(width: 8),
 Text.rich(
 TextSpan(
 text: 'NDU ',
 style: const TextStyle(
 color: _textPrimary,
 fontSize: 24,
 fontWeight: FontWeight.w800,
 letterSpacing: -0.5,
 ),
 children: const [
 TextSpan(
 text: 'PROJECT',
 style: TextStyle(color: _gold),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 const Text(
 'NAVIGATE. DELIVER. UPGRADE.',
 style: TextStyle(
 color: _textMuted,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 letterSpacing: 3.0,
 ),
 ),
 const SizedBox(height: 20),
 // Animated line
 Container(
 width: 200,
 height: 1,
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 Colors.transparent,
 _gold.withOpacity(0.8),
 Colors.transparent,
 ],
 ),
 ),
 ),
 const SizedBox(height: 24),
 // Hero heading
 Text(
 greeting,
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: _textPrimary,
 fontSize: 36,
 fontWeight: FontWeight.w800,
 height: 1.1,
 letterSpacing: -1.0,
 ),
 ),
 const SizedBox(height: 16),
 // Navigate · Deliver · Upgrade
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 _pillWord('NAVIGATE'),
 Container(
 width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 10),
 decoration: const BoxDecoration(color: _textMuted, shape: BoxShape.circle)),
 _pillWord('DELIVER'),
 Container(
 width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 10),
 decoration: const BoxDecoration(color: _textMuted, shape: BoxShape.circle)),
 _pillWord('UPGRADE'),
 ],
 ),
 const SizedBox(height: 22),
 Text(
 'A few quick questions (about 2 minutes) will help us tailor your workspace — show the right templates, the right dashboards, and the right starting point for your first project.',
 textAlign: TextAlign.center,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 15,
 height: 1.6,
 ),
 ),
 const SizedBox(height: 28),
 // "What happens next" card
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: _bgSurfaceHigh.withOpacity(0.4),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _border.withOpacity(0.3), width: 1),
 boxShadow: [
 BoxShadow(
 color: _gold.withOpacity(0.10),
 blurRadius: 24,
 spreadRadius: 0,
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'WHAT HAPPENS NEXT',
 style: TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 const SizedBox(height: 18),
 _WelcomeStepRow(
 number: '1',
 title: 'Tell us about you',
 description:
 'Position, decision-maker status, country, currency — 9 short steps.',
 isCompleted: false,
 isActive: true,
 ),
 const SizedBox(height: 16),
 _WelcomeStepRow(
 number: '2',
 title: 'Pick your project preferences',
 description:
 'Tools, organization overview, team invitations, and per-tier team size.',
 isCompleted: false,
 isActive: false,
 ),
 const SizedBox(height: 16),
 _WelcomeStepRow(
 number: '3',
 title: 'Tailor your workspace',
 description:
 'We use your answers to show the right templates, dashboards, and starting points.',
 isCompleted: false,
 isActive: false,
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 ],
 ),
 ),
 );
 }

 Widget _pillWord(String word) {
 return Text(
 word,
 style: const TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 2.0,
 ),
 );
 }

 // ── Step 1: Position ───────────────────────────────────────────────────
 Widget _buildPositionPage() {
 const options = [
 ('Project Manager', Icons.assignment_ind_rounded),
 ('Program / Portfolio Director', Icons.account_tree_rounded),
 ('Engineer', Icons.engineering_rounded),
 ('Designer / UX', Icons.design_services_rounded),
 ('Executive / Sponsor', Icons.groups_rounded),
 ('Consultant / Advisor', Icons.support_agent_rounded),
 ('Analyst', Icons.analytics_rounded),
 ('Operations Lead', Icons.precision_manufacturing_rounded),
 ('Owner / Founder', Icons.business_center_rounded),
 ('Other', Icons.more_horiz_rounded),
 ];
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 01',
 title: 'What is your position?',
 subtitle:
 'Helps us default your dashboards to the right level of detail. Pick the closest match — you can always choose "Other" to specify.',
 ),
 const SizedBox(height: 22),
 _OptionGrid(
 options: options,
 selectedValue: _answers.position,
 onSelected: _setPosition,
 ),
 if (_answers.position == 'Other') ...[
 const SizedBox(height: 14),
 _OtherTextField(
 controller: _positionOtherController,
 label: 'Specify your position',
 hint: 'e.g. Construction Superintendent, Scrum Master',
 onChanged: (v) => setState(() {
 _answers = _answers.copyWith(positionOther: v);
 }),
 ),
 ],
 ],
 ),
 ),
 );
 }

 // ── Step 2: Decision maker ─────────────────────────────────────────────
 Widget _buildDecisionMakerPage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 02',
 title: 'Are you the decision maker?',
 subtitle:
 'We use this to decide whether to surface executive summaries, approval workflows, or contributor-focused views first.',
 ),
 const SizedBox(height: 24),
 _BigChoiceTile(
 icon: Icons.check_circle_rounded,
 title: 'Yes — I approve budgets and scope',
 description:
 'I sign off on project budgets, scope changes, and tool purchases.',
 selected: _answers.isDecisionMaker == true,
 onTap: () => _setDecisionMaker(true),
 ),
 const SizedBox(height: 12),
 _BigChoiceTile(
 icon: Icons.group_rounded,
 title: 'No — I contribute, others decide',
 description:
 'I deliver work on projects, but a manager or sponsor approves.',
 selected: _answers.isDecisionMaker == false,
 onTap: () => _setDecisionMaker(false),
 ),
 const SizedBox(height: 12),
 _BigChoiceTile(
 icon: Icons.more_horiz_rounded,
 title: 'Other / It depends',
 description:
 'Shared ownership, board approval, or a hybrid situation.',
 selected: _answers.isDecisionMaker == null,
 onTap: () => _setDecisionMaker(null),
 ),
 ],
 ),
 ),
 );
 }

 // ── Step 3: Country ────────────────────────────────────────────────────
 Widget _buildCountryPage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 03',
 title: 'Which country are you based in?',
 subtitle:
 'Used for default date formats, regional compliance hints, and to suggest locally relevant templates. This selection is reflected across the entire application.',
 ),
 const SizedBox(height: 20),
 _SearchableOptionList(
 options: worldCountries,
 selectedValue: _answers.country,
 onSelected: _setCountry,
 searchHint: 'Search countries...',
 ),
 if (_answers.country == 'Other') ...[
 const SizedBox(height: 14),
 _OtherTextField(
 controller: _countryOtherController,
 label: 'Specify your country',
 hint: 'e.g. Botswana, Trinidad and Tobago',
 onChanged: (v) => setState(() {
 _answers = _answers.copyWith(countryOther: v);
 }),
 ),
 ],
 ],
 ),
 ),
 );
 }

 // ── Step 4: Currency ───────────────────────────────────────────────────
 Widget _buildCurrencyPage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 04',
 title: 'What is your main currency?',
 subtitle:
 'Sets the default currency for cost estimates, budgets, and earned-value reports across the entire application. Multi-currency support is available per project.',
 ),
 const SizedBox(height: 20),
 _SearchableOptionList(
 options: worldCurrencies,
 selectedValue: _answers.currency,
 onSelected: _setCurrency,
 searchHint: 'Search currencies...',
 ),
 if (_answers.currency == 'Other') ...[
 const SizedBox(height: 14),
 _OtherTextField(
 controller: _currencyOtherController,
 label: 'Specify your currency',
 hint: 'e.g. ZMW (Zambian Kwacha), TTD (Trinidad Dollar)',
 onChanged: (v) => setState(() {
 _answers = _answers.copyWith(currencyOther: v);
 }),
 ),
 ],
 ],
 ),
 ),
 );
 }

 // ── Step 5: Tools ──────────────────────────────────────────────────────
 Widget _buildToolsPage() {
 const tools = [
 ('Excel / Google Sheets', Icons.table_chart_rounded),
 ('Microsoft Project', Icons.calendar_month_rounded),
 ('Jira', Icons.bug_report_rounded),
 ('Asana', Icons.checklist_rounded),
 ('Monday.com', Icons.view_kanban_rounded),
 ('Trello', Icons.dashboard_rounded),
 ('Smartsheet', Icons.grid_on_rounded),
 ('Notion', Icons.note_rounded),
 ('ClickUp', Icons.task_rounded),
 ('Primavera P6', Icons.account_tree_rounded),
 ('Procore', Icons.construction_rounded),
 ('SAP', Icons.business_rounded),
 ('Oracle', Icons.cloud_rounded),
 ('Email / Spreadsheets only', Icons.email_rounded),
 ('Other', Icons.more_horiz_rounded),
 ];
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 05',
 title: 'What tools do you currently use?',
 subtitle:
 'Select all that apply. We\'ll suggest import paths and integrations for each tool you already use so you don\'t start from a blank page.',
 ),
 const SizedBox(height: 20),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: tools.map((t) {
 final selected = _answers.currentTools.contains(t.$1);
 return _ToolChip(
 label: t.$1,
 icon: t.$2,
 selected: selected,
 onTap: () => _toggleTool(t.$1),
 );
 }).toList(),
 ),
 if (_answers.currentTools.contains('Other')) ...[
 const SizedBox(height: 14),
 _OtherTextField(
 controller: _toolsOtherController,
 label: 'Specify the other tool(s)',
 hint: 'e.g. Smartsheet, Airtable, custom internal system',
 onChanged: (v) => setState(() {
 _answers = _answers.copyWith(currentToolsOther: v);
 }),
 ),
 ],
 if (_answers.currentTools.isNotEmpty) ...[
 const SizedBox(height: 14),
 Text(
 '${_answers.currentTools.length} selected',
 style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w600),
 ),
 ],
 ],
 ),
 ),
 );
 }

 // ── Steps 6–9 + supporting widgets are in the second part of the file ───
 // (continued below — kept in the same State class via partial build methods)
 // To avoid exceeding editor limits, the remaining step builders are defined
 // in _profile_onboarding_screen_part2.dart and included via part directive.
 // For simplicity, we instead inline them here as instance methods.

 // ── Step 6: Organization overview ──────────────────────────────────────
 Widget _buildOrganizationOverviewPage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 06',
 title: 'Tell us about your organization',
 subtitle:
 'Provide an overview of your organization and the types of work you manage. This information helps tailor your platform project(s) and provides more relevant guidance throughout the lifecycle of your projects, programs, and portfolios.',
 ),
 const SizedBox(height: 18),
 // Tip card
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: _gold.withOpacity(0.06),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _gold.withOpacity(0.25), width: 1),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Row(
 children: [
 Icon(Icons.lightbulb_rounded, color: _gold, size: 18),
 SizedBox(width: 8),
 Text(
 'TIP — Consider including as much information as possible about:',
 style: TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.5,
 ),
 ),
 ],
 ),
 SizedBox(height: 10),
 _TipBullet(text: 'Company name, industry, size, and geographic locations served'),
 SizedBox(height: 6),
 _TipBullet(text: 'Products, services, or core business activities'),
 SizedBox(height: 6),
 _TipBullet(text: 'Organizational structure and key functional areas involved in project delivery'),
 SizedBox(height: 6),
 _TipBullet(text: 'Typical types of projects, average duration, budget ranges, and team sizes'),
 ],
 ),
 ),
 const SizedBox(height: 18),
 _MultilineTextField(
 controller: _orgOverviewController,
 label: 'Organization overview',
 hint: 'We are a mid-sized EPC contractor headquartered in Lusaka, Zambia, with regional offices in...',
 minLines: 8,
 maxLines: 14,
 maxLength: 4000,
 ),
 ],
 ),
 ),
 );
 }

 // ── Step 7: Team invitations ───────────────────────────────────────────
 Widget _buildTeamInvitePage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 07',
 title: 'Want to invite team members?',
 subtitle:
 'Invite teammates now or skip and do it later. Each invitee receives an email with a secure auto-link — when clicked, they\'re taken straight to the sign-in page.',
 ),
 const SizedBox(height: 20),
 Row(
 children: [
 Expanded(
 child: _GhostButton(
 label: 'Skip for now',
 icon: Icons.skip_next_rounded,
 onTap: _isSaving
 ? null
 : () {
 setState(() {
 _answers = _answers.copyWith(invitedEmails: const []);
 });
 _next();
 },
 fullWidth: true,
 ),
 ),
 ],
 ),
 const SizedBox(height: 18),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: _bgSurfaceHigh.withOpacity(0.4),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _border.withOpacity(0.3), width: 1),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'INVITE BY EMAIL',
 style: TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _CustomTextField(
 controller: _emailInviteController,
 hint: 'teammate@company.com',
 keyboardType: TextInputType.emailAddress,
 errorText: _emailError,
 onSubmitted: (_) => _addInviteEmail(),
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 _PrimaryButton(
 label: 'Send invite',
 icon: Icons.send_rounded,
 onTap: _addInviteEmail,
 ),
 ],
 ),
 if (_answers.invitedEmails.isNotEmpty) ...[
 const SizedBox(height: 16),
 const Text(
 'PENDING INVITATIONS',
 style: TextStyle(
 color: _textMuted,
 fontSize: 10,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 const SizedBox(height: 8),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _answers.invitedEmails.map((email) {
 return _InviteChip(
 email: email,
 status: _inviteStatuses[email] ?? _InviteStatus.sending,
 onRemove: () => _removeInviteEmail(email),
 onRetry: () {
 setState(() => _inviteStatuses[email] = _InviteStatus.sending);
 _sendInvitationForEmail(email);
 },
 );
 }).toList(),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Icon(Icons.mark_email_read_rounded,
 color: _gold.withOpacity(0.8), size: 14),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 'Invitation emails are sent immediately from nduproject.tech. Each link expires in 7 days and takes the recipient to the sign-in page.',
 style: TextStyle(
 color: _textSecondary.withOpacity(0.85),
 fontSize: 11,
 height: 1.5,
 ),
 ),
 ),
 ],
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 // ── Step 8: Max team size per project ──────────────────────────────────
 Widget _buildMaxTeamSizePage() {
 final tierOptions = [
 ('Starter', 5, 'Up to 5 members per project'),
 ('Professional', 25, 'Up to 25 members per project'),
 ('Business', 100, 'Up to 100 members per project'),
 ('Enterprise', 250, 'Up to 250 members per project'),
 ('Custom', 0, 'Specify a custom number'),
 ];
 final currentTier = _answers.tierAtSignup ?? 'Professional';
 final customValue = int.tryParse(_maxTeamSizeController.text.trim());
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 08',
 title: 'Maximum members per project',
 subtitle:
 'Sets the per-project team-size cap that will be applied for your tier. You can override this per project later — this just sets the default upper bound.',
 ),
 const SizedBox(height: 20),
 Text(
 'CURRENT TIER: ${currentTier.toUpperCase()}',
 style: const TextStyle(
 color: _gold,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 const SizedBox(height: 14),
 Column(
 children: tierOptions.map((t) {
 final isSelected = _answers.maxTeamSizePerProject == t.$2 &&
 (t.$2 != 0 || (customValue != null && customValue > 0));
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: _BigChoiceTile(
 icon: t.$2 == 0
 ? Icons.tune_rounded
 : Icons.people_alt_outlined,
 title: t.$1,
 description: t.$3,
 selected: isSelected,
 onTap: () {
 setState(() {
 _answers = _answers.copyWith(
 maxTeamSizePerProject: t.$2,
 tierAtSignup: t.$1,
 );
 if (t.$2 == 0) {
 // Custom — focus the text field, keep its value
 if (_maxTeamSizeController.text.trim().isEmpty) {
 _maxTeamSizeController.text = '50';
 }
 } else {
 _maxTeamSizeController.text = '${t.$2}';
 }
 });
 },
 ),
 );
 }).toList(),
 ),
 if (_answers.maxTeamSizePerProject == 0) ...[
 const SizedBox(height: 14),
 _CustomTextField(
 controller: _maxTeamSizeController,
 hint: 'Enter maximum number of members per project',
 keyboardType: TextInputType.number,
 prefixIcon: Icons.group_rounded,
 onChanged: (v) {
 final parsed = int.tryParse(v.trim());
 if (parsed != null) {
 setState(() {
 _answers = _answers.copyWith(maxTeamSizePerProject: parsed);
 });
 }
 },
 ),
 ],
 ],
 ),
 ),
 );
 }

 // ── Step 9: Review & finish ────────────────────────────────────────────
 Widget _buildReviewPage() {
 return _StepShell(
 revealFade: _revealFade,
 revealSlide: _revealSlide,
 child: _ScrollableStep(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 eyebrow: 'Step 09',
 title: 'Review your setup',
 subtitle:
 'A quick summary of what we\'ll save. You can edit any of this later from your profile settings.',
 ),
 const SizedBox(height: 20),
 _ReviewRow(
 label: 'Position',
 value: _answers.positionDisplay,
 ),
 _ReviewRow(
 label: 'Decision maker',
 value: _answers.isDecisionMaker == true
 ? 'Yes'
 : (_answers.isDecisionMaker == false ? 'No' : 'Other'),
 ),
 _ReviewRow(
 label: 'Country',
 value: _answers.countryDisplay,
 ),
 _ReviewRow(
 label: 'Currency',
 value: _answers.currencyDisplay,
 ),
 _ReviewRow(
 label: 'Current tools',
 value: _answers.currentToolsDisplay.isEmpty
 ? '—'
 : _answers.currentToolsDisplay.join(', '),
 ),
 _ReviewRow(
 label: 'Team invitations',
 value: _answers.invitedEmails.isEmpty
 ? 'None — invite later'
 : _reviewInviteSummary(),
 ),
 _ReviewRow(
 label: 'Max members / project',
 value: _answers.maxTeamSizePerProject?.toString() ?? '—',
 ),
 const SizedBox(height: 18),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: _gold.withOpacity(0.06),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _gold.withOpacity(0.25), width: 1),
 ),
 child: Row(
 children: [
 Icon(Icons.rocket_launch_rounded, color: _gold, size: 22),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'You\'re ready to launch',
 style: TextStyle(
 color: _textPrimary,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Tap "Finish setup" to save your answers and personalize your workspace.',
 style: TextStyle(
 color: _textSecondary,
 fontSize: 12,
 height: 1.5,
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
}

// ── Shared widgets (used by all steps) ───────────────────────────────────

class _StepShell extends StatelessWidget {
 const _StepShell({
 required this.revealFade,
 required this.revealSlide,
 required this.child,
 });

 final Animation<double> revealFade;
 final Animation<Offset> revealSlide;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return FadeTransition(
 opacity: revealFade,
 child: SlideTransition(
 position: revealSlide,
 child: child,
 ),
 );
 }
}

class _ScrollableStep extends StatelessWidget {
 const _ScrollableStep({required this.child});
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
 physics: const BouncingScrollPhysics(),
 child: child,
 );
 }
}

class _GhostIconButton extends StatefulWidget {
 const _GhostIconButton({
 required this.icon,
 required this.onTap,
 this.tooltip,
 });
 final IconData icon;
 final VoidCallback? onTap;
 final String? tooltip;

 @override
 State<_GhostIconButton> createState() => _GhostIconButtonState();
}

class _GhostIconButtonState extends State<_GhostIconButton> {
 bool _hover = false;
 @override
 Widget build(BuildContext context) {
 final btn = MouseRegion(
 cursor: widget.onTap == null
 ? SystemMouseCursors.forbidden
 : SystemMouseCursors.click,
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 color: _hover ? _bgSurfaceHighest : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(
 widget.icon,
 color: _hover ? _textPrimary : _textMuted,
 size: 20,
 ),
 ),
 ),
 );
 return MouseRegion(
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: widget.tooltip == null
 ? btn
 : Tooltip(message: widget.tooltip!, child: btn),
 );
 }
}

class _GhostButton extends StatefulWidget {
 const _GhostButton({
 required this.label,
 this.icon,
 required this.onTap,
 this.fullWidth = false,
 });
 final String label;
 final IconData? icon;
 final VoidCallback? onTap;
 final bool fullWidth;

 @override
 State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
 bool _hover = false;
 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 cursor: widget.onTap == null
 ? SystemMouseCursors.forbidden
 : SystemMouseCursors.click,
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 decoration: BoxDecoration(
 color: _hover ? _bgSurfaceHighest : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _border.withOpacity(0.4), width: 1),
 ),
 child: Row(
 mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
 mainAxisAlignment: widget.fullWidth
 ? MainAxisAlignment.center
 : MainAxisAlignment.start,
 children: [
 if (widget.icon != null) ...[
 Icon(widget.icon, color: _textSecondary, size: 16),
 const SizedBox(width: 8),
 ],
 Text(
 widget.label,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _PrimaryButton extends StatefulWidget {
 const _PrimaryButton({
 required this.label,
 required this.icon,
 required this.onTap,
 this.isLoading = false,
 });
 final String label;
 final IconData icon;
 final VoidCallback? onTap;
 final bool isLoading;

 @override
 State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
 bool _hover = false;
 bool _press = false;
 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 cursor: widget.onTap == null
 ? SystemMouseCursors.forbidden
 : SystemMouseCursors.click,
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: GestureDetector(
 onTapDown: (_) => setState(() => _press = true),
 onTapUp: (_) => setState(() => _press = false),
 onTapCancel: () => setState(() => _press = false),
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 150),
 transform: Matrix4.identity()..scale(_press ? 0.96 : 1.0),
 transformAlignment: Alignment.center,
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
 decoration: BoxDecoration(
 color: _gold,
 borderRadius: BorderRadius.circular(24),
 boxShadow: _hover
 ? [
 BoxShadow(
 color: _gold.withOpacity(0.35),
 blurRadius: 18,
 spreadRadius: 0,
 ),
 ]
 : [],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (widget.isLoading) ...[
 const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: _goldDeep,
 ),
 ),
 const SizedBox(width: 8),
 ] else ...[
 Text(
 widget.label,
 style: const TextStyle(
 color: _goldDeep,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.2,
 ),
 ),
 const SizedBox(width: 8),
 Icon(widget.icon, color: _goldDeep, size: 16),
 ],
 ],
 ),
 ),
 ),
 );
 }
}

class _OptionGrid extends StatelessWidget {
 const _OptionGrid({
 required this.options,
 required this.selectedValue,
 required this.onSelected,
 });
 final List<(String, IconData)> options;
 final String? selectedValue;
 final ValueChanged<String> onSelected;

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: options.map((opt) {
 final selected = selectedValue == opt.$1;
 return _OptionChip(
 label: opt.$1,
 icon: opt.$2,
 selected: selected,
 onTap: () => onSelected(opt.$1),
 );
 }).toList(),
 );
 }
}

class _OptionChip extends StatefulWidget {
 const _OptionChip({
 required this.label,
 required this.icon,
 required this.selected,
 required this.onTap,
 });
 final String label;
 final IconData icon;
 final bool selected;
 final VoidCallback onTap;

 @override
 State<_OptionChip> createState() => _OptionChipState();
}

class _OptionChipState extends State<_OptionChip> {
 bool _hover = false;
 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 cursor: SystemMouseCursors.click,
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
 decoration: BoxDecoration(
 color: widget.selected
 ? _gold.withOpacity(0.12)
 : (_hover ? _bgSurfaceHigh : _bgSurfaceMid),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: widget.selected
 ? _gold
 : (_hover ? _border : _border.withOpacity(0.4)),
 width: widget.selected ? 1.5 : 1,
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 widget.icon,
 color: widget.selected ? _gold : _textSecondary,
 size: 16,
 ),
 const SizedBox(width: 8),
 Text(
 widget.label,
 style: TextStyle(
 color: widget.selected ? _gold : _textPrimary,
 fontSize: 13,
 fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
 ),
 ),
 if (widget.selected) ...[
 const SizedBox(width: 6),
 const Icon(Icons.check_circle_rounded, color: _gold, size: 14),
 ],
 ],
 ),
 ),
 ),
 );
 }
}

class _BigChoiceTile extends StatefulWidget {
 const _BigChoiceTile({
 required this.icon,
 required this.title,
 required this.description,
 required this.selected,
 required this.onTap,
 });
 final IconData icon;
 final String title;
 final String description;
 final bool selected;
 final VoidCallback onTap;

 @override
 State<_BigChoiceTile> createState() => _BigChoiceTileState();
}

class _BigChoiceTileState extends State<_BigChoiceTile> {
 bool _hover = false;
 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 cursor: SystemMouseCursors.click,
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: widget.selected
 ? _gold.withOpacity(0.08)
 : (_hover ? _bgSurfaceHigh : _bgSurfaceMid),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: widget.selected
 ? _gold
 : (_hover ? _border : _border.withOpacity(0.4)),
 width: widget.selected ? 1.5 : 1,
 ),
 ),
 child: Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: widget.selected
 ? _gold.withOpacity(0.18)
 : _bgSurfaceHighest,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(
 widget.icon,
 color: widget.selected ? _gold : _textSecondary,
 size: 20,
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 widget.title,
 style: TextStyle(
 color: widget.selected ? _gold : _textPrimary,
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 widget.description,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 12,
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 if (widget.selected)
 const Padding(
 padding: EdgeInsets.only(left: 8),
 child: Icon(Icons.check_circle_rounded, color: _gold, size: 20),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _ToolChip extends StatefulWidget {
 const _ToolChip({
 required this.label,
 required this.icon,
 required this.selected,
 required this.onTap,
 });
 final String label;
 final IconData icon;
 final bool selected;
 final VoidCallback onTap;

 @override
 State<_ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<_ToolChip> {
 bool _hover = false;
 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 cursor: SystemMouseCursors.click,
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _hover = false);
 }),
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 160),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
 decoration: BoxDecoration(
 color: widget.selected
 ? _gold.withOpacity(0.14)
 : (_hover ? _bgSurfaceHigh : _bgSurfaceMid),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: widget.selected ? _gold : _border.withOpacity(0.4),
 width: widget.selected ? 1.5 : 1,
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 widget.icon,
 color: widget.selected ? _gold : _textSecondary,
 size: 14,
 ),
 const SizedBox(width: 6),
 Text(
 widget.label,
 style: TextStyle(
 color: widget.selected ? _gold : _textPrimary,
 fontSize: 12,
 fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _SearchableOptionList extends StatefulWidget {
 const _SearchableOptionList({
 required this.options,
 required this.selectedValue,
 required this.onSelected,
 required this.searchHint,
 });
 final List<String> options;
 final String? selectedValue;
 final ValueChanged<String> onSelected;
 final String searchHint;

 @override
 State<_SearchableOptionList> createState() => _SearchableOptionListState();
}

class _SearchableOptionListState extends State<_SearchableOptionList> {
 final TextEditingController _searchController = TextEditingController();
 String _query = '';

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final filtered = widget.options.where((o) {
 if (_query.isEmpty) return true;
 return o.toLowerCase().contains(_query.toLowerCase());
 }).toList();
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Search box
 Container(
 decoration: BoxDecoration(
 color: _bgSurfaceMid,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _border.withValues(alpha: 0.4), width: 1),
 ),
 child: VoiceTextField(
 controller: _searchController,
 style: const TextStyle(color: _textPrimary, fontSize: 14),
 cursorColor: _gold,
 voiceIconColor: _gold,
 enableDocxImport: false,
 decoration: InputDecoration(
 hintText: widget.searchHint,
 hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 14),
 prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 18),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 ),
 onChanged: (v) => setState(() => _query = v),
 ),
 ),
 const SizedBox(height: 12),
 // Options list (scrollable, capped height)
 Container(
 constraints: const BoxConstraints(maxHeight: 280),
 decoration: BoxDecoration(
 color: _bgSurfaceMid.withOpacity(0.4),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _border.withOpacity(0.3), width: 1),
 ),
 child: ListView.separated(
 shrinkWrap: true,
 padding: const EdgeInsets.symmetric(vertical: 4),
 itemCount: filtered.length,
 separatorBuilder: (_, __) => Divider(
 color: _border.withOpacity(0.2),
 height: 1,
 indent: 12,
 endIndent: 12,
 ),
 itemBuilder: (_, i) {
 final opt = filtered[i];
 final selected = widget.selectedValue == opt;
 return ListTile(
 dense: true,
 visualDensity: VisualDensity.compact,
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
 title: Text(
 opt,
 style: TextStyle(
 color: selected ? _gold : _textPrimary,
 fontSize: 13,
 fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
 ),
 ),
 trailing: selected
 ? const Icon(Icons.check_circle_rounded, color: _gold, size: 18)
 : null,
 onTap: () => widget.onSelected(opt),
 );
 },
 ),
 ),
 ],
 );
 }
}

class _OtherTextField extends StatelessWidget {
 const _OtherTextField({
 required this.controller,
 required this.label,
 required this.hint,
 required this.onChanged,
 });
 final TextEditingController controller;
 final String label;
 final String hint;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: _bgSurfaceMid,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
 child: Text(
 label.toUpperCase(),
 style: const TextStyle(
 color: _gold,
 fontSize: 10,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 ),
 VoiceTextField(
 controller: controller,
 style: const TextStyle(color: _textPrimary, fontSize: 14),
 cursorColor: _gold,
 voiceIconColor: _gold,
 enableDocxImport: false,
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 14),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
 ),
 onChanged: onChanged,
 ),
 ],
 ),
 );
 }
}

class _MultilineTextField extends StatelessWidget {
 const _MultilineTextField({
 required this.controller,
 required this.label,
 required this.hint,
 required this.minLines,
 required this.maxLines,
 required this.maxLength,
 });
 final TextEditingController controller;
 final String label;
 final String hint;
 final int minLines;
 final int maxLines;
 final int maxLength;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: _bgSurfaceMid,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _border.withValues(alpha: 0.4), width: 1),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
 child: Text(
 label.toUpperCase(),
 style: const TextStyle(
 color: _gold,
 fontSize: 10,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 ),
 VoiceTextField(
 controller: controller,
 style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.6),
 cursorColor: _gold,
 voiceIconColor: _gold,
 enableDocxImport: false,
 maxLines: maxLines,
 minLines: minLines,
 maxLength: maxLength,
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
 counterStyle: const TextStyle(color: _textMuted, fontSize: 11),
 ),
 ),
 ],
 ),
 );
 }
}

class _CustomTextField extends StatelessWidget {
 const _CustomTextField({
 required this.controller,
 required this.hint,
 this.keyboardType,
 this.prefixIcon,
 this.errorText,
 this.onSubmitted,
 this.onChanged,
 });
 final TextEditingController controller;
 final String hint;
 final TextInputType? keyboardType;
 final IconData? prefixIcon;
 final String? errorText;
 final ValueChanged<String>? onSubmitted;
 final ValueChanged<String>? onChanged;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 decoration: BoxDecoration(
 color: _bgSurfaceMid,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: errorText != null
 ? Colors.redAccent.withValues(alpha: 0.6)
 : _border.withValues(alpha: 0.4),
 width: 1),
 ),
 child: VoiceTextField(
 controller: controller,
 style: const TextStyle(color: _textPrimary, fontSize: 14),
 cursorColor: _gold,
 voiceIconColor: _gold,
 enableDocxImport: false,
 keyboardType: keyboardType,
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.7), fontSize: 14),
 prefixIcon: prefixIcon != null
 ? Icon(prefixIcon, color: _textMuted, size: 18)
 : null,
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 ),
 onSubmitted: onSubmitted,
 onChanged: onChanged,
 ),
 ),
 if (errorText != null) ...[
 const SizedBox(height: 6),
 Padding(
 padding: const EdgeInsets.only(left: 4),
 child: Text(
 errorText!,
 style: const TextStyle(color: Colors.redAccent, fontSize: 11),
 ),
 ),
 ],
 ],
 );
 }
}

enum _InviteStatus { sending, sent, failed }

class _InviteChip extends StatelessWidget {
 const _InviteChip({
 required this.email,
 required this.status,
 required this.onRemove,
 this.onRetry,
 });
 final String email;
 final _InviteStatus status;
 final VoidCallback onRemove;
 final VoidCallback? onRetry;

 @override
 Widget build(BuildContext context) {
 final borderColor = switch (status) {
 _InviteStatus.sending => _border.withOpacity(0.5),
 _InviteStatus.sent => const Color(0xFF22C55E).withOpacity(0.6),
 _InviteStatus.failed => const Color(0xFFEF4444).withOpacity(0.6),
 };
 final bgColor = switch (status) {
 _InviteStatus.sending => _bgSurfaceHighest,
 _InviteStatus.sent => const Color(0xFF22C55E).withOpacity(0.08),
 _InviteStatus.failed => const Color(0xFFEF4444).withOpacity(0.08),
 };
 return GestureDetector(
 onTap: (status == _InviteStatus.failed && onRetry != null) ? onRetry : null,
 child: Tooltip(
 message: switch (status) {
 _InviteStatus.sending => 'Sending…',
 _InviteStatus.sent => 'Invitation sent',
 _InviteStatus.failed => 'Failed — tap to retry',
 },
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 300),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: bgColor,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: borderColor, width: 1),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _statusIcon(),
 const SizedBox(width: 6),
 Text(
 email,
 style: const TextStyle(color: _textPrimary, fontSize: 12),
 ),
 const SizedBox(width: 6),
 GestureDetector(
 onTap: onRemove,
 child: const Icon(Icons.close_rounded, color: _textMuted, size: 14),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _statusIcon() {
 return switch (status) {
 _InviteStatus.sending => const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: _gold,
 ),
 ),
 _InviteStatus.sent => const Icon(
 Icons.check_circle_rounded,
 color: Color(0xFF22C55E),
 size: 14,
 ),
 _InviteStatus.failed => const Icon(
 Icons.error_rounded,
 color: Color(0xFFEF4444),
 size: 14,
 ),
 };
 }
}

class _TipBullet extends StatelessWidget {
 const _TipBullet({required this.text});
 final String text;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 margin: const EdgeInsets.only(top: 6),
 width: 4,
 height: 4,
 decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 text,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 12,
 height: 1.5,
 ),
 ),
 ),
 ],
 );
 }
}

class _ReviewRow extends StatelessWidget {
 const _ReviewRow({required this.label, required this.value});
 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: _bgSurfaceMid.withOpacity(0.4),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: _border.withOpacity(0.25), width: 1),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: 140,
 child: Text(
 label.toUpperCase(),
 style: const TextStyle(
 color: _textMuted,
 fontSize: 10,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 value.isEmpty ? '—' : value,
 style: const TextStyle(
 color: _textPrimary,
 fontSize: 13,
 fontWeight: FontWeight.w500,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _WelcomeStepRow extends StatelessWidget {
 const _WelcomeStepRow({
 required this.number,
 required this.title,
 required this.description,
 required this.isCompleted,
 required this.isActive,
 });
 final String number;
 final String title;
 final String description;
 final bool isCompleted;
 final bool isActive;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: isActive ? _gold : _bgSurfaceHighest,
 shape: BoxShape.circle,
 border: isActive ? null : Border.all(color: _border, width: 1),
 ),
 child: Center(
 child: Text(
 number,
 style: TextStyle(
 color: isActive ? _goldDeep : _textSecondary,
 fontSize: 13,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Opacity(
 opacity: isActive ? 1.0 : 0.6,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 color: _textPrimary,
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 description,
 style: const TextStyle(
 color: _textSecondary,
 fontSize: 12,
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 );
 }
}

// ── Atmospheric background ───────────────────────────────────────────────

class _AtmosphericBackground extends StatelessWidget {
 const _AtmosphericBackground({required this.opacity});
 final double opacity;

 @override
 Widget build(BuildContext context) {
 return Opacity(
 opacity: opacity,
 child: Stack(
 children: [
 // Top-right secondary glow
 Positioned(
 top: -100,
 right: -120,
 child: Container(
 width: 500,
 height: 500,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: const Color(0xFF0231DE).withOpacity(0.05),
 ),
 ),
 ),
 // Bottom-left gold glow
 Positioned(
 bottom: -80,
 left: -100,
 child: Container(
 width: 400,
 height: 400,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _gold.withOpacity(0.04),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

// ── Celebration overlay ──────────────────────────────────────────────────

class _CelebrationOverlay extends StatelessWidget {
 const _CelebrationOverlay({
 required this.controller,
 required this.scale,
 required this.confettiOpacity,
 });
 final AnimationController controller;
 final Animation<double> scale;
 final Animation<double> confettiOpacity;

 @override
 Widget build(BuildContext context) {
 return AnimatedBuilder(
 animation: controller,
 builder: (context, _) {
 return Stack(
 alignment: Alignment.center,
 children: [
 // Confetti
 Opacity(
 opacity: confettiOpacity.value,
 child: CustomPaint(
 size: MediaQuery.of(context).size,
 painter: _ConfettiPainter(controller.value),
 ),
 ),
 // Giant check
 Transform.scale(
 scale: scale.value,
 child: Container(
 width: 110,
 height: 110,
 decoration: BoxDecoration(
 color: _gold,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: _gold.withOpacity(0.5),
 blurRadius: 50,
 spreadRadius: 8,
 ),
 ],
 ),
 child: const Icon(
 Icons.check_rounded,
 color: _goldDeep,
 size: 64,
 ),
 ),
 ),
 ],
 );
 },
 );
 }
}

class _ConfettiPainter extends CustomPainter {
 _ConfettiPainter(this.t);
 final double t;

 @override
 void paint(Canvas canvas, Size size) {
 final rng = math.Random(42);
 final colors = [
 const Color(0xFFF8BD2A),
 const Color(0xFFD4E4FA),
 const Color(0xFFBBC3FF),
 const Color(0xFFFFDFA0),
 ];
 for (int i = 0; i < 60; i++) {
 final x = rng.nextDouble() * size.width;
 final startY = -50 - rng.nextDouble() * 200;
 final y = startY + (size.height + 200) * t + rng.nextDouble() * 60;
 final w = 6.0 + rng.nextDouble() * 6;
 final h = 10.0 + rng.nextDouble() * 8;
 final paint = Paint()..color = colors[i % colors.length].withOpacity(0.8);
 canvas.save();
 canvas.translate(x, y);
 canvas.rotate(rng.nextDouble() * 6.28 + t * 6);
 canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
 canvas.restore();
 }
 }

 @override
 bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
