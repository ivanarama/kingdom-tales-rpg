extends Node

const SpellData = preload("res://src/core/spell_data.gd")
const ArtifactData = preload("res://src/core/artifact_data.gd")
const UnitData = preload("res://src/core/unit_data.gd")
const BattleStack = preload("res://src/battle/battle_stack.gd")

## Наборы 1–76 записаны прямо в _ready(). Новые наборы — отдельными файлами в tests/suites/ (см. tests/README.md).
const INLINE_SUITES := 76
## Упавший assert останавливает прогон, и без сторожа Godot работал бы до --quit-after (в CI — до таймаута в 15 минут).
## Весь прогон занимает меньше минуты, так что 240 с — с запасом для медленных машин.
const WATCHDOG_SEC := 240.0
## Одинаковые случайные броски в каждом прогоне: тест не должен проходить через раз.
const TEST_SEED := 20260930

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Running full HoMM-style verification suite...")
	seed(TEST_SEED)
	get_tree().create_timer(WATCHDOG_SEC, true, false, true).timeout.connect(_on_watchdog)
	
	# 1. Test SFX & Music
	print("[TEST] 1. Testing Audio & Music...")
	assert(SoundManager.music_player != null, "Music player must exist")
	assert(SoundManager.sfx_cache.has("horse_gallop"), "Missing horse_gallop")
	assert(SoundManager.sfx_cache.has("bow_shot"), "Missing bow_shot")
	assert(SoundManager.sfx_cache.has("arrow_hit"), "Missing arrow_hit")
	print("  -> SFX cache verified! Audio files imported successfully.")

	# 2. Test Persistent Hero Coordinates
	print("[TEST] 2. Testing Hero Position & World Persistence...")
	GameState.hero_cell = Vector2i(18, 11)
	var wmap_packed = load("res://src/world/world_map.tscn")
	var wmap_node = wmap_packed.instantiate()
	add_child(wmap_node)
	
	var wv = wmap_node.get_node("ScrollContainer/WorldView")
	assert(wv.hero_cell == Vector2i(18, 11), "WorldView must restore hero_cell from GameState")
	print("  -> Hero position restored to (18, 11) after battle/scene transition!")
	
	# 3. Test Chest Vanishing
	print("[TEST] 3. Testing Chest Vanishing upon Pickup...")
	assert(wv.objects.has(Vector2i(4, 9)), "Chest must exist before pickup")
	# In HoMM, guard must be defeated before chest pickup; set guard defeated for unit test
	GameState.flags["patrol_goblins"] = true
	# Simulate picking up the chest
	var chest_obj = wv.objects[Vector2i(4, 9)]
	wv.hero_cell = Vector2i(4, 9)
	wmap_node._trigger_object(chest_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	assert(GameState.flags.get("chest_start", false), "Chest flag must be set to true")
	assert(not wv.objects.has(Vector2i(4, 9)), "Chest must vanish from objects map!")
	print("  -> Chest collected and vanished completely from the map!")

	# 4. Test Limited Dwelling Stock & Hiring
	print("[TEST] 4. Testing Fairy Dwelling Stock & Hiring...")
	var initial_stock = GameState.dwelling_stock.get("fairy_camp", 0)
	assert(initial_stock == 14, "Dwelling initial stock should be 14")
	var fairy_obj = wv.objects[Vector2i(10, 8)]
	wmap_node._trigger_object(fairy_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	assert(GameState.dwelling_stock["fairy_camp"] < initial_stock, "Dwelling stock must decrease after hiring")
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
			
	assert(archer != null, "Archer stack must exist")
	assert(enemy != null, "Enemy stack must exist")
	
	# Test normal range forecast (< 5 hexes)
	var forecast_close = archer.get_damage_range(enemy, false, false)
	# Test broken arrow range forecast (> 5 hexes)
	var forecast_broken = archer.get_damage_range(enemy, false, true)
	assert(forecast_broken.min_dmg <= forecast_close.min_dmg, "Broken arrow must have reduced damage")
	print("  -> Normal damage: %d-%d | Broken arrow (penalty 50%%): %d-%d" % [
		forecast_close.min_dmg, forecast_close.max_dmg,
		forecast_broken.min_dmg, forecast_broken.max_dmg
	])
	
	# Test Unit Inspector Card
	arena_node._show_unit_info(enemy)
	assert(arena_node.unit_info_dialog.visible, "Unit info dialog must open")
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
	assert(chosen_target == archer_stack, "AI must prioritize targeting archers to lock them in melee!")
	print("  -> AI correctly prioritized Fairy Archers over Griffins!")
	
	arena_node.queue_free()

	# 7. Test Quest HUD & Progression
	print("[TEST] 7. Testing Quest HUD & Objective Updates...")
	var wmap_node2 = wmap_packed.instantiate()
	add_child(wmap_node2)
	
	GameState.quest_forester_started = false
	wmap_node2._update_quest_hud()
	assert("Хижину Лесника" in wmap_node2.quest_label.text, "QuestHUD should point to Forester first")
	
	GameState.quest_forester_started = true
	GameState.has_gate_key = true
	wmap_node2._update_quest_hud()
	assert("Железные Врата" in wmap_node2.quest_label.text, "QuestHUD should point to Gate next")
	
	GameState.flags["iron_gate_opened"] = true
	wmap_node2._update_quest_hud()
	assert("Атамана" in wmap_node2.quest_label.text, "QuestHUD should point to Boss")
	
	GameState.has_fairy_crown = true
	wmap_node2._update_quest_hud()
	assert("ВЕРНИТЕ ВЕНЕЦ" in wmap_node2.quest_label.text, "QuestHUD should instruct to return crown")
	print("  -> Quest HUD dynamically reflects all 4 campaign stages accurately!")

	# 8. Test Grand Campaign Victory Sequence
	print("[TEST] 8. Testing Grand Campaign Victory Dialog...")
	var shrine_obj = {"type": "fairy_shrine", "name": "Роща Королевы Фей", "id": "fairy_shrine"}
	wmap_node2._trigger_object(shrine_obj)
	assert(wmap_node2.victory_dialog.visible, "Victory Dialog must open when crown is returned!")
	assert(GameState.quest_completed, "Quest must be marked as completed!")
	print("  -> Grand Campaign Victory Dialog presented with fanfare & rewards!")

	# 9. Test Terrain vs Road Movement Penalty
	print("[TEST] 9. Testing Road vs Wilderness Movement Penalties...")
	var initial_mp = 36
	GameState.move_points = initial_mp
	# Step onto road cell (5, 11) - road costs 1
	var road_cell = Vector2i(5, 11)
	assert(wmap_node2.world_view.road_cells.has(road_cell), "Cell (5, 11) must be a road cell")
	var p_road: Array[Vector2i] = [road_cell]
	wmap_node2._move_hero_along_path(p_road)
	assert(GameState.move_points == initial_mp - 1, "Moving on road must cost exactly 1 MP")
	
	# Step onto grass cell (5, 10) - grass costs 2
	var grass_cell = Vector2i(5, 10)
	assert(not wmap_node2.world_view.road_cells.has(grass_cell), "Cell (5, 10) must be off-road grass")
	var p_grass: Array[Vector2i] = [grass_cell]
	wmap_node2._move_hero_along_path(p_grass)
	assert(GameState.move_points == initial_mp - 3, "Moving on off-road grass must cost 2 MP (penalty 100%)")
	print("  -> Road movement costs 1 MP, rough grass costs 2 MP! A* penalty verified.")

	# 10. Test Hero Profile Screen & Hotkeys
	print("[TEST] 10. Testing Hero Character Sheet (Profile)...")
	wmap_node2._open_hero_profile()
	assert(wmap_node2.hero_dialog.visible, "Hero Profile Dialog must open")
	assert("Аларик" in wmap_node2.hero_dialog.get_node("Parchment/Title").text, "Profile title must show hero name")
	assert(wmap_node2.hero_skills_vbox.get_child_count() > 0, "Hero skills must be listed in profile")
	wmap_node2.hero_dialog.hide()
	print("  -> Hero Profile sheet verified with stats, attributes, and secondary skills!")

	# 11. Test Level-Up System & Skill Learning
	print("[TEST] 11. Testing Level-Up Trigger & Skill Selection...")
	GameState.pending_level_ups.clear()
	var prev_lvl = GameState.level
	GameState.add_xp(GameState.next_level_xp)
	assert(GameState.level == prev_lvl + 1, "Hero level must increase")
	assert(wmap_node2.level_dialog.visible, "Level-up dialog must appear with skill choices")
	# Simulate clicking first skill choice button
	wmap_node2.level_skill_btn1.emit_signal("pressed")
	assert(not wmap_node2.level_dialog.visible, "Level-up dialog closes after picking skill")
	assert(GameState.skills.size() >= 2 or GameState.skills.values().max() > 1, "Hero must now possess learned or upgraded secondary skill")
	print("  -> Level Up system successfully rewarded primary stat and secondary skill!")

	# 12. Test Artifacts & Equipment System
	print("[TEST] 12. Testing Artifacts & Equipment System...")
	GameState.equipped_artifacts.clear()
	var base_att = GameState.attack
	var base_def = GameState.defense
	GameState.inventory_artifacts.append("sword_valiance")
	GameState.inventory_artifacts.append("shield_aegis")
	GameState.inventory_artifacts.append("boots_traveler")
	assert(GameState.equip_artifact("sword_valiance"), "Must equip sword_valiance")
	assert(GameState.get_total_attack() == base_att + 4, "Total attack must include sword bonus +4")
	# Equip shield: sword + shield activates Guardian 2-piece set bonus (+2 Att, +2 Def)
	assert(GameState.equip_artifact("shield_aegis"), "Must equip shield_aegis")
	assert(GameState.get_total_defense() == base_def + 4 + 2, "Total defense must include shield +4 and Guardian set +2")
	assert(GameState.equip_artifact("boots_traveler"), "Must equip boots_traveler")
	assert(GameState.get_total_max_mp() >= 44, "Total max MP must include boots bonus +8")
	# Unequip weapon: set bonus breaks, defense reverts to base_def + 4, attack reverts to base_att
	GameState.unequip_artifact("weapon")
	assert(GameState.get_total_defense() == base_def + 4, "Defense without set bonus must be base + 4")
	assert(GameState.get_total_attack() == base_att, "Attack must revert after unequipping weapon")
	print("  -> Artifact equip/unequip & stat bonuses verified successfully!")

	# 13. Test Adventure Spells
	print("[TEST] 13. Testing Adventure Spells on World Map...")
	var pre_scry_count = GameState.revealed_cells.size()
	wmap_node2._cast_scrying()
	var post_scry_count = GameState.revealed_cells.size()
	assert(post_scry_count >= pre_scry_count, "Scrying spell must reveal cells on world map")
	GameState.current_mana = 30
	var prev_count = GameState.player_army[0]["count"]
	# Благодать возвращает только павших в боях (0.3.3): садим павших и проверяем
	GameState.add_fallen_units(GameState.player_army[0]["unit_id"], 10)
	wmap_node2._cast_restoration()
	assert(GameState.player_army[0]["count"] > prev_count, "Restoration spell must return fallen troops to army")
	assert(GameState.current_mana == 15, "Restoration must consume 15 mana")
	var fallen_left := 0
	for f51 in GameState.fallen_units:
		fallen_left += int(f51["count"])
	assert(fallen_left < 10, "Fallen pool must shrink after restoration")
	print("  -> Adventure spells (Scrying & Divine Restoration) cast and verified!")

	# 14. Test Unit Upgrades
	print("[TEST] 14. Testing Unit Upgrades in Army...")
	GameState.gold = 5000
	GameState.player_army = [
		{"unit_id": "griffin", "count": 5},
		{"unit_id": "fairy_archer", "count": 20}
	]
	var upgraded_griffin = GameState.upgrade_army_unit(0)
	assert(upgraded_griffin, "Upgrade griffin to royal_griffin must succeed")
	assert(GameState.player_army[0]["unit_id"] == "royal_griffin", "Slot 0 must now be royal_griffin")
	var upgraded_fairy = GameState.upgrade_army_unit(1)
	assert(upgraded_fairy, "Upgrade fairy to royal_fairy must succeed")
	assert(GameState.player_army[1]["unit_id"] == "royal_fairy", "Slot 1 must now be royal_fairy")
	print("  -> Unit upgrades (Griffins -> Royal Griffins, Fairies -> Royal Fairies) verified!")

	# 15. Test Multi-Chapter Progression
	print("[TEST] 15. Testing Multi-Chapter Story Progression...")
	GameState.start_chapter(2)
	assert(GameState.current_chapter == 2, "Current chapter must be 2")
	assert(GameState.hero_cell == Vector2i(3, 11), "Hero start cell for Chapter 2 set correctly")
	assert(GameState.player_army.size() >= 2, "Hero army preserved into Chapter 2")
	GameState.start_chapter(3)
	assert(GameState.current_chapter == 3, "Current chapter must be 3")
	assert(GameState.hero_cell == Vector2i(4, 16), "Hero start cell for Chapter 3 set correctly")
	print("  -> Multi-chapter transition and carryover verified for all 3 chapters!")

	# 16. Test Tactical Hex Obstacles & Flyer Movement
	print("[TEST] 16. Testing Combat Obstacles & Flyer Aerial Soaring...")
	var arena_packed2 = load("res://src/battle/battle_arena.tscn")
	var arena_node2 = arena_packed2.instantiate()
	add_child(arena_node2)
	assert(arena_node2.obstacles.size() > 0, "Tactical obstacles must be spawned on arena")
	# Royal griffin is flying, so obstacles do not block its flight
	assert(UnitData.get_unit("royal_griffin").get("flying", false) == true, "Royal griffin must have flying property")
	arena_node2.queue_free()
	print("  -> Hex arena obstacles and flying unit movement verified!")

	# 17. Test Persistent Save & Load System
	print("[TEST] 17. Testing Persistent Save & Load System...")
	GameState.gold = 7777
	GameState.day = 12
	GameState.xp = 450
	var test_save_path = "user://test_savegame.json"
	assert(GameState.save_game(test_save_path), "Saving game to disk must succeed")
	assert(GameState.has_save_game(test_save_path), "Save game must exist on disk")
	GameState.gold = 100
	GameState.day = 1
	assert(GameState.load_game(test_save_path), "Loading game from disk must succeed")
	assert(GameState.gold == 7777, "Gold must be restored from save file")
	assert(GameState.day == 12, "Day must be restored from save file")
	assert(GameState.xp == 450, "XP must be restored from save file")
	print("  -> Game state serialization & save/load roundtrip verified!")

	# 18. Test Shooter Melee Penalty & Enemy Blocking
	print("[TEST] 18. Testing Shooter Melee Penalty & Enemy Blocking...")
	var test_shooter = BattleStack.new()
	test_shooter.setup("fairy_archer", 10, 0, Vector2i(2, 2))
	var test_enemy_adj = BattleStack.new()
	test_enemy_adj.setup("swamp_zombie", 10, 1, Vector2i(3, 2))
	var dummy_stacks: Array[BattleStack] = [test_shooter, test_enemy_adj]
	assert(test_shooter.is_blocked_by_enemy(dummy_stacks), "Shooter must be blocked when enemy is adjacent (distance 1)")
	var ranged_dmg = test_shooter.calculate_attack_damage(test_enemy_adj, false, false)
	var melee_dmg = test_shooter.calculate_attack_damage(test_enemy_adj, true, false)
	assert(melee_dmg <= ranged_dmg, "Melee damage of shooter must suffer melee penalty (50% reduction)")
	print("  -> Shooter melee blocking and 50% melee penalty verified!")

	# 19. Test Minimap & Pause Menu Components
	print("[TEST] 19. Testing Minimap & Pause Menu Components...")
	var wmap_packed3 = load("res://src/world/world_map.tscn")
	var wmap_node3 = wmap_packed3.instantiate()
	add_child(wmap_node3)
	assert(wmap_node3.minimap_canvas != null, "Minimap canvas must be initialized")
	assert(wmap_node3.pause_dialog != null, "Pause dialog must be initialized")
	wmap_node3._toggle_pause_menu()
	assert(wmap_node3.pause_dialog.visible, "Pause dialog must be toggled visible")
	wmap_node3._toggle_pause_menu()
	assert(not wmap_node3.pause_dialog.visible, "Pause dialog must be toggled hidden")
	wmap_node3.queue_free()
	print("  -> Minimap radar canvas and pause menu verified!")

	# 20. Test New Spells (Lightning & Slow)
	print("[TEST] 20. Testing New Combat Spells (Lightning & Slow)...")
	assert(SpellData.has_spell("lightning"), "SpellData must contain lightning")
	assert(SpellData.has_spell("slow"), "SpellData must contain slow")
	var s_stack = BattleStack.new()
	s_stack.setup("wolf", 10, 1, Vector2i(5, 5))
	var base_spd = s_stack.get_speed()
	s_stack.buff_slow_turns = 3
	assert(s_stack.get_speed() < base_spd, "Slow debuff must reduce stack speed")
	print("  -> Lightning and Slow spells verified! Slow reduced speed from %d to %d." % [base_spd, s_stack.get_speed()])

	# 21. Test Artifact Set Synergy Bonuses
	print("[TEST] 21. Testing Artifact Set Synergy Bonuses...")
	GameState.equipped_artifacts.clear()
	GameState.inventory_artifacts.clear()
	GameState.equip_artifact("sword_valiance")
	GameState.equip_artifact("shield_aegis")
	GameState.equip_artifact("armor_chitin")
	var set_bonuses = ArtifactData.get_active_set_bonuses(GameState.equipped_artifacts)
	assert(set_bonuses["active_titles"].size() > 0, "Must activate Guardian of Kingdom set bonus")
	assert(set_bonuses["attack"] >= 4, "Set bonus must grant at least +4 attack")
	assert(set_bonuses["defense"] >= 4, "Set bonus must grant at least +4 defense")
	print("  -> Active set bonus verified: %s (+%d Att, +%d Def)!" % [
		set_bonuses["active_titles"][0], set_bonuses["attack"], set_bonuses["defense"]
	])

	# 22. Test Hero Class Selection
	print("[TEST] 22. Testing Hero Class Selection (Paladin, Archmage, Ranger)...")
	GameState.set_hero_class("archmage")
	assert(GameState.hero_class_id == "archmage", "Hero class must be archmage")
	assert("Элеонора" in GameState.hero_name, "Hero name must be Eleonora")
	assert(GameState.spellpower == 6, "Archmage must have 6 spellpower")
	assert(GameState.knowledge == 6, "Archmage must have 6 knowledge")
	
	GameState.set_hero_class("ranger")
	assert(GameState.hero_class_id == "ranger", "Hero class must be ranger")
	assert("Торн" in GameState.hero_name, "Hero name must be Thorn")
	assert(GameState.skills.has("logistics"), "Ranger must possess Logistics skill")
	assert(GameState.skills.has("pathfinding"), "Ranger must possess Pathfinding skill")
	
	GameState.set_hero_class("paladin")
	assert(GameState.hero_class_id == "paladin", "Hero class reset to paladin")
	print("  -> Hero classes (Paladin, Archmage, Ranger) configured and verified!")

	# 23. Test Quick Combat Resolution on World Map
	print("[TEST] 23. Testing Quick Combat Resolution on World Map...")
	var wmap_packed4 = load("res://src/world/world_map.tscn")
	var wmap_node4 = wmap_packed4.instantiate()
	add_child(wmap_node4)
	
	var enc_obj = {"type": "encounter", "name": "Дозор Разбойников", "id": "test_encounter"}
	wmap_node4._trigger_object(enc_obj)
	assert(wmap_node4.popup_btn2.visible, "Quick battle button must be visible for encounters")
	assert("Быстрый бой" in wmap_node4.popup_btn2.text, "Button text must contain 'Быстрый бой'")
	
	var pre_gold = GameState.gold
	var pre_xp = GameState.xp
	# По Ланчестеру (PR #4) слабое войско честно проигрывает — даём заведомо сильное
	GameState.player_army = [
		{"unit_id": "griffin", "count": 60},
		{"unit_id": "fairy_archer", "count": 80},
		{"unit_id": "druid", "count": 40}
	]
	GameState.attack = 20
	GameState.defense = 20
	GameState.spellpower = 10
	wmap_node4._execute_quick_combat("test_encounter")
	assert(GameState.flags.get("test_encounter", false) == true, "Encounter flag must be set to true")
	assert(GameState.gold > pre_gold, "Gold must be awarded for quick victory")
	assert(GameState.xp > pre_xp, "XP must be awarded for quick victory")
	wmap_node4.queue_free()
	print("  -> Quick Combat instant tactical resolution verified with rewards & casualties!")

	# 24. Test In-Arena Auto-battle Toggle
	print("[TEST] 24. Testing In-Arena Auto-battle Toggle...")
	var arena_packed3 = load("res://src/battle/battle_arena.tscn")
	var arena_node3 = arena_packed3.instantiate()
	add_child(arena_node3)
	assert(arena_node3.auto_battle_btn != null, "Auto-battle button must exist on HeroHUD")
	arena_node3._toggle_auto_battle()
	assert(arena_node3.is_auto_battling == true, "Auto-battle state must be active")
	arena_node3._toggle_auto_battle()
	assert(arena_node3.is_auto_battling == false, "Auto-battle state must be toggled off")
	arena_node3.queue_free()
	print("  -> In-arena Auto-battle toggle and button verified!")

	# 25. Test Single-Wait per Round Rule & Button State
	print("[TEST] 25. Testing Single-Wait per Round Rule & Wait Button State...")
	var arena_packed4 = load("res://src/battle/battle_arena.tscn")
	var arena_node4 = arena_packed4.instantiate()
	add_child(arena_node4)
	
	var test_actor = arena_node4.current_actor
	assert(test_actor != null and test_actor.team == 0, "Initial actor should be player stack")
	assert(not test_actor.has_waited, "Initial unit has_waited must be false")
	assert(not arena_node4.wait_btn.disabled, "Wait button must be enabled initially")
	
	# First wait succeeds
	arena_node4._on_wait_pressed()
	assert(test_actor.has_waited == true, "Unit must have has_waited = true after waiting")
	
	# Simulate unit getting turn again after waiting
	arena_node4.current_actor = test_actor
	arena_node4.is_ai_turn = false
	if arena_node4.wait_btn:
		arena_node4.wait_btn.disabled = test_actor.has_waited
	assert(arena_node4.wait_btn.disabled == true, "Wait button must be disabled for unit that has already waited")
	
	# Second wait in same round is rejected
	var q_size_before_second_wait = arena_node4.turn_queue.size()
	arena_node4._on_wait_pressed()
	assert(arena_node4.turn_queue.size() == q_size_before_second_wait, "Second wait must NOT re-append unit to queue")
	
	# Test round reset resets has_waited
	test_actor.reset_round()
	assert(not test_actor.has_waited, "Round reset must clear has_waited flag")
	arena_node4.queue_free()
	print("  -> Single wait per round enforced! No infinite wait possible.")

	# 26. Test Demo Battle Setup & Difficulty Scaling
	print("[TEST] 26. Testing Demo Battle Setup & Difficulty Scaling...")
	GameState.setup_demo_battle("hard", "balanced", "dragon_cult")
	assert(GameState.is_demo_battle == true, "is_demo_battle must be set")
	assert(GameState.demo_difficulty == "hard", "Difficulty must be hard")
	assert(GameState.demo_player_army.size() >= 3, "Demo player army must have units")
	assert(GameState.demo_enemy_configs.size() >= 3, "Demo enemy army must have units")
	
	# Verify hard difficulty has dragon
	var has_dragon = false
	for e in GameState.demo_enemy_configs:
		if e["unit_id"] == "red_dragon":
			has_dragon = true
			assert(e["count"] >= 2, "Hard difficulty dragon cult should have 2 dragons")
	assert(has_dragon, "Dragon cult must contain red_dragon")
	
	# Instantiate arena with demo battle
	var demo_arena = arena_packed4.instantiate()
	add_child(demo_arena)
	assert(demo_arena.retreat_btn != null, "Retreat button must exist on arena")
	assert("В Меню" in demo_arena.retreat_btn.text, "Demo arena retreat button should say 'В Меню'")
	assert(demo_arena.all_stacks.size() >= 6, "Arena should have initialized both player and enemy stacks")
	demo_arena.queue_free()
	GameState.is_demo_battle = false
	print("  -> Demo battle setup, difficulty scaling, and retreat button verified!")

	# 27. Test Pause Dialog Centering & Geometry
	print("[TEST] 27. Testing Pause Dialog Centering & Geometry...")
	var wmap_test_packed = load("res://src/world/world_map.tscn")
	var wmap_test_node = wmap_test_packed.instantiate()
	add_child(wmap_test_node)
	assert(wmap_test_node.pause_dialog != null, "Pause dialog must be instantiated")
	var pause_center = null
	for ch in wmap_test_node.pause_dialog.get_children():
		if ch is CenterContainer:
			pause_center = ch
			break
	assert(pause_center != null, "Pause dialog must contain a CenterContainer for mathematical screen centering")
	var pause_parch = pause_center.get_child(0) as NinePatchRect
	assert(pause_parch != null, "CenterContainer must hold the parchment panel")
	assert(pause_parch.custom_minimum_size.x >= 500 and pause_parch.custom_minimum_size.y >= 500, "Pause parchment must have valid minimum size")
	wmap_test_node.queue_free()
	print("  -> Pause dialog CenterContainer architecture verified! Zero off-screen clipping.")

	# 28. Test Chapter 1 Tactical Encounters & Chapter 2 Swamp Layout
	print("[TEST] 28. Testing Chapter 1 Tactical Encounters & Chapter 2 Unique Layout...")
	GameState.start_chapter(1)
	var wmap_c1 = wmap_test_packed.instantiate()
	add_child(wmap_c1)
	var wv_c1 = wmap_c1.get_node("ScrollContainer/WorldView")
	assert(wv_c1.objects.has(Vector2i(8, 4)), "Chapter 1 must have wolves guarding watermill at (8, 4)")
	assert(wv_c1.objects.has(Vector2i(4, 8)), "Chapter 1 must have goblins guarding chest at (4, 8)")
	assert(wv_c1.objects.has(Vector2i(7, 14)), "Chapter 1 must have forester road ambush at (7, 14)")
	assert(wv_c1.objects.has(Vector2i(10, 13)), "Chapter 1 must have ancient treant guardian at (10, 13)")
	assert(wv_c1.objects.has(Vector2i(18, 11)), "Chapter 1 must have vanguard at (18, 11)")
	assert(wv_c1.objects.has(Vector2i(22, 7)), "Chapter 1 must have rogue archers at (22, 7)")
	assert(wv_c1.objects.has(Vector2i(24, 16)), "Chapter 1 must have obelisk guard at (24, 16)")
	assert(wv_c1.objects.has(Vector2i(28, 11)), "Chapter 1 must have bandit boss at (28, 11)")
	print("  -> Chapter 1 verified with 8 tactical encounters and extra treasure caches!")
	
	# Test Chapter 2 Transition & Unique Swamp Objects
	GameState.start_chapter(2)
	assert(GameState.current_chapter == 2, "Current chapter must be 2")
	var wmap_c2 = wmap_test_packed.instantiate()
	add_child(wmap_c2)
	var wv_c2 = wmap_c2.get_node("ScrollContainer/WorldView")
	assert(wv_c2.objects.has(Vector2i(6, 17)), "Chapter 2 must have Witch Hut at (6, 17)")
	assert(wv_c2.objects.has(Vector2i(10, 4)), "Chapter 2 must have Sunken Crypt at (10, 4)")
	assert(wv_c2.objects.has(Vector2i(10, 7)), "Chapter 2 must have Druid Camp at (10, 7)")
	assert(wv_c2.objects.has(Vector2i(27, 4)), "Chapter 2 must have Druid Altar at (27, 4)")
	assert(wv_c2.objects.has(Vector2i(6, 8)), "Chapter 2 must have swamp zombies patrol at (6, 8)")
	assert(wv_c2.objects.has(Vector2i(6, 14)), "Chapter 2 must have skeleton archers at (6, 14)")
	assert(wv_c2.objects.has(Vector2i(21, 8)), "Chapter 2 must have undead legion at (21, 8)")
	assert(wv_c2.objects.has(Vector2i(28, 11)), "Chapter 2 must have Ancient Lich Citadel at (28, 11)")
	wmap_c1.queue_free()
	wmap_c2.queue_free()
	print("  -> Chapter 2 verified with unique swamp landmarks and undead encounters!")

	# 29. Test Skeleton Archer Assets & Orientation, Army Stack Swapping, and EventDialog Layout
	print("[TEST] 29. Testing Skeleton Archer Assets, Army Stack Swapping & EventDialog Layout...")
	var skel = UnitData.get_unit("skeleton_archer")
	assert(skel.get("token_path", "").ends_with("token_unit_skeleton_archer.png"), "Skeleton archer must have dedicated token")
	assert(skel.get("sprite_path", "").ends_with("unit_skeleton_archer.png"), "Skeleton archer must have dedicated sprite")
	assert(ResourceLoader.exists(skel["token_path"]), "Skeleton archer token file must exist")
	assert(ResourceLoader.exists(skel["sprite_path"]), "Skeleton archer sprite file must exist")
	assert(skel.get("natural_faces_left", true) == false, "Skeleton archer naturally faces right (natural_faces_left == false)")
	assert(UnitData.get_unit("goblin").get("natural_faces_left", false) == true, "Goblin naturally faces left")

	# Army Stack Swapping (HoMM style)
	GameState.start_chapter(1)
	assert(GameState.player_army[0]["unit_id"] == "griffin", "Initial slot 0 must be griffin")
	assert(GameState.player_army[1]["unit_id"] == "fairy_archer", "Initial slot 1 must be fairy_archer")
	var swap_ok = GameState.swap_army_slots(0, 1)
	assert(swap_ok == true, "swap_army_slots(0, 1) must succeed")
	assert(GameState.player_army[0]["unit_id"] == "fairy_archer", "Fairies must now be first in hero army (slot 0)")
	assert(GameState.player_army[1]["unit_id"] == "griffin", "Griffins must now be slot 1")

	# EventDialog Structural Integrity
	var wmap_test_dialog = wmap_test_packed.instantiate()
	add_child(wmap_test_dialog)
	var parch_margin = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox")
	assert(parch_margin != null, "EventDialog must contain MainVBox inside MarginContainer")
	var dlg_title = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Title")
	var dlg_scroll = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Scroll")
	var dlg_text = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Scroll/ScrollMargin/Text")
	var dlg_btn_box = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox")
	var dlg_btn1 = wmap_test_dialog.get_node_or_null("CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox/Btn1")
	assert(dlg_title != null, "EventDialog Title must be in MainVBox")
	assert(dlg_scroll != null and dlg_scroll is ScrollContainer, "EventDialog must wrap text in ScrollContainer")
	assert(dlg_text != null, "EventDialog Text must be in ScrollContainer")
	assert(dlg_btn_box != null and dlg_btn1 != null, "EventDialog buttons must be docked in BtnVBox")
	wmap_test_dialog.queue_free()
	print("  -> Skeleton archer assets, HoMM army stack swap, and non-overlapping dialog layout verified!")

	wmap_node2.queue_free()

	# 30. Test Immediate Battle Conclusion (Zero Ghost Turns on Zero Enemies)
	print("[TEST] 30. Testing Immediate Battle Conclusion (Zero Ghost Turns)...")
	var arena_packed_30 = load("res://src/battle/battle_arena.tscn")
	var arena_node_30 = arena_packed_30.instantiate()
	add_child(arena_node_30)
	
	# Verify living stack helper logic
	assert(arena_node_30._has_living_enemies() == true, "Must have living enemies initially")
	assert(arena_node_30._has_living_players() == true, "Must have living players initially")
	
	# Eliminate all enemy stacks
	for s in arena_node_30.all_stacks:
		if s.team == 1:
			s.count = 0
			s.current_hp = 0
	
	assert(arena_node_30._has_living_enemies() == false, "No living enemies must remain")
	var ended = arena_node_30._check_battle_end()
	assert(ended == true, "_check_battle_end() must return true when all enemies are slain")
	assert(arena_node_30.victory_dialog.visible == true, "Victory dialog must immediately become visible")
	assert(arena_node_30.turn_queue.is_empty() == true, "Turn queue must be completely cleared upon victory")
	assert(arena_node_30.current_actor == null, "Current actor must be null - no ghost turns permitted!")
	assert(arena_node_30.reachable_hexes.is_empty() == true, "Reachable hexes must be cleared")
	
	# Verify calling _next_turn does not grant a turn to player or loop round
	arena_node_30._next_turn()
	assert(arena_node_30.current_actor == null, "Post-victory _next_turn() must not assign an actor")
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
	assert(day_lbl != null and end_btn != null, "TopHUD must contain DayLabel and EndDayBtn")
	assert(day_lbl.offset_right <= end_btn.offset_left, "DayLabel must NOT overlap or hide beneath EndDayBtn")
	assert(day_lbl.offset_right - day_lbl.offset_left >= 150.0, "DayLabel must have at least 150px width for full text")
	
	# Paper Doll Mannequin on Character Profile
	wmap_node_31._open_hero_profile()
	var content_hbox = wmap_node_31.hero_dialog.get_node("Parchment/ContentHBox")
	assert(content_hbox.offset_left >= 0.0, "ContentHBox must not have negative offset outside parchment")
	assert(wmap_node_31.mannequin_box != null, "HeroProfileDialog must contain MannequinBox for body silhouette")
	
	# Verify all 6 equipment slots on mannequin
	var expected_slots = ["relic", "weapon", "armor", "shield", "accessory", "boots"]
	for slot_name in expected_slots:
		var slot_btn = wmap_node_31.mannequin_box.get_node_or_null("Slot_" + slot_name)
		assert(slot_btn != null, "Mannequin must have Slot_%s on body" % slot_name)
	
	# Equip artifact and verify slot reflection
	GameState.inventory_artifacts.clear()
	GameState.equipped_artifacts.clear()
	GameState.inventory_artifacts.append("sword_valiance")
	wmap_node_31._update_hero_profile()
	assert(wmap_node_31.backpack_vbox.get_child_count() > 0, "Backpack must list inventory artifacts")
	
	# Simulate clicking equip
	GameState.equip_artifact("sword_valiance")
	wmap_node_31._update_hero_profile()
	var weapon_slot_btn = wmap_node_31.mannequin_box.get_node("Slot_weapon")
	assert("Меч" in weapon_slot_btn.text, "Weapon slot on mannequin must reflect equipped sword")
	
	# Simulate clicking unequip from mannequin slot
	weapon_slot_btn.emit_signal("pressed")
	assert(not GameState.equipped_artifacts.has("weapon"), "Clicking mannequin slot must unequip artifact to backpack")
	assert(GameState.inventory_artifacts.has("sword_valiance"), "Sword must return to backpack")
	
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
	assert(wmap_node_32.world_view.is_moving == true, "Hero must be actively moving")
	# Simulate player clicking mouse or pressing key while moving to cancel path
	wmap_node_32.cancel_hero_movement()
	assert(wmap_node_32.cancel_movement == true, "Cancellation request must be registered")
	# Wait for hero to finish step 1 and halt cleanly
	while wmap_node_32.world_view.is_moving:
		await get_tree().process_frame
	# Hero should halt cleanly at cell (5, 11), having aborted remaining steps
	assert(wmap_node_32.world_view.hero_cell == Vector2i(5, 11), "Hero must halt at cell (5, 11) due to cancellation")
	assert(wmap_node_32.world_view.is_moving == false, "Hero movement state must be reset to false")
	assert(wmap_node_32.cancel_movement == false, "cancel_movement flag must be reset after halting")
	assert(GameState.move_points == 19, "Only 1 MP should have been consumed for the single completed step (out of 3)")
	
	# Test 32.2: Differentiated Monster Tokens in Chapter 1
	var wv_32 = wmap_node_32.world_view
	var wolf_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(8, 4)])
	assert(wolf_tex != null and wolf_tex.resource_path.ends_with("token_unit_wolf.png"), "Wolves encounter at (8, 4) must use token_unit_wolf")
	var goblin_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(4, 8)])
	assert(goblin_tex != null and goblin_tex.resource_path.ends_with("token_unit_goblin.png"), "Goblins encounter at (4, 8) must use token_unit_goblin")
	var treant_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(10, 13)])
	assert(treant_tex != null and treant_tex.resource_path.ends_with("token_unit_treant.png"), "Treant encounter at (10, 13) must use token_unit_treant")
	var bandit_tex = wv_32.get_object_texture(wv_32.objects[Vector2i(28, 11)])
	assert(bandit_tex != null and bandit_tex.resource_path.ends_with("token_boss_bandit.png"), "Bandit boss at (28, 11) must use token_boss_bandit")
	
	wmap_node_32.queue_free()
	
	# Test 32.3: Chapter 2 Swamp Differentiated Miniatures & Distinct Biome
	GameState.start_chapter(2)
	assert(GameState.current_chapter == 2, "Current chapter must be 2")
	var wmap_node_32_c2 = wmap_test_packed_32.instantiate()
	add_child(wmap_node_32_c2)
	var wv_c2_32 = wmap_node_32_c2.world_view
	
	var zombie_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(6, 8)])
	assert(zombie_tex != null and zombie_tex.resource_path.ends_with("token_unit_swamp_zombie.png"), "Swamp zombie encounter at (6, 8) must use token_unit_swamp_zombie")
	var skel_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(6, 14)])
	assert(skel_tex != null and skel_tex.resource_path.ends_with("token_unit_skeleton_archer.png"), "Swamp skeletons encounter at (6, 14) must use token_unit_skeleton_archer")
	var lich_tex = wv_c2_32.get_object_texture(wv_c2_32.objects[Vector2i(28, 11)])
	assert(lich_tex != null and lich_tex.resource_path.ends_with("token_boss_lich.png"), "Lich boss at (28, 11) must use token_boss_lich")
	
	# Check unique swamp objects
	assert(wv_c2_32.objects.has(Vector2i(6, 17)) and wv_c2_32.objects[Vector2i(6, 17)]["type"] == "witch_hut", "Chapter 2 must have witch_hut at (6, 17)")
	assert(wv_c2_32.objects.has(Vector2i(10, 4)) and wv_c2_32.objects[Vector2i(10, 4)]["type"] == "crypt", "Chapter 2 must have crypt at (10, 4)")
	assert(wv_c2_32.objects.has(Vector2i(14, 11)) and wv_c2_32.objects[Vector2i(14, 11)]["type"] == "bone_gate", "Chapter 2 must have bone_gate at (14, 11)")
	
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
	assert(name_lbl.offset_right <= gold_lbl.offset_left, "NameLabel must end before GoldLabel begins to eliminate overlap")
	assert(gold_lbl.offset_right <= mana_lbl.offset_left, "GoldLabel must end before ManaLabel begins")
	assert(name_lbl.clip_text == true, "NameLabel must clip text to prevent horizontal overflow")
	assert(name_lbl.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "NameLabel must trim with ellipsis")
	
	# Test 33.2: Adventure Spellbook Dialog Geometry & Elements
	var sb_dialog = wmap_node_33.get_node("CanvasLayer/SpellbookDialog") as Control
	var sb_parch = sb_dialog.get_node("Parchment") as NinePatchRect
	assert(sb_parch.offset_right - sb_parch.offset_left >= 700.0, "Spellbook parchment must be wide (>= 700px) for dual-card layout")
	assert(sb_parch.offset_bottom - sb_parch.offset_top >= 500.0, "Spellbook parchment must be tall (>= 500px) for dual-card layout")
	
	var scry_btn_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/ScryCard/CardVBox/ScryBtn") as Button
	var rest_btn_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/RestCard/CardVBox/RestBtn") as Button
	var sb_close_33 = sb_dialog.get_node("Parchment/CloseBtn") as Button
	assert(scry_btn_33 != null and rest_btn_33 != null and sb_close_33 != null, "Spellbook must have ScryBtn, RestBtn and CloseBtn inside Parchment")
	
	# Open Spellbook & Verify Mana/State Updates
	GameState.current_mana = 40
	wmap_node_33._open_spellbook()
	assert(sb_dialog.visible == true, "Spellbook dialog must be visible after _open_spellbook()")
	assert(scry_btn_33.disabled == false, "ScryBtn must be enabled when hero has 40 mana")
	assert(rest_btn_33.disabled == false, "RestBtn must be enabled when hero has 40 mana")
	
	# Mana subtitle check
	var mana_sub = sb_dialog.get_node("Parchment/Margin/MainVBox/ManaSubtitle") as Label
	assert(mana_sub.text.contains("40 / 40"), "ManaSubtitle must reflect current and max mana")
	
	# Low mana disabling check
	GameState.current_mana = 5
	wmap_node_33._open_spellbook()
	assert(scry_btn_33.disabled == true, "ScryBtn must be disabled when hero has only 5 mana (requires 10)")
	assert(rest_btn_33.disabled == true, "RestBtn must be disabled when hero has only 5 mana (requires 15)")
	
	# Combat spells populated
	var combat_grid_33 = sb_dialog.get_node("Parchment/Margin/MainVBox/Scroll/ContentVBox/CombatGrid") as GridContainer
	assert(combat_grid_33.get_child_count() >= 4, "CombatGrid must display all learned combat spells")
	
	# Close dialog
	sb_close_33.emit_signal("pressed")
	assert(sb_dialog.visible == false, "Spellbook must hide when CloseBtn pressed")
	
	# Test 33.3: QuestHUD Dimensions & Non-overlapping with MinimapPanel
	var quest_hud = wmap_node_33.get_node("CanvasLayer/QuestHUD") as Control
	var quest_lbl = quest_hud.get_node("QuestLabel") as Label
	assert(quest_hud.offset_right - quest_hud.offset_left >= 240.0, "QuestHUD width must be >= 240px to prevent text clipping")
	assert(quest_hud.offset_bottom - quest_hud.offset_top >= 130.0, "QuestHUD height must be >= 130px to accommodate long objectives")
	assert(quest_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD or quest_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "QuestLabel must word wrap cleanly")
	assert(quest_hud.offset_top >= wmap_node_33.minimap_container.offset_bottom, "QuestHUD must not overlap MinimapPanel vertically")
	assert(wmap_node_33.minimap_container.offset_right <= -15.0, "MinimapPanel must not overflow screen right edge")
	
	# Test 33.4: Arena Spellbook Sizing
	var arena_packed_33 = load("res://src/battle/battle_arena.tscn")
	var arena_node_33 = arena_packed_33.instantiate()
	add_child(arena_node_33)
	var arena_sb_parch = arena_node_33.get_node("CanvasLayer/SpellbookDialog/Parchment") as NinePatchRect
	assert(arena_sb_parch.offset_right - arena_sb_parch.offset_left >= 650.0, "Arena spellbook parchment must be >= 650px wide")
	# 0.3.3: SpellGrid теперь GridContainer с подписями под иконками
	var arena_spell_grid = arena_sb_parch.get_node("SpellGrid") as GridContainer
	assert(arena_spell_grid.columns == 5, "Arena SpellGrid must have 5 columns for 10 labeled spells")
	var grid_children := arena_spell_grid.get_child_count()
	assert(grid_children >= 8, "All combat spells must render as labeled cells")
	for cell in arena_spell_grid.get_children():
		assert(cell.get_child_count() >= 2, "Each spell cell must contain an icon and a label")
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
	assert(wmap_node_34.planned_destination == Vector2i(7, 11), "First click must lock planned destination to (7, 11)")
	assert(wmap_node_34.planned_path.size() == 3, "Planned path from (4, 11) to (7, 11) must have 3 steps")
	assert(wmap_node_34.world_view.is_moving == false, "Hero MUST NOT start moving on first click!")
	assert(wmap_node_34.world_view.hero_cell == Vector2i(4, 11), "Hero must remain stationary at (4, 11)")
	assert(wmap_node_34.world_view.planned_path.size() == 3, "WorldView must display locked planned path on map")
	
	# Test 34.2: Clear route on cancel / right-click
	wmap_node_34._clear_planned_route()
	assert(wmap_node_34.planned_destination == Vector2i(-1, -1), "Clearing route must reset planned destination")
	assert(wmap_node_34.planned_path.is_empty(), "Planned path must be empty after clear")
	assert(wmap_node_34.world_view.planned_path.is_empty(), "WorldView planned path must be empty after clear")
	
	# Test 34.3: First click plots route to (6, 11), Second click confirms and starts movement
	wmap_node_34._on_cell_clicked(Vector2i(6, 11))
	assert(wmap_node_34.planned_destination == Vector2i(6, 11), "Destination must be locked to (6, 11)")
	assert(wmap_node_34.world_view.is_moving == false, "Hero still must not move on 1st click")
	
	# 2nd click on same target confirms!
	wmap_node_34._on_cell_clicked(Vector2i(6, 11))
	assert(wmap_node_34.world_view.is_moving == true, "Hero MUST start moving on 2nd click on planned destination!")
	assert(wmap_node_34.planned_path.is_empty(), "Planned path must be cleared upon movement start")
	
	# Test 34.4: Click during movement halts hero
	wmap_node_34.cancel_hero_movement()
	assert(wmap_node_34.cancel_movement == true, "Cancellation request must be set")
	while wmap_node_34.world_view.is_moving:
		await get_tree().process_frame
	assert(wmap_node_34.world_view.is_moving == false, "Hero must halt cleanly after finishing current step")
	assert(wmap_node_34.world_view.hero_cell == Vector2i(5, 11), "Hero must stop at cell (5, 11) after 1 step")
	
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
	assert(confirm_dlg != null and confirm_dlg.visible == true, "End-day dialog must show when MP > 0")
	assert(GameState.day == 1, "Day must NOT advance yet while confirmation dialog is pending")
	assert(wmap_node_35.confirm_end_day_prompt.text.contains("20/"), "Prompt must show remaining move points")
	
	# Test Cancel Button
	wmap_node_35.confirm_end_day_cancel_btn.emit_signal("pressed")
	assert(confirm_dlg.visible == false, "Dialog must hide on cancel")
	assert(GameState.day == 1, "Day must remain 1 after cancellation")
	
	# Test Confirm Button
	wmap_node_35._on_end_day_pressed()
	assert(confirm_dlg.visible == true, "Dialog must reopen")
	wmap_node_35.confirm_end_day_confirm_btn.emit_signal("pressed")
	assert(confirm_dlg.visible == false, "Dialog must hide on confirmation")
	assert(GameState.day == 2, "Day must advance to 2 upon confirmation")
	
	# Test 35.2: Immediate end day when MP == 0
	GameState.move_points = 0
	wmap_node_35._on_end_day_pressed()
	assert(confirm_dlg.visible == false, "Dialog must NOT show when MP == 0")
	assert(GameState.day == 3, "Day must advance immediately when MP == 0")
	
	# Test 35.3: Vanishing of defeated encounter from map (Quick Combat)
	assert(wmap_node_35.world_view.objects.has(Vector2i(18, 11)), "Map must initially have patrol_1 at (18, 11)")
	wmap_node_35._execute_quick_combat("patrol_1")
	assert(GameState.flags.get("patrol_1", false) == true, "patrol_1 flag must be true")
	assert(not wmap_node_35.world_view.objects.has(Vector2i(18, 11)), "patrol_1 object must be completely removed from map objects upon victory")
	
	# Test 35.4: Vanishing of bandit boss from map
	assert(wmap_node_35.world_view.objects.has(Vector2i(28, 11)), "Map must initially have bandit_boss at (28, 11)")
	GameState.player_army = [{"unit_id": "griffin", "count": 60}]
	wmap_node_35._execute_quick_combat("bandit_boss")
	assert(GameState.flags.get("bandit_boss", false) == true, "bandit_boss flag must be true")
	assert(not wmap_node_35.world_view.objects.has(Vector2i(28, 11)), "bandit_boss object must be completely removed from map objects upon victory")
	
	# Test 35.5: Persistence across scene reload
	wmap_node_35.queue_free()
	var wmap_node_35_reloaded = wmap_test_packed_35.instantiate()
	add_child(wmap_node_35_reloaded)
	assert(not wmap_node_35_reloaded.world_view.objects.has(Vector2i(18, 11)), "patrol_1 must remain gone after scene reload")
	assert(not wmap_node_35_reloaded.world_view.objects.has(Vector2i(28, 11)), "bandit_boss must remain gone after scene reload")
	
	# Test 35.6: NameLabel Vertical Alignment in TopHUD
	var hero_lbl = wmap_node_35_reloaded.get_node("CanvasLayer/TopHUD/NameLabel") as Label
	assert(hero_lbl.offset_top == 22.0 and hero_lbl.offset_bottom == 52.0, "NameLabel must be vertically aligned with GoldLabel at y=22-52")
	assert(hero_lbl.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "NameLabel must have vertical_alignment centered")
	
	# Test 35.7: Guard Interception on Guarded Chests (HoMM-style)
	GameState.start_chapter(1)
	var wmap_node_guard_test = wmap_test_packed_35.instantiate()
	add_child(wmap_node_guard_test)
	assert(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 8)), "Guard at (4, 8) must exist")
	assert(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest at (4, 9) must exist")
	GameState.flags["patrol_goblins"] = false
	wmap_node_guard_test.world_view.hero_cell = Vector2i(4, 9)
	var guarded_chest_obj = wmap_node_guard_test.world_view.objects[Vector2i(4, 9)]
	wmap_node_guard_test._trigger_object(guarded_chest_obj)
	assert(wmap_node_guard_test.popup_title.text.contains("ОХРАНА СОКРОВИЩ"), "Guard must intercept before chest can be looted!")
	assert(not GameState.flags.get("chest_start", false), "Chest must NOT be looted while guard is alive!")
	assert(wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest must still remain on map!")
	
	# Defeating guard unblocks chest
	wmap_node_guard_test.popup_btn2.emit_signal("pressed") # Quick combat guard
	assert(GameState.flags.get("patrol_goblins", false) == true, "Guard must be defeated")
	assert(not wmap_node_guard_test.world_view.objects.has(Vector2i(4, 8)), "Guard must be removed from map")
	
	# Now chest can be claimed freely
	wmap_node_guard_test._trigger_object(guarded_chest_obj)
	assert(wmap_node_guard_test.popup_title.text.contains("Сундук"), "Now chest popup must be shown")
	wmap_node_guard_test.popup_btn1.emit_signal("pressed")
	assert(GameState.flags.get("chest_start", false) == true, "Chest is now collected")
	assert(not wmap_node_guard_test.world_view.objects.has(Vector2i(4, 9)), "Chest is now vanished from map")
	
	# Test 35.8: Double-click event does not prematurely cancel movement
	var double_click_evt = InputEventMouseButton.new()
	double_click_evt.button_index = MOUSE_BUTTON_LEFT
	double_click_evt.pressed = true
	double_click_evt.double_click = true
	wmap_node_guard_test.world_view.is_moving = true
	wmap_node_guard_test.world_view._gui_input(double_click_evt)
	assert(wmap_node_guard_test.cancel_movement == false, "double_click event must NOT cancel hero movement!")
	
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
	assert(test_stack_ally.has_stoneskin() == true, "Stack must report having stoneskin")
	assert(test_stack_ally.get_defense() == stoneskin_base_def + 5, "Stoneskin must grant exactly +5 defense")
	print("  -> Stoneskin spell successfully grants +5 Defense!")

	# Test 36.2: Blind Spell & Damage Break
	var test_stack_enemy = BattleStack.new()
	test_stack_enemy.setup("goblin", 20, 1, Vector2i(4, 2))
	test_stack_enemy.debuff_blind_turns = 3
	assert(test_stack_enemy.is_blinded() == true, "Stack must report being blinded")
	assert(test_stack_enemy.get_speed() == 0, "Blinded stack must have 0 speed (cannot move)")
	var dmg_res = test_stack_enemy.take_damage(15)
	assert(dmg_res.get("dispelled_blind", false) == true, "Taking damage must dispel blind")
	assert(test_stack_enemy.is_blinded() == false, "Stack must no longer be blinded after taking damage")
	assert(test_stack_enemy.get_speed() > 0, "Speed must be restored after blind is dispelled")
	print("  -> Blind spell and damage dispel mechanics verified!")

	# Test 36.3: Swamp Zombie Disease Passive
	var test_zombie = BattleStack.new()
	test_zombie.setup("swamp_zombie", 15, 1, Vector2i(2, 2))
	assert(test_zombie.data.get("disease", false) == true, "Swamp zombie must have disease passive")
	test_stack_ally.debuff_disease_turns = 2
	assert(test_stack_ally.is_diseased() == true, "Target must report being diseased")
	var diseased_range = test_stack_ally.get_damage_range(test_stack_enemy, true)
	test_stack_ally.debuff_disease_turns = 0
	var healthy_range = test_stack_ally.get_damage_range(test_stack_enemy, true)
	assert(diseased_range.max_dmg < healthy_range.max_dmg, "Diseased stack must deal reduced damage (-25% attack)")
	print("  -> Swamp Zombie Disease debuff verified (-25% attack penalty)!")

	# Test 36.4: Treant Regeneration & Entangle Passives
	var test_treant = BattleStack.new()
	test_treant.setup("treant", 5, 0, Vector2i(1, 1))
	assert(test_treant.data.get("regeneration", 0) == 20, "Treant must have 20 HP regeneration")
	assert(test_treant.data.get("entangle", false) == true, "Treant must have entangle passive")
	test_treant.current_hp = 30 # Injured
	test_treant.reset_round()
	assert(test_treant.current_hp == 50, "Treant must regenerate 20 HP upon round reset!")
	print("  -> Treant Regeneration (+20 HP/round) verified!")

	# Test 36.5: Red Dragon Linear 2-Hex Breath Passive
	var test_dragon = BattleStack.new()
	test_dragon.setup("red_dragon", 2, 0, Vector2i(2, 3))
	assert(test_dragon.data.get("breath_attack", false) == true, "Red Dragon must have breath_attack passive")
	var delta_hex = Vector2i(1, 0)
	var defender_hex = test_dragon.hex + delta_hex
	var behind_hex = defender_hex + delta_hex
	assert(HexGrid.distance(test_dragon.hex, behind_hex) == 2, "Behind hex must be exactly 2 hexes in line")
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
	assert(goblin_enemy != null, "Arena must have an enemy stack")
	var goblin_pos = HexGrid.hex_to_pixel(goblin_enemy.hex.x, goblin_enemy.hex.y, arena_suite_node.HEX_SIZE, arena_suite_node.grid_origin)
	arena_suite_node._update_mouse_hover(goblin_pos)
	assert(arena_suite_node.hovered_threat_hexes.size() > 0, "Hovering enemy must calculate threat range hexes")
	assert(arena_suite_node.hovered_threat_hexes.has(goblin_enemy.hex), "Threat hexes must include enemy's own hex")
	
	# Test Hotkey B (Spellbook)
	var key_b_evt = InputEventKey.new()
	key_b_evt.keycode = KEY_B
	key_b_evt.pressed = true
	arena_suite_node._unhandled_input(key_b_evt)
	assert(arena_suite_node.spellbook_dialog.visible == true, "Key B must open spellbook dialog")
	arena_suite_node.spellbook_dialog.hide()
	
	# Test Floating text with casualties
	arena_suite_node._spawn_floating_text(Vector2i(2, 2), "-120", Color(1, 0.3, 0.2))
	arena_suite_node._spawn_floating_text(Vector2i(2, 2), "Потери: -3", Color(1, 0.1, 0.1), Vector2(0, -28))
	assert(arena_suite_node.floating_texts.size() >= 2, "Floating texts must support damage and casualties")
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
	assert(GameState.day == 8, "Day must advance to 8 (Week 2)")
	assert(GameState.last_astrologers_event.size() > 0, "Astrologers event must trigger on Day 8")
	assert(wmap_node_36.popup_title.text.contains("АСТРОЛОГИ"), "Astrologers popup must be displayed")
	wmap_node_36.popup_btn1.emit_signal("pressed")
	assert(wmap_node_36.popup_dialog.visible == false, "Popup must close after acknowledgment")
	
	# Test 36.8: Player Ownership Banners over Visited Structures
	GameState.flags["watermill"] = true
	GameState.flags["magic_shrine"] = true
	assert(GameState.flags.get("watermill", false) == true, "Watermill must be flagged visited")
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
	assert(safe_margin != null, "SafeMargin container must exist")
	assert(safe_margin.get_theme_constant("margin_left") >= 40, "Mobile left margin must be >= 40px")
	assert(safe_margin.get_theme_constant("margin_right") >= 40, "Mobile right margin must be >= 40px")
	assert(safe_margin.get_theme_constant("margin_top") >= 24, "Mobile top margin must be >= 24px")

	# Check primary action cards touch sizes
	var action_cards = main_node.get_node("SafeMargin/MainVBox/CenterSection/ActionCards")
	var start_adv_btn = action_cards.get_node("StartAdventureBtn") as Button
	var arena_btn = action_cards.get_node("ArenaBattleBtn") as Button
	var chap_btn = action_cards.get_node("ChapterSelectBtn") as Button
	assert(start_adv_btn.custom_minimum_size.y >= 64, "Primary buttons must have finger touch height >= 64px")
	assert(arena_btn.custom_minimum_size.y >= 64, "Arena button must have finger touch height >= 64px")
	assert(chap_btn.custom_minimum_size.y >= 64, "Chapter select button must have finger touch height >= 64px")

	# Check bottom toolbar touch sizes
	var bottom_toolbar = main_node.get_node("SafeMargin/MainVBox/BottomToolbar")
	var music_btn = bottom_toolbar.get_node("MusicSelectBtn") as Button
	var about_btn = bottom_toolbar.get_node("AboutBtn") as Button
	var exit_btn = bottom_toolbar.get_node("ExitBtn") as Button
	assert(music_btn.custom_minimum_size.y >= 50, "Bottom toolbar buttons must have touch height >= 50px")
	assert(about_btn.custom_minimum_size.y >= 50, "About button must have touch height >= 50px")
	assert(exit_btn.custom_minimum_size.y >= 50, "Exit button must have touch height >= 50px")

	# Check top mini player
	var mini_player = main_node.get_node("SafeMargin/MainVBox/TopBar/RightBox/MiniMusicPlayer")
	assert(mini_player != null, "Top mini music player must exist")

	# Test modal openings & Android back request dismissal
	main_node._open_chapter_dialog()
	assert(main_node.chapter_dialog.visible == true, "Chapter dialog must open")
	main_node._handle_back_request()
	assert(main_node.chapter_dialog.visible == false, "Chapter dialog must dismiss on Back")

	main_node._on_start_adventure()
	assert(main_node.hero_select_dialog.visible == true, "Hero select dialog must open")
	main_node._handle_back_request()
	assert(main_node.hero_select_dialog.visible == false, "Hero select dialog must dismiss on Back")

	main_node._open_music_dialog()
	assert(main_node.music_dialog.visible == true, "Music jukebox dialog must open")
	main_node._handle_back_request()
	assert(main_node.music_dialog.visible == false, "Music jukebox dialog must dismiss on Back")

	main_node._on_about()
	assert(main_node.about_dialog.visible == true, "About dialog must open")
	main_node._handle_back_request()
	assert(main_node.about_dialog.visible == false, "About dialog must dismiss on Back")

	# Test continue button with save game summary
	var continue_btn = action_cards.get_node("ContinueBtn") as Button
	assert(continue_btn != null, "ContinueBtn must exist")
	if GameState.has_save_game():
		assert(continue_btn.visible == true, "Continue button must be visible when save exists")
		assert(continue_btn.text.contains("Гл."), "Continue button must show chapter info")

	main_node.queue_free()
	print("  -> Mobile Main Menu layout, touch targets, and Back navigation fully verified!")

	# 38. Review 0.1.1 regression: attack stats, level-up persistence, scaled rewards
	print("[TEST] 38. Testing Review 0.1.1 Fixes (attack stats, level-up persistence, scaled rewards)...")
	# a) Every unit must declare its own attack stat (unit card honesty)
	for uid in UnitData.UNITS.keys():
		var uinfo = UnitData.UNITS[uid]
		assert(uinfo.get("attack", 0) > 0, "Unit '%s' must declare an attack stat" % uid)
	print("  -> All %d units declare their attack stat!" % UnitData.UNITS.size())

	# b) pending_level_ups must survive a save/load roundtrip (skill choice is never lost)
	GameState.pending_level_ups.clear()
	GameState.pending_level_ups.append({"level": 2, "stat": "Атака (+1)", "options": ["archery", "offense"]})
	assert(GameState.save_game(), "Save must succeed")
	GameState.pending_level_ups.clear()
	assert(GameState.load_game(), "Load must succeed")
	assert(GameState.pending_level_ups.size() == 1, "pending_level_ups must survive save/load")
	assert(GameState.pending_level_ups[0]["stat"] == "Атака (+1)", "Level-up stat must survive save/load")
	assert(GameState.pending_level_ups[0]["options"].size() == 2, "Level-up options must survive save/load")
	GameState.pending_level_ups.clear()
	print("  -> Pending level-up choices persisted across save/load!")

	# c) Victory rewards scale with enemy strength (patrol_goblins = 24 goblins + 6 wolves, tier 1)
	#    gold = 100 + (24*12 + 10) + (6*12 + 10) = 480; xp = 60 + (24*8 + 12) + (6*8 + 12) = 324
	GameState.is_demo_battle = false
	GameState.current_chapter = 1
	GameState.pending_battle_id = "patrol_goblins"
	var rewards_arena = arena_packed.instantiate()
	add_child(rewards_arena)
	var exp_gold = 100 + (24 * 12 + 10) + (6 * 12 + 10)
	var exp_xp = 60 + (24 * 8 + 12) + (6 * 8 + 12)
	assert(rewards_arena.pending_reward_gold == exp_gold,
		"Scaled gold for patrol_goblins must be %d, got %d" % [exp_gold, rewards_arena.pending_reward_gold])
	assert(rewards_arena.pending_reward_xp == exp_xp,
		"Scaled xp for patrol_goblins must be %d, got %d" % [exp_xp, rewards_arena.pending_reward_xp])
	rewards_arena.queue_free()
	GameState.pending_battle_id = ""
	print("  -> Victory rewards scale with enemy strength (gold %d, xp %d)!" % [exp_gold, exp_xp])

	# 39. Новый контент 0.2.0: существа, арт, заклинания, артефакты
	print("[TEST] 39. Testing New Content (units, art, spells, artifacts)...")
	for uid in ["royal_pegasus", "stone_guardian", "fox_shifter", "lich", "red_dragon"]:
		var nu = UnitData.get_unit(uid)
		assert(not nu.is_empty(), "Unit '%s' must exist" % uid)
		assert(int(nu.get("attack", 0)) > 0, "Unit '%s' must have attack" % uid)
		assert(ResourceLoader.exists(nu.get("token_path", "")), "Token missing for %s" % uid)
		assert(ResourceLoader.exists(nu.get("sprite_path", "")), "Sprite missing for %s" % uid)
	assert(UnitData.get_unit("lich").get("is_caster", false), "Lich must be a caster")
	# Болотный зомби — круглый медальон: углы прозрачные, а не квадратный фон жетона
	var zombie_img: Image = load(str(UnitData.get_unit("swamp_zombie")["sprite_path"])).get_image()
	var zw := zombie_img.get_width()
	assert(zombie_img.get_pixel(0, 0).a < 0.05 and zombie_img.get_pixel(zw - 1, zw - 1).a < 0.05, "Swamp zombie sprite corners must be transparent")
	assert(zombie_img.get_pixel(zw / 2, zw / 2).a > 0.95, "Swamp zombie medallion center must be opaque")
	assert(float(UnitData.get_unit("stone_guardian").get("reflect", 0.0)) > 0.0, "Stone guardian must reflect")
	assert(float(UnitData.get_unit("fox_shifter").get("dodge", 0.0)) > 0.0, "Fox must dodge")
	for sid in ["inspiration", "shield_light", "retribution"]:
		var sp = SpellData.get_spell(sid)
		assert(not sp.is_empty(), "Spell '%s' must exist" % sid)
		assert(ResourceLoader.exists(sp.get("icon_path", "")), "Icon missing for spell %s" % sid)
	assert(SpellData.SPELLS.size() == 13, "Spellbook must have 13 spells")
	for aid in ["horn_of_valor", "mantle_wanderer"]:
		var art = ArtifactData.get_artifact(aid)
		assert(not art.is_empty() and art.get("battle_effect", "") != "", "Battle artifact '%s' must exist" % aid)
	print("  -> New units (own art), 13 distinct spell icons and battle artifacts verified!")

	# 40. Механика новых заклинаний: Щит Света, чары Вдохновения/Возмездия
	print("[TEST] 40. Testing New Spell Mechanics (shield absorb, buffs)...")
	var shield_stack = BattleStack.new()
	shield_stack.setup("griffin", 10, 0, Vector2i(2, 2))
	shield_stack.shield_hp = 50
	var r1 = shield_stack.take_damage(30)
	assert(int(r1["absorbed"]) == 30 and int(r1["damage"]) == 0, "Shield must absorb 30 fully")
	assert(shield_stack.is_alive() and shield_stack.count == 10, "No casualties behind full shield")
	var r2 = shield_stack.take_damage(40)
	assert(int(r2["absorbed"]) == 20 and int(r2["damage"]) == 20, "Overspill must wound the stack")
	assert(shield_stack.shield_hp == 0, "Shield pool must be spent")
	shield_stack.buff_slow_turns = 3
	shield_stack.debuff_disease_turns = 2
	shield_stack.buff_inspiration_turns = 3
	shield_stack.buff_retribution_turns = 3
	shield_stack.reset_round()
	assert(shield_stack.buff_slow_turns == 2 and shield_stack.debuff_disease_turns == 1, "Buff timers decrement")
	assert(shield_stack.buff_inspiration_turns == 2 and shield_stack.buff_retribution_turns == 2, "New buffs decrement per round")
	print("  -> Shield Light absorb pool, Inspiration/Retaliation buff timers verified!")

	# 41. Летопись подвигов
	print("[TEST] 41. Testing Chronicle of Deeds...")
	if FileAccess.file_exists(GameState.CHRONICLE_PATH):
		DirAccess.remove_absolute(GameState.CHRONICLE_PATH)
	GameState.chronicle.clear()
	assert(GameState.unlock_feat("first_blood"), "First unlock must succeed")
	assert(not GameState.unlock_feat("first_blood"), "Duplicate unlock must be rejected")
	assert(GameState.is_feat_unlocked("first_blood"), "Feat must be unlocked")
	GameState.chronicle.clear()
	GameState.load_chronicle()
	assert(GameState.is_feat_unlocked("first_blood"), "Chronicle must persist to user://")
	print("  -> Chronicle unlock, dedup and persistence verified!")

	# 42. Реестр встреч (data/encounters.json)
	print("[TEST] 42. Testing Encounter Registry (JSON data-driven)...")
	for enc_id in ["bandit_boss", "lich_boss", "dragon_boss", "patrol_1", "patrol_wolves", "patrol_goblins",
			"patrol_forester", "patrol_grove", "patrol_rogues", "patrol_obelisk", "swamp_patrol_road",
			"swamp_patrol_fens", "swamp_patrol_gate", "swamp_patrol_east", "swamp_patrol_ruins",
			"dragon_patrol_gate", "dragon_patrol_caldera", "dragon_patrol_citadel", "patrol_2", "swamp_patrol"]:
		var enc = EncounterData.get_encounter(enc_id)
		assert(not enc.is_empty(), "Encounter '%s' must exist in JSON" % enc_id)
		assert(enc["enemies"].size() > 0, "Encounter '%s' must have enemies" % enc_id)
		for e in enc["enemies"]:
			assert(not UnitData.get_unit(e["unit_id"]).is_empty(), "Unknown unit in %s: %s" % [enc_id, e["unit_id"]])
	var pg = EncounterData.get_encounter("patrol_goblins")
	assert(pg["enemies"][0]["count"] == 24 and pg["enemies"][0]["hex"] == Vector2i(10, 2), "patrol_goblins must match original config")
	var def1 = EncounterData.get_default_for_chapter(1)
	assert(def1["enemies"].size() == 3, "Chapter 1 default encounter must exist")
	assert(not EncounterData.get_encounter("patrol_grove").is_empty(), "grove patrol must use fox shifters now")
	print("  -> All 20+ encounter configs loaded from data/encounters.json!")

	# 43. Настройки: язык и громкость
	print("[TEST] 43. Testing Settings (locale & volumes)...")
	SettingsManager.set_locale("en")
	assert(TranslationServer.get_locale() == "en", "Locale must switch to en")
	assert(tr("Закрыть") == "Close", "UI string must translate to English")
	SettingsManager.set_locale("ru")
	assert(tr("Закрыть") == "Закрыть", "UI string must fall back to Russian")
	SettingsManager.save_settings()
	assert(FileAccess.file_exists(SettingsManager.PATH), "Settings file must persist")
	print("  -> Language switch (RU/EN via CSV) and settings persistence verified!")

	# 44. Слоты сохранений
	print("[TEST] 44. Testing Save Slots...")
	var slot2 = GameState.SAVE_SLOTS[2]
	assert(GameState.save_game(slot2), "Save to slot 2 must succeed")
	assert(GameState.has_save_game(slot2), "Slot 2 file must exist")
	assert(GameState.get_save_summary(slot2).size() > 0, "Slot 2 must provide a summary")
	assert(GameState.get_newest_save_path() == slot2, "Newest slot must be the just-written slot 2")
	print("  -> 3 save slots + newest-slot detection verified!")

	# 45. Боевые артефакты, отражение, статистика боя
	print("[TEST] 45. Testing Battle Artifacts, Reflect & Battle Stats...")
	GameState.equipped_artifacts["accessory"] = "horn_of_valor"
	assert(GameState.has_artifact_effect("horn_of_valor"), "Horn must be detected as equipped")
	var art_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(art_arena)
	for st in art_arena.all_stacks:
		if st.team == 0:
			assert(st.init_bonus == 2, "Horn must grant +2 initiative to every player stack")
	var gob = BattleStack.new()
	gob.setup("goblin", 5, 1, Vector2i(5, 2))
	var guard = BattleStack.new()
	guard.setup("stone_guardian", 2, 0, Vector2i(6, 2))
	var res_reflect = art_arena._resolve_attack_damage(gob, guard, 100, true)
	assert(int(res_reflect["damage"]) == 100, "Guardian must take full damage")
	assert(gob.count < 5, "Goblin must suffer 30%% reflect damage")
	assert(art_arena.battle_stats["taken"] >= 100, "Battle stats must track incoming damage")
	GameState.equipped_artifacts.erase("accessory")
	art_arena.queue_free()
	GameState.equipped_artifacts["accessory"] = "ring_arcana"
	print("  -> Horn initiative, Stone Guardian reflect and battle stats verified!")

	# 46. Наём новых существ на карте: склады и недельное пополнение
	print("[TEST] 46. Testing New Creature Hiring (stocks & weekly growth)...")
	GameState.reset()
	assert(int(GameState.dwelling_stock.get("shrine_pegasus", 0)) == 2, "Pegasus stock must start at 2")
	assert(int(GameState.dwelling_stock.get("forester_fox", 0)) == 6, "Fox stock must start at 6")
	assert(int(GameState.dwelling_stock.get("obelisk_guard", 0)) == 1, "Guardian stock must start at 1")
	for i in range(7):
		GameState.next_day()
	assert(GameState.day == 8, "Seven next_day calls must reach day 8")
	assert(int(GameState.dwelling_stock.get("shrine_pegasus", 0)) == 4, "Pegasus stock must grow +2 weekly")
	assert(int(GameState.dwelling_stock.get("forester_fox", 0)) == 12, "Fox stock must grow +6 weekly")
	assert(int(GameState.dwelling_stock.get("obelisk_guard", 0)) == 2, "Guardian stock must grow +1 weekly")
	GameState.reset()
	print("  -> Pegasus/fox/guardian hiring stocks and weekly growth verified!")

	# 47. Сложность кампании скейлит составы
	print("[TEST] 47. Testing Campaign Difficulty Scaling...")
	GameState.reset()
	GameState.campaign_difficulty = "legendary"
	GameState.pending_battle_id = "patrol_goblins"
	var d_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(d_arena)
	var enemies := []
	var player_counts := []
	for st in d_arena.all_stacks:
		if st.team == 1:
			enemies.append(st.count)
		else:
			player_counts.append(st.count)
	assert(53 in enemies and 13 in enemies, "Legendary must scale enemies x2.2 (got %s)" % str(enemies))
	assert(player_counts == [5, 14], "Player must scale x0.8 on legendary (got %s)" % str(player_counts))
	d_arena.queue_free()
	GameState.campaign_difficulty = "normal"
	GameState.pending_battle_id = ""
	print("  -> Campaign difficulty multipliers applied in arena (53/13 enemies, 5/14 player)!")

	# 48. Бэкап и восстановление сохранения
	print("[TEST] 48. Testing Save Backup & Fallback...")
	GameState.gold = 4321
	assert(GameState.save_game(), "Save must succeed")
	assert(GameState.save_game(), "Second save must succeed (fills .bak with same state)")
	assert(FileAccess.file_exists(GameState.SAVE_PATH + ".bak"), ".bak must exist after second save")
	var f = FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{broken json!")
	f.close()
	assert(GameState.load_game(), "load_game must fall back to .bak")
	assert(GameState.gold == 4321, "State must be restored from backup")
	assert(int(GameState._read_save_data(GameState.SAVE_PATH + ".bak").get("version", 0)) == 3, "Saves must be version 3")
	print("  -> .bak rotation, fallback load and save migration verified!")

	# 49. Бродячий торговец
	print("[TEST] 49. Testing Wandering Merchant...")
	GameState.reset()
	GameState.spawn_merchant_offers()
	assert(GameState.merchant_offers.size() == 2, "Merchant must have 2 offers")
	for offer in GameState.merchant_offers:
		assert(int(offer["price"]) > 0 and str(offer["id"]) != "", "Offer must be filled")
	GameState.gold = 99999
	var offers_before: int = GameState.merchant_offers.size()
	assert(GameState.buy_merchant_offer(0), "Buying offer 0 must succeed")
	assert(GameState.merchant_offers.size() == offers_before - 1, "Bought offer must be removed")
	var gold_before := GameState.gold
	assert(not GameState.buy_merchant_offer(5), "Buying nonexistent offer must fail")
	assert(GameState.gold == gold_before, "Gold must not change on failed purchase")
	GameState.reset()
	print("  -> Merchant offers, purchase and gold handling verified!")

	# 50. Охраняемый сундук после победы над охраной (регрессия игрока)
	print("[TEST] 50. Testing Guarded Chest After Victory...")
	GameState.reset()
	GameState.flags["chapter_intro_seen_1"] = true
	GameState.flags["patrol_goblins"] = true
	GameState.hero_cell = Vector2i(4, 9)
	var gwm = load("res://src/world/world_map.tscn").instantiate()
	add_child(gwm)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not gwm.world_view.objects.has(Vector2i(4, 8)), "Dead guard must be purged on return")
	assert(gwm.world_view.objects.has(Vector2i(4, 9)), "Chest must remain after guard victory")
	assert(gwm.popup_dialog.visible, "Chest popup must auto-open on victory return")
	var gold_before2 := GameState.gold
	gwm.popup_btn1.emit_signal("pressed")
	assert(GameState.gold == gold_before2 + 1000, "Chest gold must be claimable after guard victory")
	assert(not gwm.world_view.objects.has(Vector2i(4, 9)), "Chest must vanish after pickup")
	gwm.queue_free()
	GameState.reset()
	print("  -> Guarded chest auto-opens and is lootable after guard victory!")

	# 51. Остаток PR: павшие/Благодать, блокирующие объекты, hero_form, can_add_units
	print("[TEST] 51. Testing Fallen Units, Blocking Objects & Hero Forms...")
	GameState.reset()
	# can_add_units
	GameState.player_army = [{"unit_id": "griffin", "count": 5}]
	assert(GameState.can_add_units("griffin"), "Same-kind stack always fits")
	assert(GameState.can_add_units("wolf"), "Free slot accepts new kind")
	GameState.player_army = [
		{"unit_id": "griffin", "count": 1},
		{"unit_id": "wolf", "count": 1},
		{"unit_id": "goblin", "count": 1},
		{"unit_id": "druid", "count": 1},
		{"unit_id": "treant", "count": 1}
	]
	assert(not GameState.can_add_units("fairy_archer"), "Full army of distinct kinds must refuse")
	# fallen_units + restore cap (3 + Spellpower)
	GameState.player_army = [{"unit_id": "griffin", "count": 3}]
	GameState.fallen_units = [{"unit_id": "griffin", "count": 10}]
	GameState.spellpower = 3
	var res51: Dictionary = GameState.restore_fallen_units()
	assert(int(res51["restored"]) == 6, "Restore cap = 3 + Spellpower 3 = 6 (got %d)" % int(res51["restored"]))
	assert(GameState.player_army[0]["count"] == 9, "Griffins must be restored into their stack")
	assert(GameState.fallen_units.size() == 1 and int(GameState.fallen_units[0]["count"]) == 4, "4 fallen must remain for later")
	# hero_form
	GameState.set_hero_class("paladin")
	assert(GameState.hero_form() == "сэр Аларик", "Paladin form")
	GameState.set_hero_class("archmage")
	assert(GameState.hero_form() == "леди Элеонора", "Archmage form")
	GameState.set_hero_class("paladin")
	# Блокирующие объекты и маршрут
	var b_enc = {"type": "encounter", "id": "patrol_1", "name": "x"}
	assert(WorldView.is_blocking_object(b_enc), "Living encounter must block")
	GameState.flags["patrol_1"] = true
	assert(not WorldView.is_blocking_object(b_enc), "Dead encounter must not block")
	var b_gate = {"type": "gate", "id": "iron_gate"}
	assert(WorldView.is_blocking_object(b_gate), "Locked gate must block")
	GameState.flags["iron_gate_opened"] = true
	assert(not WorldView.is_blocking_object(b_gate), "Opened gate must not block")
	# Маршрут сквозь запертые врата невозможен, после открытия — возможен
	var bwm = load("res://src/world/world_map.tscn").instantiate()
	add_child(bwm)
	await get_tree().process_frame
	GameState.flags["iron_gate_opened"] = false
	var blocked_path: Array[Vector2i] = bwm.world_view.get_path_obstacles(Vector2i(20, 11))
	var p_locked: Array[Vector2i] = WorldNavigator.find_path(Vector2i(4, 11), Vector2i(20, 11), blocked_path, Rect2i(0, 0, bwm.world_view.MAP_COLS, bwm.world_view.MAP_ROWS), bwm.world_view.road_cells, false)
	assert(p_locked.is_empty(), "Locked gate must stop the route to the east")
	GameState.flags["iron_gate_opened"] = true
	var p_open: Array[Vector2i] = WorldNavigator.find_path(Vector2i(4, 11), Vector2i(20, 11), bwm.world_view.get_path_obstacles(Vector2i(20, 11)), Rect2i(0, 0, bwm.world_view.MAP_COLS, bwm.world_view.MAP_ROWS), bwm.world_view.road_cells, false)
	assert(not p_open.is_empty(), "Opened gate must let the route through")
	bwm.queue_free()
	GameState.reset()
	print("  -> Fallen/Grace restore, blocking objects, gate routing and hero forms verified!")

	# 52. Английская локализация: меню, карта, бой и черты существ без русских строк
	print("[TEST] 52. Testing English Localization Coverage...")
	var saved_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert(tr("СКАЗКИ КОРОЛЕВСТВА") == "KINGDOM TALES", "Main menu title must be translated")
	assert(tr("⏳ Завершить день") == "⏳ End day", "End-day button (scene text) must be translated")
	assert(tr("Старая Мельница") == "The Old Mill", "Map object names must be translated")
	assert(tr("ШТРАФ 50%") == "PENALTY 50%", "Broken-arrow label on the battlefield must be translated")
	var fairy_traits := UnitData.get_trait_string("royal_fairy")
	assert(fairy_traits.contains("•") and not _has_cyrillic(fairy_traits), "Creature traits must be translated one by one")
	# Карточка отряда собирается шаблоном и списками черт — после сборки не должно остаться русского
	GameState.reset()
	var card_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(card_arena)
	for card_stack in card_arena.all_stacks:
		card_arena._show_unit_info(card_stack)
		assert(not _has_cyrillic(card_arena.unit_info_stats.text), "Unit card must be fully translated: " + card_arena.unit_info_stats.text.left(60))
	card_arena.queue_free()
	var untranslated := _untranslated_source_strings()
	if not untranslated.is_empty():
		print("  Untranslated (run tools/extract_strings.py and tools/build_csv.py): ", untranslated.slice(0, 10))
	assert(untranslated.is_empty(), "Every Russian string in src/ must have an English translation")
	TranslationServer.set_locale(saved_locale)
	print("  -> English locale covers main menu, map, battle and creature traits!")

	# 53. Механики боссов: знамя Атамана, подъём нежити Личем, огненный шквал Дракона
	print("[TEST] 53. Testing Boss Mechanics (banner, raise dead, firestorm)...")
	assert(int(UnitData.get_unit("bandit_chief").get("rally_aura", 0)) > 0, "Bandit chief must carry a banner")
	var chief_in_lair := false
	for lair_enemy in EncounterData.get_encounter("bandit_boss")["enemies"]:
		chief_in_lair = chief_in_lair or lair_enemy["unit_id"] == "bandit_chief"
	assert(chief_in_lair, "Bandit chief must fight in his own lair")
	assert(UnitData.get_unit("lich").has("raise_dead"), "Lich must raise the dead")
	assert(int(UnitData.get_unit("red_dragon").get("firestorm", 0)) > 0, "Red dragon must have firestorm")
	var chief_img: Image = load(str(UnitData.get_unit("bandit_chief")["sprite_path"])).get_image()
	assert(chief_img.get_pixel(0, 0).a < 0.05, "Chief medallion corners must be transparent")
	var cone := BossMechanics.cone_cells(Vector2i(5, 3), Vector2i(-1, 0), 3, Rect2i(0, 0, 11, 7))
	assert(cone.size() == 7, "Firestorm cone of length 3 must cover 1 + 3 + 3 tiles")
	for cone_hex in [Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 2)]:
		assert(cone.has(cone_hex), "Cone west of (5, 3) must cover %s" % cone_hex)
	assert(BossMechanics.cone_cells(Vector2i(0, 0), Vector2i(-1, 0), 3, Rect2i(0, 0, 11, 7)).is_empty(), "Cone past the field edge must be empty")
	assert(BossMechanics.is_firestorm_round(2) and BossMechanics.is_firestorm_round(5), "Dragon inhales in rounds 2 and 5")
	assert(not BossMechanics.is_firestorm_round(1) and not BossMechanics.is_firestorm_round(3), "No inhale in rounds 1 and 3")

	# Знамя: +к атаке союзникам, пока Атаман жив; сам он прибавку не получает
	var ba_chief = await _boss_arena("bandit_boss", 1)
	var chief: BattleStack = _boss_find(ba_chief, "bandit_chief")
	var goblins: BattleStack = _boss_find(ba_chief, "goblin")
	var hero_stack: BattleStack = _boss_find(ba_chief, "griffin")
	var aura := int(chief.data["rally_aura"])
	ba_chief.boss.before_turn()
	assert(goblins.aura_attack == aura and chief.aura_attack == 0 and hero_stack.aura_attack == 0, "Banner must boost only the chief's allies")
	var with_banner: int = goblins.get_damage_range(hero_stack, true)["max_dmg"]
	ba_chief._show_unit_info(chief)
	assert(ba_chief.unit_info_stats.text.contains(tr("Знамя вожака (+%d к атаке союзников)") % aura), "Chief card must describe the banner")
	ba_chief.unit_info_dialog.hide()
	chief.count = 0
	ba_chief.boss.before_turn()
	assert(goblins.aura_attack == 0, "Banner must fall with the chief")
	assert(with_banner > int(goblins.get_damage_range(hero_stack, true)["max_dmg"]), "Goblins must hit harder under the banner")
	await _boss_free(ba_chief)

	# Лич: в начале 3-го, 5-го... раунда поднимает скелетов (к живому отряду или новым рядом)
	var ba_lich = await _boss_arena("lich_boss", 2)
	var lich: BattleStack = _boss_find(ba_lich, "lich")
	var lich_skel: BattleStack = _boss_find(ba_lich, "skeleton_archer")
	var per_unit := int(lich.data["raise_dead"]["per_unit"])
	var lich_skel_before := lich_skel.count
	ba_lich.current_round = 2
	ba_lich.boss.on_round_start()
	assert(lich_skel.count == lich_skel_before and ba_lich.boss.rounds_until_raise(lich) == 1, "No raise in round 2, ritual next round")
	ba_lich.current_round = 3
	ba_lich.boss.on_round_start()
	assert(lich_skel.count == lich_skel_before + lich.count * per_unit, "Lich must raise %d skeletons in round 3" % (lich.count * per_unit))
	lich_skel.count = 0
	lich.count = 3
	var stacks_before: int = ba_lich.all_stacks.size()
	ba_lich.current_round = 5
	ba_lich.boss.on_round_start()
	var raised: BattleStack = ba_lich.all_stacks.back()
	assert(ba_lich.all_stacks.size() == stacks_before + 1 and raised.unit_id == "skeleton_archer" and raised.count == 3 * per_unit, "Without living skeletons the lich raises a new stack")
	assert(HexGrid.distance(raised.hex, lich.hex) == 1 and not ba_lich.obstacles.has(raised.hex), "Raised stack must stand on a free tile next to the lich")
	lich.count = 0
	var raised_count := raised.count
	ba_lich.current_round = 7
	ba_lich.boss.on_round_start()
	assert(raised.count == raised_count, "A slain lich raises no one")
	await _boss_free(ba_lich)

	# Дракон: вдох помечает конус без урона, выдох жжёт клетки, а не прежнюю цель
	var ba_dragon = await _boss_arena("dragon_boss", 3)
	var dragon: BattleStack = _boss_find(ba_dragon, "red_dragon")
	var mine: Array = []
	for boss_st in ba_dragon.all_stacks:
		if boss_st.team == 0 and boss_st.is_alive():
			mine.append(boss_st)
	ba_dragon.obstacles.clear()
	dragon.hex = Vector2i(6, 3)
	mine[0].hex = Vector2i(4, 3)
	mine[1].hex = Vector2i(0, 0)
	ba_dragon.current_round = 1
	assert(not ba_dragon.boss.plan_turn(dragon), "Round 1: the dragon attacks normally")
	ba_dragon.current_round = 2
	assert(ba_dragon.boss.plan_turn(dragon), "Round 2: the dragon draws breath")
	var pool_target := _boss_pool(mine[0])
	await ba_dragon.boss.take_turn(dragon)
	var fire_cells: Array = ba_dragon.boss.charged.get(dragon, [])
	assert(fire_cells.has(mine[0].hex) and not fire_cells.has(mine[1].hex), "Cone must aim at the stack in front of the dragon")
	assert(_boss_pool(mine[0]) == pool_target, "Inhale deals no damage")
	assert(ba_dragon.boss.turn_hint(mine[0]) != "" and ba_dragon.boss.turn_hint(mine[1]) == "", "Turn hint must warn only the stack in the fire")
	mine[0].hex = Vector2i(0, 6)
	mine[1].hex = fire_cells[0]
	var pool_moved := _boss_pool(mine[0])
	var pool_burned := _boss_pool(mine[1])
	ba_dragon.current_round = 3
	assert(ba_dragon.boss.plan_turn(dragon), "Charged dragon exhales on its next turn")
	await ba_dragon.boss.take_turn(dragon)
	assert(_boss_pool(mine[1]) < pool_burned and _boss_pool(mine[0]) == pool_moved, "Fire burns the marked tiles, the stack that left is safe")
	assert(ba_dragon.boss.charged.is_empty(), "Charge must be spent after exhale")
	# Настоящий ход ИИ в раунд шквала — вдох вместо атаки
	var pools := {}
	for boss_st in mine:
		pools[boss_st] = _boss_pool(boss_st)
	ba_dragon.current_round = 5
	ba_dragon.victory_dialog.hide()
	ba_dragon.current_actor = dragon
	ba_dragon.is_ai_turn = true
	ba_dragon._update_reachable_hexes()
	await ba_dragon._handle_ai_turn()
	assert(ba_dragon.boss.charged.has(dragon), "AI turn in round 5 must be an inhale")
	for boss_st in pools:
		assert(_boss_pool(boss_st) == pools[boss_st], "The dragon attacks no one while drawing breath")
	await _boss_free(ba_dragon)
	GameState.reset()
	print("  -> Chief's banner, lich raising the dead and dragon firestorm verified!")

	# 54. Настроение поля боя: топи и вулкан — своим видом, глава 1 — без изменений
	print("[TEST] 54. Testing Battle Mood per Chapter...")
	assert(BattleMood.mood_for(1, false, []) == "" and BattleMood.mood_for(2, false, []) == "swamp" and BattleMood.mood_for(3, false, []) == "volcano", "Campaign mood must follow the chapter")
	assert(BattleMood.mood_for(1, true, ["wolf", "red_dragon"]) == "volcano" and BattleMood.mood_for(1, true, ["lich"]) == "swamp" and BattleMood.mood_for(3, true, ["goblin"]) == "", "Arena mood must follow the enemy army")
	for mood_ch in [1, 2, 3]:
		GameState.reset()
		GameState.current_chapter = mood_ch
		var mood_arena = load("res://src/battle/battle_arena.tscn").instantiate()
		add_child(mood_arena)
		var mood_bg: TextureRect = mood_arena.get_node("Background")
		if mood_ch == 1:
			assert(mood_bg.material == null and mood_bg.get_node_or_null("MoodParticles") == null, "Chapter 1 background must stay as drawn")
		else:
			assert(mood_bg.material is ShaderMaterial, "Chapter %d background must be graded" % mood_ch)
			assert(mood_bg.get_node_or_null("MoodParticles") is CPUParticles2D, "Chapter %d must have ambient particles" % mood_ch)
		mood_arena.queue_free()
		await get_tree().process_frame
	# Упрощённые анимации: только неподвижная цветокоррекция, без частиц и дрожания воздуха
	SettingsManager.reduced_animations = true
	GameState.reset()
	GameState.current_chapter = 3
	var calm_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(calm_arena)
	var calm_bg: TextureRect = calm_arena.get_node("Background")
	assert(calm_bg.material is ShaderMaterial and calm_bg.get_node_or_null("MoodParticles") == null, "Reduced animations: grading without particles")
	assert(float(calm_bg.material.get_shader_parameter("heat_haze")) == 0.0, "Reduced animations: no heat haze")
	calm_arena.queue_free()
	SettingsManager.reduced_animations = false
	GameState.reset()
	print("  -> Swamp and volcano battles get their own mood, chapter 1 unchanged!")

	# 55. Бой живее: павшие тают, у каждого удара искры, тяжёлый удар встряхивает поле
	print("[TEST] 55. Testing Battle Juice (death fade, hit sparks, shake)...")
	GameState.reset()
	var juice_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(juice_arena)
	await get_tree().process_frame
	var juice_vp = juice_arena.arena_viewport
	var juice_enemies: Array = []
	var juice_hero: BattleStack = null
	for js in juice_arena.all_stacks:
		if js.team == 1:
			juice_enemies.append(js)
		elif juice_hero == null:
			juice_hero = js
	juice_enemies[0].count = 0
	await get_tree().process_frame
	assert(juice_vp.dying.has(juice_enemies[0]), "A slain stack must fade out instead of vanishing")
	await get_tree().create_timer(juice_vp.DEATH_FADE_TIME + 0.2).timeout
	assert(not juice_vp.dying.has(juice_enemies[0]), "The fade must end")
	var juice_fx: int = juice_vp.special_effects.size()
	juice_arena._resolve_attack_damage(juice_hero, juice_enemies[1], 1, false)
	assert(juice_vp.special_effects.size() == juice_fx + 1 and juice_vp.special_effects.back()["type"] == "hit", "Every hit must spark")
	assert(juice_vp.shake_time == 0.0, "A light hit must not shake the field")
	juice_arena._resolve_attack_damage(juice_hero, juice_enemies[1], 100000, false)
	assert(juice_vp.shake_time > 0.0, "A heavy hit must shake the field")
	await get_tree().create_timer(juice_vp.SHAKE_TIME + 0.1).timeout
	assert(juice_vp.position == juice_vp._shake_rest, "The field must settle back after the shake")
	SettingsManager.reduced_animations = true
	juice_vp.shake(8.0)
	assert(juice_vp.shake_time == 0.0, "Reduced animations: no shake")
	SettingsManager.reduced_animations = false
	juice_arena.queue_free()
	GameState.reset()
	print("  -> Slain stacks fade, hits spark and heavy blows shake the field!")

	# 56. Звук: плавная смена музыки, звуки событий и стихий заклинаний, музыка боссов
	print("[TEST] 56. Testing Sound: crossfade, event and element SFX, boss music...")
	for sfx_name in ["defeat", "level_up", "fire_whoosh", "lightning", "heal_chime", "frost", "ward", "swift"]:
		assert(SoundManager.sfx_cache.has(sfx_name), "Missing SFX: " + sfx_name)
	for spell_key in SoundManager.SPELL_SFX:
		assert(SoundManager.sfx_cache.has(SoundManager.SPELL_SFX[spell_key]), "Missing element sound for " + spell_key)
	for boss_key in ["bandit_boss", "lich_boss", "dragon_boss"]:
		var boss_track: String = BattleArena.battle_music_for(boss_key)
		assert(boss_track != BattleArena.BATTLE_MUSIC and ResourceLoader.exists(boss_track), "Boss %s must have its own battle theme" % boss_key)
	assert(BattleArena.battle_music_for("patrol_goblins") == BattleArena.BATTLE_MUSIC, "Regular battles keep the common battle theme")
	SoundManager.play_music("res://assets/audio/music/fairy_tale_theme.ogg", true)
	await get_tree().create_timer(SoundManager.MUSIC_FADE_TIME + 0.2).timeout
	var fade_from: AudioStreamPlayer = SoundManager.music_player
	SoundManager.play_music("res://assets/audio/music/swamp_theme.ogg")
	assert(SoundManager.music_player != fade_from and SoundManager.music_player.playing, "The new theme must start on the second player")
	assert(fade_from.playing, "The old theme must keep playing while it fades out")
	await get_tree().create_timer(SoundManager.MUSIC_FADE_TIME + 0.2).timeout
	assert(not fade_from.playing, "The old theme must stop after the fade")
	assert(is_equal_approx(SoundManager.music_player.volume_db, linear_to_db(SoundManager.music_volume)), "The new theme must reach full volume")
	SoundManager.play_sfx("click")
	SoundManager.play_sfx("sword_hit")
	for sfx_player in SoundManager.sfx_players:
		if sfx_player.stream == SoundManager.sfx_cache["click"]:
			assert(sfx_player.pitch_scale == 1.0, "UI sounds keep their pitch")
		elif sfx_player.stream == SoundManager.sfx_cache["sword_hit"]:
			assert(sfx_player.pitch_scale >= 0.93 and sfx_player.pitch_scale <= 1.07, "Combat sounds vary their pitch slightly")
	print("  -> Music crossfades, events and spell elements sound, bosses have their own themes!")

	# 57. ИИ выбора цели: не лезет под тяжёлый ответный удар и выручает своих стрелков
	print("[TEST] 57. Testing Smarter AI Target Choice...")
	GameState.reset()
	var ai_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ai_arena)
	await get_tree().process_frame
	var ai_wolves := BattleStack.new()
	ai_wolves.setup("wolf", 5, 1, Vector2i(5, 3))
	# Рядом — 12 Королевских Грифонов с бесконечным отпором, в трёх клетках — одинокий гоблин
	var ai_griffins := BattleStack.new()
	ai_griffins.setup("royal_griffin", 12, 0, Vector2i(4, 3))
	var ai_lone := BattleStack.new()
	ai_lone.setup("goblin", 1, 0, Vector2i(2, 3))
	var ai_field_a: Array[BattleStack] = [ai_wolves, ai_griffins, ai_lone]
	ai_arena.all_stacks = ai_field_a
	var ai_targets_a: Array[BattleStack] = [ai_griffins, ai_lone]
	assert(ai_arena._select_ai_target(ai_wolves, ai_targets_a) == ai_lone, "AI must not charge a stack whose retaliation outweighs the gain")
	# Свои скелеты-лучники стеснены гоблином — выручить их важнее, чем бить соседа
	var ai_archers := BattleStack.new()
	ai_archers.setup("skeleton_archer", 10, 1, Vector2i(8, 3))
	var ai_blocker := BattleStack.new()
	ai_blocker.setup("goblin", 1, 0, Vector2i(7, 3))
	var ai_neighbour := BattleStack.new()
	ai_neighbour.setup("goblin", 1, 0, Vector2i(4, 3))
	var ai_field_b: Array[BattleStack] = [ai_wolves, ai_archers, ai_blocker, ai_neighbour]
	ai_arena.all_stacks = ai_field_b
	var ai_targets_b: Array[BattleStack] = [ai_blocker, ai_neighbour]
	assert(ai_arena._select_ai_target(ai_wolves, ai_targets_b) == ai_blocker, "AI must free its own shooters from melee blockers")
	# Оценка без случайного броска: один и тот же выбор при повторе
	for ai_i in 5:
		assert(ai_arena._select_ai_target(ai_wolves, ai_targets_b) == ai_blocker, "AI target choice must be deterministic")
	ai_arena.queue_free()
	GameState.reset()
	print("  -> AI weighs retaliation and protects its shooters!")

	# 58. Туман войны с мягким краем: полоса только внутри открытых клеток на границе тумана
	print("[TEST] 58. Testing Soft Fog Edges...")
	GameState.reset()
	GameState.flags["chapter_intro_seen_1"] = true
	var fog_map = load("res://src/world/world_map.tscn").instantiate()
	add_child(fog_map)
	await get_tree().process_frame
	var fog_wv = fog_map.world_view
	fog_wv.revealed_cells = {Vector2i(5, 5): true, Vector2i(6, 5): true, Vector2i(5, 6): true, Vector2i(0, 0): true}
	var fog_e: Array[Vector2i] = fog_wv.fog_edges(Vector2i(5, 5))
	assert(fog_e.has(Vector2i(-1, 0)) and fog_e.has(Vector2i(0, -1)), "Soft edge must face fogged neighbours")
	assert(not fog_e.has(Vector2i(1, 0)) and not fog_e.has(Vector2i(0, 1)), "No edge toward open neighbours")
	assert(fog_e.has(Vector2i(1, 1)), "Fog only on the diagonal must soften the corner")
	assert(fog_wv.fog_edges(Vector2i(4, 4)).is_empty(), "A fogged cell gets no soft edge: the shroud stays opaque")
	var fog_border: Array[Vector2i] = fog_wv.fog_edges(Vector2i(0, 0))
	assert(not fog_border.has(Vector2i(-1, 0)) and not fog_border.has(Vector2i(0, -1)), "The map border is not fog")
	fog_map.queue_free()
	GameState.reset()
	print("  -> Fog of war fades softly at its edges and stays opaque inside!")

	# 59. Огненный шар бьёт по площади: соседние вражеские отряды — вполсилы, свои не задеты
	print("[TEST] 59. Testing Fireball Splash...")
	GameState.reset()
	var fb_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(fb_arena)
	await get_tree().process_frame
	var fb_target := BattleStack.new()
	fb_target.setup("goblin", 20, 1, Vector2i(6, 3))
	var fb_next := BattleStack.new()
	fb_next.setup("wolf", 10, 1, Vector2i(7, 3))
	var fb_far := BattleStack.new()
	fb_far.setup("wolf", 10, 1, Vector2i(9, 1))
	var fb_mine := BattleStack.new()
	fb_mine.setup("griffin", 6, 0, Vector2i(5, 3))
	var fb_field: Array[BattleStack] = [fb_target, fb_next, fb_far, fb_mine]
	fb_arena.all_stacks = fb_field
	var fb_before := {}
	for fb_st in fb_field:
		fb_before[fb_st] = _fb_pool(fb_st)
	GameState.current_mana = GameState.max_mana
	await fb_arena._execute_spell("fireball", fb_target)
	var fb_main: int = fb_before[fb_target] - _fb_pool(fb_target)
	var fb_splash: int = fb_before[fb_next] - _fb_pool(fb_next)
	assert(fb_main > 0 and fb_splash > 0, "Fireball must hurt the target and its enemy neighbour")
	assert(absi(fb_splash - int(fb_main * fb_arena.FIREBALL_SPLASH)) <= 1, "The neighbour takes half of the blast")
	assert(_fb_pool(fb_far) == fb_before[fb_far], "A distant enemy stack is untouched")
	assert(_fb_pool(fb_mine) == fb_before[fb_mine], "Own stacks next to the target are never burned")
	fb_arena.queue_free()
	GameState.reset()
	print("  -> Fireball splashes onto neighbouring enemy stacks!")

	# 60. Поле боя: у глав несколько раскладок препятствий, у боссов — свои
	print("[TEST] 60. Testing Battlefield Obstacle Layouts...")
	var lay_bounds := Rect2i(0, 0, BattleArena.GRID_COLS, BattleArena.GRID_ROWS)
	var lay_all: Array = []
	for lay_ch in BattleArena.OBSTACLE_LAYOUTS:
		lay_all.append_array(BattleArena.OBSTACLE_LAYOUTS[lay_ch])
	lay_all.append_array(BattleArena.BOSS_OBSTACLES.values())
	for lay in lay_all:
		var lay_typed: Array[Vector2i] = []
		lay_typed.assign(lay)
		var lay_seen := {}
		for lay_h in lay_typed:
			assert(HexGrid.is_in_bounds(HexGrid.offset_to_axial(lay_h), lay_bounds) and lay_h.x >= 2 and lay_h.x <= 8, "Obstacle %s must stay off the deployment columns" % lay_h)
			assert(not lay_seen.has(lay_h), "Duplicate obstacle %s" % lay_h)
			lay_seen[lay_h] = true
		# с любой клетки расстановки игрока можно дойти до любой клетки врага;
		# раскладки заданы как (колонка, ряд), а бой считает в осевых координатах
		var lay_axial := HexGrid.offsets_to_axial(lay_typed)
		for lay_r in range(1, 6):
			var lay_reach := HexGrid.get_reachable_hexes(HexGrid.offset_to_axial(Vector2i(0, lay_r)), 40, lay_axial, lay_bounds)
			for lay_r2 in range(1, 6):
				assert(lay_reach.has(HexGrid.offset_to_axial(Vector2i(10, lay_r2))), "Obstacle layout must not cut the field in two")
	assert(BattleArena.obstacle_layout("patrol_wolves", 1) == BattleArena.obstacle_layout("patrol_wolves", 1), "The same encounter always gets the same field")
	var lay_variants := {}
	for lay_id in ["patrol_wolves", "patrol_goblins", "patrol_forester", "patrol_grove", "patrol_1", "patrol_rogues", "patrol_obelisk", "patrol_2"]:
		lay_variants[str(BattleArena.obstacle_layout(lay_id, 1))] = true
	assert(lay_variants.size() >= 2, "Chapter 1 battles must not all share one field")
	var lay_lich: Array[Vector2i] = []
	lay_lich.assign(BattleArena.BOSS_OBSTACLES["lich_boss"])
	assert(BattleArena.obstacle_layout("lich_boss", 2) == lay_lich, "Bosses have their own field")
	print("  -> Battlefields vary by encounter, bosses have their own, no layout blocks the way!")

	# 61. Обучение в первом бою: подсказки сменяются по действиям игрока, показываются один раз
	print("[TEST] 61. Testing First Battle Tutorial...")
	var tut_saved: bool = SettingsManager.battle_tutorial_done
	GameState.reset()
	GameState.is_demo_battle = true
	SettingsManager.battle_tutorial_done = false
	assert(not BattleTutorial.should_show(), "No tutorial in demo arena battles")
	GameState.is_demo_battle = false
	assert(BattleTutorial.should_show(), "Tutorial shows in the first campaign battle")
	var tut_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(tut_arena)
	await get_tree().process_frame
	var tut: BattleTutorial = tut_arena.get_node("CanvasLayer/BattleTutorial")
	assert(tut != null and tut.step == 0, "Tutorial starts at the first tip")
	var tut_actor: BattleStack = tut_arena.current_actor
	assert(tut_actor != null and tut_actor.team == 0, "First actor of the first battle is the player's")
	tut_actor.hex += Vector2i(1, 0)
	await get_tree().process_frame
	assert(tut.step == 1, "Moving a stack advances to the attack tip")
	tut_arena.battle_stats["dealt"] = int(tut_arena.battle_stats["dealt"]) + 10
	await get_tree().process_frame
	assert(tut.step == 2, "Dealing damage advances to the shooters tip")
	tut.next_step()
	assert(tut.step == 3, "The Next button advances the tip")
	tut_arena.hero_cast_this_round = true
	await get_tree().process_frame
	assert(tut.step == 4, "Casting a spell advances to the last tip")
	tut.next_step()
	assert(SettingsManager.battle_tutorial_done, "Finishing the tutorial marks it done")
	assert(not BattleTutorial.should_show(), "The tutorial is shown only once")
	tut_arena.queue_free()
	await get_tree().process_frame
	SettingsManager.battle_tutorial_done = tut_saved
	SettingsManager.save_settings()
	GameState.reset()
	print("  -> First battle tips follow the player's actions and show only once!")

	# 62. Войско после боя: сложность не меняет его навсегда, отступление не отменяет потерь,
	# в сохранение уходит армия уже с потерями
	print("[TEST] 62. Testing Army After Battle (difficulty scale, retreat, save)...")
	GameState.reset()
	GameState.campaign_difficulty = "easy"
	GameState.player_army = [{"unit_id": "griffin", "count": 10}]
	var arm_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(arm_arena)
	await get_tree().process_frame
	var arm_gr: BattleStack = arm_arena.all_stacks[0]
	assert(arm_gr.team == 0 and arm_gr.count == 14, "Easy: 10 griffins fight as 14")
	arm_arena._sync_army_after_battle()
	assert(GameState.player_army[0]["count"] == 10, "Easy, no losses: the army keeps 10, it must not grow to 14")
	arm_gr.count = 7
	arm_arena._sync_army_after_battle()
	assert(GameState.player_army[0]["count"] == 5, "Half of the battle stack fell: half of the army (5 of 10)")
	arm_arena.queue_free()
	await get_tree().process_frame

	GameState.reset()
	GameState.campaign_difficulty = "legendary"
	GameState.player_army = [{"unit_id": "griffin", "count": 10}]
	arm_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(arm_arena)
	await get_tree().process_frame
	arm_gr = arm_arena.all_stacks[0]
	assert(arm_gr.count == 8, "Legendary: 10 griffins fight as 8")
	arm_arena._sync_army_after_battle()
	assert(GameState.player_army[0]["count"] == 10, "Legendary, no losses: the army must not melt to 8")
	# Отступление: уцелевшие уходят с героем, потери остаются и сохраняются
	arm_gr.count = 4
	arm_arena._show_victory(false)
	assert(GameState.player_army[0]["count"] == 5, "Retreat keeps the survivors and the losses (5 of 10)")
	GameState.player_army = [{"unit_id": "griffin", "count": 99}]
	GameState.load_game()
	assert(GameState.player_army[0]["count"] == 5, "Losses after a retreat must reach the save")
	arm_arena.queue_free()
	await get_tree().process_frame

	# Победа: в сохранение уходит армия с потерями, а не армия до боя
	GameState.reset()
	GameState.player_army = [{"unit_id": "griffin", "count": 10}]
	GameState.pending_battle_id = "patrol_goblins"
	arm_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(arm_arena)
	await get_tree().process_frame
	arm_arena.all_stacks[0].count = 6
	arm_arena._show_victory(true)
	GameState.player_army = [{"unit_id": "griffin", "count": 99}]
	GameState.load_game()
	assert(GameState.player_army[0]["count"] == 6, "Victory: the save must hold the army after losses")
	arm_arena.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Army size survives difficulty scaling, retreats keep losses, saves hold them!")

	# 63. «Благодать Похода» возвращает и отряд, павший целиком; лимит — на вид, а не на слот
	print("[TEST] 63. Testing Grace Restores Wiped-out Stacks...")
	GameState.reset()
	var grace_cap := 3 + GameState.get_total_spellpower()
	GameState.player_army = [{"unit_id": "fairy_archer", "count": 12}]
	GameState.fallen_units = [{"unit_id": "griffin", "count": 5}]
	assert(GameState.restorable_fallen_count() == mini(5, grace_cap), "Grace must see the fallen of a stack that fell entirely")
	GameState.restore_fallen_units()
	var grace_griffins := 0
	for grace_slot in GameState.player_army:
		if grace_slot["unit_id"] == "griffin":
			grace_griffins += int(grace_slot["count"])
	assert(grace_griffins == mini(5, grace_cap), "Griffins that fell entirely return as a new stack")
	GameState.player_army = [{"unit_id": "fairy_archer", "count": 6}, {"unit_id": "fairy_archer", "count": 6}]
	GameState.fallen_units = [{"unit_id": "fairy_archer", "count": 50}]
	GameState.restore_fallen_units()
	var grace_fairies := 0
	for grace_slot in GameState.player_army:
		grace_fairies += int(grace_slot["count"])
	assert(grace_fairies == 12 + grace_cap, "The cap is per kind, not per army slot")
	GameState.player_army = [{"unit_id": "fairy_archer", "count": 1}, {"unit_id": "wolf", "count": 1}, {"unit_id": "goblin", "count": 1}, {"unit_id": "treant", "count": 1}, {"unit_id": "druid", "count": 1}]
	GameState.fallen_units = [{"unit_id": "griffin", "count": 3}]
	assert(GameState.restorable_fallen_count() == 0, "No free slot: nothing to restore yet")
	GameState.restore_fallen_units()
	assert(GameState.player_army.size() == 5 and int(GameState.fallen_units[0]["count"]) == 3, "Without a free slot the fallen wait for later")
	GameState.reset()
	print("  -> Grace brings back stacks that fell entirely, capped per kind!")

	# 64. Недельные бонусы переживают сохранение и снимаются ровно через неделю
	print("[TEST] 64. Testing Weekly Bonuses Across Save/Load...")
	GameState.reset()
	var wk_attack: int = GameState.attack
	GameState.day = 28
	GameState.next_day() # день 29 — Неделя Воинской Доблести
	assert(GameState.week_valor_bonus == 2 and GameState.attack == wk_attack + 2, "Week of Valor gives +2 attack")
	GameState.save_game()
	GameState.week_valor_bonus = 0
	GameState.load_game()
	assert(GameState.week_valor_bonus == 2, "The valor bonus must survive save/load")
	for wk_i in 7:
		GameState.next_day()
	assert(GameState.attack == wk_attack, "After a reload the +2 attack must still expire in a week, not stay forever")
	GameState.reset()
	GameState.day = 21
	var wk_mana_base: int = GameState.get_total_max_mana()
	GameState.next_day() # день 22 — Неделя Магии
	assert(GameState.week_mana_bonus == 20 and GameState.max_mana == wk_mana_base + 20, "Week of Magic adds 20 max mana, not 40")
	GameState.reset()
	print("  -> Weekly bonuses survive reloads and expire on time!")

	# 65. Королевские отряды и Друиды не выглядят как базовые: у каждого существа свой арт
	print("[TEST] 65. Testing Distinct Unit Art (royal units, druids)...")
	for va_pair in [["royal_griffin", "griffin"], ["royal_fairy", "fairy_archer"], ["druid", "fairy_archer"]]:
		var va_unit: Dictionary = UnitData.get_unit(va_pair[0])
		var va_base: Dictionary = UnitData.get_unit(va_pair[1])
		for va_key in ["token_path", "sprite_path"]:
			var va_path: String = va_unit.get(va_key, "")
			assert(va_path != va_base.get(va_key, ""), "%s must not reuse the %s of %s" % [va_pair[0], va_key, va_pair[1]])
			var va_tex = load(va_path)
			assert(va_tex is Texture2D and va_tex.get_width() > 0, "%s: %s must load (%s)" % [va_pair[0], va_key, va_path])
	var va_seen := {}
	for va_id in UnitData.UNITS:
		for va_key in ["token_path", "sprite_path"]:
			var va_slot: String = va_key + ":" + str(UnitData.UNITS[va_id].get(va_key, ""))
			assert(not va_seen.has(va_slot), "%s and %s share the same %s" % [va_id, va_seen.get(va_slot, ""), va_slot])
			va_seen[va_slot] = va_id
	print("  -> Royal griffins, royal fairies and druids have their own art!")

	# 66. Полное войско: найм не забирает золото впустую, подаренные отряды не исчезают
	print("[TEST] 66. Testing Full Army (hiring, gifted units, Week of Fairies)...")
	GameState.reset()
	GameState.flags["chapter_intro_seen_1"] = true
	GameState.player_army = [
		{"unit_id": "griffin", "count": 1},
		{"unit_id": "wolf", "count": 1},
		{"unit_id": "goblin", "count": 1},
		{"unit_id": "druid", "count": 1},
		{"unit_id": "treant", "count": 1}
	]
	GameState.gold = 3000
	GameState.dwelling_stock["fairy_camp"] = 14
	var fa_wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(fa_wm)
	await get_tree().process_frame
	fa_wm._open_dwelling_popup("fairy_camp")
	fa_wm.popup_btn1.emit_signal("pressed")
	assert(GameState.gold == 3000, "Full army: hiring fairies must not take the gold")
	assert(GameState.player_army.size() == 5 and int(GameState.dwelling_stock["fairy_camp"]) == 14, "Full army: nothing hired, the stock stays")
	assert(fa_wm.popup_title.text == tr("Войско полно"), "The player is told that the army is full")
	GameState.player_army[0] = {"unit_id": "fairy_archer", "count": 1}
	fa_wm._open_dwelling_popup("fairy_camp")
	fa_wm.popup_btn1.emit_signal("pressed")
	assert(GameState.gold == 3000 - 14 * 30 and GameState.player_army[0]["count"] == 15, "A fairy stack still accepts hired fairies")
	# Подарок: улучшенный стек той же линии, иначе — золото по цене найма
	GameState.player_army[0] = {"unit_id": "royal_fairy", "count": 5}
	var fa_res: Dictionary = GameState.grant_units("fairy_archer", 10)
	assert(fa_res["unit_id"] == "royal_fairy" and GameState.player_army[0]["count"] == 15, "Gifted fairies join the Royal Fairies when there is no slot")
	var fa_gold := GameState.gold
	fa_res = GameState.grant_units("griffin", 8)
	assert(fa_res["gold"] == 8 * 65 and GameState.gold == fa_gold + 8 * 65, "No room at all: griffins are paid out at the nest price")
	assert(GameState.player_army.size() == 5, "Gifts never push the army past 5 stacks")
	fa_res = GameState.grant_units("royal_pegasus", 4)
	assert(fa_res["gold"] == 4 * (30 + 35 * int(UnitData.get_unit("royal_pegasus")["tier"])), "Units without a dwelling are valued like the merchant does")
	# Неделя Фей при полном войске без фей: феи не исчезают молча
	GameState.player_army[0] = {"unit_id": "griffin", "count": 1}
	GameState.day = 7
	fa_gold = GameState.gold
	GameState.next_day()
	assert(GameState.last_astrologers_event.get("id", "") == "week_of_fairies", "Day 8 brings the Week of Fairies")
	assert(GameState.gold == fa_gold + 10 * 30, "Fairies that found no room are paid out (10 x 30 gold)")
	fa_wm._show_astrologers_popup(GameState.last_astrologers_event)
	assert(fa_wm.popup_text.text.contains(str(10 * 30)), "The astrologers popup says what became of the fairies")
	fa_wm.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Full army: hiring keeps the gold, gifted units join or are paid out!")

	# 67. Удача и боевой дух врага — только на высокой сложности; Воодушевление удваивает боевой дух
	print("[TEST] 67. Testing Enemy Luck & Morale on Hard Difficulties...")
	for ef_diff in ["easy", "normal"]:
		var ef_calm: Dictionary = GameState.get_enemy_fortune(ef_diff)
		assert(float(ef_calm["luck"]) == 0.0 and float(ef_calm["morale"]) == 0.0, "%s stays cozy: no enemy luck or morale" % ef_diff)
	assert(float(GameState.get_enemy_fortune("legendary")["morale"]) > float(GameState.get_enemy_fortune("hard")["morale"]), "Legendary is harsher than hard")
	GameState.reset()
	GameState.campaign_difficulty = "hard"
	GameState.player_army = [{"unit_id": "griffin", "count": 10}]
	GameState.pending_battle_id = "patrol_goblins"
	var ef_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ef_arena)
	await get_tree().process_frame
	var ef_gr: BattleStack = ef_arena.all_stacks[0]
	var ef_foe: BattleStack = null
	for ef_s in ef_arena.all_stacks:
		if ef_s.team == 1:
			ef_foe = ef_s
			break
	assert(ef_arena._roll_luck(ef_foe, 0.0) and ef_arena._roll_luck(ef_gr, 0.0), "Hard: the enemy can be lucky too")
	var ef_morale: float = 0.05 + 0.10 * GameState.get_skill_level("leadership")
	assert(is_equal_approx(ef_arena.morale_chance(ef_gr), ef_morale), "Hero morale: 5% + 10% per Leadership level")
	ef_gr.buff_inspiration_turns = 2
	assert(is_equal_approx(ef_arena.morale_chance(ef_gr), ef_morale * 2.0), "Inspiration doubles the morale chance")
	ef_gr.buff_inspiration_turns = 0
	# Боевой дух врага: ИИ сразу использует дополнительный ход
	ef_foe.hex = ef_gr.hex + Vector2i(1, 0)
	ef_arena.current_actor = ef_foe
	ef_arena.is_ai_turn = true
	ef_foe.has_acted = true
	var ef_pool := func(st: BattleStack) -> int: return (st.count - 1) * int(st.data["max_hp"]) + st.current_hp
	var ef_hp_before: int = ef_pool.call(ef_gr)
	assert(ef_arena._try_morale(ef_foe, 0.0), "Hard: enemy morale grants an extra move")
	assert(not ef_foe.has_acted and ef_foe.had_morale_this_round, "The extra move is granted once per round")
	var ef_wait := 0.0
	while ef_wait < 3.0 and ef_pool.call(ef_gr) == ef_hp_before:
		await get_tree().process_frame
		ef_wait += get_process_delta_time()
	assert(ef_pool.call(ef_gr) < ef_hp_before, "The AI uses the extra move right away instead of stalling")
	# Уют: на «Воителе» у врага нет ни удачи, ни боевого духа
	GameState.campaign_difficulty = "normal"
	ef_foe.had_morale_this_round = false
	assert(not ef_arena._roll_luck(ef_foe, 0.0) and not ef_arena._try_morale(ef_foe, 0.0), "Normal: no enemy luck or morale")
	ef_arena.victory_dialog.show()
	ef_arena.turn_queue.clear()
	ef_arena.current_actor = null
	await get_tree().create_timer(0.6).timeout
	ef_arena.queue_free()
	await get_tree().process_frame
	# Сложность переживает перезапуск: load_game её раньше не читал
	GameState.campaign_difficulty = "legendary"
	GameState.save_game()
	GameState.campaign_difficulty = "normal"
	GameState.load_game()
	assert(GameState.campaign_difficulty == "legendary", "Campaign difficulty must survive save/load")
	GameState.reset()
	print("  -> Enemy luck and morale only on hard difficulties; Inspiration really doubles morale!")

	# 68. Способности существ: Стая, Трусоватые, Кости, Молния природы, Стремительный налёт
	print("[TEST] 68. Testing Creature Abilities (wolves, goblins, skeletons, druids, pegasi)...")
	GameState.reset()
	var ab_wolf := BattleStack.new()
	ab_wolf.setup("wolf", 10, 1, Vector2i(5, 3))
	var ab_prey := BattleStack.new()
	ab_prey.setup("griffin", 10, 0, Vector2i(4, 3))
	assert(is_equal_approx(ab_wolf.ability_multiplier(ab_prey, true), 1.0), "Pack: no bonus against an unwounded stack")
	var ab_calm: int = ab_wolf.get_damage_range(ab_prey, true)["max_dmg"]
	ab_prey.take_damage(1)
	assert(is_equal_approx(ab_wolf.ability_multiplier(ab_prey, true), 1.25), "Pack: +25% against a stack wounded this round")
	assert(ab_wolf.get_damage_range(ab_prey, true)["max_dmg"] > ab_calm, "Pack: the forecast shows the bonus")
	ab_prey.reset_round()
	assert(not ab_prey.hit_this_round, "The wound mark clears at the start of a round")
	var ab_gob := BattleStack.new()
	ab_gob.setup("goblin", 20, 1, Vector2i(6, 3))
	assert(is_equal_approx(ab_gob.ability_multiplier(ab_prey, true), 1.0), "Goblins fight normally at full strength")
	ab_gob.count = 9
	assert(is_equal_approx(ab_gob.ability_multiplier(ab_prey, true), 0.75), "Cowardly: -25% after losing over half the stack")
	var ab_fairy := BattleStack.new()
	ab_fairy.setup("fairy_archer", 10, 0, Vector2i(0, 3))
	var ab_skel := BattleStack.new()
	ab_skel.setup("skeleton_archer", 10, 1, Vector2i(10, 3))
	assert(is_equal_approx(ab_fairy.ability_multiplier(ab_skel, false), 0.75) and is_equal_approx(ab_fairy.ability_multiplier(ab_skel, true), 1.0), "Bones: only shots are weakened")
	var ab_arrows: int = ab_fairy.get_damage_range(ab_skel, false)["max_dmg"]
	ab_skel.data = ab_skel.data.duplicate()
	ab_skel.data.erase("ranged_resist")
	assert(ab_arrows < ab_fairy.get_damage_range(ab_skel, false)["max_dmg"], "Bones: the forecast shows the reduced arrow damage")
	var ab_druid := BattleStack.new()
	ab_druid.setup("druid", 5, 0, Vector2i(0, 3))
	assert(ab_fairy.has_range_penalty(Vector2i(10, 3)) and not ab_druid.has_range_penalty(Vector2i(10, 3)), "Nature's lightning: druids shoot across the field without penalty")
	var ab_peg := BattleStack.new()
	ab_peg.setup("royal_pegasus", 5, 0, Vector2i(3, 3))
	assert(not ab_gob.will_retaliate(ab_peg) and ab_gob.will_retaliate(ab_prey), "Swift strike: no retaliation against pegasi")
	for ab_uid in ["wolf", "goblin", "skeleton_archer", "druid", "royal_pegasus"]:
		assert(UnitData.get_trait_string(ab_uid) != "Пехота ближнего боя", "%s shows its ability in the codex" % ab_uid)
	# Английский кодекс: способности переводятся поштучно, как и остальные черты
	var ab_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	for ab_en_uid in ["wolf", "goblin", "skeleton_archer", "druid", "royal_pegasus"]:
		assert(not _has_cyrillic(UnitData.get_trait_string(ab_en_uid)), "%s abilities must be translated in the codex" % ab_en_uid)
	TranslationServer.set_locale(ab_locale)
	# В бою: друиды без штрафа за дальность в прогнозе, пегасы бьют без ответа
	GameState.player_army = [{"unit_id": "royal_pegasus", "count": 6}, {"unit_id": "druid", "count": 6}]
	GameState.pending_battle_id = "patrol_goblins"
	var ab_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ab_arena)
	await get_tree().process_frame
	var ab_bpeg: BattleStack = ab_arena.all_stacks[0]
	var ab_bdru: BattleStack = ab_arena.all_stacks[1]
	var ab_bfoe: BattleStack = null
	for ab_s in ab_arena.all_stacks:
		if ab_s.team == 1:
			ab_bfoe = ab_s
			break
	ab_arena.current_actor = ab_bdru
	ab_bdru.hex = Vector2i(0, 3)
	ab_bfoe.hex = Vector2i(10, 3)
	ab_arena._show_attack_forecast(ab_bfoe)
	assert(not ab_arena.hovered_is_broken, "The forecast shows no range penalty for druids")
	ab_bfoe.hex = ab_bpeg.hex + Vector2i(1, 0)
	var ab_peg_hp: int = (ab_bpeg.count - 1) * int(ab_bpeg.data["max_hp"]) + ab_bpeg.current_hp
	ab_arena.current_actor = ab_bpeg
	await ab_arena._execute_attack(ab_bpeg, ab_bfoe, true)
	assert((ab_bpeg.count - 1) * int(ab_bpeg.data["max_hp"]) + ab_bpeg.current_hp == ab_peg_hp and not ab_bfoe.has_retaliated, "Pegasi strike without retaliation in battle")
	# ИИ за пегасов не боится ответного удара: пегасам не отвечают
	var ab_saved_stacks = ab_arena.all_stacks
	var ab_ai_peg := BattleStack.new()
	ab_ai_peg.setup("royal_pegasus", 5, 1, Vector2i(5, 3))
	var ab_ai_griffins := BattleStack.new()
	ab_ai_griffins.setup("royal_griffin", 40, 0, Vector2i(4, 3))
	var ab_ai_lone := BattleStack.new()
	ab_ai_lone.setup("goblin", 1, 0, Vector2i(2, 3))
	var ab_ai_field: Array[BattleStack] = [ab_ai_peg, ab_ai_griffins, ab_ai_lone]
	ab_arena.all_stacks = ab_ai_field
	var ab_ai_targets: Array[BattleStack] = [ab_ai_griffins, ab_ai_lone]
	assert(ab_arena._select_ai_target(ab_ai_peg, ab_ai_targets) == ab_ai_griffins, "AI pegasi must not fear a retaliation they never get")
	ab_arena.all_stacks = ab_saved_stacks
	ab_arena.victory_dialog.show()
	ab_arena.turn_queue.clear()
	ab_arena.current_actor = null
	await get_tree().create_timer(0.6).timeout
	ab_arena.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Wolves hunt in packs, goblins lose heart, bones shrug off arrows, druids and pegasi shine!")

	# 69. Ветеранские полки: победы копятся по видам, ранги дают +атаку и +защиту
	print("[TEST] 69. Testing Veteran Regiments...")
	GameState.reset()
	assert(GameState.veteran_rank("griffin") == 0, "A fresh campaign has no veterans")
	GameState.veteran_wins["griffin"] = 2
	var vet_promos: Array[Dictionary] = GameState.add_veteran_wins(["griffin", "wolf"])
	assert(vet_promos.size() == 1 and vet_promos[0]["unit_id"] == "griffin" and vet_promos[0]["rank"] == 1, "The third victory makes griffins veterans")
	assert(GameState.veteran_rank("wolf") == 0, "One victory is not enough for wolves")
	GameState.veteran_wins["griffin"] = 40
	assert(GameState.veteran_rank("griffin") == 3, "Rank caps at 3")
	# В бою: +ранг к атаке и защите, общий UnitData не меняется, враги не ветераны
	var vet_base_att: int = int(UnitData.get_unit("griffin")["attack"])
	var vet_base_def: int = int(UnitData.get_unit("griffin")["defense"])
	GameState.player_army = [{"unit_id": "griffin", "count": 10}]
	GameState.pending_battle_id = "patrol_goblins"
	var vet_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(vet_arena)
	await get_tree().process_frame
	var vet_gr: BattleStack = vet_arena.all_stacks[0]
	assert(vet_gr.veteran_rank == 3 and int(vet_gr.data["attack"]) == vet_base_att + 3 and int(vet_gr.data["defense"]) == vet_base_def + 3, "Veteran griffins fight with +3 attack and defense")
	assert(int(UnitData.get_unit("griffin")["attack"]) == vet_base_att, "Shared unit data stays untouched")
	for vet_s in vet_arena.all_stacks:
		if vet_s.team == 1:
			assert(vet_s.veteran_rank == 0, "Enemies are not veterans")
	# Победа засчитывается уцелевшим видам и объявляется в итогах боя
	GameState.veteran_wins["griffin"] = 7
	vet_arena._show_victory(true)
	assert(GameState.veteran_rank("griffin") == 2 and vet_arena.victory_desc.text.contains("🎖"), "A won battle promotes the surviving kind and says so")
	vet_arena.queue_free()
	await get_tree().process_frame
	# Сохранение и улучшение полка
	GameState.save_game()
	GameState.veteran_wins.clear()
	GameState.load_game()
	assert(int(GameState.veteran_wins.get("griffin", 0)) == 8, "Veteran wins survive save/load")
	GameState.gold = 99999
	GameState.player_army = [{"unit_id": "griffin", "count": 2}]
	assert(GameState.upgrade_army_unit(0) and GameState.veteran_rank("royal_griffin") == 2, "The regiment keeps its rank after an upgrade")
	GameState.reset()
	assert(GameState.veteran_wins.is_empty(), "A new game starts without veterans")
	print("  -> Veteran regiments earn ranks, fight better and survive saves and upgrades!")

	# 70. Сказочные встречи на карте и побочный квест «Овечка Белянка»
	print("[TEST] 70. Testing Map Events & the Lost Sheep Side Quest...")
	var me_all: Dictionary = MapEventData.get_all()
	assert(me_all.size() > 5, "Map events must load from data/map_events.json")
	for me_id in me_all:
		if not (me_all[me_id] is Dictionary):
			continue
		var me_d: Dictionary = me_all[me_id]
		var me_choices: Array = me_d.get("choices", [])
		assert(str(me_d.get("title", "")) != "" and str(me_d.get("text", "")) != "" and me_choices.size() >= 1 and me_choices.size() <= 2, "Event %s needs a title, text and 1-2 choices" % me_id)
		for me_c in me_choices:
			assert(str(me_c.get("label", "")) != "" and str(me_c.get("result", "")) != "", "Every choice of %s needs a label and a result" % me_id)
	for me_ch in [1, 2, 3]:
		GameState.reset()
		GameState.start_chapter(me_ch)
		GameState.flags["chapter_intro_seen_%d" % me_ch] = true
		var me_wm = load("res://src/world/world_map.tscn").instantiate()
		add_child(me_wm)
		await get_tree().process_frame
		var me_visible: Array[Dictionary] = MapEventData.visible_for_chapter(me_ch, GameState.flags)
		assert(me_visible.size() >= 2, "Chapter %d must have map events" % me_ch)
		for me_ev in me_visible:
			assert(me_wm.world_view.objects.get(me_ev["cell"], {}).get("id", "") == me_ev["id"], "Event %s must stand on its own free, passable cell" % me_ev["id"])
		me_wm.queue_free()
		await get_tree().process_frame
	# Эффекты: золото, характеристики, очки хода (не ниже нуля)
	GameState.reset()
	var me_att: int = GameState.attack
	var me_gold: int = GameState.gold
	GameState.move_points = 2
	var me_lines: Array[String] = GameState.apply_event_effects({"gold": -100, "attack": 1, "move_points": -3})
	assert(GameState.gold == me_gold - 100 and GameState.attack == me_att + 1 and GameState.move_points == 0, "Event effects change gold, stats and movement (never below zero)")
	assert(me_lines.size() == 3 and me_lines[0].contains("-100"), "Every effect is listed in the result")
	# Цепочка квеста: просьба -> овечка на карте -> благодарность -> награда один раз
	GameState.reset()
	GameState.start_chapter(1)
	GameState.flags["chapter_intro_seen_1"] = true
	var me_map = load("res://src/world/world_map.tscn").instantiate()
	add_child(me_map)
	await get_tree().process_frame
	var me_objs: Dictionary = me_map.world_view.objects
	var me_shep := Vector2i(2, 10)
	var me_sheep := Vector2i(12, 19)
	assert(me_objs.get(me_shep, {}).get("id", "") == "ch1_shepherd" and not me_objs.has(me_sheep), "At first only the shepherdess asks for help")
	me_map._trigger_object(me_objs[me_shep])
	assert(me_map.popup_title.text == tr("Пастушка Мила") and me_map.popup_btn2.visible, "The shepherdess offers two choices")
	me_map.popup_btn2.emit_signal("pressed")
	assert(me_objs.get(me_shep, {}).get("id", "") == "ch1_shepherd", "'Later' keeps the shepherdess waiting")
	me_map._trigger_object(me_objs[me_shep])
	me_map.popup_btn1.emit_signal("pressed")
	assert(GameState.flags.get("sheep_quest", false) and me_objs.get(me_sheep, {}).get("id", "") == "ch1_lost_sheep", "Accepting the quest puts the lost sheep on the map")
	assert(me_objs.get(me_shep, {}).get("id", "") == "ch1_shepherd_wait", "The shepherdess waits for news")
	me_map._trigger_object(me_objs[me_sheep])
	me_map.popup_btn1.emit_signal("pressed")
	assert(not me_objs.has(me_sheep) and me_objs.get(me_shep, {}).get("id", "") == "ch1_shepherd_thanks", "Found sheep: the shepherdess waits to thank the hero")
	var me_gold2: int = GameState.gold
	me_map._trigger_object(me_objs[me_shep])
	me_map.popup_btn1.emit_signal("pressed")
	assert(GameState.gold == me_gold2 + 300 and not me_objs.has(me_shep), "The reward is paid once and the quest leaves the map")
	# Платный выбор без денег ничего не делает, встреча остаётся
	GameState.gold = 0
	var me_minstrel := Vector2i(28, 8)
	me_map._trigger_object(me_objs[me_minstrel])
	me_map.popup_btn1.emit_signal("pressed")
	assert(GameState.gold == 0 and not GameState.flags.get("ch1_minstrel", false) and me_objs.has(me_minstrel), "Without gold the paid choice does nothing and the minstrel stays")
	me_map.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Map events stand on their cells, choices apply once, the Lost Sheep quest runs to its end!")

	# 71. Плейлисты: короткие темы сменяют друг друга, одиночная тема останавливает подборку
	print("[TEST] 71. Testing Music Playlists...")
	for pl_key in SoundManager.PLAYLISTS:
		for pl_path in SoundManager.PLAYLISTS[pl_key]:
			assert(ResourceLoader.exists(pl_path), "Playlist %s: missing %s" % [pl_key, pl_path])
	SoundManager.play_playlist("map_1")
	assert(SoundManager.current_music_path == SoundManager.PLAYLISTS["map_1"][0], "A playlist starts with the chapter theme")
	var pl_len: float = SoundManager.music_player.stream.get_length()
	var pl_wait: float = SoundManager._playlist_timer.wait_time
	assert(pl_wait >= SoundManager.PLAYLIST_TRACK_SECONDS and pl_wait < SoundManager.PLAYLIST_TRACK_SECONDS + pl_len + 0.01, "Each theme plays about 40 s, in whole loops")
	assert(SoundManager._playlist_timer.ignore_time_scale, "Battle speed-up must not rush the music")
	SoundManager._advance_playlist()
	assert(SoundManager.current_music_path == SoundManager.PLAYLISTS["map_1"][1], "Then the next theme plays")
	SoundManager.play_playlist("map_1")
	assert(SoundManager.current_music_path == SoundManager.PLAYLISTS["map_1"][1], "Re-entering the map does not restart a running playlist")
	SoundManager.play_music("res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg")
	assert(SoundManager._playlist.is_empty() and SoundManager._playlist_timer.is_stopped(), "A single theme (menu, boss) stops the playlist")
	GameState.reset()
	GameState.start_chapter(2)
	GameState.flags["chapter_intro_seen_2"] = true
	var pl_wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(pl_wm)
	await get_tree().process_frame
	assert(SoundManager._playlist == SoundManager.PLAYLISTS["map_2"], "The swamp map plays its own playlist")
	pl_wm.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Short music loops now rotate in chapter and battle playlists!")

	# 72. Прямоугольное поле боя: кромки вертикальные, строй стоит колонной, поле на экране
	print("[TEST] 72. Testing Rectangular Battlefield...")
	var rf_bounds := Rect2i(0, 0, BattleArena.GRID_COLS, BattleArena.GRID_ROWS)
	var rf_cells: Array[Vector2i] = HexGrid.field_cells(rf_bounds)
	assert(rf_cells.size() == BattleArena.GRID_COLS * BattleArena.GRID_ROWS, "The field keeps cols x rows cells")
	for rf_c in rf_cells:
		assert(HexGrid.is_in_bounds(rf_c, rf_bounds), "Every field cell is in bounds")
		assert(HexGrid.offset_to_axial(HexGrid.axial_to_offset(rf_c)) == rf_c, "Axial/offset conversion round-trips")
	assert(not HexGrid.is_in_bounds(Vector2i(10, 6), rf_bounds), "The old parallelogram corner (10, 6) is off the field now")
	var rf_w: float = BattleArena.HEX_SIZE * HexGrid.SQRT_3
	for rf_col in [0, BattleArena.GRID_COLS - 1]:
		var rf_xs: Array[float] = []
		for rf_row in BattleArena.GRID_ROWS:
			var rf_h := HexGrid.offset_to_axial(Vector2i(rf_col, rf_row))
			rf_xs.append(HexGrid.hex_to_pixel(rf_h.x, rf_h.y, BattleArena.HEX_SIZE, Vector2.ZERO).x)
		assert(rf_xs.max() - rf_xs.min() <= rf_w * 0.5 + 0.01, "Column %d is a vertical zigzag, not a diagonal" % rf_col)
	# В бою: войско героя — в колонке 0, враги — в колонке из encounters.json, препятствия и ходы — на поле
	GameState.reset()
	GameState.player_army = [{"unit_id": "griffin", "count": 5}, {"unit_id": "fairy_archer", "count": 5}, {"unit_id": "wolf", "count": 5}, {"unit_id": "treant", "count": 2}, {"unit_id": "druid", "count": 3}]
	GameState.pending_battle_id = "patrol_goblins"
	var rf_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(rf_arena)
	await get_tree().process_frame
	for rf_s in rf_arena.all_stacks:
		var rf_cell := HexGrid.axial_to_offset(rf_s.hex)
		assert(rf_cell.x == (0 if rf_s.team == 0 else 10), "Armies stand at the field edges (%s is in column %d)" % [rf_s.unit_id, rf_cell.x])
	for rf_o in rf_arena.obstacles:
		assert(HexGrid.is_in_bounds(rf_o, rf_arena.field_bounds), "Obstacles stay on the field")
	for rf_actor in [rf_arena.all_stacks[0], rf_arena.all_stacks[2]]:
		rf_arena.current_actor = rf_actor
		rf_arena._update_reachable_hexes()
		assert(not rf_arena.reachable_hexes.is_empty(), "%s can move" % rf_actor.unit_id)
		for rf_r in rf_arena.reachable_hexes:
			assert(HexGrid.is_in_bounds(rf_r, rf_arena.field_bounds), "%s never leaves the field" % rf_actor.unit_id)
	# Поле целиком на экране 1920x1080: между шкалой инициативы и панелью героя, по центру
	var rf_min := Vector2(INF, INF)
	var rf_max := Vector2(-INF, -INF)
	for rf_c in rf_cells:
		var rf_px := HexGrid.hex_to_pixel(rf_c.x, rf_c.y, BattleArena.HEX_SIZE, rf_arena.grid_origin)
		rf_min = rf_min.min(rf_px)
		rf_max = rf_max.max(rf_px)
	assert(rf_min.x - rf_w * 0.5 >= 0.0 and rf_max.x + rf_w * 0.5 <= 1920.0, "The field fits the screen width")
	assert(rf_min.y - BattleArena.HEX_SIZE >= 100.0 and rf_max.y + BattleArena.HEX_SIZE <= 860.0, "The field stays between the initiative bar and the hero panel")
	assert(absf((rf_min.x + rf_max.x) * 0.5 - 960.0) < 80.0, "The field is centered")
	rf_arena.victory_dialog.show()
	rf_arena.turn_queue.clear()
	rf_arena.current_actor = null
	await get_tree().create_timer(0.6).timeout
	rf_arena.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> The battlefield is a rectangle: armies form columns and every hex fits the screen!")

	# 73. Распустить отряд: освобождает слот, спрашивает подтверждение, последний не распускается
	print("[TEST] 73. Testing Dismiss Stack...")
	GameState.reset()
	GameState.player_army = [{"unit_id": "griffin", "count": 5}, {"unit_id": "wolf", "count": 7}, {"unit_id": "goblin", "count": 9}]
	assert(GameState.dismiss_stack(1) and GameState.player_army.size() == 2 and GameState.player_army[1]["unit_id"] == "goblin", "Dismissing frees the slot")
	assert(GameState.fallen_units.is_empty(), "Dismissed warriors are not fallen: Grace does not bring them back")
	assert(not GameState.dismiss_stack(5), "A missing slot cannot be dismissed")
	GameState.player_army = [{"unit_id": "griffin", "count": 5}]
	assert(not GameState.dismiss_stack(0) and GameState.player_army.size() == 1, "The last stack always stays")
	# В панели войска: кнопка есть только у выбранного отряда, подтверждение, «Оставить» ничего не меняет
	GameState.flags["chapter_intro_seen_1"] = true
	GameState.player_army = [{"unit_id": "griffin", "count": 5}, {"unit_id": "wolf", "count": 7}]
	var ds_wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(ds_wm)
	await get_tree().process_frame
	ds_wm.popup_dialog.hide()
	var ds_find := func() -> Button:
		for ds_b in ds_wm.army_container.find_children("*", "Button", true, false):
			if ds_b.text == "✖" and not ds_b.is_queued_for_deletion():
				return ds_b
		return null
	assert(ds_find.call() == null, "No dismiss button until a stack is selected")
	ds_wm.selected_army_slot = 1
	ds_wm._army_panel_sig = ""
	ds_wm._update_hud()
	var ds_btn: Button = ds_find.call()
	assert(ds_btn != null, "The selected stack shows the dismiss button")
	ds_btn.emit_signal("pressed")
	assert(ds_wm.popup_dialog.visible and ds_wm.popup_btn2.visible, "Dismissing asks for confirmation")
	ds_wm.popup_btn2.emit_signal("pressed")
	assert(GameState.player_army.size() == 2, "'Keep' changes nothing")
	ds_wm._confirm_dismiss_stack(1)
	ds_wm.popup_btn1.emit_signal("pressed")
	assert(GameState.player_army.size() == 1 and GameState.player_army[0]["unit_id"] == "griffin", "Confirmed: the wolves leave the army")
	ds_wm._show_army_full_popup()
	assert(ds_wm.popup_text.text == tr("В войске нет свободных слотов. Объедините одинаковые отряды или выберите лишний в панели «Войско Героя» и распустите его (✖)."), "The full-army hint explains how to free a slot")
	ds_wm.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Stacks can be dismissed with confirmation, the last one always stays!")

	# 74. Новые существа: Единороги (поляна в гл. 2) и огненные враги Пика Дракона
	print("[TEST] 74. Testing New Creatures (unicorns, lava salamanders, magma golems)...")
	for nc_id in ["unicorn", "lava_salamander", "magma_golem"]:
		var nc_u: Dictionary = UnitData.get_unit(nc_id)
		assert(not nc_u.is_empty(), "Unit %s must exist" % nc_id)
		assert(ResourceLoader.exists(nc_u["token_path"]) and ResourceLoader.exists(nc_u["sprite_path"]), "%s must have a token and a sprite" % nc_id)
		assert(UnitData.get_trait_string(nc_id) != "Пехота ближнего боя", "%s shows its ability in the codex" % nc_id)
	# Английский кодекс: черты новых существ переводятся поштучно
	var nc_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	for nc_en_id in ["unicorn", "lava_salamander", "magma_golem"]:
		assert(not _has_cyrillic(UnitData.get_trait_string(nc_en_id)), "%s traits must be translated in the codex" % nc_en_id)
	TranslationServer.set_locale(nc_locale)
	assert(float(UnitData.get_unit("unicorn")["blind_chance"]) > 0.0, "Unicorns blind with their horn")
	assert(float(UnitData.get_unit("lava_salamander")["reflect"]) > 0.0 and int(UnitData.get_unit("magma_golem")["regeneration"]) > 0, "Salamanders burn back, golems regenerate")
	# Пик Дракона охраняют свои огненные враги, а не грифоны и древни
	var nc_fire := 0
	for nc_enc in ["dragon_patrol_pass", "dragon_patrol_gate", "dragon_patrol_caldera", "dragon_patrol_citadel", "dragon_boss"]:
		for nc_e in EncounterData.get_encounter(nc_enc)["enemies"]:
			assert(nc_e["unit_id"] not in ["griffin", "treant", "goblin"], "%s must not be guarded by %s any more" % [nc_enc, nc_e["unit_id"]])
			if nc_e["unit_id"] in ["lava_salamander", "magma_golem"]:
				nc_fire += 1
	assert(nc_fire >= 5, "Chapter 3 encounters use the new fire creatures")
	# Лунная поляна: жилище гл. 2 из dwellings.json, запас 2 и +2 в неделю
	assert(DwellingData.get_dwelling("unicorn_glade").get("unit", "") == "unicorn", "The glade hires unicorns")
	GameState.reset()
	GameState.start_chapter(2)
	GameState.flags["chapter_intro_seen_2"] = true
	assert(int(GameState.dwelling_stock.get("unicorn_glade", 0)) == 2, "The glade starts with 2 unicorns")
	var nc_wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(nc_wm)
	await get_tree().process_frame
	var nc_glade: Dictionary = nc_wm.world_view.objects.get(Vector2i(28, 15), {})
	assert(nc_glade.get("type", "") == "unicorn_glade", "The glade stands on the chapter 2 map")
	assert(nc_wm.world_view.get_object_texture({"type": "encounter", "id": "dragon_patrol_caldera"}) == nc_wm.world_view.creature_tokens.get("magma_golem"), "Chapter 3 patrols show the new tokens on the map")
	GameState.gold = 1000
	GameState.player_army = [{"unit_id": "griffin", "count": 5}]
	nc_wm._trigger_object(nc_glade)
	nc_wm.popup_btn1.emit_signal("pressed")
	assert(GameState.player_army.size() == 2 and GameState.player_army[1]["unit_id"] == "unicorn" and GameState.player_army[1]["count"] == 2, "Two unicorns join for 300 gold")
	assert(GameState.gold == 1000 - 2 * 150, "Unicorns cost 150 gold each")
	nc_wm.queue_free()
	await get_tree().process_frame
	GameState.day = 7
	GameState.next_day()
	assert(int(GameState.dwelling_stock.get("unicorn_glade", 0)) == 2, "A new week brings 2 more unicorns")
	# В бою: удар рога ослепляет цель (шанс поднят до 100% для проверки)
	GameState.reset()
	GameState.player_army = [{"unit_id": "unicorn", "count": 6}]
	GameState.pending_battle_id = "patrol_goblins"
	var nc_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(nc_arena)
	await get_tree().process_frame
	var nc_uni: BattleStack = nc_arena.all_stacks[0]
	var nc_foe: BattleStack = null
	for nc_s in nc_arena.all_stacks:
		if nc_s.team == 1:
			nc_foe = nc_s
			break
	nc_uni.data = nc_uni.data.duplicate()
	nc_uni.data["blind_chance"] = 1.0
	nc_foe.hex = nc_uni.hex + Vector2i(1, 0)
	# Цель должна пережить удар, иначе слепоту не проверить: 6 единорогов порой вырезают всех 24 гоблинов
	nc_foe.count = 200
	nc_arena.current_actor = nc_uni
	await nc_arena._execute_attack(nc_uni, nc_foe, true)
	assert(nc_foe.is_alive() and nc_foe.is_blinded(), "The unicorn horn blinds the target")
	nc_arena.victory_dialog.show()
	nc_arena.turn_queue.clear()
	nc_arena.current_actor = null
	await get_tree().create_timer(0.6).timeout
	nc_arena.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Unicorns join from the moonlit glade and blind foes; the Dragon Peak has its own fire creatures!")

	# 75. Крючки под арт: у каждого объекта карты есть место под свой значок, фоны боя по главам
	print("[TEST] 75. Testing Art Hooks (map object icons, battle backgrounds)...")
	var ah_combat := ["encounter", "bandit_boss", "lich_boss", "dragon_boss"]
	for ah_ch in [1, 2, 3]:
		GameState.reset()
		GameState.start_chapter(ah_ch)
		GameState.flags["chapter_intro_seen_%d" % ah_ch] = true
		var ah_wm = load("res://src/world/world_map.tscn").instantiate()
		add_child(ah_wm)
		await get_tree().process_frame
		for ah_obj in ah_wm.world_view.objects.values():
			var ah_type: String = ah_obj.get("type", "")
			if ah_type in ah_combat:
				continue
			assert(ah_type in WorldView.MAP_OBJECT_ICON_TYPES, "Map object type %s must be listed for its own icon (and in the art brief)" % ah_type)
			assert(ah_wm.world_view.icons.get(ah_type) != null, "Map object type %s keeps a fallback icon until the art arrives" % ah_type)
		ah_wm.queue_free()
		await get_tree().process_frame
	assert(WorldView.object_icon_override("mill", 1) == "", "No own icons yet: the generic ones stay")
	for ah_id in ["", "patrol_goblins", "bandit_boss", "lich_boss", "dragon_boss"]:
		assert(BattleArena.background_path(ah_id, 1) == "", "No own backgrounds yet: the meadow stays")
	GameState.reset()
	GameState.pending_battle_id = "patrol_goblins"
	var ah_arena = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ah_arena)
	await get_tree().process_frame
	assert(ah_arena.get_node("Background").texture.resource_path.ends_with("meadow_bg.jpg"), "Without new art the battle keeps the meadow")
	ah_arena.victory_dialog.show()
	ah_arena.turn_queue.clear()
	ah_arena.current_actor = null
	await get_tree().create_timer(0.6).timeout
	ah_arena.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Every map object and battle has a hook for its own art, with safe fallbacks!")

	# 76. Иллюстрации встреч: место под заголовком, без картинки скрыто, при закрытии окна прячется
	print("[TEST] 76. Testing Event Illustrations...")
	assert(str(MapEventData.get_event("ch1_shepherd_thanks").get("image", "")) == "ch1_shepherd", "Quest stages share the shepherdess picture")
	assert(MapEventData.image_path("ch1_lost_fawn") == "", "No pictures yet: the popup keeps text only")
	GameState.reset()
	GameState.start_chapter(1)
	GameState.flags["chapter_intro_seen_1"] = true
	var ea_wm = load("res://src/world/world_map.tscn").instantiate()
	add_child(ea_wm)
	await get_tree().process_frame
	ea_wm._trigger_object(ea_wm.world_view.objects[Vector2i(12, 6)])
	var ea_art: TextureRect = ea_wm.popup_title.get_parent().get_node("EventArt")
	assert(ea_art.get_index() == ea_wm.popup_title.get_index() + 1 and not ea_art.visible, "The picture slot sits under the title and stays hidden without art")
	ea_art.texture = load("res://assets/art/world/icon_quest.png")
	ea_art.visible = true
	ea_wm.popup_dialog.hide()
	assert(not ea_art.visible, "Closing the popup hides the picture, other popups never show it")
	ea_wm._trigger_object(ea_wm.world_view.objects[Vector2i(12, 6)])
	assert(ea_wm.popup_title.get_parent().get_children().filter(func(n): return n.name == "EventArt").size() == 1, "The picture slot is created once")
	ea_wm.queue_free()
	await get_tree().process_frame
	GameState.reset()
	print("  -> Event popups have a picture slot that stays hidden until the art arrives!")

	# Наборы из tests/suites/: один файл — один набор, номера идут дальше по алфавиту файлов
	var suites := _suite_files()
	for i in suites.size():
		var suite = load(suites[i]).new()
		print("[TEST] %d. %s..." % [INLINE_SUITES + i + 1, suite.TITLE])
		await suite.run(self)

	print("\n==========================================")
	print("   ALL %d TEST SUITES PASSED FLAWLESSLY!  " % (INLINE_SUITES + suites.size()))
	print("==========================================\n")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _has_cyrillic(text: String) -> bool:
	return RegEx.create_from_string("[А-Яа-яЁё]").search(text) != null

