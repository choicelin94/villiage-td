class_name Building
extends Node2D

enum Kind { WALL, SPEAR, FIRE, HOUSE, FARM, WORKSHOP, LUMBER, SPEAR_BARRACKS, GUN_BARRACKS }

var kind: Kind = Kind.WALL
var cell := Vector2i.ZERO
var hp := 1
var max_hp := 1
var defense := 0.0
var always_bar := true
var cooldown := 0.0
var _stats: Dictionary = {}
var crew: Array[Node2D] = []
var _muzzle := Vector2(0, -40)
var _locked: Zombie = null
var _lock_left := 0.0
var produce_cd := 0.0

static func kind_key(p_kind: Kind) -> String:
	match p_kind:
		Kind.WALL:
			return "WALL"
		Kind.SPEAR:
			return "SPEAR"
		Kind.FIRE:
			return "FIRE"
		Kind.HOUSE:
			return "HOUSE"
		Kind.FARM:
			return "FARM"
		Kind.WORKSHOP:
			return "WORKSHOP"
		Kind.LUMBER:
			return "LUMBER"
		Kind.SPEAR_BARRACKS:
			return "SPEAR_BARRACKS"
		Kind.GUN_BARRACKS:
			return "GUN_BARRACKS"
	return "WALL"

func _prune_crew() -> void:
	var kept: Array[Node2D] = []
	for node in crew:
		if node != null and is_instance_valid(node) and not bool(node.get("infected")) and not bool(node.get("fallen")) and not bool(node.get("leaving")):
			kept.append(node)
	crew = kept

func staff_cap() -> int:
	if not is_functional():
		return 0
	if kind == Kind.LUMBER:
		return maxi(int(_stats.get("staff_slots", 4)), 0)
	return 1

func staff_count() -> int:
	_prune_crew()
	return crew.size()

func villager_crew() -> int:
	_prune_crew()
	var n := 0
	for node in crew:
		if str(node.get("unit_id")) == "villager":
			n += 1
	return n

func has_staff() -> bool:
	return staff_count() > 0

func primary_staff() -> Node2D:
	_prune_crew()
	if crew.is_empty():
		return null
	return crew[0]

func holds(person: Node) -> bool:
	_prune_crew()
	return person != null and person in crew

func add_crew(person: Node2D) -> void:
	_prune_crew()
	if person == null or person in crew:
		return
	crew.append(person)

func dismiss(person: Node) -> void:
	_prune_crew()
	crew.erase(person)

func dismiss_all() -> Array[Node2D]:
	_prune_crew()
	var copy: Array[Node2D] = crew.duplicate()
	crew.clear()
	return copy

func provides() -> Dictionary:
	var row = _stats.get("provides", {})
	return row if row is Dictionary else {}

func produce_spec() -> Dictionary:
	var row = _stats.get("produces", {})
	return row if row is Dictionary else {}

func staff_produces() -> bool:
	return str(produce_spec().get("mode", "")) == "staff"

func is_functional() -> bool:
	return kind != Kind.WALL

func setup(p_kind: Kind, p_cell: Vector2i) -> void:
	kind = p_kind
	cell = p_cell
	_stats = Balance.building_by_kind(kind_key(kind))
	max_hp = int(_stats.get("hp", 1))
	hp = max_hp
	defense = float(_stats.get("defense", 0.0))
	var tex: Texture2D = load(str(_stats.get("tex", "")))
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var size := tex.get_size()
	sprite.position = Vector2(-size.x * 0.5, IsoVolume.HALF - size.y)
	sprite.z_as_relative = true
	sprite.z_index = 0
	add_child(sprite)
	_muzzle = Vector2(0, sprite.position.y + size.y * 0.42)
	if kind == Kind.FIRE:
		var flame := Flame.new()
		flame.position = _muzzle
		flame.z_as_relative = true
		flame.z_index = 0
		add_child(flame)
	var bar := HpBar.new()
	bar.z_as_relative = true
	bar.z_index = 0
	bar.y_off = sprite.position.y - 8.0
	add_child(bar)
	add_to_group("iso")

var _volume: IsoVolume

func get_iso_volume() -> IsoVolume:
	if _volume == null:
		_volume = IsoVolume.from_cell(cell, _volume_key())
	_volume.node = self
	var sprite := _art()
	_volume.screen_rect = IsoVolume.sprite_rect(sprite) if sprite else Rect2(global_position, Vector2(8, 8))
	return _volume

