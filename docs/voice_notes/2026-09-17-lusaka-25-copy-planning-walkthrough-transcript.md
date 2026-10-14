# Voice Note — Lusaka 25 (copy) / SSHER · Quality · Design walkthrough (2026-09-17)

Source: `assets/assets/images/Lusaka 25 copy.m4a` (~90 min).

This is the long screen-by-screen walkthrough of the **execution/planning sections**
that come after Front-End Planning: Stakeholder Management → Team Management →
SSHER (Safety / Security / Health / Environment / Regulatory) → Quality
Management → Design Planning → Planning Technology → Cost Estimate. It is a
different session from the 25-minute `Lusaka 25.m4a` already archived in
`2026-09-15-lusaka-25-transcript.md`; the file was delivered as
`Lusaka 25 copy.m4a`, so it is filed here as "Lusaka 25 (copy)".

Transcribed locally with whisper.cpp (`ggml-small.en`, English). The audio is a
screen-share recording, so speaker turns are not separable and several
sentences are mangled — the asks below are the passages intelligible enough to
act on. The tail of the recording (last ~40 min of audio) drifts into two
people debugging an admin login and a CodeMagic build off-microphone, plus a
long cross-talk stretch; the product asks are all in the first half.

## Distilled asks

### 1. Stakeholder Management must carry an actual person's name

> "all the way to … I do have to mention here is we need to have an actual name
> of the person"

> "I would say we need to change one of these to be … the contact person"

The owner does not accept an organisation-only row: the table has
organisation / role / contact info / influence / channel / owner, and the
"owner" column's meaning is unclear ("I don't know what the owner is"). One
column must become the **contact person's name**, with organisation kept
separate.

### 2. Stakeholder Management needs a review pop-up

> "there are a few things for you … we put a pop-up that says they need to
> ensure to review it … ensure that it's stakeholder name, organization and
> title is currently reflected — so let's put the work on them to actually do
> it"

### 3. Stakeholder provenance ("carried from preferred solution") must be real

> "where did this specific group … so is it carried from preferred solution?
> … we need to know where this is … you can't just pull out random stuff and
> then that carried-from sentence is just interesting"

The owner could not tell whether the Program Manager / Project Manager entries
were inherited from the Preferred Solution or invented, and asked for the
screening questions to be re-checked against the solution comparison.

### 4. Team Management / RACI role display

> "I don't think that we need to put in those roles, but … you can also show
> who the design leader or engineering leader, manager is on there so they know
> who it is"

Explicitly deprioritised in the same breath — "this is not a very high priority
so can you write this down for us to come back to" — so it is logged, not
scheduled.

### 5. SSHER needs a table view, and the table view must be the **default**

> "is there a table view for this … so we do need a table view so they can view
> everything … they're not always easy to read when there's so many of them"

> "I think we should still remain within the card view, but we should just have
> the table view and the table view needs to be the default"

Reason given: "scrolling down is not always functional". Applies across the
whole SSHER section, not one tab.

### 6. SSHER items must carry their cost, and feed the Cost Estimate

> "what is the cost aspect for these things? … something very basic, like if it
> says PPE required, just have a question on the cost for that"

> "in that share costs, the key aspects of safety, security, health,
> environmental regulatory … you can have them on the table and say cost items
> and then estimated costs … that is how we can put our share costs into the
> cost estimate"

### 7. "AI-Generated" must disappear when AI is off

> "if AI is off, I don't want to see AI generated anything … you shouldn't even
> say AI generated"

> "we are going to have the AI turned off and the options to have the AI turned
> on and be used … can you tie this function to AI being turned on and off?"

The quality plan renders `AI-Generated` in its heading and is produced
automatically without the user asking, which is the concrete instance flagged.

### 8. AI-drafted content must be editable, rejectable, deletable

> "it cannot be edited … we definitely want to start to be editable. If
> something pops up, they should be able to edit it, reject it, delete it. We
> don't want them to be forced with anything"

