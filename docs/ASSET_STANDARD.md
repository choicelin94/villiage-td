# 资源标准 / Asset standard

友方单位、敌人、建筑，以及会挡住建造的树和岩石，都按这份约定放文件、起 id、填 JSON。图鉴页 [docs/codex/](codex/) 读这些目录，不读 Godot 场景。

Ally units, enemies, buildings, and the trees and rocks that block building follow this layout, these ids, and these JSON fields. The codex at [docs/codex/](codex/) reads the catalogs. It does not read a Godot scene.

对局脚本**还没有**加载 `units.json`、`enemies.json`、`buildings.json`。已经出场的数值仍写在 `scripts/building.gd` 的 `STATS` 和 `scripts/main.gd` 的 `WAVES` / `KIND_MOD` 里。`tools/build_codex.py` 会对照这两处；对不上就拒绝生成图鉴。改已经出场的数值时，脚本和 JSON 一起改，然后重新跑生成器。这份重复是维护债务，架构说明在 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 谁改什么 / Ownership

| 目录 | 放什么 | 维护 |
| --- | --- | --- |
| `data/` | 平衡、目录、体积、形象。只有 JSON。 | 改 id 和数值的人。已出场的数还要改对应脚本。 |
| `assets/` | PNG、字体、可选 Spine。 | 改图的人。不要改已经在用的文件名。 |
| `scripts/` | 玩法，以及仍写死的已出场数值。 | 改行为的人。 |
| `docs/codex/` | 图鉴生成结果。 | 只跑 `python3 tools/build_codex.py`，不要手改。 |
| `docs/index.html` 顶部三个链接 | 导出壳上的手写入口。 | Godot 重新导出后要把「图鉴」、景深、压力页放回去。 |

The match scripts do not load those three catalogs yet. Live numbers still live in `Building.STATS` and in `WAVES` / `KIND_MOD`. The codex builder refuses to run when the JSON disagrees. Change a live number in both places, then regenerate.

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
  units.json                  # 友方
  enemies.json                # 敌人，波次表另放在同一文件
  buildings.json              # 建筑
  iso_volumes.json            # 占地，键是体积 id
```

不要改已经在用的文件名。新文件沿用同一套名字。地面贴图不进图鉴。

Do not rename files the game already loads. New files use the same naming. Ground tiles are not codex cards.

## ID

| 层 Layer | 规则 Rule | 例子 Examples |
| --- | --- | --- |
| 平衡单位 id | snake_case，英文 | `villager`, `spearman`, `engineer` |
| 平衡敌人 id | `{视觉}_{职责}` | `spear_normal`, `spear_fast`, `spear_infected`, `shooter_brute`, `shooter_boss` |
| 平衡建筑 id | snake_case 名词 | `wall`, `spear_tower`, `fire_tower`, `house`, `farm`, `workshop` |
| 建筑 `kind` | 大写枚举，与 Godot `Building.Kind` 一致 | `WALL`, `SPEAR`, `FIRE`, `HOUSE`, `FARM`, `WORKSHOP` |
| 角色视觉键 | `characters.json` 里的 snake_case | `villager`, `spear`, `shooter` |
| 皮肤名 | 小写名词，与图包一致 | `wolf`, `penguin`, `raccoon`, `knight`, `frog`, `robot`, `skeleton`；哥布林为 `default` |
| 体积键 | 通常对齐建筑视觉或 `walker` | `house`, `farm`, `workshop`, `wall`, `spear`, `fire`, `tree`, `rock`, `walker` |
| 文案键 | `unit.*` / `enemy.*` / `build.*` | `unit.villager`, `enemy.spear_normal`, `build.spear` |

建筑 id `spear_tower` 和视觉键 `spear` 不是同一个东西。体积键用视觉那边的短名。`tree_b` 和 `tree_c` 只换贴图，体积键仍是 `tree`。

`spear_tower` is the balance id. `spear` is the visual and the footprint. Tree variants share the `tree` volume.

## 必填字段 / Required fields

距离和速度写**世界像素**。脚本里先写作者值，再乘 `IsoVolume.WORLD_SCALE`（`1.2708197158225134`）。JSON 里记乘完、保留 3 位小数的结果。一格的边长是 `IsoVolume.TILE`（128），近战射程用这个数，不再乘。

`attack_speed` 是两次攻击之间的**秒数**，对应塔的 `cd` 和僵尸的 `_cooldown`。0 表示不攻击。`defense` 是护甲。当前模拟没有减伤，所以全部为 0。建筑脚本里的 `"defense": true` 不是护甲，这里用 `category` 表示那一类。

Distances and speeds are world pixels, already multiplied by `WORLD_SCALE` and rounded to 3 decimals. Melee range is one tile, 128, and is not scaled. `attack_speed` is the delay in seconds. `defense` is armor and is 0 today. A building's old boolean `defense` flag is its `category`, not its armor.

### `units.json` → `units[]`

`id`, `display_key`, `faction`（`ally`）, `role`, `character`, `skin` 和/或 `skins[]`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `cost.wood`, `cost.gold`, `train_time`.

另外：`name.zh`, `name.en` 必须和 `scripts/locale.gd` 里的 `display_key` 一致。`status` 为 `live` 或 `configured`。`volume` 对人是 `walker`。可选 `move_speed_authored` 是乘 `WORLD_SCALE` 之前的数，生成器会检查乘积。

### `enemies.json`

根上有 `world_scale` 和 `waves[]`。每条波次是 `n`, `hp`, `speed`, `gap`, `fast`, `brute`, `boss`，与 `main.gd` 的 `WAVES` 相同。`n` 只数普通尸潮，迅捷、蛮兵和首领另外再加。

`enemies[]`：`id`, `display_key`, `character`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `scale`, `gold_reward`, `wood_reward`, `tags[]`.

`hp` 和 `move_speed` 写**第 1 波**的结果。`hp_mul`, `speed_mul`, `kind` 用来和 `KIND_MOD` 对齐。被感染的村民是 `kind: normal` 再加 `turned`。生命先按普通尸潮取整，再乘 `turned_hp_scale`（0.65）并向零截断，至少 `turned_hp_min`（12）。

形象和职责的对应是固定的：`normal` / `fast` 用 `spear`，`brute` / `boss` 用 `shooter`。感染也走 `spear`。

### `buildings.json` → `buildings[]`

`id`, `kind`, `category`（`recruit` | `production` | `defense`）, `display_key`, `tex`（`res://` 路径）, `hp`, `defense`, `can_attack`, `cost`.

