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
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/business_case_lock_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

class SkipBusinessCaseDialog {
  SkipBusinessCaseDialog._();

  /// Opens the Skip Business Case dialog. Returns true if the user
  /// confirmed the skip (and the project description was saved).
  static Future<bool> show(BuildContext context) async {
    final provider = ProjectDataHelper.getProvider(context);
    final data = provider.projectData;
    final controller = TextEditingController(
      text: data.projectDescription.isNotEmpty
          ? data.projectDescription
          : data.notes,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SkipBusinessCaseDialog(
        controller: controller,
        projectName: data.projectName ?? 'Untitled Project',
        onConfirm: () async {
          final description = controller.text.trim();
          if (description.isEmpty) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please enter a project description before skipping the Business Case. The description will be used as the basis for FEP documentation with AI KAZ.'),
                backgroundColor: Color(0xFFD97706),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return false;
          }

          // Mark the Business Case as skipped + locked, and store the
          // description as the project description (and notes) so the
          // FEP screens can use it as AI KAZ context.
          // NOTE: `projectDescription` is a getter/setter alias for
          // `solutionDescription`, so we set solutionDescription
          // directly via copyWith.
          provider.updateField((d) => d.copyWith(
                solutionDescription: description,
                notes: description.isEmpty ? d.notes : description,
                frontEndPlanning: d.frontEndPlanning.copyWith(
                  skippedBusinessCase: true,
                  businessCaseLocked: true,
                ),
              ));
          await provider.saveToFirebase(
              checkpoint: 'skip_business_case');

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
    required this.onConfirm,
  });

  final TextEditingController controller;
  final String projectName;
  final Future<bool> Function() onConfirm;

  @override
  State<_SkipBusinessCaseDialog> createState() =>
      _SkipBusinessCaseDialogState();
}

class _SkipBusinessCaseDialogState extends State<_SkipBusinessCaseDialog> {
  bool _saving = false;

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
            const Text(
              'If you already know the solution, you can skip the Business '
              'Case workflow. Enter a robust project description below — '
              'type, import (DOCX/PDF/TXT/MD), or speak it. This description '
              'will serve as the basis for FEP documentation developments '
              'with AI KAZ.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Project Description *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D1F)),
            ),
            const SizedBox(height: 8),
            VoiceTextField(
              controller: widget.controller,
              maxLines: 8,
              minLines: 6,
              enableVoice: true,
              enableDocxImport: true,
              enableKazAi: false,
              decoration: InputDecoration(
                hintText: 'Describe the core project details: objectives, '
                    'scope, known solution, deliverables, constraints, '
                    'and any other context that should seed the FEP '
                    'documentation. You can type, paste, tap the upload '
                    'icon to import a DOCX/PDF/TXT/MD file, or tap the '
                    'mic to speak.',
                hintStyle: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF005BB3), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF005BB3).withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF005BB3)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After skipping, the Business Case screens (Potential '
                      'Solutions, Risk Identification, Preferred Solution '
                      'Analysis) will be locked. You can still edit IT '
                      'Considerations and Infrastructure Considerations '
                      'from their dedicated pages.',
                      style: TextStyle(fontSize: 11, height: 1.4),
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
                  final ok = await widget.onConfirm();
                  if (!mounted) return;
                  setState(() => _saving = false);
                  if (ok) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Business Case skipped. Your project description '
                            'is now the basis for FEP documentation with AI KAZ.'),
                        backgroundColor: Color(0xFF005BB3),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 4),
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
          label: const Text('Confirm & Skip'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF005BB3).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: Color(0xFF005BB3)),
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
                    color: Color(0xFF005BB3),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your project description is now the basis for FEP '
                  'documentation developments with AI KAZ. The Business '
                  'Case screens are view-only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E40AF),
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
                      foregroundColor: const Color(0xFF005BB3),
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
