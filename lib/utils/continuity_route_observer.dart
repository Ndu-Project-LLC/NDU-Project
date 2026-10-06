import 'package:flutter/material.dart';

import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

/// Global [NavigatorObserver] that keeps the deterministic continuity
/// snapshot fresh on EVERY page push — not just the handful of routes that
/// navigate through [PhaseTransitionHelper].
///
/// Continuity is passed across pages with real project data, never by the AI:
/// whenever a route with a known sidebar checkpoint is pushed (via go_router
/// `context.push`/`context.go` or a plain `Navigator.push` on the root
/// navigator), [ProjectDataProvider.prepareForCheckpoint] rebuilds the
/// context scan for that checkpoint and stores it in `planningNotes`
/// (`continuity_context_<checkpoint>`). Downstream pages read that snapshot
/// with [ProjectIntelligenceService.continuityContextFor] / the sidebar
/// accumulated-context helpers, so prior-phase data flows page-to-page
/// without any LLM involvement.
///
/// The observer is intentionally conservative:
///   - Only routes whose name resolves to a real sidebar checkpoint trigger a
///     refresh (auth, marketing, dashboards, dialogs are skipped).
///   - It never runs before a project is actually loaded, so navigating
///     around an empty model cannot mark data dirty (which would otherwise
///     auto-create a phantom project on the debounced autosave).
///   - [ProjectDataProvider.prepareForCheckpoint] itself is idempotent and
///     early-returns when the prepared context is unchanged.
class ContinuityRouteObserver extends NavigatorObserver {
  ContinuityRouteObserver._();

  static final ContinuityRouteObserver instance = ContinuityRouteObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _refreshForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _refreshForRoute(newRoute);
  }

  void _refreshForRoute(Route<dynamic> route) {
    final checkpoint = checkpointForRouteName(route.settings.name);
    if (checkpoint == null) return;

    final provider = ProjectDataProvider.active;
    if (provider == null) return;

    final projectId = provider.projectData.projectId;
    // Guard: only prepare continuity for a loaded/active project. Preparing
    // an empty model would mark it dirty and trigger a debounced autosave
    // that creates a phantom project with no name.
    if (projectId == null || projectId.isEmpty) return;

    provider.prepareForCheckpoint(checkpoint);
  }
}

/// Maps a go_router route name (kebab-case, from [AppRoutes]) to its sidebar
/// checkpoint key (snake_case, from [SidebarNavigationService]).
///
/// Returns `null` when the route is not part of the project flow (auth,
/// marketing, dashboards, settings, …), in which case no continuity snapshot
/// is prepared.
String? checkpointForRouteName(String? routeName) {
  final name = (routeName ?? '').trim();
  if (name.isEmpty) return null;

  // Route names that don't convert 1:1 to a sidebar checkpoint (aliases,
  // sub-screen routes, and preserved typos like "reconcillation").
  const overrides = <String, String>{
    // Initiation phase is hosted on the phase screen; treat it as the first
    // checkpoint so downstream context has a stable anchor.
    'initiation-phase': 'business_case',
    'team-training-building': 'team_training',
    'ssher-stacked': 'ssher',
    'ssher-1': 'ssher',
    'ssher-2': 'ssher',
    'ssher-3': 'ssher',
    'ssher-4': 'ssher',
    'ssher-full': 'ssher',
    'design-planning': 'design',
    'technology-definitions': 'technology',
    'technology-inventory': 'technology',
    'deliverable-roadmap-agile-map-out': 'agile_map_out',
    'execution-interface-management': 'execution_plan_interface_management',
    'gap-analysis-scope-reconciliation': 'gap_analysis_scope_reconcillation',
    'project-plan-level-1-schedule': 'project_plan_level1_schedule',
    'startup-planning-closeout-plan': 'startup_planning_closeout',
    'risk-tracking-screen': 'risk_tracking',
    'planning-procurement': 'procurement',
    'planning-requirements': 'requirements',
    'contract-details': 'contracts',
    'create-contract': 'contracts',
    'contracting-status': 'contracts',
    'contracting-summary': 'contracts',
    'change-management-module': 'change_management',
    'agile-project-hub': 'agile_development_iterations',
    'project-framework-next': 'project_goals_milestones',
  };

  final direct = overrides[name];
  if (direct != null) return direct;

  // Most routes convert cleanly: kebab-case → snake_case. Only accept a
  // conversion when it resolves to a real sidebar checkpoint, so non-project
  // routes are skipped instead of polluting the continuity snapshot.
  final candidate = name.replaceAll('-', '_');
  return SidebarNavigationService.instance
          .findItemByCheckpoint(candidate) !=
      null
      ? candidate
      : null;
}