class_name MapBoard
extends Control

# The workbench map. Same 20×20 cell grid, tile size, and pictures as the match.
# Ground, trees, rocks, buildings, and units use the match textures. Enemy gates
# are a red translucent mask on those cells.

signal place_requested(cell: Vector2i, at: Vector2)
signal hint_changed(text: String)
signal changed

var state: Dictionary = {}
var _font: Font
var _grass_a: Texture2D
var _grass_b: Texture2D
var _road: Texture2D
var _pressing := false
var _press_pos := Vector2.ZERO
var _press_cell := Vector2i(-1, -1)
var _dragging := false
var _drag: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _ghost: Dictionary = {}
var _ghost_cell := Vector2i(-99, -99)
var _last_action := ""

func setup(p_state: Dictionary, p_font: Font) -> void:
	state = p_state
	_font = p_font
	custom_minimum_size = Vector2(760, 760)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_ensure("spawn_rects")
	_ensure("spawns")
	_ensure("starter_buildings")
	_ensure("starter_units")
	_ensure("starter_props")
	_grass_a = load("res://assets/village/grass_a.png")
	_grass_b = load("res://assets/village/grass_b.png")
	_road = load("res://assets/village/road.png")
	queue_redraw()

func place_payload(payload: Dictionary, cell: Vector2i) -> bool:
	var layer := str(payload.get("layer", ""))
	var id := str(payload.get("id", ""))
	if layer != "unit" and layer != "build" and layer != "prop":
		return false
	if not _can_accept_new(cell):
		if MapPlan.is_fixed_rock(cell):
			_hint(Locale.text("bench.map.rock"))
		elif not MapPlan.in_bounds(cell) or MapPlan.is_border(cell):
			_hint(Locale.text("bench.map.outside"))
		else:
			_hint(Locale.text("bench.map.occupied"))
		_last_action = "reject"
		return false
	_clear_editor_at(cell)
	if layer == "unit":
		_ensure("starter_units").append({
			"unit": id,
			"cell": [cell.x, cell.y],
			"sex": _next_sex(id),
		})
	elif layer == "build":
		_ensure("starter_buildings").append({"kind": id, "cell": [cell.x, cell.y]})
	else:
		_ensure("starter_props").append({"kind": id, "cell": [cell.x, cell.y]})
	_last_action = "placed"
	_hint(Locale.format("bench.map.moved", [cell.x, cell.y]))
	queue_redraw()
	changed.emit()
	return true

func edit_click(cell: Vector2i) -> String:
	_click(cell, Vector2.ZERO)
	return _last_action

func probe_edits() -> bool:
	var corner := edit_click(Vector2i(0, 0))
	var before := _ensure("spawn_rects").size()
	var spawned := edit_click(Vector2i(3, 0))
	var rects: Array = state.get("spawn_rects", [])
	var cell_ok := false
	if rects.size() == before + 1:
		var cells := MapPlan.cells_of_rect(rects[rects.size() - 1])
		cell_ok = cells.size() == 3 and cells[0] == Vector2i(2, 0) and cells[1] == Vector2i(3, 0) and cells[2] == Vector2i(4, 0)
	var pick := edit_click(Vector2i(10, 8))
	var placed := place_payload({"layer": "unit", "id": "spearman", "volume": "walker"}, Vector2i(10, 8))
	var border_reject := not place_payload({"layer": "build", "id": "WALL", "volume": "wall"}, Vector2i(5, 0))
	var rock_reject := not place_payload({"layer": "prop", "id": "tree", "volume": "tree"}, Vector2i(4, 8))
	var prop_ok := place_payload({"layer": "prop", "id": "rock", "volume": "rock"}, Vector2i(6, 6))
	var art_ok := CubeThumb.has_art("build", "HOUSE") and CubeThumb.has_art("unit", "villager") and CubeThumb.has_art("unit", "spearman") and CubeThumb.has_art("prop", "tree") and CubeThumb.has_art("prop", "rock")
	var ok := corner == "corner" and spawned == "spawn" and cell_ok and pick == "pick" and placed and border_reject and rock_reject and prop_ok and art_ok
	print("BENCH_EDIT corner=", corner, " spawn=", spawned, " cell=", cell_ok, " pick=", pick, " placed=", placed, " border=", border_reject, " rock=", rock_reject, " prop=", prop_ok, " art=", art_ok)
	return ok

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover = _cell_at(motion.position)
		if _pressing and motion.position.distance_to(_press_pos) > 8.0:
			_dragging = true
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_remove_at(_cell_at(mb.position))
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_dragging = false
			_press_pos = mb.position
			_press_cell = _cell_at(mb.position)
			_drag = _hit_item(_press_cell)
			accept_event()
		else:
			var cell := _cell_at(mb.position)
			if _dragging and not _drag.is_empty():
				_finish_drag(cell)
			elif not _dragging:
				_click(cell, mb.position)
			_pressing = false
			_dragging = false
			_drag = {}
			queue_redraw()
			accept_event()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var layer := str(data.get("layer", ""))
	if layer != "unit" and layer != "build" and layer != "prop":
		return false
	var cell := _cell_at(at_position)
	var ok := _can_accept_new(cell)
	_ghost = data
	_ghost_cell = cell if ok else Vector2i(-99, -99)
	queue_redraw()
	return ok

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		place_payload(data, _cell_at(at_position))
	_clear_ghost()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_ghost()

