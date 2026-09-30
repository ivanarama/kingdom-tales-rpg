extends RefCounted
## Побочный квест третьей главы «Гном-кузнец Борин»: просьба → молот за Огненными вратами → награда один раз.

const TITLE := "Testing the Dwarf Smith's Lost Hammer Quest"


func run(t: Node) -> void:
	GameState.reset()
	GameState.start_chapter(3)
	GameState.flags["chapter_intro_seen_3"] = true
	var wm = load("res://src/world/world_map.tscn").instantiate()
	t.add_child(wm)
	await t.get_tree().process_frame
	var objs: Dictionary = wm.world_view.objects
	var smith := Vector2i(12, 5)
	var hammer := Vector2i(18, 17)
	assert(objs.get(smith, {}).get("id", "") == "ch3_smith" and not objs.has(hammer), "At first only the smith asks for help")
	wm._trigger_object(objs[smith])
	assert(wm.popup_title.text == tr("Гном-кузнец Борин") and wm.popup_btn2.visible, "The smith offers two choices")
	wm.popup_btn2.emit_signal("pressed")
	assert(objs.get(smith, {}).get("id", "") == "ch3_smith", "'Later' keeps the smith waiting")
	wm._trigger_object(objs[smith])
	wm.popup_btn1.emit_signal("pressed")
	assert(GameState.flags.get("hammer_quest", false) and objs.get(hammer, {}).get("id", "") == "ch3_lost_hammer", "Accepting the quest puts the hammer on the map")
	assert(objs.get(smith, {}).get("id", "") == "ch3_smith_wait", "The smith waits for news")
	wm._trigger_object(objs[hammer])
	wm.popup_btn1.emit_signal("pressed")
	assert(not objs.has(hammer) and objs.get(smith, {}).get("id", "") == "ch3_smith_thanks", "Found hammer: the smith waits to thank the hero")
	var attack_before: int = GameState.attack
	wm._trigger_object(objs[smith])
	wm.popup_btn1.emit_signal("pressed")
	assert(GameState.attack == attack_before + 1 and not objs.has(smith), "The blades are reforged once and the quest leaves the map")
	wm.queue_free()
	await t.get_tree().process_frame
	GameState.reset()
	print("  -> Borin gets his hammer back, and the blades are reforged once!")
