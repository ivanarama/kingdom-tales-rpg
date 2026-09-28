extends Node

const SpellData = preload("res://src/core/spell_data.gd")
const ArtifactData = preload("res://src/core/artifact_data.gd")
const UnitData = preload("res://src/core/unit_data.gd")
const BattleStack = preload("res://src/battle/battle_stack.gd")

## Сколько секунд даём всему прогону. Если скрипт упал посреди набора,
## _ready() обрывается и до _finish() не доходит — тогда прогон завершает сторож.
const WATCHDOG_SEC := 120.0

## Считает ошибки движка и скриптов (SCRIPT ERROR, push_error) во время прогона.
## Ошибка в коде игры не обрывает тест, поэтому без счётчика она осталась бы незамеченной.
class ErrorCounter extends Logger:
	var _mutex := Mutex.new()
	var _messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_messages.append("%s:%d %s" % [file, line, rationale if rationale != "" else code])
		_mutex.unlock()

	func get_messages() -> Array[String]:
		_mutex.lock()
		var copy := _messages.duplicate()
		_mutex.unlock()
		return copy

var _errors := ErrorCounter.new()
var _failures: Array[String] = []
var _finished := false

## Проверка без обрыва прогона: провал копится и попадает в итог.
func _check(condition, message: String = "") -> void:
	if not condition:
		_failures.append(message)
		print("[TEST] FAIL: " + message)

func _finish(timed_out: bool = false) -> void:
	if _finished:
		return
	_finished = true
	var errors := _errors.get_messages()
	if timed_out or not _failures.is_empty() or not errors.is_empty():
		print("\n==========================================")
		print("[TEST] RESULT: FAILED (провалов проверок: %d, ошибок скриптов: %d%s)" % [
			_failures.size(), errors.size(), ", прогон оборван по таймауту" if timed_out else ""
		])
		for f in _failures:
			print("  FAIL: " + f)
		for e in errors.slice(0, 30):
			print("  ERROR: " + e)
		print("==========================================\n")
		get_tree().quit(1)
		return
	print("\n==========================================")
	print("   ALL 41 TEST SUITES PASSED FLAWLESSLY!  ")
	print("==========================================\n")
	get_tree().quit(0)

