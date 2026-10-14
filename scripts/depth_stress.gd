extends Node2D

const TILE := Vector2i(128, 128)
const COLS := 18
const ROWS := 14
const WARM := 40
const SAMPLE := 90
const CHECK_MOVE := 36
const CHECK_HOLD := 4

var ground: TileMapLayer
var camera: Camera2D
var walkers: Array[Villager] = []
var _bases: Array[Vector2] = []
var _amps: Array[float] = []
var _n := 100
var _only := ""
var _check := false
var _web := false
var _phase := 0
var _phase_frame := 0
var _sum_us := 0
var _samples: Array[int] = []
var _sum_narrow := 0
var _sum_cand := 0
var _sum_hits := 0
var _sum_broad := 0
var _wall0 := 0
var ref_ms := 0.0
var ref_fps := 0.0
var new_ms := 0.0
var new_fps := 0.0
var new_narrow := 0.0
var new_cand := 0.0
var new_hits := 0.0
var new_broad := 0.0
var _done := false
var _font: Font
var _title: Label
var _body: Label
var hosted := false

func _ready() -> void:
	process_priority = 50
	Engine.max_fps = 0
	_font = CatalogPaths.load_font()
	_web = OS.has_feature("web")
	_check = not _web and not hosted
	_n = int(Engine.get_meta("stress_n", 100))
	_only = str(Engine.get_meta("stress_only", ""))
	if _n < 1:
		_n = 100
	_build_ground()
	_build_props()
	_build_people()
	_build_camera()
	_build_ui()
	Locale.changed.connect(_refresh_copy)
	_refresh_copy()
	if _check:
		_run_check()

func _process(_delta: float) -> void:
	if _check or _done:
		return
	_pose(_phase_frame)
	var vols := _gather()
	var sample := _is_sample()
	if sample and _phase_frame == 0:
		_sum_us = 0
		_sum_narrow = 0
		_sum_cand = 0
		_sum_hits = 0
		_sum_broad = 0
		_samples.clear()
		_wall0 = Time.get_ticks_usec()
	if _solver_is_ref():
		DepthSolver.apply_reference(vols)
		if sample:
			var spent := DepthSolver.last_reference_usec
			_sum_us += spent
			_samples.append(spent)
	else:
		DepthSolver.apply(vols)
		if sample:
			var spent_new := DepthSolver.last_sort_usec
			_sum_us += spent_new
			_samples.append(spent_new)
			_sum_narrow += DepthSolver.last_narrow
			_sum_cand += DepthSolver.last_candidates
			_sum_hits += DepthSolver.last_hits
			_sum_broad += DepthSolver.last_broad
	_phase_frame += 1
	var limit := SAMPLE if sample else WARM
	if _phase_frame >= limit:
		if sample:
			_close_sample()
		_phase += 1
		_phase_frame = 0
		if _bench_done():
			_done = true
			_publish()
	_refresh_copy()

