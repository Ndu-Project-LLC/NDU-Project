# Planning-phase review fixes (Lusaka 27) Implementation Plan

> **For the agent picking this up:** this plan came out of the 2026-09-28 Lusaka 27
> walkthrough. The owner's verbatim asks (with transcription caveats) are in
> `docs/voice_notes/2026-09-28-lusaka-27-planning-review-transcript.md`.

**Goal:** Make the rest of the Planning phase behave the way the owner reviewed —
an Execution Plan that does not duplicate project-wide sections (and belongs to
Waterfall, not Agile), a Risk Assessment that reuses the FEP risk log on both
sides of the phase change, contracting and procurement driven by a per-contract
strategy and a log table, and one consistent "log" vocabulary across every table.

**Architecture:** No new screens. Every ask lands on an existing screen, its
existing service, and the existing nav surfaces that define order
(`sidebar_navigation_service`, `planning_phase_navigation`,
`initiation_like_sidebar`). Data already carries the links: `ProjectDataModel`
risks, `AgileWireframeService`, `KanbanConfigService`, and the schedule's
`ScheduleBasis.deliveryModel` (`'AGILE' | 'WATERFALL' | 'HYBRID'`) for the
phase gating.

**Tech stack:** Flutter/Dart, Provider, Firestore via the existing services,
`flutter_test`, `analysis_options.yaml` lints.

---

## Ordering rule for the whole plan

Four of the asks are **removals** of things that should never have been separate
sections. Do those first (Task 1) so the later screens are reviewed against the
final flow, not the duplicated one. Tasks 3–4 (risk) and 5–6 (contract/procure)
are the two largest bodies of work and are independent of each other.

---

### Task 1: Drop the Execution Plan duplicates of project-wide sections — DONE

**Files:**
- Modified: `lib/services/sidebar_navigation_service.dart` (remove three
  `SidebarItem`s from `_sidebarOrder`)
- Modified: `lib/utils/planning_phase_navigation.dart` (remove the same three
  `PlanningPage` entries)
- Modified: `lib/widgets/initiation_like_sidebar.dart` (remove the same three
  sub-sub menu items)
- Test: `test/routing/execution_plan_dedup_test.dart` (new)

**The three duplicates, and the project-wide section that already covers each:**

| Removed checkpoint | Existing project-wide section |
| --- | --- |
| `execution_issue_management` | `issue_management` — "Issue Management" |
| `execution_plan_lessons_learned` | `lessons_learned` — "Lessons Learned" |
| `execution_plan_stakeholder_identification` | `stakeholder_management` — "Stakeholder Management" |

"Execution Plan is also … I see execution issues management. I don't know why
that's there" / "I don't think we need an execution-specific one" / "the
stakeholder identification we've already done that in the beginning".

**Screens and routes are left in place.** Only the flow entries go: the screens,
their route constants, `navigation_route_resolver` aliases and
`project_data_provider` completion weights stay, so a deep link or a saved
bookmark cannot 404. The test pins *the flow*, not the route table.

**Not done here:** the wider rule that an Agile project gets no Execution Plan at
all (and a Waterfall project no Agile Delivery) — that is Task 2.

---

### Task 2: Gate the Execution Plan to Waterfall projects (and Agile Delivery to Agile) — DONE

**Files:**
- Added: `lib/utils/delivery_model_nav_gate.dart` (the pure rule)
- Modify: `lib/services/sidebar_navigation_service.dart` (a `deliveryModel`
  filter over the execution-plan block; the flow walkers take an optional
  `deliveryModel`)
- Modify: `lib/widgets/initiation_like_sidebar.dart` (hide the Execution Plan
  group when the model is `AGILE`, the Agile Delivery group when `WATERFALL`)
- Modify: `lib/utils/planning_phase_navigation.dart` (Next/Back and the
  `backLabel` / `nextLabel` labels follow the same gate)
- Modify: `lib/utils/project_data_helper.dart` (`deliveryModelOrNull`)
- Modify: `lib/services/project_route_registry.dart` and the two boundary
  screens that label the crossing (`planning_technology_screen.dart`,
  `deliverable_roadmap_subsections_screen.dart`)
- Test: `test/routing/delivery_model_nav_gate_test.dart` (new)

The owner's rule: *"there should be no execution plan for the agile delivery. The
execution plan is mostly so if the waterfall project is going to be blanked out,
they cannot click on it, they cannot access it."*

**Landed as a pure rule, then wired in.** `DeliveryModelNavGate` owns the two
checkpoint sets (the Execution Plan block and the Agile Delivery block — pinned
against the real flow by the test) plus `showsExecutionPlan` and
`showsAgileDelivery`. `SidebarNavigationService` exposes
`itemsForDeliveryModel` and takes an optional `deliveryModel` on
`getNextAccessibleItem`, `getPreviousAccessibleItem`, `getNextItem`,
`getPreviousItem` and `itemsBetween`. The sidebar widget hides both groups, and
`PlanningPhaseNavigation` passes the model when it walks the flow — so on an
Agile project Next from Agile Map Out no longer opens the Execution Plan, and on
a Waterfall project Next from Technology Planning skips straight to it.

