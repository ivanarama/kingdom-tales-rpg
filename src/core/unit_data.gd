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
		"attack": 8,
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
		"attack": 11,
		"defense": 12,
		"speed": 7,
		"initiative": 16,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": true,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_royal_griffin.png",
		"sprite_path": "res://assets/art/units/unit_royal_griffin.png",
		"description": "Элитные белые грифоны королевской гвардии. Повышенная скорость и сокрушительный ответный удар!"
	},
	"fairy_archer": {
		"id": "fairy_archer",
		"name": "Феи-лучницы",
		"tier": 2,
		"max_hp": 16,
		"min_dmg": 5,
		"max_dmg": 8,
		"attack": 6,
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
		"attack": 9,
		"defense": 6,
		"speed": 5,
		"initiative": 14,
		"is_ranged": true,
		"flying": true,
		"double_shot": true,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_royal_fairy.png",
		"sprite_path": "res://assets/art/units/unit_royal_fairy.png",
		"description": "Благословленные королевой лучницы. Стреляют дважды за один выстрел!"
	},
	"treant": {
		"id": "treant",
		"name": "Древни",
		"tier": 4,
		"max_hp": 85,
		"min_dmg": 14,
		"max_dmg": 20,
		"attack": 12,
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
		"attack": 5,
		"defense": 5,
		"speed": 5,
		"initiative": 11,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"pack_hunter": true,
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
		"attack": 3,
		"defense": 3,
		"speed": 4,
		"initiative": 9,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"cowardly": true,
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
		"attack": 5,
		"defense": 4,
		"speed": 4,
		"initiative": 10,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"ranged_resist": 0.25,
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
		"attack": 6,
		"defense": 8,
		"speed": 3,
		"initiative": 7,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"disease": true,
		"natural_faces_left": true,
		# Медальон вырезан из жетона карты: у жетона непрозрачный квадратный фон
		"sprite_height": 1.6,
		"token_path": "res://assets/art/units/medallion_swamp_zombie.png",
		"sprite_path": "res://assets/art/units/medallion_swamp_zombie.png",
		"description": "Тяжело ступающие мертвецы болот. Удары заражают врага трупным ядом (-25% к атаке)!"
	},
	"druid": {
		"id": "druid",
		"name": "Лесные Друиды",
		"tier": 3,
		"max_hp": 36,
		"min_dmg": 10,
		"max_dmg": 16,
		"attack": 9,
		"defense": 9,
		"speed": 5,
		"initiative": 13,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"no_range_penalty": true,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_druid.png",
		"sprite_path": "res://assets/art/units/unit_druid.png",
		"description": "Мудрецы священных дубрав. Разит молниями природы на дальнем расстоянии."
	},
	"lich": {
		"id": "lich",
		"name": "Лич Некромант",
		"tier": 5,
		"max_hp": 65,
		"min_dmg": 16,
		"max_dmg": 24,
		"attack": 12,
		"defense": 14,
		"speed": 5,
		"initiative": 14,
		"is_ranged": true,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": true,
		"is_caster": true,
		"raise_dead": {"unit": "skeleton_archer", "per_unit": 1, "every": 2},
		"token_path": "res://assets/art/ui/tokens/token_unit_lich.png",
		"sprite_path": "res://assets/art/units/unit_lich.png",
		"description": "Повелитель тлетворных топей. Колдует тёмное пламя по самым густым строям врага, а раз в 2 раунда поднимает из болота по скелету-лучнику за каждого лича."
	},
	"red_dragon": {
		"id": "red_dragon",
		"name": "Красный Дракон",
		"tier": 7,
		"max_hp": 240,
		"min_dmg": 38,
		"max_dmg": 55,
		"attack": 18,
		"defense": 22,
		"speed": 8,
		"initiative": 18,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": true,
		"breath_attack": true,
		"firestorm": 3,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_red_dragon.png",
		"sprite_path": "res://assets/art/units/unit_red_dragon.png",
		"description": "Легендарный владыка огнедышащих пиков. Огненное дыхание пробивает на 2 гекса сквозь строй врагов, а раз в 3 раунда дракон набирает воздух и выжигает конус перед собой — отмеченные клетки видны заранее."
	},
	# Босс главы 1. Арт — медальон, вырезанный из жетона босса на карте мира.
	"bandit_chief": {
		"id": "bandit_chief",
		"name": "Атаман Разбойников",
		"tier": 5,
		"max_hp": 150,
		"attack": 10,
		"min_dmg": 15,
		"max_dmg": 22,
		"defense": 12,
		"speed": 5,
		"initiative": 12,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"rally_aura": 2,
		"sprite_height": 1.9,
		"natural_faces_left": true,
		"token_path": "res://assets/art/units/medallion_bandit_chief.png",
		"sprite_path": "res://assets/art/units/medallion_bandit_chief.png",
		"description": "Главарь лесной вольницы. Пока над ним реет знамя, его люди бьются яростнее: +2 к атаке всем союзным отрядам. Сразите Атамана — и шайка дрогнет."
	},
	"royal_pegasus": {
		"id": "royal_pegasus",
		"name": "Светлые Пегасы",
		"tier": 3,
		"max_hp": 40,
		"min_dmg": 8,
		"max_dmg": 13,
		"attack": 9,
		"defense": 8,
		"speed": 8,
		"initiative": 15,
		"is_ranged": false,
		"flying": true,
		"unlimited_retaliation": false,
		"no_retaliation": true,
		"natural_faces_left": false,
		"token_path": "res://assets/art/ui/tokens/token_unit_pegasus.png",
		"sprite_path": "res://assets/art/units/unit_pegasus.png",
		"description": "Крылатые конники рощи фей. Стремительны и первыми перехватывают вражеских стрелков!"
	},
	"stone_guardian": {
		"id": "stone_guardian",
		"name": "Каменные Стражи",
		"tier": 4,
		"max_hp": 90,
		"min_dmg": 12,
		"max_dmg": 18,
		"attack": 11,
		"defense": 18,
		"speed": 3,
		"initiative": 6,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"reflect": 0.3,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_stone_guardian.png",
		"sprite_path": "res://assets/art/units/unit_stone_guardian.png",
		"description": "Ожившие изваяния древних обелисков. Отражают 30% урона от ответных и любых ближних ударов!"
	},
	"unicorn": {
		"id": "unicorn",
		"name": "Единороги",
		"tier": 4,
		"max_hp": 75,
		"min_dmg": 14,
		"max_dmg": 20,
		"attack": 13,
		"defense": 13,
		"speed": 7,
		"initiative": 14,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"blind_chance": 0.2,
		"token_path": "res://assets/art/ui/tokens/token_unit_unicorn.png",
		"sprite_path": "res://assets/art/units/unit_unicorn.png",
		"description": "Светлые хранители лунных полян. Сияние рога ослепляет врага: он пропускает ход, пока его не ранят."
	},
	"lava_salamander": {
		"id": "lava_salamander",
		"name": "Лавовые саламандры",
		"tier": 2,
		"max_hp": 26,
		"min_dmg": 6,
		"max_dmg": 9,
		"attack": 8,
		"defense": 6,
		"speed": 6,
		"initiative": 12,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"reflect": 0.2,
		"token_path": "res://assets/art/ui/tokens/token_unit_lava_salamander.png",
		"sprite_path": "res://assets/art/units/unit_lava_salamander.png",
		"description": "Юркие ящерки из огненных трещин Пика. Раскалённая шкура обжигает тех, кто бьёт вблизи (20% урона возвращается)."
	},
	"magma_golem": {
		"id": "magma_golem",
		"name": "Магмовые големы",
		"tier": 4,
		"max_hp": 95,
		"min_dmg": 15,
		"max_dmg": 21,
		"attack": 13,
		"defense": 16,
		"speed": 3,
		"initiative": 7,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"natural_faces_left": false,
		"regeneration": 20,
		"token_path": "res://assets/art/ui/tokens/token_unit_magma_golem.png",
		"sprite_path": "res://assets/art/units/unit_magma_golem.png",
		"description": "Медлительные великаны из остывающей лавы. Трещины на их теле затягиваются сами (+20 HP в раунд)."
	},
	"fox_shifter": {
		"id": "fox_shifter",
		"name": "Лисы-Оборотни",
		"tier": 2,
		"max_hp": 24,
		"min_dmg": 5,
		"max_dmg": 9,
		"attack": 6,
		"defense": 5,
		"speed": 7,
		"initiative": 13,
		"is_ranged": false,
		"flying": false,
		"unlimited_retaliation": false,
		"dodge": 0.25,
		"natural_faces_left": true,
		"token_path": "res://assets/art/ui/tokens/token_unit_fox_shifter.png",
		"sprite_path": "res://assets/art/units/unit_fox_shifter.png",
		"description": "Хитрые лесные духи. 25% шанс увернуться от ближнего удара (урон вдвое меньше)!"
	}
}

