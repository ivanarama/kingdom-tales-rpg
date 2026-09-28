class_name BattleStack
extends RefCounted

const HexGrid = preload("res://src/battle/hex_grid.gd")
const UnitData = preload("res://src/core/unit_data.gd")

var unit_id: String
var data: Dictionary
var team: int # 0: Player, 1: Enemy
var hex: Vector2i
var count: int
var current_hp: int

var has_retaliated: bool = false
var has_acted: bool = false
var has_waited: bool = false
var is_defending: bool = false
var had_morale_this_round: bool = false
var init_bonus: int = 0 # Рог Доблести и прочие боевые бонусы на весь бой

var buff_bless_turns: int = 0
var buff_haste_turns: int = 0
var buff_slow_turns: int = 0
var buff_stoneskin_turns: int = 0
var buff_shield_turns: int = 0
var buff_retribution_turns: int = 0
var buff_inspiration_turns: int = 0
var debuff_blind_turns: int = 0
var debuff_disease_turns: int = 0
var debuff_entangle_turns: int = 0
var shield_hp: int = 0 # поглощённый Щитом Света урон

func setup(p_unit_id: String, p_count: int, p_team: int, p_hex: Vector2i) -> void:
	unit_id = p_unit_id
	data = UnitData.get_unit(unit_id)
	team = p_team
	count = p_count
	hex = p_hex
	current_hp = data.get("max_hp", 20)
	had_morale_this_round = false
	has_waited = false
	init_bonus = 0
	buff_bless_turns = 0
	buff_haste_turns = 0
	buff_slow_turns = 0
	buff_stoneskin_turns = 0
	buff_shield_turns = 0
	buff_retribution_turns = 0
	buff_inspiration_turns = 0
	shield_hp = 0
	debuff_blind_turns = 0
	debuff_disease_turns = 0
	debuff_entangle_turns = 0

func is_alive() -> bool:
	return count > 0

func reset_round() -> void:
	has_retaliated = false
	has_acted = false
	has_waited = false
	is_defending = false
	had_morale_this_round = false
	if buff_bless_turns > 0:
		buff_bless_turns -= 1
	if buff_haste_turns > 0:
		buff_haste_turns -= 1
	if buff_slow_turns > 0:
		buff_slow_turns -= 1
	if buff_stoneskin_turns > 0:
		buff_stoneskin_turns -= 1
	if buff_shield_turns > 0:
		buff_shield_turns -= 1
		if buff_shield_turns == 0:
			shield_hp = 0
	if buff_retribution_turns > 0:
		buff_retribution_turns -= 1
	if buff_inspiration_turns > 0:
		buff_inspiration_turns -= 1
	if debuff_blind_turns > 0:
		debuff_blind_turns -= 1
	if debuff_disease_turns > 0:
		debuff_disease_turns -= 1
	if debuff_entangle_turns > 0:
		debuff_entangle_turns -= 1
		
	# Creature passive regeneration (e.g. Treants)
	var regen: int = data.get("regeneration", 0)
	if regen > 0 and count > 0:
		heal(regen)

func get_initiative() -> int:
	return data.get("initiative", 10) + init_bonus

func get_speed() -> int:
	if debuff_blind_turns > 0 or debuff_entangle_turns > 0:
		return 0
	var spd: int = data.get("speed", 4)
	if buff_haste_turns > 0:
		spd += 3
	if buff_slow_turns > 0:
		spd = maxi(1, int(spd * 0.5))
	return spd

func get_defense() -> int:
	var def: int = data.get("defense", 4)
	if buff_stoneskin_turns > 0:
		def += 5
	if is_defending:
		def = int(def * 1.3) + 2
	return def

func calculate_attack_damage(target: BattleStack, is_melee: bool, is_broken_arrow: bool = false) -> int:
	var min_d: int = data.get("min_dmg", 3)
	var max_d: int = data.get("max_dmg", 6)
	
	var base_dmg := 0
	if buff_bless_turns > 0:
		base_dmg = count * max_d
	else:
		for i in range(count):
			base_dmg += randi_range(min_d, max_d)
			
	# Defense calculation
	var def := target.get_defense()
	var att: int = data.get("attack", 4)
	if debuff_disease_turns > 0:
		att = maxi(1, int(att * 0.75))
	if team == 0:
		att += GameState.get_total_attack() if GameState.has_method("get_total_attack") else GameState.attack
	if target.team == 0:
		def += GameState.get_total_defense() if GameState.has_method("get_total_defense") else GameState.defense
		
	var mult: float = 1.0 + float(att - def) * 0.05
	mult = clampf(mult, 0.35, 2.5)
	
	# Secondary Skills Modifiers
	if team == 0:
		if is_melee and GameState.has_skill("offense"):
			mult *= 1.15
		elif not is_melee and GameState.has_skill("archery"):
			mult *= 1.20
		if GameState.has_skill("leadership") and randf() < 0.15:
			mult *= 1.30
	
	# Ranged melee penalty
	if is_melee and data.get("is_ranged", false):
		mult *= 0.5
	elif not is_melee and is_broken_arrow:
		mult *= 0.5
		
	var final_dmg := int(base_dmg * mult)
	return maxi(1, final_dmg)

