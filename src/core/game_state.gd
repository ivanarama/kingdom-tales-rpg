extends Node

const ArtifactData = preload("res://src/core/artifact_data.gd")
const UnitData = preload("res://src/core/unit_data.gd")

signal state_changed
signal gold_changed(new_gold: int)
signal day_advanced(day: int)
signal level_up_pending(level_data: Dictionary)

# Hero RPG data
var hero_name: String = "Рыцарь Аларик"
var hero_title: String = "Паладин Королевства"
var hero_portrait: String = "res://assets/art/portraits/hero_alaric.jpg"
var hero_class_id: String = "paladin"
var battle_return_scene: String = "res://src/world/world_map.tscn"

# Demo Battle / Arena parameters
var is_demo_battle: bool = false
var demo_player_army: Array[Dictionary] = []
var demo_enemy_configs: Array[Dictionary] = []
var demo_difficulty: String = "normal"
var demo_difficulty_title: String = "🟡 Воитель (Нормально)"
var demo_encounter_title: String = "Случайная битва"

var current_chapter: int = 1

var level: int = 1
var xp: int = 0
var next_level_xp: int = 1000

var attack: int = 4
var defense: int = 3
var spellpower: int = 3
var knowledge: int = 4
var leadership: int = 350

var current_mana: int = 40
var max_mana: int = 40

var gold: int = 1500
var day: int = 1
var move_points: int = 36
var max_move_points: int = 36

# Secondary Skills: skill_id -> level (1: Базовый, 2: Продвинутый, 3: Эксперт)
var skills: Dictionary = {
	"leadership": 1 # Паладин начинает с базовым Лидерством
}

const ALL_SKILLS: Dictionary = {
	"archery": {
		"name": "Стрельба",
		"icon": "🏹",
		"desc": "Увеличивает урон всех стрелков в войске на 20%."
	},
	"offense": {
		"name": "Нападение",
		"icon": "⚔️",
		"desc": "Увеличивает урон отрядов в ближнем бою на 15%."
	},
	"logistics": {
		"name": "Логистика",
		"icon": "🐎",
		"desc": "Увеличивает запас очков хода на +8 каждый день."
	},
	"pathfinding": {
		"name": "Поиск пути",
		"icon": "🌿",
		"desc": "Снижает штраф за бездорожье: трава стоит 1 очко хода вместо 2."
	},
	"leadership": {
		"name": "Лидерство",
		"icon": "👑",
		"desc": "Повышает боевой дух: 15% шанс воодушевления отряда (+30% крит. урон в бою)."
	},
	"sorcery": {
		"name": "Волшебство",
		"icon": "✨",
		"desc": "Увеличивает урон всех атакующих заклинаний героя на 25%."
	},
	"mysticism": {
		"name": "Мистицизм",
		"icon": "💧",
		"desc": "Восстанавливает герою дополнительно +10 маны каждый новый день."
	}
}

var pending_level_ups: Array[Dictionary] = []

# Hero Artifacts & Equipment
# Slots: weapon, shield, armor, boots, accessory, relic
var equipped_artifacts: Dictionary = {
	"weapon": "sword_valiance"
}
var inventory_artifacts: Array[String] = [
	"shield_aegis",
	"boots_traveler"
]

func get_set_bonuses() -> Dictionary:
	return ArtifactData.get_active_set_bonuses(equipped_artifacts)

func get_total_attack() -> int:
	var total = attack
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("attack_bonus", 0)
	total += get_set_bonuses().get("attack", 0)
	return total

func get_total_defense() -> int:
	var total = defense
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("defense_bonus", 0)
	total += get_set_bonuses().get("defense", 0)
	return total

func get_total_spellpower() -> int:
	var total = spellpower
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("spellpower_bonus", 0)
	total += get_set_bonuses().get("spellpower", 0)
	return total

func get_total_knowledge() -> int:
	var total = knowledge
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("knowledge_bonus", 0)
	total += get_set_bonuses().get("knowledge", 0)
	return total

func get_total_max_mana() -> int:
	var total = 40 + (knowledge - 4) * 10
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("mana_bonus", 0)
		total += art.get("knowledge_bonus", 0) * 10
	var sb = get_set_bonuses()
	total += sb.get("mana", 0)
	total += sb.get("knowledge", 0) * 10
	return total

