# Mover character: Godot guide

How to bring the mover models into Ghosted Movers (Godot 4.7.2, Mobile renderer) and drive their animations from the spec's mover rules. Everything here was tested by importing `mover_orange.glb` into Godot 4.7.2 headless and running `actors/mover_model.gd` against it.

## Files

| File | What it is |
| --- | --- |
| `assets/models/mover_orange.glb` | Mover with an orange shirt (the reference look) |
| `assets/models/mover_red.glb` | Same mover, red shirt |
| `assets/models/mover_green.glb` | Same mover, green shirt |
| `assets/models/mover.blend` | Blender 5.2 source for all three, plus every animation |
| `actors/mover_model.gd` | `MoverModel`: picks the animation, playback speed and team colour |
| `assets/models/mover_anim_sheet.png`, `mover_trio.png` | Preview renders |

All three `.glb` files share the same skeleton, bone names, animation names and material names, so code written for one works for all.

## 1. Put the models in the project

1. Copy the three `.glb` files into `res://assets/models/` and `mover_model.gd` into `res://actors/`.
2. Focus the Godot editor. It imports them automatically; nothing needs changing in the Import dock.
3. Commit the `.glb` files and the `.import` files Godot creates next to them. Don't commit `.godot/`.

What the import gives you (checked in 4.7.2):

- Animations are named `mover_idle`, `mover_run` and so on. Godot strips the `-loop` suffix from the Blender names and sets those clips to loop.
- One `AnimationPlayer`, one `Skeleton3D` with 18 bones and one `MeshInstance3D` with 13 surfaces.
- Materials keep their Blender names (`Mover_Team`, `Mover_Shirt` and so on) as `resource_name`.

## 2. Set up `Mover.tscn`

```
Mover (CharacterBody3D)            actors/mover.gd
├── CollisionShape3D               CapsuleShape3D, radius 0.35, height 1.7, position y = 0.85
└── Model (Node3D)                 actors/mover_model.gd
    └── mover_orange (instanced .glb)
```

- **Scale:** 1 unit = 1 m. The mover is 1.74 m tall with its feet at the origin, so no scaling or offset is needed.
- **Facing:** the model's front is +Z (Godot's `Vector3.MODEL_FRONT`). Turn the `Model` node, not the body, with `face_direction()`.
- **Colour per player:** swap the instanced `.glb` (orange, red or green shirt) and set `team_colour` on `Model` for the overalls.

## 3. Drive it from the mover

```gdscript
@onready var model: MoverModel = $Model

func _physics_process(delta: float) -> void:
	# ... existing movement code sets velocity ...
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	model.face_direction(flat, delta)
	model.update_locomotion(flat.length(), _carry_state(), is_bracing, is_on_slime, gust_active)

func _carry_state() -> MoverModel.Carry:
	if held == null:
		return MoverModel.Carry.NONE
	if held.is_flashlight:
		return MoverModel.Carry.FLASHLIGHT
	if held.is_two_person:
		return MoverModel.Carry.TEAM if held.both_handles_held() else MoverModel.Carry.DRAG
	return [MoverModel.Carry.LIGHT, MoverModel.Carry.MEDIUM, MoverModel.Carry.HEAVY][held.speed_class()]
```

The names `held`, `is_bracing`, `is_on_slime` and so on stand in for whatever `mover.gd` already tracks. A cursed item should report one speed class slower, as the Curse rule says, so a cursed medium item uses the heavy animations.

Call the one-shots at the moment the gameplay event happens:

| Gameplay event | Call |
| --- | --- |
| GRAB picks something up | `model.play_grab()` |
| THROW released | `model.play_throw()` |
| Mover tumbles | `model.play_tumble()`: 1.5 s on the ground, then `get_up` plays automatically |
| Item banked in the truck | `model.play_bank()` |
| Round result screen | `model.play_result(movers_won)`, then `model.clear_result()` for the next round |

While a one-shot plays, `update_locomotion()` is ignored, so a tumble is never cut short by movement input. Use `model.is_busy()` if gameplay needs to wait for it.

## 4. Animation reference

Lengths are at 1.0x speed (30 fps source).

| Animation | Length | Loops | Spec situation | Plays at 1.0x when moving at |
| --- | --- | --- | --- | --- |
| `mover_idle` | 2.0 s | yes | Standing, empty-handed | – |
| `mover_walk` | 0.67 s | yes | Moving slower than 2.2 m/s | 1.6 m/s |
| `mover_run` | 0.53 s | yes | Base speed 4.5 m/s | 4.5 m/s |
| `mover_carry_idle` | 2.0 s | yes | Holding a light or medium item | – |
| `mover_carry_run` | 0.53 s | yes | Carrying light (100%) or medium (80%) | 3.6 m/s |
| `mover_carry_heavy_idle` | 0.9 s | yes | Holding a heavy or cursed item | – |
| `mover_carry_heavy_walk` | 0.8 s | yes | Heavy carry, 60% speed | 2.7 m/s |
| `mover_team_carry_idle` | 2.0 s | yes | Holding a two-person handle | – |
| `mover_team_carry_walk` | 0.8 s | yes | Two-person carry, 70% speed | 3.15 m/s |
| `mover_drag` | 0.8 s | yes | One-handle drag, 25% (40% solo) | 1.1 m/s |
| `mover_grab` | 0.47 s | no | GRAB pick-up; ends in the carry pose | – |
| `mover_throw` | 0.6 s | no | THROW a light item | – |
| `mover_brace` | 0.53 s | yes | BRACE held | – |
| `mover_tumble` | 1.5 s | no | Tumble: falls and lies flailing | – |
| `mover_get_up` | 0.53 s | no | Stands back up after a tumble | – |
| `mover_slime_slide` | 0.67 s | yes | Sliding on Ecto Slime | – |
| `mover_wind_push` | 1.0 s | yes | Gust of Wind, standing still | – |
| `mover_flashlight_aim` | 1.33 s | yes | Holding the flashlight still | – |
| `mover_bank_cheer` | 0.87 s | no | Item banked | – |
| `mover_victory` | 0.8 s | yes | Results: movers won | – |
| `mover_defeat` | 2.0 s | yes | Results: ghost won | – |

