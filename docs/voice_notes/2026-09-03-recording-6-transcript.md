# Voice Note — New Recording 6 (2026-09-03)

Source: `assets/assets/images/New Recording 6.m4a` (~10 min).
Transcribed locally with whisper.cpp (`ggml-small`, multilingual) on 2026-09-03.

## Distilled asks (product-owner review of staging)

1. **Cost core is manual, not AI.** Every WBS work package that appears in the
   Schedule must be estimable at the *smallest* WBS level (leaf work package).
   Entering a cost value for a work package ($1 / $10 / $15 …) is core
   functionality and must **not** require AI. AI is only acceptable for
   *suggesting prices* and for checking the site for *missing* items (a
   "minimal AI cost").
2. **Data movement between sections must be core, not AI.** Copying/taking a
   topic from one part of the site to another (e.g. initiation → planning) is
   core functionality; it must not depend on AI "grabbing things".
3. **AI should read the latest version of a topic.** When a topic (e.g.
   technology) exists in multiple phases, AI should use the *most recent*
   phase's version (planning auto-takes it from initiation), not go back to the
   start of the project. Only fall back to an earlier phase when no later
   version exists.
4. **Schedule → Cost linkage.** Costs already visible in the Schedule (e.g.
   "buy CPE", equipment/material purchases tied to work packages) must be
   pulled into the Cost Estimate, not re-entered.
5. **Costs not in the schedule get added at estimate level.** Project manager,
   structural engineer, permits, government fees, architect, etc. are added as
   additional estimate costs on top of the work-package costs.
6. **The "skeleton" must actually work.** Five core aspects: WBS breakdown →
   Schedule → Cost; Cost + Schedule → Controls; management based on Controls
   (what is changing). Everything else (people, quality, orders, procurement)
   feeds those. If the skeleton does not work the app "makes no sense".
7. **WBS semantics (house example).** House → Upstairs/Downstairs/Outside →
   rooms → work packages (walls, floor, electrical, plumbing, AC, wardrobe).
   Each work package carries its own scope: design, requirements/standards/code,
   contracts (per-trade or per-room), procurement (specific orders), and
   execution. The Schedule holds the work packages identified in design +
   execution; the Cost estimate prices each; controls track change against
   that baseline.
8. **Process note.** Updates pushed to staging should be announced to the owner
   (missed notification this round). Staging was behind at recording time; a new
   push had just gone out.

## Raw transcript (verbatim, lightly de-fillerized)

