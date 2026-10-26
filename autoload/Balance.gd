# Shared game and greybox settings. Distances are metres and times are seconds.
extends Node

# --- Network settings ---
const WEB_PORT: int = 8080
const SOCKET_PORT: int = 9080
const MAX_PLAYERS: int = 4

# --- Battery Run (optional Mansion task) ---
const BATTERY_COUNT: int = 3 # Deliver all three; no quota value.
const BATTERY_SIZE := Vector3(0.65, 0.55, 0.45) # Metres; heavy, single-mover carry.
const BATTERY_COLOUR := Color("e6af39") # Amber case, distinct from ordinary decor.
const BATTERY_METAL := Color("283340")
const GENERATOR_COLOUR := Color("66d9ff") # Cyan delivery zone, distinct from the green truck zone.
const GENERATOR_ZONE_SIZE := Vector3(2.4, 2.0, 2.4) # Metres; centre must be inside on release.
const GENERATOR_BODY_SIZE := Vector3(1.2, 1.0, 0.65) # Metres; sits behind the marked delivery zone.
const GENERATOR_COOLDOWN_RATIO: float = 1.5 # Haunting cooldown duration; abilities remain usable.
const GENERATOR_REGEN_RATIO: float = 0.5 # Free-wisp energy per second.
const GENERATOR_SPEED_RATIO: float = 0.75 # Free-wisp movement only.
const GENERATOR_AMBIENT_RATIO: float = 1.4 # Gentle ambient lift, preserving dusk colours.
const GENERATOR_MOON_RATIO: float = 1.15
const GENERATOR_LIGHT_FADE: float = 1.5 # Seconds to brighten after the final battery.
# --- Light the Lanterns (Ghost Ship task, decision 104); the ghost handicap reuses GENERATOR_* ---
const LANTERN_COUNT: int = 3
const OIL_CAN_SIZE := Vector3(0.4, 0.55, 0.4) # Metres; a medium, single-mover carry.
const OIL_CAN_COLOUR := Color("c4473a")
const OIL_CAN_SPOTS: Array[Vector3] = [ # x, deck height, z; three are picked per round by seed.
	Vector3(4.2, 1.2, 4.2), Vector3(1.9, 1.2, 4.2), Vector3(5.4, 1.2, 7.4), Vector3(11.0, 0.0, 8.9),
	Vector3(16.8, 0.0, 3.9), Vector3(13.9, 0.0, 8.4), Vector3(19.6, 0.0, 6.0), Vector3(24.4, 0.7, 5.6),
	Vector3(26.0, 0.7, 6.0)]
const LANTERN_POST_SPOTS: Array[Vector3] = [Vector3(8.7, 0.0, 18.2), Vector3(15.3, 0.0, 18.2), Vector3(2.2, 1.2, 8.8)] # x, deck height, z: two on the tug, one on the stern castle.
const LANTERN_ZONE_SIZE := Vector3(1.2, 2.0, 1.2) # Metres; the can's centre must be inside on release.
const LANTERN_POST_HEIGHT: float = 2.0
const LANTERN_LIT_COLOUR := Color("ffbf4a") # Warm flame, distinct from the cold blue deck lamps.
const LANTERN_DARK_COLOUR := Color("2b3240")
const LANTERN_GLOW: float = 6.0 # Emission strength of a lit lantern; no extra light (Ship omni budget).
const LANTERN_LAMP_RATIO: float = 1.6 # Ship deck lamps brighten by this once all lanterns are lit.
const LANTERN_SEED_OFFSET: int = 6151 # Separate can placement from the seeded loot selection.
const TASK_LABEL_PIXEL_SIZE: float = 0.006 # World metres per label pixel.
const TASK_LABEL_HEIGHT: float = 1.4 # Metres above the generator zone.
const BATTERY_RECOVERY_DEPTH: float = -3.0 # Metres; return a battery that escapes below the arena.
const BATTERY_SEED_OFFSET: int = 7919 # Separate battery placement from the seeded loot selection.

# --- Controller cadence ---
const INPUT_RATE: int = 30 # Messages per second, including idle heartbeats.
const HUD_RATE: int = 8 # Messages per second in later gameplay phases.
const INPUT_TIMEOUT_MS: int = 500
const MAX_PACKETS_PER_FRAME: int = 64
const MAX_NAME_LENGTH: int = 20

# --- Connection security (autoload/Net.gd; the phone page reads the same rules from controller/settings.json) ---
const SESSION_KEY_BYTES: int = 16 # 128-bit key per host start, carried in the QR link.
const PLAYER_SECRET_BYTES: int = 16 # 128-bit secret per player; a rejoin needs it with the pid.
const JOIN_CODE_LENGTH: int = 6 # Short code for typing the key in by hand.
const JOIN_CODE_LETTERS: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" # No 0/O, 1/I/L look-alikes.
const AUTH_TIMEOUT_MS: int = 2000 # A new socket must send a valid hello within this.
const MAX_PENDING_PEERS: int = 4 # Sockets not yet logged in, at once.
const MAX_MESSAGE_BYTES: int = 1024 # Larger messages disconnect.
const RATE_LIMIT_PER_SECOND: float = 100.0 # Normal phones send about 38 messages a second.
const RATE_LIMIT_BURST: float = 150.0 # Messages a socket may send at once before the limit applies.
const CODE_LOCKOUT_FAILURES: int = 5 # Wrong keys or codes from one address within the window lock it out.
const CODE_LOCKOUT_WINDOW_MS: int = 60000
const CODE_LOCKOUT_MS: int = 60000
const RECONNECT_DELAY_MS: int = 1000
const PLAYER_COLOURS: Array[String] = ["#ffb84d", "#64d9ee", "#ed8bb6", "#b6de70"]

# --- Movement and test-scene settings ---
const MOVER_SPEED: float = 4.5 # Metres per second; unchanged from the spec.
const MOVER_ACCELERATION: float = 15.0 # Metres per second squared; about 0.3 s from standing to full speed.
const MOVER_DECELERATION: float = 30.0 # Metres per second squared when stopping or reversing; about 0.15 s.
const STICK_RESPONSE_EXPONENT: float = 1.6 # Speed = tilt ^ this, so small tilts walk gently; 1 is linear.
const GRAVITY: float = 9.8 # Metres per second squared.
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.6
const FLOOR_SIZE: float = 28.0
const FLOOR_THICKNESS: float = 0.2
const SPAWN_SPACING: float = 2.5
const CAMERA_DISTANCE: float = 21.0
const CAMERA_TARGET := Vector3(0.0, 0.0, -3.0) # Centre of the greybox between the parlour and the truck.
const CAMERA_ANGLE: float = 55.0 # Degrees down from horizontal.
const CAMERA_YAW: float = -40.0 # Three-quarter view, degrees; negative looks in from the house's left.
const CAMERA_MIN_DISTANCE: float = 12.0
const CAMERA_MAX_DISTANCE: float = 26.0
const CAMERA_FOLLOW_RATE: float = 3.0 # Exponential easing per second.
const CAMERA_FRAME_PADDING: float = 2.5 # Metres around the movers.
const CAMERA_SAFE_VIEW: float = 0.8 # Fraction of the viewport used for framing.
const CAMERA_BOUNDS := Rect2(-6.0, -10.0, 12.0, 15.0) # The x/z area the camera's focus may move within: house and truck.
const LABEL_HEIGHT: float = 1.35
const LABEL_FONT_SIZE: int = 48
const LABEL_PIXEL_SIZE: float = 0.01 # World metres per label pixel.
const LABEL_OUTLINE: int = 14 # Ink outline on name tags.
const LABEL_SPREAD_DISTANCE: float = 2.6 # Metres: movers this close stack their name tags (long names are wide).
const LABEL_STACK_STEP: float = 0.7 # Metres each stacked tag rises.
const FLOOR_LABEL_PIXEL_SIZE: float = 0.011 # Zone markings painted on the ground (truck, generator).
const FLOOR_LABEL_HEIGHT: float = 0.06 # Metres above the floor, clear of the zone pads (up to 0.045 m).
const FLOOR_LABEL_ALPHA: float = 0.9
const LIGHT_ROTATION := Vector3(-55.0, -25.0, 0.0) # Degrees.
const OVERLAY_MARGIN: float = 16.0 # Pixels.
const JOYSTICK_SIZE: int = 120 # CSS pixels.
const JOYSTICK_DEADZONE: float = 0.15 # Normalised stick magnitude, 0 to 1; the phone rescales past it, so there is no jump.

# --- Goofy physics settings (turned up; mostly visual) ---
# To tone it back down: set GOOFINESS to 1.0 and the three *_DAMPING values to 12, 14 and 10 (decision 84's mild
# settings), and LIGHT_LOOT_BOUNCE to 0.2. GOOFINESS 0 turns every effect below off.
const GOOFINESS: float = 1.8 # Scales every effect below: 0 turns them off, 1 is mild, 2 doubles them.
const LEAN_MAX: float = 8.0 # Degrees a mover's body tilts into speeding up, stopping and turning.
const LEAN_FULL_ACCELERATION: float = 15.0 # Metres per second squared that gives the full lean.
const LEAN_STIFFNESS: float = 120.0 # Spring pulling the lean to its target, per degree.
const LEAN_DAMPING: float = 8.0 # Lower is bouncier: well below 2 * sqrt(stiffness), so the lean overshoots and rocks back.
const SQUASH_STIFFNESS: float = 300.0 # Spring returning a squash or stretch to normal.
const SQUASH_DAMPING: float = 9.0 # Lower is bouncier.
const SQUASH_GRAB: float = 0.06 # Fraction of height; positive squashes, negative stretches.
const SQUASH_THROW: float = -0.06
const SQUASH_LAND: float = 0.08 # At LAND_SQUASH_SPEED or faster.
const LAND_SQUASH_SPEED: float = 4.0 # Metres per second of fall for the full landing squash.
const SQUASH_GET_UP: float = -0.07
const SQUASH_BUMP: float = 0.05
const BUMP_MIN_SPEED: float = 1.0 # Metres per second two movers must close at to bump.
const BUMP_SHOVE: float = 1.5 # Metres per second each bumped mover is pushed apart.
const BUMP_SHOVE_DECAY: float = 6.0 # Per second; the shove fades over about half a second.
const BUMP_COOLDOWN: float = 0.4 # Seconds before the same mover can bump again.
const JIGGLE_MAX: float = 0.1 # Fraction of size an item wobbles at most.
const JIGGLE_FULL_SPEED: float = 6.0 # Metres per second of impact for the full jiggle.
const JIGGLE_MIN_SPEED: float = 1.0 # Softer touches don't jiggle.
const JIGGLE_GRAB: float = 0.04
const JIGGLE_THROW: float = -0.06
const JIGGLE_STIFFNESS: float = 260.0 # Settles in about 0.4 s.
const JIGGLE_DAMPING: float = 6.0 # Lower is bouncier: items wobble for longer after a knock.

