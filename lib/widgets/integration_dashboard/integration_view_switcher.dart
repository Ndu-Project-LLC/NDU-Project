import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/ibr_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_baseline_view.dart';

// Shared Workspaces / Baseline Integration switcher. The Integration Dashboard
// drives it with its own view state; the other dashboards mount
// [IntegrationViewSwitcherLink], which navigates to the Integration Dashboard.

/// Which half of the dashboard is on screen.
enum IntegrationDashboardView {
  /// Portfolio roll-up, resume card, search, and the workspace grid.
  workspaces,

  /// PMB / Integrated Baseline Review for the active project.
  baseline,
}

// ──────────────────────────────────────────────────────────────────────
// View switcher
// ──────────────────────────────────────────────────────────────────────

/// A two-state pill control that doubles as a status readout: each segment
/// carries a live badge so the user can see the shape of both halves of the
/// dashboard without switching to them.
class IntegrationViewSwitcher extends StatelessWidget {
  const IntegrationViewSwitcher({
    super.key,
    required this.tokens,
    this.value,
    required this.onChanged,
    this.workspaceCount = 0,
    this.ibrStatus,
    this.ibrScore,
  });

  final IntegrationTokens tokens;
  /// The highlighted view. Null when no segment of this dashboard is the
  /// current view, so the thumb is hidden.
  final IntegrationDashboardView? value;
  final ValueChanged<IntegrationDashboardView> onChanged;
  final int workspaceCount;
  final IbrStatus? ibrStatus;
  final double? ibrScore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below ~420px the labels plus badges stop fitting side by side, so
        // the switcher stacks into two full-width rows.
        final stacked = constraints.maxWidth < 420;
        // One shared row height keeps the sliding thumb and the hit targets
        // in lockstep in both orientations.
        const rowHeight = 46.0;
        const rowGap = 4.0;
        final trackHeight = stacked ? rowHeight * 2 + rowGap : rowHeight;
        // 4px of padding plus a 1px border on each side are inside the box and
        // so are not available to the track: the rows used to be handed 8px of
        // it and the thumb 8px of width, which put them 2px over in each
        // direction and painted Flutter's overflow stripe across the Baseline
        // segment (and clipped the thumb's right edge).
        const inset = (4.0 + 1.0) * 2;
        final trackWidth = constraints.maxWidth - inset;
        final thumbWidth = stacked ? trackWidth : trackWidth / 2;

        // One thumb, positioned by the current selection: stacked, it slides
        // down a row; side by side, it slides across a column. Drawing a thumb
        // per segment instead made both segments read as selected.
        Widget thumb() {
          final isBaseline = value == IntegrationDashboardView.baseline;
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: 4 + (isBaseline && !stacked ? thumbWidth : 0),
            top: stacked ? 4 + (isBaseline ? rowHeight + rowGap : 0) : 4,
            width: thumbWidth,
            height: rowHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: value == null ? 0 : 1,
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.brand,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brandDeep.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget segment(IntegrationDashboardView view) {
          final selected = value == view;
          final tone = selected ? tokens.onBrand : tokens.ink;
          final (IconData icon, String label, Widget? badge) = switch (view) {
            IntegrationDashboardView.workspaces => (
                Icons.grid_view_rounded,
                'Workspaces',
                workspaceCount == 0
                    ? null
                    : _Badge(
                        tokens: tokens,
                        label: '$workspaceCount',
                        selected: selected,
                      ),
              ),
            IntegrationDashboardView.baseline => (
                Icons.hub_outlined,
                'Baseline Integration',
                ibrStatus == null
                    ? null
                    : _Badge(
                        tokens: tokens,
                        label: ibrScore == null
                            ? '—'
                            : '${ibrScore!.clamp(0, 100).round()}',
                        selected: selected,
                        accent: ibrStatus == null
                            ? null
                            : statusVisual(tokens, ibrStatus!).$1,
                      ),
              ),
          };

          return Semantics(
            button: true,
            selected: selected,
            label: '$label view',
            child: InkWell(
              onTap: () => onChanged(view),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: stacked ? Alignment.centerLeft : Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 17, color: tone),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: tone,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge],
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          height: trackHeight + inset,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.outline),
          ),
          child: stacked
              ? Stack(
                  children: [
                    thumb(),
                    Column(
                      children: [
                        SizedBox(
                          height: rowHeight,
                          child: segment(IntegrationDashboardView.workspaces),
                        ),
                        const SizedBox(height: rowGap),
                        SizedBox(
                          height: rowHeight,
                          child: segment(IntegrationDashboardView.baseline),
                        ),
                      ],
                    ),
                  ],
                )
              : Stack(
                  children: [
                    thumb(),
                    Row(
                      children: [
                        Expanded(
                          child: segment(IntegrationDashboardView.workspaces),
                        ),
                        Expanded(
                          child: segment(IntegrationDashboardView.baseline),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.tokens,
    required this.label,
    required this.selected,
    this.accent,
  });

  final IntegrationTokens tokens;
  final String label;
  final bool selected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = selected
        ? (accent ?? tokens.onBrand)
        : (accent ?? tokens.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? tone.withValues(alpha: 0.18)
            : tokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? tone.withValues(alpha: 0.35) : tokens.outline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

/// The Workspaces / Baseline Integration switcher for dashboards other than
/// the Integration Dashboard. Selecting a segment opens the Integration
/// Dashboard on that view. The workspace count matches the Integration
/// Dashboard: the signed-in user's basic-plan projects.
class IntegrationViewSwitcherLink extends StatelessWidget {
  const IntegrationViewSwitcherLink({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final tokens =
        IntegrationTokens.of(context, DashboardPaletteScope.of(context));
    return StreamBuilder<List<ProjectRecord>>(
      stream: user == null
          ? Stream.value(const <ProjectRecord>[])
          : ProjectService.streamProjects(
              ownerId: user.uid,
              filterByOwner: true,
              limit: 200,
            ),
      builder: (context, snapshot) {
        final workspaceCount = (snapshot.data ?? const <ProjectRecord>[])
            .where((p) => p.isBasicPlanProject)
            .length;
        return SizedBox(
          width: double.infinity,
          child: IntegrationViewSwitcher(
            tokens: tokens,
            workspaceCount: workspaceCount,
            onChanged: (view) => context.go(switch (view) {
              IntegrationDashboardView.workspaces =>
                '/${AppRoutes.regularProjectDashboard}',
              IntegrationDashboardView.baseline =>
                '/${AppRoutes.integrationDashboard}',
            }),
          ),
        );
      },
    );
  }
}
