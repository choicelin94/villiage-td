class_name CubeThumb
extends Control

# Palette chip. The picture itself is drawn by ActorPainter from
# presentation config and art/. Drag data and click-to-place share that id.

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
	_font = CatalogPaths.load_font()
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
	ActorPainter.draw_fitted(self, area, layer, item_id)
	if _font == null or label_key == "":
		return
	var text := Locale.text(label_key)
	draw_string(_font, Vector2(2, size.y - 8), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 14, Color(1, 0.95, 0.82))


static func has_art(p_layer: String, id: String) -> bool:
	return ActorPainter.has_art(p_layer, id)
