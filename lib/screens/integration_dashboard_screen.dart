library;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// integration_dashboard_screen.dart
//
// The Integration Dashboard — one screen that answers both "where does my
// portfolio need me?" and "is my baseline actually integrated?".
//
// It deliberately absorbs the role of the old Regular Project Dashboard
// (route `/regular-project-dashboard`): the workspace launchpad content that
// screen used to own now lives behind the **Workspaces** view here, while the
// Performance Measurement Baseline / Integrated Baseline Review content lives
// behind the **Baseline** view. Both routes resolve to this screen; the route
// you arrive on picks the initial view.
//
// Why one screen rather than two:
//   • The two views answer questions about the *same* objects. A project at
//     40% progress with two open risks is exactly the project whose baseline
//     will fail the IBR — splitting the two views across two screens forces
//     the user to hold that link in their head.
//   • It keeps a single deep-link surface. `/regular-project-dashboard` stays
//     valid for existing bookmarks and the `/dashboard` stat card, while
//     `/integration-dashboard` stays reachable from the mobile shell.
//
// The screen is read-only. It never mutates module state; every action it
// offers either navigates to the module where the gap gets closed, or
// performs a fresh read-only assessment.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/ibr_service.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/services/scope_coverage_validator.dart';
import 'package:ndu_project/widgets/dashboard_header.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_baseline_view.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_workspaces_view.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

/// Which half of the dashboard is on screen.
enum IntegrationDashboardView {
  /// Portfolio roll-up, resume card, search, and the workspace grid.
  workspaces,

  /// PMB / Integrated Baseline Review for the active project.
  baseline,
}

/// World-class Integration Dashboard.
class IntegrationDashboardScreen extends StatefulWidget {
  const IntegrationDashboardScreen({
    super.key,
    this.initialView = IntegrationDashboardView.baseline,
  });

  /// Which view opens first. `/integration-dashboard` passes [baseline];
  /// `/regular-project-dashboard` passes [workspaces].
  final IntegrationDashboardView initialView;

  /// Navigate to the workspace view (the Regular Projects entry point).
  static void openWorkspaces(BuildContext context) {
    context.push('/${AppRoutes.regularProjectDashboard}');
  }

  /// Navigate to the baseline view (the Planning-sidebar entry point).
  static void openBaseline(BuildContext context) {
    context.push('/${AppRoutes.integrationDashboard}');
  }

  @override
  State<IntegrationDashboardScreen> createState() =>
      _IntegrationDashboardScreenState();
}

