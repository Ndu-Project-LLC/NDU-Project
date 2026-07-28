/// Small utilities for sanitizing KAZ AI-generated text before it is shown in UI
class TextSanitizer {
  /// Remove markdown asterisk markers that can appear in AI output (e.g. *bold* or **bold**)
  /// and trim surrounding whitespace.
  static String sanitizeAiText(String? input) {
    if (input == null) return '';
    return input.replaceAll('*', '').trim();
  }

  /// Preserve lightweight rich-text markers while removing common code fences.
  static String sanitizeAiRichText(String? input) {
    if (input == null) return '';
    return input
        .replaceAll(RegExp(r'```[a-zA-Z0-9_-]*'), '')
        .replaceAll('```', '')
        .trim();
  }

  /// Remove common markdown code fences and try to extract the JSON object.
  static String cleanJson(String input) {
    var cleaned = input.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return cleaned.substring(start, end + 1).trim();
    }
    return cleaned;
  }
}
