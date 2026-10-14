import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for pages outside the phase tour files: the agile
/// hub pages exposed under bare titles, the initiation overview, design
/// management, project controls, SSHER, start-up planning and team training.
final Map<String, PageTour> miscPageTours = {
  // ── Phase & module overviews ────────────────────────────────────────────
  'Initiation Phase': const PageTour(
    title: 'Initiation Phase',
    icon: Icons.flag_outlined,
    intro:
        'Kick the project off properly: build the business case, name the '
        'sponsor and manager, and capture the first view of scope, cost and '
        'risk before any money is committed.',
    bullets: [
      'Work top to bottom — each section feeds the next',
      'Use Next and Back to move between sections',
      'Press Escape at any time to leave the tour',
    ],
    outro:
        'The phase is complete when the charter is approved and the business '
        'case holds up to scrutiny.',
  ),
  'Project Controls': const PageTour(
    title: 'Project Controls',
    icon: Icons.tune_outlined,
    intro:
        'The controls room for the project: baselines, change management and '
        'the registers that keep cost, schedule and scope honest as the work '
        'progresses.',
    outro:
        'Controls only work when they are current. Update the registers as '
        'soon as reality changes.',
  ),
  'Design Management': const PageTour(
    title: 'Design Management',
    icon: Icons.design_services_outlined,
    intro:
        'Run the design effort from one hub: strategy, documents, '
        'architecture and the tools the design team uses day to day.',
    outro:
        'A design is managed when its reviews, versions and owners are all '
        'visible here.',
  ),
  'SSHER': const PageTour(
    title: 'SSHER',
    icon: Icons.health_and_safety_outlined,
    intro:
        'The safety, security, health and environment register. Record the '
        'hazards, controls and inspections that keep the site and the team '
        'safe.',
    sections: {
      'Safety':
          'Physical safety controls: site inductions, PPE requirements, '
          'permits to work and the inspection schedule.',
      'Security':
          'Physical and cyber security measures: access control, data '
          'protection and incident reporting.',
    },
    outro:
        'Escalate any uncontrolled hazard immediately — paperwork can wait, '
        'people cannot.',
  ),
  'Start-Up Planning': const PageTour(
    title: 'Start-Up Planning',
    icon: Icons.rocket_launch_outlined,
    intro:
        'Plan the hand-over from project to operations: readiness checklists, '
        'training, cutover and the hypercare period after launch.',
    sections: {
      'Go-Live Readiness Checklist':
          'Critical items required before launch. Nothing ships with an open '
          'red item.',
      'Training & Enablement':
          'Make sure every team is ready for launch day: materials, sessions '
          'and attendance.',
      'Cutover & Launch Timeline':
          'Sequenced steps for the go-live window, with owners and fallback '
          'points.',
      'Hypercare Plan':
          'Post-launch monitoring and support: who is on call and how issues '
          'escalate.',
    },
    outro:
        'Launch is a schedule, not a date. Keep the cutover plan rehearsed '
        'and current.',
  ),
  'Training & Team Building': const PageTour(
    title: 'Training & Team Building',
    icon: Icons.groups_outlined,
    intro:
        'Grow the team while the project runs: onboarding plans, '
        'discipline-specific training and the team-building activities that '
        'keep people working well together.',
    sections: {
      'Onboarding':
          'Get new joiners productive fast: accounts, buddies and the first '
          'week plan.',
      'New Onboarding':
          'Add an onboarding entry for a new team member and track it to '
          'done.',
      'Discipline-Specific':
          'Role-specific training paths per discipline, with completion '
          'tracking.',
    },
    outro:
        'Record training as it happens, not at review time — the history is '
        'what audits and handovers need.',
  ),

  // ── Agile pages exposed under bare titles ───────────────────────────────
  'AI Agile Coach': const PageTour(
    title: 'AI Agile Coach',
    icon: Icons.smart_toy_outlined,
    intro:
        'Ask an AI coach about your agile delivery: it reads the project '
        'context and answers questions about the backlog, cadence and '
        'impediments.',
    outro:
        'The coach advises; the team decides. Bring its suggestions to the '
        'next standup.',
  ),
  'Agile Dashboard': const PageTour(
    title: 'Agile Dashboard',
    icon: Icons.dashboard_outlined,
    intro:
        'The agile control tower: velocity, burndown and delivery health at '
        'a glance, so the team sees drift before the sprint feels it.',
    outro:
        'Check the dashboard in every review — trends matter more than any '
        'single number.',
  ),
  'Agile Metrics': const PageTour(
    title: 'Agile Metrics',
    icon: Icons.insights_outlined,
    intro:
        'Measure the delivery engine: throughput, cycle time and quality '
        'signals, tracked sprint over sprint.',
    outro:
        'Pick two metrics to improve this quarter. Improving ten means '
        'improving none.',
  ),
  'Agile Risks & Impediments': const PageTour(
    title: 'Agile Risks & Impediments',
    icon: Icons.warning_amber_outlined,
    intro:
        'Capture what could slow the team down: risks to delivery and the '
        'impediments blocking work right now, each with an owner.',
    outro:
        'An impediment without an owner is a wish. Assign one before you '
        'leave this page.',
  ),
  'Daily Standups': const PageTour(
    title: 'Daily Standups',
    icon: Icons.record_voice_over_outlined,
    intro:
        'Run the daily standup: yesterday, today and blockers for each team '
        'member, logged so nothing said in the meeting is lost.',
    outro:
        'Blockers raised here should appear on the impediments register the '
        'same day.',
  ),
  'Iteration Management': const PageTour(
    title: 'Iteration Management',
    icon: Icons.autorenew_outlined,
    intro:
        'Plan and steer iterations: goals, capacity, scope commitments and '
        'the mid-iteration adjustments that keep delivery honest.',
    outro:
        'Close every iteration with a review and a retro — the next one '
        'starts better.',
  ),
  'Sprint Retrospectives': const PageTour(
    title: 'Sprint Retrospectives',
    icon: Icons.forum_outlined,
    intro:
        'Reflect as a team: what worked, what did not and the one or two '
        'experiments that will make the next sprint better.',
    outro:
        'A retro without an action item is a complaint session. Leave with '
        'experiments and owners.',
  ),
  'Sprint Reviews': const PageTour(
    title: 'Sprint Reviews',
    icon: Icons.rate_review_outlined,
    intro:
        'Show the increment to stakeholders: what is done, what they accept '
        'and what the feedback changes in the backlog.',
    outro:
        'Record acceptance decisions here — they are the contract with the '
        'business.',
  ),
  'Kanban Board': const PageTour(
    title: 'Kanban Board',
    icon: Icons.view_kanban_outlined,
    intro:
        'The work board: cards flow left to right, WIP limits keep focus, '
        'and the blocked column is where impediments surface first.',
    outro:
        'Pull, do not push — finish work before starting more.',
  ),
};
