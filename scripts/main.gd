extends Node2D

const COLS := 20
const ROWS := 20
const TILE := Vector2i(128, 128)
const HEART := Vector2i(10, 14)
const DEFAULT_SPAWNS: Array[Vector2i] = [
	Vector2i(9, 0), Vector2i(10, 0), Vector2i(11, 0)
]
var spawns: Array[Vector2i] = []
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const START_WOOD := 100
const START_GOLD := 70
const CLAIM_TIME := 6.5
const REFUGEES_PER_WAVE := 2
const INFECT_RADIUS := 38.0 * IsoVolume.WORLD_SCALE
const WAVE_CLEAR_WOOD := 8
const WAVE_CLEAR_GOLD := 14

var wood := START_WOOD
var gold := START_GOLD
var core_pos := Vector2.ZERO
var phase := "prep"
var wave_number := 0
var inspected: Building = null
var selected_villager: Villager = null

var ground: TileMapLayer
var actors: Node2D
var decals: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Hud
var font: Font

var buildings := {}
var scenery := {}
var road_lookup := {}
var _prop_cache: Array = []
var _prop_ready := false
var _center_block := {}
var spawn_queue: Array[String] = []
var spawn_cd := 0.0
var spawn_gap := 0.8
var spawn_cursor := 0
var _selftest := false
var _selftest_t0 := 0
var _skin_i := 0
var _map_min := Vector2.ZERO
var _map_max := Vector2.ZERO
var _cam_min_zoom := 0.12
var _cam_max_zoom := 1.8
var _mouse_down := false
var _mouse_moved := false
var _mouse_press := Vector2.ZERO
var _mouse_cam := Vector2.ZERO
var _touches := {}
var _pinch_dist := 0.0
var _single_origin := Vector2.ZERO
var _single_cam := Vector2.ZERO
var _single_moved := false
var _cam_user := false
var _syncing := false

func _ready() -> void:
	if _open_stress_now():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/depth_stress.tscn")
		return
	if _open_lab_now():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/depth_lab.tscn")
		return
	process_priority = 50
	Engine.max_fps = 60
	add_to_group("game")
	_touch_unit_catalog()
	if OS.get_environment("TD_SELFTEST") == "1":
		seed(1)
	_load_setup_layout()
	wood = Balance.economy_i("start_wood", START_WOOD)
	gold = Balance.economy_i("start_gold", START_GOLD)
	font = CatalogPaths.load_font()
	_selftest = OS.get_environment("TD_SELFTEST") == "1"
	if OS.get_environment("TD_UI") == "1":
		get_window().size = Vector2i(390, 844)
	_sync_pixels()
	_build_world()
	_paint_map()
	_place_starter()
	_spawn_starter_people()
	core_pos = cell_center(HEART)
	_build_camera()
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_try_start_wave)
	hud.restart_pressed.connect(_restart)
	hud.zoom_in_pressed.connect(_on_zoom_in)
	hud.zoom_out_pressed.connect(_on_zoom_out)
	hud.place_requested.connect(_on_place_requested)
	hud.sell_pressed.connect(_on_sell_requested)
	hud.staff_selected.connect(_on_staff_selected)
	hud.staff_dismissed.connect(_on_staff_dismissed)
	hud.unit_closed.connect(_on_unit_panel_closed)
	hud.codex_pressed.connect(_open_codex)
	hud.bench_pressed.connect(_open_workbench)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_sync_pixels()
	_apply_fit_zoom(true)
	if hud:
		hud._layout()
	_refresh_beds()
	_refresh_hud()
	if OS.get_environment("TD_BALANCE") == "1":
		var code := _balance_probe()
		get_tree().quit(code)
		return
	if (_selftest or OS.get_environment("TD_DEMO") == "1") and OS.get_environment("TD_NONE") != "1":
		_scripted_defense()
	if _selftest:
		Engine.time_scale = 8.0
		_selftest_t0 = Time.get_ticks_msec()
		_try_start_wave()
	elif OS.get_environment("TD_DEMO") == "1":
		_try_start_wave()
		_demo_shot()
	elif OS.get_environment("TD_FLOW") == "1":
		if FileAccess.file_exists("/tmp/td_flow_restarted"):
			print("FLOW_RESTARTED")
			get_tree().quit(0)
		else:
			_flow_shot()
	elif OS.get_environment("TD_UI") == "1":
		_ui_shot()
	elif OS.get_environment("TD_FACE") == "1":
		_face_check()
	elif OS.get_environment("TD_CHAR") == "1":
		_char_shot()
	elif OS.get_environment("TD_LANG") == "1":
		_lang_shot()
	elif OS.get_environment("TD_HUD") == "1":
		_hud_shot()
	elif OS.get_environment("TD_BENCH") == "1":
		call_deferred("_open_workbench")
	elif OS.get_environment("TD_MOVE") == "1":
		_move_shot()
	elif OS.get_environment("TD_ORDER") == "1":
		_order_probe()
	elif OS.get_environment("TD_PASS") == "1":
		_pass_probe()
	elif OS.get_environment("TD_STACK") == "1":
		_stack_probe()
	elif OS.get_environment("TD_UNIT") == "1":
		_unit_probe()
	elif OS.get_environment("TD_SHOT") == "1":
		_opening_shot()

func _process(delta: float) -> void:
	_refresh_beds()
	_infect_contacts()
	_tick_mills(delta)
	_update_ghost()
	if phase == "combat":
		_tick_spawns(delta)
	if _selftest and Time.get_ticks_msec() - _selftest_t0 > 180000:
		print("SELFTEST_TIMEOUT people=", _alive_villagers().size(), " wave=", wave_number)
		get_tree().quit(1)
	_separate_walkers()
	_apply_iso_sort()

