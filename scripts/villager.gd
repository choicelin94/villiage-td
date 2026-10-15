class_name Villager
extends Node2D

var sex := "m"
var unit_id := "villager"
var speed := 108.0
var hp := 1
var max_hp := 1
var defense := 0.0
var attack := 0.0
var attack_speed := 1.0
var attack_range := 0.0
var housed := false
var refugee := false
var infected := false
var fallen := false
var leaving := false
var claim_left := -1.0
var job: Building = null
var selected := false
var ordered := false
var order_goal := Vector2.ZERO
var pending_job: Building = null
var stand_left := 0.0

const ROAD_BONUS := 1.65
const ENTER_REACH := 56.0

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
var foe: Zombie = null
var foe_hold := 0.0
var strike_cd := 0.0
var path_cd := 0.0

func is_fighter() -> bool:
	return unit_id != "" and unit_id != "villager"

func configure(def: Dictionary) -> void:
	unit_id = str(def.get("id", "villager"))
	max_hp = maxi(int(round(float(def.get("hp", 1)))), 1)
	hp = max_hp
	defense = float(def.get("defense", 0.0))
	attack = float(def.get("attack", 0.0))
	attack_speed = float(def.get("attack_speed", 1.0))
	attack_range = float(def.get("attack_range", 0.0))
	if def.has("move_speed"):
		speed = float(def.move_speed)

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

func stand_at(world: Vector2) -> void:
	ordered = false
	pending_job = null
	stand_left = 2.5
	global_position = world
	visible = true
	_path.clear()
	_path_i = 0
	_goal = world
	_retarget = stand_left
	_held_job = false

func command_move(cell: Vector2i) -> bool:
	var game := _game()
	if game == null:
		return false
	if not _begin_order(cell, game.cell_center(cell)):
		return false
	pending_job = null
	return true

func command_enter(building: Building) -> bool:
	var game := _game()
	if game == null or building == null or not is_instance_valid(building):
		return false
	if not game.has_method("front_of"):
		return false
	var door: Vector2 = game.front_of(building)
	var cell: Vector2i = game.world_to_cell(door)
	if game.has_method("_stand_ok") and not bool(game._stand_ok(cell)):
		return false
	if not _begin_order(cell, door):
		return false
	pending_job = building
	return true

func _begin_order(cell: Vector2i, goal: Vector2) -> bool:
	var game := _game()
	if game == null:
		return false
	# A failed retarget must not drop the order already being walked.
	var old_ordered := ordered
	var old_goal := order_goal
	var old_path: Array[Vector2i] = []
	old_path.assign(_path)
	var old_i := _path_i
	var old_stand := stand_left
	var old_walk := _goal
	stand_left = 0.0
	var here: Vector2i = game.world_to_cell(global_position)
	_path = game.route_cells(here, cell)
	_path_i = 0
	while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0 * IsoVolume.WORLD_SCALE:
		_path_i += 1
	var close := global_position.distance_to(goal) <= ENTER_REACH * IsoVolume.WORLD_SCALE
	if _path.is_empty() or (_path_i >= _path.size() and here != cell and not close):
		ordered = old_ordered
		order_goal = old_goal
		_path.clear()
		_path.append_array(old_path)
		_path_i = old_i
		stand_left = old_stand
		_goal = old_walk
		return false
	order_goal = goal
	ordered = true
	if _path_i < _path.size():
		_goal = game.cell_center(_path[_path_i])
	else:
		_goal = goal
	return true

func guide_color() -> Color:
	if sex == "f":
		return Color(1.0, 0.46, 0.72, 1.0)
	return Color(0.32, 0.84, 1.0, 1.0)


func guide_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if not ordered or is_fighter():
		return points
	var game := _game()
	if game == null:
		return points
	points.append(global_position)
	var previous := global_position
	for i in range(_path_i, _path.size()):
		var center: Vector2 = game.cell_center(_path[i])
		if center.distance_to(previous) < 6.0:
			continue
		points.append(center)
		previous = center
	if order_goal.distance_to(previous) >= 6.0:
		points.append(order_goal)
	elif points.size() < 2:
		points.append(order_goal)
	return points


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
		ordered = false
		pending_job = null
		stand_left = 0.0
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
		_path.clear()
		_path_i = 0
		if stand_left <= 0.0 and not ordered:
			_retarget = 0.0
	visible = true
	if is_fighter():
		_fight(delta, game)
		queue_redraw()
		return
	if refugee and claim_left > 0.0:
		claim_left -= delta
		if claim_left <= 0.0 and game.phase != "win" and game.phase != "lose":
			if not housed:
				leaving = true
				ordered = false
				pending_job = null
				_path.clear()
				_path_i = 0
				_goal = global_position + Vector2(0, -800)
				queue_redraw()
				return
			refugee = false
			claim_left = -1.0
	if game.should_panic(self):
		if ordered:
			ordered = false
			pending_job = null
			_path.clear()
			_path_i = 0
			_retarget = 0.0
		stand_left = 0.0
		_retarget -= delta
		if _retarget <= 0.0:
			_pick_goal(game)
		_walk(delta, game)
		queue_redraw()
		return
	if ordered:
		_follow_order(delta, game)
		queue_redraw()
		return
	if selected or stand_left > 0.0:
		if stand_left > 0.0:
			stand_left = maxf(stand_left - delta, 0.0)
		_hold_idle(delta)
		queue_redraw()
		return
	_retarget -= delta
	if _retarget <= 0.0:
		_pick_goal(game)
	_walk(delta, game)
	queue_redraw()

