# 资源标准 / Asset standard

友方单位、敌人、建筑，以及会挡住建造的树和岩石，都按这份约定放文件、起 id、填 JSON。图鉴页 [docs/codex/](codex/) 读这些目录，不读 Godot 场景。

Ally units, enemies, buildings, and the trees and rocks that block building follow this layout, these ids, and these JSON fields. The codex at [docs/codex/](codex/) reads the catalogs. It does not read a Godot scene.

对局通过自动加载 `scripts/balance.gd` 读取 `data/units.json`、`data/enemies.json`、`data/buildings.json`。改这三份里的数值，重新开一局就会生效。`data/characters.json` 只描述形象。伤害公式、哪些单位会生成、清波底薪还写在脚本里，见 [ARCHITECTURE.md](ARCHITECTURE.md)。

The match loads those three catalogs through the `Balance` autoload. `characters.json` stays visual. The damage formula, which units spawn, and the flat wave payout stay in scripts. See [ARCHITECTURE.md](ARCHITECTURE.md).

## 谁改什么 / Ownership

| 目录 | 放什么 | 维护 |
| --- | --- | --- |
| `data/` | 平衡、目录、体积、形象。只有 JSON。 | 改 id 和数值的人。 |
| `assets/` | PNG、字体、可选 Spine。 | 改图的人。不要改已经在用的文件名。 |
| `scripts/` | 玩法，以及仍写死的清波底薪、占地后备表。 | 改行为的人。 |
| `docs/codex/` | 图鉴生成结果。 | 只跑 `python3 tools/build_codex.py`，不要手改。 |
| `docs/index.html` | 网页包外壳。 | 不要再手写左上角入口。问号菜单在游戏 HUD。 |

## 目录 / Layout

```
assets/
  characters/                 # 单位与敌人的序列帧
    villager_0.png … villager_6.png
    spear.png
    shooter.png
    spine/                    # 可选的 Spine 导出，网页包不包含
  village/                    # 俯视建筑与景物
    house.png farm.png workshop.png wall.png spear.png fire.png
    tree.png tree_b.png tree_c.png rock.png
    grass_a.png grass_b.png road.png    # 地面，不是图鉴卡片
data/
  characters.json             # 只描述形象：图、皮肤、帧、脚、片段
  units.json                  # 友方。Balance 会读
  enemies.json                # 敌人，波次表在同一文件。Balance 会读
  buildings.json              # 建筑。Balance 会读
  iso_volumes.json            # 占地，键是体积 id
```

不要改已经在用的文件名。新文件沿用同一套名字。地面贴图不进图鉴。

Do not rename files the game already loads. New files use the same naming. Ground tiles are not codex cards.

## ID

| 层 Layer | 规则 Rule | 例子 Examples |
| --- | --- | --- |
| 平衡单位 id | snake_case，英文 | `villager`, `spearman`, `engineer` |
| 平衡敌人 id | `{视觉}_{职责}` | `spear_normal`, `spear_fast`, `spear_infected`, `shooter_elite`, `shooter_boss` |
| 平衡建筑 id | snake_case 名词 | `wall`, `spear_tower`, `fire_tower`, `house`, `farm`, `workshop` |
| 建筑 `kind` | 大写枚举，与 Godot `Building.Kind` 一致 | `WALL`, `SPEAR`, `FIRE`, `HOUSE`, `FARM`, `WORKSHOP` |
| 角色视觉键 | `characters.json` 里的 snake_case | `villager`, `spear`, `shooter` |
| 皮肤名 | 小写名词，与图包一致 | `wolf`, `penguin`, `raccoon`, `knight`, `frog`, `robot`, `skeleton`；哥布林为 `default` |
| 体积键 | 通常对齐建筑视觉或 `walker` | `house`, `farm`, `workshop`, `wall`, `spear`, `fire`, `tree`, `rock`, `walker` |
| 文案键 | `unit.*` / `enemy.*` / `build.*` | `unit.villager`, `enemy.spear_normal`, `enemy.shooter_elite`, `build.spear` |

`Balance._KIND_ALIAS` 把旧的波次种类名接到现在的敌人 id：`normal` → `spear_normal`，`fast` → `spear_fast`，`brute` → `shooter_elite`，`boss` → `shooter_boss`。不要再造一个 `shooter_brute` 目录。

