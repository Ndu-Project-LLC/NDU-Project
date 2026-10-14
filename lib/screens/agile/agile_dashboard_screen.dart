import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/utils/agile_metrics_catalog.dart';
import 'package:ndu_project/utils/agile_project_context_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/agile_tracked_metrics_strip.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:go_router/go_router.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE DASHBOARD — World-Class Delivery Performance Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileDashboardScreen extends StatefulWidget {
  const AgileDashboardScreen({super.key});

  static void open(BuildContext context) {
    context.push('/agile-dashboard');
  }

  @override
  State<AgileDashboardScreen> createState() => _AgileDashboardScreenState();
}

class _AgileDashboardScreenState extends State<AgileDashboardScreen> {
  // Brand palette — yellow / amber
  static const Color _kAccent = Color(0xFFF59E0B);
  static const Color _kAccentLight = Color(0xFFFFC812);
  static const Color _kAccentBg = Color(0xFFFEF3C7);
  static const Color _kBackground = Colors.white;
  static const Color _kSurface = Colors.white;
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kHeadline = Color(0xFF111827);
  static const Color _kMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isSaving = false;

  // Sprint metrics, read from the project's sprints and stories. Everything is
  // zero or empty until the project has data, so no invented figures show.
  String _activeSprint = 'No sprint scheduled';
  DateTime? _sprintEnd;
  int _sprintDay = 0;
  int _sprintTotalDays = 0;
  int _velocity = 0;
  int _storiesCompleted = 0;
  int _storiesTotal = 0;
  int _storiesInProgress = 0;
  int _teamSize = 0;
  int _activeContributors = 0;
  double _sprintCompletion = 0;

  /// What this page reports, read from Metrics Planning rather than assumed.
  List<AgileMetric> _trackedMetrics = const [];
  bool _metricsUsingDefaults = false;

  // Burn-down in story points. The ideal line runs linearly from the sprint's
  // total points to zero. Actual holds only what is known: the starting total
  // and today's remaining points. Days without a value are null, because no
  // daily history is stored.
  List<double?> _burnDown = const [];
  List<double?> _idealBurn = const [];

