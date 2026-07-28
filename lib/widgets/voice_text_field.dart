import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:ndu_project/services/docx_import_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

/// A drop-in replacement for [TextField] that adds a microphone button
/// for voice-to-text input.
///
/// The mic icon appears as a suffixIcon inside the text field's decoration.
/// When tapped, it requests microphone permission and starts listening.
/// Recognized speech is appended to the field's text.
///
/// Set [enableVoice] to false to hide the mic button (defaults to true).
class VoiceTextField extends StatefulWidget {
  const VoiceTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onTap,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20),
    this.enableInteractiveSelection = true,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const [],
    this.enableVoice = true,
    this.voiceIconColor,
    this.onTapOutside,
    this.enableDocxImport = false,
    this.docxImportIconColor,
    this.docxImportTooltip = 'Import from .docx / .doc',
    this.enableKazAi = true,
    this.kazAiLabel,
    this.enableTextFormatting = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final bool enableInteractiveSelection;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String> autofillHints;

  /// Whether to show the voice input mic button. Defaults to true.
  final bool enableVoice;

  /// Color of the mic icon. Defaults to brand yellow if not specified.
  final Color? voiceIconColor;

  /// Whether to show the document-import button next to the mic icon.
  /// When enabled, the user can tap the icon to pick a .docx / .doc / .txt /
  /// .md / .csv / .rtf file and have its extracted text fill the field.
  /// Defaults to true.
  final bool enableDocxImport;

  /// Color of the document-import icon. Defaults to a teal/brand color.
  final Color? docxImportIconColor;

  /// Tooltip shown on the import icon.
  final String docxImportTooltip;

  /// Whether to show the KAZ AI button. Defaults to true.
  final bool enableKazAi;

  /// Optional label for AI context.
  final String? kazAiLabel;

  /// Whether to show the text formatting toolbar for multi-line fields.
  final bool enableTextFormatting;

  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField> {
  late TextEditingController _controller;
  final VoiceInputService _voiceService = VoiceInputService.instance;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _voiceAvailable = true;
  bool _isImportingDoc = false;
  bool _isGeneratingAi = false;

  /// Generates AI content for this field using OpenAiServiceSecure.
  Future<void> _generateWithKazAi() async {
    if (_isGeneratingAi) return;
    setState(() => _isGeneratingAi = true);
    try {
      final openai = OpenAiServiceSecure();
      final label = widget.kazAiLabel ?? 'this field';
      final result = await openai.generateCompletion(
        'Suggest a concise, realistic value for the "$label" field in a '
        'project management application. Return ONLY the text value '
        '(no JSON, no markdown, no explanation).',
        maxTokens: 200,
        temperature: 0.6,
      );
      final cleaned = result.trim();
      if (cleaned.isNotEmpty && mounted) {
        _controller.text = cleaned;
        widget.onChanged?.call(cleaned);
        setState(() {});
      }
    } catch (e) {
      debugPrint('[VoiceTextField] KAZ AI failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KAZ AI failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _isGeneratingAi = false);
  }

  /// Picks a .docx/.doc/.txt/.md/.csv/.rtf file and fills the field with its
  /// extracted plain-text content. Shows a loading spinner on the import
  /// icon during parsing and a success/error SnackBar afterwards.
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
  void didUpdateWidget(VoiceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? TextEditingController();
    }
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await _voiceService.initialize();
      if (mounted && available != _voiceAvailable) {
        setState(() => _voiceAvailable = available);
      }
    } catch (e) {
      debugPrint('[VoiceTextField] Availability check failed: $e');
      if (mounted) {
        setState(() => _voiceAvailable = false);
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      _cleanupSubscriptions();
      if (mounted) setState(() => _isListening = false);
    } else {
      // ── Microphone permission dialog ──
      // Show a world-class permission request dialog before accessing the mic.
      final shouldProceed = await showMicrophonePermissionDialog(context);
      if (!shouldProceed || !mounted) return;

      final started = await _voiceService.startListening(
        existingText: _controller.text,
      );
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb
                  ? 'Voice input unavailable. Use Chrome/Edge/Safari over HTTPS and allow mic access. Firefox is not supported.'
                  : 'Speech recognition is not available on this device.'),
              duration: const Duration(seconds: 3),
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
          // Show user-facing error message when voice input fails
          if (status == VoiceStatus.error && mounted) {
            final errorMsg = _voiceService.lastErrorMessage;
            if (errorMsg.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFFEF4444),
                ),
              );
            }
          }
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
    // Only dispose the controller if we created it
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always show the mic button when enableVoice is true and the field
    // isn't a password field — even if the browser doesn't support voice
    // input. Tapping the mic on an unsupported browser shows a helpful
    // message instead of silently failing.
    final voiceEnabled = widget.enableVoice && !widget.obscureText;
    final docxEnabled = widget.enableDocxImport && !widget.obscureText;
    final kazAiEnabled = widget.enableKazAi && !widget.obscureText && !widget.readOnly;
    final effectiveDecoration = _buildDecoration(voiceEnabled, docxEnabled, kazAiEnabled);

    // Show text formatting toolbar only for multi-line fields
    final showToolbar = widget.enableTextFormatting &&
        !widget.obscureText &&
        !widget.readOnly &&
        (widget.maxLines == null || widget.maxLines! > 1);

    final textField = TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: effectiveDecoration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      textDirection: widget.textDirection,
      readOnly: widget.readOnly,
      showCursor: widget.showCursor,
      autofocus: widget.autofocus,
      obscuringCharacter: widget.obscuringCharacter,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      enableSuggestions: widget.enableSuggestions,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      maxLength: widget.maxLength,
      maxLengthEnforcement: widget.maxLengthEnforcement,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onTapOutside: widget.onTapOutside,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      cursorWidth: widget.cursorWidth,
      cursorHeight: widget.cursorHeight,
      cursorRadius: widget.cursorRadius,
      cursorColor: widget.cursorColor,
      keyboardAppearance: widget.keyboardAppearance,
      scrollPadding: widget.scrollPadding,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      scrollController: widget.scrollController,
      scrollPhysics: widget.scrollPhysics,
      autofillHints: widget.autofillHints,
    );

    if (showToolbar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormattingToolbar(controller: _controller),
          const SizedBox(height: 2),
          textField,
        ],
      );
    }
    return textField;
  }

  InputDecoration _buildDecoration(bool voiceEnabled, bool docxEnabled, bool kazAiEnabled) {
    final base = widget.decoration ?? const InputDecoration();

    final icons = <Widget>[];
    if (docxEnabled) icons.add(_buildDocxImportIcon());
    if (voiceEnabled) icons.add(_buildMicIcon());
    if (kazAiEnabled) icons.add(_buildKazAiIcon());
    if (kazAiEnabled && _controller.text.isNotEmpty) icons.add(_buildClearIcon());

    if (icons.isEmpty) return base;

    final existingSuffix = base.suffixIcon;
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

    return base.copyWith(suffixIcon: suffixWidget);
  }

  Widget _buildKazAiIcon() {
    if (_isGeneratingAi) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      icon: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
      tooltip: 'KAZ AI',
      onPressed: _generateWithKazAi,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 16,
    );
  }

  Widget _buildClearIcon() {
    return IconButton(
      icon: const Icon(Icons.delete_sweep, color: Color(0xFFEF4444), size: 18),
      tooltip: 'Clear all content',
      onPressed: () {
        _controller.clear();
        widget.onChanged?.call('');
        setState(() {});
      },
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 16,
    );
  }

  Widget _buildDocxImportIcon() {
    final iconColor =
        widget.docxImportIconColor ?? const Color(0xFF0EA5E9);
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor,
            ),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        Icons.upload_file,
        color: iconColor,
        size: 18,
      ),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _importDocument,
      tooltip: widget.docxImportTooltip,
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
          icon: Icon(
            Icons.mic,
            color: iconColor,
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _toggleVoiceInput,
          tooltip: 'Stop voice input',
        ),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.mic_none_outlined,
        color: iconColor,
        size: 18,
      ),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _toggleVoiceInput,
      tooltip: 'Voice input',
    );
  }
}

