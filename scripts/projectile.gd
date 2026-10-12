class_name Projectile
extends Node2D

var velocity := Vector2.ZERO
var damage := 1
var splash := 0.0
var aim := Vector2.ZERO
var target: Node2D
var life := 2.2
var fired := false
var is_fire := false

func setup(from: Vector2, p_aim: Vector2, p_target: Node2D, p_damage: int, p_splash: float, speed: float, p_fire: bool) -> void:
	global_position = from
	aim = p_aim
	target = p_target
	damage = p_damage
	splash = p_splash
	is_fire = p_fire
	var dir := aim - from
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	velocity = dir.normalized() * speed
	rotation = velocity.angle()
	fired = true

func _process(delta: float) -> void:
	if not fired:
		return
	life -= delta
	if is_instance_valid(target) and not (target as Zombie).dying:
		aim = target.global_position
	var before := global_position
	global_position += velocity * delta
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	queue_redraw()
	if _reached(before, global_position, aim) or life <= 0.0:
		_impact()

func _reached(a: Vector2, b: Vector2, p: Vector2) -> bool:
	if b.distance_to(p) < 16.0 * IsoVolume.WORLD_SCALE or a.distance_to(p) < 16.0 * IsoVolume.WORLD_SCALE:
		return true
	var ab := b - a
	var denom := ab.length_squared()
	if denom < 0.001:
		return false
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return a.lerp(b, t).distance_to(p) < 16.0 * IsoVolume.WORLD_SCALE and t < 1.0

func _impact() -> void:
	fired = false
	var game := get_tree().get_first_node_in_group("game")
	if game:
		var alive: Node2D = target if is_instance_valid(target) else null
		game.apply_hit(global_position, damage, splash, is_fire, alive)
	queue_free()

func _draw() -> void:
	if is_fire:
		draw_circle(Vector2.ZERO, 9, Color(1, 0.42, 0.05, 0.9))
		draw_circle(Vector2(-3, 0), 4, Color(1, 0.92, 0.45, 0.95))
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(14, 0), Vector2(-8, 3.2), Vector2(-4, 0), Vector2(-8, -3.2)
		]), Color(0.48, 0.3, 0.14, 1))
		draw_colored_polygon(PackedVector2Array([
			Vector2(14, 0), Vector2(5, 2.4), Vector2(5, -2.4)
		]), Color(0.92, 0.9, 0.82, 1))
