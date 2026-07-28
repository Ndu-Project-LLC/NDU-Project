const heroStats = [
  {
    value: "70+",
    label: "Named route surfaces",
    caption: "Lifecycle, planning, design, execution, launch, SSHER, admin, and policy screens defined in the router.",
  },
  {
    value: "25+",
    label: "Service modules",
    caption: "Authentication, AI, persistence, subscriptions, navigation, procurement, contracts, integrations, and operations.",
  },
  {
    value: "3",
    label: "Primary runtimes",
    caption: "Web, iOS, and Android with Flutter frontends and Firebase-backed platform services.",
  },
  {
    value: "1",
    label: "Shared project model",
    caption: "A single cross-platform project state model powers planning continuity and checkpoint persistence.",
  },
];

const quickPills = [
  {
    title: "Who this is for",
    body: "Product owners, PMs, solution teams, delivery leaders, admins, and developers deploying or extending the platform.",
  },
  {
    title: "What it covers",
    body: "Architecture, routes, workflows, AI, payments, admin operations, data persistence, Firebase setup, and deployment order.",
  },
  {
    title: "How it is organized",
    body: "By lifecycle, capability domain, technical architecture, data model, commercial systems, and operational controls.",
  },
  {
    title: "Hosting model",
    body: "Static documentation site deployed from docs_site through Firebase Hosting with clean URLs and SPA rewrites.",
  },
];

const overviewCards = [
  {
    title: "End-to-end project operating system",
    body: "NDU Project is not a single-screen planner. It is a structured operating environment for concept definition, front-end planning, execution controls, launch readiness, and project closure.",
    bullets: [
      "Initiation, planning, design, execution, launch, and close-out support",
      "Project, program, and portfolio entry points",
      "Structured navigation and checkpoint-based continuity",
    ],
  },
  {
    title: "AI-assisted delivery planning",
    body: "KAZ AI is embedded across planning and analysis flows to accelerate drafts, structured recommendations, risk thinking, diagrams, and summary generation.",
    bullets: [
      "Secure OpenAI proxy architecture",
      "Context-aware drafting across major planning modules",
      "Optional auth enforcement and rate limiting patterns",
    ],
  },
  {
    title: "Enterprise operational depth",
    body: "The platform goes beyond planning templates into execution tables, issue and change logs, contract and vendor tracking, cost analysis, schedule management, and lessons learned.",
    bullets: [
      "Real-time Firestore-backed operational records",
      "Execution and governance modules",
      "Admin and content-control tooling",
    ],
  },
];

const lifecyclePhases = [
  {
    label: "Phase 01",
    title: "Initiation",
    body: "Capture the business case, define the problem space, shortlist solutions, assess risk, and formalize the charter foundation before planning hardens.",
    bullets: [
      "Business case and solution framing",
      "Potential solutions and preferred solution analysis",
      "Core stakeholders and governance alignment",
    ],
  },
  {
    label: "Phase 02",
    title: "Planning",
    body: "Define framework, goals, milestones, WBS, requirements, budget assumptions, and the detailed Front-End Planning suite that shapes delivery confidence.",
    bullets: [
      "Project framework and planning goals",
      "Cost estimate, cost analysis, and risk assessment",
      "Front-End Planning workspace and summaries",
    ],
  },
  {
    label: "Phase 03",
    title: "Design and readiness",
    body: "Move from conceptual planning to delivery-ready structures across design management, technical alignment, interfaces, tooling, security, infrastructure, and implementation scope.",
    bullets: [
      "Design phase and engineering screens",
      "Detailed design and technical alignment",
      "Interface, infrastructure, IT, and security planning",
    ],
  },
  {
    label: "Phase 04",
    title: "Execution and control",
    body: "Run the project using schedules, execution plans, issues, change management, contract oversight, stakeholder engagement, quality, and operational dashboards.",
    bullets: [
      "Execution plan and schedule board",
      "Issue, risk, change, and progress tracking",
      "Vendor, contract, and team operations",
    ],
  },
  {
    label: "Phase 05",
    title: "Launch and closure",
    body: "Coordinate launch, ramp-down, transitions, closure records, lessons learned, and handover activities needed to finish responsibly.",
    bullets: [
      "Launch checklist and transition to production",
      "Project, contract, and vendor close-out",
      "Demobilization and lessons learned",
    ],
  },
];

