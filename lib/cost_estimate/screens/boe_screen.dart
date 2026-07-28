library;

/// BOE Screen — Basis of Estimate.
///
/// Documents: scope basis, assumptions, constraints, exclusions, data sources,
/// methodology, accuracy range (auto from class), escalation assumptions.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

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
      assumptions:
          _assumptionCtrls.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.description, color: LightModeColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Basis of Estimate',
                style: TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Documents the assumptions, constraints, exclusions, data sources, and methodology behind every number in this estimate.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 24),
          // Accuracy range (auto from class)
          _buildCard(
            title: 'Accuracy Range',
            child: Row(
              children: [
                const Text('Estimate class: ',
                    style: TextStyle(color: Color(0xFF495057), fontSize: 13)),
                Text(
                  '${classMeta.label} — ${classMeta.name}',
                  style: const TextStyle(
                      color: LightModeColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text('Accuracy: ',
                    style: TextStyle(color: Color(0xFF495057), fontSize: 13)),
                Text(
                  '${classMeta.accuracy.low >= 0 ? "+" : ""}${classMeta.accuracy.low}% / +${classMeta.accuracy.high}%',
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Scope basis
          _buildCard(
            title: 'Scope Basis',
            child: TextField(
              controller: _scopeBasisCtrl,
              maxLines: 4,
              enabled: canEdit,
              decoration: InputDecoration(
                hintText:
                    'Describe the deliverables, WBS elements, and backlog items included...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFE4E7EC))),
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide:
                        BorderSide(color: LightModeColors.accent, width: 1.6)),
                enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFE4E7EC))),
              ),
              style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          // Assumptions / Constraints / Exclusions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildListCard(
                      'Assumptions', _assumptionCtrls, canEdit)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildListCard(
                      'Constraints', _constraintCtrls, canEdit)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildListCard(
                      'Exclusions', _exclusionCtrls, canEdit)),
            ],
          ),
          const SizedBox(height: 16),
          // Methodology
          _buildCard(
            title: 'Estimation Methodology',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EstimationMethod.values.map((m) {
                final selected = _methodology.contains(m);
                return FilterChip(
                  label: Text(m.label),
                  selected: selected,
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
                  selectedColor:
                      LightModeColors.accent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected
                        ? LightModeColors.accent
                        : const Color(0xFF495057),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? LightModeColors.accent
                        : const Color(0xFFE4E7EC),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Escalation assumptions
          _buildCard(
            title: 'Escalation Assumptions',
            child: TextField(
              controller: _escalationCtrl,
              maxLines: 3,
              enabled: canEdit,
              decoration: InputDecoration(
                hintText:
                    'e.g. 3% annual labor escalation, 5% material escalation...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFE4E7EC))),
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide:
                        BorderSide(color: LightModeColors.accent, width: 1.6)),
                enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFFE4E7EC))),
              ),
              style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 24),
            Center(
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                child: const Text('Save BOE'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: LightModeColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildListCard(
      String title, List<TextEditingController> ctrls, bool canEdit) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: LightModeColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...ctrls.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: c,
                  enabled: canEdit,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Color(0xFFE4E7EC))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: LightModeColors.accent, width: 1.6)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Color(0xFFE4E7EC))),
                  ),
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F), fontSize: 13),
                ),
              )),
          if (canEdit)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  ctrls.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, size: 14),
              label: Text('Add ${title.toLowerCase().replaceAll('s', '')}'),
              style: TextButton.styleFrom(
                  foregroundColor: LightModeColors.accent),
            ),
        ],
      ),
    );
  }
}
