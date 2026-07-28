import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/widgets/ai_diagram_panel.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/utils/ai_assist_helper.dart';

const Map<String, String> executionCheckpointAlias = {
  'execution_plan_outline': 'execution_plan',
  'execution_lessons_learned': 'execution_plan_lessons_learned',
  'execution_best_practices': 'execution_plan_best_practices',
  'execution_construction_plan': 'execution_plan_construction_plan',
  'execution_infrastructure_plan': 'execution_plan_infrastructure_plan',
  'execution_agile_delivery_plan': 'execution_plan_agile_delivery_plan',
  'execution_interface_management': 'execution_plan_interface_management',
  'execution_communication_plan': 'execution_plan_communication_plan',
  'execution_interface_management_plan':
      'execution_plan_interface_management_plan',
  'execution_stakeholder_identification':
      'execution_plan_stakeholder_identification',
  'execution_plan_interface_overview':
      'execution_plan_interface_management_overview',
};

const String executionStakeholderRowsNotesKey =
    'execution_stakeholder_identification_rows';

String resolveExecutionCheckpoint(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return 'execution_plan';
  return executionCheckpointAlias[trimmed] ?? trimmed;
}

class ExecutionPlanHeader extends StatelessWidget {
  const ExecutionPlanHeader({
    super.key,
    required this.onBack,
    this.onNext,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
    this.showExportPdf = true,
    this.showAiAssist = true,
    this.onExportPdf,
    this.onAiAssist,
  });

  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String? breadcrumbPhase;
  final String? breadcrumbTitle;

  /// Show Export PDF button in the action row.
  final bool showExportPdf;

  /// Show AI Assist button in the action row.
  final bool showAiAssist;

  /// Callback for Export PDF button.
  final VoidCallback? onExportPdf;

  /// Callback for AI Assist button.
  final VoidCallback? onAiAssist;

