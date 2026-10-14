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
	_font = CatalogPaths.load_font()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if kind == Kind.LINE:
		_draw_line()
	elif kind == Kind.DOT:
		_draw_line()
		draw_circle(Vector2.ZERO, 4.0, color)
	elif kind == Kind.TAG:
		_draw_tag()

func _draw_line() -> void:
	if source == null or not source.has_method("get_iso_volume"):
		return
	var vol: IsoVolume = source.get_iso_volume()
	if vol.ground_poly_iso.size() < 2:
		return
	var ground := PackedVector2Array()
	for p in vol.ground_poly_iso:
		ground.append(to_local(IsoVolume.iso_to_world(p)))
	var ring := ground.duplicate()
	ring.append(ground[0])
	draw_polyline(ring, color, 3.0)
	var lift := -vol.max_z * IsoVolume.TILE * 0.32
	var top := PackedVector2Array()
	for p in ground:
		top.append(p + Vector2(0.0, lift))
	var top_ring := top.duplicate()
	top_ring.append(top[0])
	var faint := Color(color.r, color.g, color.b, color.a * 0.65)
	draw_polyline(top_ring, faint, 2.0)
	for i in ground.size():
		draw_line(ground[i], top[i], faint, 1.5)

func _draw_tag() -> void:
	if _font == null or text_key == "":
		return
	var text := Locale.text(text_key)
	draw_string(_font, Vector2(-18, -18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.96, 0.85))
