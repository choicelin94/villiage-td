class_name IsoVolume
extends RefCounted

# Ground contact in square tile space, plus a height. Depth never reads sprite
# pixels. The map is orthographic top-down: +X is east, +Y is south. Cell
# (0, 0) sits at (HALF, HALF) on a stacked square TileMapLayer.
#
# Authoring (data/iso_volumes.json), one entry per kind:
#   shape "ellipse" — rx, ry, optional ox/oy from the cell center (or the feet).
#   shape "poly" — poly is a list of [x, y] offsets around that same origin.
#   z — height of the prism. The solver compares these shapes; it does not
#   assume one shared rectangle. Walkers are an ellipse with area, never a point.
# Every polygon is convex. A hollow prop (farm frame, wall gap) is authored as
# one solid convex cover, so walkers lose the interior instead of standing in it.
# Draw the ground contact (trunk, wall base, stance), not the roof or canopy.

const TILE := 128.0
const HALF := 64.0
# One old isometric step was hypot(88, 49). Speeds and ranges scale with the
# new square so a walker still crosses one tile in the same time.
const WORLD_SCALE := 1.2708197158225134
const TREE_ANCHOR := Vector2(-127.5, -157.0)
const ROCK_ANCHOR := Vector2(-129.5, -196.0)

enum Shape { ELLIPSE, POLY }

const TABLE := {
	"house": {
		"shape": "poly", "z": 2.2,
		"poly": [[-0.40, 0.48], [0.46, 0.48], [0.46, 0.06], [0.08, -0.18], [-0.40, 0.06]],
	},
	"farm": {
		"shape": "poly", "z": 0.85,
		"poly": [[-0.49, -0.43], [0.49, -0.43], [0.49, 0.50], [-0.49, 0.50]],
	},
	"workshop": {
		"shape": "poly", "z": 1.8,
		"poly": [[-0.22, 0.48], [0.22, 0.48], [0.22, -0.02], [-0.22, -0.02]],
	},
	"wall": {
		"shape": "poly", "z": 1.15,
		"poly": [[-0.49, -0.36], [0.49, -0.36], [0.49, 0.50], [-0.49, 0.50]],
	},
	"spear": {
		"shape": "poly", "z": 1.65,
		"poly": [[-0.34, 0.46], [0.34, 0.46], [0.22, 0.08], [-0.22, 0.08]],
	},
	"fire": {"shape": "ellipse", "ox": 0.0, "oy": 0.18, "rx": 0.20, "ry": 0.14, "z": 1.25},
	"tree": {"shape": "ellipse", "ox": 0.0, "oy": -0.06, "rx": 0.14, "ry": 0.06, "z": 2.35},
	"rock": {"shape": "ellipse", "ox": 0.06, "oy": -0.08, "rx": 0.24, "ry": 0.12, "z": 0.7},
	"walker": {"shape": "ellipse", "rx": 0.16, "ry": 0.145, "z": 1.05},
}

var shape := Shape.ELLIPSE
var center := Vector2.ZERO
var radius := Vector2.ZERO
var min_x := 0.0
var max_x := 0.0
var min_y := 0.0
var max_y := 0.0
var min_z := 0.0
var max_z := 1.0
var ground_poly_iso: PackedVector2Array = PackedVector2Array()
var sort_origin := Vector3.ZERO
var screen_rect := Rect2()
var node: Node2D

static var _table: Dictionary = {}

static func spec_for(key: String) -> Dictionary:
	_ensure()
	if _table.has(key):
		return _table[key]
	return TABLE[key]

static func _ensure() -> void:
	if not _table.is_empty():
		return
	var path := "res://data/iso_volumes.json"
	if not FileAccess.file_exists(path):
		_table = TABLE.duplicate(true)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_table = parsed
	else:
		_table = TABLE.duplicate(true)

static func world_to_iso(world: Vector2) -> Vector2:
	return Vector2((world.x - HALF) / TILE, (world.y - HALF) / TILE)

static func iso_to_world(iso: Vector2) -> Vector2:
	return Vector2(HALF + iso.x * TILE, HALF + iso.y * TILE)

static func walker_support(dir: Vector2) -> float:
	var spec: Dictionary = spec_for("walker")
	return _ellipse_support(Vector2(float(spec.rx), float(spec.ry)), dir)

static func from_cell(cell: Vector2i, key: String) -> IsoVolume:
	return _from_spec(Vector2(float(cell.x), float(cell.y)), spec_for(key))

static func from_feet(world: Vector2) -> IsoVolume:
	return _from_spec(world_to_iso(world), spec_for("walker"))