  List<_HealthIndicator> _health = const [];
  List<_ActivityItem> _activity = const [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    final projectData = ProjectDataHelper.getData(context);
    if (mounted) setState(() => _isLoading = true);

    var sprints = <RoadmapSprint>[];
    var stories = <AgileTask>[];
    var metricsConfig = <String, dynamic>{};
    if (pid != null) {
      try {
        sprints = await RoadmapService.loadSprints(projectId: pid);
        stories = await ExecutionPhaseService.loadAgileTasks(projectId: pid);
        metricsConfig = await AgileWireframeService.loadMetricsConfig(pid);
      } catch (e) {
        debugPrint('Agile dashboard load error: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      // The tracked set comes from Metrics Planning, so this page reports what
      // the project said it would track. A project that has never chosen gets
      // the default set, and the strip says so.
      _trackedMetrics = AgileMetricsCatalog.trackedMetrics(metricsConfig);
      _metricsUsingDefaults =
          AgileMetricsCatalog.usesDefaultTrackedSet(metricsConfig);
      _applyProjectData(projectData, sprints, stories);
      _isLoading = false;
    });
  }

  /// Fills every figure on the page from the project's own sprints, stories,
  /// issues, risks and activities. Anything the project has not recorded stays
  /// empty or zero rather than falling back to sample values.
  void _applyProjectData(
    ProjectDataModel data,
    List<RoadmapSprint> sprints,
    List<AgileTask> stories,
  ) {
    final now = DateTime.now();
    final sprint = _pickSprint(sprints, now);
    final start = sprint?.startDate;
    final end = sprint?.endDate;
    final hasDates = start != null && end != null;
    final sprintStories = sprint == null
        ? const <AgileTask>[]
        : stories.where((s) => s.plannedSprintId == sprint.id).toList();

    _activeSprint = sprint == null
        ? 'No sprint scheduled'
        : (sprint.name.trim().isEmpty ? 'Sprint' : sprint.name.trim());
    _sprintEnd = end;
    _sprintTotalDays = (start != null && end != null)
        ? math.max(1, end.difference(start).inDays)
        : 0;
    _sprintDay = (start != null && end != null)
        ? (now.difference(start).inDays + 1).clamp(0, _sprintTotalDays).toInt()
        : 0;

    _storiesTotal = sprintStories.length;
    _storiesCompleted = sprintStories.where((s) => s.status == 'Done').length;
    _storiesInProgress = sprintStories
        .where((s) => s.status == 'In-Progress' || s.status == 'Testing')
        .length;
    _sprintCompletion =
        _storiesTotal == 0 ? 0.0 : _storiesCompleted / _storiesTotal;

    final totalPoints =
        sprintStories.fold<int>(0, (total, s) => total + s.storyPoints);
    final donePoints = sprintStories
        .where((s) => s.status == 'Done')
        .fold<int>(0, (total, s) => total + s.storyPoints);
    _velocity = donePoints;

    if (_sprintTotalDays > 0 && totalPoints > 0) {
      final days = math.max(2, _sprintTotalDays);
      _idealBurn = [
        for (var i = 0; i < days; i++) totalPoints * (1 - i / (days - 1)),
      ];
      _burnDown = List<double?>.filled(days, null);
      _burnDown[0] = totalPoints.toDouble();
      if (_sprintDay >= 1) {
        _burnDown[math.min(_sprintDay - 1, days - 1)] =
            (totalPoints - donePoints).toDouble();
      }
    } else {
      _burnDown = const [];
      _idealBurn = const [];
    }

    final people = AgileProjectContextHelper.people(data, limit: 200);
    _teamSize = people.length;
    _activeContributors = sprintStories
        .where((s) => s.status != 'Done' && s.assignedRole.trim().isNotEmpty)
        .map((s) => s.assignedRole.trim())
        .toSet()
        .length;

    final issues = AgileProjectContextHelper.issues(data, limit: 100);
    final risks = AgileProjectContextHelper.risks(data, limit: 100);
    final openIssues = issues.where((i) => i.status != 'Done').toList();
    final highRisks =
        risks.where((r) => r.probability * r.impact >= 12).length;

    final indicators = <_HealthIndicator>[];
    if (hasDates && sprintStories.isNotEmpty) {
      final expected =
          _sprintTotalDays == 0 ? 0.0 : _sprintDay / _sprintTotalDays;
      final adherence =
          expected == 0 ? 1.0 : math.min(1.0, _sprintCompletion / expected);
      indicators.add(_HealthIndicator(
        'Schedule Adherence',
        adherence,
        adherence >= 0.9 ? Colors.green : _kAccent,
        adherence >= 0.9 ? 'On Track' : 'Behind',
      ));
    }
    if (sprintStories.isNotEmpty) {
      final estimated = sprintStories.where((s) => s.storyPoints > 0).length;
      final coverage = estimated / sprintStories.length;
      indicators.add(_HealthIndicator(
        'Estimate Coverage',
        coverage,
        coverage >= 0.8
            ? Colors.green
            : (coverage >= 0.5 ? _kAccent : Colors.red),
        coverage >= 0.8 ? 'Estimated' : 'Partial',
      ));
    }
    final openCount = openIssues.length;
    indicators.add(_HealthIndicator(
      'Blocker Backlog',
      openCount == 0 ? 1.0 : 1 - math.min(openCount, 10) / 10,
      openCount == 0 ? Colors.green : (openCount <= 3 ? _kAccent : Colors.red),
      openCount == 0 ? 'Clear' : '$openCount open',
    ));
    indicators.add(_HealthIndicator(
      'Risk Exposure',
      highRisks == 0 ? 1.0 : 1 - math.min(highRisks, 5) / 5,
      highRisks == 0 ? Colors.green : Colors.red,
      highRisks == 0 ? 'Low' : '$highRisks high',
    ));
    _health = indicators;

    final projectActivities = [
      ...data.projectActivities,
      ...data.customProjectActivities,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _activity = [
      for (final activity in projectActivities
          .where((a) => a.title.trim().isNotEmpty)
          .take(6))
        _activityFromProject(activity, now),
      for (final issue in openIssues.take(2))
        _ActivityItem(
          issue.owner.trim().isEmpty ? 'Issue log' : issue.owner.trim(),
          'logged',
          issue.title,
          issue.due.isEmpty ? 'Open' : 'Due ${issue.due}',
          Icons.report_problem_outlined,
          issue.status == 'Blocked' ? Colors.red : _kAccent,
        ),
    ];
  }

  /// The sprint the dashboard reports: the one running now, else the next one
  /// to start, else the most recent. Undated sprints fall back to the first.
  RoadmapSprint? _pickSprint(List<RoadmapSprint> sprints, DateTime now) {
    if (sprints.isEmpty) return null;
    final dated = sprints
        .where((s) => s.startDate != null && s.endDate != null)
        .toList()
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
    if (dated.isEmpty) return sprints.first;
    for (final s in dated) {
      if (!now.isBefore(s.startDate!) &&
          now.isBefore(s.endDate!.add(const Duration(days: 1)))) {
        return s;
      }
    }
    for (final s in dated) {
      if (s.startDate!.isAfter(now)) return s;
    }
    return dated.last;
  }

  _ActivityItem _activityFromProject(ProjectActivity activity, DateTime now) {
    final assignee = activity.assignedTo?.trim() ?? '';
    final actor = assignee.isNotEmpty
        ? assignee
        : (activity.role.trim().isEmpty ? 'Project team' : activity.role.trim());
    var verb = 'added';
    var icon = Icons.add_circle_outline;
    var color = _kAccent;
    switch (activity.status) {
      case ProjectActivityStatus.implemented:
        verb = 'completed';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ProjectActivityStatus.acknowledged:
        verb = 'acknowledged';
        icon = Icons.track_changes;
        break;
      case ProjectActivityStatus.rejected:
        verb = 'rejected';
        icon = Icons.block;
        color = Colors.red;
        break;
      case ProjectActivityStatus.deferred:
        verb = 'deferred';
        icon = Icons.schedule;
        break;
      case ProjectActivityStatus.pending:
        break;
    }
    return _ActivityItem(
      actor,
      verb,
      activity.title.trim(),
      _relativeTime(activity.updatedAt, now),
      icon,
      color,
    );
  }

  String _relativeTime(DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_dashboard')
          .set({
        'activeSprint': _activeSprint,
        'sprintDay': _sprintDay,
        'sprintTotalDays': _sprintTotalDays,
        'velocity': _velocity,
        'storiesCompleted': _storiesCompleted,
        'storiesTotal': _storiesTotal,
        'teamMembers': _teamSize,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard metrics saved'),
            backgroundColor: _kAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Agile dashboard save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Dashboard'),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Agile Dashboard',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 20),
                        const PlanningPhaseHeader(
                          title: 'Agile Dashboard',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Dashboard',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          AgileTrackedMetricsStrip(
                            metrics: _trackedMetrics,
                            usingDefaults: _metricsUsingDefaults,
                          ),
                          const SizedBox(height: 16),
                          _buildMetricsRow(isMobile),
                          const SizedBox(height: 24),
                          _buildSprintProgressCard(),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildBurnDownCard()),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: _buildHealthCard()),
                              ],
                            )
                          else ...[
                            _buildBurnDownCard(),
                            const SizedBox(height: 24),
                            _buildHealthCard(),
                          ],
                          const SizedBox(height: 24),
                          _buildActivityFeed(),
                          const SizedBox(height: 24),
                          _buildActionBar(),
                          const SizedBox(height: 64),
                        ],
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(positioned: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar with logo ────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        Image.asset('assets/images/Logo.png',
            height: 36,
            cacheWidth: (MediaQuery.devicePixelRatioOf(context) * 150).round()),
        const SizedBox(width: 12),
        const Text('Ndu Project',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _kHeadline)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccentBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on, size: 14, color: _kAccent),
              SizedBox(width: 6),
              Text('LIVE DASHBOARD',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                      letterSpacing: 1.1)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Metric cards row ─────────────────────────────────────────────────────
  Widget _buildMetricsRow(bool isMobile) {
    final cards = <_MetricCard>[
      _MetricCard(
        title: 'Active Sprint',
        value: _activeSprint,
        sublabel: _sprintTotalDays > 0
            ? 'Day $_sprintDay of $_sprintTotalDays'
            : 'Add sprints in the Sprint Calendar',
        icon: Icons.directions_run,
        accent: _kAccent,
        accentBg: _kAccentBg,
      ),
      _MetricCard(
        title: 'Velocity',
        value: '$_velocity pts',
        sublabel: 'Story points completed this sprint',
        icon: Icons.speed,
        accent: Colors.green,
        accentBg: const Color(0xFFD1FAE5),
        metricKey: 'velocity',
      ),
      _MetricCard(
        title: 'Stories Completed',
        value: '$_storiesCompleted / $_storiesTotal',
        sublabel: '${(_sprintCompletion * 100).toInt()}% complete',
        icon: Icons.task_alt,
        accent: const Color(0xFFFFC812),
        accentBg: const Color(0xFFFEF3C7),
        trend: '$_storiesInProgress in progress',
        metricKey: 'throughput',
      ),
      _MetricCard(
        title: 'Team Members',
        value: '$_teamSize',
        sublabel: '$_activeContributors with open stories',
        icon: Icons.groups,
        accent: const Color(0xFFB8860B),
        accentBg: const Color(0xFFFFF8E1),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMetricCard(c),
                ))
            .toList(),
      );
    }
    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildMetricCard(c),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(_MetricCard c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(c.icon, size: 18, color: c.accent),
              ),
              const Spacer(),
              if (c.trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync,
                      size: 12,
                      color: _kMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(c.trend!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(c.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kMuted)),
              ),
              if (c.metricKey != null) ...[
                const SizedBox(width: 6),
                const Tooltip(
                  message: 'Reported because Metrics Planning tracks it',
                  child: Icon(Icons.check_circle,
                      size: 12, color: Color(0xFF059669)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(c.value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          Text(c.sublabel,
              style: const TextStyle(fontSize: 11, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Sprint progress card ─────────────────────────────────────────────────
  Widget _buildSprintProgressCard() {
    final pct = (_sprintCompletion * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Sprint Progress — $_activeSprint',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${pct.toInt()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _sprintCompletion,
              minHeight: 14,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(_kAccentLight),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('$_storiesCompleted Completed', Colors.green),
              const SizedBox(width: 8),
              _chip('${_storiesTotal - _storiesCompleted} Remaining', _kAccent),
              if (_sprintTotalDays > 0) ...[
                const SizedBox(width: 8),
                _chip('Day $_sprintDay/$_sprintTotalDays', const Color(0xFFFFC812)),
              ],
              const Spacer(),
              if (_sprintEnd != null)
                Text(
                    'Ends ${_sprintEnd!.day}/${_sprintEnd!.month}/${_sprintEnd!.year}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Burn-down chart ──────────────────────────────────────────────────────
  Widget _buildBurnDownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Sprint Burn-down',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _legendDot(_kAccentLight, 'Actual'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFCBD5E1), 'Ideal'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _burnDown.isEmpty
                ? const Center(
                    child: Text(
                      'The burn-down appears once the sprint has planned story points.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _kMuted),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _BurnDownPainter(
                      actual: _burnDown,
                      ideal: _idealBurn,
                      accent: _kAccentLight,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                _burnDown.length,
                (i) => Text('D${i + 1}',
                    style: const TextStyle(fontSize: 10, color: _kMuted))),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: _kMuted)),
      ],
    );
  }

  // ── Health indicators ────────────────────────────────────────────────────
  Widget _buildHealthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 20, color: _kAccent),
              SizedBox(width: 8),
              Text('Sprint Health',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 16),
          if (_health.isEmpty)
            const Text(
              'Health indicators appear once sprint stories or project issues are recorded.',
              style: TextStyle(fontSize: 12, color: _kMuted),
            )
          else
            ..._health.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(h.label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kHeadline)),
                        const Spacer(),
                        Text(h.status,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: h.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: h.value,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation<Color>(h.color),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Activity feed ─────────────────────────────────────────────────────────
  Widget _buildActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 14),
                label: const Text('Filter'),
                style: TextButton.styleFrom(foregroundColor: _kAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_activity.isEmpty)
            const Text(
              'No recent activity is recorded for this project yet.',
              style: TextStyle(fontSize: 12, color: _kMuted),
            )
          else
            ..._activity.map((a) => _buildActivityItem(a)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(_ActivityItem a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(a.icon, size: 16, color: a.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: _kHeadline, height: 1.4),
                children: [
                  TextSpan(
                      text: a.actor,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: ' ${a.verb} ',
                      style: const TextStyle(color: _kMuted)),
                  TextSpan(
                      text: a.target,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Text(a.time, style: const TextStyle(fontSize: 11, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Action bar (save / refresh) ───────────────────────────────────────────
  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveData,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_isSaving ? 'Saving…' : 'Save Metrics'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper models & painters
// ═══════════════════════════════════════════════════════════════════════════
class _MetricCard {
  final String title;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String? trend;

  /// The Metrics Planning key this card reports, when it reports one at all.
  /// Cards without a key (sprint context, team capacity) are context, not
  /// tracked metrics — the review's "it does not look like it's driving any
  /// certain output" was about tiles nobody could trace back to a metric.
  final String? metricKey;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.accent,
    required this.accentBg,
    this.trend,
    this.metricKey,
  });
}

class _HealthIndicator {
  final String label;
  final double value;
  final Color color;
  final String status;
  const _HealthIndicator(this.label, this.value, this.color, this.status);
}

class _ActivityItem {
  final String actor;
  final String verb;
  final String target;
  final String time;
  final IconData icon;
  final Color color;
  const _ActivityItem(
      this.actor, this.verb, this.target, this.time, this.icon, this.color);
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF59E0B)),
            SizedBox(height: 16),
            Text('Loading sprint dashboard…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BurnDownPainter extends CustomPainter {
  final List<double?> actual;
  final List<double?> ideal;
  final Color accent;
  _BurnDownPainter({
    required this.actual,
    required this.ideal,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...actual, ...ideal].whereType<double>();
    final maxVal = values.isEmpty
        ? 1.0
        : math.max(1.0, values.reduce((a, b) => a > b ? a : b));
    final w = size.width;
    final h = size.height;
    const pad = 8.0;
    final count = math.max(actual.length, ideal.length);

    double xOf(int i) =>
        count <= 1 ? w / 2 : pad + (w - 2 * pad) * i / (count - 1);
    // Higher remaining work sits higher on the chart.
    double yOf(double value) => pad + (h - 2 * pad) * (1 - value / maxVal);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad + (h - 2 * pad) * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    // Path through the known values only. Gaps are skipped, not drawn as zero.
    Path pathFor(List<double?> series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < series.length; i++) {
        final value = series[i];
        if (value == null) continue;
        final x = xOf(i);
        final y = yOf(value);
        if (started) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          started = true;
        }
      }
      return path;
    }

    // Ideal line
    final idealPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(pathFor(ideal), idealPaint);

    final knownActual = [
      for (var i = 0; i < actual.length; i++)
        if (actual[i] != null) i,
    ];
    if (knownActual.isEmpty) return;

    // Actual filled area
    if (knownActual.length > 1) {
      final areaPath = pathFor(actual)
        ..lineTo(xOf(knownActual.last), h - pad)
        ..lineTo(xOf(knownActual.first), h - pad)
        ..close();
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(areaPath, areaPaint);
    }

    // Actual line
    final actualPaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(pathFor(actual), actualPaint);

    // Points
    for (final i in knownActual) {
      final center = Offset(xOf(i), yOf(actual[i]!));
      canvas.drawCircle(center, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
          center,
          4,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _BurnDownPainter old) =>
      old.actual != actual || old.ideal != ideal || old.accent != accent;
}
