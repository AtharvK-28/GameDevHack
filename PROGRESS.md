# PROGRESS.md — Build progress

The phases follow the spec's 24-hour build plan. A phase is done only when its check passes. AI agents update this file after every task.

**Status:** Phases 0–3 complete. Phase 4 (ghost) passes `core/ghost_check.gd`; its two-phone 1v1 check is still to do. Phase 5 (match flow and demo scope) is built and passes `core/match_check.gd` (60 checks) plus all four earlier checks; the user's 4-player phone test is next. The Mansion layout, furniture catalog, lighting, environment, animated movers, menus and edge HUD are built. Phase 6 remains incomplete: Ship, Museum, their hauntings and human acceptance are pending.

## Phase 0 · Setup

- [x] Godot project created by the user in the editor (Mobile, Jolt; 60 Hz explicitly configured)
- [x] `AGENTS.md`, `DECISIONS.md`, `PROGRESS.md`, `ghosted-movers-spec.md` added to the repo root
- [x] Git repository initialised and pushed to `origin/main`
- [x] Phase 1 decisions recorded under the user's instruction to replan and start; exact supplied Godot version verified

## Phase 1 · H0–2 · Plumbing

- [x] Folder structure from the spec (later-phase scenes intentionally not stubbed)
- [x] `Net.gd` WebSocket server
- [x] Controller page served from the laptop
- [x] Keyboard fallback in `InputRouter`
- [x] **Check:** 4 phones each move their own capsule — user confirmed all four players work on 2026-10-23

## Phase 2 · H2–6 · Carrying core

- [x] Mover controller
- [x] Base `Loot` with spring carry
- [x] Impact damage and price tags
- [x] Truck banking
- [x] Greybox room built from CSG shapes
- [x] **Check:** carry a vase to the truck; bumping a wall visibly drops its value — user confirmed on phones on 2026-10-23

## Phase 3 · H6–9 · Two-person carry, tumbling, flashlight

- [x] Two-person carry
- [x] Tumbling
- [x] Flashlight with beam and 1.5 s exorcism timer (removed later, decision 82)
- [x] **Check:** two players get the piano through a doorway — user confirmed phone control and two-person pickup work on 2026-10-23; the single-person fallback is not needed

## Phase 4 · H9–12 · Ghost

- [x] Wisp movement
- [x] `Possessable` component with all 5 prop types
- [x] Exorcism (the flashlight that triggered it was removed later, decision 82; map tasks will trigger it)
- [x] Energy
- [x] House Shake and Ecto Slime
- [x] Ghost phone screen: energy, ACTION label, haunting costs, greyed buttons, cooldown rings
- [ ] **Check:** a 1v1 greybox round is tense and fair — waiting for the user's two-phone test

## Phase 5 · H12–14 · Match flow and demo scope

- [x] Lobby with QR code
- [x] Role reveal and ghost rotation
- [x] 150 s timer, 70% final delivery target, >30% loss early defeat and single result snapshot
- [x] Round end with restart
- [x] Final leaderboard (awards deferred)
- [x] HUD and phone phase/lock/reason/countdown feedback
- [x] Seeded 6/9/12-item setup; identical restart
- [x] Simplified ghost: sliders, Shake, six-second heavy-item Curse
- [x] Three-quarter smooth camera; ability-only shake
- [x] Disconnect pause/reconnect/cancel
- [x] Automated scoring, Curse and full-match checks
- [ ] **Check:** a 4-player match runs from lobby to results with no restart — waiting for the user's phone test

## Phase 6 · H14–18 · Arenas and look (safe submission)

- [ ] Old Mansion — layout, truck and look pass done (dusk lighting, textures, wall fade, arches, gates, windows, decor, grounds); furniture catalog and possessable furniture built; human playtest of the look still pending
- [ ] Ghost Ship
- [ ] Museum of Mostly Real Things (decision 128). Stage A done 2026-10-28: the arena from
  `arenas/layouts/museum_layout.json` (six galleries, laser hall, lobby, van at the loading dock), 12 loot items worth
  ₹88,000 on pedestals, the moon rock's floaty throw, CC0 exhibits placed at real size by `MuseumKit`, the map tile
  unlocked, no intro yet. `core/museum_check.gd` passes 28 assertions (pool, seeded rounds, exhibits resting on their
  spots, a mover walking from the van into every gallery, the skull carried by two through the laser hall to the
  van, the moon rock). All 19 suites pass, 1,304 assertions. Next: the museum look (lighting, marble, facade,
  ropes, plaques), then stage B (skull teeth, headless skeleton, Bahadur, JAAGTE RAHO!) and stage C (lasers, swap
  the fakes). Until stage B it borrows the Mansion's House Shake and ghost model.
- [x] Museum look (decision 129, 2026-10-28): spotlit exhibits in dim galleries, marble, gallery paint, ropes, plaques,
  name plates, EXIT signs, runner, desk, UFO, gold case, dock markings and the classical facade. Museum, layout,
  catalog and UI checks pass; 131 fps average at 1080p on the Radeon 780M.
- [x] Museum outside and van sign (decision 130, 2026-10-28): a city block at night round the museum (forecourt,
  fountain, street, lamps, parked cars, flags, trees, lit skyline) and a two-line van sign that fits the panel.
  Museum check passes (28); 125 fps average at 1080p.
- [x] Museum stage B (decision 131, 2026-10-28): the skull on a headless T-Rex skeleton's neck, losing teeth as it
  loses value and clacking its jaw; Bahadur the watchman as the ghost; JAAGTE RAHO! (lights out, a torch beam that
  follows the ghost, HALT! for movers who move in it, statue labels for those who brace), the bonus goal "Nobody gets
  caught in the beam" and the award CAUGHT RED-HANDED. `core/museum_check.gd` now passes 39 assertions; all 19
  suites pass, 1,315 assertions. Next: stage C (blinking lasers, swap the fakes), then the revolving door and the
  animatronic T-Rex.
