# Agile Delivery review fixes (Lusaka 26) Implementation Plan

> **For the agent picking this up:** this plan came out of the 2026-09-28 Lusaka 26
> walkthrough. The owner's verbatim asks (with transcription caveats) are in
> `docs/voice_notes/2026-09-28-lusaka-26-agile-planning-walkthrough-transcript.md`.

**Goal:** Make the Planning-phase Agile Delivery flow match what the owner
reviewed — Kanban Configuration under Epics & Features, a real Epic → Feature →
Story → Task backlog with a table view, a "User Story Template" section with
several named templates, a Release Plan driven by epics + milestones, and a
Metrics Planning step that feeds the dashboard instead of duplicating Backlog
Governance.

**Architecture:** No new screens. Every ask lands on an existing section screen
(`lib/screens/agile_*.dart`), its existing service (`EpicFeatureService`,
`AgileService`, `AgileWireframeService`, `KanbanConfigService`), and the existing
nav surfaces that define order (sidebar service, planning-phase nav, the
sidebar widget's hardcoded sub-menu). Data already carries the links we need:
`Feature.epicId`, `AgileTask.epicId`/`AgileTask.featureId`,
`AgileReleasePlan.epicIds`/`featureIds`, and `ProjectDataModel.keyMilestones`.

**Tech stack:** Flutter/Dart, Provider, Firestore via the existing services,
`flutter_test` widget tests, `analysis_options.yaml` lints.

---

## Ordering rule for the whole plan

The owner gave the flow order twice, so **do Task 1 first**: everything else is
ordered relative to it.

Target Agile Delivery order:

```
Agile Delivery Model → Scrum Configuration → Capacity Planning →
Backlog Governance → Agile Team Structure → Epics & Features →
Kanban Configuration → Acceptance Criteria Planning → Sprint Cadence &
Calendar → Release Plan → Metrics Planning → Agile Map Out
```

Two changes versus today: **Kanban Configuration moves after Epics & Features**
(ask 1), and **Metrics Planning moves above Agile Map Out** (ask 9).

> Confirm the Metrics-Planning/Agile-Map-Out swap with the owner before landing it
> — the recording supports "metrics planning goes above … which will come in the
> dashboard", but the sentence is partially garbled.

---

### Task 1: Reorder Kanban Configuration and Metrics Planning in every nav surface

**Files:**
- Modify: `lib/services/sidebar_navigation_service.dart` (~lines 203-224)
- Modify: `lib/utils/planning_phase_navigation.dart` (Agile `PlanningPage` entries, ~lines 150-230)
- Modify: `lib/widgets/initiation_like_sidebar.dart` (known-label list ~255-259; sub-sub menu ~2894-2906)
- Modify: `lib/services/project_route_registry.dart` only if a checkpoint is renamed (none should be)
- Test: `test/screens/agile_screen_navigator_test.dart` (the explicit checkpoint-order `expect`, and the `Step N of 12` strings)

**Step 1: Write the failing test first.** Update the order expectation in
`agile_screen_navigator_test.dart` to the target order above, keeping the same
12 checkpoints:

```dart
expect(steps.map((s) => s.checkpoint).toList(), [
  'agile_delivery_model',
  'agile_scrum_config',
  'agile_capacity_planning',
  'agile_backlog_governance',
  'agile_team_structure',
  'agile_epics_features',
  'agile_kanban_config',
  'agile_acceptance_criteria',
  'agile_sprint_calendar',
  'agile_release_plan',
  'agile_metrics_planning',
  'agile_map_out',
]);
```

**Step 2: Run it and watch it fail.**
Run: `flutter test test/screens/agile_screen_navigator_test.dart`
Expected: FAIL — the actual list still has `agile_kanban_config` before
`agile_epics_features`.

**Step 3: Move the entries.** Move the `SidebarItem(checkpoint: 'agile_kanban_config', …)`
entry in `_sidebarOrder` so it sits directly after `agile_epics_features`, and
move the `agile_metrics_planning` entry so it sits directly before `agile_map_out`.
Mirror the same two moves in the `PlanningPhaseNavigation.pages` list, and in
`initiation_like_sidebar.dart` (both the `_isActiveLabel('Agile Delivery Model - …')`
label list and the `_buildSubSubMenuItem(...)` calls, which must stay in the same
order).

**Step 4: Re-run.** Run: `flutter test test/screens/agile_screen_navigator_test.dart`
Expected: PASS. The `Step N of 12` assertions still pass because the first three
screens are unchanged; if you touch them, update the numbers.

**Step 4b: Move the navigator's range boundary.**
`PlanningPhaseNavigation.agileDeliverySteps` reads
`itemsBetween('agile_delivery_model', 'agile_metrics_planning')`. Once Metrics
Planning sits *before* Agile Map Out, that range clips the last screen off the
on-page navigator (11 steps instead of 12) — change the boundary to
`agile_map_out`, which is now the last Agile Delivery screen.

**Step 5: Sweep for other hardcoded orders.**
Run: `grep -rn "agile_kanban_config" lib test | grep -v "\.g\.dart"`
Expected: hits only in the registry, nav services, and tests — no screen with its
own "next screen" list, no snapshot/`golden` fixture.

**Step 6: Commit.**
```bash
git add lib/services/sidebar_navigation_service.dart lib/utils/planning_phase_navigation.dart lib/widgets/initiation_like_sidebar.dart test/screens/agile_screen_navigator_test.dart
git commit -m "fix(agile): put Kanban Configuration after Epics & Features and Metrics Planning before Agile Map Out"
```

---

### Task 2: Kanban Configuration says what is actually configurable — DONE

**Files:**
- Modified: `lib/screens/agile_kanban_config_screen.dart`
- Modified: `lib/services/kanban_config_service.dart` (`KanbanColumnConfig`,
  `defaultColumns`, `loadColumns`, `saveColumns`, `parseWipLimit`,
  `wipLimitLabel`, `columnIdFor`)
- Modified: `lib/screens/agile_kanban_board_screen.dart` (board reads its
  columns and its fallback through the service)
- Tests: `test/screens/agile_kanban_config_test.dart`,
  `test/services/kanban_config_service_test.dart`

**What landed.** The page is split into *Workflow Columns* (rename, reorder,
WIP limit, add/remove, Save, UNSAVED badge) and *Fixed on Every Kanban Board*
(the lock list: state derived from the column name, drag-to-move, WIP gating,
re-homing on rename/remove, one workflow per project). Columns load from the
saved config (`AgileWireframeService.loadKanbanConfig`), falling back to the
board's own defaults, and save through `KanbanConfigService.saveColumns`.

**Correction to the original step 2.** Do **not** run
`KanbanConfigService.alignStatusesToWorkflow` over the saved column names. It
normalises `Backlog` and `Ready` to `To Do` and then de-duplicates, so saving
the owner's five-column board through it would silently collapse two columns.
The board already re-homes a card whose `workflowState` no longer exists to the
first column, so no extra alignment step is needed for renames or removals.

**One drift fixed on the way.** `agile_kanban_board_screen.dart` carried its
own hardcoded default columns and its own name→id slug. Both now come from
`KanbanConfigService` (`defaultColumns`, `columnIdFor`, `columnsFromConfig`), so
the page and the board cannot disagree about the starting workflow.

---

### Task 3: Backlog table view — Epic → Feature → Story — DONE

**Files:**
- Modified: `lib/screens/agile_stories_backlog_screen.dart` (table is now the
  default view, with a Table / Cards toggle; the card view is untouched)
- Added: `lib/utils/agile_backlog_table.dart` (`AgileBacklogTable.build`,
  `BacklogTableRow`, `featuresWithoutStories`)
- Added: `lib/widgets/agile_backlog_table_view.dart` (`AgileBacklogTableView`)
- Tests: `test/utils/agile_backlog_table_test.dart` (12),
  `test/widgets/agile_backlog_table_view_test.dart` (6)

**What landed.** Columns load through the existing `EpicFeatureService` /
`ExecutionPhaseService` data: Epic | Feature | Story | Priority | Points |
Readiness | Sprint | Release | WBS, ordered epic → feature → backlog order, using
`buildNduTableWithExpand` (wrapped cells + full-screen expand) so it matches the
SSHER/Design tables. Stories with no feature are grouped below in their own
amber section rather than dropped, with the reason ("No feature set" or "Feature
x no longer exists"), and features with no stories are counted off in a notice —
that is the breakdown gap the review found.

**Deviation: no "Type" column.** The plan called for Type (Story/Task).
`AgileTask` has no story/task discriminator — tasks only appear when a story is
pulled into an iteration, which is the second half of ask 3 and is not built
yet. A Type column would print "Story" on every row, so it was left out until
there is something to distinguish.

**Testability deviation.** The original step 1 wanted a widget test that pumps
`AgileStoriesBacklogScreen` with fixture epics/features/stories. That cannot
work: the screen's Firestore loads never complete under `flutter test` (no
platform handler), so the page sits on its spinner forever and nothing renders.
The table was therefore split into a presentational `AgileBacklogTableView`
(rows in, table out) with its own widget tests, and the row construction into a
pure builder with its own unit tests. **Follow-up worth doing:** `_loadData` has
no timeout, so a hung store leaves this page loading indefinitely — the same
shape of bug would be a blank screen in production.

---

### Task 4: Enforce Story → Feature → Epic, and let a Feature spawn its stories — DONE

**Files:**
- Added: `lib/utils/agile_story_linkage.dart` (`AgileStoryLinkage.link`,
  `newStoryFor`, `isLinked`, `featureFor`, `countUnlinked`, `optionLabels`)
- Modified: `lib/screens/agile_stories_backlog_screen.dart` (feature picker on
  every story card; stories created through the rule; unlinked count on save)
- Modified: `lib/screens/agile_epics_features_screen.dart` (an "Add story"
  action on each feature row)
- Tests: `test/utils/agile_story_linkage_test.dart` (12)

**Correction: the plan pointed at the wrong service.** It said to derive `epicId`
in `AgileService.createStory`. `AgileService` is the *legacy* `agile_stories`
store — its own doc comment says "Prefer `AgileTask` persisted via
`ExecutionPhaseService` for canonical backlog/execution/schedule integration" —
and the backlog screen never touches it.

The rule now lives in one pure place, `AgileStoryLinkage`, and every path uses
it: `newStoryFor` gives a story its feature **and that feature's epic**, ordered
by highest-order-plus-one rather than a count (so deleting a story cannot make
the next one collide); `link` re-parents an existing story and replaces a stale
epic. The card view gained a **Feature** picker that cannot be cleared and shows
"Not under any feature" with the fix list for anything unlinked, and saving now
reports "· N still have no feature".

**Hazard found while wiring "Add story" to a feature.**
`ExecutionPhaseService.saveAgileTasks` replaces the **whole** `agileTasks`
array, so any caller holding a subset of stories wipes the rest. The new action
loads the existing list first and saves it back with the new story appended.

Audit of the other callers, so nobody has to redo it: `agile_stories_backlog`
and `agile_development_iterations` hold the full list they loaded;
`agile_iteration_table_widget` and `wbs_agile_sync_service` load-then-append (the
WBS one even documents the hazard); `agile_kanban_board_screen` saves the full
list it loaded. `agile_task_board_screen.dart` saves whatever `initialTasks` it
was handed, but nothing in `lib/` constructs `AgileTaskBoardScreen`, so that path
is dead rather than dangerous.

**Legacy tolerance (plan step 5).** Stories with no feature still load; they are
flagged in the card picker, counted on save and grouped in the Task 3 table — no
migration, no crash. Covered by the `link checks` group in the new test file.

---

### Task 5: Acceptance Criteria above Definition of Done, wired to Backlog Governance — DONE

**Files:**
- Added: `lib/utils/agile_gate_definitions.dart` (`AgileGateStage`,
  `AgileGateDefinition`, `AgileGateDefinitions.ready/done/forStage`)
- Added: `lib/widgets/agile_gate_panel.dart` (`AgileGatePanel`)
- Modified: `lib/screens/agile_acceptance_criteria_screen.dart` (loads
  governance, renders the gate, exports it)
- Modified: `lib/screens/agile_backlog_governance_screen.dart` (see the bug
  below; its seed lists now come from the util)
- Tests: `test/utils/agile_gate_definitions_test.dart` (12),
  `test/widgets/agile_gate_panel_test.dart` (7)

**What landed.** The page now renders the gate in one ordered panel: step 1
Definition of Ready (read-only, `FROM GOVERNANCE`, with an "Open Backlog
Governance" link), step 2 Acceptance Criteria (`THIS PAGE`, badge + criteria
count, containing the whole existing editor), step 3 Definition of Done
(read-only). The order comes from `AgileGateDefinitions.order`, and the widget
test asserts it **by on-screen position** — criteria above done — not by build
order. The PDF export carries the same three stages.

**Bug found and fixed on the way.** Definition of Ready / Done have two forms in
Backlog Governance — a checklist and a prose definition — and the prose form was
never saved: `_controllers` was only seeded for the five `_fields` keys, and
`_performSave` only wrote those keys. So a definition typed in checklist-off mode
was dropped on reload, and there was nothing for the Acceptance Criteria page to
echo. The prose keys now get controllers, are loaded back, and are written on
save (guarded so checklist mode cannot blank a stored definition).

**Known pre-existing red test (not from this task).**
`test/widgets/acceptance_criteria_template_dialog_test.dart` fails 5/5 on
`staging`: it looks for `find.widgetWithText(FilledButton, 'Create template')`
while the dialog builds `FilledButton.icon`, and `find.byType` does not match
subclasses. Neither the test nor the dialog is touched by this work — worth a
one-line finder fix in its own commit.

---

### Task 6: Rename the template section to "User Story Template", support N named templates — DONE

**Files:**
- Modified: `lib/models/acceptance_criteria.dart` (`AcceptanceCriteriaTemplate.isDefault`)
- Added: `lib/utils/agile_story_template.dart` (`AgileStoryTemplate`)
- Modified: `lib/screens/agile_acceptance_criteria_screen.dart` (section heading,
  default marking, `Advanced` disclosure)
- Modified: `lib/widgets/acceptance_criteria_template_dialog.dart` ("use as the
  default template" choice)
- Modified: `lib/screens/agile_stories_backlog_screen.dart` and
  `lib/screens/agile_epics_features_screen.dart` (a new story starts from the
  default template)
- Tests: `test/utils/agile_story_template_test.dart` (13),
  `test/screens/agile_acceptance_criteria_test.dart` (2)

**What landed.** The template block is titled **User Story Template** and lists
named templates. `AcceptanceCriteriaTemplate` gained `isDefault`; the rules live
in one pure place, `AgileStoryTemplate` (`sectionTitle`, `userStoryTemplates`,
`defaultTemplate`, `markDefault`, `ensureDefault`, `acceptanceCriteriaFor`,
`newStoryFor`). Exactly one template is the default: each list tile carries a
`Default` badge and a star toggle, the create-template modal has a "Use as the
default template" choice, and a config saved before the flag existed — or one
whose default was deleted — is backfilled on load. A newly created story, from
the backlog or from Epics & Features' "Add story", starts with the default
template's criteria as a `• ` bullet list (the app's existing list format), and
still goes through `AgileStoryLinkage.newStoryFor` so it inherits the feature and
that feature's epic.

**Section body kept.** The format selector (Checklist / Given-When-Then /
Scenario) and the Task 5 gate (Definition of Ready → Acceptance Criteria →
Definition of Done) stay inside the section; the review asked for given/when/then
to stay in the template, and for the two outer gates not to be restated here.

**Where "Advanced" came from.** The clutter the owner pointed at ("all those
things, you know, at the top … they can be hidden, they should be hidden") is the
ten-chip **work item type** row. It now sits behind a collapsed `Advanced`
disclosure instead of being deleted — the filter still exists, it just is not the
first thing on the page. Nothing was removed.

**Why the page is still called "Acceptance Criteria Planning".** That string is
the nav checkpoint, not the section: renaming it would move the step in
`sidebar_navigation_service.dart` / `planning_phase_navigation.dart` and break
navigation. The rename is scoped to the template section, which is what the
owner pointed at.

**Pre-existing red test in the touched file, fixed here.**
`test/screens/agile_acceptance_criteria_add_template_test.dart` could not tap its
own "Add" button: the Task 5 gate panel put that button below the 800×600 test
window (measured at y≈923 on `staging`, before this task), so `tester.tap`
warned and missed. The test now calls `ensureVisible` first and both cases pass.
This is the gate panel's height, not the rename — verified against `staging`.

**Still red, untouched, unrelated.**
`test/widgets/acceptance_criteria_template_dialog_test.dart` (5 failures) still
looks for `find.widgetWithText(FilledButton, 'Create template')` while the dialog
builds `FilledButton.icon`, and `find.byType` does not match subclasses. Task 6's
dialog change (the default checkbox) does not add to or remove from those — the
count is 5 before and after. One-line finder fix, its own commit.

---

### Task 7: Release Plan shows epics + milestones and ties them automatically — DONE

**Files:**
- Added: `lib/utils/agile_release_scope.dart` (`AgileReleaseScope`,
  `ReleasePlanTableRow`, `EpicMilestoneRow`)
- Added: `lib/widgets/agile_release_plan_table.dart` (`AgileReleasePlanTableView`)
- Modified: `lib/screens/agile_release_plan_screen.dart` (loads epics/features/
  milestones/work packages, table + cards toggle, blank new plans, auto
  milestones on the cards and in the dialog, export)
- Tests: `test/utils/agile_release_scope_test.dart` (10),
  `test/widgets/agile_release_plan_table_test.dart` (3)

**What landed.** The page now shows what the project already has — every epic and
`ProjectDataModel.keyMilestones` — in a "Project epics & milestones" table, then
a "Release plan" table with one row per release and epic, and a notice naming any
milestone no release has claimed. A release's milestones are **resolved, never
picked**: `milestoneIdsForEpic` reads `AgileTask.milestoneIds` from the stories
under the epic, and — the owner's "reflected automatically with the associated
[WBS] item" — `WorkPackage.milestoneIds` for packages sitting on the epic's
`wbsId`. The editor dialog shows the same list read-only for the current scope,
the cards carry the same auto banner, and a new plan is created blank instead of
pre-named `Release N`.

**Deviation: the test is on the pure rules, not the screen.** The plan wanted a
widget test that pumps `AgileReleasePlanScreen` with fixture epics/milestones.
That cannot work for the same reason as Task 3: the screen's Firestore loads
never complete under `flutter test`, so it stays on its spinner. The rules live
in `AgileReleaseScope` with unit tests, and the table is a presentational widget
with its own tests; the screen only wires them.

**Defensive read added.** The screen reads milestones/work packages from
`ProjectDataHelper.getData(context)`, which needs `Provider<ProjectDataProvider>`
above it. That read is now guarded like `_projectId`, so a host without the
provider degrades to "no milestones" instead of throwing
`ProviderNotFoundException` — which is exactly what the existing
`agile_release_plan_dialog_test.dart` would otherwise have hit.

**Milestone→epic linkage is derived, so it is only as good as the data.** A
project whose stories carry no `milestoneIds` and whose epics carry no `wbsId`
shows every milestone under "not tied to a release yet" rather than inventing a
tie. That is the honest reading, but it means Task 11's story/task work (and the
FEP milestone pickers on stories) is what makes this section fill up.

---

### Task 8: De-duplicate Metrics Planning and Backlog Governance — DONE (owner said keep both)

**Files:**
- Modified: `lib/services/agile_wireframe_service.dart` (sub-map key constants +
  the two payload builders)
- Modified: `lib/screens/agile_metrics_planning_screen.dart`,
  `lib/screens/agile_backlog_governance_screen.dart` (use the builders)
- Test: `test/services/agile_wireframe_config_keys_test.dart` (5)

**The owner's verdict: keep them as they are.** Asked directly (the recording
gave no answer), the answer was to keep both screens and their fields. So nothing
was merged, moved, or deleted, and the flow keeps the Metrics Planning step.

