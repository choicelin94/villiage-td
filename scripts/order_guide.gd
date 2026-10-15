extends Node2D

# Ground overlay for a villager move or enter order. One line follows the
# remaining walk path, and a reticle sits on the destination. Both stay up
# for every unit that still has an order, including after that unit is
# deselected. They drop out when the order finishes, is replaced, or is
# cancelled (panic, stuck, arrival, enter). Selection is not consulted.

var _shown := false


func _process(_delta: float) -> void:
	var active := false
	for node in get_tree().get_nodes_in_group("villagers"):
		var person := node as Villager
		if _showing(person):
			active = true
			break
	if active or _shown:
		queue_redraw()
	_shown = active


func _draw() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var person := node as Villager
		if not _showing(person):
			continue
		var raw := person.guide_points()
		if raw.size() < 2:
			continue
		var points := PackedVector2Array()
		for spot in raw:
			points.append(to_local(spot))
		var color := person.guide_color()
		_draw_route(points, color)
		_draw_mark(to_local(person.order_goal), color)


func _showing(person: Villager) -> bool:
	return person != null and person.visible and person.ordered and not person.is_fighter()


func _draw_route(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, Color(0.04, 0.03, 0.02, 0.78), 10.0, true)
	draw_polyline(points, Color(color.r, color.g, color.b, 0.95), 5.0, true)
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	if length < 8.0:
		return
	var dist := fmod(float(Time.get_ticks_msec()) * 0.09, length)
	var at := points[0]
	for i in range(1, points.size()):
		var span := points[i - 1].distance_to(points[i])
		if dist <= span:
			at = points[i - 1].lerp(points[i], dist / maxf(span, 0.001))
			break
		dist -= span
	draw_circle(at, 6.0, Color(1, 1, 1, 0.95))


func _draw_mark(at: Vector2, color: Color) -> void:
	var wave := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.007)
	var radius := 28.0 + 7.0 * wave
	draw_arc(at, radius + 4.0, 0, TAU, 36, Color(0, 0, 0, 0.6), 8.0, true)
	draw_arc(at, radius, 0, TAU, 36, color, 4.5, true)
	draw_circle(at, 9.0, Color(color.r, color.g, color.b, 0.92))
	draw_circle(at, 4.0, Color(1, 1, 1, 0.98))
	var reach := 20.0
	var gap := 8.0
	var white := Color(1, 1, 1, 0.96)
	draw_line(at + Vector2(-reach, 0), at + Vector2(-gap, 0), white, 3.0, true)
	draw_line(at + Vector2(gap, 0), at + Vector2(reach, 0), white, 3.0, true)
	draw_line(at + Vector2(0, -reach), at + Vector2(0, -gap), white, 3.0, true)
	draw_line(at + Vector2(0, gap), at + Vector2(0, reach), white, 3.0, true)
	var corner := 36.0
	var tick := 14.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var tip := at + Vector2(sx * corner, sy * corner)
			draw_line(tip, tip + Vector2(-sx * tick, 0), white, 3.5, true)
			draw_line(tip, tip + Vector2(0, -sy * tick), white, 3.5, true)
