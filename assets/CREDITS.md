# Asset credits

Every third-party asset in the game, where it came from, and its licence. Raw downloads go in `assets/_incoming/` (ignored by Git and Godot); only the pieces the game uses are copied into `assets/`.

## Models

| Asset | Source | Licence | Pieces used (in `assets/models/decor/`) |
| --- | --- | --- | --- |
| Graveyard Kit 5.0 by Kenney | https://kenney.nl/assets/graveyard-kit | CC0 1.0 | `graveyard/`: iron-fence (gate leaves, perimeter fence), border-pillar (front gate posts), gravestone-round, gravestone-cross, gravestone-broken, lantern-candle, candle-multiple, fire-basket |
| Fantasy Town Kit 2.0 by Kenney | https://kenney.nl/assets/fantasy-town-kit | CC0 1.0 | `town/`: fountain-round-detail, hedge, hedge-large, lantern (street lamp) |
| Furniture Kit by Kenney | https://kenney.nl/assets/furniture-kit | CC0 1.0 | `furniture/`: bookcaseClosedWide, loungeSofa, loungeChair, kitchenCabinet, kitchenCabinetUpper, kitchenSink, kitchenStove |
| Nature Kit by Kenney | https://kenney.nl/assets/nature-kit | CC0 1.0 | `nature/`: statue_column, grass, grass_large |
| Farm truck (raw scan) | Sketchfab, "farm truck free raw scan" | To confirm: author and licence not yet recorded | `assets/models/truck/` (cut to 20k triangles); source in `assets/source/truck/` |
| Mover and ghost characters | The team's own models | Ours | `assets/models/mover/`, `assets/models/ghost/` |

The Kenney models are unchanged files. In the game their colours are muted toward grey and darkened (`DECOR_DESATURATION`, `DECOR_SHADE` in `autoload/Balance.gd`) so decor sits in the Mansion's dusk mood.

## Textures

All surface textures (`assets/textures/surfaces/`) and decor images (`assets/textures/decor/`: portraits, cobweb) are made by the project's own `tools/make_surface_textures.gd`. No third-party textures.

## Code

nipplejs 0.10.2 (MIT), vendored for the phone controller; its licence is in `controller/nipplejs_license.txt`.
