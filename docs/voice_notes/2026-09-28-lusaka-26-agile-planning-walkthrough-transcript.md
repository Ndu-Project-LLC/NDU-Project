# Voice Note — Lusaka 26 / Agile Delivery (planning) walkthrough (2026-09-28)

Source: `Lusaka 26.m4a` at the repo root (~44 min; an identical copy is
`Lusaka 26 copy.m4a`). Transcribed locally with whisper.cpp because no hosted
transcription key was available in this environment. To regenerate the
machine-readable transcript (`.txt` + timestamped `.srt`):

```bash
ffmpeg -y -i "Lusaka 26.m4a" -ac 1 -ar 16000 -c:a pcm_s16le /tmp/lusaka26.wav
whisper-cli -m ggml-base.en.bin -f /tmp/lusaka26.wav -l en -t 8 -bs 5 \
  -osrt -otxt -of lusaka26
```

`ggml-base.en` was chosen for turnaround (~1.5 min of compute for the 44-minute
recording); a `small.en` or `medium.en` model would resolve more of the mangled
vocabulary below.

This is the Agile Delivery Model review: the owner walks the Planning-phase
Agile screens top to bottom — Kanban Configuration → Epics & Features →
Acceptance Criteria Planning → Capacity Planning → Agile Map Out → Release Plan
→ Agile Metrics Planning — and calls out what is missing or in the wrong place.
It is a **screen-by-screen review**, so the asks below are the owner's words
with the mangled bits flagged.

**Transcription caveat:** the audio is a screen-share, so speaker turns are not
separable, and whisper-base reliably mis-hears Agile vocabulary. Read the
quotes with these substitutions in mind:

| Whisper wrote | Means |
| --- | --- |
| "ethics" / "the ethics" | **epics** |
| "storage" | **stories** |
| "backflow" | **backlog** |
| "exhibition" | **execution** |
| "background governance" | **Backlog Governance** |
| "the danger execution" | **the Agile Execution** phase |
| "the muscles" | **milestones** (release-plan section) |

The tail of the recording (from ~41 min) is pure logistics: the session is
continued tomorrow, and the meeting moves to 2 PM.

## Distilled asks

### 1. Move Kanban Configuration under Epics & Features, and say what is configurable

> "the Kanban board configuration, I feel like we need to maybe break it out …
> so move the Kanban configuration under the epic and feature"

> "Definitely on the epic and features"

The owner confirmed the section order twice, then checked the section itself:

> "So is this board editable? … So no. So at this point, you cannot edit. You
> can remove them between different sections" (columns are Backlog / In Progress
> / Review)

> "they can't change anything here, which is OK. But that means they're not
> really configuring anything here"

Two asks: (a) the section belongs **after** Epics & Features in the flow, and
(b) since the workflow columns are fixed, the page must state plainly what the
user *can* change (column names/order/WIP limits) versus what is locked, rather
than presenting read-only cards as configuration.

The Kanban **board** must stay reachable from Execution:

> "this Kanban board is still available in the exhibition, right?" — "Yes"

### 2. The backlog needs a real table view (Epics → Features → Stories → Tasks)

> "So is there a list view for all the features and, and [epics]? You know, so
> currently they just, as cards, yeah, that's not very efficient."

> "a table view, [it] is one of the best for the backlog, because you have to
> see what the story is, what the feature is, it's coming from it and of course
> the [epic] for each one"

> "the backlog should be able to have [roll-ups] from Epic, features, story,
> tasks, so however the table is supposed to be"

### 3. Features must break down into stories — this is the headline gap

> "the features have to be able to go down into storage [stories], so that's one
> thing that is missing here is the ability to break the features down into
> storage [stories] … the [epics], I can see that you can [add] features to the
> [epics] if it's good, but the features all have to be broken down into
> storage [stories]"

> "every story has to affect the features, so every story comes from the
> feature … you have to be linked to one of the features or you create the
> stories from the features, and then those features are already automatically
> tied to [epics]"

