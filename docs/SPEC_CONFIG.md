# 配置规范 / Config spec

可编辑的 JSON 都在 `config/`。二进制图和字体在 [SPEC_ART.md](SPEC_ART.md) 的 `art/`。玩法脚本读这些文件，不再另放一套伤害、射程、攻速表。

Editable JSON lives in `config/`. Binaries live in `art/`. See [SPEC_ART.md](SPEC_ART.md). Scripts load these files and do not keep a second combat table.

## 目录 / Layout

```
config/
  manifest.json                 # config_version + 文件清单
  balance/
    units.json                  # 友方
    enemies.json                # 敌人与十波表
    buildings.json              # 建筑
  layout/
    setup.json                  # 难度、经济、出怪、开局布局
  presentation/
    characters.json             # 序列帧、皮肤、脚、片段
    volumes.json                # 占地。原 data/iso_volumes.json
  schema/                       # 上面每个文件一份 JSON Schema
```

`config/manifest.json` 的 `config_version` 与 `layout/setup.json` 的 `config_version` 相同。清单里的每个 `path` 都要有对应的 `schema`。

旧路径仍可被加载：`data/units.json` 对应 `config/balance/units.json`，`data/iso_volumes.json` 对应 `config/presentation/volumes.json`。新文件在时用新文件。

## 谁读什么 / Who reads what

| 文件 | 游戏 | 图鉴 |
| --- | --- | --- |
| `balance/units.json` | `scripts/balance.gd` | `tools/build_codex.py` |
| `balance/enemies.json` | 同上，含十波 | 同上 |
| `balance/buildings.json` | 同上 | 同上 |
| `layout/setup.json` | 难度、入驻、锁敌、经济、出怪、开局 | 刷新时比对 `config_version` |
| `presentation/characters.json` | `spine_actor.gd` 播序列帧。Balance 只用它把皮肤名换成图序号 | 裁第 0 帧 |
| `presentation/volumes.json` | `iso_volume.gd`。读不到才用脚本里的 `TABLE` | 核对体积键 |

伤害仍是 `max(1, round(attack * 100 / (100 + defense)))`。`attack_speed` 是每秒攻击次数。距离和速度已是世界单位，不要再乘 `IsoVolume.WORLD_SCALE`。击杀只加 `gold_reward`，`wood_reward` 读入后写成 0。十波的数量和曲线写在 `enemies.json` 的 `waves`，不要在脚本里再抄一张波次表。

## 布局 / Layout document

`layout/setup.json` 是开局布局的唯一真相。出怪是 `spawn_rects`：全图只保留一条。`edge` 为 `north` | `south` | `west` | `east`，`middle` 是正中格，`length` 为 3，`width` 为 1。上下沿横轴，左右沿纵轴。四个角不能当正中。`spawns` 由这一个长方形展开，不单独手改。`roads` 是铺在地上的路面格子 `[x, y]`，和怪物寻路无关，只让村民在路上走得更快。出怪口不绑在路面上。设出怪口不会改写路面。缺了 `roads` 时按空数组处理，不会自动铺一条路。

`starter_buildings` 是 `{kind, cell}`，`starter_units` 是 `{unit, cell, sex}`，`starter_props` 是额外的树或岩石 `{kind, cell}`。边上一圈的树和四块固定岩石仍由对局生成。

工作台只改这份配置文档。保存时写成两份本机覆盖：

| 本机文件 | 内容 |
| --- | --- |
| `user://layout.json` | 难度、经济、出怪、开局布局 |
| `user://balance.json` | 单位、敌人、建筑、波次、空缺、木坊产量 |
| `user://setup.json` | 上面两份合成的旧读取口，网页 `localStorage` 的 `vtd.setup` 仍用它 |

没有拆开的旧存档时，仍读 `user://setup.json`。

## 字段 / Fields

id 用 snake_case。显示名不写在 JSON 里，`display_key` 指向 `scripts/locale.gd`。

`units.json` 的每条要有 `id`, `display_key`, `faction`（`ally`）, `role`, `character`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `cost.wood`, `cost.gold`, `train_time`。可选 `skin`, `skins`, `notes`, `intro_key`。`intro_key` 和 `display_key` 一样指向 `scripts/locale.gd`，给右侧单位面板用。

`enemies.json` 根上是 `waves`（正好 10 条）和 `enemies`。每条波次是 `hp`, `speed`, `gap`, `normal`, `fast`, `elite`, `boss`。敌人要有 `id`, `display_key`, `character`, `hp`, `defense`, `attack`, `attack_speed`, `move_speed`, `attack_range`, `scale`, `gold_reward`, `wood_reward`, `tags`。

`buildings.json` 的每条要有 `id`, `kind`, `category`（`recruit` | `production` | `defense`）, `display_key`, `tex`（`res://art/...`）, `hp`, `defense`, `can_attack`, `cost`。`can_attack` 为真时再写 `attack`, `attack_speed`, `attack_range`。

`characters.json` 的每个视觉键要有 `sheets`, `skins`, `frame`, `foot`, `faces_right`, `clips`（至少 `idle` 和 `move`）。可选 `spine`。Spine 运行时仍不打进网页包，职责不变。

`volumes.json` 的键是体积 id。`ellipse` 用 `rx` / `ry`，可加 `ox` / `oy`。`poly` 必须是凸多边形。`z` 是高度。人用 `walker`。

## 校验 / Check

```bash
python3 tools/validate_config.py
```

脚本按 `manifest.json` 用 `config/schema/` 做 JSON Schema 校验，并核对十波、出怪 3×1、体积凸多边形、以及贴图路径能落到文件。