> at the code level or the regular level of the cost estimate, it's going to
> start with the schedule stuff and also the personnel, she, quality, like any
> other aspects of the site that is not already reflected in the schedule. And
> this might not be where you can say the AI cost might be minimal because you
> might need to now find there are these costs that wasn't reflected in the
> schedule and that might be similar to what you say in terms of going to the
> technology page to look to that might be like a minimal AI cost. But I think
> the main point of where you get to cost is like all the WBS items, all the
> work packages in schedule have to be estimated and the same rule up where you
> estimate it at different levels, you like the smallest level of the status
> where you kind of have the cost estimate. So but just reflecting that, I know
> we are talking about if you want AI to then suggest the price, that's where
> you use AI. But they should, they might be able to put it, or they should cost
> $1, they should cost $10, they should cost $15. Like just having that,
> reflecting those work packages, that's the basic functionality that should not
> require AI. Are you understanding where I'm coming from? Yes. So that part is
> what I'm talking about is you cannot rely on AI to grab things from one place
> to the other. That should be on the core functionality. Now to search and see
> if something is missing. I like how you put it like that would be almost a
> minimal AI cost because it's not like someone is asking you the question or is
> searching the web and the whole world to find something for you. This is more
> like within the site, just moving stuff from one place and checking the site
> for okay. But, but the thing is, if, if this works out well, AI should even
> have to work very hard. It just should go to the most previous version of that
> topic because it had been trying along. So if we had technology in the, in the
> initiation phase, but at the time we looked in the initial phase and we came to
> this thing, it should have like both technology that is being gone through a
> lot of that and planning. So the AI should just go to planning because planning
> has automatically taken it from initiation. Does that make sense? Okay. It
> shouldn't be a case of where it not goes back to the beginning. It should, it
> should go to the latest version of time. Unless there was never a latest
> version and it was only left in the shipping. Then that means that is the
> latest version. So it goes back to that one. So I don't see it having to search
> too hard. So of course, for something like cost, that one in the same section
> just took the work cost. We have within this site that is already reflected in
> this schedule and that we don't currently have here. Generally, where there was
> a cost and go buy CPE or buy this or buy this, okay, you have this, this, this
> here and you put them into the cost estimate. Okay.
>
> Okay. So was there anything else that we need to talk about? Because right now,
> so this update that you have right now, it's currently in the staging, right?
> So is the staging up to date or out of date? Yes. It's not up to date. I can
> confirm that. Okay. And then it also, for that matter, you were supposed to
> tell me yesterday when you pushed. I don't know if you forgot. Oh yes. I
> forgot. Yeah. And I've been working throughout the day trying to like push
> multiple stuff. So like right now I've just pushed something else to ask now
> again. Yeah. Okay. Yeah. I forgot about that. I'll put it for that. Yeah. No
> problem. I'll just like, I guess I'll ask you guys when we meet.
>
> So for me, that is a core function. I think that has to work. If it's not
> working, this makes no sense. So the WBS break down to the schedule, the
> schedule tied to the cost, then cost and schedule tied to the controls and
> gene management is based on the controls. Like what, what is changing? So
> those, like those five core aspects is what's going to make this night work.
> Everything else feeds all of them. So those five are kind of the skeleton of
> the body. And then all the everything else that is being used to like the
> people doing the work, the sheer, the quality orders, like your skin, like the
> rest of the human body, you know, so we do have to mention that the skeleton of
> the site actually works. And that's where I think we have a problem.
>
> Okay. So how long did it take you to implement this? We could touch this
> tomorrow. All right. So I will look out. So I guess we will discuss tomorrow.
> If you have any questions, please ask me. I am under documentation out there as
> well. But it has to tie in to cost. Like the WBS break down to schedule, like
> the schedule has a work package. So where you see the work packages, those work
> packages, like when it goes through design, contracting, design, contracting,
> procurement, execution, all of that is like those work packages have these
> different elements that might be associated with it. So if you go back to the
> house example, because I like to see the house example, look at the house and
> the way you broke it up upstairs, downstairs, outside, those are like the best
> level of the WBS. Second level, living room, when you come upstairs, you have
> living room, kitchen, guest room, toilet. That's like the next level. Then you
> have the, then for downstairs or upstairs, you have kids room, master room,
> this is it. And outside, you have planting trees, school area, this is it. So
> that's like the next level because all of them are still under each of those
> three. Now when you now come from house to upstairs to bedroom, in the bedroom
> you are going to have this coated in the bedroom. So that's the next level of
> the WBS. Now in that bedroom, you could have a wall, floor, electrical,
> plumbing, a conditioner, each back, all that, all things part of that distance
> and they're under all different scopes. Other different scopes because you have
> contract, so maybe you have the contract for doing each each back for the whole
> house or just each back for that room. Maybe you have your painter that is
> telling you the painting for all upstairs or painting for just that room. Maybe
> you have to order like a specific paint only for that room. So that's the
> procurement. So everything, that work package has to do with everything that
> has to do with that support. And that's where it ties in together. So when you
> have the design and you design it, you are like, okay, to design this room, I
> need to know what the load there in this room is, what the electrical hold is
> going to be, what the aid bracket is going to look like, how big is this room,
> how much air do we need coming in here. I need to know like how much load is
> going to be in this room usually so that we can have, I mentioned that the
> beams are strong enough so we can buy the tickets in the team or whatever it
> is. So all that goes in the work package of life, in the design. I'll be
> thinking about the design for each of the work package. So the design package,
> it's usually going to be, okay, to design upstairs, this is everything and this
> is how I'm breaking out the design. This is how we're going to work in through
> contract. So if you give the construction person this package and they take it,
> they know everything they need for it. So this is also where requirements come
> in. Requirements to design because say for that room upstairs in, in Zambia,
> you cannot have an upstairs room that does not have three windows. They must
> have three windows. They must use the color yellow wall. They must have, be
> able to hold 7,700 pounds of weight. So lots of them, those requirements,
> standards, code, whatever. That's what those requirements are associated with
> that room, will be tied into the design of it and then the design package will
> go into the execution where like, okay, this is how many types you build it
> from. So everything kind of ties together. So by the time it gets to schedule
> and you have like the double JS element, the schedule will also have the work
> packages that were identified within design and execution. And those work
> packages have, have already included the procurement and the contract that has
> to do with that scope in there. So that's kind of the, that, that, that is how
> everything ties into the schedule. The schedule shows you, this is how we're
> going to build this, this, this project from the smallest level or the width of
> the big project. So once you have that from the schedule, when you get to the
> course, you just take all those work packages. Okay, this is going to be the
> course for each of these work packages. And then the course, you go, okay, what
> all do we have that we haven't included in this execution on design work
> package? But we have a project manager, we have a depth, a structure engineer,
> we have to also have to deal with the permits, we have to get permits and we
> have to pay the government for that. You also need to get an architect that
> will not do that. And then all those costs just added as well. And that's how
> you end up with your process here.
>
> Okay. So you don't have to tie it together. If you don't tie it together, it's,
> it is like, we don't have a sound. Okay. Yes. And so we can touch, touch on
> that tomorrow, like touch base on that tomorrow, but we'll actually implement
> all these things that you've discussed.

