class_name MapCommands
extends RefCounted

# place, move, remove, and set_spawn. Click and drag-drop both end in apply().
# Nothing here instances a Building or a Villager.


static func apply(doc: SetupDocument, cmd: Dictionary) -> Dictionary:
	var cell: Vector2i = cmd.get("cell", Vector2i(-1, -1))
	match str(cmd.get("op", "")):
		"place":
			return place(doc, str(cmd.get("layer", "")), str(cmd.get("id", "")), cell)
		"move":
			return move(doc, str(cmd.get("layer", "")), int(cmd.get("index", -1)), cell)
		"remove":
			return remove_at(doc, cell)
		"set_spawn":
			return set_spawn(doc, cell)
		"move_spawn":
			return move_spawn(doc, int(cmd.get("index", -1)), cell)
		"pick":
			return {"ok": true, "action": "pick", "cell": cell}
		"reject":
			return {"ok": false, "action": str(cmd.get("reason", "reject")), "cell": cell}
		_:
			return {"ok": false, "action": "reject", "cell": cell}


static func place(doc: SetupDocument, layer: String, id: String, cell: Vector2i) -> Dictionary:
	if layer != "unit" and layer != "build" and layer != "prop":
		return _no("outside", cell)
	if not _id_allowed(layer, id):
		return _no("outside", cell)
	if MapPlan.is_fixed_rock(cell):
		return _no("rock", cell)
	if not MapPlan.in_bounds(cell) or MapPlan.is_border(cell) or MapPlan.is_corner(cell):
		return _no("outside", cell)
	if doc.spawn_lookup().has(cell) or doc.blocks_new(cell, {}):
		return _no("occupied", cell)
	if layer == "unit":
		doc.starter_units().append({
			"unit": id,
			"cell": [cell.x, cell.y],
			"sex": _next_sex(doc, id),
		})
	elif layer == "build":
		doc.starter_buildings().append({"kind": id, "cell": [cell.x, cell.y]})
	else:
		doc.starter_props().append({"kind": id, "cell": [cell.x, cell.y]})
	return {"ok": true, "action": "placed", "cell": cell}


static func move(doc: SetupDocument, layer: String, index: int, cell: Vector2i) -> Dictionary:
	if MapPlan.is_fixed_rock(cell) or not MapPlan.in_bounds(cell) or MapPlan.is_border(cell):
		return _no("outside", cell)
	if doc.spawn_lookup().has(cell):
		return _no("occupied", cell)
	var key := "starter_units"
	if layer == "build":
		key = "starter_buildings"
	elif layer == "prop":
		key = "starter_props"
	elif layer != "unit":
		return _no("outside", cell)
	var rows: Array = doc.state().get(key, [])
	if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
		return _no("outside", cell)
	if doc.blocks_new(cell, {"layer": layer, "index": index}):
		return _no("occupied", cell)
	rows[index]["cell"] = [cell.x, cell.y]
	return {"ok": true, "action": "moved", "cell": cell}


static func remove_at(doc: SetupDocument, cell: Vector2i) -> Dictionary:
	var spawn_i := doc.spawn_index_at(cell)
	if spawn_i >= 0:
		var rows := doc.spawn_rects()
		if rows.size() <= 1:
			return _no("need_spawn", cell)
		rows.remove_at(spawn_i)
		doc.touch_spawns()
		return {"ok": true, "action": "removed", "cell": cell}
	if doc.remove_editor_at(cell):
		return {"ok": true, "action": "removed", "cell": cell}
	return _no("reject", cell)


static func set_spawn(doc: SetupDocument, cell: Vector2i) -> Dictionary:
	var rect := MapPlan.rect_from_middle(cell)
	if rect.is_empty():
		return _no("corner" if MapPlan.is_corner(cell) else "outside", cell)
	if doc.middle_exists(cell):
		return {"ok": false, "action": "spawn_have", "cell": cell}
	doc.spawn_rects().append(rect)
	doc.touch_spawns()
	return {"ok": true, "action": "spawn", "cell": cell}


