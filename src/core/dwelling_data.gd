class_name DwellingData
extends RefCounted

## Реестр наёмных жилищ (data/dwellings.json): контент правится данными.

const DATA_PATH := "res://data/dwellings.json"

static var _cache: Dictionary = {}

static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = _load()
	return _cache

static func _load() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("DwellingData: missing %s" % DATA_PATH)
		return {}
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DwellingData: malformed JSON")
		return {}
	return parsed

static func get_dwelling(id: String) -> Dictionary:
	var raw: Dictionary = get_all().get(id, {})
	return raw
