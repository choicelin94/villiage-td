# 部落村落塔防 / Tribal Village TD

正面俯视的部落村落塔防。地图大约是原先的四倍大。僵尸从北边入口进来，追赶还在外面的村民，也会啃房屋和塔。房屋、农场、工坊和塔自己就会工作，不用先派人。把村民派进建筑只是把人收起来。守住 **10** 波即胜利。只有村民全部被感染才会失败。

A top-down tower defense game on a map about four times the previous area. Zombies enter from the north, chase villagers who are still outside, and chew houses and towers. Houses, farms, the workshop, and towers work on their own. Assigning a villager only shelters that person inside. Hold for **10** waves to win. The only loss is every villager becoming infected.

**引擎 / Engine:** Godot 4.7 (GDScript)  
**玩法切片 / Slice:** 20×20 正方形俯视地图，村落建筑 + 有上限的木墙 + 两种炮塔，村民可躲进建筑，难民，10 波。  
**美术 / Art:** 建筑用 Kenney Fantasy Town Kit 2.0（CC0）。村民是 LAYERLAB 的 Cute Adventurers 七个皮肤（Spine 4.3 导出的序列帧：待机、跑、倒下、死亡）。怪物是两套手绘哥布林：持矛的是普通尸潮和被感染的村民，持枪的是蛮力和首领。朝向跟屏幕上的速度走，侧面的序列不会倒着播。这两套图都不是 CC0 / CC-BY。Spine 运行时没有打进网页包。详见 [CREDITS.md](CREDITS.md)。 Buildings are Kenney Fantasy Town Kit 2.0 (CC0). Villagers are the seven LAYERLAB Cute Adventurers skins, played from the Spine 4.3 frame export (idle, run, down, death). Monsters are two hand-drawn goblins: the spear goblin is the horde and an infected villager, and the gun goblin is a brute or the boss. Facing follows screen-space velocity, and the side-view cycles are not played backwards. Neither character pack is CC0 or CC-BY. The Spine runtime is not in the web build. See [CREDITS.md](CREDITS.md).

## 在线试玩 / Play in the browser

单线程网页导出在 [`docs/`](docs/)（关闭了线程，GitHub Pages 不需要 COOP/COEP）。界面默认是简体中文，右上角的「中文」按钮可以改成英文，游戏里同一处不会同时显示两种语言。文字用 Noto Sans SC（OFL）。第一次打开大约要下 47 MB（引擎加字体），请等加载条走完。手机用双指缩放、单指拖动。电脑在开始和离开图标旁边有 `+` / `-`。第一次打开时，镜头对准地图正中的一半（把 20×20 看成 4×4 块，对准中间 2×2 块），手机比电脑更近一些。

The single-threaded web export is in [`docs/`](docs/) (threads off, so GitHub Pages does not need COOP/COEP headers). The game starts in Simplified Chinese. The button at the top right switches the whole interface to English, and each label shows one language at a time. Text uses Noto Sans SC (OFL). The first visit downloads about 47 MB (engine plus font). Wait for the loading bar. Phones pinch to zoom and drag to pan. A computer also has `+` and `-` next to the start and leave icons. The first view centers the middle half of the map (the center 2×2 of a 4×4 split of the 20×20 grid). A phone starts closer than a computer.

网页导出没有打开 GDExtension（`extensions_support` 仍是关的）。官方 spine-godot 4.3 / Godot 4.7.2 的包里有 wasm，但 Spine Runtimes License（2025-04-05）要求集成方持有 Spine Editor 许可证，或者每个玩家自己持有。这个项目没有那份许可证，所以运行时不进仓库，也不进 Pages。页面上的人是同一套 Spine 动画导出的序列帧，脚仍落在原来的椭圆上。本机如果把官方 `bin/` 放进工程，村民会改走 SpineSprite。

