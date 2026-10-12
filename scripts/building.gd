class_name Building
extends Node2D

enum Kind { WALL, SPEAR, FIRE, HOUSE, FARM, WORKSHOP }

# Sprites are 256px renders. The ground diamond center sits at (127.5, 134).
const SPRITE_OFF := Vector2(-127.5, -134.0)

const STATS := {
	Kind.WALL: {
		"hp": 170, "wood": 18, "gold": 0,
		"range": 0.0, "dmg": 0, "cd": 0.0, "splash": 0.0, "shot_speed": 0.0,
		"defense": true, "cap": 0,
		"tex": "res://assets/village/wall.png",
	},
	Kind.SPEAR: {
		"hp": 200, "wood": 24, "gold": 40,
		"range": 460.0, "dmg": 24, "cd": 0.64, "splash": 0.0, "shot_speed": 700.0,
		"defense": true, "cap": 0,
		"tex": "res://assets/village/spear.png",
	},
	Kind.FIRE: {
		"hp": 160, "wood": 16, "gold": 64,
		"range": 420.0, "dmg": 18, "cd": 1.05, "splash": 120.0, "shot_speed": 380.0,
		"defense": true, "cap": 0,
		"tex": "res://assets/village/fire.png",
	},
	Kind.HOUSE: {
		"hp": 120, "wood": 22, "gold": 0,
		"range": 0.0, "dmg": 0, "cd": 0.0, "splash": 0.0, "shot_speed": 0.0,
		"defense": false, "cap": 4,
		"tex": "res://assets/village/house.png",
	},
	Kind.FARM: {
		"hp": 80, "wood": 16, "gold": 12,
		"range": 0.0, "dmg": 0, "cd": 0.0, "splash": 0.0, "shot_speed": 0.0,
		"defense": false, "cap": 0,
		"tex": "res://assets/village/farm.png",
	},
	Kind.WORKSHOP: {
		"hp": 100, "wood": 20, "gold": 28,
		"range": 0.0, "dmg": 0, "cd": 0.0, "splash": 0.0, "shot_speed": 0.0,
		"defense": false, "cap": 0,
		"tex": "res://assets/village/workshop.png",
	},
}

var kind: Kind = Kind.WALL
var cell := Vector2i.ZERO
var hp := 1
var max_hp := 1
var always_bar := true
var cooldown := 0.0
var _stats: Dictionary = {}
var staff: Node2D = null

func has_staff() -> bool:
	return staff != null and is_instance_valid(staff) and not bool(staff.get("infected")) and not bool(staff.get("leaving"))

func is_functional() -> bool:
	return kind != Kind.WALL

func setup(p_kind: Kind, p_cell: Vector2i) -> void:
	kind = p_kind
	cell = p_cell
	_stats = STATS[kind]
	max_hp = int(_stats.hp)
	hp = max_hp
	var tex: Texture2D = load(_stats.tex)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = SPRITE_OFF
	sprite.z_as_relative = true
	sprite.z_index = 0
	add_child(sprite)
	if kind == Kind.FIRE:
		var flame := Flame.new()
		flame.position = Vector2(8, -78)
		flame.z_as_relative = true
		flame.z_index = 0
		add_child(flame)
	var bar := HpBar.new()
	bar.z_as_relative = true
	bar.z_index = 0
	bar.y_off = -148.0
	add_child(bar)
	add_to_group("iso")

func iso_points() -> PackedVector2Array:
	var sprite := _art()
	if sprite:
		return IsoSort.front_edge(sprite)
	return IsoSort.footprint(global_position)

func iso_rect() -> Rect2:
	var sprite := _art()
	if sprite:
		return IsoSort.front_rect(sprite)
	return Rect2(global_position, Vector2.ZERO)

func _art() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null

func is_defense() -> bool:
	return bool(_stats.defense)

func _process(delta: float) -> void:
	queue_redraw()
	if float(_stats.range) <= 0.0 or not has_staff():
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := _acquire()
	if target == null:
		return
	cooldown = float(_stats.cd)
	_shoot(target)

func _acquire() -> Zombie:
	var best: Zombie = null
	var best_core := INF
	var game := _game()
	if game == null:
		return null
	var reach := float(_stats.range)
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.dying:
			continue
		if global_position.distance_to(z.global_position) > reach:
			continue
		var core_d := z.global_position.distance_to(game.core_pos)
		if core_d < best_core:
			best_core = core_d
			best = z
	return best

func _shoot(target: Zombie) -> void:
	var shot := Projectile.new()
	var aim := target.global_position + target.step_hint * 0.12
	var bonus := 1.0
	var game := _game()
	if game:
		bonus = float(game.tower_bonus())
	var damage := maxi(int(round(float(_stats.dmg) * bonus)), 1)
	shot.setup(global_position + Vector2(0, -70), aim, target, damage, float(_stats.splash), float(_stats.shot_speed), kind == Kind.FIRE)
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
	var pts := PackedVector2Array()
	var rad := 34.0 if is_defense() else 40.0
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * rad, sin(a) * rad * 0.42 + 10.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
	if is_functional():
		var dot := Color(0.4, 0.85, 0.45) if has_staff() else Color(0.85, 0.35, 0.3)
		draw_circle(Vector2(0, -150), 6, dot)
	if float(_stats.range) > 0.0 and _game() and _game().inspected == self:
		draw_arc(Vector2.ZERO, float(_stats.range), 0, TAU, 48, Color(1, 0.86, 0.35, 0.55), 2.0)


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
