class_name SpellData
extends RefCounted

static var SPELLS: Dictionary = {
	"fireball": {
		"id": "fireball",
		"name": "Огненный Шар",
		"mana_cost": 10,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_fireball.png",
		"description": "Обрушивает пылающую сферу на вражеский отряд: 50 + 14 × Сила Магии ед. урона (+25–55% с навыком Волшебство)."
	},
	"heal": {
		"id": "heal",
		"name": "Исцеление",
		"mana_cost": 8,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_heal.png",
		"description": "Лечит раненых и поднимает павших воинов союзного отряда: 60 + 16 × Сила Магии ед. здоровья, но не больше численности отряда на начало боя."
	},
	"bless": {
		"id": "bless",
		"name": "Благословение",
		"mana_cost": 6,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_bless.png",
		"description": "Наполняет союзный отряд святой силой, гарантируя максимальный урон каждым ударом на 3 раунда."
	},
	"haste": {
		"id": "haste",
		"name": "Ускорение",
		"mana_cost": 5,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_haste.png",
		"description": "Дарует крылья ветров союзному отряду, увеличивая скорость перемещения на +3 гекса."
	},
	"scrying": {
		"id": "scrying",
		"name": "Око Орла",
		"mana_cost": 10,
		"type": "adventure",
		"category": "adventure",
		"icon_path": "res://assets/art/spells/spell_haste.png",
		"description": "Походное заклинание: рассеивает туман войны на обширной территории вокруг героя (радиус 9)!"
	},
	"restoration": {
		"id": "restoration",
		"name": "Благодать Похода",
		"mana_cost": 15,
		"type": "adventure",
		"category": "adventure",
		"icon_path": "res://assets/art/spells/spell_heal.png",
		"description": "Походное заклинание: возвращает в строй павших в боях — до (3 + Сила Магии) воинов каждого вида."
	},
	"lightning": {
		"id": "lightning",
		"name": "Молния",
		"mana_cost": 12,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_fireball.png",
		"description": "Призывает с небес ослепительную молнию: 65 + 18 × Сила Магии ед. урона (+25–55% с навыком Волшебство)."
	},
	"slow": {
		"id": "slow",
		"name": "Замедление",
		"mana_cost": 8,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_haste.png",
		"description": "Оковывает врага инеем, уменьшая его скорость на 50% на 3 раунда."
	},
	"stoneskin": {
		"id": "stoneskin",
		"name": "Каменная Кожа",
		"mana_cost": 7,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_bless.png",
		"description": "Укрепляет плоть союзного отряда магией земли, даруя +5 к Защите на 3 раунда."
	},
	"blind": {
		"id": "blind",
		"name": "Ослепление",
		"mana_cost": 10,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_haste.png",
		"description": "Ослепляет вражеский отряд яркой вспышкой. Отряд не может ходить, пока не получит урон (до 3 раундов)."
	}
}

static func get_spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})

static func has_spell(id: String) -> bool:
	return SPELLS.has(id)
