/// The "finish this section first" gate for multi-tab sections.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): **"that design
/// planning needs to be grayed out. So please take this action for every single
/// section that has more than one tab … The next must be grayed out and if you
/// try to click on it, you should tell them to finish the flow within that
/// section."**
///
/// The failure the owner described is why this exists: "if they go all the way
/// down … they might click next and they'll skip everything else here." A
/// section with several tabs is one planning step, not several, so leaving it
/// early skips work the user never saw.
///
/// Pure and testable: it compares a section's declared tabs against the tab ids
/// that section has recorded as seen. No widget state, no AI — the same shape as
/// `schedule_work_packages.dart` and the other extract-and-verify helpers.
///
/// The owner was also explicit that this must not become busywork: "if this is a
/// lot of work, don't do it … I think you need to put a next within the section
/// at the bottom. But that's not possible. Please don't do it." So the gate never
/// *adds* a second Next button — it only holds the existing one until the tabs
/// have been shown.
library;

/// One tab inside a multi-tab section.
class SectionTab {
  /// The id the section records when the tab has been seen. These must match
  /// what the section actually stores, or the gate can never open.
  final String id;

  /// Shown to the user when naming what is still missing.
  final String label;

  const SectionTab(this.id, this.label);
}

/// A planning section that holds more than one tab.
class SectionFlow {
  final String sectionId;
  final String sectionTitle;
  final List<SectionTab> tabs;

  const SectionFlow({
    required this.sectionId,
    required this.sectionTitle,
    required this.tabs,
  });

  int get tabCount => tabs.length;
}

/// Every section that has more than one tab.
///
/// A section that is not listed here has a single tab (or none), so there is no
/// flow inside it to finish and its Next is never gated.
const List<SectionFlow> multiTabSectionFlows = [
  SectionFlow(
    sectionId: 'ssher',
    sectionTitle: 'SSHER',
    tabs: [
      SectionTab('safety', 'Safety'),
      SectionTab('security', 'Security'),
      SectionTab('health', 'Health'),
      SectionTab('environment', 'Environment'),
      SectionTab('regulatory', 'Regulatory'),
    ],
  ),
  SectionFlow(
    sectionId: 'quality_management',
    sectionTitle: 'Quality Management',
    // These ids are the `_QualityTab` enum names, which is what the screen
    // records in `QualityManagementData.visitedSections`. They previously did
    // not match — the screen recorded AI *category* keys (`objectives`,
    // `inspection`, `audit`) while the gate looked for `targets`, `qaTracking`,
    // `qcTracking` — so the gate could never open and Quality's Next was locked
    // permanently. Both sides now use the enum name.
    tabs: [
      SectionTab('plan', 'Plan'),
      SectionTab('targets', 'Targets'),
      SectionTab('qaTracking', 'QA Tracking'),
      SectionTab('qcTracking', 'QC Tracking'),
      SectionTab('metrics', 'Metrics'),
      SectionTab('register', 'Register'),
      SectionTab('costOfQuality', 'Cost of Quality'),
    ],
  ),
  SectionFlow(
    sectionId: 'technology',
    sectionTitle: 'Technology Planning',
    tabs: [
      SectionTab('inventory', 'Inventory'),
      SectionTab('aiIntegrations', 'AI Integrations'),
      SectionTab('externalIntegrations', 'External Integrations'),
      SectionTab('definitions', 'Definitions'),
      SectionTab('aiRecommendations', 'AI Recommendations'),
    ],
  ),
  // Design Planning is the section the owner named when he asked for this
  // ("that design planning needs to be grayed out"). Its "tabs" are the 15
  // inner sections of `_sectionOrder` in `design_planning_screen.dart`, and
  // what counts as seen there is a section that has been marked complete or
  // not-applicable — the guided sections are steps to work through, not tabs to
  // glance at. Ids must stay in step with `_sectionOrder`.
  SectionFlow(
    sectionId: 'design',
    sectionTitle: 'Design Planning',
    tabs: [
      SectionTab('overview', 'Project Overview'),
      SectionTab('design_overview', 'Design Overview'),
      SectionTab('design_specifications_workspace', 'Design Specifications'),
      SectionTab('deviations', 'Deviations'),
      SectionTab('requirements', 'Requirements Mapping'),
      SectionTab('architecture', 'Architecture Basis'),
      SectionTab('uiux', 'UI/UX Basis'),
      SectionTab('technical', 'Technical Basis'),
      SectionTab('constraints', 'Constraints & Assumptions'),
      SectionTab('risks', 'Risks & Mitigation'),
      SectionTab('dependencies', 'Dependencies'),
      SectionTab('decisions', 'Decision Log'),
      SectionTab('validation', 'Validation'),
      SectionTab('approvals', 'Approvals'),
      SectionTab('work_packages', 'Work Packages'),
    ],
  ),
];

/// The declared flow for [sectionId], or null when the section is not multi-tab.
SectionFlow? sectionFlowFor(String sectionId) {
  for (final flow in multiTabSectionFlows) {
    if (flow.sectionId == sectionId) return flow;
  }
  return null;
}

/// True when [sectionId] is one of the sections that has a flow to finish.
bool isMultiTabSection(String sectionId) => sectionFlowFor(sectionId) != null;

/// The tabs of [sectionId] the user has not opened yet, in declaration order.
///
/// An unknown section returns empty, which means "nothing to finish" — a section
/// we have not modelled must never lock the user out of their own Next.
List<SectionTab> unvisitedTabs(String sectionId, Iterable<String> visited) {
  final flow = sectionFlowFor(sectionId);
  if (flow == null) return const [];
  final seen = visited.toSet();
  return flow.tabs.where((tab) => !seen.contains(tab.id)).toList(growable: false);
}

/// True when the section's Next may be used.
bool sectionFlowComplete(String sectionId, Iterable<String> visited) =>
    unvisitedTabs(sectionId, visited).isEmpty;

/// Sections a methodology does not produce at all, keyed by methodology name.
///
/// Agile delivery has no design work package — "for agile projects there
/// wouldn't necessarily be a design work package … design is part of the
/// iteration anyways" (Lusaka 25 (copy) ask 22). A section named here ships
/// already marked **Not applicable**, so the user is not made to fill in
/// something their delivery model does not have. Nothing is deleted: the
/// section stays visible and can be switched back on.
const Map<String, Set<String>> sectionsNotApplicableByMethodology = {
  'agile': {'work_packages'},
};

/// True when [sectionId] should start life as Not applicable under
/// [methodology].
///
/// An unknown methodology never marks anything: we only skip a section when the
/// delivery model positively says the section does not exist.
bool sectionStartsNotApplicable(String methodology, String sectionId) {
  final notApplicable =
      sectionsNotApplicableByMethodology[methodology.trim().toLowerCase()];
  return notApplicable != null && notApplicable.contains(sectionId);
}

/// The message to show when a gated Next is pressed.
///
/// Names the tabs still to review rather than only saying "finish the section",
/// because the whole point is that the user did not know those tabs existed.
String sectionIncompleteMessage(String sectionId, List<SectionTab> missing) {
  if (missing.isEmpty) return '';
  final flow = sectionFlowFor(sectionId);
  final title = flow?.sectionTitle ?? 'this section';
  final names = missing.map((tab) => tab.label).join(', ');
  return 'Please finish the flow within $title before moving on. '
      'Still to review: $names.';
}
