import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Agile Hub and agile delivery pages.
final Map<String, PageTour> agilePageTours = {
  'Acceptance Criteria Planning': const PageTour(
    title: 'Acceptance Criteria Planning',
    icon: Icons.fact_check_outlined,
    intro:
        'Define the acceptance criteria for each story or feature: what must be '
        'true for the work to be accepted by the product owner.',
    outro:
        'Write criteria that can be tested. Vague criteria lead to disputes at '
        'review.',
  ),
  'Agile Delivery Model': const PageTour(
    title: 'Agile Delivery Model',
    icon: Icons.loop_outlined,
    intro:
        'Choose and describe the agile delivery model: the framework, the team '
        'roles and how work flows from idea to release.',
    outro:
        'Agree the model with the team before the first sprint, then review it '
        'after a few iterations.',
  ),
  'Agile Development Iterations': const PageTour(
    title: 'Agile Development Iterations',
    icon: Icons.repeat_outlined,
    intro:
        'Plan the development iterations: what each one will deliver, its length '
        'and the goal it is working towards.',
    outro:
        'Each iteration should end with something working. Adjust the plan as '
        'the team learns its pace.',
  ),
  'Agile Hub › Kanban Board': const PageTour(
    title: 'Kanban Board',
    icon: Icons.view_kanban_outlined,
    intro:
        'See the work as it moves across the board, from backlog to done, and '
        'spot where items are stuck.',
    outro:
        'Limit work in progress. Items that sit in one column for long need '
        'attention.',
  ),
  'Agile Hub › AI Coach': const PageTour(
    title: 'AI Coach',
    icon: Icons.auto_awesome_outlined,
    intro:
        'Ask the AI coach for help with agile practice: planning, backlog '
        'quality, retrospectives or team dynamics.',
    outro:
        'Treat suggestions as a starting point. The team knows its context best.',
  ),
  'Agile Hub › Daily Standups': const PageTour(
    title: 'Daily Standups',
    icon: Icons.record_voice_over_outlined,
    intro:
        'Record the daily standup: what was done, what is planned next and what '
        'is blocking progress.',
    outro:
        'Keep standups short. Anything that needs discussion goes to a separate '
        'conversation.',
  ),
  'Agile Hub › Dashboard': const PageTour(
    title: 'Agile Dashboard',
    icon: Icons.dashboard_outlined,
    intro:
        'See the agile hub at a glance: the current iteration, the progress '
        'against it and the items that need attention.',
    outro:
        'Use the dashboard to decide where to look next, then open the detailed '
        'page.',
  ),
  'Agile Hub › Iteration Management': const PageTour(
    title: 'Iteration Management',
    icon: Icons.event_repeat_outlined,
    intro:
        'Manage each iteration: its scope, its capacity and whether it is on track '
        'to meet its goal.',
    outro:
        'Move unfinished work deliberately. Carrying items forward silently hides '
        'overcommitment.',
  ),
  'Agile Hub › Metrics': const PageTour(
    title: 'Agile Metrics',
    icon: Icons.bar_chart_outlined,
    intro:
        'Review the delivery measures for the team, such as velocity, throughput '
        'and cycle time, and what they show.',
    outro:
        'Read trends rather than single values. Use the numbers to start a '
        'conversation, not to judge people.',
  ),
  'Agile Hub › Retrospectives': const PageTour(
    title: 'Retrospectives',
    icon: Icons.forum_outlined,
    intro:
        'Capture what went well, what did not and what the team will change in '
        'the next iteration.',
    outro:
        'Pick a few changes and give each one an owner. A long list rarely gets '
        'acted on.',
  ),
  'Agile Hub › Risks & Impediments': const PageTour(
    title: 'Risks & Impediments',
    icon: Icons.report_outlined,
    intro:
        'Log the risks and impediments slowing the team, with an owner and a '
        'target date for each.',
    outro:
        'Impediments are the team’s to escalate. Raise anything you cannot clear '
        'within the iteration.',
  ),
  'Agile Hub › Sprint Reviews': const PageTour(
    title: 'Sprint Reviews',
    icon: Icons.preview_outlined,
    intro:
        'Record the sprint review: what was demonstrated, what was accepted and '
        'the feedback that will shape the next backlog.',
    outro:
        'Only accepted work counts as done. Record feedback against the items it '
        'relates to.',
  ),
  'Agile Metrics Planning': const PageTour(
    title: 'Agile Metrics Planning',
    icon: Icons.insights_outlined,
    intro:
        'Decide which agile measures the project will track, how each is '
        'calculated and how often it is reviewed.',
    outro:
        'Choose a few measures that drive decisions. Too many metrics get ignored.',
  ),
  'Agile Project Baseline': const PageTour(
    title: 'Agile Project Baseline',
    icon: Icons.flag_outlined,
    intro:
        'Set the agile baseline: the release goals, the expected scope and the '
        'timing the team is measured against.',
    outro:
        'Change the baseline through control when scope moves, so progress stays '
        'measurable.',
  ),
  'Agile Task Board': const PageTour(
    title: 'Agile Task Board',
    icon: Icons.checklist_outlined,
    intro:
        'Manage the tasks for the current work on one board, with an owner and '
        'status for each task.',
    outro:
        'Keep tasks small enough to finish in a few days. Split any that are not.',
  ),
  'Agile Team Structure': const PageTour(
    title: 'Agile Team Structure',
    icon: Icons.groups_outlined,
    intro:
        'Describe the agile teams: their members, the roles they play and how the '
        'teams are organised around the work.',
    outro:
        'Make sure each team can deliver a useful slice on its own where possible.',
  ),
  'Backlog Governance': const PageTour(
    title: 'Backlog Governance',
    icon: Icons.rule_outlined,
    intro:
        'Set the rules for the backlog: who can add to it, how items are ranked '
        'and what must be true before work is pulled in.',
    outro:
        'A governed backlog stays small and current. Review it on a regular cycle.',
  ),
  'Capacity Planning': const PageTour(
    title: 'Capacity Planning',
    icon: Icons.speed_outlined,
    intro:
        'Compare the team’s available capacity with the work planned, allowing '
        'for leave, support and meetings.',
    outro:
        'Plan to real capacity, not full capacity. Overcommitment is the most '
        'common reason iterations slip.',
  ),
  'Epics & Features Planning': const PageTour(
    title: 'Epics & Features Planning',
    icon: Icons.account_tree_outlined,
    intro:
        'Break the product into epics and features, each linked to the business '
        'value it delivers.',
    outro:
        'Epics should be large and features should be deliverable. Keep the '
        'hierarchy clear.',
  ),
  'Kanban Workflow Configuration': const PageTour(
    title: 'Kanban Workflow Configuration',
    icon: Icons.settings_outlined,
    intro:
        'Set up the workflow stages the board uses, with the work-in-progress '
        'limit for each.',
    outro:
        'Name the stages so anyone can tell what work in each one means.',
  ),
  'Release Plan': const PageTour(
    title: 'Release Plan',
    icon: Icons.rocket_launch_outlined,
    intro:
        'Plan the releases: what each one contains, when it ships and what must '
        'be ready before it does.',
    outro:
        'Confirm each release against its readiness criteria before you commit '
        'to a date.',
  ),
  'Scrum Configuration': const PageTour(
    title: 'Scrum Configuration',
    icon: Icons.tune_outlined,
    intro:
        'Configure the scrum setup: sprint length, ceremonies, roles and the '
        'definition of done.',
    outro:
        'Write the definition of done down. The team should all mean the same thing.',
  ),
  'Sprint Cadence & Calendar': const PageTour(
    title: 'Sprint Cadence & Calendar',
    icon: Icons.calendar_today_outlined,
    intro:
        'Set the sprint rhythm and the calendar: start and end dates, planning, '
        'reviews and retrospectives.',
    outro:
        'Keep the cadence steady. Changing sprint length often breaks the '
        'team’s planning.',
  ),
  'Stories & Backlog Breakdown': const PageTour(
    title: 'Stories & Backlog Breakdown',
    icon: Icons.view_list_outlined,
    intro:
        'Write the user stories that make up the backlog, each with its size, '
        'priority and acceptance criteria.',
    outro:
        'Stories that cannot be sized or tested are not ready. Refine them before '
        'planning.',
  ),
};
