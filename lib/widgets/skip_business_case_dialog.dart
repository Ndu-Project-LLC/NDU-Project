// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SkipBusinessCaseDialog
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// When the user already knows the solution and wants to skip the
// Business Case workflow (Potential Solutions, Risk Identification,
// Preferred Solution Analysis, etc.), this dialog re-opens the project
// description input so they can type, import (DOCX/PDF), or speak the
// core project details. That description then becomes the basis for
// the FEP documentation developments with AI KAZ.
//
// On confirm:
//   - sets frontEndPlanning.skippedBusinessCase = true
//   - sets frontEndPlanning.businessCaseLocked = true (the BC screens
//     are skipped, so they are also locked)
//   - writes the description to projectData.projectDescription
//     (alias for solutionDescription) and projectData.notes
//   - the FEP screens downstream (Summary, Requirements, Risks, etc.)
//     will use this description as AI KAZ context
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/docx_import_service.dart';
import 'package:ndu_project/utils/business_case_lock_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

class SkipBusinessCaseDialog {
  SkipBusinessCaseDialog._();

  /// Opens the skip wizard. Skipping the Business Case captures a preferred
  /// solution; skipping both Business Case and FEP captures charter essentials.
  static Future<bool> show(
    BuildContext context, {
    bool skipFrontEndPlanning = false,
  }) async {
    final provider = ProjectDataHelper.getProvider(context);
    final data = provider.projectData;
    final controller = SpellCheckTextEditingController(
      text: data.projectDescription.isNotEmpty
          ? data.projectDescription
          : data.notes,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SkipBusinessCaseDialog(
        controller: controller,
        projectName: data.projectName.isEmpty ? 'Untitled Project' : data.projectName,
        skipFrontEndPlanning: skipFrontEndPlanning,
        onConfirm: (draft) async {
          final skipFrontEndPlanning = draft.skipFrontEndPlanning;
          final solutionTitle = draft.solutionTitle.trim();
          final solutionDescription = draft.solutionDescription.trim();
          final objective = draft.objective.trim();
          final scope = draft.scope.trim();
          final deliverables = draft.deliverables.trim();
          final stakeholders = draft.stakeholders.trim();
          if (solutionTitle.isEmpty ||
              solutionDescription.isEmpty ||
              objective.isEmpty ||
              scope.isEmpty ||
              deliverables.isEmpty ||
              (skipFrontEndPlanning && stakeholders.isEmpty)) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(skipFrontEndPlanning
                    ? 'Complete solution, objective, scope, deliverables, and key stakeholders before skipping both phases.'
                    : 'Complete the preferred solution, objective, scope, and deliverables before skipping the Business Case.'),
                backgroundColor: const Color(0xFFD97706),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return false;
          }

          final combinedDescription = [
            'Preferred solution: $solutionTitle',
            solutionDescription,
            'Project objective: $objective',
            'In scope: $scope',
            'Key deliverables: $deliverables',
            if (stakeholders.isNotEmpty) 'Core stakeholders: $stakeholders',
          ].join('\\n\\n');
          final now = DateTime.now();
          provider.updateField((project) {
            final updatedSolutions = List<PotentialSolution>.from(project.potentialSolutions);
            if (updatedSolutions.isEmpty) {
              updatedSolutions.add(PotentialSolution(
                id: 'preferred-solution-skip-${now.microsecondsSinceEpoch}',
                number: 1,
                title: solutionTitle,
                description: solutionDescription,
              ));
            } else {
              updatedSolutions[0] = updatedSolutions[0].copyWith(
                title: solutionTitle,
                description: solutionDescription,
              );
            }
            return project.copyWith(
              solutionTitle: solutionTitle,
              solutionDescription: combinedDescription,
              potentialSolutions: updatedSolutions,
              projectObjective: objective,
              withinScope: scope.split('\\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList(),
              projectGoals: [ProjectGoal(name: objective, description: deliverables)],
              stakeholderEntries: skipFrontEndPlanning && stakeholders.isNotEmpty
                  ? [
                      StakeholderEntry(
                        id: 'skip-charter-${now.microsecondsSinceEpoch}',
                        name: stakeholders,
                        organization: '',
                        role: 'Core stakeholder',
                        influence: 'High',
                        interest: 'High',
                        channel: '',
                        contactInfo: '',
                        owner: '',
                        notes: '',
                        createdAt: now,
                        updatedAt: now,
                      ),
                    ]
                  : project.stakeholderEntries,
              frontEndPlanning: project.frontEndPlanning.copyWith(
                skippedBusinessCase: true,
                skippedFrontEndPlanning: skipFrontEndPlanning,
                businessCaseLocked: true,
                detailsConfirmed: true,
                summary: objective,
                requirements: scope,
                requirementsPlan: deliverables,
                requirementsNotes: combinedDescription,
              ),
              currentCheckpoint: skipFrontEndPlanning ? 'project_charter' : 'fep_summary',
            );
          });
          await provider.saveToFirebase(
            checkpoint: skipFrontEndPlanning ? 'project_charter' : 'skip_business_case',
          );
          return true;
        },
      ),
    );

    controller.dispose();
    return result ?? false;
  }
}

