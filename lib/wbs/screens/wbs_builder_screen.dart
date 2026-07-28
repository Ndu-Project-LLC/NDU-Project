/// WBS Builder Screen — recursive deep tree view with methodology-aware flow.
///
/// Supports arbitrary depth up to WBSFramework.maxDepth.
/// Each level gets its own label (e.g. "Deliverable", "Work Package", "Activity").
/// Methodology badges (Waterfall/Agile/Hybrid) on relevant nodes.
/// Templates, KAZ AI, linked cost lines, and full CRUD at any depth.
///
/// Rendered inside the parent [ResponsiveScaffold]'s TabBarView.

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/models/wbs_templates.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class WBSBuilderScreen extends StatefulWidget {
  const WBSBuilderScreen({super.key});

  @override
  State<WBSBuilderScreen> createState() => _WBSBuilderScreenState();
}

enum _SimpleAxis { topDown, leftRight }

class _TopDownConnectorBand extends StatelessWidget {
  const _TopDownConnectorBand({required this.childCount});

  final int childCount;

  @override
  Widget build(BuildContext context) {
    if (childCount <= 0) return const SizedBox.shrink();
    return CustomPaint(
      size: Size(144.0 * childCount, 28.0),
      painter: _TopDownConnectorPainter(childCount: childCount),
    );
  }
}

class _TopDownConnectorPainter extends CustomPainter {
  const _TopDownConnectorPainter({required this.childCount});

  final int childCount;

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = Color(0xFF64748B);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, 12), paint);
    if (childCount == 1) {
      canvas.drawLine(Offset(centerX, 12), Offset(centerX, size.height), paint);
      return;
    }
    const firstAnchor = 72.0;
    final lastX = size.width - 72.0;
    canvas.drawLine(Offset(firstAnchor, 12.0), Offset(lastX, 12.0), paint);
    for (int i = 0; i < childCount; i++) {
      final x = 72.0 + (144.0 * i);
      canvas.drawLine(Offset(x, 12.0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopDownConnectorPainter oldDelegate) {
    return oldDelegate.childCount != childCount;
  }
}

class _LeftRightConnectorBand extends StatelessWidget {
  const _LeftRightConnectorBand({required this.isFirst, required this.isLast});

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(48, 96),
      painter: _LeftRightConnectorPainter(isFirst: isFirst, isLast: isLast),
    );
  }
}

class _LeftRightConnectorPainter extends CustomPainter {
  const _LeftRightConnectorPainter(
      {required this.isFirst, required this.isLast});

  final bool isFirst;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = Color(0xFF64748B);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final spineX = size.width * 0.35;
    final midY = size.height / 2;

