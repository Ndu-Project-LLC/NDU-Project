import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/theme.dart';

import '../models/program_model.dart';
import '../models/portfolio_model.dart';
import '../providers/project_data_provider.dart';
import '../routing/app_router.dart';
import '../services/firebase_auth_service.dart';
import '../services/navigation_context_service.dart';
import '../services/portfolio_service.dart';
import '../services/program_service.dart';
import '../services/profile_onboarding_service.dart';
import '../services/dashboard_metrics_service.dart';
import '../screens/profile_onboarding_screen.dart';
import '../widgets/dashboard_metrics_cards.dart';
import '../widgets/collapsible_section.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/project_navigation_service.dart';
import '../utils/navigation_route_resolver.dart';
import '../widgets/app_logo.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/kaz_ai_chat_bubble.dart';
import 'initiation_phase_screen.dart';
import 'portfolio_dashboard_screen.dart';
import 'program_dashboard_screen.dart';
import 'project_dashboard_mobile_shell.dart';
import 'project_workspace_dashboard_screen.dart';
import 'project_activities_log_screen.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ProjectDashboardScreen extends StatefulWidget {
 const ProjectDashboardScreen({super.key, this.isBasicPlan = false});

 final bool isBasicPlan;

 @override
 State<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends State<ProjectDashboardScreen> {
 late final ValueNotifier<Set<String>> _selectedProjectIds;
 DashboardMetrics? _metrics;
 bool _isLoadingMetrics = true;

 @override
 void initState() {
 super.initState();
 _selectedProjectIds = ValueNotifier<Set<String>>({});
 // First-time-user check: if the signed-in user hasn't completed profile
 // onboarding yet, redirect them there before they land on the dashboard.
 // Runs once, post-frame, so we don't block the build.
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _checkProfileOnboarding();
 _loadMetrics();
 });
 }

 Future<void> _loadMetrics() async {
 try {
 final m = await DashboardMetricsService.load();
 if (mounted) {
 setState(() {
 _metrics = m;
 _isLoadingMetrics = false;
 });
 }
 } catch (e) {
 debugPrint('[ProjectDashboardScreen] metrics load failed: $e');
 if (mounted) setState(() => _isLoadingMetrics = false);
 }
 }

 Future<void> _checkProfileOnboarding() async {
 try {
 final user = FirebaseAuth.instance.currentUser;
 if (user == null) return;
 final completed = await ProfileOnboardingService.hasCompleted();
 if (!completed && mounted) {
 // Show as a modal dialog overlay instead of navigating away.
 ProfileOnboardingScreen.show(context);
 }
 } catch (e) {
 // Don't block the dashboard on a Firestore read failure — just log.
 debugPrint('[ProjectDashboardScreen] profile onboarding check failed: $e');
 }
 }

 @override
 void dispose() {
 _selectedProjectIds.dispose();
 super.dispose();
 }

 void _toggleSelection(String id) {
 final current = Set<String>.from(_selectedProjectIds.value);

 if (current.contains(id)) {
 current.remove(id);
 } else {
 if (current.length >= 3) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('You can select up to three projects for a program.'),
 duration: Duration(seconds: 2),
 ),
 );
 return;
 }
 current.add(id);
 }

 _selectedProjectIds.value = current;
 }

 void _clearSelection() {
 _selectedProjectIds.value = {};
 }

 Future<void> _handleAddProject() async {
 final nameController = TextEditingController();
 final formKey = GlobalKey<FormState>();

 final projectName = await showDialog<String>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 final theme = Theme.of(dialogContext);
 final scheme = theme.colorScheme;
 final isMobileDialog = MediaQuery.of(dialogContext).size.width <= 500;

 if (isMobileDialog) {
 return Dialog(
 backgroundColor: Colors.transparent,
 insetPadding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
 child: Container(
 padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.14),
 blurRadius: 24,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF4CC),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(
 Icons.create_new_folder_outlined,
 size: 16,
 color: Color(0xFFCC8A00),
 ),
 ),
 const SizedBox(width: 10),
 const Expanded(
 child: Text(
 'Name Your Project',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1C2430),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 'Provide a working title to spin up a new project workspace.',
 style: TextStyle(
 fontSize: 13,
 color: Colors.grey.shade600,
 height: 1.4,
 ),
 ),
 const SizedBox(height: 14),
 const Text(
 'PROJECT NAME*',
 style: TextStyle(
 fontSize: 10.5,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.8,
 color: Color(0xFFFFB800),
 ),
 ),
 const SizedBox(height: 6),
 VoiceTextFormField(
 controller: nameController,
 autofocus: true,
 decoration: InputDecoration(
 hintText: 'e.g., Terminal upgrade - Phase 2',
 prefixIcon: Icon(Icons.work_outline,
 color: Colors.grey.shade500),
 filled: true,
 fillColor: const Color(0xFFF5F7FC),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12,
 vertical: 12,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(
 color: Color(0xFF2F6BFF), width: 1.8),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(
 color: Color(0xFF2F6BFF), width: 1.8),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(
 color: Color(0xFF2F6BFF), width: 2.0),
 ),
 ),
 validator: (value) {
 if (value == null || value.trim().isEmpty) {
 return 'Please enter a project name';
 }
 if (value.trim().length < 3) {
 return 'Project name must be at least 3 characters';
 }
 return null;
 },
 textInputAction: TextInputAction.done,
 onFieldSubmitted: (_) async {
 if (formKey.currentState?.validate() ?? false) {
 final trimmed = nameController.text.trim();
 await _processDuplicateCheck(trimmed, dialogContext);
 }
 },
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 const Spacer(),
 ElevatedButton(
 onPressed: () async {
 if (formKey.currentState?.validate() ?? false) {
 final trimmed = nameController.text.trim();
 await _processDuplicateCheck(
 trimmed, dialogContext);
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 ),
 child: const Text('Continue'),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 );
 }

 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: scheme.primary.withOpacity(0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(Icons.create_new_folder,
 color: scheme.primary, size: 24),
 ),
 const SizedBox(width: 12),
 const Text('Name Your Project'),
 ],
 ),
 content: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Provide a working title to spin up a new project workspace.',
 style: TextStyle(color: Colors.grey[700], fontSize: 14),
 ),
 const SizedBox(height: 20),
 VoiceTextFormField(
 controller: nameController,
 autofocus: true,
 decoration: InputDecoration(
 labelText: 'Project Name',
 hintText: 'e.g., Terminal upgrade - Phase 2',
 prefixIcon: const Icon(Icons.work_outline),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 filled: true,
 fillColor:
 scheme.surfaceContainerHighest.withOpacity(0.3),
 ),
 validator: (value) {
 if (value == null || value.trim().isEmpty) {
 return 'Please enter a project name';
 }
 if (value.trim().length < 3) {
 return 'Project name must be at least 3 characters';
 }
 return null;
 },
 textInputAction: TextInputAction.done,
 onFieldSubmitted: (_) async {
 if (formKey.currentState?.validate() ?? false) {
 final trimmed = nameController.text.trim();
 await _processDuplicateCheck(trimmed, dialogContext);
 }
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 if (formKey.currentState?.validate() ?? false) {
 final trimmed = nameController.text.trim();
 await _processDuplicateCheck(trimmed, dialogContext);
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: scheme.primary,
 foregroundColor: scheme.onPrimary,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Continue'),
 ),
 ],
 );
 },
 );

 if (!mounted || projectName == null || projectName.isEmpty) {
 return;
 }

 // Show loading indicator while creating the project
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => Center(
 child: Container(
 width: 100,
 height: 100,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.15),
 blurRadius: 18,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: const CircularProgressIndicator(),
 ),
 ),
 );

 try {
 final provider = ProjectDataInherited.read(context);
 provider.reset();
 provider.updateInitiationData(
 projectName: projectName,
 solutionTitle: projectName,
 solutionDescription: 'New project in initiation phase',
 businessCase: '',
 notes: '',
 tags: const ['Initiation'],
 );
 provider.updateField(
 (data) => data.copyWith(isBasicPlanProject: widget.isBasicPlan),
 );

 final user = FirebaseAuth.instance.currentUser;
 if (user == null) {
 Navigator.of(context).pop();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please sign in to create a project'),
 backgroundColor: Colors.orange,
 ),
 );
 return;
 }

 final success = await provider.saveToFirebase(checkpoint: 'initiation');

 if (!mounted) {
 return;
 }

 Navigator.of(context).pop();

 if (success) {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const InitiationPhaseScreen(
 scrollToBusinessCase: true,
 ),
 ),
 );
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Failed to create project: ${provider.lastError ?? "Unknown error"}'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 } catch (e) {
 if (Navigator.canPop(context)) {
 Navigator.of(context).pop();
 }
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error creating project: $e'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 }
 }

 Future<void> _processDuplicateCheck(
 String trimmed, BuildContext dialogContext) async {
 Navigator.of(dialogContext).pop(trimmed);
 }

 @override
 Widget build(BuildContext context) {
 // Record this dashboard so the logo knows where to return on tap
 NavigationContextService.instance
 .setLastClientDashboard(AppRoutes.dashboard);
 final user = FirebaseAuth.instance.currentUser;
 if (MediaQuery.sizeOf(context).width < 700) {
 return ProjectDashboardMobileShell(
 isBasicPlan: widget.isBasicPlan,
 onAddProject: _handleAddProject,
 );
 }
 return Scaffold(
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 SafeArea(
 child: LayoutBuilder(
 builder: (context, constraints) {
 final isCompact = constraints.maxWidth < 1180;
 final horizontalPadding =
 constraints.maxWidth < 600 ? 20.0 : 40.0;

 Widget buildProjectColumns({
 required List<ProjectRecord> projects,
 required bool isLoading,
 String? error,
 }) {
 if (isCompact) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SingleProjectsCard(
 projects: projects,
 isLoading: isLoading,
 error: error,
 isBasicPlan: widget.isBasicPlan,
 ),
 const SizedBox(height: 24),
 const _ProgramsSummaryCard(),
 ],
 );
 }

 // Single Projects at full width, Programs & Portfolios below
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SingleProjectsCard(
 projects: projects,
 isLoading: isLoading,
 error: error,
 isBasicPlan: widget.isBasicPlan,
 ),
 if (!widget.isBasicPlan) ...[
 const SizedBox(height: 24),
 const _ProgramsSummaryCard(),
 ],
 ],
 );
 }

 return SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 36),
 child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _ProjectHeader(
              onAddProject: _handleAddProject,
              isBasicPlan: widget.isBasicPlan,
            ),
            const SizedBox(height: 26),
            const _StatusStrip(),
            // ── GAP only when action buttons or metrics follow ──
            if (!widget.isBasicPlan || _isLoadingMetrics || _metrics != null)
              const SizedBox(height: 28),
            // ── Compact action button row ──
            if (!widget.isBasicPlan)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactActionButton(
                        label: 'Group Into A Program',
                        subtitle:
                            'Select up to 3 projects to combine',
                        icon: Icons.layers_outlined,
                        accent: const Color(0xFF8B5CF6),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  _GroupProjectsExpandedScreen(
                                projects: const [],
                                isLoading: false,
                                selectedIdsListenable:
                                    _selectedProjectIds,
                                selectedIds: _selectedProjectIds.value,
                                onToggle: _toggleSelection,
                                onClear: _clearSelection,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactActionButton(
                        label: 'Project Logs',
                        subtitle: 'Activity across all projects',
                        icon: Icons.fact_check_outlined,
                        accent: const Color(0xFFFCD34D),
                        onTap: () => ProjectActivitiesLogScreen.open(
                            context),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Past-due + Assigned-to-me + Project metrics ──
            if (_isLoadingMetrics)
              _buildMetricsSkeleton()
            else if (_metrics != null) ...[
              if (_metrics!.totalPastDue > 0) ...[
                PastDueActivitiesCard(
                  activities: _metrics!.pastDue),
                const SizedBox(height: 18),
              ],
              AssignedActivitiesCard(
                activities: _metrics!.assignedToMe),
              const SizedBox(height: 18),
              if (_metrics!.projectStatuses.isNotEmpty) ...[
                CollapsibleSection(
                  title: 'Project status',
                  itemCount: _metrics!.projectStatuses.length,
                  initiallyExpanded: false,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _metrics!.projectStatuses
                        .map((r) => ProjectMetricsCard(
                              rollup: r,
                              level: 'Project',
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ],
 if (user == null)
  buildProjectColumns(
    projects: const [], isLoading: false)
else
  StreamBuilder<List<ProjectRecord>>(
    stream: ProjectService.streamProjects(
      ownerId: user.uid,
      filterByOwner: true,
      limit: 200,
    ),
    builder: (context, snapshot) {
      final projects =
          snapshot.data ?? const <ProjectRecord>[];
      final isLoading = snapshot.connectionState ==
          ConnectionState.waiting;
      final error = snapshot.hasError
          ? snapshot.error.toString()
          : null;
      return buildProjectColumns(
        projects: projects,
        isLoading: isLoading,
        error: error,
      );
    },
  ),
  // ── Bottom spacing only when content exists above ──
  if (user != null || _metrics != null || !widget.isBasicPlan)
    const SizedBox(height: 96),
],
      ),
    ); },
   ),
 ),
 const KazAiChatBubble(),
],
  ),
);
  }

  /// World-class metrics loading skeleton — fills space so the dashboard
  /// never has empty gaps during data fetch.
  Widget _buildMetricsSkeleton() {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _shimmerBox(width: 80, height: 10),
                    _shimmerBox(width: 120, height: 22),
                    _shimmerBox(width: 60, height: 8),
                  ],
                ),
              ),
            )),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: List.generate(4, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _shimmerBox(width: 60, height: 10),
                    _shimmerBox(width: 100, height: 18),
                    _shimmerBox(width: 40, height: 8),
                  ],
                ),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({required double width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E7EC),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProjectHeader extends StatefulWidget {
 const _ProjectHeader({required this.onAddProject, required this.isBasicPlan});

 final VoidCallback onAddProject;
 final bool isBasicPlan;

 @override
 State<_ProjectHeader> createState() => _ProjectHeaderState();
}

class _ProjectHeaderState extends State<_ProjectHeader> {
 void _navigateToProgram() {
 if (!mounted) return;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted) {
 context.go('/${AppRoutes.programDashboard}');
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

 void _navigateToBilling() {
 if (!mounted) return;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (mounted) {
 context.go('/${AppRoutes.settings}?from=${AppRoutes.dashboard}');
 }
 });
 }

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

 @override
 Widget build(BuildContext context) {
 final textTheme = Theme.of(context).textTheme;

 return LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 960;

 final crumb = Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: Colors.grey.shade300),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.view_quilt_outlined,
 size: 18, color: Colors.grey.shade700),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 'Project workspace overview',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Colors.grey.shade700,
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
 height: compact ? 72 : 104,
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
 onPressed: widget.onAddProject,
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.blue.shade600,
 foregroundColor: Colors.white,
 elevation: 2,
 shadowColor: Colors.black.withOpacity(0.1),
 padding: const EdgeInsets.symmetric(
 horizontal: 26, vertical: 18),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.add_circle_outline, size: 22),
 const SizedBox(width: 10),
 Text(widget.isBasicPlan
 ? 'Create Regular Project'
 : 'Create Project'),
 const SizedBox(width: 6),
 const Icon(Icons.arrow_forward, size: 20),
 ],
 ),
 ),
 if (!widget.isBasicPlan)
 _secondaryCta(
 label: 'Create Program',
 onPressed: _navigateToProgram,
 ),
 if (!widget.isBasicPlan)
 _secondaryCta(
 label: 'Create Portfolio',
 onPressed: _navigateToPortfolio,
 ),
 _secondaryCta(
 label: 'Billing',
 onPressed: _navigateToBilling,
 icon: Icons.account_balance_wallet_outlined,
 ),
 _secondaryCta(
 label: 'Log Out',
 onPressed: _handleLogout,
 icon: Icons.logout,
 ),
 ],
 ),
 ],
 ),
 if (!compact)
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 IconButton(
 icon: const Icon(Icons.arrow_back),
 onPressed: () {
 if (context.canPop()) {
 context.pop();
 } else {
 context.go('/');
 }
 },
 color: const Color(0xFF2D3A4B),
 tooltip: 'Back',
 ),
 const SizedBox(width: 10),
 Flexible(child: crumb),
 ],
 )
 else
 Row(
 children: [
 IconButton(
 icon: const Icon(Icons.arrow_back),
 onPressed: () {
 if (context.canPop()) {
 context.pop();
 } else {
 context.go('/');
 }
 },
 color: const Color(0xFF2D3A4B),
 tooltip: 'Back',
 ),
 const SizedBox(width: 10),
 Expanded(child: crumb),
 ],
 ),
 const SizedBox(height: 26),
 // ── Premium Personalized Greeting ─────────────────────────
 _DesktopPremiumGreeting(isBasicPlan: widget.isBasicPlan),
 const SizedBox(height: 14),
 // ── Description (web only – hidden on Android/iOS) ────────
 if (kIsWeb)
 Text(
 widget.isBasicPlan
 ? 'Manage your basic plan project workspace. Build the core initiation details and upgrade when you are ready to unlock more sections.'
 : 'Manage all single projects before they are linked into programs or portfolios. Add new work, track status, and quickly roll three projects into a program when you are ready.',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade700,
 height: 1.55,
 ),
 ),
 ],
 );
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
 foregroundColor: Colors.black87,
 backgroundColor: Colors.white,
 side: BorderSide(color: Colors.grey.shade300),
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 textStyle: const TextStyle(fontWeight: FontWeight.w600),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(label),
 const SizedBox(width: 8),
 Icon(icon ?? Icons.keyboard_arrow_right, size: 20),
 ],
 ),
 );
 }
}

