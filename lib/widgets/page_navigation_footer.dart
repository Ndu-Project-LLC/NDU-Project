import 'package:flutter/material.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';

/// Brand tokens for the page navigation footer.
///
/// Local constants, matching the other shared planning widgets: the screens
/// hardcode these values too, and a theme dependency would couple a utility
/// widget to app setup.
const Color kPageNavAccent = Color(0xFFFFC812);
const Color kPageNavInk = Color(0xFF1A1A1A);
const Color kPageNavMuted = Color(0xFF6B7280);
const Color kPageNavBorder = Color(0xFFE5E7EB);
const Color kPageNavDisabledBg = Color(0xFFE5E7EB);

/// The one forward/back navigation footer every page in the application uses.
///
/// Before this widget each page rolled its own footer: some had a bare back
/// arrow with no forward button, some had "Submit" with no way back, and the
/// wording and colours drifted page to page. This is the single canonical
/// strip — a labelled **Previous** button, the page's position in the flow
/// ("Initial Cost Estimate (2 of 68)"), an optional **Save**, and the gold
/// **Continue to `<next page>`** button — so every page answers the same two
/// questions the same way: *where am I?* and *what comes next?*
///
/// Destinations are not passed in by the caller. They are resolved from the
/// sidebar/planning flow via [PlanningPhaseNavigation], the same source
/// `goToNext`/`goToPrevious` navigate from, so the button label can never
/// point at a different screen than the button opens.
///
/// Usage — drop it at the end of the page's content column, or pass it to
/// `Scaffold.bottomNavigationBar` for a pinned bar:
///
/// ```dart
/// PageNavigationFooter(
///   checkpoint: 'fep_requirements',
///   pageTitle: 'Requirements',
///   onSave: _save,
/// )
/// ```
///
/// Overrides exist for the cases the shared flow cannot know about:
/// [onNext] for a page that must submit before advancing, and [nextLabel] for
/// a page whose forward action is genuinely named something else.
class PageNavigationFooter extends StatelessWidget {
  const PageNavigationFooter({
    super.key,
    required this.checkpoint,
    required this.pageTitle,
    this.onPrevious,
    this.onNext,
    this.onSave,
    this.onSaveSpin,
    this.previousLabel = 'Previous',
    this.nextLabel,
    this.saveLabel = 'Save',
    this.extraActions = const <Widget>[],
    this.showStepStatus = true,
    this.showBorders = true,
    this.confirmationValue,
    this.onConfirmationChanged,
    this.scrollController,
    this.padding,
  });

  /// Checkpoint id of the page the footer sits on — the same id the screens
  /// pass to `PlanningPhaseNavigation` (e.g. `fep_requirements`).
  final String checkpoint;

  /// Human label of this page, shown in the step status (e.g. `Requirements`).
  final String pageTitle;

  /// Overrides the default previous action. Null means "use the flow", which
  /// is the common case.
  final VoidCallback? onPrevious;

  /// Overrides the default next action. Use this when the page has to submit
  /// or save before advancing.
  final VoidCallback? onNext;

  /// When non-null, a Save button is rendered. Pages without persisted state
  /// simply omit it.
  final VoidCallback? onSave;

  /// Shows a spinner in place of the Save icon while an async save runs.
  final bool? onSaveSpin;

  /// Left button label. Matches the reference design: just "Previous".
  final String previousLabel;

  /// Overrides the derived `Continue to X` label.
  final String? nextLabel;

  final String saveLabel;

  /// Secondary actions the page already carries in its bar — "AI
  /// Suggestions", "Import CSV", and similar. They render in one row above
  /// the navigation buttons so replacing a page's ad-hoc footer with this
  /// widget never silently drops functionality.
  final List<Widget> extraActions;

  /// Hides the "Page (n of m)" status on pages where position is meaningless
  /// (a module hub, for example).
  final bool showStepStatus;

  /// Draws the top hairline and card surface. Set false when the footer is
  /// already inside a bordered container.
  final bool showBorders;

  /// When non-null the review-confirmation checkbox is rendered above the
  /// buttons, matching the gated flow the reference design uses.
  final bool? confirmationValue;
  final ValueChanged<bool>? onConfirmationChanged;
  final ScrollController? scrollController;

  /// Overrides the outer padding.
  final EdgeInsetsGeometry? padding;

  // ── Flow resolution ──────────────────────────────────────────────────

  /// The position of [checkpoint] in the overall flow, or null when the page
  /// is not part of one.
  ///
  /// Sidebar items win over planning pages because the sidebar is the order
  /// the navigator actually walks; the planning list is the fallback for
  /// screens that have no sidebar entry of their own (Scrum Configuration,
  /// Capacity Planning, Execution Plan Details, …).
  static ({int index, int total})? positionOf(String checkpoint) {
    final items = SidebarNavigationService.allItems;
    final sidebarIndex =
        items.indexWhere((item) => item.checkpoint == checkpoint);
    if (sidebarIndex != -1) {
      return (index: sidebarIndex, total: items.length);
    }
    final pageIndex = PlanningPhaseNavigation.getPageIndex(checkpoint);
    if (pageIndex != -1) {
      return (index: pageIndex, total: PlanningPhaseNavigation.pages.length);
    }
    return null;
  }

  /// Whether this page has a place in the planning flow at all.
  ///
  /// Pages outside the flow (drill-downs like a module sub-screen) cannot be
  /// walked forward or back along it. They still get a working Previous — it
  /// pops to wherever the user came from — but no forward button, because
  /// inventing a destination would be a dead control. That is what makes this
  /// footer safe to mount on every page in the app.
  bool _inFlow() => positionOf(checkpoint) != null;

