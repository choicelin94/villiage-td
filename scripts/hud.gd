class_name Hud
extends CanvasLayer

signal start_pressed
signal restart_pressed
signal zoom_in_pressed
signal zoom_out_pressed
signal place_requested(kind: int)
signal sell_pressed

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
	_end.visible = true
	if win:
		_end_title.text = "村落守住了  /  Village held"
		_end_body.text = "十波僵尸已被击退。\nAll 10 waves were driven back."
	else:
		_end_title.text = "村落陷落  /  Village lost"
		_end_body.text = "村民全部被感染了。\nEvery villager was infected."

func _idle_hint() -> String:
	return "点空地，在右侧选择建筑。先点村民，再点建筑来派人。双指缩放，单指拖动地图。  |  Tap empty ground, then pick a building on the right. Tap a villager, then a building, to assign. Pinch to zoom, or use + and - on a computer. Drag to pan."

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return
	_narrow = view.x < 760.0
	var font_size := 16 if _narrow else 18
	_theme.default_font_size = font_size
	var top_h := 78.0 if _narrow else 64.0
	var bot_h := 96.0 if _narrow else 72.0
	_top.offset_bottom = top_h
	_bottom.offset_top = -bot_h
	_hint.add_theme_font_size_override("font_size", 15 if _narrow else 16)
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
	_top.theme = _theme
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 72
	_top.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(_top)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_top = 4
	col.offset_right = -10
	col.offset_bottom = -4
	col.add_theme_constant_override("separation", 0)
	_top.add_child(col)
	var row_a := HBoxContainer.new()
	var row_b := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 12)
	row_b.add_theme_constant_override("separation", 12)
	col.add_child(row_a)
	col.add_child(row_b)
	_wood = _chip("wood", "木材 / Wood", Color(0.86, 0.62, 0.32))
	_gold = _chip("gold", "金币 / Gold", Color(0.98, 0.82, 0.28))
	_pop = _chip("people", "村民 / People", Color(0.65, 0.86, 0.98))
	_beds = _chip("bed", "床 已住/总数 / Beds", Color(0.75, 0.9, 0.7))
	_walls = _chip("wall", "墙 / Walls", Color(0.9, 0.75, 0.5))
	_wave = _chip("wave", "波次 / Wave", Color(0.9, 0.92, 0.84))
	_core = _chip("clock", "难民倒计时 / Refugees", Color(1, 0.86, 0.4))
	row_a.add_child(_wood)
	row_a.add_child(_gold)
	row_a.add_child(_pop)
	row_b.add_child(_beds)
	row_b.add_child(_walls)
	row_b.add_child(_wave)
	row_b.add_child(_core)

func _build_bottom() -> void:
	_bottom = Panel.new()
	_bottom.theme = _theme
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -88
	_bottom.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.92), Color(0.35, 0.28, 0.14)))
	add_child(_bottom)
	_hint = Label.new()
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
	_start.tooltip_text = "开始波次 / Start wave"
	_start.pressed.connect(func() -> void: start_pressed.emit())
	add_child(_start)
	_leave = _icon_button("LeaveButton", "leave", Color(0.32, 0.16, 0.14), Color(0.78, 0.42, 0.32))
	_leave.tooltip_text = "离开并重开 / Leave and restart"
	_leave.pressed.connect(func() -> void: restart_pressed.emit())
	add_child(_leave)
	_zoom_out = _icon_button("ZoomOutButton", "minus", Color(0.16, 0.2, 0.18), Color(0.55, 0.62, 0.5))
	_zoom_out.tooltip_text = "缩小 / Zoom out"
	_zoom_out.pressed.connect(func() -> void: zoom_out_pressed.emit())
	add_child(_zoom_out)
	_zoom_in = _icon_button("ZoomInButton", "plus", Color(0.16, 0.2, 0.18), Color(0.55, 0.62, 0.5))
	_zoom_in.tooltip_text = "放大 / Zoom in"
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
	again.tooltip_text = "再来一局 / Play again"
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(again)

func _fill_ground() -> void:
	_clear_list()
	_list.add_child(_title("建造  /  Build"))
	var options := [
		[Building.Kind.WALL, "木墙", "Wall", "挡路"],
		[Building.Kind.SPEAR, "矛塔", "Spear", "穿刺"],
		[Building.Kind.FIRE, "火塔", "Fire", "溅射"],
		[Building.Kind.HOUSE, "房屋", "House", "床位"],
		[Building.Kind.FARM, "农场", "Farm", "产木材"],
		[Building.Kind.WORKSHOP, "工坊", "Workshop", "强化塔"],
	]
	for item in options:
		var kind := int(item[0])
		var stats: Dictionary = Building.STATS[kind]
		var cost := ""
		if int(stats.wood) > 0:
			cost += "%d木 " % int(stats.wood)
		if int(stats.gold) > 0:
			cost += "%d金" % int(stats.gold)
		var btn := Button.new()
		btn.theme = _theme
		btn.custom_minimum_size = Vector2(0, 72)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = "%s  %s\n%s  %s" % [item[1], item[2], cost, item[3]]
		_style_button(btn, Color(0.24, 0.16, 0.09), Color(0.62, 0.46, 0.22))
		btn.pressed.connect(_emit_place.bind(kind))
		_list.add_child(btn)
	_list.add_child(_close_button())

func _fill_building(building: Building) -> void:
	_clear_list()
	var names := {
		Building.Kind.WALL: "木墙  Wall",
		Building.Kind.SPEAR: "矛塔  Spear",
		Building.Kind.FIRE: "火塔  Fire",
		Building.Kind.HOUSE: "房屋  House",
		Building.Kind.FARM: "农场  Farm",
		Building.Kind.WORKSHOP: "工坊  Workshop",
	}
	_list.add_child(_title(str(names.get(building.kind, "建筑"))))
	var info := Label.new()
	info.theme = _theme
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	var staffed := "有人值守" if building.has_staff() else "没有人"
	if building.is_functional():
		info.text = "%s。先点村民，再点这里来派人。\n%s. Tap a villager, then tap here to assign." % [staffed, "Staffed" if building.has_staff() else "Empty"]
	else:
		info.text = "木墙不用派人。\nWalls do not take a villager."
	_list.add_child(info)
	var sell := Button.new()
	sell.theme = _theme
	sell.custom_minimum_size = Vector2(0, 64)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.add_theme_font_size_override("font_size", 18)
	sell.text = "出售  /  Sell"
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
	btn.text = "关闭  /  Close"
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
		add_theme_constant_override("separation", 4)
		_icon = StatIcon.new()
		_icon.kind = kind
		_icon.custom_minimum_size = Vector2(22, 22)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_label = Label.new()
		_label.theme = theme
		_label.add_theme_color_override("font_color", number_color)
		_label.add_theme_font_size_override("font_size", 16)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.clip_text = true
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func set_value(text: String) -> void:
		if _label:
			_label.text = text


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
