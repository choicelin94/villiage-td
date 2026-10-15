# 架构与维护 / Architecture and upkeep

这份说明给要改游戏、改数值或发网页的人。配置目录见 [SPEC_CONFIG.md](SPEC_CONFIG.md)，美术目录见 [SPEC_ART.md](SPEC_ART.md)。字段和 id 的细则仍在 [ASSET_STANDARD.md](ASSET_STANDARD.md)。怎么玩在仓库根目录的 [README.md](../README.md)。

This is the maintainer map. Config lives in [SPEC_CONFIG.md](SPEC_CONFIG.md). Art lives in [SPEC_ART.md](SPEC_ART.md). Field and id rules stay in [ASSET_STANDARD.md](ASSET_STANDARD.md). How to play is in the root [README.md](../README.md).

## 目录各管一块 / What each directory owns

| 目录 | 所有权 | 不放什么 |
| --- | --- | --- |
| `config/` | 配置。平衡、形象目录、占地。只有 JSON。 | 图、脚本、生成的网页 |
| `art/` | 资源。角色序列帧、建筑和景物 PNG、字体、可选 Spine。 | 数值、玩法 |
| `scripts/` | 行为。波次怎么刷、塔怎么打、人怎么走。平衡从 `config/` 读。 | 新的图片文件 |
| `scenes/` | 入口场景：主游戏、工作台，以及仍可深链的景深试验和压力页。 | 平衡表 |
| `docs/` | 已经能打开的静态站：游戏网页包、图鉴、试验页跳转。 | 手改过的图鉴 HTML |
| `tools/` | 从 `config/` 和 `art/` 生成图鉴的脚本。 | 运行时逻辑 |

改一张图就改 `art/`。改一条已经出场的数值就改 `config/` 里对应的 JSON，重新开一局即生效。文案在 `scripts/locale.gd`。

Edit art under `art/`. Edit a live number in the matching JSON under `config/`, then start a new match. Copy lives in `scripts/locale.gd`.

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
    scripts/spine_actor.gd 读 config/presentation/characters.json，播序列帧
    scripts/iso_volume.gd  读 config/presentation/volumes.json，算占地
    scripts/depth_solver.gd 两段排序
scenes/depth_lab.tscn      景深试验。只留网页深链 docs/depth-lab/，工作台不再进入
scenes/depth_stress.tscn   压力页。只留网页深链 docs/stress/，工作台不再进入
scenes/workbench.tscn      工作台。只编辑配置文档。保存写入 user://layout.json 与 user://balance.json，并同步 user://setup.json。地图由 SetupDocument、MapCommands、MapView、MapInteraction 组成，ActorPainter 贴 art/ 的图，出怪点是红色半透明遮罩。滚轮或地图上的＋／－按光标缩放，拖动空地平移，绘制裁在 MapView 里。点格子打开的面板停在这块黑色地图右侧，不会盖到工作台其它控件。路面是单独铺的格子，不决定怪物路线，只让村民走得更快；全图只有一个出怪口，出怪口不绑在路面上，设出怪口不会自动铺一条路。窗口逻辑宽度低于 900，或短边低于 480 时，盖一层灰罩挡住编辑，只留返回游戏
```

`Balance` 在启动时加载 `config/balance/units.json`、`config/balance/enemies.json`、`config/balance/buildings.json`，再叠 `config/layout/setup.json`、本机 `user://layout.json` 和 `user://balance.json`。只有旧存档时才读 `user://setup.json`。伤害是 `max(1, round(attack * 100 / (100 + defense)))`。工坊的 `tower_damage` 先乘在攻击上，再对每个目标套一次这个公式。村民被感染仍是接触，不走这个公式。击杀只加 `gold_reward`，`wood_reward` 读入后强制为 0。

塔立着就攻击，不用先派人。房屋的 `beds` / `provides.slots` 是村民空缺。矛兵营、枪兵营、工坊分别提供矛兵、枪兵、工兵空缺。木坊按驻守村民产木，`staff_slots` 默认 4，空坊为 0。农场按 `produces.rate` 在清波时加木材。工坊加成不叠加，取还立着的最高一座。`attack_speed` 是每秒攻击次数，冷却是 `1 / attack_speed`。

