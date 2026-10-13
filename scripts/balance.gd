extends Node

# Loads data/units.json, data/enemies.json, and data/buildings.json once.
# data/characters.json stays visual (sheets, clips, skins). It is read here
# only to turn a skin name into a sheet index.
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

const UNITS_PATH := "res://data/units.json"
const ENEMIES_PATH := "res://data/enemies.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const CHARACTERS_PATH := "res://data/characters.json"

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
	var units_doc := _read(UNITS_PATH)
	for raw in units_doc.get("units", []):
		if raw is Dictionary:
			var def := _norm_unit(raw)
			var id := str(def.get("id", ""))
			if id == "":
				continue
			_units[id] = def
			_unit_order.append(id)
	var enemies_doc := _read(ENEMIES_PATH)
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
	var buildings_doc := _read(BUILDINGS_PATH)
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
	var characters := _read(CHARACTERS_PATH)
	for key in characters.keys():
		var row = characters[key]
		if row is Dictionary and row.has("skins"):
			_skins[str(key)] = row.skins

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
	scaled["hp"] = maxi(int(round(float(def.hp) * hp_scale)), 1)
	scaled["move_speed"] = float(def.move_speed) * speed_scale
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
	def["wood_reward"] = int(def.get("wood_reward", 0))
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
	def["place_cap"] = int(def.get("place_cap", 0))
	if not def.has("bonus") or not (def.bonus is Dictionary):
		def["bonus"] = {}
	def["kind"] = str(def.get("kind", ""))
	def["category"] = str(def.get("category", ""))
	def["tex"] = str(def.get("tex", ""))
	return def

func _fill_combat(def: Dictionary) -> void:
	def["hp"] = float(def.get("hp", 1.0))
	def["defense"] = float(def.get("defense", 0.0))
	def["attack"] = float(def.get("attack", 0.0))
	def["attack_speed"] = float(def.get("attack_speed", 1.0))
	def["move_speed"] = float(def.get("move_speed", 0.0))
	def["attack_range"] = float(def.get("attack_range", 0.0))

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Balance missing %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Balance could not parse %s" % path)
	return {}
