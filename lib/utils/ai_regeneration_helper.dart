import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Helper utility for adding AI regeneration functionality to screens
class AiRegenerationHelper {
  /// Creates a page-level regenerate all button with confirmation
  static Widget buildPageRegenerateButton({
    required BuildContext context,
    required VoidCallback onRegenerate,
    required bool isLoading,
    String tooltip = 'Regenerate all AI content on this page',
  }) {
    return PageRegenerateAllButton(
      onRegenerateAll: () async {
        final confirmed = await showRegenerateAllConfirmation(context);
        if (confirmed && context.mounted) {
          onRegenerate();
        }
      },
      isLoading: isLoading,
      tooltip: tooltip,
    );
  }

  /// Wraps a text field with hover-based regenerate/undo buttons
  static Widget wrapFieldWithControls({
    required BuildContext context,
    required Widget child,
    required String fieldKey,
    required TextEditingController controller,
    required VoidCallback onRegenerate,
    bool isAiGenerated = true,
    bool isLoading = false,
  }) {
    final provider = ProjectDataHelper.getProvider(context);
    final canUndo = provider.canUndoField(fieldKey);
    final canRedo = provider.canRedoField(fieldKey);

    return HoverableFieldControls(
      isAiGenerated: isAiGenerated,
      isLoading: isLoading,
      canUndo: canUndo,
      canRedo: canRedo,
      onRegenerate: () {
        // Add current value to history before regenerating
        provider.addFieldToHistory(fieldKey, controller.text, isAiGenerated: true);
        onRegenerate();
      },
      onUndo: () async {
        final data = provider.projectData;
        final previousValue = data.undoField(fieldKey);
        if (previousValue != null && previousValue.isNotEmpty) {
          controller.text = previousValue;
          await provider.saveToFirebase(checkpoint: 'field_undo');
        }
      },
      onRedo: () async {
        final data = provider.projectData;
        final nextValue = data.redoField(fieldKey);
        if (nextValue != null) {
          controller.text = nextValue;
          await provider.saveToFirebase(checkpoint: 'field_redo');
        }
      },
      child: child,
    );
  }

  /// Adds field to history when value changes
  static void trackFieldChange(String fieldKey, String value, {bool isAiGenerated = false}) {
    // This should be called from the screen's onChanged callback
    // Implementation will be handled by ProjectDataProvider
  }
}
