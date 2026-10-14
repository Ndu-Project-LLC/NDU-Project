/// Hand-authored walkthroughs for the four tabbed MVP module screens:
/// Work Breakdown Structure, Schedule, Cost Estimate and Change Management.
///
/// Unlike the sweep-derived page tours, module tours are fully authored:
/// every tab gets its own stop with copy a product manager wrote on purpose,
/// and the tour switches tabs for the user as it moves along. The heading
/// strings used as spotlight anchors must match the on-screen text exactly
/// (a trailing ellipsis means prefix match for dynamic titles).
///
/// See `page_walkthrough.dart` (`ModuleTourSpec`) for the mechanics.
library;

import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/page_walkthrough.dart';
import 'package:ndu_project/widgets/page_tours/page_tour.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Work Breakdown Structure
// ─────────────────────────────────────────────────────────────────────────────

/// Intro/outro copy for the WBS module tour (keyed by the chip's page id).
const PageTour wbsModuleTour = PageTour(
  title: 'Work Breakdown Structure',
  icon: Icons.account_tree_outlined,
  intro:
      'The Work Breakdown Structure is where your project\'s scope becomes an '
      'executable plan. Every deliverable, work package and task hangs off '
      'this one hierarchy — and what you build here flows straight into the '
      'Schedule, the Cost Estimate and progress tracking. This tour walks '
      'through all five tabs in order.',
  bullets: [
    'The tour switches tabs for you — just keep pressing Next',
    'The structure follows your project methodology automatically',
    'Press Escape at any time to leave the tour',
  ],
  outro:
      'That is the whole WBS module. Build the hierarchy in the Builder, keep '
      'it costed in Cost by WBS, validate it before baselining, and export it '
      'whenever you need a clean snapshot for stakeholders.',
);