The web export leaves GDExtension off (`extensions_support` stays false). The official spine-godot 4.3 build for Godot 4.7.2 includes wasm, but the Spine Runtimes License (2025-04-05) allows shipping that runtime only when the integrator has a Spine Editor license, or every player has one. This project has neither, so the runtime is not in the repo and not on Pages. Characters on the page are the frame sequences exported from those Spine animations, and their feet still sit on the same ellipse. If the official `bin/` folder is added locally, villagers switch to SpineSprite.

发布地址 / public URL, after Pages is turned on:

**https://choicelin94.github.io/villiage-td/**

线上页面是 `main` 里的 `docs/`，由 GitHub Actions 发布。地图是正面俯视的正方形格子。房屋和木墙是同一套 CC0 模型从南边俯视渲染的，树和岩石仍用原来的图。前后仍由体积决定：人的落点是一块椭圆，树干、岩石和房子各用自己的凸多边形或椭圆。整块椭圆到了占地北侧，人才被挡住。空心的农场和木墙用一块盖住内部的凸多边形，椭圆不能走进去，人与人之间也保持椭圆不相交。选中线跟着物件的深度。

排序仍是两段。每件东西先按椭圆或多边形算出紧的包围盒。屏幕上的盒子先扫一遍，对不上的对子直接丢掉。盒子在东西、南北或高度上已经分开的，用包围盒就能定前后。只有盒子真的叠在一起，才问整块是不是在北侧。房屋、木墙、树和岩石的结果会留着，人挪动了才重算涉及到的对子。景深试验页：

**https://choicelin94.github.io/villiage-td/depth-lab/**

压力页会放出很多走动的人，并在同一页里量旧排序和两段排序的耗时（`?stress=100`、`300`、`500`）：

**https://choicelin94.github.io/villiage-td/stress/**

图鉴列出当前的友方单位、敌人和建筑，也带上挡路的树和岩石。头像从现有序列帧和建筑图裁出，数值来自 `data/units.json`、`data/enemies.json`、`data/buildings.json`，和对局里的 Balance 是同一份。矛兵和工匠已经写进 Balance，对局还不会生成。资源约定见 [docs/ASSET_STANDARD.md](docs/ASSET_STANDARD.md)。改完目录后运行 `python3 tools/build_codex.py`，再提交 `docs/codex/`。

**https://choicelin94.github.io/villiage-td/codex/**

游戏里右上角的「景深」打开试验页。推到 `main` 时，Actions 先跑图鉴生成器，再把 `docs/` 发布到 Pages。仓库需要把 Pages 的 Source 设成 **GitHub Actions**，见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。网页包里的 wasm 仍是本地用 Godot 导出后提交的。

The live site is the `docs/` directory on `main`, published by GitHub Actions. The map is a square top-down grid. Houses and walls are CC0 models rendered from the south. Trees and rocks keep their previous pictures. Depth still comes from volumes: a person stands on an oval, and each tree, rock, and building has its own convex polygon or ellipse. The whole oval has to sit north of a footprint before that object covers the person. The open farm and wall use one convex polygon over the interior. An oval cannot enter a footprint, and walkers keep their ovals apart. Selection lines use that depth.

The sort stays two-phase. Each footprint first becomes a tight box around its ellipse or polygon. A sweep drops pairs whose screen boxes miss. Pairs whose boxes already separate in x, y, or height take their order from the box. Only a real overlap asks whether one footprint is entirely to the north. Houses, walls, trees, and rocks keep that result; a pair is redone when someone in it moves. The depth lab is at:

**https://choicelin94.github.io/villiage-td/depth-lab/**

The stress page spawns many moving people and times the old sort against the two-phase sort in one session (`?stress=100`, `300`, or `500`):

**https://choicelin94.github.io/villiage-td/stress/**

The codex lists the current ally units, enemies, and buildings, plus the trees and rocks that block building. Portraits are cropped from the existing sheets and building pictures. Stats come from `data/units.json`, `data/enemies.json`, and `data/buildings.json`, the same files Balance loads in a match. Spearman and engineer are in that catalog and are not spawned yet. The resource rules are in [docs/ASSET_STANDARD.md](docs/ASSET_STANDARD.md). After a catalog edit, run `python3 tools/build_codex.py` and commit `docs/codex/`.

