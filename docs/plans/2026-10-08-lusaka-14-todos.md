# Lusaka 14 — action items (2026-10-08)

Extracted from [`docs/voice_notes/2026-10-07-lusaka-14-transcript.md`](../voice_notes/2026-10-07-lusaka-14-transcript.md)
(the 58-minute review call). The owner walks Planning → Requirements, Design →
Work Packages, Scope Tracking, and Agile Delivery Model (Sprint Cadence &
Calendar, Release Plan), and closes with the automated report not arriving.

Ordered by what the owner called out first and by dependency.

---

## 1. Requirements → WBS mapping is missing from the push

> "where is the requirements to the WBS mapping which is what we talked about
> last time and I sent an email … it looks like that actually wasn't put in the
> push."

The two columns were built in the working tree but the owner cannot see them.
**Deliverable:** the Requirements table shows **WBS Mapping** (a Level‑1 goal,
or `ALL — Entire project`) and **Sub WBS** (the Level‑2 elements under that
goal; blank when `ALL`), persisted on the row as `wbsGoalId` / `wbsElementIds`.

- `lib/screens/front_end_planning_requirements_screen.dart`
- `lib/widgets/wbs_mapping_selectors.dart` (`WbsGoalDropdown`, `WbsElementMultiSelect`)
- `test/screens/front_end_requirements_wbs_columns_test.dart` (3/3 green)

- [ ] Re-verify on the running app, then **push** — the owner explicitly
      suspects it never left the branch.

## 2. Requirements must carry the codes / standards / specifications

> "to get this feature done these are all the requirements and all the codes
> associated with it."

Right now a requirement maps to a WBS goal/element but not to the code,
standard or specification it must satisfy.

- [ ] Add a codes / standards / specifications field (or multi-select) to a
      requirement, saved alongside `wbsGoalId` / `wbsElementIds`.
- [ ] Make it selectable from the standards already captured in the project
      (do not free-type it where a list already exists).

## 3. Design Work Packages must show the traceability

> "by the time you've gone through the design you should have what requirements,
> codes and standards are associated with each of the features … that literally
> [is] the goal of having this work package at the bottom."

- [ ] On the Design Plan → **Work Packages** section, each package lists the
      requirements (and their codes/standards) inherited from its
      feature / WBS element.
- [ ] Read-only "pocketing" view: it reflects what was captured upstream, it
      does not create new requirements.

## 4. Sidebar → Work Packages opens at the top of the page

> "when you put on the last tab it still took you to the beginning, it didn't
> take you directly to it … it makes no sense to have it on the sidebar if you
> click on the sidebar [and then] scroll down to find it."

- [ ] `design_planning_screen.dart` already takes an `initialSectionId`; wire
      the Work Packages sidebar sub-page to it (and check the other Design Plan
      sub-pages) so the tab is selected and scrolled into view.

## 5. Scope Tracking Plan — keep it, re-scope it to Planning

> "in the planning section the scope tracking plan should just talk about how
> we're going to plan [the] transfer [of] scope … a summary of what we're going
> to do on the project … you shouldn't have all the change management stuff."

- [ ] Keep `ScopeTrackingPlanScreen` reachable under Planning **and** restore it
      in the sidebar (it was removed in the working tree).
- [ ] Remove the change-management content from that page; keep it a
      scope-transfer plan summary, not the Execution scope tracking.

## 6. Release Plan drives the schedule and project controls

> "the milestone is supposed to auto-populate on the schedule … we've tied the
> WBS elements to the milestones … for agile that's going to impact the release
> plan because it's going to say these are the features we want to release."

- [ ] Milestones flow from the Release Plan onto the project schedule.
- [ ] Each release shows which epics/features must be complete by its date
      (partly present on `agile_release_plan_screen.dart`).
- [ ] Adding or reprioritising an epic in Execution surfaces the schedule
      impact.

## 7. Agile ceremonies must be selectable and recurring on the calendar

> "sprint planning, stand-up, sprint review … retrospective and then sprint demo
> and backlog grooming have to be things that they have to actually select …
> it cannot just be [a] text [box] … it has to show up in the calendar … it
> stays on the calendar forever until the sprint/product is over."

The Sprint Cadence & Calendar page already has day/duration pickers for
Sprint Planning, Daily Stand-up, Backlog Grooming, Sprint Demo and
Retrospective, plus `.ics` export. Gaps the owner hit:

- [ ] **Backlog Grooming was not visible in his ceremony list** — make sure it
      renders (and that the five required ceremonies are pre-selected, not
      blank).
- [ ] Replace the free-text "Sprint cadence & calendar" field on the Agile
      Delivery Model with a clear entry point into the ceremony selection.
- [ ] Confirm the chosen cadence is reflected on the project calendar, and that
      changing the sprint length re-derives the recurring dates.

## 8. Velocity reconciliation of the agile schedule

> "after the first two sprints you should know what the velocity looks like and
> there should be a reconciliation: are we going to meet it … red flags when
> there's a need to flag it."

- [ ] Use observed velocity (after ~2 completed sprints) to reconcile the plan
      against milestones.
- [ ] Flag milestones that will be missed and state what *can* be achieved in
      the project duration, so the backlog can be reprioritised.

## 9. Automated work / status report is not arriving

> "the bravo [Brevo] key was marked inactive … this is a functionality that
> should already be on the site."

- [ ] Reactivate / re-add the **Brevo SMTP** credential used by
      `.github/workflows/work-report-email.yml`.
- [ ] Confirm the scheduled 6-day work report actually sends and lands.

## 10. Logistics

- [ ] Next review moved to **14:00 on 2026-10-08**; keep the meeting invite
      only on the current date (a stale Monday invite went out last time).
- [ ] Send the owner a written status report after each session.
