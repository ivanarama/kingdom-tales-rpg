class_name UnitData
extends RefCounted

static var UNITS: Dictionary = {
	"griffin": {
		"id": "griffin",
		"name": "Грифоны",
		"tier": 3,
		"max_hp": 38,
		"min_dmg": 7,
		"max_dmg": 11,
		"defense": 9,
		"speed": 6,
		"initiative": 14,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": true,
		"natural_faces_left": false,
		"upgrade_to": "royal_griffin",
		"token_path": "res://assets/art/ui/tokens/token_unit_griffin.png",
		"sprite_path": "res://assets/art/units/unit_griffin.png",
		"description": "Могучий зверь с телом льва и крыльями орла. Отвечает на все удары без ограничений!"
	},
	"royal_griffin": {
		"id": "royal_griffin",
		"name": "Королевские Грифоны",
		"tier": 3,
		"max_hp": 46,
		"min_dmg": 10,
		"max_dmg": 15,
		"defense": 12,
		"speed": 7,
		"initiative": 16,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": true,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_griffin.png",
		"sprite_path": "res://assets/art/units/unit_griffin.png",
		"description": "Элитные белые грифоны королевской гвардии. Повышенная скорость и сокрушительный ответный удар!"
	},
	"fairy_archer": {
		"id": "fairy_archer",
		"name": "Феи-лучницы",
		"tier": 2,
		"max_hp": 16,
		"min_dmg": 5,
		"max_dmg": 8,
		"defense": 4,
		"speed": 4,
		"initiative": 12,
		"is_ranged": true,
		"flying": true,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"upgrade_to": "royal_fairy",
		"token_path": "res://assets/art/ui/tokens/token_unit_fairy_archer.png",
		"sprite_path": "res://assets/art/units/unit_fairy_archer.png",
		"description": "Метко поражает врагов зачарованными стрелами издалека."
	},
	"royal_fairy": {
		"id": "royal_fairy",
		"name": "Королевские Феи",
		"tier": 2,
		"max_hp": 22,
		"min_dmg": 7,
		"max_dmg": 11,
		"defense": 6,
		"speed": 5,
		"initiative": 14,
		"is_ranged": true,
		"flying": true,
		"double_shot": true,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_fairy_archer.png",
		"sprite_path": "res://assets/art/units/unit_fairy_archer.png",
		"description": "Благословленные королевой лучницы. Стреляют дважды за один выстрел!"
	},
	"treant": {
		"id": "treant",
		"name": "Древни",
		"tier": 4,
		"max_hp": 85,
		"min_dmg": 14,
		"max_dmg": 20,
		"defense": 15,
		"speed": 3,
		"initiative": 8,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"regeneration": 20,
		"entangle": true,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_treant.png",
		"sprite_path": "res://assets/art/units/unit_treant.png",
		"description": "Вековой защитник чащи. Регенерирует 20 HP в раунд и может опутать врага корнями!"
	},
	"wolf": {
		"id": "wolf",
		"name": "Лесные волки",
		"tier": 1,
		"max_hp": 22,
		"min_dmg": 4,
		"max_dmg": 7,
		"defense": 5,
		"speed": 5,
		"initiative": 11,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_wolf.png",
		"sprite_path": "res://assets/art/units/unit_wolf.png",
		"description": "Быстрый и свирепый хищник, способный молниеносно настигать стрелков."
	},
	"goblin": {
		"id": "goblin",
		"name": "Гоблины",
		"tier": 1,
		"max_hp": 14,
		"min_dmg": 3,
		"max_dmg": 5,
		"defense": 3,
		"speed": 4,
		"initiative": 9,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_goblin.png",
		"sprite_path": "res://assets/art/units/unit_goblin.png",
		"description": "Шумный лесной разбойник с копьем и деревянным щитом."
	},
	"skeleton_archer": {
		"id": "skeleton_archer",
		"name": "Скелеты-лучники",
		"tier": 1,
		"max_hp": 16,
		"min_dmg": 4,
		"max_dmg": 6,
		"defense": 4,
		"speed": 4,
		"initiative": 10,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_skeleton_archer.png",
		"sprite_path": "res://assets/art/units/unit_skeleton_archer.png",
		"description": "Восставшие стрелки из древних курганов. Не ведают страха и усталости."
	},
	"swamp_zombie": {
		"id": "swamp_zombie",
		"name": "Болотные Зомби",
		"tier": 2,
		"max_hp": 34,
		"min_dmg": 5,
		"max_dmg": 8,
		"defense": 8,
		"speed": 3,
		"initiative": 7,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"disease": true,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_swamp_zombie.png",
		"sprite_path": "res://assets/art/ui/tokens/token_unit_swamp_zombie.png",
		"description": "Тяжело ступающие мертвецы болот. Удары заражают врага трупным ядом (-25% к атаке)!"
	},
	"druid": {
		"id": "druid",
		"name": "Лесные Друиды",
		"tier": 3,
		"max_hp": 36,
		"min_dmg": 10,
		"max_dmg": 16,
		"defense": 9,
		"speed": 5,
		"initiative": 13,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_fairy_archer.png",
		"sprite_path": "res://assets/art/units/unit_fairy_archer.png",
		"description": "Мудрецы священных дубрав. Разит молниями природы на дальнем расстоянии."
	},
	"lich": {
		"id": "lich",
		"name": "Лич Некромант",
		"tier": 5,
		"max_hp": 65,
		"min_dmg": 16,
		"max_dmg": 24,
		"defense": 14,
		"speed": 5,
		"initiative": 14,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_treant.png",
		"sprite_path": "res://assets/art/units/unit_treant.png",
		"description": "Повелитель тлетворных топей. Обрушивает на врагов сгустки черной магии."
	},
	"red_dragon": {
		"id": "red_dragon",
		"name": "Красный Дракон",
		"tier": 7,
		"max_hp": 240,
		"min_dmg": 38,
		"max_dmg": 55,
		"defense": 22,
		"speed": 8,
		"initiative": 18,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": true,
		"breath_attack": true,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_griffin.png",
		"sprite_path": "res://assets/art/units/unit_griffin.png",
		"description": "Легендарный владыка огнедышащих пиков. Огненное дыхание пробивает на 2 гекса сквозь строй врагов!"
	},
	# Награда Королевы Фей и найм в Роще после главы 1. Арт временно от грифона.
	"royal_pegasus": {
		"id": "royal_pegasus",
		"name": "Королевские Пегасы",
		"tier": 3,
		"max_hp": 36,
		"min_dmg": 7,
		"max_dmg": 12,
		"defense": 9,
		"speed": 8,
		"initiative": 15,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_griffin.png",
		"sprite_path": "res://assets/art/units/unit_griffin.png",
		"description": "Крылатые скакуны Королевы Фей. Стремительно облетают поле боя и первыми бросаются в атаку."
	},
	# Найм у Лесника после главы 1. Арт временно от волка.
	"fox_shifter": {
		"id": "fox_shifter",
		"name": "Лисы-оборотни",
		"tier": 2,
		"max_hp": 24,
		"min_dmg": 5,
		"max_dmg": 8,
		"defense": 6,
		"speed": 6,
		"initiative": 13,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_wolf.png",
		"sprite_path": "res://assets/art/units/unit_wolf.png",
		"description": "Лесные духи в облике лис. Быстры, неуловимы и верны тем, кто вернул лесу свет."
	},
	# Найм у Древнего Обелиска после победы над его стражей. Арт временно от древня.
	"stone_guardian": {
		"id": "stone_guardian",
		"name": "Каменные Стражи",
		"tier": 5,
		"max_hp": 90,
		"min_dmg": 12,
		"max_dmg": 18,
		"defense": 18,
		"speed": 3,
		"initiative": 7,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_treant.png",
		"sprite_path": "res://assets/art/units/unit_treant.png",
		"description": "Ожившие изваяния Древнего Обелиска. Медлительны, но почти несокрушимы."
	}
}

static func get_unit(id: String) -> Dictionary:
	return UNITS.get(id, {})

static func has_unit(id: String) -> bool:
	return UNITS.has(id)

## Краткая строка особенностей существа (кодекс, карточки).
static func get_trait_string(id: String) -> String:
	var u: Dictionary = get_unit(id)
	var traits: Array[String] = []
	if u.get("is_ranged", false):
		traits.append("Стрелок")
	if u.get("double_shot", false):
		traits.append("Двойной выстрел")
	if u.get("flying", false):
		traits.append("Летает")
	if u.get("unlimited_retaliation", false):
		traits.append("Бесконечный отпор")
	if u.get("breath_attack", false):
		traits.append("Огненное дыхание")
	if u.get("disease", false):
		traits.append("Трупный яд")
	if int(u.get("regeneration", 0)) > 0:
		traits.append("Регенерация +%d HP" % int(u["regeneration"]))
	if u.get("entangle", false):
		traits.append("Оплетающие корни")
	if traits.is_empty():
		return "Пехота ближнего боя"
	return " • ".join(traits)
