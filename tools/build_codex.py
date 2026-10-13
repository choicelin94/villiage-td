#!/usr/bin/env python3
"""Regenerate the static Codex from balance JSON and sprite sheets.

Run from anywhere:

    python3 tools/build_codex.py

Requires Pillow. Writes docs/codex/index.html, catalog.json, and thumbs/.
Live numbers are checked against the GDScript tables before anything is written.
"""

from __future__ import annotations

import json
import math
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
    "shooter_brute",
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
ATTACK_FIELDS = ("attack", "attack_speed", "attack_range", "splash", "shot_speed")
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
    "horde": "尸潮",
    "spear": "持矛",
    "fast": "迅捷",
    "infected": "感染",
    "shooter": "持枪",
    "brute": "蛮兵",
    "boss": "首领",
}
VISUAL_FOR_KIND = {
    "normal": "spear",
    "fast": "spear",
    "brute": "shooter",
    "boss": "shooter",
}


def die(message: str) -> None:
    sys.exit(f"build_codex: {message}")


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        die(f"missing {path.relative_to(ROOT)}")
    except json.JSONDecodeError as exc:
        die(f"{path.relative_to(ROOT)} is not valid JSON ({exc})")


def world_len(authored: float, scale: float) -> float:
    return round(float(authored) * float(scale) + 1e-12, 3)


def gd_round(value: float) -> int:
    if value >= 0:
        return int(math.floor(value + 0.5))
    return int(math.ceil(value - 0.5))


def near(left, right) -> bool:
    return abs(float(left) - float(right)) < 1e-6


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


def parse_waves(text: str) -> list:
    rows = re.findall(
        r'\{"n":\s*(\d+),\s*"hp":\s*(\d+),\s*"speed":\s*([\d.]+),\s*"gap":\s*([\d.]+),\s*'
        r'"fast":\s*(\d+),\s*"brute":\s*(\d+),\s*"boss":\s*(\d+)\}',
        text,
    )
    if len(rows) != 10:
        die(f"expected 10 waves in main.gd, found {len(rows)}")
    waves = []
    for n, hp, speed, gap, fast, brute, boss in rows:
        waves.append(
            {
                "n": int(n),
                "hp": int(hp),
                "speed": float(speed),
                "gap": float(gap),
                "fast": int(fast),
                "brute": int(brute),
                "boss": int(boss),
            }
        )
    return waves


def parse_kind_mod(text: str) -> dict:
    pattern = re.compile(
        r'"(normal|fast|brute|boss)":\s*\{'
        r'"hp":\s*([\d.]+),\s*"speed":\s*([\d.]+),\s*"scale":\s*([\d.]+),\s*'
        r'"dmg":\s*(\d+),\s*"wood":\s*(\d+),\s*"gold":\s*(\d+),',
    )
    found = pattern.findall(text)
    if len(found) != 4:
        die("could not read KIND_MOD from main.gd")
    mods = {}
    for kind, hp, speed, scale, dmg, wood, gold in found:
        mods[kind] = {
            "hp": float(hp),
            "speed": float(speed),
            "scale": float(scale),
            "dmg": int(dmg),
            "wood": int(wood),
            "gold": int(gold),
        }
    return mods


def parse_building_stats(text: str) -> dict:
    blocks = re.findall(r"Kind\.(\w+):\s*\{([^}]*)\}", text, re.S)
    if len(blocks) < 6:
        die("could not read Building.STATS")
    stats = {}
    for kind, body in blocks:
        nums = {}
        for key, raw in re.findall(r'"(\w+)":\s*(-?\d+(?:\.\d+)?)', body):
            nums[key] = float(raw) if "." in raw else int(raw)
        stats[kind] = nums
    return stats


def read_const(text: str, name: str) -> float:
    match = re.search(rf"const {name} := ([\d.]+)", text)
    if not match:
        die(f"missing const {name}")
    return float(match.group(1))


def fmt_num(value) -> str:
    number = float(value)
    if number.is_integer():
        return str(int(number))
    return f"{number:.3f}".rstrip("0").rstrip(".")


def fmt_cost(cost: dict) -> str:
    parts = []
    if cost.get("wood"):
        parts.append(f"{int(cost['wood'])} 木")
    if cost.get("gold"):
        parts.append(f"{int(cost['gold'])} 金")
    return " + ".join(parts) if parts else "无"


def fmt_seconds(value) -> str:
    if float(value) == 0:
        return "—"
    return f"{fmt_num(value)} 秒"


