# Voice Note — Lusaka 14 / Planning + Agile cadence & release-plan follow-up (2026-10-07)

Source: `Lusaka 14.m4a` (the attached export). The original Voice Memos
recording is `20261007 183201.m4a` (29,728,490 bytes, ~58 min) in
`~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/`;
the attachment's Voice Memos temp copy was cleaned up before it could be read.

Transcribed **locally** with faster-whisper (`base`, int8) — no hosted
transcription key was available, and the `medium` model could not be fetched
(the data volume was full). Regenerate with:

```bash
ffmpeg -y -i "Lusaka 14.m4a" -ac 1 -ar 16000 -c:a pcm_s16le /tmp/lusaka14.wav
HF_HUB_OFFLINE=1 uv run --with faster-whisper python transcribe.py base
```

**Transcription caveat.** The recording is a screen-share, so speaker turns are
not separable and whisper-base reliably mis-hears the project's vocabulary.
Read the quotes with these substitutions in mind:

| Whisper wrote | Means |
| --- | --- |
| "spring" | **sprint** |
| "backward / backflow / buffalo grooming" | **Backlog Grooming** |
| "mouse / muscles / mouse stones" | **milestones** |
| "VPS / VBS" | **WBS** |
| "specificions" | **specifications** |
| "bravo" | **Brevo** (SMTP provider for the report emails) |
| "chingle" | the developer being addressed |
| "requirements to design what people" | **requirements tab** (Requirements Implementation) |
| "execute / exhibition" | **execution** |

The tail (from ~53 min) is logistics: the next session moves to **2 PM on the
8th**, plus a complaint that the automated work/status report is not arriving.

## Distilled asks

The owner's asks, in his own words, with the action items worked out in
[`docs/plans/2026-10-08-lusaka-14-todos.md`](../plans/2026-10-08-lusaka-14-todos.md).

1. **Requirements → WBS mapping was expected in the last push and is missing.**
   > "where is the requirements to the WBS mapping which is what we talked about
   > last time and I sent an email … it looks like that actually wasn't put in
   > the push."
2. **Requirements must carry the codes / standards / specifications** they are
   associated with, mapped to WBS level 1 (epics) and level 2 (features).
3. **Design Work Packages must show, per feature, the requirements + codes +
   standards that apply** — that is the point of the package.
   > "if it clicks on work packet 3.2 it's going to see all the requirements or
   > the code standards and specifications associated with that … that
   > literally [is] the goal of having this work package at the bottom."
4. **Sidebar → Work Packages tab must open that tab**, not the top of the page.
   > "when you put on the last tab it still took you to the beginning … can you
   > please make a note for that."
5. **Scope Tracking Plan stays, but as a scope-transfer plan for Planning** —
   not change management, and not the Execution scope tracking.
6. **Release Plan drives the schedule and project controls**; milestones
   auto-populate on the schedule from the WBS ties; epics/features carry the
   release dates.
7. **The five ceremonies must be selectable and recurring on the calendar**
   (Sprint Planning, Daily Stand-up, Sprint Review/Demo, Retrospective,
   **Backlog Grooming**) — "it cannot just be [a] text [box]" — with day, time
   and repetition, self-adjusting when the sprint length changes.
8. **Velocity-based reconciliation of the agile schedule** after the first
   couple of sprints, with red flags when milestones are at risk.
9. **The automated work/status report email is not arriving** (Brevo SMTP key
   marked inactive).

## Full transcript

Machine transcript, one line per segment (`[start -> end]` seconds).

