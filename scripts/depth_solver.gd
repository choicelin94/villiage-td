class_name DepthSolver
extends RefCounted

# Mazebert-style iso AABB: A is behind B when A's box is entirely on the
# far side of B along at least one iso axis. Screen rects only reject pairs
# that cannot overlap. Marks are not volumes; they inherit the parent rank.

const PAD := 8.0

static func is_behind(a: IsoVolume, b: IsoVolume) -> bool:
	return a.max_x <= b.min_x or a.max_y <= b.min_y or a.max_z <= b.min_z

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
