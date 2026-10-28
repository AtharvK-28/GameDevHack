# IDEAS.md — What to build next to win

A ranked backlog of ideas, with the research behind them. Nothing here is approved. Each item still goes through the
usual AGENTS.md flow (plan, "go", build) and, if it changes the design, gets a decision in `DECISIONS.md`.

Last updated: 27 Oct 2026, after commit `e5e449d`. Presentation: 2 Nov 2026.

## 1. Must-fix before anything else

These can lose the event on their own, whatever else we build.

| # | Item | Why it matters | Effort |
| --- | --- | --- | --- |
| 1.1 | **Third arena: Abandoned Museum** | PS02 requires **at least 3 arenas**; we have 2 (Mansion, Ship). The Museum is still locked on map select and unticked in `PROGRESS.md`. | 2–3 days |
| 1.2 | **Phone page served by the game itself** | Today the venue needs the game *and* `python -m http.server`. A small static file server on `TCPServer` (already a stretch goal in the spec) makes the game one double-click export. | ½ day |
| 1.3 | **Export build and venue rehearsal** | Offline router, firewall prompts on 8080/9080, the Intel Iris Xe laptop. All still open in `PROGRESS.md`. | ½ day |
| 1.4 | **Overnight soak test** | Jam judges stop at a crash; an early crash or hard lock can disqualify. Our bots (`core/bot_crew.gd`) can play hundreds of rounds on every arena unattended, logging script errors, stalls and memory growth. | ½ day to set up |
| 1.5 | **Player-name filter and host kick** | Names are free text shown on the projector. At a public expo, one rude name ends up on everyone's screen. Jackbox ships a family-friendly filter and host moderation for exactly this. | ¼ day |

### Museum concept: "THE MUSEUM HEIST" (for 1.1)

Ideation only, 27 Oct 2026. Chosen so far: Bahadur the watchman as the ghost, a comic-heist tone, the laser
corridor and the "Swap the fakes" task. Not chosen: a Full Tour match (Mansion → Ship → Museum in one match) and
reworking the Ship intro's ending. Nothing here is approved for building yet.

**Tone.** A comic heist, a Bollywood *Dhoom* / *Ocean's Eleven* parody, with real stakes underneath (bankruptcy). The
crew stay lovable: they are stealing back what was theirs. It's still a moving job, just at 2 a.m. without permission.

**Story.** The Museum is Act 3 of "The Malhotra Fortune" (see the story section below): six intro panels, from the
voyage home and the crash, through Vicky's newspaper headline, to the plan, Bahadur and the title card.

**The ghost: Bahadur, the night watchman.** Each arena has its own ghost (Seth-ji, the Captain); a dead
watchman still on duty is instantly readable, funny and very Indian. Lathi, torch, whistle, a big moustache.

**Signature haunting: "JAAGTE RAHO!"** It plays like Red Light, Green Light, and fills the spec's long-promised
"Lights Out":

1. **Warning:** a whistle blast, then the lights dim.
2. **Lights Out:** the hall goes dark and Bahadur's torch beam sweeps the floor.
3. **The catch:** a mover *moving* inside the beam is caught: they drop what they hold, with a comic "HALT!" stamp.
4. **The counter:** freeze and **pose like a statue**. The mover snaps into a museum pose and the beam passes over.

The comedy is movers pretending to be exhibits next to the T-Rex. It keeps our rule that every haunting has a
warning and a counter.

**The arena: City Museum, one night floor**

- **Central rotunda:** a T-Rex skeleton, the two-person item; it rattles and loses bones (value) on hard bumps.
- **Galleries:**
  - Ancient India: a bronze Nataraja, old coins.
  - Egypt: a sarcophagus the ghost can possess.
  - Art: a painting labelled *"Mona Lisa's cousin"* that screams when bumped.
  - Pirate treasure: the Captain's chest, back again.
- **Laser corridor (chosen):** a shortcut to the van crossed by laser tripwires. Breaking a beam sounds the alarm and
  gives the ghost energy. Hold BRACE to duck under, or take the long way round.
- **Polished floors:** loot slides further; loose display trolleys roll.
- **Loading dock:** the getaway van is the delivery zone, a scruffy Sasta Shifters van with a fake "Museum
  Maintenance" sign taped over it.

**Arena task (chosen): "Swap the fakes."** Carry 3 cheap replicas (a plaster bust, a cardboard T-Rex skull, a painted
brick "gold bar") to empty plinths so the cameras see nothing missing. Doing it weakens Bahadur for the round, the
same way the lanterns and the generator weaken their ghosts.

