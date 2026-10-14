class_name MapView
extends Control

# Real-art preview of the layout document. Ground, trees, rocks, buildings,
# and units are textures from art/. Spawn gates are a red translucent mask.
# This control does not instance Building or Villager nodes.

signal command_issued(cmd: Dictionary)

var doc: SetupDocument
var interaction: MapInteraction
var _font: Font
var _grass_a: Texture2D
var _grass_b: Texture2D
var _road: Texture2D


func setup(p_doc: SetupDocument, p_interaction: MapInteraction, p_font: Font) -> void:
	doc = p_doc
	interaction = p_interaction
	_font = p_font
	name = "MapView"
	custom_minimum_size = Vector2(760, 760)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_grass_a = CatalogPaths.load_tex("village/grass_a.png")
	_grass_b = CatalogPaths.load_tex("village/grass_b.png")
	_road = CatalogPaths.load_tex("village/road.png")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if doc == null or interaction == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		interaction.note_motion(_cell_at(motion.position), motion.position)
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			command_issued.emit({"op": "remove", "cell": _cell_at(mb.position)})
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
			var cmd := interaction.release(cell, doc)
			if str(cmd.get("op", "")) == "pick":
				cmd["at"] = get_global_transform() * mb.position
			command_issued.emit(cmd)
			queue_redraw()
			accept_event()


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
	_draw_screen_labels(origin, drawn)


func _draw_world() -> void:
	var tile := MapPlan.TILE
	var spawns := doc.spawn_lookup()
	var blocked := MapPlan.scenery_cells(spawns, doc.starter_props())
	var roads := MapPlan.road_cells(blocked, MapPlan.cells_from_rects(doc.spawn_rects()))
	for y in MapPlan.ROWS:
		for x in MapPlan.COLS:
			var cell := Vector2i(x, y)
			var tex := _road if roads.has(cell) and not blocked.has(cell) else (_grass_a if (x + y) % 2 == 0 else _grass_b)
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
	if MapPlan.in_bounds(interaction.hover):
		draw_rect(Rect2(float(interaction.hover.x) * tile, float(interaction.hover.y) * tile, tile, tile), Color(1, 0.95, 0.7, 0.95), false, 4.0)


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
	var world := MapPlan.TILE * float(MapPlan.COLS)
	var drawn := minf(view.x, view.y) / world
	var used := world * drawn
	return {"scale": drawn, "origin": (view - Vector2(used, used)) * 0.5}


func _view_size() -> Vector2:
	var view := size
	if view.x < 32.0 or view.y < 32.0:
		view = custom_minimum_size
	return view