func get_total_max_mp() -> int:
	var total = 36 + (8 * get_skill_level("logistics"))
	for slot in equipped_artifacts.keys():
		var art = ArtifactData.get_artifact(equipped_artifacts[slot])
		total += art.get("mp_bonus", 0)
	total += get_set_bonuses().get("mp", 0)
	return total

func equip_artifact(art_id: String) -> bool:
	var art = ArtifactData.get_artifact(art_id)
	if art.is_empty():
		return false
	var slot = art.get("slot", "")
	if slot == "":
		return false
	# If already equipped in slot, move existing to inventory
	if equipped_artifacts.has(slot):
		inventory_artifacts.append(equipped_artifacts[slot])
	# Remove newly equipped from inventory
	var idx = inventory_artifacts.find(art_id)
	if idx != -1:
		inventory_artifacts.remove_at(idx)
	equipped_artifacts[slot] = art_id
	max_mana = get_total_max_mana()
	max_move_points = get_total_max_mp()
	state_changed.emit()
	return true

func unequip_artifact(slot: String) -> bool:
	if not equipped_artifacts.has(slot):
		return false
	var art_id = equipped_artifacts[slot]
	equipped_artifacts.erase(slot)
	inventory_artifacts.append(art_id)
	max_mana = get_total_max_mana()
	current_mana = mini(current_mana, max_mana)
	max_move_points = get_total_max_mp()
	move_points = mini(move_points, max_move_points)
	state_changed.emit()
	return true

func has_skill(skill_id: String) -> bool:
	return skills.has(skill_id)

func get_skill_level(skill_id: String) -> int:
	return skills.get(skill_id, 0)

func learn_skill(skill_id: String) -> void:
	if skills.has(skill_id):
		skills[skill_id] += 1
	else:
		skills[skill_id] = 1
	if skill_id == "logistics":
		max_move_points = get_total_max_mp()
		move_points = mini(max_move_points, move_points + 8)
	state_changed.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= next_level_xp:
		level += 1
		xp -= next_level_xp
		next_level_xp = int(next_level_xp * 1.5)
		
		# Paladin primary stat roll (HoMM3 style)
		var r = randf()
		var stat_name = ""
		if r < 0.35:
			attack += 1
			stat_name = "Атака (+1)"
		elif r < 0.70:
			defense += 1
			stat_name = "Защита (+1)"
		elif r < 0.85:
			spellpower += 1
			stat_name = "Сила Магии (+1)"
		else:
			knowledge += 1
			stat_name = "Знание (+1)"
			max_mana = get_total_max_mana()
			current_mana = max_mana
			
		# Pick 2 secondary skills to offer
		var options: Array[String] = []
		var pool: Array[String] = []
		for s in ALL_SKILLS.keys():
			if not skills.has(s) or skills[s] < 3:
				pool.append(s)
		pool.shuffle()
		if pool.size() > 0:
			options.append(pool[0])
		if pool.size() > 1:
			options.append(pool[1])
			
		var lvl_info = {
			"level": level,
			"stat": stat_name,
			"options": options
		}
		pending_level_ups.append(lvl_info)
		level_up_pending.emit(lvl_info)

# Army stacks (up to 5 slots)
var player_army: Array[Dictionary] = [
	{"unit_id": "griffin", "count": 6},
	{"unit_id": "fairy_archer", "count": 18}
]

var learned_spells: Array[String] = ["fireball", "heal", "bless", "haste", "scrying", "restoration", "lightning", "slow", "stoneskin", "blind"]

# World progress flags
var flags: Dictionary = {
	"watermill_visited": false,
	"magic_shrine_visited": false,
	"chest_opened": false,
	"fairy_dwelling_hired": false,
	"goblin_camp_defeated": false
}

# Current encounter data (when entering battle)
var pending_battle: Dictionary = {}

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	state_changed.emit()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		state_changed.emit()
		return true
	return false

func restore_mana() -> void:
	current_mana = get_total_max_mana()
	state_changed.emit()

func spend_mana(cost: int) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		state_changed.emit()
		return true
	return false

