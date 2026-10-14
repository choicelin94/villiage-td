class_name Hud
extends CanvasLayer

signal start_pressed
signal restart_pressed
signal zoom_in_pressed
signal zoom_out_pressed
signal place_requested(kind: int)
signal sell_pressed
signal staff_selected(person: Villager)
signal staff_dismissed(person: Villager)
signal codex_pressed
signal bench_pressed

var _font: Font
var _theme: Theme
var _narrow := false
var _flash_t := 0.0

var _top: Panel
var _bottom: Panel
var _hint: Label
var _wood: StatChip
var _gold: StatChip
var _pop: StatChip
var _beds: StatChip
var _walls: StatChip
var _wave: StatChip
var _core: StatChip
var _start: Button
var _leave: Button
var _zoom_in: Button
var _zoom_out: Button
var _phone := false
var _panel: Panel
var _scroll: ScrollContainer
var _list: VBoxContainer
var _end: Control
var _end_title: Label
var _end_body: Label
var _again: Button
var _lang: Button
var _help: Button
var _menu: Panel
var _catcher: Control
var _codex_btn: Button
var _bench_btn: Button
var _menu_open := false
var _top_box: BoxContainer
var _won := false

var _ground := Vector2i(-1, -1)
var _ground_open := false
var _inspected: Building = null

func _ready() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	layer = 10
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 18
	for type_name in ["Label", "Button", "RichTextLabel", "LineEdit", "TooltipLabel"]:
		_theme.set_font("font", type_name, _font)
	_build_top()
	_build_bottom()
	_build_actions()
	_build_panel()
	_build_end()
	_build_lang()
	_build_help()
	Locale.changed.connect(_on_language)
	_on_language()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0 and _end.visible == false:
			_hint.text = _idle_hint()
	if _inspected != null and not is_instance_valid(_inspected):
		close_panel()

func has_ground() -> bool:
	return _ground_open

func ground_cell() -> Vector2i:
	return _ground

func inspected_building() -> Building:
	return _inspected

func is_blocking() -> bool:
	return _end.visible

func close_panel() -> void:
	_ground_open = false
	_inspected = null
	if _panel:
		_panel.visible = false

func open_ground(cell: Vector2i) -> void:
	_ground = cell
	_ground_open = true
	_inspected = null
	_fill_ground()
	_panel.visible = true
	_layout()

func open_building(building: Building) -> void:
	_ground_open = false
	_inspected = building
	_fill_building(building)
	_panel.visible = true
	_layout()

func flash(text: String) -> void:
	_hint.text = text
	_flash_t = 2.4

func set_phone(phone: bool) -> void:
	if _phone == phone and _zoom_in != null:
		_zoom_in.visible = not phone
		_zoom_out.visible = not phone
		return
	_phone = phone
	_layout()

func zoom_buttons_visible() -> bool:
	return _zoom_in != null and _zoom_in.visible

func refresh(wood: int, gold: int, people: int, housed: int, beds: int, walls: int, wall_cap: int, wave_label: String, phase: String, claim: float) -> void:
	_wood.set_value(str(wood))
	_gold.set_value(str(gold))
	_pop.set_value(str(people))
	_beds.set_value("%d/%d" % [housed, beds])
	_walls.set_value("%d/%d" % [walls, wall_cap])
	_wave.set_value(wave_label)
	_core.visible = claim > 0.0
	if claim > 0.0:
		_core.set_value(str(int(ceil(claim))))
	var busy := phase == "combat" or phase == "win" or phase == "lose"
	_start.disabled = busy
	_start.modulate = Color(0.55, 0.55, 0.55) if busy else Color.WHITE

func show_end(win: bool) -> void:
	close_panel()
	_set_menu(false)
	_won = win
	_end.visible = true
	if win:
		_end_title.text = Locale.text("end.win_title")
		_end_body.text = Locale.text("end.win_body")
	else:
		_end_title.text = Locale.text("end.lose_title")
		_end_body.text = Locale.text("end.lose_body")