# --- Carrying settings ---
const WORLD_LAYER: int = 1
const MOVER_LAYER: int = 2
const LOOT_LAYER: int = 4 # Loose physics props: loot and furniture.
const LIGHT: int = 0 # Weight classes, used as indexes into the tables below.
const MEDIUM: int = 1
const HEAVY: int = 2
const TWO_PERSON: int = 3
const CARRY_SPEEDS: Array[float] = [1.0, 0.8, 0.6, 0.7] # By weight class; two-person with both handles held.
const WEIGHT_MASSES: Array[float] = [2.0, 8.0, 20.0, 100.0] # Kilograms, by weight class.
const GRAB_RANGE: float = 1.8
const GRAB_HALF_ANGLE: float = 60.0 # Degrees either side of facing.
const HOLD_DISTANCE: float = 1.25
const CARRY_CLEARANCE: float = 0.25 # Gap under a carried item; below 0.31 a plain drop lands under the damage threshold.
const GRIP_HEIGHT_RATIO: float = 0.25 # Fraction of item height above its centre.
const CARRY_STIFFNESS: float = 150.0 # Spring acceleration per metre of error.
const CARRY_DAMPING: float = 18.0 # Damping acceleration per m/s of relative speed.
const CARRY_MAX_FORCE: float = 1600.0 # Newtons.
const CARRY_MAX_STRETCH: float = 1.0 # Metres of spring error used at most, so a far-off item cannot snap back at high speed.
const TURN_SPEED: float = 5.0 # Radians per second the facing and hold point swing toward the stick.
const CARRY_UPRIGHT_STIFFNESS: float = 60.0 # Angular acceleration per radian of tilt while carried.
const CARRY_UPRIGHT_DAMPING: float = 10.0 # Angular acceleration per rad/s of spin while carried.
const LOOT_MAX_SPEED: float = 12.0 # Metres per second.
const LOOT_MAX_SPIN: float = 12.0 # Radians per second.
const LOOT_LINEAR_DAMP: float = 0.15
const LOOT_ANGULAR_DAMP: float = 1.0
const LOOT_FRICTION: float = 0.6
const LOOT_BOUNCE: float = 0.1
const LIGHT_LOOT_BOUNCE: float = 0.3 # Light items skitter when dropped (goofy physics).
const THROW_SPEED: float = 7.0 # Metres per second added in the facing direction.
const THROW_LIFT: float = 2.0 # Metres per second upwards.

# --- Two-person carry settings ---
const DRAG_SPEED: float = 0.25 # Fraction of mover speed when one handle drags.
const LONE_DRAG_SPEED: float = 0.4 # Fraction of mover speed for a lone mover's drag.
const SCRAPE_RATE: float = 0.015 # Fraction of current value lost per metre dragged.
const SCRAPE_POPUP_INTERVAL: float = 0.5 # Seconds between scrape-loss popups.
const TEAM_DRIVE_GAIN: float = 20.0 # Per second; how quickly a handle matches its holder's stick.
const TEAM_MAX_FORCE: float = 1500.0 # Newtons per handle.
const TEAM_LIFT_MAX_FORCE: float = 3000.0 # Newtons holding a two-person item up.
const DRAG_SUPPORT: float = 0.9 # Fraction of weight supported while dragging, so the item slides instead of sticking.
const TEAM_STAND_DISTANCE: float = 0.6 # Metres beyond a handle where its holder stands.
const TEAM_FOLLOW_GAIN: float = 12.0 # Per second; how quickly a holder keeps up with their handle.
const TEAM_LEASH: float = 1.0 # Metres a holder can be pulled off their spot before letting go.

# --- Tumbling settings ---
const TUMBLE_HIT_SPEED: float = 4.0 # Metres per second; a thrown prop faster than this knocks a mover over.
const TUMBLE_DURATION: float = 1.5 # Seconds lying down.
const TUMBLE_FALL_TIME: float = 0.2 # Seconds of margin the checks allow after the down time.
const TUMBLE_BUZZ_MS: int = 200

# --- Mover character model (visual only; from assets/source/mover/MOVER_GUIDE.md) ---
const MOVER_MODEL_PATH: String = "res://assets/models/mover/mover_%s.glb" # Filled with the shirt colour.
const MOVER_SHIRTS: Array[String] = ["green", "orange", "green", "red"] # By slot, to contrast with the overalls.
const MOVER_MODEL_HEIGHT: float = 1.757 # Metres, as modelled.
const MOVER_MODEL_SCALE: float = CAPSULE_HEIGHT / MOVER_MODEL_HEIGHT # Fits the model to the 1.6 m capsule.
const MODEL_NATURAL_SPEEDS: Dictionary = { # Ground speed (m/s, at full model size) where each clip's feet don't slide.
	"walk": 1.6, "run": 4.5, "carry_run": 3.6, "carry_heavy_walk": 2.7, "team_carry_walk": 3.15, "drag": 1.1,
}
const MODEL_WALK_RUN_SWITCH: float = 2.2 # Metres per second; empty-handed walk/run cut-over.
const MODEL_MOVE_THRESHOLD: float = 0.2 # Metres per second; slower counts as standing.
const MODEL_BLEND_TIME: float = 0.12 # Seconds of cross-fade between clips.
const MODEL_REACH_STRETCH: float = 1.4 # Maximum visual arm extension (a snagged item can lag 1.6 m; 3.5 made noodle arms); does not move loot or colliders.
const MODEL_REACH_BEND: float = 1.05 # Keeps a slight elbow bend while reaching.
const MODEL_REACH_EPSILON: float = 0.001 # Metres; avoids a straight-arm singularity.
const MODEL_SPEED_SCALE_MIN: float = 0.5 # Limits on clip playback speed.
const MODEL_SPEED_SCALE_MAX: float = 1.8
const MODEL_TRIM_LIGHTEN: float = 0.35 # Overall cuffs and cap strap, lighter than the slot colour.
const MODEL_SEAM_DARKEN: float = 0.55 # Seams and pocket edges, darker than the slot colour.

# --- Ghost settings ---
const GHOST_MODEL_PATH: String = "res://assets/models/ghost/ghost.glb"
const WISP_SPEED: float = 7.0 # Metres per second; the wisp passes through walls.
const WISP_HEIGHT: float = 1.2 # Metres above the floor.
const WISP_RADIUS: float = 0.35
const WISP_BODY_HEIGHT: float = 0.9 # A tall egg, like a bedsheet ghost.
const WISP_COLOUR := Color("e4fff3")
const WISP_FROZEN_COLOUR := Color("9fb4c9") # Tint while frozen after an exorcism.
const WISP_ALPHA_MIN: float = 0.25 # Opacity shimmers between these, 0 to 1.
const WISP_ALPHA_MAX: float = 0.45
const WISP_SHIMMER_RATE: float = 1.5 # Shimmer cycles per second.
const WISP_BOB_HEIGHT: float = 0.08 # Metres of gentle bobbing.

# --- Ghost Ship ghost: the drowned captain (decision 103) ---
# An original captain built from simple shapes in GhostCaptainModel, which animates him in code.
const CAPTAIN_DROP: float = -1.0 # Metres below the wisp's node, so his tail hovers just off the deck.
const CAPTAIN_FACING_OFFSET: float = 0.0 # He is built facing +Z.
const CAPTAIN_COAT_COLOUR := Color("23365c")
const CAPTAIN_TRIM_COLOUR := Color("e0b54a")
const CAPTAIN_SKIN_COLOUR := Color("9fc7b0")
const CAPTAIN_HAT_COLOUR := Color("1b1a22")
const CAPTAIN_BEARD_COLOUR := Color("6fc79d")
const CAPTAIN_EYE_COLOUR := Color("fff27a")
const CAPTAIN_TAIL_COLOUR := Color("b8f2d6")
const CAPTAIN_LANTERN_COLOUR := Color("ffcf5a")
const CAPTAIN_BEARD_SWAY: float = 0.35 # Radians each beard tentacle swings.
const CAPTAIN_BEARD_RATE: float = 1.3 # Beard sway cycles per second.
const CAPTAIN_BEARD_TILT: float = 0.45 # Radians the beard juts forward off his coat.
# He sits over a brightly lit deck, so below about 0.75 the deck bleeds through and washes him out.
const CAPTAIN_ALPHA_MIN: float = 0.80 # Opacity shimmers between these, 0 to 1.
const CAPTAIN_ALPHA_MAX: float = 0.93
const CAPTAIN_TINT_COLOUR := Color("6fd9a8") # The sea green his colours are washed toward.
const CAPTAIN_TINT_AMOUNT: float = 0.1 # 0 keeps his own colours, 1 makes him fully ghost-green.
const CAPTAIN_FROZEN_TINT_AMOUNT: float = 0.6 # Washed out much harder while frozen after an exorcism.
const CAPTAIN_RIM_COLOUR := Color("8cffc4") # The ghost-green fresnel edge.
const CAPTAIN_RIM_GLOW: float = 0.7 # How hard the edge glows; above about 1.5 it blows out his colours.
const CAPTAIN_RIM_POWER: float = 4.0 # Higher keeps the glow tight to his outline.
const CAPTAIN_SELF_GLOW: float = 0.5 # How much his own colours glow, so he reads on a dark deck.
const CAPTAIN_RIM_OPACITY: float = 0.22 # How much the edge firms him up, 0 to 1.
const CAPTAIN_TURN_RATE: float = 8.0 # How sharply he swings round to face his travel direction.
const CAPTAIN_LEAN: float = 0.18 # Radians of forward lean at full speed.
const CAPTAIN_SWAY_RATE: float = 0.6 # Idle sway cycles per second.
const CAPTAIN_SWAY_ANGLE: float = 0.05 # Radians of idle sway.
const CAPTAIN_MOVE_THRESHOLD: float = 0.3 # Metres per second below which he counts as hovering still.
const CAPTAIN_LEAN_RATE: float = 6.0 # How fast the lean eases in and out.
# Action lengths in seconds, matching the clips the bedsheet wisp plays so no timing shifts.
const CAPTAIN_EMERGE_TIME: float = 0.5
const CAPTAIN_CAST_TIME: float = 0.8
const CAPTAIN_EJECT_TIME: float = 0.6
const CAPTAIN_EMERGE_OVERSHOOT: float = 0.35 # Extra scale at the peak of the pop-out, 0 to 1.
const CAPTAIN_CAST_SHAKE: float = 0.07 # Radians of shake while casting.
const CAPTAIN_CAST_SHAKE_RATE: float = 11.0 # Shake cycles per second.
const CAPTAIN_EJECT_SPINS: float = 1.5 # Full turns while being blasted out of a prop.
const CAPTAIN_DIZZY_ANGLE: float = 0.22 # Radians of wobble while stunned.
const CAPTAIN_DIZZY_RATE: float = 2.6 # Wobble cycles per second.
const GHOST_BOUNDS := Rect2(-7.5, -12.0, 15.0, 19.0) # The x/z area the wisp may roam: the house and the truck.
const GHOST_SPAWN := Vector2(0.0, -10.9) # Far end of the parlour.
const ENERGY_MAX: float = 100.0
const ENERGY_REGEN: float = 12.0 # Per second while a free wisp.
const MATCH_ENERGY_REGEN: Array[float] = [8.0, 10.0, 12.0] # By number of movers.
const HAUNT_SHARED_LOCK: float = 4.0 # Seconds between hauntings.
const HAUNT_OPENING_GRACE: float = 8.0 # Seconds from live round start.
const CURSE_DURATION: float = 6.0
const CURSE_COST: int = 30
const CURSE_COOLDOWN: float = 15.0
const CURSE_CARRY_RATIO: float = 0.7 # Multiplies carry and drag speed, not the spring.
const CURSE_COLOUR := Color("cf80ff")
const POSSESS_DRAIN: float = 8.0 # Per second while possessing.
const POSSESS_RANGE: float = 1.2 # Metres from a prop's footprint (was 0.6: too fiddly to hit on the big screen).
const POSSESS_AIM_BONUS: float = 0.5 # Metres of reach credited to a prop straight ahead of the ghost's last movement.
const POSSESS_AIM_DEADZONE: float = 0.3 # Stick tilt needed to update the ghost's aim.
const POSSESS_LOCKOUT: float = 5.0 # Seconds after an exorcism before the ghost can possess again.
const EXORCISE_FREEZE: float = 1.0 # Seconds the ejected wisp cannot move or press anything.

