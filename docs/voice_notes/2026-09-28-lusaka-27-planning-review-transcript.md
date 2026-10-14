# Voice Note — Lusaka 27 / Planning phase walkthrough (2026-09-28)

Source: `Lusaka 27.m4a` at the repo root (~88 min, 45.7 MB). Transcribed locally
with whisper.cpp because no hosted transcription key was available in this
environment. To regenerate the machine-readable transcript (`.txt` + timestamped
`.srt`):

```bash
ffmpeg -y -i "Lusaka 27.m4a" -ac 1 -ar 16000 -c:a pcm_s16le /tmp/lusaka27.wav
# 88 minutes is long enough that whisper can fall into a repetition loop before
# the end, so it is split and each chunk transcribed with no context carry-over.
mkdir -p /tmp/l27 && cd /tmp/l27
ffmpeg -y -v error -i /tmp/lusaka27.wav -f segment -segment_time 660 \
  -c:a pcm_s16le chunk_%02d.wav
for i in 00 01 02 03 04 05 06 07; do
  whisper-cli -m ~/whisper-models/ggml-small.en.bin -f chunk_$i.wav -l en -t 4 \
    -bs 5 -mc 0 -osrt -otxt -of out_$i &
done; wait
cat out_0*.txt > /tmp/lusaka27_full.txt
```

`-mc 0` (no context conditioning) is what stops the loop; a single
`ggml-large-v3-turbo` run over the whole file aborts on load in this build, and
`small.en` was used instead. `small.en` still mangles the project vocabulary —
read the quotes with the substitutions below in mind.

This is the **continuation of the Lusaka 26 Agile review** and the owner's
instruction was to move on to the rest of the Planning phase. It walks the
planning flow in order — **Kanban Configuration → Interface Management →
Execution Plan → Risk Assessment → Contracting → Procurement** — and calls out
what is missing, duplicated, or in the wrong shape. It ends mid-Procurement:
the owner leaves at 15:30 and the session continues **tomorrow at 2 PM PST**.

**Transcription caveat:** the audio is a screen-share, so speaker turns are not
separable. whisper-small reliably mis-hears the vocabulary, and the recording is
a phone/two-mic capture, so some passages are marked `[INAUDIBLE]`. Read the
quotes with these substitutions in mind:

| Whisper wrote | Means |
| --- | --- |
| "ethics" / "the ethics" / "epic" | **epics** |
| "storage" / "stories" | **stories** |
| "backflow" / "backdrop" / "backlog" | **backlog** |
| "exhibition" / "the danger execution" | **execution** |
| "petition plan" / "the situation plan" | **execution plan** |
| "the muscles" / "the muscles" | **milestones** |
| "the WDS" / "WVSP" | **the WBS** |
| "FEP" / "FTP" / "the SCT" | **the Front-End Planning (FEP) section** |
| "RSP" / "RFC" | **RFP** (request for proposal) |
| "invisible Samsung" | **a lump sum** |
| "the aquarium / aqua flow" | **Aquaflow** (an earlier phase) |
| "raccoon" / "RAC unit" | a **rack/telemetry unit** to be procured |
| "commissioning" | **contract negotiation / award** in context |
| "the race" | **the risks** |

## Distilled asks

### 1. Kanban Configuration — approved, with one layout complaint

