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

var _actor: SpineActor
var _skin := 0
var _goal := Vector2.ZERO
var _retarget := 0.0
var _facing := 2
var _frame := 0
var _frame_t := 0.0
var _steps := 0
var _path: Array[Vector2i] = []
var _path_i := 0
var _held_job := false
var anchored := false

func setup(p_skin: int, p_sex: String, p_speed: float) -> void:
	sex = p_sex
	speed = p_speed
	_skin = p_skin

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("iso")
	_actor = SpineActor.new()
	_actor.kind = "villager"
	_actor.skin = _skin
	add_child(_actor)
	_set_frame(2, 0)
	_goal = global_position
	_retarget = randf_range(0.2, 1.0)

func face_texture() -> AtlasTexture:
	if _actor:
		return _actor.portrait()
	return AtlasTexture.new()

func get_iso_volume() -> IsoVolume:
	var vol := IsoVolume.from_feet(global_position)
	vol.node = self
	var body := _actor.sprite() if _actor else null
	vol.screen_rect = IsoVolume.sprite_rect(body) if body else Rect2(global_position, Vector2(8, 8))
	return vol

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
	while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0 * IsoVolume.WORLD_SCALE:
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
	if vel.length() < 8.0 * IsoVolume.WORLD_SCALE:
		if _path_i < _path.size():
			_path_i += 1
			if _path_i >= _path.size():
				_retarget = 0.0
			_hold_idle(delta)
			return
		_retarget = 0.0
		_hold_idle(delta)
		return
	var dir := vel.normalized()
	var step_speed := speed * (1.15 if panic else 0.72)
	var step := minf(step_speed * delta, vel.length())
	var nxt: Vector2 = global_position + dir * step
	if game.can_step(global_position, nxt, self):
		global_position = nxt
		_step_anim(dir, delta)
		return
	var slide := Vector2(dir.x, 0) if absf(dir.x) > absf(dir.y) else Vector2(0, dir.y)
	if slide.length_squared() > 0.001:
		var alt: Vector2 = global_position + slide.normalized() * step
		if game.can_step(global_position, alt, self):
			global_position = alt
			_step_anim(slide, delta)
			return
	_path.clear()
	_path_i = 0
	_retarget = 0.0
	_hold_idle(delta)

func _step_anim(vel: Vector2, delta: float) -> void:
	# Callers pass a unit direction. A threshold of 1 px rejected those, so a
	# villager kept the idle south row while the 4-direction path turned north.
	if vel.length_squared() > 0.000001:
		_facing = LpcFacing.row_for(vel)
	_frame_t += delta
	_steps += 1
	var count := 6
	if _actor:
		count = maxi(_actor.clip_count("move"), 1)
	if _frame_t >= 0.09:
		_frame_t = 0.0
		_frame = (_frame + 1) % count
	if _actor:
		_actor.show_frame("move", _frame, _facing)

func _set_frame(row: int, frame: int) -> void:
	_facing = row
	_frame = frame
	if _actor:
		_actor.show_frame("idle", frame, row)

func _hold_idle(delta: float) -> void:
	if _actor == null:
		return
	_frame_t += delta
	var count := maxi(_actor.clip_count("idle"), 1)
	if _frame_t >= 0.1:
		_frame_t = 0.0
		_frame = (_frame + 1) % count
	_actor.show_frame("idle", _frame, _facing)

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
			while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0 * IsoVolume.WORLD_SCALE:
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
	if vel.length() < 8.0 * IsoVolume.WORLD_SCALE:
		_path_i += 1
		return
	var dir := vel.normalized()
	var nxt: Vector2 = global_position + dir * minf(speed * delta, vel.length())
	if game.can_step(global_position, nxt, self):
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
		var bar_y := _actor.bar_y() if _actor else -120.0
		draw_line(Vector2(-14, bar_y), Vector2(-14 + 28.0 * clampf(claim_left / 6.5, 0, 1), bar_y), Color(1, 0.9, 0.3), 3.0)