`can_attack` 为真时再写 `attack`, `attack_speed`, `attack_range`, `splash`, `shot_speed`。可选 `beds`, `produces`, `bonus`, `place_cap`, `requires_staff`, `role_key`, `volume`.

| 建筑 id | kind | category | 体积 | 贴图 |
| --- | --- | --- | --- | --- |
| `wall` | `WALL` | defense | `wall` | `wall.png` |
| `spear_tower` | `SPEAR` | defense | `spear` | `spear.png` |
| `fire_tower` | `FIRE` | defense | `fire` | `fire.png` |
| `house` | `HOUSE` | recruit | `house` | `house.png` |
| `farm` | `FARM` | production | `farm` | `farm.png` |
| `workshop` | `WORKSHOP` | production | `workshop` | `workshop.png` |

房屋的 `beds` 在派人之后生效。农场的 `produces.wood` 是清波额外木材。工坊的 `bonus.tower_damage` 是塔伤害倍率，不叠加。木墙 `place_cap` 含开局已经放好的墙。文件根上的 `economy` 是清波底薪：8 木材、14 金币，再加上有人农场。

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
3. 平衡写入 `data/units.json`、`data/enemies.json` 或 `data/buildings.json`，字段见上。
4. 会占地的再写 `data/iso_volumes.json`。多边形或椭圆要包住落地接触，并且是凸的。
5. `scripts/locale.gd` 加上 `display_key`，中文和英文与 `name` 相同。
6. 只有新的建筑 `kind` 才改 `Building.Kind` 和放置逻辑。矛兵和工程师已经在 `units.json` 里，`main.gd` 仍然只调用 `_make_villager`。
7. 运行 `python3 tools/build_codex.py`，提交 `docs/codex/`。

## 出场 / What is spawned

| id | 状态 |
| --- | --- |
| `villager` | 已出场 |
| `spearman`, `engineer` | 配置已有 · 尚未出场 |
| `spear_normal`, `spear_fast`, `spear_infected`, `shooter_brute`, `shooter_boss` | 已出场 |
| `wall`, `spear_tower`, `fire_tower`, `house`, `farm`, `workshop` | 已出场 |
| `tree`, `tree_b`, `tree_c`, `rock` | 已出场，挡建造 |

矛兵和工程师没有自己的序列帧，头像暂用村民皮肤 `knight` 和 `robot`。下面这组数只存在于目录，脚本里没有对应常量。移速暂与村民相同（作者值 108，世界单位 137.249）。防御为 0，因为模拟里还没有护甲。

| id | 形象 | 皮肤 | 生命 | 攻击 | 攻击间隔 | 射程 | 费用 | 训练 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `spearman` | `villager` | `knight` | 64 | 10 | 0.85 秒 | 128 | 10 木 / 16 金 | 5 秒 |
| `engineer` | `villager` | `robot` | 48 | 0 | — | — | 16 木 / 24 金 | 6 秒 |

真的要让他们出场时，把 `status` 改成 `live`，并在 `main.gd` 里生成。生成器在那之前会保持「尚未出场」。

## 图鉴 / Codex

`python3 tools/build_codex.py` 需要 Pillow。它会：

- 用 `characters.json` 的 `frame` 裁每张序列帧的左上角，写成 `docs/codex/thumbs/`
- 建筑和树、岩石用 `assets/village/` 里的 PNG
- 写出 `docs/codex/catalog.json` 和 `docs/codex/index.html`

页面是静态的。推到 `main` 时，GitHub Actions 会再跑一次生成器，并发布整个 `docs/`。入口在游戏页左上角的「图鉴」，和景深、压力页一样。草地 `grass_*.png` 和 `road.png` 不是卡片；新的景物 PNG 要先写进 `tools/build_codex.py` 的 `SCENERY_LABELS`，否则生成器会停下来。发布细节在 [ARCHITECTURE.md](ARCHITECTURE.md)。
