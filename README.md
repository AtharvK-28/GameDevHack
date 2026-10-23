# Ghosted Movers

Godot 4.7.2 stable · Mobile renderer · Jolt · 60 Hz physics.

## Run the Phase 2 carrying greybox

1. Import this folder's `project.godot` into Godot and press **F6 with Main.tscn open**, or **F5** to run the project. Only run one host at a time: it listens on port 9080.
2. In a terminal, change into `controller/` and start the page server:

   ```text
   python -m http.server 8080
   ```

   If your Python installation uses a different command, use `python3 -m http.server 8080` (commonly Linux/macOS) or `py -m http.server 8080` (Windows).

3. Put the laptop and phones on the same private Wi-Fi/hotspot. Open the `http://<laptop-ip>:8080` address shown in the game on each phone. Do not use `localhost` on phones. Use the address belonging to the shared network if the host lists several.
4. Hold the phone sideways, enter a name, join, and tap **Ready to move**. Each phone controls its own coloured mover. The page and nipplejs are served locally; internet is not needed.
5. To test with the keyboard, focus the game, select an unconnected slot with **1–4**, and move with **WASD/arrows**. **Space** holds Grab, **E** sends Throw, and **Shift** holds Brace. A connected phone takes priority over keyboard input for its slot.

**What to try.** The greybox is one CSG room with four vases, two TVs and a grandfather clock, a practice obstacle, and a green truck zone outside the doorway.

- Hold **GRAB** facing an item to pick it up; it swings on a spring in front of you. Let go to put it down. A plain drop never damages loot.
- Medium and heavy items slow you down (80% and 60%). Only light items (the vases) can be thrown with **THROW**; throws land hard and take damage.
- Any hit above 2.5 m/s costs `impact speed × fragility × 4%` of the current value. The price tag ticks down and turns red, and a red "−₹" amount pops off the item. At ₹0 the item shatters.
- Release **GRAB** while standing in the truck zone to bank the item. Items thrown or pushed into the zone are not banked.
- The phone shows the held item and its value. A dropped connection or 500 ms without input drops whatever you carry.

Roles, the ghost, two-person carrying, scoring, the QR lobby and gamepads are later phases.

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
```

Close a running host before either integration check; both open port 9080.

- `plumbing_check.gd` tests four clients, independent mover movement, malformed messages, joystick clamping, button edges, timeout, reconnect, capacity and keyboard fallback. Success ends with `PLUMBING CHECK: PASS` and exit code 0.
- `carrying_check.gd` runs real Jolt physics: pickup and spring settling, walking and 180° turns without launching, plain drops, grab selection, throwing, damage maths, wall hits, resting contact, banking exactly once, phone grab and HUD, heartbeat and disconnect drops, and two movers grabbing the same item in one tick. Success ends with `CARRYING CHECK: PASS` and exit code 0.

Change tuning values in `autoload/Balance.gd`. After changing controller settings, regenerate the committed browser settings:

```text
godot --headless --path . --script res://core/export_controller_settings.gd
```

The browser consumes `controller/settings.json`; do not tune it independently. nipplejs is vendored at **0.10.2**, with its MIT license in `controller/nipplejs_license.txt`.

## Phase 2 acceptance still needed

With phones on the target network: carry a vase to the truck and bank it, and bump a carried vase into a wall to see its price visibly drop. Also judge the carry feel (swing, turn speed, lag behind the mover); the spring and turn values are in `Balance.gd` under "Carrying settings".