func get_damage_range(target: BattleStack, is_melee: bool, is_broken_arrow: bool = false) -> Dictionary:
	var min_d: int = data.get("min_dmg", 3)
	var max_d: int = data.get("max_dmg", 6)
	
	var base_min = count * min_d
	var base_max = count * max_d
	if buff_bless_turns > 0:
		base_min = base_max
		
	var def := target.get_defense()
	var att: int = data.get("attack", 4)
	if debuff_disease_turns > 0:
		att = maxi(1, int(att * 0.75))
	if team == 0:
		att += GameState.get_total_attack() if GameState.has_method("get_total_attack") else GameState.attack
	if target.team == 0:
		def += GameState.get_total_defense() if GameState.has_method("get_total_defense") else GameState.defense
		
	var mult: float = 1.0 + float(att - def) * 0.05
	mult = clampf(mult, 0.35, 2.5)
	
	if team == 0:
		if is_melee and GameState.has_skill("offense"):
			mult *= 1.15
		elif not is_melee and GameState.has_skill("archery"):
			mult *= 1.20
	
	if is_melee and data.get("is_ranged", false):
		mult *= 0.5
	elif not is_melee and is_broken_arrow:
		mult *= 0.5
		
	var dmg_min = maxi(1, int(base_min * mult))
	var dmg_max = maxi(1, int(base_max * mult))
	
	var max_hp = target.data.get("max_hp", 20)
	var total_pool = (target.count - 1) * max_hp + target.current_hp
	
	var rem_min = maxi(0, total_pool - dmg_max)
	var rem_count_min = int(ceil(float(rem_min) / float(max_hp))) if rem_min > 0 else 0
	var cas_max = target.count - rem_count_min
	
	var rem_max = maxi(0, total_pool - dmg_min)
	var rem_count_max = int(ceil(float(rem_max) / float(max_hp))) if rem_max > 0 else 0
	var cas_min_actual = target.count - rem_count_max
	
	return {
		"min_dmg": dmg_min,
		"max_dmg": dmg_max,
		"min_cas": cas_min_actual,
		"max_cas": cas_max,
		"is_broken_arrow": is_broken_arrow
	}

func take_damage(damage: int) -> Dictionary:
	var was_blind = (debuff_blind_turns > 0)
	if debuff_blind_turns > 0:
		debuff_blind_turns = 0 # Damage dispels blind!
	
	# Щит Света поглощает урон до здоровья отряда
	var absorbed := 0
	if shield_hp > 0 and damage > 0:
		absorbed = mini(shield_hp, damage)
		shield_hp -= absorbed
		damage -= absorbed
	
	var max_hp: int = data.get("max_hp", 20)
	var total_pool := (count - 1) * max_hp + current_hp
	var actual_dmg := mini(damage, total_pool)
	
	var remaining_pool := total_pool - actual_dmg
	var old_count := count
	
	if remaining_pool <= 0:
		count = 0
		current_hp = 0
	else:
		count = int(ceil(float(remaining_pool) / float(max_hp)))
		current_hp = remaining_pool % max_hp
		if current_hp == 0:
			current_hp = max_hp
			
	var casualties := old_count - count
	return {
		"damage": actual_dmg,
		"casualties": casualties,
		"is_dead": count <= 0,
		"dispelled_blind": was_blind,
		"absorbed": absorbed
	}

func is_blinded() -> bool:
	return debuff_blind_turns > 0

func is_diseased() -> bool:
	return debuff_disease_turns > 0

func is_entangled() -> bool:
	return debuff_entangle_turns > 0

func has_stoneskin() -> bool:
	return buff_stoneskin_turns > 0

func heal(amount: int) -> Dictionary:
	var max_hp: int = data.get("max_hp", 20)
	var missing_hp := max_hp - current_hp
	current_hp = mini(max_hp, current_hp + amount)
	return {
		"healed": amount,
		"current_hp": current_hp
	}

func is_blocked_by_enemy(all_stacks: Array) -> bool:
	for s in all_stacks:
		if s is BattleStack and s.is_alive() and s.team != team and HexGrid.distance(hex, s.hex) == 1:
			return true
	return false