- [x] Bahadur's toys (decision 132, 2026-10-28): the animatronic T-Rex (possessed, it walks; SHOVE is a roaring
  charge) and the revolving door (always turning; SPIN knocks down movers inside; the skull leaves by the laser
  hall). The ghost may possess every kind of prop in a Museum match. `core/museum_check.gd` passes 46 assertions
  (its walking routes now go through the laser hall); all 19 suites pass, 1,322 assertions.
- [x] Museum stage C (decision 133, 2026-10-28): the laser hall's three blinking gates (a lit crossing trips the alarm
  and feeds the ghost; award HUMAN ALARM CLOCK) and Swap the Fakes (three replicas from the van onto three plinths;
  all three slow Bahadur). `core/museum_check.gd` passes 53 assertions; all 19 suites pass, 1,329 assertions
  (`stick_check` failed once in its phone-joining setup with a slot index error and passed on two reruns: flaky,
  worth a look). Museum still to do: bots and a balance run, the ALARM bar and shutters, the smaller personality
  items, intro panels.
- [x] Museum bots (decision 134, 2026-10-28): a route map (in and out by the laser hall), the skull pair's path, and
  bots that wait for lit lasers. Balance sim, 4 seeded rounds at x3 on the Museum: movers won 0 of 4, banked 41%,
  lost 19% (target 60% for two movers); the skull was delivered in every round. Bots still trip lasers often, mostly
  the skull pair: with its carriers it is ~3.4 m long against gates 2.5 m apart (decision for the user). Fixed: an
  arena with no intro left the intro screen over the round. All 19 suites pass, 1,329 assertions.
- [x] Two laser gates, 4.5 m apart (decision 135, 2026-10-28), so the skull pair can stop between them; bots wait
  while the gate ahead is lit. Bot rounds on the Museum vary a lot on the same seeds (21-45% banked), so its
  balance needs a human playtest. All 19 suites pass, 1,329 assertions.
- [x] Museum extras batch 1 (decision 136, 2026-10-28): Mona Lisa's cousin screams, the goat (goal "Rescue the
  goat"), the mummy's hand crawls home, the gift shop. Fixed: "Nobody gets caught in the beam" counted as missed.
  `core/museum_check.gd` passes 61 assertions; all 19 suites pass, 1,337 assertions. Next: the ALARM bar and
  lockdown shutters, the dinosaur egg, display cases.
- [x] Museum extras batch 2 (decision 137, 2026-10-28): the ALARM bar (lasers, screams, beam catches) with police
  lights and a 20 s lockdown of the back galleries, and the dinosaur egg that hatches a runaway baby raptor.
  `core/museum_check.gd` passes 69 assertions; all 19 suites pass, 1,345 assertions.
- [x] Display cases and security cameras (decision 138, 2026-10-28): exhibits in Egypt and Space under glass (hold
  GRAB to unlock, THROW to smash), three sweeping CCTV cameras, a REC banner on a spotted mover's phone and a CCTV
  line on the ghost's. Phone page rendered with a simulated `cam` message. `core/museum_check.gd` passes 76
  assertions; all 19 suites pass, 1,352 assertions. Museum left: intro panels (with the story) and a human
  playtest, which should also judge the ALARM numbers.
- [x] Playtest went fine (user, 2026-10-28). Audit of the three maps done; order approved: (1) Museum fixes and
  sound, (2) the Mansion upgrade, (3) expo safety, (4) Ship bots and Museum dev tools, (5) crazy ideas.
- [x] Step 1 (decision 139, 2026-10-28): the Museum's own round music and city night ambience with far sirens and
  horns; the ghost's phone button reads JAAGTE RAHO on the Museum (was SHAKE); the guide covers all three maps and
  its role text fits (it was clipped). `core/museum_check.gd` passes 80 assertions, `core/ui_check.gd` 206 (rendered
  and inspected); all 19 suites pass, 1,358 assertions.
- [x] Step 2 (decision 140, 2026-10-28): the Mansion upgrade. The ghost may possess every furniture kind in every
  arena's matches (the slider-only rule is gone); the cat in a box, the fish tank and the cursed doll; the
  grandfather clock chimes; the goal "Don't wake Seth-ji" and the award GRANDFATHER'S ALARM. Models rendered and
  inspected. New suite `core/mansion_check.gd`, 34 assertions; all 20 suites pass, 1,400 assertions.
  `tools/balance_sim.gd` on the Mansion (10 seeded rounds, x3): before, movers won 3 of 10 (58% banked); with the
  new loot but slider-only possession, 6 of 10 (59%); as built, with full possession, 2 of 10 (38%). The loot is
  neutral; the ghost's door, chandelier, armour and rug make the bot crew much weaker (on one seed the bot pair
  could not hold the piano after the ghost shoved the clock and yanked the rug). Needs a human playtest to judge.
- [x] Museum developer shortcuts (decision 141, 2026-10-28): Ctrl+2 drives the ALARM (full, lockdown, over),
  Ctrl+4 switches the lasers, and the overlay shows the Museum's state. `core/museum_check.gd` passes 86 assertions,
  `core/dev_mode_check.gd` 32.
- [x] The Haunted Controller (decision 142, 2026-10-28): the ghost's HEX cracks a mover's phone, mirrors their stick and
  swaps GRAB and THROW for 4 s; letting go of the stick breaks it. Phone rendered hexed, warned and as the ghost (five
  buttons). New suite `core/crazy_check.gd`, 11 assertions; `ui_check` 206, `ghost_check` 128, `match_check` 66 and
  `plumbing_check` 73 still pass.
- [x] Throw your teammate (decision 143, 2026-10-28): lift an empty-handed teammate with GRAB, THROW them about 5.5 m
  (over a lit laser gate, or overboard), let go to set them down, BRACE to wriggle free. Rendered lifted and mid-air.
  `core/crazy_check.gd` 20 assertions; `core/museum_check.gd` 88; all 21 suites pass, 1,429 assertions.
