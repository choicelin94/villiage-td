extends Node2D

var _font: Font
var _theme: Theme
var _doc: ConfigDocument
var _state: Dictionary = {}
var _tab := "diff"
var _title: Label
var _status: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _narrow_root: Control
var _narrow_card: PanelContainer
var _narrow_box: VBoxContainer
var _narrow_label: Label
var _narrow_back: Button
var _narrow_on := false

func _ready() -> void:
	_font = CatalogPaths.load_font()
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 18
	for type_name in ["Label", "Button", "LineEdit", "SpinBox", "OptionButton"]:
		_theme.set_font("font", type_name, _font)
	_doc = ConfigDocument.new()
	_doc.pull()
	_state = _doc.data
	_build_chrome()
	Locale.changed.connect(_show_tab.bind(_tab))
	Locale.changed.connect(_apply_narrow_copy)
	get_viewport().size_changed.connect(_apply_narrow_lock)
	_show_tab("diff")
	_apply_narrow_lock()
	if OS.get_environment("TD_BENCH") == "1":
		_bench_probe()

func _bench_probe() -> void:
	Locale.set_code("zh")
	get_window().size = Vector2i(1100, 1400)
	await get_tree().process_frame
	_apply_narrow_lock()
	_show_tab("map")
	await get_tree().process_frame
	await get_tree().process_frame
	var save := find_child("SaveButton", true, false)
	var map := find_child("TabMap", true, false)
	var board := find_child("MapBoard", true, false)
	var popup := find_child("PlacePopup", true, false)
	var no_lab := find_child("LabModeButton", true, false) == null
	var no_stress := find_child("StressModeButton", true, false) == null
	var title_ok := _title != null and _title.text == Locale.text("bench.title")
	var roster_ok := Balance.starter_units().size() >= 5 and Balance.spawns().size() == 3 and Balance.spawn_rects().size() == 1
	var layout_ok := _probe_layout()
	var thumb_ok := _probe_thumbs()
	var edit_ok := board != null and board.has_method("probe_edits") and bool(board.probe_edits())
	var mask: Color = MapPlan.SPAWN_MASK
	var mask_ok := mask.r > 0.75 and mask.g < 0.35 and mask.b < 0.35 and mask.a > 0.35 and mask.a < 0.8
	_hide_popup()
	var passed := save != null and map != null and board != null and popup != null and no_lab and no_stress and title_ok and roster_ok and layout_ok and thumb_ok and edit_ok and mask_ok
	print("BENCH_OK ", passed, " save=", save != null, " map=", map != null, " board=", board != null, " popup=", popup != null, " lab=", no_lab, " stress=", no_stress, " title=", _title.text if _title else "", " roster=", Balance.starter_units().size(), " spawns=", Balance.spawns().size(), " layout=", layout_ok, " thumbs=", thumb_ok, " edit=", edit_ok, " mask=", mask_ok)
	get_window().size = Vector2i(1100, 1400)
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll and board is Control:
		_scroll.ensure_control_visible(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image and not image.is_empty():
		image.save_png("/tmp/bench-map.png")
		var reds := 0
		var run := 0
		var longest := 0
		for y in range(0, image.get_height(), 2):
			run = 0
			for x in range(0, image.get_width(), 2):
				var pixel := image.get_pixel(x, y)
				if pixel.r > 0.5 and pixel.r > pixel.g + 0.22 and pixel.r > pixel.b + 0.22:
					reds += 1
					run += 1
					if run > longest:
						longest = run
				else:
					run = 0
		print("BENCH_SHOT ", image.get_width(), " ", image.get_height(), " reds=", reds, " run=", longest)
		if reds < 8 or longest < 24:
			passed = false
	if board != null and board.has_method("present_multi_demo"):
		board.present_multi_demo()
		await get_tree().process_frame
		await get_tree().process_frame
		var multi := get_viewport().get_texture().get_image()
		if multi and not multi.is_empty():
			multi.save_png("/tmp/map-multi.png")
		if board.has_method("settle_multi_demo"):
			board.settle_multi_demo()
			await get_tree().process_frame
			await get_tree().process_frame
			var settled := get_viewport().get_texture().get_image()
			if settled and not settled.is_empty():
				settled.save_png("/tmp/map-multi-settled.png")
		if board.has_method("end_multi_demo"):
			board.end_multi_demo()
	var narrow_ok := await _probe_narrow_lock()
	passed = passed and narrow_ok
	get_tree().quit(0 if passed else 1)

func _probe_layout() -> bool:
	var north := MapPlan.cells_of_rect(MapPlan.rect_from_middle(Vector2i(10, 0)))
	var west := MapPlan.cells_of_rect(MapPlan.rect_from_middle(Vector2i(0, 8)))
	var south := MapPlan.rect_from_middle(Vector2i(4, 19))
	var east := MapPlan.cells_of_rect(MapPlan.rect_from_middle(Vector2i(19, 3)))
	var corner := MapPlan.rect_from_middle(Vector2i(0, 0)).is_empty() and MapPlan.rect_from_middle(Vector2i(19, 19)).is_empty()
	var legacy := MapPlan.cells_from_rects(MapPlan.rects_from_cells([[8, 0], [9, 0], [10, 0], [11, 0], [12, 0]]))
	var legacy_set := {}
	for item in legacy:
		legacy_set["%d,%d" % [int(item[0]), int(item[1])]] = true
	var legacy_ok := legacy_set.size() == 5
	for x in [8, 9, 10, 11, 12]:
		if not legacy_set.has("%d,0" % x):
			legacy_ok = false
	var north_ok := north.size() == 3 and north[0] == Vector2i(9, 0) and north[1] == Vector2i(10, 0) and north[2] == Vector2i(11, 0)
	var west_ok := west.size() == 3 and west[0] == Vector2i(0, 7) and west[1] == Vector2i(0, 8) and west[2] == Vector2i(0, 9)
	var south_ok := str(south.get("edge", "")) == "south"
	var east_ok := east.size() == 3 and east[1] == Vector2i(19, 3)
	var ok := north_ok and west_ok and south_ok and east_ok and corner and legacy_ok
	print("BENCH_LAYOUT north=", north_ok, " west=", west_ok, " south=", south_ok, " east=", east_ok, " corner=", corner, " legacy=", legacy_ok, " legacy_n=", legacy_set.size())
	return ok

func _probe_thumbs() -> bool:
	var ok := true
	for id in ["Thumb_unit_villager", "Thumb_unit_spearman", "Thumb_unit_gunner", "Thumb_unit_engineer", "Thumb_build_HOUSE", "Thumb_build_WALL", "Thumb_build_LUMBER", "Thumb_prop_tree", "Thumb_prop_rock"]:
		if find_child(id, true, false) != null:
			print("BENCH_THUMB still present ", id)
			ok = false
	return ok

func _input(event: InputEvent) -> void:
	if not _narrow_on or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		return
	if get_viewport().gui_get_focus_owner() == _narrow_back:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		var board := find_child("MapBoard", true, false)
		if board and board.has_method("inspector_open") and bool(board.inspector_open()):
			board.close_inspector()
			get_viewport().set_input_as_handled()
			return
		_back_to_game()

func _build_chrome() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	layer.add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	column.add_child(bar)
	var back := _button("BackButton", Locale.text("lab.back"))
	back.pressed.connect(_back_to_game)
	bar.add_child(back)
	_title = Label.new()
	_title.theme = _theme
	_title.text = Locale.text("bench.title")
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	var save := _button("SaveButton", Locale.text("bench.save"))
	save.pressed.connect(_save)
	bar.add_child(save)
	var reset := _button("ResetButton", Locale.text("bench.reset"))
	reset.pressed.connect(_reset)
	bar.add_child(reset)
	var lang := _button("LangButton", Locale.text("lang.switch"))
	lang.pressed.connect(func() -> void: Locale.toggle())
	bar.add_child(lang)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	_tab_button(tabs, "diff", "bench.tab.diff")
	_tab_button(tabs, "people", "bench.tab.people")
	_tab_button(tabs, "map", "bench.tab.map", "TabMap")
	_tab_button(tabs, "stats", "bench.tab.stats")
	_tab_button(tabs, "waves", "bench.tab.waves")
	_status = Label.new()
	_status.theme = _theme
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	column.add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	_build_narrow_lock()

func _build_narrow_lock() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NarrowLockLayer"
	layer.layer = 80
	add_child(layer)
	_narrow_root = Control.new()
	_narrow_root.name = "NarrowLock"
	_narrow_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narrow_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrow_root.visible = false
	layer.add_child(_narrow_root)
	var dim := ColorRect.new()
	dim.name = "NarrowDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.22, 0.24, 0.23, 0.74)
	_narrow_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_narrow_root.add_child(center)
	_narrow_card = PanelContainer.new()
	_narrow_card.name = "NarrowCard"
	_narrow_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.12, 0.14, 0.12, 0.96)
	plate.border_color = Color(0.78, 0.72, 0.58)
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(14)
	plate.content_margin_left = 22
	plate.content_margin_right = 22
	plate.content_margin_top = 20
	plate.content_margin_bottom = 18
	_narrow_card.add_theme_stylebox_override("panel", plate)
	center.add_child(_narrow_card)
	_narrow_box = VBoxContainer.new()
	_narrow_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_narrow_card.add_child(_narrow_box)
	_narrow_label = Label.new()
	_narrow_label.name = "NarrowMessage"
	_narrow_label.theme = _theme
	_narrow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrow_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	_narrow_box.add_child(_narrow_label)
	_narrow_back = _button("NarrowBack", Locale.text("lab.back"))
	_narrow_back.pressed.connect(_back_to_game)
	_narrow_box.add_child(_narrow_back)
	_apply_narrow_copy()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_narrow_lock()