**https://choicelin94.github.io/villiage-td/codex/**

The in-game **Depth** button opens the lab. A push to `main` runs the codex generator, then publishes `docs/` to Pages. The repository has to set the Pages source to **GitHub Actions**. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). The game wasm is still exported locally with Godot and committed.

## 架构与维护 / Architecture and upkeep

配置在 `data/`，图在 `assets/`，玩法在 `scripts/`。对局通过 `scripts/balance.gd` 读取单位、敌人和建筑 JSON。怎么改、改完要跑什么、还有哪些数仍写在脚本里（占地后备表、清波底薪），见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。每条资源的字段和 id 见 [docs/ASSET_STANDARD.md](docs/ASSET_STANDARD.md)。

Balance and catalogs live in `data/`. Art lives in `assets/`. Behavior lives in `scripts/`. A match loads the unit, enemy, and building JSON through `scripts/balance.gd`. What to edit, which leftovers are still script constants (the footprint fallback and the flat wave payout), and how publishing works are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Field rules are in [docs/ASSET_STANDARD.md](docs/ASSET_STANDARD.md).

本地先看网页包 / preview the export locally:

```bash
python3 -m http.server -d docs 8765
# open http://127.0.0.1:8765/
```

## 怎么玩 / How to play

### 目标 / Goal

- 失败只有一种：场上村民全部被感染，变成僵尸。
- 难民自己离开不算失败。
- 圣树不再是失败条件。塔会优先打已经深入村落的僵尸。
- 守完 **10** 波且场上没有剩余僵尸：胜利。

You lose only when every villager is infected and turns into a zombie. Refugees who leave are not a loss. There is no sacred-tree defeat. Towers prefer zombies that have pushed farthest into the village. Clear all **10** waves with no zombies left to win.

### 操作 / Controls

把人收进建筑是可选的：先点村民，再点房屋、农场、工坊或塔。先点建筑会打开右侧说明，可以出售，但不会把人收进去。建筑不等人也会工作。

建造从空地开始：点一块能造的草地，右侧列出木墙、矛塔、火塔、房屋、农场、工坊。点其中一项就盖在那一格上。侧栏打开时，按 `1` 到 `6` 也会盖对应的建筑。

地图可以单指拖动，双指或滚轮缩放。电脑还可以点左下角的 `+` 和 `-`，这两个按钮在开始和离开图标的右边，手机上不显示。第一次打开时镜头对准地图正中那一半，手机默认比电脑更近。之后如果自己拖过或缩放过，改变窗口大小不会把镜头拉回去。再缩小可以看到整张地图。顶栏是图标加数字：木材、金币、村民、床位、木墙、波次。有难民在等待时才多出一个计时图标。左下角两个图标是开始波次（三角）和离开并重开（出门箭头），没有文字按钮，点一下就生效，不用确认。

Sheltering someone is optional. Tap a villager, then tap a house, farm, workshop, or tower. Tapping a building first opens the side panel, where you can sell it. That tap does not shelter anyone. The building works with nobody inside.

Building starts from the ground: tap an empty tile and the right-hand panel lists the wall, spear tower, fire tower, house, farm, and workshop. Tap one to place it on that tile. With the panel open, keys `1` through `6` place the same way.

Drag with one finger to pan. Pinch or use the mouse wheel to zoom. On a computer, `+` and `-` sit to the right of the start and leave icons; those buttons stay hidden on a phone. The first view frames the center half of the map, closer on a phone than on a computer. After you pan or zoom, resizing the window does not snap the camera back. Zoom out to see the whole map. The top bar is an icon plus a number for wood, gold, people, beds, walls, and the wave. A timer icon appears only while refugees are waiting. Two icons at the lower left start the wave (triangle) and leave for a fresh game (door arrow). They are not text buttons. One tap, no confirmation.

