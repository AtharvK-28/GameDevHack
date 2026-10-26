# Ghost Ship intro: panel brief for painted art

The Ghost Ship's intro plays four panels before the first round, like the Old Mansion's eleven. Today the panels are staged renders from the game (`tools/make_ship_intro.gd`) with the words lettered over them by the game. Painted panels in the same style as the Mansion intro can replace them with no code changes.

## How to drop in new art

1. Make each panel **1920 × 1080** (or 1024 × 572 like the Mansion panels: anything 16:9 works), JPG.
2. Save it over the file of the same name in `assets/cutscenes/ship/`.
3. Choose one way to letter it:
   - **Letter the words into the art yourselves**, like the Mansion panels. Then delete that panel's `"caption"`, `"bubble"` and `"title"` entries in `SHIP_INTRO_PANELS` in `autoload/Balance.gd`, so the game doesn't letter on top.
   - **Leave the art wordless.** Keep the entries, and the game letters them: caption top-left, bubble at the `"at"` position (shares of the screen width and height), title near the bottom.

Keep the important part of each picture away from the top-left third if the game letters the caption.

## The story so far

At the end of the Mansion intro, Seth-ji hired **Sasta Shifters** ("We Move Anything\*") to empty his haunted mansion. The Ship intro picks up after that job: Seth-ji's cheque bounced, so the crew takes the next job in the paper.

## Panels

### 1. The wreck (`01_the_wreck.jpg`, 7 s)

**Scene:** night, fog on a black sea. The crew's battered orange tug ("SASTA SALVAGE" painted on its side) pulls up beside a huge, rotting pirate galleon with tattered sails and a skull flag. Two Sasta Shifters movers in blue overalls and caps stand on the tug, staring up. One looks queasy. Lightning in the distance.

- **Caption:** MONTH-END. SETH-JI'S CHEQUE BOUNCED, SO SASTA SHIFTERS TOOK THE ONLY JOB LEFT IN THE PAPER: "SALVAGE A SHIPWRECK. NO QUESTIONS ASKED."
- **Bubble (a mover):** Since when do we own a **BOAT?!**
- **Sound:** foghorn, distant thunder, the sea shanty starts.

### 2. Boarding (`02_boarding.jpg`, 6 s)

**Scene:** the two movers cross a narrow, unrailed plank from the tug to the galleon's side. The galleon is visibly tilted and rocking. Its deck is empty but strewn with treasure: barrels, a chest, bottles, a brass telescope. Mist curls over the rails.

- **Caption:** THE WRECK WASN'T ON THE SEABED. IT WAS FLOATING. ROCKING. AND COMPLETELY EMPTY...
- **Bubble (the lead mover):** In and out. Five minutes. What could **possibly** go wrong?
- **Sound:** hull creaks, ropes straining.

### 3. The captain (`03_the_captain.jpg`, 7 s, the panel flashes and shakes)

**Scene:** low angle on the main deck. The ghost captain rises up glowing sea-green and see-through:
- a tricorn hat with a skull badge,
- a navy coat with gold buttons and epaulettes,
- a beard of short tentacles,
- glowing yellow eyes,
- a lantern in one hand,
- a wispy tail instead of legs.

He towers over a mover, who throws his arms up. A second mover is already knocked flat by a rolling rum barrel.

He must not look like Davy Jones or any other existing character. He is the game's own "drowned captain".

- **Caption:** NARRATOR: The captain went down with his ship. He did **not** stay down.
- **Bubble (the captain):** **ARRR!** Every doubloon on this deck is **MINE!**
- **Sound:** thunder crack, theremin, organ chord.

### 4. The job (`04_the_job.jpg`, 8 s)

**Scene:** a high three-quarter view of the whole ship and tug, as the game's camera sees it:
- a big wave breaking over the plank,
- two movers carrying the treasure chest down the forecastle steps,
- lanterns waiting to be lit on posts,
- the captain looming at the bow.

Leave the bottom fifth fairly calm for the title.

- **Caption:** Haul the loot to the tug. Brace for waves. Light the lanterns. And mind the barrels!
- **Title:** THE GHOST SHIP
- **Sound:** wave crash, title hit.

## Style notes

- Match the Mansion intro: bold comic illustration, ink outlines, moody night colours with warm highlights, readable from across a room.
- The palette is moonlit blue sea and sky, rotting brown wood, the bright orange tug and the sea-green ghost. Avoid neon green across the whole scene: keep the green on the captain.
- The movers are chunky and cartoonish, in blue overalls with orange or red shirts and blue caps.