def fmt_distance(value) -> str:
    if float(value) == 0:
        return "—"
    return fmt_num(value)


def stat(label: str, value: str) -> dict:
    return {"k": label, "v": value}


def load_locale_names(entry: dict, locale: dict) -> None:
    key = entry["display_key"]
    row = locale.get(key)
    if row is None:
        die(f"{entry['id']} display_key {key} is missing from scripts/locale.gd")
    name = entry.get("name")
    if not isinstance(name, dict):
        die(f"{entry['id']} needs name.zh and name.en")
    if row["zh"] != name["zh"] or row["en"] != name["en"]:
        die(
            f"{key} disagrees with locale.gd "
            f"({name['zh']}/{name['en']} vs {row['zh']}/{row['en']})"
        )


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


def enemy_wave1_hp(entry: dict, wave_hp: int) -> int:
    hp = max(gd_round(wave_hp * float(entry["hp_mul"])), 1)
    if entry.get("turned"):
        hp = max(int(hp * float(entry["turned_hp_scale"])), int(entry["turned_hp_min"]))
    return hp


def check_enemy(entry: dict, wave: dict, mods: dict, scale: float, bite: float, tile: float) -> None:
    kind = entry.get("kind")
    if kind not in mods:
        die(f"{entry['id']} kind {kind} is not in KIND_MOD")
    mod = mods[kind]
    if not near(entry["hp_mul"], mod["hp"]) or not near(entry["speed_mul"], mod["speed"]):
        die(f"{entry['id']} multipliers do not match KIND_MOD.{kind}")
    if not near(entry["scale"], mod["scale"]) or int(entry["attack"]) != mod["dmg"]:
        die(f"{entry['id']} scale or attack does not match KIND_MOD.{kind}")
    if int(entry["wood_reward"]) != mod["wood"] or int(entry["gold_reward"]) != mod["gold"]:
        die(f"{entry['id']} rewards do not match KIND_MOD.{kind}")
    if entry["character"] != VISUAL_FOR_KIND[kind]:
        die(f"{entry['id']} character should be {VISUAL_FOR_KIND[kind]}")
    if int(entry["hp"]) != enemy_wave1_hp(entry, int(wave["hp"])):
        die(f"{entry['id']} hp {entry['hp']} is not the wave-1 value")
    expected_speed = world_len(float(wave["speed"]) * float(entry["speed_mul"]), scale)
    if not near(entry["move_speed"], expected_speed):
        die(f"{entry['id']} move_speed {entry['move_speed']} != {expected_speed}")
    if not near(entry["attack_speed"], bite):
        die(f"{entry['id']} attack_speed should be the zombie bite cooldown {bite}")
    if not near(entry["attack_range"], tile):
        die(f"{entry['id']} attack_range should be one tile ({tile})")
    if int(entry["defense"]) != 0:
        die(f"{entry['id']} defense is 0; the simulation has no armor")


def check_building(entry: dict, stats: dict, scale: float, wall_cap: int, workshop: float) -> None:
    kind = entry["kind"]
    block = stats.get(kind)
    if block is None:
        die(f"{entry['id']} kind {kind} is missing from Building.STATS")
    if int(entry["hp"]) != int(block["hp"]):
        die(f"{entry['id']} hp does not match Building.STATS")
    if int(entry["cost"]["wood"]) != int(block["wood"]) or int(entry["cost"]["gold"]) != int(block["gold"]):
        die(f"{entry['id']} cost does not match Building.STATS")
    attacks = float(block.get("range", 0)) > 0 or int(block.get("dmg", 0)) > 0
    if bool(entry["can_attack"]) != attacks:
        die(f"{entry['id']} can_attack does not match Building.STATS")
    if entry["can_attack"]:
        for field in ATTACK_FIELDS:
            if field not in entry:
                die(f"{entry['id']} can_attack but missing {field}")
        if int(entry["attack"]) != int(block["dmg"]) or not near(entry["attack_speed"], block["cd"]):
            die(f"{entry['id']} attack or attack_speed does not match Building.STATS")
        if not near(entry["attack_range"], world_len(block["range"], scale)):
            die(f"{entry['id']} attack_range is not range * WORLD_SCALE")
        if not near(entry["splash"], world_len(block["splash"], scale)):
            die(f"{entry['id']} splash is not splash * WORLD_SCALE")
        if not near(entry["shot_speed"], world_len(block["shot_speed"], scale)):
            die(f"{entry['id']} shot_speed is not shot_speed * WORLD_SCALE")
    if kind == "WALL":
        if entry.get("requires_staff") or int(entry.get("place_cap", -1)) != int(wall_cap):
            die("wall must not require staff and place_cap must be WALL_CAP")
    elif entry.get("requires_staff") is not True:
        die(f"{entry['id']} requires a villager")
    if kind == "HOUSE" and int(entry.get("beds", -1)) != int(block["cap"]):
        die("house beds must match STATS cap")
    if kind == "FARM":
        produces = entry.get("produces") or {}
        if int(produces.get("wood", -1)) != 6:
            die("farm produces.wood must be 6")
    if kind == "WORKSHOP":
        bonus = entry.get("bonus") or {}
        if not near(bonus.get("tower_damage", 0), workshop) or bonus.get("stacks") is not False:
            die("workshop bonus must be the unstacked tower multiplier")
    if int(entry["defense"]) != 0:
        die(f"{entry['id']} defense is armor 0; category carries the old defense flag")