**Bonus goals (decision 123) the Museum could add:** "Nobody gets caught in the beam", "Move the T-Rex with every
bone", "Swap all the fakes".

**Role reveal lines:** Movers: *"Load the van. Freeze when the whistle blows."* Ghost: *"Nobody moves on MY shift!"*

**Still to decide before building:** a layout sketch (room sizes, corridor length, van position); how a caught mover
recovers; the exact energy the alarm gives; and whether the intro panels are staged renders, like the Ship's, or
painted, like the Mansion's.

### Museum ideas, round 2 (all picked 28 Oct 2026)

**The T-Rex, in three parts (chosen).**

1. **The loot: the T-Rex skull**, the two-person item (the spec's "Dinosaur skull", ₹25,000). Hard bumps knock teeth
   out, which clatter across the floor: every lost tooth is lost value, visible. Its jaw clacks while carried and now
   and then snaps at the nearest mover (C5).
2. **The set piece: the full skeleton in the rotunda, headless.** The skull starts on its neck; lifting it off is the
   heist moment. After that a headless T-Rex stands there all round beside a sign: *"Skull removed for cleaning."*
   Static decor built from shapes (no CC0 skeleton exists).
3. **The living dinosaur: an animatronic T-Rex** in a "Jurassic Hall" corner, Bahadur's possessable signature prop
   (like the rum barrels and the sofa). Possessed, its eyes glow, it roars and stomps across the hall, knocking movers
   flat. The Quaternius "Animated Lowpoly Dinosaurs" T-Rex (CC0, walk/attack animations).

**Tying things together.**

- **The cardboard skull goes on the headless skeleton:** one of the three "Swap the fakes" replicas is a cardboard
  T-Rex skull, placed on the skeleton's neck.
- **Frozen movers become exhibits:** freezing in Bahadur's beam pops a museum label over the mover (*"Untitled
  (Mover), 2026. Sasta Shifters. Oil on overalls."*) and strikes a pose that suits the nearest gallery (a dance pose
  by the Nataraja, the Thinker by the bust).
- **The ALARM level:** breaking a laser fills an ALARM bar as well as giving Bahadur energy. At full, police lights
  flash through the windows and steel shutters start closing gallery doors, trapping loot behind them.

**Loot with personalities.** Moon rock (floats down slowly when thrown: the safe throw); meteorite (pebble-sized but
heavy class); Mona Lisa's cousin (screams when bumped, giving away where you are); dinosaur egg (fragile; if it breaks
a baby dino runs off, reusing the parrot's escape); mummy's hand (put down, it crawls back to its case); gift-shop junk
near the van (T-Rex plushies, snow globes: cheap, quick points).

**Hazards and ghost toys.** A revolving door at the main entrance, on the direct path to the van: the skull through a
revolving door is the Museum's puzzle, and Bahadur can possess it and spin it. Glass display cases: hold to unlock
quietly, or smash at once and raise the ALARM. Bahadur's lathi tap: a short swipe that drops what a mover holds.
Polished marble floors.

**Phones.** "You're on camera": security cameras sweep the galleries; a red ● REC shows on the phone of a mover a
camera sees, and the ghost's phone shows which camera sees whom.

**Running gag.** The goat in a case labelled *"Goat, 2026 (on loan)"*; bonus goal "Rescue the goat", carried to the
van bleating.

**Build order.**

1. Core Museum: layout, skull plus headless skeleton, the beam haunting with freeze-as-exhibit, the laser corridor,
   the swap task with the cardboard skull, the van, and a loot list with the moon rock and meteorite.
2. Then the revolving door and the animatronic T-Rex.
3. If time allows: the ALARM level and shutters, display cases, Mona Lisa's cousin, the goat, the egg, the mummy's
   hand, the gift shop.
4. Later: the camera feeds on phones (the most new phone work).

**Assets found (CC0 unless noted).** Quaternius Animated Lowpoly Dinosaurs (the animatronic, decor dinosaurs); Kenney
Car Kit (the van, to confirm on download); KayKit Halloween Bits (coffin and crypt to repaint as a sarcophagus);
KayKit Furniture Bits (pedestals); Quaternius animal statues on Poly Pizza (check each licence); the Kenney Pirate,
Furniture and Graveyard kits already in the project. Built from shapes: the skeleton, display cases, rope posts,
plinths, lasers, cameras, the painting and the replicas. Not used: CC-BY statues (the spec wants CC0), the
Smithsonian scans (photoreal, clash with the style), paid skeletons.