const capabilityColumns = [
  {
    title: "Planning intelligence",
    body: "The strongest product depth lives in planning, especially the Front-End Planning suite and its scenario-based, AI-assisted workflows.",
    tags: [
      "Requirements",
      "Risks",
      "Opportunities",
      "Procurement",
      "Contracts",
      "Vendor quotes",
      "Infrastructure",
      "Technology",
      "Personnel",
      "Security",
      "Allowance",
      "Milestones",
      "Summaries",
    ],
  },
  {
    title: "Execution control surfaces",
    body: "Execution modules provide operational rigor instead of static notes, with structured records, tables, boards, and role-aware actions.",
    tags: [
      "Schedule board",
      "Execution plan",
      "Issues",
      "Changes",
      "Risk tracking",
      "Contract details",
      "Vendor tracking",
      "Progress tracking",
      "Quality",
      "Stakeholder management",
    ],
  },
  {
    title: "Design and implementation depth",
    body: "The platform includes technical and implementation-oriented tooling across design, interface, architecture, and readiness workflows.",
    tags: [
      "UI/UX design",
      "Backend design",
      "Detailed design",
      "Engineering design",
      "Technical alignment",
      "Technical debt",
      "Requirements implementation",
      "Scope completion",
      "Tools integration",
    ],
  },
  {
    title: "Governance, admin, and commercialization",
    body: "The product includes pricing, billing, subscription logic, coupon controls, and an admin estate for operational oversight and content governance.",
    tags: [
      "Pricing",
      "Subscriptions",
      "Coupons",
      "Invoice tracking",
      "Admin projects",
      "Admin users",
      "Subscription lookup",
      "Editable content",
      "Access policy",
    ],
  },
];

const routeAtlas = [
  {
    title: "Access and entry",
    description: "Public entry and account lifecycle routes that gate access into the product.",
    tags: [
      "splash",
      "onboarding",
      "landing",
      "sign-in",
      "create-account",
      "forgot-password",
      "pricing",
      "mobile-pricing",
      "settings",
      "privacy-policy",
      "terms-conditions",
    ],
  },
  {
    title: "Dashboards and portfolio context",
    description: "Entry points for project, program, portfolio, and launch-oriented overview experiences.",
    tags: [
      "dashboard",
      "program-dashboard",
      "portfolio-dashboard",
      "mobile-dashboard",
      "home",
      "launch-checklist",
      "management-level",
    ],
  },
  {
    title: "Front-End Planning suite",
    description: "The most comprehensive cluster in the platform, covering early planning depth across risk, procurement, technology, staffing, and summaries.",
    tags: [
      "front-end-planning",
      "fep-workspace",
      "fep-requirements",
      "fep-personnel",
      "fep-procurement",
      "fep-contracts",
      "fep-contract-vendor-quotes",
      "fep-infrastructure",
      "fep-technology",
      "fep-technology-personnel",
      "fep-risks",
      "fep-allowance",
      "fep-milestone",
      "fep-opportunities",
      "fep-summary",
      "fep-summary-end",
      "fep-security",
    ],
  },
  {
    title: "Strategy, planning, and analysis",
    description: "Project framework, goals, WBS, cost and solution analysis, and charter-related flows.",
    tags: [
      "project-plan",
      "project-framework",
      "project-framework-next",
      "project-charter",
      "project-decision-summary",
      "progress-tracking",
      "work-breakdown-structure",
      "cost-estimate",
      "cost-analysis",
      "potential-solutions",
      "preferred-solution-analysis",
      "risk-assessment",
      "risk-identification",
    ],
  },
  {
    title: "Execution and controls",
    description: "Operational execution routes that help teams run live delivery with governance and visibility.",
    tags: [
      "execution-plan",
      "execution-plan-interface-management",
      "issue-management",
      "change-management",
      "schedule",
      "schedule-management",
      "contract-details",
      "risk-tracking",
      "contracts-tracking",
      "vendor-tracking",
      "scope-tracking-implementation",
    ],
  },
  {
    title: "Team, stakeholder, and operating model",
    description: "Team composition, stakeholder operations, meetings, training, and organization design surfaces.",
    tags: [
      "team-management",
      "team-meetings",
      "team-roles-responsibilities",
      "team-training-building",
      "training-project-tasks",
      "staff-team",
      "stakeholder-management",
      "core-stakeholders",
      "stakeholder-alignment",
      "identify-staff-ops-team",
      "program-basics",
    ],
  },
  {
    title: "Design, technology, launch, and closure",
    description: "Implementation readiness and end-of-lifecycle routes spanning technical design, transitions, and close-out.",
    tags: [
      "initiation-phase",
      "design-phase",
      "deliverables-roadmap",
      "deliver-project-closure",
      "transition-to-prod-team",
      "contract-close-out",
      "vendor-account-close-out",
      "ui-ux-design",
      "development-set-up",
      "technical-alignment",
      "backend-design",
      "long-lead-equipment-ordering",
      "technical-development",
      "tools-integration",
      "technical-debt-management",
      "detailed-design",
      "engineering-design",
      "requirements-implementation",
      "scope-completion",
      "project-close-out",
      "demobilize-team",
      "summarize-account-risks",
      "agile-development-iterations",
      "infrastructure-considerations",
      "it-considerations",
      "security-management",
      "lessons-learned",
      "update-ops-maintenance-plans",
    ],
  },
  {
    title: "SSHER, admin, and policy",
    description: "Safety and operational governance suite plus administrative routes and policy screens.",
    tags: [
      "ssher-stacked",
      "ssher-1",
      "ssher-2",
      "ssher-3",
      "ssher-4",
      "admin-home",
      "admin-projects",
      "admin-users",
      "admin-coupons",
      "admin-subscription-lookup",
      "admin",
    ],
  },
];

