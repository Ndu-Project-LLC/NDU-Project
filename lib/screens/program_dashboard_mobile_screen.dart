import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/program_model.dart';
import '../models/portfolio_model.dart';
import '../widgets/dashboard_bottom_nav_bar.dart';
import '../services/navigation_context_service.dart';
import '../services/portfolio_service.dart';
import '../services/program_service.dart';
import '../services/project_service.dart';
import '../services/project_navigation_service.dart';
import '../services/navigation_context_service.dart';
import '../utils/navigation_route_resolver.dart';
import '../providers/project_data_provider.dart';
import '../screens/initiation_phase_screen.dart';
import '../screens/portfolio_dashboard_screen.dart';
import '../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Data models (kept private to this file, same as existing screen)
// ---------------------------------------------------------------------------

class _ProjectInfo {
 const _ProjectInfo({
 required this.title,
 required this.code,
 required this.stage,
 required this.stageColor,
 required this.priority,
 required this.priorityColor,
 required this.owner,
 required this.status,
 required this.progress,
 });

 final String title;
 final String code;
 final String stage;
 final Color stageColor;
 final String priority;
 final Color priorityColor;
 final String owner;
 final String status;
 final double progress; // 0..1
}

class _InterfaceItem {
 const _InterfaceItem({
 required this.title,
 required this.appliesTo,
 required this.tags,
 required this.riskLabel,
 required this.riskColor,
 });

 final String title;
 final String appliesTo;
 final List<String> tags;
 final String riskLabel;
 final Color riskColor;
}

class _ProgramAction {
 const _ProgramAction({
 required this.title,
 required this.description,
 required this.appliesTo,
 required this.isOn,
 this.badgeColor,
 this.badgeTextColor,
 });

 final String title;
 final String description;
 final String appliesTo;
 final bool isOn;
 final Color? badgeColor;
 final Color? badgeTextColor;
}

class _RollupSlice {
 const _RollupSlice({
 required this.label,
 required this.amount,
 required this.percent,
 required this.color,
 });

 final String label;
 final double amount;
 final double percent;
 final Color color;
}

class _ScheduleItem {
 const _ScheduleItem({
 required this.label,
 required this.startMonths,
 required this.endMonths,
 required this.color,
 });

 final String label;
 final double startMonths;
 final double endMonths;
 final Color color;
}

// Demo data constants (same as existing screen)
const _demoInterfaces = [
 _InterfaceItem(
 title: 'Terminal access windows',
 appliesTo: 'Applies to all projects',
 tags: ['Ops coordination', 'Customer impact'],
 riskLabel: 'Medium risk',
 riskColor: Color(0xFFEA580C),
 ),
 _InterfaceItem(
 title: 'Control room cutover',
 appliesTo: 'Applies to PRJ-001, PRJ-002',
 tags: ['Safety & SHE/R'],
 riskLabel: 'High risk',
 riskColor: Color(0xFFEF4444),
 ),
];

const _demoSlices = [
 _RollupSlice(
 label: 'Goal 1',
 amount: 2.1,
 percent: 0.40,
 color: Color(0xFF22C55E),
 ),
 _RollupSlice(
 label: 'Goal 2',
 amount: 1.9,
 percent: 0.35,
 color: Color(0xFF3B82F6),
 ),
 _RollupSlice(
 label: 'Goal 3',
 amount: 1.4,
 percent: 0.25,
 color: Color(0xFFF97316),
 ),
];

// ---------------------------------------------------------------------------
// Main screen widget
// ---------------------------------------------------------------------------

class ProgramDashboardMobileScreen extends StatefulWidget {
 const ProgramDashboardMobileScreen({super.key, this.programId});

 final String? programId;

 @override
 State<ProgramDashboardMobileScreen> createState() =>
 _ProgramDashboardMobileScreenState();
}

