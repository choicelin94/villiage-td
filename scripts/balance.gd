extends Node

# Loads config/balance/units.json, config/balance/enemies.json, and
# config/balance/buildings.json once. config/presentation/characters.json
# stays visual (sheets, clips, skins). It is read here only to turn a skin
# name into a sheet index. If a config file is missing, the matching
# data/*.json is used so an older checkout still loads.
# The workbench saves a layout override and a balance override. There is
# no second combat table in this script.
#
# Damage formula for every hit that spends attack against defense
# (tower shots into zombies, zombie bites into buildings):
#
#   dealt = max(1, round(attack * 100 / (100 + defense)))
#
# defense 0 leaves the attack unchanged after rounding. A workshop's
# tower_damage multiplier is applied to the attack first, then this formula
# runs once per target. Villager infection is still contact, not this formula.
# Spearman and engineer are catalogued, and they do not swing yet.

const UNITS_PATH := "res://config/balance/units.json"
const ENEMIES_PATH := "res://config/balance/enemies.json"
const BUILDINGS_PATH := "res://config/balance/buildings.json"
const CHARACTERS_PATH := "res://config/presentation/characters.json"
const SETUP_PATH := "res://config/layout/setup.json"
const UNITS_LEGACY := "res://data/units.json"
const ENEMIES_LEGACY := "res://data/enemies.json"
const BUILDINGS_LEGACY := "res://data/buildings.json"
const CHARACTERS_LEGACY := "res://data/characters.json"
const SETUP_LEGACY := "res://data/setup.json"
const USER_SETUP_PATH := "user://setup.json"
const USER_LAYOUT_PATH := "user://layout.json"
const USER_BALANCE_PATH := "user://balance.json"
const LAYOUT_KEYS: Array[String] = [
	"config_version", "difficulty_id", "presets", "settlement", "combat", "economy",
	"spawns", "spawn_rects", "starter_buildings", "starter_units", "starter_props",
]
const BALANCE_KEYS: Array[String] = [
	"config_version", "slots", "lumber", "waves", "units", "enemies", "buildings",
]
const _Plan := preload("res://scripts/map_plan.gd")

const _KIND_ALIAS := {
	"normal": "spear_normal",
	"fast": "spear_fast",
	"brute": "shooter_elite",
	"boss": "shooter_boss",
}

var _units := {}
var _enemies := {}
var _buildings := {}
var _by_kind := {}
var _unit_order: Array[String] = []
var _enemy_order: Array[String] = []
var _building_order: Array[String] = []
var _waves: Array[Dictionary] = []
var _skins := {}
var _setup := {}
var _shipped_version := 1

func _ready() -> void:
	reload()

func reload() -> void:
	_units.clear()
	_enemies.clear()
	_buildings.clear()
	_by_kind.clear()
	_unit_order.clear()
	_enemy_order.clear()
	_building_order.clear()
	_waves.clear()
	_skins.clear()
	var units_doc := _read(_cfg(UNITS_PATH, UNITS_LEGACY))
	for raw in units_doc.get("units", []):
		if raw is Dictionary:
			var def := _norm_unit(raw)
			var id := str(def.get("id", ""))
			if id == "":
				continue
			_units[id] = def
			_unit_order.append(id)
	var enemies_doc := _read(_cfg(ENEMIES_PATH, ENEMIES_LEGACY))
	for raw in enemies_doc.get("waves", []):
		if raw is Dictionary:
			_waves.append(raw)
	for raw in enemies_doc.get("enemies", []):
		if raw is Dictionary:
			var def := _norm_enemy(raw)
			var id := str(def.get("id", ""))
			if id == "":
				continue
			_enemies[id] = def
			_enemy_order.append(id)
	var buildings_doc := _read(_cfg(BUILDINGS_PATH, BUILDINGS_LEGACY))
	for raw in buildings_doc.get("buildings", []):
		if raw is Dictionary:
			var def := _norm_building(raw)
			var id := str(def.get("id", ""))
			if id == "":
				continue
			_buildings[id] = def
			_building_order.append(id)
			var kind := str(def.get("kind", ""))
			if kind != "":
				_by_kind[kind] = def
	var characters := _read(_cfg(CHARACTERS_PATH, CHARACTERS_LEGACY))
	for key in characters.keys():
		var row = characters[key]
		if row is Dictionary and row.has("skins"):
			_skins[str(key)] = row.skins
	var shipped := _read(_cfg(SETUP_PATH, SETUP_LEGACY))
	_shipped_version = maxi(int(shipped.get("config_version", 1)), 1)
	_pull_web_setup()
	_upgrade_user_setup(shipped)
	_publish_web_setup()
	_setup = _default_setup()
	_overlay_setup(shipped)
	_overlay_setup(_read_user_setup())
	_apply_setup_stats()

