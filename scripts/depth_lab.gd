extends Node2D

const TILE := Vector2i(128, 128)
const COLS := 9
const ROWS := 9
const HOUSE_CELL := Vector2i(4, 4)
const TREE_CELL := Vector2i(2, 3)
const TREE2_CELL := Vector2i(2, 4)
const ROCK_CELL := Vector2i(6, 3)
const WALL_CELL := Vector2i(6, 5)
const FARM_CELL := Vector2i(7, 6)

var ground: TileMapLayer
var house: Building
var wall: Building
var farm: Building
var tree: Node2D
var tree2: Node2D
var rock: Node2D
var _crowd: Array[Villager] = []
var player: Villager
var near_one: Villager
var far_one: Villager
var camera: Camera2D
var _font: Font
var _hint: Label
var _title: Label
var _buttons: Array[Button] = []
var _index := 0
var _scenarios: Array[Dictionary] = []
var _blocked := {}
var _auto := false

func _ready() -> void:
	process_priority = 50
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	_auto = OS.get_environment("TD_LAB") == "1"
	_build_ground()
	_build_props()
	_build_people()
	_build_camera()
	_build_guides()
	_build_ui()
	_build_scenarios()
	Locale.changed.connect(_refresh_copy)
	_show_scenario(0)
	if _auto:
		_auto_check()

func _process(delta: float) -> void:
	if not _auto:
		_steer(delta)
	_apply_sort()

func _unhandled_input(event: InputEvent) -> void:
	if _auto or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_8:
		_show_scenario(key.keycode - KEY_1)
	elif key.keycode == KEY_BRACKETLEFT:
		_show_scenario(posmod(_index - 1, _scenarios.size()))
	elif key.keycode == KEY_BRACKETRIGHT:
		_show_scenario(posmod(_index + 1, _scenarios.size()))
	elif key.keycode == KEY_ESCAPE:
		_back_to_game()

