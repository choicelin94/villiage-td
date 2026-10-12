class_name IsoSlice
extends Sprite2D

# One horizontal band of a walker. Its sort point is the bottom of the band,
# so bands higher on the body can sit behind a prop the feet are already in
# front of. The anchor band copies its rank onto the walker so rings and
# bars drawn on the root stay with the feet.

var foot: Node2D
var y_off := 0.0
var band := 0
var anchor := false

func _ready() -> void:
	add_to_group("iso")
	z_as_relative = false

func iso_points() -> PackedVector2Array:
	if foot == null:
		return PackedVector2Array([global_position])
	return PackedVector2Array([foot.to_global(Vector2(0.0, y_off))])

func iso_rect() -> Rect2:
	return IsoSort.sprite_rect(self)

func sync_root() -> void:
	if not anchor or foot == null:
		return
	foot.z_as_relative = false
	foot.z_index = z_index
