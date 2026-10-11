extends Node2D

const COLS := 10
const ROWS := 10
const TILE := Vector2i(132, 66)
const CORE_CELL := Vector2i(5, 8)
const SPAWNS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)
]
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const START_WOOD := 120
const START_GOLD := 80
const CORE_MAX := 20
const TOTAL_WAVES := 8

const WAVES: Array[Dictionary] = [
	{"n": 6, "hp": 36, "speed": 52.0, "gap": 0.85, "fast": 0, "brute": 0, "boss": 0},
	{"n": 8, "hp": 48, "speed": 54.0, "gap": 0.74, "fast": 2, "brute": 0, "boss": 0},
	{"n": 9, "hp": 60, "speed": 54.0, "gap": 0.66, "fast": 3, "brute": 1, "boss": 0},
	{"n": 10, "hp": 74, "speed": 56.0, "gap": 0.58, "fast": 3, "brute": 2, "boss": 0},
	{"n": 10, "hp": 90, "speed": 56.0, "gap": 0.54, "fast": 3, "brute": 2, "boss": 0},
	{"n": 11, "hp": 104, "speed": 58.0, "gap": 0.5, "fast": 4, "brute": 3, "boss": 0},
	{"n": 12, "hp": 120, "speed": 58.0, "gap": 0.46, "fast": 4, "brute": 3, "boss": 0},
	{"n": 10, "hp": 132, "speed": 56.0, "gap": 0.5, "fast": 3, "brute": 3, "boss": 1},
]

const KIND_MOD := {
	"normal": {"hp": 1.0, "speed": 1.0, "scale": 1.18, "dmg": 1, "wood": 2, "gold": 4, "mod": Color(1, 1, 1)},
	"fast": {"hp": 0.7, "speed": 1.48, "scale": 1.0, "dmg": 1, "wood": 1, "gold": 5, "mod": Color(0.82, 1, 0.78)},
	"brute": {"hp": 2.35, "speed": 0.68, "scale": 1.38, "dmg": 2, "wood": 3, "gold": 9, "mod": Color(0.72, 0.86, 0.68)},
	"boss": {"hp": 4.8, "speed": 0.58, "scale": 1.7, "dmg": 3, "wood": 8, "gold": 30, "mod": Color(0.62, 0.82, 0.55)},
}

var wood := START_WOOD
var gold := START_GOLD
var core_hp := CORE_MAX
var core_cell := CORE_CELL
var core_pos := Vector2.ZERO
var phase := "prep"
var wave_number := 0
var inspected: Building = null

var ground: TileMapLayer
var actors: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Hud
var font: Font
var core_marker: Node2D

var buildings := {}
var scenery := {}
var spawn_queue: Array[String] = []
var spawn_cd := 0.0
var spawn_gap := 0.8
var spawn_cursor := 0
var _selftest := false
var _selftest_t0 := 0

func _ready() -> void:
	Engine.max_fps = 60
	add_to_group("game")
	font = load("res://assets/fonts/DroidSansFallback-subset.ttf")
	_selftest = OS.get_environment("TD_SELFTEST") == "1"
	_build_world()
	_paint_map()
	_check_opening()
	_build_camera()
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_try_start_wave)
	hud.restart_pressed.connect(_restart)
	_refresh_hud()
	if (_selftest or OS.get_environment("TD_DEMO") == "1") and OS.get_environment("TD_NONE") != "1":
		_scripted_defense()
	if _selftest:
		Engine.time_scale = 8.0
		_selftest_t0 = Time.get_ticks_msec()
		_try_start_wave()
	elif OS.get_environment("TD_DEMO") == "1":
		_try_start_wave()
		_demo_shot()
	elif OS.get_environment("TD_SHOT") == "1":
		_opening_shot()

func _process(delta: float) -> void:
	queue_redraw()
	_update_ghost()
	if phase == "combat":
		_tick_spawns(delta)
	if _selftest and Time.get_ticks_msec() - _selftest_t0 > 120000:
		print("SELFTEST_TIMEOUT core=", core_hp, " wave=", wave_number, " alive=", _living().size())
		get_tree().quit(1)

