class_name MapView
extends Control

# Real-art preview of the layout document. Ground, trees, rocks, buildings,
# and units are textures from art/. Spawn gates are a red translucent mask.
# This control does not instance Building or Villager nodes.

signal command_issued(cmd: Dictionary)

const ZOOM_MIN := 0.85
const ZOOM_MAX := 3.5
const ZOOM_STEP := 1.12

var doc: SetupDocument
var interaction: MapInteraction
var _font: Font
var _grass_a: Texture2D
var _grass_b: Texture2D
var _road: Texture2D
var _zoom := 1.0
var _pan := Vector2.ZERO
var _zoom_in: Button
var _zoom_out: Button
var selected: Dictionary = {}
var primary := Vector2i(-1, -1)
var _boxing := false
var _box_drag := false
var _box_ctrl := false
var _box_from := Vector2.ZERO
var _box_to := Vector2.ZERO

const _DRAG_PX := 8.0


func setup(p_doc: SetupDocument, p_interaction: MapInteraction, p_font: Font) -> void:
	doc = p_doc
	interaction = p_interaction
	_font = p_font
	name = "MapView"
	custom_minimum_size = Vector2(760, 860)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_grass_a = CatalogPaths.load_tex("village/grass_a.png")
	_grass_b = CatalogPaths.load_tex("village/grass_b.png")
	_road = CatalogPaths.load_tex("village/road.png")
	_build_zoom()
	queue_redraw()


func zoom_level() -> float:
	return _zoom


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_clamp_pan()
	queue_redraw()