The last column is the speed at which the feet don't slide. `MoverModel` sets `AnimationPlayer.speed_scale = speed / that speed`, clamped to 0.5–1.8. If feet slide after `Balance.gd` changes, adjust `NATURAL_SPEED` in `mover_model.gd`.

For a drop, play `mover_grab` backwards: `player.play_backwards("mover_grab")`. Release doesn't need its own clip.

## 5. Parameters you can change

**In `mover_model.gd`**

| Constant or property | Default | Effect |
| --- | --- | --- |
| `team_colour` (exported) | `Color(0.16, 0.55, 0.88)` | Overalls and cap colour. Trim is derived as 35% lighter and seams as 55% darker. |
| `NATURAL_SPEED` | see table above | Stride matching for each moving clip |
| `WALK_RUN_SWITCH` | 2.2 m/s | Empty-handed walk/run cut-over |
| `MOVE_THRESHOLD` | 0.2 m/s | Below this the mover counts as standing |
| `BLEND_TIME` | 0.12 s | Cross-fade between clips |
| `SPEED_SCALE_MIN` / `SPEED_SCALE_MAX` | 0.5 / 1.8 | Limits on playback speed |

**Materials**

| Material | Used on | Changed by |
| --- | --- | --- |
| `Mover_Team` | Overalls, straps, cap | `team_colour` |
| `Mover_TeamTrim` | Rolled cuffs, cap strap | `team_colour`, lightened |
| `Mover_TeamDark` | Seams, pocket edges, brim underside | `team_colour`, darkened |
| `Mover_Shirt`, `Mover_ShirtDark` | Shirt and sleeve hem | Fixed per `.glb` (orange, red, green) |
| `Mover_Skin`, `Mover_Glove`, `Mover_Boot`, `Mover_Sole`, `Mover_Hair`, `Mover_Dark`, `Mover_White`, `Mover_Metal` | Body details | Not overridden |

The colours are plain material colours with no textures, so they cost almost nothing on the Mobile renderer. Each mover is about 8,300 triangles.

**Bones** (useful for `BoneAttachment3D`)

| Bone | Use it for |
| --- | --- |
| `hand.R` | The flashlight. `model.attach_to_hand(flashlight)` parents it there; then adjust its local transform. |
| `hand.L` | A second held prop |
| `head` | Effects that should follow the head (sweat drops, stars after a tumble) |
| `chest` | Effects on the body |
| `root` | Moves and rotates the whole body during tumbles; keep gameplay on the `CharacterBody3D` |

The full list is `root`, `hips`, `spine`, `chest`, `neck`, `head`, `upper_arm.L/R`, `forearm.L/R`, `hand.L/R`, `thigh.L/R`, `shin.L/R` and `foot.L/R`.

The overhead name tag the spec calls for is best done as a `Label3D` with billboard mode, placed about 2.1 m up. The chest badge stays blank on purpose.

## 6. Carrying while running, and the flashlight, with blending (optional)

`MoverModel` plays one clip at a time, which already covers every spec state. Two places would look better with an upper-body blend:

- the flashlight beam while walking, and
- a light carry using the run legs.

To get them, add an `AnimationTree` with a `Blend2` node. Feed the lower body from the locomotion clip and the upper body from `mover_flashlight_aim` or `mover_carry_idle`. Enable the filter on these bones: `spine`, `chest`, `neck`, `head` and every arm and hand bone.

This is an improvement for later, not something the spec needs.

## 7. Re-exporting from Blender

Only needed if you edit `mover.blend`.

1. Open `mover.blend` and switch to the `Mover` scene.
2. Select `MoverRig`, then shift-select `Mover`.
3. Choose File → Export → glTF 2.0 and set:
   - Format: glTF Binary (`.glb`)
   - Include: Limit to Selected Objects
   - Animation: Mode = Actions, and tick Always Sample Animations
4. Save over `mover_orange.glb`.

For the red and green versions, export from `MoverRig` and `Mover` too. Before each export, change `Mover`'s `Mover_Shirt` and `Mover_ShirtDark` material slots to the `_Red` or `_Green` copies, then put them back afterwards.

Don't export from `MoverRig_Red` or `MoverRig_Green`. In Blender 5 each action is tied to the original rig, so those exports come out with no animations.

New animations need to be actions whose names start with `mover_`. Add `-loop` to the name if the clip should loop.
