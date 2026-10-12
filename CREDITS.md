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

The download is a **3D** kit (FBX, GLB, OBJ). Those model files are not in this repository. The PNGs in `assets/village/` are isometric renders made for this game in Godot 4.7: orthographic camera, view direction along (1, 1, 1), GL Compatibility renderer. Several renders stack more than one model on the same 1×1 cell.

| In this game | Kenney models in the render |
| --- | --- |
| `assets/village/road.png` | `road.glb` |
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

The grass slabs and the farm's soil slab use small original albedo textures made for this game, rendered with the same camera and lights as the Kenney models. Those albedo textures are not from the Fantasy Town kit.

### Packs that were checked and not shipped

- **Isometric Miniature Farm (2.0)** by Kenney, CC0, from https://kenney.nl/assets/isometric-miniature-farm (`License.txt` in that zip says Creative Commons Zero). It is a strong 2D isometric set, but the buildings are modular blocks. This slice uses the Fantasy Town renders above instead, so the farm zip is not in the repository.
- **Isometric Buildings** and **Isometric Landscape** by Kenney, both CC0 on their `License.txt`, are the older small isometric tiles. They are the same family as the previous tower-defense tiles and are not shipped.
- The earlier build used Kenney's 2D pack "Tower Defense assets (isometric)" (CC0, https://opengameart.org/content/tower-defense-assets-isometric). Those PNGs have been removed from this repository.

## Villagers and zombies

Villagers and zombies are Liberated Pixel Cup (LPC) sprites at the same 64×64 frame size, so an infected villager reads as the same style of character. Each villager is a stack of a body, pants, shirt, shoes, head, eyes, and hair. The zombie is the LPC zombie body plus the LPC zombie head. They are not nude bases.

- **Collection:** Universal LPC Spritesheet Character Generator, `spritesheets/` on the `master` branch  
  https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator
- **Credits table used:** `CREDITS.csv` in that repository  
  https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator/blob/master/CREDITS.csv
- **License used for the PNGs in this game:** Creative Commons Attribution-ShareAlike 3.0 Unported (CC-BY-SA 3.0)  
  https://creativecommons.org/licenses/by-sa/3.0/legalcode
- **Attribution copy:** [`assets/people/LICENSE.txt`](assets/people/LICENSE.txt) and [`assets/enemies/LICENSE.txt`](assets/enemies/LICENSE.txt)

Where a source file lists more than one license, this game uses **CC-BY-SA 3.0**. The short-sleeve t-shirt is only **OGA-BY 3.0**. That license's section 8(g) says the work may be distributed under CC-BY 3.0:

> You may distribute this work under the terms of the Creative Commons Attribution 3.0 license (CC-BY 3.0), which can be found here: https://creativecommons.org/licenses/by/3.0/legalcode

The t-shirt is stacked with CC-BY-SA body, pants, hair, and shoes, so the combined villager PNGs are shared under CC-BY-SA 3.0. Game code stays under the MIT license. CC-BY-SA applies to these character images, not to the code.

Frames are the front row of each `walk.png` (64×64 cells, 9 columns). Villagers use column 1. `zombie_stand.png` uses column 1 and `zombie_hold.png` uses column 4. Each frame is cropped above the top opaque pixel, the feet stay on the bottom edge, and the result is scaled 2× with nearest-neighbor filtering.

| In this game | LPC layers, in draw order |
| --- | --- |
| `assets/people/man_brown.png` | `body/bodies/male/walk.png`, `legs/pants/male/walk.png`, `torso/clothes/shortsleeve/tshirt/male/walk.png`, `feet/shoes/basic/male/walk.png`, `head/heads/human/male/walk.png`, `eyes/human/adult/neutral/walk.png`, `hair/bedhead/adult/walk.png` |
| `assets/people/man_blue.png` | Same stack as `man_brown.png`. The shirt layer's hue is shifted to blue. That recolor is a change made for this game. |
| `assets/people/man_old.png` | Same body, pants, shoes, head, and eyes. Shirt hue is shifted toward olive. Hair is `hair/messy1/adult/walk.png` with the color pulled to gray. Both edits were made for this game. |
| `assets/people/woman.png` | `body/bodies/female/walk.png`, `legs/pants/thin/walk.png`, `torso/clothes/shortsleeve/tshirt/female/walk.png`, `feet/shoes/basic/thin/walk.png`, `head/heads/human/female/walk.png`, `eyes/human/adult/neutral/walk.png`, `hair/long/adult/walk.png` |
| `assets/enemies/zombie_stand.png` | `body/bodies/zombie/walk/zombie.png`, `head/heads/zombie/adult/walk.png` |
| `assets/enemies/zombie_hold.png` | Same two zombie layers, one walk step later |

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
- Nude Cabbit / AntumDeluge body templates were not shipped. Villagers use the clothed LPC stacks above.
- Kenney isometric character renders (Mini Characters, Graveyard Kit, Animated Characters 3) were not shipped. Their scale and style do not match this LPC set.

## Font

- **Font:** Droid Sans Fallback
- **Copyright:** 2006, 2007, 2008, 2009, 2010 Google Corp. Droid is a trademark of Google Corp.
- **License:** Apache License 2.0  
  http://www.apache.org/licenses/LICENSE-2.0
- **Source used:** Debian package `fonts-droid-fallback`, file `DroidSansFallbackFull.ttf`  
  Upstream noted in that package: https://android.googlesource.com/platform/frameworks/base/
- **Bundled file:** `assets/fonts/DroidSansFallback-subset.ttf`  
  A subset of the original font, containing the Latin and Chinese glyphs used by the in-game UI.
- The full Apache License 2.0 text is in [`assets/fonts/APACHE-2.0.txt`](assets/fonts/APACHE-2.0.txt).

## Code and effects drawn in the game

- Game code in this repository is under the MIT License. See [`LICENSE`](LICENSE).
- Spears, fireballs, flames, range rings, shadows, and hit flashes are drawn with Godot canvas calls. They are not taken from an asset pack.
