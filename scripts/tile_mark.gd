extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array([
		Vector2(0, -49),
		Vector2(88, 0),
		Vector2(0, 49),
		Vector2(-88, 0),
	])
	draw_colored_polygon(pts, Color(0.95, 0.86, 0.35, 0.22))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.92, 0.45, 0.95), 5.0, true)