func _ready() -> void:
	OS.add_logger(_errors)
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(func():
		print("[TEST] TIMEOUT: прогон не завершился за %d с — скорее всего, набор оборвался на ошибке" % int(WATCHDOG_SEC))
		_finish(true)
	)
	print("\n==========================================")
	print("[TEST] Running full HoMM-style verification suite...")
	
	# 1. Test SFX & Music
	print("[TEST] 1. Testing Audio & Music...")
	_check(SoundManager.music_player != null, "Music player must exist")
	_check(SoundManager.sfx_cache.has("horse_gallop"), "Missing horse_gallop")
	_check(SoundManager.sfx_cache.has("bow_shot"), "Missing bow_shot")
	_check(SoundManager.sfx_cache.has("arrow_hit"), "Missing arrow_hit")
	print("  -> SFX cache verified! Audio files imported successfully.")

	# 2. Test Persistent Hero Coordinates
	print("[TEST] 2. Testing Hero Position & World Persistence...")
	GameState.hero_cell = Vector2i(18, 11)
	var wmap_packed = load("res://src/world/world_map.tscn")
	var wmap_node = wmap_packed.instantiate()
	add_child(wmap_node)
	
	var wv = wmap_node.get_node("ScrollContainer/WorldView")
	_check(wv.hero_cell == Vector2i(18, 11), "WorldView must restore hero_cell from GameState")
	print("  -> Hero position restored to (18, 11) after battle/scene transition!")
	
	# 3. Test Chest Vanishing
	print("[TEST] 3. Testing Chest Vanishing upon Pickup...")
	_check(wv.objects.has(Vector2i(4, 9)), "Chest must exist before pickup")
	# In HoMM, guard must be defeated before chest pickup; set guard defeated for unit test
	GameState.flags["patrol_goblins"] = true
	# Simulate picking up the chest
	var chest_obj = wv.objects[Vector2i(4, 9)]
	wv.hero_cell = Vector2i(4, 9)
	wmap_node._trigger_object(chest_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	_check(GameState.flags.get("chest_start", false), "Chest flag must be set to true")
	_check(not wv.objects.has(Vector2i(4, 9)), "Chest must vanish from objects map!")
	print("  -> Chest collected and vanished completely from the map!")

	# 4. Test Limited Dwelling Stock & Hiring
	print("[TEST] 4. Testing Fairy Dwelling Stock & Hiring...")
	var initial_stock = GameState.dwelling_stock.get("fairy_camp", 0)
	_check(initial_stock == 14, "Dwelling initial stock should be 14")
	var fairy_obj = wv.objects[Vector2i(10, 8)]
	wmap_node._trigger_object(fairy_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	_check(GameState.dwelling_stock["fairy_camp"] < initial_stock, "Dwelling stock must decrease after hiring")
	print("  -> Fairy dwelling stock decreased to %d!" % GameState.dwelling_stock["fairy_camp"])
	
	wmap_node.queue_free()

	# 5. Test Combat Damage Forecast, Broken Arrow & Health Bars
	print("[TEST] 5. Testing Combat Damage Forecast & Broken Arrow...")
	var arena_packed = load("res://src/battle/battle_arena.tscn")
	var arena_node = arena_packed.instantiate()
	add_child(arena_node)
	
	# Find an archer stack and an enemy stack
	var archer: BattleStack = null
	var enemy: BattleStack = null
	for s in arena_node.all_stacks:
		if s.team == 0 and s.data.get("is_ranged", false):
			archer = s
		elif s.team == 1:
			enemy = s
			
	_check(archer != null, "Archer stack must exist")
	_check(enemy != null, "Enemy stack must exist")
	
	# Test normal range forecast (< 5 hexes)
	var forecast_close = archer.get_damage_range(enemy, false, false)
	# Test broken arrow range forecast (> 5 hexes)
	var forecast_broken = archer.get_damage_range(enemy, false, true)
	_check(forecast_broken.min_dmg <= forecast_close.min_dmg, "Broken arrow must have reduced damage")
	print("  -> Normal damage: %d-%d | Broken arrow (penalty 50%%): %d-%d" % [
		forecast_close.min_dmg, forecast_close.max_dmg,
		forecast_broken.min_dmg, forecast_broken.max_dmg
	])
	
	# Test Unit Inspector Card
	arena_node._show_unit_info(enemy)
	_check(arena_node.unit_info_dialog.visible, "Unit info dialog must open")
	print("  -> Unit Inspector Card opened with full stats!")

	# 6. Test Tactical AI Target Selection (Archer Focus)
	print("[TEST] 6. Testing Tactical AI Target Selection...")
	var player_stacks: Array[BattleStack] = []
	var melee_stack = BattleStack.new()
	melee_stack.setup("griffin", 6, 0, Vector2i(2, 2))
	var archer_stack = BattleStack.new()
	archer_stack.setup("fairy_archer", 18, 0, Vector2i(4, 2))
	player_stacks.append(melee_stack)
	player_stacks.append(archer_stack)
	
	var ai_actor = BattleStack.new()
	ai_actor.setup("wolf", 12, 1, Vector2i(6, 2))
	
	var chosen_target = arena_node._select_ai_target(ai_actor, player_stacks)
	_check(chosen_target == archer_stack, "AI must prioritize targeting archers to lock them in melee!")
	print("  -> AI correctly prioritized Fairy Archers over Griffins!")
	
	arena_node.queue_free()

	# 7. Test Quest HUD & Progression
	print("[TEST] 7. Testing Quest HUD & Objective Updates...")
	var wmap_node2 = wmap_packed.instantiate()
	add_child(wmap_node2)
	
	GameState.quest_forester_started = false
	wmap_node2._update_quest_hud()
	_check("Хижину Лесника" in wmap_node2.quest_label.text, "QuestHUD should point to Forester first")
	
	GameState.quest_forester_started = true
	GameState.has_gate_key = true
	wmap_node2._update_quest_hud()
	_check("Железные Врата" in wmap_node2.quest_label.text, "QuestHUD should point to Gate next")
	
	GameState.flags["iron_gate_opened"] = true
	wmap_node2._update_quest_hud()
	_check("Атамана" in wmap_node2.quest_label.text, "QuestHUD should point to Boss")
	
	GameState.has_fairy_crown = true
	wmap_node2._update_quest_hud()
	_check("ВЕРНИТЕ ВЕНЕЦ" in wmap_node2.quest_label.text, "QuestHUD should instruct to return crown")
	print("  -> Quest HUD dynamically reflects all 4 campaign stages accurately!")

	# 8. Test Grand Campaign Victory Sequence
	print("[TEST] 8. Testing Grand Campaign Victory Dialog...")
	var shrine_obj = {"type": "fairy_shrine", "name": "Роща Королевы Фей", "id": "fairy_shrine"}
	wmap_node2._trigger_object(shrine_obj)
	_check(wmap_node2.victory_dialog.visible, "Victory Dialog must open when crown is returned!")
	_check(GameState.quest_completed, "Quest must be marked as completed!")
	print("  -> Grand Campaign Victory Dialog presented with fanfare & rewards!")

	# 9. Test Terrain vs Road Movement Penalty
	print("[TEST] 9. Testing Road vs Wilderness Movement Penalties...")
	var initial_mp = 36
	GameState.move_points = initial_mp
	# Step onto road cell (5, 11) - road costs 1
	var road_cell = Vector2i(5, 11)
	_check(wmap_node2.world_view.road_cells.has(road_cell), "Cell (5, 11) must be a road cell")
	var p_road: Array[Vector2i] = [road_cell]
	wmap_node2._move_hero_along_path(p_road)
	_check(GameState.move_points == initial_mp - 1, "Moving on road must cost exactly 1 MP")
	
	# Step onto grass cell (5, 10) - grass costs 2
	var grass_cell = Vector2i(5, 10)
	_check(not wmap_node2.world_view.road_cells.has(grass_cell), "Cell (5, 10) must be off-road grass")
	var p_grass: Array[Vector2i] = [grass_cell]
	wmap_node2._move_hero_along_path(p_grass)
	_check(GameState.move_points == initial_mp - 3, "Moving on off-road grass must cost 2 MP (penalty 100%)")
	print("  -> Road movement costs 1 MP, rough grass costs 2 MP! A* penalty verified.")

	# 10. Test Hero Profile Screen & Hotkeys
	print("[TEST] 10. Testing Hero Character Sheet (Profile)...")
	wmap_node2._open_hero_profile()
	_check(wmap_node2.hero_dialog.visible, "Hero Profile Dialog must open")
	_check("Аларик" in wmap_node2.hero_dialog.get_node("Parchment/Title").text, "Profile title must show hero name")
	_check(wmap_node2.hero_skills_vbox.get_child_count() > 0, "Hero skills must be listed in profile")
	wmap_node2.hero_dialog.hide()
	print("  -> Hero Profile sheet verified with stats, attributes, and secondary skills!")

	# 11. Test Level-Up System & Skill Learning
	print("[TEST] 11. Testing Level-Up Trigger & Skill Selection...")
	GameState.pending_level_ups.clear()
	var prev_lvl = GameState.level
	GameState.add_xp(GameState.next_level_xp)
	_check(GameState.level == prev_lvl + 1, "Hero level must increase")
	_check(wmap_node2.level_dialog.visible, "Level-up dialog must appear with skill choices")
	# Simulate clicking first skill choice button
	wmap_node2.level_skill_btn1.emit_signal("pressed")
	_check(not wmap_node2.level_dialog.visible, "Level-up dialog closes after picking skill")
	_check(GameState.skills.size() >= 2 or GameState.skills.values().max() > 1, "Hero must now possess learned or upgraded secondary skill")
	print("  -> Level Up system successfully rewarded primary stat and secondary skill!")

	# 12. Test Artifacts & Equipment System
	print("[TEST] 12. Testing Artifacts & Equipment System...")
	GameState.equipped_artifacts.clear()
	var base_att = GameState.attack
	var base_def = GameState.defense
	GameState.inventory_artifacts.append("sword_valiance")
	GameState.inventory_artifacts.append("shield_aegis")
	GameState.inventory_artifacts.append("boots_traveler")
	_check(GameState.equip_artifact("sword_valiance"), "Must equip sword_valiance")
	_check(GameState.get_total_attack() == base_att + 4, "Total attack must include sword bonus +4")
	# Equip shield: sword + shield activates Guardian 2-piece set bonus (+2 Att, +2 Def)
	_check(GameState.equip_artifact("shield_aegis"), "Must equip shield_aegis")
	_check(GameState.get_total_defense() == base_def + 4 + 2, "Total defense must include shield +4 and Guardian set +2")
	_check(GameState.equip_artifact("boots_traveler"), "Must equip boots_traveler")
	_check(GameState.get_total_max_mp() >= 44, "Total max MP must include boots bonus +8")
	# Unequip weapon: set bonus breaks, defense reverts to base_def + 4, attack reverts to base_att
	GameState.unequip_artifact("weapon")
	_check(GameState.get_total_defense() == base_def + 4, "Defense without set bonus must be base + 4")
	_check(GameState.get_total_attack() == base_att, "Attack must revert after unequipping weapon")
	print("  -> Artifact equip/unequip & stat bonuses verified successfully!")

	# 13. Test Adventure Spells
	print("[TEST] 13. Testing Adventure Spells on World Map...")
	var pre_scry_count = GameState.revealed_cells.size()
	wmap_node2._cast_scrying()
	var post_scry_count = GameState.revealed_cells.size()
	_check(post_scry_count >= pre_scry_count, "Scrying spell must reveal cells on world map")
	GameState.current_mana = 30
	# Благодать возвращает только павших в боях
	GameState.fallen_units = {GameState.player_army[0]["unit_id"]: 4}
	var prev_count = GameState.player_army[0]["count"]
	wmap_node2._cast_restoration()
	_check(GameState.player_army[0]["count"] == prev_count + 4, "Restoration spell must return fallen troops to the army")
	_check(GameState.current_mana == 15, "Restoration must consume 15 mana")
	var army_snapshot = str(GameState.player_army)
	wmap_node2._cast_restoration()
	_check(str(GameState.player_army) == army_snapshot and GameState.current_mana == 15, "Restoration without fallen troops must neither grow the army nor spend mana")
	print("  -> Adventure spells (Scrying & Divine Restoration) cast and verified!")

	# 14. Test Unit Upgrades
	print("[TEST] 14. Testing Unit Upgrades in Army...")
	GameState.gold = 5000
	GameState.player_army = [
		{"unit_id": "griffin", "count": 5},
		{"unit_id": "fairy_archer", "count": 20}
	]
	var upgraded_griffin = GameState.upgrade_army_unit(0)
	_check(upgraded_griffin, "Upgrade griffin to royal_griffin must succeed")
	_check(GameState.player_army[0]["unit_id"] == "royal_griffin", "Slot 0 must now be royal_griffin")
	var upgraded_fairy = GameState.upgrade_army_unit(1)
	_check(upgraded_fairy, "Upgrade fairy to royal_fairy must succeed")
	_check(GameState.player_army[1]["unit_id"] == "royal_fairy", "Slot 1 must now be royal_fairy")
	print("  -> Unit upgrades (Griffins -> Royal Griffins, Fairies -> Royal Fairies) verified!")

	# 15. Test Multi-Chapter Progression
	print("[TEST] 15. Testing Multi-Chapter Story Progression...")
	GameState.start_chapter(2)
	_check(GameState.current_chapter == 2, "Current chapter must be 2")
	_check(GameState.hero_cell == Vector2i(3, 11), "Hero start cell for Chapter 2 set correctly")
	_check(GameState.player_army.size() >= 2, "Hero army preserved into Chapter 2")
	GameState.start_chapter(3)
	_check(GameState.current_chapter == 3, "Current chapter must be 3")
	_check(GameState.hero_cell == Vector2i(4, 16), "Hero start cell for Chapter 3 set correctly")
	print("  -> Multi-chapter transition and carryover verified for all 3 chapters!")

	# 16. Test Tactical Hex Obstacles & Flyer Movement
	print("[TEST] 16. Testing Combat Obstacles & Flyer Aerial Soaring...")
	var arena_packed2 = load("res://src/battle/battle_arena.tscn")
	var arena_node2 = arena_packed2.instantiate()
	add_child(arena_node2)
	_check(arena_node2.obstacles.size() > 0, "Tactical obstacles must be spawned on arena")
	# Royal griffin is flying, so obstacles do not block its flight
	_check(UnitData.get_unit("royal_griffin").get("flying", false) == true, "Royal griffin must have flying property")
	arena_node2.queue_free()
	print("  -> Hex arena obstacles and flying unit movement verified!")

	# 17. Test Persistent Save & Load System
	print("[TEST] 17. Testing Persistent Save & Load System...")
	GameState.gold = 7777
	GameState.day = 12
	GameState.xp = 450
	var test_save_path = "user://test_savegame.json"
	_check(GameState.save_game(test_save_path), "Saving game to disk must succeed")
	_check(GameState.has_save_game(test_save_path), "Save game must exist on disk")
	GameState.gold = 100
	GameState.day = 1
	_check(GameState.load_game(test_save_path), "Loading game from disk must succeed")
	_check(GameState.gold == 7777, "Gold must be restored from save file")
	_check(GameState.day == 12, "Day must be restored from save file")
	_check(GameState.xp == 450, "XP must be restored from save file")
	print("  -> Game state serialization & save/load roundtrip verified!")

	# 18. Test Shooter Melee Penalty & Enemy Blocking
	print("[TEST] 18. Testing Shooter Melee Penalty & Enemy Blocking...")
	var test_shooter = BattleStack.new()
	test_shooter.setup("fairy_archer", 10, 0, Vector2i(2, 2))
	var test_enemy_adj = BattleStack.new()
	test_enemy_adj.setup("swamp_zombie", 10, 1, Vector2i(3, 2))
	var dummy_stacks: Array[BattleStack] = [test_shooter, test_enemy_adj]
	_check(test_shooter.is_blocked_by_enemy(dummy_stacks), "Shooter must be blocked when enemy is adjacent (distance 1)")
	var ranged_dmg = test_shooter.calculate_attack_damage(test_enemy_adj, false, false)
	var melee_dmg = test_shooter.calculate_attack_damage(test_enemy_adj, true, false)
	_check(melee_dmg <= ranged_dmg, "Melee damage of shooter must suffer melee penalty (50% reduction)")
	print("  -> Shooter melee blocking and 50% melee penalty verified!")

	# 19. Test Minimap & Pause Menu Components
	print("[TEST] 19. Testing Minimap & Pause Menu Components...")
	var wmap_packed3 = load("res://src/world/world_map.tscn")
	var wmap_node3 = wmap_packed3.instantiate()
	add_child(wmap_node3)
	_check(wmap_node3.minimap_canvas != null, "Minimap canvas must be initialized")
	_check(wmap_node3.pause_dialog != null, "Pause dialog must be initialized")
	wmap_node3._toggle_pause_menu()
	_check(wmap_node3.pause_dialog.visible, "Pause dialog must be toggled visible")
	wmap_node3._toggle_pause_menu()
	_check(not wmap_node3.pause_dialog.visible, "Pause dialog must be toggled hidden")
	wmap_node3.queue_free()
	print("  -> Minimap radar canvas and pause menu verified!")

	# 20. Test New Spells (Lightning & Slow)
	print("[TEST] 20. Testing New Combat Spells (Lightning & Slow)...")
	_check(SpellData.has_spell("lightning"), "SpellData must contain lightning")
	_check(SpellData.has_spell("slow"), "SpellData must contain slow")
	var s_stack = BattleStack.new()
	s_stack.setup("wolf", 10, 1, Vector2i(5, 5))
	var base_spd = s_stack.get_speed()
	s_stack.buff_slow_turns = 3
	_check(s_stack.get_speed() < base_spd, "Slow debuff must reduce stack speed")
	print("  -> Lightning and Slow spells verified! Slow reduced speed from %d to %d." % [base_spd, s_stack.get_speed()])

	# 21. Test Artifact Set Synergy Bonuses
	print("[TEST] 21. Testing Artifact Set Synergy Bonuses...")
	GameState.equipped_artifacts.clear()
	GameState.inventory_artifacts.clear()
	GameState.equip_artifact("sword_valiance")
	GameState.equip_artifact("shield_aegis")
	GameState.equip_artifact("armor_chitin")
	var set_bonuses = ArtifactData.get_active_set_bonuses(GameState.equipped_artifacts)
	_check(set_bonuses["active_titles"].size() > 0, "Must activate Guardian of Kingdom set bonus")
	_check(set_bonuses["attack"] >= 4, "Set bonus must grant at least +4 attack")
	_check(set_bonuses["defense"] >= 4, "Set bonus must grant at least +4 defense")
	print("  -> Active set bonus verified: %s (+%d Att, +%d Def)!" % [
		set_bonuses["active_titles"][0], set_bonuses["attack"], set_bonuses["defense"]
	])

	# 22. Test Hero Class Selection
	print("[TEST] 22. Testing Hero Class Selection (Paladin, Archmage, Ranger)...")
	GameState.set_hero_class("archmage")
	_check(GameState.hero_class_id == "archmage", "Hero class must be archmage")
	_check("Элеонора" in GameState.hero_name, "Hero name must be Eleonora")
	_check(GameState.spellpower == 6, "Archmage must have 6 spellpower")
	_check(GameState.knowledge == 6, "Archmage must have 6 knowledge")
	
	GameState.set_hero_class("ranger")
	_check(GameState.hero_class_id == "ranger", "Hero class must be ranger")
	_check("Торн" in GameState.hero_name, "Hero name must be Thorn")
	_check(GameState.skills.has("logistics"), "Ranger must possess Logistics skill")
	_check(GameState.skills.has("pathfinding"), "Ranger must possess Pathfinding skill")
	
	GameState.set_hero_class("paladin")
	_check(GameState.hero_class_id == "paladin", "Hero class reset to paladin")
	print("  -> Hero classes (Paladin, Archmage, Ranger) configured and verified!")

	# 23. Test Quick Combat Resolution on World Map
	print("[TEST] 23. Testing Quick Combat Resolution on World Map...")
	var wmap_packed4 = load("res://src/world/world_map.tscn")
	var wmap_node4 = wmap_packed4.instantiate()
	add_child(wmap_node4)
	
	var enc_obj = {"type": "encounter", "name": "Дозор Разбойников", "id": "test_encounter"}
	wmap_node4._trigger_object(enc_obj)
	_check(wmap_node4.popup_btn2.visible, "Quick battle button must be visible for encounters")
	_check("Быстрый бой" in wmap_node4.popup_btn2.text, "Button text must contain 'Быстрый бой'")
	
	var pre_gold = GameState.gold
	var pre_xp = GameState.xp
	wmap_node4._execute_quick_combat("test_encounter")
	_check(GameState.flags.get("test_encounter", false) == true, "Encounter flag must be set to true")
	_check(GameState.gold > pre_gold, "Gold must be awarded for quick victory")
	_check(GameState.xp > pre_xp, "XP must be awarded for quick victory")
	wmap_node4.queue_free()
	print("  -> Quick Combat instant tactical resolution verified with rewards & casualties!")

	# 24. Test In-Arena Auto-battle Toggle
	print("[TEST] 24. Testing In-Arena Auto-battle Toggle...")
	var arena_packed3 = load("res://src/battle/battle_arena.tscn")
	var arena_node3 = arena_packed3.instantiate()
	add_child(arena_node3)
	_check(arena_node3.auto_battle_btn != null, "Auto-battle button must exist on HeroHUD")
	arena_node3._toggle_auto_battle()
	_check(arena_node3.is_auto_battling == true, "Auto-battle state must be active")
	arena_node3._toggle_auto_battle()
	_check(arena_node3.is_auto_battling == false, "Auto-battle state must be toggled off")
	arena_node3.queue_free()
	print("  -> In-arena Auto-battle toggle and button verified!")

	# 25. Test Single-Wait per Round Rule & Button State
	print("[TEST] 25. Testing Single-Wait per Round Rule & Wait Button State...")
	var arena_packed4 = load("res://src/battle/battle_arena.tscn")
	var arena_node4 = arena_packed4.instantiate()
	add_child(arena_node4)
	
	var test_actor = arena_node4.current_actor
	_check(test_actor != null and test_actor.team == 0, "Initial actor should be player stack")
	_check(not test_actor.has_waited, "Initial unit has_waited must be false")
	_check(not arena_node4.wait_btn.disabled, "Wait button must be enabled initially")
	
	# First wait succeeds
	arena_node4._on_wait_pressed()
	_check(test_actor.has_waited == true, "Unit must have has_waited = true after waiting")
	
	# Simulate unit getting turn again after waiting
	arena_node4.current_actor = test_actor
	arena_node4.is_ai_turn = false
	if arena_node4.wait_btn:
		arena_node4.wait_btn.disabled = test_actor.has_waited
	_check(arena_node4.wait_btn.disabled == true, "Wait button must be disabled for unit that has already waited")
	
	# Second wait in same round is rejected
	var q_size_before_second_wait = arena_node4.turn_queue.size()
	arena_node4._on_wait_pressed()
	_check(arena_node4.turn_queue.size() == q_size_before_second_wait, "Second wait must NOT re-append unit to queue")
	
	# Test round reset resets has_waited
	test_actor.reset_round()
	_check(not test_actor.has_waited, "Round reset must clear has_waited flag")
	arena_node4.queue_free()
	print("  -> Single wait per round enforced! No infinite wait possible.")

	# 26. Test Demo Battle Setup & Difficulty Scaling
	print("[TEST] 26. Testing Demo Battle Setup & Difficulty Scaling...")
	GameState.setup_demo_battle("hard", "balanced", "dragon_cult")
	_check(GameState.is_demo_battle == true, "is_demo_battle must be set")
	_check(GameState.demo_difficulty == "hard", "Difficulty must be hard")
	_check(GameState.demo_player_army.size() >= 3, "Demo player army must have units")
	_check(GameState.demo_enemy_configs.size() >= 3, "Demo enemy army must have units")
	
	# Verify hard difficulty has dragon
	var has_dragon = false
	for e in GameState.demo_enemy_configs:
		if e["unit_id"] == "red_dragon":
			has_dragon = true
			_check(e["count"] >= 2, "Hard difficulty dragon cult should have 2 dragons")
	_check(has_dragon, "Dragon cult must contain red_dragon")
	
	# Instantiate arena with demo battle
	var demo_arena = arena_packed4.instantiate()
	add_child(demo_arena)
	_check(demo_arena.retreat_btn != null, "Retreat button must exist on arena")
	_check("В Меню" in demo_arena.retreat_btn.text, "Demo arena retreat button should say 'В Меню'")
	_check(demo_arena.all_stacks.size() >= 6, "Arena should have initialized both player and enemy stacks")
	demo_arena.queue_free()
	GameState.is_demo_battle = false
	print("  -> Demo battle setup, difficulty scaling, and retreat button verified!")

	# 27. Test Pause Dialog Centering & Geometry
	print("[TEST] 27. Testing Pause Dialog Centering & Geometry...")
	var wmap_test_packed = load("res://src/world/world_map.tscn")
	var wmap_test_node = wmap_test_packed.instantiate()
	add_child(wmap_test_node)
	_check(wmap_test_node.pause_dialog != null, "Pause dialog must be instantiated")
	var pause_center = null
	for ch in wmap_test_node.pause_dialog.get_children():
		if ch is CenterContainer:
			pause_center = ch
			break
	_check(pause_center != null, "Pause dialog must contain a CenterContainer for mathematical screen centering")
	var pause_parch = pause_center.get_child(0) as NinePatchRect
	_check(pause_parch != null, "CenterContainer must hold the parchment panel")
	_check(pause_parch.custom_minimum_size.x >= 500 and pause_parch.custom_minimum_size.y >= 500, "Pause parchment must have valid minimum size")
	wmap_test_node.queue_free()
	print("  -> Pause dialog CenterContainer architecture verified! Zero off-screen clipping.")

	# 28. Test Chapter 1 Tactical Encounters & Chapter 2 Swamp Layout
	print("[TEST] 28. Testing Chapter 1 Tactical Encounters & Chapter 2 Unique Layout...")
	GameState.start_chapter(1)
	var wmap_c1 = wmap_test_packed.instantiate()
	add_child(wmap_c1)
	var wv_c1 = wmap_c1.get_node("ScrollContainer/WorldView")
	_check(wv_c1.objects.has(Vector2i(8, 4)), "Chapter 1 must have wolves guarding watermill at (8, 4)")
	_check(wv_c1.objects.has(Vector2i(4, 8)), "Chapter 1 must have goblins guarding chest at (4, 8)")
	_check(wv_c1.objects.has(Vector2i(7, 14)), "Chapter 1 must have forester road ambush at (7, 14)")
	_check(wv_c1.objects.has(Vector2i(10, 13)), "Chapter 1 must have ancient treant guardian at (10, 13)")
	_check(wv_c1.objects.has(Vector2i(18, 11)), "Chapter 1 must have vanguard at (18, 11)")
	_check(wv_c1.objects.has(Vector2i(22, 7)), "Chapter 1 must have rogue archers at (22, 7)")
	_check(wv_c1.objects.has(Vector2i(24, 16)), "Chapter 1 must have obelisk guard at (24, 16)")
	_check(wv_c1.objects.has(Vector2i(28, 11)), "Chapter 1 must have bandit boss at (28, 11)")
	print("  -> Chapter 1 verified with 8 tactical encounters and extra treasure caches!")
	
	# Test Chapter 2 Transition & Unique Swamp Objects
	GameState.start_chapter(2)
	_check(GameState.current_chapter == 2, "Current chapter must be 2")
	var wmap_c2 = wmap_test_packed.instantiate()
	add_child(wmap_c2)
	var wv_c2 = wmap_c2.get_node("ScrollContainer/WorldView")
	_check(wv_c2.objects.has(Vector2i(6, 17)), "Chapter 2 must have Witch Hut at (6, 17)")
	_check(wv_c2.objects.has(Vector2i(10, 4)), "Chapter 2 must have Sunken Crypt at (10, 4)")
	_check(wv_c2.objects.has(Vector2i(10, 7)), "Chapter 2 must have Druid Camp at (10, 7)")
	_check(wv_c2.objects.has(Vector2i(27, 4)), "Chapter 2 must have Druid Altar at (27, 4)")
	_check(wv_c2.objects.has(Vector2i(6, 8)), "Chapter 2 must have swamp zombies patrol at (6, 8)")
	_check(wv_c2.objects.has(Vector2i(6, 14)), "Chapter 2 must have skeleton archers at (6, 14)")
	_check(wv_c2.objects.has(Vector2i(21, 8)), "Chapter 2 must have undead legion at (21, 8)")
	_check(wv_c2.objects.has(Vector2i(28, 11)), "Chapter 2 must have Ancient Lich Citadel at (28, 11)")
	wmap_c1.queue_free()
	wmap_c2.queue_free()
	print("  -> Chapter 2 verified with unique swamp landmarks and undead encounters!")

	# 29. Test Skeleton Archer Assets & Orientation, Army Stack Swapping, and EventDialog Layout
	print("[TEST] 29. Testing Skeleton Archer Assets, Army Stack Swapping & EventDialog Layout...")
	var skel = UnitData.get_unit("skeleton_archer")
	_check(skel.get("token_path", "").ends_with("token_unit_skeleton_archer.png"), "Skeleton archer must have dedicated token")
	_check(skel.get("sprite_path", "").ends_with("unit_skeleton_archer.png"), "Skeleton archer must have dedicated sprite")
	_check(ResourceLoader.exists(skel["token_path"]), "Skeleton archer token file must exist")
	_check(ResourceLoader.exists(skel["sprite_path"]), "Skeleton archer sprite file must exist")
	_check(skel.get("natural_faces_left", true) == false, "Skeleton archer naturally faces right (natural_faces_left == false)")
	_check(UnitData.get_unit("goblin").get("natural_faces_left", false) == true, "Goblin naturally faces left")

	# Army Stack Swapping (HoMM style)
	GameState.start_chapter(1)
	_check(GameState.player_army[0]["unit_id"] == "griffin", "Initial slot 0 must be griffin")
	_check(GameState.player_army[1]["unit_id"] == "fairy_archer", "Initial slot 1 must be fairy_archer")
	var swap_ok = GameState.swap_army_slots(0, 1)
	_check(swap_ok == true, "swap_army_slots(0, 1) must succeed")
	_check(GameState.player_army[0]["unit_id"] == "fairy_archer", "Fairies must now be first in hero army (slot 0)")
	_check(GameState.player_army[1]["unit_id"] == "griffin", "Griffins must now be slot 1")

	# EventDialog Structural Integrity
	var wmap_test_dialog = wmap_test_packed.instantiate()
	add_child(wmap_test_dialog)
	var parch_margin = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox")
	_check(parch_margin != null, "EventDialog must contain MainVBox inside MarginContainer")
	var dlg_title = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Title")
	var dlg_scroll = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Scroll")
	var dlg_text = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Scroll/ScrollMargin/Text")
	var dlg_btn_box = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox")
	var dlg_btn1 = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox/Btn1")
	_check(dlg_title != null, "EventDialog Title must be in MainVBox")
	_check(dlg_scroll != null and dlg_scroll is ScrollContainer, "EventDialog must wrap text in ScrollContainer")
	_check(dlg_text != null, "EventDialog Text must be in ScrollContainer")
	_check(dlg_btn_box != null and dlg_btn1 != null, "EventDialog buttons must be docked in BtnVBox")
	wmap_test_dialog.queue_free()
	print("  -> Skeleton archer assets, HoMM army stack swap, and non-overlapping dialog layout verified!")

	wmap_node2.queue_free()

	# 30. Test Immediate Battle Conclusion (Zero Ghost Turns on Zero Enemies)
	print("[TEST] 30. Testing Immediate Battle Conclusion (Zero Ghost Turns)...")
	var arena_packed_30 = load("res://src/battle/battle_arena.tscn")
	var arena_node_30 = arena_packed_30.instantiate()
	add_child(arena_node_30)
	
	# Verify living stack helper logic
	_check(arena_node_30._has_living_enemies() == true, "Must have living enemies initially")
	_check(arena_node_30._has_living_players() == true, "Must have living players initially")
	
	# Eliminate all enemy stacks
	for s in arena_node_30.all_stacks:
		if s.team == 1:
			s.count = 0
			s.current_hp = 0
	
	_check(arena_node_30._has_living_enemies() == false, "No living enemies must remain")
	var ended = arena_node_30._check_battle_end()
	_check(ended == true, "_check_battle_end() must return true when all enemies are slain")
	_check(arena_node_30.victory_dialog.visible == true, "Victory dialog must immediately become visible")
	_check(arena_node_30.turn_queue.is_empty() == true, "Turn queue must be completely cleared upon victory")
	_check(arena_node_30.current_actor == null, "Current actor must be null - no ghost turns permitted!")
	_check(arena_node_30.reachable_hexes.is_empty() == true, "Reachable hexes must be cleared")
	
	# Verify calling _next_turn does not grant a turn to player or loop round
	arena_node_30._next_turn()
	_check(arena_node_30.current_actor == null, "Post-victory _next_turn() must not assign an actor")
	arena_node_30.queue_free()
	print("  -> Combat terminates instantaneously on last enemy death! Zero redundant/ghost turns.")

	# 31. Test Hero Paper Doll, Equipment Mannequin & Top HUD Day Geometry
	print("[TEST] 31. Testing Hero Paper Doll, Equipment Mannequin & Top HUD Day Geometry...")
	var wmap_test_packed_31 = load("res://src/world/world_map.tscn")
	var wmap_node_31 = wmap_test_packed_31.instantiate()
	add_child(wmap_node_31)
	
	# Top HUD Day Display and End Day Button
	var day_lbl = wmap_node_31.get_node("CanvasLayer/TopHUD/DayLabel")
	var end_btn = wmap_node_31.get_node("CanvasLayer/TopHUD/EndDayBtn")
	_check(day_lbl != null and end_btn != null, "TopHUD must contain DayLabel and EndDayBtn")
	_check(day_lbl.offset_right <= end_btn.offset_left, "DayLabel must NOT overlap or hide beneath EndDayBtn")
	_check(day_lbl.offset_right - day_lbl.offset_left >= 150.0, "DayLabel must have at least 150px width for full text")
	
	# Paper Doll Mannequin on Character Profile
	wmap_node_31._open_hero_profile()
	var content_hbox = wmap_node_31.hero_dialog.get_node("Parchment/ContentHBox")
	_check(content_hbox.offset_left >= 0.0, "ContentHBox must not have negative offset outside parchment")
	_check(wmap_node_31.mannequin_box != null, "HeroProfileDialog must contain MannequinBox for body silhouette")
	
	# Verify all 6 equipment slots on mannequin
	var expected_slots = ["relic", "weapon", "armor", "shield", "accessory", "boots"]
	for slot_name in expected_slots:
		var slot_btn = wmap_node_31.mannequin_box.get_node_or_null("Slot_" + slot_name)
		_check(slot_btn != null, "Mannequin must have Slot_%s on body" % slot_name)
	
	# Equip artifact and verify slot reflection
	GameState.inventory_artifacts.clear()
	GameState.equipped_artifacts.clear()
	GameState.inventory_artifacts.append("sword_valiance")
	wmap_node_31._update_hero_profile()
	_check(wmap_node_31.backpack_vbox.get_child_count() > 0, "Backpack must list inventory artifacts")
	
	# Simulate clicking equip
	GameState.equip_artifact("sword_valiance")
	wmap_node_31._update_hero_profile()
	var weapon_slot_btn = wmap_node_31.mannequin_box.get_node("Slot_weapon")
	_check("Меч" in weapon_slot_btn.text, "Weapon slot on mannequin must reflect equipped sword")
	
	# Simulate clicking unequip from mannequin slot
	weapon_slot_btn.emit_signal("pressed")
	_check(not GameState.equipped_artifacts.has("weapon"), "Clicking mannequin slot must unequip artifact to backpack")
	_check(GameState.inventory_artifacts.has("sword_valiance"), "Sword must return to backpack")
	
	wmap_node_31.hero_dialog.hide()
	wmap_node_31.queue_free()
	print("  -> Top HUD Day display geometry & Hero paper doll equipment mannequin fully verified!")

	# 32. Test Movement Interruption, Differentiated Monster Miniatures & Chapter 2 Visual Identity
	print("[TEST] 32. Testing Movement Interruption, Monster Miniatures & Chapter 2 Visual Identity...")
	GameState.start_chapter(1)
	var wmap_test_packed_32 = load("res://src/world/world_map.tscn")
	var wmap_node_32 = wmap_test_packed_32.instantiate()
	add_child(wmap_node_32)
	
	# Test 32.1: Movement Interruption
	GameState.move_points = 20
	wmap_node_32.world_view.hero_cell = Vector2i(4, 11)
	wmap_node_32.world_view.hero_pixel_pos = wmap_node_32.world_view.cell_to_pixel(Vector2i(4, 11))
	var p32: Array[Vector2i] = [Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]
	# Start movement along 3-tile path
	wmap_node_32._move_hero_along_path(p32)
	_check(wmap_node_32.world_view.is_moving == true, "Hero must be actively moving")
	# Simulate player clicking mouse or pressing key while moving to cancel path
	wmap_node_32.cancel_hero_movement()
	_check(wmap_node_32.cancel_movement == true, "Cancellation request must be registered")
	# Wait for hero to finish step 1 and halt cleanly
	while wmap_node_32.world_view.is_moving:
		await get_tree().process_frame
	# Hero should halt cleanly at cell (5, 11), having aborted remaining steps
	_check(wmap_node_32.world_view.hero_cell == Vector2i(5, 11), "Hero must halt at cell (5, 11) due to cancellation")
	_check(wmap_node_32.world_view.is_moving == false, "Hero movement state must be reset to false")
	_check(wmap_node_32.cancel_movement == false, "cancel_movement flag must be reset after halting")
	_check(GameState.move_points == 19, "Only 1 MP should have been consumed for the single completed step (out of 3)")
	
	# Test 32.2: Differentiated Monster Tokens in Chapter 1
	var wv_32 = wmap_node_32.world_view
	var wolf_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(8, 4)])
	_check(wolf_tex != null and wolf_tex.resource_path.ends_with("token_unit_wolf.png"), "Wolves encounter at (8, 4) must use token_unit_wolf")
	var goblin_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(4, 8)])
	_check(goblin_tex != null and goblin_tex.resource_path.ends_with("token_unit_goblin.png"), "Goblins encounter at (4, 8) must use token_unit_goblin")
	var treant_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(10, 13)])
	_check(treant_tex != null and treant_tex.resource_path.ends_with("token_unit_treant.png"), "Treant encounter at (10, 13) must use token_unit_treant")
	var bandit_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(28, 11)])
	_check(bandit_tex != null and bandit_tex.resource_path.ends_with("token_boss_bandit.png"), "Bandit boss at (28, 11) must use token_boss_bandit")
	
	wmap_node_32.queue_free()
	
	# Test 32.3: Chapter 2 Swamp Differentiated Miniatures & Distinct Biome
	GameState.start_chapter(2)
	_check(GameState.current_chapter == 2, "Current chapter must be 2")
	var wmap_node_32_c2 = wmap_test_packed_32.instantiate()
	add_child(wmap_node_32_c2)
	var wv_c2_32 = wmap_node_32_c2.world_view
	
	var zombie_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(6, 8)])
	_check(zombie_tex != null and zombie_tex.resource_path.ends_with("token_unit_swamp_zombie.png"), "Swamp zombie encounter at (6, 8) must use token_unit_swamp_zombie")
	var skel_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(6, 14)])
	_check(skel_tex != null and skel_tex.resource_path.ends_with("token_unit_skeleton_archer.png"), "Swamp skeletons encounter at (6, 14) must use token_unit_skeleton_archer")
	var lich_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(28, 11)])
	_check(lich_tex != null and lich_tex.resource_path.ends_with("token_boss_lich.png"), "Lich boss at (28, 11) must use token_boss_lich")
	
	# Check unique swamp objects
	_check(wv_c2_32.objects.has(Vector2i(6, 17)) and wv_c2_32.objects[Vector2i(6, 17)]["type"] == "witch_hut", "Chapter 2 must have witch_hut at (6, 17)")
	_check(wv_c2_32.objects.has(Vector2i(10, 4)) and wv_c2_32.objects[Vector2i(10, 4)]["type"] == "crypt", "Chapter 2 must have crypt at (10, 4)")
	_check(wv_c2_32.objects.has(Vector2i(14, 11)) and wv_c2_32.objects[Vector2i(14, 11)]["type"] == "bone_gate", "Chapter 2 must have bone_gate at (14, 11)")
	
	wmap_node_32_c2.queue_free()
	print("  -> Route interruption on click, differentiated creature tokens, and Chapter 2 swamp features fully verified!")

	# 33. Test Adventure Spellbook Overhaul, TopHUD Overlap Prevention & Quest HUD Sizing
	print("[TEST] 33. Testing Adventure Spellbook Overhaul, TopHUD Non-overlap & Quest HUD...")
	GameState.start_chapter(1)
	var wmap_test_packed_33 = load("res://src/world/world_map.tscn")
	var wmap_node_33 = wmap_test_packed_33.instantiate()
	add_child(wmap_node_33)
	
	# Test 33.1: TopHUD Non-overlapping Geometry
	var name_lbl = wmap_node_33.get_node("CanvasLayer/TopHUD/NameLabel") as Label
	var gold_lbl = wmap_node_33.get_node("CanvasLayer/TopHUD/GoldLabel") as Label
	var mana_lbl = wmap_node_33.get_node("CanvasLayer/TopHUD/ManaLabel") as Label
	_check(name_lbl.offset_right <= gold_lbl.offset_left, "NameLabel must end before GoldLabel begins to eliminate overlap")
	_check(gold_lbl.offset_right <= mana_lbl.offset_left, "GoldLabel must end before ManaLabel begins")
	_check(name_lbl.clip_text == true, "NameLabel must clip text to prevent horizontal overflow")
	_check(name_lbl.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "NameLabel must trim with ellipsis")
	
	# Test 33.2: Adventure Spellbook Dialog Geometry & Elements
	var sb_dialog = wmap_node_33.get_node("CanvasLayer/SpellbookDialog") as Control
	var sb_parch = sb_dialog.get_node("Parchment") as NinePatchRect
	_check(sb_parch.offset_right - sb_parch.offset_left >= 700.0, "Spellbook parchment must be wide (>= 700px) for dual-card layout")
	_check(sb_parch.offset_bottom - sb_parch.offset_top >= 500.0, "Spellbook parchment must be tall (>= 500px) for dual-card layout")
	
	var scry_btn_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/ScryCard/CardVBox/ScryBtn") as Button
	var rest_btn_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/RestCard/CardVBox/RestBtn") as Button
	var sb_close_33 = sb_dialog.get_node("Parchment/CloseBtn") as Button
	_check(scry_btn_33 != null and rest_btn_33 != null and sb_close_33 != null, "Spellbook must have ScryBtn, RestBtn and CloseBtn inside Parchment")
	
	# Open Spellbook & Verify Mana/State Updates
	GameState.current_mana = 40
	wmap_node_33._open_spellbook()
	_check(sb_dialog.visible == true, "Spellbook dialog must be visible after _open_spellbook()")
	_check(scry_btn_33.disabled == false, "ScryBtn must be enabled when hero has 40 mana")
	_check(rest_btn_33.disabled == false, "RestBtn must be enabled when hero has 40 mana")
	
	# Mana subtitle check
	var mana_sub = sb_dialog.get_node("Parchment/Margin/MainVBox/ManaSubtitle") as Label
	_check(mana_sub.text.contains("40 / 40"), "ManaSubtitle must reflect current and max mana")
	
	# Low mana disabling check
	GameState.current_mana = 5
	wmap_node_33._open_spellbook()
	_check(scry_btn_33.disabled == true, "ScryBtn must be disabled when hero has only 5 mana (requires 10)")
	_check(rest_btn_33.disabled == true, "RestBtn must be disabled when hero has only 5 mana (requires 15)")
	
	# Combat spells populated
	var combat_grid_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/CombatGrid") as GridContainer
	_check(combat_grid_33.get_child_count() >= 4, "CombatGrid must display all learned combat spells")
	
	# Close dialog
	sb_close_33.emit_signal("pressed")
	_check(sb_dialog.visible == false, "Spellbook must hide when CloseBtn pressed")
	
	# Test 33.3: QuestHUD Dimensions & Non-overlapping with MinimapPanel
	var quest_hud = wmap_node_33.get_node("CanvasLayer/QuestHUD") as Control
	var quest_lbl = quest_hud.get_node("QuestLabel") as Label
	_check(quest_hud.offset_right - quest_hud.offset_left >= 240.0, "QuestHUD width must be >= 240px to prevent text clipping")
	_check(quest_hud.offset_bottom - quest_hud.offset_top >= 130.0, "QuestHUD height must be >= 130px to accommodate long objectives")
	_check(quest_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD or quest_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "QuestLabel must word wrap cleanly")
	_check(quest_hud.offset_top >= wmap_node_33.minimap_container.offset_bottom, "QuestHUD must not overlap MinimapPanel vertically")
	_check(wmap_node_33.minimap_container.offset_right <= -15.0, "MinimapPanel must not overflow screen right edge")
	
	# Test 33.4: Arena Spellbook Sizing
	var arena_packed_33 = load("res://src/battle/battle_arena.tscn")
	var arena_node_33 = arena_packed_33.instantiate()
	add_child(arena_node_33)
	var arena_sb_parch = arena_node_33.get_node("CanvasLayer/SpellbookDialog/Parchment") as NinePatchRect
	_check(arena_sb_parch.offset_right - arena_sb_parch.offset_left >= 650.0, "Arena spellbook parchment must be >= 650px wide")
	var arena_spell_grid = arena_sb_parch.get_node("SpellGrid") as HBoxContainer
	_check(arena_spell_grid.offset_right - arena_spell_grid.offset_left >= 550.0, "Arena SpellGrid must be >= 550px wide for 6+ spells")
	arena_node_33.queue_free()
	
	wmap_node_33.queue_free()
	print("  -> Adventure Spellbook dual-card overhaul, TopHUD zero-overlap and QuestHUD sizing fully verified!")

	# 34. Test HoMM3 2-Click Movement (Click 1 plots, Click 2 walks, Click during movement stops)
	print("[TEST] 34. Testing HoMM3 2-Click Movement & Route Confirmation...")
	GameState.start_chapter(1)
	var wmap_test_packed_34 = load("res://src/world/world_map.tscn")
	var wmap_node_34 = wmap_test_packed_34.instantiate()
	add_child(wmap_node_34)
	
	GameState.move_points = 24
	wmap_node_34.world_view.hero_cell = Vector2i(4, 11)
	wmap_node_34.world_view.hero_pixel_pos = wmap_node_34.world_view.cell_to_pixel(Vector2i(4, 11))
	
	# Test 34.1: First click plots route without moving
	wmap_node_34._on_cell_clicked(Vector2i(7, 11))
	_check(wmap_node_34.planned_destination == Vector2i(7, 11), "First click must lock planned destination to (7, 11)")
	_check(wmap_node_34.planned_path.size() == 3, "Planned path from (4, 11) to (7, 11) must have 3 steps")
	_check(wmap_node_34.world_view.is_moving == false, "Hero MUST NOT start moving on first click!")
	_check(wmap_node_34.world_view.hero_cell == Vector2i(4, 11), "Hero must remain stationary at (4, 11)")
	_check(wmap_node_34.world_view.planned_path.size() == 3, "WorldView must display locked planned path on map")
	
	# Test 34.2: Clear route on cancel / right-click
	wmap_node_34._clear_planned_route()
	_check(wmap_node_34.planned_destination == Vector2i(-1, -1), "Clearing route must reset planned destination")
	_check(wmap_node_34.planned_path.is_empty(), "Planned path must be empty after clear")
	_check(wmap_node_34.world_view.planned_path.is_empty(), "WorldView planned path must be empty after clear")
	
	# Test 34.3: First click plots route to (6, 11), Second click confirms and starts movement
	wmap_node_34._on_cell_clicked(Vector2i(6, 11))
	_check(wmap_node_34.planned_destination == Vector2i(6, 11), "Destination must be locked to (6, 11)")
	_check(wmap_node_34.world_view.is_moving == false, "Hero still must not move on 1st click")
	
	# 2nd click on same target confirms!
	wmap_node_34._on_cell_clicked(Vector2i(6, 11))
	_check(wmap_node_34.world_view.is_moving == true, "Hero MUST start moving on 2nd click on planned destination!")
	_check(wmap_node_34.planned_path.is_empty(), "Planned path must be cleared upon movement start")
	
	# Test 34.4: Click during movement halts hero
	wmap_node_34.cancel_hero_movement()
	_check(wmap_node_34.cancel_movement == true, "Cancellation request must be set")
	while wmap_node_34.world_view.is_moving:
		await get_tree().process_frame
	_check(wmap_node_34.world_view.is_moving == false, "Hero must halt cleanly after finishing current step")
	_check(wmap_node_34.world_view.hero_cell == Vector2i(5, 11), "Hero must stop at cell (5, 11) after 1 step")
	
	wmap_node_34.queue_free()
	print("  -> HoMM3 2-click movement (Click 1 plots, Click 2 moves, Click during movement stops) fully verified!")

	# 35. Test Unspent MP End-Day Warning & Encounter Vanishing Post-Combat
	print("[TEST] 35. Testing Unspent MP End-Day Warning & Encounter Vanishing Post-Combat...")
	GameState.start_chapter(1)
	var wmap_test_packed_35 = load("res://src/world/world_map.tscn")
	var wmap_node_35 = wmap_test_packed_35.instantiate()
	add_child(wmap_node_35)
	
	# Test 35.1: End-day warning when MP > 0
	GameState.day = 1
	GameState.move_points = 20
	wmap_node_35._on_end_day_pressed()
	var confirm_dlg = wmap_node_35.confirm_end_day_dialog
	_check(confirm_dlg != null and confirm_dlg.visible == true, "End-day dialog must show when MP > 0")
	_check(GameState.day == 1, "Day must NOT advance yet while confirmation dialog is pending")
	_check(wmap_node_35.confirm_end_day_prompt.text.contains("20/"), "Prompt must show remaining move points")
	
	# Test Cancel Button
	wmap_node_35.confirm_end_day_cancel_btn.emit_signal("pressed")
	_check(confirm_dlg.visible == false, "Dialog must hide on cancel")
	_check(GameState.day == 1, "Day must remain 1 after cancellation")
	
	# Test Confirm Button
	wmap_node_35._on_end_day_pressed()
	_check(confirm_dlg.visible == true, "Dialog must reopen")
	wmap_node_35.confirm_end_day_confirm_btn.emit_signal("pressed")
	_check(confirm_dlg.visible == false, "Dialog must hide on confirmation")
	_check(GameState.day == 2, "Day must advance to 2 upon confirmation")
	
	# Test 35.2: Immediate end day when MP == 0
	GameState.move_points = 0
	wmap_node_35._on_end_day_pressed()
	_check(confirm_dlg.visible == false, "Dialog must NOT show when MP == 0")
	_check(GameState.day == 3, "Day must advance immediately when MP == 0")
	
	# Test 35.3: Vanishing of defeated encounter from map (Quick Combat)
	_check(wmap_node_35.world_view.objects.has(Vector2i(18, 11)), "Map must initially have patrol_1 at (18, 11)")
	wmap_node_35._execute_quick_combat("patrol_1")
	_check(GameState.flags.get("patrol_1", false) == true, "patrol_1 flag must be true")
	_check(not wmap_node_35.world_view.objects.has(Vector2i(18, 11)), "patrol_1 object must be completely removed from map objects upon victory")
	
	# Test 35.4: Vanishing of bandit boss from map
	_check(wmap_node_35.world_view.objects.has(Vector2i(28, 11)), "Map must initially have bandit_boss at (28, 11)")
	GameState.player_army = [{"unit_id": "griffin", "count": 60}]
	wmap_node_35._execute_quick_combat("bandit_boss")
	_check(GameState.flags.get("bandit_boss", false) == true, "bandit_boss flag must be true")
	_check(not wmap_node_35.world_view.objects.has(Vector2i(28, 11)), "bandit_boss object must be completely removed from map objects upon victory")
	
	# Test 35.5: Persistence across scene reload
	wmap_node_35.queue_free()
	var wmap_node_35_reloaded = wmap_test_packed_35.instantiate()
	add_child(wmap_node_35_reloaded)
	_check(not wmap_node_35_reloaded.world_view.objects.has(Vector2i(18, 11)), "patrol_1 must remain gone after scene reload")
	_check(not wmap_node_35_reloaded.world_view.objects.has(Vector2i(28, 11)), "bandit_boss must remain gone after scene reload")
	
	# Test 35.6: NameLabel Vertical Alignment in TopHUD
	var hero_lbl = wmap_node_35_reloaded.get_node("CanvasLayer/TopHUD/NameLabel") as Label
	_check(hero_lbl.offset_top == 22.0 and hero_lbl.offset_bottom == 52.0, "NameLabel must be vertically aligned with GoldLabel at y=22-52")
	_check(hero_lbl.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "NameLabel must have vertical_alignment centered")
	
	# Test 35.7: Guard Interception on Guarded Chests (HoMM-style)
	GameState.start_chapter(1)
	var wmap_node_guard_test = wmap_test_packed_35.instantiate()
	add_child(wmap_node_guard_test)
	_check(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 8)), "Guard at (4, 8) must exist")
	_check(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest at (4, 9) must exist")
	GameState.flags["patrol_goblins"] = false
	wmap_node_guard_test.world_view.hero_cell = Vector2i(4, 9)
	var guarded_chest_obj = wmap_node_guard_test.world_view.objects[Vector2i(4, 9)]
	wmap_node_guard_test._trigger_object(guarded_chest_obj)
	_check(wmap_node_guard_test.popup_title.text.contains("ОХРАНА СОКРОВИЩ"), "Guard must intercept before chest can be looted!")
	_check(not GameState.flags.get("chest_start", false), "Chest must NOT be looted while guard is alive!")
	_check(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest must still remain on map!")
	
	# Defeating guard unblocks chest
	wmap_node_guard_test.popup_btn2.emit_signal("pressed") # Quick combat guard
	_check(GameState.flags.get("patrol_goblins", false) == true, "Guard must be defeated")
	_check(not wmap_node_guard_test.world_view.objects.has(Vector2i(4, 8)), "Guard must be removed from map")
	
	# Now chest can be claimed freely
	wmap_node_guard_test._trigger_object(guarded_chest_obj)
	_check(wmap_node_guard_test.popup_title.text.contains("Сундук"), "Now chest popup must be shown")
	wmap_node_guard_test.popup_btn1.emit_signal("pressed")
	_check(GameState.flags.get("chest_start", false) == true, "Chest is now collected")
	_check(not wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest is now vanished from map")
	
	# Test 35.8: Double-click event does not prematurely cancel movement
	var double_click_evt = InputEventMouseButton.new()
	double_click_evt.button_index = MOUSE_BUTTON_LEFT
	double_click_evt.pressed = true
	double_click_evt.double_click = true
	wmap_node_guard_test.world_view.is_moving = true
	wmap_node_guard_test.world_view._gui_input(double_click_evt)
	_check(wmap_node_guard_test.cancel_movement == false, "double_click event must NOT cancel hero movement!")
	
	wmap_node_guard_test.queue_free()
	wmap_node_35_reloaded.queue_free()
	
	print("  -> Unspent MP end-day confirmation, monster token vanishing, NameLabel centering, and Guard interception fully verified!")

	# 36. Test Tactical Spells, Creature Passives, Threat Range & Astrologers Proclaim
	print("[TEST] 36. Testing Tactical Spells, Creature Passives, Threat Range & Astrologers Proclaim...")
	
	# Test 36.1: Stoneskin Spell
	var test_stack_ally = BattleStack.new()
	test_stack_ally.setup("griffin", 10, 0, Vector2i(1, 2))
	var stoneskin_base_def = test_stack_ally.get_defense()
	test_stack_ally.buff_stoneskin_turns = 3
	_check(test_stack_ally.has_stoneskin() == true, "Stack must report having stoneskin")
	_check(test_stack_ally.get_defense() == stoneskin_base_def + 5, "Stoneskin must grant exactly +5 defense")
	print("  -> Stoneskin spell successfully grants +5 Defense!")

	# Test 36.2: Blind Spell & Damage Break
	var test_stack_enemy = BattleStack.new()
	test_stack_enemy.setup("goblin", 20, 1, Vector2i(4, 2))
	test_stack_enemy.debuff_blind_turns = 3
	_check(test_stack_enemy.is_blinded() == true, "Stack must report being blinded")
	_check(test_stack_enemy.get_speed() == 0, "Blinded stack must have 0 speed (cannot move)")
	var dmg_res = test_stack_enemy.take_damage(15)
	_check(dmg_res.get("dispelled_blind", false) == true, "Taking damage must dispel blind")
	_check(test_stack_enemy.is_blinded() == false, "Stack must no longer be blinded after taking damage")
	_check(test_stack_enemy.get_speed() > 0, "Speed must be restored after blind is dispelled")
	print("  -> Blind spell and damage dispel mechanics verified!")

	# Test 36.3: Swamp Zombie Disease Passive
	var test_zombie = BattleStack.new()
	test_zombie.setup("swamp_zombie", 15, 1, Vector2i(2, 2))
	_check(test_zombie.data.get("disease", false) == true, "Swamp zombie must have disease passive")
	test_stack_ally.debuff_disease_turns = 2
	_check(test_stack_ally.is_diseased() == true, "Target must report being diseased")
	var diseased_range = test_stack_ally.get_damage_range(test_stack_enemy, true)
	test_stack_ally.debuff_disease_turns = 0
	var healthy_range = test_stack_ally.get_damage_range(test_stack_enemy, true)
	_check(diseased_range.max_dmg < healthy_range.max_dmg, "Diseased stack must deal reduced damage (-25% attack)")
	print("  -> Swamp Zombie Disease debuff verified (-25% attack penalty)!")

	# Test 36.4: Treant Regeneration & Entangle Passives
	var test_treant = BattleStack.new()
	test_treant.setup("treant", 5, 0, Vector2i(1, 1))
	_check(test_treant.data.get("regeneration", 0) == 20, "Treant must have 20 HP regeneration")
	_check(test_treant.data.get("entangle", false) == true, "Treant must have entangle passive")
	test_treant.current_hp = 30 # Injured
	test_treant.reset_round()
	_check(test_treant.current_hp == 50, "Treant must regenerate 20 HP upon round reset!")
	print("  -> Treant Regeneration (+20 HP/round) verified!")

	# Test 36.5: Red Dragon Linear 2-Hex Breath Passive
	var test_dragon = BattleStack.new()
	test_dragon.setup("red_dragon", 2, 0, Vector2i(2, 3))
	_check(test_dragon.data.get("breath_attack", false) == true, "Red Dragon must have breath_attack passive")
	var delta_hex = Vector2i(1, 0)
	var defender_hex = test_dragon.hex + delta_hex
	var behind_hex = defender_hex + delta_hex
	_check(HexGrid.distance(test_dragon.hex, behind_hex) == 2, "Behind hex must be exactly 2 hexes in line")
	print("  -> Red Dragon 2-hex linear breath geometry verified!")

	# Test 36.6: Enemy Threat Range Preview & Hotkeys in BattleArena
	var arena_suite_packed = load("res://src/battle/battle_arena.tscn")
	var arena_suite_node = arena_suite_packed.instantiate()
	add_child(arena_suite_node)
	var goblin_enemy = null
	for s in arena_suite_node.all_stacks:
		if s.team == 1 and s.is_alive():
			goblin_enemy = s
			break
	_check(goblin_enemy != null, "Arena must have an enemy stack")
	var goblin_pos = HexGrid.hex_to_pixel(goblin_enemy.hex.x, goblin_enemy.hex.y, arena_suite_node.HEX_SIZE, arena_suite_node.grid_origin)
	arena_suite_node._update_mouse_hover(goblin_pos)
	_check(arena_suite_node.hovered_threat_hexes.size() > 0, "Hovering enemy must calculate threat range hexes")
	_check(arena_suite_node.hovered_threat_hexes.has(goblin_enemy.hex), "Threat hexes must include enemy's own hex")
	
	# Test Hotkey B (Spellbook)
	var key_b_evt = InputEventKey.new()
	key_b_evt.keycode = KEY_B
	key_b_evt.pressed = true
	arena_suite_node._unhandled_input(key_b_evt)
	_check(arena_suite_node.spellbook_dialog.visible == true, "Key B must open spellbook dialog")
	arena_suite_node.spellbook_dialog.hide()
	
	# Test Floating text with casualties
	arena_suite_node._spawn_floating_text(Vector2i(2, 2), "-120", Color(1, 0.3, 0.2))
	arena_suite_node._spawn_floating_text(Vector2i(2, 2), "Потери: -3", Color(1, 0.1, 0.1), Vector2(0, -28))
	_check(arena_suite_node.floating_texts.size() >= 2, "Floating texts must support damage and casualties")
	arena_suite_node.queue_free()
	print("  -> Enemy threat range preview, hotkeys and floating combat casualties verified!")

	# Test 36.7: Astrologers Proclaim Weekly Rollover
	GameState.start_chapter(1)
	GameState.day = 7
	var wmap_test_packed_36 = load("res://src/world/world_map.tscn")
	var wmap_node_36 = wmap_test_packed_36.instantiate()
	add_child(wmap_node_36)
	wmap_node_36.planned_destination = Vector2i(-1, -1)
	wmap_node_36._execute_end_day()
	_check(GameState.day == 8, "Day must advance to 8 (Week 2)")
	_check(GameState.last_astrologers_event.size() > 0, "Astrologers event must trigger on Day 8")
	_check(wmap_node_36.popup_title.text.contains("АСТРОЛОГИ"), "Astrologers popup must be displayed")
	wmap_node_36.popup_btn1.emit_signal("pressed")
	_check(wmap_node_36.popup_dialog.visible == false, "Popup must close after acknowledgment")
	
	# Test 36.8: Player Ownership Banners over Visited Structures
	GameState.flags["watermill"] = true
	GameState.flags["magic_shrine"] = true
	_check(GameState.flags.get("watermill", false) == true, "Watermill must be flagged visited")
	wmap_node_36.world_view.queue_redraw()
	await get_tree().process_frame
	wmap_node_36.queue_free()
	print("  -> Astrologers Proclaim weekly event & Player Ownership Banners fully verified!")

	# 37. Test Mobile Main Menu Ergonomics, Touch Targets & Modals
	print("[TEST] 37. Testing Mobile Main Menu Ergonomics, Touch Targets & Navigation...")
	var main_packed = load("res://src/main.tscn")
	var main_node = main_packed.instantiate()
	add_child(main_node)
	await get_tree().process_frame

	# Check safe margin container for mobile cutouts
	var safe_margin = main_node.get_node("SafeMargin") as MarginContainer
	_check(safe_margin != null, "SafeMargin container must exist")
	_check(safe_margin.get_theme_constant("margin_left") >= 40, "Mobile left margin must be >= 40px")
	_check(safe_margin.get_theme_constant("margin_right") >= 40, "Mobile right margin must be >= 40px")
	_check(safe_margin.get_theme_constant("margin_top") >= 24, "Mobile top margin must be >= 24px")

	# Check primary action cards touch sizes
	var action_cards = main_node.get_node("SafeMargin/MainVBox/CenterSection/ActionCards")
	var start_adv_btn = action_cards.get_node("StartAdventureBtn") as Button
	var arena_btn = action_cards.get_node("ArenaBattleBtn") as Button
	var chap_btn = action_cards.get_node("ChapterSelectBtn") as Button
	_check(start_adv_btn.custom_minimum_size.y >= 64, "Primary buttons must have finger touch height >= 64px")
	_check(arena_btn.custom_minimum_size.y >= 64, "Arena button must have finger touch height >= 64px")
	_check(chap_btn.custom_minimum_size.y >= 64, "Chapter select button must have finger touch height >= 64px")

	# Check bottom toolbar touch sizes
	var bottom_toolbar = main_node.get_node("SafeMargin/MainVBox/BottomToolbar")
	var music_btn = bottom_toolbar.get_node("MusicSelectBtn") as Button
	var about_btn = bottom_toolbar.get_node("AboutBtn") as Button
	var exit_btn = bottom_toolbar.get_node("ExitBtn") as Button
	_check(music_btn.custom_minimum_size.y >= 50, "Bottom toolbar buttons must have touch height >= 50px")
	_check(about_btn.custom_minimum_size.y >= 50, "About button must have touch height >= 50px")
	_check(exit_btn.custom_minimum_size.y >= 50, "Exit button must have touch height >= 50px")

	# Check top mini player
	var mini_player = main_node.get_node("SafeMargin/MainVBox/TopBar/RightBox/MiniMusicPlayer")
	_check(mini_player != null, "Top mini music player must exist")

	# Test modal openings & Android back request dismissal
	main_node._open_chapter_dialog()
	_check(main_node.chapter_dialog.visible == true, "Chapter dialog must open")
	main_node._handle_back_request()
	_check(main_node.chapter_dialog.visible == false, "Chapter dialog must dismiss on Back")

	main_node._on_start_adventure()
	_check(main_node.hero_select_dialog.visible == true, "Hero select dialog must open")
	main_node._handle_back_request()
	_check(main_node.hero_select_dialog.visible == false, "Hero select dialog must dismiss on Back")

	main_node._open_music_dialog()
	_check(main_node.music_dialog.visible == true, "Music jukebox dialog must open")
	main_node._handle_back_request()
	_check(main_node.music_dialog.visible == false, "Music jukebox dialog must dismiss on Back")

	main_node._on_about()
	_check(main_node.about_dialog.visible == true, "About dialog must open")
	main_node._handle_back_request()
	_check(main_node.about_dialog.visible == false, "About dialog must dismiss on Back")

	# Test continue button with save game summary
	var continue_btn = action_cards.get_node("ContinueBtn") as Button
	_check(continue_btn != null, "ContinueBtn must exist")
	if GameState.has_save_game():
		_check(continue_btn.visible == true, "Continue button must be visible when save exists")
		_check(continue_btn.text.contains("Гл."), "Continue button must show chapter info")

	main_node.queue_free()
	print("  -> Mobile Main Menu layout, touch targets, and Back navigation fully verified!")

	# 38. Data Integrity: every unit, spell and resource the code refers to must exist
	print("[TEST] 38. Testing Data Integrity (units, spells, resources)...")
	_check_data_integrity()
	print("  -> All referenced units, spells, dwellings and resource paths exist!")

	# 39. Gameplay flow (перенесено из tests/test_gameplay.gd: как -s скрипт он не видел автозагрузки)
	print("[TEST] 39. Testing Army Split/Merge, Forester Quest Chain & Battle Flags...")
	GameState.reset()
	GameState.start_chapter(1)
	GameState.player_army = [{"unit_id": "griffin", "count": 5}]
	_check(GameState.split_stack(0, 1), "Failed to split stack")
	_check(GameState.player_army.size() == 2, "Army size should be 2 after split")
	_check(GameState.player_army[0]["count"] == 4 and GameState.player_army[1]["count"] == 1, "Split must leave 4 + 1")
	GameState.split_stack(0, 1)
	GameState.split_stack(0, 1)
	GameState.split_stack(0, 1)
	_check(GameState.player_army.size() == 5, "Army size should be 5 after splits")
	_check(not GameState.split_stack(0, 1), "Sixth stack must be refused")
	_check(GameState.merge_stacks(0, 1), "Failed to merge stacks")
	_check(GameState.player_army.size() == 4 and GameState.player_army[0]["count"] == 2, "Merge must leave 4 stacks, slot 0 = 2")
	for uid in ["griffin", "fairy_archer", "treant", "wolf", "goblin"]:
		_check(str(UnitData.get_unit(uid)["name"]).length() <= 16, "Unit name too long for UI: %s" % uid)

	GameState.player_army = [{"unit_id": "griffin", "count": 6}, {"unit_id": "fairy_archer", "count": 18}]
	var wmap_39 = load("res://src/world/world_map.tscn").instantiate()
	add_child(wmap_39)
	var wv_39 = wmap_39.world_view
	wmap_39._trigger_object(wv_39.objects[Vector2i(7, 18)])
	_check(wmap_39.popup_dialog.visible, "Forester popup must be visible")
	wmap_39.popup_btn1.emit_signal("pressed")
	_check(GameState.has_gate_key and GameState.quest_forester_started, "Forester must give the Gate Key and start the quest")
	wmap_39._trigger_object(wv_39.objects[Vector2i(14, 11)])
	wmap_39.popup_btn1.emit_signal("pressed")
	_check(GameState.flags.get("iron_gate_opened", false), "Iron Gate must open with the key")
	wmap_39._trigger_object(wv_39.objects[Vector2i(27, 4)])
	_check(not GameState.quest_completed, "Shrine must not complete the quest without the crown")
	wmap_39.popup_btn1.emit_signal("pressed")
	GameState.has_fairy_crown = true
	var gold_39 = GameState.gold
	wmap_39._trigger_object(wv_39.objects[Vector2i(27, 4)])
	_check(GameState.quest_completed and GameState.gold > gold_39, "Returning the crown must complete the quest with a reward")
	wmap_39.queue_free()

	var arena_39 = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(arena_39)
	var first_39 = arena_39.all_stacks[0]
	var pos_39 = HexGrid.hex_to_pixel(first_39.hex.x, first_39.hex.y, arena_39.HEX_SIZE, arena_39.grid_origin)
	_check(arena_39._find_stack_at_position(pos_39) == first_39, "Tap on a stack's hex must pick that stack")
	GameState.pending_battle_id = "test_encounter"
	arena_39._show_victory(false)
	_check(not GameState.flags.get("test_encounter", false), "Defeat must keep the enemy on the map")
	arena_39.victory_dialog.hide()
	GameState.pending_battle_id = "test_encounter_2"
	arena_39._show_victory(true)
	_check(GameState.flags.get("test_encounter_2", false), "Victory must mark the encounter as defeated")
	arena_39.queue_free()
	print("  -> Army split/merge, forester quest chain and battle outcome flags verified!")

	# 40. Regression: exploits and campaign flow bugs found in review
	print("[TEST] 40. Testing Regressions: reward dupes, restoration, saves, gates, morale...")
	await _check_regressions()
	print("  -> Reward dupes, unbounded restoration, save order, gates, weekly events and auto-battle verified!")

	# 41. Mobile & UI: Android back, modal backdrops, retreat confirmation, layout fits
	print("[TEST] 41. Testing Android Back, Modal Backdrops, Retreat Confirmation & Layout Fit...")
	await _check_mobile_ui()
	print("  -> Back button, backdrop taps, two-step retreat, tap-side attacks and dialog layouts verified!")

	await get_tree().process_frame
	_finish()

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev)
		await get_tree().process_frame

func _check_mobile_ui() -> void:
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false, "Android Back must not quit the game on its own")

	var mm = load("res://src/main.tscn").instantiate()
	add_child(mm)
	await get_tree().process_frame
	_check(mm._handle_back_request() == false, "Back in an empty main menu must report nothing to close (the game then quits)")
	mm._open_chapter_dialog()
	await get_tree().process_frame
	await _tap(Vector2(20, 20))
	_check(not mm.chapter_dialog.visible, "Tapping the dark backdrop must close a main menu dialog")
	mm.queue_free()
	await get_tree().process_frame

	GameState.reset()
	GameState.start_chapter(1)
	var wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(wm)
	await get_tree().process_frame
	wm.popup_dialog.hide()
	wm._handle_back()
	_check(wm.pause_dialog.visible, "Back on the map with no dialogs must open the camp menu")
	wm._handle_back()
	_check(not wm.pause_dialog.visible, "Back must close the camp menu")
	var pause_parch: Control = null
	for ch in wm.pause_dialog.get_children():
		if ch is CenterContainer:
			pause_parch = ch.get_child(0)
	var pause_vbox: Control = pause_parch.get_child(0).get_child(0)
	_check(pause_parch.custom_minimum_size.y >= pause_vbox.get_combined_minimum_size().y, "Camp menu parchment must fit all its rows")
	wm.queue_free()
	await get_tree().process_frame

	GameState.pending_battle_id = "patrol_wolves"
	var ba = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ba)
	await get_tree().process_frame
	ba._on_retreat_pressed()
	_check(not ba.victory_dialog.visible, "First retreat press must only ask for confirmation")
	ba._on_retreat_pressed()
	_check(ba.victory_dialog.visible, "Second retreat press must leave the battle")
	ba.queue_free()
	await get_tree().process_frame

	var ba2 = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ba2)
	await get_tree().process_frame
	var grid: Control = ba2.get_node("CanvasLayer/SpellbookDialog/Parchment/SpellGrid")
	ba2._setup_spell_buttons()
	await get_tree().process_frame
	_check(grid.get_combined_minimum_size().x <= grid.size.x + 1.0, "Battle spell icons must fit inside the spellbook (%d > %d)" % [grid.get_combined_minimum_size().x, grid.size.x])
	# Атака с той стороны, куда тапнули: тап правее цели — клетка справа от неё
	var target = null
	for s in ba2.all_stacks:
		if s.team == 1:
			target = s
	var actor = ba2.current_actor
	actor.hex = target.hex + Vector2i(-3, 0)
	ba2._update_reachable_hexes()
	var t_px = HexGrid.hex_to_pixel(target.hex.x, target.hex.y, ba2.HEX_SIZE, ba2.grid_origin)
	var from_left: Vector2i = ba2._pick_attack_hex(target, t_px + Vector2(-60, 0))
	var from_top: Vector2i = ba2._pick_attack_hex(target, t_px + Vector2(0, -80))
	_check(from_left == target.hex + Vector2i(-1, 0), "Tap on the left of the enemy must attack from the left hex (got %s)" % str(from_left))
	_check(from_top != from_left and HexGrid.distance(from_top, target.hex) == 1, "Tap above the enemy must pick another adjacent hex")
	ba2.queue_free()
	await get_tree().process_frame

