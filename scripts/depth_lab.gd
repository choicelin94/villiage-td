extends Node2D

const TILE := Vector2i(176, 98)
const COLS := 9
const ROWS := 9
const HOUSE_CELL := Vector2i(4, 4)
const TREE_CELL := Vector2i(2, 3)
const ROCK_CELL := Vector2i(6, 3)

var ground: TileMapLayer
var house: Building
var tree: Node2D
var rock: Node2D
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
	var entries: Array = []
	for node in get_tree().get_nodes_in_group("iso"):
		if not is_instance_valid(node) or not (node is CanvasItem):
			continue
		if not (node as CanvasItem).is_visible_in_tree():
			continue
		if not node.has_method("iso_points") or not node.has_method("iso_rect"):
			continue
		entries.append({
			"node": node,
			"points": node.iso_points(),
			"rect": node.iso_rect(),
		})
	IsoSort.apply(entries)

func _build_ground() -> void:
	ground = TileMapLayer.new()
	ground.z_index = -4096
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
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
	_blocked[ROCK_CELL] = true

func _build_props() -> void:
	house = Building.new()
	house.position = _cell_center(HOUSE_CELL)
	house.setup(Building.Kind.HOUSE, HOUSE_CELL)
	add_child(house)
	tree = _prop(TREE_CELL, "res://assets/village/tree.png")
	tree.name = "Tree"
	rock = _prop(ROCK_CELL, "res://assets/village/rock.png")
	rock.name = "Rock"

func _prop(cell: Vector2i, path: String) -> Node2D:
	var node := Node2D.new()
	node.position = _cell_center(cell)
	node.set_script(load("res://scripts/iso_prop.gd"))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(path)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Building.SPRITE_OFF
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
	_mark_line(tree, Color(0.45, 0.9, 0.45, 0.9))
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
	person.add_child(mark)