- [x] Disaster Cam (decision 144, 2026-10-28): the round's worst disaster replays letterboxed in slow motion before
  the round-end page (rewind, build-up, the hit, the blame); the final results open with the match's worst three. Rendered
  on the Mansion with bots carrying the piano. New suite `core/replay_check.gd`, 18 assertions; all 22 suites pass,
  1,447 assertions.
- [x] Story cutscenes (decision 145, 2026-10-31): new intros on all three maps from the team's Gemini art, with a video
  for each ghost's entrance, a held last frame for the ghost's line, and the Museum's first story. Every panel rendered
  with its lettering. New suite `core/story_check.gd`, 24 assertions; all 23 suites pass, 1,471 assertions.
- [ ] End-of-match cliffhangers (Seth-ji's diary, the wave) and the epilogue: art is in `assets/source/cutscenes/`; each
  needs a hook after the final results.
- [ ] Gust of Wind and Lights Out
- [x] Mover and ghost character models integrated (brought forward; visual acceptance pending)
- [x] Party camera and Mansion wall fade implemented (human acceptance pending)
- [ ] Lighting per arena
- [ ] **Check:** every PS02 requirement met; commit and tag

## Phase 7 · H18–21 · Juice and playtest

- [ ] Full sounds and music pass (procedural game sounds, UI sounds and night ambience already exist)
- [ ] Complete particles and phone buzz pass (some effects and tumble buzz already implemented; shatter punch-in deferred)
- [ ] Playtests with 2, 3 and 4 players
- [ ] `Balance.gd` tuned

## Phase 8 · H21–22.5 · Feature freeze

- [ ] Bug fixes only
- [ ] Exported build
- [ ] Venue network tested
- [ ] Fallback inputs confirmed

## Phase 9 · H22.5–24 · Demo prep

- [ ] Pitch rehearsed
- [ ] Backup video recorded
- [ ] Attract loop running

## Genre research follow-ups (2026-10-26, approved)

- [x] Ghost-nearby buzz and glow on mover phones (decision 115): Ship check covers levels 0-3 and silence inside a prop;
  phone page rendered in headless Edge at 844 x 390 at levels 1 and 3, JS syntax-checked.
- [x] Funny end-of-round and match awards (decision 116): Ship match check covers overboard, tumbles, the ghost's
  MENACE, no blame for unheld loot, award picking and restarts; round end rendered with four players at 1080p.
- [x] Shout bubbles from the phone (decision 117): Ship match check covers a real phone's shout, the cooldown, junk
  messages and the ghost; phone page rendered at 844 x 390 and 568 x 320; bubbles rendered on the Ship.
- [x] Slow-motion punch-in on big smashes (decision 118): Ship match check covers slow-down, camera punch, recovery
  and the cooldown. Needs a human look at the camera move in a live match.
- [x] Audience phones vote (decision 119): `core/audience_check.gd` (real WebSocket phones) covers joining, voting,
  ties, every outcome and the timed vote; HUD card and audience phone rendered.
- [x] Medals and bonus goals (decision 123): stars, one bonus goal a round and the ghost's counter-goal on the
  reveal, HUD, round end and phones. Phone result rendered at 844 x 390.

## Playtest follow-ups (2026-10-27)

- [x] Balance (decision 122): target 55/60/65% by mover count, softer impacts. `tools/balance_sim.gd`, 10 seeded bot
  rounds per arena at x3: Mansion movers won 0 of 10 before (banked 37%, lost 31%) and 5 of 10 after (banked 62%,
  lost 27%). Ship 1 of 10 both times: the Ship bots seldom deliver, so only a human playtest can judge the Ship.
- [x] Joystick feel (decision 124): screen-relative stick, changes sent as they happen, follow, tilt^1.3.
  `core/stick_check.gd` pushes up and right from a real phone on both arenas and measures the mover on screen.
- [ ] Playtest the new balance and stick with people.

## Joining and the venue network (2026-10-27)

- [x] The host serves the phone page (decision 125): `autoload/PageServer.gd` on 8080, so there is no second
  server to start and no Python dependency. `core/page_server_check.gd` passes 27 assertions (the page and every
  file the phone needs, content types, the served `settings.json` parsing as JSON, five traversal and 404
  refusals, non-GET refused, the WebSocket port unaffected). All 17 suites pass, 1,226 assertions, no failures.
  Worth knowing for future checks: autoload globals do not resolve in `extends SceneTree` scripts — use
  `preload("res://autoload/Balance.gd")` and `root.get_node("Net")`, as every other check does — and `_get` is
  reserved by `Object`.
- [x] Busy page port (decision 126, 2026-10-28): a backup tool's service held 8080 on the host laptop, so the page
  server failed silently. It now falls back to the next free port up to 8090, every link uses `PageServer.port`, and
  the lobby says "PHONE PAGE COULDN'T START" when all are taken. `core/page_server_check.gd` covers the move, the QR
  link and the all-busy report (33 assertions). All 17 suites pass, 1,241 assertions, no failures.
- [ ] Export filter: `controller/` carries a `.gdignore`, so the page is read from disk when running from source
  but would not be packed into an exported build. Add `controller/*` to the export preset's include filter when
  the export is built.
- [ ] Venue network still untested. The laptop hotspot caps at 8 devices on Windows, which covers 4 players plus
  4 spectators but not audience mode's 50; that needs venue Wi-Fi without client isolation.
- Dropped for now: a Wi-Fi QR beside the join QR. Two codes cost more experience than they save, and the
  one-scan version needs a captive portal, whose iOS WebView has no `localStorage` — which reconnect depends on.
- [ ] Preflight panel (detected IPs, page server state, connected devices) — proposed, not built.

## Developer mode (decision 120, 2026-10-27)

- [x] Options switch, F10 stand-in phones, keyboard driving of stand-in slots, F9 phone page, F3 overlay and the
  Ctrl shortcuts. `core/dev_mode_check.gd` passes 22 checks on the Ship with no phones (off by default, stand-ins
  join and re-ready, keyboard drives a mover and the ghost while an undriven stand-in stays put, every shortcut).
  Lobby hint and live overlay rendered at 1080p.
- [x] Human try-out on the laptop (user checked it, 2026-10-27).
- [x] Playing stand-ins and extras (decision 121): bots on both arenas, Ctrl+B, F5/F6 speed, Ctrl+G ghost cheat, Ctrl+N
  last round. `core/dev_mode_check.gd` covers the keys and that bots play every stand-in but the keyboard's;
  `core/bot_crew_check.gd` plays a ×3 round per arena (bots pick up loot, carry the pair item along its path, the
  ghost haunts and possesses, the round ends). At ×1 the Mansion bots won with 7 deliveries; on the Ship the ghost
  bot usually wins, as the pair carry down the forecastle steps and the ghost's shoves cost too much.

## Blocked / notes

- Verified Godot `4.7.2.stable.official.ed1daf0bf`, Mobile/D3D12 rendering on Intel Iris Xe, Jolt and explicit 60 Hz physics.
- `core/plumbing_check.gd`: passed four real WebSocket clients, separate capsule movement, malformed input, magnitude clamping, short taps, timeout, disconnect, reconnect with role/points preservation, fifth-player rejection and keyboard/focus release.
- Browser verification: four isolated Chrome contexts; 30 input messages per second at rest; simultaneous joystick/button touch; touch cancellation; reload/rejoin; no uncaught JavaScript errors; landscape layouts at 568×320, 667×375, 844×390 and 1024×768; portrait rotate overlay at 375×667. Screenshots visually inspected.
- Main scene rendered and visually inspected with the actual Mobile renderer. Godot emitted an environment-level root certificate-store warning during local checks; LAN HTTP/WebSocket checks still passed. This was not a script/scene error.
- User confirmed the controller page loaded and all four phone players worked; Phase 1 accepted. Phase 2 approved with “go”.
- Initial project and Phase 1 checkpoint `9bfc228` pushed successfully to `origin/main`; generated caches, local test dependencies and verification captures are ignored.
- Run instructions and the browser feature limitations are in `README.md`.
- Phase 2 handover (2026-10-23): the previous agent's `carrying_check.gd` never really ran, because preloading loot before the autoloads existed failed to compile, so several of its passes were false. Fixed; the check now stops if loot fails to load.
- `core/carrying_check.gd`: 75 checks pass with real Jolt physics. Measured carry worst cases: 6.4 m/s relative to the mover, centre at most 1.24 m high, 1.03 m behind the carry target during a 180° turn. Plain drops are free even at walking speed. A carried vase walked into a wall lost value (₹3,000 → ₹1,383); slow wall contact, resting contact and holding an item against a wall caused no damage. Banking happens exactly once, including repeated release/bank calls in one frame. Two movers grabbing in the same tick give exactly one holder. `plumbing_check.gd` still passes; the 120-frame smoke run is clean.
- Phase 2 fixes from those checks: carried items are kept upright by a torque (they were flipping up to 168°); facing turns at 5 rad/s instead of snapping (the hold point jumped 2.5 m, which flung items); the spring is stiffer (150 / 18) with a 1 m stretch cap; a fixed 0.25 m carry clearance makes drops free (decision 14). Price tags are larger, use ₹ grouping and are drawn over walls; damage popups start above the tag. Rendered frames inspected with the Mobile renderer.
- Known: the four "Unclaimed" mover name tags overlap at spawn until phones join (Phase 1 harness).
- Phase 3 build (2026-10-23): `props/carryable.gd` now holds the shared carry, so loot and the flashlight both use it. Each loot item has its own weight class (this fixes the item-kind indexing noted in Phase 2). New: piano with two handles, flashlight with beam and exorcism timer, tumbling, a parlour with a 2 m door, and a camera pulled back to frame it.
- `core/team_carry_check.gd`: 49 checks pass with real Jolt physics and two simulated phones. Measured:
  - Two holders lift the piano to 0.75 m and carry it at 3.07 m/s (target 3.15), peaking at 3.11.
  - Average steering lands 10° off the 45° average; opposite pulls turn it 68° in 0.8 s without moving its centre.
  - One-handle drag runs at 1.03 m/s (target 1.125) and scrapes ₹363 over 1.23 m (expected ₹366); the lone mover drags at 1.67 m/s (target 1.8).
  - A scripted pair turns the piano and takes it through the parlour door in 1.3 s with no damage.
  - A thrown vase knocks a mover over, drops their item and buzzes their phone. They stay down for 1.5 s and ignore the stick meanwhile. Slower hits, and fast items that were not thrown, tumble nobody.
  - The flashlight beam follows facing; 1.5 s in the beam exorcises the stand-in once. Cone, walls and a loose torch all prevent exorcism.

  `carrying_check.gd` (75) and `plumbing_check.gd` still pass; the smoke run is clean.
- Phase 3 fixes found by the checks: hits on a mover counted only about half the item's speed, because the physics engine reported the mover's shove-out-of-the-way motion as its velocity. Hits now use the mover's own walking velocity: a vase arriving at 5.39 m/s registers 5.39 m/s, not 2.62. The parlour partition is knee-high (0.7 m), so the camera can see into the parlour; it still blocks movers and a carried piano. Rendered frames inspected.
- Deferred to Phase 5: the second flashlight for 4-player matches (spawned at round setup); the lone-mover flag is set by match flow.
- Phase 4 handover (2026-10-23, new machine): Godot 4.7.2 (`ed1daf0bf`) verified; import plus `plumbing_check.gd` (35), `carrying_check.gd` (75) and `team_carry_check.gd` (49) all passed before any change. A headless import re-saved `project.godot` without the explicit 60 Hz line (60 is Godot's default); the line was restored. Watch for this after imports.
- Phase 4 build (2026-10-23): `GhostWisp` (energy, possession, the exorcism freeze and lock, and the host's check on every ghost button), the `Possessable` component (slider and hopper driven in the component; door, chandelier and rug act through their own scripts), `Haunting` with House Shake and Ecto Slime, `PartyCamera` with trauma shake, the ghost's phone screen, and one valueless prop of each type in the greybox. The host key G passes the ghost; the lone-mover rule counts movers only.
- Phase 4 build verification: every new script compiles and loads, Main runs headless with a ghost (13 possessables: 8 loot items and 5 furniture), and the three earlier checks still pass (35, 75, 49; they now remove the furniture first). The ghost phone screen was rendered in headless Firefox at 844×390 and 568×320 for the free, possessing and exorcised states, plus the unchanged mover screen, with no script errors. A Mobile-renderer look at the new visuals remains pending.
- Phase 4 ghost check (2026-10-23): the first complete run had 128 passing assertions and 2 failures. Both were test issues: the reopening door pushed the mover outside its panel beside the jamb, where walking straight ahead hit the wall; the chandelier assertion ran just before physical contact with the vase. The test now walks the mover around the open panel and through the doorway, and waits for the chandelier's landing with a bounded timeout before asserting damage. The focused door probe and final full ghost check pass: **130 assertions, exit code 0**. The mover reached z = -8.81 m beyond the doorway; the dropped chandelier reduced the vase from ₹3,000 to ₹829 after exorcism. Gameplay code and tuning are unchanged. Local output is saved in ignored `.verification/ghost_check_latest.log`.
- Phase 5 build (2026-10-23, continued after the previous agent's usage limit): it had recorded decisions 39–48 and written `Game.gd`, Curse, the phone refusal reasons and seeded loot, but stopped before the round setup and host screens, so Main could not run. Added: `setup_match_round()` and the lobby reset in `main.gd`; the five host screens in `screens/` (Lobby with QR, RoleReveal, HUD with pause overlay, RoundEnd, Results); `core/qr_code.gd`; the three-quarter following `PartyCamera`; phone match screens (reveal, pause, result, final), Curse button, refusal reasons with seconds and the cursed-item note. Main defaults to match mode; the four earlier checks switch it off and use the greybox harness.
- Phase 5 verification: `match_check.gd` passes 60 checks with two real WebSocket phones and the host keys (lobby, refused late join, seeded setup, reveal, camera yaw and follow, regen 8/s, opening protection and shared lock with phone reasons, Curse cost/no stacking/30% slower for 6 s, exact 70%/30% win, early ghost win at 30% + ₹1, restart with identical layout and replaced points, ghost rotation, timeout, disconnect pause/resume/cancel, a full 4-round match). Plumbing, carrying (75), team carry (49) and ghost checks still pass; the match-mode smoke run is clean, with no script errors or leaks. The QR encoder matches the reference `qrcode` library module for module (48 symbols, versions 1–6, all 8 masks). Host screens were rendered in the Mobile renderer and phone screens in headless Chrome at 844 × 390; both inspected.
- Phase 5 fixes found while verifying: the phone HUD read a freed item when a carried item shattered (logged an error each time); the lobby link wrapped onto two lines; the 3D truck sign showed through the panels; the locked Curse button kept its colour; the cooldown ring covered button text.
- Watch: the open Godot editor re-saved `project.godot`, dropping the explicit 60 Hz line (restored) and adding `import/blender/enabled=false` (left uncommitted for the art task).
- Mover art (2026-10-23): the team's model replaces the capsule visuals, from `assets/models/mover/` (three shirt variants, 21 clips, 18-bone rig, 8,294 triangles, no textures). It is scaled 0.91 to the unchanged 1.6 m capsule, faces the mover's facing, and is driven by `MoverModel` from existing state only. Checked frame by frame: every state plays its own clip; walk 1.62 m/s plays at 1.11×, run 4.5 at 1.10×, team carry 3.11 at 1.08×, and tumble plus get-up at 1.36× to fit 1.5 s. Mobile-renderer screenshots of each state and all four colours were inspected. Four animated movers ran at 441–523 fps with vsync off on the Intel Iris Xe laptop. Plumbing, carrying, team carry, ghost and match checks all pass after the change. The source `.blend`, previews and guide are in `assets/source/mover/` (Godot skips it), and Blender import is off. Historical issue: carried items sat ahead of the hands; the repair pass adds a visual arm-reach pose while preserving the hold point.
- User requests (2026-10-23): camera mirrored to yaw −20° (decision 54); the live HUD's top panel is one compact row; the match starts fullscreen and F11 toggles (decision 55). If Godot embeds the running game in the editor's Game tab, fullscreen needs the game in its own window.
- Old Mansion layout (2026-10-23): built from `arenas/layouts/mansion-layout.svg` as data (`mansion_layout.json`) by the new arena-agnostic `arenas/arena_builder.gd`. Walls stand 3.0 m above their floor (scaled to the 1.6 m movers), camera-facing walls are 15% see-through, railings are see-through with solid colliders, and the stairs are 8 visible steps over one ramp collider. The old test room is now `arenas/Greybox.tscn`; all earlier checks use it and real matches load the Mansion. `core/arena_layout_check.gd` passes 30 checks: room zones, doorway widths and piano clearance, routes from every room to the truck (gallery route carrying a vase down the stairs), all three carry weights up and down the stairs, two movers carrying the piano down and back up undamaged, and railings, the gallery edge and see-through walls holding movers and loot. Top-down and party-camera screenshots inspected. Known: colours look washed out under the white ambient light and bloom (greybox only); historically the wisp used a fixed world height and intersected the gallery; the repair pass makes its height follow the arena floor.
- Truck (2026-10-23): the farm pickup scan cut to 20k triangles with its texture, scaled to 4.5 m × 1.67 m to suit the 1.6 m movers, and parked tailgate-first at the end of the path (`props/Truck.tscn`, solid bed and cab boxes). Delivery is a green half-circle behind the tailgate (`TruckZone` half-circle mode), narrowed to a 2 m radius and laid flush with the ground; the model sinks 8 cm to hide the scanned grass at its tyres. `arena_layout_check.gd` now passes 35 checks, adding: the half-circle counts and its outside doesn't, a vase released in it banks, and the truck is solid. Party-camera and top-down screenshots inspected.
- Mansion look (2026-10-24): dusk mood (violet fog and ambient, AgX, glow, moon shadows, 7 lamps), procedural stylised textures on every surface through triplanar materials, two-sided walls with wainscoting, camera-facing walls that fade only while they hide a player, stone and walnut arches, open iron gates (garden and a new front gate), a walnut balustrade, glowing windows, and a dressing scene with Kenney CC0 decor per room plus the grounds (perimeter fence, bare trees, grass). Ghost spawns outside for now. `arena_layout_check.gd` passes 41 checks (adds wall fade, ghost spawn, decor clearance from every spawn spot, arch headroom and width, front gate opening). Frame rate with 4 movers walking, fullscreen 1920 × 1080 on Intel Iris Xe (integrated), Mobile renderer, vsync off: 225 FPS before, 114 FPS after (shadows cost most; the shadow map was cut to 2048 px).
- Menus, HUD and security (2026-10-24): Maaack's Game Template menus (title over the idling Mansion, map select, options with Demo mode, credits, pause) themed with Kenney UI Pack pieces and Baloo 2; the game launches into them. Lobby with keyed QR, join code and slot cards; edge HUD (timer, room ring, truck totals, delivery toasts, player chips with ghost energy, Tab totals). Phone page restyled with code entry. Connection security: session key and code, per-player secrets, 2 s log-in, pending cap, 1 KB messages, rate limit, wrong-code lockout, key rotation. All six checks pass (plumbing includes every security case); screenshots of every screen and the phone page inspected. Frame rate 114–118 FPS at 1080p on Iris Xe, unchanged.
- Mansion world (2026-10-24): surroundings scene with forest, grassland, road, gate, chimney and shutters; wildlife, mist, leaves, fireflies, lightning and reactions; synthesized night sounds; truck lights. Proven: no void or ground edge at any of the four camera-bound corners at the widest framing (26 m). All six checks pass. Frame rate with 4 movers at 1080p on Iris Xe: 114–118 FPS before, about 94 after.
- Furniture system (2026-10-24): data-driven catalog (`props/catalog/`) from the Kenney Furniture Kit (CC0) plus 7 built hero items; the Mansion's 18-piece loot pool spawns on role-tagged spots placed like a lived-in home; possessable chandelier, kitchen door, suit of armour, hall rug and sofa; rooms dressed (gallery library, piano and bedroom; fireside parlour; kitchen; garden benches). New `core/catalog_check.gd` passes (entries, values, colliders, the piano's route, decor never possessable or priced, the whole pool rests where placed, every match-sized pick). The greybox the other checks use is unchanged.
- Flashlight removed and price tags made subtle (2026-10-24, decisions 82 and 83): no flashlight item, spawns, settings, carry pose or beam checks; exorcism stays for future ghost tasks (the checks trigger it directly). Price tags are half size, softer, and show only within 3 m of a mover or the ghost, or while carried; `carrying_check` covers hiding and revealing. Next: design the map tasks that handicap the ghost.
- Cleanup, goofy physics and joystick feel (2026-10-24, decisions 84 and 85): removed the furniture-kit zip committed by accident, 7 unused UI icons and placeholder `.gitkeep` files; locally cleared the download archives in `assets/_incoming/` and old logs and screenshots in `.verification/`. Movers lean and squash, bump each other apart and ease in and out of walking with a curved stick response; items jiggle and light ones bounce. `carrying_check` covers the stick curve, the walking ramp, bumping and jiggle. The controller settings export now includes the join code length. Still to do: try the joystick on real phones.

- Repair pass (2026-10-24, decision 86): added the home Guide with Back/Escape and restored Play focus; ensured the home window cannot shrink below the configured UI base. Verified real opening -> Home -> Guide/Options -> map select -> QR lobby; F6 on Main intentionally bypasses Home, so README now clearly specifies F5. Ghost flight follows the gallery and stair floor, including after leaving possession. Visual arms reach item surfaces/handles with elastic scaling; loot transforms, spring targets and colliders are unchanged. README reconnect rules, Mansion/character checklist and spec submission claims reconciled.
- Repair verification: all seven checks passed, 495 assertions total (plumbing 73, carrying 83, team carry 35, ghost 128, match 63, arena 46, catalog 67). The arena check adds gallery/stairs/ground flight and gallery possession-exit coverage. Rendered Mobile checks verify Home, Guide, Options, map select and lobby navigation; captures inspected. Rendered vase/TV/clock and two-person piano spot checks place both hands at the item surface/handle (under 0.001 m surface gap). Local harnesses/captures/logs stay ignored in `.verification/`; new script `.uid` files are retained. Godot import and some test exits still report ObjectDB/resource cleanup warnings; these are unresolved and are not assertion passes.
- Still pending: real-phone fairness, full four-player match acceptance and joystick feel. Other arena tasks, Ship/Museum, their abilities, gamepad support and export/demo preparation remain development work. Decision 40's demo ability restrictions remain in force and are explained in Guide; the older archived-behavior questions in DECISIONS.md remain open.

- Battery Run (2026-10-24, decision 87): implemented three heavy task batteries at three distinct seeded picks from ten checked Mansion spots. A separate cyan generator zone left of the path counts mover releases once; all three power it for the rest of the round. Lighting improves over 1.5 s; haunting cooldowns become 1.5x, free-wisp regen 0.5x and flight 0.75x. Possession/SHOVE and active abilities remain available. Batteries do not affect loot, points or quota, and escaped batteries recover to their spawn. Restart restores task positions, ghost tuning and lighting; new rounds receive new seeded picks. Vegetation clears the generator pad; lightning preserves the improved light. HUD, phone feedback, Guide, README and spec updated.
- Battery Run verification: `core/battery_check.gd` passes 120 assertions, including all ten spawn clearances with the full loot pool, RNG coverage/restart, heavy carry, a physical carry route through the front door, release-only delivery, duplicate prevention, no money/loot credit, real wisp speed, regen, current/new cooldowns, still-usable abilities, lightning, pause and reset. Carrying, ghost, match, arena-layout and catalog regressions all pass. Rendered before/after lighting, generator and HUD captures inspected; menu/Guide navigation passes. Headless Edge phone checks pass at 568 x 320 and 844 x 390 with no script errors or controls overflowing. New script UID files generated. The previously recorded Godot shutdown resource warnings remain. Human playtesting is still needed to tune task cost and reward, especially in 1v1 and 60-second Demo mode.
- Intro cutscene (2026-10-24, decision 88): `screens/Cutscene.tscn` plays the 11 story panels between START and round 1's reveal, once per match, with cozy then spooky music, rain and engine loops and per-panel sound cues; Enter next panel, Esc skip. Phones show "Story time". Sources are in `assets/CREDITS.md`; the goat, whoosh, rumble, walkie crackle and organ are synthesized in `Sfx.gd`. Verified: a scripted run of the flow (Enter through all 11 panels, Esc skip, no replay on restart or next round, replays on a new match, a phone dropping during the intro pauses the round only once it starts), every panel rendered and inspected at 1600 × 900, and all seven checks pass with no failures (`match_check.gd` now also checks the intro phase, the phone message and Esc). Pending: a human listen to judge the sound mix; panel 10's "Torch it!" line refers to the removed flashlight (kept as flavour for now).
- Comic UI (2026-10-24, decision 89): after the judge called the UI underwhelming, every screen now follows the intro's comic look, built from a shared kit in `screens/screen_style.gd` (caption boxes, ink panels, bubbles, stamps, chips, keycaps, mover figures, halftone backdrop) with Bangers lettering. Rebuilt: the lobby (clock-in board), role reveal (Seth-ji splash page), HUD (punch-clock timer, truck and vase meters, red edges, player chips), world labels (comic popups, stacking name tags, painted zones), round end (stamp, stat tiles, counting points), final standings (rising podium with a crown) and the menus (comic title, comic map cards, page-turn wipe). The match screens now apply the game theme themselves (they sit under a CanvasLayer and had been falling back to Godot's default font). Every screen was rendered and inspected at 1920 × 1080 with realistic names and with `ui_check`'s 16-character names; the rendered `ui_check` now passes (it had failed on the lobby overflowing). The phone page is unchanged. Open: the comic world popups keep decision 83's size (pixel size 0.009) and read small from the camera; enlarging them needs the user's say.
- Truck and arms (2026-10-24, decision 90): the truck now faces the house on the driveway with the delivery half-circle on the path; zone pads and painted markings were lifted above the path slab (they had been hidden under it). The arm-stretch bug was reproduced (an armchair carried into the generator machine lagged 1.60 m behind the hold point while still held) and the visual reach capped at 1.4x. A held item can still lag behind when snagged; the user chose to skip an auto-drop. All nine checks pass (`arena_layout_check.gd`'s delivery point moved with the truck) and the intro flow test passes.
- Ghost reach, effects and contrast (2026-10-24, decision 91): reach 1.2 m with aim assist toward the wisp's movement; `core/fx.gd` particle bursts (dust, sparks, shards, sparkles, ghost puffs) wired to landing, tumbling, one-handle dragging, damage, smashing, banking and possession, plus the wisp's trail; the Mansion grade gains contrast and saturation; movers get an ink outline (`assets/shaders/ink_outline.gdshader`). Rendered and inspected in a live round. Next: random task per round (designs to be approved).
- Sound (2026-10-24, decision 92): the spec's audio table is now in the game (banking, damage by fragility and size, smash with a sad trombone over ₹10,000, possession, House Shake warning, tumble), plus grab, throw, Curse, countdown, last-10-second ticks, round and match jingles, and round music that speeds up for the last 30 s. A scripted check confirmed every event starts its sound and the music follows the phases; the mix still needs a human listen.
- Graphics pass (2026-10-24, decision 93): `STYLE.md` written; light grade, yard light and the repainted orange truck added and inspected in a rendered live round. Arena, battery, match, catalog and rendered UI checks pass. The intro flow test's one "starts on panel 1" miss was timing in the scratch test (it read the panel after the first auto-advance), not the game.
- Calmer yard and clearer loot (2026-10-24, decision 94): yard scatter thinned and toned toward the ground; wood floors darkened so loot reads; rendered and inspected.
- Comic look on the playfield (2026-10-24, decision 95): toon light on movers, loot and possessable furniture; ink outlines on loot and furniture. All nine checks pass; close-ups of a mover and the piano inspected.
- Lighting softened (2026-10-24, decision 96): compared renders before and after the grade changes; the strong contrast, saturation, vignette and floor tint were rolled back to light touches. Battery, arena and match checks pass.
- Goofier physics (2026-10-24, decision 97): GOOFINESS 1.8 with bouncier springs and more bounce on light loot; all eight physics and match checks pass. The way back to the mild settings is in the comment above GOOFINESS.
- Rim light and window light pools (2026-10-24, decision 98): rendered and inspected; arena, battery, catalog, match, carrying and rendered UI checks pass.
- Loading screen (2026-10-24, decision 99): built from the user's design; rendered at 78% and inspected; the rendered UI check (real launch path) passes.


## Ghost Ship build (decision 100, 2026-10-24)

- [x] Approved deck-plan SVG and data-driven split-floor layout, ramps, open hold, tug delivery and map selection.
- [x] Ship catalog: 18 items, 74500 rupees; seeded match picks, chest and rolling barrels.
- [x] The Captain's parrot (decision 127, 2026-10-28): Ship loot with a personality, in every round; walk it, don't
  run. The catalog is now 19 items, 78500 rupees. `core/parrot_check.gd` passes 35 assertions (spawning, perch
  clearances, the walk, the reset, warning then escape, throws, knocks, the sea, landing on a perch, banking). All
  18 suites pass, 1,278 assertions. `tools/balance_sim.gd` on the Ship: movers won 1 of 10, the same as before;
  the parrot flew off 5 times (4 knocks, 1 fall in the sea), never from a bot running with it.
- [x] All five possessable types, Gust warning/counters, two-second overboard rescue and water-plane loot loss.
- [x] Initial real-physics Ship check passes: all room routes, held ramp travel, continuous two-player chest route and delivery, wind counters, rescue/pause and loot removal.
- [x] Initial Mobile performance with four movers/full pool passes: wide 149758 triangles / 287 draws; close 158834 / 282 on Intel Iris Xe. Final visual capture/measurement still pending.
- [x] Davy Jones is the Ghost Ship's ghost (decision 101, 2026-10-25): a `GhostAvatar` interface lets each arena name
  its ghost body, `DavyJonesModel` animates the static model in code, and `ghost_apparition.gdshader` keeps his own
  textures while making him spectral. Verified: ghost check still passes 128 assertions on the Mansion wisp, and the
  Ship check passes 60 (up from 53) with new coverage of his body, bound textures, facing, shadow and exorcism
  tumble. Close portraits at the game's angle inspected. The model is not CC0 and must be swapped before release.
- [x] Ghost Ship look finished (decision 102, 2026-10-25): solid hull decks (the open undersides and the wall-less
  hold are gone), a hull that reaches below the waterline, a bowsprit, billowed canvas sails, and wood/treasure tints
  on the three Kenney pirate props that were rendering salmon and powder blue.
- [x] Reference-water comparison done: the project's own shader is kept; the MIT reference renders as ice floes
  without the author's own (non-MIT) textures, so it and its licence file were removed from `assets/`.
- [x] Davy Jones replaced by an original drowned captain built from shapes (decision 103, 2026-10-26); the rip and
  its textures are deleted. Ship check passes 60 (captain checks rewritten: built body, per-part colours, no shadow,
  faces +Z travel, tumble) and ghost check 128. Portraits at three angles rendered with the Mobile renderer and inspected.
- [ ] Human 2/3/4-phone Ship playtest.

## Ghost Ship expansion (decision 104, for the 2 Nov presentation)

- [x] 1. Original captain replaces Davy Jones
- [x] 2. Light the Lanterns map task (decision 105): `core/lantern_check.gd` passes (seeded spots, clearances, a real
  carry over the gangplank, release-only delivery, handicap, lighting through lightning, restart). The battery is now a
  task base the oil can extends; HUD and phones read the task's own name. Tug render inspected. Human feel pending.
- [x] 3. Ship intro comic (decision 114): four panels with lettering, music and cues; Ship match check covers the
  story opening, lettering and Esc skip. Panels rendered and inspected at 1080p. Painted art pending from the team
  (`assets/cutscenes/ship/PANEL_BRIEF.md`).
- [x] Ship performance re-measured after the sea motion (2026-10-26) with `tools/ship_performance.gd` (4 movers, motion,
  two breaking waves, a fog bank, 1080p, vsync off) on an AMD Radeon 780M: 134 FPS average, 115 at the 5th percentile,
  113 minimum; 256 draw calls and 164920 triangles (budgets 350 and 400000). Still to run on the Intel Iris Xe laptop.
- [ ] 4. Human 2/3/4-phone playtest and tuning (user tested the captain and lantern task on 2026-10-26: "feels right")
- [x] 5. Deck sway (decision 106): Ship check passes with five new sway checks (bottle creeps both ways, chest stays,
  sea tilts, camera unchanged); lantern, ship match and arena layout checks pass. Peak-roll render inspected. Feel pending.
- [x] Ship rebuilt around Kenney ship-pirate-large (decision 107): new deck plan, model hull/castles/rails/masts, ghost
  sails, gangplank from the waist port. Ship check passes (routes from every deck, all weights down and up the castle
  steps, chest down the forecastle steps and over the plank, sway, wind, rescue). Party-camera renders inspected.
- [x] 6. Rolling barrel hazard (decision 108): Ship check adds ROLL label, spin, speed-up down the castle steps and the
  knocked-over mover (69 pass); ghost, ship match, arena layout and match checks pass. Feel pending.
- [x] 7. Waves over the gangplank (decision 109): Ship check adds calm outside matches, warning visuals, no hit during
  the warning, unbraced mover washed into a rescue, braced mover holds, deck untouched, next-wave timing (77 pass).
  Warning render inspected. Feel pending.
- [x] 8. Ship audio (decision 110): bell, shanty, roll creaks; Ship check covers the bell, the track and its file. Mix
  needs a human listen.
- [x] 9. Fog banks (decision 111): Ship check covers forming, drifting faint and clearing.
- [x] Stern castle steps made carryable (decision 112): every weight goes down and up undamaged.
- [x] The Ship rides the sea (decision 113): rolling, pitching, heaving rig of moving platforms; sea swell and foam;
  breaking gangplank wave with spray, foam and an eased lurch. Ship check adds movers standing steady on moving decks,
  loot riding the motion and a wave lurch without damage (an instant lurch had cost 15,814 rupees), and deck height
  following the tilt. Wave stages and motion rendered and inspected. Tools: `tools/ship_autoplay.gd` plays a scripted
  Ship round (recording paused at the user's request).
