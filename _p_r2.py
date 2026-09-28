# -*- coding: utf-8 -*-
# 0.3.3 ч.2: боевой остаток из PR #2/#3.
import io


def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, "count=%d in %s for %r" % (s.count(old), path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print(path, 'patched OK')


# ============ battle_stack.gd: start_count + Исцеление с подъёмом павших ============
patch('src/battle/battle_stack.gd', [
    ('''var unit_id: String
var data: Dictionary
var team: int # 0: Player, 1: Enemy
var hex: Vector2i
var count: int
var current_hp: int''',
     '''var unit_id: String
var data: Dictionary
var team: int # 0: Player, 1: Enemy
var hex: Vector2i
var count: int
var start_count: int # численность на начало боя — потолок воскрешения Исцелением
var current_hp: int'''),
    ('''	count = p_count
	hex = p_hex
	current_hp = data.get("max_hp", 20)''',
     '''	count = p_count
	start_count = p_count
	hex = p_hex
	current_hp = data.get("max_hp", 20)'''),
    ('''func heal(amount: int) -> Dictionary:
	var max_hp: int = data.get("max_hp", 20)
	var missing_hp := max_hp - current_hp
	current_hp = mini(max_hp, current_hp + amount)
	return {
		"healed": amount,
		"current_hp": current_hp
	}''',
     '''## Исцеление (PR #2): сначала лечит верхнего воина, затем поднимает павших,
## но не выше численности отряда на начало боя. Возвращает реально восстановленное.
func heal(amount: int) -> Dictionary:
	var max_hp: int = data.get("max_hp", 20)
	var restored := 0
	if current_hp < max_hp and amount > 0:
		var put: int = mini(max_hp - current_hp, amount)
		current_hp += put
		amount -= put
		restored += put
	while amount >= max_hp and count < start_count:
		count += 1
		amount -= max_hp
		restored += max_hp
	return {
		"healed": restored,
		"current_hp": current_hp
	}'''),
])

# ============ battle_arena.gd ============
patch('src/battle/battle_arena.gd', [
    # 1. Снимок армии на начало боя
    ('''	var diff := GameState.get_difficulty_multipliers(GameState.campaign_difficulty)
	for i in range(min(player_army.size(), player_hexes.size())):''',
     '''	army_start_snapshot.clear()
	for item in player_army:
		if item["count"] > 0:
			army_start_snapshot.append({"unit_id": str(item["unit_id"]), "count": int(item["count"])})
	var diff := GameState.get_difficulty_multipliers(GameState.campaign_difficulty)
	for i in range(min(player_army.size(), player_hexes.size())):'''),
    # 2. Переменная снимка
    ('''var enemy_spell_charges: int = 0 # сколько раз Лич может колдовать за бой''',
     '''var enemy_spell_charges: int = 0 # сколько раз Лич может колдовать за бой
var army_start_snapshot: Array[Dictionary] = [] # численность на начало боя (для fallen_units)'''),
    # 3. Учёт павших при победе (до синка армии)
    ('''		# Save that enemy on the map is defeated
		if GameState.pending_battle_id != "":''',
     '''		# Павшие в победном бою попадают в Летопись павших — их вернёт «Благодать»
		for snap in army_start_snapshot:
			var surviving := 0
			for st in all_stacks:
				if st.team == 0 and st.unit_id == str(snap["unit_id"]):
					surviving += st.count
			var fallen: int = maxi(0, int(snap["count"]) - surviving)
			if fallen > 0:
				GameState.add_fallen_units(str(snap["unit_id"]), fallen)

		# Save that enemy on the map is defeated
		if GameState.pending_battle_id != "":'''),
    # 4. Исцеление: показывает реально восстановленное
    ('''			var heal_amount = 60 + cur_sp * 16
			target_stack.heal(heal_amount)
			_spawn_floating_text(target_stack.hex, tr("+%d HP") % heal_amount, Color(0.3, 1.0, 0.4))
			log_combat(tr("Исцеление: отряд %s восстанавливает %d ед. здоровья!") % [
				tr(target_stack.data.name), heal_amount
			])''',
     '''			var heal_amount = 60 + cur_sp * 16
			var heal_res: Dictionary = target_stack.heal(heal_amount)
			var healed: int = int(heal_res["healed"])
			_spawn_floating_text(target_stack.hex, tr("+%d HP") % healed, Color(0.3, 1.0, 0.4))
			log_combat(tr("Исцеление: отряд %s восстанавливает %d ед. здоровья!") % [
				tr(target_stack.data.name), healed
			])'''),
    # 5. Продление дебаффов, если цель уже походила (PR #2)
    ('''				if defender.has_acted:
					pass''',
     '''				if defender.has_acted:
					pass''') if False else (
    '''			if attacker.data.get("disease", false) or attacker.unit_id == "swamp_zombie":
				defender.debuff_disease_turns = 2''',
     '''			if attacker.data.get("disease", false) or attacker.unit_id == "swamp_zombie":
				defender.debuff_disease_turns = 2
				if defender.has_acted:
					defender.debuff_disease_turns += 1 # цель походила: эффект продлевается'''),
    ('''			elif (attacker.data.get("entangle", false) or attacker.unit_id == "treant") and randf() < 0.35:
				defender.debuff_entangle_turns = 1''',
     '''			elif (attacker.data.get("entangle", false) or attacker.unit_id == "treant") and randf() < 0.35:
				defender.debuff_entangle_turns = 1
				if defender.has_acted:
					defender.debuff_entangle_turns += 1 # цель походила: эффект продлевается'''),
    # 6. Одноразовая точка возврата (PR #2)
    ('''	var is_demo = GameState.is_demo_battle
	var target = GameState.battle_return_scene if GameState.battle_return_scene != "" else "res://src/world/world_map.tscn"''',
     '''	var is_demo = GameState.is_demo_battle
	var target = GameState.battle_return_scene if GameState.battle_return_scene != "" else "res://src/world/world_map.tscn"
	GameState.battle_return_scene = "" # точка возврата одноразовая (PR #2)'''),
    # 7. Сторона ближней атаки по точке тапа (PR #3)
    ('''func _handle_player_attack(target: BattleStack) -> void:''',
     '''func _handle_player_attack(target: BattleStack, tap_pos: Vector2 = Vector2.INF) -> void:'''),
    ('''		if HexGrid.distance(current_actor.hex, target.hex) > 1:
			for r_hex in reachable_hexes:
				if HexGrid.distance(r_hex, target.hex) == 1:
					current_actor.hex = r_hex
					break''',
     '''		if HexGrid.distance(current_actor.hex, target.hex) > 1:
			# Встаём с той стороны цели, куда тапнули; при равенстве — ближе к себе (PR #3)
			var best_hex := Vector2i(-99, -99)
			var best_score := 999999.0
			for r_hex in reachable_hexes:
				if HexGrid.distance(r_hex, target.hex) != 1:
					continue
				var mid: Vector2 = (HexGrid.hex_to_pixel(r_hex.x, r_hex.y, HEX_SIZE, grid_origin)
					+ HexGrid.hex_to_pixel(target.hex.x, target.hex.y, HEX_SIZE, grid_origin)) * 0.5
				var score: float = mid.distance_to(tap_pos) if tap_pos != Vector2.INF else float(HexGrid.distance(r_hex, current_actor.hex))
				if score < best_score:
					best_score = score
					best_hex = r_hex
			if best_hex != Vector2i(-99, -99):
				current_actor.hex = best_hex'''),
    # 8. Передаём точку тапа в обработчик атаки
    ('''					if attackable_targets.has(clicked_stack):
						if DisplayServer.is_touchscreen_available() and pending_attack_target != clicked_stack:''',
     '''					if attackable_targets.has(clicked_stack):
						if DisplayServer.is_touchscreen_available() and pending_attack_target != clicked_stack:'''),
    ('''						pending_attack_target = null
						_handle_player_attack(clicked_stack)
						return''',
     '''						pending_attack_target = null
						_handle_player_attack(clicked_stack, event.position)
						return'''),
])

# ============ Книга магии: подписи под иконками ============
patch('src/battle/battle_arena.gd', [
    ('''		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(sdata.icon_path):
			btn.texture_normal = load(sdata.icon_path)
		btn.tooltip_text = "%s (%d маны)\\n%s" % [sdata.name, sdata.mana_cost, sdata.description]
		btn.pressed.connect(func(): _on_spell_selected(spell_id))
		container.add_child(btn)''',
     '''		# Иконка с подписью (PR #3): на телефоне подсказок нет
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(sdata.icon_path):
			btn.texture_normal = load(sdata.icon_path)
		btn.tooltip_text = "%s (%d маны)\\n%s" % [sdata.name, sdata.mana_cost, sdata.description]
		btn.pressed.connect(func(): _on_spell_selected(spell_id))
		cell.add_child(btn)
		var lbl = Label.new()
		lbl.text = tr(str(sdata.name))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		lbl.custom_minimum_size = Vector2(76, 0)
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(lbl)
		container.add_child(cell)'''),
])