class _StatusStrip extends StatelessWidget {
 const _StatusStrip();

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 void openProjectDashboard() {
 Navigator.push(
 context,
 MaterialPageRoute(
     builder: (_) => const ProjectWorkspaceDashboardScreen(isBasicPlan: false)),
 );
 }

 void openBasicDashboard() {
 Navigator.push(
 context,
 MaterialPageRoute(
     builder: (_) => const ProjectWorkspaceDashboardScreen(isBasicPlan: true)),
 );
 }

 void openProgramDashboard() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const ProgramDashboardScreen()),
 );
 }

 void openPortfolioDashboard() {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 final isStacked = constraints.maxWidth < 920;

 if (user == null) {
 final metrics = [
 DashboardStatCard( label: 'Regular Projects',
 value: '—',
 subLabel: 'Sign in to view',
 icon: Icons.folder_special_rounded,
 color: Colors.teal.shade600,
 onTap: openBasicDashboard,
 ),
 DashboardStatCard(
 label: 'Projects',
 value: '—',
 subLabel: 'Sign in to view',
 icon: Icons.folder_open_rounded,
 color: Colors.blue.shade600,
 onTap: openProjectDashboard,
 ),
 DashboardStatCard(
 label: 'Programs',
 value: '—',
 subLabel: 'Sign in to view',
 icon: Icons.layers_outlined,
 color: Colors.purple.shade600,
 onTap: openProgramDashboard,
 ),
 DashboardStatCard(
 label: 'Portfolios',
 value: '—',
 subLabel: 'Sign in to view',
 icon: Icons.pie_chart_outline_rounded,
 color: Colors.green.shade600,
 onTap: openPortfolioDashboard,
 ),
 ];

 return DashboardStatLayout(
 cards: metrics,
 isStacked: isStacked,
 );
 }

 return StreamBuilder<List<ProjectRecord>>(
 stream: ProjectService.streamProjects(ownerId: user.uid, limit: 100),
 builder: (context, projectSnapshot) {
 final projects = projectSnapshot.data ?? const <ProjectRecord>[];
 final projectCount =
 projects.where((project) => !project.isBasicPlanProject).length;
 final basicProjectCount =
 projects.where((project) => project.isBasicPlanProject).length;

 return StreamBuilder<List<ProgramModel>>(
 stream: ProgramService.streamPrograms(ownerId: user.uid),
 builder: (context, programSnapshot) {
 final programCount =
 programSnapshot.hasData ? programSnapshot.data!.length : 0;
 return StreamBuilder<List<PortfolioModel>>(
 stream: PortfolioService.streamPortfolios(ownerId: user.uid),
 builder: (context, portfolioSnapshot) {
 final portfolioCount = portfolioSnapshot.hasData
 ? portfolioSnapshot.data!.length
 : 0;

 final metrics = [
 DashboardStatCard(
 label: 'Regular Projects',
 value: '$basicProjectCount',
 subLabel: 'Basic plan workspaces',
 icon: Icons.folder_special_rounded,
 color: Colors.teal.shade600,
 onTap: openBasicDashboard,
 ),
 DashboardStatCard(
 label: 'Projects',
 value: '$projectCount',
 subLabel: 'Active workspaces',
 icon: Icons.folder_open_rounded,
 color: Colors.blue.shade600,
 onTap: openProjectDashboard,
 ),
 DashboardStatCard(
 label: 'Programs',
 value: '$programCount',
 subLabel: 'Grouped projects',
 icon: Icons.layers_outlined,
 color: Colors.purple.shade600,
 onTap: openProgramDashboard,
 ),
 DashboardStatCard(
 label: 'Portfolios',
 value: '$portfolioCount',
 subLabel: 'Executive views',
 icon: Icons.pie_chart_outline_rounded,
 color: Colors.green.shade600,
 onTap: openPortfolioDashboard,
 ),
 ];

 return DashboardStatLayout(
 cards: metrics,
 isStacked: isStacked,
 );
 },
 );
 },
 );
 },
 );
 },
 );
 }
}

