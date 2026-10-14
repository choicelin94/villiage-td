class_name MapBoard
extends Control

# Hosts the layout document, the command applier, and the art preview.
# Pointer events from MapView become MapCommands. Click and drop share
# MapInteraction.op_for.

signal place_requested(cell: Vector2i, at: Vector2)
signal hint_changed(text: String)
signal changed

var state: Dictionary = {}
var doc: SetupDocument
var interaction: MapInteraction
var view: MapView
var _last_action := ""


func setup(p_state: Dictionary, p_font: Font) -> void:
	state = p_state
	doc = SetupDocument.new()
	doc.bind(state)
	interaction = MapInteraction.new()
	custom_minimum_size = Vector2(760, 760)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = MapView.new()
	view.setup(doc, interaction, p_font)
	view.command_issued.connect(_on_command)
	add_child(view)
	_fit_view()


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
	if view:
		view.queue_redraw()
	return _last_action


func probe_edits() -> bool:
	var commands_ok := MapCommands.golden()
	var corner := edit_click(Vector2i(0, 0))
	var before := doc.spawn_rects().size()
	var spawned := edit_click(Vector2i(3, 0))
	var rects := doc.spawn_rects()
	var cell_ok := false
	if rects.size() == before + 1:
		var cells := MapPlan.cells_of_rect(rects[rects.size() - 1])
		cell_ok = cells.size() == 3 and cells[0] == Vector2i(2, 0) and cells[1] == Vector2i(3, 0) and cells[2] == Vector2i(4, 0)
	var pick := edit_click(Vector2i(10, 8))
	var placed := place_payload({"layer": "unit", "id": "spearman", "volume": "walker"}, Vector2i(10, 8))
	var border_reject := not place_payload({"layer": "build", "id": "WALL", "volume": "wall"}, Vector2i(5, 0))
	var rock_reject := not place_payload({"layer": "prop", "id": "tree", "volume": "tree"}, Vector2i(4, 8))
	var prop_ok := place_payload({"layer": "prop", "id": "rock", "volume": "rock"}, Vector2i(6, 6))
	var art_ok := ActorPainter.has_art("build", "HOUSE") and ActorPainter.has_art("unit", "villager") and ActorPainter.has_art("unit", "spearman") and ActorPainter.has_art("prop", "tree") and ActorPainter.has_art("prop", "rock")
	var combat_nodes := _combat_node_count()
	var ok := commands_ok and corner == "corner" and spawned == "spawn" and cell_ok and pick == "pick" and placed and border_reject and rock_reject and prop_ok and art_ok and combat_nodes == 0
	print("BENCH_EDIT corner=", corner, " spawn=", spawned, " cell=", cell_ok, " pick=", pick, " placed=", placed, " border=", border_reject, " rock=", rock_reject, " prop=", prop_ok, " art=", art_ok, " commands=", commands_ok, " combat=", combat_nodes)
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_view()


func _fit_view() -> void:
	if view == null:
		return
	view.position = Vector2.ZERO
	view.size = size if size.x > 32.0 and size.y > 32.0 else custom_minimum_size


func _on_command(cmd: Dictionary) -> void:
	var result: Dictionary = MapCommands.apply(doc, cmd)
	_after(result)
	if str(result.get("action", "")) == "pick":
		var cell: Vector2i = result.get("cell", Vector2i.ZERO)
		var at: Vector2 = cmd.get("at", get_global_position())
		place_requested.emit(cell, at)


func _after(result: Dictionary) -> void:
	_last_action = str(result.get("action", ""))
	var text := _hint_for(result)
	if text != "":
		hint_changed.emit(text)
	if view:
		view.queue_redraw()
	if bool(result.get("ok", false)) and _last_action != "pick":
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
