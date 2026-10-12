extends Node2D

var cell := Vector2i.ZERO
var volume_key := "tree"
var _volume: IsoVolume

func _ready() -> void:
	add_to_group("iso")

func get_iso_volume() -> IsoVolume:
	if _volume == null:
		_volume = IsoVolume.from_cell(cell, volume_key)
	_volume.node = self
	var sprite := _art()
	_volume.screen_rect = IsoVolume.sprite_rect(sprite) if sprite else Rect2(global_position, Vector2(8, 8))
	return _volume

func _art() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null
