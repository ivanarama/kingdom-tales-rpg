class_name BattleStack
extends RefCounted

const HexGrid = preload("res://src/battle/hex_grid.gd")
const UnitData = preload("res://src/core/unit_data.gd")

var unit_id: String
var data: Dictionary
var team: int # 0: Player, 1: Enemy
var hex: Vector2i
var count: int
var start_count: int # численность на начало боя — потолок воскрешения Исцелением
var current_hp: int

var has_retaliated: bool = false
var has_acted: bool = false
var has_waited: bool = false
var is_defending: bool = false
var hit_this_round: bool = false # получал урон в этом раунде (для «Стаи» волков)
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
var aura_attack: int = 0 # прибавка к атаке от знамени союзного вожака (BossMechanics.before_turn)

func setup(p_unit_id: String, p_count: int, p_team: int, p_hex: Vector2i) -> void:
	unit_id = p_unit_id
	data = UnitData.get_unit(unit_id)
	team = p_team
	count = p_count
	start_count = p_count
	hex = p_hex
	current_hp = data.get("max_hp", 20)
	had_morale_this_round = false
	has_waited = false
	hit_this_round = false
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
	hit_this_round = false
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
	att += aura_attack
	if team == 0:
		att += GameState.get_total_attack() if GameState.has_method("get_total_attack") else GameState.attack
	if target.team == 0:
		def += GameState.get_total_defense() if GameState.has_method("get_total_defense") else GameState.defense
		
	var mult: float = 1.0 + float(att - def) * 0.05
	mult = clampf(mult, 0.35, 2.5)
	
	# Secondary Skills Modifiers
	if team == 0:
		if is_melee:
			mult *= 1.0 + GameState.skill_bonus("offense")
		else:
			mult *= 1.0 + GameState.skill_bonus("archery")
		if GameState.has_skill("leadership") and randf() < 0.15:
			mult *= 1.30
	
	# Ranged melee penalty
	if is_melee and data.get("is_ranged", false):
		mult *= 0.5
	elif not is_melee and is_broken_arrow:
		mult *= 0.5
	mult *= ability_multiplier(target, is_melee)
		
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
	att += aura_attack
	if team == 0:
		att += GameState.get_total_attack() if GameState.has_method("get_total_attack") else GameState.attack
	if target.team == 0:
		def += GameState.get_total_defense() if GameState.has_method("get_total_defense") else GameState.defense
		
	var mult: float = 1.0 + float(att - def) * 0.05
	mult = clampf(mult, 0.35, 2.5)
	
	if team == 0:
		if is_melee:
			mult *= 1.0 + GameState.skill_bonus("offense")
		else:
			mult *= 1.0 + GameState.skill_bonus("archery")
	
	if is_melee and data.get("is_ranged", false):
		mult *= 0.5
	elif not is_melee and is_broken_arrow:
		mult *= 0.5
	mult *= ability_multiplier(target, is_melee)
		
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
	if actual_dmg > 0:
		hit_this_round = true
	
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

## Исцеление (PR #2): сначала лечит верхнего воина, затем поднимает павших,
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
	}

## Множитель урона от способностей: «Стая» волков (+25% по отряду, уже раненому
## в этом раунде), «Трусоватые» гоблины (−25%, потеряв больше половины отряда),
## «Кости» скелетов (−25% урона от выстрелов по ним).
func ability_multiplier(target: BattleStack, is_melee: bool) -> float:
	var m := 1.0
	if data.get("pack_hunter", false) and target.hit_this_round:
		m *= 1.25
	if data.get("cowardly", false) and count * 2 < start_count:
		m *= 0.75
	if not is_melee:
		m *= 1.0 - float(target.data.get("ranged_resist", 0.0))
	return m

## Штраф за дальность («сломанная стрела»): цель дальше 5 гексов.
## «Молния природы» друидов бьёт без штрафа.
func has_range_penalty(target_hex: Vector2i) -> bool:
	return HexGrid.distance(hex, target_hex) > 5 and not data.get("no_range_penalty", false)

## Ответит ли отряд на удар attacker: раз за раунд (с «Бесконечным отпором» — всегда),
## но не на «Стремительный налёт» Королевских Пегасов.
func will_retaliate(attacker: BattleStack) -> bool:
	return is_alive() and (not has_retaliated or data.get("unlimited_retaliation", false)) \
		and not attacker.data.get("no_retaliation", false)

func is_blocked_by_enemy(all_stacks: Array) -> bool:
	for s in all_stacks:
		if s is BattleStack and s.is_alive() and s.team != team and HexGrid.distance(hex, s.hex) == 1:
			return true
	return false