## The story: "The Malhotra Fortune" (three acts and an epilogue)

Ideation only, 27 Oct 2026. Re-threads the existing intros instead of scrapping them: the Mansion's painted panels
stay (one repaint), the Ship gets new text and one panel, the Museum and an epilogue are new. Not approved yet.

**Logline.** Mumbai's cheapest movers take the three jobs nobody wants, all chasing one family fortune, and the rich
kid who keeps stealing their pay.

**Cast**

- **Sasta Shifters:** the players. Riya, the crew boss on the walkie-talkie (from the Mansion briefing panel), gives
  each job's rules.
- **Seth-ji (Seth Dhanraj Malhotra):** ghost of the Mansion. Died 40 years ago, never moved out. A hoarder: *"If I
  can't keep them, nobody can!"*
- **Vicky Malhotra:** Seth-ji's great-grandson (already mentioned in Mansion panel 07). A startup bro in sunglasses at
  night, always on his phone. The human villain across all three acts; he appears only in story panels, never in play.
- **Captain Kaala Daant ("Black Tooth"):** ghost of the Ship. Seth-ji's shipping partner, who ran off with the
  Malhotra fortune in 1946 on the *Sagar Rani* and sank with it. Hence *"every doubloon is MINE!"*
- **Bahadur:** ghost night watchman of the City Museum (see the Museum concept above). **The twist that ties the
  ghosts together (chosen):** in 1946 Bahadur was *Seth-ji's own watchman*. He failed to stop the Captain stealing the
  fortune, and out of shame has followed the gold ever since; now it sits in his museum, so he guards it there. The
  three ghosts become one story: the hoarder (Seth-ji), the thief (the Captain) and the guard (Bahadur), with the
  movers in between, the only ones who actually carry the thing.
- **The thread:** the Malhotra fortune, a chest of gold.
- **Running gag:** each round's ghost player "works for" that act's ghost, as the role reveal already says (*"X works
  for ME now!"*).

**Act 1 — The Mansion.** Vicky hires Sasta Shifters to empty the house by morning; Seth-ji fights for every vase.

- Keep the painted panels 01–06 and 08–11.
- Repaint panel 07 (job sheet): name the client, *"Client: Vicky Malhotra (great-grandson)"*, and replace the painted
  **70%** with the crew-size target (it is stale since decision 122). Caption: *"His great-grandson Vicky wants
  everything sold by morning…"* Better than a repaint: draw the job sheet live over the panel (a clean, readable list
  with the catalog's real prices, pen ticks, and a red stamp with this crew's actual 55/60/65% target), so it never
  goes stale. The painted sheet today also has a stray "FRAGILE!!" over the list and "Antique vases" twice.
- New beat (a new panel or added to 09/10): Riya finds Seth-ji's diary in the piano bench: *"My fortune sank with
  the Sagar Rani. Curse you, Captain!"* She pockets it.
- **The letter about the ship must read at a glance (user, 28 Oct 2026).** It should look realistic and be clearly
  understood the moment a player sees it, so it is drawn live by the game, not painted into a panel: a full-screen
  page of old, yellowed diary paper (fold creases, ink blots, a water stain, a torn corner), in a clean handwriting
  font, short enough to read in one look:

  > *14 March 1946.*
  > *The Captain has taken it ALL. Every rupee of the Malhotra fortune, loaded onto his ship, the* **SAGAR RANI**,
  > *and gone to sea. If you find this, find the ship. The gold is still on board.*
  > *— Dhanraj Malhotra (Seth-ji)*

  Underlined **SAGAR RANI**, with a small ink sketch of the galleon in the margin, so even someone who skips the
  words sees "a ship" and "gold". It slides up with a paper rustle, the key words underline themselves as the pen
  scratches, and Riya's bubble lands on it: *"…a ship full of gold?"* Same technique as the job-sheet idea: live
  text, never baked into art, so it can't go stale. Plays as the Mansion's end-of-match cliffhanger, and as the
  "Previously…" panel before the Ship.

**Act 2 — The Ghost Ship.** The existing staged renders, with new text and one new panel.

1. **"Previously…"** (new): Vicky's cheque, stamped **BOUNCED**. Caption: *"Vicky's cheque bounced. But Seth-ji's
   diary said the real fortune went down with the Sagar Rani…"* Riya: *"If he won't pay us… his great-grandpa will."*
   This also fixes a continuity slip: today's panel 01 says *"Seth-ji's cheque bounced"*, but Seth-ji is dead.