本机配置带 `config_version`。打开玩法指南或页内点「刷新」时，若本地版本低于出厂 `config/layout/setup.json`，先补上出厂字段并升版本，再刷新这一页。玩法指南不编辑数值。锁敌默认在 `setup.json` 的 `combat`：`target_hold` 1.2 秒、`switch_margin` 0.72、`repath` 0.6 秒、`stuck` 0.9 秒、`wander_hold` 2.4 秒、`panic_hold` 1.3 秒。清波入驻默认 `settlement.chance` 0.65、`max_per_wave` 3。

`project.godot` 的主场景是 `scenes/main.tscn`，渲染器是 GL Compatibility。网页导出关闭了线程和 GDExtension。字体是 `art/fonts/NotoSansSC-Regular.otf`。

`Balance` loads `config/balance/units.json`, `config/balance/enemies.json`, and `config/balance/buildings.json`, then overlays `config/layout/setup.json` and `user://setup.json`. Damage is `max(1, round(attack * 100 / (100 + defense)))`. A workshop's `tower_damage` multiplies attack first, then the formula runs once per target. Villager infection is still contact. Kills add gold only. Towers attack while they stand. The lumber mill produces wood from stationed villagers. `attack_speed` is attacks per second. A codex refresh upgrades a local config whose `config_version` is behind the shipped file, then reloads the page.

玩家看到的三页静态入口都在 `docs/`：

| 路径 | 内容 |
| --- | --- |
| `docs/index.html` | 游戏网页包。玩法指南和工作台在游戏内右上角问号菜单，不在网页角上再挂按钮。 |
| `docs/depth-lab/` | 跳到 `../index.html?lab=1` |
| `docs/stress/` | 跳到 `../index.html?stress=300` |
| `docs/codex/` | 玩法指南。由 `tools/build_codex.py` 生成。首页是背景和玩法，资料卡片在后面。 |

## 配置和资源 / Config versus art

`config/` 是配置，`art/` 是资源。两边不要混。

| 文件 | 游戏会读吗 | 图鉴会读吗 |
| --- | --- | --- |
| `config/balance/units.json` | 会。`scripts/balance.gd` | 会 |
| `config/balance/enemies.json` | 会。`scripts/balance.gd`，含波次表 | 会 |
| `config/balance/buildings.json` | 会。`scripts/balance.gd` | 会 |
| `config/layout/setup.json` | 会。难度、清波入驻、锁敌、经济、出怪长方形、开局建筑、开局站位、额外景物。`config_version` 给出厂版本 | 会。刷新时用来比对本地配置 |
| `config/presentation/characters.json` | 会。`spine_actor.gd`。`Balance` 只用它把皮肤名换成图序号 | 会。用来裁第 0 帧 |
| `config/presentation/volumes.json` | 会。`iso_volume.gd` 读到就用 | 会。核对体积键还在 |
| `art/characters/*.png` | 会。路径写在 `characters.json` | 会 |
| `art/village/*.png` | 会。建筑路径写在 `buildings.json` 的 `tex` | 会 |

`python3 tools/build_codex.py` 是图鉴的正式路径。它需要 Pillow。生成 `docs/codex/index.html`、`docs/codex/catalog.json` 和 `docs/codex/thumbs/`。提交这些生成结果。不要手改它们。名字来自 `scripts/locale.gd` 的 `display_key`。单位是否「已出场」看 `main.gd` 里有没有 `Balance.unit("这个 id")`。敌人 id 以 `enemies.json` 为准（`shooter_elite`，不是另一套目录）。

新的挡路景物 PNG 要补进 `tools/build_codex.py` 的 `SCENERY_LABELS`，否则生成器会停。草地和道路是地面，不进图鉴。

## 还没收进 JSON 的地方 / Leftover duplication

单位、敌人和建筑的战斗数值已经只在那三份 JSON 里。下面这些仍是另外一份，或还没接到玩法上。

| 真源 | 另一份 | 状态 |
| --- | --- | --- |
| `config/presentation/volumes.json` | `scripts/iso_volume.gd` 的 `TABLE` | JSON 读得到就用 JSON。`TABLE` 只在文件缺失或解析失败时顶上，两边要保持一样。 |
| `scripts/main.gd` 的 `WAVE_CLEAR_WOOD`（8）和 `WAVE_CLEAR_GOLD`（14） | `config/layout/setup.json` 的 `economy` | 对局读 setup，常量只在缺字段时兜底。农场每波木材仍是 `farm.produces.rate`。木坊产木在 `lumber_mill.produces`。 |
| `units.json` 里村民的 `attack` / `attack_speed` / `attack_range` | 村民仍不挥砍 | 感染仍是碰到就变。矛兵、枪兵、工兵会用自己的攻击。 |
| `units.json` 的 `spearman`、`gunner`、`engineer` | `main.gd` 在开局登记 `Balance.unit(...)`，清波按空缺生成 | 不是训练按钮，也不是把村民转化过去。 |
| `docs/index.html` | Godot 重新导出会盖掉手改 | 游戏页不再手写左上角链接。问号菜单在 `scripts/hud.gd`。 |

