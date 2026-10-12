# Voice Note — Lusaka 15 / Goals & Milestones + Requirements + Design Planning review (2026-10-08)

Source: the attached export (`Lusaka 15.m4a` / `Lusaka 15 2.m4a`). The original
Voice Memos recording is `20261008 214623.m4a` (23,095,226 bytes, ~44.7 min) in
`~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/`.
The attachment's Voice Memos temp copies (`…/itemprovider.temporary.*/Lusaka 15*.m4a`)
were cleaned up before they could be read; both shared names resolve to the
same underlying recording in the Voice Memos database (`CloudRecordings.db`,
rows 39 = "Lusaka 15" and 40 = "Lusaka 15 2", both → `20261008 214623.m4a`).

Transcribed **locally** with `whisper-cli` (whisper.cpp `ggml-small.en`),
~2.8 min. Regenerate with:

```bash
ffmpeg -y -i "20261008 214623.m4a" -ac 1 -ar 16000 -c:a pcm_s16le /tmp/lusaka15.wav
whisper-cli -m "$HOME/.cache/whisper.cpp/ggml-small.en.bin" \
  -f /tmp/lusaka15.wav -otxt -osrt -of tool-results/lusaka-15-transcript \
  -t 8 -pp --language en
```

**Transcription caveat.** This is a screen-share, so speaker turns are not
separable and the model reliably mis-hears the project's vocabulary. Read the
quotes with these substitutions in mind:

| Whisper wrote | Means |
| --- | --- |
| "ethics" / "ethic" | **epics** / **epic** |
| "master's" / "mouse stones" | **milestones** |
| "WBF / VVS / BBL / VPS / one way down structure" | **WBS** (work breakdown structure) |
| "code standards" / "code standard" | **codes / standards** |
| "specificions" | **specifications** |
| "racing matrix" | **RACI matrix** |
| "decision phase" | **design phase** |
| "the checker being locked" | **the charter lock** |
| "reviews" | **requirements** |
| "Jungkook" / "Jungle Pharma" | the developer being addressed |
| "local produce" | the demo project on screen |

