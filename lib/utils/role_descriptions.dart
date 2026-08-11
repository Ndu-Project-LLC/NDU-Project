// Comprehensive role description bank.
// Each entry maps a role title to its description and workstream/discipline.

class RoleDescriptionEntry {
  final String description;
  final String discipline;
  const RoleDescriptionEntry({required this.description, required this.discipline});
}

const Map<String, RoleDescriptionEntry> roleDescriptions = {
  // ═══ 1. Project Leadership and Governance ═══
  'Project Sponsor': RoleDescriptionEntry(
    description: 'Provides executive sponsorship, funding approval, and high-level strategic direction for the project.',
    discipline: 'Project Governance',
  ),
  'Steering Committee': RoleDescriptionEntry(
    description: 'Governance body that reviews project progress, approves key decisions, and ensures alignment with organisational strategy.',
    discipline: 'Project Governance',
  ),
  'Program Manager': RoleDescriptionEntry(
    description: 'Coordinates multiple related projects, manages interdependencies, and ensures alignment with program-level objectives.',
    discipline: 'Program Management',
  ),
  'Portfolio Manager': RoleDescriptionEntry(
    description: 'Oversees the project portfolio, prioritises investments, balances resources, and aligns initiatives with strategic goals.',
    discipline: 'Portfolio Management',
  ),
  'Project Manager': RoleDescriptionEntry(
    description: 'Overall project leadership — plans, executes, monitors, and closes the project across all phases, managing scope, schedule, budget, and stakeholders.',
    discipline: 'Project Leadership',
  ),
  'Delivery Manager': RoleDescriptionEntry(
    description: 'Coordinates delivery across teams, manages dependencies, removes blockers, and ensures timely execution of deliverables.',
    discipline: 'Project Leadership',
  ),
  'Engagement Manager': RoleDescriptionEntry(
    description: 'Manages client relationships, expectations, and contract delivery; acts as the primary point of contact for the customer.',
    discipline: 'Project Leadership',
  ),
  'Program Director': RoleDescriptionEntry(
    description: 'Provides strategic leadership across a program of work, manages senior stakeholders, and ensures benefits realisation.',
    discipline: 'Program Management',
  ),
  'PMO Director': RoleDescriptionEntry(
    description: 'Leads the Project Management Office, sets governance standards, and drives project management maturity across the organisation.',
    discipline: 'PMO Management',
  ),
  'PMO Manager': RoleDescriptionEntry(
    description: 'Manages PMO operations, reporting cadence, resource planning, and ensures adherence to project management frameworks.',
    discipline: 'PMO Management',
  ),
  'PMO Analyst': RoleDescriptionEntry(
    description: 'Provides analytical support to the PMO — maintains dashboards, tracks milestones, and prepares status reports.',
    discipline: 'PMO Management',
  ),
  'Executive Sponsor': RoleDescriptionEntry(
    description: 'Senior executive who champions the project, secures funding, and removes organisational barriers.',
    discipline: 'Strategic Alignment',
  ),
  'Business Sponsor': RoleDescriptionEntry(
    description: 'Business-side sponsor who ensures the project delivers expected business value and aligns with strategic priorities.',
    discipline: 'Strategic Alignment',
  ),

  // ═══ 2. Scope and Requirements Management ═══
  'Business Analyst': RoleDescriptionEntry(
    description: 'Elicits, analyses, documents, and manages requirements; bridges business stakeholders and the delivery team to ensure solutions meet business needs.',
    discipline: 'Requirements Management',
  ),
  'Systems Analyst': RoleDescriptionEntry(
    description: 'Analyses system requirements, defines functional specifications, and translates business needs into technical solutions.',
    discipline: 'Requirements Management',
  ),
  'Product Owner': RoleDescriptionEntry(
    description: 'Owns the product backlog, prioritises user stories, represents stakeholder interests, and ensures the team delivers maximum value.',
    discipline: 'Requirements Management',
  ),
  'Product Manager': RoleDescriptionEntry(
    description: 'Defines product vision, strategy, and roadmap; conducts market research, prioritises features, and manages the product lifecycle.',
    discipline: 'Scope Definition',
  ),
  'Solution Architect': RoleDescriptionEntry(
    description: 'Designs the overall solution architecture, ensures technical feasibility, and aligns technology decisions with business requirements.',
    discipline: 'Solution Definition',
  ),
  'Enterprise Architect': RoleDescriptionEntry(
    description: 'Defines enterprise-wide architecture strategy, standards, and roadmaps; ensures solutions align with the broader organisational landscape.',
    discipline: 'Solution Definition',
  ),
  'Change Control Board': RoleDescriptionEntry(
    description: 'Reviews and approves/rejects change requests, ensuring changes are assessed for impact on scope, schedule, cost, and quality.',
    discipline: 'Change Requests',
  ),

  // ═══ 3. Schedule and Planning Management ═══
  'Project Scheduler': RoleDescriptionEntry(
    description: 'Develops and maintains the project schedule, tracks progress against milestones, and provides schedule analysis and forecasting.',
    discipline: 'Schedule Development',
  ),
  'Project Controls Specialist': RoleDescriptionEntry(
    description: 'Supports project controls functions including scheduling, cost control, earned value management, and performance reporting.',
    discipline: 'Schedule Development',
  ),
  'Planning Engineer': RoleDescriptionEntry(
    description: 'Develops detailed project plans, work breakdown structures, and progress measurement systems for engineering and construction projects.',
    discipline: 'Schedule Development',
  ),
  'Scrum Master': RoleDescriptionEntry(
    description: 'Facilitates Agile ceremonies, coaches the team on Scrum practices, removes impediments, and fosters a culture of continuous improvement.',
    discipline: 'Sprint Planning',
  ),
  'Release Manager': RoleDescriptionEntry(
    description: 'Plans, schedules, and coordinates software releases across environments; manages release calendar and go/no-go decisions.',
    discipline: 'Release Planning',
  ),

  // ═══ 4. Cost and Financial Management ═══
  'Cost Engineer': RoleDescriptionEntry(
    description: 'Develops cost estimates, monitors project costs, performs earned value analysis, and provides cost forecasting and variance reporting.',
    discipline: 'Cost Estimating',
  ),
  'Estimator': RoleDescriptionEntry(
    description: 'Prepares detailed cost estimates for labor, materials, equipment, and overheads based on scope documents and historical data.',
    discipline: 'Cost Estimating',
  ),
  'Financial Analyst': RoleDescriptionEntry(
    description: 'Analyses project financials, prepares budgets and forecasts, tracks expenditure, and supports financial decision-making.',
    discipline: 'Cost Estimating',
  ),
  'Project Controls Engineer': RoleDescriptionEntry(
    description: 'Integrates cost, schedule, and risk data to provide accurate performance measurement, earned value analysis, and trend forecasting.',
    discipline: 'Earned Value Management',
  ),
  'Cost Analyst': RoleDescriptionEntry(
    description: 'Analyses cost data, identifies trends and variances, and supports cost forecasting and budget management activities.',
    discipline: 'Forecasting',
  ),
  'Finance Manager': RoleDescriptionEntry(
    description: 'Manages project financial operations, including budgeting, accounting, reporting, and financial compliance.',
    discipline: 'Forecasting',
  ),

  // ═══ 5. Resource and Workforce Management ═══
  'Resource Manager': RoleDescriptionEntry(
    description: 'Allocates personnel across projects, manages resource demand and capacity, and optimises workforce utilisation.',
    discipline: 'Resource Planning',
  ),
  'Functional Manager': RoleDescriptionEntry(
    description: 'Manages a functional team, assigns staff to projects, oversees professional development, and ensures resource availability.',
    discipline: 'Staffing',
  ),
  'Agile Coach': RoleDescriptionEntry(
    description: 'Coaches teams and leadership on Agile principles, practices, and mindsets; facilitates organisational agile transformation.',
    discipline: 'Team Development',
  ),
  'Operations Manager': RoleDescriptionEntry(
    description: 'Oversees day-to-day operations, resource allocation, process efficiency, and service delivery performance.',
    discipline: 'Workforce Optimization',
  ),
  'Workforce Manager': RoleDescriptionEntry(
    description: 'Plans and manages workforce capacity, recruitment, scheduling, and skill development to meet project and operational demands.',
    discipline: 'Resource Planning',
  ),

  // ═══ 6. Risk and Issue Management ═══
  'Risk Manager': RoleDescriptionEntry(
    description: 'Identifies, assesses, and mitigates project risks; maintains the risk register and facilitates regular risk reviews.',
    discipline: 'Risk Identification',
  ),
  'Risk Analyst': RoleDescriptionEntry(
    description: 'Performs quantitative and qualitative risk analysis, models risk impacts, and supports risk response planning.',
    discipline: 'Quantitative Risk Analysis',
  ),
  'Enterprise Risk Manager': RoleDescriptionEntry(
    description: 'Manages enterprise-level risk framework, risk appetite, and reporting across the portfolio of projects.',
    discipline: 'Enterprise Risk Management',
  ),
  'Release Train Engineer': RoleDescriptionEntry(
    description: 'Facilitates Agile Release Train (ART) ceremonies, manages ART-level impediments, and drives continuous improvement in SAFe environments.',
    discipline: 'Dependency Management',
  ),

  // ═══ 7. Quality Management ═══
  'QA Manager': RoleDescriptionEntry(
    description: 'Leads quality assurance strategy, establishes QA processes, oversees testing teams, and ensures quality standards are met.',
    discipline: 'Quality Assurance',
  ),
  'Quality Engineer': RoleDescriptionEntry(
    description: 'Designs and implements quality engineering practices, automates testing, and integrates quality into the development lifecycle.',
    discipline: 'Quality Assurance',
  ),
  'QA Analyst': RoleDescriptionEntry(
    description: 'Executes test cases, reports defects, verifies fixes, and ensures software quality through structured testing processes.',
    discipline: 'Quality Control',
  ),
  'Inspector': RoleDescriptionEntry(
    description: 'Conducts inspections and audits of deliverables, processes, and work products to verify compliance with specifications and standards.',
    discipline: 'Quality Control',
  ),
  'Lean Specialist': RoleDescriptionEntry(
    description: 'Applies Lean methodologies to eliminate waste, optimise flow, and improve process efficiency across the value stream.',
    discipline: 'Continuous Improvement',
  ),
  'Six Sigma Black Belt': RoleDescriptionEntry(
    description: 'Leads process improvement projects using Six Sigma methodology, drives defect reduction and process capability improvements.',
    discipline: 'Continuous Improvement',
  ),
  'Test Manager': RoleDescriptionEntry(
    description: 'Manages testing strategy, test planning, resource allocation, and defect management across the testing lifecycle.',
    discipline: 'Testing Management',
  ),

  // ═══ 8. Procurement and Contract Management ═══
  'Procurement Manager': RoleDescriptionEntry(
    description: 'Manages procurement strategy, supplier selection, contract negotiation, and purchasing activities for project goods and services.',
    discipline: 'Procurement',
  ),
  'Vendor Manager': RoleDescriptionEntry(
    description: 'Manages vendor relationships, monitors service levels, negotiates contracts, and ensures supplier performance meets expectations.',
    discipline: 'Vendor Management',
  ),
  'Contract Administrator': RoleDescriptionEntry(
    description: 'Administers contracts throughout the lifecycle — tracks terms, manages changes, processes payments, and ensures compliance.',
    discipline: 'Contract Administration',
  ),
  'Supply Chain Manager': RoleDescriptionEntry(
    description: 'Manages end-to-end supply chain operations — sourcing, logistics, inventory, and distribution to ensure timely delivery of materials.',
    discipline: 'Supply Chain Management',
  ),
  'Commercial Manager': RoleDescriptionEntry(
    description: 'Manages commercial aspects of projects — pricing, contract terms, risk allocation, claims, and dispute resolution.',
    discipline: 'Commercial Management',
  ),

  // ═══ 9. Communications and Stakeholder Management ═══
  'Communications Manager': RoleDescriptionEntry(
    description: 'Develops and executes the communications plan, manages internal and external communications, and ensures message consistency.',
    discipline: 'Communications Management',
  ),
  'Customer Success Manager': RoleDescriptionEntry(
    description: 'Ensures customer satisfaction, manages post-delivery relationships, drives adoption, and identifies upsell opportunities.',
    discipline: 'Customer Management',
  ),
  'Stakeholder Manager': RoleDescriptionEntry(
    description: 'Identifies, maps, and engages stakeholders; manages expectations, communications, and relationships throughout the project.',
    discipline: 'Stakeholder Engagement',
  ),
  'Change Manager': RoleDescriptionEntry(
    description: 'Plans and manages organisational change, stakeholder adoption, training, and transition activities to embed new ways of working.',
    discipline: 'Change Communications',
  ),

  // ═══ 10. Change Management and Organisational Readiness ═══
  'Training Coordinator': RoleDescriptionEntry(
    description: 'Coordinates training logistics, schedules sessions, tracks attendance, and ensures training materials are prepared and distributed.',
    discipline: 'Training and Development',
  ),
  'Change Lead': RoleDescriptionEntry(
    description: 'Leads change management initiatives, drives adoption strategies, and measures change readiness and effectiveness.',
    discipline: 'Adoption Management',
  ),
  'Transition Manager': RoleDescriptionEntry(
    description: 'Plans and manages transition activities — cutover, migration, handover, and stabilisation to move from project to operations.',
    discipline: 'Transition Planning',
  ),
  'Business Readiness Manager': RoleDescriptionEntry(
    description: 'Assesses and ensures business readiness for change — training, process updates, organisational alignment, and capability building.',
    discipline: 'Business Readiness',
  ),

  // ═══ 11. Technical Delivery and Engineering ═══
  'Systems Engineer': RoleDescriptionEntry(
    description: 'Designs and integrates complex systems, manages system requirements, and ensures end-to-end system coherence and performance.',
    discipline: 'Systems Engineering',
  ),
  'Engineering Manager': RoleDescriptionEntry(
    description: 'Leads engineering teams, manages technical delivery, oversees design and development, and ensures engineering best practices.',
    discipline: 'Engineering Management',
  ),
  'Engineering Lead': RoleDescriptionEntry(
    description: 'Provides technical leadership to the engineering team, drives architecture decisions, and ensures technical quality.',
    discipline: 'Engineering Management',
  ),
  'Software Engineer': RoleDescriptionEntry(
    description: 'Designs, develops, tests, and maintains software applications following coding standards and engineering best practices.',
    discipline: 'Software Development',
  ),
  'Developer': RoleDescriptionEntry(
    description: 'Writes code, implements features, fixes bugs, and participates in code reviews as part of the development team.',
    discipline: 'Software Development',
  ),
  'Infrastructure Engineer': RoleDescriptionEntry(
    description: 'Designs, builds, and maintains IT infrastructure — servers, networks, cloud services, and supporting systems.',
    discipline: 'Infrastructure',
  ),
  'DevOps Engineer': RoleDescriptionEntry(
    description: 'Automates CI/CD pipelines, manages cloud infrastructure, and bridges development and operations for reliable software delivery.',
    discipline: 'DevOps',
  ),
  'Integration Architect': RoleDescriptionEntry(
    description: 'Designs integration strategies, defines APIs and data flows, and ensures seamless interoperability between systems.',
    discipline: 'Integration Management',
  ),
  'Design Engineer': RoleDescriptionEntry(
    description: 'Produces detailed engineering designs, drawings, and specifications for construction or manufacturing.',
    discipline: 'Engineering Management',
  ),

  // ═══ 12. Agile Delivery Disciplines ═══
  'Lean Portfolio Manager': RoleDescriptionEntry(
    description: 'Applies Lean principles to portfolio management — aligns investments to strategy, optimises flow, and enables decentralised decision-making.',
    discipline: 'Lean Portfolio Management',
  ),
  'Flow Manager': RoleDescriptionEntry(
    description: 'Manages Kanban flow across the value stream, monitors work-in-progress limits, and optimises throughput and cycle time.',
    discipline: 'Kanban Flow Management',
  ),
  'Value Stream Manager': RoleDescriptionEntry(
    description: 'Maps and optimises value streams, identifies bottlenecks, and drives improvements to deliver value faster.',
    discipline: 'Value Stream Management',
  ),

  // ═══ 13. Project Controls ═══
  'Project Controls Manager': RoleDescriptionEntry(
    description: 'Leads project controls functions — planning, scheduling, cost control, risk management, and performance reporting across the project.',
    discipline: 'Performance Measurement',
  ),

  // ═══ 14. Configuration and Document Management ═══
  'Document Controller': RoleDescriptionEntry(
    description: 'Manages project documentation — version control, distribution, storage, and retrieval ensures accuracy and accessibility.',
    discipline: 'Document Control',
  ),
  'Configuration Manager': RoleDescriptionEntry(
    description: 'Establishes and maintains configuration management processes, controls baselines, and audits configuration items.',
    discipline: 'Configuration Management',
  ),
  'Records Specialist': RoleDescriptionEntry(
    description: 'Manages records retention, archiving, and disposal in compliance with legal and regulatory requirements.',
    discipline: 'Records Management',
  ),
  'Data Manager': RoleDescriptionEntry(
    description: 'Oversees data governance, data quality, data architecture, and master data management across the organisation.',
    discipline: 'Data Governance',
  ),

  // ═══ 15. Testing and Validation ═══
  'Test Engineer': RoleDescriptionEntry(
    description: 'Designs and executes test plans, automates test scripts, and ensures software meets functional and non-functional requirements.',
    discipline: 'Integration Testing',
  ),
  'Validation Engineer': RoleDescriptionEntry(
    description: 'Performs verification and validation activities, ensuring deliverables meet specified requirements and quality standards.',
    discipline: 'Verification and Validation',
  ),
  'Compliance Manager': RoleDescriptionEntry(
    description: 'Ensures project compliance with regulatory requirements, standards, and policies; manages compliance audits and reporting.',
    discipline: 'Regulatory Validation',
  ),

  // ═══ 16. Compliance and Regulatory Management ═══
  'Compliance Officer': RoleDescriptionEntry(
    description: 'Monitors and enforces compliance with laws, regulations, and internal policies; conducts compliance risk assessments.',
    discipline: 'Regulatory Compliance',
  ),
  'Internal Auditor': RoleDescriptionEntry(
    description: 'Conducts internal audits of projects, processes, and controls to assess effectiveness and identify improvement areas.',
    discipline: 'Audit Management',
  ),
  'Governance Manager': RoleDescriptionEntry(
    description: 'Establishes and oversees governance frameworks, decision rights, and accountability structures across projects.',
    discipline: 'Governance and Controls',
  ),
  'Information Security Manager': RoleDescriptionEntry(
    description: 'Manages information security program, cybersecurity risks, and ensures compliance with security standards and regulations.',
    discipline: 'Cybersecurity Compliance',
  ),
  'HSE Manager': RoleDescriptionEntry(
    description: 'Manages health, safety, and environmental programs; ensures regulatory compliance and promotes a safety culture.',
    discipline: 'Environmental Compliance',
  ),

  // ═══ 17. Health, Safety, and Environmental Management ═══
  'Environmental Engineer': RoleDescriptionEntry(
    description: 'Assesses environmental impacts, designs mitigation measures, and ensures environmental compliance for projects.',
    discipline: 'Environmental Management',
  ),
  'Safety Coordinator': RoleDescriptionEntry(
    description: 'Coordinates safety activities, conducts inspections, investigates incidents, and promotes workplace safety awareness.',
    discipline: 'Incident Management',
  ),
  'Safety Specialist': RoleDescriptionEntry(
    description: 'Provides specialised safety expertise, conducts risk assessments, and develops safety protocols and procedures.',
    discipline: 'Risk Prevention',
  ),

  // ═══ 18. Data and Analytics ═══
  'Data Analyst': RoleDescriptionEntry(
    description: 'Analyses data to generate insights, builds reports and dashboards, and supports data-driven decision-making.',
    discipline: 'Data Management',
  ),
  'BI Analyst': RoleDescriptionEntry(
    description: 'Develops business intelligence solutions, designs data visualisations, and provides analytical insights to stakeholders.',
    discipline: 'Business Intelligence',
  ),
  'Reporting Analyst': RoleDescriptionEntry(
    description: 'Prepares standard and ad-hoc reports, maintains reporting systems, and ensures data accuracy and timeliness.',
    discipline: 'Reporting',
  ),
  'Data Scientist': RoleDescriptionEntry(
    description: 'Applies advanced analytics, machine learning, and statistical methods to extract insights and solve complex business problems.',
    discipline: 'AI and Analytics',
  ),
  'KPI Analyst': RoleDescriptionEntry(
    description: 'Defines, tracks, and analyses key performance indicators to measure project and organisational performance.',
    discipline: 'Performance Metrics',
  ),

  // ═══ 19. Product and Customer Management ═══
  'UX Designer': RoleDescriptionEntry(
    description: 'Designs user experiences — conducts user research, creates wireframes and prototypes, and ensures intuitive, accessible interfaces.',
    discipline: 'Customer Experience',
  ),
  'Product Marketing Manager': RoleDescriptionEntry(
    description: 'Develops go-to-market strategies, conducts market research, and drives product positioning and messaging.',
    discipline: 'Market Research',
  ),

  // ═══ 20. Release and Deployment Management ═══
  'Deployment Manager': RoleDescriptionEntry(
    description: 'Plans and manages deployment activities, coordinates release logistics, and ensures smooth rollouts across environments.',
    discipline: 'Deployment Management',
  ),
  'Support Manager': RoleDescriptionEntry(
    description: 'Manages production support operations, incident response, service levels, and continuous improvement of support processes.',
    discipline: 'Production Support',
  ),
  'Service Delivery Manager': RoleDescriptionEntry(
    description: 'Manages service delivery against SLAs, oversees the service desk, and ensures customer satisfaction with delivered services.',
    discipline: 'Service Introduction',
  ),

  // ═══ 21. Operations and Sustainment ═══
  'Asset Manager': RoleDescriptionEntry(
    description: 'Manages the lifecycle of physical and intangible assets — acquisition, maintenance, depreciation, and disposal.',
    discipline: 'Asset Management',
  ),
  'Maintenance Manager': RoleDescriptionEntry(
    description: 'Plans and manages maintenance programs, schedules preventive maintenance, and ensures asset reliability and availability.',
    discipline: 'Maintenance Management',
  ),
  'Lean Manager': RoleDescriptionEntry(
    description: 'Drives Lean transformation initiatives, coaches teams on Lean practices, and leads continuous improvement efforts.',
    discipline: 'Continuous Improvement',
  ),

  // ═══ Additional Methodology-Specific Roles ═══
  'Project Coordinator': RoleDescriptionEntry(
    description: 'Supports project administration — schedules meetings, maintains documentation, tracks actions, and facilitates communication.',
    discipline: 'Project Leadership',
  ),
  'Quality Assurance Lead': RoleDescriptionEntry(
    description: 'Owns quality planning, QA/QC processes, and compliance with standards across the project lifecycle.',
    discipline: 'Quality Assurance',
  ),
  'PMO Lead': RoleDescriptionEntry(
    description: 'Provides PMO leadership, establishes project governance standards, and drives consistency in project delivery.',
    discipline: 'PMO Management',
  ),
  'Project Lead': RoleDescriptionEntry(
    description: 'Leads day-to-day project activities, coordinates team members, and ensures deliverables meet scope and quality expectations.',
    discipline: 'Project Leadership',
  ),
  'Designer': RoleDescriptionEntry(
    description: 'Creates visual designs, UI mockups, and design assets; ensures brand consistency and user-centred design principles.',
    discipline: 'Customer Experience',
  ),
};

