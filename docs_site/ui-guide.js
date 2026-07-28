const guideSections = [
  { id: "ui-principles", label: "UI Principles" },
  { id: "core-pages", label: "Core Pages" },
  { id: "planning-pages", label: "Planning Pages" },
  { id: "design-pages", label: "Design and Readiness" },
  { id: "operations-pages", label: "Execution and Operations" },
  { id: "admin-pages", label: "Admin UI" },
];

const guideHeroStats = [
  {
    value: "6",
    label: "UI guide sections",
    caption: "Organized by entry, planning, design, operations, and admin page families.",
  },
  {
    value: "40+",
    label: "Screen patterns represented",
    caption: "Mapped from the router and grouped into usable UI categories instead of a flat screen list.",
  },
  {
    value: "High + Detailed",
    label: "Documentation depth",
    caption: "Short enough to scan, detailed enough to understand layout, controls, and information hierarchy.",
  },
  {
    value: "Product-first",
    label: "Audience orientation",
    caption: "Useful for product, delivery, support, design, QA, onboarding, and implementation conversations.",
  },
];

const uiPrinciples = [
  {
    title: "Workspace headers",
    body: "Most major pages open with a strong header area containing the page title, project context, navigation affordances, and often phase-aware actions or checkpoint cues.",
    bullets: [
      "Page title and subcontext",
      "Current project or user state",
      "Action buttons such as save, continue, create, or regenerate",
    ],
  },
  {
    title: "Section card model",
    body: "Complex pages are split into visually separated cards or panels. Each card handles one thought unit such as a note area, matrix, summary, table, or workflow slice.",
    bullets: [
      "Contained information clusters",
      "Clear spacing and card borders",
      "Expandable or collapsible subsections on denser screens",
    ],
  },
  {
    title: "Input-first planning pages",
    body: "Planning screens bias toward structured entry: text fields, note cards, rich narrative areas, bullet-driven fields, and AI-assisted drafting controls.",
    bullets: [
      "Narrative and structured inputs mixed together",
      "Contextual hints and examples",
      "AI regenerate and save-aware behavior",
    ],
  },
  {
    title: "Operational record pages",
    body: "Execution-facing screens replace long narrative blocks with logs, tables, boards, rows, filters, and CRUD dialogs so teams can act on live delivery data quickly.",
    bullets: [
      "Row-based records",
      "Inline status actions",
      "Stream-backed or table-backed data layouts",
    ],
  },
];

const corePages = [
  {
    title: "Landing page",
    body: "The landing experience is a narrative product showcase. It contains a large hero, value proposition copy, capability highlights, proof-style content, and calls to action into sign-in, pricing, or account creation.",
    bullets: [
      "Hero headline and primary CTA band",
      "Capability and lifecycle storytelling sections",
      "Trust, product explanation, and conversion-oriented layout blocks",
    ],
  },
  {
    title: "Sign-in and create-account pages",
    body: "These are clean, centered auth card layouts. They prioritize clarity over density: logo, title, concise helper copy, core fields, password visibility controls, and one primary action.",
    bullets: [
      "Single-card auth surface",
      "Email and password inputs with support links",
      "Low-noise layout that moves quickly into the app",
    ],
  },
  {
    title: "Pricing page",
    body: "The pricing UI presents commercial tiers, feature differentiation, payment or subscription cues, and plan selection actions. It is designed to convert while explaining entitlement differences.",
    bullets: [
      "Tier cards and benefit comparison",
      "Billing and coupon context",
      "Subscription path into checkout or account action",
    ],
  },
  {
    title: "Dashboards",
    body: "Dashboard pages are overview-oriented. They aggregate active projects or workspaces, status cues, quick links into lifecycle modules, and contextual summaries instead of heavy form input.",
    bullets: [
      "Workspace tiles or cards",
      "Progress and summary visibility",
      "Fast navigation into the next relevant module",
    ],
  },
];

const planningPages = [
  {
    title: "Project framework and charter pages",
    body: "These pages are strategic-definition surfaces. They contain goal framing, planning logic, governance details, charter fields, and guidance-oriented blocks that formalize the project direction.",
    bullets: [
      "Goal and milestone inputs",
      "Governance and ownership fields",
      "Structured narrative areas for formal project definition",
    ],
  },
  {
    title: "Front-End Planning workspace",
    body: "The FEP workspace acts like a planning control center. It usually contains a planning header, side navigation, summary indicators, and links into deeper subsections such as procurement, risks, and technology.",
    bullets: [
      "Cross-section planning navigation",
      "Summary or progress status surfaces",
      "Entry into detailed FEP modules",
    ],
  },
  {
    title: "FEP detail pages",
    body: "Requirements, risks, opportunities, procurement, contracts, infrastructure, technology, personnel, security, allowance, and milestone pages are card-heavy planning screens. Each page mixes longform notes, guided fields, AI actions, and structured rows or matrices.",
    bullets: [
      "Multiple planning cards per page",
      "Examples, helper text, and AI-assisted inputs",
      "Summaries and cross-linked planning outputs",
    ],
  },
  {
    title: "Cost and solution analysis pages",
    body: "These pages are analytical rather than purely descriptive. They combine comparison structures, numeric or semi-structured inputs, recommendation text, and decision support summaries.",
    bullets: [
      "Option or scenario comparison panels",
      "Tables and cost model summaries",
      "Decision-oriented output sections",
    ],
  },
];