func _css_window_size() -> Vector2:
	# Web reports the canvas backing store. Divide by the screen scale so a
	# phone at devicePixelRatio 3 is judged in CSS pixels, same as the browser.
	var px := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("web"):
		var ratio := DisplayServer.screen_get_scale()
		if ratio >= 0.5:
			px /= ratio
	return px

func _narrow_locked() -> bool:
	var css := _css_window_size()
	if css.x < 8.0 or css.y < 8.0:
		return false
	# Width under 900 covers a portrait phone and a squeezed desktop window.
	# Short side under 480 covers a landscape phone whose width is just over 900.
	# The design viewport is 720 tall, so the short side must stay below that.
	if css.x < 900.0:
		return true
	return minf(css.x, css.y) < 480.0

func _viewport_units_per_css() -> float:
	var css := _css_window_size()
	var view := get_viewport_rect().size
	if css.x < 8.0 or view.x < 8.0:
		return 1.0
	return view.x / css.x

func _apply_narrow_copy() -> void:
	if _narrow_label:
		_narrow_label.text = Locale.text("bench.narrow")
	if _narrow_back:
		_narrow_back.text = Locale.text("lab.back")

func _apply_narrow_lock() -> void:
	if _narrow_root == null:
		return
	var locked := _narrow_locked()
	_narrow_on = locked
	_narrow_root.visible = locked
	_narrow_root.mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	if not locked:
		return
	_apply_narrow_copy()
	var k := _viewport_units_per_css()
	var css := _css_window_size()
	var card_w := clampf(css.x * 0.86, 240.0, 420.0) * k
	_narrow_card.custom_minimum_size = Vector2(card_w, 0)
	_narrow_label.custom_minimum_size = Vector2(maxf(card_w - 64.0 * k, 160.0 * k), 0)
	_narrow_label.add_theme_font_size_override("font_size", int(round(22.0 * k)))
	_narrow_back.add_theme_font_size_override("font_size", int(round(20.0 * k)))
	_narrow_back.custom_minimum_size = Vector2(0, 52.0 * k)
	_narrow_box.add_theme_constant_override("separation", int(round(18.0 * k)))

