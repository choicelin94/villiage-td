extends Node2D

const COLS := 20
const ROWS := 20
const TILE := Vector2i(176, 98)
const SPRITE_OFF := Vector2(-127.5, -134.0)
const HEART := Vector2i(10, 14)
const SPAWNS: Array[Vector2i] = [
	Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0)
]
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const START_WOOD := 100
const START_GOLD := 70
const WALL_CAP := 28
const HOUSE_BEDS := 4
const TOTAL_WAVES := 10
const ZOMBIE_SPEED := 72.0
const VILLAGER_SPEED := 108.0
const CLAIM_TIME := 6.5
const REFUGEES_PER_WAVE := 2
const INFECT_RADIUS := 38.0

const WAVES: Array[Dictionary] = [
	{"n": 5, "hp": 34, "speed": 72.0, "gap": 0.9, "fast": 0, "brute": 0, "boss": 0},
	{"n": 7, "hp": 44, "speed": 74.0, "gap": 0.78, "fast": 2, "brute": 0, "boss": 0},
	{"n": 8, "hp": 54, "speed": 74.0, "gap": 0.7, "fast": 2, "brute": 1, "boss": 0},
	{"n": 8, "hp": 66, "speed": 76.0, "gap": 0.64, "fast": 3, "brute": 1, "boss": 0},
	{"n": 9, "hp": 78, "speed": 76.0, "gap": 0.58, "fast": 3, "brute": 2, "boss": 0},
	{"n": 9, "hp": 90, "speed": 78.0, "gap": 0.54, "fast": 3, "brute": 2, "boss": 0},
	{"n": 10, "hp": 102, "speed": 78.0, "gap": 0.5, "fast": 4, "brute": 2, "boss": 0},
	{"n": 10, "hp": 114, "speed": 78.0, "gap": 0.48, "fast": 4, "brute": 3, "boss": 0},
	{"n": 11, "hp": 126, "speed": 80.0, "gap": 0.46, "fast": 4, "brute": 3, "boss": 0},
	{"n": 8, "hp": 130, "speed": 76.0, "gap": 0.5, "fast": 3, "brute": 2, "boss": 1},
]

const KIND_MOD := {
	"normal": {"hp": 1.0, "speed": 1.0, "scale": 1.05, "dmg": 1, "wood": 2, "gold": 4, "mod": Color(1, 1, 1)},
	"fast": {"hp": 0.7, "speed": 1.35, "scale": 0.95, "dmg": 1, "wood": 1, "gold": 5, "mod": Color(0.82, 1, 0.78)},
	"brute": {"hp": 2.2, "speed": 0.7, "scale": 1.3, "dmg": 2, "wood": 3, "gold": 9, "mod": Color(0.72, 0.86, 0.68)},
	"boss": {"hp": 4.2, "speed": 0.6, "scale": 1.6, "dmg": 3, "wood": 8, "gold": 30, "mod": Color(0.62, 0.82, 0.55)},
}

const MALE_TEX := [
	"res://assets/people/man_brown.png",
	"res://assets/people/man_old.png",
	"res://assets/people/man_blue.png",
]
const FEMALE_TEX := "res://assets/people/woman.png"

var wood := START_WOOD
var gold := START_GOLD
var core_pos := Vector2.ZERO
var phase := "prep"
var wave_number := 0
var inspected: Building = null
var selected_villager: Villager = null

var ground: TileMapLayer
var actors: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Hud
var font: Font

var buildings := {}
var scenery := {}
var spawn_queue: Array[String] = []
var spawn_cd := 0.0
var spawn_gap := 0.8
var spawn_cursor := 0
var _selftest := false
var _selftest_t0 := 0
var _male_i := 0
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
	Engine.max_fps = 60
	add_to_group("game")
	font = load("res://assets/fonts/NotoSansSC-Regular.otf")
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
	get_viewport().size_changed.connect(_on_viewport_resized)
	_sync_pixels()
	_apply_fit_zoom(true)
	if hud:
		hud._layout()
	_refresh_beds()
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
	elif OS.get_environment("TD_LANG") == "1":
		_lang_shot()
	elif OS.get_environment("TD_SHOT") == "1":
		_opening_shot()

