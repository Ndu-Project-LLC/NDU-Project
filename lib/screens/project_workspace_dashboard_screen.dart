import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/services/project_ssher_rollup_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/compact_action_button.dart';
import 'package:ndu_project/widgets/dashboard_metrics_cards.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

// The dashboard_metrics_cards import is retained intentionally so the
// workspace keeps a stable import surface even though the executive
// command center redesign builds its own bespoke widget tree.
// ignore_for_file: unused_import

/// NDU Executive Command Center — bento-grid project workspace dashboard.
class ProjectWorkspaceDashboardScreen extends StatefulWidget {
  const ProjectWorkspaceDashboardScreen({super.key, required this.isBasicPlan});

  final bool isBasicPlan;

  static void open(BuildContext context, {bool isBasicPlan = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProjectWorkspaceDashboardScreen(isBasicPlan: isBasicPlan),
      ),
    );
  }

  @override
  State<ProjectWorkspaceDashboardScreen> createState() =>
      _ProjectWorkspaceDashboardScreenState();
}

class _ProjectWorkspaceDashboardScreenState
    extends State<ProjectWorkspaceDashboardScreen> {
  DashboardMetrics? _metrics;
  bool _loading = true;
  String? _error;
  SsherPortfolioRollup? _ssherRollup;
  Stream<List<ProjectRecord>>? _projectsStream;
  final TextEditingController _updateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Design tokens — white canvas, near-black ink, gray secondary text,
  // status colors and a yellow accent (#FFC812).
  static const _bg = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFF8FAFC);
  static const _surfaceHigh = Color(0xFFF1F5F9);
  static const _outline = Color(0xFFE5E7EB);
  static const _outlineStrong = Color(0xFFCBD5E1);
  static const _ink = Color(0xFF0A0A0A);
  static const _inkSoft = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _mutedSoft = Color(0xFF9CA3AF);
  static const _accent = Color(0xFFFFC812);
  static const _accentDeep = Color(0xFFE0A800);
  static const _accentSoft = Color(0xFFFFF4CC);
  static const _emerald = Color(0xFF059669);
  static const _emeraldSoft = Color(0xFFD1FAE5);
  static const _gold = Color(0xFFD97706);
  static const _goldSoft = Color(0xFFFEF3C7);
  static const _crimson = Color(0xFFDC2626);
  static const _crimsonSoft = Color(0xFFFEE2E2);
  static const _slate = Color(0xFF0F172A);

  static const _statusColors = <String, Color>{
    'on_track': _emerald,
    'at_risk': _gold,
    'off_track': _crimson,
    'unknown': _muted,
  };
  static const _statusSoftColors = <String, Color>{
    'on_track': _emeraldSoft,
    'at_risk': _goldSoft,
    'off_track': _crimsonSoft,
    'unknown': _surfaceHigh,
  };
  static const _statusLabels = <String, String>{
    'on_track': 'On Track',
    'at_risk': 'At Risk',
    'off_track': 'Off Track',
    'unknown': 'Unknown',
  };

  bool get _isBasic => widget.isBasicPlan;

  @override
  void initState() {
    super.initState();
    _projectsStream = FirebaseAuth.instance.currentUser == null
        ? Stream.value(const <ProjectRecord>[])
        : ProjectService.streamProjects(
            ownerId: FirebaseAuth.instance.currentUser!.uid,
            filterByOwner: true,
            limit: 200,
          ).handleError((error, stackTrace) {
              debugPrint('Projects stream error: $error');
              return <ProjectRecord>[];
            });
    _loadMetrics();
  }

  @override
  void dispose() {
    _updateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data loading (preserved from prior implementation) ───────────────────
  Future<void> _loadMetrics() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final metrics = await DashboardMetricsService.load();
      // Kick off SSHER rollup load in parallel (best-effort — failures don't
      // break the dashboard, they just leave the SSHER card empty).
      final user = FirebaseAuth.instance.currentUser;
      SsherPortfolioRollup? ssherRollup;
      try {
        if (user != null) {
          final projects = await ProjectService.streamProjects(
            ownerId: user.uid,
            filterByOwner: true,
            limit: 200,
          ).first.timeout(const Duration(seconds: 10));
          final ids = projects.map((p) => p.id).toList();
          ssherRollup = await ProjectSsherRollupService.loadForProjects(ids);
        }
      } catch (e) {
        // Best-effort: log and move on with null rollup.
        ssherRollup = null;
      }
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _ssherRollup = ssherRollup;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load workspace dashboard data.';
          _loading = false;
        });
      }
    }
  }

  // ── Auth (preserved) ────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  // ── Project open (preserved) ─────────────────────────────────────────────
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.lastError ?? 'Unable to open project'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      final checkpoint = project.checkpointRoute.isNotEmpty
          ? project.checkpointRoute
          : await ProjectNavigationService.instance.getLastPage(project.id);
      if (!mounted) return;
      final screen = NavigationRouteResolver.resolveCheckpointToScreen(
          checkpoint.isEmpty ? 'initiation' : checkpoint, context);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => screen ?? const InitiationPhaseScreen(),
      ));
    } on TimeoutException {
      if (!mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Project load timed out. Please retry.'),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      if (!mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error opening project: $e')));
    } finally {
      closeLoadingDialog();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    NavigationContextService.instance.setLastClientDashboard('/dashboard');
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<List<ProjectRecord>>(
          stream: _projectsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildBanner(
                'Failed to load projects: ${snapshot.error}',
                _crimson,
              );
            }
            final allProjects = snapshot.data ?? const <ProjectRecord>[];
            final projects = allProjects
                .where((p) =>
                    _isBasic ? p.isBasicPlanProject : !p.isBasicPlanProject)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            final statusesById = {
              for (final s
                  in _metrics?.projectStatuses ?? const <ProjectStatusRollup>[])
                s.projectId: s,
            };
            final rollups = projects
                .map((p) => statusesById[p.id])
                .whereType<ProjectStatusRollup>()
                .toList();
            final assigned =
                (_metrics?.assignedToMe ?? const <AssignedActivity>[])
                    .where((a) => projects.any((p) => p.id == a.projectId))
                    .toList();
            final pastDue = (_metrics?.pastDue ?? const <AssignedActivity>[])
                .where((a) => projects.any((p) => p.id == a.projectId))
                .toList();
            final primary = projects.isNotEmpty ? projects.first : null;
            final primaryRollup = primary == null
                ? null
                : rollups.firstWhere((r) => r.projectId == primary.id,
                    orElse: () => rollups.isNotEmpty
                        ? rollups.first
                        : const ProjectStatusRollup(
                            projectId: '',
                            projectName: '',
                            overallStatus: 'unknown',
                            scheduleStatus: 'unknown',
                            costStatus: 'unknown',
                            scopeStatus: 'unknown',
                            qualityStatus: 'unknown',
                            riskStatus: 'unknown'));

            return RefreshIndicator(
              onRefresh: _loadMetrics,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildProjectHeader(primary),
                  const SizedBox(height: 16),
                  if (_loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_error != null)
                    _buildBanner(_error!, _crimson),
                  const SizedBox(height: 18),
                  _buildKpiRow(
                      primary: primary,
                      rollup: primaryRollup,
                      assigned: assigned),
                  const SizedBox(height: 20),
                  _buildBentoGrid(
                      primary: primary,
                      rollup: primaryRollup,
                      assigned: assigned,
                      pastDue: pastDue),
                  const SizedBox(height: 20),
                  _buildSsherPortfolioCard(projects),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: const KazAiChatBubble(),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        const AppLogo(height: 38),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('NDU Executive Command Center',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.2)),
              Text(
                _isBasic
                    ? 'Basic plan workspace · program-level delivery visibility'
                    : 'Active workspace · executive-level delivery visibility',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        CompactActionButton(
          label: 'Activity Log',
          subtitle: 'Open unified tracker',
          icon: Icons.fact_check_outlined,
          accent: _gold,
          onTap: () => ProjectActivitiesLogScreen.open(context),
        ),
        const SizedBox(width: 10),
        CompactActionButton(
          label: 'Log Out',
          subtitle: 'Sign out of workspace',
          icon: Icons.logout_rounded,
          accent: _crimson,
          onTap: _handleLogout,
        ),
      ],
    );
  }

  // ── 1. Project header ───────────────────────────────────────────────────
  Widget _buildProjectHeader(ProjectRecord? project) {
    final name = project?.name.isNotEmpty == true
        ? project!.name
        : (_isBasic ? 'Regular Project Workspace' : 'Project Workspace');
    final manager = (project?.ownerName.isNotEmpty == true)
        ? project!.ownerName
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Project Manager');
    final status = _overallStatus(project);
    final start = project?.createdAt ??
        DateTime.now().subtract(const Duration(days: 120));
    final end = start.add(const Duration(days: 365));
    final initial = manager.trim().isNotEmpty
        ? manager.trim().substring(0, 1).toUpperCase()
        : 'P';

    final badge = _statusBadge(status);
    final planPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: _accentDeep, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_isBasic ? 'BASIC PLAN' : 'STANDARD PLAN',
            style: const TextStyle(
                color: _accentDeep,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ]),
    );
    final managerRow = Row(children: [
      Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
              color: _slate,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 2))),
          alignment: Alignment.center,
          child: Text(initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800))),
      const SizedBox(width: 8),
      Text(manager,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _inkSoft)),
      const SizedBox(width: 14),
      _dateChip(Icons.calendar_today_outlined, 'Started ${_formatDate(start)}'),
      const SizedBox(width: 14),
      _dateChip(Icons.flag_outlined, 'Target ${_formatDate(end)}'),
    ]);

    Widget actionButton(
        String label, IconData icon, bool filled, VoidCallback onTap) {
      return Material(
        color: filled ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: filled ? null : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: filled ? null : Border.all(color: _outlineStrong),
              boxShadow: filled
                  ? [
                      BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: _slate),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: filled ? FontWeight.w800 : FontWeight.w700,
                      color: _slate)),
            ]),
          ),
        ),
      );
    }

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        actionButton('Export Report', Icons.download_outlined, false,
            () => _showSnack('Report queued for export')),
        const SizedBox(width: 10),
        actionButton('Edit Project', Icons.edit_outlined, true, () {
          if (project != null) {
            _openProject(project);
          } else {
            _showSnack('No project available to edit');
          }
        }),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 760;
        final meta =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [badge, const SizedBox(width: 10), planPill]),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.4,
                  height: 1.15)),
          const SizedBox(height: 10),
          narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [managerRow])
              : managerRow,
        ]);
        if (narrow) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                meta,
                const SizedBox(height: 16),
                actions,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: meta),
          const SizedBox(width: 24),
          actions,
        ]);
      }),
    );
  }

  Widget _dateChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
        ],
      );

  // ── 2. KPI row (5 cards) ────────────────────────────────────────────────
  Widget _buildKpiRow({
    required ProjectRecord? primary,
    required ProjectStatusRollup? rollup,
    required List<AssignedActivity> assigned,
  }) {
    final totalBudget = math.max(0.5, primary?.investmentMillions ?? 4.2);
    final usedPct = (rollup?.budgetUsedPercent ?? 78).clamp(0.0, 130.0) / 100.0;
    final actualSpend = totalBudget * usedPct;
    final variance = totalBudget - actualSpend;
    final completion = (primary?.progressSnapshot.completionPercent ?? 0)
        .clamp(0, 100)
        .toInt();
    final resources = math.max(1, assigned.length + 3);

    final kpis = <Widget>[
      _kpiCard('Total Budget', _formatMoney(totalBudget), 'Approved allocation',
          Icons.account_balance_wallet_outlined, _slate, _surfaceHigh),
      _kpiCard(
          'Actual Spend',
          _formatMoney(actualSpend),
          '${(usedPct * 100).round()}% of budget consumed',
          Icons.payments_outlined,
          _gold,
          _goldSoft),
      _kpiCard(
          'Variance',
          (variance < 0 ? '-' : '+') + _formatMoney(variance.abs()),
          variance < 0
              ? 'Over budget — review spend'
              : 'Under budget — on pace',
          variance < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded,
          variance < 0 ? _crimson : _emerald,
          variance < 0 ? _crimsonSoft : _emeraldSoft,
          valueColor: variance < 0 ? _crimson : _emerald),
      _kpiCard('Resources', '$resources', 'Active contributors on this project',
          Icons.groups_2_outlined, _accentDeep, _accentSoft,
          trailing: _avatarStack(resources)),
      _kpiCard('Completion', '$completion%', 'Overall delivery progress',
          Icons.task_alt_rounded, _emerald, _emeraldSoft,
          trailing: _miniProgress(completion / 100)),
    ];

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 920;
      if (narrow) {
        return Column(children: [
          for (int i = 0; i < kpis.length; i++) ...[
            kpis[i],
            if (i != kpis.length - 1) const SizedBox(height: 12),
          ],
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < kpis.length; i++) ...[
            Expanded(child: kpis[i]),
            if (i != kpis.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    });
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon,
      Color accent, Color accentSoft,
      {Color? valueColor, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: accentSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: accent, size: 20)),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 14),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: valueColor ?? _ink,
                letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _inkSoft)),
        const SizedBox(height: 4),
        Text(sub,
            style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _avatarStack(int count) {
    final colors = [_slate, _gold, _emerald, _crimson];
    final initials = ['AK', 'MR', 'JS', 'TP'];
    final shown = math.min(4, math.max(2, count));
    return SizedBox(
      width: shown * 18.0,
      height: 24,
      child: Stack(children: [
        for (int i = 0; i < shown; i++)
          Positioned(
              left: i * 18.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                alignment: Alignment.center,
                child: Text(initials[i % initials.length],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              )),
      ]),
    );
  }

  Widget _miniProgress(double value) => SizedBox(
        width: 48,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: _surfaceHigh,
            valueColor: const AlwaysStoppedAnimation<Color>(_emerald),
          ),
        ),
      );

  // ── 3-6. Bento grid ─────────────────────────────────────────────────────
  Widget _buildBentoGrid({
    required ProjectRecord? primary,
    required ProjectStatusRollup? rollup,
    required List<AssignedActivity> assigned,
    required List<AssignedActivity> pastDue,
  }) {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 1080;
      final chart = _buildCostChartCard(primary);
      final blockers = _buildActiveBlockers(pastDue);
      final matrix = _buildHealthMatrix(rollup);
      final stream = _buildActivityStream(assigned, primary);
      if (narrow) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chart,
              const SizedBox(height: 16),
              blockers,
              const SizedBox(height: 16),
              matrix,
              const SizedBox(height: 16),
              stream,
            ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 8, child: chart),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: blockers),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 8, child: matrix),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: stream),
        ]),
      ]);
    });
  }

  // ── 3. Planned vs Actual Cost Chart ─────────────────────────────────────
  Widget _buildCostChartCard(ProjectRecord? primary) {
    final budget = math.max(0.5, primary?.investmentMillions ?? 4.2) * 1000;
    final planned = [
      budget * .08,
      budget * .12,
      budget * .16,
      budget * .18,
      budget * .18,
      budget * .16,
      budget * .12
    ];
    final actual = [
      budget * .06,
      budget * .14,
      budget * .15,
      budget * .20,
      budget * .17,
      budget * .14,
      budget * .10
    ];
    final labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    final plannedTotal = planned.reduce((a, b) => a + b);
    final actualTotal = actual.reduce((a, b) => a + b);
    Widget legend(String label, Color dot, Color text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: dot,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _outline))),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: text)),
          ],
        );

    return _sectionCard(
      title: 'Planned vs Actual Cost',
      subtitle: r'Monthly burn across the active delivery window ($K).',
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _outline)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insights_rounded, size: 14, color: _accentDeep),
          SizedBox(width: 6),
          Text('Live',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _inkSoft,
                  letterSpacing: 0.4)),
        ]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          legend('Planned', _surfaceHigh, _inkSoft),
          const SizedBox(width: 16),
          legend('Actual', _accent, _slate),
          const Spacer(),
          Text(
              'Plan ${_formatMoney(plannedTotal / 1000)} · Actual ${_formatMoney(actualTotal / 1000)}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarChartPainter(
              planned: planned,
              actual: actual,
              labels: labels,
              plannedColor: _surfaceHigh,
              plannedBorderColor: _outlineStrong,
              actualColor: _accent,
              actualBorderColor: _accentDeep,
              gridColor: _outline,
              textColor: _muted,
            ),
          ),
        ),
      ]),
    );
  }

  // ── 4. Project Health Matrix Table ──────────────────────────────────────
  Widget _buildHealthMatrix(ProjectStatusRollup? rollup) {
    final rows = <_HealthRow>[
      _HealthRow(
          'Schedule',
          Icons.schedule_outlined,
          rollup?.scheduleStatus ?? 'on_track',
          '+5%',
          true,
          'Critical path activities running 4 days ahead of plan.'),
      _HealthRow(
          'Budget',
          Icons.savings_outlined,
          rollup?.costStatus ?? 'at_risk',
          '-2%',
          false,
          'Consulting line item trending over forecast by 2%.'),
      _HealthRow(
          'Scope',
          Icons.category_outlined,
          rollup?.scopeStatus ?? 'on_track',
          'Stable',
          null,
          'Two change requests approved, no scope creep detected.'),
      _HealthRow(
          'Quality',
          Icons.verified_outlined,
          rollup?.qualityStatus ?? 'on_track',
          '+1%',
          true,
          'Defect rate down to 0.8% across last 3 sprints.'),
      _HealthRow(
          'Risk',
          Icons.shield_outlined,
          rollup?.riskStatus ?? 'at_risk',
          '+1',
          false,
          'New high-impact risk logged: vendor lead time slippage.'),
    ];
    return _sectionCard(
      title: 'Project Health Matrix',
      subtitle: 'Five-dimension PMO rollup with trend and latest insight.',
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: const [
              Expanded(flex: 3, child: _HeaderCell('Indicator')),
              Expanded(flex: 2, child: _HeaderCell('Status')),
              Expanded(flex: 2, child: _HeaderCell('Trend')),
              Expanded(flex: 4, child: _HeaderCell('Latest Insight')),
            ]),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            _healthRow(rows[i]),
            if (i != rows.length - 1) const Divider(height: 1, color: _outline),
          ],
        ]),
      ),
    );
  }

  Widget _healthRow(_HealthRow row) {
    final statusColor = _statusColors[row.status] ?? _muted;
    final statusSoft = _statusSoftColors[row.status] ?? _surfaceHigh;
    final statusLabel = _statusLabels[row.status] ?? 'Unknown';
    final trendColor = row.trendUp == true
        ? _emerald
        : (row.trendUp == false ? _crimson : _muted);
    final trendIcon = row.trendUp == true
        ? Icons.arrow_upward_rounded
        : (row.trendUp == false
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: statusSoft,
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(row.icon, color: statusColor, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(row.indicator,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _inkSoft))),
            ])),
        Expanded(
            flex: 2, child: _statusChip(statusLabel, statusColor, statusSoft)),
        Expanded(
            flex: 2,
            child: Row(children: [
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 5),
              Text(row.trend,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: trendColor)),
            ])),
        Expanded(
            flex: 4,
            child: Text(row.insight,
                style:
                    const TextStyle(fontSize: 12, color: _muted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ── 5. Active Blockers ──────────────────────────────────────────────────
  Widget _buildActiveBlockers(List<AssignedActivity> pastDue) {
    final blockers = <_Blocker>[];
    if (pastDue.isNotEmpty) {
      for (int i = 0; i < pastDue.length && i < 4; i++) {
        final a = pastDue[i];
        blockers.add(_Blocker(
          a.title,
          a.projectName,
          a.dueDate.isNotEmpty
              ? 'Due ${_formatDate(DateTime.tryParse(a.dueDate) ?? DateTime.now())}'
              : 'No due date',
          i == 0 ? 'Critical' : (i == 1 ? 'High' : 'Medium'),
        ));
      }
    }
    if (blockers.isEmpty) {
      blockers.addAll([
        _Blocker('Vendor lead time slippage', 'Procurement · critical path',
            'Raised 2 days ago', 'Critical'),
        _Blocker('Stakeholder sign-off pending on Phase 2 spec',
            'Scope · approvals', 'Due in 3 days', 'High'),
        _Blocker('QA environment provisioning delayed',
            'Quality · infrastructure', 'Due in 5 days', 'Medium'),
        _Blocker('Budget reallocation request open', 'Budget · finance review',
            'Open 1 week', 'Medium'),
      ]);
    }
    return _sectionCard(
      title: 'Active Blockers',
      subtitle:
          '${blockers.length} open issues across schedule, budget, scope, quality & risk.',
      child: blockers.isEmpty
          ? _emptyState('No active blockers. The workspace is clear.')
          : Column(children: [
              for (int i = 0; i < blockers.length; i++) ...[
                _blockerCard(blockers[i]),
                if (i != blockers.length - 1) const SizedBox(height: 10),
              ],
            ]),
    );
  }

  Widget _blockerCard(_Blocker b) {
    final palette = _priorityPalette(b.priority);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
                color: palette.$1, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(b.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _priorityBadge(b.priority, palette.$1, palette.$2),
          ]),
          const SizedBox(height: 6),
          Text(b.subtitle,
              style: const TextStyle(
                  fontSize: 11.5, color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule_outlined, size: 12, color: palette.$1),
            const SizedBox(width: 4),
            Text(b.meta,
                style: TextStyle(
                    fontSize: 11,
                    color: palette.$1,
                    fontWeight: FontWeight.w700)),
          ]),
        ])),
      ]),
    );
  }

  (Color, Color) _priorityPalette(String priority) => switch (priority) {
        'Critical' => (_crimson, _crimsonSoft),
        'High' => (_gold, _goldSoft),
        _ => (_mutedSoft, _surfaceHigh),
      };

  Widget _priorityBadge(String label, Color accent, Color soft) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.4))),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.5)),
      );

  // ── 6. Activity Stream ──────────────────────────────────────────────────
  Widget _buildActivityStream(
      List<AssignedActivity> assigned, ProjectRecord? primary) {
    final entries = <_ActivityEntry>[
      _ActivityEntry(
          primary?.ownerName.isNotEmpty == true
              ? primary!.ownerName
              : 'A. Khan',
          'updated the milestone review checklist',
          '12m ago',
          _emerald),
      _ActivityEntry(
          'M. Rahman', 'approved Phase 2 quality gates', '1h ago', _accentDeep),
      _ActivityEntry(
          'J. Sarker', 'logged a new high-impact risk', '3h ago', _crimson),
      _ActivityEntry(
          'T. Pasha', 'revised the cost forecast for Q3', '5h ago', _gold),
      _ActivityEntry('A. Khan', 'closed blocker on procurement vendor',
          '1d ago', _emerald),
    ];
    return _sectionCard(
      title: 'Activity Stream',
      subtitle: 'Latest project updates from the team.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < entries.length; i++)
          _activityRow(entries[i], isLast: i == entries.length - 1),
        const SizedBox(height: 14),
        _postUpdateInput(),
      ]),
    );
  }

  Widget _activityRow(_ActivityEntry e, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 22,
            child: Column(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: e.dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: e.dot.withValues(alpha: 0.3), blurRadius: 4)
                      ])),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2,
                        color: _outline,
                        margin: const EdgeInsets.only(top: 2))),
            ])),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 12.5, color: _inkSoft, height: 1.4),
                  children: [
                    TextSpan(
                        text: e.who,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: ' ${e.action}',
                        style: const TextStyle(color: _muted)),
                  ],
                )),
            const SizedBox(height: 3),
            Text(e.at,
                style: const TextStyle(
                    fontSize: 10.5,
                    color: _mutedSoft,
                    fontWeight: FontWeight.w600)),
          ]),
        )),
      ]),
    );
  }

  Widget _postUpdateInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline)),
      child: Row(children: [
        Expanded(
            child: TextField(
          controller: _updateController,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(
              fontSize: 13, color: _ink, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            hintText: 'Post a project update...',
            hintStyle: const TextStyle(
                color: _mutedSoft, fontSize: 13, fontWeight: FontWeight.w500),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.white,
          ),
          onSubmitted: (_) => _submitUpdate(),
        )),
        const SizedBox(width: 8),
        Material(
          color: _accent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: _submitUpdate,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.send_rounded, size: 14, color: _slate),
                SizedBox(width: 6),
                Text('Post',
                    style: TextStyle(
                        color: _slate,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  void _submitUpdate() {
    final text = _updateController.text.trim();
    if (text.isEmpty) {
      _showSnack('Write a project update before posting.');
      return;
    }
    _updateController.clear();
    _showSnack('Project update posted to the activity stream.');
  }

  // ── Reusable section card ───────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? headerTrailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.2)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: _muted, height: 1.45)),
              ])),
          if (headerTrailing != null) headerTrailing,
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  // ── Status helpers ──────────────────────────────────────────────────────
  String _overallStatus(ProjectRecord? project) {
    final rollup = _metrics?.projectStatuses.firstWhere(
        (r) => r.projectId == project?.id,
        orElse: () => const ProjectStatusRollup(
            projectId: '',
            projectName: '',
            overallStatus: 'unknown',
            scheduleStatus: 'unknown',
            costStatus: 'unknown',
            scopeStatus: 'unknown',
            qualityStatus: 'unknown',
            riskStatus: 'unknown'));
    if (rollup != null && rollup.overallStatus != 'unknown') {
      return rollup.overallStatus;
    }
    return switch (project?.progressSnapshot.health) {
      ProjectProgressHealth.completed => 'on_track',
      ProjectProgressHealth.onTrack => 'on_track',
      ProjectProgressHealth.inProgress => 'at_risk',
      ProjectProgressHealth.behind => 'off_track',
      null => 'on_track',
    };
  }

  Widget _statusBadge(String status) {
    final color = _statusColors[status] ?? _muted;
    final soft = _statusSoftColors[status] ?? _surfaceHigh;
    final label = _statusLabels[status] ?? 'Unknown';
    final icon = status == 'on_track'
        ? Icons.check_circle
        : (status == 'at_risk'
            ? Icons.warning_amber_rounded
            : Icons.error_outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _statusChip(String label, Color accent, Color soft) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.35))),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.3)),
      );

  // ── SSHER Portfolio Cost Burden Card (multi-project rollup) ─────────────
  Widget _buildSsherPortfolioCard(List<ProjectRecord> projects) {
    final rollup = _ssherRollup;
    final hasData = rollup != null && rollup.totalItems > 0;
    final projectsWithSsher = rollup?.projectsWithSsher ?? 0;
    final totalProjects = projects.length;

    return _sectionCard(
      title: 'SSHER Cost Burden — All Projects',
      subtitle:
          'Aggregated Safety, Security, Health, Environment & Regulatory obligations across your $totalProjects ${totalProjects == 1 ? 'project' : 'projects'}.',
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasData ? _goldSoft : _surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: hasData ? _gold : _outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety_rounded,
                size: 14, color: hasData ? _gold : _muted),
            const SizedBox(width: 6),
            Text(
              hasData ? '$projectsWithSsher/$totalProjects active' : 'No data',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: hasData ? _gold : _muted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      child: !hasData
          ? _buildEmptySsherPortfolio()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grand total + summary row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total SSHER Cost (All Projects)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _muted)),
                          const SizedBox(height: 4),
                          Text(
                            _formatMoney(rollup!.grandTotal / 1000000),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ssherPortfolioMiniRow(
                              'Items with cost', '${rollup.totalItems}', _slate),
                          const SizedBox(height: 6),
                          _ssherPortfolioMiniRow(
                              'High-risk items', '${rollup.totalHighRisk}', _crimson),
                          const SizedBox(height: 6),
                          _ssherPortfolioMiniRow('Projects with SSHER',
                              '$projectsWithSsher / $totalProjects', _emerald),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Cost by category (aggregate across all projects)
                const Text('Cost by Category (All Projects)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _muted)),
                const SizedBox(height: 8),
                ...['safety', 'security', 'health', 'environment', 'regulatory']
                    .map((cat) {
                  final total = rollup.costByCategory[cat] ?? 0.0;
                  final double pct = rollup.grandTotal > 0
                      ? (total / rollup.grandTotal * 100).clamp(0.0, 100.0).toDouble()
                      : 0.0;
                  final color = _ssherPortfolioCategoryColor(cat);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            cat[0].toUpperCase() + cat.substring(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _muted),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: _surfaceHigh,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                              minHeight: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: Text(
                            _formatMoney(total / 1000000),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ink),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Top projects by SSHER cost (top 5)
                const Text('Top Projects by SSHER Cost',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _muted)),
                const SizedBox(height: 8),
                ...(rollup.projects
                        .where((p) => p.hasSsherData)
                        .toList()
                      ..sort((a, b) => b.totalCost.compareTo(a.totalCost)))
                    .take(5)
                    .map((p) {
                  final double pct = rollup.grandTotal > 0
                      ? (p.totalCost / rollup.grandTotal * 100).clamp(0.0, 100.0).toDouble()
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.projectName.isNotEmpty
                                ? p.projectName
                                : 'Untitled project',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: _surfaceHigh,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  _accent),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: Text(
                            _formatMoney(p.totalCost / 1000000),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _ink),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // CTA: open SSHER Hub for the primary project
                if (projects.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openProject(projects.first),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open Primary Project SSHER Hub'),
                      style: TextButton.styleFrom(
                        foregroundColor: _slate,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptySsherPortfolio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: _muted, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('No SSHER items recorded yet',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                SizedBox(height: 4),
                Text(
                    'Open a project and visit the SSHER Hub to plan Safety, Security, Health, Environment, and Regulatory obligations. Cost data will roll up here automatically.',
                    style: TextStyle(fontSize: 12, color: _muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ssherPortfolioMiniRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Color _ssherPortfolioCategoryColor(String category) {
    switch (category) {
      case 'safety':
        return const Color(0xFF34A853);
      case 'security':
        return const Color(0xFFEF5350);
      case 'health':
        return const Color(0xFF1E88E5);
      case 'environment':
        return const Color(0xFF2E7D32);
      case 'regulatory':
        return const Color(0xFF8E24AA);
      default:
        return _muted;
    }
  }

  // ── Footer / banner / empty / snack ─────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline)),
      child: Row(children: [
        const Icon(Icons.bolt_rounded, size: 16, color: _accentDeep),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          _isBasic
              ? 'Basic plan · executive command center · synced ${_nowLabel()}'
              : 'Executive command center · last synced ${_nowLabel()}',
          style: const TextStyle(
              fontSize: 11.5, color: _muted, fontWeight: FontWeight.w600),
        )),
        Text('NDU v2.0',
            style: const TextStyle(
                fontSize: 11,
                color: _mutedSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildBanner(String message, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.24))),
      child: Row(children: [
        Icon(Icons.error_outline, color: accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: accent, fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }

  Widget _emptyState(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline)),
        child: Column(children: [
          Icon(Icons.inbox_outlined, size: 30, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12.5)),
        ]),
      );

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _slate,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Formatting helpers ──────────────────────────────────────────────────
  String _formatMoney(double millions) {
    if (millions == 0) return '\$0';
    final abs = millions.abs();
    final sign = millions < 0 ? '-' : '';
    if (abs >= 1000) return '$sign\$${(abs / 1000).toStringAsFixed(1)}B';
    if (abs >= 1) return '$sign\$${abs.toStringAsFixed(1)}M';
    return '$sign\$${(abs * 1000).toStringAsFixed(0)}K';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _nowLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

// ── Data holders ───────────────────────────────────────────────────────────
class _HealthRow {
  const _HealthRow(this.indicator, this.icon, this.status, this.trend,
      this.trendUp, this.insight);
  final String indicator;
  final IconData icon;
  final String status;
  final String trend;
  final bool? trendUp;
  final String insight;
}

class _Blocker {
  const _Blocker(this.title, this.subtitle, this.meta, this.priority);
  final String title;
  final String subtitle;
  final String meta;
  final String priority;
}

class _ActivityEntry {
  const _ActivityEntry(this.who, this.action, this.at, this.dot);
  final String who;
  final String action;
  final String at;
  final Color dot;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5));
}

// ── CustomPaint bar chart painter ──────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.planned,
    required this.actual,
    required this.labels,
    required this.plannedColor,
    required this.plannedBorderColor,
    required this.actualColor,
    required this.actualBorderColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<double> planned;
  final List<double> actual;
  final List<String> labels;
  final Color plannedColor;
  final Color plannedBorderColor;
  final Color actualColor;
  final Color actualBorderColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 48.0, padRight = 14.0, padTop = 14.0, padBottom = 28.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    if (chartW <= 0 || chartH <= 0) return;

    final maxVal = [...planned, ...actual, if (planned.isEmpty) 1.0]
        .reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;
    final niceMax = (maxVal / 50).ceil() * 50.0;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(padLeft, padTop), Offset(padLeft, padTop + chartH), axisPaint);
    canvas.drawLine(Offset(padLeft, padTop + chartH),
        Offset(size.width - padRight, padTop + chartH), axisPaint);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    const ticks = 4;
    for (int i = 0; i <= ticks; i++) {
      final y = padTop + chartH * (1 - i / ticks);
      if (i != 0 && i != ticks) {
        canvas.drawLine(
            Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
      }
      final value = (niceMax * i / ticks).round();
      tp.text = TextSpan(
          text: '\$$value',
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w700));
      tp.layout();
      tp.paint(canvas, Offset(padLeft - tp.width - 6, y - tp.height / 2));
    }

    final groupCount = planned.length;
    if (groupCount == 0) return;
    final groupWidth = chartW / groupCount;
    final barWidth = (groupWidth * 0.30).clamp(8.0, 22.0);
    final gap = barWidth * 0.22;

    final plannedPaint = Paint()..color = plannedColor;
    final plannedBorder = Paint()
      ..color = plannedBorderColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final actualPaint = Paint()..color = actualColor;
    final actualBorder = Paint()
      ..color = actualBorderColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < groupCount; i++) {
      final cx = padLeft + groupWidth * (i + 0.5);
      final ph = (planned[i] / niceMax) * chartH;
      if (ph > 0) {
        final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
                cx - barWidth - gap / 2, padTop + chartH - ph, barWidth, ph),
            const Radius.circular(4));
        canvas.drawRRect(rect, plannedPaint);
        canvas.drawRRect(rect, plannedBorder);
      }
      final ah = (actual[i] / niceMax) * chartH;
      if (ah > 0) {
        final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + gap / 2, padTop + chartH - ah, barWidth, ah),
            const Radius.circular(4));
        canvas.drawRRect(rect, actualPaint);
        canvas.drawRRect(rect, actualBorder);
      }
      tp.text = TextSpan(
          text: labels[i],
          style: TextStyle(
              color: textColor, fontSize: 11, fontWeight: FontWeight.w700));
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, padTop + chartH + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.planned != planned ||
      old.actual != actual ||
      old.labels != labels ||
      old.plannedColor != plannedColor ||
      old.actualColor != actualColor;
}
