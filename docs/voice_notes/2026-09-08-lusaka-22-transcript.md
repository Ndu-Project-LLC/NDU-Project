# Voice Note — Lusaka 22 (2026-09-08)

Source: `assets/assets/images/Lusaka 22.m4a` (~22.5 min).
Transcribed locally with faster-whisper (`base`, English, VAD) on 2026-09-09.

## Distilled asks (project-controls review)

### Change management — change request creation & impacts

1. **All work packages must be listable on a change request.** Not just the
   ones currently shown: pull *all* work packages into the change-request
   work-package picker, verify every package is actually repopulating, and let
   the user deselect / add others from there.
2. **Searchable / capped work-package picker.** Don't list 50 packages (covers
   the whole screen). Show the first ~10; the rest are reachable through a
   drop-down with a type-to-search filter (e.g. typing "electrical" pops up
   every electrical work package to pick).
3. **Cost & schedule impact captured at creation.** The change request must
   carry the *initial cost estimate* of the change and the *initial
   duration/schedule impact* (days / weeks / …) so the approver can go look at
   it and confirm it.
4. **Contingency / management-reserve drawdown belongs to the approver.** The
   contingency drawdown and management reserve drawdown fields should only
   appear when the change is approved; the approving person decides whether it
   comes out of contingency or management reserve.
5. **Deliverables impact at approval.** When approved, list whatever
   deliverables are associated with the change (contract to go get, document
   to update, …) — which deliverables are impacted / modified / deleted — and
   capture that list (e.g. the "documents" list already visible).
6. **Before the change is closed: actual vs estimate.** On closure the user
   records what deliverables were impacted and what the *actual* cost and
   schedule turned out to be compared with what was in the cost and schedule
   estimate.
7. **Controls must show actual vs plan per change request.** For each affected
   work package: initial cost estimate & initial duration vs what the change
   made it become (cost more/less, more/less time); the variance reason is the
   change request number (CR01…). Wants to see how change management ties into
   project controls.

### Cost estimate must work WITHOUT AI

8. **The first estimate must fully reflect project cost, no AI.** Duplicate
   the WBS/schedule work packages into the cost estimate (duplication feature),
   with a manual estimate column the user prices themselves; no AI.
9. **Personnel cost is a built-in calculation.** The rate table + number of
   people + number of months already exist in personnel; the
   rate × people × months calculation should be a plain function at the code
   level (open-source/library), not AI.
10. **Reflect everything: WBS, schedule, contracts, procurement, personnel,
    risk, quality.** The cost estimate section must show everything in the
    WBS/schedule plus additional contract/procurement/personnel costs, plus
    the risk metric calculation result, plus quality — all reflected in the
    cost estimate.

### Process

- Next meeting: tomorrow 11:00 (not 8:00 — the 8 a.m. slot conflicts; agreed
  11). Come with laptops ready to work.
- "I don't want an update to be shared. I want it to be functional." Implement
  by tomorrow's meeting. AI is off for now (cost); the site must function
  without AI.

## Raw transcript (verbatim, lightly de-fillerized)

