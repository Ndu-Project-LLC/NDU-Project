library;

/// Builder Screen — Treasury-treated cost estimate builder with 4 sub-tabs.
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient. Generous
///   whitespace, tabular figures everywhere, hairline borders, layered soft
///   shadows, and a bento-style composition.
///
/// Tabs: Direct Costs, Indirect Costs, SSHER & Quality, Additional Elements.
/// Shows cost lines grouped by category with add/edit/delete + live totals
/// sidebar (TotalsPanel).
///
/// Lusaka 32: a second view — **Schedule Work Packages** — shows every
/// scheduled work package in a table (work package, duration, cost) with
/// the cost loudest and tappable, so the estimator can price each package
/// without leaving the Builder.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/widgets/totals_panel.dart';
import 'package:ndu_project/cost_estimate/widgets/add_line_dialog.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
// `EstimationMethod` is declared in the WBS model library too, so that import
// hides it and the Cost Estimate's copy stays unambiguous.
import 'package:ndu_project/cost_estimate/utils/cost_descriptor_text.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/utils/schedule_purchase_cost.dart';
import 'package:ndu_project/schedule/utils/schedule_work_packages.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart' hide EstimationMethod;
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Which face of the Builder is showing (Lusaka 32): the category
  /// line builder, or the Schedule work-package table where every
  /// scheduled work package carries its duration and cost side by side.
  _BuilderViewMode _viewMode = _BuilderViewMode.lines;

  static const _subTabs = [
    ('Direct Costs', [
      CostCategory.labor,
      CostCategory.materials,
      CostCategory.software,
      CostCategory.procurement,
      CostCategory.travelTraining,
      CostCategory.construction,
    ]),
    ('Indirect Costs', [
      CostCategory.projectTeam,
      CostCategory.overheads,
      CostCategory.ga,
      CostCategory.facilities,
      CostCategory.insuranceCompliance,
    ]),
    ('SSHER & Quality', [
      CostCategory.ssher,
      CostCategory.quality,
    ]),
    ('Additional Elements', [
      CostCategory.riskAllowance,
      CostCategory.contingency,
      CostCategory.mgmtReserve,
      CostCategory.escalation,
      CostCategory.taxes,
      CostCategory.financing,
      CostCategory.startup,
      CostCategory.warranty,
      CostCategory.decommissioning,
      CostCategory.other,
    ]),
  ];

  // Tab accent tints — warm Treasury palette progression
  static const _tabTints = <Color>[
    Color(0xFFD97706), // Direct — amber (brand deep)
    Color(0xFFB8860B), // Indirect — violet
    Color(0xFFD97706), // SSHER & Quality — pink
    Color(0xFFD97706), // Additional — cyan
  ];
  static const _tabTintsSoft = <Color>[
    Color(0xFFFFF3E0),
    Color(0xFFF4EEFF),
    Color(0xFFFFF8E1),
    Color(0xFFFFF8E1),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final isBaselined = estimate.status == EstimateStatus.baselined ||
            estimate.status == EstimateStatus.rebaselined;
        final canEdit = provider.currentRole == RBACRole.editor ||
            provider.currentRole == RBACRole.approver ||
            provider.currentRole == RBACRole.admin;
        final canEditNow = canEdit && !isBaselined;

        final currencySymbol = UserPreferencesService.currencySymbolSync;
        final tabIndex = _tabController.index;
        final tabCategories = _subTabs[tabIndex].$2;
        final tabLines = estimate.lines
            .where((l) => tabCategories.contains(l.category))
            .toList();
        final tabTotal = tabLines.fold(0.0, (a, l) => a + l.total);
        final totalLines = estimate.lines.length;
        final grandTotal = estimate.totals.costBaseline;

        return Container(
          color: TreasuryTokens.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero command band ─────────────────────────────────
                TreasuryHeroBand(
                  eyebrow: 'COST ESTIMATE · BUILDER',
                  title: 'Cost Line Builder',
                  subtitle:
                      '$totalLines lines · ${estimate.className.label} · $currencySymbol${treasuryFmt(grandTotal)} baseline',
                  statusLabel: isBaselined
                      ? 'Baselined v${estimate.baseline?.version ?? 1}'
                      : 'Draft — open for edits',
                  statusLive: isBaselined,
                  contextChips: [
                    TreasuryHeroChip(
                      icon: Icons.flag_outlined,
                      label: 'Project',
                      value: estimate.projectName,
                    ),
                    TreasuryHeroChip(
                      icon: Icons.layers_outlined,
                      label: 'Active Tab',
                      value: _subTabs[tabIndex].$1,
                    ),
                    TreasuryHeroChip(
                      icon: Icons.shield_outlined,
                      label: 'Class',
                      value: estimate.className.label,
                    ),
                  ],
                  actions: [
                    // The base case sits ahead of "Add line": the estimate
                    // starts from the Schedule's work packages (2026-09-10).
                    if (canEditNow)
                      TreasuryHeroAction(
                        icon: Icons.download_rounded,
                        label: 'Start from Schedule',
                        primary: false,
                        onTap: () => _startFromSchedule(context),
                      ),
                    if (canEditNow)
                      TreasuryHeroAction(
                        icon: Icons.add_rounded,
                        label: 'Add line',
                        primary: true,
                        onTap: () => _showAddLineDialog(context, provider,
                            tabCategories.isNotEmpty
                                ? tabCategories.first
                                : CostCategory.labor),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 2. Premium KPI strip ─────────────────────────────────
                TreasuryKpiStrip(
                  kpis: [
                    TreasuryKpiSpec(
                      label: 'Tab Total',
                      value:
                          '$currencySymbol${treasuryFmt(tabTotal)}',
                      sub: '${tabLines.length} lines in this tab',
                      icon: Icons.account_balance_wallet_outlined,
                      tint: _tabTints[tabIndex],
                      tintSoft: _tabTintsSoft[tabIndex],
                    ),
                    TreasuryKpiSpec(
                      label: 'Estimate Total',
                      value:
                          '$currencySymbol${treasuryFmt(grandTotal)}',
                      sub: 'All categories combined',
                      icon: Icons.shield_outlined,
                      tint: const Color(0xFFD97706),
                      tintSoft: const Color(0xFFFFF3E0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Total Lines',
                      value: '$totalLines',
                      sub: 'Itemised cost lines',
                      icon: Icons.list_alt_rounded,
                      tint: const Color(0xFF10B981),
                      tintSoft: const Color(0xFFE7F8F0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Avg / Line',
                      value: totalLines > 0
                          ? '$currencySymbol${treasuryFmt(grandTotal / totalLines)}'
                          : '${currencySymbol}0',
                      sub: 'Mean cost across estimate',
                      icon: Icons.analytics_outlined,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3. View switch: line builder ↔ schedule packages ──
                _BuilderViewToggle(
                  mode: _viewMode,
                  onChanged: (mode) => setState(() => _viewMode = mode),
                ),
                const SizedBox(height: 14),
                if (_viewMode == _BuilderViewMode.lines)
                  _TreasurySubTabBar(
                    controller: _tabController,
                    tabs: _subTabs.map((t) => t.$1).toList(),
                    tints: _tabTints,
                    tintsSoft: _tabTintsSoft,
                    counts: _subTabs
                        .map((t) => estimate.lines
                            .where((l) => t.$2.contains(l.category))
                            .length)
                        .toList(),
                  ),
                if (isBaselined) ...[
                  const SizedBox(height: 14),
                  _BaselinedNotice(version: estimate.baseline?.version ?? 1,
                      remaining: estimate.baseline?.rebaselineRemaining ?? 0),
                ],
                const SizedBox(height: 18),

                // ── 4. Two-column: lines list + totals sidebar ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lines column — or the Schedule work-package table
                    // (Lusaka 32) when that view is showing.
                    Expanded(
                      child: _viewMode == _BuilderViewMode.lines
                          ? _buildLinesColumn(
                              context,
                              provider,
                              estimate,
                              tabCategories,
                              tabLines,
                              tabTotal,
                              canEditNow,
                              currencySymbol,
                              tabIndex,
                            )
                          : _buildSchedulePackagesColumn(
                              context,
                              provider,
                              estimate,
                              canEditNow,
                              currencySymbol,
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Totals sidebar
                    const SizedBox(
                      width: 320,
                      child: Padding(
                        padding: EdgeInsets.only(top: 0),
                        child: TotalsPanel(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinesColumn(
    BuildContext context,
    CostEstimateProvider provider,
    CostEstimate estimate,
    List<CostCategory> categories,
    List<CostLine> lines,
    double tabTotal,
    bool canEditNow,
    String currencySymbol,
    int tabIndex,
  ) {
    return TreasurySectionCard(
      title: _subTabs[tabIndex].$1,
      subtitle:
          '${lines.length} ${lines.length == 1 ? "line" : "lines"} · $currencySymbol${treasuryFmt(tabTotal)}',
      trailing: canEditNow
          ? TreasuryPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Add line',
              onPressed: () => _showAddLineDialog(context, provider,
                  categories.isNotEmpty ? categories.first : CostCategory.labor),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The product owner asked for the direct/indirect distinction to be
          // spelled out on the page (2026-09-10): "you can verify that direct
          // and indirect costs … can't be fed by the same thing … or there will
          // be a duplicate".
          _subTabDefinitionNote(tabIndex),
          const SizedBox(height: 14),
          if (lines.isEmpty)
            TreasuryEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No ${_subTabs[tabIndex].$1.toLowerCase()} yet',
              body:
                  'Add your first cost line in this category. The totals sidebar updates live as you build out the estimate.',
              ctaLabel: canEditNow ? 'Add first line' : null,
              onCta: canEditNow
                  ? () => _showAddLineDialog(context, provider,
                      categories.isNotEmpty ? categories.first : CostCategory.labor)
                  : null,
            )
          else
            Column(
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TreasuryLineRow(
                      line: line,
                      currencySymbol: currencySymbol,
                      canEdit: canEditNow,
                      onEdit: () => _showAddLineDialog(
                          context, provider, line.category, line),
                      onDelete: () => provider.removeLine(line.id),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Plain-language definition of each sub-tab's cost group, in the order of
  /// [_subTabs]. Direct cost is the scheduled delivery work; indirect cost is
  /// what supports the project without belonging to it. Keeping them visibly
  /// separate is what stops the same source feeding both and double-counting.
  static const _subTabDefinitions = <String>[
    'Direct cost is everything tied to delivering THIS project — the scheduled '
        'work packages and the contracts that carry them out.',
    'Indirect cost supports the project without belonging to it — shared '
        'staff, overheads, offices and systems used across projects. It must '
        'not be fed by the same sources as direct cost.',
    'SSHER & Quality covers the safety, health, environment and quality '
        'provisions carried for the project.',
    'Additional elements sit outside the delivery work — risk allowances, '
        'contingency, escalation, taxes and management reserve.',
  ];

  Widget _subTabDefinitionNote(int tabIndex) {
    final index = tabIndex < _subTabDefinitions.length ? tabIndex : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TreasuryTokens.brandSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TreasuryTokens.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: TreasuryTokens.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _subTabDefinitions[index],
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: TreasuryTokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Seed the estimate with **every work package on the Schedule** as an
  /// unpriced direct-cost line — the base case from the 2026-09-10 voice note:
  /// "the cost estimate … is supposed to start with the work packages from the
  /// Schedule as a direct cost".
  ///
  /// Plain data movement, no AI. Each new line is stamped back onto its
  /// schedule activity (`costLineId`) and linked to the WBS node the work
  /// package sits under, so repeat pulls stay idempotent and the Cost-by-WBS
  /// view can match by foreign key rather than by name.
  void _startFromSchedule(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final scheduleProvider = context.read<ScheduleProvider>();
    final costProvider = context.read<CostEstimateProvider>();

    final schedule = scheduleProvider.schedule;
    final activities = schedule?.activities ?? const [];
    if (activities.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('The Schedule has no work packages yet. Build the '
            'schedule first — the estimate starts from it.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final candidates = collectScheduleWorkPackages(activities)
        .map((wp) => ScheduleWorkPackageCandidate(
              activityId: wp.activityId,
              title: wp.title,
              wbsRef: wp.wbsRef,
              activityCostLineId: wp.activityCostLineId,
              category: wp.category,
            ))
        .toList(growable: false);

    final result = costProvider.pullScheduleWorkPackages(candidates);
    _stampScheduleLinks(context, result);

    messenger.showSnackBar(SnackBar(
      content: Text(
        result.pulled > 0
            ? 'Started from the Schedule — added ${result.pulled} work '
                'package${result.pulled == 1 ? '' : 's'} as direct cost. Price '
                'them to build the baseline.'
            : (result.alreadyInEstimate > 0
                ? 'All ${candidates.length} scheduled work package'
                    '${candidates.length == 1 ? '' : 's'} are already in the estimate.'
                : 'Nothing to add — the Schedule has no work packages to estimate.'),
      ),
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Link every line created by a schedule pull back to its schedule
  /// activity (`costLineId`) and the WBS node the work package sits
  /// under — shared by the hero-band pull and the single-package pull
  /// from the Schedule work-package table.
  void _stampScheduleLinks(
      BuildContext context, ScheduleWorkPackagePullResult result) {
    if (result.addedByActivityId.isEmpty) return;
    final scheduleProvider = context.read<ScheduleProvider>();
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;
    final nodeIdByCode = <String, String>{};
    if (wbs != null) {
      for (final flat in flattenWBS(wbs)) {
        final path = flat.path.trim();
        if (path.isNotEmpty) nodeIdByCode[path] = flat.id;
      }
    }
    // Snapshot taken before any mutation: `findActivityById` only reads.
    final roots = scheduleProvider.schedule?.activities ?? const [];
    result.addedByActivityId.forEach((activityId, lineId) {
      final activity = findActivityById(roots, activityId);
      if (activity == null) return;
      scheduleProvider.updateActivity(
        activityId,
        activity.copyWith(costLineId: lineId),
      );
      final code = (activity.wbsCode ?? '').trim();
      if (code.isEmpty) return;
      final nodeId = nodeIdByCode[code];
      if (nodeId != null) wbsProvider.linkCostLine(nodeId, lineId);
    });
  }

  /// The Schedule work-package view (Lusaka 32): a table like the
  /// Schedule's own list, picking up **every work package from the
  /// Schedule** — work package, duration, cost.
  ///
  /// The cost is the point of the view ("the cost aspect has to be
  /// very clear … obvious and jumping out"), so it is the loudest
  /// column and every cost cell is tappable. Duration rides along
  /// because adjusting a too-long duration is how an over-high cost
  /// comes down.
  Widget _buildSchedulePackagesColumn(
    BuildContext context,
    CostEstimateProvider provider,
    CostEstimate estimate,
    bool canEditNow,
    String currencySymbol,
  ) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final activities = scheduleProvider.schedule?.activities ?? const [];
    final candidates = collectScheduleWorkPackages(activities)
        .map((wp) => ScheduleWorkPackageCandidate(
              activityId: wp.activityId,
              title: wp.title,
              wbsRef: wp.wbsRef,
              activityCostLineId: wp.activityCostLineId,
              category: wp.category,
            ))
        .toList(growable: false);

    // Duration belongs to the Schedule; cost belongs to the estimate
    // line that represents the package (matched by foreign key first,
    // then by identical in-schedule line).
    var pricedCount = 0;
    var pricedTotal = 0.0;
    final rows = <_SchedulePackageRow>[];
    for (final candidate in candidates) {
      final activity = findActivityById(activities, candidate.activityId);
      final duration = activity == null
          ? '—'
          : formatDuration(activity.duration, activity.durationUnit);
      CostLine? matched;
      for (final line in estimate.lines) {
        if (CostEstimateProvider.isScheduleWorkPackageLine(candidate, line)) {
          matched = line;
          break;
        }
      }
      if (matched != null) {
        pricedCount++;
        pricedTotal += matched.total;
      }
      rows.add(_SchedulePackageRow(
        candidate: candidate,
        duration: duration,
        matchedLine: matched,
      ));
    }

    return TreasurySectionCard(
      title: 'Schedule Work Packages',
      subtitle: candidates.isEmpty
          ? 'Nothing scheduled yet'
          : '${candidates.length} work packages · $pricedCount of '
              '${candidates.length} priced · '
              '$currencySymbol${treasuryFmt(pricedTotal)}',
      trailing: canEditNow
          ? TreasuryPrimaryButton(
              icon: Icons.download_rounded,
              label: 'Start from Schedule',
              onPressed: () => _startFromSchedule(context),
            )
          : null,
      child: candidates.isEmpty
          ? const TreasuryEmptyState(
              icon: Icons.event_note_rounded,
              title: 'No work packages on the Schedule',
              body: 'This table picks up every work package from the '
                  'Schedule — its name, duration and cost. Build the '
                  'Schedule first, then price each package here.',
            )
          : _SchedulePackagesTable(
              rows: rows,
              canEdit: canEditNow,
              currencySymbol: currencySymbol,
              onEditCost: (row) =>
                  _editSchedulePackageCost(context, provider, row),
            ),
    );
  }

  /// Open the cost editor for one schedule work package (Lusaka 32).
  ///
  /// An already-pulled package opens its existing line for editing.
  /// A package not yet in the estimate is pulled first (as a $0
  /// direct-cost line, linked back to its activity and WBS node) and
  /// the editor opens on the fresh line — one tap from "unpriced" to
  /// "priced".
  void _editSchedulePackageCost(
    BuildContext context,
    CostEstimateProvider provider,
    _SchedulePackageRow row,
  ) {
    final candidate = row.candidate;
    CostLine? matched;
    for (final line in provider.estimate!.lines) {
      if (CostEstimateProvider.isScheduleWorkPackageLine(candidate, line)) {
        matched = line;
        break;
      }
    }
    if (matched != null) {
      _showAddLineDialog(context, provider, matched.category, matched);
      return;
    }

    final result = provider.pullScheduleWorkPackages([candidate]);
    final newLineId = result.addedByActivityId[candidate.activityId];
    if (newLineId != null) {
      _stampScheduleLinks(context, result);
      for (final line in provider.estimate!.lines) {
        if (line.id == newLineId) {
          _showAddLineDialog(context, provider, line.category, line);
          return;
        }
      }
    }
    // Fallback (e.g. the package was represented by an unlinked
    // line): open a plain add dialog under the package's category.
    _showAddLineDialog(context, provider, candidate.category);
  }

  void _showAddLineDialog(
    BuildContext context,
    CostEstimateProvider provider,
    CostCategory defaultCategory, [
    CostLine? editing,
  ]) {
    showAppDialog(
      context: context,
      builder: (ctx) => AddLineDialog(
        defaultCategory: defaultCategory,
        editingLine: editing,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY SUB-TAB BAR — pill-style with active accent tint
// ═══════════════════════════════════════════════════════════════════════════

class _TreasurySubTabBar extends StatelessWidget {
  const _TreasurySubTabBar({
    required this.controller,
    required this.tabs,
    required this.tints,
    required this.tintsSoft,
    required this.counts,
  });
  final TabController controller;
  final List<String> tabs;
  final List<Color> tints;
  final List<Color> tintsSoft;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TreasuryTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _TreasurySubTabPill(
                label: tabs[i],
                count: counts[i],
                tint: tints[i],
                tintSoft: tintsSoft[i],
                active: controller.index == i,
                onTap: () {
                  controller.animateTo(i);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreasurySubTabPill extends StatelessWidget {
  const _TreasurySubTabPill({
    required this.label,
    required this.count,
    required this.tint,
    required this.tintSoft,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color tint;
  final Color tintSoft;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? tint : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? Colors.white
                        : TreasuryTokens.inkSoft,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : tintSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : tint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BUILDER VIEW MODE — line builder ↔ schedule work packages (Lusaka 32)
// ═══════════════════════════════════════════════════════════════════════════

enum _BuilderViewMode {
  lines,
  schedulePackages;

  String get label => switch (this) {
        _BuilderViewMode.lines => 'Line Builder',
        _BuilderViewMode.schedulePackages => 'Schedule Work Packages',
      };

  IconData get icon => switch (this) {
        _BuilderViewMode.lines => Icons.receipt_long_rounded,
        _BuilderViewMode.schedulePackages => Icons.table_rows_rounded,
      };
}

class _BuilderViewToggle extends StatelessWidget {
  const _BuilderViewToggle({required this.mode, required this.onChanged});

  final _BuilderViewMode mode;
  final ValueChanged<_BuilderViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TreasuryTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          for (final m in _BuilderViewMode.values) ...[
            if (m.index > 0) const SizedBox(width: 4),
            Expanded(
              child: _ViewTogglePill(
                label: m.label,
                icon: m.icon,
                active: mode == m,
                onTap: () => onChanged(m),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewTogglePill extends StatelessWidget {
  const _ViewTogglePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? TreasuryTokens.brandDeep : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? Colors.white : TreasuryTokens.inkSoft,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? Colors.white : TreasuryTokens.inkSoft,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULE WORK-PACKAGES TABLE — work package · duration · cost (Lusaka 32)
// ═══════════════════════════════════════════════════════════════════════════

/// One row of the Schedule work-package table: the package itself,
/// its duration (owned by the Schedule) and the cost line that
/// prices it.
class _SchedulePackageRow {
  const _SchedulePackageRow({
    required this.candidate,
    required this.duration,
    required this.matchedLine,
  });

  final ScheduleWorkPackageCandidate candidate;
  final String duration;
  final CostLine? matchedLine;
}

class _SchedulePackagesTable extends StatelessWidget {
  const _SchedulePackagesTable({
    required this.rows,
    required this.canEdit,
    required this.currencySymbol,
    required this.onEditCost,
  });

  final List<_SchedulePackageRow> rows;
  final bool canEdit;
  final String currencySymbol;
  final void Function(_SchedulePackageRow row) onEditCost;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold(0.0, (sum, row) => sum + (row.matchedLine?.total ?? 0));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        columns: const [
          DataColumn(label: Text('Work Package')),
          DataColumn(label: Text('Duration')),
          DataColumn(label: Text('Cost')),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.candidate.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: TreasuryTokens.ink,
                        ),
                      ),
                      if ((row.candidate.wbsRef ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'WBS ${row.candidate.wbsRef}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: TreasuryTokens.muted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    row.duration,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: TreasuryTokens.inkSoft,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                DataCell(
                  _ScheduleCostCell(
                    line: row.matchedLine,
                    canEdit: canEdit,
                    currencySymbol: currencySymbol,
                    onTap: () => onEditCost(row),
                  ),
                ),
              ],
            ),
          // Carry total — the number the cost estimator is here for.
          DataRow(
            cells: [
              const DataCell(
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: TreasuryTokens.ink,
                  ),
                ),
              ),
              const DataCell(SizedBox.shrink()),
              DataCell(
                Text(
                  '$currencySymbol${treasuryFmt(total)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: TreasuryTokens.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The loudest cell in the table (Lusaka 32): "the cost aspect has to
/// be very clear to them. It has to be obvious and jumping out."
/// A priced package shows a bold tabular figure on a brand wash; an
/// unpriced one shows a muted dash. Tapping either opens the editor.
class _ScheduleCostCell extends StatelessWidget {
  const _ScheduleCostCell({
    required this.line,
    required this.canEdit,
    required this.currencySymbol,
    required this.onTap,
  });

  final CostLine? line;
  final bool canEdit;
  final String currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priced = line != null;
    final amount = Text(
      priced ? '$currencySymbol${treasuryFmt(line!.total)}' : '—',
      style: TextStyle(
        fontSize: 13,
        fontWeight: priced ? FontWeight.w900 : FontWeight.w600,
        color: priced ? TreasuryTokens.ink : TreasuryTokens.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (!canEdit) return amount;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: priced
              ? TreasuryTokens.brand.withValues(alpha: 0.14)
              : TreasuryTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: priced
                ? TreasuryTokens.brandDeep.withValues(alpha: 0.35)
                : TreasuryTokens.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            amount,
            const SizedBox(width: 4),
            Icon(
              priced ? Icons.edit_rounded : Icons.add_rounded,
              size: 13,
              color: priced ? TreasuryTokens.brandDeep : TreasuryTokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BASELINED NOTICE — Treasury-styled inline banner
// ═══════════════════════════════════════════════════════════════════════════

class _BaselinedNotice extends StatelessWidget {
  const _BaselinedNotice({required this.version, required this.remaining});
  final int version;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TreasuryTokens.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: TreasuryTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TreasuryTokens.warning.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_rounded,
                size: 15, color: TreasuryTokens.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimate is baselined (v$version)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TreasuryTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edits create variance entries. Re-baselines remaining: $remaining',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TreasuryTokens.muted,
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

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY LINE ROW — premium card for each cost line
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryLineRow extends StatelessWidget {
  const _TreasuryLineRow({
    required this.line,
    required this.currencySymbol,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });
  final CostLine line;
  final String currencySymbol;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          // Icon tile
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: TreasuryTokens.brand.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 18, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 12),
          // Description + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        // Descriptors arrive from the SSHER, Schedule and Risk
                        // pulls and are user-editable, so a doubled dash can
                        // already be stored. Normalising on display removes
                        // it without a data migration (Lusaka 25 (copy):
                        // "remove the double dashes, the double hyphens").
                        costDescriptorForDisplay(line.description),
                        style: const TextStyle(
                          color: TreasuryTokens.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (line.aiGenerated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC812)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFC812)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            color: Color(0xFFFFC812),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                    if (!line.inSchedule) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TreasuryTokens.warningSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: TreasuryTokens.warning
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'NOT IN SCHEDULE',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.label_outline,
                        size: 11,
                        color: TreasuryTokens.mutedSoft),
                    const SizedBox(width: 4),
                    Text(
                      line.category.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TreasuryTokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.source_outlined,
                        size: 11,
                        color: TreasuryTokens.mutedSoft),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        line.basisSource.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: TreasuryTokens.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Total
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              // `formatCurrency` already prefixes a symbol, so combining it
              // with `currencySymbol` rendered "$$4.2M". Group the number and
              // let the preference supply the symbol (which also keeps non-
              // USD/EUR/GBP currencies like ZMW from losing their symbol).
              '$currencySymbol${formatAmountGrouped(line.total)}',
              style: const TextStyle(
                color: TreasuryTokens.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.edit_outlined,
              onTap: onEdit,
              tint: TreasuryTokens.muted,
            ),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.delete_outline,
              onTap: onDelete,
              tint: const Color(0xFFDC2626),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tint,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: tint),
        ),
      ),
    );
  }
}