func _probe_narrow_lock() -> bool:
	Locale.set_code("zh")
	var phone_ok := await _probe_narrow_at(Vector2i(390, 844), true)
	var land_ok := await _probe_narrow_at(Vector2i(932, 430), true)
	var squeezed_ok := await _probe_narrow_at(Vector2i(800, 700), true)
	var wide_ok := await _probe_narrow_at(Vector2i(1280, 800), false)
	var ok := phone_ok and land_ok and squeezed_ok and wide_ok
	print("BENCH_NARROW ok=", ok, " phone=", phone_ok, " land=", land_ok, " squeezed=", squeezed_ok, " wide=", wide_ok)
	return ok

func _probe_narrow_at(window_size: Vector2i, expect_lock: bool) -> bool:
	get_window().size = window_size
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_narrow_lock()
	await get_tree().process_frame
	await get_tree().process_frame
	var css := _css_window_size()
	var shown := _narrow_root != null and _narrow_root.visible and _narrow_on
	var text_ok := true
	var back_ok := true
	var blocked := true
	var back_click := true
	if expect_lock:
		text_ok = _narrow_label != null and _narrow_label.text == "工作台请在电脑浏览器中打开使用。"
		back_ok = _narrow_back != null and _narrow_back.text == "返回游戏" and _narrow_back.visible
		var save := find_child("SaveButton", true, false) as Button
		if save == null:
			blocked = false
		else:
			var hits := {"n": 0}
			var on_save := func() -> void: hits["n"] = int(hits["n"]) + 1
			save.pressed.connect(on_save)
			_probe_click(save.get_global_rect().get_center())
			await get_tree().process_frame
			blocked = int(hits["n"]) == 0
			save.pressed.disconnect(on_save)
		if _narrow_back == null:
			back_click = false
		else:
			var backs := {"n": 0}
			var on_back := func() -> void: backs["n"] = int(backs["n"]) + 1
			_narrow_back.pressed.disconnect(_back_to_game)
			_narrow_back.pressed.connect(on_back)
			_probe_click(_narrow_back.get_global_rect().get_center())
			await get_tree().process_frame
			back_click = int(backs["n"]) == 1
			_narrow_back.pressed.disconnect(on_back)
			_narrow_back.pressed.connect(_back_to_game)
		if window_size == Vector2i(390, 844):
			var image := get_viewport().get_texture().get_image()
			if image and not image.is_empty():
				image.save_png("/tmp/bench-narrow.png")
			print("BENCH_NARROW_RECT root=", _narrow_root.size, " card=", _narrow_card.get_global_rect(), " back=", _narrow_back.get_global_rect(), " font=", _narrow_label.get_theme_font_size("font_size"))
	var ok := shown == expect_lock and text_ok and back_ok and blocked and back_click
	print("BENCH_NARROW_AT ", window_size, " css=", css, " win=", DisplayServer.window_get_size(), " scale=", DisplayServer.screen_get_scale(), " view=", get_viewport_rect().size, " shown=", shown, " text=", text_ok, " back=", back_ok, " blocked=", blocked, " back_click=", back_click)
	return ok