## Implementation log (2026-09-03, staging)

Executed from the distilled asks above:

### WS1 — Cost core: price every leaf work package, manually, no AI
- Added pure coverage helpers (`lib/wbs/utils/wbs_cost_coverage.dart`):
  collect leaf work packages, detect linked/priced leaves (by `costLineIds` or
  `wbsRef == code`), and report unpriced leaves — the "smallest level" where
  cost is estimated.
- `Cost by WBS` tab (used in both the WBS module and Cost Estimate module)
  now shows a **Work Packages Without Cost (N of M)** section listing every
  unpriced leaf; each row has an **Add cost** button that opens the manual
  cost-line dialog pre-linked to that WBS node (`AddLineDialog` gained
  `initialWbsRef` / `initialDescription`). Quantity × rate or lump total is
  typed by the user; the line is stored and bidirectionally linked. No AI.
- The tab now watches both providers so coverage updates immediately after
  a manual entry.
- Tests: `test/wbs_cost_coverage_test.dart`.

### WS2 — AI / downstream reads the LATEST version of a topic
- Added a reusable resolver (`lib/utils/latest_phase_content.dart`):
  `resolveLatestNonEmpty`, `resolveLatestPerArea` and
  `buildLatestContextSummary` implement the rule: later phase wins; earlier
  phase is authoritative only when nothing later exists; placeholders count
  as empty. Ready for any AI context builder that scans multiple phases.
- Audit result: cross-phase write paths already honour latest-wins
  (idempotent, seed-only-if-empty behaviours — e.g. `WBSProvider
  .seedFromInitiation`, FEP procurement/contracts seeding) and never clobber
  later phases with earlier data.
- Tests: `test/latest_phase_content_test.dart`.

### WS3 — Skeleton hardening (WBS → Schedule → Cost → Controls)
- Fixed a real cold-start data-loss bug: saved estimates could not reload
  because `EstimateClass.name` is overridden to the display label
  (`Budget Authorization`) while reload used `values.byName` (identifier
  only) → the whole estimate silently failed to deserialize. Reload now
  accepts identifier or label and defaults safely.
- Cost Estimate persistence now round-trips the **BOE** (scope basis,
  assumptions/constraints/exclusions, methodology, data sources, accuracy
  range) and **stakeholders** instead of dropping them on save; BOE /
  stakeholder parse failures degrade to defaults instead of killing the load.