func damage(attack: float, defense: float) -> int:
	var armor := maxf(defense, 0.0)
	var mitigated := attack * 100.0 / (100.0 + armor)
	return maxi(int(round(mitigated)), 1)

func unit(id: String) -> Dictionary:
	return _units.get(id, {})

func unit_ids() -> Array[String]:
	return _unit_order.duplicate()

func enemy(id: String) -> Dictionary:
	if _enemies.has(id):
		return _enemies[id]
	var alias := str(_KIND_ALIAS.get(id, ""))
	if alias != "" and _enemies.has(alias):
		return _enemies[alias]
	return {}

func enemy_ids() -> Array[String]:
	return _enemy_order.duplicate()

func waves() -> Array[Dictionary]:
	return _waves

func building(id: String) -> Dictionary:
	return _buildings.get(id, {})

func building_ids() -> Array[String]:
	return _building_order.duplicate()

func building_by_kind(kind: String) -> Dictionary:
	return _by_kind.get(kind, {})

func skin_index(character: String, skin_name: String) -> int:
	var list: Array = _skins.get(character, [])
	for i in list.size():
		if str(list[i]) == skin_name:
			return i
	return 0

func villager_skin_pool() -> Array:
	var def := unit("villager")
	var pool = def.get("skins", [])
	if pool is Array and not pool.is_empty():
		return pool
	return [str(def.get("skin", "wolf"))]

func scaled_enemy(id: String, wave_index: int) -> Dictionary:
	var def := enemy(id)
	if def.is_empty():
		push_error("Balance missing enemy %s" % id)
		return {}
	var scaled := def.duplicate(true)
	if _waves.is_empty():
		scaled["hp"] = maxi(int(round(float(scaled.hp))), 1)
		return scaled
	var index := clampi(wave_index, 0, _waves.size() - 1)
	var wave := _waves[index]
	var ref := _waves[0]
	var ref_hp := float(ref.get("hp", 1.0))
	var ref_speed := float(ref.get("speed", 1.0))
	if ref_hp <= 0.0:
		ref_hp = 1.0
	if ref_speed <= 0.0:
		ref_speed = 1.0
	var hp_scale := float(wave.get("hp", ref_hp)) / ref_hp
	var speed_scale := float(wave.get("speed", ref_speed)) / ref_speed
	var diff := difficulty()
	scaled["hp"] = maxi(int(round(float(def.hp) * hp_scale * float(diff.get("hp", 1.0)))), 1)
	scaled["move_speed"] = float(def.move_speed) * speed_scale * float(diff.get("speed", 1.0))
	scaled["gold_reward"] = maxi(int(round(float(def.gold_reward) * float(diff.get("gold", 1.0)))), 0)
	scaled["wood_reward"] = 0
	return scaled

func _norm_unit(raw: Dictionary) -> Dictionary:
	var def := raw.duplicate(true)
	_fill_combat(def)
	if not def.has("cost"):
		def["cost"] = {"wood": 0, "gold": 0}
	def["train_time"] = float(def.get("train_time", 0.0))
	def["character"] = str(def.get("character", "villager"))
	def["skin"] = str(def.get("skin", ""))
	return def