> In fact, all our packages are not listed here. How does this allow those
> work packages to find them, to add them to this specific change request? I
> think maybe we can just deliberately pull all of them. It should not only do
> that, but then we just verify that like every package is actually
> repopulating. So right from there they can actually more select and that they
> can also add the other. Yeah, so what I would say is that there should be the
> option to search for the work package as well. So that's that option or the
> scroll down where they can go down and choose because you could be telling
> what packages you could be 50 work packages. So we don't want to list all 50
> here either. You end up covering the whole screen depending on the project.
> Some projects might just have a few, so it might make sense to list all of
> them. So it is the first 10 like you've done here and then the rest they can
> select from a drop down list or something to that effect. And they can be
> like the little search can search. And they can start typing in the name. So
> that type in electrical and every electrical work package will pop up and he
> can select from there. But that is what needs to happen for the change. What
> goes with the impacts? So that way any work package as impacted needs to be
> reflected here. Okay, that's clear. All right, so if you can please make a
> note and implement that that will all fall on private. Sorry to interrupt
> you. I just had to make sure that that point was clear to tune specifically.
> So this, the variable impact I honestly don't know how it's supposed to
> function. A bit modified, you know, sketching impact that didn't mean the
> initial post-test move. Okay. And you can get me because I don't want to have
> to repeat this to you. That's why I didn't need any of you on this call. So
> private is not having to tell you and I need some stuff. And I have to talk
> about this again next week. So I really want to make it that you can get it.
> Yes, I can hear you. All right, so for the course on the scheduled impact, I
> saying as initial process made and the the the scheduled impact should, um,
> like that set of days, impact should should also be scheduled, um, initial
> duration or something to, to that effect because they will have to like go
> and look at it and confirm it. So those two needs to stay for this change
> request. They're putting like, what is in the estimate of the change is going
> to be and how much time they change is going to take. So it'll be days weeks
> more. So you can have the option to put in like the number of like what it is
> for the duration is. And then, um, so this part, like the continuity drawdown
> and the reserve drawdown, I think should be more of if we get approved. Um,
> then it shows what continuity, what, uh, I don't know if it's going to be at
> all. If it's resistant, so easy. And it's not going to come out of the
> contingency or it's going to come out of the management room. It's going to
> come out of both at the same time, so one of them is going to be it. So I
> think that option to put in a contingency drawdown or drawdowns can be given
> to the person approving it to determine if it's going to be a contingency or
> a management reserve change. And then the deliverables impact, I think, also
> comes at the end when easy to approve. When it approves, the top orders will
> be to list whatever deliverables that are associated with that change. So say
> if they need to go out and get a contract or if they need to update a
> document. So it's knowing what deliverables will be impact or modified or
> deleted. And then having the demo that deliverable or the list of those
> deliverables. I saw down there, it had documents, so that's it like this
> documentation is going to go. So that means if you had any code, so whatever
> it is, you can update that in there. So what it can request itself, like you
> don't have to have, like, to crack it, I think I saw it, you put a
> description and stuff. So that kind of goes through with it. And then when
> it's submitted, it's going to request, it has to go to the product manager or
> the control manager or whoever, so the race issues as the manager already
> goes to that person. And then that person can review it and approve it. And
> then the document which was there was impacted and before the change is
> closed, they have to put what deliverables were impacted, what the actual
> cost and schedule estimate was compared to what was in the cost and schedule
> estimate. So from what I see, this seems to be working, because it is pulling
> from the work breakdown structure, like the work packages, the key thing I
> would say that needs to be confirmed is the control. So if this is, like, the
> work package usually will have a cost and schedule, right? So that's kind of
> where, if you have the initial cost estimate and the initial duration for,
> like, as a stability change, there's got to be a check of actual versus plan
> in terms of, for this work package, this is how much cost and schedule, this
> work package was going to take. If you make this change, this is what a
> difference is going to be. So almost like a different standard, this is not
> going to be worth it. What the change is going to be based on this change,
> but I think that I'll be reflected on the product control. I haven't received
> the product control working yet. But from a change, management perspective, I
> can see where it has into the ability. And now I want to see how it has into
> the control. So the control, either of the change, the work package, if it
> was deleted, then it will show that the cost and schedule, as such, the work
> package will change. But maybe he was added, like, maybe cost more than it
> already was, of course, of course, or cost less. He's going to take more time
> or less time, but that will show that the actual versus plan and the reason
> will be because of the change request 101, or CR01, whatever the number of
> this change request is. So what I said makes sense, and again, you have
> questions around how to make sure that this all ties in together more.
>
> Okay. So the project controls is private. Did you do the project controls as
> well? No. All right, so I know China was supposed to incorporate the WBS show
> up to the cost. So have you looked at the costs in two? Yes. What? So what
> they have been some obvious to you, you just haven't heard it. Is that what
> you're saying? I'm saying that it's like muting, manually the way has like
> shown you last time. For the cost estimates? Yes. China, go ahead and tell
> you you have to pay the cost estimate to go from the WBS and then every other
> thing. At the code level. So go from the schedule. So yes, yes, at the code
> level, I think there was something that you flagged in that the actual
> consistency of lack of it was actually an issue when there was no AI. Because
> at the code level, it's like it wasn't pulling very, very good. Very very
> strong information as opposed to windows there and so like that's what you
> have flagged this time to me that okay it's like when it pulls with you it
> pulls better compared to if you just I don't want to say anything about here
> it's not about a post-level and you were going to implement it the schedule
> has broken down so it's like even from a core level perspective or or a local
> node of that that's supposed to be a duplication of that update just with
> additional features. Oh yes yes I'm not turning AI on so we're going to
> utilize this site without AI right now because AI is pushing me a lot of
> money and we are still where we are so let's visit AI out of it we have a
> great discussion around this or the fact that the culture should spread the
> schedule to the case of duplicating that page and making them similar we're
> just going to have to walk packages and of course we don't have the column
> for each of those little packages like what is in tail and all of that and if
> I'm not really trying to get those estimates without the help of AI AI can
> obviously send the web finally but we're not using games right yes yes as in
> us what so sorry come to that level yes I think I think what you just I think
> what you just saying is that it can populate information that's what you're
> existing it just can populate new new information so like this is what you
> were saying last time we talked that was it happened what this is the
> question with you gentlemen at the at the code regular site levels because
> estimates should reflect the schedule with all the WBLs that we should also
> put in the any any estimates on the personnel and stuff and that's what you
> were talking about or AI has to put it in and I'll tell you you know you put
> your duplication if you have a duplication feature where it's duplicates all
> the work packages that cannot table on the long line and then you have a
> column that is first estimate and then the pages for it they can they can
> google it themselves and put in whatever estimates it is for for each of
> those packages to run it AI to do them then for the personnel to we already
> have the rate table in the personnel and we already have the number of people
> the number of months if it's calculation calculation calculation function
> that should be available open source or or as a packet of water should should
> should not have all of you to do it at the code level and then there would be
> a good enhancement with all the crumbs and like also giving you information
> on all of that but that should be a lot that is that is not supposed to be
> the the functionalities I want us to move away from the AI.
>
> You can go ahead and I want you to be sure nothing like if you're working
> through. So just a moment, I'm trying to see the screen. I think for this one
> I just need to do a further check at the code level at the code level
> implementation. So I'll just do that and then I'll share the update. I don't
> want an update to be shared. I want it to be functional. Yeah. We are fast
> like sharing of this right now. Like in too many of you are implemented. As
> if you haven't, I would suggest you implement it by tomorrow's meeting. Yes.
> We talked about the functionality. We talked about it with being this is
> before this AI was run out today. When there was AI, I was going to talk
> about it and I have the stress in that we want to stop what at the code level
> without AI. I think it's a good thing that AI is not available now. So let's
> look at the real big functionality of this thing. They should function
> without AI. AI may be good, but they should function without AI. If you need
> to duplicate the information whenever it's put here, it should update. Then
> we do that. Okay. All right, so what's anything else guys? This is nothing
> from nothing to. All right, so 2 p.m. does not work too well for me. When is
> it good time to work? We can make that 8 a.m. as usual. I think that the
> world is best. So that way you have your laptop and everything that you need
> to work. So just meeting a two talking on your phone, it really doesn't help
> with an artist project that is way behind the camera. So I don't know why we
> are showing up without the ability to actually work. So for the more. Is it
> that the afternoon is actually awful that it's just 2 p.m. to something? 2
> p.m. is awful. I cannot do 2 p.m. my 2 p.m. is really good. Oh yes as in I
> come like I'm gonna ask would it would like 2 p.m. be? So I'm only asking
> because I think tomorrow personally I might have a conflict. Tomorrow you
> might have a conflict at 8 a.m. Yes. So what time are you available tomorrow?
> Will 11 work for you? I think I'm just estimate what a sort of time is in in
> our time here. So that's pst right? I am central time cst. Oh cst. Oh 18. 18.
> 18. Okay I think we can do 18. So please start to make it to the mid in the
> mid in the mid in the mid. Yes. So it's not just to show up just to see that
> you're here. But you actually really need and so we can actually get guests
> of women. So the cost is to be fully reflected. The cost estimate part of it.
> So reflect everything in the WBS. And then any additional in the contract
> procurement or personnel. Is it currently showing on the cost on the WBS? It
> needs to be reflected in the cost estimate section. And then the risk. Also
> so the risk has a risk metric. It has like like the calculations for the
> risk. So whatever the two comes out to issue issue up on the cost estimate as
> well. So the cost has made all the schedule. From the WBS expectation.
> Everything is on there. Then it also has to reflect all of that costs. I was
> not interested in the video. So I know we've talked about it. And also it was
> quality here. And if I miss anything else, I know we've thought about it. If
> you have any questions, please let me know. The first estimate has to fully
> reflect the cost for the project. Without AI. Okay. All right. So I guess
> that's it for today. With the meeting at 11. So I can remember on not have
> something else on top of it. I know this is down here.