def check_names_and_art(entry: dict, characters: dict, volumes: dict, locale: dict) -> dict:
    load_locale_names(entry, locale)
    visual = entry.get("character")
    if visual is not None:
        if visual not in characters:
            die(f"{entry['id']} character {visual} is missing from characters.json")
        spec = characters[visual]
        for key in ("sheets", "skins", "frame", "foot", "faces_right", "clips"):
            if key not in spec:
                die(f"characters.json {visual} missing {key}")
        skin = entry.get("skin")
        skins = entry.get("skins")
        if skin is None and not skins:
            die(f"{entry['id']} needs skin or skins")
        if skin is not None and skin not in spec["skins"]:
            die(f"{entry['id']} skin {skin} is not on {visual}")
        for name in skins or []:
            if name not in spec["skins"]:
                die(f"{entry['id']} skins contains unknown {name}")
    volume = entry.get("volume")
    if volume and volume not in volumes:
        die(f"{entry['id']} volume {volume} is missing from iso_volumes.json")
    return characters.get(visual, {})


def make_character_thumbs(entry: dict, spec: dict) -> list:
    frame = spec["frame"]
    skins = list(entry.get("skins") or [entry["skin"]])
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


def unit_card(entry: dict, skins: list) -> dict:
    badge, tone = badge_for(entry["status"])
    role = ROLE_ZH.get(entry["role"], entry["role"])
    stats = [
        stat("职责", f"{role} · {entry['role']}"),
        stat("生命", fmt_num(entry["hp"])),
        stat("防御", fmt_num(entry["defense"])),
        stat("攻击", fmt_num(entry["attack"])),
        stat("攻击间隔", fmt_seconds(entry["attack_speed"])),
        stat("移速", fmt_num(entry["move_speed"])),
        stat("射程", fmt_distance(entry["attack_range"])),
        stat("费用", fmt_cost(entry["cost"])),
        stat("训练", "—" if float(entry["train_time"]) == 0 else f"{fmt_num(entry['train_time'])} 秒"),
        stat("形象", entry["character"]),
        stat("体积", entry["volume"]),
    ]
    return card(entry, "units", badge, tone, stats, skins)


def enemy_card(entry: dict, skins: list) -> dict:
    badge, tone = badge_for(entry["status"])
    tags = " · ".join(TAG_ZH.get(tag, tag) for tag in entry["tags"])
    stats = [
        stat("生命", f"{fmt_num(entry['hp'])}（第 1 波）"),
        stat("防御", fmt_num(entry["defense"])),
        stat("攻击", fmt_num(entry["attack"])),
        stat("攻击间隔", fmt_seconds(entry["attack_speed"])),
        stat("移速", f"{fmt_num(entry['move_speed'])}（第 1 波）"),
        stat("射程", fmt_distance(entry["attack_range"])),
        stat("体型", f"×{fmt_num(entry['scale'])}"),
        stat("赏金", f"{int(entry['gold_reward'])} 金"),
        stat("木材", f"{int(entry['wood_reward'])} 木"),
        stat("标签", tags),
        stat("形象", entry["character"]),
        stat("体积", entry["volume"]),
    ]
    return card(entry, "enemies", badge, tone, stats, skins)


