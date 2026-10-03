# Voice Note — Lusaka 23 (2026-09-14)

Source: `assets/assets/images/Lusaka 23.m4a` (~37 min).
Transcribed locally with whisper.cpp (`ggml-small.en`, English) on 2026-09-15.

This is the **execution review** that walks the whole chain the platform is
built on — WBS → schedule → cost estimate → project controls → change
management — and it is almost entirely about one defect: **the cost estimate
did not start from the schedule.**

## Distilled asks

### 1. The chain is WBS → schedule → cost, and it must be wired end to end

> "before the WBS jumps to the cost, the schedule has to have had a hold of the
> WBS."

> "Cost takes everything from the schedule and then any additional thing that
> did not show up on the schedule work packages — like the personnel, or any
> contract that are not intertwined into the schedule work packages."

Whole-day-one framing: WBS breaks the project to the second/third level → the
schedule takes it down to the smallest incrementable work package → the cost
estimate prices those schedule work packages as the core direct cost → controls
compare schedule packages against cost packages → change management explains
any delta. The owner stressed this is "the skeleton", and it must hold without
AI.

### 2. The schedule's calendar view must not be blank

> "on the activity tree of the schedule, we have the work packages or the WBS,
> but then it's just on this calendar view that some of them are not showing.
> So that was a blank chart … that's going to be the blank chart that's going to
> show the duration of each work package and roll up to each one."

The tree view listed the work packages; the calendar/Gantt drew nothing for
them. Each work package needs a bar for its own duration, rolled up into its
parent.

### 3. Cost by WBS cannot be the last tab

> "this cost by the WBS cannot be at the end, it needs to be pulled beside the
> builder, either in front of the builder or after the builder."

### 4. Cost by WBS vs Cost Builder must be clearly different things

- **Cost by WBS** — the read-back summary: every cost attached to each WBS
  line, which work packages are linked and which are not, and a breakdown of
  the big costs. A work package with no cost can be given one from here.
- **Cost Builder** — the manual side: add line items that were missed, pick the
  category, link the line to a WBS node, choose the type.

### 5. The Builder must start from the schedule's work packages

The complaint: of the sources feeding the Builder (manual entry, a
code-level "data module", front-end planning allowances, scheduled purchases,
personnel staffing, CAS AI, planning procurement items) **the schedule work
packages were missing** — i.e. the base case was absent.

> "the core thing that's supposed to feed the cost estimate is the schedule work
> packages. It's supposed to start with the work packages from the schedule as a
> direct cost."

> "the direct cost cannot be contract only."

> "If it's a small addition but it's the base case, why wasn't it there in the
> first place?"

### 6. Direct and indirect cost must not share sources

> "it cannot be the same concept. It has to be very clear what is feeding what."

> "direct and indirect costs … can't be fed by the same thing … or there will be
> a duplicate."

The owner also asked for the **definitions to be stated in the product** and
emailed a brief: direct cost is everything tied to delivering *this* project
(scheduled work packages, and the contracts that carry them out); indirect cost
supports the project without belonging to it (shared staff, overheads, offices,
systems spanning projects).

### 7. The doubled dollar signs

> "these dollar signs are doubled. So, the dollar signs in front of all of these
> are two."

### 8. The total estimated cost must be labelled and leftmost

> "with that 4.2 million, can you please move it to the left and say total
> estimated cost."

The tabs each showed a different figure and the owner could not tell which one
was the total.

### 9. The estimate must reflect everything, with no AI

WBS/schedule work packages **plus** contract, procurement and personnel **plus**
the risk metric result **plus** quality (SSHER & Quality) — all inside the cost
estimate, computed at the code level.

> "we're not using AI right now … they should function without AI."

### 10. Both delivery models

The same estimate must work for **waterfall** (schedule work packages) and
**agile** (epics/features, estimated from people × how much work they do ×
number of sprints). The owner offered literature and said to ask rather than
guess.

### Process