func _steer(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var step := dir * 150.0 * delta
	var nxt: Vector2 = player.global_position + step
	if _can_step(player.global_position, nxt):
		player.global_position = nxt
		player._step_anim(dir, delta)
	camera.position = player.global_position

func _apply_sort() -> void:
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

func _build_ground() -> void:
	ground = TileMapLayer.new()
	ground.z_index = -4096
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_size = TILE
	var atlas := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/village/grass_a.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
	atlas.create_tile(Vector2i.ZERO)
	tileset.add_source(atlas, 0)
	ground.tile_set = tileset
	add_child(ground)
	for y in ROWS:
		for x in COLS:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	_blocked[HOUSE_CELL] = true
	_blocked[TREE_CELL] = true
	_blocked[TREE2_CELL] = true
	_blocked[ROCK_CELL] = true
	_blocked[WALL_CELL] = true
	_blocked[FARM_CELL] = true

func _build_props() -> void:
	house = Building.new()
	house.position = _cell_center(HOUSE_CELL)
	house.setup(Building.Kind.HOUSE, HOUSE_CELL)
	house.name = "House"
	add_child(house)
	wall = Building.new()
	wall.position = _cell_center(WALL_CELL)
	wall.setup(Building.Kind.WALL, WALL_CELL)
	wall.name = "Wall"
	add_child(wall)
	farm = Building.new()
	farm.position = _cell_center(FARM_CELL)
	farm.setup(Building.Kind.FARM, FARM_CELL)
	farm.name = "Farm"
	add_child(farm)
	tree = _prop(TREE_CELL, "res://assets/village/tree.png", "tree")
	tree.name = "Tree"
	tree2 = _prop(TREE2_CELL, "res://assets/village/tree_b.png", "tree")
	tree2.name = "TreeB"
	rock = _prop(ROCK_CELL, "res://assets/village/rock.png", "rock")
	rock.name = "Rock"

func _prop(cell: Vector2i, path: String, key: String) -> Node2D:
	var node := Node2D.new()
	node.position = _cell_center(cell)
	node.set_script(load("res://scripts/iso_prop.gd"))
	node.cell = cell
	node.volume_key = key
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(path)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = IsoVolume.ROCK_ANCHOR if key == "rock" else IsoVolume.TREE_ANCHOR
	sprite.z_as_relative = true
	node.add_child(sprite)
	add_child(node)
	return node

func _build_people() -> void:
	var tex: Texture2D = load("res://assets/people/man_brown.png")
	player = _person(tex, _cell_center(HOUSE_CELL) + Vector2(0, 90))
	near_one = _person(load("res://assets/people/woman.png"), Vector2.ZERO)
	far_one = _person(load("res://assets/people/man_blue.png"), Vector2.ZERO)
	near_one.visible = false
	far_one.visible = false

func _person(tex: Texture2D, at: Vector2) -> Villager:
	var v := Villager.new()
	v.position = at
	v.setup(tex, "m", 108.0)
	v.anchored = true
	add_child(v)
	return v

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(1.55, 1.55)
	camera.position = _cell_center(HOUSE_CELL)
	add_child(camera)
	camera.make_current()

func _build_guides() -> void:
	_mark_line(house, Color(1, 0.86, 0.25, 0.95))
	_mark_line(wall, Color(0.95, 0.75, 0.35, 0.9))
	_mark_line(farm, Color(0.95, 0.72, 0.35, 0.95))
	_mark_line(tree, Color(0.45, 0.9, 0.45, 0.9))
	_mark_line(tree2, Color(0.35, 0.75, 0.4, 0.9))
	_mark_line(rock, Color(0.75, 0.8, 0.85, 0.9))
	_mark_dot(player, Color(0.4, 0.75, 1))
	_mark_dot(near_one, Color(0.4, 0.9, 0.5))
	_mark_dot(far_one, Color(1, 0.45, 0.4))
	_mark_tag(player, "lab.tag_you")
	_mark_tag(near_one, "lab.tag_near")
	_mark_tag(far_one, "lab.tag_far")

func _mark_line(node: Node2D, color: Color) -> void:
	var mark := IsoMark.new()
	mark.kind = IsoMark.Kind.LINE
	mark.color = color
	mark.source = node
	node.add_child(mark)

func _mark_dot(person: Villager, color: Color) -> void:
	var mark := IsoMark.new()
	mark.kind = IsoMark.Kind.DOT
	mark.color = color
	mark.source = person
	person.add_child(mark)

func _mark_tag(person: Villager, key: String) -> void:
	var mark := IsoMark.new()
	mark.kind = IsoMark.Kind.TAG
	mark.text_key = key
	mark.position = Vector2(-18, -132)
	person.add_child(mark)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	theme.set_font("font", "Label", _font)
	theme.set_font("font", "Button", _font)
	var top := Panel.new()
	top.theme = theme
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 228
	top.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	layer.add_child(top)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 8
	box.offset_right = -12
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 6)
	top.add_child(box)
	_title = Label.new()
	_title.theme = theme
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	box.add_child(_title)
	_hint = Label.new()
	_hint.theme = theme
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	box.add_child(_hint)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	for i in 12:
		var btn := Button.new()
		btn.theme = theme
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(92, 36)
		btn.add_theme_font_size_override("font_size", 14)
		_style_button(btn)
		var idx := i
		btn.pressed.connect(func() -> void: _show_scenario(idx))
		flow.add_child(btn)
		_buttons.append(btn)
	var back := Button.new()
	back.name = "BackButton"
	back.theme = theme
	back.focus_mode = Control.FOCUS_NONE
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 12
	back.offset_top = -64
	back.offset_right = 180
	back.offset_bottom = -16
	back.add_theme_font_size_override("font_size", 16)
	_style_button(back)
	back.pressed.connect(_back_to_game)
	layer.add_child(back)
	back.text = Locale.text("lab.back")
	var lang := Button.new()
	lang.name = "LangButton"
	lang.theme = theme
	lang.focus_mode = Control.FOCUS_NONE
	lang.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang.offset_left = -88
	lang.offset_top = 236
	lang.offset_right = -12
	lang.offset_bottom = 276
	lang.add_theme_font_size_override("font_size", 16)
	_style_button(lang)
	lang.pressed.connect(func() -> void: Locale.toggle())
	layer.add_child(lang)
	lang.text = Locale.text("lang.switch")

