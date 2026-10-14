import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Design phase pages.
final Map<String, PageTour> designPageTours = {
  'Design Planning': const PageTour(
    title: 'Design Planning',
    intro:
        'Plan the design work: the design disciplines involved, the outputs each '
        'one owes, and the order they need to happen in.',
    outro:
        'Design planning sets the sequence for everything that follows. Agree it '
        'with the leads before design starts.',
  ),
  'Design Deliverables': const PageTour(
    title: 'Design Deliverables',
    intro:
        'Track each design deliverable from authoring through review, approval '
        'and handover, with the evidence that proves it is complete.',
    outro:
        'A deliverable is only done when its acceptance evidence is attached and '
        'approved.',
  ),
  'Detailed Design': const PageTour(
    title: 'Detailed Design',
    intro:
        'Work out the detailed design of the solution: components, interfaces and '
        'the decisions behind them.',
    outro:
        'Record the reasons for each major design decision so reviewers can '
        'follow the thinking later.',
  ),
  'Development Set Up': const PageTour(
    title: 'Development Set Up',
    intro:
        'Set up the environments, tools and access the development team needs '
        'before build work starts.',
    outro:
        'Confirm each environment works end to end before the first build begins.',
  ),
  'Engineering': const PageTour(
    title: 'Engineering',
    intro:
        'Plan the engineering design: the structure, standards and calculations '
        'that the build will rely on.',
    outro:
        'Engineering decisions here are hard to reverse later. Get the right '
        'reviews before you lock them in.',
  ),
  'Specialized Design': const PageTour(
    title: 'Specialized Design',
    intro:
        'Capture the specialist design areas that sit outside the core design, '
        'and who is responsible for each.',
    outro:
        'Specialist areas are easy to overlook. Check that each one has an owner '
        'and a review date.',
  ),
  'UI/UX Design': const PageTour(
    title: 'UI/UX Design',
    intro:
        'Plan the user experience and interface design: the users, their key '
        'journeys, and the screens that support them.',
    outro:
        'Test the design against the real user journeys, not only the happy path.',
  ),
  'Backend Design': const PageTour(
    title: 'Backend Design',
    intro:
        'Design the back-end services, data and integrations that sit behind the '
        'user interface.',
    outro:
        'Back-end choices shape performance and security. Review them alongside '
        'the requirements.',
  ),
  'Technical Alignment': const PageTour(
    title: 'Technical Alignment',
    intro:
        'Check that the technical choices across teams fit together, and record '
        'any conflicts that need a decision.',
    outro:
        'Resolve misalignments early. They are much cheaper to fix on paper than '
        'in code.',
  ),
  'Technical Development': const PageTour(
    title: 'Technical Development',
    intro:
        'Track the technical development work: what is being built, by whom, and '
        'how far along it is.',
    outro:
        'Link each piece of work back to a requirement or design decision so '
        'progress means something.',
  ),
  'Technical Debt Management': const PageTour(
    title: 'Technical Debt Management',
    intro:
        'Record known technical debt, its cost to the project, and the plan for '
        'paying it down.',
    outro:
        'Unmanaged debt grows quietly. Give each item an owner and a target '
        'date.',
  ),
  'Technology Definitions': const PageTour(
    title: 'Technology Definitions',
    intro:
        'Define each technology the solution uses: what it is for, the version, '
        'and the standards that apply.',
    outro:
        'Clear definitions prevent teams from building against different '
        'assumptions.',
  ),
  'Technology Inventory': const PageTour(
    title: 'Technology Inventory',
    intro:
        'List every technology component in use, with its owner, licence and '
        'status, so nothing is missing from the record.',
    outro:
        'Keep the inventory current as components are added or retired.',
  ),
  'Tools Integration': const PageTour(
    title: 'Tools Integration',
    intro:
        'Plan how the project tools connect to each other, such as the tracker, '
        'the code repository and the test system.',
    outro:
        'Each integration should have a named owner and a test that proves it '
        'works.',
  ),
  'Requirements Implementation': const PageTour(
    title: 'Requirements Implementation',
    intro:
        'Trace each requirement to the design or build item that delivers it, '
        'and show which ones are not yet covered.',
    outro:
        'A requirement with no implementation item is a gap. Close it or record '
        'why it is deferred.',
  ),
  'Roadmap Overview': const PageTour(
    title: 'Roadmap Overview',
    intro:
        'See the deliverables roadmap at a glance: the main deliverables, their '
        'timing and how they depend on each other.',
    outro:
        'Use the overview to spot clashes before you open the detailed pages.',
  ),
  'Detailed Deliverables': const PageTour(
    title: 'Detailed Deliverables',
    intro:
        'Define each deliverable in detail: its content, its owner, its due date '
        'and what counts as done.',
    outro:
        'Vague deliverables cause disputes at handover. Write the done criteria '
        'carefully.',
  ),
  'Agile Map Out': const PageTour(
    title: 'Agile Map Out',
    intro:
        'Map the deliverables onto agile delivery: the epics, sprints or releases '
        'each deliverable will move through.',
    outro:
        'The map is a plan, not a commitment. Revisit it as the backlog firms up.',
  ),
  'Recurring Deliverables': const PageTour(
    title: 'Recurring Deliverables',
    intro:
        'Track the deliverables that repeat on a schedule, such as reports and '
        'reviews, with the cadence and owner for each.',
    outro:
        'Missed recurring items are easy to forget. Check the calendar against '
        'this list each cycle.',
  ),
  'Deliverable Status Updates': const PageTour(
    title: 'Deliverable Status Updates',
    intro:
        'Record the latest status of each deliverable, with what changed and what '
        'is blocking it.',
    outro:
        'Keep updates short and factual so the status can be read at a glance.',
  ),
  'Document Review Matrix': const PageTour(
    title: 'Document Review Matrix',
    intro:
        'Plan who reviews each document, in what order, and what sign-off each '
        'review requires.',
    outro:
        'Make sure every document has a reviewer and a sign-off route before it '
        'is issued.',
  ),
};
