class_name EncounterData
extends RefCounted

## Реестр тактических встреч: контент правится в data/encounters.json
## без изменения кода арены (см. CONCEPT.md — конвейер).

const DATA_PATH := "res://data/encounters.json"

static var _cache: Dictionary = {}

static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = _load()
	return _cache

static func _load() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("EncounterData: missing %s" % DATA_PATH)
		return {}
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EncounterData: malformed JSON")
		return {}
	return parsed

static func get_encounter(id: String) -> Dictionary:
	var raw: Dictionary = get_all().get(id, {})
	if raw.is_empty():
		return {}
	return _normalize(id, raw)

static func get_default_for_chapter(chapter: int) -> Dictionary:
	var defaults: Dictionary = get_all().get("_defaults", {})
	var raw: Dictionary = defaults.get(str(clampi(chapter, 1, 99)), {})
	if raw.is_empty():
		raw = defaults.get("1", {})
	return _normalize("default_ch%d" % chapter, raw)

static func _normalize(id: String, raw: Dictionary) -> Dictionary:
	var enemies: Array = []
	for item in raw.get("enemies", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var hex_arr = item.get("hex", [10, 3])
		enemies.append({
			"unit_id": str(item.get("unit", "")),
			"count": maxi(1, int(item.get("count", 1))),
			"hex": Vector2i(int(hex_arr[0]), int(hex_arr[1]))
		})
	return {
		"id": id,
		"log": str(raw.get("log", "Вражеский отряд преграждает путь!")),
		"enemies": enemies
	}