func _probe_click(at: Vector2) -> void:
	# push_input expects window coordinates and converts them into the stretched viewport.
	var screen: Vector2 = get_viewport().get_screen_transform() * at
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen
	get_viewport().push_input(release)

func _tab_button(tabs: HBoxContainer, tab: String, key: String, node_name: String = "") -> void:
	var btn := _button(node_name if node_name != "" else "Tab" + tab, Locale.text(key))
	btn.pressed.connect(_show_tab.bind(tab))
	tabs.add_child(btn)

func _show_tab(tab: String = "diff") -> void:
	_tab = tab
	_hide_popup()
	if _title:
		_title.text = Locale.text("bench.title")
	for child in _body.get_children():
		child.queue_free()
	match tab:
		"people":
			_fill_people()
		"map":
			_fill_map()
		"stats":
			_fill_stats()
		"waves":
			_fill_waves()
		_:
			_fill_diff()

func _fill_diff() -> void:
	_note(Locale.text("bench.diff_help"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	for id in ["easy", "normal", "hard"]:
		var btn := _button("", Locale.text("diff." + id))
		if str(_state.get("difficulty_id", "normal")) == id:
			btn.modulate = Color(1, 0.95, 0.7)
		btn.pressed.connect(_pick_diff.bind(id))
		row.add_child(btn)
	var preset: Dictionary = (_state.get("presets", {}) as Dictionary).get(str(_state.get("difficulty_id", "normal")), {})
	_spin_row("生命倍率", ["presets", str(_state.get("difficulty_id", "normal")), "hp"], float(preset.get("hp", 1)), 0.05, 0.2, 3.0)
	_spin_row("数量倍率", ["presets", str(_state.get("difficulty_id", "normal")), "count"], float(preset.get("count", 1)), 0.05, 0.2, 3.0)
	_spin_row("移速倍率", ["presets", str(_state.get("difficulty_id", "normal")), "speed"], float(preset.get("speed", 1)), 0.05, 0.2, 3.0)
	_spin_row("金币倍率", ["presets", str(_state.get("difficulty_id", "normal")), "gold"], float(preset.get("gold", 1)), 0.05, 0.2, 3.0)

func _pick_diff(id: String) -> void:
	_state["difficulty_id"] = id
	_show_tab("diff")

func _fill_people() -> void:
	_note(Locale.text("bench.people_help"))
	var settle: Dictionary = _state.get("settlement", {})
	_spin_row("入驻概率", ["settlement", "chance"], float(settle.get("chance", 0.65)), 0.05, 0.0, 1.0)
	_spin_row("每波上限", ["settlement", "max_per_wave"], float(settle.get("max_per_wave", 3)), 1, 1, 8)
	var slots: Dictionary = _state.get("slots", {})
	_spin_row("房屋村民空缺", ["slots", "house"], float(slots.get("house", 4)), 1, 0, 12)
	_spin_row("矛兵营空缺", ["slots", "spear_barracks"], float(slots.get("spear_barracks", 2)), 1, 0, 12)
	_spin_row("枪兵营空缺", ["slots", "gun_barracks"], float(slots.get("gun_barracks", 2)), 1, 0, 12)
	_spin_row("工坊工兵空缺", ["slots", "workshop"], float(slots.get("workshop", 2)), 1, 0, 12)
	_spin_row("木坊驻守上限", ["slots", "lumber_mill"], float(slots.get("lumber_mill", 4)), 1, 0, 8)
	_body.add_child(_label("初始人口与站位"))
	var roster: Array = _state.get("starter_units", [])
	for i in roster.size():
		var item: Dictionary = roster[i]
		var cell = item.get("cell", [0, 0])
		var line := "%s  (%s, %s)" % [str(item.get("unit", "")), str(cell[0]), str(cell[1])]
		var btn := _button("", "移除 " + line)
		btn.pressed.connect(_remove_roster.bind(i))
		_body.add_child(btn)
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 6)
	_body.add_child(add)
	var unit := OptionButton.new()
	unit.theme = _theme
	for id in ["villager", "spearman", "gunner", "engineer"]:
		unit.add_item(Locale.text("unit." + id) if Locale.text("unit." + id) != "unit." + id else id)
		unit.set_item_metadata(unit.item_count - 1, id)
	add.add_child(unit)
	var sx := _bare_spin(10, 1, 0, 19)
	var sy := _bare_spin(15, 1, 0, 19)
	add.add_child(sx)
	add.add_child(sy)
	var plus := _button("", "添加")
	plus.pressed.connect(func() -> void:
		var id := str(unit.get_item_metadata(unit.selected))
		var cell := [int(sx.value), int(sy.value)]
		(_state.get("starter_units", []) as Array).append({"unit": id, "cell": cell, "sex": "m"})
		_show_tab("people")
	)
	add.add_child(plus)

func _remove_roster(index: int) -> void:
	var roster: Array = _state.get("starter_units", [])
	if index >= 0 and index < roster.size():
		roster.remove_at(index)
	_show_tab("people")

func _fill_map() -> void:
	_note(Locale.text("bench.map_help"))
	var board := MapBoard.new()
	board.name = "MapBoard"
	board.setup(_state, _font)
	board.hint_changed.connect(_show_hint)
	_body.add_child(board)

func _hide_popup() -> void:
	var board := find_child("MapBoard", true, false)
	if board and board.has_method("close_inspector"):
		board.close_inspector()

func _show_hint(text: String) -> void:
	if _status:
		_status.text = text

func _fill_stats() -> void:
	_note("击杀只掉金币。木坊产量 = 每名村民产量 × 驻守村民，按间隔跳。")
	var econ: Dictionary = _state.get("economy", {})
	_spin_row("开局木材", ["economy", "start_wood"], float(econ.get("start_wood", 100)), 1, 0, 9999)
	_spin_row("开局金币", ["economy", "start_gold"], float(econ.get("start_gold", 70)), 1, 0, 9999)
	_spin_row("清波木材", ["economy", "wave_clear_wood"], float(econ.get("wave_clear_wood", 8)), 1, 0, 999)
	_spin_row("清波金币", ["economy", "wave_clear_gold"], float(econ.get("wave_clear_gold", 14)), 1, 0, 999)
	var lumber: Dictionary = _state.get("lumber", {})
	_spin_row("木坊每人产量", ["lumber", "rate_per_villager"], float(lumber.get("rate_per_villager", 1)), 1, 0, 20)
	_spin_row("木坊间隔秒", ["lumber", "interval"], float(lumber.get("interval", 5)), 0.5, 0.5, 60)
	var fight: Dictionary = _state.get("combat", {})
	_spin_row("锁敌秒", ["combat", "target_hold"], float(fight.get("target_hold", 1.2)), 0.1, 0.2, 8)
	_spin_row("换目标阈值", ["combat", "switch_margin"], float(fight.get("switch_margin", 0.72)), 0.02, 0.2, 1)
	_spin_row("重寻路秒", ["combat", "repath"], float(fight.get("repath", 0.6)), 0.05, 0.15, 4)
	_spin_row("卡住重锁秒", ["combat", "stuck"], float(fight.get("stuck", 0.9)), 0.05, 0.3, 4)
	_body.add_child(_label("单位"))
	var units: Dictionary = _state.get("units", {})
	for id in units.keys():
		_body.add_child(_label(str(id)))
		_spin_row("生命", ["units", id, "hp"], float(units[id].get("hp", 1)), 1, 1, 9999)
		_spin_row("攻击", ["units", id, "attack"], float(units[id].get("attack", 0)), 1, 0, 999)
		_spin_row("移速", ["units", id, "move_speed"], float(units[id].get("move_speed", 0)), 1, 0, 400)
	_body.add_child(_label("敌人（木材赏金固定为 0）"))
	var enemies: Dictionary = _state.get("enemies", {})
	for id in enemies.keys():
		_body.add_child(_label(str(id)))
		_spin_row("生命", ["enemies", id, "hp"], float(enemies[id].get("hp", 1)), 1, 1, 9999)
		_spin_row("金币", ["enemies", id, "gold_reward"], float(enemies[id].get("gold_reward", 0)), 1, 0, 999)
	_body.add_child(_label("建筑"))
	var buildings: Dictionary = _state.get("buildings", {})
	for id in buildings.keys():
		_body.add_child(_label(str(id)))
		_spin_row("生命", ["buildings", id, "hp"], float(buildings[id].get("hp", 1)), 1, 1, 9999)
		_spin_row("木材费用", ["buildings", id, "cost_wood"], float(buildings[id].get("cost_wood", 0)), 1, 0, 999)
		_spin_row("金币费用", ["buildings", id, "cost_gold"], float(buildings[id].get("cost_gold", 0)), 1, 0, 999)

func _fill_waves() -> void:
	_note("每一波的基准生命、数量。难度倍率在开局再乘一次。")
	var waves: Array = _state.get("waves", [])
	for i in waves.size():
		var wave: Dictionary = waves[i]
		_body.add_child(_label("第 %d 波" % [i + 1]))
		_spin_row("基准生命", ["waves", i, "hp"], float(wave.get("hp", 1)), 1, 1, 9999)
		_spin_row("普通", ["waves", i, "normal"], float(wave.get("normal", 0)), 1, 0, 40)
		_spin_row("迅捷", ["waves", i, "fast"], float(wave.get("fast", 0)), 1, 0, 40)
		_spin_row("精锐", ["waves", i, "elite"], float(wave.get("elite", 0)), 1, 0, 20)
		_spin_row("首领", ["waves", i, "boss"], float(wave.get("boss", 0)), 1, 0, 4)

func _spin_row(label: String, path: Array, value: float, step: float, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var name := _label(label)
	name.custom_minimum_size = Vector2(140, 0)
	row.add_child(name)
	var spin := _bare_spin(value, step, lo, hi)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(next: float) -> void: _write_path(path, next if step < 1.0 else int(round(next))))
	row.add_child(spin)

func _bare_spin(value: float, step: float, lo: float, hi: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.theme = _theme
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.rounded = step >= 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(120, 40)
	return spin

func _write_path(path: Array, value) -> void:
	var node = _state
	for i in path.size() - 1:
		var key = path[i]
		if node is Dictionary:
			if not (node as Dictionary).has(key):
				return
			node = node[key]
		elif node is Array:
			node = node[int(key)]
		else:
			return
	var leaf = path[path.size() - 1]
	if node is Dictionary:
		node[leaf] = value
	elif node is Array:
		node[int(leaf)] = value

func _save() -> void:
	var rects: Array = _state.get("spawn_rects", []) if _state.get("spawn_rects", []) is Array else []
	var cleaned := MapPlan.clean_rects(rects)
	if cleaned.is_empty():
		cleaned = MapPlan.default_rects()
	elif cleaned.size() > 1:
		cleaned = [cleaned[0]]
	_state["spawn_rects"] = cleaned
	_state["spawns"] = MapPlan.cells_from_rects(cleaned)
	if _state.get("roads") is Array:
		_state["roads"] = MapPlan.clean_roads(_state["roads"])
	_doc.data = _state
	_doc.save()
	_state = _doc.data
	if _status:
		_status.text = Locale.text("bench.saved")
	_show_tab(_tab)

func _reset() -> void:
	_doc.reset()
	_state = _doc.data
	if _status:
		_status.text = Locale.text("bench.reset")
	_show_tab(_tab)

func _back_to_game() -> void:
	Engine.max_fps = 60
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _note(text: String) -> void:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)

func _label(text: String) -> Label:
	var label := Label.new()
	label.theme = _theme
	label.text = text
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	return label

func _button(node_name: String, text: String) -> Button:
	var btn := Button.new()
	if node_name != "":
		btn.name = node_name
	btn.theme = _theme
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 40)
	_style_button(btn)
	return btn

func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _box(Color(0.16, 0.22, 0.16), Color(0.54, 0.44, 0.22)))
	btn.add_theme_stylebox_override("hover", _box(Color(0.22, 0.3, 0.2), Color(0.9, 0.78, 0.4)))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.14, 0.1), Color(0.9, 0.78, 0.4)))
	btn.add_theme_color_override("font_color", Color(1, 0.93, 0.75))

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
