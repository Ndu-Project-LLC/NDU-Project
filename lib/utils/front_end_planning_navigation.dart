import 'package:flutter/material.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Front End Planning checkpoint flow aligned to the sidebar order shown in UI.
class FrontEndPlanningNavigation {
  FrontEndPlanningNavigation._();

  static const List<String> checkpoints = <String>[
    'fep_summary',
    'fep_requirements',
    'fep_risks',
    'fep_opportunities',
    'fep_contract_vendor_quotes',
    'fep_procurement',
    'fep_security',
    'fep_milestone',
    'fep_allowance',
    'project_charter',
  ];

  static String? nextCheckpoint(BuildContext context, String currentCheckpoint) {
    return _resolveAdjacentCheckpoint(
      context,
      currentCheckpoint,
      forward: true,
    );
  }

  static String? previousCheckpoint(
      BuildContext context, String currentCheckpoint) {
    return _resolveAdjacentCheckpoint(
      context,
      currentCheckpoint,
      forward: false,
    );
  }

  static String backLabel(BuildContext context, String currentCheckpoint) {
    final previous = previousCheckpoint(context, currentCheckpoint);
    final item = previous == null
        ? null
        : SidebarNavigationService.instance.findItemByCheckpoint(previous);
    return item == null ? 'Back' : 'Back: ${item.label}';
  }

  static String nextLabel(BuildContext context, String currentCheckpoint) {
    final next = nextCheckpoint(context, currentCheckpoint);
    final item = next == null
        ? null
        : SidebarNavigationService.instance.findItemByCheckpoint(next);
    return item == null ? 'Next' : 'Next: ${item.label}';
  }

  static Widget? resolveScreen(BuildContext context, String checkpoint) {
    return NavigationRouteResolver.resolveCheckpointToScreen(checkpoint, context);
  }

  static void goToNext(BuildContext context, String currentCheckpoint) {
    final target = nextCheckpoint(context, currentCheckpoint);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End of Front End Planning navigation path.'),
        ),
      );
      return;
    }
    _replaceWithCheckpoint(context, currentCheckpoint, target);
  }

  static void goToPrevious(BuildContext context, String currentCheckpoint) {
    final target = previousCheckpoint(context, currentCheckpoint);
    if (target == null) {
      Navigator.maybePop(context);
      return;
    }
    _replaceWithCheckpoint(context, currentCheckpoint, target);
  }

  static String? _resolveAdjacentCheckpoint(
    BuildContext context,
    String currentCheckpoint, {
    required bool forward,
  }) {
    final currentIndex = checkpoints.indexOf(currentCheckpoint);
    if (currentIndex == -1) return null;

    final isBasicPlan = ProjectDataHelper.getData(context).isBasicPlanProject;
    final iterable = forward
        ? Iterable<int>.generate(checkpoints.length - currentIndex - 1,
            (i) => currentIndex + i + 1)
        : Iterable<int>.generate(currentIndex, (i) => currentIndex - i - 1);

    for (final index in iterable) {
      final checkpoint = checkpoints[index];
      final item =
          SidebarNavigationService.instance.findItemByCheckpoint(checkpoint);
      if (item == null ||
          !SidebarNavigationService.instance.isItemLocked(item, isBasicPlan)) {
        return checkpoint;
      }
    }
    return null;
  }

  static void _replaceWithCheckpoint(
    BuildContext context,
    String sourceCheckpoint,
    String destinationCheckpoint,
  ) {
    final screen = resolveScreen(context, destinationCheckpoint);
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $destinationCheckpoint.')),
      );
      return;
    }

    final route = PhaseTransitionHelper.buildRoute(
      context: context,
      builder: (_) => screen,
      sourceCheckpoint: sourceCheckpoint,
      destinationCheckpoint: destinationCheckpoint,
    );
    Navigator.of(context).pushReplacement(route);
  }
}
