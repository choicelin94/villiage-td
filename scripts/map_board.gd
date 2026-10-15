class_name MapBoard
extends Control

# Hosts the layout document, the command applier, and the art preview.
# A click opens the inspector, which stays inside this black map panel.
# Pointer drags from MapView become MapCommands.

signal hint_changed(text: String)
signal changed

const PANEL_W := 300.0

var state: Dictionary = {}
var doc: SetupDocument
var interaction: MapInteraction
var view: MapView
var _font: Font
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _selected := Vector2i(-1, -1)
var _status_text := ""
var _last_action := ""


func setup(p_state: Dictionary, p_font: Font) -> void:
	state = p_state
	_font = p_font
	doc = SetupDocument.new()
	doc.bind(state)
	interaction = MapInteraction.new()
	name = "MapBoard"
	custom_minimum_size = Vector2(760, 860)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = MapView.new()
	view.setup(doc, interaction, p_font)
	view.command_issued.connect(_on_command)
	add_child(view)
	_build_panel()
	_fit_view()
	var note := _combined_note()
	if note != "":
		_status_text = note
		call_deferred("_emit_hint", note)


func place_payload(payload: Dictionary, cell: Vector2i) -> bool:
	if doc == null or interaction == null:
		return false
	var result: Dictionary = MapCommands.apply(doc, interaction.drop_command(cell, payload, doc))
	_after(result)
	return bool(result.get("ok", false)) and str(result.get("action", "")) == "placed"


func edit_click(cell: Vector2i) -> String:
	if doc == null:
		return ""
	var cmd: Dictionary = MapInteraction.op_for(cell, {}, doc.blocks_new(cell, {}))
	var result: Dictionary = MapCommands.apply(doc, cmd)
	_last_action = str(result.get("action", ""))
	if _last_action == "inspect":
		_open_inspector(cell)
	if view:
		view.queue_redraw()
	return _last_action


func inspect_cell(cell: Vector2i) -> void:
	_on_command({"op": "inspect", "cell": cell})


func close_inspector() -> void:
	_selected = Vector2i(-1, -1)
	if _panel:
		_panel.visible = false
	_fit_view()


func inspector_open() -> bool:
	return _panel != null and _panel.visible


func probe_edits() -> bool:
	var commands_ok := MapCommands.golden()
	var corner := edit_click(Vector2i(0, 0))
	var corner_set: Dictionary = MapCommands.set_spawn(doc, Vector2i(0, 0))
	var before := doc.roads().duplicate()
	var bare: Dictionary = MapCommands.set_spawn(doc, Vector2i(3, 0))
	var painted: Dictionary = MapCommands.apply(doc, {"op": "toggle_road", "cell": Vector2i(3, 0)})
	var spawned: Dictionary = MapCommands.set_spawn(doc, Vector2i(3, 0))
	var rects := doc.spawn_rects()
	var cell_ok := false
	if rects.size() == 1:
		var cells := MapPlan.cells_of_rect(rects[0])
		cell_ok = cells.size() == 3 and cells[0] == Vector2i(2, 0) and cells[1] == Vector2i(3, 0) and cells[2] == Vector2i(4, 0)
	var road_ok := doc.is_road(Vector2i(3, 0)) and not doc.is_road(Vector2i(3, 1)) and not doc.is_road(Vector2i(2, 0))
	var kept_old := false
	for item in before:
		if item is Array and item.size() >= 2 and int(item[0]) == 10 and int(item[1]) == 0:
			kept_old = doc.is_road(Vector2i(10, 0))
	doc.starter_props().append({"kind": "tree", "cell": [2, 0]})
	var blocked: Dictionary = MapCommands.set_spawn(doc, Vector2i(3, 0))
	doc.starter_props().clear()
	var south_bare: Dictionary = MapCommands.set_spawn(doc, Vector2i(4, 19))
	var pick := edit_click(Vector2i(10, 8))
	var placed := place_payload({"layer": "unit", "id": "spearman", "volume": "walker"}, Vector2i(10, 8))
	var border_reject := not place_payload({"layer": "build", "id": "WALL", "volume": "wall"}, Vector2i(5, 0))
	var rock_reject := not place_payload({"layer": "prop", "id": "tree", "volume": "tree"}, Vector2i(4, 8))
	var prop_ok := place_payload({"layer": "prop", "id": "rock", "volume": "rock"}, Vector2i(6, 6))
	var art_ok := ActorPainter.has_art("build", "HOUSE") and ActorPainter.has_art("unit", "villager") and ActorPainter.has_art("unit", "spearman") and ActorPainter.has_art("prop", "tree") and ActorPainter.has_art("prop", "rock")
	var combat_nodes := _combat_node_count()
	inspect_cell(Vector2i(8, 8))
	_fit_view()
	var popup := find_child("PlacePopup", true, false) as Control
	var panel_ok := popup != null and popup.visible and _rect_inside(get_global_rect(), popup.get_global_rect()) and _rect_inside(view.get_global_rect(), popup.get_global_rect())
	var clip_ok := clip_contents and view.clip_contents
	view.zoom_by(1.4, view.size * 0.5)
	var zoom_ok := view.zoom_level() > 1.2 and view.zoom_level() < 2.0
	var zoom_btns := find_child("MapZoomIn", true, false) != null and find_child("MapZoomOut", true, false) != null
	view.reset_view()
	close_inspector()
	var ok := commands_ok and corner == "inspect" and str(corner_set.get("action", "")) == "corner" and str(bare.get("action", "")) == "need_road" and str(painted.get("action", "")) == "road_on" and str(spawned.get("action", "")) == "spawn" and cell_ok and road_ok and kept_old and str(blocked.get("action", "")) == "spawn_blocked" and str(south_bare.get("action", "")) == "need_road" and pick == "inspect" and placed and border_reject and rock_reject and prop_ok and art_ok and combat_nodes == 0 and panel_ok and clip_ok and zoom_ok and zoom_btns
	print("BENCH_EDIT corner=", corner, " spawn=", str(spawned.get("action", "")), " cell=", cell_ok, " road=", road_ok, " blocked=", str(blocked.get("action", "")), " pick=", pick, " placed=", placed, " border=", border_reject, " rock=", rock_reject, " prop=", prop_ok, " art=", art_ok, " commands=", commands_ok, " combat=", combat_nodes, " panel=", panel_ok, " clip=", clip_ok, " zoom=", zoom_ok)
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_view()


