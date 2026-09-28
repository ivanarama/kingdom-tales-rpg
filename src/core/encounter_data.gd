class_name EncounterData
extends RefCounted

## Составы вражеских отрядов кампании: id объекта карты -> армия.
## Единый источник для тактического боя (BattleArena) и быстрого боя (WorldMapScene).
## army: [{unit_id, count, hex}], name — заголовок быстрого боя, intro — строка лога боя.

const ENCOUNTERS: Dictionary = {
	# --- Глава 1 ---
	"patrol_wolves": {
		"name": "Стая Волков",
		"intro": "Стая голодных лесных волков скалит клыки и идет на перехват!",
		"army": [{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)}]
	},
	"patrol_goblins": {
		"name": "Шайка Гоблинов",
		"intro": "Шайка гоблинов-грабителей бросается в атаку!",
		"army": [
			{"unit_id": "goblin", "count": 24, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 6, "hex": Vector2i(10, 4)}
		]
	},
	"patrol_forester": {
		"name": "Засада Разбойников",
		"intro": "Засада разбойников на южном тракте атакует из кустов!",
		"army": [
			{"unit_id": "goblin", "count": 18, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 8, "hex": Vector2i(10, 4)}
		]
	},
	"patrol_grove": {
		"name": "Страж Рощи",
		"intro": "Страж Рощи — могучий Древень и его свита пробудились!",
		"army": [
			{"unit_id": "treant", "count": 3, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 4)}
		]
	},
	"patrol_1": {
		"name": "Авангард Разбойников",
		"intro": "Авангард разбойников преграждает дорогу за Железными Вратами!",
		"army": [
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 12, "hex": Vector2i(10, 4)}
		]
	},
	"patrol_rogues": {
		"name": "Дозор Стрелков",
		"intro": "Стрелки разбойников преграждают путь к Роще Фей!",
		"army": [
			{"unit_id": "goblin", "count": 26, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 14, "hex": Vector2i(10, 4)}
		]
	},
	"patrol_obelisk": {
		"name": "Стража Обелиска",
		"intro": "Элитная стража Обелиска защищает древние сокровища!",
		"army": [
			{"unit_id": "treant", "count": 3, "hex": Vector2i(10, 1)},
			{"unit_id": "goblin", "count": 20, "hex": Vector2i(10, 3)},
			{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 5)}
		]
	},
	"patrol_2": {
		"name": "Разбойничий дозор",
		"intro": "Вражеский дозор пытается перерезать дорогу!",
		"army": [
			{"unit_id": "goblin", "count": 22, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 12, "hex": Vector2i(10, 4)}
		]
	},
	"bandit_boss": {
		"name": "Атаман Разбойников",
		"intro": "Логово Главаря Разбойников! Атаман и его приспешники идут в атаку!",
		"army": [
			{"unit_id": "goblin", "count": 35, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 18, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 5, "hex": Vector2i(10, 5)}
		]
	},
	# --- Глава 2 ---
	"swamp_patrol_road": {
		"name": "Болотные Зомби",
		"intro": "Орда болотных зомби медленно поднимается из тины!",
		"army": [{"unit_id": "swamp_zombie", "count": 18, "hex": Vector2i(10, 3)}]
	},
	"swamp_patrol_fens": {
		"name": "Скелеты Топей",
		"intro": "Скелеты-лучники натягивают тетиву среди камышей!",
		"army": [{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 2)}]
	},
	"swamp_patrol_gate": {
		"name": "Костяная Стража",
		"intro": "Костяная стража охраняет подступы к Некрополю!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 22, "hex": Vector2i(10, 1)},
			{"unit_id": "swamp_zombie", "count": 14, "hex": Vector2i(10, 4)}
		]
	},
	"swamp_patrol_east": {
		"name": "Легион Смерти",
		"intro": "Легион Смерти преграждает дорогу к Алтарю Друидов!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 24, "hex": Vector2i(10, 2)},
			{"unit_id": "swamp_zombie", "count": 18, "hex": Vector2i(10, 4)}
		]
	},
	"swamp_patrol_ruins": {
		"name": "Стражи Гробниц",
		"intro": "Осквернители древних гробниц обрушивают темную магию!",
		"army": [
			{"unit_id": "lich", "count": 4, "hex": Vector2i(10, 1)},
			{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 3)},
			{"unit_id": "swamp_zombie", "count": 12, "hex": Vector2i(10, 5)}
		]
	},
	"swamp_patrol": {
		"name": "Болотный дозор",
		"intro": "Болотная нежить преграждает путь сквозь трясину!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 18, "hex": Vector2i(10, 2)},
			{"unit_id": "swamp_zombie", "count": 14, "hex": Vector2i(10, 4)}
		]
	},
	"lich_boss": {
		"name": "Древний Лич",
		"intro": "Цитадель Тьмы! Древний Лич поднимает нежить из болотных могил!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 32, "hex": Vector2i(10, 1)},
			{"unit_id": "swamp_zombie", "count": 22, "hex": Vector2i(10, 3)},
			{"unit_id": "lich", "count": 8, "hex": Vector2i(10, 5)}
		]
	},
	# --- Глава 3 ---
	"dragon_patrol_pass": {
		"name": "Огненный Дозор",
		"intro": "Огненная стража перевала атакует!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 1)},
			{"unit_id": "griffin", "count": 8, "hex": Vector2i(10, 4)}
		]
	},
	"dragon_patrol_gate": {
		"name": "Стража Врат",
		"intro": "Стража Огненных Врат идет на таран!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 22, "hex": Vector2i(10, 1)},
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 3)},
			{"unit_id": "wolf", "count": 14, "hex": Vector2i(10, 5)}
		]
	},
	"dragon_patrol_caldera": {
		"name": "Слуги Дракона",
		"intro": "Слуги дракона перекрывают путь к жерлу вулкана!",
		"army": [
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 4, "hex": Vector2i(10, 5)}
		]
	},
	"dragon_patrol_citadel": {
		"name": "Лавовые Хищники",
		"intro": "Лавовые хищники бросаются на защиту цитадели!",
		"army": [
			{"unit_id": "griffin", "count": 12, "hex": Vector2i(10, 2)},
			{"unit_id": "goblin", "count": 22, "hex": Vector2i(10, 4)}
		]
	},
	"dragon_boss": {
		"name": "Красный Дракон",
		"intro": "Гнездо Владыки Огня! Красный Дракон расправляет пылающие крылья!",
		"army": [
			{"unit_id": "wolf", "count": 25, "hex": Vector2i(10, 1)},
			{"unit_id": "red_dragon", "count": 3, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 8, "hex": Vector2i(10, 5)}
		]
	}
}

