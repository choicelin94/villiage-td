extends Node2D

const COLS := 20
const ROWS := 20

var _font: Font
var _theme: Theme
var _state: Dictionary = {}
var _tab := "diff"
var _map_mode := "spawn"
var _build_kind := "HOUSE"
var _unit_kind := "villager"
var _title: Label
var _status: Label
var _body: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 18
	for type_name in ["Label", "Button", "LineEdit", "SpinBox", "OptionButton"]:
		_theme.set_font("font", type_name, _font)
	_state = Balance.editor_state()
	_build_chrome()
	Locale.changed.connect(_show_tab.bind(_tab))
	_show_tab("diff")
	if OS.get_environment("TD_BENCH") == "1":
		_bench_probe()

func _bench_probe() -> void:
	Locale.set_code("zh")
	_show_tab("map")
	await get_tree().process_frame
	await get_tree().process_frame
	var save := find_child("SaveButton", true, false)
	var map := find_child("TabMap", true, false)
	var no_lab := find_child("LabModeButton", true, false) == null
	var no_stress := find_child("StressModeButton", true, false) == null
	var title_ok := _title != null and _title.text == Locale.text("bench.title")
	var roster_ok := Balance.starter_units().size() >= 5 and Balance.spawns().size() >= 5
	var passed := save != null and map != null and no_lab and no_stress and title_ok and roster_ok
	print("BENCH_OK ", passed, " save=", save != null, " map=", map != null, " lab=", no_lab, " stress=", no_stress, " title=", _title.text if _title else "", " roster=", Balance.starter_units().size(), " spawns=", Balance.spawns().size())
	get_tree().quit(0 if passed else 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
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

func _tab_button(tabs: HBoxContainer, tab: String, key: String, node_name: String = "") -> void:
	var btn := _button(node_name if node_name != "" else "Tab" + tab, Locale.text(key))
	btn.pressed.connect(_show_tab.bind(tab))
	tabs.add_child(btn)

func _show_tab(tab: String = "diff") -> void:
	_tab = tab
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
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	_body.add_child(modes)
	for pair in [["spawn", "bench.mode.spawn"], ["build", "bench.mode.build"], ["unit", "bench.mode.unit"]]:
		var btn := _button("", Locale.text(str(pair[1])))
		if _map_mode == str(pair[0]):
			btn.modulate = Color(1, 0.95, 0.7)
		btn.pressed.connect(_set_map_mode.bind(str(pair[0])))
		modes.add_child(btn)
	if _map_mode == "build":
		var kinds := OptionButton.new()
		kinds.theme = _theme
		for kind_name in ["WALL", "SPEAR", "FIRE", "HOUSE", "FARM", "WORKSHOP", "LUMBER", "SPEAR_BARRACKS", "GUN_BARRACKS"]:
			kinds.add_item(kind_name)
			kinds.set_item_metadata(kinds.item_count - 1, kind_name)
			if kind_name == _build_kind:
				kinds.select(kinds.item_count - 1)
		kinds.item_selected.connect(func(idx: int) -> void: _build_kind = str(kinds.get_item_metadata(idx)))
		_body.add_child(kinds)
	elif _map_mode == "unit":
		var units := OptionButton.new()
		units.theme = _theme
		for id in ["villager", "spearman", "gunner", "engineer"]:
			units.add_item(id)
			units.set_item_metadata(units.item_count - 1, id)
			if id == _unit_kind:
				units.select(units.item_count - 1)
		units.item_selected.connect(func(idx: int) -> void: _unit_kind = str(units.get_item_metadata(idx)))
		_body.add_child(units)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_body.add_child(grid)
	for y in ROWS:
		for x in COLS:
			var btn := Button.new()
			btn.theme = _theme
			btn.custom_minimum_size = Vector2(22, 22)
			btn.focus_mode = Control.FOCUS_NONE
			btn.text = _cell_mark(x, y)
			_style_button(btn)
			btn.modulate = _cell_color(x, y)
			btn.pressed.connect(_tap_cell.bind(x, y))
			grid.add_child(btn)

func _set_map_mode(mode: String) -> void:
	_map_mode = mode
	_show_tab("map")

func _cell_mark(x: int, y: int) -> String:
	if _spawn_at(x, y):
		return "敌"
	if _building_at(x, y) != "":
		return "建"
	if _unit_at(x, y) != "":
		return "人"
	return ""

func _cell_color(x: int, y: int) -> Color:
	if _spawn_at(x, y):
		return Color(1, 0.45, 0.4)
	if _building_at(x, y) != "":
		return Color(0.95, 0.78, 0.4)
	if _unit_at(x, y) != "":
		return Color(0.55, 0.85, 1)
	if x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1:
		return Color(0.35, 0.4, 0.32)
	return Color(0.75, 0.82, 0.62)

func _tap_cell(x: int, y: int) -> void:
	if _map_mode == "spawn":
		if _spawn_at(x, y):
			_remove_pair(_state.spawns, x, y)
		else:
			(_state.spawns as Array).append([x, y])
	elif _map_mode == "build":
		if x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1:
			return
		if _building_at(x, y) != "":
			_remove_cell_entry(_state.starter_buildings, x, y)
		else:
			(_state.starter_buildings as Array).append({"kind": _build_kind, "cell": [x, y]})
	else:
		if x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1:
			return
		if _unit_at(x, y) != "":
			_remove_cell_entry(_state.starter_units, x, y)
		else:
			(_state.starter_units as Array).append({"unit": _unit_kind, "cell": [x, y], "sex": "m"})
	_show_tab("map")

func _spawn_at(x: int, y: int) -> bool:
	return _pair_in(_state.get("spawns", []), x, y)

func _building_at(x: int, y: int) -> String:
	return _entry_at(_state.get("starter_buildings", []), x, y, "kind")

func _unit_at(x: int, y: int) -> String:
	return _entry_at(_state.get("starter_units", []), x, y, "unit")

func _pair_in(rows: Array, x: int, y: int) -> bool:
	for item in rows:
		if item is Array and item.size() >= 2 and int(item[0]) == x and int(item[1]) == y:
			return true
	return false

func _entry_at(rows: Array, x: int, y: int, key: String) -> String:
	for item in rows:
		if item is Dictionary:
			var cell = item.get("cell", [])
			if cell is Array and cell.size() >= 2 and int(cell[0]) == x and int(cell[1]) == y:
				return str(item.get(key, ""))
	return ""

func _remove_pair(rows: Array, x: int, y: int) -> void:
	for i in range(rows.size() - 1, -1, -1):
		var item = rows[i]
		if item is Array and item.size() >= 2 and int(item[0]) == x and int(item[1]) == y:
			rows.remove_at(i)

func _remove_cell_entry(rows: Array, x: int, y: int) -> void:
	for i in range(rows.size() - 1, -1, -1):
		var item = rows[i]
		if item is Dictionary:
			var cell = item.get("cell", [])
			if cell is Array and cell.size() >= 2 and int(cell[0]) == x and int(cell[1]) == y:
				rows.remove_at(i)

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
	Balance.save_editor_state(_state)
	_state = Balance.editor_state()
	if _status:
		_status.text = Locale.text("bench.saved")

func _reset() -> void:
	Balance.reset_editor_state()
	_state = Balance.editor_state()
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
