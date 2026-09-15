# Voice Notes — 2026-09-10 execution review (five clips)

Source: five recordings in `assets/assets/images/`, captured 15:56–17:17 on
2026-09-10. Transcribed locally with whisper.cpp (`ggml-small.en`, English).
Archived here beside their siblings (`2026-09-08-lusaka-22`,
`2026-09-15-lusaka-24`) for the record. Nothing in `assets/assets/images/` is
bundled — `pubspec.yaml` ships `assets/images/`, not this directory.

| # | Clip | Length | Page the owner was on |
|---|------|--------|------------------------|
| 1 | `AUDIO-2026-09-10-15-56-33.m4a` | 0:40 | Procurement |
| 2 | `AUDIO-2026-09-10-16-33-25.m4a` | 0:09 | A card that "is supposed to show the WBS packages" |
| 3 | `AUDIO-2026-09-10-16-40-31.m4a` | 0:44 | Schedule |
| 4 | `AUDIO-2026-09-10-17-16-32.m4a` | 0:19 | Change Management — new change request |
| 5 | `AUDIO-2026-09-10-17-17-00.m4a` | 0:09 | Change request — document upload |

## Distilled asks

1. **The procurement page is broken, everywhere.** "Nothing is working" — the
   tags (the tab pills), the scope value that should move from procurement
   through to scope details, the procurement workflow, and the rest of the
   page. Re-look at the whole flow.
2. **A card was supposed to show the WBS packages**, and showed something else.
3. **The Schedule has to carry everything the WBS has.** Every WBS package
   should be able to find itself on the schedule; on the schedule there should
   be an option to attach the WBS item's start and finish; and a cost item
   attached inside the schedule has to show up on the schedule, on the Cost
   Estimate overview, and on the WBS cost estimates.
4. **Change Management must support creating a new change**, and its Scope
   Impact section must let the user choose which scope the change attaches to —
   drawn from the work breakdown structure.
5. **The change-request document upload does not work.**

## Clip 1 — Procurement page (0:40)

> I was checking through the procurement page because I should suspect that
> something should come from the procurement page, but the procurement page is
> also like buggy. I remember from last time when we were on the call, we had
> agreed that it needed to be re-looked at. Yeah. So if we can try and re-look
> the procurement page as well, almost every aspect of the procurement flow.
>
> So nothing is working, the tags, the scope value to move from procurement to
> scope details, procurement workflow, and just everything else on the page.

## Clip 2 — the card that should show WBS packages (0:09)

> So this cage [card] is supposed to show the WBS packages. It's supposed to
> show the WBS packages.

## Clip 3 — schedule ↔ WBS ↔ costs (0:44)

> Yeah, so the schedule should be able to put out everything that's like on the
> WBS should be able to find itself on the schedule. And then while it's on the
> schedule, it should be an option to attach the timelines of what the WBS item
> is from the start and when it's supposed to finish in order to attach any
> cost related item within the schedule, which then will be able to show up on
> the schedule. And on the cost estimate overview, as well as on the WBS cost
> estimates.

## Clip 4 — change management, scope impact (0:19)

> So on the change management, you should also be able to create a new change
> management. So on the scope impact, you should be able to choose which scope
> is attached to that change that you are making. So it's supposed to draw
> things that are also on the work breakdown structures.

## Clip 5 — change request document upload (0:09)

> And then as you create a change request, the document upload is not working.

## What each ask turned into

Recorded so the next review does not have to re-derive the mapping.

| Ask | Where it landed |
|-----|-----------------|
| 1 — the page latched an empty project id and never subscribed to its data, so every tab stayed empty | `PlanningProcurementV2Screen._syncActiveProject` / `_bindProject` (`lib/screens/planning_procurement_v2_screen.dart`), rule pinned by `shouldBindProject` in `lib/procurement/utils/procurement_cost_line.dart` |
| 1 — tab pills appeared to do nothing | `_selectTab` scrolls the selected tab's content into view (`KeyedSubtree` + `Scrollable.ensureVisible`) |
| 1 — "the scope value … to scope details" | `procurementItemCostLine` + `findWbsNodeByCode`: the item's budget now becomes a real Cost Estimate line filed under the WBS code, linked onto the WBS node, so the WBS / Cost Estimate / Cost by WBS views all read it |
| 2 — a card showing the WBS packages | `ScheduleWbsPackagesCard` on the Schedule module (`lib/schedule/widgets/schedule_wbs_packages_card.dart`) |
| 3 — everything on the WBS finds itself on the schedule | `buildWbsPackageRows` / `wbsPackagesMissingFromSchedule` and `ScheduleProvider.attachWbsPackages` (`lib/schedule/utils/schedule_wbs_packages.dart`) |
| 3 — attach the WBS item's start and finish | `ScheduleProvider.applyWbsPlannedDates` (WBS → schedule, fills only undated rows) and `WBSProvider.applyScheduleTimelines` (schedule → WBS) |
| 3 — a cost item attached in the schedule shows in all three places | `ScheduleProvider.attachCostLineToActivity` + `WBSProvider.linkCostLine` from the card's "Attach cost item" action |
| 4 — create a new change, scope impact from the WBS | `ChangeRequestScopePicker` (`lib/project_controls/widgets/change_request_scope_picker.dart`), now used by the register's one-tap "Quick CR" as well as the long-form Create CR tab |
| 5 — document upload | `FileUploadHelper` now reads bytes with `PlatformFile.readAsBytes()` instead of the deprecated `bytes` field (null on the web-blob / path fallbacks, which is why the upload silently failed), enforces the 25 MB Storage cap up front, and the New Change Request dialog uploads through it instead of its own broken copy |