class _SkipBusinessCaseDialog extends StatefulWidget {
  const _SkipBusinessCaseDialog({
    required this.controller,
    required this.projectName,
    required this.skipFrontEndPlanning,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final String projectName;
  final bool skipFrontEndPlanning;
  final Future<bool> Function(_SkipProjectDraft draft) onConfirm;

  @override
  State<_SkipBusinessCaseDialog> createState() =>
      _SkipBusinessCaseDialogState();
}

class _SkipBusinessCaseDialogState extends State<_SkipBusinessCaseDialog> {
  bool _saving = false;
  late bool _skipFrontEndPlanning;
  late final TextEditingController _solutionTitleController;
  late final TextEditingController _objectiveController;
  late final TextEditingController _scopeController;
  late final TextEditingController _deliverablesController;
  late final TextEditingController _stakeholdersController;

  @override
  void initState() {
    super.initState();
    _skipFrontEndPlanning = widget.skipFrontEndPlanning;
    _solutionTitleController = SpellCheckTextEditingController();
    _objectiveController = SpellCheckTextEditingController();
    _scopeController = SpellCheckTextEditingController();
    _deliverablesController = SpellCheckTextEditingController();
    _stakeholdersController = SpellCheckTextEditingController();
  }

  @override
  void dispose() {
    _solutionTitleController.dispose();
    _objectiveController.dispose();
    _scopeController.dispose();
    _deliverablesController.dispose();
    _stakeholdersController.dispose();
    super.dispose();
  }

  Future<String?> _importCharterBrief() async {
    final outcome = await DocxImportService.pickAndExtract(context);
    if (outcome is DocxImportSuccess) return outcome.result.text;
    if (outcome is DocxImportError &&
        outcome.reason != DocxImportFailure.cancelledByUser &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.message ?? 'Unable to import this file.')),
      );
    }
    return null;
  }

  void _applyImportedBrief(String text) {
    _solutionTitleController.text = _extractBriefValue(text, 'Preferred solution');
    _objectiveController.text = _extractBriefValue(text, 'Project objective');
    _scopeController.text = _extractBriefValue(text, 'In scope');
    _deliverablesController.text = _extractBriefValue(text, 'Key deliverables');
    _stakeholdersController.text = _extractBriefValue(text, 'Core stakeholders');
    if (_solutionTitleController.text.isEmpty) _solutionTitleController.text = widget.projectName;
    widget.controller.text = text;
  }

  String _extractBriefValue(String text, String label) {
    final lines = text.split(RegExp(r'\\r?\\n'));
    final labelLower = label.toLowerCase();
    final start = lines.indexWhere((line) =>
        line.trimLeft().toLowerCase().startsWith('$labelLower:'));
    if (start < 0) return '';

    final firstLine = lines[start].trimLeft();
    final value = <String>[firstLine.substring(firstLine.indexOf(':') + 1).trim()];
    for (var i = start + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || RegExp(r'^[A-Z][^:]{1,45}:').hasMatch(line)) break;
      value.add(line);
    }
    return value.where((line) => line.isNotEmpty).join('\\n').trim();
  }

  Widget _charterField(String label, TextEditingController controller, String hint, {int minLines = 2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VoiceTextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 2,
        enableDocxImport: false,
        enableKazAi: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD97706), width: 1),
            ),
            child: const Icon(Icons.fast_forward_rounded,
                size: 20, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Skip Business Case',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project: ${widget.projectName}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Text(
              _skipFrontEndPlanning
                  ? 'You are skipping both initiation analysis and Front End Planning. Enter or import the minimum charter brief below. These structured details will populate the project objective, scope, deliverables, preferred solution, and core stakeholder sections.'
                  : 'You are skipping the Business Case only. Capture the preferred solution, objective, scope, and deliverables so Front End Planning starts with a useful, structured baseline. You can type, speak, or import an existing brief.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _skipFrontEndPlanning,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _skipFrontEndPlanning = value),
              title: const Text('Also skip Front End Planning'),
              subtitle: const Text('Go directly to the charter and capture its core details here.'),
            ),
            const SizedBox(height: 12),
            if (_skipFrontEndPlanning) ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final text = await _importCharterBrief();
                          if (text != null && mounted) setState(() => _applyImportedBrief(text));
                        },
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import charter brief'),
                ),
              ),
              _charterField('Preferred solution *', _solutionTitleController, 'Name the selected solution'),
              _charterField('Project objective *', _objectiveController, 'What outcome will this project achieve?'),
              _charterField('Scope *', _scopeController, 'What is included? List key boundaries.'),
              _charterField('Key deliverables *', _deliverablesController, 'What will be delivered and accepted?'),
              _charterField('Core stakeholders *', _stakeholdersController, 'Name the sponsor, decision-maker, owner, and key users.'),
              _charterField('Additional context', widget.controller, 'Constraints, assumptions, risks, and success measures.'),
            ] else ...[
              const Text(
                'Preferred Solution & FEP Baseline *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1D1F)),
              ),
              const SizedBox(height: 8),
              _charterField('Preferred solution *', _solutionTitleController, 'Name the selected solution'),
              _charterField('Solution description *', widget.controller, 'Describe the known solution, why it is preferred, major constraints, and intended outcomes.', minLines: 4),
              _charterField('Project objective *', _objectiveController, 'What outcome will this project achieve?'),
              _charterField('Initial scope *', _scopeController, 'What is included? Add boundaries or exclusions.'),
              _charterField('Key deliverables *', _deliverablesController, 'List tangible outputs and acceptance expectations.'),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final text = await _importCharterBrief();
                          if (text != null && mounted) {
                            widget.controller.text = text;
                            _objectiveController.text = _extractBriefValue(text, 'Project objective');
                            _scopeController.text = _extractBriefValue(text, 'In scope');
                            _deliverablesController.text = _extractBriefValue(text, 'Key deliverables');
                          }
                        },
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import existing brief'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFC812).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFFFFC812)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _skipFrontEndPlanning
                          ? 'This will mark both Business Case and FEP as bypassed. The captured brief is saved directly to the project charter core; the Charter is still editable until approved.'
                          : 'The Business Case analysis screens will be bypassed. Your preferred solution, objective, scope, and deliverables will seed FEP; the FEP and Charter remain available for refinement.',
                      style: const TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final ok = await widget.onConfirm(_SkipProjectDraft(
                    skipFrontEndPlanning: _skipFrontEndPlanning,
                    solutionTitle: _solutionTitleController.text,
                    solutionDescription: widget.controller.text,
                    objective: _objectiveController.text,
                    scope: _scopeController.text,
                    deliverables: _deliverablesController.text,
                    stakeholders: _stakeholdersController.text,
                  ));
                  if (!mounted) return;
                  setState(() => _saving = false);
                  if (ok) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            _skipFrontEndPlanning
                                ? 'Business Case and FEP skipped. Your charter brief has been saved.'
                                : 'Business Case skipped. Your preferred solution and baseline have been saved for FEP.'),
                        backgroundColor: const Color(0xFFFFC812),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_skipFrontEndPlanning ? 'Save charter & skip both' : 'Save solution & skip Business Case'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SkipProjectDraft {
  const _SkipProjectDraft({
    required this.skipFrontEndPlanning,
    required this.solutionTitle,
    required this.solutionDescription,
    required this.objective,
    required this.scope,
    required this.deliverables,
    required this.stakeholders,
  });

  final bool skipFrontEndPlanning;
  final String solutionTitle;
  final String solutionDescription;
  final String objective;
  final String scope;
  final String deliverables;
  final String stakeholders;
}

