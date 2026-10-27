# One entry in the furniture catalog (props/catalog/<arena>/*.tres): a piece of loot, possessable furniture or
# static decor. Loot spawns on spawn spots whose role it suits, so a vase lands on a table and a TV on its
# cabinet; furniture and decor are placed by hand in each arena's dressing scene.
class_name CatalogItem
extends Resource

enum Category { LOOT, FURNITURE, DECOR }

# --- Identity ---
@export var id: StringName
@export var display_name: String
@export var category: Category = Category.LOOT
@export var model: PackedScene # Bottom-centred, front facing +Z.
@export var model_scale: float = 1.0 # Extra scale on top of the import's furniture scale.
# Multiplies the model's own colours. Kit models that share one palette texture cannot be recoloured
# per part, so this pulls the whole piece toward the arena's palette. White leaves it alone.
@export var tint := Color.WHITE

# --- Loot ---
@export var value: int = 0 # Rupees.
@export_enum("Light", "Medium", "Heavy", "Two-person") var weight_class: int = 0
@export_range(1, 3) var fragility: int = 1 # 1 sturdy, 3 glass.
@export var rolls: bool = false # Horizontal cylindrical loot can roll when released.
@export var throwable: bool = false
@export var two_person_handles: bool = false # A handle at each end along X, like the piano.
@export var count: int = 1 # How many of it the arena's pool holds.
@export var every_round: bool = false # Placed in every round, right after the centrepiece, like the Ship's parrot.
@export var loot_script: Script # A Loot subclass with its own behaviour (e.g. props/parrot.gd); empty for plain loot.

# --- Furniture ---
@export_enum("Slider", "Door", "Dropper", "Hopper", "Rug") var possessable_kind: int = 0

# --- Placement ---
@export var footprint := Vector3.ONE # Metres: the collider box, and the space it needs.
@export var spot_roles: Array[StringName] = [] # Spawn spot roles it can spawn on (loot only).
@export var pools: Array[StringName] = [] # Arena pools it belongs to, e.g. "mansion".