class _ProgramDashboardMobileScreenState
 extends State<ProgramDashboardMobileScreen> {
 // ── State variables (preserved from existing screen) ──
 ProgramModel? _currentProgram;
 List<ProjectRecord> _projects = [];
 bool _isLoading = true;
 String? _error;
 StreamSubscription<List<ProgramModel>>? _programSubscription;
 StreamSubscription<List<ProjectRecord>>? _projectSubscription;
 StreamSubscription<List<ProjectRecord>>? _allProjectsSubscription;
 StreamSubscription<List<PortfolioModel>>? _portfolioSubscription;
 int _totalProjects = 0;
 int _basicProjectCount = 0;
 int _programCount = 0;
 int _portfolioCount = 0;

 // ── Toggle state for program actions ──
 bool _gateApprovalsOn = true;
 bool _sharedRiskOn = true;
 bool _commonChangeControlOn = false;

 // ── Lifecycle (preserved) ──

 @override
 void initState() {
 super.initState();
 _loadProgramData();
 }

 @override
 void dispose() {
 _programSubscription?.cancel();
 _projectSubscription?.cancel();
 _allProjectsSubscription?.cancel();
 _portfolioSubscription?.cancel();
 super.dispose();
 }

 // ── Backend logic (preserved from existing screen) ──

 Future<void> _loadProgramData() async {
 final user = FirebaseAuth.instance.currentUser;
 _allProjectsSubscription?.cancel();
 _portfolioSubscription?.cancel();
 if (user == null) {
 setState(() {
 _isLoading = false;
 _error = 'Please sign in to view program data';
 _currentProgram = null;
 _projects = [];
 _programCount = 0;
 _totalProjects = 0;
 _basicProjectCount = 0;
 _portfolioCount = 0;
 });
 return;
 }

 _allProjectsSubscription =
 ProjectService.streamProjects(ownerId: user.uid, limit: 100).listen(
 (projects) {
 if (!mounted) return;
 final basicCount =
 projects.where((project) => project.isBasicPlanProject).length;
 setState(() {
 _totalProjects = projects.length;
 _basicProjectCount = basicCount;
 });
 },
 onError: (error) {
 debugPrint('Error streaming all projects: $error');
 },
 );

 _portfolioSubscription =
 PortfolioService.streamPortfolios(ownerId: user.uid).listen(
 (items) {
 if (!mounted) return;
 setState(() {
 _portfolioCount = items.length;
 });
 },
 onError: (error) {
 debugPrint('Error streaming portfolios: $error');
 },
 );

 try {
 _programSubscription?.cancel();
 _programSubscription =
 ProgramService.streamPrograms(ownerId: user.uid).listen(
 (programs) {
 if (!mounted) return;

 if (programs.isEmpty) {
 _projectSubscription?.cancel();
 setState(() {
 _isLoading = false;
 _currentProgram = null;
 _projects = [];
 _error = null;
 _programCount = 0;
 });
 return;
 }

 final programCount = programs.length;
 final program = widget.programId != null
 ? programs.firstWhere(
 (p) => p.id == widget.programId,
 orElse: () => programs.first,
 )
 : programs.first;
 final programChanged = _currentProgram?.id != program.id;

 _projectSubscription?.cancel();
 if (program.projectIds.isNotEmpty) {
 if (programChanged) {
 setState(() {
 _programCount = programCount;
 _currentProgram = program;
 _projects = [];
 _isLoading = true;
 _error = null;
 });
 } else {
 setState(() {
 _programCount = programCount;
 _currentProgram = program;
 _error = null;
 });
 }

 _projectSubscription =
 ProjectService.streamProjectsByIds(program.projectIds).listen(
 (projects) {
 if (!mounted) return;
 setState(() {
 _projects = projects;
 _isLoading = false;
 _error = null;
 });
 },
 onError: (e) {
 debugPrint('Error streaming projects: $e');
 if (!mounted) return;
 setState(() {
 _isLoading = false;
 _error = 'Failed to load projects';
 });
 },
 );
 } else {
 setState(() {
 _programCount = programCount;
 _currentProgram = program;
 _projects = [];
 _isLoading = false;
 _error = null;
 });
 }
 },
 onError: (e) {
 debugPrint('Error streaming programs: $e');
 if (!mounted) return;
 setState(() {
 _isLoading = false;
 _error = 'Failed to load program data';
 _programCount = 0;
 });
 },
 );
 } catch (e) {
 debugPrint('Error loading program data: $e');
 if (mounted) {
 setState(() {
 _isLoading = false;
 _error = 'An error occurred while loading data';
 _programCount = 0;
 });
 }
 }
 }

 // ── Project info converter (preserved + mobile progress) ──

 _ProjectInfo _toProjectInfo(ProjectRecord record, int index) {
 Color stageColor;
 switch (record.status.toLowerCase()) {
 case 'initiation':
 stageColor = const Color(0xFF9747FF);
 break;
 case 'front-end planning':
 case 'planning':
 stageColor = const Color(0xFF0B7AE4);
 break;
 case 'execution':
 case 'in progress':
 stageColor = const Color(0xFF17A673);
 break;
 case 'close-out':
 case 'complete':
 stageColor = const Color(0xFF565970);
 break;
 default:
 stageColor = const Color(0xFF0B7AE4);
 }

 final priorityColors = [
 const Color(0xFFEA580C), // P1 - Primary driver (orange)
 const Color(0xFF2563EB), // P2 - Dependent (blue)
 const Color(0xFF16A34A), // P3 - Support (green)
 ];
 final priorityLabels = [
 'P1 - Primary driver',
 'P2 - Dependent',
 'P3 - Support',
 ];

 String category = 'General';
 if (record.tags.isNotEmpty) {
 category = record.tags.first;
 }

 final projectCode =
 'PRJ-${(index + 1).toString().padLeft(3, '0')}';

 // Assign demo progress based on index
 final progressValues = [0.30, 0.60, 0.15];

 return _ProjectInfo(
 title: record.name.isEmpty ? 'Untitled Project' : record.name,
 code: projectCode,
 stage: record.status.isEmpty ? 'Initiation' : record.status,
 stageColor: stageColor,
 priority: priorityLabels[index.clamp(0, 2)],
 priorityColor: priorityColors[index.clamp(0, 2)],
 owner: record.ownerName.isEmpty ? 'owner@company.com' : record.ownerName,
 status: 'Open',
 progress: progressValues[index.clamp(0, 2)],
 );
 }

 // ── Open project (preserved navigation logic) ──

 Future<void> _openProject(String projectId) async {
 final rootNavigator = Navigator.of(context, rootNavigator: true);
 var loadingDialogVisible = false;

 void dismissLoadingDialog() {
 if (!loadingDialogVisible) return;
 if (rootNavigator.mounted) {
 rootNavigator.pop();
 }
 loadingDialogVisible = false;
 }

 showDialog(
 context: context,
 barrierDismissible: false,
 useRootNavigator: true,
 builder: (context) => const Center(
 child: Card(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircularProgressIndicator(strokeWidth: 3),
 SizedBox(height: 16),
 Text(
 'Loading project...',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 ),
 ),
 ).whenComplete(() {
 loadingDialogVisible = false;
 });
 loadingDialogVisible = true;

 try {
 final provider = ProjectDataInherited.read(context);
 debugPrint('Calling loadFromFirebase for project: $projectId');

 final success = await provider
 .loadFromFirebase(projectId)
 .timeout(const Duration(seconds: 35));

 debugPrint('Load result: $success, error: ${provider.lastError}');

 if (!context.mounted) return;

 dismissLoadingDialog();

 if (success) {
 final projectRecord =
 await ProjectService.getProjectById(projectId);
 final checkpointRoute =
 projectRecord?.checkpointRoute.isNotEmpty == true
 ? projectRecord!.checkpointRoute
 : await ProjectNavigationService.instance
 .getLastPage(projectId);
 debugPrint(
 'Project loaded successfully, navigating to checkpoint: $checkpointRoute');

 if (!context.mounted) return;

 final screen = NavigationRouteResolver.resolveCheckpointToScreen(
 checkpointRoute.isEmpty ? 'initiation' : checkpointRoute,
 context,
 );

 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => screen ?? const InitiationPhaseScreen()),
 );
 } else {
 debugPrint('Failed to load project: ${provider.lastError}');
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Failed to load project: ${provider.lastError ?? "Unknown error"}')),
 );
 }
 }
 } on TimeoutException catch (e) {
 debugPrint('Error loading project: $e');
 if (context.mounted) {
 dismissLoadingDialog();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Project load timed out. Please retry in a moment.')),
 );
 }
 } catch (e) {
 debugPrint('Error loading project: $e');
 if (context.mounted) {
 dismissLoadingDialog();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error loading project: $e')),
 );
 }
 } finally {
 if (context.mounted) {
 dismissLoadingDialog();
 }
 }
 }

 // ── Build ──

 @override
 Widget build(BuildContext context) {
 NavigationContextService.instance
 .setLastClientDashboard(AppRoutes.programDashboard);

 const background = Color(0xFFF9FAFB);
 final showEmptyState =
 !_isLoading && _error == null && _currentProgram == null;

 return Scaffold(
 backgroundColor: background,
 body: Stack(
 children: [
 SafeArea(
 bottom: false,
 child: Column(
 children: [
 // ── Sticky top nav ──
 _TopNavBar(programName: _currentProgram?.name),
 // ── Scrollable content ──
 Expanded(
 child: showEmptyState
 ? _EmptyStateView(onCreate: () {
 context.go('/${AppRoutes.dashboard}');
 })
 : SingleChildScrollView(
 padding: const EdgeInsets.only(bottom: 100),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Page summary
 const _PageSummary(),
 const SizedBox(height: 20),
 // Stats horizontal scroll
 _StatsScrollRow(
 basicProjectCount: _basicProjectCount,
 totalProjects: _totalProjects,
 programCount: _programCount,
 ),
 const SizedBox(height: 20),
 // Status indicators
 _StatusIndicators(
 projectCount: _projects.length),
 const SizedBox(height: 24),
 // Projects
 _ProjectsSection(
 projects: _projects,
 isLoading: _isLoading,
 error: _error,
 toProjectInfo: _toProjectInfo,
 onOpenProject: _openProject,
 ),
 const SizedBox(height: 20),
 // Program-level actions
 _ProgramActionsSection(
 gateApprovalsOn: _gateApprovalsOn,
 sharedRiskOn: _sharedRiskOn,
 commonChangeControlOn:
 _commonChangeControlOn,
 onGateApprovalsChanged: (v) =>
 setState(() => _gateApprovalsOn = v),
 onSharedRiskChanged: (v) =>
 setState(() => _sharedRiskOn = v),
 onCommonChangeControlChanged: (v) =>
 setState(
 () => _commonChangeControlOn = v),
 ),
 const SizedBox(height: 20),
 // Interface management
 const _InterfaceSection(),
 const SizedBox(height: 20),
 // Rolled up estimates
 const _RollupSection(),
 const SizedBox(height: 20),
 // ── Roll-up CTA (moved inline) ──
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC800),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
 elevation: 4,
 shadowColor: const Color(0xFFFFC800).withValues(alpha: 0.4),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: const [
 Icon(Icons.arrow_upward, size: 18),
 SizedBox(width: 8),
 Text('ROLL UP TO PORTFOLIO'),
 ],
 ),
 ),
 ),
 ),
 const SizedBox(height: 32),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 // ── Fixed bottom navbar ──
 Positioned(
 left: 0,
 right: 0,
 bottom: 0,
 child: DashboardBottomNavBar(
 currentIndex: 1,
 onNavigate: (index) {
 if (index == 0) {
 Navigator.pop(context);
 } else if (index == 2) {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
 );
 } else if (index == 3) {
 context.go('/${AppRoutes.settings}?from=${AppRoutes.dashboard}');
 }
 },
 ),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// TOP NAVIGATION BAR
// ===========================================================================

class _TopNavBar extends StatelessWidget {
 const _TopNavBar({this.programName});

 final String? programName;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: const BoxDecoration(
 color: Colors.white,
 border: Border(
 bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
 ),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(
 children: [
 // NP Logo square
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFF111827),
 borderRadius: BorderRadius.circular(6),
 ),
 alignment: Alignment.center,
 child: const Text(
 'NP',
 style: TextStyle(
 color: Color(0xFFFFC800),
 fontSize: 14,
 fontWeight: FontWeight.w800,
 letterSpacing: 0.5,
 ),
 ),
 ),
 const SizedBox(width: 10),
 // Title / subtitle
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'NDUPROJECT',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 letterSpacing: 0.8,
 ),
 ),
 Text(
 'INTELLIGENCE',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF6B7280),
 letterSpacing: 1.2,
 ),
 ),
 ],
 ),
 ),
 // Search icon
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.search, size: 20, color: Color(0xFF374151)),
 ),
 const SizedBox(width: 8),
 // Notification bell with red dot
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 const Icon(Icons.notifications_none, size: 20,
 color: Color(0xFF374151)),
 Positioned(
 top: 7,
 right: 7,
 child: Container(
 width: 8,
 height: 8,
 decoration: const BoxDecoration(
 color: Color(0xFFEF4444),
 shape: BoxShape.circle,
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 // User avatar
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFE0E7FF),
 borderRadius: BorderRadius.circular(18),
 ),
 child: const Icon(Icons.person, size: 20, color: Color(0xFF4F46E5)),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// PAGE SUMMARY
// ===========================================================================

class _PageSummary extends StatelessWidget {
 const _PageSummary();

 @override
 Widget build(BuildContext context) {
 return Container(
 color: Colors.white,
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Breadcrumb with arrow
 Row(
 children: [
 const Icon(Icons.arrow_back_ios, size: 14,
 color: Color(0xFF3B82F6)),
 const SizedBox(width: 4),
 Text(
 'Program workspace overview',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF3B82F6),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Title
 const Text(
 'Data Intelligence',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 height: 1.2,
 ),
 ),
 const SizedBox(height: 8),
 // Description
 const Text(
 'Coordinate up to three related projects with shared outcomes. Manage interfaces, prioritize delivery, and roll estimates and risk into a single program view before promoting to a portfolio.',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 height: 1.55,
 ),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// STATS HORIZONTAL SCROLL
// ===========================================================================

class _StatsScrollRow extends StatelessWidget {
 const _StatsScrollRow({
 required this.basicProjectCount,
 required this.totalProjects,
 required this.programCount,
 });

 final int basicProjectCount;
 final int totalProjects;
 final int programCount;

 @override
 Widget build(BuildContext context) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Row(
 children: [
 _StatCard(
 icon: Icons.folder_special_outlined,
 iconBgColor: const Color(0xFFD1FAE5),
 iconColor: const Color(0xFF059669),
 value: '$basicProjectCount',
 label: 'REGULAR PROJECTS',
 ),
 const SizedBox(width: 12),
 _StatCard(
 icon: Icons.folder_open_outlined,
 iconBgColor: const Color(0xFFDBEAFE),
 iconColor: const Color(0xFF2563EB),
 value: '$totalProjects',
 label: 'PROJECTS',
 ),
 const SizedBox(width: 12),
 _StatCard(
 icon: Icons.layers_outlined,
 iconBgColor: const Color(0xFFEDE9FE),
 iconColor: const Color(0xFF7C3AED),
 value: '$programCount',
 label: 'PROGRAMS',
 ),
 ],
 ),
 );
 }
}

class _StatCard extends StatelessWidget {
 const _StatCard({
 required this.icon,
 required this.iconBgColor,
 required this.iconColor,
 required this.value,
 required this.label,
 });

 final IconData icon;
 final Color iconBgColor;
 final Color iconColor;
 final String value;
 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 130,
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: iconBgColor,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, size: 20, color: iconColor),
 ),
 const SizedBox(height: 12),
 Text(
 value,
 style: const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 2),
 Text(
 label,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 letterSpacing: 0.5,
 ),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// STATUS INDICATORS
// ===========================================================================

class _StatusIndicators extends StatelessWidget {
 const _StatusIndicators({required this.projectCount});

 final int projectCount;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 _StatusPill(
 icon: Icons.check_circle,
 text: '$projectCount OF 3 PROJECTS IN THIS PROGRAM',
 bgColor: const Color(0xFFDBEAFE),
 textColor: const Color(0xFF1D4ED8),
 ),
 _StatusPill(
 icon: Icons.check_circle,
 text: 'ROLLED UP ESTIMATE: \$5.4M',
 bgColor: const Color(0xFFDCFCE7),
 textColor: const Color(0xFF15803D),
 ),
 ],
 ),
 );
 }
}