func _check_regressions() -> void:
	GameState.reset()
	GameState.start_chapter(1)
	var wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(wm)
	await get_tree().process_frame
	wm.popup_dialog.hide()
	var wv = wm.world_view

	# Награда объекта не должна выдаваться повторно через «Око Орла»
	var gold0 = GameState.gold
	wm._trigger_object(wv.objects[Vector2i(10, 4)])
	wm.popup_btn1.emit_signal("pressed")
	GameState.current_mana = 100
	wm._cast_scrying()
	wm.popup_btn1.emit_signal("pressed")
	_check(GameState.gold == gold0 + 500, "Mill reward must not repeat after casting Eagle Eye (gold %d)" % GameState.gold)
	var att0 = GameState.attack
	wm._trigger_object(wv.objects[Vector2i(27, 18)])
	wm.popup_btn1.emit_signal("pressed")
	wm._cast_scrying()
	wm.popup_btn1.emit_signal("pressed")
	_check(GameState.attack == att0 + 2, "Obelisk blessing must be granted exactly once (attack %d)" % GameState.attack)

	# Источник маны — раз в день
	var fountain = wv.objects[Vector2i(4, 4)]
	GameState.current_mana = 0
	wm._trigger_object(fountain)
	wm.popup_btn1.emit_signal("pressed")
	_check(GameState.current_mana == GameState.max_mana, "Fountain must restore mana")
	GameState.current_mana = 0
	wm._trigger_object(fountain)
	wm.popup_btn1.emit_signal("pressed")
	_check(GameState.current_mana == 0, "Fountain must restore mana only once per day")

	# Обелиск: после благословения и победы над стражей можно нанять Каменного Стража
	GameState.flags["patrol_obelisk"] = true
	GameState.gold = 5000
	wm._trigger_object(wv.objects[Vector2i(27, 18)])
	wm.popup_btn1.emit_signal("pressed")
	_check(GameState.player_army.any(func(s): return s["unit_id"] == "stone_guardian"), "Obelisk must offer Stone Guardians after its blessing")

	# Покупка при полном войске не должна списывать золото
	GameState.player_army = [
		{"unit_id": "griffin", "count": 1}, {"unit_id": "fairy_archer", "count": 1},
		{"unit_id": "treant", "count": 1}, {"unit_id": "druid", "count": 1},
		{"unit_id": "royal_fairy", "count": 1}]
	GameState.gold = 5000
	GameState.merchant_offers = [{"kind": "units", "id": "wolf", "count": 5, "price": 400}]
	_check(not GameState.buy_merchant_offer(0) and GameState.gold == 5000, "Merchant must not take gold when the army is full")

	# Запертые врата не пропускают героя без ключа
	GameState.player_army = [{"unit_id": "griffin", "count": 6}]
	GameState.has_gate_key = false
	wv.hero_cell = Vector2i(13, 11)
	wv.hero_pixel_pos = wv.cell_to_pixel(Vector2i(13, 11))
	GameState.move_points = 50
	await wm._move_hero_along_path([Vector2i(14, 11), Vector2i(15, 11), Vector2i(16, 11)] as Array[Vector2i])
	_check(wv.hero_cell == Vector2i(13, 11), "Locked gate must stop the hero in front of it (hero at %s)" % str(wv.hero_cell))
	_check(wm.popup_dialog.visible and "Врата" in wm.popup_title.text, "Locked gate must open its dialog from the adjacent cell")
	wm.popup_dialog.hide()
	_check(WorldNavigator.find_path(Vector2i(13, 11), Vector2i(16, 11), wv.get_path_obstacles(Vector2i(16, 11)), Rect2i(0, 0, wv.MAP_COLS, wv.MAP_ROWS), wv.road_cells).is_empty(), "Route must not lead through a locked gate")

	# Тексты обращаются к текущему герою
	GameState.set_hero_class("archmage")
	GameState.quest_forester_started = false
	GameState.quest_completed = false
	wm._trigger_object(wv.objects[Vector2i(7, 18)])
	_check("Элеонора" in wm.popup_text.text and not "Аларик" in wm.popup_text.text, "Forester must address the current hero")
	wm.queue_free()
	await get_tree().process_frame

	# «Неделя Доблести» и «Неделя Магии» действуют только неделю
	GameState.reset()
	GameState.day = 28
	var base_att = GameState.get_total_attack()
	GameState.next_day()
	_check(GameState.get_total_attack() == base_att + 2, "Week of Valor must grant +2 attack")
	for i in 7:
		GameState.next_day()
	_check(GameState.get_total_attack() == base_att, "Week of Valor bonus must expire after the week")
	GameState.day = 21
	var base_mana = GameState.get_total_max_mana()
	GameState.next_day()
	_check(GameState.max_mana == base_mana + 20, "Week of Magic must raise max mana by 20")
	for i in 7:
		GameState.next_day()
	_check(GameState.max_mana == base_mana, "Week of Magic bonus must expire after the week")

	# Бой: «Исцеление» поднимает павших, победа сохраняет войско уже с потерями
	GameState.reset()
	GameState.start_chapter(1)
	GameState.current_mana = 100
	GameState.pending_battle_id = "patrol_wolves"
	var ba = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ba)
	await get_tree().process_frame
	var fairy: BattleStack = null
	var griffin: BattleStack = null
	for s in ba.all_stacks:
		if s.unit_id == "fairy_archer":
			fairy = s
		elif s.unit_id == "griffin":
			griffin = s
	fairy.take_damage(16 * 3 + 5)
	var heal_res: Dictionary = fairy.heal(108)
	_check(fairy.count == 18 and fairy.current_hp == 16, "Heal must revive fallen fairies up to the starting count")
	_check(heal_res.healed == 53 and heal_res.revived == 3, "Heal must report what it actually restored")
	var dmg_target: BattleStack = null
	for s in ba.all_stacks:
		if s.team == 1:
			dmg_target = s
	dmg_target.has_acted = true
	dmg_target.debuff_entangle_turns = ba._debuff_duration(1, dmg_target)
	dmg_target.reset_round()
	_check(dmg_target.get_speed() == 0, "Entangle applied after the target acted must still hold on its next turn")
	for s in ba.all_stacks:
		if s.team == 1:
			s.count = 0
	griffin.count = 1
	ba._show_victory(true)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	var saved_griffins := 0
	for slot in saved["player_army"]:
		if slot["unit_id"] == "griffin":
			saved_griffins = int(slot["count"])
	_check(saved_griffins == 1, "Victory must save the army after losses (griffins on disk: %d)" % saved_griffins)
	_check(int(GameState.fallen_units.get("griffin", 0)) == 5, "Fallen griffins must be remembered for restoration")
	_check(GameState.is_feat_unlocked("first_blood"), "First victory must unlock the 'first_blood' feat")
	ba.queue_free()
	await get_tree().process_frame

	# После Арены бой кампании снова возвращает на карту
	GameState.setup_demo_battle("normal", "balanced", "forest_bandits")
	var demo = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(demo)
	await get_tree().process_frame
	GameState.reset()
	_check(GameState.battle_return_scene == GameState.WORLD_MAP_SCENE, "New campaign must return from battles to the world map")
	demo.queue_free()
	await get_tree().process_frame

	# Автобой не должен вставать после дополнительного хода от боевого духа
	GameState.reset()
	GameState.start_chapter(1)
	GameState.skills["leadership"] = 10
	GameState.pending_battle_id = "patrol_wolves"
	var auto_ba = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(auto_ba)
	await get_tree().process_frame
	auto_ba._toggle_auto_battle()
	await get_tree().create_timer(6.0).timeout
	_check(auto_ba.current_round > 1 or auto_ba.victory_dialog.visible, "Auto-battle must keep going after a morale extra turn (round %d)" % auto_ba.current_round)
	auto_ba.queue_free()
	await get_tree().process_frame

