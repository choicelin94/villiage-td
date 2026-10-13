class_name Zombie
extends Node2D

var hp := 1
var max_hp := 1
var speed := 72.0
var bite := 1
var defense := 0.0
var attack_speed := 1.1111111111111112
var attack_range := 128.0
var xp_reward := 0
var reward_wood := 2
var reward_gold := 4
var body_scale := 1.0
var dying := false
var step_hint := Vector2.ZERO
var kind_name := "normal"
var fresh := 0.0

var _path: Array[Vector2i] = []
var _path_i := 0
var _attack := Vector2i(-1, -1)
var _attacking := false
var _cooldown := 0.0
var _flash := 0.0
var _death := 0.0
var _repath_cd := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _rewarded := false
var _actor: SpineActor
var _visual := "spear"
var _base_mod := Color.WHITE
var _facing := 2
var _frame_i := 0
var _frame_t := 0.0
var _hurt_t := 0.0
var _death_i := 0
var _death_t := 0.0

func setup(p_hp: int, p_speed: float, p_scale: float, p_dmg: int, p_wood: int, p_gold: int, p_kind: String, p_mod: Color, p_visual: String = "spear") -> void:
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	body_scale = p_scale
	reward_wood = p_wood
	reward_gold = p_gold
	kind_name = p_kind
	_base_mod = p_mod
	_visual = p_visual
	bite = maxi(p_dmg, 1)
	scale = Vector2(p_scale, p_scale)

func mark_fresh() -> void:
	fresh = 0.85

func _ready() -> void:
	add_to_group("zombies")
	add_to_group("iso")
	_actor = SpineActor.new()
	_actor.kind = _visual
	_actor.skin = 0
	add_child(_actor)
	_face(Vector2.DOWN, 0.0, false)
	var bar := HpBarZ.new()
	bar.z_as_relative = true
	bar.z_index = 0
	add_child(bar)
	_repath()

func _face(vel: Vector2, delta: float, faster: bool) -> void:
	if vel.length_squared() > 0.000001:
		_facing = LpcFacing.row_for(vel)
	var clip := "move"
	if _hurt_t > 0.0 and _actor != null and _actor.clip_count("hurt") > 0:
		clip = "hurt"
	elif faster and _actor != null and _actor.clip_count("attack") > 0:
		clip = "attack"
	_frame_t += delta
	var step := 0.08 if clip != "move" else 0.1
	var count := 1
	if _actor:
		count = maxi(_actor.clip_count(clip), 1)
	if _frame_t >= step:
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % count
	if _actor:
		_actor.show_frame(clip, _frame_i, _facing)

func notify_map_changed() -> void:
	_repath()

func hurt(amount: int) -> void:
	if dying:
		return
	hp -= amount
	_flash = 0.1
	_hurt_t = 0.32
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

func get_iso_volume() -> IsoVolume:
	var vol := IsoVolume.from_feet(global_position)
	vol.node = self
	var body := _actor.sprite() if _actor else null
	vol.screen_rect = IsoVolume.sprite_rect(body) if body else Rect2(global_position, Vector2(8, 8))
	return vol