const architectureCards = [
  {
    title: "Client architecture",
    body: "Flutter is the primary client framework. The app uses go_router for navigation, Provider and InheritedNotifier for shared state, custom widgets for high-density workspace UIs, and web/mobile-specific routing adaptations.",
    bullets: [
      "Entries: main.dart and main_admin.dart",
      "Routing: lib/routing/app_router.dart and platform_router.dart",
      "Shared UI shell via workspace, sidebar, and phase header widgets",
    ],
  },
  {
    title: "State and persistence",
    body: "ProjectDataProvider manages in-memory project state, coalesced save queues, Firebase load/save orchestration, and checkpoint metadata. ProjectDataModel holds the cross-screen project state.",
    bullets: [
      "Single shared project data object",
      "Checkpoint-aware save flow",
      "Firestore-backed project records and subcollections",
    ],
  },
  {
    title: "Backend services",
    body: "Firebase provides Authentication, Firestore, Storage, and Cloud Functions. Functions act as secure boundaries for OpenAI and payment providers, keeping secrets off the client.",
    bullets: [
      "Firebase Auth for user identity",
      "Cloud Firestore for documents and subcollections",
      "Cloud Functions for AI proxy and billing workflows",
    ],
  },
  {
    title: "Service atlas",
    body: "Business logic is partitioned across service modules instead of being buried entirely in screens.",
    bullets: [
      "Auth and access: firebase_auth_service, auth_nav, access_policy",
      "Core entities: project_service, program_service, portfolio_service, user_service",
      "Execution operations: contract_service, vendor_service, change_request_service, execution_service",
      "AI and intelligence: openai_service_secure, project_intelligence_service, project_insights_service",
      "Commercial: subscription_service, coupon_service",
      "Integrations: integration_oauth_service, tools_integration_service",
    ],
  },
];

const dataMatrix = [
  {
    title: "ProjectDataModel coverage",
    body: "The core data model spans initiation, project charter, planning notes, WBS, issue logs, lessons learned, Front-End Planning, SSHER, team data, launch checklists, cost analysis, cost estimates, IT and infrastructure, stakeholders, execution, monitoring, quality, AI usage, field history, and metadata.",
    bullets: [
      "Cross-phase persistence in one object graph",
      "Legacy getter aliases for compatibility",
      "Checkpoint and history support for ongoing workflows",
    ],
  },
  {
    title: "Primary top-level Firestore collection",
    body: "Projects are stored in the projects collection, with owner metadata, timestamps, status, progress, and checkpoint state written during save operations.",
    bullets: [
      "projects/{projectId}",
      "ownerId, ownerEmail, ownerName, updatedAt, checkpointRoute, checkpointAt",
      "Create and update handled in ProjectDataProvider",
    ],
  },
  {
    title: "Operational subcollections",
    body: "Execution and specialized modules use subcollections beneath each project to support real-time tables and domain-specific records.",
    bullets: [
      "execution_tools, execution_issues, execution_enabling_works",
      "execution_change_requests, vendors, contracts, agile_stories",
      "salvage_inventory, tool_integrations, ops_members, ops_checklist",
    ],
  },
  {
    title: "Persistence behavior",
    body: "Save requests are coalesced to avoid redundant writes. Loads are cached but validated against Firestore before reusing the cached project state.",
    bullets: [
      "Queued save drain model",
      "Project-specific load serialization",
      "Server timestamp usage for update metadata",
    ],
  },
];

