class_name IsoSort
extends RefCounted

# One sorter for every standing thing.
# Buildings, trees, and rocks all use the southern contour of their own
# sprite (front_edge). Walkers are horizontal slices of one body; each
# slice is a point at that band's bottom, so the chest can pass behind a
# trunk while the legs stay in front. Overlapping pieces become a graph
# and a topological draw order.
# Marks that trace a front edge are children of that object, so they share
# its depth. Ground highlights live under every standing rank.

const HALF_W := 88.0
const HALF_H := 49.0
const TIE := 2.0
const _SAMPLE := 4

static var _edge_cache: Dictionary = {}

static func footprint(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-HALF_W, 0.0),
		center + Vector2(0.0, HALF_H),
		center + Vector2(HALF_W, 0.0),
	])

static func sprite_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var local := sprite.get_rect()
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

# Local southern contour of a sprite, cached per texture. Same routine for
# every building, tree, and rock.
static func front_edge(sprite: Sprite2D) -> PackedVector2Array:
	var local := _local_edge(sprite)
	var out := PackedVector2Array()
	if sprite == null:
		return out
	var xf := sprite.get_global_transform()
	for p in local:
		out.append(xf * p)
	return out

static func front_rect(sprite: Sprite2D) -> Rect2:
	var local: Rect2 = _local_rect(sprite)
	if sprite == null:
		return Rect2()
	return _xform_rect(sprite.get_global_transform(), local)

static func y_at(pts: PackedVector2Array, x: float) -> float:
	return _y_at(pts, x)

# Positive when A is closer to the camera than B (A draws later).
# A point standing on a front edge is still behind that edge.
# Two points do not constrain each other. Bands of people overlap, and a
# point-vs-point edge cycles with a front edge. Their order is the baseline
# used to break ties.
static func compare_points(a: PackedVector2Array, b: PackedVector2Array) -> int:
	if a.is_empty() or b.is_empty():
		return 0
	if a.size() <= 1 and b.size() <= 1:
		return 0
	if a.size() <= 1:
		return _cmp_actor(a[0], b)
	if b.size() <= 1:
		return -_cmp_actor(b[0], a)
	return _cmp_lines(a, b)

static func apply(entries: Array) -> void:
	var n := entries.size()
	if n == 0:
		return
	var next: Array = []
	var indeg := PackedInt32Array()
	indeg.resize(n)
	for i in n:
		next.append([])
	for i in n:
		var ai: Dictionary = entries[i]
		var a_pts: PackedVector2Array = ai.points
		var a_rect: Rect2 = ai.rect
		for j in range(i + 1, n):
			var bj: Dictionary = entries[j]
			if not a_rect.grow(8.0).intersects((bj.rect as Rect2).grow(8.0)):
				continue
			var cmp := compare_points(a_pts, bj.points)
			if cmp > 0:
				var behind: Array = next[j]
				behind.append(i)
				next[j] = behind
				indeg[i] += 1
			elif cmp < 0:
				var ahead: Array = next[i]
				ahead.append(j)
				next[i] = ahead
				indeg[j] += 1
	var ready: Array = []
	for i in n:
		if indeg[i] == 0:
			ready.append(i)
	var ordered: Array[int] = []
	var seen := {}
	while not ready.is_empty():
		ready.sort_custom(func(a, b) -> bool:
			var fa := _front_y(entries[a].points)
			var fb := _front_y(entries[b].points)
			if absf(fa - fb) > 0.01:
				return fa < fb
			return int(a) < int(b)
		)
		var current: int = ready.pop_front()
		if seen.has(current):
			continue
		seen[current] = true
		ordered.append(current)
		for nxt in next[current]:
			var k := int(nxt)
			indeg[k] -= 1
			if indeg[k] == 0:
				ready.append(k)
	if ordered.size() < n:
		var rest: Array = []
		for i in n:
			if not seen.has(i):
				rest.append(i)
		rest.sort_custom(func(a, b) -> bool:
			return _front_y(entries[a].points) < _front_y(entries[b].points)
		)
		for item in rest:
			ordered.append(int(item))
	for rank in ordered.size():
		var node: Node2D = entries[ordered[rank]].node
		if is_instance_valid(node):
			node.z_as_relative = false
			node.z_index = rank
			if node.has_method("sync_root"):
				node.sync_root()