func _follow_order(delta: float, game: Node) -> void:
	if pending_job != null and not is_instance_valid(pending_job):
		pending_job = null
		ordered = false
		return
	if _at_door():
		_finish_enter(game)
		return
	_walk(delta, game)
	if not ordered:
		return
	if _at_door():
		_finish_enter(game)
		return
	var arrived := pending_job == null and global_position.distance_to(order_goal) <= 24.0 * IsoVolume.WORLD_SCALE
	if arrived:
		ordered = false
		_path.clear()
		if not selected:
			stand_left = 1.2
			_retarget = stand_left
		return
	var stuck := _path.is_empty() or _path_i >= _path.size()
	if stuck and global_position.distance_to(order_goal) > ENTER_REACH * IsoVolume.WORLD_SCALE:
		ordered = false
		pending_job = null
		_path.clear()
		if game.has_method("order_stuck"):
			game.order_stuck()

func _at_door() -> bool:
	return pending_job != null and is_instance_valid(pending_job) and global_position.distance_to(order_goal) <= ENTER_REACH * IsoVolume.WORLD_SCALE

func _finish_enter(game: Node) -> void:
	var building := pending_job
	ordered = false
	pending_job = null
	_path.clear()
	_path_i = 0
	if building != null and game.has_method("complete_staff"):
		game.complete_staff(self, building)

func _pick_goal(game: Node) -> void:
	var panic: bool = game.should_panic(self)
	var base := Balance.combat_f("panic_hold", 1.3) if panic else Balance.combat_f("wander_hold", 2.4)
	_retarget = base * randf_range(0.85, 1.15)
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
	var step_speed := speed if is_fighter() else speed * _pace(game, panic)
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
	_retarget = 0.45
	_hold_idle(delta)

func _fight(delta: float, game: Node) -> void:
	foe_hold = maxf(foe_hold - delta, 0.0)
	strike_cd -= delta
	path_cd -= delta
	var hold := Balance.combat_f("target_hold", 1.2)
	var margin := Balance.combat_f("switch_margin", 0.72)
	if not _foe_ok(foe):
		foe = null
	var best := _nearest_zombie()
	if foe == null:
		foe = best
		foe_hold = hold
		_path.clear()
	elif foe_hold <= 0.0 and best != null and best != foe:
		var old_d := global_position.distance_to(foe.global_position)
		var new_d := global_position.distance_to(best.global_position)
		if new_d < old_d * margin:
			foe = best
			foe_hold = hold
			_path.clear()
		else:
			foe_hold = hold
	if foe == null:
		_hold_idle(delta)
		return
	var dist := global_position.distance_to(foe.global_position)
	_facing = LpcFacing.row_for(foe.global_position - global_position)
	if dist <= attack_range:
		_path.clear()
		_path_i = 0
		if strike_cd <= 0.0:
			var rate := attack_speed if attack_speed > 0.0 else 1.0
			strike_cd = 1.0 / rate
			_strike(game, foe)
		_hold_idle(delta)
		return
	if path_cd <= 0.0 or _path.is_empty():
		path_cd = Balance.combat_f("repath", 0.6)
		var here: Vector2i = game.world_to_cell(global_position)
		var goal: Vector2i = game.approach_cell(here, game.world_to_cell(foe.global_position))
		_path = game.route_cells(here, goal)
		_path_i = 0
		while _path_i < _path.size() and global_position.distance_to(game.cell_center(_path[_path_i])) < 10.0 * IsoVolume.WORLD_SCALE:
			_path_i += 1
	if _path_i >= _path.size():
		_hold_idle(delta)
		return
	_walk(delta, game)

func _foe_ok(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and not z.dying

func _nearest_zombie() -> Zombie:
	var best: Zombie = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if not _foe_ok(z):
			continue
		var d := global_position.distance_squared_to(z.global_position)
		if d < best_d:
			best_d = d
			best = z
	return best

func _strike(game: Node, z: Zombie) -> void:
	if attack_range >= 96.0:
		var shot := Projectile.new()
		shot.setup(global_position + Vector2(0, -36), z.global_position, z, attack, 0.0, 700.0, false)
		if game.fx:
			game.fx.add_child(shot)
		return
	z.hurt(Balance.damage(attack, z.defense))

func hurt(amount: int) -> void:
	if fallen or infected or not is_fighter():
		return
	hp -= amount
	if hp <= 0:
		hp = 0
		fallen = true
		if job != null and is_instance_valid(job):
			job.dismiss(self)
		job = null
		visible = false
		remove_from_group("iso")
		remove_from_group("villagers")
		queue_free()

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
			var flee := speed
			if not is_fighter() and game.has_method("on_road") and bool(game.on_road(global_position)):
				flee *= ROAD_BONUS
			var vel := Vector2(0, -flee)
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
	var leave_speed := speed
	if not is_fighter() and game.has_method("on_road") and bool(game.on_road(global_position)):
		leave_speed *= ROAD_BONUS
	var nxt: Vector2 = global_position + dir * minf(leave_speed * delta, vel.length())
	if game.can_step(global_position, nxt, self):
		global_position = nxt
		_step_anim(dir, delta)
	else:
		_path.clear()
		_path_i = 0
		if not is_fighter():
			_retarget = 0.45

func _pace(game: Node, panic: bool) -> float:
	var pace := 1.15 if panic else 0.72
	if game.has_method("on_road") and bool(game.on_road(global_position)):
		pace *= ROAD_BONUS
	return pace

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
