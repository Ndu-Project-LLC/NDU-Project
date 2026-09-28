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

### Task 7: Release Plan shows epics + milestones and ties them automatically

**Files:**
- Modify: `lib/screens/agile_release_plan_screen.dart` (1132 lines; `_ReleasePlanEditDialog`, `ReleaseScopePicker`, `_buildSectionHeader`)
- Modify: `lib/models/agile_release_plan.dart` (`epicIds`, `featureIds`)
- Read: `lib/models/project_data_model.dart` (`keyMilestones`, `List<Milestone>`), `lib/services/planning_sync_service.dart` (`importSourceMilestone`, `_resolveMilestoneNamesForTask`), `lib/models/planning_contracting_models.dart` for the milestone shape
- Test: `test/screens/agile_release_plan_test.dart` (new)

**Step 1: Write the failing test** — with two epics and two key milestones in the
project data, the release plan screen renders both epics and both milestones, and
a release whose `epicIds` includes an epic shows that epic's milestone without
the user re-selecting it.

**Step 2:** Implement: read `ProjectDataModel.keyMilestones` (already rendered on
the Project Baseline and Deliverables screens) and the project's epics, show them
in the plan, auto-resolve milestones from the epics' WBS/schedule linkage
(`PlanningSyncService` already tags imported milestones with
`importSourceMilestone`), and start from a blank plan when nothing is saved
("this should start with a blank").

**Step 3:** Add the table view the owner asked for ("I can type view, like the
[table] view") alongside the existing card layout.

**Step 4:** Run the new test plus `flutter analyze lib/screens/agile_release_plan_screen.dart`. Expected: PASS.

**Step 5: Commit.**

---

### Task 8: De-duplicate Metrics Planning and Backlog Governance

**Files:**
- Modify: `lib/screens/agile_metrics_planning_screen.dart` (553 lines)
- Modify: `lib/screens/agile_backlog_governance_screen.dart` (930 lines)
- Read: `lib/services/agile_wireframe_service.dart` (`loadMetricsConfig`/`saveMetricsConfig` ~297-325, `loadBacklogGovernance`/`saveBacklogGovernance`)

**Step 1:** Decide with the owner which of the two keeps each field. The
recording gives no verdict ("I don't know what the difference between this and
the Backlog Governance is"), so ask before deleting anything.

**Step 2:** Whichever way it goes, the persisted keys must agree:
`loadMetricsConfig` and `loadBacklogGovernance` currently read the same Firestore
doc (`agile_wireframe_service._loadDoc`), so a field saved by one and edited by
the other will silently fight. Add a test that saves via one path and reads via
the other.

**Step 3: Commit** — message must say which screen owns what now.

---

### Task 9: Metrics drive the dashboard; stop asking the user to pick metrics

**Files:**
- Modify: `lib/screens/agile_metrics_planning_screen.dart` (metric-selection UI)
- Modify: `lib/screens/agile_dashboard_screen.dart` (1049 lines)
- Read: `lib/screens/agile_metrics_screen.dart` (1117 lines) — check whether this is a third surface that should merge into the dashboard
- Test: `test/screens/agile_dashboard_test.dart` (new)

**Step 1: Write the failing test** — with a saved metrics config, the dashboard
renders a tile per configured metric without any user selection step.

**Step 2:** Pre-select the tracked metric set (velocity, predictability, plus the
existing business metrics as optional) and have the dashboard read them from the
metrics config. The owner's ask: "just have the metrics available. And then the
dashboard is going to reflect those metrics."

**Step 3:** Check the dashboard against the "everything a dashboard should have"
bar — every tile must trace to a metric defined in Metrics Planning. Remove or
relabel anything that does not ("it does not look like it's driving any certain
output").

**Step 4:** Run the test, `flutter analyze`, commit.

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
