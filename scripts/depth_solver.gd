class_name DepthSolver
extends RefCounted

# One compare for every footprint. On a top-down map the camera sits to the
# south, so depth is the south rim of the real ground shape (ellipse or
# polygon) plus height. Where the east-west spans miss, the shapes are side
# by side and only a fully northern footprint is behind. A point has no south
# rim of its own; callers that still need that old test use point_behind.
# Screen rects only reject pairs that cannot overlap. Marks inherit the parent rank.
#
# apply() is a two-phase sort. The broad phase copies each volume's tight
# iso AABB (already derived from the ellipse or polygon plus height) into
# reused buffers, then sweep-and-prune on screen rects drops pairs the old
# solver would skip. Pairs whose boxes separate in x, y, or z get the same
# answer is_behind would, without walking the outline. Only a real overlap
# runs that south-rim test. Static props keep the pair result until one of
# them moves. apply_reference() is the previous all-pairs sort, used to time
# the old path on the stress page.

const PAD := 8.0
const MISS := 2

static var last_sort_usec := 0
static var last_reference_usec := 0
static var last_candidates := 0
static var last_narrow := 0
static var last_broad := 0
static var last_hits := 0

static var _batch: Array = []
static var _empty: Array = []
static var _min_x: Array = []
static var _min_y: Array = []
static var _min_z: Array = []
static var _max_x: Array = []
static var _max_y: Array = []
static var _max_z: Array = []
static var _sx0: Array = []
static var _sy0: Array = []
static var _sx1: Array = []
static var _sy1: Array = []
static var _idx: PackedInt32Array = PackedInt32Array()
static var _indeg: PackedInt32Array = PackedInt32Array()
static var _active: PackedInt32Array = PackedInt32Array()
static var _next: Array = []
static var _ids: PackedInt64Array = PackedInt64Array()
static var _dirty: PackedByteArray = PackedByteArray()
static var _sig: PackedFloat64Array = PackedFloat64Array()
static var _filled: PackedByteArray = PackedByteArray()
static var _was_clean: PackedByteArray = PackedByteArray()
static var _slot_of: Dictionary = {}
static var _slot_count := 0
static var _cache: Dictionary = {}
static var _live: Dictionary = {}
static var _cached_any := false

const _SIG := 10

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
	var t0 := Time.get_ticks_usec()
	var ordered := _order_two(volumes)
	_commit(volumes, ordered)
	last_sort_usec = Time.get_ticks_usec() - t0

static func apply_reference(volumes: Array) -> void:
	var t0 := Time.get_ticks_usec()
	var ordered := _order_reference(volumes)
	_commit(volumes, ordered)
	last_reference_usec = Time.get_ticks_usec() - t0

static func order_two_phase(volumes: Array) -> Array:
	return _order_two(volumes)

static func order_reference(volumes: Array) -> Array:
	return _order_reference(volumes)

# Pairs the screen test keeps. Returns how many of those disagree with is_behind.
static func shortcut_mismatches(volumes: Array) -> int:
	var n := volumes.size()
	if n == 0:
		return 0
	_load_geom(volumes)
	var bad := 0
	var pad2 := PAD * 2.0
	for i in n:
		for j in range(i + 1, n):
			if not _screen_near(i, j, pad2):
				continue
			var got := _resolve(i, j)
			var expect := _reference_rel(volumes[i], volumes[j])
			if got != expect:
				bad += 1
	_batch = _empty
	return bad

static func _order_reference(volumes: Array) -> Array:
	var n := volumes.size()
	if n == 0:
		return []
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
	var ordered: Array = []
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
	return ordered

static func _order_two(volumes: Array) -> Array:
	var n := volumes.size()
	last_candidates = 0
	last_narrow = 0
	last_broad = 0
	last_hits = 0
	if n == 0:
		return []
	_load_geom(volumes)
	_live.clear()
	for i in n:
		var id := _ids[i]
		if id != 0:
			_live[id] = true
		var dirty := true
		var slot := -1
		if id != 0:
			slot = _slot(id)
			dirty = _touch_sig(slot, i)
			if _was_clean[slot] == 1 and dirty:
				_wipe(id)
			_was_clean[slot] = 0 if dirty else 1
		_dirty[i] = 1 if dirty else 0
		_indeg[i] = 0
		(_next[i] as Array).clear()
		_idx[i] = i
	_heap_sort(n)
	var active_n := 0
	var pad2 := PAD * 2.0
	for k in n:
		var i := _idx[k]
		var window: float = _sx0[i]
		var w := 0
		for r in active_n:
			var j := _active[r]
			if float(_sx1[j]) + pad2 <= window:
				continue
			_active[w] = j
			w += 1
			if _screen_near(i, j, pad2):
				_link(i, j)
		_active[w] = i
		active_n = w + 1
	for i in n:
		(_next[i] as Array).sort()
	var ordered := _topo(volumes, n)
	_prune()
	_batch = _empty
	return ordered