static func _cmp_actor(point: Vector2, line: PackedVector2Array) -> int:
	if point.y > _y_at(line, point.x) + TIE:
		return 1
	return -1

static func _local_edge(sprite: Sprite2D) -> PackedVector2Array:
	var found: Dictionary = _scan(sprite)
	return found.edge as PackedVector2Array

static func _local_rect(sprite: Sprite2D) -> Rect2:
	var found: Dictionary = _scan(sprite)
	return found.rect

static func _scan(sprite: Sprite2D) -> Dictionary:
	var empty := {
		"edge": PackedVector2Array([Vector2.ZERO, Vector2(8, 0)]),
		"rect": Rect2(),
	}
	if sprite == null or sprite.texture == null:
		return empty
	var key := str(sprite.texture.get_rid())
	if _edge_cache.has(key):
		return _edge_cache[key]
	var img := sprite.texture.get_image()
	if img == null:
		_edge_cache[key] = empty
		return empty
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	var cols: Array = []
	cols.resize(w)
	for x in w:
		cols[x] = -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.15:
				continue
			if int(cols[x]) < y:
				cols[x] = y
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	var edge := PackedVector2Array()
	if max_x < 0:
		_edge_cache[key] = empty
		return empty
	var x := min_x
	while x <= max_x:
		var south := int(cols[x])
		var best := south
		var end := mini(x + _SAMPLE - 1, max_x)
		for k in range(x, end + 1):
			best = maxi(best, int(cols[k]))
		if best >= 0:
			edge.append(Vector2(x, best))
		x += _SAMPLE
	if edge.size() == 1:
		edge.append(edge[0] + Vector2(4, 0))
	var packed := {
		"edge": edge,
		"rect": Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
	}
	_edge_cache[key] = packed
	return packed

static func _xform_rect(xf: Transform2D, rec: Rect2) -> Rect2:
	var corners: Array[Vector2] = [
		rec.position,
		rec.position + Vector2(rec.size.x, 0.0),
		rec.position + Vector2(0.0, rec.size.y),
		rec.position + rec.size,
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

static func _cmp_y(a: float, b: float) -> int:
	if absf(a - b) <= TIE:
		return 0
	return 1 if a > b else -1

static func _front_y(pts: PackedVector2Array) -> float:
	var y := -1.0e9
	for p in pts:
		y = maxf(y, p.y)
	return y

static func _span_x(pts: PackedVector2Array) -> Vector2:
	var lo := pts[0].x
	var hi := pts[0].x
	for p in pts:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return Vector2(lo, hi)

static func _y_at(pts: PackedVector2Array, x: float) -> float:
	if pts.size() == 1:
		return pts[0].y
	for i in pts.size() - 1:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1]
		var lo := minf(p.x, q.x)
		var hi := maxf(p.x, q.x)
		if x < lo - 0.01 or x > hi + 0.01:
			continue
		if absf(q.x - p.x) < 0.001:
			return maxf(p.y, q.y)
		var t := clampf((x - p.x) / (q.x - p.x), 0.0, 1.0)
		return p.y + (q.y - p.y) * t
	var best: Vector2 = pts[0]
	var best_d := absf(pts[0].x - x)
	for p in pts:
		var d := absf(p.x - x)
		if d < best_d:
			best = p
			best_d = d
	return best.y

static func _cmp_lines(a: PackedVector2Array, b: PackedVector2Array) -> int:
	var sa := _span_x(a)
	var sb := _span_x(b)
	var lo := maxf(sa.x, sb.x)
	var hi := minf(sa.y, sb.y)
	if hi < lo:
		return _cmp_y(_front_y(a), _front_y(b))
	var acc := 0.0
	for s in 3:
		var x := lo + (hi - lo) * float(s) * 0.5
		acc += _y_at(a, x) - _y_at(b, x)
	return _cmp_y(acc, 0.0)