class _StatusPill extends StatelessWidget {
 const _StatusPill({
 required this.icon,
 required this.text,
 required this.bgColor,
 required this.textColor,
 });

 final IconData icon;
 final String text;
 final Color bgColor;
 final Color textColor;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: bgColor,
 borderRadius: BorderRadius.circular(20),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 16, color: textColor),
 const SizedBox(width: 6),
 Text(
 text,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: textColor,
 letterSpacing: 0.3,
 ),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// PROJECTS SECTION
// ===========================================================================

class _ProjectsSection extends StatelessWidget {
 const _ProjectsSection({
 required this.projects,
 required this.isLoading,
 this.error,
 required this.toProjectInfo,
 required this.onOpenProject,
 });

 final List<ProjectRecord> projects;
 final bool isLoading;
 final String? error;
 final _ProjectInfo Function(ProjectRecord, int) toProjectInfo;
 final void Function(String projectId) onOpenProject;

 @override
 Widget build(BuildContext context) {
 final remainingSlots = 3 - projects.length;

 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title row
 Row(
 children: [
 const Expanded(
 child: Text(
 'PROJECTS IN THIS PROGRAM',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF374151),
 letterSpacing: 0.5,
 ),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Text(
 'Up to 3 related',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),

 // Loading / Error / Empty state
 if (isLoading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: CircularProgressIndicator(),
 ),
 )
 else if (error != null)
 Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Text(
 error!,
 style: const TextStyle(color: Colors.red),
 ),
 ),
 )
 else if (projects.isEmpty)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: Text(
 'No projects in this program yet. Add a project to get started.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 ),
 )
 else
 ...List.generate(projects.length, (i) {
 final info = toProjectInfo(projects[i], i);
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _ProjectCard(
 info: info,
 onTap: () => onOpenProject(projects[i].id),
 ),
 );
 }),

 // Max projects notice
 if (remainingSlots <= 0 && projects.isNotEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF9C3),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Expanded(
 child: Text(
 'This program has reached the maximum of 3 projects.',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF92400E),
 ),
 ),
 ),
 const SizedBox(width: 8),
 TextButton(
 onPressed: () {},
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 4),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 child: const Text(
 'View all',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF2563EB),
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
}