func _draw() -> void:
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
	var spawns := _spawn_cells()
	var blocked := MapPlan.scenery_cells(spawns, _ensure("starter_props"))
	var roads := MapPlan.road_cells(blocked, MapPlan.cells_from_rects(_ensure("spawn_rects")))
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
	if not _ghost.is_empty() and MapPlan.in_bounds(_ghost_cell):
		CubeThumb.draw_actor(self, _ghost_cell, str(_ghost.get("layer", "")), str(_ghost.get("id", "")), 0.72, -1)
	if not _dragging and _ghost.is_empty() and MapPlan.is_border(_hover) and not MapPlan.is_corner(_hover) and not _middle_exists(_hover):
		var ghost := MapPlan.rect_from_middle(_hover)
		if not ghost.is_empty():
			var wash := MapPlan.SPAWN_MASK
			wash.a = 0.28
			_draw_mask(ghost, wash)
	if MapPlan.in_bounds(_hover):
		draw_rect(Rect2(float(_hover.x) * tile, float(_hover.y) * tile, tile, tile), Color(1, 0.95, 0.7, 0.95), false, 4.0)

func _draw_actors() -> void:
	var skip := _drag if _dragging and str(_drag.get("layer", "")) != "spawn" else {}
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
		CubeThumb.draw_actor(self, placed["cell"], str(placed["layer"]), str(placed["id"]), 1.0, _cycle_of(placed))
	if _dragging and not skip.is_empty():
		var target := _hover if _can_place(_hover, skip) else _press_cell
		if MapPlan.in_bounds(target):
			var id := _id_of(skip)
			var ghost := {"layer": str(skip.get("layer", "")), "id": id, "index": int(skip.get("index", -1))}
			CubeThumb.draw_actor(self, target, str(ghost["layer"]), id, 0.8, _cycle_of(ghost))

