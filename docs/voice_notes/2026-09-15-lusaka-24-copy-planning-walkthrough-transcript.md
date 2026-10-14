# Voice Note — Lusaka 24 (copy) / planning-phase walkthrough (2026-09-15)

Source: `assets/assets/images/Lusaka 24 copy.m4a` (~36 min).

This is the long walkthrough of the **planning phase**, screen by screen:
Charter → Business Case → Preferred Solution → Project Details → WBS → Rules
& Staffing. It is a different session from the 5-minute Lusaka 24 wrap-up that
is already archived in `2026-09-15-lusaka-24-transcript.md`; the file was
delivered under the name `Lusaka 24 copy.m4a`, so it is filed here as
"Lusaka 24 (copy)".

Transcribed locally with whisper.cpp (`ggml-small.en`, English). The audio is a
screen-share recording, so speaker turns are not separable and several
sentences are mangled — the quotes below are the passages that are intelligible
enough to act on. Anything uncertain is marked.

## Distilled asks

### 1. Exports/downloads on every section, starting with the Charter

> "can you make sure that not just for the charter but for everywhere across
> the site where we need to export … make downloads for everything on the site,
> not just the charter, starting with the charter but everything else, the
> other section"

### 2. Charter roadmap/charter view must read left → right with its dates

> "so what we had discussed for this … it was to make it go long ways, like
> project milestones, and it should go … better if it goes from left to right
> … if it has the dates or whatever it is at each point"

### 3. Preferred Solution Analysis must come *before* Preferred Solution selection

Repeated ask, ~15th time per the owner:

> "the preferred solution analysis comes before the preferred solution
> selection"
>
> "these two views [side-by-side compare and the full detail view] should be in
> that preferred solution analysis … they should be able to select one … then
> they go to the preferred solution which is that one that they've selected
> … and then you go to the front end planning that just pulls up just from that
> preferred solution"

Flow wanted: analyse all three side by side → select one (two-step approval,
with an email-approval path when the wrong person is signed in) → the
Preferred Solution page carries only the selected solution plus its
justification → Front-End Planning pulls from it.

### 4. Traceability of the Project Details objectives

> "I really want to know what it's sitting with … if you took any word for word
> [from the project description] … I have to understand that"

Asked the team to write down where each objective came from (project
description vs Preferred Solution) rather than guess.

### 5. Project Details: rename "Project Goals" → "Project Objectives"

> "I think this is going to make this easier, just change that product goals
> for the project objectives and we don't have to worry about it"

Tied to the WBS ask below: the objectives entered in Planning → Project Details
are meant to become the Level 1 epics.

### 6. WBS: objectives must auto-fill the epics (agile) / be the breakdown basis (waterfall)

> "where are they going to go … so they're supposed to come under the nodes
> … those goals are becoming epics … they are supposed to auto fill, but
> [it's] almost there"

Next step requested: do a **waterfall** project too, because waterfall must let
you break down by scope / location / deliverable / discipline.

### 7. Pop-out / full-screen for the cramped tables

> "this whole place is supposed to be for the goal, so this is supposed to be a
> full window … make this table bigger, make it wider or like longer … and then
> also make it pop up. I think everything should pop up everywhere — you pop it
> up and it fills the screen"
>
> "so this is where I've said we need a pop-out button because there's no way"

Flagged screens: the goal/objective breakdown table (WBS goals), the project
requirements table, and the milestone/allowance tables. The complaint is that
the table is squeezed while everything around it wastes space.

### 8. Requirements import must append, never delete

> "if you import another [template] and you just pass on to the person … from a
> code level we have to make sure that everything there still remains there,
> and then if we import additional, add to the bottom of it"
>
> "if you want to delete stuff you can select all and delete, that's different,
> but I don't want work getting deleted because somebody added a new
> [requirement]"

Also: a **pop-up offering "download template and re-import"** so an importer
knows the format before they upload.

### 9. Basic spell check / typo formatting in text fields

> "are we using the regular, out of the box spell check … just like you get in
> Microsoft Word … you're not gonna have AI always … it's not very high
> priority but please put it on your list"

### 10. Staffing plan notes must be editable (not minimizable)

> "maybe these notes … it is not minimizable — the whole premise of this note
> is for them to be able to type in notes"

## What this note changed in code

| Ask | Where it lives now | Test |
|---|---|---|
| 5 — Project Details says **Project Objectives** | `project_framework_screen.dart` — the goals section header, the "missing field" label and the block-proceed message | `flutter analyze` clean; no test file existed for that string |
| 8 — imports append, AI generation appends | `front_end_planning_requirements_screen.dart` `_generateRequirementsFromContext` now de-dupes against what is on the page and appends below it instead of `_replaceRowsSafely(...)`; the dialog copy says so | — (screen-level; covered by the existing requirement screens' tests) |
| 8 — template pop-up / definitions | see Lusaka 25 — the shared template now carries a `Definitions` sheet and row numbering | `test/utils/table_template_definitions_test.dart` |

## Still open from this note

1. **Ask 3 — Preferred Solution ordering.** `preferred_solution_analysis_screen.dart`
   must own the side-by-side compare *and* the selection + approval, and
   `preferred_solution` must render the selected one afterwards. This is a flow
   re-order across routing, not a copy change, so it is queued rather than done.
2. **Ask 6 — objectives → epics auto-fill**, plus the waterfall breakdown
   (scope / location / deliverable / discipline).
3. **Ask 7 — pop-out adoption.** The primitives already exist
   (`buildNduTableWithExpand`, `ExpandableDataTable`,
   `ResponsiveDataTableWrapper` in `lib/widgets/`); the flagged tables are
   custom-built and need to be moved onto them one screen at a time.
4. **Ask 1 — exports everywhere.** Charter first, then the rest of the sections.
5. **Ask 4 — traceability note** for the Project Details objectives.
6. **Ask 9 — spell check** (owner marked it low priority but "on the list").
7. **Ask 10 — staffing plan notes** editable / not minimizable.

## Raw transcript (verbatim)

Kept verbatim, including whisper artefacts (repeated fragments and
mis-segmented turns) — the audio is a screen-share, so several lines are not
speech.

```
to import so so or if they import a template and it doesn't mean they require maybe have a pop-up
say download template and re-import so did you get everything i said
yes i'm following all right
this is the course of something that is engaged we hear
...
can you make sure that not just for their charter
but for everywhere across the site where we need to export cds
so can you make make downloads for everything on the site not just the charter starting with the
charter but everything else the other section okay all right thank you jingo
...
so we came to the planning phase um did it have the information here or did you have to put in
information by yourself you know so it had the information i just had to choose the framework
...
the preferred solution analysis comes before the preferred solution selection so i really hope that
change has been made because i've said it so many times
...
so i think this is going to make this easier just change that product
goals for the project objectives
...
those goals are becoming epic ... they are supposed to auto fill but if it's the waterfall project
...
so this is where i've said we need a pop-out button because there's no way
...
so from a code level we have to make sure that everything there still remains there and then if we
import additional ... add to the bottom of it
...
are we using the regular like of the box spell spell check and formatting for text is that
functionality in here uh to actually avoid typos
```

(The full whisper output for this recording is 286 lines; the passages quoted
above are the intelligible asks. The remainder is the presenter walking through
screens — WBS node creation, the rules list, rates coming from Team Management,
and the staffing plan — without a new instruction in it.)
