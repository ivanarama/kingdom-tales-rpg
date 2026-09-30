extends RefCounted
## Английская версия сказочных встреч: у каждой строки из data/map_events.json есть перевод.

const TITLE := "Testing English Map Events"


func run(t: Node) -> void:
	var saved_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var all_events: Dictionary = MapEventData.get_all()
	var missing: Array[String] = []
	var checked := 0
	for id in all_events:
		if not (all_events[id] is Dictionary):
			continue
		var ev: Dictionary = all_events[id]
		var lines: Array = [ev.get("title", ""), ev.get("text", "")]
		for c in ev.get("choices", []):
			lines.append(c.get("label", ""))
			lines.append(c.get("result", ""))
		for line in lines:
			if t._has_cyrillic(tr(str(line))):
				missing.append("%s: %s" % [id, str(line).left(50)])
		checked += 1
	TranslationServer.set_locale(saved_locale)
	assert(missing.is_empty(), "Map events need English (tools/tr_dicts + tools/build_csv.py): %s" % str(missing.slice(0, 5)))
	print("  -> All %d map events read in English!" % checked)
