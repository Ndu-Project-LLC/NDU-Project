import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Front End Planning and planning-support pages.
final Map<String, PageTour> frontEndPlanningPageTours = {
  'Allowance': const PageTour(
    title: 'Allowance',
    intro:
        'Set aside a contingency allowance for costs you cannot yet pin down. '
        'Record the basis for each allowance so it can be justified later.',
    outro:
        'Allowances should shrink as the design firms up. Release unused amounts '
        'deliberately rather than letting them disappear.',
  ),
  'Front End Infrastructure': const PageTour(
    title: 'Front End Infrastructure',
    intro:
        'Plan the infrastructure the front end work needs, from facilities to '
        'utilities, and note what must be in place before construction begins.',
    outro:
        'Confirm the infrastructure items against the schedule so none of them '
        'becomes a late surprise.',
  ),
  'Milestone': const PageTour(
    title: 'Milestone',
    intro:
        'Define the key milestones for the front end work, with a date and an '
        'owner for each. Milestones are the checkpoints the project is judged on.',
    outro:
        'Milestones you set here are the ones reported upward. Keep them '
        'realistic.',
  ),
  'Project Opportunities': const PageTour(
    title: 'Project Opportunities',
    intro:
        'Record the opportunities the project could take advantage of, such as '
        'savings, reuse or faster delivery, and how each would be captured.',
    outro:
        'An opportunity without an owner rarely gets realised. Assign one to '
        'each entry.',
  ),
  'Front End Personnel': const PageTour(
    title: 'Front End Personnel',
    intro:
        'Plan the people the front end phase needs: roles, skills and when each '
        'person is required.',
    outro:
        'Check that every key role has a named person or a recruitment plan '
        'before the phase starts.',
  ),
  'Front End Procurement': const PageTour(
    title: 'Front End Procurement',
    intro:
        'Plan what the front end phase must buy or contract for, with the '
        'lead time and the route to market for each item.',
    outro:
        'Long lead items drive the schedule. Start those first.',
  ),
  'Project Requirements': const PageTour(
    title: 'Project Requirements',
    intro:
        'Write down what the project must deliver. Each requirement should be '
        'clear enough to test once the work is done.',
    outro:
        'Requirements feed the scope, the design and the acceptance criteria. '
        'Change them through control, not quietly.',
  ),
  'Project Risks': const PageTour(
    title: 'Project Risks',
    intro:
        'Log the risks specific to the front end phase, with their likelihood, '
        'impact and the response you plan.',
    outro:
        'Risks with no response or owner stay open. Give each one both.',
  ),
  'Security': const PageTour(
    title: 'Security',
    intro:
        'Define the security needs for the project: access, data protection, '
        'compliance and who approves exceptions.',
    outro:
        'Security requirements are cheapest to design in early. Review them with '
        'the security owner.',
  ),
  'Front End Details': const PageTour(
    title: 'Front End Details',
    intro:
        'Capture the detail behind the front end plan, so the summary that follows '
        'rests on something you can point to.',
    outro:
        'Make sure every figure on the summary traces back to a detail here.',
  ),
  'Front End Summary': const PageTour(
    title: 'Front End Summary',
    intro:
        'Review the front end plan as a whole: scope, cost, schedule, people and '
        'risks on one page, before you submit it for approval.',
    outro:
        'Approval here commits the project to the next phase. Resolve open items '
        'first.',
  ),
  'Front End Technology Personnel': const PageTour(
    title: 'Front End Technology Personnel',
    intro:
        'Plan the technical roles the front end work needs, such as engineers, '
        'architects and specialists, and when each is needed.',
    outro:
        'Technical roles that are missing here often show up later as delays. '
        'Plan them now.',
  ),
  'Front End Workspace': const PageTour(
    title: 'Front End Workspace',
    intro:
        'Use this workspace to bring together the front end inputs in one place '
        'and see what is complete and what is still open.',
    outro:
        'Move items to complete as they are agreed, so the summary stays current.',
  ),
  'Contracting': const PageTour(
    title: 'Contracting',
    intro:
        'Plan the contracts the project needs: scope, value, terms and the vendor '
        'or partner for each one.',
    outro:
        'Contract terms set what the project can enforce later. Check them '
        'against the requirements.',
  ),
  'Procurement': const PageTour(
    title: 'Procurement',
    intro:
        'Plan how the project will buy what it needs, including the items, the '
        'suppliers and the timing of each purchase.',
    outro:
        'Procurement timing often sets the critical path. Confirm it against the '
        'schedule.',
  ),
  'Project Summary': const PageTour(
    title: 'Project Summary',
    intro:
        'Review the front end plan on one page: scope, cost, schedule, people '
        'and the main risks, before it goes forward for approval.',
    outro:
        'Resolve the open items here first. Approval commits the project to the '
        'next phase.',
  ),
  'Requirements': const PageTour(
    title: 'Requirements',
    intro:
        'Set out the requirements that the solution has to meet during planning, '
        'with the source and priority of each.',
    outro:
        'Track each requirement through to design and testing so none is lost.',
  ),
  'Technology Planning': const PageTour(
    title: 'Technology Planning',
    intro:
        'Choose the technology the solution will use and record why, including '
        'the platforms, tools and integrations.',
    outro:
        'Technology choices affect cost, skills and risk. Note any decisions that '
        'are still open.',
  ),
  'Staffing Plan': const PageTour(
    title: 'Staffing Plan',
    intro:
        'Plan how many people the project needs, in which roles, and when each '
        'role must be filled.',
    outro:
        'A staffing plan that is short on skills is a schedule risk. Check '
        'availability against the plan.',
  ),
  'RACI Matrix': const PageTour(
    title: 'RACI Matrix',
    intro:
        'Show who is Responsible, Accountable, Consulted and Informed for each '
        'key activity, so ownership is never unclear.',
    outro:
        'Every activity should have exactly one Accountable person. Check for '
        'gaps before you publish the matrix.',
  ),
  'Roles & Responsibilities': const PageTour(
    title: 'Roles & Responsibilities',
    intro:
        'Describe each project role and what it is responsible for. Clear roles '
        'prevent work from being dropped between people.',
    outro:
        'Match these roles to the RACI matrix and the staffing plan so the three '
        'agree.',
  ),
  'Project Plan Overview': const PageTour(
    title: 'Project Plan Overview',
    intro:
        'See the project plan at a glance: the main work areas, their timing and '
        'how they connect.',
    outro:
        'Use the overview to spot gaps before you dig into the detailed pages.',
  ),
  'Project Schedule': const PageTour(
    title: 'Project Schedule',
    intro:
        'Lay out the project schedule by phase and activity, with the dates and '
        'the dependencies between them.',
    outro:
        'Keep the schedule consistent with the milestones and procurement lead '
        'times.',
  ),
  'Identify and Staff Ops Team': const PageTour(
    title: 'Identify and Staff Ops Team',
    intro:
        'Identify the operations team that will run the solution after go-live '
        'and plan how to staff it.',
    outro:
        'Involve operations early. The people who will run the system should help '
        'shape it.',
  ),
  'Launch Checklist': const PageTour(
    title: 'Launch Checklist',
    intro:
        'Work through the checklist of everything that must be true before '
        'launch, and mark each item done or open.',
    outro:
        'Any open item needs an owner and a date. Do not launch with unowned gaps.',
  ),
  'Long Lead Equipment Ordering': const PageTour(
    title: 'Long Lead Equipment Ordering',
    intro:
        'Track equipment with long delivery times, so orders are placed early '
        'enough to hold the schedule.',
    outro:
        'Record the order date and expected delivery for each item and check them '
        'against the schedule.',
  ),
  'Gap Analysis and Scope Reconciliation': const PageTour(
    title: 'Gap Analysis and Scope Reconciliation',
    intro:
        'Compare what the project is meant to deliver with what is currently '
        'planned, and reconcile the differences.',
    outro:
        'Every gap needs a decision: add it to scope, defer it, or drop it, with '
        'the reason recorded.',
  ),
  'Scope & Deliverable Reconciliation': const PageTour(
    title: 'Scope & Deliverable Reconciliation',
    intro:
        'Check that the scope and the deliverables match. Any deliverable without '
        'scope, or scope without a deliverable, is flagged here.',
    outro:
        'Reconcile before the baseline is set, so the baseline is trustworthy.',
  ),
};