func _idle_hint() -> String:
	return Locale.text("hint.idle")

func _on_language() -> void:
	_apply_copy()
	if _end and _end.visible:
		show_end(_won)
	if _ground_open:
		_fill_ground()
	elif _inspected != null and is_instance_valid(_inspected):
		_fill_building(_inspected)

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return
	_narrow = view.x < 760.0
	var font_size := 20 if _narrow else 22
	_theme.default_font_size = font_size
	var top_h := 58.0 if _narrow else 68.0
	var bot_h := 96.0 if _narrow else 72.0
	_top.offset_bottom = top_h
	_bottom.offset_top = -bot_h
	_hint.add_theme_font_size_override("font_size", 16 if _narrow else 18)
	var margin := 10.0
	var lang_w := 84.0 if _narrow else 96.0
	var lang_h := 42.0 if _narrow else 48.0
	var help_s := 42.0 if _narrow else 48.0
	var chrome_gap := 8.0
	var lang_top := (top_h - lang_h) * 0.5
	_lang.offset_right = -margin
	_lang.offset_left = -(margin + lang_w)
	_lang.offset_top = lang_top
	_lang.offset_bottom = lang_top + lang_h
	_lang.add_theme_font_size_override("font_size", 20 if _narrow else 22)
	var help_top := (top_h - help_s) * 0.5
	var help_right := margin + lang_w + chrome_gap
	_help.offset_right = -help_right
	_help.offset_left = -(help_right + help_s)
	_help.offset_top = help_top
	_help.offset_bottom = help_top + help_s
	var reserve := help_right + help_s + 14.0
	if _top_box:
		_top_box.offset_right = -reserve
		_top_box.add_theme_constant_override("separation", 8 if _narrow else 16)
	var num := 20 if _narrow else 22
	for chip in [_wood, _gold, _pop, _beds, _walls, _wave, _core]:
		chip.set_number_size(num)
	_place_menu(top_h)
	var icon := 64.0
	var gap := 10.0
	_place_icon(_start, 12.0, bot_h + gap + icon, icon)
	_place_icon(_leave, 12.0 + icon + gap, bot_h + gap + icon, icon)
	var zoom_x := 12.0 + (icon + gap) * 2.0
	_zoom_out.visible = not _phone
	_zoom_in.visible = not _phone
	_place_icon(_zoom_out, zoom_x, bot_h + gap + icon, icon)
	_place_icon(_zoom_in, zoom_x + icon + gap, bot_h + gap + icon, icon)
	var panel_w := minf(300.0, maxf(168.0, view.x * (0.46 if _narrow else 0.28)))
	_panel.offset_left = -panel_w
	_panel.offset_top = top_h + 8.0
	_panel.offset_bottom = -(bot_h + 8.0)

func _place_icon(button: Button, left: float, above_bottom: float, icon: float) -> void:
	button.offset_left = left
	button.offset_right = left + icon
	button.offset_bottom = -above_bottom + icon
	button.offset_top = -above_bottom

func _build_top() -> void:
	_top = Panel.new()
	_top.name = "TopBar"
	_top.theme = _theme
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 68
	_top.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(_top)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 6
	row.offset_right = -168
	row.offset_bottom = -6
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_top_box = row
	_top.add_child(row)
	_wood = _chip("wood", Locale.text("tip.wood"), Color(0.86, 0.62, 0.32))
	_gold = _chip("gold", Locale.text("tip.gold"), Color(0.98, 0.82, 0.28))
	_pop = _chip("people", Locale.text("tip.people"), Color(0.65, 0.86, 0.98))
	_beds = _chip("bed", Locale.text("tip.beds"), Color(0.75, 0.9, 0.7))
	_walls = _chip("wall", Locale.text("tip.walls"), Color(0.9, 0.75, 0.5))
	_wave = _chip("wave", Locale.text("tip.wave"), Color(0.9, 0.92, 0.84))
	_core = _chip("clock", Locale.text("tip.refugees"), Color(1, 0.86, 0.4))
	row.add_child(_wood)
	row.add_child(_gold)
	row.add_child(_pop)
	row.add_child(_beds)
	row.add_child(_walls)
	row.add_child(_wave)
	row.add_child(_core)

