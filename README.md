# 部落村落塔防 / Tribal Village TD

等距俯视角的部落村落塔防。地图大约是原先的四倍大。僵尸从北边入口进来，追赶没躲进建筑的村民，也会啃有人值守的房屋和塔。先点村民，再点建筑，才能让房屋、农场、工坊和塔生效。守住 **10** 波即胜利。只有村民全部被感染才会失败。

An isometric tower defense game on a map about four times the previous area. Zombies enter from the north, chase villagers who are still outside, and chew staffed houses and towers. Click a villager first, then a building, to make houses, farms, the workshop, and towers do anything. Hold for **10** waves to win. The only loss is every villager becoming infected.

**引擎 / Engine:** Godot 4.7 (GDScript)  
**玩法切片 / Slice:** 20×20 等距地图，村落建筑 + 有上限的木墙 + 两种炮塔，村民派工，难民，10 波。  
**美术 / Art:** 建筑用 Kenney Fantasy Town Kit 2.0（CC0）。村民是穿好衣服的 LPC 男女（身体 + 衣服 + 头发），僵尸是同一套 LPC 体型。行走时按屏幕上的速度选择朝向，脸会跟着移动方向转，不会一直背对镜头。许可证是 CC-BY-SA 3.0（T 恤图层是 OGA-BY 3.0）。详见 [CREDITS.md](CREDITS.md)。 Buildings are Kenney Fantasy Town Kit 2.0 (CC0). Villagers are clothed LPC men and women (body, clothes, and hair). Zombies are the matching LPC body and head. Walk frames follow screen-space velocity, so a character faces the way they move. The character images are CC-BY-SA 3.0. The t-shirt layer is OGA-BY 3.0. See [CREDITS.md](CREDITS.md).

## 在线试玩 / Play in the browser

单线程网页导出在 [`docs/`](docs/)（关闭了线程，GitHub Pages 不需要 COOP/COEP）。界面默认是简体中文，右上角的「中文」按钮可以改成英文，游戏里同一处不会同时显示两种语言。文字用 Noto Sans SC（OFL）。第一次打开大约要下 47 MB（引擎加字体），请等加载条走完。手机用双指缩放、单指拖动。电脑在开始和离开图标旁边有 `+` / `-`。第一次打开时，镜头对准地图正中的一半（把 20×20 看成 4×4 块，对准中间 2×2 块），手机比电脑更近一些。

The single-threaded web export is in [`docs/`](docs/) (threads off, so GitHub Pages does not need COOP/COEP headers). The game starts in Simplified Chinese. The button at the top right switches the whole interface to English, and each label shows one language at a time. Text uses Noto Sans SC (OFL). The first visit downloads about 47 MB (engine plus font). Wait for the loading bar. Phones pinch to zoom and drag to pan. A computer also has `+` and `-` next to the start and leave icons. The first view centers the middle half of the map (the center 2×2 of a 4×4 split of the 20×20 grid). A phone starts closer than a computer.

发布地址 / public URL, after Pages is turned on:

**https://choicelin94.github.io/villiage-td/**

线上页面来自 `main` 的 `/docs`。这一支合并之后，驻岗会显示在建筑详情里，人物也会按前后遮挡并绕开障碍。若要先预览，在 **Settings → Pages → Deploy from a branch** 里把 Branch 改成 `cursor/staff-depth-4d8f`，Folder 仍是 **`/docs`**，看完再改回 `main`。

The live site serves `/docs` from `main`. After this branch merges, stationed villagers show in the building panel, and people pass behind or in front of scenery instead of walking through it. To preview first, set **Settings → Pages → Deploy from a branch** to `cursor/staff-depth-4d8f` and folder **`/docs`**, then switch the branch back to `main`.

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

派人只有一条主路径：先点村民，再点房屋、农场、工坊或塔。先点建筑会打开右侧说明，可以出售，但不会派人。

建造从空地开始：点一块能造的草地，右侧列出木墙、矛塔、火塔、房屋、农场、工坊。点其中一项就盖在那一格上。侧栏打开时，按 `1` 到 `6` 也会盖对应的建筑。

地图可以单指拖动，双指或滚轮缩放。电脑还可以点左下角的 `+` 和 `-`，这两个按钮在开始和离开图标的右边，手机上不显示。第一次打开时镜头对准地图正中那一半，手机默认比电脑更近。之后如果自己拖过或缩放过，改变窗口大小不会把镜头拉回去。再缩小可以看到整张地图。顶栏是图标加数字：木材、金币、村民、床位、木墙、波次。有难民在等待时才多出一个计时图标。左下角两个图标是开始波次（三角）和离开并重开（出门箭头），没有文字按钮，点一下就生效，不用确认。

