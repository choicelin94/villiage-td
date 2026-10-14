class_name ActorPainter
extends RefCounted

# Draws a prop, building, or unit from presentation JSON and art files.
# The workbench map uses this directly. It does not instance combat nodes.

const _TREES: Array[String] = [
	"village/tree.png",
	"village/tree_b.png",
	"village/tree_c.png",
]
const _ROCK := "village/rock.png"

static var _tex_cache: Dictionary = {}
static var _chars: Dictionary = {}


static func has_art(p_layer: String, id: String) -> bool:
	var placed := _placed(p_layer, id, Vector2i.ZERO, 0)
	if placed.is_empty() or placed.get("tex") == null:
		return false
	var dest: Rect2 = placed.dest
	return dest.size.x > 8.0 and dest.size.y > 8.0


static func draw_actor(item: CanvasItem, cell: Vector2i, p_layer: String, id: String, alpha: float = 1.0, skin_cycle: int = -1) -> void:
	var placed := _placed(p_layer, id, cell, skin_cycle)
	if placed.is_empty():
		return
	_blit(item, placed, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))


static func draw_fitted(item: CanvasItem, area: Rect2, p_layer: String, id: String) -> void:
	var placed := _placed(p_layer, id, Vector2i.ZERO, -1)
	if placed.is_empty():
		return
	var dest: Rect2 = placed.dest
	var span := dest.size
	span.x = maxf(span.x, 1.0)
	span.y = maxf(span.y, 1.0)
	var fitted := minf(area.size.x / span.x, area.size.y / span.y) * 0.92
	var used := span * fitted
	var origin := area.position + (area.size - used) * 0.5
	var fitted_place := placed.duplicate()
	fitted_place["dest"] = Rect2(origin, used)
	_blit(item, fitted_place, Color.WHITE)


static func _blit(item: CanvasItem, placed: Dictionary, color: Color) -> void:
	var tex: Texture2D = placed.tex
	var dest: Rect2 = placed.dest
	if tex == null:
		return
	if placed.has("region"):
		item.draw_texture_rect_region(tex, dest, placed.region, color)
	else:
		item.draw_texture_rect(tex, dest, false, color)


static func _placed(p_layer: String, id: String, cell: Vector2i, skin_cycle: int) -> Dictionary:
	var center := Vector2(MapPlan.TILE * (float(cell.x) + 0.5), MapPlan.TILE * (float(cell.y) + 0.5))
	if p_layer == "prop":
		var rel := _ROCK if id == "rock" else _TREES[posmod(cell.x + cell.y, _TREES.size())]
		var tex := _tex(rel)
		if tex == null:
			return {}
		var anchor := IsoVolume.ROCK_ANCHOR if id == "rock" else IsoVolume.TREE_ANCHOR
		return {"tex": tex, "dest": Rect2(center + anchor, tex.get_size())}
	if p_layer == "build":
		var def := Balance.building_by_kind(id)
		var tex := _tex(str(def.get("tex", "")))
		if tex == null:
			return {}
		var size := tex.get_size()
		var origin := center + Vector2(-size.x * 0.5, IsoVolume.HALF - size.y)
		return {"tex": tex, "dest": Rect2(origin, size)}
	if p_layer == "unit":
		return _unit_placed(id, center, skin_cycle)
	return {}


static func _unit_placed(unit_id: String, center: Vector2, skin_cycle: int) -> Dictionary:
	_boot_chars()
	var def := Balance.unit(unit_id)
	if def.is_empty():
		def = Balance.unit("villager")
		unit_id = "villager"
	var character := str(def.get("character", "villager"))
	var spec: Dictionary = _chars.get(character, {})
	if spec.is_empty():
		return {}
	var skin_name := str(def.get("skin", "wolf"))
	if unit_id == "villager" and skin_cycle >= 0:
		var pool: Array = Balance.villager_skin_pool()
		if not pool.is_empty():
			skin_name = str(pool[posmod(skin_cycle, pool.size())])
	var sheets: Array = spec.get("sheets", [])
	if sheets.is_empty():
		return {}
	var sheet_i := posmod(Balance.skin_index(character, skin_name), sheets.size())
	var tex := _tex(str(sheets[sheet_i]))
	if tex == null:
		return {}
	var frame: Array = spec.get("frame", [128, 128])
	var fw := float(frame[0])
	var fh := float(frame[1])
	var foot: Array = spec.get("foot", [fw * 0.5, fh])
	var clips: Dictionary = spec.get("clips", {})
	var idle: Dictionary = clips.get("idle", {})
	var row := float(idle.get("row", 0))
	var region := Rect2(0, row * fh, fw, fh)
	var origin := center + Vector2(-float(foot[0]), -float(foot[1]))
	return {"tex": tex, "dest": Rect2(origin, Vector2(fw, fh)), "region": region}


static func _boot_chars() -> void:
	if not _chars.is_empty():
		return
	var path := CatalogPaths.config_file("presentation/characters.json")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_chars = parsed


static func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	var resolved := path
	if path.begins_with("res://"):
		resolved = CatalogPaths.resolve(path)
	else:
		resolved = CatalogPaths.art_file(path)
	if _tex_cache.has(resolved):
		var cached = _tex_cache[resolved]
		return cached if cached is Texture2D else null
	var tex := CatalogPaths.load_tex(resolved)
	_tex_cache[resolved] = tex
	return tex