func _fit_view() -> void:
	if view == null:
		return
	view.position = Vector2.ZERO
	view.size = size if size.x > 32.0 and size.y > 32.0 else custom_minimum_size
	if _panel == null:
		return
	if _panel.visible:
		var width := minf(PANEL_W, maxf(view.size.x - 48.0, 120.0))
		_panel.position = Vector2(view.size.x - width, 0)
		_panel.size = Vector2(width, view.size.y)
	else:
		_panel.position = Vector2(view.size.x, 0)
		_panel.size = Vector2(PANEL_W, view.size.y)


func _on_command(cmd: Dictionary) -> void:
	var op := str(cmd.get("op", ""))
	var cell: Vector2i = cmd.get("cell", Vector2i(-1, -1))
	if op == "inspect":
		_open_inspector(cell)
		if view:
			view.queue_redraw()
		return
	if op == "none":
		return
	var result: Dictionary = MapCommands.apply(doc, cmd)
	_after(result)
	if inspector_open():
		call_deferred("_rebuild_panel")


func _open_inspector(cell: Vector2i) -> void:
	if not MapPlan.in_bounds(cell):
		return
	_selected = cell
	_panel.visible = true
	_rebuild_panel()
	_fit_view()


func _after(result: Dictionary) -> void:
	_last_action = str(result.get("action", ""))
	var text := _hint_for(result)
	if text != "":
		_status_text = text
		hint_changed.emit(text)
	if view:
		view.queue_redraw()
	if bool(result.get("ok", false)) and _last_action != "inspect" and _last_action != "none" and _last_action != "pick":
		changed.emit()


func _hint_for(result: Dictionary) -> String:
	var action := str(result.get("action", ""))
	var cell: Vector2i = result.get("cell", Vector2i.ZERO)
	match action:
		"corner":
			return Locale.text("bench.map.corner")
		"spawn":
			return Locale.format("bench.map.spawn_set", [cell.x, cell.y])
		"spawn_have":
			return Locale.text("bench.map.spawn_have")
		"spawn_blocked":
			return Locale.text("bench.map.spawn_blocked")
		"need_road":
			return Locale.text("bench.map.need_road")
		"spawn_one":
			return Locale.text("bench.map.spawn_one")
		"road_on":
			return Locale.text("bench.road.on")
		"road_off":
			return Locale.text("bench.road.off")
		"placed", "moved":
			return Locale.format("bench.map.moved", [cell.x, cell.y])
		"removed":
			return Locale.text("bench.map.removed")
		"need_spawn":
			return Locale.text("bench.map.need_spawn")
		"occupied":
			return Locale.text("bench.map.occupied")
		"rock":
			return Locale.text("bench.map.rock")
		"outside":
			return Locale.text("bench.map.outside")
		_:
			return ""


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "PlacePopup"
	_panel.visible = false
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 4
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.11, 0.09, 0.98)
	box.border_color = Color(0.9, 0.78, 0.4)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(scroll)
	_panel_box = VBoxContainer.new()
	_panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_panel_box)
	view.add_child(_panel)


