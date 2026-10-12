extends Node2D

func _ready() -> void:
	add_to_group("iso")

func iso_points() -> PackedVector2Array:
	var sprite := _art()
	if sprite:
		return IsoSort.front_edge(sprite)
	return IsoSort.footprint(global_position)

func iso_rect() -> Rect2:
	var sprite := _art()
	if sprite:
		return IsoSort.front_rect(sprite)
	return Rect2(global_position, Vector2.ZERO)

func _art() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null