class _ProjectCard extends StatelessWidget {
 const _ProjectCard({required this.info, required this.onTap});

 final _ProjectInfo info;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title row
 Row(
 children: [
 Expanded(
 child: Text(
 info.title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 const SizedBox(width: 8),
 // OPEN button
 GestureDetector(
 onTap: onTap,
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFF2563EB),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Text(
 'OPEN',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 letterSpacing: 0.5,
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 // Code + Category
 Text(
 '${info.code} · ${info.stage}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: 12),
 // Progress bar
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: info.progress,
 backgroundColor: Colors.white,
 valueColor: AlwaysStoppedAnimation<Color>(info.stageColor),
 minHeight: 6,
 ),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 Text(
 '${(info.progress * 100).round()}%',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: info.stageColor,
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 // Priority badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: info.priorityColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 info.priority,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: info.priorityColor,
 ),
 ),
 ),
 const SizedBox(height: 8),
 // Owner
 Row(
 children: [
 Icon(Icons.person_outline, size: 14,
 color: const Color(0xFF9CA3AF)),
 const SizedBox(width: 4),
 Text(
 info.owner,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// PROGRAM-LEVEL ACTIONS
// ===========================================================================

class _ProgramActionsSection extends StatelessWidget {
 const _ProgramActionsSection({
 required this.gateApprovalsOn,
 required this.sharedRiskOn,
 required this.commonChangeControlOn,
 required this.onGateApprovalsChanged,
 required this.onSharedRiskChanged,
 required this.onCommonChangeControlChanged,
 });

 final bool gateApprovalsOn;
 final bool sharedRiskOn;
 final bool commonChangeControlOn;
 final ValueChanged<bool> onGateApprovalsChanged;
 final ValueChanged<bool> onSharedRiskChanged;
 final ValueChanged<bool> onCommonChangeControlChanged;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'PROGRAM-LEVEL ACTIONS',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF374151),
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 12),
 Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 children: [
 _ActionToggleRow(
 title: 'Gate approvals',
 subtitle:
 'Use the same approval path for all projects in this program.',
 isOn: gateApprovalsOn,
 badgeText: 'Applies to all',
 badgeBgColor: const Color(0xFFDBEAFE),
 badgeTextColor: const Color(0xFF1D4ED8),
 onChanged: onGateApprovalsChanged,
 ),
 const Divider(height: 1, color: Color(0xFFF3F4F6)),
 _ActionToggleRow(
 title: 'Shared risk register',
 subtitle:
 'Surface program-level risks and mitigation once across all work.',
 isOn: sharedRiskOn,
 badgeText: 'Applies to all',
 badgeBgColor: const Color(0xFFDBEAFE),
 badgeTextColor: const Color(0xFF1D4ED8),
 onChanged: onSharedRiskChanged,
 ),
 const Divider(height: 1, color: Color(0xFFF3F4F6)),
 _ActionToggleRow(
 title: 'Common change control',
 subtitle:
 'Route change requests through a single program board.',
 isOn: commonChangeControlOn,
 badgeText: 'Project-specific',
 badgeBgColor: const Color(0xFFF3F4F6),
 badgeTextColor: const Color(0xFF6B7280),
 onChanged: onCommonChangeControlChanged,
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 // Apply selections button
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: () {},
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF111827),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700, fontSize: 13),
 elevation: 0,
 ),
 child: const Text('APPLY SELECTIONS'),
 ),
 ),
 ],
 ),
 );
 }
}