static func _load_geom(volumes: Array) -> void:
	var n := volumes.size()
	_fit(n)
	_batch = volumes
	for i in n:
		var vol: IsoVolume = volumes[i]
		_min_x[i] = vol.min_x
		_min_y[i] = vol.min_y
		_min_z[i] = vol.min_z
		_max_x[i] = vol.max_x
		_max_y[i] = vol.max_y
		_max_z[i] = vol.max_z
		var rect := vol.screen_rect
		var pos := rect.position
		var end := pos + rect.size
		_sx0[i] = pos.x
		_sy0[i] = pos.y
		_sx1[i] = end.x
		_sy1[i] = end.y
		var id := 0
		if is_instance_valid(vol.node):
			id = vol.node.get_instance_id()
		_ids[i] = id

static func _fit(n: int) -> void:
	if _min_x.size() >= n and _next.size() >= n:
		return
	var cap := maxi(n, 64)
	if _min_x.size() > 0:
		cap = maxi(n, _min_x.size() * 2)
	_min_x.resize(cap)
	_min_y.resize(cap)
	_min_z.resize(cap)
	_max_x.resize(cap)
	_max_y.resize(cap)
	_max_z.resize(cap)
	_sx0.resize(cap)
	_sy0.resize(cap)
	_sx1.resize(cap)
	_sy1.resize(cap)
	_idx.resize(cap)
	_indeg.resize(cap)
	_active.resize(cap)
	_ids.resize(cap)
	_dirty.resize(cap)
	while _next.size() < cap:
		_next.append([])

static func _screen_near(i: int, j: int, pad2: float) -> bool:
	if float(_sx0[i]) >= float(_sx1[j]) + pad2:
		return false
	if float(_sx0[j]) >= float(_sx1[i]) + pad2:
		return false
	if float(_sy0[i]) >= float(_sy1[j]) + pad2:
		return false
	if float(_sy0[j]) >= float(_sy1[i]) + pad2:
		return false
	return true

static func _link(i: int, j: int) -> void:
	var rel := _relation(i, j)
	if rel < 0:
		(_next[i] as Array).append(j)
		_indeg[j] += 1
	elif rel > 0:
		(_next[j] as Array).append(i)
		_indeg[i] += 1

static func _relation(i: int, j: int) -> int:
	last_candidates += 1
	var idi := _ids[i]
	var idj := _ids[j]
	if _dirty[i] == 0 and _dirty[j] == 0 and idi != 0 and idj != 0:
		var hit := _cache_get(idi, idj)
		if hit != MISS:
			last_hits += 1
			return hit
		var rel := _resolve(i, j)
		_cache_put(idi, idj, rel)
		return rel
	return _resolve(i, j)

static func _resolve(i: int, j: int) -> int:
	var az: bool = float(_max_z[i]) <= float(_min_z[j])
	var bz: bool = float(_max_z[j]) <= float(_min_z[i])
	if az or bz:
		last_broad += 1
		if az and not bz:
			return -1
		if bz and not az:
			return 1
		return _tie(i, j)
	var x_lo := maxf(float(_min_x[i]), float(_min_x[j]))
	var x_hi := minf(float(_max_x[i]), float(_max_x[j]))
	if x_hi < x_lo:
		last_broad += 1
		var a_north: bool = float(_max_y[i]) <= float(_min_y[j])
		var b_north: bool = float(_max_y[j]) <= float(_min_y[i])
		if a_north and not b_north:
			return -1
		if b_north and not a_north:
			return 1
		return _tie(i, j)
	if float(_max_y[i]) < float(_min_y[j]) - 0.0001:
		last_broad += 1
		return -1
	if float(_max_y[j]) < float(_min_y[i]) - 0.0001:
		last_broad += 1
		return 1
	last_narrow += 1
	var a: IsoVolume = _batch[i]
	var b: IsoVolume = _batch[j]
	var a_behind := is_behind(a, b)
	var b_behind := is_behind(b, a)
	if a_behind and not b_behind:
		return -1
	if b_behind and not a_behind:
		return 1
	return _tie(i, j)

static func _tie(i: int, j: int) -> int:
	var a: IsoVolume = _batch[i]
	var b: IsoVolume = _batch[j]
	var ka := a.depth_key()
	var kb := b.depth_key()
	if ka < kb - 0.0001:
		return -1
	if kb < ka - 0.0001:
		return 1
	return 0

static func _reference_rel(a: IsoVolume, b: IsoVolume) -> int:
	var a_behind := is_behind(a, b)
	var b_behind := is_behind(b, a)
	if a_behind and not b_behind:
		return -1
	if b_behind and not a_behind:
		return 1
	var ka := a.depth_key()
	var kb := b.depth_key()
	if ka < kb - 0.0001:
		return -1
	if kb < ka - 0.0001:
		return 1
	return 0