static func move_spawn(doc: SetupDocument, index: int, cell: Vector2i) -> Dictionary:
	var rect := MapPlan.rect_from_middle(cell)
	var rows := doc.spawn_rects()
	if rect.is_empty() or index < 0 or index >= rows.size():
		return _no("corner" if MapPlan.is_corner(cell) else "outside", cell)
	if doc.middle_exists(cell) and not doc.same_middle(index, cell):
		return {"ok": false, "action": "spawn_have", "cell": cell}
	rows[index] = rect
	doc.touch_spawns()
	return {"ok": true, "action": "moved", "cell": cell}


static func golden() -> bool:
	var failures: Array[String] = []
	_expect_strategy(failures)
	_expect_gates(failures)
	_expect_pieces(failures)
	var ok := failures.is_empty()
	if ok:
		print("BENCH_COMMANDS ok=true")
	else:
		print("BENCH_COMMANDS ok=false ", ", ".join(PackedStringArray(failures)))
	return ok


static func _expect_strategy(failures: Array[String]) -> void:
	var empty := {}
	var unit := {"layer": "unit", "id": "villager"}
	var click_gate: Dictionary = MapInteraction.op_for(Vector2i(3, 0), empty, false)
	var drop_gate: Dictionary = MapInteraction.op_for(Vector2i(3, 0), unit, false)
	var click_land: Dictionary = MapInteraction.op_for(Vector2i(10, 8), empty, false)
	var drop_land: Dictionary = MapInteraction.op_for(Vector2i(10, 8), unit, false)
	var click_place: Dictionary = {"op": "place", "layer": "unit", "id": "villager", "cell": Vector2i(10, 8)}
	var corner: Dictionary = MapInteraction.op_for(Vector2i(0, 0), empty, false)
	var corner_drop: Dictionary = MapInteraction.op_for(Vector2i(19, 19), unit, false)
	var occupied: Dictionary = MapInteraction.op_for(Vector2i(10, 8), unit, true)
	if str(click_gate.get("op", "")) != "set_spawn":
		failures.append("click gate")
	if str(drop_gate.get("op", "")) != "reject":
		failures.append("drop on gate")
	if str(click_land.get("op", "")) != "pick":
		failures.append("click land")
	if str(drop_land.get("op", "")) != "place" or str(drop_land.get("id", "")) != "villager":
		failures.append("drop land")
	if str(drop_land.get("op", "")) != str(click_place.get("op", "")) or drop_land.get("cell") != click_place.get("cell") or str(drop_land.get("id", "")) != str(click_place.get("id", "")):
		failures.append("click-place and drop diverge")
	if str(corner.get("reason", "")) != "corner" or str(corner_drop.get("reason", "")) != "corner":
		failures.append("corners")
	if str(occupied.get("reason", "")) != "occupied":
		failures.append("occupied drop")


static func _expect_gates(failures: Array[String]) -> void:
	var doc := _blank()
	var north := MapPlan.cells_of_rect(doc.spawn_rects()[0])
	if not _flat(north, true, Vector2i(10, 0)):
		failures.append("default north")
	var added: Dictionary = apply(doc, MapInteraction.op_for(Vector2i(3, 0), {}, false))
	if str(added.get("action", "")) != "spawn":
		failures.append("set spawn action")
	var gate := MapPlan.cells_of_rect(doc.spawn_rects()[doc.spawn_rects().size() - 1])
	if not _flat(gate, true, Vector2i(3, 0)):
		failures.append("north 3x1")
	var west: Dictionary = set_spawn(doc, Vector2i(0, 8))
	if not west.get("ok", false) or not _flat(MapPlan.cells_of_rect(doc.spawn_rects()[doc.spawn_rects().size() - 1]), false, Vector2i(0, 8)):
		failures.append("west vertical")
	var south: Dictionary = set_spawn(doc, Vector2i(4, 19))
	if not south.get("ok", false) or not _flat(MapPlan.cells_of_rect(doc.spawn_rects()[doc.spawn_rects().size() - 1]), true, Vector2i(4, 19)):
		failures.append("south horizontal")
	var east: Dictionary = set_spawn(doc, Vector2i(19, 3))
	if not east.get("ok", false) or not _flat(MapPlan.cells_of_rect(doc.spawn_rects()[doc.spawn_rects().size() - 1]), false, Vector2i(19, 3)):
		failures.append("east vertical")
	var again: Dictionary = set_spawn(doc, Vector2i(10, 0))
	if str(again.get("action", "")) != "spawn_have":
		failures.append("duplicate middle")
	var bad: Dictionary = set_spawn(doc, Vector2i(0, 0))
	if str(bad.get("action", "")) != "corner":
		failures.append("corner spawn")


