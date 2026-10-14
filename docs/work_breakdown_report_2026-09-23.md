# Work Breakdown Report — NDU Project

**Date:** 2026-09-23
**Branch:** `staging` · 34 modified files, ~4,000 lines added / ~2,700 removed, plus 30+ new files
**Review source:** *Lusaka 25 (copy)* voice-note walkthrough, 2026-09-17 (`docs/voice_notes/2026-09-17-lusaka-25-copy-planning-walkthrough-transcript.md`)
**Data flow direction:** everything below traces changes **from the WBS (bottom of the planning chain) upwards** through Schedule → Cost Estimate → Variance/Project Controls, then the cross-cutting systems that carry them.

---

## Reading guide — the planning chain this report follows

```
WBS (work breakdown, packages)
  └→ Integrated Work Package Service (EWP → Procurement → Execution chains)
      └→ Schedule (Builder / Gantt / List View)  ← planning sync
          └→ Cost Estimate (Builder / dashboard cards / pulls)
              └→ Variance & Project Controls (baseline vs actual)
                  └→ Cross-cutting: shared model, gates, tables, sidebar, tests
```

---

## 1. Work Breakdown Structure layer (the base)

### 1.1 Package naming fixed at the single source — `lib/services/integrated_work_package_service.dart`

**Problem:** a schedule row used to read *"engineering Ewp: 1.1 Authentication & Security Engineering Engineering Work Package"* — classification prefixed in raw camelCase while the title already stated its own type, and the leaf title's last word stuttered into the appended type ("…Engineering **Engineering** Work Package").

**Change:** the service is now the one place that decides what a package is called on screen:

| New member | Purpose |
|---|---|
| `packageTypeLabel()` | Human-readable classification names (EWP → "Engineering Work Package", etc.) |
| `packageTypeShortLabel()` | Short form ("EWP", "CWP") used only when a title says nothing about its type |
| `packageActivityName()` | The display name: title stands as-is when it already names its type; otherwise a short prefix (`"EWP · …"`) |
| `packageTitleWithType()` | Appends a type to a leaf title **without stuttering** the join — shared word kept once |
| `collapseRepeatedWords()` | Repairs stored titles that already carry the old doubled words |

All three chain-generation call sites (EWP, Procurement, Execution titles) now route through `packageTitleWithType()` instead of naive string concatenation.

**Upward impact:** every consumer of package titles — Schedule activities, planning sync — inherits the fix automatically. Verified by `test/services/work_package_activity_name_test.dart`.

### 1.2 WBS module screen — `lib/wbs/screens/wbs_module_screen.dart`

- Header stack (Section Navigator, node-count indicator, Cross-Section Sync card) moved into a **`ScrollableSectionHeader`** — a height-capped, scrollable host that self-collapses so the tab content always keeps its share of the page.
- Section tabs extracted to a single `_sectionTabs` list shared by the navigator and the collapsed summary bar.

---

## 2. Schedule layer (consumes the WBS)

### 2.1 Builder screen — `lib/schedule/screens/builder_screen.dart` (−2,100 lines net)

The biggest single change in the session: a **de-clutter of the Builder page** and a rename fix.

**Removed from the Builder page** (moved to where they belong):
- `EstimateBasisCard` and `ScheduleReadinessRules` (pre-CWP gate checklist) cards
- The "Schedule Level Convention" card and its `_TreasuryLevelLegend` (L0–L8 legend)
- `_TimelineVisualization` (Gantt preview) — columnar/timeline views live on the List View and Gantt tabs, not here
- `_ActivityScheduleTable` (sample activity table) and its footer note
- `_formatPackageName()` — the camelCase-prefixing formatter that produced the doubled names; replaced with `IntegratedWorkPackageService.packageActivityName()`

**Guidance reworded:** the project date-range hint now points users to the row editor: *"To date an individual activity, tap its row in the Activity Tree and pick its start and finish."*

### 2.2 Schedule module screen — `lib/schedule/screens/schedule_module_screen.dart`

- Header stack (navigator, context banner, resync button, purchase-pull card) wrapped in `ScrollableSectionHeader` — same self-collapsing treatment as WBS.
- The context banner ("Project · WBS nodes · Cost Estimate total · Planning Milestones synced · items synced"), Resync-from-Planning button, and scheduled-purchase pull card are preserved inside the scrollable host.
- Tabs extracted to `_sectionTabs` (Builder / Gantt / List View).

