extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var h := IsoVolume.HALF
	var pts := PackedVector2Array([
		Vector2(-h, -h),
		Vector2(h, -h),
		Vector2(h, h),
		Vector2(-h, h),
	])
	draw_colored_polygon(pts, Color(0.95, 0.86, 0.35, 0.22))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.92, 0.45, 0.95), 5.0, true)
