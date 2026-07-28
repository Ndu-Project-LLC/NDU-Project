library;

/// Cost by WBS Tab — world-class dashboard showing costs per WBS level.
/// Used by both the WBS Module and Cost Estimate Module screens.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class CostByWBSTab extends StatelessWidget {
  const CostByWBSTab({super.key});

  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;
    if (wbs == null) {
      return const Center(
        child: Text(
          'No WBS data available. Set up the WBS first.',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
      );
    }

    final ceProvider = context.read<CostEstimateProvider>();
    final estimate = ceProvider.estimate;
    final currencySymbol = UserPreferencesService.currencySymbolSync;
    final allLines = estimate?.lines ?? [];

    // Match cost lines to WBS nodes by wbsRef
    final l1Nodes = wbs.level0.children;
    final l2Nodes = <WBSNode>[];
    for (final l1 in l1Nodes) {
      l2Nodes.addAll(l1.children);
    }

    // Calculate cost per L1 node (including children's costs)
    Map<String, double> l1Costs = {};
    Map<String, List<CostLine>> l1Lines = {};
    Map<String, double> l2Costs = {};
    Map<String, List<CostLine>> l2Lines = {};
    double unlinkedTotal = 0;
    List<CostLine> unlinkedLines = [];

    for (final line in allLines) {
      final ref = line.wbsRef?.trim() ?? '';
      bool matched = false;

      // Try matching to L1 nodes
      for (final l1 in l1Nodes) {
        if (ref == l1.code || ref == l1.id || ref == l1.name) {
          l1Costs[l1.id] = (l1Costs[l1.id] ?? 0) + line.total;
          l1Lines.putIfAbsent(l1.id, () => []).add(line);
          matched = true;
          break;
        }
        // Try matching to L2 nodes (adds to parent L1)
        for (final l2 in l1.children) {
          if (ref == l2.code || ref == l2.id || ref == l2.name) {
            l2Costs[l2.id] = (l2Costs[l2.id] ?? 0) + line.total;
            l2Lines.putIfAbsent(l2.id, () => []).add(line);
            l1Costs[l1.id] = (l1Costs[l1.id] ?? 0) + line.total;
            l1Lines.putIfAbsent(l1.id, () => []).add(line);
            matched = true;
            break;
          }
        }
        if (matched) break;
      }

      if (!matched) {
        unlinkedTotal += line.total;
        unlinkedLines.add(line);
      }
    }

    final totalLinked = l1Costs.values.fold(0.0, (a, b) => a + b);
    final totalAll = totalLinked + unlinkedTotal;
    final linkedPct = totalAll > 0 ? (totalLinked / totalAll * 100) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Cost by WBS Level',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          Text(
              '${allLines.length} cost lines · $currencySymbol${_fmt(totalAll)} total · ${linkedPct.toStringAsFixed(0)}% linked to WBS',
              style:
                  const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // KPI Cards
          Row(
            children: [
              Expanded(
                  child: _costKpi('Total Cost',
                      '$currencySymbol${_fmt(totalAll)}', Icons.account_balance_wallet_outlined, const Color(0xFF6366F1))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi('Linked',
                      '$currencySymbol${_fmt(totalLinked)}', Icons.link_outlined, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi('Unlinked',
                      '$currencySymbol${_fmt(unlinkedTotal)}', Icons.link_off_outlined, const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi('L1 Deliverables',
                      '${l1Nodes.length}', Icons.layers_outlined, const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 24),

          // Cost Distribution Bar Chart
          if (totalAll > 0) ...[
            _sectionCard(
              title: 'Cost Distribution by WBS Level',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          if (totalLinked > 0)
                            Expanded(
                              flex:
                                  (totalLinked / totalAll * 1000).round(),
                              child: Container(
                                color: const Color(0xFF10B981),
                                child: Center(
                                    child: Text(
                                        '${linkedPct.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold))),
                              ),
                            ),
                          if (unlinkedTotal > 0)
                            Expanded(
                              flex: (unlinkedTotal / totalAll * 1000)
                                  .round(),
                              child: Container(
                                color: const Color(0xFFEF4444),
                                child: const Center(
                                    child: Text('Unlinked',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _legendDot('Linked to WBS',
                          const Color(0xFF10B981),
                          '$currencySymbol${_fmt(totalLinked)}'),
                      const SizedBox(width: 24),
                      _legendDot('Unlinked',
                          const Color(0xFFEF4444),
                          '$currencySymbol${_fmt(unlinkedTotal)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Level 1 Deliverable Costs
          _sectionCard(
            title:
                'Level 1 — ${wbs.framework.level1Label} Costs',
            child: l1Nodes.isEmpty
                ? const Text(
                    'No Level 1 deliverables yet. Add them in the Builder tab.',
                    style: TextStyle(
                        color: _textSecondary, fontSize: 13))
                : Column(
                    children: l1Nodes.map((node) {
                      final cost =
                          (l1Costs[node.id] ?? 0).toDouble();
                      final lines = l1Lines[node.id] ?? [];
                      final pct = totalAll > 0
                          ? (cost / totalAll * 100)
                          : 0.0;
                      final maxCost = l1Costs.values.fold(
                          0.0, (a, b) => a > b ? a : b);
                      final barPct =
                          maxCost > 0 ? (cost / maxCost) : 0.0;
                      return _wbsCostRow(
                        code: node.code,
                        name: node.name,
                        description: node.description ?? "",
                        cost: cost,
                        currencySymbol: currencySymbol,
                        lineCount: lines.length,
                        pct: pct,
                        barPct: barPct,
                        color: const Color(0xFF6366F1),
                        children: node.children.map((l2) {
                          final l2Cost =
                              (l2Costs[l2.id] ?? 0).toDouble();
                          final l2LinesList = l2Lines[l2.id] ?? [];
                          return _wbsCostRow(
                            code: l2.code,
                            name: l2.name,
                            description: l2.description ?? "",
                            cost: l2Cost,
                            currencySymbol: currencySymbol,
                            lineCount: l2LinesList.length,
                            pct: totalAll > 0
                                ? (l2Cost / totalAll * 100)
                                : 0.0,
                            barPct: cost > 0 ? (l2Cost / cost) : 0,
                            color: const Color(0xFF8B5CF6),
                            isChild: true,
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // Unlinked Cost Lines
          if (unlinkedLines.isNotEmpty) ...[
            _sectionCard(
              title: 'Unlinked Cost Lines (${unlinkedLines.length})',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'These cost lines have no WBS reference. Link them in the Cost Estimate Builder for full traceability.',
                              style: TextStyle(
                                  color: const Color(0xFF92400E),
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unlinkedLines.map((line) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    line.description.isNotEmpty
                                        ? line.description
                                        : line.subCategory,
                                    style: const TextStyle(
                                        color: _textPrimary,
                                        fontSize: 12),
                                    overflow:
                                        TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('${line.category.label}',
                                style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 10)),
                            const SizedBox(width: 8),
                            Text(
                                '$currencySymbol${line.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      LightModeColors.accent
                          .withValues(alpha: 0.12),
                      LightModeColors.accent
                          .withValues(alpha: 0.04)
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: LightModeColors.accent
                            .withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: LightModeColors.accent
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(6)),
                            child: const Icon(Icons.layers,
                                color: LightModeColors.accent,
                                size: 16)),
                        const SizedBox(width: 8),
                        const Text('WBS-Linked Total',
                            style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          '$currencySymbol${_fmt(totalLinked)}',
                          style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: 4),
                      Text('${linkedPct.toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1D1F),
                      borderRadius:
                          BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('GRAND TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Text(
                          '$currencySymbol${_fmt(totalAll)}',
                          style: TextStyle(
                              color: LightModeColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: 4),
                      Text('${allLines.length} cost lines',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _costKpi(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [
                      FontFeature.tabularFigures()
                    ])),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(
      String label, Color color, String value) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: _textSecondary, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _wbsCostRow({
    required String code,
    required String name,
    required String description,
    required double cost,
    required String currencySymbol,
    required int lineCount,
    required double pct,
    required double barPct,
    required Color color,
    bool isChild = false,
    List<Widget> children = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(4)),
                child: Text(code,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: isChild ? 12 : 13,
                            fontWeight:
                                FontWeight.w600),
                        overflow:
                            TextOverflow.ellipsis),
                    if (description.isNotEmpty)
                      Text(description,
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10),
                          overflow:
                              TextOverflow.ellipsis,
                          maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (lineCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius:
                          BorderRadius.circular(4)),
                  child: Text('$lineCount',
                      style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 8),
              Text(
                  '$currencySymbol${_fmt(cost)}',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: isChild ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ])),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w500),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: barPct.clamp(0.0, 1.0),
              minHeight: isChild ? 3 : 5,
              backgroundColor:
                  const Color(0xFFF3F4F6),
              valueColor:
                  AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  left: 24, top: 4),
              child:
                  Column(children: children),
            ),
        ],
      ),
    );
  }

  static String _fmt(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(
        value == value.roundToDouble() ? 0 : 2);
  }
}