class _SingleProjectsCard extends StatefulWidget {
 const _SingleProjectsCard({
 required this.projects,
 required this.isLoading,
 this.error,
 this.expandedView = false,
 this.isBasicPlan = false,
 });

 final List<ProjectRecord> projects;
 final bool isLoading;
 final String? error;
 final bool expandedView;
 final bool isBasicPlan;

 @override
 State<_SingleProjectsCard> createState() => _SingleProjectsCardState();
}

class _SingleProjectsCardState extends State<_SingleProjectsCard> {
 bool _showAll = false;
 final TextEditingController _searchController = TextEditingController();
 String _searchQuery = '';

 @override
 void initState() {
 super.initState();
 if (widget.expandedView) {
 _showAll = true;
 }
 }

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 void _openExpandedView() {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => _SingleProjectsExpandedScreen(
 projects: widget.projects,
 isLoading: widget.isLoading,
 error: widget.error,
 isBasicPlan: widget.isBasicPlan,
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final textTheme = Theme.of(context).textTheme;
 final user = FirebaseAuth.instance.currentUser;
 final titleText = widget.isBasicPlan ? 'Regular Projects' : 'Projects';
 final subtitleText = widget.isBasicPlan
 ? 'Review all basic plan projects before upgrading to unlock more sections.'
 : 'Review all standalone projects before they are linked into programs or portfolios.';
 final searchHint =
 widget.isBasicPlan ? 'Search regular projects...' : 'Search projects...';
 final tipText = widget.isBasicPlan
 ? 'Basic plan workspaces focus on initiation essentials'
 : 'If more than 3 projects, group up to 3 into a program';

 return _FrostedSurface(
 padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final narrow = constraints.maxWidth < 840;
 final seeAllButton = widget.expandedView
 ? const SizedBox.shrink()
 : TextButton(
 onPressed: _openExpandedView,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFF4D6D),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 6),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: const Text('See All'),
 );
 final tip = Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.grey.shade50,
 borderRadius: BorderRadius.circular(30),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.merge_type,
 size: 18, color: Colors.grey.shade600),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 tipText,
 style: TextStyle(
 fontWeight: FontWeight.w600,
 fontSize: 13,
 color: Colors.grey.shade600,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 softWrap: true,
 ),
 ),
 ],
 ),
 );

 if (!narrow) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 titleText,
 style: textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 fontSize: 24,
 ),
 ),
 const SizedBox(height: 10),
 Text(
 subtitleText,
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontSize: 16,
 height: 1.5,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 seeAllButton,
 const SizedBox(height: 8),
 SizedBox(width: 260, child: tip),
 ],
 ),
 ],
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 titleText,
 style: textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 fontSize: 24,
 ),
 ),
 ),
 seeAllButton,
 ],
 ),
 const SizedBox(height: 10),
 Text(
 subtitleText,
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontSize: 16,
 height: 1.5,
 ),
 ),
 const SizedBox(height: 12),
 tip,
 ],
 );
 },
 ),
 const SizedBox(height: 20),
 VoiceTextField(
 controller: _searchController,
 style: const TextStyle(fontSize: 16),
 decoration: InputDecoration(
 hintText: searchHint,
 hintStyle: const TextStyle(fontSize: 16),
 prefixIcon:
 Icon(Icons.search, color: Colors.grey.shade600, size: 24),
 suffixIcon: _searchQuery.isNotEmpty
 ? IconButton(
 icon: const Icon(Icons.clear, size: 22),
 onPressed: () {
 setState(() {
 _searchController.clear();
 _searchQuery = '';
 });
 },
 )
 : null,
 filled: true,
 fillColor: Colors.grey.shade50,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: Colors.grey.shade300),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(
 color: Theme.of(context).primaryColor, width: 2.5),
 ),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 ),
 onChanged: (value) {
 setState(() => _searchQuery = value.toLowerCase().trim());
 },
 ),
 const SizedBox(height: 26),
 if (user == null)
 Container(
 padding: const EdgeInsets.all(40),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.person_off_outlined,
 size: 48, color: Colors.grey.shade400),
 const SizedBox(height: 16),
 Text(
 'Please sign in to view your projects',
 style: textTheme.bodyLarge?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 )
 else if (widget.isLoading)
 Container(
 padding: const EdgeInsets.all(60),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: const Center(child: CircularProgressIndicator()),
 )
 else if (widget.error != null)
 Container(
 padding: const EdgeInsets.all(40),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.error_outline,
 size: 48, color: Colors.red.shade400),
 const SizedBox(height: 16),
 Text(
 'Error loading projects',
 style: textTheme.bodyLarge?.copyWith(
 color: Colors.red.shade700,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 widget.error!,
 style: textTheme.bodySmall
 ?.copyWith(color: Colors.grey.shade600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 )
 else
 Builder(
 builder: (context) {
 final allProjects = widget.isBasicPlan
 ? widget.projects
 .where((project) => project.isBasicPlanProject)
 .toList()
 : List<ProjectRecord>.from(widget.projects);

 // Apply search filter
 final firebaseProjects = _searchQuery.isEmpty
 ? allProjects
 : allProjects.where((project) {
 final name = project.name.toLowerCase();
 final status = project.status.toLowerCase();
 final milestone = project.milestone.toLowerCase();
 return name.contains(_searchQuery) ||
 status.contains(_searchQuery) ||
 milestone.contains(_searchQuery);
 }).toList();

 if (allProjects.isEmpty) {
 return Container(
 padding: const EdgeInsets.all(40),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.folder_off_outlined,
 size: 48, color: Colors.grey.shade400),
 const SizedBox(height: 16),
 Text(
 widget.isBasicPlan
 ? 'No regular projects yet'
 : 'No projects yet',
 style: textTheme.bodyLarge?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 widget.isBasicPlan
 ? 'Create your first regular project using the "Create Project" button above'
 : 'Create your first project using the "Create Project" button above',
 style: textTheme.bodySmall
 ?.copyWith(color: Colors.grey.shade600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 );
 }

 if (firebaseProjects.isEmpty) {
 return Container(
 padding: const EdgeInsets.all(40),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.search_off,
 size: 48, color: Colors.grey.shade400),
 const SizedBox(height: 16),
 Text(
 'No matching projects',
 style: textTheme.bodyLarge?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Try adjusting your search criteria',
 style: textTheme.bodySmall
 ?.copyWith(color: Colors.grey.shade600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 // Provide horizontal scroll for narrow screens
 final totalCount = firebaseProjects.length;
 final visibleCount = _showAll
 ? totalCount
 : (totalCount > 10 ? 10 : totalCount);
 final table = DecoratedBox(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
 child: Row(
 children: const [
 Expanded(
 flex: 32,
 child: _TableHeaderLabel('Project'),
 ),
 Expanded(
 flex: 16,
 child: _TableHeaderLabel(
 'Current Phase',
 alignment: Alignment.center,
 ),
 ),
 Expanded(
 flex: 20,
 child: _TableHeaderLabel(
 'Progress',
 alignment: Alignment.center,
 ),
 ),
 Expanded(
 flex: 12,
 child: _TableHeaderLabel(
 'Owner',
 alignment: Alignment.center,
 ),
 ),
 Expanded(
 flex: 10,
 child: _TableHeaderLabel(
 'Investment',
 alignment: Alignment.center,
 ),
 ),
 Expanded(
 flex: 18,
 child: _TableHeaderLabel(
 'Actions',
 alignment: Alignment.center,
 ),
 ),
 ],
 ),
 ),
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFE8E9F2)),
 for (int i = 0; i < visibleCount; i++) ...[
 _ProjectTableRowFromFirebase(
 project: firebaseProjects[i]),
 if (i < visibleCount - 1)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFE8E9F2)),
 ],
 if (totalCount > 10 && !widget.expandedView)
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
 child: Align(
 alignment: Alignment.centerRight,
 child: TextButton.icon(
 onPressed: () {
 setState(() => _showAll = !_showAll);
 },
 style: TextButton.styleFrom(
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(24)),
 ),
 icon: Icon(
 _showAll
 ? Icons.expand_less
 : Icons.expand_more,
 size: 18),
 label: Text(_showAll
 ? 'Show 10'
 : 'View All ($totalCount)'),
 ),
 ),
 ),
 ],
 ),
 );

 if (constraints.maxWidth < 1180) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: 1180,
 child: table,
 ),
 );
 }

 return table;
 },
 );
 },
 ),
 ],
 ),
 );
 }
}