# --- Match settings ---
const ROUND_SECONDS: float = 150.0
const REVEAL_SECONDS: float = 3.0
const DELIVERY_PERCENT: int = 70 # Integer arithmetic keeps the exact boundary fair.
const LOOT_COUNTS: Array[int] = [6, 9, 12] # For 2, 3, 4 players.
const HEAVY_LOOT_LIMITS: Array[int] = [1, 2, 2] # Most heavy items a round spawns, for 2, 3, 4 players.
const MATCH_ROUNDS: Array[int] = [4, 3, 4]
const RUPEES_PER_POINT: float = 100.0
const MOVER_WIN_BONUS: float = 100.0
const GHOST_WIN_BONUS: float = 150.0
const LOST_ITEM_Y: float = -10.0 # Metres below the arena; permanently lost.
const MATCH_SPAWN_POINTS: Array[Vector2] = [
	Vector2(-4.5, -10.5), Vector2(4.5, -10.5), Vector2(-4.5, -6.5),
	Vector2(4.5, -6.5), Vector2(-4.5, -3.5), Vector2(4.5, -3.5),
	Vector2(-4.5, -0.5), Vector2(4.5, -0.5), Vector2(-2.0, -3.5),
	Vector2(2.0, -3.5), Vector2(0.0, -0.5),
]

# --- Host screen settings (pixels at the 1152 × 648 base size; the window scales them) ---
const HOST_FONT_SIZE: int = 22
const HOST_SMALL_SIZE: int = 16
const HOST_TITLE_SIZE: int = 42
const HOST_COUNTDOWN_SIZE: int = 96
const HOST_PANEL_WIDTH: float = 680.0
const HOST_CREW_WIDTH: float = 260.0
const HOST_PANEL_PADDING: int = 20
const HOST_ROW_GAP: int = 10
const HOST_CORNER_RADIUS: int = 12
const HOST_OUTLINE_SIZE: int = 4
const HOST_PANEL_COLOUR := Color(0.086, 0.165, 0.169, 0.97)
const HOST_TEXT_COLOUR := Color("f7f1df")
const HOST_MUTED_COLOUR := Color("a9bdb8")
const HOST_ACCENT_COLOUR := Color("ffb84d")
const HOST_GHOST_COLOUR := Color("6dff8a")
const HOST_OUTLINE_COLOUR := Color("0b1414")
const QR_DISPLAY_SIZE: float = 222.0
const QR_MODULE_PIXELS: int = 6 # Source image pixels per QR module; scaled with nearest filtering.
const QR_QUIET_MODULES: int = 4 # Light border the standard asks for.
const HUD_MARGIN: float = 10.0 # Gap between the live HUD panels and the screen edge.
const HUD_PANEL_PADDING: int = 8
const HUD_ROW_GAP: int = 3
const HUD_TIMER_SIZE: int = 30
const HUD_TEXT_SIZE: int = 13
const HUD_BAR_SIZE := Vector2(300.0, 10.0)
const HUD_ENERGY_BAR_SIZE := Vector2(150.0, 10.0)
const HUD_MARKER_WIDTH: float = 3.0
const HUD_MARKER_OVERHANG: float = 4.0 # Pixels the 70% tick reaches above and below the bar.

# --- UI look (assets/ui/ghosted_theme.tres is made from these by tools/make_ui_theme.gd; base 1152 × 648) ---
const UI_NIGHT := Color("1a1228") # Screen backgrounds.
const UI_PANEL := Color("2b2142") # Panels and cards.
const UI_PANEL_ALPHA: float = 0.88 # 0 to 1: menu panels.
const UI_HUD_ALPHA: float = 0.72 # 0 to 1: HUD panels over the game.
const UI_BUTTON := Color("5b4691") # Buttons and tabs.
const UI_BUTTON_HOVER := Color("7a62bd")
const UI_TEXT := Color("f4efff")
const UI_MUTED := Color("b8acd9")
const UI_GHOST := Color("6dff8a") # Ghost green: the ghost, Start and Play.
const UI_MONEY := Color("ffd04a") # Gold for rupees, distinct from player 1's amber.
const UI_DANGER := Color("ff6b6b")
const UI_OUTLINE := Color("120b1d") # Text outline over the game world.
const UI_FONT_WEIGHT: int = 700 # Baloo 2 is a variable font, 400 to 800.
const UI_TITLE_WEIGHT: int = 800
const UI_BODY_SIZE: int = 18 # 30 px at 1080p; the projector needs 28 px or more.
const UI_SMALL_SIZE: int = 17 # 28 px at 1080p: the smallest text anywhere.
const UI_HEADING_SIZE: int = 30
const UI_TITLE_SIZE: int = 64
const UI_BUTTON_SIZE: int = 22
const UI_OUTLINE_SIZE: int = 5
const UI_PANEL_MARGIN: int = 18 # Padding inside panels.
const UI_FOCUS_WIDTH: int = 3 # Keyboard focus ring, ghost green.
const UI_POP_TIME: float = 0.35 # Seconds for a pop-in with overshoot.
const UI_POP_START: float = 0.6 # Scale a pop-in starts from.
const UI_SQUASH_SCALE := Vector2(1.08, 0.88) # A pressed button's squash.
const UI_SQUASH_TIME: float = 0.18 # Seconds back to normal.
const UI_WIPE_TIME: float = 0.35 # Seconds for each half of the wipe between screens.
const UI_PAGE_SLANT: float = 0.3 # The wipe's page-turn edge leans by this share of the screen height.
const UI_PAGE_FOLD: float = 90.0 # Pixels of folded paper at the page's top corner.
const UI_PAGE_EDGE: float = 6.0 # Ink line along the page's edge.
const UI_SCREEN_MARGIN: float = 16.0 # 28 px at 1080p: HUD distance from the screen edges.
const TITLE_DIM: float = 0.5 # 0 to 1: how much the night colour covers the Mansion behind the title.
const TITLE_ORBIT_SPEED: float = 3.0 # Degrees per second the title camera circles the Mansion.
const TITLE_CAMERA_PITCH: float = 38.0 # Degrees down.
const TITLE_CAMERA_DISTANCE: float = 30.0 # Metres from the Mansion's centre.
const MAP_TILE_SIZE := Vector2(300.0, 300.0) # Map select tiles.

# --- Comic style (match screens) ---
# The intro's comic look carried into the UI: parchment caption boxes and dark panels with thick ink borders and a
# hard drop shadow, speech bubbles, slam-in stamps and comic lettering (Bangers) for headlines and events.
const COMIC_FONT_PATH: String = "res://assets/fonts/bangers_regular.ttf"
const COMIC_PAPER := Color("f6e7bd") # Caption boxes, like the intro's narration boxes.
const COMIC_INK := Color("120b1d") # Borders, shadows and text on paper.
const COMIC_BORDER: int = 3 # Ink border width.
const COMIC_SHADOW := Vector2(5.0, 5.0) # Hard drop shadow offset.
const COMIC_SHADOW_ALPHA: float = 0.75
const COMIC_CORNER: int = 6 # Panel corner radius; bubbles use COMIC_BUBBLE_CORNER.
const COMIC_BUBBLE_CORNER: int = 22
const COMIC_TAIL_SIZE := Vector2(26.0, 22.0) # A speech bubble's tail: width at the bubble, length.
const COMIC_TITLE_SIZE: int = 56 # Comic lettering sizes.
const COMIC_HEADING_SIZE: int = 34
const COMIC_LABEL_SIZE: int = 24
const COMIC_OUTLINE_SIZE: int = 10 # Ink outline on comic lettering over the game.
const COMIC_STAMP_ANGLE: float = -7.0 # Degrees a stamp is tilted.
const COMIC_STAMP_START: float = 2.4 # Scale a stamp slams down from.
const COMIC_STAMP_TIME: float = 0.22 # Seconds the slam takes.
const COMIC_BACKDROP_ALPHA: float = 0.72 # 0 to 1: the night colour over the game behind full screens.
const COMIC_DOT_ALPHA: float = 0.12 # 0 to 1: halftone dots on the backdrop.
const COMIC_DOT_SPACING: float = 14.0 # Pixels between halftone dots.
const NAME_MAX_CHARS: int = 12 # Host screens shorten longer names with an ellipsis.
const KEYCAP_SIZE: int = 16 # Key hint text beside buttons.
const TIME_CARD_SIZE := Vector2(250.0, 118.0) # Lobby time cards, one per player slot, in a 2 × 2 grid.
const TIME_CARD_FIGURE: float = 58.0 # The mover silhouette on a time card.
const LOBBY_QR_SIZE: float = 190.0 # The QR code on the job sheet.
const MOVER_SKIN := Color("e8b98a") # Faces on drawn mover figures.
const REVEAL_GHOST_ART: String = "res://assets/cutscenes/intro/08_seth_ji.jpeg" # Seth-ji, cropped for the reveal.
const REVEAL_GHOST_CROP := Rect2(448.0, 104.0, 290.0, 330.0) # Pixels of that panel.
const REVEAL_PORTRAIT_SIZE := Vector2(190.0, 212.0)
const REVEAL_FIGURE: float = 78.0 # Line-up figures.
const REVEAL_MOVE_SECONDS: float = 0.45 # The countdown shows MOVE! for its last this many seconds.
const RESULT_TILE_WIDTH: float = 170.0 # Round end stat tiles.
const MENU_TITLE_SIZE: int = 76 # The home menu's comic title.
const MAP_PREVIEW_ART: String = "res://assets/cutscenes/intro/05_mansion_owner.jpeg" # The Mansion's map card.
const MAP_PREVIEW_CROP := Rect2(470.0, 40.0, 440.0, 440.0)
const RESULT_FIGURE: float = 40.0 # Role figures on round end rows.
const RESULT_ROW_WIDTH: float = 360.0
const COUNT_UP_TIME: float = 0.9 # Seconds round points take to count up.
const PODIUM_HEIGHTS: Array[float] = [150.0, 105.0, 72.0] # First, second and third place blocks.
const PODIUM_WIDTH: float = 160.0
const PODIUM_FIGURE: float = 72.0
const PODIUM_RISE_TIME: float = 0.45 # Seconds each block takes to rise; third rises first.
const PODIUM_STAGGER: float = 0.3 # Seconds between blocks.

