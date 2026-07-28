import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the application theme mode (Light / Dark / System) with
/// SharedPreferences persistence so the user's choice survives restarts.
class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'pref_theme_mode';

  /// The current effective theme mode.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Short label for UI display.
  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // ── Initialisation ────────────────────────────────────────────────

  /// Load the persisted choice (or default to 'system').
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey) ?? 'system';
      _themeMode = _parseMode(raw);
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  // ── Mutators ──────────────────────────────────────────────────────

  /// Set the theme mode and persist the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _labelFor(mode));
    } catch (_) {
      // Silently ignore persistence failures – the in-memory value is
      // already updated and will be used for the remainder of the session.
    }
  }

  /// Convenience: set from a string label ('light', 'dark', 'system').
  Future<void> setThemeModeLabel(String label) =>
      setThemeMode(_parseMode(label));

  // ── Helpers ───────────────────────────────────────────────────────

  static ThemeMode _parseMode(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
