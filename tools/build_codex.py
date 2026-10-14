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
# At this width and below, the left rail becomes a drawer. Desktop keeps the rail.
# Phone stacking is a second, narrower query in CODEX_LAYOUT_CSS. Keep them in sync.
NARROW_MQ = "(max-width: 1099px)"
RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS

REQUIRED_UNITS = {"villager", "spearman", "engineer", "gunner"}
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
    "lumber_mill",
    "spear_barracks",
    "gun_barracks",
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
ROLE_ZH = {"worker": "劳工", "melee": "近战", "support": "工兵", "ranged": "远程"}
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
# Level-1 modules. Scenery stays its own module: those cards are props, not buildings.
CODEX_MODULES = (
    ("units", "角色", "村民、矛兵、枪兵和工兵都会出场。空缺由房屋、兵营和工坊决定，清波后按概率补上，不是把村民转成兵。"),
    ("enemies", "敌人", "卡片是第 1 波的世界单位。后面的波次在「波次」模块里按比例缩放。击杀只掉金币。"),
    ("buildings", "建筑", "塔立着就会攻击。房屋床位是村民空缺。矛兵营、枪兵营和工坊提供对应单位空缺。木坊按驻守村民产木材。"),
    ("scenery", "场景", "树和岩石挡住建造。草地和道路是地面，不进图鉴。"),
    ("waves", "波次", "十波都在这一页。点左侧条目，页面滚到那一波。"),
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
    primary = entry.get("skin") or skins[0]
    made = []
    for skin in skins:
        dest = THUMBS / f"{entry['id']}__{skin}.png"
        portrait_from_sheet(res_path(sheet_for(spec, skin)), frame, dest)
        made.append(
            {
                "name": skin,
                "thumb": f"thumbs/{dest.name}",
                "primary": skin == primary,
            }
        )
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
    if isinstance(produces, dict) and produces.get("mode") == "staff":
        resource = {"wood": "木", "gold": "金"}.get(str(produces.get("resource", "")), str(produces.get("resource", "")))
        stats.append(stat("产出", f"每 {fmt_num(produces.get('interval', 0))} 秒，每名村民 +{fmt_num(produces.get('rate_per_villager', 0))} {resource}"))
        stats.append(stat("驻守", str(int(entry.get("staff_slots") or 0))))
    elif isinstance(produces, dict) and produces.get("rate") is not None:
        resource = {"wood": "木", "gold": "金"}.get(str(produces.get("resource", "")), str(produces.get("resource", "")))
        stats.append(stat("产出", f"每波 +{fmt_num(produces['rate'])} {resource}"))
    provides = entry.get("provides")
    if isinstance(provides, dict) and provides.get("unit"):
        unit_name = locale.get(f"unit.{provides['unit']}", {}).get("zh", str(provides["unit"]))
        stats.append(stat("空缺", f"{unit_name} × {int(provides.get('slots') or 0)}"))
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


GLYPHS = {
    "units": '<circle cx="12" cy="8" r="3"/><path d="M6 19c.8-3 2.8-4.5 6-4.5s5.2 1.5 6 4.5"/>',
    "enemies": '<path d="M14.5 4.5 19.5 9.5"/><path d="M14.5 4.5 5 17.5"/><path d="M5 17.5 3.6 20.4 7.2 19.2"/><path d="M9.2 13.2l2.8 2.8"/>',
    "buildings": '<path d="M4 11 12 4l8 7"/><path d="M6.5 10.5V20h11v-9.5"/><path d="M10 20v-5h4v5"/>',
    "scenery": '<path d="M12 21v-6"/><path d="M12 15c-4 .2-6.2-2.4-4.6-6 1.2-3.6 7.2-5 8.2-.4 1.6 3.4-.2 6.2-3.6 6.4z"/>',
    "waves": '<path d="M3 8c1.6 0 1.6 2.4 3.2 2.4S7.8 8 9.4 8s1.6 2.4 3.2 2.4 1.6-2.4 3.2-2.4 1.6 2.4 3.2 2.4 1.6-2.4 3.2-2.4"/><path d="M3 14.5c1.6 0 1.6 2.4 3.2 2.4s1.6-2.4 3.2-2.4 1.6 2.4 3.2 2.4 1.6-2.4 3.2-2.4 1.6 2.4 3.2 2.4 1.6-2.4 3.2-2.4"/>',
    "menu": '<path d="M4 7h16M4 12h16M4 17h10"/>',
    "close": '<path d="M6 6l12 12M18 6 6 18"/>',
}


def glyph(name: str) -> str:
    if name not in GLYPHS:
        die(f"missing icon {name}")
    return (
        '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">'
        f"{GLYPHS[name]}</svg>"
    )


def render_page(catalog: dict) -> str:
    shell, codex_css = build_codex_view(catalog)
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
  color-scheme: light;
  /* Warm light only: honey cream page, parchment cards, amber chrome, warm sage wells. */
  --bg: #f6ead8;
  --card: #fff7ec;
  --line: #e6cfaa;
  --text: #3e2c1c;
  --muted: #6b5340;
  --gold: #8f5612;
  --live-bg: #e4efd2;
  --live-ink: #355428;
  --soon-bg: #f8ddb0;
  --soon-ink: #7a4510;
  --scene-bg: #f3d2a4;
  --scene-ink: #6a3d12;
  --well: #e6edd4;
  --chip: #f8e6c8;
  --portrait: #73824a;
  --scrim: rgba(62, 40, 18, .42);
  --shadow: 0 10px 24px rgba(92, 54, 16, .10);
  --gutter: 16px;
  --content-max: 1120px;
}}
@media (min-width: 768px) {{
  :root {{ --gutter: 24px; --content-max: 1160px; }}
}}
@media (min-width: 1100px) {{
  :root {{ --gutter: 32px; --content-max: 1200px; }}
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 16px/1.55 "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Noto Sans SC", "Microsoft YaHei", sans-serif;
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}}
a {{ color: var(--gold); }}
header.top, .codex-shell, footer {{
  width: min(var(--content-max), calc(100% - 2 * var(--gutter)));
  margin-left: auto;
  margin-right: auto;
}}
header.top {{ padding: 28px 0 12px; }}
.kicker {{ margin: 0; color: var(--muted); letter-spacing: .08em; font-size: 13px; }}
h1 {{ margin: 4px 0; font-size: clamp(32px, 5vw, 48px); line-height: 1.1; }}
.summary {{ margin: 0 0 8px; color: var(--muted); }}
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
  background: radial-gradient(circle at 50% 78%, var(--portrait), var(--well) 68%);
  border-radius: 14px;
  aspect-ratio: 1;
  display: grid;
  place-items: center;
  overflow: hidden;
}}
.portrait > img {{
  grid-area: 1 / 1;
  width: 82%;
  height: 82%;
  object-fit: contain;
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
footer {{ margin-bottom: 32px; color: var(--muted); font-size: 13px; }}
.refresh-row {{ display: flex; align-items: center; gap: 12px; margin: 0 0 8px; flex-wrap: wrap; }}
.refresh-row button {{
  font: inherit; font-size: 15px; color: var(--text); cursor: pointer;
  background: var(--card); border: 1px solid var(--line); border-radius: 999px;
  padding: 6px 16px; min-height: 40px;
}}
.refresh-row button:hover {{ border-color: var(--gold); }}
.refresh-row button:focus-visible {{ outline: 2px solid var(--gold); outline-offset: 2px; }}
#codex-refresh-note {{ color: var(--muted); font-size: 14px; }}
a:focus-visible {{ outline: 2px solid var(--gold); outline-offset: 2px; }}
@media (max-width: 767px) {{
  header.top {{ padding: 18px 0 12px; }}
  h1 {{ font-size: 34px; }}
  .summary {{ font-size: 15px; }}
}}
{codex_css}
</style>
</head>
<body>
<header class="top">
  <p class="kicker">部落村落塔防</p>
  <h1>图鉴</h1>
  <p class="summary">{esc(summary)}，共 {total} 张。</p>
  <p class="refresh-row">
    <button type="button" id="codex-refresh">刷新</button>
    <span id="codex-refresh-note"></span>
  </p>
</header>
{shell}
<footer>
  <p>头像是序列帧左上角第 0 帧，或建筑的俯视图，透明边已裁掉。数值来自 data/units.json、data/enemies.json、data/buildings.json，对局由 scripts/balance.gd 加载同一份。攻速是每秒攻击次数。伤害是 max(1, round(attack × 100 / (100 + defense)))。移速、射程、溅射和弹速是世界单位。卡片上的小数最多显示 4 位。</p>
  <p>此页由 tools/build_codex.py 生成。改目录后重新运行脚本，再提交 docs/codex/。点「刷新」会读取 catalog.json 的 config_version。本地配置版本更低时，先用出厂配置补齐并升版本，再重新载入这一页。图鉴本身不编辑数值。</p>
</footer>
<script>
(function () {{
  var KEY = "vtd.setup";
  var PAGE_VERSION = {int(catalog.get("config_version", 1))};
  var note = document.getElementById("codex-refresh-note");
  var pending = sessionStorage.getItem("vtd.refreshNote");
  if (pending) {{
    note.textContent = pending;
    sessionStorage.removeItem("vtd.refreshNote");
  }}
  document.getElementById("codex-refresh").addEventListener("click", function () {{
    note.textContent = "正在检查配置…";
    fetch("catalog.json?t=" + Date.now(), {{ cache: "no-store" }})
      .then(function (response) {{
        if (!response.ok) throw new Error("catalog");
        return response.json();
      }})
      .then(function (remote) {{
        var remoteVersion = Number(remote.config_version) || 0;
        var local = null;
        try {{ local = JSON.parse(localStorage.getItem(KEY) || "null"); }} catch (err) {{ local = null; }}
        var localVersion = local && Number(local.config_version) || 0;
        if (localVersion < remoteVersion) {{
          var base = remote.setup && typeof remote.setup === "object" ? remote.setup : {{}};
          var merged = Object.assign({{}}, base, local || {{}});
          merged.config_version = remoteVersion;
          localStorage.setItem(KEY, JSON.stringify(merged));
          sessionStorage.setItem("vtd.refreshNote", "配置已从版本 " + localVersion + " 更新到 " + remoteVersion);
        }} else {{
          sessionStorage.setItem("vtd.refreshNote", "配置已是版本 " + remoteVersion);
        }}
        var next = new URL(window.location.href);
        next.searchParams.set("v", String(remoteVersion || PAGE_VERSION));
        window.location.replace(next.toString());
      }})
      .catch(function () {{
        note.textContent = "刷新失败，请再试一次";
      }});
  }});
}})();
</script>
</body>
</html>
"""


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


def _anchor(section: str, item_id: str) -> str:
    return f"entry-{section}-{item_id}"


def _stat_tiles(rows: list) -> str:
    tiles = []
    for row in rows:
        tiles.append(
            '<div class="stat-tile">'
            f'<dt>{esc(row["k"])}</dt>'
            f'<dd>{esc(row["v"])}</dd></div>'
        )
    return f'<dl class="card-stats">{"".join(tiles)}</dl>'


def _preview_html(item: dict) -> str:
    """Large portrait, with a thumbnail list underneath when several skins exist.

    The list is a sibling of the portrait, not a child, so the thumbs never sit
    inside the preview well. Choosing one swaps the large image.
    """
    zh = item["name_zh"]
    skins = item.get("skins") or []
    if len(skins) < 2:
        return (
            '<div class="preview"><div class="portrait">'
            f'<img src="{esc(item["portrait"])}" alt="{esc(zh)}头像">'
            "</div></div>"
        )
    group = f"skin-{item['section']}-{item['id']}"
    primary = next((index for index, skin in enumerate(skins) if skin.get("primary")), 0)
    frames = []
    options = []
    for index, skin in enumerate(skins):
        label = f"{zh} · {skin['name']}"
        checked = " checked" if index == primary else ""
        frames.append(
            f'<img class="skin-frame" src="{esc(skin["thumb"])}" alt="{esc(label)}">'
        )
        options.append(
            '<label class="skin-opt">'
            f'<input type="radio" name="{esc(group)}"{checked} aria-label="{esc(label)}">'
            f'<img src="{esc(skin["thumb"])}" alt="">'
            "</label>"
        )
    return (
        '<div class="preview">'
        f'<div class="portrait">{"".join(frames)}</div>'
        f'<div class="skins" role="radiogroup" aria-label="{esc(zh)}外观">'
        f'{"".join(options)}</div></div>'
    )


def _detail_panel(item: dict, section: str, item_id: str) -> str:
    note = f'<p class="note">{esc(item["note"])}</p>' if item["note"] else ""
    anchor = _anchor(section, item_id)
    return (
        f'<article class="item-panel" id="{esc(anchor)}" data-item="{esc(section)}-{esc(item_id)}">'
        '<div class="detail">'
        f"{_preview_html(item)}"
        '<div class="detail-copy">'
        '<div class="identity">'
        f'<h3>{esc(item["name_zh"])}</h3>'
        f'<p class="en">{esc(item["name_en"])}</p>'
        f'<p class="wid">{esc(item["id"])}</p>'
        f'<span class="badge {esc(item["badge_tone"])}">{esc(item["badge"])}</span>'
        "</div>"
        f'{_stat_tiles(item["stats"])}'
        f"{note}</div></div></article>"
    )


def _wave_panel(row: dict, ref: dict) -> str:
    number = int(row["wave"])
    ref_hp = float(ref["hp"]) or 1.0
    ref_speed = float(ref["speed"]) or 1.0
    hp_ratio = float(row["hp"]) / ref_hp
    speed_ratio = float(row["speed"]) / ref_speed
    groups = []
    for group, title, cols in WAVE_GROUPS:
        tiles = []
        for key, label, hint in cols:
            value = row[key]
            mark = ""
            if group == "counts":
                mark = " is-present" if int(value) > 0 else " is-zero"
            tiles.append(
                f'<div class="stat-tile{mark}">'
                f"<dt>{esc(label)}</dt>"
                f'<dd><span class="wave-num">{esc(fmt_num(value))}</span>'
                f'<span class="hint">{esc(hint)}</span></dd></div>'
            )
        groups.append(
            f'<section class="wave-group" data-group="{esc(group)}">'
            f"<h4>{esc(title)}</h4>"
            f'<dl class="card-stats">{"".join(tiles)}</dl></section>'
        )
    return (
        f'<article class="item-panel" id="entry-waves-{number}" data-item="waves-{number}">'
        f"<h3>第 {number} 波</h3>"
        f'<p class="wave-scale"><span class="wave-scale-label">相对第 1 波</span>'
        f'<span class="scale-chip">生命 ×{esc(fmt_num(hp_ratio))}</span>'
        f'<span class="scale-chip">移速 ×{esc(fmt_num(speed_ratio))}</span></p>'
        f'{"".join(groups)}</article>'
    )


def _icon_toggle(input_id: str, label: str, slug: str, kind: str, checked: str, name: str = "") -> str:
    name_attr = f' name="{esc(name)}"' if name else ""
    input_type = "radio" if name else "checkbox"
    return (
        f'<label class="{kind}" title="{esc(label)}">'
        f'<input type="{input_type}" id="{esc(input_id)}"{name_attr}{checked} '
        f'aria-label="{esc(label)}">'
        f"{glyph(slug)}</label>"
    )


def _skin_switch_css(catalog: dict) -> str:
    count = 0
    for items in catalog["sections"].values():
        for item in items:
            count = max(count, len(item.get("skins") or []))
    lines = []
    for index in range(1, count + 1):
        lines.append(
            ".preview:has(.skin-opt:nth-child(%d) input:checked) "
            ".skin-frame:nth-child(%d) { display: block; }" % (index, index)
        )
    return "\n".join(lines)


def _mark_anchor(anchor: str) -> str:
    return (
        f'.codex:has(#{anchor}:target) a[href="#{anchor}"] '
        "{ background: var(--text); color: var(--bg); font-weight: 700; }"
    )


def build_codex_view(catalog: dict) -> tuple:
    """Left rail: module icons, then anchors into that module's page.

    Switching a module replaces the main column with every card or wave in
    that module. A level-2 link only sets the hash so the same page scrolls
    to that entry. Below 1100px the rail is a drawer; below 768px each card
    stacks in one column.
    """
    if NARROW_MQ not in CODEX_LAYOUT_CSS:
        die("layout CSS is missing the drawer breakpoint")
    _wave_columns()
    modules = []
    for key, title, blurb in CODEX_MODULES:
        items = catalog["waves"] if key == "waves" else catalog["sections"][key]
        modules.append((key, title, blurb, items))

    module_btns = []
    item_navs = []
    sections = []
    rules = []
    for index, (key, title, blurb, items) in enumerate(modules):
        checked = " checked" if index == 0 else ""
        module_btns.append(
            _icon_toggle(f"sec-{key}", title, key, "mod-btn", checked, "codex-sec")
            .replace("</label>", f"<span>{esc(title)}</span></label>", 1)
        )
        links = []
        panels = []
        rules.append(
            f'.codex:has(#sec-{key}:checked) .item-nav[data-for="{key}"] {{ display: flex; }}'
        )
        rules.append(
            f'.codex:has(#sec-{key}:checked) .codex-section[data-section="{key}"] {{ display: block; }}'
        )
        if key == "waves":
            ref = items[0]
            for row in items:
                number = int(row["wave"])
                anchor = _anchor("waves", str(number))
                links.append(
                    f'<a class="item-link" href="#{esc(anchor)}" title="第 {number} 波">'
                    f'<span class="wave-mark">{number}</span><span>第 {number} 波</span></a>'
                )
                panels.append(_wave_panel(row, ref))
                rules.append(_mark_anchor(anchor))
                rules.append(
                    f'.codex:has(#{anchor}:target) a[href="#{anchor}"] .wave-mark '
                    "{ background: var(--bg); color: var(--text); }"
                )
            extra = f'<p class="footnote">{esc(WAVE_FOOTNOTE)}</p>'
        else:
            for item in items:
                item_id = str(item["id"])
                anchor = _anchor(key, item_id)
                links.append(
                    f'<a class="item-link" href="#{esc(anchor)}" title="{esc(item["name_zh"])}">'
                    f'<img src="{esc(item["portrait"])}" alt="">'
                    f'<span>{esc(item["name_zh"])}</span></a>'
                )
                panels.append(_detail_panel(item, key, item_id))
                rules.append(_mark_anchor(anchor))
            extra = render_economy(catalog["economy"]) if key == "buildings" else ""
        item_navs.append(
            f'<div class="item-nav" data-for="{esc(key)}">{"".join(links)}</div>'
        )
        sections.append(
            f'<section class="codex-section" id="{esc(key)}" data-section="{esc(key)}">'
            f"<header><h2>{esc(title)}</h2><p>{esc(blurb)}</p></header>"
            f'{"".join(panels)}{extra}</section>'
        )
    shell = (
        '<div class="codex" id="codex">'
        '<input class="codex-drawer" type="checkbox" id="codex-drawer" aria-label="打开目录">'
        '<div class="codex-shell">'
        '<label class="codex-backdrop" for="codex-drawer" aria-hidden="true"></label>'
        '<aside class="codex-aside" aria-label="图鉴目录">'
        '<div class="drawer-bar">'
        '<p class="rail-kicker">目录</p>'
        '<label class="drawer-close" for="codex-drawer" title="关闭">'
        f'<span class="sr">关闭</span>{glyph("close")}</label>'
        "</div>"
        '<div class="rail-block"><p class="rail-kicker">模块</p>'
        f'<div class="mod-row">{"".join(module_btns)}</div></div>'
        '<div class="rail-block"><p class="rail-kicker">条目</p>'
        f'{"".join(item_navs)}</div>'
        "</aside>"
        '<div class="codex-main">'
        '<div class="codex-toolbar">'
        '<label class="codex-drawer-btn" for="codex-drawer" title="目录">'
        f'<span class="sr">打开目录</span>{glyph("menu")}</label>'
        "</div>"
        f'{"".join(sections)}'
        "</div></div>"
        "<script>"
        "(function () {"
        'var root = document.getElementById("codex");'
        "if (!root) return;"
        'var drawer = document.getElementById("codex-drawer");'
        "if (!drawer) return;"
        f'var narrowQuery = window.matchMedia("{NARROW_MQ}");'
        "function narrow() { return narrowQuery.matches; }"
        "function syncDrawer() {"
        'document.body.style.overflow = drawer.checked && narrow() ? "hidden" : "";'
        "if (drawer.checked && narrow()) {"
        'var current = root.querySelector(".mod-btn input:checked");'
        'var key = current ? current.id.replace("sec-", "") : "";'
        'var nav = key && root.querySelector(\'.item-nav[data-for="\' + key + \'"] a\');'
        "if (nav) nav.focus();"
        "}"
        "}"
        'drawer.addEventListener("change", syncDrawer);'
        'if (narrowQuery.addEventListener) {'
        'narrowQuery.addEventListener("change", function () {'
        "if (!narrow()) drawer.checked = false;"
        "syncDrawer();"
        "});"
        "}"
        'root.addEventListener("click", function (event) {'
        'var link = event.target.closest ? event.target.closest("a.item-link") : null;'
        "if (!link || !drawer.checked || !narrow()) return;"
        "drawer.checked = false;"
        "syncDrawer();"
        "});"
        'document.addEventListener("keydown", function (event) {'
        'if (event.key === "Escape" && drawer.checked) {'
        "drawer.checked = false; syncDrawer(); drawer.focus();"
        "}"
        "});"
        "})();"
        "</script></div>"
    )
    return shell, "\n".join((CODEX_LAYOUT_CSS, _skin_switch_css(catalog), "\n".join(rules), ""))


CODEX_LAYOUT_CSS = """
.codex { position: relative; }
.codex-shell {
  display: grid; grid-template-columns: 252px minmax(0, 1fr);
  gap: 20px; align-items: start; padding-bottom: 28px;
}
.sr {
  position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0;
  overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
.codex-drawer, .mod-btn input, .skin-opt input {
  position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0;
  overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
.codex-aside {
  position: sticky; top: 16px; align-self: start;
  max-height: calc(100vh - 32px); overflow: auto;
  background: var(--card); border: 1px solid var(--line); border-radius: 18px;
  box-shadow: var(--shadow); padding: 12px;
}
.drawer-bar, .codex-toolbar { display: none; }
.rail-kicker {
  margin: 0 0 6px; color: var(--muted); font-size: 12px; letter-spacing: .06em;
}
.rail-block + .rail-block { margin-top: 14px; }
.mod-row { display: flex; gap: 4px; }
.mod-btn, .item-link, .codex-drawer-btn, .drawer-close, .skin-opt {
  position: relative; cursor: pointer; user-select: none; color: var(--text);
}
.mod-btn {
  flex: 1 1 0; display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 2px; min-width: 0; min-height: 48px; padding: 6px 2px;
  border-radius: 14px; border: 1px solid transparent; background: var(--chip);
  font-size: 12px; line-height: 1.2;
}
.mod-btn svg, .codex-drawer-btn svg, .drawer-close svg {
  width: 22px; height: 22px; fill: none; stroke: currentColor;
  stroke-width: 1.75; stroke-linecap: round; stroke-linejoin: round;
}
.mod-btn:has(input:checked) { background: var(--text); color: var(--bg); }
.item-nav { display: none; flex-direction: column; gap: 4px; }
.item-link {
  display: flex; align-items: center; gap: 8px;
  min-height: 44px; padding: 6px 8px; border-radius: 12px; border: 1px solid transparent;
  font-size: 14px; color: inherit; text-decoration: none;
}
.item-link img, .wave-mark {
  width: 32px; height: 32px; flex: 0 0 32px; border-radius: 8px;
  background: var(--well); object-fit: contain;
}
.wave-mark {
  display: grid; place-items: center; font-weight: 700; font-size: 13px;
}
.item-link:hover, .mod-btn:hover, .skin-opt:hover { border-color: var(--gold); }
.mod-btn:focus-within, .codex-drawer-btn:focus-within, .drawer-close:focus-within,
.item-link:focus-visible, .skin-opt:focus-within {
  outline: 2px solid var(--gold); outline-offset: 2px;
}
.codex-main { min-width: 0; padding-bottom: calc(100vh - 8rem); }
.codex-section { display: none; margin: 0; }
.codex-section > header h2 {
  margin: 0; font-size: clamp(28px, 2.4vw, 36px); line-height: 1.15;
}
.codex-section > header p {
  margin: 8px 0 16px; max-width: 68ch; color: var(--muted);
}
.codex .item-panel { padding: 16px; }
.item-panel { scroll-margin-top: 16px; }
.item-panel + .item-panel { margin-top: 16px; }
.item-panel:target { box-shadow: inset 0 0 0 2px var(--gold), var(--shadow); }
.detail {
  display: grid; grid-template-columns: minmax(216px, 248px) minmax(0, 1fr);
  gap: 16px; align-items: start;
}
.preview { display: flex; flex-direction: column; gap: 10px; min-width: 0; }
.detail-copy { min-width: 0; }
.identity h3 { margin: 0; }
.identity .badge { margin-top: 8px; }
.detail .portrait { aspect-ratio: 1; width: 100%; }
.skin-frame { display: none; }
.skins { display: flex; flex-wrap: wrap; gap: 6px; margin: 0; }
.skin-opt {
  display: grid; place-items: center; width: 44px; height: 44px; flex: 0 0 44px;
  margin: 0; padding: 0; border-radius: 12px; border: 1px solid var(--line);
  background: var(--well);
}
.skin-opt img { width: 30px; height: 30px; object-fit: contain; pointer-events: none; }
.skin-opt:has(input:checked) {
  border-color: var(--gold); box-shadow: inset 0 0 0 2px var(--gold);
}
dl.card-stats {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 10px; margin: 12px 0 0;
}
.stat-tile {
  background: var(--well); border-radius: 14px; padding: 10px 12px; min-width: 0;
}
.stat-tile.is-present { box-shadow: inset 0 0 0 1px var(--gold); }
.stat-tile dt { font-size: 13px; font-weight: 650; }
.stat-tile dd {
  margin: 2px 0 0; text-align: left; font-size: 22px; font-weight: 700;
  line-height: 1.25; overflow-wrap: anywhere;
  font-variant-numeric: tabular-nums;
}
.stat-tile.is-zero dd, .stat-tile.is-zero .wave-num { color: var(--muted); font-weight: 600; }
.wave-num { display: block; line-height: 1.15; }
.stat-tile .hint { display: block; margin-top: 2px; color: var(--muted); font-size: 12px; font-weight: 400; }
.wave-scale {
  display: flex; flex-wrap: wrap; align-items: center; gap: 8px;
  margin: 8px 0 0; color: var(--muted); font-size: 14px;
}
.scale-chip {
  background: var(--well); color: var(--text); border-radius: 999px; padding: 4px 12px;
}
.wave-group { margin: 16px 0 0; }
.wave-group h4 {
  margin: 0 0 8px; color: var(--muted); font-size: 13px; font-weight: 650; letter-spacing: .04em;
}
.codex .footnote, .codex .callout { margin-top: 16px; }
.codex-drawer:focus-visible ~ .codex-shell .codex-drawer-btn {
  outline: 2px solid var(--gold); outline-offset: 2px;
}
.codex-backdrop { display: none; }
@media (max-width: 1099px) {
  body { overflow-x: clip; }
  .codex-shell { grid-template-columns: 1fr; gap: 0; }
  .codex-toolbar {
    display: flex; align-items: center; position: sticky; top: 0; z-index: 30;
    min-height: 64px;
    margin: 0 calc(50% - 50vw) 20px;
    padding: max(10px, env(safe-area-inset-top)) max(var(--gutter), env(safe-area-inset-right)) 10px max(var(--gutter), env(safe-area-inset-left));
    background: var(--bg);
    border-bottom: 1px solid var(--line);
  }
  .codex-drawer-btn {
    display: inline-grid; place-items: center; width: 48px; height: 48px;
    border-radius: 14px; border: 1px solid var(--line); background: var(--card); color: var(--text);
    box-shadow: var(--shadow);
  }
  .item-panel { scroll-margin-top: 88px; }
  .drawer-bar {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    position: sticky; top: 0; z-index: 2;
    margin: -14px -14px 12px;
    padding: max(12px, env(safe-area-inset-top)) 14px 10px;
    background: var(--card);
    border-bottom: 1px solid var(--line);
  }
  .drawer-bar .rail-kicker { margin: 0; font-size: 13px; }
  .drawer-close {
    display: grid; place-items: center; width: 44px; height: 44px; flex: 0 0 44px;
    border-radius: 12px; border: 1px solid var(--line); background: var(--chip);
  }
  .codex-drawer:checked ~ .codex-shell .codex-backdrop {
    display: block; position: fixed; inset: 0; z-index: 40;
    background: var(--scrim);
  }
  .codex-aside {
    position: fixed; z-index: 41; top: 0; left: 0; right: auto;
    width: min(22rem, calc(100vw - 48px)); height: 100vh; height: 100dvh; max-height: none;
    border-radius: 0 18px 18px 0;
    box-shadow: 16px 0 40px rgba(70, 42, 14, .22);
    transform: translateX(-105%); visibility: hidden;
    transition: transform .18s ease, visibility .18s ease;
    overscroll-behavior: contain;
    padding: 14px 14px max(16px, env(safe-area-inset-bottom));
  }
  .codex-drawer:checked ~ .codex-shell .codex-aside {
    transform: translateX(0); visibility: visible;
  }
  .mod-row { flex-wrap: wrap; gap: 6px; }
  .mod-btn { flex: 1 1 56px; min-width: 52px; min-height: 52px; }
  .item-nav { gap: 6px; }
  .item-link { min-height: 48px; padding: 8px 10px; }
  .item-link img, .wave-mark { width: 36px; height: 36px; flex-basis: 36px; }
}
@media (min-width: 768px) and (max-width: 1099px) {
  .detail { grid-template-columns: minmax(200px, 240px) minmax(0, 1fr); gap: 18px; }
}
@media (max-width: 767px) {
  .codex-section > header { margin-bottom: 4px; }
  .codex-section > header h2 { font-size: 26px; }
  .codex-section > header p { margin: 8px 0 14px; font-size: 15px; }
  .codex .item-panel { padding: 16px; }
  .item-panel + .item-panel { margin-top: 18px; }
  .detail {
    grid-template-columns: 148px minmax(0, 1fr);
    grid-template-areas:
      "portrait identity"
      "skins skins"
      "stats stats"
      "note note";
    gap: 12px 14px;
    align-items: center;
  }
  .preview, .detail-copy { display: contents; }
  .detail .portrait { grid-area: portrait; width: 148px; }
  .identity { grid-area: identity; min-width: 0; align-self: center; }
  .skins { grid-area: skins; justify-content: flex-start; width: auto; gap: 10px; }
  .detail .card-stats { grid-area: stats; margin: 0; }
  .detail .note { grid-area: note; margin: 0; }
  .skin-opt { width: 48px; height: 48px; flex-basis: 48px; }
  .skin-opt img { width: 34px; height: 34px; }
  dl.card-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
  .stat-tile { padding: 12px; }
  .stat-tile dd { font-size: clamp(16px, 4.8vw, 20px); }
  .codex .note { font-size: 14px; line-height: 1.55; }
  .wave-group h4 { margin-bottom: 8px; }
}
@media (min-width: 1100px) {
  .codex-drawer { display: none; }
}
@media (prefers-reduced-motion: no-preference) {
  html { scroll-behavior: smooth; }
}
@media (prefers-reduced-motion: reduce) {
  .codex-aside { transition: none; }
}
"""


def render_economy(economy: dict) -> str:
    return (
        '<p class="callout">击杀只掉金币。清完一波：木材 '
        f"{int(economy['wave_clear_wood'])} + 每座农场 × {fmt_num(economy['farm_wood'])}，"
        f"金币 +{int(economy['wave_clear_gold'])}。"
        f"木坊按驻守村民产木：每 {fmt_num(economy['lumber_interval'])} 秒、每名村民 +{fmt_num(economy['lumber_rate'])} 木，"
        f"上限 {int(economy['lumber_slots'])} 人，空坊为 0。"
        f"清波入驻概率 {fmt_num(economy['settle_chance'])}，每类 1～min({int(economy['settle_max'])}, 空缺)。"
        "房屋床位是村民空缺，矛兵营/枪兵营是对应兵种空缺，工坊是工兵空缺。"
        f"塔立着就会攻击。工坊把塔的攻击 ×{fmt_num(economy['workshop_tower_damage'])}，"
        "先乘攻击再套伤害公式，不叠加。</p>"
    )


def esc(value) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def economy_from(main_gd: str, buildings: list, setup: dict) -> dict:
    wood = read_const(main_gd, "WAVE_CLEAR_WOOD")
    gold = read_const(main_gd, "WAVE_CLEAR_GOLD")
    farm = next((entry for entry in buildings if entry.get("id") == "farm"), None)
    workshop = next((entry for entry in buildings if entry.get("id") == "workshop"), None)
    mill = next((entry for entry in buildings if entry.get("id") == "lumber_mill"), None)
    produces = (farm or {}).get("produces") or {}
    bonus = (workshop or {}).get("bonus") or {}
    mill_out = (mill or {}).get("produces") or {}
    settle = setup.get("settlement") or {}
    if produces.get("rate") is None or bonus.get("tower_damage") is None:
        die("farm.produces.rate and workshop.bonus.tower_damage are required")
    if mill_out.get("mode") != "staff" or mill_out.get("rate_per_villager") is None:
        die("lumber_mill.produces must be mode staff with rate_per_villager")
    if "chance" not in settle or "max_per_wave" not in settle:
        die("data/setup.json settlement needs chance and max_per_wave")
    return {
        "wave_clear_wood": int(wood),
        "wave_clear_gold": int(gold),
        "farm_wood": produces["rate"],
        "workshop_tower_damage": bonus["tower_damage"],
        "lumber_rate": mill_out["rate_per_villager"],
        "lumber_interval": mill_out.get("interval", 0),
        "lumber_slots": int((mill or {}).get("staff_slots") or 0),
        "settle_chance": settle["chance"],
        "settle_max": settle["max_per_wave"],
    }


def _check_skin_switcher(html: str) -> None:
    start = html.find('data-item="units-villager"')
    end = html.find('data-item="units-spearman"')
    if start < 0 or end < start:
        die("villager card is missing from the codex page")
    block = html[start:end]
    if "<div class=\"portrait\">" not in block or "<div class=\"skins\"" not in block:
        die("villager needs a portrait and a skin thumbnail list")
    portrait = block.split('<div class="portrait">', 1)[1]
    inside, _, after = portrait.partition("</div>")
    if "skin-opt" in inside or "skin-frame" not in inside:
        die("skin thumbnails must not sit inside the preview")
    if not after.lstrip().startswith('<div class="skins"'):
        die("skin thumbnail list must follow the preview")
    if "max-width: 767px" not in html or NARROW_MQ not in html:
        die("responsive breakpoints missing from the codex page")
    if "返回游戏" in html:
        die("codex page must not include 返回游戏")
    if 'id="codex-refresh"' not in html or ">刷新</button>" not in html:
        die("codex page needs a 刷新 button")
    if "vtd.setup" not in html or "config_version" not in html:
        die("codex refresh must compare the local config version")


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

    for name in ("data/units.json", "data/enemies.json", "data/buildings.json", "data/setup.json"):
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
    setup = load_json(ROOT / "data" / "setup.json")
    if int(setup.get("config_version", 0)) < 1:
        die("data/setup.json needs config_version")
    economy = economy_from(main_gd, buildings, setup)

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
        "config_version": int(setup["config_version"]),
        "setup": {key: value for key, value in setup.items() if key != "_comment"},
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    page = render_page(catalog)
    _check_skin_switcher(page)
    (OUT / "index.html").write_text(page, encoding="utf-8")
    counts = catalog["counts"]
    total = sum(counts.values())
    print(
        f"codex: {counts['units']} units, {counts['enemies']} enemies, "
        f"{counts['buildings']} buildings, {counts['scenery']} scenery ({total} cards)"
    )


if __name__ == "__main__":
    main()
