class_name MapEventData
extends RefCounted

## Сказочные встречи на карте (data/map_events.json): история и выбор.
## Новая встреча — новая запись в JSON, без правок кода карты.

const DATA_PATH := "res://data/map_events.json"

static var _cache: Dictionary = {}

static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = _load()
	return _cache

static func _load() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("MapEventData: missing %s" % DATA_PATH)
		return {}
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MapEventData: malformed JSON")
		return {}
	return parsed

static func get_event(id: String) -> Dictionary:
	var raw = get_all().get(id, {})
	return raw if raw is Dictionary else {}

## Иллюстрация встречи: assets/art/events/<image или id>.png, если уже нарисована, иначе "".
## Поле image позволяет стадиям одного квеста делить картинку.
static func image_path(id: String) -> String:
	var p := "res://assets/art/events/%s.png" % str(get_event(id).get("image", id))
	return p if ResourceLoader.exists(p) else ""

## Встречи главы, которые сейчас стоят на карте: не решённые, и show_if/hide_if
## по флагам. Возвращает готовые объекты карты {type, name, id, cell}.
static func visible_for_chapter(chapter: int, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var all := get_all()
	for id in all:
		var ev = all[id]
		if not (ev is Dictionary) or int(ev.get("chapter", 0)) != chapter:
			continue
		var show_if := str(ev.get("show_if", ""))
		if show_if != "" and not flags.get(show_if, false):
			continue
		if flags.get(str(id), false) or flags.get(str(ev.get("hide_if", "")), false):
			continue
		var cell = ev.get("cell", [])
		if cell is Array and cell.size() >= 2:
			result.append({"type": "event", "name": str(ev.get("title", "")), "id": str(id), "cell": Vector2i(int(cell[0]), int(cell[1]))})
	return result
