import 'package:flutter/material.dart';

/// Reusable field-level regenerate and undo buttons
/// Shows on hover over text fields that have KAZ AI-generated content
class FieldRegenerateUndoButtons extends StatelessWidget {
  const FieldRegenerateUndoButtons({
    super.key,
    required this.onRegenerate,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    this.isLoading = false,
    this.size = 20,
  });

  final VoidCallback onRegenerate;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool isLoading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarActionIcon(
            icon: isLoading
                ? SizedBox(
                    width: size,
                    height: size,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  )
                : Icon(Icons.refresh, size: size, color: Colors.grey.shade700),
            tooltip: 'Regenerate this field',
            onPressed: isLoading ? null : onRegenerate,
            hoverColor: primary.withValues(alpha: 0.08),
          ),
          _verticalDivider(),
          _ToolbarActionIcon(
            icon: Icon(
              Icons.undo,
              size: size,
              color: canUndo ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            tooltip: 'Undo last change',
            onPressed: canUndo ? onUndo : null,
            hoverColor: primary.withValues(alpha: 0.08),
          ),
          _verticalDivider(),
          _ToolbarActionIcon(
            icon: Icon(
              Icons.redo,
              size: size,
              color: canRedo ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            tooltip: 'Redo last change',
            onPressed: canRedo ? onRedo : null,
            hoverColor: primary.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0xFFE5E7EB),
    );
  }
}

/// Wrapper widget that shows regenerate/undo buttons on hover
class HoverableFieldControls extends StatefulWidget {
  const HoverableFieldControls({
    super.key,
    required this.child,
    required this.onRegenerate,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    this.isAiGenerated = false,
    this.isLoading = false,
  });

  final Widget child;
  final VoidCallback onRegenerate;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool isAiGenerated;
  final bool isLoading;

  @override
  State<HoverableFieldControls> createState() => _HoverableFieldControlsState();
}

class _HoverableFieldControlsState extends State<HoverableFieldControls> {
  bool _isHovering = false;

  void _setHovering(bool value) {
    if (mounted && _isHovering != value) {
      setState(() => _isHovering = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAiGenerated) {
      return widget.child;
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final showControls = isMobile || _isHovering;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FieldRegenerateUndoButtons(
            onRegenerate: widget.onRegenerate,
            onUndo: widget.onUndo,
            onRedo: widget.onRedo,
            canUndo: widget.canUndo,
            canRedo: widget.canRedo,
            isLoading: widget.isLoading,
            size: 16,
          ),
          const SizedBox(height: 6),
          widget.child,
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              offset: showControls ? Offset.zero : const Offset(0.08, -0.06),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !showControls,
                  child: FieldRegenerateUndoButtons(
                    onRegenerate: widget.onRegenerate,
                    onUndo: widget.onUndo,
                    onRedo: widget.onRedo,
                    canUndo: widget.canUndo,
                    canRedo: widget.canRedo,
                    isLoading: widget.isLoading,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarActionIcon extends StatelessWidget {
  const _ToolbarActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.hoverColor,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color hoverColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        splashRadius: 18,
        hoverColor: hoverColor,
      ),
    );
  }
}