class _GroupProjectsCard extends StatefulWidget {
 const _GroupProjectsCard({
 required this.projects,
 required this.isLoading,
 this.error,
 required this.selectedIds,
 required this.onToggle,
 required this.onClear,
 this.expandedView = false,
 this.selectedIdsListenable,
 });

 final List<ProjectRecord> projects;
 final bool isLoading;
 final String? error;
 final Set<String> selectedIds;
 final ValueChanged<String> onToggle;
 final VoidCallback onClear;
 final bool expandedView;
 final ValueListenable<Set<String>>? selectedIdsListenable;

 @override
 State<_GroupProjectsCard> createState() => _GroupProjectsCardState();
}

class _GroupProjectsCardState extends State<_GroupProjectsCard> {
 bool _showAll = false;
 final TextEditingController _searchController = TextEditingController();
 String _searchQuery = '';

 @override
 void initState() {
 super.initState();
 if (widget.expandedView) {
 _showAll = true;
 }
 }

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 void _openExpandedView() {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => _GroupProjectsExpandedScreen(
 projects: widget.projects,
 isLoading: widget.isLoading,
 error: widget.error,
 selectedIdsListenable: widget.selectedIdsListenable,
 selectedIds: widget.selectedIds,
 onToggle: widget.onToggle,
 onClear: widget.onClear,
 ),
 ),
 );
 }

 Future<void> _handleCreateProgram() async {
 final nameController = TextEditingController();
 final formKey = GlobalKey<FormState>();

 final programName = await showDialog<String>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 final theme = Theme.of(dialogContext);
 final scheme = theme.colorScheme;

 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: scheme.primary.withOpacity(0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(Icons.layers, color: scheme.primary, size: 24),
 ),
 const SizedBox(width: 12),
 const Text('Name Your Program'),
 ],
 ),
 content: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Give a name to your new program.',
 style: TextStyle(color: Colors.grey[700], fontSize: 14),
 ),
 const SizedBox(height: 20),
 VoiceTextFormField(
 controller: nameController,
 autofocus: true,
 decoration: InputDecoration(
 labelText: 'Program Name',
 hintText: 'e.g., Terminal Modernization Program',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12)),
 filled: true,
 fillColor:
 scheme.surfaceContainerHighest.withOpacity(0.3),
 ),
 validator: (value) {
 if (value == null || value.trim().isEmpty) {
 return 'Please enter a name';
 }
 if (value.trim().length < 3) {
 return 'Name must be at least 3 characters';
 }
 return null;
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (formKey.currentState?.validate() ?? false) {
 Navigator.of(dialogContext).pop(nameController.text.trim());
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: scheme.primary,
 foregroundColor: scheme.onPrimary,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Create Program'),
 ),
 ],
 );
 },
 );

 if (programName == null || !mounted) return;

 try {
 final user = FirebaseAuth.instance.currentUser;
 if (user == null) return;

 // Create program
 await ProgramService.createProgram(
 name: programName,
 projectIds: widget.selectedIds.toList(),
 ownerId: user.uid,
 );

 if (!mounted) return;

 // Clear selection
 widget.onClear();

 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Program created successfully!'),
 backgroundColor: Colors.green),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error creating program: $e'),
 backgroundColor: Colors.red),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 final textTheme = Theme.of(context).textTheme;
 final selectedCount = widget.selectedIds.length;
 final user = FirebaseAuth.instance.currentUser;

 return _FrostedSurface(
 padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final isColumn = constraints.maxWidth < 720;
 final seeAllButton = widget.expandedView
 ? const SizedBox.shrink()
 : TextButton(
 onPressed: _openExpandedView,
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFFFF4D6D),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 6),
 textStyle: const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: const Text('See All'),
 );

 final guidance = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Group Projects Into A Program',
 style: textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 fontSize: 24,
 ),
 ),
 const SizedBox(height: 10),
 Text(
 'When you have more than three single projects, select up to three that share an outcome to create a new program.',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontSize: 16,
 height: 1.5,
 ),
 ),
 ],
 );

 final capChip = Align(
 alignment:
 isColumn ? Alignment.centerLeft : Alignment.topCenter,
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
 decoration: BoxDecoration(
 color: Colors.grey.shade50,
 borderRadius: BorderRadius.circular(30),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.filter_alt_outlined,
 size: 18, color: Colors.grey.shade600),
 const SizedBox(width: 8),
 Text(
 'Up to 3 projects',
 style: TextStyle(
 fontWeight: FontWeight.w600,
 fontSize: 13,
 color: Colors.grey.shade600,
 ),
 ),
 ],
 ),
 ),
 );

 if (isColumn) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(child: guidance),
 seeAllButton,
 ],
 ),
 const SizedBox(height: 16),
 capChip,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: guidance),
 const SizedBox(width: 16),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 seeAllButton,
 const SizedBox(height: 8),
 capChip,
 ],
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 20),
 VoiceTextField(
 controller: _searchController,
 style: const TextStyle(fontSize: 16),
 decoration: InputDecoration(
 hintText: 'Search projects to group...',
 hintStyle: const TextStyle(fontSize: 16),
 prefixIcon:
 Icon(Icons.search, color: Colors.grey.shade600, size: 24),
 suffixIcon: _searchQuery.isNotEmpty
 ? IconButton(
 icon: const Icon(Icons.clear, size: 22),
 onPressed: () {
 setState(() {
 _searchController.clear();
 _searchQuery = '';
 });
 },
 )
 : null,
 filled: true,
 fillColor: Colors.grey.shade50,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: Colors.grey.shade300),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(
 color: Theme.of(context).primaryColor, width: 2.5),
 ),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
 ),
 onChanged: (value) {
 setState(() => _searchQuery = value.toLowerCase().trim());
 },
 ),
 const SizedBox(height: 24),
 if (user == null)
 Container(
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: const Color(0xFFF7F8FD),
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE3E6F2)),
 ),
 child: Center(
 child: Text(
 'Sign in to group projects',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 )
 else if (widget.isLoading)
 Container(
 padding: const EdgeInsets.all(40),
 child: const Center(child: CircularProgressIndicator()),
 )
 else if (widget.error != null)
 Container(
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.error_outline,
 size: 40, color: Colors.red.shade400),
 const SizedBox(height: 12),
 Text(
 'Error loading projects',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.red.shade700,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 widget.error!,
 style: textTheme.bodySmall
 ?.copyWith(color: Colors.grey.shade600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 )
 else
 Builder(
 builder: (context) {
 final allProjects = widget.projects;

 // Apply search filter
 final firebaseProjects = _searchQuery.isEmpty
 ? allProjects
 : allProjects.where((project) {
 final name = project.name.toLowerCase();
 final status = project.status.toLowerCase();
 return name.contains(_searchQuery) ||
 status.contains(_searchQuery);
 }).toList();

 if (allProjects.isEmpty) {
 return Container(
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Text(
 'No projects available to group',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 );
 }

 if (firebaseProjects.isEmpty) {
 return Container(
 padding: const EdgeInsets.all(32),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Center(
 child: Column(
 children: [
 Icon(Icons.search_off,
 size: 40, color: Colors.grey.shade400),
 const SizedBox(height: 12),
 Text(
 'No matching projects',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 );
 }

 // Show only 10 by default
 final visibleCount = _showAll
 ? firebaseProjects.length
 : (firebaseProjects.length > 10
 ? 10
 : firebaseProjects.length);

 // Use ValueListenableBuilder to react to selection changes
 if (widget.selectedIdsListenable != null) {
 return ValueListenableBuilder<Set<String>>(
 valueListenable: widget.selectedIdsListenable!,
 builder: (context, selectedIds, _) {
 return Column(
 children: [
 for (int i = 0; i < visibleCount; i++) ...[
 _SelectableProjectRowFromFirebase(
 project: firebaseProjects[i],
 selected:
 selectedIds.contains(firebaseProjects[i].id),
 onTap: () =>
 widget.onToggle(firebaseProjects[i].id),
 ),
 if (i < visibleCount - 1)
 const SizedBox(height: 12),
 ],
 if (firebaseProjects.length > 10 &&
 !widget.expandedView)
 Padding(
 padding: const EdgeInsets.only(top: 16),
 child: Align(
 alignment: Alignment.centerRight,
 child: TextButton.icon(
 onPressed: () {
 setState(() => _showAll = !_showAll);
 },
 style: TextButton.styleFrom(
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(24)),
 ),
 icon: Icon(
 _showAll
 ? Icons.expand_less
 : Icons.expand_more,
 size: 18),
 label: Text(_showAll
 ? 'Show 10'
 : 'View All (${firebaseProjects.length})'),
 ),
 ),
 ),
 ],
 );
 },
 );
 }

 // Fallback if no ValueListenable provided
 return Column(
 children: [
 for (int i = 0; i < visibleCount; i++) ...[
 _SelectableProjectRowFromFirebase(
 project: firebaseProjects[i],
 selected:
 widget.selectedIds.contains(firebaseProjects[i].id),
 onTap: () => widget.onToggle(firebaseProjects[i].id),
 ),
 if (i < visibleCount - 1) const SizedBox(height: 12),
 ],
 if (firebaseProjects.length > 10 && !widget.expandedView)
 Padding(
 padding: const EdgeInsets.only(top: 16),
 child: Align(
 alignment: Alignment.centerRight,
 child: TextButton.icon(
 onPressed: () {
 setState(() => _showAll = !_showAll);
 },
 style: TextButton.styleFrom(
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(24)),
 ),
 icon: Icon(
 _showAll
 ? Icons.expand_less
 : Icons.expand_more,
 size: 18),
 label: Text(_showAll
 ? 'Show 10'
 : 'View All (${firebaseProjects.length})'),
 ),
 ),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 24),
 // Use ValueListenableBuilder for selection count if available
 widget.selectedIdsListenable != null
 ? ValueListenableBuilder<Set<String>>(
 valueListenable: widget.selectedIdsListenable!,
 builder: (context, selectedIds, _) {
 final count = selectedIds.length;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '$count/3 projects selected. Select exactly three to create a program.',
 style: textTheme.bodySmall?.copyWith(
 color: Colors.grey.shade700,
 fontWeight: FontWeight.w700,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed: count == 3 ? _handleCreateProgram : null,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF111111),
 foregroundColor: Colors.white,
 elevation: count == 3 ? 10 : 0,
 padding: const EdgeInsets.symmetric(vertical: 18),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16)),
 ),
 child: Text(
 count == 3
 ? 'Create Program'
 : 'Select ${3 - count} more',
 style: const TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700),
 ),
 ),
 ),
 ],
 );
 },
 )
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '$selectedCount/3 projects selected. Select exactly three to create a program.',
 style: textTheme.bodySmall?.copyWith(
 color: Colors.grey.shade700,
 fontWeight: FontWeight.w700,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 onPressed:
 selectedCount == 3 ? _handleCreateProgram : null,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF111111),
 foregroundColor: Colors.white,
 elevation: selectedCount == 3 ? 10 : 0,
 shadowColor: Colors.black.withOpacity(0.3),
 padding: const EdgeInsets.symmetric(
 horizontal: 28, vertical: 22),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(32)),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 17,
 letterSpacing: 0.3,
 ),
 ),
 child: const Text('Create program from selected'),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ProgramsSummaryCard extends StatelessWidget {
 const _ProgramsSummaryCard();

 @override
 Widget build(BuildContext context) {
 final textTheme = Theme.of(context).textTheme;
 final user = FirebaseAuth.instance.currentUser;

 return _FrostedSurface(
 padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Programs and portfolios',
 style: textTheme.titleLarge?.copyWith(
 fontWeight: FontWeight.w700,
 fontSize: 24,
 ),
 ),
 const SizedBox(height: 10),
 Text(
 'High-level containers for your grouped work.',
 style: textTheme.bodyMedium?.copyWith(
 color: Colors.grey.shade600,
 fontSize: 16,
 height: 1.5,
 ),
 ),
 const SizedBox(height: 20),
 if (user == null)
 LayoutBuilder(
 builder: (context, constraints) {
 final stats = [
 const _SummaryStat(
 label: 'Programs',
 value: '—',
 caption: 'Sign in to view your programs.',
 ),
 const _SummaryStat(
 label: 'Portfolios',
 value: '—',
 caption: 'Sign in to view your portfolios.',
 ),
 const _SummaryStat(
 label: 'Projects per program',
 value: 'Max 3',
 caption: 'Keep scope focused and interfaces manageable.',
 ),
 ];

 return _buildStatsLayout(constraints, stats);
 },
 )
 else
 StreamBuilder<List<ProgramModel>>(
 stream: ProgramService.streamPrograms(ownerId: user.uid),
 builder: (context, programSnapshot) {
 final programCount =
 programSnapshot.hasData ? programSnapshot.data!.length : 0;
 return StreamBuilder<List<PortfolioModel>>(
 stream: PortfolioService.streamPortfolios(ownerId: user.uid),
 builder: (context, portfolioSnapshot) {
 final portfolioCount = portfolioSnapshot.hasData
 ? portfolioSnapshot.data!.length
 : 0;

 final stats = [
 _SummaryStat(
 label: 'Programs',
 value: '$programCount',
 caption: programCount == 0
 ? 'Add three projects to unlock a program dashboard.'
 : 'Grouped projects',
 ),
 _SummaryStat(
 label: 'Portfolios',
 value: '$portfolioCount',
 caption:
 'Roll multiple programs into an executive view.',
 ),
 const _SummaryStat(
 label: 'Projects per program',
 value: 'Max 3',
 caption:
 'Keep scope focused and interfaces manageable.',
 ),
 ];

 return LayoutBuilder(
 builder: (context, constraints) =>
 _buildStatsLayout(constraints, stats),
 );
 },
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildStatsLayout(
 BoxConstraints constraints, List<_SummaryStat> stats) {
 if (constraints.maxWidth < 620) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 stats[i],
 if (i < stats.length - 1) const SizedBox(height: 16),
 ],
 ],
 );
 }

 if (constraints.maxWidth < 1024) {
 final double cardWidth =
 ((constraints.maxWidth - 18) / 2).clamp(260.0, constraints.maxWidth);
 return Wrap(
 spacing: 18,
 runSpacing: 18,
 children: [
 for (final stat in stats)
 SizedBox(
 width: cardWidth,
 child: stat,
 ),
 ],
 );
 }

 return Row(
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 Expanded(child: stats[i]),
 if (i < stats.length - 1) const SizedBox(width: 18),
 ],
 ],
 );
 }
}