**HYBRID (the open question).** The recording names only the two pure cases, so
Hybrid keeps **both** sections: a hybrid project runs Waterfall execution
planning *and* Agile delivery, and the gate hides a section only when the model
rules it out entirely. An *unset* model also keeps both, through
`ProjectDataHelper.deliveryModelOrNull`, which reports "no choice" instead of
falling back to Waterfall (`resolvedProjectMethodology`'s default) — so an
unconfigured project's flow is exactly what it was. All four cases are pinned in
the test. If the owner prefers the existing `dm == 'AGILE' || dm == 'HYBRID'`
precedent applied to navigation too, flip the two predicate bodies; the test
states the intended behaviour in one place.

The screens, routes and on-page step lists are untouched, matching Task 1: only
the *flow* is gated, so a deep link still resolves.

---

### Task 3: Planning Risk Assessment reuses the FEP risk log table — DONE

**Files:**
- Added: `lib/models/risk_log.dart` (the one column set + row mapping)
- Modify: `lib/screens/risk_assessment_screen.dart` (the risk log table, first;
  cards second)
- Modify: `lib/screens/front_end_planning_risks_screen.dart` (same derivation,
  and its export prints the table too)
- Reuse: `lib/widgets/searchable_table_section.dart`,
  `lib/widgets/responsive_table_widgets.dart` (`buildNduTableWithExpand` → the
  table also expands to full screen) and `lib/widgets/wrapped_table_primitives.dart`
- Test: `test/models/risk_log_test.dart` (new)

**Landed as one shared log.** `RiskLogRow`/`riskLogColumns` map the canonical
store — `ProjectDataModel.frontEndPlanning.riskRegisterItems`, the list the FEP
risk register writes — into the log both screens render: ID, Risk Title,
Description, Category, Probability, Impact, Risk Level, Mitigation, Discipline,
Project Role, Owner, Status. Front End Planning's trailing "Action" column is
not in the spec: it is a control, not data, and the Planning copy is read-only.
The Planning screen shows the log as its primary table (table view default, card
view as the toggle, `buildNduTableWithExpand` for the expand-to-full-screen ask),
and its **metrics and risk matrix now count those same rows** — which is the fix
for "there are 14 medium risks … here they are showing three high and three
medium". Front End Planning's own `_deriveRiskLevel`/`_normalizeRiskScale` now
delegate to the same module, so the "Risk Level" column cannot drift between the
two screens.

**Export.** The Planning export printed only Project Info and Notes — the table
"didn't show anything". It now appends `PdfSection.table('Risk Log', …)` from the
same rows; Front End Planning's export got the same table section.

**Deviation — no cost/schedule-impact columns.** The transcript names "the
potential cost impact with the schedule impact", and the plan's first draft
listed them as columns. `RiskRegisterItem` does carry `costImpactMostLikely` /
`scheduleImpactMostLikely` / `costImpactMin|Max` / `scheduleImpactMin|Max`, but
**nothing in the app ever writes them** (they are read nowhere outside
`project_data_model.dart`), so the columns would have been permanently blank on
every project. They are left out rather than shipped empty — flag this for the
owner: if the risk form should capture cost/schedule impact, that is a small
addition to the FEP risk sheet plus two columns in `riskLogColumns`.

**Kept, not removed.** The Planning screen's own register (Add Risk / Filter /
CSV import and the planning-local entries) is still below the carried-over log,
so nothing that worked before regressed and no project's planning entries
disappear. Once the owner confirms the carried-over log is the only table they
want in Planning, that block can be deleted and the screen becomes single-source;
it is flagged as a follow-up rather than guessed at now.

---

### Task 4: Make the Risk Assessment section sign-off-gated — DONE

**Files:**
- Added: `lib/models/risk_assessment_signoff.dart` (the pure gate + allowance)
- Modify: `lib/screens/risk_assessment_screen.dart` (the confirmation, the top
  risks and the allowance)
- Test: `test/models/risk_assessment_signoff_test.dart` (new)

**The gate.** `RiskAssessmentSignoff.confirmationSentence` is the owner's
sentence, verbatim: *"I confirm that I have reviewed this with all the key
stakeholders."* The section's Next button (header and the mobile chevron) now
runs `blockerFor(rows)` first and, while something is missing, shows what is
missing instead of advancing. In order: the confirmation tick, the date the log
was reviewed with the stakeholders, the review cadence, at least two logged
risks, and a mitigation plan on every top risk.