const aiCards = [
  {
    title: "AI capability surface",
    body: "KAZ AI supports planning text generation, solution drafting, requirements generation, infrastructure and IT recommendations, stakeholder reasoning, and strategic diagram support.",
    bullets: [
      "Autocomplete and full-section generation",
      "Project-specific context assembly",
      "Cross-screen recommendation workflows",
    ],
  },
  {
    title: "Security posture",
    body: "AI requests are designed to flow through Firebase Cloud Functions so keys remain server-side and auditable.",
    bullets: [
      "Secret Manager-backed OPENAI_API_KEY",
      "No client key exposure",
      "Optional Firebase Auth checks and rate limiting",
    ],
  },
  {
    title: "Implementation references",
    body: "The AI layer is anchored in openai_service_secure.dart, OpenAI configuration helpers, AI widgets, and cloud functions documentation.",
    bullets: [
      "lib/services/openai_service_secure.dart",
      "lib/widgets/ai_suggesting_textfield.dart",
      "functions/README.md",
    ],
  },
];

const commercialCards = [
  {
    title: "Subscription tiers",
    body: "The commercial model supports Project, Program, and Portfolio subscriptions with monthly and annual pricing tracks.",
    bullets: [
      "Project: $79 monthly or $790 annual",
      "Program: $189 monthly or $1,890 annual",
      "Portfolio: $449 monthly or $4,490 annual",
    ],
  },
  {
    title: "Payment providers",
    body: "Billing flows are designed for Stripe, PayPal, and Paystack with server-side verification and invoice recording.",
    bullets: [
      "Stripe checkout and verification",
      "PayPal order creation and capture",
      "Paystack initialization and verification",
    ],
  },
  {
    title: "Commercial controls",
    body: "Coupons, invoice history, subscription status, and lookup tooling support both users and administrators.",
    bullets: [
      "Coupon validation and usage tracking",
      "Invoice retrieval and recording",
      "Subscription cancellation and trial support",
    ],
  },
];

const adminColumns = [
  {
    title: "Admin operations",
    body: "The admin runtime has its own entrypoint and dedicated route cluster for back-office workflows.",
    tags: [
      "Admin home",
      "Projects",
      "Users",
      "Coupons",
      "Subscription lookup",
      "Admin auth wrapper",
    ],
  },
  {
    title: "Governance controls",
    body: "Access policy, restricted hosts, content edit tooling, and user-aware routing constrain how sensitive areas are reached and managed.",
    tags: [
      "Access policy",
      "Auth wrapper",
      "Admin auth wrapper",
      "Content provider",
      "Admin edit toggle",
      "Restricted access widgets",
    ],
  },
];

const integrationCards = [
  {
    title: "OAuth integrations",
    body: "The integration_oauth_service is structured for providers such as Figma, Miro, Draw.io, and a Microsoft-backed whiteboard flow using an nduproject redirect URI.",
    bullets: [
      "Stored client credentials and token state",
      "Provider-specific authorization and token endpoints",
      "Disconnect and refresh-aware patterns",
    ],
  },
  {
    title: "Platform service integrations",
    body: "Firebase, OpenAI, Stripe, PayPal, Paystack, Storage, and file picking are all first-class dependencies in the project.",
    bullets: [
      "Firebase Auth, Firestore, Storage, Functions",
      "OpenAI via secure proxy",
      "WebView and file workflows for richer operations",
    ],
  },
  {
    title: "UI integration surfaces",
    body: "Tools integration and collaboration workflows are supported through dedicated screens, widgets, and services that can be expanded over time.",
    bullets: [
      "tools_integration_screen.dart",
      "external_integrations_screen.dart",
      "whiteboard_canvas.dart and ai_diagram_panel.dart",
    ],
  },
];