Also: "by lessons learned retrospect, that is saying the same thing twice … I
want to delete it."

### 9. Quality item pop-ups should suggest quality things to consider

> "from a pop-up perspective, I think we want to give ideas of quality things to
> consider for quality … consider quality items such as requirements, now KPIs"

### 10. Quality plan entries must be traceable and trackable, not typed twice

> "what I'm seeing now is a lot of typing and stuff, which is not bad, but it
> has to be trackable"

> "when you put in that we are going to check this every week … this must tie
> back to the schedule to something to the quality tracking … so whoever is
> responsible for quality from the RACI will get this … or the team will get it
> in the team's to-do list. This has to show up somewhere. You cannot just
> [let it] die here."

Concrete duplication called out: the review cadence typed in the Quality Plan
had to be re-typed in QA/QC Tracking with the responsible person. The owner's
suggested fix: make the tracking table the same object as the plan table so it
is only entered once.

### 11. Quality costs must reach the Cost Estimate

> "we also have to have that cost for quality. So if there's any additional
> stuff like cost to bring in a quality [inspector] … that will need to be
> estimated from a cost perspective"

### 12. One project change log; quality is a discipline, not a second log

> "there should be only one change log for the project … if it's a quality item
> then the discipline will be quality"

> "if it's going to be a lot of work to remove it, you should only pull the
> quality items from the [project log] … if you can't tie this one to that one
> you can just delete it. I don't want to create [extra] work."

Plus a quality **register** holding items, results (pass / fail / performance)
and what is being done to fix them.

### 13. The section "Next" must be gated and correctly labelled

> "that design planning needs to be grayed out. So please take this action for
> every single section that has more than one tab … The next must be grayed out
> and if you try to click on it, you should tell them to finish the flow within
> that section"

> "they might click next and they'll skip everything else here"

Also a label bug: the Design Planning footer says "next technology planning"
because design/technology order was swapped — "I need to swap this next and
make sure that it says the right thing".

### 14. Design Specifications vs Requirements Mapping are two different jobs

> "this specification should look at internal and external regulatory
> specifications, code … I don't think that there shouldn't be any linkage at
> this point … the requirements mapping is when they can mark the specs to the
> linkage"

Specs = codes / standards / regulatory rules that must be met (internal or
external). Mapping codes onto requirements is a separate tab, and picking a
requirement should surface the applicable codes automatically.

### 15. Design Specifications need a table view plus import/export

> "if you have the specs and if you have a table view, with the default view,
> you should also have the ability to import the table … a template where they
> export and then they can import a table"

Columns asked for: the spec, the source of the spec, a link to it. The existing
"attach requirements" picker was also called "not very intuitive" (two states,
none attached vs attached).

### 16. Sidebar/section highlight does not follow the Design Planning sub-pages

> "right now you are in the design specification but … the panel … it just
> stays on the same design overview"

### 17. Architecture Basis ("model 1 / 2 / 3") is not understandable

> "I really do not understand the architecture business … I wasn't sure I was
> understanding that whole model, model two, model three. So are those supposed
> to be the … epics, like what are those?"

Asks: a pop-out/full-screen view ("this should be pop out table") and a way to
sketch — "I thought we were gonna have like a whiteboard".

### 18. Technology inventory cost totals are wrong and must roll up

> "I see here that you have cost 115 … is this a one-time cost is this a
> recurring cost; zero in monthly cost … it doesn't show anywhere here that is
> monthly"

> "this 270 is obviously wrong if you're paying 150 a month"

The requested shape: total per table, subtotal per section, grand total, with
monthly costs totalled over the project duration, and that grand total
surfacing as a **single line item** in the Cost Estimate rather than the
estimate linking each item.

### 19. Cost Estimate: remove the double dashes / double hyphens

> "my comment on those double dashes and double hyphens still remains"

(Repeated from the Lusaka 24 walkthrough — still open.)

### 20. Admin accounts show as "disabled" after the Postgres → Firebase migration

