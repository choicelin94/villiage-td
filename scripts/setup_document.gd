class_name SetupDocument
extends RefCounted

# Layout truth for the map editor. Buildings, units, props, and spawn
# gates live here. The match and the workbench both read this shape
# from config/layout/setup.json. Map commands are the only writers.

var _state: Dictionary = {}


func bind(state: Dictionary) -> void:
	_state = state
	_ensure("spawn_rects")
	_ensure("spawns")
	_ensure("starter_buildings")
	_ensure("starter_units")
	_ensure("starter_props")


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


func _ensure(key: String) -> Array:
	var raw = _state.get(key, [])
	if not (raw is Array):
		raw = []
		_state[key] = raw
	return raw
