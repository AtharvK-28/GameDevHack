# The coloured ring on the floor under a mover, so a glance at the big screen says which character is yours.
# A chevron on the ring's front edge shows which way the mover faces. The aura only shows state: every frame the
# mover tells it the facing, whether it is carrying and whether it is down or hexed. Visual only.
class_name MoverAura
extends Node3D

# --- Parts ---
var ring: MeshInstance3D
var chevron: MeshInstance3D
var material := StandardMaterial3D.new()
var colour := Color.WHITE
var pulse_time: float = 0.0

# --- Setup ---
func setup(slot_colour: Color) -> void:
	colour = slot_colour
	_build_material()
	_build_ring()
	_build_chevron()
	position.y = -Balance.CAPSULE_HEIGHT / 2.0 + Balance.AURA_HEIGHT


# --- Every frame, from the mover ---
func update_aura(facing: Vector3, carrying: bool, alarmed: bool, delta: float) -> void:
	pulse_time += delta
	rotation.y = atan2(facing.x, facing.z)

	var alpha: float = Balance.AURA_ALPHA + (Balance.AURA_CARRY_BRIGHTEN if carrying else 0.0)
	if alarmed:
		# Down or hexed: the ring throbs, so teammates can spot who needs help.
		var pulse: float = 0.5 + 0.5 * sin(TAU * Balance.AURA_PULSE_RATE * pulse_time)
		alpha *= 1.0 - Balance.AURA_PULSE_DEPTH * pulse
	material.albedo_color = Color(colour, clampf(alpha, 0.0, 1.0))


# --- Build ---
func _build_material() -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(colour, Balance.AURA_ALPHA)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED # Flat on the floor, so it must draw from above.


func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = Balance.AURA_INNER_RADIUS
	torus.outer_radius = Balance.AURA_OUTER_RADIUS
	torus.rings = 24
	torus.ring_segments = 4 # The ring lies flat, so its tube is never seen from the side.
	ring = MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = material
	ring.scale.y = 0.08 # Flattened to a painted band rather than a tube.
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _build_chevron() -> void:
	# A flat wedge just outside the ring, pointing where the mover faces.
	var prism := PrismMesh.new()
	prism.size = Vector3(Balance.AURA_CHEVRON_WIDTH, Balance.AURA_CHEVRON_LENGTH, 0.02)
	chevron = MeshInstance3D.new()
	chevron.mesh = prism
	chevron.material_override = material
	chevron.rotation = Vector3(PI / 2.0, 0.0, 0.0) # Lays the wedge down with its apex toward local +Z, the facing.
	chevron.position.z = Balance.AURA_OUTER_RADIUS + Balance.AURA_CHEVRON_LENGTH / 2.0
	chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chevron)