> "it's showing the fact that your account is actually disabled in the admin
> panel"

Diagnosis on the call: accounts were imported into Postgres by the old C# app
without a matching Firebase identity, so the two identity stores disagree and
password reset is the current workaround.

### 21. Desktop distribution is missing / CodeMagic build not updating

> "there is no download for the desktop version … that process is actually
> automated using code magic … if it's not updated, it's just about how it's
> working there"

### 22. Agile projects have no Design work package

> "for agile projects there wouldn't necessarily be a design work package,
> because it's going to be based on epics of features … design is part of the
> iteration anyways"

So the Design Planning work-package section must not be forced on agile
projects.

## What this note changed in code

The asks below are done and verified (`flutter analyze` → 0 errors,
`flutter test` → **731 passed**). Everything not in this table is accounted for
in "Still open" further down — nothing is silently dropped.

| Ask | Where it lives now | Test |
|---|---|---|
| 7 — there is now one AI on/off switch instead of a per-call-site flag | `ProjectData.aiEnabled` (`lib/models/project_data_model.dart`), toggled by the `AI` switch in the Quality plan card header (`_QualityTabScaffold._setAiEnabled`) | `test/ai_switch_gates_ai_content_test.dart` |
| 7 — "(AI-Generated)" only shows while AI is on *and* AI wrote the text | `_QualityTabScaffold` heading reads `_aiEnabled && _planIsAiGenerated(q)`; `QualityManagementData.aiGeneratedPlans` records which category AI produced | `test/ai_switch_gates_ai_content_test.dart` |
| 7 — with AI off nothing is invented: no auto-generation, no Regenerate, no assistant insights | `_ensurePlanGenerated` / `_regeneratePlan` return early; the insights card and the Regenerate button are gated on `_aiEnabled` | — (screen-level) |
| 8 — the AI narrative is editable, rejectable and deletable | the `SelectableText` became a `VoiceTextField` owned by the screen (debounced write-back); a `Delete` action clears it. Both drop the AI marker, because the text is no longer AI's | — (screen-level; the marker logic it depends on is covered above) |
| 5 — SSHER ships a table view, and the table is the default | `ssher_stacked_screen.dart` gained `_SsherViewMode` (default `table`) plus a table/card toggle in the section header and a `_buildEntriesTable` (Department, Team member, Item, Risk, Est. cost, actions). Cards stay one tap away for the mitigation narrative | — (screen-level) |
| 1 + 2 — the register flags rows with no person, and asks the user to confirm name / organization / title before leaving | `lib/utils/stakeholder_review.dart` (pure, tested) finds the rows a person could actually be contacted on; `stakeholder_management_screen.dart` shows a **Review the stakeholder details** prompt naming them, wired into *both* Next affordances (the header arrow and the footer button) so neither can bypass it. It is a prompt rather than a block — the owner asked to "put the work on them", not to lock the section | `test/utils/stakeholder_review_test.dart` |
| 13 — a multi-tab section's `Next` is gated until its tabs have been shown | `lib/utils/section_flow_gate.dart` (pure, tested) declares the multi-tab sections and their tabs; `quality_management_screen.dart` records the tabs it has shown in `QualityManagementData.visitedSections` and greys its `Next` out with an inline “Still to review: …” notice; `planning_technology_screen.dart` gates both its footer Next and the header forward arrow. SSHER already had this exact behaviour (`_allTabsVisited` + the stakeholder-confirmation gate), which is why the owner's comment applied to the other sections | `test/utils/section_flow_gate_test.dart` |
| 6 — a SSHER item can state what it costs, and that cost reaches the estimate | `SsherEntry.requiresPurchase` + `SsherEntry.estimatedCost`; the add/edit dialog asks the question (“Requires a purchase (adds a cost to the estimate)”) with a required amount when ticked; unpriced purchases show **Needs a price** instead of `0`. Selection lives in the pure, tested `ssher_cost_lines.dart`; `CostEstimateProvider.pullSsherCostLines` writes `CostCategory.ssher` lines; the Cost Dashboard gained an **SSHER Costs** pull card | `test/cost_estimate/ssher_cost_lines_test.dart` |
| 9 — quality pop-ups suggest what to consider | a `_QualityConsiderHint` sits at the top of the objective dialog, listing acceptance criteria, a measurable KPI, test coverage, a code to satisfy, review cadence and a customer target — so a quality item is prompted for rather than invented | — (screen-level) |
| 16 — the sidebar highlight follows the Design Planning sub-pages | `lib/utils/sidebar_label_match.dart` (pure, tested) adds the missing rule: a `"<section> - <sub-page>"` active label highlights its parent section when no more specific item exists. `initiation_like_sidebar.dart` now uses it for both the item highlight and group expansion, so every section using that convention is fixed, not just Design Planning | `test/utils/sidebar_label_match_test.dart` |
| 18 — technology cost totals are per table, subtotalled, and projected over the project | `lib/utils/technology_cost_rollup.dart` (pure, tested) fixes the parsing bug behind the wrong number — the old code took the *first* number in a string, so `"3 licences @ $150/month"` summed as 3 — and produces a total per table, a recurring-per-month figure and a grand total over the project's months. The dashboard card headline now shows the genuine grand total instead of the one-time sum, and the duration it used is stated on the card | `test/utils/technology_cost_rollup_test.dart` |
| 19 — doubled dash separators in cost descriptors | `lib/cost_estimate/utils/cost_descriptor_text.dart` (pure, tested) collapses a run of two or more dash characters into one em dash and normalises on display in the builder's line row and the variance table. Deliberately narrow: a single hyphen is untouched, so `WP-04` and `Level 1 - Project Schedule` survive | `test/cost_estimate/cost_descriptor_text_test.dart` |
| 11 — quality costs reach the Cost Estimate | **The blocker is cleared.** `ProjectDataModel.costOfQualityData` is ported from `origin/comments` (field, constructor, copyWith, toJson, fromJson), so `lib/models/cost_of_quality.dart` and `lib/services/cost_of_quality_service.dart` are removed from the `analysis_options.yaml` exclude list and analysed with the rest of the app. A **Cost of Quality** tab captures prevention / appraisal / internal-failure / external-failure entries with estimate and actual amounts; `lib/cost_estimate/utils/quality_cost_lines.dart` (pure, tested) selects the priced ones — actual beating estimate — and `CostEstimateProvider.pullQualityCostLines` writes `CostCategory.quality` lines, surfaced by a **Cost of Quality** pull card on the Cost Dashboard | `test/cost_estimate/quality_cost_lines_test.dart` |
| 3 — stakeholder provenance is recorded, not assumed | `lib/utils/stakeholder_provenance.dart` (pure, tested). The carry used to fall back to `solutions.first` silently when the preferred solution's title did not match, so a row taken off a different candidate read exactly like one that came from the chosen solution. The fallback is kept — showing the candidates' stakeholders beats showing nothing — but the note on each row now names the solution it actually came from and says when that is *not* the preferred one | `test/utils/stakeholder_provenance_test.dart` |
| 17 — Architecture Basis is explained, and the rows have a pop-out table | `lib/utils/architecture_module_labels.dart` (pure, tested) names the rows `"Module 2 — Payments service"` instead of a bare ordinal — the label used to hide the name the user had typed — and flags unnamed rows. An explainer above the rows says what a module is and that the numbers are not a ranking, and an **Open module table** button pops the rows out as one table (Module, Purpose, Owner, Status) | `test/utils/architecture_module_labels_test.dart` |
| 14 — Design Specifications and Requirements Mapping are stated as different jobs | the Requirements Mapping section is now subtitled as the *link* between a planning requirement and the specification that satisfies it, and points at the Design Specifications section as where specifications are written | — (copy-level; the two are already separate sections) |
| 15 — Design Specifications table view is the default, with import **and** export | a `Table / Cards` toggle defaults to **Table** (`_SpecViewMode`), showing every row together with an **Edit as cards** affordance, and the full-screening table dialog is still available. `CsvImportHelper.exportRows` (pure, tested) writes the same columns the importer accepts, so export → edit in a spreadsheet → import round-trips; the import button and the export action share one column set | `test/utils/csv_import_helper_export_test.dart` |
| 13 — Design Planning's `Next` is gated on its 15 guided sections | the `design` flow is declared in `section_flow_gate.dart` with the ids from `_sectionOrder`, and `design_planning_screen.dart` holds `Next` (greyed, not hidden) until every section is Complete or Not applicable, naming the outstanding ones inline and in the snackbar | `test/utils/section_flow_gate_test.dart` |