### 2.3 Package rows flowing in — `lib/services/planning_sync_service.dart`

Planning-sync activity names now use `packageActivityName()`, so rows synced from Planning into the Schedule carry the corrected titles (§1.1).

**Verified by:** `test/schedule/schedule_builder_removed_sections_test.dart`, `test/schedule/schedule_module_header_scroll_test.dart`, `test/routing/planning_phase_order_test.dart`.

---

## 3. Cost Estimate layer (consumes the Schedule and Planning)

### 3.1 Two new pull cards — Planning data reaching the estimate

The owner's Lusaka-25 ask was explicit: *"quality costs must reach the cost estimate"* and *"SSHER … you can have them on the table and say cost items and then estimated costs."* Both are now wired, **code-level, no AI**:

**`pullQualityCostLines()`** + `_QualityCostCard` (dashboard section 2f)
- Source: Cost of Quality entries (prevention / appraisal / internal & external failure) priced on the Quality tab.
- Lands as `CostCategory.quality` lines, sub-category `Quality — <category>`, basis reference "Cost of Quality entry …".
- **Idempotent** — same description + total (±0.005) is never duplicated.

**`pullSsherCostLines()`** + `_SsherCostCard` (dashboard section 2e)
- Source: SSHER items ticked **"requires a purchase"** with an assessor-estimated amount (new `requiresPurchase` / `estimatedCost` fields on the add-item dialog, §4.2).
- Lands as `CostCategory.ssher` lines, unit "purchase", same idempotency rule.
- Items ticked but **not yet priced** are surfaced ("needs a price") rather than silently dropped.

Both return typed pull results (`QualityCostPullResult` / `SsherCostPullResult`) with `pulled / alreadyInEstimate / addedTotal`, and both recompute totals and persist via `ComputeUtils.computeTotals()` + `_saveToStorage()`. Selection/summing logic lives in pure, testable utils: `quality_cost_lines.dart`, `ssher_cost_lines.dart`.

### 3.2 Module screen — `lib/cost_estimate/screens/cost_estimate_module_screen.dart` (+600)

- New **SSHER Costs** and **Cost of Quality** dashboard cards (above), with test seams (`ssherEntriesSourceOverride`, `costOfQualitySourceOverride`) so widget tests can inject data.
- Header stack wrapped in `ScrollableSectionHeader`; `_sectionTabs` extracted (11 tabs: Dashboard → Baseline → Variance).

### 3.3 Technology roll-up — `lib/utils/technology_cost_rollup.dart` (new) + `planning_technology_screen.dart`

The owner read **"270"** where the table said **"150/month"** and asked for *"a total per table, then a subtotal for the section, then the grand total across the project duration … and it should land as one line in the Cost Estimate."* Two real defects fixed:

1. **Wrong number** — the old parser took the *first* number, so `"3 licences @ $150/month"` parsed as **3**. `parseCostAmount()` now prefers a currency-symbol-adjacent number, else the **largest** number (correct for `qty @ price` forms).
2. **Not a total** — the card showed only one-time spend under "Total Technology Budget". The new `TechnologyCostRollup` exposes one-time, recurring (per-month / per-year), a genuine `grandTotal` over the project's months, and `totalsByTable()`, with `projectMonthsBetween()` deriving duration from milestone dates (any part of a month is billed) and a stated `defaultProjectMonths = 12` fallback.

### 3.4 Variance screen — `lib/cost_estimate/screens/variance_screen.dart`

Line descriptions are normalised with the new `costDescriptorForDisplay()` so the doubled-dash artifacts the owner flagged ("remove the double dashes") can't survive on the variance surface either.

### 3.5 Cost descriptor text — `lib/cost_estimate/utils/cost_descriptor_text.dart` (new)

Single normalisation point for cost descriptor text (doubled-dash cleanup), shared by the Builder line row and the Variance screen.

---

## 4. Sections feeding the chain (Planning / FEP / SSHER / Quality)

### 4.1 Quality Management — `lib/screens/quality_management_screen.dart` (+1,085)

- **Cost of Quality model ported and made live.** `ProjectDataModel.costOfQualityData` (new field, §5) carries the four CoQ categories; `lib/models/cost_of_quality.dart` and `lib/services/cost_of_quality_service.dart` were removed from `analysis_options.yaml`'s exclude list — they had been excluded precisely because the model field they depend on never crossed over from `origin/comments`, which is why CoQ capture existed but was inert.
- New `_QualityTab` enum with a **`_QualityGateNotice`** that names which tabs are still unopened — the section-flow gate *teaches the flow* instead of just refusing.
- `_QualityConsiderHint` — a shared "consider these" list at the top of every quality add/edit dialog so all pop-ups suggest the same shape of thing.