func _build_scenarios() -> void:
	var tree_vol: IsoVolume = tree.get_iso_volume()
	var rock_vol: IsoVolume = rock.get_iso_volume()
	var house_vol: IsoVolume = house.get_iso_volume()
	var wall_vol: IsoVolume = wall.get_iso_volume()
	var north_tree := _world_feet(tree_vol, Vector2(0, -1))
	var east_tree := _world_feet(tree_vol, Vector2(1, 0))
	var north_rock := _world_feet(rock_vol, Vector2(0, -1))
	var south_house := _world_feet(house_vol, Vector2(0, 1))
	var north_wall := _world_feet(wall_vol, Vector2(0, -1))
	var pair_far := IsoVolume.iso_to_world(Vector2(4.2, 6.2))
	var pair_near := IsoVolume.iso_to_world(Vector2(4.5, 7.1))
	var farm_vol: IsoVolume = farm.get_iso_volume()
	var south_farm := _world_feet(farm_vol, Vector2(0, 1))
	var trunk_east := _press_feet(tree_vol, Vector2(1, 0))
	var wall_corner := _corner_feet(wall_vol)
	_scenarios = [
		{"btn": "lab.btn_l1", "title": "lab.l1", "expect": "lab.expect_l1", "pos": north_tree, "focus": tree.global_position, "crowd": false},
		{"btn": "lab.btn_l2", "title": "lab.l2", "expect": "lab.expect_l2", "pos": east_tree, "focus": tree.global_position, "crowd": false},
		{"btn": "lab.btn_l3", "title": "lab.l3", "expect": "lab.expect_l3", "pos": north_rock, "focus": rock.global_position, "crowd": false},
		{"btn": "lab.btn_l4", "title": "lab.l4", "expect": "lab.expect_l4", "pos": south_house, "focus": house.global_position, "crowd": false},
		{"btn": "lab.btn_l5", "title": "lab.l5", "expect": "lab.expect_l5", "pos": _world_feet(tree_vol, Vector2(0, 1)), "focus": tree.global_position, "crowd": false},
		{"btn": "lab.btn_l6", "title": "lab.l6", "expect": "lab.expect_l6", "pos": south_house, "focus": house.global_position, "crowd": false},
		{"btn": "lab.btn_l7", "title": "lab.l7", "expect": "lab.expect_l7", "pos": north_wall, "focus": wall.global_position, "crowd": false},
		{"btn": "lab.btn_l8", "title": "lab.l8", "expect": "lab.expect_l8", "pos": pair_near, "focus": (pair_near + pair_far) * 0.5, "crowd": true, "near": pair_far},
		{"btn": "lab.btn_l9", "title": "lab.l9", "expect": "lab.expect_l9", "pos": south_farm, "focus": farm.global_position, "crowd": false},
		{"btn": "lab.btn_l10", "title": "lab.l10", "expect": "lab.expect_l10", "pos": trunk_east, "focus": tree.global_position, "crowd": false},
		{"btn": "lab.btn_l11", "title": "lab.l11", "expect": "lab.expect_l11", "pos": wall_corner, "focus": wall.global_position, "crowd": false},
		{"btn": "lab.btn_l12", "title": "lab.l12", "expect": "lab.expect_l12", "pos": player.global_position, "focus": IsoVolume.iso_to_world(Vector2(1.2, 1.1)), "crowd": false, "pack": true},
	]
	_refresh_copy()

func _show_scenario(index: int) -> void:
	_index = clampi(index, 0, _scenarios.size() - 1)
	var row: Dictionary = _scenarios[_index]
	var crowd: bool = row.crowd
	player.global_position = row.pos
	player.visible = true
	player._set_frame(2, 0)
	near_one.visible = crowd
	far_one.visible = crowd
	if row.get("pack", false):
		player.visible = false
		_place_crowd()
	else:
		_hide_crowd()
	if crowd:
		near_one.global_position = row.near
		near_one._set_frame(2, 0)
		far_one.visible = false
	camera.position = row.focus
	_refresh_copy()
	for i in _buttons.size():
		_buttons[i].modulate = Color(1, 0.95, 0.7) if i == _index else Color.WHITE

func _refresh_copy() -> void:
	if _scenarios.is_empty():
		return
	var row: Dictionary = _scenarios[_index]
	_title.text = "%d/%d  %s" % [_index + 1, _scenarios.size(), Locale.text(str(row.title))]
	_hint.text = "%s\n%s" % [Locale.text(str(row.expect)), Locale.text("lab.help")]
	for i in _buttons.size():
		_buttons[i].text = Locale.text(str(_scenarios[i].btn))
	var back := find_child("BackButton", true, false) as Button
	if back:
		back.text = Locale.text("lab.back")
	var lang := find_child("LangButton", true, false) as Button
	if lang:
		lang.text = Locale.text("lang.switch")
		lang.tooltip_text = Locale.text("tip.lang")