2. **The wreck** (existing): *"Since when do we own a BOAT?!"*
3. **Boarding** (existing).
4. **The Captain** (existing render, new narrator line): *"Captain Kaala Daant ran off with Seth-ji's fortune in
   1946. The sea took him. It didn't take the gold."* Bubble unchanged: *"ARRR! Every doubloon on this deck is MINE!"*
5. **Title: THE GHOST SHIP** (existing).

**Act 3 — The Museum Heist.** Six new panels.

1. **The voyage home.** The tug piled with the fortune; the crew celebrating. The sea bulges and the Captain rises:
   *"I said every doubloon is MINE!"*
2. **The crash.** The tug flips. The crew cling to a floating grand piano (a callback to the Mansion). Caption:
   *"WE LOST EVERYTHING. EVEN THE SPARE TYRE."*
3. **Bankrupt.** The Mumbai office: a bank notice stamped **BANKRUPT**, a repossession sticker on the truck. Riya
   reads the paper: *"VICKY MALHOTRA DONATES SUNKEN FAMILY FORTUNE TO CITY MUSEUM — 'Found it myself!'"* (He had the
   coast guard fish it out and took the credit.) The crew: *"That's OUR treasure!!"*
4. **The plan.** A blueprint on the table, black masks over their overalls. *"We're not robbers. We're movers. We'll
   just… move it. At night."* Caption: *"Technically, still a moving job."*
5. **The watchman.** The museum at night. A ghostly *chowkidar* with a lathi, a torch and a whistle: *"JAAGTE RAHO!"*
   Narrator: *"Bahadur guarded this museum for 40 years. Death didn't change his roster."*
6. **Title: THE MUSEUM HEIST.** *"Load the getaway van. Freeze when the whistle blows. Swap in the fakes. And don't
   break anything — we can't afford it."*

**The ending, in order.** Museum match's last round → **the Getaway** (a playable 75 s finale, see C7 below) →
final standings → **the epilogue** (five panels) → **credits** → **post-credits stinger**.

**Epilogue — five new panels.**

1. **The godown at dawn.** The truck parked and steaming, the crew collapsed on the gold. Riya: *"We… actually did
   it?"*
2. **The hitchhikers.** At the back of the truck: Seth-ji, the Captain and Bahadur sitting on the gold. *"Where are
   you taking OUR gold?"* Bahadur turns: *"SETH-JI?! Forty years I waited!"* Seth-ji: *"Bahadur?! You're STILL on
   duty?"*
3. **The verdict.** The Captain: *"It's MINE!"* Seth-ji: *"It's MINE!"* Bahadur blows his whistle; everyone freezes.
   *"It belongs… to whoever CARRIED it."* All three ghosts slowly turn to look at the crew. (The story's theme, paid
   off by the guard.)
4. **Meanwhile.** Vicky in the museum, staring at an empty plinth with a sticky note: *"Moved by Sasta Shifters.
   Terms and conditions apply."* In the display case behind him, the goat is eating the plaque.
5. **The new sign.** The repainted truck: *"SASTA SHIFTERS — We Move Anything\*. \*Ghosts included free."* Seth-ji
   carries a vase *very* carefully, the Captain rides the roof like a figurehead, Bahadur guards it with his lathi.
   Title: **"THE END… of the beginning?"**

**Credits (chosen).** After the game ends: *"Starring the Sasta Shifters crew"* with the **real players' names**,
each with their match award (for example, "Atharv: Butterfingers") and the gold they carried. Judges see their own
names in the credits.

**Post-credits stinger.** A new job sheet slides in: *"JOB: Clear out a haunted Bollywood film studio. Fragile: 1
golden trophy."* The sequel tease, and an answer to "what's next?".

**How it plays without a Full Tour.** Each match is still one arena, so each act opens with a one-panel
"Previously…" recap and stands on its own; any arena can be played first.

**End-of-match cliffhangers (chosen).** After each match's final standings, one post-credits panel sets up the next
act, so the audience wants the next arena:

- After the Mansion: Riya finds Seth-ji's diary in the piano bench. *"…the Sagar Rani?"*
- After the Ship: a huge wave rising behind the overloaded tug. *"To be continued…"*
- After the Museum: the Getaway (see "Crazy ideas") and then the epilogue.

**Running gags (chosen).**

- **The goat** from Mansion panel 03 turns up in every act: on the tug's roof, in a museum case labelled *"Goat, 2026
  (on loan)"*, and in the epilogue in a Sasta Shifters cap.
- **The asterisk:** *"We Move Anything\*"* gets new small print each act: *"\*except ghosts"*, *"\*except boats"*,
  *"\*except legally"*, and finally *"\*ghosts included free"*.
