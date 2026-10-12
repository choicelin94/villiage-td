class_name DepthSolver
extends RefCounted

# One compare for every footprint. On a top-down map the camera sits to the
# south, so depth is the south rim of the real ground shape (ellipse or
# polygon) plus height. Where the east-west spans miss, the shapes are side
# by side and only a fully northern footprint is behind. A point has no south
# rim of its own; callers that still need that old test use point_behind.
# Screen rects only reject pairs that cannot overlap. Marks inherit the parent rank.

const PAD := 8.0

static func is_behind(a: IsoVolume, b: IsoVolume) -> bool:
	if a.max_z <= b.min_z:
		return true
	var x0 := maxf(a.min_x, b.min_x)
	var x1 := minf(a.max_x, b.max_x)
	if x1 < x0:
		return a.max_y <= b.min_y
	return a.south_rim_on(x0, x1) < b.south_rim_on(x0, x1) - 0.0001

# The old feet-as-a-point test: behind whenever that one sample is north of
# the other's northernmost ground point. An oval can still reach farther south.
static func point_behind(feet_iso: Vector2, other: IsoVolume) -> bool:
	return feet_iso.y <= other.min_y

static func apply(volumes: Array) -> void:
	var n := volumes.size()
	if n == 0:
		return
	var next: Array = []
	var indeg := PackedInt32Array()
	indeg.resize(n)
	for i in n:
		next.append([])
	for i in n:
		var a: IsoVolume = volumes[i]
		for j in range(i + 1, n):
			var b: IsoVolume = volumes[j]
			if not a.screen_rect.grow(PAD).intersects(b.screen_rect.grow(PAD)):
				continue
			var a_behind := is_behind(a, b)
			var b_behind := is_behind(b, a)
			if a_behind and not b_behind:
				var ahead: Array = next[i]
				ahead.append(j)
				next[i] = ahead
				indeg[j] += 1
			elif b_behind and not a_behind:
				var behind: Array = next[j]
				behind.append(i)
				next[j] = behind
				indeg[i] += 1
			else:
				var ka := a.depth_key()
				var kb := b.depth_key()
				if ka < kb - 0.0001:
					var tie_a: Array = next[i]
					tie_a.append(j)
					next[i] = tie_a
					indeg[j] += 1
				elif kb < ka - 0.0001:
					var tie_b: Array = next[j]
					tie_b.append(i)
					next[j] = tie_b
					indeg[i] += 1
	var ready: Array = []
	for i in n:
		if indeg[i] == 0:
			ready.append(i)
	var ordered: Array[int] = []
	var seen := {}
	while not ready.is_empty():
		ready.sort_custom(func(pa, pb) -> bool:
			var ka := (volumes[pa] as IsoVolume).depth_key()
			var kb := (volumes[pb] as IsoVolume).depth_key()
			if absf(ka - kb) > 0.0001:
				return ka < kb
			return int(pa) < int(pb)
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
		rest.sort_custom(func(pa, pb) -> bool:
			return (volumes[pa] as IsoVolume).depth_key() < (volumes[pb] as IsoVolume).depth_key()
		)
		for item in rest:
			ordered.append(int(item))
	for rank in ordered.size():
		var vol: IsoVolume = volumes[ordered[rank]]
		var node := vol.node
		if is_instance_valid(node):
			node.z_as_relative = false
			node.z_index = rank
