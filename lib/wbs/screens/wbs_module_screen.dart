library;

/// WBS Module Screen — main entry point for the WBS module.
///
/// Uses [ResponsiveScaffold] with the standard app sidebar
/// (`InitiationLikeSidebar`) so it matches the rest of the app.
///
/// Sub-navigation between Builder / AI Generator / Validator / Export & Link
/// is a horizontal `TabBar` at the top of the content area (light-mode pills
/// matching the Project Controls screen), replacing the old dark navy left
/// rail.
///
/// A subtle [ContextBanner] is shown between the [SectionNavigator] and the
/// tab content summarising the upstream Initiation Phase context (project
/// name, solutions count, business case preview) so the user can see what
/// data this page is drawing from.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/section_navigator.dart';
import 'package:ndu_project/widgets/context_banner.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/screens/wbs_builder_screen.dart';
import 'package:ndu_project/wbs/screens/framework_picker_screen.dart';
import 'package:ndu_project/widgets/cost_by_wbs_tab.dart';
import 'package:ndu_project/wbs/screens/wbs_ai_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_validator_screen.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/providers/project_data_provider.dart';

class WBSModuleScreen extends StatefulWidget {
  const WBSModuleScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WBSModuleScreen()),
    );
  }

  @override
  State<WBSModuleScreen> createState() => _WBSModuleScreenState();
}