const deploySteps = [
  "Deploy Firestore rules and indexes so persistence constraints match the current data model.",
  "Deploy Cloud Functions after setting secrets for OpenAI and payment providers.",
  "Verify Firebase project selection and web configuration in firebase_options.dart and firebase.json.",
  "Deploy Hosting from docs_site for the documentation experience.",
  "Deploy the Flutter web app separately if you want an app runtime alongside the docs site.",
  "Validate CORS, auth, and redirect behavior for production domains.",
];

const references = [
  {
    title: "PROJECT_UNDERSTANDING.md",
    body: "High-level system overview, lifecycle mapping, feature coverage, architecture notes, and commercial stack summary.",
    source: "Root documentation",
  },
  {
    title: "lib/routing/app_router.dart",
    body: "Source of truth for route inventory, product clustering, and user-facing navigation topology.",
    source: "Router definition",
  },
  {
    title: "lib/models/project_data_model.dart",
    body: "Canonical shared project state model spanning planning, execution, launch, metadata, AI usage, and history.",
    source: "Core data model",
  },
  {
    title: "lib/providers/project_data_provider.dart",
    body: "Save queue, Firestore synchronization, project creation logic, and checkpoint persistence behavior.",
    source: "Persistence provider",
  },
  {
    title: "functions/README.md",
    body: "OpenAI secure proxy setup, secret storage, auth protection, CORS, and function deployment guidance.",
    source: "Cloud Functions docs",
  },
  {
    title: "DEPLOYMENT_GUIDE.md",
    body: "Operational rollout notes for Firestore-backed integrations and remaining service work across modules.",
    source: "Deployment notes",
  },
  {
    title: "ADMIN_DEPLOYMENT.md",
    body: "Admin deployment, environment assumptions, and operations notes for the administrative runtime.",
    source: "Admin operations",
  },
  {
    title: "INTEGRATION_GUIDE.md",
    body: "Existing integration guidance for system setup and deployment-related dependencies.",
    source: "Integration reference",
  },
];

const sections = [
  { id: "overview", label: "Overview" },
  { id: "lifecycle", label: "Lifecycle" },
  { id: "capabilities", label: "Capabilities" },
  { id: "atlas", label: "Route Atlas" },
  { id: "architecture", label: "Architecture" },
  { id: "data", label: "Data and Persistence" },
  { id: "ai", label: "KAZ AI" },
  { id: "commercial", label: "Commercial" },
  { id: "admin", label: "Admin and Governance" },
  { id: "integrations", label: "Integrations" },
  { id: "deploy", label: "Deployment" },
  { id: "references", label: "References" },
];

function createEl(tag, className, text) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text) el.textContent = text;
  return el;
}

function renderHeroStats() {
  const mount = document.getElementById("hero-stats");
  heroStats.forEach((item) => {
    const card = createEl("article", "stat-card");
    card.dataset.search = `${item.value} ${item.label} ${item.caption}`.toLowerCase();
    card.append(
      createEl("div", "stat-value", item.value),
      createEl("div", "stat-label", item.label),
      createEl("div", "stat-caption", item.caption)
    );
    mount.appendChild(card);
  });
}

function renderQuickPills() {
  const mount = document.getElementById("quick-strip");
  quickPills.forEach((item) => {
    const pill = createEl("article", "quick-pill");
    pill.dataset.search = `${item.title} ${item.body}`.toLowerCase();
    pill.append(createEl("h3", "", item.title), createEl("p", "", item.body));
    mount.appendChild(pill);
  });
}

function renderCards(targetId, cards) {
  const mount = document.getElementById(targetId);
  cards.forEach((item) => {
    const card = createEl("article", "card");
    card.dataset.search = [
      item.title,
      item.body,
      ...(item.bullets || []),
    ].join(" ").toLowerCase();
    card.append(createEl("h3", "", item.title), createEl("p", "", item.body));
    if (item.bullets?.length) {
      const list = createEl("ul");
      item.bullets.forEach((bullet) => {
        list.appendChild(createEl("li", "", bullet));
      });
      card.appendChild(list);
    }
    mount.appendChild(card);
  });
}

