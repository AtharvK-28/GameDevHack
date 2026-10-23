# Ghosted Movers

Godot 4.7.2 stable · Mobile renderer · Jolt · 60 Hz physics.

## Play a match

1. Press **F5** in Godot. The shared screen opens fullscreen on the lobby with a QR code and the join link; **F11** switches between fullscreen and a window. (If Godot runs the game inside the editor's Game tab, fullscreen needs the game in its own window: turn off the Game tab's embed option.)
2. Start the phone page server (see the next section, step 2). Phones on the same Wi-Fi scan the QR code or open the link, enter a name and tap **Ready to move**. If opening the plain link, also enter the six-character code shown on the host.
3. With 2–4 phones ready, press **Enter** on the host. Each round: a 3 s role reveal, then 150 s of play. 2 players play 4 rounds, 3 play 3 and 4 play 4; the ghost passes to the next player every round.
4. **Winning a round:** movers must deliver at least **70%** of the round's starting value. Losing more than 30% (damage, shattering, items lost) ends the round for the ghost at once. Otherwise the round ends when time runs out or every item has been delivered or destroyed; only delivered value counts.
5. **Host keys.** Round end: **Enter** next round, **R** restart the round (same layout and roles; its points are replaced), **L** back to the lobby. Final standings: **Enter** back to the lobby. If a phone drops mid-round the round pauses until it rejoins from the same browser with its saved secret; **L** cancels to the lobby without scoring.
6. **The demo ghost** has POSSESS (any loose loot or the crate), SHOVE, SHAKE (House Shake, 45) and CURSE (30, 15 s cooldown: nearby loot glows and is 30% slower to carry for 6 s). Hauntings are locked for the first 8 s and for 4 s after each one; the ghost's phone shows why a button is unavailable and for how long. Keyboard ghost: Q possess, F action, Z shake, C curse.

Matches play in the **Old Mansion**, built from `arenas/layouts/mansion_layout.json` (the floor plan `mansion-layout.svg`): a raised gallery reached by stairs, the main room, the kitchen, a fenced garden, and the path to the truck. It is lit for dusk, with textured surfaces, glowing windows and decor. Camera-facing walls are solid until they hide a player, then fade; they always block. To change the house, edit the layout file; `arenas/arena_builder.gd` builds any arena from such a file. Decor, lamps and the grounds live in `arenas/dressing/MansionDressing.tscn`. Surface textures come from `tools/make_surface_textures.gd` (`godot --headless --path . --script res://tools/make_surface_textures.gd`, then open the editor to import). Asset sources and licences: `assets/CREDITS.md`.

Movers are the team's character model in their slot's colours; the model only shows what the mover is doing (walk, run, carry, two-person carry, brace, throw, tumble) and never changes how it plays. The source files and the model guide are in `assets/source/mover/`.

Points: movers get 1 per ₹100 they deliver (two-person items split) plus 100 for a win; the ghost gets 1 per ₹100 lost plus 150 for a win. Awards, more arenas and the other ghost abilities come later.

## Run the greybox harness

The Phase 4 sandbox, with every ghost ability and the G key, is still available: select the root node of `Main.tscn`, untick **Match Mode** in the Inspector, and run. Tick it again before committing. The checks below use the harness automatically.

### Harness steps

1. Import this folder's `project.godot` into Godot and press **F6 with Main.tscn open**, or **F5** to run the project. Only run one host at a time: it listens on port 9080.
2. In a terminal, change into `controller/` and start the page server:

   ```text
   python -m http.server 8080
   ```

   If your Python installation uses a different command, use `python3 -m http.server 8080` (commonly Linux/macOS) or `py -m http.server 8080` (Windows).