# --- Possession settings ---
const ACTION_LABELS: Array[String] = ["SHOVE", "SLAM", "DROP", "STOMP", "YANK"] # By possessable kind: slider, door, dropper, hopper, rug.
const ACTION_COSTS: Array[int] = [15, 20, 30, 25, 25] # Energy, by possessable kind.
const POSSESS_COLOUR := Color("6dff8a")
const OUTLINE_GROW: float = 0.03 # Metres the outline shell stands off a prop.
const OUTLINE_IDLE_ALPHA: float = 0.2 # Every possessable prop's faint outline.
const OUTLINE_TARGET_ALPHA: float = 0.85 # The prop the free wisp would possess.
const GLOW_GROW: float = 0.05
const GLOW_ALPHA_MIN: float = 0.35 # A possessed prop's glow pulses between these.
const GLOW_ALPHA_MAX: float = 0.6
const GLOW_PULSE_RATE: float = 2.0 # Pulses per second.
const DRIP_AMOUNT: int = 10
const DRIP_LIFETIME: float = 0.8
const DRIP_SIZE: float = 0.06 # Metres across.

# --- Possessed prop settings ---
const SLIDER_SPEED: float = 2.4 # Just under the damage threshold, so plain sliding never breaks anything.
const SHOVE_SPEED: float = 6.0
const POSSESS_SPEED_FACTORS: Array[float] = [1.0, 0.8, 0.6, 0.45] # By weight class, for sliding and SHOVE.
const POSSESS_SUPPORT: float = 0.9 # Fraction of a sliding prop's weight the ghost holds up, so it glides.
const POSSESS_DRIVE_GAIN: float = 10.0 # Per second; how quickly a possessed prop matches the stick.
const POSSESS_MAX_ACCELERATION: float = 15.0 # Metres per second squared.
const SHOVE_DRIVE_PAUSE: float = 0.5 # Seconds a shove runs before the stick steers again.
# ROLL (decision 108): a possessed rolling item (the rum barrels) is bowled instead of shoved. It turns side-on,
# rolls freely so ramps and steps speed it up, and knocks over every mover it reaches while still rolling.
const ROLL_LABEL: String = "ROLL"
const ROLL_SPEED: float = 4.5 # Metres per second at release.
const ROLL_TUMBLE_SPEED: float = 1.5 # A rolling barrel knocks movers over until it slows below this.
const ROLL_DRIVE_PAUSE: float = 2.5 # Seconds the stick leaves it alone, so it rolls on down slopes.
const HOP_INTERVAL: float = 0.55
const HOP_SPEED: float = 2.5 # Metres per second along the stick.
const HOP_LIFT: float = 3.5 # Metres per second upwards.
const LANDED_SPEED: float = 0.3 # Vertical speed below which a hopping or falling prop counts as landed.
const STOMP_RADIUS: float = 2.0
const SHOCKWAVE_TIME: float = 0.35 # Seconds the stomp ring takes to spread.
const DOOR_OPEN_ANGLE: float = 100.0 # Degrees from shut; the door opens into the main room.
const DOOR_SLAM_TIME: float = 0.3
const DOOR_LOCK_TIME: float = 3.0
const DOOR_REOPEN_TIME: float = 1.0
const DOOR_THICKNESS: float = 0.12
const DOOR_GAP: float = 0.05 # Metres between the shut door and the far jamb.
const DOOR_COLOUR := Color("7b5a8c")
const CHANDELIER_SIZE := Vector2(1.2, 0.5) # Diameter and height, metres.
const CHANDELIER_HEIGHT: float = 2.8 # Bottom above the floor; it lands on a head faster than 4 m/s.
const CHANDELIER_CREAK_TIME: float = 1.0
const CHANDELIER_WOBBLE_ANGLE: float = 6.0 # Degrees of creaking sway.
const CHANDELIER_WOBBLE_RATE: float = 3.0 # Sways per second.
const CHANDELIER_CHAIN_LENGTH: float = 1.5
const CHANDELIER_CHAIN_RADIUS: float = 0.03
const CHANDELIER_SETTLE_TIME: float = 0.3 # Seconds of falling before it can count as landed.
const CHANDELIER_COLOUR := Color("e2c15b")
const MARKER_COLOUR := Color(1.0, 0.35, 0.25, 0.55)
const RUG_SIZE := Vector2(3.0, 2.0) # Across and along its yank axis, metres.
const RUG_THICKNESS: float = 0.02
const YANK_SPEED: float = 3.5
const YANK_HEIGHT: float = 1.5 # Things up to this high above the rug count as on it.
const YANK_SHIFT: float = 0.5 # Metres the rug jerks along before settling back.
const YANK_TIME: float = 0.15
const YANK_RETURN_TIME: float = 0.8
const RUG_COLOUR := Color("a8434a")
const QUERY_LIMIT: int = 16 # Most bodies one door or rug overlap query returns.
const DECAL_HEIGHT: float = 0.03 # Floor markings (slime, the drop marker, the stomp ring) sit this high, clear of the rug.
const DECAL_THICKNESS: float = 0.01

# --- Haunting settings ---
const SHAKE_COST: int = 45
const SHAKE_COOLDOWN: float = 20.0 # Seconds, counted from when the haunting is triggered.
const SHAKE_WARNING: float = 1.0
const SHAKE_DURATION: float = 2.5
const SHAKE_MOVING_SPEED: float = 0.3 # Metres per second; a mover sliding faster than this counts as moving.
const SHAKE_WARNING_TRAUMA: float = 0.35 # Camera trauma, 0 to 1, held during the warning.
const SHAKE_TRAUMA: float = 0.8 # Camera trauma held while the house shakes.
const DUST_AMOUNT: int = 160
const DUST_LIFETIME: float = 1.6
const DUST_HEIGHT: float = 3.2 # Metres; the dust falls from where the ceiling would be.
const DUST_SIZE: float = 0.05
const DUST_GRAVITY: float = 3.0 # Metres per second squared; dust drifts down slower than things fall.
const DUST_COLOUR := Color("cbbfa8")
const SLIME_COST: int = 25
const SLIME_COOLDOWN: float = 10.0
const SLIME_TRAIL_TIME: float = 4.0 # Seconds the ghost leaves slime after casting.
const SLIME_PATCH_LIFETIME: float = 4.0
const SLIME_PATCH_RADIUS: float = 0.4
const SLIME_PATCH_SPACING: float = 0.6 # Metres of ghost travel between patches.
const SLIME_FADE_TIME: float = 0.5 # The end of a patch's life, spent fading out.
const SLIME_GRIP: float = 1.5 # Per second; how quickly the stick can change a mover's velocity on slime.
const SLIME_COLOUR := Color(0.45, 1.0, 0.35, 0.7)
const BANNER_FONT_SIZE: int = 44
const BANNER_OUTLINE_SIZE: int = 8
const BANNER_TOP: int = 96 # Pixels from the top of the screen to the haunting banner.

# --- Camera shake settings ---
const TRAUMA_DECAY: float = 1.2 # Trauma lost per second.
const CAMERA_SHAKE_OFFSET: float = 0.45 # Metres of camera offset at full trauma.
const CAMERA_SHAKE_ROLL: float = 2.5 # Degrees of camera roll at full trauma.
const CAMERA_SHAKE_FREQUENCY: float = 18.0 # How fast the shake noise moves.

# --- Damage, loot and feedback settings ---
const DAMAGE_SPEED_THRESHOLD: float = 2.5 # Metres per second of closing speed.
const DAMAGE_MULTIPLIER: float = 0.04 # Fraction of current value per m/s × fragility.
const LOOT_CONTACT_LIMIT: int = 16
const FLOOR_NORMAL_MIN: float = 0.7 # Contacts with a steeper normal than this count as floor.
const LOOT_NAMES: Array[String] = ["Antique vase", "Old TV", "Grandfather clock", "Grand piano"]
const LOOT_VALUES: Array[int] = [3000, 5000, 8000, 20000] # Rupees from the Mansion loot list.
const LOOT_FRAGILITIES: Array[int] = [3, 3, 2, 2]
const LOOT_WEIGHTS: Array[int] = [LIGHT, MEDIUM, HEAVY, TWO_PERSON]
const LOOT_SIZES: Array[Vector3] = [Vector3(0.65, 0.8, 0.65), Vector3(1.0, 0.75, 0.6), Vector3(0.7, 1.8, 0.5), Vector3(2.2, 1.0, 1.4)]
const LOOT_COLOURS: Array[Color] = [Color("87d9e6"), Color("cf9ec9"), Color("bd9667"), Color("4b3b5c")]
const PRICE_LABEL_HEIGHT: float = 0.2 # Metres above the item's top.
const PRICE_FONT_SIZE: int = 48
const PRICE_PIXEL_SIZE: float = 0.006 # World metres per label pixel; small, so tags never crowd the screen.
const PRICE_OPACITY: float = 0.8 # 0 to 1.
const PRICE_OUTLINE_SIZE: int = 8 # Pixels of dark outline around the tag's text.
const PRICE_SHOW_DISTANCE: float = 3.0 # Metres; a tag shows only while a mover or the ghost is this close.
const PRICE_FADE_TIME: float = 0.2 # Seconds to fade a tag fully in or out.
const VALUE_POPUP_PIXEL_SIZE: float = 0.009 # Damage and banking popups, a little bigger than tags.
const VALUE_POPUP_START: float = 0.6 # Metres above the price tag, so the popup never covers it.
const VALUE_POPUP_LIFETIME: float = 1.2
const VALUE_POPUP_RISE: float = 1.0
const VALUE_POPUP_OUTLINE: int = 18 # Ink outline on the comic popups (CRASH!, SCRAPE!, SMASH!, KA-CHING!).
const VALUE_POPUP_PUNCH: float = 1.8 # Scale a popup punches in from.
const VALUE_POPUP_PUNCH_TIME: float = 0.2
const DAMAGE_COLOUR := Color("ff7676")
const BANK_COLOUR := Color("c2e78b")
const DAMAGE_BUZZ_MS: int = 60

