extends SceneTree

func _init() -> void:
	print("[TEST] Starting gameplay verification...")
	
	# 1. Test GameState Splitting & Merging
	print("[TEST] 1. Testing Army Stack Splitting & Merging...")
	GameState.player_army = [
		{"unit_id": "griffin", "count": 5}
	]
	var split_ok = GameState.split_stack(0, 1)
	assert(split_ok, "Failed to split stack")
	assert(GameState.player_army.size() == 2, "Army size should be 2 after split")
	assert(GameState.player_army[0]["count"] == 4, "Remaining count should be 4")
	assert(GameState.player_army[1]["count"] == 1, "New stack count should be 1")
	print("  -> Stack split verified: slot 0 has 4, slot 1 has 1")
	
	# Split into 5 stacks total
	GameState.split_stack(0, 1)
	GameState.split_stack(0, 1)
	GameState.split_stack(0, 1)
	assert(GameState.player_army.size() == 5, "Army size should be 5 after splits")
	print("  -> 5 stacks created successfully! Counts:", GameState.player_army.map(func(s): return s["count"]))
	
	# Test Merge
	var merge_ok = GameState.merge_stacks(0, 1)
	assert(merge_ok, "Failed to merge stacks")
	assert(GameState.player_army.size() == 4, "Army size should be 4 after merge")
	assert(GameState.player_army[0]["count"] == 2, "Merged slot count should be 2")
	print("  -> Stack merge verified: slot 0 has 2, size is 4")
	
	# Reset army to standard test composition
	GameState.player_army = [
		{"unit_id": "griffin", "count": 6},
		{"unit_id": "fairy_archer", "count": 18}
	]
	
	# 2. Test Sound Manager & Audio Clips
	print("[TEST] 2. Testing Sound Manager...")
	assert(SoundManager.sfx_streams.has("horse_gallop"), "Missing horse_gallop sfx")
	assert(SoundManager.sfx_streams.has("bow_shot"), "Missing bow_shot sfx")
	assert(SoundManager.sfx_streams.has("arrow_hit"), "Missing arrow_hit sfx")
	assert(SoundManager.sfx_streams.has("sword_hit"), "Missing sword_hit sfx")
	assert(SoundManager.sfx_streams.has("spell_cast"), "Missing spell_cast sfx")
	assert(SoundManager.sfx_streams.has("coin"), "Missing coin sfx")
	print("  -> All clean fantasy SFX are loaded and registered!")
	
	# 3. Test Unit Names length
	print("[TEST] 3. Testing Unit Names length for UI fit...")
	for uid in ["griffin", "fairy_archer", "treant", "wolf", "goblin"]:
		var u = UnitData.get_unit(uid)
		assert(u.name.length() <= 16, "Unit name too long: %s" % u.name)
		print("  -> Unit %s name: '%s' (length: %d)" % [uid, u.name, u.name.length()])
		
	# 4. Test World Map Scene & Quest nodes
	print("[TEST] 4. Testing World Scene & Quest Objects...")
	var wmap_packed = load("res://src/world/world_map.tscn")
	var wmap_node = wmap_packed.instantiate()
	root.add_child(wmap_node)
	
	var wv = wmap_node.get_node("ScrollContainer/WorldView")
	assert(wv.objects.has(Vector2i(7, 18)), "Missing Forester's Hut")
	assert(wv.objects.has(Vector2i(14, 11)), "Missing Iron Gate")
	assert(wv.objects.has(Vector2i(28, 11)), "Missing Bandit Boss Lair")
	assert(wv.objects.has(Vector2i(27, 4)), "Missing Fairy Queen Shrine")
	print("  -> All quest locations verified on map!")
	
	# Test Forester Quest trigger
	var forester_obj = wv.objects[Vector2i(7, 18)]
	wmap_node._trigger_object(forester_obj)
	assert(wmap_node.popup_dialog.visible, "Popup dialog should be visible")
	# Click accept key
	wmap_node.popup_btn1.emit_signal("pressed")
	assert(GameState.has_gate_key, "Player should have received Gate Key")
	assert(GameState.quest_forester_started, "Forester quest should be started")
	print("  -> Forester dialog gave Gate Key: has_gate_key = %s" % GameState.has_gate_key)
	
	# Test Gate with Key
	var gate_obj = wv.objects[Vector2i(14, 11)]
	wmap_node._trigger_object(gate_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	assert(GameState.flags.get("iron_gate_opened", false), "Iron Gate should now be opened")
	print("  -> Iron Gate unlocked successfully!")
	
	# Test Fairy Queen Shrine without crown
	var shrine_obj = wv.objects[Vector2i(27, 4)]
	wmap_node._trigger_object(shrine_obj)
	assert(not GameState.quest_completed, "Quest should not be completed yet")
	wmap_node.popup_btn1.emit_signal("pressed")
	
	# Grant Crown (simulating Boss Victory)
	GameState.has_fairy_crown = true
	var prev_gold = GameState.gold
	wmap_node._trigger_object(shrine_obj)
	wmap_node.popup_btn1.emit_signal("pressed")
	assert(GameState.quest_completed, "Quest should now be completed!")
	assert(GameState.gold > prev_gold, "Player should have received reward gold")
	print("  -> Fairy Queen accepted Crown! Quest completed triumphantly!")
	
	wmap_node.queue_free()
	
	# 5. Test Battle Arena Scene & Animations
	print("[TEST] 5. Testing Battle Arena Scene & Combat Mechanisms...")
	var arena_packed = load("res://src/battle/battle_arena.tscn")
	var arena_node = arena_packed.instantiate()
	root.add_child(arena_node)
	
	assert(arena_node.all_stacks.size() >= 5, "Arena should have deployed player and enemy stacks")
	print("  -> Stacks deployed: %d stacks" % arena_node.all_stacks.size())
	
	# Test unit targeting distance helper
	var first_stack = arena_node.all_stacks[0]
	var pixel_pos = HexGrid.hex_to_pixel(first_stack.hex.x, first_stack.hex.y, arena_node.HEX_SIZE, arena_node.grid_origin)
	var found = arena_node._find_stack_at_position(pixel_pos)
	assert(found == first_stack, "Target helper should find stack at its position")
	print("  -> Unit click targeting verified at %s!" % pixel_pos)
	
	# Test Defeat Logic: pending_battle_id should NOT be marked defeated on loss
	GameState.pending_battle_id = "test_encounter"
	arena_node._show_victory(false)
	assert(not GameState.flags.get("test_encounter", false), "Encounter flag must NOT be true after defeat!")
	print("  -> Defeat preserves enemy on the map! Verified!")
	
	# Test Victory Logic: pending_battle_id IS marked defeated on win
	GameState.pending_battle_id = "test_encounter_2"
	arena_node._show_victory(true)
	assert(GameState.flags.get("test_encounter_2", false), "Encounter flag MUST be true after victory!")
	print("  -> Victory consumes encounter flag properly! Verified!")
	
	arena_node.queue_free()
	
	print("\n==========================================")
	print("   ALL 9 USER REQUIREMENTS VERIFIED OK!   ")
	print("==========================================")
	quit()
