extends Node2D

const BAR_H := 58.0

var _font: Font
var _theme: Theme
var _title: Label
var _back: Button
var _lab_btn: Button
var _stress_btn: Button
var _lang: Button
var _tool: Node = null
var _mode := ""

func _ready() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 20
	for type_name in ["Label", "Button"]:
		_theme.set_font("font", type_name, _font)
	_build_chrome()
	Locale.changed.connect(_refresh_copy)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_copy()
	_show_mode("lab")
	if OS.get_environment("TD_BENCH") == "1":
		_bench_probe()

func _bench_probe() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lab_on := _mode == "lab" and _tool != null and is_instance_valid(_tool)
	var lab_hosted := bool(_tool.get("hosted")) if lab_on else false
	var no_lab_back := _tool.find_child("BackButton", true, false) == null if lab_on else false
	await _capture("/opt/cursor/artifacts/workbench-lab.png")
	_show_mode("stress")
	await get_tree().process_frame
	await get_tree().process_frame
	var stress_on := _mode == "stress" and _tool != null and is_instance_valid(_tool)
	var stress_hosted := bool(_tool.get("hosted")) if stress_on else false
	var title := ""
	if stress_on:
		var label = _tool.get("_title")
		if label is Label:
			title = (label as Label).text
	await _capture("/opt/cursor/artifacts/workbench-stress.png")
	var passed := lab_on and lab_hosted and no_lab_back and stress_on and stress_hosted and title.contains("N=")
	print("BENCH_OK ", passed, " lab=", lab_on, lab_hosted, no_lab_back, " stress=", stress_on, stress_hosted, " title=", title)
	get_tree().quit(0 if passed else 1)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("SHOT", path, " err=", err, " ", image.get_width(), "x", image.get_height())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_back_to_game()

func _build_chrome() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var bar := Panel.new()
	bar.name = "WorkbenchBar"
	bar.theme = _theme
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = BAR_H
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _box(Color(0.07, 0.11, 0.08, 0.96), Color(0.35, 0.28, 0.14)))
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -112
	row.offset_bottom = -8
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	_back = _button("BackButton")
	_back.pressed.connect(_back_to_game)
	row.add_child(_back)
	_title = Label.new()
	_title.theme = _theme
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	row.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_lab_btn = _button("LabModeButton")
	_lab_btn.pressed.connect(func() -> void: _show_mode("lab"))
	row.add_child(_lab_btn)
	_stress_btn = _button("StressModeButton")
	_stress_btn.pressed.connect(func() -> void: _show_mode("stress"))
	row.add_child(_stress_btn)
	_lang = _button("LangButton")
	_lang.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lang.offset_left = -100
	_lang.offset_right = -10
	_lang.offset_top = 8
	_lang.offset_bottom = BAR_H - 8
	_lang.add_theme_font_size_override("font_size", 20)
	_lang.pressed.connect(func() -> void: Locale.toggle())
	layer.add_child(_lang)

func _layout() -> void:
	var narrow := get_viewport().get_visible_rect().size.x < 720.0
	if _title:
		_title.visible = not narrow
	if _back:
		_back.custom_minimum_size = Vector2(112 if narrow else 148, 40)
		_back.add_theme_font_size_override("font_size", 18 if narrow else 20)
	for btn in [_lab_btn, _stress_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(88 if narrow else 112, 40)
			btn.add_theme_font_size_override("font_size", 18 if narrow else 20)

func _show_mode(mode: String) -> void:
	if _tool != null and _mode == mode:
		return
	_mode = mode
	_drop_tool()
	if mode == "stress":
		if int(Engine.get_meta("stress_n", 0)) < 1:
			Engine.set_meta("stress_n", 300)
		Engine.max_fps = 0
	else:
		Engine.max_fps = 60
	var path := "res://scenes/depth_stress.tscn" if mode == "stress" else "res://scenes/depth_lab.tscn"
	var node := (load(path) as PackedScene).instantiate()
	node.set("hosted", true)
	_tool = node
	add_child(node)
	_paint_modes()

func _drop_tool() -> void:
	if _tool == null:
		return
	var old := _tool
	_tool = null
	old.set_process(false)
	old.set_process_unhandled_input(false)
	if is_instance_valid(old) and old.get_parent() == self:
		remove_child(old)
	old.queue_free()

func _back_to_game() -> void:
	Engine.set_meta("skip_stress", true)
	Engine.set_meta("skip_lab", true)
	Engine.max_fps = 60
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _refresh_copy() -> void:
	if _back == null:
		return
	_back.text = Locale.text("lab.back")
	_back.tooltip_text = Locale.text("lab.back")
	_title.text = Locale.text("bench.title")
	_lab_btn.text = Locale.text("bench.lab")
	_lab_btn.tooltip_text = Locale.text("bench.lab_tip")
	_stress_btn.text = Locale.text("bench.stress")
	_stress_btn.tooltip_text = Locale.text("bench.stress_tip")
	_lang.text = Locale.text("lang.switch")
	_lang.tooltip_text = Locale.text("tip.lang")
	_paint_modes()

func _paint_modes() -> void:
	_paint_mode(_lab_btn, _mode == "lab")
	_paint_mode(_stress_btn, _mode == "stress")

func _paint_mode(btn: Button, on: bool) -> void:
	if btn == null:
		return
	var bg := Color(0.24, 0.34, 0.2) if on else Color(0.16, 0.22, 0.16)
	var edge := Color(1, 0.86, 0.4) if on else Color(0.54, 0.44, 0.22)
	btn.add_theme_stylebox_override("normal", _box(bg, edge))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), edge.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.08), Color(1, 0.86, 0.4)))

func _button(node_name: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.theme = _theme
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	_style_button(btn)
	return btn

func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _box(Color(0.16, 0.22, 0.16), Color(0.54, 0.44, 0.22)))
	btn.add_theme_stylebox_override("hover", _box(Color(0.22, 0.3, 0.2), Color(0.9, 0.78, 0.4)))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.14, 0.1), Color(0.9, 0.78, 0.4)))
	btn.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.86))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
