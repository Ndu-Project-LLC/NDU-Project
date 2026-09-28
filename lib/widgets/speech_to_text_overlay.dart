import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ndu_project/providers/display_preferences_provider.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:provider/provider.dart';

/// Adds a contextual dictation action to standard Flutter text inputs that do
/// not already provide their own voice-input control.
///
/// The control is rendered **inline inside the focused text field**: a compact
/// "Dictate" pill anchored to the field's right edge that follows the field
/// wherever it goes — scrolling lists, dialogs animating in, keyboard-driven
/// layout shifts — instead of floating in the corner of the screen. Fields
/// that already ship their own microphone action opt out through
/// [SpeechInputFieldMarker], so a field never shows two dictation controls.
class SpeechToTextOverlay extends StatefulWidget {
  const SpeechToTextOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SpeechToTextOverlay> createState() => _SpeechToTextOverlayState();
}

class _SpeechToTextOverlayState extends State<SpeechToTextOverlay> {
  /// Height of the inline pill. Short enough to sit comfortably inside
  /// compact single-line fields (40px tall) without touching their borders.
  static const double _pillHeight = 30;

  /// Gap kept between the pill's trailing edge and the field's text-area
  /// edge, so the pill reads as part of the field rather than as a sticker.
  static const double _pillTrailingInset = 6;

  /// How quickly the pill glides when focus moves to another field.
  static const Duration _repositionDuration = Duration(milliseconds: 160);

  final VoiceInputService _voiceService = VoiceInputService.instance;
  final GlobalKey _overlayKey = GlobalKey();
  EditableTextState? _focusedField;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _starting = false;

  /// True while the microphone permission dialog is on screen. The dialog
  /// borrows focus from the field that asked for it, which would otherwise
  /// make us drop the field (and cancel dictation) the moment the user taps
  /// "Allow". While this flag is set, focus changes are ignored and the pill
  /// hides behind the dialog.
  bool _permissionPending = false;
  int _refreshGeneration = 0;

