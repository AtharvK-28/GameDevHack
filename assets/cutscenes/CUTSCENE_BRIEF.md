# Cutscene brief: "The Malhotra Fortune"

The story panels for all three maps, generated with Gemini. All of it is in the game (decisions 145 and 146). The ghost
panels became videos, with the same words.

## How the cutscenes work in the game

- Each cutscene is a run of still pictures (panels). Each panel shows for a few seconds and slowly zooms and drifts,
  with music and sound effects.
- **The game writes all the words** (caption box, speech bubble, title) over the picture. So the pictures must have
  **no text at all**: lettering stays sharp and spelled right, and we can change a line without redrawing.
- A caption box sits in the **top-left**; a speech bubble goes wherever the panel's notes say. Keep faces and the
  important action out of those areas.
- Enter skips to the next panel and Esc skips the whole cutscene, so long stories never block a demo.

## What to deliver

| | |
|---|---|
| Shape | **16:9 landscape**. Pick 16:9 in Gemini if offered; otherwise the prompt asks for it. |
| Size | As large as Gemini allows; 1920 × 1080 or more is ideal (the slow zoom shows softness). |
| Format | JPG or PNG. |
| Names | Exactly as listed below, e.g. `m01_godown.jpg`. |
| Where | Send them to me, or drop them in `assets/cutscenes/mansion/`, `ship/`, `museum/` and `epilogue/`. Character sheets go in `assets/source/cutscenes/` (Godot skips that folder). |

## How to get consistent results from Gemini

1. **Make the 7 reference sheets first** (section A). Keep the best of each.
2. **One Gemini chat per act.** Start it with the **setup message** below and attach the reference sheets that act
   needs. Gemini then keeps the style and the characters' looks across the chat.