static func _from_spec(origin: Vector2, spec: Dictionary) -> IsoVolume:
	var vol := IsoVolume.new()
	vol.min_z = float(spec.get("min_z", 0.0))
	vol.max_z = float(spec.z)
	var ox := float(spec.get("ox", 0.0))
	var oy := float(spec.get("oy", 0.0))
	vol.center = origin + Vector2(ox, oy)
	var shape_name := str(spec.get("shape", "poly"))
	if shape_name == "ellipse":
		vol.shape = Shape.ELLIPSE
		vol.radius = Vector2(float(spec.rx), float(spec.ry))
		vol.ground_poly_iso = _ellipse_poly(vol.center, vol.radius, 20)
	else:
		vol.shape = Shape.POLY
		var pts := PackedVector2Array()
		if spec.has("poly"):
			for item in spec.poly:
				pts.append(vol.center + Vector2(float(item[0]), float(item[1])))
		else:
			var hw := float(spec.w) * 0.5
			var hh := float(spec.h) * 0.5
			pts = PackedVector2Array([
				vol.center + Vector2(-hw, -hh),
				vol.center + Vector2(hw, -hh),
				vol.center + Vector2(hw, hh),
				vol.center + Vector2(-hw, hh),
			])
		vol.ground_poly_iso = pts
		if not poly_convex(pts):
			push_error("Footprint is concave: %s" % str(spec.get("poly", [])))
	vol._apply_bounds()
	return vol

