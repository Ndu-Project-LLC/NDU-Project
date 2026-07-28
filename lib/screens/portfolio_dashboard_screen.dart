/// NDU Portfolio — PMO Executive Dashboard
///
/// Loads real data from Firestore via DashboardMetricsService and ProjectService.
/// Shows project statuses, budget, risks, phases, milestones — all live.
library;

import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/dashboard_metrics_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/widgets/compact_action_button.dart';
import 'package:ndu_project/widgets/shimmer_loading.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/screens/group_into_portfolio_screen.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';

class PortfolioDashboardScreen extends StatefulWidget {
 final String? portfolioId;

 const PortfolioDashboardScreen({super.key, this.portfolioId});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
 );
 }

 @override
 State<PortfolioDashboardScreen> createState() =>
 _PortfolioDashboardScreenState();
}

class _PortfolioDashboardScreenState extends State<PortfolioDashboardScreen>
 with SingleTickerProviderStateMixin {
 late AnimationController _fadeController;
 late Animation<double> _fadeAnimation;

 // ── Theme tokens ──
 static const _bg = Color(0xFFFFFFFF);
 static const _surface = Color(0xFFF8FAFC);
 static const _surfaceHigh = Color(0xFFF1F5F9);
 static const _surfaceHighest = Color(0xFFE2E8F0);
 static const _onSurface = Color(0xFF0F172A);
 static const _muted = Color(0xFF64748B);
 static const _outline = Color(0xFFE2E8F0);
 static const _gold = Color(0xFFD97706);
 static const _blue = Color(0xFF6366F1);
 static const _blueDeep = Color(0xFF4F46E5);
 static const _emerald = Color(0xFF059669);
 static const _amber = Color(0xFFD97706);
 static const _crimson = Color(0xFFDC2626);
 static const _crimsonBright = Color(0xFFEF4444);

 LinearGradient get _goldGrad => const LinearGradient(
 colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 );

  // ── Real data state ──
  DashboardMetrics? _metrics;
  List<ProjectRecord> _projects = [];
  bool _loading = true;
  String? _loadError;
  bool _loadTimedOut = false;
  static const _loadTimeout = Duration(seconds: 8);

  // ── Search state ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<ProjectRecord> get _filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    final q = _searchQuery.toLowerCase();
    return _projects.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.progressSnapshot.currentPhase.toLowerCase().contains(q);
    }).toList();
  }

  // ── View-more toggles (show 7 by default, expand to all) ──
  bool _showAllProjects = false;


 @override
 void initState() {
 super.initState();
 _fadeController = AnimationController(
 vsync: this, duration: const Duration(milliseconds: 600))
 ..forward();
 _fadeAnimation = CurvedAnimation(
 parent: _fadeController, curve: Curves.easeOutCubic);
 _loadData();  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _loadTimedOut = false;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      // ── Parallelize the two independent data loads ──
      // Previously these ran sequentially (metrics first, then projects),
      // doubling the wall-clock time. Now they run concurrently.
      // Also: pass includeActivities=false because the portfolio dashboard
      // only displays project status rollups, not individual activities —
      // skipping the activities subcollection saves N extra Firestore reads.
      final results = await Future.wait([
        DashboardMetricsService.load(includeActivities: false)
            .timeout(_loadTimeout, onTimeout: () => throw TimeoutException(
                'Dashboard metrics took longer than ${_loadTimeout.inSeconds}s')),
        ProjectService.streamProjects(
          ownerId: user?.uid,
          limit: 200,
          filterByOwner: true,
        ).first.timeout(_loadTimeout, onTimeout: () => throw TimeoutException(
            'Project stream took longer than ${_loadTimeout.inSeconds}s')),
      ]);

      final metrics = results[0] as DashboardMetrics;
      final projectsSnap = results[1] as List<ProjectRecord>;

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _projects = projectsSnap;
          _loading = false;
          _loadError = null;
          _loadTimedOut = false;
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('[PortfolioDashboard] load timeout: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadTimedOut = true;
          _loadError = 'Loading is taking longer than expected. '
              'This usually happens when you have many projects. '
              'Pull to refresh, or try again in a moment.';
        });
      }
    } catch (e) {
      debugPrint('[PortfolioDashboard] load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Could not load dashboard data. '
              'Check your connection and pull to refresh.';
        });
      }
    }
  }

 // ── Derived metrics from real data ──
 int get _totalProjects => _projects.length;
 int get _onTrackCount => _metrics?.projectsOnTrack ?? 0;
 int get _atRiskCount => _metrics?.projectsAtRisk ?? 0;
 int get _offTrackCount => _metrics?.projectsOffTrack ?? 0;
 int get _unknownCount =>
 _totalProjects - _onTrackCount - _atRiskCount - _offTrackCount;
 double get _onTrackPct =>
 _totalProjects > 0 ? _onTrackCount / _totalProjects : 0;
 double get _atRiskPct =>
 _totalProjects > 0 ? _atRiskCount / _totalProjects : 0;
 double get _offTrackPct =>
 _totalProjects > 0 ? _offTrackCount / _totalProjects : 0;

 int get _totalBudget => _projects.fold(0, (sum, p) {
 final inv = (p.investmentMillions * 1000000).round();
 return sum + inv;
 });

 double get _avgProgress => _totalProjects > 0
 ? _projects.fold<double>(0, (s, p) => s + p.progress) / _totalProjects
 : 0;

 int get _totalMilestones => _projects.fold(
 0, (s, p) => s + p.progressSnapshot.totalMilestones);
 int get _achievedMilestones => _projects.fold(
 0, (s, p) => s + p.progressSnapshot.achievedMilestones);

 int get _totalActivities =>
 _projects.fold(0, (s, p) => s + p.progressSnapshot.totalActivities);
 int get _completedActivities => _projects.fold(
 0, (s, p) => s + p.progressSnapshot.implementedActivities);
 int get _overdueActivities => _projects.fold(
 0, (s, p) => s + p.progressSnapshot.overdueActivities);

 // Group projects by current phase
 Map<String, int> get _phaseDistribution {
 final map = <String, int>{};
 for (final p in _projects) {
 final phase = p.progressSnapshot.currentPhase;
 map[phase] = (map[phase] ?? 0) + 1;
 }
 return map;
 }

 @override
 Widget build(BuildContext context) {
 NavigationContextService.instance
 .setLastClientDashboard(AppRoutes.portfolioDashboard);

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth < 600 ? 20.0 : 40.0;
            return Stack(
              children: [
                // Subtle atmospheric glows
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _blue.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  left: -80,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gold.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _loading
                      ? const PageShimmerSkeleton()
                      : (_loadError != null
                          ? _buildErrorState()
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: _blue,
                              backgroundColor: Colors.white,
                              strokeWidth: 3,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding, vertical: 28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 28),
                                    _buildSearchBar(),
                                    const SizedBox(height: 20),
                                    _buildGroupPortfolioSection(context),
                                    const SizedBox(height: 28),
                                    _buildKpis(context),
                                    const SizedBox(height: 28),
                                    _buildBento(context),
                                    const SizedBox(height: 72),
                                  ],
                                ),
                              ),
                            )),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Error / timeout state ──
  Widget _buildErrorState() {
    final isTimeout = _loadTimedOut;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout ? Icons.schedule_outlined : Icons.cloud_off_outlined,
              size: 56,
              color: _muted,
            ),
            const SizedBox(height: 16),
            Text(
              isTimeout ? 'Taking longer than expected' : 'Could not load data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 // ═══════════════════════════════════════════════════════════════════════
 // HEADER
 // ═══════════════════════════════════════════════════════════════════════
 Widget _buildHeader() {
 final user = FirebaseAuth.instance.currentUser;
 final displayName = FirebaseAuthService.displayNameOrEmail();
 final initials = _userInitials(displayName);

 return LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 960;

 final crumb = Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: _outline),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0D000000),
 blurRadius: 8,
 offset: Offset(0, 2)),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.view_quilt_outlined, size: 18, color: _muted),
 const SizedBox(width: 8),
 Flexible(
 child: Text(
 'Portfolio workspace overview',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: _muted,
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
 alignment: compact
 ? Alignment.center
 : Alignment.centerLeft,
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
 onPressed: () {
 if (!mounted) return;
 context.go('/${AppRoutes.dashboard}');
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _blue,
 foregroundColor: Colors.white,
 elevation: 2,
 shadowColor: const Color(0x1A000000),
 padding: const EdgeInsets.symmetric(
 horizontal: 26, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 textStyle:
 const TextStyle(fontWeight: FontWeight.w700),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.add_circle_outline, size: 22),
 const SizedBox(width: 10),
 Text('Create Project',
 style:
 TextStyle(fontFamily: appFontFamily)),
 const SizedBox(width: 6),
 const Icon(Icons.arrow_forward, size: 20),
 ],
 ),
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
 color: _muted,
 tooltip: 'Back',
 ),
 const SizedBox(width: 10),
 Expanded(child: crumb),
 ],
 ),
 const SizedBox(height: 22),
 Text(
 'Executive Portfolio Dashboard',
 style: TextStyle(
 color: _onSurface,
 fontSize: 26,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.3,
 fontFamily: appFontFamily,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 _totalProjects == 0
 ? 'No projects yet — create one to get started'
 : 'Strategic overview across $_totalProjects project${_totalProjects == 1 ? '' : 's'}',
 style: TextStyle(
 color: _muted,
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
 color: _surfaceHigh,
 border: Border.all(color: _outline, width: 1),
 ),
 child: ClipOval(
 child: photoUrl != null && photoUrl.isNotEmpty
 ? Image.network(photoUrl,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Center(
 child: Text(initials,
 style: TextStyle(
 color: _onSurface,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 fontFamily: appFontFamily)),
 ))
 : Center(
 child: Text(initials,
 style: TextStyle(
 color: _onSurface,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 fontFamily: appFontFamily)),
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
 Text(displayName,
 style: TextStyle(
 fontWeight: FontWeight.w700,
 color: _onSurface,
 fontFamily: appFontFamily)),
 if (user?.email != null && user!.email!.isNotEmpty)
 Text(user.email!,
 style: TextStyle(
 fontSize: 12, color: _muted, fontFamily: appFontFamily)),
 ],
 ),
 ),
 const PopupMenuDivider(),
 PopupMenuItem<String>(
 value: 'logout',
 child: Row(children: [
 Icon(Icons.logout, size: 18, color: _crimson),
 const SizedBox(width: 10),
 Text('Log Out',
 style: TextStyle(color: _crimson, fontFamily: appFontFamily)),
 ]),
 ),
 ],
 onSelected: (value) {
 if (value == 'logout') _handleLogout();
 },
 );
 }

 Future<void> _handleLogout() async {
 if (!mounted) return;
 final shouldLogout = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: const Text('Confirm Log Out'),
 content: const Text('Are you sure you want to log out?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: Theme.of(ctx).colorScheme.error,
 foregroundColor: Theme.of(ctx).colorScheme.onError,
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
 content: Text('Error logging out: $e'),
 backgroundColor: Colors.red));
 }
 }
 }
 }

 // ═══════════════════════════════════════════════════════════════════════
 // KPIs — REAL DATA
 // ═══════════════════════════════════════════════════════════════════════
 Widget _buildKpis(BuildContext context) {
 final screenWidth = MediaQuery.sizeOf(context).width;
 final isDesktop = screenWidth > 1000;
 final isTablet = screenWidth > 600;
 final sp = 16.0;

 final budgetStr = _totalBudget >= 1000000000
 ? '\$${(_totalBudget / 1000000000).toStringAsFixed(1)}B'
 : _totalBudget >= 1000000
 ? '\$${(_totalBudget / 1000000).toStringAsFixed(1)}M'
 : _totalBudget > 0
 ? '\$${(_totalBudget / 1000).toStringAsFixed(0)}K'
 : '\$0';

 final kpis = [
 (
 'Total Projects',
 '$_totalProjects',
 Icons.inventory_2_rounded,
 _gold,
 'All time',
 _muted,
 null,
 null,
 null,
 ),
 (
 'On Track',
 '${(_onTrackPct * 100).round()}%',
 Icons.check_circle_rounded,
 _gold,
 '$_onTrackCount project${_onTrackCount == 1 ? '' : 's'}',
 _muted,
 null,
 _gold,
 null,
 ),
 (
 'At Risk',
 '${(_atRiskPct * 100).round()}%',
 Icons.warning_amber_rounded,
 _gold,
 '$_atRiskCount project${_atRiskCount == 1 ? '' : 's'}',
 _muted,
 null,
 _gold,
 null,
 ),
 (
 'Off Track',
 '${(_offTrackPct * 100).round()}%',
 Icons.error_outline_rounded,
 _gold,
 '$_offTrackCount project${_offTrackCount == 1 ? '' : 's'}',
 _muted,
 null,
 _gold,
 null,
 ),
 (
 'Total Budget',
 budgetStr,
 Icons.account_balance_wallet_rounded,
 _gold,
 'Across all projects',
 _muted,
 null,
 null,
 null,
 ),
 (
 'Avg Progress',
 '${(_avgProgress * 100).round()}%',
 Icons.trending_up_rounded,
 _gold,
 '$_completedActivities/$_totalActivities activities',
 _muted,
 null,
 null,
 _avgProgress,
 ),
 ];

 if (isDesktop) {
 return Row(
 children: kpis.asMap().entries.map((entry) {
 final i = entry.key;
 final k = entry.value;
 return Expanded(
 child: Padding(
 padding: EdgeInsets.only(right: i < kpis.length - 1 ? sp : 0),
 child: _kpi(k),
 ),
 );
 }).toList(),
 );
 }

 final count = isTablet ? 3 : 2;
 final w = (screenWidth - 64 - sp * (count - 1)) / count;
 return Wrap(
 spacing: sp,
 runSpacing: sp,
 children: kpis.map((k) => SizedBox(width: w, child: _kpi(k))).toList());
 }

 Widget _kpi(dynamic k) {
 return _glassCard(
 glow: k.$4 as Color?,
 blur: 20,
 child: Stack(children: [
 if (k.$4 != null)
 Positioned(
 top: 0,
 left: 0,
 right: 0,
 child: Container(
 height: 3,
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 k.$4 as Color,
 (k.$4 as Color).withValues(alpha: 0)
 ])))),
 if (k.$8 != null)
 Positioned(
 left: 0,
 top: 0,
 bottom: 0,
 child: Container(
 width: 3,
 decoration: BoxDecoration(
 color: k.$8 as Color,
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(16),
 bottomLeft: Radius.circular(16))))),
 Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(k.$1 as String,
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.3,
 fontFamily: appFontFamily)),
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: (k.$4 as Color)
 .withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(8)),
 child: Icon(k.$3 as IconData,
 color: k.$4 as Color, size: 16)),
 ]),
 const SizedBox(height: 14),
 ShaderMask(
 shaderCallback: (b) => ((k.$4 == _gold)
 ? _goldGrad
 : LinearGradient(
 colors: [_onSurface, _onSurface]))
 .createShader(b),
 child: Text(k.$2 as String,
 style: TextStyle(
 color: Colors.white,
 fontSize: 30,
 fontWeight: FontWeight.w900,
 letterSpacing: -1,
 fontFamily: appFontFamily))),
 const SizedBox(height: 6),
 if (k.$9 != null) ...[
 ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: k.$9 as double,
 backgroundColor: _surfaceHighest,
 valueColor:
 AlwaysStoppedAnimation(_gold),
 minHeight: 4)),
 const SizedBox(height: 4),
 ],
 Row(children: [
 if (k.$7 != null)
 Icon(k.$7 as IconData, color: k.$6 as Color, size: 12),
 if (k.$7 != null) const SizedBox(width: 3),
 Text(k.$5 as String,
 style: TextStyle(
 color: k.$6 as Color,
 fontSize: 11,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)),
 ]),
 ])),
 ]));
 }

 // ═══════════════════════════════════════════════════════════════════════
 // BENTO GRID — REAL DATA
 // ═══════════════════════════════════════════════════════════════════════
 Widget _buildBento(BuildContext context) {
 final w = MediaQuery.sizeOf(context).width;
 final isDesktop = w > 1000;

 if (_totalProjects == 0) {
 return _emptyStateCard(
 'No projects in your portfolio yet',
 'Create a project from the dashboard to start tracking portfolio health.',
 Icons.inventory_2_outlined,
 );
 }  return Column(children: [
 if (isDesktop)
 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(flex: 8, child: _portfolioTable()),
 const SizedBox(width: 20),
 Expanded(flex: 4, child: _phaseChart()),
 ])
 else ...[
 _portfolioTable(),
 const SizedBox(height: 20),
 _phaseChart(),
 ],
 const SizedBox(height: 20),
 if (isDesktop)
 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(flex: 4, child: _statusDonut()),
 const SizedBox(width: 20),
 Expanded(flex: 4, child: _milestonesCard()),
 const SizedBox(width: 20),
 Expanded(flex: 4, child: _activitiesCard()),
 ])
 else ...[
 _statusDonut(),
 const SizedBox(height: 20),
 _milestonesCard(),
 const SizedBox(height: 20),
 _activitiesCard(),
 ],
 const SizedBox(height: 20),
 if (isDesktop)
 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Expanded(flex: 6, child: _upcomingMilestones()),
 const SizedBox(width: 20),
 Expanded(flex: 6, child: _overdueMilestones()),
 ])
 else ...[
 _upcomingMilestones(),
 const SizedBox(height: 20),
 _overdueMilestones(),
 ],
 ]);
 }

 // ═══════════════════════════════════════════════════════════════════════
 // SEARCH BAR
 // ═══════════════════════════════════════════════════════════════════════
 Widget _buildSearchBar() {
   return _glassCard(
     child: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
       child: Row(
         children: [
           Icon(Icons.search, size: 20, color: _muted),
           const SizedBox(width: 10),
           Expanded(
             child: TextField(
               controller: _searchController,
               onChanged: (v) => setState(() => _searchQuery = v),
               style: TextStyle(
                 fontSize: 14,
                 color: _onSurface,
                 fontFamily: appFontFamily,
               ),
               decoration: InputDecoration(
                 hintText: 'Search projects by name or phase...',
                 hintStyle: TextStyle(
                   fontSize: 14,
                   color: _muted.withValues(alpha: 0.6),
                   fontFamily: appFontFamily,
                 ),
                 border: InputBorder.none,
                 contentPadding: const EdgeInsets.symmetric(vertical: 12),
               ),
             ),
           ),
           if (_searchQuery.isNotEmpty)
             IconButton(
               onPressed: () {
                 _searchController.clear();
                 setState(() => _searchQuery = '');
               },
               icon: Icon(Icons.close_rounded, size: 18, color: _muted),
               tooltip: 'Clear search',
             ),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
             decoration: BoxDecoration(
               color: _searchQuery.isEmpty
                   ? _surfaceHighest.withValues(alpha: 0.4)
                   : _blue.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Text(
               '${_filteredProjects.length} project${_filteredProjects.length == 1 ? '' : 's'}',
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
                 color: _searchQuery.isEmpty ? _muted : _blue,
                 fontFamily: appFontFamily,
               ),
             ),
           ),
         ],
       ),
     ),
   );
 }

 // ═══════════════════════════════════════════════════════════════════════
 // GROUP PORTFOLIO SECTION — Group Into Portfolio + Activity Logs
 // ═══════════════════════════════════════════════════════════════════════
 Widget _buildGroupPortfolioSection(BuildContext context) {
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       // ── Action buttons row: Group Into Portfolio + Activity Logs ──
       LayoutBuilder(
         builder: (context, constraints) {
           final useColumn = constraints.maxWidth < 500;
           final buttons = [
             CompactActionButton(
               label: 'Group Into Portfolio',
               subtitle: 'Select up to 7 projects to combine',
               icon: Icons.pie_chart_outline_rounded,
               accent: const Color(0xFF4338CA),
               onTap: () {
                 // Open the expanded full-page Group Into Portfolio view
                 GroupIntoPortfolioScreen.open(context, _projects);
               },
             ),
             CompactActionButton(
               label: 'Activity Logs',
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
         },
       ),
       // NOTE: The inline "Group Projects Into A Portfolio" card has been
       // moved to a dedicated expanded full-page view (GroupIntoPortfolioScreen).
       // It is now only rendered when the user taps "Group Into Portfolio".
     ],
   );
 }



 // ── Helper: summary KPI chip ──
 Widget _summaryChip(String label, String value, Color color) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
     decoration: BoxDecoration(
       color: color.withValues(alpha: 0.08),
       borderRadius: BorderRadius.circular(10),
       border: Border.all(color: color.withValues(alpha: 0.15)),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           value,
           style: TextStyle(
             fontWeight: FontWeight.w800,
             fontSize: 14,
             color: color,
             fontFamily: appFontFamily,
           ),
         ),
         const SizedBox(width: 6),
         Text(
           label,
           style: TextStyle(
             fontSize: 10,
             fontWeight: FontWeight.w600,
             color: color.withValues(alpha: 0.8),
             fontFamily: appFontFamily,
           ),
         ),
       ],
     ),
   );
 }

 // ── Helper: numeric cell with subtle ratio indicator ──
 Widget _cellMetric(String text, {required double ratio}) {
   final numericColor = ratio >= 0.8
       ? _emerald
       : ratio >= 0.5
           ? _amber
           : ratio > 0
               ? _crimson
               : _muted;
   return Center(
     child: Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           text,
           style: TextStyle(
             fontWeight: FontWeight.w700,
             fontSize: 13,
             color: _onSurface,
             fontFamily: appFontFamily,
           ),
         ),
         const SizedBox(height: 3),
         ClipRRect(
           borderRadius: BorderRadius.circular(2),
           child: LinearProgressIndicator(
             value: ratio,
             minHeight: 3,
             backgroundColor: _surfaceHighest.withValues(alpha: 0.4),
             valueColor: AlwaysStoppedAnimation<Color>(numericColor),
           ),
         ),
       ],
     ),
   );
 }

 // ── Portfolio Table — REAL PROJECTS ──
 Widget _portfolioTable() {
   final sortedProjects = List<ProjectRecord>.from(_filteredProjects)
     ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

 return _glassCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Portfolio Overview',
 style: TextStyle(
 color: _onSurface,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.3,
 fontFamily: appFontFamily)),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 5),
 decoration: BoxDecoration(
 color: _surfaceHighest.withValues(alpha: 0.4),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: _outline.withValues(alpha: 0.3))),
 child: Text('$_totalProjects projects',
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily))),
 ])),
 Divider(height: 1, color: _outline.withValues(alpha: 0.2)),
 if (sortedProjects.isEmpty)
 Padding(
 padding: const EdgeInsets.all(24),
 child: Center(
 child: Text('No projects found',
 style: TextStyle(
 color: _muted, fontFamily: appFontFamily))))
 else ...[  // Show up to 7 by default
 for (var i = 0; i < _tblDisplayCount(sortedProjects.length) && i < sortedProjects.length; i++)
 _buildPortfolioRow(sortedProjects[i], i, _tblDisplayCount(sortedProjects.length)),
 if (sortedProjects.length > 7)
 _buildViewMoreToggle(
 isExpanded: _showAllProjects,
 totalCount: sortedProjects.length,
 onToggle: () {
 setState(() => _showAllProjects = !_showAllProjects);
 },
 ),
 ],
 ]));
 }

 // ── Phase Distribution Chart — REAL DATA ──
 Widget _phaseChart() {
 final phases = _phaseDistribution;
 final total = _totalProjects;
 final colors = <String, Color>{
 'Initiation': _blue,
 'Front End Planning': _blueDeep,
 'Planning': _blueDeep,
 'Design': _amber,
 'Execution': _gold,
 'Launch': _emerald,
 'Close-out': _muted,
 'Completed': _emerald,
 'Unknown': _surfaceHighest,
 };

 return _glassCard(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('PROJECTS BY PHASE',
 style: TextStyle(
 color: _muted,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 fontFamily: appFontFamily)),
 const SizedBox(height: 20),
 if (phases.isEmpty)
 Center(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Text('No phase data',
 style: TextStyle(
 color: _muted,
 fontFamily: appFontFamily))))
 else
 ...phases.entries.map((e) {
 final pct = total > 0 ? e.value / total : 0.0;
 final color = colors[e.key] ?? _muted;
 return Padding(
 padding: const EdgeInsets.only(bottom: 14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment:
 MainAxisAlignment.spaceBetween,
 children: [
 Text(e.key,
 style: TextStyle(
 color: _onSurface,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)),
 Text('${e.value}',
 style: TextStyle(
 color: color,
 fontSize: 14,
 fontWeight: FontWeight.w800,
 fontFamily: appFontFamily)),
 ]),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Stack(children: [
 Container(
 height: 22,
 decoration: BoxDecoration(
 color: _surface
 .withValues(alpha: 0.6),
 borderRadius:
 BorderRadius.circular(8))),
 FractionallySizedBox(
 widthFactor: pct,
 child: Container(
 height: 22,
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 color,
 color.withValues(
 alpha: 0.6)
 ]),
 borderRadius:
 BorderRadius.circular(
 8),
 boxShadow: [
 BoxShadow(
 color: color
 .withValues(
 alpha: 0.3),
 blurRadius: 8)
 ]))),
 ])),
 ]));
 }),
 ])));
 }

 // ── Status Donut — REAL DATA ──
 Widget _statusDonut() {
 final onTrack = _onTrackCount;
 final atRisk = _atRiskCount;
 final offTrack = _offTrackCount;
 final unknown = _unknownCount;
 final total = _totalProjects;

 return _glassCard(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('STATUS DISTRIBUTION',
 style: TextStyle(
 color: _muted,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 fontFamily: appFontFamily)),
 const SizedBox(height: 20),
 Row(children: [
 SizedBox(
 width: 110,
 height: 110,
 child: CustomPaint(
 painter: _DonutPainter(
 segments: [
 if (onTrack > 0)
 (_emerald, onTrack / total),
 if (atRisk > 0)
 (_amber, atRisk / total),
 if (offTrack > 0)
 (_crimson, offTrack / total),
 if (unknown > 0)
 (_surfaceHighest, unknown / total),
 ],
 trackColor:
 _surfaceHighest.withValues(alpha: 0.4)),
 child: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text('$total',
 style: TextStyle(
 color: _onSurface,
 fontSize: 22,
 fontWeight: FontWeight.w900,
 fontFamily: appFontFamily)),
 Text('TOTAL',
 style: TextStyle(
 color:
 _muted.withValues(alpha: 0.5),
 fontSize: 8,
 letterSpacing: 2,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)),
 ])))),
 const SizedBox(width: 24),
 Expanded(
 child: Column(children: [
 _rLeg('On Track', '$onTrack', _emerald),
 const SizedBox(height: 10),
 _rLeg('At Risk', '$atRisk', _amber),
 const SizedBox(height: 10),
 _rLeg('Off Track', '$offTrack', _crimson),
 ])),
 ]),
 ])));
 }

 // ── Milestones Summary — REAL DATA ──
 Widget _milestonesCard() {
 final total = _totalMilestones;
 final achieved = _achievedMilestones;
 final pct = total > 0 ? achieved / total : 0.0;

 return _glassCard(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('MILESTONES',
 style: TextStyle(
 color: _muted,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 fontFamily: appFontFamily)),
 const SizedBox(height: 20),
 Row(children: [
 _statusMetric('Total', '$total', _blue),
 const SizedBox(width: 16),
 _statusMetric('Achieved', '$achieved', _emerald),
 const SizedBox(width: 16),
 _statusMetric(
 'Remaining', '${total - achieved}', _amber),
 ]),
 const SizedBox(height: 16),
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: pct,
 backgroundColor: _surfaceHighest,
 valueColor:
 AlwaysStoppedAnimation(_emerald),
 minHeight: 8)),
 const SizedBox(height: 8),
 Text(
 '${(pct * 100).round()}% milestone completion rate',
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontFamily: appFontFamily)),
 ])));
 }

 // ── Activities Summary — REAL DATA ──
 Widget _activitiesCard() {
 final total = _totalActivities;
 final completed = _completedActivities;
 final overdue = _overdueActivities;
 final pct = total > 0 ? completed / total : 0.0;

 return _glassCard(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('ACTIVITIES',
 style: TextStyle(
 color: _muted,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 fontFamily: appFontFamily)),
 const SizedBox(height: 20),
 Row(children: [
 _statusMetric('Total', '$total', _blue),
 const SizedBox(width: 16),
 _statusMetric('Completed', '$completed', _emerald),
 const SizedBox(width: 16),
 _statusMetric(
 'Overdue', '$overdue', overdue > 0 ? _crimson : _muted),
 ]),
 const SizedBox(height: 16),
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: pct,
 backgroundColor: _surfaceHighest,
 valueColor:
 AlwaysStoppedAnimation(_blue),
 minHeight: 8)),
 const SizedBox(height: 8),
 Text('${(pct * 100).round()}% activity completion rate',
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontFamily: appFontFamily)),
 ])));
 }

 // ── Upcoming Milestones — REAL DATA ──
 Widget _upcomingMilestones() {
 // Find projects that are not yet completed and sort by progress
 final activeProjects = _projects
 .where((p) =>
 p.progressSnapshot.health != ProjectProgressHealth.completed)
 .toList()
 ..sort((a, b) =>
 b.progressSnapshot.completionPercent.compareTo(
 a.progressSnapshot.completionPercent));

 return _glassCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('ACTIVE PROJECTS',
 style: TextStyle(
 color: _onSurface,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: _gold.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8)),
 child: Icon(Icons.work_outline,
 color: _gold, size: 14)),
 ])),
 Divider(height: 1, color: _outline.withValues(alpha: 0.15)),
 if (activeProjects.isEmpty)
 Padding(
 padding: const EdgeInsets.all(24),
 child: Center(
 child: Text('All projects are completed!',
 style: TextStyle(
 color: _emerald,
 fontFamily: appFontFamily))))
 else
 ...activeProjects.take(5).map((p) => Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Text(
 p.name.isEmpty ? 'Untitled' : p.name,
 style: TextStyle(
 color: _gold.withValues(alpha: 0.9),
 fontSize: 13,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily),
 maxLines: 1,
 overflow: TextOverflow.ellipsis)),
 Text(p.progressSnapshot.currentPhase,
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontFamily: appFontFamily)),
 const SizedBox(width: 12),
 _badge(
 '${p.progressSnapshot.completionPercent}%'),
 ]))),
 ]));
 }

 // ── Overdue Items — REAL DATA ──
 Widget _overdueMilestones() {
 final overdueProjects = _projects
 .where((p) => p.progressSnapshot.overdueActivities > 0)
 .toList()
 ..sort((a, b) => b.progressSnapshot.overdueActivities
 .compareTo(a.progressSnapshot.overdueActivities));

 final hasOverdue = overdueProjects.isNotEmpty;

 return _glassCard(
 glow: hasOverdue ? _crimson : null,
 blur: 16,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
 decoration: BoxDecoration(
 color: _crimson.withValues(alpha: 0.06),
 border: Border(
 bottom: BorderSide(
 color: _crimson.withValues(alpha: 0.15)))),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('OVERDUE ITEMS',
 style: TextStyle(
 color: _crimsonBright,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1,
 fontFamily: appFontFamily)),
 if (_overdueActivities > 0)
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: _crimson.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(8)),
 child: Text('$_overdueActivities total',
 style: TextStyle(
 color: _crimsonBright,
 fontSize: 10,
 fontWeight: FontWeight.w800,
 fontFamily: appFontFamily))),
 ])),
 if (!hasOverdue)
 Padding(
 padding: const EdgeInsets.all(24),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Icons.check_circle,
 color: _emerald, size: 20),
 const SizedBox(width: 8),
 Text('No overdue items',
 style: TextStyle(
 color: _emerald,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily)),
 ]))
 else
 ...overdueProjects.take(5).map((p) => Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Text(
 p.name.isEmpty ? 'Untitled' : p.name,
 style: TextStyle(
 color: _onSurface,
 fontSize: 13,
 fontWeight: FontWeight.w600,
 fontFamily: appFontFamily),
 maxLines: 1,
 overflow: TextOverflow.ellipsis)),
 Text(p.progressSnapshot.currentPhase,
 style: TextStyle(
 color: _muted,
 fontSize: 12,
 fontFamily: appFontFamily)),
 const SizedBox(width: 12),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 3),
 decoration: BoxDecoration(
 color: _crimson.withValues(alpha: 0.15),
 borderRadius:
 BorderRadius.circular(8)),
 child: Text(
 '${p.progressSnapshot.overdueActivities}',
 style: TextStyle(
 color: _crimsonBright,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 fontFamily: appFontFamily))),
 ]))),
 ]));
 }

 // ═══════════════════════════════════════════════════════════════════════
 // VIEW-MORE TOGGLE & HEALTH HELPERS
 // ═══════════════════════════════════════════════════════════════════════

 /// "View All X projects" / "Show Less" toggle button.
  Widget _buildViewMoreToggle({
    required bool isExpanded,
    required int totalCount,
    bool compact = false,
    required VoidCallback onToggle,
  }) {
    final remaining = totalCount - 7;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 12 : 14,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _outline.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _blue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isExpanded
                  ? 'Show Less'
                  : 'View All $totalCount Projects',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _blue,
                fontFamily: appFontFamily,
              ),
            ),
            if (!isExpanded && remaining > 0) ...[  // e.g. "+3 more"
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+$remaining more',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                    fontFamily: appFontFamily,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Display count helpers (moved out of list literals for valid Dart) ──

  int _tblDisplayCount(int totalLength) =>
      _showAllProjects ? totalLength : (7 < totalLength ? 7 : totalLength);


  /// Builds a single row for the Portfolio Health Overview table.
  Widget _buildPortfolioRow(ProjectRecord p, int index, int displayCount) {
    final phase = p.progressSnapshot.currentPhase;
    final progress = p.progressSnapshot.completionPercent;
    final overdue = p.progressSnapshot.overdueActivities;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 14,
      ),
      decoration: BoxDecoration(
        color: index.isOdd
            ? _surface.withValues(alpha: 0.3)
            : Colors.transparent,
        border: index < displayCount - 1
            ? Border(
                bottom: BorderSide(
                  color: _outline.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name.isEmpty ? 'Untitled' : p.name,
                        style: TextStyle(
                          color: _onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: appFontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        phase,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 1, child: _badge('$progress%')),
          Expanded(
            flex: 1,
            child: _badge('$overdue', high: overdue > 0),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${p.updatedAt.day}/${p.updatedAt.month}/${p.updatedAt.year}',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openProject(p),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open'),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: appFontFamily,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProject(ProjectRecord p) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final provider = ProjectDataInherited.read(context);
      final success = await provider
          .loadFromFirebase(p.id)
          .timeout(const Duration(seconds: 35));

      if (!mounted) return;
      Navigator.of(context).pop();

      if (success) {
        context.go('/${AppRoutes.dashboard}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open "${p.name}". Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening project: $e')),
        );
      }
    }
  }

 // ═══════════════════════════════════════════════════════════════════════
 // HELPER WIDGETS
 // ═══════════════════════════════════════════════════════════════════════

 Widget _glassCard({required Widget child, Color? glow, double blur = 0}) {
 return Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 boxShadow: glow != null
 ? [BoxShadow(color: glow.withValues(alpha: 0.08), blurRadius: blur)]
 : null,
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(16),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
 child: Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: _outline, width: 1),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 8,
 offset: const Offset(0, 2))
 ],
 ),
 child: child,
 ),
 ),
 ),
 );
 }

 Widget _dot(Color c, {double size = 8}) => Container(
 width: size,
 height: size,
 decoration: BoxDecoration(
 color: c,
 shape: BoxShape.circle,
 boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]));

 Widget _badge(String count, {bool high = false}) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
 decoration: BoxDecoration(
 color: high
 ? _crimson.withValues(alpha: 0.12)
 : _surfaceHighest.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: high
 ? _crimson.withValues(alpha: 0.3)
 : _outline.withValues(alpha: 0.3))),
 child: Text(count,
 style: TextStyle(
 color: high ? _crimsonBright : _onSurface,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 fontFamily: appFontFamily)));

 Widget _rLeg(String l, String p, Color c) => Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: c,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 4)
 ])),
 const SizedBox(width: 8),
 Text(l,
 style:
 TextStyle(color: _onSurface, fontSize: 11, fontFamily: appFontFamily)),
 ]),
 Text(p,
 style: TextStyle(
 color: _onSurface,
 fontSize: 12,
 fontWeight: FontWeight.w800,
 fontFamily: appFontFamily)),
 ]);

 Widget _statusMetric(String label, String value, Color color) {
 return Expanded(
 child: Column(children: [
 Text(value,
 style: TextStyle(
 color: color,
 fontSize: 20,
 fontWeight: FontWeight.w900,
 fontFamily: appFontFamily)),
 const SizedBox(height: 2),
 Text(label,
 style: TextStyle(
 color: _muted,
 fontSize: 10,
 fontFamily: appFontFamily)),
 ]));
 }

  Widget _emptyStateCard(String title, String subtitle, IconData icon) {
    return _glassCard(
        child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
                child: Column(children: [
              Icon(icon, size: 48, color: _muted.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: appFontFamily)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontFamily: appFontFamily)),
            ]))));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

class _DonutPainter extends CustomPainter {
 final List<(Color, double)> segments;
 final Color trackColor;
 _DonutPainter({required this.segments, required this.trackColor});

 @override
 void paint(Canvas canvas, Size size) {
 final center = Offset(size.width / 2, size.height / 2);
 final radius = size.width / 2;
 const sw = 10.0;
 final paint = Paint()
 ..style = PaintingStyle.stroke
 ..strokeWidth = sw
 ..strokeCap = StrokeCap.round;
 canvas.drawCircle(center, radius - sw / 2, paint..color = trackColor);
 double start = -90 * 3.14159 / 180;
 const gap = 0.04;
 for (final (color, frac) in segments) {
 if (frac <= 0) continue;
 canvas.drawArc(
 Rect.fromCircle(center: center, radius: radius - sw / 2),
 start,
 frac * 2 * 3.14159 - gap,
 false,
 paint..color = color);
 start += frac * 2 * 3.14159;
 }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
