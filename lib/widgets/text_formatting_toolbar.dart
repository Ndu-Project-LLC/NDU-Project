import 'package:flutter/material.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';

/// A toolbar for lightweight rich-text formatting tokens and undo support.
/// Pair it with `RichTextEditingController` to render formatting inline.
class TextFormattingToolbar extends StatefulWidget {
  const TextFormattingToolbar({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onBeforeUndo,
  });

  final TextEditingController controller;
  final bool enabled;

  /// Called immediately before undo. Use to save current state to avoid data loss.
  final VoidCallback? onBeforeUndo;

  @override
  State<TextFormattingToolbar> createState() => _TextFormattingToolbarState();
}

class _TextFormattingToolbarState extends State<TextFormattingToolbar> {
  final List<String> _undoHistory = [];
  static const int _maxUndoHistory = 50;
  bool _isUndoAvailable = false;
  bool _isExpanded = false;
  bool _manuallyExpanded = false;

  bool get _showHeadingButtons =>
      widget.controller is! AutoBulletTextController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    FocusManager.instance.addListener(_handleFocusChange);
    _saveToHistory();
    _syncToolbarVisibility();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _onTextChanged() {
    _syncToolbarVisibility();
    // Save to history on significant changes (debounced)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted &&
          widget.controller.text !=
              (_undoHistory.isEmpty ? '' : _undoHistory.last)) {
        _saveToHistory();
      }
    });
  }

  void _handleFocusChange() {
    _syncToolbarVisibility();
  }

  bool get _hasControllerFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    final editableAncestor =
        focusContext.findAncestorWidgetOfExactType<EditableText>();
    if (editableAncestor != null) {
      return identical(editableAncestor.controller, widget.controller);
    }
    final focusedWidget = focusContext.widget;
    if (focusedWidget is EditableText) {
      return identical(focusedWidget.controller, widget.controller);
    }
    return false;
  }

  void _syncToolbarVisibility() {
    if (!mounted) return;
    final hasFocus = _hasControllerFocus;

    if (_manuallyExpanded && !hasFocus) {
      _manuallyExpanded = false;
    }
    final shouldExpand = hasFocus || _manuallyExpanded;

    if (_isExpanded != shouldExpand) {
      setState(() {
        _isExpanded = shouldExpand;
      });
    }
  }

  void _saveToHistory() {
    if (_undoHistory.isEmpty || _undoHistory.last != widget.controller.text) {
      _undoHistory.add(widget.controller.text);
      if (_undoHistory.length > _maxUndoHistory) {
        _undoHistory.removeAt(0);
      }
      setState(() {
        _isUndoAvailable = _undoHistory.length > 1;
      });
    }
  }

  void _insertText(String before, String after) {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final start = selection.start;
    final end = selection.end;

    if (start == -1 || end == -1) return;

    final selectedText = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$before$selectedText$after');
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: start + before.length + selectedText.length + after.length),
    );
  }

  void _applyFormat(String markdownFormat) {
    switch (markdownFormat) {
      case 'bold':
        _insertText('**', '**');
        break;
      case 'italic':
        _insertText('*', '*');
        break;
      case 'underline':
        _insertText('__', '__');
        break;
      case 'h1':
        _applyHeading(1);
        break;
      case 'h2':
        _applyHeading(2);
        break;
      case 'h3':
        _applyHeading(3);
        break;
    }
  }

  void _applyHeading(int level) {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final start = selection.start;
    final end = selection.end;

    if (start == -1 || end == -1) return;

    final marker = '${'#' * level} ';
    final lineStart = start <= 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var normalizedEnd = end;
    if (normalizedEnd > lineStart && text[normalizedEnd - 1] == '\n') {
      normalizedEnd -= 1;
    }
    final lineEnd = normalizedEnd >= text.length
        ? text.length
        : (() {
            final nextBreak = text.indexOf('\n', normalizedEnd);
            return nextBreak == -1 ? text.length : nextBreak;
          })();
    final affectedText = text.substring(lineStart, lineEnd);
    final lines = affectedText.split('\n');
    final transformedLines = lines
        .map((line) => '$marker${line.replaceFirst(RegExp(r'^#{1,3}\s+'), '')}')
        .toList();
    final replacement = transformedLines.join('\n');

    if (selection.isCollapsed) {
      final originalLine = lines.isEmpty ? '' : lines.first;
      final trimmedLine = originalLine.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
      final removedPrefixLength = originalLine.length - trimmedLine.length;
      final relativeOffset = (start - lineStart - removedPrefixLength)
          .clamp(0, trimmedLine.length);
      widget.controller.value = TextEditingValue(
        text: text.replaceRange(lineStart, lineEnd, replacement),
        selection: TextSelection.collapsed(
          offset: lineStart + marker.length + relativeOffset,
        ),
      );
      return;
    }

    widget.controller.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, replacement),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
  }

  void _undo() {
    if (_undoHistory.length <= 1) return;
    widget.onBeforeUndo?.call();
    _undoHistory.removeLast(); // Remove current
    final previous = _undoHistory.last;
    widget.controller.value = TextEditingValue(
      text: previous,
      selection: TextSelection.collapsed(offset: previous.length),
    );
    setState(() {
      _isUndoAvailable = _undoHistory.length > 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    if (!_isExpanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: 'Show formatting tools',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _manuallyExpanded = true;
                _isExpanded = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Format',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                onPressed: () => _applyFormat('bold'),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                onPressed: () => _applyFormat('italic'),
              ),
              _ToolbarButton(
                icon: Icons.format_underlined,
                tooltip: 'Underline',
                onPressed: () => _applyFormat('underline'),
              ),
              if (_showHeadingButtons) ...[
                const VerticalDivider(width: 1, thickness: 1),
                _ToolbarButton(
                  icon: Icons.text_fields,
                  tooltip: 'Heading 1',
                  onPressed: () => _applyFormat('h1'),
                ),
                _ToolbarButton(
                  icon: Icons.title,
                  tooltip: 'Heading 2',
                  onPressed: () => _applyFormat('h2'),
                ),
              ],
              const VerticalDivider(width: 1, thickness: 1),
              _ToolbarButton(
                icon: Icons.undo,
                tooltip: 'Undo',
                onPressed: _isUndoAvailable ? _undo : null,
                isDisabled: !_isUndoAvailable,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              _ToolbarButton(
                icon: Icons.close_rounded,
                tooltip: 'Hide formatting tools',
                onPressed: () {
                  setState(() {
                    _manuallyExpanded = false;
                    _isExpanded = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDisabled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color:
            isDisabled || onPressed == null ? Colors.grey[400] : Colors.black87,
        onPressed: onPressed,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}
