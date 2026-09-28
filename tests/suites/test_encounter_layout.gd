extends RefCounted

## Вражеские отряды каждого столкновения стоят на поле и не делят клетку.

func get_title() -> String:
	return "Encounter Layout: enemy stacks inside the field on distinct hexes"

func run(t) -> void:
	var bounds := Rect2i(0, 0, BattleArena.GRID_COLS, BattleArena.GRID_ROWS)
	var encounters: Array = EncounterData.ENCOUNTERS.values() + EncounterData.CHAPTER_DEFAULTS.values()
	for enc in encounters:
		var seen := {}
		for item in enc["army"]:
			var hex: Vector2i = item["hex"]
			t._check(HexGrid.is_in_bounds(hex, bounds), "%s: отряд вне поля на %s" % [enc["name"], hex])
			t._check(not seen.has(hex), "%s: два отряда на клетке %s" % [enc["name"], hex])
			seen[hex] = true
