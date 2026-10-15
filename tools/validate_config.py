#!/usr/bin/env python3
"""Check config/ against its manifest and JSON Schemas.

    python3 tools/validate_config.py

Requires jsonschema. Exits 0 when the shipped catalogs, layout, and
presentation files agree with each other.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    sys.exit("validate_config.py needs jsonschema. Install it with: pip install jsonschema")

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config"
COLS = 20
ROWS = 20
CORNERS = {(0, 0), (COLS - 1, 0), (0, ROWS - 1), (COLS - 1, ROWS - 1)}
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
KIND_VOLUME = {
    "WALL": "wall",
    "SPEAR": "spear",
    "FIRE": "fire",
    "HOUSE": "house",
    "FARM": "farm",
    "WORKSHOP": "workshop",
    "LUMBER": "lumber",
    "SPEAR_BARRACKS": "spear_barracks",
    "GUN_BARRACKS": "gun_barracks",
}


def die(message: str) -> None:
    sys.exit(f"validate_config: {message}")


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        die(f"missing {path.relative_to(ROOT)}")
    except json.JSONDecodeError as exc:
        die(f"{path.relative_to(ROOT)} is not valid JSON ({exc})")


def resolve_res(res: str) -> Path:
    if not str(res).startswith("res://"):
        die(f"expected a res:// path, got {res}")
    rel = str(res)[len("res://") :]
    path = ROOT / rel
    if path.is_file():
        return path
    if rel.startswith("art/"):
        alt = ROOT / "assets" / rel[len("art/") :]
        if alt.is_file():
            return alt
    if rel.startswith("assets/"):
        alt = ROOT / "art" / rel[len("assets/") :]
        if alt.is_file():
            return alt
    die(f"missing file for {res}")


def cells_of(rect: dict) -> list[tuple[int, int]]:
    edge = rect["edge"]
    x, y = int(rect["middle"][0]), int(rect["middle"][1])
    if edge == "north":
        row = [(x - 1, 0), (x, 0), (x + 1, 0)]
    elif edge == "south":
        row = [(x - 1, ROWS - 1), (x, ROWS - 1), (x + 1, ROWS - 1)]
    elif edge == "west":
        row = [(0, y - 1), (0, y), (0, y + 1)]
    elif edge == "east":
        row = [(COLS - 1, y - 1), (COLS - 1, y), (COLS - 1, y + 1)]
    else:
        die(f"unknown spawn edge {edge}")
    return row


ROCKS = {(4, 8), (16, 8), (4, 16), (16, 16)}


def check_spawn(setup: dict) -> None:
    if len(setup["spawn_rects"]) != 1:
        die("exactly one spawn rect is allowed")
    derived: list[tuple[int, int]] = []
    seen_middle = set()
    for rect in setup["spawn_rects"]:
        edge = rect["edge"]
        middle = (int(rect["middle"][0]), int(rect["middle"][1]))
        if middle in CORNERS:
            die(f"spawn middle {middle} is a corner")
        if edge in ("north", "south") and middle[1] != (0 if edge == "north" else ROWS - 1):
            die(f"{edge} gate middle {middle} is not on that edge")
        if edge in ("west", "east") and middle[0] != (0 if edge == "west" else COLS - 1):
            die(f"{edge} gate middle {middle} is not on that edge")
        if not (1 <= (middle[0] if edge in ("north", "south") else middle[1]) <= (COLS if edge in ("north", "south") else ROWS) - 2):
            die(f"spawn middle {middle} cannot hold a 3x1 gate")
        if middle in seen_middle:
            die(f"duplicate spawn middle {middle}")
        seen_middle.add(middle)
        row = cells_of(rect)
        horizontal = edge in ("north", "south")
        ys = {cell[1] for cell in row}
        xs = {cell[0] for cell in row}
        if horizontal and (len(ys) != 1 or len(xs) != 3):
            die(f"{edge} gate {middle} is not horizontal 3x1")
        if not horizontal and (len(xs) != 1 or len(ys) != 3):
            die(f"{edge} gate {middle} is not vertical 3x1")
        for cell in row:
            if cell not in derived:
                derived.append(cell)
    listed = [(int(pair[0]), int(pair[1])) for pair in setup["spawns"]]
    if listed != derived:
        die("spawns must be rebuilt from spawn_rects, in that order, without duplicates")
    if "roads" not in setup:
        return
    roads = setup["roads"]
    if not isinstance(roads, list):
        die("roads must be a list of cells")
    seen = set()
    for pair in roads:
        if not isinstance(pair, (list, tuple)) or len(pair) != 2:
            die("road cell must be [x, y]")
        cell = (int(pair[0]), int(pair[1]))
        if not (0 <= cell[0] < COLS and 0 <= cell[1] < ROWS):
            die(f"road cell {cell} is outside the map")
        if cell in ROCKS:
            die(f"road cell {cell} is a fixed rock")
        seen.add(cell)


def cross(o, a, b) -> float:
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def check_volumes(volumes: dict) -> None:
    for key, spec in volumes.items():
        shape = spec.get("shape")
        if shape == "ellipse":
            if float(spec.get("rx", 0)) <= 0 or float(spec.get("ry", 0)) <= 0:
                die(f"volume {key} ellipse needs positive rx and ry")
        elif shape == "poly":
            poly = spec.get("poly")
            if not isinstance(poly, list) or len(poly) < 3:
                die(f"volume {key} poly needs at least 3 points")
            points = [(float(p[0]), float(p[1])) for p in poly]
            signs = []
            n = len(points)
            for i in range(n):
                value = cross(points[i], points[(i + 1) % n], points[(i + 2) % n])
                if abs(value) > 1e-9:
                    signs.append(value > 0)
            if signs and any(sign != signs[0] for sign in signs):
                die(f"volume {key} poly is not convex")
        else:
            die(f"volume {key} has unknown shape")


def check_refs(units, enemies, buildings, characters, volumes) -> None:
    unit_ids = {entry["id"] for entry in units["units"]}
    enemy_ids = {entry["id"] for entry in enemies["enemies"]}
    building_ids = {entry["id"] for entry in buildings["buildings"]}
    if not REQUIRED_UNITS <= unit_ids:
        die(f"units missing {sorted(REQUIRED_UNITS - unit_ids)}")
    if not REQUIRED_ENEMIES <= enemy_ids:
        die(f"enemies missing {sorted(REQUIRED_ENEMIES - enemy_ids)}")
    if not REQUIRED_BUILDINGS <= building_ids:
        die(f"buildings missing {sorted(REQUIRED_BUILDINGS - building_ids)}")
    if len(enemies["waves"]) != 10:
        die("enemies.json must keep 10 waves")
    for entry in units["units"]:
        if entry["character"] not in characters:
            die(f"unit {entry['id']} character {entry['character']} is missing")
    for entry in enemies["enemies"]:
        if entry["character"] not in characters:
            die(f"enemy {entry['id']} character {entry['character']} is missing")
    for entry in buildings["buildings"]:
        resolve_res(entry["tex"])
        kind = entry["kind"]
        if kind in KIND_VOLUME and KIND_VOLUME[kind] not in volumes:
            die(f"building {entry['id']} volume {KIND_VOLUME[kind]} is missing")
    for key, spec in characters.items():
        sheets = spec["sheets"]
        skins = spec["skins"]
        if len(sheets) != len(skins) and not (len(sheets) == 1 or len(skins) == 1):
            die(f"character {key} sheets and skins should pair, or one side is a single shared sheet")
        for sheet in sheets:
            resolve_res(sheet)
        spine = spec.get("spine") or {}
        for field in ("json", "atlas"):
            if field in spine:
                resolve_res(spine[field])


def main() -> None:
    manifest_path = CONFIG / "manifest.json"
    manifest = load(manifest_path)
    schema_root = CONFIG / "schema"
    jsonschema.validate(manifest, load(schema_root / "manifest.schema.json"))
    seen = []
    docs = {}
    for item in manifest["files"]:
        rel = item["path"]
        if rel in seen:
            die(f"manifest lists {rel} twice")
        seen.append(rel)
        doc_path = CONFIG / rel
        schema_path = CONFIG / item["schema"]
        if not schema_path.is_file():
            die(f"missing schema {item['schema']}")
        doc = load(doc_path)
        jsonschema.validate(doc, load(schema_path))
        docs[rel] = doc
    setup = docs["layout/setup.json"]
    if int(setup["config_version"]) != int(manifest["config_version"]):
        die("manifest config_version must match layout/setup.json")
    check_spawn(setup)
    check_volumes(docs["presentation/volumes.json"])
    check_refs(
        docs["balance/units.json"],
        docs["balance/enemies.json"],
        docs["balance/buildings.json"],
        docs["presentation/characters.json"],
        docs["presentation/volumes.json"],
    )
    print("validate_config: ok")


if __name__ == "__main__":
    main()
