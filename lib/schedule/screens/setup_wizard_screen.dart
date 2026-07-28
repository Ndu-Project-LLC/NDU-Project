library;

/// Setup Wizard Screen — creates a new schedule.
///
/// 2-step setup:
///   Step 1: Project name (Level 0)
///   Step 2: Delivery model (Agile / Waterfall / Hybrid)
///
/// Rendered inside a [ResponsiveScaffold] so the standard app sidebar stays
/// visible during setup. Light-mode (white) theme — matches the rest of the
/// app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  String _projectName = '';
  String? _deliveryModel;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      activeItemLabel: 'Schedule',
      appBarTitle: 'Schedule',
      breadcrumbPhase: 'Planning Phase',
      breadcrumbTitle: 'Schedule Setup',
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today,
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
              const Text('Schedule Setup',
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
                children: List.generate(2, (i) {
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
              Text('Step ${_step + 1} of 2',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
              const SizedBox(height: 32),
              Expanded(child: _step == 0 ? _buildProjectNameStep() : _buildDeliveryModelStep()),
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
                    child: Text(_step == 1 ? 'Create schedule' : 'Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canProceed() =>
      _step == 0 ? _projectName.trim().isNotEmpty : _deliveryModel != null;

  void _handleNext() {
    if (_step < 1) {
      setState(() => _step++);
    } else {
      context.read<ScheduleProvider>().setup(
            projectName: _projectName.trim(),
            deliveryModel: _deliveryModel!,
          );
    }
  }

  Widget _buildProjectNameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Name your project',
            style: TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'This name will appear on the Level 0 root activity and on every schedule report, Gantt chart, and review communication.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 32),
        TextField(
          onChanged: (v) => setState(() => _projectName = v),
          decoration: InputDecoration(
            labelText: 'Project name (Level 0)',
            labelStyle:
                const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            hintText: 'e.g. NDU Manufacturing Facility',
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: LightModeColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can rename the project later from the Builder tab. The delivery model picked next controls the activity-type vocabulary and review gate flow.',
                  style: TextStyle(
                      color: const Color(0xFF6B7280), fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryModelStep() {
    final models = [
      ('AGILE', 'Agile', Icons.speed,
          'Epic → Feature → Story → Task. Sprint-based with rolling-wave planning.', 'Levels 0–5'),
      ('WATERFALL', 'Waterfall', Icons.water_drop,
          'WBS → EWP → Procurement → CWP → Activity → Task. CPM-based with up to 8 levels.', 'Levels 0–8'),
      ('HYBRID', 'Hybrid', Icons.merge,
          'Waterfall phases with Agile sprints within execution.', 'Levels 0–8'),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Pick delivery model',
            style: TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'This drives the activity decomposition vocabulary and the SME review stages.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 24),
        ...models.map((m) {
          final selected = _deliveryModel == m.$1;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _deliveryModel = m.$1),
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
                      Icon(m.$3,
                          color: selected
                              ? LightModeColors.accent
                              : const Color(0xFF6B7280),
                          size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(m.$2,
                                    style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE4E7EC)),
                                  ),
                                  child: Text(m.$5,
                                      style: const TextStyle(
                                          color: Color(0xFF495057),
                                          fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(m.$4,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 12)),
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
}
