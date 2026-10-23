# Valueless physics furniture such as a crate or a suit of armour. Movers cannot carry it; its Possessable child
# lets the ghost slide or hop it.
extends RigidBody3D

# --- Furniture settings ---
@export_enum("Crate", "Armour") var furniture_kind: int = 0
@export var catalog_item: CatalogItem # When set, its name, size, weight and model replace the kind's.

var item_name: String
var item_size: Vector3
var weight_class: int

# --- Setup ---
func _ready() -> void:
	item_name = Balance.FURNITURE_NAMES[furniture_kind] if catalog_item == null else catalog_item.display_name
	item_size = Balance.FURNITURE_SIZES[furniture_kind] if catalog_item == null else catalog_item.footprint
	weight_class = Balance.FURNITURE_WEIGHTS[furniture_kind] if catalog_item == null else catalog_item.weight_class
	add_to_group("furniture")
	mass = Balance.WEIGHT_MASSES[weight_class]
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	linear_damp = Balance.LOOT_LINEAR_DAMP
	angular_damp = Balance.LOOT_ANGULAR_DAMP
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = Balance.LOOT_FRICTION
	physics_material_override.bounce = Balance.LOOT_BOUNCE
	_build_shape()


# --- Visual helpers ---
func _build_shape() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = item_size
	collision.shape = shape
	add_child(collision)
	if catalog_item != null:
		var model: Node3D = catalog_item.model.instantiate()
		model.position.y = -item_size.y / 2.0 # Models are bottom-centred; the body's origin is its centre.
		model.scale = Vector3.ONE * catalog_item.model_scale
		add_child(model)
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = item_size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.FURNITURE_COLOURS[furniture_kind]
	mesh.material_override = material
	add_child(mesh)
