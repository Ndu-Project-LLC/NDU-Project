/// The Agile Project Hub breakdown — one list, two consumers.
///
/// The hub landing page (`screens/agile_project_hub_screen.dart`) renders these
/// as its "Module Components" cards, and the sidebar
/// (`widgets/initiation_like_sidebar.dart`) renders them as the sub-pages nested
/// under **Agile Project Hub**. Both read the same entries so a card and its
/// sidebar sub-page can never open different pages.
///
/// Each entry carries three navigation facts:
///
/// * [route] — where the section opens (`go_router` path, without a leading
///   slash in the constant; [path] adds it).
/// * [sidebarLabel] — the sub-page's title inside the Agile Project Hub group.
/// * [activeLabel] — the label the target screen passes to the sidebar as
///   `activeItemLabel`. It is usually *not* [sidebarLabel] (the backlog and
///   release pages are shared with the Planning phase), so the sidebar needs it
///   to highlight the right sub-page when one of those screens is open.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/routing/app_router.dart';

/// One section of the Agile Project Hub.
@immutable
class AgileHubSection {
  /// 1-based position, matching the badge on the hub card.
  final int number;

  /// Full title shown on the hub card, e.g. `Agile Metrics & Reporting`.
  final String title;

  /// Short title shown in the sidebar, e.g. `Agile Metrics`.
  final String sidebarTitle;

  final String subtitle;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  /// Feature chips shown on the hub card.
  final List<String> features;

  /// `AppRoutes` name of the page this section opens.
  final String route;

  /// The `activeItemLabel` the target screen declares, used to highlight this
  /// sub-page. See the library doc for why it is separate from
  /// [sidebarLabel].
  final String activeLabel;

  const AgileHubSection({
    required this.number,
    required this.title,
    required this.sidebarTitle,
    required this.subtitle,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.features,
    required this.route,
    required this.activeLabel,
  });

  /// `go_router` location for this section.
  String get path => '/$route';

  /// The `"<section> - <sub-page>"` label convention that
  /// `utils/sidebar_label_match.dart` resolves back to this group.
  String get sidebarLabel => 'Agile Project Hub - $sidebarTitle';

  /// Open the section's page.
  void open(BuildContext context) => context.push(path);
}

