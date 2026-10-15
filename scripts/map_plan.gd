class_name MapPlan
extends RefCounted

# Shared map geometry for the match and the workbench.
# 20×20 square cells, tile 128. Cell (0, 0) is the north-west corner.
# +x is east, +y is south. The outermost ring is the border. The four
# corners are never the middle of an enemy gate.

const COLS := 20
const ROWS := 20
const TILE := 128.0
const SPAWN_LENGTH := 3
const SPAWN_WIDTH := 1
const HEART := Vector2i(10, 14)
const SPAWN_MASK := Color(0.95, 0.06, 0.05, 0.6)
const ROCKS: Array[Vector2i] = [
	Vector2i(4, 8), Vector2i(16, 8), Vector2i(4, 16), Vector2i(16, 16),
]
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const EDGES: Array[String] = ["north", "south", "west", "east"]

static func default_rects() -> Array:
	return [{
		"edge": "north",
		"middle": [10, 0],
		"length": SPAWN_LENGTH,
		"width": SPAWN_WIDTH,
	}]

static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS

static func is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == COLS - 1 or cell.y == ROWS - 1

static func is_corner(cell: Vector2i) -> bool:
	var x_edge := cell.x == 0 or cell.x == COLS - 1
	var y_edge := cell.y == 0 or cell.y == ROWS - 1
	return x_edge and y_edge

static func is_fixed_rock(cell: Vector2i) -> bool:
	return cell in ROCKS

static func edge_of(cell: Vector2i) -> String:
	if not in_bounds(cell) or is_corner(cell) or not is_border(cell):
		return ""
	if cell.y == 0:
		return "north"
	if cell.y == ROWS - 1:
		return "south"
	if cell.x == 0:
		return "west"
	return "east"

static func rect_from_middle(cell: Vector2i) -> Dictionary:
	var edge := edge_of(cell)
	if edge == "":
		return {}
	var index := cell.x if edge == "north" or edge == "south" else cell.y
	return _make_rect(edge, index)

