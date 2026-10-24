# STYLE.md — Ghosted Movers visual style guide

Every new model, texture, effect or screen follows this page. It is derived from the intro cutscene's comic art and
the team's low-poly mover, so the menus, the cutscene and the 3D world read as one game.

## Style in one sentence

**A bright Saturday-morning comic laid over chunky low-poly 3D:** thick dark ink edges, saturated colours under warm
light, flat painted shading in clear bands, and comic lettering for anything loud. No photo textures, no realism,
no horror: it is a comedy.

## Palette anchors

| Name | Hex | Job |
| --- | --- | --- |
| Night | `#1a1228` | Backgrounds, the vignette, screen wipes |
| Panel | `#2b2142` | HUD and menu panels |
| Ink | `#120b1d` | Outlines, borders, shadows, text on paper |
| Paper | `#f6e7bd` | Caption boxes, keycaps, the vase meter |
| Ghost green | `#6dff8a` | The ghost, possession, Play and START, MOVE! |
| Gold | `#ffd04a` | Money, the title, celebration, DELIVERED! |
| Danger red | `#ff6b6b` | Damage, losses, the last 30 seconds, CRASH! |
| Sasta orange | `#ff9a3c` | The moving company: the truck, mover #1's cap |
| Lamplight | `#ffc070` | Windows, lamps, the warm yard light |
| Players | `#ffb84d` `#64d9ee` `#ed8bb6` `#b6de70` | Player 1 to 4, always the same player |

## Colour meanings (never swap these)

- **Green = the ghost.** Nothing else in the world glows green; environment glow is yellow, blue or purple only.
- **Red = danger and loss.** Gold = money and winning. The cyan generator zone is the only other "zone" colour.
- **A player's colour means that player**, every round. The role that round is shown by a ghost glow or icon, never
  by changing their colour.

## Light

1. **One key light:** the moon, high and to the camera's left (`MOON_ROTATION`); it alone casts shadows.
2. **Shared warm undertone:** lamplight windows, the yard light and a soft warm wash at the centre of the screen.
3. **Real value range:** dark violet surroundings, bright playfield. Shading is in bands (the truck's repaint, the
   UI's flat fills), not smooth gradients.
4. **Aerial perspective:** the depth fog fades distant trees and fences into the night colour, so far things are
   darker and less saturated than the house.
5. **The code light grade** (`assets/shaders/light_grade.gdshader`): a vignette into the night colour at the screen
   edges and a faint warm wash at the centre, drawn over the 3D world and under the HUD.

## Focal hierarchy

The house, the movers, the loot and the truck must be the brightest, most saturated things on screen. If
something in the background competes, **dim the background**; don't brighten the subject. Squint test: blur your
eyes at a screenshot and the movers and the driveway should still stand out.

## Characters and props

- Movers: chunky low-poly, overalls in their player's colour, a thin ink outline (`ink_outline.gdshader`).
- Props: Kenney's low-poly kits, muted toward grey (`DECOR_DESATURATION`) so they sit behind the movers. Loot keeps
  its colours.
- Any scanned or photo-textured model is repainted in flat colour with banded shading (`posterize.gdshader`).

## Text and effects

- Comic lettering (Bangers) with a thick ink outline for headlines, stamps and sound words in the world (CRASH!,
  KA-CHING!); Baloo 2 for everything you read.
- Effects are short, bright bursts that fade fast (`core/fx.gd`); settled things stop moving, so nothing in the
  background competes with play.
- No text baked into models or textures: labels are drawn by code, so they can change.