static func _expect_pieces(failures: Array[String]) -> void:
	var doc := _blank()
	var drop: Dictionary = MapInteraction.op_for(Vector2i(10, 8), {"layer": "unit", "id": "spearman"}, false)
	var click_place := {"op": "place", "layer": "build", "id": "HOUSE", "cell": Vector2i(8, 8)}
	if str(apply(doc, drop).get("action", "")) != "placed":
		failures.append("place unit")
	if str(apply(doc, click_place).get("action", "")) != "placed":
		failures.append("place house")
	var border: Dictionary = apply(doc, MapInteraction.op_for(Vector2i(5, 0), {"layer": "build", "id": "WALL"}, false))
	if border.get("ok", true):
		failures.append("border place")
	var rock: Dictionary = apply(doc, MapInteraction.op_for(Vector2i(4, 8), {"layer": "prop", "id": "tree"}, true))
	if str(rock.get("action", "")) != "rock":
		failures.append("fixed rock")
	var prop: Dictionary = place(doc, "prop", "rock", Vector2i(6, 6))
	if not prop.get("ok", false):
		failures.append("prop")
	var moved: Dictionary = move(doc, "unit", 0, Vector2i(12, 9))
	if not moved.get("ok", false) or not _has_unit(doc, Vector2i(12, 9), "spearman"):
		failures.append("move unit")
	if _has_unit(doc, Vector2i(10, 8), "spearman"):
		failures.append("move left the old cell")
	var removed: Dictionary = remove_at(doc, Vector2i(12, 9))
	if str(removed.get("action", "")) != "removed" or _has_unit(doc, Vector2i(12, 9), "spearman"):
		failures.append("remove unit")
	var only := _blank()
	var kept: Dictionary = remove_at(only, Vector2i(10, 0))
	if str(kept.get("action", "")) != "need_spawn" or only.spawn_rects().size() != 1:
		failures.append("keep one spawn")


static func _blank() -> SetupDocument:
	var doc := SetupDocument.new()
	doc.bind({
		"spawn_rects": MapPlan.default_rects(),
		"spawns": MapPlan.cells_from_rects(MapPlan.default_rects()),
		"starter_buildings": [],
		"starter_units": [],
		"starter_props": [],
	})
	return doc


static func _flat(cells: Array, horizontal: bool, middle: Vector2i) -> bool:
	if cells.size() != 3:
		return false
	if cells[1] != middle:
		return false
	if horizontal:
		return cells[0].y == middle.y and cells[2].y == middle.y and cells[0].x == middle.x - 1 and cells[2].x == middle.x + 1
	return cells[0].x == middle.x and cells[2].x == middle.x and cells[0].y == middle.y - 1 and cells[2].y == middle.y + 1


static func _has_unit(doc: SetupDocument, cell: Vector2i, id: String) -> bool:
	for item in doc.starter_units():
		if item is Dictionary and str(item.get("unit", "")) == id:
			var raw = item.get("cell", [])
			if raw is Array and raw.size() >= 2 and int(raw[0]) == cell.x and int(raw[1]) == cell.y:
				return true
	return false


static func _id_allowed(layer: String, id: String) -> bool:
	if layer == "unit":
		return MapPlan.unit_ids().has(id)
	if layer == "build":
		return MapPlan.build_ids().has(id)
	return id == "tree" or id == "rock"


static func _next_sex(doc: SetupDocument, unit_id: String) -> String:
	if unit_id != "villager":
		return "m"
	var males := 0
	var females := 0
	for item in doc.starter_units():
		if not (item is Dictionary) or str(item.get("unit", "")) != "villager":
			continue
		if str(item.get("sex", "m")) == "f":
			females += 1
		else:
			males += 1
	return "f" if females < males else "m"


static func _no(action: String, cell: Vector2i) -> Dictionary:
	return {"ok": false, "action": action, "cell": cell}
