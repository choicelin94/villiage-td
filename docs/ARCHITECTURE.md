# 架构与维护 / Architecture and upkeep

这份说明给要改游戏、改数值或发网页的人。字段和 id 的细则在 [ASSET_STANDARD.md](ASSET_STANDARD.md)。怎么玩在仓库根目录的 [README.md](../README.md)。

This is the maintainer map. Field and id rules are in [ASSET_STANDARD.md](ASSET_STANDARD.md). How to play is in the root [README.md](../README.md).

## 目录各管一块 / What each directory owns

| 目录 | 所有权 | 不放什么 |
| --- | --- | --- |
| `data/` | 配置。平衡、形象目录、占地。只有 JSON。 | 图、脚本、生成的网页 |
| `assets/` | 资源。角色序列帧、建筑和景物 PNG、字体、可选 Spine。 | 数值、玩法 |
| `scripts/` | 行为。波次怎么刷、塔怎么打、人怎么走。 | 新的图片文件 |
| `scenes/` | 入口场景：主游戏、景深试验、压力页。 | 平衡表 |
| `docs/` | 已经能打开的静态站：游戏网页包、图鉴、试验页跳转。 | 手改过的图鉴 HTML |
| `tools/` | 从 `data/` 和 `assets/` 生成图鉴的脚本。 | 运行时逻辑 |

改一张图就改 `assets/`。改一个 id 或一条目录就改 `data/`。已经在对局里生效的数字，还要改 `scripts/` 里的那一份，因为对局还没改成读 JSON。

Edit art under `assets/`. Edit ids and catalogs under `data/`. Numbers the match already uses also have a copy in `scripts/`, because the match does not load the balance JSON yet.

## 运行时怎么串 / How a match is wired

```
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

`project.godot` 的主场景是 `scenes/main.tscn`，渲染器是 GL Compatibility。网页导出关闭了线程和 GDExtension。字体是 `assets/fonts/NotoSansSC-Regular.otf`。

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
| `data/characters.json` | 会。`spine_actor.gd` | 会。用来裁第 0 帧 |
| `data/iso_volumes.json` | 会。`iso_volume.gd` 读到就用 | 会。核对体积键还在 |
| `data/units.json` | 不会 | 会 |
| `data/enemies.json` | 不会 | 会 |
| `data/buildings.json` | 不会 | 会 |
| `assets/characters/*.png` | 会。路径写在 `characters.json` | 会 |
| `assets/village/*.png` | 会。建筑路径写在 `building.gd`，景物路径写在 `main.gd` | 会。建筑路径以 `buildings.json` 的 `tex` 为准 |

`python3 tools/build_codex.py` 是图鉴的正式路径。它需要 Pillow。生成 `docs/codex/index.html`、`docs/codex/catalog.json` 和 `docs/codex/thumbs/`。提交这些生成结果。不要手改它们。

新的挡路景物 PNG 要补进 `tools/build_codex.py` 的 `SCENERY_LABELS`，否则生成器会停。草地和道路是地面，不进图鉴。

## 仍写在脚本里的数值 / Hardcoded balance (debt)

下面这些已经出场的数，目录里有一份，脚本里还有一份。生成器会对照；对不上就失败。对局本身只读脚本那一份。把对局改成读 JSON 之前，两处都要改。

| 对局里的真源 | 目录里的副本 | 状态 |
| --- | --- | --- |
| `scripts/main.gd` 的 `VILLAGER_SPEED` | `units.json` 里 `villager.move_speed` | 债务。脚本不读 JSON。 |
| `scripts/main.gd` 的 `WAVES`、`KIND_MOD`、清波奖励、`tower_bonus` | `enemies.json` 的 `waves` 和敌人倍率；`buildings.json` 的 `economy`、农场、工坊 | 债务。 |
| `scripts/zombie.gd` 的咬击间隔 `_cooldown = 0.9` | 每条敌人的 `attack_speed` | 债务。 |
| `scripts/building.gd` 的 `STATS` | `buildings.json` | 债务。塔的射程和弹速在脚本里乘 `WORLD_SCALE`，JSON 里写乘完的世界像素。 |
| `scripts/iso_volume.gd` 的 `TABLE` | `iso_volumes.json` | 文件存在时游戏读 JSON。`TABLE` 只是读失败时的后备，要和 JSON 保持一样。 |
| `scripts/locale.gd` | 各条目的 `name` | 生成器要求两边的中文和英文一致。 |
| 无 | `units.json` 的 `spearman`、`engineer` | 只在目录里。`status` 是 `configured`。`main.gd` 只生成村民。 |

`defense` 在目录里是护甲，现在全是 0。建筑脚本里的 `"defense": true` 表示这一类是防御建筑，对应 JSON 的 `category`，不是护甲。

## 一次改动怎么走完 / A change, end to end

1. 图放进 `assets/`。不要给已经在用的文件改名。
2. 形象、占地、平衡分别写入 `data/characters.json`、`data/iso_volumes.json`、`data/units.json` 或 `enemies.json` 或 `buildings.json`。字段见资源标准。
3. 文案写入 `scripts/locale.gd`，并和 JSON 的 `name` 用同一句中文和英文。
4. 如果这个实体已经会出场，再改 `scripts/` 里对应的常量。新的建筑 `kind` 还要改 `Building.Kind` 和放置逻辑。
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
