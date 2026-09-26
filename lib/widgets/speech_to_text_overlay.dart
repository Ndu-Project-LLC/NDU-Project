import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/providers/display_preferences_provider.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:provider/provider.dart';

/// Adds a contextual dictation action to standard Flutter text inputs that do
/// not already provide their own voice-input control.
class SpeechToTextOverlay extends StatefulWidget {
  const SpeechToTextOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SpeechToTextOverlay> createState() => _SpeechToTextOverlayState();
}

class _SpeechToTextOverlayState extends State<SpeechToTextOverlay> {
  final VoiceInputService _voiceService = VoiceInputService.instance;
  EditableTextState? _focusedField;
  StreamSubscription<VoiceResult>? _resultSubscription;
  StreamSubscription<VoiceStatus>? _statusSubscription;
  bool _isListening = false;
  bool _starting = false;
  int _refreshGeneration = 0;

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
    });
  }

  void _updateFocusedField() {
    if (!mounted) return;
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
    setState(() => _focusedField = next);
    if (next == null && _isListening) _stopListening();
  }

  Future<void> _toggleListening() async {
    if (!speechToTextEnabledFor(context)) return;
    if (_isListening) {
      await _stopListening();
      return;
    }
    final field = _focusedField;
    if (field == null || _starting) return;

    setState(() => _starting = true);
    try {
      final allowed = await requestMicrophonePermission(context);
      if (!allowed || !mounted || _focusedField != field) return;

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
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (enabled && _focusedField != null)
          Positioned(
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Semantics(
                button: true,
                label: _isListening ? 'Stop dictation' : 'Dictate into field',
                child: FloatingActionButton.extended(
                  heroTag: 'global-speech-to-text',
                  onPressed: _starting ? null : _toggleListening,
                  backgroundColor: _isListening
                      ? Theme.of(context).colorScheme.error
                      : const Color(0xFFFFB800),
                  foregroundColor:
                      _isListening ? Colors.white : const Color(0xFF1F2937),
                  icon: _starting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isListening ? Icons.stop : Icons.mic_none),
                  label: Text(_isListening ? 'Stop dictation' : 'Dictate'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
