# Lusaka 15 — action items (2026-10-08)

Extracted from
[`docs/voice_notes/2026-10-08-lusaka-15-transcript.md`](../voice_notes/2026-10-08-lusaka-15-transcript.md)
(the 44-minute review call). The owner walks **Design → Work Packages**,
**Planning → Goals & Milestones**, **Planning → Requirements**, **Design →
Design Specifications / Requirements Mapping**, touches Organization Plan and
Agile Delivery Model, and closes on pushing to staging.

Ordered by what the owner called out first and by dependency.

---

## 1. Goals & Milestones — goals must not be created here

> "they should not be able to add any goal here. If that goal should take them
> to the WBS section … The WBS is the source of truth for the project goals
> because they are just the second layer of the WBS."

- [x] Remove the **Add goal** affordance from Goals & Milestones; goals are
      the WBS's second level. — the button and `_addGoal` are gone, and the page
      no longer seeds three empty goal slots.
- [x] Replace it with a link/CTA that takes the user to the **WBS** section. —
      `_buildWbsGoalsNotice` explains that goals are the WBS's second level and
      pushes `WBSModuleScreen`.
- [x] Make sure a goal added on this page can no longer be created
      independently of the WBS. — the goal list now comes from the WBS
      (`_wbsGoalItems`: the live `WBSProvider.wbs` Level-1 items, falling back
      to the saved `wbsTree`), the title and description are read-only, and the
      old `_setupGoalNomenclature` auto-titling is gone. Priority and the
      milestone mapping still belong to this page and carry over by goal id or
      title. Guarded by `test/screens/project_goals_milestones_layout_test.dart`
      (including the live-WBS path).

## 2. Goals & Milestones — reorder for a usable landing

> "This project goals has to be at the top. … And then the milestones has to be
> under it. And then the mapping has to happen."

- [x] **Project Goals** section first, then the **Milestone table**, then the
      goal↔milestone mapping. — the landing content is now ordered Notes →
      context → **Project Goals** → **Milestones** → **Project Goals →
      Milestones** (the mapping). The mapping half of the goal card
      (`_GoalCardWidget(showGoalDetails: false, showMilestoneMapping: true)`)
      lives in its own section and names the goal it belongs to; the goal cards
      above it keep only the title / priority / description. Guarded by
      `test/screens/project_goals_milestones_layout_test.dart`.
- [x] Keep the **Notes** box hidden/collapsed by default (the owner says it is
      currently showing and taking the top of the page). — `_buildNotesSection`
      now wraps the editor in `CollapsibleNotesSection` (starts collapsed);
      guarded by `test/screens/project_goals_milestones_notes_test.dart`.
- [x] The page must open on usable content, not on a mostly empty headings/notes
      view. — the Milestones section starts expanded (`_CollapsibleSection`
      gained an `initiallyExpanded` flag) and defaults to its Table tab.
- [x] Fixed while reordering: `_goalLabelsForMilestone` walked a fixed three
      goal slots, so building the milestone table before the goals had loaded
      threw `RangeError: Valid value range is empty` and took the page down. It
      now walks the live goal lists.

## 3. Milestones are validated before they are mapped

> "validate the milestones … validate them and then add any milestones in the
> list and then delete any, if they don't need those. Before they then go to the
> goals and then they should be able to open each goal up and map the
> applicable milestones to each goal."

- [ ] Show the **Milestone table** (all milestones, editable dates) as the first
      step, with an edit/validate prompt that mirrors the existing guided-prompt
      pattern.
- [ ] Only after the milestones are confirmed should the goal-mapping step be
      available.
- [ ] A milestone tied to a **goal** does **not** mean every child needs it — at
      least one child must; at the next level the user picks which child.

## 4. Milestone table / timeline

> "I think we need tabs here." · "The milestone timeline … it should be
> chronological … starting from December, 2026. This is the first milestone."

- [x] Add **tabs** to the milestones area (table vs. timeline). — the two
      stacked `_CollapsibleSection`s became one **Milestones** section with
      **Table | Timeline** tabs (`_MilestoneView`, `_buildMilestoneTab`), Table
      first. Guarded by `test/screens/project_goals_milestones_layout_test.dart`.
- [x] Fix the FEP caption — "all shared milestones from FEP with the goals
      currently mapped to each milestone" read wrong on an unmapped page. Now
      "All shared milestones from Front End Planning, with the goals mapped to
      each one."
