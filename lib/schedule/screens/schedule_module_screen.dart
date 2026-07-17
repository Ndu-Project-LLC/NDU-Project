library;

/// Schedule Module Screen — main entry point for the Schedule module.
///
/// Uses [ResponsiveScaffold] with the standard app sidebar
/// (`InitiationLikeSidebar`) so it matches the rest of the app.
///
/// Sub-navigation between Builder / Gantt / List View is a horizontal
/// `TabBar` at the top of the content area (light-mode pills matching the
/// Project Controls screen), replacing the old dark navy left rail.
///
/// A subtle [ContextBanner] is shown between the [SectionNavigator] and the
/// tab content summarising upstream context (project name, WBS node count,
/// Cost Estimate total) so the user can see what data this page is drawing
/// from.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/section_navigator.dart';
import 'package:ndu_project/widgets/context_banner.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/setup_wizard_screen.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';
import 'package:ndu_project/schedule/screens/list_view_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/planning_sync_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';


class ScheduleModuleScreen extends StatefulWidget {
  const ScheduleModuleScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScheduleModuleScreen()),
    );
  }

  @override
  State<ScheduleModuleScreen> createState() => _ScheduleModuleScreenState();
}

class _ScheduleModuleScreenState extends State<ScheduleModuleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );
  bool _syncedAll = false;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSyncAll());
  }

  Future<void> _autoSyncAll() async {
    if (_syncedAll || !mounted) return;
    _syncedAll = true;
    final provider = context.read<ScheduleProvider>();
    final schedule = provider.schedule;
    if (schedule == null) return;
    final root = schedule.activities[0];
    if (root.children.isNotEmpty) return;
    await PlanningSyncService.syncAll(
      context: context,
      provider: provider,
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ScheduleProvider, WBSProvider, CostEstimateProvider>(
      builder: (context, provider, wbsProvider, costProvider, _) {
        final schedule = provider.schedule;

        // Setup state — show the setup wizard (which itself uses
        // ResponsiveScaffold so the sidebar stays visible).
        if (schedule == null || !provider.setupComplete) {
          return const SetupWizardScreen();
        }

        // ---- Context banner data ----
        final projectName = schedule.projectName;
        final wbs = wbsProvider.wbs;
        final wbsCounts = wbs != null ? countNodes(wbs) : null;
        final wbsNodeCount = wbsCounts != null
            ? (wbsCounts.level1 + wbsCounts.level2 + 1)
            : 0;
        final estimate = costProvider.estimate;
        final currency = estimate?.currency ?? 'USD';
        final costTotal = estimate != null
            ? estimate.lines.fold<double>(
                0,
                (s, l) => s + _effectiveScheduleContextLineTotal(l))
            : 0.0;

        final data = ProjectDataHelper.getData(context, listen: false);
        final fepMilestones = data.keyMilestones
            .where((m) => m.name.trim().isNotEmpty)
            .toList();
        final fepMilestoneCount = fepMilestones.length;

        // Count managed-import activities in the tree
        final tree = schedule.activities;
        int countBySource(String source) {
          int c = 0;
          for (final a in tree) {
            c += _countWithSource(a, source);
          }
          return c;
        }
        final syncedPkgs =
            countBySource(PlanningSyncService.importSourceWorkPackage);
        final syncedStories =
            countBySource(PlanningSyncService.importSourceAgileStory);
        int syncedMstones = 0;
        for (final a in tree) {
          syncedMstones += _countWithSource(
              a, PlanningSyncService.importSourceMilestone);
        }
        // Also count children of the Planning Milestones group
        for (final a in tree) {
          if (a.name == 'Planning Milestones') {
            syncedMstones =
                a.children.length;
          }
        }

        return ResponsiveScaffold(
          activeItemLabel: 'Schedule',
          appBarTitle: 'Schedule',
          breadcrumbPhase: 'Planning Phase',
          breadcrumbTitle: 'Schedule',
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // ── World-class Section Navigator ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'Schedule Navigation',
                  subtitle: 'Navigate between schedule sections',
                  icon: Icons.calendar_month_outlined,
                  tabs: [
                    SectionTab(icon: Icons.build_outlined, label: 'Builder'),
                    SectionTab(icon: Icons.bar_chart, label: 'Gantt'),
                    SectionTab(icon: Icons.list_alt, label: 'List View'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                ),
              ),
              // ── Context banner (drawn from WBS + Cost Estimate) ───────
              ContextBanner(
                storageKey: 'schedule_module_context_banner',
                items: [
                  ContextBannerItem(
                    label: 'Project',
                    value: projectName,
                    icon: Icons.flag_outlined,
                  ),
                  if (wbs != null && wbsCounts != null)
                    ContextBannerItem(
                      label: 'WBS',
                      value:
                          '$wbsNodeCount nodes · ${wbsCounts.level1} ${wbs.framework.level1Label}',
                      icon: Icons.account_tree_outlined,
                    ),
                  if (estimate != null)
                    ContextBannerItem(
                      label: 'Cost Estimate',
                      value: formatCurrency(costTotal, currency),
                      icon: Icons.attach_money,
                    ),
                  if (fepMilestoneCount > 0)
                    ContextBannerItem(
                      label: 'Planning Milestones',
                      value: '$syncedMstones / $fepMilestoneCount synced',
                      icon: Icons.flag_outlined,
                    ),
                  if (syncedPkgs > 0 || syncedStories > 0)
                    ContextBannerItem(
                      label: 'From Planning',
                      value: '${syncedPkgs + syncedStories} items synced',
                      icon: Icons.sync,
                    ),
                ],
              ),
              // ── Resync button ─────────────────────────────────────
              if (fepMilestoneCount > 0 || syncedPkgs > 0 || syncedStories > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await PlanningSyncService.syncAll(
                            context: context,
                            provider: provider,
                            replaceExisting: true,
                          );
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Resync from Planning'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                ),
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const BuilderScreen(),
                    const GanttScreen(),
                    const ListViewScreen(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mirror of [ComputeUtils] effective line total so the schedule context
  /// banner can show a variance-aware total without re-implementing the full
  /// totals computation. Kept private to avoid widening the cost estimate
  /// compute utils API.
  double _effectiveScheduleContextLineTotal(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  int _countWithSource(ScheduleActivity a, String source) {
    int c = a.importSource == source ? 1 : 0;
    for (final child in a.children) {
      c += _countWithSource(child, source);
    }
    return c;
  }
}