The section itself was signed off ("thank you for having the capability … the one
that is in the card, you can go to the card here"). Two notes:

> "So can this be little? So I feel like it's covering the entire page, right?
> … can the button be like something little"

> "you have to scroll all the way down there to the actual … but yeah this is not
> a description for the section"

So: the add-column control currently takes over the whole page and pushes the
rest of the configuration below the fold; it should be compact, and the section
should keep its own description.

### 2. Interface Management — the add bug is fixed; move the overview to the front

> "It's like it had a bug where when you're adding stuff … So I'm just trying to
> add one. Done, how could it work? So yes, it now populates information on the
> some interface management section."

> "And the adjustment that we're trying to make is to put the, I think, status
> dashboard at the front."

The governance/RACI view was shown for the first time and the owner could not
follow it, but explicitly did not want to spend the session on it ("it's not as
hard for me to find a way to deal with that … I don't want to spend, 'cause it's
taken us a while to get through"). Only the overview reorder is an ask.

### 3. Execution Plan — every Execution-specific duplicate must go

The strongest ask of the recording. Execution Plan is a **Waterfall** construct
and its sections repeat project-wide planning sections:

> "I see a petition issue management but there should be just one issue
> management for the entire project so which is in the planning"

> "Execution issues management. I don't know why that's there. If you just take
> code identification, I don't know why that's there because you already have to
> put identities in the earlier point in the teams. That is for the entire
> project."

> "We have lessons learned. If you want to scroll down, as long as it's in there,
> I don't think we need an execution-specific one."

> "the stakeholder identification we've already done that in the beginning so …
> it's going to be handled the same way for the entire project"

> "there's really a risk management for the entire project that's there so it
> shouldn't be specific to the [execution] plan"

And the gating rule:

> "So we still need that project but there should be no [execution] plan for the
> agile delivery. The [execution] plan is mostly so if the waterfall project is
> going to be blanked out, they cannot click on it, they cannot access it."

> "for adult [agile] project is in the adult today without in the ethics there
> isn't features for waterfall project there'll be no adult delivery because
> it's not an adult project"

So: **Agile Delivery projects must not have an Execution Plan, and Waterfall
projects must not have an Agile Delivery flow.** The Execution Plan's duplicates
of project-wide sections (Issue Management, Lessons Learned, Stakeholder
Identification, Risk) must not appear twice.

**Why the backlog matters here, for the third recording running:**

> "the work packages are not the new work packages. That's where the features,
> that's why the backlog, that's where we need a search and go … we do need a
> backlog at that border, 'cause that's where they're gonna take work from. And
> the backlog is gonna have the epics, the features and the stories."

> "I know you have, what I was really hoping for was to see a backlog and see
> some stories and stuff, but that's what we're going to drive the schedule and
> the cost."

> "if you ask the stories there, the story points and stuff like that and then
> the features have like all the features … So that way we can test the schedule
> and of course for the schedule actually it should meet the … milestones and the
> timeline"

### 4. Risk Assessment (Planning) — must be the *same* table as the FEP risk log

> "this view is not user-friendly. It's a lot of scrolling. We already have a
> risk table. I think that we have either in the [initiation] or in FEP."

> "this table has to be it needs to be the exact same table. This table is
> supposed to carry on over and in the final date if things are closed they can
> close it or stuff like that."

> "the risk management section in the planning section should start off from this
> … the card view is okay … both from an overall or over efficiency perspective
> the table of course is needed with the ID numbers, the title, the description,
> what category it is, the probability"

> "we have the risk, you have … the potential cost impact with the [schedule]
> impact then you then have the possible probability and the possible overall
> impact which is the high impact risk or low impact on medium impact risk that
> that is all done on the table not through this card"

> "the same comment I have with this entire site is to be expandable … if you
> click on the expand, you can cover the screen and you can see all the details
> for that table"

> "So in planning, there are 14 medium risks. Here they are showing three high and
> three medium … That means it didn't take this information it should take that
> information."

> "I confirm that I have reviewed this with all the key stakeholders. And we have
> estimated this number as accepted. So that needs to be required for the risk
> assessment section. But this is a required section for sure."

> "for the top risks like say the high [ones] … we're going to require them to
> have either like two to five top risks … those top risks they can then have the
> specific [mitigation] plan for those top risks that can be seen immediately"

> "that is also going to be the cost estimate from the risk perspective. So it is
> like 0.6 percent of the budget and that cost estimate will be put before [the
> risk table]"

> "Did it export and show the whole table … No, it didn't actually. No, it didn't
> show anything."

### 5. Contracting — one strategy per *contract*, not one for the project

> "the contract price is going to be by contract basis … We can't have one story
> for the entire project. It's going to be a contract by contract basis. It's
> going to be based on the scope of work and what's needed at the time."

> "this is a table view which is good but … if you have five contracts you want to
> be able to see your [contracts] … if you put on one you can expand it, you can
> see all the details about it"

> "FEP scope input, that does not make sense to me. So if you have like the
> contract, and the contract name, the scope, the potential value … then you can
> do it there."

> "that table needs to be here. As a default view … This is where they have to go
> through the process of building it out."

> "I think it should be a button where you click on it and it can pop up and it can
> show you where the cycle [is] and you can choose which is going to be where you
> are going to send out the [RFP]"

> "We are going to give two weeks to have this scope out to them. We are going to
> send out the RFP. We are going to give them four weeks to review and respond …
> one week for clarification … two weeks to review the contract and evaluate their
> responses … one week to give us all the documentation … and then we are going to
> award the contract on this date. So that is required for each of the contracts
> here."

> "It is a very small contract and they can elect to keep that and say sole source
> or award or bid award … so they're not forced to go through the [whole process]
> if they don't need to."

> "Can you click on any one of these instead of negotiation? … please just hide it.
> Just hide it fully, don't delete it, just hide it."

> "warranty has to be included in one of those in admin controls where you had
> your legal registration … instead before contract award"

> "this score here does not really make sense to me. You should be inside each of
> them … when you click on this, so we can have a contract, that is where the score
> should be for each of the people that did [bid]."

> "if you already have a list of contractors, they can just import it and utilize
> it"

### 6. Procurement — mirror contracting, and put the log on top

> "if we go up here … my first comment is we have the [start-up] with what we
> already have. So this page is very different from the procurement page in the
> planning … the good news about already doing some work is that you can just
> continue from where you stopped … So that continuity is important for every
> single section"

> "so this water procure I don't understand that. So we need to take that out."

> "the procurement strategies has strategy name, category status, I don't know
> what that is … strategy name, that does not make sense to me"

> "this procurement look to be at the top and it should have like the key items
> that they plan to buy. And that log is what should start [the section]."

> "procured items are really supposed to be like equipment and stuff like that"

> "the overview … could include … a plan [note] section that just gives you the
> spot to put in that information"

> "if you have an overview then you can remove the search [section]"

> "this section is very busy … contracting work is not going to be here"

> "the procurement is similar to contract and I said that it's more buying things.
> So I think they need to try to mirror each other."

### 7. Naming — a table view is a "log"

> "M-L-O-G is all these tables that have like, like this procurement table now and
> can be called a procurement log. The contract table can be called a contract
> log. The issues management table can be called an issues log."

> "all our tables should be numbered"

### 8. Logistics (tail of the recording)

- The owner leaves at 15:30; the walkthrough stops inside Procurement.
- The session continues **tomorrow at 11 AM, or 2 PM** — the owner confirmed
  2 PM ("does 2 p.m work for you guys tomorrow as well?" … "we will try to make
  it work for tomorrow as well").
- Still to walk: the rest of Procurement, then Schedule, Cost, Scope Tracking and
  Change Management.
