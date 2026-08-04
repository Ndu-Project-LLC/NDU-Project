// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// regular_project_dashboard_screen.dart
//
// World-class dashboard for REGULAR (basic plan) projects.
//
// Design philosophy:
//   "The Runway" — a calm, focused launchpad for teams starting their
//   project journey. Brand-aligned palette (yellow + blue), generous whitespace, card-first
//   composition, and a clear "what to do next" flow. Every element is
//   designed to reduce cognitive load for first-time project owners.
//
// Visual language:
//   - White canvas (#FFFFFF) matching the app surface
//   - Brand yellow accent (#FFC812) + info blue primary (#2563EB)
//     aligned with the overall NDU app theme (theme.dart)
//   - Sand/clay neutrals for surfaces

//   - Generous 28-32px radii, soft shadows
//   - Inter-style typography with tight tracking on display headings
//   - Bento-style asymmetric grid (not the typical 3-column exec layout)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

/// A world-class dashboard for REGULAR (basic plan) projects.
///
/// Shows all basic-plan workspaces owned by the current user with a calm,
/// onboarding-oriented layout. Designed to feel like a "runway" — a clear
/// place to start, with the next action always visible.
class RegularProjectDashboardScreen extends StatefulWidget {
  const RegularProjectDashboardScreen({super.key});

  static void open(BuildContext context) {
    context.push('/regular-project-dashboard');
  }

  @override
  State<RegularProjectDashboardScreen> createState() =>
      _RegularProjectDashboardScreenState();
}

