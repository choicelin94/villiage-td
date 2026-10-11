class_name Zombie
extends Node2D

const FOOT_PAD := 31.0 * 96.0 / 311.0

var hp := 1
var max_hp := 1
var speed := 48.0
var core_damage := 1
var reward_wood := 2
var reward_gold := 4
var body_scale := 1.0
var dying := false
var always_bar := false
var step_hint := Vector2.ZERO
var kind_name := "normal"

var _path: Array[Vector2i] = []
var _path_i := 0
var _attack := Vector2i(-1, -1)
var _attack_core := false
var _attacking := false
var _cooldown := 0.0
var _flash := 0.0
var _death := 0.0
var _repath_cd := 0.0
var _rewarded := false
var _anim: AnimatedSprite2D
var _base_mod := Color.WHITE

static var _frames: SpriteFrames

func setup(p_hp: int, p_speed: float, p_scale: float, p_dmg: int, p_wood: int, p_gold: int, p_kind: String, p_mod: Color) -> void:
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	body_scale = p_scale
	core_damage = p_dmg
	reward_wood = p_wood
	reward_gold = p_gold
	kind_name = p_kind
	_base_mod = p_mod
	scale = Vector2(p_scale, p_scale)

func _ready() -> void:
	add_to_group("zombies")
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _get_frames()
	_anim.centered = false
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_anim.z_index = 1
	add_child(_anim)
	_play("move")
	var bar := HpBarZ.new()
	bar.z_index = 3
	add_child(bar)
	_repath()

func _get_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_add_anim("move", "move", 17, 9.0)
	_add_anim("attack", "attack", 9, 12.0)
	return _frames

func _add_anim(anim_name: String, prefix: String, count: int, fps: float) -> void:
	_frames.add_animation(anim_name)
	_frames.set_animation_loop(anim_name, true)
	_frames.set_animation_speed(anim_name, fps)
	for i in count:
		_frames.add_frame(anim_name, load("res://assets/enemies/%s_%02d.png" % [prefix, i]))

func _play(anim_name: String) -> void:
	if _anim.animation != anim_name:
		_anim.play(anim_name)
	_anchor()

func _anchor() -> void:
	var tex := _anim.sprite_frames.get_frame_texture(_anim.animation, 0)
	if tex == null:
		return
	_anim.position = Vector2(-tex.get_width() * 0.5, FOOT_PAD - tex.get_height())

func notify_map_changed() -> void:
	_repath()

func hurt(amount: int) -> void:
	if dying:
		return
	hp -= amount
	_flash = 0.1
	if hp <= 0:
		hp = 0
		_die()

func _die() -> void:
	if dying:
		return
	dying = true
	_death = 0.28
	if not _rewarded:
		_rewarded = true
		var game := _game()
		if game:
			game.on_zombie_killed(self)

func _process(delta: float) -> void:
	queue_redraw()
	if dying:
		_death -= delta
		modulate.a = clampf(_death / 0.28, 0.0, 1.0)
		if _death <= 0.0:
			queue_free()
		return
	_flash = maxf(_flash - delta, 0.0)
	_anim.modulate = Color(1, 0.55, 0.5) if _flash > 0.0 else _base_mod
	if _attacking:
		_repath_cd -= delta
		if _repath_cd <= 0.0:
			_repath_cd = 0.55
			_repath()
			if not _attacking:
				return
		_do_attack(delta)
		return
	if _path_i >= _path.size():
		_repath()
		if _path_i >= _path.size():
			if _attack.x >= 0 or _attack_core:
				_attacking = true
				_play("attack")
			return
	var game := _game()
	if game == null:
		return
	var goal: Vector2 = game.cell_center(_path[_path_i])
	var diff: Vector2 = goal - global_position
	var dist: float = diff.length()
	if dist < 5.0:
		_path_i += 1
		if _path_i >= _path.size():
			if _attack.x >= 0 or _attack_core:
				_attacking = true
				_play("attack")
		return
	var dir: Vector2 = diff / dist
	var step := minf(speed * delta, dist)
	global_position += dir * step
	step_hint = dir * speed
	_anim.flip_h = dir.x < 0.0
	_separate(delta)
	if _anim.animation != "move":
		_play("move")

func _do_attack(delta: float) -> void:
	var game := _game()
	if game == null:
		return
	var target_cell: Vector2i = _attack if _attack.x >= 0 else game.core_cell
	var target_pos: Vector2 = game.cell_center(target_cell)
	var diff: Vector2 = target_pos - global_position
	if diff.x != 0.0:
		_anim.flip_h = diff.x < 0.0
	if not game.can_attack_cell(_attack, _attack_core):
		_attacking = false
		_repath()
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = 0.9
		game.damage_cell(_attack, _attack_core, core_damage)
		_play("attack")

func _separate(delta: float) -> void:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other == self or other.dying:
			continue
		var d := global_position - other.global_position
		var len := d.length()
		if len > 0.1 and len < 22.0:
			push += d / len * (22.0 - len)
	if push != Vector2.ZERO:
		global_position += push * minf(delta * 3.0, 0.4)

func _repath() -> void:
	var game := _game()
	if game == null:
		return
	var here: Vector2i = game.world_to_cell(global_position)
	if not game.in_bounds(here):
		here = game.nearest_spawn(global_position)
	var info: Dictionary = game.route_from(here)
	_path = info.path
	_path_i = 0
	_attack = info.attack
	_attack_core = info.core
	_attacking = false
	while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 6.0:
		_path_i += 1
	if _path_i >= _path.size() and (_attack.x >= 0 or _attack_core):
		_attacking = true
		_play("attack")

func _game() -> Node:
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 6.0 + 4.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))


class HpBarZ:
	extends Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := get_parent()
		if p.hp >= p.max_hp:
			return
		var w := 32.0
		var y := -52.0
		var ratio := clampf(float(p.hp) / float(maxi(p.max_hp, 1)), 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, y, w, 4), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, y, w * ratio, 4), Color(0.75, 0.2, 0.18))
