class_name CatalogPaths
extends RefCounted

# Resolves config JSON and art files.
# New files live in res://config and res://art. The old res://data and
# res://assets paths still load when the new file is missing, so a
# half-migrated checkout keeps running.

const CONFIG_ROOT := "res://config/"
const ART_ROOT := "res://art/"
const LEGACY_DATA := "res://data/"
const LEGACY_ART := "res://assets/"

const _CONFIG_LEGACY := {
	"balance/units.json": "units.json",
	"balance/enemies.json": "enemies.json",
	"balance/buildings.json": "buildings.json",
	"layout/setup.json": "setup.json",
	"presentation/characters.json": "characters.json",
	"presentation/volumes.json": "iso_volumes.json",
}


static func config_file(rel: String) -> String:
	var modern := CONFIG_ROOT + rel
	if FileAccess.file_exists(modern):
		return modern
	var legacy_name := str(_CONFIG_LEGACY.get(rel, rel.get_file()))
	var legacy := LEGACY_DATA + legacy_name
	if FileAccess.file_exists(legacy):
		return legacy
	return modern


static func art_file(rel: String) -> String:
	var modern := ART_ROOT + rel
	if _exists(modern):
		return modern
	var legacy := LEGACY_ART + rel
	if _exists(legacy):
		return legacy
	return modern


static func resolve(path: String) -> String:
	if path.begins_with(ART_ROOT):
		if _exists(path):
			return path
		var legacy := LEGACY_ART + path.trim_prefix(ART_ROOT)
		if _exists(legacy):
			return legacy
		return path
	if path.begins_with(LEGACY_ART):
		var modern := ART_ROOT + path.trim_prefix(LEGACY_ART)
		if _exists(modern):
			return modern
		return path
	if path.begins_with(CONFIG_ROOT):
		if FileAccess.file_exists(path):
			return path
		var rel := path.trim_prefix(CONFIG_ROOT)
		return config_file(rel)
	if path.begins_with(LEGACY_DATA):
		var name := path.trim_prefix(LEGACY_DATA)
		for rel in _CONFIG_LEGACY.keys():
			if str(_CONFIG_LEGACY[rel]) == name:
				return config_file(rel)
		return path
	return path


static func load_tex(rel_or_res: String) -> Texture2D:
	var res = load_res(rel_or_res)
	return res if res is Texture2D else null


static func load_font(rel := "fonts/NotoSansSC-Regular.otf") -> Font:
	var res = load_res(rel)
	return res if res is Font else null


static func load_res(rel_or_res: String):
	var path := rel_or_res
	if path.begins_with("res://"):
		path = resolve(path)
	else:
		path = art_file(path)
	if not _exists(path):
		return null
	return load(path)


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)