| 操作 Action | 作用 Effect |
| --- | --- |
| 点村民 | 选中。再点一座功能建筑把这个人收进去 |
| 点已选中的人要去的建筑 | 把人收进去。一座建筑同时只留一个人 |
| 点空地 | 右侧打开建造列表 |
| 点右侧的一项，或侧栏打开时按 `1` 到 `6` | 把该建筑盖在选中的格子上 |
| 点已有建筑（没有选中村民时） | 右侧显示躲在里面的头像和称呼，以及出售。地图上不再把人叠在建筑上 |
| 右键建筑，或侧栏里的出售 | 出售，返还一半资源。取消派工，不感染 |
| 单指拖动，或鼠标拖动 | 平移地图 |
| 双指张开捏合，或滚轮 | 缩放地图 |
| 电脑左下角 `+` / `-` | 以画面中心放大或缩小。手机上没有这两个按钮 |
| 右上角「中文」或 `EN` | 只切换界面语言。选择会记住 |
| 左下三角图标，或 `Space` / `Enter` | 开始下一波 |
| 左下出门图标，或 `R`，或结束画面的图标 | 离开这一局并重开 |
| `Esc` | 关掉侧栏并取消选中的村民 |

Tap a villager, then tap a functional building to shelter them. One building keeps one villager. After that, the villager leaves the map and shows up as a portrait and name in that building's panel. Tap the portrait to select them again. Tap empty ground to open the build list. Tap an existing building, with nobody selected, to inspect or sell it. Drag to pan and pinch to zoom. On a computer, `+` and `-` zoom toward the middle of the screen. The triangle starts the next wave. The door icon leaves and restarts. `Esc` closes the panel. The top-right button shows the current language, 中文 or EN, and switches the whole interface. The choice is saved.

### 村民 / Villagers

开局有一批房屋、农场、工坊、塔和木墙，以及 **5** 名村民（男女都有）。开局 **100 木材 / 70 金币**。

村民移动速度是普通僵尸的 1.5 倍（世界单位约 137 对 91，也就是原来的 108 对 72）。波次开始前，他们在村子里闲逛。波次开始后，没有床位、也没有躲进建筑的人会惊慌跑动，并往房屋（否则往村子中心）靠。闲逛、惊慌和撤离都会沿着格子绕开房屋、木墙、树木和岩石，不会穿进去。人的脚底和景物的前沿决定谁画在前面，经过建筑、树木和岩石时会走到后面或前面。

碰到僵尸会感染，立刻变成一只新僵尸，并短暂高亮。有人躲着的建筑如果被拆掉（不是出售），里面的人也会立刻感染。

The village starts with houses, a farm, a workshop, towers, walls, and **5** villagers, men and women. You start with **100 wood and 70 gold**.

Villagers move at 1.5× a normal zombie's speed (about 137 vs 91 world units, the old 108 vs 72). Before the first wave they wander. After the start, anyone without a bed and without a shelter panics and drifts toward a house, or toward the village center. Wandering, panic, and leaving follow the grid around houses, walls, trees, and rocks. Feet and the front edge of each sprite decide draw order, so a walker passes behind or in front of a building, tree, or rock.

Contact with a zombie infects them. They become a zombie on the spot, with a short highlight. If a building someone is sheltering in is destroyed, and it was not sold, that villager is infected immediately.

### 建筑 / Buildings

功能建筑（房屋、农场、工坊、矛塔、火塔）立着就会工作，不用先派人。木墙仍然挡路。木墙费用 18 木材，全图最多 **28** 座（含开局已有的墙），避免只用墙把路封死。

每座房屋提供 4 个床位。躲在这屋里的人占 1 个床位，剩下的床位分给还没躲起来的村民，难民优先。躲在农场、工坊或塔里的人不占床，也不会惊慌。盖房屋不会立刻生出新人。

