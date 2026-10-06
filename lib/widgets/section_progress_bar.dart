/// The progress summary + "Continue" affordance for multi-tab planning
/// sections.
///
/// Design Planning already shows this pattern at page level: a progress chip
/// ("9 of 15 sections · Next: …") that doubles as a jump-to-next button, and a
/// "Continue" pill marking the one tab the user should be in. This widget is
/// the shared form of both pieces for the tab-based sections — Technology
/// Planning, Quality Management and SSHER — so all four speak the same
/// language about position in the flow.
///
/// Both pieces answer the two questions a gated section leaves open: "how much
/// is left?" and "what do I open next?". The gate itself
/// (`lib/utils/section_flow_gate.dart`) still holds Next; this only makes the
/// state legible.
library;

import 'package:flutter/material.dart';

/// Brand tokens shared by the planning screens. Local constants: the screens
/// themselves hardcode these same values, and a theme dependency would couple
/// a utility widget to app setup.
const Color kFlowBrandYellow = Color(0xFFFFC812);
const Color kFlowBrandDark = Color(0xFF1A1A1A);

/// One tab of a section's flow, as the progress bar needs it.
class FlowTab {
  const FlowTab({required this.id, required this.label});

  /// Matches the id the section records as seen (the gate's tab id).
  final String id;

  /// Short label shown in the progress summary.
  final String label;
}

/// "N of M tabs · Next: X" — and tapping it opens tab X.
///
/// Renders as a compact filled chip next to the section's tab strip. When
/// every tab has been seen it turns green ("All M tabs reviewed") and stops
/// being a button — there is nothing left to jump to.
class SectionProgressBar extends StatelessWidget {
  const SectionProgressBar({
    super.key,
    required this.tabs,
    required this.visitedIds,
    required this.onOpenTab,
    this.sectionTitle,
  });

  /// The section's tabs in flow order.
  final List<FlowTab> tabs;

  /// Ids already recorded as seen.
  final Set<String> visitedIds;

  /// Called with the id of the next unvisited tab when tapped.
  final ValueChanged<String> onOpenTab;

  /// Optional section name used in the tooltip ("Next up in SSHER: Safety").
  final String? sectionTitle;

  FlowTab? get _next {
    for (final tab in tabs) {
      if (!visitedIds.contains(tab.id)) return tab;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final total = tabs.length;
    final done = tabs.where((t) => visitedIds.contains(t.id)).length;
    final next = _next;
    final allDone = next == null;
    final label = allDone
        ? 'All $total tabs reviewed'
        : '$done of $total reviewed · Next: ${next.label}';

    return Tooltip(
      message: allDone
          ? 'Every tab has been shown — Next is unlocked.'
          : 'Jump to ${next.label}'
              '${sectionTitle == null ? '' : ' in $sectionTitle'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: allDone ? null : () => onOpenTab(next.id),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: allDone
                  ? const Color(0xFF0F9D58).withValues(alpha: 0.12)
                  : kFlowBrandYellow.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: allDone
                    ? const Color(0xFF0F9D58)
                    : kFlowBrandYellow,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allDone ? Icons.verified_outlined : Icons.flag_outlined,
                  size: 15,
                  color: allDone
                      ? const Color(0xFF0F9D58)
                      : kFlowBrandDark,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kFlowBrandDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Continue ▸" pill a tab strip shows on the next tab to review.
///
/// Same affordance Design Planning's section cards carry, at tab scale: the
/// strip answers "where am I?" by pointing at the one tab to open next, so
/// the user never has to infer it from the gate message.
class FlowTabContinueBadge extends StatelessWidget {
  const FlowTabContinueBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kFlowBrandYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFlowBrandYellow, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 12, color: kFlowBrandDark),
          SizedBox(width: 1),
          Text(
            'Continue',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kFlowBrandDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// The id of the first tab in [tabs] not present in [visitedIds], or null.
///
/// Shared by the three tab strips so "which tab is next?" cannot drift
/// between the progress chip and the Continue badge.
String? nextUnvisitedTabId(List<FlowTab> tabs, Set<String> visitedIds) {
  for (final tab in tabs) {
    if (!visitedIds.contains(tab.id)) return tab.id;
  }
  return null;
}
