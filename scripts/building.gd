class_name Building
extends Node2D

enum Kind { WALL, SPEAR, FIRE }

const STATS := {
	Kind.WALL: {
		"hp": 170, "wood": 12, "gold": 0,
		"range": 0.0, "dmg": 0, "cd": 0.0, "splash": 0.0, "shot_speed": 0.0,
		"tex": "res://assets/kenney/buildings/wall.png",
	},
	Kind.SPEAR: {
		"hp": 100, "wood": 32, "gold": 48,
		"range": 220.0, "dmg": 17, "cd": 0.68, "splash": 0.0, "shot_speed": 520.0,
		"tex": "res://assets/kenney/buildings/spear.png",
	},
	Kind.FIRE: {
		"hp": 90, "wood": 22, "gold": 72,
		"range": 185.0, "dmg": 13, "cd": 1.15, "splash": 88.0, "shot_speed": 280.0,
		"tex": "res://assets/kenney/buildings/fire.png",
	},
}

var kind: Kind = Kind.WALL
var cell := Vector2i.ZERO
var hp := 1
var max_hp := 1
var always_bar := true
var cooldown := 0.0
var _stats: Dictionary = {}

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
	sprite.position = Vector2(-tex.get_width() * 0.5, 33.0 - tex.get_height())
	sprite.z_index = 1
	add_child(sprite)
	if kind == Kind.FIRE:
		var flame := Flame.new()
		flame.position = sprite.position + Vector2(tex.get_width() * 0.5, 14)
		flame.z_index = 2
		add_child(flame)
	var bar := HpBar.new()
	bar.z_index = 3
	bar.y_off = sprite.position.y - 8.0
	add_child(bar)

func _process(delta: float) -> void:
	queue_redraw()
	if kind == Kind.WALL:
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
	shot.setup(global_position + Vector2(0, -28), aim, target, int(_stats.dmg), float(_stats.splash), float(_stats.shot_speed), kind == Kind.FIRE)
	_game().fx.add_child(shot)

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
	var rad := 16.0 if kind == Kind.WALL else 20.0
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * rad, sin(a) * rad * 0.42 + 8.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
	if kind != Kind.WALL and _game() and _game().inspected == self:
		draw_arc(Vector2.ZERO, float(_stats.range), 0, TAU, 48, Color(1, 0.86, 0.35, 0.55), 2.0)


class Flame:
	extends Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var flick := 0.8 + 0.25 * sin(Time.get_ticks_msec() / 70.0)
		draw_circle(Vector2(0, 2), 8.0 * flick, Color(1, 0.38, 0.05, 0.75))
		draw_circle(Vector2(0, -6.0 * flick), 4.5, Color(1, 0.9, 0.4, 0.95))


class HpBar:
	extends Node2D

	var y_off := -70.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := get_parent()
		if p.hp >= p.max_hp and not p.always_bar:
			return
		var w := 40.0
		var ratio := clampf(float(p.hp) / float(maxi(p.max_hp, 1)), 0.0, 1.0)
		var col := Color(0.35, 0.78, 0.32) if ratio > 0.35 else Color(0.85, 0.28, 0.18)
		draw_rect(Rect2(-w * 0.5, y_off, w, 5), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, y_off, w * ratio, 5), col)