func _norm_enemy(raw: Dictionary) -> Dictionary:
	var def := raw.duplicate(true)
	_fill_combat(def)
	def["scale"] = float(def.get("scale", 1.0))
	def["gold_reward"] = int(def.get("gold_reward", 0))
	def["wood_reward"] = 0
	def["xp_reward"] = int(def.get("xp_reward", 0))
	def["character"] = str(def.get("character", "spear"))
	if not def.has("tags"):
		def["tags"] = []
	return def

func _norm_building(raw: Dictionary) -> Dictionary:
	var def := raw.duplicate(true)
	def["hp"] = int(def.get("hp", 1))
	def["defense"] = float(def.get("defense", 0.0))
	def["attack"] = float(def.get("attack", 0.0))
	def["attack_speed"] = float(def.get("attack_speed", 0.0))
	def["attack_range"] = float(def.get("attack_range", 0.0))
	def["splash"] = float(def.get("splash", 0.0))
	def["shot_speed"] = float(def.get("shot_speed", 0.0))
	def["can_attack"] = bool(def.get("can_attack", false))
	if not def.has("cost") or not (def.cost is Dictionary):
		def["cost"] = {"wood": 0, "gold": 0}
	else:
		def["cost"] = {"wood": int(def.cost.get("wood", 0)), "gold": int(def.cost.get("gold", 0))}
	if not def.has("recruits") or not (def.recruits is Array):
		def["recruits"] = []
	def["beds"] = int(def.get("beds", 0))
	def["staff_slots"] = int(def.get("staff_slots", 0))
	def["place_cap"] = int(def.get("place_cap", 0))
	if def.has("provides") and def.provides is Dictionary:
		def["provides"] = {
			"unit": str(def.provides.get("unit", "")),
			"slots": int(def.provides.get("slots", 0)),
		}
	else:
		def["provides"] = {}
	if def.has("produces") and def.produces is Dictionary:
		var produced: Dictionary = def.produces.duplicate(true)
		produced["resource"] = str(produced.get("resource", ""))
		produced["mode"] = str(produced.get("mode", "wave" if produced.has("rate") else ""))
		produced["rate"] = int(produced.get("rate", 0))
		produced["rate_per_villager"] = int(produced.get("rate_per_villager", 0))
		produced["interval"] = float(produced.get("interval", 0.0))
		def["produces"] = produced
	if not def.has("bonus") or not (def.bonus is Dictionary):
		def["bonus"] = {}
	def["kind"] = str(def.get("kind", ""))
	def["category"] = str(def.get("category", ""))
	def["tex"] = CatalogPaths.resolve(str(def.get("tex", "")))
	return def

func _fill_combat(def: Dictionary) -> void:
	def["hp"] = float(def.get("hp", 1.0))
	def["defense"] = float(def.get("defense", 0.0))
	def["attack"] = float(def.get("attack", 0.0))
	def["attack_speed"] = float(def.get("attack_speed", 1.0))
	def["move_speed"] = float(def.get("move_speed", 0.0))
	def["attack_range"] = float(def.get("attack_range", 0.0))

func settlement() -> Dictionary:
	return _setup.get("settlement", {"chance": 0.65, "max_per_wave": 3})

func combat() -> Dictionary:
	return _setup.get("combat", {})

func combat_f(key: String, fallback: float) -> float:
	return float(combat().get(key, fallback))

func economy() -> Dictionary:
	return _setup.get("economy", {})

func economy_i(key: String, fallback: int) -> int:
	return int(economy().get(key, fallback))

func spawns() -> Array:
	var raw = _setup.get("spawns", [])
	return raw if raw is Array else []

func spawn_rects() -> Array:
	var raw = _setup.get("spawn_rects", [])
	return raw if raw is Array else []

func starter_buildings() -> Array:
	var raw = _setup.get("starter_buildings", [])
	return raw if raw is Array else []

