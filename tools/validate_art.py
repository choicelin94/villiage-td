#!/usr/bin/env python3
"""Check that art/ holds the binaries the config catalogs point at.

    python3 tools/validate_art.py

PNG files must be real PNG. The font must be present. A leftover assets/
tree may only be symlinks into art/, so the binary source of truth stays one place.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
CONFIG = ROOT / "config"
PNG = b"\x89PNG\r\n\x1a\n"
REQUIRED = [
    "characters/villager_0.png",
    "characters/villager_1.png",
    "characters/villager_2.png",
    "characters/villager_3.png",
    "characters/villager_4.png",
    "characters/villager_5.png",
    "characters/villager_6.png",
    "characters/spear.png",
    "characters/shooter.png",
    "village/grass_a.png",
    "village/grass_b.png",
    "village/road.png",
    "village/tree.png",
    "village/tree_b.png",
    "village/tree_c.png",
    "village/rock.png",
    "village/house.png",
    "village/farm.png",
    "village/workshop.png",
    "village/wall.png",
    "village/spear.png",
    "village/fire.png",
    "village/lumber.png",
    "village/spear_barracks.png",
    "village/gun_barracks.png",
    "fonts/NotoSansSC-Regular.otf",
]


def die(message: str) -> None:
    sys.exit(f"validate_art: {message}")


def resolve_res(res: str) -> Path:
    rel = str(res)[len("res://") :]
    path = ROOT / rel
    if path.is_file():
        return path
    if rel.startswith("assets/"):
        alt = ART / rel[len("assets/") :]
        if alt.is_file():
            return alt
    if rel.startswith("art/"):
        alt = ROOT / "assets" / rel[len("art/") :]
        if alt.is_file():
            return alt
    die(f"missing file for {res}")


def walk_strings(node, found: list[str]) -> None:
    if isinstance(node, dict):
        for value in node.values():
            walk_strings(value, found)
    elif isinstance(node, list):
        for value in node:
            walk_strings(value, found)
    elif isinstance(node, str) and node.startswith("res://"):
        found.append(node)


def main() -> None:
    for folder in ("characters", "village", "fonts"):
        if not (ART / folder).is_dir():
            die(f"missing art/{folder}")
    for rel in REQUIRED:
        path = ART / rel
        if not path.is_file():
            die(f"missing art/{rel}")
        if path.suffix.lower() == ".png":
            if path.read_bytes()[:8] != PNG:
                die(f"art/{rel} is not a PNG")
    font = ART / "fonts" / "NotoSansSC-Regular.otf"
    if font.stat().st_size < 1000:
        die("art/fonts/NotoSansSC-Regular.otf is too small to be the UI font")
    for path in ART.rglob("*.png"):
        if path.read_bytes()[:8] != PNG:
            die(f"{path.relative_to(ROOT)} is not a PNG")
    for path in ART.rglob("*.json"):
        if path.name.endswith(".import"):
            continue
        die(f"config JSON does not belong in art/: {path.relative_to(ROOT)}")
    refs: list[str] = []
    for path in CONFIG.rglob("*.json"):
        if "schema" in path.parts:
            continue
        walk_strings(json.loads(path.read_text(encoding="utf-8")), refs)
    art_refs = [ref for ref in refs if ref.startswith("res://art/") or ref.startswith("res://assets/")]
    if not art_refs:
        die("config does not reference any art files")
    for ref in art_refs:
        resolved = resolve_res(ref)
        if "art" not in resolved.parts and "assets" not in resolved.parts:
            die(f"{ref} resolved outside art")
    assets = ROOT / "assets"
    if assets.exists():
        for path in assets.rglob("*"):
            if path.is_symlink():
                continue
            if path.is_file():
                die(f"{path.relative_to(ROOT)} is a real file; move binaries to art/ and keep assets/ as links only")
    print("validate_art: ok")


if __name__ == "__main__":
    main()