人口只在每波结束后来的难民里增加，每波固定 2 人。他们有 **6.5** 秒。这段时间里把他们收进建筑，或让房屋的床位够用，他们就会留下。超时就向北离开，离开不是失败。

清完一波：木材 `8 + 农场 × 6`，金币 `+14`。击杀僵尸也会给资源。

Functional buildings (house, farm, workshop, spear tower, fire tower) work while they are standing. Nobody has to be stationed first. Walls still block movement. A wall costs 18 wood, and the map allows at most **28** walls, counting the ones already built, so a pure maze has a limit.

Every house provides 4 beds. A villager sheltering in that house uses 1 bed. The remaining beds go to villagers who are still outside, refugees first. Someone sheltering in a farm, workshop, or tower does not use a bed and does not panic. Building a house does not spawn people.

Population grows only from refugees at the end of a wave, 2 people each time. They wait **6.5** seconds. Shelter them, or leave a free bed in a house, and they stay. Otherwise they walk off the north edge. Leaving is not a loss.

A cleared wave pays `8 + 6 per farm` wood and `14` gold. Kills also pay wood and gold.

| 建筑 | 费用 | 立着的时候 |
| --- | --- | --- |
| 木墙 Wall | 18 木材 | 挡路，生命 170，防御 8。达到 28 座就不能再造。不能收人。 |
| 矛塔 Spear | 24 木材 + 40 金币 | 自动单体穿刺，优先打深入村落的僵尸。生命 200，防御 6。 |
| 火塔 Fire | 16 木材 + 64 金币 | 自动火球溅射。生命 160，防御 4。 |
| 房屋 House | 22 木材 | 4 个床位。不生人。生命 120，防御 3。 |
| 农场 Farm | 16 木材 + 12 金币 | 每波结束额外 +6 木材。生命 80，防御 2。 |
| 工坊 Workshop | 20 木材 + 28 金币 | 矛塔和火塔攻击 +25%（不叠加）。生命 100，防御 3。 |

有人躲在功能建筑里时，头顶有一个绿点。没有人时不画点，建筑照样工作。

入口、树木和岩石不能建造。木墙会迫使僵尸绕路或啃墙；把他们留在塔的射程里。僵尸够到没进建筑的村民就会感染。建筑会从旁边被啃，倒下后里面的人感染。伤害是 `max(1, round(attack * 100 / (100 + defense)))`。防御为 0 时，打出去的伤害就等于攻击。现在这些防御值还小，1 到 3 点的撕咬四舍五入之后仍是原来的数字。

Entrance tiles, trees, and rocks are not buildable. Walls bend the route or get chewed, which holds zombies in tower range. Zombies infect villagers who are still outside. They bite a building from the next tile, and anyone sheltering inside is infected when that building falls. Damage is `max(1, round(attack * 100 / (100 + defense)))`. Defense 0 leaves the attack unchanged after rounding. The defense values shipped here are still small enough that bites of 1, 2, and 3 round back to the same numbers.

A green dot above a functional building means a villager is sheltering there. An empty building draws no dot and still works.

### 波次 / Waves

共 10 波。后面的僵尸更多、更耐打，并混有更快的僵尸、更慢的壮汉，第 10 波有一头目。

There are 10 waves. Later waves add more health, faster zombies, slow brutes, and a boss on wave 10.

塔会自己开火。村民如果一直停在外面，还是会被感染，全员感染才会失败。用木墙把路折进射程，房屋提供的床位能让没躲起来的人少惊慌。

Towers fire on their own. Villagers left outside can still be infected, and the loss is still every villager turning. Fold the road through tower range with walls. Beds from houses keep unsheltered people from panicking.

## 数值 / Balance data

攻击、防御、生命、攻速、移速和射程写在 `data/units.json`、`data/enemies.json`、`data/buildings.json`。`data/characters.json` 只留皮肤和序列帧。距离和速度已经是世界单位（乘过 `IsoVolume.WORLD_SCALE`），改完保存，重新开始一局就会生效。伤害公式在 `scripts/balance.gd` 开头。