func starter_units() -> Array:
	var raw = _setup.get("starter_units", [])
	return raw if raw is Array else []

func starter_props() -> Array:
	var raw = _setup.get("starter_props", [])
	return raw if raw is Array else []

func difficulty_id() -> String:
	return str(_setup.get("difficulty_id", "normal"))

func difficulty() -> Dictionary:
	var presets = _setup.get("presets", {})
	if presets is Dictionary and presets.has(difficulty_id()) and presets[difficulty_id()] is Dictionary:
		return presets[difficulty_id()]
	return {"hp": 1.0, "count": 1.0, "speed": 1.0, "gold": 1.0}

func count_scale(amount: int) -> int:
	if amount <= 0:
		return 0
	var scaled := int(round(float(amount) * float(difficulty().get("count", 1.0))))
	return maxi(scaled, 1)

func editor_state() -> Dictionary:
	var slots := {
		"house": int(building("house").get("beds", 4)),
		"workshop": _provide_slots("workshop"),
		"spear_barracks": _provide_slots("spear_barracks"),
		"gun_barracks": _provide_slots("gun_barracks"),
		"lumber_mill": int(building("lumber_mill").get("staff_slots", 4)),
	}
	var produced: Dictionary = building("lumber_mill").get("produces", {})
	var units := {}
	for id in _unit_order:
		var row: Dictionary = _units[id]
		units[id] = {
			"hp": float(row.get("hp", 1)),
			"defense": float(row.get("defense", 0)),
			"attack": float(row.get("attack", 0)),
			"attack_speed": float(row.get("attack_speed", 1)),
			"move_speed": float(row.get("move_speed", 0)),
			"attack_range": float(row.get("attack_range", 0)),
		}
	var enemies := {}
	for id in _enemy_order:
		var row: Dictionary = _enemies[id]
		enemies[id] = {
			"hp": float(row.get("hp", 1)),
			"defense": float(row.get("defense", 0)),
			"attack": float(row.get("attack", 0)),
			"move_speed": float(row.get("move_speed", 0)),
			"gold_reward": int(row.get("gold_reward", 0)),
		}
	return {
		"config_version": _shipped_version,
		"difficulty_id": difficulty_id(),
		"presets": (_setup.get("presets", {}) as Dictionary).duplicate(true),
		"settlement": settlement().duplicate(true),
		"combat": combat().duplicate(true),
		"economy": economy().duplicate(true),
		"spawns": spawns().duplicate(true),
		"spawn_rects": spawn_rects().duplicate(true),
		"starter_buildings": starter_buildings().duplicate(true),
		"starter_units": starter_units().duplicate(true),
		"starter_props": starter_props().duplicate(true),
		"slots": slots,
		"lumber": {
			"rate_per_villager": int(produced.get("rate_per_villager", 1)),
			"interval": float(produced.get("interval", 5.0)),
		},
		"waves": _waves.duplicate(true),
		"units": units,
		"enemies": enemies,
		"buildings": _building_editor_rows(),
	}

func save_editor_state(state: Dictionary) -> void:
	_write_user_setup(state)
	reload()