func _run_check() -> void:
	var count := mini(_n, 120)
	if walkers.size() > count:
		for i in range(count, walkers.size()):
			walkers[i].visible = false
			walkers[i].remove_from_group("iso")
	var bad_order := 0
	var bad_pairs := 0
	var bad_short := 0
	var bad_overlap := 0
	var bad_cycle := 0
	var frames := 0
	for frame in CHECK_MOVE + CHECK_HOLD:
		var pose := frame if frame < CHECK_MOVE else CHECK_MOVE
		_pose(pose)
		var vols := _gather()
		if frame == 0 or frame == 10 or frame == 20 or frame == CHECK_MOVE:
			bad_short += DepthSolver.shortcut_mismatches(vols)
		var brute := _brute_pairs(vols)
		var left := DepthSolver.order_reference(vols)
		if DepthSolver.last_cycle:
			bad_cycle += 1
		var right := DepthSolver.order_two_phase(vols)
		if DepthSolver.last_cycle:
			bad_cycle += 1
		if DepthSolver.count_overlaps(vols) > 0:
			bad_overlap += 1
			if bad_overlap == 1:
				print("OVERLAP frame ", frame, " count ", DepthSolver.count_overlaps(vols))
		if brute != DepthSolver.last_candidates:
			bad_pairs += 1
			if bad_pairs == 1:
				print("PAIR_MISMATCH frame ", frame, " brute ", brute, " sweep ", DepthSolver.last_candidates)
		if not _same(left, right):
			bad_order += 1
			if bad_order == 1:
				print("ORDER_MISMATCH frame ", frame, " ref ", left.slice(0, 12), " two ", right.slice(0, 12))
		frames += 1
	var ok := bad_order == 0 and bad_pairs == 0 and bad_short == 0 and bad_overlap == 0 and bad_cycle == 0
	print("ORDER_OK %s mismatches %d shortcut %d pairs %d overlap %d cycle %d frames %d n %d" % [ok, bad_order, bad_short, bad_pairs, bad_overlap, bad_cycle, frames, _gather().size()])
	get_tree().quit(0 if ok else 1)

func _solver_is_ref() -> bool:
	if _only == "ref":
		return true
	if _only == "new":
		return false
	return _phase == 0 or _phase == 2

func _is_sample() -> bool:
	if _only == "":
		return _phase >= 2
	return _phase >= 1

func _bench_done() -> bool:
	if _only == "":
		return _phase > 3
	return _phase > 1

func _median_us() -> int:
	if _samples.is_empty():
		return 0
	var ordered := _samples.duplicate()
	ordered.sort()
	return int(ordered[ordered.size() / 2])

func _close_sample() -> void:
	var wall := Time.get_ticks_usec() - _wall0
	var fps := float(SAMPLE) * 1000000.0 / float(maxi(wall, 1))
	var ms := float(_sum_us) / float(SAMPLE) / 1000.0
	var med := float(_median_us()) / 1000.0
	var ref_side := _only == "ref" or (_only == "" and _phase == 2)
	if ref_side:
		ref_ms = ms
		ref_fps = fps
		Engine.set_meta("stress_ref_median_ms", med)
	else:
		new_ms = ms
		new_fps = fps
		new_narrow = float(_sum_narrow) / float(SAMPLE)
		new_cand = float(_sum_cand) / float(SAMPLE)
		new_hits = float(_sum_hits) / float(SAMPLE)
		new_broad = float(_sum_broad) / float(SAMPLE)
		Engine.set_meta("stress_new_median_ms", med)

func _publish() -> void:
	var payload := {
		"n": _n,
		"frames": SAMPLE,
		"ref_ms": ref_ms,
		"ref_fps": ref_fps,
		"new_ms": new_ms,
		"new_fps": new_fps,
		"candidates": new_cand,
		"narrow": new_narrow,
		"broad": new_broad,
		"hits": new_hits,
		"only": _only,
		"ref_median_ms": float(Engine.get_meta("stress_ref_median_ms", 0.0)),
		"new_median_ms": float(Engine.get_meta("stress_new_median_ms", 0.0)),
	}
	print("STRESS_DONE ", JSON.stringify(payload))
	if _web:
		JavaScriptBridge.eval("window.__STRESS_DONE = %s;" % JSON.stringify(payload), true)

func _pose(frame: int) -> void:
	for i in walkers.size():
		if not walkers[i].visible:
			continue
		var nxt := _at(i, frame)
		var prev := _at(i, frame - 1) if frame > 0 else nxt
		walkers[i].global_position = nxt
		walkers[i]._step_anim(nxt - prev, 1.0 / 60.0)

func _at(i: int, frame: int) -> Vector2:
	var base: Vector2 = _bases[i]
	var t := float(frame) * 0.085 + float(i) * 0.37
	var amp := _amps[i] if i < _amps.size() else 0.0
	return base + Vector2(cos(t) * amp, sin(t) * amp * 0.85)

