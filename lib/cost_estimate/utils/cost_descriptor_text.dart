/// Cost descriptor text normalisation.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): while reviewing the
/// Cost Estimate the owner asked to **"remove the double dashes, the double
/// hyphens"** from the cost descriptors.
///
/// A doubled separator reaches the screen whenever two description fragments
/// are joined and one of them already ends with a dash — `"WP-04 — Electrical"
/// joined onto `"— site works"` renders as `"WP-04 — Electrical — — site
/// works"`. Because descriptors are user-editable and also arrive from the
/// SSHER, Schedule and Risk pulls, a doubled dash can already be sitting in
/// stored data, so this normalises on the way to the screen as well as at the
/// join.
///
/// Deliberately narrow: only a **run of two or more** dash characters is
/// collapsed. A single hyphen is left completely alone, so genuine identifiers
/// (`WP-04`, `Level 1 - Project Schedule`, `WP-01 - Electrical`) pass through
/// unchanged. Idempotent — running it twice changes nothing.
library;

/// Dash characters treated as separators: hyphen-minus, en dash, em dash.
const String _dashClass = r'-\u2013\u2014';

/// A run of two or more dash characters, with any surrounding whitespace.
final RegExp _dashRun = RegExp(
  '\\s*[$_dashClass]\\s*(?:[$_dashClass]\\s*)+',
);

/// Collapse doubled/tripled dash separators into a single em dash.
///
/// `"PPE — — Gloves"` → `"PPE — Gloves"`, `"Site -- Works"` →
/// `"Site — Works"`, `"WP-04"` → `"WP-04"` (unchanged).
String collapseDashRuns(String text) {
  if (text.isEmpty) return text;
  // A run only counts as doubled when at least two dash characters are
  // present, which the pattern above already enforces.
  return text.replaceAll(_dashRun, ' — ').trim();
}

/// Normalise a cost descriptor for display.
///
/// Collapses doubled separators and tidies the whitespace they leave behind,
/// without touching anything else about the text.
String costDescriptorForDisplay(String raw) {
  if (raw.isEmpty) return raw;
  final collapsed = collapseDashRuns(raw);
  // Runs of spaces left by the substitution. Horizontal whitespace only — a
  // description may legitimately span lines and those newlines are preserved.
  return collapsed.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
}