func _draw() -> void:
	if OS.get_environment("TD_GRID") != "1" or ground == null:
		return
	for y in ROWS:
		for x in COLS:
			draw_circle(ground.map_to_local(Vector2i(x, y)), 4, Color(1, 0.2, 0.2, 0.85))

func _unhandled_input(event: InputEvent) -> void:
	if hud != null and hud.is_blocking():
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_left_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				hud.select_kind(Building.Kind.WALL)
			KEY_2:
				hud.select_kind(Building.Kind.SPEAR)
			KEY_3:
				hud.select_kind(Building.Kind.FIRE)
			KEY_ESCAPE:
				hud.select_kind(-1)
				inspected = null
			KEY_SPACE, KEY_ENTER:
				_try_start_wave()
			KEY_R:
				if phase == "win" or phase == "lose":
					_restart()

func _build_world() -> void:
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -1
	ground.y_sort_enabled = true
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = TILE
	var files := [
		"res://assets/kenney/landscape/grass_a.png",
		"res://assets/kenney/landscape/grass_b.png",
		"res://assets/kenney/landscape/grass_c.png",
		"res://assets/kenney/landscape/grass_d.png",
		"res://assets/kenney/landscape/dirt.png",
	]
	for i in files.size():
		var atlas := TileSetAtlasSource.new()
		var tex: Texture2D = load(files[i])
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		atlas.create_tile(Vector2i.ZERO)
		var data := atlas.get_tile_data(Vector2i.ZERO, 0)
		data.texture_origin = Vector2i(0, -16)
		tileset.add_source(atlas, i)
	ground.tile_set = tileset
	add_child(ground)

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_index = 4
	add_child(fx)

func _paint_map() -> void:
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if _is_border(cell) and not _is_spawn(cell):
				scenery[cell] = true
	scenery[Vector2i(2, 4)] = true
	scenery[Vector2i(7, 6)] = true
	scenery[Vector2i(4, 8)] = true
	scenery[Vector2i(6, 8)] = true

	var trail := {}
	for spawn in SPAWNS:
		for cell in _astar(spawn, CORE_CELL).path:
			trail[cell] = true

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var source := (x * 3 + y * 5) % 4
			if trail.has(cell) and cell != CORE_CELL and not scenery.has(cell):
				source = 4
			ground.set_cell(cell, source, Vector2i.ZERO)

	_place_prop(Vector2i(2, 4), load("res://assets/kenney/details/rock.png"))
	_place_prop(Vector2i(7, 6), load("res://assets/kenney/details/rock.png"))
	_place_prop(Vector2i(4, 8), load("res://assets/kenney/buildings/hut.png"))
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if not _is_border(cell) or _is_spawn(cell):
				continue
			var trees := [
				"res://assets/kenney/details/tree_a.png",
				"res://assets/kenney/details/tree_b.png",
			]
			_place_prop(cell, load(trees[(x + y) % trees.size()]))

	var tree: Texture2D = load("res://assets/kenney/details/tree_core.png")
	var heart := Node2D.new()
	heart.position = cell_center(CORE_CELL)
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.polygon = _ellipse(22, 9, 6)
	heart.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = tree
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(-tree.get_width() * 0.5, 33.0 - tree.get_height())
	sprite.z_index = 1
	heart.add_child(sprite)
	core_marker = preload("res://scripts/marker.gd").new()
	core_marker.position = Vector2(0, sprite.position.y - 6)
	core_marker.z_index = 3
	core_marker.hp = core_hp
	core_marker.max_hp = CORE_MAX
	core_marker.title = "圣树"
	heart.add_child(core_marker)
	actors.add_child(heart)
	core_pos = heart.position

func _place_prop(cell: Vector2i, tex: Texture2D) -> void:
	var node := Node2D.new()
	node.position = cell_center(cell)
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.25)
	shadow.polygon = _ellipse(16, 7, 6)
	node.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(-tex.get_width() * 0.5, 33.0 - tex.get_height())
	sprite.z_index = 1
	node.add_child(sprite)
	actors.add_child(node)