func _volume_key() -> String:
	match kind:
		Kind.WALL:
			return "wall"
		Kind.SPEAR:
			return "spear"
		Kind.FIRE:
			return "fire"
		Kind.HOUSE:
			return "house"
		Kind.FARM:
			return "farm"
		Kind.WORKSHOP:
			return "workshop"
		Kind.LUMBER:
			return "lumber"
		Kind.SPEAR_BARRACKS:
			return "spear_barracks"
		Kind.GUN_BARRACKS:
			return "gun_barracks"
	return "house"

func _art() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null

func is_defense() -> bool:
	return str(_stats.get("category", "")) == "defense"

func _process(delta: float) -> void:
	queue_redraw()
	_lock_left = maxf(_lock_left - delta, 0.0)
	if not bool(_stats.get("can_attack", false)) or hp <= 0:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := _acquire()
	if target == null:
		return
	var rate := float(_stats.get("attack_speed", 0.0))
	cooldown = 1.0 / rate if rate > 0.0 else 0.64
	_shoot(target)

func _in_range(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and not z.dying and global_position.distance_to(z.global_position) <= float(_stats.get("attack_range", 0.0))

func _best_target() -> Zombie:
	var best: Zombie = null
	var best_core := INF
	var game := _game()
	if game == null:
		return null
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if not _in_range(z):
			continue
		var core_d := z.global_position.distance_to(game.core_pos)
		if core_d < best_core:
			best_core = core_d
			best = z
	return best

func _acquire() -> Zombie:
	var hold := Balance.combat_f("target_hold", 1.2)
	var margin := Balance.combat_f("switch_margin", 0.72)
	var best := _best_target()
	if _in_range(_locked) and _lock_left > 0.0:
		return _locked
	if _in_range(_locked) and best != null and best != _locked:
		var old_d := global_position.distance_to(_locked.global_position)
		var new_d := global_position.distance_to(best.global_position)
		if new_d > old_d * margin:
			_lock_left = hold
			return _locked
	if best != _locked:
		_lock_left = hold
	elif _lock_left <= 0.0:
		_lock_left = hold
	_locked = best
	return _locked

func _shoot(target: Zombie) -> void:
	var shot := Projectile.new()
	var aim := target.global_position + target.step_hint * 0.12
	var bonus := 1.0
	var game := _game()
	if game:
		bonus = float(game.tower_bonus())
	var attack := float(_stats.get("attack", 0.0)) * bonus
	shot.setup(global_position + _muzzle, aim, target, attack, float(_stats.get("splash", 0.0)), float(_stats.get("shot_speed", 0.0)), kind == Kind.FIRE)
	game.fx.add_child(shot)

func hurt(amount: int) -> bool:
	hp -= amount
	if hp <= 0:
		hp = 0
		return true
	return false

func _game() -> Node:
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	var rad := 36.0 if is_defense() else 42.0
	draw_circle(Vector2.ZERO, rad, Color(0, 0, 0, 0.22))
	var stationed := staff_count()
	if is_functional() and stationed > 0:
		var art := _art()
		var dot_at := Vector2(0, -70)
		if art:
			dot_at = Vector2(0, art.position.y + 14.0)
		var shown := mini(stationed, 4)
		var span := 14.0
		var origin := dot_at.x - span * float(shown - 1) * 0.5
		for i in shown:
			draw_circle(Vector2(origin + span * float(i), dot_at.y), 5, Color(0.4, 0.85, 0.45))
	if bool(_stats.get("can_attack", false)) and _game() and _game().inspected == self:
		draw_arc(Vector2.ZERO, float(_stats.get("attack_range", 0.0)), 0, TAU, 48, Color(1, 0.86, 0.35, 0.55), 2.0)


class Flame:
	extends Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var flick := 0.8 + 0.25 * sin(Time.get_ticks_msec() / 70.0)
		draw_circle(Vector2(0, 2), 10.0 * flick, Color(1, 0.38, 0.05, 0.75))
		draw_circle(Vector2(0, -8.0 * flick), 5.5, Color(1, 0.9, 0.4, 0.95))


class HpBar:
	extends Node2D

	var y_off := -140.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := get_parent()
		if p.hp >= p.max_hp and not p.always_bar:
			return
		var w := 46.0
		var ratio := clampf(float(p.hp) / float(maxi(p.max_hp, 1)), 0.0, 1.0)
		var col := Color(0.35, 0.78, 0.32) if ratio > 0.35 else Color(0.85, 0.28, 0.18)
		draw_rect(Rect2(-w * 0.5, y_off, w, 5), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, y_off, w * ratio, 5), col)