- Focus the demo on the MVP: planning phase end-to-end, then phase by phase
  through the week.
- Owner to email the direct/indirect cost definitions (sent during the call).
- "I want it to be functional" — not an update.

## Implementation status (audited 2026-09-15, HEAD `6e104aaf`)

Every ask above is already in the tree. The work landed in
`c4922837` (Lusaka 22), `7893f07f` (voice-note fixes + code-level no-AI
generation), `8cdf3d9e` (cost estimate starts from the schedule work packages)
and `5b0a698e` (Risk Register → Cost Estimate). Several of these comments cite
the 2026-09-10 review because the same points were raised across the 09-10 and
09-14 calls.

| Ask | Where it lives | Test |
|---|---|---|
| 1 — chain wired | `CostEstimateProvider.pullScheduleWorkPackages` stamps the line back onto its schedule activity (`costLineId`) and links the WBS node, so the three views share one foreign key | `test/cost_estimate/schedule_work_package_pull_test.dart` |
| 2 — calendar not blank | `gantt_screen.dart` `_buildRows`: window = earliest start → latest finish **including descendants**, summary nodes are drawn (they used to be skipped outright), and an activity that cannot be placed is *counted* and surfaced rather than dropped | `test/schedule/gantt_schedule_coverage_test.dart` |
| 3 — tab order | `cost_estimate_module_screen.dart` tab strip: Dashboard → Builder → **Cost by WBS** → BOE → AI → … | — |
| 4 — two views, two jobs | `lib/widgets/cost_by_wbs_tab.dart` (read-back + "price this work package") vs `BuilderScreen` (add line, category, WBS link, type) | `test/wbs/wbs_cost_link_test.dart` |
| 5 — Builder starts from the schedule | `BuilderScreen._startFromSchedule` seeds every scheduled work package as an unpriced direct-cost line, linked to its WBS node, idempotent, no AI | `test/cost_estimate/schedule_work_package_pull_test.dart` |
| 6 — separate sources + definitions | `_subTabDefinitions` / `_subTabDefinitionNote` on every Builder sub-tab; direct = `labor, materials, software, procurement, travelTraining, construction`; indirect = `projectTeam, overheads, ga, facilities, insuranceCompliance` | — |
| 7 — doubled `$` | `compute_utils.formatAmountGrouped` (grouping with **no** symbol) so callers prefix the user's currency once — the old path prefixed a symbol onto `formatCurrency`, which already had one | `test/cost_estimate/compute_utils_test.dart` |
| 8 — total cost | cost dashboard KPI strip, leftmost card is labelled **Total Estimated Cost** | — |
| 9 — everything, no AI | scheduled purchases (`pullScheduledPurchases`), personnel (`pullPersonnelCosts`, `quantity × months × rate`), risk (`lib/cost_estimate/utils/risk_cost_lines.dart`), quality (`CostCategory.quality` + SSHER sub-tab) — all plain code paths | `test/cost_estimate/risk_cost_lines_test.dart`, `risk_cost_card_e2e_test.dart` |
| 10 — waterfall + agile | `DeliveryModel { waterfall, agile, hybrid }` and `EstimationMethod` in the cost models; the pull sources from schedule work packages regardless of model | — |

The outstanding gap at the time of writing is **not** in this list: the product
owner attached a screenshot that never reached the session, so this audit is
from the code and the note alone.

## Raw transcript (verbatim)

Kept verbatim, including a whisper repetition artifact in the middle
("I'm going to go back to the builder, and then …") where the model looped on a
silence during a screen-share pause — it is not speech.