建筑 id `spear_tower` 和视觉键 `spear` 不是同一个东西。体积键用 `building.gd` 的 `_volume_key`：`SPEAR` → `spear`。`tree_b` 和 `tree_c` 只换贴图，体积键仍是 `tree`。

`spear_tower` is the balance id. `spear` is the visual and the footprint. Tree variants share the `tree` volume. The old brute kind is `shooter_elite`.

## 必填字段 / Required fields

距离和速度写**世界单位**，已经乘过 `IsoVolume.WORLD_SCALE`（`1.2708197158225134`）。不要再乘一次。一格的边长是 `IsoVolume.TILE`（128）。近战咬击距离用这个数。

`attack_speed` 是**每秒攻击次数**。矛塔是 `1 / 0.64`，火塔是 `1 / 1.05`，敌人咬击是 `1 / 0.9`。冷却是 `1 / attack_speed`。`defense` 是护甲，伤害为 `max(1, round(attack * 100 / (100 + defense)))`。防御为 0 时，四舍五入后的伤害等于攻击。

显示名不写在 JSON 里。`display_key` 指向 `scripts/locale.gd`。备注字段是 `notes`。

Distances and speeds are already world units. Do not scale them again. `attack_speed` is attacks per second. `defense` is the armor in the damage formula. Display names live in `locale.gd` under `display_key`.

### `units.json` → `units[]`

`id`, `display_key`, `faction`（`ally`）, `role`, `character`, `skin` 和/或 `skins[]`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `cost.wood`, `cost.gold`, `train_time`.

可选 `notes`。人的体积键是 `walker`，不写进这条 JSON。村民的 `skins` 是出场时的外观池（狼、企鹅、浣熊、青蛙、骷髅）。矛兵用 `knight`，工匠用 `robot`，这两张图在 `characters.json` 里，不在村民的外观池里。

`main.gd` 会用 `Balance.unit("villager")`、`Balance.unit("spearman")`、`Balance.unit("gunner")` 和 `Balance.unit("engineer")` 登记这四个 id。村民开局就在场上。矛兵、枪兵、工兵在对应空缺里，于清波时按概率入驻。枪兵用村民序列里的 `raccoon`。

### `enemies.json`

根上有 `waves[]` 和 `enemies[]`。没有单独的 `world_scale` 字段，也没有 `economy`。

每条波次是 `hp`, `speed`, `gap`, `normal`, `fast`, `elite`, `boss`。`hp` 和 `speed` 是这一波的基准。`speed` 还没乘 `WORLD_SCALE`，只用来和第一波做比。数量是这一波各加多少只。

`enemies[]`：`id`, `display_key`, `character`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `scale`, `gold_reward`, `wood_reward`, `tags[]`. 可选 `xp_reward`, `notes`。`wood_reward` 仍留在文件里，但 `Balance` 读入后写成 0。击杀只加 `gold_reward`。

`hp` 和 `move_speed` 写**第 1 波**的世界单位。后面的波次是 `round(hp * wave.hp / waves[0].hp)` 和 `move_speed * wave.speed / waves[0].speed`。`spear_infected` 是单独一条，不再在普通僵尸上再乘 0.65。持枪的精锐 id 是 `shooter_elite`。

### `buildings.json` → `buildings[]`

`id`, `kind`, `category`（`recruit` | `production` | `defense`）, `display_key`, `tex`（`res://` 路径）, `hp`, `defense`, `can_attack`, `cost`.

`can_attack` 为真时再写 `attack`, `attack_speed`, `attack_range`，塔再写 `splash`, `shot_speed`。可选 `beds`, `provides`（`{unit, slots}`，这一类单位的空缺）, `staff_slots`, `produces`（清波是 `{resource, mode: "wave", rate}`；木坊是 `{resource, mode: "staff", rate_per_villager, interval}`；没有就是 `null`）, `recruits[]`, `bonus`（`{tower_damage}`）, `place_cap`, `notes`.

