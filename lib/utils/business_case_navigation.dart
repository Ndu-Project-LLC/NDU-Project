import 'package:flutter/material.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';

/// Business-case flow navigation that follows the sidebar checkpoint order.
class BusinessCaseNavigation {
  static const Map<String, String> _screenToCheckpoint = {
    'Business Case': 'business_case',
    'Potential Solutions': 'potential_solutions',
    'Risk Identification': 'risk_identification',
    'IT Considerations': 'it_considerations',
    'Infrastructure Considerations': 'infrastructure_considerations',
    'Core Stakeholders': 'core_stakeholders',
    'Initial Cost Estimate': 'cost_analysis',
    'Preferred Solution Analysis': 'preferred_solution_analysis',
  };

  static String? _checkpointFor(String label) => _screenToCheckpoint[label];

  static void navigateBack(BuildContext context, String currentScreen) {
    final currentCheckpoint = _checkpointFor(currentScreen);
    if (currentCheckpoint == null) return;

    final previous =
        SidebarNavigationService.instance.getPreviousItem(currentCheckpoint);
    if (previous == null) return;

    final screen = NavigationRouteResolver.resolveCheckpointToScreen(
      previous.checkpoint,
      context,
    );
    if (screen == null) return;

    Navigator.of(context).pushReplacement(
      PhaseTransitionHelper.buildRoute(
        context: context,
        builder: (_) => screen,
        destinationCheckpoint: previous.checkpoint,
        sourceCheckpoint: currentCheckpoint,
      ),
    );
  }

  static void navigateForward(BuildContext context, String currentScreen) {
    final currentCheckpoint = _checkpointFor(currentScreen);
    if (currentCheckpoint == null) return;

    final next = SidebarNavigationService.instance.getNextItem(currentCheckpoint);
    if (next == null) return;

    final screen = NavigationRouteResolver.resolveCheckpointToScreen(
      next.checkpoint,
      context,
    );
    if (screen == null) return;

    Navigator.of(context).pushReplacement(
      PhaseTransitionHelper.buildRoute(
        context: context,
        builder: (_) => screen,
        destinationCheckpoint: next.checkpoint,
        sourceCheckpoint: currentCheckpoint,
      ),
    );
  }

  static bool hasPrevious(String currentScreen) {
    final currentCheckpoint = _checkpointFor(currentScreen);
    if (currentCheckpoint == null) return false;
    return SidebarNavigationService.instance.getPreviousItem(currentCheckpoint) !=
        null;
  }

  static bool hasNext(String currentScreen) {
    final currentCheckpoint = _checkpointFor(currentScreen);
    if (currentCheckpoint == null) return false;
    return SidebarNavigationService.instance.getNextItem(currentCheckpoint) !=
        null;
  }
}
