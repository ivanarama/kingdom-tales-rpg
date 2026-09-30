extends RefCounted
## Свёрнутая на телефоне или закрытая игра сохраняет карту: ходы с последнего сохранения не пропадают.

const TITLE := "Testing Save When the App Is Paused or Closed"


func run(t: Node) -> void:
	GameState.reset()
	GameState.start_chapter(1)
	GameState.flags["chapter_intro_seen_1"] = true
	var wm = load("res://src/world/world_map.tscn").instantiate()
	t.add_child(wm)
	await t.get_tree().process_frame
	# Сворачивание: золото, полученное после последнего сохранения, переживает перезапуск
	GameState.gold += 777
	var gold_paused: int = GameState.gold
	wm.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	GameState.gold = 0
	assert(GameState.load_game() and GameState.gold == gold_paused, "Pausing the app must save the map")
	# Закрытие окна — то же самое
	GameState.gold += 111
	var gold_closed: int = GameState.gold
	wm.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	GameState.gold = 0
	assert(GameState.load_game() and GameState.gold == gold_closed, "Closing the window must save the map")
	# Потеря фокуса сохраняет только в браузере: на ПК и телефоне окно просто переключают
	if not OS.has_feature("web"):
		GameState.gold += 5
		wm.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		GameState.gold = 0
		assert(GameState.load_game() and GameState.gold == gold_closed, "Focus loss must not save outside the web build")
	wm.queue_free()
	await t.get_tree().process_frame
	GameState.reset()
	print("  -> The map saves when the app is paused or closed!")