class _ActionToggleRow extends StatelessWidget {
 const _ActionToggleRow({
 required this.title,
 required this.subtitle,
 required this.isOn,
 required this.badgeText,
 required this.badgeBgColor,
 required this.badgeTextColor,
 required this.onChanged,
 });

 final String title;
 final String subtitle;
 final bool isOn;
 final String badgeText;
 final Color badgeBgColor;
 final Color badgeTextColor;
 final ValueChanged<bool> onChanged;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Switch.adaptive(
 value: isOn,
 onChanged: onChanged,
 activeColor: const Color(0xFF2563EB),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 2),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF9CA3AF),
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: badgeBgColor,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 badgeText,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: badgeTextColor,
 ),
 ),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// INTERFACE MANAGEMENT SECTION
// ===========================================================================

class _InterfaceSection extends StatelessWidget {
 const _InterfaceSection();

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title row with badge
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Expanded(
 child: Text(
 'Interface management',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF374151),
 letterSpacing: 0.5,
 ),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFFED7AA),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Text(
 'Taylor Brooks',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFC2410C),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 // Interface cards
 ..._demoInterfaces.map((item) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _InterfaceCard(item: item),
 )),
 ],
 ),
 );
 }
}

class _InterfaceCard extends StatelessWidget {
 const _InterfaceCard({required this.item});

