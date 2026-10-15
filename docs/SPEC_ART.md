# 美术规范 / Art spec

图、字体和可选的 Spine 导出都在 `art/`。数值和布局不放这里，见 [SPEC_CONFIG.md](SPEC_CONFIG.md)。

Pictures, the font, and the optional Spine export live in `art/`. Numbers and layout do not. See [SPEC_CONFIG.md](SPEC_CONFIG.md).

## 目录 / Layout

```
art/
  characters/                   # 单位与敌人的序列帧
    villager_0.png … villager_6.png
    spear.png
    shooter.png
    spine/                      # 可选的 Spine 导出，网页包不包含
  village/                      # 俯视建筑、景物、地面
    house.png farm.png workshop.png wall.png spear.png fire.png
    lumber.png spear_barracks.png gun_barracks.png
    tree.png tree_b.png tree_c.png rock.png
    grass_a.png grass_b.png road.png
  fonts/
    NotoSansSC-Regular.otf
```

不要改已经在用的文件名。地面 `grass_*.png` 和 `road.png` 不进图鉴。新的挡路景物 PNG 要补进 `tools/build_codex.py` 的 `SCENERY_LABELS`。

路径写在配置里，不写在玩法脚本的第二张表里：

| 配置 | 字段 | 例子 |
| --- | --- | --- |
| `config/presentation/characters.json` | `sheets[]`, 可选 `spine.json` / `spine.atlas` | `res://art/characters/villager_0.png` |
| `config/balance/buildings.json` | `tex` | `res://art/village/house.png` |

加载时若 `res://art/...` 不存在，会再试 `res://assets/...`。反过来也一样。仓库里的二进制以 `art/` 为准；`assets/` 只允许作为指向 `art/` 的链接，不要再放一份真正的文件。

## 序列帧 / Sheets

- 一个视觉一张图。村民是一个皮肤一张图。
- 左上角那一格是待机第 0 帧，也是图鉴头像。格子大小来自 `characters.json` 的 `frame`。
- 脚点写在 `foot`，工作台预览和对局都用这一对，不要在编辑器里再量一次。
- 村民和两只哥布林在 `spine_actor.gd` 里用 linear。像素图包才用 nearest。

建筑图是正面俯视，主体不透明，外面透明。体积包住贴地的那一块，见 `config/presentation/volumes.json`。

## 工作台预览 / Workbench preview

地图编辑用 `ActorPainter` 读 presentation 和 `art/`，把贴图画在格子上。出怪格盖红色半透明罩。预览不实例化 `Building` 或 `Villager`。

多选：Ctrl 点格把这一格加进或移出选择；按住右键拖出方框，松开后选中与方框相交的格子。方框会换成新的选择，拖的时候按着 Ctrl 则加进已有选择。多格时铺路、去掉路面和移除作用在全部所选。出怪口仍只设在当前格，并且全图只有一个。左键点一格仍只选这一格并打开右侧面板。左键在空地上拖动仍是平移。右键轻点、没有拖动，仍移除这一格。

## 校验 / Check

```bash
python3 tools/validate_art.py
python3 tools/build_codex.py
```

`validate_art.py` 检查目录、PNG 文件头、字体，以及配置里的 `res://art/` 和 `res://assets/` 都能落到文件。图鉴生成器读 `art/village` 和配置里的序列帧。
