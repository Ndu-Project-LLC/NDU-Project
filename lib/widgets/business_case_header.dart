import 'package:flutter/material.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/ai_assist_helper.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

/// Standardized header for all Business Case pages
/// Displays: back button, "Initiation Phase" title, user profile,
/// and action buttons (Export PDF, AI Assist) matching PlanningPhaseHeader style.
class BusinessCaseHeader extends StatelessWidget {
  const BusinessCaseHeader({
    super.key,
    this.onBackPressed,
    this.scaffoldKey,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
    this.showExportPdf = true,
    this.showAiAssist = true,
    this.onExportPdf,
    this.onAiAssist,
  });

  final VoidCallback? onBackPressed;
  final GlobalKey<ScaffoldState>? scaffoldKey;
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
    final title = breadcrumbTitle ?? 'Initiation Phase';
    PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: title,
      sections: [
        PdfSection.text(title, 'Project section export from Ndu Project.'),
      ],
    );
  }

  void _defaultAiAssist(BuildContext context) {
    final title = breadcrumbTitle ?? 'Initiation Phase';
    AiAssistHelper.generateForSection(context, sectionLabel: title);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UnifiedPhaseHeader(
          title: 'Initiation Phase',
          breadcrumbPhase: breadcrumbPhase,
          breadcrumbTitle: breadcrumbTitle,
          scaffoldKey: scaffoldKey,
          onBackPressed: onBackPressed,
        ),
        if (showExportPdf || showAiAssist) ...[
          if (isMobile)
            const SizedBox(height: 12)
          else
            const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Wrap(
              alignment: WrapAlignment.end,
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
