import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/portfolio_model.dart';
import '../models/program_model.dart';
import '../providers/project_data_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/portfolio_service.dart';
import '../services/program_service.dart';
import '../services/project_navigation_service.dart';
import '../services/project_service.dart';
import '../utils/navigation_route_resolver.dart';
import 'initiation_phase_screen.dart';
import 'program_dashboard_mobile_screen.dart';
import 'portfolio_dashboard_screen.dart';
import 'project_workspace_dashboard_screen.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import '../widgets/dashboard_bottom_nav_bar.dart';
import '../widgets/kaz_ai_chat_bubble.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens extracted from the HTML source (Material You / Tailwind config)
// ─────────────────────────────────────────────────────────────────────────────
class _Tokens {
  // Surfaces
  static const background = Color(0xFFF7F9FB);
  static const surface = Color(0xFFF7F9FB);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const surfaceContainerHigh = Color(0xFFE6E8EA);
  static const surfaceContainerHighest = Color(0xFFE0E3E5);

  // Text
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF414754);
  static const onSecondaryFixed = Color(0xFF1C1B1B);
  static const outline = Color(0xFF717786);
  static const outlineVariant = Color(0xFFC0C6D6);

  // Brand / Accent
  static const primary = Color(0xFFB45309);
  static const primaryContainer = Color(0xFFD97706);
  static const tertiaryFixedDim = Color(0xFFFABD00);
  static const tertiary = Color(0xFF755700);
  static const error = Color(0xFFBA1A1A);
  static const inverseSurface = Color(0xFF2D3133);
  static const inverseOnSurface = Color(0xFFEFF1F3);

  // Spacing
  static const containerMargin = 16.0;
  static const sectionGap = 24.0;
  static const gridGutter = 12.0;
  static const stackGap = 12.0;
  static const cardPadding = 20.0;

  // Radius
  static const radiusXl = 12.0;
  static const radiusFull = 9999.0;
}

class ProjectDashboardMobileShell extends StatefulWidget {
  const ProjectDashboardMobileShell({
    super.key,
    required this.isBasicPlan,
    required this.onAddProject,
  });

  final bool isBasicPlan;
  final Future<void> Function() onAddProject;

  @override
  State<ProjectDashboardMobileShell> createState() =>
      _ProjectDashboardMobileShellState();
}