**Correction to the plan's premise.** The plan said the two screens "read the
same Firestore doc, so a field saved by one and edited by the other will silently
fight". They do share the doc, but not a key: Metrics Planning writes
`metricsConfig`, Backlog Governance writes `backlogGovernance`, and every save
uses `SetOptions(merge: true)`. There was no collision to fix.

**What settled instead.** Both screens' payloads are now built by
`AgileWireframeService.metricsConfigData` / `backlogGovernanceData`, the keys are
named constants, and a test asserts the two payloads share no key at all — plus
that the gate keys the Acceptance Criteria page echoes (Task 5) are still in the
governance payload. That is the guard the plan actually wanted; if someone later
points both screens at one key, the test fails instead of a screen quietly
blanking the other.

Field ownership, for the record:
- **Backlog Governance** — prioritization framework, refinement cadence,
  estimation framework, backlog ownership, grooming rules; Definition of Ready
  and Done (checklist or prose); working agreements.
- **Metrics Planning** — the tracked metric set and its notes (Task 9 makes those
  drive the dashboard).

**Deviation: no Firestore round trip.** The plan asked for "a test that saves via
one path and reads via the other". That needs a fake Firestore, and the project
has no `fake_cloud_firestore` (or `mockito`) dependency — adding one would pull in
new packages for a single test. The key-disjointness check above is the
achievable proxy and is noted as such in the test file.

