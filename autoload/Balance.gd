# Shared settings for the plumbing test. Distances are metres and times are seconds.
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