func _draw_spawn_masks() -> void:
	var rects: Array = _ensure("spawn_rects")
	var drag_i := -1
	if _dragging and str(_drag.get("layer", "")) == "spawn":
		drag_i = int(_drag.get("index", -1))
	for i in rects.size():
		if i == drag_i or not (rects[i] is Dictionary):
			continue
		_draw_mask(rects[i], MapPlan.SPAWN_MASK)
	if drag_i >= 0 and drag_i < rects.size():
		var preview := MapPlan.rect_from_middle(_hover)
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
	var rects := _visible_rects()
	for rect in rects:
		var cells := MapPlan.cells_of_rect(rect)
		if cells.is_empty():
			continue
		var acc := Vector2.ZERO
		for cell in cells:
			acc += Vector2((float(cell.x) + 0.5) * MapPlan.TILE, (float(cell.y) + 0.5) * MapPlan.TILE)
		acc /= float(cells.size())
		var at := origin + acc * drawn
		draw_string(_font, at + Vector2(-18, 7), Locale.text("bench.spawn.tag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.97, 0.92))
	if MapPlan.in_bounds(_hover):
		draw_string(_font, Vector2(10, 24), Locale.format("bench.map.cell", [_hover.x, _hover.y]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8))

func _visible_rects() -> Array:
	var rects: Array = _ensure("spawn_rects").duplicate()
	if _dragging and str(_drag.get("layer", "")) == "spawn":
		var index := int(_drag.get("index", -1))
		var preview := MapPlan.rect_from_middle(_hover)
		if index >= 0 and index < rects.size() and not preview.is_empty():
			rects[index] = preview
	return rects

func _collect_scenery(into: Array) -> void:
	var spawns := _spawn_cells()
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
	var rows: Array = _ensure("starter_units")
	for i in rows.size():
		var item = rows[i]
		if not (item is Dictionary) or str(item.get("unit", "")) != "villager":
			continue
		if i == index:
			return n
		n += 1
	return 0

func _click(cell: Vector2i, local_pos: Vector2) -> void:
	if not MapPlan.in_bounds(cell):
		_last_action = "outside"
		return
	if MapPlan.is_corner(cell):
		_last_action = "corner"
		_hint(Locale.text("bench.map.corner"))
		return
	if MapPlan.is_border(cell):
		_add_spawn(cell)
		return
	if MapPlan.is_fixed_rock(cell):
		_last_action = "rock"
		_hint(Locale.text("bench.map.rock"))
		return
	if not _hit_item(cell).is_empty():
		_last_action = "occupied"
		_hint(Locale.text("bench.map.occupied"))
		return
	_last_action = "pick"
	place_requested.emit(cell, get_global_transform() * local_pos)

func _add_spawn(cell: Vector2i) -> void:
	var rect := MapPlan.rect_from_middle(cell)
	if rect.is_empty():
		_last_action = "corner"
		_hint(Locale.text("bench.map.corner"))
		return
	if _middle_exists(cell):
		_last_action = "spawn"
		_hint(Locale.text("bench.map.spawn_have"))
		return
	_ensure("spawn_rects").append(rect)
	_touch_spawns()
	_last_action = "spawn"
	_hint(Locale.format("bench.map.spawn_set", [cell.x, cell.y]))
	changed.emit()

func _finish_drag(cell: Vector2i) -> void:
	if str(_drag.get("layer", "")) == "spawn":
		var rect := MapPlan.rect_from_middle(cell)
		var index := int(_drag.get("index", -1))
		var rows: Array = _ensure("spawn_rects")
		if rect.is_empty() or index < 0 or index >= rows.size():
			_hint(Locale.text("bench.map.corner") if MapPlan.is_corner(cell) else Locale.text("bench.map.outside"))
			return
		if _middle_exists(cell) and not _same_middle(index, cell):
			_hint(Locale.text("bench.map.spawn_have"))
			return
		rows[index] = rect
		_touch_spawns()
		_hint(Locale.format("bench.map.moved", [cell.x, cell.y]))
		changed.emit()
		return
	if not _can_place(cell, _drag):
		_hint(Locale.text("bench.map.outside") if MapPlan.is_border(cell) or not MapPlan.in_bounds(cell) else Locale.text("bench.map.occupied"))
		return
	_move_entry(_drag, cell)
	_hint(Locale.format("bench.map.moved", [cell.x, cell.y]))
	changed.emit()

func _remove_at(cell: Vector2i) -> void:
	var spawn_i := _spawn_index_at(cell)
	if spawn_i >= 0:
		var rows: Array = _ensure("spawn_rects")
		if rows.size() <= 1:
			_hint(Locale.text("bench.map.need_spawn"))
			return
		rows.remove_at(spawn_i)
		_touch_spawns()
		_hint(Locale.text("bench.map.removed"))
		changed.emit()
		return
	if _clear_editor_at(cell):
		_hint(Locale.text("bench.map.removed"))
		queue_redraw()
		changed.emit()

func _collect(into: Array, key: String, layer: String, id_key: String, skip: Dictionary) -> void:
	var rows: Array = _ensure(key)
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

func _hit_item(cell: Vector2i) -> Dictionary:
	var build_i := _entry_at(_ensure("starter_buildings"), cell)
	if build_i >= 0:
		return {"layer": "build", "index": build_i}
	var unit_i := _entry_at(_ensure("starter_units"), cell)
	if unit_i >= 0:
		return {"layer": "unit", "index": unit_i}
	var prop_i := _entry_at(_ensure("starter_props"), cell)
	if prop_i >= 0:
		return {"layer": "prop", "index": prop_i}
	var spawn_i := _spawn_index_at(cell)
	if spawn_i >= 0:
		return {"layer": "spawn", "index": spawn_i}
	return {}

func _entry_at(rows: Array, cell: Vector2i) -> int:
	for i in rows.size():
		var item = rows[i]
		if item is Dictionary:
			var raw = item.get("cell", [])
			if raw is Array and raw.size() >= 2 and int(raw[0]) == cell.x and int(raw[1]) == cell.y:
				return i
	return -1

func _spawn_index_at(cell: Vector2i) -> int:
	var rects: Array = _ensure("spawn_rects")
	var found := -1
	for i in rects.size():
		if not (rects[i] is Dictionary):
			continue
		var cells := MapPlan.cells_of_rect(rects[i])
		if cell in cells:
			found = i
			var middle = rects[i].get("middle", [])
			if middle is Array and middle.size() >= 2 and int(middle[0]) == cell.x and int(middle[1]) == cell.y:
				return i
	return found

func _middle_exists(cell: Vector2i) -> bool:
	for rect in _ensure("spawn_rects"):
		if not (rect is Dictionary):
			continue
		var middle = rect.get("middle", [])
		if middle is Array and middle.size() >= 2 and int(middle[0]) == cell.x and int(middle[1]) == cell.y:
			return true
	return false

func _same_middle(index: int, cell: Vector2i) -> bool:
	var rows: Array = _ensure("spawn_rects")
	if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
		return false
	var middle = rows[index].get("middle", [])
	return middle is Array and middle.size() >= 2 and int(middle[0]) == cell.x and int(middle[1]) == cell.y

func _id_of(hit: Dictionary) -> String:
	var layer := str(hit.get("layer", ""))
	var index := int(hit.get("index", -1))
	var key := "starter_units"
	var id_key := "unit"
	if layer == "build":
		key = "starter_buildings"
		id_key = "kind"
	elif layer == "prop":
		key = "starter_props"
		id_key = "kind"
	var rows: Array = _ensure(key)
	if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
		return ""
	return str(rows[index].get(id_key, ""))

func _move_entry(hit: Dictionary, cell: Vector2i) -> void:
	var layer := str(hit.get("layer", ""))
	var key := "starter_units"
	if layer == "build":
		key = "starter_buildings"
	elif layer == "prop":
		key = "starter_props"
	var rows: Array = _ensure(key)
	var index := int(hit.get("index", -1))
	if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
		return
	rows[index]["cell"] = [cell.x, cell.y]
	queue_redraw()

func _clear_editor_at(cell: Vector2i) -> bool:
	var removed := false
	for key in ["starter_buildings", "starter_units", "starter_props"]:
		var rows: Array = _ensure(key)
		var index := _entry_at(rows, cell)
		if index >= 0:
			rows.remove_at(index)
			removed = true
	return removed

func _can_place(cell: Vector2i, ignore: Dictionary = {}) -> bool:
	if not MapPlan.in_bounds(cell) or MapPlan.is_border(cell) or MapPlan.is_fixed_rock(cell):
		return false
	if _spawn_cells().has(cell):
		return false
	var hit := _hit_item(cell)
	if hit.is_empty() or str(hit.get("layer", "")) == "spawn":
		return true
	return str(hit.get("layer", "")) == str(ignore.get("layer", "")) and int(hit.get("index", -2)) == int(ignore.get("index", -1))

func _can_accept_new(cell: Vector2i) -> bool:
	if not MapPlan.in_bounds(cell) or MapPlan.is_border(cell) or MapPlan.is_fixed_rock(cell):
		return false
	if _spawn_cells().has(cell):
		return false
	return true

func _spawn_cells() -> Dictionary:
	return MapPlan.spawn_lookup(_ensure("spawn_rects"))

func _touch_spawns() -> void:
	var cleaned := MapPlan.clean_rects(_ensure("spawn_rects"))
	state["spawn_rects"] = cleaned
	state["spawns"] = MapPlan.cells_from_rects(cleaned)
	queue_redraw()

func _next_sex(unit_id: String) -> String:
	if unit_id != "villager":
		return "m"
	var males := 0
	var females := 0
	for item in _ensure("starter_units"):
		if not (item is Dictionary) or str(item.get("unit", "")) != "villager":
			continue
		if str(item.get("sex", "m")) == "f":
			females += 1
		else:
			males += 1
	return "f" if females < males else "m"

func _ensure(key: String) -> Array:
	var raw = state.get(key, [])
	if not (raw is Array):
		raw = []
		state[key] = raw
	return raw

func _clear_ghost() -> void:
	_ghost = {}
	_ghost_cell = Vector2i(-99, -99)
	queue_redraw()

func _hint(text: String) -> void:
	hint_changed.emit(text)

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