### Two runtime crashes the Cost of Quality screen test caught

Both were introduced by earlier work in this note and were invisible to
`flutter analyze`, because they are Flutter **runtime** assertions, not type
errors. They only surfaced once a widget test actually built the Quality screen:

1. **`minLines can't be greater than maxLines`.** The editable AI narrative (ask
   8) was given `minLines: 6`, but `VoiceTextField.maxLines` defaults to `1`, so
   the Quality plan tab asserted on every render. Fixed with `maxLines: null`,
   which also lets a long narrative grow instead of being clipped.
2. **`Competing ParentDataWidgets`.** The gated footer's `OutlinedButton.icon`
   and `FilledButton.icon` each wrapped their label in a `Flexible` — but `*.icon`
   buttons already put the label inside one, so two `Flexible`s fought over the
   same render object. The inner `Flexible`s are gone; the `FittedBox` stays.

the gate's tab ids and what the screen records were also out of step for
Quality: the screen recorded the AI *category* keys (`objectives`, `inspection`,
`audit`) while the gate looked for `targets`, `qaTracking`, `qcTracking`, so the
gate could never open and Quality's `Next` was locked for good. Both sides now
use the `_QualityTab` enum name, and the Cost of Quality tab was added to the
flow. The screen tests below drive the real screens, which is how all three were
found.