- Tests: `test/cost_estimate_boe_persistence_test.dart`.

Verification: `flutter analyze` clean on all touched files; 47 related unit
/widget tests pass (cost, WBS, schedule, lifecycle, routing).

### Round 2 — schedule ↔ cost direct flows + coverage KPI (same session)

- **One-click pull of scheduled purchases into the Cost Estimate** (Schedule
  module): `CostEstimateProvider.pullScheduledPurchases(...)` creates
  procurement cost lines (in-schedule, WBS-ref carried, $0 until priced) and
  is idempotent; pure detector
  `lib/schedule/utils/schedule_purchase_cost.dart` finds pullable purchases
  (procurement domain / procurement packages, leaf-level, no double count);
  the Schedule module screen shows a status strip with a **Pull N into Cost
  Estimate** button that also stamps `ScheduleActivity.costLineId` and links
  the same WBS node — core data movement, no AI.
- **Costs entered directly on schedule work packages**: each activity row in
  the Schedule Builder now carries a cost action — add on leaf work packages,
  edit when a linked cost line exists (`AddLineDialog` now returns the line
  id so the activity gets stamped).
- **Coverage KPI on the Cost Dashboard**: a **Work-Package Pricing Coverage**
  card shows what % of leaf WBS work packages are priced (progress bar,
  priced/total counts, hint when WBS is not set up).
- Tests: `test/cost_estimate_pull_purchases_test.dart`,
  `test/schedule_purchase_cost_test.dart` (11 new assertions in this round).

### Round 3 — latest-version AI context + schedule/cost finishing touches

- **Latest-phase resolver wired into the Execution & Launch AI seed context
  builders**: new `ProjectDataHelper.buildLatestTopicOverlay(data)` renders a
  "Latest topic versions" overlay (Goals: initiation vs planning; Technology
  and Infrastructure: initiation IT/infra notes vs planning FEP notes) using
  the resolver, and both `ExecutionPhaseAiSeed.buildContext` and
  `LaunchPhaseAiSeed.buildFullPhaseDependencyContext` append it — so AI
  prompts read the most recent phase of any recurring topic, never a stale
  earlier copy. Tests: `test/latest_topic_overlay_test.dart`.
- **Leaf-coverage % in the WBS module's Cost-by-WBS header** line (cost
  lines · total · linked % · **leaf work packages priced %**).
- **"Price them now" walkthrough**: after pulling purchases, the snackbar
  offers a walkthrough that opens the manual cost dialog for each newly
  pulled line in order (`AddLineDialog` per line, cancel/skip moves on).
- **Priced/unpriced confirmation on Schedule rows**: activity rows now show a
  live badge — green **Cost: $X** when its linked cost line is priced, amber
  **Cost: not priced yet** when linked but unpriced (updates right after a
  pull or manual entry so the link landing is visible).

### Round 4 — fix blank Schedule Builder content (missing schedule items)

- **Root cause**: the Project Timeline card's activity rows used
  `CrossAxisAlignment.stretch` with only `minHeight` inside the Builder's
  vertically-unbounded `SingleChildScrollView`. With no bounded cross extent
  the stretch Row threw `RenderFlex` during layout, which blanked the entire
  Builder tab content (only the top chrome / sync cards rendered — the
  "missing schedule items" symptom). Pre-existing at HEAD; surfaced when
  synced planning content populated the tree.
- **Fix** (`lib/schedule/screens/builder_screen.dart`): give each timeline
  activity row a bounded `height: 60` (replacing the `minHeight` + stretch
  expansion) so the stretch row resolves; long activity names now ellipsize
  (single line) instead of wrapping, matching the Activity Tree rows.
  `IntrinsicHeight` was tried first but is incompatible with the bar area's
  `LayoutBuilder` (intrinsic dimensions assertion), so bounded height is the
  fix.
- Verified with widget repros (populated synced tree and root-only tree both
  render without exceptions) and the existing schedule/cost suites (21+
  related tests pass); scratch repro tests removed.