/// Returns true if the user has skipped the Business Case workflow
/// for the given project data.
bool isBusinessCaseSkipped(ProjectDataModel? data) {
  if (data == null) return false;
  return data.frontEndPlanning.skippedBusinessCase;
}

/// A small banner that surfaces the "Skip Business Case" affordance on any
/// Business Case screen (Scope Statement, Potential Solutions, Risk
/// Identification, etc.). Tapping the action opens [SkipBusinessCaseDialog]
/// so the user can provide a robust project description that becomes the
/// basis for FEP documentation with AI KAZ.
///
/// The banner is automatically hidden once the Business Case is locked
/// (preferred solution selected OR already skipped) — in those states there
/// is nothing to skip.
class SkipBusinessCaseAffordance extends StatelessWidget {
  const SkipBusinessCaseAffordance({
    super.key,
    this.onAfterSkip,
    this.compact = false,
  });

  /// Called after the user confirms the skip flow. The caller can use this
  /// to navigate to the FEP Summary screen or refresh UI state.
  final VoidCallback? onAfterSkip;

  /// When true, renders as a single inline button instead of a full banner.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // listen: true so the banner hides itself the moment the user confirms
    // the skip in the dialog (the provider notifies, this rebuilds, and the
    // [isBusinessCaseSkipped] / [BusinessCaseLockHelper.isBusinessCaseLocked]
    // checks return true).
    final data = ProjectDataHelper.getData(context, listen: true);
    // Hide entirely when the Business Case is already locked or already
    // skipped — there is nothing to skip in those states.
    if (BusinessCaseLockHelper.isBusinessCaseLocked(data) ||
        isBusinessCaseSkipped(data)) {
      return const SizedBox.shrink();
    }

