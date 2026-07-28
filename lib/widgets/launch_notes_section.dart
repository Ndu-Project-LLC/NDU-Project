import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

/// A reusable Notes section widget for Launch Phase screens.
/// Provides a labeled text area with KAZ AI, clear-all, text formatting,
/// and voice input — all built into VoiceTextField.
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
    this.hint = 'Add any additional notes, observations, or context for this section...',
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sticky_note_2_outlined,
                    color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                'Auto-saved',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Text field with KAZ AI + clear-all + formatting (all built into VoiceTextField)
          VoiceTextField(
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937), height: 1.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
