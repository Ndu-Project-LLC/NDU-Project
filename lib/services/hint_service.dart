import 'package:shared_preferences/shared_preferences.dart';

/// Stores hint viewing state + global behavior.
///
/// Requirements:
/// - Hints are compulsory the first time a page is viewed.
/// - Optional global setting: "Disable hints for pages I've viewed before"
///   (when enabled, hints won't auto pop for previously viewed pages, but will for new pages).
/// - Optional action: "Enable all hints" (clears viewed pages + disables the disable-viewed flag).
class HintService {
  static const _kDisableViewedHints = 'hints.disable_viewed_pages';
  static const _kViewedPages = 'hints.viewed_pages';

  static Future<bool> disableViewedHints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDisableViewedHints) ?? false;
  }

  static Future<void> setDisableViewedHints(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisableViewedHints, value);
  }

  static Future<Set<String>> viewedPages() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kViewedPages) ?? const <String>[];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<bool> hasViewed(String pageId) async {
    final viewed = await viewedPages();
    return viewed.contains(pageId);
  }

  static Future<void> markViewed(String pageId) async {
    final prefs = await SharedPreferences.getInstance();
    final viewed = await viewedPages();
    viewed.add(pageId);
    await prefs.setStringList(_kViewedPages, viewed.toList()..sort());
  }

  /// Should we auto-show the hint for [pageId]?
  ///
  /// - If user has globally disabled hints, never show (even on first visit)
  /// - If page has NOT been viewed: always true (compulsory)
  /// - If page HAS been viewed: show only if disableViewedHints == false
  static Future<bool> shouldShowHint(String pageId) async {
    final disableViewed = await disableViewedHints();
    if (disableViewed) return false;
    final viewed = await hasViewed(pageId);
    if (!viewed) return true;
    return !disableViewed;
  }

  /// Clears viewed pages and re-enables hints everywhere.
  static Future<void> enableAllHints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisableViewedHints, false);
    await prefs.setStringList(_kViewedPages, <String>[]);
  }

  // ─── Per-page dismiss for InnerPageNavigationHint ──────────────────────────

  static const _kDismissedPages = 'hints.dismissed_pages';

  /// Whether the user has permanently dismissed the inner-page nav hint for [key].
  static Future<bool> isPageDismissed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDismissedPages) ?? const <String>[];
    return list.contains(key);
  }

  /// Mark an inner-page nav hint as permanently dismissed.
  static Future<void> markPageDismissed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDismissedPages) ?? <String>[];
    if (!list.contains(key)) {
      list.add(key);
      await prefs.setStringList(_kDismissedPages, list);
    }
  }

  /// Restore all dismissed inner-page nav hints (called during "Enable All").
  static Future<void> restoreAllDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedPages);
  }
}