Staffing has one primary path: tap a villager, then tap a house, farm, workshop, or tower. Tapping a building first opens the side panel, where you can sell it. That tap does not assign anyone.

Building starts from the ground: tap an empty tile and the right-hand panel lists the wall, spear tower, fire tower, house, farm, and workshop. Tap one to place it on that tile. With the panel open, keys `1` through `6` place the same way.

Drag with one finger to pan. Pinch or use the mouse wheel to zoom. On a computer, `+` and `-` sit to the right of the start and leave icons; those buttons stay hidden on a phone. The first view frames the center half of the map, closer on a phone than on a computer. After you pan or zoom, resizing the window does not snap the camera back. Zoom out to see the whole map. The top bar is an icon plus a number for wood, gold, people, beds, walls, and the wave. A timer icon appears only while refugees are waiting. Two icons at the lower left start the wave (triangle) and leave for a fresh game (door arrow). They are not text buttons. One tap, no confirmation.

| 操作 Action | 作用 Effect |
| --- | --- |
| 点村民 | 选中。再点一座功能建筑把这个人派过去 |
| 点已选中的人要去的建筑 | 派人。一座建筑同时只留一个人 |
| 点空地 | 右侧打开建造列表 |
| 点右侧的一项，或侧栏打开时按 `1` 到 `6` | 把该建筑盖在选中的格子上 |
| 点已有建筑（没有选中村民时） | 右侧显示驻岗的头像和称呼，以及出售。地图上不再把人叠在建筑上 |
| 右键建筑，或侧栏里的出售 | 出售，返还一半资源。取消派工，不感染 |
| 单指拖动，或鼠标拖动 | 平移地图 |
| 双指张开捏合，或滚轮 | 缩放地图 |
| 电脑左下角 `+` / `-` | 以画面中心放大或缩小。手机上没有这两个按钮 |
| 右上角「中文」或 `EN` | 只切换界面语言。选择会记住 |
| 左下三角图标，或 `Space` / `Enter` | 开始下一波 |
| 左下出门图标，或 `R`，或结束画面的图标 | 离开这一局并重开 |
| `Esc` | 关掉侧栏并取消选中的村民 |

Tap a villager, then tap a functional building to assign them. One building keeps one villager. After that, the villager leaves the map and shows up as a portrait and name in that building's panel. Tap the portrait to select them again. Tap empty ground to open the build list. Tap an existing building, with nobody selected, to inspect or sell it. Drag to pan and pinch to zoom. On a computer, `+` and `-` zoom toward the middle of the screen. The triangle starts the next wave. The door icon leaves and restarts. `Esc` closes the panel. The top-right button shows the current language, 中文 or EN, and switches the whole interface. The choice is saved.

### 村民 / Villagers

开局有一批房屋、农场、工坊、塔和木墙，以及 **5** 名村民（男女都有）。人数少于功能建筑的岗位，也少于两座房屋都派人之后的床位。开局 **100 木材 / 70 金币**。

村民移动速度是僵尸的 1.5 倍（108 对 72）。波次开始前，他们在村子里闲逛。波次开始后，没有床位、也没有被派到功能建筑的人会惊慌跑动，并往有人值守的房屋（否则往村子中心）靠。闲逛、惊慌和撤离都会沿着格子绕开房屋、木墙、树木和岩石，不会穿进去。人的脚底和景物的前沿决定谁画在前面，经过建筑、树木和岩石时会走到后面或前面。

碰到僵尸会感染，立刻变成一只新僵尸，并短暂高亮。有人值守的功能建筑如果被拆掉（不是出售），里面的人也会立刻感染。

The village starts with houses, a farm, a workshop, towers, walls, and **5** villagers, men and women. That is fewer people than there are jobs, and fewer than the beds both houses would offer once staffed. You start with **100 wood and 70 gold**.

Villagers move at 1.5× zombie speed (108 vs 72). Before the first wave they wander. After the start, anyone without a bed and without a job panics and drifts toward a staffed house, or toward the village center. Wandering, panic, and leaving follow the grid around houses, walls, trees, and rocks. Feet and the front edge of each sprite decide draw order, so a walker passes behind or in front of a building, tree, or rock.

Contact with a zombie infects them. They become a zombie on the spot, with a short highlight. If a staffed functional building is destroyed, and it was not sold, its assigned villager is infected immediately.

### 建筑 / Buildings

