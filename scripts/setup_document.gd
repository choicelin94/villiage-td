class_name SetupDocument
extends RefCounted

# Layout truth for the map editor. Buildings, units, props, spawn gates,
# and painted road cells live here. The match and the workbench both read
# this shape from config/layout/setup.json. Map commands are the only writers.
# Roads are ground paint. They are not the enemy movement route.

var _state: Dictionary = {}
var trimmed := false


func bind(state: Dictionary) -> void:
	_state = state
	_ensure("spawn_rects")
	_ensure("spawns")
	_ensure("starter_buildings")
	_ensure("starter_units")
	_ensure("starter_props")
	normalize()


func normalize() -> void:
	var cleaned: Array = MapPlan.clean_rects(spawn_rects())
	trimmed = cleaned.size() > 1
	if cleaned.is_empty():
		cleaned = MapPlan.default_rects()
	elif trimmed:
		cleaned = [cleaned[0]]
	_state["spawn_rects"] = cleaned
	_state["spawns"] = MapPlan.cells_from_rects(cleaned)
	if not (_state.get("roads") is Array):
		var middle := MapPlan.middle_of(cleaned[0])
		var blocked := MapPlan.scenery_cells(MapPlan.spawn_lookup(cleaned), starter_props())
		_state["roads"] = MapPlan.seed_road_cells(middle, blocked)
	else:
		_state["roads"] = MapPlan.clean_roads(_state.get("roads"))


func state() -> Dictionary:
	return _state


func spawn_rects() -> Array:
	return _ensure("spawn_rects")


func spawns() -> Array:
	return _ensure("spawns")


func starter_buildings() -> Array:
	return _ensure("starter_buildings")


func starter_units() -> Array:
	return _ensure("starter_units")


func starter_props() -> Array:
	return _ensure("starter_props")


func roads() -> Array:
	var raw = _state.get("roads", [])
	if not (raw is Array):
		raw = []
		_state["roads"] = raw
	return raw


func is_road(cell: Vector2i) -> bool:
	return MapPlan.road_lookup(roads()).has(cell)


func footprint_block(cell: Vector2i) -> String:
	var rect := MapPlan.rect_from_middle(cell)
	if rect.is_empty():
		return "corner" if MapPlan.is_corner(cell) else "outside"
	for spot in MapPlan.cells_of_rect(rect):
		if MapPlan.is_fixed_rock(spot):
			return "rock"
		var hit := hit_at(spot)
		if not hit.is_empty() and str(hit.get("layer", "")) != "spawn":
			return "spawn_blocked"
	if not is_road(cell):
		return "need_road"
	return ""


func toggle_road(cell: Vector2i) -> String:
	if not MapPlan.in_bounds(cell):
		return "outside"
	if MapPlan.is_fixed_rock(cell):
		return "rock"
	var rows := roads()
	for i in rows.size():
		var raw = rows[i]
		if raw is Array and raw.size() >= 2 and int(raw[0]) == cell.x and int(raw[1]) == cell.y:
			rows.remove_at(i)
			if _spawn_middle_is(cell):
				return "need_road"
			return "road_off"
	rows.append([cell.x, cell.y])
	return "road_on"


func load_note() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if trimmed:
		parts.append(Locale.text("bench.map.spawn_one"))
	if not spawn_rects().is_empty():
		var block := footprint_block(MapPlan.middle_of(spawn_rects()[0]))
		if block == "need_road" or block == "spawn_blocked" or block == "rock":
			parts.append(Locale.text("bench.map." + block))
	return " ".join(parts)


func touch_spawns() -> void:
	var cleaned: Array = MapPlan.clean_rects(spawn_rects())
	_state["spawn_rects"] = cleaned
	_state["spawns"] = MapPlan.cells_from_rects(cleaned)


func spawn_lookup() -> Dictionary:
	return MapPlan.spawn_lookup(spawn_rects())


func hit_at(cell: Vector2i) -> Dictionary:
	var build_i := _entry_at(starter_buildings(), cell)
	if build_i >= 0:
		return {"layer": "build", "index": build_i, "id": str(starter_buildings()[build_i].get("kind", ""))}
	var unit_i := _entry_at(starter_units(), cell)
	if unit_i >= 0:
		return {"layer": "unit", "index": unit_i, "id": str(starter_units()[unit_i].get("unit", ""))}
	var prop_i := _entry_at(starter_props(), cell)
	if prop_i >= 0:
		return {"layer": "prop", "index": prop_i, "id": str(starter_props()[prop_i].get("kind", ""))}
	var spawn_i := spawn_index_at(cell)
	if spawn_i >= 0:
		return {"layer": "spawn", "index": spawn_i, "id": "spawn"}
	return {}


func blocks_new(cell: Vector2i, ignore: Dictionary) -> bool:
	if MapPlan.is_fixed_rock(cell):
		return true
	var hit := hit_at(cell)
	if hit.is_empty() or str(hit.get("layer", "")) == "spawn":
		return false
	if str(hit.get("layer", "")) == str(ignore.get("layer", "")) and int(hit.get("index", -2)) == int(ignore.get("index", -1)):
		return false
	return true


func spawn_index_at(cell: Vector2i) -> int:
	var rects := spawn_rects()
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


func middle_exists(cell: Vector2i) -> bool:
	for rect in spawn_rects():
		if not (rect is Dictionary):
			continue
		var middle = rect.get("middle", [])
		if middle is Array and middle.size() >= 2 and int(middle[0]) == cell.x and int(middle[1]) == cell.y:
			return true
	return false


func same_middle(index: int, cell: Vector2i) -> bool:
	var rows := spawn_rects()
	if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
		return false
	var middle = rows[index].get("middle", [])
	return middle is Array and middle.size() >= 2 and int(middle[0]) == cell.x and int(middle[1]) == cell.y


func remove_editor_at(cell: Vector2i) -> bool:
	var removed := false
	for key in ["starter_buildings", "starter_units", "starter_props"]:
		var rows: Array = _ensure(key)
		var index := _entry_at(rows, cell)
		if index >= 0:
			rows.remove_at(index)
			removed = true
	return removed


func _entry_at(rows: Array, cell: Vector2i) -> int:
	for i in rows.size():
		var item = rows[i]
		if item is Dictionary:
			var raw = item.get("cell", [])
			if raw is Array and raw.size() >= 2 and int(raw[0]) == cell.x and int(raw[1]) == cell.y:
				return i
	return -1


func _spawn_middle_is(cell: Vector2i) -> bool:
	var rows := spawn_rects()
	if rows.is_empty() or not (rows[0] is Dictionary):
		return false
	return MapPlan.middle_of(rows[0]) == cell


func _ensure(key: String) -> Array:
	var raw = _state.get(key, [])
	if not (raw is Array):
		raw = []
		_state[key] = raw
	return raw
