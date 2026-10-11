class_name Burst
extends Node2D

var radius := 18.0
var color := Color(1, 0.55, 0.15)
var t := 0.0
var duration := 0.32

func setup(p_radius: float, p_color: Color) -> void:
	radius = p_radius
	color = p_color

func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if t >= duration:
		queue_free()

func _draw() -> void:
	var k := t / duration
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, radius * (0.25 + k), Color(color.r, color.g, color.b, a * 0.35))
	draw_arc(Vector2.ZERO, radius * (0.45 + k * 0.9), 0, TAU, 28, Color(1, 0.95, 0.7, a), 2.0)
