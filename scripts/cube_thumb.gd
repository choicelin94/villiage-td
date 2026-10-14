class_name CubeThumb
extends Control

# Palette chip and the painter for pieces on the workbench map.
# Props, buildings, and units use the same textures and anchors as the match.
# A unit is the idle frame, with its foot on the cell center.

signal chosen(payload: Dictionary)

var layer := ""
var item_id := ""
var volume_key := "walker"
var tint := Color.WHITE
var label_key := ""
var click_places := false
var _font: Font
var _armed := false
var _dragged := false

const _TREES: Array[String] = [
	"res://assets/village/tree.png",
	"res://assets/village/tree_b.png",
	"res://assets/village/tree_c.png",
]
const _ROCK := "res://assets/village/rock.png"

static var _tex_cache: Dictionary = {}
static var _chars: Dictionary = {}

func _ready() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	custom_minimum_size = Vector2(78, 104)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func _get_drag_data(_at_position: Vector2) -> Variant:
	_dragged = true
	if is_inside_tree() and get_viewport().gui_is_dragging():
		var preview := CubeThumb.new()
		preview.layer = layer
		preview.item_id = item_id
		preview.volume_key = volume_key
		preview.tint = tint
		preview.label_key = ""
		preview.custom_minimum_size = Vector2(72, 72)
		preview.size = Vector2(72, 72)
		set_drag_preview(preview)
	return {"layer": layer, "id": item_id, "volume": volume_key, "tint": tint}

func _gui_input(event: InputEvent) -> void:
	if not click_places:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_armed = true
			_dragged = false
		elif _armed and not _dragged:
			_armed = false
			chosen.emit({"layer": layer, "id": item_id, "volume": volume_key, "tint": tint})
			accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.15, 0.12, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.58, 0.28, 0.9), false, 2.0)
	var area := Rect2(6, 4, maxf(size.x - 12.0, 8.0), maxf(size.y - 32.0, 8.0))
	draw_fitted(self, area, layer, item_id)
	if _font == null or label_key == "":
		return
	var text := Locale.text(label_key)
	draw_string(_font, Vector2(2, size.y - 8), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 14, Color(1, 0.95, 0.82))

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
		var path := _ROCK if id == "rock" else _TREES[posmod(cell.x + cell.y, _TREES.size())]
		var tex := _tex(path)
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
	var tex := _tex(str(sheets[posmod(Balance.skin_index(character, skin_name), sheets.size())]))
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	if parsed is Dictionary:
		_chars = parsed

static func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		var cached = _tex_cache[path]
		return cached if cached is Texture2D else null
	var tex: Texture2D = load(path)
	_tex_cache[path] = tex
	return tex
