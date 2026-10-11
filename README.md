# 部落村落塔防 / Tribal Village TD

等距俯视角的部落村落塔防。僵尸从北口涌入，沿着小路走向南边的圣树。先盖房屋养活人口，再用木墙改道，用矛塔和火塔守住 8 波进攻。

An isometric tower defense game. Zombies enter from the north and path toward the sacred tree in the south. Build houses to grow the population, maze the road with wooden walls, and hold for 8 waves with a spear tower and a fire tower.

**引擎 / Engine:** Godot 4.7 (GDScript)  
**玩法切片 / Slice:** 一张地图，村落建筑（房屋、农场、工坊）+ 木墙 + 两种炮塔，人口，8 波。  
**美术 / Art:** Kenney Fantasy Town Kit 2.0（CC0）的等距渲染，外加原有的 CC0 顶视角僵尸。来源与许可证见 [CREDITS.md](CREDITS.md)。

## 在线试玩 / Play in the browser

单线程网页导出在 [`docs/`](docs/)（关闭了线程，GitHub Pages 不需要 COOP/COEP）。第一次打开大约要下 40 MB 的引擎，请等加载条走完。建议横屏。

The single-threaded web export is in [`docs/`](docs/) (threads off, so GitHub Pages does not need COOP/COEP headers). The first visit downloads about 40 MB. Wait for the loading bar. Landscape works best.

发布地址 / public URL, after Pages is turned on:

**https://choicelin94.github.io/villiage-td/**

这个仓库目前还没打开 GitHub Pages（接口返回 403，当前令牌不能改 Pages 设置）。在 GitHub 上打开 **Settings → Pages → Build and deployment → Deploy from a branch**，Branch 选 `cursor/village-population-4d8f`（合并进 `main` 之后改选 `main`），Folder 选 **`/docs`**，保存。一两分钟后上面的地址就会变成可玩的页面。

GitHub Pages is not enabled on this repo yet (the API returned 403; this token cannot change that setting). In **Settings → Pages**, choose **Deploy from a branch**, branch `cursor/village-population-4d8f` (switch to `main` after merge), folder **`/docs`**, and save. The URL above becomes playable after the site finishes building.

本地先看网页包 / preview the export locally:

```bash
python3 -m http.server -d docs 8765
# open http://127.0.0.1:8765/
```

## 怎么玩 / How to play

### 目标 / Goal

- 圣树有生命值。僵尸走到圣树旁边会持续攻击。
- 生命归零：村落陷落。
- 守完 **8** 波且场上没有剩余僵尸：胜利。

The sacred tree has HP. Zombies that reach it attack until it falls. Survive all **8** waves with no zombies left to win.

### 操作 / Controls

| 操作 Action | 作用 Effect |
| --- | --- |
| 点击底部建筑按钮，或按 `1` 到 `6` | 选择木墙、矛塔、火塔、房屋、农场、工坊 |
| 左键点击可建造的草地 | 放置。绿色虚影表示可以放，红色表示不行 |
| 右键点击已放置的建筑 | 出售，返还一半木材和金币 |
| 右键空地，或 `Esc` | 取消选择 |
| **开始波次 / Start Wave**，或 `Space` / `Enter` | 在准备阶段放出下一波 |
| 结束画面的 **重新开始**，或 `R` | 重开一局 |

Click a build button (or press `1` through `6`), then left-click a tile. A green ghost can be placed; a red ghost cannot. Right-click a building to sell it for half the wood and gold. Right-click empty ground or press `Esc` to cancel. Start the next wave with the button or `Space` / `Enter`.

### 建造与人口 / Buildings and population

开局 **150 木材 / 90 金币 / 人口 6/6**。击杀僵尸会给资源。每清完一波，金币增加 `8 + 人口 × 2`，木材增加 `6 + 农场数 × 5`。波次进行中也可以建造。

You start with **150 wood, 90 gold, and population 6/6**. Kills pay wood and gold. Each cleared wave adds `8 + population × 2` gold and `6 + 5 per farm` wood. You can build during a wave.

顶栏显示 **人口 Pop**。房屋把人口上限加 4，新村民会立刻住进来。出售或被拆掉的房屋会把上限减回去。人口有两个作用：

- **防御编制：** 木墙、矛塔、火塔的总数不能超过当前人口。房屋、农场、工坊不占这个名额。
- **收入：** 人口越高，每波结束拿到的金币越多。

The top bar shows **Pop**. Each house adds 4 to the cap, and the new villagers arrive immediately. Selling or losing a house lowers the cap again. Population does two things:

- **Defense roster:** the number of walls and towers cannot exceed the current population. Houses, farms, and the workshop do not count against it.
- **Income:** a larger population pays more gold at the end of each wave.

| 建筑 | 费用 | 作用 |
| --- | --- | --- |
| 木墙 Wall | 10 木材 | 挡住一格。僵尸无路可走时会拆它。生命 170。占 1 个防御名额。 |
| 矛塔 Spear | 24 木材 + 40 金币 | 单体穿刺，优先打离圣树更近的僵尸。占 1 个名额。 |
| 火塔 Fire | 16 木材 + 64 金币 | 火球溅射。占 1 个名额。 |
| 房屋 House | 22 木材 | 人口上限 +4。挡住一格，可被拆。 |
| 农场 Farm | 16 木材 + 12 金币 | 每座农场让每波结束时多 5 木材。挡住一格。 |
| 工坊 Workshop | 20 木材 + 28 金币 | 场上有工坊时，矛塔和火塔伤害 +25%（不叠加）。挡住一格。 |

Walls, towers, houses, farms, and the workshop all block a tile. If the path to the tree is sealed, zombies attack the nearest building. The spear tower hits the zombie closest to the tree. The fire tower splashes. One standing workshop raises spear and fire damage by 25%. Extra workshops do not stack.

入口四格和圣树、树木、岩石不能建造。木墙会迫使僵尸绕路；把它们引进塔的射程，比把塔直接堵在路上更有用。人口不够时，先盖房屋再加塔。

The four entrance tiles, the sacred tree, trees, and rocks are not buildable. Walls should bend the route through tower range. A tower placed on the path also blocks movement. If the defense roster is full, build a house before adding another tower.

### 波次 / Waves

共 8 波，后面的僵尸更多、更耐打，并混有更快的僵尸、更慢的壮汉，最后一波有一头目。

There are 8 waves. Later waves add more health, faster zombies, slow brutes, and a boss on wave 8.

什么都不造，第一波就会破树。只在路边放两三座塔、不改道，中期会漏怪。先盖房屋把人口加上去，再用木墙把路折成几段，并让矛塔和火塔覆盖这些路段，才能守完。

Doing nothing loses on wave 1. A few towers beside a straight path leak in the middle waves. Raise the population with houses, then fold the path so spear and fire towers cover the lanes.

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

游戏代码为 MIT，见 [LICENSE](LICENSE)。美术和字体各自的许可证见 [CREDITS.md](CREDITS.md)，请勿把素材的 CC0 / Apache-2.0 和代码许可混为一谈。

Game code is MIT. Art and the font keep their own licenses, documented in [CREDITS.md](CREDITS.md).