func _back_to_game() -> void:
	Engine.set_meta("skip_lab", true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _cell_center(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)

func _can_step(from_pos: Vector2, to_pos: Vector2) -> bool:
	var to_cell := ground.local_to_map(to_pos)
	if to_cell.x < 0 or to_cell.y < 0 or to_cell.x >= COLS or to_cell.y >= ROWS:
		return false
	if _blocked.has(to_cell) and to_cell != ground.local_to_map(from_pos):
		return false
	var mine := IsoVolume.from_feet(to_pos)
	for node in _prop_nodes():
		if mine.overlaps(node.get_iso_volume()):
			return false
	if near_one.visible and mine.overlaps(near_one.get_iso_volume()):
		return false
	if far_one.visible and mine.overlaps(far_one.get_iso_volume()):
		return false
	for person in _crowd:
		if person.visible and mine.overlaps(person.get_iso_volume()):
			return false
	return true

func _world_feet(vol: IsoVolume, dir: Vector2) -> Vector2:
	return IsoVolume.iso_to_world(_feet_iso(vol, dir))

func _feet_iso(vol: IsoVolume, dir: Vector2) -> Vector2:
	return _feet_gap(vol, dir, 0.12)

func _press_feet(vol: IsoVolume, dir: Vector2) -> Vector2:
	return IsoVolume.iso_to_world(_feet_gap(vol, dir, 0.004))

func _corner_feet(vol: IsoVolume) -> Vector2:
	var corner := Vector2(vol.max_x, vol.max_y)
	return _press_feet(vol, corner - vol.bounds_center())

func _feet_gap(vol: IsoVolume, dir: Vector2, gap: float) -> Vector2:
	var d := dir.normalized()
	return vol.bounds_center() + d * (vol.reach(d) + IsoVolume.walker_support(d) + gap)

func _prop_nodes() -> Array:
	return [house, wall, farm, tree, tree2, rock]

func _isolate(subject: Node) -> void:
	for node in _prop_nodes():
		(node as CanvasItem).visible = node == subject

func _show_props() -> void:
	for node in _prop_nodes():
		(node as CanvasItem).visible = true

func _auto_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var l1 := await _axis_case(tree, "L1", "/opt/cursor/artifacts/lab-tree-north.png", "/opt/cursor/artifacts/lab-tree-south.png")
	var l2 := await _beside_case(tree, "L2", "/opt/cursor/artifacts/lab-tree-east.png")
	var l2_point := await _point_vs_ellipse()
	var l3 := await _axis_case(rock, "L3", "/opt/cursor/artifacts/lab-rock-north.png", "/opt/cursor/artifacts/lab-rock-south.png")
	var l4 := await _axis_case(house, "L4", "/opt/cursor/artifacts/lab-house-north.png", "/opt/cursor/artifacts/lab-house-south.png")
	var l5 := await _pair_props()
	var l6 := await _select_case()
	var l7 := await _axis_case(wall, "L7", "/opt/cursor/artifacts/lab-wall-north.png", "/opt/cursor/artifacts/lab-wall-south.png")
	var l7_side := await _beside_case(wall, "L7E", "")
	var l8 := await _walker_pair()
	var l9 := await _frame_case()
	var l10 := await _trunk_press()
	var l11 := await _wall_corner()
	var l12 := await _crowd_case()
	var convex_ok := _convex_ok()
	var ok := l1 and l2 and l2_point and l3 and l4 and l5 and l6 and l7 and l7_side and l8 and l9 and l10 and l11 and l12 and convex_ok
	print("LAB_L ", l1, l2, l2_point, l3, l4, l5, l6, l7, l7_side, l8, l9, l10, l11, l12, convex_ok)
	print("LAB_OK ", ok)
	get_tree().quit(0 if ok else 1)

func _axis_case(prop: Node2D, label: String, north_path: String, south_path: String) -> bool:
	var vol: IsoVolume = prop.get_iso_volume()
	var north := _world_feet(vol, Vector2(0, -1))
	var south := _world_feet(vol, Vector2(0, 1))
	var north_vol := IsoVolume.from_feet(north)
	var south_vol := IsoVolume.from_feet(south)
	var math_north := DepthSolver.is_behind(north_vol, vol) and not DepthSolver.is_behind(vol, north_vol)
	var math_south := DepthSolver.is_behind(vol, south_vol) and not DepthSolver.is_behind(south_vol, vol)
	_isolate(prop)
	near_one.visible = false
	far_one.visible = false
	camera.position = prop.global_position
	player.visible = false
	await get_tree().process_frame
	var bare := await _grab()
	player.visible = true
	player.global_position = north
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var north_z := player.z_index < prop.z_index
	var north_px := _overlap_change(prop, player, bare, await _grab())
	if north_path != "":
		await _capture(north_path)
	player.global_position = south
	await get_tree().process_frame
	await get_tree().process_frame
	var south_z := player.z_index > prop.z_index
	var south_px := _overlap_change(prop, player, bare, await _grab())
	if south_path != "":
		await _capture(south_path)
	_show_props()
	var north_cover: bool = int(north_px.opaque) < 12 or float(north_px.ratio) < 0.12
	var south_show: bool = int(south_px.opaque) < 12 or float(south_px.ratio) > 0.2
	var passed: bool = math_north and math_south and north_z and south_z and north_cover and south_show
	print(label, " math=", math_north, math_south, " z=", north_z, south_z, " north_px=", north_px, " south_px=", south_px, " ok=", passed)
	return passed

func _beside_case(prop: Node2D, label: String, path: String) -> bool:
	var vol: IsoVolume = prop.get_iso_volume()
	var east := _world_feet(vol, Vector2(1, 0))
	var east_vol := IsoVolume.from_feet(east)
	var math_front := not DepthSolver.is_behind(east_vol, vol) and east_vol.depth_key() > vol.depth_key()
	var shifted := IsoVolume.from_cell(prop.cell, "tree").shifted(Vector2(0, 1.2))
	var wide_would_cover := DepthSolver.is_behind(east_vol, shifted) and not DepthSolver.is_behind(east_vol, vol)
	_isolate(prop)
	near_one.visible = false
	far_one.visible = false
	camera.position = prop.global_position
	player.visible = false
	await get_tree().process_frame
	var bare := await _grab()
	player.visible = true
	player.global_position = east
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := player.z_index > prop.z_index
	var shown := _overlap_change(prop, player, bare, await _grab())
	if path != "":
		await _capture(path)
	_show_props()
	var visible: bool = int(shown.opaque) < 12 or float(shown.ratio) > 0.15
	var passed: bool = math_front and front_z and visible and wide_would_cover
	print(label, " math=", math_front, " z=", front_z, " px=", shown, " wide=", wide_would_cover, " ok=", passed)
	return passed

func _point_vs_ellipse() -> bool:
	# Center the oval on the trunk's north rim. A point there is already
	# "behind" the trunk. The oval still reaches farther south, so it is not
	# entirely north of the trunk and the person stays in front. This pose
	# overlaps on purpose; the game never allows it.
	DepthSolver.audit = false
	var vol: IsoVolume = tree.get_iso_volume()
	var feet := Vector2(vol.center.x, vol.min_y - 0.005)
	var oval := IsoVolume.from_feet(IsoVolume.iso_to_world(feet))
	var as_point := DepthSolver.point_behind(feet, vol)
	var as_oval := DepthSolver.is_behind(oval, vol)
	var trunk_behind := DepthSolver.is_behind(vol, oval)
	_isolate(tree)
	near_one.visible = false
	far_one.visible = false
	camera.position = tree.global_position
	player.visible = false
	await get_tree().process_frame
	var bare := await _grab()
	player.visible = true
	player.global_position = IsoVolume.iso_to_world(feet)
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := player.z_index > tree.z_index
	var shown := _overlap_change(tree, player, bare, await _grab())
	await _capture("/opt/cursor/artifacts/lab-tree-oval.png")
	_show_props()
	var visible: bool = int(shown.opaque) < 12 or float(shown.ratio) > 0.2
	var front_key := oval.depth_key() > vol.depth_key()
	var passed := as_point and not as_oval and not trunk_behind and front_key and front_z and visible
	print("L2P point_behind=", as_point, " oval_behind=", as_oval, " trunk_behind=", trunk_behind, " key=", front_key, " z=", front_z, " px=", shown, " ok=", passed)
	DepthSolver.audit = true
	return passed

func _pair_props() -> bool:
	house.visible = false
	wall.visible = false
	rock.visible = false
	tree.visible = true
	tree2.visible = true
	camera.position = (tree.global_position + tree2.global_position) * 0.5
	player.visible = false
	near_one.visible = false
	far_one.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var first := tree2.z_index > tree.z_index
	await get_tree().process_frame
	var stable := tree2.z_index > tree.z_index and tree2.z_index == tree2.z_index
	await _capture("/opt/cursor/artifacts/lab-two-trees.png")
	_show_props()
	var passed := first and stable
	print("L5 z=", tree.z_index, tree2.z_index, " ok=", passed)
	return passed

func _select_case() -> bool:
	var vol: IsoVolume = house.get_iso_volume()
	var south := _world_feet(vol, Vector2(0, 1))
	var north := _world_feet(vol, Vector2(0, -1))
	_isolate(house)
	camera.position = house.global_position
	near_one.visible = false
	far_one.visible = false
	player.visible = false
	await get_tree().process_frame
	var bare := await _grab()
	var mark_at := IsoVolume.iso_to_world(Vector2((vol.min_x + vol.max_x) * 0.5, vol.max_y))
	var yellow := _yellow_near(bare, mark_at, 18)
	player.visible = true
	player.global_position = south
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var over := await _grab()
	var covered := false
	if yellow.x >= 0.0:
		covered = not _is_yellow(over.get_pixel(int(yellow.x), int(yellow.y)))
	var front_z := player.z_index > house.z_index
	await _capture("/opt/cursor/artifacts/lab-select-front.png")
	player.global_position = north
	await get_tree().process_frame
	await get_tree().process_frame
	var behind_z := player.z_index < house.z_index
	var hidden := _overlap_change(house, player, bare, await _grab())
	await _capture("/opt/cursor/artifacts/lab-select-behind.png")
	_show_props()
	var behind_cover: bool = int(hidden.opaque) < 12 or float(hidden.ratio) < 0.12
	var passed: bool = yellow.x >= 0.0 and covered and front_z and behind_z and behind_cover
	print("L6 yellow=", yellow, " covered=", covered, " z=", front_z, behind_z, " hide=", hidden, " ok=", passed)
	return passed

func _walker_pair() -> bool:
	var far_pos := IsoVolume.iso_to_world(Vector2(4.2, 6.2))
	var near_pos := IsoVolume.iso_to_world(Vector2(4.5, 7.1))
	player.visible = true
	near_one.visible = true
	far_one.visible = false
	camera.position = (far_pos + near_pos) * 0.5
	player.global_position = near_pos
	near_one.global_position = far_pos
	player._set_frame(2, 0)
	near_one._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var near_front := player.z_index > near_one.z_index
	var z0 := player.z_index
	var z1 := near_one.z_index
	await get_tree().process_frame
	var stable := player.z_index == z0 and near_one.z_index == z1
	player.global_position = far_pos
	near_one.global_position = near_pos
	await get_tree().process_frame
	await get_tree().process_frame
	var swapped := player.z_index < near_one.z_index
	await _capture("/opt/cursor/artifacts/lab-walkers.png")
	var passed := near_front and stable and swapped
	print("L8 near_front=", near_front, " stable=", stable, " swapped=", swapped, " ok=", passed)
	return passed

func _convex_ok() -> bool:
	var ok := true
	for key in IsoVolume.TABLE:
		if not IsoVolume.spec_convex(IsoVolume.spec_for(str(key))):
			ok = false
			print("CONCAVE ", key)
	print("CONVEX_OK ", ok)
	return ok

func _frame_case() -> bool:
	var vol: IsoVolume = farm.get_iso_volume()
	var south := _press_feet(vol, Vector2(0, 1))
	var north := _press_feet(vol, Vector2(0, -1))
	var south_vol := IsoVolume.from_feet(south)
	var north_vol := IsoVolume.from_feet(north)
	var inside := IsoVolume.from_feet(IsoVolume.iso_to_world(vol.bounds_center()))
	var inside_hit := inside.overlaps(vol)
	var south_free := not south_vol.overlaps(vol)
	var north_free := not north_vol.overlaps(vol)
	var math_south := DepthSolver.is_behind(vol, south_vol) and not DepthSolver.is_behind(south_vol, vol)
	var math_north := DepthSolver.is_behind(north_vol, vol) and not DepthSolver.is_behind(vol, north_vol)
	_isolate(farm)
	near_one.visible = false
	far_one.visible = false
	_hide_crowd()
	camera.zoom = Vector2(2.2, 2.2)
	camera.position = farm.global_position
	player.visible = true
	player.global_position = south
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := player.z_index > farm.z_index
	var south_clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	await _capture("/opt/cursor/artifacts/frame-farm-fixed.png")
	player.global_position = north
	await get_tree().process_frame
	await get_tree().process_frame
	var back_z := player.z_index < farm.z_index
	var north_clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	var ordered := _orders_match()
	await _capture("/opt/cursor/artifacts/frame-farm-north.png")
	camera.zoom = Vector2(1.55, 1.55)
	_show_props()
	var passed := inside_hit and south_free and north_free and math_south and math_north and front_z and back_z and south_clean and north_clean and ordered
	print("L9 inside=", inside_hit, " free=", south_free, north_free, " math=", math_south, math_north, " z=", front_z, back_z, " clean=", south_clean, north_clean, " order=", ordered, " ok=", passed)
	return passed

func _trunk_press() -> bool:
	var vol: IsoVolume = tree.get_iso_volume()
	var east := _press_feet(vol, Vector2(1, 0))
	var north := _press_feet(vol, Vector2(0, -1))
	var east_vol := IsoVolume.from_feet(east)
	var north_vol := IsoVolume.from_feet(north)
	var east_free := not east_vol.overlaps(vol)
	var north_free := not north_vol.overlaps(vol)
	var sunk := IsoVolume.from_feet(IsoVolume.iso_to_world(_feet_gap(vol, Vector2(1, 0), -0.02)))
	var sunk_hit := sunk.overlaps(vol)
	var math_north := DepthSolver.is_behind(north_vol, vol) and not DepthSolver.is_behind(vol, north_vol)
	var math_east := not DepthSolver.is_behind(east_vol, vol) and east_vol.depth_key() > vol.depth_key()
	_isolate(tree)
	near_one.visible = false
	far_one.visible = false
	_hide_crowd()
	camera.position = tree.global_position
	player.visible = true
	player.global_position = east
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := player.z_index > tree.z_index
	var east_clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	await _capture("/opt/cursor/artifacts/lab-trunk-press.png")
	player.global_position = north
	await get_tree().process_frame
	await get_tree().process_frame
	var back_z := player.z_index < tree.z_index
	var north_clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	var ordered := _orders_match()
	_show_props()
	var passed := east_free and north_free and sunk_hit and math_north and math_east and front_z and back_z and east_clean and north_clean and ordered
	print("L10 free=", east_free, north_free, " sunk=", sunk_hit, " math=", math_north, math_east, " z=", front_z, back_z, " clean=", east_clean, north_clean, " order=", ordered, " ok=", passed)
	return passed

func _wall_corner() -> bool:
	var vol: IsoVolume = wall.get_iso_volume()
	var at := _corner_feet(vol)
	var oval := IsoVolume.from_feet(at)
	var free := not oval.overlaps(vol)
	var sunk := IsoVolume.from_feet(IsoVolume.iso_to_world(_feet_gap(vol, Vector2(vol.max_x, vol.max_y) - vol.bounds_center(), -0.02)))
	var sunk_hit := sunk.overlaps(vol)
	var neither := not DepthSolver.is_behind(oval, vol) and not DepthSolver.is_behind(vol, oval)
	var front_key := oval.depth_key() > vol.depth_key()
	_isolate(wall)
	near_one.visible = false
	far_one.visible = false
	_hide_crowd()
	camera.position = wall.global_position + Vector2(40, 30)
	player.visible = true
	player.global_position = at
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var front_z := player.z_index > wall.z_index
	var clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	var ordered := _orders_match()
	await _capture("/opt/cursor/artifacts/lab-wall-corner.png")
	_show_props()
	var passed := free and sunk_hit and neither and front_key and front_z and clean and ordered
	print("L11 free=", free, " sunk=", sunk_hit, " neither=", neither, " key=", front_key, " z=", front_z, " clean=", clean, " order=", ordered, " ok=", passed)
	return passed

func _crowd_case() -> bool:
	_show_props()
	player.visible = false
	near_one.visible = false
	far_one.visible = false
	_place_crowd()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = IsoVolume.iso_to_world(Vector2(1.6, 1.2))
	await get_tree().process_frame
	await get_tree().process_frame
	var clean := DepthSolver.last_overlaps == 0 and not DepthSolver.last_cycle
	var ordered := _orders_match()
	var slots := _crowd_slots()
	await _capture("/opt/cursor/artifacts/lab-crowd.png")
	camera.zoom = Vector2(1.55, 1.55)
	_hide_crowd()
	var passed := slots.size() >= 16 and clean and ordered
	print("L12 slots=", slots.size(), " clean=", clean, " overlaps=", DepthSolver.last_overlaps, " cycle=", DepthSolver.last_cycle, " order=", ordered, " ok=", passed)
	return passed

func _orders_match() -> bool:
	var vols: Array = []
	for node in get_tree().get_nodes_in_group("iso"):
		if not is_instance_valid(node) or not (node is CanvasItem):
			continue
		if not (node as CanvasItem).is_visible_in_tree():
			continue
		if not node.has_method("get_iso_volume"):
			continue
		vols.append(node.get_iso_volume())
	var left := DepthSolver.order_reference(vols)
	var right := DepthSolver.order_two_phase(vols)
	if left.size() != right.size():
		return false
	for i in left.size():
		if int(left[i]) != int(right[i]):
			return false
	return not DepthSolver.last_cycle

func _crowd_slots() -> Array[Vector2]:
	var props: Array = []
	for node in _prop_nodes():
		props.append(node.get_iso_volume())
	var slots: Array[Vector2] = []
	var x := 0.45
	while x < 3.2:
		var y := 0.45
		while y < 2.4:
			var feet := IsoVolume.from_feet(IsoVolume.iso_to_world(Vector2(x, y)))
			var bad := false
			for prop in props:
				if feet.overlaps(prop):
					bad = true
					break
			if not bad:
				slots.append(IsoVolume.iso_to_world(Vector2(x, y)))
			y += 0.40
		x += 0.42
	return slots

func _place_crowd() -> void:
	var slots := _crowd_slots()
	var tex: Texture2D = load("res://assets/people/woman.png")
	var want := mini(16, slots.size())
	while _crowd.size() < want:
		var person := _person(tex, Vector2.ZERO)
		person.visible = false
		_crowd.append(person)
	for i in _crowd.size():
		var on := i < want
		_crowd[i].visible = on
		if on:
			_crowd[i].global_position = slots[i]
			_crowd[i]._set_frame(2, 0)

func _hide_crowd() -> void:
	for person in _crowd:
		person.visible = false

func _overlap_change(prop: Node2D, person: Villager, bare: Image, covered: Image) -> Dictionary:
	var sprite := _art_of(prop)
	var body := person.get_node_or_null("Sprite2D")
	if body == null:
		for child in person.get_children():
			if child is Sprite2D:
				body = child
				break
	if sprite == null or body == null or bare == null or covered == null:
		return {"opaque": 0, "ratio": 1.0}
	var img := sprite.texture.get_image()
	if img == null:
		return {"opaque": 0, "ratio": 1.0}
	if img.is_compressed():
		img.decompress()
	var body_img: Image
	var body_origin := Vector2i.ZERO
	if body.texture is AtlasTexture:
		var atlas := body.texture as AtlasTexture
		body_img = atlas.atlas.get_image()
		body_origin = Vector2i(atlas.region.position)
	else:
		body_img = body.texture.get_image()
	if body_img == null:
		return {"opaque": 0, "ratio": 1.0}
	if body_img.is_compressed():
		body_img.decompress()
	var xform := get_viewport().get_canvas_transform()
	var changed := 0
	var opaque := 0
	var step := 3
	var body_size: Vector2 = body.texture.get_size()
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			if img.get_pixel(x, y).a < 0.92:
				continue
			var world: Vector2 = sprite.to_global(Vector2(x, y))
			var local: Vector2 = body.to_local(world)
			if local.x < 0.0 or local.y < 0.0 or local.x >= body_size.x or local.y >= body_size.y:
				continue
			var bx := body_origin.x + int(local.x)
			var by := body_origin.y + int(local.y)
			if bx < 0 or by < 0 or bx >= body_img.get_width() or by >= body_img.get_height():
				continue
			if body_img.get_pixel(bx, by).a < 0.45:
				continue
			var screen: Vector2 = xform * world
			var sx := int(screen.x)
			var sy := int(screen.y)
			if sx < 0 or sy < 0 or sx >= bare.get_width() or sy >= bare.get_height():
				continue
			if sx >= covered.get_width() or sy >= covered.get_height():
				continue
			opaque += 1
			var ca := covered.get_pixel(sx, sy)
			var cb := bare.get_pixel(sx, sy)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.18:
				changed += 1
	var ratio := 1.0 if opaque == 0 else float(changed) / float(opaque)
	return {"opaque": opaque, "ratio": ratio}

func _art_of(node: Node2D) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
	return null

func _yellow_near(image: Image, world: Vector2, radius: int) -> Vector2:
	if image == null:
		return Vector2(-1, -1)
	var screen: Vector2 = get_viewport().get_canvas_transform() * world
	var best := Vector2(-1, -1)
	var best_d := 100000.0
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var x := int(screen.x) + ox
			var y := int(screen.y) + oy
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if not _is_yellow(image.get_pixel(x, y)):
				continue
			var d := Vector2(ox, oy).length_squared()
			if d < best_d:
				best_d = d
				best = Vector2(x, y)
	return best

func _is_yellow(c: Color) -> bool:
	return c.r > 0.72 and c.g > 0.55 and c.b < 0.5 and c.g > c.b + 0.2 and c.r > c.b + 0.25

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("SHOT", path, " err=", err)

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _box(Color(0.16, 0.22, 0.18), Color(0.55, 0.62, 0.5)))
	btn.add_theme_stylebox_override("hover", _box(Color(0.22, 0.3, 0.24), Color(0.7, 0.78, 0.6)))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.16, 0.13), Color(1, 0.86, 0.4)))
	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