/// All known role titles for suggestion/search purposes.
final List<String> allRoleTitles =
    roleDescriptions.keys.toList(growable: false);

/// Returns the [RoleDescriptionEntry] for [title], or null if not found.
RoleDescriptionEntry? getRoleDescription(String title) =>
    roleDescriptions[title];

/// Suggested role titles organised by category for chip display.
class RoleCategory {
  final String label;
  final List<String> roles;
  const RoleCategory({required this.label, required this.roles});
}

const List<RoleCategory> roleCategories = [
  RoleCategory(
    label: 'Leadership & Governance',
    roles: [
      'Project Manager',
      'Program Manager',
      'PMO Lead',
      'Portfolio Manager',
    ],
  ),
  RoleCategory(
    label: 'Requirements & Scope',
    roles: ['Business Analyst', 'Product Owner', 'Product Manager'],
  ),
  RoleCategory(
    label: 'Engineering & Technical',
    roles: [
      'Solution Architect',
      'Engineering Lead',
      'Systems Engineer',
      'Planning Engineer',
    ],
  ),
  RoleCategory(
    label: 'Quality & Risk',
    roles: ['QA Lead', 'Risk Manager', 'Quality Engineer'],
  ),
  RoleCategory(
    label: 'Operations & Delivery',
    roles: [
      'Operations Manager',
      'Delivery Manager',
      'Scrum Master',
      'Project Coordinator',
    ],
  ),
  RoleCategory(
    label: 'Specialists',
    roles: ['Change Manager', 'Data Analyst', 'Designer', 'Project Lead'],
  ),
];

/// Flat list of suggested role titles (for convenience).
List<String> get flatSuggestedRoles =>
    roleCategories.expand((c) => c.roles).toList(growable: false);