class _IntegrationDashboardScreenState
    extends State<IntegrationDashboardScreen>
    with SingleTickerProviderStateMixin {
  /// Horizontal page inset. Matches the padding the old workspace dashboard
  /// used so the density of the screen doesn't shift on the swap.
  static const _gutter = EdgeInsets.symmetric(horizontal: 24);

  // ── View ────────────────────────────────────────────────────────────────────
  late IntegrationDashboardView _view = widget.initialView;

  // ── Baseline (IBR) data ────────────────────────────────────────────────────
  IbrReport? _report;
  bool _ibrLoading = false;
  String? _ibrError;

  // ── Workspace data ─────────────────────────────────────────────────────────
  DashboardMetrics? _metrics;
  bool _metricsLoading = true;
  String? _metricsError;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  late final AnimationController _heroController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();

    NavigationContextService.instance.setLastClientDashboard(
      '/${AppRoutes.dashboard}',
    );

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
    ));

    _loadMetrics();
    // The baseline is the slower of the two reads, so it starts immediately
    // and is simply ready by the time anyone switches to it.
    _runIbr();
    _heroController.forward();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadMetrics() async {
    if (mounted) {
      setState(() {
        _metricsLoading = true;
        _metricsError = null;
      });
    }
    try {
      // The launchpad only needs per-project rollups; the activities
      // subcollection is a fan-out read we don't use here.
      final metrics = await DashboardMetricsService.load(
        includeActivities: false,
      );
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _metricsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _metricsError = 'Could not load workspace data.';
          _metricsLoading = false;
        });
      }
      debugPrint('IntegrationDashboard: metrics load failed: $e');
    }
  }

  Future<void> _runIbr() async {
    if (mounted) {
      setState(() {
        _ibrLoading = true;
        _ibrError = null;
      });
    }
    try {
      final project = context.read<ProjectDataProvider>().projectData;
      final wbs = context.read<WBSProvider>().wbs;

      // Schedule and Cost Estimate are project-scoped. Bind them to the
      // active project before reporting so the integration read never mixes
      // in another project's activities or cost lines.
      final projectId = (project.projectId ?? '').trim();
      final projectName = project.projectName.trim();
      final scheduleProvider = context.read<ScheduleProvider>();
      final costProvider = context.read<CostEstimateProvider>();
      await scheduleProvider.ensureProjectLoaded(
        projectId,
        projectName: projectName,
      );
      await costProvider.ensureProjectLoaded(
        projectId,
        projectName: projectName,
      );
      if (!mounted) return;

      final schedule = scheduleProvider.schedule;
      final controls = context.read<ProjectControlsProvider>().state;
      final estimate = costProvider.estimate;

      // PlanningDashboardItem has no wbsId in the legacy model, so scope
      // items are passed as text-only and the validator surfaces any that
      // aren't yet matched by code. Linking them properly is done from the
      // Scope Tracking Plan screen.
      final scopeItems = project.withinScopeItems
          .where((s) => s.description.trim().isNotEmpty)
          .map((s) => ScopeCoverageInput(
                id: s.id,
                description: s.description,
                wbsNodeId: null,
                wbsCode: null,
              ))
          .toList();

      final report = IbrService.assess(
        project: project,
        wbs: wbs,
        schedule: schedule,
        costEstimate: estimate,
        controls: controls,
        scopeItems: scopeItems,
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        setState(() => _ibrError = 'The baseline could not be assessed: $e');
      }
      debugPrint('IntegrationDashboard: IBR assess failed: $e');
    } finally {
      if (mounted) setState(() => _ibrLoading = false);
    }
  }

  /// Pull-to-refresh re-runs both reads concurrently.
  Future<void> _refreshAll() async {
    await Future.wait([_loadMetrics(), _runIbr()]);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _selectView(IntegrationDashboardView view) {
    if (_view == view) return;
    setState(() => _view = view);
    // Switching to the baseline before it has ever run means the user would
    // otherwise land on an empty panel — fetch it now.
    if (view == IntegrationDashboardView.baseline &&
        _report == null &&
        !_ibrLoading) {
      _runIbr();
    }
  }

  void _onSearchChanged(String value) {
    // Debounce so a fast typist doesn't re-filter the grid on every keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _searchQuery = value.trimLeft());
    });
  }

  void _createNewProject() => context.push('/${AppRoutes.initiationPhase}');

  /// Load a workspace, then resume it exactly where it was last left.
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
        _toast(provider.lastError ?? 'Unable to open project', isError: true);
        return;
      }
      final checkpoint = project.checkpointRoute.isNotEmpty
          ? project.checkpointRoute
          : await ProjectNavigationService.instance.getLastPage(project.id);
      if (!mounted) return;
      final key = checkpoint.isEmpty ? 'initiation' : checkpoint;
      context.push(
        NavigationRouteResolver.resolveCheckpointToUrl(key),
        extra: NavigationRouteResolver.resolveCheckpointToScreen(key, context) ??
            const InitiationPhaseScreen(),
      );
    } on TimeoutException {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _toast('Project load timed out. Please retry.', isError: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _toast('Error opening project: $e', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.forPlan(true);
    final tokens = IntegrationTokens.of(context, palette);
    final user = FirebaseAuth.instance.currentUser;

    return DashboardPaletteScope(
      palette: palette,
      child: ResponsiveScaffold(
        // This page is a full-width cross-project command centre, so the
        // phase sidebar is suppressed here: it carries no context a user needs
        // while scanning workspaces and baseline health. The dashboard's own
        // Workspaces / Baseline switcher is the navigation for this screen.
        showSidebar: false,
        appBarTitle: 'Integration Dashboard',
        activeItemLabel: 'Integration Dashboard',
        floatingActionButton: const KazAiChatBubble(positioned: false),
        body: StreamBuilder<List<ProjectRecord>>(
          stream: user == null
              ? Stream.value(const <ProjectRecord>[])
              : ProjectService.streamProjects(
                  ownerId: user.uid,
                  filterByOwner: true,
                  limit: 200,
                ),
          builder: (context, snapshot) {
            // Basic-plan workspaces only, most recently touched first.
            final projects = (snapshot.data ?? const <ProjectRecord>[])
                .where((p) => p.isBasicPlanProject)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

            final isProjectListLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                    projects.isEmpty;

            return RefreshIndicator(
              onRefresh: _refreshAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Hero command band ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: SlideTransition(
                        position: _heroSlide,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: DashboardHeader(
                            isBasicPlan: true,
                            onAddProject: _createNewProject,
                            crumbLabel: 'Integration Dashboard',
                            modeTitle: _view ==
                                    IntegrationDashboardView.workspaces
                                ? 'Workspace launchpad · Scope, WBS, schedule '
                                    'and cost at a glance'
                                : 'Performance Measurement Baseline · '
                                    'Scope, WBS, schedule and cost integration',
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── View switcher ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: _ViewSwitcher(
                        tokens: tokens,
                        value: _view,
                        workspaceCount: projects.length,
                        ibrStatus: _report?.overallStatus,
                        ibrScore: _report?.readinessScore,
                        onChanged: _selectView,
                      ),
                    ),
                  ),

                  // ── Active view ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: _gutter.add(
                        const EdgeInsets.only(top: 18, bottom: 120),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _view == IntegrationDashboardView.workspaces
                            ? KeyedSubtree(
                                key: const ValueKey('workspaces'),
                                child: IntegrationWorkspacesView(
                                  tokens: tokens,
                                  projects: projects,
                                  metrics: _metrics,
                                  isLoading:
                                      _metricsLoading || isProjectListLoading,
                                  error: _metricsError,
                                  searchController: _searchController,
                                  searchQuery: _searchQuery,
                                  onSearchChanged: _onSearchChanged,
                                  onRetry: _loadMetrics,
                                  onOpenProject: _openProject,
                                  onCreateProject: _createNewProject,
                                ),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('baseline'),
                                child: IntegrationBaselineView(
                                  tokens: tokens,
                                  report: _report,
                                  isLoading: _ibrLoading,
                                  error: _ibrError,
                                  onRetry: _runIbr,
                                  projectLabel: _activeProjectLabel(),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _activeProjectLabel() {
    final name = context.read<ProjectDataProvider>().projectData.projectName;
    final trimmed = name.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

// ──────────────────────────────────────────────────────────────────────
// View switcher
// ──────────────────────────────────────────────────────────────────────

/// A two-state pill control that doubles as a status readout: each segment
/// carries a live badge so the user can see the shape of both halves of the
/// dashboard without switching to them.
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.tokens,
    required this.value,
    required this.onChanged,
    this.workspaceCount = 0,
    this.ibrStatus,
    this.ibrScore,
  });

  final IntegrationTokens tokens;
  final IntegrationDashboardView value;
  final ValueChanged<IntegrationDashboardView> onChanged;
  final int workspaceCount;
  final IbrStatus? ibrStatus;
  final double? ibrScore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below ~420px the labels plus badges stop fitting side by side, so
        // the switcher stacks into two full-width rows.
        final stacked = constraints.maxWidth < 420;
        // One shared row height keeps the sliding thumb and the hit targets
        // in lockstep in both orientations.
        const rowHeight = 46.0;
        const rowGap = 4.0;
        final trackHeight = stacked ? rowHeight * 2 + rowGap : rowHeight;
        final trackWidth = constraints.maxWidth - 8;
        final thumbWidth = stacked ? trackWidth : trackWidth / 2;

        Widget thumbFor(IntegrationDashboardView view) {
          final isBaseline = view == IntegrationDashboardView.baseline;
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            // Stacked: the thumb moves down one row. Side by side: it moves
            // right one column. It must never span both rows, or both
            // segments would read as selected.
            left: 4 + (isBaseline && !stacked ? thumbWidth : 0),
            top: stacked
                ? 4 + (isBaseline ? rowHeight + rowGap : 0)
                : 4,
            width: thumbWidth,
            height: rowHeight,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: tokens.brandDeep.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          );
        }

        Widget segment(IntegrationDashboardView view) {
          final selected = value == view;
          final tone = selected ? tokens.onBrand : tokens.ink;
          final (IconData icon, String label, Widget? badge) = switch (view) {
            IntegrationDashboardView.workspaces => (
                Icons.grid_view_rounded,
                'Workspaces',
                workspaceCount == 0
                    ? null
                    : _Badge(
                        tokens: tokens,
                        label: '$workspaceCount',
                        selected: selected,
                      ),
              ),
            IntegrationDashboardView.baseline => (
                Icons.hub_outlined,
                'Baseline Integration',
                ibrStatus == null
                    ? null
                    : _Badge(
                        tokens: tokens,
                        label: ibrScore == null
                            ? '—'
                            : '${ibrScore!.clamp(0, 100).round()}',
                        selected: selected,
                        accent: ibrStatus == null
                            ? null
                            : statusVisual(tokens, ibrStatus!).$1,
                      ),
              ),
          };

          return Semantics(
            button: true,
            selected: selected,
            label: '$label view',
            child: InkWell(
              onTap: () => onChanged(view),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: stacked ? Alignment.centerLeft : Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 17, color: tone),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: tone,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge],
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          height: trackHeight + 8,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.outline),
          ),
          child: stacked
              ? Stack(
                  children: [
                    thumbFor(IntegrationDashboardView.workspaces),
                    thumbFor(IntegrationDashboardView.baseline),
                    Column(
                      children: [
                        SizedBox(
                          height: rowHeight,
                          child: segment(IntegrationDashboardView.workspaces),
                        ),
                        const SizedBox(height: rowGap),
                        SizedBox(
                          height: rowHeight,
                          child: segment(IntegrationDashboardView.baseline),
                        ),
                      ],
                    ),
                  ],
                )
              : Stack(
                  children: [
                    thumbFor(IntegrationDashboardView.workspaces),
                    thumbFor(IntegrationDashboardView.baseline),
                    Row(
                      children: [
                        Expanded(
                          child: segment(IntegrationDashboardView.workspaces),
                        ),
                        Expanded(
                          child: segment(IntegrationDashboardView.baseline),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.tokens,
    required this.label,
    required this.selected,
    this.accent,
  });

  final IntegrationTokens tokens;
  final String label;
  final bool selected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = selected
        ? (accent ?? tokens.onBrand)
        : (accent ?? tokens.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? tone.withValues(alpha: 0.18)
            : tokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? tone.withValues(alpha: 0.35) : tokens.outline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}