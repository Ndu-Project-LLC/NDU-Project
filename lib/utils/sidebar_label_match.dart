/// Sidebar highlight matching.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): **"when I am on the
/// sub-pages of design planning, the sidebar highlight does not follow me."**
///
/// The cause was exact-equality matching. Sub-pages identify themselves in the
/// `"<section> - <sub-page>"` convention — `Design Planning - Design
/// Specifications`, `Design Planning - Architecture Basis`, and so on — but the
/// sidebar only ever contains the parent item, `Design Planning`. Nothing
/// equalled anything, so no item highlighted and the section never expanded.
///
/// The convention is used widely (`navigation_route_resolver.dart` lists
/// `Design Planning - …`, `Project Close Out - …`, `Execution Plan - …`), so the
/// fix belongs here rather than in either screen: a sub-page resolves to its
/// parent section when no more specific item exists.
library;

/// Strip a leading numeric step like `"3. "` or `"12) "`.
///
/// Some screens prefix their active label with a phase step, and the sidebar
/// titles are unnumbered, so the number has to come off before comparing.
String normalizeSidebarLabel(String label) {
  return label.replaceFirst(RegExp(r'^\d{1,3}[.)]\s+'), '').trim();
}

/// The parent section of a `"<section> - <sub-page>"` label, or null when the
/// label has no such prefix.
///
/// Only the text before the *first* `" - "` is taken, so a doubly-scoped label
/// like `"Project Plan - Level 1 - Project Schedule"` resolves to
/// `"Project Plan"` rather than inventing a `"Project Plan - Level 1"` item.
String? parentSectionLabel(String label) {
  final index = label.indexOf(' - ');
  if (index <= 0) return null;
  final parent = label.substring(0, index).trim();
  return parent.isEmpty ? null : parent;
}

/// Whether an active label should highlight the sidebar item titled
/// [itemLabel].
///
/// Matching is, in order:
/// 1. exact,
/// 2. exact after stripping a numeric step prefix on either side,
/// 3. the active label's parent section (`"Design Planning - Deviations"` →
///    `"Design Planning"`), which is what makes sub-pages light up the section
///    that contains them.
///
/// Step 3 runs last so a real item always beats its parent: if a sidebar ever
/// gains a `"Design Planning - Deviations"` entry, that entry highlights and the
/// section header no longer does.
bool sidebarLabelMatches({
  required String activeLabel,
  required String itemLabel,
}) {
  final active = normalizeSidebarLabel(activeLabel);
  final item = normalizeSidebarLabel(itemLabel);

  if (active == item) return true;
  if (active.toLowerCase() == item.toLowerCase()) return true;

  final parent = parentSectionLabel(active);
  if (parent == null) return false;
  return parent.toLowerCase() == item.toLowerCase();
}