func add_units_to_army(unit_id: String, count: int) -> void:
	for slot in player_army:
		if slot["unit_id"] == unit_id:
			slot["count"] += count
			state_changed.emit()
			return
	if player_army.size() < 5:
		player_army.append({"unit_id": unit_id, "count": count})
		state_changed.emit()

func upgrade_army_unit(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= player_army.size():
		return false
	var slot = player_army[slot_idx]
	var udata = UnitData.get_unit(slot["unit_id"])
	var upgrade_id = udata.get("upgrade_to", "")
	if upgrade_id == "":
		return false
	var cost_per_unit = 15 if udata.tier <= 2 else 35
	var total_cost = cost_per_unit * slot["count"]
	if not spend_gold(total_cost):
		return false
	slot["unit_id"] = upgrade_id
	state_changed.emit()
	return true

# Quest items & state
var has_gate_key: bool = false
var has_fairy_crown: bool = false
var quest_forester_started: bool = false
var quest_completed: bool = false

# Pending battle identifier to consume on victory only
var pending_battle_id: String = ""

func split_stack(slot_idx: int, split_count: int) -> bool:
	if slot_idx < 0 or slot_idx >= player_army.size():
		return false
	var slot = player_army[slot_idx]
	if split_count <= 0 or split_count >= slot["count"]:
		return false
	if player_army.size() >= 5:
		return false
	slot["count"] -= split_count
	player_army.append({"unit_id": slot["unit_id"], "count": split_count})
	state_changed.emit()
	return true

func merge_stacks(slot_a: int, slot_b: int) -> bool:
	if slot_a == slot_b or slot_a >= player_army.size() or slot_b >= player_army.size():
		return false
	var a = player_army[slot_a]
	var b = player_army[slot_b]
	if a["unit_id"] == b["unit_id"]:
		a["count"] += b["count"]
		player_army.remove_at(slot_b)
		state_changed.emit()
		return true
	return false

func swap_army_slots(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= player_army.size() or slot_b < 0 or slot_b >= player_army.size():
		return false
	if slot_a == slot_b:
		return false
	var temp = player_army[slot_a]
	player_army[slot_a] = player_army[slot_b]
	player_army[slot_b] = temp
	state_changed.emit()
	return true


# Persistent World Map coordinates & fog
var hero_cell: Vector2i = Vector2i(4, 11)
var revealed_cells: Dictionary = {}

# Dwelling stocks (replenishes weekly)
var dwelling_stock: Dictionary = {
	"fairy_camp": 14
}
var last_astrologers_event: Dictionary = {}

func next_day() -> void:
	day += 1
	max_move_points = get_total_max_mp()
	move_points = max_move_points
	var mana_regen = 15 + (10 * get_skill_level("mysticism"))
	max_mana = get_total_max_mana()
	current_mana = mini(max_mana, current_mana + mana_regen)
	if day % 7 == 1:
		flags["watermill"] = false
		dwelling_stock["fairy_camp"] = dwelling_stock.get("fairy_camp", 0) + 14
		dwelling_stock["druid_camp"] = dwelling_stock.get("druid_camp", 0) + 8
		dwelling_stock["griffin_nest"] = dwelling_stock.get("griffin_nest", 0) + 6
		
		# Astrologers proclaim... (Weekly events on day 8, 15, 22...)
		if day > 1:
			var events = [
				{
					"id": "week_of_fairies",
					"name": "Неделя Фей",
					"description": "Астрологи объявляют Неделю Фей!\n\nПрирост лесных лучниц удвоен. 10 фей-лучниц безвозмездно присоединяются к вашей армии!"
				},
				{
					"id": "week_of_gold",
					"name": "Неделя Золота",
					"description": "Астрологи объявляют Неделю Золота!\n\nТорговые пути безопасны, и королевская казна пополняется на +1000 золота!"
				},
				{
					"id": "week_of_magic",
					"name": "Неделя Магии",
					"description": "Астрологи объявляют Неделю Магии!\n\nЭфирные потоки насыщают разум героя. Запас маны полностью восстановлен, а предел маны увеличен на +20!"
				},
				{
					"id": "week_of_valor",
					"name": "Неделя Воинской Доблести",
					"description": "Астрологи объявляют Неделю Воинской Доблести!\n\nВсе отряды королевства вдохновлены боевым духом (+2 к Атаке героя)!"
				}
			]
			var ev_idx = ((day / 7) - 1) % events.size()
			var ev = events[ev_idx]
			match ev.id:
				"week_of_fairies":
					add_units_to_army("fairy_archer", 10)
					dwelling_stock["fairy_camp"] = dwelling_stock.get("fairy_camp", 0) + 14
				"week_of_gold":
					add_gold(1000)
				"week_of_magic":
					max_mana = get_total_max_mana() + 20
					current_mana = max_mana
				"week_of_valor":
					attack += 2
			last_astrologers_event = ev
		else:
			last_astrologers_event.clear()
	else:
		last_astrologers_event.clear()
	day_advanced.emit(day)
	state_changed.emit()
	save_game()

func start_chapter(chapter_num: int) -> void:
	current_chapter = chapter_num
	day = 1
	max_move_points = get_total_max_mp()
	move_points = max_move_points
	max_mana = get_total_max_mana()
	current_mana = max_mana
	
	revealed_cells.clear()
	flags.clear()
	pending_battle.clear()
	pending_battle_id = ""
	has_gate_key = false
	has_fairy_crown = false
	quest_forester_started = false
	quest_completed = false
	dwelling_stock.clear()
	
	match chapter_num:
		1:
			hero_cell = Vector2i(4, 11)
			dwelling_stock["fairy_camp"] = 14
		2:
			hero_cell = Vector2i(3, 11)
			dwelling_stock["druid_camp"] = 8
		3:
			hero_cell = Vector2i(4, 16)
			dwelling_stock["griffin_nest"] = 6
		_:
			hero_cell = Vector2i(4, 11)
			dwelling_stock["fairy_camp"] = 14
			
	state_changed.emit()
	save_game()

func set_hero_class(class_id: String) -> void:
	hero_class_id = class_id
	match class_id:
		"archmage":
			hero_name = "Чародейка Элеонора"
			hero_title = "Верховный Архимаг"
			hero_portrait = "res://assets/art/portraits/hero_archmage.jpg"
			attack = 2
			defense = 2
			spellpower = 6
			knowledge = 6
			leadership = 250
			skills = {
				"sorcery": 1,
				"mysticism": 1
			}
			equipped_artifacts = {
				"accessory": "ring_arcana"
			}
			inventory_artifacts = [
				"crown_fairy"
			]
			player_army = [
				{"unit_id": "griffin", "count": 4},
				{"unit_id": "fairy_archer", "count": 24}
			]
			learned_spells = ["fireball", "lightning", "slow", "bless", "heal", "scrying", "restoration", "haste", "stoneskin", "blind"]
		"ranger":
			hero_name = "Следопыт Торн"
			hero_title = "Хранитель Чащобы"
			hero_portrait = "res://assets/art/portraits/hero_ranger.jpg"
			attack = 3
			defense = 3
			spellpower = 2
			knowledge = 3
			leadership = 300
			skills = {
				"logistics": 1,
				"pathfinding": 1,
				"archery": 1
			}
			equipped_artifacts = {
				"boots": "boots_traveler",
				"weapon": "sword_valiance"
			}
			inventory_artifacts = [
				"shield_aegis"
			]
			player_army = [
				{"unit_id": "griffin", "count": 8},
				{"unit_id": "fairy_archer", "count": 14}
			]
			learned_spells = ["heal", "haste", "slow", "bless", "scrying", "restoration", "fireball", "lightning", "stoneskin", "blind"]
		_:
			hero_class_id = "paladin"
			hero_name = "Рыцарь Аларик"
			hero_title = "Паладин Королевства"
			hero_portrait = "res://assets/art/portraits/hero_alaric.jpg"
			attack = 4
			defense = 3
			spellpower = 3
			knowledge = 4
			leadership = 350
			skills = {
				"leadership": 1
			}
			equipped_artifacts = {
				"weapon": "sword_valiance"
			}
			inventory_artifacts = [
				"shield_aegis",
				"boots_traveler"
			]
			player_army = [
				{"unit_id": "griffin", "count": 6},
				{"unit_id": "fairy_archer", "count": 18}
			]
			learned_spells = ["fireball", "heal", "bless", "haste", "scrying", "restoration", "lightning", "slow", "stoneskin", "blind"]
			
	max_mana = get_total_max_mana()
	current_mana = max_mana
	max_move_points = get_total_max_mp()
	move_points = max_move_points
	state_changed.emit()

func reset() -> void:
	hero_class_id = "paladin"
	hero_name = "Рыцарь Аларик"
	hero_title = "Паладин Королевства"
	hero_portrait = "res://assets/art/portraits/hero_alaric.jpg"
	current_chapter = 1
	level = 1
	xp = 0
	next_level_xp = 1000
	attack = 4
	defense = 3
	spellpower = 3
	knowledge = 4
	leadership = 350
	gold = 1500
	day = 1
	skills = {
		"leadership": 1
	}
	equipped_artifacts = {
		"weapon": "sword_valiance"
	}
	inventory_artifacts = [
		"shield_aegis",
		"boots_traveler"
	]
	max_mana = get_total_max_mana()
	current_mana = max_mana
	max_move_points = get_total_max_mp()
	move_points = max_move_points
	pending_level_ups.clear()
	player_army = [
		{"unit_id": "griffin", "count": 6},
		{"unit_id": "fairy_archer", "count": 18}
	]
	learned_spells = ["fireball", "heal", "bless", "haste", "scrying", "restoration", "lightning", "slow", "stoneskin", "blind"]
	flags = {
		"watermill_visited": false,
		"magic_shrine_visited": false,
		"chest_opened": false,
		"fairy_dwelling_hired": false,
		"goblin_camp_defeated": false
	}
	pending_battle = {}
	pending_battle_id = ""
	is_demo_battle = false
	demo_player_army.clear()
	demo_enemy_configs.clear()
	has_gate_key = false
	has_fairy_crown = false
	quest_forester_started = false
	quest_completed = false
	hero_cell = Vector2i(4, 11)
	revealed_cells = {}
	dwelling_stock = {"fairy_camp": 14}
	state_changed.emit()

const SAVE_PATH := "user://savegame.json"

func has_save_game(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

func get_save_summary(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var d = json.data
	return {
		"hero_name": d.get("hero_name", "Рыцарь Аларик"),
		"hero_title": d.get("hero_title", "Паладин Королевства"),
		"chapter": d.get("current_chapter", 1),
		"day": d.get("day", 1),
		"gold": d.get("gold", 0),
		"level": d.get("level", 1)
	}

func save_game(path: String = SAVE_PATH) -> bool:
	var rev_arr = []
	for c in revealed_cells.keys():
		rev_arr.append([c.x, c.y])
	
	var data = {
		"version": 1,
		"hero_class_id": hero_class_id,
		"hero_name": hero_name,
		"hero_title": hero_title,
		"hero_portrait": hero_portrait,
		"current_chapter": current_chapter,
		"level": level,
		"xp": xp,
		"next_level_xp": next_level_xp,
		"attack": attack,
		"defense": defense,
		"spellpower": spellpower,
		"knowledge": knowledge,
		"leadership": leadership,
		"current_mana": current_mana,
		"max_mana": max_mana,
		"gold": gold,
		"day": day,
		"move_points": move_points,
		"max_move_points": max_move_points,
		"skills": skills,
		"equipped_artifacts": equipped_artifacts,
		"inventory_artifacts": inventory_artifacts,
		"player_army": player_army,
		"learned_spells": learned_spells,
		"flags": flags,
		"has_gate_key": has_gate_key,
		"has_fairy_crown": has_fairy_crown,
		"quest_forester_started": quest_forester_started,
		"quest_completed": quest_completed,
		"hero_cell": [hero_cell.x, hero_cell.y],
		"revealed_cells": rev_arr,
		"dwelling_stock": dwelling_stock
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false
		
	hero_class_id = data.get("hero_class_id", "paladin")
	hero_name = data.get("hero_name", hero_name)
	hero_title = data.get("hero_title", hero_title)
	hero_portrait = data.get("hero_portrait", hero_portrait)
	current_chapter = int(data.get("current_chapter", current_chapter))
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	next_level_xp = int(data.get("next_level_xp", next_level_xp))
	attack = int(data.get("attack", attack))
	defense = int(data.get("defense", defense))
	spellpower = int(data.get("spellpower", spellpower))
	knowledge = int(data.get("knowledge", knowledge))
	leadership = int(data.get("leadership", leadership))
	current_mana = int(data.get("current_mana", current_mana))
	max_mana = int(data.get("max_mana", max_mana))
	gold = int(data.get("gold", gold))
	day = int(data.get("day", day))
	move_points = int(data.get("move_points", move_points))
	max_move_points = int(data.get("max_move_points", max_move_points))
	
	skills = data.get("skills", skills)
	
	equipped_artifacts = data.get("equipped_artifacts", equipped_artifacts)
	inventory_artifacts = Array(data.get("inventory_artifacts", inventory_artifacts), TYPE_STRING, &"", null)
	
	var raw_army = data.get("player_army", [])
	player_army.clear()
	for slot in raw_army:
		player_army.append({"unit_id": str(slot.get("unit_id", "")), "count": int(slot.get("count", 1))})
		
	var raw_spells = data.get("learned_spells", [])
	learned_spells = Array(raw_spells, TYPE_STRING, &"", null)
	
	flags = data.get("flags", flags)
	has_gate_key = data.get("has_gate_key", false)
	has_fairy_crown = data.get("has_fairy_crown", false)
	quest_forester_started = data.get("quest_forester_started", false)
	quest_completed = data.get("quest_completed", false)
	
	var hc = data.get("hero_cell", [4, 11])
	if hc is Array and hc.size() >= 2:
		hero_cell = Vector2i(int(hc[0]), int(hc[1]))
		
	revealed_cells.clear()
	var rev_arr = data.get("revealed_cells", [])
	if rev_arr is Array:
		for item in rev_arr:
			if item is Array and item.size() >= 2:
				revealed_cells[Vector2i(int(item[0]), int(item[1]))] = true
				
	dwelling_stock = data.get("dwelling_stock", dwelling_stock)
	
	state_changed.emit()
	return true

func get_difficulty_multipliers(diff: String) -> Dictionary:
	match diff:
		"easy":
			return {"player": 1.35, "enemy": 0.65, "title": "🟢 Новобранец (Легко)"}
		"hard":
			return {"player": 0.90, "enemy": 1.45, "title": "🔴 Герой (Сложно)"}
		"legendary":
			return {"player": 0.80, "enemy": 2.20, "title": "💀 Легенда (Кошмар)"}
		_:
			return {"player": 1.00, "enemy": 1.00, "title": "🟡 Воитель (Нормально)"}

func get_demo_player_preset_army(preset: String, diff: String = "normal") -> Array[Dictionary]:
	var mult: float = get_difficulty_multipliers(diff)["player"]
	var result: Array[Dictionary] = []
	match preset:
		"balanced":
			result = [
				{"unit_id": "royal_griffin", "count": maxi(1, int(round(8 * mult)))},
				{"unit_id": "royal_fairy", "count": maxi(1, int(round(20 * mult)))},
				{"unit_id": "treant", "count": maxi(1, int(round(4 * mult)))}
			]
		"shooters":
			result = [
				{"unit_id": "royal_fairy", "count": maxi(1, int(round(26 * mult)))},
				{"unit_id": "druid", "count": maxi(1, int(round(12 * mult)))},
				{"unit_id": "griffin", "count": maxi(1, int(round(6 * mult)))}
			]
		"flyers":
			result = [
				{"unit_id": "royal_griffin", "count": maxi(1, int(round(12 * mult)))},
				{"unit_id": "griffin", "count": maxi(1, int(round(10 * mult)))},
				{"unit_id": "fairy_archer", "count": maxi(1, int(round(18 * mult)))}
			]
		"druids":
			result = [
				{"unit_id": "druid", "count": maxi(1, int(round(14 * mult)))},
				{"unit_id": "treant", "count": maxi(1, int(round(5 * mult)))},
				{"unit_id": "royal_fairy", "count": maxi(1, int(round(18 * mult)))}
			]
		_: # random
			var pool = ["royal_griffin", "griffin", "royal_fairy", "fairy_archer", "treant", "druid"]
			pool.shuffle()
			var picked = [pool[0], pool[1], pool[2]]
			var base_counts = {
				"royal_griffin": 8, "griffin": 12, "royal_fairy": 22,
				"fairy_archer": 28, "treant": 4, "druid": 12
			}
			for u in picked:
				var c = maxi(1, int(round(base_counts.get(u, 10) * mult)))
				result.append({"unit_id": u, "count": c})
	return result

func get_demo_enemy_preset_army(preset: String, diff: String = "normal") -> Array[Dictionary]:
	var mult: float = get_difficulty_multipliers(diff)["enemy"]
	var result: Array[Dictionary] = []
	var hexes = [Vector2i(10, 1), Vector2i(10, 3), Vector2i(10, 5), Vector2i(10, 2), Vector2i(10, 4)]
	match preset:
		"forest_bandits":
			result = [
				{"unit_id": "goblin", "count": maxi(1, int(round(22 * mult))), "hex": hexes[0]},
				{"unit_id": "wolf", "count": maxi(1, int(round(12 * mult))), "hex": hexes[1]},
				{"unit_id": "treant", "count": maxi(1, int(round(3 * mult))), "hex": hexes[2]}
			]
		"swamp_undead":
			result = [
				{"unit_id": "skeleton_archer", "count": maxi(1, int(round(24 * mult))), "hex": hexes[0]},
				{"unit_id": "swamp_zombie", "count": maxi(1, int(round(16 * mult))), "hex": hexes[1]},
				{"unit_id": "lich", "count": maxi(1, int(round(4 * mult))), "hex": hexes[2]}
			]
		"dragon_cult":
			var d_count = 1
			if diff == "hard":
				d_count = 2
			elif diff == "legendary":
				d_count = 4
			result = [
				{"unit_id": "wolf", "count": maxi(1, int(round(18 * mult))), "hex": hexes[0]},
				{"unit_id": "red_dragon", "count": d_count, "hex": hexes[1]},
				{"unit_id": "goblin", "count": maxi(1, int(round(25 * mult))), "hex": hexes[2]}
			]
		"rebel_guard":
			result = [
				{"unit_id": "griffin", "count": maxi(1, int(round(10 * mult))), "hex": hexes[0]},
				{"unit_id": "druid", "count": maxi(1, int(round(10 * mult))), "hex": hexes[1]},
				{"unit_id": "fairy_archer", "count": maxi(1, int(round(22 * mult))), "hex": hexes[2]}
			]
		_: # random
			var enemy_units = [
				{"id": "goblin", "base": 24},
				{"id": "wolf", "base": 14},
				{"id": "skeleton_archer", "base": 20},
				{"id": "swamp_zombie", "base": 16},
				{"id": "treant", "base": 4},
				{"id": "druid", "base": 10},
				{"id": "griffin", "base": 9},
				{"id": "lich", "base": 5}
			]
			if diff in ["hard", "legendary"]:
				enemy_units.append({"id": "red_dragon", "base": 2})
			enemy_units.shuffle()
			for i in range(3):
				var item = enemy_units[i]
				var c = maxi(1, int(round(item["base"] * mult)))
				result.append({"unit_id": item["id"], "count": c, "hex": hexes[i]})
	return result

func setup_demo_battle(difficulty: String, player_preset: String, enemy_preset: String) -> void:
	is_demo_battle = true
	demo_difficulty = difficulty
	var diff_data = get_difficulty_multipliers(difficulty)
	demo_difficulty_title = diff_data["title"]
	
	demo_player_army = get_demo_player_preset_army(player_preset, difficulty)
	demo_enemy_configs = get_demo_enemy_preset_army(enemy_preset, difficulty)
	
	match enemy_preset:
		"forest_bandits":
			demo_encounter_title = "Лесные Разбойники"
		"swamp_undead":
			demo_encounter_title = "Болотная Нежить"
		"dragon_cult":
			demo_encounter_title = "Культ Дракона"
		"rebel_guard":
			demo_encounter_title = "Мятежная Гвардия"
		_:
			demo_encounter_title = "Случайный Отряд Врага"
	
	battle_return_scene = "res://src/main.tscn"


