/// NDU Program Dashboard — Light Mode
///
/// Program workspace overview dashboard rendered with the standard app shell:
///
/// - Light/white theme matching the rest of the app
/// - Standard header (logo + breadcrumb + nav buttons + profile avatar with logout)
/// - No sidebar (full-width dashboard, like Portfolio Dashboard)
/// - Hero bento grid: Budget KPI + Planned vs Actual chart + Radial progress gauge
/// - Project Health Matrix table with sparkline budget trends
/// - Critical Risks + Resource Capacity side-by-side
/// - Escalation Summary + Recent Activity timeline + Visual Context card
/// - Floating Action Button
/// - Custom radial gauge painter with animated sweep
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/models/program_model.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/program_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/widgets/compact_action_button.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/app_logo.dart';

class ProgramDashboardScreen extends StatefulWidget {
 final String? programId;

 const ProgramDashboardScreen({super.key, this.programId});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ProgramDashboardScreen()));
 }

 @override
 State<ProgramDashboardScreen> createState() => _ProgramDashboardScreenState();
}

class _ProgramDashboardScreenState extends State<ProgramDashboardScreen>
 with TickerProviderStateMixin {
 late AnimationController _gaugeController;
 late AnimationController _fadeController;
 late Animation<double> _gaugeAnim;
 late Animation<double> _fadeAnim;

 // ─── Design Tokens (light theme, aligned with the rest of the app) ────────
 static const _bg = Colors.white;
 static const _surface = Color(0xFFF9FAFB);
 static const _surfaceHigh = Color(0xFFF3F4F6);
 static const _surfaceHighest = Color(0xFFE5E7EB);
 static const _onSurface = Color(0xFF1A1D1F);
 static const _onSurfaceVariant = Color(0xFF6B7280);
 static const _outlineVariant = Color(0xFFE4E7EC);
 static const _primary = Color(0xFF1A1D1F);
 static const _primaryContainer = Color(0xFFE5E7EB);
 static const _tertiary = Color(0xFFFFC107);
 static const _tertiaryContainer = Color(0xFFFBBF24);
 static const _secondary = Color(0xFF3B82F6);
 static const _emerald = Color(0xFF10B981);
 static const _amber = Color(0xFFF59E0B);
 static const _crimson = Color(0xFFEF4444);
 static const _onTertiary = Color(0xFF1A1D1F);

 @override
 void initState() {
 super.initState();
 _gaugeController = AnimationController(
 vsync: this, duration: const Duration(milliseconds: 1200));
 _gaugeAnim =
 CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic);
 _fadeController = AnimationController(
 vsync: this, duration: const Duration(milliseconds: 500));
 _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
 _gaugeController.forward();
 _fadeController.forward();
 }

 @override
 void dispose() {
 _gaugeController.dispose();
 _fadeController.dispose();
 super.dispose();
 }

 // ─── Empty metrics fallback (used when streams haven't loaded yet) ──────
 static final _emptyMetrics = _ProgramMetrics(
 programName: 'Program Dashboard',
 programSubtitle: 'Loading…',
 totalBudget: 0,
 expended: 0,
 expendedPercent: 0,
 globalProgress: 0,
 projectCount: 0,
 healthEntries: const [],
 projects: const [],
 );

 String _formatBudget(double millions) {
 if (millions.isNaN || millions <= 0) return '\$0';
 if (millions >= 1000) return '\$${(millions / 1000).toStringAsFixed(1)}B';
 if (millions >= 1) return '\$${millions.toStringAsFixed(1)}M';
 return '\$${(millions * 1000).toStringAsFixed(0)}K';
 }

 // ─── Surface Card (replaces the dark glassmorphism card) ─────────────────
 Widget _surfaceCard({
 required Widget child,
 Color? leftBorder,
 EdgeInsets padding = EdgeInsets.zero,
 }) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border(
 left: leftBorder != null
 ? BorderSide(color: leftBorder, width: 4)
 : BorderSide.none,
 top: BorderSide(color: _outlineVariant, width: 1),
 right: BorderSide(color: _outlineVariant, width: 1),
 bottom: BorderSide(color: _outlineVariant, width: 1),
 ),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 8,
 offset: Offset(0, 2),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(12),
 child: padding == EdgeInsets.zero
 ? child
 : Padding(padding: padding, child: child),
 ),
 );
 }

 // ─── Logout (used by the profile avatar dropdown) ────────────────────────
 Future<void> _handleLogout() async {
 if (!mounted) return;
 final shouldLogout = await showDialog<bool>(
 context: context,
 builder: (dialogContext) {
 final theme = Theme.of(dialogContext);
 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: const Text('Confirm Log Out'),
 content: const Text('Are you sure you want to log out?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: theme.colorScheme.error,
 foregroundColor: theme.colorScheme.onError,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Log Out'),
 ),
 ],
 );
 },
 );

 if (shouldLogout == true && mounted) {
 try {
 await FirebaseAuthService.signOut();
 if (mounted) {
 context.go('/');
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error logging out: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }
 }

 void _navigateToProjectDashboard() {
 if (!mounted) return;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted) {
 context.go('/${AppRoutes.dashboard}');
 }
 });
 }

 void _navigateToPortfolio() {
 if (!mounted) return;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted) {
 context.go('/${AppRoutes.portfolioDashboard}');
 }
 });
 }

 @override
 Widget build(BuildContext context) {
 // Record this dashboard so the brand logo knows where to return on tap.
 NavigationContextService.instance
 .setLastClientDashboard(AppRoutes.programDashboard);

 final user = FirebaseAuth.instance.currentUser;

 return Scaffold(
 backgroundColor: _bg,
 floatingActionButton: Column(
 mainAxisAlignment: MainAxisAlignment.end,
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 const KazAiChatBubble(positioned: false),
 const SizedBox(height: 12),
 FloatingActionButton(
 onPressed: () {},
 backgroundColor: _tertiary,
 foregroundColor: _onTertiary,
 elevation: 4,
 shape: const CircleBorder(),
 child: const Icon(Icons.add, size: 28),
 ),
 ],
 ),
 body: SafeArea(
 child: StreamBuilder<List<ProgramModel>>(
 stream: user == null
 ? Stream.value(const <ProgramModel>[])
 : ProgramService.streamPrograms(ownerId: user.uid),
 builder: (context, programSnapshot) {
 // Load all projects for this user, then compute real metrics
 return StreamBuilder<List<ProjectRecord>>(
 stream: user == null
 ? Stream.value(const <ProjectRecord>[])
 : ProjectService.streamProjects(ownerId: user.uid),
 builder: (context, projectSnapshot) {
 // Auto-create programs/portfolios based on project count
 if (user != null && projectSnapshot.hasData) {
 final projects = projectSnapshot.data!;
 _maybeAutoCreatePrograms(user.uid, projects);
 }

 final metrics = _computeMetrics(
 programs: programSnapshot.data ?? const [],
 projects: projectSnapshot.data ?? const [],
 );

 if (projectSnapshot.connectionState ==
 ConnectionState.waiting &&
 !projectSnapshot.hasData) {
 return const Center(child: CircularProgressIndicator());
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 final horizontalPadding =
 constraints.maxWidth < 600 ? 20.0 : 40.0;
 return FadeTransition(
 opacity: _fadeAnim,
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHeader(metrics: metrics),
 const SizedBox(height: 24),
 _buildActionButtons(context),
 const SizedBox(height: 24),
 _buildHeroBento(context, metrics: metrics),
 const SizedBox(height: 24),
 _buildMainGrid(context, metrics: metrics),
 const SizedBox(height: 72),
 ],
 ),
 ),
 );
 },
 );
 },
 );
 },
 ),
 ),
 );
 }

 // ─── Auto-create Programs (3 projects) and Portfolios (7 projects) ──────
 /// When the user has 3+ projects that aren't yet in a program, automatically
 /// create a program to group them. When 7+ projects exist, create a portfolio.
 /// This runs on every dashboard build but is idempotent — it only creates
 /// new programs/portfolios for ungrouped projects.
 void _maybeAutoCreatePrograms(String ownerId, List<ProjectRecord> projects) {
 if (projects.length < 3) return;

 // Get all project IDs already in programs (we need the program snapshot
 // for this, but since this method is called from the StreamBuilder that
 // also has the program stream, we'll use a simple heuristic: check if
 // there are ungrouped projects that could form a new program)
 //
 // We defer the actual Firestore read to avoid blocking the build.
 _checkAndAutoCreatePrograms(ownerId, projects);
 }

 Future<void> _checkAndAutoCreatePrograms(
 String ownerId, List<ProjectRecord> projects) async {
 try {
 // Get existing programs for this user
 final existingProgramsSnap = await FirebaseFirestore.instance
 .collection('programs')
 .where('ownerId', isEqualTo: ownerId)
 .get();

 final groupedProjectIds = <String>{};
 for (final doc in existingProgramsSnap.docs) {
 final ids = List<String>.from(doc.data()['projectIds'] ?? []);
 groupedProjectIds.addAll(ids);
 }

 // Find ungrouped projects
 var ungrouped =
 projects.where((p) => !groupedProjectIds.contains(p.id)).toList();

 // Auto-create a program for every batch of 3 ungrouped projects
 while (ungrouped.length >= 3) {
 final batch = ungrouped.take(3).toList();
 final batchIds = batch.map((p) => p.id).toList();
 final programName = _generateProgramName(batch);

 await ProgramService.createProgram(
 name: programName,
 projectIds: batchIds,
 ownerId: ownerId,
 );

 // Remove the batched projects from ungrouped
 ungrouped = ungrouped.skip(3).toList();
 }

 // Auto-create a portfolio when 7+ projects exist total
 if (projects.length >= 7) {
 final existingPortfoliosSnap = await FirebaseFirestore.instance
 .collection('portfolios')
 .where('ownerId', isEqualTo: ownerId)
 .get();

 // Only create if no portfolio exists yet
 if (existingPortfoliosSnap.docs.isEmpty) {
 await FirebaseFirestore.instance
 .collection('portfolios')
 .add({
 'name': '${ownerId.substring(0, 6)} Portfolio',
 'projectIds': projects.take(7).map((p) => p.id).toList(),
 'ownerId': ownerId,
 'createdAt': FieldValue.serverTimestamp(),
 'updatedAt': FieldValue.serverTimestamp(),
 'status': 'Active',
 });
 }
 }
 } catch (e) {
 debugPrint('Auto-create programs error: $e');
 }
 }

 String _generateProgramName(List<ProjectRecord> projects) {
 if (projects.isEmpty) return 'New Program';
 // Use the first project's name + "Program"
 final firstName = projects.first.name;
 if (firstName.isNotEmpty) {
 return '$firstName Program';
 }
 return 'Program ${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
 }

 // ─── Compute real metrics from projects + programs ─────────────────────
 _ProgramMetrics _computeMetrics({
 required List<ProgramModel> programs,
 required List<ProjectRecord> projects,
 }) {
 // If we have programs, use the first one's projects. Otherwise, use all.
 List<ProjectRecord> relevantProjects;
 ProgramModel? activeProgram;

 if (programs.isNotEmpty) {
 activeProgram = programs.first;
 final programProjectIds = activeProgram.projectIds.toSet();
 relevantProjects =
 projects.where((p) => programProjectIds.contains(p.id)).toList();
 // If the program has no projects yet (or they haven't loaded), fall back
 if (relevantProjects.isEmpty) {
 relevantProjects = projects;
 }
 } else {
 relevantProjects = projects;
 }

 // Total budget = sum of investmentMillions across all relevant projects
 final totalBudget = relevantProjects.fold<double>(
 0,
 (sum, p) => sum + (p.investmentMillions.isNaN ? 0 : p.investmentMillions),
 );

 // Expended = budget * avg progress (proxy for actual spend)
 final avgProgress = relevantProjects.isEmpty
 ? 0.0
 : relevantProjects.fold<double>(0,
 (sum, p) => sum + (p.progress.isNaN ? 0 : p.progress.clamp(0, 1))) /
 relevantProjects.length;
 final expended = totalBudget * avgProgress;
 final expendedPercent = totalBudget > 0 ? (expended / totalBudget) : 0.0;

 // Global progress = average progress across projects
 final globalProgress = avgProgress;

 // Project health entries
 final healthEntries = relevantProjects.map((p) {
 final progress = p.progress.isNaN ? 0.0 : p.progress.clamp(0, 1);
 String statusLabel;
 Color statusColor;
 String scheduleLabel;
 Color? scheduleColor;

 if (progress >= 0.67) {
 statusLabel = 'Healthy';
 statusColor = _emerald;
 scheduleLabel = 'On Track';
 scheduleColor = null;
 } else if (progress >= 0.34) {
 statusLabel = 'At Risk';
 statusColor = _amber;
 scheduleLabel = progress < 0.5 ? 'Delayed' : 'On Track';
 scheduleColor = _amber;
 } else {
 statusLabel = 'Critical';
 statusColor = _crimson;
 scheduleLabel = 'Stalled';
 scheduleColor = _crimson;
 }

 // Sparkline: synthesize from progress (rising = healthy, falling = at risk)
 final sparkline = progress >= 0.67
 ? [0.2, 0.4, 0.6, 1.0]
 : progress >= 0.34
 ? [1.0, 0.6, 0.4, 0.2]
 : [0.8, 1.0, 0.5, 0.2];

 return (
 p.name.isEmpty ? 'Untitled Project' : p.name,
 p.solutionTitle.isEmpty ? p.status : p.solutionTitle,
 statusLabel,
 statusColor,
 sparkline,
 scheduleLabel,
 '${(progress * 100).round()}%',
 scheduleColor,
 );
 }).toList();

 return _ProgramMetrics(
 programName: activeProgram?.name ?? 'Program Dashboard',
 programSubtitle: activeProgram != null
 ? '${relevantProjects.length} projects in this program'
 : '${relevantProjects.length} projects total',
 totalBudget: totalBudget,
 expended: expended,
 expendedPercent: expendedPercent,
 globalProgress: globalProgress,
 projectCount: relevantProjects.length,
 healthEntries: healthEntries,
 projects: relevantProjects,
 );
 }

 // ─── Standard Header ─────────────────────────────────────────────────────
 Widget _buildHeader({_ProgramMetrics? metrics}) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName = FirebaseAuthService.displayNameOrEmail();
 final initials = _userInitials(displayName);

 return LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 960;

 final crumb = Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: _outlineVariant),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0D000000),
 blurRadius: 8,
 offset: Offset(0, 2),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.view_quilt_outlined,
 size: 18, color: _onSurfaceVariant),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 'Program workspace overview',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: _onSurfaceVariant,
 fontFamily: appFontFamily,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 );

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Padding(
 padding: EdgeInsets.only(bottom: compact ? 16 : 20),
 child: Align(
 alignment:
 compact ? Alignment.center : Alignment.centerLeft,
 child: AppLogo(
 height: compact ? 72 : 88,
 semanticLabel: 'NDU Project Platform',
 ),
 ),
 ),
 ),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 alignment: WrapAlignment.end,
 crossAxisAlignment: WrapCrossAlignment.start,
 children: [
 ElevatedButton(
 onPressed: _navigateToProjectDashboard,
 style: ElevatedButton.styleFrom(
 backgroundColor: _secondary,
 foregroundColor: Colors.white,
 elevation: 2,
 shadowColor: const Color(0x1A000000),
 padding: const EdgeInsets.symmetric(
 horizontal: 26, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.add_circle_outline, size: 22),
 const SizedBox(width: 10),
 Text('Create Project',
 style: TextStyle(fontFamily: appFontFamily)),
 const SizedBox(width: 6),
 const Icon(Icons.arrow_forward, size: 20),
 ],
 ),
 ),
 _secondaryCta(
 label: 'Create Portfolio',
 onPressed: _navigateToPortfolio,
 ),
 _profileAvatar(user, displayName, initials),
 ],
 ),
 ],
 ),
 const SizedBox(height: 18),
 Row(
 children: [
 IconButton(
 icon: const Icon(Icons.arrow_back),
 onPressed: () {
 if (context.canPop()) {
 context.pop();
 } else {
 context.go('/${AppRoutes.dashboard}');
 }
 },
 color: _onSurfaceVariant,
 tooltip: 'Back',
 ),
 const SizedBox(width: 10),
 Expanded(child: crumb),
 ],
 ),
 const SizedBox(height: 22),
 Text(
 metrics?.programName ?? 'Program Dashboard',
 style: TextStyle(
 color: _primary,
 fontSize: 26,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.3,
 fontFamily: appFontFamily,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 metrics?.programSubtitle ?? 'Loading…',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 15,
 fontFamily: appFontFamily,
 ),
 ),
 ],
 );
 },
 );
 }

 String _userInitials(String displayName) {
 if (displayName.isEmpty) return 'U';
 final parts =
 displayName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
 if (parts.isEmpty) return displayName.substring(0, 1).toUpperCase();
 if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
 return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
 }

 Widget _profileAvatar(User? user, String displayName, String initials) {
 final photoUrl = user?.photoURL;
 return PopupMenuButton<String>(
 tooltip: displayName,
 offset: const Offset(0, 52),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 color: Colors.white,
 elevation: 4,
 icon: Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _primaryContainer,
 border: Border.all(color: _outlineVariant, width: 1),
 ),
 child: ClipOval(
 child: photoUrl != null && photoUrl.isNotEmpty
 ? Image.network(
 photoUrl,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Center(
 child: Text(
 initials,
 style: TextStyle(
 color: _primary,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 fontFamily: appFontFamily,
 ),
 ),
 ),
 )
 : Center(
 child: Text(
 initials,
 style: TextStyle(
 color: _primary,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 fontFamily: appFontFamily,
 ),
 ),
 ),
 ),
 ),
 itemBuilder: (context) => [
 PopupMenuItem<String>(
 enabled: false,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 displayName,
 style: TextStyle(
 fontWeight: FontWeight.w700,
 color: _primary,
 fontFamily: appFontFamily,
 ),
 ),
 if (user?.email != null && user!.email!.isNotEmpty)
 Text(
 user.email!,
 style: TextStyle(
 fontSize: 12,
 color: _onSurfaceVariant,
 fontFamily: appFontFamily,
 ),
 ),
 ],
 ),
 ),
 const PopupMenuDivider(),
 PopupMenuItem<String>(
 value: 'logout',
 child: Row(
 children: [
 Icon(Icons.logout, size: 18, color: _crimson),
 const SizedBox(width: 10),
 Text('Log Out',
 style: TextStyle(color: _crimson, fontFamily: appFontFamily)),
 ],
 ),
 ),
 ],
 onSelected: (value) {
 if (value == 'logout') {
 _handleLogout();
 }
 },
 );
 }

 Widget _secondaryCta({
 required String label,
 VoidCallback? onPressed,
 IconData? icon,
 }) {
 return OutlinedButton(
 onPressed: onPressed,
 style: OutlinedButton.styleFrom(
 foregroundColor: _primary,
 backgroundColor: Colors.white,
 side: BorderSide(color: _outlineVariant),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w600),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(label, style: TextStyle(fontFamily: appFontFamily)),
 const SizedBox(width: 8),
 Icon(icon ?? Icons.keyboard_arrow_right, size: 20),
 ],
 ),
 );
 }

 // ─── Action Buttons (Group Into Program + Project Logs) ─────────────────
 Widget _buildActionButtons(BuildContext context) {
 final screenWidth = MediaQuery.sizeOf(context).width;
 final useColumn = screenWidth < 500;

 final buttons = [
 CompactActionButton(
 label: 'Group Into A Program',
 subtitle: 'Select up to 3 projects to combine',
 icon: Icons.account_tree_outlined,
 accent: const Color(0xFF4338CA),
 onTap: () {
 _showGroupIntoProgramDialog(context);
 },
 ),
 CompactActionButton(
 label: 'Project Logs',
 subtitle: 'Activity across all projects',
 icon: Icons.fact_check_outlined,
 accent: const Color(0xFFFCD34D),
 onTap: () {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ProjectActivitiesLogScreen(),
 ),
 );
 },
 ),
 ];

 if (useColumn) {
 return Column(
 children: [
 for (int i = 0; i < buttons.length; i++) ...[
 if (i > 0) const SizedBox(height: 12),
 buttons[i],
 ],
 ],
 );
 }

 return Row(
 children: [
 for (int i = 0; i < buttons.length; i++) ...[
 if (i > 0) const SizedBox(width: 16),
 Expanded(child: buttons[i]),
 ],
 ],
 );
 }

 /// Dialog for grouping projects into a program (up to 3 projects).
 void _showGroupIntoProgramDialog(BuildContext context) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Group Into A Program: Select up to 3 projects to combine into a program.'),
 duration: Duration(seconds: 3),
 ),
 );
 }

 // ─── Hero Bento Grid ─────────────────────────────────────────────────────
  Widget _buildHeroBento(BuildContext context, {_ProgramMetrics? metrics}) {
    final width = MediaQuery.sizeOf(context).width;
    // Desktop (>1180): 3-column hero bento
    // Tablet (700-1180): 2-column (KPI + chart side-by-side, gauge below)
    // Mobile (<700): stacked vertically with tighter spacing
    if (width > 1180) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _budgetKpi(metrics ?? _emptyMetrics)),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: _plannedVsActual(metrics ?? _emptyMetrics)),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _progressGauge(metrics ?? _emptyMetrics)),
      ]);
    }
    if (width >= 700) {
      return Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _budgetKpi(metrics ?? _emptyMetrics)),
          const SizedBox(width: 24),
          Expanded(flex: 6, child: _plannedVsActual(metrics ?? _emptyMetrics)),
        ]),
        const SizedBox(height: 24),
        _progressGauge(metrics ?? _emptyMetrics),
      ]);
    }
    // Mobile: stacked with 16dp spacing (Material 3 compact)
    return Column(children: [
      _budgetKpi(metrics ?? _emptyMetrics),
      const SizedBox(height: 16),
      SizedBox(
          height: 180,
          child: _plannedVsActual(metrics ?? _emptyMetrics)),
      const SizedBox(height: 16),
      _progressGauge(metrics ?? _emptyMetrics),
    ]);
  }

 Widget _budgetKpi(_ProgramMetrics metrics) {
 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 Text('TOTAL BUDGET',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 Icon(Icons.payments, color: _onSurfaceVariant, size: 20),
 ]),
 const SizedBox(height: 16),
 Text(_formatBudget(metrics.totalBudget),
 style: TextStyle(
 color: _primary,
 fontSize: 30,
 fontWeight: FontWeight.w900,
 fontFamily: appFontFamily)),
 const SizedBox(height: 8),
 Row(children: [
 Icon(
 metrics.expendedPercent <= 0.68
 ? Icons.trending_down
 : Icons.trending_up,
 color: metrics.expendedPercent <= 0.68
 ? _emerald
 : _amber,
 size: 14),
 const SizedBox(width: 4),
 Text(
 metrics.expendedPercent <= 0.68
 ? '${((1 - metrics.expendedPercent) * 100).toStringAsFixed(1)}% below forecast'
 : '${((metrics.expendedPercent - 0.68) * 100).toStringAsFixed(1)}% above forecast',
 style: TextStyle(
 color: metrics.expendedPercent <= 0.68
 ? _emerald
 : _amber,
 fontSize: 14,
 fontFamily: appFontFamily),
 ),
 ]),
 ]),
 const SizedBox(height: 32),
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: metrics.expendedPercent.clamp(0, 1),
 backgroundColor: _surfaceHighest,
 valueColor: const AlwaysStoppedAnimation(_tertiary),
 minHeight: 6,
 ),
 ),
 const SizedBox(height: 8),
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 Text('EXPENDED: ${_formatBudget(metrics.expended)}',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.5,
 fontFamily: appFontFamily)),
 Text('${(metrics.expendedPercent * 100).round()}%',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)),
 ]),
 ]),
 ],
 ),
 );
 }

 Widget _plannedVsActual(_ProgramMetrics metrics) {
 final planned = [0.40, 0.55, 0.70, 0.85, 0.65, 0.90];
 final actual = [0.38, 0.52, 0.72, 0.88, 0.60, 0.95];
 final labels = ['Q1', 'Q2', 'Q3', 'Q4', 'FY24', 'FY25'];

 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 Text('PLANNED VS ACTUAL COST',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 Row(children: [
 _legendDot('Planned', _tertiary),
 const SizedBox(width: 12),
 _legendDot('Actual', _secondary),
 ]),
 ]),
 const SizedBox(height: 24),
 // Chart area — fixed height so bars can size as a fraction of it
 SizedBox(
 height: 160,
 child: LayoutBuilder(
 builder: (context, constraints) {
 final maxBarHeight = constraints.maxHeight - 4;
 return Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
 children: List.generate(planned.length, (i) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 // Planned bar
 Container(
 width: 12,
 decoration: BoxDecoration(
 color: _tertiary.withValues(alpha: 0.55),
 borderRadius: const BorderRadius.vertical(
 top: Radius.circular(2)),
 ),
 height: (maxBarHeight * planned[i])
 .clamp(2.0, maxBarHeight),
 ),
 const SizedBox(width: 2),
 // Actual bar
 Container(
 width: 12,
 decoration: BoxDecoration(
 color: _secondary,
 borderRadius: const BorderRadius.vertical(
 top: Radius.circular(2)),
 ),
 height: (maxBarHeight * actual[i])
 .clamp(2.0, maxBarHeight),
 ),
 ],
 );
 }),
 );
 },
 ),
 ),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
 children: labels
 .map((l) => Text(l,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)))
 .toList(),
 ),
 ],
 ),
 );
 }

 Widget _legendDot(String label, Color color) {
 return Row(children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
 const SizedBox(width: 4),
 Text(label,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 ]);
 }

 Widget _progressGauge(_ProgramMetrics metrics) {
 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 SizedBox(
 width: 120,
 height: 120,
 child: AnimatedBuilder(
 animation: _gaugeAnim,
 builder: (context, _) {
 final progressPct = (metrics.globalProgress * 100).clamp(0, 100);
 return CustomPaint(
 painter: _RadialGaugePainter(
 progress: _gaugeAnim.value * progressPct,
 fillColor: _tertiary,
 trackColor: _surfaceHighest,
 ),
 child: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text('${(_gaugeAnim.value * progressPct).round()}%',
 style: TextStyle(
 color: _primary,
 fontSize: 30,
 fontWeight: FontWeight.w900,
 fontFamily: appFontFamily)),
 Text('COMPLETED',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 ]),
 ),
 );
 },
 ),
 ),
 const SizedBox(height: 16),
 Text('GLOBAL PROGRESS',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 ],
 ),
 );
 }

 // ─── Main Grid ───────────────────────────────────────────────────────────
 Widget _buildMainGrid(BuildContext context, {_ProgramMetrics? metrics}) {
 final width = MediaQuery.sizeOf(context).width;
 // Desktop (>1180): 2-column main grid (8:4)
 // Tablet (700-1180): 1-column main grid (left column above, then right column)
 // Mobile (<700): stacked vertically
 if (width > 1180) {
 return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(flex: 8, child: _leftColumn(metrics: metrics)),
 const SizedBox(width: 24),
 Expanded(flex: 4, child: _rightColumn(metrics: metrics)),
 ]);
 }
 return Column(children: [
 _leftColumn(metrics: metrics),
 const SizedBox(height: 24),
 _rightColumn(metrics: metrics),
 ]);
 }

 // ─── Left Column: Health Matrix + Risks + Capacity ───────────────────────
 Widget _leftColumn({_ProgramMetrics? metrics}) {
 final width = MediaQuery.sizeOf(context).width;
 final sideBySide = width > 1180;
 if (sideBySide) {
 return Column(children: [
 _healthMatrix(metrics ?? _emptyMetrics),
 const SizedBox(height: 24),
 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(child: _criticalRisks()),
 const SizedBox(width: 24),
 Expanded(child: _resourceCapacity()),
 ]),
 ]);
 }
 return Column(children: [
 _healthMatrix(metrics ?? _emptyMetrics),
 const SizedBox(height: 24),
 _criticalRisks(),
 const SizedBox(height: 24),
 _resourceCapacity(),
 ]);
 }

 Widget _healthMatrix(_ProgramMetrics metrics) {
 // Use real project data from metrics. If no projects, show empty state.
 final projects = metrics.healthEntries;

 return _surfaceCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header
 Container(
 padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
 decoration: BoxDecoration(
 color: _surfaceHigh,
 border: Border(
 bottom: BorderSide(
 color: _outlineVariant.withValues(alpha: 0.6))),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Project Health Matrix',
 style: TextStyle(
 color: _primary,
 fontSize: 18,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Text('${projects.length} projects',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 12,
 fontFamily: appFontFamily)),
 ]),
 ),
 if (projects.isEmpty)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.assignment_outlined,
 color: _onSurfaceVariant, size: 32),
 const SizedBox(height: 8),
 Text('No projects in this program yet',
 style: TextStyle(
 color: _onSurfaceVariant, fontSize: 14)),
 const SizedBox(height: 4),
 Text(
 'Projects will appear here once they are added to a program.',
 style: TextStyle(
 color: _onSurfaceVariant, fontSize: 12),
 textAlign: TextAlign.center),
 ],
 ),
 ),
 )
 else
 // Table
 ...List.generate(projects.length, (i) {
 final p = projects[i];
 final altBg = i.isOdd ? _surface : Colors.white;
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 decoration: BoxDecoration(
 color: altBg,
 border: i < projects.length - 1
 ? Border(
 bottom: BorderSide(
 color: _outlineVariant.withValues(alpha: 0.5)))
 : null,
 ),
 child: Row(children: [
 // Project name
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(p.$1,
 style: TextStyle(
 color: _primary,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Text(p.$2,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 11,
 fontFamily: appFontFamily)),
 ])),
 // Status
 Expanded(
 flex: 2,
 child: Row(children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: p.$4,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: p.$4.withValues(alpha: 0.35),
 blurRadius: 8)
 ])),
 const SizedBox(width: 8),
 Text(p.$3,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 13,
 fontFamily: appFontFamily)),
 ])),
 // Budget trend sparkline
 Expanded(
 flex: 2,
 child: SizedBox(
 height: 24,
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: p.$5
 .map<Widget>((h) => Expanded(
 child: Container(
 margin: const EdgeInsets.only(right: 1),
 decoration: BoxDecoration(
 color: p.$4.withValues(
 alpha: h == 1.0 ? 1.0 : h * 0.6),
 borderRadius:
 BorderRadius.circular(1)),
 height: 24 * h)))
 .toList()),
 )),
 // Schedule
 Expanded(
 flex: 2,
 child: Text(p.$6,
 style: TextStyle(
 color: p.$8 ?? _onSurface,
 fontSize: 13,
 fontFamily: appFontFamily))),
 // Progress
 Expanded(
 child: Align(
 alignment: Alignment.centerRight,
 child: Text(p.$7,
 style: TextStyle(
 color: _primary,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)))),
 ]),
 );
 }),
 ],
 ),
 );
 }

 Widget _criticalRisks() {
 final risks = [
 (
 'Resource Burnout - Project Titan',
 'Key developers at 140% capacity for 6+ weeks.',
 _crimson,
 Icons.report,
 true
 ),
 (
 'Hardware Lead-Time Delay',
 'Global supply chain constraints impacting Phase 3.',
 _amber,
 Icons.warning,
 true
 ),
 (
 'Budget Re-allocation Needed',
 'Surplus from Project Phoenix could offset Data Lake.',
 _onSurfaceVariant,
 Icons.info,
 false
 ),
 ];

 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 Text('Critical Risks',
 style: TextStyle(
 color: _primary,
 fontSize: 18,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: _crimson.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(4)),
 child: Text('3 HIGH PRIORITY',
 style: TextStyle(
 color: _crimson,
 fontSize: 10,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 ),
 ]),
 const SizedBox(height: 24),
 ...risks.map((r) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: r.$3.withValues(alpha: r.$5 ? 0.45 : 0.25)),
 ),
 child:
 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Icon(r.$4, color: r.$3, size: 18),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(r.$1,
 style: TextStyle(
 color: _primary,
 fontSize: 13,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 const SizedBox(height: 4),
 Text(r.$2,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 11,
 fontFamily: appFontFamily)),
 ])),
 ]),
 )),
 ]),
 );
 }

 Widget _resourceCapacity() {
 final resources = [
 ('Engineering', 98, _crimson),
 ('DevOps / Cloud', 72, _emerald),
 ('Security Analysis', 85, _amber),
 ('UX / Design', 40, _emerald),
 ];

 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 Text('Resource Capacity',
 style: TextStyle(
 color: _primary,
 fontSize: 18,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Text('ACROSS PROJECTS',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 ]),
 const SizedBox(height: 24),
 ...resources.map((r) => Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(r.$1,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 11,
 fontFamily: appFontFamily)),
 Text('${r.$2}%',
 style: TextStyle(
 color: r.$3,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 ]),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: r.$2 / 100,
 backgroundColor: _surfaceHighest,
 valueColor: AlwaysStoppedAnimation(r.$3),
 minHeight: 6,
 ),
 ),
 ]),
 )),
 ]),
 );
 }

 // ─── Right Column: Escalations + Activity + Visual Context ───────────────
 Widget _rightColumn({_ProgramMetrics? metrics}) {
 return Column(children: [
 _escalationSummary(metrics ?? _emptyMetrics),
 const SizedBox(height: 24),
 _recentActivity(),
 const SizedBox(height: 24),
 _visualContext(),
 ]);
 }

 Widget _escalationSummary(_ProgramMetrics metrics) {
 return _surfaceCard(
 leftBorder: _amber,
 padding: const EdgeInsets.all(24),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(children: [
 Icon(Icons.priority_high, color: _amber, size: 18),
 const SizedBox(width: 8),
 Text('ESCALATION SUMMARY',
 style: TextStyle(
 color: _amber,
 fontSize: 13,
 fontWeight: FontWeight.bold,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 ]),
 const SizedBox(height: 16),
 // Escalation 1
 Container(
 padding: const EdgeInsets.all(16),
 margin: const EdgeInsets.only(bottom: 12),
 decoration: BoxDecoration(
 color: _surfaceHigh,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: _outlineVariant.withValues(alpha: 0.6)),
 ),
 child:
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text('OPEN APPROVAL',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 const SizedBox(height: 4),
 Text(
 metrics.projectCount == 0
 ? 'No projects require approval.'
 : '${metrics.healthEntries.where((e) => e.$3 == 'At Risk' || e.$3 == 'Critical').length} project(s) need attention — review status and budget.',
 style: TextStyle(
 color: _primary, fontSize: 13, fontFamily: appFontFamily),
 ),
 const SizedBox(height: 12),
 GestureDetector(
 onTap: () {},
 child: Row(children: [
 Text('REVIEW DETAILS',
 style: TextStyle(
 color: _tertiaryContainer,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Icon(Icons.arrow_forward, color: _tertiaryContainer, size: 12),
 ]),
 ),
 ]),
 ),
 // Escalation 2
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: _surfaceHigh,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: _outlineVariant.withValues(alpha: 0.6)),
 ),
 child:
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text('SCHEDULE REVISION',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 const SizedBox(height: 4),
 Text(
 'Baseline shift requested for CyberShield v4 due to legislative changes.',
 style: TextStyle(
 color: _primary, fontSize: 13, fontFamily: appFontFamily)),
 const SizedBox(height: 12),
 GestureDetector(
 onTap: () {},
 child: Row(children: [
 Text('REVIEW DETAILS',
 style: TextStyle(
 color: _tertiaryContainer,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 Icon(Icons.arrow_forward, color: _tertiaryContainer, size: 12),
 ]),
 ),
 ]),
 ),
 ]),
 );
 }

 Widget _recentActivity() {
 final activities = [
 (
 'M. Chen pushed a budget update',
 'Project Phoenix • 22 mins ago',
 _primary
 ),
 (
 'Milestone Reached: Q3 Cloud Gate',
 'Data Lake 2.0 • 2 hours ago',
 _emerald
 ),
 ('Risk Level Updated to Medium', 'Edge Connect • 5 hours ago', _amber),
 (
 'S. Rossi added a comment',
 'Resource Allocation • Yesterday',
 _primary
 ),
 ];

 return _surfaceCard(
 padding: const EdgeInsets.all(24),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text('RECENT ACTIVITY',
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 13,
 fontWeight: FontWeight.bold,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 const SizedBox(height: 24),
 // Timeline — each row is a self-contained horizontal layout
 // (dot + connector on the left, text on the right). No Positioned
 // widgets, so no Stack-constraint issues.
 Column(
 children: List.generate(activities.length, (i) {
 final a = activities[i];
 final isLast = i == activities.length - 1;
 return IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Timeline gutter: dot + vertical line below
 SizedBox(
 width: 16,
 child: Column(
 children: [
 Container(
 width: 16,
 height: 16,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(
 color: _outlineVariant.withValues(alpha: 0.8)),
 ),
 child: Center(
 child: Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: a.$3, shape: BoxShape.circle),
 ),
 ),
 ),
 if (!isLast)
 Expanded(
 child: Container(
 width: 1,
 color: _outlineVariant.withValues(alpha: 0.7),
 margin: const EdgeInsets.only(top: 4),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 // Text content
 Expanded(
 child: Padding(
 padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(a.$1,
 style: TextStyle(
 color: _primary,
 fontSize: 12,
 fontFamily: appFontFamily)),
 const SizedBox(height: 2),
 Text(a.$2,
 style: TextStyle(
 color: _onSurfaceVariant,
 fontSize: 10,
 fontFamily: appFontFamily)),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }),
 ),
 ]),
 );
 }

 Widget _visualContext() {
 return _surfaceCard(
 child: Container(
 height: 192,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(12),
 gradient: LinearGradient(
 begin: Alignment.bottomCenter,
 end: Alignment.topCenter,
 colors: [Colors.white, _surfaceHigh],
 ),
 ),
 child: Stack(children: [
 // Light gradient overlay
 Positioned.fill(
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(12),
 gradient: LinearGradient(
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 colors: [
 _surfaceHigh.withValues(alpha: 0.4),
 Colors.white.withValues(alpha: 0.8)
 ])))),
 // City silhouette shapes (light gray)
 Positioned(
 bottom: 0,
 left: 0,
 right: 0,
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
 children: [
 _cityBuilding(
 40, 60, _surfaceHighest.withValues(alpha: 0.7)),
 _cityBuilding(
 30, 80, _surfaceHighest.withValues(alpha: 0.55)),
 _cityBuilding(
 50, 100, _surfaceHighest.withValues(alpha: 0.8)),
 _cityBuilding(
 35, 70, _surfaceHighest.withValues(alpha: 0.6)),
 _cityBuilding(
 45, 90, _surfaceHighest.withValues(alpha: 0.75)),
 _cityBuilding(
 30, 50, _surfaceHighest.withValues(alpha: 0.5)),
 ])),
 // Glow spots
 Positioned(
 top: 20,
 right: 30,
 child: Container(
 width: 60,
 height: 60,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _tertiaryContainer.withValues(alpha: 0.25),
 boxShadow: [
 BoxShadow(
 color: _tertiaryContainer.withValues(alpha: 0.3),
 blurRadius: 30)
 ]))),
 Positioned(
 top: 40,
 left: 40,
 child: Container(
 width: 50,
 height: 50,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _secondary.withValues(alpha: 0.18),
 boxShadow: [
 BoxShadow(
 color: _secondary.withValues(alpha: 0.22),
 blurRadius: 25)
 ]))),
 // Label
 Positioned(
 bottom: 16,
 left: 16,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('VISUAL CONTEXT',
 style: TextStyle(
 color: _tertiaryContainer,
 fontSize: 10,
 fontWeight: FontWeight.bold,
 letterSpacing: 2,
 fontFamily: appFontFamily)),
 Text('Site A-01 Progress',
 style: TextStyle(
 color: _primary,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 fontFamily: appFontFamily)),
 ])),
 ]),
 ),
 );
 }

 Widget _cityBuilding(double w, double h, Color c) {
 return Container(
 width: w,
 height: h,
 decoration: BoxDecoration(
 color: c,
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(2), topRight: Radius.circular(2))));
 }
}

