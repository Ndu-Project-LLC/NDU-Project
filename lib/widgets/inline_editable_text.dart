import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:ndu_project/services/docx_import_service.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';

/// Inline editable text widget - clicking text turns it into an input field
/// with optional voice-to-text support.
class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.style,
    this.textAlign = TextAlign.left,
    this.maxLines = 1,
    this.isListField = false, // If true, uses "." bullet format
    this.isProseField = false, // If true, no bullets, multi-line
    this.showRegenerate = false,
    this.onRegenerate,
    this.isRegenerating = false,
    this.showUndo = false,
    this.onUndo,
    this.canUndo = false,
    this.enableVoice = true,
    this.voiceIconColor,
    this.enableDocxImport = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final bool isListField;
  final bool isProseField;
  final bool showRegenerate;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;
  final bool showUndo;
  final VoidCallback? onUndo;
  final bool canUndo;

  /// Whether to show the voice input mic button. Defaults to true.
  final bool enableVoice;

  /// Color of the mic icon. Defaults to brand yellow.
  final Color? voiceIconColor;

  /// Whether to show the document-import button. Defaults to true.
  final bool enableDocxImport;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  bool _isEditing = false;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final VoiceInputService _voiceService = VoiceInputService.instance;
  StreamSubscription<VoiceResult>? _voiceResultSub;
  StreamSubscription<VoiceStatus>? _voiceStatusSub;
  bool _isListening = false;
  bool _voiceAvailable = true;
  bool _isImportingDoc = false;

  /// Picks a .docx/.doc/.txt/.md/.csv/.rtf file and fills the field with its
  /// extracted plain-text content.
  Future<void> _importDocument() async {
    if (_isImportingDoc) return;
    setState(() => _isImportingDoc = true);
    try {
      final outcome = await DocxImportService.pickAndExtract(context);
      if (!mounted) return;
      switch (outcome) {
        case DocxImportSuccess(:final result):
          _controller.text = result.text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: result.text.length),
          );
          widget.onChanged(result.text);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Imported ${result.wordCount} words from ${result.fileName}'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        case DocxImportError(:final reason, :final message):
          if (reason == DocxImportFailure.cancelledByUser) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Import failed: $reason'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isImportingDoc = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Use AutoBulletTextController for list fields (blockers, nextSteps, etc.)
    // Use regular TextEditingController for prose fields (description, notes)
    if (widget.isListField) {
      _controller = AutoBulletTextController(
          text: widget.value.isEmpty ? '' : widget.value);
    } else {
      _controller = TextEditingController(text: widget.value);
    }
    _focusNode.addListener(_handleFocusChange);
    _initVoice();
  }

  Future<void> _initVoice() async {
    final available = await _voiceService.initialize();
    if (mounted && available != _voiceAvailable) {
      setState(() => _voiceAvailable = available);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      _cleanupVoiceSubs();
      if (mounted) setState(() => _isListening = false);
    } else {
      final started = await _voiceService.startListening(
        existingText: _controller.text,
      );
      if (!started) return;

      _voiceResultSub = _voiceService.onResult.listen((result) {
        if (!mounted) return;
        _controller.text = result.text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: result.text.length),
        );
        widget.onChanged(result.text);
        if (result.isFinal) {
          if (mounted) setState(() => _isListening = false);
          _cleanupVoiceSubs();
        }
      });

      _voiceStatusSub = _voiceService.onStatusChanged.listen((status) {
        if (status == VoiceStatus.stopped || status == VoiceStatus.error) {
          if (mounted) setState(() => _isListening = false);
          _cleanupVoiceSubs();
        }
      });

      if (mounted) setState(() => _isListening = true);
    }
  }

  void _cleanupVoiceSubs() {
    _voiceResultSub?.cancel();
    _voiceResultSub = null;
    _voiceStatusSub?.cancel();
    _voiceStatusSub = null;
  }

  @override
  void didUpdateWidget(InlineEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _controller.text = widget.value;
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      setState(() => _isEditing = false);
      widget.onChanged(_controller.text);
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.value;
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _cleanupVoiceSubs();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always show the mic button — even if the browser doesn't support
    // voice input. Tapping it on an unsupported browser shows a helpful
    // message instead of silently failing.
    final voiceEnabled = widget.enableVoice;

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action icons above field
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showRegenerate)
                IconButton(
                  icon: widget.isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD97706)),
                        )
                      : const Icon(Icons.auto_awesome,
                          size: 16, color: Color(0xFF64748B)),
                  onPressed:
                      widget.isRegenerating ? null : widget.onRegenerate,
                  tooltip: 'Regenerate',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (widget.showUndo)
                IconButton(
                  icon: Icon(
                    Icons.undo,
                    size: 16,
                    color: widget.canUndo
                        ? const Color(0xFF64748B)
                        : const Color(0xFFD1D5DB),
                  ),
                  onPressed: widget.canUndo ? widget.onUndo : null,
                  tooltip: 'Undo',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (voiceEnabled) _buildMicIcon(),
              if (widget.enableDocxImport)
                IconButton(
                  icon: _isImportingDoc
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0EA5E9),
                          ),
                        )
                      : const Icon(Icons.upload_file,
                          size: 16, color: Color(0xFF0EA5E9)),
                  onPressed: _isImportingDoc ? null : _importDocument,
                  tooltip: 'Import from .docx / .doc',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          // Text field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: widget.isProseField ? null : widget.maxLines,
            textAlign: widget.textAlign,
            style: widget.style ??
                const TextStyle(fontSize: 13, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFFFFD700), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFFFFD700), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
            onSubmitted: (_) {
              _focusNode.unfocus();
            },
          ),
        ],
      );
    }

    // Display mode - clickable text
    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value.isEmpty ? widget.hint : widget.value,
                style: widget.value.isEmpty
                    ? (widget.style?.copyWith(color: Colors.grey.shade400) ??
                        TextStyle(fontSize: 13, color: Colors.grey.shade400))
                    : (widget.style ??
                        const TextStyle(
                            fontSize: 13, color: Color(0xFF111827))),
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (voiceEnabled && !_isListening)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(Icons.mic_none_outlined,
                    size: 12, color: Colors.grey.shade400),
              ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildMicIcon() {
    final iconColor = widget.voiceIconColor ?? const Color(0xFFFFB800);

    if (_isListening) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.mic, color: iconColor, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: _toggleVoiceInput,
          tooltip: 'Stop voice input',
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.mic_none_outlined, color: iconColor, size: 14),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: _toggleVoiceInput,
      tooltip: 'Voice input',
    );
  }
}