func _process(delta: float) -> void:
	_refresh_beds()
	_infect_contacts()
	_update_ghost()
	if phase == "combat":
		_tick_spawns(delta)
	if _selftest and Time.get_ticks_msec() - _selftest_t0 > 180000:
		print("SELFTEST_TIMEOUT people=", _alive_villagers().size(), " wave=", wave_number)
		get_tree().quit(1)

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
	ground.z_index = -1
	ground.y_sort_enabled = true
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = TILE
	var files := [
		"res://assets/village/grass_a.png",
		"res://assets/village/grass_b.png",
		"res://assets/village/road.png",
	]
	for i in files.size():
		var atlas := TileSetAtlasSource.new()
		var tex: Texture2D = load(files[i])
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		atlas.create_tile(Vector2i.ZERO)
		var data := atlas.get_tile_data(Vector2i.ZERO, 0)
		data.texture_origin = Vector2i(0, -6)
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
	for rock_cell in [Vector2i(4, 8), Vector2i(16, 8), Vector2i(4, 16), Vector2i(16, 16)]:
		scenery[rock_cell] = true
	var trail := {}
	for spawn in SPAWNS:
		for cell in _astar(spawn, HEART).path:
			trail[cell] = true
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var source := (x + y) % 2
			if trail.has(cell) and not scenery.has(cell):
				source = 2
			ground.set_cell(cell, source, Vector2i.ZERO)
	for rock_cell in [Vector2i(4, 8), Vector2i(16, 8), Vector2i(4, 16), Vector2i(16, 16)]:
		_place_prop(rock_cell, load("res://assets/village/rock.png"))
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if not scenery.has(cell) or _is_spawn(cell):
				continue
			if not _is_border(cell):
				continue
			var trees := [
				"res://assets/village/tree.png",
				"res://assets/village/tree_b.png",
				"res://assets/village/tree_c.png",
			]
			_place_prop(cell, load(trees[(x + y) % trees.size()]))

func _place_starter() -> void:
	var plan := [
		[Building.Kind.HOUSE, Vector2i(8, 14)],
		[Building.Kind.HOUSE, Vector2i(12, 14)],
		[Building.Kind.FARM, Vector2i(9, 16)],
		[Building.Kind.WORKSHOP, Vector2i(11, 16)],
		[Building.Kind.SPEAR, Vector2i(7, 12)],
		[Building.Kind.SPEAR, Vector2i(13, 12)],
		[Building.Kind.FIRE, Vector2i(10, 12)],
		[Building.Kind.WALL, Vector2i(6, 11)],
		[Building.Kind.WALL, Vector2i(8, 11)],
		[Building.Kind.WALL, Vector2i(12, 11)],
		[Building.Kind.WALL, Vector2i(14, 11)],
		[Building.Kind.WALL, Vector2i(9, 10)],
		[Building.Kind.WALL, Vector2i(11, 10)],
	]
	for item in plan:
		_place_free(int(item[0]), item[1])

func _spawn_starter_people() -> void:
	var spots: Array[Vector2i] = [
		Vector2i(9, 15), Vector2i(10, 15), Vector2i(11, 15), Vector2i(8, 15), Vector2i(12, 15)
	]
	var sexes := ["m", "f", "m", "f", "m"]
	for i in spots.size():
		_make_villager(spots[i], sexes[i], false)

func _make_villager(cell: Vector2i, sex: String, as_refugee: bool) -> Villager:
	var v := Villager.new()
	v.position = cell_center(cell)
	var tex_path := FEMALE_TEX
	if sex == "m":
		tex_path = MALE_TEX[_male_i % MALE_TEX.size()]
		_male_i += 1
	v.setup(load(tex_path), sex, VILLAGER_SPEED)
	v.refugee = as_refugee
	v.claim_left = CLAIM_TIME if as_refugee else -1.0
	actors.add_child(v)
	return v

func _place_prop(cell: Vector2i, tex: Texture2D) -> void:
	var node := Node2D.new()
	node.position = cell_center(cell)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = SPRITE_OFF
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
	var best := SPAWNS[0]
	var best_d := INF
	for cell in SPAWNS:
		var d := world.distance_squared_to(cell_center(cell))
		if d < best_d:
			best_d = d
			best = cell
	return best

func walkable(world: Vector2) -> bool:
	var cell := world_to_cell(world)
	return in_bounds(cell) and not _blocked(cell)

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
		if building.kind == Building.Kind.HOUSE and building.has_staff():
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

func damage_cell(cell: Vector2i, amount: int) -> void:
	if phase == "win" or phase == "lose":
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
		for z in _living_zombies():
			if z.global_position.distance_to(at) <= splash:
				z.hurt(damage)
	else:
		fx.add_child(_burst(at, 14.0, Color(0.95, 0.9, 0.7)))
		if is_instance_valid(target) and target is Zombie and not (target as Zombie).dying:
			(target as Zombie).hurt(damage)
		else:
			var nearest: Zombie = null
			var best := 26.0
			for z in _living_zombies():
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
	_popup(z.global_position, Locale.format("popup.gold", [z.reward_gold]), Color(1, 0.86, 0.3))
	_refresh_hud()