def building_card(entry: dict, locale: dict) -> dict:
    badge, tone = badge_for(entry["status"])
    role = locale.get(entry.get("role_key", ""), {})
    role_text = entry["category"]
    if role:
        role_text = f"{role['zh']} · {CATEGORY_ZH[entry['category']]}"
    stats = [
        stat("类别", role_text),
        stat("种类", entry["kind"]),
        stat("生命", fmt_num(entry["hp"])),
        stat("防御", fmt_num(entry["defense"])),
        stat("费用", fmt_cost(entry["cost"])),
    ]
    if entry["can_attack"]:
        stats.extend(
            [
                stat("攻击", fmt_num(entry["attack"])),
                stat("攻击间隔", fmt_seconds(entry["attack_speed"])),
                stat("射程", fmt_distance(entry["attack_range"])),
                stat("溅射", fmt_num(entry["splash"])),
                stat("弹速", fmt_num(entry["shot_speed"])),
            ]
        )
    if "beds" in entry:
        stats.append(stat("床位", str(int(entry["beds"]))))
    if "produces" in entry:
        stats.append(stat("产出", f"每波 +{int(entry['produces']['wood'])} 木"))
    if "bonus" in entry:
        stats.append(stat("加成", f"塔伤害 ×{fmt_num(entry['bonus']['tower_damage'])}"))
    if "place_cap" in entry:
        stats.append(stat("上限", str(int(entry["place_cap"]))))
    stats.append(stat("派人", "需要" if entry["requires_staff"] else "不需要"))
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


def wave_rows(waves: list, scale: float) -> list:
    rows = []
    for index, wave in enumerate(waves, start=1):
        rows.append(
            {
                "wave": index,
                "n": wave["n"],
                "hp": wave["hp"],
                "speed": world_len(wave["speed"], scale),
                "gap": wave["gap"],
                "fast": wave["fast"],
                "brute": wave["brute"],
                "boss": wave["boss"],
            }
        )
    return rows


def render_page(catalog: dict) -> str:
    sections = {
        "units": ("友方单位", "Units", "村民会出场。矛兵和工程师只写在目录里。"),
        "enemies": ("敌人", "Enemies", "生命和移速随波次变化。卡片写第 1 波，倍率写在备注里。"),
        "buildings": ("建筑", "Buildings", "功能建筑要派人之后才生效。木墙不用派人。"),
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
  <p>头像是序列帧左上角第 0 帧，或建筑的俯视图，透明边已裁掉。数值来自 data/units.json、data/enemies.json、data/buildings.json。攻击间隔是两次攻击之间的秒数。移速、射程、溅射和弹速是世界像素。</p>
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
            f"<td>{row['n']}</td><td>{row['hp']}</td><td>{fmt_num(row['speed'])}</td>"
            f"<td>{fmt_num(row['gap'])}</td><td>{row['fast']}</td>"
            f"<td>{row['brute']}</td><td>{row['boss']}</td>"
            "</tr>"
        )
    return (
        '<div class="table-wrap"><table>'
        "<thead><tr><th>波次</th><th>普通</th><th>基准生命</th><th>普通移速</th>"
        "<th>间隔</th><th>迅捷</th><th>蛮兵</th><th>首领</th></tr></thead>"
        f"<tbody>{''.join(body)}</tbody></table></div>"
        '<p class="footnote">普通数量之外，迅捷、蛮兵和首领另外再加。移速是这一波普通尸潮的世界单位，其他敌人再乘自己的速度倍率。生命同理，被感染的村民还要再按 65% 截断。</p>'
    )


def render_economy(economy: dict) -> str:
    return (
        '<p class="callout">清完一波：木材 '
        f"{int(economy['wave_clear_wood'])} + 有人农场 × {int(economy['staffed_farm_wood'])}，"
        f"金币 +{int(economy['wave_clear_gold'])}。"
        f"有人工坊使矛塔和火塔伤害 ×{fmt_num(economy['workshop_tower_damage'])}，不叠加。</p>"
    )


def esc(value) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def same_wave(left: dict, right: dict) -> bool:
    keys = ("n", "hp", "speed", "gap", "fast", "brute", "boss")
    return all(near(left[key], right[key]) for key in keys)