**Top risks up front.** A `Top Risks & Mitigation` card sits directly under the
page title, above everything else — the two-to-five worst risks (High before
Medium before Low, ties in log order) with their mitigation plan, and a count of
how many still have none. That is the "can be seen immediately" ask.

**Risk allowance.** A `Risk Allowance` card sits between the matrix and the risk
log — 0.6 % of the project budget, using the same
`ProjectDataHelper.getTotalEstimatedCostValue` the Project Charter uses as the
project's total. Before any budget exists it shows the label and "no budget
recorded yet" rather than a misleading `$0`.

**Stored without a model change.** The three sign-off values ride in the
existing `planningNotes` map
(`planning_risk_assessment_signoff_*`), round-tripped through
`fromPlanningNotes` / `toPlanningNotes`, so no `ProjectDataModel` change and no
migration.

**Deviation — the review cadence is an inference.** The recording only says the
review *did* happen with the stakeholders; the plan's first draft added "a risk
review/meeting cadence must be recorded". It is implemented as a required
cadence field (Monthly / Quarterly / Semi-annual / Annual) because the gate
needs to say what "reviewed" means over time, but it is the one condition here
that the owner did not state. If they would rather not record a cadence, drop
`hasCadence` from `blockerFor` and the field from the card; the rest of the gate
stands.

**Also worth confirming:** *"we have estimated this number as accepted"* is
treated as covered by the confirmation sentence itself, not a separate numeric
field — the owner asked for the sentence to be required, not for a second input.

---

### Task 5: Contracting — a contract log and a per-contract strategy — DONE