func tower_bonus() -> float:
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.WORKSHOP and building.has_staff():
			return 1.25
	return 1.0

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
	hud.flash(Locale.format("flash.wave_in", [wave_number]))
	_refresh_hud()

func _compose_wave(spec: Dictionary) -> Array[String]:
	var list: Array[String] = []
	for _i in int(spec.n):
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
			_spawn_zombie(spawn_queue.pop_front(), false, Vector2.ZERO)
			spawn_cd = spawn_gap
	elif _living_zombies().is_empty():
		_on_wave_cleared()

func _spawn_zombie(kind: String, turned: bool, at: Vector2) -> void:
	var spec: Dictionary = WAVES[maxi(wave_number, 1) - 1]
	var mod: Dictionary = KIND_MOD[kind]
	var z := Zombie.new()
	if turned:
		z.position = at
		z.mark_fresh()
	else:
		var cell := SPAWNS[spawn_cursor % SPAWNS.size()]
		spawn_cursor += 1
		z.position = cell_center(cell)
	var hp := maxi(int(round(float(spec.hp) * float(mod.hp))), 1)
	if turned:
		hp = maxi(int(hp * 0.65), 12)
	z.setup(hp, float(spec.speed) * float(mod.speed), float(mod.scale), int(mod.dmg), int(mod.wood), int(mod.gold), kind, mod.mod)
	actors.add_child(z)

func _on_wave_cleared() -> void:
	if phase != "combat":
		return
	var farms := _staffed_count(Building.Kind.FARM)
	wood += 8 + farms * 6
	gold += 14
	if wave_number >= TOTAL_WAVES:
		_finish(true)
		return
	phase = "prep"
	_spawn_refugees()
	hud.flash(Locale.format("flash.wave_clear", [wave_number, CLAIM_TIME]))
	_refresh_hud()
	if _selftest:
		_try_start_wave()

func _spawn_refugees() -> void:
	var spots: Array[Vector2i] = [Vector2i(10, 17), Vector2i(9, 17), Vector2i(11, 17), Vector2i(8, 17)]
	var made := 0
	for cell in spots:
		if made >= REFUGEES_PER_WAVE:
			break
		if _blocked(cell):
			continue
		var sex := "f" if made % 2 == 0 else "m"
		_make_villager(cell, sex, true)
		made += 1

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
	var person := _villager_at(world)
	if selected_villager != null and is_instance_valid(selected_villager) and building != null:
		hud.close_panel()
		_assign(selected_villager, building)
		return
	if person != null:
		hud.close_panel()
		_clear_villager_selection()
		selected_villager = person
		person.selected = true
		inspected = null
		hud.flash(Locale.text("flash.assign_next"))
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

func _on_sell_requested() -> void:
	var building := hud.inspected_building()
	if building == null or not is_instance_valid(building):
		hud.close_panel()
		return
	_remove_building(building.cell, true)
	hud.close_panel()

func _assign(v: Villager, building: Building) -> void:
	if v.infected or v.leaving:
		return
	if not building.is_functional():
		hud.flash(Locale.text("flash.wall_no_staff"))
		return
	if building.staff != null and is_instance_valid(building.staff) and building.staff != v:
		var old := building.staff as Villager
		if old:
			old.job = null
		building.staff = null
	if v.job != null and is_instance_valid(v.job) and v.job != building:
		if v.job.staff == v:
			v.job.staff = null
		v.job = null
	building.staff = v
	v.job = building
	v.refugee = false
	v.claim_left = -1.0
	_clear_villager_selection()
	_popup(building.global_position + Vector2(0, -80), Locale.text("popup.assigned"), Color(0.7, 0.95, 1))
	_refresh_beds()
	_refresh_hud()

func _try_place(kind: int, cell: Vector2i) -> bool:
	var reason := _block_reason(cell)
	if reason != "":
		hud.flash(reason)
		return false
	var stats: Dictionary = Building.STATS[kind]
	if kind == Building.Kind.WALL and _count_kind(Building.Kind.WALL) >= WALL_CAP:
		hud.flash(Locale.format("flash.wall_cap", [WALL_CAP]))
		return false
	if wood < int(stats.wood) or gold < int(stats.gold):
		hud.flash(Locale.text("flash.need_res"))
		return false
	wood -= int(stats.wood)
	gold -= int(stats.gold)
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
	_notify_zombies()

