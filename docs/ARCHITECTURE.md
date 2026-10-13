# 架构与维护 / Architecture and upkeep

这份说明给要改游戏、改数值或发网页的人。字段和 id 的细则在 [ASSET_STANDARD.md](ASSET_STANDARD.md)。怎么玩在仓库根目录的 [README.md](../README.md)。

This is the maintainer map. Field and id rules are in [ASSET_STANDARD.md](ASSET_STANDARD.md). How to play is in the root [README.md](../README.md).

## 目录各管一块 / What each directory owns

| 目录 | 所有权 | 不放什么 |
| --- | --- | --- |
| `data/` | 配置。平衡、形象目录、占地。只有 JSON。 | 图、脚本、生成的网页 |
| `assets/` | 资源。角色序列帧、建筑和景物 PNG、字体、可选 Spine。 | 数值、玩法 |
| `scripts/` | 行为。波次怎么刷、塔怎么打、人怎么走。平衡从 `data/` 读。 | 新的图片文件 |
| `scenes/` | 入口场景：主游戏、景深试验、压力页。 | 平衡表 |
| `docs/` | 已经能打开的静态站：游戏网页包、图鉴、试验页跳转。 | 手改过的图鉴 HTML |
| `tools/` | 从 `data/` 和 `assets/` 生成图鉴的脚本。 | 运行时逻辑 |

改一张图就改 `assets/`。改一条已经出场的数值就改 `data/` 里对应的 JSON，重新开一局即生效。文案在 `scripts/locale.gd`。

Edit art under `assets/`. Edit a live number in the matching JSON under `data/`, then start a new match. Copy lives in `scripts/locale.gd`.

## 运行时怎么串 / How a match is wired

```
project.godot
  Balance 自动加载 scripts/balance.gd
scenes/main.tscn
  scripts/main.gd          地图、波次、资源、胜负
    scripts/hud.gd         顶栏和侧栏
    scripts/locale.gd      自动加载，中英文字
    scripts/villager.gd    村民
    scripts/zombie.gd      敌人
    scripts/building.gd    建筑和塔
    scripts/spine_actor.gd 读 data/characters.json，播序列帧
    scripts/iso_volume.gd  读 data/iso_volumes.json，算占地
    scripts/depth_solver.gd 两段排序
scenes/depth_lab.tscn      景深试验，网页入口 docs/depth-lab/
scenes/depth_stress.tscn   压力页，网页入口 docs/stress/
```

`Balance` 在启动时加载 `data/units.json`、`data/enemies.json`、`data/buildings.json`。伤害是 `max(1, round(attack * 100 / (100 + defense)))`。工坊的 `tower_damage` 先乘在攻击上，再对每个目标套一次这个公式。村民被感染仍是接触，不走这个公式。

塔、农场、房屋、工坊立着就工作，不用先派人。房屋立着就给床位；有人躲在里面才占 1 个床，头顶才有绿点。农场按 `produces.rate` 在清波时加木材。工坊加成不叠加，取还立着的最高一座。`attack_speed` 是每秒攻击次数，冷却是 `1 / attack_speed`。

`project.godot` 的主场景是 `scenes/main.tscn`，渲染器是 GL Compatibility。网页导出关闭了线程和 GDExtension。字体是 `assets/fonts/NotoSansSC-Regular.otf`。

`Balance` loads `data/units.json`, `data/enemies.json`, and `data/buildings.json` at startup. Damage is `max(1, round(attack * 100 / (100 + defense)))`. A workshop's `tower_damage` multiplies attack first, then the formula runs once per target. Villager infection is still contact. Towers, farms, houses, and the workshop work while they stand. `attack_speed` is attacks per second.

玩家看到的三页静态入口都在 `docs/`：

| 路径 | 内容 |
| --- | --- |
| `docs/index.html` | 游戏网页包。左上角链到景深、压力页、图鉴。 |
| `docs/depth-lab/` | 跳到 `../index.html?lab=1` |
| `docs/stress/` | 跳到 `../index.html?stress=300` |
| `docs/codex/` | 图鉴。由 `tools/build_codex.py` 生成。 |

## 配置和资源 / Config versus art

`data/` 是配置，`assets/` 是资源。两边不要混。

| 文件 | 游戏会读吗 | 图鉴会读吗 |
| --- | --- | --- |
| `data/units.json` | 会。`scripts/balance.gd` | 会 |
| `data/enemies.json` | 会。`scripts/balance.gd`，含波次表 | 会 |
| `data/buildings.json` | 会。`scripts/balance.gd` | 会 |
| `data/characters.json` | 会。`spine_actor.gd`。`Balance` 只用它把皮肤名换成图序号 | 会。用来裁第 0 帧 |
| `data/iso_volumes.json` | 会。`iso_volume.gd` 读到就用 | 会。核对体积键还在 |
| `assets/characters/*.png` | 会。路径写在 `characters.json` | 会 |
| `assets/village/*.png` | 会。建筑路径写在 `buildings.json` 的 `tex` | 会 |

`python3 tools/build_codex.py` 是图鉴的正式路径。它需要 Pillow。生成 `docs/codex/index.html`、`docs/codex/catalog.json` 和 `docs/codex/thumbs/`。提交这些生成结果。不要手改它们。名字来自 `scripts/locale.gd` 的 `display_key`。单位是否「已出场」看 `main.gd` 里有没有 `Balance.unit("这个 id")`。敌人 id 以 `enemies.json` 为准（`shooter_elite`，不是另一套目录）。

