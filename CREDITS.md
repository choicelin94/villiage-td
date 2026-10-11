# Credits

This game uses third-party art and a third-party font. Licenses below are copied from the files or pages those assets were downloaded from. Nothing here is a guessed license.

## Terrain, towers, trees, and rocks

- **Pack:** Tower Defense assets (isometric)
- **Author:** Kenney Vleugels, for Kenney (www.kenney.nl)
- **Download page:** https://opengameart.org/content/tower-defense-assets-isometric
- **File downloaded:** `Tower Defense assets.zip` (1.5 MB) from that page
- **License:** Creative Commons Zero (CC0) 1.0 Universal  
  http://creativecommons.org/publicdomain/zero/1.0/
- **License file shipped with the pack:** copied unchanged to [`assets/kenney/LICENSE.txt`](assets/kenney/LICENSE.txt)

The pack's own license text says:

> Tower Defense assets (isometric)  
> by Kenney Vleugels for Kenney (www.kenney.nl)  
> License (Creative Commons Zero, CC0)  
> You may use these graphics in personal and commercial projects.  
> Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

Sprites used, by their original filenames:

| In this game | Original file in the zip |
| --- | --- |
| `assets/kenney/landscape/grass_a.png` | `PNG/Landscape/landscape_13.png` |
| `assets/kenney/landscape/grass_b.png` | `PNG/Landscape/landscape_19.png` |
| `assets/kenney/landscape/grass_c.png` | `PNG/Landscape/landscape_24.png` |
| `assets/kenney/landscape/grass_d.png` | `PNG/Landscape/landscape_26.png` |
| `assets/kenney/landscape/dirt.png` | `PNG/Landscape/landscape_29.png` |
| `assets/kenney/buildings/wall.png` | `PNG/Towers (brown)/tower_45.png` |
| `assets/kenney/buildings/spear.png` | `PNG/Towers (brown)/tower_42.png` |
| `assets/kenney/buildings/fire.png` | `PNG/Towers (brown)/tower_35.png` |
| `assets/kenney/buildings/hut.png` | `PNG/Towers (brown)/tower_44.png` |
| `assets/kenney/details/tree_a.png` | `PNG/Details/trees_1.png` |
| `assets/kenney/details/tree_b.png` | `PNG/Details/trees_8.png` |
| `assets/kenney/details/tree_core.png` | `PNG/Details/trees_5.png` |
| `assets/kenney/details/rock.png` | `PNG/Details/rocks_1.png` |

These PNGs were copied as-is (not recolored). `icon.png` is a small composite of `landscape_13` and `tower_42` from the same pack.

### Kenney Tower Defense Kit (3D) was not shipped

The current pack at https://kenney.nl/assets/tower-defense-kit (Tower Defense Kit 2.1, file `kenney_tower-defense-kit.zip`) was downloaded and checked. Its `License.txt` says:

> License: (Creative Commons Zero, CC0)  
> http://creativecommons.org/publicdomain/zero/1.0/

That kit is a **3D** model pack (FBX, GLB, and OBJ). This playable build uses Kenney's **2D isometric** tower-defense sprites above so the game can stay a lightweight HTML5 export. The 3D models are not included in this repository.

## Zombies

- **Pack:** Animated Top Down Zombie
- **Author:** Riley Gombart (OpenGameArt user `rileygombart`)
- **Page attribution notice:** "Riley Gombart or ChessMasterRiley"
- **Download page:** https://opengameart.org/content/animated-top-down-zombie
- **File downloaded:** `tds_zombie.zip`
- **License stated on that page:** CC0 1.0  
  The page shows a CC0 license icon linking to http://creativecommons.org/publicdomain/zero/1.0/
- The zip does not contain its own license file. The license above is the one selected on the OpenGameArt page.
- CC0 does not require credit. The author wrote: "if you feel like crediting, I won't say no."

Frames in the zip are named `skeleton-move_*.png` and `skeleton-attack_*.png` (Spine export names). The published asset is the top-down zombie. This game keeps the move and attack cycles and scales every frame by the same factor (`311px` move-canvas height → `96px`) so the web download stays small. Idle frames are not used.

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
