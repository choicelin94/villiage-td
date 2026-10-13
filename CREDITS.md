# Credits

This game uses third-party art and a third-party font. Licenses below are copied from the files or pages those assets were downloaded from. Nothing here is a guessed license.

## Village, trees, rocks, and roads

- **Pack:** Fantasy Town Kit (2.0)
- **Author:** Kenney (www.kenney.nl)
- **Download page:** https://kenney.nl/assets/fantasy-town-kit
- **File downloaded:** `kenney_fantasy-town-kit_2.0.zip`  
  https://kenney.nl/media/pages/assets/fantasy-town-kit/efe948d309-1754222374/kenney_fantasy-town-kit_2.0.zip
- **License:** Creative Commons Zero (CC0) 1.0 Universal  
  http://creativecommons.org/publicdomain/zero/1.0/
- **License file shipped with the pack:** copied unchanged to [`assets/village/LICENSE.txt`](assets/village/LICENSE.txt)

The pack's own `License.txt` says:

> Fantasy Town Kit (2.0)  
> Created/distributed by Kenney (www.kenney.nl)  
> License: (Creative Commons Zero, CC0)  
> http://creativecommons.org/publicdomain/zero/1.0/  
> You can use this content for personal, educational, and commercial purposes.  
> Support by crediting 'Kenney' or 'www.kenney.nl' (this is not a requirement)

The download is a **3D** kit (FBX, GLB, OBJ). Those model files are not in this repository. Trees and rocks in `assets/village/` are the earlier isometric renders (orthographic camera, view direction along (1, 1, 1)). Houses, walls, the farm, the workshop, and both towers were rendered again for the top-down map: orthographic camera south of the model, looking down, so the ground reads as a square and the front of the building stays visible. Grass and the dirt path are original square textures made for this game, not Kenney images. Several building renders stack more than one model on the same 1×1 cell.