const List<AgileHubSection> agileHubSections = <AgileHubSection>[
  AgileHubSection(
    number: 1,
    title: 'Agile Dashboard',
    sidebarTitle: 'Agile Dashboard',
    subtitle: 'Real-time delivery performance',
    icon: Icons.dashboard_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Active sprint overview',
      'Velocity trends',
      'Burnup/Burndown charts',
      'Cycle time trends',
      'Delivery forecasts',
      'AI delivery recommendations',
    ],
    route: AppRoutes.agileDashboard,
    activeLabel: 'Agile Dashboard',
  ),
  AgileHubSection(
    number: 2,
    title: 'Product Backlog',
    sidebarTitle: 'Product Backlog',
    subtitle: 'Central repository for all work items',
    icon: Icons.list_alt_outlined,
    gradientStart: Color(0xFFFFC812),
    gradientEnd: Color(0xFFEAB308),
    features: [
      'User stories, Epics, Features',
      'Story point estimation',
      'Priority management',
      'Business value scoring',
      'AI story suggestions',
      'Requirement traceability',
    ],
    route: AppRoutes.agileStoriesBacklog,
    activeLabel: 'Agile Delivery Model - Stories & Backlog Breakdown',
  ),
  AgileHubSection(
    number: 3,
    title: 'Sprint / Iteration Planning',
    sidebarTitle: 'Sprint Planning',
    subtitle: 'Plan each development iteration',
    icon: Icons.event_note_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Sprint creation & goals',
      'Team capacity planning',
      'Velocity recommendations',
      'Story selection',
      'Definition of Ready',
      'AI sprint planning',
    ],
    route: AppRoutes.agileSprintCalendar,
    activeLabel: 'Agile Delivery Model - Sprint Calendar',
  ),
  AgileHubSection(
    number: 4,
    title: 'Iteration Management',
    sidebarTitle: 'Iteration Management',
    subtitle: 'Manage the lifecycle of each sprint',
    icon: Icons.repeat_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Sprint kickoff',
      'Daily progress tracking',
      'Blocker management',
      'Sprint completion',
      'Velocity calculation',
      'AI sprint summary',
    ],
    route: AppRoutes.agileIterationManagement,
    activeLabel: 'Agile Iteration Management',
  ),
  AgileHubSection(
    number: 5,
    title: 'Kanban Board',
    sidebarTitle: 'Kanban Board',
    subtitle: 'Visual work management board',
    icon: Icons.view_kanban_outlined,
    gradientStart: Color(0xFFEAB308),
    gradientEnd: Color(0xFFCA8A04),
    features: [
      'Standard & configurable columns',
      'Drag-and-drop workflow',
      'WIP limits',
      'Cycle time tracking',
      'Swimlanes',
      'AI recommendations',
    ],
    route: AppRoutes.agileKanbanBoard,
    activeLabel: 'Agile Kanban Board',
  ),
  AgileHubSection(
    number: 6,
    title: 'Daily Standups',
    sidebarTitle: 'Daily Standups',
    subtitle: 'Daily Agile ceremonies',
    icon: Icons.groups_outlined,
    gradientStart: Color(0xFFD97706),
    gradientEnd: Color(0xFFB45309),
    features: [
      'Yesterday / Today / Blockers',
      'Team attendance',
      'Action items',
      'Decision log',
      'AI standup summaries',
      'Team sentiment',
    ],
    route: AppRoutes.agileDailyStandups,
    activeLabel: 'Agile Daily Standups',
  ),
  AgileHubSection(
    number: 7,
    title: 'Sprint Reviews',
    sidebarTitle: 'Sprint Reviews',
    subtitle: 'Review completed work with stakeholders',
    icon: Icons.rate_review_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Completed story review',
      'Demonstrations',
      'Stakeholder feedback',
      'Product increment summary',
      'Action items',
      'AI review summary',
    ],
    route: AppRoutes.agileSprintReviews,
    activeLabel: 'Agile Sprint Reviews',
  ),
  AgileHubSection(
    number: 8,
    title: 'Sprint Retrospectives',
    sidebarTitle: 'Sprint Retrospectives',
    subtitle: 'Continuous improvement',
    icon: Icons.lightbulb_outline,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Start / Stop / Continue',
      'Mad / Sad / Glad',
      '4Ls & Sailboat templates',
      'Anonymous participation',
      'Action item tracking',
      'AI pattern recognition',
    ],
    route: AppRoutes.agileRetrospectives,
    activeLabel: 'Agile Retrospectives',
  ),
  AgileHubSection(
    number: 9,
    title: 'Backlog Grooming',
    sidebarTitle: 'Backlog Grooming',
    subtitle: 'Maintain backlog readiness',
    icon: Icons.tune_outlined,
    gradientStart: Color(0xFFEAB308),
    gradientEnd: Color(0xFFCA8A04),
    features: [
      'Story refinement & splitting',
      'Estimation updates',
      'Dependency review',
      'Duplicate detection',
      'AI story quality scoring',
      'Readiness assessment',
    ],
    route: AppRoutes.agileBacklogGovernance,
    activeLabel: 'Agile Delivery Model - Backlog Governance',
  ),
  AgileHubSection(
    number: 10,
    title: 'Agile Metrics & Reporting',
    sidebarTitle: 'Agile Metrics',
    subtitle: 'Comprehensive delivery analytics',
    icon: Icons.analytics_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFEAB308),
    features: [
      'Velocity & predictability',
      'Burndown & Burnup',
      'Lead time & Cycle time',
      'Escaped defects',
      'Sprint completion rate',
      'Release readiness',
    ],
    route: AppRoutes.agileMetrics,
    activeLabel: 'Agile Metrics',
  ),
  AgileHubSection(
    number: 11,
    title: 'Release Planning',
    sidebarTitle: 'Release Planning',
    subtitle: 'Coordinate multiple sprints into releases',
    icon: Icons.rocket_launch_outlined,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Release roadmap',
      'Sprint-to-release mapping',
      'Feature readiness',
      'Release forecasting',
      'Go-live checklist',
      'AI release risk analysis',
    ],
    route: AppRoutes.agileReleasePlan,
    activeLabel: 'Agile Delivery Model - Release Plan',
  ),
  AgileHubSection(
    number: 12,
    title: 'Agile Risks & Impediments',
    sidebarTitle: 'Agile Risks',
    subtitle: 'Track delivery blockers',
    icon: Icons.warning_amber_outlined,
    gradientStart: Color(0xFFD97706),
    gradientEnd: Color(0xFFB45309),
    features: [
      'Blocker log',
      'Escalation workflow',
      'Risk register integration',
      'Root cause tracking',
      'Resolution SLA',
      'AI risk prediction',
    ],
    route: AppRoutes.agileRisks,
    activeLabel: 'Agile Risks & Impediments',
  ),
  AgileHubSection(
    number: 13,
    title: 'Team Capacity & Workload',
    sidebarTitle: 'Team Capacity',
    subtitle: 'Support sustainable delivery',
    icon: Icons.fitness_center_outlined,
    gradientStart: Color(0xFFEAB308),
    gradientEnd: Color(0xFFCA8A04),
    features: [
      'Capacity planning',
      'Team allocation',
      'Vacation & leave tracking',
      'Skill coverage',
      'Burnout indicators',
      'AI workload optimization',
    ],
    route: AppRoutes.agileCapacityPlanning,
    activeLabel: 'Agile Delivery Model - Capacity Planning',
  ),
  AgileHubSection(
    number: 14,
    title: 'AI Agile Coach',
    sidebarTitle: 'AI Agile Coach',
    subtitle: 'Embedded guidance throughout execution',
    icon: Icons.auto_awesome,
    gradientStart: Color(0xFFF59E0B),
    gradientEnd: Color(0xFFD97706),
    features: [
      'Sprint planning recommendations',
      'Story writing assistance',
      'Estimation suggestions',
      'Risk identification',
      'Retrospective insights',
      'Agile maturity coaching',
    ],
    route: AppRoutes.agileAiCoach,
    activeLabel: 'AI Agile Coach',
  ),
  AgileHubSection(
    number: 15,
    title: 'Agile Roadmap',
    sidebarTitle: 'Agile Roadmap',
    subtitle: 'Strategic visual roadmap',
    icon: Icons.map_outlined,
    gradientStart: Color(0xFFD97706),
    gradientEnd: Color(0xFFB45309),
    features: [
      'Timeline & Hierarchical views',
      'Project progress tracking',
      'Milestone management',
      'Dependency mapping',
      'Business value tracking',
      'AI roadmap advisor',
    ],
    route: AppRoutes.agileRoadmap,
    activeLabel: 'Agile Project Hub - Agile Roadmap',
  ),
];

/// Every `"Agile Project Hub - <sub-page>"` label, for the sidebar's
/// `_isActiveLabel` checks.
final Set<String> agileHubSidebarLabels =
    agileHubSections.map((section) => section.sidebarLabel).toSet();

/// Every label a hub sub-page's target screen can declare as its active item.
///
/// Shared pages (backlog governance, sprint calendar, release plan, capacity
/// planning) also belong to the Planning phase, so the labels they report are
/// not hub-specific — but the hub is where the user came from, and the sidebar
/// has to keep the Agile Project Hub group highlighted while they are open.
final Set<String> agileHubTargetLabels =
    agileHubSections.map((section) => section.activeLabel).toSet();