class _ProjectDashboardMobileShellState
    extends State<ProjectDashboardMobileShell> {
  final TextEditingController _searchProjects = TextEditingController();
  final TextEditingController _searchGrouping = TextEditingController();
  String _query = '';
  String _groupQuery = '';
  int _bottomNavIndex = 0;

  @override
  void dispose() {
    _searchProjects.dispose();
    _searchGrouping.dispose();
    super.dispose();
  }

  String _owner(ProjectRecord p) {
    final name = p.ownerName.trim();
    if (name.isNotEmpty && !name.contains('@')) return name;
    final email = p.ownerEmail.trim();
    return email.isEmpty ? 'Unknown' : email.split('@').first;
  }

  Future<void> _openProject(ProjectRecord project) async {
    var loadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    void closeLoadingDialog() {
      if (!loadingDialogOpen || !mounted) return;
      loadingDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      final provider = ProjectDataInherited.read(context);
      final success = await provider
          .loadFromFirebase(project.id)
          .timeout(const Duration(seconds: 35));
      if (!mounted) return;
      closeLoadingDialog();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.lastError ?? 'Unable to open project'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final checkpoint = project.checkpointRoute.isNotEmpty
          ? project.checkpointRoute
          : await ProjectNavigationService.instance.getLastPage(project.id);
      if (!mounted) return;
      final screen = NavigationRouteResolver.resolveCheckpointToScreen(
        checkpoint.isEmpty ? 'initiation' : checkpoint,
        context,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => screen ?? const InitiationPhaseScreen()),
      );
    } on TimeoutException {
      if (!mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project load timed out. Please retry.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening project: $e')),
      );
    } finally {
      closeLoadingDialog();
    }
  }

  void _navigateToProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgramDashboardMobileScreen()),
    );
  }

  void _navigateToRegularProjects() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const ProjectWorkspaceDashboardScreen(isBasicPlan: true)),
    );
  }

  void _navigateToProjects() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const ProjectWorkspaceDashboardScreen(isBasicPlan: false)),
    );
  }

  void _navigateToPortfolio() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              backgroundColor: _Tokens.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuthService.signOut();
        if (mounted) context.go('/');
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

  // ─── Stat card matching the HTML 2×2 grid ───────────────────────────────
  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    bool filled = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: _Tokens.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(_Tokens.radiusXl),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_Tokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Tokens.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(_Tokens.radiusXl),
                ),
                child: Icon(icon,
                    color: iconColor, size: 24, fill: filled ? 1.0 : 0.0),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: _Tokens.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: _Tokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                width: 32,
                decoration: BoxDecoration(
                  color: _Tokens.onSecondaryFixed,
                  borderRadius: BorderRadius.circular(_Tokens.radiusFull),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search bar matching the HTML input style ────────────────────────────
  Widget _searchBar({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(_Tokens.radiusXl),
      ),
      child: VoiceTextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _Tokens.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: _Tokens.outline),
          prefixIcon:
              const Icon(Icons.search, color: _Tokens.outline, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_Tokens.radiusXl),
            borderSide:
                BorderSide(color: _Tokens.primary.withOpacity(0.2), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_Tokens.radiusXl),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── Project list item ──────────────────────────────────────────────────
  Widget _projectItem(ProjectRecord p) {
    final snapshot = p.progressSnapshot;
    final pct = snapshot.completionPercent;
    final phase = snapshot.currentPhase.trim().isEmpty
        ? (p.status.trim().isEmpty ? 'Initiation' : p.status.trim())
        : snapshot.currentPhase.trim();
    String healthLabel;
    Color healthColor;
    switch (snapshot.health) {
      case ProjectProgressHealth.completed:
        healthLabel = 'Completed';
        healthColor = const Color(0xFFD97706);
        break;
      case ProjectProgressHealth.onTrack:
        healthLabel = 'On Track';
        healthColor = const Color(0xFF166534);
        break;
      case ProjectProgressHealth.behind:
        healthLabel = 'Behind';
        healthColor = const Color(0xFFB91C1C);
        break;
      case ProjectProgressHealth.inProgress:
        healthLabel = 'In Progress';
        healthColor = const Color(0xFF92400E);
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _Tokens.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openProject(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _Tokens.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name.isEmpty ? 'Untitled Project' : p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _Tokens.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: healthColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        healthLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: healthColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$phase - ${_owner(p)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Tokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 6,
                          backgroundColor: _Tokens.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 80
                                ? const Color(0xFF16A34A)
                                : pct >= 50
                                    ? _Tokens.primary
                                    : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _Tokens.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Empty state matching the HTML dashed-border illustration ────────────
  Widget _emptyState({required String message}) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_Tokens.radiusXl),
        border: Border.all(
          color: _Tokens.outlineVariant.withOpacity(0.5),
          width: 2,
          style: BorderStyle.solid,
        ),
        color: _Tokens.surface.withOpacity(0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined,
              size: 48, color: _Tokens.outlineVariant),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: _Tokens.outline,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final projects$ = user == null
        ? Stream.value(const <ProjectRecord>[])
        : ProjectService.streamProjects(ownerId: user.uid, filterByOwner: true);
    final programs$ = user == null
        ? Stream.value(const <ProgramModel>[])
        : ProgramService.streamPrograms(ownerId: user.uid);
    final portfolios$ = user == null
        ? Stream.value(const <PortfolioModel>[])
        : PortfolioService.streamPortfolios(ownerId: user.uid);

    return StreamBuilder<List<ProjectRecord>>(
      stream: projects$,
      builder: (context, projectSnap) {
        final all = projectSnap.data ?? const <ProjectRecord>[];
        final singles = widget.isBasicPlan
            ? all.where((e) => e.isBasicPlanProject).toList()
            : all.where((e) => !e.isBasicPlanProject).toList();
        singles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final filteredList = _query.trim().isEmpty
            ? singles
            : singles.where((e) {
                final q = _query.toLowerCase();
                return e.name.toLowerCase().contains(q) ||
                    e.status.toLowerCase().contains(q) ||
                    _owner(e).toLowerCase().contains(q);
              }).toList();
        final groupingList = _groupQuery.trim().isEmpty
            ? singles
            : singles.where((e) {
                final q = _groupQuery.toLowerCase();
                return e.name.toLowerCase().contains(q) ||
                    e.status.toLowerCase().contains(q);
              }).toList();

        return StreamBuilder<List<ProgramModel>>(
          stream: programs$,
          builder: (context, programSnap) {
            return StreamBuilder<List<PortfolioModel>>(
              stream: portfolios$,
              builder: (context, portfolioSnap) {
                final programCount = programSnap.data?.length ?? 0;
                final portfolioCount = portfolioSnap.data?.length ?? 0;
                final basicCount =
                    all.where((e) => e.isBasicPlanProject).length;
                final singleCount = singles.length;

                return Scaffold(
                  backgroundColor: _Tokens.background,
                  body: SafeArea(
                    top: true,
                    child: Stack(
                      children: [
                        // ── Top App Bar (unified with sidebar pages) ────────────
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: _Tokens.surfaceContainerLowest,
                              border: Border(
                                bottom: BorderSide(
                                    color: _Tokens.outlineVariant
                                        .withOpacity(0.5)),
                              ),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  // Hamburger menu
                                  IconButton(
                                    icon: const Icon(Icons.menu,
                                        color: _Tokens.onSurface, size: 24),
                                    tooltip: 'Open menu',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                        minWidth: 40, minHeight: 40),
                                    onPressed: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/');
                                      }
                                    },
                                  ),
                                  const Spacer(),
                                  // Center: NDUPROJECT brand
                                  const Text(
                                    'NDUPROJECT',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _Tokens.onSurface,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Right: Notification bell
                                  IconButton(
                                    icon: const Icon(
                                        Icons.notifications_none_rounded,
                                        color: _Tokens.onSurface,
                                        size: 22),
                                    tooltip: 'Notifications',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                        minWidth: 40, minHeight: 40),
                                    onPressed: () {
                                      // Placeholder for notification action
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  // Right: Yellow chat "C" button
                                  GestureDetector(
                                    onTap: () =>
                                        KazAiChatBubble.openChat(context),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: _Tokens.tertiaryFixedDim,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'C',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Breadcrumb bar ────────────────────────────────────
                        Positioned(
                          top: 56,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _Tokens.surfaceContainerLowest,
                              border: Border(
                                bottom: BorderSide(
                                    color: _Tokens.outlineVariant
                                        .withOpacity(0.5)),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _Tokens.surfaceContainerLowest,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _Tokens.outlineVariant
                                            .withOpacity(0.3)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(Icons.chevron_left_rounded,
                                      size: 18,
                                      color: _Tokens.onSurfaceVariant
                                          .withOpacity(0.4)),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Dashboard',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _Tokens.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Main Scrollable Content ──────────────────────────
                        Positioned.fill(
                          top: 96,
                          bottom: 72,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              _Tokens.containerMargin,
                              24,
                              _Tokens.containerMargin,
                              120,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Welcome Header ───────────────────────────
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _Tokens.surfaceContainerHigh,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.arrow_back,
                                            size: 18, color: _Tokens.onSurface),
                                        onPressed: () {
                                          if (context.canPop()) {
                                            context.pop();
                                          } else {
                                            context.go('/');
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _Tokens.surfaceContainerLowest,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        border: Border.all(
                                            color: _Tokens.outlineVariant),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.domain,
                                              size: 16,
                                              color: _Tokens.onSurfaceVariant),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Project workspace overview',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.05,
                                              color: _Tokens.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // ── Personalized Greeting (world‑class) ────────────
                                _PremiumUserGreeting(
                                    isBasicPlan: widget.isBasicPlan),
                                // ── Description (web only – hidden on Android/iOS) ──
                                if (kIsWeb) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.isBasicPlan
                                        ? 'Manage your basic plan project workspace. Build the core initiation details and upgrade when you are ready to unlock more sections.'
                                        : 'Manage all single projects before they are linked into programs or portfolios. Add new work, track status, and quickly roll three projects into a program when you are ready.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: _Tokens.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: _Tokens.sectionGap),

                                // ── Stat Cards Grid (2×2) ────────────────────
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: _Tokens.gridGutter,
                                  crossAxisSpacing: _Tokens.gridGutter,
                                  childAspectRatio: 0.82,
                                  children: [
                                    _statCard(
                                      label: 'Regular Projects',
                                      value: user == null
                                          ? 'Sign in to view'
                                          : basicCount.toString(),
                                      icon: Icons.folder_special,
                                      iconBg: const Color(0xFFF0FDFA),
                                      iconColor: const Color(0xFF0D9488),
                                      filled: true,
                                      onTap: _navigateToRegularProjects,
                                    ),
                                    _statCard(
                                      label: 'Projects',
                                      value: user == null
                                          ? 'Sign in to view'
                                          : singleCount.toString(),
                                      icon: Icons.folder,
                                      iconBg: const Color(0xFFFFF7E6),
                                      iconColor: _Tokens.primary,
                                      onTap: _navigateToProjects,
                                    ),
                                    _statCard(
                                      label: 'Programs',
                                      value: user == null
                                          ? 'Sign in to view'
                                          : programCount.toString(),
                                      icon: Icons.layers,
                                      iconBg: const Color(0xFFFAF5FF),
                                      iconColor: const Color(0xFF9333EA),
                                      onTap: _navigateToProgram,
                                    ),
                                    _statCard(
                                      label: 'Portfolios',
                                      value: user == null
                                          ? 'Sign in to view'
                                          : portfolioCount.toString(),
                                      icon: Icons.account_tree,
                                      iconBg: const Color(0xFFF0FDF4),
                                      iconColor: const Color(0xFF16A34A),
                                      onTap: _navigateToPortfolio,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: _Tokens.sectionGap),

                                // ── Single Projects Section ──────────────────
                                Container(
                                  padding:
                                      const EdgeInsets.all(_Tokens.cardPadding),
                                  decoration: BoxDecoration(
                                    color: _Tokens.surfaceContainerLowest,
                                    borderRadius:
                                        BorderRadius.circular(_Tokens.radiusXl),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            widget.isBasicPlan
                                                ? 'Regular Projects'
                                                : 'Projects',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: _Tokens.onSurface,
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {},
                                            style: TextButton.styleFrom(
                                              foregroundColor: _Tokens.primary,
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('See All',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.isBasicPlan
                                            ? 'Review all basic plan projects before upgrading to unlock more sections.'
                                            : 'Review all standalone projects before they are linked into programs or portfolios.',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: _Tokens.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: _Tokens.stackGap),

                                      // Info banner
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _Tokens.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                              _Tokens.radiusXl),
                                          border: Border.all(
                                            color: _Tokens.outlineVariant
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.trending_up,
                                                size: 18,
                                                color: _Tokens.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.isBasicPlan
                                                    ? 'Basic plan workspaces focus on initiation essentials'
                                                    : 'If more than 3 projects, group up to 3 into a program',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.05,
                                                  color:
                                                      _Tokens.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: _Tokens.stackGap),

                                      // Search
                                      _searchBar(
                                        controller: _searchProjects,
                                        hint: 'Search projects...',
                                        onChanged: (v) =>
                                            setState(() => _query = v),
                                      ),
                                      const SizedBox(height: _Tokens.stackGap),

                                      // Project list or empty state
                                      if (user == null)
                                        _emptyState(
                                            message: 'Sign in to view projects')
                                      else if (filteredList.isEmpty)
                                        _emptyState(
                                            message: 'No projects found')
                                      else
                                        ...filteredList
                                            .take(5)
                                            .map((p) => _projectItem(p)),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: _Tokens.sectionGap),

                                // ── Group Projects Section ───────────────────
                                if (!widget.isBasicPlan)
                                  Container(
                                    padding: const EdgeInsets.all(
                                        _Tokens.cardPadding),
                                    decoration: BoxDecoration(
                                      color: _Tokens.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                          _Tokens.radiusXl),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Group Projects Into A Program',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                  color: _Tokens.onSurface,
                                                  letterSpacing: -0.01,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {},
                                              style: TextButton.styleFrom(
                                                foregroundColor: _Tokens.error,
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text('See All',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'When you have more than three single projects, select up to three that share an outcome to create a new program.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: _Tokens.onSurfaceVariant,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: _Tokens.stackGap),

                                        // Filter chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _Tokens.surfaceContainerLow,
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            border: Border.all(
                                              color: _Tokens.outlineVariant,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.filter_list,
                                                  size: 18,
                                                  color:
                                                      _Tokens.onSurfaceVariant),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Up to 3 projects',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.05,
                                                  color:
                                                      _Tokens.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                            height: _Tokens.stackGap),

                                        // Search
                                        _searchBar(
                                          controller: _searchGrouping,
                                          hint: 'Search projects to group...',
                                          onChanged: (v) =>
                                              setState(() => _groupQuery = v),
                                        ),
                                        const SizedBox(
                                            height: _Tokens.stackGap),

                                        // CTA / empty state
                                        if (user == null)
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: _Tokens.onSecondaryFixed
                                                  .withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      _Tokens.radiusXl),
                                              border: Border.all(
                                                color: _Tokens.onSecondaryFixed
                                                    .withOpacity(0.1),
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Sign in to group projects',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                      _Tokens.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (groupingList.isEmpty)
                                          _emptyState(
                                              message: 'No projects to group')
                                        else
                                          ...groupingList
                                              .take(3)
                                              .map((p) => _projectItem(p)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // ── FAB ─────────────────────────────────────────────
                        Positioned(
                          right: 24,
                          bottom: 88,
                          child: FloatingActionButton(
                            onPressed: widget.onAddProject,
                            backgroundColor: _Tokens.primary,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 28),
                          ),
                        ),

                        // ── Bottom Navigation Bar ────────────────────────────
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: DashboardBottomNavBar(
                            currentIndex: _bottomNavIndex,
                            onNavigate: (index) {
                              setState(() => _bottomNavIndex = index);
                              switch (index) {
                                case 1:
                                  _navigateToProgram();
                                  break;
                                case 2:
                                  _navigateToPortfolio();
                                  break;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium User Greeting Widget – world‑class personalised greeting
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumUserGreeting extends StatelessWidget {
  const _PremiumUserGreeting({required this.isBasicPlan});

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
    final displayName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    final firstName = displayName.split(' ').first;
    final initials = _initials(displayName);
    final greeting = '${_timePrefix()}, $firstName';

    // Photo URL from Firebase Auth
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF7F9FB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E3E5).withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFFFCC00).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ───────────────────────────────────────────────────
          Container(
            width: 48,
            height: 48,
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFCC00).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildInitialsText(initials),
                      ),
                    )
                  : _buildInitialsText(initials),
            ),
          ),
          const SizedBox(width: 14),

          // ── Greeting text ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C1E),
                    letterSpacing: -0.02,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Plan badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBasicPlan
                            ? const Color(0xFFFFF7E6)
                            : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(6),
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
                            isBasicPlan
                                ? Icons.star_outline
                                : Icons.workspace_premium_outlined,
                            size: 11,
                            color: isBasicPlan
                                ? const Color(0xFFD97706)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isBasicPlan ? 'Basic Plan' : 'Pro Plan',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.04,
                              color: isBasicPlan
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isBasicPlan
                            ? 'Basic plan dashboard'
                            : 'Project dashboard',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF414754),
                          letterSpacing: 0.02,
                          height: 1.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Status dot (online indicator) ────────────────────────────
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsText(String initials) {
    return Text(
      initials,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF191C1D),
        height: 1,
      ),
    );
  }
}
