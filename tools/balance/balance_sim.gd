extends Node
## Проверка баланса: настоящие бои на автобое за обе стороны.
## Для каждой главы берутся её встречи с карты и герой с войском со старта главы
## (как в меню «Выбор главы», GameState.prepare_chapter_start), для каждой сложности — RUNS боёв.
## Магию герой на автобое не применяет, так что результат — нижняя граница силы игрока.
##
## Запуск без окна; --fixed-fps отвязывает бой от реального времени, и он идёт в разы быстрее:
##   godot --headless --path . --fixed-fps 60 res://tools/balance/balance_sim.tscn
## Переменные окружения: RUNS — боёв на связку (по умолчанию 3), OUT — путь для отчёта .md,
## ONLY — id встреч через запятую, чтобы прогнать только их.

const DIFFS := ["easy", "normal", "hard", "legendary"]
const DIFF_TITLES := {"easy": "Новобранец", "normal": "Воитель", "hard": "Герой", "legendary": "Легенда"}
const TIME_SCALE := 4.0
const MAX_GAME_SECONDS := 900.0 # дольше — ничья (оба войска топчутся на месте)

var _start_msec := 0


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	SettingsManager.battle_tutorial_done = true
	seed(20260930)
	var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 3
	var only: PackedStringArray = OS.get_environment("ONLY").split(",", false)
	var rows: Array[Dictionary] = []
	var armies := {}
	for ch in [1, 2, 3]:
		var battles: Array[String] = await _chapter_battles(ch)
		armies[ch] = _army_text(ch)
		for id in battles:
			if not only.is_empty() and not only.has(id):
				continue
			var row := {"ch": ch, "id": id, "enemies": _enemies_text(id), "cells": {}}
			for diff in DIFFS:
				var wins := 0
				var draws := 0
				var loss := 0.0
				var rounds := 0.0
				for i in runs:
					var r: Dictionary = await _battle(ch, id, diff)
					wins += 1 if r["won"] else 0
					draws += 1 if r["draw"] else 0
					loss += r["loss"]
					rounds += r["rounds"]
				row["cells"][diff] = {"wins": wins, "runs": runs, "draws": draws, "loss": loss / runs, "rounds": rounds / runs}
			rows.append(row)
			print("BAL ch%d %-22s %s" % [ch, id, _cells_text(row)])
	var report := _report(rows, armies, runs)
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(report)
		f.close()
		print("BAL report saved to ", out)
	print("BAL done in %d s" % int((Time.get_ticks_msec() - _start_msec) / 1000))
	get_tree().quit()


## Встречи главы — патрули и босс с её карты, в порядке клеток.
func _chapter_battles(ch: int) -> Array[String]:
	GameState.reset()
	GameState.prepare_chapter_start(ch)
	GameState.flags["chapter_intro_seen_%d" % ch] = true
	var wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(wm)
	await get_tree().process_frame
	var cells: Array = wm.world_view.objects.keys()
	cells.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var ids: Array[String] = []
	var boss := ""
	for c in cells:
		var obj: Dictionary = wm.world_view.objects[c]
		var type := str(obj.get("type", ""))
		if type == "encounter":
			ids.append(str(obj.get("id", "")))
		elif type.ends_with("_boss"):
			boss = type
	if boss != "":
		ids.append(boss)
	wm.queue_free()
	await get_tree().process_frame
	return ids


func _battle(ch: int, id: String, diff: String) -> Dictionary:
	GameState.reset()
	GameState.prepare_chapter_start(ch)
	GameState.campaign_difficulty = diff
	GameState.pending_battle_id = id
	var ba = load("res://src/battle/battle_arena.tscn").instantiate()
	ba.is_auto_battling = true # до _ready: первый же ход игрока пойдёт на автобое
	add_child(ba)
	Engine.time_scale = TIME_SCALE
	await get_tree().process_frame
	var p0 := _pool(ba, 0)
	var frames := 0
	var max_frames := int(MAX_GAME_SECONDS * 60.0 / TIME_SCALE)
	while not ba.victory_dialog.visible and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	var draw: bool = not ba.victory_dialog.visible
	var won: bool = not draw and ba._has_living_players() and not ba._has_living_enemies()
	var p1 := _pool(ba, 0)
	var result := {
		"won": won,
		"draw": draw,
		"loss": 1.0 - float(p1) / float(maxi(1, p0)),
		"rounds": float(ba.battle_stats.get("rounds", 0)),
	}
	ba.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return result


## Запас здоровья стороны: (число − 1) × макс. HP + HP верхнего бойца.
func _pool(ba, team: int) -> int:
	var total := 0
	for s in ba.all_stacks:
		if s.team == team and s.is_alive():
			total += (s.count - 1) * int(s.data["max_hp"]) + s.current_hp
	return total


func _army_text(ch: int) -> String:
	GameState.reset()
	GameState.prepare_chapter_start(ch)
	var parts: Array[String] = []
	for item in GameState.player_army:
		parts.append("%s ×%d" % [str(UnitData.get_unit(item["unit_id"]).get("name", item["unit_id"])), int(item["count"])])
	return "ур. %d, Атака %d, Защита %d: %s" % [GameState.level, GameState.attack, GameState.defense, ", ".join(parts)]


func _enemies_text(id: String) -> String:
	var enc: Dictionary = EncounterData.get_encounter(id)
	var parts: Array[String] = []
	for e in enc.get("enemies", []):
		parts.append("%s ×%d" % [str(UnitData.get_unit(e["unit_id"] if e.has("unit_id") else e.get("unit", "")).get("name", "?")), int(e.get("count", 0))])
	return ", ".join(parts)


func _cells_text(row: Dictionary) -> String:
	var parts: Array[String] = []
	for diff in DIFFS:
		var c: Dictionary = row["cells"][diff]
		parts.append("%s %d/%d −%d%%" % [diff, c["wins"], c["runs"], int(round(c["loss"] * 100.0))])
	return " | ".join(parts)


func _report(rows: Array[Dictionary], armies: Dictionary, runs: int) -> String:
	var L: Array[String] = []
	L.append("| Встреча | Враги | " + " | ".join(DIFFS.map(func(d): return DIFF_TITLES[d])) + " |")
	L.append("|---|---|" + "---|".repeat(DIFFS.size()))
	var ch_seen := 0
	for row in rows:
		if row["ch"] != ch_seen:
			ch_seen = row["ch"]
			L.append("| **Глава %d** | %s |%s" % [ch_seen, armies[ch_seen], " |".repeat(DIFFS.size())])
		var cells: Array[String] = []
		for diff in DIFFS:
			var c: Dictionary = row["cells"][diff]
			var mark := ""
			if c["wins"] * 2 < c["runs"]:
				mark = " ⚠"
			cells.append("%d/%d · −%d%%%s" % [c["wins"], c["runs"], int(round(c["loss"] * 100.0)), mark])
		L.append("| `%s` | %s | %s |" % [row["id"], row["enemies"], " | ".join(cells)])
	L.append("")
	L.append("Ячейка — побед из %d боёв и сколько здоровья войска игрока потеряно в среднем. ⚠ — побед меньше половины." % runs)
	return "\n".join(L) + "\n"
