class_name IsoVolume
extends RefCounted

# Virtual ground box in iso tile space, plus a height. Depth never reads
# sprite pixels. HALF_W / HALF_H match the 176×98 diamond, including the
# TileMapLayer origin (cell 0,0 sits at (HALF_W, HALF_H)).

const HALF_W := 88.0
const HALF_H := 49.0

const TABLE := {
	"house": {"w": 1.0, "h": 1.0, "z": 2.2},
	"farm": {"w": 1.0, "h": 1.0, "z": 1.6},
	"workshop": {"w": 1.0, "h": 1.0, "z": 1.8},
	"wall": {"w": 0.9, "h": 0.9, "z": 1.15},
	"spear": {"w": 0.7, "h": 0.7, "z": 1.6},
	"fire": {"w": 0.6, "h": 0.6, "z": 1.3},
	"tree": {"w": 0.45, "h": 0.45, "z": 2.2},
	"rock": {"w": 0.62, "h": 0.62, "z": 0.7},
	"walker": {"w": 0.35, "h": 0.35, "z": 1.0},
}

var min_x := 0.0
var max_x := 0.0
var min_y := 0.0
var max_y := 0.0
var min_z := 0.0
var max_z := 1.0
var ground_poly_iso: PackedVector2Array = PackedVector2Array()
var sort_origin := Vector3.ZERO
var screen_rect := Rect2()
var node: Node2D

static var _table: Dictionary = {}

static func spec_for(key: String) -> Dictionary:
	_ensure()
	if _table.has(key):
		return _table[key]
	return TABLE[key]

static func _ensure() -> void:
	if not _table.is_empty():
		return
	var path := "res://data/iso_volumes.json"
	if not FileAccess.file_exists(path):
		_table = TABLE.duplicate(true)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_table = parsed
	else:
		_table = TABLE.duplicate(true)

static func world_to_iso(world: Vector2) -> Vector2:
	var dx := (world.x - HALF_W) / HALF_W
	var dy := (world.y - HALF_H) / HALF_H
	return Vector2((dx + dy) * 0.5, (dy - dx) * 0.5)

static func iso_to_world(iso: Vector2) -> Vector2:
	return Vector2(
		HALF_W + (iso.x - iso.y) * HALF_W,
		HALF_H + (iso.x + iso.y) * HALF_H
	)

static func from_cell(cell: Vector2i, key: String) -> IsoVolume:
	var spec: Dictionary = spec_for(key)
	var vol := IsoVolume.new()
	var cx := float(cell.x)
	var cy := float(cell.y)
	var hw := float(spec.w) * 0.5
	var hh := float(spec.h) * 0.5
	vol.min_x = cx - hw
	vol.max_x = cx + hw
	vol.min_y = cy - hh
	vol.max_y = cy + hh
	vol.min_z = 0.0
	vol.max_z = float(spec.z)
	vol.sort_origin = Vector3(cx, cy, 0.0)
	vol.ground_poly_iso = PackedVector2Array([
		Vector2(vol.min_x, vol.min_y),
		Vector2(vol.max_x, vol.min_y),
		Vector2(vol.max_x, vol.max_y),
		Vector2(vol.min_x, vol.max_y),
	])
	return vol

static func from_feet(world: Vector2) -> IsoVolume:
	var iso := world_to_iso(world)
	var spec: Dictionary = spec_for("walker")
	var vol := IsoVolume.new()
	var hw := float(spec.w) * 0.5
	var hh := float(spec.h) * 0.5
	vol.min_x = iso.x - hw
	vol.max_x = iso.x + hw
	vol.min_y = iso.y - hh
	vol.max_y = iso.y + hh
	vol.min_z = 0.0
	vol.max_z = float(spec.z)
	vol.sort_origin = Vector3(iso.x, iso.y, 0.0)
	vol.ground_poly_iso = PackedVector2Array([
		Vector2(vol.min_x, vol.min_y),
		Vector2(vol.max_x, vol.min_y),
		Vector2(vol.max_x, vol.max_y),
		Vector2(vol.min_x, vol.max_y),
	])
	return vol

static func sprite_rect(sprite: CanvasItem) -> Rect2:
	if sprite == null:
		return Rect2()
	var local := Rect2()
	if sprite is Sprite2D:
		local = (sprite as Sprite2D).get_rect()
	else:
		return Rect2()
	var xf := sprite.get_global_transform()
	var corners: Array[Vector2] = [
		local.position,
		local.position + Vector2(local.size.x, 0.0),
		local.position + Vector2(0.0, local.size.y),
		local.position + local.size,
	]
	var mn := xf * corners[0]
	var mx := mn
	for corner in corners:
		var g: Vector2 = xf * corner
		mn.x = minf(mn.x, g.x)
		mn.y = minf(mn.y, g.y)
		mx.x = maxf(mx.x, g.x)
		mx.y = maxf(mx.y, g.y)
	return Rect2(mn, mx - mn)

func depth_key() -> float:
	return sort_origin.x + sort_origin.y + sort_origin.z * 0.01
