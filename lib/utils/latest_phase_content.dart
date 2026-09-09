/// Latest-phase content resolution.
///
/// Product rule (voice note, 2026-09-03): a topic (technology, requirements,
/// procurement, scope, …) lives across project phases. Each later phase
/// normally *carries forward* the earlier one, so anything downstream — an AI
/// assistant scanning the site, a context banner, a seeding routine — should
/// read the **latest phase that actually has content**, not re-scan from the
/// beginning of the project.
///
///   - If planning carries the topic, read planning.
///   - If the topic only ever existed in initiation, read initiation.
///   - Only when no later phase has it does the earlier phase become the
///     source of truth.
///
/// These are pure helpers (no providers / BuildContext) so they are trivially
/// unit-testable and reusable from screens, services and AI context builders.
library;

/// A single phase's content for one topic area.
class PhaseContent {
  /// Human label of the phase, e.g. `'Initiation'` or `'Planning'`.
  final String phase;

  /// Raw content captured in that phase (may be empty / whitespace-only).
  final String content;

  /// Ordering weight — higher wins when multiple phases have content.
  /// Phases normally pass chronological order (initiation = 1, planning = 2,
  /// design = 3, …) so the most recent phase is picked.
  final int order;

  const PhaseContent({
    required this.phase,
    required this.content,
    required this.order,
  });

  bool get isEmpty =>
      content.trim().isEmpty || content.trim() == '—' || content.trim() == '-';

  factory PhaseContent.initiation(String content) =>
      PhaseContent(phase: 'Initiation', content: content, order: 1);

  factory PhaseContent.planning(String content) =>
      PhaseContent(phase: 'Planning', content: content, order: 2);

  factory PhaseContent.design(String content) =>
      PhaseContent(phase: 'Design', content: content, order: 3);

  factory PhaseContent.execution(String content) =>
      PhaseContent(phase: 'Execution', content: content, order: 4);

  factory PhaseContent.launch(String content) =>
      PhaseContent(phase: 'Launch', content: content, order: 5);
}

/// The resolved "latest version" of a topic across its phases.
class ResolvedLatestContent {
  /// Phase label that holds the winning content, or null when no phase has
  /// any content.
  final String? sourcePhase;

  /// Order of the winning phase, or null.
  final int? sourceOrder;

  /// The winning content (trimmed), or empty string when nothing exists.
  final String content;

  const ResolvedLatestContent({
    this.sourcePhase,
    this.sourceOrder,
    this.content = '',
  });

  bool get hasContent => content.trim().isNotEmpty;
}

/// Pick the most recent non-empty entry from an ordered list of phase
/// contents. Entries are expected in chronological order; later entries win.
/// Returns an empty [ResolvedLatestContent] when every phase is empty.
ResolvedLatestContent resolveLatestNonEmpty(List<PhaseContent> phases) {
  ResolvedLatestContent latest = const ResolvedLatestContent();
  for (final phase in phases) {
    if (phase.isEmpty) continue;
    // Later entries override earlier ones. When ordering ties, the last one
    // in list order wins (callers control tie-breaks by list order).
    latest = ResolvedLatestContent(
      sourcePhase: phase.phase,
      sourceOrder: phase.order,
      content: phase.content.trim(),
    );
  }
  return latest;
}

/// Resolve the latest version for every topic area in [areas] (map of area
/// name → its phase contents in chronological order).
///
/// Returns an ordered map of area → resolved latest version, keeping the same
/// area order as the input so callers can render deterministic output.
Map<String, ResolvedLatestContent> resolveLatestPerArea(
    Map<String, List<PhaseContent>> areas) {
  final result = <String, ResolvedLatestContent>{};
  for (final entry in areas.entries) {
    result[entry.key] = resolveLatestNonEmpty(entry.value);
  }
  return result;
}

/// Render a compact, AI-ready summary of the *latest* content per area — the
/// canonical input for assistants scanning the site for context. Empty areas
/// are omitted entirely so downstream prompts never see stale duplicates.
///
/// Example output:
/// ```
/// Technology (latest: Planning):
/// planning carries the technology forward…
/// ```
String buildLatestContextSummary(Map<String, List<PhaseContent>> areas) {
  final buf = StringBuffer();
  for (final entry in areas.entries) {
    final resolved = resolveLatestNonEmpty(entry.value);
    if (!resolved.hasContent) continue;
    buf.writeln('${entry.key} (latest: ${resolved.sourcePhase}):');
    buf.writeln(resolved.content);
    buf.writeln();
  }
  return buf.toString().trim();
}