| 建筑 id | kind | category | 体积 | 贴图 |
| --- | --- | --- | --- | --- |
| `wall` | `WALL` | defense | `wall` | `wall.png` |
| `spear_tower` | `SPEAR` | defense | `spear` | `spear.png` |
| `fire_tower` | `FIRE` | defense | `fire` | `fire.png` |
| `house` | `HOUSE` | recruit | `house` | `house.png` |
| `farm` | `FARM` | production | `farm` | `farm.png` |
| `workshop` | `WORKSHOP` | production | `workshop` | `workshop.png` |
| `lumber_mill` | `LUMBER` | production | `lumber` | `lumber.png` |
| `spear_barracks` | `SPEAR_BARRACKS` | recruit | `spear_barracks` | `spear_barracks.png` |
| `gun_barracks` | `GUN_BARRACKS` | recruit | `gun_barracks` | `gun_barracks.png` |

塔立着就会攻击。房屋的 `beds` 与 `provides.slots` 都是村民空缺，盖下不加人。矛兵营、枪兵营、工坊的 `provides` 是对应兵种空缺。农场的 `produces.rate` 是每清一波加的木材，不用派人。木坊按驻守村民数产木，空坊为 0。工坊的 `bonus.tower_damage` 先乘攻击，不叠加。木墙 `place_cap` 含开局已经放好的墙。清波底薪在 `data/setup.json` 的 `economy`，`main.gd` 的 `WAVE_CLEAR_WOOD` 和 `WAVE_CLEAR_GOLD` 只是缺字段时的兜底。难度、出怪长方形、开局人口和 `config_version` 也在 `setup.json`。工作台把覆盖写到 `user://setup.json`。图鉴刷新发现本地 `config_version` 更低时，用出厂配置补齐后再升版本。

### `setup.json` 地图字段（config_version 2）

格子与对局相同：20×20，一格 128，`(0, 0)` 在西北角，`+x` 向东，`+y` 向南。工作台保存的是下面这些字段，开局由 `Balance` 读入。

| 字段 | 含义 |
| --- | --- |
| `spawn_rects[]` | 出怪长方形。每条是 `{edge, middle, length, width}`。`edge` 为 `north` / `south` / `west` / `east`，即最外一圈的上、下、左、右。`middle` 是 `[x, y]`，用户点击的那一格，也是长方形正中。`length` 固定 3，`width` 固定 1。上、下边沿 x 横放，左、右边沿 y 竖放。宽的方向朝内，但只占边上一格，不向地图里面再进一格。四个角 `(0,0)`、`(19,0)`、`(0,19)`、`(19,19)` 不能当正中。 |
| `spawns[]` | 由 `spawn_rects` 展开的出生格 `[x, y]`，重复的格子只留一次。加载时会按长方形重写，不要单独改这一份。 |
| `starter_buildings[]` | 开局建筑 `{kind, cell}`。`kind` 用 `WALL`、`SPEAR`、`FIRE`、`HOUSE`、`FARM`、`WORKSHOP`、`LUMBER`、`SPEAR_BARRACKS`、`GUN_BARRACKS`。`cell` 是内侧空格。 |
| `starter_units[]` | 开局站位 `{unit, cell, sex}`。`unit` 为 `villager`、`spearman`、`gunner`、`engineer`。`sex` 为 `m` 或 `f`。 |
| `starter_props[]` | 额外景物 `{kind, cell}`。`kind` 为 `tree` 或 `rock`，只能放在内侧、不是固定岩石、也不是出怪格的位置。最外圈的林子和四块固定岩石仍由对局生成。 |

The match grid is 20×20 cells of 128. `spawn_rects` is the authored enemy gate: `edge`, `middle` (the clicked center cell), `length` 3, `width` 1. North and south run along x; west and east run along y; the short side points inward and stays on the border. `spawns` is rebuilt from those rects. `starter_buildings`, `starter_units`, and `starter_props` are the opening placements.

### `characters.json`

每个视觉键：`sheets[]`, `skins[]`, `frame` `[宽, 高]`, `foot` `[x, y]`, `faces_right`, `clips`（至少 `idle` 和 `move`）。可选 `spine`。一张图对应一个皮肤时，`sheets` 和 `skins` 等长；哥布林两套都是一张图加 `default`。

| 视觉 | 帧 | 脚 | 朝右为正面 | 图 |
| --- | --- | --- | --- | --- |
| `villager` | 195×182 | (91, 144) | 是 | `villager_0.png` … `villager_6.png` |
| `spear` | 255×206 | (146, 180) | 否 | `spear.png` |
| `shooter` | 298×201 | (153, 170) | 是 | `shooter.png` |

