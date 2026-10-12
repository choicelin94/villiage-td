class_name IsoMark
extends Node2D

# A mark is not its own sorted object. Parent it to the thing it describes
# and it inherits that depth, so a walker in front covers the line and a
# walker behind is covered by it.

enum Kind { LINE, DOT, TAG }

var kind := Kind.LINE
var color := Color(1, 0.86, 0.25, 0.95)
var source: Node2D
var text_key := ""
var _font: Font

func _ready() -> void:
	z_as_relative = true
	z_index = 0
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if kind == Kind.LINE:
		_draw_line()
	elif kind == Kind.DOT:
		draw_circle(Vector2.ZERO, 6.0, color)
	elif kind == Kind.TAG:
		_draw_tag()

func _draw_line() -> void:
	if source == null or not source.has_method("iso_points"):
		return
	var pts: PackedVector2Array = source.iso_points()
	if pts.size() < 2:
		return
	var local := PackedVector2Array()
	for p in pts:
		local.append(to_local(p))
	draw_polyline(local, color, 3.0)

func _draw_tag() -> void:
	if _font == null or text_key == "":
		return
	var text := Locale.text(text_key)
	draw_string(_font, Vector2(-18, -18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.96, 0.85))