func _build_bottom() -> void:
	_bottom = Panel.new()
	_bottom.theme = _theme
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -88
	_bottom.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(_bottom)
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.theme = _theme
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.offset_left = 12
	_hint.offset_top = 6
	_hint.offset_right = -12
	_hint.offset_bottom = -6
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	_hint.text = _idle_hint()
	_bottom.add_child(_hint)

func _build_actions() -> void:
	_start = _icon_button("StartButton", "start", Color(0.16, 0.34, 0.18), Color(0.55, 0.78, 0.4))
	_start.tooltip_text = Locale.text("tip.start")
	_start.pressed.connect(func() -> void: start_pressed.emit())
	add_child(_start)
	_leave = _icon_button("LeaveButton", "leave", Color(0.32, 0.16, 0.14), Color(0.78, 0.42, 0.32))
	_leave.tooltip_text = Locale.text("tip.leave")
	_leave.pressed.connect(func() -> void: restart_pressed.emit())
	add_child(_leave)
	_zoom_out = _icon_button("ZoomOutButton", "minus", Color(0.16, 0.2, 0.18), Color(0.55, 0.62, 0.5))
	_zoom_out.tooltip_text = Locale.text("tip.zoom_out")
	_zoom_out.pressed.connect(func() -> void: zoom_out_pressed.emit())
	add_child(_zoom_out)
	_zoom_in = _icon_button("ZoomInButton", "plus", Color(0.16, 0.2, 0.18), Color(0.55, 0.62, 0.5))
	_zoom_in.tooltip_text = Locale.text("tip.zoom_in")
	_zoom_in.pressed.connect(func() -> void: zoom_in_pressed.emit())
	add_child(_zoom_in)

func _build_panel() -> void:
	_panel = Panel.new()
	_panel.theme = _theme
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -280
	_panel.offset_top = 80
	_panel.offset_bottom = -96
	_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.09, 0.96), Color(0.72, 0.58, 0.28)))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 8
	_scroll.offset_top = 8
	_scroll.offset_right = -8
	_scroll.offset_bottom = -8
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

func _build_end() -> void:
	_end = ColorRect.new()
	_end.color = Color(0, 0, 0, 0.55)
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = _theme
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.14, 0.1, 0.96), Color(0.72, 0.58, 0.28)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_end_title = Label.new()
	_end_title.theme = _theme
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 28)
	_end_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	box.add_child(_end_title)
	_end_body = Label.new()
	_end_body.theme = _theme
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_body.custom_minimum_size = Vector2(280, 0)
	_end_body.add_theme_color_override("font_color", Color(0.9, 0.88, 0.78))
	box.add_child(_end_body)
	var again := _icon_button("AgainButton", "start", Color(0.16, 0.34, 0.18), Color(0.55, 0.78, 0.4))
	again.custom_minimum_size = Vector2(72, 72)
	again.tooltip_text = Locale.text("tip.again")
	_again = again
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(again)

func _build_lang() -> void:
	_lang = Button.new()
	_lang.name = "LangButton"
	_lang.theme = _theme
	_lang.focus_mode = Control.FOCUS_NONE
	_lang.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lang.add_theme_font_size_override("font_size", 16)
	_style_button(_lang, Color(0.16, 0.22, 0.18), Color(0.55, 0.62, 0.5))
	_lang.pressed.connect(func() -> void: Locale.toggle())
	add_child(_lang)