  /// Geometry of the focused field's text area in overlay-local coordinates,
  /// the overlay's own size, and the height of the field's first line. Used
  /// to anchor the pill inside the field. Measured after layout — never
  /// during build — so the render tree is only read when it is settled.
  Rect? _fieldRect;
  Size? _overlaySize;
  double _lineHeight = 16;
  bool _rectSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFocusedField());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _cancelSubscriptions();
    super.dispose();
  }

  void _handleFocusChange() => _refreshFocusedField();

  void _refreshFocusedField() {
    final generation = ++_refreshGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _refreshGeneration) return;
      _updateFocusedField();
      _scheduleRectSync();
    });
  }

  void _updateFocusedField() {
    if (!mounted) return;
    // The permission dialog owns focus while it is open; keep the field that
    // requested it so dictation can start as soon as the user allows.
    if (_permissionPending) return;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editable = focusContext?.findAncestorStateOfType<EditableTextState>();
    final field = editable?.widget;
    final marker = editable?.context
        .getInheritedWidgetOfExactType<SpeechInputFieldMarker>();
    final eligible = editable != null &&
        field != null &&
        !field.obscureText &&
        !field.readOnly &&
        field.focusNode.hasFocus &&
        (marker == null || (marker.voiceAllowed && !marker.hasVoiceControl));
    final next = eligible ? editable : null;
    if (_focusedField == next) return;
    final rect = next == null ? null : _measureField(next);
    setState(() {
      _focusedField = next;
      _fieldRect = rect;
    });
    if (next == null && _isListening) _stopListening();
  }

  /// Measures [field]'s text area (and this overlay) in overlay-local
  /// coordinates so the pill can be positioned inside the field. Returns
  /// null while either render box has not been laid out yet.
  Rect? _measureField(EditableTextState field) {
    final overlayBox = _overlayKey.currentContext?.findRenderObject();
    final fieldBox = field.context.findRenderObject();
    if (overlayBox is! RenderBox || fieldBox is! RenderBox) return null;
    if (!overlayBox.hasSize || !fieldBox.hasSize) return null;
    _overlaySize = overlayBox.size;
    final origin = fieldBox.localToGlobal(Offset.zero) -
        overlayBox.localToGlobal(Offset.zero);
    final style = field.widget.style;
    _lineHeight = (style.fontSize ?? 14.0) * (style.height ?? 1.35);
    return origin & fieldBox.size;
  }

  /// Keeps the pill glued to the field: geometry is re-checked after every
  /// frame rendered while a field is focused (scrolls, dialog entrances,
  /// window resizes), and setState only fires when the field actually moved.
  /// With the app idle no frames are produced, so this costs nothing.
  void _scheduleRectSync() {
    if (_rectSyncScheduled) return;
    _rectSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectSyncScheduled = false;
      if (!mounted) return;
      final field = _focusedField;
      if (field == null) {
        if (_fieldRect != null) setState(() => _fieldRect = null);
        return;
      }
      final rect = _measureField(field);
      if (rect != _fieldRect) setState(() => _fieldRect = rect);
      _scheduleRectSync();
    });
  }

  Future<void> _toggleListening() async {
    if (!speechToTextEnabledFor(context)) return;
    if (_isListening) {
      await _stopListening();
      return;
    }
    final field = _focusedField;
    if (field == null || _starting) return;

    setState(() {
      _starting = true;
      _permissionPending = true;
    });
    try {
      bool allowed = false;
      try {
        allowed = await requestMicrophonePermission(context);
      } finally {
        _permissionPending = false;
        // Re-sync with live focus — the dialog borrowed it while we were
        // ignoring focus changes — and bring the pill back on screen.
        _refreshFocusedField();
        if (mounted) setState(() {});
      }
      if (!allowed || !mounted || _focusedField != field) return;

      // Hand focus straight back to the field being dictated so the caret
      // (and the inline pill) return to where the words will land.
      if (!field.widget.focusNode.hasFocus) {
        field.widget.focusNode.requestFocus();
      }

      final controller = field.widget.controller;
      _resultSubscription = _voiceService.onResult.listen((result) {
        if (!mounted || _focusedField != field) return;
        final selection = TextSelection.collapsed(offset: result.text.length);
        field.updateEditingValue(
          TextEditingValue(text: result.text, selection: selection),
        );
      });
      _statusSubscription = _voiceService.onStatusChanged.listen((status) {
        if (status == VoiceStatus.stopped || status == VoiceStatus.error) {
          if (mounted) setState(() => _isListening = false);
          _cancelSubscriptions();
        }
      });

      final started = await _voiceService.startListening(
        existingText: controller.text,
      );
      if (!started) {
        _cancelSubscriptions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available right now.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _isListening = true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    _cancelSubscriptions();
    if (mounted) setState(() => _isListening = false);
  }

  void _cancelSubscriptions() {
    _resultSubscription?.cancel();
    _resultSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<DisplayPreferencesProvider, bool>(
      (preferences) => preferences.speechToTextEnabled,
    );
    if (!enabled && _isListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isListening) _stopListening();
      });
    }

    final showInlineControl = enabled &&
        _focusedField != null &&
        _fieldRect != null &&
        _overlaySize != null &&
        !_permissionPending;

    return Stack(
      key: _overlayKey,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showInlineControl) _buildInlineDictation(),
      ],
    );
  }

  /// Anchors the pill inside the focused field's right edge, on its first
  /// line: that is simply the vertical centre of a single-line field, and the
  /// top line of a multiline one, so the pill never drifts down into the body
  /// of a long text. Returns nothing while the field is scrolled out of view.
  Widget _buildInlineDictation() {
    final rect = _fieldRect!;
    final overlaySize = _overlaySize!;

    final anchorY = rect.top + math.min(rect.height, _lineHeight) / 2;
    final top = anchorY - _pillHeight / 2;

    final onScreen = rect.right > 12 &&
        rect.left < overlaySize.width - 12 &&
        top > -_pillHeight &&
        top < overlaySize.height;
    if (!onScreen) return const SizedBox.shrink();

    return AnimatedPositioned(
      duration: _repositionDuration,
      curve: Curves.easeOutCubic,
      right: math.max(
        4.0,
        overlaySize.width - (rect.right - _pillTrailingInset),
      ),
      top: top,
      height: _pillHeight,
      child: _buildDictationPill(),
    );
  }

  Widget _buildDictationPill() {
    final listening = _isListening;
    final foreground =
        listening ? const Color(0xFFDC2626) : const Color(0xFF92400E);
    final background =
        listening ? const Color(0xFFFFF1F2) : Colors.white;
    final borderColor =
        listening ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A);

    return ExcludeFocus(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: listening ? 'Stop dictation' : 'Dictate into this field',
          child: Semantics(
            button: true,
            label: listening ? 'Stop dictation' : 'Dictate into field',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _starting ? null : _toggleListening,
                borderRadius: BorderRadius.circular(_pillHeight / 2),
                child: AnimatedContainer(
                  duration: _repositionDuration,
                  curve: Curves.easeOutCubic,
                  height: _pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(_pillHeight / 2),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Deliberately not a spinner: an indefinite animation
                      // would keep the widget tree scheduling frames.
                      Icon(
                        listening ? Icons.mic : Icons.mic_none_outlined,
                        size: 15,
                        color: _starting
                            ? foreground.withValues(alpha: 0.45)
                            : foreground,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        listening ? 'Stop' : 'Dictate',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