### 4.2 SSHER — `lib/screens/ssher_stacked_screen.dart` (+264), `ssher_add_safety_item_dialog.dart`

- **Table view is now the default** (`_SsherViewMode { table, cards }`), per the review: *"we do need a table view … the table view needs to be the default"* — scrolling wasn't functional once a category held many items. Cards stay one tap away because they carry the mitigation narrative.
- The add-item dialog gains `requiresPurchase` (bool) and `estimatedCost` (string) — the two fields that make the SSHER → Cost Estimate pull (§3.1) possible at all.
- Amounts are thousand-grouped (`12,000`, not `12000`).

### 4.3 Design Planning — `lib/screens/design_planning_screen.dart` (+749)

- Design Specifications get a **read-only table as the default view** (`_SpecViewMode`, `_SpecViewToggle`, `_SpecificationsInlineTable`) — editing stays on the cards, since a table cell is a poor place to write a specification.
- **Architecture Basis made intelligible** (owner: *"model 1, 2, 3 … it is not intelligible"*): new `_ArchitectureModuleExplainer` plain-language note above the module rows, a pop-out read-only table for the modules, and `lib/utils/architecture_module_labels.dart` (new) providing proper module names/explanations.

### 4.4 Stakeholder Management — `lib/screens/stakeholder_management_screen.dart`, three new utils

Per the review's three asks on this screen:

1. **A real person's name** — `lib/utils/stakeholder_review.dart` (new) identifies rows that aren't yet actionable (missing name/organisation/title) so they can't pass unnoticed.
2. **Review pop-up before leaving** — the screen now demands review, putting the work on the user, exactly as requested.
3. **Provenance must be real** — `lib/utils/stakeholder_provenance.dart` (new) proves where a carried row came from (e.g. "carried from preferred solution"), answering *"you can't just pull out random stuff and then that carried-from sentence is just interesting."*

Also: `lib/utils/sidebar_label_match.dart` (new) — the sidebar highlight now follows the user onto Design Planning sub-pages (prefix/alias matching instead of exact equality).

### 4.5 CSV import/export — `lib/utils/csv_import_helper.dart`

New `exportRows()` writes the template's own header row (row-number column included) so an exported table can be edited in a spreadsheet and imported straight back; row numbers are regenerated from position, not trusted from data. Verified by `test/utils/csv_import_helper_export_test.dart`.

---

## 5. Data model & persistence — `lib/models/project_data_model.dart`

- **`costOfQualityData` field added** (type `CostOfQualityData?`) — the one structural change at the model layer. It is the reason the Quality → Cost Estimate pipeline works end-to-end: without it, CoQ capture could not be stored, and the model/service files stayed analyzer-excluded (§4.1).

---

## 6. Project Controls & cross-cutting systems (top of the chain)

### 6.1 Project Controls screen — `lib/project_controls/screens/project_controls_screen.dart`

Header stack wrapped in `ScrollableSectionHeader`; `_sectionTabs` extracted (Dashboard / Scope Tracking / Cost Control / Change Management / Forecasting). This is the top consumer of the chain — baseline vs actual across scope, cost, and change.

### 6.2 Shared section-header widget — `lib/widgets/scrollable_section_header.dart` (new)

The root cause fix behind §1.2, §2.2, §3.2, §6.1: each module screen used to **pin** its header stack (navigator + context banner + status cards) above the tab content; on a short window — or as soon as one card expanded — the pinned stack squeezed the tab content out. The new widget caps the header's height, scrolls it, and collapses itself, so tab content always keeps its share. Applied consistently to **WBS, Schedule, Cost Estimate, and Project Controls**. Verified by `test/widgets/scrollable_section_header_test.dart` and `test/screens/module_section_header_scroll_test.dart`.

### 6.3 Section flow gates — `lib/utils/section_flow_gate.dart` (new)

The owner's rule: *"that design planning needs to be grayed out … take this action for every single section that has more than one tab … if you try to click on it, you should tell them to finish the flow within that section."* One shared gate now enforces sequential tab/section completion across multi-tab sections, with messaging that names what's still unopened (see `_QualityGateNotice`, §4.1). Verified by `test/utils/section_flow_gate_test.dart`, plus gate tests in `test/ai_switch_gates_ai_content_test.dart`.

