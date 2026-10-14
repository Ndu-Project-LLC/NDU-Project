import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Planning phase pages.
///
/// Keys are the exact page ids the headers pass in (breadcrumb title when set,
/// otherwise the title). Section entries are keyed by the exact on-screen
/// heading text; headings not listed here use the generic line.
final Map<String, PageTour> planningPageTours = {
  'Risk Assessment': const PageTour(
    title: 'Risk Assessment',
    icon: Icons.warning_amber_outlined,
    intro:
        'Identify, score and plan responses for project risks. Start with the '
        'risk log, then record mitigation and ownership for each risk.',
    sections: {
      'Risk Log':
          'Every identified risk, its likelihood and impact, and its current '
              'status. Add new risks here first.',
    },
    outro:
        'Keep the log current as risks change. Mitigation and ownership you '
        'set here feed the project controls.',
  ),
  'Schedule': const PageTour(
    title: 'Schedule',
    icon: Icons.calendar_month_outlined,
    intro:
        'Build the project timeline: tasks, durations, dependencies and '
        'milestones. Use it to see how work sequences across the project.',
    outro:
        'Adjust durations and dependencies as you learn more. Later pages '
        'use these dates for baselines and reporting.',
  ),
  'Cost Estimate': const PageTour(
    title: 'Cost Estimate',
    icon: Icons.attach_money_outlined,
    intro:
        'Estimate what the project will cost, line by line. Start from the '
        'initiation baseline, then record planning adjustments.',
    sections: {
      'Initiation baseline':
          'The budget and cost figures agreed at initiation. Use these as the '
              'starting point for the estimate.',
      'Planning adjustments':
          'Changes made during planning that move the estimate away from the '
              'initiation baseline, with the reason for each.',
    },
    outro:
        'Check the total against the baseline before you move on. Differences '
        'should be explained, not left unexplained.',
  ),
  'Change Management': const PageTour(
    title: 'Change Management',
    icon: Icons.swap_horiz_outlined,
    intro:
        'Record requested changes to scope, schedule or cost, assess their '
        'impact, and track each one to a decision.',
    outro:
        'Every approved change should flow back into the schedule, cost and '
        'risk pages so the plan stays accurate.',
  ),
  'Issue Management': const PageTour(
    title: 'Issue Management',
    icon: Icons.report_problem_outlined,
    intro:
        'Log issues that are already affecting the project, assign an owner '
        'and track each one until it is resolved.',
    outro:
        'Issues differ from risks: they have happened. Escalate any issue '
        'that blocks a milestone.',
  ),
  'Lessons Learned': const PageTour(
    title: 'Lessons Learned',
    icon: Icons.school_outlined,
    intro:
        'Capture what went well, what did not, and what to change. Record '
        'lessons as they happen so they are not lost at closeout.',
    sections: {
      'Lessons Learned — Tasks':
          'Actions that come out of each lesson, with an owner and a due date.',
    },
    outro:
        'Lessons are only useful if someone acts on them. Give each one an '
        'owner.',
  ),
  'Interface Management Plan': const PageTour(
    title: 'Interface Management Plan',
    icon: Icons.device_hub_outlined,
    intro:
        'Define the handoffs and connections between this project and other '
        'teams, systems or vendors, and who manages each one.',
    outro:
        'Each interface needs one owner on each side. Gaps here usually show '
        'up as delays later.',
  ),
  'Stakeholder Management Plan': const PageTour(
    title: 'Stakeholder Management Plan',
    icon: Icons.groups_outlined,
    intro:
        'Plan how you will engage each stakeholder: their influence, what they '
        'need to know, and how often you will update them.',
    sections: {
      'Stakeholders':
          'The people and groups with a stake in the project, and the level of '
              'engagement each one needs.',
    },
    outro:
        'Revisit this plan when the project changes. A stakeholder you missed '
        'early is hard to recover later.',
  ),
  'Quality Management': const PageTour(
    title: 'Quality Management',
    icon: Icons.verified_outlined,
    intro:
        'Set the quality standards, checks and acceptance criteria the project '
        'must meet, and who signs off on each.',
    outro:
        'Quality is planned here and verified during execution. Make the '
        'criteria measurable so they can be checked.',
  ),
  'Startup Planning': const PageTour(
    title: 'Startup Planning',
    icon: Icons.rocket_launch_outlined,
    intro:
        'Prepare everything needed to start the work: readiness checks, '
        'resources, and the go-live checklist.',
    sections: {
      'Go-Live Readiness Checklist':
          'The items that must be complete before work or launch can begin.',
    },
    outro:
        'Do not start execution until the readiness checklist is complete or '
        'each open item has an agreed owner and date.',
  ),
  'Team Training': const PageTour(
    title: 'Team Training',
    icon: Icons.school_outlined,
    intro:
        'Plan how the team will be onboarded and trained, and how the team '
        'will be built to deliver the project.',
    sections: {
      'Onboarding':
          'How new team members are brought up to speed, what they learn, and '
              'who guides them.',
    },
    outro:
        'Training that is planned early is cheaper than training that is '
        'rushed in the middle of delivery.',
  ),
  'Project Framework': const PageTour(
    title: 'Project Framework',
    icon: Icons.account_tree_outlined,
    intro:
        'Set the core project details and the delivery approach that the rest '
        'of the plan builds on.',
    sections: {
      'Project Details':
          'The basic facts about the project that every later page reuses. '
              'Check these first.',
    },
    outro:
        'Changes here flow into other pages, so review the framework before '
        'you complete the later planning steps.',
  ),
  'WBS': const PageTour(
    title: 'Work Breakdown Structure',
    icon: Icons.format_list_numbered_outlined,
    intro:
        'Break the project into deliverables and work packages. Use the WBS '
        'to see the full scope before you schedule or cost it.',
    outro:
        'Every piece of work should sit under one parent. Items that do not '
        'fit usually point to missing scope.',
  ),
  'Project Baseline': const PageTour(
    title: 'Project Baseline',
    icon: Icons.flag_outlined,
    intro:
        'Lock the approved schedule, cost and scope as the baseline. Later '
        'progress is measured against this snapshot.',
    sections: {
      'Schedule Summary':
          'The approved timeline the project will be measured against.',
      'Cost Summary': 'The approved budget the project will be measured against.',
      'Scope Summary':
          'The approved scope the project will be measured against.',
    },
    outro:
        'Once the baseline is approved, changes need to go through change '
        'management so the record stays honest.',
  ),
  'Deliverables Roadmap': const PageTour(
    title: 'Deliverables Roadmap',
    icon: Icons.map_outlined,
    intro:
        'Plan when each deliverable will be produced and in what order, so '
        'the team knows what is coming next.',
    outro:
        'Keep the roadmap aligned with the schedule. A deliverable that is not '
        'on the roadmap is easy to forget.',
  ),
};