| Ask | Where it lives now | Test |
|---|---|---|
| 11 — the capture side, end to end | opening the **Cost of Quality** tab, adding an entry through the real dialog, and checking what lands on the project — including that the category is remembered and an unpriced entry is flagged rather than carried as a zero | `test/screens/quality_cost_of_quality_tab_test.dart` |
| 11 — the pull side, end to end | the real Cost Dashboard, the real provider, the real pull: four categories selected and totalled, an unpriced entry reported as waiting, the actual winning over the estimate, and idempotency | `test/cost_estimate/quality_cost_card_e2e_test.dart` |

## Blocker found while implementing asks 11 and 12 — now cleared for 11

The Cost of Quality data and the quality intelligence services **already existed
in the tree but were inert**. `analysis_options.yaml` listed them under
"Alick's new modules (ported from `comments` branch)" and excluded them from
analysis, with the reason spelled out:

> These are self-contained new modules whose models/services reference fields
> (`costOfQualityData`, `customKpis`, `methodology`, `RiskRegisterItem.id`,
> `QualityChangeEntry.changeDate`, `QualityTarget.category`,
> `QualityObjective.area`) that exist on Alick's branch but are not yet present
> on staging's versions … They are inert (no callers in the active app) until the
> dependent model fields are also ported.

Concretely: `lib/models/cost_of_quality.dart` and
`lib/services/cost_of_quality_service.dart` define the Prevention / Appraisal /
Internal-failure / External-failure cost capture the owner is asking for, but
`ProjectDataModel` has no `costOfQualityData` field on this branch, so nothing
can store it and no screen can read it. `flutter analyze` on
`cost_of_quality_service.dart` alone reports `undefined_getter` for that reason
(the whole-project run skips the file because of the exclude entry).

**Ask 11 was blocked on a port, not on new UI.** The declared path is the one the
config already documents: port the model fields from `origin/comments`, then
remove the file from that exclude list. Doing it the other way round would have
created a second, divergent definition of the same concept.

