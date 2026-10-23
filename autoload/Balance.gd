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
const FLOOR_SIZE: float = 20.0
const FLOOR_THICKNESS: float = 0.2
const SPAWN_SPACING: float = 2.5
const CAMERA_DISTANCE: float = 18.0
const CAMERA_ANGLE: float = 55.0 # Degrees down from horizontal.
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
const LOOT_LAYER: int = 4
const CARRY_SPEEDS: Array[float] = [1.0, 0.8, 0.6] # Light, medium, heavy.
const LOOT_MASSES: Array[float] = [2.0, 8.0, 20.0] # Kilograms.
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

# --- Damage, loot and feedback settings ---
const DAMAGE_SPEED_THRESHOLD: float = 2.5 # Metres per second of closing speed.
const DAMAGE_MULTIPLIER: float = 0.04 # Fraction of current value per m/s × fragility.
const LOOT_CONTACT_LIMIT: int = 16
const LOOT_NAMES: Array[String] = ["Antique vase", "Old TV", "Grandfather clock"]
const LOOT_VALUES: Array[int] = [3000, 5000, 8000] # Rupees from the Mansion loot list.
const LOOT_FRAGILITIES: Array[int] = [3, 3, 2]
const LOOT_SIZES: Array[Vector3] = [Vector3(0.65, 0.8, 0.65), Vector3(1.0, 0.75, 0.6), Vector3(0.7, 1.8, 0.5)]
const LOOT_COLOURS: Array[Color] = [Color("87d9e6"), Color("cf9ec9"), Color("bd9667")]
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
const ROOM_DEPTH: float = 10.0
const ROOM_CENTRE_Z: float = -3.0
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
const FACING_MARKER_SIZE := Vector3(0.18, 0.18, 0.18)
const FACING_MARKER_DISTANCE: float = 0.4
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
