library;

/// BOE Screen — Basis of Estimate (Treasury-treated).
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient.
///
/// Documents: scope basis, assumptions, constraints, exclusions, data sources,
/// methodology, accuracy range (auto from class), escalation assumptions.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class BOEScreen extends StatefulWidget {
  const BOEScreen({super.key});

  @override
  State<BOEScreen> createState() => _BOEScreenState();
}

class _BOEScreenState extends State<BOEScreen> {
  late TextEditingController _scopeBasisCtrl;
  late TextEditingController _escalationCtrl;
  final List<TextEditingController> _assumptionCtrls = [];
  final List<TextEditingController> _constraintCtrls = [];
  final List<TextEditingController> _exclusionCtrls = [];
  List<EstimationMethod> _methodology = [];

  @override
  void initState() {
    super.initState();
    final boe = context.read<CostEstimateProvider>().estimate!.boe;
    _scopeBasisCtrl = TextEditingController(text: boe.scopeBasis);
    _escalationCtrl = TextEditingController(text: boe.escalationAssumptions);
    for (final a in boe.assumptions) {
      _assumptionCtrls.add(TextEditingController(text: a));
    }
    for (final c in boe.constraints) {
      _constraintCtrls.add(TextEditingController(text: c));
    }
    for (final e in boe.exclusions) {
      _exclusionCtrls.add(TextEditingController(text: e));
    }
    _methodology = List.from(boe.methodology);
  }

