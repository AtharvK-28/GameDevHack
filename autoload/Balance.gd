# Shared game and greybox settings. Distances are metres and times are seconds.
extends Node

# --- Network settings ---
const WEB_PORT: int = 8080
const SOCKET_PORT: int = 9080
const MAX_PLAYERS: int = 4
const INPUT_RATE: int = 30 # Messages per second, including idle heartbeats.
const HUD_RATE: int = 8 # Messages per second in later gameplay phases.
const INPUT_TIMEOUT_MS: int = 500
const JOIN_TIMEOUT_MS: int = 5000
const MAX_PENDING_PEERS: int = 8
const MAX_PACKET_BYTES: int = 2048
const MAX_PACKETS_PER_FRAME: int = 64
const MAX_NAME_LENGTH: int = 20
const RECONNECT_DELAY_MS: int = 1000
const PLAYER_COLOURS: Array[String] = ["#ffb84d", "#64d9ee", "#ed8bb6", "#b6de70"]

# --- Movement and test-scene settings ---
const MOVER_SPEED: float = 4.5 # Metres per second; unchanged from the spec.
const GRAVITY: float = 9.8 # Metres per second squared.
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.6
const FLOOR_SIZE: float = 28.0
const FLOOR_THICKNESS: float = 0.2
const SPAWN_SPACING: float = 2.5
const CAMERA_DISTANCE: float = 21.0
const CAMERA_TARGET := Vector3(0.0, 0.0, -3.0) # Centre of the greybox between the parlour and the truck.
const CAMERA_ANGLE: float = 65.0 # Degrees down from horizontal.
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
const LIGHT_ROTATION := Vector3(-55.0, -25.0, 0.0) # Degrees.
const OVERLAY_MARGIN: float = 16.0 # Pixels.
const JOYSTICK_SIZE: int = 120 # CSS pixels.
const JOYSTICK_DEADZONE: float = 0.12 # Normalised stick magnitude, 0 to 1.

# --- Carrying settings ---
const WORLD_LAYER: int = 1
const MOVER_LAYER: int = 2
const LOOT_LAYER: int = 4 # Loose physics props: loot, the flashlight and furniture.
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
const MODEL_SPEED_SCALE_MIN: float = 0.5 # Limits on clip playback speed.
const MODEL_SPEED_SCALE_MAX: float = 1.8
const MODEL_TRIM_LIGHTEN: float = 0.35 # Overall cuffs and cap strap, lighter than the slot colour.
const MODEL_SEAM_DARKEN: float = 0.55 # Seams and pocket edges, darker than the slot colour.

# --- Flashlight settings ---
const FLASHLIGHT_SIZE := Vector3(0.25, 0.25, 0.6)
const FLASHLIGHT_COLOUR := Color("f2d16b")
const FLASHLIGHT_RANGE: float = 8.0 # Metres.
const FLASHLIGHT_HALF_ANGLE: float = 20.0 # Degrees either side of the beam.
const FLASHLIGHT_ENERGY: float = 4.0
const FLASHLIGHT_AIM_STIFFNESS: float = 40.0 # Angular acceleration per radian turning the torch toward the holder's facing.
const BEAM_CONE_ALPHA: float = 0.15 # Opacity of the visible beam cone, 0 to 1.
const EXORCISE_TIME: float = 1.5 # Seconds a possessed prop must stay in the beam.

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
const POSSESS_RANGE: float = 0.6 # Metres from a prop's footprint.
const POSSESS_LOCKOUT: float = 5.0 # Seconds after an exorcism before the ghost can possess again.
const EXORCISE_FREEZE: float = 1.0 # Seconds the ejected wisp cannot move or press anything.

# --- Match settings ---
const ROUND_SECONDS: float = 150.0
const REVEAL_SECONDS: float = 3.0
const DELIVERY_PERCENT: int = 70 # Integer arithmetic keeps the exact boundary fair.
const LOOT_COUNTS: Array[int] = [6, 9, 12] # For 2, 3, 4 players.
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
const PRICE_LABEL_HEIGHT: float = 0.35 # Above the item's top.
const PRICE_FONT_SIZE: int = 48
const PRICE_PIXEL_SIZE: float = 0.012 # World metres per label pixel; tags must read on a projector.
const VALUE_POPUP_START: float = 0.6 # Metres above the price tag, so the popup never covers it.
const VALUE_POPUP_LIFETIME: float = 1.2
const VALUE_POPUP_RISE: float = 1.0
const DAMAGE_COLOUR := Color("ff7676")
const BANK_COLOUR := Color("c2e78b")
const DAMAGE_BUZZ_MS: int = 60

# --- Greybox room settings ---
const ROOM_WIDTH: float = 14.0
const ROOM_DEPTH: float = 13.5
const ROOM_CENTRE_Z: float = -4.75
const PARLOUR_WALL_Z: float = -8.0 # Partition between the main room and the back parlour.
const PARLOUR_DOOR_WIDTH: float = 2.0
const PARLOUR_WALL_HEIGHT: float = 0.7 # Knee-high like other camera-side walls; still blocks a carried piano and movers.
const PIANO_POSITION := Vector2(0.0, -9.75)
const FLASHLIGHT_POSITION := Vector2(-5.5, 1.0)
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