That port is now done for `costOfQualityData`: the field, its constructor
parameter, its `copyWith` branch, its `toJson` entry and its `fromJson` parse
were taken from `origin/comments`, and `cost_of_quality.dart` plus
`cost_of_quality_service.dart` were removed from the exclude list. Both analyse
clean alongside the rest of the app, and ask 11 is implemented end to end (see
the table above).

**Ask 12 still needs more of the same port.** The register the owner describes
references `QualityChangeEntry.changeDate` and `QualityTarget.category`, which
are still missing here; and the "one change log" half is a product decision about
whether the project change log becomes the only log or quality is mirrored into
it. That is why 12 is listed under "Still open" rather than half-built.

## Still open from this note

1. **Ask 10 — quality traceability.** Tying the plan's cadence to schedule
   prompts, the QA/QC tracking tables and RACI-owner alerts, so the same thing is
   not typed twice. This is the largest item in the note and the only one that
   is genuinely cross-module (Quality → Schedule → Cost): it needs the plan's
   cadence fields, the QA/QC tables and the RACI matrix read together, and
   alerts that fire on the same owner. Not started.
2. **Ask 12 — one project change log carrying quality as a discipline, plus a
   quality register with pass/fail and corrective action.** The quality half of
   the blocker is cleared (see ask 11 above), but the register the owner wants is
   distinct from the existing NCR log: it needs `QualityChangeEntry.changeDate`
   and `QualityTarget.category` ported from `origin/comments` as well, and a
   decision on whether the project change log becomes the single log or mirrors
   quality into it. Not started.
3. **Ask 4 — RACI design/engineering lead.** The owner explicitly deprioritised
   this in the recording ("not a very high priority"), so it was left alone.
4. **Ask 20 + 21 — admin identity migration and desktop/CodeMagic builds.**
   Infrastructure rather than app code: the Postgres → Firebase identity
   migration for admin accounts, and the missing desktop distribution / stale
   CodeMagic build. Neither can be verified from this tree.
5. **Ask 1 — the ambiguous `Owner` column.** The review prompt and the
   missing-person detection are done. The outstanding decision is what the
   register's `Owner` column means — the owner said plainly "I don't know what
   the owner is" — which either needs renaming to whatever the team means by it,
   or merging into the contact person's name. A product decision, not a code one.
6. **Ask 17 — the architecture whiteboard.** The explainer, the readable row
   names and the pop-out table are done. The whiteboard the owner also asked for
   is not: it is a canvas feature (placeable, connectable blocks persisted in the
   design planning document), and it is a design decision in its own right rather
   than a fix to the numbering that made the section unintelligible.
7. **Ask 19 — the surface.** The doubling is fixed wherever a cost descriptor is
   displayed. The recording only says "can you go back to the cost descriptors"
   while the screen being shared was the **stakeholder** table, so if the owner
   was looking at a stakeholder descriptor rather than a cost one, that surface
   still needs the same treatment — `costDescriptorForDisplay` is ready to be
   pointed at it.

## Raw transcript (verbatim highlights)

Kept as the intelligible passages only; the source audio is a screen-share, so
several lines are not speech and the repeated fragments are whisper artefacts.

