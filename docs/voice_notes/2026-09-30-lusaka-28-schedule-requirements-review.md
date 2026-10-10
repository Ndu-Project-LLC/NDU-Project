# Lusaka 28 — Schedule & Requirements Design Review (Implementation Notes)

Source: `assets/assets/images/Lusaka 28.m4a` (transcript in `tool-results/lusaka-28-transcript.txt`).
Recorded feedback and what was implemented.

## 1. Schedule — List View is the default

> "the list view needs to be the default" · "you should be able to open it big and see quite a few line items at the same time"

- `ScheduleModuleScreen` tab order is now **List View → Builder → Gantt**; List View is the tab the module opens on.

## 2. Schedule — inline editing of dates & duration

> "it has to be editable here, where they can put in the duration, they can put in the start date, and the end date here, without having to click edit"

- List View's Duration / Start / Finish cells are now editable inline (`_InlineDurationCell`, `_InlineDateCell`):
  - Duration commits on submit or focus loss; Start/Finish open a date picker and commit immediately.
  - Edits write back through `ScheduleProvider.updateActivity` (persisted).
  - Typing a duration with a start date derives the finish (and vice versa).
  - Sample/demo rows stay read-only.

## 3. Schedule — Gantt must zoom (16-month view)

> "the schedule has to be big enough where it can show like months… could be quarterly, it could be weekly, it could be monthly… if the project is going to be a 16 month project, you want to be able to zoom out"

- `GanttScreen` gained a **Week / Month / Quarter / Year** zoom selector (`_GanttScale`).
- Timeline cells are generated per scale from the earliest activity date; bar placement interpolates from dates, so bars stay accurate at every zoom.

## 4. Schedule — milestones visible on the Gantt

> "those milestones have to be clear… on the schedule… for the Gantt as well"

- FEP milestones already sync into the schedule under "Planning Milestones" (`PlanningSyncService` / `MilestoneScheduleSyncService`); milestone activities now render as **diamonds** on the Gantt with a date tooltip, distinct from work bars.

## 5. Schedule — color coding by goal

> "everything that fits goal one might all be this specific color, anything that fits goal two, goal three… so everything is just yellow, it's not going to be very easy"

- Bars are color-coded by the activity's top-level WBS code (G1 / G2 / …) via a deterministic palette (`_GanttScreenState.colorForGoal`); items without a WBS link keep their domain color. Footnote reports how many goals are color-coded.

## 6. Schedule — date-mismatch warnings

> "there should be some kind of [warning], like, hey, these days don't match. And then people have to discuss and override a date."

- In List View, rows whose finish/start lands after a committed FEP milestone date — and milestone rows that differ from their committed date — carry an amber warning chip with a tooltip explaining the conflict (`_MilestoneMismatchCell`).

## 7. Requirements — tie to WBS elements

> "the requirements is supposed to be tied to a WBS element, so the second level of the WBS… the first column is going to be the WBS element… the second column beside it's going to be like this sub goal"

- Two new columns in the Requirements table: **WBS Goal (Level 1)** and **WBS Elements (Level 2)**:
  - Goal dropdown lists live WBS top-level codes (G1, G2, …) plus "ALL — Entire project".
  - Element multi-select lists the goal's Level-2 children (G2.1, G2.4, …) with a "Select all" option; changing the goal clears stale elements.
- `RequirementItem` model gains `wbsGoalId` + `wbsElementIds` (serialized to Firestore; backward-compatible `fromJson`).
- CSV import/export template includes both columns.
- WBS Goal / WBS Element columns narrow the requirement/comments columns to keep the table bounded.

## 8. Navigation — dashboard placement

> "in planning, I would say that from the usability perspective, that should not be between the cost of schedule. After the schedule, you need to go to cost. So it's definitely in the wrong place there."

- **Integration Dashboard** moved below **Cost Estimate** in the planning sidebar (`InitiationLikeSidebar`) and in `SidebarNavigationService`, so the build flow runs Schedule → Cost Estimate → Integration Dashboard.

## 9. What was NOT needed (already in place)

- Milestones pull into the schedule from Goals & Milestones (sync banner shows "Planning Milestones: n/m synced", plus "Resync from Planning").
- Work packages pull into the schedule from the WBS (sync + WBS packages card).
- The duplicate-row bug ("same content over and over") was already fixed by identity dedupe in `PlanningSyncService` and ID remapping in the legacy screen.

## Follow-ups (deferred / larger scope)

- Drag-and-drop dependency linking in the Builder (or a searchable "link to issue/parent" picker).
- Critical-path roll-up: minimize to see only goals on the Gantt (currently activities sort by date; goal grouping visible via color).
- Project dashboard accessibility from anywhere in the project (persistent activities/dashboard entry point).

## Follow-up (same day): Activity Tree default table view

> "Ensure that the 'Activity Tree' has the default table view as well. The size of the rows should be a small size overall between the rows."

- The Builder's Activity Tree now renders a **compact table by default** (`_ActivityTreeTable`):
  - ~30px rows with 0.5px hairline dividers (the card rows were ~80px each — a 105-activity schedule meant endless scrolling).
  - Columns: expander / Code / Activity / Domain / Duration / Start / Finish / Cost / actions; milestone diamonds and domain dots kept.
  - Tree structure preserved via indentation; summary rows expand/collapse.
  - Tapping a row opens the SAME editor dialog the cards used; cost + delete actions shared.
- A **Table / Cards** toggle keeps the original card tree available for deep-nesting work; title + "n L1 · n total" badge are shared above both views.

## Follow-up (same day): locked Project Risks must stay viewable/scrollable

> "Even though the 'Project Risks' is locked due to the Charter approval, it does not mean that the table should not be scrollable or viewing all the content overall."

**Root cause:** `CharterLockBanner.applyLock` wrapped the whole content column in an `AbsorbPointer`. AbsorbPointer swallows ALL pointer events — including scroll drags — so once the charter was approved the Project Risks page could not scroll vertically, and the wide risk table could not scroll horizontally either. The comment in the code even claimed "the user can still view the data and scroll through it", which the implementation contradicted.

**Fix (`front_end_planning_risks_screen.dart`):** the blanket lock is gone. The charter lock now gates ONLY the edit affordances:
- Notes field is `readOnly` when locked.
- "Regenerate all risks" and "Add Item" buttons are hidden while locked.
- In the risk table, double-click-to-edit and the Edit / Undo / Delete action buttons are disabled (grayed) while locked.
- Search, scrolling (vertical page + horizontal table), "View more" cell expanders, and the risk distribution matrix all stay fully interactive.
- The info line under the matrix explains the read-only state instead of the edit hint.