func zoom_by(factor: float, anchor: Vector2) -> void:
	var before := _fit()
	var world: Vector2 = (anchor - before.origin) / before.scale
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var view := _view_size()
	var world_px := MapPlan.TILE * float(MapPlan.COLS)
	var base := minf(view.x, view.y) / world_px
	var new_scale := base * _zoom
	var new_origin := anchor - world * new_scale
	var used := world_px * new_scale
	_pan = new_origin - (view - Vector2(used, used)) * 0.5
	_clamp_pan()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if doc == null or interaction == null:
		return
	if event is InputEventMouseMotion:
		if _boxing:
			return
		var motion := event as InputEventMouseMotion
		var was_dragging := interaction.dragging
		interaction.note_motion(_cell_at(motion.position), motion.position)
		if interaction.pressing and interaction.dragging and interaction.drag.is_empty() and was_dragging:
			_pan += motion.relative
			_clamp_pan()
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor := ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			zoom_by(factor, mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_boxing = true
			_box_drag = false
			_box_ctrl = mb.ctrl_pressed
			_box_from = mb.position
			_box_to = mb.position
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var cell := _cell_at(mb.position)
			interaction.arm(cell, mb.position, doc.hit_at(cell))
			accept_event()
		else:
			var cell := _cell_at(mb.position)
			var was_dragging := interaction.dragging
			var cmd := interaction.release(cell, doc)
			command_issued.emit(MapInteraction.with_ctrl(cmd, mb.ctrl_pressed, was_dragging))
			queue_redraw()
			accept_event()


func _input(event: InputEvent) -> void:
	if not _boxing or doc == null or interaction == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var local := _event_local(motion.position)
		_box_to = local
		_box_ctrl = motion.ctrl_pressed
		if _box_from.distance_to(_box_to) > _DRAG_PX:
			_box_drag = true
		interaction.note_motion(_cell_at(local), local)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_RIGHT or mb.pressed:
			return
		_finish_box(_event_local(mb.position), mb.ctrl_pressed)
		get_viewport().set_input_as_handled()


func cells_in_screen_box(a: Vector2, b: Vector2) -> Array:
	var box := Rect2(a, Vector2.ZERO).expand(b)
	var fit := _fit()
	var tile := MapPlan.TILE
	var cells: Array = []
	for y in MapPlan.ROWS:
		for x in MapPlan.COLS:
			var world := Rect2(float(x) * tile, float(y) * tile, tile, tile)
			var screen := Rect2(fit.origin + world.position * fit.scale, world.size * fit.scale)
			if screen.intersects(box):
				cells.append(Vector2i(x, y))
	return cells


func cell_screen_rect(cell: Vector2i) -> Rect2:
	var fit := _fit()
	var tile := MapPlan.TILE
	var world := Rect2(float(cell.x) * tile, float(cell.y) * tile, tile, tile)
	return Rect2(fit.origin + world.position * fit.scale, world.size * fit.scale)


func show_box_preview(a: Vector2, b: Vector2, ctrl: bool) -> void:
	_boxing = true
	_box_drag = true
	_box_ctrl = ctrl
	_box_from = a
	_box_to = b
	queue_redraw()


func clear_box_preview() -> void:
	_boxing = false
	_box_drag = false
	queue_redraw()


func _finish_box(local: Vector2, ctrl: bool) -> void:
	var dragged := _box_drag or _box_from.distance_to(local) > _DRAG_PX
	var anchor := _cell_at(_box_from)
	var cells: Array = cells_in_screen_box(_box_from, local) if dragged else []
	_boxing = false
	_box_drag = false
	command_issued.emit(MapInteraction.right_gesture(dragged, _cell_at(local), cells, ctrl, anchor))
	queue_redraw()


func _event_local(viewport_pos: Vector2) -> Vector2:
	return make_canvas_position_local(viewport_pos)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if doc == null or interaction == null or not (data is Dictionary):
		return false
	var layer := str(data.get("layer", ""))
	if layer != "unit" and layer != "build" and layer != "prop":
		return false
	var cell := _cell_at(at_position)
	var cmd: Dictionary = interaction.drop_command(cell, data, doc)
	var ok := str(cmd.get("op", "")) == "place"
	interaction.ghost = data
	interaction.ghost_cell = cell if ok else Vector2i(-99, -99)
	queue_redraw()
	return ok


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if doc != null and interaction != null and data is Dictionary:
		command_issued.emit(interaction.drop_command(_cell_at(at_position), data, doc))
	if interaction:
		interaction.clear_ghost()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and interaction:
		interaction.clear_ghost()
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_layout_zoom()
		queue_redraw()


func _draw() -> void:
	if doc == null or interaction == null:
		return
	var fit := _fit()
	var origin: Vector2 = fit.origin
	var drawn: float = fit.scale
	draw_rect(Rect2(Vector2.ZERO, _view_size()), Color(0.07, 0.10, 0.08, 1))
	draw_set_transform(origin, 0.0, Vector2(drawn, drawn))
	_draw_world()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_box()
	_draw_screen_labels(origin, drawn)


func _draw_box() -> void:
	if not _boxing or not _box_drag:
		return
	var box := Rect2(_box_from, Vector2.ZERO).expand(_box_to)
	draw_rect(box, Color(0.35, 0.78, 1.0, 0.22), true)
	draw_rect(box, Color(0.62, 0.94, 1.0, 0.98), false, 2.0)


func _draw_world() -> void:
	var tile := MapPlan.TILE
	var roads := MapPlan.road_lookup(doc.roads())
	for y in MapPlan.ROWS:
		for x in MapPlan.COLS:
			var cell := Vector2i(x, y)
			var on_road := roads.has(cell) and not MapPlan.is_fixed_rock(cell)
			var tex := _road if on_road else (_grass_a if (x + y) % 2 == 0 else _grass_b)
			if tex:
				draw_texture_rect(tex, Rect2(float(x) * tile, float(y) * tile, tile, tile), false)
	var grid := Color(0.05, 0.08, 0.05, 0.16)
	var span := tile * float(MapPlan.COLS)
	for i in MapPlan.COLS + 1:
		var at := float(i) * tile
		draw_line(Vector2(at, 0), Vector2(at, span), grid, 1.0)
		draw_line(Vector2(0, at), Vector2(span, at), grid, 1.0)
	_draw_actors()
	_draw_spawn_masks()
	if not interaction.ghost.is_empty() and MapPlan.in_bounds(interaction.ghost_cell):
		ActorPainter.draw_actor(self, interaction.ghost_cell, str(interaction.ghost.get("layer", "")), str(interaction.ghost.get("id", "")), 0.72, -1)
	if not interaction.dragging and interaction.ghost.is_empty() and MapPlan.is_border(interaction.hover) and not MapPlan.is_corner(interaction.hover) and not doc.middle_exists(interaction.hover):
		var ghost := MapPlan.rect_from_middle(interaction.hover)
		if not ghost.is_empty():
			var wash := MapPlan.SPAWN_MASK
			wash.a = 0.28
			_draw_mask(ghost, wash)
	_draw_selection()
	if MapPlan.in_bounds(interaction.hover):
		draw_rect(Rect2(float(interaction.hover.x) * tile, float(interaction.hover.y) * tile, tile, tile), Color(1, 0.95, 0.7, 0.95), false, 4.0)


func _draw_selection() -> void:
	var tile := MapPlan.TILE
	for key in _highlight_cells():
		var cell: Vector2i = key
		if not MapPlan.in_bounds(cell):
			continue
		var rect := Rect2(float(cell.x) * tile, float(cell.y) * tile, tile, tile)
		var main := cell == primary
		var fill := Color(1.0, 0.62, 0.12, 0.62) if main else Color(0.2, 0.62, 1.0, 0.46)
		var edge := Color(1.0, 0.86, 0.2, 1.0) if main else Color(0.45, 0.9, 1.0, 1.0)
		draw_rect(rect, fill, true)
		draw_rect(rect.grow(-4.0), edge, false, 10.0)


func _highlight_cells() -> Dictionary:
	if _boxing and _box_drag:
		var preview: Dictionary = {}
		if _box_ctrl:
			for key in selected:
				preview[key] = true
		for cell in cells_in_screen_box(_box_from, _box_to):
			preview[cell] = true
		return preview
	return selected


func _draw_actors() -> void:
	var skip: Dictionary = interaction.drag if interaction.dragging and str(interaction.drag.get("layer", "")) != "spawn" else {}
	var entries: Array = []
	_collect_scenery(entries)
	_collect(entries, "starter_props", "prop", "kind", skip)
	_collect(entries, "starter_buildings", "build", "kind", skip)
	_collect(entries, "starter_units", "unit", "unit", skip)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.y == cb.y:
			return ca.x < cb.x
		return ca.y < cb.y
	)
	for entry in entries:
		var placed: Dictionary = entry
		ActorPainter.draw_actor(self, placed["cell"], str(placed["layer"]), str(placed["id"]), 1.0, _cycle_of(placed))
	if interaction.dragging and not skip.is_empty():
		var target := interaction.hover if _can_show_drag(interaction.hover, skip) else interaction.press_cell
		if MapPlan.in_bounds(target):
			var id := str(skip.get("id", ""))
			var ghost := {"layer": str(skip.get("layer", "")), "id": id, "index": int(skip.get("index", -1))}
			ActorPainter.draw_actor(self, target, str(ghost["layer"]), id, 0.8, _cycle_of(ghost))