function renderTimeline() {
  const mount = document.getElementById("timeline");
  lifecyclePhases.forEach((phase) => {
    const item = createEl("article", "timeline-item");
    item.dataset.search = [
      phase.label,
      phase.title,
      phase.body,
      ...(phase.bullets || []),
    ].join(" ").toLowerCase();

    const badge = createEl("div", "phase-index", phase.label);
    const title = createEl("h3", "", phase.title);
    const body = createEl("p", "", phase.body);
    item.append(badge, title, body);

    if (phase.bullets?.length) {
      const list = createEl("ul");
      phase.bullets.forEach((bullet) => list.appendChild(createEl("li", "", bullet)));
      item.appendChild(list);
    }

    mount.appendChild(item);
  });
}

function renderFeaturePanels(targetId, panels) {
  const mount = document.getElementById(targetId);
  panels.forEach((panel) => {
    const el = createEl("article", "feature-panel");
    el.dataset.search = `${panel.title} ${panel.body} ${(panel.tags || []).join(" ")}`.toLowerCase();
    el.append(createEl("h3", "", panel.title), createEl("p", "", panel.body));
    if (panel.tags?.length) {
      const tags = createEl("div", "tag-list");
      panel.tags.forEach((tag) => tags.appendChild(createEl("span", "tag", tag)));
      el.appendChild(tags);
    }
    mount.appendChild(el);
  });
}

function renderAtlas() {
  const mount = document.getElementById("route-atlas");
  routeAtlas.forEach((group) => {
    const card = createEl("article", "atlas-card");
    card.dataset.search = `${group.title} ${group.description} ${group.tags.join(" ")}`.toLowerCase();
    card.append(createEl("h3", "", group.title), createEl("p", "", group.description));
    const tags = createEl("div", "tag-list");
    group.tags.forEach((tag) => tags.appendChild(createEl("span", "tag", tag)));
    card.appendChild(tags);
    mount.appendChild(card);
  });
}

function renderMatrix() {
  const mount = document.getElementById("data-matrix");
  dataMatrix.forEach((item) => {
    const card = createEl("article", "matrix-card");
    card.dataset.search = `${item.title} ${item.body} ${(item.bullets || []).join(" ")}`.toLowerCase();
    card.append(createEl("h3", "", item.title), createEl("p", "", item.body));
    const list = createEl("ul");
    item.bullets.forEach((bullet) => list.appendChild(createEl("li", "", bullet)));
    card.appendChild(list);
    mount.appendChild(card);
  });
}

function renderDeploySteps() {
  const mount = document.getElementById("deploy-steps");
  deploySteps.forEach((step) => {
    mount.appendChild(createEl("li", "", step));
  });
}

function renderReferences() {
  const mount = document.getElementById("reference-list");
  references.forEach((ref) => {
    const item = createEl("article", "reference-item");
    item.dataset.search = `${ref.title} ${ref.body} ${ref.source}`.toLowerCase();
    item.append(
      createEl("h3", "", ref.title),
      createEl("p", "", ref.body),
      createEl("small", "", ref.source)
    );
    mount.appendChild(item);
  });
}

function renderNav() {
  const mount = document.getElementById("section-nav");
  sections.forEach((section) => {
    const link = createEl("a", "sidebar-link", section.label);
    link.href = `#${section.id}`;
    mount.appendChild(link);
  });
}

function applySearch(query) {
  const normalized = query.trim().toLowerCase();
  const searchable = document.querySelectorAll("[data-search]");

  searchable.forEach((node) => {
    const haystack = node.dataset.search || "";
    const match = !normalized || haystack.includes(normalized);
    node.classList.toggle("hidden", !match);
  });

  document.querySelectorAll(".content-section").forEach((section) => {
    const visibleChildren = [...section.querySelectorAll("[data-search]")]
      .some((node) => !node.classList.contains("hidden"));
    section.classList.toggle("hidden", !visibleChildren && normalized.length > 0);
  });
}

function boot() {
  renderNav();
  renderHeroStats();
  renderQuickPills();
  renderCards("overview-cards", overviewCards);
  renderTimeline();
  renderFeaturePanels("capability-columns", capabilityColumns);
  renderAtlas();
  renderCards("architecture-cards", architectureCards);
  renderMatrix();
  renderCards("ai-cards", aiCards);
  renderCards("commercial-cards", commercialCards);
  renderFeaturePanels("admin-columns", adminColumns);
  renderCards("integration-cards", integrationCards);
  renderDeploySteps();
  renderReferences();

  const search = document.getElementById("search-input");
  search.addEventListener("input", (event) => {
    applySearch(event.target.value);
  });
}

boot();
