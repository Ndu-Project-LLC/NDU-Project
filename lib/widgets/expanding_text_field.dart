import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:ndu_project/services/docx_import_service.dart';

/// A drop-in TextField that grows vertically as the user types,
/// with optional voice-to-text input via a microphone button.
/// - No internal scrolling; the enclosing page scrolls instead.
/// - By default starts with [minLines] and expands with content (maxLines=null).
/// - Use for multiline content such as notes, descriptions, comments.
/// - Set [enableVoice] to false to hide the mic button (defaults to true).
class ExpandingTextField extends StatefulWidget {
  const ExpandingTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.minLines = 1,
    this.readOnly = false,
    this.onChanged,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.decoration,
    this.style,
    this.enabled,
    this.onEditingComplete,
    this.onSubmitted,
    this.enableVoice = true,
    this.voiceIconColor,
    this.enableDocxImport = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int minLines;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool? enabled;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;

  /// Whether to show the voice input mic button. Defaults to true.
  final bool enableVoice;

  /// Color of the mic icon. Defaults to brand yellow.
  final Color? voiceIconColor;

  /// Whether to show the document-import button. Defaults to true.
  final bool enableDocxImport;

  @override
  State<ExpandingTextField> createState() => _ExpandingTextFieldState();
}

class _ExpandingTextFieldState extends State<ExpandingTextField> {
  late TextEditingController _controller;
  final VoiceInputService _voiceService = VoiceInputService.instance;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _voiceAvailable = true;
  bool _isImportingDoc = false;

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
          widget.onChanged?.call(result.text);
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
    _controller = widget.controller ?? TextEditingController();
    _checkAvailability();
  }

  @override
  void didUpdateWidget(ExpandingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? TextEditingController();
    }
  }

  Future<void> _checkAvailability() async {
    final available = await _voiceService.initialize();
    if (mounted && available != _voiceAvailable) {
      setState(() => _voiceAvailable = available);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      _cleanupSubscriptions();
      if (mounted) setState(() => _isListening = false);
    } else {
      final started = await _voiceService.startListening(
        existingText: _controller.text,
      );
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available on this device.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      _resultSubscription = _voiceService.onResult.listen((result) {
        if (!mounted) return;
        final text = result.text;
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        widget.onChanged?.call(text);

        if (result.isFinal) {
          if (mounted) setState(() => _isListening = false);
          _cleanupSubscriptions();
        }
      });

      _statusSubscription = _voiceService.onStatusChanged.listen((status) {
        if (status == VoiceStatus.stopped || status == VoiceStatus.error) {
          if (mounted) setState(() => _isListening = false);
          _cleanupSubscriptions();
        }
      });

      if (mounted) setState(() => _isListening = true);
    }
  }

  void _cleanupSubscriptions() {
    _resultSubscription?.cancel();
    _resultSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceEnabled = widget.enableVoice && _voiceAvailable;
    final docxEnabled = widget.enableDocxImport;
    final InputDecoration baseDecoration = widget.decoration ?? const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    );

    final effectiveDecoration =
        _buildDecoration(baseDecoration, voiceEnabled, docxEnabled);

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      minLines: widget.minLines,
      maxLines: null, // allow vertical growth with content
      decoration: effectiveDecoration,
      style: widget.style,
      enabled: widget.enabled,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
    );
  }

  InputDecoration _buildDecoration(
      InputDecoration base, bool voiceEnabled, bool docxEnabled) {
    final decorated = base.copyWith(
      hintText: widget.hintText ?? base.hintText,
      labelText: widget.labelText ?? base.labelText,
    );

    final icons = <Widget>[];
    if (docxEnabled) icons.add(_buildDocxImportIcon());
    if (voiceEnabled) icons.add(_buildMicIcon());

    if (icons.isEmpty) return decorated;

    final existingSuffix = decorated.suffixIcon;
    Widget suffixWidget;
    final merged = icons.length == 1
        ? icons.first
        : Row(mainAxisSize: MainAxisSize.min, children: icons);

    if (existingSuffix != null) {
      suffixWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [existingSuffix, merged],
      );
    } else {
      suffixWidget = merged;
    }

    return decorated.copyWith(suffixIcon: suffixWidget);
  }

  Widget _buildDocxImportIcon() {
    const iconColor = Color(0xFF0EA5E9);
    if (_isImportingDoc) {
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
          ),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.upload_file, color: iconColor, size: 18),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _importDocument,
      tooltip: 'Import from .docx / .doc',
    );
  }

  Widget _buildMicIcon() {
    final iconColor = widget.voiceIconColor ?? const Color(0xFFFFB800);

    if (_isListening) {
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.mic, color: iconColor, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _toggleVoiceInput,
          tooltip: 'Stop voice input',
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.mic_none_outlined, color: iconColor, size: 18),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _toggleVoiceInput,
      tooltip: 'Voice input',
    );
  }
}