 final _InterfaceItem item;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title + risk badge
 Row(
 children: [
 Expanded(
 child: Text(
 item.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: item.riskColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 item.riskLabel,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: item.riskColor,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 // Applies to badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFDBEAFE),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 item.appliesTo,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF2563EB),
 ),
 ),
 ),
 const SizedBox(height: 10),
 // Tags
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: item.tags
 .map((tag) => Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 tag,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 ))
 .toList(),
 ),
 ],
 ),
 );
 }
}

// ===========================================================================
// ROLLED UP ESTIMATES
// ===========================================================================

class _RollupSection extends StatelessWidget {
 const _RollupSection();

 @override
 Widget build(BuildContext context) {
 final schedules = [
 _ScheduleItem(
 label: 'Goal 1',
 startMonths: 0,
 endMonths: 11,
 color: const Color(0xFF22C55E),
 ),
 _ScheduleItem(
 label: 'Goal 2',
 startMonths: 3,
 endMonths: 18,
 color: const Color(0xFF3B82F6),
 ),
 _ScheduleItem(
 label: 'Goal 3',
 startMonths: 6,
 endMonths: 12,
 color: const Color(0xFFF97316),
 ),
 ];

 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'ROLLED UP ESTIMATES',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF374151),
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 12),
 // Donut chart + legend
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 children: [
 // Donut chart
 SizedBox(
 width: 160,
 height: 160,
 child: CustomPaint(
 painter: _DonutChartPainter(slices: _demoSlices),
 child: Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Text(
 '\$5.4M',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const Text(
 'Total',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 const SizedBox(height: 20),
 // Legend
 Column(
 children: _demoSlices
 .map((slice) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 children: [
 Container(
 width: 12,
 height: 12,
 decoration: BoxDecoration(
 color: slice.color,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 8),
 Text(
 slice.label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 const Spacer(),
 Text(
 '\$${slice.amount.toStringAsFixed(1)}M',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ))
 .toList(),
 ),
 const SizedBox(height: 20),
 // Gantt bars
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: schedules
 .map((item) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _GanttRow(item: item),
 ))
 .toList(),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 // Risk posture banner
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF9C3),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Icon(Icons.shield_moon_outlined, size: 18,
 color: Color(0xFF92400E)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Risk posture: Medium · 3 open high risks across all goals',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF92400E),
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
}

// ── Gantt row widget ──

class _GanttRow extends StatelessWidget {
 const _GanttRow({required this.item});

 final _ScheduleItem item;

 @override
 Widget build(BuildContext context) {
 const double maxMonths = 18;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
 ),
 const SizedBox(width: 8),
 Text(
 item.label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 const Spacer(),
 Text(
 '${item.startMonths.toInt()}–${item.endMonths.toInt()} mo',
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF9CA3AF),
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 LayoutBuilder(
 builder: (context, constraints) {
 final totalWidth = constraints.maxWidth;
 final left = (item.startMonths / maxMonths) * totalWidth;
 final width =
 ((item.endMonths - item.startMonths) / maxMonths) * totalWidth;
 return Stack(
 children: [
 Container(
 height: 8,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 Positioned(
 left: left,
 child: Container(
 height: 8,
 width: width,
 decoration: BoxDecoration(
 color: item.color,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ),
 ],
 );
 },
 ),
 ],
 );
 }
}

// ── Donut chart painter ──

class _DonutChartPainter extends CustomPainter {
 _DonutChartPainter({required this.slices});

 final List<_RollupSlice> slices;

 @override
 void paint(Canvas canvas, Size size) {
 final center = Offset(size.width / 2, size.height / 2);
 final radius = size.width / 2;
 final strokeWidth = 22.0;
 final paint = Paint()
 ..style = PaintingStyle.stroke
 ..strokeWidth = strokeWidth
 ..strokeCap = StrokeCap.round;

 double start = -math.pi / 2;
 final gapAngle = 0.03; // Small gap between segments

 for (int i = 0; i < slices.length; i++) {
 final slice = slices[i];
 final sweep = slice.percent * 2 * math.pi - gapAngle;
 paint.color = slice.color;
 canvas.drawArc(
 Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
 start,
 sweep,
 false,
 paint,
 );
 start += slice.percent * 2 * math.pi;
 }
 }

 @override
 bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
 oldDelegate.slices != slices;
}

// ===========================================================================
// EMPTY STATE
// ===========================================================================

class _EmptyStateView extends StatelessWidget {
 const _EmptyStateView({required this.onCreate});

 final VoidCallback onCreate;

 @override
 Widget build(BuildContext context) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.layers_outlined, size: 48,
 color: Color(0xFF9CA3AF)),
 const SizedBox(height: 16),
 const Text(
 'No programs yet',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 const Text(
 'Create a program from three projects to see a live program dashboard here.',
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 height: 1.5,
 ),
 ),
 const SizedBox(height: 20),
 ElevatedButton(
 onPressed: onCreate,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF111827),
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: const Text('Go to project dashboard'),
 ),
 ],
 ),
 ),
 );
 }
}

// ===========================================================================
// BOTTOM CTA
// ===========================================================================
