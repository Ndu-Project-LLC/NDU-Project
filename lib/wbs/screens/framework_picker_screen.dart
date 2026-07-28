/// Framework Picker Screen — 1-step setup for a new WBS.
///
/// Step 1: Framework selection (Agile + 5 Waterfall variations with ratings)
///
/// Methodology is auto-applied from the project's overall framework selection
/// in Project Details. The user only picks the WBS decomposition framework.
///
/// Rendered inside a [ResponsiveScaffold] so the standard app sidebar stays
/// visible during setup. Light-mode (white) theme.

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/review_confirmation_checkbox.dart';
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
  bool _wbsConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectData = ProjectDataHelper.getData(context);
      final mapped = ProjectDataHelper.projectMethodologyFromOverallFramework(
        projectData.overallFramework,
      );
      if (mapped != null && mounted) {
        setState(() {
          _methodology = mapped;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = 1;
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
              // Confirmation gate
              ReviewConfirmationCheckbox(
                value: _wbsConfirmed,
                onChanged: (value) => setState(() => _wbsConfirmed = value),
                padding: const EdgeInsets.only(bottom: 16),
                label:
                    'I confirm I have reviewed all information needs before the WBS section can be activated.',
              ),
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
                    onPressed: _canProceed()
                        ? _handleNext
                        : () {
                            if (_framework == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please select a WBS framework before proceeding.'),
                                  backgroundColor: Color(0xFFD97706),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else if (!_wbsConfirmed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please check the acknowledgment box above before proceeding.'),
                                  backgroundColor: Color(0xFFD97706),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
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
                    child: Text(
                        _step == totalSteps - 1 ? 'Create WBS' : 'Continue'),
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
    return _framework != null && _wbsConfirmed;
  }

  void _handleNext() {
    if (_framework == null) return;
    final resolvedMethodology = _methodology ?? ProjectMethodology.waterfall;
    final projectData = ProjectDataHelper.getData(context);
    final resolvedProjectName = projectData.projectName.trim().isNotEmpty
        ? projectData.projectName.trim()
        : 'Untitled Project';
    context.read<WBSProvider>().setup(
          projectName: resolvedProjectName,
          framework: _framework!,
          methodology: resolvedMethodology,
        );
    // Populate Level 1 nodes from project goals
    final goals = projectData.projectGoals;
    final hasGoals =
        goals.isNotEmpty && goals.any((g) => g.name.trim().isNotEmpty);
    final planGoals = projectData.planningGoals;
    final hasPlanGoals =
        planGoals.isNotEmpty && planGoals.any((g) => g.title.trim().isNotEmpty);

    if (hasGoals) {
      final wbsProvider = context.read<WBSProvider>();
      for (final goal in goals) {
        final name = goal.name.trim();
        if (name.isNotEmpty) {
          wbsProvider.addChildNode(
            wbsProvider.wbs!.level0.id,
            name,
            goal.description.trim(),
          );
        }
      }
    } else if (hasPlanGoals) {
      final wbsProvider = context.read<WBSProvider>();
      for (final goal in planGoals) {
        final name = goal.title.trim();
        if (name.isNotEmpty) {
          wbsProvider.addChildNode(
            wbsProvider.wbs!.level0.id,
            name,
            goal.description.trim(),
          );
        }
      }
    }
  }

  Widget _buildStepContent() {
    return _buildFrameworkStep();
  }

  // ── Framework Selection Step ────────────────────────────────────────

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
        const SizedBox(height: 12),
        if (_methodology != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _methodology!.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _methodology!.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_methodology!.icon, size: 14, color: _methodology!.color),
                const SizedBox(width: 6),
                Text(
                  'Methodology: ${_methodology!.label} (from Project Details)',
                  style: TextStyle(
                    color: _methodology!.color.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
                                      '★' * f.rating + '☆' * (5 - f.rating),
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
                                        borderRadius: BorderRadius.circular(6),
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
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFFB923C)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning_amber,
                                            size: 12, color: Color(0xFFFB923C)),
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
