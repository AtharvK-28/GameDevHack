# PROGRESS.md — Build progress

The phases follow the spec's 24-hour build plan. A phase is done only when its check passes. AI agents update this file after every task.

**Status:** Phases 0–1 complete. Phase 2 carrying core is built and passes automated physics checks; awaiting the user's phone playtest.

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
- [ ] **Check:** carry a vase to the truck; bumping a wall visibly drops its value (awaiting the user's phone playtest)

## Phase 3 · H6–9 · Two-person carry, tumbling, flashlight

- [ ] Two-person carry
- [ ] Tumbling
- [ ] Flashlight and exorcism
- [ ] **Check:** two players get the piano through a doorway (fallback decision at H9)

## Phase 4 · H9–12 · Ghost

- [ ] Wisp movement
- [ ] `Possessable` component with all 5 prop types
- [ ] Energy
- [ ] House Shake and Ecto Slime
- [ ] **Check:** a 1v1 greybox round is tense and fair

## Phase 5 · H12–14 · Match flow (minimum viable game)

- [ ] Lobby with QR code
- [ ] Role reveal and ghost rotation
- [ ] Timer and quota
- [ ] Round end with restart
- [ ] Results with awards
- [ ] HUD
- [ ] **Check:** a 4-player match runs from lobby to results with no restart

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
- [ ] Particles, shatter punch-in, phone buzz
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
- Known: the four "Unclaimed" mover name tags overlap at spawn until phones join (Phase 1 harness). Loot speed and mass tables are indexed by item kind, which only works while vase/TV/clock map to light/medium/heavy; add a per-item weight class when more loot arrives in Phase 6.