func _build_help() -> void:
	_catcher = ColorRect.new()
	_catcher.name = "HelpCatcher"
	_catcher.color = Color(0, 0, 0, 0)
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.visible = false
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	_menu = Panel.new()
	_menu.name = "HelpMenu"
	_menu.theme = _theme
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.09, 0.98), Color(0.72, 0.58, 0.28)))
	add_child(_menu)
	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 8
	list.offset_top = 8
	list.offset_right = -8
	list.offset_bottom = -8
	list.add_theme_constant_override("separation", 8)
	_menu.add_child(list)
	_codex_btn = _menu_button("CodexButton")
	_codex_btn.pressed.connect(_on_codex)
	list.add_child(_codex_btn)
	_bench_btn = _menu_button("BenchButton")
	_bench_btn.pressed.connect(_on_bench)
	list.add_child(_bench_btn)
	_help = _icon_button("HelpButton", "help", Color(0.16, 0.22, 0.18), Color(0.55, 0.62, 0.5))
	_help.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help.custom_minimum_size = Vector2(0, 0)
	_help.pressed.connect(_toggle_menu)
	add_child(_help)

func _menu_button(node_name: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.theme = _theme
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 22)
	_style_button(btn, Color(0.16, 0.22, 0.18), Color(0.55, 0.62, 0.5))
	return btn

func _place_menu(top_h: float) -> void:
	if _menu == null:
		return
	var menu_w := 196.0 if _narrow else 228.0
	var item_h := 52.0 if _narrow else 56.0
	var pad := 8.0
	# Sit entirely under the resource bar so chips stay visible.
	_menu.offset_right = -10.0
	_menu.offset_left = -(10.0 + menu_w)
	_menu.offset_top = top_h + 8.0
	_menu.offset_bottom = top_h + 8.0 + pad * 2.0 + item_h * 2.0 + 8.0
	if _codex_btn:
		_codex_btn.custom_minimum_size = Vector2(0, item_h)
		_codex_btn.add_theme_font_size_override("font_size", 20 if _narrow else 22)
	if _bench_btn:
		_bench_btn.custom_minimum_size = Vector2(0, item_h)
		_bench_btn.add_theme_font_size_override("font_size", 20 if _narrow else 22)

func _toggle_menu() -> void:
	_set_menu(not _menu_open)

func _set_menu(open: bool) -> void:
	_menu_open = open
	if _menu:
		_menu.visible = open
	if _catcher:
		_catcher.visible = open
		_catcher.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		move_child(_catcher, get_child_count() - 1)
		move_child(_menu, get_child_count() - 1)
		move_child(_help, get_child_count() - 1)
		move_child(_lang, get_child_count() - 1)

func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_set_menu(false)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_set_menu(false)

func _on_codex() -> void:
	_set_menu(false)
	codex_pressed.emit()

func _on_bench() -> void:
	_set_menu(false)
	bench_pressed.emit()

func _apply_copy() -> void:
	_wood.tooltip_text = Locale.text("tip.wood")
	_gold.tooltip_text = Locale.text("tip.gold")
	_pop.tooltip_text = Locale.text("tip.people")
	_beds.tooltip_text = Locale.text("tip.beds")
	_walls.tooltip_text = Locale.text("tip.walls")
	_wave.tooltip_text = Locale.text("tip.wave")
	_core.tooltip_text = Locale.text("tip.refugees")
	_start.tooltip_text = Locale.text("tip.start")
	_leave.tooltip_text = Locale.text("tip.leave")
	_zoom_out.tooltip_text = Locale.text("tip.zoom_out")
	_zoom_in.tooltip_text = Locale.text("tip.zoom_in")
	_lang.text = Locale.text("lang.switch")
	_lang.tooltip_text = Locale.text("tip.lang")
	_help.tooltip_text = Locale.text("tip.help")
	_codex_btn.text = Locale.text("menu.codex")
	_codex_btn.tooltip_text = Locale.text("tip.codex")
	_bench_btn.text = Locale.text("menu.bench")
	_bench_btn.tooltip_text = Locale.text("tip.bench")
	if _again:
		_again.tooltip_text = Locale.text("tip.again")
	if _flash_t <= 0.0:
		_hint.text = Locale.text("hint.idle")