func _gather() -> Array:
	var vols: Array = []
	for node in get_tree().get_nodes_in_group("iso"):
		if not is_instance_valid(node) or not (node is CanvasItem):
			continue
		if not (node as CanvasItem).is_visible_in_tree():
			continue
		if not node.has_method("get_iso_volume"):
			continue
		vols.append(node.get_iso_volume())
	return vols

func _brute_pairs(vols: Array) -> int:
	var count := 0
	var n := vols.size()
	for i in n:
		var a: IsoVolume = vols[i]
		for j in range(i + 1, n):
			var b: IsoVolume = vols[j]
			if a.screen_rect.grow(DepthSolver.PAD).intersects(b.screen_rect.grow(DepthSolver.PAD)):
				count += 1
	return count

func _same(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for i in left.size():
		if int(left[i]) != int(right[i]):
			return false
	return true

func _build_ground() -> void:
	ground = TileMapLayer.new()
	ground.z_index = -4096
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_size = TILE
	var atlas := TileSetAtlasSource.new()
	var tex: Texture2D = CatalogPaths.load_tex("village/grass_a.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
	atlas.create_tile(Vector2i.ZERO)
	tileset.add_source(atlas, 0)
	ground.tile_set = tileset
	add_child(ground)
	for y in ROWS:
		for x in COLS:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)

func _build_props() -> void:
	var trees := [
		"res://art/village/tree.png",
		"res://art/village/tree_b.png",
		"res://art/village/tree_c.png",
	]
	var placed := 0
	for y in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			var h := (x * 3 + y * 5) % 7
			var cell := Vector2i(x, y)
			if h == 0:
				_prop(cell, trees[placed % trees.size()], "tree")
				placed += 1
			elif h == 1:
				_prop(cell, "res://art/village/rock.png", "rock")
			elif h == 2 and x % 2 == 0:
				_building(cell, Building.Kind.HOUSE)
			elif h == 3:
				_building(cell, Building.Kind.WALL)
			elif h == 4:
				_building(cell, Building.Kind.FARM)

func _building(cell: Vector2i, kind: Building.Kind) -> void:
	var building := Building.new()
	building.position = ground.map_to_local(cell)
	building.setup(kind, cell)
	building.always_bar = false
	add_child(building)
	_quiet(building)

func _prop(cell: Vector2i, path: String, key: String) -> void:
	var node := Node2D.new()
	node.position = ground.map_to_local(cell)
	node.set_script(load("res://scripts/iso_prop.gd"))
	node.cell = cell
	node.volume_key = key
	var sprite := Sprite2D.new()
	sprite.texture = CatalogPaths.load_tex(path)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = IsoVolume.ROCK_ANCHOR if key == "rock" else IsoVolume.TREE_ANCHOR
	sprite.z_as_relative = true
	node.add_child(sprite)
	add_child(node)
	_quiet(node)

func _build_people() -> void:
	var props: Array = []
	for node in get_tree().get_nodes_in_group("iso"):
		if node.has_method("get_iso_volume"):
			props.append(node.get_iso_volume())
	var slots := _legal_slots(props, _n)
	for i in _n:
		var base: Vector2 = slots[i % maxi(slots.size(), 1)]
		_bases.append(base)
		var v := Villager.new()
		v.position = base
		v.setup(i % 7, "f" if i % 2 == 1 else "m", 108.0)
		v.anchored = true
		add_child(v)
		_quiet(v)
		walkers.append(v)
	for i in _n:
		_amps.append(_fit_amp(i, props))

func _legal_slots(props: Array, n: int) -> Array[Vector2]:
	var chosen: Array[Vector2] = []
	for step in [1.05, 0.9, 0.78, 0.66, 0.56, 0.48, 0.42, 0.36]:
		var found: Array[Vector2] = []
		var x := 0.3
		while x < float(COLS) - 0.3:
			var y := 0.3
			while y < float(ROWS) - 0.3:
				var vol := IsoVolume.from_feet(IsoVolume.iso_to_world(Vector2(x, y)))
				var bad := false
				for prop in props:
					if vol.overlaps(prop):
						bad = true
						break
				if not bad:
					found.append(IsoVolume.iso_to_world(Vector2(x, y)))
				y += float(step)
			x += float(step)
		if found.size() >= n:
			print("STRESS_GRID step ", step, " slots ", found.size())
			return found
		chosen = found
	print("STRESS_GRID fallback slots ", chosen.size())
	return chosen

func _fit_amp(i: int, props: Array) -> float:
	var here := IsoVolume.world_to_iso(_bases[i])
	var nearest := 4.0
	for j in _bases.size():
		if j == i:
			continue
		nearest = minf(nearest, here.distance_to(IsoVolume.world_to_iso(_bases[j])))
	var slack := maxf(nearest - IsoVolume.walker_separation(Vector2.RIGHT), 0.0)
	var amp := slack * 0.3 * IsoVolume.TILE
	var guard := amp
	for _try in 6:
		var ok := true
		var reach := guard * 1.15
		for k in 24:
			var ang := TAU * float(k) / 24.0
			var iso := here + Vector2(cos(ang) * reach, sin(ang) * reach * 0.85) / IsoVolume.TILE
			var vol := IsoVolume.from_feet(IsoVolume.iso_to_world(iso))
			for prop in props:
				if vol.overlaps(prop):
					ok = false
					break
			if not ok:
				break
		if ok:
			return guard
		guard *= 0.55
	return 0.0

func _quiet(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children():
		_quiet(child)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(0.42, 0.42)
	camera.position = ground.map_to_local(Vector2i(COLS / 2, ROWS / 2))
	add_child(camera)
	camera.make_current()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	var top := Panel.new()
	top.theme = theme
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var shift := 64.0 if hosted else 0.0
	top.offset_top = shift
	top.offset_bottom = 132.0 + shift
	top.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	layer.add_child(top)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 8
	box.offset_right = -12 if hosted else -108
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	top.add_child(box)
	_title = Label.new()
	_title.theme = theme
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	box.add_child(_title)
	_body = Label.new()
	_body.theme = theme
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	box.add_child(_body)
	if hosted:
		return
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
	lang.offset_left = -96
	lang.offset_top = 12
	lang.offset_right = -12
	lang.offset_bottom = 52
	lang.add_theme_font_size_override("font_size", 16)
	_style_button(lang)
	lang.pressed.connect(func() -> void: Locale.toggle())
	layer.add_child(lang)
	lang.text = Locale.text("lang.switch")

func _refresh_copy() -> void:
	if _title == null:
		return
	_title.text = "%s  N=%d" % [Locale.text("stress.title"), _n]
	if _done:
		_body.text = "%s\n%s" % [Locale.format("stress.done", [_n, ref_ms, ref_fps, new_ms, new_fps]), Locale.text("stress.help")]
	elif _phase <= 1:
		_body.text = Locale.text("stress.warm")
	elif _phase == 2:
		_body.text = Locale.text("stress.phase_ref")
	else:
		_body.text = Locale.text("stress.phase_new")
	var back := find_child("BackButton", true, false) as Button
	if back:
		back.text = Locale.text("lab.back")
	var lang := find_child("LangButton", true, false) as Button
	if lang:
		lang.text = Locale.text("lang.switch")
		lang.tooltip_text = Locale.text("tip.lang")

func _back_to_game() -> void:
	Engine.set_meta("skip_stress", true)
	Engine.set_meta("skip_lab", true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _box(Color(0.16, 0.22, 0.16, 1), Color(0.54, 0.44, 0.22)))
	btn.add_theme_stylebox_override("hover", _box(Color(0.22, 0.3, 0.2, 1), Color(0.9, 0.78, 0.4)))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.14, 0.1, 1), Color(0.9, 0.78, 0.4)))
	btn.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.86))