> "those stories come from the back[log] and into tasks during the
> [iteration] … when the stories are pulled into those [iterations], they
> convert them into tasks if they want to, they don't have to, but they can"

Chain to enforce: **Epic → Feature → Story → Task**, with Story → Feature
mandatory and Feature → Epic inherited.

### 4. Backlog must auto-populate, be prioritizable, and feed the board

> "It's almost … to auto-populating so [we're not] just putting things manually
> in there"

> "We actually need a back[log]. This is going to be the platform for that.
> It's the back[log] … where you just pull all the stories from the backlog.
> And you can pull them into, you can drag them up and down to prioritize them.
> And you can pull them into the Kanban."

> "you can search for epic, feature, story and all the stories will show you any
> story you click on … And the stories themselves can open that into tasks. But
> that will be within the story. So they won't necessarily be on the Kanban"

### 5. Acceptance Criteria sits *above* Definition of Done in the gate

> "I think it should be above definition of done"

> "acceptance criteria, which would be tied to the definition of done, right?
> So, we will accept this once [we meet the] definition of done for this term"

The user story template must reference the existing gates rather than restate
them — Definition of Ready and Definition of Done already live in Backlog
Governance:

> "if you go back to the [Kanban] configuration, sorry, the Backlog Governance,
> I think we have the definition of [ready] and definition of done"

### 6. The template section is a **User Story Template** and must support more than one

> "So, yes, it has to be called a user story template. And not as a test, but
> the other one."

> "So, given when then, so these are the type of user stories … that's kind of
> like [the template]. Hey, this is what your user story should look like."

> "I think it's just the option of creating a few templates in there, they can
> create templates for, you know, technical user stories … if they don't want,
> they can just have that one [default] template"

> "what I want [is] them templates, so they can name it. So they can name the
> template and decide"

So: rename the section, allow N named templates (technical, etc.), one default,
and keep the given/when/then + Definition of Ready/Done/acceptance-criteria
blocks inside the template body. The top-level clutter above it should be
hidden:

> "all those things, you know, at the top, you really … they can be hidden,
> they should be hidden"

### 7. Release Plan must show the epics **and** the milestones, tied automatically

> "this plan doesn't tell me anything. So first of all, this release plan should
> also already show … all the [epics]. Also already show the milestones that we
> had identified … for some point in this project"

> "if we are [tying] any of the [epics] to milestones, we should have been done
> … that should also show here; this should start with a blank"

> "the milestones should be reflected automatically with the associated …
> [work breakdown] structure item"

> "at the [epic] level, it should tie with all [the estimates], how really they
> put in for each of those"

Also asked for the release table to be viewable as a table ("I can type view,
like the [table] view") rather than only cards.

### 8. Metrics Planning vs Backlog Governance is duplicated and indistinguishable

> "I don't know what the difference between this and the [Backlog] Governance
> is. But I believe we put this in the [Backlog] Governance or my mistake in
> that."

The owner repeated it twice ("Yeah, he's going on both sides"). One of the two
must go, or each must be given a clearly different job.

### 9. Metrics Planning must come **before** Agile Map Out, and drive the dashboard

> "either the metrics planning goes above the [Map Out/dashboard] which will
> come in the dashboard. Because the metrics should kind of come before the
> dashboard"

> "it should be driving … an output. So it does not look like it's driving any
> certain output"

> "my [view] is best … to just have the metrics available. And then the
> dashboard is going to reflect those metrics. And nobody's choosing, [it's]
> choosing" — i.e. **stop making the user tick metrics**; pre-select the tracked
> set and let the dashboard render it

### 10. The dashboard must be a dashboard

> "It's a friend [screen] that says this is supposed to be a dashboard. Please
> make sure that it's going to be consistent with everything that the dashboard
> should have. If this cannot be a [decision], it's still okay to have it here.
> But … you wouldn't have any relation on it."

