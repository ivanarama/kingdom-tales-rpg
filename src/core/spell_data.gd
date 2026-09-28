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
		"description": "Обрушивает пылающую сферу на вражеский отряд, нанося 50 ед. урона (+14 за каждую Силу Магии)."
	},
	"heal": {
		"id": "heal",
		"name": "Исцеление",
		"mana_cost": 8,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_heal.png",
		"description": "Восстанавливает 60 ед. здоровья (+16 за каждую Силу Магии) раненым воинам дружественного отряда."
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
		"icon_path": "res://assets/art/spells/spell_scrying.png",
		"description": "Походное заклинание: рассеивает туман войны на обширной территории вокруг героя (радиус 9)!"
	},
	"restoration": {
		"id": "restoration",
		"name": "Благодать Похода",
		"mana_cost": 15,
		"type": "adventure",
		"category": "adventure",
		"icon_path": "res://assets/art/spells/spell_restoration.png",
		"description": "Походное заклинание: исцеляет раненых в походе и пополняет все отряды армии на +20% воинов!"
	},
	"lightning": {
		"id": "lightning",
		"name": "Молния",
		"mana_cost": 12,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_lightning.png",
		"description": "Призывает с небес ослепительную молнию, наносящую 65 ед. урона (+18 за каждую Силу Магии)."
	},
	"slow": {
		"id": "slow",
		"name": "Замедление",
		"mana_cost": 8,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_slow.png",
		"description": "Оковывает врага инеем, уменьшая его скорость на 50% на 3 раунда."
	},
	"stoneskin": {
		"id": "stoneskin",
		"name": "Каменная Кожа",
		"mana_cost": 7,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_stoneskin.png",
		"description": "Укрепляет плоть союзного отряда магией земли, даруя +5 к Защите на 3 раунда."
	},
	"blind": {
		"id": "blind",
		"name": "Ослепление",
		"mana_cost": 10,
		"type": "target_enemy",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_blind.png",
		"description": "Ослепляет вражеский отряд яркой вспышкой. Отряд не может ходить, пока не получит урон (до 3 раундов)."
	},
	"inspiration": {
		"id": "inspiration",
		"name": "Вдохновение",
		"mana_cost": 8,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_inspiration.png",
		"description": "Развевает все тёмные чары с союзного отряда (слепота, яд, корни, замедление) и удваивает его боевой дух на 3 раунда."
	},
	"shield_light": {
		"id": "shield_light",
		"name": "Щит Света",
		"mana_cost": 9,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_shield_light.png",
		"description": "Окружает союзный отряд куполом света, поглощающим 40 ед. урона (+10 за каждую Силу Магии) на 3 раунда."
	},
	"retribution": {
		"id": "retribution",
		"name": "Возмездие",
		"mana_cost": 10,
		"type": "target_ally",
		"category": "combat",
		"icon_path": "res://assets/art/spells/spell_retribution.png",
		"description": "Осеняет союзный отряд печатью правосудия: на 3 раунда каждый ближний атакующий получает 25% урона ответно."
	}
}

static func get_spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})

static func has_spell(id: String) -> bool:
	return SPELLS.has(id)