3. Paste one panel prompt at a time. If a result is close but not right, ask for an edit in the same chat ("make the
   ghost bigger", "move the goat to the right") instead of starting again.
4. **If Gemini writes any text** (signs, gibberish letters, speech bubbles), reply: *"Remove all text, letters and
   speech bubbles from this image. Change nothing else."*
5. Generate 2–4 versions of the important panels (the ghost reveals and the titles) and pick the best.

### Setup message (paste at the start of every chat)

> I'm making the story cutscenes for a comedy video game set in Mumbai, India. I'll ask for one comic panel at a
> time. Every panel must follow these rules:
> - Wide 16:9 landscape, one single image filling the whole frame: no panel borders, no comic page layout.
> - Style: bold modern comic illustration with thick confident ink outlines, painterly cel shading, rich saturated
>   colours, moody night palette with warm lamp-light highlights, and the slapstick energy of an animated comedy film.
>   Chunky cartoon proportions.
> - Absolutely NO text anywhere: no letters, words, numbers, signs, captions, speech bubbles, sound effects or
>   watermarks. Leave signs and papers blank.
> - Keep the characters exactly as in the attached reference sheets.
>
> Reply "ready" and wait for my first panel.

---

## The story in one minute

**Sasta Shifters** are Mumbai's cheapest movers: four movers (the players) and **Riya**, their boss on the
walkie-talkie. Every job they take is chasing the same thing without knowing it: **the Malhotra fortune**, a chest of
gold.

- **Act 1, the Old Mansion.** Rich kid **Vicky Malhotra** hires the crew to empty his great-grandfather's mansion by
  morning. But **Seth-ji**, the great-grandfather, died 40 years ago and never moved out. *"If I can't keep them,
  nobody can!"* After the job, Riya finds Seth-ji's diary: his fortune was stolen by a sea captain in 1946 and sank
  on his ship, the *Sagar Rani*.
- **Act 2, the Ghost Ship.** Vicky's cheque bounces. So the crew hires a rusty tug and goes after the gold
  themselves. The *Sagar Rani* is floating, and its drowned **Captain Kaala Daant** ("Black Tooth") still says
  every doubloon is his. On the way home, a giant wave...
- **Act 3, the Museum.** The tug sank, and so did the company. Then the morning paper: *"Vicky Malhotra donates
  sunken family fortune to City Museum."* He had the coast guard fish it out and took the credit. So the crew
  plans one last "moving job", at night, inside a museum guarded by **Bahadur**, a ghost night watchman who,
  it turns out, was Seth-ji's own watchman back in 1946.
- **Epilogue.** The crew gets away with the gold, and the three ghosts turn up in the back of the truck, arguing
  over whose it is. Bahadur settles it: *"It belongs to whoever CARRIED it."*

**Running gags:** the goat turns up in every act; the truck's slogan "We Move Anything\*" gets new small print
each act (lettered by the game).

---

## A. Reference sheets (make these first)

Not shown in the game; they keep the characters consistent. Ask for a **plain light-grey background** on each.

### A1 `ref_crew.png`: the Sasta Shifters crew

> Character reference sheet on a plain light-grey background, in a bold modern comic style with thick ink outlines
> and cel shading. Five members of a cheap Mumbai moving company standing in a row, full body, front view:
> - Four movers with chunky, blocky cartoon builds, square jaws and thick eyebrows. All wear blue denim overalls
>   with rolled cuffs, blue baseball caps, brown work gloves and tan work boots. Their short-sleeved shirts are
>   orange, red, green and yellow, one colour each. Varied heights and builds: one tall and broad, one short and
>   round, one lanky, one average. Comic expressions: proud, nervous, sleepy, cheerful.
> - Their boss Riya: a sharp, confident Indian woman in her thirties, in the same blue overalls over a white
>   T-shirt, a red bandana tied over her hair, a pencil behind her ear, a clipboard under one arm and a chunky
>   yellow walkie-talkie in her hand. She stands slightly forward of the others with a knowing grin.
>
> No text anywhere.

### A2 `ref_sethji.png`: Seth-ji, the Mansion's ghost

> Character reference sheet on a plain light-grey background, in a bold modern comic style. Seth-ji, the ghost of a
> rich old Indian businessman, three poses (calm, furious, clutching a vase protectively). He is a plump, glowing,
> pale-blue translucent ghost shaped like a floating sheet with a wispy tail instead of legs and stubby arms. He has
> angry bushy white eyebrows, a big white handlebar moustache, small gold-rimmed round spectacles and a tiny black
> cap. Soft cyan glow around his edges. Grumpy, possessive, comic rather than scary. No text anywhere.

### A3 `ref_vicky.png`: Vicky Malhotra, the rich kid

> Character reference sheet on a plain light-grey background, in a bold modern comic style. Vicky, a smug Indian
> man in his mid-twenties: slicked-back hair, sunglasses worn at night, a white linen blazer over a loud printed
> T-shirt, a gold chain, white sneakers, and a phone always in his hand. Three poses: taking a selfie, waving
> someone away, and shocked with his sunglasses slipping down. A spoiled, harmless comedy villain. No text anywhere.

### A4 `ref_captain.png`: Captain Kaala Daant, the Ship's ghost

> Character reference sheet on a plain light-grey background, in a bold modern comic style. Captain Kaala Daant
> ("Black Tooth"), the ghost of a drowned sea captain, three poses (looming, laughing, pointing). He glows sea-green
> and is see-through. He wears a black tricorn hat with a gold band and a small skull badge, and a navy-blue coat
> with gold buttons and gold epaulettes. His beard is made of short curling green tentacles. He has glowing yellow
> eyes, one blackened front tooth in a wide grin, and an old brass lantern in one hand. A wispy tail instead of
> legs. An original character: he must not resemble Davy Jones or any existing pirate character. No text anywhere.

### A5 `ref_bahadur.png`: Bahadur, the Museum's ghost

> Character reference sheet on a plain light-grey background, in a bold modern comic style. Bahadur, the ghost of an
> old Indian night watchman (a chowkidar), three poses (blowing his whistle, holding up a torch, standing to
> attention with his bamboo stick). He is a translucent grey-green ghost with a wispy tail instead of legs. He wears
> a khaki uniform shirt with a dark brown belt and a khaki peaked cap. He has a thick black moustache and stern but
> kind eyes. A brass whistle hangs on a red cord, and he carries a long bamboo lathi and a torch with a warm yellow
> beam. Dutiful, proud, a little comic. No text anywhere.

### A6 `ref_goat.png`: the goat

> Character reference sheet on a plain light-grey background, in a bold modern comic style. A small white goat with
> a brown patch over one eye, a tiny brass bell on a red string, and a permanently unimpressed expression. Three
> poses: standing, chewing paper, and bleating. No text anywhere.

### A7 `ref_vehicles.png`: the truck, the tug and the van

> Vehicle reference sheet on a plain light-grey background, in a bold modern comic style. Three vehicles side by
> side:
> 1. The Sasta Shifters truck: a small, battered mustard-yellow Indian goods truck with a high wooden cargo box,
>    dents, one headlight taped on, garlands of marigolds on the grille, and a blue tarp roped over an overloaded
>    roof.
> 2. A rusty orange harbour tug with a stubby funnel, car-tyre bumpers and a patched hull.
> 3. A borrowed white panel van with one door a different colour, a cracked side mirror and a roof rack.
>
> Leave all sides blank: no text or logos.

---

## B. Act 1: The Old Mansion (8 panels, about 50 s)

Chat setup: attach A1, A2, A3, A6, A7.

### m01_godown.jpg (6 s)

> Panel 1. Night, monsoon rain outside. The inside of a cramped, leaky Mumbai warehouse that is the Sasta Shifters
> office: stacked cardboard boxes, buckets catching drips, a single hanging bulb, a calendar with nothing marked.
> The four movers lounge around an upturned crate playing cards, bored and broke. Riya bursts in through the door
> on the right, soaking wet, holding up her phone triumphantly. Keep the top-left quarter as plain warehouse wall.
> Same style as before, wordless, 16:9.

- **Caption:** MUMBAI. MONSOON. SASTA SHIFTERS, THE CITY'S CHEAPEST MOVERS, HAVEN'T HAD A JOB IN THREE WEEKS.
- **Bubble (Riya, upper right):** Pack up, team. We've got a **CLIENT!**

### m02_vicky_call.jpg (6 s)

> Panel 2. Close-up of Riya's phone held in her wet hand, filling most of the frame. On the screen, a video call:
> Vicky in sunglasses at night, lounging on an inflatable flamingo in a glowing rooftop pool, with party lights
> behind him, holding a drink and waving lazily. Riya's face is reflected faintly in the dark edge of the screen,
> unimpressed. Keep the top-left quarter clear and dark. Same style as before, wordless, 16:9.

- **Caption:** THE CLIENT: VICKY MALHOTRA. GREAT-GRANDSON. "ENTREPRENEUR".
- **Bubble (Vicky, top right of the phone):** Empty great-grandpa's mansion by morning, bro. Sell **everything.**

### m03_truck_road.jpg (5 s)

> Panel 3. The overloaded Sasta Shifters truck struggling up a steep, winding hill road at night in heavy rain,
> headlights blazing, water splashing from the tyres, the blue tarp flapping. Two movers are visible in the cab, one
> pointing ahead in panic. The goat stands in the middle of the road in the headlights, completely unbothered. Palm
> trees and old street lamps; city lights far below. Keep the top-left quarter as dark sky. Same style as before,
> wordless, 16:9.

- **Caption:** MALABAR HILL. THE MALHOTRA MANSION HAS BEEN EMPTY FOR FORTY YEARS.
- **Bubble (a mover in the cab, centre right):** Are you **sure** this hill is on the GPS?!

### m04_arrival.jpg (6 s)

> Panel 4. Low angle at the rusted iron gates of a huge, crumbling colonial-era Indian mansion on a hilltop at night:
> turrets, carved balconies, broken shutters, an overgrown garden and a dry stone fountain. A lightning bolt splits
> the sky. The four movers and Riya stand small in the foreground, looking up. In one upstairs window, a faint
> pale-blue glow with two angry eyes. Keep the top-left quarter as stormy sky. Same style as before, wordless, 16:9.

- **Caption:** EMPTY... **MOSTLY.**

### m05_sethji.jpg (7 s, thunder)

> Panel 5. Inside the mansion's dusty drawing room by candlelight: cobwebbed chandelier, old portraits, a grand piano
> under a dust sheet, antique vases on every surface. Seth-ji rises up in the middle of the room, huge, glowing and
> furious, hugging a tall antique vase to his chest. Two movers in the doorway on the right freeze mid-step, one
> holding an empty cardboard box. Keep the top-left quarter as dark wall, and leave space top right for a speech
> bubble. Same style as before, wordless, 16:9.

- **Caption:** SETH DHANRAJ MALHOTRA. DIED 1986. **NEVER MOVED OUT.**
- **Bubble (Seth-ji, top right):** If I can't keep them... **NOBODY CAN!**

### m06_house_shake.jpg (4 s, the panel shakes)

> Panel 6. Chaos in the mansion's grand hall: the whole house is shaking. The chandelier swings wildly, chairs and
> vases fly through the air, paintings tilt and a rug whips up like a wave. Seth-ji floats at the top of the stairs
> with his arms raised, eyes blazing. Three movers crouch in a braced position, gripping the floor; a fourth is
> knocked flat by a flying armchair. Strong motion lines and dust. Keep the top-left quarter as dim ceiling. Same
> style as before, wordless, 16:9.

- **Caption:** HE CAN POSSESS ANYTHING IN THE HOUSE. AND WHEN HE'S REALLY ANGRY...
- **Bubble (a mover, centre):** **BRACE!!**

### m07_title.jpg (8 s, title)

> Panel 7. Outside the mansion at night in the rain. The Sasta Shifters truck is backed up to the front steps with
> its cargo doors open and a loading ramp down. Riya stands on the ramp barking orders into her walkie-talkie. The
> four movers line up with determined faces, rolling up their sleeves, one holding a lantern. The mansion looms
> behind with Seth-ji's glowing face in a window. Keep the bottom fifth of the image calm and dark (wet driveway)
> for a big title, and the top-left quarter as sky. Same style as before, wordless, 16:9.

- **Caption:** Grab it, carry it, get it in the truck. The piano needs two. House shakes? **BRACE.** And remember: you break it, you **pay.**
- **Title:** THE OLD MANSION

### m08_diary.jpg (end of the Mansion match: the cliffhanger)

> Panel 8. Dawn light through dusty windows in the now-empty drawing room. Riya kneels by the grand piano's open
> bench, holding up an old leather diary that glows faintly pale blue. Behind her, the tired movers slump against
> the wall. A faint outline of Seth-ji watches over her shoulder, sad rather than angry. Keep the right half of the
> image soft and simple: the game shows the diary page there. Same style as before, wordless, 16:9.

- The game slides a yellowed diary page over the right half: *"14 March 1946. The Captain has taken it ALL. Every
  rupee of the Malhotra fortune, loaded onto his ship, the SAGAR RANI... The gold is still on board. — Dhanraj
  Malhotra"*
- **Bubble (Riya):** ...a ship **full of gold?**

---

## C. Act 2: The Ghost Ship (7 panels, about 45 s)

Chat setup: attach A1, A3, A4, A6, A7.

### s01_previously.jpg (6 s)

> Panel 1. Back in the leaky Sasta Shifters warehouse, daytime, grey monsoon light. Riya holds a cheque torn in
> half, steaming with anger. On a phone propped on a box, Vicky on a yacht shrugs with both palms up. The movers
> crowd round, outraged; one is chewing his cap. The goat in the corner is eating the other half of the cheque. Keep
> the top-left quarter as plain wall. Same style as before, wordless, 16:9.

- **Caption:** PREVIOUSLY... VICKY'S CHEQUE **BOUNCED.**
- **Bubble (Riya, top right):** If he won't pay us... his great-grandpa's **gold** will.

### s02_the_chart.jpg (6 s)

> Panel 2. Night in a fishing harbour. Riya spreads an old yellowed sea chart on an oil drum under a lamp, with
> Seth-ji's diary open beside it, and stabs a finger at a spot far out at sea. Behind her, the four movers look
> doubtfully at the rusty orange tug moored at the jetty, which is lopsided and patched with a car door. The goat
> stands on the tug's roof. Keep the top-left quarter as night sky. Same style as before, wordless, 16:9.

- **Caption:** THE DIARY SAID THE SAGAR RANI SANK IN 1946. THE FISHERMEN SAID SOMETHING ELSE.
- **Bubble (a mover, right):** Since when do we own a **BOAT?!**

### s03_the_wreck.jpg (7 s, foghorn)

> Panel 3. Night, thick fog on a black sea under a full moon. The small orange tug pulls up beside a huge rotting
> galleon with tattered sails, barnacled hull and broken rails. It is not sunk: it is floating and creaking,
> tilted. The movers stand at the tug's bow staring up, mouths open; one is seasick over the side. Lightning far
> away. Keep the top-left quarter as fog and sky. Same style as before, wordless, 16:9.

- **Caption:** THE WRECK WASN'T ON THE SEABED. IT WAS FLOATING. ROCKING. AND COMPLETELY EMPTY...

### s04_boarding.jpg (6 s)

> Panel 4. Two movers inch across a narrow wobbly plank from the tug up to the galleon's deck, arms out for
> balance, while the sea heaves below. On the deck beyond: barrels, a treasure chest, bottles with ships inside, a
> brass telescope, all glinting in the moonlight. Mist curls over the rails. Keep the top-left quarter as sky and
> rigging. Same style as before, wordless, 16:9.

- **Bubble (the lead mover, top centre):** In and out. Five minutes. What could **possibly** go wrong?

### s05_the_captain.jpg (7 s, flash and shake)

> Panel 5. Low angle on the galleon's main deck. Captain Kaala Daant erupts up through the deck boards, enormous and
> glowing sea-green, lantern held high, tentacle beard writhing, grinning with his black tooth. One mover throws his
> arms up in terror; another is flattened by a runaway rum barrel. Green light, sea spray and flying planks. Leave
> space top right for a speech bubble and the top-left quarter as dark sky. Same style as before, wordless, 16:9.

- **Caption:** CAPTAIN KAALA DAANT STOLE SETH-JI'S FORTUNE IN 1946. THE SEA TOOK HIM. **IT DIDN'T TAKE THE GOLD.**
- **Bubble (the Captain, top right):** **ARRR!** Every doubloon on this deck is **MINE!**

### s06_title.jpg (8 s, title)

> Panel 6. A high three-quarter view of the whole scene, like a game camera: the galleon and the little orange tug
> tied alongside, a big wave breaking over the plank, two movers carrying a treasure chest down the deck steps, oil
> lanterns waiting on posts, and the Captain looming at the bow. Keep the bottom fifth calm dark sea for a big title,
> and the top-left quarter as sky. Same style as before, wordless, 16:9.

- **Caption:** Haul the loot to the tug. Brace for waves. Light the lanterns. And mind the barrels!
- **Title:** THE GHOST SHIP

### s07_the_wave.jpg (end of the Ship match: the cliffhanger)

> Panel 7. Dawn on the open sea. The little orange tug, dangerously overloaded with treasure and the cheering
> movers, chugs toward the distant Mumbai skyline. Behind it, unseen by the crew, a colossal wave rises, and in the
> wave's curling face is the Captain's furious glowing face. The goat, alone, looks back at it. Keep the top-left
> quarter as sky. Same style as before, wordless, 16:9.

- **Title:** TO BE CONTINUED...

---

## D. Act 3: The Museum of Mostly Real Things (6 panels, about 45 s)

Chat setup: attach A1, A3, A5, A6, A7.

### u01_shipwrecked.jpg (6 s)

> Panel 1. Morning on a calm sea littered with floating junk: barrels, cardboard boxes, a life ring, the tug's
> funnel just poking out of the water. The four movers and Riya cling to a floating grand piano, soaked and
> miserable. The goat sits on top of the piano, perfectly dry. Keep the top-left quarter as sky. Same style as
> before, wordless, 16:9.

- **Caption:** PREVIOUSLY... WE LOST THE GOLD. AND THE TUG. **AND THE SPARE TYRE.**

### u02_the_paper.jpg (6 s)

> Panel 2. The Sasta Shifters warehouse, almost empty now: the truck outside the open shutter has a big yellow
> clamp on its wheel. The crew sit on the floor around one blanket. Riya holds up a newspaper, furious; its front
> page shows a big photo of Vicky grinning beside a chest of gold in a museum, and the headline area is a solid
> dark block. The movers lean in, outraged. Keep the top-left quarter as plain wall. Same style as before,
> wordless, 16:9.

- **Caption:** "VICKY MALHOTRA DONATES FAMILY FORTUNE TO CITY MUSEUM. 'FOUND IT MYSELF!'"
- **Bubble (all the movers, right):** That's **OUR** treasure!!

### u03_the_plan.jpg (7 s)

> Panel 3. Night, the warehouse lit by one lamp. A museum blueprint is spread on a crate, weighted down with chai
> glasses. Riya points at it with her pencil. The four movers wear black eye masks over their blue overalls and
> caps, looking hilariously un-sneaky; one wears his mask upside down. The goat wears a tiny mask too. Keep the
> top-left quarter as dark wall. Same style as before, wordless, 16:9.

- **Caption:** TECHNICALLY, STILL A MOVING JOB.
- **Bubble (Riya, top right):** We're not robbers. We're movers. We just... **move it.** At night.

### u04_the_museum.jpg (6 s)

> Panel 4. Night in the city. A grand classical museum with stone columns and wide steps, lit by street lamps,
> with a fountain in the forecourt and a city skyline behind. The borrowed white van creeps toward the loading dock
> with its headlights off. Through a tall window, a single torch beam sweeps across glass cases and a dinosaur
> skeleton. Keep the top-left quarter as night sky. Same style as before, wordless, 16:9.

- **Caption:** THE CITY MUSEUM. LASERS. CAMERAS. AND ONE NIGHT WATCHMAN...

### u05_bahadur.jpg (7 s, whistle)

> Panel 5. Inside a dark museum gallery, among exhibits on pedestals and a T-Rex skeleton. Bahadur the ghost
> watchman swoops out of the darkness, torch beam blazing straight at the viewer, whistle in his mouth, lathi raised.
> In the beam, two masked movers freeze mid-tiptoe like statues, one balancing a vase on his head. Leave space top
> right for a speech bubble and the top-left quarter as dark ceiling. Same style as before, wordless, 16:9.

- **Caption:** BAHADUR GUARDED THIS MUSEUM FOR FORTY YEARS. **DEATH DIDN'T CHANGE HIS ROSTER.**
- **Bubble (Bahadur, top right):** **JAAGTE RAHO!**

### u06_title.jpg (8 s, title)

> Panel 6. A high three-quarter view of the museum's interior like a game camera: galleries of glass cases, a
> rotunda with the dinosaur skeleton, a hall criss-crossed by red laser beams, and the white van waiting at the
> loading dock. The masked movers sneak in carrying a cardboard replica of a dinosaur skull. Bahadur's torch beam
> sweeps a far gallery. Keep the bottom fifth calm and dark for a big title, and the top-left quarter clear. Same
> style as before, wordless, 16:9.

- **Caption:** Load the van. Freeze when the whistle blows. Swap in the fakes. And don't break anything: we can't afford it.
- **Title:** THE MUSEUM OF MOSTLY REAL THINGS

---

## E. Epilogue (6 panels, after the Museum match)

Chat setup: attach A1, A2, A3, A4, A5, A6, A7.

### e01_dawn.jpg

> Panel 1. Dawn over Mumbai. The Sasta Shifters truck is parked back at the warehouse, steaming, dented and
> scorched. The four movers and Riya lie collapsed and exhausted on top of a heap of gold coins, goblets and a
> treasure chest in the open cargo box. Warm orange sunrise. Keep the top-left quarter as sky. Same style as
> before, wordless, 16:9.

- **Bubble (Riya):** We... actually **did it?**

### e02_hitchhikers.jpg

> Panel 2. Close on the back of the same truck. Sitting on the gold, as if they had always been there: Seth-ji,
> Captain Kaala Daant and Bahadur, all glowing and see-through. Seth-ji and Bahadur have just recognised each other,
> both pointing in shock. The Captain clutches a gold goblet. The crew, in the foreground, have frozen in horror.
> Leave space top left and top right for speech bubbles. Same style as before, wordless, 16:9.

- **Bubble (Bahadur):** **SETH-JI?!** Forty years I waited!
- **Bubble (Seth-ji):** Bahadur?! You're **STILL** on duty?

### e03_the_verdict.jpg

> Panel 3. The three ghosts float in a tense standoff above the gold. The Captain and Seth-ji are nose to nose,
> fists raised, shouting. Bahadur blows his whistle between them, holding up his lathi like a judge's gavel.
> Everyone else is frozen mid-motion. Then all three ghosts slowly turn their heads toward the four movers. Leave
> space top centre for a speech bubble. Same style as before, wordless, 16:9.

- **Bubble (Bahadur):** It belongs... to whoever **CARRIED** it.

### e04_meanwhile.jpg

> Panel 4. Inside the museum by day. Vicky stands in front of an empty plinth, sunglasses slipping off in shock,
> phone dropped. On the plinth is a single small sticky note (blank). In the glass case behind him, the goat is
> calmly eating an exhibit's plaque. Keep the top-left quarter clear. Same style as before, wordless, 16:9.

- **Caption:** MEANWHILE...
- The game letters the sticky note: *"Moved by Sasta Shifters. Terms and conditions apply."*

### e05_new_sign.jpg

> Panel 5. Sunny morning street. The Sasta Shifters truck, freshly repainted with marigold garlands, drives off with
> the crew waving from the cab and the back. Seth-ji carries a vase very, very carefully in the cargo box; the
> Captain rides on the roof like a ship's figurehead; Bahadur stands guard on the back step with his lathi. The goat
> wears a tiny blue cap. Keep the bottom fifth calm for a title. Same style as before, wordless, 16:9.

- **Caption (the truck's new small print):** SASTA SHIFTERS. WE MOVE ANYTHING\*. \*GHOSTS INCLUDED FREE.
- **Title:** THE END... OF THE BEGINNING?

### e06_next_job.jpg (post-credits stinger)

> Panel 6. Close-up of a blank job sheet pinned to the warehouse wall with a knife, next to a photo of a spooky old
> Bollywood film studio at night with a glowing golden trophy in its window. Dramatic red light. Keep the right half
> fairly plain: the game writes the job sheet. Same style as before, wordless, 16:9.

- The game letters: *"NEXT JOB: Clear out a haunted film studio. Fragile: 1 golden trophy."*

---

## Checklist

| Set | Images | Folder |
|---|---|---|
| A. Reference sheets | 7 | `assets/source/cutscenes/` |
| B. Old Mansion | 8 | `assets/cutscenes/mansion/` |
| C. Ghost Ship | 7 | `assets/cutscenes/ship/` |
| D. Museum | 6 | `assets/cutscenes/museum/` |
| E. Epilogue (optional) | 6 | `assets/cutscenes/epilogue/` |
| **Total** | **34** (28 without the epilogue) | |
