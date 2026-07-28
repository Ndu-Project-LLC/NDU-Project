/// Framework Picker Screen — 3-step setup for a new WBS.
///
/// Step 1: Project name (Level 0 node)
/// Step 2: Project methodology (Waterfall, Agile, Hybrid)
/// Step 3: Framework selection (Agile + 5 Waterfall variations with ratings)
///
/// The methodology determines the default framework and the depth structure.
///
/// Rendered inside a [ResponsiveScaffold] so the standard app sidebar stays
/// visible during setup. Light-mode (white) theme.

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

class FrameworkPickerScreen extends StatefulWidget {
  const FrameworkPickerScreen({super.key});

  @override
  State<FrameworkPickerScreen> createState() => _FrameworkPickerScreenState();
}

class _FrameworkPickerScreenState extends State<FrameworkPickerScreen> {
  int _step = 0;
  ProjectMethodology? _methodology;
  WBSFramework? _framework;

  @override
  Widget build(BuildContext context) {
    final totalSteps = 2;
    return ResponsiveScaffold(
      activeItemLabel: 'Work Breakdown Structure',
      appBarTitle: 'Work Breakdown Structure',
      breadcrumbPhase: 'Planning Phase',
      breadcrumbTitle: 'WBS Setup',
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      color: LightModeColors.accent, size: 28),
                  const SizedBox(width: 8),
                  const Text('NDU ',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const Text('PROJECT',
                      style: TextStyle(
                          color: LightModeColors.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('WBS Setup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3)),
              const SizedBox(height: 32),
              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 24 : 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? LightModeColors.accent
                          : const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Step indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Step ${_step + 1} of $totalSteps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              // Step content
              Expanded(child: _buildStepContent()),
              // Footer nav
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    )
                  else
                    const SizedBox(width: 80),
                  FilledButton(
                    onPressed: _canProceed() ? _handleNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: LightModeColors.accent,
                      foregroundColor: LightModeColors.lightOnPrimary,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(_step == totalSteps - 1
                        ? 'Create WBS'
                        : 'Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _methodology != null;
      case 1:
        return _framework != null;
    }
    return false;
  }

  void _handleNext() {
    if (_step == 0 && _methodology != null) {
      // Auto-select the default framework based on methodology
      _framework ??= switch (_methodology!) {
        ProjectMethodology.agile => WBSFramework.agile,
        ProjectMethodology.waterfall => WBSFramework.waterfallDeliverable,
        ProjectMethodology.hybrid => WBSFramework.waterfallDeliverable,
      };
      setState(() => _step = 1);
    } else if (_step == 1 && _framework != null) {
      final projectData = ProjectDataHelper.getData(context);
      final resolvedProjectName =
          projectData.projectName.trim().isNotEmpty
              ? projectData.projectName.trim()
              : 'Untitled Project';
      context.read<WBSProvider>().setup(
            projectName: resolvedProjectName,
            framework: _framework!,
            methodology: _methodology!,
          );
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildMethodologyStep();
      case 1:
        return _buildFrameworkStep();
    }
    return const SizedBox();
  }

  // ── STEP 1: Methodology ────────────────────────────────────────────

  Widget _buildMethodologyStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Choose delivery methodology',
            style: TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'The methodology determines how your WBS is structured and decomposed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        const SizedBox(height: 32),
        Expanded(
          child: ListView(
            children: ProjectMethodology.values.map((m) {
              final selected = _methodology == m;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _methodology = m),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: selected
                            ? m.color.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? m.color
                              : const Color(0xFFE4E7EC),
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: selected ? 0.08 : 0.03),
                            blurRadius: selected ? 16 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon with colored circle
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? m.color.withValues(alpha: 0.15)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(m.icon,
                                color: selected ? m.color : const Color(0xFF6B7280),
                                size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(m.label,
                                        style: TextStyle(
                                            color: selected
                                                ? m.color
                                                : const Color(0xFF1A1D1F),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                    if (selected) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check_circle,
                                          color: m.color, size: 18),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  m.description,
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13,
                                      height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Methodology info banner
        if (_methodology != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _methodology!.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _methodology!.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(_methodology!.icon,
                    size: 16, color: _methodology!.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_methodology!.label} project: max depth 8 (drill down to hours-of-work level)',
                    style: TextStyle(
                        color: _methodology!.color.withValues(alpha: 0.9),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── STEP 2: Framework ──────────────────────────────────────────────

  Widget _buildFrameworkStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Pick a WBS framework',
                style: TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
            'The framework determines how your${_methodology != null ? ' ${_methodology!.label}' : ''} project is decomposed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: WBSFramework.values
                .where((f) =>
                    // For Agile methodology, only show Agile framework
                    _methodology == ProjectMethodology.agile
                        ? f == WBSFramework.agile
                        : true)
                .map((f) {
              final selected = _framework == f;
              final isPhase = f == WBSFramework.waterfallPhase;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _framework = f),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? LightModeColors.accent.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? LightModeColors.accent
                              : const Color(0xFFE4E7EC),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            f.iconData,
                            color: selected
                                ? LightModeColors.accent
                                : const Color(0xFF6B7280),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(f.label,
                                          style: const TextStyle(
                                              color: Color(0xFF1A1D1F),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '★' * f.rating +
                                          '☆' * (5 - f.rating),
                                      style: const TextStyle(
                                          color: LightModeColors.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    // Show depth badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'L0–L${f.maxDepth}',
                                        style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(f.description,
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('Best for: ${f.bestFor}',
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                                if (isPhase) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFB923C)
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFFB923C)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning_amber,
                                            size: 12,
                                            color: Color(0xFFFB923C)),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Least preferred — consider Deliverable-Based.',
                                            style: TextStyle(
                                                color: Color(0xFFFB923C),
                                                fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                color: LightModeColors.accent, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
