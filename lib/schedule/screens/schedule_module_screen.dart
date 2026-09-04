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
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';
import 'package:ndu_project/schedule/screens/list_view_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/widgets/add_line_dialog.dart';
import 'package:ndu_project/services/planning_sync_service.dart';
import 'package:ndu_project/schedule/utils/schedule_purchase_cost.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/cross_section_sync_card.dart';
import 'package:go_router/go_router.dart';


class ScheduleModuleScreen extends StatefulWidget {
  const ScheduleModuleScreen({super.key});

  static void open(BuildContext context) {
    context.push('/schedule');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSetupFromProjectContext();
      _autoSyncAll();
    });
  }

  /// Auto-setup the schedule using the project's already-captured context
  /// (project name + overall framework from the Project Framework screen).
  ///
  /// This SKIPS the 2-step Setup Wizard (which used to ask for project name
  /// + delivery model / "methodology"). The methodology is already captured
  /// upstream on the Project Framework screen, so re-asking here is redundant.
  /// Falls back to 'WATERFALL' if the framework is somehow unset.
  Future<void> _autoSetupFromProjectContext() async {
    if (!mounted) return;
    final provider = context.read<ScheduleProvider>();
    if (provider.setupComplete && provider.schedule != null) return;

    final data = ProjectDataHelper.getData(context, listen: false);
    final projectName =
        data.projectName.trim().isNotEmpty ? data.projectName.trim() : 'Project';
    final frameworkRaw = (data.overallFramework ?? '').trim();
    final deliveryModel = _normalizeDeliveryModel(frameworkRaw) ?? 'WATERFALL';

    provider.setup(
      projectName: projectName,
      deliveryModel: deliveryModel,
    );
  }

  /// Map the project's overallFramework value to the schedule delivery model
  /// vocabulary (AGILE / WATERFALL / HYBRID). Returns null if unrecognized.
  String? _normalizeDeliveryModel(String framework) {
    final f = framework.toLowerCase();
    if (f == 'agile') return 'AGILE';
    if (f == 'waterfall') return 'WATERFALL';
    if (f == 'hybrid') return 'HYBRID';
    return null;
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

  /// One-click "Pull scheduled purchases into the Cost Estimate".
  ///
  /// Core data movement (per the 2026-09-03 voice note): purchases already
  /// scheduled — "buy CPE", procurement packages, any procurement-domain
  /// work package — flow into the Cost Estimate as procurement cost lines.
  /// No AI involved. Each created line is stamped back onto its schedule
  /// activity (`costLineId`) and linked to the same WBS node the activity
  /// is attached to, so the skeleton (Schedule → Cost → WBS) stays tight.
  Future<void> _pullScheduledPurchases(
    BuildContext context,
    List<ScheduledPurchaseCandidate> candidates,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!mounted) return;

    final costProvider = context.read<CostEstimateProvider>();
    // Auto-setup mirrors the Cost Estimate module: opening the module
    // creates a default estimate, so the pull is always one click.
    if (costProvider.estimate == null || !costProvider.setupComplete) {
      final data = ProjectDataHelper.getData(context, listen: false);
      final projectName =
          data.projectName.trim().isNotEmpty ? data.projectName.trim() : 'Project';
      costProvider.setup(
        projectName: projectName,
        className: EstimateClass.class3,
        deliveryModel: DeliveryModel.waterfall,
      );
    }

    final result = costProvider.pullScheduledPurchases(candidates);
    if (result.pulled > 0) {
      final scheduleProvider = context.read<ScheduleProvider>();
      final wbsProvider = context.read<WBSProvider>();
      final wbs = wbsProvider.wbs;
      // Map WBS codes → node ids so lines can also get the bidirectional
      // costLineIds link (matching what the Cost Estimate dialog does).
      final nodeIdByCode = <String, String>{};
      if (wbs != null) {
        for (final flat in flattenWBS(wbs)) {
          if (flat.path.trim().isNotEmpty) {
            nodeIdByCode[flat.path.trim()] = flat.id;
          }
        }
      }
      final roots = scheduleProvider.schedule?.activities ?? const [];
      result.addedByActivityId.forEach((activityId, lineId) {
        final activity = findActivityById(roots, activityId);
        if (activity != null) {
          scheduleProvider.updateActivity(
            activityId,
            activity.copyWith(costLineId: lineId),
          );
          final code = (activity.wbsCode ?? '').trim();
          if (code.isNotEmpty) {
            final nodeId = nodeIdByCode[code];
            if (nodeId != null) {
              wbsProvider.linkCostLine(nodeId, lineId);
            }
          }
        }
      });
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
        result.pulled > 0
            ? 'Pulled ${result.pulled} scheduled purchase${result.pulled == 1 ? '' : 's'} into the Cost Estimate — each one starts at \$0 until you price it.'
            : (result.alreadyInEstimate > 0
                ? 'All scheduled purchases are already in the Cost Estimate ($result.alreadyInEstimate already present).'
                : 'All scheduled purchases are already in the Cost Estimate.'),
      ),
      duration: const Duration(seconds: 6),
      action: result.pulled > 0
          ? SnackBarAction(
              label: 'Price them now',
              onPressed: () => _pricePulledPurchases(
                  context, result.addedByActivityId.values.toList()),
            )
          : null,
    ));
  }

  /// Walkthrough that opens the manual cost-line dialog for each freshly
  /// pulled purchase (in pull order) so the user can price it right away.
  /// Skipping/cancelling a dialog moves on to the next line.
  Future<void> _pricePulledPurchases(
    BuildContext navigatorContext,
    List<String> lineIds,
  ) async {
    if (lineIds.isEmpty || !mounted) return;
    var priced = 0;
    for (final lineId in lineIds) {
      if (!mounted) break;
      final estimate =
          context.read<CostEstimateProvider>().estimate;
      CostLine? line;
      if (estimate != null) {
        for (final l in estimate.lines) {
          if (l.id == lineId) {
            line = l;
            break;
          }
        }
      }
      if (line == null) continue;
      final savedId = await showDialog<String>(
        context: navigatorContext,
        barrierDismissible: true,
        builder: (ctx) => AddLineDialog(
          defaultCategory: CostCategory.procurement,
          editingLine: line,
        ),
      );
      if (savedId != null && savedId.isNotEmpty) priced++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        priced > 0
            ? 'Priced $priced of ${lineIds.length} pulled purchase${lineIds.length == 1 ? '' : 's'}. Remaining ones stay \$0 until priced.'
            : 'No prices entered — you can price them anytime in the Cost Estimate Builder.',
      ),
      duration: const Duration(seconds: 4),
    ));
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

        // While auto-setup is in-flight (first frame), render a minimal
        // loading placeholder instead of the Setup Wizard. The
        // `_autoSetupFromProjectContext` post-frame callback will call
        // `provider.setup()` synchronously, so this state only lasts one
        // frame. We intentionally do NOT render `SetupWizardScreen` here
        // — the wizard used to ask the user for project name + delivery
        // model / methodology, but that information is already captured
        // upstream on the Project Framework screen.
        if (schedule == null || !provider.setupComplete) {
          return ResponsiveScaffold(
            activeItemLabel: 'Schedule',
            appBarTitle: 'Schedule',
            breadcrumbPhase: 'Planning Phase',
            breadcrumbTitle: 'Schedule',
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading schedule…',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // ---- Context banner data ----
        final projectName = schedule.projectName;
        final data = ProjectDataHelper.getData(context, listen: false);

        // Keep the schedule's delivery model in sync with the project's
        // Project Details methodology selection (Waterfall / Agile / Hybrid)
        // so methodology-dependent views (badge, agile hints, sync imports)
        // always reflect the current choice.
        final resolvedMethodology =
            ProjectDataHelper.resolvedProjectMethodology(data);
        final resolvedDeliveryModel =
            ProjectDataHelper.deliveryModelForMethodology(resolvedMethodology);
        if (schedule.basis.deliveryModel.toUpperCase() !=
            resolvedDeliveryModel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context
                  .read<ScheduleProvider>()
                  .syncDeliveryModel(resolvedDeliveryModel);
            }
          });
        }
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

        // Scheduled purchases → Cost Estimate candidates (core pull flow).
        final purchaseCandidates = schedule.activities.isEmpty
            ? const <ScheduledPurchaseCandidate>[]
            : collectPullablePurchases(schedule.activities)
                .map((a) => ScheduledPurchaseCandidate(
                      activityId: a.id,
                      title: a.name,
                      wbsRef: a.wbsCode,
                      activityCostLineId: a.costLineId,
                    ))
                .toList(growable: false);
        final pendingPurchasePull = purchaseCandidates
            .where((c) => !costProvider.isScheduledPurchaseRepresented(c))
            .toList(growable: false);

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // ── World-class Section Navigator ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'Schedule Navigation',
                  subtitle: 'Navigate between schedule sections',
                  icon: Icons.calendar_month_outlined,
                  tabs: const [
                    SectionTab(icon: Icons.build_outlined, label: 'Builder'),
                    SectionTab(icon: Icons.bar_chart, label: 'Gantt'),
                    SectionTab(icon: Icons.list_alt, label: 'List View'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                  isCollapsible: true,
                  initiallyCollapsed: true,
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
                          foregroundColor: const Color(0xFFB8860B),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                ),
              ),
              // ── Pull scheduled purchases into the Cost Estimate ─────────
              if (purchaseCandidates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: pendingPurchasePull.isEmpty
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pendingPurchasePull.isEmpty
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pendingPurchasePull.isEmpty
                              ? Icons.check_circle_outline
                              : Icons.shopping_cart_checkout,
                          size: 16,
                          color: pendingPurchasePull.isEmpty
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pendingPurchasePull.isEmpty
                                ? 'All ${purchaseCandidates.length} scheduled purchase${purchaseCandidates.length == 1 ? '' : 's'} are in the Cost Estimate.'
                                : '${pendingPurchasePull.length} scheduled purchase${pendingPurchasePull.length == 1 ? '' : 's'} not yet in the Cost Estimate.',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151)),
                          ),
                        ),
                        if (pendingPurchasePull.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _pullScheduledPurchases(
                                context, pendingPurchasePull),
                            icon: const Icon(Icons.arrow_downward, size: 14),
                            label: Text(
                                'Pull ${pendingPurchasePull.length} into Cost Estimate',
                                style: const TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB45309),
                              backgroundColor: const Color(0xFFFFF7ED),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // ── Cross-section sync card (WBS ↔ Schedule ↔ PC) ──────────
              const CrossSectionSyncCard(
                currentSection: CrossSection.schedule,
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    BuilderScreen(),
                    GanttScreen(),
                    ListViewScreen(),
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