    Future<void> openSkipDialog() async {
      final skipped = await SkipBusinessCaseDialog.show(context);
      if (skipped && onAfterSkip != null) {
        onAfterSkip!();
      }
    }

    if (compact) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: openSkipDialog,
          icon: const Icon(Icons.fast_forward_rounded, size: 18),
          label: const Text('Skip Business Case'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFD97706),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD97706), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fast_forward_rounded,
              size: 20, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Already know the solution?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Skip the Business Case workflow and provide a robust '
                  'project description instead. You can type, import '
                  '(DOCX/PDF/TXT/MD), or speak it — your description '
                  'becomes the basis for FEP documentation developments '
                  'with AI KAZ.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: openSkipDialog,
                    icon: const Icon(Icons.fast_forward_rounded, size: 16),
                    label: const Text('Skip Business Case'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

/// A small status banner shown on Business Case screens once the user has
/// already skipped the workflow. Tells them their project description is
/// being used as the basis for FEP documentation with AI KAZ, and surfaces
/// a button to re-open the dialog if they want to refine the description.
class BusinessCaseSkippedBanner extends StatelessWidget {
  const BusinessCaseSkippedBanner({
    super.key,
    this.onAfterUpdate,
  });

  final VoidCallback? onAfterUpdate;

  @override
  Widget build(BuildContext context) {
    // listen: true so the banner appears/disappears as the skip state changes.
    final data = ProjectDataHelper.getData(context, listen: true);
    if (!isBusinessCaseSkipped(data)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFFFC812).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: Color(0xFFFFC812)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business Case skipped',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFC812),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your project description is now the basis for FEP '
                  'documentation developments with AI KAZ. The Business '
                  'Case screens are view-only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFC812),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final updated = await SkipBusinessCaseDialog.show(
                          context);
                      if (updated && onAfterUpdate != null) {
                        onAfterUpdate!();
                      }
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Update description'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC812),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
