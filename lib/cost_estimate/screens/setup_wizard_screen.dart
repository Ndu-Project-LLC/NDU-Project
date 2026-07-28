library;

/// Setup Wizard Screen — 3-step setup for a new cost estimate.
///
/// Step 1: Project name
/// Step 2: Delivery model (Waterfall / Agile / Hybrid)
/// Step 3: Estimate class (Class 5 → 1 with accuracy ranges)
///
/// Rendered inside a [ResponsiveScaffold] so the standard app sidebar stays
/// visible during setup. Light-mode (white) theme — matches the rest of the
/// app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  String _projectName = '';
  DeliveryModel? _deliveryModel;
  EstimateClass? _className;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      activeItemLabel: 'Cost Estimate',
      appBarTitle: 'Cost Estimate',
      breadcrumbPhase: 'Planning Phase',
      breadcrumbTitle: 'Cost Estimate Setup',
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up,
                      color: LightModeColors.accent, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'NDU ',
                    style: TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'PROJECT',
                    style: TextStyle(
                      color: LightModeColors.accent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Cost Estimate Setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 32),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
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
              const SizedBox(height: 8),
              Text(
                'Step ${_step + 1} of 3',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 32),

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
                    child: Text(_step == 2 ? 'Create estimate' : 'Continue'),
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
        return _projectName.trim().isNotEmpty;
      case 1:
        return _deliveryModel != null;
      case 2:
        return _className != null;
    }
    return false;
  }

  void _handleNext() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      // Finish
      context.read<CostEstimateProvider>().setup(
            projectName: _projectName.trim(),
            className: _className!,
            deliveryModel: _deliveryModel!,
          );
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildProjectNameStep();
      case 1:
        return _buildDeliveryModelStep();
      case 2:
        return _buildEstimateClassStep();
    }
    return const SizedBox();
  }

  Widget _buildProjectNameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Name your project',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This name will appear on the BOE, baseline reports, and all review communications.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 32),
        TextField(
          onChanged: (v) => setState(() => _projectName = v),
          decoration: InputDecoration(
            labelText: 'Project name',
            labelStyle:
                const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            hintText: 'e.g. NDU Product Launch',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: LightModeColors.accent, width: 1.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
          style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
          autofocus: true,
        ),
      ],
    );
  }

  Widget _buildDeliveryModelStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'How will you deliver?',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This drives the change-management process after baseline.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),
        ...DeliveryModel.values.map((m) {
          final selected = _deliveryModel == m;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _deliveryModel = m),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                        switch (m) {
                          DeliveryModel.waterfall => Icons.water_drop,
                          DeliveryModel.agile => Icons.speed,
                          DeliveryModel.hybrid => Icons.merge,
                        },
                        color: selected
                            ? LightModeColors.accent
                            : const Color(0xFF6B7280),
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.label,
                              style: const TextStyle(
                                color: Color(0xFF1A1D1F),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Changes: ${m.changeProcess}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            color: LightModeColors.accent, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEstimateClassStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Pick estimate maturity',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sets the expected accuracy range. You can refine as the project matures.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: EstimateClass.values.reversed.map((c) {
              final selected = _className == c;
              final acc = c.accuracy;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _className = c),
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
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: selected
                                  ? LightModeColors.accent
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFE4E7EC)),
                            ),
                            child: Center(
                              child: Text(
                                c.label.replaceAll('Class ', ''),
                                style: TextStyle(
                                  color: selected
                                      ? LightModeColors.lightOnPrimary
                                      : const Color(0xFF495057),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.label,
                                      style: const TextStyle(
                                        color: LightModeColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  c.desc,
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${acc.low >= 0 ? "+" : ""}${acc.low}% / +${acc.high}%',
                            style: const TextStyle(
                              color: Color(0xFF495057),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
      ],
    );
  }
}
