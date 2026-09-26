import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/collapsible_notes_section.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// A reusable Notes section widget for Launch Phase screens.
/// Provides a collapsible, labeled text area with KAZ AI, clear-all, text
/// formatting, and voice input — all built into VoiceTextField.
///
/// The section starts collapsed; it only opens when the user opens it.
///
/// Usage:
/// ```dart
/// LaunchNotesSection(
///   controller: _notesController,
///   label: 'Notes',
///   hint: 'Add any additional notes for this section...',
///   onChanged: (value) { /* save */ },
/// )
/// ```
class LaunchNotesSection extends StatelessWidget {
  const LaunchNotesSection({
    super.key,
    required this.controller,
    this.label = 'Notes',
    this.hint =
        'Add any additional notes, observations, or context for this section...',
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CollapsibleNotesSection(
      title: label,
      icon: Icons.sticky_note_2_outlined,
      card: true,
      trailing: Text(
        'Auto-saved',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
      ),
      child: VoiceTextField(
        controller: controller,
        maxLines: 6,
        minLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF1F2937), height: 1.5),
        onChanged: onChanged,
      ),
    );
  }
}
