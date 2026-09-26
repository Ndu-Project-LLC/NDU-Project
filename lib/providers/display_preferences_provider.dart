import 'package:flutter/material.dart';
import 'package:ndu_project/services/voice_input_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application-wide display and accessibility preferences.
///
/// The provider is observed at the app root so changes from Settings apply
/// immediately to every route and remain in effect after restarting the app.
class DisplayPreferencesProvider extends ChangeNotifier {
  static const String _fontSizeKey = 'pref_font_size';
  static const String _compactModeKey = 'pref_compact_mode';
  static const String _reduceAnimationsKey = 'pref_reduce_animations';
  static const String _speechToTextKey = 'pref_speech_to_text';

  String _fontSize = 'medium';
  bool _compactMode = false;
  bool _reduceAnimations = false;
  bool _speechToTextEnabled = true;

  String get fontSize => _fontSize;
  bool get compactMode => _compactMode;
  bool get reduceAnimations => _reduceAnimations;
  bool get speechToTextEnabled => _speechToTextEnabled;

  double get textScaleFactor => switch (_fontSize) {
        'small' => 0.9,
        'large' => 1.15,
        _ => 1.0,
      };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontSize = _normalizeFontSize(prefs.getString(_fontSizeKey));
      _compactMode = prefs.getBool(_compactModeKey) ?? false;
      _reduceAnimations = prefs.getBool(_reduceAnimationsKey) ?? false;
      _speechToTextEnabled = prefs.getBool(_speechToTextKey) ?? true;
    } catch (_) {
      // Keep defaults when local preference storage is temporarily unavailable.
    }
    notifyListeners();
  }

  Future<void> setFontSize(String value) async {
    final normalized = _normalizeFontSize(value);
    if (_fontSize == normalized) return;
    _fontSize = normalized;
    notifyListeners();
    await _persist((prefs) => prefs.setString(_fontSizeKey, normalized));
  }

  Future<void> setCompactMode(bool value) async {
    if (_compactMode == value) return;
    _compactMode = value;
    notifyListeners();
    await _persist((prefs) => prefs.setBool(_compactModeKey, value));
  }

  Future<void> setReduceAnimations(bool value) async {
    if (_reduceAnimations == value) return;
    _reduceAnimations = value;
    notifyListeners();
    await _persist((prefs) => prefs.setBool(_reduceAnimationsKey, value));
  }

  Future<void> setSpeechToTextEnabled(bool value) async {
    if (_speechToTextEnabled == value) return;
    // Update the global state before awaiting native shutdown so the UI reacts
    // immediately and no new dictation can be started in the meantime.
    _speechToTextEnabled = value;
    notifyListeners();
    if (!value) await VoiceInputService.instance.stopListening();
    await _persist((prefs) => prefs.setBool(_speechToTextKey, value));
  }

  Future<void> _persist(
    Future<bool> Function(SharedPreferences prefs) write,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {
      // The in-memory update is still active for this app session.
    }
  }

  static String _normalizeFontSize(String? value) {
    return switch (value) {
      'small' => 'small',
      'large' => 'large',
      _ => 'medium',
    };
  }
}

/// Read the shared speech-to-text preference from any widget context.
bool speechToTextEnabledFor(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<DisplayPreferencesProvider>(context, listen: listen)
        .speechToTextEnabled;
  } catch (_) {
    // Some isolated dialogs/tests are rendered outside MyApp's provider tree.
    return true;
  }
}