// ── World-class microphone permission dialog ──────────────────────────────
/// Shows a branded, friendly permission request dialog before accessing the
/// microphone. Returns true if the user grants permission, false otherwise.
///
/// Used by both [VoiceTextField] and [VoiceTextFormField] before starting
/// voice input.
Future<bool> showMicrophonePermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header with gradient + mic icon ──
              Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB800), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Microphone Access',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'KAZ AI wants to use your microphone for voice-to-text',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // ── Body: permission bullets ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPermissionBullet(
                      icon: Icons.record_voice_over_outlined,
                      text: 'Speak naturally — your voice will be converted to text in this field',
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionBullet(
                      icon: Icons.lock_outline,
                      text: 'Audio is processed securely and never stored or shared',
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionBullet(
                      icon: Icons.toggle_on_outlined,
                      text: 'You can stop voice input at any time by tapping the mic icon again',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFCD34D).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline,
                              size: 16, color: Color(0xFF92400E)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your browser will ask for mic permission after you tap "Allow".',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Footer: Don't Allow + Allow ──
              Container(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Don't Allow",
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        icon: const Icon(Icons.mic, size: 18),
                        label: const Text(
                          'Allow',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

Widget _buildPermissionBullet({required IconData icon, required String text}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFFD97706)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

/// A drop-in replacement for [TextFormField] that adds a microphone button
/// for voice-to-text input.
///
/// Identical API surface to TextFormField with an additional [enableVoice] param.
class VoiceTextFormField extends StatefulWidget {
  const VoiceTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLengthEnforcement,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20),
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.buildCounter,
    this.scrollPhysics,
    this.autofillHints = const [],
    this.autovalidateMode,
    this.scrollController,
    this.restorationId,
    this.enableVoice = true,
    this.voiceIconColor,
    this.enableDocxImport = false,
    this.docxImportIconColor,
    this.docxImportTooltip = 'Import from .docx / .doc',
    this.enableKazAi = true,
    this.kazAiLabel,
    this.enableTextFormatting = true,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final bool enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final InputCounterWidgetBuilder? buildCounter;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String> autofillHints;
  final AutovalidateMode? autovalidateMode;
  final ScrollController? scrollController;
  final String? restorationId;

  /// Whether to show the voice input mic button. Defaults to true.
  final bool enableVoice;

  /// Color of the mic icon. Defaults to brand yellow if not specified.
  final Color? voiceIconColor;

  /// Whether to show the document-import button next to the mic icon.
  /// When enabled, the user can tap the icon to pick a .docx / .doc / .txt /
  /// .md / .csv / .rtf file and have its extracted text fill the field.
  /// Defaults to true.
  final bool enableDocxImport;

  /// Color of the document-import icon. Defaults to a sky-blue brand color.
  final Color? docxImportIconColor;

  /// Tooltip shown on the import icon.
  final String docxImportTooltip;

  /// Whether to show the KAZ AI button. Defaults to true.
  final bool enableKazAi;

  /// Optional label for AI context.
  final String? kazAiLabel;

  /// Whether to show the text formatting toolbar for multi-line fields.
  final bool enableTextFormatting;

  @override
  State<VoiceTextFormField> createState() => _VoiceTextFormFieldState();
}

class _VoiceTextFormFieldState extends State<VoiceTextFormField> {
  late TextEditingController _controller;
  final VoiceInputService _voiceService = VoiceInputService.instance;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _voiceAvailable = true;
  bool _isImportingDoc = false;
  bool _isGeneratingAi = false;

  Future<void> _generateWithKazAi() async {
    if (_isGeneratingAi) return;
    setState(() => _isGeneratingAi = true);
    try {
      final openai = OpenAiServiceSecure();
      final label = widget.kazAiLabel ?? 'this field';
      final result = await openai.generateCompletion(
        'Suggest a concise, realistic value for the "$label" field in a '
        'project management application. Return ONLY the text value '
        '(no JSON, no markdown, no explanation).',
        maxTokens: 200,
        temperature: 0.6,
      );
      final cleaned = result.trim();
      if (cleaned.isNotEmpty && mounted) {
        _controller.text = cleaned;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KAZ AI failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _isGeneratingAi = false);
  }

  /// Picks a .docx/.doc/.txt/.md/.csv/.rtf file and fills the field with its
  /// extracted plain-text content. Shows a loading spinner on the import
  /// icon during parsing and a success/error SnackBar afterwards.
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
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _checkAvailability();
  }

  @override
  void didUpdateWidget(VoiceTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller =
          widget.controller ?? TextEditingController(text: widget.initialValue);
    } else if (widget.controller == null &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await _voiceService.initialize();
      if (mounted && available != _voiceAvailable) {
        setState(() => _voiceAvailable = available);
      }
    } catch (e) {
      debugPrint('[VoiceTextField] Availability check failed: $e');
      if (mounted) {
        setState(() => _voiceAvailable = false);
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      _cleanupSubscriptions();
      if (mounted) setState(() => _isListening = false);
    } else {
      // ── Microphone permission dialog ──
      // Show a world-class permission request dialog before accessing the mic.
      final shouldProceed = await showMicrophonePermissionDialog(context);
      if (!shouldProceed || !mounted) return;

      final started = await _voiceService.startListening(
        existingText: _controller.text,
      );
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb
                  ? 'Voice input unavailable. Use Chrome/Edge/Safari over HTTPS and allow mic access. Firefox is not supported.'
                  : 'Speech recognition is not available on this device.'),
              duration: const Duration(seconds: 3),
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
          // Show user-facing error message when voice input fails
          if (status == VoiceStatus.error && mounted) {
            final errorMsg = _voiceService.lastErrorMessage;
            if (errorMsg.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFFEF4444),
                ),
              );
            }
          }
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
    // Always show the mic button — even if the browser doesn't support
    // voice input. Tapping it on an unsupported browser shows a helpful
    // message instead of silently failing.
    final voiceEnabled = widget.enableVoice && !widget.obscureText;
    final docxEnabled = widget.enableDocxImport && !widget.obscureText;
    final kazAiEnabled = widget.enableKazAi && !widget.obscureText && !widget.readOnly;
    final effectiveDecoration =
        _buildDecoration(voiceEnabled, docxEnabled, kazAiEnabled);

    // Show text formatting toolbar only for multi-line fields
    final showToolbar = widget.enableTextFormatting &&
        !widget.obscureText &&
        !widget.readOnly &&
        (widget.maxLines == null || widget.maxLines! > 1);

    final textField = TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: effectiveDecoration,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      textDirection: widget.textDirection,
      readOnly: widget.readOnly,
      showCursor: widget.showCursor,
      autofocus: widget.autofocus,
      obscuringCharacter: widget.obscuringCharacter,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      enableSuggestions: widget.enableSuggestions,
      maxLengthEnforcement: widget.maxLengthEnforcement,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      onTapOutside: widget.onTapOutside,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onFieldSubmitted,
      onSaved: widget.onSaved,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      cursorWidth: widget.cursorWidth,
      cursorHeight: widget.cursorHeight,
      cursorRadius: widget.cursorRadius,
      cursorColor: widget.cursorColor,
      keyboardAppearance: widget.keyboardAppearance,
      scrollPadding: widget.scrollPadding,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      selectionControls: widget.selectionControls,
      buildCounter: widget.buildCounter,
      scrollPhysics: widget.scrollPhysics,
      autofillHints: widget.autofillHints,
      autovalidateMode: widget.autovalidateMode,
      scrollController: widget.scrollController,
      restorationId: widget.restorationId,
    );

    if (showToolbar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormattingToolbar(controller: _controller),
          const SizedBox(height: 2),
          textField,
        ],
      );
    }
    return textField;
  }

  InputDecoration _buildDecoration(bool voiceEnabled, bool docxEnabled, bool kazAiEnabled) {
    final base = widget.decoration ?? const InputDecoration();

    final icons = <Widget>[];
    if (docxEnabled) icons.add(_buildDocxImportIcon());
    if (voiceEnabled) icons.add(_buildMicIcon());
    if (kazAiEnabled) icons.add(_buildKazAiIcon());
    if (kazAiEnabled && _controller.text.isNotEmpty) icons.add(_buildClearIcon());

    if (icons.isEmpty) return base;

    final existingSuffix = base.suffixIcon;
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

    return base.copyWith(suffixIcon: suffixWidget);
  }


  Widget _buildKazAiIcon() {
    if (_isGeneratingAi) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      icon: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
      tooltip: 'KAZ AI',
      onPressed: _generateWithKazAi,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 16,
    );
  }

  Widget _buildClearIcon() {
    return IconButton(
      icon: const Icon(Icons.delete_sweep, color: Color(0xFFEF4444), size: 18),
      tooltip: 'Clear all content',
      onPressed: () {
        _controller.clear();
        setState(() {});
      },
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 16,
    );
  }

  Widget _buildDocxImportIcon() {
    final iconColor =
        widget.docxImportIconColor ?? const Color(0xFF0EA5E9);
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor,
            ),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        Icons.upload_file,
        color: iconColor,
        size: 18,
      ),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _importDocument,
      tooltip: widget.docxImportTooltip,
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
          icon: Icon(
            Icons.mic,
            color: iconColor,
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _toggleVoiceInput,
          tooltip: 'Stop voice input',
        ),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.mic_none_outlined,
        color: iconColor,
        size: 18,
      ),
      padding: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: _toggleVoiceInput,
      tooltip: 'Voice input',
    );
  }
}
