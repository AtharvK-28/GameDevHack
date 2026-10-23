# DECISIONS.md — Decision log

Every approved design or technical decision, newest first. Only the user approves decisions. AI agents add an entry after approval and keep `ghosted-movers-spec.md` in sync.

## Decided

| # | Date | Decision | Reason |
| --- | --- | --- | --- |
| 21 | 2026-10-23 | A "thrown" prop (for tumbling) is one launched with THROW, until it slows below 4 m/s or comes to rest. Possessed props join in Phase 4. | Phase 3 plan approved with “ok add it in” |
| 20 | 2026-10-23 | The flashlight is a light, throwable item. It has no value, takes no damage and does not bank. | Phase 3 plan approved |
| 19 | 2026-10-23 | Exorcism is split as the spec's build plan says. Phase 3 builds the flashlight, its beam and the 1.5 s beam-held timer, tested against a stand-in target. Phase 4 connects the timer to real possession. PROGRESS.md now matches the spec. | PROGRESS.md and the spec disagreed; phase 3 plan approved |
| 18 | 2026-10-23 | Grand piano is 2.2 × 1.0 × 1.4 m and 100 kg. The greybox gains a back parlour behind a partition with a 2.0 m doorway, so the piano must be turned to fit through. | Phase 3 plan approved; matches "piano in the far parlour" |
| 17 | 2026-10-23 | The lone-mover drag rule (40%) turns on automatically when only one player is active, until Phase 5 sets it for real 2-player matches. | No match roles exist before Phase 5; phase 3 plan approved |
| 16 | 2026-10-23 | Dragging a two-person item by one handle scrapes 1.5% of its current value per metre dragged, including the lone mover's 40% drag. | Spec had no number; phase 3 plan approved |
| 15 | 2026-10-23 | Two-person carry uses physical pulls: each holder drives their own handle toward their stick at 70% speed, so the average moves the item and a difference turns it. Holders stay attached to their handles and let go if pulled too far off their spot. Loot and the flashlight share a carry base, `props/carryable.gd`. | Phase 3 plan approved; makes the doorway a turning puzzle |
| 14 | 2026-10-23 | A plain drop never damages loot: carried items hang a fixed 0.25 m above the floor (`CARRY_CLEARANCE`), so letting go lands below the 2.5 m/s threshold. Throws and bumps still cause damage. | Measured: the old hold height made every vase or TV drop cost about 46% of its value. User approved with “ok” |
| 13 | 2026-10-23 | Phase 2: only light loot is throwable; impact damage uses relative closing speed, counted once per distinct impact, rounded up to whole rupees and capped at remaining value. Build single-person spring carrying, a CSG Mansion greybox, banking and phone held-item feedback. | User approved the Phase 2 plan with “go” after confirming four-player phone operation |
| 12 | 2026-10-23 | Phase 1 uses flat JSON messages with a `type` field; slots are zero-based. Keyboard test: 1–4 selects a slot, WASD/arrows move, Space grabs, E throws, Shift braces. Connected phones take priority. | Proposed in the initial plan; implementation authorized by “replan then start” |
| 11 | 2026-10-23 | Keep local HTTP/WebSocket serving. Request Wake Lock where available and show manual screen-timeout guidance otherwise. | The plain LAN HTTP page is not a secure context; browser features must fail gracefully |
| 10 | 2026-10-23 | Typed GDScript, tabs, snake_case members/functions, PascalCase classes, UPPER_SNAKE_CASE constants, short header/section comments. Preserve filenames explicitly named in the spec; new supporting scripts use snake_case. All tunables live in Balance.gd; generate browser settings from it. | Style proposed in the plan and applied under the user's instruction to start Phase 1 |
| 9 | 2026-10-23 | Use the supplied Godot 4.7.2 stable build (`4.7.2.stable.official.ed1daf0bf`), Mobile renderer, Jolt, 60 Hz physics | Verified the supplied executable and the user-created project; keep both developer installations aligned |
| 8 | 2026-10-23 | Mobile renderer | User's choice. No volumetric fog or SSAO; depth fog, glow, shadows and particles are kept. |
| 7 | 2026-10-23 | Agent ground rules as written in `AGENTS.md` | Set by the user before development started |
| 6 | 2026-10-23 | Cross-platform development: no OS-specific paths, tools or commands | Two developers work on different operating systems |
| 5 | 2026-10-23 | `ghosted-movers-spec.md` v1 is the design baseline | Locked by the user |
| 4 | 2026-10-23 | One shared screen with an angled dollhouse camera; phones as controllers | Shared-screen party play demos best; phones let anyone join by QR code |
| 3 | 2026-10-23 | Godot 4, 3D | Better visuals, tools and native performance than the web engines considered (Phaser, PlayCanvas) |
| 2 | 2026-10-23 | Concept: Ghosted Movers | Chosen over Trap Draft and Admin Crown |
| 1 | 2026-10-23 | Problem statement PS02: Chaos Control | Chosen over PS01 |

## Open — needs the user's confirmation

- **A two-person item banks when the last holder lets go inside the truck zone.** If one holder lets go first, the other is left dragging until they let go too. This is how the build behaves; it is not yet confirmed as a decision.
- **Thrown or pushed loot landing in the truck zone does not bank.** Only releasing GRAB inside the zone banks, matching the spec's wording. This is how the build currently behaves; it is not yet confirmed as a decision.