static func _ellipse_poly(at: Vector2, rad: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(at + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return pts

static func _ellipse_support(rad: Vector2, dir: Vector2) -> float:
	if dir.length_squared() < 0.000001:
		return 0.0
	var d := dir.normalized()
	return sqrt(rad.x * rad.x * d.x * d.x + rad.y * rad.y * d.y * d.y)

static func poly_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var sign := 0
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var c: Vector2 = poly[(i + 2) % n]
		var cross := (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
		if absf(cross) <= 0.0000001:
			continue
		var s := 1 if cross > 0.0 else -1
		if sign == 0:
			sign = s
		elif s != sign:
			return false
	return sign != 0

static func spec_convex(spec: Dictionary) -> bool:
	if str(spec.get("shape", "poly")) == "ellipse":
		return float(spec.get("rx", 0.0)) > 0.0 and float(spec.get("ry", 0.0)) > 0.0
	if not spec.has("poly"):
		return false
	var pts := PackedVector2Array()
	for item in spec.poly:
		pts.append(Vector2(float(item[0]), float(item[1])))
	return poly_convex(pts)

# Center distance, in iso units, at which two walker ovals just touch along dir.
static func walker_separation(dir: Vector2) -> float:
	return walker_support(dir) * 2.0

static func support_point(vol: IsoVolume, dir: Vector2) -> Vector2:
	if vol.shape == Shape.ELLIPSE:
		var denom := sqrt(vol.radius.x * vol.radius.x * dir.x * dir.x + vol.radius.y * vol.radius.y * dir.y * dir.y)
		if denom < 0.000000000001:
			return vol.center
		return vol.center + Vector2(vol.radius.x * vol.radius.x * dir.x / denom, vol.radius.y * vol.radius.y * dir.y / denom)
	if vol.ground_poly_iso.is_empty():
		return vol.center
	var best: Vector2 = vol.ground_poly_iso[0]
	var best_d := best.dot(dir)
	for p in vol.ground_poly_iso:
		var dd := p.dot(dir)
		if dd > best_d:
			best = p
			best_d = dd
	return best

# True only when the ground shapes penetrate. A shared boundary is not an overlap.
func overlaps(other: IsoVolume) -> bool:
	if other == null:
		return false
	if max_x < other.min_x or other.max_x < min_x or max_y < other.min_y or other.max_y < min_y:
		return false
	return _gjk_hit(self, other)

static func _gjk_hit(a: IsoVolume, b: IsoVolume) -> bool:
	var dir := a.center - b.center
	if dir.length_squared() < 0.00000000000001:
		dir = Vector2.RIGHT
	var pts: Array[Vector2] = [_mink(a, b, dir)]
	dir = -pts[0]
	for _step in 16:
		var newest := _mink(a, b, dir)
		if newest.dot(dir) <= 0.0000001:
			return false
		pts.append(newest)
		if pts.size() == 2:
			var ao2 := -pts[1]
			var ab2 := pts[0] - pts[1]
			if ab2.dot(ao2) > 0.0:
				var perp := Vector2(-ab2.y, ab2.x)
				if perp.dot(ao2) < 0.0:
					perp = -perp
				dir = perp
			else:
				pts.remove_at(0)
				dir = ao2
			continue
		var a0: Vector2 = pts[2]
		var b0: Vector2 = pts[1]
		var c0: Vector2 = pts[0]
		var ao := -a0
		var ab := b0 - a0
		var ac := c0 - a0
		var ab_perp := Vector2(-ab.y, ab.x)
		if ab_perp.dot(ac) > 0.0:
			ab_perp = -ab_perp
		var ac_perp := Vector2(-ac.y, ac.x)
		if ac_perp.dot(ab) > 0.0:
			ac_perp = -ac_perp
		if ab_perp.dot(ao) > 0.0:
			pts.remove_at(0)
			dir = ab_perp
		elif ac_perp.dot(ao) > 0.0:
			pts.remove_at(1)
			dir = ac_perp
		else:
			# The origin is inside this simplex, so it is inside the Minkowski
			# difference. A true touch never gets here: the support test stops
			# when the origin is only on the boundary of the shapes.
			return true
	return true

static func _mink(a: IsoVolume, b: IsoVolume, dir: Vector2) -> Vector2:
	return support_point(a, dir) - support_point(b, -dir)

static func sprite_rect(sprite: CanvasItem) -> Rect2:
	if sprite == null:
		return Rect2()
	var local := Rect2()
	if sprite is Sprite2D:
		local = (sprite as Sprite2D).get_rect()
	else:
		return Rect2()
	var xf := sprite.get_global_transform()
	var corners: Array[Vector2] = [
		local.position,
		local.position + Vector2(local.size.x, 0.0),
		local.position + Vector2(0.0, local.size.y),
		local.position + local.size,
	]
	var mn := xf * corners[0]
	var mx := mn
	for corner in corners:
		var g: Vector2 = xf * corner
		mn.x = minf(mn.x, g.x)
		mn.y = minf(mn.y, g.y)
		mx.x = maxf(mx.x, g.x)
		mx.y = maxf(mx.y, g.y)
	return Rect2(mn, mx - mn)

func bounds_center() -> Vector2:
	return Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

func reach(dir: Vector2) -> float:
	if dir.length_squared() < 0.000001:
		return 0.0
	var d := dir.normalized()
	if shape == Shape.ELLIPSE:
		return _ellipse_support(radius, d)
	var origin := bounds_center()
	var best := 0.0
	for p in ground_poly_iso:
		best = maxf(best, (p - origin).dot(d))
	return best

func shifted(delta: Vector2) -> IsoVolume:
	var copy := IsoVolume.new()
	copy.shape = shape
	copy.center = center + delta
	copy.radius = radius
	copy.min_z = min_z
	copy.max_z = max_z
	var moved := PackedVector2Array()
	for p in ground_poly_iso:
		moved.append(p + delta)
	copy.ground_poly_iso = moved
	copy._apply_bounds()
	return copy

func south_rim_on(x0: float, x1: float) -> float:
	if shape == Shape.ELLIPSE:
		var lo := maxf(x0, center.x - radius.x)
		var hi := minf(x1, center.x + radius.x)
		if hi < lo:
			return max_y
		var x := clampf(center.x, lo, hi)
		var dx := 0.0
		if radius.x > 0.00001:
			dx = (x - center.x) / radius.x
		var half := radius.y * sqrt(maxf(0.0, 1.0 - dx * dx))
		return center.y + half
	var clipped := _clip_poly_x(ground_poly_iso, x0, x1)
	if clipped.is_empty():
		return max_y
	var best := -1.0e20
	for p in clipped:
		best = maxf(best, p.y)
	return best

func depth_key() -> float:
	return sort_origin.x + sort_origin.y + sort_origin.z * 0.01

func _apply_bounds() -> void:
	if shape == Shape.ELLIPSE:
		min_x = center.x - radius.x
		max_x = center.x + radius.x
		min_y = center.y - radius.y
		max_y = center.y + radius.y
	else:
		if ground_poly_iso.is_empty():
			min_x = center.x
			max_x = center.x
			min_y = center.y
			max_y = center.y
		else:
			min_x = ground_poly_iso[0].x
			max_x = min_x
			min_y = ground_poly_iso[0].y
			max_y = min_y
			for p in ground_poly_iso:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
	# Tie-break uses the south rim, not a single foot point.
	sort_origin = Vector3(center.x, max_y, min_z)

static func _clip_poly_x(poly: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	return _clip_half(_clip_half(poly, x0, true), x1, false)

static func _clip_half(poly: PackedVector2Array, bound: float, keep_above: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	if n < 3:
		return out
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var a_in := a.x >= bound if keep_above else a.x <= bound
		var b_in := b.x >= bound if keep_above else b.x <= bound
		if a_in and b_in:
			out.append(b)
		elif a_in and not b_in:
			out.append(_hit_x(a, b, bound))
		elif not a_in and b_in:
			out.append(_hit_x(a, b, bound))
			out.append(b)
	return out

static func _hit_x(a: Vector2, b: Vector2, bound: float) -> Vector2:
	var dx := b.x - a.x
	var t := 0.0 if absf(dx) < 0.000001 else (bound - a.x) / dx
	t = clampf(t, 0.0, 1.0)
	return a.lerp(b, t)
