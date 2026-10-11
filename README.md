# 部落村落塔防 / Tribal Village TD

等距俯视角的部落村落塔防。僵尸从北口涌入，沿着草地走向南边的圣树。用木墙改道，用矛塔和火塔守住 8 波进攻。

An isometric tower defense game. Zombies enter from the north and path toward the sacred tree in the south. Maze them with wooden walls, and hold the village for 8 waves with a spear tower and a fire tower.

**引擎 / Engine:** Godot 4.7 (GDScript)  
**玩法切片 / Slice:** 一张地图，木墙 + 两种炮塔，8 波，胜负条件明确。  
**美术 / Art:** Kenney CC0 等距塔防图块。来源与许可证见 [CREDITS.md](CREDITS.md)。

## 在线试玩 / Play in the browser

公开页面（GitHub Pages，单线程 Web 导出，不需要 SharedArrayBuffer）：

Public page (GitHub Pages, single-threaded web export, no SharedArrayBuffer headers required):

**https://choicelin94.github.io/villiage-td/**

第一次打开会下载约十几 MB 的引擎与资源，请等加载条走完。建议横屏。

The first visit downloads the engine and assets (on the order of 10–20 MB). Wait for the loading bar. Landscape orientation works best.

## 怎么玩 / How to play

### 目标 / Goal

- 圣树有生命值。僵尸走到圣树旁边会持续攻击。
- 生命归零：村落陷落。
- 守完 **8** 波且场上没有剩余僵尸：胜利。

The sacred tree has HP. Zombies that reach it attack until it falls. Survive all **8** waves with no zombies left to win.

### 操作 / Controls

| 操作 Action | 作用 Effect |
| --- | --- |
| 点击底部 **木墙 / 矛塔 / 火塔**，或按 `1` `2` `3` | 选择要建造的建筑 |
| 左键点击可建造的草地 | 放置。绿色虚影表示可以放，红色表示不行 |
| 右键点击已放置的建筑 | 出售，返还一半木材和金币 |
| 右键空地，或 `Esc` | 取消选择 |
| **开始波次 / Start Wave**，或 `Space` / `Enter` | 在准备阶段放出下一波 |
| 结束画面的 **重新开始**，或 `R` | 重开一局 |

Click a build button (or press `1` `2` `3`), then left-click a tile. A green ghost can be placed; a red ghost cannot. Right-click a building to sell it for half the wood and gold. Right-click empty ground or press `Esc` to cancel. Start the next wave with the button or `Space` / `Enter`.

### 建造 / Buildings

开局 **120 木材 / 80 金币**。击杀僵尸和清空波次都会再给资源。波次进行中也可以建造。

You start with **120 wood and 80 gold**. Kills and cleared waves pay more. You can build during a wave.

| 建筑 | 费用 | 作用 |
| --- | --- | --- |
| 木墙 Wall | 12 木材 | 挡住一格。僵尸无路可走时会拆墙。生命 170。 |
| 矛塔 Spear | 32 木材 + 48 金币 | 单体穿刺，优先打离圣树更近的僵尸。 |
| 火塔 Fire | 22 木材 + 72 金币 | 火球溅射，适合拐角和挤在一起的僵尸。 |

Walls block a tile. If the path to the tree is sealed, zombies attack the nearest wall or tower. The spear tower hits one target (the one closest to the tree). The fire tower splashes.

入口四格和圣树、树木、岩石不能建造。木墙会迫使僵尸绕路；把它们引进塔的射程，比把塔直接堵在路上更有用。

The four entrance tiles, the sacred tree, trees, and rocks are not buildable. Walls should bend the route through tower range. A tower placed on the path also blocks movement.

### 波次 / Waves

共 8 波，后面的僵尸更多、更耐打，并混有更快的僵尸、更慢的壮汉，最后一波有一头目。

There are 8 waves. Later waves add more health, faster zombies, slow brutes, and a boss on wave 8.

什么都不造，第一波就会破树。只在路边放两三座塔、不改道，中后期会漏怪。用木墙把路折成几段，并让矛塔和火塔覆盖这些路段，才能守完。

Doing nothing loses on wave 1. A few towers beside a straight path leak in the mid waves. Fold the path with walls so spear and fire towers cover the lanes.

## 本地运行 / Run locally

需要 [Godot 4.7.x](https://godotengine.org/download)（本项目用 4.7.2 制作）。

1. 用 Godot 打开本目录的 `project.godot`。
2. 按 `F5` 运行主场景 `scenes/main.tscn`。

渲染器是 **GL Compatibility**，方便网页导出。地图是 Godot 的等距 `TileMapLayer`（diamond / 2:1），角色和建筑在开启 Y-sort 的节点下，按脚下位置排序。

Open `project.godot` in Godot 4.7.x and press `F5`. The project uses the GL Compatibility renderer. The ground is an isometric `TileMapLayer`. Characters and buildings Y-sort by their feet.

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