# --- Truck (the scanned pickup, decimated; visual size scaled to the 1.6 m movers) ---
const TRUCK_MODEL_PATH: String = "res://assets/models/truck/truck.obj"
const TRUCK_MODEL_HEADING: float = -10.56 # Degrees from +X toward +Z of the scan's cab-to-tailgate line.
const TRUCK_MODEL_LENGTH: float = 41.54 # The scan's length in its own units.
const TRUCK_MODEL_TAILGATE := Vector3(10.48, 0.0, -26.82) # Middle of the tailgate in the scan's units.
const TRUCK_MODEL_FLOOR: float = -7.15 # The scan's wheel bottoms (its y).
const TRUCK_SINK: float = 0.08 # Metres the model sits into the ground, hiding the scanned grass around its tyres.
const TRUCK_LENGTH: float = 4.5 # Metres: a 4.9 m pickup × 0.914 (1.6 m movers for 1.75 m people).
const TRUCK_WIDTH: float = 1.85
const TRUCK_BED_LENGTH: float = 2.1 # From the tailgate to the cab.
const TRUCK_BED_HEIGHT: float = 1.0 # The bed's sides; its solid collider.
const TRUCK_CAB_HEIGHT: float = 1.67 # Roof height; the cab's solid collider.
const DELIVERY_RADIUS: float = 2.0 # Metres: the half-circle behind the tailgate where released loot banks.
const DELIVERY_COLOUR := Color(0.43, 0.85, 0.35, 0.45)
const DELIVERY_SEGMENTS: int = 32 # Half-circle smoothness.
const DELIVERY_LIFT: float = 0.03 # Metres above the ground: just above the 0.02 m path and floor slabs, so the truck zone shows on the driveway.

# --- Arena build settings (arenas/arena_builder.gd; geometry lives in arenas/layouts/) ---
const ARENA_WALL_HEIGHT: float = 3.0 # Metres above each room's floor: a 3.3 m mansion ceiling scaled to 1.6 m movers.
const ARENA_WALL_THICKNESS: float = 0.2
const ARENA_SEE_THROUGH_ALPHA: float = 0.15 # Opacity of a faded camera-facing wall, 0 to 1; it still blocks.
const ARENA_WAINSCOT_HEIGHT: float = 0.9 # Metres above the room's floor.
const ARENA_WAINSCOT_DEPTH: float = 0.015 # Metres proud of the wall face.
const ARENA_RAIL_HEIGHT: float = 0.06 # The dado rail on top of the wainscoting, metres.
const ARENA_RAIL_DEPTH: float = 0.03 # Dado rail and skirting, metres proud of the wall face.
const ARENA_SKIRTING_HEIGHT: float = 0.12 # Metres.
const WALL_FADE_TIME: float = 0.25 # Seconds to fade between solid and see-through.
const WALL_FADE_HOLD: float = 1.0 # Seconds a wall stays see-through after it stops hiding a player.
const WALL_FADE_REACH: float = 0.7 # Metres above and below each player's centre that a wall must not hide.
const ARENA_FENCE_HEIGHT: float = 0.9
const ARENA_FENCE_THICKNESS: float = 0.1
const ARENA_RAILING_HEIGHT: float = 1.0
const ARENA_RAILING_THICKNESS: float = 0.1 # The railing's invisible collider.
const ARENA_BALUSTER_SPACING: float = 0.2 # Metres between balusters; gaps stay see-through.
const ARENA_BALUSTER_RADIUS: float = 0.035 # Metres at the foot; the top is narrower.
const ARENA_NEWEL_SPACING: float = 3.0 # Metres between the balustrade's square posts.
const ARENA_NEWEL_SIZE: float = 0.12 # Metres square.
const ARENA_HANDRAIL_SIZE := Vector2(0.09, 0.07) # Width and height of the handrail and base rail, metres.
const ARENA_WINDOW_SIZE := Vector2(0.9, 1.4) # Glass width and height, metres.
const ARENA_WINDOW_SILL: float = 1.0 # Metres above the room's floor.
const ARENA_WINDOW_FRAME: float = 0.08 # Frame width, metres; the glazing bars are half this.
const ARENA_SHUTTER_THICKNESS: float = 0.04 # Metres; shutters fold back beside outside windows.
const ARENA_WINDOW_GLASS_COLOUR := Color("2a1a08") # Under the glow (WINDOW_GLOW_* in the mood settings).
const ARENA_ARCH_SPRING: float = 2.3 # Metres above the floor where an arch starts to curve; at least 2.2 so a carried piano fits.
const ARENA_ARCH_CROWN: float = 2.8 # Metres above the floor at the arch's highest point.
const ARENA_ARCH_PILLAR_WIDTH: float = 0.25 # Metres; pillars stand beside the opening, never in it.
const ARENA_ARCH_DEPTH: float = 0.3 # Metres: the wall's thickness plus a little either side.
const ARENA_ARCH_SLICES: int = 9 # Steps in the arch's curve.
const ARENA_GATE_LEAF_MODEL: String = "res://assets/models/decor/graveyard/iron-fence.glb"
const ARENA_GATE_LEAF_OFFSET := Vector3(0.5, 0.0, 0.325) # Moves the model so it runs from its hinge along +X.
const ARENA_GATE_LEAF_LENGTH: float = 1.0 # Metres (the model's size).
const ARENA_GATE_LEAF_HEIGHT: float = 0.88 # Metres (the model's size).
const ARENA_GATE_LEAF_THICKNESS: float = 0.08 # The leaf's collider, metres.
const ARENA_GATE_POST_MODEL: String = "res://assets/models/decor/graveyard/border-pillar.glb"
const ARENA_GATE_POST_SCALE: float = 2.0 # The 0.76 m model becomes a 1.5 m post.
const ARENA_GATE_POST_WIDTH: float = 0.44 # The scaled post's collider, metres.
const ARENA_GATE_POST_HEIGHT: float = 1.52
const ARENA_RAMP_THICKNESS: float = 0.2 # The invisible ramp over the stairs.
const ARENA_FLOOR_SLAB: float = 0.02 # Thin coloured floor tiles over the ground.

# --- Mansion mood (arenas/mansion.gd builds it; the lamps sit in arenas/dressing/MansionDressing.tscn) ---
const MOOD_BACKGROUND := Color("1b1530") # Dusk violet; the fog fades into the same colour.
const MOOD_AMBIENT_COLOUR := Color("7a6fa8")
const MOOD_AMBIENT_ENERGY: float = 0.55 # 0 to 1: low, so the lamps and the moon do the lighting.
const MOOD_EXPOSURE: float = 1.15
const MOOD_GLOW_INTENSITY: float = 0.8 # Bloom on emissive windows, flames and the ghost.
const MOOD_GLOW_THRESHOLD: float = 1.0 # Only brightness above this blooms.
const MOOD_FOG_BEGIN: float = 30.0 # Metres from the camera where the fog starts.
const MOOD_FOG_END: float = 75.0 # Metres from the camera where the fog is solid.
const MOOD_FOG_CURVE: float = 1.5 # Above 1 keeps the near ground clearer.
const MOON_COLOUR := Color("c3cbff")
const MOON_ENERGY: float = 0.8
const MOON_ROTATION := Vector3(-50.0, -70.0, 0.0) # Degrees; the only light that casts shadows.
const MOON_SHADOW_DISTANCE: float = 60.0 # Metres from the camera that get shadows.
const LAMP_COLOUR := Color("ffb35c") # Warm lamplight, about 2700 K.
const LAMP_ENERGY: float = 2.2 # Ceiling lamps (and where the possessable chandeliers will hang).
const LAMP_RANGE: float = 8.0 # Metres.
const FIRE_COLOUR := Color("ff8a3d")
const FIRE_ENERGY: float = 1.4
const FIRE_RANGE: float = 4.5 # Metres.
const LANTERN_COLOUR := Color("ffc070")
const LANTERN_ENERGY: float = 1.2 # Garden lanterns and the street lamp.
const LANTERN_RANGE: float = 5.0 # Metres.
const WINDOW_GLOW_COLOUR := Color("ffc070")
const WINDOW_GLOW_ENERGY: float = 2.0 # Emission strength; above the glow threshold, so windows bloom.
const FLAME_GLOW_ENERGY: float = 3.0 # The fireplace flame's emission.
const DECOR_DESATURATION: float = 0.45 # 0 to 1: how far decor model colours are pulled toward grey.
const DECOR_SHADE: float = 0.75 # 0 to 1: decor brightness, so pale furniture never reads as pastel loot.
const GROUNDS_FENCE_SCALE: float = 1.7 # The perimeter iron fence (1 m model sections), on the movers' outer limits.

# --- Greybox room settings ---
const ROOM_WIDTH: float = 14.0
const ROOM_DEPTH: float = 13.5
const ROOM_CENTRE_Z: float = -4.75
const PARLOUR_WALL_Z: float = -8.0 # Partition between the main room and the back parlour.
const PARLOUR_DOOR_WIDTH: float = 2.0
const PARLOUR_WALL_HEIGHT: float = 0.7 # Knee-high like other camera-side walls; still blocks a carried piano and movers.
const PIANO_POSITION := Vector2(0.0, -9.75)
const WALL_THICKNESS: float = 0.3
const WALL_HEIGHT: float = 2.2
const FRONT_WALL_HEIGHT: float = 0.7
const DOOR_WIDTH: float = 3.0
const MOVER_SPAWN_Z: float = 5.0
const TRUCK_POSITION := Vector3(5.0, 0.0, 5.0)
const TRUCK_SIZE := Vector3(3.5, 3.0, 3.0)
const LOOT_SPAWN_CLEARANCE: float = 0.03
const VASE_POSITIONS: Array[Vector2] = [Vector2(-4.5, -5.0), Vector2(-1.5, -5.0), Vector2(1.5, -5.0), Vector2(4.5, -5.0)]
const TV_POSITIONS: Array[Vector2] = [Vector2(-4.5, -2.0), Vector2(4.5, -2.0)]
const CLOCK_POSITION := Vector2(2.5, -3.0)
const OBSTACLE_POSITION := Vector3(-1.5, 0.5, -2.0)
const OBSTACLE_SIZE := Vector3(2.0, 1.0, 0.8)
const CRATE_POSITION := Vector2(-3.5, 0.0)
const ARMOUR_POSITION := Vector2(3.0, -6.8)
const CHANDELIER_POSITION := Vector2(0.5, -3.5)
const RUG_POSITION := Vector2(0.0, 0.5)
const FURNITURE_NAMES: Array[String] = ["Crate", "Suit of armour"]
const FURNITURE_SIZES: Array[Vector3] = [Vector3(1.0, 1.0, 1.0), Vector3(0.6, 1.8, 0.6)]
const FURNITURE_WEIGHTS: Array[int] = [MEDIUM, HEAVY]
const FURNITURE_COLOURS: Array[Color] = [Color("a87a4f"), Color("9aa3ad")]
const GHOST_PANEL_WIDTH: float = 240.0 # Pixels; the ghost energy bar shown to everyone.
const HUD_FONT_SIZE: int = 20
const HUD_SMALL_FONT_SIZE: int = 15

