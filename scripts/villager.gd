class_name Villager
extends Node2D

var sex := "m"
var speed := 108.0
var housed := false
var refugee := false
var infected := false
var leaving := false
var claim_left := -1.0
var job: Building = null
var selected := false

var _tex: Texture2D
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _goal := Vector2.ZERO
var _retarget := 0.0
var _facing := 2
var _frame := 0
var _frame_t := 0.0
var _path: Array[Vector2i] = []
var _path_i := 0
var _held_job := false
var anchored := false

func setup(p_tex: Texture2D, p_sex: String, p_speed: float) -> void:
	sex = p_sex
	speed = p_speed
	_tex = p_tex

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("iso")
	_atlas = AtlasTexture.new()
	_atlas.atlas = _tex
	_atlas.region = LpcFacing.region(0, _facing)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(-LpcFacing.FRAME * 0.5, -LpcFacing.FRAME + 6.0)
	_sprite.z_as_relative = true
	_sprite.z_index = 0
	add_child(_sprite)
	_goal = global_position
	_retarget = randf_range(0.2, 1.0)

func face_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _tex
	atlas.region = LpcFacing.region(0, 2)
	return atlas

func iso_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])

func iso_rect() -> Rect2:
	return IsoSort.sprite_rect(_sprite)

func _process(delta: float) -> void:
	if job != null and is_instance_valid(job) and not infected and not leaving:
		visible = false
		global_position = job.global_position
		_held_job = true
		_path.clear()
		_path_i = 0
		return
	if anchored:
		queue_redraw()
		return
	if infected or leaving:
		queue_redraw()
		if leaving:
			_leave(delta)
		return
	var game := _game()
	if game == null:
		return
	if _held_job:
		_held_job = false
		visible = true
		_retarget = 0.0
		_path.clear()
		_path_i = 0
	visible = true
	if refugee and claim_left > 0.0:
		claim_left -= delta
		if claim_left <= 0.0 and game.phase != "win" and game.phase != "lose":
			if not housed:
				leaving = true
				_path.clear()
				_path_i = 0
				_goal = global_position + Vector2(0, -800)
				queue_redraw()
				return
			refugee = false
			claim_left = -1.0
	_retarget -= delta
	if _retarget <= 0.0:
		_pick_goal(game)
	_walk(delta, game)
	queue_redraw()

func _pick_goal(game: Node) -> void:
	var panic: bool = game.should_panic(self)
	_retarget = randf_range(0.35, 0.7) if panic else randf_range(1.1, 2.2)
	var cell: Vector2i = game.wander_cell(self, panic)
	var here: Vector2i = game.world_to_cell(global_position)
	_path = game.route_cells(here, cell)
	_path_i = 0
	while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0:
		_path_i += 1
	if _path_i < _path.size():
		_goal = game.cell_center(_path[_path_i])
	else:
		_goal = game.cell_center(cell)

func _walk(delta: float, game: Node) -> void:
	var panic: bool = game.should_panic(self)
	if _path_i < _path.size():
		_goal = game.cell_center(_path[_path_i])
	var vel := _goal - global_position
	if vel.length() < 8.0:
		if _path_i < _path.size():
			_path_i += 1
			if _path_i >= _path.size():
				_retarget = 0.0
			return
		_retarget = 0.0
		return
	var dir := vel.normalized()
	var step_speed := speed * (1.15 if panic else 0.72)
	var step := minf(step_speed * delta, vel.length())
	var nxt: Vector2 = global_position + dir * step
	if game.can_step(global_position, nxt):
		global_position = nxt
		_step_anim(dir, delta)
		return
	var slide := Vector2(dir.x, 0) if absf(dir.x) > absf(dir.y) else Vector2(0, dir.y)
	if slide.length_squared() > 0.001:
		var alt: Vector2 = global_position + slide.normalized() * step
		if game.can_step(global_position, alt):
			global_position = alt
			_step_anim(slide, delta)
			return
	_path.clear()
	_path_i = 0
	_retarget = 0.0

func _step_anim(vel: Vector2, delta: float) -> void:
	if vel.length_squared() > 1.0:
		_facing = LpcFacing.row_for(vel)
	_frame_t += delta
	if _frame_t >= 0.09:
		_frame_t = 0.0
		_frame = (_frame + 1) % LpcFacing.COLS
	_set_frame(_facing, _frame)

func _set_frame(row: int, frame: int) -> void:
	_facing = row
	_frame = frame
	_sprite.flip_h = false
	if _atlas:
		_atlas.region = LpcFacing.region(frame, row)

func _leave(delta: float) -> void:
	var game := _game()
	if game == null:
		return
	if _path_i >= _path.size():
		if _path.is_empty():
			var here: Vector2i = game.world_to_cell(global_position)
			var exit_cell: Vector2i = game.nearest_spawn(global_position)
			_path = game.route_cells(here, exit_cell)
			_path_i = 0
			while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0:
				_path_i += 1
		if _path_i >= _path.size():
			var vel := Vector2(0, -speed)
			global_position += vel * delta
			_step_anim(vel, delta)
			if global_position.y < game.cell_center(Vector2i(0, 0)).y - 80.0:
				queue_free()
			return
	var goal: Vector2 = game.cell_center(_path[_path_i])
	var vel := goal - global_position
	if vel.length() < 8.0:
		_path_i += 1
		return
	var dir := vel.normalized()
	var nxt: Vector2 = global_position + dir * minf(speed * delta, vel.length())
	if game.can_step(global_position, nxt):
		global_position = nxt
		_step_anim(dir, delta)
	else:
		_path.clear()
		_path_i = 0

func _game() -> Node:
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	var col := Color(0.35, 0.75, 1, 0.9) if sex == "m" else Color(1, 0.55, 0.75, 0.9)
	if refugee:
		col = Color(1, 0.85, 0.25, 0.95)
	if selected:
		col = Color(1, 1, 1, 1)
	draw_arc(Vector2(0, -8), 22 if selected else 16, 0, TAU, 24, col, 2.0 if selected else 1.4)
	if refugee and claim_left > 0.0:
		var bar_y := -float(LpcFacing.FRAME) - 8.0
		draw_line(Vector2(-14, bar_y), Vector2(-14 + 28.0 * clampf(claim_left / 6.5, 0, 1), bar_y), Color(1, 0.9, 0.3), 3.0)
