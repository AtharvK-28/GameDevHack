# PROGRESS.md — Build progress

The phases follow the spec's 24-hour build plan. A phase is done only when its check passes. AI agents update this file after every task.

**Status:** Phases 0–3 complete. Phase 4 (ghost) passes `core/ghost_check.gd`; its two-phone 1v1 check is still to do. Phase 5 (match flow and demo scope) is built and passes `core/match_check.gd` (60 checks) plus all four earlier checks; the user's 4-player phone test is next. Mover character art is waiting for its plan's go.

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
- [x] Flashlight with beam and 1.5 s exorcism timer (connected to possession in Phase 4)
- [x] **Check:** two players get the piano through a doorway — user confirmed phone control and two-person pickup work on 2026-10-23; the single-person fallback is not needed

## Phase 4 · H9–12 · Ghost

- [x] Wisp movement
- [x] `Possessable` component with all 5 prop types
- [x] Exorcism wired to the flashlight's beam timer
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

- [ ] Old Mansion
- [ ] Ghost Ship
- [ ] Abandoned Museum
- [ ] Gust of Wind and Lights Out
- [ ] Party camera and wall fade finished
- [ ] Lighting per arena
- [ ] **Check:** every PS02 requirement met; commit and tag

## Phase 7 · H18–21 · Juice and playtest

- [ ] Sounds and music
- [ ] Particles and phone buzz (shatter punch-in deferred)
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