func _fill_ground() -> void:
	_clear_list()
	_list.add_child(_title(Locale.text("panel.build")))
	var options := [
		[Building.Kind.WALL, "build.wall", "role.wall"],
		[Building.Kind.SPEAR, "build.spear", "role.spear"],
		[Building.Kind.FIRE, "build.fire", "role.fire"],
		[Building.Kind.HOUSE, "build.house", "role.house"],
		[Building.Kind.FARM, "build.farm", "role.farm"],
		[Building.Kind.WORKSHOP, "build.workshop", "role.workshop"],
		[Building.Kind.LUMBER, "build.lumber", "role.lumber"],
		[Building.Kind.SPEAR_BARRACKS, "build.spear_barracks", "role.spear_barracks"],
		[Building.Kind.GUN_BARRACKS, "build.gun_barracks", "role.gun_barracks"],
	]
	for item in options:
		var kind := int(item[0])
		var stats: Dictionary = Balance.building_by_kind(Building.kind_key(kind as Building.Kind))
		var price: Dictionary = stats.get("cost", {})
		var cost := ""
		if int(price.get("wood", 0)) > 0:
			cost += Locale.format("cost.wood", [int(price.wood)])
		if int(price.get("gold", 0)) > 0:
			if cost != "":
				cost += "  "
			cost += Locale.format("cost.gold", [int(price.gold)])
		var btn := Button.new()
		btn.theme = _theme
		btn.custom_minimum_size = Vector2(0, 72)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = "%s\n%s  %s" % [Locale.text(str(item[1])), cost, Locale.text(str(item[2]))]
		_style_button(btn, Color(0.24, 0.16, 0.09), Color(0.62, 0.46, 0.22))
		btn.pressed.connect(_emit_place.bind(kind))
		_list.add_child(btn)
	_list.add_child(_close_button())

func _fill_building(building: Building) -> void:
	_clear_list()
	var names := {
		Building.Kind.WALL: "build.wall",
		Building.Kind.SPEAR: "build.spear",
		Building.Kind.FIRE: "build.fire",
		Building.Kind.HOUSE: "build.house",
		Building.Kind.FARM: "build.farm",
		Building.Kind.WORKSHOP: "build.workshop",
		Building.Kind.LUMBER: "build.lumber",
		Building.Kind.SPEAR_BARRACKS: "build.spear_barracks",
		Building.Kind.GUN_BARRACKS: "build.gun_barracks",
	}
	_list.add_child(_title(Locale.text(str(names.get(building.kind, "panel.building")))))
	if building.is_functional():
		if building.staff_cap() > 1:
			_list.add_child(_body(Locale.format("panel.crew_count", [building.staff_count(), building.staff_cap()])))
			var spec := building.produce_spec()
			_list.add_child(_body(Locale.format("panel.lumber_rate", [float(spec.get("interval", 5.0)), int(spec.get("rate_per_villager", 0))])))
		else:
			_list.add_child(_body(Locale.format("panel.station_count", [building.staff_count()])))
		var provides := building.provides()
		if str(provides.get("unit", "")) != "" and building.kind != Building.Kind.LUMBER:
			var unit_name := Locale.text("unit." + str(provides.get("unit", "")))
			_list.add_child(_body(Locale.format("panel.vacancy", [unit_name, int(provides.get("slots", 0))])))
		if building.has_staff():
			for node in building.crew:
				var person := node as Villager
				if person == null:
					continue
				_list.add_child(_staff_button(person))
				if building.staff_produces():
					_list.add_child(_dismiss_button(person))
			_list.add_child(_body(Locale.text("panel.reassign")))
		elif building.staff_produces():
			_list.add_child(_body(Locale.format("panel.mill_empty", [building.staff_cap()])))
		else:
			_list.add_child(_body(Locale.text("panel.empty")))
	else:
		_list.add_child(_body(Locale.text("panel.wall_info")))
	var sell := Button.new()
	sell.theme = _theme
	sell.custom_minimum_size = Vector2(0, 64)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.add_theme_font_size_override("font_size", 18)
	sell.text = Locale.text("panel.sell")
	_style_button(sell, Color(0.34, 0.18, 0.14), Color(0.8, 0.45, 0.32))
	sell.pressed.connect(func() -> void: sell_pressed.emit())
	_list.add_child(sell)
	_list.add_child(_close_button())