const designPages = [
  {
    title: "Design phase and technical alignment pages",
    body: "These pages support architecture and delivery readiness. The UI usually contains specification cards, interface or dependency notes, architecture-related artifacts, and technical explanatory text.",
    bullets: [
      "Technical narrative cards",
      "Structured specifications or design lists",
      "Readiness framing rather than execution tracking",
    ],
  },
  {
    title: "Detailed design, backend, engineering, and UI/UX pages",
    body: "Design-specialist screens move deeper into components, layers, constraints, deliverables, and implementation specifics. The UI shifts toward structured lists and technical blocks rather than generic project summaries.",
    bullets: [
      "Design element sections",
      "Architecture or component tables",
      "Technical fields and implementation-ready notes",
    ],
  },
  {
    title: "Tools integration and whiteboard-style pages",
    body: "These pages are integration-aware workspaces. They present integration entries, auth state, connection controls, and in some cases diagram or whiteboard-oriented canvases.",
    bullets: [
      "Connection state and auth cues",
      "Provider-specific controls",
      "Canvas or diagram surfaces where applicable",
    ],
  },
];

const operationsPages = [
  {
    title: "Execution plan and schedule pages",
    body: "These are operational workspace pages with heavier use of data tables, sequence rows, dependencies, and control actions. They are designed for active management rather than document drafting.",
    bullets: [
      "Table or board-driven structure",
      "Create, edit, delete, and move actions",
      "Live delivery visibility over narrative form content",
    ],
  },
  {
    title: "Issue, change, contract, vendor, and risk tracking pages",
    body: "These pages behave like operational registers. Users see rows, status chips, details, filters, dialogs, and action controls that support updates during project execution.",
    bullets: [
      "Log or register style layouts",
      "Status-aware controls and row actions",
      "Operational detail with real-time persistence patterns",
    ],
  },
  {
    title: "Team, stakeholder, and meeting pages",
    body: "These pages are coordination surfaces. They combine roster-like structures, role tables, meeting resources, stakeholder records, and training plans with a practical management UI.",
    bullets: [
      "People and responsibility structures",
      "Meeting or training resource sections",
      "Operational team coordination controls",
    ],
  },
  {
    title: "Launch and closure pages",
    body: "Launch and close-out UI tends to combine checklists, sign-off or approval cues, final summaries, completion records, and handover-oriented content sections.",
    bullets: [
      "Checklist and readiness structure",
      "Completion and transition sections",
      "Final-state summaries and closure documentation",
    ],
  },
];

const adminPages = [
  {
    title: "Admin dashboard",
    body: "The admin home UI is control-tower oriented. It favors quick access to critical management domains rather than end-user workflow narration.",
    bullets: [
      "Admin navigation and control tiles",
      "Fast access to projects, users, coupons, and subscriptions",
      "Operational rather than storytelling layout",
    ],
  },
  {
    title: "Users, projects, coupons, and lookup pages",
    body: "Admin detail pages are management tables with filtering, row detail, lookup controls, and action affordances. They are built for efficiency and operational confidence.",
    bullets: [
      "Searchable or filterable records",
      "Actionable table rows",
      "Management-focused information density",
    ],
  },
  {
    title: "Content administration and governance surfaces",
    body: "Content and governance UI supports safe change control. It exposes configuration, editable content, role-aware behavior, and operational safeguards around modifications.",
    bullets: [
      "Editable content blocks",
      "Governance or confirmation patterns",
      "High-trust admin interaction model",
    ],
  },
];

function createEl(tag, className, text) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text) el.textContent = text;
  return el;
}

function renderNav() {
  const mount = document.getElementById("guide-section-nav");
  guideSections.forEach((section) => {
    const link = createEl("a", "sidebar-link", section.label);
    link.href = `#${section.id}`;
    mount.appendChild(link);
  });
}

function renderHeroStats() {
  const mount = document.getElementById("guide-hero-stats");
  guideHeroStats.forEach((item) => {
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

function renderGuideGrid(targetId, items) {
  const mount = document.getElementById(targetId);
  items.forEach((item) => {
    const card = createEl("article", "guide-card");
    card.dataset.search = `${item.title} ${item.body} ${(item.bullets || []).join(" ")}`.toLowerCase();
    card.append(createEl("h3", "", item.title), createEl("p", "", item.body));
    if (item.bullets?.length) {
      const list = createEl("ul");
      item.bullets.forEach((bullet) => list.appendChild(createEl("li", "", bullet)));
      card.appendChild(list);
    }
    mount.appendChild(card);
  });
}

function applySearch(query) {
  const normalized = query.trim().toLowerCase();
  const searchable = document.querySelectorAll("[data-search]");

  searchable.forEach((node) => {
    const haystack = node.dataset.search || "";
    node.classList.toggle("hidden", Boolean(normalized) && !haystack.includes(normalized));
  });

  document.querySelectorAll(".content-section").forEach((section) => {
    const hasVisible = [...section.querySelectorAll("[data-search]")]
      .some((node) => !node.classList.contains("hidden"));
    section.classList.toggle("hidden", Boolean(normalized) && !hasVisible);
  });
}

function boot() {
  renderNav();
  renderHeroStats();
  renderGuideGrid("ui-principles-grid", uiPrinciples);
  renderGuideGrid("core-pages-grid", corePages);
  renderGuideGrid("planning-pages-grid", planningPages);
  renderGuideGrid("design-pages-grid", designPages);
  renderGuideGrid("operations-pages-grid", operationsPages);
  renderGuideGrid("admin-pages-grid", adminPages);

  const input = document.getElementById("guide-search-input");
  input.addEventListener("input", (event) => applySearch(event.target.value));
}

boot();
