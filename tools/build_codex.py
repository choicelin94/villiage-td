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
        "enemies": ("敌人", "Enemies", "卡片是第 1 波的世界单位。后面的波次按相对第 1 波的比例缩放。"),
        "buildings": ("建筑", "Buildings", "塔立着就会攻击，不用派人。房屋立着就给床位，农场立着就产木材。"),
        "scenery": ("场景", "Scenery", "树和岩石挡住建造。草地和道路是地面，不进图鉴。"),
    }
    nav = []
    blocks = []
    for key, (zh, en, blurb) in sections.items():
        nav.append(f'<a href="#{key}">{esc(zh)}</a>')
        items = [render_card(item) for item in catalog["sections"][key]]
        extra = ""
        if key == "enemies":
            extra = render_waves(catalog["waves"])
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


def render_waves(rows: list) -> str:
    body = []
    for row in rows:
        body.append(
            "<tr>"
            f"<td>第 {row['wave']} 波</td>"
            f"<td>{row['normal']}</td><td>{fmt_num(row['hp'])}</td><td>{fmt_num(row['speed'])}</td>"
            f"<td>{fmt_num(row['gap'])}</td><td>{row['fast']}</td>"
            f"<td>{row['elite']}</td><td>{row['boss']}</td>"
            "</tr>"
        )
    return (
        '<div class="table-wrap"><table>'
        "<thead><tr><th>波次</th><th>普通</th><th>基准生命</th><th>基准移速</th>"
        "<th>间隔</th><th>迅捷</th><th>精锐</th><th>首领</th></tr></thead>"
        f"<tbody>{''.join(body)}</tbody></table></div>"
        '<p class="footnote">卡片上的生命和移速已经是第 1 波的世界单位。后面每一波按相对第 1 波的比例缩放：生命取 round(卡片生命 × 本波基准生命 / 第 1 波基准生命)，移速取卡片移速 × 本波基准移速 / 第 1 波基准移速。表里的基准移速还没有乘 WORLD_SCALE，它只用来算这个比例。被感染的村民是单独的 spear_infected，不再在普通僵尸上再乘 0.65。</p>'
    )


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