func _emit_place(kind: int) -> void:
	place_requested.emit(kind)

func _clear_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()

func _body(text: String) -> Label:
	var label := Label.new()
	label.theme = _theme
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	return label

func _staff_button(person: Villager) -> Button:
	var btn := Button.new()
	btn.name = "StaffButton"
	btn.theme = _theme
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_button(btn, Color(0.14, 0.22, 0.16), Color(0.45, 0.62, 0.42))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	row.offset_right = -8
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(row)
	var frame := TextureRect.new()
	frame.texture = person.face_texture()
	frame.custom_minimum_size = Vector2(84, 84)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var name := Label.new()
	name.theme = _theme
	name.text = Locale.text("villager.female" if person.sex == "f" else "villager.male")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	row.add_child(name)
	btn.pressed.connect(func() -> void: staff_selected.emit(person))
	return btn

func _dismiss_button(person: Villager) -> Button:
	var btn := Button.new()
	btn.name = "DismissButton"
	btn.theme = _theme
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)
	btn.text = Locale.text("panel.dismiss")
	_style_button(btn, Color(0.28, 0.2, 0.12), Color(0.72, 0.55, 0.28))
	btn.pressed.connect(func() -> void: staff_dismissed.emit(person))
	return btn

func _title(text: String) -> Label:
	var label := Label.new()
	label.theme = _theme
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	return label

func _close_button() -> Button:
	var btn := Button.new()
	btn.theme = _theme
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.text = Locale.text("panel.close")
	_style_button(btn, Color(0.16, 0.18, 0.16), Color(0.45, 0.48, 0.42))
	btn.pressed.connect(close_panel)
	return btn

func _icon_button(node_name: String, kind: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.theme = _theme
	btn.text = ""
	btn.custom_minimum_size = Vector2(64, 64)
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.focus_mode = Control.FOCUS_NONE
	_style_button(btn, bg, border)
	var mark := IconMark.new()
	mark.kind = kind
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(mark)
	return btn

func _chip(kind: String, tip: String, color: Color) -> StatChip:
	var chip := StatChip.new()
	chip.kind = kind
	chip.theme = _theme
	chip.tooltip_text = tip
	chip.number_color = color
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip

func _style_button(btn: Button, bg: Color, border: Color) -> void:
	btn.add_theme_stylebox_override("normal", _box(bg, border))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), border.lightened(0.1)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.12), Color(1, 0.86, 0.4)))
	btn.add_theme_stylebox_override("disabled", _box(Color(0.16, 0.16, 0.15), Color(0.32, 0.32, 0.3)))
	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.5))

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


class IconMark:
	extends Control

	var kind := "start"

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var parent_btn := get_parent() as Button
		var col := Color(0.9, 0.98, 0.86)
		if parent_btn and parent_btn.disabled:
			col = Color(0.55, 0.55, 0.52)
		elif kind == "leave":
			col = Color(1, 0.9, 0.78)
		var c := size * 0.5
		if kind == "start":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-12, -16),
				c + Vector2(-12, 16),
				c + Vector2(16, 0),
			]), col)
			return
		if kind == "plus" or kind == "minus":
			draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), col, 4.0)
			if kind == "plus":
				draw_line(c + Vector2(0, -12), c + Vector2(0, 12), col, 4.0)
			return
		if kind == "help":
			var s := minf(size.x, size.y)
			var u := s / 48.0
			draw_arc(c, 16.0 * u, 0, TAU, 28, col, 2.6 * u)
			var hook := PackedVector2Array([
				c + Vector2(-6.2, -1.2) * u,
				c + Vector2(-6.4, -5.4) * u,
				c + Vector2(-3.2, -8.6) * u,
				c + Vector2(1.6, -8.8) * u,
				c + Vector2(5.6, -6.2) * u,
				c + Vector2(5.8, -2.6) * u,
				c + Vector2(2.2, 0.6) * u,
				c + Vector2(0.2, 3.0) * u,
				c + Vector2(0.2, 5.6) * u,
			])
			draw_polyline(hook, col, 2.6 * u, true)
			draw_circle(c + Vector2(0.2, 9.4) * u, 1.7 * u, col)
			return
		draw_rect(Rect2(c + Vector2(-18, -16), Vector2(20, 32)), col, false, 3.0)
		draw_line(c + Vector2(4, 0), c + Vector2(18, 0), col, 3.0)
		draw_line(c + Vector2(12, -6), c + Vector2(18, 0), col, 3.0)
		draw_line(c + Vector2(12, 6), c + Vector2(18, 0), col, 3.0)