### 6.4 Table infrastructure — `lib/widgets/launch_data_table.dart`

Launch table gains virtualization support (the perf work in `test/perf/app_table_test.dart` and the rewritten `test/perf/README.md`).

### 6.5 Initiation-like sidebar — `lib/widgets/initiation_like_sidebar.dart`

Sub-page highlighting wired through `sidebar_label_match.dart` (§4.4), so navigation state is correct on every sub-page of the chain.

---

## 7. Traceability matrix — review ask → change → tests

| # | Owner ask (Lusaka 25 copy) | Where it landed | Tests |
|---|---|---|---|
| 1 | "quality is not done … the quality costs must reach the cost estimate" | CoQ model port (§4.1, §5) → `pullQualityCostLines` + Quality card (§3.1–3.2) | `quality_cost_lines_test`, `quality_cost_card_e2e_test`, `quality_cost_of_quality_tab_test` |
| 2 | "what is the cost aspect for these things?" (SSHER purchases) | `requiresPurchase`/`estimatedCost` on the dialog (§4.2) → `pullSsherCostLines` + SSHER card (§3.1–3.2) | `ssher_cost_lines_test`, plus card tests |
| 3 | "a total per table, then a subtotal … then the grand total … one line in the Cost Estimate" (Technology) | `technology_cost_rollup.dart` (§3.3) | `technology_cost_rollup_test` |
| 4 | "we need to have an actual name of the person" + review pop-up | `stakeholder_review.dart` + screen review prompt (§4.4) | `stakeholder_review_test`, `stakeholder_provenance_test` |
| 5 | "where did this group come from?" (provenance) | `stakeholder_provenance.dart` (§4.4) | `stakeholder_provenance_test` |
| 6 | "model 1, 2, 3 … it is not intelligible" (Architecture Basis) | `architecture_module_labels.dart` + explainer + pop-out table (§4.3) | `architecture_module_labels_test` |
| 7 | "remove the double dashes" | `cost_descriptor_text.dart` applied in Builder + Variance (§3.4–3.5) | `cost_descriptor_text_test` |
| 8 | "the table view needs to be the default" (SSHER) | `_SsherViewMode` table-default (§4.2) | `app_table_test`, smoke tests |
| 9 | "every single section that has more than one tab … next must be grayed out" | `section_flow_gate.dart` + `_QualityGateNotice` (§6.3) | `section_flow_gate_test`, `ai_switch_gates_ai_content_test` |
| 10 | "when I am on the sub-pages of design planning, the sidebar highlight does not follow me" | `sidebar_label_match.dart` (§4.4, §6.5) | `sidebar_label_match_test` |
| 11 | Schedule row names reading "engineering Ewp: … Engineering Engineering Work Package" | `packageActivityName`/`packageTitleWithType` at the single source (§1.1) | `work_package_activity_name_test` |
| 12 | Header stack squeezing tab content on module screens | `ScrollableSectionHeader` across WBS / Schedule / CE / PC (§6.2) | `scrollable_section_header_test`, `module_section_header_scroll_test`, `schedule_module_header_scroll_test` |

---

## 8. Quality & verification

**New test files (26):** work-package naming, quality cost lines/card/tab, SSHER cost lines, technology roll-up, cost descriptor text, stakeholder review/provenance, sidebar label match, section flow gate, architecture module labels, CSV export, scrollable section header (widget + module screens), schedule builder removed-sections, planning phase order, launch table virtualization smoke, app table perf.

**Analyzer:** two files (`cost_of_quality.dart`, `cost_of_quality_service.dart`) graduated out of the exclude list into full analysis — the first exclusion removal of its kind in this config.

**No-AI discipline:** the three new Cost Estimate pulls (quality, SSHER, technology roll-up) are explicitly pure selection-and-summing with `aiGenerated: false` — consistent with the repo's stated product rule that cost computation is code-level, never model-generated.

**Known limitation:** the CoQ model port means previously captured CoQ data (if any existed in the excluded build) becomes storable and pullable only from now on; historical projects with no stored CoQ simply show an empty card with a "needs a price"-style guidance state.

---

## 9. Suggested next actions

1. Run the full suite: `flutter test` — 26 new test files landed with the changes.
2. Commit the WIP (34 modified + 30 untracked files are sitting uncommitted on `staging`).
3. Port the remaining excluded model files (`execution_quality_tracking_model.dart` and friends) the same way CoQ was ported, when their features come up.