static func _topo(volumes: Array, n: int) -> Array:
	var ready: Array = []
	for i in n:
		if _indeg[i] == 0:
			ready.append(i)
	var ordered: Array = []
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
		for nxt in _next[current]:
			var k := int(nxt)
			_indeg[k] -= 1
			if _indeg[k] == 0:
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
	return ordered

static func _commit(volumes: Array, ordered: Array) -> void:
	for rank in ordered.size():
		var vol: IsoVolume = volumes[ordered[rank]]
		var node := vol.node
		if is_instance_valid(node):
			node.z_as_relative = false
			node.z_index = rank

static func _heap_sort(n: int) -> void:
	var start := n >> 1
	while start > 0:
		start -= 1
		_sift(start, n)
	var end := n
	while end > 1:
		end -= 1
		var tmp := _idx[0]
		_idx[0] = _idx[end]
		_idx[end] = tmp
		_sift(0, end)

static func _sift(start: int, count: int) -> void:
	var root := start
	while true:
		var child := root * 2 + 1
		if child >= count:
			return
		if child + 1 < count and _idx_less(child, child + 1):
			child += 1
		if _idx_less(root, child):
			var tmp := _idx[root]
			_idx[root] = _idx[child]
			_idx[child] = tmp
			root = child
		else:
			return

static func _idx_less(ia: int, ib: int) -> bool:
	var a := _idx[ia]
	var b := _idx[ib]
	var sa: float = _sx0[a]
	var sb: float = _sx0[b]
	if sa < sb:
		return true
	if sb < sa:
		return false
	return a < b

static func _slot(id: int) -> int:
	if _slot_of.has(id):
		return int(_slot_of[id])
	var slot := _slot_count
	_slot_count += 1
	_slot_of[id] = slot
	var need := (slot + 1) * _SIG
	if _sig.size() < need:
		_sig.resize(maxi(need, maxi(_sig.size() * 2, _SIG)))
	if _filled.size() <= slot:
		_filled.resize(maxi(slot + 1, maxi(_filled.size() * 2, 8)))
	if _was_clean.size() <= slot:
		_was_clean.resize(maxi(slot + 1, maxi(_was_clean.size() * 2, 8)))
	return slot

static func _touch_sig(slot: int, i: int) -> bool:
	var b := slot * _SIG
	var dirty := true
	if slot < _filled.size() and _filled[slot] != 0:
		dirty = (
			_sig[b] != float(_min_x[i])
			or _sig[b + 1] != float(_min_y[i])
			or _sig[b + 2] != float(_min_z[i])
			or _sig[b + 3] != float(_max_x[i])
			or _sig[b + 4] != float(_max_y[i])
			or _sig[b + 5] != float(_max_z[i])
			or _sig[b + 6] != float(_sx0[i])
			or _sig[b + 7] != float(_sy0[i])
			or _sig[b + 8] != float(_sx1[i])
			or _sig[b + 9] != float(_sy1[i])
		)
	_sig[b] = float(_min_x[i])
	_sig[b + 1] = float(_min_y[i])
	_sig[b + 2] = float(_min_z[i])
	_sig[b + 3] = float(_max_x[i])
	_sig[b + 4] = float(_max_y[i])
	_sig[b + 5] = float(_max_z[i])
	_sig[b + 6] = float(_sx0[i])
	_sig[b + 7] = float(_sy0[i])
	_sig[b + 8] = float(_sx1[i])
	_sig[b + 9] = float(_sy1[i])
	_filled[slot] = 1
	return dirty

static func _cache_get(idi: int, idj: int) -> int:
	var lo := idi if idi < idj else idj
	var hi := idi if idi > idj else idj
	if not _cache.has(lo):
		return MISS
	var inner: Dictionary = _cache[lo]
	if not inner.has(hi):
		return MISS
	var stored := int(inner[hi])
	if idi == lo:
		return stored
	return -stored

static func _cache_put(idi: int, idj: int, rel_ij: int) -> void:
	var lo := idi if idi < idj else idj
	var hi := idi if idi > idj else idj
	var stored := rel_ij if idi == lo else -rel_ij
	var inner: Dictionary
	if _cache.has(lo):
		inner = _cache[lo]
	else:
		inner = {}
		_cache[lo] = inner
	inner[hi] = stored
	_cached_any = true

static func _wipe(id: int) -> void:
	if not _cached_any:
		return
	_cache.erase(id)
	for lo in _cache.keys():
		var inner: Dictionary = _cache[lo]
		inner.erase(id)

static func _prune() -> void:
	if not _cached_any:
		return
	var drop: Array = []
	for lo in _cache.keys():
		if not _live.has(lo):
			drop.append(lo)
			continue
		var inner: Dictionary = _cache[lo]
		var drop_hi: Array = []
		for hi in inner.keys():
			if not _live.has(hi):
				drop_hi.append(hi)
		for hi in drop_hi:
			inner.erase(hi)
	for lo in drop:
		_cache.erase(lo)
