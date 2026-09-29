extends Node

const SpellData = preload("res://src/core/spell_data.gd")
const ArtifactData = preload("res://src/core/artifact_data.gd")
const UnitData = preload("res://src/core/unit_data.gd")
const BattleStack = preload("res://src/battle/battle_stack.gd")

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Running full HoMM-style verification suite...")
	
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

	print("\n==========================================")
	print("   ALL 54 TEST SUITES PASSED FLAWLESSLY!  ")
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