  void _defaultExportPdf(BuildContext context) {
    final title = breadcrumbTitle ?? 'Execution Plan';
    PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: title,
      sections: [
        PdfSection.text(title, 'Project section export from Ndu Project.'),
      ],
    );
  }

  void _defaultAiAssist(BuildContext context) {
    final title = breadcrumbTitle ?? 'Execution Plan';
    AiAssistHelper.generateForSection(context, sectionLabel: title);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UnifiedPhaseHeader(
          title: 'Execution Plan',
          breadcrumbPhase: breadcrumbPhase,
          breadcrumbTitle: breadcrumbTitle,
          showDrawerButton: true,
          onBackPressed: onBack,
          onForwardPressed: onNext,
          showActivityLogAction: true,
        ),
        if (showExportPdf || showAiAssist) ...[
          if (isMobile)
            const SizedBox(height: 12)
          else
            const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (showExportPdf)
                  _WhiteButton(
                    label: 'Export PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: onExportPdf ?? () => _defaultExportPdf(context),
                  ),
                if (showAiAssist)
                  _AiAssistButton(
                    label: 'AI Assist',
                    icon: Icons.auto_awesome,
                    onPressed: onAiAssist ?? () => _defaultAiAssist(context),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AiAssistButton extends StatelessWidget {
  const _AiAssistButton(
      {required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4154F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class CurrentUserProfileChip extends StatelessWidget {
  const CurrentUserProfileChip({super.key});

  String _initials(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r"\s+"));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    final photoUrl = user?.photoURL;
    final email = user?.email ?? '';

    return StreamBuilder<bool>(
      stream: UserService.watchAdminStatus(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
        final role = isAdmin ? 'Admin' : 'Member';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE5E7EB),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                        _initials(displayName),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)),
                  ),
                  Text(
                    role,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class SectionIntro extends StatelessWidget {
  const SectionIntro({super.key, this.title = 'Executive Plan Outline'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Outline the strategy and actions for the implementation phase.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class ExecutionPlanForm extends StatefulWidget {
  const ExecutionPlanForm({super.key, 
    this.title = 'Executive Plan Outline',
    required this.hintText,
    this.noteKey,
    this.showDiagram = true,
  });

  final String title;
  final String hintText;
  final String? noteKey;
  final bool showDiagram;

  @override
  State<ExecutionPlanForm> createState() => _ExecutionPlanFormState();
}

class _ExecutionPlanFormState extends State<ExecutionPlanForm> {
  String _currentText = '';
  Timer? _saveDebounce;
  DateTime? _lastSavedAt;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _handleChanged(String value) {
    _currentText = value;
    final noteKey = widget.noteKey;
    if (noteKey == null || noteKey.trim().isEmpty) return;
    final checkpoint = resolveExecutionCheckpoint(noteKey);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () async {
      final trimmed = value.trim();
      final success = await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: checkpoint,
        dataUpdater: (data) {
          final currentExecutionData =
              data.executionPhaseData ?? ExecutionPhaseData();
          final updatedExecutionData = (noteKey == 'execution_plan_outline')
              ? currentExecutionData.copyWith(executionPlanOutline: trimmed)
              : (noteKey == 'execution_plan_strategy')
                  ? currentExecutionData.copyWith(
                      executionPlanStrategy: trimmed)
                  : currentExecutionData;

          return data.copyWith(
            executionPhaseData: updatedExecutionData,
            planningNotes: {
              ...data.planningNotes,
              noteKey:
                  trimmed,
            },
          );
        },
        showSnackbar: false,
      );
      if (mounted && success) {
        setState(() => _lastSavedAt = DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noteKey = widget.noteKey;
    if (noteKey != null && _currentText.isEmpty) {
      final projectData = ProjectDataHelper.getData(context);
      String saved = '';

      if (noteKey == 'execution_plan_outline') {
        saved = projectData.executionPhaseData?.executionPlanOutline ?? '';
      } else if (noteKey == 'execution_plan_strategy') {
        saved = projectData.executionPhaseData?.executionPlanStrategy ?? '';
      }

      if (saved.isEmpty) {
        saved = projectData.planningNotes[noteKey] ?? '';
      }

      if (saved.trim().isNotEmpty) {
        _currentText = saved;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiSuggestingTextField(
          fieldLabel: widget.title,
          hintText: widget.hintText,
          sectionLabel: 'Execution Plan',
          showLabel: true,
          initialText: noteKey == null
              ? null
              : () {
                  final projectData = ProjectDataHelper.getData(context);
                  if (noteKey == 'execution_plan_outline') {
                    return projectData
                            .executionPhaseData?.executionPlanOutline ??
                        projectData.planningNotes[noteKey];
                  } else if (noteKey == 'execution_plan_strategy') {
                    return projectData
                            .executionPhaseData?.executionPlanStrategy ??
                        projectData.planningNotes[noteKey];
                  }
                  return projectData.planningNotes[noteKey];
                }(),
          autoGenerate: true,
          autoGenerateSection: widget.title,
          onChanged: _handleChanged,
        ),
        if (_lastSavedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
        if (widget.showDiagram)
          AiDiagramPanel(
            sectionLabel: widget.title,
            currentTextProvider: () => _currentText,
            title: 'Generate ${widget.title} Diagram',
          ),
      ],
    );
  }
}

class InfoBadge extends StatelessWidget {
  const InfoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFDAE9FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
    );
  }
}

class AiTipCard extends StatelessWidget {
  const AiTipCard({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE1EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AiBadge(),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text ??
                  'Use concrete owners, dates, and dependencies so execution can be tracked and adjusted in real time.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiBadge extends StatelessWidget {
  const AiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
          SizedBox(width: 6),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class AddRowButton extends StatelessWidget {
  const AddRowButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, color: Color(0xFF111827)),
      label: const Text(
        'Add Row',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class AddSolutionButton extends StatelessWidget {
  const AddSolutionButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, color: Color(0xFF111827)),
      label: const Text(
        'Add Solution',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class CrossReferenceNote extends StatelessWidget {
  const CrossReferenceNote({super.key, required this.standalonePage, this.standaloneLabel});

  final String standalonePage;
  final String? standaloneLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For comprehensive ${standaloneLabel ?? standalonePage} planning, see the "$standalonePage" page in the Planning Phase.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class YellowActionButton extends StatelessWidget {
  const YellowActionButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