## Implementation log (2026-09-09, staging)

Executed from the distilled asks above (on top of the Lusaka 22 work already
in the working tree from the previous session — searchable work-package
picker, creation-form cost/schedule impact, deliverables list, drawdown
source at approval, actual-vs-estimate at close-out):

### CM1 — Fix approveStep stale-overwrite (drawdown wiped approval state)
- **Bug**: `approveStep` called `_updateCR` twice — first with the approved
  steps / status / step index, then again with the drawdown fields built from
  the *original* `cr`. The second update reverted the approval entirely, so a
  final approval left the CR stuck at `pendingApproval` with the last step
  never marked approved (while the reserve had already moved).
- **Fix** (`lib/project_controls/providers/change_management_provider.dart`):
  compute the drawdown first, then persist ONE `_updateCR` carrying approval
  steps + status + step index + drawdown fields atomically.
- **Tests**: `test/project_controls/change_management_provider_test.dart` —
  the two Lusaka 22 drawdown tests now pass (only-chosen-reserve moves exactly
  one reserve; drawdown clamped to the reserve available at approval time).

### CM3 — Change requests tie into Project Controls variance (ask 7)
- **Ask 7**: "the actual versus plan and the reason will be because of the
  change request 101, or CR01, whatever the number of this change request
  is."