---

### Task 9: Metrics drive the dashboard; stop asking the user to pick metrics — DONE

**Files:**
- Added: `lib/utils/agile_metrics_catalog.dart` (`AgileMetric`,
  `AgileMetricsCatalog`, `defaultTrackedKeys`, `trackedMetrics`,
  `usesDefaultTrackedSet`)
- Added: `lib/widgets/agile_tracked_metrics_strip.dart`
  (`AgileTrackedMetricsStrip`)
- Modified: `lib/screens/agile_metrics_planning_screen.dart` (the metric list now
  comes from the catalog; the default tracked set is pre-selected)
- Modified: `lib/screens/agile_dashboard_screen.dart` (loads the metrics config,
  renders the tracked strip, and tags the cards that report a tracked metric)
- Tests: `test/utils/agile_metrics_catalog_test.dart` (7),
  `test/widgets/agile_tracked_metrics_strip_test.dart` (3)

**What landed.** The 16-metric list moved out of Metrics Planning into
`AgileMetricsCatalog`, so it is one list rather than two that drift. A project
that has never chosen now gets the default tracked set — velocity, sprint
predictability, delivery confidence, and the business metrics, which are labelled
`optional` — instead of an empty selection ("just have the metrics available …
and nobody's choosing"). The dashboard reads `metricsConfig` through
`AgileWireframeService.loadMetricsConfig`, renders a **Tracked metrics** strip
with one chip per metric, and says out loud when it is only showing the defaults
instead of passing them off as the user's choice.

**Dashboard tile audit (the "does not look like it's driving an output" ask).**
Each metric card now carries the catalog key it reports: Velocity → `velocity`,
Stories Completed → `throughput`, and those show a small tracked marker. Active
Sprint and Team Capacity carry no key because no planning metric defines them —
they are sprint context, which the owner explicitly allowed to stay ("it's still
okay to have it here"). Nothing was removed.

**`agile_metrics_screen.dart` is not a third duplicate.** It is the
Execution-phase metrics detail page (velocity chart, predictability gauge,
lead/cycle time, defect trend, capacity), reachable from the Agile Project Hub
and not part of the Agile Delivery planning flow, and it reads its own
`execution_phase_entries` data. Left alone; the planning set drives the dashboard.

**Deviation: the test is on the catalog and the strip, not the screen.** Same
reason as Tasks 3 and 7 — the dashboard's loads do not complete under
`flutter test`, so the rule that decides the tracked set is tested pure, and the
strip is a presentational widget with its own tests.

---

### Task 10: Capacity Planning is editable and cadence-driven

**Files:**
- Modify: `lib/screens/agile_capacity_planning_screen.dart` (849 lines)
- Read: `lib/services/agile_wireframe_service.dart` (`loadCapacityPlanning`/`saveCapacityPlanning` ~267-295) and `AgileDeliveryModelScreen`'s saved cadence for the sprint length (the two-week model)

**Step 1:** Make the planning-stage values editable and persist them on change
(debounced save, matching the pattern in `agile_stories_backlog_screen.dart`'s
`_saveDebounce`), and derive the per-sprint capacity from the saved delivery
model cadence rather than a hardcoded two weeks.

**Step 2:** Test: change sprint length in the delivery model → capacity planning
recomputes. Commit.

---

### Task 11: Work through the rest of the review

Remaining asks that are small and independent — do them as one commit each:

1. Feature add/edit dialog fields: title, description, priority, parent epic
   (ask 12) — `lib/screens/agile_epics_features_screen.dart`.
2. Feature list view (all features, all epics) in Epics & Features — same file;
   the current card-only grid is the "not very efficient" complaint.
3. WBS shows one more level (epic → feature → story) — `wbs/screens/wbs_module_screen.dart`
   plus whatever `EpicFeatureService` view it renders.
4. Backlog drag-to-prioritize + search across epic/feature/story, and the
   pull-into-Kanban action — `lib/screens/agile_stories_backlog_screen.dart`,
   `lib/screens/agile_kanban_config_screen.dart`.
5. Confirm the Kanban board is still reachable from the Execution phase (ask 1's
   second half) and fix the phase wiring if it is not.

> Ordering places that look plausible but do **not** need editing:
> `initiation_like_sidebar.dart`'s `agileWireframeCheckpoints` list (a `contains`
> membership check, so order is inert) and `project_route_registry.dart` (a
> checkpoint → screen map, not an order).

---

## Verification for the whole plan

Run after each commit, and once at the end:

```bash
flutter analyze
flutter test test/screens/agile_screen_navigator_test.dart
flutter test test/screens/agile_stories_backlog_test.dart
flutter test test/screens/agile_release_plan_test.dart
flutter test test/screens/agile_dashboard_test.dart
```

The nav regression test is the canary: it asserts the exact 12-step order, so any
later reordering of the Agile flow fails loudly instead of silently drifting.

## Manual walkthrough before handing back

1. Agile Delivery Model → … → Epics & Features → Kanban Configuration order, both
   in the sidebar and by Back/Next.
2. Create epic → feature → story; confirm the story cannot exist without a feature
   and appears in the backlog table with its epic and feature.
3. Open the Kanban board from Execution and confirm the story can be pulled in.
4. Release Plan shows the epics + milestones with no manual milestone picking.
5. Acceptance Criteria template reads Ready → Acceptance Criteria → Done, and the
   template section is named "User Story Template".

## Not code work (from the same recording)

- Continue the review session tomorrow; the organiser moves that invitation to
  **2 PM PST**.