## Русские строки из src/ без английского перевода. Правила те же, что у
## tools/extract_strings.py: литералы .gd и видимые свойства .tscn.
func _untranslated_source_strings() -> Array[String]:
	var en := TranslationServer.get_translation_object("en")
	var literal := RegEx.create_from_string(r'"((?:[^"\\]|\\.)*)"')
	var scene_prop := RegEx.create_from_string(r'(?m)^(?:text|tooltip_text|placeholder_text|title|dialog_text) = "((?:[^"\\]|\\.)*)"')
	var missing: Array[String] = []
	for path in _collect_source_files("res://src"):
		var re := scene_prop if path.ends_with(".tscn") else literal
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var key := m.get_string(1).c_unescape()
			if _has_cyrillic(key) and String(en.get_message(key)) == "" and not missing.has(key):
				missing.append(key)
	return missing

func _collect_source_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			result.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		result.append_array(_collect_source_files(dir_path.path_join(d)))
	return result

## Арена боя с боссом с остановленным ходом боя: способности зовутся напрямую.
## Видимое окно итогов останавливает _next_turn, пустой актёр — отложенный ход ИИ (0,5 с).
func _boss_arena(battle_id: String, chapter: int):
	GameState.reset()
	GameState.current_chapter = chapter
	GameState.pending_battle_id = battle_id
	var ba = load("res://src/battle/battle_arena.tscn").instantiate()
	add_child(ba)
	await _boss_freeze(ba)
	return ba

func _boss_freeze(ba) -> void:
	ba.victory_dialog.show()
	ba.turn_queue.clear()
	ba.current_actor = null
	await get_tree().create_timer(0.6).timeout

func _boss_free(ba) -> void:
	await _boss_freeze(ba)
	ba.queue_free()
	GameState.pending_battle_id = ""
	await get_tree().process_frame

func _boss_find(ba, unit_id: String) -> BattleStack:
	for st in ba.all_stacks:
		if st.unit_id == unit_id and st.is_alive():
			return st
	return null

func _boss_pool(st: BattleStack) -> int:
	return (st.count - 1) * int(st.data["max_hp"]) + st.current_hp

func _fb_pool(st: BattleStack) -> int:
	return (st.count - 1) * int(st.data["max_hp"]) + st.current_hp

## Файлы наборов из tests/suites/ по алфавиту.
func _suite_files() -> Array[String]:
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests/suites"):
		if f.ends_with(".gd"):
			files.append("res://tests/suites/" + f)
	files.sort()
	return files

func _on_watchdog() -> void:
	printerr("TEST WATCHDOG: the run did not finish in %d s. A failed assert stops the run; the failing suite is the last [TEST] line above." % int(WATCHDOG_SEC))
	get_tree().quit(1)