## Старые/альтернативные id объектов карты, которые встречаются в сохранениях.
const ALIASES: Dictionary = {
	"dragon_patrol": "dragon_patrol_pass",
	"patrol_dragon": "dragon_patrol_pass",
	"patrol_swamp": "swamp_patrol"
}

## Отряд по умолчанию для неизвестного id — по главе кампании.
const CHAPTER_DEFAULTS: Dictionary = {
	1: {
		"name": "Лесные разбойники",
		"intro": "Лесные разбойники преграждают путь! Битва началась!",
		"army": [
			{"unit_id": "goblin", "count": 18, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 9, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 2, "hex": Vector2i(10, 5)}
		]
	},
	2: {
		"name": "Болотная нежить",
		"intro": "Орда нежити восстает из могил болот!",
		"army": [
			{"unit_id": "skeleton_archer", "count": 16, "hex": Vector2i(10, 1)},
			{"unit_id": "swamp_zombie", "count": 12, "hex": Vector2i(10, 3)},
			{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 5)}
		]
	},
	3: {
		"name": "Стража ущелья",
		"intro": "Стражи вулканического ущелья бросаются в бой!",
		"army": [
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 4, "hex": Vector2i(10, 5)}
		]
	}
}

## Описание столкновения (name, intro, army) по id объекта; неизвестный id — отряд главы.
static func get_encounter(battle_id: String, chapter: int) -> Dictionary:
	var id: String = ALIASES.get(battle_id, battle_id)
	if ENCOUNTERS.has(id):
		return ENCOUNTERS[id]
	return CHAPTER_DEFAULTS.get(chapter, CHAPTER_DEFAULTS[1])

## Копия вражеской армии — её можно менять, не трогая таблицу.
static func get_army(battle_id: String, chapter: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in get_encounter(battle_id, chapter)["army"]:
		result.append(item.duplicate())
	return result

static func is_boss(battle_id: String) -> bool:
	return battle_id in ["bandit_boss", "lich_boss", "dragon_boss"]