class _SingleProjectsExpandedScreen extends StatelessWidget {
 const _SingleProjectsExpandedScreen({
 required this.projects,
 required this.isLoading,
 this.error,
 this.isBasicPlan = false,
 });

 final List<ProjectRecord> projects;
 final bool isLoading;
 final String? error;
 final bool isBasicPlan;

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 title: Text(isBasicPlan ? 'Regular Projects' : 'Projects'),
 backgroundColor: Colors.white,
 elevation: 0,
 foregroundColor: Colors.black87,
 ),
 body: SafeArea(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: _SingleProjectsCard(
 projects: projects,
 isLoading: isLoading,
 error: error,
 expandedView: true,
 isBasicPlan: isBasicPlan,
 ),
 ),
 ),
 );
 }
}

class _GroupProjectsExpandedScreen extends StatelessWidget {
 const _GroupProjectsExpandedScreen({
 required this.projects,
 required this.isLoading,
 this.error,
 required this.selectedIds,
 required this.onToggle,
 required this.onClear,
 this.selectedIdsListenable,
 });

 final List<ProjectRecord> projects;
 final bool isLoading;
 final String? error;
 final Set<String> selectedIds;
 final ValueChanged<String> onToggle;
 final VoidCallback onClear;
 final ValueListenable<Set<String>>? selectedIdsListenable;

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 title: const Text('Group Projects Into A Program'),
 backgroundColor: Colors.white,
 elevation: 0,
 foregroundColor: Colors.black87,
 ),
 body: SafeArea(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: selectedIdsListenable == null
 ? _GroupProjectsCard(
 projects: projects,
 isLoading: isLoading,
 error: error,
 selectedIds: selectedIds,
 onToggle: onToggle,
 onClear: onClear,
 expandedView: true,
 )
 : ValueListenableBuilder<Set<String>>(
 valueListenable: selectedIdsListenable!,
 builder: (context, ids, _) {
 return _GroupProjectsCard(
 projects: projects,
 isLoading: isLoading,
 error: error,
 selectedIds: ids,
 onToggle: onToggle,
 onClear: onClear,
 expandedView: true,
 selectedIdsListenable: selectedIdsListenable,
 );
 },
 ),
 ),
 ),
 );
 }
}

class _ProjectTableRowFromFirebase extends StatelessWidget {
 const _ProjectTableRowFromFirebase({required this.project});

 final ProjectRecord project;
 static final Set<String> _openingProjectIds = <String>{};

 String _lastEditorName() {
 final ownerName = project.ownerName.trim();
 if (ownerName.isNotEmpty && !ownerName.contains('@')) return ownerName;
 final email = project.ownerEmail.trim();
 if (email.isNotEmpty) {
 final username =
 email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
 return username
 .split(' ')
 .map((part) => part.isEmpty
 ? ''
 : '${part[0].toUpperCase()}${part.substring(1)}')
 .join(' ');
 }
 return 'Unknown';
 }

 String _relativeTimeString(DateTime? time) {
 if (time == null) return 'moments ago';
 final diff = DateTime.now().difference(time);
 if (diff.isNegative) {
 return 'just now';
 }
 if (diff.inDays >= 1) {
 return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
 }
 if (diff.inHours >= 1) {
 return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
 }
 if (diff.inMinutes >= 1) {
 return diff.inMinutes == 1
 ? '1 minute ago'
 : '${diff.inMinutes} minutes ago';
 }
 return 'moments ago';
 }