func _unhandled_input(event: InputEvent) -> void:
	if hud != null and hud.is_blocking():
		return
	if event is InputEventScreenTouch:
		_screen_touch(event as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		_screen_drag(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_zoom_at(magnify.position, camera.zoom.x * magnify.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		camera.position -= pan.delta / camera.zoom
		_clamp_camera()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not mb.pressed:
				return
			var step := 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			_zoom_at(mb.position, camera.zoom.x * step)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_click(get_canvas_transform().affine_inverse() * mb.position)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				_mouse_moved = false
				_mouse_press = mb.position
				_mouse_cam = camera.position
			else:
				_mouse_down = false
				if not _mouse_moved:
					_left_click(get_canvas_transform().affine_inverse() * mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _mouse_down:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _mouse_press
		if delta.length() > 14.0:
			_mouse_moved = true
			_cam_user = true
		if _mouse_moved:
			camera.position = _mouse_cam - delta / camera.zoom
			_clamp_camera()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				_place_from_shortcut(Building.Kind.WALL)
			KEY_2:
				_place_from_shortcut(Building.Kind.SPEAR)
			KEY_3:
				_place_from_shortcut(Building.Kind.FIRE)
			KEY_4:
				_place_from_shortcut(Building.Kind.HOUSE)
			KEY_5:
				_place_from_shortcut(Building.Kind.FARM)
			KEY_6:
				_place_from_shortcut(Building.Kind.WORKSHOP)
			KEY_7:
				_place_from_shortcut(Building.Kind.LUMBER)
			KEY_8:
				_place_from_shortcut(Building.Kind.SPEAR_BARRACKS)
			KEY_9:
				_place_from_shortcut(Building.Kind.GUN_BARRACKS)
			KEY_ESCAPE:
				hud.close_panel()
				_clear_villager_selection()
				inspected = null
			KEY_SPACE, KEY_ENTER:
				_try_start_wave()
			KEY_R:
				_restart()

func _build_world() -> void:
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -4096
	ground.y_sort_enabled = true
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_size = TILE
	var files := [
		"res://art/village/grass_a.png",
		"res://art/village/grass_b.png",
		"res://art/village/road.png",
	]
	for i in files.size():
		var atlas := TileSetAtlasSource.new()
		var tex: Texture2D = CatalogPaths.load_tex(files[i])
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		atlas.create_tile(Vector2i.ZERO)
		var data := atlas.get_tile_data(Vector2i.ZERO, 0)
		data.texture_origin = Vector2i.ZERO
		tileset.add_source(atlas, i)
	ground.tile_set = tileset
	add_child(ground)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	# Ground highlights sit above the grass and under every standing rank.
	decals = Node2D.new()
	decals.name = "Decals"
	decals.z_as_relative = false
	decals.z_index = -4000
	add_child(decals)
	var order_guide := Node2D.new()
	order_guide.name = "OrderGuide"
	order_guide.set_script(load("res://scripts/order_guide.gd"))
	decals.add_child(order_guide)
	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_as_relative = false
	fx.z_index = 4096
	add_child(fx)

func _paint_map() -> void:
	var spawn_lookup := {}
	for cell in spawns:
		spawn_lookup[cell] = true
	scenery = MapPlan.scenery_cells(spawn_lookup, Balance.starter_props())
	road_lookup = MapPlan.road_lookup(Balance.roads())
	var trail := road_lookup
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var source := (x + y) % 2
			if trail.has(cell) and not scenery.has(cell):
				source = 2
			ground.set_cell(cell, source, Vector2i.ZERO)
	for rock_cell in MapPlan.ROCKS:
		_place_prop(rock_cell, CatalogPaths.load_tex("village/rock.png"), "rock")
	var trees := [
		"res://art/village/tree.png",
		"res://art/village/tree_b.png",
		"res://art/village/tree_c.png",
	]
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if not scenery.has(cell) or _is_spawn(cell) or MapPlan.is_fixed_rock(cell):
				continue
			if not _is_border(cell):
				continue
			_place_prop(cell, CatalogPaths.load_tex(trees[(x + y) % trees.size()]), "tree")
	for item in Balance.starter_props():
		if not (item is Dictionary):
			continue
		var raw = item.get("cell", [])
		if not (raw is Array) or raw.size() < 2:
			continue
		var cell := Vector2i(int(raw[0]), int(raw[1]))
		if not scenery.has(cell) or _is_spawn(cell) or _is_border(cell) or MapPlan.is_fixed_rock(cell):
			continue
		var kind := str(item.get("kind", "tree"))
		if kind == "rock":
			_place_prop(cell, CatalogPaths.load_tex("village/rock.png"), "rock")
		else:
			_place_prop(cell, CatalogPaths.load_tex(trees[(cell.x + cell.y) % trees.size()]), "tree")
	_invalidate_props()

func _place_starter() -> void:
	var plan := Balance.starter_buildings()
	if plan.is_empty():
		plan = [
			{"kind": "HOUSE", "cell": [8, 14]},
			{"kind": "HOUSE", "cell": [12, 14]},
			{"kind": "FARM", "cell": [9, 16]},
			{"kind": "WORKSHOP", "cell": [11, 16]},
			{"kind": "SPEAR", "cell": [7, 12]},
			{"kind": "SPEAR", "cell": [13, 12]},
			{"kind": "FIRE", "cell": [10, 12]},
			{"kind": "WALL", "cell": [6, 11]},
			{"kind": "WALL", "cell": [8, 11]},
			{"kind": "WALL", "cell": [12, 11]},
			{"kind": "WALL", "cell": [14, 11]},
			{"kind": "WALL", "cell": [9, 10]},
			{"kind": "WALL", "cell": [11, 10]},
		]
	for item in plan:
		if not (item is Dictionary):
			continue
		var cell_raw = item.get("cell", [])
		if not (cell_raw is Array) or cell_raw.size() < 2:
			continue
		_place_free(_kind_from_name(str(item.get("kind", "WALL"))), Vector2i(int(cell_raw[0]), int(cell_raw[1])))

func _spawn_starter_people() -> void:
	var roster := Balance.starter_units()
	if roster.is_empty():
		roster = [
			{"unit": "villager", "cell": [9, 15], "sex": "m"},
			{"unit": "villager", "cell": [10, 15], "sex": "f"},
			{"unit": "villager", "cell": [11, 15], "sex": "m"},
			{"unit": "villager", "cell": [8, 15], "sex": "f"},
			{"unit": "villager", "cell": [12, 15], "sex": "m"},
		]
	for item in roster:
		if not (item is Dictionary):
			continue
		var cell_raw = item.get("cell", [])
		if not (cell_raw is Array) or cell_raw.size() < 2:
			continue
		_spawn_unit(str(item.get("unit", "villager")), Vector2i(int(cell_raw[0]), int(cell_raw[1])), str(item.get("sex", "")))


func _place_prop(cell: Vector2i, tex: Texture2D, key: String) -> void:
	var node := Node2D.new()
	node.position = cell_center(cell)
	node.set_script(load("res://scripts/iso_prop.gd"))
	node.cell = cell
	node.volume_key = key
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = IsoVolume.ROCK_ANCHOR if key == "rock" else IsoVolume.TREE_ANCHOR
	sprite.z_as_relative = true
	sprite.z_index = 0
	node.add_child(sprite)
	actors.add_child(node)

func _build_camera() -> void:
	camera = Camera2D.new()
	var corners: Array[Vector2] = [
		cell_center(Vector2i(0, 0)),
		cell_center(Vector2i(COLS - 1, 0)),
		cell_center(Vector2i(0, ROWS - 1)),
		cell_center(Vector2i(COLS - 1, ROWS - 1)),
	]
	_map_min = corners[0]
	_map_max = corners[0]
	for p in corners:
		_map_min.x = minf(_map_min.x, p.x)
		_map_min.y = minf(_map_min.y, p.y)
		_map_max.x = maxf(_map_max.x, p.x)
		_map_max.y = maxf(_map_max.y, p.y)
	_map_min -= Vector2(TILE.x, TILE.y) * 0.5
	_map_max += Vector2(TILE.x, TILE.y) * 0.5
	add_child(camera)
	camera.make_current()
	_apply_fit_zoom(true)

func _sync_pixels() -> void:
	if _syncing:
		return
	var win_size := DisplayServer.window_get_size()
	if win_size.x < 8 or win_size.y < 8:
		return
	_syncing = true
	var window := get_window()
	window.content_scale_size = win_size
	window.content_scale_factor = 1.0
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_syncing = false

func _on_viewport_resized() -> void:
	_sync_pixels()
	if _cam_user:
		_clamp_camera()
		if hud:
			hud.set_phone(_is_phone())
	else:
		_apply_fit_zoom(true)
	if hud:
		hud._layout()

func _is_phone() -> bool:
	var view := get_viewport_rect().size
	var short_side := minf(view.x, view.y)
	var long_side := maxf(view.x, view.y)
	if short_side <= 520.0:
		return true
	if DisplayServer.is_touchscreen_available() and short_side < 700.0 and long_side < 1100.0:
		return true
	return false

func _center_half_focus() -> Vector2:
	return (
		cell_center(Vector2i(5, 5))
		+ cell_center(Vector2i(14, 5))
		+ cell_center(Vector2i(5, 14))
		+ cell_center(Vector2i(14, 14))
	) * 0.25

func _center_half_span() -> Vector2:
	var corners: Array[Vector2] = [
		cell_center(Vector2i(5, 5)),
		cell_center(Vector2i(14, 5)),
		cell_center(Vector2i(5, 14)),
		cell_center(Vector2i(14, 14)),
	]
	var mn := corners[0]
	var mx := corners[0]
	for p in corners:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	var pad := Vector2(float(TILE.x) * 0.5, float(TILE.y) * 0.5)
	return (mx + pad) - (mn - pad)

func _apply_fit_zoom(force: bool) -> void:
	var view := get_viewport_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return
	var span := _map_max - _map_min
	var usable := Vector2(maxf(view.x - 8.0, 64.0), maxf(view.y - 160.0, 64.0))
	var fit := minf(usable.x / span.x, usable.y / span.y)
	_cam_min_zoom = maxf(fit * 0.92, 0.08)
	_cam_max_zoom = maxf(fit * 6.0, 1.45)
	var phone := _is_phone()
	if hud:
		hud.set_phone(phone)
	if not force:
		camera.zoom.x = clampf(camera.zoom.x, _cam_min_zoom, _cam_max_zoom)
		camera.zoom.y = camera.zoom.x
		_clamp_camera()
		return
	var half := _center_half_span()
	var fit_half := minf(usable.x / half.x, usable.y / half.y)
	var zoom_v := fit_half
	if phone:
		zoom_v = maxf(fit_half * 1.85, 0.48)
	zoom_v = clampf(zoom_v, _cam_min_zoom, _cam_max_zoom)
	camera.zoom = Vector2(zoom_v, zoom_v)
	camera.position = _center_half_focus()
	_clamp_camera()

func _on_zoom_in() -> void:
	_zoom_at(get_viewport_rect().size * 0.5, camera.zoom.x * 1.18)

func _on_zoom_out() -> void:
	_zoom_at(get_viewport_rect().size * 0.5, camera.zoom.x / 1.18)

func _zoom_at(screen_point: Vector2, new_zoom: float) -> void:
	var old := camera.zoom.x
	var zoom_v := clampf(new_zoom, _cam_min_zoom, _cam_max_zoom)
	if is_equal_approx(old, zoom_v) or old <= 0.001:
		return
	_cam_user = true
	var view := get_viewport_rect().size
	var before := camera.position + (screen_point - view * 0.5) / old
	camera.zoom = Vector2(zoom_v, zoom_v)
	var after := camera.position + (screen_point - view * 0.5) / zoom_v
	camera.position += before - after
	_clamp_camera()

func _clamp_camera() -> void:
	var view := get_viewport_rect().size
	var half := view * 0.5 / camera.zoom
	var span := _map_max - _map_min
	if half.x * 2.0 >= span.x:
		camera.position.x = (_map_min.x + _map_max.x) * 0.5
	else:
		camera.position.x = clampf(camera.position.x, _map_min.x + half.x * 0.25, _map_max.x - half.x * 0.25)
	if half.y * 2.0 >= span.y:
		camera.position.y = (_map_min.y + _map_max.y) * 0.5
	else:
		camera.position.y = clampf(camera.position.y, _map_min.y + half.y * 0.25, _map_max.y - half.y * 0.25)

func _screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_single_origin = event.position
			_single_cam = camera.position
			_single_moved = false
		else:
			_single_moved = true
			_pinch_dist = _finger_span()
	else:
		var pos: Vector2 = _touches.get(event.index, event.position)
		var was_tap := _touches.size() == 1 and not _single_moved
		_touches.erase(event.index)
		if _touches.size() == 1:
			for key in _touches:
				_single_origin = _touches[key]
			_single_cam = camera.position
			_single_moved = true
		elif _touches.size() >= 2:
			_pinch_dist = _finger_span()
		elif was_tap:
			_left_click(get_canvas_transform().affine_inverse() * pos)

func _screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var span := _finger_span()
		if _pinch_dist > 12.0 and span > 12.0:
			_zoom_at(_finger_center(), camera.zoom.x * (span / _pinch_dist))
		_pinch_dist = _finger_span()
		_single_moved = true
		return
	var delta := event.position - _single_origin
	if delta.length() > 16.0:
		_single_moved = true
		_cam_user = true
	if _single_moved:
		camera.position = _single_cam - delta / camera.zoom
		_clamp_camera()

func _finger_span() -> float:
	var pts: Array[Vector2] = []
	for key in _touches:
		pts.append(_touches[key])
	if pts.size() < 2:
		return 0.0
	return pts[0].distance_to(pts[1])

func _finger_center() -> Vector2:
	var acc := Vector2.ZERO
	var n := 0
	for key in _touches:
		acc += _touches[key]
		n += 1
	if n == 0:
		return get_viewport_rect().size * 0.5
	return acc / float(n)

func cell_center(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)

func world_to_cell(world: Vector2) -> Vector2i:
	return ground.local_to_map(world)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS

func nearest_spawn(world: Vector2) -> Vector2i:
	var best: Vector2i = spawns[0] if not spawns.is_empty() else DEFAULT_SPAWNS[0]
	var best_d := INF
	for cell in spawns:
		var d := world.distance_squared_to(cell_center(cell))
		if d < best_d:
			best_d = d
			best = cell
	return best

func walkable(world: Vector2) -> bool:
	var cell := world_to_cell(world)
	return in_bounds(cell) and not _blocked(cell)

func on_road(world: Vector2) -> bool:
	return road_lookup.has(world_to_cell(world))

func _stand_ok(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	if scenery.has(cell) or buildings.has(cell) or _is_spawn(cell) or _blocked(cell):
		return false
	return _oval_clear(cell_center(cell), null, null)

func _point_standable(world: Vector2) -> bool:
	if not _stand_ok(world_to_cell(world)):
		return false
	return _oval_clear(world, null, null)

func front_of(building: Building) -> Vector2:
	if building == null or not is_instance_valid(building):
		return Vector2.ZERO
	var ideal := building.global_position + Vector2(0, 96)
	if building.has_method("get_iso_volume"):
		ideal = IsoVolume.iso_to_world(_feet_iso(building.get_iso_volume(), Vector2(0, 1)))
	if _point_standable(ideal):
		return ideal
	var origin := world_to_cell(ideal)
	var best := ideal
	var found := false
	var best_score := 999999
	for radius in range(1, 5):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := origin + Vector2i(dx, dy)
				if not _stand_ok(cell):
					continue
				var score := (origin.y - cell.y) * 100 + absi(dx) * 8 + absi(dy)
				if not found or score < best_score:
					found = true
					best_score = score
					best = cell_center(cell)
		if found:
			return best
	return ideal

func should_panic(v: Villager) -> bool:
	if wave_number <= 0 or phase == "win" or phase == "lose":
		return false
	if v.job != null and is_instance_valid(v.job):
		return false
	return not v.housed

func safe_point() -> Vector2:
	var heart := cell_center(HEART)
	var best := heart
	var best_d := INF
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.HOUSE:
			var d := heart.distance_squared_to(building.global_position)
			if d < best_d:
				best_d = d
				best = building.global_position
	return best

func wander_cell(v: Villager, panic: bool) -> Vector2i:
	var cell := HEART
	for _try in 8:
		var x := randi_range(6, 14)
		var y := randi_range(12, 17)
		if panic:
			var pull := world_to_cell(safe_point())
			x = clampi(pull.x + randi_range(-2, 2), 5, 15)
			y = clampi(pull.y + randi_range(0, 2), 11, 17)
		cell = Vector2i(x, y)
		if not _blocked(cell):
			return cell
	if not _blocked(Vector2i(10, 15)):
		return Vector2i(10, 15)
	return v_cell_or_heart(v)

func v_cell_or_heart(v: Villager) -> Vector2i:
	var cell := world_to_cell(v.global_position)
	if in_bounds(cell) and not _blocked(cell):
		return cell
	return HEART

func _load_setup_layout() -> void:
	spawns.clear()
	for item in Balance.spawns():
		if item is Array and item.size() >= 2:
			var cell := Vector2i(int(item[0]), int(item[1]))
			if in_bounds(cell):
				spawns.append(cell)
	if spawns.is_empty():
		spawns = DEFAULT_SPAWNS.duplicate()

func _touch_unit_catalog() -> void:
	Balance.unit("villager")
	Balance.unit("spearman")
	Balance.unit("gunner")
	Balance.unit("engineer")

func _kind_from_name(kind_name: String) -> int:
	match kind_name:
		"WALL":
			return Building.Kind.WALL
		"SPEAR":
			return Building.Kind.SPEAR
		"FIRE":
			return Building.Kind.FIRE
		"HOUSE":
			return Building.Kind.HOUSE
		"FARM":
			return Building.Kind.FARM
		"WORKSHOP":
			return Building.Kind.WORKSHOP
		"LUMBER":
			return Building.Kind.LUMBER
		"SPEAR_BARRACKS":
			return Building.Kind.SPEAR_BARRACKS
		"GUN_BARRACKS":
			return Building.Kind.GUN_BARRACKS
	return Building.Kind.WALL

func _count_unit(unit_id: String) -> int:
	var n := 0
	for v in _alive_villagers():
		if v.unit_id == unit_id:
			n += 1
	return n

func _unit_cap(unit_id: String) -> int:
	if unit_id == "villager":
		return _bed_cap()
	var n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		var provides := building.provides()
		if str(provides.get("unit", "")) == unit_id:
			n += int(provides.get("slots", 0))
	return n

func _settle_cell() -> Vector2i:
	var origin := Vector2i(10, 16)
	for radius in 8:
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if not in_bounds(cell) or _blocked(cell) or _is_spawn(cell):
					continue
				var taken := false
				for v in _alive_villagers():
					if world_to_cell(v.global_position) == cell:
						taken = true
						break
				if not taken:
					return cell
	return Vector2i(-1, -1)

func _tick_mills(delta: float) -> void:
	if phase == "win" or phase == "lose":
		return
	var gained := 0
	var popup_at := Vector2.ZERO
	var popup_n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if not building.staff_produces():
			continue
		var spec := building.produce_spec()
		var interval := float(spec.get("interval", 5.0))
		var rate := int(spec.get("rate_per_villager", 0))
		var crew_n := building.villager_crew()
		if crew_n <= 0 or rate <= 0 or interval <= 0.0:
			building.produce_cd = 0.0
			continue
		building.produce_cd += delta
		var batch := 0
		while building.produce_cd >= interval:
			building.produce_cd -= interval
			batch += rate * crew_n
		if batch > 0:
			gained += batch
			popup_n = batch
			popup_at = building.global_position
	if gained <= 0:
		return
	wood += gained
	_popup(popup_at + Vector2(0, -80), Locale.format("popup.wood", [popup_n]), Color(0.86, 0.62, 0.32))
	_refresh_hud()

func damage_fighter(person: Villager, attack: float) -> void:
	if person == null or not is_instance_valid(person) or person.fallen:
		return
	var dealt := Balance.damage(attack, person.defense)
	person.hurt(dealt)
	if is_instance_valid(person):
		_popup(person.global_position + Vector2(0, -30), "-%d" % dealt, Color(1, 0.7, 0.45))

func approach_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	if not _blocked(goal) and in_bounds(goal):
		return goal
	var best := start
	var best_d := 999999
	for dir in DIRS:
		var nxt: Vector2i = goal + dir
		if not in_bounds(nxt) or _blocked(nxt):
			continue
		var d := absi(nxt.x - start.x) + absi(nxt.y - start.y)
		if d < best_d:
			best_d = d
			best = nxt
	return best

func route_for(z: Zombie, start: Vector2i) -> Dictionary:
	var hold := Balance.combat_f("target_hold", 1.2)
	var margin := Balance.combat_f("switch_margin", 0.72)
	var current_ok := _focus_ok(z)
	var best := _best_focus(start)
	var keep := false
	if current_ok and z.focus_hold > 0.0:
		keep = true
	elif current_ok:
		var old_d := _focus_dist(z, start)
		var new_d := int(best.get("dist", 999999))
		var same := false
		if z.focus_unit != null:
			same = best.get("unit") == z.focus_unit
		else:
			same = best.get("unit") == null and best.get("cell") == z.focus_cell
		if same or new_d > int(round(float(old_d) * margin)):
			keep = true
			z.focus_hold = hold
	if not keep:
		z.focus_unit = best.get("unit") as Node2D
		var cell_raw = best.get("cell", Vector2i(-1, -1))
		z.focus_cell = cell_raw if cell_raw is Vector2i else Vector2i(-1, -1)
		z.focus_hold = hold
	return _route_kept(z, start)

func _focus_ok(z: Zombie) -> bool:
	if z.focus_unit != null and is_instance_valid(z.focus_unit):
		var person := z.focus_unit as Villager
		if person != null and not person.infected and not person.fallen and not person.leaving and person.job == null:
			return true
	if z.focus_cell.x >= 0 and buildings.has(z.focus_cell):
		return z.focus_unit == null
	return false

func _focus_dist(z: Zombie, start: Vector2i) -> int:
	if z.focus_unit != null and is_instance_valid(z.focus_unit):
		var cell := world_to_cell(z.focus_unit.global_position)
		return absi(cell.x - start.x) + absi(cell.y - start.y)
	if z.focus_cell.x >= 0:
		return absi(z.focus_cell.x - start.x) + absi(z.focus_cell.y - start.y)
	return 999999

func _best_focus(start: Vector2i) -> Dictionary:
	var best_unit: Node2D = null
	var best_d := 999999
	for v in _alive_villagers():
		if v.job != null and is_instance_valid(v.job):
			continue
		var cell := world_to_cell(v.global_position)
		if not in_bounds(cell) or _blocked(cell):
			continue
		var d := absi(cell.x - start.x) + absi(cell.y - start.y)
		if d < best_d:
			best_d = d
			best_unit = v
	if best_unit != null:
		return {"unit": best_unit, "cell": Vector2i(-1, -1), "dist": best_d}
	var shelter := _nearest_staffed_cell(start)
	if shelter.x >= 0:
		return {"unit": null, "cell": shelter, "dist": absi(shelter.x - start.x) + absi(shelter.y - start.y)}
	var any := _nearest_building(start)
	return {"unit": null, "cell": any, "dist": absi(any.x - start.x) + absi(any.y - start.y) if any.x >= 0 else 999999}

func _nearest_building(start: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 999999
	for cell in buildings:
		var d := absi(cell.x - start.x) + absi(cell.y - start.y)
		if d < best_d:
			best_d = d
			best = cell
	return best

func _route_kept(z: Zombie, start: Vector2i) -> Dictionary:
	if z.focus_unit != null and is_instance_valid(z.focus_unit):
		var goal := world_to_cell(z.focus_unit.global_position)
		var chased: Dictionary = _astar(start, goal)
		return {"path": chased.path, "attack": Vector2i(-1, -1)}
	if z.focus_cell.x >= 0 and buildings.has(z.focus_cell):
		return _path_to_attack(start, z.focus_cell)
	return _path_to_building(start)

func route_from(start: Vector2i) -> Dictionary:
	var open_goal := _nearest_open_villager_cell(start)
	if open_goal.x >= 0:
		var chased := _astar(start, open_goal)
		if not chased.path.is_empty():
			return {"path": chased.path, "attack": Vector2i(-1, -1)}
	var shelter := _nearest_staffed_cell(start)
	if shelter.x >= 0:
		var hit := _path_to_attack(start, shelter)
		if int(hit.attack.x) >= 0:
			return hit
	return _path_to_building(start)

func can_attack_cell(cell: Vector2i) -> bool:
	return buildings.has(cell)

func damage_cell(cell: Vector2i, attack: float) -> void:
	if phase == "win" or phase == "lose":
		return
	if not buildings.has(cell):
		return
	var building: Building = buildings[cell]
	var dealt := Balance.damage(attack, building.defense)
	_popup(building.global_position + Vector2(0, -40), "-%d" % dealt, Color(1, 0.8, 0.45))
	if building.hurt(dealt):
		_remove_building(cell, false)

func apply_hit(at: Vector2, attack: float, splash: float, is_fire: bool, target: Node2D) -> void:
	if is_fire or splash > 0.0:
		fx.add_child(_burst(at, splash if splash > 0.0 else 28.0, Color(1, 0.45, 0.1)))
		for z in _living_zombies():
			if z.global_position.distance_to(at) <= splash:
				z.hurt(Balance.damage(attack, z.defense))
	else:
		fx.add_child(_burst(at, 14.0, Color(0.95, 0.9, 0.7)))
		if is_instance_valid(target) and target is Zombie and not (target as Zombie).dying:
			var zombie := target as Zombie
			zombie.hurt(Balance.damage(attack, zombie.defense))
		else:
			var nearest: Zombie = null
			var best := 26.0
			for z in _living_zombies():
				var d := z.global_position.distance_to(at)
				if d < best:
					best = d
					nearest = z
			if nearest:
				nearest.hurt(Balance.damage(attack, nearest.defense))

func on_zombie_killed(z: Zombie) -> void:
	if phase == "lose":
		return
	gold += z.reward_gold
	_popup(z.global_position, Locale.format("popup.gold", [z.reward_gold]), Color(1, 0.86, 0.3))
	_refresh_hud()

func tower_bonus() -> float:
	var best := 1.0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind != Building.Kind.WORKSHOP:
			continue
		var bonus: Dictionary = Balance.building_by_kind("WORKSHOP").get("bonus", {})
		best = maxf(best, float(bonus.get("tower_damage", 1.0)))
	return best

func _try_start_wave() -> void:
	if phase != "prep":
		return
	if wave_number >= _wave_count():
		return
	var spec: Dictionary = Balance.waves()[wave_number]
	wave_number += 1
	phase = "combat"
	spawn_gap = float(spec.gap)
	spawn_cd = 0.35
	spawn_queue = _compose_wave(spec)
	hud.flash(Locale.format("flash.wave_in", [wave_number]))
	_refresh_hud()

func _compose_wave(spec: Dictionary) -> Array[String]:
	var list: Array[String] = []
	for _i in Balance.count_scale(int(spec.get("normal", spec.get("n", 0)))):
		list.append("spear_normal")
	for _i in Balance.count_scale(int(spec.get("fast", 0))):
		list.append("spear_fast")
	for _i in Balance.count_scale(int(spec.get("elite", spec.get("brute", 0)))):
		list.append("shooter_elite")
	list.shuffle()
	for _i in Balance.count_scale(int(spec.get("boss", 0))):
		list.append("shooter_boss")
	return list

func _tick_spawns(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			_spawn_zombie(spawn_queue.pop_front(), false, Vector2.ZERO)
			spawn_cd = spawn_gap
	elif _living_zombies().is_empty():
		_on_wave_cleared()

func _spawn_zombie(kind: String, turned: bool, at: Vector2) -> void:
	var id := "spear_infected" if turned else kind
	var stat := Balance.scaled_enemy(id, maxi(wave_number, 1) - 1)
	var z := Zombie.new()
	if turned:
		z.position = at
		z.mark_fresh()
	else:
		var cell := spawns[spawn_cursor % spawns.size()]
		spawn_cursor += 1
		z.position = cell_center(cell)
	z.setup(int(stat.hp), float(stat.move_speed), float(stat.scale), int(round(float(stat.attack))), int(stat.wood_reward), int(stat.gold_reward), id, Color.WHITE, str(stat.character))
	z.defense = float(stat.defense)
	z.attack_speed = float(stat.attack_speed)
	z.attack_range = float(stat.attack_range)
	z.xp_reward = int(stat.xp_reward)
	actors.add_child(z)

func _on_wave_cleared() -> void:
	if phase != "combat":
		return
	wood += Balance.economy_i("wave_clear_wood", WAVE_CLEAR_WOOD) + _farm_wave_wood()
	gold += Balance.economy_i("wave_clear_gold", WAVE_CLEAR_GOLD)
	if wave_number >= _wave_count():
		_finish(true)
		return
	phase = "prep"
	var note := _settle_wave()
	hud.flash(Locale.format("flash.wave_settle", [wave_number, note]))
	_refresh_hud()
	if _selftest:
		_try_start_wave()

func _settle_wave() -> String:
	var rules := Balance.settlement()
	var chance := float(rules.get("chance", 0.65))
	var per_wave := int(rules.get("max_per_wave", 3))
	var order: Array[String] = ["villager", "spearman", "gunner", "engineer"]
	var any_free := false
	var parts: PackedStringArray = []
	for unit_id in order:
		var free := _unit_cap(unit_id) - _count_unit(unit_id)
		if free <= 0 or per_wave <= 0:
			continue
		any_free = true
		if randf() >= chance:
			continue
		var n := randi_range(1, mini(per_wave, free))
		for _i in n:
			var cell := _settle_cell()
			if cell.x < 0:
				break
			_spawn_unit(unit_id, cell, "")
		var label := Locale.text("unit." + unit_id)
		parts.append("%s +%d" % [label, n])
	_refresh_beds()
	if not parts.is_empty():
		return " ".join(parts)
	if any_free:
		return Locale.text("flash.settle_none")
	return Locale.text("flash.settle_full")

func _spawn_unit(unit_id: String, cell: Vector2i, sex: String) -> Villager:
	var v := Villager.new()
	v.position = cell_center(cell)
	var def := Balance.unit(unit_id)
	if def.is_empty():
		def = Balance.unit("villager")
		unit_id = "villager"
	var skin_name := str(def.get("skin", "wolf"))
	if unit_id == "villager":
		var pool: Array = Balance.villager_skin_pool()
		skin_name = str(pool[_skin_i % pool.size()])
		_skin_i += 1
		if sex != "m" and sex != "f":
			sex = "f" if _skin_i % 2 == 0 else "m"
	elif sex != "m" and sex != "f":
		sex = "m"
	v.configure(def)
	v.setup(Balance.skin_index("villager", skin_name), sex, float(def.get("move_speed", 0.0)))
	v.refugee = false
	v.claim_left = -1.0
	actors.add_child(v)
	return v

func _make_villager(cell: Vector2i, sex: String, as_refugee: bool) -> Villager:
	var v := _spawn_unit("villager", cell, sex)
	v.refugee = as_refugee
	v.claim_left = CLAIM_TIME if as_refugee else -1.0
	return v

func _finish(win: bool) -> void:
	if phase == "win" or phase == "lose":
		return
	phase = "win" if win else "lose"
	hud.show_end(win)
	_refresh_hud()
	if _selftest:
		print("SELFTEST_%s" % ("WIN" if win else "LOSE"))
		print("SELFTEST_PEOPLE ", _alive_villagers().size(), " WAVE ", wave_number)
		get_tree().quit(0 if win else 1)

func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _left_click(world: Vector2) -> void:
	var building := _building_at_world(world)
	var hits := _villagers_hit(world)
	var person := _pick_villager(hits, world)
	# The selected villager already owns clicks that land on their pile.
	# A different cell (or a building) is a command. Their own cell cycles
	# the pile so someone standing behind can still be chosen.
	if person != null and person == selected_villager:
		var own_cell := building == null and world_to_cell(world) == world_to_cell(person.global_position)
		if person.is_fighter():
			if own_cell and hits.size() > 1:
				person = _next_stacked(hits, person, world)
			else:
				hud.open_unit(person)
				return
		elif own_cell:
			if hits.size() > 1:
				person = _next_stacked(hits, person, world)
			else:
				hud.open_unit(person)
				return
		else:
			person = null
	if person != null:
		_select_villager(person)
		return
	if selected_villager != null and is_instance_valid(selected_villager):
		if building != null:
			_order_staff(selected_villager, building)
			return
		var ordered_cell := world_to_cell(world)
		if not _stand_ok(ordered_cell):
			hud.flash(Locale.text("flash.no_path"))
			return
		_order_move(selected_villager, ordered_cell)
		return
	if building != null:
		_clear_villager_selection()
		inspected = building
		hud.open_building(building)
		return
	var cell := world_to_cell(world)
	_clear_villager_selection()
	inspected = null
	if not in_bounds(cell) or scenery.has(cell) or _is_spawn(cell):
		hud.close_panel()
		hud.flash(Locale.text("flash.cant_build"))
		return
	hud.open_ground(cell)

func _right_click(world: Vector2) -> void:
	var building := _building_at_world(world)
	if building != null:
		_remove_building(building.cell, true)
		hud.close_panel()
		return
	hud.close_panel()
	_clear_villager_selection()
	inspected = null

func _place_from_shortcut(kind: int) -> void:
	if not hud.has_ground():
		hud.flash(Locale.text("flash.need_tile"))
		return
	_clear_villager_selection()
	if _try_place(kind, hud.ground_cell()):
		hud.close_panel()

func _on_place_requested(kind: int) -> void:
	_place_from_shortcut(kind)

func _select_villager(person: Villager) -> void:
	if person == null or not is_instance_valid(person) or person.infected or person.leaving or person.fallen:
		return
	_clear_villager_selection()
	selected_villager = person
	person.selected = true
	inspected = null
	hud.open_unit(person)
	hud.flash(Locale.text("flash.assign_next"))

func _on_unit_panel_closed() -> void:
	_clear_villager_selection()
	inspected = null

func _on_staff_selected(person: Villager) -> void:
	_select_villager(person)

func _on_staff_dismissed(person: Villager) -> void:
	var building := hud.inspected_building()
	if building == null or person == null or not building.holds(person):
		return
	building.dismiss(person)
	person.job = null
	_place_in_front(person, building, 0)
	_popup(building.global_position + Vector2(0, -80), Locale.text("popup.dismissed"), Color(0.85, 0.95, 0.75))
	_refresh_beds()
	_refresh_hud()
	hud.open_building(building)

func _on_sell_requested() -> void:
	var building := hud.inspected_building()
	if building == null or not is_instance_valid(building):
		hud.close_panel()
		return
	_remove_building(building.cell, true)
	hud.close_panel()

func _assign(v: Villager, building: Building) -> void:
	_commit_staff(v, building)

func _order_move(v: Villager, cell: Vector2i) -> void:
	if v == null or not is_instance_valid(v) or v.infected or v.leaving or v.fallen:
		return
	if v.is_fighter():
		hud.flash(Locale.text("flash.fighter_stay"))
		return
	if v.job != null and is_instance_valid(v.job):
		_step_outside(v, v.job)
	if not v.command_move(cell):
		hud.flash(Locale.text("flash.no_path"))
		return
	hud.flash(Locale.text("flash.walking"))

func _order_staff(v: Villager, building: Building) -> void:
	if not _can_staff(v, building):
		return
	if v.job != null and is_instance_valid(v.job) and v.job != building:
		_step_outside(v, v.job)
	if not v.command_enter(building):
		hud.flash(Locale.text("flash.no_path"))
		return
	hud.flash(Locale.text("flash.walking"))

func _can_staff(v: Villager, building: Building) -> bool:
	if v == null or building == null or not is_instance_valid(v) or not is_instance_valid(building):
		return false
	if v.infected or v.leaving or v.fallen:
		return false
	if not building.is_functional():
		hud.flash(Locale.text("flash.wall_no_staff"))
		return false
	if v.is_fighter():
		hud.flash(Locale.text("flash.fighter_stay"))
		return false
	if building.kind == Building.Kind.LUMBER and v.unit_id != "villager":
		hud.flash(Locale.text("flash.mill_villager"))
		return false
	if building.holds(v):
		_clear_villager_selection()
		if hud.inspected_unit() == v:
			hud.close_panel()
		return false
	if building.staff_count() >= building.staff_cap() and building.staff_cap() > 1:
		hud.flash(Locale.format("flash.mill_full", [building.staff_cap()]))
		return false
	return true

func _step_outside(v: Villager, building: Building) -> void:
	if building != null and is_instance_valid(building) and building.holds(v):
		building.dismiss(v)
	v.job = null
	v.visible = true
	_place_in_front(v, building, 0)

func _place_in_front(person: Villager, building: Building, slot: int) -> void:
	if person == null or not is_instance_valid(person) or building == null or not is_instance_valid(building):
		return
	var spot := front_of(building)
	if slot != 0:
		var dir := 1.0 if slot % 2 == 1 else -1.0
		var shifted := spot + Vector2(dir * float((slot + 1) / 2) * 28.0, 0.0)
		if _point_standable(shifted):
			spot = shifted
	person.job = null
	person.visible = true
	person.stand_at(spot)

func complete_staff(v: Villager, building: Building) -> void:
	_commit_staff(v, building)

func order_stuck() -> void:
	if hud:
		hud.flash(Locale.text("flash.no_path"))

func _commit_staff(v: Villager, building: Building) -> void:
	if not _can_staff(v, building):
		return
	if building.staff_count() >= building.staff_cap() and building.staff_cap() <= 1:
		var slot := 0
		for old in building.dismiss_all():
			var prior := old as Villager
			if prior and prior != v:
				prior.job = null
				_place_in_front(prior, building, slot)
				slot += 1
	if v.job != null and is_instance_valid(v.job) and v.job != building:
		var previous: Building = v.job
		previous.dismiss(v)
		v.job = null
		_place_in_front(v, previous, 0)
	building.add_crew(v)
	v.job = building
	v.ordered = false
	v.pending_job = null
	v.refugee = false
	v.claim_left = -1.0
	if hud.inspected_unit() == v:
		hud.close_panel()
	_clear_villager_selection()
	_popup(building.global_position + Vector2(0, -80), Locale.text("popup.assigned"), Color(0.7, 0.95, 1))
	_refresh_beds()
	_refresh_hud()
	if hud.inspected_building() == building:
		hud.open_building(building)

func _try_place(kind: int, cell: Vector2i) -> bool:
	var reason := _block_reason(cell)
	if reason != "":
		hud.flash(reason)
		return false
	var stats: Dictionary = Balance.building_by_kind(Building.kind_key(kind as Building.Kind))
	var cost: Dictionary = stats.get("cost", {})
	var cap := _wall_cap()
	if kind == Building.Kind.WALL and _count_kind(Building.Kind.WALL) >= cap:
		hud.flash(Locale.format("flash.wall_cap", [cap]))
		return false
	if wood < int(cost.get("wood", 0)) or gold < int(cost.get("gold", 0)):
		hud.flash(Locale.text("flash.need_res"))
		return false
	wood -= int(cost.get("wood", 0))
	gold -= int(cost.get("gold", 0))
	_place_free(kind, cell)
	_refresh_hud()
	return true

func _place_free(kind: int, cell: Vector2i) -> void:
	if not in_bounds(cell) or _blocked(cell) or _is_spawn(cell):
		return
	var building := Building.new()
	building.position = cell_center(cell)
	building.setup(kind as Building.Kind, cell)
	actors.add_child(building)
	buildings[cell] = building
	inspected = building
	_invalidate_props()
	_notify_zombies()

func _remove_building(cell: Vector2i, refund: bool) -> void:
	if not buildings.has(cell):
		return
	var building: Building = buildings[cell]
	var people := building.dismiss_all()
	var slot := 0
	for node in people:
		var person := node as Villager
		if person != null and is_instance_valid(person):
			person.job = null
			_place_in_front(person, building, slot)
			slot += 1
	if refund:
		var stats: Dictionary = Balance.building_by_kind(Building.kind_key(building.kind))
		var cost: Dictionary = stats.get("cost", {})
		var rw := int(cost.get("wood", 0)) / 2
		var rg := int(cost.get("gold", 0)) / 2
		wood += rw
		gold += rg
		_popup(building.global_position, Locale.format("popup.sold", [rw, rg]), Color(0.85, 0.95, 0.7))
	buildings.erase(cell)
	_invalidate_props()
	if inspected == building:
		inspected = null
	building.queue_free()
	_notify_zombies()
	_refresh_hud()
	if not refund:
		for node in people:
			var person := node as Villager
			if person != null and is_instance_valid(person):
				_infect(person)

func _block_reason(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return Locale.text("reason.outside")
	if scenery.has(cell) or _is_spawn(cell):
		return Locale.text("reason.cant")
	if buildings.has(cell):
		return Locale.text("reason.occupied")
	for z in _living_zombies():
		if world_to_cell(z.global_position) == cell:
			return Locale.text("reason.zombie")
	return ""

func _notify_zombies() -> void:
	for z in _living_zombies():
		z.notify_map_changed()

func _infect_contacts() -> void:
	if phase == "win" or phase == "lose":
		return
	for z in _living_zombies():
		for v in _alive_villagers():
			if v.is_fighter():
				continue
			if z.global_position.distance_to(v.global_position) <= INFECT_RADIUS:
				_infect(v)
				if phase == "lose":
					return
				break

func _infect(v: Villager) -> void:
	if v == null or not is_instance_valid(v) or v.infected:
		return
	v.infected = true
	v.leaving = false
	if v.job != null and is_instance_valid(v.job):
		v.job.dismiss(v)
	v.job = null
	if selected_villager == v:
		selected_villager = null
	if hud != null and hud.inspected_unit() == v:
		hud.close_panel()
	var at := v.global_position
	v.visible = false
	v.remove_from_group("iso")
	v.queue_free()
	_popup(at + Vector2(0, -30), Locale.text("popup.infected"), Color(0.65, 1, 0.45))
	_spawn_zombie("normal", true, at)
	if _alive_villagers().is_empty():
		_finish(false)

func _refresh_beds() -> void:
	var beds := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.HOUSE:
			beds += _house_beds()
	var people := _alive_villagers()
	for v in people:
		v.housed = false
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind != Building.Kind.HOUSE:
			continue
		for node in building.crew:
			var staff := node as Villager
			if staff and not staff.infected and not staff.fallen and not staff.is_fighter():
				staff.housed = true
				beds -= 1
	var pool: Array[Villager] = []
	for v in people:
		if v.housed or v.job != null or v.is_fighter():
			continue
		pool.append(v)
	pool.sort_custom(func(a: Villager, b: Villager) -> bool: return a.refugee and not b.refugee)
	for v in pool:
		if beds <= 0:
			break
		v.housed = true
		beds -= 1
		if v.refugee:
			v.refugee = false
			v.claim_left = -1.0

func _alive_villagers() -> Array[Villager]:
	var list: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v != null and not v.infected and not v.leaving and not v.fallen:
			list.append(v)
	return list

func _living_zombies() -> Array[Zombie]:
	var list: Array[Zombie] = []
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z != null and not z.dying:
			list.append(z)
	return list

func _building_at_world(world: Vector2) -> Building:
	# Sprites stand above the diamond, so a click on the art often falls in the
	# cell behind the building. Prefer the front-most body under the cursor.
	var best: Building = null
	var best_y := -INF
	for key in buildings:
		var building: Building = buildings[key]
		var local := world - building.global_position
		var zoom_v := camera.zoom.x if camera else 1.0
		var extra := clampf(28.0 / maxf(zoom_v, 0.05) - 48.0, 0.0, 40.0)
		var on_body := absf(local.x) <= 78.0 + extra and local.y <= 24.0 + extra and local.y >= -130.0 - extra
		if on_body and building.global_position.y >= best_y:
			best_y = building.global_position.y
			best = building
	if best != null:
		return best
	var cell := world_to_cell(world)
	if buildings.has(cell):
		return buildings[cell]
	return null

func _villager_pick_radius() -> float:
	var zoom_v := camera.zoom.x if camera else 1.0
	return minf(maxf(48.0, 34.0 / maxf(zoom_v, 0.05)), 96.0)

func _villager_pick_point(v: Villager) -> Vector2:
	return v.global_position + Vector2(0, -30)

func _villagers_hit(world: Vector2) -> Array[Villager]:
	var hits: Array[Villager] = []
	var radius := _villager_pick_radius()
	for v in _alive_villagers():
		if v.job != null and is_instance_valid(v.job):
			continue
		if world.distance_to(_villager_pick_point(v)) < radius:
			hits.append(v)
	return hits

# Clicks on a shared footprint use one rule:
# the selected villager wins when the click reaches them, so a neighbor in
# the pile cannot steal the click before a move. Otherwise the frontmost
# sprite wins (highest z_index, the depth rank). Ties break toward the
# nearer pick point, then the lower instance id.
func _pick_villager(hits: Array[Villager], world: Vector2) -> Villager:
	if hits.is_empty():
		return null
	if selected_villager != null and is_instance_valid(selected_villager) and hits.has(selected_villager):
		return selected_villager
	return _sort_hits(hits, world)[0]

func _next_stacked(hits: Array[Villager], current: Villager, world: Vector2) -> Villager:
	var ranked := _sort_hits(hits, world)
	var at := ranked.find(current)
	if at < 0:
		return ranked[0]
	return ranked[(at + 1) % ranked.size()]

func _sort_hits(hits: Array[Villager], world: Vector2) -> Array[Villager]:
	var ranked: Array[Villager] = []
	ranked.assign(hits)
	ranked.sort_custom(func(a: Villager, b: Villager) -> bool:
		return _villager_before(a, b, world)
	)
	return ranked

func _villager_before(a: Villager, b: Villager, world: Vector2) -> bool:
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	var da := world.distance_squared_to(_villager_pick_point(a))
	var db := world.distance_squared_to(_villager_pick_point(b))
	if absf(da - db) > 0.01:
		return da < db
	return a.get_instance_id() < b.get_instance_id()

func _clear_villager_selection() -> void:
	# Highlight only. Move and enter orders are not part of the selection.
	if selected_villager != null and is_instance_valid(selected_villager):
		selected_villager.selected = false
	selected_villager = null

func _update_ghost() -> void:
	var ghost := decals.get_node_or_null("Ghost") as Node2D
	if hud == null or not hud.has_ground():
		if ghost:
			ghost.visible = false
		return
	var cell := hud.ground_cell()
	if not in_bounds(cell):
		if ghost:
			ghost.visible = false
		return
	if ghost == null:
		ghost = Node2D.new()
		ghost.name = "Ghost"
		ghost.set_script(load("res://scripts/tile_mark.gd"))
		ghost.z_as_relative = true
		ghost.z_index = 0
		decals.add_child(ghost)
	ghost.visible = true
	ghost.position = cell_center(cell)
	ghost.queue_redraw()

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
	var shown := wave_number
	if phase == "prep" and wave_number > 0 and wave_number < _wave_count():
		shown = wave_number + 1
	elif phase == "win":
		shown = _wave_count()
	var label := "%d/%d" % [shown, _wave_count()]
	var claim := 0.0
	for v in _alive_villagers():
		if v.refugee and v.claim_left > claim:
			claim = v.claim_left
	var housed := 0
	for v in _alive_villagers():
		if v.housed:
			housed += 1
	hud.refresh(wood, gold, _alive_villagers().size(), housed, _bed_cap(), _count_kind(Building.Kind.WALL), _wall_cap(), label, phase, claim)

func _balance_probe() -> int:
	var failed := false
	var units := Balance.unit_ids()
	var enemies := Balance.enemy_ids()
	var buildings_ids := Balance.building_ids()
	if units.size() < 3 or enemies.size() < 5 or buildings_ids.size() < 6 or Balance.waves().size() != 10:
		failed = true
	var spear_def := Balance.building_by_kind("SPEAR")
	var range_expect := 460.0 * IsoVolume.WORLD_SCALE
	if absf(float(spear_def.get("attack_range", 0.0)) - range_expect) > 0.05:
		failed = true
	var cd := 1.0 / float(spear_def.get("attack_speed", 1.0))
	if absf(cd - 0.64) > 0.0001:
		failed = true
	if Balance.damage(24.0, 0.0) != 24 or Balance.damage(22.5, 0.0) != 23 or Balance.damage(1.0, 6.0) != 1 or Balance.damage(3.0, 6.0) != 3:
		failed = true
	if int(Balance.scaled_enemy("spear_normal", 0).hp) != 34:
		failed = true
	if int(Balance.scaled_enemy("spear_fast", 1).hp) != 31:
		failed = true
	if int(Balance.scaled_enemy("shooter_boss", 9).hp) != 546:
		failed = true
	if int(Balance.scaled_enemy("spear_infected", 0).hp) != 22:
		failed = true
	var villager_def := Balance.unit("villager")
	if absf(float(villager_def.get("move_speed", 0.0)) - 108.0 * IsoVolume.WORLD_SCALE) > 0.05:
		failed = true
	if Balance.skin_index("villager", "knight") != 3 or Balance.skin_index("villager", "robot") != 5:
		failed = true
	for person in _alive_villagers():
		if person.unit_id != "villager" or person._skin == 3 or person._skin == 5:
			failed = true
		if absf(person.speed - float(villager_def.move_speed)) > 0.05:
			failed = true
	if _bed_cap() != 8 or absf(tower_bonus() - 1.25) > 0.001 or _farm_wave_wood() != 6 or _wall_cap() != 28:
		failed = true
	var mill_def := Balance.building("lumber_mill")
	var mill_out: Dictionary = mill_def.get("produces", {})
	if int(mill_def.get("staff_slots", 0)) != 4 or str(mill_out.get("mode", "")) != "staff" or int(mill_out.get("rate_per_villager", 0)) != 1:
		failed = true
	if int(Balance.enemy("spear_normal").get("wood_reward", 1)) != 0:
		failed = true
	if absf(float(Balance.settlement().get("chance", 0.0)) - 0.65) > 0.001 or int(Balance.settlement().get("max_per_wave", 0)) != 3:
		failed = true
	var rects := Balance.spawn_rects()
	var gate: Dictionary = rects[0] if rects.size() == 1 and rects[0] is Dictionary else {}
	var mid = gate.get("middle", [])
	var gate_ok: bool = str(gate.get("edge", "")) == "north" and mid is Array and mid.size() >= 2 and int(mid[0]) == 10 and int(mid[1]) == 0
	if not gate_ok or Balance.spawns().size() != 3 or spawns.size() != 3:
		failed = true
	if not _is_spawn(Vector2i(9, 0)) or not _is_spawn(Vector2i(10, 0)) or not _is_spawn(Vector2i(11, 0)) or _is_spawn(Vector2i(8, 0)):
		failed = true
	var spear_slots: Dictionary = Balance.building("spear_barracks").get("provides", {})
	var gun_slots: Dictionary = Balance.building("gun_barracks").get("provides", {})
	var shop_slots: Dictionary = Balance.building("workshop").get("provides", {})
	var house_slots: Dictionary = Balance.building("house").get("provides", {})
	if str(spear_slots.get("unit", "")) != "spearman" or int(spear_slots.get("slots", 0)) != 2:
		failed = true
	if str(gun_slots.get("unit", "")) != "gunner" or int(gun_slots.get("slots", 0)) != 2:
		failed = true
	if str(shop_slots.get("unit", "")) != "engineer" or int(shop_slots.get("slots", 0)) != 2:
		failed = true
	if int(house_slots.get("slots", 0)) != 4:
		failed = true
	var wood_before := wood
	var gold_before := gold
	var payout := Zombie.new()
	payout.reward_wood = 9
	payout.reward_gold = 3
	on_zombie_killed(payout)
	if wood != wood_before or gold != gold_before + 3:
		failed = true
	wood = 500
	gold = 500
	var mill_cell := Vector2i(10, 8)
	if not _try_place(Building.Kind.LUMBER, mill_cell):
		failed = true
	else:
		var idle_wood := wood
		_tick_mills(20.0)
		if wood != idle_wood:
			failed = true
		var mill: Building = buildings[mill_cell]
		var assigned := 0
		for person in _alive_villagers():
			if person.unit_id != "villager" or person.job != null:
				continue
			_assign(person, mill)
			assigned += 1
			if assigned >= 2:
				break
		var staffed_wood := wood
		_tick_mills(5.0)
		if assigned != 2 or mill.villager_crew() != 2 or wood != staffed_wood + 2:
			failed = true
	var spear: Building = buildings[Vector2i(7, 12)]
	if spear.has_staff() or not spear.is_defense() or spear.max_hp != 200 or absf(spear.defense - 6.0) > 0.001:
		failed = true
	var dummy := Zombie.new()
	dummy.position = spear.position + Vector2(40, 0)
	dummy.setup(30, 0.0, 1.0, 1, 0, 0, "probe", Color.WHITE, "spear")
	actors.add_child(dummy)
	spear.cooldown = 0.0
	spear._process(0.016)
	var shots := 0
	for child in fx.get_children():
		if child is Projectile:
			shots += 1
	if shots < 1:
		failed = true
	var normal := Balance.scaled_enemy("spear_normal", 0)
	var user_path := "user://setup.json"
	var old_setup := FileAccess.open(user_path, FileAccess.WRITE)
	if old_setup == null:
		failed = true
	else:
		old_setup.store_string("{\"config_version\":0,\"difficulty_id\":\"hard\"}")
		old_setup.close()
		Balance.reload()
		var upgraded = JSON.parse_string(FileAccess.get_file_as_string(user_path))
		var version_ok := false
		if upgraded is Dictionary:
			var econ: Dictionary = upgraded.get("economy", {})
			version_ok = int(upgraded.get("config_version", 0)) == Balance.config_version() and Balance.difficulty_id() == "hard" and int(econ.get("start_wood", 0)) == 100
		if not version_ok:
			failed = true
		Balance.reset_editor_state()
		if Balance.difficulty_id() != "normal" or Balance.config_version() < 1:
			failed = true
	print("BALANCE units=", units, " enemies=", enemies, " buildings=", buildings_ids, " spawns=", Balance.spawns(), " rects=", Balance.spawn_rects().size())
	print("BALANCE dmg=", Balance.damage(24.0, 0.0), "/", Balance.damage(22.5, 0.0), " beds=", _bed_cap(), " bonus=", tower_bonus(), " shots=", shots, " boss=", Balance.scaled_enemy("shooter_boss", 9).hp, " normal_hp=", normal.hp)
	print("BALANCE_OK" if not failed else "BALANCE_FAIL")
	return 0 if not failed else 1

func _wave_count() -> int:
	var n := Balance.waves().size()
	return n if n > 0 else 10

func _wall_cap() -> int:
	var cap := int(Balance.building_by_kind("WALL").get("place_cap", 28))
	return cap if cap > 0 else 28

func _house_beds() -> int:
	var beds := int(Balance.building_by_kind("HOUSE").get("beds", 4))
	return beds if beds > 0 else 4

func _farm_wave_wood() -> int:
	var wood_bonus := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind != Building.Kind.FARM:
			continue
		var produces = Balance.building_by_kind("FARM").get("produces", null)
		if produces is Dictionary:
			wood_bonus += int(produces.get("rate", 0))
	return wood_bonus

func _bed_cap() -> int:
	var n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.HOUSE:
			n += _house_beds()
	return n

func _count_kind(kind: int) -> int:
	var n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == kind:
			n += 1
	return n

func _is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == COLS - 1 or cell.y == ROWS - 1

func _is_spawn(cell: Vector2i) -> bool:
	return cell in spawns

func _open_stress_now() -> bool:
	if Engine.get_meta("skip_stress", false):
		return false
	var n := _stress_count()
	if n <= 0:
		return false
	Engine.set_meta("stress_n", n)
	Engine.set_meta("stress_only", _stress_only())
	return true

func _stress_count() -> int:
	var env := OS.get_environment("TD_STRESS")
	if env.is_valid_int():
		return clampi(int(env), 0, 800)
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		return _stress_in_query(query)
	return 0

func _stress_only() -> String:
	var env := OS.get_environment("TD_STRESS_ONLY")
	if env == "ref" or env == "new":
		return env
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		if query.contains("only=ref"):
			return "ref"
		if query.contains("only=new"):
			return "new"
	return ""

func _stress_in_query(query: String) -> int:
	var at := query.find("stress=")
	if at < 0:
		return 0
	var rest := query.substr(at + 7)
	var amp := rest.find("&")
	if amp >= 0:
		rest = rest.substr(0, amp)
	if not rest.is_valid_int():
		return 0
	return clampi(int(rest), 0, 800)

func _open_lab_now() -> bool:
	if Engine.get_meta("skip_lab", false):
		return false
	if OS.get_environment("TD_LAB") == "1":
		return true
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		return query.contains("lab=1")
	return false

func _open_codex() -> void:
	Balance.prepare_codex_refresh()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign(new URL('codex/', window.location.href).href)", true)
		return
	OS.shell_open("https://choicelin94.github.io/villiage-td/codex/")

func _open_workbench() -> void:
	get_tree().change_scene_to_file("res://scenes/workbench.tscn")

func _hud_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	hud._layout()
	var wide_ok := _hud_bar_ok("wide")
	var help := hud.get_node_or_null("HelpButton") as Button
	if help:
		help.emit_signal("pressed")
	await get_tree().process_frame
	var menu_ok := _hud_menu_ok("wide")
	await _capture("/opt/cursor/artifacts/hud-menu.png")
	if help:
		help.emit_signal("pressed")
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	hud._layout()
	var narrow_ok := _hud_bar_ok("narrow")
	if help:
		help.emit_signal("pressed")
	await get_tree().process_frame
	var narrow_menu := _hud_menu_ok("narrow")
	await _capture("/opt/cursor/artifacts/hud-menu-phone.png")
	var passed := wide_ok and menu_ok and narrow_ok and narrow_menu
	print("HUD_OK ", passed)
	get_tree().quit(0 if passed else 1)

func _hud_bar_ok(tag: String) -> bool:
	var bar := hud.get_node_or_null("TopBar") as Control
	var help := hud.get_node_or_null("HelpButton") as Button
	var lang := hud.get_node_or_null("LangButton") as Button
	var no_lab := hud.get_node_or_null("LabButton") == null
	var icon_only := help != null and help.text.strip_edges() == ""
	var row := bar.get_child(0) as HBoxContainer if bar != null else null
	var ys: Array[float] = []
	var font_ok := false
	if row:
		for child in row.get_children():
			if not (child is Control) or not (child as Control).visible:
				continue
			var rect := (child as Control).get_global_rect()
			ys.append(rect.position.y)
			var label := child.get_child(1) as Label if child.get_child_count() > 1 else null
			if label:
				font_ok = label.get_theme_font_size("font_size") >= 20
	var same_row := ys.size() >= 4
	if same_row:
		var y0 := ys[0]
		for y in ys:
			if absf(y - y0) > 1.5:
				same_row = false
	var lang_font := lang.get_theme_font_size("font_size") >= 20 if lang else false
	var beside := false
	var inside := false
	if help and lang and bar:
		var help_rect := help.get_global_rect()
		var lang_rect := lang.get_global_rect()
		var bar_rect := bar.get_global_rect()
		beside = lang_rect.position.x >= help_rect.end.x - 2.0
		inside = help_rect.position.y >= bar_rect.position.y - 1.0 and help_rect.end.y <= bar_rect.end.y + 1.0
	print("HUD_BAR ", tag, " chips=", ys.size(), " row=", same_row, " font=", font_ok, " lang=", lang_font, " icon=", icon_only, " nolab=", no_lab, " beside=", beside, " inside=", inside)
	return same_row and font_ok and lang_font and icon_only and no_lab and beside and inside and lang != null

func _hud_menu_ok(tag: String) -> bool:
	var bar := hud.get_node_or_null("TopBar") as Control
	var menu := hud.get_node_or_null("HelpMenu") as Control
	var codex := hud.find_child("CodexButton", true, false) as Button
	var bench := hud.find_child("BenchButton", true, false) as Button
	if bar == null or menu == null or codex == null or bench == null or not menu.visible:
		print("HUD_MENU ", tag, " missing")
		return false
	var bar_rect := bar.get_global_rect()
	var menu_rect := menu.get_global_rect()
	var clear := menu_rect.position.y >= bar_rect.end.y - 0.5 and not menu_rect.intersects(bar_rect)
	var labels := codex.text == Locale.text("menu.codex") and bench.text == Locale.text("menu.bench")
	var only_two := menu.get_child(0).get_child_count() == 2
	var codex_font := codex.get_theme_font_size("font_size") >= 20
	print("HUD_MENU ", tag, " clear=", clear, " labels=", labels, " two=", only_two, " font=", codex_font, " codex=", codex.text, " bench=", bench.text, " menu_y=", menu_rect.position.y, " bar_end=", bar_rect.end.y)
	return clear and labels and only_two and codex_font

func _apply_iso_sort() -> void:
	if actors == null:
		return
	DepthSolver.allow_walker_overlap = true
	var vols: Array = []
	for node in get_tree().get_nodes_in_group("iso"):
		if not is_instance_valid(node) or not (node is CanvasItem):
			continue
		if not (node as CanvasItem).is_visible_in_tree():
			continue
		if not node.has_method("get_iso_volume"):
			continue
		vols.append(node.get_iso_volume())
	DepthSolver.apply(vols)

func can_step(from_pos: Vector2, to_pos: Vector2, ignore: Node = null) -> bool:
	var to_cell := world_to_cell(to_pos)
	if not in_bounds(to_cell):
		return false
	if _blocked(to_cell) and to_cell != world_to_cell(from_pos):
		return false
	return _oval_clear(to_pos, ignore, null)

func route_cells(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var found: Dictionary = _astar(start, goal)
	var path: Array[Vector2i] = found.path
	return path

func _blocked(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	if scenery.has(cell) or buildings.has(cell):
		return true
	_ensure_props()
	return _center_block.has(cell)

func _invalidate_props() -> void:
	_prop_ready = false
	_prop_cache = []
	_center_block = {}

func _ensure_props() -> void:
	if _prop_ready:
		return
	_prop_cache = []
	_center_block = {}
	for node in get_tree().get_nodes_in_group("iso"):
		if node is Villager or node is Zombie:
			continue
		if node.has_method("get_iso_volume"):
			_prop_cache.append(node.get_iso_volume())
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if scenery.has(cell) or buildings.has(cell):
				continue
			var mine := IsoVolume.from_feet(cell_center(cell))
			for prop in _prop_cache:
				if mine.overlaps(prop):
					_center_block[cell] = true
					break
	_prop_ready = true

func _oval_clear(world: Vector2, ignore: Node, also: Node) -> bool:
	var mine := IsoVolume.from_feet(world)
	_ensure_props()
	for prop in _prop_cache:
		if mine.overlaps(prop):
			return false
	# Villagers, including fighters, do not block each other. Zombies still do.
	var skip_villagers := ignore == null or ignore is Villager
	if not skip_villagers:
		for node in get_tree().get_nodes_in_group("villagers"):
			if not _walker_counts(node, ignore, also):
				continue
			if mine.overlaps((node as Villager).get_iso_volume()):
				return false
	for node in get_tree().get_nodes_in_group("zombies"):
		if not _walker_counts(node, ignore, also):
			continue
		var zombie := node as Zombie
		if mine.overlaps(zombie.get_iso_volume()):
			return false
	return true

func _walker_counts(node: Node, ignore: Node, also: Node) -> bool:
	if node == ignore or node == also:
		return false
	if not is_instance_valid(node) or not (node is CanvasItem):
		return false
	return (node as CanvasItem).visible

func _separate_walkers() -> void:
	var bodies: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("villagers"):
		if _walker_counts(node, null, null):
			bodies.append(node)
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie != null and _walker_counts(node, null, null):
			bodies.append(zombie)
	_eject_from_props(bodies)
	if bodies.size() < 2:
		return
	var x_lim := 0.33 * IsoVolume.TILE
	var y_lim := 0.30 * IsoVolume.TILE
	for _pass in 8:
		var moved := false
		for i in bodies.size():
			if not is_instance_valid(bodies[i]):
				continue
			for j in range(i + 1, bodies.size()):
				if not is_instance_valid(bodies[j]):
					continue
				if bodies[i] is Villager and bodies[j] is Villager:
					continue
				var delta := bodies[i].global_position - bodies[j].global_position
				if absf(delta.x) >= x_lim or absf(delta.y) >= y_lim:
					continue
				var va := IsoVolume.from_feet(bodies[i].global_position)
				var vb := IsoVolume.from_feet(bodies[j].global_position)
				if not va.overlaps(vb):
					continue
				if _push_apart(bodies[i], bodies[j]):
					moved = true
		if not moved:
			break
	for i in bodies.size():
		if not is_instance_valid(bodies[i]):
			continue
		for j in range(i + 1, bodies.size()):
			if not is_instance_valid(bodies[j]):
				continue
			if bodies[i] is Villager and bodies[j] is Villager:
				continue
			var delta := bodies[i].global_position - bodies[j].global_position
			if absf(delta.x) >= x_lim or absf(delta.y) >= y_lim:
				continue
			if not IsoVolume.from_feet(bodies[i].global_position).overlaps(IsoVolume.from_feet(bodies[j].global_position)):
				continue
			_shove_free(bodies[j], bodies)

func _push_apart(a: Node2D, b: Node2D) -> bool:
	var delta := a.global_position - b.global_position
	if delta.length_squared() < 0.25:
		delta = Vector2(0, -1)
	var iso := delta / IsoVolume.TILE
	var need := IsoVolume.walker_separation(iso) + 0.006
	var have := iso.length()
	var pen := need - have
	if pen < 0.006:
		pen = 0.006
	var dir := iso / maxf(have, 0.0001)
	if _slide_iso(a, dir * pen):
		return true
	if _slide_iso(b, -dir * pen):
		return true
	var room_a := _room_iso(a, dir, pen)
	var room_b := _room_iso(b, -dir, pen)
	if room_a + room_b >= pen - 0.0001:
		_slide_iso(a, dir * room_a)
		_slide_iso(b, -dir * (pen - room_a))
		return true
	var dx := absf(iso.x)
	var dy := absf(iso.y)
	var need_x := 0.326 - dx
	var need_y := 0.296 - dy
	if need_x < need_y:
		if _separate_axis(a, b, Vector2(1, 0), need_x):
			return true
		return _separate_axis(a, b, Vector2(0, 1), need_y)
	if _separate_axis(a, b, Vector2(0, 1), need_y):
		return true
	return _separate_axis(a, b, Vector2(1, 0), need_x)

func _separate_axis(a: Node2D, b: Node2D, axis: Vector2, gap: float) -> bool:
	if gap <= 0.001:
		return true
	if _slide_iso(a, axis * gap) or _slide_iso(b, -axis * gap):
		return true
	if _slide_iso(a, -axis * gap) or _slide_iso(b, axis * gap):
		return true
	var room_a := _room_iso(a, axis, gap)
	var room_b := _room_iso(b, -axis, gap)
	if room_a + room_b >= gap - 0.0001:
		_slide_iso(a, axis * room_a)
		_slide_iso(b, -axis * (gap - room_a))
		return true
	room_a = _room_iso(a, -axis, gap)
	room_b = _room_iso(b, axis, gap)
	if room_a + room_b >= gap - 0.0001:
		_slide_iso(a, -axis * room_a)
		_slide_iso(b, axis * (gap - room_a))
		return true
	return false

func _slide_iso(body: Node2D, iso_delta: Vector2) -> bool:
	if iso_delta.length_squared() < 0.00000001:
		return true
	var world := body.global_position + iso_delta * IsoVolume.TILE
	if not _feet_clear(world):
		return false
	body.global_position = world
	return true

func _room_iso(body: Node2D, dir: Vector2, max_d: float) -> float:
	var lo := 0.0
	var hi := max_d
	for _k in 6:
		var mid := (lo + hi) * 0.5
		if _feet_clear(body.global_position + dir * mid * IsoVolume.TILE):
			lo = mid
		else:
			hi = mid
	return lo

func _eject_from_props(bodies: Array[Node2D]) -> void:
	var radii: Array[float] = [0.08, 0.16, 0.28, 0.42, 0.6, 0.85, 1.2, 1.7]
	var dirs: Array[Vector2] = [
		Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1),
	]
	for body in bodies:
		if not is_instance_valid(body) or _prop_clear(body.global_position):
			continue
		var origin := body.global_position
		if _place_clear(body, origin, bodies, radii, dirs, true):
			continue
		_place_clear(body, origin, bodies, radii, dirs, false)

func _place_clear(body: Node2D, origin: Vector2, bodies: Array[Node2D], radii: Array[float], dirs: Array[Vector2], check_bodies: bool) -> bool:
	for radius in radii:
		for dir in dirs:
			var world := origin + dir.normalized() * radius * IsoVolume.TILE
			if not _prop_clear(world):
				continue
			if check_bodies and not _clear_of_bodies(body, world, bodies):
				continue
			body.global_position = world
			return true
	return false

func _prop_clear(world: Vector2) -> bool:
	var cell := world_to_cell(world)
	if not in_bounds(cell):
		return false
	var mine := IsoVolume.from_feet(world)
	_ensure_props()
	for prop in _prop_cache:
		if mine.overlaps(prop):
			return false
	return true

func _feet_clear(world: Vector2) -> bool:
	var cell := world_to_cell(world)
	if not in_bounds(cell) or _blocked(cell):
		return false
	var mine := IsoVolume.from_feet(world)
	_ensure_props()
	for prop in _prop_cache:
		if mine.overlaps(prop):
			return false
	return true

func _shove_free(body: Node2D, bodies: Array[Node2D]) -> void:
	var origin := body.global_position
	var radii: Array[float] = [0.36, 0.55, 0.8, 1.15, 1.6, 2.2]
	var dirs: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
	]
	for radius in radii:
		for dir in dirs:
			var world := origin + dir.normalized() * radius * IsoVolume.TILE
			if not _feet_clear(world):
				continue
			if not _clear_of_bodies(body, world, bodies):
				continue
			body.global_position = world
			return

func _clear_of_bodies(body: Node2D, world: Vector2, bodies: Array[Node2D]) -> bool:
	var mine := IsoVolume.from_feet(world)
	for other in bodies:
		if other == body or not is_instance_valid(other):
			continue
		if mine.overlaps(IsoVolume.from_feet(other.global_position)):
			return false
	return true

func _nearest_open_villager_cell(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 999999
	for v in _alive_villagers():
		if v.job != null and is_instance_valid(v.job):
			continue
		var cell := world_to_cell(v.global_position)
		if not in_bounds(cell) or _blocked(cell):
			continue
		var d := absi(cell.x - from.x) + absi(cell.y - from.y)
		if d < best_d:
			best_d = d
			best = cell
	return best

func _nearest_staffed_cell(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 999999
	for v in _alive_villagers():
		if v.job == null or not is_instance_valid(v.job):
			continue
		var cell: Vector2i = v.job.cell
		var d := absi(cell.x - from.x) + absi(cell.y - from.y)
		if d < best_d:
			best_d = d
			best = cell
	return best

func _astar(start: Vector2i, goal: Vector2i) -> Dictionary:
	if start == goal:
		var only: Array[Vector2i] = [start]
		return {"path": only}
	if not in_bounds(start) or not in_bounds(goal):
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
			if closed.has(nxt) or not in_bounds(nxt):
				continue
			if nxt != goal and _blocked(nxt):
				continue
			var tentative := int(gscore[current]) + 1
			if tentative < int(gscore.get(nxt, 999999)):
				came[nxt] = current
				gscore[nxt] = tentative
				open.append(nxt)
	return {"path": [] as Array[Vector2i]}

func _path_to_attack(start: Vector2i, goal: Vector2i) -> Dictionary:
	var empty: Array[Vector2i] = []
	var none := {"path": empty, "attack": Vector2i(-1, -1)}
	if not in_bounds(start) or not buildings.has(goal):
		return none
	var queue: Array[Vector2i] = [start]
	var came := {}
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for dir in DIRS:
			var nxt: Vector2i = current + dir
			if not in_bounds(nxt) or seen.has(nxt):
				continue
			if nxt == goal:
				return {"path": _rebuild(came, current), "attack": goal}
			if _blocked(nxt):
				continue
			seen[nxt] = true
			came[nxt] = current
			queue.append(nxt)
	return none

func _path_to_building(start: Vector2i) -> Dictionary:
	var empty: Array[Vector2i] = []
	if not in_bounds(start):
		return {"path": empty, "attack": Vector2i(-1, -1)}
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
		return {"path": empty, "attack": Vector2i(-1, -1)}
	return {"path": _rebuild(came, best_from), "attack": best_cell}

func _chain_length(came: Dictionary, cell: Vector2i) -> int:
	var n := 0
	var cursor := cell
	while came.has(cursor):
		cursor = came[cursor]
		n += 1
		if n > 800:
			break
	return n

func _rebuild(came: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var guard := 0
	while came.has(current) and guard < 800:
		current = came[current]
		path.push_front(current)
		guard += 1
	return path

func _scripted_defense() -> void:
	wood = 999
	gold = 999
	var modest := OS.get_environment("TD_MODEST") == "1"
	var people := _alive_villagers()
	var want: Array[int] = []
	if modest:
		want = [Building.Kind.SPEAR]
	else:
		want = [Building.Kind.HOUSE, Building.Kind.SPEAR, Building.Kind.SPEAR, Building.Kind.FIRE, Building.Kind.WORKSHOP]
	var pi := 0
	for kind in want:
		if pi >= people.size():
			break
		for cell in buildings:
			var building: Building = buildings[cell]
			if building.kind == kind and not building.has_staff():
				_assign(people[pi], building)
				pi += 1
				break
	if not modest:
		var extra := [
			Vector2i(5, 8), Vector2i(7, 8), Vector2i(9, 8), Vector2i(11, 8), Vector2i(13, 8), Vector2i(15, 8),
			Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6), Vector2i(15, 6),
		]
		for cell in extra:
			if _count_kind(Building.Kind.WALL) >= _wall_cap():
				break
			_try_place(Building.Kind.WALL, cell)
	var route: Dictionary = route_from(spawns[mini(2, spawns.size() - 1)])
	print("SCRIPTED buildings=", buildings.size(), " people=", _alive_villagers().size(), " path=", route.path.size())

func _flow_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("/tmp/shots/start.png")
	var spear: Building = buildings[Vector2i(7, 12)]
	_click_world(spear.global_position + Vector2(0, -70))
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOW_BUILDING_FIRST staff=", spear.has_staff(), " selected=", selected_villager != null)
	var people := _alive_villagers()
	_click_world(people[0].global_position + Vector2(0, -30))
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOW_VILLAGER_SELECTED ", selected_villager == people[0])
	await _capture("/tmp/shots/selected.png")
	_click_world(spear.global_position + Vector2(0, -70))
	var flow_scale := Engine.time_scale
	Engine.time_scale = 8.0
	var assigned := false
	for _i in 240:
		await get_tree().process_frame
		if spear.has_staff() and spear.primary_staff() == people[0]:
			assigned = true
			break
	Engine.time_scale = flow_scale
	print("FLOW_ASSIGNED ", assigned)
	await _capture("/tmp/shots/assigned.png")
	var restart := _restart_button()
	print("FLOW_RESTART_BUTTON ", restart != null)
	var marker := FileAccess.open("/tmp/td_flow_restarted", FileAccess.WRITE)
	if marker:
		marker.store_line("1")
		marker.close()
	if restart:
		_click_screen(restart.get_global_rect().get_center())
		return
	print("FLOW_RESTART_FAILED")
	get_tree().quit(1)

func _restart_button() -> Button:
	if hud == null:
		return null
	var buttons: Array[Button] = []
	_collect_buttons(hud, buttons)
	for button in buttons:
		if button.name == "LeaveButton":
			return button
	return null

func _collect_buttons(node: Node, into: Array[Button]) -> void:
	if node is Button:
		into.append(node)
	for child in node.get_children():
		_collect_buttons(child, into)

func _click_world(world: Vector2) -> void:
	_click_screen(get_viewport().get_canvas_transform() * world)

func _click_screen(screen: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	get_viewport().push_input(motion, false)
	press.position = screen
	press.global_position = screen
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(press, false)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	get_viewport().push_input(release, false)

func _ui_shot() -> void:
	var win := get_window()
	win.size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_pixels()
	_cam_user = false
	_apply_fit_zoom(true)
	hud._layout()
	await get_tree().process_frame
	print("UI_VIEW ", get_viewport_rect().size, " win=", DisplayServer.window_get_size(), " zoom=", camera.zoom.x)
	var focus := _center_half_focus()
	var view := get_viewport_rect().size
	var screen_focus: Vector2 = get_viewport().get_canvas_transform() * focus
	var phone := _is_phone()
	var zoom_hidden := not hud.zoom_buttons_visible()
	var framed := camera.position.distance_to(focus) < 120.0 and screen_focus.distance_to(view * 0.5) < 140.0
	print("UI_PHONE ", phone, " zoom_btns=", hud.zoom_buttons_visible(), " cam=", camera.position, " focus=", focus, " screen_focus=", screen_focus, " framed=", framed)
	await _capture("/tmp/shots/phone.png")
	var cell := _visible_open_cell()
	print("UI_CELL ", cell, " screen=", get_viewport().get_canvas_transform() * cell_center(cell))
	_click_world(cell_center(cell))
	await get_tree().process_frame
	await get_tree().process_frame
	print("UI_PANEL ", hud.has_ground(), " ", hud.ground_cell())
	await _capture("/tmp/shots/phone_panel.png")
	var placed := _try_place(Building.Kind.WALL, cell)
	if placed:
		hud.close_panel()
	print("UI_PLACED ", placed, " ", buildings.has(cell), " panel=", hud.has_ground())
	await _capture("/tmp/shots/phone_built.png")
	var z0 := camera.zoom.x
	_pinch_test()
	var zoomed := camera.zoom.x > z0 + 0.02
	print("UI_ZOOM ", z0, " -> ", camera.zoom.x)
	var cam_before := camera.position
	_drag_test()
	var panned := camera.position.distance_to(cam_before) > 8.0
	print("UI_PAN ", cam_before, " -> ", camera.position, " moved=", panned)
	var icons := hud.get_node_or_null("StartButton") != null and hud.get_node_or_null("LeaveButton") != null
	print("UI_ICONS ", icons)
	if placed and zoomed and panned and icons and not hud.has_ground() and phone and zoom_hidden and framed:
		get_tree().quit(0)
		return
	get_tree().quit(1)

func _visible_open_cell() -> Vector2i:
	var view := get_viewport_rect().size
	var xform := get_viewport().get_canvas_transform()
	for y in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			var cell := Vector2i(x, y)
			if scenery.has(cell) or buildings.has(cell) or _is_spawn(cell):
				continue
			var screen: Vector2 = xform * cell_center(cell)
			if screen.x > 28.0 and screen.x < view.x * 0.5 and screen.y > 96.0 and screen.y < view.y - 160.0:
				return cell
	return Vector2i(3, 3)

func _pinch_test() -> void:
	var view := get_viewport_rect().size
	var a := Vector2(view.x * 0.32, view.y * 0.42)
	var b := Vector2(view.x * 0.48, view.y * 0.42)
	var b2 := Vector2(view.x * 0.72, view.y * 0.42)
	_push_touch(0, a, true)
	_push_touch(1, b, true)
	_push_drag(1, b2, b2 - b)
	_push_touch(0, a, false)
	_push_touch(1, b2, false)

func _drag_test() -> void:
	var view := get_viewport_rect().size
	var a := Vector2(view.x * 0.45, view.y * 0.5)
	var b := a + Vector2(90, 0)
	_push_touch(0, a, true)
	_push_drag(0, b, b - a)
	_push_touch(0, b, false)

func _push_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	get_viewport().push_input(ev, false)

func _push_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = rel
	get_viewport().push_input(ev, false)

func _lang_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var persisted := FileAccess.file_exists("/tmp/td_lang_switched")
	var hint := _hint_text()
	print("LANG ", Locale.code, " persist=", persisted, " hint=", hint)
	var mono := not hint.contains(" / ")
	if persisted:
		var ok := Locale.code == "en" and hint.contains("Tap empty") and not _has_cjk(hint) and mono
		await _capture("/opt/cursor/artifacts/lang-en.png")
		hud.open_ground(Vector2i(3, 3))
		await get_tree().process_frame
		var panel := _ui_texts()
		print("LANG_PANEL ", panel)
		var panel_ok := not panel.contains(" / ") and not _has_cjk(panel.replace("中文", ""))
		print("LANG_PERSIST ", ok and panel_ok)
		await _capture("/opt/cursor/artifacts/lang-en-panel.png")
		get_tree().quit(0 if ok and panel_ok else 1)
		return
	var zh_ok := Locale.code == "zh" and hint.contains("点空地") and not hint.contains("Tap empty") and mono
	await _capture("/opt/cursor/artifacts/lang-zh.png")
	var lang_btn := hud.get_node_or_null("LangButton") as Button
	if lang_btn:
		_click_screen(lang_btn.get_global_rect().get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	hint = _hint_text()
	print("LANG_SWITCH ", Locale.code, " hint=", hint)
	var en_ok := Locale.code == "en" and hint.contains("Tap empty") and not _has_cjk(hint)
	hud.open_ground(Vector2i(3, 3))
	await get_tree().process_frame
	var panel_now := _ui_texts()
	print("LANG_PANEL_NOW ", panel_now)
	var panel_en := panel_now.contains("Wall") and not panel_now.contains("木墙") and not panel_now.contains(" / ")
	var marker := FileAccess.open("/tmp/td_lang_switched", FileAccess.WRITE)
	if marker:
		marker.store_line("1")
		marker.close()
	get_tree().quit(0 if zh_ok and en_ok and panel_en else 1)

func _move_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var people := _alive_villagers()
	for v in people:
		v.anchored = true
		v.visible = false
	var house_cell := Vector2i(8, 14)
	var from_cell := Vector2i(8, 15)
	var goal_cell := Vector2i(8, 13)
	var into := can_step(cell_center(from_cell), cell_center(house_cell))
	var out := can_step(cell_center(house_cell), cell_center(from_cell))
	var tree_cell := Vector2i(0, 5)
	var into_tree := can_step(cell_center(Vector2i(1, 5)), cell_center(tree_cell))
	var into_rock := can_step(cell_center(Vector2i(5, 8)), cell_center(Vector2i(4, 8)))
	var path := route_cells(from_cell, goal_cell)
	var path_hits := false
	for cell in path:
		if _blocked(cell):
			path_hits = true
			print("PATH_BLOCKED ", cell)
	var clip := false
	for i in maxi(path.size() - 1, 0):
		var a: Vector2 = cell_center(path[i])
		var b: Vector2 = cell_center(path[i + 1])
		for s in 9:
			var p: Vector2 = a.lerp(b, float(s) / 8.0)
			var stepped: Vector2i = world_to_cell(p)
			if _blocked(stepped):
				clip = true
				print("CLIP ", path[i], "->", path[i + 1], " via ", stepped)
	print("MOVE_STEP into_house=", into, " out=", out, " tree=", into_tree, " rock=", into_rock, " path=", path, " hits=", path_hits, " clip=", clip)
	var walker: Villager = people[0]
	walker.visible = true
	walker.anchored = false
	walker.job = null
	walker.global_position = cell_center(from_cell)
	walker._path = path
	walker._path_i = 0
	walker._retarget = 40.0
	var entered := false
	var reached := false
	for _i in 420:
		await get_tree().process_frame
		var at := world_to_cell(walker.global_position)
		if _blocked(at):
			entered = true
			print("ENTERED ", at, " pos=", walker.global_position)
			break
		if at == goal_cell:
			reached = true
			break
	walker.anchored = true
	print("MOVE_WALK entered=", entered, " reached=", reached, " at=", world_to_cell(walker.global_position))
	var rock_cell := Vector2i(4, 8)
	var rock_pos := cell_center(rock_cell)
	var rock_tex: Texture2D = CatalogPaths.load_tex("village/rock.png")
	var rock := _actor_near(rock_pos)
	var rock_vol: IsoVolume = rock.get_iso_volume()
	for v in people:
		v.anchored = true
		v.visible = false
	var probe: Villager = people[1]
	probe.visible = true
	probe.global_position = IsoVolume.iso_to_world(_feet_iso(rock_vol, Vector2(0, -1)))
	camera.position = rock_pos
	camera.zoom = Vector2(1.45, 1.45)
	_cam_user = true
	await get_tree().process_frame
	await get_tree().process_frame
	var behind_z := probe.z_index
	var behind_rock_z := rock.z_index
	var with_behind := await _grab()
	await _capture("/opt/cursor/artifacts/depth-behind.png")
	probe.visible = false
	await get_tree().process_frame
	var rock_only := await _grab()
	var behind_ratio := _cover_ratio(rock_pos, rock_tex, with_behind, rock_only)
	probe.global_position = IsoVolume.iso_to_world(_feet_iso(rock_vol, Vector2(0, 1)))
	probe.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := probe.z_index
	var front_rock_z := rock.z_index
	await _capture("/opt/cursor/artifacts/depth-front.png")
	var depth_ok := behind_z < behind_rock_z and front_z > front_rock_z and behind_ratio < 0.08
	var house: Building = buildings[Vector2i(8, 14)]
	var house_vol: IsoVolume = house.get_iso_volume()
	var near_pt := IsoVolume.iso_to_world(_feet_iso(house_vol, Vector2(0, 1)))
	var far_pt := IsoVolume.iso_to_world(_feet_iso(house_vol, Vector2(0, -1)))
	var near_vol := IsoVolume.from_feet(near_pt)
	var far_vol := IsoVolume.from_feet(far_pt)
	var cmp_near := DepthSolver.is_behind(house_vol, near_vol) and not DepthSolver.is_behind(near_vol, house_vol)
	var cmp_far := DepthSolver.is_behind(far_vol, house_vol) and not DepthSolver.is_behind(house_vol, far_vol)
	probe.global_position = near_pt
	await get_tree().process_frame
	await get_tree().process_frame
	var near_front := probe.z_index > house.z_index
	probe.global_position = far_pt
	await get_tree().process_frame
	await get_tree().process_frame
	var far_behind := probe.z_index < house.z_index
	var tree_ok := cmp_near and cmp_far and near_front and far_behind
	print("DEPTH behind_z=", behind_z, " behind_rock=", behind_rock_z, " front_z=", front_z, " front_rock=", front_rock_z, " behind_ratio=", behind_ratio, " depth_ok=", depth_ok)
	print("CORNER cmp_near=", cmp_near, " cmp_far=", cmp_far, " near_front=", near_front, " far_behind=", far_behind, " corner_ok=", tree_ok)
	var person: Villager = people[0]
	for v in people:
		v.anchored = false
		v.visible = true
	var spear: Building = buildings[Vector2i(7, 12)]
	_assign(person, spear)
	for v in people:
		if v != person:
			v.anchored = true
			v.visible = false
	if Locale.code != "zh":
		Locale.set_code("zh")
	hud.open_building(spear)
	await get_tree().process_frame
	await get_tree().process_frame
	var hidden: bool = not person.visible and person.global_position.distance_to(spear.global_position) < 4.0
	camera.position = spear.global_position + Vector2(-30, 10)
	camera.zoom = Vector2(1.2, 1.2)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _ui_texts()
	var expect := Locale.text("villager.female" if person.sex == "f" else "villager.male")
	var count := Locale.format("panel.station_count", [1])
	var panel_ok := panel.contains(expect) and panel.contains(count) and not panel.contains(" / ")
	print("STAFF hidden=", hidden, " sex=", person.sex, " panel_ok=", panel_ok)
	print("STAFF_PANEL ", panel)
	await _capture("/opt/cursor/artifacts/staff-panel.png")
	var staff_btn := hud.find_child("StaffButton", true, false) as Button
	if staff_btn:
		_click_screen(staff_btn.get_global_rect().get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	var selected: bool = selected_villager == person
	print("STAFF_SELECT ", selected)
	var ok := (not into) and out and (not into_tree) and (not into_rock) and (not path_hits) and (not clip) and (not entered) and reached and depth_ok and tree_ok and hidden and panel_ok and selected
	print("MOVE_OK ", ok)
	get_tree().quit(0 if ok else 1)

func _pass_probe() -> void:
	await get_tree().process_frame
	var people := _alive_villagers()
	if people.size() < 2:
		print("PASS_OK false missing")
		get_tree().quit(1)
		return
	var mover: Villager = people[0]
	var other: Villager = people[1]
	for person in people:
		person.set_process(false)
		if person != mover and person != other:
			person.visible = false
			person.anchored = true
	var origin := cell_center(Vector2i(6, 15))
	mover.visible = true
	other.visible = true
	mover.job = null
	other.job = null
	mover.ordered = false
	other.ordered = false
	mover.global_position = origin
	other.global_position = origin + Vector2(12, 8)
	var other_start := other.global_position
	var overlapped := mover.get_iso_volume().overlaps(other.get_iso_volume())
	var step_through := can_step(mover.global_position, other.global_position, mover)
	var stand_on := _stand_ok(world_to_cell(other.global_position))
	var goal := Vector2i(9, 15)
	var ordered := mover.command_move(goal)
	var travelled := 0.0
	var max_jump := 0.0
	var prev := mover.global_position
	if ordered:
		for _i in 360:
			mover._process(1.0 / 60.0)
			_separate_walkers()
			_apply_iso_sort()
			var jump := mover.global_position.distance_to(prev)
			max_jump = maxf(max_jump, jump)
			travelled += jump
			prev = mover.global_position
			if not mover.ordered:
				break
	var arrived := world_to_cell(mover.global_position) == goal
	var other_held := other.global_position.distance_to(other_start) < 2.0
	var blocked_house := not can_step(cell_center(Vector2i(8, 15)), cell_center(Vector2i(8, 14)), mover)
	var blocked_tree := not can_step(cell_center(Vector2i(1, 5)), cell_center(Vector2i(0, 5)), mover)
	var blocked_rock := not can_step(cell_center(Vector2i(5, 8)), cell_center(Vector2i(4, 8)), mover)
	var zombie := Zombie.new()
	zombie.set_process(false)
	zombie.position = cell_center(Vector2i(6, 17))
	actors.add_child(zombie)
	var blocked_zombie := not can_step(cell_center(Vector2i(6, 18)), zombie.global_position, mover)
	var zombie_blocked := not can_step(zombie.global_position + Vector2(0, 90), mover.global_position, zombie)
	mover.global_position = origin
	other.global_position = origin + Vector2(6, 18)
	mover.visible = true
	other.visible = true
	var still_overlap := mover.get_iso_volume().overlaps(other.get_iso_volume())
	_apply_iso_sort()
	var depth_ok := other.z_index > mover.z_index
	var ok := overlapped and step_through and stand_on and ordered and arrived and other_held and travelled > 200.0 and max_jump < 48.0 and blocked_house and blocked_tree and blocked_rock and blocked_zombie and zombie_blocked and still_overlap and depth_ok
	print("PASS overlap=", overlapped, " step=", step_through, " stand=", stand_on, " arrived=", arrived, " held=", other_held, " travel=", travelled, " jump=", max_jump, " house=", blocked_house, " tree=", blocked_tree, " rock=", blocked_rock, " zombie=", blocked_zombie, " zombie_in=", zombie_blocked, " depth=", depth_ok, " z=", mover.z_index, other.z_index)
	print("PASS_OK ", ok)
	get_tree().quit(0 if ok else 1)

func _stack_probe() -> void:
	await get_tree().process_frame
	var people := _alive_villagers()
	if people.size() < 3:
		print("STACK_OK false missing")
		get_tree().quit(1)
		return
	var front: Villager = people[0]
	var back: Villager = people[1]
	var other: Villager = people[2]
	var park := 0
	for person in people:
		person.set_process(false)
		person.job = null
		person.ordered = false
		person.pending_job = null
		person.selected = false
		person.anchored = person != front and person != back and person != other
		person.visible = person == front or person == back or person == other
		if person != front and person != back and person != other:
			person.global_position = cell_center(Vector2i(2, 2 + park))
			park += 1
	selected_villager = null
	var failed := false
	if not _place_stack(front, back, Vector2i(6, 15)):
		print("STACK_OK false place")
		get_tree().quit(1)
		return
	var select_at := (_villager_pick_point(front) + _villager_pick_point(back)) * 0.5
	var select_hits := _villagers_hit(select_at)
	_left_click(select_at)
	var picked_front := selected_villager == front and front.selected and not back.selected
	if not picked_front or not select_hits.has(front) or not select_hits.has(back):
		failed = true
	var command_at := _stack_command_point(front)
	var command_cell := world_to_cell(command_at)
	var overlapped := front.get_iso_volume().overlaps(back.get_iso_volume())
	var back_at := back.global_position
	_left_click(command_at)
	var commanded := front.ordered and front.pending_job == null and selected_villager == front and world_to_cell(front.order_goal) == command_cell
	var still_piled := front.global_position.distance_to(back.global_position) < 30.0
	if command_at == Vector2.INF or not overlapped or not commanded or not still_piled:
		failed = true
	var goal_before := front.order_goal
	var path_before := front._path_i
	_left_click(cell_center(Vector2i(4, 8)))
	var blocked_kept := front.ordered and front.order_goal.distance_to(goal_before) < 1.0 and front._path_i == path_before
	if not blocked_kept or front.command_move(Vector2i(-1, -1)) or front.order_goal.distance_to(goal_before) > 1.0:
		failed = true
	var buildings_before := buildings.size()
	_right_click(cell_center(Vector2i(2, 12)))
	var cleared := selected_villager == null and not front.selected and front.ordered and front.guide_points().size() >= 2
	if not cleared or buildings.size() != buildings_before:
		failed = true
	other.global_position = cell_center(Vector2i(3, 17))
	other.visible = true
	other.anchored = true
	_left_click(_villager_pick_point(other))
	var switched := selected_villager == other and other.selected and not front.selected and front.ordered and front.guide_points().size() >= 2
	if not switched:
		failed = true
	var arrived := false
	var max_jump := 0.0
	var prev := front.global_position
	for _i in 360:
		front._process(1.0 / 60.0)
		_separate_walkers()
		var jump := front.global_position.distance_to(prev)
		max_jump = maxf(max_jump, jump)
		prev = front.global_position
		if not front.ordered:
			arrived = world_to_cell(front.global_position) == command_cell
			break
	var held := back.global_position.distance_to(back_at) < 2.0
	if not arrived or not held or max_jump > 48.0 or not front.guide_points().is_empty():
		failed = true
	var house: Building = buildings[Vector2i(8, 14)]
	front.global_position = cell_center(Vector2i(8, 16))
	front.job = null
	front.ordered = false
	front.pending_job = null
	var entered := false
	var enter_kept := false
	if front.command_enter(house):
		for _i in 8:
			front._process(1.0 / 60.0)
		_clear_villager_selection()
		enter_kept = front.ordered and front.pending_job == house and front.guide_points().size() >= 2 and selected_villager == null
		for _i in 400:
			front._process(1.0 / 60.0)
			if front.job == house and not front.visible:
				entered = true
				break
	if not enter_kept or not entered or not front.guide_points().is_empty():
		failed = true
	if not _place_stack(front, back, Vector2i(5, 17)):
		failed = true
	else:
		front.global_position = cell_center(Vector2i(5, 17))
		back.global_position = front.global_position
		_apply_iso_sort()
		_clear_villager_selection()
		_left_click(_villager_pick_point(front))
		var piled := selected_villager
		var same_spot := front.global_position.distance_to(back.global_position) < 1.0
		var far := Vector2i(5, 13)
		if not _stand_ok(far):
			far = Vector2i(4, 17)
		_left_click(cell_center(far))
		if piled == null or not piled.ordered or not same_spot or world_to_cell(piled.order_goal) != far:
			failed = true
		else:
			var cycle_goal := piled.order_goal
			# Click the feet. The body pick point sits 30px north and can land in the next cell.
			_left_click(piled.global_position)
			var cycled := selected_villager != null and selected_villager != piled and selected_villager.selected and piled.ordered and piled.order_goal.distance_to(cycle_goal) < 1.0
			if not cycled:
				failed = true
	var step_through := can_step(front.global_position, back.global_position, front)
	var blocked_house := not can_step(cell_center(Vector2i(8, 15)), cell_center(Vector2i(8, 14)), front)
	var blocked_tree := not can_step(cell_center(Vector2i(1, 5)), cell_center(Vector2i(0, 5)), front)
	var blocked_rock := not can_step(cell_center(Vector2i(5, 8)), cell_center(Vector2i(4, 8)), front)
	if not step_through or not blocked_house or not blocked_tree or not blocked_rock:
		failed = true
	front.ordered = false
	front.pending_job = null
	front.unit_id = "spearman"
	_clear_villager_selection()
	selected_villager = front
	front.selected = true
	_left_click(cell_center(Vector2i(5, 13)))
	var fighter_still := not front.ordered and front.guide_points().is_empty() and selected_villager == front
	front.unit_id = "villager"
	if not fighter_still:
		failed = true
	print("STACK pick=", picked_front, " command=", commanded, " cell=", command_cell, " kept=", blocked_kept, " clear=", cleared, " switch=", switched, " arrived=", arrived, " held=", held, " jump=", max_jump, " enter=", enter_kept, entered, " through=", step_through, " house=", blocked_house, " tree=", blocked_tree, " rock=", blocked_rock, " fighter=", fighter_still)
	print("STACK_OK ", not failed)
	get_tree().quit(0 if not failed else 1)

func _place_stack(front: Villager, back: Villager, home: Vector2i) -> bool:
	var center := cell_center(home)
	for unit in [front, back]:
		if unit.job != null and is_instance_valid(unit.job):
			unit.job.dismiss(unit)
		unit.job = null
		unit.visible = true
		unit.ordered = false
		unit.pending_job = null
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		front.global_position = center + dir * 48.0
		back.global_position = front.global_position + Vector2(0, -14)
		if world_to_cell(front.global_position) != home or world_to_cell(back.global_position) != home:
			continue
		if not front.get_iso_volume().overlaps(back.get_iso_volume()):
			continue
		_apply_iso_sort()
		if front.z_index <= back.z_index:
			continue
		if _stack_command_point(front) == Vector2.INF:
			continue
		return true
	return false

func _stack_command_point(person: Villager) -> Vector2:
	var origin := _villager_pick_point(person)
	var own := world_to_cell(person.global_position)
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1)]:
		for dist in [20.0, 28.0, 36.0, 44.0]:
			var spot: Vector2 = origin + dir * dist
			if spot.distance_to(origin) >= _villager_pick_radius():
				continue
			if world_to_cell(spot) == own or not _stand_ok(world_to_cell(spot)):
				continue
			if _villagers_hit(spot).has(person):
				return spot
	return Vector2.INF

func _unit_probe() -> void:
	await get_tree().process_frame
	if Locale.code != "zh":
		Locale.set_code("zh")
	var people := _alive_villagers()
	if people.is_empty():
		print("UNIT_OK false missing")
		get_tree().quit(1)
		return
	var walker: Villager = people[0]
	var park := 0
	for person in people:
		person.set_process(false)
		person.anchored = person != walker
		person.visible = true
		person.job = null
		if person == walker:
			continue
		person.global_position = cell_center(Vector2i(2, 2 + park))
		park += 1
	walker.global_position = cell_center(Vector2i(6, 15))
	var failed := false
	_clear_villager_selection()
	hud.close_panel()
	_left_click(_villager_pick_point(walker))
	var villager_text := hud.panel_text()
	var villager_ok := selected_villager == walker and walker.selected and hud.inspected_unit() == walker and hud.panel_visible() and villager_text.contains(Locale.text("unit.villager")) and villager_text.contains(Locale.text("unit.villager.intro")) and villager_text.contains(Locale.text("villager.female" if walker.sex == "f" else "villager.male"))
	if not villager_ok:
		failed = true
	camera.position = walker.global_position
	camera.zoom = Vector2(1.2, 1.2)
	_cam_user = true
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/unit-panel-villager.png")
	var spear_ok := _unit_card(walker, "spearman", "unit.spearman", "unit.spearman.intro")
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/unit-panel-spearman.png")
	var engineer_ok := _unit_card(walker, "engineer", "unit.engineer", "unit.engineer.intro")
	var gunner_ok := _unit_card(walker, "gunner", "unit.gunner", "unit.gunner.intro")
	if not spear_ok or not engineer_ok or not gunner_ok:
		failed = true
	var distinct := Locale.text("unit.villager.intro") != Locale.text("unit.spearman.intro") and Locale.text("unit.spearman.intro") != Locale.text("unit.engineer.intro") and Locale.text("unit.engineer.intro") != Locale.text("unit.gunner.intro")
	if not distinct:
		failed = true
	_show_unit(walker, "villager")
	var goal := Vector2i(6, 13)
	if not _stand_ok(goal):
		goal = Vector2i(5, 15)
	_left_click(cell_center(goal))
	var kept := walker.ordered and hud.panel_visible() and hud.inspected_unit() == walker and hud.panel_text().contains(Locale.text("unit.villager"))
	if not kept:
		failed = true
	walker.ordered = false
	walker.global_position = cell_center(Vector2i(2, 17))
	_clear_villager_selection()
	hud.close_panel()
	var house: Building = buildings[Vector2i(8, 14)]
	_left_click(house.global_position)
	var building_text := hud.panel_text()
	var building_ok := hud.inspected_building() == house and hud.inspected_unit() == null and hud.panel_visible() and building_text.contains(Locale.text("build.house")) and not building_text.contains(Locale.text("unit.villager.intro"))
	if not building_ok:
		failed = true
	walker.global_position = cell_center(Vector2i(6, 15))
	_show_unit(walker, "villager")
	_right_click(cell_center(Vector2i(2, 12)))
	var cleared := selected_villager == null and not walker.selected and not hud.panel_visible() and hud.inspected_unit() == null
	if not cleared:
		failed = true
	_left_click(_villager_pick_point(walker))
	var close := _button_labeled(Locale.text("panel.close"))
	if close == null:
		failed = true
	else:
		_click_screen(close.get_global_rect().get_center())
		await get_tree().process_frame
		await get_tree().process_frame
	var closed := selected_villager == null and not hud.panel_visible()
	if not closed:
		failed = true
	print("UNIT villager=", villager_ok, " spear=", spear_ok, " engineer=", engineer_ok, " gunner=", gunner_ok, " kept=", kept, " building=", building_ok, " clear=", cleared, " close=", closed)
	print("UNIT_OK ", not failed)
	get_tree().quit(0 if not failed else 1)

func _show_unit(person: Villager, id: String) -> void:
	var def := Balance.unit(id)
	var sex := person.sex
	person.configure(def)
	person.setup(Balance.skin_index("villager", str(def.get("skin", "wolf"))), sex, float(def.get("move_speed", 0.0)))
	person.global_position = cell_center(Vector2i(6, 15))
	_clear_villager_selection()
	hud.close_panel()
	_left_click(_villager_pick_point(person))

func _unit_card(person: Villager, id: String, name_key: String, intro_key: String) -> bool:
	_show_unit(person, id)
	var text := hud.panel_text()
	var skin := str(Balance.unit(id).get("skin", ""))
	var skin_ok := Balance.skin_index("villager", skin) == person._skin
	return selected_villager == person and hud.inspected_unit() == person and hud.panel_visible() and skin_ok and text.contains(Locale.text(name_key)) and text.contains(Locale.text(intro_key)) and not text.contains(Locale.text("unit.villager.intro"))

func _button_labeled(text: String) -> Button:
	for node in hud.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn != null and btn.visible and btn.text == text:
			return btn
	return null

func _order_probe() -> void:
	await get_tree().process_frame
	var people := _alive_villagers()
	var walker: Villager = null
	for person in people:
		if person.unit_id == "villager" and person.job == null:
			walker = person
			break
	if walker == null:
		print("ORDER_OK false missing")
		get_tree().quit(1)
		return
	var park := 0
	for person in people:
		person.set_process(false)
		if person == walker:
			continue
		person.visible = false
		person.anchored = true
		person.global_position = cell_center(Vector2i(2, 2 + park))
		park += 1
	var failed := false
	walker.unit_id = "spearman"
	walker.ordered = true
	walker.order_goal = walker.global_position + Vector2(40, 0)
	var fighter_clear := walker.guide_points().is_empty()
	walker.unit_id = "villager"
	walker.ordered = false
	if not fighter_clear:
		failed = true
	walker.visible = true
	walker.global_position = cell_center(Vector2i(7, 15))
	walker.job = null
	var grass := _sample_travel(walker, Vector2i(6, 15), Vector2i(8, 15), 45)
	var road := _sample_travel(walker, Vector2i(10, 6), Vector2i(10, 8), 45)
	if grass < 20.0 or road < grass * 1.4 or road > grass * 2.1:
		failed = true
	if not on_road(cell_center(Vector2i(10, 7))) or on_road(cell_center(Vector2i(6, 15))):
		failed = true
	walker.global_position = cell_center(Vector2i(7, 15))
	walker.job = null
	walker.ordered = false
	walker.pending_job = null
	var max_jump := 0.0
	var guide_move := false
	var guide_done := false
	var guide_pixels := false
	if not walker.command_move(Vector2i(5, 15)):
		failed = true
	else:
		guide_move = _guide_ends_at(walker, cell_center(Vector2i(5, 15))) and _guide_passes(walker, cell_center(Vector2i(6, 15)))
		guide_pixels = await _guide_shot(walker)
		var move_prev := walker.global_position
		for _i in 240:
			walker._process(1.0 / 60.0)
			var jump := walker.global_position.distance_to(move_prev)
			max_jump = maxf(max_jump, jump)
			move_prev = walker.global_position
			if not walker.ordered:
				break
		if max_jump > 48.0 or world_to_cell(walker.global_position) != Vector2i(5, 15):
			failed = true
		guide_done = walker.guide_points().is_empty()
	if not guide_move or not guide_done or not guide_pixels:
		failed = true
	var house: Building = buildings[Vector2i(8, 14)]
	walker.global_position = cell_center(Vector2i(8, 16))
	walker.job = null
	walker.ordered = false
	var door := front_of(house)
	var saw_walk := false
	var hidden_inside := false
	var enter_jump := 0.0
	var guide_door := false
	var guide_inside := false
	if not walker.command_enter(house):
		failed = true
	else:
		guide_door = _guide_ends_at(walker, door)
		var enter_prev := walker.global_position
		for _i in 400:
			var had := walker.job
			walker._process(1.0 / 60.0)
			var jump := walker.global_position.distance_to(enter_prev)
			if had == null and walker.job == null:
				if jump > 48.0:
					failed = true
				if walker.visible:
					saw_walk = true
			if walker.job == house and not walker.visible and walker.global_position.distance_to(house.global_position) < 4.0:
				enter_jump = jump
				hidden_inside = true
				break
			enter_prev = walker.global_position
		if not saw_walk or not hidden_inside or enter_jump > 180.0:
			failed = true
		if door.distance_to(house.global_position) < 24.0:
			failed = true
		guide_inside = walker.guide_points().is_empty()
	if not guide_door or not guide_inside:
		failed = true
	var spot := front_of(house)
	hud.open_building(house)
	_on_staff_dismissed(walker)
	var front_d := walker.global_position.distance_to(spot)
	var center_d := walker.global_position.distance_to(house.global_position)
	if front_d > 6.0 or center_d < 36.0 or not walker.visible or walker.job != null:
		failed = true
	_left_click(walker.global_position + Vector2(0, -30))
	var selected_ok := selected_villager == walker and walker.selected
	var dest := Vector2i(6, 16)
	if not _stand_ok(dest):
		dest = Vector2i(7, 16)
	_left_click(cell_center(dest))
	var order_ok := walker.ordered and walker.pending_job == null and selected_villager == walker
	var guide_retarget := _guide_ends_at(walker, cell_center(dest))
	if not selected_ok or not order_ok or not guide_retarget:
		failed = true
	var step_prev := walker.global_position
	walker._process(1.0 / 60.0)
	if walker.global_position.distance_to(step_prev) > 48.0:
		failed = true
	print("ORDER grass=", grass, " road=", road, " jump=", max_jump, " enter=", enter_jump, " front=", front_d, " center=", center_d, " door=", door, " selected=", selected_ok, " order=", order_ok, " hidden=", hidden_inside, " guide=", guide_move, guide_done, guide_pixels, guide_door, guide_inside, guide_retarget, " fighter=", fighter_clear)
	print("ORDER_OK ", not failed)
	get_tree().quit(0 if not failed else 1)

func _guide_passes(walker: Villager, spot: Vector2) -> bool:
	for point in walker.guide_points():
		if point.distance_to(spot) < 12.0:
			return true
	return false


func _guide_ends_at(walker: Villager, goal: Vector2) -> bool:
	var points := walker.guide_points()
	if points.size() < 2:
		return false
	return points[0].distance_to(walker.global_position) < 8.0 and points[points.size() - 1].distance_to(goal) < 8.0


func _guide_shot(walker: Villager) -> bool:
	var mid := (walker.global_position + walker.order_goal) * 0.5
	camera.position = mid
	camera.zoom = Vector2(1.55, 1.55)
	_cam_user = true
	_clamp_camera()
	await get_tree().process_frame
	await get_tree().process_frame
	var image := await _grab()
	if image == null:
		return false
	var path := "/opt/cursor/artifacts/order-guide.png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	var xform := get_viewport().get_canvas_transform()
	var color := walker.guide_color()
	var marker := _tint_near(image, xform * walker.order_goal, 40, color)
	var line_hits := 0
	for t in [0.2, 0.4, 0.6, 0.8]:
		var spot := walker.global_position.lerp(walker.order_goal, t)
		if _tint_near(image, xform * spot, 16, color):
			line_hits += 1
	print("GUIDE_SHOT marker=", marker, " line=", line_hits, " size=", image.get_width(), "x", image.get_height())
	return marker and line_hits >= 2


func _tint_near(image: Image, at: Vector2, radius: int, color: Color) -> bool:
	var hits := 0
	var x0 := int(at.x) - radius
	var y0 := int(at.y) - radius
	var x1 := int(at.x) + radius
	var y1 := int(at.y) + radius
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var pixel := image.get_pixel(x, y)
			var near := absf(pixel.r - color.r) + absf(pixel.g - color.g) + absf(pixel.b - color.b) < 0.72
			var bright := pixel.r > 0.85 and pixel.g > 0.85 and pixel.b > 0.85
			if near or bright:
				hits += 1
				if hits >= 6:
					return true
	return false


func _sample_travel(walker: Villager, start: Vector2i, goal: Vector2i, frames: int) -> float:
	walker.job = null
	walker.ordered = false
	walker.pending_job = null
	walker.stand_left = 0.0
	walker.global_position = cell_center(start)
	walker.visible = true
	if not _stand_ok(goal) or not walker.command_move(goal):
		return -1.0
	var dist := 0.0
	var prev := walker.global_position
	for _i in frames:
		if not walker.ordered:
			break
		walker._process(1.0 / 60.0)
		dist += walker.global_position.distance_to(prev)
		prev = walker.global_position
	return dist

func _actor_near(pos: Vector2) -> Node2D:
	for child in actors.get_children():
		if child is Node2D and (child as Node2D).global_position.distance_to(pos) < 2.0:
			return child
	return null

func _feet_iso(vol: IsoVolume, dir: Vector2) -> Vector2:
	var d := dir.normalized()
	var gap := 0.12
	return vol.bounds_center() + d * (vol.reach(d) + IsoVolume.walker_support(d) + gap)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _cover_ratio(origin: Vector2, tex: Texture2D, covered: Image, bare: Image) -> float:
	var img := tex.get_image()
	if img == null or covered == null or bare == null:
		return 1.0
	var changed := 0
	var opaque := 0
	var sprite_origin := origin + IsoVolume.ROCK_ANCHOR
	var xform := get_viewport().get_canvas_transform()
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			if img.get_pixel(x, y).a < 0.92:
				continue
			var screen: Vector2 = xform * (sprite_origin + Vector2(x, y))
			var sx := int(screen.x)
			var sy := int(screen.y)
			if sx < 0 or sy < 0 or sx >= covered.get_width() or sy >= covered.get_height():
				continue
			if sx >= bare.get_width() or sy >= bare.get_height():
				continue
			opaque += 1
			var ca := covered.get_pixel(sx, sy)
			var cb := bare.get_pixel(sx, sy)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.18:
				changed += 1
	if opaque == 0:
		return 1.0
	return float(changed) / float(opaque)

func _hint_text() -> String:
	var label := hud.find_child("HintLabel", true, false) as Label
	return label.text if label else ""

func _ui_texts() -> String:
	var parts: PackedStringArray = []
	_collect_ui_text(hud, parts)
	return " || ".join(parts)

func _collect_ui_text(node: Node, parts: PackedStringArray) -> void:
	if node.name != "LangButton" and node is Control:
		var control := node as Control
		if control.tooltip_text != "":
			parts.append(control.tooltip_text)
	if node.name != "LangButton" and node is Button and (node as Button).text != "":
		parts.append((node as Button).text)
	elif node is Label and (node as Label).text != "":
		parts.append((node as Label).text)
	for child in node.get_children():
		_collect_ui_text(child, parts)

func _has_cjk(value: String) -> bool:
	for i in value.length():
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false

func _opening_shot() -> void:
	await get_tree().create_timer(0.6).timeout
	await _capture(OS.get_environment("TD_SHOT_PATH") if OS.get_environment("TD_SHOT_PATH") != "" else "/tmp/shots/start.png")
	var focus := _center_half_focus()
	var view := get_viewport_rect().size
	var screen_focus: Vector2 = get_viewport().get_canvas_transform() * focus
	var phone := _is_phone()
	print("CAM_PHONE ", phone, " zoom=", camera.zoom.x, " pos=", camera.position, " focus=", focus, " screen=", screen_focus, " view=", view, " btns=", hud.zoom_buttons_visible())
	var near := camera.position.distance_to(focus) < 80.0
	var centered := screen_focus.distance_to(view * 0.5) < 90.0
	var z0 := camera.zoom.x
	var zin := hud.get_node_or_null("ZoomInButton") as Button
	if zin and zin.visible:
		_click_screen(zin.get_global_rect().get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	print("CAM_ZOOM_BTN ", z0, " -> ", camera.zoom.x, " user=", _cam_user)
	var zoomed := camera.zoom.x > z0 + 0.01
	if not phone and hud.zoom_buttons_visible() and near and centered and zoomed:
		get_tree().quit(0)
		return
	get_tree().quit(1)

func _char_shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for person in _alive_villagers():
		person.visible = false
	var idle := _make_villager(Vector2i(6, 8), "m", false)
	idle.anchored = true
	idle._set_frame(2, 0)
	var walking := _make_villager(Vector2i(8, 8), "f", false)
	walking.anchored = true
	walking._step_anim(Vector2.RIGHT, 0.2)
	walking._step_anim(Vector2.RIGHT, 0.2)
	walking._step_anim(Vector2.RIGHT, 0.2)
	camera.zoom = Vector2(2.2, 2.2)
	_cam_user = true
	camera.position = idle.global_position + Vector2(80, 10)
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/spine-villager-idle.png")
	camera.position = walking.global_position + Vector2(40, 10)
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/spine-villager-walk.png")
	var spear := Zombie.new()
	spear.position = cell_center(Vector2i(11, 8))
	spear.setup(20, 0.0, 1.05, 1, 0, 0, "normal", Color.WHITE, "spear")
	actors.add_child(spear)
	spear._face(Vector2.LEFT, 0.2, false)
	spear._face(Vector2.LEFT, 0.2, false)
	var gun := Zombie.new()
	gun.position = cell_center(Vector2i(13, 8))
	gun.setup(40, 0.0, 1.15, 1, 0, 0, "brute", Color.WHITE, "shooter")
	actors.add_child(gun)
	gun._face(Vector2.RIGHT, 0.2, true)
	gun._face(Vector2.RIGHT, 0.2, true)
	spear.process_mode = Node.PROCESS_MODE_DISABLED
	gun.process_mode = Node.PROCESS_MODE_DISABLED
	camera.zoom = Vector2(1.6, 1.6)
	camera.position = (spear.global_position + gun.global_position) * 0.5
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/spine-monsters.png")
	var behind := _make_villager(Vector2i(9, 15), "m", false)
	behind.anchored = true
	behind._set_frame(3, 1)
	var front := Zombie.new()
	front.position = cell_center(Vector2i(9, 17))
	front.setup(20, 0.0, 1.05, 1, 0, 0, "normal", Color.WHITE, "spear")
	actors.add_child(front)
	front._face(Vector2.LEFT, 0.16, false)
	front.process_mode = Node.PROCESS_MODE_DISABLED
	idle.visible = false
	walking.visible = false
	spear.visible = false
	gun.visible = false
	camera.zoom = Vector2(1.7, 1.7)
	camera.position = cell_center(Vector2i(9, 16))
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/spine-occlusion.png")
	get_tree().quit(0)

func _face_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var people := _alive_villagers()
	var spots: Array[Vector2i] = [Vector2i(5, 3), Vector2i(14, 3), Vector2i(8, 3), Vector2i(11, 8)]
	var dirs: Array[Vector2] = [
		Vector2(160, 0),
		Vector2(-160, 0),
		Vector2(0, 160),
		Vector2(0, -160),
	]
	var starts: Array[Vector2] = []
	for i in mini(people.size(), dirs.size()):
		var v: Villager = people[i]
		v.global_position = cell_center(spots[i])
		v.job = null
		v._path.clear()
		v._path_i = 0
		v._goal = v.global_position + dirs[i]
		v._retarget = 8.0
		starts.append(v.global_position)
		v._step_anim(dirs[i], 0.0)
		print("FACE_SET i=", i, " row=", v._facing, " goal_delta=", v._goal - v.global_position)
	_spawn_zombie("normal", true, cell_center(Vector2i(15, 4)))
	var zombies := get_tree().get_nodes_in_group("zombies")
	var zombie: Zombie = zombies[0]
	var z0 := zombie.global_position
	await get_tree().create_timer(0.5).timeout
	var ok := true
	for i in mini(people.size(), dirs.size()):
		var v: Villager = people[i]
		var expect := LpcFacing.row_for(dirs[i])
		var moved: Vector2 = v.global_position - starts[i]
		print("FACE_V i=", i, " expect=", expect, " got=", v._facing, " frame=", v._frame, " steps=", v._steps, " moved=", moved)
		# A 6-frame run cycle wraps back to frame 0 inside this wait. Steps
		# prove the walk loop kept running. Facing still has to match.
		if v._facing != expect or v._steps < 8:
			ok = false
	var zdelta: Vector2 = zombie.global_position - z0
	var zexpect := LpcFacing.row_for(zdelta)
	print("FACE_Z vel=", zdelta, " expect=", zexpect, " got=", zombie._facing, " frame=", zombie._frame_i)
	if zdelta.length() < 8.0 or zombie._facing != zexpect:
		ok = false
	# The walk loop feeds a unit vector. Force the south row, then aim north,
	# and require the row to follow that step without a pre-seeded long vector.
	var turn: Villager = people[0]
	turn._set_frame(2, 0)
	turn._path.clear()
	turn._path_i = 0
	turn.global_position = cell_center(Vector2i(10, 6))
	turn._goal = turn.global_position + Vector2(0, -220)
	turn._retarget = 8.0
	var turn0 := turn.global_position
	var turn_steps := turn._steps
	await get_tree().create_timer(0.35).timeout
	var turn_moved: Vector2 = turn.global_position - turn0
	var turn_expect := 0
	print("FACE_TURN moved=", turn_moved, " expect=", turn_expect, " got=", turn._facing, " frame=", turn._frame, " steps=", turn._steps)
	if turn_moved.y >= -4.0 or turn._facing != turn_expect or turn._steps <= turn_steps:
		ok = false
	print("FACE_OK ", ok)
	camera.zoom = Vector2(1.8, 1.8)
	camera.position = people[2].global_position + Vector2(40, -20)
	_cam_user = true
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/facing-walk.png")
	camera.position = turn.global_position
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/facing-north.png")
	get_tree().quit(0 if ok else 1)

func _demo_shot() -> void:
	await get_tree().create_timer(2.4).timeout
	await _capture(OS.get_environment("TD_SHOT_PATH") if OS.get_environment("TD_SHOT_PATH") != "" else "/tmp/shots/combat.png")
	get_tree().quit(0)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("SHOT", path, " err=", err, " ", image.get_width(), "x", image.get_height())