新的挡路景物 PNG 要补进 `tools/build_codex.py` 的 `SCENERY_LABELS`，否则生成器会停。草地和道路是地面，不进图鉴。

## 还没收进 JSON 的地方 / Leftover duplication

单位、敌人和建筑的战斗数值已经只在那三份 JSON 里。下面这些仍是另外一份，或还没接到玩法上。

| 真源 | 另一份 | 状态 |
| --- | --- | --- |
| `data/iso_volumes.json` | `scripts/iso_volume.gd` 的 `TABLE` | JSON 读得到就用 JSON。`TABLE` 只在文件缺失或解析失败时顶上，两边要保持一样。 |
| `scripts/main.gd` 的 `WAVE_CLEAR_WOOD`（8）和 `WAVE_CLEAR_GOLD`（14） | 没有对应 JSON | 清波底薪仍是这两个常量。农场每波木材是 `buildings.json` 里 `farm.produces.rate`。 |
| `units.json` 里村民的 `attack` / `attack_speed` / `attack_range` | 对局还没花 | 感染仍是碰到就变。这些攻击数值已经在 Balance 里，还没有挥出去。 |
| `units.json` 的 `spearman`、`engineer` | `main.gd` 只调用 `Balance.unit("villager")` | 配置已有。房屋的 `recruits` 列了他们，还不是训练按钮。 |
| `docs/index.html` 的 `<nav id="site-links">` | Godot 重新导出会盖掉 | 景深、压力页、图鉴三个链接是手写的，导出后要放回去。 |

波次表里的 `speed` 是缩放用的作者值，还没乘 `WORLD_SCALE`。卡片上的 `move_speed` 已经是第 1 波的世界单位。后面的波次用 `move_speed * wave.speed / waves[0].speed`，不要把表里的 `speed` 再乘一次比例之外的东西。

## 一次改动怎么走完 / A change, end to end

1. 图放进 `assets/`。不要给已经在用的文件改名。
2. 形象、占地、平衡分别写入 `data/characters.json`、`data/iso_volumes.json`、`data/units.json` 或 `enemies.json` 或 `buildings.json`。字段见资源标准。改占地时把 `iso_volume.gd` 的 `TABLE` 后备一起改。
3. 文案写入 `scripts/locale.gd` 的 `display_key`。JSON 不需要再抄一份 `name`。
4. 新的建筑 `kind` 才改 `Building.Kind`、`_volume_key` 和放置逻辑。矛兵和工匠已经在 `units.json` 里；要让他们出场，就在 `main.gd` 里调用 `Balance.unit("spearman")` 或 `Balance.unit("engineer")`。
5. 运行 `python3 tools/build_codex.py`。
6. 提交 `data/`、`assets/`、`scripts/` 和 `docs/codex/`。
7. 推到 `main` 后，Actions 发布网页。见下一节。

本地先看图鉴：

```bash
python3 -m http.server -d docs 8765
# http://127.0.0.1:8765/codex/
```

## 网页发布 / GitHub Pages

工作流是 `.github/workflows/pages.yml`。

- 拉取请求会跑生成器。`docs/codex/index.html` 和 `catalog.json` 必须已经提交，缩略图不能多也不能少。PNG 压缩字节差一点点不会让检查失败。
- 推到 `main`，或在 `main` 上手动跑这个工作流时：再跑一次生成器，用官方 Pages 动作把整个 `docs/` 部署出去。游戏、景深、压力页和图鉴一起上去。
- 站点根就是 `docs/` 的内容。图鉴的线上路径是 `/codex/`，完整地址是 `https://choicelin94.github.io/villiage-td/codex/`。

一次性设置：仓库 **Settings → Pages → Build and deployment → Source** 选 **GitHub Actions**。在改成 Actions 之前，原来的「从分支发布 `/docs`」仍然有效；工作流里的部署步骤会失败，直到 Source 改过来。改过来之后不要再把 Source 设回某个分支，否则两套发布会抢。

### Godot 导出不在 CI 里

Godot **4.7.2** 的 Linux 编辑器压缩包在发布页上。配套的 export templates（`Godot_v4.7.2-stable_export_templates.tpz`）大约 **1.28 GB**。每次推送都下载这份模板太重，而且一次全新导出会盖掉 `docs/index.html` 里手写的三个链接（景深、压力页、图鉴）。

所以 CI **不**重新导出 wasm。`docs/index.js`、`docs/index.wasm`、`docs/index.pck` 和图标是本地导出后提交的。Actions 原样发布它们，只负责重新生成图鉴并上传 `docs/`。

本地导出仍然是：

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

导出预设 **Web** 写着默认路径 `build/web/index.html`，线程和 GDExtension 都是关的。上面的命令把结果直接写进 `docs/`。写完后把这三个链接放回 `docs/index.html` 的 `<nav id="site-links">`：`depth-lab/`、`stress/`、`codex/`。没放回去的话，Pages 上的游戏页就进不了图鉴。

The 4.7.2 export templates are about 1.28 GB, and a fresh export overwrites the hand-maintained links on `docs/index.html`. CI deploys the committed web build and regenerates the codex. It does not run Godot.