func _process(delta: float) -> void:
	queue_redraw()
	fresh = maxf(fresh - delta, 0.0)
	if dying:
		_death -= delta
		modulate.a = clampf(_death / 0.28, 0.0, 1.0)
		_death_t += delta
		if _actor and _actor.clip_count("death") > 0 and _death_t >= 0.045:
			_death_t = 0.0
			_death_i += 1
			_actor.show_frame("death", _death_i, _facing)
		if _death <= 0.0:
			queue_free()
		return
	_flash = maxf(_flash - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	var tint := _base_mod
	if fresh > 0.0:
		tint = Color(1, 1, 0.45)
	elif _flash > 0.0:
		tint = Color(1, 0.55, 0.5)
	if _actor:
		_actor.modulate = tint
	_repath_cd -= delta
	var moved := global_position.distance_to(_last_pos)
	if _last_pos != Vector2.ZERO and moved < speed * delta * 0.25:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	if _path_i >= _path.size() and not _attacking:
		_repath_cd = minf(_repath_cd, 0.0)
	var need_path := _repath_cd <= 0.0 or _stuck_t > 0.85
	if _attacking:
		if need_path:
			_repath_cd = 0.7
			_stuck_t = 0.0
			_repath()
			if not _attacking:
				return
		_do_attack(delta)
		return
	if need_path:
		_repath_cd = 0.7
		_stuck_t = 0.0
		_repath()
	if _path_i >= _path.size():
		_hold_idle(delta)
		return
	var game := _game()
	if game == null:
		return
	var goal: Vector2 = game.cell_center(_path[_path_i])
	var diff: Vector2 = goal - global_position
	var dist: float = diff.length()
	if dist < 12.0 * IsoVolume.WORLD_SCALE:
		_path_i += 1
		if _path_i >= _path.size() and _attack.x >= 0:
			_attacking = true
		return
	var dir: Vector2 = diff / dist
	var step := minf(speed * delta, dist)
	var nxt: Vector2 = global_position + dir * step
	if game.can_step(global_position, nxt, self):
		global_position = nxt
		step_hint = dir * speed
		_face(diff, delta, false)
	else:
		_stuck_t += delta
	_separate(delta, dir)

func _do_attack(delta: float) -> void:
	var game := _game()
	if game == null:
		return
	if _attack.x < 0 or not game.can_attack_cell(_attack):
		_attacking = false
		_repath()
		return
	var target_pos: Vector2 = game.cell_center(_attack)
	_face(target_pos - global_position, delta, true)
	_cooldown -= delta
	if _cooldown <= 0.0:
		var rate := attack_speed if attack_speed > 0.0 else 1.0
		_cooldown = 1.0 / rate
		game.damage_cell(_attack, float(bite))

func _separate(delta: float, forward: Vector2) -> void:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other == self or other.dying:
			continue
		var d := global_position - other.global_position
		var len := d.length()
		var need := IsoVolume.walker_separation(d) * IsoVolume.TILE
		if len > 0.1 and len < need:
			push += d / len * (need - len)
	if push == Vector2.ZERO:
		return
	var along := push.dot(forward)
	if along < 0.0:
		push -= forward * along
	var game := _game()
	var nxt: Vector2 = global_position + push * minf(delta * 3.0, 0.35)
	if game == null or game.can_step(global_position, nxt, self):
		global_position = nxt

func _repath() -> void:
	var game := _game()
	if game == null:
		return
	var here: Vector2i = game.world_to_cell(global_position)
	if not game.in_bounds(here):
		here = game.nearest_spawn(global_position)
	var info: Dictionary = game.route_from(here)
	var new_path: Array[Vector2i] = info.path
	var idx := 0
	# A refresh used to restart at the cell under the zombie, so they walked
	# back to a center they had already left and jittered in place.
	while idx < new_path.size():
		var center: Vector2 = game.cell_center(new_path[idx])
		var close := global_position.distance_to(center) < 16.0 * IsoVolume.WORLD_SCALE
		var occupied := new_path[idx] == here and idx < new_path.size() - 1
		if close or occupied:
			idx += 1
			continue
		break
	_path = new_path
	_path_i = idx
	_attack = info.attack
	_attacking = false
	if _path_i >= _path.size() and _attack.x >= 0:
		_attacking = true

func bar_anchor() -> float:
	return _actor.bar_y() if _actor else -110.0

func _hold_idle(delta: float) -> void:
	if _actor == null:
		return
	_frame_t += delta
	var count := maxi(_actor.clip_count("idle"), 1)
	if _frame_t >= 0.12:
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % count
	_actor.show_frame("idle", _frame_i, _facing)

func _game() -> Node:
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	if fresh > 0.0:
		draw_arc(Vector2(0, -30), 26, 0, TAU, 20, Color(1, 0.95, 0.4, fresh), 3.0)
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 7.0 + 2.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))


class HpBarZ:
	extends Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := get_parent()
		if p.hp >= p.max_hp:
			return
		var w := 32.0
		var y := -110.0
		if p.has_method("bar_anchor"):
			y = p.bar_anchor()
		var ratio := clampf(float(p.hp) / float(maxi(p.max_hp, 1)), 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, y, w, 4), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, y, w * ratio, 4), Color(0.75, 0.2, 0.18))
