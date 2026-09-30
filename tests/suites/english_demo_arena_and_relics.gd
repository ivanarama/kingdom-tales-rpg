extends RefCounted
## Английская версия: черты отрядов на карточках демо-арены и реликвии героя (#34).

const TITLE := "Testing English Demo Arena Cards & Hero Relics"


func run(t: Node) -> void:
	var en_saved_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var en_main = load("res://src/main.tscn").instantiate()
	t.add_child(en_main)
	await t.get_tree().process_frame
	var en_trait_lines := 0
	for en_l in en_main.arena_dialog.find_children("*", "Label", true, false):
		var en_shown: String = tr(en_l.text)
		if en_shown.contains(" • ") or en_shown == "Melee infantry":
			en_trait_lines += 1
		assert(not t._has_cyrillic(en_shown), "Demo arena text must be translated: " + en_shown.left(60))
	assert(en_trait_lines > 0, "Demo arena cards must list unit traits")
	en_main.queue_free()
	await t.get_tree().process_frame
	GameState.reset()
	GameState.has_fairy_crown = true
	GameState.has_gate_key = true
	GameState.flags["iron_gate_opened"] = true
	var en_wm = load("res://src/world/world_map.tscn").instantiate()
	t.add_child(en_wm)
	await t.get_tree().process_frame
	en_wm._update_hero_profile()
	var en_relics: String = en_wm.hero_relics_lbl.text
	assert(en_relics.contains("Crown") and not t._has_cyrillic(tr(en_relics)), "Hero relics must be translated: " + en_relics.left(60))
	en_wm.queue_free()
	await t.get_tree().process_frame
	GameState.reset()
	TranslationServer.set_locale(en_saved_locale)
	print("  -> Demo arena cards and hero relics read in English!")