The recording opens on the **Design → Work Packages** page (they would not open
up) and closes on the **Agile Delivery Model** ("did you implement it? … push
that") and the fact that the schedule still has to be built on top of all this.

## Distilled asks

The owner's asks, in his own words, with the action items worked out in
[`docs/plans/2026-10-08-lusaka-15-todos.md`](../plans/2026-10-08-lusaka-15-todos.md).

1. **Goals come from the WBS — the Goals & Milestones page must not let you add
   a goal.** The WBS is the source of truth; the goals *are* its second layer.
   > "If it's three goals or four goals, well, they should not be able to add
   > any goal here. If that goal should take them to the WBS section. Because
   > they should not be able to add a goal here and then it will show up on the
   > WBS. The WBS is the source of truth for the project goals because they are
   > just the second layer of the WBS."

2. **Agile calls them epics, and the WBS must cap them at 5–7.**
   > "For waterfall, we are calling them goals. And then for agile, if you
   > maintain the one goal, then go one, two, three, which is the epic. Then
   > that's fine." · "If the Agile project, it should be able to select up to, I
   > believe it's five to seven ethics [epics] that they can identify."

3. **Land on usable content.** Project Goals at the top, then the milestone
   table, **then** the mapping; the Notes box must stay hidden unless needed.
   > "This is not a good starting view for when you land here. You have to have
   > like content that is usable. So we talked about the notes being hidden …
   > it's great to have the notes at the top where it needs to be hidden. So
   > that is not happening now." · "I think this project goals has to be at the
   > top. … And then the milestones has to be under it. And then the mapping has
   > to happen."

4. **Validate / edit the milestones *before* mapping them to goals.**
   > "The milestones have to be edited before the goals. So, before mapping into
   > the goals." · "start from like the milestones, validate the milestones so
   > there'll be a prompt … the first one is … the list of the milestones,
   > validate them and then add any milestones in the list and then delete any,
   > if they don't need those. Before they then go to the goals and then they
   > should be able to open each goal up and map the applicable milestones to
   > each goal."

5. **Milestone timeline must be chronological**, and the milestone table needs
   tabs (the "shared milestones from FEP" caption makes no sense as-is).
   > "The milestone timeline … usually, it should be chronological where you
   > know, okay, starting from December, 2026. This is the first milestone. Next
   > milestone is February, 2027 … So it should be clear what those main
   > milestone dates are." · "So I think we need tabs here." · "So this shows
   > all shared milestones from FEP with the goals currently mapped to each
   > milestone. But that's not possible. That description does not make sense
   > because you haven't have the goals in it."

6. **The mapping UI is not user-friendly** — everything is tiny, and Expand
   still needs nested scrolling.
   > "These screens are very small and it's hard to tell what is happening." ·
   > "even though this is the full screen, it's still hard to see." · "when you
   > do expand, at least it goes to the data … not have to scroll down and
   > scroll inside the scroll."

7. **A milestone mapped to a goal does not roll down to every child** — at least
   one child must carry it, and at the next level you pick which child.
   > "the fact that the milestone is tied to a goal, that does not mean all the
   > children in that goal will need their milestone. At least one child must
   > make the milestone." · "when you go to the third level, you have to select
   > if that milestone is applicable to that child."

8. **Requirements map to the first and second level of the WBS, and the
   codes / standards column does not belong here** — codes / standards are
   created in Design Planning and mapped to requirements there, then shown on
   the requirements log.
   > "in this requirement section … the key thing here is having a requirement.
   > They should be able to import and it should have the mapping of the
   > requirements to the first and second level of the [WBS]. And so that is
   > where the requirements finish, but it doesn't have to mark the code
   > standard." · "The code standard comes in in the design planning." ·
   > "if you want to have the code … the code standard, it needs to be grayed
   > out. So it's something that they don't have to fill out now, for when they
   > then go to the codes and standards and map it to the requirements, then it
   > can show up on this requirements log."

9. **Design Specifications is the codes / standards / specifications register.**
   > "when you go to the design specifications, that's where you actually mark
   > the requirements. That's when you actually list all the specifications. So
   > this … should have a table where you are listing all the codes, standards,
   > specifications, their source and all of that."

10. **Requirements Mapping applies specs to requirements; every requirement
    must be mapped.**
    > "my suggestion you mark the specifications to the requirements, all the
    > specifications listed have to be mapped to a requirement, any requirement,
    > some might be more than one requirement." · "This was supposed to be a
    > table view or whatever view that made it easy to see what requirements
    > need to be mapped."

11. **Design Work Packages show the Level-2 WBS, and a package expands to the
    requirements + specs / codes / standards beneath it** — this is the same
    ask as Lusaka 14 item 3, still open.
    > "the desired work packages really should show the second level of the
    > [WBS] … and then if you click on any, it should give you the requirements
    > and the specification code and standards that are associated with that
    > package."

12. **Organization Plan — confirm the RACI matrix update landed.**
    > "I know the racing matrix [RACI matrix] or something that has to be
    > updated. I don't know if you guys did update that."

13. **Agile Delivery Model — implement yesterday's emailed feedback and push.**
    > "the ideal delivery model … we talked about the email I sent you
    > yesterday, I don't know if you implemented that or not." · "All right, if
    > you can push that. So what this part is very important."

14. **Push to staging** — they were reviewing on localhost and needed the build
    live so the owner could see it.
    > "some of these things were actually recently finished, so it should be
    > live on staging. Just that I think we just didn't want to check and see if
    > it was pushed live … we just want to just push."

## Raw transcript

The full `whisper-cli` output is kept at `tool-results/lusaka-15-transcript.txt`
and `tool-results/lusaka-15-transcript.srt` (22,579 / 45,583 bytes).
