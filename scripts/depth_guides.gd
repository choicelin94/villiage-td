extends Node2D

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Regular.otf")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var lab := get_parent()
	if lab == null or not lab.get("house"):
		return
	var house: Building = lab.house
	var tree: Node2D = lab.tree
	var rock: Node2D = lab.rock
	_line(house.iso_points(), Color(1, 0.86, 0.25, 0.95))
	_line(IsoSort.footprint(tree.global_position), Color(0.45, 0.9, 0.45, 0.9))
	_line(IsoSort.footprint(rock.global_position), Color(0.75, 0.8, 0.85, 0.9))
	_dot(lab.player.global_position, Color(0.4, 0.75, 1))
	if lab.near_one.visible:
		_dot(lab.near_one.global_position, Color(0.4, 0.9, 0.5))
		_tag(lab.near_one.global_position, Locale.text("lab.tag_near"))
	if lab.far_one.visible:
		_dot(lab.far_one.global_position, Color(1, 0.45, 0.4))
		_tag(lab.far_one.global_position, Locale.text("lab.tag_far"))
	_tag(lab.player.global_position, Locale.text("lab.tag_you"))

func _line(pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, color, 3.0)

func _dot(at: Vector2, color: Color) -> void:
	draw_circle(at, 6.0, color)

func _tag(at: Vector2, text: String) -> void:
	if _font == null or text == "":
		return
	draw_string(_font, at + Vector2(-18, -132), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.96, 0.85))