  bool _hasPrevious(BuildContext context) {
    final override = onPrevious;
    if (override != null) return true;
    if (_inFlow()) {
      return PlanningPhaseNavigation.hasPrevious(context, checkpoint);
    }
    return Navigator.of(context).canPop();
  }

  bool _hasNext(BuildContext context) {
    if (onNext != null) return true;
    if (!_inFlow()) return false;
    return PlanningPhaseNavigation.hasNext(context, checkpoint);
  }

  void _goPrevious(BuildContext context) {
    final override = onPrevious;
    if (override != null) {
      override();
      return;
    }
    if (_inFlow()) {
      PlanningPhaseNavigation.goToPrevious(context, checkpoint);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goNext(BuildContext context) {
    final override = onNext;
    if (override != null) {
      override();
      return;
    }
    PlanningPhaseNavigation.goToNext(context, checkpoint);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasPrevious = _hasPrevious(context);
    final hasNext = _hasNext(context);
    final inFlow = _inFlow();
    final destination = inFlow
        ? PlanningPhaseNavigation.nextTitle(context, checkpoint)
        : null;
    final previousDestination = inFlow
        ? PlanningPhaseNavigation.previousTitle(context, checkpoint)
        : null;

    // A page with nowhere to go forward shows no forward button. A disabled
    // or dead "Continue" is worse than none: it promises a destination that
    // does not exist.
    final showNext = hasNext || nextLabel != null;

    final effectiveNextLabel = nextLabel ??
        (destination == null ? 'Finish' : 'Continue to $destination');
    final previousButton = Tooltip(
      message: hasPrevious
          ? 'Back to ${previousDestination ?? 'the previous page'}'
          : 'This is the first page in the flow',
      child: OutlinedButton.icon(
        onPressed: hasPrevious ? () => _goPrevious(context) : null,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
        label: Text(
          previousLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPageNavInk,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          side: BorderSide(
            color: hasPrevious ? kPageNavBorder : const Color(0xFFEDEFF2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(0, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    final Widget? saveButton = onSave == null
        ? null
        : OutlinedButton.icon(
            onPressed: onSaveSpin == true ? null : onSave,
            icon: onSaveSpin == true
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(
              saveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPageNavInk,
              disabledForegroundColor: const Color(0xFF9CA3AF),
              side: const BorderSide(color: kPageNavBorder),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );

    final nextButton = Tooltip(
      message: hasNext
          ? 'Open $destination'
          : (onNext != null
              ? 'Continue'
              : 'This is the last page in the flow'),
      child: ElevatedButton.icon(
        onPressed: () => _goNext(context),
        icon: Icon(
          hasNext ? Icons.arrow_forward_rounded : Icons.check_rounded,
          size: 17,
        ),
        label: Text(
          effectiveNextLabel,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPageNavAccent,
          foregroundColor: kPageNavInk,
          disabledBackgroundColor: kPageNavDisabledBg,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(0, 46),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    final Widget? statusText = showStepStatus
        ? _StepStatus(checkpoint: checkpoint, pageTitle: pageTitle)
        : null;

    final Widget buttons = LayoutBuilder(
      builder: (context, constraints) {
        // Stack the buttons on a phone. A single row cannot hold a labelled
        // Previous, the page status, Save and a long "Continue to" label
        // without one of them being clipped, and the forward
        // button is the one that must never be ambiguous.
        final compact = constraints.maxWidth < 720;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  previousButton,
                  if (statusText != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: statusText,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (saveButton != null) ...[
                saveButton,
                const SizedBox(height: 10),
              ],
              if (showNext) nextButton,
            ],
          );
        }

        return Row(
          children: [
            previousButton,
            if (statusText != null) ...[
              const SizedBox(width: 16),
              Flexible(child: statusText),
            ],
            const Spacer(),
            if (saveButton != null) ...[
              saveButton,
              const SizedBox(width: 12),
            ],
            if (showNext) nextButton,
          ],
        );
      },
    );

    final gate = confirmationValue == null || onConfirmationChanged == null
        ? null
        : ProceedConfirmationGate(
            value: confirmationValue!,
            onChanged: onConfirmationChanged!,
            scrollController: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gate != null) gate,
        if (extraActions.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < extraActions.length; i++) ...[
                Expanded(child: extraActions[i]),
                if (i < extraActions.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        buttons,
      ],
    );

    final horizontalPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

    if (!showBorders) {
      return Padding(padding: horizontalPadding, child: content);
    }

    return Container(
      width: double.infinity,
      padding: horizontalPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPageNavBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// "Requirements (7 of 68)" — where this page sits in the flow.
class _StepStatus extends StatelessWidget {
  const _StepStatus({
    required this.checkpoint,
    required this.pageTitle,
  });

  final String checkpoint;
  final String pageTitle;

  @override
  Widget build(BuildContext context) {
    final position = PageNavigationFooter.positionOf(checkpoint);
    final phase = SidebarNavigationService.phaseForCheckpoint(checkpoint);
    final where = position == null
        ? pageTitle
        : '$pageTitle (${position.index + 1} of ${position.total})';

    return Tooltip(
      message: phase == null ? where : '$phase · $where',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 15, color: kPageNavMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              where,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kPageNavMuted,
                fontFamily: appFontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