 Color _stageBackgroundColor(String phase) {
 final normalized = phase.toLowerCase();
 if (normalized.contains('execution')) return const Color(0xFFE6FAF1);
 if (normalized.contains('planning')) return const Color(0xFFFFF1CC);
 if (normalized.contains('front end')) return const Color(0xFFFFF8E1);
 if (normalized.contains('design')) return const Color(0xFFE8E6FF);
 if (normalized.contains('launch')) return const Color(0xFFE0F2FE);
 if (normalized.contains('close')) return const Color(0xFFEFF6FF);
 if (normalized.contains('completed')) return const Color(0xFFE8F0FF);
 if (normalized.contains('initiation') || normalized.contains('idea')) {
 return const Color(0xFFF3F4F8);
 }
 return const Color(0xFFF3F4F8);
 }

 Color _stageForegroundColor(String phase) {
 final normalized = phase.toLowerCase();
 if (normalized.contains('execution')) return const Color(0xFF14734E);
 if (normalized.contains('planning')) return const Color(0xFF875900);
 if (normalized.contains('front end')) return const Color(0xFF9A6700);
 if (normalized.contains('design')) return const Color(0xFF5941C6);
 if (normalized.contains('launch')) return const Color(0xFF075985);
 if (normalized.contains('close')) return const Color(0xFF1D4ED8);
 if (normalized.contains('completed')) return const Color(0xFF1D4ED8);
 if (normalized.contains('initiation') || normalized.contains('idea')) {
 return const Color(0xFF4A4D57);
 }
 return const Color(0xFF4A4D57);
 }

 Color _progressStatusBackground(ProjectProgressHealth status) {
 switch (status) {
 case ProjectProgressHealth.completed:
 return const Color(0xFFE0EDFF);
 case ProjectProgressHealth.onTrack:
 return const Color(0xFFDCFCE7);
 case ProjectProgressHealth.behind:
 return const Color(0xFFFEE2E2);
 case ProjectProgressHealth.inProgress:
 return const Color(0xFFFEF3C7);
 }
 }

 Color _progressStatusForeground(ProjectProgressHealth status) {
 switch (status) {
 case ProjectProgressHealth.completed:
 return const Color(0xFF1E40AF);
 case ProjectProgressHealth.onTrack:
 return const Color(0xFF166534);
 case ProjectProgressHealth.behind:
 return const Color(0xFF991B1B);
 case ProjectProgressHealth.inProgress:
 return const Color(0xFF92400E);
 }
 }

 String _progressStatusLabel(ProjectProgressHealth status) {
 switch (status) {
 case ProjectProgressHealth.completed:
 return 'Completed';
 case ProjectProgressHealth.onTrack:
 return 'On Track';
 case ProjectProgressHealth.behind:
 return 'Behind';
 case ProjectProgressHealth.inProgress:
 return 'In Progress';
 }
 }