Attack, defense, hp, attack speed, move speed, and range live in `data/units.json`, `data/enemies.json`, and `data/buildings.json`. `data/characters.json` is only skins and frame clips. Distances and speeds are already world units (multiplied by `IsoVolume.WORLD_SCALE`). Save the file and start a new game to see the change. The damage formula is at the top of `scripts/balance.gd`.

## 本地运行 / Run locally

需要 [Godot 4.7.x](https://godotengine.org/download)（本项目用 4.7.2 制作）。

1. 用 Godot 打开本目录的 `project.godot`。
2. 按 `F5` 运行主场景 `scenes/main.tscn`。

渲染器是 **GL Compatibility**，方便网页导出。地图是 Godot 的正方形 `TileMapLayer`（正面俯视，不是 45° 菱形）。房屋、木墙、树、岩石和走动的人仍走同一段排序。每人的占地写在 `data/iso_volumes.json`：`ellipse` 用 `rx`/`ry`（可加 `ox`/`oy`），`poly` 必须是凸多边形，顶点相对格子中心，`z` 是高度。空心的农场和木墙写成盖住内部的实心凸多边形。人必须是椭圆，不能收成一个点。只有整块都在北侧（或整段更矮）才算在后面。并排没有几何先后，就绪队列再用南缘键和输入顺序排队，这条不写进依赖图。屏幕上的包围盒先筛掉碰不到的对子，盒子在东西、南北或高度上分开就直接定前后，真正重叠才做同一次比较。没挪动的景物会留下比较结果。树只算树干接触地面的那一小块椭圆。椭圆不能进入任何占地，走动的人之间也保持椭圆不相交。网页地址加上 `?stress=300` 可以给排序计时。调试彩线和建造高亮挂在被描述的物件上。躲在建筑里的人只出现在建筑详情里。

Open `project.godot` in Godot 4.7.x and press `F5`. The project uses the GL Compatibility renderer. The ground is a square `TileMapLayer` (top-down, not a 45° diamond). Houses, walls, trees, rocks, and walkers still share one sort. Each footprint is authored in `data/iso_volumes.json`: `ellipse` uses `rx`/`ry` (optional `ox`/`oy`), `poly` must be a convex polygon around the cell center, and `z` is the height. The open farm and wall are one solid convex cover over the interior. Walkers are an ellipse with area, not a point. A footprint is behind another only when it sits entirely to the north, or entirely below in height. Side-by-side pairs have no geometric edge; the ready queue orders them by the south-rim key and then input order, and that order is not a graph edge. A sweep on screen boxes rejects pairs that cannot overlap. Boxes that already separate in x, y, or height take that order, and a real overlap runs the same compare. Unmoved props keep their pair result. A tree uses the small ellipse where the trunk meets the ground. An oval cannot enter a footprint, and walkers keep their ovals apart. Debug lines and the build-tile highlight are drawn with the object they describe. Someone sheltering in a building still appears only in that building's panel. Add `?stress=300` to the web build to time the sort.

### 导出网页 / Export web

已包含导出预设 **Web**（关闭线程，避免 GitHub Pages 缺少 COOP/COEP 头）。安装与编辑器版本一致的 Export Templates 后：

The **Web** preset is included, with thread support off so GitHub Pages can host it without cross-origin isolation headers. Install matching export templates, then:

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

静态文件在 `docs/`。用任意静态服务器打开 `docs/index.html`（不要直接用 `file://`）。

The static files live in `docs/`. Serve that folder over HTTP. Do not open `index.html` via `file://`.

## 许可 / License

游戏代码为 MIT，见 [LICENSE](LICENSE)。美术和字体各自的许可证见 [CREDITS.md](CREDITS.md)。界面字体是 Noto Sans SC，许可证是 SIL OFL 1.1。

Game code is MIT. Art and the font keep their own licenses, documented in [CREDITS.md](CREDITS.md). The UI font is Noto Sans SC under the SIL Open Font License 1.1.
