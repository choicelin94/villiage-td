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

Villagers and zombies are stills from the same pack, so an infected villager reads as the same style of character.

- **Pack:** Topdown Shooter
- **Author:** Kenney Vleugels (Kenney.nl)
- **Download page:** https://kenney.nl/assets/topdown-shooter
- **OpenGameArt page:** https://opengameart.org/content/topdown-shooter
- **File downloaded:** `topdown-shooter.zip`  
  https://opengameart.org/sites/default/files/topdown-shooter.zip
- **License:** Creative Commons Zero (CC0) 1.0 Universal  
  http://creativecommons.org/publicdomain/zero/1.0/
- **License file shipped with the pack:** copied unchanged to [`assets/people/LICENSE.txt`](assets/people/LICENSE.txt) and [`assets/enemies/LICENSE.txt`](assets/enemies/LICENSE.txt)

The pack's own `License.txt` says:

> Topdown (Shooter) Pack  
> by Kenney Vleugels (Kenney.nl)  
> License (Creative Commons Zero, CC0)  
> http://creativecommons.org/publicdomain/zero/1.0/  
> You may use these assets in personal and commercial projects.  
> Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

Each sprite below is the pack PNG scaled 2× with nearest-neighbor filtering.

| In this game | Original file in the zip |
| --- | --- |
| `assets/people/man_brown.png` | `PNG/Man Brown/manBrown_stand.png` |
| `assets/people/man_old.png` | `PNG/Man Old/manOld_stand.png` |
| `assets/people/man_blue.png` | `PNG/Man Blue/manBlue_stand.png` |
| `assets/people/woman.png` | `PNG/Woman Green/womanGreen_stand.png` |
| `assets/enemies/zombie_stand.png` | `PNG/Zombie 1/zoimbie1_stand.png` |
| `assets/enemies/zombie_hold.png` | `PNG/Zombie 1/zoimbie1_hold.png` |

The zombie filenames use the pack's spelling `zoimbie`. Only these two zombie frames are shipped. Gun, reload, and machine poses are not used. The two frames alternate for walking and biting.

### Removed and not shipped

- Riley Gombart's "Animated Top Down Zombie" (OpenGameArt, CC0 on that page) was the previous zombie. Those `move_*.png` and `attack_*.png` frames have been removed from this repository.
- Engvee, "FREE Animated Isometric Zombies" on itch.io, was not used. That page allows commercial use in the author's own words, but it does not state CC0 or CC-BY.
- Other CC0 character packs were looked at and not shipped, including a side-view civilian set and separate top-down zombie sheets, so the village uses one Kenney set for people and zombies.

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
