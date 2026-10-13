#!/usr/bin/env python3
"""Regenerate the static Codex from the balance JSON the match already loads.

Run from anywhere:

    python3 tools/build_codex.py

Requires Pillow. Writes docs/codex/index.html, catalog.json, and thumbs/.
Stats come from data/units.json, data/enemies.json, and data/buildings.json,
the same files scripts/balance.gd reads. Names come from scripts/locale.gd.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("build_codex.py needs Pillow. Install it with: pip install pillow")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "codex"
THUMBS = OUT / "thumbs"
RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS

REQUIRED_UNITS = {"villager", "spearman", "engineer"}
REQUIRED_ENEMIES = {
    "spear_normal",
    "spear_fast",
    "spear_infected",
    "shooter_elite",
    "shooter_boss",
}
REQUIRED_BUILDINGS = {
    "wall",
    "spear_tower",
    "fire_tower",
    "house",
    "farm",
    "workshop",
}
UNIT_FIELDS = (
    "id",
    "display_key",
    "faction",
    "role",
    "character",
    "hp",
    "defense",
    "attack",
    "attack_speed",
    "move_speed",
    "attack_range",
    "cost",
    "train_time",
)
ENEMY_FIELDS = (
    "id",
    "display_key",
    "character",
    "hp",
    "defense",
    "attack",
    "attack_speed",
    "move_speed",
    "attack_range",
    "scale",
    "gold_reward",
    "wood_reward",
    "tags",
)
BUILDING_FIELDS = (
    "id",
    "kind",
    "category",
    "display_key",
    "tex",
    "hp",
    "defense",
    "can_attack",
    "cost",
)
CATEGORIES = {"recruit", "production", "defense"}
GROUND_TILES = {"grass_a.png", "grass_b.png", "road.png"}
# id, Chinese, English, iso volume, note
SCENERY_LABELS = {
    "tree.png": (
        "tree",
        "树",
        "Tree",
        "tree",
        "已出场。树干落地的那一块椭圆挡建造。树冠不参与碰撞。",
    ),
    "tree_b.png": (
        "tree_b",
        "树 · 变体 B",
        "Tree B",
        "tree",
        "已出场。贴图变体，体积键仍是 tree。",
    ),
    "tree_c.png": (
        "tree_c",
        "树 · 变体 C",
        "Tree C",
        "tree",
        "已出场。贴图变体，体积键仍是 tree。",
    ),
    "rock.png": (
        "rock",
        "岩石",
        "Rock",
        "rock",
        "已出场。椭圆体积挡建造。",
    ),
}
ROLE_ZH = {"worker": "劳工", "melee": "近战", "support": "支援"}
CATEGORY_ZH = {"recruit": "招募", "production": "生产", "defense": "防御"}
TAG_ZH = {
    "normal": "普通",
    "horde": "尸潮",
    "spear": "持矛",
    "fast": "迅捷",
    "infected": "感染",
    "elite": "精锐",
    "shooter": "持枪",
    "brute": "蛮兵",
    "boss": "首领",
}
PEOPLE_VOLUME = "walker"
WAVE_FIELDS = ("hp", "speed", "gap", "normal", "fast", "elite", "boss")
# Display groups for the codex wave panel. Keys must match WAVE_FIELDS.
# Counts are how many of that kind spawn; hp/speed/gap are the wave's baselines.
WAVE_GROUPS = (
    (
        "counts",
        "本波出场",
        (
            ("normal", "普通", "普通僵尸"),
            ("fast", "迅捷", "迅捷僵尸"),
            ("elite", "精锐", "持枪精锐"),
            ("boss", "首领", "本波首领"),
        ),
    ),
    (
        "scale",
        "缩放基准",
        (
            ("hp", "基准生命", "和第 1 波的生命比"),
            ("speed", "基准移速", "还没乘 WORLD_SCALE"),
            ("gap", "间隔", "出怪间隔，秒"),
        ),
    ),
)
WAVE_FOOTNOTE = (
    "卡片上的生命和移速已经是第 1 波的世界单位。后面每一波按相对第 1 波的比例缩放："
    "生命取 round(卡片生命 × 本波基准生命 / 第 1 波基准生命)，"
    "移速取卡片移速 × 本波基准移速 / 第 1 波基准移速。"
    "这里的基准移速还没有乘 WORLD_SCALE，它只用来算这个比例。"
    "被感染的村民是单独的 spear_infected，不再在普通僵尸上再乘 0.65。"
)


def die(message: str) -> None:
    sys.exit(f"build_codex: {message}")


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        die(f"missing {path.relative_to(ROOT)}")
    except json.JSONDecodeError as exc:
        die(f"{path.relative_to(ROOT)} is not valid JSON ({exc})")


def res_path(res: str) -> Path:
    if not str(res).startswith("res://"):
        die(f"expected a res:// path, got {res}")
    path = ROOT / str(res)[len("res://") :]
    if not path.is_file():
        die(f"missing file for {res}")
    return path


def require_fields(entry: dict, fields: tuple, label: str) -> None:
    missing = [name for name in fields if name not in entry]
    if missing:
        die(f"{label} missing {', '.join(missing)}")
    if "cost" in fields:
        cost = entry["cost"]
        if not isinstance(cost, dict) or "wood" not in cost or "gold" not in cost:
            die(f"{label} cost needs wood and gold")


def parse_locale(text: str) -> dict:
    pattern = re.compile(
        r'"((?:unit|enemy|build|role)\.[^"]+)":\s*\{\s*'
        r'"zh":\s*"((?:\\.|[^"\\])*)"\s*,\s*'
        r'"en":\s*"((?:\\.|[^"\\])*)"',
        re.S,
    )
    return {key: {"zh": zh, "en": en} for key, zh, en in pattern.findall(text)}


def read_const(text: str, name: str) -> float:
    match = re.search(rf"const {name} := ([\d.]+)", text)
    if not match:
        die(f"missing const {name}")
    return float(match.group(1))


def volume_by_kind(text: str) -> dict:
    found = re.findall(r'Kind\.([A-Z_]+):\s*return "([a-z_]+)"', text)
    if len(found) < 6:
        die("could not read Building._volume_key")
    return {kind: key for kind, key in found}


def spawned_unit_ids(text: str) -> set:
    return set(re.findall(r'Balance\.unit\(\s*"([A-Za-z0-9_]+)"\s*\)', text))


def kind_aliases(text: str) -> dict:
    found = re.findall(
        r'"(normal|fast|brute|boss)":\s*"(spear_[A-Za-z0-9_]+|shooter_[A-Za-z0-9_]+)"',
        text,
    )
    if len(found) < 4:
        die("could not read Balance._KIND_ALIAS")
    return {kind: enemy_id for kind, enemy_id in found}


def fmt_num(value) -> str:
    number = float(value)
    nearest = round(number)
    if abs(number - nearest) < 1e-9:
        return str(int(nearest))
    return f"{number:.4f}".rstrip("0").rstrip(".")


def fmt_cost(cost: dict) -> str:
    parts = []
    if cost.get("wood"):
        parts.append(f"{int(cost['wood'])} 木")
    if cost.get("gold"):
        parts.append(f"{int(cost['gold'])} 金")
    return " + ".join(parts) if parts else "无"


def fmt_rate(value) -> str:
    if float(value) == 0:
        return "—"
    return f"{fmt_num(value)} 次/秒"


def fmt_distance(value) -> str:
    if float(value) == 0:
        return "—"
    return fmt_num(value)


def stat(label: str, value: str) -> dict:
    return {"k": label, "v": value}


def apply_names(entry: dict, locale: dict) -> None:
    key = entry["display_key"]
    row = locale.get(key)
    if row is None:
        die(f"{entry['id']} display_key {key} is missing from scripts/locale.gd")
    name = entry.get("name")
    if isinstance(name, dict) and (row["zh"] != name.get("zh") or row["en"] != name.get("en")):
        die(
            f"{key} disagrees with locale.gd "
            f"({name.get('zh')}/{name.get('en')} vs {row['zh']}/{row['en']})"
        )
    entry["name"] = {"zh": row["zh"], "en": row["en"]}
    if entry.get("note") in (None, "") and entry.get("notes"):
        entry["note"] = str(entry["notes"])


def portrait_from_sheet(sheet: Path, frame: list, dest: Path) -> None:
    image = Image.open(sheet).convert("RGBA")
    width, height = image.size
    frame_w, frame_h = int(frame[0]), int(frame[1])
    if frame_w <= 0 or frame_h <= 0 or width % frame_w or height % frame_h:
        die(f"{sheet.name} is {width}×{height}, not a grid of {frame_w}×{frame_h}")
    cell = image.crop((0, 0, frame_w, frame_h))
    save_thumb(cell, dest)


def save_thumb(image: Image.Image, dest: Path) -> None:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    mask = alpha.point(lambda px: 255 if px > 8 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        die(f"portrait for {dest.name} is fully transparent")
    trimmed = image.crop(bbox)
    pad = max(4, int(max(trimmed.size) * 0.08))
    padded = Image.new(
        "RGBA",
        (trimmed.width + pad * 2, trimmed.height + pad * 2),
        (0, 0, 0, 0),
    )
    padded.paste(trimmed, (pad, pad))
    padded.thumbnail((280, 280), RESAMPLE)
    canvas = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
    canvas.paste(
        padded,
        ((320 - padded.width) // 2, (320 - padded.height) // 2),
        padded,
    )
    if canvas.getchannel("A").getextrema()[1] == 0:
        die(f"portrait for {dest.name} is fully transparent")
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG", optimize=True)


def portrait_skins(entry: dict, spec: dict) -> list:
    listed = entry.get("skins")
    if isinstance(listed, list) and listed:
        return [str(name) for name in listed]
    skin = entry.get("skin")
    if skin:
        return [str(skin)]
    catalog = spec.get("skins") or []
    if catalog:
        return [str(catalog[0])]
    die(f"{entry['id']} has no skin and {entry.get('character')} has no skins")
    return []


def sheet_for(spec: dict, skin: str) -> str:
    skins = spec["skins"]
    if skin not in skins:
        die(f"skin {skin} is not in {skins}")
    sheets = spec["sheets"]
    if len(sheets) == 1:
        return sheets[0]
    if len(sheets) != len(skins):
        die("character sheets and skins differ in length")
    return sheets[skins.index(skin)]


def bind_entry(entry: dict, characters: dict, volumes: dict, locale: dict, volume: str) -> dict:
    apply_names(entry, locale)
    if volume not in volumes:
        die(f"{entry['id']} volume {volume} is missing from iso_volumes.json")
    entry["volume"] = volume
    visual = entry.get("character")
    if visual is None:
        return {}
    if visual not in characters:
        die(f"{entry['id']} character {visual} is missing from characters.json")
    spec = characters[visual]
    for key in ("sheets", "skins", "frame", "foot", "faces_right", "clips"):
        if key not in spec:
            die(f"characters.json {visual} missing {key}")
    for name in portrait_skins(entry, spec):
        if name not in spec["skins"]:
            die(f"{entry['id']} skin {name} is not on {visual}")
    return spec


def make_character_thumbs(entry: dict, spec: dict) -> list:
    frame = spec["frame"]
    skins = portrait_skins(entry, spec)
    made = []
    for skin in skins:
        dest = THUMBS / f"{entry['id']}__{skin}.png"
        portrait_from_sheet(res_path(sheet_for(spec, skin)), frame, dest)
        made.append({"name": skin, "thumb": f"thumbs/{dest.name}"})
    primary = entry.get("skin") or skins[0]
    primary_src = THUMBS / f"{entry['id']}__{primary}.png"
    shutil.copyfile(primary_src, THUMBS / f"{entry['id']}.png")
    return made


def badge_for(status: str) -> tuple:
    if status == "configured":
        return "配置已有 · 尚未出场", "soon"
    if status == "live":
        return "已出场", "live"
    die(f"unknown status {status}")
    return "", ""


def unit_card(entry: dict, skins: list, spawned: bool) -> dict:
    badge, tone = badge_for("live" if spawned else "configured")
    role = ROLE_ZH.get(entry["role"], entry["role"])
    stats = [
        stat("职责", f"{role} · {entry['role']}"),
        stat("生命", fmt_num(entry["hp"])),
        stat("防御", fmt_num(entry["defense"])),
        stat("攻击", fmt_num(entry["attack"])),
        stat("攻速", fmt_rate(entry["attack_speed"])),
        stat("移速", fmt_num(entry["move_speed"])),
        stat("射程", fmt_distance(entry["attack_range"])),
        stat("费用", fmt_cost(entry["cost"])),
        stat("训练", "—" if float(entry["train_time"]) == 0 else f"{fmt_num(entry['train_time'])} 秒"),
        stat("形象", entry["character"]),
        stat("体积", entry["volume"]),
    ]
    return card(entry, "units", badge, tone, stats, skins)


def enemy_card(entry: dict, skins: list) -> dict:
    badge, tone = badge_for("live")
    tags = " · ".join(TAG_ZH.get(tag, tag) for tag in entry["tags"])
    stats = [
        stat("生命", f"{fmt_num(entry['hp'])}（第 1 波）"),
        stat("防御", fmt_num(entry["defense"])),
        stat("攻击", fmt_num(entry["attack"])),
        stat("攻速", fmt_rate(entry["attack_speed"])),
        stat("移速", f"{fmt_num(entry['move_speed'])}（第 1 波）"),
        stat("射程", fmt_distance(entry["attack_range"])),
        stat("体型", f"×{fmt_num(entry['scale'])}"),
        stat("赏金", f"{int(entry['gold_reward'])} 金"),
        stat("木材", f"{int(entry['wood_reward'])} 木"),
    ]
    if int(entry.get("xp_reward") or 0):
        stats.append(stat("经验", str(int(entry["xp_reward"]))))
    stats.extend(
        [
            stat("标签", tags),
            stat("形象", entry["character"]),
            stat("体积", entry["volume"]),
        ]
    )
    return card(entry, "enemies", badge, tone, stats, skins)


def building_role(entry: dict, locale: dict) -> str:
    key = str(entry.get("display_key", ""))
    role_key = "role." + key.split(".", 1)[1] if key.startswith("build.") else ""
    role = locale.get(role_key, {})
    category = CATEGORY_ZH.get(entry["category"], entry["category"])
    if role:
        return f"{role['zh']} · {category}"
    return category


def recruit_names(ids: list, locale: dict) -> str:
    labels = []
    for unit_id in ids:
        row = locale.get(f"unit.{unit_id}")
        labels.append(row["zh"] if row else str(unit_id))
    return "、".join(labels)


def building_card(entry: dict, locale: dict) -> dict:
    badge, tone = badge_for("live")
    stats = [
        stat("类别", building_role(entry, locale)),
        stat("种类", entry["kind"]),
        stat("生命", fmt_num(entry["hp"])),
        stat("防御", fmt_num(entry["defense"])),
        stat("费用", fmt_cost(entry["cost"])),
    ]
    if entry["can_attack"]:
        stats.append(stat("攻击", fmt_num(entry["attack"])))
        stats.append(stat("攻速", fmt_rate(entry["attack_speed"])))
        stats.append(stat("射程", fmt_distance(entry["attack_range"])))
        if "splash" in entry:
            stats.append(stat("溅射", fmt_num(entry["splash"])))
        if "shot_speed" in entry:
            stats.append(stat("弹速", fmt_num(entry["shot_speed"])))
    if int(entry.get("beds") or 0) > 0:
        stats.append(stat("床位", str(int(entry["beds"]))))
    produces = entry.get("produces")
    if isinstance(produces, dict) and produces.get("rate") is not None:
        resource = {"wood": "木", "gold": "金"}.get(str(produces.get("resource", "")), str(produces.get("resource", "")))
        stats.append(stat("产出", f"每波 +{fmt_num(produces['rate'])} {resource}"))
    recruits = entry.get("recruits") or []
    if recruits:
        stats.append(stat("可招募", recruit_names(recruits, locale)))
    bonus = entry.get("bonus")
    if isinstance(bonus, dict) and bonus.get("tower_damage") is not None:
        stats.append(stat("加成", f"塔攻击 ×{fmt_num(bonus['tower_damage'])}"))
    if int(entry.get("place_cap") or 0) > 0:
        stats.append(stat("上限", str(int(entry["place_cap"]))))
    stats.append(stat("体积", entry["volume"]))
    portrait = THUMBS / f"{entry['id']}.png"
    save_thumb(Image.open(res_path(entry["tex"])), portrait)
    return card(entry, "buildings", badge, tone, stats, [])


def scenery_cards(building_names: set, volumes: dict) -> list:
    village = ROOT / "assets" / "village"
    pngs = {path.name for path in village.glob("*.png")}
    props = pngs - GROUND_TILES - building_names
    if props != set(SCENERY_LABELS):
        die(
            "scenery PNG set changed. Update SCENERY_LABELS in tools/build_codex.py. "
            f"Found {sorted(props)}"
        )
    cards = []
    for filename, (sid, zh, en, volume, note) in SCENERY_LABELS.items():
        if volume not in volumes:
            die(f"scenery {sid} volume {volume} is missing")
        portrait = THUMBS / f"{sid}.png"
        save_thumb(Image.open(village / filename), portrait)
        entry = {"id": sid, "name": {"zh": zh, "en": en}, "note": note, "volume": volume}
        stats = [
            stat("体积", volume),
            stat("贴图", filename),
            stat("建造", "不能"),
        ]
        cards.append(card(entry, "scenery", "挡建造", "scene", stats, []))
    return cards


def card(entry: dict, section: str, badge: str, tone: str, stats: list, skins: list) -> dict:
    shown = skins if len(skins) > 1 else []
    return {
        "id": entry["id"],
        "section": section,
        "name_zh": entry["name"]["zh"],
        "name_en": entry["name"]["en"],
        "portrait": f"thumbs/{entry['id']}.png",
        "badge": badge,
        "badge_tone": tone,
        "stats": stats,
        "note": entry.get("note", ""),
        "skins": shown,
        "volume": entry.get("volume", ""),
    }


def wave_rows(waves: list) -> list:
    rows = []
    for index, wave in enumerate(waves, start=1):
        rows.append(
            {
                "wave": index,
                "normal": int(wave["normal"]),
                "hp": wave["hp"],
                "speed": wave["speed"],
                "gap": wave["gap"],
                "fast": int(wave["fast"]),
                "elite": int(wave["elite"]),
                "boss": int(wave["boss"]),
            }
        )
    return rows


def render_page(catalog: dict) -> str:
    sections = {
        "units": ("友方单位", "Units", "村民会出场。矛兵和工匠已写入 Balance，对局还不会生成。"),
        "enemies": ("敌人", "Enemies", "卡片是第 1 波的世界单位。波次说明在卡片下面，一次只看一波。"),
        "buildings": ("建筑", "Buildings", "塔立着就会攻击，不用派人。房屋立着就给床位，农场立着就产木材。"),
        "scenery": ("场景", "Scenery", "树和岩石挡住建造。草地和道路是地面，不进图鉴。"),
    }
    nav = []
    blocks = []
    wave_css = ""
    for key, (zh, en, blurb) in sections.items():
        nav.append(f'<a href="#{key}">{esc(zh)}</a>')
        items = [render_card(item) for item in catalog["sections"][key]]
        extra = ""
        if key == "enemies":
            nav.append('<a href="#waves">波次</a>')
            extra, wave_css = render_waves(catalog["waves"])
        if key == "buildings":
            extra = render_economy(catalog["economy"])
        blocks.append(
            f'<section id="{key}">'
            f"<header><h2>{esc(zh)} <span>{esc(en)}</span></h2><p>{esc(blurb)}</p></header>"
            f'<div class="grid">{"".join(items)}</div>{extra}</section>'
        )
    counts = catalog["counts"]
    total = sum(counts.values())
    summary = (
        f"{counts['units']} 个友方 · {counts['enemies']} 个敌人 · "
        f"{counts['buildings']} 座建筑 · {counts['scenery']} 个场景"
    )
    return f"""<!DOCTYPE html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>图鉴 · 部落村落塔防</title>