波次表里的 `speed` 是缩放用的作者值，还没乘 `WORLD_SCALE`。卡片上的 `move_speed` 已经是第 1 波的世界单位。后面的波次用 `move_speed * wave.speed / waves[0].speed`，不要把表里的 `speed` 再乘一次比例之外的东西。

## 一次改动怎么走完 / A change, end to end

1. 图放进 `art/`。不要给已经在用的文件改名。
2. 形象、占地、平衡分别写入 `config/presentation/characters.json`、`config/presentation/volumes.json`、`config/balance/units.json` 或 `enemies.json` 或 `buildings.json`。字段见资源标准。改占地时把 `iso_volume.gd` 的 `TABLE` 后备一起改。
3. 文案写入 `scripts/locale.gd` 的 `display_key`。JSON 不需要再抄一份 `name`。
4. 新的建筑 `kind` 才改 `Building.Kind`、`_volume_key` 和放置逻辑。矛兵、枪兵、工兵已经由 `main.gd` 调用 `Balance.unit(...)`，并在清波按空缺入驻。
5. 运行 `python3 tools/validate_config.py`、`python3 tools/validate_art.py`，再运行 `python3 tools/build_codex.py`。
6. 提交 `config/`、`art/`、`scripts/` 和 `docs/codex/`。
7. 推到 `main` 后，Actions 发布网页。见下一节。

本地先看图鉴：

```bash
python3 -m http.server -d docs 8765
# http://127.0.0.1:8765/codex/
```

## 网页发布 / GitHub Pages

工作流是 `.github/workflows/pages.yml`。

- 拉取请求会先跑 `tools/validate_config.py` 和 `tools/validate_art.py`，再跑生成器。`docs/codex/index.html` 和 `catalog.json` 必须已经提交，缩略图不能多也不能少。PNG 压缩字节差一点点不会让检查失败。
- 推到 `main`，或在 `main` 上手动跑这个工作流时：再跑一次生成器，用官方 Pages 动作把整个 `docs/` 部署出去。游戏、景深、压力页和图鉴一起上去。
- 站点根就是 `docs/` 的内容。图鉴的线上路径是 `/codex/`，完整地址是 `https://choicelin94.github.io/villiage-td/codex/`。

一次性设置：仓库 **Settings → Pages → Build and deployment → Source** 选 **GitHub Actions**。在改成 Actions 之前，原来的「从分支发布 `/docs`」仍然有效；工作流里的部署步骤会失败，直到 Source 改过来。改过来之后不要再把 Source 设回某个分支，否则两套发布会抢。

### Godot 导出不在 CI 里

Godot **4.7.2** 的 Linux 编辑器压缩包在发布页上。配套的 export templates（`Godot_v4.7.2-stable_export_templates.tpz`）大约 **1.28 GB**。每次推送都下载这份模板太重。图鉴和工作台的入口在游戏 HUD 里，不靠 `docs/index.html` 上的外链。

所以 CI **不**重新导出 wasm。`docs/index.js`、`docs/index.wasm`、`docs/index.pck` 和图标是本地导出后提交的。Actions 原样发布它们，只负责重新生成图鉴并上传 `docs/`。

本地导出仍然是：

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

预设 **Web** 的 `include_filter` 要把原始文本打进包：`config/` 里的 JSON、`art/fonts/`、`art/characters/spine/`。贴图走导入资源，不靠这条过滤。过滤仍写旧的 `data/`、`assets/` 时，网页包里没有新路径，线上只会落到已经不存在的回退。

导出预设 **Web** 写着默认路径 `build/web/index.html`，线程和 GDExtension 都是关的。上面的命令把结果直接写进 `docs/`。不要再往 `docs/index.html` 加左上角的景深、压力页、玩法指南链接；这三项从游戏右上角的问号菜单进。

The 4.7.2 export templates are about 1.28 GB. CI deploys the committed web build and regenerates the codex. It does not run Godot. The codex and the workbench are opened from the in-game help menu, not from links pasted onto `docs/index.html`.
