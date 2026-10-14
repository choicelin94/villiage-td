class_name MapInteraction
extends RefCounted

# One pointer policy for click and for drag-drop.
# Interior empty ground asks for a friendly. The outer ring, except the
# four corners, sets a 3×1 gate whose middle is the cell under the pointer.
# North and south run along x. West and east run along y. MapPlan owns
# that geometry; this class only chooses the command.

var pressing := false
var dragging := false
var press_pos := Vector2.ZERO
var press_cell := Vector2i(-1, -1)
var drag: Dictionary = {}
var hover := Vector2i(-1, -1)
var ghost: Dictionary = {}
var ghost_cell := Vector2i(-99, -99)


static func zone_of(cell: Vector2i) -> String:
	if not MapPlan.in_bounds(cell):
		return "outside"
	if MapPlan.is_corner(cell):
		return "corner"
	if MapPlan.is_border(cell):
		return "gate"
	return "interior"


static func op_for(cell: Vector2i, carrying: Dictionary, occupied: bool) -> Dictionary:
	var layer := str(carrying.get("layer", ""))
	var has_id := carrying.has("id") and str(carrying.get("id", "")) != ""
	if not MapPlan.in_bounds(cell):
		return {"op": "reject", "reason": "outside", "cell": cell}
	if MapPlan.is_corner(cell):
		return {"op": "reject", "reason": "corner", "cell": cell}
	if MapPlan.is_fixed_rock(cell):
		return {"op": "reject", "reason": "rock", "cell": cell}
	if MapPlan.is_border(cell):
		if layer == "spawn":
			return {"op": "move_spawn", "index": int(carrying.get("index", -1)), "cell": cell}
		if not has_id:
			return {"op": "set_spawn", "cell": cell}
		return {"op": "reject", "reason": "outside", "cell": cell}
	if layer == "spawn":
		return {"op": "reject", "reason": "outside", "cell": cell}
	if occupied:
		return {"op": "reject", "reason": "occupied", "cell": cell}
	if not has_id:
		return {"op": "pick", "cell": cell}
	if carrying.has("index"):
		return {
			"op": "move",
			"layer": layer,
			"index": int(carrying.get("index", -1)),
			"id": str(carrying.get("id", "")),
			"cell": cell,
		}
	return {"op": "place", "layer": layer, "id": str(carrying.get("id", "")), "cell": cell}


func arm(cell: Vector2i, pos: Vector2, hit: Dictionary) -> void:
	pressing = true
	dragging = false
	press_pos = pos
	press_cell = cell
	drag = hit


func note_motion(cell: Vector2i, pos: Vector2) -> void:
	hover = cell
	if pressing and pos.distance_to(press_pos) > 8.0:
		dragging = true


func release(cell: Vector2i, doc: SetupDocument) -> Dictionary:
	var carrying: Dictionary = {}
	if dragging and not drag.is_empty():
		carrying = drag
	var occupied := doc.blocks_new(cell, carrying)
	var cmd := op_for(cell, carrying, occupied)
	pressing = false
	dragging = false
	drag = {}
	return cmd


func drop_command(cell: Vector2i, payload: Dictionary, doc: SetupDocument) -> Dictionary:
	var carrying := {
		"layer": str(payload.get("layer", "")),
		"id": str(payload.get("id", "")),
	}
	return op_for(cell, carrying, doc.blocks_new(cell, {}))


func clear_ghost() -> void:
	ghost = {}
	ghost_cell = Vector2i(-99, -99)
