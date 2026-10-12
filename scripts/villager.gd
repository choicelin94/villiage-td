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
var _goal := Vector2.ZERO
var _retarget := 0.0
var _bob := 0.0

func setup(p_tex: Texture2D, p_sex: String, p_speed: float) -> void:
	sex = p_sex
	speed = p_speed
	_tex = p_tex

func _ready() -> void:
	add_to_group("villagers")
	_sprite = Sprite2D.new()
	_sprite.texture = _tex
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(-_tex.get_width() * 0.5, -_tex.get_height())
	_sprite.z_index = 0
	add_child(_sprite)
	_goal = global_position
	_retarget = randf_range(0.2, 1.0)

func _process(delta: float) -> void:
	if infected or leaving:
		queue_redraw()
		if leaving:
			_leave(delta)
		return
	_bob += delta
	var game := _game()
	if game == null:
		return
	if job != null and is_instance_valid(job):
		global_position = job.global_position + Vector2(0, 8 + sin(_bob * 3.0) * 2.0)
		_sprite.flip_h = false
		queue_redraw()
		return
	if refugee and claim_left > 0.0:
		claim_left -= delta
		if claim_left <= 0.0 and game.phase != "win" and game.phase != "lose":
			if not housed:
				leaving = true
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
	_goal = game.cell_center(cell)

func _walk(delta: float, game: Node) -> void:
	var panic: bool = game.should_panic(self)
	var vel := _goal - global_position
	if panic:
		var pull: Vector2 = game.safe_point() - global_position
		if pull.length() > 8.0:
			vel = vel.normalized() * 0.45 + pull.normalized() * 0.55
			vel *= 140.0
	if vel.length() < 6.0:
		_retarget = 0.0
		return
	var dir := vel.normalized()
	var step_speed := speed * (1.15 if panic else 0.72)
	var nxt: Vector2 = global_position + dir * step_speed * delta
	if game.walkable(nxt):
		global_position = nxt
	else:
		var slide := Vector2(dir.x, 0) if absf(dir.x) > absf(dir.y) else Vector2(0, dir.y)
		var alt: Vector2 = global_position + slide.normalized() * step_speed * delta
		if game.walkable(alt):
			global_position = alt
		else:
			_retarget = 0.0
	_sprite.flip_h = dir.x < 0.0

func _leave(delta: float) -> void:
	global_position += Vector2(0, -speed * delta)
	var game := _game()
	if game and global_position.y < game.cell_center(Vector2i(0, 0)).y - 80.0:
		queue_free()

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
		var bar_y := -float(_tex.get_height()) - 8.0
		draw_line(Vector2(-14, bar_y), Vector2(-14 + 28.0 * clampf(claim_left / 6.5, 0, 1), bar_y), Color(1, 0.9, 0.3), 3.0)