# --- Temporary banking sound settings ---
const BANK_SAMPLE_RATE: int = 22050
const BANK_SOUND_DURATION: float = 0.35
const BANK_SOUND_FREQUENCIES: Array[float] = [880.0, 1320.0] # Hz, two cash-register-like notes.
const BANK_SOUND_VOLUME: float = 0.3 # Linear amplitude, 0 to 1.
const BANK_SOUND_DECAY: float = 12.0
const BANK_LARGE_VALUE: int = 5000 # Rupees, pitch lift threshold.
const BANK_LARGE_PITCH: float = 1.15

# --- Edge HUD settings ---
const HUD_CARD_WIDTH: float = 260.0
const HUD_TOAST_SECONDS: float = 3.0
const HUD_TOAST_LIMIT: int = 3
const HUD_WARNING_SECONDS: float = 30.0 # The timer turns red and wobbles for the last stretch.
const DEMO_ROUND_SECONDS: float = 60.0
const HUD_DIAL_SIZE: float = 54.0 # The punch-clock dial beside the timer.
const HUD_WOBBLE_DEGREES: float = 4.0 # How far the timer card rocks in the last stretch.
const HUD_WOBBLE_RATE: float = 9.0 # Radians per second of that rocking.
const HUD_TRUCK_SIZE := Vector2(236.0, 62.0) # The truck meter: cargo fills toward the 70% flag.
const HUD_VASE_SIZE := Vector2(30.0, 40.0) # The damage meter: a vase that cracks as value is lost.
const HUD_VASE_CRACKS: int = 4 # Cracks at the loss limit; the vase shatters past it.
const HUD_DANGER_FRACTION: float = 0.7 # Share of the loss limit at which the screen edges pulse red.
const HUD_DANGER_WIDTH: float = 90.0 # How far the red edge glow reaches in.
const HUD_DANGER_RATE: float = 6.0 # Radians per second of the red pulse.
const HUD_ENERGY_RING: float = 30.0 # The ghost chip's energy ring.

const HUD_ROOM_SIZE := Vector2(190, 64)
const HUD_RING_RADIUS: float = 23.0
const HUD_RING_WIDTH: float = 5.0
const HUD_RING_SEGMENTS: int = 48
const HUD_DISC_STEP: float = 17.0
const HUD_DISC_COLUMNS: int = 7
const HUD_DISC_RADIUS: float = 5.0
const HUD_DISC_STROKE: float = 2.0
const LOBBY_PULSE_SECONDS: float = 1.2
const LOBBY_PULSE_ALPHA: float = 0.5

# --- Mansion surroundings (arenas/dressing/MansionEnvironment.tscn; outside the play area, no colliders) ---
const WORLD_GROUND_SIZE: float = 300.0 # Metres square, centred on the arena; its edges sit deep in the fog.
const WORLD_GROUND_TILES: int = 5 # Tiles per side, so each tile is lit by only nearby lamps (8 per mesh on Mobile).
const WORLD_SEED: int = 13 # Places the forest, grass and props the same way every time.
const FOREST_NEAR_TREES: int = 160 # Detailed trees in the band behind and beside the house.
const FOREST_FAR_TREES: int = 420 # Cheap cone trees further out, in the fog.
const FOREST_NEAR_DEPTH: float = 30.0 # Metres of detailed forest beyond the fence.
const FOREST_FAR_DEPTH: float = 110.0 # Metres of cheap forest beyond that.
const FOREST_DEAD_SHARE: float = 0.3 # 0 to 1: twisted dead trees among the near forest.
const GRASS_TUFTS: int = 380 # Inside the fence, away from the house, path and truck (fewer: a calmer yard, STYLE.md).
const WEEDS: int = 70 # Tall weeds among the grass.
const DEAD_BUSHES: int = 36
const DEAD_BUSH_COLOUR := Color("4d4238") # Darker and greyer, so bushes sit back from the playfield.
const GRASS_TUFT_COLOUR := Color("48523a") # Desaturated green, near the ground colour.
const FOREST_SHADE: float = 0.5 # 0 to 1: forest colours are darkened this much, so the wood reads dark.
const WEED_COLOUR := Color("4c5539")
const DIRT_PATCHES: int = 14 # Dark dirt patches in the grass.
const FENCE_PILLAR_SPACING: float = 6.0 # Metres between the perimeter fence's stone pillars.
const FENCE_PILLAR_SCALE: float = 2.0
const GATE_WIDTH: float = 4.0 # Metres: the big gate where the drive leaves the plot.
const ROAD_GAP: float = 2.5 # Metres between the fence and the pavement.
const ROAD_TILE: float = 6.0 # Metres: the road pieces are scaled to this.
const ROAD_LENGTH: float = 220.0 # Metres of road along the front.
const PAVEMENT_WIDTH: float = 2.0
const CURB_HEIGHT: float = 0.15
const STREET_LAMP_SPACING: float = 16.0 # Metres between street lamps.
const STREET_LAMP_SCALE: float = 5.0 # The 0.67 m model becomes a 3.4 m lamp post.
const STREET_LAMP_LIT: int = 2 # Lamps nearest the gate that also shine real light; the rest only glow.
const LAMP_FLICKER_CHANCE: float = 0.04 # 0 to 1 per tenth of a second: a lamp or window dips.
const LAMP_FLICKER_DIP: float = 0.25 # 0 to 1: brightness during a flicker.
const SWAY_STRENGTH: float = 0.05 # Metres of wind sway per metre of height.
const SWAY_SPEED: float = 1.3 # Radians per second.
const MIST_COLOUR := Color(0.62, 0.58, 0.78, 0.13) # Pale purple; environment glow is never green.
const EYE_COLOUR := Color("fff2a8") # Pale yellow eyes in the forest.
const MUSHROOM_GLOW := Color("9fd6ff") # Pale blue.
const FIREFLY_COLOUR := Color("fff6b0")
const GLOW_ENERGY: float = 1.6 # Emission strength of eyes, mushrooms and fireflies.
const CHIMNEY_SIZE := Vector3(1.6, 8.0, 1.6) # Metres; the stack stands just outside the back wall.
const TRUCK_HEADLIGHT_ENERGY: float = 2.0
const TRUCK_HEADLIGHT_RANGE: float = 12.0 # Metres.
const TRUCK_HAZARD_COLOUR := Color("ffb347")
const TRUCK_HAZARD_SECONDS: float = 0.6 # On and off time of the hazard lamps.

# --- Wildlife and sky events (arenas/dressing/wildlife.gd, sky_events.gd) ---
const CROW_SCARE_DISTANCE: float = 3.0 # Metres: a mover this close sends a crow flying.
const CROW_RETURN_SECONDS: float = 12.0 # A scared crow comes back after this long.
const SMASH_SCARE_DISTANCE: float = 12.0 # Metres: birds this near a shattering item take off.
const BAT_INTERVAL := Vector2(18.0, 35.0) # Seconds between bat flights, random in this range.
const OWL_INTERVAL := Vector2(20.0, 45.0) # Seconds between hoots.
const HOWL_INTERVAL := Vector2(40.0, 80.0) # Seconds between distant howls.
const EYE_BLINK_INTERVAL := Vector2(2.0, 6.0) # Seconds between blinks.
const LIGHTNING_INTERVAL := Vector2(40.0, 60.0) # Seconds between lightning strikes, random in this range.
const LIGHTNING_RETRY: float = 5.0 # Seconds to wait when a haunting is warning or running.
const LIGHTNING_FLASH_ENERGY: float = 6.0 # Moonlight energy at the flash's peak.
const LIGHTNING_AMBIENT_BOOST: float = 4.0 # Ambient light multiplier during a flash.
const LIGHTNING_FLASH_TIME: float = 0.35 # Seconds each flash takes to fade; lightning flashes twice.
const THUNDER_DELAY := Vector2(0.6, 1.8) # Seconds from flash to thunder.
const AMBIENT_VOLUME_DB: float = -14.0 # The wind, crickets and night loop.
const CREATURE_VOLUME_DB: float = -10.0 # Owl, howl, crows.
const THUNDER_VOLUME_DB: float = -4.0