3. Put the laptop and phones on the same private Wi-Fi/hotspot. Open the `http://<laptop-ip>:8080` address shown in the game on each phone. Do not use `localhost` on phones. Use the address belonging to the shared network if the host lists several.
4. Hold the phone sideways, enter a name, join, and tap **Ready to move**. Each phone controls its own coloured mover. The page and nipplejs are served locally; internet is not needed.
5. To test with the keyboard, focus the game, select an unconnected slot with **1–4**, and move with **WASD/arrows**. **Space** holds Grab, **E** sends Throw, and **Shift** holds Brace. A connected phone takes priority over keyboard input for its slot.
6. To play the ghost, press **G** on the host: the ghost passes to the next active slot (a connected phone, or the keyboard's slot), and after the last one back to no ghost. That player's mover leaves the board and their phone switches to the green ghost screen. On the keyboard, **Q** possesses or leaves, **F** is the prop's ACTION, **Z** is House Shake and **X** is Ecto Slime.

**What to try.** The greybox is one CSG room with four vases, two TVs and a grandfather clock, a practice obstacle, and a green truck zone outside the doorway. A grand piano waits in the back parlour behind a knee-high wall with a 2 m doorway, and a flashlight lies by the front-left corner. The ghost's furniture: a crate on the left, the parlour door (open), a chandelier over the main lane, a suit of armour by the parlour wall and a red rug inside the front door.

- Hold **GRAB** facing an item to pick it up; it swings on a spring in front of you. Let go to put it down. A plain drop never damages loot.
- Medium and heavy items slow you down (80% and 60%). Only light items (the vases) can be thrown with **THROW**; throws land hard and take damage.
- Any hit above 2.5 m/s costs `impact speed × fragility × 4%` of the current value. The price tag ticks down and turns red, and a red "−₹" amount pops off the item. At ₹0 the item shatters.
- Release **GRAB** while standing in the truck zone to bank the item (in the Mansion: the green half-circle behind the truck's tailgate). Items thrown or pushed into the zone are not banked.
- The phone shows the held item and its value. A dropped connection or 500 ms without input drops whatever you carry.
- **Piano (two-person).** Face one end and hold GRAB to take that handle. With both handles held, each player's stick pulls their own end: push the same way to carry it at 70% speed, push differently to turn it. Turn it lengthwise to fit through the parlour doorway. With one handle you can only drag it at 25% (40% if you are the only mover), and dragging scrapes 1.5% of its value per metre. Get pulled too far off your handle and you lose your grip. It banks when the last hand lets go inside the truck.
- **Tumbling.** A thrown item hitting you above 4 m/s knocks you over: you drop what you carry, lie down for 1.5 s and get up automatically. Release and press GRAB again to pick something up afterwards. A possessed prop hitting you above 4 m/s, a slam, a stomp, a yank and moving during a House Shake do the same.
- **Flashlight.** Carry it like any light item (it can be thrown). Its beam follows the way you face; its aim ignores height. Hold the beam on a glowing possessed prop for 1.5 s to exorcise the ghost: the wisp is frozen for 1 s and can't possess anything for 5 s.

**The ghost.** A faint wisp that flies at 7 m/s through walls. The top-right bar shows everyone its energy: 100 at most, +12 per second while free, −8 per second while possessing (it is pushed out at 0). Every possessable prop has a faint green outline; the one the wisp would take is outlined brightly. The phone greys out anything the host would refuse right now and shows a ring while a haunting cools down.

- **Possess** a prop within reach (Q / POSSESS); press again to leave for free. Carried items and anything in the truck can't be possessed, and nobody can grab a possessed item.
- **Loot and the crate are sliders:** the stick glides them just below damage speed; **SHOVE** (15) launches them at 6 m/s, which smashes loot and knocks over movers.
- **Door: SLAM** (20) shuts it for 3 s, knocking over movers in its swing; loot in the way stops it and takes the hit.
- **Chandelier: DROP** (30) creaks for 1 s over a red floor marker, then falls on whatever is below. One use.
- **Armour: hops** along the stick; **STOMP** (25) knocks over everyone within 2 m, braced or not.
- **Rug: YANK** (25) knocks over everyone standing on it and slides the loot on it toward the parlour.
- **House Shake** (45, 20 s cooldown): a 1 s rumble warning, then 2.5 s in which anyone moving tumbles. Stand still or BRACE.
- **Ecto Slime** (25, 10 s cooldown): for 4 s the wisp leaves green patches that last 4 s each; movers on slime keep their momentum.

Gamepads are a later phase.

Allow the game (9080) and Python page server (8080) through the host's firewall on the private network if prompted. A second game instance shows a port-in-use error. Stop the first host before retrying. Stop Python with Ctrl+C when finished.

## Reconnect and phone behaviour

- The browser stores its player ID. Rejoin from the same browser to restore the slot and role; another browser is a new identity. Reloading the page requires tapping Join again, while temporary connection loss retries automatically.
- Slots stay reserved until the host restarts. Restart the game to clear the test roster. A fifth identity is declined without taking another player's slot.
- The host clears movement and held buttons after 500 ms without a valid input heartbeat, or immediately on a detected disconnect. Button press/release edges survive between physics frames.
- Fullscreen, orientation lock, vibration and Wake Lock depend on browser support. Ordinary LAN HTTP does not support Wake Lock; increase the phone's screen timeout for the demo. A rotate overlay covers portrait touch screens.

## Checks and tuning

The commands below use `godot` as the executable name. If it is not on PATH, substitute its installed path. In PowerShell, a quoted executable path must be preceded by `&`; in a POSIX shell, use the quoted executable path directly. No executable path is stored in this project.

```text
godot --headless --path . --editor --import
godot --headless --path . --script res://core/plumbing_check.gd
godot --headless --path . --script res://core/carrying_check.gd
godot --headless --path . --script res://core/team_carry_check.gd
godot --headless --path . --script res://core/ghost_check.gd
godot --headless --path . --script res://core/match_check.gd
godot --headless --path . --script res://core/arena_layout_check.gd
```

Close a running host before any integration check; they all open port 9080.

- `plumbing_check.gd` tests four clients, independent mover movement, malformed messages, joystick clamping, button edges, timeout, reconnect, capacity and keyboard fallback. Success ends with `PLUMBING CHECK: PASS` and exit code 0.
- `carrying_check.gd` runs real Jolt physics: pickup and spring settling, walking and 180° turns without launching, plain drops, grab selection, throwing, damage maths, wall hits, resting contact, banking exactly once, phone grab and HUD, heartbeat and disconnect drops, and two movers grabbing the same item in one tick. Success ends with `CARRYING CHECK: PASS` and exit code 0.
- `team_carry_check.gd` drives two simulated phones: two-person lift, 70% carry, average steering, turning, 25% drag with scraping, the lone-mover 40% drag, losing grip, the piano through the parlour doorway, tumbling from thrown items, and the flashlight's beam, wall blocking and 1.5 s exorcism timer against a stand-in target. Success ends with `TEAM CARRY CHECK: PASS` and exit code 0. The carrying checks remove the ghost's furniture first, so they test carrying alone.
- `ghost_check.gd` drives a mover phone and a ghost phone: the piano route past the open door, the G key and the movers-only lone-mover rule, wisp speed, walls, bounds and shimmer, energy gain and drain, every possession rule, all five prop actions and their costs, exorcism with the freeze and lock, House Shake, Ecto Slime, the ghost's `hud` (labels, costs, cooldowns, greying) and the Q/F/Z/X keys. Success ends with `GHOST CHECK: PASS` and exit code 0.
- `arena_layout_check.gd` checks the Old Mansion: room zones, doorway widths, walking from every room to the truck, carrying every weight up and down the stairs, two movers taking the piano down and back up, railings and walls holding movers and loot, walls fading only while they hide a player, the ghost spawning outside, decor keeping clear of every spawn spot, and arches and gates leaving their openings clear. Success ends with `ARENA LAYOUT CHECK: PASS` and exit code 0. The other checks run on the one-room greybox (`arenas/Greybox.tscn`).
- `match_check.gd` plays whole matches with two phones and the host keys: lobby and ready, Enter to start, a third phone refused mid-match, the seeded 6-item setup with one piano, reveal and live phases, the three-quarter camera following the mover, energy regeneration, opening protection, the shared haunting lock and their phone reasons, Curse (cost, no stacking, 30% slower carry for 6 s), the exact 70%/30% boundaries, an early ghost win, restart with the same layout and replaced points, ghost rotation, timeout, disconnect pause and resume, cancelling to the lobby, and a full 4-round match to the final standings. Success ends with `MATCH CHECK: PASS` and exit code 0.

Change tuning values in `autoload/Balance.gd`. After changing controller settings, regenerate the committed browser settings:

```text
godot --headless --path . --script res://core/export_controller_settings.gd
```

The browser consumes `controller/settings.json`; do not tune it independently. nipplejs is vendored at **0.10.2**, with its MIT license in `controller/nipplejs_license.txt`.

## Tuning the carry feel

The spring, turn speed and upright values are in `Balance.gd` under "Carrying settings"; the two-person values are under "Two-person carry settings". Change one at a time and re-run the checks.

## UI preview checkpoint

The themed title/map/options/credits screens are in `menus/`. The new lobby and edge HUD replace the earlier plain match panels. F5 still starts `Main.tscn` until the requested screenshot review; preview `menus/main_menu/main_menu.tscn` with F6 to inspect the title and map selection. Options include a saved 60-second Demo mode. Escape pauses, Tab holds the totals overlay. The HTTP page server command is unchanged; reload the phone page to load the new local font, colours and authenticated joining.

The QR includes a session key; manual joining needs the six-character lobby code. Reconnect uses a private per-player secret saved in that browser. New join code disconnects everyone and requires the new QR/code. Five bad credentials from one address temporarily lock it out; oversized messages and floods disconnect. `core/plumbing_check.gd` covers these cases in addition to four simultaneous controllers.