func _draw_spawn_masks() -> void:
	var rects := doc.spawn_rects()
	var drag_i := -1
	if interaction.dragging and str(interaction.drag.get("layer", "")) == "spawn":
		drag_i = int(interaction.drag.get("index", -1))
	for i in rects.size():
		if i == drag_i or not (rects[i] is Dictionary):
			continue
		_draw_mask(rects[i], MapPlan.SPAWN_MASK)
	if drag_i >= 0 and drag_i < rects.size():
		var preview := MapPlan.rect_from_middle(interaction.hover)
		if preview.is_empty():
			preview = rects[drag_i]
		_draw_mask(preview, MapPlan.SPAWN_MASK)


func _draw_mask(rect: Dictionary, fill: Color) -> void:
	var cells := MapPlan.cells_of_rect(rect)
	if cells.is_empty():
		return
	var tile := MapPlan.TILE
	var x0 := float(mini(cells[0].x, cells[cells.size() - 1].x)) * tile
	var y0 := float(mini(cells[0].y, cells[cells.size() - 1].y)) * tile
	var x1 := float(maxi(cells[0].x, cells[cells.size() - 1].x) + 1) * tile
	var y1 := float(maxi(cells[0].y, cells[cells.size() - 1].y) + 1) * tile
	draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), fill, true)
	draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), Color(1.0, 0.35, 0.28, 0.95), false, 8.0)
	var seam := Color(1.0, 0.9, 0.86, 0.75)
	if cells[0].y == cells[cells.size() - 1].y:
		for step in [1, 2]:
			var x := x0 + float(step) * tile
			draw_line(Vector2(x, y0), Vector2(x, y1), seam, 3.0)
	else:
		for step in [1, 2]:
			var y := y0 + float(step) * tile
			draw_line(Vector2(x0, y), Vector2(x1, y), seam, 3.0)
	var inner := Color(1.0, 0.55, 0.42, 0.95)
	match str(rect.get("edge", "")):
		"north":
			draw_line(Vector2(x0, y1), Vector2(x1, y1), inner, 10.0)
		"south":
			draw_line(Vector2(x0, y0), Vector2(x1, y0), inner, 10.0)
		"west":
			draw_line(Vector2(x1, y0), Vector2(x1, y1), inner, 10.0)
		"east":
			draw_line(Vector2(x0, y0), Vector2(x0, y1), inner, 10.0)