func _ellipse(rx: float, ry: float, lift: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry + lift))
	return pts

func _build_camera() -> void:
	camera = Camera2D.new()
	var a := cell_center(Vector2i(0, 0))
	var b := cell_center(Vector2i(COLS - 1, ROWS - 1))
	camera.position = (a + b) * 0.5 + Vector2(0, 48)
	camera.zoom = Vector2(0.78, 0.78)
	add_child(camera)
	camera.make_current()

func _check_opening() -> void:
	for spawn in SPAWNS:
		var info := _astar(spawn, CORE_CELL)
		if info.path.is_empty():
			push_error("No path from %s to the core. Map is sealed." % str(spawn))

func cell_center(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)

func world_to_cell(world: Vector2) -> Vector2i:
	return ground.local_to_map(world)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS

func nearest_spawn(world: Vector2) -> Vector2i:
	var best := SPAWNS[0]
	var best_d := INF
	for cell in SPAWNS:
		var d := world.distance_squared_to(cell_center(cell))
		if d < best_d:
			best_d = d
			best = cell
	return best

func route_from(start: Vector2i) -> Dictionary:
	var info := _astar(start, CORE_CELL)
	if not info.path.is_empty():
		return {"path": info.path, "attack": Vector2i(-1, -1), "core": true}
	return _path_to_building(start)

func can_attack_cell(cell: Vector2i, attack_core: bool) -> bool:
	if attack_core:
		return core_hp > 0 and phase != "lose"
	return buildings.has(cell)

func damage_cell(cell: Vector2i, attack_core: bool, amount: int) -> void:
	if phase == "win" or phase == "lose":
		return
	if attack_core:
		_hurt_core(amount)
		return
	if not buildings.has(cell):
		return
	var building: Building = buildings[cell]
	_popup(building.global_position + Vector2(0, -40), "-%d" % amount, Color(1, 0.8, 0.45))
	if building.hurt(amount):
		_remove_building(cell, false)

func apply_hit(at: Vector2, damage: int, splash: float, is_fire: bool, target: Node2D) -> void:
	if is_fire or splash > 0.0:
		fx.add_child(_burst(at, splash if splash > 0.0 else 28.0, Color(1, 0.45, 0.1)))
		for z in _living():
			if z.global_position.distance_to(at) <= splash:
				z.hurt(damage)
	else:
		fx.add_child(_burst(at, 14.0, Color(0.95, 0.9, 0.7)))
		if is_instance_valid(target) and target is Zombie and not (target as Zombie).dying:
			(target as Zombie).hurt(damage)
		else:
			var nearest: Zombie = null
			var best := 26.0
			for z in _living():
				var d := z.global_position.distance_to(at)
				if d < best:
					best = d
					nearest = z
			if nearest:
				nearest.hurt(damage)

func on_zombie_killed(z: Zombie) -> void:
	if phase == "lose":
		return
	wood += z.reward_wood
	gold += z.reward_gold
	_popup(z.global_position, "+%d金" % z.reward_gold, Color(1, 0.86, 0.3))
	_refresh_hud()

func _hurt_core(amount: int) -> void:
	core_hp = maxi(core_hp - amount, 0)
	if core_marker:
		core_marker.hp = core_hp
	_popup(core_pos + Vector2(0, -70), "-%d" % amount, Color(1, 0.45, 0.35))
	_refresh_hud()
	if core_hp <= 0 and phase != "lose":
		_finish(false)

func _try_start_wave() -> void:
	if phase != "prep":
		return
	if wave_number >= TOTAL_WAVES:
		return
	var spec: Dictionary = WAVES[wave_number]
	wave_number += 1
	phase = "combat"
	spawn_gap = float(spec.gap)
	spawn_cd = 0.35
	spawn_queue = _compose_wave(spec)
	hud.flash("第 %d 波来袭  /  Wave %d" % [wave_number, wave_number])
	_refresh_hud()