func reset_editor_state() -> void:
	for path in [USER_SETUP_PATH, USER_LAYOUT_PATH, USER_BALANCE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	reload()

func config_version() -> int:
	return _shipped_version

func prepare_codex_refresh() -> void:
	var shipped := _read(_cfg(SETUP_PATH, SETUP_LEGACY))
	_shipped_version = maxi(int(shipped.get("config_version", 1)), 1)
	_pull_web_setup()
	if _upgrade_user_setup(shipped):
		reload()
		return
	_publish_web_setup()

func _building_editor_rows() -> Dictionary:
	var rows := {}
	for id in _building_order:
		var row: Dictionary = _buildings[id]
		var cost: Dictionary = row.get("cost", {})
		rows[id] = {
			"hp": int(row.get("hp", 1)),
			"defense": float(row.get("defense", 0)),
			"cost_wood": int(cost.get("wood", 0)),
			"cost_gold": int(cost.get("gold", 0)),
		}
	return rows

func _provide_slots(id: String) -> int:
	var row: Dictionary = building(id).get("provides", {})
	return int(row.get("slots", 0))

func _default_setup() -> Dictionary:
	return {
		"config_version": _shipped_version,
		"difficulty_id": "normal",
		"presets": {
			"easy": {"hp": 0.8, "count": 0.8, "speed": 0.92, "gold": 1.15},
			"normal": {"hp": 1.0, "count": 1.0, "speed": 1.0, "gold": 1.0},
			"hard": {"hp": 1.35, "count": 1.15, "speed": 1.08, "gold": 0.85},
		},
		"settlement": {"chance": 0.65, "max_per_wave": 3},
		"combat": {
			"target_hold": 1.2,
			"switch_margin": 0.72,
			"repath": 0.6,
			"stuck": 0.9,
			"wander_hold": 2.4,
			"panic_hold": 1.3,
		},
		"economy": {
			"start_wood": 100,
			"start_gold": 70,
			"wave_clear_wood": 8,
			"wave_clear_gold": 14,
		},
		"spawns": [[9, 0], [10, 0], [11, 0]],
		"spawn_rects": _Plan.default_rects(),
		"starter_buildings": [],
		"starter_units": [],
		"starter_props": [],
	}

func _overlay_setup(doc: Dictionary) -> void:
	if doc.is_empty():
		return
	for key in ["config_version", "difficulty_id", "presets", "settlement", "combat", "economy", "spawns", "spawn_rects", "starter_buildings", "starter_units", "starter_props", "slots", "lumber", "waves", "units", "enemies", "buildings"]:
		if doc.has(key):
			_setup[key] = doc[key]
	_normalize_setup()

func _normalize_setup() -> void:
	var settle: Dictionary = _setup.get("settlement", {})
	_setup["settlement"] = {
		"chance": clampf(float(settle.get("chance", 0.65)), 0.0, 1.0),
		"max_per_wave": maxi(int(settle.get("max_per_wave", 3)), 0),
	}
	var fight: Dictionary = _setup.get("combat", {})
	_setup["combat"] = {
		"target_hold": maxf(float(fight.get("target_hold", 1.2)), 0.2),
		"switch_margin": clampf(float(fight.get("switch_margin", 0.72)), 0.2, 1.0),
		"repath": maxf(float(fight.get("repath", 0.6)), 0.15),
		"stuck": maxf(float(fight.get("stuck", 0.9)), 0.3),
		"wander_hold": maxf(float(fight.get("wander_hold", 2.4)), 0.4),
		"panic_hold": maxf(float(fight.get("panic_hold", 1.3)), 0.4),
	}
	var econ: Dictionary = _setup.get("economy", {})
	_setup["economy"] = {
		"start_wood": maxi(int(econ.get("start_wood", 100)), 0),
		"start_gold": maxi(int(econ.get("start_gold", 70)), 0),
		"wave_clear_wood": maxi(int(econ.get("wave_clear_wood", 8)), 0),
		"wave_clear_gold": maxi(int(econ.get("wave_clear_gold", 14)), 0),
	}
	if not (_setup.get("presets") is Dictionary):
		_setup["presets"] = _default_setup().presets
	var id := str(_setup.get("difficulty_id", "normal"))
	if not (_setup.presets as Dictionary).has(id):
		id = "normal"
	_setup["difficulty_id"] = id
	var layout: Dictionary = _Plan.resolve_layout(_setup.get("spawn_rects", []), _setup.get("spawns", []))
	_setup["spawn_rects"] = layout.get("spawn_rects", [])
	_setup["spawns"] = layout.get("spawns", [])
	var blocked: Dictionary = _Plan.spawn_lookup(_setup["spawn_rects"])
	_setup["starter_buildings"] = _Plan.clean_placed(_setup.get("starter_buildings", []), "kind", _Plan.build_ids(), blocked)
	_setup["starter_units"] = _Plan.clean_placed(_setup.get("starter_units", []), "unit", _Plan.unit_ids(), blocked)
	for item in _setup["starter_buildings"]:
		if item is Dictionary:
			blocked[_Plan._cell_from(item)] = true
	for item in _setup["starter_units"]:
		if item is Dictionary:
			blocked[_Plan._cell_from(item)] = true
	_setup["starter_props"] = _Plan.clean_props(_setup.get("starter_props", []), blocked)

func _apply_setup_stats() -> void:
	var unit_patch = _setup.get("units", {})
	if unit_patch is Dictionary:
		for id in unit_patch.keys():
			if not _units.has(id) or not (unit_patch[id] is Dictionary):
				continue
			for stat in unit_patch[id].keys():
				_units[id][stat] = unit_patch[id][stat]
	var enemy_patch = _setup.get("enemies", {})
	if enemy_patch is Dictionary:
		for id in enemy_patch.keys():
			if not _enemies.has(id) or not (enemy_patch[id] is Dictionary):
				continue
			for stat in enemy_patch[id].keys():
				_enemies[id][stat] = enemy_patch[id][stat]
			_enemies[id]["wood_reward"] = 0
	var wave_patch = _setup.get("waves", [])
	if wave_patch is Array and wave_patch.size() == _waves.size():
		for i in _waves.size():
			if wave_patch[i] is Dictionary:
				for stat in ["hp", "speed", "gap", "normal", "fast", "elite", "boss"]:
					if (wave_patch[i] as Dictionary).has(stat):
						_waves[i][stat] = wave_patch[i][stat]
	var slots = _setup.get("slots", {})
	if slots is Dictionary:
		_set_beds("house", int(slots.get("house", building("house").get("beds", 4))))
		_set_provide("workshop", "engineer", int(slots.get("workshop", _provide_slots("workshop"))))
		_set_provide("spear_barracks", "spearman", int(slots.get("spear_barracks", _provide_slots("spear_barracks"))))
		_set_provide("gun_barracks", "gunner", int(slots.get("gun_barracks", _provide_slots("gun_barracks"))))
		if _buildings.has("lumber_mill"):
			_buildings["lumber_mill"]["staff_slots"] = maxi(int(slots.get("lumber_mill", _buildings["lumber_mill"].get("staff_slots", 4))), 0)
			_by_kind["LUMBER"] = _buildings["lumber_mill"]
	var building_patch = _setup.get("buildings", {})
	if building_patch is Dictionary:
		for id in building_patch.keys():
			if not _buildings.has(id) or not (building_patch[id] is Dictionary):
				continue
			var row: Dictionary = building_patch[id]
			if row.has("hp"):
				_buildings[id]["hp"] = int(row.hp)
			if row.has("defense"):
				_buildings[id]["defense"] = float(row.defense)
			if row.has("cost_wood") or row.has("cost_gold"):
				var cost: Dictionary = _buildings[id].get("cost", {"wood": 0, "gold": 0})
				if row.has("cost_wood"):
					cost["wood"] = int(row.cost_wood)
				if row.has("cost_gold"):
					cost["gold"] = int(row.cost_gold)
				_buildings[id]["cost"] = cost
			var kind := str(_buildings[id].get("kind", ""))
			if kind != "":
				_by_kind[kind] = _buildings[id]
	var lumber = _setup.get("lumber", {})
	if lumber is Dictionary and _buildings.has("lumber_mill"):
		var produced: Dictionary = _buildings["lumber_mill"].get("produces", {})
		if produced.is_empty():
			produced = {"resource": "wood", "mode": "staff"}
		produced["mode"] = "staff"
		produced["resource"] = "wood"
		produced["rate_per_villager"] = maxi(int(lumber.get("rate_per_villager", produced.get("rate_per_villager", 1))), 0)
		produced["interval"] = maxf(float(lumber.get("interval", produced.get("interval", 5.0))), 0.25)
		_buildings["lumber_mill"]["produces"] = produced
		_by_kind["LUMBER"] = _buildings["lumber_mill"]

func _set_beds(id: String, slots: int) -> void:
	if not _buildings.has(id):
		return
	var n := maxi(slots, 0)
	_buildings[id]["beds"] = n
	var provides: Dictionary = _buildings[id].get("provides", {})
	provides["unit"] = "villager"
	provides["slots"] = n
	_buildings[id]["provides"] = provides
	_by_kind["HOUSE"] = _buildings[id]

func _set_provide(id: String, unit_id: String, slots: int) -> void:
	if not _buildings.has(id):
		return
	_buildings[id]["provides"] = {"unit": unit_id, "slots": maxi(slots, 0)}
	var kind := str(_buildings[id].get("kind", ""))
	if kind != "":
		_by_kind[kind] = _buildings[id]

func _upgrade_user_setup(shipped: Dictionary) -> bool:
	var user := _read_user_setup()
	if user.is_empty():
		return false
	var local_v := int(user.get("config_version", 0))
	if local_v >= _shipped_version:
		return false
	var merged := shipped.duplicate(true)
	for key in user.keys():
		if str(key) == "config_version" or str(key) == "_comment":
			continue
		merged[key] = user[key]
	if local_v < 2 and not user.has("spawn_rects"):
		var source = user.get("spawns", [])
		if source is Array and not source.is_empty():
			var derived: Array = _Plan.rects_from_cells(source)
			if not derived.is_empty():
				merged["spawn_rects"] = derived
				merged["spawns"] = _Plan.cells_from_rects(derived)
	if not merged.has("starter_props"):
		merged["starter_props"] = []
	merged["config_version"] = _shipped_version
	_write_user_setup(merged)
	return true

func _pull_web_setup() -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("localStorage.getItem('vtd.setup')", true)
	if raw == null or str(raw) == "":
		return
	var parsed = JSON.parse_string(str(raw))
	if not (parsed is Dictionary) or parsed.is_empty():
		return
	var user := _read_user_setup()
	var user_v := int(user.get("config_version", 0)) if not user.is_empty() else -1
	if int(parsed.get("config_version", 0)) > user_v:
		_write_user_setup(parsed)

func _publish_web_setup() -> void:
	if not OS.has_feature("web"):
		return
	var payload := _read_user_setup()
	if payload.is_empty():
		payload = {"config_version": _shipped_version}
	JavaScriptBridge.eval("localStorage.setItem('vtd.setup', %s)" % JSON.stringify(JSON.stringify(payload)), true)

func _write_user_setup(state: Dictionary) -> void:
	_write_user_file(USER_SETUP_PATH, state)
	var layout := _slice(state, LAYOUT_KEYS)
	var balance := _slice(state, BALANCE_KEYS)
	layout["config_version"] = int(state.get("config_version", _shipped_version))
	balance["config_version"] = int(state.get("config_version", _shipped_version))
	_write_user_file(USER_LAYOUT_PATH, layout)
	_write_user_file(USER_BALANCE_PATH, balance)

func _read_user_setup() -> Dictionary:
	var layout := _read_user_file(USER_LAYOUT_PATH)
	var balance := _read_user_file(USER_BALANCE_PATH)
	if not layout.is_empty() or not balance.is_empty():
		var merged := layout.duplicate(true)
		for key in balance.keys():
			merged[key] = balance[key]
		return merged
	return _read_user_file(USER_SETUP_PATH)

func _write_user_file(path: String, state: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()

func _read_user_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}

func _slice(state: Dictionary, keys: Array[String]) -> Dictionary:
	var out := {}
	for key in keys:
		if state.has(key):
			out[key] = state[key]
	return out

func _cfg(modern: String, legacy: String) -> String:
	if FileAccess.file_exists(modern):
		return modern
	if FileAccess.file_exists(legacy):
		return legacy
	return modern

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Balance missing %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Balance could not parse %s" % path)
	return {}