    if (!isFirst) {
      canvas.drawLine(Offset(spineX, 0), Offset(spineX, midY), paint);
    }
    canvas.drawLine(Offset(spineX, midY), Offset(size.width, midY), paint);
    if (!isLast) {
      canvas.drawLine(Offset(spineX, midY), Offset(spineX, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeftRightConnectorPainter oldDelegate) {
    return oldDelegate.isFirst != isFirst || oldDelegate.isLast != isLast;
  }
}

class _WBSBuilderScreenState extends State<WBSBuilderScreen> {
  final Set<String> _expanded = {};
  bool _kazAiLoading = false;
  _SimpleAxis _simpleAxis = _SimpleAxis.topDown;

  @override
  Widget build(BuildContext context) {
    return Consumer2<WBSProvider, CostEstimateProvider>(
      builder: (context, provider, costProvider, _) {
        final wbs = provider.wbs;
        if (wbs == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading Work Breakdown Structure...',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }
        final fm = wbs.framework;
        final counts = countNodes(wbs);
        final totalNodes = countAllNodes(wbs.level0);
        final treeDepthActual = treeDepth(wbs.level0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── World-class Header ──────────────────────────────────
              _buildHeader(context, provider, wbs, fm, counts, totalNodes,
                  treeDepthActual),
              const SizedBox(height: 24),
              // ── Tree View ───────────────────────────────────────────
              (provider.viewMode == WBSViewMode.advanced)
                  ? _buildAdvancedView(
                      context, provider, costProvider, wbs, fm, counts)
                  : (provider.viewMode == WBSViewMode.simple)
                      ? _buildSimpleView(context, provider, wbs, fm)
                      : _buildTableView(context, provider, wbs, fm),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // HEADER
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    WBSProvider provider,
    WBS wbs,
    WBSFramework fm,
    ({
      int level0,
      int level1,
      int level2,
      int level3,
      int level4,
      int level5,
      int level6,
      int level7,
      int level8
    }) counts,
    int totalNodes,
    int treeDepthActual,
  ) {
    // Build level summary
    final levelParts = <String>[];
    if (counts.level1 > 0) levelParts.add('${counts.level1} ${fm.level1Label}');
    if (counts.level2 > 0) levelParts.add('${counts.level2} ${fm.level2Label}');
    if (counts.level3 > 0) levelParts.add('${counts.level3} ${fm.level3Label}');
    if (counts.level4 > 0) levelParts.add('${counts.level4} ${fm.level4Label}');
    if (counts.level5 > 0) levelParts.add('${counts.level5} ${fm.level5Label}');
    if (counts.level6 > 0) levelParts.add('${counts.level6} ${fm.level6Label}');
    if (counts.level7 > 0) levelParts.add('${counts.level7} ${fm.level7Label}');
    if (counts.level8 > 0) levelParts.add('${counts.level8} ${fm.level8Label}');
    final summary = levelParts.join(' · ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon with methodology color
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: wbs.methodology.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(fm.iconData, color: wbs.methodology.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(wbs.projectName,
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        _buildMethodologyBadge(wbs.methodology),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.isNotEmpty
                          ? '${fm.label} · $summary · $totalNodes nodes total'
                          : '${fm.label} · $totalNodes nodes total',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              // Generate WBS button (prominent)
              _kazAiLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          _generateWithKazAi(context, provider, wbs),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text('Generate ${fm.level1Label}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: const Color(0xFF1A1D1F),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
              const SizedBox(width: 8),
              if (WBSTemplates.templates[wbs.framework]!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showTemplatesDialog(
                      context, provider, wbs.framework, wbs.level0.id),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1D1F),
                    side: const BorderSide(color: Color(0xFFE4E7EC)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              // View mode toggle
              SegmentedButton<WBSViewMode>(
                segments: const [
                  ButtonSegment(
                      value: WBSViewMode.advanced,
                      label: Text('Advanced', style: TextStyle(fontSize: 12))),
                  ButtonSegment(
                      value: WBSViewMode.simple,
                      label: Text('Simple', style: TextStyle(fontSize: 12))),
                  ButtonSegment(
                      value: WBSViewMode.table,
                      label: Text('Table', style: TextStyle(fontSize: 12))),
                ],
                selected: {provider.viewMode},
                onSelectionChanged: (v) => provider.setViewMode(v.first),
                style: SegmentedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (provider.viewMode == WBSViewMode.simple ||
                  provider.viewMode == WBSViewMode.advanced) ...[
                const SizedBox(width: 8),
                SegmentedButton<_SimpleAxis>(
                  segments: const [
                    ButtonSegment(
                      value: _SimpleAxis.topDown,
                      icon: Icon(Icons.south, size: 14),
                      label: Text('Top Down', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: _SimpleAxis.leftRight,
                      icon: Icon(Icons.east, size: 14),
                      label: Text('Left Right', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_simpleAxis},
                  onSelectionChanged: (v) =>
                      setState(() => _simpleAxis = v.first),
                  style: SegmentedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  if (!_canAddLevel1(wbs)) {
                    _showLevel1CapMessage(context, wbs: wbs);
                    return;
                  }
                  _showAddNodeDialog(context, provider, 1, fm.level1Label,
                      parentId: wbs.level0.id);
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add ${fm.level1Label}'),
                style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // METHODOLOGY BADGE
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildMethodologyBadge(ProjectMethodology methodology) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: methodology.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: methodology.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(methodology.icon, size: 12, color: methodology.color),
          const SizedBox(width: 4),
          Text(
            methodology.label,
            style: TextStyle(
              color: methodology.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMethodologyBadge(
      String? methodology, WBSFramework framework) {
    if (methodology == null || methodology.isEmpty)
      return const SizedBox.shrink();
    final color = switch (methodology) {
      'agile' => const Color(0xFF7C3AED),
      'waterfall' => const Color(0xFFD97706),
      _ => const Color(0xFF059669),
    };
    final label = switch (methodology) {
      'agile' => 'AGILE',
      'waterfall' => 'WF',
      _ => 'HYB',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // SIMPLE VIEW (old-style flat tree)
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildSimpleView(
    BuildContext context,
    WBSProvider provider,
    WBS wbs,
    WBSFramework fm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSimpleLevelHint(fm),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _expanded
                  ..clear()
                  ..addAll(flattenWBS(wbs).map((n) => n.id));
              }),
              icon: const Icon(Icons.unfold_more, size: 16),
              label: const Text('Expand All'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _expanded.clear()),
              icon: const Icon(Icons.unfold_less, size: 16),
              label: const Text('Collapse All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE4E7EC)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: _simpleAxis == _SimpleAxis.topDown
                  ? _buildTopDownDiagram(context, provider, wbs.level0, fm,
                      isRoot: true)
                  : _buildLeftRightDiagram(context, provider, wbs.level0, fm,
                      isRoot: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopDownDiagram(
    BuildContext context,
    WBSProvider provider,
    WBSNode node,
    WBSFramework fm, {
    bool isRoot = false,
  }) {
    final isExpanded = _expanded.contains(node.id) || isRoot;
    final children = node.children;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDiagramNodeCard(
          context,
          provider,
          node,
          fm,
          isRoot: isRoot,
          isExpanded: isExpanded,
        ),
        if (isRoot && children.isEmpty)
          _buildSimpleEmptyState(context, provider, fm),
        if (children.isNotEmpty && (isExpanded || isRoot)) ...[
          const SizedBox(height: 10),
          _TopDownConnectorBand(childCount: children.length),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((child) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildTopDownSubtree(context, provider, child, fm),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLeftRightDiagram(
    BuildContext context,
    WBSProvider provider,
    WBSNode node,
    WBSFramework fm, {
    bool isRoot = false,
  }) {
    final isExpanded = _expanded.contains(node.id) || isRoot;
    final children = node.children;
    final childTrees = children
        .map((child) => _buildLeftRightDiagram(context, provider, child, fm))
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDiagramNodeCard(
                context,
                provider,
                node,
                fm,
                isRoot: isRoot,
                isExpanded: isExpanded,
              ),
              if (isRoot && children.isEmpty) ...[
                const SizedBox(height: 16),
                _buildSimpleEmptyState(context, provider, fm),
              ],
            ],
          ),
        ),
        if (children.isNotEmpty && (isExpanded || isRoot)) ...[
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(children.length, (index) {
              final isFirst = index == 0;
              final isLast = index == children.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LeftRightConnectorBand(isFirst: isFirst, isLast: isLast),
                    const SizedBox(width: 12),
                    childTrees[index],
                  ],
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildTopDownSubtree(
    BuildContext context,
    WBSProvider provider,
    WBSNode node,
    WBSFramework fm,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 2, height: 16, color: const Color(0xFF64748B)),
        _buildTopDownDiagram(context, provider, node, fm),
      ],
    );
  }

  Widget _buildDiagramNodeCard(
    BuildContext context,
    WBSProvider provider,
    WBSNode node,
    WBSFramework fm, {
    bool isRoot = false,
    required bool isExpanded,
  }) {
    final level = node.level.value;
    final accent = isRoot
        ? LightModeColors.accent
        : levelColor(level, LightModeColors.accent);
    final hasChildren = node.children.isNotEmpty;
    final canAddChild = node.level.value < fm.maxDepth;
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            node.name.isEmpty
                ? (isRoot ? 'Project' : 'Untitled Node')
                : node.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isRoot ? 'PROJECT' : node.code,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: accent),
                ),
              ),
              if (hasChildren)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${node.children.length} child${node.children.length == 1 ? '' : 'ren'}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (hasChildren)
                _diagramIconAction(
                  icon: isExpanded ? Icons.expand_less : Icons.expand_more,
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(node.id);
                    } else {
                      _expanded.add(node.id);
                    }
                  }),
                ),
              if (canAddChild)
                _diagramIconAction(
                  icon: Icons.add,
                  tooltip: 'Add child',
                  onPressed: () => _showAddNodeDialog(
                    context,
                    provider,
                    node.level.value + 1,
                    fm.levelLabel(node.level.value + 1),
                    parentId: node.id,
                  ),
                ),
              if (!isRoot)
                _diagramIconAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: () =>
                      _showEditNodeDialog(context, provider, node, fm),
                ),
              if (!isRoot)
                _diagramIconAction(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  color: const Color(0xFFEF4444),
                  onPressed: () => provider.removeNode(node.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleLevelHint(WBSFramework fm) {
    return const SizedBox.shrink();
  }

  Widget _buildSimpleEmptyState(
      BuildContext context, WBSProvider provider, WBSFramework fm) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.layers, color: Color(0xFF9CA3AF), size: 32),
          const SizedBox(height: 8),
          Text('No ${fm.level1Label} nodes yet.',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  if (!_canAddLevel1(provider.wbs!)) {
                    _showLevel1CapMessage(context, wbs: provider.wbs);
                    return;
                  }
                  _showAddNodeDialog(context, provider, 1, fm.level1Label,
                      parentId: provider.wbs!.level0.id);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: LightModeColors.accent,
                    foregroundColor: LightModeColors.lightOnPrimary),
                child: Text('Add ${fm.level1Label}'),
              ),
              if (WBSTemplates.templates[provider.wbs!.framework]!.isNotEmpty)
                OutlinedButton(
                  onPressed: () => _showTemplatesDialog(context, provider,
                      provider.wbs!.framework, provider.wbs!.level0.id),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1D1F),
                      side: const BorderSide(color: Color(0xFFE4E7EC))),
                  child: const Text('Use template'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diagramIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = const Color(0xFF475569),
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // DIAGRAM CONNECTORS
  // ───────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────
  // ADVANCED VIEW (current deep recursive tree)
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildAdvancedView(
    BuildContext context,
    WBSProvider provider,
    CostEstimateProvider costProvider,
    WBS wbs,
    WBSFramework fm,
    ({
      int level0,
      int level1,
      int level2,
      int level3,
      int level4,
      int level5,
      int level6,
      int level7,
      int level8
    }) counts,
  ) {
    return _buildRecursiveTree(
        context, provider, costProvider, wbs.level0, fm, 0);
  }

  /// Flat table view showing all Level 1 and Level 2 nodes.
  Widget _buildTableView(
    BuildContext context,
    WBSProvider provider,
    WBS wbs,
    WBSFramework fm,
  ) {
    final children = wbs.level0.children;
    if (children.isEmpty) {
      return _buildEmptyState(context, provider, fm);
    }

    final allRows = <Map<String, dynamic>>[];
    for (final l1 in children) {
      allRows.add({
        'level': 'L1',
        'code': l1.code,
        'name': l1.name,
        'description': l1.description ?? '',
        'children': l1.children.length,
        'depth': 0,
      });
      for (final l2 in l1.children) {
        allRows.add({
          'level': 'L2',
          'code': l2.code,
          'name': l2.name,
          'description': l2.description ?? '',
          'children': l2.children.length,
          'depth': 1,
        });
      }
    }

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columnSpacing: 24,
            columns: [
              DataColumn(
                label: Text('Level',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ),
              DataColumn(
                label: Text('Code',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ),
              DataColumn(
                label: Text('Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ),
              DataColumn(
                label: Text('Description',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ),
              DataColumn(
                numeric: true,
                label: Text('Children',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ),
            ],
            rows: allRows.map((row) {
              final isL1 = row['level'] == 'L1';
              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>((_) {
                  if (isL1) return const Color(0xFFFFF8E1);
                  return null;
                }),
                cells: [
                  DataCell(Text(row['level'] as String,
                      style: TextStyle(
                        fontWeight: isL1 ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ))),
                  DataCell(Text(row['code'] as String,
                      style: TextStyle(
                        fontWeight: isL1 ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF1A1D1F),
                      ))),
                  DataCell(Text(row['name'] as String,
                      style: TextStyle(
                        fontWeight: isL1 ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF1A1D1F),
                      ))),
                  DataCell(Text(row['description'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ))),
                  DataCell(Text('${row['children']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────

  Widget _buildRecursiveTree(
    BuildContext context,
    WBSProvider provider,
    CostEstimateProvider costProvider,
    WBSNode node,
    WBSFramework fm,
    int depth,
  ) {
    if (depth == 0) {
      // Root (Level 0) node
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNodeCard(context, provider, costProvider, node, fm, depth,
              isRoot: true),
          if (node.children.isEmpty)
            _buildEmptyState(context, provider, fm)
          else
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 8),
              child: _buildChildrenList(context, provider, costProvider,
                  node.children, fm, depth + 1),
            ),
        ],
      );
    }

    return _buildChildrenList(
        context, provider, costProvider, node.children, fm, depth);
  }

  Widget _buildChildrenList(
    BuildContext context,
    WBSProvider provider,
    CostEstimateProvider costProvider,
    List<WBSNode> children,
    WBSFramework fm,
    int depth,
  ) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((entry) {
        final child = entry.value;
        final isLast = entry.key == children.length - 1;
        final isExpanded = _expanded.contains(child.id);
        final canExpand = child.children.isNotEmpty;
        final canAddChild = depth < fm.maxDepth;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Node row with optional expand toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expand/collapse toggle (always visible)
                  SizedBox(
                    width: 24,
                    child: IconButton(
                      icon: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: canExpand
                              ? const Color(0xFF6B7280)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expanded.remove(child.id);
                          } else {
                            _expanded.add(child.id);
                          }
                        });
                      },
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Tree branch connector
                  _TreeBranch(
                      isLast: isLast,
                      color: levelColor(depth, LightModeColors.accent)),
                  const SizedBox(width: 8),
                  // Node card
                  Expanded(
                    child: _buildNodeCard(
                        context, provider, costProvider, child, fm, depth),
                  ),
                ],
              ),
              // Children (when expanded)
              if (isExpanded && child.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: child.children.asMap().entries.map((grandEntry) {
                      final grand = grandEntry.value;
                      final isLastGrand =
                          grandEntry.key == child.children.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildRecursiveChild(context, provider,
                            costProvider, grand, fm, depth + 1,
                            isLast: isLastGrand),
                      );
                    }).toList(),
                  ),
                ),
              // Add child button (when expanded)
              if (isExpanded && canAddChild)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 2),
                  child: _buildAddChildButton(
                      context, provider, child, fm, depth + 1),
                ),
              // Linked cost lines panel
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: _buildLinkedCostLinesPanel(child, costProvider),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Recursively render a child node (with its own expand/collapse).
  Widget _buildRecursiveChild(
    BuildContext context,
    WBSProvider provider,
    CostEstimateProvider costProvider,
    WBSNode node,
    WBSFramework fm,
    int depth, {
    bool isLast = true,
  }) {
    final isExpanded = _expanded.contains(node.id);
    final canExpand = node.children.isNotEmpty;
    final canAddChild = depth < fm.maxDepth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: IconButton(
                icon: AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: canExpand
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expanded.remove(node.id);
                    } else {
                      _expanded.add(node.id);
                    }
                  });
                },
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
                iconSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            // Tree branch connector
            _TreeBranch(
                isLast: isLast,
                color: levelColor(depth, LightModeColors.accent)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNodeCard(
                  context, provider, costProvider, node, fm, depth),
            ),
          ],
        ),
        if (isExpanded && node.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children.asMap().entries.map((entry) {
                final c = entry.value;
                final isLastChild = entry.key == node.children.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildRecursiveChild(
                      context, provider, costProvider, c, fm, depth + 1,
                      isLast: isLastChild),
                );
              }).toList(),
            ),
          ),
        if (isExpanded && canAddChild)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 2),
            child: _buildAddChildButton(context, provider, node, fm, depth + 1),
          ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 4),
            child: _buildLinkedCostLinesPanel(node, costProvider),
          ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // NODE CARD
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildNodeCard(
    BuildContext context,
    WBSProvider provider,
    CostEstimateProvider costProvider,
    WBSNode node,
    WBSFramework fm,
    int depth, {
    bool isRoot = false,
  }) {
    final levelLabel = nodeLevelLabel(node, fm);
    final linkedLines = _linkedCostLinesFor(node, costProvider);
    final linkedCount = linkedLines.length;
    final methodology = node.methodology;
    final isHybrid = methodology != null && methodology.isNotEmpty;
    final childCount = node.children.length;
    final accentColor = isRoot
        ? LightModeColors.accent
        : levelColor(depth, LightModeColors.accent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isRoot
                ? accentColor.withValues(alpha: 0.3)
                : const Color(0xFFE4E7EC),
            width: isRoot ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isRoot
                ? accentColor.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isRoot ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: code badge + name + badges
          Row(
            children: [
              // Code badge (larger, more prominent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  isRoot ? 'ROOT' : node.code,
                  style: TextStyle(
                      color: accentColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontFamily: appFontFamily,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
              ),
              if (!isRoot) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    levelLabel.toUpperCase(),
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              // Name
              Flexible(
                child: Text(
                  node.name,
                  style: TextStyle(
                    color: const Color(0xFF1A1D1F),
                    fontSize: isRoot ? 16 : 14,
                    fontWeight: isRoot ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Badges row
              if (node.aiGenerated) ...[
                const SizedBox(width: 6),
                _buildBadge('AI', const Color(0xFFFBBF24), 8),
              ],
              if (node.isWorkPackage == true && !isRoot) ...[
                const SizedBox(width: 4),
                _buildBadge('WP', const Color(0xFF16A34A), 8),
              ],
              if (isHybrid) ...[
                const SizedBox(width: 4),
                _buildSmallMethodologyBadge(methodology, fm),
              ],
              if (linkedCount > 0) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message:
                      '$linkedCount cost line${linkedCount == 1 ? '' : 's'} linked',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                              const Color(0xFFD97706).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_money,
                            size: 10, color: Color(0xFFD97706)),
                        const SizedBox(width: 2),
                        Text('$linkedCount',
                            style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
              if (childCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_tree,
                          size: 10, color: Color(0xFF6B7280)),
                      const SizedBox(width: 3),
                      Text('$childCount',
                          style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Description
          if (node.description != null && node.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: accentColor.withValues(alpha: 0.2), width: 2),
                ),
              ),
              child: Text(
                node.description!,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // Bottom row: level label + estimation + actions
          const SizedBox(height: 10),
          Row(
            children: [
              // Level label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRoot
                      ? accentColor.withValues(alpha: 0.08)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isRoot
                          ? accentColor.withValues(alpha: 0.2)
                          : const Color(0xFFE4E7EC)),
                ),
                child: Text(
                  isRoot ? 'PROJECT ROOT' : levelLabel.toUpperCase(),
                  style: TextStyle(
                      color: isRoot
                          ? accentColor.withValues(alpha: 0.7)
                          : const Color(0xFF9CA3AF),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6),
                ),
              ),
              // Estimation method
              if (node.estimationMethod != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(node.estimationMethod!.icon,
                          size: 11, color: const Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text(node.estimationMethod!.label,
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Action buttons (larger, more touchable)
              _actionButton(
                icon: Icons.add_circle_outline,
                onPressed: () => _showAddNodeDialog(
                  context,
                  provider,
                  isRoot ? 1 : depth + 1,
                  fm.levelLabel(isRoot ? 1 : depth + 1),
                  parentId: node.id,
                ),
                tooltip: 'Add child',
                color:
                    levelColor(isRoot ? 1 : depth + 1, LightModeColors.accent),
              ),
              if (!isRoot) ...[
                const SizedBox(width: 2),
                _actionButton(
                  icon: Icons.arrow_upward,
                  onPressed: () => provider.moveNode(node.id, true),
                  tooltip: 'Move up',
                ),
                const SizedBox(width: 2),
                _actionButton(
                  icon: Icons.arrow_downward,
                  onPressed: () => provider.moveNode(node.id, false),
                  tooltip: 'Move down',
                ),
                const SizedBox(width: 2),
                _actionButton(
                  icon: Icons.edit_outlined,
                  onPressed: () =>
                      _showEditNodeDialog(context, provider, node, fm),
                  tooltip: 'Edit',
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 2),
                _actionButton(
                  icon: Icons.delete_outline,
                  onPressed: () => provider.removeNode(node.id),
                  tooltip: 'Delete',
                  color: const Color(0xFFEF4444),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: fontSize, fontWeight: FontWeight.w800)),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color color = const Color(0xFF6B7280),
  }) {
    final btn = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: btn);
    return btn;
  }

  // ───────────────────────────────────────────────────────────────────────
  // ADD CHILD BUTTON
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildAddChildButton(
    BuildContext context,
    WBSProvider provider,
    WBSNode parent,
    WBSFramework fm,
    int childDepth,
  ) {
    final label = fm.levelLabel(childDepth);
    return TextButton.icon(
      onPressed: () => _showAddNodeDialog(context, provider, childDepth, label,
          parentId: parent.id),
      icon: Icon(Icons.add_circle_outline,
          size: 14, color: levelColor(childDepth, LightModeColors.accent)),
      label: Text(
        'Add $label',
        style: TextStyle(
          fontSize: 11,
          color: levelColor(childDepth, LightModeColors.accent),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(
      BuildContext context, WBSProvider provider, WBSFramework fm) {
    return Container(
      margin: const EdgeInsets.only(left: 28, top: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.layers,
              color: Color(0xFF9CA3AF).withValues(alpha: 0.5), size: 40),
          const SizedBox(height: 12),
          Text(
            'No ${fm.level1Label} nodes yet.',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a ${fm.level1Label} manually or use templates to get started.',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  if (!_canAddLevel1(provider.wbs!)) {
                    _showLevel1CapMessage(context, wbs: provider.wbs);
                    return;
                  }
                  _showAddNodeDialog(context, provider, 1, fm.level1Label,
                      parentId: provider.wbs!.level0.id);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: LightModeColors.accent,
                    foregroundColor: LightModeColors.lightOnPrimary),
                child: Text('Add ${fm.level1Label}'),
              ),
              if (WBSTemplates.templates[provider.wbs!.framework]!.isNotEmpty)
                OutlinedButton(
                  onPressed: () => _showTemplatesDialog(context, provider,
                      provider.wbs!.framework, provider.wbs!.level0.id),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1D1F),
                      side: const BorderSide(color: Color(0xFFE4E7EC))),
                  child: const Text('Use template'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ───────────────────────────────────────────────────────────────────────

  void _showAddNodeDialog(
    BuildContext context,
    WBSProvider provider,
    int level,
    String levelLabel, {
    String? parentId,
  }) {
    if (level == 1 && provider.wbs != null && !_canAddLevel1(provider.wbs!)) {
      _showLevel1CapMessage(context, wbs: provider.wbs);
      return;
    }
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isHybrid = provider.wbs!.methodology == ProjectMethodology.hybrid;
    String? selectedMethodology;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline,
                color: LightModeColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Add Level $level — $levelLabel',
                style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 16)),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                      hintText: level <= 2
                          ? 'Use a deliverable noun (not an activity verb)'
                          : 'Describe the work package or activity',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: LightModeColors.accent),
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFF1A1D1F)),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  VoiceTextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: LightModeColors.accent),
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFF1A1D1F)),
                  ),
                  if (isHybrid && level == 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMethodology,
                      decoration: InputDecoration(
                        labelText: 'Methodology',
                        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'waterfall', child: Text('Waterfall')),
                        DropdownMenuItem(value: 'agile', child: Text('Agile')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedMethodology = v),
                      hint: const Text('Inherit from project'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id =
                  provider.addChildNode(parentId!, name, descCtrl.text.trim());
              if (isHybrid && selectedMethodology != null && id.isNotEmpty) {
                provider.setNodeMethodology(id, selectedMethodology);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary),
            child: Text('Add $levelLabel'),
          ),
        ],
      ),
    );
  }

  void _showEditNodeDialog(
    BuildContext context,
    WBSProvider provider,
    WBSNode node,
    WBSFramework fm,
  ) {
    final nameCtrl = TextEditingController(text: node.name);
    final descCtrl = TextEditingController(text: node.description ?? '');
    final levelLabel = nodeLevelLabel(node, fm);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_outlined, color: LightModeColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Edit $levelLabel',
                style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              const SizedBox(height: 12),
              VoiceTextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNode(
                  node.id,
                  node.copyWith(
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  ));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showTemplatesDialog(BuildContext context, WBSProvider provider,
      WBSFramework framework, String parentId) {
    final templates = WBSTemplates.templates[framework]!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: LightModeColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Framework templates',
                style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: templates.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: const TextStyle(
                                    color: Color(0xFF1A1D1F),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (t.description != null)
                              Text(t.description!,
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280), fontSize: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: t.children
                                  .map((c) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: const Color(0xFFE4E7EC)),
                                        ),
                                        child: Text(c.name,
                                            style: const TextStyle(
                                                color: Color(0xFF495057),
                                                fontSize: 10)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          final wbs = provider.wbs;
                          if (wbs != null && !_canAddLevel1(wbs)) {
                            Navigator.pop(ctx);
                            _showLevel1CapMessage(context, wbs: wbs);
                            return;
                          }
                          provider.addNodesFromTemplate(parentId, [t]);
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: LightModeColors.accent,
                            foregroundColor: LightModeColors.lightOnPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8)),
                        child:
                            const Text('Add', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  // ─── Level 1 cap ────────────────────────────────────────────────────

  bool _canAddLevel1(WBS wbs) {
    if (wbs.framework == WBSFramework.waterfallDiscipline &&
        wbs.methodology == ProjectMethodology.waterfall) {
      return true;
    }
    return wbs.level0.children.length < 3;
  }

  void _showLevel1CapMessage(BuildContext context, {WBS? wbs}) {
    final isDisciplineUnlimited = wbs != null &&
        wbs.framework == WBSFramework.waterfallDiscipline &&
        wbs.methodology == ProjectMethodology.waterfall;
    final message = isDisciplineUnlimited
        ? 'Discipline-based WBS allows more than 3 top-level items.'
        : 'Maximum 3 top-level WBS items — these become the 3 goals. Remove one to add another.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // KAZ AI GENERATION
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _generateWithKazAi(
      BuildContext context, WBSProvider provider, WBS wbs) async {
    setState(() => _kazAiLoading = true);
    try {
      final fm = wbs.framework;
      final existingNames = wbs.level0.children.map((n) => n.name).join(', ');
      final projectData = ProjectDataHelper.getData(context);
      final goals = projectData.projectGoals;
      final goalsContext = goals.isNotEmpty
          ? 'Project goals:\n${goals.map((g) => "- ${g.name}: ${g.description}").join("\n")}'
          : '';
      final planningGoals = projectData.planningGoals;
      final planningGoalsContext = planningGoals
              .any((g) => g.title.trim().isNotEmpty)
          ? 'Planning goals:\n${planningGoals.where((g) => g.title.trim().isNotEmpty).map((g) => "- ${g.title}: ${g.description}").join("\n")}'
          : '';
      final prompt = '''
You are a WBS (Work Breakdown Structure) expert. Generate 3-5 Level 1 ${fm.level1Label} nodes for a "${fm.label}" WBS.

Project: "${wbs.projectName}"
Framework: ${fm.label}
Level 1 label: ${fm.level1Label}
Level 2 label: ${fm.level2Label}
Level 3 label: ${fm.level3Label}
Existing nodes: ${existingNames.isEmpty ? '(none)' : existingNames}
Methodology: ${wbs.methodology.label}
${goalsContext}
${planningGoalsContext}

Output format: pipe-delimited list of node names, one per line.
Each line: NodeName|Level 1 description

Example:
Site Preparation|Site readiness and ground works
Building Structure|Structural envelope and shell

Guidelines:
- Use deliverable-based names (nouns not verbs)
- Be specific to the project context
- Align with the project goals listed above
- Suggest 3-5 nodes
- Use a pipe separator: name|description
''';

      final result = await OpenAiServiceSecure().generateCompletion(
        prompt,
        maxTokens: 600,
        temperature: 0.7,
      );

      if (!mounted) return;

      if (result.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('KAZ AI returned empty result'),
                backgroundColor: Color(0xFFEF4444)),
          );
        }
        return;
      }

      // Parse pipe-delimited output
      final lines = result
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.contains('|'))
          .toList();

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not parse KAZ AI output'),
                backgroundColor: Color(0xFFEF4444)),
          );
        }
        return;
      }

      int added = 0;
      final isDisciplineUnlimited =
          wbs.framework == WBSFramework.waterfallDiscipline &&
              wbs.methodology == ProjectMethodology.waterfall;
      final maxToAdd = isDisciplineUnlimited
          ? 5 - wbs.level0.children.length
          : 3 - wbs.level0.children.length;
      for (final line in lines.take(maxToAdd > 0 ? maxToAdd : 0)) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final desc = parts.sublist(1).join('|').trim();
          if (name.isNotEmpty) {
            provider.addChildNode(wbs.level0.id, name, desc);
            added++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KAZ AI added $added ${fm.level1Label} node(s)'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KAZ AI error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _kazAiLoading = false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // LINKED COST LINES
  // ───────────────────────────────────────────────────────────────────────

  List<CostLine> _linkedCostLinesFor(
      WBSNode node, CostEstimateProvider costProvider) {
    final estimate = costProvider.estimate;
    if (estimate == null) return const [];
    final allLines = estimate.lines;
    final lineIdSet = <String>{...(node.costLineIds ?? const [])};
    final matches = <CostLine>[];
    final seenIds = <String>{};
    for (final l in allLines) {
      final wbsRef = (l.wbsRef ?? '').trim();
      final matchesByPath = wbsRef.isNotEmpty && wbsRef == node.code;
      final matchesById = lineIdSet.contains(l.id);
      if ((matchesByPath || matchesById) && !seenIds.contains(l.id)) {
        matches.add(l);
        seenIds.add(l.id);
      }
    }
    return matches;
  }

  Widget _buildLinkedCostLinesPanel(
      WBSNode node, CostEstimateProvider costProvider) {
    final linked = _linkedCostLinesFor(node, costProvider);
    if (linked.isEmpty) return const SizedBox.shrink();
    final total = linked.fold<double>(0, (s, l) => s + l.total);
    final currency = costProvider.estimate?.currency ?? 'USD';
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.25), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 12, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              const Text('LINKED COST LINES',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text(
                '${linked.length} line${linked.length == 1 ? '' : 's'} · ${formatCurrency(total, currency)}',
                style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...linked.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE), width: 0.5),
                      ),
                      child: Text(
                        l.category.label,
                        style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.description.isEmpty
                            ? '(no description)'
                            : l.description,
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatCurrency(l.total, currency),
                      style: const TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Draws a tree-branch connector: ├ for middle children, └ for last child.
class _TreeBranch extends StatelessWidget {
  const _TreeBranch({required this.isLast, required this.color});
  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 40,
      child: CustomPaint(
        painter: _TreeBranchPainter(isLast: isLast, color: color),
      ),
    );
  }
}

class _TreeBranchPainter extends CustomPainter {
  _TreeBranchPainter({required this.isLast, required this.color});
  final bool isLast;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final h = size.height;
    final w = size.width;
    final midY = h / 2;

    // Horizontal line from left to right (branch to card)
    canvas.drawLine(Offset(0, midY), Offset(w, midY), paint);

    // Vertical line from top to mid (connecting from parent)
    if (isLast) {
      // Last child: line stops at the branch point
      canvas.drawLine(Offset(0, 0), Offset(0, midY), paint);
    } else {
      // Middle child: line continues below the branch
      canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
    }
  }

  @override
  bool shouldRepaint(_TreeBranchPainter old) =>
      old.isLast != isLast || old.color != color;
}