## Черты переводятся по одной: вызывающие делали tr() от склеенной строки,
## а такого ключа в CSV нет — в EN-версии кодекс показывал черты по-русски.
## UnitData — не узел, поэтому переводим через TranslationServer.
static func _t(text: String) -> String:
	return String(TranslationServer.translate(text))

static func get_trait_string(id: String) -> String:
	var u := get_unit(id)
	var traits: Array[String] = []
	# Особые способности — первыми, чтобы их было видно в кодексе
	if u.get("pack_hunter", false):
		traits.append(_t("Стая"))
	if u.get("cowardly", false):
		traits.append(_t("Трусоватые"))
	if float(u.get("ranged_resist", 0.0)) > 0.0:
		traits.append(_t("Кости"))
	if u.get("no_range_penalty", false):
		traits.append(_t("Молния природы"))
	if u.get("no_retaliation", false):
		traits.append(_t("Стремительный налёт"))
	if u.get("is_ranged", false):
		traits.append(_t("Стрелок"))
	if u.get("flying", false):
		traits.append(_t("Летун"))
	if u.get("unlimited_retaliation", false):
		traits.append(_t("Бесконечный отпор"))
	if u.get("double_shot", false):
		traits.append(_t("Двойной выстрел"))
	if u.get("breath_attack", false):
		traits.append(_t("Огненное дыхание"))
	if u.get("disease", false):
		traits.append(_t("Трупный яд"))
	if int(u.get("regeneration", 0)) > 0:
		traits.append(_t("Регенерация +%d") % int(u["regeneration"]))
	if u.get("entangle", false):
		traits.append(_t("Оплетающие корни"))
	if float(u.get("reflect", 0.0)) > 0.0:
		traits.append(_t("Отражение %d%%") % int(round(100.0 * float(u["reflect"]))))
	if float(u.get("dodge", 0.0)) > 0.0:
		traits.append(_t("Уклонение %d%%") % int(round(100.0 * float(u["dodge"]))))
	if u.get("is_caster", false):
		traits.append(_t("Колдун"))
	if int(u.get("rally_aura", 0)) > 0:
		traits.append(_t("Знамя: +%d к атаке союзникам") % int(u["rally_aura"]))
	if u.has("raise_dead"):
		traits.append(_t("Подъём нежити"))
	if int(u.get("firestorm", 0)) > 0:
		traits.append(_t("Огненный шквал"))
	if float(u.get("blind_chance", 0.0)) > 0.0:
		traits.append(_t("Ослепляющий рог"))
	return " • ".join(traits) if traits.size() > 0 else _t("Пехота ближнего боя")
static func get_unit(id: String) -> Dictionary:
	return UNITS.get(id, {})


