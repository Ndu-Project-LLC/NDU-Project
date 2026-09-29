# Lusaka 27 — extracted todo items (2026-09-28 recording)

> Source: `Lusaka 27.m4a` (repo root, ~88 min). Full walkthrough transcript with
> the transcription-caveat vocabulary table:
> `docs/voice_notes/2026-09-28-lusaka-27-planning-review-transcript.md`.
> Implementation detail per landed item:
> `docs/plans/2026-09-28-lusaka-27-planning-review-fixes.md` (Tasks 1–9 + the
> RACI follow-up all report DONE; re-verified against the code 2026-09-29).

## Landed (verify in the next walkthrough, do not rebuild)

- [ ] **Kanban Configuration** — compact add-column control, section description
  kept under the header, board embedded as a ~320 px preview with
  **Open full board** (fixes plan Task 9).
- [ ] **Interface Management** — add-interface bug fixed; **Status Dashboard is
  the first tab and the screen opens on it** (fixes plan Task 8).
- [ ] **Interface RACI & Governance** — provenance card + legend + coverage
  chips; R/A/C/I read from Party A / Owner / Party B / `Not set` (RACI
  follow-up).
- [ ] **Execution Plan dedup** — Execution Issue Management, Execution Lessons
  Learned and Execution Stakeholder Identification are out of the flow;
  project-wide sections remain (fixes plan Task 1).
- [ ] **Delivery-model gating** — Agile projects get no Execution Plan; Waterfall
  projects get no Agile Delivery flow; Hybrid/unset keep both (fixes plan
  Task 2).
- [ ] **Risk Assessment (Planning)** — opens on the FEP risk log table (same
  columns/rows, card view as the toggle, expand-to-full-screen), matrix/counts
  derived from the same rows, top-risks card on top, 0.6 % risk allowance,
  sign-off gate on Next, export prints the table (fixes plan Tasks 3–4).
- [ ] **Contracting** — Contract Log as the default tab view (numbered,
  expandable), per-contract strategy/type, per-contract RFP cycle popup
  (2 wk scope-out → 4 wk respond → 1 wk clarify → 2 wk evaluate → 1 wk docs →
  award), skip-cycle with reason (Sole Source / Direct Award / …), warranty +
  key dates before award, Negotiation tab hidden not deleted, Add from FEP +
  contractor import, export prints the log (fixes plan Task 5).
- [ ] **Procurement (FEP + Planning)** — Procurement Log table after the
  overview, long-lead flag on items, overview dashboard with status counts,
  plan note in the overview, strategies table / "what to procure" / contract
  scope block / dead search removed (hidden behind a flag), export prints the
  log (fixes plan Task 6).
- [ ] **One log vocabulary** — Risk Log / Contract Log / Procurement Log / Issue
  Log, every log numbered `#` first, all expandable to full screen, all exports
  print their table (fixes plan Task 7).

## Open work items (from the recording, not yet built)

