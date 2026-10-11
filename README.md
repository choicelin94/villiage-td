# 部落村落塔防 / Tribal Village TD

等距俯视角的部落村落塔防。地图大约是原先的四倍大。僵尸从北边入口进来，追赶没躲进建筑的村民，也会啃有人值守的房屋和塔。先点村民，再点建筑，才能让房屋、农场、工坊和塔生效。守住 **10** 波即胜利。只有村民全部被感染才会失败。

An isometric tower defense game on a map about four times the previous area. Zombies enter from the north, chase villagers who are still outside, and chew staffed houses and towers. Click a villager first, then a building, to make houses, farms, the workshop, and towers do anything. Hold for **10** waves to win. The only loss is every villager becoming infected.

**引擎 / Engine:** Godot 4.7 (GDScript)  
**玩法切片 / Slice:** 20×20 等距地图，村落建筑 + 有上限的木墙 + 两种炮塔，村民派工，难民，10 波。  
**美术 / Art:** 建筑用 Kenney Fantasy Town Kit 2.0（CC0）。村民（男女）和僵尸用 Kenney Topdown Shooter（CC0）。来源与许可证见 [CREDITS.md](CREDITS.md)。

## 在线试玩 / Play in the browser

单线程网页导出在 [`docs/`](docs/)（关闭了线程，GitHub Pages 不需要 COOP/COEP）。第一次打开大约要下 40 MB 的引擎，请等加载条走完。建议横屏。点村民、点建筑、点屏幕按钮，这些操作在触屏上也能完成；完整的手机布局是下一步，不在这一版里。

The single-threaded web export is in [`docs/`](docs/) (threads off, so GitHub Pages does not need COOP/COEP headers). The first visit downloads about 40 MB. Wait for the loading bar. Landscape works best. Tapping a villager, a building, and the on-screen buttons is the touch path. A full mobile layout is the next pass and is not part of this version.

发布地址 / public URL, after Pages is turned on:

**https://choicelin94.github.io/villiage-td/**

这个仓库目前还没打开 GitHub Pages（接口返回 403，当前令牌不能改 Pages 设置）。上面的地址在打开 Pages 之前打不开。在 GitHub 上打开 **Settings → Pages → Build and deployment → Deploy from a branch**，Branch 选 `cursor/villager-infection-4d8f`（合并进 `main` 之后改选 `main`），Folder 选 **`/docs`**，保存。一两分钟后上面的地址才会变成可玩的页面。

GitHub Pages is not enabled on this repo yet (the API returned 403; this token cannot change that setting). The URL above is not live until Pages is enabled. In **Settings → Pages**, choose **Deploy from a branch**, branch `cursor/villager-infection-4d8f` (switch to `main` after merge), folder **`/docs`**, and save. The URL becomes playable after the site finishes building.

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

派人只有一条主路径：先点村民，再点房屋、农场、工坊或塔。先点建筑只会查看，不会派人。选建造按钮会取消当前选中的村民。

Staffing has one primary path: click a villager, then click a house, farm, workshop, or tower. Clicking a building first only inspects it. Choosing a build tool clears the villager selection.

| 操作 Action | 作用 Effect |
| --- | --- |
| 左键点村民 | 选中。再点一座功能建筑把这个人派过去 |
| 左键点已选中的人要去的建筑 | 派人。一座建筑同时只留一个人，后来的人换下前一个人 |
| 点击底部建筑按钮，或按 `1` 到 `6` | 选择木墙、矛塔、火塔、房屋、农场、工坊 |
| 左键点击可建造的草地 | 放置。绿色虚影表示可以放，红色表示不行 |
| 右键点击已放置的建筑 | 出售，返还一半木材和金币。出售会取消派工，但不会感染 |
| 右键空地，或 `Esc` | 取消选择 |
| **开始波次 / Start Wave**，或 `Space` / `Enter` | 在准备阶段放出下一波 |
| 底部 **重开 / Restart**（始终可点，不用确认），或 `R`，或结束画面的按钮 | 立刻重开一局 |

Left-click a villager, then left-click a functional building to assign them. One building keeps one villager; a new assignment replaces the previous one. Click a build button (or press `1` through `6`), then left-click a tile. A green ghost can be placed; a red ghost cannot. Right-click a building to sell it for half the wood and gold. Selling unassigns the worker and does not infect them. Right-click empty ground or press `Esc` to cancel. The **Restart** button on the bar is always available and does not ask for confirmation. `R` and the end-screen button do the same.

### 村民 / Villagers

开局有一批房屋、农场、工坊、塔和木墙，以及 **5** 名村民（男女都有）。人数少于功能建筑的岗位，也少于两座房屋都派人之后的床位。开局 **100 木材 / 70 金币**。

村民移动速度是僵尸的 1.5 倍（108 对 72）。波次开始前，他们在村子里闲逛。波次开始后，没有床位、也没有被派到功能建筑的人会惊慌跑动，并往有人值守的房屋（否则往村子中心）靠。

碰到僵尸会感染，立刻变成一只新僵尸，并短暂高亮。有人值守的功能建筑如果被拆掉（不是出售），里面的人也会立刻感染。

The village starts with houses, a farm, a workshop, towers, walls, and **5** villagers, men and women. That is fewer people than there are jobs, and fewer than the beds both houses would offer once staffed. You start with **100 wood and 70 gold**.

Villagers move at 1.5× zombie speed (108 vs 72). Before the first wave they wander. After the start, anyone without a bed and without a job panics and drifts toward a staffed house, or toward the village center.

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

游戏代码为 MIT，见 [LICENSE](LICENSE)。美术和字体各自的许可证见 [CREDITS.md](CREDITS.md)，请勿把素材的 CC0 / Apache-2.0 和代码许可混为一谈。

Game code is MIT. Art and the font keep their own licenses, documented in [CREDITS.md](CREDITS.md).