```
so all the way to i do have to mention here is we need to have an actual name of the person
so you write role title and then organization contact information channel owner so my key comment here is so i don't know what the owner is
i would say we need to change one of these to be a ... we need to change it to be that to take one of one of those to have the name like the contact person
so for our for this stakeholder we need to put a pop-up that says review ensure that it's stakeholder name organization and title is is currently reflected so let's put the work on them to actually do it okay
so i don't think that's the case i do not see any program project manager then so i was thinking maybe it was the project manager from the rules and responsibilities so we need to know where this is the comment from
so we do need a table view so they can view everything you want and make the screen because they're not always easy to read when there's so many of them
i think we should still remain within the card view but we should just have the table view and the table view needs to be the default
and this goes across for the whole share
now i guess my key question now is did we add any like what is the cost aspect for these things
something very basic like if it says PPE required just have a question on the cost for that and they can look at what what I think that might cost
in that share costs the key aspects of safety security health environmental regulatory you can have them on the table and say costs like items and then cost is estimated costs
that is how we can put our share costs into the cost estimate
all right can you please take care of this so if you don't have AI we should have any AI generated
so when we so if AI is off i don't want to see AI generated anything
and also it cannot be edited so can you make this can you tie this function to AI being turned on and off
and he asked you have you figured out how we can turn on AI for the site and turn it off
so we definitely want to start to be editable if something pops up they should be able to edit it reject it delete it we don't want them to be forced with anything
so can you maybe like look at what this one already has and for the pop-up say consider quality items such as requirements now KPIs
so what i would say is that the one that did this work and great job going through the process
all right so what i needed to do is maybe you can then give that direction is maybe this table needs to be in that plan section right so that way you're not doing it twice
but you want to make sure that when you put in that we are going to check this every week that is somewhere
this must tie back to the schedule to something to the quality tracking and make sure that it's being tracked
so whoever is responsible for quality from the RACI will get this or the product manager will get it or the team will get it in the teams to do list this has to show up somewhere you cannot just die here
so the reason but you know this quality change change log here can just be quality change items ... so you should only pull the quality items from the approach so you wouldn't be a whole different changeload
if you can't tie this one to that one you can just delete it i don't want to create that from work thank you
so to me quality is not done does that make sense ... so quality and share definitely need to be updated
all right so it said design planning in the next button this is another one that's keep something so private
please take this action for every single section that has more than one tab that you need to get to the next must be grayed out and if you try to click on it you should tell them to finish the flow within that section
they really might not know so they might click next and they'll skip everything else here does that make sense
this is design planning and i guess technology was full default of design this is what happened so i think originally design was in front of technology so that wasn't changed
i need to swap this next and make sure that it says the right thing
this specification should look at internal and external regulatory specifications code and developing requirements ... code and specs that need to be met by the project is what needs to be in this specification
i don't think that there shouldn't be any linkage at this point it's the requirement mapping is when they can mark the specs to the linkage
so if you have the specs and if you have a table view with the default view you should also have the ability to import the table so they can have a template where they export and then they can import a table
the table should have like the spec the source of the spec the link to it
right now you are in the design specification but the but the thing is still saying design overview the what oh the panel yeah that's that's really was truly all the way so as you keep going down it just stays on the same design design overview
so i really do not understand the architecture business right ... this architecture i wasn't sure i was understanding that whole model model two model three
so are those supposed to be the good ones like the epics like what are those ... i thought we were gonna have like a whiteboard where are the whiteboard shows
so this should be pop out table it's a lot of like this is enough for me to look at it just isn't
so i see here that you have cost 115 um is this a one-time cost is this a recurring cost zero in monthly cost okay so it doesn't show anywhere here that is monthly
and for the cost estimate it needs to show the total cost so i think provided to add something around total cost
so the total is coming up on there and then the annual cost is in 240 per year but that's not the case but we know what is really 150 per month so the total cost is wrong
so this needs to be updated to actually make it quite feasible like it has to make sense
if the total is going to take the total of everything in that total that you go to the cost estimate they don't need to come and link to all of these ones
but make sure that the total cost makes sense which means if it's monthly cost then have it total for the duration of the project
this 270 is obviously wrong if you're playing 150 a month
my comment on those double dashes and double hyphens still remains i know we talked about this a while ago
it says the bridge up requires so the issue is that the bridge up has has actually completely separate identity stores
some of them were just imported records without having the actual accounts ... they were in Postgres and then they had moved over all the accounts without them having their accounts created
oh but there is no download for the desktop version ... that process it's actually automated using code magic i just need to rectify a few things
for agile it's a bit different you won't have a desirable package ... it's going to be epic speech of the story
so the design is going to be part of the iteration anyways you don't finish this design and then do something design is part of the work
```