func _remove_building(cell: Vector2i, refund: bool) -> void:
	if not buildings.has(cell):
		return
	var building: Building = buildings[cell]
	var person: Villager = building.staff as Villager
	building.staff = null
	if person != null and is_instance_valid(person):
		person.job = null
	if refund:
		var stats: Dictionary = Building.STATS[building.kind]
		var rw := int(stats.wood) / 2
		var rg := int(stats.gold) / 2
		wood += rw
		gold += rg
		_popup(building.global_position, Locale.format("popup.sold", [rw, rg]), Color(0.85, 0.95, 0.7))
	buildings.erase(cell)
	if inspected == building:
		inspected = null
	building.queue_free()
	_notify_zombies()
	_refresh_hud()
	if not refund and person != null and is_instance_valid(person):
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
	if v.job != null and is_instance_valid(v.job) and v.job.staff == v:
		v.job.staff = null
	v.job = null
	if selected_villager == v:
		selected_villager = null
	var at := v.global_position
	v.queue_free()
	_popup(at + Vector2(0, -30), Locale.text("popup.infected"), Color(0.65, 1, 0.45))
	_spawn_zombie("normal", true, at)
	if _alive_villagers().is_empty():
		_finish(false)

func _refresh_beds() -> void:
	var beds := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.HOUSE and building.has_staff():
			beds += HOUSE_BEDS
	var people := _alive_villagers()
	for v in people:
		v.housed = false
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind != Building.Kind.HOUSE or not building.has_staff():
			continue
		var staff := building.staff as Villager
		if staff and not staff.infected:
			staff.housed = true
			beds -= 1
	var pool: Array[Villager] = []
	for v in people:
		if v.housed or v.job != null:
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
		if v != null and not v.infected and not v.leaving:
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

func _villager_at(world: Vector2) -> Villager:
	var best: Villager = null
	var zoom_v := camera.zoom.x if camera else 1.0
	var best_d := maxf(48.0, 34.0 / maxf(zoom_v, 0.05))
	best_d = minf(best_d, 96.0)
	for v in _alive_villagers():
		var d := world.distance_to(v.global_position + Vector2(0, -30))
		if d < best_d:
			best_d = d
			best = v
	return best

func _clear_villager_selection() -> void:
	if selected_villager != null and is_instance_valid(selected_villager):
		selected_villager.selected = false
	selected_villager = null

func _update_ghost() -> void:
	var ghost := fx.get_node_or_null("Ghost") as Node2D
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
		fx.add_child(ghost)
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
	if phase == "prep" and wave_number > 0 and wave_number < TOTAL_WAVES:
		shown = wave_number + 1
	elif phase == "win":
		shown = TOTAL_WAVES
	var label := "%d/%d" % [shown, TOTAL_WAVES]
	var claim := 0.0
	for v in _alive_villagers():
		if v.refugee and v.claim_left > claim:
			claim = v.claim_left
	var housed := 0
	for v in _alive_villagers():
		if v.housed:
			housed += 1
	hud.refresh(wood, gold, _alive_villagers().size(), housed, _bed_cap(), _count_kind(Building.Kind.WALL), WALL_CAP, label, phase, claim)

func _bed_cap() -> int:
	var n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == Building.Kind.HOUSE and building.has_staff():
			n += HOUSE_BEDS
	return n

func _staffed_count(kind: int) -> int:
	var n := 0
	for cell in buildings:
		var building: Building = buildings[cell]
		if building.kind == kind and building.has_staff():
			n += 1
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
	return cell in SPAWNS

func _blocked(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	if scenery.has(cell) or buildings.has(cell):
		return true
	return false

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
			if _count_kind(Building.Kind.WALL) >= WALL_CAP:
				break
			_try_place(Building.Kind.WALL, cell)
	var route: Dictionary = route_from(SPAWNS[2])
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
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOW_ASSIGNED ", spear.has_staff() and spear.staff == people[0])
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

func _face_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var people := _alive_villagers()
	var spots: Array[Vector2i] = [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 6), Vector2i(7, 7)]
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
		print("FACE_V i=", i, " expect=", expect, " got=", v._facing, " frame=", v._frame, " moved=", moved, " goal_left=", v._goal - v.global_position, " retarget=", v._retarget)
		if v._facing != expect or v._frame == 0:
			ok = false
	var zdelta: Vector2 = zombie.global_position - z0
	var zexpect := LpcFacing.row_for(zdelta)
	print("FACE_Z vel=", zdelta, " expect=", zexpect, " got=", zombie._facing, " frame=", zombie._frame_i)
	if zdelta.length() < 8.0 or zombie._facing != zexpect:
		ok = false
	print("FACE_OK ", ok)
	camera.zoom = Vector2(1.8, 1.8)
	camera.position = people[2].global_position + Vector2(40, -20)
	_cam_user = true
	await get_tree().process_frame
	await _capture("/opt/cursor/artifacts/facing-walk.png")
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