- `ScheduleVariance` gained a `changeRequestNumber` field (persisted via
  Firestore). `ProjectControlsProvider.attributeScheduleVarianceToChangeRequest`
  upserts it: existing variance rows keep their dates/strategy and gain the
  attribution (user-entered delay reasons preserved, CR appended); missing
  rows get a minimal default variance.
- New pure helper `lib/project_controls/utils/cr_variance_attribution.dart`:
  `syncCrVarianceAttribution` walks the CM module's approved/implemented/
  closed change requests, matches each affected work package against the
  Project Controls work packages (by implementation-task id, WBS code, or
  name), and stamps the variance rows with the CR number + title + schedule
  impact (e.g. "CR-2026-003: Accelerate Steel Delivery (+14d schedule)").
  Idempotent — a CR already named on a row is never re-stamped.
- The Project Controls screen runs the sync on load and shows an amber
  **CR-number chip** on schedule-variance rows (wide table + narrow cards),
  on the Cost tab's Work Package Cost Breakdown cards, and on the
  Forecasting tab's trend cards — so every actual-vs-plan delta is traceable
  to the change request that caused it.
- Made `ProjectControlsFirestoreService` construction lazy and the
  `_uid`/`_currentUser` accessors defensive so the provider is unit-testable
  without Firebase (mirrors the CM provider's approach).
- Tests: `test/project_controls/cr_variance_attribution_test.dart` (12 tests:
  provider upsert + idempotency, reason composition, work-package matching,
  sync stamping, draft/submitted CRs ignored).

### CM4 — Work-package picker: first 10 + dropdown (ask 2 refinement)
- The Create CR work-package picker previously rendered *every* matching
  package as a chip — a 50-package project filled the whole section
  ("we don't want to list all 50 here either. You end up covering the whole
  screen").
- Now: with no search query, the first **10** packages show as chips and the
  rest are reachable through a compact **"More (N)" dropdown** whose entries
  show a check-box reflecting the current selection (tap to toggle). Typing
  in the search box still surfaces every match as a chip ("type in
  electrical and every electrical work package will pop up"). Select-all /
  clear unchanged.
- `_MoreWorkPackagesDropdown` widget in
  `lib/project_controls/screens/change_management_module_screen.dart`.

### CM2 — Personnel cost is a built-in calculation in the Cost Estimate (no AI)
- **Ask 9**: "we already have the rate table in the personnel and the number
  of people the number of months … the calculation should be available at the
  code level."
- `CostEstimateProvider.pullPersonnelCosts(List<StaffingRow>)`
  (`lib/cost_estimate/providers/cost_estimate_provider.dart`) pulls each
  Staff Team role into the estimate as a `projectTeam` / "Personnel
  (staffing)" cost line. Total = `quantity × months × monthly rate` computed
  at the code level via `StaffingRow.subtotal` (basis reference shows the
  breakdown, e.g. "2 × 6 mo × $3,500/mo per person"). `aiGenerated: false`,
  `inSchedule: false`. Idempotent — a row already represented (same role +
  same total) is never duplicated; a repriced row is pulled as a new line.
- **UI**: Cost Dashboard gains a **Personnel Costs (Staff Team)** card that
  loads the project's staffing rows (`ExecutionPhaseService`), shows how many
  roles are/aren't priced and the computed total, and offers a one-click
  **"Pull N into Cost Estimate"** action (`_PersonnelCostCard` in
  `lib/cost_estimate/screens/cost_estimate_module_screen.dart`).
- **Tests**: `test/cost_estimate_pull_personnel_test.dart` (4 tests: totals,
  idempotency, repriced-row re-pull, no-estimate guard).

Verification: `flutter analyze` clean on all touched files (remaining 9
warnings in the cost module screen are pre-existing — unused context-banner
locals, dead `_HeroBand`, one brace lint); 22 related unit tests pass (CM
drawdown/close-out/deliverables, purchases pull, personnel pull, WBS cost
coverage).