- **Each ghost's catchphrase** on its role reveal: Seth-ji *"Nobody touches my vases!"*, the Captain *"Every doubloon
  is MINE!"*, Bahadur *"JAAGTE RAHO!"*

**Rejected:** Vicky as a livestreaming influencer. **Not picked (for now):** the company's only truck "Rani" as the
crew's emotional core; two endings decided by who wins. The theme "who does stuff really belong to?" can stay as a
quiet undercurrent.

**Art work this needs:** repaint Mansion panel 07; optionally paint the diary beat; one new Ship panel and text edits;
six Museum panels; three epilogue panels; a new cutscene hook that plays the epilogue after the Museum's final
standings.

## Crazy ideas (picked 27 Oct 2026)

Ideas no other party game copies easily, because every one of our players holds a screen, a speaker and a vibration
motor. Picked for the backlog; none approved for building yet. Phone tilt, shake and microphone are left out on
purpose: browsers allow them only on HTTPS pages, and our page is plain HTTP on local Wi-Fi.

| # | Idea | What it is | Why it's crazy good | Effort |
| --- | --- | --- | --- | --- |
| C1 | **Haunted Controller** | The ghost spends energy to possess a mover's *phone*. Warning: that phone's screen cracks and flickers for 1 s. Then the stick is mirrored and the buttons swap places for 4 s. Counter: let go of the stick and the possession breaks. | A jump-scare made of the player's own hardware; keeps "every haunting has a warning and a counter" | ½ day |
| C2 | **The Pocket: greed vs the team** | Movers can secretly pocket a small item (a coin, a ring). It vanishes from the big screen into their phone's "pocket" and scores for *them*, not the team's target. At the round end, **THE AUDIT**: Seth-ji reveals who pocketed what, with a comic mugshot. Pocket a little and you win the match; pocket too much and the crew misses the target. | Hidden information that only works with private screens; Among Us-style suspicion inside a co-op game | 1 day |
| C3 | **The Audience Throws Stuff** | Beyond voting, each audience phone gets one heckle per round: 🍌 a banana peel dropped where the ghost is, 🍅 a tomato that stuns whoever is winning, 📣 a CHEER that briefly speeds the movers up. | The whole expo crowd, judges included, becomes part of the game | 1 day |
| C4 | **Match mode: Classic or MIDNIGHT** | A choice on map select or in the lobby. **Classic:** rounds as they are. **Midnight:** at 0:30 the clock strikes midnight; the music doubles in speed, the lights flicker red, every delivery is worth double, and the ghost gets free energy for 10 s. | Every round ends in a frantic climax, great on video, and hosts can still pick the calmer game | ½ day |
| C5 | **Loot with personalities** | Mansion: a cat in a box that sometimes jumps out and runs; a fish tank that sloshes and spills fish (value) if you run; a grandfather clock that chimes when bumped and gives your position away; a cursed doll that walks back to its shelf if put down. Ship: a parrot that flies off if you sprint. Museum: a T-Rex skull that bites the nearest mover. | Each one creates a story players retell | ¼–½ day each |
| C6 | **Throw your teammate** | Movers can pick each other up and throw a teammate across a gap, or over the Museum's laser corridor. | Physics comedy and a heroic two-player combo | 1 day (riskiest physics tuning) |
| C7 | **The Getaway: a playable epilogue** | After a Museum match, a 60 s bonus finale on the highway. The van speeds along with the gold on its open back; movers keep the treasure from bouncing off over bumps and potholes while **all three ghosts** attack: Seth-ji throws vases from rooftops, the Captain sends a flood across the road, Bahadur blows roadblock whistles. Then the epilogue panels. | A boss finale that pays off the whole story | 2–3 days |
| C8 | **Ghost cameos** | Earlier acts' ghosts pop into later arenas as guest hauntings: Seth-ji shoves a museum vase; the Captain floods the museum basement for 10 s. | The story feels connected in play, not only in cutscenes | ½ day each |

