# PROGRESS.md — Build progress

The phases follow the spec's 24-hour build plan. A phase is done only when its check passes. AI agents update this file after every task.

**Status:** Phase 1 implemented and locally verified; awaiting four physical phones on the target network. No later phase started.

## Phase 0 · Setup

- [x] Godot project created by the user in the editor (Mobile, Jolt; 60 Hz explicitly configured)
- [x] `AGENTS.md`, `DECISIONS.md`, `PROGRESS.md`, `ghosted-movers-spec.md` added to the repo root
- [ ] Git repository initialised and pushed
- [x] Phase 1 decisions recorded under the user's instruction to replan and start; exact supplied Godot version verified

## Phase 1 · H0–2 · Plumbing

- [x] Folder structure from the spec (later-phase scenes intentionally not stubbed)
- [x] `Net.gd` WebSocket server
- [x] Controller page served from the laptop
- [x] Keyboard fallback in `InputRouter`
- [ ] **Check:** 4 phones each move their own capsule, with no noticeable lag

## Phase 2 · H2–6 · Carrying core

- [ ] Mover controller
- [ ] Base `Loot` with spring carry
- [ ] Impact damage and price tags
- [ ] Truck banking
- [ ] Greybox room built from CSG shapes
- [ ] **Check:** carry a vase to the truck; bumping a wall visibly drops its value

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
- Four physical phones and actual network latency remain unverified. Phase 2 is gated on that acceptance check.
- Git repository existed without commits at the start of this task. Remote push is not yet verified.
- Run instructions and the browser feature limitations are in `README.md`.