/// Stops for the WBS module tour, one per tab.
const List<ModuleTourStop> wbsModuleTourStops = [
  ModuleTourStop(
    tabIndex: 0,
    title: 'Builder — shape the hierarchy',
    description:
        'The Builder is the canvas where the whole project takes shape. Add '
        'top-level elements, nest work packages beneath them, rename and '
        're-order anything directly on the tree. The level labels and default '
        'framework adapt to the methodology chosen on the Project Framework '
        'screen, so an Agile project breaks down into Epics, Features and '
        'Stories while a Waterfall project uses Deliverables and Work '
        'Packages.',
    bullets: [
      'Add top-level elements from the toolbar, or start from a framework template',
      'Expand and collapse branches to focus on the area you are planning',
      'Everything saves automatically to this project as you work',
    ],
  ),
  ModuleTourStop(
    tabIndex: 1,
    heading: 'Cost by WBS Level',
    title: 'Cost by WBS — money on the tree',
    description:
        'This tab rolls the project\'s cost lines up the WBS so every element '
        'carries its share of the budget. Levels that attract no cost are '
        'flagged immediately — an uncosted work package discovered here costs '
        'nothing to fix, but the same discovery at baseline is a re-plan. '
        'Lines from the Initial Cost Estimate import automatically, and '
        'anything that could not be mapped to the tree is listed for you to '
        're-assign.',
    bullets: [
      'Cost distribution is shown per level, from top-level elements down',
      'Work packages without cost and unlinked cost lines are called out explicitly',
      'Fix gaps here before you lock the Cost Estimate baseline',
    ],
  ),
  ModuleTourStop(
    tabIndex: 2,
    heading: 'AI WBS Generator',
    title: 'AI Generator — draft a branch in seconds',
    description:
        'The AI generator drafts WBS branches from a short description of the '
        'work. Describe what needs to happen — a phase, a deliverable, a work '
        'stream — and KAZ AI proposes a structured breakdown you can review, '
        'trim and insert into the tree. It is an accelerator for the '
        'blank-page problem, not an autopilot: you stay the author of record.',
    bullets: [
      'Describe the work in plain language and let KAZ AI propose the breakdown',
      'Review the draft before it is inserted — nothing lands without you',
      'Works best when the description names concrete deliverables',
    ],
  ),
  ModuleTourStop(
    tabIndex: 3,
    heading: 'WBS Validator',
    title: 'Validator — structural health check',
    description:
        'The Validator runs the structural checks a reviewing engineer would: '
        'elements without children, packages without owners, levels deeper '
        'than your framework expects. Results are graded PASS, WARN and FAIL '
        'so you know what blocks a baseline and what is merely worth a look. '
        'Run it before every major milestone — a clean validator is the '
        'cheapest insurance the schedule will ever get.',
    bullets: [
      'FAIL items should be resolved before the WBS is baselined',
      'WARN items are judgement calls — review, then accept or fix',
      'Re-run the validator after any significant restructuring',
    ],
  ),
  ModuleTourStop(
    tabIndex: 4,
    heading: 'WBS Summary',
    title: 'WBS Summary — export and link',
    description:
        'The Summary tab is the module\'s export desk and its bridge to the '
        'rest of the platform. Export the full hierarchy as JSON for tools '
        'and archives, or as an ASCII tree for documents and sign-off packs. '
        'You can also link WBS work packages directly to Cost Estimate lines '
        'here, closing the loop between scope and money.',
    bullets: [
      'Export as JSON for systems, or ASCII tree for documents',
      'Link work packages to cost lines to keep scope and budget in step',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Schedule
// ─────────────────────────────────────────────────────────────────────────────

/// Intro/outro copy for the Schedule module tour.
const PageTour scheduleModuleTour = PageTour(
  title: 'Schedule',
  icon: Icons.event_note_outlined,
  intro:
      'The Schedule module turns the WBS into time: activities, durations, '
      'dependencies and a critical path you can defend. Work in whichever '
      'view suits the moment — the List View for bulk editing, the Builder '
      'for structure, and the Gantt chart for the story your dates tell. The '
      'header panels above the tabs keep WBS packages, cost estimates and '
      'cross-section sync one glance away.',
  bullets: [
    'List View is the default — build dates fastest where you can see every row',
    'The tour switches tabs for you as it moves along',
    'Press Escape at any time to leave the tour',
  ],
  outro:
      'That is the whole Schedule module. Keep activities flowing in List '
      'View, shape dependencies in the Builder, and read the plan\'s story in '
      'the Gantt. The schedule stays in step with the WBS and the Cost '
      'Estimate automatically.',
);

/// Stops for the Schedule module tour, one per tab.
const List<ModuleTourStop> scheduleModuleTourStops = [
  ModuleTourStop(
    tabIndex: 0,
    heading: 'List View — …',
    headingAlt: 'No matching activities',
    title: 'List View — every activity, one surface',
    description:
        'List View lays every schedule activity out in a single editable '
        'table, because when you are building a schedule you need to see all '
        'line items at once and fill in dates and durations inline — not open '
        'one card at a time. The summary cards on top track total activities, '
        'critical-path count, progress and completion as you type.',
    bullets: [
      'Edit dates and durations directly in the grid',
      'Summary cards update live as the plan changes',
      'Sort and filter to work one work package at a time',
    ],
  ),
  ModuleTourStop(
    tabIndex: 1,
    heading: 'Activity Tree',
    title: 'Builder — structure and dependencies',
    description:
        'The Builder shows the schedule as a tree of activity groups, so the '
        'shape of the work stays visible while you wire dependencies and '
        'timelines. Key metrics — total activities, timeline span, dominant '
        'domain — sit above the tree, and the setup dialog captures the '
        'project timeline basis when you are starting from scratch.',
    bullets: [
      'Group activities the way the work actually nests',
      'Timeline span and activity counts update as the tree grows',
      'The structure here mirrors the WBS packages from the header panel',
    ],
  ),
  ModuleTourStop(
    tabIndex: 2,
    heading: 'Gantt Chart — …',
    headingAlt: 'No activities yet',
    title: 'Gantt — the plan\'s story in bars',
    description:
        'The Gantt renders the schedule as a timeline: bars for every '
        'activity, dependencies drawn between them, and the critical path '
        'highlighted so the dates that actually govern delivery stand out. '
        'Slippage is obvious here long before it is obvious in a table — make '
        'this the view you present in steering meetings.',
    bullets: [
      'The critical path is highlighted — protect those activities first',
      'Dependencies show how a slip cascades through the plan',
      'The chart fills in as activities are added in List View or the Builder',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Cost Estimate
// ─────────────────────────────────────────────────────────────────────────────

/// Intro/outro copy for the Cost Estimate module tour.
const PageTour costEstimateModuleTour = PageTour(
  title: 'Cost Estimate',
  icon: Icons.account_balance_outlined,
  intro:
      'The Cost Estimate module is where the project\'s money is planned, '
      'defended and controlled. Ten tabs take a line from first entry to a '
      'locked baseline: build costs in the Builder, explain them in the Basis '
      'of Estimate, route them through review, lock the baseline and then '
      'track variance against it for the rest of delivery. This tour visits '
      'every tab in working order.',
  bullets: [
    'Ten tabs, one workflow: build → explain → review → lock → track',
    'The tour switches tabs for you as it moves along',
    'Press Escape at any time to leave the tour',
  ],
  outro:
      'That is the whole Cost Estimate module. The discipline that makes it '
      'work: keep the Builder current, keep the BOE honest, drive the review '
      'to acceptance, and treat the locked baseline as the number everyone '
      'answers to.',
);

/// Stops for the Cost Estimate module tour, one per tab.
const List<ModuleTourStop> costEstimateModuleTourStops = [
  ModuleTourStop(
    tabIndex: 0,
    heading: 'Category Details',
    headingAlt: 'Lines by Category',
    title: 'Cost Dashboard — the estimate at a glance',
    description:
        'The Dashboard condenses the whole estimate onto one screen: headline '
        'KPIs for total cost and reserves, the cost composition breakdown, '
        'and category details that show exactly where the money sits. When '
        'the estimate is still empty this tab tells you that plainly instead '
        'of showing zeros — head to the Builder to add the first cost lines.',
    bullets: [
      'KPI cards include the management reserve, not just the raw total',
      'Cost composition shows the balance across categories',
      'Category details is where you spot top-heavy estimates early',
    ],
  ),
  ModuleTourStop(
    tabIndex: 1,
    heading: 'Cost Line Builder',
    title: 'Builder — where estimate lines are born',
    description:
        'The Builder is the engine room of the estimate. Cost lines are '
        'grouped into Direct Costs, Indirect Costs, SSHER & Quality and '
        'Additional Elements, each edited inline with quantities, rates and '
        'totals that recalculate as you type. The KPI tiles keep the running '
        'tab total against the estimate total in view so drift is caught the '
        'moment it starts.',
    bullets: [
      'Switch sub-tab groups to work one cost family at a time',
      'Line totals recalculate live from quantity × rate',
      'Every line here feeds Cost by WBS, the dashboard and the baseline',
    ],
  ),
  ModuleTourStop(
    tabIndex: 2,
    heading: 'Cost by WBS Level',
    title: 'Cost by WBS — every pound on the tree',
    description:
        'This tab maps estimate lines onto the Work Breakdown Structure so '
        'each work package carries its share of the budget. Distribution is '
        'shown per WBS level, uncosted packages are flagged, and any line '
        'that could not be attached to the tree is listed for re-assignment. '
        'It is the read-back view of what the Builder writes — keep it clean '
        'before you consider a baseline.',
    bullets: [
      'Level-by-level distribution exposes scope that carries no cost',
      'Unlinked cost lines must be re-assigned before baselining',
      'Shares the same engine as the WBS module\'s Cost by WBS tab',
    ],
  ),
  ModuleTourStop(
    tabIndex: 3,
    heading: 'Basis of Estimate',
    title: 'BOE — why the numbers are credible',
    description:
        'The Basis of Estimate is the estimate\'s sworn testimony: the '
        'accuracy range, the scope basis, the assumptions, constraints and '
        'exclusions behind the numbers, plus the estimation methodology and '
        'escalation assumptions. Reviewers read this tab before they read '
        'any total — a number without a basis is a guess, and this tab is '
        'where guesses are retired.',
    bullets: [
      'Record the accuracy range reviewers should read against the totals',
      'Assumptions, constraints and exclusions each get their own register',
      'Methodology and escalation assumptions keep estimates comparable over time',
    ],
  ),
  ModuleTourStop(
    tabIndex: 4,
    heading: 'AI Assistant',
    title: 'AI Assistant — a second pair of eyes',
    description:
        'The AI tab asks KAZ AI to pressure-test and draft for this estimate: '
        'suggest missing cost lines, sanity-check category weightings and '
        'propose wording for the basis of estimate. Suggestions arrive as a '
        'reviewable list — accept individually, edit freely, or discard. The '
        'estimate remains yours; the assistant just shortens the debate.',
    bullets: [
      'Run a suggestion pass after the first draft of the Builder is in',
      'Accept or reject each suggestion individually — nothing auto-applies',
      'Availability depends on AI credits; the tab says so when offline',
    ],
  ),
  ModuleTourStop(
    tabIndex: 5,
    heading: 'Stakeholders & Access',
    title: 'Stakeholders — who sees and approves',
    description:
        'This tab controls the estimate\'s audience. Stakeholders lists the '
        'people attached to the cost view, and Access Control defines what '
        'each of them can do — from read-only visibility to approval rights. '
        'Setting this up early means the right reviewers are already watching '
        'when the estimate reaches review, instead of being hunted down '
        'afterwards.',
    bullets: [
      'Grant edit rights sparingly — estimates reward single authorship',
      'Approvers configured here are the ones the Review tab expects',
    ],
  ),
  ModuleTourStop(
    tabIndex: 6,
    heading: 'GL Code Mapping',
    title: 'GL Mapping — the bridge to accounting',
    description:
        'GL Code Mapping attaches general-ledger codes to cost categories so '
        'the estimate speaks the finance department\'s language. When actual '
        'costs start flowing in during execution, they reconcile against the '
        'plan through exactly these codes — a few minutes of mapping here '
        'saves hours of reconciliation archaeology later.',
    bullets: [
      'Map every category before the baseline is locked',
      'Codes follow your organisation\'s chart of accounts',
    ],
  ),
  ModuleTourStop(
    tabIndex: 7,
    heading: 'Review & Acceptance',
    title: 'Review — drive the estimate to acceptance',
    description:
        'The Review tab walks the estimate through formal acceptance: the '
        'review meeting gets scheduled, acceptance steps are confirmed one '
        'by one, and progress is tracked until the estimate is formally '
        'accepted. Acceptance here is what unlocks the Baseline tab — no '
        'shortcuts, which is exactly the point.',
    bullets: [
      'Schedule the review meeting from this tab when you are the approver',
      'Each acceptance step is confirmed explicitly and stays auditable',
    ],
  ),
  ModuleTourStop(
    tabIndex: 8,
    heading: 'Locked Baseline',
    headingAlt: 'No baseline yet',
    title: 'Baseline — the number everyone answers to',
    description:
        'Baselining freezes the accepted estimate as the project\'s cost '
        'reference: totals, lines and metadata are snapshotted, and the '
        'snapshot becomes the yardstick for the rest of delivery. Before the '
        'first baseline this tab explains what locking means; afterwards it '
        'shows the frozen snapshot with its metadata and authorized totals.',
    bullets: [
      'A baseline can only change through a formal re-baseline',
      'Snapshot metadata records who locked, when, and on whose approval',
    ],
  ),
  ModuleTourStop(
    tabIndex: 9,
    heading: 'Variance & Re-baseline',
    headingAlt: 'No baseline to compare',
    title: 'Variance — plan versus reality',
    description:
        'Once a baseline exists, this tab compares live cost data against it '
        'and grades the difference by category. Positive variance gets '
        'explained, negative variance gets managed, and when reality has '
        'genuinely moved the re-baseline flow records a controlled, approved '
        'reset instead of a quiet drift. This is the tab that keeps the '
        'estimate a living control, not a museum piece.',
    bullets: [
      'Category variance shows where the plan is bending first',
      'Re-baselining is deliberate and auditable — never a silent overwrite',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Change Management
// ─────────────────────────────────────────────────────────────────────────────

/// Intro/outro copy for the Change Management module tour.
const PageTour changeManagementModuleTour = PageTour(
  title: 'Change Management',
  icon: Icons.sync_alt,
  intro:
      'Change Management is the project\'s immune system: every scope, cost '
      'and schedule change is raised, impact-assessed, approved through a '
      'defined workflow and then implemented against the baseline — with an '
      'audit trail behind all of it. This tour walks the eight tabs in the '
      'order a change request actually flows through them.',
  bullets: [
    'Eight tabs follow a CR\'s life: raise → assess → approve → implement',
    'The tour switches tabs for you as it moves along',
    'Press Escape at any time to leave the tour',
  ],
  outro:
      'That is the whole Change Management module. The habit that makes it '
      'work: raise everything, assess honestly, let the workflow decide, and '
      'let the audit trail answer for you when questions come later.',
);

/// Stops for the Change Management module tour, one per tab.
const List<ModuleTourStop> changeManagementModuleTourStops = [
  ModuleTourStop(
    tabIndex: 0,
    title: 'Dashboard — the change pulse',
    description:
        'The Dashboard answers the executive question in one look: how much '
        'change is the project absorbing? KPI cards track open CRs, pending '
        'approvals, emergency changes and re-baselines, a seven-day volume '
        'chart shows the trend, and the contingency & reserve panel shows how '
        'much approved change has eaten into the buffers. The impact summary '
        'and recent CRs list keep the newest pressure visible.',
    bullets: [
      'Watch emergency changes — a rising count signals planning gaps upstream',
      'Contingency burn is shown against the reserves you actually hold',
    ],
  ),
  ModuleTourStop(
    tabIndex: 1,
    heading: 'Change Register',
    title: 'Change Register — every change, one ledger',
    description:
        'The Register is the single source of truth for change requests: '
        'every CR raised on the project, with its type, priority, status and '
        'owner. Select a row to focus the Impact Detail, Workflow and '
        'Implementation tabs on that CR. Filter and search here whenever the '
        'question is "what happened to that change?" — the answer always '
        'starts in this table.',
    bullets: [
      'Raise a quick CR with the new-change action in the header',
      'Selecting a CR here drives the detail tabs that follow',
    ],
  ),
  ModuleTourStop(
    tabIndex: 2,
    heading: 'Impact & Approval Summary',
    title: 'Impact & Approval Summary — decisions at a glance',
    description:
        'This tab rolls every CR\'s impact assessment and approval state into '
        'one summary view, so the board can see which changes are waiting on '
        'whom and what they are worth. It is the tab to project in change '
        'control board meetings: approval bottlenecks and heavy-hitting '
        'changes surface immediately instead of hiding inside individual '
        'records.',
    bullets: [
      'Approval bottlenecks show up here before they hurt the schedule',
      'Impacts are aggregated across cost, scope and schedule dimensions',
    ],
  ),
  ModuleTourStop(
    tabIndex: 3,
    heading: 'Audit Trail',
    title: 'Audit Trail — who did what, and when',
    description:
        'The Audit Trail records every meaningful action on every change '
        'request — creation, edits, approvals, rejections, baseline '
        'applications — with timestamps and the baseline revision history '
        'alongside. When a stakeholder asks why a change was approved three '
        'months ago, this tab answers in seconds, without recollection '
        'exercises.',
    bullets: [
      'Filter to one CR or one actor to reconstruct any decision',
      'Baseline revisions are logged here automatically',
    ],
  ),
  ModuleTourStop(
    tabIndex: 4,
    heading: 'Create Change Request',
    title: 'Create CR — raise a change properly',
    description:
        'This tab is the structured intake form for a new change request. '
        'Section A captures identification, B the description, C the scope '
        'impact, D the cost & schedule impact, and E any supporting '
        'documents. Filling it in fully is what makes the downstream '
        'assessment meaningful — a CR with a vague description produces a '
        'vague approval decision.',
    bullets: [
      'Work through sections A–E in order; each maps to an assessment field',
      'Attach documents in section E — evidence shortens the approval loop',
    ],
  ),
  ModuleTourStop(
    tabIndex: 5,
    heading: 'Impact Assessment Detail',
    headingAlt: 'No change requests available',
    title: 'Impact Detail — score the change honestly',
    description:
        'Impact Detail works through the consequences of the selected CR: '
        'scope, cost, schedule, risk and quality dimensions, rolled up into a '
        'composite score that drives the approval conversation. The honest '
        'score here is the one that protects the project — optimistic '
        'assessments are how small changes become large overruns.',
    bullets: [
      'Select the CR in the Change Register first if the tab looks empty',
      'The composite score aggregates every impact dimension you filled in',
    ],
  ),
  ModuleTourStop(
    tabIndex: 6,
    heading: 'Approval Workflow Builder',
    headingAlt: 'No change requests available',
    title: 'Workflow — route the decision',
    description:
        'The Workflow Builder defines who signs off the selected CR and in '
        'what order: approval steps are added, assigned to roles, and walked '
        'in sequence until the change is approved or rejected. A change worth '
        'making is a change worth routing properly — this tab is the control '
        'that keeps approvals deliberate rather than accidental.',
    bullets: [
      'Steps are walked in order — each approver sees the decisions before theirs',
      'Rejections land here too, with the reason recorded for the audit trail',
    ],
  ),
  ModuleTourStop(
    tabIndex: 7,
    heading: 'Implementation & Baseline',
    headingAlt: 'No change requests available',
    title: 'Implementation — make the change real',
    description:
        'Approved changes do not implement themselves. This tab tracks the '
        'selected CR through execution and, where the change alters the '
        'project\'s cost or schedule baseline, applies it to the baseline as '
        'a formal revision — with rollback available if the implementation '
        'proves wrong. This is where governance meets delivery.',
    bullets: [
      'Apply approved changes to the baseline explicitly — never by drift',
      'Rollback is available for implementations that do not hold up',
    ],
  ),
];