func _mark_tag(person: Villager, key: String) -> void:
	var mark := IsoMark.new()
	mark.kind = IsoMark.Kind.TAG
	mark.text_key = key
	var head := person.head_slice()
	mark.position = Vector2(-18, -132) - head.position
	head.add_child(mark)

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
	for i in 8:
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
	var h := _cell_center(HOUSE_CELL)
	var t := _cell_center(TREE_CELL)
	var r := _cell_center(ROCK_CELL)
	var tree_tip := _south_tip(tree)
	var rock_tip := _south_tip(rock)
	_scenarios = [
		{"btn": "lab.btn_front", "title": "lab.front", "expect": "lab.expect_front", "pos": h + Vector2(0, 78), "focus": h, "crowd": false},
		{"btn": "lab.btn_east_near", "title": "lab.east_near", "expect": "lab.expect_near", "pos": h + Vector2(70, 30), "focus": h, "crowd": false},
		{"btn": "lab.btn_east_far", "title": "lab.east_far", "expect": "lab.expect_far", "pos": h + Vector2(80, -8), "focus": h, "crowd": false},
		{"btn": "lab.btn_west_near", "title": "lab.west_near", "expect": "lab.expect_near", "pos": h + Vector2(-70, 30), "focus": h, "crowd": false},
		{"btn": "lab.btn_west_far", "title": "lab.west_far", "expect": "lab.expect_far", "pos": h + Vector2(-80, -8), "focus": h, "crowd": false},
		{"btn": "lab.btn_tree", "title": "lab.tree", "expect": "lab.expect_far", "pos": Vector2(tree_tip.x, tree_tip.y - 40.0), "focus": t, "crowd": false},
		{"btn": "lab.btn_rock", "title": "lab.rock", "expect": "lab.expect_far", "pos": Vector2(rock_tip.x, rock_tip.y - 40.0), "focus": r, "crowd": false},
		{"btn": "lab.btn_crowd", "title": "lab.crowd", "expect": "lab.expect_crowd", "pos": h + Vector2(0, 78), "focus": h, "crowd": true},
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
	if crowd:
		var h := _cell_center(HOUSE_CELL)
		near_one.global_position = h + Vector2(70, 30)
		far_one.global_position = h + Vector2(80, -8)
		near_one._set_frame(2, 0)
		far_one._set_frame(2, 0)
	camera.position = row.focus
	_refresh_copy()
	for i in _buttons.size():
		_buttons[i].modulate = Color(1, 0.95, 0.7) if i == _index else Color.WHITE

func _refresh_copy() -> void:
	if _scenarios.is_empty():
		return
	var row: Dictionary = _scenarios[_index]
	_title.text = "%d/8  %s" % [_index + 1, Locale.text(str(row.title))]
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
	if not _blocked.has(to_cell):
		return true
	return to_cell == ground.local_to_map(from_pos)

func _south_tip(node: Node2D) -> Vector2:
	var pts: PackedVector2Array = node.iso_points()
	var tip := pts[0]
	for p in pts:
		if p.y > tip.y:
			tip = p
	return tip

func _auto_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var h := house.global_position
	var near := h + Vector2(70, 30)
	var far := h + Vector2(80, -8)
	var cmp_near := IsoSort.compare_points(PackedVector2Array([near]), house.iso_points())
	var cmp_far := IsoSort.compare_points(PackedVector2Array([far]), house.iso_points())
	_show_scenario(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var near_front := player.feet_slice().z_index > house.z_index
	var near_head_behind := player.head_slice().z_index < house.z_index
	await _capture("/opt/cursor/artifacts/lab-east-near.png")
	_show_scenario(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var far_behind := player.feet_slice().z_index < house.z_index and player.head_slice().z_index < house.z_index
	await _capture("/opt/cursor/artifacts/lab-east-far.png")
	_show_scenario(7)
	await get_tree().process_frame
	await get_tree().process_frame
	var crowd_near := near_one.feet_slice().z_index > house.z_index
	var crowd_far := far_one.feet_slice().z_index < house.z_index
	var crowd_front := player.feet_slice().z_index > house.z_index
	await _capture("/opt/cursor/artifacts/lab-crowd.png")
	var tree_tip := _south_tip(tree)
	var tree_behind := await _occluder_case(tree, tree_tip, "/opt/cursor/artifacts/lab-tree-behind.png", "/opt/cursor/artifacts/lab-tree-straddle.png")
	var rock_tip := _south_tip(rock)
	var rock_behind := await _occluder_case(rock, rock_tip, "/opt/cursor/artifacts/lab-rock-behind.png", "/opt/cursor/artifacts/lab-rock-straddle.png")
	var line_ok := await _line_case()
	var math_ok := cmp_near > 0 and cmp_far < 0
	var ok := math_ok and near_front and near_head_behind and far_behind and crowd_near and crowd_far and crowd_front and tree_behind and rock_behind and line_ok
	print("LAB_CMP near=", cmp_near, " far=", cmp_far)
	print("LAB_Z near_front=", near_front, " near_head_behind=", near_head_behind, " far_behind=", far_behind, " crowd=", crowd_near, crowd_far, crowd_front)
	print("LAB_PROP tree=", tree_behind, " rock=", rock_behind, " line=", line_ok)
	print("LAB_OK ", ok)
	get_tree().quit(0 if ok else 1)

func _occluder_case(prop: Node2D, tip: Vector2, behind_path: String, straddle_path: String) -> bool:
	near_one.visible = false
	far_one.visible = false
	player.visible = false
	camera.position = prop.global_position
	await get_tree().process_frame
	var bare := await _grab()
	player.visible = true
	player.global_position = Vector2(tip.x, tip.y - 40.0)
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet_behind := player.feet_slice().z_index < prop.z_index
	var head_behind := player.head_slice().z_index < prop.z_index
	var covered := _opaque_ratio(prop, bare, await _grab(), Vector2(tip.x, tip.y - 36.0), 18.0)
	await _capture(behind_path)
	player.global_position = Vector2(tip.x, tip.y + 16.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet_front := player.feet_slice().z_index > prop.z_index
	var head_back := player.head_slice().z_index < prop.z_index
	var chest_hidden := _opaque_ratio(prop, bare, await _grab(), Vector2(tip.x, tip.y - 48.0), 14.0)
	var feet_shown := _opaque_ratio(prop, bare, await _grab(), Vector2(tip.x, tip.y - 8.0), 10.0)
	await _capture(straddle_path)
	var passed := feet_behind and head_behind and covered < 0.12 and feet_front and head_back and chest_hidden < 0.2 and feet_shown > 0.2
	print("LAB_CASE ", prop.name, " feet_behind=", feet_behind, " head_behind=", head_behind, " covered=", covered, " feet_front=", feet_front, " head_back=", head_back, " chest=", chest_hidden, " feet_px=", feet_shown)
	return passed

func _line_case() -> bool:
	near_one.visible = false
	far_one.visible = false
	var tip := _south_tip(house)
	camera.position = house.global_position
	player.visible = true
	player.global_position = house.global_position + Vector2(0, -90)
	player._set_frame(2, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var away := await _grab()
	var line_at := _yellow_near(away, tip, 14)
	player.global_position = Vector2(tip.x, tip.y)
	await get_tree().process_frame
	await get_tree().process_frame
	var over := await _grab()
	await _capture("/opt/cursor/artifacts/lab-line.png")
	var covered := false
	if line_at.x >= 0.0:
		covered = not _is_yellow(over.get_pixel(int(line_at.x), int(line_at.y)))
	var side := _south_tip(house)
	var side_pt := Vector2(side.x - 70.0, IsoSort.y_at(house.iso_points(), side.x - 70.0))
	var side_px := _yellow_near(over, side_pt, 10)
	var side_stays := side_px.x >= 0.0
	print("LAB_LINE found=", line_at, " covered=", covered, " side=", side_stays)
	return line_at.x >= 0.0 and covered and side_stays

func _opaque_ratio(prop: Node2D, bare: Image, covered: Image, world: Vector2, radius: float) -> float:
	var sprite := _art_of(prop)
	if sprite == null or sprite.texture == null or bare == null or covered == null:
		return 1.0
	var img := sprite.texture.get_image()
	if img == null:
		return 1.0
	if img.is_compressed():
		img.decompress()
	var xform := get_viewport().get_canvas_transform()
	var changed := 0
	var opaque := 0
	var steps := int(radius)
	for oy in range(-steps, steps + 1, 2):
		for ox in range(-steps, steps + 1, 2):
			var at := world + Vector2(ox, oy)
			var local: Vector2 = sprite.to_local(at)
			var ix := int(local.x)
			var iy := int(local.y)
			if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			if img.get_pixel(ix, iy).a < 0.45:
				continue
			var screen: Vector2 = xform * at
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
	if opaque == 0:
		return 1.0
	return float(changed) / float(opaque)

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
