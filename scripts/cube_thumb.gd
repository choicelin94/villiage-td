class_name CubeThumb
extends Control

# Palette thumbnail and the shared virtual-3D prism painter.
# The prism is the IsoVolume footprint extruded by the same lift IsoMark uses.

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
	draw_fitted(self, area, volume_key, tint)
	if _font == null or label_key == "":
		return
	var text := Locale.text(label_key)
	draw_string(_font, Vector2(2, size.y - 8), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 14, Color(1, 0.95, 0.82))

static func draw_world(item: CanvasItem, cell: Vector2i, volume_key: String, tint: Color) -> void:
	var ground := _ground(cell, volume_key)
	if ground.size() < 3:
		return
	var top := _lifted(ground, volume_key)
	_paint(item, ground, top, tint, 2.0)

static func draw_fitted(item: CanvasItem, area: Rect2, volume_key: String, tint: Color) -> void:
	var ground := _ground(Vector2i.ZERO, volume_key)
	if ground.size() < 3:
		return
	var top := _lifted(ground, volume_key)
	var min_p := ground[0]
	var max_p := ground[0]
	for p in ground:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	for p in top:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var span := max_p - min_p
	span.x = maxf(span.x, 1.0)
	span.y = maxf(span.y, 1.0)
	var fitted := minf(area.size.x / span.x, area.size.y / span.y) * 0.88
	var used := span * fitted
	var origin := area.position + (area.size - used) * 0.5 - min_p * fitted
	var g2 := PackedVector2Array()
	var t2 := PackedVector2Array()
	for p in ground:
		g2.append(origin + p * fitted)
	for p in top:
		t2.append(origin + p * fitted)
	_paint(item, g2, t2, tint, 1.5)

static func _ground(cell: Vector2i, volume_key: String) -> PackedVector2Array:
	var vol := IsoVolume.from_cell(cell, volume_key)
	var pts := PackedVector2Array()
	for p in vol.ground_poly_iso:
		pts.append(IsoVolume.iso_to_world(p))
	return pts

static func _lifted(ground: PackedVector2Array, volume_key: String) -> PackedVector2Array:
	var spec := IsoVolume.spec_for(volume_key)
	var lift := -float(spec.get("z", 1.0)) * IsoVolume.TILE * 0.32
	var top := PackedVector2Array()
	for p in ground:
		top.append(p + Vector2(0.0, lift))
	return top

static func _paint(item: CanvasItem, ground: PackedVector2Array, top: PackedVector2Array, tint: Color, width: float) -> void:
	if ground.size() < 3 or top.size() != ground.size():
		return
	var shadow := Color(0, 0, 0, 0.28 * tint.a)
	item.draw_colored_polygon(ground, shadow)
	var centroid_y := 0.0
	for p in ground:
		centroid_y += p.y
	centroid_y /= float(ground.size())
	var n := ground.size()
	for i in n:
		var j := (i + 1) % n
		var y := (ground[i].y + ground[j].y) * 0.5
		var k := clampf((y - centroid_y) / (IsoVolume.TILE * 0.35), -1.0, 1.0)
		var face := tint.lerp(Color(0.12, 0.09, 0.07), 0.42 - 0.22 * k)
		face.a = tint.a
		item.draw_colored_polygon(PackedVector2Array([ground[i], ground[j], top[j], top[i]]), face)
	var cap := tint.lightened(0.28)
	cap.a = tint.a
	item.draw_colored_polygon(top, cap)
	var ring := top.duplicate()
	ring.append(top[0])
	item.draw_polyline(ring, Color(0.08, 0.05, 0.03, 0.7 * tint.a), width)