class StatChip:
	extends HBoxContainer

	var kind := "wood"
	var number_color := Color.WHITE
	var _label: Label
	var _icon: StatIcon

	func _ready() -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 6)
		_icon = StatIcon.new()
		_icon.kind = kind
		_icon.custom_minimum_size = Vector2(28, 28)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_label = Label.new()
		_label.theme = theme
		_label.add_theme_color_override("font_color", number_color)
		_label.add_theme_font_size_override("font_size", 22)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.clip_text = true
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func set_value(text: String) -> void:
		if _label:
			_label.text = text

	func set_number_size(px: int) -> void:
		if _label:
			_label.add_theme_font_size_override("font_size", px)
		if _icon:
			var side := float(px + 8)
			_icon.custom_minimum_size = Vector2(side, side)


class StatIcon:
	extends Control

	var kind := "wood"

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		if kind == "wood":
			draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 8)), Color(0.55, 0.34, 0.16))
			draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 8)), Color(0.35, 0.2, 0.08), false, 1.5)
			draw_line(c + Vector2(-4, -4), c + Vector2(-4, 4), Color(0.35, 0.2, 0.08), 1.5)
			return
		if kind == "gold":
			draw_circle(c, 8.0, Color(0.95, 0.78, 0.22))
			draw_arc(c, 8.0, 0, TAU, 16, Color(0.55, 0.38, 0.08), 1.5)
			draw_line(c + Vector2(0, -4), c + Vector2(0, 4), Color(0.55, 0.38, 0.08), 1.5)
			return
		if kind == "people":
			draw_circle(c + Vector2(0, -5), 4.0, Color(0.95, 0.86, 0.7))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6, 8), c + Vector2(0, -1), c + Vector2(6, 8)
			]), Color(0.45, 0.62, 0.85))
			return
		if kind == "bed":
			draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 10)), Color(0.75, 0.55, 0.38))
			draw_rect(Rect2(c + Vector2(-9, -6), Vector2(6, 6)), Color(0.92, 0.9, 0.82))
			return
		if kind == "wall":
			draw_rect(Rect2(c + Vector2(-8, -7), Vector2(4, 14)), Color(0.62, 0.48, 0.28))
			draw_rect(Rect2(c + Vector2(3, -7), Vector2(4, 14)), Color(0.62, 0.48, 0.28))
			draw_line(c + Vector2(-8, -2), c + Vector2(7, -2), Color(0.4, 0.28, 0.14), 2.0)
			return
		if kind == "wave":
			draw_line(c + Vector2(-7, 8), c + Vector2(-7, -8), Color(0.85, 0.82, 0.7), 2.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-7, -8), c + Vector2(8, -4), c + Vector2(-7, 0)
			]), Color(0.86, 0.32, 0.28))
			return
		draw_arc(c, 8.0, 0, TAU, 16, Color(0.95, 0.86, 0.45), 2.0)
		draw_line(c, c + Vector2(0, -5), Color(0.95, 0.86, 0.45), 2.0)
		draw_line(c, c + Vector2(4, 2), Color(0.95, 0.86, 0.45), 2.0)
