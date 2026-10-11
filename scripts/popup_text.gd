class_name PopupText
extends Node2D

var text := ""
var color := Color.WHITE
var font: Font
var t := 0.0

func setup(p_text: String, p_color: Color, p_font: Font) -> void:
	text = p_text
	color = p_color
	font = p_font

func _process(delta: float) -> void:
	t += delta
	position.y -= 28.0 * delta
	modulate.a = clampf(1.0 - t / 0.85, 0.0, 1.0)
	queue_redraw()
	if t >= 0.85:
		queue_free()

func _draw() -> void:
	if font == null:
		return
	font.draw_string(get_canvas_item(), Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
