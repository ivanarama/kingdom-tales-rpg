class_name ArtifactData
extends RefCounted

# Slots: weapon, shield, armor, boots, accessory, relic
static var ARTIFACTS: Dictionary = {
	"sword_valiance": {
		"id": "sword_valiance",
		"name": "Меч Доблести",
		"slot": "weapon",
		"icon": "⚔️",
		"attack_bonus": 4,
		"defense_bonus": 0,
		"spellpower_bonus": 0,
		"knowledge_bonus": 0,
		"mp_bonus": 0,
		"mana_bonus": 0,
		"description": "Клинок из закаленной звездной стали. Прибавляет +4 к Атаке паладина."
	},
	"shield_aegis": {
		"id": "shield_aegis",
		"name": "Щит Заступника",
		"slot": "shield",
		"icon": "🛡️",
		"attack_bonus": 0,
		"defense_bonus": 4,
		"spellpower_bonus": 0,
		"knowledge_bonus": 0,
		"mp_bonus": 0,
		"mana_bonus": 0,
		"description": "Массивный геральдический щит с грифоном. Прибавляет +4 к Защите войска."
	},
	"boots_traveler": {
		"id": "boots_traveler",
		"name": "Сапоги Странника",
		"slot": "boots",
		"icon": "👢",
		"attack_bonus": 0,
		"defense_bonus": 0,
		"spellpower_bonus": 0,
		"knowledge_bonus": 0,
		"mp_bonus": 8,
		"mana_bonus": 0,
		"description": "Сапоги из мягкой эльфийской кожи. Даруют +8 очков хода герою каждый новый день."
	},
	"ring_arcana": {
		"id": "ring_arcana",
		"name": "Перстень Архимага",
		"slot": "accessory",
		"icon": "💍",
		"attack_bonus": 0,
		"defense_bonus": 0,
		"spellpower_bonus": 2,
		"knowledge_bonus": 2,
		"mp_bonus": 0,
		"mana_bonus": 20,
		"description": "Сапфировое кольцо с древними рунами. Дарует +2 к Силе Магии, +2 к Знанию и +20 к макс. мане."
	},
	"armor_chitin": {
		"id": "armor_chitin",
		"name": "Панцирь Древнего Стража",
		"slot": "armor",
		"icon": "🦺",
		"attack_bonus": 1,
		"defense_bonus": 3,
		"spellpower_bonus": 0,
		"knowledge_bonus": 0,
		"mp_bonus": 0,
		"mana_bonus": 0,
		"description": "Пластинчатые латы, выкованные мастерами холмов. +1 к Атаке, +3 к Защите."
	},
	"crown_fairy": {
		"id": "crown_fairy",
		"name": "Венец Королевы Фей",
		"slot": "relic",
		"icon": "👑",
		"attack_bonus": 2,
		"defense_bonus": 2,
		"spellpower_bonus": 2,
		"knowledge_bonus": 2,
		"mp_bonus": 4,
		"mana_bonus": 20,
		"description": "Легендарная реликвия волшебного леса. Дарует +2 ко всем параметрам и +4 очка хода!"
	}
}

static func get_artifact(id: String) -> Dictionary:
	return ARTIFACTS.get(id, {})

static func get_all_slot_names() -> Array[String]:
	var slots: Array[String] = ["weapon", "shield", "armor", "boots", "accessory", "relic"]
	return slots

static func get_slot_title(slot: String) -> String:
	match slot:
		"weapon": return "Оружие"
		"shield": return "Щит"
		"armor": return "Доспех"
		"boots": return "Обувь"
		"accessory": return "Кольцо"
		"relic": return "Реликвия"
		_: return slot

# Artifact Sets & Synergy Bonuses
static var SETS: Dictionary = {
	"guardian": {
		"id": "guardian",
		"name": "Страж Королевства",
		"items": ["sword_valiance", "shield_aegis", "armor_chitin"],
		"bonuses": {
			2: {
				"title": "Страж Королевства (2/3): +2 Атака, +2 Защита",
				"attack": 2, "defense": 2, "spellpower": 0, "knowledge": 0, "mp": 0, "mana": 0
			},
			3: {
				"title": "Страж Королевства (3/3): +4 Атака, +4 Защита, +4 Очка хода",
				"attack": 4, "defense": 4, "spellpower": 0, "knowledge": 0, "mp": 4, "mana": 0
			}
		}
	},
	"archmagus": {
		"id": "archmagus",
		"name": "Наследие Архимага",
		"items": ["ring_arcana", "crown_fairy"],
		"bonuses": {
			2: {
				"title": "Наследие Архимага (2/2): +3 Сила магии, +3 Знание, +30 Мана",
				"attack": 0, "defense": 0, "spellpower": 3, "knowledge": 3, "mp": 0, "mana": 30
			}
		}
	},
	"wanderer": {
		"id": "wanderer",
		"name": "Странник Просторов",
		"items": ["boots_traveler", "crown_fairy"],
		"bonuses": {
			2: {
				"title": "Странник Просторов (2/2): +6 Очков хода, +2 Атака",
				"attack": 2, "defense": 0, "spellpower": 0, "knowledge": 0, "mp": 6, "mana": 0
			}
		}
	}
}

static func get_active_set_bonuses(equipped_dict: Dictionary) -> Dictionary:
	var total_bonuses = {
		"attack": 0,
		"defense": 0,
		"spellpower": 0,
		"knowledge": 0,
		"mp": 0,
		"mana": 0,
		"active_titles": []
	}
	var equipped_ids: Array[String] = []
	for slot in equipped_dict.keys():
		var art_id = equipped_dict[slot]
		if art_id != "" and not equipped_ids.has(art_id):
			equipped_ids.append(art_id)
			
	for set_id in SETS.keys():
		var s = SETS[set_id]
		var count = 0
		for item_id in s["items"]:
			if equipped_ids.has(item_id):
				count += 1
		# Check applicable bonus tiers
		var best_tier = 0
		var tiers = s["bonuses"].keys()
		tiers.sort()
		for tier in tiers:
			if count >= tier:
				best_tier = tier
		if best_tier > 0:
			var b = s["bonuses"][best_tier]
			total_bonuses["attack"] += b.get("attack", 0)
			total_bonuses["defense"] += b.get("defense", 0)
			total_bonuses["spellpower"] += b.get("spellpower", 0)
			total_bonuses["knowledge"] += b.get("knowledge", 0)
			total_bonuses["mp"] += b.get("mp", 0)
			total_bonuses["mana"] += b.get("mana", 0)
			total_bonuses["active_titles"].append(b.get("title", ""))
			
	return total_bonuses