**Files:**
- Added: `lib/models/contract_rfp_cycle.dart` (the per-contract cycle: the
  owner's template, stage dates, the skip option, validation)
- Added: `lib/models/contract_log.dart` (the log columns + the row mapping)
- Modified: `lib/screens/planning_contracting_screen.dart` (the Contracts tab,
  the cycle popup, the FEP/contractor actions, Admin Controls, evaluation
  factors)
- Modified: `lib/services/contract_service.dart` (`rfpCycle`, `warrantyMonths`,
  `warrantyExpiryDate`, `keyDatesNotes` on `ContractModel` and
  `updatePlanningFields`)
- Tests: `test/models/contract_rfp_cycle_test.dart`,
  `test/models/contract_log_test.dart` (new, 29 tests)

**The contract log is the working view of the Contracts tab.** The old
"Packages" tab (and the `Packages` / `Add Package` wording) is gone: the tab is
now *Contracts* and its first section is the **Contract Log** — "that table
needs to be here. As a default view … This is where they have to go through the
process of building it out". Table first with the numbered `#` column
(`buildNduTableWithExpand`, so it expands to full screen), the package cards as
the secondary toggle, search, and a row per contract with: `#`, Contract, Scope,
Potential Value, Award Strategy, Type, RFP Cycle, Award Date, Status. Tapping a
contract name opens the edit dialog; tapping its cycle opens the cycle popup.

**A per-contract RFP cycle.** `ContractRfpCycle` is the owner's template with
their own durations — scope out to bidders 2 wk → **RFP issued** → bidder
response 4 wk → clarification 1 wk → evaluation 2 wk → documentation 1 wk →
**award** (10 weeks end to end, with the two milestones collapsing onto a date).
The *Set cycle* / *Edit cycle* action on a log row opens the popup the owner
asked for ("a button where you click on it and it can pop up and it can show you
where the cycle is"), with an adjustable start date, `− n wk +` steppers per
stage, the dated timeline, and the award date. Saving writes `rfpCycle` **and**
`targetAwardDate` (the award date drives the existing schedule milestone), and a
cycle can be back-planned from an award date the contract already carries.

**A small contract may skip the cycle.** The popup's *Skip the cycle* toggle
asks for one of `Sole Source / Direct Award / Small Value Contract / Emergency /
Single Qualified Bidder` and awards on the chosen date — "they can elect to keep
that and say sole source or award … they're not forced to go through the whole
process". A skip with no reason fails `validate()` and the save is refused.

**Per-contract strategy, not one story for the project.** The Overview tab's
project-wide *Contract Planning Strategy* radios — and the `contracting/strategy`
Firestore doc they read and wrote — are removed. Its place is a read-only
**Contract Strategy** card listing each contract's strategy, type and cycle
state, with the stat cards now reporting *Award Strategies* (`n in use`) and
*RFP Cycles* (`n to set`). Strategy and type remain editable per contract in the
edit dialog (`awardStrategy` / `contractType` already existed on the contract).

**Warranty before award.** Admin Controls gained a **Warranty & Key Dates
(before award)** block above the compliance checklist: warranty period (None /
6 / 12 / 24 / 36 months), the derived warranty expiry (award date + period) and
a key-dates note. `Warranty`, `Key Dates` and `Taxes` are pre-award compliance
items, so the checklist the owner pointed at ("where you had your legal
registration … instead before contract award") now covers them. The default RFP
evaluation criteria were rebalanced to include them and still sum to 100 %:
Technical 30 / Commercial 25 / Delivery 15 / **Warranty Terms 15 / Key Dates 10 /
Taxes & Duties 5**.

**Negotiation is hidden, not deleted.** The tab is out of the strip behind
`_showNegotiationTab = false`; `_NegotiationTab`, its dialog and its Firestore
fields are untouched. Flip the flag to bring it back.

**FEP carry-forward and the contractor list.** "Contract items auto-populate
from FEP" is the new **Add from FEP** action: it lists the initiation/FEP scopes
that do not already have a contract (`_planningScopeOptionsFromData`, matched on
`linkedFepScopeId`) and creates one contract per selected scope pre-filled with
the scope name, scope of work and potential value. The separate "FEP Scope
Inputs" card — the label the owner rejected — is deleted. **Import contractors**
runs the initiation `contractors` list into the log on demand, skipping names
already there (the FEP screen's one-shot seeding stays as it is).

**Export.** The screen's export carried only Project Info and Notes. It now
appends `PdfSection.table('Contract Log', …)` after them, from
`contractLogExportHeaders()` / `contractLogExportRows(contracts)` in
`contract_log.dart` — the same columns and the same numbered rows the on-screen
log draws, so the downloaded table cannot disagree with the screen. The
contracts are read from the same `ContractService.streamContracts` the log uses
(project id from `ProjectDataHelper.getData`); if that read fails the rest of
the export still goes out rather than the download erroring. The section is
added only when there is at least one contract, so an empty project keeps the
clean two-section export. Three tests in `contract_log_test.dart` (16 in the
file now) pin the header/row contract: headers are the log columns in order
(`#` first), every row lines up with them, and the rows are numbered from 1.

**Deviation — nothing to change in `front_end_planning_contracts_screen.dart`.**
The plan listed it as a file to modify, but it and the Planning section already
write the *same* `projects/{id}/contracts` collection through the same
`ContractService`, so Planning already carries FEP contracts forward; the log is
that collection rendered as a table. Its risk-register analogue needed a shared
model because the two screens had drifted apart (Task 3) — here there is one
store, so there is nothing to unify.

**Deviation — bidder scores were already per contract.** The Evaluation tab
builds one `ExpansionTile` per contract holding that contract's own
`evaluationScores`, criteria and vendor ranking, so "the score should be inside
each of them" is already true in the code; the owner was most likely looking at
the section-wide summary card. The evaluation-factors change above is the part
of that ask that was genuinely missing. Worth confirming on the next walkthrough
that the Evaluation tab now reads the way they meant.

**Deviation — the "cycle" is deliberately not a per-stage date editor.** The
popup sets a start date plus week counts per stage and shows the resulting
timeline, rather than letting each of the seven stages be dragged onto an
arbitrary date. The owner's own description was duration-based ("give two weeks
… give them four weeks"), so the durations are the input and the dates are
derived; a stage that needs to move independently is a start-date change.

---

### Task 6: Procurement — mirror contracting, log on top — DONE

**The page this is about.** The recording is explicit that the owner opened
*FEP's* procurement page — "can we look at procurement from the [FEP] … so if you
go back down to the procurement section of the front end planning, front end
planning, front end planning" — and then compared it to the planning one ("this
page is very different from the procurement page in the planning … that
continuity is important for every single section"). Every field he names lives in
`lib/screens/front_end_planning_procurement_screen.dart` and nowhere else: the
`Procurement Strategies` table (`Strategy Name` / `Category` / `Status`), the
`What to procure` section, the contract-scope block, and the dead search box. The
planning route's page (`PlanningProcurementScreen` → `PlanningProcurementV2Screen`)
has none of them. So this task lands on the FEP screen; the split between the two
screens is flagged at the end of this task.

**Files:**
- Added: `lib/models/procurement_log.dart` (the log columns, the row mapping, the
  long-lead rule and the overview numbers)
- Modified: `lib/screens/front_end_planning_procurement_screen.dart`
- Modified: `lib/widgets/procurement/procurement_items_list_view.dart` (table-
  first log, cards as the secondary toggle, chrome that only shows when it does
  something)
- Modified: `lib/screens/planning_procurement_v2_screen.dart` (vendor names into
  the log)
- Test: `test/models/procurement_log_test.dart` (new, 19 tests)

**The overview is a real dashboard now, and it carries the plan note.** The old
first tab was a grab-bag that never showed the log: a plan header followed by
contract scope management, the procurement-strategies table, a second copy of the
item list labelled "Procurement Scope", "What to procure", and vendors. It is now
the **plan header → plan note → Procurement Overview** card set (items, long lead,
ordered, overdue, total budget, committed %), which is the owner's ask — "it's
gonna be a dashboard that kind of shows the key status of the procured items and
the cost and all of that. It can sort of blank and then fill up as they get the
work done." The numbers come from `ProcurementStatusSummary`, so the dashboard and
the log can never disagree. The plan note (`_ProcurementPlanCard`) used to render
only in planning mode at page level; it now lives in the overview, "in the
overview at the top", in both modes.

**The log is the table, and it sits immediately after the overview.** The tab
named "Scope Details" is now **Procurement Log** (as is the button in the plan
header), and the item list the tab renders is a numbered, expandable table
(`buildNduTableWithExpand`, `#` first) with the card grid as the secondary toggle
— "this procurement table now [can] be called a procurement log … the table makes
sense". Columns: `#`, Item, Category, Priority, **Long Lead**, Budget, Est.
Delivery, Lead Time, Vendor, Status. The long-lead rule ("identify if they're
gonna be long lead items") moved into the pure module so the column, the overview
count and the old long-lead classification agree.

**What is no longer on the page.** Contract scope management ("contracting work
is not going to be here"), the procurement-strategies table ("strategy name,
category status, I don't know what that is"), the duplicate item list, and
"What to procure" ("this what-to-procure I don't understand that. So we need to
take that out.") are gone from the dashboard. They are behind one flag,
`_showLegacyProcurementSections = false`, rather than deleted, so the strategy
rows can be re-homed instead of rebuilt if they want them somewhere — the models,
services and seeded strategy data are untouched either way. This mirrors how the
owner asked for Negotiation to be handled ("hide it, don't delete it").

**Export.** Both procurement screens' exports carried only Project Info and
Notes, so the owner's "the table didn't show anything" applied here as well.
Each now appends `PdfSection.table('Procurement Log', …)` after Notes, from
`procurementLogExportHeaders()` / `procurementLogExportRows(items, vendorNames:)`
in `procurement_log.dart` — the same columns, the same numbered rows and the
same vendor-name resolution the on-screen log uses, so the downloaded table and
the screen cannot drift. It lands in `front_end_planning_procurement_screen.dart`
(exporting `_items`) and `planning_procurement_v2_screen.dart` (same), for the
same reason the log change landed in both: they share one items model and one
items view. The section is added only when the log has items. Four tests in
`procurement_log_test.dart` (23 in the file now) pin the contract: headers are
the log columns in order (`#` first), one numbered row per item in column order,
the vendor reads the way the table shows it (`Not assigned` when there is none),
and an empty log exports no rows.

**The busy-ness.** The log's toolbar used to render a search box with **no
handler behind it** on this page; controls now appear only when they do
something (`onSearchChanged != null`, more than one filter option), so the FEP
log is just "Add Item" plus the view toggle, while the planning screen keeps its
working search and filters. This is also the "if you have an overview then you
can remove the search [section]" item.

**Open question — the Contracting Workflow tab.** "This section is very busy …
like if you go left, like you have contracting work, contracting work is not
going to be here. Do you mind going left on that one?" reads like a gesture at
the tab strip, which on this page includes **Contracting Workflow** (and Vendor
Evaluation). That tab was **left in place**: it is part of the page's required-
section validation and its "Next:" flow, and pulling it out is a much larger
change than the dashboard cleanup. The contract-*scope* block, which is the same
objection in section form and is not part of the flow, was removed. Confirm on
the next walkthrough whether the tab itself should go.

**Open question — FEP vs planning procurement are two different pages.** They
share `ProcurementItemsListView` (so both now open on the log table), but the
planning page is still a separate screen with its own overview, and the owner's
"continuity is important for every single section" may eventually mean one page
in two modes — `FrontEndPlanningProcurementScreen` already has a `mode` switch for
exactly that. Not attempted here: merging them is a rewrite, not a review fix.

---

### Task 7: One "log" vocabulary, numbered tables, full-screen expand — DONE

**Files:**
- Added: `lib/models/issue_log.dart` (the issue log's columns, row mapping and
  the overview counts — the same shape as `risk_log` / `contract_log` /
  `procurement_log`)
- Modified: `lib/screens/issue_management_screen.dart` (the issue table is the
  **Issue Log** — numbered, expandable, and the only place the overview counts
  and the search rule come from)
- Modified: `lib/screens/execution_issue_management_screen.dart` (same heading
  and numbering; the screen stays reachable by route even though Task 1 took it
  out of the flow)
- Reuse: `buildNduTableWithExpand`
  (`lib/widgets/responsive_table_widgets.dart`)
- Test: `test/models/issue_log_test.dart` (new, 10 tests)

The owner asked for the same thing three times: *"this procurement table now [can]
be called a procurement log. The contract table can be called a contract log. The
issues management table can be called an issues log"* and *"all our tables should
be numbered"*, and *"the same comment I have with this entire site is to be
expandable … you can cover the screen"*.

**The issue management table is the Issue Log now.** The hand-built flex table
in `_ProjectIssuesLogCard` — the last table in these three screens that was not a
log — is replaced by `_IssueLogCard` rendering `buildNduTableWithExpand`, titled
**Issue Log**, with the numbered `#` first. Columns: `#`, ID, Issue, Type,
Severity, Status, Assignee, Due Date, Milestone, then the Edit / Delete controls.
The old heading "Project Issues Log" is now just "Issue Log", to read exactly
like Contract Log and Procurement Log. The empty state, the search box and the
type/severity/status pills are unchanged.

**The overview and the log cannot disagree.** `IssueLogSummary.fromItems`
counts Open / In Progress / Resolved from the same statuses `IssueLogRow`
classifies, so the Issues Overview card and the table report the same project;
the search box now asks `IssueLogRow.matches` instead of keeping a second copy of
the searchable fields. Edit and delete moved to the state
(`_handleDeleteIssue`) so the card stays stateless.

**Contracting and procurement were already done — Tasks 5 and 6.** The Contract
Log (`planning_contracting_screen.dart`) and the Procurement Log
(`procurement_items_list_view.dart`, shared by the FEP and planning pages) were
built in those tasks with the `#` column first and the expand button, so the
vocabulary and the numbering already hold there.

**Deviation — the sweep found nothing else that is a log.** The remaining tables
in those three screens are not entity tables and were deliberately left alone:
Vendor Comparison Sheet, Vendor Evaluation scores and ranking, payment
milestones, the objectives grid and the editable Contract Budget in Contracting;
the vendor list in FEP procurement. Two more FEP procurement tables
(`Procurement Strategies`, `Procurement Needs`) are part of the sections behind
`_showLegacyProcurementSections = false` and are unreachable while that flag is
false — they should be numbered or deleted as part of the "should this come
back?" decision, not before it.

**The export prints the log now (asked for after Task 7).** The export carried
only Project Info and Notes, so the owner's "the table didn't show anything"
applied here too. It now appends `PdfSection.table('Issue Log', …)` — exactly
what the risk export got in Task 3 — built from
`issueLogExportHeaders()` / `issueLogExportRows(items)` in `issue_log.dart`:
the same column set and the same numbered rows the on-screen table draws, so the
downloaded table cannot disagree with the one on screen. Three tests in
`issue_log_test.dart` (13 in the file now) pin the header/row contract: the
headers are the log columns in order, every row lines up with them, and the rows
are numbered from 1.

**Not changed.** The Issues by Milestone card is a card list, not a table, and
stays as it is.

---

### Task 8: Interface Management — the Status Dashboard leads — DONE

**Files:**
- Modified: `lib/screens/interface_management_screen.dart`
  (`_ImTab.dashboard` moved to the head of the enum, and the screen opens on it)
- Modified: `test/screens/interface_management_tabs_test.dart` (the tab list in
  bar order, and an explicit register-tab selection in the two register tests)
- Modified: `test/screens/interface_register_add_test.dart` (the in-flight
  session's own test file — one extra tap, and its dialog-size assertions now
  measure the dialog card instead of the route wrapper)

*"the adjustment that we're trying to make is to put the, I think, status
dashboard at the front."* The Status Dashboard is now the **first tab in the
strip and the tab the screen opens on**, so the overview is the first thing on
the page; Interface Register, Architecture, RACI & Governance and the rest keep
their order behind it. The page title, notes, plan card and metrics row above the
strip are unchanged, so the register is still one click away and its own header
(and Add Interface button) only appear when that tab is selected.

**Landed on top of the in-flight register-add work** (the owner chose "do it
fully now" over waiting for that work to be committed). Its three tests landed on
the register tab implicitly, because it used to be the default, so they now
select it explicitly in their `pumpScreen` helper — no assertion changed. That
kept the file's own coverage while the default moved, and nothing in the dialog
or register code was touched.

**Repaired — the in-flight dialog-size test could never pass.** The uncommitted
session had added `the Add Interface modal stays a sensible size on desktop`,
asserting `tester.getSize(find.byType(AlertDialog)).width <= 660`. That reads the
*route*'s first render box — the dialog route's padding/align — which fills the
window (measured **2000** on a 2000-wide window) however narrow the card is; the
card is the first `Material` inside it (measured **624 × 808**, which satisfies
every assertion the test makes). So the test was red before this task and for a
reason unrelated to the tab change; it now measures the card. The dialog fix it
was written for (`ConstrainedBox(maxWidth: 640)` in the dialog's content) works
and was left untouched.

**Not done, deliberately.** The owner could not follow the governance/RACI view
but said so explicitly wanting *not* to spend the session on it ("it's not as
hard for me to find a way to deal with that … I don't want to spend, 'cause it's
taken us a while to get through"). Only the overview reorder landed.

---

### Task 9: Kanban Configuration — a compact add-column control — DONE

**Files:**
- Modified: `lib/screens/agile_kanban_config_screen.dart`
- Modified: `lib/screens/agile_kanban_board_screen.dart`
  (`KanbanBoardPanel(boardHeight:)`, default unchanged)
- Modified: `test/screens/agile_kanban_config_test.dart`

*"can the button be like something little"* / *"I feel like it's covering the
entire page"* — the add-column control is currently large enough to push the rest
of the configuration below the fold. Keep the section's own description visible.

**The control is little and it no longer sinks.** The full-width labelled
`Add column` `OutlinedButton` sat *after* the last column row, so every column
added pushed it further down and you had to scroll back for it. It is now a
compact `IconButton` (`Icons.add`, tooltip `Add column`, `visualDensity:
VisualDensity.compact`) in the **Workflow Columns** section header, beside the
YOURS TO CHANGE / UNSAVED badges — always on screen, never below the fold. The
`kanban-add-column` key is kept, so the existing tests and any future ones drive
the same control. `Save workflow` keeps its footer place, and the section's own
description stays immediately under the header, where the review wanted it.

**The board is a preview now, not the page.** The recording reads both ways (the
"button" that is "covering the entire page", and "you have to scroll all the way
down there to the actual [board]"), so both halves were done. The embedded live
board used to render its desktop board at a fixed **640 px** inside the
configuration page; `KanbanBoardPanel` now takes a `boardHeight` (default
`kKanbanBoardHeight` = 640, so the Kanban Board screen and its header test are
unchanged) and the configuration page passes `kKanbanBoardPreviewHeight` = 320.
Each column still scrolls inside that box, so it stays usable. The section header
carries an **Open full board** action (the existing
`AgileKanbanBoardScreen.open` route), so the working board is one click away
instead of a long scroll, and the description says the panel is a preview.

---

### Follow-up (asked for after the plan was written): the RACI & Governance tab — DONE

**Why it is not one of Tasks 1–9:** the owner could not follow this tab, but
explicitly did not want to spend the recording on it ("it's not as hard for me to
find a way to deal with that … I don't want to spend, 'cause it's taken us a
while to get through"), so Task 8 left it alone. It was picked up separately.

**Files:**
- Added: `lib/models/interface_raci.dart` (the derivation, the coverage counts
  and the governance rows)
- Modified: `lib/screens/interface_management_screen.dart` (the RACI & Governance
  tab)
- Test: `test/models/interface_raci_test.dart` (new, 17 tests)

**What was actually wrong.** The matrix looked auto-filled and the owner's
question was *"this information you detailed got filled up from where?"*. It was
a derivation the screen never explained: **R was the interface's `partyA`, A was
its `owner`, C was its `partyB`, and I was the literal string `'Team'` — on every
row.** An invented value plus a silent mapping is why the tab read as noise.
`InterfaceEntry` has no responsible/accountable/consulted/informed fields, so
nothing can be "assigned" to the matrix; it can only be read from the interface.

**The tab now states its own provenance.** Above the matrix:

- A **provenance card** — "every row is one interface from the Interface
  Register, and every letter is read from that interface's own fields; nothing
  is typed into the matrix directly" — with **Open the register**, which selects
  the register tab (`onOpenRegister` on the section), so the source is one click
  away rather than a guess.
- A **legend** for R/A/C/I that names the field behind each letter.
- **Coverage chips** on the same rows the table draws: `n interfaces`,
  `n with no accountable owner`, `n with no cadence`, `n never synced`, the
  last three highlighted when non-zero.

**The matrix itself.** The header carries the letter *over the register field it
is read from* (`R` over `Party A (provider)`, and so on), the rows are numbered
`#` first like every other table, each letter has its own colour (R amber,
A blue, C green, I grey), and **Informed now reads `Not set`** — with the
provenance card saying why — instead of `'Team'`. The interface name is a link
that opens that interface's edit dialog, which is the answer to *"when did you
assign yourself to that?"*: you set it on the interface, and you can get there
from the matrix. A blank cell means the field is blank on the interface.

**Governance is a table too.** The run-on `name | Owner: … | Cadence: …` bullets
became a numbered `#` / Interface / Owner / Cadence / Escalation path / Last sync
table, one row per interface (the bullets hid interfaces that had neither an
owner nor a cadence), and a hole says what is missing — `No owner`, `No cadence`,
`Never synced` — in amber, so a row reads as an action item.

**Checked by rendering, not by eye.** Both pages were rendered in the widget
harness at desktop size (2000×1200) and at a narrow window (1000×900) with
seeded interfaces, which is what the new tab/page tests do. That found one real
bug in this work: the R/A/C/I legend put a plain `Text` in a `Row` inside a
`Wrap`, so the Row laid the label out unbounded and the longest line
(`I — not captured on the register yet`) **overflowed by 80 px** on a narrow
window. The legend line is now short (`legendLine` in `interface_raci.dart`) and
the item is capped (`ConstrainedBox(maxWidth: 340)` + `Flexible`) so it wraps
inside its own item instead. Both pages now render clean at 1000×900, and that
check is a test — all nine Interface Management tabs, and the Kanban
Configuration page with its compact add control, its description and the bounded
board preview.

**Also worth knowing (finding, not fixed):** `ProjectDataModel` already carries a
`raciMatrixRows` list (`{role, framework, discipline, assignments}`) and **nothing
in the app writes or reads it** — it is dormant. If the owner wants a real
Informed field, that list (or a field on `InterfaceEntry`) is where it would go;
today the matrix has nothing to read.

## Verification for the whole plan

```bash
flutter analyze
flutter test test/routing/planning_phase_order_test.dart
flutter test test/routing/execution_plan_dedup_test.dart
flutter test test/screens/agile_screen_navigator_test.dart
flutter test test/models/risk_log_test.dart       # Task 3
flutter test test/models/risk_assessment_signoff_test.dart  # Task 4
flutter test test/models/contract_rfp_cycle_test.dart       # Task 5
flutter test test/models/contract_log_test.dart             # Task 5
flutter test test/models/procurement_log_test.dart          # Task 6
flutter test test/models/issue_log_test.dart                # Task 7
flutter test test/screens/interface_management_tabs_test.dart  # Task 8
flutter test test/screens/interface_register_add_test.dart     # Task 8
flutter test test/screens/agile_kanban_config_test.dart        # Task 9
flutter test test/screens/agile_kanban_board_header_test.dart  # Task 9
flutter test test/models/interface_raci_test.dart       # RACI follow-up
```

The nav tests are the canary: they pin the exact flow order, so any later
reordering or re-adding of a removed duplicate fails loudly instead of silently
drifting back.

## Manual walkthrough before handing back

1. Planning sidebar: no Execution Issue Management / Execution Lessons Learned /
   Execution Stakeholder Identification; the project-wide Issue Management,
   Lessons Learned and Stakeholder Management are still there.
2. Agile project: no Execution Plan, and Next from Agile Map Out skips it.
   Waterfall project: no Agile Delivery flow, and Next from Technology Planning
   goes straight to the Execution Plan. Hybrid/unset: both sections stay.
3. Risk Assessment (Planning) opens on the same table as FEP risks, with the same
   columns and row count, and its export produces the table. The top risks and
   their mitigations are above everything, the 0.6 % allowance is above the risk
   table, and Next refuses to advance until the stakeholder confirmation, the
   review date and the cadence are recorded.
4. Contracting: the log table is the default view; a contract's strategy and cycle
   are set per contract; Negotiation is hidden; **Export PDF** prints the
   Contract Log (header plus numbered rows) after Project Info and Notes.
5. Procurement (FEP): the overview tab is the plan note and the status cards, the
   next tab is the Procurement Log table, and the strategies table, the contract
   scope block, the duplicate item list and "What to procure" are gone;
   **Export PDF** prints the Procurement Log (header plus numbered rows) after
   Project Info and Notes — and the same on Planning Procurement.
6. Issue Management: the table under the overview reads **Issue Log**, its first
   column is `#`, it expands to full screen, the Open / In Progress / Resolved
   cards count the same rows, and **Export PDF** prints that table (header plus
   numbered rows) after Project Info and Notes.
7. Interface Management opens on **Status Dashboard**, which is also the first
   tab in the strip; selecting Interface Register still adds an entry and bumps
   Total Interfaces; the Add Interface modal stays a ~620 px card on a wide
   desktop.
8. Kanban Configuration: the add-column control is a small `+` in the Workflow
   Columns header, the section description is right under it, adding a column
   still appends a row, and the board at the bottom is a ~320 px scrolling
   preview with **Open full board** going to the working board.
9. Interface Management → RACI & Governance: the provenance card says where the
   letters come from and **Open the register** jumps to the register; R/A/C/I
   read Party A / Owner / Party B / `Not set`; tapping an interface name opens
   its dialog; the governance table flags `No owner` / `No cadence` /
   `Never synced` in the rows that have them.

## Not code work (from the same recording)

- Session continues **tomorrow at 2 PM PST**; still to walk: rest of Procurement,
  Schedule, Cost, Scope Tracking, Change Management.