# --- Intro cutscene ---
# Plays once per match, between START and the first role reveal. Each panel holds for "hold" seconds; "music" picks
# the bed ("cozy", "spooky" or "" for none), "beds" sets the looping rain and engine levels in dB (missing = silent),
# "flash" marks a change between the 3D and comic art, "shake" shakes the panel, and each cue is
# [seconds into the panel, sound, volume dB]. Sounds are files in res://assets/audio/cutscene/ or Sfx's own.
const INTRO_FOLDER: String = "res://assets/cutscenes/intro/"
const INTRO_PANELS: Array[Dictionary] = [
	{"image": "01_godown.jpeg", "hold": 6.0, "music": "cozy", "beds": {"rain": -22.0},
		"cues": [[1.0, "glass_clink_1", -8.0], [2.4, "glass_clink_2", -8.0], [3.9, "glass_clink_1", -10.0]]},
	{"image": "02_truck_road.jpeg", "hold": 4.0, "music": "cozy", "beds": {"rain": -10.0, "engine": -14.0}, "flash": true,
		"cues": []},
	{"image": "03_sasta_shifters.jpeg", "hold": 7.0, "music": "cozy", "beds": {"rain": -12.0, "engine": -12.0},
		"cues": [[0.8, "rattle", -6.0], [2.6, "horn", -6.0], [3.0, "horn", -6.0], [3.8, "goat", -8.0]]},
	{"image": "04_arrival.jpeg", "hold": 6.0, "music": "", "beds": {"rain": -10.0, "engine": -24.0},
		"cues": [[2.2, "gate_latch", -4.0], [2.5, "gate_creak", -2.0]]},
	{"image": "05_mansion_owner.jpeg", "hold": 6.0, "music": "spooky", "beds": {"rain": -12.0},
		"cues": [[0.2, "thunder", -2.0]]},
	{"image": "06_windshield.jpeg", "hold": 4.0, "music": "spooky", "beds": {"rain": -10.0},
		"cues": [[0.5, "whoosh", -6.0], [1.3, "splat", -2.0]]},
	{"image": "07_job_sheet.jpeg", "hold": 7.0, "music": "spooky", "beds": {"rain": -18.0},
		"cues": [[0.3, "paper_1", -4.0], [1.1, "paper_2", -4.0]]},
	{"image": "08_seth_ji.jpeg", "hold": 7.0, "music": "spooky", "beds": {"rain": -24.0},
		"cues": [[0.3, "organ", -6.0]]},
	{"image": "09_house_shake.jpeg", "hold": 4.0, "music": "spooky", "beds": {"rain": -24.0}, "shake": true,
		"cues": [[0.0, "rumble", -2.0], [0.7, "crash_wood", -2.0], [1.5, "crash_glass", -4.0]]},
	{"image": "10_briefing.jpeg", "hold": 10.0, "music": "spooky", "beds": {"rain": -14.0},
		"cues": [[0.3, "crackle", -8.0], [4.8, "crackle", -8.0], [7.6, "crackle", -8.0]]},
	{"image": "11_title.jpeg", "hold": 4.0, "music": "", "beds": {"rain": -16.0}, "flash": true,
		"cues": [[0.0, "title_hit", -2.0], [0.0, "thunder", -6.0], [0.5, "title_pizzicato", -4.0]]},
]
const INTRO_FADE_TIME: float = 0.5 # Seconds each panel takes to fade in over the last.
const INTRO_ZOOM: float = 1.06 # Each panel slowly grows to this scale while it shows.
const INTRO_DRIFT: float = 0.015 # Share of the screen width each panel drifts sideways, alternating direction.
const INTRO_FLASH_TIME: float = 0.3 # Seconds the white flash takes to fade on a change of art style.
const INTRO_SHAKE_PIXELS: float = 14.0 # Largest shake offset on a "shake" panel.
const INTRO_SHAKE_TIME: float = 2.0 # Seconds the shake lasts, easing out.
const INTRO_MUSIC_DB: float = -10.0
const INTRO_MUSIC_FADE: float = 1.5 # Seconds to crossfade between music beds, and to fade beds in or out.
const INTRO_END_FADE: float = 0.6 # Seconds the sound fades out after the last panel or a skip.
const INTRO_SILENT_DB: float = -60.0 # A faded-out bed.

# --- Effects (core/fx.gd) ---
# One-shot bursts, in the order of Fx.Kind: dust, sparks, shards, sparkle, ghost puff. Size and radius in metres,
# speed in metres per second, gravity in metres per second squared, spread in degrees around straight up.
const FX_BURSTS: Array[Dictionary] = [
	{"colour": Color("cbbfa8"), "amount": 10, "size": 0.5, "lifetime": 0.6, "speed": 1.6, "gravity": 1.5, "spread": 75.0, "radius": 0.15},
	{"colour": Color("ffd04a"), "amount": 14, "size": 0.2, "lifetime": 0.4, "speed": 4.5, "gravity": 9.0, "spread": 80.0, "radius": 0.05, "glow": true},
	{"colour": Color("ff8f8f"), "amount": 16, "size": 0.26, "lifetime": 0.7, "speed": 4.0, "gravity": 12.0, "spread": 85.0, "radius": 0.1},
	{"colour": Color("ffe27a"), "amount": 22, "size": 0.28, "lifetime": 0.9, "speed": 3.0, "gravity": -1.0, "spread": 50.0, "radius": 0.3, "glow": true},
	{"colour": Color("6dff8a"), "amount": 18, "size": 0.45, "lifetime": 0.7, "speed": 2.2, "gravity": -1.5, "spread": 180.0, "radius": 0.25, "glow": true},
]
const FX_GLOW_ENERGY: float = 2.0 # Emission on glowing effects, so they bloom.
const FX_TRAIL_SIZE: float = 0.34 # The ghost trail's puffs.
const FX_TRAIL_LIFETIME: float = 0.7
const FX_TRAIL_AMOUNT: int = 40
const FX_TRAIL_RISE: float = 0.6 # Puffs float upward as they fade.
const FX_TRAIL_DRIFT: float = 0.15
const FX_TRAIL_RADIUS: float = 0.12
const FX_TRAIL_MIN_SPEED: float = 0.4 # Metres per second the ghost must move to leave a trail.
const FX_DRAG_INTERVAL: float = 0.12 # Seconds between dust puffs while an item scrapes along the floor.
const FX_LAND_SPEED: float = 2.5 # Fall speed (m/s) at which a landing kicks up dust.

# --- Contrast (Supercell-style punch) ---
const MOOD_CONTRAST: float = 1.04 # Colour adjustment over the AgX tonemap; kept gentle (1.18 crushed the dusk into mud).
const MOOD_SATURATION: float = 1.08
const MOOD_BRIGHTNESS: float = 1.0
const OUTLINE_INK := Color("120b1d") # Movers' comic outline.
const OUTLINE_WIDTH: float = 0.022 # Metres.

# --- Sound effects and music (autoload/Sfx.gd) ---
const SFX_PITCH_JITTER: float = 0.08 # Repeated sounds vary their pitch by up to this share.
const SFX_FRAGILE: int = 3 # Fragility at or above this sounds like glass; below, a thud.
const SFX_DAMAGE_QUIET_DB: float = -14.0 # A tiny scratch; losing an item's whole value plays at 0 dB.
const SFX_TROMBONE_VALUE: int = 10000 # Smashing an item worth this much (₹) plays the sad trombone.
const SFX_TROMBONE_DB: float = -4.0
const SFX_COINS_DB: float = -6.0 # The coin jingle under the banking chime.
const SFX_CREAK_DB: float = -6.0 # Possession: a creak and a theremin swell.
const SFX_THEREMIN_DB: float = -8.0
const SFX_CURSE_PITCH: float = 0.6 # The Curse is a low theremin.
const SFX_CURSE_DB: float = -6.0
const SFX_BOING_DB: float = -4.0 # A tumble.
const SFX_WHOOSH_DB: float = -8.0 # A throw.
const SFX_GRAB_DB: float = -10.0 # A grab.
const SFX_RUMBLE_DB: float = -2.0 # House Shake's warning.
const SFX_TICK_SECONDS: int = 10 # The clock ticks each second for the last this many seconds.
const SFX_TICK_DB: float = -8.0
const SFX_JINGLE_DB: float = -4.0 # Round and match end jingles.
const MUSIC_LOBBY_DB: float = -14.0
const MUSIC_ROUND_DB: float = -12.0
const MUSIC_RUSH_PITCH: float = 1.12 # The round music speeds up for the last 30 s.

# --- Light grade and focal light (STYLE.md) ---
const GRADE_VIGNETTE: float = 0.18 # 0 to 1: how far the screen corners sink into the night colour; a light touch.
const GRADE_VIGNETTE_INNER: float = 0.32 # Share of the screen from the centre that stays clear.
const GRADE_WARM := Color("ffb46b") # The warm wash at the centre of the action.
const GRADE_WARM_STRENGTH: float = 0.04
const GRADE_CENTRE := Vector2(0.5, 0.55) # The camera keeps the action a little below the middle.
const YARD_LIGHT_COLOUR := Color("ffcf94") # A warm light pool over the front yard and driveway.
const YARD_LIGHT_ENERGY: float = 0.8
const YARD_LIGHT_RANGE: float = 11.0 # Metres.
const YARD_LIGHT_HEIGHT: float = 5.0 # Metres above the yard.
const TRUCK_POSTER_LEVELS: float = 4.0 # Shading bands on the repainted truck.
const TRUCK_PAINT := Color("ff9a3c") # Sasta Shifters orange, as in the intro's comic panels.
const FLOOR_TINT := Color(1.0, 1.0, 1.0) # Multiplies the wood floors; white keeps the original warm wood (a darker tint read muddy).
const PROP_OUTLINE_WIDTH: float = 0.03 # Metres: ink outline on loot and possessable furniture.
const RIM_STRENGTH: float = 0.45 # Rim light on movers, loot and possessable furniture (0 to 1).
const RIM_TINT: float = 0.4 # 0 is a white rim, 1 takes the object's own colour.
const WINDOW_POOL_REACH: float = 1.1 # Metres a window's light patch reaches out from the wall.
const WINDOW_POOL_WIDTH: float = 2.0 # The patch's width, as a multiple of the window's.
const WINDOW_POOL_STRENGTH: float = 0.22 # 0 to 1: how bright the additive patch is.
const WINDOW_POOL_LIFT: float = 0.035 # Metres above the floor, clear of the path slab and zone pads.

# --- Loading screen (menus/loading_screens/) ---
const LOADING_BAR_HEIGHT: float = 34.0
const LOADING_BAR_COLOUR := Color("4aa8e0") # The blue of the designed mock-up bar.
const LOADING_LABEL_SIZE: int = 24
const LOADING_TIP_SECONDS: float = 3.5
const LOADING_TIPS: Array[String] = [
	"The piano needs two movers. Turn it to fit through doors.",
	"House shaking? Stand still or hold BRACE.",
	"Fragile things lose value with every bump.",
	"Deliver 70% of the haul to the truck to win.",
	"Ghost: possess furniture and SHOVE it at the movers.",
	"Power the generator with 3 batteries to weaken the ghost.",
	"On the Ship, carry 3 oil cans to the lantern posts on the tug.",
	"Ghost: possess a rum barrel and ROLL it down the steps.",
	"Wave coming? Hold BRACE on the gangplank or get washed overboard.",
	"A thrown vase can knock a mover flat.",
]