<meta name="description" content="部落村落塔防的友方单位、敌人和建筑图鉴。">
<link rel="icon" href="thumbs/villager.png">
<style>
:root {{
  color-scheme: dark;
  --bg: #141a14;
  --card: #222c22;
  --line: #3d4d39;
  --text: #f4f0e4;
  --muted: #b7b39a;
  --gold: #e6c56a;
  --live-bg: #1e6b45;
  --live-ink: #e7fff1;
  --soon-bg: #8a5a16;
  --soon-ink: #fff3d8;
  --scene-bg: #24506a;
  --scene-ink: #e7f6ff;
  --well: #1a261c;
  --chip: #2c382c;
  --shadow: 0 12px 28px rgba(0, 0, 0, .28);
}}
@media (prefers-color-scheme: light) {{
  :root {{
    color-scheme: light;
    --bg: #f4f0e6;
    --card: #fffdf8;
    --line: #e2d6c0;
    --text: #1d2418;
    --muted: #5c6556;
    --gold: #8a5a12;
    --live-bg: #d9f5e4;
    --live-ink: #145c38;
    --soon-bg: #fff1d6;
    --soon-ink: #7a4e0d;
    --scene-bg: #d9edf8;
    --scene-ink: #18445c;
    --well: #e5f0df;
    --chip: #f6efe2;
    --shadow: 0 10px 24px rgba(70, 50, 10, .08);
  }}
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 16px/1.5 "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Noto Sans SC", "Microsoft YaHei", sans-serif;
}}
a {{ color: var(--gold); }}
header.top, main {{ width: min(1120px, calc(100% - 32px)); margin: 0 auto; }}
header.top {{ padding: 28px 0 8px; }}
.kicker {{ margin: 0; color: var(--muted); letter-spacing: .08em; font-size: 13px; }}
h1 {{ margin: 4px 0; font-size: clamp(32px, 5vw, 48px); line-height: 1.1; }}
.summary {{ margin: 0 0 8px; color: var(--muted); }}
nav {{ display: flex; flex-wrap: wrap; gap: 8px; margin: 16px 0 8px; }}
nav a {{
  text-decoration: none;
  background: var(--chip);
  color: var(--text);
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 6px 12px;
}}
section {{ margin: 28px 0 36px; }}
section > header h2 {{ margin: 0; font-size: 28px; }}
section > header h2 span {{ color: var(--muted); font-size: 16px; font-weight: 500; }}
section > header p {{ margin: 6px 0 14px; color: var(--muted); }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 14px; }}
article {{
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: 18px;
  box-shadow: var(--shadow);
  padding: 12px;
  min-width: 0;
}}
.portrait {{
  background: radial-gradient(circle at 50% 78%, #3e5c3c, var(--well) 68%);
  border-radius: 14px;
  aspect-ratio: 1;
  display: grid;
  place-items: center;
}}
.portrait img {{ width: 88%; height: 88%; object-fit: contain; }}
.skins {{ display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }}
.skins img {{
  width: 42px; height: 42px; object-fit: contain;
  background: var(--well); border-radius: 8px; border: 1px solid var(--line);
}}
h3 {{ margin: 10px 0 0; font-size: 22px; }}
.en, .wid, .note {{ margin: 0; color: var(--muted); }}
.wid {{ font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 13px; }}
.badge {{
  display: inline-block; margin-top: 8px; border-radius: 999px;
  padding: 2px 8px; font-size: 12px; font-weight: 650;
}}
.badge.live {{ background: var(--live-bg); color: var(--live-ink); }}
.badge.soon {{ background: var(--soon-bg); color: var(--soon-ink); }}
.badge.scene {{ background: var(--scene-bg); color: var(--scene-ink); }}
dl {{
  display: grid; grid-template-columns: auto 1fr; gap: 3px 12px;
  margin: 10px 0 0; font-size: 14px;
}}
dt {{ color: var(--muted); }}
dd {{ margin: 0; text-align: right; }}
.note {{ margin-top: 8px; font-size: 13px; }}
.table-wrap {{ overflow-x: auto; border: 1px solid var(--line); border-radius: 14px; }}
table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
th, td {{ padding: 8px 10px; text-align: right; white-space: nowrap; }}
th:first-child, td:first-child {{ text-align: left; }}
th {{ color: var(--muted); font-weight: 600; }}
tr + tr td, tr + tr th {{ border-top: 1px solid var(--line); }}
.callout, .footnote {{ color: var(--muted); font-size: 14px; }}
.callout {{
  margin-top: 14px; padding: 12px 14px; border-radius: 14px;
  background: var(--chip); border: 1px solid var(--line);
}}
footer {{ width: min(1120px, calc(100% - 32px)); margin: 0 auto 32px; color: var(--muted); font-size: 13px; }}
a:focus-visible {{ outline: 2px solid var(--gold); outline-offset: 2px; }}
{wave_css}
</style>
</head>
<body>
<header class="top">
  <p class="kicker">部落村落塔防</p>
  <h1>图鉴</h1>
  <p class="summary">{esc(summary)}，共 {total} 张。</p>
  <nav>{"".join(nav)}<a href="../">返回游戏</a></nav>
</header>
<main>
{"".join(blocks)}
</main>
<footer>
  <p>头像是序列帧左上角第 0 帧，或建筑的俯视图，透明边已裁掉。数值来自 data/units.json、data/enemies.json、data/buildings.json，对局由 scripts/balance.gd 加载同一份。攻速是每秒攻击次数。伤害是 max(1, round(attack × 100 / (100 + defense)))。移速、射程、溅射和弹速是世界单位。卡片上的小数最多显示 4 位。</p>
  <p>此页由 tools/build_codex.py 生成。改目录后重新运行脚本，再提交 docs/codex/。</p>
</footer>
</body>
</html>
"""


def render_card(item: dict) -> str:
    stats = "".join(f"<dt>{esc(row['k'])}</dt><dd>{esc(row['v'])}</dd>" for row in item["stats"])
    skins = ""
    if item["skins"]:
        thumbs = "".join(
            f'<img src="{esc(skin["thumb"])}" alt="{esc(item["name_zh"])} {esc(skin["name"])}">'
            for skin in item["skins"]
        )
        skins = f'<div class="skins">{thumbs}</div>'
    note = f'<p class="note">{esc(item["note"])}</p>' if item["note"] else ""
    return (
        "<article>"
        f'<div class="portrait"><img src="{esc(item["portrait"])}" alt="{esc(item["name_zh"])}头像"></div>'
        f"{skins}"
        f'<h3>{esc(item["name_zh"])}</h3>'
        f'<p class="en">{esc(item["name_en"])}</p>'
        f'<p class="wid">{esc(item["id"])}</p>'
        f'<span class="badge {esc(item["badge_tone"])}">{esc(item["badge"])}</span>'
        f"<dl>{stats}</dl>"
        f"{note}"
        "</article>"
    )


def _wave_columns() -> list:
    columns = []
    seen = set()
    for group, _title, cols in WAVE_GROUPS:
        for key, label, hint in cols:
            if key in seen:
                die(f"duplicate wave column {key}")
            seen.add(key)
            columns.append((group, key, label, hint))
    if seen != set(WAVE_FIELDS):
        die(f"wave columns {sorted(seen)} do not match WAVE_FIELDS")
    return columns


def _wave_css(count: int) -> str:
    show = []
    selected = []
    focused = []
    for index in range(1, count + 1):
        show.append(
            f"#wave-pick-{index}:checked ~ .wave-panel[data-wave=\"{index}\"] {{ display: block; }}"
        )
        selected.append(f"#wave-pick-{index}:checked ~ .wave-tabs label[for=\"wave-pick-{index}\"]")
        focused.append(
            f"#wave-pick-{index}:focus-visible ~ .wave-tabs label[for=\"wave-pick-{index}\"]"
        )
    hide = []
    for _group, key, _label, _hint in _wave_columns():
        hide.append(
            f".waves:not(:has(#col-{key}:checked)) [data-col=\"{key}\"] {{ display: none; }}"
        )
    group_hide = []
    for group, _title, cols in WAVE_GROUPS:
        chain = "".join(f":not(:has(#col-{key}:checked))" for key, _label, _hint in cols)
        group_hide.append(f".waves{chain} [data-group=\"{group}\"] {{ display: none; }}")
    return (
        WAVE_PANEL_CSS
        + "\n"
        + "\n".join(show)
        + "\n"
        + ",\n".join(selected)
        + " {\n"
        "  background: var(--text);\n"
        "  color: var(--bg);\n"
        "  border-color: transparent;\n"
        "  font-weight: 700;\n"
        "}\n"
        + ",\n".join(focused)
        + " {\n"
        "  outline: 2px solid var(--gold);\n"
        "  outline-offset: 2px;\n"
        "}\n"
        + "\n".join(hide)
        + "\n"
        + "\n".join(group_hide)
        + "\n"
        ".waves:not(:has(#col-hp:checked)):not(:has(#col-speed:checked)) .wave-scale { display: none; }\n"
        ".waves:not(:has(.wave-col input:checked)) .wave-empty { display: block; }\n"
        ".waves:not(:has(.wave-col input:checked)) .wave-group { display: none; }\n"
    )


def render_waves(rows: list) -> tuple:
    """One tab per wave, plus a column picker that stays outside the tabs.

    Rows come from data/enemies.json via wave_rows(). Column keys are WAVE_GROUPS,
    checked against WAVE_FIELDS so the picker cannot drift from the match data.
    """
    if not rows:
        die("waves are empty")
    _wave_columns()
    ref = rows[0]
    ref_hp = float(ref["hp"]) or 1.0
    ref_speed = float(ref["speed"]) or 1.0
    picks = []
    tabs = []
    panels = []
    for row in rows:
        number = int(row["wave"])
        checked = " checked" if number == int(rows[0]["wave"]) else ""
        picks.append(
            f'<input class="wave-pick" type="radio" name="wave-pick" '
            f'id="wave-pick-{number}" aria-controls="wave-panel-{number}"{checked}>'
        )
        tabs.append(f'<label for="wave-pick-{number}">第 {number} 波</label>')
        hp_ratio = float(row["hp"]) / ref_hp
        speed_ratio = float(row["speed"]) / ref_speed
        groups = []
        for group, title, cols in WAVE_GROUPS:
            stats = []
            for key, label, hint in cols:
                value = row[key]
                mark = ""
                if group == "counts":
                    mark = " is-present" if int(value) > 0 else " is-zero"
                stats.append(
                    f'<div class="wave-stat{mark}" data-col="{esc(key)}">'
                    f"<dt>{esc(label)}</dt>"
                    f"<dd><span class=\"wave-num\">{esc(fmt_num(value))}</span>"
                    f'<span class="hint">{esc(hint)}</span></dd></div>'
                )
            groups.append(
                f'<section class="wave-group" data-group="{esc(group)}">'
                f"<h4>{esc(title)}</h4>"
                f'<dl class="wave-stats">{"".join(stats)}</dl></section>'
            )
        panels.append(
            f'<article class="wave-panel" id="wave-panel-{number}" data-wave="{number}">'
            f"<h3>第 {number} 波</h3>"
            f'<p class="wave-scale"><span class="wave-scale-label">相对第 1 波</span>'
            f'<span data-col="hp">生命 ×{esc(fmt_num(hp_ratio))}</span>'
            f'<span data-col="speed">移速 ×{esc(fmt_num(speed_ratio))}</span></p>'
            f'<p class="wave-empty">可选栏里的字段都已隐藏。勾选右侧项目即可显示。</p>'
            f'{"".join(groups)}</article>'
        )
    sidebar = []
    for group, title, cols in WAVE_GROUPS:
        sidebar.append(f'<p class="wave-aside-kicker">{esc(title)}</p>')
        for key, label, _hint in cols:
            sidebar.append(
                f'<label class="wave-col" for="col-{esc(key)}">'
                f'<input type="checkbox" id="col-{esc(key)}" checked> '
                f"<span>{esc(label)}</span></label>"
            )
    html = (
        '<div class="waves" id="waves" data-waves>'
        '<input class="wave-drawer" type="checkbox" id="wave-drawer" aria-label="打开可选栏">'
        '<div class="waves-head"><div class="waves-title">'
        "<h3>波次说明</h3>"
        '<p class="waves-lead">一次只看一波。可选栏决定显示哪些字段，换波次时不会收起。</p>'
        "</div>"
        '<label class="waves-drawer-btn" for="wave-drawer">可选栏</label></div>'
        '<label class="wave-backdrop" for="wave-drawer" aria-hidden="true"></label>'
        '<div class="waves-layout"><div class="waves-main">'
        '<fieldset class="wave-switch">'
        '<legend class="sr">选择波次</legend>'
        f'{"".join(picks)}'
        f'<div class="wave-tabs">{"".join(tabs)}</div>'
        f'{"".join(panels)}'
        "</fieldset></div>"
        '<aside class="wave-aside" id="wave-columns" aria-label="可选栏">'
        '<div class="wave-aside-bar"><h3>可选栏</h3>'
        '<label class="wave-aside-close" for="wave-drawer">关闭</label></div>'
        "<p>勾选后每一波都显示。换到别的波次，这一栏还在。</p>"
        f'{"".join(sidebar)}'
        "</aside></div>"
        f'<p class="footnote">{esc(WAVE_FOOTNOTE)}</p>'
        "<script>"
        "(function () {"
        'var root = document.getElementById("waves");'
        "if (!root) return;"
        'var cols = root.querySelectorAll(".wave-col input");'
        'var key = "codex-wave-columns";'
        "try {"
        'var saved = JSON.parse(localStorage.getItem(key) || "null");'
        'if (saved && typeof saved === "object") {'
        "cols.forEach(function (input) {"
        "if (Object.prototype.hasOwnProperty.call(saved, input.id)) input.checked = !!saved[input.id];"
        "});"
        "}"
        "} catch (e) {}"
        "function store() {"
        "var state = {};"
        "cols.forEach(function (input) { state[input.id] = input.checked; });"
        "try { localStorage.setItem(key, JSON.stringify(state)); } catch (e) {}"
        "}"
        'cols.forEach(function (input) { input.addEventListener("change", store); });'
        'var drawer = document.getElementById("wave-drawer");'
        "if (!drawer) return;"
        "function narrow() { return window.matchMedia(\"(max-width: 860px)\").matches; }"
        "function syncDrawer() {"
        "document.body.style.overflow = drawer.checked && narrow() ? \"hidden\" : \"\";"
        "if (drawer.checked && narrow()) {"
        'var first = root.querySelector(".wave-col input");'
        "if (first) first.focus();"
        "}"
        "}"
        'drawer.addEventListener("change", syncDrawer);'
        'document.addEventListener("keydown", function (event) {'
        "if (event.key === \"Escape\" && drawer.checked) {"
        "drawer.checked = false;"
        "syncDrawer();"
        "drawer.focus();"
        "}"
        "});"
        "})();"
        "</script></div>"
    )
    return html, _wave_css(len(rows))


WAVE_PANEL_CSS = """
.waves { margin-top: 28px; scroll-margin-top: 16px; position: relative; }
.waves-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 12px; margin-bottom: 12px;
}
.waves-title { min-width: 0; }
.waves h3 { margin: 0; font-size: 22px; }
.waves-lead { margin: 4px 0 0; color: var(--muted); font-size: 14px; }
.waves-drawer-btn, .wave-aside-close {
  display: none;
  align-items: center; justify-content: center;
  min-height: 40px; padding: 8px 14px;
  border: 1px solid var(--line); border-radius: 999px;
  background: var(--card); color: var(--text);
  font: inherit; font-size: 14px; font-weight: 650;
  cursor: pointer; user-select: none;
}
.wave-drawer:focus-visible ~ .waves-head .waves-drawer-btn,
.wave-aside-close:focus-visible {
  outline: 2px solid var(--gold); outline-offset: 2px;
}
.wave-backdrop { display: none; }
.wave-drawer, .sr, .wave-pick {
  position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0;
  overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
.waves-layout {
  display: grid; grid-template-columns: minmax(0, 1fr) 232px;
  gap: 16px; align-items: start;
}
.wave-switch { border: 0; margin: 0; padding: 0; min-width: 0; min-inline-size: 0; }
.wave-tabs {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(4.8em, 1fr));
  gap: 6px; margin: 0 0 12px; padding: 6px;
  background: var(--chip); border: 1px solid var(--line); border-radius: 16px;
}
.wave-tabs label {
  display: flex; align-items: center; justify-content: center;
  min-height: 40px; padding: 6px 8px; border-radius: 999px;
  border: 1px solid transparent; cursor: pointer; user-select: none;
  font-size: 14px; line-height: 1.2; text-align: center;
}
.wave-tabs label:hover { background: var(--card); }
.wave-panel { display: none; padding: 16px 16px 14px; }
.wave-panel h3 { font-size: 28px; line-height: 1.15; }
.wave-scale {
  display: flex; flex-wrap: wrap; align-items: center; gap: 6px 8px;
  margin: 8px 0 14px; color: var(--muted); font-size: 14px;
}
.wave-scale span[data-col] {
  background: var(--well); color: var(--text);
  border-radius: 999px; padding: 2px 10px;
}
.wave-empty { display: none; margin: 0 0 8px; color: var(--muted); }
.wave-group + .wave-group { margin-top: 14px; }
.wave-group h4 {
  margin: 0 0 8px; color: var(--muted); font-size: 13px; font-weight: 650;
  letter-spacing: .04em;
}
dl.wave-stats {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(148px, 1fr));
  gap: 10px; margin: 0;
}
.wave-stat {
  background: var(--well); border-radius: 14px; padding: 10px 12px; min-width: 0;
}
.wave-stat.is-present { box-shadow: inset 0 0 0 1px var(--gold); }
.wave-stat dt { font-size: 14px; font-weight: 650; }
.wave-stat dd {
  display: flex; flex-direction: column; align-items: flex-start;
  margin: 2px 0 0; text-align: left;
}
.wave-num {
  font-size: 28px; font-weight: 700; line-height: 1.15;
  font-variant-numeric: tabular-nums; color: var(--text);
}
.wave-stat.is-zero .wave-num { color: var(--muted); font-weight: 600; }
.wave-stat .hint {
  margin-top: 2px; color: var(--muted); font-size: 12px; font-weight: 400; line-height: 1.3;
}
.wave-aside {
  position: sticky; top: 16px; align-self: start;
  max-height: calc(100vh - 32px); overflow: auto;
  background: var(--card); border: 1px solid var(--line); border-radius: 18px;
  box-shadow: var(--shadow); padding: 14px 14px 10px;
}
.wave-aside-bar { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.wave-aside h3 { font-size: 18px; }
.wave-aside > p { margin: 6px 0 8px; color: var(--muted); font-size: 13px; }
.wave-aside-kicker {
  margin: 12px 0 2px; color: var(--muted); font-size: 12px; letter-spacing: .04em;
}
.wave-col {
  display: flex; align-items: center; gap: 10px;
  min-height: 40px; margin: 0; padding: 4px 6px; border-radius: 10px;
  cursor: pointer; font-size: 15px;
}
.wave-col:hover { background: var(--chip); }
.wave-col input { width: 18px; height: 18px; margin: 0; accent-color: var(--gold); }
.waves .footnote { margin: 14px 0 0; }
@media (min-width: 861px) {
  .wave-drawer { display: none; }
}
@media (max-width: 860px) {
  .waves-drawer-btn { display: inline-flex; }
  .wave-aside-close { display: inline-flex; }
  .waves-layout { grid-template-columns: 1fr; }
  .wave-drawer:checked ~ .waves-head .waves-drawer-btn {
    background: var(--text); color: var(--bg); border-color: transparent;
  }
  .wave-backdrop { display: none; }
  .wave-drawer:checked ~ .wave-backdrop {
    display: block; position: fixed; inset: 0; z-index: 40;
    background: rgba(20, 26, 20, .45);
  }
  .wave-aside {
    position: fixed; z-index: 41; top: 0; right: 0;
    height: 100vh; height: 100dvh; max-height: none;
    width: min(300px, 86vw); border-radius: 18px 0 0 18px;
    box-shadow: -16px 0 40px rgba(0, 0, 0, .22);
    transform: translateX(105%); visibility: hidden;
    transition: transform .18s ease, visibility .18s ease;
    overscroll-behavior: contain;
    padding-bottom: max(16px, env(safe-area-inset-bottom));
  }
  .wave-drawer:checked ~ .waves-layout .wave-aside {
    transform: translateX(0); visibility: visible;
  }
}
@media (prefers-reduced-motion: reduce) {
  .wave-aside { transition: none; }
}
"""


def render_economy(economy: dict) -> str:
    return (
        '<p class="callout">清完一波：木材 '
        f"{int(economy['wave_clear_wood'])} + 每座农场 × {fmt_num(economy['farm_wood'])}，"
        f"金币 +{int(economy['wave_clear_gold'])}。"
        "平底薪仍是 scripts/main.gd 里的 WAVE_CLEAR_WOOD 和 WAVE_CLEAR_GOLD。"
        f"塔立着就会攻击。工坊把塔的攻击 ×{fmt_num(economy['workshop_tower_damage'])}，"
        "先乘攻击再套伤害公式，不叠加，取还立着的最高一座。</p>"
    )


def esc(value) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def economy_from(main_gd: str, buildings: list) -> dict:
    wood = read_const(main_gd, "WAVE_CLEAR_WOOD")
    gold = read_const(main_gd, "WAVE_CLEAR_GOLD")
    farm = next((entry for entry in buildings if entry.get("id") == "farm"), None)
    workshop = next((entry for entry in buildings if entry.get("id") == "workshop"), None)
    produces = (farm or {}).get("produces") or {}
    bonus = (workshop or {}).get("bonus") or {}
    if produces.get("rate") is None or bonus.get("tower_damage") is None:
        die("farm.produces.rate and workshop.bonus.tower_damage are required")
    return {
        "wave_clear_wood": int(wood),
        "wave_clear_gold": int(gold),
        "farm_wood": produces["rate"],
        "workshop_tower_damage": bonus["tower_damage"],
    }


def main() -> None:
    units_doc = load_json(ROOT / "data" / "units.json")
    enemies_doc = load_json(ROOT / "data" / "enemies.json")
    buildings_doc = load_json(ROOT / "data" / "buildings.json")
    characters = load_json(ROOT / "data" / "characters.json")
    volumes = load_json(ROOT / "data" / "iso_volumes.json")
    main_gd = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
    building_gd = (ROOT / "scripts" / "building.gd").read_text(encoding="utf-8")
    balance_gd = (ROOT / "scripts" / "balance.gd").read_text(encoding="utf-8")
    locale = parse_locale((ROOT / "scripts" / "locale.gd").read_text(encoding="utf-8"))

    for name in ("data/units.json", "data/enemies.json", "data/buildings.json"):
        if name not in balance_gd:
            die(f"scripts/balance.gd no longer loads {name}")
    if PEOPLE_VOLUME not in volumes:
        die(f"iso_volumes.json is missing {PEOPLE_VOLUME}")
    volumes_for_kind = volume_by_kind(building_gd)
    spawned = spawned_unit_ids(main_gd)
    if "villager" not in spawned:
        die('main.gd no longer calls Balance.unit("villager")')
    aliases = kind_aliases(balance_gd)

    units = units_doc.get("units")
    enemies = enemies_doc.get("enemies")
    buildings = buildings_doc.get("buildings")
    if not isinstance(units, list) or not isinstance(enemies, list) or not isinstance(buildings, list):
        die("units, enemies, and buildings must be arrays")
    ids = {
        "units": {entry.get("id") for entry in units},
        "enemies": {entry.get("id") for entry in enemies},
        "buildings": {entry.get("id") for entry in buildings},
    }
    if not REQUIRED_UNITS <= ids["units"]:
        die(f"units.json is missing {sorted(REQUIRED_UNITS - ids['units'])}")
    if not REQUIRED_ENEMIES <= ids["enemies"]:
        die(f"enemies.json is missing {sorted(REQUIRED_ENEMIES - ids['enemies'])}")
    if not REQUIRED_BUILDINGS <= ids["buildings"]:
        die(f"buildings.json is missing {sorted(REQUIRED_BUILDINGS - ids['buildings'])}")
    for kind, enemy_id in aliases.items():
        if enemy_id not in ids["enemies"]:
            die(f"Balance alias {kind} -> {enemy_id} is not an enemy id")
    json_waves = enemies_doc.get("waves")
    if not isinstance(json_waves, list) or len(json_waves) != 10:
        die("enemies.json needs 10 waves")
    for index, wave in enumerate(json_waves, start=1):
        missing = [name for name in WAVE_FIELDS if name not in wave]
        if missing:
            die(f"wave {index} missing {', '.join(missing)}")
    economy = economy_from(main_gd, buildings)

    if THUMBS.exists():
        shutil.rmtree(THUMBS)
    THUMBS.mkdir(parents=True)

    unit_cards = []
    for entry in units:
        require_fields(entry, UNIT_FIELDS, entry.get("id", "unit"))
        if entry["faction"] != "ally":
            die(f"{entry['id']} faction should be ally")
        spec = bind_entry(entry, characters, volumes, locale, PEOPLE_VOLUME)
        skins = make_character_thumbs(entry, spec)
        unit_cards.append(unit_card(entry, skins, entry["id"] in spawned))

    enemy_cards = []
    for entry in enemies:
        require_fields(entry, ENEMY_FIELDS, entry.get("id", "enemy"))
        if not isinstance(entry["tags"], list) or not entry["tags"]:
            die(f"{entry['id']} needs tags")
        spec = bind_entry(entry, characters, volumes, locale, PEOPLE_VOLUME)
        skins = make_character_thumbs(entry, spec)
        enemy_cards.append(enemy_card(entry, skins))

    building_cards = []
    building_names = set()
    for entry in buildings:
        require_fields(entry, BUILDING_FIELDS, entry.get("id", "building"))
        if entry["category"] not in CATEGORIES:
            die(f"{entry['id']} category must be recruit, production, or defense")
        if entry["can_attack"]:
            require_fields(entry, ("attack", "attack_speed", "attack_range"), entry["id"])
        volume = volumes_for_kind.get(entry["kind"])
        if volume is None:
            die(f"{entry['id']} kind {entry['kind']} is missing from Building._volume_key")
        bind_entry(entry, characters, volumes, locale, volume)
        res_path(entry["tex"])
        building_names.add(Path(entry["tex"]).name)
        building_cards.append(building_card(entry, locale))

    scene_cards = scenery_cards(building_names, volumes)
    catalog = {
        "counts": {
            "units": len(unit_cards),
            "enemies": len(enemy_cards),
            "buildings": len(building_cards),
            "scenery": len(scene_cards),
        },
        "sections": {
            "units": unit_cards,
            "enemies": enemy_cards,
            "buildings": building_cards,
            "scenery": scene_cards,
        },
        "waves": wave_rows(json_waves),
        "economy": economy,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (OUT / "index.html").write_text(render_page(catalog), encoding="utf-8")
    counts = catalog["counts"]
    total = sum(counts.values())
    print(
        f"codex: {counts['units']} units, {counts['enemies']} enemies, "
        f"{counts['buildings']} buildings, {counts['scenery']} scenery ({total} cards)"
    )


if __name__ == "__main__":
    main()
