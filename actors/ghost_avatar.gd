# The visual body the ghost wears. GhostModel is the Mansion's bedsheet wisp; DavyJonesModel is the
# Ghost Ship's captain. The wisp drives whichever one the arena asked for through these calls only,
# so a new arena can bring its own body without touching the ghost's rules.
class_name GhostAvatar
extends Node3D


# --- Continuous state ---
# Called every frame while the ghost flies free, with its world velocity.
func update_motion(_velocity: Vector3, _delta: float) -> void:
	pass


# True while an action is playing, so the wisp can let it finish.
func is_busy() -> bool:
	return false


# The pale shimmer colour and opacity the wisp computes each frame. Bodies that tint themselves
# use this; the bedsheet wisp is tinted by the wisp's own material override instead.
func apply_shimmer(_colour: Color, _alpha: float) -> void:
	pass


# --- Ghost actions ---
func play_possess() -> void:
	pass


func play_emerge() -> void:
	pass


func play_cast() -> void:
	pass


func play_laugh(_seconds: float = 1.5) -> void:
	pass


func play_taunt() -> void:
	pass


func play_exorcised(_stun_seconds: float = 1.0) -> void:
	pass