func _draw_screen_labels(origin: Vector2, drawn: float) -> void:
	if _font == null:
		return
	for rect in _visible_rects():
		var cells := MapPlan.cells_of_rect(rect)
		if cells.is_empty():
			continue
		var acc := Vector2.ZERO
		for cell in cells:
			acc += Vector2((float(cell.x) + 0.5) * MapPlan.TILE, (float(cell.y) + 0.5) * MapPlan.TILE)
		acc /= float(cells.size())
		var at := origin + acc * drawn
		draw_string(_font, at + Vector2(-18, 7), Locale.text("bench.spawn.tag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.97, 0.92))
	if MapPlan.in_bounds(interaction.hover):
		draw_string(_font, Vector2(10, 24), Locale.format("bench.map.cell", [interaction.hover.x, interaction.hover.y]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8))


func _visible_rects() -> Array:
	var rects: Array = doc.spawn_rects().duplicate()
	if interaction.dragging and str(interaction.drag.get("layer", "")) == "spawn":
		var index := int(interaction.drag.get("index", -1))
		var preview := MapPlan.rect_from_middle(interaction.hover)
		if index >= 0 and index < rects.size() and not preview.is_empty():
			rects[index] = preview
	return rects


func _collect_scenery(into: Array) -> void:
	var spawns := doc.spawn_lookup()
	for y in MapPlan.ROWS:
		for x in MapPlan.COLS:
			var cell := Vector2i(x, y)
			if MapPlan.is_border(cell) and not spawns.has(cell):
				into.append({"layer": "prop", "id": "tree", "cell": cell, "index": -1})
			if MapPlan.is_fixed_rock(cell):
				into.append({"layer": "prop", "id": "rock", "cell": cell, "index": -1})


func _cycle_of(entry: Dictionary) -> int:
	if str(entry.get("layer", "")) != "unit" or str(entry.get("id", "")) != "villager":
		return -1
	return _villager_cycle(int(entry.get("index", -1)))


func _villager_cycle(index: int) -> int:
	var n := 0
	var rows := doc.starter_units()
	for i in rows.size():
		var item = rows[i]
		if not (item is Dictionary) or str(item.get("unit", "")) != "villager":
			continue
		if i == index:
			return n
		n += 1
	return 0


func _collect(into: Array, key: String, layer: String, id_key: String, skip: Dictionary) -> void:
	var rows: Array = doc.state().get(key, [])
	for i in rows.size():
		if str(skip.get("layer", "")) == layer and int(skip.get("index", -2)) == i:
			continue
		var item = rows[i]
		if not (item is Dictionary):
			continue
		var raw = item.get("cell", [])
		if not (raw is Array) or raw.size() < 2:
			continue
		into.append({
			"layer": layer,
			"id": str(item.get(id_key, "")),
			"cell": Vector2i(int(raw[0]), int(raw[1])),
			"index": i,
		})


func _can_show_drag(cell: Vector2i, ignore: Dictionary) -> bool:
	if not MapPlan.in_bounds(cell) or MapPlan.is_border(cell) or MapPlan.is_fixed_rock(cell):
		return false
	if doc.spawn_lookup().has(cell):
		return false
	return not doc.blocks_new(cell, ignore)


func _cell_at(local_pos: Vector2) -> Vector2i:
	var fit := _fit()
	var world: Vector2 = (local_pos - fit.origin) / fit.scale
	return Vector2i(floori(world.x / MapPlan.TILE), floori(world.y / MapPlan.TILE))


func _fit() -> Dictionary:
	var view := _view_size()
	var world_px := MapPlan.TILE * float(MapPlan.COLS)
	var base := minf(view.x, view.y) / world_px
	var drawn := base * _zoom
	var used := world_px * drawn
	return {"scale": drawn, "origin": (view - Vector2(used, used)) * 0.5 + _pan}


func _clamp_pan() -> void:
	var view := _view_size()
	var world_px := MapPlan.TILE * float(MapPlan.COLS)
	var base := minf(view.x, view.y) / world_px
	var drawn := base * _zoom
	var used := world_px * drawn
	var margin := 64.0
	var min_x := margin - used
	var max_x := view.x - margin
	if min_x > max_x:
		var locked := (view.x - used) * 0.5
		min_x = locked
		max_x = locked
	var base_x := (view.x - used) * 0.5
	_pan.x = clampf(_pan.x, min_x - base_x, max_x - base_x)
	var min_y := margin - used
	var max_y := view.y - margin
	if min_y > max_y:
		var locked_y := (view.y - used) * 0.5
		min_y = locked_y
		max_y = locked_y
	var base_y := (view.y - used) * 0.5
	_pan.y = clampf(_pan.y, min_y - base_y, max_y - base_y)


func _build_zoom() -> void:
	_zoom_out = _zoom_button("MapZoomOut", "－", 1.0 / ZOOM_STEP)
	_zoom_in = _zoom_button("MapZoomIn", "＋", ZOOM_STEP)
	add_child(_zoom_out)
	add_child(_zoom_in)
	_layout_zoom()


func _zoom_button(node_name: String, text: String, factor: float) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(36, 36)
	btn.add_theme_font_size_override("font_size", 18)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.pressed.connect(_on_zoom_button.bind(factor))
	return btn


func _on_zoom_button(factor: float) -> void:
	zoom_by(factor, Vector2(size.x * 0.35, size.y * 0.5))


func _layout_zoom() -> void:
	if _zoom_out == null or _zoom_in == null:
		return
	var y := maxf(size.y - 44.0, 8.0)
	_zoom_out.position = Vector2(8, y)
	_zoom_out.size = Vector2(36, 36)
	_zoom_in.position = Vector2(48, y)
	_zoom_in.size = Vector2(36, 36)


func _view_size() -> Vector2:
	var view := size
	if view.x < 32.0 or view.y < 32.0:
		view = custom_minimum_size
	return view