func _rebuild_panel() -> void:
	if _panel_box == null or not MapPlan.in_bounds(_selected):
		return
	while _panel_box.get_child_count() > 0:
		var child := _panel_box.get_child(0)
		_panel_box.remove_child(child)
		child.queue_free()
	var title := _label(Locale.format("bench.map.cell", [_selected.x, _selected.y]))
	title.add_theme_font_size_override("font_size", 20)
	_panel_box.add_child(title)
	var here := _label(_cell_blurb())
	here.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(here)
	if _status_text != "":
		var status := _label(_status_text)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_color_override("font_color", Color(1, 0.82, 0.45))
		_panel_box.add_child(status)
	if not MapPlan.is_fixed_rock(_selected):
		var road_key := "bench.road.clear" if doc.is_road(_selected) else "bench.road.paint"
		_panel_box.add_child(_action_button(Locale.text(road_key), {"op": "toggle_road", "cell": _selected}))
	if MapInteraction.zone_of(_selected) == "gate":
		_panel_box.add_child(_action_button(Locale.text("bench.spawn.set"), {"op": "set_spawn", "cell": _selected}))
	var hit := doc.hit_at(_selected)
	if not hit.is_empty():
		_panel_box.add_child(_action_button(Locale.text("bench.map.remove"), {"op": "remove", "cell": _selected}))
	if _can_place(hit):
		_add_place_group(Locale.text("bench.palette.units"), MapPlan.unit_palette())
		_add_place_group(Locale.text("bench.palette.builds"), MapPlan.build_palette())
		_add_place_group(Locale.text("bench.inspect.props"), MapPlan.prop_palette())
	var close := _action_button(Locale.text("bench.pick_close"), {})
	close.pressed.connect(close_inspector)
	_panel_box.add_child(close)


func _add_place_group(title: String, items: Array) -> void:
	var heading := _label(title)
	heading.add_theme_color_override("font_color", Color(0.78, 0.9, 0.72))
	_panel_box.add_child(heading)
	for spec in items:
		if not (spec is Dictionary):
			continue
		var label := Locale.text(str(spec.get("label", "")))
		var cmd := {
			"op": "place",
			"layer": str(spec.get("layer", "")),
			"id": str(spec.get("id", "")),
			"cell": _selected,
		}
		_panel_box.add_child(_action_button(label, cmd))


func _can_place(hit: Dictionary) -> bool:
	if MapInteraction.zone_of(_selected) != "interior":
		return false
	if MapPlan.is_fixed_rock(_selected) or doc.spawn_lookup().has(_selected):
		return false
	return hit.is_empty()


func _cell_blurb() -> String:
	var hit := doc.hit_at(_selected)
	var parts: PackedStringArray = PackedStringArray()
	if doc.is_road(_selected):
		parts.append(Locale.text("bench.inspect.road"))
	else:
		parts.append(Locale.text("bench.inspect.empty"))
	if str(hit.get("layer", "")) == "spawn":
		parts.append(Locale.text("bench.spawn.tag"))
	elif not hit.is_empty():
		var key := _label_key(str(hit.get("layer", "")), str(hit.get("id", "")))
		parts.append(Locale.text(key) if key != "" else str(hit.get("id", "")))
	return " · ".join(parts)


func _label_key(layer: String, id: String) -> String:
	for group in [MapPlan.unit_palette(), MapPlan.build_palette(), MapPlan.prop_palette()]:
		for item in group:
			if str(item.get("layer", "")) == layer and str(item.get("id", "")) == id:
				return str(item.get("label", ""))
	return ""


func _action_button(text: String, cmd: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(0, 36)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	if not cmd.is_empty():
		btn.pressed.connect(_run_panel_cmd.bind(cmd))
	return btn


func _run_panel_cmd(cmd: Dictionary) -> void:
	_on_command(cmd)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _combined_note() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var own := doc.load_note()
	if own != "":
		parts.append(own)
	for code in Balance.layout_notes():
		var line := _hint_for({"action": str(code)})
		if line != "" and own.find(line) < 0:
			parts.append(line)
	return " ".join(parts)


func _emit_hint(text: String) -> void:
	hint_changed.emit(text)


func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	if inner.size.x < 8.0 or inner.size.y < 8.0:
		return false
	return outer.position.x <= inner.position.x + 1.0 and outer.position.y <= inner.position.y + 1.0 and outer.end.x + 1.0 >= inner.end.x and outer.end.y + 1.0 >= inner.end.y


func _combat_node_count() -> int:
	var n := 0
	for node in find_children("*", "", true, false):
		var script_res = node.get_script()
		if script_res == null:
			continue
		var path := str(script_res.resource_path)
		if path.ends_with("building.gd") or path.ends_with("villager.gd") or path.ends_with("zombie.gd"):
			n += 1
	return n