/// A Form-compatible variant using TextFormField, with voice-to-text support.
class ExpandingTextFormField extends StatefulWidget {
  const ExpandingTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.minLines = 1,
    this.readOnly = false,
    this.onChanged,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.decoration,
    this.style,
    this.enabled,
    this.validator,
    this.onSaved,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.autovalidateMode,
    this.enableVoice = true,
    this.voiceIconColor,
    this.enableDocxImport = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int minLines;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool? enabled;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;

  /// Whether to show the voice input mic button. Defaults to true.
  final bool enableVoice;

  /// Color of the mic icon. Defaults to brand yellow.
  final Color? voiceIconColor;

  /// Whether to show the document-import button. Defaults to true.
  final bool enableDocxImport;

  @override
  State<ExpandingTextFormField> createState() => _ExpandingTextFormFieldState();
}

class _ExpandingTextFormFieldState extends State<ExpandingTextFormField> {
  late TextEditingController _controller;
  final VoiceInputService _voiceService = VoiceInputService.instance;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _voiceAvailable = true;
  bool _isImportingDoc = false;

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
          widget.onChanged?.call(result.text);
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
    _controller = widget.controller ?? TextEditingController();
    _checkAvailability();
  }

  @override
  void didUpdateWidget(ExpandingTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? TextEditingController();
    }
  }

  Future<void> _checkAvailability() async {
    final available = await _voiceService.initialize();
    if (mounted && available != _voiceAvailable) {
      setState(() => _voiceAvailable = available);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      _cleanupSubscriptions();
      if (mounted) setState(() => _isListening = false);
    } else {
      final started = await _voiceService.startListening(
        existingText: _controller.text,
      );
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available on this device.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      _resultSubscription = _voiceService.onResult.listen((result) {
        if (!mounted) return;
        final text = result.text;
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        widget.onChanged?.call(text);

        if (result.isFinal) {
          if (mounted) setState(() => _isListening = false);
          _cleanupSubscriptions();
        }
      });

      _statusSubscription = _voiceService.onStatusChanged.listen((status) {
        if (status == VoiceStatus.stopped || status == VoiceStatus.error) {
          if (mounted) setState(() => _isListening = false);
          _cleanupSubscriptions();
        }
      });

      if (mounted) setState(() => _isListening = true);
    }
  }

  void _cleanupSubscriptions() {
    _resultSubscription?.cancel();
    _resultSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceEnabled = widget.enableVoice && _voiceAvailable;
    final docxEnabled = widget.enableDocxImport;
    final InputDecoration baseDecoration = widget.decoration ?? const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    );

    final effectiveDecoration =
        _buildDecoration(baseDecoration, voiceEnabled, docxEnabled);

    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      minLines: widget.minLines,
      maxLines: null,
      decoration: effectiveDecoration,
      style: widget.style,
      enabled: widget.enabled,
      validator: widget.validator,
      onSaved: widget.onSaved,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onFieldSubmitted,
      autovalidateMode: widget.autovalidateMode,
    );
  }

  InputDecoration _buildDecoration(
      InputDecoration base, bool voiceEnabled, bool docxEnabled) {
    final decorated = base.copyWith(
      hintText: widget.hintText ?? base.hintText,
      labelText: widget.labelText ?? base.labelText,
    );

    final icons = <Widget>[];
    if (docxEnabled) icons.add(_buildDocxImportIcon());
    if (voiceEnabled) icons.add(_buildMicIcon());

    if (icons.isEmpty) return decorated;

    final existingSuffix = decorated.suffixIcon;
    Widget suffixWidget;
    final merged = icons.length == 1
        ? icons.first
        : Row(mainAxisSize: MainAxisSize.min, children: icons);

    if (existingSuffix != null) {
      suffixWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [existingSuffix, merged],
      );
    } else {
      suffixWidget = merged;
    }

    return decorated.copyWith(suffixIcon: suffixWidget);
  }

  Widget _buildDocxImportIcon() {
    const iconColor = Color(0xFF0EA5E9);
    if (_isImportingDoc) {
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
          ),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.upload_file, color: iconColor, size: 18),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _importDocument,
      tooltip: 'Import from .docx / .doc',
    );
  }

  Widget _buildMicIcon() {
    final iconColor = widget.voiceIconColor ?? const Color(0xFFFFB800);

    if (_isListening) {
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.mic, color: iconColor, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _toggleVoiceInput,
          tooltip: 'Stop voice input',
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.mic_none_outlined, color: iconColor, size: 18),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _toggleVoiceInput,
      tooltip: 'Voice input',
    );
  }
}
