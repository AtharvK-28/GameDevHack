# Credits

Every third-party asset in the game, where it came from, and its licence. This file is also the in-game Credits screen. Raw downloads go in `assets/_incoming/` (ignored by Git and Godot); only the pieces the game uses are copied into the project.

## Game

### Ghosted Movers
Made for the Artificial Arcade hackathon (PS02: Chaos Control).  
Mover and ghost characters: the team's own models (`assets/models/mover/`, `assets/models/ghost/`).  
Surface textures, portraits, cobweb and ghost icon: made by the project's own `tools/` scripts.  
Wildlife (crows, bats, cat, rats, frogs, owl), the scarecrow, mailbox and hydrant: built from simple shapes in `arenas/dressing/`.  
All sounds (banking chime, night ambience, thunder, owl, howl, crows): synthesized in `autoload/Sfx.gd`.  

## Menus

### Maaack's Godot Game Template 1.7.0
Author: Marek Belski and contributors  
Source: [github: Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template)  
License: MIT. Used for the menus, options, pause, credits and scene loader (`addons/`, customised copies in `menus/`).  

## Art

### Kenney UI Pack
Author: Kenney  
Source: [kenney.nl: UI Pack](https://kenney.nl/assets/ui-pack)  
License: CC0 1.0. Buttons, panels, sliders, check boxes and click sounds (`assets/ui/kenney/`, `assets/ui/sounds/`), tinted by `tools/make_ui_theme.gd`.  

### Kenney Game Icons
Author: Kenney  
Source: [kenney.nl: Game Icons](https://kenney.nl/assets/game-icons)  
License: CC0 1.0. Lock, phone, checkmark, trophy, star and pause icons (`assets/ui/icons/`).  

### Kenney Graveyard Kit 5.0
Author: Kenney  
Source: [kenney.nl: Graveyard Kit](https://kenney.nl/assets/graveyard-kit)  
License: CC0 1.0. Iron fence and gates, gate posts, gravestones, lanterns, candles, fire basket (`assets/models/decor/graveyard/`).  

### Kenney Fantasy Town Kit 2.0
Author: Kenney  
Source: [kenney.nl: Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit)  
License: CC0 1.0. Fountain, hedges, street lamp (`assets/models/decor/town/`).  

### Kenney City Kit (Roads)
Author: Kenney  
Source: [kenney.nl: City Kit Roads](https://kenney.nl/assets/city-kit-roads)  
License: CC0 1.0. Road, street lamp and street sign (`assets/models/decor/roads/`).  

### Kenney Furniture Kit
Author: Kenney  
Source: [kenney.nl: Furniture Kit](https://kenney.nl/assets/furniture-kit)  
License: CC0 1.0. The only furniture source: loot (TV, armchairs, bookcase, coat stand, radio, side table, lamp, teddy bear), the sofa and rug props, and decor (bookcases, beds, kitchen, tables, chairs, benches, planters) in `assets/models/furniture/kenney/`, scaled and bottom-centred at import by `tools/furniture_post_import.gd`. The grand piano, grandfather clock, oil painting, vase, chandelier, suit of armour and door are built from simple shapes in its style (`props/catalog/built/`).  

### Kenney Nature Kit
Author: Kenney  
Source: [kenney.nl: Nature Kit](https://kenney.nl/assets/nature-kit)  
License: CC0 1.0. Statue, grass, trees, bushes, mushrooms, stumps, logs and rocks (`assets/models/decor/nature/`).  

The Kenney models are unchanged files. In the game their colours are muted toward grey and darkened (`DECOR_DESATURATION`, `DECOR_SHADE` in `autoload/Balance.gd`) so decor sits in the Mansion's dusk mood.

### Farm truck (raw scan)
Source: Sketchfab, "farm truck free raw scan"  
License: to confirm; author and licence not yet recorded. Cut to 20k triangles (`assets/models/truck/`); source in `assets/source/truck/`.  

## Fonts

### Baloo 2
Author: The Baloo 2 Project Authors (Ek Type)  
Source: [github: Baloo2](https://github.com/EkType/Baloo2)  
License: SIL Open Font License 1.1 (`assets/fonts/baloo2_OFL.txt`). Used on every screen and on the phone page.  

## Code

### nipplejs 0.10.2
Source: [github: nipplejs](https://github.com/yoannmoinet/nipplejs)  
License: MIT (`controller/nipplejs_license.txt`). The phone's joystick.  

### Godot Engine
Source: [godotengine.org](https://godotengine.org)  
License: MIT  
