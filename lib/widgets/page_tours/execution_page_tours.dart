import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Execution phase pages.
final Map<String, PageTour> executionPageTours = {
  'Execution Plan': const PageTour(
    title: 'Execution Plan',
    intro:
        'The execution plan is the hub for how the work will be carried out. Use '
        'it to move between the detailed plans for interfaces, communication and '
        'construction.',
    outro:
        'Start from here when you need to see how the execution pages fit '
        'together.',
  ),
  'Execution Plan Overview': const PageTour(
    title: 'Execution Plan Overview',
    intro:
        'Set out how the project will be executed: the approach, the work areas '
        'and how they are governed. Other execution plan pages go into detail.',
    outro:
        'Keep the overview consistent with the detailed plans behind it.',
  ),
  'Execution Plan Details': const PageTour(
    title: 'Execution Plan Details',
    intro:
        'Record the detail behind the execution approach, so each area of work '
        'has a clear method and owner.',
    outro:
        'Detail is what the teams will work from. Be specific about who does what.',
  ),
  'Execution Plan - Best Practices': const PageTour(
    title: 'Execution Plan - Best Practices',
    intro:
        'Capture the practices the project will follow during execution, such as '
        'reviews, quality checks and handover standards.',
    outro:
        'Good practices only help if people use them. Name who enforces each one.',
  ),
  'Execution Plan - Communication Plan': const PageTour(
    title: 'Execution Plan - Communication Plan',
    intro:
        'Plan how information flows during execution: who needs what, how often, '
        'and through which channel.',
    outro:
        'A communication plan works only if it is kept. Review it when the team '
        'or the audience changes.',
  ),
  'Execution Plan - Construction Plan': const PageTour(
    title: 'Execution Plan - Construction Plan',
    intro:
        'Plan the construction work: sequences, crews, access and the checks that '
        'must pass before each stage.',
    outro:
        'Check the construction sequence against the schedule and the site '
        'constraints.',
  ),
  'Execution Plan - Infrastructure Plan': const PageTour(
    title: 'Execution Plan - Infrastructure Plan',
    intro:
        'Plan the infrastructure work during execution: what gets installed, in '
        'what order, and how it is tested.',
    outro:
        'Infrastructure must be ready before the work that depends on it. Check '
        'the order.',
  ),
  'Execution Interface Management Plan': const PageTour(
    title: 'Execution Interface Management Plan',
    intro:
        'Plan how interfaces between teams, vendors and systems will be managed '
        'during execution, with an owner for each interface.',
    outro:
        'Unowned interfaces are where work falls between teams. Assign each one.',
  ),
  'Execution Interface Management': const PageTour(
    title: 'Execution Interface Management',
    intro:
        'Track each interface during execution: its status, the open points and '
        'who is resolving them.',
    outro:
        'Escalate any interface blocked for more than a short time.',
  ),
  'Execution Lessons Learned': const PageTour(
    title: 'Execution Lessons Learned',
    intro:
        'Record what is working and what is not during execution, while the '
        'details are still fresh.',
    outro:
        'Lessons that are noted now can change the next stage, not just the report.',
  ),
  'Executive Plan Strategy': const PageTour(
    title: 'Executive Plan Strategy',
    intro:
        'Set the strategy for executing the solution: the approach chosen, the '
        'main trade-offs, and the outcomes it must deliver.',
    outro:
        'The strategy guides the detailed plans. Revisit it if the scope changes.',
  ),
  'Execution Stakeholder Identification': const PageTour(
    title: 'Execution Stakeholder Identification',
    intro:
        'Identify the stakeholders who matter during execution, their influence, '
        'and what they need to hear.',
    outro:
        'Stakeholders change during execution. Update this list as new people '
        'become involved.',
  ),
  'Execution Enabling Work Plan': const PageTour(
    title: 'Execution Enabling Work Plan',
    intro:
        'Plan the enabling work that must happen before the main execution work '
        'can start, such as access, permits and set-up.',
    outro:
        'Enabling work often sits on the critical path. Track it as closely as the '
        'main work.',
  ),
  'Execution Issue Management': const PageTour(
    title: 'Execution Issue Management',
    intro:
        'Log the issues that are affecting execution now, assign an owner, and '
        'track each one to resolution.',
    outro:
        'An issue with no owner or date is not being managed. Give each one both.',
  ),
  'Agile Delivery Plan': const PageTour(
    title: 'Agile Delivery Plan',
    intro:
        'Plan how the work will be delivered in agile increments, including the '
        'cadence, roles and the release points.',
    outro:
        'Use the plan to agree expectations with the team, then let the backlog '
        'drive the detail.',
  ),
  'Execution Quality Tracking': const PageTour(
    title: 'Execution Quality Tracking',
    intro:
        'Track the quality checks during execution: what was tested, what passed, '
        'and what needs rework.',
    outro:
        'Look at trends, not just single results. Repeated failures point to a cause.',
  ),
  'Execution Work Packages': const PageTour(
    title: 'Execution Work Packages',
    intro:
        'Break the execution work into work packages, each with a scope, an owner '
        'and a due date.',
    outro:
        'A good work package can be finished and checked on its own.',
  ),
  'Progress Tracking': const PageTour(
    title: 'Progress Tracking',
    intro:
        'Track progress against the plan: what is complete, what is late and what '
        'is coming up.',
    outro:
        'Report progress against the baseline, not against last week, so drift is '
        'visible.',
  ),
  'Status Reports': const PageTour(
    title: 'Status Reports',
    intro:
        'Prepare the status report for the project: progress, risks, issues and '
        'the decisions needed.',
    outro:
        'Keep the report short enough to read in a few minutes. Put decisions '
        'first.',
  ),
  'Project Performance Review': const PageTour(
    title: 'Project Performance Review',
    intro:
        'Review how the project is performing against its cost, schedule and '
        'quality measures, and what that means for the forecast.',
    outro:
        'Use the review to agree corrective actions, with an owner and a date for '
        'each.',
  ),
  'Team Meetings': const PageTour(
    title: 'Team Meetings',
    intro:
        'Record the team meetings: their purpose, attendees, the actions agreed '
        'and who owns each one.',
    outro:
        'Follow up on actions at the next meeting. Unfollowed actions are lost.',
  ),
  'Team Status Check': const PageTour(
    title: 'Team Status Check',
    intro:
        'Check where each team stands: its workload, its blockers and how '
        'confident it is in its commitments.',
    outro:
        'Raise blockers early. A quick check now saves a missed milestone later.',
  ),
  'Team Management': const PageTour(
    title: 'Team Management',
    intro:
        'Manage the project team: roles, capacity and performance, and the '
        'actions needed to keep people productive.',
    outro:
        'Balance capacity against the work each person is committed to.',
  ),
  'Staff Team': const PageTour(
    title: 'Staff Team',
    intro:
        'Record the people on the team, their roles and their availability, so '
        'gaps are visible.',
    outro:
        'Keep the list current as people join or leave.',
  ),
  'Team Handover Checklist': const PageTour(
    title: 'Team Handover Checklist',
    intro:
        'Work through the checklist for handing the team over: knowledge, access, '
        'documents and open items.',
    outro:
        'Confirm each item with the receiving team. Handover is complete only when '
        'they accept it.',
  ),
  'Punchlist Actions': const PageTour(
    title: 'Punchlist Actions',
    intro:
        'List the remaining defects and small items that must be closed before '
        'acceptance, each with an owner.',
    outro:
        'Close the punchlist in priority order and re-check each item before you '
        'sign it off.',
  ),
  'Operations Control': const PageTour(
    title: 'Operations Control',
    intro:
        'Set up the controls the operations team will use to run the solution: '
        'monitoring, thresholds and escalation.',
    outro:
        'Test the controls before handover so the operations team trusts them.',
  ),
  'Update Ops and Maintenance Plans': const PageTour(
    title: 'Update Ops and Maintenance Plans',
    intro:
        'Update the operations and maintenance plans to match what was actually '
        'built and handed over.',
    outro:
        'Plans that do not match the asset are a risk. Check them against the '
        'delivered solution.',
  ),
  'Security Management': const PageTour(
    title: 'Security Management',
    intro:
        'Manage the security controls during execution: access, incidents and '
        'the reviews that keep them effective.',
    outro:
        'Review access rights regularly, especially after team changes.',
  ),
  'Stakeholder Alignment': const PageTour(
    title: 'Stakeholder Alignment',
    intro:
        'Check that stakeholders agree on scope, timing and what success looks '
        'like, and record where they still differ.',
    outro:
        'Any disagreement left open becomes a change request later. Close them '
        'early.',
  ),
  'Scope Tracking Implementation': const PageTour(
    title: 'Scope Tracking Implementation',
    intro:
        'Track the scope as it is delivered: what is in, what is out, and what '
        'has changed since the baseline.',
    outro:
        'Every scope change should go through change control and be recorded here.',
  ),
  'Scope Completion': const PageTour(
    title: 'Scope Completion',
    intro:
        'Confirm which scope items are complete, which are partly done, and what '
        'evidence supports each status.',
    outro:
        'Only mark scope complete when the acceptance evidence is in place.',
  ),
  'Vendor Tracking': const PageTour(
    title: 'Vendor Tracking',
    intro:
        'Track each vendor: what they deliver, the milestones they owe, and any '
        'performance issues.',
    outro:
        'Raise vendor performance problems early, while there is still time to '
        'recover them.',
  ),
  'Contracts Tracking': const PageTour(
    title: 'Contracts Tracking',
    intro:
        'Track the contracts in force: their value, their dates and the obligations '
        'each party still owes.',
    outro:
        'Check obligations against the schedule. A missed contract date is a '
        'delay you can see coming.',
  ),
  'Contract Details': const PageTour(
    title: 'Contract Details',
    intro:
        'Review the terms of a single contract: scope, value, payment milestones '
        'and the key clauses.',
    outro:
        'Keep the terms summary accurate. It is what the team checks when a '
        'dispute starts.',
  ),
  'FAT, Mechanical Completion & Commission Solution': const PageTour(
    title: 'FAT, Mechanical Completion & Commission Solution',
    intro:
        'Plan the factory acceptance tests, mechanical completion and commissioning '
        'steps the solution must pass before handover.',
    outro:
        'Each test needs a pass criterion agreed in advance. Record results as '
        'they happen.',
  ),
  'Deployment Transfer, Certification & Release': const PageTour(
    title: 'Deployment Transfer, Certification & Release',
    intro:
        'Plan the transfer of the solution into production: certification steps, '
        'release approval and the handover to the production team.',
    outro:
        'Do not release until certification is signed. Keep the release record '
        'complete.',
  ),
  'Recognition & Awards': const PageTour(
    title: 'Recognition & Awards',
    intro:
        'Record the people and teams whose work should be recognised, and the '
        'reason for each recognition.',
    outro:
        'Recognition is more useful when it is specific. Say what the person did.',
  ),
  'Team Demobilization & Operations/Production Transition': const PageTour(
    title: 'Team Demobilization & Operations/Production Transition',
    intro:
        'Plan how the project team stands down and how responsibility passes to '
        'operations and production.',
    outro:
        'Confirm the receiving owner for every item before the team leaves.',
  ),
};
