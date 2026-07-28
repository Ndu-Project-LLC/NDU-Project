import 'package:flutter/material.dart';

class AiRegenerateUndoButtons extends StatelessWidget {
  const AiRegenerateUndoButtons({
    super.key,
    required this.onRegenerate,
    required this.onUndo,
    required this.onRedo,
    required this.isLoading,
    required this.canUndo,
    required this.canRedo,
  });

  final VoidCallback onRegenerate;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool isLoading;
  final bool canUndo;
  final bool canRedo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Regenerate (AI)',
          onPressed: isLoading ? null : onRegenerate,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18, color: Color(0xFFD97706)),
        ),
        IconButton(
          tooltip: 'Undo last AI regenerate',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo, size: 18, color: Color(0xFF6B7280)),
        ),
        IconButton(
          tooltip: 'Redo last AI regenerate',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo, size: 18, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