// ─── Radial Gauge Painter ──────────────────────────────────────────────────
class _RadialGaugePainter extends CustomPainter {
 final double progress; // 0-100
 final Color fillColor;
 final Color trackColor;

 _RadialGaugePainter({
 required this.progress,
 required this.fillColor,
 required this.trackColor,
 });

 @override
 void paint(Canvas canvas, Size size) {
 final center = Offset(size.width / 2, size.height / 2);
 final radius = size.width / 2;
 const strokeWidth = 10.0;

 // Track (full circle)
 canvas.drawCircle(
 center,
 radius - strokeWidth / 2,
 Paint()
 ..color = trackColor
 ..style = PaintingStyle.stroke
 ..strokeWidth = strokeWidth,
 );

 // Progress arc
 final sweepAngle = (progress / 100) * 2 * 3.14159265;
 canvas.drawArc(
 Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
 -3.14159265 / 2, // start from top
 sweepAngle,
 false,
 Paint()
 ..color = fillColor
 ..style = PaintingStyle.stroke
 ..strokeWidth = strokeWidth
 ..strokeCap = StrokeCap.round,
 );

 // Inner radial gradient effect (very subtle on light theme)
 final innerPaint = Paint()
 ..shader = RadialGradient(
 colors: [fillColor.withValues(alpha: 0.06), Colors.transparent],
 radius: 0.85,
 ).createShader(
 Rect.fromCircle(center: center, radius: radius - strokeWidth));

 canvas.drawCircle(center, radius - strokeWidth, innerPaint);
 }

 @override
 bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) =>
 oldDelegate.progress != progress;
}


// ═══════════════════════════════════════════════════════════════════════════
// _ProgramMetrics — real data computed from Firestore projects + programs
// ═══════════════════════════════════════════════════════════════════════════

class _ProgramMetrics {
 final String programName;
 final String programSubtitle;
 final double totalBudget;
 final double expended;
 final double expendedPercent;
 final double globalProgress;
 final int projectCount;
 // Positional record type (tuple) — matches the table's $1, $2, $3... accessors
 // (name, subtitle, status, statusColor, sparkline, schedule, progressPct, scheduleColor)
 final List<(String, String, String, Color, List<double>, String, String, Color?)> healthEntries;
 final List<ProjectRecord> projects;

 const _ProgramMetrics({
 required this.programName,
 required this.programSubtitle,
 required this.totalBudget,
 required this.expended,
 required this.expendedPercent,
 required this.globalProgress,
 required this.projectCount,
 required this.healthEntries,
 required this.projects,
 });
}
