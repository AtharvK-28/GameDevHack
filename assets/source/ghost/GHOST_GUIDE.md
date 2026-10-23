# Ghost character: Godot guide

How to use the ghost model in Ghosted Movers (Godot 4.7.2, Mobile renderer) and drive it from the spec's ghost rules. Everything here was tested by importing `ghost.glb` into Godot 4.7.2 headless and running `actors/ghost_model.gd` against it.

## Files

| File | What it is |
| --- | --- |
| `assets/models/ghost.glb` | The ghost: rigged, 9 animations, 4 face expressions |
| `assets/models/ghost.blend` | Blender 5.2 source (scene `Ghost`, with glowing preview materials and bloom) |
| `assets/shaders/ghost_body.gdshader` | The glowing see-through body |
| `assets/shaders/ghost_aura.gdshader` | The soft halo around the ghost |
| `actors/ghost_model.gd` | `GhostModel`: animations, expressions, glow shaders, opacity shimmer, particle trail |
| `assets/models/ghost_in_godot.png` | A real Godot 4.7.2 Mobile-renderer frame of the ghost with glow on |
| `assets/models/ghost_preview.png`, `ghost_anim_sheet.png` | Blender preview renders |

## The model

- **Size:** about 1.37 m tall including the curled tail, and 1.75 m across the claws. It's about 11,300 triangles, of which roughly half is the aura shell.
- **Origin:** at the middle of the body, not the tail tip. To match the spec's "flies 1.2 m up", set the wisp node's height to 1.2.
- **Facing:** the front is +Z (Godot's `Vector3.MODEL_FRONT`), the same as the movers.
- **Shape:** a smooth sheet body with a wavy, rippling hem, a long tail that curls up at the tip, and arms with three long hooked claws each.
- **Materials:**

| Material | Look | In Godot |
| --- | --- | --- |
| `Ghost_Body` | See-through blue core with a bright cyan rim; fades out toward the tail tip | Replaced by `ghost_body.gdshader`. The opacity shimmers between 25% and 45%, as the spec says, and a slow swirl drifts through the glow. |
| `Ghost_Aura` | An inflated shell just outside the body | Replaced by `ghost_aura.gdshader`: a soft additive halo, brightest just outside the outline and clear over the face. It pulses slowly. |
| `Ghost_Face` | Near-black navy | Eye sockets and mouth |
| `Ghost_Glow` | Cyan-white, very emissive | Pupils |
| `Ghost_Teeth` | Off-white, slightly emissive | Fangs |

The `.glb` stores plain stand-in materials for the body and aura, so it still looks reasonable without the script. `GhostModel` swaps in the shaders automatically.

## Keeping the glow

The glow comes from three things that work together:

1. **Rim and body glow:** the body shader's `EMISSION`. It always works.
2. **Halo:** the additive aura shell. It works even with bloom turned off.
3. **Bloom:** in the arena's `WorldEnvironment`, tick **Glow** (the spec already asks for this). The emissive pupils and rim then bloom, like the concept art. This works on the Mobile renderer, and `ghost_in_godot.png` was rendered that way with Filmic tonemapping.

Keep the shader files at `res://assets/shaders/`, or change the `body_shader` and `aura_shader` exports on `GhostModel` to point at their new location.

## 1. Scene setup

```
GhostWisp (Node3D or CharacterBody3D)      actors/ghost_wisp.gd
└── Model (Node3D)                          actors/ghost_model.gd
    └── ghost (instanced ghost.glb)
```

Copy these into your project:
- `ghost.glb` to `res://assets/models/`
- `ghost_model.gd` to `res://actors/`
- both `.gdshader` files to `res://assets/shaders/`

Godot imports the model with no import settings to change.

## 2. Driving it from the wisp

```gdscript
@onready var model: GhostModel = $Model

func _physics_process(delta: float) -> void:
	# ... wisp movement at 7 m/s, clamped to the house ...
	model.update_motion(velocity, delta)  # idle or move, turning, grin while moving

func _on_possess() -> void:
	model.play_possess()        # dives in and hides when done

func _on_leave_prop() -> void:
	global_position = prop.global_position
	model.play_emerge()         # pops back out

func _on_exorcised() -> void:
	model.play_exorcised(Balance.GHOST_STUN_SECONDS)  # knocked out, then dizzy for the 1 s freeze

func _on_haunting_or_curse_cast() -> void:
	model.play_cast()

func _on_item_shattered() -> void:
	model.play_laugh(1.5)
```

While an action plays, `update_motion()` is ignored. The stun is frozen in place, as the spec wants. The script handles the look only; `GhostWisp` should keep doing the gameplay checks (energy, cooldowns, the stun lock).

## 3. Animation reference

Lengths are at 1.0x speed (30 fps source).

| Animation | Length | Loops | Spec situation | Face |
| --- | --- | --- | --- | --- |
| `ghost_idle` | 2.0 s | yes | Free wisp hovering | default grin |
| `ghost_move` | 1.0 s | yes | Wisp moving (plays at 1.0x at 7 m/s) | Grin |
| `ghost_possess` | 0.5 s | no | POSSESS: dives into the prop and shrinks away | Squint |
| `ghost_emerge` | 0.5 s | no | LEAVE, or pushed out by energy or the truck zone | Grin |
| `ghost_cast` | 0.8 s | no | House Shake, Gust, Lights Out, Ecto Slime, Curse | Grin |
| `ghost_laugh` | 0.67 s | yes | Cackle after a shatter or a tumble | Laugh |
| `ghost_taunt` | 1.0 s | no | Claw wave, e.g. on the role reveal | Grin |
| `ghost_ejected` | 0.6 s | no | Exorcised: blasted out, spinning back | Stunned |
| `ghost_stunned` | 1.0 s | yes | The 1 s stun after an exorcism | Stunned |

`play_exorcised(1.0)` plays `ejected` and then `stunned` so that the two together last the full stun time.

The tail has five bones. Every animation drives it with a travelling wave, where each bone lags the one above it, so motion ripples from the body out to the curled tip. The looping clips (`idle`, `move`, `laugh`, `stunned`) are keyed every 2–5 frames, which keeps the float and flutter smooth.

## 4. Face expressions

The face uses blend shapes on the ghost mesh, so it changes shape smoothly with no texture swaps.

| Blend shape | Look |
| --- | --- |
| (none: all at 0) | Default mischievous fanged grin with angry eyes |
| `Grin` | Angrier eyes, wider evil grin |
| `Laugh` | Squeezed-shut eyes, huge open mouth |
| `Squint` | Narrow slit eyes, tight grin (possessing) |
| `Stunned` | Round dazed eyes, tiny "o" mouth |

`GhostModel` picks the expression for each animation. To set one yourself:

```gdscript
var mesh: MeshInstance3D = $Model.find_children("*", "MeshInstance3D", true, false)[0]
mesh.set_blend_shape_value(mesh.find_blend_shape_by_name(&"Laugh"), 1.0)
```

## 5. Parameters

These are exported on `GhostModel`:

| Property | Default | Effect |
| --- | --- | --- |
| `glow_colour` | `Color(0.4, 0.8, 1.0)` | Tints the body core, rim and halo together (e.g. green for a possessed or cursed look) |
| `body_shader` / `aura_shader` | the two `.gdshader` files | Swap these for your own shaders |
| `opacity_min` / `opacity_max` | 0.25 / 0.45 | The spec's shimmer range for the body |
| `shimmer_speed` | 1.2 | Shimmer cycles per second |
| `expression_speed` | 8.0 | How fast faces blend between expressions |
| `trail_enabled` | true | Particle trail from the tail: 24 small additive cyan-to-violet puffs |

These are constants in the script:

| Constant | Value | Effect |
| --- | --- | --- |
| `MOVE_ANIM_SPEED` | 7.0 m/s | Wisp speed at which `move` plays at 1.0x |
| `MOVE_THRESHOLD` | 0.3 m/s | Below this the ghost counts as idle |
| `TRAIL_OFFSET` | (0.45, -0.45, 0) | Where the trail emits from, near the tail tip |

You can also tune the look directly on the shaders (uniforms with sliders in the inspector):

| Shader | Uniform | Default | Effect |
| --- | --- | --- | --- |
| body | `rim_power` | 2.2 | Lower gives a wider glowing edge |
| body | `rim_opacity` | 0.55 | How solid the edge is |
| body | `glow_energy` / `rim_glow` | 1.4 / 2.4 | Core and edge brightness |
| body | `tail_fade` | 0.32 | How far up from the tail tip the body fades out |
| body | `swirl_amount` / `swirl_speed` | 0.18 / 1.6 | The drifting shimmer bands |
| aura | `intensity` | 0.9 | Halo strength |
| aura | `pulse_amount` / `pulse_speed` | 0.25 / 0.8 | Slow halo breathing |
| `BLEND_TIME` | 0.15 s | Cross-fade between clips |

**Bones**, useful for `BoneAttachment3D` (for example, curse sparks on a claw):
- `root` moves the whole ghost; possess, emerge and ejected use it to scale and spin
- `body`, `head`
- `tail1` to `tail5`
- `arm_upper.L/R`, `arm_lower.L/R`, `hand.L/R`

**Transparency.** The body shader writes depth (`depth_draw_always`), which stops the far side of the body showing through the front. The aura is additive and never writes depth, so it can't hide anything behind it. Both work on the Mobile renderer.

## 6. Re-exporting from Blender

`ghost.blend` keeps each ghost animation on its own NLA track on `GhostRig`.

1. In `Ghost`'s material slots, set slot 1 to `Ghost_Body` and slot 5 to `Ghost_Aura`. The `_Preview` versions use shader nodes that glTF can't export. Switch back to the `_Preview` materials afterwards for the glowing look in Blender.
2. Select `GhostRig`, then shift-select `Ghost`.
3. Choose File → Export → glTF 2.0 and set:
   - Format: glTF Binary
   - Include: Limit to Selected Objects
   - Animation: Mode = **NLA Tracks**, and tick Always Sample Animations
   - Shape Keys: on
4. Save over `ghost.glb`.

Use NLA Tracks mode, not Actions. In a Blender file that also holds the movers, Actions mode exports every mover animation onto the ghost too.

The same applies the other way round: if you re-export a mover from a file that also contains the ghost, its Actions export picks up the ghost animations. Export the movers from `mover.blend`, which contains only the movers.

New ghost animations need an action named `ghost_<name>`, put on its own NLA track (muted). Add `-loop` to the name if the clip should loop, and add the name to `LOOPING` in `ghost_model.gd`.