- [x] Force the timeline into **chronological** order (earliest date first),
      not the current 2026→2027 layout. — `_sortedMilestones` now parses target
      dates through `parseMilestoneDate` (`lib/utils/milestone_date.dart`), which
      reads the loose month / quarter forms the FEP field accepts ("e.g.
      2026-09-15 or Q3 2026") as well as ISO, instead of falling back to name
      order for everything non-ISO. Undated milestones sort last, by name.
      Guarded by `test/utils/milestone_date_test.dart`, plus the table and
      timeline order assertions in the layout test.
- [ ] Make the timeline readable at a glance — the current view is "not user
      friendly at all".

## 5. Mapping UI — size and Expand

> "These screens are very small and it's hard to tell what is happening." ·
> "even though this is the full screen, it's still hard to see." · "when you do
> expand … you should be able to see everything quickly, not have to scroll down
> and scroll inside the scroll."

- [ ] Widen / enlarge the goal↔milestone mapping controls.
- [ ] Expand must give a single, full-width view with no nested scrolling.

## 6. Requirements — map to WBS L1/L2, drop the codes/standards input here

> "it should have the mapping of the requirements to the first and second level
> of the [WBS] … but it doesn't have to mark the code standard." · "The code
> standard comes in in the design planning." · "it needs to be grayed out … when
> they then go to the codes and standards and map it to the requirements, then
> it can show up on this requirements log."

- [x] Requirement rows map to **WBS Level 1 (goal)** and **Level 2 (element)** —
      kept as-is. **Front End Planning → Requirements** now uses the same
      read-only cell in both its table and its add / edit dialog, so neither
      requirements page offers the picker any more
      (`test/screens/requirements_codes_standards_column_test.dart`, rewritten
      from the Lusaka 14 picker test).
      **Open dependency:** the only remaining place to author the values is
      Design Planning → Requirements Mapping (items 7–8) plus CSV import, so
      until that is built the field is effectively read-only end to end.
- [x] The **Codes / Standards** column is **not** an input here any more: it is
      now a greyed, non-tappable read-out of what Design Planning mapped
      (`CodesStandardsReadOnly` in `lib/widgets/codes_standards_selectors.dart`
      replaces the picker in `planning_requirements_screen.dart`; the cell says
      "Set in Design Planning" when nothing is mapped yet). Guarded by
      `test/screens/planning_requirements_codes_readonly_test.dart`.
      The CSV template / import / export still round-trips the field, so the
      mapped values stay in an export — see the note below.
- [ ] Import/export keeps the WBS mapping columns.
- [ ] The requirements log still surfaces the codes/standards mapped downstream.

## 7. Design Planning — Design Specifications is the register

> "when you go to the design specifications … you actually list all the
> specifications. So this … should have a table where you are listing all the
> codes, standards, specifications, their source and all of that."

- [ ] Add a **Design Specifications** table: code / standard / specification,
      source, and the requirement(s) it applies to.

## 8. Design Planning — Requirements Mapping

> "my suggestion you mark the specifications to the requirements, all the
> specifications listed have to be mapped to a requirement … This was supposed
> to be a table view … that made it easy to see what requirements need to be
> mapped."

- [ ] Add a **Requirements Mapping** view: apply codes/standards to
      requirements, table-first, showing what is still unmapped.
- [ ] Every listed specification must be mapped to at least one requirement.

## 9. Design Work Packages show L2 WBS + inherited specs

> "the desired work packages really should show the second level of the [WBS] …
> and then if you click on any, it should give you the requirements and the
> specification code and standards that are associated with that package."

- [ ] Work Packages lists the **Level-2 WBS** as their basis.
- [ ] Expanding a package shows the requirements + specs/codes/standards
      inherited from its feature/WBS element.
- [ ] The package must actually **open up** (the owner's first complaint — the
      packages "were not actually designed to open up").

## 10. Agile — epics, capped at 5–7

> "For waterfall, we are calling them goals … for agile … that is the epic." ·
> "If the Agile project, it should be able to select up to … five to seven
> ethics [epics]."

- [ ] Use **epic / epics** (not goal/goals) wherever the delivery model is Agile.
- [ ] Cap the Agile WBS at **5–7 epics** (currently it appears to allow more).

## 11. Organization Plan — RACI matrix

> "I know the racing matrix [RACI matrix] or something that has to be updated. I
> don't know if you guys did update that."

- [ ] Confirm the RACI Matrix update landed and behaves as discussed.

## 12. Agile Delivery Model — implement the emailed feedback

> "the ideal delivery model … the email I sent you yesterday, I don't know if
> you implemented that or not." · "if you can push that. So what this part is
> very important."

- [ ] Implement the Agile Delivery Model feedback sent by email on 2026-10-07.
- [ ] Push it.

## 13. Schedule

> "There's two things we still have to get a schedule. And a schedule is gonna
> be based on a lot of these things."

- [ ] Once the goals/milestones/requirements structure above is settled, build
      the project schedule on top of it.

## 14. Logistics

- [ ] **Push to staging** so the owner reviews the live build, not localhost.
- [ ] Continue the review the following day.