OpenGameArt “Primitive Village” (CC0, https://opengameart.org/content/primitive-village) was checked and not used. Its tiles are isometric diamonds, which is the projection this map left behind. Kenney Tiny Town (CC0) is a 16×16 3/4 pixel set and was not mixed in with these renders.

| In this game | Kenney models in the render |
| --- | --- |
| `assets/village/road.png` | original dirt path, not a Kenney texture |
| `assets/village/tree.png` | `tree.glb` |
| `assets/village/tree_b.png` | `tree-crooked.glb` |
| `assets/village/tree_c.png` | `tree-high.glb` |
| `assets/village/rock.png` | `rock-large.glb` |
| `assets/village/wall.png` | `fence.glb` (four sides) and `pillar-wood.glb` |
| `assets/village/spear.png` | `planks.glb`, `wall-wood-corner.glb`, `roof-point.glb`, `banner-green.glb` |
| `assets/village/fire.png` | `planks.glb`, `pillar-wood.glb`, `chimney.glb`, `banner-green.glb` |
| `assets/village/house.png` | `planks.glb`, `wall-wood.glb`, `wall-wood-door.glb`, `roof.glb`, `chimney.glb` |
| `assets/village/workshop.png` | `planks.glb`, `wall-wood.glb`, `wall-wood-window-shutters.glb`, `roof-point.glb`, `stall.glb` |
| `assets/village/farm.png` | `fence.glb`, `hedge.glb`, plus an original dirt-colored ground slab (see below) |
| `assets/village/grass_a.png`, `grass_b.png` | original grass-colored ground slabs, not a Kenney texture |

`icon.png` is a scaled crop of `house.png`.

Grass tiles and the dirt path are original square textures painted for this game. The farm render still uses an original dirt-colored ground slab under the Kenney hedges. Those textures are not from the Fantasy Town kit.

### Packs that were checked and not shipped

- **Isometric Miniature Farm (2.0)** by Kenney, CC0, from https://kenney.nl/assets/isometric-miniature-farm (`License.txt` in that zip says Creative Commons Zero). It is a strong 2D isometric set, but the buildings are modular blocks. This slice uses the Fantasy Town renders above instead, so the farm zip is not in the repository.
- **Isometric Buildings** and **Isometric Landscape** by Kenney, both CC0 on their `License.txt`, are the older small isometric tiles. They are the same family as the previous tower-defense tiles and are not shipped.
- The earlier build used Kenney's 2D pack "Tower Defense assets (isometric)" (CC0, https://opengameart.org/content/tower-defense-assets-isometric). Those PNGs have been removed from this repository.

## Villagers and monsters

Villagers and monsters are no longer the LPC sheets. An infected villager becomes a spear goblin, which is a different drawing on purpose. Feet still register on the walker ellipse (`IsoVolume.from_feet`). Side-view cycles flip on the horizontal part of the velocity and keep that flip while moving mostly north or south, so the cycle is not played backwards.

### LAYERLAB — 2D Characters, Cute Adventurers

- **Page:** https://layerlab.itch.io/2d-characters-cute-adventurers
- **File downloaded:** `2D Characters - Cute Adventurers_4_3.zip` (3.9 MB)
- **Spine export inside that zip:** `Export_4_3/redhood.json`. The skeleton block says `"spine": "4.3.26"`. Skins are `skin_0` through `skin_6`. Animations are `die`, `die2`, `down`, `idle`, `jump`, `jump2`, and `run`. The page lists Idle, Walk, Jump, and Die. The file names the locomotion clip `run`, not `walk`.
- **In this game:** `assets/characters/villager_0.png` through `villager_6.png`, in skin order wolf, penguin, raccoon, knight, frog, robot, skeleton. Each sheet is the pack's own PNG sequence (idle, run, down, die2) on the export canvas, with the standing foot at pixel (91, 144). `assets/characters/spine/redhood.spine-json`, `redhood.atlas`, and `redhood.png` are the packed Spine 4.3 export, used only if spine-godot is present.
- The `.spine` project, the loose limb folders, the image-sequence directory, and the zip are not in this repository. Jump is in the skeleton and is not a village action.

The itch page's license block says, in its own words:

> ✅ You CAN:
> - Used for commercial or non-commercial project
> - Can be modified to fit the purpose of the project
>
> ❌ You CANNOT:
> - Resale or distribute that file
> - Edit and resell those files to others
> - Create NFTs using those assets

The same page says: "This asset may not be used for training, input, or any purpose related to generative AI programs." It also says the frames can be used without Spine, and that a Spine Editor license is required to integrate the Spine runtime into a game you build and distribute, and to edit the `.spine` sources (those use meshes and need Spine Professional).

This page does not name CC0, CC-BY, or CC-BY-SA. Those names are not this pack's license.

### Spear goblin and shooting goblin

- **Spear page:** https://wigglesmith79.itch.io/spear-goblin
- **Spear file:** `Goblin spearman.zip` (3 MB). The download page dates that upload 10 July 2023.
- **Spear page text:** "Stabbing Goblin is a hand drawn(FREE), spine animated, goblin with a spear with all the animations you will need for you game. Along with the limbs to make your very own animations(With Spine)." It lists "PNG files of all limbs", "PNG flies of frame by frame animations", and "Walk, Idle, Stab, hurt." The info table says "No generative AI was used".
- **Shooter page:** https://wigglesmith79.itch.io/shooting-goblin
- **Shooter file:** `shooting goblin.zip` (170 MB)
- **Shooter page text:** "Shooting Goblin is a hand drawn, spine animated, goblin with a gun with all the animations you will need for you game. Along with the limbs to make your very own animations(With Spine)." It lists "Walk, Idle, Shoot, Reload, Stun, death." The info table says "No generative AI was used".
- Neither zip contains a `LICENSE` file, a Spine `.json`, a `.atlas`, or a `.skel`. The spear zip's `Goblin spearman.clip` starts with the bytes `CSFCHUNK` and is not a Spine skeleton. spine-godot cannot play these two packs. The game uses their frame PNGs.
- **In this game:** `assets/characters/spear.png` (idle, walk, stab, hurt) and `assets/characters/shooter.png` (idle, walk, shoot, stun, death). Shooter frames were scaled down from source PNGs around 3000×3600. Reload frames and the limb sheets were not shipped. Spear goblins are normal zombies, fast zombies, and infected villagers. The gun goblin is a brute or the boss.
- The pages do not state CC0, CC-BY, or CC-BY-SA. This file does not invent a license for them.

### Spine runtime, not shipped

Esoteric publishes a spine-godot 4.3 GDExtension for Godot 4.7.2:

https://spine-godot.s3.eu-central-1.amazonaws.com/4.3/4.7.2-stable/spine-godot-extension-4.3-4.7.2-stable.zip

That zip contains desktop libraries and web wasm (a threads build and a nothreads build). It is not in this repository.

The Spine Runtimes License, last updated April 5, 2025, https://esotericsoftware.com/spine-runtimes-license , says:

> Integration of the Spine Runtimes into software or otherwise creating derivative works of the Spine Runtimes is permitted under the terms and conditions of Section 2 of the Spine Editor License Agreement: http://esotericsoftware.com/spine-editor-license
>
> Otherwise, it is permitted to integrate the Spine Runtimes into software or otherwise create derivative works of the Spine Runtimes (collectively, "Products"), provided that each user of the Products must obtain their own Spine Editor license and redistribution of the Products in any form must include this license and copyright notice.

No Spine Editor license was provided for this project. Putting the runtime in a public Pages build would require that license, or a Spine Editor license for every player. The web export therefore keeps `variant/extensions_support=false` and `variant/thread_support=false`, which is also what lets the existing GitHub Pages host serve the game without COOP/COEP headers.

`scripts/spine_actor.gd` creates a `SpineSprite` only when those classes already exist. On a machine allowed to use the runtime, extract the official `bin/` into the project and villagers play `idle`, `run`, `down`, and `die2` on `skin_0`..`skin_6`. The frame sprite remains the screen box registered to the same feet.

### Removed and not shipped

The previous villagers and zombie were Liberated Pixel Cup sheets (CC-BY-SA 3.0, t-shirt layer OGA-BY 3.0) from the Universal LPC Spritesheet Character Generator, https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator . `assets/people/*.png` and `assets/enemies/zombie_walk.png` are no longer in this repository.

## Villagers and zombies (previous LPC notes, files removed)

The sheets below are not in the repository anymore. The credit is kept so the old files stay attributed. Villagers and zombies were Liberated Pixel Cup (LPC) sprites. Each villager was a stack of a body, pants, shirt, shoes, head, eyes, and hair. The zombie was the LPC zombie body plus the LPC zombie head. They were not nude bases.

- **Collection:** Universal LPC Spritesheet Character Generator, `spritesheets/` on the `master` branch  
  https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator
- **Credits table used:** `CREDITS.csv` in that repository  
  https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator/blob/master/CREDITS.csv
- **License of those removed PNGs:** Creative Commons Attribution-ShareAlike 3.0 Unported (CC-BY-SA 3.0)  
  https://creativecommons.org/licenses/by-sa/3.0/legalcode

Where a source file lists more than one license, this game uses **CC-BY-SA 3.0**. The short-sleeve t-shirt is only **OGA-BY 3.0**. That license's section 8(g) says the work may be distributed under CC-BY 3.0:

> You may distribute this work under the terms of the Creative Commons Attribution 3.0 license (CC-BY 3.0), which can be found here: https://creativecommons.org/licenses/by/3.0/legalcode

The t-shirt is stacked with CC-BY-SA body, pants, hair, and shoes, so the combined villager PNGs are shared under CC-BY-SA 3.0. Game code stays under the MIT license. CC-BY-SA applies to these character images, not to the code.

Each PNG is a full LPC walk cycle: 9 columns by 4 rows of 64×64, scaled 2× with nearest-neighbor filtering to 128×128 frames (sheet 1152×512). Row 0 is up, the back of the character. Row 1 is left. Row 2 is down, the face toward the camera. Row 3 is right. That row order was checked on the eye layer: row 0 has no eyes, row 2 has both eyes, and the eyes sit left of center on row 1 and right of center on row 3. The game chooses the row from screen-space velocity and plays the columns while the character moves. Feet stay on the bottom of each frame. `zombie_walk.png` uses the same layout. The earlier stills `zombie_stand.png` and `zombie_hold.png` are not shipped.

| Previously shipped | LPC layers, in draw order |
| --- | --- |
| `assets/people/man_brown.png` | `body/bodies/male/walk.png`, `legs/pants/male/walk.png`, `torso/clothes/shortsleeve/tshirt/male/walk.png`, `feet/shoes/basic/male/walk.png`, `head/heads/human/male/walk.png`, `eyes/human/adult/neutral/walk.png`, `hair/bedhead/adult/walk.png` |
| `assets/people/man_blue.png` | Same stack as `man_brown.png`. The shirt layer's hue is shifted to blue. That recolor is a change made for this game. |
| `assets/people/man_old.png` | Same body, pants, shoes, head, and eyes. Shirt hue is shifted toward olive. Hair is `hair/messy1/adult/walk.png` with the color pulled to gray. Both edits were made for this game. |
| `assets/people/woman.png` | `body/bodies/female/walk.png`, `legs/pants/thin/walk.png`, `torso/clothes/shortsleeve/tshirt/female/walk.png`, `feet/shoes/basic/thin/walk.png`, `head/heads/human/female/walk.png`, `eyes/human/adult/neutral/walk.png`, `hair/long/adult/walk.png` |
| `assets/enemies/zombie_walk.png` | `body/bodies/zombie/walk/zombie.png`, `head/heads/zombie/adult/walk.png` |

Authors and source pages, taken from `CREDITS.csv` (not guessed):

| Layer | Authors | Licenses listed on the source | Page |
| --- | --- | --- | --- |
| Male body | bluecarrot16, Benjamin K. Smith (BenCreating), Evert, Eliza Wyatt (ElizaWy), TheraHedwig, MuffinElZangano, Durrani, Johannes Sjölund (wulax), Stephen Challener (Redshrike) | CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-character-bases |
| Female body | Benjamin K. Smith (BenCreating), bluecarrot16, TheraHedwig, Evert, MuffinElZangano, Durrani, Pierre Vigier (pvigier), Eliza Wyatt (ElizaWy), Matthew Krohn (makrohn), Johannes Sjölund (wulax), Stephen Challener (Redshrike) | OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-character-bases |
| Human male and female heads | bluecarrot16, Benjamin K. Smith (BenCreating), Stephen Challener (Redshrike) | OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-character-bases |
| Eyes | JaidynReiman, Matthew Krohn (makrohn), Stephen Challener (Redshrike) | OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles |
| Pants, male | bluecarrot16, JaidynReiman, Eliza Wyatt (ElizaWy), Matthew Krohn (makrohn), Johannes Sjölund (wulax) | OGA-BY 3.0, GPL 3.0, CC-BY-SA 3.0 | https://opengameart.org/content/lpc-medieval-fantasy-character-sprites |
| Pants, thin (woman) | bluecarrot16, JaidynReiman, Eliza Wyatt (ElizaWy), Joe White, Matthew Krohn (makrohn), Johannes Sjölund (wulax) | OGA-BY 3.0, GPL 3.0, CC-BY-SA 3.0 | https://opengameart.org/content/lpc-clothing-updates |
| Short-sleeve t-shirt | Eliza Wyatt (ElizaWy), JaidynReiman | OGA-BY 3.0 | https://opengameart.org/content/lpc-revised-character-basics |
| Shoes | bluecarrot16, Johannes Sjölund (wulax) | OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-medieval-fantasy-character-sprites |
| Hair: bedhead, long, messy1 | Manuel Riecke (MrBeast) | CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles |
| Zombie body | Stephen Challener (Redshrike), Johannes Sjölund (wulax), Sander Frenken (castelonia), Benjamin K. Smith (BenCreating), bluecarrot16 | CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-zombie |
| Zombie head | bluecarrot16, Benjamin K. Smith (BenCreating), Sander Frenken (castelonia), Stephen Challener (Redshrike) | CC-BY-SA 3.0, GPL 3.0 | https://opengameart.org/content/lpc-zombie |

### Removed and not shipped

- Kenney's Topdown Shooter civilians and zombie (`manBrown_stand.png`, `manOld_stand.png`, `manBlue_stand.png`, `womanGreen_stand.png`, `zoimbie1_stand.png`, `zoimbie1_hold.png`) have been removed. That pack is CC0, but it does not match the LPC villagers.
- Riley Gombart's "Animated Top Down Zombie" (OpenGameArt, CC0 on that page) was an earlier zombie. Those frames are not in this repository.
- Engvee, "FREE Animated Isometric Zombies" on itch.io, was not used. That page does not state CC0, CC-BY, or CC-BY-SA.
- Nude Cabbit / AntumDeluge body templates were not shipped.
- Kenney isometric character renders (Mini Characters, Graveyard Kit, Animated Characters 3) were not shipped. Their scale and style do not match this LPC set.

## Font

- **Font:** Noto Sans SC Regular (the Simplified Chinese face of Noto Sans CJK / Source Han Sans)
- **Copyright, from the font name table:** © 2014-2021 Adobe (http://www.adobe.com/). Noto is a trademark of Google Inc.
- **Designers, from the font name table:** Ryoko NISHIZUKA 西塚涼子 (kana, bopomofo and ideographs); Paul D. Hunt (Latin, Greek and Cyrillic); Sandoll Communications 산돌커뮤니케이션, Soo-young JANG 장수영 and Joo-yeon KANG 강주연 (hangul elements, letters and syllables). Project architect: Dr. Ken Lunde. Production and ideograph elements: Masataka HATTORI 服部正貴.
- **License:** SIL Open Font License 1.1  
  http://scripts.sil.org/OFL
- **Source:** https://github.com/notofonts/noto-cjk (`Sans/SubsetOTF/SC/NotoSansSC-Regular.otf`)  
  https://fonts.google.com/noto/specimen/Noto+Sans+SC
- **Bundled file:** [`assets/fonts/NotoSansSC-Regular.otf`](assets/fonts/NotoSansSC-Regular.otf)  
  The full Regular face, not a character subset. The earlier Droid Sans Fallback subset missed glyphs such as 倒、大、小、总、数、时、计, which the web build drew as boxes because HTML5 has no system-font fallback.
- The license text shipped with that Noto CJK file is in [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt).

## Code and effects drawn in the game

- Game code in this repository is under the MIT License. See [`LICENSE`](LICENSE).
- Spears, fireballs, flames, range rings, shadows, and hit flashes are drawn with Godot canvas calls. They are not taken from an asset pack.