# --- Ghost Ship settings (metres, seconds and rendering limits) ---
const SHIP_CAMERA_YAW: float = -20.0
const SHIP_WATER_Y: float = -1.6 # Raised with the Kenney hull (decision 107) so its keel sits in the sea.
const SHIP_RESCUE_SECONDS: float = 2.0
const SHIP_RESCUE_CLEARANCE: float = 0.9
const SHIP_DECK_THICKNESS: float = 0.22
# Hull decks are solid down to this, so no step shows daylight underneath and the hold gets real walls.
const SHIP_DECK_BASE: float = -1.6
const SHIP_BULWARK_HEIGHT: float = 0.7
const SHIP_BULWARK_WIDTH: float = 0.18
# Ship motion (decisions 106 and 113): the whole ship, tug and plank ride the sea as one rig of moving platforms,
# rolling, pitching and heaving on three cycles that never line up; the camera never moves. Loose loot on the
# galleon's decks also creeps toward the low side of the roll.
const SHIP_SWAY_PERIOD: float = 9.0 # Seconds for one full roll, port and back.
const SHIP_SWAY_ANGLE: float = 3.0 # Degrees of roll at the peak.
const SHIP_PITCH_PERIOD: float = 7.0
const SHIP_PITCH_ANGLE: float = 1.5 # Degrees of pitch, bow and stern, at the peak.
const SHIP_HEAVE_PERIOD: float = 5.0
const SHIP_HEAVE: float = 0.25 # Metres up and down at the peak.
const SHIP_MOTION_PIVOT := Vector3(16.0, 0.0, 6.0) # The galleon's centre on its main deck.
const SHIP_WAVE_LURCH: float = 2.5 # Extra degrees of roll a breaking gangplank wave knocks into the ship.
const SHIP_LURCH_DECAY: float = 2.0 # Per second.
const SHIP_LURCH_EASE: float = 6.0 # Per second; the lurch rolls in over about a third of a second, never a jolt.
# The sea's swell: long rolling crests under the existing ripples, foam on the tops.
const SHIP_SWELL_HEIGHT: float = 0.3
const SHIP_SWELL_SPEED: float = 0.8
const SHIP_SWAY_DRIFT_SPEEDS: Array[float] = [0.35, 0.25, 0.12, 0.0] # Peak creep in m/s by weight class; the chest stays put.
const SHIP_SWAY_GRIP: float = 12.0 # m/s² the roll may add to reach that creep, enough to beat loot friction.
# Gangplank waves (decision 109): in live play a wave washes over the plank about every 20 s. A foam wall rises
# beside the plank for the warning; then every unbraced mover on the plank is knocked down and carried off it.
const SHIP_WAVE_INTERVAL := Vector2(17.0, 23.0) # Seconds between waves, picked per wave from a seeded stream.
const SHIP_WAVE_WARNING: float = 1.0
const SHIP_WAVE_CLEARANCE: float = 0.6 # Metres past the plank's far edge a washed mover is carried.
const SHIP_WAVE_SEED_OFFSET: int = 4241 # Separate wave timing from the seeded loot selection.
const SHIP_WAVE_COLOUR := Color(0.85, 0.95, 1.0, 0.65) # Foam.
const SHIP_WAVE_SWEEP_TIME: float = 0.35 # Seconds the crest takes to break across the plank.
const SHIP_WAVE_BODY_COLOUR := Color("1d5d70") # The face of the breaking wave, greener and lighter than the sea.
const SHIP_WAVE_START: float = 6.0 # Metres out at sea where the swell starts building during the warning.
const SHIP_WAVE_CREST_SCALE: float = 1.9 # Height of the full crest, as a multiple of its 1.25 m profile.
const SHIP_WAVE_SPRAY: int = 90 # Spray droplets when it breaks.
const SHIP_WAVE_FOAM_TIME: float = 1.4 # Seconds the foam sheet takes to drain off the plank.
# Ship audio (decision 110): a ship's bell rings on the tug instead of the truck's chime, a sea shanty plays in
# rounds, and the hull creaks at each end of the roll.
const SHIP_BELL_NOTE: float = 830.0 # Hz, the bell's strike note.
const SHIP_BELL_PARTIALS: Array[Vector2] = [Vector2(0.5, 1.2), Vector2(1.0, 2.2), Vector2(1.19, 3.0), Vector2(1.5, 3.4), Vector2(2.0, 4.0), Vector2(2.52, 5.5)] # Ratio to the strike note, decay per second.
const SHIP_BELL_STRIKES: Array[float] = [0.0, 0.32] # Seconds: "ding-ding".
const SHIP_BELL_LENGTH: float = 2.2
const SHIP_BELL_VOLUME: float = 0.18
const SHIP_SWAY_CREAK_DB: float = -14.0
# Fog banks (decision 111): every so often a thin bank of fog rolls across the ship from stern to bow. Cosmetic
# only and kept faint, so loot, warnings and players stay readable through it.
const SHIP_FOG_BANK_INTERVAL := Vector2(25.0, 40.0) # Seconds between banks.
const SHIP_FOG_BANK_FIRST: float = 10.0 # Seconds into a round before the first bank.
const SHIP_FOG_BANK_SPEED: float = 1.6 # Metres per second toward the bow.
const SHIP_FOG_BANK_PATH := Vector2(-14.0, 44.0) # World x where a bank starts and where it is gone.
const SHIP_FOG_BANK_PUFFS: int = 14
const SHIP_FOG_BANK_PUFF_SIZE := Vector2(5.0, 2.5)
const SHIP_FOG_BANK_EXTENTS := Vector3(6.0, 0.6, 7.0) # Half-size of the cloud of puffs.
const SHIP_FOG_BANK_CENTRE := Vector2(1.2, 8.0) # Height and z of the bank's middle.
const SHIP_FOG_BANK_ALPHA: float = 0.16 # Per puff, at its thickest.
const SHIP_GUST_COST: int = 40
const SHIP_GUST_COOLDOWN: float = 18.0
const SHIP_GUST_WARNING: float = 1.0
const SHIP_GUST_DURATION: float = 3.0
const SHIP_GUST_PUSH_SPEED: float = 1.0 # Stationary, unbraced movers drift in metres/second.
const SHIP_GUST_WITH_DOT: float = 0.35 # Stick projection along wind that causes a tumble.
const SHIP_OCEAN_SIZE: float = 300.0
const SHIP_NEAR_WATER_SIZE: float = 60.0
const SHIP_WATER_SUBDIVISIONS: int = 59
const SHIP_WAVE_HEIGHT: float = 0.14
const SHIP_WAVE_SPEED: float = 0.65
const SHIP_FOG_BEGIN: float = 32.0
const SHIP_FOG_END: float = 115.0
const SHIP_AMBIENT_ENERGY: float = 0.65
const SHIP_MOON_ENERGY: float = 1.25
const SHIP_LAMP_ENERGY: float = 1.0
const SHIP_LAMP_RANGE: float = 6.0
const SHIP_LIGHTNING_INTERVAL := Vector2(40.0, 60.0)
const SHIP_LIGHTNING_DURATION: float = 0.16
const SHIP_LIGHTNING_ENERGY: float = 2.6
const SHIP_BACKGROUND := Color("17253f")
const SHIP_WATER_COLOUR := Color("203f61")
const SHIP_WOOD_COLOUR := Color("69535f")
const SHIP_SAIL_COLOUR := Color("b0a9ba")
const SHIP_METAL_COLOUR := Color("3a465f")
const SHIP_GOLD_COLOUR := Color("dfb65f")
const SHIP_LANTERN_COLOUR := Color("b9ddff")
const SHIP_TUG_COLOUR := Color("ff9a3c")
const SHIP_TRIANGLE_BUDGET: int = 400000
const SHIP_DRAW_CALL_BUDGET: int = 350

const SHIP_DOOR_HEIGHT: float = 1.8
const SHIP_DROPPER_HEIGHT: float = 3.0
const SHIP_WIND_MARKER_SIZE: float = 0.025
const SHIP_WIND_MARKERS: Array[Vector3] = [Vector3(4, 1.28, 4), Vector3(10.5, 0.08, 9.2), Vector3(15, 0.08, 9.2), Vector3(17, 0.08, 3.2), Vector3(12, 0.08, 13.5), Vector3(12, 0.08, 15.0)]

const SHIP_HULL_TAPER: float = 0.82
# The tug's hull wraps its deck from just under the rail down past the waterline.
const SHIP_TUG_TOP: float = 0.45
const SHIP_TUG_DEPTH: float = 3.25 # Also reaches below the water.
const SHIP_TUG_OUTLINE: Array[Vector2] = [Vector2(7.8, 15.7), Vector2(16.2, 15.7), Vector2(16.5, 18.2), Vector2(15.8, 21.1), Vector2(8.2, 21.1), Vector2(7.5, 18.2)]
# The galleon is Kenney's ship-pirate-large (CC0, decision 107): 2.5x in plan so its decks fit play, 1x in height so
# its steps stay climbable. It is turned so its bow points +x, with its main deck at world height 0.
const SHIP_MODEL_PATH: String = "res://assets/models/pirate/kenney/ship-pirate-large.glb"
const SHIP_MODEL_SCALE := Vector3(2.5, 1.0, 2.5)
const SHIP_MODEL_AT := Vector3(16.4, -2.1, 6.0)
const SHIP_MODEL_TINT := Color("a39a9e") # Pulls the kit's salmon wood toward weathered grey-brown.
# The model's own flat deck faces (model units) are removed so the layout's walkable floors show instead.
const SHIP_MODEL_DECK_LEVELS: Array[float] = [1.6, 2.1, 2.3, 2.4, 2.8, 3.2, 3.5] # Includes the hatch grate and coaming: the main deck is open.
const SHIP_MODEL_DECK_HALF_WIDTH: float = 1.8 # Inside the rails; rail tops are kept.
const SHIP_GHOST_SAIL_ALPHA: float = 0.45 # The big sails are see-through so they never hide the deck.
const SHIP_LAMP_SPOTS: Array[Vector3] = [Vector3(1.6, 1.2, 2.0), Vector3(1.6, 1.2, 10.0), Vector3(9.0, 0, 2.0), Vector3(18.2, 0, 2.0), Vector3(18.2, 0, 10.0), Vector3(25.0, 0.7, 3.4), Vector3(8.2, 0, 20.5), Vector3(15.8, 0, 20.5)]
const SHIP_SIGN_SIZE: float = 0.012
const SHIP_FLOOR_SIGN_SIZE: float = 0.012
const SHIP_PLANK_MARKS: int = 20
const SHIP_PLANK_SPACING: float = 0.5
const SHIP_LIGHTHOUSE_SPOT := Vector3(53, -1.6, -39)
const SHIP_LIGHTHOUSE_SCALE: float = 2.0
const SHIP_LIGHTHOUSE_HEIGHT: float = 7.0
const SHIP_LIGHTHOUSE_ENERGY: float = 0.7
const SHIP_LIGHTHOUSE_RANGE: float = 30.0
const SHIP_LIGHTHOUSE_ANGLE: float = 12.0
const SHIP_LIGHTHOUSE_TURN_SPEED: float = 0.2
const SHIP_TENTACLE_SPOT := Vector3(-13, -3.0, -13)
const SHIP_TENTACLE_SEGMENTS: int = 8
const SHIP_TENTACLE_STEP: float = 0.5
const SHIP_TENTACLE_COLOUR := Color("51466c")
const SHIP_CREATURE_SPEED: float = 0.35
const SHIP_CREATURE_BOB: float = 0.3
const SHIP_AMBIENT_DB: float = -30.0
const SHIP_AMBIENT_CALL_INTERVAL: float = 24.0

const SHIP_MIST_SIZE := Vector2(10, 2)
const SHIP_MIST_POSITION := Vector3(15, -1, 6)
const SHIP_MIST_EXTENTS := Vector3(35, 0, 25)
const SHIP_MIST_AMOUNT: int = 8
const SHIP_MIST_ALPHA: float = 0.12
const SHIP_MIST_LIFETIME: float = 30.0
const SHIP_MIST_SPEED := Vector2(0.1, 0.25)
