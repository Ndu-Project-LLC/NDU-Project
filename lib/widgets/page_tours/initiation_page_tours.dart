import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for Initiation phase pages.
final Map<String, PageTour> initiationPageTours = {
  'Core Stakeholders': const PageTour(
    title: 'Core Stakeholders',
    intro:
        'Name the people and groups with the most influence over this project '
        'and what each one needs from it. Start with sponsors and decision makers.',
    outro:
        'The core list feeds the stakeholder management plan. Revisit it when '
        'roles or influence change.',
  ),
  'Initial Cost Estimate': const PageTour(
    title: 'Initial Cost Estimate',
    intro:
        'Give a first, high-level estimate of what the project will cost. This '
        'becomes the early benchmark that later cost pages are measured against.',
    outro:
        'Keep the assumptions behind each figure visible. They are what you will '
        'challenge first when the estimate is refined.',
  ),
  'Infrastructure Considerations': const PageTour(
    title: 'Infrastructure Considerations',
    intro:
        'Record the physical and environmental infrastructure the project depends '
        'on, such as facilities, utilities, access and hosting needs.',
    outro:
        'Infrastructure gaps found here usually become procurement or schedule '
        'items. Note who owns each one.',
  ),
  'Business Case Detail': const PageTour(
    title: 'Business Case Detail',
    intro:
        'Capture the reasons the project should go ahead: the problem, the '
        'expected benefits and the cost of doing nothing.',
    outro:
        'A clear business case is the basis for every later approval. Keep it '
        'specific enough that someone could test it.',
  ),
  'IT Considerations': const PageTour(
    title: 'IT Considerations',
    intro:
        'Identify the systems, data, integrations and security requirements the '
        'solution needs. Flag anything the IT team must approve early.',
    outro:
        'Unresolved IT constraints tend to delay design. Resolve or assign '
        'each one before moving on.',
  ),
  'Potential Solutions': const PageTour(
    title: 'Potential Solutions',
    intro:
        'List the realistic options for solving the problem. Include a do-nothing '
        'option so the comparison is fair.',
    outro:
        'The solutions you keep here are compared on the next page. Be honest '
        'about the trade-offs of each.',
  ),
  'Preferred Solution Analysis': const PageTour(
    title: 'Preferred Solution Analysis',
    intro:
        'Compare the potential solutions against the criteria that matter and '
        'choose the one to take forward, with the reasons.',
    outro:
        'The preferred solution sets the scope for planning. Record why the '
        'alternatives were rejected.',
  ),
  'Risk Identification': const PageTour(
    title: 'Risk Identification',
    intro:
        'Capture the risks that could stop or change the project at this early '
        'stage. Note a rough likelihood and impact for each.',
    outro:
        'These risks carry into the risk assessment in planning. Add new ones '
        'as you find them.',
  ),
  'Project Details': const PageTour(
    title: 'Project Details',
    intro:
        'Set the basic facts of the project: name, scope, timing and the key '
        'parties. Everything later in the framework refers back to this page.',
    outro:
        'Keep these details accurate. Changes here flow into the reports and '
        'the framework.',
  ),
  'Project Charter': const PageTour(
    title: 'Project Charter',
    intro:
        'Write the formal charter: purpose, objectives, scope, success criteria '
        'and the authority given to the project lead.',
    outro:
        'Once the charter is approved, scope changes are measured against it. '
        'Keep the wording precise.',
  ),
};