Named metrics the owner expects tracked: velocity/predictability ("you need to
know if you say you could finish"), business metrics as optional. Also:
"the dashboard needs to be tied to this metrics."

### 11. Planning-stage sections that are informational must still be updatable

> "at this stage in planning … can they change anything on this stage?"

> "ideally, I just want to be able to be updating this thing" (Capacity
> Planning, tied to the two-week delivery-model cadence)

The delivery-model cadence (two weeks) is the input; capacity and metrics
planning are supposed to compute from it.

### 12. Feature add/edit must carry the fields the epic link needs

> "you have the title of the … description [and] the priority of that feature.
> Because every feature will be tied to an epic."

> "How do you add story to the features?" / "So if you go back to your [Kanban]
> configuration board, so those are your stories, right? How do you add those
> stories to the backlog?"

### 13. Meeting logistics (not a code ask)

> "I plan to have this meeting from two to four. Push it to three. I'm not able
> to go past four or four, ten … So plan to continue this tomorrow."

> "I'll move tomorrow's meeting to two PM."

Timezones in the room: PST and CST. Organiser action: move tomorrow's invitation
to 2 PM PST.

## Implementable summary

| # | Ask | Primary surface |
| --- | --- | --- |
| 1 | Kanban Configuration after Epics & Features; state what is locked | `agile_kanban_config_screen.dart`, sidebar/flow order |
| 2 | Backlog table view (Epic/Feature/Story/Task) | `agile_stories_backlog_screen.dart` |
| 3 | Feature → Story → Task breakdown, mandatory parent links | `agile_stories_backlog_screen.dart`, `agile_epics_features_screen.dart`, `agile_service.dart` |
| 4 | Backlog auto-populates, drag-prioritize, pushes to Kanban, search | `agile_stories_backlog_screen.dart`, `agile_kanban_config_screen.dart` |
| 5 | Acceptance Criteria above Definition of Done | `agile_acceptance_criteria_screen.dart` |
| 6 | "User Story Template", multiple named templates, hide clutter | `agile_acceptance_criteria_screen.dart`, `acceptance_criteria_template_dialog.dart` |
| 7 | Release Plan: epics + milestones + auto ties + table view | `agile_release_plan_screen.dart`, `agile_release_plan.dart` |
| 8 | De-duplicate Metrics Planning vs Backlog Governance | `agile_metrics_planning_screen.dart`, `agile_backlog_governance_screen.dart` |
| 9 | Metrics Planning before Agile Map Out; metrics drive dashboard | flow order, `agile_metrics_planning_screen.dart` |
| 10 | Dashboard renders the tracked metrics consistently | `agile_dashboard_screen.dart`, `agile_metrics_screen.dart` |
| 11 | Capacity Planning editable and cadence-driven | `agile_capacity_planning_screen.dart` |
| 12 | Feature add/edit shows title/description/priority/parent epic | `agile_epics_features_screen.dart` |

Sequencing, file-by-file steps and verification live in
`docs/plans/2026-09-28-agile-delivery-review-fixes.md`.

## Raw transcript (verbatim highlights)

Regenerate the full text with the command at the top of this note. Selected
passages as spoken, in order:

```text
And they could still identify some stories, but they wouldn't really have what the project is doing.
But it's the concept of the board ...
So is this board editable? So no. So at this point, you cannot edit. You can remove them between different sections.
OK, so backlog, but in progress and review them.
... we can move the ethics and features about the Kanban configuration.
And this Kanban board is still available in the exhibition, right?
... you will have, like, the backlog. You can see it at an epic level, at the feature level, and at the story level.
Is that an option here, or is that not an option? That isn't an option on this particular session yet.
So what I would say is the Kanban board configuration, I feel like we need to maybe break it out. Here ... they can't change anything.
So if we can go to the epic and features, so do you get what I said? So move the Kanban configuration under the epic and feature.
It does not look like they are going to be doing a lot of configuration here.
... they don't have that option here, on that flexibility here, which is OK. But that means they're not really configuring anything here.
So we have to look at epic and features because that's when they need to break down the ethics in the features.
So is there a list view for all the features and, and ethics? You know, so currently they just, as cards, yeah, that's not very efficient.
So how do you add story to the features? So if you go back to your account bank configuration board, so those are your stories, right? How do you add those stories to the backlog?
So those are features, so that's the top, then it has the ethics, three ethics, and then everything else.
... the features have to be able to go down into storage, so that's one thing that is missing here is the ability to break the features down into storage, the ethics, I can see that you can ask features to the ethics if it's good, but the features all have to be broken down into storage or the size and the story that we've broken down into tasks.
So I think that is one thing that is missing here is the overall backlog itself, the backlog should be able to have highlights from Epic features, story tasks, so however the table is supposed to be.
every story has to affect the features, so every story comes from the feature ... you have to be linked to one of the features or you create the stories from the features, and then those features are already automatically tied to ethics.
And a table view, she is one of the best for the backlog, because you have to see what the story is, what the feature is, it's coming from it and of course the viral ethics for each one.
And then those stories come from the book and into tasks during the presentation like when the stories are pulled into those frames, they convert them up into tasks if they want to, they don't have to, but they can't, if they need to.
It's almost of these three here under the ethics and features to end on auto populating so we just like putting things manually in there.
so it says epic template details. But we've already created our ethics right ...
So, the only template here is a template for a user story, etc. ... So, it gives you a template of, okay, this is how the user story should be.
So, given when then, so these are the type of user stories ... Hey, this is what your user story should look like. So, I think this is more like a user story template.
... the definition of done will be part of that. That is our story to definition of ready ...
And then the definition of done, I think we, we have done here to, if you say you are done, you must have met this, this that and that.
I think it should be above definition of done.
So, yes, it has to be called a user story template. And not as a test, but the other one.
So, in this planning sector, it's still where the define what that template looks like, and they could have one or two ... so they can name it. So they can name the template and decide what it will be from.
I think it's just the option of creating a few templates in there, they can create templates for, you know, technical user stories or whatever is that.
So, it is supposed to be the other dashboard.
I think we need to make it all the metrics that are involved with that ... Please make sure that it's going to be consistent with everything that the dashboard should have.
Can you please go to the release plan? So this plan doesn't tell me anything. So first of all, this release plan should also already show the, all the ethics. Also already show the milestones that we had identified for some point in this project.
Now, if we are tight, any of the ethics to milestones, we should have been done. That should also show here, this should start with a blank.
Now the milestones should should be reflected automatically with the associated ... what we done structure item.
And then the release is that, of course, it should read and stuff like that. And have like that. I can type view, like the mouse contact view.
So I don't know what the difference between this and the background governance is. But I believe we put this in the background governance or my mistake in that.
the metrics planning and the idea map out. Looks like they look like they are tried ... So the other delivery model, right? We said it was going to be two weeks.
either the metrics planning goes above the amount, which will come in the dashboard. Because the metrics should kind of come before the dashboard. So you need to know what metrics that you're...
the dashboard needs to be able to show these different things because those are the usual things that are tracks for ... The predictability should be tracked because you need to know if you say you could finish.
So I think overall, like the dashboard needs to be tied to this metrics.
my viewers best for artists to just have the metrics available. And then the dashboard is going to reflect those metrics. And nobody's choosing, I'm choosing. Yeah, that's good.
So metrics planning and I'm kind of connected.
The release plan has to be tied to the. The muscles are really good. It's quite efficient. It's already identified. And the timeline of course...
The key to missing here is the backflow. We actually need a backflow. This is going to be the platform for that. It's the back of our day shop in the Kanban configuration where you just pull all the stories from the backlog. And you can pull them into, you can drag them up and down to prioritize them. And you can pull them into the Kanban.
The epic control story. So ethics are like, you kind of know what ethics are tied to each feature. And the features are going to break down into story. So each story in the backflow. So you can search for epic feature story and all the stories will show you any story you click on.
And the stories themselves can open that into tasks. But that will be within the story. So they won't necessarily be on the Kanban.
I had a copy and back end. So I plan to have this meeting from two to four. Push it to three. I'm not able to go past four or four, 10. Right now. So plan to continue this tomorrow.
I'll move tomorrow's meeting to two PM. And I'll talk to you guys tomorrow.
```