 Future<void> _openProject(BuildContext context) async {
 if (_openingProjectIds.contains(project.id)) {
 debugPrint('Ignoring duplicate open request for project: ${project.id}');
 return;
 }
 _openingProjectIds.add(project.id);
 debugPrint('Opening project: ${project.id} - ${project.name}');

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
 builder: (context) => Center(
 child: Container(
 width: 140,
 height: 140,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.15),
 blurRadius: 24,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: const [
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
 ).whenComplete(() {
 loadingDialogVisible = false;
 });
 loadingDialogVisible = true;

 try {
 final provider = ProjectDataInherited.read(context);
 debugPrint('Calling loadFromFirebase for project: ${project.id}');

 final success = await provider
 .loadFromFirebase(project.id)
 .timeout(const Duration(seconds: 35));

 debugPrint('Load result: $success, error: ${provider.lastError}');

 if (!context.mounted) return;
 dismissLoadingDialog();

 if (success) {
 final checkpointRoute = project.checkpointRoute.isNotEmpty
 ? project.checkpointRoute
 : await ProjectNavigationService.instance.getLastPage(project.id);
 if (!context.mounted) return;
 debugPrint(
 'Project loaded successfully, navigating to checkpoint: $checkpointRoute');

 final screen = NavigationRouteResolver.resolveCheckpointToScreen(
 checkpointRoute.isEmpty ? 'initiation' : checkpointRoute,
 context,
 );

 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => screen ?? const InitiationPhaseScreen(),
 ),
 );
 } else {
 debugPrint('Failed to load project: ${provider.lastError}');
 showDialog(
 context: context,
 builder: (dialogContext) => AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.red.shade50,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(
 Icons.error_outline,
 color: Colors.red.shade700,
 size: 24,
 ),
 ),
 const SizedBox(width: 12),
 const Expanded(child: Text('Failed to Load Project')),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Project: ${project.name}',
 style: const TextStyle(
 fontWeight: FontWeight.w600,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 provider.lastError ??
 'Unknown error occurred while loading project data.',
 style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
 ),
 const SizedBox(height: 12),
 Text(
 'Please try again or contact support if the issue persists.',
 style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Close'),
 ),
 ElevatedButton(
 onPressed: () {
 Navigator.of(dialogContext).pop();
 _openProject(context);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF1A4DB3),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 24,
 vertical: 12,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 child: const Text('Retry'),
 ),
 ],
 ),
 );
 }
 } on TimeoutException catch (e, stackTrace) {
 debugPrint('Timeout opening project: $e');
 debugPrint('Stack trace: $stackTrace');

 if (!context.mounted) return;
 dismissLoadingDialog();
 showDialog(
 context: context,
 builder: (dialogContext) => AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.orange.shade50,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(Icons.timer_off_outlined,
 color: Colors.orange.shade700, size: 24),
 ),
 const SizedBox(width: 12),
 const Expanded(child: Text('Project Load Timed Out')),
 ],
 ),
 content: const Text(
 'The project is taking too long to load. Please retry in a moment.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Close'),
 ),
 ElevatedButton(
 onPressed: () {
 Navigator.of(dialogContext).pop();
 _openProject(context);
 },
 child: const Text('Retry'),
 ),
 ],
 ),
 );
 } catch (e, stackTrace) {
 debugPrint('Exception opening project: $e');
 debugPrint('Stack trace: $stackTrace');

 if (!context.mounted) return;
 dismissLoadingDialog();
 showDialog(
 context: context,
 builder: (dialogContext) => AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.red.shade50,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(Icons.error_outline,
 color: Colors.red.shade700, size: 24),
 ),
 const SizedBox(width: 12),
 const Expanded(child: Text('Error Opening Project')),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('An unexpected error occurred:',
 style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.grey.shade100,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 e.toString(),
 style: TextStyle(                  color: Colors.grey.shade800,
                  fontSize: 13,
                  fontFamily: appFontFamily,
 ),
 ),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Close'),
 ),
 ],
 ),
 );
 } finally {
 if (context.mounted) {
 dismissLoadingDialog();
 }
 _openingProjectIds.remove(project.id);
 }
 }

 Future<void> _renameProject(BuildContext context) async {
 final nameController = TextEditingController(text: project.name);
 final formKey = GlobalKey<FormState>();

 final newName = await showDialog<String>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 final theme = Theme.of(dialogContext);
 final scheme = theme.colorScheme;

 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: scheme.primary.withOpacity(0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child:
 Icon(Icons.edit_outlined, color: scheme.primary, size: 24),
 ),
 const SizedBox(width: 12),
 const Text('Rename Project'),
 ],
 ),
 content: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Enter a new name for "${project.name}"',
 style: TextStyle(color: Colors.grey[700], fontSize: 14),
 ),
 const SizedBox(height: 20),
 VoiceTextFormField(
 controller: nameController,
 autofocus: true,
 decoration: InputDecoration(
 labelText: 'Project Name',
 prefixIcon: const Icon(Icons.work_outline),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 filled: true,
 fillColor:
 scheme.surfaceContainerHighest.withOpacity(0.3),
 ),
 validator: (value) {
 if (value == null || value.trim().isEmpty) {
 return 'Please enter a project name';
 }
 if (value.trim().length < 3) {
 return 'Project name must be at least 3 characters';
 }
 return null;
 },
 textInputAction: TextInputAction.done,
 onFieldSubmitted: (_) {
 if (formKey.currentState?.validate() ?? false) {
 Navigator.of(dialogContext)
 .pop(nameController.text.trim());
 }
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (formKey.currentState?.validate() ?? false) {
 Navigator.of(dialogContext).pop(nameController.text.trim());
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: scheme.primary,
 foregroundColor: scheme.onPrimary,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Rename'),
 ),
 ],
 );
 },
 );

 if (newName == null || newName == project.name || !context.mounted) return;

 // Show loading indicator
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => const Center(child: CircularProgressIndicator()),
 );

 try {
 await ProjectService.updateProject(
 project.id,
 {'projectName': newName},
 );

 if (!context.mounted) return;

 Navigator.of(context).pop(); // Close loading dialog

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Project renamed to "$newName"'),
 backgroundColor: Colors.green,
 duration: const Duration(seconds: 2),
 ),
 );
 } catch (e) {
 if (Navigator.canPop(context)) {
 Navigator.of(context).pop();
 }
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error renaming project: $e'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 }
 }

 Future<void> _deleteProject(BuildContext context) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) {
 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.red.shade50,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(Icons.warning_amber_rounded,
 color: Colors.red.shade700, size: 24),
 ),
 const SizedBox(width: 12),
 const Text('Delete Project?'),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Are you sure you want to delete "${project.name}"?',
 style:
 const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 12),
 Text(
 'This action cannot be undone. All project data will be permanently removed.',
 style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.red,
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Delete'),
 ),
 ],
 );
 },
 );

 if (confirmed != true || !context.mounted) return;

 // Show loading indicator
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => const Center(child: CircularProgressIndicator()),
 );

 try {
 await ProjectService.deleteProject(project.id);

 if (!context.mounted) return;

 Navigator.of(context).pop(); // Close loading dialog

 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project deleted successfully'),
 backgroundColor: Colors.green,
 duration: Duration(seconds: 2),
 ),
 );
 } catch (e) {
 if (Navigator.canPop(context)) {
 Navigator.of(context).pop();
 }
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error deleting project: $e'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 }
 }

 @override
 Widget build(BuildContext context) {
 final displayName =
 project.name.isNotEmpty ? project.name : 'Untitled Project';
 final phaseLabel = project.progressSnapshot.currentPhase.trim().isEmpty
 ? (project.status.isNotEmpty ? project.status : 'Initiation')
 : project.progressSnapshot.currentPhase.trim();
 final milestoneLabel =
 project.milestone.isNotEmpty ? project.milestone : 'Starting up';
 final progressValue = project.progressSnapshot.completion.clamp(0.0, 1.0);
 final progressPercent = project.progressSnapshot.completionPercent;
 final progressDetail = project.progressSnapshot.totalActivities > 0
 ? '${project.progressSnapshot.implementedActivities}/${project.progressSnapshot.totalActivities} implemented'
 : project.progressSnapshot.totalMilestones > 0
 ? '${project.progressSnapshot.achievedMilestones}/${project.progressSnapshot.totalMilestones} milestones'
 : 'Awaiting activity data';
 final investment = project.investmentMillions > 0
 ? '\$${project.investmentMillions.toStringAsFixed(1)}M'
 : 'Not set';

 return Padding(
 padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 flex: 32,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 InkWell(
 onTap: () => _openProject(context),
 child: Text(
 displayName,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 18,
 color: Color(0xFF1A4DB3),
 decoration: TextDecoration.underline,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 milestoneLabel,
 style: TextStyle(
 fontSize: 14,
 color: Colors.grey.shade600,
 letterSpacing: 0.2,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 6),
 Text(
 'Last edited by ${_lastEditorName()} - ${_relativeTimeString(project.updatedAt)}',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey.shade500,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Expanded(
 flex: 16,
 child: Padding(
 padding: const EdgeInsets.only(right: 8),
 child: Center(
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 color: _stageBackgroundColor(phaseLabel),
 borderRadius: BorderRadius.circular(24),
 ),
 child: Text(
 phaseLabel,
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 13,
 color: _stageForegroundColor(phaseLabel),
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 textAlign: TextAlign.center,
 ),
 ),
 ),
 ),
 ),
 Expanded(
 flex: 20,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Row(
 children: [
 Text(
 '$progressPercent%',
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 progressDetail,
 style: TextStyle(
 fontSize: 11,
 color: Colors.grey.shade600,
 fontWeight: FontWeight.w600,
 ),
 textAlign: TextAlign.right,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(999),
 child: LinearProgressIndicator(
 value: progressValue,
 minHeight: 8,
 backgroundColor: const Color(0xFFF3F4F6),
 valueColor: AlwaysStoppedAnimation<Color>(
 _progressStatusForeground(
 project.progressSnapshot.health),
 ),
 ),
 ),
 const SizedBox(height: 8),
 Align(
 alignment: Alignment.center,
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10,
 vertical: 5,
 ),
 decoration: BoxDecoration(
 color: _progressStatusBackground(
 project.progressSnapshot.health,
 ),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 7,
 height: 7,
 decoration: BoxDecoration(
 color: _progressStatusForeground(
 project.progressSnapshot.health,
 ),
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 6),
 Text(
 _progressStatusLabel(
 project.progressSnapshot.health),
 style: TextStyle(
 color: _progressStatusForeground(
 project.progressSnapshot.health,
 ),
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 Expanded(
 flex: 12,
 child: Padding(
 padding: const EdgeInsets.only(right: 8),
 child: Center(child: _OwnerNameCell(project: project)),
 ),
 ),
 Expanded(
 flex: 10,
 child: Padding(
 padding: const EdgeInsets.only(right: 8),
 child: Center(
 child: Text(
 investment,
 style: TextStyle(
 color: Colors.grey.shade700,
 fontWeight: FontWeight.w700,
 fontSize: 14,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 textAlign: TextAlign.center,
 ),
 ),
 ),
 ),
 Expanded(
 flex: 18,
 child: Center(
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Flexible(
 child: TextButton.icon(
 onPressed: () => _openProject(context),
 icon: const Icon(Icons.launch, size: 18),
 label: const Text('Open'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF1A4DB3),
 padding: const EdgeInsets.symmetric(
 horizontal: 10,
 vertical: 10,
 ),
 textStyle: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 13,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 ),
 ),
 const SizedBox(width: 6),
 PopupMenuButton<String>(
 onSelected: (value) {
 if (value == 'rename') {
 _renameProject(context);
 } else if (value == 'delete') {
 _deleteProject(context);
 }
 },
 itemBuilder: (context) => [
 const PopupMenuItem(
 value: 'rename',
 child: Row(
 children: [
 Icon(Icons.edit_outlined,
 size: 20, color: Color(0xFF1A4DB3)),
 SizedBox(width: 12),
 Text('Rename',
 style: TextStyle(
 fontWeight: FontWeight.w600, fontSize: 15)),
 ],
 ),
 ),
 const PopupMenuItem(
 value: 'delete',
 child: Row(
 children: [
 Icon(Icons.delete_outline,
 size: 20, color: Colors.red),
 SizedBox(width: 12),
 Text('Delete',
 style: TextStyle(
 fontWeight: FontWeight.w600,
 color: Colors.red,
 fontSize: 15)),
 ],
 ),
 ),
 ],
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.grey.shade50,
 borderRadius: BorderRadius.circular(10),
 border:
 Border.all(color: Colors.grey.shade300, width: 1.5),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.more_horiz,
 size: 20, color: Colors.grey.shade700),
 ],
 ),
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

class _OwnerNameCell extends StatefulWidget {
 const _OwnerNameCell({required this.project});

 final ProjectRecord project;

 @override
 State<_OwnerNameCell> createState() => _OwnerNameCellState();
}

class _OwnerNameCellState extends State<_OwnerNameCell> {
 static final Map<String, String> _displayNameCache = <String, String>{};
 static final Map<String, Future<String>> _pendingLookups =
 <String, Future<String>>{};

 String _resolved = 'Unknown';

 @override
 void initState() {
 super.initState();
 _resolved = _initialName();
 // Resolve asynchronously from Firestore with cache
 _resolveFromUserDoc();
 }

 @override
 void didUpdateWidget(covariant _OwnerNameCell oldWidget) {
 super.didUpdateWidget(oldWidget);
 final ownerChanged = oldWidget.project.ownerId != widget.project.ownerId ||
 oldWidget.project.ownerEmail != widget.project.ownerEmail ||
 oldWidget.project.ownerName != widget.project.ownerName;
 if (ownerChanged) {
 _resolved = _initialName();
 _resolveFromUserDoc();
 }
 }

 String _initialName() {
 final ownerName = widget.project.ownerName.trim();
 if (ownerName.isNotEmpty && !_looksLikeEmail(ownerName)) {
 return ownerName;
 }
 final email = widget.project.ownerEmail.trim();
 if (email.isNotEmpty) {
 return _prettifyFromEmail(email);
 }
 return 'Unknown';
 }

 bool _looksLikeEmail(String value) {
 final v = value.trim();
 return v.contains('@') && v.contains('.');
 }

 String _prettifyFromEmail(String email) {
 final beforeAt = email.split('@').first;
 final cleaned = beforeAt.replaceAll(RegExp(r'[._-]+'), ' ').trim();
 if (cleaned.isEmpty) return 'Unknown';
 final parts = cleaned.split(RegExp(r'\s+'));
 final cased = parts.map((p) {
 if (p.isEmpty) return p;
 final lower = p.toLowerCase();
 return lower[0].toUpperCase() + lower.substring(1);
 }).join(' ');
 return cased;
 }

 Future<void> _resolveFromUserDoc() async {
 final uid = widget.project.ownerId.trim();
 if (uid.isEmpty) return;

 // Cached?
 final cached = _displayNameCache[uid];
 if (cached != null && cached.isNotEmpty) {
 if (mounted) setState(() => _resolved = cached);
 return;
 }

 final lookup = _pendingLookups[uid] ??= _fetchOwnerDisplayName(uid);

 try {
 final resolved = await lookup;
 if (resolved.isNotEmpty) {
 _displayNameCache[uid] = resolved;
 if (mounted && _resolved != resolved) {
 setState(() => _resolved = resolved);
 }
 }
 } catch (e) {
 debugPrint('Owner name resolve failed for $uid: $e');
 // Keep initial fallback
 } finally {
 if (identical(_pendingLookups[uid], lookup)) {
 _pendingLookups.remove(uid);
 }
 }
 }

 Future<String> _fetchOwnerDisplayName(String uid) async {
 final userModel = await UserService.getUser(uid);
 if (userModel == null) return _initialName();

 final displayName = userModel.displayName.trim();
 if (displayName.isNotEmpty) return displayName;

 return _prettifyFromEmail(userModel.email);
 }

 @override
 Widget build(BuildContext context) {
 return AnimatedSwitcher(
 duration: const Duration(milliseconds: 200),
 switchInCurve: Curves.easeOut,
 switchOutCurve: Curves.easeIn,
 child: Text(
 _resolved,
 key: ValueKey(_resolved),
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 15,
 color: Color(0xFF1E1F23),
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 textAlign: TextAlign.center,
 ),
 );
 }
}

class _SelectableProjectRowFromFirebase extends StatelessWidget {
 const _SelectableProjectRowFromFirebase({
 required this.project,
 required this.selected,
 required this.onTap,
 });

 final ProjectRecord project;
 final bool selected;
 final VoidCallback onTap;

 Color _dotColor(String status) {
 final normalized = status.toLowerCase();
 if (normalized.contains('execution')) return const Color(0xFF1EB980);
 if (normalized.contains('planning')) return const Color(0xFFFFB300);
 if (normalized.contains('design')) return const Color(0xFF6A4DE9);
 return const Color(0xFF8A92A6);
 }

 @override
 Widget build(BuildContext context) {
 final displayName =
 project.name.isNotEmpty ? project.name : 'Untitled Project';
 final statusLabel =
 project.status.isNotEmpty ? project.status : 'Initiation';

 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(24),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 color: selected ? const Color(0xFFFFF7E6) : const Color(0xFFF7F8FD),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(
 color: selected ? const Color(0xFFFFCF6B) : const Color(0xFFE3E6F2),
 width: 2,
 ),
 boxShadow: selected
 ? [
 BoxShadow(
 color: const Color(0xFFFFC14A).withOpacity(0.4),
 blurRadius: 28,
 offset: const Offset(0, 14),
 ),
 ]
 : [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 22,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 18,
 height: 18,
 decoration: BoxDecoration(
 color: _dotColor(statusLabel),
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 18),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 displayName,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 17,
 color: Color(0xFF101218),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 6),
 Text(
 statusLabel,
 style: TextStyle(
 color: Colors.grey.shade600,
 fontSize: 15,
 fontWeight: FontWeight.w500,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 const SizedBox(width: 20),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 decoration: BoxDecoration(
 color: selected ? const Color(0xFF111111) : Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(
 color: selected ? Colors.black : const Color(0xFFE1E4ED),
 width: 1.5,
 ),
 ),
 child: Text(
 selected ? 'Selected' : 'Tap to include',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 color: selected ? Colors.white : const Color(0xFF4A4D57),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _SummaryStat extends StatelessWidget {
 const _SummaryStat({
 required this.label,
 required this.value,
 required this.caption,
 });

 final String label;
 final String value;
 final String caption;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: const Color(0xFFF7F8FD),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE4E6F1), width: 1.5),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 color: Color(0xFF5B5D7A),
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 value,
 style: const TextStyle(
 fontWeight: FontWeight.w800,
 fontSize: 28,
 color: Color(0xFF14161D),
 ),
 ),
 const SizedBox(height: 10),
 Text(
 caption,
 style: TextStyle(
 color: Colors.grey.shade600,
 fontSize: 15,
 height: 1.5,
 ),
 ),
 ],
 ),
 );
 }
}

class _TableHeaderLabel extends StatelessWidget {
 const _TableHeaderLabel(this.label, {this.alignment = Alignment.centerLeft});

 final String label;
 final Alignment alignment;

 @override
 Widget build(BuildContext context) {
 return Align(
 alignment: alignment,
 child: Text(
 label,
 style: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 15,
 color: Color(0xFF53556B),
 letterSpacing: 0.3,
 ),
 textAlign: TextAlign.center,
 ),
 );
 }
}

class _FrostedSurface extends StatelessWidget {
 const _FrostedSurface({required this.child, this.padding});

 final Widget child;
 final EdgeInsetsGeometry? padding;

 @override
 Widget build(BuildContext context) {
 final media = MediaQuery.of(context);
 final isCompact = media.size.width < 600;
 final resolvedPadding = padding ?? EdgeInsets.all(isCompact ? 20 : 24);

 return Container(
 padding: resolvedPadding,
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.92),
 borderRadius: BorderRadius.circular(isCompact ? 22 : 28),
 border: Border.all(color: const Color(0xFFE4E7F3)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 28,
 offset: const Offset(0, 18),
 ),
 ],
 ),
 child: child,
 );
 }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Premium User Greeting Widget – world‑class personalised greeting
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopPremiumGreeting extends StatelessWidget {
 const _DesktopPremiumGreeting({required this.isBasicPlan});

 final bool isBasicPlan;

 /// Time‑aware greeting prefix
 static String _timePrefix() {
 final hour = DateTime.now().hour;
 if (hour < 12) return 'Good morning';
 if (hour < 17) return 'Good afternoon';
 return 'Good evening';
 }

 /// Extract initials (up to 2 chars) from display name
 static String _initials(String name) {
 final parts = name.trim().split(RegExp(r'\s+'));
 if (parts.length >= 2) {
 return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
 }
 return name.isNotEmpty ? name[0].toUpperCase() : 'U';
 }

 @override
 Widget build(BuildContext context) {
 final textTheme = Theme.of(context).textTheme;
 final displayName = FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final firstName = displayName.split(' ').first;
 final initials = _initials(displayName);
 final greeting = '${_timePrefix()}, $firstName';

 // Photo URL from Firebase Auth
 final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 Color(0xFFFFFFFF),
 Color(0xFFF7F9FB),
 ],
 ),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(
 color: const Color(0xFFE0E3E5).withOpacity(0.6),
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.03),
 blurRadius: 20,
 offset: const Offset(0, 4),
 ),
 BoxShadow(
 color: const Color(0xFFFFCC00).withOpacity(0.06),
 blurRadius: 32,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: Row(
 children: [
 // ── Avatar ───────────────────────────────────────────────────
 Container(
 width: 56,
 height: 56,
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 Color(0xFFFFCC00),
 Color(0xFFFFE066),
 Color(0xFFFFD633),
 ],
 ),
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFFFFCC00).withOpacity(0.35),
 blurRadius: 14,
 offset: const Offset(0, 5),
 ),
 ],
 ),
 child: Center(
 child: photoUrl != null && photoUrl.isNotEmpty
 ? ClipRRect(
 borderRadius: BorderRadius.circular(14),
 child: Image.network(
 photoUrl,
 width: 46,
 height: 46,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => _buildInitialsText(initials, 24),
 ),
 )
 : _buildInitialsText(initials, 24),
 ),
 ),
 const SizedBox(width: 20),

 // ── Greeting text ────────────────────────────────────────────
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 greeting,
 style: textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.w800,
 color: const Color(0xFF0F1117),
 letterSpacing: -0.02,
 height: 1.2,
 ),
 ),
 const SizedBox(height: 6),
 Row(
 children: [
 // Plan badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: isBasicPlan
 ? const Color(0xFFEFF6FF)
 : const Color(0xFFFFF8E1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: isBasicPlan
 ? const Color(0xFFBFDBFE)
 : const Color(0xFFFFE082),
 width: 0.5,
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 isBasicPlan ? Icons.star_outline : Icons.workspace_premium_outlined,
 size: 14,
 color: isBasicPlan
 ? const Color(0xFF2563EB)
 : const Color(0xFFF59E0B),
 ),
 const SizedBox(width: 4),
 Text(
 isBasicPlan ? 'Basic Plan' : 'Pro Plan',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.04,
 color: isBasicPlan
 ? const Color(0xFF2563EB)
 : const Color(0xFFB45309),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Flexible(
 child: Text(
 isBasicPlan ? 'Basic plan dashboard' : 'Project dashboard',
 style: textTheme.titleMedium?.copyWith(
 fontWeight: FontWeight.w600,
 color: const Color(0xFF414754),
 letterSpacing: 0.01,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ],
 ),
 ),

 // ── Online indicator + date ──────────────────────────────────
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: const Color(0xFF22C55E),
 shape: BoxShape.circle,
 border: Border.all(color: Colors.white, width: 1.5),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF22C55E).withOpacity(0.4),
 blurRadius: 4,
 offset: const Offset(0, 1),
 ),
 ],
 ),
 ),
 const SizedBox(width: 6),
 Text(
 'Online',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF22C55E),
 letterSpacing: 0.04,
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 _formatDate(),
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Colors.grey.shade500,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildInitialsText(String initials, double fontSize) {
 return Text(
 initials,
 style: TextStyle(
 fontSize: fontSize,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF191C1D),
 height: 1,
 ),
 );
 }

 static String _formatDate() {
 final now = DateTime.now();
 const months = [
 '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
 ];
 return '${months[now.month]} ${now.day}, ${now.year}';
 }
}