```
[     3.2 ->      5.2] to the epics and features.
[     5.2 ->     15.3] And did you hear what I said about the requirements mapping?
[    15.3 ->     19.8] Because I think that comes before they add down.
[    19.8 ->     26.2] Okay, so, how did you implement that, like,
[    26.2 ->     30.2] the requirements mapping from the notes that she shared in the beginning?
[    30.2 ->     34.0] So, for example,
[    34.0 ->     37.1] under this section,
[    37.1 ->     40.6] so, like, whatever,
[    40.6 ->     42.6] so, like, the features in the,
[    42.6 ->     44.6] and then the item which I pulled,
[    44.6 ->     46.6] trying to go to the requirements phase.
[    46.6 ->     48.6] Oh, oh, I was talking.
[    48.6 ->     50.9] Sorry.
[    50.9 ->     52.9] So, the requirements mapping,
[    52.9 ->     55.9] and then she shared some more information
[    55.9 ->     57.9] by email how that should be,
[    57.9 ->     62.6] which could be used and everything.
[    62.6 ->     63.6] Yes.
[    63.6 ->     64.6] And so, here it says,
[    64.6 ->     65.6] okay,
[    65.6 ->     66.6] it says,
[    66.6 ->     67.6] Hey, requirements.
[    67.6 ->     88.0] I don't plan into specificions.
[    88.0 ->     94.1] Moment, I'm trying to get back to the screen.
[    94.1 ->     95.1] So, the,
[    95.1 ->    104.9] see,
[   104.9 ->    106.9] I'm not sure if I plan this very well.
[   108.5 ->    109.5] I'm not explained now.
[   109.5 ->    110.5] What do I say?
[   110.5 ->    113.9] How do I say it?
[   113.9 ->    123.7] So, on this section,
[   123.7 ->    126.0] under the requirements mapping,
[   126.0 ->    128.0] they are tied to the WBS,
[   128.0 ->    130.1] but how do I explain it?
[   130.1 ->    132.1] How do I explain it?
[   132.1 ->    143.7] The present requirements could design what people?
[   143.7 ->    144.7] Just a moment.
[   144.7 ->    147.9] Sorry.
[   147.9 ->    148.9] Where is it?
[   148.9 ->    150.9] I have to put on my inspects.
[   150.9 ->    166.6] Sorry.
[   166.6 ->    167.6] I haven't seen that.
[   167.6 ->    168.6] Where is it?
[   168.6 ->    183.8] I was meeting.
[   183.8 ->    186.8] So, I was saying
[   186.8 ->    191.8] that we can go up,
[   191.8 ->    192.8] ought to be done.
[   192.8 ->    193.8] On the page,
[   193.8 ->    195.9] requirements to design what people,
[   195.9 ->    197.9] I mean, a tab,
[   197.9 ->    200.2] I'm really interested in that tab.
[   200.2 ->    217.9] Exclusive.
[   217.9 ->    218.9] Just,
[   218.9 ->    219.9] just going to first,
[   219.9 ->    225.8] for example, here,
[   225.8 ->    227.8] mapping also,
[   227.8 ->    229.8] it brings a drop down
[   229.8 ->    232.8] of all the requirements that are there,
[   232.8 ->    235.1] and then,
[   235.1 ->    237.1] once you choose that requirement,
[   237.1 ->    243.7] and then you can add moment permission
[   243.7 ->    244.7] about the requirements.
[   244.7 ->    245.8] How do you,
[   245.8 ->    255.1] this is the requirement mapping to what to the code specifications right this is requirement
[   255.1 ->    262.6] tracking mapping to the code specifications and standards right okay all right but we talked
[   262.6 ->    271.6] about in before we get here the requirements have to be tied to the WBS elements so if you go
[   271.6 ->    277.4] up to the requirements section so this thing they are showing showing me was already done
[   278.3 ->    287.6] this is not new is there anything new here on this particular section no except you just
[   287.6 ->    297.6] chose the I think requirements which have been linked to the specifications okay so not
[   297.6 ->    309.2] new here yeah yes well where is the requirements to the WBS mapping which is what we talked about
[   309.2 ->    331.1] last last quick and I sent an email and did I get done just the moment
[   523.8 ->    529.0] shouldn't be as quick as frozen and nobody's saying anything so I'm not sure what's happening
[   529.0 ->    535.1] right now are you still looking yes I was just looking in the in the same history of the committee
[   535.1 ->    545.5] just to like kind of check for the push like if it was pushed I'm checking like my desk
[   727.0 ->    773.7] because so like it looks like that actually wasn't put in the push hello yeah I hate
[   773.8 ->    780.5] me I'm just so that was one of the key things that we left the last call for right yes
[   781.6 ->    786.0] so that was one key thing that that was missing because I know when we talked about the requirement
[   786.0 ->    792.2] which I was really mostly focused on the ability to import an export and that functionality was
[   792.2 ->    804.0] totally missed overall and that's a key functionality that ties back to do that ties into
[   804.2 ->    817.8] the the work packages so the epics the features and stories and so as I said we've been
[   817.8 ->    824.4] them with the execution work packages yeah this is something that we have pushed over the next few
[   825.0 ->    841.9] hours okay to be persistent yes how do we proceed
[   841.9 ->    867.4] and you essentially have like most of those things you want in so maybe go to the project services
[   867.4 ->    876.4] another stop tracking plan but you could be more like interface because of the things before
[   886.3 ->    893.4] yeah so this is all the support kind of like it's like but then most of the things once the
[   893.4 ->    911.5] scope is aligned from the schedule course this is when it would like populate most okay you trying
[   911.5 ->    917.2] to say something I am I just don't know what I'm looking at here so this is project controls
[   917.8 ->    929.0] no a page before project controls so oh so I think last time the I think last time when we
[   929.0 ->    934.8] when we put project controls there was actually a scope uh scope tracking plan so so I didn't
[   934.8 ->    940.2] delete the like scope tracking plan page so that we could see if there's anything valuable because
[   940.2 ->    945.6] I just didn't know if there's anything valuable then or that if it could just be overhauled over
[   945.6 ->    951.9] because we built the like project controls which is here and then this was the page that was there
[   951.9 ->    956.7] before so we didn't know if there's anything useful that we could keep then if we just if we just
[   956.7 ->    964.5] take it out I think I recall that but yeah yeah in the in the planning section the scope tracking
[   964.5 ->    971.1] plan should just talk about how we're going to plan um transfer scope um and she does be a summary
[   971.1 ->    978.9] of what we're going to do on the project to travel scope okay so you shouldn't have like all the
[   978.9 ->    996.6] chain management stuff I think that is what's roomy else um the I don't want to see the execution
[   996.6 ->   1018.9] section scope down on this side no scope off right execution yes we have to scroll up so where's
[  1018.9 ->   1025.2] the execution here did you remove it yes it's kind of hiding because of the because of the
[  1025.2 ->   1030.1] project type that we own I think that's something that we discussed this thing okay so the
[  1030.1 ->   1036.1] execution and heat yeah from the this is okay you can work for okay sorry can you go yeah
[  1036.1 ->   1045.3] squint in the first can you go in the room go off all right so what section is this is the design
[  1046.6 ->   1051.5] please pull up on the sitting game yeah the design plan all right so can I see the work packages
[  1051.5 ->   1068.4] on the design plan and the last one yeah that one the last tab for the boat room okay yeah yeah here
[  1068.4 ->   1074.4] so when you put on the last tab it still took you to the beginning it didn't take you directly to it
[  1074.4 ->   1080.7] now we get you the design with package stuff we didn't navigate to the he had to scroll down right
[  1080.7 ->   1092.6] to move the statue yes okay contact you know can you please make a note for that because
[  1092.6 ->   1097.2] it makes no sense to have it on the sidebar if you click on the sidebar scene of the scroll scroll down
[  1097.2 ->   1110.3] to find it okay that that is clear okay so in this work package is right now what really fed this
[  1112.9 ->   1125.4] so this game exactly as it is from the VPS okay so so the big one is epic for you and trust
[  1125.4 ->   1130.0] on the tower I'm looking at so the content more about shopping experience does the epic
[  1137.3 ->   1147.1] yes yes we would we would say work package than epic right these things they confuse me epic story
[  1147.1 ->   1158.8] work package but I believe that the story is that we have epic feature and story so I should
[  1158.8 ->   1167.5] presume this 2.1 2.2 these are the epics that's those are probably features okay so the
[  1167.5 ->   1173.1] epics are the top so the first layer in the in the WBS is that payment infrastructure and
[  1173.1 ->   1183.2] integration yes come on so those are the epics so that's the first layer and then the second
[  1183.2 ->   1189.1] layer is the features so can you click on one of those features because I'm trying to understand
[  1189.1 ->   1202.3] like what is work package is so like I said it creates design work package from selected so
[  1202.3 ->   1213.8] by the time you've gone through the design you should have what requirements codes and standards
[  1213.8 ->   1221.5] are associated with each of the features so where do you see that here where they where they are
[  1221.5 ->   1238.4] identified the requirements codes that specification for each of the workers because that video
[  1238.4 ->   1243.5] should be happening here in the work package because just listing this is just just a WBS
[  1243.5 ->   1247.4] what is supposed to do in the design is to understand what the
[  1250.8 ->   1262.7] which of the codes requirement standards apply to each of the different packages
[  1269.1 ->   1275.7] this is what I'm saying making sense yes I think that is like part for a multi-much here
[  1275.7 ->   1285.2] from the email so it's not effective okay so is this part of this this stuff that wasn't pushed
[  1285.2 ->   1289.3] yet or is this something that you missed and you need to work on I just want to make sure
[  1290.0 ->   1294.5] that you actually work on it if you was missed if you've done it and in common reflect in
[  1294.5 ->   1300.9] I think you should probably speak up one day because I can't say that I want to know why
[  1301.4 ->   1306.3] yes and so all of this and so we had captured everything it's just that it probably wasn't in
[  1306.3 ->   1316.9] the push so I just want to make sure you understand what I'm talking about because what is happening now
[  1316.9 ->   1320.9] is we have pushed this thing to a different day even though it took us almost a week to meet again
[  1322.0 ->   1328.4] so you say you've done it okay or I don't want you to then do the push and I say oh we missed
[  1328.4 ->   1333.3] this so please take in notes the work packages is really supposed to reflect for each of the
[  1333.3 ->   1338.6] features what are the requirements because at the top you you should have mapped all the codes
[  1338.6 ->   1343.5] standards and specifications that are associated with each requirements before that in the
[  1343.5 ->   1349.0] requirement section you should have mapped the requirements to the to the to the
[  1351.1 ->   1357.3] epic and then the features so to the first level of the VBS and the second level of the VBS so now
[  1357.3 ->   1362.1] when you look at a package you should say to get this feature done these are all the requirements and
[  1362.1 ->   1368.1] all the codes are associated with it but at this stage you are not creating it already being
[  1368.1 ->   1373.0] created in those previous stages but this is just pocketing it for say if somebody says well let's
[  1373.0 ->   1378.1] look at this design work package if you want to give somebody that's what I'm going to say I like
[  1378.1 ->   1385.0] you you work on work packet 3.2 if it takes if it clicks on work packet 3.2 it's going to see all the
[  1385.0 ->   1390.8] requirements or the code standards and specifications associated with that from a design perspective
[  1390.8 ->   1395.1] or from a product perspective that literally the goal of having this work package at the bottom
[  1400.0 ->   1407.3] okay so if you haven't implemented that please implement that so when we do
[  1407.3 ->   1436.5] meet tomorrow it's fully reflected okay all right I'm glad it controls go up at the end of the
[  1436.5 ->   1441.0] VTS also when we can walk through all the limitations from the dashboard the VTS is cop tracking
[  1442.9 ->   1463.6] to the scope tracking this is a dashboard so is the release plan and reflected in the
[  1463.6 ->   1471.1] schedule so if you go through the release plan I see right there at the top of the page
[  1472.0 ->   1477.4] because that's what is going to drive the schedule and the project controls so I'm trying to make sure
[  1477.4 ->   1485.3] that we have the previous stuff done so look it is wanted to look at the navigation but the navigation
[  1485.3 ->   1491.2] has to have something that can be interpreted and used if not we are we are we are just looking at
[  1491.3 ->   1503.8] something for four and I we don't have that for that so to go on the on the on the side panel
[  1503.8 ->   1507.4] the release plan is right there right right under the search search bar
[  1509.0 ->   1567.6] check on the release plan to choose to record
[  1569.7 ->   1572.2] I'm going to check you what the issue could be
[  1574.5 ->   1578.5] go yeah it's been noting from time let me check if it's my network or if it's something of
[  1579.3 ->   1631.9] contributing else it's taking a bit longer to load this one it's taking a bit longer to load
[  1673.4 ->   1678.1] all right so I guess the the release plan is going to be very important so
[  1678.1 ->   1684.1] to go you are taking notes right different all right so the release plan is going to be vital I know
[  1684.1 ->   1689.3] we have our milestones the milestone is supposed to auto-populate on the schedule because we've identified
[  1689.4 ->   1698.8] the key things we have to meet we have walked through the we have tied the the WBS elements to
[  1698.8 ->   1705.2] the milestones so that that marker was was done at the beginning of planning where you tied the
[  1707.1 ->   1712.7] the first and second level of the WBS the milestones and so okay this has to be done by this time
[  1712.7 ->   1718.4] so that's kind of for agile that's that's going to impact the release plan because it's going to
[  1718.4 ->   1723.0] say okay this is these are the features we want to release this are the this epic has to be
[  1723.0 ->   1727.4] fully released by this time this aspect of the epic maybe the features has to be released by this
[  1727.4 ->   1733.0] time because usually the epic works together um so that's kind of what kind of drives the
[  1734.2 ->   1739.3] that is also what it's going to feed the schedule is that when that plan of okay these are things
[  1739.3 ->   1745.7] that we need to achieve at this point of time then of course when we know our sprints um I think we
[  1745.8 ->   1751.8] really put in like uh if you go up on the side side by while while this is still trying to lose because
[  1751.8 ->   1756.8] I don't think I remember what the release plan was like so we've already done the sorry go back down
[  1756.8 ->   1762.9] I am still in the agile delivery as we have the dashboard the path of governance, agile team structure
[  1764.0 ->   1770.2] epic some features can run configuration as a respiratory release plan so I believe this is also where we
[  1770.2 ->   1783.0] had the the stories like where we select the the duration for the stories and stuff like that
[  1784.2 ->   1791.0] where this is in backlog governance none backlog that is a backlog yeah this has changed a bit
[  1791.0 ->   1796.0] so it's a backlog governance supposed to be the backlog but that one I haven't seen either I know
[  1796.0 ->   1801.1] you're supposed to go implement that because we didn't have the backlog here for some reason
[  1801.6 ->   1810.7] it's for sure so backlog governance decision already
[  1814.7 ->   1821.5] when did we select the the spring duration there was a board that had like we came with the agile dashboard
[  1822.1 ->   1839.8] that's probably where we selected the the sprints it can't bind um also it goes on the agile
[  1840.8 ->   1846.2] remember the agile delivery model so it's on the agile delivery model okay look on the agile delivery model
[  1846.3 ->   1856.6] okay so this is where we selected the uh that was 30 points
[  1857.6 ->   1862.2] print cadence and calendar yes this is where we said we're in two weeks so I could get on one day
[  1862.2 ->   1871.8] then they don't fly days and and the discussion there was made that whatever I selected here is
[  1871.8 ->   1878.1] reflected on the schedule in terms of is if it's going to be two week increments to have that
[  1879.1 ->   1889.7] kind of shut it to two weeks um these have the tie together right so okay it's crude crude crude
[  1889.7 ->   1896.4] crude on a beach and inside there's a living model okay so we just talk about the sprints
[  1896.4 ->   1903.7] it's going to be every two weeks so we selected that cadence print review and demo so and then
[  1903.7 ->   1907.7] the discussion here if I recall we talked about the fact that this has to show up on the calendar
[  1907.7 ->   1917.2] like on the schedule of showing the sprints starting on this day and then the review and demo and I
[  1917.3 ->   1933.2] don't see the backward grooming here this is how a backward grooming as well um so this text here you
[  1933.2 ->   1943.8] put that in yourself right okay so this is not auto filled so now sprints we have to stand up
[  1944.5 ->   1950.3] we have the end demo we have Rachel so um if you can add backward grooming there those
[  1950.4 ->   1957.9] these these five key things actually have to be something that is added to the calendar
[  1959.0 ->   1965.9] so I know when we talked we talked about the the and I don't know if it's going to be on the
[  1965.9 ->   1972.5] agile map as well because some things have changed I'm struggling with understanding the where
[  1972.5 ->   1981.4] everything is but the calendar should have the it's going to be a cadence where it's the same
[  1981.5 ->   1988.1] and every every two weeks right so every first Monday in the stats it is it's used to start on Monday
[  1988.1 ->   1996.2] October 7th or whatever it's 12th then that'll be the spring planning the bug that is the demo is
[  1996.2 ->   2002.2] going to be on the last Friday the next two Fridays because of the two weeks friends the backward
[  2002.2 ->   2007.4] grooming they can choose what they want to do the backward grooming the retrospective they can
[  2007.5 ->   2014.5] choose what they want to put in the retrospective um maybe the the largely of the sprints and stuff
[  2014.5 ->   2019.8] like that so but those are very recurring that on the schedule if you show them as recurring where
[  2019.8 ->   2026.7] they have to do it like it kind of pops up as a recurring calendar this is for agile um so
[  2027.6 ->   2031.0] those four days and I thought I saw them somewhere I can't see them now
[  2031.8 ->   2037.2] for those four days in putting back on grooming have to show up somewhere where they can actually put
[  2037.2 ->   2044.8] and select the date or or the repetition for it and so that way those things they put they will
[  2044.8 ->   2051.2] auto show on the schedule period so when the project schedule is going through or whatever it's like
[  2051.2 ->   2056.5] you you would you would be a reminder half sprint review the schedule review or the schedule it
[  2056.6 ->   2062.7] and it's just recurring and you have a reminder for it um because those have to happen period
[  2063.5 ->   2068.1] so um so I don't know where you were actually but thank you for an idea of delivery model
[  2068.1 ->   2074.6] I don't know if um that's kind of where um I think I think I think for private I typed in those things
[  2074.6 ->   2079.6] so you need to add backward grooming to it and I think there needs to be something
[  2079.7 ->   2086.7] understandable not just put into a text box so that way it is actually um implemented and
[  2086.7 ->   2092.8] enforceable where they are required to put in what they intend to do and then it should
[  2092.8 ->   2097.5] open the calendar and they have to do it if the nature edited or whatever they can do that say
[  2097.5 ->   2102.7] they said let's have a three-week sprint or whatever they can auto-adjust those dates to reflect
[  2102.7 ->   2108.7] that um so I think that needs to be reflected I thought it was somewhere but I can't find it
[  2109.3 ->   2113.2] if it's somewhere just find it and update that to reflect but if it's not please include it
[  2114.4 ->   2120.1] so going back to the release plan in the same place you were in Chumbo so if you go back to
[  2121.4 ->   2136.5] the adult delivery model yeah so it had release strategy can't you can release strategy
[  2136.5 ->   2141.9] so the delivery model is ready the release strategy okay so this so this might be where it is
[  2141.9 ->   2148.2] release goal is a reversible parameter software updates okay release cadence production
[  2148.2 ->   2154.9] will be the cause by for each plane's completion which is the money for this scope and scope for
[  2154.9 ->   2162.7] its security can you go down honestly what else is there all right so this release strategy doesn't really
[  2162.7 ->   2169.9] point out which features so it is just kind of talk talk through key things that need to be
[  2170.4 ->   2175.2] considered so this should be printable for if somebody wants to see what they're planning so I
[  2175.2 ->   2182.2] think this is okay for now okay so the release plan is what you are going to so they will be
[  2182.2 ->   2188.2] low um not duplication then so the release plan even there's not a lot then it really has to show
[  2189.3 ->   2195.4] type the milestones tab up to all the epics so I really cannot change to be like the epics but the
[  2195.4 ->   2201.1] epics can have like certain features within them and stuff like that and the planning phase it
[  2201.1 ->   2207.1] won't add an epics they they might be able to but once they're in that sufficient phase the top
[  2207.1 ->   2210.7] principle is if you're going to add epics then it's going to have an impact on the schedule
[  2211.8 ->   2217.5] that is out out outlined and stuff like that or they can just reprioritize it and put it
[  2217.5 ->   2224.7] ahead of a different epics um it's what I'm saying making sense because I want to make sure
[  2224.7 ->   2232.7] I am I am not losing you guys I know some of this could be a bit technical um we're following
[  2234.5 ->   2239.7] okay all right no because I know it is a bit technical so you can only feel that if you haven't
[  2239.7 ->   2244.4] really walked within those kind of things you might not understand what I'm talking about but the
[  2244.4 ->   2252.5] point here is because that's the thing with agile it things can change and also with the with the
[  2252.5 ->   2259.3] sizing like understanding like the size of the stories and stuff like that I think like when they start
[  2259.3 ->   2263.6] the the groom and the buffalo groom and saying oh these are the stories within these features
[  2264.6 ->   2270.1] then that style is kind of what's going to drive how much they can do within two weeks and
[  2270.1 ->   2274.8] stuff like that because once you size it then you and you know the number of team members you have
[  2275.5 ->   2279.5] it could be like oh this is the number of stories we have but we only have three people and
[  2279.6 ->   2289.6] we only do six stories stories story points each each sprint um each uh and that is going to help
[  2290.6 ->   2297.6] make the schedule better so okay this is kind of our his his history the team velocity has been
[  2297.6 ->   2304.0] at 25 where we are when we are sizing the stories like we're putting in the story points
[  2304.9 ->   2310.4] if this story points is 21st story point history I'm sure that we're going to be able to do 18
[  2310.4 ->   2316.5] so it kind of and that's where the internal functionality from the code level kind of gives a red flag
[  2316.5 ->   2322.1] of okay if you can't finish this feature in the next frame this master is going to be impacted
[  2325.5 ->   2330.2] that is the true value of our platform but it's not just putting in those things it's also having
[  2330.2 ->   2335.1] the intelligence of understanding what the impact is going to be to the plan and if the solution could
[  2335.3 ->   2343.1] be guess another developer in or the prioritize that specific story or feature if it's not
[  2343.7 ->   2349.1] if it's not tied to that milestone right or or nick it from the mouse because if we're not going
[  2349.1 ->   2354.6] to fill the mouse mouse mouse so these are the kind of educated decisions people have to make
[  2354.6 ->   2361.3] based on the information in front of them so to go I guess from an overall other perspective those
[  2361.3 ->   2368.5] repetitive story feature backlog grooming I mentioned that please add that to to that list
[  2368.5 ->   2373.1] that so if you go to the degree model again now yeah already strategy if you go to the degree model
[  2373.1 ->   2385.3] again the tab so those things that that's probably put in there if you can type in backlog grooming
[  2386.0 ->   2394.8] as well so those five things just inside the spring cadence and calendar that text box right there
[  2397.8 ->   2404.3] okay so the spring planning there is stand-up spring review that's retrospective
[  2405.0 ->   2414.5] and then spring demo on backlog grooming have to be things that they have to actually select
[  2415.4 ->   2421.3] and put in so that has to be selectable it cannot just be touched and it can look unless we can
[  2421.3 ->   2426.9] convert this text into something that can be actionable on the calendar I don't think that's
[  2426.9 ->   2432.3] feasible but it might be from your end so whichever works best for you but the third process would be
[  2432.3 ->   2438.9] so anything that we put here is will be a first step it has to be do not just write the text and go
[  2440.3 ->   2443.8] it's going to show up in the calendar it's going to show up on it okay then it's calendar saying
[  2443.9 ->   2446.0] spring review
[  2446.0 ->   2460.4] it just made all the sounds everybody says much that they said grass and today I'm
[  2460.4 ->   2466.4] finding this part of the spring planning my video is not supposed to go out every good day starts with
[  2466.4 ->   2472.6] a good outfit the outfit was great but when it came down to it didn't just understand what they're saying
[  2472.6 ->   2489.2] now that we're always done you're going to say we are not going to talk about this
[  2489.9 ->   2501.2] okay
[  2530.1 ->   2531.9] now so I will have to
[  2573.8 ->   2575.8] you can have to careful
[  2633.5 ->   2635.5] gigabytes of production
[  2675.3 ->   2680.2] okay so I'm trying to see if I can find I don't know if I'll put it out to you guys I'm not
[  2680.9 ->   2684.6] trying to check the photos
[  2701.3 ->   2731.0] okay so I don't say it in there
[  2822.5 ->   2826.7] well do you guys have any questions questions questions because I can tell you if I sent it to you
[  2826.7 ->   2832.8] if I did I'll send you an email or I just sent I'm I just sent something to you so that we
[  2833.9 ->   2851.9] um it's clear on on the items that need to be highlighted for for the section where you have
[  2851.9 ->   2860.9] very selective what you need to be implemented on the calendar so they are key um they are key
[  2868.2 ->   2875.9] I have ceremony to have to happen and it's recurring so it happens every spring right so
[  2875.9 ->   2880.2] we don't have the spring during the spring end of the spring some some things that
[  2880.2 ->   2886.2] should absolutely have to happen so we're just making sure that's you reflect those here
[  2886.2 ->   2892.2] and it's something that's actionable so it's not your text put you into the text box but it's
[  2892.2 ->   2898.2] small something that they select they know that it's going to be part of the calendar and it's
[  2898.2 ->   2904.7] going to be recurring and so that is it's clear what days and time and so everybody knows that so
[  2904.7 ->   2934.5] it stays on the calendar forever until the spring the product is over okay so was there anything else
[  2934.5 ->   2940.5] then I know we have past times today but we haven't been able to meet in a while so I do want to
[  2940.5 ->   2954.6] ensure that we are aligned on on everything else yeah I think we aligned and we will I think once
[  2954.6 ->   2972.9] we hope on the quote tomorrow we'll be aligned in terms of the items that are still standing okay
[  2975.3 ->   2986.3] that's clear all right so I will just send you an email with this and um that way it can be
[  2986.3 ->   2995.8] implemented um within the I think the best place is in the delivery model um so similar so
[  2995.8 ->   3004.2] selecting the stuff that we have in the the cost ceremony is included here so they know
[  3005.2 ->   3011.5] these are the things I'm intent to do this for this amount of time and um that should also reflect
[  3011.5 ->   3022.3] on the calendar and that should also help drive the and then for the release plan in itself at the
[  3022.3 ->   3027.5] beginning they might not have story points right so the features might not have a specific size
[  3027.5 ->   3033.6] they can do like uh putting like like sizing but you won't know what the team velocity is going to be
[  3033.6 ->   3039.6] that's what going to determine one of the teams has worked and after the first two sprints you should
[  3039.6 ->   3047.7] know what the velocity looks like and there should be a a recon in okay are we is a schedule really
[  3047.7 ->   3053.0] going to meet it based on the first velocity so this should be an internal feature within the site
[  3053.1 ->   3060.0] so I hope you are writing this down um so after like a couple sprints once the velocity is known
[  3060.8 ->   3068.2] then there needs to be a real look at the schedule and if they can really meet it based on what they
[  3069.1 ->   3074.2] put as the because if you remember agile is not really going to have a baseline of the schedule
[  3074.2 ->   3079.4] so instead of that base baseline I'm asking you will be you will be you will be you will be you will
[  3079.8 ->   3086.2] in reconciliation based on the team velocity to see hey this thing that we're going to achieve at this
[  3086.2 ->   3092.3] mouse mouse stones we will be able to achieve it even half as our team is going and how much more
[  3092.3 ->   3097.5] work we have right and we've said that this predict has to be done in six months so what can we achieve
[  3097.5 ->   3103.6] in six months within velocity and that way they can reprioritize based on that another thing into
[  3103.6 ->   3110.9] is if for an existing company or the same company or the same project it doesn't present in
[  3110.9 ->   3115.4] June another project with a similar team they have a good idea of what a velocity would look like
[  3115.9 ->   3122.4] right but again if it's a different team of people then the velocity could change so um you know
[  3122.4 ->   3129.8] what I mean by velocity rights jungle yes okay so that would be one of the metrics and the team
[  3129.9 ->   3135.3] velocity would be determined based on how much they achieve in within this print so if they put it
[  3135.3 ->   3139.6] or in the size that and they said this would be fifty-three pounds but they finished only eleven
[  3140.2 ->   3144.9] and then the second time that happens after the first two spreads there needs to be a review then
[  3144.9 ->   3149.6] after of course six spreads if that are really meeting the velocity or they're taking in more work
[  3150.2 ->   3156.7] than they then they need to adjust so that would be like the agile aspect of the schedule because
[  3157.4 ->   3164.3] the agile schedule is more like same this is when we need to finish the work um and this is how much
[  3164.3 ->   3169.8] work we plan to finish but that's going to depend on the team velocity and they need to prioritize
[  3169.8 ->   3174.7] the items based on to measure that the key things in the milestone is at risk and it is
[  3174.7 ->   3179.1] if they're not going to meet it it needs to be clear to say just so you know for these six months
[  3179.1 ->   3183.5] with the way the team is going we are probably not going to meet this so do you want to
[  3184.8 ->   3189.2] pull up this milestone or change this and stuff like that so that's kind of where the value of
[  3189.2 ->   3197.3] our platform will come in is is that intelligent um like red red red red flags when there's a need
[  3197.3 ->   3210.9] to which to flag it and say hey we look at this okay that is clear all right so I guess we'll talk
[  3210.9 ->   3217.8] tomorrow um I will confirm my my schedule for tomorrow my timing has just been crazy
[  3218.7 ->   3226.8] but tomorrow is the eighth so i happen to be available at two tomorrow so if you guys want to
[  3226.8 ->   3234.3] meet at two tomorrow we can do that so what will be your preference this time tomorrow or two p.m i think
[  3234.3 ->   3240.1] two p.m might be good all right so i'm going to change tomorrow to two guys please plan to make this
[  3240.1 ->   3244.3] meeting private mentioned that you guys joined the meeting yesterday i think the error was
[  3244.9 ->   3252.7] moved it back when it was a Monday meeting that i moved it on the Tuesday so i wasn't that you guys
[  3252.7 ->   3258.3] should have picked that up but um if you can walk together where if you do bugging and i'm not there
[  3258.3 ->   3265.8] ask and i did change changing meeting invite so i'm sure you guys saw that but it said the Monday one
[  3265.8 ->   3271.9] instead of the Tuesday because i was in transit so um but yes if you join and i'm not there maybe
[  3271.9 ->   3276.8] then you know after five minutes i can let you guys know oh that would be very helpful
[  3276.8 ->   3282.3] because it's just disappearing and that's it you you have a semi-ali status of all this jungle
[  3283.0 ->   3289.5] so i don't appreciate that and i don't know why you just refuse to do that so we tried to
[  3289.5 ->   3300.9] automate the process um so like we were trying to send some kind of um so like you actually may have
[  3300.9 ->   3305.5] received some i think the put stuff and and so we're like doing a pilot for some system like we are
[  3305.5 ->   3311.8] work um as we are doing as we are adding stuff it then keeps track of what we're doing and then it
[  3311.8 ->   3316.5] sends you like reporting and so and so we're like piloting that so it's easier for us also to like do the
[  3317.5 ->   3322.5] they i think reports so i think i thought you may have seen also the same
[  3322.5 ->   3325.9] i don't see anything i'm trying to go specifically out for such a report
[  3327.1 ->   3331.2] a concept i asked for probably like three times all the meetings i've missed i have asked for it
[  3332.0 ->   3335.1] the fact they are working on something does not mean that you don't give me the report
[  3335.1 ->   3339.2] so you're trying to make that easier for you okay but i'm super safe for a report
[  3339.2 ->   3345.1] so you need to send me the report i don't think the fact that you're trying to work on something else
[  3345.1 ->   3350.4] to make it easier to send and um okay you know what now that you see this
[  3351.3 ->   3356.4] oh wait oh the bravo key was marked inactive we know using the the bravo smtp key
[  3358.9 ->   3365.8] so i think you need to so i just sort of you know um the bravo let me for and i think i might have
[  3365.8 ->   3371.8] afforded it to you before as well so i want to make sure that we are avoiding any because this is
[  3371.8 ->   3380.6] a functionality that should already be on the site um so i just afforded that to you so you can
[  3381.5 ->   3388.9] deal with but yes after now on the dimension i'm going to receive something i'm seeing work report
[  3388.9 ->   3395.1] last six six days this was October 50 and today is the seventh i totally missed it it says report
[  3395.1 ->   3404.5] as into project but tech wow okay all right so i'm seeing but you could have told me that right
[  3405.3 ->   3410.0] oh yes i did not look to i was i was looking up from from an email from you so this email is here
[  3410.8 ->   3418.2] let's see reports let me see there's another one so you only got it on the fifth let me search for
[  3418.2 ->   3441.2] these reports i don't know okay so there's only one report that i got then so that was two days ago
[  3441.2 ->   3446.1] so i didn't get any yesterday last week all right so i missed it so you sent one i'm going to look
[  3446.1 ->   3452.9] at that because i was looking up for reports but i would have pointed out anything i thought was
[  3452.9 ->   3459.1] was missing out of all of that so i think it's great i tried to utilize the
[  3459.1 ->   3465.8] the technology to make life easier for you um i think you should also
[  3469.1 ->   3474.2] consider the fact that i asked for some some something and either get it to me or tell me
[  3474.2 ->   3480.3] hey i'm sending you an author report please did you get that that's the way to work together
[  3480.4 ->   3485.9] yeah yes all right well thank you chingle and i'll check out your author developed
[  3485.9 ->   3494.9] okay all right thank you so much thank you
```