  @override
  void dispose() {
    _scopeBasisCtrl.dispose();
    _escalationCtrl.dispose();
    for (final c in _assumptionCtrls) {
      c.dispose();
    }
    for (final c in _constraintCtrls) {
      c.dispose();
    }
    for (final c in _exclusionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final provider = context.read<CostEstimateProvider>();
    final boe = provider.estimate!.boe;
    provider.updateBOE(boe.copyWith(
      scopeBasis: _scopeBasisCtrl.text,
      assumptions: _assumptionCtrls
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList(),
      constraints: _constraintCtrls
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList(),
      exclusions: _exclusionCtrls
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList(),
      methodology: _methodology,
      escalationAssumptions: _escalationCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final estimate = context.watch<CostEstimateProvider>().estimate!;
    final classMeta = estimate.className;
    final canEdit = estimate.status == EstimateStatus.draft;
    final currencySymbol = UserPreferencesService.currencySymbolSync;

    final assumptionCount =
        _assumptionCtrls.where((c) => c.text.isNotEmpty).length;
    final constraintCount =
        _constraintCtrls.where((c) => c.text.isNotEmpty).length;
    final exclusionCount =
        _exclusionCtrls.where((c) => c.text.isNotEmpty).length;
    final methodologyCount = _methodology.length;

    return Container(
      color: TreasuryTokens.canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero command band ─────────────────────────────────
            TreasuryHeroBand(
              eyebrow: 'COST ESTIMATE · BOE',
              title: 'Basis of Estimate',
              subtitle:
                  'Documents the assumptions, constraints, exclusions, data sources, and methodology behind every number in this estimate.',
              statusLabel: canEdit
                  ? 'Draft — open for edits'
                  : 'Locked (no longer editable)',
              statusLive: !canEdit,
              contextChips: [
                TreasuryHeroChip(
                  icon: Icons.flag_outlined,
                  label: 'Project',
                  value: estimate.projectName,
                ),
                TreasuryHeroChip(
                  icon: Icons.class_outlined,
                  label: 'Class',
                  value: classMeta.label,
                ),
                TreasuryHeroChip(
                  icon: Icons.payments_outlined,
                  label: 'Baseline',
                  value:
                      '$currencySymbol${treasuryFmt(estimate.totals.costBaseline)}',
                ),
              ],
              actions: [
                if (canEdit)
                  TreasuryHeroAction(
                    icon: Icons.save_rounded,
                    label: 'Save BOE',
                    primary: true,
                    onTap: _save,
                  ),
              ],
            ),
            const SizedBox(height: 22),

            // ── 2. Premium KPI strip ─────────────────────────────────
            TreasuryKpiStrip(
              kpis: [
                TreasuryKpiSpec(
                  label: 'Assumptions',
                  value: '$assumptionCount',
                  sub: 'Documented in BOE',
                  icon: Icons.lightbulb_outline_rounded,
                  tint: const Color(0xFFD97706),
                  tintSoft: const Color(0xFFFFF3E0),
                ),
                TreasuryKpiSpec(
                  label: 'Constraints',
                  value: '$constraintCount',
                  sub: 'Boundaries on the estimate',
                  icon: Icons.lock_outline_rounded,
                  tint: const Color(0xFFB8860B),
                  tintSoft: const Color(0xFFF4EEFF),
                ),
                TreasuryKpiSpec(
                  label: 'Exclusions',
                  value: '$exclusionCount',
                  sub: 'Out of scope items',
                  icon: Icons.block_rounded,
                  tint: const Color(0xFFD97706),
                  tintSoft: const Color(0xFFFFF8E1),
                ),
                TreasuryKpiSpec(
                  label: 'Methodology',
                  value: '$methodologyCount',
                  sub: 'Selected methods',
                  icon: Icons.science_outlined,
                  tint: const Color(0xFF10B981),
                  tintSoft: const Color(0xFFE7F8F0),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── 3. Accuracy range (auto from class) ─────────────────
            TreasurySectionCard(
              title: 'Accuracy Range',
              subtitle: 'Auto-derived from the estimate class',
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 600;
                  return Flex(
                    direction:
                        wide ? Axis.horizontal : Axis.vertical,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaTile(
                        icon: Icons.class_outlined,
                        label: 'ESTIMATE CLASS',
                        value: '${classMeta.label} — ${classMeta.name}',
                        tint: TreasuryTokens.brandDeep,
                        tintSoft: TreasuryTokens.brandSoft,
                      ),
                      if (wide) const SizedBox(width: 16) else const SizedBox(height: 12),
                      _MetaTile(
                        icon: Icons.timeline_rounded,
                        label: 'ACCURACY RANGE',
                        value:
                            '${classMeta.accuracy.low >= 0 ? "+" : ""}${classMeta.accuracy.low}% / +${classMeta.accuracy.high}%',
                        tint: const Color(0xFF10B981),
                        tintSoft: const Color(0xFFE7F8F0),
                      ),
                      if (wide) const SizedBox(width: 16) else const SizedBox(height: 12),
                      _MetaTile(
                        icon: Icons.delivery_dining_outlined,
                        label: 'DELIVERY MODEL',
                        value: estimate.deliveryModel.label,
                        tint: const Color(0xFFB8860B),
                        tintSoft: const Color(0xFFEEF0FF),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Scope basis ──────────────────────────────────────
            TreasurySectionCard(
              title: 'Scope Basis',
              subtitle: 'What is included in this estimate',
              child: _TreasuryTextField(
                controller: _scopeBasisCtrl,
                enabled: canEdit,
                minLines: 4,
                hint:
                    'Describe the deliverables, WBS elements, and backlog items included...',
              ),
            ),
            const SizedBox(height: 16),

            // ── 5. Assumptions / Constraints / Exclusions ──────────
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                  Widget assumptions = _ListCard(
                  title: 'Assumptions',
                  icon: Icons.lightbulb_outline_rounded,
                  tint: TreasuryTokens.brandDeep,
                  tintSoft: TreasuryTokens.brandSoft,
                  ctrls: _assumptionCtrls,
                  canEdit: canEdit,
                  suffixSingular: 'assumption',
                  hint: 'State an assumption...',
                  onAdd: () => setState(() {
                        final defaultText = '${estimate.projectName} — Assumption: Based on ${estimate.className.label} accuracy range.';
                        _assumptionCtrls.add(TextEditingController(text: defaultText));
                      }),
                );
                Widget constraints = _ListCard(
                  title: 'Constraints',
                  icon: Icons.lock_outline_rounded,
                  tint: const Color(0xFFB8860B),
                  tintSoft: const Color(0xFFF4EEFF),
                  ctrls: _constraintCtrls,
                  canEdit: canEdit,
                  suffixSingular: 'constraint',
                  hint: 'State a constraint...',
                  onAdd: () => setState(() {
                        final defaultText = '${estimate.projectName} — Constraint: Funding, approvals, or access may limit delivery.';
                        _constraintCtrls.add(TextEditingController(text: defaultText));
                      }),
                );
                Widget exclusions = _ListCard(
                  title: 'Exclusions',
                  icon: Icons.block_rounded,
                  tint: const Color(0xFFD97706),
                  tintSoft: const Color(0xFFFFF8E1),
                  ctrls: _exclusionCtrls,
                  canEdit: canEdit,
                  suffixSingular: 'exclusion',
                  hint: 'State an exclusion...',
                  onAdd: () => setState(() {
                        final defaultText = '${estimate.projectName} — Exclusion: Operations, maintenance, and third-party warranties.';
                        _exclusionCtrls.add(TextEditingController(text: defaultText));
                      }),
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: assumptions),
                      const SizedBox(width: 14),
                      Expanded(child: constraints),
                      const SizedBox(width: 14),
                      Expanded(child: exclusions),
                    ],
                  );
                }
                return Column(
                  children: [
                    assumptions,
                    const SizedBox(height: 14),
                    constraints,
                    const SizedBox(height: 14),
                    exclusions,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── 6. Methodology ──────────────────────────────────────
            TreasurySectionCard(
              title: 'Estimation Methodology',
              subtitle: 'Methods used to derive the cost figures',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EstimationMethod.values.map((m) {
                  final selected = _methodology.contains(m);
                  return _TreasuryFilterChip(
                    label: m.label,
                    selected: selected,
                    enabled: canEdit,
                    onSelected: canEdit
                        ? (s) {
                            setState(() {
                              if (s) {
                                _methodology.add(m);
                              } else {
                                _methodology.remove(m);
                              }
                            });
                          }
                        : null,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── 7. Escalation assumptions ──────────────────────────
            TreasurySectionCard(
              title: 'Escalation Assumptions',
              subtitle: 'Time-phased cost growth assumptions',
              child: _TreasuryTextField(
                controller: _escalationCtrl,
                enabled: canEdit,
                minLines: 3,
                hint:
                    'e.g. 3% annual labor escalation, 5% material escalation...',
              ),
            ),
            const SizedBox(height: 24),

            // ── 8. Save ────────────────────────────────────────────
            if (canEdit)
              Center(
                child: TreasuryPrimaryButton(
                  icon: Icons.save_rounded,
                  label: 'Save BOE',
                  onPressed: _save,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// META TILE — compact icon + label + value tile
// ═══════════════════════════════════════════════════════════════════════════

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.tintSoft,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color tintSoft;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tintSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tint.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tint.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, size: 15, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: TreasuryTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: TreasuryTokens.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LIST CARD — for Assumptions / Constraints / Exclusions
// ═══════════════════════════════════════════════════════════════════════════

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.tint,
    required this.tintSoft,
    required this.ctrls,
    required this.canEdit,
    required this.suffixSingular,
    required this.hint,
    required this.onAdd,
  });
  final String title;
  final IconData icon;
  final Color tint;
  final Color tintSoft;
  final List<TextEditingController> ctrls;
  final bool canEdit;
  final String suffixSingular;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return TreasurySectionCard(
      title: title,
      subtitle: '${ctrls.where((c) => c.text.isNotEmpty).length} entries',
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < ctrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TreasuryTextField(
                      controller: ctrls[i],
                      enabled: canEdit,
                      hint: hint,
                    ),
                  ),
                ],
              ),
            ),
          if (canEdit)
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 14, color: tint),
              label: Text('Add ${suffixSingular}',
                  style: TextStyle(
                    color: tint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY TEXT FIELD — hairline border, brand-deep focus
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryTextField extends StatelessWidget {
  const _TreasuryTextField({
    required this.controller,
    required this.enabled,
    this.minLines = 1,
    this.maxLines,
    this.hint,
  });
  final TextEditingController controller;
  final bool enabled;
  final int minLines;
  final int? maxLines;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines ?? null,
      style: const TextStyle(
        color: TreasuryTokens.ink,
        fontSize: 13.5,
        height: 1.45,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: TreasuryTokens.mutedSoft,
          fontSize: 13,
        ),
        filled: true,
        fillColor: TreasuryTokens.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TreasuryTokens.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: TreasuryTokens.brandDeep, width: 1.6),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TreasuryTokens.hairline),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TreasuryTokens.hairlineSoft),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY FILTER CHIP — for methodology selection
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryFilterChip extends StatelessWidget {
  const _TreasuryFilterChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? TreasuryTokens.brandSoft
          : (enabled ? Colors.white : TreasuryTokens.surfaceAlt),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled && onSelected != null
            ? () => onSelected!(!selected)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? TreasuryTokens.brand.withValues(alpha: 0.55)
                  : TreasuryTokens.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Icon(Icons.check_rounded,
                    size: 13, color: TreasuryTokens.brandDeep)
              else
                Icon(Icons.add_rounded,
                    size: 13, color: TreasuryTokens.mutedSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? TreasuryTokens.brandDeep
                      : TreasuryTokens.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
