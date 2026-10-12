extends Node2D

func _ready() -> void:
	add_to_group("iso")

func iso_points() -> PackedVector2Array:
	return IsoSort.footprint(global_position)

func iso_rect() -> Rect2:
	for child in get_children():
		if child is Sprite2D:
			return IsoSort.sprite_rect(child)
	return Rect2(global_position, Vector2.ZERO)
