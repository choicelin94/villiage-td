extends Node2D

var hp := 1
var max_hp := 1
var title := ""
var font: Font

func _ready() -> void:
	font = load("res://assets/fonts/DroidSansFallback-subset.ttf")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if font != null and title != "":
		font.draw_string(get_canvas_item(), Vector2(-22, -16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.92, 0.62))
	var w := 56.0
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var col := Color(0.4, 0.82, 0.35) if ratio > 0.35 else Color(0.9, 0.25, 0.18)
	draw_rect(Rect2(-w * 0.5, -8, w, 6), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w * 0.5, -8, w * ratio, 6), col)