func _compose_wave(spec: Dictionary) -> Array[String]:
	var list: Array[String] = []
	var normals := int(spec.n)
	for _i in normals:
		list.append("normal")
	for _i in int(spec.fast):
		list.append("fast")
	for _i in int(spec.brute):
		list.append("brute")
	list.shuffle()
	for _i in int(spec.boss):
		list.append("boss")
	return list

func _tick_spawns(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			_spawn_zombie(spawn_queue.pop_front())
			spawn_cd = spawn_gap
	elif _living().is_empty():
		_on_wave_cleared()

func _spawn_zombie(kind: String) -> void:
	var spec: Dictionary = WAVES[wave_number - 1]
	var mod: Dictionary = KIND_MOD[kind]
	var z := Zombie.new()
	var cell := SPAWNS[spawn_cursor % SPAWNS.size()]
	spawn_cursor += 1
	z.position = cell_center(cell)
	z.setup(
		maxi(int(round(float(spec.hp) * float(mod.hp))), 1),
		float(spec.speed) * float(mod.speed),
		float(mod.scale),
		int(mod.dmg),
		int(mod.wood),
		int(mod.gold),
		kind,
		mod.mod
	)
	actors.add_child(z)

func _on_wave_cleared() -> void:
	if phase != "combat":
		return
	if wave_number >= TOTAL_WAVES:
		_finish(true)
		return
	wood += 14 + wave_number * 2
	gold += 18 + wave_number * 4
	phase = "prep"
	hud.flash("第 %d 波已清除。准备下一波。  /  Wave %d cleared." % [wave_number, wave_number])
	_refresh_hud()
	if _selftest:
		_try_start_wave()

func _finish(win: bool) -> void:
	phase = "win" if win else "lose"
	hud.show_end(win)
	_refresh_hud()
	if _selftest:
		print("SELFTEST_%s" % ("WIN" if win else "LOSE"))
		print("SELFTEST_CORE ", core_hp, " WAVE ", wave_number)
		get_tree().quit(0 if win else 1)

func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _left_click() -> void:
	var cell := _mouse_cell()
	if not in_bounds(cell):
		return
	var kind := hud.selected_kind()
	if kind < 0:
		inspected = buildings[cell] if buildings.has(cell) else null
		return
	_try_place(kind, cell)

func _right_click() -> void:
	var cell := _mouse_cell()
	if buildings.has(cell):
		_remove_building(cell, true)
		return
	hud.select_kind(-1)
	inspected = null

func _try_place(kind: int, cell: Vector2i) -> void:
	var reason := _block_reason(cell)
	if reason != "":
		hud.flash(reason)
		return
	var stats: Dictionary = Building.STATS[kind]
	if wood < int(stats.wood) or gold < int(stats.gold):
		hud.flash("资源不足  /  Not enough wood or gold")
		return
	wood -= int(stats.wood)
	gold -= int(stats.gold)
	var building := Building.new()
	building.position = cell_center(cell)
	building.setup(kind as Building.Kind, cell)
	actors.add_child(building)
	buildings[cell] = building
	inspected = building
	_notify_zombies()
	_refresh_hud()

func _remove_building(cell: Vector2i, refund: bool) -> void:
	if not buildings.has(cell):
		return
	var building: Building = buildings[cell]
	if refund:
		var stats: Dictionary = Building.STATS[building.kind]
		var rw := int(stats.wood) / 2
		var rg := int(stats.gold) / 2
		wood += rw
		gold += rg
		_popup(building.global_position, "出售 +%d木 +%d金" % [rw, rg], Color(0.85, 0.95, 0.7))
	buildings.erase(cell)
	if inspected == building:
		inspected = null
	building.queue_free()
	_notify_zombies()
	_refresh_hud()

func _block_reason(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "超出地图  /  Outside the map"
	if cell == CORE_CELL or scenery.has(cell) or _is_spawn(cell):
		return "这里不能建造  /  Can't build here"
	if buildings.has(cell):
		return "格子已占用  /  Tile occupied"
	for z in _living():
		if world_to_cell(z.global_position) == cell:
			return "僵尸占着格子  /  A zombie is standing here"
	return ""

func _notify_zombies() -> void:
	for z in _living():
		z.notify_map_changed()

func _living() -> Array[Zombie]:
	var list: Array[Zombie] = []
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z != null and not z.dying:
			list.append(z)
	return list

func _mouse_cell() -> Vector2i:
	return world_to_cell(get_global_mouse_position())

func _update_ghost() -> void:
	var ghost := fx.get_node_or_null("Ghost")
	var kind := hud.selected_kind() if hud else -1
	if kind < 0:
		if ghost:
			ghost.visible = false
		return
	var cell := _mouse_cell()
	if not in_bounds(cell):
		if ghost:
			ghost.visible = false
		return
	if ghost == null:
		ghost = Node2D.new()
		ghost.name = "Ghost"
		fx.add_child(ghost)
	ghost.visible = true
	ghost.position = cell_center(cell)
	var tex: Texture2D = load(Building.STATS[kind].tex)
	var sprite := ghost.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = false
		sprite.z_index = 1
		ghost.add_child(sprite)
	if sprite.texture != tex:
		sprite.texture = tex
		sprite.position = Vector2(-tex.get_width() * 0.5, 33.0 - tex.get_height())
	var ok := _block_reason(cell) == ""
	var stats: Dictionary = Building.STATS[kind]
	if wood < int(stats.wood) or gold < int(stats.gold):
		ok = false
	sprite.modulate = Color(0.6, 1, 0.6, 0.55) if ok else Color(1, 0.35, 0.3, 0.55)
	var ring := ghost.get_node_or_null("Ring") as Node2D
	if ring == null:
		ring = RangeRing.new()
		ring.name = "Ring"
		ghost.add_child(ring)
	ring.visible = float(stats.range) > 0.0
	ring.set("radius", float(stats.range))

func _popup(at: Vector2, text: String, color: Color) -> void:
	var pop := PopupText.new()
	pop.position = at
	pop.setup(text, color, font)
	fx.add_child(pop)

func _burst(at: Vector2, radius: float, color: Color) -> Burst:
	var burst := Burst.new()
	burst.position = at
	burst.setup(radius, color)
	return burst

func _refresh_hud() -> void:
	if hud == null:
		return
	var label := "准备  Ready"
	if phase == "combat":
		label = "波次 Wave %d / %d" % [wave_number, TOTAL_WAVES]
	elif wave_number > 0 and phase == "prep":
		label = "下一波 Next %d / %d" % [wave_number + 1, TOTAL_WAVES]
	elif phase == "win":
		label = "胜利 Victory"
	elif phase == "lose":
		label = "失败 Defeat"
	else:
		label = "波次 Wave 0 / %d" % TOTAL_WAVES
	hud.refresh(wood, gold, label, core_hp, CORE_MAX, phase)

func _is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == COLS - 1 or cell.y == ROWS - 1

func _is_spawn(cell: Vector2i) -> bool:
	return cell in SPAWNS

func _blocked(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	if scenery.has(cell):
		return true
	if buildings.has(cell):
		return true
	return false

func _astar(start: Vector2i, goal: Vector2i) -> Dictionary:
	if start == goal:
		var only: Array[Vector2i] = [start]
		return {"path": only}
	if _blocked(start):
		return {"path": [] as Array[Vector2i]}
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
			return {"path": _rebuild(came, current)}
		closed[current] = true
		for dir in DIRS:
			var nxt: Vector2i = current + dir
			if closed.has(nxt):
				continue
			if nxt != goal and _blocked(nxt):
				continue
			if not in_bounds(nxt):
				continue
			var tentative := int(gscore[current]) + 1
			if tentative < int(gscore.get(nxt, 999999)):
				came[nxt] = current
				gscore[nxt] = tentative
				open.append(nxt)
	return {"path": [] as Array[Vector2i]}

func _path_to_building(start: Vector2i) -> Dictionary:
	var empty: Array[Vector2i] = []
	if not in_bounds(start):
		return {"path": empty, "attack": Vector2i(-1, -1), "core": false}
	var queue: Array[Vector2i] = [start]
	var came := {}
	var seen := {start: true}
	var best_cell := Vector2i(-1, -1)
	var best_from := start
	var best_steps := 999999
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		var steps := _chain_length(came, current)
		for dir in DIRS:
			var nxt: Vector2i = current + dir
			if not in_bounds(nxt) or seen.has(nxt):
				continue
			if buildings.has(nxt):
				if steps + 1 < best_steps:
					best_steps = steps + 1
					best_cell = nxt
					best_from = current
				continue
			if scenery.has(nxt):
				continue
			seen[nxt] = true
			came[nxt] = current
			queue.append(nxt)
	if best_cell.x < 0:
		return {"path": empty, "attack": Vector2i(-1, -1), "core": false}
	return {"path": _rebuild(came, best_from), "attack": best_cell, "core": false}

func _chain_length(came: Dictionary, cell: Vector2i) -> int:
	var n := 0
	var cursor := cell
	while came.has(cursor):
		cursor = came[cursor]
		n += 1
		if n > 400:
			break
	return n

func _rebuild(came: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var guard := 0
	while came.has(current) and guard < 400:
		current = came[current]
		path.push_front(current)
		guard += 1
	return path

func _scripted_defense() -> void:
	wood = 999
	gold = 999
	var plan := [
		[Building.Kind.WALL, Vector2i(1, 2)],
		[Building.Kind.WALL, Vector2i(2, 2)],
		[Building.Kind.WALL, Vector2i(3, 2)],
		[Building.Kind.SPEAR, Vector2i(4, 2)],
		[Building.Kind.WALL, Vector2i(5, 2)],
		[Building.Kind.SPEAR, Vector2i(6, 2)],
		[Building.Kind.SPEAR, Vector2i(3, 4)],
		[Building.Kind.WALL, Vector2i(4, 4)],
		[Building.Kind.FIRE, Vector2i(5, 4)],
		[Building.Kind.WALL, Vector2i(6, 4)],
		[Building.Kind.WALL, Vector2i(7, 4)],
		[Building.Kind.WALL, Vector2i(8, 4)],
		[Building.Kind.WALL, Vector2i(1, 6)],
		[Building.Kind.FIRE, Vector2i(2, 6)],
		[Building.Kind.WALL, Vector2i(3, 6)],
		[Building.Kind.SPEAR, Vector2i(4, 6)],
		[Building.Kind.WALL, Vector2i(5, 6)],
		[Building.Kind.WALL, Vector2i(6, 6)],
		[Building.Kind.SPEAR, Vector2i(3, 7)],
	]
	if OS.get_environment("TD_MODEST") == "1":
		plan = [
			[Building.Kind.WALL, Vector2i(2, 3)],
			[Building.Kind.WALL, Vector2i(7, 3)],
			[Building.Kind.SPEAR, Vector2i(3, 2)],
			[Building.Kind.SPEAR, Vector2i(6, 5)],
			[Building.Kind.FIRE, Vector2i(4, 6)],
		]
	for item in plan:
		_try_place(int(item[0]), item[1])
	var route: Dictionary = route_from(SPAWNS[1])
	print("SCRIPTED buildings=", buildings.size(), " path=", route.path.size(), " core=", route.core)

func _opening_shot() -> void:
	await get_tree().create_timer(0.4).timeout
	await _capture(OS.get_environment("TD_SHOT_PATH") if OS.get_environment("TD_SHOT_PATH") != "" else "/tmp/shots/start.png")
	get_tree().quit(0)

func _demo_shot() -> void:
	await get_tree().create_timer(3.2).timeout
	await _capture(OS.get_environment("TD_SHOT_PATH") if OS.get_environment("TD_SHOT_PATH") != "" else "/tmp/shots/combat.png")
	get_tree().quit(0)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err := image.save_png(path)
	print("SHOT", path, " err=", err, " ", image.get_width(), "x", image.get_height())


class RangeRing:
	extends Node2D

	var radius := 100.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if radius <= 1.0:
			return
		draw_arc(Vector2.ZERO, radius, 0, TAU, 56, Color(1, 0.86, 0.35, 0.7), 2.0)
		draw_circle(Vector2.ZERO, radius, Color(1, 0.86, 0.35, 0.08))