功能建筑（房屋、农场、工坊、矛塔、火塔）必须派人之后才生效。没人时只占格子：塔不攻击，农场不产木材，工坊不加成，房屋不提供床位。木墙不用派人，仍然挡路。木墙费用 18 木材，全图最多 **28** 座（含开局已有的墙），避免只用墙把路封死。

每座有人的房屋提供 4 个床位。派在这屋里的人占 1 个床位，剩下的床位分给还没有工作的村民，难民优先。被派到农场、工坊或塔的人不占床，也不会惊慌。盖房屋不会立刻生出新人。

人口只在每波结束后来的难民里增加，每波固定 2 人。他们有 **6.5** 秒。这段时间里把他们派去工作，或让有人的房屋腾出床位，他们就会留下。超时就向北离开，离开不是失败。

清完一波：木材 `8 + 有人农场 × 6`，金币 `+14`。击杀僵尸也会给资源。

Functional buildings (house, farm, workshop, spear tower, fire tower) work only while a villager is assigned. Unstaffed, they only occupy a tile: no shots, no wood, no tower bonus, no beds. Walls are never staffed and still block movement. A wall costs 18 wood, and the map allows at most **28** walls, counting the ones already built, so a pure maze has a limit.

A staffed house provides 4 beds. Its worker uses 1 bed. The remaining beds go to villagers without a job, refugees first. Someone assigned to a farm, workshop, or tower does not use a bed and does not panic. Building a house does not spawn people.

Population grows only from refugees at the end of a wave, 2 people each time. They wait **6.5** seconds. Assign them, or free a bed in a staffed house, and they stay. Otherwise they walk off the north edge. Leaving is not a loss.

A cleared wave pays `8 + 6 per staffed farm` wood and `14` gold. Kills also pay wood and gold.

| 建筑 | 费用 | 有人时 | 没人时 |
| --- | --- | --- | --- |
| 木墙 Wall | 18 木材 | 不用派人。挡路，生命 170。达到 28 座就不能再造。 | 同左 |
| 矛塔 Spear | 24 木材 + 40 金币 | 单体穿刺，优先打深入村落的僵尸。 | 不攻击 |
| 火塔 Fire | 16 木材 + 64 金币 | 火球溅射。 | 不攻击 |
| 房屋 House | 22 木材 | 4 个床位。不生人。 | 0 床位 |
| 农场 Farm | 16 木材 + 12 金币 | 每波结束额外 +6 木材。 | 不产木材 |
| 工坊 Workshop | 20 木材 + 28 金币 | 矛塔和火塔伤害 +25%（不叠加）。 | 没有加成 |

功能建筑头顶有一个点：绿色表示有人，红色表示没人。

A dot above a functional building is green when someone is assigned and red when it is empty.

入口、树木和岩石不能建造。木墙会迫使僵尸绕路或啃墙；把他们留在塔的射程里。僵尸够到没进建筑的村民就会感染。有人的建筑会从旁边被啃，建筑倒下后里面的人感染。

Entrance tiles, trees, and rocks are not buildable. Walls bend the route or get chewed, which holds zombies in tower range. Zombies infect villagers who are still outside. They bite a staffed building from the next tile, and the worker is infected when that building falls.

### 波次 / Waves

共 10 波。后面的僵尸更多、更耐打，并混有更快的僵尸、更慢的壮汉，第 10 波有一头目。

There are 10 waves. Later waves add more health, faster zombies, slow brutes, and a boss on wave 10.

谁都不派，村民停在外面，第一波就会被感染光。只派一个人去一座矛塔，中途会守不住。把房屋、两座塔、火塔和工坊都派上人，再用木墙把路折进射程，才能守完 10 波。

Leaving everyone unassigned loses on wave 1, because they are still outside. Staffing only one spear tower loses in the middle waves. Staff the house, both spear towers, the fire tower, and the workshop, and fold the road through their range, to last all 10 waves.

## 本地运行 / Run locally

需要 [Godot 4.7.x](https://godotengine.org/download)（本项目用 4.7.2 制作）。

1. 用 Godot 打开本目录的 `project.godot`。
2. 按 `F5` 运行主场景 `scenes/main.tscn`。

渲染器是 **GL Compatibility**，方便网页导出。地图是 Godot 的等距 `TileMapLayer`（diamond，约 45° 俯视），角色和建筑在开启 Y-sort 的节点下，按脚下位置排序。

Open `project.godot` in Godot 4.7.x and press `F5`. The project uses the GL Compatibility renderer. The ground is an isometric `TileMapLayer` (diamond, about 45° top-down). Characters and buildings Y-sort by their feet.

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