村民片段：`idle` 第 0 行 12 帧，`move` 第 1 行 6 帧，`hurt` 第 2 行 3 帧，`death` 第 3 行 8 帧。持矛：`idle` 8、`move` 8、`attack` 10、`hurt` 2。持枪：`idle` 7、`move` 9、`attack` 10、`hurt` 7、`death` 6。行号从 0 开始。左上角第 0 帧是图鉴头像。

### `iso_volumes.json`

`ellipse` 用 `rx` / `ry`，可加 `ox` / `oy`。`poly` 必须是凸多边形，顶点相对格子中心。`z` 是高度。空心的农场和木墙写成盖住内部的实心凸多边形。人用 `walker`，必须是有面积的椭圆。

`iso_volume.gd` 的 `TABLE` 是同一份体积的后备。JSON 读得到就用 JSON。改体积时两处一起改。

## 序列帧 / Character sheets

- 一个视觉一张图。村民是一个皮肤一张图。
- 左上角那一格是待机第 0 帧，也是图鉴头像。格子大小来自 `frame`。
- 脚点已经对过，不要随手改。
- 能排成 2 的幂更省，但现在这三张图是导出的帧网格，没有补成 2 的幂。
- 像素图包用 nearest。现在的村民和两只哥布林在 `spine_actor.gd` 里都是 linear。

图鉴缩略图会把这一格四周的透明边裁掉，方便卡片显示。逻辑上的头像区域仍然是整格。

## 建筑图 / Building PNGs

- 正面俯视，主体不透明，外面透明。
- 文件名是 `tex` 的文件名，并尽量和体积键同一族（`spear.png` 对体积 `spear`）。
- 体积必须包住贴地的那一块，而且是凸的。不要按屋顶或树冠去描碰撞。

## 新实体怎么接 / Adding an entity

1. 先放图。角色一张序列帧，或村民再加一张皮肤。建筑一张俯视 PNG。不要改旧文件名。
2. 角色写入 `data/characters.json`：`sheets`, `skins`, `frame`, `foot`, `faces_right`, `clips`。
3. 平衡写入 `data/units.json`、`data/enemies.json` 或 `data/buildings.json`，字段见上。对局已经会读这三份。
4. 会占地的再写 `data/iso_volumes.json`，并更新 `iso_volume.gd` 的 `TABLE` 后备。多边形或椭圆要包住落地接触，并且是凸的。
5. `scripts/locale.gd` 加上 `display_key`。
6. 只有新的建筑 `kind` 才改 `Building.Kind`、`_volume_key` 和放置逻辑。矛兵和工匠已经在 `units.json` 里，`main.gd` 仍然只调用 `Balance.unit("villager")`。
7. 运行 `python3 tools/build_codex.py`，提交 `docs/codex/`。

## 出场 / What is spawned

| id | 状态 |
| --- | --- |
| `villager` | 已出场 |
| `spearman`, `engineer` | 配置已有 · 尚未出场 |
| `spear_normal`, `spear_fast`, `spear_infected`, `shooter_elite`, `shooter_boss` | 已出场 |
| `wall`, `spear_tower`, `fire_tower`, `house`, `farm`, `workshop` | 已出场 |
| `tree`, `tree_b`, `tree_c`, `rock` | 已出场，挡建造 |

矛兵和工匠没有自己的序列帧，头像用村民皮肤 `knight`（`villager_3`）和 `robot`（`villager_5`）。他们的生命、防御、攻击和费用都在 `units.json` 里，由 Balance 读到，只是对局还不会生成。图鉴是否标「尚未出场」，看 `main.gd` 里有没有对应的 `Balance.unit("…")` 调用。

## 图鉴 / Codex

`python3 tools/build_codex.py` 需要 Pillow。它会：

- 用 `characters.json` 的 `frame` 裁每张序列帧的左上角，写成 `docs/codex/thumbs/`
- 建筑和树、岩石用 `assets/village/` 里的 PNG
- 写出 `docs/codex/catalog.json` 和 `docs/codex/index.html`

页面是静态的。推到 `main` 时，GitHub Actions 会再跑一次生成器，并发布整个 `docs/`。游戏里右上角问号菜单的「玩法指南」打开这一页。草地 `grass_*.png` 和 `road.png` 不是卡片；新的景物 PNG 要先写进 `tools/build_codex.py` 的 `SCENERY_LABELS`，否则生成器会停下来。发布细节在 [ARCHITECTURE.md](ARCHITECTURE.md)。