So what we got to the execution, what fact it is, before the WBS jumps to the cost, the
schedule has to have had a hold of the WBS.
So if those are not linked, I just want to be clear again on that.
The WBS cost and schedule are linked because the WBS goes straight to the schedule, the
schedule takes the walk, the schedule takes the walk, the walk without stroke, you know,
and raises further into walk packages.
This walk, that feeds the cost estimate.
I just want to be clear that we are aligned on that, still aligned on that because I've
experienced a decrease in the verdict.
Yes.
If you're saying that some things are on the WBS but not on the schedule but they are somehow
on the clock, you can't keep the schedule and jump to cost.
Cost takes everything from the schedule and then any additional thing that did not show
up on the schedule walk packages like the personnel or any contract that are not part
of the schedule, that are not intertwined into the schedule walk packages.
But I did it, the schedule should have everything, tell the people.
Yes, so what I mean is that, so on the activity tree of the schedule, we have the week packages
or the WBS, but then it's just on this calendar view that some of them are not showing.
So that was a blank chart, right, so that's going to be the blank chart that's going to
show the duration of each walk package and roll up to each one.
Is that what you're talking about, Clyde?
Yes.
Yes, so that's what I was talking about.
I mean, can you clarify that because the data should be auto, right?
So once things come to the schedule, it should auto feed every aspect of the schedule.
It's being coded that way with the reason, but if it's in one section, then it should
be able to show up on data because it is the same data.
But some of this is pretty much a duplication of data.
Yes, that also should be it.
And so I think also one of the things that I'm working on too is that with the way it
was configured across the whole app, it was meant to heavily rely on like AI.
And then we had to implement code level implementation as far as continuity, even in some cases,
local module for us to also pull without any third party AI so that it can kind of like
intelligently route information.
And so we've been wearing that around the whole application itself, trying to make sure
that it also has a way of how it can pass on information without having to use what we've
been using so far up to this point.
I think it has got a section for the same gunshot rate.
So I think if you put down that, Oh, sorry, yes, it should have a gunshot section, right?
What is this?
Yeah, yeah.
So I just have a question to me with regards to the cost.
So at this point, like the cost estimate is it supposed to be put on the schedule here
was with the way we're not testing the platform with the way it is right now.
And also after recently, some of the comments that you had shared is that some of the things
that were really defined with like post items and stuff, they kind of like show themselves
like the cost estimate automatically, then those items that are on the WBS that are not
yet linked to a cost, it would ask you to it would ask you to like link the cost item
to that WBS.
And then you just like this on the link and then you just put how much that would cost
in automatically integrates and also updates itself on the WBS mitigation term.
So on private, I know the last time we were on the call, we had disappeared and we just
never came back on the call.
So do you mind scrolling all the way to the right in this cost estimate navigation?
Alright, so that caused by WBS is what you were showing me.
And do you remember I was trying to say something so to get back on and 30 minutes and that
doesn't never finished.
So going back to where we started, I think this was on Thursday around the last week.
The first thing, the first comment I had about this cost section was a cost by WBS, then
if you go to the cost builder, all the different between the cost by WBS and the cost builder,
that's the first question I had for Trungu.
So this is why I was calling Trungu on the call that day to try to align on what he did
here and the thought process.
So we don't just measure everything is aligned because I thought that the WBS all the way
at the end, I am not understanding it.
Also, the cost by I think WBS, we were at some point when I had shown the I think WBS
is an aspect so like that used to be a section under the WBS and then last time we had actually
discussed that it should be instead here and like on the same WBS and so that's why it
was here.
We said that at the time wasn't that we'd actually work out how best it could be useful.
We're supposed to erase it, we just said that no, it should be here until we then work out
how best it can be used.
That's how it is here now.
One of the different between the cost by WBS and the builder.
So the cost by WBS is more like a summary that just tells you each and every cost attached
to the WBS line and also just shows you the ones that are linked and those that are linked
and then it also shows you the kind of like a big cost, it breaks them down.
Then if the work package is without the cost you could also try to add the cost there then
coming to the builder.
So here then you can then add other line items that you could have missed to the cost estimate
the category and everything so you can include them and you can also link them if there's
like a WBS node and then choose which type it is so it's more like the manual aspect
of the things that you could have already missed and then you can add the money in the
way but in the cost by WBS it's just more like a summary that just shows you and then
here it shows you like a dairy cost, dairy cost you can also add if there are any other
shear cost related you could add them.
So what is the builder when you land on there?
There is a section where I think all these items are actually added under procurement
and stuff and so it just was like there's a section prior to this under procurement
where you add the cost, the dairy cost and then other items you just put that information
and then place it here.
So the procurement cost should just be the cost of the procurement items right?
So when you, sorry I just need to understand from the background when you get to the cost
builder, what's visit from a food level, what information gets put into their automatically?
So right now I am a little bit unable to like kind of speak into what's specific information
because up to this point it was being kind of routed based on the AI but then I may just
check and then give more accurate information but then it just gets relevant information
like I think under procurement under the like SHR amongst others and then place it here.
So can you pull up your computer and check?
I think we'll give more context on that.
So I think what I'm actually doing, well I'm actually finding this, here is what we actually
propose.
I think we can do a systematic review like I can call it a demo of the full overcast
of what we've done tomorrow because I think and then this time with like I think you focus
more around the phase in the second part of course maybe looking at the first phase, looking
at how it works without the like AI and stuff like that and then also looking more at the
other section in the, what you got section again, planning, yeah I think planning phase
going going all the way down on that.
From there we can actually tackle all the key MVP items.
So Chungo just looking at these direct costs, did you find out what is, what is feeding
it?
I was asking Clavid that while you were searching to see what's feeding the direct costs because
I don't want to distract, get distracted from that but he said you will provide a feedback
so I guess we can wait for that but the direct costs just sort of with the schedule, the work
packages, the work package, like the cost section should start off with the schedule,
the work packages.
So this commission and handover contract, long lead equipment contract, like this direct
cost is not really, like where is the cost, like where is the breakdown by the WBS?
That's why I was asking you the WBS breakdown and you took me there which is supposed to
be a, a duplication I guess but where is the WBS breakdown in this cost builder?
Now where is the, where are the schedule packages?
So the work packages from the schedule are the first things that should show up in the
cost.
So if you estimate within the work packages, that's what you kind of have as your direct
costs, is that the actual cost to put in the equipment, to do the work, if some of that
is part of contract, that makes sense but the direct cost cannot be contract only.
The contracts are going to tie into either the design or the execution and some contract
by itself might be its own cost and that's okay because it's not going to be part of
the schedule or it's not going to be part of this thing but it has to be clear that
this, this cost builder starts off from the schedule.
That's the one thing that is, that I'm seeing that is missing and like we've been talking
about since before the MVP implementation of hiring people for that one month.
Okay, fine then.
So this is the screen, yes it should be my screen, I just go down let me see what the
53 lines are, 53 lines, okay, so it's these, there's a procurement packages, then where
is the, okay so, where are the work packages, where are the actual work packages, or under
these costs, yeah, okay, so this one, the cost pay, the BBS is the one that shows the
actual work packages like this, that you can see, the dashboard, it's the one that breaks
them down and then it also has kind of like this under this and then you put these quick
packages.
So before I lose my line of thought, sorry, so in terms of how it feeds, there are seven
sources, the first is that they can actually manually add the same information, two, we
had built a, I can call it data module, that actually populates based off of what it actually
believes could be actually missing, and then there's also front-end planning allowances
section, it just populates information from there, also under schedule purchases, and
then under personnel staffing, it also populates information that is from there, also there
like...
So populates in two words, Tungu, the builder?
Yes.
Okay, so Krava, can you please go back to the builder?
So Tungu, the very first comment I'm going to make is, this call by the BBS cannot be
at the end, it needs to be pulled beside the builder, either in front of the builder or
after the builder, that's the first comment I have on this page.
Okay.
It cannot be the last thing.
Now, Krava, do you mind going back to the builder, because you will see what the seven
sources for the builder.
Okay, so, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, I'm going to go back to the builder, and then, I'm going to go back to the builder,
and then, also, CAS AI, when they're actually prompted, it can...
Okay, CAS AI is not really, like, we are open to it with our AI right now, so what else?
Yes, and then, also, planning procurement items.
So, everything but the schedule work packages is what's fitting this thing.
So, I mean, the core thing that's supposed to fit the cost estimate is the schedule work packages.
It's supposed to start with the work packages from the schedule as a direct cost.
So, I'm just wondering why that is not there.
Is there a reason why the schedule is not, like, the packages from the schedule are not there?
No, it's something we'll just quickly add.
I'm not seeing how this is thinking. Yes. Let's see.
I'm sorry. Did he say something?
Oh, it's not me? I'm going to move. Can you hear me?
So, I was asking why the cost estimate not reflect the schedule.
Can you hear me? I can hear you, Jungo.
Yes, yes. It's something we'll actually quickly rewrite, because it's a small addition.
If it's a small addition but it's the base case, why wasn't it there in the first place?
Like, everything I've explained about the scope,
work breakdown structure to schedule work packages to cost, to protect controls, to change management.
That's from the work breakdown structure being up to the second or third level,
then the schedule taking it down to the smallest level, and then the cost taking everything from
the schedule and estimating those, and then picking up any additional things like all the
additional things you just talked about to get a full cost, and then the controls having those
schedule work packages compared to the cost packages, and understanding where you are versus
where it's supposed to be, then the change control, especially for waterfall,
for if a change is implemented, how it's going to affect everything else.
So, I explained this process. This is before we even had MVP people come in,
but it's not in here, but that's the basis. Like, that's the core of the cost estimate.
It has to start from the schedule. You create a schedule, you break it down to work packages for
traditional projects. For ideal projects, it will be epics and features.
A bit different for ideal projects because they are more fluid, so those features could change,
so you just have like an estimate based on the scope. So, I'm a little like, I don't know what
to say, but I don't know what to say.
That would be actually shown by the next few hours.
So, we talked about the skeleton. That is the skeleton.
So, can you please click on the indirect costs private?
So, what's fed this indirect?
So, it's all fed around the same concept as I shared earlier.
Yeah, but it cannot be the same concept. It has to be very clear what is feeding what,
and these dollar signs are doubled. So, the dollar signs in front of all of these are two.
Have you noticed that?
Yes, I noticed that. So, I think the team is working on them.
So, I'm going to send you an email with a different between a direct and indirect cost.
Chenggu, you'll be very good if you can fully understand what you're feeding into the site.
I know it's very tempting to just put different things in there, but it looking shiny is not good
enough if it doesn't have the actual details that it needs. So, the direct costs are usually
everything associated with doing that specific project. Okay, so that's like, first of all,
it starts from the work breakdown structure. Are there any contracts or anything that are
directly for the project? The indirect costs are going to be costs that are outside of the
project itself. Like, say admin staff could be indirect, right? So, people that are not fully
dedicated to the project, maybe they're supporting different projects that could be indirect,
you know, if they add an office location or stuff like that, that'll be indirect costs. So,
they can identify indirect costs, and we can also put the definition for direct and indirect in there.
So, I will send you this brief stuff, but they say that it's going to take a couple hours,
so you can make sure that you can clarify that direct and indirect costs. They can both be
fed by the same thing. They have to have different things feeding them, or if not,
there will be a duplicate. Okay, so we have 15 minutes. Right now, I mean, from what I've
seen so far, I'm not saying that you haven't been working. I am not there with you, but we have not
been able to meet. And from the updates I've seen so far, I'm not sure what changes have been made,
if the cost estimate is still not reflecting the schedule. So, that's the first thing we
talked about when I was trying to get you guys to get a team to work on the MVP release for June or
July, I don't remember which one it was. The top process was the work breakdown structure,
and Alex, you know, I haven't seen Alex in a while, but I did take out time to explain this to Alex
very well, because the work breakdown structure gets it down to the second or the third level.
It goes through design planning. If there's any design parts, the design packages can go in there.
The procurement contracts, if they go across different work packages, they have to be
reflected in those. When you get the execution planning, that is where you can actually start
having the real work packages, because the execution says, this is how we're going to get
this work done. To get it done, we need the design package done, we need this procurement ordered,
and we need to have this contract on board. And this is how long it's going to take,
or whatever it is. So, that's kind of where the execution package comes in.
And the schedule kind of takes those packages under the WBS, and kind of takes them through
different layers to make sure that all the work is reflected in work packages in small
sizes where they are actually incrementable. Once the schedule has start, that's where the schedule
is done before the cost. The schedule kind of pulls up everything, has it busy, this is how we
estimated that this work will get done, this is how much hours it usually takes three minutes to put
in brick wall, this is how many time it takes five developers to develop this, whatever it is.
Then the cost estimate takes the schedule work packages, and has costs associated with
the schedule work packages. So, with those work package items, that is the core direct costs.
Now, a lot of times the personnel, especially if it's not agile, if it's waterfall,
if I'm like a project engineer, project manager, whatever it is, those people will get estimated
as well. They were already estimated in the personnel because they have the rates and stuff
that will pull in. If you have the sheets and the sheer and the qualities, if you said, "Oh,
we're going to check this and bring in a quality person," or do whatever it is,
if that cost didn't show up in any of the design package or the execution package that fell into
the schedule, then that is also pulled forward. That's how you get your full direct costs.
Your indirect costs will be, say, if they're going to rent an office for seven days or for
six months, that cost is going to be an indirect. If they're going to have an admin assistant that
supports the company overall, not necessarily just a project, that'll be indirect. So, that's what
feeds the indirect, but you do have to be clear on what is feeding what and make it very clear,
so that way you understand what you did as well.
Okay.
So, I just sent you the email with the definition of direct versus indirect costs.
But at a basic level, the cost estimate is not showing the schedule. It needs to start with the
schedule. So, that also makes me concerned about the scope tracking and then the chain management
because they are all linked. And this should be done for waterfall and for agile. I did have
some literature on those two different estimations. You can also Google it. If you're
confused or you can ask me, that's why we have these meetings if you need any clarifications.
The cost by the BBS, the cost builder should start off with all the information coming from
the schedule. The cost by the BBS, that's why I was like, okay, kind of leave it there. It's
supposed to pull by whatever happened from the cost builder and kind of show the cost on each
of the BBS elements and stuff like that. It should also be within the cost estimate itself,
like the cost builder or the dashboard. The formulas in there should be able to show
you the total amount of the contract or whatever it is on there. So, I just...
Carmen, can you click on the share on quality?
Okay, then click on additional elements.
So, where is the total cost? The 4.2 million is the total cost. Where do you see the total cost?
This is broken down by direct, indirect share. Share on quality and then additional. So, where is the
total cost? The total cost is, um, yeah, just a moment. It's on the cost dashboard.
Which one of these is the total cost? The cost baseline?
It should be total cost.
But it's not the right thing, right? You didn't estimate the right number. Have you already
authorized cost? Yes, when I was trying. Okay, no problem. Can you please go back to the builder?
Okay, so that means the estimate total is the total cost.
So, that one down there with the shield, the middle one is the total cost.
The 4.2 million.
All right, so with that 4.2 million, can you please move it to the left
and say total estimated cost? So, that is very clear. I could not tell which one was the total cost
because we have all these different, um, tabs that shows they have different costs associated.
But the total estimated cost has to be in one tab, like at the left. So,
that is very clear what the total estimated cost across all the, all the tabs is.
They should hear me because I can't hear him. I don't know if he heard me or not. I don't know
if he's here or not. Yes, I'm here. I can hear you.
All right, so did you hear what I asked for?
Yes, I've written down notes and then I'm also recording this, I think, the whole conversation.
Okay, but what did I say? What did I ask for?
[BLANK_AUDIO]