// ═══════════════════════════════════════════════════════════════════════════
// Compact Action Button — horizontal button used for "Group Into A Program"
// and "Project Logs" on the project dashboard.
// ═══════════════════════════════════════════════════════════════════════════

class _CompactActionButton extends StatefulWidget {
 const _CompactActionButton({
 required this.label,
 required this.subtitle,
 required this.icon,
 required this.accent,
 required this.onTap,
 });

 final String label;
 final String subtitle;
 final IconData icon;
 final Color accent;
 final VoidCallback onTap;

 @override
 State<_CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<_CompactActionButton> {
 bool _isHovered = false;

 @override
 Widget build(BuildContext context) {
 return MouseRegion(
 onEnter: (_) {
 if (!mounted || _isHovered) return;
 setState(() => _isHovered = true);
 },
 onExit: (_) {
 if (!mounted || !_isHovered) return;
 setState(() => _isHovered = false);
 },
 child: GestureDetector(
 onTap: widget.onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 curve: Curves.easeOut,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: _isHovered
 ? widget.accent.withOpacity(0.08)
 : Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: _isHovered
 ? widget.accent.withOpacity(0.4)
 : const Color(0xFFE2E8F0),
 width: 1.5,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(_isHovered ? 0.06 : 0.03),
 blurRadius: _isHovered ? 12 : 8,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: widget.accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(widget.icon, size: 20, color: widget.accent),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 widget.label,
 style: TextStyle(
 decoration: TextDecoration.none,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF0F172A),
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 2),
 Text(
 widget.subtitle,
 style: const TextStyle(
 decoration: TextDecoration.none,
 fontSize: 11.5,
 color: Color(0xFF64748B),
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Icon(Icons.arrow_forward_ios_rounded,
 size: 14,
 color: _isHovered
 ? widget.accent
 : const Color(0xFF94A3B8)),
 ],
 ),
 ),
 ),
 );
 }
}
