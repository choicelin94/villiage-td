class_name IsoBody
extends RefCounted

# Walkers share one slicing rule. Each band is its own sorted drawable.

const SLICE_H := 32

static func attach(parent: Node2D, tex: Texture2D) -> Array[IsoSlice]:
	var slices: Array[IsoSlice] = []
	var bands := LpcFacing.FRAME / SLICE_H
	for i in bands:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var slice := IsoSlice.new()
		slice.texture = atlas
		slice.centered = false
		slice.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slice.position = Vector2(-LpcFacing.FRAME * 0.5, -LpcFacing.FRAME + 6.0 + i * SLICE_H)
		slice.foot = parent
		slice.band = i
		slice.y_off = slice.position.y + SLICE_H
		slice.anchor = i == bands - 1
		parent.add_child(slice)
		slices.append(slice)
	paint(slices, 0, 2)
	return slices

static func paint(slices: Array[IsoSlice], frame: int, row: int) -> void:
	var base := LpcFacing.region(frame, row)
	for slice in slices:
		slice.flip_h = false
		var atlas := slice.texture as AtlasTexture
		if atlas == null:
			continue
		atlas.region = Rect2(base.position.x, base.position.y + slice.band * SLICE_H, base.size.x, SLICE_H)