**Not picked:** the Invisible Ghost (a VANISH ability tracked only by the phones' near-buzz).

### C7 in detail: THE GETAWAY, "Marine Drive at Dawn"

Ideation, 27 Oct 2026. Decided: the ghosts are run by the game; it's a pure victory lap (no points); credits come
after the game ends; Vicky gets a short cameo.

**When and how long.** Right after a Museum match's last round, before the final standings. About 75 s; Esc skips it
for quick demos.

**Everyone vs the ghosts.** In every normal round one player is the ghost, so friends are rivals. In the finale
**everyone is a mover**, the whole crew together against all three ghosts, run by the game. Role reveal: *"ALL HANDS:
PROTECT THE GOLD!"*

**The setup.** The Sasta Shifters truck races through Mumbai at dawn with its back open and the gold piled loose on
the cargo bed. Riya drives (not a player) and shouts over the walkie-talkie: *"HOLD ON TO SOMETHING!"* The players
stand on the bed, which jolts, tilts and swerves. Anything that slides off the back bounces down the road and is gone
("₹4,000 — BYE!").

**What the movers do.**

- Hold the gold down: BRACE next to an item to sit on it and pin it.
- Catch and re-stack: grab items sliding toward the edge and carry them back to the middle.
- Throw back: an item teetering on the edge can be thrown back onto the pile.

**Four stages: one per ghost, then all three.**

1. **Seth-ji's Revenge** (city streets, 0:00–0:20). He floats along the rooftops hurling vases at the truck. Red target
   circles show where each lands: dodge or catch. A caught vase is a bonus: *"Thank you, Seth-ji!"*
2. **The Captain's Flood** (Bandra-Worli Sea Link, 0:20–0:40). The sea surges and waves crash across the road.
   Warning *"WAVE!"*, counter BRACE: the Ship's wave mechanic as a finale.
3. **Bahadur's Roadblock** (the toll plaza, 0:40–0:55). A whistle, then a barrier swings down and the truck swerves
   hard, so all the cargo slides sideways. Then his searchlight sweeps the bed: freeze like statues or drop what you
   hold. **Vicky's cameo:** his red sports car catches up behind; from the sunroof he can net one item that's too
   close to the back edge, then gets stuck behind the barrier: *"Do you know who my great-grandfather is?!"*
4. **All three at once** (0:55–1:15). Everything together, then a huge **speed breaker** right before the godown gate:
   the truck goes airborne in slow motion, everything floats… and lands.

**Gags.** The goat walks into the road and Riya swerves (*"BEEEEP!"*, a callback to Mansion panel 03).

**Scoring.** **"GOLD SAVED: ₹X"** with 1–3 stars, shown before the final standings. No individual points, so it never
changes who wins the match. The audience can cheer the crew (C3) or throw tomatoes at the ghosts.

**What the big screen shows.** A chase camera behind and above the truck, looking down the road like a racing
game's replay view:

```
┌──────────────────────────────────────────────────────────┐
│  MUSEUM ──●────── SEA LINK ────── TOLL ────── GODOWN      │  ← route strip: the truck icon moves along it
│                        ↑ road ahead to the horizon         │
│   rooftops                                         sea    │
│   Seth-ji throws ─╮                     ~~ waves come ~~  │
│   vases from here ↓      ┌──────────────┐     from here   │
│                          │ [cab] Riya   │                  │
│                          ├──────────────┤                  │
│                          │ gold  mover  │  ← the CARGO BED │
│                          │ mover  gold  │     (the play area)│
│                          │ gold  mover  │                  │
│                          └HORN OK PLEASE┘ ← the open tailgate│
│              ₹4,000 — BYE!  (bounces away down the road)   │
│                       Vicky's car gaining                  │
│  GOLD SAVED ₹1,24,000                       0:42           │
└──────────────────────────────────────────────────────────┘
```

- **The cargo bed fills the middle of the screen**: a big open Mumbai lorry, about twice the Mansion piano's length,
  room for four movers and the gold. All the play happens there.
- **The open tailgate faces the camera**, painted "HORN OK PLEASE" like real Indian trucks. Anything that slides off
  tumbles toward the viewer and bounces away down the road, so every loss is right in the players' faces.
- **The world scrolls past on both sides**: rooftops and streetlights on the left (Seth-ji's side), the sea on the
  right (the Captain's side), the road ahead to the horizon where the toll barrier and the godown gate appear.
- **Behind the truck**, at the bottom of the screen, Vicky's red car creeps up during the toll stage.
- **The speed breaker**: the camera swings to a side-on slow-motion shot of the truck airborne, gold and movers
  floating above the bed, then everything slams down.

**Why it's buildable.** Most of it reuses systems we have: the truck bed is the Ship's moving deck (heave, roll,
slide); the waves are the Ship's gangplank waves; the searchlight is Bahadur's beam from the Museum (so the Getaway
comes after the Museum); the road is a treadmill (the truck stays still while the road, buildings and sea scroll past,
like the Ship's sea), and Kenney road pieces are already in the project. New work: Seth-ji's thrown vases, the barrier
swerve, the goat, Vicky's car and the Mumbai backdrop.

## 2. What similar games do that we don't

Each row comes from the games' features as reviewed or documented (sources at the end). "Have" is our state at `e5e449d`.

| Game | Feature | Have? | What it could look like for us | Value | Effort |
| --- | --- | --- | --- | --- | --- |
| Moving Out 2 | **Assist mode:** longer time, easier items, level skip | Partly (60 s Demo mode, developer mode) | Host "Assist" toggle: +60 s, softer damage, gentler ghost. Lets kids and first-timers finish a round. | High | ¼ day |
| Moving Out 2 | **Accessibility:** UI scale, dyslexia-friendly font, subtitles, motion options, key remapping | No | Options: UI scale, high-contrast/colour-blind markers on player colours, reduce-motion (sway, punch-in), left-handed phone layout | Medium-high (judges notice) | 1 day |
| Moving Out 2 | **Character variants and skins** | No | Hats/outfits picked on the phone in the lobby; or a selfie or doodled face on your mover and the podium | High (delight) | 1 day |
| Moving Out 2 | **Arcade minigames** between jobs | No | A **lobby playground**: movers can run around and shove props while waiting for others to join, instead of an empty board | High (fills dead time) | ½ day |
| Moving Out (series) | **Throwing loot out of windows** as a risky shortcut | No (throws exist, windows are solid) | Breakable windows on the Mansion: throw light loot out and it may survive the drop, or not | Medium | ½ day |
| R.E.P.O. | **Escalating quota** across levels | No (flat target per round) | Target rises a few % each round of the match, so the last round is the tensest | Medium | ¼ day |
| R.E.P.O. | **Shop and upgrades** between levels (strength, reach, stamina) | No | "Seth-ji's tool shop" between rounds: spend round points on perks such as padded gloves (fewer bump losses), a dolly (faster heavy carry), extra seconds. Ghost buys tricks. Adds a strategy layer. | High (depth) | 2 days |
| R.E.P.O. | **Proximity voice and comic mouth flaps** as the main comedy engine | Partly (shouts) | **Phones as speakers:** each phone plays its own sounds (ghost whisper when near you, a crunch when *your* vase cracks). Nobody else does this. | High (unique) | ½ day |
| Overcooked 2 | **Emote wheel** for talking without voice, and celebrating | Partly (3 shouts) | More shouts, plus a celebration emote on the round end, sent from the phone | Low-medium | ¼ day |
| Overcooked 2 | **Versus mode** (team against team) | No | Two crews race to fill their own trucks in one house, the ghost hassling both. Big job. | Medium | 2–3 days |
| Jackbox | **Family-friendly filter, moderation, extended timers** | No | See 1.5; extended timers = the Assist toggle | High at an expo | ¼ day |
| Jackbox | **Audience** of many more phones | **Yes** (decision 119) | — | — | — |
| Luigi's Mansion 3 | **Single-player practice** for party minigames | Partly (developer mode, bots) | A one-phone **practice round** with bot teammates, so a judge can try the controls alone while others gather | Medium | ½ day |
| Luigi's Mansion 3 | **Up to 8 players** | No (4 + audience) | Out of scope; the audience vote covers extra people | — | — |
| Gang Beasts | Grabbing other players | Partly (bumps) | A "nudge" teammates can use to unstick each other; or let the ghost possess a stunned mover's cap. Small, comedic. | Low | ½ day |
| Most of them | **Gamepad support** | No (spec says keyboard and gamepad fallback) | Gamepads map to slots through `InputRouter`, like the keyboard. A backup if the venue Wi-Fi fails. | Medium (risk) | ½ day |
| Most of them | **Persistent records** | No | "Today's best crew" board: highest haul and stars since the game started. Great at an expo booth. | Medium | ½ day |

## 3. Our own ideas (beyond the competitors)

| # | Idea | What it is | Value | Effort |
| --- | --- | --- | --- | --- |
| 3.1 | **Disaster Cam replay** | Record the last ~10 s of every body's transform. At the round end, replay the worst smash from a cinematic angle in slow motion; at the final, a top-three reel. | Very high: judges laugh at their own disaster | 1–1.5 days |
| 3.2 | **Seth-ji live commentary** | The boss's comic bubbles react to big moments ("MY PIANO!!", "₹20,000 GONE!") | Medium-high | ½ day |
| 3.3 | **Contextual phone hints** | First round only: "Hold GRAB" near loot, "Find a partner!" at the chest, "BRACE!" before a wave | High: judges play once | ½ day |
| 3.4 | **Attract mode** | Bots play on the title screen while the lobby is empty, so passers-by stop to watch | Medium-high at an expo | ¼ day |
| 3.5 | **Trailer, poster, demo script** | 60 s trailer from bot recordings; one-page "how it's built" poster; demo script updated (it still says awards are deferred) | High for the pitch | 1 day |

## 4. Recommended order

1. **Museum + Lights Out** (1.1). The only compulsory item we miss.
2. **Built-in page server, export, soak test, name filter** (1.2–1.5). Removes the ways to lose outright.
3. **Disaster Cam** (3.1). The most memorable moment for judges.
4. **Phone hints, attract mode, lobby playground, Assist toggle** (3.3, 3.4, §2). The judges' first minute.
5. **Faces on movers, phones as speakers, Seth-ji commentary** (§2, 3.2). Delight.
6. **Crazy ideas**, cheapest and loudest first: Midnight mode and the Haunted Controller (C4, C1), the Audience
   Throws Stuff (C3), the Pocket (C2), loot personalities and ghost cameos (C5, C8), Throw your teammate (C6), and
   the Getaway (C7), the biggest, together with the story's art.
7. **Trailer, poster, demo script** (3.5).
8. If time is left: tool shop and escalating quota (depth), accessibility options, gamepads, records board.

The Museum and the page server live mostly in new files, so they can be built alongside other work with few merge
conflicts.

## 5. Open questions

- Do we have the official PS02 document or the judging rubric? The event's criteria aren't public. If it weights
  presentation or innovation heavily, the order above should change.
- Which of these is the teammate already doing?

## Sources

- Moving Out 2: [Wikipedia](https://en.wikipedia.org/wiki/Moving_Out_2), [Shacknews review](https://shacknews.com/article/136630/moving-out-2-review-score), [Gaming Trend review](https://gamingtrend.com/reviews/moving-out-2-review-i-like-to-move-it-move-it/), [Superjump review](https://superjumpmagazine.com/moving-out-2-review), [FingerGuns review](https://fingerguns.net/games/2023/08/11/moving-out-2-review-ps5-moving-on/)
- R.E.P.O.: [Destructoid money tips](https://www.destructoid.com/repo-tips-to-make-money/), [Twinfinite items guide](https://twinfinite.net/guides/all-items-in-repo-how-use-them/), [Game8](https://game8.co/articles/games/repo), [Deltia's Gaming](https://deltiasgaming.com/?p=170035), [Co-Optimus](https://www.co-optimus.com/blog/article-poster/3380/the-game-where-a-piano-is-scarier-than-the-monsters.html), [Pure Xbox](https://purexbox.com/news/2025/03/repo-explodes-in-popularity-on-pc-leading-to-calls-for-an-xbox-version)
- Jackbox: [Party Pack 8 streaming, moderation and accessibility](https://jackboxgames.com/streaming-moderation-accessibility-features-jackbox-party-pack-eight), [Party Pack 10 accessibility](https://www.jackboxgames.com/blog/accessibility-features-in-the-jackbox-party-pack-10), [Keeping your stream safe](https://www.jackboxgames.com/how-to-keep-your-stream-safe-while-playing-jackbox-games/), [Wikipedia](https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack)
- Overcooked 2: [Stevivor review](https://stevivor.com/reviews/overcooked-2-review-time-head-back-kitchen), [Push Square review](https://www.pushsquare.com/reviews/ps4/overcooked_2), [Vooks review](https://vooks.net/overcooked-2-switch-review)
- Luigi's Mansion 3: [Nintendo multiplayer page](https://luigismansion3.nintendo.com/multiplayer/), [GameSpot on ScreamPark](https://www.gamespot.com/articles/nintendo-shows-off-luigis-mansion-3s-new-screampar/1100-6470787), [Vooks on DLC pack 2](https://vooks.net/the-second-luigis-mansion-3-multiplayer-dlc-pack-is-out-now)
- Gang Beasts: [Gamereactor review](https://www.gamereactor.eu/gang-beasts-review/), [Nintendo Life review](https://www.nintendolife.com/reviews/switch-eshop/gang-beasts)
- Jam judging: [WPI Game Jam](https://wp.wpi.edu/gamejam/?p=90), [The Sandbox jam criteria](https://thesandboxkorea.notion.site/Game-Jam-Criteria-and-Judging-Process-c33eaaa771f94e1aa77f9be9c76f48bf), [SA Game Jam results](https://makegamessa.com/discussion/comment/55250)