class _RegularProjectDashboardScreenState
    extends State<RegularProjectDashboardScreen> with TickerProviderStateMixin {
  DashboardMetrics? _metrics;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  late final AnimationController _heroAnimController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  // Design tokens — aligned with the NDU app theme (theme.dart):
  //   primary = #FFC812 (brand yellow), secondary = #2563EB (info blue),
  //   tertiary = #16A34A (success green), surface = white.
  static const _canvas = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceWarm = Color(0xFFFFFBF3);
  static const _surfaceMint = Color(0xFFFEFCE8); // Soft brand-yellow tint
  static const _outline = Color(0xFFE7E5E0);
  static const _outlineSoft = Color(0xFFF1EFE9);
  static const _ink = Color(0xFF1A1D1F);
  static const _inkSoft = Color(0xFF3D4046);
  static const _muted = Color(0xFF6B7280);
  static const _mutedSoft = Color(0xFF9CA3AF);
  static const _brand = Color(0xFFFFC812); // App primary (brand yellow)
  static const _teal = Color(0xFF2563EB); // App secondary (info blue)
  static const _tealDeep = Color(0xFF1E40AF);
  static const _tealSoft = Color(0xFFDBEAFE);

  static const _coral = Color(0xFFFB7185);
  static const _amber = Color(0xFFF59E0B);
  static const _emerald = Color(0xFF10B981);
  static const _indigo = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade = CurvedAnimation(
      parent: _heroAnimController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    _loadMetrics();
    _heroAnimController.forward();
  }

  @override
  void dispose() {
    _heroAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final metrics = await DashboardMetricsService.load();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load workspace data.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirm Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _coral,
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
      await FirebaseAuthService.signOut();
      if (mounted) context.go('/');
    }
  }

  Future<void> _openProject(ProjectRecord project) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final provider = ProjectDataInherited.read(context);
      final success = await provider
          .loadFromFirebase(project.id)
          .timeout(const Duration(seconds: 35));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.lastError ?? 'Unable to open project'),
          backgroundColor: _coral,
        ));
        return;
      }
      final checkpoint = project.checkpointRoute.isNotEmpty
          ? project.checkpointRoute
          : await ProjectNavigationService.instance.getLastPage(project.id);
      if (!mounted) return;
      final screen = NavigationRouteResolver.resolveCheckpointToScreen(
          checkpoint.isEmpty ? 'initiation' : checkpoint, context);
      context.push(
        NavigationRouteResolver.resolveCheckpointToUrl(
            checkpoint.isEmpty ? 'initiation' : checkpoint),
        extra: screen ?? const InitiationPhaseScreen(),
      );
    } on TimeoutException {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Project load timed out. Please retry.'),
        backgroundColor: _amber,
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error opening project: $e')));
    }
  }

  void _createNewProject() {
    context.push('/initiation-phase');
  }

  @override
  Widget build(BuildContext context) {
    NavigationContextService.instance.setLastClientDashboard('/dashboard');
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName ?? user?.email ?? 'there').split(' ').first;

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: StreamBuilder<List<ProjectRecord>>(
          stream: user == null
              ? Stream.value(const <ProjectRecord>[])
              : ProjectService.streamProjects(
                  ownerId: user.uid,
                  filterByOwner: true,
                  limit: 200,
                ),
          builder: (context, snapshot) {
            final allProjects = snapshot.data ?? const <ProjectRecord>[];
            final projects = allProjects
                .where((p) => p.isBasicPlanProject)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

            final filtered = _searchQuery.isEmpty
                ? projects
                : projects
                    .where((p) =>
                        p.name.toLowerCase().contains(_searchQuery) ||
                        p.solutionTitle.toLowerCase().contains(_searchQuery) ||
                        p.tags.any((t) =>
                            t.toLowerCase().contains(_searchQuery)))
                    .toList();

            final statusesById = {
              for (final s in _metrics?.projectStatuses ??
                  const <ProjectStatusRollup>[])
                s.projectId: s,
            };

            return RefreshIndicator(
              onRefresh: _loadMetrics,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar(displayName)),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: SlideTransition(
                        position: _heroSlide,
                        child: _buildHero(projects.length, displayName),
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _teal,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildErrorBanner(_error!),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _buildStatsRow(projects, statusesById),
                    ),
                    SliverToBoxAdapter(
                      child: _buildNextActionCard(projects),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSearchAndFilters(),
                    ),
                    filtered.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                            sliver: SliverList.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                final rollup = statusesById[p.id];
                                return _RegularProjectCard(
                                  project: p,
                                  rollup: rollup,
                                  onTap: () => _openProject(p),
                                );
                              },
                            ),
                          ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        backgroundColor: _teal,
        foregroundColor: const Color(0xFF1C1C1C),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'New Project',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const _BottomMiniNav(activeIndex: 0),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(String displayName) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initialsFor(displayName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Row(
        children: [
          const AppLogo(height: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NDU Runway',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Regular Projects · Basic plan workspace',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _kazAiPill(),
          const SizedBox(width: 8),
          _IconActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Activity',
            color: _amber,
            onTap: () => ProjectActivitiesLogScreen.open(context),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceWarm,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: _outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _tealSoft,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _tealDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.logout_rounded, size: 14, color: _muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// KAZ AI copilot pill — opens the KAZ AI chat.
  Widget _kazAiPill() {
    return InkWell(
      onTap: () => KazAiChatBubble.openChat(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFC812), Color(0xFFFF9800)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _tealDeep.withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 13, color: Color(0xFF1C1C1C)),
            SizedBox(width: 5),
            Text(
              'KAZ AI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF1C1C1C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────
  Widget _buildHero(int projectCount, String displayName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFC812),
              Color(0xFFFABD00),
              Color(0xFFF59E0B),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _tealDeep.withAlpha(50),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3D2E00).withAlpha(16),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3D2E00).withAlpha(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $displayName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5B4300),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your project runway awaits.',
                    style: TextStyle(
                      fontSize: 26,
                      color: Color(0xFF2B1F00),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Every great delivery starts with one clear next step. '
                    'Pick a workspace below or start fresh — we\'ll guide you '
                    'through initiation, planning, and launch.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4A3A00),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeroStat(
                        label: 'Active workspaces',
                        value: '$projectCount',
                        icon: Icons.folder_special_rounded,
                      ),
                      const SizedBox(width: 14),
                      _HeroStat(
                        label: 'Plan tier',
                        value: 'Basic',
                        icon: Icons.bolt_rounded,
                      ),
                      const SizedBox(width: 14),
                      _HeroStat(
                        label: 'Quota used',
                        value: '${(projectCount / 10 * 100).round().clamp(0, 100)}%',
                        icon: Icons.donut_small_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow(
      List<ProjectRecord> projects, Map<String, ProjectStatusRollup> statuses) {
    final onTrack = projects.where((p) {
      final s = statuses[p.id]?.overallStatus ?? 'unknown';
      return s == 'on_track';
    }).length;
    final atRisk = projects.where((p) {
      final s = statuses[p.id]?.overallStatus ?? 'unknown';
      return s == 'at_risk';
    }).length;
    final offTrack = projects.where((p) {
      final s = statuses[p.id]?.overallStatus ?? 'unknown';
      return s == 'off_track';
    }).length;
    final avgProgress = projects.isEmpty
        ? 0.0
        : projects.map((p) => p.progress).reduce((a, b) => a + b) /
            projects.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _StatTile(
            label: 'On Track',
            value: '$onTrack',
            sublabel: 'healthy workspaces',
            color: _emerald,
            icon: Icons.check_circle_rounded,
          ),
          _StatTile(
            label: 'At Risk',
            value: '$atRisk',
            sublabel: 'need attention',
            color: _amber,
            icon: Icons.warning_amber_rounded,
          ),
          _StatTile(
            label: 'Off Track',
            value: '$offTrack',
            sublabel: 'blocked / stalled',
            color: _coral,
            icon: Icons.error_outline_rounded,
          ),
          _StatTile(
            label: 'Avg. Progress',
            value: '${(avgProgress * 100).round()}%',
            sublabel: 'across all workspaces',
            color: _teal,
            icon: Icons.trending_up_rounded,
          ),
        ],
      ),
    );
  }

  // ── Next action card ───────────────────────────────────────────────────────
  Widget _buildNextActionCard(List<ProjectRecord> projects) {
    final hasProjects = projects.isNotEmpty;
    final title = hasProjects
        ? 'Continue where you left off'
        : 'Start your first project';
    final subtitle = hasProjects
        ? 'Pick the workspace you last touched — we\'ll resume exactly where you stopped.'
        : 'In under five minutes you\'ll have a project framework, core stakeholder map, and a draft business case.';
    final cta = hasProjects ? 'Open last project' : 'Begin initiation';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surfaceWarm,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _tealSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: _tealDeep,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            FilledButton(
              onPressed: hasProjects
                  ? () => _openProject(projects.first)
                  : _createNewProject,
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: const Color(0xFF1C1C1C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cta,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & filters ───────────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _outline),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search workspaces, tags, solutions…',
                  hintStyle: TextStyle(color: _mutedSoft, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: _muted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                style: const TextStyle(fontSize: 14, color: _ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _outlineSoft, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _tealSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                size: 40,
                color: _teal,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'A clean slate — perfect for starting fresh.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t created any regular projects yet. Tap "New Project" '
              'and we\'ll walk you through initiation — no jargon, no setup, '
              'just a clear runway to launch.',
              style: TextStyle(
                fontSize: 13,
                color: _muted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _coral.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _coral.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: _coral, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: _ink),
            ),
          ),
          TextButton(
            onPressed: _loadMetrics,
            child: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3D2E00).withAlpha(22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3D2E00).withAlpha(40)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2B1F00)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2B1F00),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF5B4300),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final Color color;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _RegularProjectDashboardScreenState._surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _RegularProjectDashboardScreenState._outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _RegularProjectDashboardScreenState._ink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _RegularProjectDashboardScreenState._ink,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 11,
              color: _RegularProjectDashboardScreenState._muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegularProjectCard extends StatelessWidget {
  final ProjectRecord project;
  final ProjectStatusRollup? rollup;
  final VoidCallback onTap;
  const _RegularProjectCard({
    required this.project,
    required this.rollup,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = rollup?.overallStatus ?? 'unknown';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final progress = (project.progress * 100).clamp(0, 100).toDouble();
    final updatedLabel = _formatRelative(project.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E5E0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4CC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_special_rounded,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name.isEmpty
                              ? 'Untitled workspace'
                              : project.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1D1F),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.solutionTitle.isEmpty
                              ? 'No solution defined yet'
                              : project.solutionTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(color: statusColor, label: statusLabel),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        '${progress.round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1EFE9),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Footer row
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Updated $updatedLabel',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (project.tags.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: project.tags
                            .take(2)
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBF3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE7E5E0)),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'on_track':
        return const Color(0xFF10B981);
      case 'at_risk':
        return const Color(0xFFF59E0B);
      case 'off_track':
        return const Color(0xFFFB7185);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_track':
        return 'On Track';
      case 'at_risk':
        return 'At Risk';
      case 'off_track':
        return 'Off Track';
      default:
        return 'Unknown';
    }
  }

  String _formatRelative(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomMiniNav extends StatelessWidget {
  final int activeIndex;
  const _BottomMiniNav({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE7E5E0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Runway',
            isActive: activeIndex == 0,
            color: const Color(0xFFD97706),
          ),
          _NavItem(
            icon: Icons.explore_rounded,
            label: 'Insights',
            isActive: activeIndex == 1,
            color: const Color(0xFF6366F1),
          ),
          _NavItem(
            icon: Icons.bookmark_rounded,
            label: 'Library',
            isActive: activeIndex == 2,
            color: const Color(0xFFF59E0B),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isActive: activeIndex == 3,
            color: const Color(0xFFFB7185),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isActive ? color : const Color(0xFF6B7280)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
