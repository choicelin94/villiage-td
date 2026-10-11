class_name Hud
extends CanvasLayer

signal start_pressed
signal restart_pressed

var _selected := -1
var _sync := false
var _buttons := {}
var _wood: Label
var _gold: Label
var _pop: Label
var _wave: Label
var _core: Label
var _bar: ProgressBar
var _hint: Label
var _start: Button
var _end: Control
var _end_title: Label
var _end_body: Label
var _flash_t := 0.0
var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/DroidSansFallback-subset.ttf")
	layer = 10
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	_build_top(theme)
	_build_bottom(theme)
	_build_end(theme)

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0 and _end.visible == false:
			_hint.text = _idle_hint()

func selected_kind() -> int:
	return _selected

func is_blocking() -> bool:
	return _end.visible

func select_kind(kind: int) -> void:
	_selected = kind
	_sync = true
	for key in _buttons.keys():
		(_buttons[key] as Button).button_pressed = int(key) == kind
	_sync = false

func flash(text: String) -> void:
	_hint.text = text
	_flash_t = 2.2

func refresh(wood: int, gold: int, pop: int, pop_cap: int, wave_label: String, core: int, core_max: int, phase: String) -> void:
	_wood.text = "木材 Wood  %d" % wood
	_gold.text = "金币 Gold  %d" % gold
	_pop.text = "人口 Pop  %d/%d" % [pop, pop_cap]
	_wave.text = wave_label
	_core.text = "圣树 %d/%d" % [core, core_max]
	_bar.max_value = core_max
	_bar.value = core
	var busy := phase == "combat"
	_start.disabled = busy or phase == "win" or phase == "lose"
	if phase == "combat":
		_start.text = "交战中\nIn progress"
	elif phase == "win" or phase == "lose":
		_start.text = "结束\nEnded"
	else:
		_start.text = "开始波次\nStart Wave"

func show_end(win: bool) -> void:
	_end.visible = true
	if win:
		_end_title.text = "村落守住了  /  Village held"
		_end_body.text = "八波僵尸已被击退。\nAll 8 waves were driven back."
	else:
		_end_title.text = "村落陷落  /  Village lost"
		_end_body.text = "圣树被摧毁了。\nThe sacred tree has fallen."

func _idle_hint() -> String:
	return "房屋提高人口。人口决定能建多少防御，并在每波后发金币。农场产木材，工坊让塔更强。  |  Houses raise population, which caps defenses and pays gold. Farms yield wood. The workshop strengthens towers."

func _build_top(theme: Theme) -> void:
	var panel := Panel.new()
	panel.theme = theme
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 54
	panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(panel)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	_wood = _stat(theme, Color(0.86, 0.62, 0.32))
	_gold = _stat(theme, Color(0.98, 0.82, 0.28))
	_pop = _stat(theme, Color(0.65, 0.86, 0.98))
	_wave = _stat(theme, Color(0.9, 0.92, 0.84))
	_core = _stat(theme, Color(0.7, 0.9, 0.65))
	row.add_child(_wood)
	row.add_child(_gold)
	row.add_child(_pop)
	row.add_child(_wave)
	row.add_child(_core)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(180, 18)
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.32, 0.72, 0.3)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.12, 0.1)
	bg.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	row.add_child(_bar)

func _stat(theme: Theme, color: Color) -> Label:
	var label := Label.new()
	label.theme = theme
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label

func _build_bottom(theme: Theme) -> void:
	var panel := Panel.new()
	panel.theme = theme
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -132
	panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_top = 6
	col.offset_right = -12
	col.offset_bottom = -6
	panel.add_child(col)
	_hint = Label.new()
	_hint.theme = theme
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	_hint.text = _idle_hint()
	_hint.custom_minimum_size = Vector2(0, 36)
	col.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_add_build_button(row, theme, Building.Kind.WALL, "木墙 Wall", "挡路")
	_add_build_button(row, theme, Building.Kind.SPEAR, "矛塔 Spear", "穿刺")
	_add_build_button(row, theme, Building.Kind.FIRE, "火塔 Fire", "溅射")
	_add_build_button(row, theme, Building.Kind.HOUSE, "房屋 House", "人口+4")
	_add_build_button(row, theme, Building.Kind.FARM, "农场 Farm", "产木材")
	_add_build_button(row, theme, Building.Kind.WORKSHOP, "工坊 Workshop", "强化塔")
	_start = Button.new()
	_start.theme = theme
	_start.custom_minimum_size = Vector2(148, 58)
	_start.text = "开始波次\nStart Wave"
	_style_button(_start, Color(0.18, 0.32, 0.18), Color(0.55, 0.75, 0.4))
	_start.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(_start)

func _add_build_button(row: HBoxContainer, theme: Theme, kind: int, title: String, blurb: String) -> void:
	var stats: Dictionary = Building.STATS[kind]
	var cost := ""
	if int(stats.wood) > 0:
		cost += "%d木 " % int(stats.wood)
	if int(stats.gold) > 0:
		cost += "%d金" % int(stats.gold)
	var btn := Button.new()
	btn.theme = theme
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(148, 58)
	btn.add_theme_font_size_override("font_size", 15)
	btn.text = "%s\n%s  %s" % [title, cost, blurb]
	_style_button(btn, Color(0.24, 0.16, 0.09), Color(0.62, 0.46, 0.22))
	btn.toggled.connect(func(on: bool) -> void: _on_toggled(kind, on))
	row.add_child(btn)
	_buttons[kind] = btn

func _on_toggled(kind: int, on: bool) -> void:
	if _sync:
		return
	if on:
		select_kind(kind)
	elif _selected == kind:
		select_kind(-1)

func _build_end(theme: Theme) -> void:
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
	panel.theme = theme
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.14, 0.1, 0.96), Color(0.72, 0.58, 0.28)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_end_title = Label.new()
	_end_title.theme = theme
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 28)
	_end_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	box.add_child(_end_title)
	_end_body = Label.new()
	_end_body.theme = theme
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.add_theme_color_override("font_color", Color(0.9, 0.88, 0.78))
	box.add_child(_end_body)
	var again := Button.new()
	again.theme = theme
	again.text = "重新开始  /  Play again"
	again.custom_minimum_size = Vector2(280, 48)
	_style_button(again, Color(0.2, 0.34, 0.18), Color(0.6, 0.8, 0.4))
	again.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(again)

func _style_button(btn: Button, bg: Color, border: Color) -> void:
	btn.add_theme_stylebox_override("normal", _box(bg, border))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), border.lightened(0.1)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), Color(1, 0.86, 0.4)))
	btn.add_theme_stylebox_override("disabled", _box(Color(0.15, 0.15, 0.14), Color(0.3, 0.3, 0.28)))
	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.5))

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