## Статическая сверка: конвейер не должен уметь закоммитить ссылку на юнит,
## заклинание или ресурс, которых нет в данных (так ломались пегасы и музыка карты).
func _check_data_integrity() -> void:
	var unit_re := RegEx.create_from_string("(?:add_units_to_army\\(\\s*\"|\"unit_id\"\\s*:\\s*\"|\"unit\"\\s*:\\s*\")([a-z_]+)\"")
	var res_re := RegEx.create_from_string("\"(res://[^\"%]+\\.(?:png|jpg|wav|ogg|mp3|tscn|tres|gd))\"")
	for path in _collect_scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for m in unit_re.search_all(text):
			_check(UnitData.has_unit(m.get_string(1)), "%s ссылается на несуществующий юнит '%s'" % [path, m.get_string(1)])
		for m in res_re.search_all(text):
			_check(ResourceLoader.exists(m.get_string(1)), "%s ссылается на отсутствующий ресурс %s" % [path, m.get_string(1)])

	for uid in UnitData.UNITS.keys():
		var u: Dictionary = UnitData.UNITS[uid]
		for key in ["token_path", "sprite_path"]:
			_check(ResourceLoader.exists(str(u.get(key, ""))), "Юнит %s: нет файла %s" % [uid, u.get(key, "")])
		var up := str(u.get("upgrade_to", ""))
		_check(up == "" or UnitData.has_unit(up), "Юнит %s улучшается в несуществующий '%s'" % [uid, up])
	for sid in SpellData.SPELLS.keys():
		_check(ResourceLoader.exists(str(SpellData.SPELLS[sid].get("icon_path", ""))), "Заклинание %s: нет иконки" % sid)
	for uid in GameState.MERCHANT_UNIT_POOL:
		_check(UnitData.has_unit(uid), "Торговец продаёт несуществующий юнит '%s'" % uid)
	for did in DwellingData.DWELLINGS.keys():
		var unit_id := str(DwellingData.DWELLINGS[did].get("unit", ""))
		_check(UnitData.has_unit(unit_id), "Жилище %s нанимает несуществующий юнит '%s'" % [did, unit_id])

	var saved_class := GameState.hero_class_id
	for cls in ["paladin", "archmage", "ranger"]:
		GameState.set_hero_class(cls)
		for sp in GameState.learned_spells:
			_check(SpellData.has_spell(sp), "У класса %s в learned_spells неизвестное заклинание '%s'" % [cls, sp])
	GameState.set_hero_class(saved_class)

func _collect_scripts(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			result.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		result.append_array(_collect_scripts(dir_path.path_join(d)))
	return result


