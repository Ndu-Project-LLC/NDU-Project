import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Generic AI Assist helper that generates contextual content for any screen.
///
/// When called, it:
/// 1. Reads the current project data via [ProjectDataHelper]
/// 2. Builds a context scan using the screen's [sectionLabel]
/// 3. Calls [OpenAiServiceSecure.generateCompletion] to generate content
/// 4. Shows a dialog with the generated content + copy/insert options
class AiAssistHelper {
  AiAssistHelper._();

  /// Generates contextual content for the given [sectionLabel] and shows
  /// the result in a dialog. The user can copy the content to clipboard
  /// or close the dialog.
  ///
  /// [sectionLabel] should be the title of the current screen (e.g.
  /// "Cost Estimate", "Risk Tracking", "Stakeholder Management").
  static Future<void> generateForSection(
    BuildContext context, {
    required String sectionLabel,
    int maxTokens = 1000,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = ProjectDataHelper.getData(context);
      final contextText =
          ProjectDataHelper.buildProjectContextScan(data, sectionLabel: sectionLabel);

      if (contextText.trim().isEmpty) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No project data available. Please complete project setup first.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final prompt = '''You are a project management assistant. Based on the project context below, generate practical, specific content for the "$sectionLabel" section.

Project Context:
$contextText

IMPORTANT RULES:
- Generate content that is directly relevant to the "$sectionLabel" section
- Use the project name, goals, milestones, and other context from above
- Be specific and actionable — avoid generic filler
- Structure the content with clear headings and bullet points where appropriate
- If this is a table-based section, suggest 3-5 realistic entries with realistic data
- If this is a text-based section, write a concise 2-3 paragraph summary
- Reference actual project details (name, solution, business case) where relevant
- Keep the tone professional and practical''';

      final result = await OpenAiServiceSecure().generateCompletion(
        prompt,
        maxTokens: maxTokens,
        temperature: 0.5,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (result.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI Assist could not generate content. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Show the generated content in a dialog
      if (context.mounted) {
        _showGeneratedContentDialog(context, sectionLabel, result);
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // dismiss loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Assist failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Shows the generated content in a dialog with copy-to-clipboard option.
  static void _showGeneratedContentDialog(
    BuildContext context,
    String sectionLabel,
    String content,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFFC812), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Assist — $sectionLabel',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF1E293B)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Content copied to clipboard'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC812),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
