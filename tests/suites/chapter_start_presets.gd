extends RefCounted
## Старт с выбранной главы: герой и войско, с которыми глава задумана. Ими пользуются меню
## «Выбор главы» и проверка баланса (tools/balance/), поэтому пресеты живут в одном месте.

const TITLE := "Testing Chapter Start Presets"


func run(_t: Node) -> void:
	GameState.reset()
	var new_game_army := GameState.player_army.duplicate(true)
	GameState.prepare_chapter_start(1)
	assert(GameState.current_chapter == 1 and GameState.player_army == new_game_army, "Chapter 1 starts with the new-game army")
	GameState.reset()
	GameState.prepare_chapter_start(2)
	assert(GameState.current_chapter == 2 and GameState.level == 3 and GameState.attack == 6 and GameState.defense == 5, "Chapter 2 hero preset")
	assert(GameState.player_army.size() == 2 and GameState.player_army[1]["unit_id"] == "royal_fairy", "Chapter 2 army preset")
	GameState.reset()
	GameState.prepare_chapter_start(3)
	assert(GameState.current_chapter == 3 and GameState.level == 5 and GameState.attack == 8 and GameState.player_army.size() == 3, "Chapter 3 preset")
	GameState.reset()
	print("  -> Chapter start presets for the chapter menu and the balance check are in one place!")
