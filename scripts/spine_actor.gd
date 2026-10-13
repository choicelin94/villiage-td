class_name SpineActor
extends Node2D

# Frame sequences exported from the Spine projects. Feet sit on this node's
# origin, which is the same point IsoVolume.from_feet uses.
# A SpineSprite is created only when the spine-godot GDExtension is installed.
# The extension is not part of this repo: the Spine Runtimes License requires
# a Spine Editor license to ship it, and GitHub Pages cannot be given the
# COOP/COEP headers Godot's web extension export expects. See CREDITS.md.

const DATA_PATH := "res://data/characters.json"

static var _catalog: Dictionary = {}
static var _announced := false

var kind := "villager"
var skin := 0

var _spec: Dictionary = {}
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _sheet: Texture2D
var _frame_size := Vector2(128, 128)
var _foot := Vector2(64, 120)
var _faces_right := true
var _flip := false
var _spine: Node = null
var _spine_clip := ""
var _using_spine := false


func _ready() -> void:
	_spec = spec_for(kind)
	var frame: Array = _spec.frame
	_frame_size = Vector2(float(frame[0]), float(frame[1]))
	var foot: Array = _spec.foot
	_foot = Vector2(float(foot[0]), float(foot[1]))
	_faces_right = bool(_spec.faces_right)
	var sheets: Array = _spec.sheets
	var sheet_path: String = str(sheets[skin % sheets.size()])
	_sheet = load(sheet_path)
	_atlas = AtlasTexture.new()
	_atlas.atlas = _sheet
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = _atlas
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.position = Vector2(-_foot.x, -_foot.y)
	_sprite.z_as_relative = true
	_sprite.z_index = 0
	add_child(_sprite)
	_try_spine()
	show_frame("idle", 0, 2)


func sprite() -> Sprite2D:
	return _sprite


func using_spine() -> bool:
	return _using_spine


func bar_y() -> float:
	return -_foot.y + 20.0


func clip_count(clip: String) -> int:
	if _spec.is_empty():
		return 0
	var clips: Dictionary = _spec.clips
	if not clips.has(clip):
		return 0
	return int(clips[clip].count)


func portrait() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = Rect2(0, 0, _frame_size.x, _frame_size.y)
	return atlas


func show_frame(clip: String, frame: int, row: int) -> void:
	if _atlas == null or _spec.is_empty():
		return
	var clips: Dictionary = _spec.clips
	if not clips.has(clip):
		clip = "move" if clips.has("move") else "idle"
	var info: Dictionary = clips[clip]
	var count := maxi(int(info.count), 1)
	var idx := posmod(frame, count)
	_atlas.region = Rect2(idx * _frame_size.x, int(info.row) * _frame_size.y, _frame_size.x, _frame_size.y)
	_apply_row(row)
	if _using_spine:
		_drive_spine(clip)


func _apply_row(row: int) -> void:
	# Rows are the LPC screen directions: 1 left, 3 right. North and south
	# keep the last horizontal flip. These packs are side views, so that is
	# the facing they can show without playing the cycle backwards.
	if row == 1 or row == 3:
		var want_right := row == 3
		_flip = want_right != _faces_right
	_sprite.flip_h = _flip
	if not _using_spine or _spine == null:
		return
	var skeleton: Object = _spine.call("get_skeleton")
	if skeleton != null and skeleton.has_method("set_scale_x"):
		skeleton.call("set_scale_x", -1.0 if _flip else 1.0)


func _drive_spine(clip: String) -> void:
	if not _spec.has("spine"):
		return
	var anims: Dictionary = _spec.spine.anims
	if not anims.has(clip):
		return
	var anim_name := str(anims[clip])
	if anim_name == "" or anim_name == _spine_clip:
		return
	var state: Object = _spine.call("get_animation_state")
	if state == null or not state.has_method("set_animation"):
		return
	state.call("set_animation", anim_name, clip != "death", 0)
	_spine_clip = anim_name


func _try_spine() -> void:
	if not _spec.has("spine"):
		return
	if not ClassDB.class_exists("SpineSprite"):
		return
	if not ClassDB.class_exists("SpineAtlasResource") or not ClassDB.class_exists("SpineSkeletonFileResource"):
		return
	if not ClassDB.class_exists("SpineSkeletonDataResource"):
		return
	var spine_info: Dictionary = _spec.spine
	var atlas_path := str(spine_info.atlas)
	var json_path := str(spine_info.json)
	if not FileAccess.file_exists(atlas_path) or not FileAccess.file_exists(json_path):
		return
	var atlas: Object = ClassDB.instantiate("SpineAtlasResource")
	var err: int = int(atlas.call("load_from_atlas_file", atlas_path))
	if err != OK:
		push_warning("Spine atlas did not load (%s)" % err)
		return
	var skel_file: Object = ClassDB.instantiate("SpineSkeletonFileResource")
	err = int(skel_file.call("load_from_file", json_path))
	if err != OK:
		push_warning("Spine skeleton did not load (%s)" % err)
		return
	var data: Object = ClassDB.instantiate("SpineSkeletonDataResource")
	data.call("set_atlas_res", atlas)
	data.call("set_skeleton_file_res", skel_file)
	if data.has_method("is_skeleton_data_loaded") and not bool(data.call("is_skeleton_data_loaded")):
		push_warning("Spine skeleton data did not load")
		return
	_spine = ClassDB.instantiate("SpineSprite")
	add_child(_spine)
	_spine.call("set_skeleton_data_res", data)
	var skins: Array = spine_info.skins
	var skin_name := str(skins[skin % skins.size()])
	var skeleton: Object = _spine.call("get_skeleton")
	if skeleton != null and skeleton.has_method("set_skin_by_name"):
		skeleton.call("set_skin_by_name", skin_name)
		if skeleton.has_method("set_slots_to_setup_pose"):
			skeleton.call("set_slots_to_setup_pose")
	_sprite.visible = false
	_using_spine = true
	_spine_clip = ""
	if not _announced:
		_announced = true
		print("SPINE_SPRITE ", kind, " ", skin_name)


static func spec_for(kind: String) -> Dictionary:
	if _catalog.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file == null:
			push_error("Missing character catalog")
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_catalog = parsed
	if not _catalog.has(kind):
		return {}
	return _catalog[kind]