def main() -> None:
    units_doc = load_json(ROOT / "data" / "units.json")
    enemies_doc = load_json(ROOT / "data" / "enemies.json")
    buildings_doc = load_json(ROOT / "data" / "buildings.json")
    characters = load_json(ROOT / "data" / "characters.json")
    volumes = load_json(ROOT / "data" / "iso_volumes.json")
    main_gd = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
    building_gd = (ROOT / "scripts" / "building.gd").read_text(encoding="utf-8")
    zombie_gd = (ROOT / "scripts" / "zombie.gd").read_text(encoding="utf-8")
    iso_gd = (ROOT / "scripts" / "iso_volume.gd").read_text(encoding="utf-8")
    locale = parse_locale((ROOT / "scripts" / "locale.gd").read_text(encoding="utf-8"))

    scale = read_const(iso_gd, "WORLD_SCALE")
    if not near(enemies_doc.get("world_scale"), scale):
        die("enemies.json world_scale does not match IsoVolume.WORLD_SCALE")
    tile = read_const(iso_gd, "TILE")
    bite_match = re.search(r"_cooldown = ([\d.]+)", zombie_gd)
    if not bite_match:
        die("could not read the zombie bite cooldown")
    bite = float(bite_match.group(1))
    villager_speed = read_const(main_gd, "VILLAGER_SPEED")
    wall_cap = read_const(main_gd, "WALL_CAP")
    script_waves = parse_waves(main_gd)
    mods = parse_kind_mod(main_gd)
    stats = parse_building_stats(building_gd)
    workshop_match = re.search(r"func tower_bonus\(\) -> float:.*?return ([\d.]+)", main_gd, re.S)
    if not workshop_match:
        die("could not read tower_bonus")
    workshop = float(workshop_match.group(1))
    economy = buildings_doc.get("economy") or {}
    clear = re.search(r"wood \+= (\d+) \+ farms \* (\d+)\s*\n\s*gold \+= (\d+)", main_gd)
    if not clear:
        die("could not read the wave-clear reward")
    if (
        int(economy.get("wave_clear_wood", -1)) != int(clear.group(1))
        or int(economy.get("staffed_farm_wood", -1)) != int(clear.group(2))
        or int(economy.get("wave_clear_gold", -1)) != int(clear.group(3))
        or not near(economy.get("workshop_tower_damage", 0), workshop)
    ):
        die("buildings.json economy does not match main.gd")

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
    json_waves = enemies_doc.get("waves")
    if not isinstance(json_waves, list) or len(json_waves) != len(script_waves):
        die("enemies.json waves do not match main.gd")
    for index, (left, right) in enumerate(zip(json_waves, script_waves), start=1):
        if not same_wave(left, right):
            die(f"wave {index} does not match main.gd")

    if THUMBS.exists():
        shutil.rmtree(THUMBS)
    THUMBS.mkdir(parents=True)

    unit_cards = []
    for entry in units:
        require_fields(entry, UNIT_FIELDS, entry.get("id", "unit"))
        if entry["faction"] != "ally":
            die(f"{entry['id']} faction should be ally")
        if entry["status"] not in ("live", "configured"):
            die(f"{entry['id']} needs status live or configured")
        if entry["id"] in ("spearman", "engineer") and entry["status"] != "configured":
            die(f"{entry['id']} is not spawned; status must stay configured until main.gd spawns it")
        if entry["id"] == "villager" and entry["status"] != "live":
            die("villager is spawned and must stay live")
        spec = check_names_and_art(entry, characters, volumes, locale)
        if "move_speed_authored" in entry:
            expected = world_len(entry["move_speed_authored"], scale)
            if not near(entry["move_speed"], expected):
                die(f"{entry['id']} move_speed is not authored * WORLD_SCALE")
        if entry["status"] == "live" and not near(entry.get("move_speed_authored"), villager_speed):
            die("live villager move_speed_authored must match VILLAGER_SPEED")
        skins = make_character_thumbs(entry, spec)
        unit_cards.append(unit_card(entry, skins))

    enemy_cards = []
    for entry in enemies:
        require_fields(entry, ENEMY_FIELDS, entry.get("id", "enemy"))
        if not isinstance(entry["tags"], list) or not entry["tags"]:
            die(f"{entry['id']} needs tags")
        spec = check_names_and_art(entry, characters, volumes, locale)
        check_enemy(entry, json_waves[0], mods, scale, bite, tile)
        skins = make_character_thumbs(entry, spec)
        enemy_cards.append(enemy_card(entry, skins))

    building_cards = []
    building_names = set()
    for entry in buildings:
        require_fields(entry, BUILDING_FIELDS, entry.get("id", "building"))
        if entry["category"] not in CATEGORIES:
            die(f"{entry['id']} category must be recruit, production, or defense")
        if entry["can_attack"]:
            require_fields(entry, ATTACK_FIELDS, entry["id"])
        check_names_and_art(entry, characters, volumes, locale)
        if entry.get("role_key") not in locale:
            die(f"{entry['id']} role_key is missing from locale.gd")
        check_building(entry, stats, scale, wall_cap, workshop)
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
        "waves": wave_rows(json_waves, scale),
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