static func cells_of_rect(rect: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if rect.is_empty():
		return empty
	var middle = rect.get("middle", [])
	if not (middle is Array) or middle.size() < 2:
		return empty
	var cell := Vector2i(int(middle[0]), int(middle[1]))
	var built := rect_from_middle(cell)
	if built.is_empty():
		return empty
	var edge := str(rect.get("edge", ""))
	if edge != "" and edge != str(built.get("edge", "")):
		return empty
	var out: Array[Vector2i] = []
	if str(built.get("edge", "")) == "north" or str(built.get("edge", "")) == "south":
		out.append(Vector2i(cell.x - 1, cell.y))
		out.append(cell)
		out.append(Vector2i(cell.x + 1, cell.y))
	else:
		out.append(Vector2i(cell.x, cell.y - 1))
		out.append(cell)
		out.append(Vector2i(cell.x, cell.y + 1))
	return out

static func cells_from_rects(rects: Array) -> Array:
	var out: Array = []
	var seen := {}
	for rect in rects:
		if not (rect is Dictionary):
			continue
		for cell in cells_of_rect(rect):
			var key := "%d,%d" % [cell.x, cell.y]
			if seen.has(key):
				continue
			seen[key] = true
			out.append([cell.x, cell.y])
	return out

static func clean_rects(raw: Array) -> Array:
	var out: Array = []
	var seen := {}
	for item in raw:
		if not (item is Dictionary):
			continue
		var middle = item.get("middle", [])
		if not (middle is Array) or middle.size() < 2:
			continue
		var cell := Vector2i(int(middle[0]), int(middle[1]))
		var rect := rect_from_middle(cell)
		if rect.is_empty():
			continue
		var edge := str(item.get("edge", ""))
		if edge != "" and edge != str(rect.get("edge", "")):
			continue
		var key := "%s:%d,%d" % [str(rect.get("edge", "")), cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(rect)
	return out

static func rects_from_cells(raw) -> Array:
	var cells := {}
	if raw is Array:
		for item in raw:
			var cell := _cell_from(item)
			if in_bounds(cell):
				cells[cell] = true
	var rects: Array = []
	for edge in EDGES:
		var horizontal := edge == "north" or edge == "south"
		var limit := COLS if horizontal else ROWS
		var indexes: Array[int] = []
		for i in limit:
			if cells.has(_edge_cell(edge, i)):
				indexes.append(i)
		var cursor := 0
		while cursor < indexes.size():
			var end_i := cursor
			while end_i + 1 < indexes.size() and indexes[end_i + 1] == indexes[end_i] + 1:
				end_i += 1
			var start: int = indexes[cursor]
			var endv: int = indexes[end_i]
			if _run_has_body(start, endv, limit):
				for mid in _cover_run(edge, start, endv):
					var rect := _make_rect(edge, mid)
					if not rect.is_empty():
						rects.append(rect)
			cursor = end_i + 1
	return clean_rects(rects)

static func resolve_layout(raw_rects, raw_spawns) -> Dictionary:
	var rects := clean_rects(raw_rects if raw_rects is Array else [])
	var spawns := _clean_spawn_list(raw_spawns if raw_spawns is Array else [])
	var from_rects := cells_from_rects(rects)
	if rects.is_empty():
		rects = clean_rects(rects_from_cells(spawns))
	elif not spawns.is_empty() and not same_cells(from_rects, spawns) and rects_match_default(rects):
		var derived := clean_rects(rects_from_cells(spawns))
		if not derived.is_empty():
			rects = derived
	if rects.is_empty():
		rects = default_rects()
	return {
		"spawn_rects": rects,
		"spawns": cells_from_rects(rects),
	}

static func spawn_lookup(rects: Array) -> Dictionary:
	var out := {}
	for rect in rects:
		if rect is Dictionary:
			for cell in cells_of_rect(rect):
				out[cell] = true
	return out

static func scenery_cells(spawn_cells: Dictionary, props: Array) -> Dictionary:
	var out := {}
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if is_border(cell) and not spawn_cells.has(cell):
				out[cell] = true
	for rock in ROCKS:
		out[rock] = true
	if props is Array:
		for item in props:
			if not (item is Dictionary):
				continue
			var kind := str(item.get("kind", ""))
			if kind != "tree" and kind != "rock":
				continue
			var cell := _cell_from(item)
			if not in_bounds(cell) or spawn_cells.has(cell):
				continue
			out[cell] = true
	return out

static func road_cells(blocked: Dictionary, spawns: Array) -> Dictionary:
	# Legacy visual trace from every spawn cell. Painted roads and combat
	# pathfinding do not use this. Roads are an authored cell list.
	var trail := {}
	for item in spawns:
		var start := _cell_from(item)
		for cell in _astar(start, HEART, blocked):
			trail[cell] = true
	return trail

static func default_roads() -> Array:
	var out: Array = []
	for y in HEART.y + 1:
		out.append([HEART.x, y])
	return out

static func middle_of(rect: Dictionary) -> Vector2i:
	var middle = rect.get("middle", [])
	if middle is Array and middle.size() >= 2:
		return Vector2i(int(middle[0]), int(middle[1]))
	return Vector2i(-1, -1)

static func clean_roads(raw) -> Array:
	var out: Array = []
	var seen := {}
	if not (raw is Array):
		return out
	for item in raw:
		var cell := _cell_from(item)
		if not in_bounds(cell) or is_fixed_rock(cell):
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append([cell.x, cell.y])
	return out

static func road_lookup(raw) -> Dictionary:
	var out := {}
	for item in clean_roads(raw):
		out[Vector2i(int(item[0]), int(item[1]))] = true
	return out

static func clean_props(raw, blocked: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	if not (raw is Array):
		return out
	for item in raw:
		if not (item is Dictionary):
			continue
		var kind := str(item.get("kind", ""))
		if kind != "tree" and kind != "rock":
			continue
		var cell := _cell_from(item)
		if not in_bounds(cell) or is_border(cell) or is_fixed_rock(cell) or blocked.has(cell):
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"kind": kind, "cell": [cell.x, cell.y]})
	return out

static func clean_placed(raw, id_key: String, allowed: Dictionary, blocked: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	if not (raw is Array):
		return out
	for item in raw:
		if not (item is Dictionary):
			continue
		var id := str(item.get(id_key, ""))
		if not allowed.has(id):
			continue
		var cell := _cell_from(item.get("cell", []))
		if not in_bounds(cell) or is_border(cell) or is_fixed_rock(cell) or blocked.has(cell):
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		var copy: Dictionary = item.duplicate(true)
		copy[id_key] = id
		copy["cell"] = [cell.x, cell.y]
		out.append(copy)
	return out

static func build_ids() -> Dictionary:
	var ids := {}
	for id in ["WALL", "SPEAR", "FIRE", "HOUSE", "FARM", "WORKSHOP", "LUMBER", "SPEAR_BARRACKS", "GUN_BARRACKS"]:
		ids[id] = true
	return ids

static func unit_ids() -> Dictionary:
	var ids := {}
	for id in ["villager", "spearman", "gunner", "engineer"]:
		ids[id] = true
	return ids

static func same_cells(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if _cell_from(a[i]) != _cell_from(b[i]):
			return false
	return true

static func rects_match_default(rects: Array) -> bool:
	var cleaned := clean_rects(rects)
	var base := default_rects()
	if cleaned.size() != base.size():
		return false
	for i in cleaned.size():
		if str(cleaned[i].get("edge", "")) != str(base[i].get("edge", "")):
			return false
		if not same_cells([cleaned[i].get("middle", [])], [base[i].get("middle", [])]):
			return false
	return true

static func unit_palette() -> Array:
	return [
		_item("unit", "villager", "walker", Color(0.36, 0.70, 0.86), "unit.villager"),
		_item("unit", "spearman", "walker", Color(0.45, 0.52, 0.82), "unit.spearman"),
		_item("unit", "gunner", "walker", Color(0.36, 0.55, 0.40), "unit.gunner"),
		_item("unit", "engineer", "walker", Color(0.72, 0.48, 0.28), "unit.engineer"),
	]

static func build_palette() -> Array:
	return [
		_item("build", "WALL", "wall", Color(0.62, 0.50, 0.34), "build.wall"),
		_item("build", "SPEAR", "spear", Color(0.78, 0.70, 0.42), "build.spear"),
		_item("build", "FIRE", "fire", Color(0.86, 0.38, 0.18), "build.fire"),
		_item("build", "HOUSE", "house", Color(0.78, 0.48, 0.30), "build.house"),
		_item("build", "FARM", "farm", Color(0.62, 0.72, 0.32), "build.farm"),
		_item("build", "WORKSHOP", "workshop", Color(0.50, 0.42, 0.62), "build.workshop"),
		_item("build", "LUMBER", "lumber", Color(0.55, 0.36, 0.20), "build.lumber"),
		_item("build", "SPEAR_BARRACKS", "spear_barracks", Color(0.38, 0.50, 0.70), "build.spear_barracks"),
		_item("build", "GUN_BARRACKS", "gun_barracks", Color(0.32, 0.42, 0.36), "build.gun_barracks"),
	]

static func prop_palette() -> Array:
	return [
		_item("prop", "tree", "tree", Color(0.24, 0.55, 0.30), "bench.prop.tree"),
		_item("prop", "rock", "rock", Color(0.48, 0.50, 0.54), "bench.prop.rock"),
	]

static func volume_for(layer: String, id: String) -> String:
	for group in [unit_palette(), build_palette(), prop_palette()]:
		for item in group:
			if str(item.get("layer", "")) == layer and str(item.get("id", "")) == id:
				return str(item.get("volume", "walker"))
	return "walker"

static func tint_for(layer: String, id: String) -> Color:
	for group in [unit_palette(), build_palette(), prop_palette()]:
		for item in group:
			if str(item.get("layer", "")) == layer and str(item.get("id", "")) == id:
				return item.get("tint", Color.WHITE)
	return Color(0.7, 0.7, 0.7)

static func _item(layer: String, id: String, volume: String, tint: Color, label: String) -> Dictionary:
	return {"layer": layer, "id": id, "volume": volume, "tint": tint, "label": label}

static func _make_rect(edge: String, index: int) -> Dictionary:
	if not _middle_ok(edge, index):
		return {}
	var middle := Vector2i.ZERO
	match edge:
		"north":
			middle = Vector2i(index, 0)
		"south":
			middle = Vector2i(index, ROWS - 1)
		"west":
			middle = Vector2i(0, index)
		"east":
			middle = Vector2i(COLS - 1, index)
		_:
			return {}
	return {
		"edge": edge,
		"middle": [middle.x, middle.y],
		"length": SPAWN_LENGTH,
		"width": SPAWN_WIDTH,
	}

static func _middle_ok(edge: String, index: int) -> bool:
	var limit := COLS if edge == "north" or edge == "south" else ROWS
	return index >= 1 and index <= limit - 2

static func _edge_cell(edge: String, index: int) -> Vector2i:
	match edge:
		"north":
			return Vector2i(index, 0)
		"south":
			return Vector2i(index, ROWS - 1)
		"west":
			return Vector2i(0, index)
		_:
			return Vector2i(COLS - 1, index)

static func _run_has_body(start: int, endv: int, limit: int) -> bool:
	for i in range(start, endv + 1):
		if i != 0 and i != limit - 1:
			return true
	return false

static func _cover_run(edge: String, start: int, endv: int) -> Array[int]:
	var mids: Array[int] = []
	var length := endv - start + 1
	if length >= SPAWN_LENGTH:
		var cursor := start
		while cursor + 2 <= endv:
			var middle := cursor + 1
			if _middle_ok(edge, middle):
				mids.append(middle)
			cursor += SPAWN_LENGTH
		if not _run_covered(mids, start, endv):
			var tail := endv - 1
			if _middle_ok(edge, tail) and not (tail in mids):
				mids.append(tail)
	else:
		var centroid := (float(start) + float(endv)) * 0.5
		var best := -1
		var best_d := 9999.0
		var limit := COLS if edge == "north" or edge == "south" else ROWS
		for mid in range(1, limit - 1):
			if mid - 1 > start or mid + 1 < endv:
				continue
			var dist := absf(float(mid) - centroid)
			if dist < best_d:
				best_d = dist
				best = mid
		if best >= 0:
			mids.append(best)
	return mids

static func _run_covered(mids: Array[int], start: int, endv: int) -> bool:
	for i in range(start, endv + 1):
		var hit := false
		for mid in mids:
			if absi(i - mid) <= 1:
				hit = true
				break
		if not hit:
			return false
	return true

static func _clean_spawn_list(raw: Array) -> Array:
	var out: Array = []
	var seen := {}
	for item in raw:
		var cell := _cell_from(item)
		if not in_bounds(cell):
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append([cell.x, cell.y])
	return out

static func _cell_from(item) -> Vector2i:
	if item is Vector2i:
		return item
	if item is Array and item.size() >= 2:
		return Vector2i(int(item[0]), int(item[1]))
	if item is Dictionary:
		var raw = item.get("cell", item.get("middle", []))
		if raw is Array and raw.size() >= 2:
			return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i(-1, -1)

static func _astar(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == goal and in_bounds(start):
		empty.append(start)
		return empty
	if not in_bounds(start) or not in_bounds(goal):
		return empty
	var open: Array[Vector2i] = [start]
	var came := {}
	var gscore := {start: 0}
	var closed := {}
	while not open.is_empty():
		var best_i := 0
		var best_f := 999999
		for i in open.size():
			var f := int(gscore[open[i]]) + absi(open[i].x - goal.x) + absi(open[i].y - goal.y)
			if f < best_f:
				best_f = f
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)
		if closed.has(current):
			continue
		if current == goal:
			return _rebuild(came, current)
		closed[current] = true
		for dir in DIRS:
			var nxt: Vector2i = current + dir
			if closed.has(nxt) or not in_bounds(nxt):
				continue
			if nxt != goal and blocked.has(nxt):
				continue
			var tentative := int(gscore[current]) + 1
			if tentative < int(gscore.get(nxt, 999999)):
				came[nxt] = current
				gscore[nxt] = tentative
				open.append(nxt)
	return empty

static func _rebuild(came: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var guard := 0
	while came.has(current) and guard < 800:
		current = came[current]
		path.push_front(current)
		guard += 1
	return path