class _WBSModuleScreenState extends State<WBSModuleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );
  bool _wbsReviewedConfirmed = false;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
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
    return Consumer3<WBSProvider, ProjectDataProvider, CostEstimateProvider>(
      builder: (context, provider, projectProvider, costProvider, _) {
        final wbs = provider.wbs;

        // Still loading from storage — wait
        if (provider.isLoadingFromStorage) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(LightModeColors.accent),
            ),
          );
        }

        // No WBS yet — show the framework picker so the user chooses
        // their WBS dimension (deliverable, discipline, geographic, etc.)
        if (wbs == null || !provider.setupComplete) {
          return const FrameworkPickerScreen();
        }

        final projectData = projectProvider.projectData;
        final projectName = (projectData.projectName).trim().isNotEmpty
            ? projectData.projectName
            : wbs.projectName;
        final solutionsCount = projectData.potentialSolutions.length;
        final businessCasePreview =
            _clamp((projectData.businessCase).trim(), max: 50);
        final fm = wbs.framework;
        final totalNodes = countAllNodes(wbs.level0);
        final hasCostEstimate = costProvider.estimate != null;

        return ResponsiveScaffold(
          activeItemLabel: 'Work Breakdown Structure',
          appBarTitle: 'Work Breakdown Structure',
          breadcrumbPhase: 'Planning Phase',
          breadcrumbTitle: 'WBS',
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // ── World-class Section Navigator ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'WBS Navigation',
                  subtitle: 'Navigate between WBS sections',
                  icon: Icons.account_tree_outlined,
                  tabs: [
                    SectionTab(icon: Icons.folder_open, label: 'Builder'),
                    SectionTab(icon: Icons.auto_awesome, label: 'AI Generator'),
                    SectionTab(
                        icon: Icons.check_circle_outline, label: 'Validator'),
                    SectionTab(
                        icon: Icons.attach_money_outlined,
                        label: 'Cost by WBS',
                        enabled: hasCostEstimate),
                    SectionTab(icon: Icons.trending_up, label: 'Export & Link'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                ),
              ),
              // ── Framework dimension indicator ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(fm.iconData, size: 14, color: LightModeColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Dimension: ${fm.label}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'L0–L${fm.maxDepth} · $totalNodes nodes',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const WBSBuilderScreen(),
                    const WBSAIScreen(),
                    const WBSValidatorScreen(),
                    hasCostEstimate
                        ? const CostByWBSTab()
                        : _buildCostByWBSPlaceholder(),
                    const _ExportAndLinkTab(),
                  ],
                ),
              ),
              // Navigation footer
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Confirmation gate
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _wbsReviewedConfirmed,
                              onChanged: (checked) => setState(
                                  () => _wbsReviewedConfirmed =
                                      checked ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'I confirm I have reviewed all information needs before the WBS section can be activated.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF334155),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LaunchPhaseNavigation(
                      backLabel: PlanningPhaseNavigation.backLabel(
                          'work_breakdown_structure'),
                      nextLabel: PlanningPhaseNavigation.nextLabel(
                          'work_breakdown_structure'),
                      onBack: () => PlanningPhaseNavigation.goToPrevious(
                          context, 'work_breakdown_structure'),
                      onNext: () => PlanningPhaseNavigation.goToNext(
                          context, 'work_breakdown_structure'),
                      nextEnabled: _wbsReviewedConfirmed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCostByWBSPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            const Text(
              'Cost by WBS is not yet available.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete the Cost Estimate section first to unlock this view.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clamp a string to [max] characters, appending an ellipsis if truncated.
  String _clamp(String value, {int max = 50}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }
}

/// Export & Link tab — exports the WBS as JSON or ASCII tree, and shows the
/// link-to-Cost-Estimate affordance.
class _ExportAndLinkTab extends StatelessWidget {
  const _ExportAndLinkTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<WBSProvider, CostEstimateProvider>(
      builder: (context, provider, costProvider, _) {
        final wbs = provider.wbs;
        if (wbs == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final counts = countNodes(wbs);
        final json = const JsonEncoder.withIndent('  ').convert({
          'id': wbs.id,
          'projectName': wbs.projectName,
          'framework': wbs.framework.name,
          'frameworkLabel': wbs.framework.label,
          'level1Label': wbs.framework.level1Label,
          'level2Label': wbs.framework.level2Label,
          'level0': _nodeToJson(wbs.level0),
        });
        final ascii = _toAsciiTree(wbs.level0);

        // ---- Cost-estimate summary computation ----
        final estimate = costProvider.estimate;
        final allLines = estimate?.lines ?? const <CostLine>[];
        final currency = estimate?.currency ?? 'USD';
        final totalCost =
            allLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));
        final linkedLineIds = <String>{};
        void collect(WBSNode n) {
          for (final id in (n.costLineIds ?? const <String>[])) {
            linkedLineIds.add(id);
          }
          for (final c in n.children) {
            collect(c);
          }
        }

        collect(wbs.level0);
        // Also treat cost lines whose wbsRef matches a node code as linked.
        final wbsCodes = <String>{};
        for (final flat in flattenWBS(wbs)) {
          if (flat.path.isNotEmpty) wbsCodes.add(flat.path);
        }
        final linkedLines = allLines.where((l) {
          if (linkedLineIds.contains(l.id)) return true;
          final ref = (l.wbsRef ?? '').trim();
          return ref.isNotEmpty && wbsCodes.contains(ref);
        }).toList();
        final unlinkedLines = allLines.where((l) {
          if (linkedLineIds.contains(l.id)) return false;
          final ref = (l.wbsRef ?? '').trim();
          return !(ref.isNotEmpty && wbsCodes.contains(ref));
        }).toList();
        final linkedTotal =
            linkedLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));
        final unlinkedTotal =
            unlinkedLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));

        // Per-WBS-node linked totals (only nodes that actually have links).
        final nodeLinkedTotals = <MapEntry<WBSNode, double>>[];
        void walk(WBSNode n) {
          final nodeLines = allLines.where((l) {
            if ((n.costLineIds ?? const []).contains(l.id)) return true;
            final ref = (l.wbsRef ?? '').trim();
            return ref.isNotEmpty && ref == n.code;
          });
          final sum =
              nodeLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));
          if (sum > 0) {
            nodeLinkedTotals.add(MapEntry(n, sum));
          }
          for (final c in n.children) {
            walk(c);
          }
        }

        walk(wbs.level0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: LightModeColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text('Export & Link',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Export the WBS as JSON or ASCII tree, or link WBS work packages to Cost Estimate lines.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 24),
              // Cost Estimate Summary card
              _buildCostEstimateSummaryCard(
                context: context,
                totalCost: totalCost,
                currency: currency,
                linkedCount: linkedLines.length,
                unlinkedCount: unlinkedLines.length,
                linkedTotal: linkedTotal,
                unlinkedTotal: unlinkedTotal,
                nodeLinkedTotals: nodeLinkedTotals,
                unlinkedLines: unlinkedLines,
                hasEstimate: estimate != null,
              ),
              const SizedBox(height: 16),
              // WBS Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: LightModeColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_open,
                          color: LightModeColors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(wbs.projectName,
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '${wbs.framework.label} · ${counts.level1} ${wbs.framework.level1Label} · ${counts.level2} ${wbs.framework.level2Label}',
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Text(
                          '${counts.level1 + counts.level2 + counts.level3 + counts.level4 + counts.level5 + counts.level6 + counts.level7 + counts.level8 + 1} nodes',
                          style: const TextStyle(
                              color: Color(0xFF495057),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Export buttons
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _copyToClipboard(context, json, 'JSON'),
                    icon: const Icon(Icons.data_object, size: 16),
                    label: const Text('Copy JSON'),
                    style: FilledButton.styleFrom(
                      backgroundColor: LightModeColors.accent,
                      foregroundColor: LightModeColors.lightOnPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context, ascii, 'ASCII'),
                    icon: const Icon(Icons.account_tree, size: 16),
                    label: const Text('Copy ASCII tree'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1D1F),
                      side: const BorderSide(color: Color(0xFFE4E7EC)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ASCII preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.preview, size: 14, color: Color(0xFF6B7280)),
                        SizedBox(width: 6),
                        Text('ASCII TREE PREVIEW',
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      ascii,
                      style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Cost Estimate link section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link,
                            size: 16, color: LightModeColors.accent),
                        SizedBox(width: 8),
                        Text('Link to Cost Estimate',
                            style: TextStyle(
                                color: Color(0xFF1A1D1F),
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Each Level 2 work package can be linked to one or more Cost Estimate line items. Open the Cost Estimate module from the sidebar to map WBS nodes to cost lines, or use the AI Generator to suggest a baseline breakdown.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _linkStatChip(
                          'Work packages',
                          '${counts.level2}',
                          Icons.inventory_2_outlined,
                        ),
                        _linkStatChip(
                          'Linked cost lines',
                          '${_countLinkedCostLines(wbs)}',
                          Icons.link,
                        ),
                        _linkStatChip(
                          'AI-generated nodes',
                          '${_countAiNodes(wbs)}',
                          Icons.auto_awesome,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Danger zone — reset
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFECACA).withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Color(0xFFB91C1C), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Reset WBS — permanently removes the current WBS and returns to setup. This cannot be undone.',
                        style:
                            TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _confirmReset(context, provider),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _linkStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1A1D1F),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Effective contribution of a cost line to the estimate total — accounts
  /// for variance flags (added / removed / changed) so the summary stays
  /// consistent with [ComputeUtils.computeTotals].
  double _effectiveLineTotal(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  /// "Cost Estimate Summary" card — surfaces the cross-module context so the
  /// WBS Export & Link tab clearly shows:
  ///   - Total estimated cost across all cost lines
  ///   - Number of cost lines linked vs unlinked to WBS nodes
  ///   - Per-WBS-node linked totals
  ///   - Warning for cost lines missing a WBS reference
  Widget _buildCostEstimateSummaryCard({
    required BuildContext context,
    required double totalCost,
    required String currency,
    required int linkedCount,
    required int unlinkedCount,
    required double linkedTotal,
    required double unlinkedTotal,
    required List<MapEntry<WBSNode, double>> nodeLinkedTotals,
    required List<CostLine> unlinkedLines,
    required bool hasEstimate,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_money,
                    color: LightModeColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cost Estimate Summary',
                        style: TextStyle(
                            color: Color(0xFF1A1D1F),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      'Total estimated cost and WBS↔Cost-Line linkage status.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  hasEstimate
                      ? 'Total: ${formatCurrency(totalCost, currency)}'
                      : 'No estimate yet',
                  style: TextStyle(
                    color: LightModeColors.accent.withValues(alpha: 1),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasEstimate) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No Cost Estimate has been set up yet. Open the Cost Estimate module from the sidebar to start adding cost lines and link them to WBS nodes here.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Linked vs unlinked count row
            Row(
              children: [
                Expanded(
                  child: _summaryStatTile(
                    label: 'Linked to WBS',
                    value: '$linkedCount line${linkedCount == 1 ? '' : 's'}',
                    sub: formatCurrency(linkedTotal, currency),
                    color: const Color(0xFF16A34A),
                    icon: Icons.link,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryStatTile(
                    label: 'Unlinked',
                    value:
                        '$unlinkedCount line${unlinkedCount == 1 ? '' : 's'}',
                    sub: formatCurrency(unlinkedTotal, currency),
                    color: unlinkedCount > 0
                        ? const Color(0xFFB45309)
                        : const Color(0xFF6B7280),
                    icon: Icons.link_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Per-node linked totals
            if (nodeLinkedTotals.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.7)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No cost lines are linked to WBS nodes yet. Open the Cost Estimate module and pick a WBS node from the WBS Reference dropdown on each cost line.',
                        style:
                            TextStyle(color: Color(0xFF92400E), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const Text('WBS NODES WITH LINKED COST TOTALS',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ...nodeLinkedTotals.map((entry) {
                final node = entry.key;
                final sum = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(node.code,
                            style: const TextStyle(
                                color: Color(0xFF495057),
                                fontSize: 11,
                                fontFamily: appFontFamily,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(node.name,
                            style: const TextStyle(
                                color: Color(0xFF1A1D1F),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(formatCurrency(sum, currency),
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
            ],
            // Warning for cost lines missing a WBS reference
            if (unlinkedLines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFECACA).withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 14, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 8),
                        const Text('Cost lines missing a WBS reference',
                            style: TextStyle(
                                color: Color(0xFF7F1D1D),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${unlinkedLines.length}',
                            style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...unlinkedLines.take(5).map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFFECACA),
                                      width: 0.5),
                                ),
                                child: Text(l.category.label,
                                    style: const TextStyle(
                                        color: Color(0xFFB91C1C),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.description.isEmpty
                                      ? '(no description)'
                                      : l.description,
                                  style: const TextStyle(
                                      color: Color(0xFF7F1D1D), fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                  formatCurrency(
                                      _effectiveLineTotal(l), currency),
                                  style: const TextStyle(
                                      color: Color(0xFF7F1D1D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    if (unlinkedLines.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${unlinkedLines.length - 5} more unlinked line(s)',
                          style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 11,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summaryStatTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(sub,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('WBS $label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmReset(BuildContext context, WBSProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset WBS?'),
        content: const Text(
            'This permanently removes the current WBS and returns to setup. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.resetWBS();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ---- helpers ----

  Map<String, dynamic> _nodeToJson(WBSNode node) {
    return {
      'id': node.id,
      'level': node.level.name,
      'code': node.code,
      'name': node.name,
      if (node.description != null) 'description': node.description,
      if (node.aiGenerated) 'aiGenerated': true,
      if (node.costLineIds != null && node.costLineIds!.isNotEmpty)
        'costLineIds': node.costLineIds,
      'children': node.children.map(_nodeToJson).toList(),
    };
  }

  String _toAsciiTree(WBSNode root) {
    final buf = StringBuffer();
    buf.writeln('${root.code}  ${root.name}');
    _writeAsciiChildren(buf, root.children, '');
    return buf.toString();
  }

  void _writeAsciiChildren(
      StringBuffer buf, List<WBSNode> children, String prefix) {
    for (var i = 0; i < children.length; i++) {
      final isLast = i == children.length - 1;
      final node = children[i];
      buf.writeln(
          '$prefix${isLast ? '└── ' : '├── '}${node.code}  ${node.name}');
      _writeAsciiChildren(
          buf, node.children, '$prefix${isLast ? '    ' : '│   '}');
    }
  }

  int _countLinkedCostLines(WBS wbs) {
    int count(WBSNode n) {
      final own = n.costLineIds?.length ?? 0;
      return own + n.children.fold(0, (s, c) => s + count(c));
    }

    return count(wbs.level0);
  }

  int _countAiNodes(WBS wbs) {
    int count(WBSNode n) {
      final own = n.aiGenerated ? 1 : 0;
      return own + n.children.fold(0, (s, c) => s + count(c));
    }

    return count(wbs.level0);
  }
}