1. **Agile Metrics & Reporting → dashboard, not a top-level sidebar section.**
   The owner opened the Agile Delivery Model area and found "Metrics &
   Reporting" as its own sidebar entry directly under Agile Delivery Model.
   Quote: *"last time we used to have metrics and reporting here. We had
   discussed that like it should be taken out, it should be moved preferably on
   a sidebar as an option … I'm pretty sure I talked about it quite a few times
   and I think you have taken it and put it right at the top. That was never the
   discussion … I think it's part of the Agile metrics planning and I think
   it's supposed to be turned into a dashboard, Agile dashboard or something to
   that effect."*
   **TODO:** confirm against the session notes he asked the team to check
   (*"can check the notes and confirm so that we are not coming back to this
   again"*), then turn the Metrics & Reporting section into the Agile dashboard
   (an `AgileDashboardScreen` already exists in the code and is linked from the
   Agile Project Hub) and remove the standalone sidebar entry under Agile
   Delivery Model. He also asked to re-check **what pages come up next / the
   screen-navigator ordering** in that section (*"I could choose what pages are
   coming up next"*).
2. **RFP package download/email.** On the Tender Setup tab the owner wants the
   RFP package (scope, mapped requirements + codes/standards, technical docs,
   description of work) downloadable so it *"could be downloaded where you can
   download it and send it out to the folks. You could just email from here …
   this is the RFP, this is all the details, this is all the code and
   technology it has to meet."* Easiest-possible-path framing: generate the
   package document from the contract's linked scope/requirements and offer
   save + share/email.
3. **Procurement: a limited procurement cycle.** *"It might not really have
   that whole cycle thing, but it might have like a limited cycle — like we
   will identify a few … items, and we will get their quotes, and then we will
   buy it."* Add a light per-item (or per-log) procurement cycle — identify →
   quote → purchase/award — mirroring contracting's shape but smaller. Contract
   has `ContractRfpCycle`; procurement has none today.
4. **Procurement continuity with FEP/Startup.** *"This page is very different
   from the procurement page in the planning … the good news about already
   doing some work is that you can just continue from where you stopped … that
   continuity is important for every single section."* The planning procurement
   screen is still a separate page from FEP procurement (shared log view, not
   one page). Either converge them or make the planning page visibly continue
   FEP's log/status.
5. **Risk log: cost + schedule impact columns.** The owner expects
   *"the potential cost impact with the schedule impact … the possible
   probability and the possible overall impact … all done on the table."*
   `RiskRegisterItem` already carries `costImpactMostLikely` /
   `scheduleImpactMostLikely` (and min/max), but nothing writes or reads them,
   so the columns were left out rather than shipped empty (flagged deviation in
   fixes plan Task 3). Decide: add the inputs to the FEP risk sheet and the two
   columns to `riskLogColumns`, or confirm they stay out.
6. **Risk sign-off: confirm the "estimated/accepted" reading.** Implemented the
   required sentence *"I confirm that I have reviewed this with all the key
   stakeholders"* plus date/cadence; *"we have estimated this number as
   accepted"* was treated as covered by the sentence, not a separate numeric
   acceptance field. Confirm with the owner (fixes plan Task 4 deviations).
7. **Risk cadence: confirm the inference.** The required review-cadence field
   (Monthly/Quarterly/Semi-annual/Annual) was an inference; the recording only
   says the review happened. Drop it if the owner disagrees (fixes plan
   Task 4 deviations).
8. **Contracting: overview showing every contract + status.** *"It shows you
   like the total contract by each one, the status … if you attach this to the
   overview, again, it might be blank to start off with, but as this section is
   filled out, it should be reflecting in real time in the overview."* The
   strategy card lists contracts, but confirm the overview status readback is
   what he meant (worth a walkthrough check, fixes plan Task 5 deviations note
   on evaluation scores).
9. **Confirm Evaluation tab reads per contract.** Code already scores bidders
   inside each contract; the owner was likely looking at the section-wide
   summary card. Confirm on the next walkthrough (fixes plan Task 5
   deviation).
10. **Contracting Workflow tab on the procurement page.** *"This section is
    very busy … contracting work is not going to be here"* — the contract-scope
    block was removed, but the **Contracting Workflow tab** itself was left
    because it is part of required-section validation/Next flow. Confirm
    whether the tab should go (fixes plan Task 6 open question).
11. **Legacy procurement sections: bring back or delete.** Strategies table /
    "what to procure" / duplicate item list are behind
    `_showLegacyProcurementSections = false`. Decide re-home vs delete (fixes
    plan Task 6/7).
12. **Planning risk screen: drop the local register block?** The Planning Risk
    screen still keeps its own Add Risk/Filter/CSV register below the carried
    FEP log. Once the owner confirms the carried log is the only table, delete
    that block and make the screen single-source (fixes plan Task 3).
13. **Backlog demo data.** For the demo the owner wants the backlog testable
    end-to-end: *"if you're going to demonstrate this … build us stories there,
    some story points and stuff like that. And then all the features … so that
    way we can test the schedule … it should meet the milestones and the
    timeline."* Seed/complete Stories & Backlog with stories + story points
    linked to features/epics so schedule/cost have something to drive.
14. **Requirements → codes/standards carry-through.** Repeated emphasis:
    requirements mapped to codes/standards in Design Planning must feed
    contracts, the execution plan and WBS-linked work — *"everything mapped to
    it … this is the code and the certification attached to this requirement."*
    Verify the RFP/contract views actually surface the mapped codes/standards
    (overlaps with item 2).
15. **WBS tie-in for contract work.** *"From the state contract, you need to
    pull out all the requirements for that contract, for that scope that sits
    under the WBS."* Verify each contract's scope resolves to a WBS element and
    inherits its requirements/codes links.

## Confirmations to raise with the owner (no code yet)

- Agile Metrics & Reporting: was the agreement "move under the Agile dashboard",
  and should the standalone sidebar entry disappear entirely? (item 1)
- HYBRID projects: current gate keeps both Execution Plan and Agile Delivery —
  confirm that is the intent (fixes plan Task 2 note).
- Whether the risk log should capture cost/schedule impact (item 5) and the
  cadence field (item 7).
- Governance/RACI tab: he parked it ("I don't want to spend [time] … it's
  taken us a while to get through") — the provenance work landed, but he has
  not re-reviewed it.

## Next session (from the tail of the recording)

- Continues **tomorrow at 2 PM PST** (owner confirmed 2 PM; "I'm definitely
  available at 11 tomorrow" was about the earlier offer — 2 PM is the slot).
- Agenda he set when leaving (mid-Procurement): finish **Procurement**, then
  **Schedule, Cost, Scope Tracking, Change Management** — *"I want to get to
  the scope tracking and the change management."*
- He left at 15:30 local; expect the same hard stop style.

## Context worth keeping (said once, applies broadly)

- **Continuity is the site's premise:** every later phase continues earlier
  work; nothing should look like a first visit (*"the good news about already
  doing some work is that you can just continue from where you stopped"*).
- **Tables are logs, cards are the toggle:** table view default, numbered,
  expandable full-screen; card view is the optional alternative.
- **Expandable everything:** the expand-to-full-screen rule applies site-wide
  (*"the same comment I have with this entire site is to be expandable"*).
- **Plan notes belong in overviews:** every overview (planning phase) should
  carry a short plan text box at the top — stated for procurement/contracts,
  phrased as a general expectation.
- **Nothing new at review time:** *"at this point, we're not really creating,
  we're gonna be adding to stuff, but what already has been created has to be
  the starting point."*
